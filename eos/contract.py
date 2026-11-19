"""Contrato de projeto, versao 1 - schema e validacao.

O contrato e o registro canonico de UM item do ecossistema (registry/projects/<id>.yaml).
Ele declara INTENCAO e configuracao. Estado medido (saude, nivel atingido, ultimo backup) NAO
mora aqui: e derivado por verificacao real (portability.py) e gravado no ledger da nuvem. A
unica excecao e `certification`, escrita pela propria certificacao, porque e evidencia de um
evento passado e precisa viajar com o repositorio.

Validacao falha FECHADO: campo desconhecido e erro (erro de digitacao em nome de campo nao pode
virar "campo ausente, use o padrao"), enum fora do vocabulario e erro, tipo errado e erro.
"""
import re

VERSAO = 1

# REFERENCE_DATA: acervo de referencia (normas, bases publicas) - classificado, sem nivel, como
# ARCHIVE/COLLECTION (spec de ownership, 2026-10-12)
TIPOS = ("PROJECT", "COLLECTION", "EXTERNAL_SOURCE", "ARCHIVE", "REFERENCE_DATA")
# Tipos que a escada L0-L6 NAO alcanca: classificados, nunca certificados.
CLASSIFICADOS = tuple(t for t in TIPOS if t != "PROJECT")
CATEGORIAS = ("PLATFORM", "PROG", "PERSONAL", "UNIVERSITY", "PORTFOLIO", "LAB")
STATUS = ("active", "paused", "archived")
CRITICIDADE = ("low", "medium", "high")
NIVEIS = ("L0", "L1", "L2", "L3", "L4", "L5", "L6")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,62}$")

# Schema declarativo: campo -> (tipo, obrigatorio, vocabulario|subschema)
# tipo: 'str' | 'int' | 'bool' | 'enum' | 'map' | 'list' | 'strlist' | 'any'
SCHEMA = {
    "contract_version": ("int", True, None),
    "identity": ("map", True, {
        "id": ("str", True, None),
        "name": ("str", True, None),
        "type": ("enum", True, TIPOS),
        "category": ("enum", True, CATEGORIAS),
        "status": ("enum", True, STATUS),
        "criticality": ("enum", True, CRITICIDADE),
        "description": ("str", False, None),
        "owner": ("str", False, None),
    }),
    "workspace": ("map", False, {
        # Caminho com variaveis portaveis (${USERPROFILE}, ${AI_WORKSPACE}...). A maquina pode
        # sobrescrever por id em machine.yaml -> projects.<id>.local_path.
        "local_path": ("str", True, None),
        "onedrive_synced": ("bool", False, None),
    }),
    "git": ("map", False, {
        "enabled": ("bool", True, None),
        "default_branch": ("str", False, None),
        "remote": ("str", False, None),          # "" = ainda sem remoto (declarado, nao omitido)
        "visibility": ("enum", False, ("private", "public", "none")),
        "worktrees_policy": ("enum", False, ("preserve-all", "none")),
    }),
    "cloud": ("map", False, {
        "drive_root": ("str", True, None),       # relativo a raiz logica (EMMILY PROJECT CLOUD)
    }),
    "external_sources": ("list", False, {
        "id": ("str", True, None),
        "type": ("enum", True, ("sharepoint", "onedrive", "graph-api", "web", "other")),
        "role": ("str", True, None),
        "required_for_operation": ("bool", True, None),
        "location": ("str", False, None),
    }),
    "state": ("map", False, {
        "strategy": ("enum", True, ("git-only", "sqlite", "files")),
        "databases": ("list", False, {
            "path": ("str", True, None),
            "engine": ("enum", True, ("sqlite",)),
            "max_age_hours": ("int", False, None),
        }),
    }),
    "data": ("list", False, {
        "path": ("str", True, None),
        "policy": ("enum", True, ("cloud-mirror", "reproducible", "external", "none")),
        "note": ("str", False, None),
        # a titular ainda nao decidiu se o dado pode ir a nuvem: `eos mirror` recusa a entrada e o
        # check a acusa como motivo, qualquer que seja a policy (r10, S-A1)
        "decisao_pendente": ("bool", False, None),
    }),
    "environment": ("map", False, {
        "runtime": ("enum", True, ("python", "node", "powershell", "mixed", "none")),
        "version": ("str", False, None),
        "manifest": ("str", False, None),        # requirements.txt / pyproject.toml / package.json
        "bootstrap": ("str", False, None),
        "test_command": ("str", False, None),
        "smoke_command": ("str", False, None),
    }),
    "secrets": ("map", False, {
        "manifest": ("str", True, None),         # arquivo versionado com NOMES, nunca valores
        "store": ("enum", True, ("bitwarden", "local-env", "none")),
        # caminhos EXATOS de documentacao/teste cujo nome parece de segredo (secret-handling.md,
        # test_check_secrets.py). Nunca .env nem chave: gitinfo.permitivel decide.
        "allowed_paths": ("strlist", False, None),
    }),
    "backup": ("map", False, {
        "wip": ("enum", True, ("snapshot", "none")),
        "max_age_hours": ("int", False, None),
        "exclude": ("strlist", False, None),
    }),
    "ai": ("map", False, {
        "canonical": ("strlist", True, None),    # arquivos neutros de provedor
        "adapters": ("strlist", False, None),    # CLAUDE.md, AGENTS.md...
    }),
    "portability": ("map", False, {
        "target_level": ("enum", True, NIVEIS),
    }),
    "certification": ("map", False, {
        "level": ("enum", True, NIVEIS),
        "date": ("str", True, None),
        "commit": ("str", True, None),
        "evidence": ("str", True, None),
        "restored_from": ("strlist", False, None),
    }),
    # Titularidade DECLARADA e proveniencia (eos/ownership.py). Opcional no schema; obrigatoria por
    # politica para PROJECT novo: o ownership-check reprova PROJECT sem ela, mas a escada L0-L6 nao muda.
    "ownership": ("map", False, {
        "declared_owner": ("str", True, None),
        "owner_github": ("str", False, None),       # dono esperado do remote.origin.url
        "creators": ("strlist", True, None),
        "contributors": ("strlist", False, None),   # contribuicao real de terceiro: nunca apagar
        "tool_accounts": ("strlist", False, None),  # contas/ferramentas usadas SEM autoria
        "employer_or_client": ("str", False, None), # contexto contratual, nao autoria
        "license": ("str", False, None),            # SPDX ou 'proprietary'
        "third_party": ("list", False, {
            "name": ("str", True, None),
            "license": ("str", True, None),
            "path": ("str", False, None),
        }),
        "provenance_file": ("str", False, None),    # padrao PROVENANCE.md
        "signing": ("enum", False, ("required", "recommended", "none")),
        "identities": ("strlist", False, None),     # 'Nome <email>' que SAO da titular
        "evidence": ("strlist", False, None),
    }),
    "notes": ("strlist", False, None),
}

