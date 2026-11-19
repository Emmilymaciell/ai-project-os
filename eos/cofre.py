"""Cofre de segredos (Bitwarden CLI): leva o .env de um projeto para o cofre e de volta.

O VALOR de um segredo nunca aparece em argv, na saida do motor, em log, no manifesto ou em arquivo
temporario. Ele so trafega pelo STDIN do `bw` (JSON -> `bw encode` -> `bw create/edit item`) e pelo
stdout de `bw get/list`, lido em memoria. A sessao (BW_SESSION) vai so no ambiente do processo filho.

  item no cofre  Secure Note (type 2) "emmily-os/<id>/<arquivo>": notes = o arquivo inteiro, campo
                 "sha256" = hash do conteudo
  manifesto      99 RECOVERY/manifests/<id>/cofre-<ts>.json - SEM valores: arquivo, item, sha256 e os
                 NOMES das variaveis. Gravado POR ULTIMO, depois de reler cada item e conferir o hash.
                 Todo arquivo e lido e validado antes da primeira escrita; se o cofre ja mudou e algo
                 falha depois, fica um manifesto "incompleto": true, que o check acusa (r10, QA-A2)
  H1             login/unlock do Bitwarden e acao humana: sem sessao desbloqueada nada e feito
"""
import base64
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess

from . import backup as bk
from . import cloud, gitinfo, paths

PREFIXO = "emmily-os"
ARQUIVOS = (".env", ".env.local")
MANIFESTO = "cofre-"
CHAVE_RE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_.-]*)\s*=", re.M)
MSG_H1 = "H1: rode `bw login` e `bw unlock` e exporte BW_SESSION nesta sessao (o motor nunca faz login no cofre)"


class CofreErro(RuntimeError):
    pass


class SemSessao(CofreErro):
    """Cofre sem sessao desbloqueada: acao humana (H1)."""


class ConferenciaFalhou(CofreErro):
    """O cofre ou o arquivo gravado nao tem o conteudo que deveria (sha256 diferente)."""


def resolver_bw():
    """Executavel do Bitwarden CLI: PATH, depois o pacote do WinGet. None se nao houver."""
    p = shutil.which("bw")
    if p:
        return p
    base = os.path.join(os.environ.get("LOCALAPPDATA") or "", "Microsoft", "WinGet", "Packages")
    achados = sorted(glob.glob(os.path.join(base, "Bitwarden.CLI_*", "bw.exe")))
    return achados[-1] if achados else None


def nome_item(pid, arquivo):
    return "%s/%s/%s" % (PREFIXO, pid, arquivo)


def chaves(texto):
    """NOMES das variaveis de um .env, na ordem, sem repetir. Nunca os valores."""
    vistos = []
    for k in CHAVE_RE.findall(texto):
        if k not in vistos:
            vistos.append(k)
    return vistos


def _sha(dados):
    return hashlib.sha256(dados).hexdigest()


# valor entre aspas fechado na mesma linha e seguido de comentario: `"v" # nota` (r12, QA-A3)
ASPAS_COM_COMENTARIO = re.compile(r"""^(['"])(.*?)\1\s*#.*$""")


def _valores(texto):
    """Valores do .env (e linhas inteiras), so para REDIGIR mensagem de erro do bw. Inclui os
    curtos (1-3 caracteres): `_redigir` os trata so como token isolado (r10, A5/S-A7)."""
    out = {texto.strip()}
    aberto, partes = None, []
    for linha in texto.splitlines():
        if aberto:
            # continuacao de valor multilinha entre aspas (ex.: chave PEM): cada linha nao vazia e
            # o valor inteiro (r11, Sec3)
            s = linha.strip()
            fecha = s.endswith(aberto)
            s = s[:-1].strip() if fecha else s
            if s:
                out |= {s, linha.strip()}
                partes.append(s)
            # r12 (QA-A3): `CHAVE=valor` dentro do bloco tambem tem o VALOR extraido - se o bloco
            # foi aberto por engano, a linha e outra variavel, nao miolo de PEM
            m = CHAVE_RE.match(linha)
            if m:
                out.add(linha[m.end():].strip().strip("'\""))
            if fecha:
                out.add("\n".join(partes))
                aberto, partes = None, []
            continue
        if "=" in linha:
            bruto = linha.split("=", 1)[1].strip()
            # r12 (QA-A3): `CHAVE="v" # comentario` fecha a aspa na mesma linha: nao abre bloco
            fechado = ASPAS_COM_COMENTARIO.match(bruto)
            if fechado:
                out.add(fechado.group(2))
            elif bruto[:1] in ("'", '"') and not (len(bruto) > 1 and bruto.endswith(bruto[0])):
                aberto, partes = bruto[0], [bruto[1:].strip()] if bruto[1:].strip() else []
            v = bruto.strip("'\"")
            out |= {v, linha.strip()}
    if aberto and partes:
        out.add("\n".join(partes))  # aspa nunca fechada: o resto do arquivo e valor
    # r13 (QA3): linha base64 com padding dentro de PEM casa CHAVE_RE e extrai '=' ou '==' como
    # "valor"; redigir isso trocaria todo '=' da mensagem. Vazio ou so '=' nao e valor
    return sorted((v for v in out if v and v.strip("=")), key=len, reverse=True)


