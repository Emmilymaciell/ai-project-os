"""Guarda de git destrutivo para agentes: hook PreToolUse do plugin `os` (Claude Code).

Por que existe: na revisao r13 um subagente implementador rodou `git checkout -- <arquivo>`
para desfazer as proprias edicoes - comando proibido pelo CLAUDE.md. Nao houve perda, mas a
regra era so texto. Este hook a torna mecanica para toda sessao/subagente que carrega o plugin.

Contrato do Claude Code: o JSON do evento chega por stdin (`tool_name`, `tool_input.command`);
saida 2 BLOQUEIA a chamada e o stderr vai para o modelo; saida 0 libera; qualquer outra saida
e erro NAO bloqueante - a chamada segue. O hooks.json chama este arquivo por um involucro
(`py -3.13 -I -c ...run_path...`) que sai 0 se o arquivo nao existir: assim um caminho nao
expandido nunca vira o `2` que o Python usa para "arquivo nao encontrado" e trava tudo.

DIALETO: o comando e lido como a ferramenta o executaria - `Bash` em regras de bash (`\\` escapa
fora de aspas, `\\`+quebra de linha continua, crase e substituicao de comando); `PowerShell` em
regras do PowerShell (crase escapa e continua linha, `\\` e literal). Sem ferramenta conhecida,
avalia nos dois e bloqueia se qualquer um bloquear.

O QUE cobre (por segmento: `;`, `&&`, `||`, `|`, `&`, quebra de linha, parenteses, chaves e, em
bash, crase separam comandos; aspas agrupam; `$(...)` e crase DENTRO de aspas duplas sao
avaliados; `git -C <dir>`, `git -c k=v`, `--git-dir`, `--config-env`, `git.exe` e caminho
completo do executavel sao tolerados; prefixos `env X=1`, `sudo`, `command`, `exec`, `&`, `.`
sao pulados; `bash/sh -c ...` (inclusive com `-o opt`), `powershell/pwsh -Command ...` (inclusive
com `-ExecutionPolicy Bypass` e demais opcoes que recebem valor), `-EncodedCommand` (decodificado)
e `cmd /c` sao avaliados por dentro; heredoc ENTREGUE a um shell (`bash <<'EOF'`) tem o corpo
avaliado, os demais heredocs e here-strings sao texto; abreviacao de opcao longa a partir de 1
letra (o git rejeita prefixo ambiguo, entao bloquear um ambiguo nao barra nada que funcionaria) e
flag curta combinada (`-fd`, `-xdf`) contam):
  checkout com `--`, `.`, `-f/--force`, `-B` ou `--pathspec-from-file`; switch com `-f/--force/
  --discard-changes/-C/--force-create`; rm `-f` (salvo `--cached`, que so mexe no indice); restore (salvo `--staged/-S` sem `--worktree/-W`); reset `--hard/
  --merge/--keep`; clean com `-f/--force` (salvo dry-run `-n`); push com `--force/-f/
  --force-with-lease/--force-if-includes/--delete/-d/--mirror/--prune`, refspec `+x` ou `:x`;
  pull `--rebase/-r` (salvo `--rebase=false`); rebase (qualquer); commit `--amend`; stash
  drop/clear; branch `-D/-M/-C/-f/--force`; tag `-d/-f`; worktree remove com
  `-f/--force`; worktree prune; update-ref `-d/--delete`; reflog expire/delete; gc
  `--prune=now|all`; filter-branch; filter-repo; config que ESCREVE core.hooksPath (ler, com ou
  sem `--get`, passa); `-c core.hooksPath=...`/`--config-env` em qualquer comando git;
  `GIT_CONFIG_*=...core.hooksPath` como prefixo, `export`/`set` ou `$env:GIT_CONFIG_*`.

O QUE NAO cobre (declarado, para o nome nao prometer mais; nao e fronteira contra codigo hostil):
  - eval, variaveis e montagem dinamica (`$g = 'git'; & $g reset --hard`, `$(echo git) ...`);
  - alias do git definido fora do comando, e `pull.rebase=true` ja configurado;
  - script .ps1/.sh/.py chamado que contenha o comando (o hook ve so a linha emitida), inclusive
    `bash script.sh` e `powershell -File x.ps1`; here-string do PowerShell entregue por pipe;
  - `git checkout <ref> <arquivo>` SEM `--` (indistinguivel de troca de branch sem consultar o
    repositorio); `xargs git ...`, `find -exec git ...`;
  - `merge/am/cherry-pick/revert --abort`, `git stash` puro e `stash pop`, `branch -m`,
    `update-ref <ref> <sha>` (move ref sem apagar), `Set-Item env:GIT_CONFIG_*`;
  - hooksPath por vias indiretas: `include.path` para arquivo que o defina, `GIT_CONFIG_GLOBAL`/
    `GIT_CONFIG_SYSTEM` apontando arquivo com hooksPath, `[Environment]::SetEnvironmentVariable`,
    edicao direta de `.git/config` (ferramentas Edit/Write ou `>>` de shell);
  - aninhamento de shells/subexpressoes alem de MAX_PROFUNDIDADE niveis;
  - valor de opcao longa separado por espaco so e reconhecido para as opcoes de VALOR_LONGO; outra
    opcao com valor que comece por `-` pode ser lida como flags curtas (falso positivo, nunca negativo);
  - `--no-verify` (deliberadamente nao combatido: docs/runbooks/hooks.md);
  - ferramentas que nao sejam Bash/PowerShell (o matcher do hooks.json so entrega essas duas).
"""
import base64
import json
import re
import sys