# Campos exigidos por tipo de item, alem do schema.
EXIGIDO_POR_TIPO = {
    "PROJECT": ("workspace", "git", "cloud", "backup", "portability"),
    "COLLECTION": ("workspace", "cloud"),
    "EXTERNAL_SOURCE": (),
    "ARCHIVE": ("cloud",),
    "REFERENCE_DATA": ("cloud",),
}


def _valida(valor, spec, caminho, erros):
    tipo, _, extra = spec
    if tipo == "str":
        if not isinstance(valor, str):
            erros.append("%s: esperava texto" % caminho)
    elif tipo == "int":
        if not isinstance(valor, int) or isinstance(valor, bool):
            erros.append("%s: esperava inteiro" % caminho)
    elif tipo == "bool":
        if not isinstance(valor, bool):
            erros.append("%s: esperava true/false" % caminho)
    elif tipo == "enum":
        if valor not in extra:
            erros.append("%s: '%s' fora do vocabulario %s" % (caminho, valor, "|".join(extra)))
    elif tipo == "strlist":
        if not isinstance(valor, list) or not all(isinstance(x, str) for x in valor):
            erros.append("%s: esperava lista de textos" % caminho)
    elif tipo == "map":
        if not isinstance(valor, dict):
            erros.append("%s: esperava mapa" % caminho)
        else:
            _valida_mapa(valor, extra, caminho, erros)
    elif tipo == "list":
        if not isinstance(valor, list):
            erros.append("%s: esperava lista" % caminho)
        else:
            for i, item in enumerate(valor):
                if not isinstance(item, dict):
                    erros.append("%s[%d]: esperava mapa" % (caminho, i))
                else:
                    _valida_mapa(item, extra, "%s[%d]" % (caminho, i), erros)


def _valida_mapa(d, schema, caminho, erros):
    for k in d:
        if k not in schema:
            erros.append("%s.%s: campo desconhecido" % (caminho, k) if caminho else "%s: campo desconhecido" % k)
    for k, spec in schema.items():
        p = "%s.%s" % (caminho, k) if caminho else k
        if k not in d or d[k] is None:
            if spec[1]:
                erros.append("%s: obrigatorio" % p)
            continue
        _valida(d[k], spec, p, erros)


