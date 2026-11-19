# 08 — Backup e recovery

## 1. Versionar não é fazer backup

| | Commit | Push | `eos backup` |
|---|---|---|---|
| Onde fica | só nesta máquina | GitHub privado | Google Drive (`99 RECOVERY/`) |
| Protege o histórico | sim, localmente | sim, fora da máquina | sim (bundle com todas as refs) |
| Protege trabalho não commitado (WIP) | não | não | **sim** |
| Protege banco SQLite | não | não | **sim** (snapshot) |
| Protege contra perder o GitHub | não | não | **sim** |
| Precisa do seu pedido | sim | sim | não: o Claude pode rodar sempre que fizer sentido |

O motor trata três necessidades com três artefatos diferentes:

| Necessidade | Artefato | Caminho no Drive |
|---|---|---|
| A. histórico Git | `git bundle --all`, verificado | `99 RECOVERY/git-recovery/<id>/<carimbo>/<id>.bundle` |
| B. WIP de todas as worktrees | `wip.tar.gz` (arquivos inteiros + patches + status) | `99 RECOVERY/wip-snapshots/<id>/<carimbo>/wip.tar.gz` |
| C. estado em banco | snapshot pela API de backup do SQLite, comprimido | `99 RECOVERY/database-snapshots/<id>/<carimbo>/<banco>.gz` |
| manifesto | JSON com refs, HEAD, hashes, impressões do WIP, pendências | `99 RECOVERY/manifests/<id>/<carimbo>.json` |

**O manifesto é gravado por último**, depois de cada artefato subir e ser conferido por hash (md5
do servidor pelo rclone, ou SHA-256 pelo Drive Desktop). Backup interrompido deixa artefato órfão
**sem manifesto**: lixo, nunca falsa proteção.

## 2. Fazer backup

```powershell
cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os
py -3.13 -m eos backup prog-cerebro-documental           # um projeto
py -3.13 -m eos backup conversor-utm exemplo-pessoal-a # vários
py -3.13 -m eos backup --todos                            # todos os PROJECT
```

Ou diga *"faça backup deste projeto"* / *"faça backup de tudo"*.

Saída esperada:

```
backup prog-cerebro-documental
  aviso: backup SEM criptografia no cliente (ADR-0013): ...
  manifesto 20261011T183857Z
```

Se aparecer `manifesto <carimbo> (INCOMPLETO)`, o backup existe mas algo não pôde ser protegido. As
pendências possíveis:

| Pendência | O que significa | O que fazer |
|---|---|---|
| `'x' tem nome de segredo e NAO foi enviado` | arquivo com nome de segredo no WIP, não ignorado | ignorar no `.gitignore` do projeto, ou declarar em `backup.exclude` |
| `'x' tem nome de segredo e esta no HISTORICO` | o nome já foi commitado; vai no bundle | sanitizar o histórico é decisão sua (H3); ver [12](12-SEGREDOS-E-BITWARDEN.md) |
| `n entrada(s) de stash` | stash não é protegido | aplicar o stash ou transformá-lo em branch |
| `repositorio aninhado/submodulo` | os commits dele não vão no bundle do pai | registrar o sub-repositório como projeto próprio |
| `symlink` | o restore recusa link | trocar por arquivo ou declarar |
| `banco declarado ... nao existe` | o contrato aponta um banco que sumiu | corrigir o contrato ou investigar |

### "Qual foi o último backup?"

```powershell
py -3.13 -m eos check <id> --json
```

O campo `dimensoes.backup.ultimo` traz o carimbo (UTC) do último manifesto, por exemplo
`20261011T183857Z` = 11/10/2026, 18:38 UTC = 15:38 em Brasília. A dimensão `backup` diz também se
ele ainda vale:

| Motivo | Significa |
|---|---|
| `bundle, WIP e bancos atuais na nuvem` | o último backup cobre o estado atual |
| `refs mudaram desde o ultimo bundle` | houve commit depois: rode o backup |
| `WIP de <pasta> nao esta no ultimo snapshot` | houve alteração depois: rode o backup |
| `banco <x> mudou depois do snapshot` | o banco mudou: rode o backup |
| `snapshot de <x> mais velho que Nh` | passou do prazo declarado em `max_age_hours` |
| `nenhum backup na nuvem` | nunca houve backup |

