"""Guarda de git destrutivo para agentes (hooks/guarda_git.py, hook PreToolUse do plugin os).

Origem: incidente da revisao r13 - um subagente rodou `git checkout -- tests/suites/scanner.ps1`
para desfazer as proprias edicoes, comando proibido pelo CLAUDE.md. A regra era so texto; o hook
a torna mecanica. Estes casos provam os dois lados: o que tem de BLOQUEAR (inclusive o caso real)
e o que tem de LIBERAR - guarda que barra `git status` ensina a desligar o guarda.

O hook mora fora de eos/ (na raiz do plugin), por isso e carregado por caminho, nao por import.
O que ele NAO cobre esta declarado no docstring do proprio hooks/guarda_git.py.
"""
import base64
import importlib.util
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOOK = os.path.join(RAIZ, "hooks", "guarda_git.py")
HOOKS_JSON = os.path.join(RAIZ, "hooks", "hooks.json")

_spec = importlib.util.spec_from_file_location("guarda_git", HOOK)
guarda_git = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guarda_git)
avaliar = guarda_git.avaliar


def _enc(texto):
    return base64.b64encode(texto.encode("utf-16-le")).decode("ascii")


ENC_RESET = _enc("git reset --hard")
ENC_STATUS = _enc("git status")

BLOQUEADOS = [
    # o caso real da r13
    "git checkout -- tests/suites/scanner.ps1",
    "git checkout .",
    "git checkout HEAD -- docs/STATE.md",
    "git checkout -f main",
    "git checkout --force main",
    "git checkout main --pathspec-from-file=x.txt",
    "git switch --discard-changes main",
    "git switch -f main",
    "git restore tests/suites/scanner.ps1",
    "git restore .",
    "git restore --staged --worktree x.ps1",
    "git restore -SW x.ps1",
    "git restore --source=HEAD~1 x.ps1",
    "git reset --hard",
    "git reset --hard HEAD~1",
    "git reset --hard HEAD@{1}",
    "git reset --merge",
    "git reset --keep HEAD~1",
    "git reset --har",
    "git clean -f",
    "git clean -fd",
    "git clean -xdf",
    "git clean --force -d",
    "git push --force",
    "git push -f origin main",
    "git push -fu origin main",
    "git push --force-with-lease origin main",
    "git push --force-with-lease=main origin main",
    "git push --forc origin main",
    "git push origin +main",
    "git push origin :old-branch",
    "git push origin --delete old-branch",
    "git push -d origin old-branch",
    "git push --mirror backup",
    "git push --prune origin",
    "git rebase main",
    "git rebase --continue",
    "git commit --amend",
    "git commit --amend --no-edit",
    "git commit -a --amen -m x",
    "git stash drop",
    "git stash drop stash@{0}",
    "git stash clear",
    "git branch -D feature",
    "git branch --delete --force feature",
    "git branch -df feature",
    "git worktree remove --force .claude/worktrees/x",
    "git worktree remove -f .claude/worktrees/x",
    "git worktree prune",
    "git update-ref -d refs/heads/x",
    "git reflog expire --expire=now --all",
    "git gc --prune=now",
    "git filter-branch --tree-filter 'rm x' HEAD",
    "git filter-repo --path segredo.txt --invert-paths",
    "git config core.hooksPath /dev/null",
    "git config --unset core.hooksPath",
    "git config --local core.hookspath x",
    "git -c core.hooksPath=/dev/null commit -m x",
    # formas de invocacao
    "git -C C:/repo checkout -- a.txt",
    'git -C "C:\\Program Files\\x" reset --hard',
    "git -c user.name=x -c user.email=y reset --hard",
    "git.exe reset --hard",
    "GIT.EXE reset --hard",
    '"C:\\Program Files\\Git\\cmd\\git.exe" checkout -- a.txt',
    "/usr/bin/git reset --hard",
    "& git reset --hard",
    "& 'git.exe' clean -fd",
    "env GIT_TRACE=1 git reset --hard",
    "GIT_DIR=.git git reset --hard",
    # composicao com separadores
    "cd /c/repo && git checkout -- x.ps1",
    "git status; git reset --hard",
    "git diff || git restore .",
    "git status | git clean -f",
    "git status\ngit reset --hard",
    "git status\r\ngit reset --hard",
    "Set-Location C:\\repo; git checkout -- x.ps1",
    "echo $(git reset --hard)",
    "(git reset --hard)",
    "if ($?) { git checkout -- x }",
    "git reset `\n --hard",
    "git reset \\\n --hard",
    # dentro de outro shell
    'bash -c "git checkout -- x.ps1"',
    "powershell -NoProfile -Command git reset --hard",
    'powershell -NoProfile -Command "git clean -fd"',
    "cmd /c git reset --hard",
    "pwsh -c 'git push --force'",
    # r14: opcoes de shell que recebem VALOR nao podem parar a leitura (achado QA)
    "powershell -NoProfile -ExecutionPolicy Bypass -Command git checkout -- x.ps1",
    "powershell.exe -NoProfile -ep Bypass -WindowStyle Hidden -Command git reset --hard",
    "pwsh -NoLogo -ExecutionPolicy Bypass -Command git clean -fd",
    "powershell -Version 5.1 -NonInteractive -c git rebase main",
    "powershell -ExecutionPolicy:Bypass -Command git reset --hard",
    "bash -o pipefail -c git reset --hard",
    "bash -O extglob -lc 'git checkout -- x'",
    "sh -e -c 'git clean -xdf'",
    "cmd /d /s /c git push -f",
    # r14: -EncodedCommand e decodificado (UTF-16LE, base64)
    "powershell -NoProfile -EncodedCommand " + ENC_RESET,
    "powershell -enc " + ENC_RESET,
    # r14: substituicao DENTRO de aspas duplas e avaliada
    'echo "$(git reset --hard)"',
    'Write-Host "x $(git checkout -- a.txt) y"',
    'echo "`git clean -fd`"',
    # r14: heredoc ENTREGUE a shell tem o corpo avaliado
    "bash <<'EOF'\ngit status\ngit reset --hard\nEOF",
    "sh <<EOF\ngit checkout -- x\nEOF",
    # r14: abreviacao de 1-2 letras
    "git reset --ha",
    "git reset --k",
    "git clean --f",
    "git push --m backup",
    "git commit --am",
    # r14: comandos novos
    "git pull --rebase",
    "git pull -r origin main",
    "git pull --rebase=interactive",
    "git tag -d v1.0",
    "git tag -f v1.0",
    "git tag --delete v1.0",
    "git branch -f main HEAD~3",
    "git branch -M main",
    "git branch -C a b",
    "git rm -f x.ps1",
    "git rm --force x.ps1",
    # r14: core.hooksPath por outras vias
    "git --config-env core.hooksPath=X commit -m x",
    "git --config-env=core.hooksPath=X commit -m x",
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null git commit -m x",
    "export GIT_CONFIG_KEY_0=core.hooksPath",
    "$env:GIT_CONFIG_KEY_0 = 'core.hooksPath'",
    "git config set core.hooksPath x",
    # r15: movem branch existente (como branch -f)
    "git checkout -B main",
    "git checkout -B main origin/main",
    "git switch -C main",
    "git switch --force-create main",
    # r15: valor colado por ':' no PowerShell e -EncodedCommand colado
    "powershell -ExecutionPolicy:Bypass -EncodedCommand " + ENC_RESET,
    "powershell -ExecutionPolicy:Bypass -Command:git reset --hard",
    "powershell -EncodedCommand:" + ENC_RESET,
    # r15: flags combinadas do bash com `o` consomem o valor
    'bash -euo pipefail -c "git reset --hard"',
    "bash -eo pipefail -c 'git checkout -- x'",
    # r15: regras que nao tinham caso
    "git push --force-if-includes origin main",
    "git gc --prune=all",
    "git reflog delete HEAD@{1}",
    "git update-ref --delete refs/heads/x",
    "git -ccore.hooksPath=x commit -m x",
    "git config --replace-all core.hooksPath x",
    "git config --add core.hooksPath x",
    "GIT_CONFIG_PARAMETERS=\"'core.hooksPath'='/dev/null'\" git commit -m x",
    "cmd <<EOF\ngit reset --hard\nEOF",
    # r15: o valor tirado de _curtas nao pode esconder a flag real
    "git rm -rf dir",
    "git branch --sort -refname -D x",
    "git pull -Xtheirs --rebase",
    # r16: -t de branch e --gpg-sign/--squash NAO consomem o token seguinte (argumento opcional so colado)
    "git branch -t -f main origin/main",
    "git pull --gpg-sign -r",
    "git pull --squash -r",
    # r16: pre-filtro de -EncodedCommand com aspas, -- e payload UTF-16 impar
    "pwsh '-EncodedCommand' " + ENC_RESET,
    "pwsh --EncodedCommand " + ENC_RESET,
    "powershell -EncodedCommand " + base64.b64encode("git reset --hard; ".encode("utf-16-le") + b"x").decode("ascii"),
]

