"""Motor de backup: tres necessidades diferentes, tres artefatos diferentes (programa §13).

  A. historico Git   -> 99 RECOVERY/git-recovery/<id>/<ts>/<id>.bundle   (bundle --all)
  B. WIP             -> 99 RECOVERY/wip-snapshots/<id>/<ts>/wip.tar.gz    (todas as worktrees)
  C. estado (DB)     -> 99 RECOVERY/database-snapshots/<id>/<ts>/<nome>.gz
  manifesto          -> 99 RECOVERY/manifests/<id>/<ts>.json             (GRAVADO POR ULTIMO)

O manifesto e o ponto de commit: um backup existe se, e somente se, o manifesto existe, e o
manifesto so e gravado depois de todo artefato ter subido E sido conferido por hash. Execucao
interrompida deixa artefato orfao sem manifesto - lixo, nunca falsa protecao.

O que o motor NAO consegue proteger nao e omitido: vai para `manifesto.pendencias`, e o backup
fica `incompleto`. O check le isso e reprova. Casos (r1 do QA e do Security):
  - arquivo com nome de segredo no WIP: NAO sobe (backup sem criptografia no cliente, ADR-0013);
  - repositorio aninhado/submodulo e symlink no WIP: o restore nao os recriaria;
  - stash: o bundle leva so refs/stash, nunca o reflog com as outras entradas.

Leitura apenas sobre o projeto: bundle, status e diff com GIT_OPTIONAL_LOCKS=0; banco aberto
com mode=ro pela API de backup do SQLite (copia consistente com o banco em uso).
"""
import datetime
import gzip
import io
import json
import os
import platform
import re
import shutil
import sqlite3
import tarfile
import time

from . import gitinfo, paths

RECOVERY = "99 RECOVERY"
ROTULO_RE = re.compile(r"^[A-Za-z0-9._-]{1,80}$")
AVISO_CRIPTOGRAFIA = ("backup SEM criptografia no cliente (ADR-0013): vai em claro para o Drive privado; "
                      "arquivo com nome de segredo no WIP nao sobe, mas o que ja foi COMMITADO vai no bundle "
                      "(ver pendencias)")


def carimbo():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _rel(*partes):
    return "/".join(p.strip("/") for p in partes if p)


def mtime_do_banco(caminho):
    """Maior mtime entre o banco e os arquivos de journal/WAL.

    Em journal_mode=WAL o commit vai para <db>-wal e o arquivo principal so muda no checkpoint;
    olhar so o .db daria "nao mudou" com dado novo (r1 do QA, MEDIA 4)."""
    ms = [os.path.getmtime(caminho)]
    for suf in ("-wal", "-journal"):
        if os.path.exists(caminho + suf):
            ms.append(os.path.getmtime(caminho + suf))
    return max(ms)


def snapshot_sqlite(origem, destino):
    uri = "file:" + origem.replace("\\", "/") + "?mode=ro"
    src = sqlite3.connect(uri, uri=True)
    dst = sqlite3.connect(destino)
    try:
        src.backup(dst, pages=4096)
    finally:
        dst.close()
        src.close()
    chk = sqlite3.connect("file:" + destino.replace("\\", "/") + "?mode=ro", uri=True)
    try:
        integ = chk.execute("PRAGMA integrity_check").fetchone()[0]
        tabelas = chk.execute("select count(*) from sqlite_master where type='table'").fetchone()[0]
    finally:
        chk.close()
    if integ != "ok":
        raise RuntimeError("integrity_check do snapshot falhou: %s" % integ)
    return {"integrity_check": integ, "tabelas": tabelas}


def _gzip(src, dst):
    with open(src, "rb") as fi, gzip.open(dst, "wb", compresslevel=6) as fo:
        shutil.copyfileobj(fi, fo, 1 << 20)


def _tar_add_bytes(tar, nome, dados):
    info = tarfile.TarInfo(nome)
    info.size = len(dados)
    info.mtime = int(time.time())
    tar.addfile(info, io.BytesIO(dados))