## 3. O que o backup **não** cobre, por desenho

| Não sobe | Por quê | Onde a proteção vem |
|---|---|---|
| arquivos ignorados pelo Git (`output/`, `data/`, `tmp/`) | podem ter GB e dado de terceiro | política de dados do contrato (`cloud-mirror`, `reproducible`, `external`, `none`); as pastas `cloud-mirror` sobem por **outro** comando, `eos mirror` (seção 4) |
| `.env` e qualquer arquivo com nome de segredo | o backup não é criptografado | o cofre (Bitwarden) e o `.env.example` com os nomes |
| `.venv`, `node_modules` | reconstruíveis | `environment.bootstrap` |
| stash | pode carregar `.env` não rastreado | transformar em branch |
| `COLLECTION` (acervos sem Git) | não são repositório | cópia conferida com `rclone check` para a pasta da categoria no Drive |

O motor nunca omite em silêncio: o que ele não protege vira pendência ou bloqueio no `eos check`.

**Limite declarado:** o backup vai **sem criptografia no cliente** para o seu Drive pessoal e
privado. A criptografia depende de uma senha de cofre que não pode morar no repositório: chega com
o Bitwarden. Cada backup repete esse aviso, e o manifesto registra `client_side_encryption: false`.

## 4. Espelhar os dados (`cloud-mirror`)

O backup protege o **projeto**. As pastas de dado que ficam fora do Git e que o contrato marca como
`cloud-mirror` (PDFs, planilhas, saídas grandes) têm um comando próprio:

```powershell
py -3.13 -m eos mirror prog-relatorio-g2            # um projeto
py -3.13 -m eos mirror --todos                      # todo PROJECT que tem alguma pasta cloud-mirror
```

Ou diga *"espelhe os dados deste projeto"*.