CURTO = 4  # abaixo disso, substituir em qualquer posicao destruiria a mensagem inteira


def _redigir(msg, segredos):
    """Troca cada valor por <redigido>: a forma literal E a forma escapada em JSON (o bw ecoa
    JSON: aspa e barra invertida do valor chegam escapadas). Valor curto so como token isolado."""
    for v in segredos:
        if not v:
            continue
        formas = {v, json.dumps(v, ensure_ascii=False)[1:-1], json.dumps(v)[1:-1]}
        for f in sorted(formas, key=len, reverse=True):
            if len(v) >= CURTO:
                msg = msg.replace(f, "<redigido>")
            else:
                msg = re.sub(r"(?<![A-Za-z0-9_])" + re.escape(f) + r"(?![A-Za-z0-9_])", "<redigido>", msg)
    return msg


def _rodar(bw, args, sessao, entrada=None, segredos=(), timeout=180):
    """Roda o bw com a sessao SO no ambiente do filho; o conteudo vai por `entrada` (stdin)."""
    env = {k: v for k, v in os.environ.items() if k.upper() != "BW_SESSION"}
    if sessao:
        env["BW_SESSION"] = sessao
    env["BW_NOINTERACTION"] = "true"  # nunca esperar senha num prompt
    argv = (list(bw) if isinstance(bw, (list, tuple)) else [bw]) + list(args)
    try:
        r = subprocess.run(argv, input=entrada if entrada is not None else b"", capture_output=True,
                           env=env, timeout=timeout)
    except FileNotFoundError:
        raise CofreErro("Bitwarden CLI nao encontrado: %s" % argv[0])
    except subprocess.TimeoutExpired:
        raise CofreErro("bw %s: tempo esgotado em %ds" % (" ".join(args[:2]), timeout))
    if r.returncode != 0:
        erro = _redigir(r.stderr.decode("utf-8", "replace").strip(), list(segredos) + ([sessao] if sessao else []))
        raise CofreErro("bw %s falhou (rc=%d): %s" % (" ".join(args[:2]), r.returncode, erro[:300]))
    return r.stdout.decode("utf-8", "replace")


def _json(saida, o_que):
    try:
        return json.loads(saida)
    except ValueError:
        # nunca a saida no erro: a de `get item` tem o valor
        raise CofreErro("resposta do bw em %s nao e JSON" % o_que)


def status(bw, sessao=None):
    """'unauthenticated', 'locked' ou 'unlocked', pelo `bw status` (JSON)."""
    return _json(_rodar(bw, ["status"], sessao), "status").get("status") or "desconhecido"


def _sessao(sessao):
    return sessao or os.environ.get("BW_SESSION") or None


def _exigir_desbloqueado(bw, sessao):
    if not bw:
        raise CofreErro("Bitwarden CLI (bw) nao encontrado no PATH nem no WinGet: instale com "
                        "`winget install Bitwarden.CLI`")
    if not sessao:
        raise SemSessao(MSG_H1 + " - BW_SESSION ausente")
    st = status(bw, sessao)
    if st != "unlocked":
        raise SemSessao("%s - cofre %s" % (MSG_H1, st))


def _raiz(contrato, maquina):
    raiz = paths.caminho_local(contrato, maquina)
    if not raiz or not os.path.isdir(raiz):
        raise CofreErro("%s: pasta local nao existe nesta maquina (%s)" % (contrato["identity"]["id"], raiz))
    return raiz


