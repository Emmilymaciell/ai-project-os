"""Guardas estruturais do motor: o que tem de ser verdade sobre o CODIGO, nao sobre o comportamento.

Por AST, e com UMA funcao de analise (`analisar`) que os testes chamam tanto sobre o codigo real
quanto sobre amostras plantadas - a r2 mostrou que um auto-teste que reimplementa a extracao fica
verde com o guarda quebrado.

O QUE o guarda cobre, e o que NAO cobre (declarado, para o nome nao prometer mais):
  cobre   - literal destrutivo de git/rclone em argumento POSICIONAL (direto ou dentro da lista
            de argv), por funcao, com permissao explicita por contexto;
          - chamadas de remocao/renomeacao (os.remove/unlink/rmdir/removedirs/rename/replace/
            truncate, shutil.rmtree/move, Path.unlink/rmdir/rename/replace) so nas funcoes da
            lista PERMITIDO;
          - import que esconderia essas chamadas: `from os import remove`, `import shutil as x`;
          - forma colada (`--force-with-lease=main`) e refspec forcada (`+main`) em push;
          - (r10) refspec de delecao (`:main`, `:refs/...`), prefixo de long option destrutiva
            (`--mirr`, `--dele`, `--forc`: o Git aceita abreviacao unica) e, em push, flags
            curtas combinadas com f/d (`-fu`);
          - (r10) gh por `shutil.which("gh")`, por variavel que o guarda e por argv montado numa
            lista antes de executar;
          - gh (deps.gh([...]) ou argv que comeca pelo executavel do gh) como LISTA DE PERMISSAO:
            so os subcomandos de GH_PERMITIDO, nas funcoes listadas; delete/edit/--public/
            --visibility nao privada acusados em qualquer lugar; repo create exige --private.
          - (r11) `shell=` diferente do literal False, os.system/os.popen e subprocess.getoutput/
            getstatusoutput (e o import direto deles) em QUALQUER lugar do motor; em push,
            `--no-verify` (e abreviacoes) e `-n`;
          - (r12, Sec4) alias de `subprocess`/`asyncio` (`import subprocess as sp`) e
            `from subprocess|asyncio import ...` (esconderiam o executor do guarda);
            asyncio.create_subprocess_shell/create_subprocess_exec, os.spawn*, os.posix_spawn*,
            os.exec* e os.startfile em QUALQUER lugar (o motor nao usa nenhum: grep na r12); e o
            literal `core.hooksPath` em qualquer argv executado (desligaria os hooks do push);
          - (r13, S3) `core.hooksPath` em QUALQUER literal str do motor (sem distincao de caixa) e
            `GIT_CONFIG*` como literal (chave de dict de ambiente) ou nome de argumento
            (`dict(os.environ, GIT_CONFIG_COUNT=...)`); o motor nao usa nenhum dos dois (grep r13);
  nao cobre - `shell` passado por **kwargs, argumento montado em variavel/`*args`/f-string, e ESCRITA de arquivo (open 'w',
            copyfile): o motor escreve o tempo todo em staging, store e destino isolado;
          - (r13, S3/QA-a) config do git por AMBIENTE montada sem literal (GIT_CONFIG_COUNT/
            GIT_CONFIG_KEY_n/GIT_CONFIG_VALUE_n ou GIT_CONFIG_PARAMETERS vindos de variavel,
            concatenacao ou do ambiente herdado do processo pai) - inclusive core.hooksPath assim;
          - import/chamada dinamica: importlib.import_module, __import__, getattr(os, "system"),
            eval/exec de texto;
          - execucao por FFI: ctypes (CreateProcessW etc.) e _winapi.CreateProcess (o motor usa
            ctypes so em paths.nome_curto, para GetShortPathNameW; grep r13);
          - executores fora de subprocess/os/asyncio.create_subprocess_*: loop.subprocess_exec/
            loop.subprocess_shell do asyncio, pty.spawn e multiprocessing (Process/Pool, que podem
            rodar qualquer coisa no filho).
            O guarda e rede de seguranca contra ESCORREGAO no codigo do motor, nao contencao de
            codigo hostil: quem escreve o motor e revisado por diff.
"""
import ast
import os
import sys
import unittest

RAIZ = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

PROIBIDOS = {"--hard", "clean", "--force", "-f", "rebase", "--amend", "push", "reset", "prune", "--prune",
             "gc", "rm", "update-ref", "-d", "-D", "--delete", "remove", "restore", "checkout",
             "sync", "delete", "deletefile", "purge", "moveto", "move", "rmdir", "rmdirs", "cleanup", "dedupe",
             "--force-with-lease", "--force-if-includes", "--mirror"}
