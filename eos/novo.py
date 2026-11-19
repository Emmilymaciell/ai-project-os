"""Nascimento protegido de projeto:  py -3.13 -m eos new <id> --name "<nome>" --category <CAT>
                                     [--runtime python|node|none] [--sem-remoto] [--sem-rede] [--dry-run]
                                     [--descricao "<frase>"]

Um projeto novo NUNCA nasce L0. Ordem (spec docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md, secao 5), cada
passo VERIFICADO por fato depois de executado:

  1 validar    id (ID_RE), categoria, runtime; recusa id ja no registry ou diretorio nao vazio
  2 workspace  ${AI_WORKSPACE}\\<base da categoria>\\<id> (BASE_WORKSPACE), nunca em OneDrive/Drive
  3 arquivos   template project-standard + STATE, HANDOFF, decisoes, ownership, adapters
  4 git        git init -b main + commit inicial (assinado se a config efetiva pedir)
  5 contrato   registry/projects/<id>.yaml completo, validado pelo schema
  6 remoto     scripts/security-scan.ps1 no projeto (achado = para fechado), gh repo create
               <owner>/<repo> --private, visibilidade conferida, push, ls-remote
  7 drive      raiz do projeto no Drive, pela camada `cloud`
  8 backup     primeiro backup + portability.verificar -> nivel atingido

Falha FECHADO e nada e apagado: se um passo falha, o comando para, imprime o que ja foi feito e o
comando para retomar. O DIARIO da maquina (<estado do motor>/novo/<id>.json, fora do projeto e do
Git) e o que autoriza a retomada: rodar de novo com os MESMOS parametros continua do passo pendente
(cada passo confere o fato antes de agir, entao o que ja existe nao e refeito nem sobrescrito);
parametros diferentes, ou id/diretorio existentes sem diario, sao recusados com mensagem clara.

`--dry-run` imprime o plano e nao cria nada: nem diretorio, nem diario, nem chamada de rede.
`--sem-rede` implica `--sem-remoto`: nenhuma chamada ao gh nem push.

Tudo que toca rede e injetavel (`Dependencias`): gh, git de rede (push/ls-remote), a varredura de
seguranca e o store da nuvem. Os testes rodam sem rede, com gh falso, remoto bare local, varredura
falsa e nuvem em diretorio.
"""
import datetime
import json
import os
import re
import shutil
import subprocess
import tempfile

from . import backup as bk
from . import cloud, contract, gitinfo, ownership, paths, portability, registry, yamlite

PASSOS = ("validar", "workspace", "arquivos", "git", "contrato", "remoto", "drive", "backup")
RUNTIMES = ("python", "node", "none")
TITULAR = "Emmily Maciel"
OWNER_GITHUB = "Emmilymaciell"
TEMPLATE = os.path.join(registry.RAIZ_REPO, "templates", "project-standard")

# Mapeamento REAL dos contratos de registry/projects/ (conferido em 2026-10-12).
DRIVE_ROOT = {"PLATFORM": "00 PLATFORM", "PROG": "01 PROG", "PERSONAL": "02 PERSONAL",
              "UNIVERSITY": "03 UNIVERSITY", "PORTFOLIO": "04 PORTFOLIO", "LAB": "05 LAB"}
# Pasta-base REAL em ${AI_WORKSPACE} por categoria (confirmado pelo Lead em 2026-10-12): <base>\<id>.
BASE_WORKSPACE = {"PROG": "work\\prog", "PERSONAL": "personal", "UNIVERSITY": "university",
                  "PORTFOLIO": "portfolio", "LAB": "ai-lab", "PLATFORM": "_platform"}
# PLATFORM sem prefixo: o unico remoto PLATFORM existente e github.com/Emmilymaciell/ai-project-os.
PREFIXO_REPO = {"PROG": "prog", "PERSONAL": "personal", "UNIVERSITY": "university",
                "PORTFOLIO": "portfolio", "LAB": "lab", "PLATFORM": None}
# Vocabulario do project.yaml do template (identidade.categoria / identidade.cliente).
CATEGORIA_TEMPLATE = {"PROG": "work", "UNIVERSITY": "university", "PERSONAL": "personal",
                      "PORTFOLIO": "personal", "LAB": "ai-lab", "PLATFORM": "platform"}
CLIENTE_TEMPLATE = {"PROG": "prog", "UNIVERSITY": "faculdade"}
# Componente de caminho (inteiro, sem caixa) que denuncia pasta sincronizada. So o diretorio PAI do
# destino e olhado: o id `onedrive-limpeza` nao e nuvem. Biblioteca SharePoint sincronizada fica em
# <perfil>\<Org>\<Site> - Documentos (ou "- Documents"); pasta OneDrive e "OneDrive" ou "OneDrive - <Org>".
NUVEM_EXATA = ("onedrive", "google drive", "googledrive", "meu drive", "my drive", "shared drives",
               "drives compartilhados", "dropbox")
NUVEM_RE = re.compile(r"^(onedrive - .+|dropbox \(.+\)|.+ - (documentos|documents|documentos compartilhados|shared documents))$")
PLACEHOLDER_RE = re.compile(r"\{\{[A-Z_]+\}\}")


class NovoErro(ValueError):
    """Recusa (uso/estado): nada foi criado por ESTA execucao."""


class PassoFalhou(RuntimeError):
    pass


class RemotoPendente(PassoFalhou):
    """O remoto nao pode ser criado/publicado AGORA (gh negado, sem auth, push recusado): vira
    pendencia humana H2 e o nascimento continua (drive + backup) - o projeto fica em L1 com
    relatorio, nunca em excecao. Visibilidade nao-PRIVATE e origin divergente NAO sao pendencia:
    sao falha fechada (PassoFalhou)."""


# --------------------------------------------------------------------------- dependencias

def _caminho_gh():
    return shutil.which("gh") or r"C:\Program Files\GitHub CLI\gh.exe"


def _gh_padrao(args):
    """gh real. Devolve (rc, stdout, stderr). O gh nao esta no PATH desta maquina (runbook)."""
    try:
        r = subprocess.run([_caminho_gh(), *args], capture_output=True, timeout=180)
    except FileNotFoundError:
        return 127, "", "gh nao encontrado (PATH nem C:\\Program Files\\GitHub CLI)"
    except subprocess.TimeoutExpired:
        return 124, "", "gh: tempo esgotado"
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


def _git_rede_padrao(raiz, *args):
    """git que fala com o remoto (push, ls-remote). Devolve (rc, stdout, stderr)."""
    try:
        r = subprocess.run(["git", "-C", raiz, *args], capture_output=True, env=gitinfo._ambiente(), timeout=900)
    except subprocess.TimeoutExpired:
        return 124, "", "git %s: tempo esgotado" % (args[0] if args else "")
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