def motivo_caminho_relativo(p):
    """None se `p` e caminho RELATIVO literal dentro do projeto; senao o motivo. Recusa absoluto,
    unidade, '..', componente vazio e caractere de glob/pathspec (r10, QA-A3): o valor vira
    pathspec do git, e '*' excluiria o repositorio inteiro. Recusa tambem componente terminado em
    espaco ou ponto (r12, Sec1): o Windows os descarta, e 'data ' seria a pasta 'data'."""
    if not isinstance(p, str) or not p.strip():
        return "vazio"
    r = p.replace("\\", "/")
    if r.startswith("/") or re.match(r"^[A-Za-z]:", r):
        return "'%s' e absoluto: use caminho relativo ao projeto" % p
    if any(x in ("", ".", "..") for x in r.split("/")):
        return "'%s' tem '..', '.' ou componente vazio" % p
    if any(x != x.rstrip(" .") for x in r.split("/")):
        return "'%s' tem componente terminado em espaco ou ponto (o Windows o descarta)" % p
    if re.search(r"[*?\[\]:!]", r) or any(ord(c) < 32 for c in r):
        return "'%s' tem caractere de glob/pathspec ou de controle: so caminho literal" % p
    return None


def validar(doc, nome_arquivo=None):
    """Devolve a lista de erros (vazia = valido)."""
    erros = []
    if not isinstance(doc, dict):
        return ["documento: esperava mapa no topo"]
    _valida_mapa(doc, SCHEMA, "", erros)
    if doc.get("contract_version") not in (None, VERSAO) and isinstance(doc.get("contract_version"), int):
        erros.append("contract_version: %s nao suportada (esta versao le %d)" % (doc["contract_version"], VERSAO))
    ident = doc.get("identity") if isinstance(doc.get("identity"), dict) else {}
    pid = ident.get("id")
    if isinstance(pid, str) and not ID_RE.match(pid):
        erros.append("identity.id: '%s' invalido (minusculas, digitos e hifen)" % pid)
    if nome_arquivo and isinstance(pid, str) and nome_arquivo != pid + ".yaml":
        erros.append("identity.id: '%s' nao bate com o arquivo '%s'" % (pid, nome_arquivo))
    tipo = ident.get("type")
    for campo in EXIGIDO_POR_TIPO.get(tipo, ()):
        if campo not in doc:
            erros.append("%s: obrigatorio para type %s" % (campo, tipo))
    g = doc.get("git") if isinstance(doc.get("git"), dict) else {}
    remoto = g.get("remote")
    if isinstance(remoto, str) and remoto and g.get("visibility") == "public":
        erros.append("git.visibility: public exige decisao explicita - nunca e padrao (ADR-0003)")
    if isinstance(remoto, str) and remoto and not re.match(r"^https://github\.com/[^/]+/[^/]+?(\.git)?$", remoto):
        erros.append("git.remote: '%s' nao e URL https do GitHub" % remoto)
    for i, s in enumerate(doc.get("external_sources") or []):
        if isinstance(s, dict) and s.get("type") == "sharepoint" and tipo == "PROJECT" and s.get("role") == "backup":
            erros.append("external_sources[%d]: SharePoint nao e backup do projeto (programa §38)" % i)
    own = doc.get("ownership") if isinstance(doc.get("ownership"), dict) else {}
    if isinstance(own.get("provenance_file"), str):
        motivo = motivo_caminho_relativo(own["provenance_file"])
        if motivo:
            erros.append("ownership.provenance_file: " + motivo)
    # r12 (QA-A2/Sec1): data[].path invalido era descartado em silencio na comparacao com o
    # pendente, e o filho subia com o pai
    for i, d in enumerate(doc.get("data") or [] if isinstance(doc.get("data"), list) else []):
        if isinstance(d, dict) and "path" in d:
            motivo = motivo_caminho_relativo(d["path"])
            if motivo:
                erros.append("data[%d].path: %s" % (i, motivo))
    sec = doc.get("secrets") if isinstance(doc.get("secrets"), dict) else {}
    if isinstance(sec.get("allowed_paths"), list):
        from . import gitinfo  # tardio: o contrato nao depende do Git para o resto da validacao
        for p in sec["allowed_paths"]:
            motivo = gitinfo.permitivel(p)
            if motivo:
                erros.append("secrets.allowed_paths: " + motivo)
    return erros
