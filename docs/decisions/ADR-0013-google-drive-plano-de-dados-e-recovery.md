# ADR-0013 — Google Drive como plano de dados e recovery; transporte por API, com o Drive Desktop como segundo caminho

- **Data:** 2026-10-08
- **Status:** Aceita — provada no Portability Lab (`emmily-portability-lab`, certificado L6 em 2026-10-08)
- **Estende:** ADR-0003 (o remoto do GitHub continua sendo o backup do conteúdo **versionado**; este
  ADR cobre o que o GitHub não cobre). **Substitui** a menção a `OneDrive\AI-ARCHIVE` como lugar de
  backup de dados.

## Contexto

O GitHub protege commits. Não protege trabalho não commitado, worktrees sujas, bancos SQLite,
saídas e dados ignorados (ADR-0003, tabela "não protegido"). Em 2026-10-08 isso era a maior parte
do risco medido: 6 árvores sujas, um repositório sem nenhum commit, 1,2 GB de bancos com cópia
única.

A mantenedora tem 5 TB no Google Drive pessoal e designou-o, no programa vNext, como plano de dados
e de recovery. Na máquina havia, verificado e não suposto: `rclone` 1.75.1 com o remote `gdrive:`
autenticado, e o Google Drive Desktop montado em `H:\Meu Drive`.

## Decisão

1. **Raiz lógica `EMMILY PROJECT CLOUD/`**, com `00 PLATFORM`, `01 PROG`, `02 PERSONAL`,
   `03 UNIVERSITY`, `04 PORTFOLIO`, `05 LAB` e `99 RECOVERY/{git-recovery, wip-snapshots,
   database-snapshots, manifests, disaster-recovery, emergency-preservation}`.
2. **O Drive é um serviço lógico, não uma letra.** O motor (`eos/cloud.py`) tem uma interface e dois
   transportes:
   - **`rclone` (padrão):** API do Drive. Funciona sem o app desktop, numa máquina recém-formatada,
     e dá hash md5 do lado do servidor para conferir cada upload.
   - **`drive-desktop`:** diretório montado, **descoberto** procurando `Meu Drive`/`My Drive` nas
     unidades. É o caminho de reserva se o rclone parar.

   Os dois leem e escrevem a mesma raiz lógica. **Provado:** o backup do Lab foi gravado pelo
   rclone e restaurado pelo Drive Desktop, só a partir da nuvem, com todas as verificações ok.
3. **Nenhuma working tree Git ativa dentro de pasta sincronizada.** O Drive guarda bundle, tarball
   de WIP e snapshot de banco, que são arquivos únicos e imutáveis. A exceção já registrada do
   ADR-0002 (Organizador no OneDrive) continua valendo e não se estende ao Drive.
4. **Upload só conta depois de conferido.** Cada artefato é comparado por hash depois de subir
   (md5 do servidor no rclone, sha256 no diretório), e o manifesto (`manifests/<id>/<ts>.json`)
   é gravado **por último**: backup sem manifesto não existe.
5. **O motor não tem verbo destrutivo de nuvem.** Nada de `sync`, `delete`, `purge` ou `move`. Há
   guarda em teste (`eos/tests/test_guardas.py`). Limpeza de backup antigo é gate H3.
6. **WIP vai num arquivo só** (`wip.tar.gz`), não arquivo por arquivo. Medido: subir 449 arquivos
   soltos na preservação emergencial levou cerca de 28 minutos, por causa do custo de criação por
   objeto no Drive.

## Riscos aceitos, com gatilho

- **O rclone usa o `client_id` compartilhado do próprio rclone**, que ele avisa que "será retirado e
  deixará de funcionar durante 2026". Mitigação imediata: o transporte `drive-desktop` está provado.
  Correção definitiva: criar um `client_id` OAuth próprio (Google Cloud Console) e refazer o
  `rclone config`. É ação da mantenedora (gates H1/H2), e **também** resolve a pendência T-09 do
  projeto Organização SharePoint (o `refresh_token` do rclone apareceu num log temporário em 01/10),
  porque o novo login rotaciona o token.
  > **Resolvido em 2026-10-16** — ver *Emenda de 2026-10-16* no fim deste ADR. O texto acima fica
  > como registro do risco na data da decisão.