def _scan_padrao(destino, pid):
    """Varredura de seguranca da plataforma (scripts/security-scan.ps1) no projeto, antes do primeiro
    push. Relatorio em %TEMP%\\emmily-os-scan (nunca suja o projeto). Devolve (rc, relatorio, saida):
    0 limpo, 1 achado ALTA/MEDIA, 2 erro de execucao."""
    pasta = os.path.join(tempfile.gettempdir(), "emmily-os-scan")
    os.makedirs(pasta, exist_ok=True)
    relatorio = os.path.join(pasta, "novo-%s-%s.md" % (pid, datetime.datetime.now().strftime("%Y%m%d-%H%M%S")))
    script = os.path.join(registry.RAIZ_REPO, "scripts", "security-scan.ps1")
    try:
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script,
                            "-Path", destino, "-SemRede", "-Out", relatorio], capture_output=True, timeout=1800)
    except FileNotFoundError:
        return 2, relatorio, "powershell nao encontrado"
    except subprocess.TimeoutExpired:
        return 2, relatorio, "varredura: tempo esgotado"
    saida = (r.stdout + r.stderr).decode("utf-8", "replace").strip()
    if r.returncode == 0:
        # rc 0 com lacuna NESTA execucao nao e "limpo": e ausencia de evidencia (r10, S-A4)
        try:
            with open(relatorio, encoding="utf-8", errors="replace") as f:
                lacunas = lacunas_da_varredura(f.read())
        except OSError:
            lacunas = None
        if lacunas is None:
            return 2, relatorio, "varredura sem relatorio legivel ou sem a secao '%s': falha fechada" % SECAO_LACUNAS
        if lacunas:
            return 2, relatorio, ("lacuna(s) nesta execucao da varredura (ausencia de evidencia, nao aprovacao): %s"
                                  % "; ".join(lacunas))[:500]
    return r.returncode, relatorio, saida[-500:]


SECAO_LACUNAS = "### Lacunas DESTA execucao"
# Linhas da secao que nao sao lacuna de cobertura: o marcador de "nenhuma" e a nota sobre o destino
# do relatorio (o -Out fica fora do projeto de proposito, para nao suja-lo)
NAO_E_LACUNA = ("(nenhuma)", "Se o destino deste relatorio esta ignorado")
# Lacunas FECHADAS pelo motor, porque sao de PRECISAO da auditoria de regras do .gitignore e nao de
# leitura de conteudo: credencial, dado pessoal e nome de segredo continuam varridos em todo arquivo.
# O template do `eos new` produz as tres primeiras em todo nascimento (`*.py[cod]` e `!/examples/`).
# Qualquer outra linha (conteudo nao lido, historico nao varrido, visibilidade, divergencia interna,
# linha nova que este codigo nao conhece) e falha fechada: lista de permissao, nao de proibicao.
LACUNA_FECHADA_PELO_MOTOR = ("Classe de caractere completa em", "Atribuicao individual de",
                             "Nome canonico de segredo DENTRO de subarvore liberada por negacao")
BLOB_VAZIO = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"  # sha do blob vazio: o mesmo em todo repositorio Git


def _blob_vazio_fechado(celula, resto):
    """'N blob(s) do historico que o cat-file devolveu vazio' fecha por IDENTIDADE: so se todo sha
    listado e o do blob vazio do Git e a lista nao foi truncada ('e mais')."""
    if "devolveu vazio" not in celula or "e mais" in resto:
        return False
    shas = re.findall(r"\b([0-9a-f]{7,40})\b \(", resto)
    return bool(shas) and all(BLOB_VAZIO.startswith(s) for s in shas)


def lacunas_da_varredura(texto):
    """Primeira coluna de cada linha da tabela em 'Lacunas DESTA execucao' do security-scan.ps1 que
    NAO foi fechada (NAO_E_LACUNA, LACUNA_FECHADA_PELO_MOTOR, blob vazio por identidade).
    None se a secao nao existe (relatorio truncado ou de outro formato)."""
    linhas = texto.splitlines()
    try:
        i = next(k for k, l in enumerate(linhas) if l.strip() == SECAO_LACUNAS)
    except StopIteration:
        return None
    out = []
    for l in linhas[i + 1:]:
        s = l.strip()
        if s.startswith("#"):
            break
        if not s.startswith("|") or s.startswith("|---") or s.startswith("| O que NAO foi varrido"):
            continue
        partes = s.strip("|").split("|")
        celula, resto = partes[0].strip(), "|".join(partes[1:])
        if not celula or celula.startswith(NAO_E_LACUNA + LACUNA_FECHADA_PELO_MOTOR):
            continue
        if _blob_vazio_fechado(celula, resto):
            continue
        out.append(celula.replace("**", "")[:160])
    return out


class Dependencias:
    """O que toca rede (e a varredura que a antecede). `store=None` = transporte declarado na maquina
    (cloud.store_da_maquina), criado so quando um passo precisa dele (o --dry-run nunca o cria)."""

    def __init__(self, gh=None, git_rede=None, store=None, rede=True, scan=None):
        self.gh = gh or _gh_padrao
        self.git_rede = git_rede or _git_rede_padrao
        self.scan = scan or _scan_padrao
        self._store = store
        self.rede = rede

    def store(self, maquina):
        if self._store is None:
            self._store = cloud.store_da_maquina(maquina)
        return self._store


# --------------------------------------------------------------------------- regras puras

def nome_repo(pid, categoria):
    """Nome do repo no GitHub: o id se ja comeca pelo prefixo da categoria, senao <prefixo>-<id>."""
    pre = PREFIXO_REPO[categoria]
    if not pre or pid.startswith(pre + "-"):
        return pid
    return "%s-%s" % (pre, pid)


def caminho_bruto(pid, categoria):
    return "${AI_WORKSPACE}\\%s\\%s" % (BASE_WORKSPACE[categoria], pid)


def _na_nuvem_sincronizada(destino):
    """O componente do diretorio PAI do destino que e pasta sincronizada, ou None."""
    pai = os.path.dirname(destino.replace("/", "\\").rstrip("\\"))
    for comp in pai.split("\\"):
        baixo = comp.strip().lower()
        if baixo in NUVEM_EXATA or NUVEM_RE.match(baixo):
            return comp
    return None


def _diretorio_vazio(p):
    return not os.path.exists(p) or (os.path.isdir(p) and not os.listdir(p))


def _git_config_efetiva(chave, repo=None, booleano=False):
    """Valor efetivo da config (system+global[+local do repo]); None se ausente."""
    tipo = ["--type=bool"] if booleano else []
    if repo:
        rc, out = gitinfo.git(repo, "config", *tipo, "--get", chave, check=False)
    else:
        # sem repo: roda num diretorio que nao e repositorio, para ler so system+global
        r = subprocess.run(["git", "config", *tipo, "--get", chave], capture_output=True,
                           env=gitinfo._ambiente(), cwd=tempfile.gettempdir(), timeout=60)
        rc, out = r.returncode, r.stdout.decode("utf-8", "replace")
    return out.strip() if rc == 0 and out.strip() else None


# --------------------------------------------------------------------------- ownership
# Integrado com eos.ownership (2026-10-12): a secao vem de ownership.secao_padrao e o schema do
# contrato (contract.SCHEMA["ownership"]) a valida junto com o resto. Os TEXTOS dos arquivos de
# nascimento continuam aqui (_textos_ownership): descrevem o nascimento protegido, que o
# ownership.gerar_arquivos generico (feito para projetos existentes) nao conhece.