# dialeto definido pela ferramenta: o mesmo texto e lido como a ferramenta o executaria
BLOQUEADOS_BASH = [
    r"echo don\'t; git reset --hard",          # \ escapa fora de aspas em bash
    r'echo "a \" b"; git reset --hard',          # \" nao fecha a aspa em bash
    "git reset \\\n--hard",                      # continuacao de linha do bash
]
BLOQUEADOS_PS = [
    "Set-Location C:\\repo\\\ngit reset --hard",  # \ no fim da linha NAO e continuacao no PowerShell
    'Set-Location "C:\\repo\\"; git reset --hard',  # \ e literal: a aspa fecha
    "git reset `\n--hard",                       # continuacao de linha do PowerShell
]

LIBERADOS = [
    "git status",
    "git status --short",
    "git diff",
    "git diff HEAD -- docs/STATE.md",
    "git log --oneline -5",
    "git log --format=%H -- x.ps1",
    "git add hooks/guarda_git.py",
    "git add -- a.txt",
    "git commit -m 'feat: x'",
    "git commit -F msg.txt",
    "git commit -a -m x",
    "git worktree remove .claude/worktrees/x",
    "git worktree list",
    "git worktree add ../x -b nova",
    "git branch -d feature",
    "git branch --delete feature",
    "git branch nova",
    "git restore --staged x.ps1",
    "git restore -S x.ps1",
    "git checkout -b nova",
    "git checkout main",
    "git switch -c nova",
    "git switch main",
    "git fetch origin",
    "git push",
    "git push origin main",
    "git push -u origin main",
    "git push origin HEAD:refs/heads/x",
    "git clean -n",
    "git clean -nd",
    "git clean --dry-run -fd",
    "git stash list",
    "git stash push -u -m tag",
    "git stash apply abc123",
    "git reset",
    "git reset HEAD x.ps1",
    "git reset --soft HEAD~1",
    "git config --get core.hooksPath",
    "git config core.autocrlf",
    "git config get core.hooksPath",
    "git gc",
    "git reflog",
    "git rev-parse --verify --quiet 'HEAD^{commit}'",
    "git ls-files --others --exclude-standard",
    "py -3.13 -m unittest discover -s eos/tests -t .",
    "powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1 -Suite plugin",
    "ls -la",
    "",
    # o comando aparece so como TEXTO (mensagem, grep, eco), nao como comando
    "git commit -m 'fix: nunca rodar git checkout -- x; git reset --hard'",
    'git commit -m "docs: proibir git reset --hard e git clean -fd"',
    "grep -rn 'git checkout --' docs/",
    'echo "git push --force"',
    "Write-Host 'git rebase main'",
    "git commit -F - <<'EOF'\nfix: x\n\ngit reset --hard foi o problema\nEOF",
    "git commit -m @'\nfix: x\ngit checkout -- y\n'@",
    "github-cli status",
    "legit reset --hard",
    # r14
    "git config core.hooksPath",
    "git config --show-origin --get core.hooksPath",
    "git pull",
    "git pull --rebase=false",
    "git pull --no-rebase",
    "git tag v1.0",
    "git tag -a v1.0 -m x",
    "git tag -l",
    "git branch -m velho novo",
    "git rm --cached x.ps1",
    "git rm x.ps1",
    "powershell -NoProfile -ExecutionPolicy Bypass -Command git status",
    "powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-tests.ps1 -Suite plugin",
    "bash -o pipefail -c 'git log --oneline'",
    "powershell -NoProfile -EncodedCommand " + ENC_STATUS,
    'echo "$(git status)"',
    "cat <<'EOF' > msg.txt\ngit reset --hard\nEOF",
    "py -3.13 - <<'PY'\nprint('git reset --hard')\nPY",
    "git log --grep 'reset --hard'",
    # r15: falsos positivos de _curtas (valor de opcao nao e flag)
    "git tag -l --sort -v:refname",
    "git branch --sort -refname",
    "git pull -Xtheirs",
    "git pull -X theirs origin main",
    "git rm -rf --cached dir",
    "git commit -m -fix",
    "git checkout -b fd",
    "git switch -c nova-f",
    "git push -o ci.skip origin main",
    # r15: forma de commit do Claude Code (heredoc dentro de $() em aspas duplas)
    "git commit -m \"$(cat <<'EOF'\nfix: guarda\n\nnao rode git checkout -- x nem git reset --hard\n"
    "Co-Authored-By: Claude <noreply@anthropic.com>\nEOF\n)\"",
    "git commit -m \"$(cat <<'EOF'\nit's (parenteses) e aspa ' solta; git clean -fd\nEOF\n)\"",
]