def _rotulos(worktrees):
    """Rotulo unico e seguro por worktree: 'main' so para a principal (r1 do QA, BAIXA 9)."""
    usados, out = set(), {}
    for wt in worktrees:
        base = "main" if wt["principal"] else re.sub(r"[^A-Za-z0-9._-]", "_", os.path.basename(wt["caminho"].rstrip("\\/")))[:60] or "wt"
        if not wt["principal"] and base == "main":
            base = "wt-main"
        r, n = base, 2
        while r in usados:
            r, n = "%s-%d" % (base, n), n + 1
        usados.add(r)
        out[wt["caminho"]] = r
    return out


def empacotar_wip(fatos, excluir, destino_tar, permitidos=()):
    """Um tar.gz com o WIP de TODAS as worktrees sujas. Devolve (indice, pendencias)."""
    indice, pendencias = [], []
    rotulos = _rotulos(fatos["worktrees"])
    with tarfile.open(destino_tar, "w:gz") as tar:
        for wt in fatos["worktrees"]:
            if not wt.get("existe") or not wt.get("sujo"):
                continue
            p = wt["caminho"]
            rotulo = rotulos[p]
            w = gitinfo.wip(p, excluir, worktrees_internas=[x["caminho"] for x in fatos["worktrees"] if x["caminho"] != p],
                            permitidos=permitidos)
            for x in w["segredos"]:
                pendencias.append("%s: '%s' tem nome de segredo e NAO foi enviado (ignore no projeto ou declare em backup.exclude)" % (rotulo, x))
            for x in w["aninhados"]:
                pendencias.append("%s: repositorio aninhado/submodulo '%s' nao e protegido pelo WIP" % (rotulo, x))
            for x in w["symlinks"]:
                pendencias.append("%s: symlink '%s' nao e protegido (o restore recusa link)" % (rotulo, x))
            _tar_add_bytes(tar, rotulo + "/status.txt", w["status"].encode("utf-8"))
            if fatos.get("tem_commit"):
                # pathspec que EXCLUI cada segredo: sem isto o conteudo do segredo staged ou rastreado
                # subia dentro do patch, enquanto a pendencia dizia "NAO foi enviado" (r2 do security)
                # exclui do patch os segredos E o que o contrato exclui (inclusive rastreado: r4)
                excl = [":(exclude,literal)" + x.replace("\\", "/") for x in w["segredos"] + w["excluidos_contrato"]]
                staged = gitinfo.git(p, "diff", "--cached", "--binary", "--", ".", *excl, binario=True)
                _tar_add_bytes(tar, rotulo + "/staged.patch", staged)
                _tar_add_bytes(tar, rotulo + "/unstaged.patch", gitinfo.git(p, "diff", "--binary", "--", ".", *excl, binario=True))
            arquivos = {}
            segredos = set(w["segredos"])
            for rel in w["modificados"] + w["nao_rastreados"]:
                if rel in segredos:
                    continue
                fp = os.path.join(p, rel)
                sha_antes = gitinfo.sha256_arquivo(fp)
                tar.add(fp, arcname=rotulo + "/files/" + rel.replace("\\", "/"), recursive=False)
                arquivos[rel.replace("\\", "/")] = sha_antes
            # a impressao e calculada sobre o MESMO estado que foi empacotado: se algo mudou no
            # meio, a conferencia abaixo pega e o backup falha em vez de gravar impressao errada
            imp = gitinfo.impressao_wip(p, w, excluir)
            # o index nao pode ter mudado entre o patch e a impressao (pre-revisao r3, achado 9)
            if fatos.get("tem_commit") and gitinfo.git(p, "diff", "--cached", "--binary", "--", ".", *excl, binario=True) != staged:
                raise RuntimeError("o index mudou durante o backup - rode de novo")
            for rel, sha in arquivos.items():
                if gitinfo.sha256_arquivo(os.path.join(p, rel)) != sha:
                    raise RuntimeError("%s mudou durante o backup - rode de novo" % rel)
            indice.append({"rotulo": rotulo, "caminho": p, "branch": wt.get("branch"), "head": wt.get("head"),
                           "impressao_wip": imp, "arquivos": arquivos, "removidos": w["removidos"],
                           "excluidos": len(w["excluidos"]), "nao_enviados": sorted(segredos),
                           "intencao": [x for x in w["intencao"] if x not in segredos]})
    return indice, pendencias