OWNERSHIP_SCHEMA_LOCAL = contract.SCHEMA["ownership"][2]  # alias de compatibilidade


def _ownership_padrao(owner, github, categoria):
    return ownership.secao_padrao(owner, github, categoria)


def _validar_ownership_local(sec):
    erros = []
    contract._valida(sec, contract.SCHEMA["ownership"], "ownership", erros)
    return erros


def _textos_ownership(contrato):
    o = contrato["ownership"]
    i = contrato["identity"]
    url = (contrato.get("git") or {}).get("remote")
    remoto = ("remoto privado %s (ADR-0003 da plataforma)" % url if url
              else "ainda sem remoto (nasceu com --sem-remoto); quando houver, privado (ADR-0003 da plataforma)")
    contexto = o.get("employer_or_client")
    ids = ", ".join("`%s`" % x for x in o.get("identities") or []) or "(nenhuma identidade Git configurada no nascimento)"
    data = (contrato.get("_data") or datetime.date.today().isoformat())
    prov = "\n".join([
        "# PROVENANCE — %s" % i["name"], "",
        "> De onde este projeto veio e quem o criou. Fatos, não opinião. Fonte estruturada:",
        "> seção `ownership` do contrato `registry/projects/%s.yaml` no Emmily AI Project OS." % i["id"], "",
        "| Campo | Valor |", "|---|---|",
        "| Projeto | `%s` (%s) |" % (i["id"], i["category"]),
        "| Origem | criado do zero por `py -3.13 -m eos new` a partir do template `project-standard` |",
        "| Data de criação | %s |" % data,
        "| Criadora | %s |" % ", ".join(o["creators"]),
        "| Contexto contratual | %s |" % ("%s — contexto, não autoria" % contexto if contexto else "nenhum declarado"),
        "| Identidades Git da titular | %s |" % ids,
        "| Ferramentas | motor `eos` do Emmily AI Project OS; assistentes de IA usados como ferramenta, sem autoria (`ownership.tool_accounts`) |",
        "| Componentes de terceiro | nenhum no nascimento (ver `NOTICE`) |", "",
        "## Cadeia de custódia", "",
        "- **Original:** este repositório Git; %s." % remoto,
        "- **Dado bruto:** Drive `EMMILY PROJECT CLOUD/%s` — nunca no Git (ADR-0015 da plataforma)." % contrato["cloud"]["drive_root"],
        "- **Backups:** `99 RECOVERY/` na nuvem, cada artefato conferido por hash e listado em manifesto.",
        "- **Hashes:** o commit inicial fixa o estado de nascimento; a certificação de ownership registra o SHA-256 destes arquivos.",
        ""])
    contexto_txt = ("- A relação contratual com **%s** pode determinar a titularidade de parte deste trabalho; "
                    "esta declaração não substitui o contrato. Material, dado e documento fornecidos por %s continuam de %s." % (contexto, contexto, contexto)
                    if contexto else "- Nenhum contexto contratual declarado no nascimento.")
    own = "\n".join([
        "# OWNERSHIP — %s" % i["name"], "",
        "- **Titular declarada:** %s%s" % (o["declared_owner"], " (GitHub @%s)" % o["owner_github"] if o.get("owner_github") else ""),
        "- **Base da declaração:** projeto criado pela titular em %s; registrado no contrato do projeto, seção `ownership`." % data,
        "- **Licença:** %s." % ("proprietária — todos os direitos reservados" if o.get("license") == "proprietary" else o.get("license")),
        "- **Assinatura de commits:** %s." % o.get("signing"), "",
        "## O que NÃO é reivindicado", "",
        "- Dependências e componentes de terceiro, sob as licenças deles (ver `NOTICE`).",
        "- Ferramentas e contas usadas sem autoria (assistentes de IA, contas de serviço).",
        contexto_txt, "",
        "## Contato", "",
        "- %s" % ("@%s no GitHub" % o["owner_github"] if o.get("owner_github") else o["declared_owner"]), ""])
    autores = "\n".join([
        "# AUTHORS — %s" % i["name"], "",
        "## Criadora", ""] + ["- %s" % c for c in o["creators"]] + [
        "", "## Contribuidores", "",
        "_(nenhum até agora — contribuição real de terceiro entra aqui e nunca é apagada)_", ""])
    notice = "\n".join([
        "%s — NOTICE" % i["name"], "",
        "Atribuições de componentes de terceiro incluídos neste repositório.",
        "Nenhum componente de terceiro foi incluído no nascimento do projeto (%s)." % data,
        "Ao incluir um, registre aqui nome, licença e caminho, e na seção ownership.third_party do contrato.", ""])
    codeowners = "# Dono esperado de todo o repositório (seção ownership do contrato).\n* @%s\n" % (o.get("owner_github") or OWNER_GITHUB)
    return {"PROVENANCE.md": prov, "OWNERSHIP.md": own, "AUTHORS.md": autores, "NOTICE": notice,
            ".github/CODEOWNERS": codeowners}


def _arquivos_ownership(dir_, contrato):
    """Escreve os arquivos de ownership que ainda NAO existem. Nunca sobrescreve."""
    criados, preservados = [], []
    for rel, txt in _textos_ownership(contrato).items():
        if _escrever_se_ausente(dir_, rel, txt.encode("utf-8")):
            criados.append(rel)
        else:
            preservados.append(rel)
    return {"criados": criados, "preservados": preservados}


# --------------------------------------------------------------------------- plano

def _ambiente_do_contrato(runtime):
    testes = ".\\tests\\run-tests.ps1"
    ps = "powershell -NoProfile -ExecutionPolicy Bypass -File "
    smoke = ps + ".\\bootstrap.ps1; if ($LASTEXITCODE) { exit 1 }; " + ps + testes + "; exit $LASTEXITCODE"
    if runtime == "python":
        return {"runtime": "python", "version": "3.13", "manifest": "requirements.txt", "bootstrap": ".\\bootstrap.ps1",
                "test_command": testes, "smoke_command": smoke}
    if runtime == "node":
        return {"runtime": "node", "version": "24", "manifest": "package.json", "bootstrap": "npm install",
                "test_command": testes, "smoke_command": ps + testes + "; exit $LASTEXITCODE"}
    return {"runtime": "none", "bootstrap": ".\\bootstrap.ps1", "test_command": testes,
            "smoke_command": ps + testes + "; exit $LASTEXITCODE"}


