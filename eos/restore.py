"""Restore a partir da nuvem (e do GitHub, quando ha remoto) para um destino ISOLADO.

Regras:
  - o destino tem de estar vazio ou nao existir. Restore nunca escreve por cima de projeto
    existente: sobrescrever e acao destrutiva (gate H3), e restore nao e lugar para isso;
  - TUDO que vem do manifesto e dado nao confiavel: o manifesto nao e assinado, e quem escreve
    em `99 RECOVERY` controla manifesto e hash ao mesmo tempo (r1 do security, MEDIA 2). Por
    isso todo caminho, rotulo, branch e sha e validado ANTES de qualquer escrita ou remocao, e
    toda escrita e conferida por contencao real (commonpath sobre realpath), sem symlink no
    trajeto;
  - cada artefato e conferido por SHA-256 contra o manifesto antes de ser usado; o banco e
    gravado num temporario, conferido, e so entao movido para o lugar;
  - o resultado e verificado por fatos, nao por ausencia de erro.

Fonte do historico: 'cloud' (bundle), 'github' (clone do remoto) ou 'auto' (GitHub se houver
remoto, completado pelo bundle para refs que o remoto nao tem).
"""
import gzip
import os
import re
import shutil
import sqlite3
import tarfile
import tempfile

from . import backup as bk
from . import cloud, gitinfo, mirror

SHA_RE = re.compile(r"^[0-9a-f]{40}$")
# Nomes que o Windows trata como dispositivo: viram escrita em NUL/CON em vez de arquivo (r2 do security)
RESERVADOS = {"CON", "PRN", "AUX", "NUL"} | {"COM%d" % i for i in range(1, 10)} | {"LPT%d" % i for i in range(1, 10)}


PENDENTE = "decisao-pendente"  # marcador do plano de dados: entrada pulada, sem reprovar


class RestoreErro(RuntimeError):
    pass


def _componente_git(nome):
    """Grafias que o NTFS abre como `.git`: caixa trocada, ponto ou espaco no fim ('.git.',
    '.git '), e o nome curto 8.3 'GIT~N' (a mesma lista do core.protectNTFS do Git)."""
    n = nome.lower().rstrip(". ")
    return n == ".git" or re.fullmatch(r"git~[0-9]+", n) is not None


def _caminho_seguro(base, rel):
    """Caminho absoluto de `rel` dentro de `base`, ou RestoreErro. Recusa absoluto, unidade,
    '..', componente vazio, e qualquer symlink entre `base` e o alvo."""
    if not isinstance(rel, str) or not rel or any(ord(c) < 32 or c == "\x7f" for c in rel):
        # caractere de controle (NUL, quebra de linha, tab): a recusa e do restore, nao do git nem
        # do Windows (r6 do security, observacao 2)
        raise RestoreErro("caminho invalido no manifesto: %r" % (rel,))
    r = rel.replace("\\", "/")
    partes = r.split("/")
    if r.startswith("/") or re.match(r"^[A-Za-z]:", r) or any(p in ("", ".", "..") for p in partes) or ":" in r:
        raise RestoreErro("caminho recusado no manifesto (absoluto, unidade ou '..'): %r" % rel)
    if any(_componente_git(x) for x in partes):
        # hook ou config gravados ali seriam executados pelo proprio restore (pre-revisao r3, achado 6)
        raise RestoreErro("caminho dentro de .git no manifesto: %r" % rel)
    reservado = [x for x in partes if x.split(".")[0].upper() in RESERVADOS or x.endswith((" ", "."))]
    if reservado:
        raise RestoreErro("nome reservado do Windows no manifesto: %r" % reservado[0])
    base_real = os.path.realpath(base)
    alvo = os.path.join(base_real, *partes)
    atual = base_real
    for p in partes[:-1]:
        atual = os.path.join(atual, p)
        if os.path.islink(atual):
            raise RestoreErro("symlink no caminho de restauracao: %s" % atual)
    if os.path.islink(alvo):
        raise RestoreErro("symlink no alvo de restauracao: %s" % alvo)
    alvo_real = os.path.realpath(alvo)
    if os.path.commonpath([base_real, alvo_real]) != base_real:
        raise RestoreErro("caminho escaparia do destino: %r" % rel)
    # A mesma recusa sobre o caminho que o SO de fato abre: o realpath expande nome curto 8.3
    # (GIT~1, ou o hash que o NTFS gera quando ha colisao) e qualquer outro alias que o texto
    # nao mostra (r4 de QA e security, achado 1)
    if any(x.lower() == ".git" for x in os.path.relpath(alvo_real, base_real).replace("\\", "/").split("/")):
        raise RestoreErro("caminho resolve para dentro de .git: %r" % rel)
    return alvo


