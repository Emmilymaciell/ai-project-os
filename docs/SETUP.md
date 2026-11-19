# SETUP — instalar o Project OS

Este documento é o contrato de portabilidade da plataforma. Se ele estiver correto, outra pessoa, conta ou máquina consegue assumir sem depender de nenhum histórico de conversa.

## Requisitos

| Requisito | Mínimo | Obrigatório? |
|---|---|---|
| Windows | 10/11 | sim |
| PowerShell | 5.1 | sim |
| Git | 2.55 (versão medida; o scanner usa `rev-list --objects -z`, não provado em versões anteriores) | sim |
| Claude Code | Desktop ou CLI | sim |
| Python | 3.13 (launcher `py`; 3.12 mínimo) | sim — o motor `eos` (vNext) é Python |
| Node | 20+ | só para projetos Node |
| GitHub CLI (`gh`) | 2.x | sim — remotos privados, restore e `eos new` |
| rclone | 1.6x+ (medido: 1.75.1) | sim — Google Drive (`gdrive:`, client OAuth próprio desde 2026-10-16; criar o remoto como em `docs/runbooks/maquina-nova.md`, passo 6), backup e recovery |
| Bitwarden CLI (`bw`) | 2026.x | sim, na máquina nova — guarda o client OAuth do rclone (item `rclone-gdrive-oauth-client`) |

## Máquina nova (vNext) — caminho curto

O roteiro completo, com os logins (gates H1), a config da máquina e a assinatura, está em
[`runbooks/maquina-nova.md`](runbooks/maquina-nova.md). O kit correspondente fica no Drive em
`EMMILY PROJECT CLOUD/99 RECOVERY/disaster-recovery/`. Os passos abaixo cobrem a instalação da
plataforma e do plugin.

## Instalação

### 1. Clonar

```powershell
git clone <url-do-repo> C:\AI-WORKSPACE\_platform\emmily-ai-project-os
```

O caminho importa: o `bootstrap` deduz a raiz do workspace subindo dois níveis a partir do repositório. Clonar em outro lugar funciona, mas cria o workspace no lugar errado.

### 2. Rodar o bootstrap

```powershell
cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os
.\scripts\bootstrap.ps1
```

Ele verifica ferramentas, cria as pastas do workspace que faltarem e diz o que ainda falta. É idempotente — rode quantas vezes quiser. Para só diagnosticar sem criar nada: `.\scripts\bootstrap.ps1 -Check`.

### 3. Configurar a identidade Git (se o bootstrap acusar)

```powershell
git config --global user.name "Seu Nome"
git config --global user.email "seu@email"
git config --global init.defaultBranch main
```

Sem isso, **o primeiro commit de qualquer repositório novo falha**.

### 4. Registrar e instalar o plugin

É isso que faz `/os:new-project`, `/os:resume`, `/os:checkpoint`, `/os:status` e `/os:handoff` funcionarem **em qualquer pasta** — inclusive onde o projeto ainda não existe. Sem esse passo, o repositório é só um monte de arquivos.

Nesta máquina o CLI está em `~\.local\bin\claude.exe` (instalador nativo), fora do PATH do Bash. Pela linha de comando:

```powershell
& "$env:USERPROFILE\.local\bin\claude.exe" plugin marketplace add C:\AI-WORKSPACE\_platform\emmily-ai-project-os
& "$env:USERPROFILE\.local\bin\claude.exe" plugin install os@emmily-platform
```

O equivalente dentro do Claude Code:

```
/plugin marketplace add C:\AI-WORKSPACE\_platform\emmily-ai-project-os
```

e depois instalar o plugin `os` pelo `/plugin`.

### 5. Verificar — quatro camadas, nesta ordem

Cada camada responde a uma pergunta diferente. Passar numa não garante a seguinte.

```powershell
# 1. nossos próprios testes: estrutura, ADRs, template, segurança
.\tests\run-tests.ps1                      # tudo
.\tests\run-tests.ps1 -List                # quais suites existem
.\tests\run-tests.ps1 -Suite security      # uma só
.\tests\run-tests.ps1 -Suite skills,docs   # algumas

# 2. validação estrutural oficial do Claude Code
& "$env:USERPROFILE\.local\bin\claude.exe" plugin validate . --strict
& "$env:USERPROFILE\.local\bin\claude.exe" plugin validate .\skills --strict

# 3. carregamento real, sem instalar
& "$env:USERPROFILE\.local\bin\claude.exe" --plugin-dir C:\AI-WORKSPACE\_platform\emmily-ai-project-os --debug-file plugin.log -p "ok"
Select-String -Path plugin.log -Pattern 'skills from plugin os'   # deve dizer 5

# 4. carregamento após instalação — o caminho que você usa de fato
& "$env:USERPROFILE\.local\bin\claude.exe" plugin details os      # deve listar Skills (5)
```

Depois, dentro do Claude Code, `/os:status` deve responder.

> **Nota sobre `claude plugin validate`:** com `marketplace.json` e `plugin.json` no mesmo `.claude-plugin/`, o comando valida o **manifesto do marketplace** e não o do plugin. Para validar o plugin em si, valide `.\skills` (que checa os componentes) ou copie o plugin para uma pasta temporária sem o `marketplace.json`.

## Desenvolvimento vs. instalado — uma pegadinha real

`claude plugin install` faz uma **cópia congelada** do plugin em
`~\.claude\plugins\cache\emmily-platform\os\<versão>\`. Verificado empiricamente: editar um `SKILL.md` no repositório **não** altera a cópia instalada.

Consequência prática:

| Situação | O que fazer |
|---|---|
| Editando as skills | Usar `--plugin-dir <repo>`, que lê o repositório ao vivo, e `/reload-plugins` para recarregar |
| Terminou de editar e quer que o plugin instalado veja | Subir o `version` em `.claude-plugin/plugin.json` e rodar `claude plugin update os` |
| Corrigiu algo **sem** mudar o `version` | `claude plugin update os` responde `already at the latest version` e **não atualiza nada**. Reinstale: `claude plugin uninstall os` seguido de `claude plugin install os@emmily-platform` |

O campo `version` não é decorativo: é o que decide se a atualização é entregue. Verificado nos dois sentidos — `update` sem bump de versão é no-op silencioso, e reinstalar no mesmo número refresca a cópia.

## Desinstalar

Remover o plugin pelo `/plugin` e apagar o clone. O bootstrap não escreve fora de `C:\AI-WORKSPACE` e não altera configuração global do Git — isso é feito por você, no passo 3, explicitamente.

## Transferir para outra pessoa

1. `/os:handoff` no projeto em questão.
2. Conferir que `docs/STATE.md` e `docs/decisions/` estão atualizados.
3. Confirmar que nenhum segredo está versionado: `git ls-files | Select-String -Pattern '\.env$|\.key$|\.pem$'` deve voltar vazio.
4. Entregar a URL do repositório e este `SETUP.md`.

O que a outra pessoa **não** precisa: acesso a nenhuma conversa, a nenhuma conta do Claude específica, nem a esta máquina.
