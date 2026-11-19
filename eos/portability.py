"""Portabilidade: CHECK (rapido, fatos atuais) e CERTIFY (prova por restauracao isolada).

Niveis (cumulativos - um nivel exige todos os anteriores):
  L0 Local Only               existe so aqui
  L1 Git Versioned            repositorio com pelo menos um commit
  L2 Remote Protected         remoto PRIVADO alcancavel e toda branch/tag local publicada
  L3 Data Protected           na nuvem: bundle com as refs atuais, WIP atual (impressao
                              digital igual) e bancos declarados com snapshot atual
  L4 Environment Reproducible manifesto de ambiente + bootstrap declarados e presentes;
                              manifesto de segredos (so nomes) presente; nenhum .env rastreado
  L5 Session Independent      estado canonico neutro de provedor presente e nao mais velho que
                              o ultimo commit
  L6 Disaster Recovery Tested certificacao por restauracao isolada, aprovada, nos ultimos 30
                              dias, com o projeto ainda em L5

Regra que nao se negocia: "nao consegui verificar" NUNCA conta como passou. Cada dimensao e
PASS, WARN, FAIL ou UNKNOWN, e UNKNOWN bloqueia o nivel que depende dela.
"""
import datetime
import json
import os
import platform
import shutil
import subprocess
import tempfile
import time
import urllib.parse

from . import backup as bk
from . import cofre, gitinfo, mirror, ownership, paths, restore

PASS, WARN, FAIL, UNKNOWN = "PASS", "WARN", "FAIL", "UNKNOWN"
CERT_VALIDADE_DIAS = 30


def _dim(status, motivo, **extra):
    d = {"status": status, "motivo": motivo}
    d.update(extra)
    return d