DICA_ARQUIVO = ("Para desfazer edicao sua, edite o arquivo de volta (Edit/Write); para tirar do "
                "indice use `git restore --staged <arquivo>`; arquivo que voce mesmo criou pode "
                "ser apagado pelo nome.")
DICA_HISTORICO = "Nao reescreva historico: faca um commit novo que corrija o anterior."
DICA_REMOTO = "Push normal so a pedido; forcar ou apagar no remoto e decisao da titular."
DICA_HOOKS = "Nao desligue os hooks: se um hook barrou, corrija a causa."
DICA_WORKTREE = "Remova sem --force (o git recusa se houver mudanca) ou deixe para a titular."
DICA_REF = "Apagar ref/branch/tag ou podar objetos perde trabalho; deixe para a titular."
RODAPE = ("Se a titular pediu explicitamente, ela mesma roda o comando no terminal (`! git ...`) "
          "ou ajusta a permissao - nao contorne este guarda. Regra: CLAUDE.md, 'Proibido sem "
          "pedido explicito'; runbook: docs/runbooks/hooks.md.")

PREFIXOS = {"sudo", "env", "command", "exec", "nohup", "time", "&", ".", "call", "builtin",
            "export", "set"}
SHELLS_BASH = {"bash", "sh", "zsh", "dash"}
SHELLS_PS = {"powershell", "pwsh"}
SEP_BASH = set(";&|\n(){}`")
SEP_PS = set(";&|\n(){}")
# opcoes do powershell/pwsh que recebem VALOR (o laco nao pode parar no valor: `-ep Bypass`)
PS_COM_VALOR = ("executionpolicy", "windowstyle", "version", "outputformat", "inputformat",
                "configurationname", "configurationfile", "psconsolefile", "workingdirectory",
                "custompipename", "settingsfile", "encodedarguments")
PS_COM_VALOR_ALIAS = {"ep", "ex", "w", "v", "o", "of", "if", "inp", "wd", "config"}
BASH_COM_VALOR = {"--rcfile", "--init-file"}
MAX_PROFUNDIDADE = 4
# opcoes longas do git cujo VALOR pode vir no token seguinte (`--sort -refname`): o valor nao e
# lido como flags curtas. Lista fechada; fora dela, o erro possivel e falso POSITIVO.
VALOR_LONGO = {"sort", "format", "points-at", "contains", "no-contains", "merged", "no-merged",
               "message", "file", "cleanup", "set-upstream-to", "exec", "strategy",
               "strategy-option", "onto", "author", "date", "template", "reuse-message",
               "reedit-message", "fixup", "source", "conflict", "orphan", "push-option",
               "repo", "receive-pack", "exclude", "depth", "shallow-since", "shallow-exclude",
               "upload-pack", "trailer", "pathspec-from-file", "local-user"}
# opcoes CURTAS que recebem valor, por subcomando (`-Xtheirs`, `-m msg`): o resto do token, ou o
# token seguinte, e valor. A letra em si continua contando (`-B nome` ainda e `B`).
CURTA_COM_VALOR = {"pull": "Xsoj", "push": "o", "tag": "mFu", "branch": "u", "checkout": "bB",
                   "switch": "cC", "clean": "e", "restore": "s", "update-ref": "m", "commit": "mFcC",
                   "rm": ""}


