"""Ownership & Provenance: quem e a titular DECLARADA de um projeto, e se os fatos contradizem.

Capacidade permanente (docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md, secoes 1-4 e 6; ADR-0018). Tres partes:

  verificar(contrato, maquina)  READ-ONLY. Cada item sai PASS / WARN / FAIL / N/A com motivo:
      declared_owner   secao `ownership` com declared_owner + creators (PROJECT sem secao = FAIL)
      ownership_files  PROVENANCE.md, OWNERSHIP.md e AUTHORS.md (ou AUTHORS) no working tree
      notice           third_party nao vazio exige NOTICE
      license          license preenchida; se != proprietary, arquivo LICENSE presente
      git_identities   todo autor/committer do historico (identidade CRUA: sem .mailmap, que o
                       proprio repo controla) esta em identities U creators U contributors U
                       tool_accounts (e-mail OU nome, sem caixa; sufixo '(anotacao)' ignorado).
                       Fora = FAIL "contradicao": autoria que a declaracao nao explica
      signing          config EFETIVA do repo (gpg.format, user.signingkey, commit.gpgsign) e
                       %G? dos commits: so G conta como assinado; B/R em qualquer commit = FAIL;
                       U/E/X/Y desde o primeiro assinado = WARN
      remote_owner     dono do remote.origin.url == owner_github
      codeowners       CODEOWNERS cita @owner_github
      manifest         ultimo certificado bate com o hash atual dos arquivos de ownership
      contradictions   marcador de autoria (author/autor com dois-pontos, copyright com ano ou
                       simbolo) em README/LICENSE/NOTICE/cabecalhos atribuindo autoria a nome fora
                       da declaracao (nome casado por palavra inteira, sem acento/caixa); corte de
                       MAX_ARQUIVOS atingido = WARN
  certificar(contrato, store, maquina, tag=False)  roda o check, recusa com FAIL, grava o
      certificado JSON no ledger da nuvem (99 RECOVERY/manifests/<id>/ownership-<ts>.json) e no journal
      da maquina (%LOCALAPPDATA%/emmily-os/ownership/<id>/<ts>.json). NUNCA no working tree. Autores
      saem com NOME + SHA-256 do e-mail normalizado, nunca o e-mail em claro.
      --tag: tag ASSINADA ownership-YYYYMMDD no HEAD; sem assinatura configurada, falha fechado; se a
      gravacao falhar depois, a tag criada NESTA execucao e removida.
  secao_padrao / gerar_arquivos  reutilizaveis pelo nascimento protegido (`eos new`).

Regras da declaracao (contrato, secao `ownership`):
  - `identities` so contem identidades Git ('Nome <email>') da PROPRIA titular;
  - `contributors` e terceiro: so o NOME, sem e-mail (e-mail de terceiro e dado pessoal e o contrato e
    versionado; com e-mail, declared_owner sai WARN). A comparacao com o historico e por e-mail OU por
    nome, sem caixa, entao o nome basta para explicar o commit do contribuidor;
  - `tool_accounts`: contas/ferramentas usadas SEM autoria (ex.: conta de IA de colega, bot de CI).
  - a secao e opcional no schema (contract.validar); a obrigatoriedade para PROJECT e deste check (FAIL)
    e do nascimento protegido (`eos new`).

Ownership e INFORMATIVA para a portabilidade: nao muda a escada L0-L6 (portability.verificar).
Declaracao de titularidade nao e prova juridica: o motor confere coerencia entre o que foi
declarado e o que o repositorio mostra, e diz onde ha contradicao.
"""
import datetime
import hashlib
import subprocess
import json
import os
import re
import shutil
import unicodedata

from . import __version__
from . import backup as bk
from . import cloud, gitinfo, paths

PASS, WARN, FAIL, NA = "PASS", "WARN", "FAIL", "N/A"
ITENS = ("declared_owner", "ownership_files", "notice", "license", "git_identities", "signing",
         "remote_owner", "codeowners", "manifest", "contradictions")
SIGNING = ("required", "recommended", "none")
PASTA_LEDGER = "ownership"      # journal: %LOCALAPPDATA%/emmily-os/ownership/<id>/<ts>.json
PREFIXO_LEDGER = "ownership-"   # nuvem: 99 RECOVERY/manifests/<id>/ownership-<ts>.json (ao lado do cert-<ts>.json)
AUTHORS_NOMES = ("AUTHORS.md", "AUTHORS")
CODEOWNERS_NOMES = (".github/CODEOWNERS", "CODEOWNERS", "docs/CODEOWNERS")
LICENSE_NOMES = ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING", "COPYING.md")
GITHUB_RE = re.compile(r"^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+)/([^/]+?)(?:\.git)?/?$",
                       re.IGNORECASE)
# Atribuicao de autoria: so com DONO depois do marcador. author/autor exigem dois-pontos; copyright exige
# ano ou simbolo, senao o corpo da licenca MIT (os "holders" genericos) viraria contradicao.
# Variantes: **Autor**:, __Autor__:, **Autor:**, Autor(a):, Author(s):. Antes do marcador nao pode haver
# letra/digito; \b nao serve porque o '_' do sublinhado markdown e caractere de palavra.
ATRIB_RE = (
    re.compile(r"(?i)(?<![^\W_])(?:authors?|autor(?:a|es|as)?)(?:\s*\((?:a|s|es|as)\))?\s*(?:\*\*|__)?"
               r"\s*:\s*(?:\*\*|__)?\s*(?P<resto>.*)$"),
    re.compile(r"(?i)(?:\bcopyright\b|©)\s*(?:\(c\)|©)?\s*(?:\d{4}(?:\s*[-–,]\s*\d{4})*)\s*,?\s*(?P<resto>.*)$"),
    re.compile(r"(?i)\bcopyright\s*(?:\(c\)|©)\s*(?P<resto>.*)$"),
)
EXT_CODIGO = {".py", ".ps1", ".psm1", ".psd1", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".sh", ".bat", ".cmd",
              ".bas", ".vba", ".cls", ".cs", ".java", ".go", ".rs", ".c", ".h", ".cpp", ".hpp", ".r", ".sql",
              ".html", ".css", ".scss", ".vue", ".rb", ".php", ".kt", ".swift", ".m"}