def arquivos_locais(raiz):
    """Arquivos de segredo com valor na raiz do projeto (.env, .env.local) que existem."""
    return [a for a in ARQUIVOS if raiz and os.path.isfile(os.path.join(raiz, a))]


def _ler_bytes(p):
    with open(p, "rb") as f:
        return f.read()


def _campo(item, nome):
    return next((f.get("value") for f in item.get("fields") or [] if f.get("name") == nome), None)


def _com_hash(item, texto, sha):
    item["notes"] = texto
    item["fields"] = [f for f in item.get("fields") or [] if f.get("name") != "sha256"] + \
                     [{"name": "sha256", "value": sha, "type": 0}]
    return item


def _listar(bw, sessao, busca):
    itens = _json(_rodar(bw, ["list", "items", "--search", busca], sessao), "list items")
    return [i for i in itens if isinstance(i, dict) and isinstance(i.get("name"), str)]


def _ler_item(bw, sessao, item_id):
    return _json(_rodar(bw, ["get", "item", item_id], sessao), "get item")


def _gravar(bw, sessao, item, segredos, item_id=None):
    """create/edit com o item SO no stdin (codificado pelo proprio `bw encode`). Devolve o id."""
    bruto = json.dumps(item).encode("utf-8")
    # o item inteiro e a sua forma base64 (a que o bw recebe no create/edit) tambem sao redigidos
    # se o bw os ecoar no stderr (r11, Sec3)
    segredos = list(segredos) + [bruto.decode("utf-8"), base64.b64encode(bruto).decode("ascii")]
    cod = _rodar(bw, ["encode"], sessao, entrada=bruto, segredos=segredos)
    segredos.append(cod.strip())
    args = ["edit", "item", item_id] if item_id else ["create", "item"]
    novo = _json(_rodar(bw, args, sessao, entrada=cod.strip().encode("ascii"), segredos=segredos), args[0])
    if not novo.get("id"):
        raise CofreErro("bw %s nao devolveu o id do item" % args[0])
    return novo["id"]


def ultimo_manifesto_cofre(store, pid):
    nomes = [n for n in bk._listar_json(store, pid) if n.startswith(MANIFESTO)]
    if not nomes:
        return None
    return json.loads(store.ler_texto(bk._rel(bk.RECOVERY, "manifests", pid, nomes[-1])))


def push(contrato, maquina=None, store=None, bw=None, sessao=None, log=print):
    """Cria ou atualiza no cofre um item por arquivo de segredo local; rele e confere; grava o manifesto."""
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    pid = contrato["identity"]["id"]
    raiz = _raiz(contrato, maquina)
    locais = arquivos_locais(raiz)
    if not locais:
        raise CofreErro("%s: nenhum %s em %s - nada a levar para o cofre" % (pid, " / ".join(ARQUIVOS), raiz))
    bw = bw or resolver_bw()
    sessao = _sessao(sessao)
    _exigir_desbloqueado(bw, sessao)
    store = store if store is not None else cloud.store_da_maquina(maquina)
    if not store.disponivel():
        raise CofreErro("nuvem indisponivel (%s): sem lugar para o manifesto, nada enviado" % store.descricao())
    _rodar(bw, ["sync"], sessao)  # item criado por outra maquina tem de ser visto, senao vira duplicata
    ts = bk.carimbo()
    # TUDO lido, decodificado e validado ANTES da primeira escrita no cofre: um arquivo ruim no
    # meio nao pode deixar o cofre meio atualizado (r10, QA-A2)
    lidos = []
    for arq in locais:
        dados = _ler_bytes(os.path.join(raiz, arq))
        try:
            texto = dados.decode("utf-8")
        except UnicodeDecodeError:
            raise CofreErro("%s nao e UTF-8: converta antes (NADA enviado ao cofre)" % arq)
        lidos.append((arq, dados, texto))
    itens, gravou = [], []
    rel = bk._rel(bk.RECOVERY, "manifests", pid, "%s%s.json" % (MANIFESTO, ts))
    try:
        for arq, dados, texto in lidos:
            _push_um(bw, sessao, pid, arq, dados, texto, itens, gravou, log)
    except Exception as e:
        if gravou:
            # o cofre JA mudou: sem manifesto, o ultimo manifesto (antigo) diria SIM em outra
            # maquina. Grava um manifesto marcado incompleto, que o check trata como motivo.
            m = {"project": pid, "ts": ts, "incompleto": True,
                 "pendencias": ["push interrompido em %s (%s); o cofre foi alterado em %s"
                                % (arq, type(e).__name__, ", ".join(gravou))],
                 "itens": [{k: i[k] for k in ("arquivo", "item_nome", "item_id", "sha256", "chaves")} for i in itens]}
            try:
                store.escrever_texto(rel, json.dumps(m, ensure_ascii=False, indent=2))
            except Exception as e2:
                # o erro original continua sendo o lancado, mas NUNCA em silencio sobre o cofre
                # alterado sem manifesto (r11, QA6)
                _anexar(e, "%s (%s ao gravar o manifesto incompleto)" % (MSG_SEM_MANIFESTO, type(e2).__name__))
        raise
    m = {"project": pid, "ts": ts,
         "itens": [{k: i[k] for k in ("arquivo", "item_nome", "item_id", "sha256", "chaves")} for i in itens]}
    store.escrever_texto(rel, json.dumps(m, ensure_ascii=False, indent=2))
    return {"manifesto": m, "nuvem": rel, "itens": itens}