def _validar_manifesto(m, pid, destino):
    if m.get("project") != pid:
        raise RestoreErro("manifesto e de outro projeto: %r" % m.get("project"))
    if not m.get("unborn") and not SHA_RE.match(str(m.get("head") or "")):
        raise RestoreErro("HEAD do manifesto nao e um sha: %r" % m.get("head"))
    for item in m.get("wip_index", []):
        if not bk.ROTULO_RE.match(str(item.get("rotulo") or "")):
            raise RestoreErro("rotulo de worktree invalido: %r" % item.get("rotulo"))
        if item.get("head") is not None and not SHA_RE.match(str(item["head"])):
            raise RestoreErro("HEAD de worktree invalido: %r" % item.get("head"))
        if not isinstance(item.get("arquivos"), dict) or not isinstance(item.get("removidos", []), list):
            raise RestoreErro("indice de WIP malformado")
        if not isinstance(item.get("intencao", []), list) or not all(isinstance(x, str) for x in item.get("intencao", [])):
            raise RestoreErro("indice de WIP malformado (intencao)")
    for db in m.get("databases", []):
        _caminho_seguro(destino, db.get("path", ""))  # forma; a contencao real e reconferida na escrita


def _ref_valida(destino, nome):
    rc, _ = gitinfo.git(destino, "check-ref-format", "--branch", nome, check=False)
    if rc != 0 or nome.startswith("-"):
        raise RestoreErro("nome de branch invalido no manifesto: %r" % nome)
    return nome


def _baixar_conferido(store, art, destino):
    store.get(art["rel"], destino)
    sha = gitinfo.sha256_arquivo(destino)
    if sha != art["sha256"]:
        raise RestoreErro("hash divergente em %s: manifesto %s, baixado %s" % (art["rel"], art["sha256"][:12], sha[:12]))
    return destino


def _git_init_config(path):
    # o restore e uma maquina "nova": nada de autocrlf mudando bytes, nada de symlink real
    gitinfo.git(path, "config", "core.autocrlf", "false")
    gitinfo.git(path, "config", "core.symlinks", "false")


def _planejar_dados(contrato, store, destino):
    """Plano do --com-dados a partir do ultimo espelho ok (eos/mirror.py), validado ANTES de
    qualquer escrita: cada chave tem de estar dentro do seu data.path e passar por _caminho_seguro,
    e cada registro tem de ser [bytes, mtime_ns, md5]. Devolve (espelho ou None, planos)."""
    pid = contrato["identity"]["id"]
    try:
        alvos = [mirror.validar_path(p) for p in mirror.caminhos(contrato)]
        # pendente SEGUNDO O CONTRATO ATUAL (r12, QA-A1): a marca no manifesto sozinha nao basta -
        # titular que ja decidiu, ou manifesto adulterado, nao pode virar [ok] sem restaurar nada
        pend_contrato = {mirror._caixa(q) for q in mirror.separar(contrato)[1]}
    except mirror.MirrorErro as e:
        raise RestoreErro(str(e))
    if not alvos:
        return None, []
    m = mirror.ultimo_espelho(store, pid)
    if not m:
        return None, alvos
    planos = []
    for p in alvos:
        reg = (m.get("paths") or {}).get(p)
        if isinstance(reg, dict) and reg.get("estado") == "decisao-pendente":
            # o espelho nao subiu nada de proposito: nao ha o que restaurar, e isso nao e falha
            # (r11, QA2) - SO se o contrato atual tambem a tem pendente (r12, QA-A1); senao e
            # "sem copia verificada" e reprova. O check continua acusando a pendencia na origem.
            planos.append((p, PENDENTE if mirror._caixa(p) in pend_contrato else None))
            continue
        if not isinstance(reg, dict) or reg.get("estado") not in ("ok", "ausente"):
            planos.append((p, None))
            continue
        arquivos, tipo = reg.get("arquivos") or {}, reg.get("tipo") or "dir"
        if not isinstance(arquivos, dict) or tipo not in ("dir", "arquivo"):
            raise RestoreErro("indice de dados malformado no espelho: %r" % p)
        for k, v in arquivos.items():
            if not (k == p if tipo == "arquivo" else isinstance(k, str) and k.startswith(p + "/")):
                raise RestoreErro("arquivo de dados fora de '%s' no manifesto de espelho: %r" % (p, k))
            if not (isinstance(v, list) and len(v) == 3 and isinstance(v[0], int) and isinstance(v[2], str)
                    and mirror.MD5_RE.match(v[2])):
                raise RestoreErro("registro de dados malformado no espelho: %r" % k)
            _caminho_seguro(destino, k)
        planos.append((p, dict(reg, tipo=tipo, arquivos=arquivos)))
    return m, planos