DOC_RAIZ = re.compile(r"^(README|LICENSE|NOTICE|COPYING|AUTHORS)([._-].*)?$", re.IGNORECASE)
LINHAS_CABECALHO = 40
MAX_ARQUIVOS = 3000
MAX_BYTES = 2 * 1024 * 1024


def _it(item, status, motivo, **extra):
    d = {"item": item, "status": status, "motivo": motivo}
    d.update(extra)
    return d


def _git_cfg(raiz, chave, tipo=None):
    """Valor EFETIVO (system < global < local < worktree) ou None. `--type=bool` normaliza yes/on/1."""
    args = ["config"] + (["--type=" + tipo] if tipo else []) + ["--get", chave]
    rc, out = gitinfo.git(raiz, *args, check=False)
    v = out.strip()
    return v if rc == 0 and v != "" else None


def journal_padrao():
    """Journal da MAQUINA (fora do Git e da nuvem), irmao do indice SQLite derivado."""
    base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "emmily-os", PASTA_LEDGER)


def rel_ledger(pid, ts=None):
    """Pasta (ts=None) ou arquivo do certificado no ledger da nuvem."""
    base = "/".join((bk.RECOVERY, "manifests", pid))
    return base if ts is None else "%s/%s%s.json" % (base, PREFIXO_LEDGER, ts)


# --------------------------------------------------------------------------- identidades

def _sem_anotacao(nome):
    """'Fulano Tal (atribuido no pacote)' -> 'Fulano Tal': a anotacao livre nao e parte do nome."""
    return re.sub(r"\s*\([^()]*\)\s*$", "", nome).strip()


def _ident(s):
    """'Nome <email>' | 'email' | 'Nome' -> (nome, email), ambos sem caixa ('' = ausente)."""
    m = re.match(r"^\s*(.*?)\s*<([^>]*)>\s*$", s or "")
    if m:
        return _sem_anotacao(m.group(1)).casefold(), m.group(2).strip().casefold()
    s = (s or "").strip()
    if "@" in s and " " not in s:
        return "", s.casefold()
    return _sem_anotacao(s).casefold(), ""


def explicado(nome, email, declarados):
    """True se (nome, email) bate com ALGUMA entrada declarada: por e-mail ou por nome."""
    n, e = (nome or "").strip().casefold(), (email or "").strip().casefold()
    for d in declarados:
        dn, de = _ident(d)
        if (de and de == e) or (dn and dn == n):
            return True
    return False


def _declarados(sec):
    return [x for k in ("identities", "creators", "contributors", "tool_accounts") for x in (sec.get(k) or [])]


def autores(raiz):
    """[(nome, email, papel, commits)] de autores E committers de todas as refs (menos stash).
    Identidade CRUA (%an/%ae/%cn/%ce e --no-mailmap): o .mailmap e do proprio repositorio e reescreveria
    um terceiro como a titular (r8, Q3)."""
    out = gitinfo.git(raiz, "-c", "i18n.logOutputEncoding=UTF-8", "log", "--no-mailmap", "--exclude=refs/stash",
                      "--all", "--format=%an%x00%ae%x00%cn%x00%ce")
    cont = {}
    for linha in out.splitlines():
        p = linha.split("\0")
        if len(p) != 4:
            continue
        for nome, email, papel in ((p[0], p[1], "author"), (p[2], p[3], "committer")):
            k = (nome, email, papel)
            cont[k] = cont.get(k, 0) + 1
    return sorted((n, e, papel, c) for (n, e, papel), c in cont.items())


# --------------------------------------------------------------------------- assinatura

def _sem_caminho_da_maquina(f):
    """Copia dos fatos de assinatura para o CERTIFICADO: caminhos de arquivo viram so o nome
    (o caminho completo traz o usuario do Windows e nao serve em outra maquina)."""
    g = dict(f)
    for k in ("signingkey", "allowed_signers"):
        v = g.get(k)
        if v and not (v.startswith("key::") or v.startswith("ssh-")):
            g[k] = os.path.basename(v.replace("\\", "/").rstrip("/"))
    return _redigir_certificado(g, f)


EMAIL_RE = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")


def _formas_de_caminho(v):
    """As grafias de um caminho de arquivo que podem aparecer num texto (barra, contrabarra,
    ~ expandido, absoluto)."""
    if not v or v.startswith("key::") or v.startswith("ssh-"):
        return []
    formas = set()
    for x in (v, os.path.expanduser(v), os.path.abspath(os.path.expanduser(v))):
        formas |= {x, x.replace("\\", "/"), x.replace("/", "\\")}
    return sorted((x for x in formas if len(x) > 3), key=len, reverse=True)