- **Os backups não são criptografados no cliente.** Vão para o Drive pessoal e privado da
  mantenedora. O que impede um segredo de ir junto é verificado **pelo motor**, não suposto:
  - arquivo ignorado pelo projeto nunca entra no WIP;
  - arquivo **não** ignorado cujo nome tem cara de segredo **não sobe**, nem inteiro nem dentro
    dos patches de WIP, que são gerados com pathspec excluindo cada um deles (r2 do security).
    A regra é **única**, usada pelo WIP, pelo L4 e pelo check (`gitinfo.nome_de_segredo`). Ela
    olha só o nome do arquivo, em duas famílias:
    - **dura**, sem exceção: `.env*`, `.envrc`, chaves SSH, `*.pem`, `*.key`, `*.pfx`, `*.ppk`,
      `*.jks`, `rclone.conf`, `.npmrc`, `.pypirc`, perfis de navegador;
    - **da palavra**: `secret`, `token`, `credential`, `senha`, `password`, `api_key` e `cookie`
      como palavra, não como pedaço (`Secretaria/` e `tokenizer.py` não casam), **em qualquer
      extensão**, inclusive código e documentação.

    A r4 tinha relaxado a palavra em código e documentação (só contava `secrets.py`, não
    `secrets_prod.py`), e isso deixava subir `.env.ps1`. A r5 voltou à regra estrita. O falso
    positivo (política, decisão ou teste **sobre** segredo) sai só por **caminho exato** declarado
    em `secrets.allowed_paths` do contrato, depois de uma conferência **humana** do conteúdo (o motor não lê o arquivo declarado; backlog 147). A validação do contrato
    recusa ali `.env`, chave, curinga e caminho fora do projeto.

    O backup fica `incompleto`, com o nome em `pendencias`, e o check reprova `secrets` até
    alguém decidir: ignorar no projeto ou declarar em `backup.exclude`. Declarar em
    `backup.exclude` **não** libera o "posso apagar a pasta": o arquivo não sobe e continua
    existindo só ali (ADR-0014).
  - `refs/stash` fica fora do bundle: um `stash -u` pode carregar o conteúdo de um `.env` não
    rastreado.
  - **O que já foi COMMITADO vai no bundle**, porque o bundle é o histórico. O motor não esconde
    isso: todo caminho com nome de segredo em qualquer commit alcançável vira pendência do backup
    e reprova a dimensão `secrets`. Tirar do histórico é sanitização, e a decisão é humana
    (ADR-0015). A busca inclui o diff dos commits de merge (`-m`) e exclui `refs/stash`, que o
    bundle não leva.

    Consequência declarada (r4 do QA): enquanto o histórico tiver o nome, o projeto fica abaixo de
    L4, e "trocar de computador" e L6 não dão SIM. Não há exceção por "valor já rotacionado": a
    saída é sanitizar, ou o caminho exato em `secrets.allowed_paths` quando o arquivo nunca foi
    segredo.
  - O ambiente `GIT_*` herdado é descartado, e a configuração de diff da usuária é fixada pelo
    motor. Assim `GIT_LITERAL_PATHSPECS` não desarma a exclusão de segredo do patch, e
    `diff.noprefix` não torna o patch inaplicável.

    O custo também está declarado (r4 do security): `GIT_SSL_CAINFO` (CA corporativa),
    `GIT_CONFIG_GLOBAL` e `GIT_EXEC_PATH` deixam de valer dentro do motor. As três falham fechado
    (`ls-remote`/`clone` dão erro, nunca verde falso). Numa rede com inspeção TLS, a CA vai para
    `http.sslCAInfo` na config global, não para variável de ambiente.

  O limite está declarado: um segredo **dentro** de um arquivo de nome inocente (`config.json`, por
  exemplo) não é detectado pelo nome. A versão anterior deste item dizia que "o motor nunca inclui
  `.env`", o que só valia para `.env` ignorado. O `security-reviewer` apontou isso na r1 do motor.

  Criptografia (`rclone crypt` ou equivalente) exige uma senha de cofre que não pode morar no
  repositório nem na máquina em texto puro. Por isso depende do Bitwarden, ainda não instalado.
  Gatilho: a fase de segredos (Bitwarden CLI). Até lá, o aviso **sai de fato** em cada backup: no
  log (`aviso: backup SEM criptografia no cliente`) e no manifesto
  (`client_side_encryption: false`).
