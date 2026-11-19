# 09 — Troca de computador

> Regra: **a máquina antiga só é desligada, formatada ou devolvida depois que a nova mostra todos os
> projetos SAFE.** Apagar a antiga é gate H3.

## Parte A — na máquina antiga

### A1. "Posso trocar de computador?"

```powershell
cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os
py -3.13 -m eos prepare-machine-migration
```

Ele mostra a tabela de todos os projetos e, para cada um que **não** está pronto, o motivo:

```
Antes de trocar de computador:
  engenharia-rodoviaria (L1):
    - remote: nenhum remoto declarado
  prog-relatorio-g2 (L4):
    - ...

NAO esta pronto: 2 projeto(s) com bloqueio. Nada foi alterado.
```

ou, quando tudo está certo: `PRONTO para trocar de computador.`

*"Posso trocar de computador?"* responde SIM para um projeto só quando ele está em **L5 ou L6** e
**nada existe só nesta pasta**. Os bloqueios típicos e o que fazer:

| Bloqueio | Ação |
|---|---|
| `remote: nenhum remoto declarado` | criar remoto privado (se permitido) e push; se o remoto for bloqueado de propósito (ex.: licença externa), o projeto depende do bundle no Drive e da sua decisão (H4) |
| `remote: n ref(s) local(is) nao publicada(s)` | *"manda pro GitHub"* (push de todas as branches e tags). Refs em `refs/preservado/*` não entram nessa conta: são locais de propósito (conteúdo que não pode ir ao GitHub) e viajam só no bundle do `eos backup` |
| `backup: refs mudaram...` / `WIP ... nao esta no ultimo snapshot` | `py -3.13 -m eos backup <id>` |
| `segredos com valor so nesta pasta (.env, store local-env)` | levar os valores para o cofre (Bitwarden) antes |
| `pasta de dados '<x>' (cloud-mirror) ainda sem copia verificada pelo motor` | `py -3.13 -m eos mirror <id>` (copia para `<drive_root>/dados/<x>` e confere tamanho e md5; ver [08](08-BACKUP-E-RECOVERY.md)) |
| `'<x>': n arquivo(s) novo(s)/alterado(s) desde o espelho de <carimbo>` | a pasta mudou depois do último espelho: `py -3.13 -m eos mirror <id>` de novo |
| `'<x>': n arquivo(s) que o espelho recusa existe(m) so nesta pasta` | arquivo com nome de segredo ou atalho (symlink/junção) dentro da pasta de dados: segredo vai para o cofre; atalho vira arquivo de verdade ou sai da pasta |
| `pasta de dados '<x>' (cloud-mirror): espelho nao verificavel` | o Drive não respondeu: conferir o rclone (`rclone lsd gdrive:`) e rodar de novo |
| `n item(ns) ignorado(s) pelo Git e nao declarado(s)` | declarar a política de cada pasta em `data` no contrato (o Claude propõe) |
| `'x' esta em backup.exclude: nao sobe, e existe so nesta pasta` | decidir: copiar para o Drive ou aceitar perder |
| `state: ... mais velho que o ultimo commit` | atualizar o `STATE.md` |
| `recovery: certificacao com mais de 30 dias` | só afeta L6; para trocar de PC basta L5, mas recertificar é recomendado |

### A2. Guardar o que é da máquina

- [ ] `%USERPROFILE%\.emmily-os\machine.yaml`: pequeno, sem segredo. A cópia fica no Drive em
      `99 RECOVERY/disaster-recovery/machines/notebook-principal.machine.yaml` (kit criado em
      2026-10-12, junto com `MAQUINA-NOVA.md` e `inventario-repos.txt`). Se mudar o arquivo, copie de novo:
      `rclone copy $env:USERPROFILE\.emmily-os\machine.yaml "gdrive:EMMILY PROJECT CLOUD/99 RECOVERY/disaster-recovery/machines/"`
      e renomeie lá para `notebook-principal.machine.yaml`. Roteiro passo a passo: `docs/runbooks/maquina-nova.md`.
- [ ] Lista dos segredos de que você vai precisar: `cofre.manifest` na plataforma e `secrets.manifest`
      / `.env.example` em cada projeto. São **nomes**; os valores vêm do cofre.