def _redigir_certificado(obj, f=None):
    """Copia redigida de qualquer parte do CERTIFICADO (r10, S-A2): caminhos da chave e do
    allowed_signers viram so o nome do arquivo, a pasta do usuario vira '~' e todo e-mail vira
    'sha256:<hex>' do e-mail normalizado (como em `authors`). Recursivo em dict/list/str."""
    trocas = []
    for k in ("signingkey", "allowed_signers"):
        v = (f or {}).get(k)
        for forma in _formas_de_caminho(v):
            trocas.append((forma, os.path.basename(v.replace("\\", "/").rstrip("/"))))
    flags = re.IGNORECASE if os.name == "nt" else 0

    def texto(s):
        for de, para in trocas:
            s = re.sub(re.escape(de), lambda _m, p=para: p, s, flags=flags)
        # pasta do usuario -> '~' sem distincao de caixa no Windows e tambem pelo nome curto 8.3
        # (r11, Sec5): o mesmo redator do manifesto de espelho
        s = paths.redigir_caminhos(s)
        return EMAIL_RE.sub(lambda m: "sha256:" + hashlib.sha256(m.group(0).strip().lower().encode("utf-8")).hexdigest(), s)

    def andar(x):
        if isinstance(x, str):
            return texto(x)
        if isinstance(x, dict):
            return {k: andar(v) for k, v in x.items()}
        if isinstance(x, list):
            return [andar(v) for v in x]
        return x
    return andar(obj)


def fatos_assinatura(raiz):
    """Config EFETIVA do repo + %G? do historico do HEAD. So le."""
    fmt = _git_cfg(raiz, "gpg.format") or "openpgp"
    chave = _git_cfg(raiz, "user.signingkey")
    gpgsign = _git_cfg(raiz, "commit.gpgsign", "bool") == "true"
    if not chave:
        chave_ok, chave_motivo = False, "user.signingkey nao configurado"
    elif fmt == "ssh" and (chave.startswith("key::") or chave.startswith("ssh-")):
        chave_ok, chave_motivo = True, "chave ssh literal na config"
    elif fmt == "ssh":
        p = os.path.expanduser(chave)
        p = p if os.path.isabs(p) else os.path.join(raiz, p)
        chave_ok = os.path.isfile(p)
        chave_motivo = "arquivo da chave existe" if chave_ok else "arquivo da chave NAO existe: %s" % chave
    else:
        chave_ok, chave_motivo = True, "id de chave %s (nao e arquivo; nao conferido)" % fmt
    f = {"gpg_format": fmt, "signingkey": chave, "signingkey_ok": chave_ok, "signingkey_motivo": chave_motivo,
         "commit_gpgsign": gpgsign, "allowed_signers": _git_cfg(raiz, "gpg.ssh.allowedSignersFile"),
         "configurado": bool(chave_ok and gpgsign), "head": None, "commits": 0, "desde": None,
         "commits_desde": 0, "assinados_desde": 0, "nao_verificados_desde": 0, "invalidos": 0,
         "invalidos_shas": [], "pct": None}
    if not gitinfo.tem_commit(raiz):
        return f
    linhas = [l.split("\t") for l in gitinfo.git(raiz, "-c", "i18n.logOutputEncoding=UTF-8", "log", "--reverse", "--format=%H%x09%G?", "HEAD").splitlines() if "\t" in l]
    f["commits"] = len(linhas)
    f["head"] = linhas[-1][1] if linhas else None
    # B/R em QUALQUER commit do historico, nao so no HEAD (r8, Q4)
    ruins = [h for h, g in linhas if g in ("B", "R")]
    f["invalidos"], f["invalidos_shas"] = len(ruins), [h[:12] for h in ruins[:10]]
    primeiro = next((i for i, (_, g) in enumerate(linhas) if g != "N"), None)
    if primeiro is not None:
        desde = linhas[primeiro:]
        f["desde"] = desde[0][0]
        f["commits_desde"] = len(desde)
        # so G e assinado E verificado; U/E/X/Y e assinatura sem prova de QUEM assinou
        f["assinados_desde"] = sum(1 for _, g in desde if g == "G")
        f["nao_verificados_desde"] = sum(1 for _, g in desde if g not in ("G", "N", "B", "R"))
        f["pct"] = round(100.0 * f["assinados_desde"] / len(desde), 1)
    return f


def _item_signing(politica, f, tem_commit):
    if politica == "none":
        return _it("signing", NA, "signing: none declarado", fatos=f)
    falta = []
    if not f["signingkey_ok"]:
        falta.append(f["signingkey_motivo"])
    if not f["commit_gpgsign"]:
        falta.append("commit.gpgsign nao e true")
    ruim = FAIL if politica == "required" else WARN
    if falta:
        return _it("signing", ruim, "assinatura nao configurada (%s): %s" % (politica, "; ".join(falta)), fatos=f)
    if not tem_commit:
        return _it("signing", PASS, "configurada (gpg.format=%s); repositorio ainda sem commit" % f["gpg_format"], fatos=f)
    h = f["head"]
    # assinatura RUIM (em qualquer commit) e contradicao em qualquer politica; commit sem assinatura com
    # a config pronta e aviso (historico legado; o proximo commit sai assinado) - a spec so reprova
    # config ausente
    if f["invalidos"]:
        return _it("signing", FAIL, "%d commit(s) com assinatura invalida/revogada (%%G?=B/R): %s"
                   % (f["invalidos"], ", ".join(f["invalidos_shas"])), fatos=f)
    desde = "%d de %d commit(s) assinados e verificados (%%G?=G) desde o primeiro assinado" % (
        f["assinados_desde"], f["commits_desde"])
    if h == "N":
        return _it("signing", WARN, "configurada, mas o HEAD nao e assinado (%%G?=N)%s" % (
            "" if f["pct"] is None else "; " + desde), fatos=f)
    if f["nao_verificados_desde"]:
        # U = assinatura boa de principal desconhecido (allowedSignersFile sem a chave); E/X/Y = nao
        # verificavel ou expirada: assinado, mas sem prova de QUEM assinou -> aviso, nunca PASS
        return _it("signing", WARN, "%d commit(s) assinado(s) mas nao verificado(s) (%%G?=U/E/X/Y; HEAD %%G?=%s): "
                   "confira se a chave esta em gpg.ssh.allowedSignersFile; %s"
                   % (f["nao_verificados_desde"], h, desde), fatos=f)
    if f["pct"] is not None and f["pct"] < 100:
        return _it("signing", WARN, "%s (%.1f%%)" % (desde, f["pct"]), fatos=f)
    return _it("signing", PASS, "configurada (gpg.format=%s); %d commit(s) assinados e verificados desde o primeiro assinado"
               % (f["gpg_format"], f["assinados_desde"]), fatos=f)