MSG_SEM_MANIFESTO = "cofre alterado sem manifesto: refaça o secrets-push"


def _anexar(e, msg):
    """Acrescenta `msg` a mensagem da excecao `e` (str(e) e o que a CLI imprime) e como nota."""
    try:
        e.args = ("%s - %s" % (e, msg),) if e.args else (msg,)
    except Exception:
        pass
    try:
        e.add_note(msg)
    except Exception:
        pass


def _push_um(bw, sessao, pid, arq, dados, texto, itens, gravou, log):
    """Um arquivo: cria/edita, rele e confere. `gravou` recebe o arquivo ANTES da escrita."""
    segredos = _valores(texto)
    sha = _sha(dados)
    nome = nome_item(pid, arq)
    mesmos = [i for i in _listar(bw, sessao, nome) if i["name"] == nome]
    if len(mesmos) > 1:
        raise CofreErro("%d itens '%s' no cofre: resolva a duplicata a mao (ids %s)"
                        % (len(mesmos), nome, ", ".join(str(i.get("id")) for i in mesmos)))
    if mesmos:
        atual = _ler_item(bw, sessao, mesmos[0]["id"])
        if atual.get("notes") == texto and _campo(atual, "sha256") == sha:
            item_id, estado = atual["id"], "inalterado"
        else:
            gravou.append(arq)
            item_id, estado = _gravar(bw, sessao, _com_hash(atual, texto, sha), segredos, atual["id"]), "atualizado"
    else:
        novo = {"organizationId": None, "collectionIds": None, "folderId": None, "type": 2, "name": nome,
                "notes": None, "favorite": False, "fields": [], "login": None, "secureNote": {"type": 0},
                "card": None, "identity": None, "reprompt": 0}
        gravou.append(arq)
        item_id, estado = _gravar(bw, sessao, _com_hash(novo, texto, sha), segredos), "criado"
    relido = _ler_item(bw, sessao, item_id)
    if _sha((relido.get("notes") or "").encode("utf-8")) != sha or _campo(relido, "sha256") != sha:
        raise ConferenciaFalhou("%s: o item %s relido do cofre nao tem o conteudo do arquivo local "
                                "(sha256 diferente); manifesto completo NAO gravado" % (arq, nome))
    itens.append({"arquivo": arq, "item_nome": nome, "item_id": item_id, "sha256": sha,
                  "chaves": chaves(texto), "estado": estado})
    log("  %-12s %-10s %s" % (arq, estado, nome))


def _nao_ignorado(destino, arq):
    """True se `destino` e um repositorio Git e `arq` NAO esta ignorado: escrever ali arrisca commit."""
    if not gitinfo.eh_repo(destino):
        return False
    rc, _ = gitinfo.git(destino, "check-ignore", "-q", "--", arq, check=False)
    return rc != 0