def _baixar_dados(contrato, store, destino, m, planos, rel):
    """Baixa cada data.path do espelho para <destino>/<path> e confere tamanho e md5 de cada arquivo.
    Arquivo que o Git/WIP ja trouxe com o mesmo conteudo nao e baixado; com conteudo diferente nao
    e sobrescrito: vira conflito e reprova."""
    if m is None:
        if planos:
            rel["verificacoes"].append({"o_que": "dados cloud-mirror no restore", "ok": False,
                                        "motivo": "nenhum espelho de dados verificado na nuvem"})
        return
    confere = lambda dst, v: os.path.isfile(dst) and os.path.getsize(dst) == v[0] and cloud._md5(dst) == v[2]
    for p, reg in planos:
        o_que = "dados '%s': tamanho e md5 iguais ao espelho de %s" % (p, m["ts"])
        if reg is PENDENTE:
            rel["verificacoes"].append({"o_que": "dados '%s': decisao pendente, nao restaurado" % p, "ok": True,
                                        "motivo": "o espelho de %s registra decisao pendente: nada foi enviado" % m["ts"]})
            continue
        if reg is None:
            rel["verificacoes"].append({"o_que": o_que, "ok": False, "motivo": "sem copia verificada no espelho"})
            continue
        prefixo = mirror.unidade(p, reg["tipo"])
        baixar, conflitos = [], []
        for k, v in sorted(reg["arquivos"].items()):
            dst = _caminho_seguro(destino, k)
            if not os.path.exists(dst):
                baixar.append(k)
            elif not confere(dst, v):
                conflitos.append(k)
        erro = None
        try:
            store.baixar_lote(mirror.destino(contrato, prefixo), [mirror.sub(k, prefixo) for k in baixar],
                              _caminho_seguro(destino, prefixo) if prefixo else destino)
        except (cloud.NuvemErro, OSError) as e:
            erro = str(e)[:300]
        divergentes = [k for k in baixar if not confere(_caminho_seguro(destino, k), reg["arquivos"][k])]
        v = {"o_que": o_que, "ok": not (divergentes or conflitos or erro), "arquivos": len(reg["arquivos"]),
             "baixados": len(baixar), "divergentes": divergentes[:50]}
        if conflitos:
            v["conflitos"] = conflitos[:50]
            v["motivo"] = "o restore do Git/WIP ja trouxe esses arquivos com outro conteudo; nada foi sobrescrito"
        if erro:
            v["erro"] = erro
        rel["verificacoes"].append(v)
        rel["fontes"].append("cloud:" + reg.get("destino", mirror.destino(contrato, p)))