# --------------------------------------------------------------------------- arquivos

def arquivos_de_ownership(raiz, sec):
    """Caminhos relativos (com /) dos arquivos de ownership que EXISTEM: o que o certificado assina."""
    candidatos = [sec.get("provenance_file") or "PROVENANCE.md", "OWNERSHIP.md", "NOTICE"]
    candidatos += list(AUTHORS_NOMES) + list(LICENSE_NOMES) + list(CODEOWNERS_NOMES)
    vistos, out = set(), []
    for c in candidatos:
        if c not in vistos and os.path.isfile(os.path.join(raiz, *c.split("/"))):
            vistos.add(c)
            out.append(c)
    return sorted(out)


def hashes(raiz, rels):
    return {r: gitinfo.sha256_arquivo(os.path.join(raiz, *r.split("/"))) for r in rels}


def _existe(raiz, rel):
    return os.path.isfile(os.path.join(raiz, *rel.split("/")))


def dono_do_remoto(url):
    m = GITHUB_RE.match((url or "").strip())
    return m.group(1) if m else None


def _palavras(texto):
    """' palavra palavra ' sem acento e sem caixa: casar por palavra inteira, nunca por substring."""
    t = "".join(c for c in unicodedata.normalize("NFKD", texto or "") if not unicodedata.combining(c))
    return " %s " % " ".join(re.findall(r"[^\W_]+", t.casefold()))


def _nomes_conhecidos(sec):
    nomes = [sec.get("declared_owner") or ""] + list(sec.get("creators") or []) + list(sec.get("contributors") or [])
    nomes += [t.get("name") or "" for t in sec.get("third_party") or []]
    nomes += [_ident(i)[0] for i in sec.get("identities") or []]
    out = set()
    for n in nomes:
        dn, de = _ident(n)
        for x in (dn, de):
            p = _palavras(x)
            if len(p.strip()) >= 2:
                out.add(p)
    return out


def contradicoes(raiz, sec):
    """(['arquivo:linha: texto'] de atribuicao de autoria a nome que a declaracao nao conhece,
    total de arquivos rastreados). total > MAX_ARQUIVOS = leitura truncada."""
    conhecidos = _nomes_conhecidos(sec)
    terceiros = [(t.get("path") or "").replace("\\", "/").strip("/") for t in sec.get("third_party") or []]
    terceiros = [t for t in terceiros if t]
    rastreados = [r for r in gitinfo.git(raiz, "ls-files", "-z").split("\0") if r]
    achados = []
    for rel in rastreados[:MAX_ARQUIVOS]:
        if any(rel == t or rel.startswith(t + "/") for t in terceiros):
            continue
        base = rel.rsplit("/", 1)[-1]
        doc = "/" not in rel and DOC_RAIZ.match(base)
        if not doc and os.path.splitext(base)[1].lower() not in EXT_CODIGO:
            continue
        p = os.path.join(raiz, *rel.split("/"))
        try:
            if not os.path.isfile(p) or os.path.getsize(p) > MAX_BYTES:
                continue
            with open(p, encoding="utf-8", errors="replace") as fh:
                linhas = fh.read().splitlines()
        except OSError:
            continue
        for i, linha in enumerate(linhas if doc else linhas[:LINHAS_CABECALHO], 1):
            for rx in ATRIB_RE:
                m = rx.search(linha)
                if not m:
                    continue
                resto = m.group("resto").strip()
                if re.search(r"[^\W\d_]", resto) and not any(n in _palavras(linha) for n in conhecidos):
                    achados.append("%s:%d: %s" % (rel, i, linha.strip()[:160]))
                break
    return achados, len(rastreados)


# --------------------------------------------------------------------------- ledger

def _ler_ultimo(fonte, rel_dir, prefixo=""):
    nomes = [n for n in fonte.listar(rel_dir) if n.endswith(".json") and n.startswith(prefixo)]
    if not nomes:
        return None
    return json.loads(fonte.ler_texto(rel_dir + "/" + sorted(nomes)[-1]))


def ultimo_certificado(pid, store=None, journal=None):
    """(certificado mais recente entre journal e nuvem, com `_fonte`, None) ou (None, erros de leitura)."""
    achados, erros = [], []
    jdir = journal or journal_padrao()
    try:
        c = _ler_ultimo(cloud.DirStore(jdir), pid)
        if c:
            achados.append((c, "journal"))
    except Exception as e:
        erros.append("journal: %s" % str(e)[:120])
    if store is not None:
        try:
            c = _ler_ultimo(store, rel_ledger(pid), PREFIXO_LEDGER)
            if c:
                achados.append((c, "nuvem"))
        except Exception as e:
            erros.append("nuvem: %s" % str(e)[:120])
    if not achados:
        return None, "; ".join(erros)
    cert, fonte = max(achados, key=lambda x: x[0].get("certified_at") or "")
    return dict(cert, _fonte=fonte), None


# --------------------------------------------------------------------------- verificar

