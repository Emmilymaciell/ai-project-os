# Runbook — máquina nova: do zero ao trabalho

Objetivo: o ecossistema sobrevive à perda do notebook. Nada abaixo depende de conversa, de memória de
conta de IA nem deste computador: só do GitHub privado (`Emmilymaciell/*`), do Google Drive
(`EMMILY PROJECT CLOUD/`) e de logins que só a titular pode fazer (gates H1).

| # | Passo | Comando / ação | Gate |
|---|---|---|---|
| 1 | Pré-requisitos | Windows 11, PowerShell 5.1, Git 2.40+, Python 3.13 (`py`), Node 24, `gh`, `rclone`, Claude Code | — |
| 2 | Identidade Git | `git config --global user.name "Emmily Maciel"` · `user.email (e-mail removido)` · `init.defaultBranch main` | — |
| 3 | Login GitHub | `gh auth login` (HTTPS, navegador) | **H1** |
| 4 | Clonar a plataforma | `git clone https://github.com/Emmilymaciell/ai-project-os C:\AI-WORKSPACE\_platform\emmily-ai-project-os` | — |
| 5 | Bootstrap | `cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os; .\scripts\bootstrap.ps1; .\scripts\install-hooks.ps1` | — |
| 6 | Conectar o Drive | remoto `gdrive` com o client OAuth **próprio** (projeto Google Cloud `emmily-os-rclone`), no terminal da titular, não pelo agente: `bw unlock`; `$id = bw get username rclone-gdrive-oauth-client`; `$sec = bw get password rclone-gdrive-oauth-client`; `rclone config create gdrive drive client_id=$id client_secret=$sec scope=drive`; `Remove-Variable id,sec`. Autorizar no navegador (app não verificado: *Advanced* → *Go to Emmily OS rclone (unsafe)* → *Continue*). Conferir: `rclone about gdrive:` sem o aviso do client compartilhado | **H1** |
| 7 | Config da máquina | `rclone copy "gdrive:EMMILY PROJECT CLOUD/99 RECOVERY/disaster-recovery/machines/notebook-principal.machine.yaml" $env:TEMP\dr\` → copiar para `%USERPROFILE%\.emmily-os\machine.yaml` e ajustar `machine.name` e `AI_WORKSPACE` se a letra de unidade mudar | — |
| 8 | Assinatura | gerar chave nova: `ssh-keygen -t ed25519 -N "" -f $HOME\.ssh\id_ed25519_git_signing`; configurar `gpg.format ssh`, `user.signingkey`, `commit.gpgsign true`, `tag.gpgsign true`, `gpg.ssh.allowedSignersFile`; registrar a pública: `gh auth refresh -h github.com -s admin:ssh_signing_key` e `gh ssh-key add <pub> --type signing` | **H1** |
| 9 | Segredos | cada projeto declara NOMES em `secrets.manifest`/`.env.example`; os valores vêm do provedor (Bitwarden, Cloudflare, Google, Microsoft) — nunca do Git nem do Drive. `wrangler login` para o calendar-sync | **H1** |
| 10 | Diagnóstico | `.\scripts\doctor.ps1` · `py -3.13 -m eos validate` · `py -3.13 -m eos status` | — |
| 11 | Restaurar um projeto | `py -3.13 -m eos restore <id> --para <pasta vazia>` (fonte `auto`: GitHub + bundle, WIP e bancos do Drive). Projeto com pasta `cloud-mirror`: acrescente `--com-dados`, que baixa o último espelho verificado (`eos mirror`) para `<pasta>/<path>` e confere tamanho e md5 de cada arquivo | — |
| 12 | Trabalhar | abrir o Claude Code na pasta do projeto → `/session-start` | — |

> **Risco aceito (ADR-0018):** a chave de assinatura é gerada **sem passphrase** para que commits de
> agentes não travem em prompt. A assinatura prova "este perfil nesta máquina", não "esta pessoa".
> Quem preferir passphrase: `ssh-keygen -p -f $HOME\.ssh\id_ed25519_git_signing` e usar o `ssh-agent`.

## O que NÃO se copia de propósito

- A chave privada de assinatura: gera-se outra. As assinaturas antigas continuam verificáveis enquanto a
  chave pública antiga estiver cadastrada no GitHub.
- `rclone.conf`, `gh` e tokens: são credenciais; refaz-se o login (H1). O Client ID/secret do rclone
  vêm do Bitwarden (`rclone-gdrive-oauth-client`); a cópia `~\.emmily-os\rclone.conf.bak-20261016`
  é desta máquina e não viaja.
- `%LOCALAPPDATA%\emmily-os\registry.db`: é índice derivado; `py -3.13 -m eos index` reconstrói.

## Kit no Drive (`99 RECOVERY/disaster-recovery/`)

- `machines/notebook-principal.machine.yaml` — modelo da config desta máquina (sem segredo).
- `MAQUINA-NOVA.md` — cópia deste runbook.
- `inventario-repos.txt` — lista dos repositórios privados e onde cada projeto mora.

Prova: a certificação L6 de cada projeto já restaura de fonte limpa (clone + Drive) e roda o smoke;
`eos prepare-machine-migration` diz projeto a projeto o que ainda falta.
