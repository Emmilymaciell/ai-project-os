"""Espelho de dados `cloud-mirror` (ADR-0013/0015): dado fora do Git com copia CONFERIDA na nuvem.

  origem    <caminho_local>/<data.path>                         pasta ou arquivo
  destino   <cloud.drive_root>/dados/<data.path>                 relativo a raiz logica do store
  anterior  <cloud.drive_root>/dados-anteriores/<ts>/<data.path> versao que foi substituida
  manifesto 99 RECOVERY/manifests/<id>/mirror-<ts>.json         + journal da maquina
            (%LOCALAPPDATA%/emmily-os/mirror/<id>/<ts>.json)

Copia ADITIVA: nada e apagado na nuvem (nem sync, nem delete, nem purge). Arquivo que sumiu daqui
continua la; arquivo alterado sobe por cima, e a versao anterior e preservada ANTES em
dados-anteriores/<ts>/. Incremental: o que ja esta no destino com o mesmo tamanho e md5 nao sobe.

Nome de segredo (gitinfo.nome_de_segredo) e symlink NAO sobem: viram `recusados`, e o check
continua acusando-os como "so nesta pasta".

Verificacao DEPOIS da copia, arquivo a arquivo: tamanho E md5 na nuvem contra o local (o md5 que
o Drive guarda; no DirStore, calculado). Divergencia, arquivo faltando ou arquivo local que mudou
durante o espelho = falha fechada: o manifesto e gravado com ok=false (evidencia) e nao conta.

O manifesto guarda [size, mtime_ns, md5] de cada arquivo. O check (portability) compara so size e
mtime_ns com a pasta atual: nao le conteudo e nao faz rede alem de ler este manifesto.
"""
import json
import os
import platform
import re
import time

from . import backup as bk
from . import cloud, gitinfo, paths

POLITICA = "cloud-mirror"
PREFIXO = "mirror-"
PASTA_JOURNAL = "mirror"
MD5_RE = re.compile(r"^[0-9a-f]{32}$")
MAX_LIDOS = 20  # manifestos lidos de tras para frente procurando o ultimo ok
SEM_COPIA = "pasta de dados '%s' (cloud-mirror) ainda sem copia verificada pelo motor"


class MirrorErro(RuntimeError):
    pass


def journal_padrao():
    """Journal da MAQUINA (fora do Git e da nuvem), mesmo padrao do ownership."""
    base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "emmily-os", PASTA_JOURNAL)


def rel_dir(pid):
    return cloud._junta(bk.RECOVERY, "manifests", pid)


def rel_manifesto(pid, ts):
    return cloud._junta(rel_dir(pid), PREFIXO + ts + ".json")


def caminhos(contrato):
    return [d["path"] for d in contrato.get("data") or [] if d.get("policy") == POLITICA]


def pendentes(contrato):
    """data[] com `decisao_pendente: true` (qualquer policy): nunca sobem e sempre sao motivo."""
    return [d["path"] for d in contrato.get("data") or [] if d.get("decisao_pendente") is True and d.get("path")]


MSG_PENDENTE = "dado com decisao pendente: %s"


def _caixa(p):
    """Chave de comparacao: no Windows o sistema de arquivos ignora caixa (r10, S-A6)."""
    return os.path.normcase(p).replace("\\", "/") if os.name == "nt" else p


def _dentro(q, p):
    """`q` e `p` ou esta dentro de `p` (caminhos ja normalizados por validar_path; sem caixa no Windows)."""
    return _caixa(q) == _caixa(p) or _caixa(q).startswith(_caixa(p) + "/")


def _pendentes_norm(contrato):
    """data.path normalizados de toda entrada pendente (qualquer policy). Caminho invalido levanta
    MirrorErro (r12, QA-A2/Sec1): descartado em silencio, um './data/raw' pendente deixava de
    excluir o filho e o pai cloud-mirror o subia. Falha fechada: sem saber o que esta pendente,
    nada se compara."""
    return [validar_path(p) for p in pendentes(contrato)]