def verificar(contrato, maquina=None, store=None, journal=None):
    """Ownership check READ-ONLY. `store` (opcional) e consultado so pelo item manifest."""
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    ident = contrato["identity"]
    pid, tipo = ident["id"], ident["type"]
    sec = contrato.get("ownership")
    r = {"project": pid, "type": tipo, "verificado_em": bk.carimbo(), "caminho": None, "itens": [],
         "autores": [], "assinatura": None, "remoto": None}
    itens = r["itens"]
    if not isinstance(sec, dict):
        if tipo == "PROJECT":
            itens.append(_it("declared_owner", FAIL, "PROJECT sem secao ownership no contrato"))
        else:
            itens.append(_it("declared_owner", NA, "%s sem secao ownership (opcional fora de PROJECT)" % tipo))
        for nome in ITENS[1:]:
            itens.append(_it(nome, NA, "sem secao ownership: nada contra o que comparar"))
        return _fechar(r)
    falta = [c for c in ("declared_owner", "creators") if not sec.get(c)]
    com_email = [c for c in sec.get("contributors") or [] if _ident(c)[1]]
    if falta:
        itens.append(_it("declared_owner", FAIL, "falta: " + ", ".join(falta)))
    elif com_email:
        itens.append(_it("declared_owner", WARN, "contributors com e-mail (dado pessoal de terceiro no contrato "
                         "versionado): declare so o nome - %d entrada(s)" % len(com_email)))
    else:
        itens.append(_it("declared_owner", PASS, "titular declarada: %s" % sec["declared_owner"]))
    try:
        raiz = paths.caminho_local(contrato, maquina)
    except paths.CaminhoNaoResolvido as e:
        raiz, motivo_raiz = None, str(e)
    else:
        motivo_raiz = "caminho local nao declarado" if not raiz else "caminho local nao existe nesta maquina: %s" % raiz
    r["caminho"] = raiz
    existe = bool(raiz) and os.path.isdir(raiz)
    repo = existe and gitinfo.eh_repo(raiz)
    tem_commit = repo and gitinfo.tem_commit(raiz)
    nv = "nao verificavel: " + (motivo_raiz if not existe else "nao e repositorio Git")
    # --- arquivos ---
    if not existe:
        for nome in ("ownership_files", "notice", "license"):
            itens.append(_it(nome, WARN, nv))
    else:
        prov = sec.get("provenance_file") or "PROVENANCE.md"
        faltam = [x for x in (prov, "OWNERSHIP.md") if not _existe(raiz, x)]
        if not any(_existe(raiz, a) for a in AUTHORS_NOMES):
            faltam.append("AUTHORS.md (ou AUTHORS)")
        itens.append(_it("ownership_files", WARN if faltam else PASS,
                         ("faltam: " + ", ".join(faltam)) if faltam else "%s, OWNERSHIP.md e AUTHORS presentes" % prov))
        if not sec.get("third_party"):
            itens.append(_it("notice", NA, "sem componente de terceiro declarado"))
        else:
            ok = _existe(raiz, "NOTICE")
            itens.append(_it("notice", PASS if ok else WARN, "NOTICE presente" if ok else
                             "%d componente(s) de terceiro sem NOTICE" % len(sec["third_party"])))
        lic = (sec.get("license") or "").strip()
        if not lic:
            itens.append(_it("license", WARN, "ownership.license nao preenchido"))
        elif lic.lower() == "proprietary":
            itens.append(_it("license", PASS, "proprietary"))
        else:
            ok = any(_existe(raiz, x) for x in LICENSE_NOMES)
            itens.append(_it("license", PASS if ok else WARN, "%s com arquivo LICENSE" % lic if ok else
                             "license %s declarada sem arquivo LICENSE" % lic))
    # --- identidades ---
    if not repo:
        itens.append(_it("git_identities", WARN, nv))
    elif not tem_commit:
        itens.append(_it("git_identities", NA, "repositorio sem commit"))
    else:
        aut = autores(raiz)
        r["autores"] = ["%s <%s> (%s, %d)" % a for a in aut]
        decl = _declarados(sec)
        fora = sorted({"%s <%s>" % (n, e) for n, e, _, _ in aut if not explicado(n, e, decl)})
        unicos = len({(n.casefold(), e.casefold()) for n, e, _, _ in aut})
        itens.append(_it("git_identities", FAIL if fora else PASS,
                         ("contradicao: %d identidade(s) no historico fora de identities/creators/contributors/"
                          "tool_accounts: %s" % (len(fora), ", ".join(fora[:10]))) if fora else
                         "%d identidade(s) do historico explicada(s) pela declaracao" % unicos,
                         **({"fora": fora} if fora else {})))
    # --- assinatura ---
    politica = sec.get("signing") or "recommended"
    if not repo:
        # sem repositorio nesta maquina: nao verificado (WARN), nunca PASS; FAIL fica para config ausente medida
        itens.append(_it("signing", NA if politica == "none" else WARN, nv))
    else:
        f = fatos_assinatura(raiz)
        r["assinatura"] = f
        itens.append(_item_signing(politica, f, tem_commit))
    # --- remoto / codeowners ---
    url = _git_cfg(raiz, "remote.origin.url") if repo else None
    r["remoto"] = url
    esperado = (sec.get("owner_github") or "").strip()
    if not repo:
        itens.append(_it("remote_owner", NA, nv))
        itens.append(_it("codeowners", NA, nv))
    elif not url:
        itens.append(_it("remote_owner", NA, "sem remote.origin.url"))
        itens.append(_it("codeowners", NA, "sem remoto"))
    else:
        dono = dono_do_remoto(url)
        if not dono:
            itens.append(_it("remote_owner", WARN, "remoto nao e GitHub: %s" % url))
        elif not esperado:
            itens.append(_it("remote_owner", WARN, "owner_github nao declarado; o remoto e de %s" % dono))
        elif dono.casefold() != esperado.casefold():
            itens.append(_it("remote_owner", FAIL, "remoto pertence a '%s', a declaracao diz '%s'" % (dono, esperado)))
        else:
            itens.append(_it("remote_owner", PASS, "remoto de %s" % dono))
        co = next((c for c in CODEOWNERS_NOMES if _existe(raiz, c)), None)
        if not esperado:
            itens.append(_it("codeowners", WARN, "owner_github nao declarado"))
        elif not co:
            itens.append(_it("codeowners", WARN, "sem .github/CODEOWNERS"))
        else:
            with open(os.path.join(raiz, *co.split("/")), encoding="utf-8", errors="replace") as fh:
                cita = re.search(r"(?i)(?<![\w-])@" + re.escape(esperado) + r"(?![\w-])", fh.read())
            itens.append(_it("codeowners", PASS if cita else WARN,
                             "%s cita @%s" % (co, esperado) if cita else "%s nao cita @%s" % (co, esperado)))
    # --- manifesto ---
    cert, erro = ultimo_certificado(pid, store, journal)
    if not cert:
        itens.append(_it("manifest", NA, "nunca certificado" + (" (%s)" % erro if erro else "")))
    elif not existe:
        itens.append(_it("manifest", WARN, nv))
    else:
        atuais = hashes(raiz, arquivos_de_ownership(raiz, sec))
        salvos = cert.get("files") or {}
        dif = sorted(["mudou: " + k for k in salvos if k in atuais and atuais[k] != salvos[k]] +
                     ["sumiu: " + k for k in salvos if k not in atuais] +
                     ["novo: " + k for k in atuais if k not in salvos])
        itens.append(_it("manifest", WARN if dif else PASS,
                         ("arquivo(s) mudaram depois da certificacao de %s: %s" % (cert.get("certified_at"), "; ".join(dif)))
                         if dif else "bate com o certificado de %s" % cert.get("certified_at"),
                         certificado=cert.get("certified_at")))
    # --- contradicoes ---
    if not repo or not tem_commit:
        itens.append(_it("contradictions", NA if repo else WARN, nv if not repo else "repositorio sem commit"))
    else:
        ach, total = contradicoes(raiz, sec)
        motivo = (("%d atribuicao(oes) de autoria a nome fora da declaracao" % len(ach)) if ach else
                  "nenhuma atribuicao de autoria contraditoria em README/LICENSE/NOTICE/cabecalhos")
        if total > MAX_ARQUIVOS:
            # corte atingido: o que nao foi lido nao pode sair PASS (r8, Q5)
            motivo += "; leitura truncada: so %d de %d arquivo(s) rastreado(s) lidos" % (MAX_ARQUIVOS, total)
        itens.append(_it("contradictions", WARN if ach or total > MAX_ARQUIVOS else PASS, motivo,
                         **({"achados": ach[:20]} if ach else {})))
    return _fechar(r)