def _visibilidade_github(url):
    """private/public via gh. UNKNOWN se nao der para perguntar."""
    import re
    m = re.match(r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$", url or "")
    if not m:
        return None
    gh = shutil.which("gh") or r"C:\Program Files\GitHub CLI\gh.exe"
    try:
        r = subprocess.run([gh, "repo", "view", "%s/%s" % m.groups(), "--json", "isPrivate"],
                           capture_output=True, timeout=60)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    return "private" if json.loads(r.stdout.decode()).get("isPrivate") else "public"


def _idade_horas(ts):
    t = datetime.datetime.strptime(ts, "%Y%m%dT%H%M%SZ").replace(tzinfo=datetime.timezone.utc)
    return (datetime.datetime.now(datetime.timezone.utc) - t).total_seconds() / 3600


# Arquivos de PROVENIENCIA (ADR-0018): commit que so mexe neles e metadado, nao trabalho, e nao
# torna o STATE.md desatualizado. Achado real (r9): o commit de ownership em 20 repos derrubou para
# L4 projetos cujo STATE estava em WIP da titular e nao podia ser tocado.
SO_PROVENIENCIA = ("PROVENANCE.md", "OWNERSHIP.md", "AUTHORS.md", "AUTHORS", "NOTICE", ".github/CODEOWNERS")


class CommitNaoVerificavel(RuntimeError):
    pass


def _ultimo_commit_epoch(raiz, contrato=None):
    """Epoch do ultimo commit que toca algo ALEM dos arquivos de proveniencia (None = nenhum).
    Pathspec LITERAL (glob em provenance_file excluiria tudo) e erro do git levanta
    CommitNaoVerificavel: nunca vira "sem commit", que daria PASS sem comparar (r10, QA-A3)."""
    from . import contract
    prov = ((contrato or {}).get("ownership") or {}).get("provenance_file")
    if prov is not None:
        motivo = contract.motivo_caminho_relativo(prov)
        if motivo:
            raise CommitNaoVerificavel("ownership.provenance_file invalido: " + motivo)
    excl = [":(exclude,literal)%s" % f for f in SO_PROVENIENCIA + ((prov.replace("\\", "/"),) if prov else ())]
    try:
        rc, s = gitinfo.git(raiz, "log", "-1", "--format=%ct", "--", ".", *excl, check=False)
    except gitinfo.GitErro as e:
        raise CommitNaoVerificavel(str(e)[:200])
    if rc != 0:
        raise CommitNaoVerificavel("git log falhou (rc=%s)" % rc)
    s = s.strip()
    try:
        return int(s) if s else None
    except ValueError:
        raise CommitNaoVerificavel("git log devolveu algo que nao e epoch")


def verificar(contrato, store, maquina=None, rede=True):
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    ident = contrato["identity"]
    pid = ident["id"]
    r = {"project": pid, "type": ident["type"], "verificado_em": bk.carimbo(), "dimensoes": {}, "bloqueios": []}
    dims = r["dimensoes"]
    if ident["type"] != "PROJECT":
        r["nivel"] = None
        r["observacao"] = "niveis L0-L6 se aplicam a PROJECT; %s e classificado, nao certificado" % ident["type"]
        return r
    try:
        raiz = paths.caminho_local(contrato, maquina)
    except paths.CaminhoNaoResolvido as e:
        dims["paths"] = _dim(FAIL, str(e))
        raiz = None
    excluir = (contrato.get("backup") or {}).get("exclude") or []
    permitidos = (contrato.get("secrets") or {}).get("allowed_paths") or []
    fatos = gitinfo.resumo(raiz, excluir, permitidos) if raiz else {"existe": False}
    r["caminho"] = raiz
    # --- git ---
    if not fatos.get("existe"):
        dims["git"] = _dim(FAIL, "caminho local nao existe nesta maquina")
    elif not fatos.get("repo"):
        dims["git"] = _dim(FAIL, "nao e repositorio Git")
    elif not fatos.get("tem_commit"):
        dims["git"] = _dim(FAIL, "repositorio sem nenhum commit (unborn): Git existir nao e protecao")
    else:
        dims["git"] = _dim(PASS, "%d ref(s), HEAD %s" % (len(fatos["refs"]), fatos["head"][:8]))
    sujos = [w for w in fatos.get("worktrees", []) if w.get("sujo")]
    # --- remote ---
    url = ((contrato.get("git") or {}).get("remote") or "").strip()
    if dims["git"]["status"] != PASS:
        dims["remote"] = _dim(FAIL, "sem historico para publicar")
    elif not url:
        dims["remote"] = _dim(FAIL, "nenhum remoto declarado")
    elif _remotos_divergentes(fatos["remotos_completos"], url):
        dims["remote"] = _dim(FAIL, _remotos_divergentes(fatos["remotos_completos"], url))
    elif not rede:
        dims["remote"] = _dim(UNKNOWN, "verificacao sem rede")
    else:
        vis = _visibilidade_github(url)
        try:
            heads = gitinfo.ls_remote(raiz)
            faltam = gitinfo.nao_publicados(raiz, heads)
        except gitinfo.GitErro as e:
            heads, faltam = None, None
            dims["remote"] = _dim(UNKNOWN, "ls-remote falhou: %s" % str(e)[:200])
        if heads is not None:
            if vis is None:
                dims["remote"] = _dim(UNKNOWN, "visibilidade do remoto nao confirmada pela API")
            elif vis != "private":
                dims["remote"] = _dim(FAIL, "remoto PUBLICO")
            elif faltam:
                dims["remote"] = _dim(FAIL, "%d ref(s) local(is) nao publicada(s)" % len(faltam), faltam=faltam[:20])
            else:
                dims["remote"] = _dim(PASS, "privado, todas as branches e tags publicadas")
    # --- backup (nuvem) ---
    try:
        m = bk.ultimo_manifesto(store, pid)
    except Exception as e:
        m = None
        dims["backup"] = _dim(UNKNOWN, "nuvem indisponivel: %s" % str(e)[:200])
    if "backup" not in dims:
        problemas = []
        if not m:
            dims["backup"] = _dim(FAIL, "nenhum backup na nuvem")
        else:
            if fatos.get("tem_commit"):
                atuais = gitinfo.refs_do_projeto(fatos["refs"])
                salvos = gitinfo.refs_do_projeto(m["refs"])
                if atuais != salvos:
                    problemas.append("refs mudaram desde o ultimo bundle")
            if fatos.get("stash"):
                problemas.append("%d entrada(s) de stash: o motor nao protege stash" % len(fatos["stash"]))
            if fatos.get("tem_commit"):
                salvos_sha = set(m["refs"].values()) | {w.get("head") for w in m.get("worktrees", []) if w.get("head")}
                for w in fatos.get("worktrees", []):
                    h = w.get("head")
                    if h and h not in salvos_sha and not any(
                            gitinfo.objeto_existe(raiz, s_) and gitinfo.eh_ancestral(raiz, h, s_) for s_ in m["refs"].values()):
                        problemas.append("HEAD da worktree %s (%s) nao esta no ultimo bundle" % (os.path.basename(w["caminho"]), h[:8]))
            for g_ in fatos.get("gitlinks", []):
                problemas.append("submodulo/repositorio embutido '%s': os commits dele nao estao no bundle" % g_)
            for w in sujos:
                for x in w.get("nao_protegiveis") or []:
                    problemas.append("%s: %s nao e protegivel pelo motor" % (os.path.basename(w["caminho"]), x))
            impressoes = {w.get("impressao_wip") for w in m.get("wip_index", [])}
            for w in sujos:
                if w["impressao_wip"] not in impressoes:
                    problemas.append("WIP de %s nao esta no ultimo snapshot" % os.path.basename(w["caminho"]))
            mesma_origem = (str(m.get("machine") or "").lower() == str(os.environ.get("COMPUTERNAME") or platform.node()).lower()
                            and os.path.normcase(os.path.abspath(m.get("source_path") or "")) == os.path.normcase(os.path.abspath(raiz or "")))
            for db in ((contrato.get("state") or {}).get("databases") or []):
                reg = next((d for d in m.get("databases", []) if d["path"] == db["path"]), None)
                if reg and "rel" in reg and not mesma_origem:
                    problemas.append("snapshot de %s vem de outra maquina ou caminho (%s em %s): nao prova nada sobre este banco"
                                     % (db["path"], m.get("source_path"), m.get("machine")))
                    continue
                src = os.path.join(raiz, db["path"]) if raiz else None
                if not reg or "rel" not in reg:
                    problemas.append("banco %s sem snapshot" % db["path"])
                # '!=' e nao '>': mtime RECUADO (copia antiga por cima) tambem e banco diferente do snapshot
                elif src and os.path.isfile(src) and bk.mtime_do_banco(src) != reg["mtime_origem"]:
                    problemas.append("banco %s mudou depois do snapshot" % db["path"])
                elif db.get("max_age_hours") and _idade_horas(m["timestamp"]) > db["max_age_hours"]:
                    problemas.append("snapshot de %s mais velho que %dh" % (db["path"], db["max_age_hours"]))
            if m.get("incompleto"):
                problemas.append("ultimo backup marcado incompleto")
            dims["backup"] = (_dim(FAIL, "; ".join(problemas), ultimo=m["timestamp"]) if problemas
                              else _dim(PASS, "bundle, WIP e bancos atuais na nuvem", ultimo=m["timestamp"]))
    # --- environment / secrets / paths ---
    env = contrato.get("environment") or {}
    sec = contrato.get("secrets") or {}
    falta_env = []
    if not env:
        falta_env.append("environment nao declarado")
    else:
        for campo in ("manifest", "bootstrap"):
            v = env.get(campo)
            if env.get("runtime") not in ("none",) and not v:
                falta_env.append("environment.%s nao declarado" % campo)
            elif v and raiz and campo == "manifest" and not os.path.exists(os.path.join(raiz, v)):
                falta_env.append("%s nao existe" % v)
    dims["environment"] = _dim(FAIL if falta_env else PASS, "; ".join(falta_env) or "manifesto e bootstrap declarados")
    falta_sec = []
    if not sec:
        falta_sec.append("secrets nao declarado")
    elif sec.get("store") != "none" and raiz and not os.path.isfile(os.path.join(raiz, sec["manifest"])):
        falta_sec.append("%s nao existe" % sec["manifest"])
    if raiz and fatos.get("tem_commit"):
        rastreados = gitinfo.git(raiz, "ls-files").splitlines()
        envs = [f for f in rastreados if _segredo_rastreado(f, permitidos)]
        if envs:
            falta_sec.append("arquivo de segredo RASTREADO: %s" % ", ".join(envs[:5]))
    if raiz and fatos.get("tem_commit"):
        hist = [c for c in gitinfo.segredos_no_historico(raiz, permitidos) if c not in envs]
        if hist:
            falta_sec.append("nome de segredo no HISTORICO (vai no bundle): %s" % ", ".join(hist[:5]))
    for w in fatos.get("worktrees", []):
        if w.get("segredos"):
            falta_sec.append("nome de segredo no WIP nao ignorado em %s: %s" % (os.path.basename(w["caminho"]), ", ".join(w["segredos"][:5])))
    dims["secrets"] = _dim(FAIL if falta_sec else PASS, "; ".join(falta_sec) or "manifesto de nomes presente, nada rastreado")
    if "paths" not in dims:
        ov = ((maquina.get("projects") or {}).get(pid) or {}).get("local_path")
        bruto = ov or (contrato.get("workspace") or {}).get("local_path") or ""
        if not raiz:
            dims["paths"] = _dim(FAIL, "caminho local nao resolvido")
        elif not ov and "${" not in bruto:
            dims["paths"] = _dim(FAIL, "caminho fixo de maquina no contrato: use ${AI_WORKSPACE}, ${USERPROFILE}...")
        else:
            dims["paths"] = _dim(PASS, "caminho desta maquina (machine.yaml)" if ov else
                                 "caminho local resolvido por variavel (%s)" % (bruto.split("}")[0] + "}"))
    # --- state (independencia de sessao) ---
    can = (contrato.get("ai") or {}).get("canonical") or []
    if not can or not raiz:
        dims["state"] = _dim(FAIL, "estado canonico nao declarado")
    else:
        ausentes = [c for c in can if not os.path.exists(os.path.join(raiz, c))]
        state_md = next((c for c in can if c.lower().endswith("state.md")), None)
        erro_ult = None
        try:
            ult = _ultimo_commit_epoch(raiz, contrato) if fatos.get("tem_commit") else None
        except CommitNaoVerificavel as e:
            ult, erro_ult = None, str(e)[:200]
        if ausentes:
            dims["state"] = _dim(FAIL, "ausente(s): %s" % ", ".join(ausentes))
        elif state_md and ult and os.path.getmtime(os.path.join(raiz, state_md)) + 86400 < ult:
            dims["state"] = _dim(WARN, "%s mais velho que o ultimo commit por mais de 1 dia" % state_md)
        elif erro_ult:
            dims["state"] = _dim(UNKNOWN, "idade do estado frente ao ultimo commit nao verificavel: %s" % erro_ult)
        else:
            dims["state"] = _dim(PASS, "estado canonico presente")
    # --- recovery ---
    try:
        cert = bk.ultima_certificacao(store, pid)
    except Exception:
        cert = None
    if not cert:
        dims["recovery"] = _dim(FAIL, "nunca certificado por restauracao")
    elif not cert.get("ok"):
        dims["recovery"] = _dim(FAIL, "ultima certificacao reprovou", em=cert.get("timestamp"))
    elif _idade_horas(cert["timestamp"]) > CERT_VALIDADE_DIAS * 24:
        dims["recovery"] = _dim(WARN, "certificacao com mais de %d dias" % CERT_VALIDADE_DIAS, em=cert["timestamp"])
    else:
        dims["recovery"] = _dim(PASS, "certificado em %s" % cert["timestamp"], em=cert["timestamp"])
    # --- fontes externas (so OPERACAO) ---
    ext = []
    for s in contrato.get("external_sources") or []:
        loc = s.get("location")
        if loc and ("${" in loc or ":\\" in loc or loc.startswith("/")):
            try:
                disp = os.path.exists(paths.resolver(loc, maquina))
            except paths.CaminhoNaoResolvido:
                disp = None
        else:
            disp = None
        ext.append({"id": s["id"], "required": s["required_for_operation"], "disponivel": disp})
    r["fontes_externas"] = ext
    # --- ownership: INFORMATIVA. Fica FORA da escada abaixo de proposito: titularidade declarada
    # nao e protecao contra perda, e um projeto L6 sem secao ownership continua L6.
    try:
        o = ownership.verificar(contrato, maquina)
        dims["ownership"] = _dim(o["status"], "(informativa, fora da escada) " + o["resumo"], informativa=True,
                                 itens=[{"item": i["item"], "status": i["status"], "motivo": i["motivo"]} for i in o["itens"]])
    except Exception as e:
        dims["ownership"] = _dim(UNKNOWN, "(informativa) ownership nao verificado: %s" % str(e)[:200], informativa=True)
    # --- nivel ---
    ok = lambda d: dims.get(d, {}).get("status") == PASS
    escada = [("L1", ["git"]), ("L2", ["remote"]), ("L3", ["backup"]), ("L4", ["environment", "secrets", "paths"]),
              ("L5", ["state"]), ("L6", ["recovery"])]
    nivel = "L0" if fatos.get("existe") else None
    for nome, req in escada:
        if all(ok(d) for d in req):
            nivel = nome
        else:
            r["bloqueios"] = ["%s: %s" % (d, dims[d]["motivo"]) for d in req if not ok(d)]
            r["proximo_nivel"] = nome
            break
    r["nivel"] = nivel
    # --- respostas para gente ---
    wip_protegido = not sujos or (dims["backup"]["status"] == PASS)
    r["seguro_apagar_sessao"] = bool(ok("state") and wip_protegido)
    so_aqui = _so_nesta_pasta(contrato, raiz, fatos, store) if nivel in ("L3", "L4", "L5", "L6") else []
    r["so_nesta_pasta"] = so_aqui
    r["seguro_apagar_clone"] = bool(nivel in ("L3", "L4", "L5", "L6") and not so_aqui)
    # trocar de computador TAMBEM deixa esta pasta para tras: o que existe so aqui bloqueia os dois
    # (pre-revisao r3, ALTA: L5 respondia SIM com .env local e ignorado nao declarado)
    r["seguro_trocar_computador"] = bool(nivel in ("L5", "L6") and not so_aqui)
    r["motivos_nao"] = {
        "sessao": [] if r["seguro_apagar_sessao"] else
        ([] if ok("state") else ["estado canonico: " + dims["state"]["motivo"]]) +
        ([] if wip_protegido else ["trabalho nao commitado sem snapshot atual"]),
        "clone": [] if r["seguro_apagar_clone"] else (r["bloqueios"] if nivel not in ("L3", "L4", "L5", "L6") else so_aqui),
        "computador": [] if r["seguro_trocar_computador"] else (r["bloqueios"] if nivel not in ("L5", "L6") else so_aqui),
    }
    # --- seguranca x operacao ---
    r["safety"] = "SAFE" if nivel in ("L3", "L4", "L5", "L6") else ("AT_RISK" if nivel in ("L1", "L2") else "UNSAFE")
    indisponiveis = [e["id"] for e in ext if e["required"] and e["disponivel"] is False]
    r["operation"] = "DEGRADED" if (indisponiveis or dims["environment"]["status"] == FAIL) else "OK"
    if indisponiveis:
        r["operation_motivo"] = "fonte externa indisponivel: " + ", ".join(indisponiveis)
    return r


def _remotos_divergentes(completos, url):
    """None se o unico remoto e 'origin' e TODAS as URLs (fetch e push) sao a do contrato."""
    norm = lambda u: (u or "").rstrip("/").removesuffix(".git").lower()
    extras = sorted(n for n in completos if n != "origin")
    if extras:
        return "remoto(s) alem de origin nao declarado(s) no contrato: %s" % ", ".join(extras)
    o = completos.get("origin") or {"fetch": [], "push": []}
    urls = set(map(norm, o["fetch"] + o["push"]))
    if urls != {norm(url)}:
        return "origin aponta para %s, o contrato declara %s" % (sorted(urls) or "nada", url)
    return None


def _segredo_rastreado(f, permitidos=()):
    """A mesma regra do WIP (gitinfo.nome_de_segredo), aplicada aos arquivos rastreados."""
    return gitinfo.nome_de_segredo(f, permitidos)


def _so_nesta_pasta(contrato, raiz, fatos, store=None):
    """O que existe SO nesta pasta e o contrato nao cobre. Vazio = nada se perderia."""
    # cloud-mirror: coberto so pelo ultimo espelho ok que tem cada arquivo atual com o mesmo
    # tamanho e mtime (eos/mirror.py); sem store legivel, continua motivo
    try:
        motivos = mirror.motivos_so_aqui(contrato, raiz, store)
    except OSError as e:  # o check NUNCA estoura por E/S: vira motivo (falha fechada)
        motivos = ["espelho de dados nao verificavel nesta pasta: %s" % str(e)[:200]]
    sec = contrato.get("secrets") or {}
    if raiz and sec.get("store") == "local-env" and cofre.arquivos_locais(raiz):
        motivos.append("segredos com valor so nesta pasta (.env, store local-env): leve para o cofre antes")
    elif raiz and sec.get("store") == "bitwarden" and cofre.arquivos_locais(raiz):
        # coberto so se CADA .env local bate (sha256) com o ultimo manifesto de push para o cofre
        # (eos/cofre.py); nuvem ilegivel continua motivo (falha fechada)
        try:
            v = cofre.verificar_cofre(contrato, store, raiz=raiz)
            motivos += ["segredos com valor so nesta pasta: %s (rode secrets-push %s)" % (m, contrato["identity"]["id"])
                        for m in v["motivos"]]
        except Exception as e:
            motivos.append("cofre de segredos nao verificavel: %s" % str(e)[:200])
    if raiz and fatos.get("repo"):
        declarados = [d["path"] for d in contrato.get("data") or []]
        for db in ((contrato.get("state") or {}).get("databases") or []):
            declarados += [db["path"] + suf for suf in ("", "-wal", "-shm", "-journal")]
        # backup.exclude NAO e "pode perder": exclui do upload, e por isso o que existir ali e
        # nao for ignorado tambem e "so nesta pasta" (r2 do QA, achado 3)
        for w in fatos.get("worktrees", []):
            for x in w.get("excluidos_contrato") or []:
                motivos.append("'%s' esta em backup.exclude: nao sobe, e existe so nesta pasta" % x)
        if sec.get("store") in ("local-env", "bitwarden"):
            declarados += list(cofre.ARQUIVOS)  # ja reportados acima, com o motivo certo
        ign = []
        try:
            ign = gitinfo.ignorados_nao_declarados(raiz, declarados)
            # worktrees DENTRO da pasta somem junto com ela (r2 do QA, achado 7)
            raiz_n = os.path.normcase(os.path.abspath(raiz))
            for w in fatos.get("worktrees", [])[1:]:
                wp = os.path.normcase(os.path.abspath(w["caminho"]))
                if w.get("existe") and os.path.commonpath([raiz_n, wp]) == raiz_n:
                    ign += [os.path.relpath(os.path.join(w["caminho"], x), raiz).replace("\\", "/")
                            for x in gitinfo.ignorados_nao_declarados(w["caminho"], declarados)]
        except gitinfo.GitErro as e:
            ign.append("(nao consegui listar ignorados: %s)" % str(e)[:100])
        if ign:
            motivos.append("%d item(ns) ignorado(s) pelo Git e nao declarado(s) no contrato, ex.: %s"
                           % (len(ign), ", ".join(ign[:5])))
    return motivos


def _sem_valores_de_ambiente(texto, env):
    """Remove do texto que vai para a nuvem (cauda do smoke, erro do cert) qualquer valor de
    variavel de ambiente com 8+ caracteres, inclusive nas formas escapada para JSON e codificada
    para URL, que e como um teste costuma imprimir o valor (r4 do security, achado 4)."""
    formas = set()
    for v in (v for v in env.values() if v and len(v) >= 8):
        formas |= {v, json.dumps(v)[1:-1], json.dumps(v, ensure_ascii=False)[1:-1], repr(v)[1:-1],
                   urllib.parse.quote(v, safe=""), urllib.parse.quote(v), urllib.parse.quote_plus(v, safe=""),
                   urllib.parse.quote_plus(v)}
    for f in sorted((f for f in formas if len(f) >= 8), key=len, reverse=True):
        texto = texto.replace(f, "<redigido>")
    return texto


def _sem_caminho_nem_valor(texto, env):
    """Redige valor de ambiente E caminho da maquina ANTES de quem chama cortar o texto (r13, S1):
    cortado primeiro, a cauda pode comecar no meio da pasta do usuario ('na/Documents/...' de 'C:/Users/Ana'), e o
    fragmento ja nao casa com a grafia inteira que `paths.redigir` procura depois."""
    return paths.redigir_caminhos(_sem_valores_de_ambiente(texto, env))


def certificar(contrato, store, maquina=None, log=print, manter=False):
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    pid = contrato["identity"]["id"]
    ts = bk.carimbo()
    antes = verificar(contrato, store, maquina)
    destino = os.path.join(tempfile.gettempdir(), "eos-cert-%s-%s" % (pid, ts))
    c = {"project": pid, "timestamp": ts, "destino": destino, "nivel_antes": antes["nivel"], "ok": False}
    # So remove no fim o que ELA criou: um destino preexistente nunca e apagado (r1 do security)
    criado_aqui = not os.path.exists(destino)
    try:
        rest = restore.restaurar(contrato, store, destino, fonte="auto", log=log)
        c["restore"] = rest
        verif = list(rest["verificacoes"])
        can = (contrato.get("ai") or {}).get("canonical") or []
        aus = [x for x in can if not os.path.exists(os.path.join(destino, x))]
        verif.append({"o_que": "contexto reconstruivel sem a conversa (arquivos canonicos no restore)", "ok": not aus, "faltam": aus})
        smoke = (contrato.get("environment") or {}).get("smoke_command")
        if smoke:
            env = dict(os.environ, PROJECT_ROOT=destino, EOS_CERTIFY="1")
            t0 = time.time()
            p = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", smoke],
                               cwd=destino, capture_output=True, env=env, timeout=3600)
            saida = (p.stdout + p.stderr).decode("utf-8", "replace")
            c["smoke"] = {"comando": smoke, "rc": p.returncode, "segundos": round(time.time() - t0, 1),
                          "cauda": _sem_caminho_nem_valor(saida, env)[-2000:]}
            verif.append({"o_que": "smoke/test no restore", "ok": p.returncode == 0})
        else:
            verif.append({"o_que": "smoke/test no restore", "ok": False, "motivo": "environment.smoke_command nao declarado"})
        c["verificacoes"] = verif
        c["ok"] = rest["ok"] and all(v["ok"] for v in verif)
    except Exception as e:
        # str(e), e nao repr(e): o repr escolhe aspas e escapes pela mensagem inteira, e a forma
        # do valor dentro dele nao e previsivel
        c["erro"] = _sem_caminho_nem_valor(type(e).__name__ + ": " + str(e), os.environ)[:500]
    finally:
        if not manter and criado_aqui:
            c["destino_removido"] = gitinfo.remover_arvore(destino)
    c["manifesto_usado"] = (c.get("restore") or {}).get("manifest")
    # o que vai para a nuvem sai sem caminho da maquina (%TEMP%, pasta do usuario) em parte nenhuma
    # (r12, Sec3); o `c` devolvido a quem chamou continua com o `destino` real (o CLI nao o imprime)
    store.escrever_texto("/".join([bk.RECOVERY, "manifests", pid, "cert-%s.json" % ts]),
                         json.dumps(paths.redigir(c), ensure_ascii=False, indent=2))
    c["nivel_depois"] = verificar(contrato, store, maquina)["nivel"]
    return c