- [ ] Último `py -3.13 -m eos backup --todos`.
- [ ] Último `py -3.13 -m eos mirror --todos` (espelha as pastas `cloud-mirror` de todos os projetos
      que as têm; só acrescenta no Drive). Rode **depois** de parar de mexer nos dados: arquivo que
      muda depois do espelho volta a bloquear.
- [ ] Último `py -3.13 -m eos prepare-machine-migration` mostrando `PRONTO`.

### A3. O que **não** se copia

- **A chave de assinatura de commits** (`~/.ssh/id_ed25519_git_signing`). A máquina nova gera
  outra. As assinaturas antigas continuam verificáveis no GitHub enquanto a chave **pública** antiga
  estiver registrada lá: não a remova.
- Tokens de `gh`, `rclone` e Claude: cada um é refeito por login (H1) na máquina nova.
- `.venv`, `node_modules`, caches: são reconstruídos.

## Parte B — na máquina nova

### B1. Instalar as ferramentas

| Ferramenta | Como | Obrigatória? |
|---|---|---|
| Git 2.40+ | `winget install --id Git.Git` | sim |
| Python 3.13 (launcher `py`) | instalador do python.org ou `winget` | sim (o motor exige 3.12+) |
| GitHub CLI | `winget install --id GitHub.cli` | sim, para remoto |
| rclone | `winget install --id Rclone.Rclone` | sim, transporte padrão do Drive |
| Claude Code | instalador nativo | sim |
| Google Drive para desktop | instalador do Google | recomendado (transporte reserva) |
| Bitwarden (app e CLI) | instalador do Bitwarden | sim: o client OAuth do rclone vem dele (item `rclone-gdrive-oauth-client`) |
| Node 20+ | `winget` | só para projetos Node |

O `bootstrap.ps1` confere Git, `py` e `gh`; o rclone ele **não** confere, então verifique à mão com
`rclone version`.

### B2. Logins (gate H1: só você)

```powershell
gh auth login                       # navegador
```

**Drive (rclone com o client próprio).** O remoto continua se chamando `gdrive`, mas é criado com o
Client ID e o Client secret do seu app Google (`emmily-os-rclone`), guardados no Bitwarden no item
`rclone-gdrive-oauth-client`. Rode no **seu** terminal, não pelo Claude (o rclone mostra a
configuração do remoto ao terminar):

```powershell
bw login; bw unlock                 # guarde a sessão em $env:BW_SESSION, como o bw indica
$id  = bw get username rclone-gdrive-oauth-client
$sec = bw get password rclone-gdrive-oauth-client
rclone config create gdrive drive client_id=$id client_secret=$sec scope=drive
Remove-Variable id,sec
rclone about gdrive:                # não pode aparecer o aviso "shared Google Drive client_id"
```

O navegador abre: escolha a conta dona do Drive e, na tela "Google hasn't verified this app",
clique em **Advanced** → **Go to Emmily OS rclone (unsafe)** → **Continue**. Sem o `bw` CLI: abra o
item no app do Bitwarden e rode `rclone config` (novo remoto `gdrive`, tipo `drive`, cole os dois
valores quando ele pedir `client_id` e `client_secret`, escopo `drive`). Nunca cole esses valores no
chat nem em arquivo. Não copie o `rclone.conf` da máquina antiga: ele tem tokens.

E no Claude Code: `/login`. No Bitwarden: login e desbloqueio pelo app (nunca digite a senha mestra
no chat nem em arquivo).

### B3. Identidade e assinatura do Git