def _fechar(r):
    st = [i["status"] for i in r["itens"]]
    r["status"] = FAIL if FAIL in st else WARN if WARN in st else PASS if PASS in st else NA
    r["falhas"] = [i["item"] for i in r["itens"] if i["status"] == FAIL]
    r["avisos"] = [i["item"] for i in r["itens"] if i["status"] == WARN]
    if r["status"] == NA:
        r["resumo"] = r["itens"][0]["motivo"]
    else:
        r["resumo"] = "%s: %d PASS, %d WARN, %d FAIL%s" % (
            r["status"], st.count(PASS), st.count(WARN), st.count(FAIL),
            (" (" + ", ".join(r["falhas"] + r["avisos"]) + ")") if r["falhas"] or r["avisos"] else "")
    return r


# --------------------------------------------------------------------------- certificar

class OwnershipErro(RuntimeError):
    pass


def _criar_tag(raiz, nome, mensagem):
    """Tag ASSINADA no HEAD. Nunca sobrescreve (sem -f); confere a assinatura no objeto criado."""
    if gitinfo.git(raiz, "tag", "--list", nome).strip():
        raise OwnershipErro("tag %s ja existe: nada sobrescrito" % nome)
    gitinfo.git(raiz, "tag", "-s", "-m", mensagem, nome, "HEAD")
    t = {"name": nome, "sha": gitinfo.git(raiz, "rev-parse", "refs/tags/" + nome).strip(),
         "target": gitinfo.git(raiz, "rev-parse", "refs/tags/%s^{commit}" % nome).strip()}
    obj = gitinfo.git(raiz, "cat-file", "-p", "refs/tags/" + nome)
    if "-----BEGIN SSH SIGNATURE-----" not in obj and "-----BEGIN PGP SIGNATURE-----" not in obj:
        raise OwnershipErro("tag %s criada SEM assinatura no objeto (%s)" % (nome, _remover_tag(raiz, t)))
    return t


def _remover_tag(raiz, t):
    """Remove a tag criada NESTA execucao, so se a ref ainda aponta para o objeto criado. Devolve o relato."""
    rc, atual = gitinfo.git(raiz, "rev-parse", "--verify", "--quiet", "refs/tags/" + t["name"], check=False)
    if rc != 0 or atual.strip() != t["sha"]:
        return "tag %s NAO removida: a ref ja nao aponta para o objeto criado nesta execucao" % t["name"]
    rc, _ = gitinfo.git(raiz, "tag", "-d", t["name"], check=False)
    return ("tag %s criada nesta execucao foi removida" % t["name"]) if rc == 0 else (
        "tag %s criada nesta execucao NAO foi removida (git tag -d falhou): remova a mao" % t["name"])