# Excecao por (arquivo, funcao, literal): cada uma com o porque.
PERMITIDO_ARG = {
    ("restore.py", "restaurar", "checkout"),  # dentro do destino isolado recem-clonado
    # fetch forcado do bundle para o clone isolado recem-criado (nada local a sobrescrever)
    ("restore.py", "restaurar", "+refs/heads/*:refs/heads/*"),
    ("restore.py", "restaurar", "+refs/tags/*:refs/tags/*"),
    # refs/preservado/* so existe no bundle (nunca vai ao remoto): r10, QA-A1
    ("restore.py", "restaurar", "+refs/preservado/*:refs/preservado/*"),
    ("novo.py", "_passo_remoto", "push"),     # `git push -u origin main` do nascimento: repo recem-criado,
                                              # sem --force; remoto privado conferido ANTES (eos new)
    ("ownership.py", "_remover_tag", "-d"),   # `git tag -d` so da tag criada NESTA execucao, conferida
                                              # por sha antes (ownership-certify --tag, Q9 da revisao r8)
}
REMOCAO_MOD = {("os", "remove"), ("os", "unlink"), ("os", "rmdir"), ("os", "removedirs"), ("os", "rename"),
               ("os", "replace"), ("os", "truncate"), ("shutil", "rmtree"), ("shutil", "move")}
REMOCAO_METODO = {"unlink", "rmdir", "rename", "replace"}  # Path.<metodo>(...)
PERMITIDO = {
    ("gitinfo.py", "remover_arvore"),   # so arvores criadas pelo motor (temp, staging)
    ("restore.py", "restaurar"),        # dentro do destino isolado, caminho validado por _caminho_seguro
    ("cloud.py", "put"),                # os.replace do .part para o nome final, dentro do store
    ("cloud.py", "escrever_texto"),     # idem
    ("registry.py", "rebuild_index"),   # indice SQLite DERIVADO (.tmp -> .db)
}
MODULOS_SENSIVEIS = {"os", "shutil", "pathlib", "subprocess", "asyncio"}  # alias proibido (r12 Sec4)
# r11 Sec6: chamadas que passam o comando por um shell (proibidas em QUALQUER lugar do motor)
SHELL_IMPORT = {"os": {"system", "popen"}, "subprocess": {"getoutput", "getstatusoutput"}}
EXECUTORES = {"git", "run", "_run", "Popen", "check_output", "check_call", "call", "git_rede", "gh"}
# r12 Sec4: executores que o motor nao usa e que o guarda acima nao enxergaria (proibidos em
# QUALQUER lugar; prefixo para as familias spawn*/exec*/posix_spawn*)
EXEC_PROIBIDO = {"create_subprocess_shell", "create_subprocess_exec", "startfile"}
EXEC_PROIBIDO_OS = ("spawn", "exec", "posix_spawn")
SEM_FROM_IMPORT = {"subprocess", "asyncio"}  # `from subprocess import run as r` esconde o executor


def _exec_proibido(mod, nome):
    return nome in EXEC_PROIBIDO or (mod == "os" and nome.startswith(EXEC_PROIBIDO_OS))

# gh e LISTA DE PERMISSAO, nao de proibicao: so os subcomandos abaixo, so nestas funcoes.
GH_PERMITIDO = {
    ("novo.py", "_repo_existe", ("repo", "view")),            # visibilidade antes de criar/enviar
    ("novo.py", "_passo_remoto", ("repo", "create")),         # so com --private (conferido abaixo)
    ("portability.py", "_visibilidade_github", ("repo", "view")),
}
GH_REPASSE = {("novo.py", "_gh_padrao")}  # o gh real da Dependencias: repassa o argv montado acima
GH_PROIBIDOS = {"delete", "edit", "archive", "rename", "transfer", "--public", "--internal"}


# O Git aceita qualquer prefixo UNICO de long option: `--mirr` e `--mirror`, `--forc` e `--force`
# (r10, S-A3). Prefixo de 2+ letras de uma destas e destrutivo.
LONGAS_DESTRUTIVAS = tuple(x for x in PROIBIDOS if x.startswith("--")) + ("--delete", "--mirror")


def _destrutivo(x, em_push=False):
    """Literal proibido, com valor colado (`--force-with-lease=main`), refspec forcada (`+main`),
    refspec de delecao (`:main`, `:refs/...`; nao o pathspec `:(literal)`), abreviacao de long
    option destrutiva (`--mirr`) e, em push, flags curtas combinadas com f ou d (`-fu`)."""
    nome = x.split("=", 1)[0]
    if x in PROIBIDOS or nome in PROIBIDOS or x.startswith("+"):
        return True
    if x.startswith(":") and not x.startswith(":(") and len(x) > 1:
        return True
    if nome.startswith("--") and len(nome) >= 4 and any(l.startswith(nome) for l in LONGAS_DESTRUTIVAS):
        return True
    if em_push and (x == "-n" or (nome.startswith("--no-v") and "--no-verify".startswith(nome))):
        return True  # r11 Sec6: push sem os hooks (--no-verify, inclusive abreviado) e -n
    return em_push and len(x) > 2 and x[0] == "-" and x[1] != "-" and x[1:].isalpha() and \
        any(c in x[1:] for c in "fdDn")