def _contrato(p):
    c = {
        "contract_version": contract.VERSAO,
        "identity": {"id": p["id"], "name": p["nome"], "type": "PROJECT", "category": p["categoria"],
                     "status": "active", "criticality": "low", "description": p["descricao"], "owner": TITULAR},
        "workspace": {"local_path": p["local_path"]},
        "git": {"enabled": True, "default_branch": "main", "remote": p["remote"], "visibility": "private",
                "worktrees_policy": "preserve-all"},
        "cloud": {"drive_root": p["drive_root"]},
        "state": {"strategy": "git-only"},
        "environment": _ambiente_do_contrato(p["runtime"]),
        "secrets": {"manifest": ".env.example", "store": "none"},
        "backup": {"wip": "snapshot"},
        "ai": {"canonical": ["docs/STATE.md", "docs/HANDOFF.md"], "adapters": ["CLAUDE.md", "AGENTS.md"]},
        "portability": {"target_level": "L6"},
        "notes": ["nascido por eos new em %s (nascimento protegido, spec docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md secao 5)" % p["data"]]
                 + (["--sem-remoto: nasceu sem remoto por decisao explicita; L2 exige criar o remoto privado"] if p["sem_remoto"] else []),
        "ownership": p["ownership"],
        "_data": p["data"],  # so para os textos de ownership; chave com '_' nunca vai para o YAML
    }
    return c


def planejar(pid, nome, categoria, runtime="python", sem_remoto=False, descricao=None, maquina=None,
             raiz_repo=None, hoje=None):
    """Plano puro (sem efeito). Levanta NovoErro para entrada invalida."""
    if not isinstance(pid, str) or not contract.ID_RE.match(pid):
        raise NovoErro("id '%s' invalido: minusculas, digitos e hifen, 2 a 63 caracteres" % pid)
    if categoria not in contract.CATEGORIAS:
        raise NovoErro("categoria '%s' fora do vocabulario %s" % (categoria, "|".join(contract.CATEGORIAS)))
    if runtime not in RUNTIMES:
        raise NovoErro("runtime '%s' fora do vocabulario %s" % (runtime, "|".join(RUNTIMES)))
    if not (nome or "").strip():
        raise NovoErro("--name e obrigatorio")
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    bruto = caminho_bruto(pid, categoria)
    destino = paths.resolver(bruto, maquina)
    nuvem = _na_nuvem_sincronizada(destino)
    if nuvem:
        raise NovoErro("destino %s esta dentro de pasta sincronizada (%s): projeto novo nasce fora do Drive/OneDrive (ADR-0001/0002)" % (destino, nuvem))
    repo = nome_repo(pid, categoria)
    nome_id = _git_config_efetiva("user.name")
    assina = _git_config_efetiva("commit.gpgsign", booleano=True) == "true"
    own = _ownership_padrao(TITULAR, OWNER_GITHUB, categoria)
    # So o NOME: e-mail no registry e dado pessoal e o hook de seguranca da plataforma o barra
    # (convencao de 689be56); o ownership-check casa identidade por nome OU por e-mail.
    own["identities"] = [nome_id] if nome_id else []
    own["signing"] = "required" if assina else "recommended"
    p = {"id": pid, "nome": nome.strip(), "categoria": categoria, "runtime": runtime, "sem_remoto": bool(sem_remoto),
         "descricao": (descricao or "").strip() or "A definir no discovery (ver docs/STATE.md).",
         "local_path": bruto, "destino": destino, "repo": repo, "owner_github": OWNER_GITHUB,
         "remote": "" if sem_remoto else "https://github.com/%s/%s" % (OWNER_GITHUB, repo),
         "drive_root": "%s/%s" % (DRIVE_ROOT[categoria], pid),
         "registry_arquivo": os.path.join(registry.pasta(raiz_repo), pid + ".yaml"),
         "data": hoje or datetime.date.today().isoformat(), "assinatura_configurada": assina, "ownership": own}
    p["contrato"] = _contrato(p)
    return p


def _params(p):
    return {k: p[k] for k in ("id", "nome", "categoria", "runtime", "sem_remoto")}


def _contrato_para_registry(contrato):
    """O contrato que vai para o YAML + a lista de erros de validacao (schema com `ownership`)."""
    c = {k: v for k, v in contrato.items() if not k.startswith("_")}
    if "ownership" in contract.SCHEMA:
        return c, contract.validar(c, c["identity"]["id"] + ".yaml")
    sec = c.pop("ownership", None)
    erros = contract.validar(c, c["identity"]["id"] + ".yaml")
    if sec is not None:
        erros += _validar_ownership_local(sec)
    return c, erros


# --------------------------------------------------------------------------- conteudo do projeto

def _substituicoes(p):
    sens = p["categoria"] == "PROG"
    py = p["runtime"] == "python"
    return {
        "{{PROJECT_NAME}}": p["id"], "{{PROJECT_TITLE}}": p["nome"], "{{PROJECT_DESC}}": p["descricao"],
        "{{CATEGORY}}": CATEGORIA_TEMPLATE[p["categoria"]], "{{CLIENT}}": CLIENTE_TEMPLATE.get(p["categoria"], "pessoal"),
        "{{DATE}}": p["data"], "{{PORTE}}": "script", "{{CRITICIDADE}}": "baixa",
        "{{DADOS_SENSIVEIS}}": "true" if sens else "false", "{{COMPONENTE_LLM}}": "false",
        "{{TEM_TESTS}}": "true", "{{TEM_EVALS}}": "false", "{{TEM_INTEGRACAO}}": "false",
        "{{TEM_SECURITY}}": "true" if sens else "false",
        # ADR-0007: baixa -> nenhuma; dados sensiveis forca qa+security
        "{{REVISAO_INDEPENDENTE}}": "qa+security" if sens else "nenhuma",
        "{{PYTHON}}": "3.13" if py else "nao-usa", "{{NODE}}": "24" if p["runtime"] == "node" else "nao-usa",
        "{{REMOTO}}": p["remote"], "{{PORTFOLIO}}": "true" if p["categoria"] == "PORTFOLIO" else "false",
        "{{CRITERIO_PRONTO}}": "A definir no discovery: a frase que diz quando o problema esta resolvido",
        "{{VERIFICACAO_TESTS}}": ("suíte de fumaça do contrato em `tests/` (pytest no `.venv`); código novo em `scripts/` exige teste próprio"
                                  if py else "suíte de fumaça PowerShell em `tests/suites/`; código novo exige teste próprio"),
        "{{VERIFICACAO_EVALS}}": "não se aplica: nenhuma saída depende de julgamento de modelo (componente_llm false); reavaliar se mudar",
        "{{VERIFICACAO_SECURITY}}": ("obrigatório: categoria PROG trata dado corporativo (dados_sensiveis true); `/os:security` antes de push, release ou handoff"
                                     if sens else "`/os:security` antes de push, release ou handoff; nenhum dado sensível declarado"),
    }


def _excluido_do_template(rel, runtime):
    if runtime == "python":
        return rel == "tests/_harness.ps1" or rel.startswith("tests/suites/")
    return rel in ("tests/conftest.py", "tests/test_smoke.py", "requirements.txt")