def _autores_do_certificado(raiz):
    """Nome + SHA-256 (hex) do e-mail normalizado: o certificado nunca leva e-mail em claro (r8, S2)."""
    return [{"name": n, "email_sha256": hashlib.sha256(e.strip().lower().encode("utf-8")).hexdigest(),
             "role": papel, "commits": c} for n, e, papel, c in autores(raiz)]


def certificar(contrato, store, maquina=None, tag=False, journal=None):
    """Roda o check; com FAIL recusa SEM gravar nada. Grava o certificado na nuvem e no journal."""
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    pid = contrato["identity"]["id"]
    chk = verificar(contrato, maquina, store=store, journal=journal)
    res = {"ok": False, "project": pid, "check": chk}
    if chk["falhas"]:
        res["recusado"] = "ownership-check com FAIL: %s" % ", ".join(chk["falhas"])
        return res
    raiz = chk["caminho"]
    if not raiz or not gitinfo.eh_repo(raiz) or not gitinfo.tem_commit(raiz):
        res["recusado"] = "sem repositorio com commit em %s: nada a certificar" % raiz
        return res
    sec = contrato["ownership"]
    ts = bk.carimbo()
    f = chk["assinatura"] or fatos_assinatura(raiz)
    if tag and not f["signingkey_ok"]:
        res["recusado"] = "--tag exige assinatura configurada: %s" % f["signingkey_motivo"]
        return res
    cert = {
        "project": pid,
        "certified_at": ts,
        "head": gitinfo.git(raiz, "rev-parse", "HEAD").strip(),
        "ownership": _redigir_certificado(sec, f),
        "files": hashes(raiz, arquivos_de_ownership(raiz, sec)),
        "authors": _autores_do_certificado(raiz),
        "signing": _sem_caminho_da_maquina(f),
        "remote": _redigir_certificado(chk["remoto"], f),
        "checks": _redigir_certificado(chk["itens"], f),
        "tool_version": "eos %s" % __version__,
        "tag": None,
    }
    if tag:
        nome = "ownership-" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d")
        try:
            cert["tag"] = _criar_tag(raiz, nome, "ownership certificado em %s (eos %s)" % (ts, __version__))
        except (OwnershipErro, gitinfo.GitErro) as e:
            res["recusado"] = "tag assinada nao criada, nada gravado: %s" % str(e)[:300]
            return res
    texto = json.dumps(cert, ensure_ascii=False, indent=2)
    rel = rel_ledger(pid, ts)
    try:
        store.escrever_texto(rel, texto)
        if store.ler_texto(rel).strip() != texto.strip():
            raise OwnershipErro("certificado gravado na nuvem difere do gerado: %s" % rel)
    except Exception as e:
        # tag sem certificado na nuvem seria prova orfa: desfaz so a que ESTA execucao criou (r8, Q9)
        relato = ("; " + _remover_tag(raiz, cert["tag"])) if cert["tag"] else ""
        raise OwnershipErro("gravacao do certificado na nuvem falhou: %s%s" % (str(e)[:300], relato)) from e
    jdir = journal or journal_padrao()
    cloud.DirStore(jdir).escrever_texto(pid + "/" + ts + ".json", texto)
    res.update(ok=True, certificado=cert, nuvem=rel, journal=os.path.join(jdir, pid, ts + ".json"))
    return res


# --------------------------------------------------------------------------- nascimento (eos new)

EMPREGADOR_POR_CATEGORIA = {"PROG": "PROG"}
FERRAMENTAS_IA = "assistentes de IA (Claude Code, Codex) usados como ferramenta, sem autoria"


def secao_padrao(owner, github, categoria, identidades=()):
    """Secao `ownership` padrao de um PROJECT novo (valida pelo contrato v1)."""
    sec = {
        "declared_owner": owner,
        "owner_github": github,
        "creators": [owner],
        "contributors": [],
        # Declarado desde o nascimento: o PROVENANCE cita os assistentes de IA como ferramenta.
        "tool_accounts": [FERRAMENTAS_IA],
        "license": "proprietary",
        "third_party": [],
        "provenance_file": "PROVENANCE.md",
        "signing": "required",
        "identities": list(identidades),
        "evidence": [],
    }
    if not github:
        sec.pop("owner_github")
    emp = EMPREGADOR_POR_CATEGORIA.get(categoria)
    if emp:
        sec["employer_or_client"] = emp
    return sec


def _lista_md(itens, vazio):
    return "\n".join("- %s" % x for x in itens) if itens else vazio