NOMES_GH = {"gh"}  # nomes de variavel que guardam o executavel do gh (completado por arquivo)


def _menciona_gh(no):
    """A expressao produz o executavel do gh? literal 'gh'/'gh.exe', _caminho_gh(), which('gh')."""
    for x in ast.walk(no):
        if isinstance(x, ast.Constant) and isinstance(x.value, str) and \
                os.path.basename(x.value.replace("\\", "/")).lower() in ("gh", "gh.exe"):
            return True
        if isinstance(x, ast.Call) and isinstance(x.func, ast.Name) and x.func.id == "_caminho_gh":
            return True
    return False


def _eh_gh(e, nomes=None):
    """O primeiro elemento de um argv e o executavel do gh? (variavel que guarda o gh, literal,
    _caminho_gh(), shutil.which('gh'))."""
    if isinstance(e, ast.Name):
        return e.id in (nomes or NOMES_GH)
    if isinstance(e, ast.Constant) and isinstance(e.value, str):
        return os.path.basename(e.value.replace("\\", "/")).lower() in ("gh", "gh.exe")
    return isinstance(e, ast.Call) and _menciona_gh(e)


def _argv_gh(n, nome_f, nomes=None):
    """(eh_chamada_gh, literais do argv do gh sem o executavel, tem_argumento_nao_literal)."""
    if nome_f == "gh":
        elems = [x for a in n.args for x in (a.elts if isinstance(a, (ast.List, ast.Tuple)) else [a])]
    elif nome_f in EXECUTORES and n.args and isinstance(n.args[0], (ast.List, ast.Tuple)) \
            and n.args[0].elts and _eh_gh(n.args[0].elts[0], nomes):
        elems = n.args[0].elts[1:]
    elif isinstance(n, (ast.List, ast.Tuple)) and n.elts and _eh_gh(n.elts[0], nomes):
        elems = n.elts[1:]  # argv do gh montado numa variavel e executado depois (r10, S-A3)
    else:
        return False, [], False
    lits = [e.value for e in elems if isinstance(e, ast.Constant) and isinstance(e.value, str)]
    return True, lits, len(lits) != len(elems)


def _problemas_gh(nome, func, lits, opaco):
    if (nome, func) in GH_REPASSE and not lits:
        return []
    if opaco and not lits:
        return ["gh com argv nao literal em %s(): o guarda nao ve o subcomando" % func]
    out = ["gh '%s' proibido em %s()" % (x, func) for x in lits if x in GH_PROIBIDOS]
    for i, x in enumerate(lits):
        if x == "--visibility=public" or (x == "--visibility" and lits[i + 1:i + 2] != ["private"]):
            out.append("gh --visibility nao privada em %s()" % func)
    sub = tuple(lits[:2])
    if (nome, func, sub) not in GH_PERMITIDO:
        out.append("gh '%s' fora da lista de permissao em %s()" % (" ".join(sub), func))
    if sub == ("repo", "create") and "--private" not in lits:
        out.append("gh repo create sem --private em %s()" % func)
    return out


def _funcoes(arv):
    pai = {}
    for f in ast.walk(arv):
        if isinstance(f, (ast.FunctionDef, ast.AsyncFunctionDef)):
            for n in ast.walk(f):
                pai.setdefault(n, f.name)
    return pai