def pull(contrato, maquina=None, destino_dir=None, bw=None, sessao=None, sobrescrever=False):
    """Escreve cada item emmily-os/<id>/<arquivo> do cofre na raiz do projeto (ou em destino_dir)."""
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    pid = contrato["identity"]["id"]
    destino = destino_dir or _raiz(contrato, maquina)
    if not os.path.isdir(destino):
        raise CofreErro("destino nao existe: %s" % destino)
    bw = bw or resolver_bw()
    sessao = _sessao(sessao)
    _exigir_desbloqueado(bw, sessao)
    _rodar(bw, ["sync"], sessao)
    prefixo = nome_item(pid, "")
    achados = [i for i in _listar(bw, sessao, prefixo) if i["name"].startswith(prefixo)]
    if not achados:
        raise CofreErro("nenhum item %s* no cofre: rode secrets-push %s na maquina que tem o .env" % (prefixo, pid))
    res, por_arq = [], {}
    for i in achados:
        arq = i["name"][len(prefixo):]
        if arq not in ARQUIVOS:  # nome vindo do cofre nunca vira caminho livre (../, subpasta)
            res.append({"arquivo": arq, "item_nome": i["name"], "estado": "ignorado", "ok": True})
        elif arq in por_arq:
            raise CofreErro("mais de um item '%s' no cofre: resolva a duplicata a mao" % i["name"])
        else:
            por_arq[arq] = i
    for arq in sorted(por_arq):
        item = _ler_item(bw, sessao, por_arq[arq]["id"])
        dados = (item.get("notes") or "").encode("utf-8")
        sha = _sha(dados)
        r = {"arquivo": arq, "item_nome": item.get("name"), "item_id": item.get("id"), "sha256": sha,
             "chaves": chaves(dados.decode("utf-8")), "ok": False}
        res.append(r)
        alvo = os.path.join(destino, arq)
        if _campo(item, "sha256") != sha:
            r["estado"] = "recusado-hash"
            continue
        if os.path.islink(alvo) or (os.path.exists(alvo) and not os.path.isfile(alvo)):
            r["estado"] = "recusado-nao-e-arquivo"
            continue
        existe = os.path.isfile(alvo)
        if existe and _sha(_ler_bytes(alvo)) == sha:
            r.update(estado="ja-presente", ok=True)
            continue
        if existe and not sobrescrever:
            r["estado"] = "recusado-diferente"
            continue
        if _nao_ignorado(destino, arq):
            r["estado"] = "recusado-nao-ignorado"
            continue
        # 'xb' nunca sobrescreve: arquivo criado entre a checagem e a escrita faz a escrita falhar
        with open(alvo, "wb" if existe else "xb") as f:
            f.write(dados)
        if _sha(_ler_bytes(alvo)) != sha:
            raise ConferenciaFalhou("%s gravado em %s nao confere com o cofre (sha256)" % (arq, destino))
        r.update(estado="sobrescrito" if existe else "restaurado", ok=True)
    return {"project": pid, "destino": destino, "itens": res, "ok": all(r["ok"] for r in res)}


def verificar_cofre(contrato, store, maquina=None, raiz=None):
    """Sem rede e sem bw: cada .env local bate (sha256) com o ultimo manifesto de cofre?"""
    pid = contrato["identity"]["id"]
    if raiz is None:
        raiz = paths.caminho_local(contrato, maquina if maquina is not None else paths.carregar_maquina())
    locais = arquivos_locais(raiz)
    m = ultimo_manifesto_cofre(store, pid)
    v = {"project": pid, "manifesto": m["ts"] if m else None, "arquivos": [], "motivos": []}
    if locais and not m:
        v["motivos"].append("sem push para o cofre (%s)" % ", ".join(locais))
    if m and m.get("incompleto"):
        v["motivos"].append("ultimo push para o cofre ficou incompleto: refaca o secrets-push (%s)"
                            % "; ".join(m.get("pendencias") or [])[:200])
    for arq in locais:
        sha = gitinfo.sha256_arquivo(os.path.join(raiz, arq))
        reg = next((i for i in (m or {}).get("itens") or [] if i.get("arquivo") == arq), None)
        ok = bool(reg) and reg.get("sha256") == sha
        v["arquivos"].append({"arquivo": arq, "sha256_local": sha, "sha256_cofre": (reg or {}).get("sha256"), "ok": ok})
        if m and not reg:
            v["motivos"].append("'%s' nunca foi para o cofre" % arq)
        elif reg and not ok:
            v["motivos"].append("'%s' mudou desde o ultimo push para o cofre" % arq)
    v["ok"] = not v["motivos"]
    return v