def _primeiro_commit(dir_):
    """Data (AAAA-MM-DD) do primeiro commit do repo, ou None. So leitura."""
    if not dir_:
        return None
    try:
        r = subprocess.run(["git", "-C", dir_, "log", "--reverse", "--format=%as", "--max-parents=0"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    linhas = [x for x in r.stdout.splitlines() if x.strip()] if r.returncode == 0 else []
    return linhas[0] if linhas else None


def _textos(contrato, dir_=None):
    ident = contrato["identity"]
    sec = contrato["ownership"]
    pid, nome = ident["id"], ident["name"]
    hoje = datetime.date.today().isoformat()
    criadoras = ", ".join(sec.get("creators") or [])
    terceiros = ["%s (licenca %s%s)" % (t["name"], t["license"], ", em `%s`" % t["path"] if t.get("path") else "")
                 for t in sec.get("third_party") or []]
    remoto = (contrato.get("git") or {}).get("remote") or "sem remoto declarado"
    drive = (contrato.get("cloud") or {}).get("drive_root") or "nao declarado"
    gh = sec.get("owner_github")
    out = {}
    out[sec.get("provenance_file") or "PROVENANCE.md"] = "\n".join([
        "# Proveniencia - %s" % nome, "",
        "- Projeto: `%s`" % pid,
        "- Primeiro commit: %s" % (_primeiro_commit(dir_) or "ainda sem commit (nascimento)"),
        "- Proveniencia registrada em: %s" % hoje,
        "- Criadora(s): %s" % criadoras,
        "- Titular declarada: %s" % sec["declared_owner"],
        "- Contexto contratual (empresa/cliente): %s" % (sec.get("employer_or_client") or "nenhum declarado"),
        "- Licenca: %s" % (sec.get("license") or "nao declarada"), "",
        "## Ferramentas usadas", "",
        "Ferramentas, assistentes de IA e contas usadas SEM autoria:", "",
        _lista_md(sec.get("tool_accounts") or [], "- nenhuma conta de terceiro declarada"), "",
        "## Componentes de terceiro", "",
        _lista_md(terceiros, "Nenhum declarado."), "",
        "## Cadeia de custodia", "",
        "- Repositorio Git: %s" % remoto,
        "- Dados brutos e originais: Drive, `EMMILY PROJECT CLOUD/%s` (ADR-0015)" % drive,
        "- Hashes destes arquivos: certificado em `99 RECOVERY/manifests/%s/ownership-<ts>.json` "
        "(`py -3.13 -m eos ownership-certify %s`)" % (pid, pid), ""])
    out["OWNERSHIP.md"] = "\n".join([
        "# Titularidade - %s" % nome, "",
        "- Titular declarada: %s" % sec["declared_owner"],
        "- Base da declaracao: criacao por %s; identidades Git declaradas no contrato do registry "
        "(`registry/projects/%s.yaml`, secao `ownership`)" % (criadoras, pid),
        "- Contexto contratual: %s (contexto, nao autoria)" % (sec.get("employer_or_client") or "nenhum"), "",
    ] + ([
        "> O Emmily AI Project OS registra AUTORIA, CUSTODIA e PROVENIENCIA. Titularidade patrimonial",
        "> de software feito em contexto de trabalho ou de contrato segue o vinculo correspondente",
        "> (ex.: Lei 9.609/1998, art. 4) e NAO e decidida por este arquivo.", "",
    ] if sec.get("employer_or_client") else []) + [
        "## O que NAO e reivindicado", "",
        "- Dependencias e bibliotecas de terceiros, cada uma sob a propria licenca.",
        _lista_md(terceiros, "- Nenhum componente de terceiro incorporado declarado."), "",
        "## Contato", "",
        "- %s" % ("GitHub @%s" % gh if gh else sec["declared_owner"]), ""])
    out["AUTHORS.md"] = "\n".join([
        "# Autoria - %s" % nome, "",
        "## Criadora(s)", "", _lista_md(sec.get("creators") or [], "- (nao declarado)"), "",
        "## Contribuidores", "", _lista_md(sec.get("contributors") or [], "Nenhum contribuidor externo ate agora."), ""])
    out["NOTICE"] = "\n".join([
        "%s" % nome, "",
        "Atribuicoes de componentes de terceiro incorporados a este projeto.",
        "Arquivo mantido mesmo vazio: a ausencia de terceiros e declarada, nao omitida.", "",
        _lista_md(terceiros, "Nenhum componente de terceiro incorporado ate agora."), ""])
    if gh:
        out[".github/CODEOWNERS"] = "* @%s\n" % gh
    return out


# arquivo gerado -> nomes que cumprem o mesmo papel (o check aceita qualquer um deles)
EQUIVALENTES = {".github/CODEOWNERS": CODEOWNERS_NOMES, "AUTHORS.md": AUTHORS_NOMES}


def gerar_arquivos(dir, contrato, sobrescrever=False):
    """Escreve PROVENANCE.md, OWNERSHIP.md, AUTHORS.md, NOTICE e .github/CODEOWNERS a partir do
    contrato. Nunca sobrescreve sem `sobrescrever=True`; nunca gera um arquivo cujo equivalente ja existe
    (CODEOWNERS na raiz/docs/.github, AUTHORS sem extensao). A pasta do projeto TEM de existir: so
    subpastas (.github) sao criadas. Devolve {rel: 'criado'|'existente'|'existente (equivalente: x)'|motivo}."""
    if not isinstance(contrato.get("ownership"), dict):
        raise OwnershipErro("contrato sem secao ownership: nada a gerar")
    if not os.path.isdir(dir):
        raise OwnershipErro("pasta do projeto nao existe: %s (nada criado)" % dir)
    res = {}
    for rel, texto in _textos(contrato, dir).items():
        p = os.path.join(dir, *rel.split("/"))
        if os.path.exists(p):
            if not sobrescrever:
                res[rel] = "existente"
                continue
        else:
            eq = next((e for e in EQUIVALENTES.get(rel, ()) if e != rel and _existe(dir, e)), None)
            if eq:
                res[rel] = "existente (equivalente: %s)" % eq
                continue
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(texto)
        res[rel] = "criado"
    if not contrato["ownership"].get("owner_github"):
        res[".github/CODEOWNERS"] = "nao gerado: owner_github nao declarado"
    return res


def ssh_keygen():
    """ssh-keygen disponivel (PATH ou o do Git for Windows), ou None. Usado pelos testes."""
    achado = shutil.which("ssh-keygen")
    if achado:
        return achado
    g = shutil.which("git")
    if g:
        cand = os.path.join(os.path.dirname(os.path.dirname(g)), "usr", "bin", "ssh-keygen.exe")
        if os.path.isfile(cand):
            return cand
    return None