LIBERADOS_BASH = [
    r'git commit -m "a \"git reset --hard\" b"',
    "git commit -m 'nao rode git checkout -- x'",
    r'echo "texto \$(git reset --hard)"',       # \$ escapado: texto, nao substituicao
]
LIBERADOS_PS = [
    "git commit -m 'don''t git reset --hard'",
    'git commit -m "a `"git reset --hard`" b"',
]


class TestAvaliar(unittest.TestCase):
    def test_listas_nao_vazias(self):
        self.assertGreaterEqual(len(BLOQUEADOS), 50, "guarda sem objeto passaria por vacuidade")
        self.assertGreaterEqual(len(LIBERADOS), 30)

    def test_caso_real_r13_bloqueado_com_mensagem_util(self):
        m = avaliar("git checkout -- tests/suites/scanner.ps1")
        self.assertIsNotNone(m)
        self.assertIn("checkout", m)
        self.assertIn("edite o arquivo de volta", m)
        self.assertIn("! git", m)
        self.assertIn("titular", m)

    def test_bloqueados(self):
        falhas = [c for c in BLOQUEADOS if avaliar(c) is None]
        self.assertEqual(falhas, [], "deveriam ser bloqueados")

    def test_liberados(self):
        falhas = [(c, avaliar(c)) for c in LIBERADOS if avaliar(c) is not None]
        self.assertEqual(falhas, [], "deveriam ser liberados")

    def test_dialeto_bash(self):
        self.assertEqual([c for c in BLOQUEADOS_BASH if avaliar(c, "Bash") is None], [])
        self.assertEqual([c for c in LIBERADOS_BASH if avaliar(c, "Bash") is not None], [])

    def test_dialeto_powershell(self):
        self.assertEqual([c for c in BLOQUEADOS_PS if avaliar(c, "PowerShell") is None], [])
        self.assertEqual([c for c in LIBERADOS_PS if avaliar(c, "PowerShell") is not None], [])

    def test_sem_ferramenta_avalia_nos_dois_dialetos(self):
        for c in BLOQUEADOS_BASH + BLOQUEADOS_PS:
            self.assertIsNotNone(avaliar(c), c)

    def test_formato_exato_do_achado_qa_r14(self):
        m = avaliar("powershell -NoProfile -ExecutionPolicy Bypass -Command git checkout -- x.ps1", "PowerShell")
        self.assertIsNotNone(m)
        self.assertIn("checkout", m)

    def test_entrada_nao_texto_libera(self):
        self.assertIsNone(avaliar(None))
        self.assertIsNone(avaliar(123))

    def test_mensagem_por_categoria(self):
        self.assertIn("commit novo", avaliar("git rebase main"))
        self.assertIn("titular", avaliar("git push --force"))
        self.assertIn("hooks", avaliar("git config core.hooksPath x"))