def restaurar(contrato, store, destino, manifesto=None, fonte="auto", log=print, com_dados=False):
    """com_dados: tambem baixa o ultimo espelho cloud-mirror (pesado; a certificacao NAO usa)."""
    pid = contrato["identity"]["id"]
    m = manifesto or bk.ultimo_manifesto(store, pid)
    if not m:
        raise RestoreErro("%s: nenhum backup na nuvem" % pid)
    _validar_manifesto(m, pid, destino)
    espelho, planos = _planejar_dados(contrato, store, destino) if com_dados else (None, [])
    if os.path.exists(destino) and os.listdir(destino):
        raise RestoreErro("destino nao esta vazio: %s (restore nunca sobrescreve)" % destino)
    os.makedirs(destino, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="eos-rest-")
    rel = {"project": pid, "manifest": m["timestamp"], "destino": destino, "fontes": [], "verificacoes": []}
    try:
        remoto = ((contrato.get("git") or {}).get("remote") or "").strip()
        pai = os.path.dirname(os.path.abspath(destino))
        # --- historico ---
        if m.get("unborn"):
            gitinfo.git(pai, "-c", "init.defaultBranch=main", "init", "-q", destino)
            _git_init_config(destino)
            if m.get("branch"):
                gitinfo.git(destino, "symbolic-ref", "HEAD", "refs/heads/" + _ref_valida(destino, m["branch"]))
        else:
            bundle = None
            if "git_bundle" in m["artifacts"]:
                bundle = _baixar_conferido(store, m["artifacts"]["git_bundle"], os.path.join(tmp, pid + ".bundle"))
            if fonte == "github" and not remoto:
                raise RestoreErro("fonte github pedida, mas o contrato nao declara remoto")
            if fonte in ("github", "auto") and remoto:
                gitinfo.git(pai, "-c", "core.autocrlf=false", "-c", "core.symlinks=false", "clone", "-q", "--no-checkout", remoto, destino, timeout=1800)
                # o clone so cria localmente a branch padrao; as outras ficariam em refs/remotes/origin
                # e a verificacao de refs as acusaria como faltando (achado na r11, ao cobrir QA7).
                # Clone recem-criado: nada local a sobrescrever
                gitinfo.git(destino, "fetch", "-q", "--update-head-ok", "origin", "+refs/heads/*:refs/heads/*",
                            "+refs/tags/*:refs/tags/*", timeout=1800)
                rel["fontes"].append("github:" + remoto)
            elif bundle:
                gitinfo.git(pai, "-c", "core.autocrlf=false", "-c", "core.symlinks=false", "clone", "-q", "--no-checkout", bundle, destino)
                rel["fontes"].append("cloud:" + m["artifacts"]["git_bundle"]["rel"])
            else:
                raise RestoreErro("sem fonte de historico (sem remoto e sem bundle)")
            _git_init_config(destino)
            if bundle and fonte != "github":
                gitinfo.git(destino, "fetch", "-q", "--update-head-ok", bundle, "+refs/heads/*:refs/heads/*",
                            "+refs/tags/*:refs/tags/*", "+refs/preservado/*:refs/preservado/*")
                if fonte == "auto" and remoto:
                    rel["fontes"].append("cloud:" + m["artifacts"]["git_bundle"]["rel"] + " (refs complementares)")
            elif bundle:
                # refs/preservado/* nunca vai ao remoto: a UNICA fonte dela e o bundle, inclusive com
                # fonte=github (r10, QA-A1)
                gitinfo.git(destino, "fetch", "-q", bundle, "+refs/preservado/*:refs/preservado/*")
            alvo = m.get("branch") or None
            if alvo:
                gitinfo.git(destino, "checkout", "-q", "-B", _ref_valida(destino, alvo), m["head"])
            else:
                gitinfo.git(destino, "checkout", "-q", "--detach", m["head"])
            atuais = gitinfo.refs(destino)
            faltam = [r for r, sha in m["refs"].items()
                      if r.startswith(("refs/heads/", "refs/tags/", gitinfo.PRESERVADO)) and atuais.get(r) != sha]
            rel["verificacoes"].append({"o_que": "refs locais iguais ao manifesto", "ok": not faltam, "faltam": faltam})
            ok_head = gitinfo.git(destino, "rev-parse", "HEAD").strip() == m["head"]
            rel["verificacoes"].append({"o_que": "HEAD restaurado = HEAD do manifesto", "ok": ok_head})
            if m.get("stash"):
                rel["verificacoes"].append({"o_que": "stash restaurado", "ok": False,
                                            "motivo": "o motor nao protege stash (%d entrada(s) no backup)" % m["stash"]})
        # --- WIP ---
        if "wip" in m["artifacts"]:
            t = _baixar_conferido(store, m["artifacts"]["wip"], os.path.join(tmp, "wip.tar.gz"))
            ext = os.path.join(tmp, "wip")
            with tarfile.open(t, "r:gz") as tar:
                for membro in tar.getmembers():
                    nome = membro.name.replace("\\", "/")
                    if nome.startswith("/") or ".." in nome.split("/") or not (membro.isfile() or membro.isdir()):
                        raise RestoreErro("membro suspeito no tar de WIP: %s" % membro.name)
                tar.extractall(ext, filter="data")
            for item in m.get("wip_index", []):
                base = os.path.join(ext, item["rotulo"])
                if item["rotulo"] == "main":
                    alvo_wt = destino
                else:
                    alvo_wt = _caminho_seguro(destino, ".eos-worktrees/" + item["rotulo"])
                    br = (item.get("branch") or "").replace("refs/heads/", "")
                    if br:
                        gitinfo.git(destino, "worktree", "add", "-q", alvo_wt, _ref_valida(destino, br))
                    else:
                        gitinfo.git(destino, "worktree", "add", "-q", "--detach", alvo_wt, item["head"])
                staged = os.path.join(base, "staged.patch")
                if os.path.isfile(staged) and os.path.getsize(staged) > 0:
                    gitinfo.git(alvo_wt, "apply", "--cached", "--binary", staged)
                arquivos = os.path.join(base, "files")
                for rel_f, sha in item["arquivos"].items():
                    src = _caminho_seguro(arquivos, rel_f)
                    dst = _caminho_seguro(alvo_wt, rel_f)
                    if gitinfo.sha256_arquivo(src) != sha:
                        raise RestoreErro("arquivo do WIP diverge do indice: %s" % rel_f)
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    shutil.copyfile(src, dst)
                for rem in item.get("removidos", []):
                    p = _caminho_seguro(alvo_wt, rem)
                    if os.path.isfile(p):
                        os.remove(p)  # replica remocao nao commitada; caminho ja contido no destino
                # intent-to-add ('git add -N'): sem refazer, o arquivo volta como nao rastreado e a
                # impressao diverge (achado pela certificacao do G2, 2026-10-11)
                for ita in item.get("intencao", []):
                    _caminho_seguro(alvo_wt, ita)
                    gitinfo.git(alvo_wt, "add", "--intent-to-add", "--", ":(literal)" + ita.replace("\\", "/"))
                imp = gitinfo.impressao_wip(alvo_wt)
                ok = imp == item["impressao_wip"]
                rel["verificacoes"].append({"o_que": "impressao do WIP de '%s' igual a do manifesto" % item["rotulo"], "ok": ok})
                if item.get("nao_enviados"):
                    rel["verificacoes"].append({"o_que": "WIP de '%s' completo" % item["rotulo"], "ok": False,
                                                "motivo": "arquivos com nome de segredo nao foram enviados: %s" % item["nao_enviados"][:5]})
            rel["fontes"].append("cloud:" + m["artifacts"]["wip"]["rel"])
        # --- bancos ---
        for db in m.get("databases", []):
            if "rel" not in db:
                rel["verificacoes"].append({"o_que": "banco %s presente no backup" % db["path"], "ok": False})
                continue
            dst = _caminho_seguro(destino, db["path"])
            gz = _baixar_conferido(store, db, os.path.join(tmp, "db.gz"))
            parcial = os.path.join(tmp, "db.restaurado")
            with gzip.open(gz, "rb") as fi, open(parcial, "wb") as fo:
                shutil.copyfileobj(fi, fo, 1 << 20)
            ok_sha = gitinfo.sha256_arquivo(parcial) == db["sha256_db"]
            con = sqlite3.connect("file:" + parcial.replace("\\", "/") + "?mode=ro", uri=True)
            try:
                integ = con.execute("PRAGMA integrity_check").fetchone()[0]
            finally:
                con.close()
            if ok_sha and integ == "ok":
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(parcial, dst)
            rel["verificacoes"].append({"o_que": "banco %s: hash e integrity_check" % db["path"],
                                        "ok": ok_sha and integ == "ok", "integrity_check": integ})
            rel["fontes"].append("cloud:" + db["rel"])
        # --- dados cloud-mirror (so com --com-dados) ---
        if com_dados:
            _baixar_dados(contrato, store, destino, espelho, planos, rel)
        if m.get("incompleto"):
            rel["verificacoes"].append({"o_que": "backup completo", "ok": False, "pendencias": m.get("pendencias", [])})
        rel["ok"] = all(v["ok"] for v in rel["verificacoes"]) and bool(rel["verificacoes"] or m.get("unborn"))
        return rel
    finally:
        gitinfo.remover_arvore(tmp)