def analisar(fonte, nome):
    """Devolve (problemas, estatisticas) para o fonte de UM arquivo."""
    arv = ast.parse(fonte)
    pai = _funcoes(arv)
    problemas, est = [], {"literais": 0, "remocoes": 0, "gh": 0}
    # variaveis que guardam o executavel do gh (`exe = shutil.which("gh") or ...`)
    nomes_gh = set(NOMES_GH)
    for n in ast.walk(arv):
        if isinstance(n, (ast.Assign, ast.AnnAssign, ast.NamedExpr)) and n.value is not None \
                and not isinstance(n.value, (ast.List, ast.Tuple)) and _menciona_gh(n.value):
            alvos = n.targets if isinstance(n, ast.Assign) else [n.target]
            nomes_gh |= {t.id for t in alvos if isinstance(t, ast.Name)}
    # listas que sao argv de gh FORA de uma chamada executora (montadas em variavel)
    ja_vistas = set()
    for n in ast.walk(arv):
        if isinstance(n, ast.Call) and n.args and isinstance(n.args[0], (ast.List, ast.Tuple)):
            ja_vistas.add(id(n.args[0]))
    for n in ast.walk(arv):
        if isinstance(n, (ast.List, ast.Tuple)) and id(n) not in ja_vistas:
            eh, lits_gh, opaco = _argv_gh(n, "", nomes_gh)
            if eh:
                est["gh"] += 1
                problemas += ["%s:%d %s" % (nome, n.lineno, x) for x in _problemas_gh(nome, pai.get(n), lits_gh, opaco)]
    for n in ast.walk(arv):
        if isinstance(n, ast.ImportFrom) and n.module and n.module.split(".")[0] in MODULOS_SENSIVEIS:
            nomes = {a.name for a in n.names}
            if nomes & ({f for _, f in REMOCAO_MOD} | REMOCAO_METODO | {"*"}):
                problemas.append("%s:%d import direto de funcao destrutiva: %s" % (nome, n.lineno, sorted(nomes)))
        if isinstance(n, ast.Import):
            for a in n.names:
                if a.name.split(".")[0] in MODULOS_SENSIVEIS and a.asname:
                    problemas.append("%s:%d alias de modulo sensivel: %s as %s" % (nome, n.lineno, a.name, a.asname))
        if isinstance(n, ast.ImportFrom) and n.module in SHELL_IMPORT and \
                {a.name for a in n.names} & (SHELL_IMPORT[n.module] | {"*"}):
            problemas.append("%s:%d import direto de executor por shell: %s" % (nome, n.lineno, n.module))
        if isinstance(n, ast.ImportFrom) and n.module and n.module.split(".")[0] in SEM_FROM_IMPORT:
            problemas.append("%s:%d from %s import: use o modulo (o guarda ve subprocess.run)" % (nome, n.lineno, n.module))
        if isinstance(n, ast.ImportFrom) and n.module == "os" and \
                any(_exec_proibido("os", a.name) for a in n.names):
            problemas.append("%s:%d import direto de executor de os: %s" % (nome, n.lineno, sorted(a.name for a in n.names)))
        # r13 (S3): core.hooksPath em QUALQUER literal (nao so em argv executado) e GIT_CONFIG_*
        # como literal ou nome de argumento (dict de ambiente: {"GIT_CONFIG_COUNT": ...} ou
        # dict(os.environ, GIT_CONFIG_PARAMETERS=...)): o motor nao usa nenhum (grep na r13)
        if isinstance(n, ast.Constant) and isinstance(n.value, str):
            if "core.hookspath" in n.value.lower():
                problemas.append("%s:%d literal core.hooksPath" % (nome, n.lineno))
            if n.value.upper().startswith("GIT_CONFIG"):
                problemas.append("%s:%d literal de ambiente %s (config do git por ambiente)" % (nome, n.lineno, n.value))
        if isinstance(n, ast.keyword) and n.arg and n.arg.upper().startswith("GIT_CONFIG"):
            problemas.append("%s:%d argumento de ambiente %s= (config do git por ambiente)" % (nome, n.lineno, n.arg))
        if not isinstance(n, ast.Call):
            continue
        func = pai.get(n)
        # r11 Sec6: shell em QUALQUER lugar do motor. `shell=` so passa com o literal False
        for kw in n.keywords:
            if kw.arg == "shell" and not (isinstance(kw.value, ast.Constant) and kw.value.value is False):
                problemas.append("%s:%d shell=%s em %s()" % (nome, n.lineno, ast.unparse(kw.value), func))
        if isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name) and \
                n.func.attr in SHELL_IMPORT.get(n.func.value.id, ()):
            problemas.append("%s:%d %s.%s em %s()" % (nome, n.lineno, n.func.value.id, n.func.attr, func))
        # r12 Sec4: asyncio.create_subprocess_*, os.spawn*/exec*/posix_spawn*, os.startfile
        if isinstance(n.func, ast.Attribute) and _exec_proibido(
                n.func.value.id if isinstance(n.func.value, ast.Name) else "", n.func.attr):
            problemas.append("%s:%d executor proibido %s em %s()" % (nome, n.lineno, ast.unparse(n.func), func))
        lits = []
        for a in n.args:
            elems = a.elts if isinstance(a, (ast.List, ast.Tuple)) else [a]
            lits += [e.value for e in elems if isinstance(e, ast.Constant) and isinstance(e.value, str)]
        est["literais"] += len(lits)
        f = n.func
        nome_f = f.id if isinstance(f, ast.Name) else (f.attr if isinstance(f, ast.Attribute) else "")
        if nome_f == "git" and "stash" in lits and lits[lits.index("stash") + 1:lits.index("stash") + 2] != ["list"]:
            problemas.append("%s:%d stash que nao e 'stash list'" % (nome, n.lineno))
        # so chamadas que EXECUTAM comando: 'restore' num c.get("restore") e chave de dict
        em_push = "push" in lits
        if nome_f in EXECUTORES and any("core.hookspath" in x.lower() for x in lits):
            problemas.append("%s:%d core.hooksPath em argv executado em %s()" % (nome, n.lineno, func))
        for x in (lits if nome_f in EXECUTORES else []):
            if _destrutivo(x, em_push) and (nome, func, x) not in PERMITIDO_ARG:
                problemas.append("%s:%d argumento destrutivo '%s' em %s()" % (nome, n.lineno, x, func))
        eh_gh, lits_gh, opaco = _argv_gh(n, nome_f, nomes_gh)
        if eh_gh:
            est["gh"] += 1
            problemas += ["%s:%d %s" % (nome, n.lineno, x) for x in _problemas_gh(nome, func, lits_gh, opaco)]
        if isinstance(f, ast.Attribute):
            alvo = (f.value.id, f.attr) if isinstance(f.value, ast.Name) else None
            # Path.replace(alvo)/rename(alvo) tem 1 argumento; str.replace(a, b) tem 2+ (aridade, nao nome)
            metodo = f.attr in REMOCAO_METODO and alvo not in REMOCAO_MOD and (
                f.attr in ("unlink", "rmdir") or len(n.args) == 1)
            remocao = alvo in REMOCAO_MOD or metodo
            if remocao:
                est["remocoes"] += 1
                if (nome, func) not in PERMITIDO:
                    problemas.append("%s:%d remocao/renomeacao %s em %s()" % (nome, n.lineno, ast.unparse(f), func))
    return problemas, est