def _listar_json(store, pid):
    return sorted(n for n in store.listar(_rel(RECOVERY, "manifests", pid)) if n.endswith(".json"))


def ultimo_manifesto(store, pid):
    # cert-<ts> (certificacao DR), ownership-<ts> (eos/ownership.py), mirror-<ts> (eos/mirror.py) e
    # cofre-<ts> (eos/cofre.py) moram na mesma pasta e NAO sao manifesto de backup: sem excluir, ordenam
    # depois do <ts> e viram o "ultimo backup"
    nomes = [n for n in _listar_json(store, pid) if not n.startswith(("cert-", "ownership-", "mirror-", "cofre-"))]
    if not nomes:
        return None
    return json.loads(store.ler_texto(_rel(RECOVERY, "manifests", pid, nomes[-1])))


def ultima_certificacao(store, pid):
    nomes = [n for n in _listar_json(store, pid) if n.startswith("cert-")]
    if not nomes:
        return None
    return json.loads(store.ler_texto(_rel(RECOVERY, "manifests", pid, nomes[-1])))


def backup(contrato, store, maquina=None, staging=None, log=print):
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    pid = contrato["identity"]["id"]
    raiz = paths.caminho_local(contrato, maquina)
    if not raiz or not os.path.isdir(raiz):
        raise RuntimeError("%s: caminho local nao existe nesta maquina (%s)" % (pid, raiz))
    excluir = (contrato.get("backup") or {}).get("exclude") or []
    permitidos = (contrato.get("secrets") or {}).get("allowed_paths") or []
    ts = carimbo()
    staging = staging or paths.resolver("${EOS_STAGING}", maquina)
    trabalho = os.path.join(staging, pid, ts)
    os.makedirs(trabalho, exist_ok=True)
    log("  aviso: " + AVISO_CRIPTOGRAFIA)
    fatos = gitinfo.resumo(raiz, excluir, permitidos)
    if not fatos.get("repo"):
        raise RuntimeError("%s: nao e repositorio Git - COLLECTION usa outro caminho" % pid)
    m = {"manifest_version": 1, "project": pid, "timestamp": ts, "source_path": raiz,
         "machine": os.environ.get("COMPUTERNAME") or platform.node(),
         "client_side_encryption": False, "aviso": AVISO_CRIPTOGRAFIA,
         "branch": fatos.get("branch"), "head": fatos.get("head"), "unborn": not fatos.get("tem_commit"),
         "refs": {k: v for k, v in fatos.get("refs", {}).items() if k != "refs/stash"}, "stash": len(fatos.get("stash", [])),
         "artifacts": {}, "worktrees": [], "databases": [], "pendencias": []}
    if fatos.get("tem_commit"):
        m["segredos_no_historico"] = gitinfo.segredos_no_historico(raiz, permitidos)
        for c in m["segredos_no_historico"][:20]:
            m["pendencias"].append("'%s' tem nome de segredo e esta no HISTORICO: vai no bundle; sanitizar e decisao humana (ADR-0015)" % c)
    for g in fatos.get("gitlinks", []):
        m["pendencias"].append("submodulo/repositorio embutido '%s': os commits dele nao vao no bundle do pai" % g)
    if fatos.get("stash"):
        m["pendencias"].append("%d entrada(s) de stash: o stash nao e protegido - aplique ou transforme em branch" % len(fatos["stash"]))
    # A. Git
    if fatos.get("tem_commit"):
        b = os.path.join(trabalho, pid + ".bundle")
        # refs/stash fica de fora: o stash pode carregar segredo de arquivo nao rastreado (r2 do
        # security, achado 2), e o motor ja declara que nao o protege
        gitinfo.git(raiz, "bundle", "create", b, "--exclude=refs/stash", "--all")
        gitinfo.git(raiz, "bundle", "verify", b)
        fora = [w["head"] for w in fatos["worktrees"] if w.get("head") and
                not any(gitinfo.eh_ancestral(raiz, w["head"], sha) for r_, sha in fatos["refs"].items() if r_ != "refs/stash")]
        if fora:
            raise RuntimeError("%s: HEAD de worktree fora de toda ref, o bundle nao o levaria: %s" % (pid, fora))
        rel = _rel(RECOVERY, "git-recovery", pid, ts, pid + ".bundle")
        up = store.put(b, rel)
        m["artifacts"]["git_bundle"] = {"rel": rel, "sha256": gitinfo.sha256_arquivo(b), "bytes": up["bytes"]}
        log("  git: bundle %.1f MB conferido" % (up["bytes"] / 1e6))
    # B. WIP
    m["worktrees"] = [{k: w.get(k) for k in ("caminho", "principal", "branch", "head", "locked", "sujo", "impressao_wip")}
                      for w in fatos["worktrees"]]
    if any(w.get("sujo") for w in fatos["worktrees"]):
        t = os.path.join(trabalho, "wip.tar.gz")
        m["wip_index"], pend = empacotar_wip(fatos, excluir, t, permitidos)
        m["pendencias"].extend(pend)
        rel = _rel(RECOVERY, "wip-snapshots", pid, ts, "wip.tar.gz")
        up = store.put(t, rel)
        m["artifacts"]["wip"] = {"rel": rel, "sha256": gitinfo.sha256_arquivo(t), "bytes": up["bytes"]}
        log("  wip: %d arvore(s) suja(s), %.1f MB conferido" % (len(m["wip_index"]), up["bytes"] / 1e6))
    # C. Bancos
    for db in ((contrato.get("state") or {}).get("databases") or []):
        src = os.path.join(raiz, db["path"])
        reg = {"path": db["path"], "engine": db["engine"]}
        if not os.path.isfile(src):
            reg["erro"] = "nao existe"
            m["pendencias"].append("banco declarado %s nao existe" % db["path"])
            m["databases"].append(reg)
            continue
        # mtime ANTES do snapshot: escrita durante a copia fica com mtime maior e o check a ve
        reg["mtime_origem"] = mtime_do_banco(src)
        snap = os.path.join(trabalho, os.path.basename(db["path"]))
        reg.update(snapshot_sqlite(src, snap))
        reg["sha256_db"] = gitinfo.sha256_arquivo(snap)
        reg["bytes_db"] = os.path.getsize(snap)
        gz = snap + ".gz"
        _gzip(snap, gz)
        rel = _rel(RECOVERY, "database-snapshots", pid, ts, os.path.basename(gz))
        up = store.put(gz, rel)
        reg.update(rel=rel, sha256=gitinfo.sha256_arquivo(gz), bytes=up["bytes"])
        m["databases"].append(reg)
        log("  db: %s integrity ok, %.1f MB -> %.1f MB gz conferido" % (db["path"], reg["bytes_db"] / 1e6, up["bytes"] / 1e6))
    if m["pendencias"]:
        m["incompleto"] = True
        for x in m["pendencias"]:
            log("  PENDENCIA: " + x)
    # Ponto de commit
    m["completed_at"] = carimbo()
    store.escrever_texto(_rel(RECOVERY, "manifests", pid, ts + ".json"), json.dumps(m, ensure_ascii=False, indent=2))
    gitinfo.remover_arvore(trabalho)
    return m