def _textos_extras(p):
    c = p["contrato"]
    remoto = p["remote"] or "sem remoto (nasceu com `--sem-remoto`; L2 exige criar o remoto privado)"
    handoff = "\n".join([
        "# HANDOFF — %s" % p["nome"], "",
        "> Para outra pessoa, máquina ou conta assumir o projeto **sem acesso a nenhuma conversa**.", "",
        "- **Projeto:** `%s` (%s), nascido em %s por `py -3.13 -m eos new`." % (p["id"], p["categoria"], p["data"]),
        "- **Contrato canônico:** `registry/projects/%s.yaml` no Emmily AI Project OS." % p["id"],
        "- **Local:** `%s` (resolva com `py -3.13 -m eos resolve`)." % p["local_path"],
        "- **Remoto:** %s." % remoto,
        "- **Dado bruto:** Drive `EMMILY PROJECT CLOUD/%s` — nunca no Git (ADR-0015 da plataforma)." % p["drive_root"], "",
        "## Como retomar", "",
        "1. Ler `docs/STATE.md` (onde parou) e `docs/decisions/` (o que já foi decidido).",
        "2. Rodar `.\\bootstrap.ps1` para preparar a máquina.",
        "3. Rodar `.\\tests\\run-tests.ps1` e conferir `exit 0`.", "",
        "## Recuperar em outra máquina", "",
        "Na plataforma: `py -3.13 -m eos restore %s --para <diretório vazio>`." % p["id"], ""])
    adr = "\n".join([
        "# ADR-0001 — Nascimento protegido", "",
        "- **Data:** %s" % p["data"], "- **Status:** Aceita", "",
        "## Contexto", "",
        "Projeto criado por `eos new`: um projeto novo nunca nasce L0 (só local).", "",
        "## Decisão", "",
        "1. Workspace `%s`, fora de pasta sincronizada." % p["local_path"],
        "2. Git em `main` desde o primeiro commit; remoto GitHub **privado**: %s." % remoto,
        "3. Dado bruto no Drive `EMMILY PROJECT CLOUD/%s`, nunca no Git." % p["drive_root"],
        "4. Estado canônico neutro de provedor em `docs/STATE.md` e `docs/HANDOFF.md`; `CLAUDE.md` e `AGENTS.md` são adaptadores.",
        "5. Titularidade declarada em `OWNERSHIP.md`, `PROVENANCE.md` e `AUTHORS.md`.", "",
        "## Consequências", "",
        "- Alvo de portabilidade L6: falta só a certificação por restauração (`eos certify %s`)." % p["id"], ""])
    agents = "\n".join([
        "# AGENTS.md — %s" % p["nome"], "",
        "Adaptador para agentes de código (Codex e outros). O estado canônico é **neutro de provedor**:",
        "", "1. `docs/STATE.md` — onde o projeto está;", "2. `docs/HANDOFF.md` — como assumir sem a conversa;",
        "3. `docs/decisions/` — o que já foi decidido (não reabrir sem motivo técnico novo).", "",
        "`CLAUDE.md` é o adaptador equivalente para o Claude. Nenhum dos dois é fonte de verdade.", "",
        "## Regras", "",
        "- Nunca `git add` / `git commit` / `git tag` por iniciativa própria; só a pedido explícito.",
        "- Nunca `git add .` às cegas: status, diff, varredura de segredos, add seletivo.",
        "- Nunca push, reset --hard, clean, rebase ou amend sem pedido explícito.",
        "- Segredo e dado pessoal de terceiro nunca entram no Git; dado bruto vai para o Drive.",
        "- Testes: `.\\tests\\run-tests.ps1`.", ""])
    extras = {"docs/HANDOFF.md": handoff, "docs/decisions/ADR-0001-nascimento-protegido.md": adr, "AGENTS.md": agents}
    if p["runtime"] == "node":
        extras["package.json"] = json.dumps({"name": p["id"], "version": "0.1.0", "private": True,
                                             "description": p["descricao"]}, ensure_ascii=False, indent=2) + "\n"
    return extras


def _arquivos_do_template(p, template):
    """{rel: bytes} do template ja substituido, sem a trilha de teste que nao se aplica."""
    subs = _substituicoes(p)
    out = {}
    for raiz, dirs, fs in os.walk(template):
        dirs.sort()
        for f in sorted(fs):
            full = os.path.join(raiz, f)
            rel = os.path.relpath(full, template).replace("\\", "/")
            if _excluido_do_template(rel, p["runtime"]):
                continue
            with open(full, "rb") as fh:
                dados = fh.read()
            try:
                txt = dados.decode("utf-8")
            except UnicodeDecodeError:
                out[rel] = dados
                continue
            for k, v in subs.items():
                txt = txt.replace(k, v)
            if rel == "CLAUDE.md":
                # o template manda quem instancia apagar o comentario-instrucao
                txt = re.sub(r"<!--\s*\n\s*/os:new-project preenche.*?-->\s*\n", "", txt, flags=re.S)
                txt = txt.rstrip("\n") + ("\n\n## Estado canônico\n\nNeutro de provedor: `docs/STATE.md`, "
                                          "`docs/HANDOFF.md` e `docs/decisions/`. Este arquivo e o `AGENTS.md` "
                                          "são adaptadores.\n")
            out[rel] = txt.encode("utf-8")
    return out


def _escrever_se_ausente(dir_, rel, dados):
    alvo = os.path.join(dir_, *rel.split("/"))
    if os.path.exists(alvo):
        return False
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    with open(alvo, "xb") as f:
        f.write(dados)
    return True


def lista_de_arquivos(p, template=TEMPLATE):
    rels = list(_arquivos_do_template(p, template)) + list(_textos_extras(p)) + list(_textos_ownership(p["contrato"]))
    return sorted(set(rels))


# --------------------------------------------------------------------------- diario

def dir_estado_padrao():
    return os.path.join(os.path.dirname(registry.caminho_indice()), "novo")


def _diario_path(dir_estado, pid):
    return os.path.join(dir_estado, pid + ".json")