def _arquivos(incluir_testes=False):
    for r, _, fs in os.walk(RAIZ):
        for f in fs:
            if f.endswith(".py") and (incluir_testes or not f.startswith("test_")):
                yield os.path.join(r, f)


def _ler(p):
    with open(p, encoding="utf-8") as fh:
        return fh.read()


class TestGuardas(unittest.TestCase):
    def test_lista_de_arquivos_nao_vazia(self):
        self.assertGreaterEqual(len(list(_arquivos())), 8, "guarda sem objeto passaria por vacuidade")

    def test_so_stdlib(self):
        ruins = []
        for p in _arquivos(incluir_testes=True):
            for n in ast.walk(ast.parse(_ler(p))):
                if isinstance(n, ast.Import):
                    mods = [a.name for a in n.names]
                elif isinstance(n, ast.ImportFrom) and n.level == 0 and n.module:
                    mods = [n.module]
                else:
                    continue
                for m in mods:
                    topo = m.split(".")[0]
                    if topo not in sys.stdlib_module_names and topo != "eos":
                        ruins.append("%s: %s" % (os.path.basename(p), m))
        self.assertEqual(ruins, [], "o motor precisa rodar antes de qualquer pip (ADR-0014)")

    def test_codigo_real_passa_no_guarda_e_o_guarda_ve_o_codigo(self):
        todos, lit, rem, gh = [], 0, 0, 0
        for p in _arquivos():
            pr, est = analisar(_ler(p), os.path.basename(p))
            todos += pr
            lit += est["literais"]
            rem += est["remocoes"]
            gh += est["gh"]
        self.assertGreater(lit, 50, "o guarda nao ve os argumentos: passaria por vacuidade")
        self.assertGreater(rem, 0, "o guarda nao ve nenhuma remocao: padrao quebrado")
        # _repo_existe, _passo_remoto, _gh_padrao (novo.py) e _visibilidade_github (portability.py)
        self.assertGreaterEqual(gh, 4, "o guarda nao ve as chamadas ao gh: a lista de permissao passaria por vacuidade")
        self.assertEqual(todos, [])

    def test_amostras_plantadas_sao_acusadas_pela_funcao_real(self):
        amostras = {
            "reset --hard": "def f(r):\n    git(r, 'reset', '--hard')\n",
            "checkout fora do restore": "def backup(r):\n    gitinfo.git(r, 'checkout', '--', '.')\n",
            "rclone sync em argv": "def f():\n    subprocess.run(['rclone', 'sync', a, b])\n",
            "stash push": "def f(r):\n    git(r, 'stash', 'push')\n",
            "worktree remove": "def f(r):\n    git(r, 'worktree', 'remove', w)\n",
            "os.remove fora da lista": "import os\ndef apagar(p):\n    os.remove(p)\n",
            "os.rename fora da lista": "import os\ndef f(p):\n    os.rename(p, q)\n",
            "Path.unlink": "def f(p):\n    p.unlink()\n",
            "from os import remove": "from os import remove\n",
            "alias de shutil": "import shutil as sh\n",
            "push pelo git de rede fora do nascimento": "def f(d, deps):\n    deps.git_rede(d, 'push', 'origin')\n",
        }
        for nome, fonte in amostras.items():
            pr, _ = analisar(fonte, "amostra.py")
            self.assertTrue(pr, "o guarda NAO acusou a amostra plantada: %s" % nome)

    def test_push_destrutivo_no_contexto_permitido_e_acusado(self):
        # r8 S3/Q8: a permissao do push do nascimento nao libera nenhuma forma de sobrescrever/apagar
        rp = "def _passo_remoto(p, c):\n    deps.git_rede(d, %s)\n"
        amostras = {
            "--force-with-lease": "'push', '--force-with-lease', 'origin', 'main'",
            "--force-with-lease=ref": "'push', '--force-with-lease=main', 'origin', 'main'",
            "--force-if-includes": "'push', '--force-if-includes', 'origin', 'main'",
            "--mirror": "'push', '--mirror', 'origin'",
            "--delete": "'push', '--delete', 'origin', 'main'",
            "-d": "'push', '-d', 'origin', 'main'",
            "refspec +": "'push', 'origin', '+main'",
            "refspec + completo": "'push', 'origin', '+refs/heads/main:refs/heads/main'",
        }
        for nome, args in amostras.items():
            pr, _ = analisar(rp % args, "novo.py")
            self.assertTrue(pr, "o guarda NAO acusou push destrutivo: %s" % nome)
        pr, _ = analisar(rp % "'push', '-u', 'origin', 'main'", "novo.py")
        self.assertEqual(pr, [], "o push do nascimento (sem forca) deveria passar")

    def test_gh_so_com_as_chamadas_liberadas(self):
        positivas = {
            "repo delete": ("novo.py", "_passo_remoto", "deps.gh(['repo', 'delete', a, '--yes'])"),
            "repo edit --visibility public": ("novo.py", "_passo_remoto", "deps.gh(['repo', 'edit', a, '--visibility', 'public'])"),
            "repo edit --visibility=public": ("novo.py", "_passo_remoto", "deps.gh(['repo', 'edit', a, '--visibility=public'])"),
            "repo create --public": ("novo.py", "_passo_remoto", "deps.gh(['repo', 'create', a, '--public'])"),
            "repo create --visibility public": ("novo.py", "_passo_remoto", "deps.gh(['repo', 'create', a, '--private', '--visibility', 'public'])"),
            "repo create sem --private": ("novo.py", "_passo_remoto", "deps.gh(['repo', 'create', a])"),
            "repo create fora do passo": ("novo.py", "_repo_existe", "deps.gh(['repo', 'create', a, '--private'])"),
            "repo view em outro arquivo": ("backup.py", "_repo_existe", "deps.gh(['repo', 'view', a])"),
            "api fora da lista": ("novo.py", "_repo_existe", "deps.gh(['api', '-X', 'PATCH', u])"),
            "gh sem literal": ("novo.py", "_passo_remoto", "deps.gh(args)"),
            "gh por subprocess": ("novo.py", "_passo_remoto", "subprocess.run([gh, 'repo', 'delete', a])"),
            "gh por literal": ("novo.py", "_passo_remoto", "subprocess.run(['gh', 'repo', 'edit', a, '--public'])"),
            "gh por _caminho_gh": ("novo.py", "_passo_remoto", "subprocess.run([_caminho_gh(), 'repo', 'archive', a])"),
        }
        for nome, (arq, func, chamada) in positivas.items():
            pr, _ = analisar("def %s(deps, a):\n    %s\n" % (func, chamada), arq)
            self.assertTrue(pr, "o guarda NAO acusou gh: %s" % nome)
        negativas = {
            "repo view do nascimento": ("novo.py", "_repo_existe", "deps.gh(['repo', 'view', a, '--json', 'visibility'])"),
            "repo create --private do nascimento": ("novo.py", "_passo_remoto", "deps.gh(['repo', 'create', a, '--private', '--description', n])"),
            "repasse do gh real": ("novo.py", "_gh_padrao", "subprocess.run([_caminho_gh(), *args], capture_output=True)"),
            "visibilidade da portability": ("portability.py", "_visibilidade_github", "subprocess.run([gh, 'repo', 'view', a, '--json', 'isPrivate'])"),
        }
        for nome, (arq, func, chamada) in negativas.items():
            pr, _ = analisar("def %s(deps, a):\n    %s\n" % (func, chamada), arq)
            self.assertEqual(pr, [], "o guarda acusou chamada gh liberada: %s" % nome)

    def test_permissao_por_contexto_nao_vaza(self):
        pr, _ = analisar("def restaurar(d):\n    git(d, 'checkout', '-q', '-B', b, h)\n", "restore.py")
        self.assertEqual(pr, [], "checkout no restore isolado deveria ser permitido")
        pr, _ = analisar("def restaurar(d):\n    git(d, 'checkout', '-q', '-B', b, h)\n", "backup.py")
        self.assertTrue(pr, "a permissao do restore vazou para outro arquivo")
        pr, _ = analisar("def _passo_remoto(p, c):\n    deps.git_rede(d, 'push', '--force')\n", "novo.py")
        self.assertTrue(pr, "a permissao do push do nascimento liberou --force")
        pr, _ = analisar("def backup(d):\n    git(d, 'fetch', b, '+refs/heads/*:refs/heads/*')\n", "backup.py")
        self.assertTrue(pr, "a permissao do fetch forcado do restore vazou para outro arquivo")
        pr, _ = analisar("def _remover_tag(raiz, nome):\n    gitinfo.git(raiz, 'tag', '-d', nome)\n", "ownership.py")
        self.assertEqual(pr, [], "a remocao da tag criada nesta execucao deveria ser permitida")
        pr, _ = analisar("def certificar(raiz, nome):\n    gitinfo.git(raiz, 'tag', '-d', nome)\n", "ownership.py")
        self.assertTrue(pr, "a permissao do tag -d vazou para outra funcao do ownership")
        pr, _ = analisar("def _remover_tag(raiz, nome):\n    gitinfo.git(raiz, 'tag', '-d', nome)\n", "backup.py")
        self.assertTrue(pr, "a permissao do tag -d vazou para outro arquivo")

    def test_r10_delecao_flags_combinadas_abreviacoes_e_gh_indireto(self):
        # r10 S-A3: formas que o guarda anterior deixava passar
        rp = "def _passo_remoto(p, c):\n    deps.git_rede(d, %s)\n"
        positivas_push = {
            "refspec de delecao :main": "'push', 'origin', ':main'",
            "refspec de delecao :refs/...": "'push', 'origin', ':refs/heads/x'",
            "flags combinadas -fu": "'push', '-fu', 'origin', 'main'",
            "flags combinadas -uf": "'push', '-uf', 'origin', 'main'",
            "flags combinadas -du": "'push', '-du', 'origin', 'main'",
            "abreviacao --mirr": "'push', '--mirr', 'origin'",
            "abreviacao --dele": "'push', '--dele', 'origin', 'main'",
            "abreviacao --forc": "'push', '--forc', 'origin', 'main'",
            "abreviacao --force-w": "'push', '--force-w', 'origin', 'main'",
        }
        for nome, args in positivas_push.items():
            pr, _ = analisar(rp % args, "novo.py")
            self.assertTrue(pr, "o guarda NAO acusou: %s" % nome)
        positivas_gh = {
            "shutil.which em variavel": "exe = shutil.which('gh')\n    subprocess.run([exe, 'repo', 'edit', a, '--visibility', 'public'])",
            "shutil.which direto": "subprocess.run([shutil.which('gh'), 'repo', 'edit', a])",
            "argv do gh em variavel": "cmd = [gh, 'repo', 'delete', a]\n    subprocess.run(cmd)",
            "argv com which em variavel": "exe = shutil.which('gh') or 'x'\n    argv = [exe, 'api', '-X', 'PATCH', u]\n    subprocess.run(argv)",
            "repo edit mesmo privado": "deps.gh(['repo', 'edit', a, '--visibility', 'private'])",
        }
        for nome, corpo in positivas_gh.items():
            pr, _ = analisar("def _passo_remoto(deps, a):\n    %s\n" % corpo, "novo.py")
            self.assertTrue(pr, "o guarda NAO acusou gh: %s" % nome)
        negativas = {
            "push -u do nascimento": ("novo.py", "_passo_remoto", "deps.git_rede(d, 'push', '-u', 'origin', 'main')"),
            "checkout --detach no restore": ("restore.py", "restaurar", "git(d, 'checkout', '-q', '--detach', h)"),
            "gh view por which na portability": ("portability.py", "_visibilidade_github",
                                                 "gh = shutil.which('gh') or 'gh.exe'\n    subprocess.run([gh, 'repo', 'view', a, '--json', 'isPrivate'])"),
            "pathspec :(literal) nao e delecao": ("restore.py", "restaurar", "git(d, 'add', '--', ':(literal)x')"),
        }
        for nome, (arq, func, corpo) in negativas.items():
            pr, _ = analisar("def %s(deps, a):\n    %s\n" % (func, corpo), arq)
            self.assertEqual(pr, [], "o guarda acusou chamada legitima: %s" % nome)

    def test_r11_shell_e_push_sem_hooks(self):
        # r11 Sec6: shell e push sem hooks, em qualquer arquivo e funcao do motor
        positivas = {
            "shell=True": "subprocess.run(['git', 'status'], shell=True)",
            "shell=variavel": "subprocess.run(argv, shell=usar)",
            "shell=1": "subprocess.Popen(c, shell=1)",
            "os.system": "os.system('git status')",
            "os.popen": "os.popen('dir').read()",
            "subprocess.getoutput": "subprocess.getoutput('git log')",
            "push --no-verify": "gitinfo.git(d, 'push', '--no-verify', 'origin', 'main')",
            "push --no-verify abreviado": "gitinfo.git(d, 'push', '--no-ver', 'origin', 'main')",
            "push -n": "deps.git_rede(d, 'push', '-n', 'origin', 'main')",
            "push -un": "deps.git_rede(d, 'push', '-un', 'origin', 'main')",
        }
        for nome, corpo in positivas.items():
            pr, _ = analisar("def f(d, deps):\n    %s\n" % corpo, "backup.py")
            self.assertTrue(pr, "o guarda NAO acusou: %s" % nome)
        for nome, fonte in {"from os import system": "from os import system\n",
                            "from os import popen": "from os import popen as p\n",
                            "from subprocess import getoutput": "from subprocess import getoutput\n"}.items():
            self.assertTrue(analisar(fonte, "x.py")[0], "o guarda NAO acusou: %s" % nome)
        negativas = {
            "shell=False": "subprocess.run(['git', 'status'], shell=False)",
            "sem shell": "subprocess.run(['git', 'status'], capture_output=True)",
            "push -u do nascimento": "deps.git_rede(d, 'push', '-u', 'origin', 'main')",
            "-n fora de push": "gitinfo.git(d, 'log', '-n', '1')",
        }
        pr, _ = analisar("def _passo_remoto(d, deps):\n    %s\n" % negativas.pop("push -u do nascimento"), "novo.py")
        self.assertEqual(pr, [], "o push do nascimento deveria passar")
        for nome, corpo in negativas.items():
            pr, _ = analisar("def f(d, deps):\n    %s\n" % corpo, "backup.py")
            self.assertEqual(pr, [], "o guarda acusou chamada legitima: %s" % nome)

    def test_r12_alias_asyncio_spawn_exec_e_hookspath(self):
        # r12 Sec4: formas que o guarda da r11 nao via
        positivas = {
            "import subprocess as sp": "import subprocess as sp\n",
            "import asyncio as aio": "import asyncio as aio\n",
            "from subprocess import run": "from subprocess import run\n",
            "from subprocess import Popen as P": "from subprocess import Popen as P\n",
            "from asyncio import create_subprocess_shell": "from asyncio import create_subprocess_shell\n",
            "from os import spawnv": "from os import spawnv\n",
            "from os import execvp": "from os import execvp\n",
            "asyncio.create_subprocess_shell": "async def f(c):\n    await asyncio.create_subprocess_shell(c)\n",
            "asyncio.create_subprocess_exec": "async def f(c):\n    await asyncio.create_subprocess_exec('git', 'push')\n",
            "os.spawnv": "def f(c):\n    os.spawnv(os.P_WAIT, 'git', ['git', 'push'])\n",
            "os.spawnlp": "def f(c):\n    os.spawnlp(os.P_WAIT, 'git', 'git')\n",
            "os.posix_spawn": "def f(c):\n    os.posix_spawn('git', ['git'], {})\n",
            "os.execv": "def f(c):\n    os.execv('git', ['git', 'push'])\n",
            "os.execlp": "def f(c):\n    os.execlp('git', 'git')\n",
            "os.startfile": "def f(c):\n    os.startfile(c)\n",
            "push -c core.hooksPath=": "def f(d):\n    gitinfo.git(d, '-c', 'core.hooksPath=/dev/null', 'push', 'origin', 'main')\n",
            "push do nascimento com hookspath": "def _passo_remoto(d, deps):\n    deps.git_rede(d, '-c', 'core.hookspath=x', 'push', '-u', 'origin', 'main')\n",
            "config core.hooksPath": "def f(d):\n    gitinfo.git(d, 'config', 'core.hooksPath', 'x')\n",
        }
        for nome, fonte in positivas.items():
            arq = "novo.py" if "_passo_remoto" in fonte else "backup.py"
            self.assertTrue(analisar(fonte, arq)[0], "o guarda NAO acusou: %s" % nome)
        negativas = {
            "import subprocess": "import subprocess\n",
            "subprocess.run sem shell": "def f():\n    subprocess.run(['git', 'status'], capture_output=True)\n",
            "os.path.exists nao e exec": "def f(p):\n    os.path.exists(p)\n",
            "push -u do nascimento": "def _passo_remoto(d, deps):\n    deps.git_rede(d, 'push', '-u', 'origin', 'main')\n",
        }
        for nome, fonte in negativas.items():
            arq = "novo.py" if "_passo_remoto" in fonte else "backup.py"
            self.assertEqual(analisar(fonte, arq)[0], [], "o guarda acusou forma legitima: %s" % nome)


if __name__ == "__main__":
    unittest.main()