- **Integridade da nuvem é execução de código.** O manifesto não é assinado. Quem escreve em
  `99 RECOVERY` controla manifesto e hash ao mesmo tempo, e a certificação roda o `smoke_command`
  sobre o código restaurado. O restore trata todo campo do manifesto como dado não confiável (r1 do
  security): valida caminho, rótulo, branch e sha antes de qualquer escrita, confere a contenção
  por `realpath` e recusa qualquer componente `.git`. A recusa do `.git` entrou depois que a
  pré-revisão adversarial provou que um hook gravado ali era executado pelo próprio `worktree add`
  do restore. Na r4 ela era só léxica, e a revisão formal mostrou que `GIT~1`, o nome curto 8.3
  do `.git` (ativo no C: desta máquina), passava. O caso da r5 provou por execução que o hook
  rodava. Desde a r5, a recusa vale em duas camadas:
  - no texto: `.git` com qualquer caixa, com ponto ou espaço no fim, e `git~N`, a mesma lista do
    `core.protectNTFS` do Git;
  - no caminho que o SO de fato abre: os componentes de `relpath(realpath(alvo), destino)`, o
    que pega o hash 8.3 de colisão e qualquer outro alias.

  Isso fecha a **escrita fora do destino**, mas não a execução: quem altera o
  bundle no Drive altera o que a certificação executa. Aceito enquanto o Drive for pessoal e
  privado. Gatilho para assinar o manifesto: qualquer acesso de terceiro a `99 RECOVERY`.

## Alternativas consideradas

- **Só Drive Desktop.** Rejeitada como padrão: depende de app e login interativo na máquina nova,
  não dá hash do servidor, e a sincronização é assíncrona (arquivo "copiado" ainda pode não ter
  subido).
- **restic.** Não instalado, e traria um repositório opaco que só o restic lê. Deduplicação não
  compensa no volume atual (cerca de 1,4 GB). Reavaliar se o volume de snapshots crescer.
- **OneDrive pessoal (ADR-0003 original).** Rejeitada pela mantenedora no programa vNext. O OneDrive
  corporativo é fonte operacional (SharePoint), nunca backup.

## Emenda de 2026-10-16 — client OAuth próprio do rclone

O risco do `client_id` compartilhado foi **eliminado** por decisão da titular (2026-10-16; journal
`RUN-20261008-001/SURGE/decisoes-20261016.md`, item 4). O texto original acima não foi reescrito.

- **O que existe agora:** projeto Google Cloud `emmily-os-rclone`, app OAuth `Emmily OS rclone`,
  client do tipo *Desktop app*, escopo `drive`, status **In production** (em *Testing* o Google
  expira a autorização em cerca de 7 dias). Homepage e política de privacidade públicas em
  `https://emmilymaciell.github.io/emmily-os-oauth-pages/`, exceção pública nomeada no ADR-0019.
- **Onde vivem os valores:** Client ID e Client secret **só** no Bitwarden (item
  `rclone-gdrive-oauth-client`: Username = Client ID, Password = Client secret) e no `rclone.conf`
  local. Nunca no Git, em doc, no chat ou no OneDrive.
- **O nome do remoto não mudou:** continua `gdrive:`. Código (`eos/paths.py`, `eos/cloud.py`) e
  `machine.yaml` ficaram intocados. O remoto antigo, renomeado `gdrive-legacy` durante a migração,
  foi **removido** depois da certificação.
- **Provado sem o aviso do client compartilhado:** leitura (`about`, `lsf`), escrita controlada com
  conferência de hash em `05 LAB/`, `eos backup` + `eos certify` (restore) L6 do `lab-prova-eos-new` e
  `eos mirror` do GF. Evidência: `RUN-20261008-001/CHECKPOINTS/rclone-own-*`.
- **Rollback:** cópia da config anterior, com tokens, em `~\.emmily-os\rclone.conf.bak-20261016` —
  local, fora do Git e do OneDrive. É segredo.
- **T-09:** o login novo gerou token novo, e o token antigo saiu do `rclone.conf`. Apagar o remoto
  local não revoga o token antigo no servidor do Google.
- **Verificação residual:** em **2026-10-23 ou depois**, `rclone about gdrive:` tem de responder sem
  pedir login (prova de que o token não expira em 7 dias).
- **Máquina nova:** recriar o remoto `gdrive` com o client lido do Bitwarden
  (`docs/runbooks/maquina-nova.md`, passo 6). A tela "Google hasn't verified this app" é esperada:
  *Advanced* → *Go to Emmily OS rclone (unsafe)* → *Continue*.
- O transporte `drive-desktop` continua sendo a reserva provada.
- Fica em aberto, e não é risco do client: o `rclone.conf` está em texto puro. Criptografá-lo
  (`rclone config encryption set`, senha no Bitwarden) é opcional e faria a automação depender do
  `bw` desbloqueado.