| O que faz | Como |
|---|---|
| destino | `<cloud.drive_root>/dados/<pasta>` no Drive, ex.: `01 PROG/prog-relatorio-g2/dados/output` |
| só acrescenta | nada é apagado na nuvem: arquivo que sumiu daqui continua lá |
| versão anterior preservada | arquivo alterado sobe por cima, mas a versão antiga vai **antes** para `<drive_root>/dados-anteriores/<carimbo>/<pasta>` |
| incremental | arquivo que já está lá com o mesmo tamanho e o mesmo md5 não sobe de novo |
| recusa | arquivo com nome de segredo (`.env`, `token.json`, chave…), arquivo de texto de até 2 MB cujo **conteúdo** tem credencial (token do GitHub, chave AWS/Google/Anthropic, chave privada PEM, token do Slack, token `Bearer` literal, `senha=`/`password=` com valor, string de conexão com senha ou `AccountKey`, URL com usuário e senha embutidos no formato `esquema://usuario:senha@servidor`), arquivo que o motor não deu para ler (bloqueado, sem permissão: falha fechada) e atalho (symlink, junção): não sobem, aparecem como `recusados` e continuam aparecendo como "só nesta pasta" |
| limite da varredura de conteúdo | a varredura lê texto UTF-8 e UTF-16 (com ou sem BOM). **Não** lê arquivo maior que 2 MB nem arquivo binário (xlsx, pdf, docx, imagem, banco): esses sobem sem varredura, porque o espelho existe justamente para eles. Credencial dentro de um binário ou de um texto grande **não** é detectada pelo espelho |
| decisão pendente | pasta marcada `decisao_pendente: true` no contrato (ex.: dado jurídico corporativo que você ainda não decidiu se vai à nuvem pessoal), de qualquer policy, **nunca sobe** — nem pelo espelho de uma pasta-mãe `cloud-mirror` (ela é excluída do inventário da mãe), nem como pasta `cloud-mirror` que esteja **dentro** dela. A saída diz `RECUSADO (decisao pendente): <pasta>` e o check acusa `dado com decisao pendente: <pasta>` até você decidir e tirar a marca. O comando sai com 1 quando há outras pastas espelhadas e com 2 quando **todas** as pastas `cloud-mirror` do projeto estão pendentes (nada a espelhar); no `--todos`, basta um projeto nessa situação para o comando inteiro sair com 2. Uma cópia antiga que já esteja na nuvem não conta como decisão. No `restore --com-dados`, a pasta pendente é pulada com `[ok] dados '<pasta>': decisao pendente, nao restaurado` (não reprova) — **só se o contrato atual também a marca pendente**: se você tirou a marca depois do último espelho (ou se o manifesto foi adulterado), a marca do manifesto sozinha não basta e o restore reprova com `sem copia verificada no espelho` |
| caminho inválido | `data[].path` inválido em **qualquer** entrada, de qualquer policy (absoluto, com unidade `C:`, `..`, `.`, componente vazio ou terminado em espaço/ponto, caractere de glob): a validação do contrato (`contract.validar`) recusa todas essas causas, e o registry descarta o contrato — o que você vê é o erro de registry. Como defesa em profundidade, se um contrato assim chegasse ao motor, o `mirror` pararia antes de enviar, o check contaria o motivo e o `restore --com-dados` recusaria antes de escrever, pelas causas estruturais (absoluto, unidade, `..`, `.`, componente vazio, espaço/ponto no fim; o glob só o contrato recusa). Nada é descartado em silêncio |
| confere | depois da cópia, cada arquivo na nuvem é comparado com o local por tamanho **e** md5; arquivo que mudou durante a cópia também reprova |
| registra | manifesto `99 RECOVERY/manifests/<id>/mirror-<carimbo>.json` e uma cópia no journal da máquina (`%LOCALAPPDATA%\emmily-os\mirror\<id>\`); o manifesto guarda só caminhos relativos ao projeto e o nome do computador, nunca o caminho completo da sua pasta — inclusive na mensagem de erro de uma pasta que falhou (a pasta do projeto vira `.` e a sua pasta de usuário vira `~`) |

Saída (formato real, números ilustrativos):

```
mirror prog-relatorio-g2
  output: 312 arquivo(s), 4 a enviar (1 substituido(s)), 18.2 MB
  output                                   ok
  enviados 4 | ja presentes 308 | substituidos 1 (anterior preservada) | recusados 0
  manifesto 99 RECOVERY/manifests/prog-relatorio-g2/mirror-20261012T150000Z.json
```

Se aparecer `-- FALHOU NA VERIFICACAO`, o manifesto foi gravado com `ok: false` e **não conta**:
pare de mexer na pasta e rode de novo. Código de saída: `0` tudo conferido; `1` algum espelho
reprovou; `2` erro (contrato sem `cloud.drive_root`, pasta local inexistente, Drive inacessível).

**Como isso entra no "posso apagar a pasta?"** O `eos check` não relê o Drive: ele compara a pasta
de hoje com o **último espelho verificado**. Cada arquivo tem de estar lá com o mesmo tamanho e a
mesma data de modificação. Arquivo novo ou alterado depois do espelho volta a bloquear, com o motivo
`'<pasta>': N arquivo(s) novo(s)/alterado(s) desde o espelho de <carimbo>`, até o próximo
`eos mirror`.

**O que o espelho não faz:** não entra na certificação (o `eos certify` **não** baixa os dados; ver
seção 6), não limpa `dados-anteriores/` (limpeza na nuvem é H3) e não criptografa (o mesmo limite
do backup).

## 5. Restaurar

```powershell
py -3.13 -m eos restore prog-relatorio-g2 --para C:\Temp\restauro-g2
py -3.13 -m eos restore prog-relatorio-g2 --para C:\Temp\restauro-g2 --fonte cloud
py -3.13 -m eos restore prog-relatorio-g2 --para C:\Temp\restauro-g2 --com-dados   # + pastas cloud-mirror
```

Ou diga *"restaure este projeto"* (ou *"restaure este projeto com os dados"*). O Claude escolhe uma
pasta **nova**.

| Regra | Por quê |
|---|---|
| o destino tem de estar **vazio ou não existir** | restore nunca escreve por cima de projeto: sobrescrever é H3 |
| todo artefato é conferido por SHA-256 antes de ser usado | o manifesto é tratado como dado não confiável |
| caminho, branch e sha são validados antes de qualquer escrita | nada pode escrever fora do destino nem dentro de `.git` |
| o resultado é verificado por fatos | refs, HEAD, impressão do WIP, `integrity_check` dos bancos |

Fontes do histórico:

| `--fonte` | Usa |
|---|---|
| `auto` (padrão) | clone do GitHub se houver remoto, completado pelo bundle para refs que o remoto não tem |
| `github` | só o clone do GitHub |
| `cloud` | só o bundle do Drive (use se o GitHub estiver indisponível) |

Saída:

```
  [ok] refs locais iguais ao manifesto
  [ok] HEAD restaurado = HEAD do manifesto
  [ok] impressao do WIP de 'main' igual a do manifesto
  [ok] banco data/lab.db: hash e integrity_check
RESTORE VERIFICADO em C:\Temp\restauro-g2
```

**Com `--com-dados`**, depois do Git, do WIP e dos bancos, o restore baixa o **último espelho
verificado** de cada pasta `cloud-mirror` para `<destino>/<pasta>` e confere tamanho e md5 de cada
arquivo, com uma linha a mais por pasta:

```
  [ok] dados 'output': tamanho e md5 iguais ao espelho de 20261012T150000Z
```

| Situação | Resultado |
|---|---|
| nunca houve `eos mirror` verificado | `[FALHOU]` "nenhum espelho de dados verificado na nuvem" |
| arquivo baixado com tamanho ou md5 diferente | `[FALHOU]`, com a lista |
| o Git/WIP já trouxe um arquivo com o **mesmo** conteúdo | não é baixado de novo |
| o Git/WIP já trouxe um arquivo com conteúdo **diferente** | **não** é sobrescrito: `[FALHOU]` com "conflitos"; você decide qual vale |

O restore traz os arquivos que o último espelho listou; arquivo apagado daqui **antes** desse
espelho continua no Drive (em `dados/`), mas não volta sozinho. Sem `--com-dados`, as pastas
`cloud-mirror` simplesmente não vêm.

Depois do restore, o projeto ainda precisa do ambiente: rode o `bootstrap` declarado no contrato
(ex.: `py -3.13 -m venv .venv` e a instalação de dependências) e recupere os segredos do cofre.

Para **substituir** uma pasta existente pelo conteúdo restaurado, a ordem é: restaurar em pasta nova
→ conferir → você aprova a troca (H3) → só então a pasta antiga é renomeada ou removida.

## 6. Certificar (provar que o restore funciona)

```powershell
py -3.13 -m eos certify prog-relatorio-g2
py -3.13 -m eos certify prog-relatorio-g2 --manter    # preserva a pasta temporária para inspeção
```

A certificação:

1. restaura o último backup numa pasta temporária isolada (`%TEMP%\eos-cert-<id>-<carimbo>`);
2. confere refs, HEAD, WIP e bancos;
3. confere que os arquivos canônicos (`ai.canonical`, ex.: `STATE.md`) existem no restaurado:
   *"contexto reconstruível sem a conversa"*;
4. roda o `environment.smoke_command` do contrato **no código restaurado**;
5. grava o certificado em `99 RECOVERY/manifests/<id>/cert-<carimbo>.json`, **redigido**: a pasta do
   usuário vira `~` e a pasta temporária vira `%TEMP%` em todo o certificado (inclusive nas chaves, na
   cauda da saída do smoke e na mensagem de erro, redigidas **antes** de serem cortadas). A tela
   mostra as verificações, o nível e o erro **também redigido**; o caminho real da pasta temporária fica
   só no resultado devolvido a quem chamou o motor em Python (o CLI não o imprime);
6. apaga só a pasta temporária que ela mesma criou.

```
  [ok] refs locais iguais ao manifesto
  [ok] contexto reconstruivel sem a conversa (arquivos canonicos no restore)
  [ok] smoke/test no restore
CERTIFICACAO APROVADA - nivel agora: L6
```

Sem `smoke_command` declarado, a certificação **reprova**: não existe "certificado porque parece
certo". A certificação vale **30 dias**; depois disso a dimensão `recovery` cai para WARN e o projeto
volta a L5 até ser recertificado.

A certificação **não baixa** as pastas `cloud-mirror`: ela prova a recuperação do projeto, não do
dado bruto (que pode ter centenas de MB). Para provar o dado, use `eos restore <id> --para <pasta
nova> --com-dados`.

## 7. Recuperação de desastre: cenários

| Aconteceu | O que fazer | Comando |
|---|---|---|
| perdi o chat / a sessão | nada se perde: abra uma sessão nova | `/session-start` na pasta do projeto |
| apaguei ou corrompi a pasta do projeto | restaurar em pasta nova | `eos restore <id> --para <pasta>` (com `--com-dados` se o projeto tem pasta `cloud-mirror`) |
| apaguei ou estraguei um arquivo de dados | versão do último espelho: restaurar com dados em pasta nova e copiar o arquivo conferido; versão mais antiga: buscar em `dados-anteriores/<carimbo>/` no Drive (o motor não restaura dali) | `eos restore <id> --para <pasta nova> --com-dados` |
| o computador morreu | máquina nova, logins, plataforma, restore | ver [09](09-TROCA-DE-COMPUTADOR.md) |
| perdi o acesso ao GitHub | restaurar só do Drive | `eos restore <id> --para <pasta> --fonte cloud` |
| o rclone parou de funcionar | trocar o transporte para o app Google Drive para desktop | ver abaixo |
| o Drive Desktop não está instalado e o rclone parou | `rclone config reconnect gdrive:` (H1) ou instalar o Drive Desktop | — |
| um banco SQLite corrompeu | restaurar em pasta nova e copiar o banco conferido | `eos restore` e comparar |
| um segredo vazou | H5: rotacionar na origem antes de qualquer outra coisa | ver [12](12-SEGREDOS-E-BITWARDEN.md) |

### Trocar o transporte da nuvem

O Drive é um **serviço lógico**, não uma letra de unidade. Há dois transportes que leem e escrevem a
mesma raiz `EMMILY PROJECT CLOUD/`:

| Transporte | Quando | Configuração em `%USERPROFILE%\.emmily-os\machine.yaml` |
|---|---|---|
| `rclone` (padrão) | sempre que funcionar: dá hash do servidor e não depende de app | `cloud:` → `transport: rclone` |
| `drive-desktop` | reserva, se o rclone parar | `cloud:` → `transport: drive-desktop` (a pasta `Meu Drive`/`My Drive` é **procurada** nas unidades; pode-se fixar com `mount:`) |

Provado em 2026-10-08: o backup do Portability Lab foi gravado pelo rclone e restaurado pelo Drive
Desktop, só a partir da nuvem.

**Client OAuth próprio (desde 2026-10-16).** O remoto `gdrive:` usa o client do seu projeto Google
Cloud `emmily-os-rclone` (app `Emmily OS rclone`, *In production*), e não mais o `client_id`
compartilhado do rclone, que seria desligado em 2026. O nome do remoto não mudou, então nada no
motor nem no `machine.yaml` mudou. Client ID e secret ficam só no Bitwarden (item
`rclone-gdrive-oauth-client`) e no `rclone.conf`. Leitura, escrita, backup, restore (certify L6) e
espelho foram testados assim, sem o aviso. Se o aviso `shared Google Drive client_id` voltar a
aparecer, o remoto foi recriado sem o client: ver [15](15-TROUBLESHOOTING.md). Verificação
pendente: em 2026-10-23 ou depois, `rclone about gdrive:` deve responder sem pedir login. Máquina
nova: [09](09-TROCA-DE-COMPUTADOR.md), B2.

## 8. Limpeza de backups antigos

O motor **não tem** comando que apague nada na nuvem (não existe `sync`, `delete`, `purge` ou
`move` nele, e há teste que garante isso). Isso vale também para o espelho de dados: `dados/` e
`dados-anteriores/` só crescem. Limpar backup antigo é sempre gate **H3**: o Claude monta
a lista de candidatos com tamanho, cópia protegida, última certificação, risco e caminho de volta, e
espera sua aprovação explícita.