```powershell
git config --global user.name "Emmily Maciel"
git config --global user.email "<seu e-mail pessoal do GitHub>"
git config --global init.defaultBranch main

ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519_git_signing" -C "git-signing-<nome-da-maquina>"
git config --global gpg.format ssh
git config --global user.signingkey "$env:USERPROFILE\.ssh\id_ed25519_git_signing.pub"
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

Registrar a chave **pública** nova no GitHub como chave de assinatura (H1, porque pede uma permissão
extra do `gh` no navegador):

```powershell
gh auth refresh -h github.com -s admin:ssh_signing_key
gh ssh-key add "$env:USERPROFILE\.ssh\id_ed25519_git_signing.pub" --type signing --title "<nome-da-maquina>"
```

Para o `git log --show-signature` local reconhecer suas assinaturas, a chave pública também entra no
arquivo de signatários permitidos (`gpg.ssh.allowedSignersFile`, nesta máquina
`~/.ssh/allowed_signers`), numa linha `<seu e-mail> <conteúdo da chave .pub>`. Sem essa linha, o
`%G?` dos commits novos sai `U` (assinado, mas sem prova de quem), e o doctor e o
`ownership-check` dão WARN: só `G` conta como assinado e verificado.

### B4. A plataforma

```powershell
git clone https://github.com/Emmilymaciell/ai-project-os C:\AI-WORKSPACE\_platform\emmily-ai-project-os
cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os
.\scripts\bootstrap.ps1
& "$env:USERPROFILE\.local\bin\claude.exe" plugin marketplace add C:\AI-WORKSPACE\_platform\emmily-ai-project-os
& "$env:USERPROFILE\.local\bin\claude.exe" plugin install os@emmily-platform
```

O caminho importa: o bootstrap deduz a raiz do workspace subindo dois níveis. Ele também ativa os
hooks de Git.

### B5. A configuração da máquina

Crie `%USERPROFILE%\.emmily-os\machine.yaml`:

```yaml
machine:
  name: <nome-desta-maquina>
cloud:
  transport: rclone
vars:
  AI_WORKSPACE: 'C:\AI-WORKSPACE'
  GDRIVE_REMOTE: 'gdrive:'
  GDRIVE_ROOT: EMMILY PROJECT CLOUD
projects: {}
```

Se algum projeto ficar num caminho diferente do contrato, declare em `projects:`:

```yaml
projects:
  prog-relatorio-g2:
    local_path: 'D:\trabalho\PROG_Relatorio_G2_Automacao'
```

Confira a resolução: `py -3.13 -m eos resolve '${AI_WORKSPACE}'`. E o acesso ao Drive:
`py -3.13 -m eos status --sem-rede` (sem rede ele não consulta o GitHub, mas lê a nuvem).

### B6. Trazer os projetos

Para cada projeto, a forma mais completa é o restore verificado, que traz histórico, WIP e bancos.
Se o projeto tem pasta `cloud-mirror`, acrescente `--com-dados`: o restore também baixa o último
espelho verificado para `<destino>/<pasta>` e confere tamanho e md5 de cada arquivo:

```powershell
py -3.13 -m eos restore prog-relatorio-g2 --para "$env:USERPROFILE\PROG_Relatorio_G2_Automacao" --com-dados
```

O destino tem de estar vazio. Use o caminho que o contrato declara (`eos check <id>` mostra), ou
declare outro em `machine.yaml`. Com `--com-dados`, se não houver espelho verificado na nuvem ou se
algum arquivo baixado não bater, o restore sai `RESTORE COM FALHA` e diz qual pasta; arquivo que o
Git já trouxe com outro conteúdo nunca é sobrescrito.

Depois, em cada projeto restaurado:

- [ ] rodar o `bootstrap` declarado no contrato (cria `.venv`, instala dependências);
- [ ] recriar o `.env` a partir do cofre, seguindo o `.env.example`;
- [ ] conferir que as pastas `cloud-mirror` vieram (`[ok] dados '<pasta>': ...` na saída do
      restore); se restaurou sem `--com-dados`, restaure de novo numa pasta nova com a opção;
- [ ] `py -3.13 -m eos check <id>`.

### B7. Fechar a migração

- [ ] `py -3.13 -m eos status`: todos os projetos que estavam SAFE na antiga estão SAFE na nova.
- [ ] Um commit de teste assinado num projeto descartável aparece como **Verified** no GitHub.
- [ ] `py -3.13 -m eos certify <id>` nos projetos de criticidade alta.
- [ ] Copiar `machine.yaml` para o lugar seguro escolhido.
- [ ] Só agora: decidir o destino da máquina antiga (H3).

## Resumo em uma tabela

| Item | Copia | Recria | Restaura |
|---|---|---|---|
| projetos (histórico, WIP, bancos) | | | `eos restore` |
| dados `cloud-mirror` | `eos mirror <id>` na antiga | | `eos restore <id> --para <dir> --com-dados` na nova |
| plataforma | | | `git clone` |
| plugin `os` | | `plugin install` | |
| `machine.yaml` | conteúdo | ou do modelo | |
| logins `gh`, `rclone`, Claude, Bitwarden | | H1 | |
| chave de assinatura | **nunca** | nova + registro (H1) | |
| segredos `.env` | | do cofre | |
| `.venv`, `node_modules` | | bootstrap | |