def invalidos(contrato):
    """Mensagens de data[].path invalido em QUALQUER entrada (qualquer policy). O check as acusa
    como motivo; espelhar/restore levantam MirrorErro ao encontra-las (r12, QA-A2/Sec1)."""
    out = []
    for d in contrato.get("data") or []:
        try:
            validar_path(d.get("path"))
        except MirrorErro as e:
            out.append(str(e))
    return out


def separar(contrato):
    """(alvos, pendentes) entre os data[] cloud-mirror, normalizados. Pendente = a propria entrada
    marcada `decisao_pendente` OU dentro de (ou igual a) qualquer caminho pendente, de qualquer
    policy (r11, QA1/Sec1): o filho pendente nao pode ser contornado pelo pai, nem o pai pendente
    pelo filho. data[].path invalido em QUALQUER entrada (de qualquer policy) levanta MirrorErro
    antes de qualquer envio (r12, QA-A2/Sec1)."""
    ruins = invalidos(contrato)
    if ruins:
        raise MirrorErro("; ".join(ruins))
    pend_n = _pendentes_norm(contrato)
    alvos, pend = [], []
    for p in caminhos(contrato):
        q = validar_path(p)
        (pend if any(_dentro(q, x) for x in pend_n) else alvos).append(q)
    return alvos, pend


def aninhados(contrato, p):
    """data[] dentro de `p` que NAO sobem com ele: de OUTRA policy (ex.: output/TESTE com none
    dentro de output) - o contrato ja disse o que fazer com ele -, ou com `decisao_pendente`, de
    QUALQUER policy (r11, QA1/Sec1: pai cloud-mirror nao leva o filho pendente). Comparacao sem
    caixa no Windows: 'Data/X' e 'data/x' sao a mesma pasta. data[].path invalido em qualquer
    entrada levanta MirrorErro (r12, QA-A2)."""
    out = []
    for d in contrato.get("data") or []:
        q = validar_path(d.get("path"))  # invalido levanta (r12, QA-A2): nao some do inventario
        excluir = d.get("policy") != POLITICA or d.get("decisao_pendente") is True
        if excluir and _caixa(q).startswith(_caixa(p) + "/"):
            out.append(q)
    return sorted(set(out))