class TestHooksJson(unittest.TestCase):
    def test_hooks_json_valido_e_aponta_para_o_guarda(self):
        with open(HOOKS_JSON, encoding="utf-8") as fh:
            cfg = json.load(fh)
        entradas = cfg["hooks"]["PreToolUse"]
        alvo = [e for e in entradas if set(e["matcher"].split("|")) >= {"Bash", "PowerShell"}]
        self.assertEqual(len(alvo), 1)
        cmds = [h["command"] for h in alvo[0]["hooks"] if h["type"] == "command"]
        self.assertEqual(len(cmds), 1)
        self.assertIn("${CLAUDE_PLUGIN_ROOT}/hooks/guarda_git.py", cmds[0])
        self.assertTrue(os.path.isfile(HOOK))


class TestMainPontaAPonta(unittest.TestCase):
    def _rodar(self, evento, cru=None):
        dados = cru if cru is not None else json.dumps(evento).encode("utf-8")
        return subprocess.run([sys.executable, HOOK], input=dados, capture_output=True, timeout=30)

    def test_bloqueia_com_saida_2_e_motivo_no_stderr(self):
        r = self._rodar({"tool_name": "Bash", "hook_event_name": "PreToolUse",
                         "tool_input": {"command": "git checkout -- tests/suites/scanner.ps1"}})
        self.assertEqual(r.returncode, 2, r.stderr)
        self.assertIn(b"BLOQUEADO", r.stderr)
        self.assertIn(b"edite o arquivo de volta", r.stderr)

    def test_powershell_tambem(self):
        r = self._rodar({"tool_name": "PowerShell", "tool_input": {"command": "git reset --hard; git status"}})
        self.assertEqual(r.returncode, 2, r.stderr)

    def test_libera_com_saida_0(self):
        r = self._rodar({"tool_name": "Bash", "tool_input": {"command": "git status && git diff"}})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stderr, b"")

    def test_outra_ferramenta_nao_e_avaliada(self):
        r = self._rodar({"tool_name": "Write", "tool_input": {"command": "git reset --hard"}})
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_entrada_invalida_nao_bloqueia(self):
        # falha do guarda e saida 0, nunca 2 (sem Git Bash o Claude Code bloquearia qualquer saida != 0/2)
        r = self._rodar(None, cru=b"{nao e json")
        self.assertEqual(r.returncode, 0)
        self.assertIn(b"NAO avaliado", r.stderr)

    def test_entrada_vazia_libera(self):
        r = self._rodar(None, cru=b"")
        self.assertEqual(r.returncode, 0, r.stderr)