def _balanceado(texto, i):
    """texto[i] e o primeiro char depois de `$(`; devolve (conteudo, indice depois do `)`)."""
    prof, aspa, ini = 1, None, i
    while i < len(texto):
        c = texto[i]
        if aspa:
            if c == aspa:
                aspa = None
        elif c in "'\"":
            aspa = c
        elif c == "(":
            prof += 1
        elif c == ")":
            prof -= 1
            if prof == 0:
                return texto[ini:i], i + 1
        i += 1
    return texto[ini:], i


def _shell_do_trecho(trecho):
    """Nome do shell que recebe o heredoc desta linha (`bash <<EOF`), ou None."""
    ultimo = re.split(r"[;&|(]", trecho)[-1].split()
    k = 0
    while k < len(ultimo) and (ultimo[k].lower() in PREFIXOS or "=" in ultimo[k]):
        k += 1
    if k < len(ultimo):
        nome = _nome(ultimo[k].strip("'\""))
        if nome in SHELLS_BASH or nome in SHELLS_PS or nome == "cmd":
            return nome
    return None


def _sem_corpos(texto):
    """Tira corpo de heredoc e here-string. Devolve (texto, [(corpo, dialeto)]) - so os corpos
    entregues a um shell voltam para avaliacao; os demais sao texto (mensagem de commit etc.)."""
    texto = re.sub(r"@'\r?\n.*?\r?\n'@", "''", texto, flags=re.S)
    texto = re.sub(r'@"\r?\n.*?\r?\n"@', "''", texto, flags=re.S)
    saida, corpos, linhas, i = [], [], texto.split("\n"), 0
    while i < len(linhas):
        linha = linhas[i]
        saida.append(linha)
        m = re.search(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", linha)
        i += 1
        if m:
            fim, corpo = m.group(2), []
            while i < len(linhas) and linhas[i].strip() != fim:
                corpo.append(linhas[i])
                i += 1
            i += 1
            shell = _shell_do_trecho(linha[:m.start()])
            if shell:
                corpos.append(("\n".join(corpo), "ps" if shell in SHELLS_PS else "bash"))
    return "\n".join(saida), corpos


def _segmentos(texto, dialeto):
    """Devolve (segmentos, subcomandos): segmentos sao listas de tokens sem aspas; subcomandos
    sao `$(...)`/crase achados DENTRO de aspas duplas, para avaliar a parte."""
    if dialeto == "bash":
        texto = re.sub(r"\\\r?\n", " ", texto)
        seps, esc = SEP_BASH, "\\"
    else:
        texto = re.sub(r"`\r?\n", " ", texto)
        seps, esc = SEP_PS, "`"
    segs, subs, toks, atual, tem, aspa = [], [], [], [], False, None
    i, n = 0, len(texto)
    while i < n:
        c = texto[i]
        if aspa == "'":
            if c == "'":
                aspa = None
            else:
                atual.append(c)
        elif aspa == '"':
            if c == '"':
                aspa = None
            elif c == esc and i + 1 < n and (dialeto == "ps" or texto[i + 1] in '"\\$`'):
                atual.append(texto[i + 1])
                i += 1
            elif c == "$" and i + 1 < n and texto[i + 1] == "(":
                corpo, fim = _balanceado(texto, i + 2)
                subs.append(corpo)
                atual.append(texto[i:fim])
                i = fim
                continue
            elif c == "`" and dialeto == "bash":
                fim = texto.find("`", i + 1)
                fim = n if fim < 0 else fim
                subs.append(texto[i + 1:fim])
                i = fim + 1
                continue
            else:
                atual.append(c)
        elif c == esc and i + 1 < n:
            atual.append(texto[i + 1])
            i += 1
        elif c in "'\"":
            aspa, tem = c, True
        elif c.isspace() or c in seps:
            if atual or tem:
                toks.append("".join(atual))
                atual, tem = [], False
            if c in seps and toks:
                segs.append(toks)
                toks = []
        else:
            atual.append(c)
        i += 1
    if atual or tem:
        toks.append("".join(atual))
    if toks:
        segs.append(toks)
    return segs, subs


def _nome(tok):
    base = re.split(r"[\\/]", tok)[-1].lower()
    return base[:-4] if base.endswith(".exe") else base


def _curtas(args, com_valor=""):
    """Letras de flags curtas (`-xdf` -> 'xdf'); para em `--`. Letra de `com_valor` encerra o
    token (o resto e valor: `-Xtheirs`) ou consome o seguinte (`-m msg`); valor de opcao longa
    de VALOR_LONGO no token seguinte (`--sort -refname`) nao conta como flags."""
    letras, i = "", 0
    while i < len(args):
        a = args[i]
        if a == "--":
            break
        if a.startswith("--"):
            if "=" not in a and a[2:].lower() in VALOR_LONGO:
                i += 1
        elif a.startswith("-") and len(a) > 1:
            for k, letra in enumerate(a[1:]):
                letras += letra
                if letra in com_valor:
                    if k == len(a) - 2:
                        i += 1
                    break
        i += 1
    return letras


def _longa(args, *nomes):
    """Alguma opcao longa e um dos nomes ou abreviacao dele (desde 1 letra)? O git aceita
    abreviacao unica e REJEITA a ambigua, entao tratar prefixo como o nome destrutivo so
    bloqueia o que o git executaria ou recusaria de qualquer jeito."""
    for a in args:
        if a == "--":
            break
        if a.startswith("--") and len(a) > 2:
            parte = a[2:].split("=", 1)[0].lower()
            if any(n.startswith(parte) for n in nomes):
                return True
    return False


def _hookspath(texto):
    return "core.hookspath" in texto.lower()


def _config_escreve_hookspath(a):
    pos, i = [], 0
    while i < len(a):
        x, xl = a[i], a[i].lower()
        if x.startswith("-"):
            if xl in ("--file", "-f", "--blob", "--type", "--default", "--comment", "--value"):
                i += 2
                continue
            i += 1
            continue
        pos.append(x)
        i += 1
    if not pos:
        return False
    verbo = pos[0].lower()
    if verbo in ("get", "list"):
        return False
    if verbo in ("set", "unset", "rename-section", "remove-section", "edit"):
        return any(_hookspath(p) for p in pos[1:2])
    if not _hookspath(pos[0]):
        return False
    return len(pos) >= 2 or _longa(a, "unset", "unset-all", "replace-all", "add", "rename-section",
                                   "remove-section", "edit")


def _git(args):
    """args = tokens depois de `git`. Devolve (regra, dica) ou None."""
    i = 0
    while i < len(args) and args[i].startswith("-"):
        op = args[i]
        if op in ("-c", "--config-env") and i + 1 < len(args):
            if _hookspath(args[i + 1]):
                return "`git %s core.hooksPath=...` desliga os hooks do commit/push" % op, DICA_HOOKS
            i += 2
            continue
        if (op.startswith("-c") or op.lower().startswith("--config-env=")) and _hookspath(op):
            return "`git -c core.hooksPath=...` desliga os hooks do commit/push", DICA_HOOKS
        if op in ("-C", "--git-dir", "--work-tree", "--namespace"):
            i += 2
            continue
        i += 1
    if i >= len(args):
        return None
    sub, a = args[i].lower(), args[i + 1:]
    curtas = _curtas(a, CURTA_COM_VALOR.get(sub, ""))

    if sub == "checkout":
        if "--" in a or "." in a or "f" in curtas or _longa(a, "force", "pathspec-from-file"):
            return "`git checkout` com `--`, `.` ou `--force` descarta mudanca do disco", DICA_ARQUIVO
        if "B" in curtas:
            return "`git checkout -B` move uma branch existente (como `branch -f`)", DICA_REF
    elif sub == "switch":
        if "f" in curtas or _longa(a, "force", "discard-changes"):
            return "`git switch --force/--discard-changes` descarta mudanca do disco", DICA_ARQUIVO
        if "C" in curtas or _longa(a, "force-create"):
            return "`git switch -C/--force-create` move uma branch existente (como `branch -f`)", DICA_REF
    elif sub == "restore":
        staged = "S" in curtas or _longa(a, "staged")
        worktree = "W" in curtas or _longa(a, "worktree")
        if not staged or worktree:
            return "`git restore` (fora de `--staged` sem `--worktree`) descarta mudanca do disco", DICA_ARQUIVO
    elif sub == "reset":
        if _longa(a, "hard", "merge", "keep"):
            return "`git reset --hard/--merge/--keep` descarta mudanca do disco", DICA_ARQUIVO
    elif sub == "clean":
        if ("f" in curtas or _longa(a, "force")) and not ("n" in curtas or _longa(a, "dry-run")):
            return "`git clean -f` apaga arquivo nao rastreado sem volta", DICA_ARQUIVO
    elif sub == "rm":
        if ("f" in curtas or _longa(a, "force")) and not _longa(a, "cached"):
            return "`git rm -f` apaga arquivo com mudanca nao commitada", DICA_ARQUIVO
    elif sub == "push":
        if ("f" in curtas or "d" in curtas
                or _longa(a, "force", "force-with-lease", "force-if-includes", "delete", "mirror", "prune")):
            return "`git push` forcado, de delecao, --mirror ou --prune", DICA_REMOTO
        posicionais = [x for x in a if not x.startswith("-")]
        if any(x.startswith("+") or x.startswith(":") for x in posicionais[1:]):
            return "`git push` com refspec forcada (`+x`) ou de delecao (`:x`)", DICA_REMOTO
    elif sub == "pull":
        rebase = "r" in curtas
        for x in a:
            if x == "--":
                break
            if x.startswith("--") and len(x) > 2:
                nome, _, valor = x[2:].partition("=")
                if "rebase".startswith(nome.lower()) and valor.lower() not in ("false", "no", "off", "0"):
                    rebase = True
        if rebase:
            return "`git pull --rebase` reescreve historico local", DICA_HISTORICO
    elif sub == "rebase":
        return "`git rebase` reescreve historico", DICA_HISTORICO
    elif sub == "commit":
        if _longa(a, "amend"):
            return "`git commit --amend` reescreve historico", DICA_HISTORICO
    elif sub == "stash":
        if a and a[0].lower() in ("drop", "clear"):
            return "`git stash drop/clear` descarta trabalho guardado (e a pilha e compartilhada entre worktrees)", DICA_ARQUIVO
    elif sub == "branch":
        if any(x in curtas for x in "DMCf") or _longa(a, "force"):
            return "`git branch -D/-M/-C/-f` apaga ou sobrescreve branch", DICA_REF
    elif sub == "tag":
        if "d" in curtas or "f" in curtas or _longa(a, "delete", "force"):
            return "`git tag -d/-f` apaga ou move tag", DICA_REF
    elif sub == "worktree":
        acao = a[0].lower() if a else ""
        if acao == "prune":
            return "`git worktree prune` apaga metadado de worktree", DICA_WORKTREE
        if acao == "remove" and ("f" in _curtas(a[1:]) or _longa(a[1:], "force")):
            return "`git worktree remove --force` apaga worktree com mudanca", DICA_WORKTREE
    elif sub == "update-ref":
        if "d" in curtas or _longa(a, "delete"):
            return "`git update-ref -d` apaga ref", DICA_REF
    elif sub == "reflog":
        if a and a[0].lower() in ("expire", "delete"):
            return "`git reflog expire/delete` apaga a rede de seguranca do historico", DICA_REF
    elif sub == "gc":
        for x in a:
            if x.lower().startswith("--prune=") and x.split("=", 1)[1].lower() in ("now", "all"):
                return "`git gc --prune=now` apaga objeto inalcancavel sem volta", DICA_REF
    elif sub in ("filter-branch", "filter-repo"):
        return "`git %s` reescreve historico" % sub, DICA_HISTORICO
    elif sub == "config":
        if _config_escreve_hookspath(a):
            return "`git config core.hooksPath <valor>` desligaria ou desviaria os hooks", DICA_HOOKS
    return None


def _candidatos_de_shell(nome, resto):
    """O que um `bash -c`/`powershell -Command`/`cmd /c` executaria: [(texto, dialeto)]."""
    if nome in SHELLS_PS:
        i = 0
        while i < len(resto):
            t = resto[i]
            if len(t) > 1 and t[0] in "-/":
                op, colado, valor = t.lstrip("-/").partition(":")
                op = op.lower()
                # valor colado por ':' (`-ExecutionPolicy:Bypass`) NAO consome o token seguinte
                if op and "command".startswith(op):
                    return [(" ".join(([valor] if colado else []) + resto[i + 1:]), "ps")]
                if op in ("e", "ec") or (len(op) >= 2 and "encodedcommand".startswith(op)):
                    b64 = valor if colado else (resto[i + 1] if i + 1 < len(resto) else "")
                    try:
                        return [(base64.b64decode(b64).decode("utf-16-le", errors="replace"), "ps")]
                    except Exception:
                        return []
                if op and "file".startswith(op):
                    return []
                if op in PS_COM_VALOR_ALIAS or (len(op) >= 2 and any(v.startswith(op) for v in PS_COM_VALOR)):
                    i += 1 if colado else 2
                    continue
                i += 1
                continue
            return [(" ".join(resto[i:]), "ps")]
        return []
    if nome in SHELLS_BASH:
        i = 0
        while i < len(resto):
            t = resto[i]
            if t in BASH_COM_VALOR:
                i += 2
                continue
            if t[:1] in "-+" and len(t) > 1:
                if t.startswith("--"):
                    i += 1
                    continue
                # flags combinadas: cada `o`/`O` consome um valor (`-euo pipefail`)
                letras = t[1:]
                n_valores = letras.count("o") + letras.count("O")
                if "c" in letras:
                    return [(" ".join(resto[i + 1 + n_valores:]), "bash")]
                i += 1 + n_valores
                continue
            return []
        return []
    if nome == "cmd":
        i = 0
        while i < len(resto) and resto[i].startswith("/"):
            i += 1
        return [(" ".join(resto[i:]), "ps")]
    return []


def _avaliar_tokens(toks, dialeto, profundidade):
    i = 0
    while i < len(toks):
        t = toks[i]
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", t, flags=re.S)
        if m:
            if m.group(1).upper().startswith("GIT_CONFIG") and _hookspath(m.group(2)):
                return "`GIT_CONFIG_*` com core.hooksPath desliga os hooks", DICA_HOOKS
        elif t.lower() not in PREFIXOS:
            break
        i += 1
    if i >= len(toks):
        return None
    if toks[i].lower().startswith("$env:git_config") and any(_hookspath(x) for x in toks):
        return "`$env:GIT_CONFIG_*` com core.hooksPath desliga os hooks", DICA_HOOKS
    nome, resto = _nome(toks[i]), toks[i + 1:]
    if nome == "git":
        return _git(resto)
    if profundidade < MAX_PROFUNDIDADE:
        for texto, dial in _candidatos_de_shell(nome, resto):
            achado = _avaliar(texto, dial, profundidade + 1)
            if achado:
                return achado[:2]
    return None


def _avaliar(comando, dialeto, profundidade):
    texto, corpos = _sem_corpos(comando)
    segs, subs = _segmentos(texto, dialeto)
    for toks in segs:
        achado = _avaliar_tokens(toks, dialeto, profundidade)
        if achado:
            return achado + (" ".join(toks),)
    if profundidade < MAX_PROFUNDIDADE:
        for texto_sub, dial in [(s, dialeto) for s in subs] + corpos:
            achado = _avaliar(texto_sub, dial, profundidade + 1)
            if achado:
                return achado
    return None


def avaliar(comando, ferramenta=None):
    """Motivo do bloqueio (texto para o modelo) ou None se o comando pode seguir.

    `ferramenta` ('Bash'/'PowerShell') escolhe o dialeto; sem ela, avalia nos dois."""
    if not isinstance(comando, str):
        return None
    if "git" not in comando.lower() and not re.search(r"""(^|\s)["']?(-{1,2}|/)e(c|n[a-z]*)?["']?(\s|:)""", comando, re.I):
        return None
    dialetos = {"Bash": ["bash"], "PowerShell": ["ps"]}.get(ferramenta, ["bash", "ps"])
    for dialeto in dialetos:
        achado = _avaliar(comando, dialeto, 0)
        if achado:
            regra, dica, segmento = achado
            return ("BLOQUEADO pelo guarda de git destrutivo (plugin os): %s.\n"
                    "Segmento: %s\nComo seguir: %s\n%s" % (regra, segmento, dica, RODAPE))
    return None


def main():
    try:
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    try:
        bruto = sys.stdin.buffer.read().decode("utf-8-sig", errors="replace")
        evento = json.loads(bruto) if bruto.strip() else {}
        ferramenta = evento.get("tool_name")
        if ferramenta not in ("Bash", "PowerShell"):
            return 0
        motivo = avaliar((evento.get("tool_input") or {}).get("command"), ferramenta)
    except Exception as e:  # falha do guarda nunca vira bloqueio: saida 0 (so o 2 deliberado bloqueia)
        sys.stderr.write("guarda_git: falha interna, comando NAO avaliado (%s: %s)\n" % (type(e).__name__, e))
        return 0
    if motivo:
        sys.stderr.write(motivo + "\n")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
