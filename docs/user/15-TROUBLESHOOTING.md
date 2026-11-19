# 15 — Troubleshooting

Formato: **sintoma → causa → o que fazer**. Na dúvida, diga ao Claude o sintoma exatamente como
apareceu; ele roda o diagnóstico (`eos check`, `/os:doctor`) antes de propor qualquer coisa.

## 1. Motor (`py -3.13 -m eos`)

| Sintoma | Causa | O que fazer |
|---|---|---|
| `ERRO: o motor exige Python 3.12+ (use py -3.13)` | rodou com `python` ou `py` de versão antiga | use `py -3.13 -m eos ...` |
| `No module named eos` | rodou fora da raiz da plataforma | `cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os` antes |
| `ERRO: ...` e código de saída `2` | erro de uso (id errado, falta `--para`) ou de execução | confira o id com `eos status`; leia a mensagem |
| `KeyError` / id não encontrado | o id não existe no registry | `py -3.13 -m eos status` lista os ids |
| `variavel ${X} sem valor nesta maquina (defina em ...machine.yaml)` | `${VAR}` sem valor nesta máquina | declare em `%USERPROFILE%\.emmily-os\machine.yaml` → `vars:`; confira com `eos resolve '${AI_WORKSPACE}'` |
| `git: FAIL caminho local nao existe nesta maquina` | o projeto está em outro caminho, ou não existe aqui | declarar o caminho em `machine.yaml` → `projects.<id>.local_path`, ou restaurar |
| `eos validate` com `campo desconhecido` | erro de digitação no contrato | corrigir o nome do campo (a validação falha fechado de propósito) |
| `uso: restore <id> --para <diretorio vazio>` | faltou o destino | informe uma pasta nova |
| restore recusa o destino | a pasta tem conteúdo | escolha uma pasta nova; sobrescrever é H3 |
| `ownership-init`: `pasta local de <id> nao existe nesta maquina` ou `nao e a raiz de um repositorio Git` | o caminho resolvido (override do `machine.yaml` ou `local_path` do contrato) está errado, ou aponta para uma subpasta | corrigir `projects.<id>.local_path` no `machine.yaml` ou restaurar o projeto; o comando nunca cria a pasta |
| `eos new` para com `varredura de seguranca acusou achado ALTA/MEDIA` | a varredura antes da publicação achou possível segredo ou dado sensível | ler o relatório em `%TEMP%\emmily-os-scan\`; nada foi criado no GitHub; resolver e rodar o mesmo comando |
| `eos new` recusa: `destino ... esta dentro de pasta sincronizada` | a pasta-base cai dentro de OneDrive, Google Drive, Dropbox ou biblioteca SharePoint sincronizada | corrigir `AI_WORKSPACE` no `machine.yaml`; projeto novo nasce fora de pasta sincronizada |

### Espelho de dados (`eos mirror`, `restore --com-dados`)

| Sintoma | Causa | O que fazer |
|---|---|---|
| `uso: mirror <id>... \| --todos` (saída `2`) | sem id, id desconhecido, ou `--todos` sem nenhum projeto com `cloud-mirror` | conferir o id com `eos status` |
| `ERRO: <id>: nenhum data[] com policy cloud-mirror` | o contrato não declara pasta `cloud-mirror` | nada a espelhar; se a pasta precisa de cópia, declarar a política no contrato |
| `ERRO: <id>: cloud.drive_root nao declarado` | o contrato não diz onde fica a pasta do projeto no Drive | declarar `cloud.drive_root` (ex.: `01 PROG/<id>`); nada foi copiado |
| `ERRO: <id>: caminho local nao existe nesta maquina` | a pasta do projeto não está aqui | conferir `machine.yaml` ou o contrato |
| `recusado (nome de segredo): <arquivo>` ou `recusado (symlink): ...` | arquivo com nome de segredo ou atalho dentro da pasta de dados | não sobe por desenho; segredo vai para o cofre, atalho vira arquivo de verdade. Enquanto existir, o check acusa a pasta |
| `FALHOU <pasta>: n arquivo(s) com tamanho/md5 diferente na nuvem` | a cópia não conferiu | rodar `eos mirror <id>` de novo; se persistir, conferir o Drive (`rclone check`) |
| `FALHOU <pasta>: n arquivo(s) mudaram durante o espelho` | algo escreveu na pasta enquanto ela era copiada | fechar o programa que usa os dados e rodar de novo |
| `-- FALHOU NA VERIFICACAO` | o manifesto foi gravado com `ok: false` | não conta para nada; corrigir a causa acima e rodar de novo |
| *Posso apagar a pasta?* NÃO com `'<pasta>': n arquivo(s) novo(s)/alterado(s) desde o espelho` | a pasta mudou depois do último espelho aprovado | `eos mirror <id>` |
| `[FALHOU] dados cloud-mirror no restore` com `nenhum espelho de dados verificado na nuvem` | `--com-dados` num projeto que nunca teve `eos mirror` aprovado | espelhar primeiro (na máquina que tem os dados) |
| `[FALHOU] dados '<pasta>': ...` com `conflitos` | o Git/WIP já trouxe esses arquivos com outro conteúdo; nada foi sobrescrito | decidir qual versão vale (o arquivo restaurado pelo Git, ou o do espelho em `<drive_root>/dados/`) |

## 2. Nuvem (Google Drive / rclone)

| Sintoma | Causa | O que fazer |
|---|---|---|
| `NOTICE: ... shared Google Drive client_id, which is being retired` | **não deve mais aparecer** desde 2026-10-16: o remoto `gdrive` usa o client OAuth próprio. Se aparecer, o remoto foi recriado sem `client_id`/`client_secret` | recrie o `gdrive` com o client do Bitwarden (`rclone-gdrive-oauth-client`), como em [09](09-TROCA-DE-COMPUTADOR.md) B2; confira com `rclone about gdrive:` |
| "Google hasn't verified this app" no navegador, ao autorizar o rclone | esperado: o app `Emmily OS rclone` é pessoal e não passou por verificação do Google | **Advanced** → **Go to Emmily OS rclone (unsafe)** → **Continue** |
| `backup: UNKNOWN nuvem indisponivel` | sem internet, token expirado, ou rclone parou | `rclone lsf "gdrive:EMMILY PROJECT CLOUD/"`; se pedir login: `rclone config reconnect gdrive:` (H1) |
| rclone deixou de funcionar de vez | token revogado, ou o app OAuth voltou a *Testing* (lá a autorização expira em ~7 dias) | `rclone config reconnect gdrive:` (H1) e confira no Google Cloud (`emmily-os-rclone` → *Audience*) que o app está *In production*; enquanto isso, troque o transporte: `machine.yaml` → `cloud:` → `transport: drive-desktop` (exige o app Google Drive para desktop logado) |
| `Drive Desktop nao encontrado em nenhuma unidade` | o app não está instalado ou não montou `Meu Drive` | instale/abra o app, ou declare `mount:` em `machine.yaml` |
| backup lento | muitos arquivos pequenos | normal no primeiro backup grande; o WIP já vai num arquivo só |

## 3. GitHub

| Sintoma | Causa | O que fazer |
|---|---|---|
| `remote: UNKNOWN visibilidade do remoto nao confirmada pela API` | `gh` sem login, ou fora do PATH | `gh auth status`; se precisar, `gh auth login` (H1). O `gh` fica em `C:\Program Files\GitHub CLI\gh.exe` |
| `remote: UNKNOWN ls-remote falhou` | sem rede, sem permissão, ou repositório renomeado | confira a URL do contrato e o acesso: `git ls-remote <url>` |
| `remote: FAIL remoto PUBLICO` | o repositório ficou público | **incidente**: avise o Claude; tornar privado de novo é imediato, e a exposição é avaliada (H5) |
| `n ref(s) local(is) nao publicada(s)` | branches ou tags que só existem aqui | *"manda pro GitHub"* (push de tudo). Exceção: `refs/preservado/*` nunca aparece aqui e nunca é publicada; protege conteúdo que não pode ir ao GitHub e viaja só no bundle do backup |
| `origin aponta para X, o contrato declara Y` | remoto trocado ou contrato desatualizado | decidir qual está certo (H4) e alinhar |
| `remoto(s) alem de origin nao declarado(s)` | há outro remoto configurado | remover o extra ou declarar no contrato |
| `gh repo create` negado | a permissão do ambiente bloqueou | gate H2: aprovar; nada é contornado |
| commit aparece como **Unverified** no GitHub | a chave pública de assinatura não está registrada no GitHub | `gh auth refresh -h github.com -s admin:ssh_signing_key` e `gh ssh-key add <chave.pub> --type signing` (H1) |
| doctor ou `ownership-check` com WARN `%G?=U` | o commit está assinado, mas a chave não está no `gpg.ssh.allowedSignersFile` desta máquina | acrescentar a linha `<e-mail> <chave .pub>` no arquivo de signatários; só `G` conta como verificado |
| `ownership-check` com FAIL `assinatura invalida/revogada (%G?=B/R)` | algum commit do histórico tem assinatura quebrada ou de chave revogada | investigar os shas listados antes de qualquer certificação; é contradição, não aviso |

## 4. Backup, nível e as três respostas

| Sintoma | Causa | O que fazer |
|---|---|---|
| `refs mudaram desde o ultimo bundle` | houve commit depois do backup | `eos backup <id>` |
| `WIP de X nao esta no ultimo snapshot` | houve alteração depois do backup | `eos backup <id>` |
| `banco X mudou depois do snapshot` | o banco foi usado depois do backup | `eos backup <id>` |
| `n entrada(s) de stash: o motor nao protege stash` | há stash | *"transforma o stash em branch"* (ou aplicar); depois backup |
| `manifesto ... (INCOMPLETO)` | algo não pôde subir | ler as pendências na saída ou no manifesto; ver [08](08-BACKUP-E-RECOVERY.md) |
| `HEAD da worktree X nao esta no ultimo bundle` | uma worktree tem commits novos | `eos backup <id>` |
| `submodulo/repositorio embutido` | há um repositório dentro do projeto | registrar o sub-repositório como projeto próprio |
| `arquivo de segredo RASTREADO` | um `.env` ou chave entrou no Git | **H5**: rotacionar; depois sanitizar (H3) |
| `nome de segredo no HISTORICO` | o nome já foi commitado alguma vez | sanitização (H3) ou, se nunca foi segredo, `secrets.allowed_paths` com conferência humana |
| `nome de segredo no WIP nao ignorado` | arquivo novo com nome de segredo | ignorar no `.gitignore` ou declarar em `backup.exclude` |
| `caminho fixo de maquina no contrato` | `local_path` sem variável | trocar para `${AI_WORKSPACE}\...` ou `${USERPROFILE}\...` |
| `STATE.md mais velho que o ultimo commit por mais de 1 dia` | o STATE não acompanhou o código | atualizar o STATE (o `/session-close` e o `/os:checkpoint` fazem) |
| `certificacao com mais de 30 dias` | L6 venceu | `eos certify <id>` |
| `smoke/test no restore` FALHOU na certificação | o teste não roda num clone limpo (dependência não declarada, dado local) | rodar com `--manter`, inspecionar a pasta temporária, declarar o que falta |
| `environment.smoke_command nao declarado` | o contrato não tem comando de smoke | declarar no contrato; sem ele não há L6 |
| *Posso apagar a pasta local?* NÃO com `item(ns) ignorado(s) pelo Git e nao declarado(s)` | pastas ignoradas que o contrato não explica | o Claude propõe a política de cada uma (`cloud-mirror`, `reproducible`, `external`, `none`) |
| *Posso apagar a pasta local?* NÃO com `segredos com valor so nesta pasta` | projeto `local-env` com `.env` | levar os valores para o cofre ([12](12-SEGREDOS-E-BITWARDEN.md)) |
| `Operacao: DEGRADED` com `fonte externa indisponivel` | SharePoint fora | nada a fazer para segurança; o projeto continua SAFE |

## 5. Claude Code e plugin

| Sintoma | Causa | O que fazer |
|---|---|---|
| `/os:status` não existe | plugin não instalado | `claude plugin install os@emmily-platform` (ver `docs/SETUP.md`) |
| a skill não reflete uma mudança feita no repositório | o plugin instalado é **cópia congelada** | subir o `version` em `.claude-plugin/plugin.json` e `claude plugin update os`; ou `uninstall` + `install` |
| `claude plugin update os` diz `already at the latest version` e nada muda | não houve bump de versão | `claude plugin uninstall os` e `claude plugin install os@emmily-platform` |
| `Failed to authenticate: OAuth session expired` | a sessão OAuth do CLI expirou | `/login` (H1). Sem isso os revisores de QA e Security não rodam |
| um comando git do Claude foi barrado com o motivo do guarda | o hook `PreToolUse` do plugin `os` 0.1.4 (`hooks/guarda_git.py`) bloqueia git destrutivo emitido por agente | rode você mesma (`! git ...` no prompt, ou num terminal); não peça ao Claude para contornar. Ver `docs/runbooks/hooks.md` |
| `claude` não encontrado no terminal | o CLI fica em `~\.local\bin\claude.exe`, fora do PATH | use o caminho completo |
| o Claude "esqueceu" o que foi feito | a conversa é descartável | `/session-start`: o estado está no repositório. Se não estiver, é defeito a registrar |

## 6. Git e hooks

| Sintoma | Causa | O que fazer |
|---|---|---|
| commit barrado pelo `commit-msg` | assunto vazio, sem linha em branco depois do assunto, ou assunto > 100 caracteres | ajustar a mensagem |
| commit barrado pelo `pre-commit` | a varredura rápida achou possível segredo | ler `artifacts/hooks/pre-commit-security.md`; **não** usar `--no-verify`. Se for falso positivo deliberado, registrar exceção (ADR-0010) |
| push barrado pelo `pre-push` | faltam as verificações declaradas ou houve achado | ler `artifacts/hooks/pre-push-*.md` |
| hook sai com `2` | não conseguiu verificar | "não verifiquei" bloqueia; rode de novo ou investigue a causa |
| `fatal: ambiguous argument 'HEAD'` | repositório sem nenhum commit | esperado num projeto recém-criado sem commit; não é defeito |
| aviso `CRLF will be replaced by LF` derruba um script | aviso do Git em stderr no PowerShell 5.1 | ver `docs/runbooks/gotchas-windows-powershell.md` |
| arquivo travado, "em uso" | OneDrive sincronizando | pausar a sincronização; nunca manter repositório ativo em pasta sincronizada |
| acentos corrompidos depois de editar por script | leitura sem `-Encoding` no PowerShell 5.1 | ver o runbook de armadilhas |

## 7. Projetos e sessões

| Sintoma | Causa | O que fazer |
|---|---|---|
| o briefing mostra "INCONSISTÊNCIAS ENCONTRADAS" | STATE e Git divergem | decidir qual vale; o Claude não corrige em silêncio |
| `/os:doctor` sai `INCONCLUSIVO` | uma dimensão não pôde ser verificada | ler a seção "O que NÃO foi verificado"; corrigir a causa (ex.: placeholder no `project.yaml`) |
| `artifacts/` vazio num clone novo | `artifacts/` é ignorado pelo Git e não viaja | esperado; não é defeito |
| máquina lenta ou sem memória durante certificação | tarefas pesadas em paralelo | uma certificação ou suíte completa por vez |

## 8. Códigos de saída

| Código | Motor `eos` | Hooks e `doctor.ps1` |
|---|---|---|
| `0` | ok | passou (PASS ou WARN) |
| `1` | verificação reprovou ou algo não é seguro | reprovou |
| `2` | erro de uso ou de execução | não conseguiu verificar (INCONCLUSIVO), e isso também bloqueia |

## 9. Quando nada disso resolve

1. *"Rode o diagnóstico completo deste projeto"* → `eos check <id>` + `/os:doctor`.
2. Se houver risco de perda: *"faça backup antes de qualquer coisa"* → `eos backup <id>`.
3. Se for preciso desfazer algo: restaurar em pasta **nova** e comparar; nunca por cima.
4. Registrar a armadilha nova em `docs/runbooks/` para que ela não custe tempo de novo.