class TestComandoExatoDoHooksJson(unittest.TestCase):
    """Executa o `command` do hooks.json como o Claude Code executaria (argv por shlex, que le as
    aspas como o bash), so substituindo `${CLAUDE_PLUGIN_ROOT}`. Se `py` nao existir na maquina,
    `py -3.13` vira sys.executable - o resto do comando fica identico."""

    def _argv(self, raiz):
        with open(HOOKS_JSON, encoding="utf-8") as fh:
            cmd = json.load(fh)["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        if raiz is not None:
            cmd = cmd.replace("${CLAUDE_PLUGIN_ROOT}", raiz)
        cmd = cmd.replace("; exit $LASTEXITCODE", "")  # sufixo do PowerShell; aqui o argv roda direto
        argv = shlex.split(cmd)
        self.assertEqual(argv[:2], ["py", "-3.13"])
        if shutil.which("py") is None:
            argv = [sys.executable] + argv[2:]
        return argv

    def _rodar(self, raiz, comando, ferramenta="Bash", env_raiz=None, cwd=None):
        dados = json.dumps({"tool_name": ferramenta, "tool_input": {"command": comando}}).encode("utf-8")
        env = dict(os.environ)
        env.pop("CLAUDE_PLUGIN_ROOT", None)  # o ambiente do processo que roda a suite nao pode decidir o teste
        if env_raiz:
            env["CLAUDE_PLUGIN_ROOT"] = env_raiz
        return subprocess.run(self._argv(raiz), input=dados, capture_output=True, timeout=60, env=env, cwd=cwd)

    def test_comando_usa_modo_isolado(self):
        self.assertIn("-I", self._argv(None))

    @unittest.skipUnless(shutil.which("powershell") and shutil.which("py"), "precisa de powershell e py")
    def test_powershell_como_o_claude_code_roda(self):
        # 2026-10-16: no 0.1.2 o guarda rodava e saia 2, mas `powershell -Command` sem `exit $LASTEXITCODE`
        # devolvia 1 (nao bloqueante). O teste ao vivo do 0.1.3 mostrou o `${CLAUDE_PLUGIN_ROOT}` SUBSTITUIDO no
        # texto; o caminho pelo AMBIENTE fica como redundancia e e o que este teste exercita.
        with open(HOOKS_JSON, encoding="utf-8") as fh:
            cmd = json.load(fh)["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        def rodar(comando, env_raiz):
            env = dict(os.environ)
            env.pop("CLAUDE_PLUGIN_ROOT", None)
            if env_raiz:
                env["CLAUDE_PLUGIN_ROOT"] = env_raiz
            dados = json.dumps({"tool_name": "PowerShell", "tool_input": {"command": comando}}).encode("utf-8")
            return subprocess.run(["powershell", "-NoProfile", "-Command", cmd], input=dados,
                                  capture_output=True, timeout=120, env=env).returncode
        self.assertEqual(rodar("git checkout -- x", RAIZ), 2)
        self.assertEqual(rodar("git status", RAIZ), 0)
        self.assertEqual(rodar("git checkout -- x", None), 0)  # sem a variavel: nunca trava

    def test_arquivo_plantado_na_raiz_do_drive_nao_e_executado(self):
        # argumento sem unidade (`/hooks/guarda_git.py`, o que o PowerShell produz com a variavel vazia) resolveria
        # para a raiz do drive do cwd: o involucro nao pode executar o que estiver plantado la
        with tempfile.TemporaryDirectory() as tmp:
            os.makedirs(os.path.join(tmp, "hooks"))
            with open(os.path.join(tmp, "hooks", "guarda_git.py"), "w", encoding="utf-8") as fh:
                fh.write("import sys\nsys.exit(2)\n")  # plantado: bloquearia tudo
            sem_unidade = os.path.splitdrive(tmp)[1].replace("\\", "/")
            r = self._rodar(sem_unidade, "git status", cwd=tmp)
            self.assertEqual(r.returncode, 0, r.stderr)  # nao executou o plantado
            r = self._rodar(sem_unidade, "git status", env_raiz=RAIZ, cwd=tmp)
            self.assertEqual(r.returncode, 0, r.stderr)  # usou o guarda real (git status passa)
            r = self._rodar(sem_unidade, "git checkout -- x", env_raiz=RAIZ, cwd=tmp)
            self.assertEqual(r.returncode, 2, r.stderr)  # e o guarda real bloqueia

    def test_excecao_ao_carregar_escreve_no_stderr(self):
        argv = self._argv(RAIZ.replace("\\", "/"))
        with tempfile.TemporaryDirectory() as tmp:
            alvo = os.path.join(tmp, "alvo.py")
            with open(alvo, "w", encoding="utf-8") as fh:
                fh.write("raise RuntimeError('x')\n")
            env = dict(os.environ)
            env.pop("CLAUDE_PLUGIN_ROOT", None)
            r = subprocess.run(argv[:-1] + [alvo], input=b"", capture_output=True, timeout=60, env=env)
            self.assertEqual(r.returncode, 0)
            self.assertIn(b"NAO avaliado", r.stderr)

    def test_shell_powershell_explicito(self):
        # sem `shell`, o Claude Code no Windows sem Git Bash so aceita 0/2 como veredito (medido 2026-10-16)
        with open(HOOKS_JSON, encoding="utf-8") as fh:
            h = json.load(fh)["hooks"]["PreToolUse"][0]["hooks"][0]
        self.assertEqual(h.get("shell"), "powershell")

    def test_raiz_real_bloqueia_com_2(self):
        r = self._rodar(RAIZ.replace("\\", "/"), "git checkout -- tests/suites/scanner.ps1")
        self.assertEqual(r.returncode, 2, r.stderr)
        self.assertIn(b"BLOQUEADO", r.stderr)

    def test_raiz_real_powershell_formato_qa(self):
        r = self._rodar(RAIZ.replace("\\", "/"),
                        "powershell -NoProfile -ExecutionPolicy Bypass -Command git checkout -- x.ps1",
                        "PowerShell")
        self.assertEqual(r.returncode, 2, r.stderr)

    def test_raiz_real_libera_com_0(self):
        r = self._rodar(RAIZ.replace("\\", "/"), "git status")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_placeholder_nao_expandido_nunca_trava(self):
        # sem o involucro, o python sairia 2 ("can't open file") e bloquearia TODO comando
        r = self._rodar(None, "git checkout -- x")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_raiz_inexistente_nunca_trava(self):
        r = self._rodar(os.path.join(RAIZ, "nao-existe-xyz").replace("\\", "/"), "git reset --hard")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_involucro_propaga_exit_2_e_excecao_vira_0(self):
        # o involucro deixa o SystemExit(2) do guarda passar e uma excecao nao tratada sair 0
        argv = self._argv(RAIZ.replace("\\", "/"))
        with tempfile.TemporaryDirectory() as tmp:
            casos = {"sys.exit(2)": 2, "raise RuntimeError('x')": 0, "pass": 0}
            for corpo, esperado in casos.items():
                alvo = os.path.join(tmp, "alvo.py")
                with open(alvo, "w", encoding="utf-8") as fh:
                    fh.write("import sys\n%s\n" % corpo)
                env = dict(os.environ)
                env.pop("CLAUDE_PLUGIN_ROOT", None)  # com a variavel, o involucro rodaria o guarda real, nao o alvo
                r = subprocess.run(argv[:-1] + [alvo], input=b"", capture_output=True, timeout=60, env=env)
                self.assertEqual(r.returncode, esperado, (corpo, r.stderr))


if __name__ == "__main__":
    unittest.main()