def _ler_diario(dir_estado, pid):
    p = _diario_path(dir_estado, pid)
    if not os.path.isfile(p):
        return None
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _gravar_diario(dir_estado, d):
    os.makedirs(dir_estado, exist_ok=True)
    with open(_diario_path(dir_estado, d["plano"]["id"]), "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)


def comando_retomar(p):
    partes = ["py -3.13 -m eos new", p["id"], '--name "%s"' % p["nome"], "--category", p["categoria"],
              "--runtime", p["runtime"]]
    if p["sem_remoto"]:
        partes.append("--sem-remoto")
    return " ".join(partes)


def _agora():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --------------------------------------------------------------------------- passos

def _passo_validar(p, ctx):
    return "id, categoria e runtime validos; destino %s fora de pasta sincronizada" % p["destino"]


def _passo_workspace(p, ctx):
    os.makedirs(p["destino"], exist_ok=True)
    if not os.path.isdir(p["destino"]):
        raise PassoFalhou("diretorio %s nao existe depois de criado" % p["destino"])
    return p["destino"]


def _passo_arquivos(p, ctx):
    d = p["destino"]
    conteudo = _arquivos_do_template(p, ctx["template"])
    conteudo.update({k: v.encode("utf-8") for k, v in _textos_extras(p).items()})
    criados, preservados = [], []
    for rel in sorted(conteudo):
        (criados if _escrever_se_ausente(d, rel, conteudo[rel]) else preservados).append(rel)
    own = _arquivos_ownership(d, p["contrato"])
    criados += own["criados"]
    preservados += own["preservados"]
    esperados = set(conteudo) | set(_textos_ownership(p["contrato"]))
    faltam = sorted(r for r in esperados if not os.path.isfile(os.path.join(d, *r.split("/"))))
    if faltam:
        raise PassoFalhou("arquivo(s) ausente(s) depois da copia: %s" % ", ".join(faltam[:10]))
    restos = []
    for r in sorted(esperados):
        try:
            with open(os.path.join(d, *r.split("/")), encoding="utf-8") as f:
                if PLACEHOLDER_RE.search(f.read()):
                    restos.append(r)
        except UnicodeDecodeError:
            pass
    if restos:
        raise PassoFalhou("placeholder {{...}} restou em: %s" % ", ".join(restos))
    return "%d arquivo(s) criado(s)%s" % (len(criados), ", %d preservado(s) (ja existiam)" % len(preservados) if preservados else "")


def _assinado(d):
    obj = gitinfo.git(d, "cat-file", "commit", "HEAD")
    return "\ngpgsig " in obj.split("\n\n", 1)[0] or obj.startswith("gpgsig ")


def _passo_git(p, ctx):
    d = p["destino"]
    if not gitinfo.eh_repo(d):
        gitinfo.git(d, "init", "-q", "-b", "main")
    if not gitinfo.tem_commit(d):
        novos = [x for x in gitinfo.git(d, "ls-files", "--others", "--exclude-standard", "-z").split("\0") if x]
        # retomada: um commit que falhou DEPOIS do `add` (hook, assinatura indisponivel) deixa tudo no
        # index e nada em --others; o index entra no commit (re-adicionado: vale o conteudo atual)
        no_index = [x for x in gitinfo.git(d, "ls-files", "-z").split("\0") if x]
        novos = sorted(set(novos) | set(no_index))
        if not novos:
            raise PassoFalhou("nada para o commit inicial")
        segredos = [x for x in novos if gitinfo.nome_de_segredo(x)]
        if segredos:
            raise PassoFalhou("arquivo com nome de segredo no commit inicial: %s" % ", ".join(segredos))
        ignorados = [x for x in gitinfo.git(d, "ls-files", "--others", "--ignored", "--exclude-standard", "-z").split("\0") if x]
        if ignorados:
            raise PassoFalhou("arquivo gerado e IGNORADO pelo Git (ficaria so nesta pasta): %s" % ", ".join(ignorados[:10]))
        gitinfo.git(d, "add", "--", *novos)
        msg = ("chore: nascimento protegido do projeto %s\n\n"
               "Gerado por `py -3.13 -m eos new` (template project-standard, contrato, ownership e adapters)." % p["id"])
        gitinfo.git(d, "commit", "-q", "-m", msg)
    if not gitinfo.tem_commit(d):
        raise PassoFalhou("o commit inicial nao existe")
    rc, br = gitinfo.git(d, "symbolic-ref", "-q", "--short", "HEAD", check=False)
    if br.strip() != "main":
        raise PassoFalhou("branch atual '%s', esperado main" % br.strip())
    sujo = gitinfo.git(d, "status", "--porcelain", "--untracked-files=all")
    if sujo.strip():
        raise PassoFalhou("arvore suja depois do commit inicial: %s" % sujo.strip()[:300])
    pede = _git_config_efetiva("commit.gpgsign", repo=d, booleano=True) == "true"
    assinado = _assinado(d)
    if pede and not assinado:
        raise PassoFalhou("commit.gpgsign=true e o commit inicial NAO tem assinatura")
    ctx["assinado"] = assinado
    head = gitinfo.git(d, "rev-parse", "HEAD").strip()
    return "HEAD %s em main, %s" % (head[:8], "ASSINADO" if assinado else "sem assinatura (commit.gpgsign desligado na config efetiva)")


def _passo_contrato(p, ctx):
    c, erros = _contrato_para_registry(p["contrato"])
    if erros:
        raise PassoFalhou("contrato gerado invalido: %s" % "; ".join(erros))
    alvo = p["registry_arquivo"]
    texto = "\n".join([
        "# Contrato gerado por `eos new` em %s (nascimento protegido, docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md secao 5)." % p["data"],
        "# Intencao, nao estado medido."
        + ("" if "ownership" in c else " Secao ownership: pendente da integracao do schema (arquivos OWNERSHIP/PROVENANCE no projeto)."),
        yamlite.dumps(c), ""])
    if yamlite.loads(texto) != c:
        raise PassoFalhou("o YAML gerado nao relê igual ao contrato (yamlite)")
    if os.path.exists(alvo):
        if yamlite.load_file(alvo) != c:
            raise PassoFalhou("%s ja existe e DIVERGE do contrato planejado: nao sobrescrevo; confira a mao" % alvo)
        return "%s ja existia, igual ao planejado" % alvo
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    with open(alvo, "x", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    if contract.validar(yamlite.load_file(alvo), os.path.basename(alvo)):
        raise PassoFalhou("contrato gravado nao valida")
    return "%s (validado%s)" % (alvo, "" if "ownership" in c else "; ownership validada a parte")


def _repo_existe(deps, alvo):
    rc, out, err = deps.gh(["repo", "view", alvo, "--json", "visibility"])
    if rc == 0:
        return json.loads(out or "{}").get("visibility")
    if "could not resolve to a repository" in (err or "").lower():
        return None
    raise RemotoPendente("gh repo view %s falhou (rc %d): %s" % (alvo, rc, (err or out).strip()[:300]))


def _passo_remoto(p, ctx):
    if p["sem_remoto"]:
        return "pulado: --sem-remoto (contrato declara remote '' e o projeto fica em L1 ate ter remoto privado)"
    d, deps = p["destino"], ctx["deps"]
    alvo = "%s/%s" % (p["owner_github"], p["repo"])
    # varredura ANTES de criar o repo e de qualquer push - inclusive na retomada depois de H2, quando o
    # push leva tambem os commits que a titular fez desde o nascimento
    rc, relatorio, saida = deps.scan(d, p["id"])
    if rc == 1:
        raise PassoFalhou("varredura de seguranca acusou achado ALTA/MEDIA em %s: nada criado nem enviado; "
                          "relatorio %s" % (d, relatorio))
    if rc != 0:
        raise PassoFalhou("varredura de seguranca nao concluiu (rc %d): nada criado nem enviado; relatorio %s; %s"
                          % (rc, relatorio, (saida or "").strip()[:200]))
    vis = _repo_existe(deps, alvo)
    criado = False
    if vis is None:
        rc, out, err = deps.gh(["repo", "create", alvo, "--private", "--description", p["nome"]])
        if rc != 0:
            raise RemotoPendente("gh repo create %s --private falhou (rc %d): %s" % (alvo, rc, (err or out).strip()[:300]))
        criado = True
        vis = _repo_existe(deps, alvo)
    if vis != "PRIVATE":
        raise PassoFalhou("visibilidade de %s e %s, nao PRIVATE: nada foi enviado (ADR-0003)" % (alvo, vis))
    remotos = gitinfo.remotos_completos(d)
    if "origin" not in remotos:
        gitinfo.git(d, "remote", "add", "origin", p["remote"])
    else:
        urls = {u.rstrip("/").removesuffix(".git").lower() for u in remotos["origin"]["fetch"] + remotos["origin"]["push"]}
        if urls != {p["remote"].lower()}:
            raise PassoFalhou("origin ja existe apontando para %s, o contrato declara %s" % (sorted(urls), p["remote"]))
    rc, out, err = deps.git_rede(d, "push", "-u", "origin", "main")
    if rc != 0:
        raise RemotoPendente("git push -u origin main falhou (rc %d): %s" % (rc, (err or out).strip()[:300]))
    rc, out, err = deps.git_rede(d, "ls-remote", "origin", "refs/heads/main")
    head = gitinfo.git(d, "rev-parse", "HEAD").strip()
    if rc != 0 or out.split("\t")[0].strip() != head:
        raise RemotoPendente("ls-remote nao confirma main=%s no remoto (rc %d): %s" % (head[:8], rc, (out or err).strip()[:200]))
    return "%s %s, PRIVATE, main=%s publicada (varredura limpa: %s)" % (
        alvo, "criado" if criado else "ja existia", head[:8], relatorio)


def _passo_drive(p, ctx):
    store = ctx["deps"].store(ctx["maquina"])
    if not store.existe(p["drive_root"]):
        store.mkdir(p["drive_root"])
    if not store.existe(p["drive_root"]):
        raise PassoFalhou("raiz do Drive %s nao existe depois do mkdir (%s)" % (p["drive_root"], store.descricao()))
    return "%s em %s" % (p["drive_root"], store.descricao())


def _passo_backup(p, ctx):
    store = ctx["deps"].store(ctx["maquina"])
    c, _ = _contrato_para_registry(p["contrato"])
    m = bk.ultimo_manifesto(store, p["id"])
    atuais = gitinfo.refs_do_projeto(gitinfo.refs(p["destino"]))
    if not (m and not m.get("incompleto") and gitinfo.refs_do_projeto(m.get("refs") or {}) == atuais):
        m = bk.backup(c, store, ctx["maquina"], staging=ctx.get("staging"), log=ctx["log"])
    if m.get("incompleto"):
        raise PassoFalhou("primeiro backup INCOMPLETO: %s" % "; ".join(m.get("pendencias") or []))
    r = portability.verificar(c, store, ctx["maquina"], rede=ctx["deps"].rede)
    ctx["verificacao"] = r
    if r.get("nivel") in (None, "L0"):
        raise PassoFalhou("o projeto ficou em %s depois do nascimento: %s" % (r.get("nivel"), "; ".join(r.get("bloqueios") or [])))
    return "backup %s; nivel atingido %s" % (m["timestamp"], r["nivel"])


FUNCOES = {"validar": _passo_validar, "workspace": _passo_workspace, "arquivos": _passo_arquivos, "git": _passo_git,
           "contrato": _passo_contrato, "remoto": _passo_remoto, "drive": _passo_drive, "backup": _passo_backup}


# --------------------------------------------------------------------------- orquestracao

def _recusar_se_existe(p, raiz_repo):
    if os.path.exists(p["registry_arquivo"]):
        raise NovoErro("'%s' ja existe no registry (%s) e nao ha diario de nascimento nesta maquina: nada criado"
                       % (p["id"], p["registry_arquivo"]))
    itens, _ = registry.carregar(raiz_repo, estrito=False)
    for oid, c in itens.items():
        if (c.get("workspace") or {}).get("local_path", "").lower() == p["local_path"].lower():
            raise NovoErro("o caminho %s ja e do projeto '%s' no registry" % (p["local_path"], oid))
        if p["remote"] and (c.get("git") or {}).get("remote", "").rstrip("/").removesuffix(".git").lower() == p["remote"].lower():
            raise NovoErro("o remoto %s ja e do projeto '%s' no registry" % (p["remote"], oid))
    if not _diretorio_vazio(p["destino"]):
        raise NovoErro("diretorio %s existe e NAO esta vazio: nada criado, nada sobrescrito" % p["destino"])


def nascer(pid, nome, categoria, runtime="python", sem_remoto=False, descricao=None, dry_run=False,
           maquina=None, deps=None, raiz_repo=None, template=TEMPLATE, dir_estado=None, staging=None, log=print,
           certificar=False):
    """Executa (ou planeja, com dry_run) o nascimento. Devolve o relatorio:
    {ok, estado (nasceu | nasceu_com_pendencia | parou), dry_run, plano, passos: {nome: {status, detalhe, em}},
     nivel, h2: [pendencias humanas], retomar, retomada[, certificacao]}.
    `certificar=True` roda portability.certificar no fim (restauracao isolada + smoke): e o que leva a L6.
    Levanta NovoErro para recusa (nada foi criado por esta execucao)."""
    maquina = maquina if maquina is not None else paths.carregar_maquina()
    deps = deps or Dependencias()
    dir_estado = dir_estado or dir_estado_padrao()
    novo = planejar(pid, nome, categoria, runtime, sem_remoto, descricao, maquina, raiz_repo)
    diario = _ler_diario(dir_estado, pid)
    if diario:
        if diario.get("concluido"):
            raise NovoErro("'%s' ja nasceu em %s (diario %s): nada a fazer" % (pid, diario.get("concluido_em"), _diario_path(dir_estado, pid)))
        if _params(diario["plano"]) != _params(novo):
            raise NovoErro("retomada com parametros diferentes do nascimento pendente: diario %s, pedido %s"
                           % (_params(diario["plano"]), _params(novo)))
        if os.path.normcase(diario["plano"]["destino"]) != os.path.normcase(novo["destino"]):
            raise NovoErro("o destino mudou desde o inicio (%s -> %s): confira ${AI_WORKSPACE}" % (diario["plano"]["destino"], novo["destino"]))
        p = diario["plano"]
    else:
        _recusar_se_existe(novo, raiz_repo)
        p = novo
        diario = {"plano": p, "iniciado_em": _agora(), "concluido": False, "passos": {}}
    rel = {"ok": False, "estado": "planejado" if dry_run else "parou", "h2": [], "dry_run": dry_run, "plano": p,
           "passos": {}, "nivel": None,
           "retomar": comando_retomar(p), "retomada": bool(diario.get("passos"))}
    if dry_run:
        for n in PASSOS:
            st = (diario["passos"].get(n) or {}).get("status")
            rel["passos"][n] = {"status": "feito" if st == "ok" else "planejado"}
        rel["arquivos"] = lista_de_arquivos(p, template)
        rel["ok"] = True
        return rel
    ctx = {"deps": deps, "maquina": maquina, "template": template, "log": log, "staging": staging}
    h2 = []
    for n in PASSOS:
        try:
            detalhe = FUNCOES[n](p, ctx)
        except RemotoPendente as e:  # pendencia humana: registra e SEGUE (drive + backup)
            h2.append("sem remoto (H2): %s" % e)
            diario["passos"][n] = {"status": "H2", "detalhe": ("sem remoto (H2): %s" % e)[:1000], "em": _agora()}
            _gravar_diario(dir_estado, diario)
            continue
        except Exception as e:  # falha fechado: registra, para, nao apaga nada
            msg = "%s: %s" % (type(e).__name__, e) if not isinstance(e, PassoFalhou) else str(e)
            diario["passos"][n] = {"status": "FALHOU", "detalhe": msg[:1000], "em": _agora()}
            _gravar_diario(dir_estado, diario)
            rel["passos"] = dict(diario["passos"])
            for x in PASSOS[PASSOS.index(n) + 1:]:
                rel["passos"][x] = {"status": "pendente"}
            rel["estado"] = "parou"
            return rel
        diario["passos"][n] = {"status": "ok", "detalhe": detalhe, "em": _agora()}
        _gravar_diario(dir_estado, diario)
    v = ctx.get("verificacao") or {}
    nivel = v.get("nivel")
    if certificar:
        c_reg, _ = _contrato_para_registry(p["contrato"])
        cert = portability.certificar(c_reg, deps.store(maquina), maquina, log=log)
        rel["certificacao"] = {"ok": cert.get("ok"), "nivel_depois": cert.get("nivel_depois"), "erro": cert.get("erro"),
                               "verificacoes": cert.get("verificacoes", [])}
        nivel = cert.get("nivel_depois") or nivel
    # com H2 o nascimento NAO esta concluido: o mesmo comando, depois, tenta o remoto de novo
    diario.update(concluido=not h2, nivel=nivel, assinado=ctx.get("assinado"), h2=h2)
    if not h2:
        diario["concluido_em"] = _agora()
    _gravar_diario(dir_estado, diario)
    rel.update(ok=True, passos=dict(diario["passos"]), nivel=nivel, verificacao=v, assinado=ctx.get("assinado"),
               h2=h2, estado="nasceu_com_pendencia" if h2 else "nasceu")
    return rel


# --------------------------------------------------------------------------- CLI

def _opcao(args, nome):
    if nome not in args:
        return None
    i = args.index(nome)
    if i + 1 >= len(args) or args[i + 1].startswith("--"):
        raise NovoErro("%s exige um valor" % nome)
    return args[i + 1]


def imprimir(rel, out=print):
    p = rel["plano"]
    out("%s %s" % ("PLANO (dry-run, nada sera criado):" if rel["dry_run"] else "NASCIMENTO PROTEGIDO:", p["id"]))
    out("  nome:       %s" % p["nome"])
    out("  categoria:  %s    runtime: %s" % (p["categoria"], p["runtime"]))
    out("  workspace:  %s  ->  %s" % (p["local_path"], p["destino"]))
    out("  contrato:   %s" % p["registry_arquivo"])
    out("  remoto:     %s" % (p["remote"] + " (--private)" if p["remote"] else "nenhum (--sem-remoto)"))
    out("  drive:      %s" % p["drive_root"])
    out("  assinatura: %s" % ("commit.gpgsign ligado: commit inicial sai assinado" if p["assinatura_configurada"]
                              else "commit.gpgsign desligado na config efetiva: commit inicial sem assinatura"))
    for n in PASSOS:
        s = rel["passos"].get(n) or {}
        out("  [%-9s] %-9s %s" % (s.get("status", "-"), n, s.get("detalhe", "")))
    if rel["dry_run"]:
        out("  arquivos (%d): %s" % (len(rel.get("arquivos", [])), ", ".join(rel.get("arquivos", []))))
        return
    if rel["ok"]:
        v = rel.get("verificacao") or {}
        out("NASCEU em %s. Nivel atingido: %s%s" % (p["destino"], rel["nivel"],
                                                     " (proximo: %s)" % v.get("proximo_nivel") if v.get("proximo_nivel") else ""))
        for b in v.get("bloqueios") or []:
            out("    falta: " + b)
        for x in rel.get("h2") or []:
            out("  PENDENCIA HUMANA " + x)
        if rel.get("h2"):
            out("  Resolvida a pendencia, rode o MESMO comando: ele tenta so o que falta. %s" % rel["retomar"])
        cert = rel.get("certificacao")
        if cert:
            out("  Certificacao %s; nivel agora %s%s" % ("APROVADA" if cert["ok"] else "REPROVADA", cert["nivel_depois"],
                                                      " (%s)" % cert["erro"] if cert.get("erro") else ""))
        elif rel["nivel"] != "L6":
            out("  L6 exige certificacao por restauracao: py -3.13 -m eos certify %s (ou eos new ... --certificar)" % p["id"])
        out("  LEMBRETE: o contrato %s foi gravado na plataforma e NAO foi commitado (regra de ouro: so a pedido)."
            % p["registry_arquivo"])
    else:
        out("PAROU no primeiro passo que falhou. Nada foi apagado.")
        out("  Para retomar do passo pendente (mesmos parametros): %s" % rel["retomar"])


def cli(args, maquina=None, sem_rede=False, deps=None, out=print, **kw):
    """`eos new` a partir de argv (sem o nome do comando).
    0 nasceu (ou plano do --dry-run); 1 nasceu com pendencia (H2 do remoto, certificacao reprovada);
    2 recusado ou parou num passo (erro de execucao)."""
    try:
        if not args or args[0].startswith("--"):
            raise NovoErro('uso: new <id> --name "<nome>" --category <CAT> [--runtime python|node|none] [--sem-remoto] [--sem-rede] [--dry-run] [--certificar]')
        conhecidas = {"--name", "--category", "--runtime", "--descricao", "--sem-remoto", "--dry-run", "--certificar"}
        desconhecidas = [a for a in args[1:] if a.startswith("--") and a not in conhecidas]
        if desconhecidas:
            raise NovoErro("opcao desconhecida: %s" % ", ".join(desconhecidas))
        nome, cat = _opcao(args, "--name"), _opcao(args, "--category")
        if not nome or not cat:
            raise NovoErro("--name e --category sao obrigatorios")
        sem_remoto = "--sem-remoto" in args
        if sem_rede and not sem_remoto:
            out("--sem-rede implica --sem-remoto: nenhuma chamada ao gh nem push (o projeto fica em L1 ate ter remoto)")
            sem_remoto = True
        deps = deps or Dependencias(rede=not sem_rede)
        rel = nascer(args[0], nome, cat.upper(), runtime=_opcao(args, "--runtime") or "python",
                     sem_remoto=sem_remoto, descricao=_opcao(args, "--descricao"),
                     dry_run="--dry-run" in args, certificar="--certificar" in args, maquina=maquina, deps=deps, **kw)
    except NovoErro as e:
        out("RECUSADO: %s" % e)
        return 2
    imprimir(rel, out)
    if not rel["ok"]:
        return 2
    if rel.get("h2") or (rel.get("certificacao") and not rel["certificacao"]["ok"]):
        return 1
    return 0