# Padroes de credencial no CONTEUDO (os mesmos prefixos do scanner, scripts/lib/scan-comum.ps1,
# mais password=/senha= com valor). Arquivo que casa nao sobe: falha fechada para o arquivo.
PADROES_CREDENCIAL = (
    ("token do GitHub", re.compile(r"gh[pousr]_[A-Za-z0-9]{16,}")),
    ("PAT fino do GitHub", re.compile(r"github_pat_[A-Za-z0-9_]{20,}")),
    ("chave da Anthropic", re.compile(r"sk-ant-[A-Za-z0-9_\-]{20,}")),
    ("chave OpenAI-like", re.compile(r"sk-[A-Za-z0-9]{32,}")),
    ("access key da AWS", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("chave privada PEM", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("token do Slack", re.compile(r"xox[bpas]-[A-Za-z0-9-]{10,}")),
    ("chave do Google", re.compile(r"AIza[0-9A-Za-z_\-]{35}")),
    ("token Bearer literal", re.compile(r"Bearer [A-Za-z0-9_\-\.]{20,}")),
    # r11, Sec2: string de conexao (ADO.NET/ODBC com senha; chave de conta do Azure) e URL com
    # credencial embutida (esquema://usuario:senha@host)
    ("string de conexao", re.compile(r"(?i)\b(?:Server|Data Source|Host|Address)\s*=[^;\n]{1,200};[^\n]*?"
                                     r"\b(?:Password|Pwd)\s*=\s*[^;\s]{3,}")),
    ("string de conexao", re.compile(r"(?i)\b(?:AccountKey|SharedAccessKey|SharedAccessSignature)\s*=\s*"
                                     r"[A-Za-z0-9+/%=&]{16,}")),
    ("URL com credencial", re.compile(r"\b[A-Za-z][A-Za-z0-9+.\-]{1,30}://[^\s/:@'\"<>]{1,200}:"
                                      r"[^\s/@'\"<>]{1,200}@[^\s/'\"<>]+")),
    ("senha com valor", re.compile(r"(?im)\b(?:password|passwd|pwd|senha)\s*[:=]\s*['\"]?[^\s'\"#;,]{4,}")),
)
MAX_VARRER = 2 * 1024 * 1024
MSG_ILEGIVEL = "conteudo ilegivel para a varredura de credencial (falha fechada)"


def _decodificar(dados):
    """Texto para a varredura, ou None (binario: nao varrido). UTF-16 com BOM, e UTF-16 sem BOM de
    conteudo ASCII (um NUL a cada 2 bytes - o UTF-8 estrito NAO o recusa: runbook de armadilhas),
    sao decodificados e varridos (r11, Sec2). Qualquer outro NUL = binario."""
    if dados[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return dados.decode("utf-16", "replace")
    if b"\x00" not in dados:
        return dados.decode("utf-8", "replace")
    pares, impares = dados[0::2], dados[1::2]
    if len(dados) >= 4:
        if impares.count(0) >= 0.9 * len(impares) and pares.count(0) <= 0.1 * len(pares):
            return dados[:len(dados) // 2 * 2].decode("utf-16-le", "replace")
        if pares.count(0) >= 0.9 * len(pares) and impares.count(0) <= 0.1 * len(impares):
            return dados[:len(dados) // 2 * 2].decode("utf-16-be", "replace")
    return None


def credencial_no_conteudo(full):
    """Nome do padrao de credencial achado no arquivo, ou None. OSError na leitura PROPAGA: quem
    chama recusa o arquivo (falha fechada, r11 Sec2).

    LIMITE DECLARADO (r11, Sec2): so e varrido arquivo de ate MAX_VARRER (2 MB) cujo conteudo e
    texto (UTF-8, ou UTF-16 com ou sem BOM). Arquivo maior que 2 MB e binario (xlsx, pdf, docx,
    imagem, banco: tem NUL fora do padrao UTF-16) NAO sao lidos e SOBEM - o espelho existe para
    eles, e recusa-los por padrao tornaria o cloud-mirror inutil. Credencial dentro de binario ou
    de texto grande nao e detectada por aqui (o guia 08 diz o mesmo)."""
    if os.path.getsize(full) > MAX_VARRER:
        return None
    with open(full, "rb") as f:
        dados = f.read(MAX_VARRER + 1)
    texto = _decodificar(dados)
    if texto is None:
        return None
    for nome, rx in PADROES_CREDENCIAL:
        if rx.search(texto):
            return nome
    return None


def validar_path(p):
    """data.path normalizado ('/'), ou MirrorErro: relativo, sem '..', sem unidade, sem componente
    terminado em espaco ou ponto (o Windows os descarta: 'data ' e 'data' seriam a mesma pasta e
    escapariam da comparacao com o pendente; r12, Sec1)."""
    r = (p if isinstance(p, str) else "").replace("\\", "/").rstrip("/")
    partes = r.split("/")
    if not r or r.startswith("/") or ":" in r or any(x in ("", ".", "..") or x != x.rstrip(" .") for x in partes):
        raise MirrorErro("data.path invalido para cloud-mirror: %r" % (p,))
    return r


def _rel_dados(contrato, *partes):
    dr = ((contrato.get("cloud") or {}).get("drive_root") or "").replace("\\", "/").strip("/")
    if not dr:
        raise MirrorErro("%s: cloud.drive_root nao declarado - o espelho nao tem destino" % contrato["identity"]["id"])
    return cloud._junta(dr, *partes)


def destino(contrato, p):
    return _rel_dados(contrato, "dados", p)


def unidade(p, tipo):
    """Prefixo (relativo ao projeto) da pasta copiada como unidade: a propria pasta, ou o pai do
    arquivo. As chaves do manifesto sao relativas ao projeto; na nuvem, <drive_root>/dados/<chave>."""
    if tipo == "arquivo":
        return p.rsplit("/", 1)[0] if "/" in p else ""
    return p


def sub(chave, prefixo):
    return chave[len(prefixo) + 1:] if prefixo else chave


def _longo(p):
    """Caminho LOCAL com o prefixo de caminho longo do Windows. Sem ele, arquivo com mais de
    260 caracteres no caminho (achado real: output do Grupo1) da FileNotFoundError no stat/open e
    derrubava o check inteiro. So para operacao local: o rclone recebe o caminho normal."""
    if os.name != "nt" or not p:
        return p
    a = os.path.abspath(p)
    if a.startswith("\\\\?\\"):
        return a
    if a.startswith("\\\\"):
        return "\\\\?\\UNC\\" + a[2:]
    return "\\\\?\\" + a


def _eh_link(p):
    return os.path.islink(p) or os.path.isjunction(p)


def inventario_local(raiz, p, permitidos=(), excluir=()):
    """(tipo, {chave: (size, mtime_ns)}, recusados). tipo: 'dir', 'arquivo', 'link' ou None (nao
    existe aqui). `excluir`: chaves (pasta ou arquivo) fora do espelho. Nao le conteudo: e o que o
    check usa."""
    origem = _longo(os.path.join(raiz, *p.split("/")))
    arquivos, recusados = {}, []
    excl_c = [_caixa(e) for e in excluir]
    fora = lambda chave: any(_caixa(chave) == e or _caixa(chave).startswith(e + "/") for e in excl_c)

    def avaliar(chave, full):
        if _eh_link(full):
            recusados.append({"rel": chave, "motivo": "symlink"})
        elif gitinfo.nome_de_segredo(chave, permitidos):
            recusados.append({"rel": chave, "motivo": "nome de segredo"})
        else:
            st = os.stat(full)
            arquivos[chave] = (st.st_size, st.st_mtime_ns)
    if _eh_link(origem):
        return "link", {}, [{"rel": p, "motivo": "symlink"}]
    if os.path.isfile(origem):
        avaliar(p, origem)
        return "arquivo", arquivos, recusados
    if not os.path.isdir(origem):
        return None, {}, []
    chave_de = lambda full: p + "/" + os.path.relpath(full, origem).replace("\\", "/")
    for r, ds, fs in os.walk(origem):
        ds[:] = sorted(d for d in ds if not fora(chave_de(os.path.join(r, d))))
        for d in ds:
            if _eh_link(os.path.join(r, d)):
                recusados.append({"rel": chave_de(os.path.join(r, d)), "motivo": "symlink"})
        ds[:] = [d for d in ds if not _eh_link(os.path.join(r, d))]
        for f in sorted(fs):
            full = os.path.join(r, f)
            if not fora(chave_de(full)):
                avaliar(chave_de(full), full)
    return "dir", arquivos, recusados


def _stat(raiz, chave):
    try:
        st = os.stat(_longo(os.path.join(raiz, *chave.split("/"))))
    except OSError:
        return None
    return (st.st_size, st.st_mtime_ns)


def _carimbo_livre(store, pid):
    # dois espelhos no mesmo segundo nao podem dividir o nome (nem a pasta dados-anteriores/<ts>)
    ts = bk.carimbo()
    while store.existe(rel_manifesto(pid, ts)):
        time.sleep(0.25)
        ts = bk.carimbo()
    return ts


def ultimo_espelho(store, pid, so_ok=True):
    """O manifesto de espelho mais recente (por padrao, o mais recente com ok=true), ou None."""
    nomes = sorted((n for n in store.listar(rel_dir(pid)) if n.startswith(PREFIXO) and n.endswith(".json")),
                   reverse=True)
    for n in nomes[:MAX_LIDOS]:
        m = json.loads(store.ler_texto(cloud._junta(rel_dir(pid), n)))
        if m.get("project") == pid and (m.get("ok") is True or not so_ok):
            return m
    return None


def espelhar(contrato, store, maquina=None, journal=None, log=print):
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    pid = contrato["identity"]["id"]
    alvos, pend = separar(contrato)
    if not alvos and not pend:
        raise MirrorErro("%s: nenhum data[] com policy cloud-mirror" % pid)
    pend = set(pend)
    for p in sorted(pend):
        log("  RECUSADO (decisao pendente): %s - nada enviado; decida e tire `decisao_pendente` do contrato" % p)
    if not alvos:
        raise MirrorErro("%s: todo data[] cloud-mirror esta com decisao pendente (%s): nada a espelhar"
                         % (pid, ", ".join(sorted(pend))))
    _rel_dados(contrato)  # sem drive_root, nada e copiado
    raiz = paths.caminho_local(contrato, maquina)
    if not raiz or not os.path.isdir(raiz):
        raise MirrorErro("%s: caminho local nao existe nesta maquina (%s)" % (pid, raiz))
    permitidos = (contrato.get("secrets") or {}).get("allowed_paths") or []
    ts = _carimbo_livre(store, pid)
    # sem caminho absoluto da maquina no manifesto (r10, S-A6): as chaves ja sao relativas ao
    # projeto; `maquina` e so o hostname
    m = {"manifest_version": 1, "project": pid, "ts": ts,
         "maquina": os.environ.get("COMPUTERNAME") or platform.node(), "source_path": ".",
         "paths": {}, "recusados": [], "ok": False}
    tot = {"enviados": 0, "ja_presentes": 0, "substituidos": 0}
    for p in sorted(pend):
        m["paths"][p] = {"estado": "decisao-pendente", "destino": destino(contrato, p), "arquivos": {}}
    for p in alvos:
        reg = m["paths"][p] = {"estado": "ausente", "destino": destino(contrato, p), "arquivos": {}}
        excl = aninhados(contrato, p)
        if excl:
            reg["excluidos"] = excl
        tipo, locais, recusados = inventario_local(raiz, p, permitidos, excl)
        for k in sorted(locais):
            try:
                achado = credencial_no_conteudo(_longo(os.path.join(raiz, *k.split("/"))))
                motivo = "credencial no conteudo (%s)" % achado if achado else None
            except OSError:
                # nao deu para ler = nao deu para varrer: o arquivo nao sobe (r11, Sec2)
                motivo = MSG_ILEGIVEL
            if motivo:
                recusados.append({"rel": k, "motivo": motivo})
                del locais[k]
        m["recusados"] += recusados
        for x in recusados:
            log("  recusado (%s): %s" % (x["motivo"], x["rel"]))
        if tipo == "link":
            reg["estado"] = "recusado"
        if tipo not in ("dir", "arquivo"):
            continue
        reg["tipo"] = tipo
        prefixo = unidade(p, tipo)
        base_local = os.path.join(raiz, *prefixo.split("/")) if prefixo else raiz
        rel_base = destino(contrato, prefixo)
        recursivo = tipo == "dir"
        hashes = {k: cloud._md5(_longo(os.path.join(raiz, *k.split("/")))) for k in locais}
        esperado = {k: (locais[k][0], hashes[k]) for k in locais}
        reg["arquivos"] = {k: [locais[k][0], locais[k][1], hashes[k]] for k in sorted(locais)}
        try:
            antes = store.inventario(rel_base, recursivo)
            enviar = [k for k in sorted(locais) if antes.get(sub(k, prefixo)) != esperado[k]]
            substituir = [k for k in enviar if sub(k, prefixo) in antes]
            log("  %s: %d arquivo(s), %d a enviar (%d substituido(s)), %.1f MB" % (
                p, len(locais), len(enviar), len(substituir), sum(locais[k][0] for k in enviar) / 1e6))
            ant = _rel_dados(contrato, "dados-anteriores", ts, prefixo) if substituir else None
            store.enviar_lote(base_local, [sub(k, prefixo) for k in enviar], rel_base, ant)
            depois = store.inventario(rel_base, recursivo)
        except (cloud.NuvemErro, OSError) as e:
            # OSError e stderr do rclone trazem caminho absoluto: o manifesto vai para a nuvem
            # (r11, Sec4) - raiz do projeto vira '.', a pasta do usuario vira '~'
            reg.update(estado="falhou", erro=paths.redigir_caminhos(str(e), raiz)[:300])
            continue
        divergentes = sorted(k for k in locais if depois.get(sub(k, prefixo)) != esperado[k])
        mudaram = sorted(k for k in locais if _stat(raiz, k) != locais[k])
        reg.update(enviados=len(enviar), ja_presentes=len(locais) - len(enviar), substituidos=len(substituir))
        tot["enviados"] += len(enviar)
        tot["ja_presentes"] += len(locais) - len(enviar)
        tot["substituidos"] += len(substituir)
        reg["estado"] = "falhou" if (divergentes or mudaram) else "ok"
        if divergentes:
            reg["divergentes"] = divergentes[:50]
            log("  FALHOU %s: %d arquivo(s) com tamanho/md5 diferente na nuvem" % (p, len(divergentes)))
        if mudaram:
            reg["mudaram_durante"] = mudaram[:50]
            log("  FALHOU %s: %d arquivo(s) mudaram durante o espelho - rode de novo" % (p, len(mudaram)))
    m["ok"] = all(r["estado"] in ("ok", "ausente", "recusado", "decisao-pendente") for r in m["paths"].values())
    m["completed_at"] = bk.carimbo()
    texto = json.dumps(m, ensure_ascii=False, indent=2)
    rel = rel_manifesto(pid, ts)
    store.escrever_texto(rel, texto)
    if store.ler_texto(rel).strip() != texto.strip():
        raise MirrorErro("manifesto de espelho gravado na nuvem difere do gerado: %s" % rel)
    jdir = journal or journal_padrao()
    cloud.DirStore(jdir).escrever_texto(pid + "/" + ts + ".json", texto)
    return dict(tot, ok=m["ok"], manifesto=m, nuvem=rel, journal=os.path.join(jdir, pid, ts + ".json"),
                recusados=len(m["recusados"]), pendentes=sorted(pend))


def motivos_so_aqui(contrato, raiz, store):
    """Para o check: o que, nos data[] cloud-mirror, existe SO nesta pasta. Le so o ultimo manifesto
    de espelho ok (arquivo pequeno) e o stat da pasta. Nuvem ilegivel = motivo (falha fechada)."""
    # decisao pendente: motivo SEMPRE, mesmo com copia antiga ok na nuvem - a copia nao e decisao
    motivos = [MSG_PENDENTE % p for p in pendentes(contrato)]
    ruins = invalidos(contrato)
    if ruins:
        # falha fechada (r12, QA-A2): com um data[].path invalido nao se sabe o que esta dentro de
        # que, entao nada aqui conta como protegido
        return motivos + ruins
    pend_n = _pendentes_norm(contrato)
    alvos = []
    for bruto in caminhos(contrato):
        # nao levanta: `invalidos` acima ja devolveu com qualquer path invalido (r13, QA5)
        q = validar_path(bruto)
        if any(_dentro(q, x) for x in pend_n):
            if not any(_caixa(q) == _caixa(x) for x in pend_n):
                motivos.append(MSG_PENDENTE % q + " (dentro de caminho pendente)")
            continue
        alvos.append(q)
    if not alvos:
        return motivos
    pid = contrato["identity"]["id"]
    permitidos = (contrato.get("secrets") or {}).get("allowed_paths") or []
    m, erro = None, None
    if store is None:
        erro = "sem acesso a nuvem"
    else:
        try:
            m = ultimo_espelho(store, pid)
        except Exception as e:
            erro = str(e)[:150]
    for p in alvos:  # ja normalizados por validar_path no laco acima
        if not raiz:
            motivos.append(SEM_COPIA % p)
            continue
        tipo, locais, recusados = inventario_local(raiz, p, permitidos, aninhados(contrato, p))
        if tipo is None:
            continue  # nao existe nesta pasta: nada se perderia
        reg = ((m or {}).get("paths") or {}).get(p)
        if erro:
            motivos.append("pasta de dados '%s' (cloud-mirror): espelho nao verificavel (%s)" % (p, erro))
        elif not isinstance(reg, dict) or reg.get("estado") != "ok":
            motivos.append(SEM_COPIA % p)
        else:
            salvos = reg.get("arquivos") or {}
            n = sum(1 for k, v in locais.items() if list(salvos.get(k) or [])[:2] != list(v))
            if n:
                motivos.append("'%s': %d arquivo(s) novo(s)/alterado(s) desde o espelho de %s" % (p, n, m["ts"]))
        if recusados:
            motivos.append("'%s': %d arquivo(s) que o espelho recusa existe(m) so nesta pasta: %s" % (
                p, len(recusados), ", ".join("%s (%s)" % (x["rel"], x["motivo"]) for x in recusados[:5])))
    return motivos

