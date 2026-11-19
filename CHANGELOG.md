# CHANGELOG

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Semantic Versioning (`MAJOR.MINOR.PATCH`). Tag só depois de validação ponta a ponta — ver ADR-0006.

## [Unreleased] — programa vNext, 2026-10-16

- rclone com client OAuth próprio (projeto `emmily-os-rclone`, app *In production*); remoto `gdrive:` inalterado;
  documentado no ADR-0013 (emenda), nos manuais 08/09/12/15, no runbook de máquina nova e no SETUP. ADR-0019:
  exceção pública das páginas do app OAuth.
- Guarda `PreToolUse` contra git destrutivo emitido por agentes (`hooks/guarda_git.py`, plugin `0.1.4`, PATCH entre tags pela
  emenda do ADR-0006); revisões r14–r18; ativo desde 2026-10-16 (integração na `main` + `claude plugin update`; teste ao vivo).
- Registradas as decisões da titular de 2026-10-16 (Escritório Jurídico mantido no Drive, SWITCH do GF, Fase 9 pelo H2,
  evidência externa da engenharia-rodoviaria) no `docs/STATE.md`.

## [Não lançado] — Fase 2, Qualidade

### Subfase 2.7 — branch, evidencia e PR: o fluxo client-side (ENCERRADA em 2026-10-08)

> **ENCERRADA.** A revisao independente reprovou em rodadas sucessivas, com achados
> bloqueantes de falsa garantia, falso verde e fail-open - inclusive um `ALTA` que deixava o
> `-Abrir` sem autorizar nenhuma coleta real. Todos corrigidos, e a ultima rodada saiu
> **APROVADO** no `qa-reviewer` e no `security-reviewer`. Os `BAIXA` que sobraram nao abrem
> rodada pela regra de 2026-09-14 e estao no backlog do `docs/STATE.md`.
>
> **Nenhum numero de rodada, de caso ou de mutacao aparece aqui.** Eles vivem no cabecalho do
> `docs/STATE.md` e na tabela da secao da 2.7, e so la: numero repetido em prosa envelhece, e
> foi assim que este registro ja se contradisse duas vezes.
>
> O achado mais grave, encontrado pelos dois revisores independentemente: o portao de evidencia
> comparava os relatorios com o HEAD **local**, enquanto o PR e montado pelo GitHub a partir do
> **remoto** - o corpo publicado podia afirmar um commit que o PR nao mostra.
>
> **As duas mutacoes que sobreviveram na primeira rodada eram a mesma falha minha**, e nao do
> produto: dois casos passavam PELO MOTIVO ERRADO. Com o portao removido, o fluxo caia no portao
> seguinte e produzia o mesmo codigo de saida - o caso media o numero certo pela razao errada.
> E a classe que a 2.6 ja tinha pago repetidas vezes, reaparecendo na subfase seguinte.
> A contagem de cada subfase vive na secao dela, no `docs/STATE.md`, e so la.

Tres scripts, uma responsabilidade cada, e nenhum refaz o trabalho do outro: `branch.ps1` cuida de
criacao, estado e troca; `collect-diff.ps1 -Contra <base>` produz evidencia; `pr.ps1` integra via
`gh`. Os hooks da 2.6 sao gates locais; a CI da 2.8 sera a verificacao independente.

**A troca de branch tem guarda-corpo, e ele nao cede a confirmacao.** Arvore suja recusa a troca
MESMO com `-Confirmar`, porque confirmar e autorizar a troca, nao autorizar perder trabalho - e
arquivo nao rastreado conta, porque ele tambem se perde. Sem `-Confirmar`, `-Trocar` mostra o que
faria e para: troca implicita, feita de passagem por outro comando, nao existe. O script **nao faz
`stash`** por conta propria; esconder trabalho sem pedido e a forma mais rapida de perde-lo.

**O PR tem tres portoes, e o terceiro nasceu de uma falsa garantia minha.** O cabecalho do `pr.ps1`
ja afirmava que a seguranca era verificada "com o fluxo privado tendo saido 0" enquanto o codigo
**so conferia que o arquivo existia e citava o commit**. Um relatorio cheio de `ALTA` passava. Eu
achei isso escrevendo o briefing do `security-reviewer`: redigindo a pergunta que eu queria que ele
atacasse, descobri que a resposta era "nao, nao verifica". **Falsa garantia e pior que lacuna: a
lacuna se ve, a garantia falsa tranquiliza.** O codigo foi corrigido, nao a frase.

A leitura dos achados **reusa** `Get-AchadosBloqueantesDoRelatorio`, da 2.6, porque ela ja sabe a
unica distincao dificil - achado real nao e achado ACEITO POR EXCECAO (ADR-0010), e as duas secoes
tem linhas `MEDIA`. Mas aquela funcao devolve lista vazia quando nao consegue ler, o que e
deliberado no contexto do hook e seria fail-open aqui. Por isso a exigencia da secao `## Achados`
vem ANTES da leitura: relatorio de formato desconhecido sai **2**, nao "nada achado".

**`gh` ausente e `gh` deslogado sao estados distintos**, porque levam a acoes distintas, e os dois
saem 2 - "nao consegui verificar" nunca vira "pode abrir". **Nada aqui le, escreve ou passa token:**
o `gh` autentica por navegador (ADR-0003, item 5). O corpo do PR **aponta** para a evidencia e nunca
a transcreve - `artifacts/` e gitignored, nao viaja num clone, e publicar achado de seguranca num PR
nunca foi autorizado nesta plataforma.

**Quatro defeitos achados pela execucao, nao pela leitura:** `origin` listado como se fosse branch
(`%(refname:short)` de `refs/remotes/origin/HEAD` e `origin`, sem o `/HEAD`); uma linha fantasma na
lista vazia de PRs - e **meu primeiro diagnostico estava errado**, porque `ConvertFrom-Json` sobre
`[]` nao devolve `$null`, devolve um `Object[]` vazio como UM item do pipeline, e filtrar pela forma
quebraria o caso de um PR so; um caractere nao-ASCII num `.ps1`; e atribuicao a `$args`, que e
variavel automatica.

**Um guarda de byte novo, e ele nasceu de um defeito desta subfase.** Escrevendo o terceiro portao,
o `\r` de um caminho passou por uma camada que interpretou escapes e virou **0x0D de verdade**
dentro da string. O arquivo continuou ASCII, continuou sem caractere de controle proibido - porque
o guarda de controle PERMITE 0x0D, e tem de permitir -, continuou com sintaxe valida, e a suite
continuou verde, enquanto o portao que aquela linha sustentava nunca encontraria o relatorio. Entrou
`Get-CrSoltos`: CR que nao e seguido de LF. **Uma regra errada falha; uma regra desarmada passa.**

**O limite do mock esta declarado, e ele mudou o desenho.** O `gh` real e um `.exe`; o mock e um
`.cmd`, que passa pelo `cmd.exe`. **Medido:** argumento
multilinha - que e o caso do `--body` - chega truncado na primeira quebra, sem erro nenhum. O mock
mede codigo de saida e qual subcomando foi chamado; ele nao pode testemunhar o conteudo dos
argumentos. Por isso a montagem da linha de comando saiu para `Get-ArgumentosDePrCreate` e e pinada
em memoria.

**O que isto NAO e:** nao e enforcement. Nao ha branch protection neste plano, por decisao de
governanca registrada em **ADR-0011** - a mantenedora recusou contratar GitHub Pro so para isso em
2026-10-01. O `pr.ps1` diz isso em voz alta ao abrir, e o corpo do PR repete. O PR organiza a
revisao; ele nao impede merge sem ela.

### Subfase 2.6 — hooks de Git: guarda-corpo local, versionado, e contornavel de proposito

> **Numeros fechados:** oito rodadas de revisao independente, 37 mutacoes aplicadas contra o
> repositorio real com restauracao conferida por SHA-256, sete bloqueantes fechados, 22 itens de
> backlog abertos (99 a 120). A suite fechou em 419 casos, dos quais 60 sao da subfase.
>
> **Dos sete bloqueantes, CINCO estavam em codigo que eu tinha acabado de escrever para consertar o
> bloqueante anterior.** Nas tres ultimas rodadas nao houve nenhum defeito de comportamento no
> produto: houve afirmacao minha excedendo o que o codigo faz, derrubada uma a uma. O
> security-reviewer aprovou o produto em sete rodadas seguidas; o qa-reviewer reprovou a camada que
> o MEDE em sete delas.

Erro previsivel barrado ANTES de entrar no historico ou sair para o remoto. Os hooks
**orquestram** o que ja existe - `security-scan.ps1`, `doctor.ps1`, o `verificacao.comando` do
manifesto - e nao implementam verificacao propria: detector novo seria dois detectores divergindo
em silencio.

**O mecanismo nao copia nada.** `core.hooksPath` aponta para a pasta VERSIONADA `githooks/`; nada
vai para `.git/hooks`, que nao viaja num clone e exigiria alguem lembrar de recriar. O que nao e
copiado nao diverge da origem: o que roda E o arquivo que a revisao leu. O que ainda pode divergir -
o shim ficar para tras da versao que o codigo espera - tem detector, porque cada shim carrega
`# os-hooks-versao: N` e a setima dimensao do doctor confere.

**Quatro fatos medidos por sonda antes da primeira linha de codigo:** `core.hooksPath` relativo
funciona e resolve contra o topo da working tree; o diretorio corrente do hook e esse topo;
`GIT_DIR` NAO vem preenchida no `commit-msg` deste Git for Windows - o registro anterior afirmava
mais do que isso; e caminho com espaco (OneDrive) funciona com aspas em toda expansao.

**`commit-msg`: tres regras, todas estruturais.** Assunto nao vazio; se existir linha 2, ela tem de
ser vazia; assunto ate 100 caracteres. Convencao estilistica nao entra - bloquear gosto transforma
o hook em coisa que se contorna por habito. A regra da linha 2 veio de um defeito desta casa, de
cinco dias atras: o commit de fechamento da 2.5 nasceu sem a linha separadora e o assunto engoliu o
primeiro paragrafo inteiro. **O caso de teste usa a mensagem que produziu aquele commit - um trecho
dela, com a estrutura intacta - e a corrigida como par positivo.** A primeira redacao dizia "a
mensagem exata"; o qa-reviewer conferiu e a fixture carrega ~228 caracteres do primeiro paragrafo,
nao os 350. O caso mede a REGRA, nao o texto.

**`pre-commit`: 8,2 s, offline.** `security-scan.ps1 -SemHistorico -SemRede` - os dois
modificadores que a 2.3 criou dizendo, no proprio docstring, "use apenas onde a latencia importa
(hook de pre-commit)". Nao roda a suite, nao altera arquivo, nao faz `git add`. E escreve em
`artifacts/hooks/`, NUNCA em `artifacts/review/`: aquele e a evidencia das revisoes independentes,
e um hook que a regravasse a cada commit destruiria a evidencia do fechamento em curso.

**`pre-push`: composto pelo manifesto, com vocabulario fechado** - `security`, `doctor`, `tests`,
`nenhum`. Valor fora dele BARRA, nomeando o valor. Campo ausente cai no padrao (`doctor` +
`security`), porque ausente nao e "nao verifique" e tambem nao autoriza impor o caro; `["nenhum"]` e
o desligamento explicito. `tests` nao entra no padrao nem nesta plataforma: a suite leva ~12 min, e
um portao de 12 min em todo push ensina `--no-verify` em uma semana.

**Codigo de saida 2 BARRA.** "Nao consegui verificar" nunca vira "esta bom": scanner que nao rodou
nao autoriza commit, e manifesto ilegivel nao cai no padrao - assumir o padrao ali seria verificar
menos do que o projeto pode ter pedido, em silencio.

**O doctor ganhou a setima dimensao e uma invariante.** `hooks` responde se os guarda-corpos estao
ativos neste clone - `WARN` e nao `FAIL`, porque hook ausente nao torna o projeto incorreto, torna-o
desprotegido -, e ele NAO instala: ha caso medindo que `core.hooksPath` nao foi tocado. Quem
responde a pergunta e a MESMA funcao que o instalador usa no `-Verificar`. Junto entrou
`Get-DimensoesDoDoctor`, a lista canonica: o doctor confere o que emitiu contra ela e LANCA se
divergir, porque uma dimensao que sumisse produziria relatorio menor e igualmente verde.

**Quatro defeitos reais, achados pela propria construcao.** Um laco infinito no trim de linhas vazias
- com um elemento, `$uteis[1..0]` nao e intervalo vazio: o PowerShell INVERTE o sentido e devolve
dois itens -, e a guarda faltava exatamente no laco irmao daquele onde ela ja estava. E a declaracao
de politica em colecao de FLUXO, que este leitor de manifesto nao le (item 42): chegava como uma
string com colchete dentro, e a mensagem mandaria procurar erro de digitacao num valor certo. O hook
passou a detectar a forma e a mostrar como declarar em bloco.

E o terceiro: **o leitor de YAML do proprio harness tinha o fail-open que ele existe para pegar.**
`Get-CampoYaml` buscava por NOME e usava `\s*` depois dos dois-pontos; quando `verificacao.hooks`
passou a existir ao lado de `plugin.hooks`, a chave de BLOCO capturou a linha seguinte como valor e
quem pedia `hooks` recebeu a primeira ocorrencia. E o mesmo "bloco irmao satisfazendo o caminho
pedido" que o leitor do doctor fechou na 2.4, vivo dentro do harness - e foi o guarda-corpo que
acusou. Conserto na raiz: valor na MESMA linha, nome ambiguo LANCA, e `-Bloco` para desambiguar,
aplicado aos NOVE sitios de chamada e com par negativo e positivo.

E o quarto, que a coleta de evidencia da PROPRIA 2.6 produziu: os tres shims sairam do coletor como
"nao e texto reconhecido", porque sao os primeiros arquivos SEM EXTENSAO que este repositorio
versiona - e sao os que EXECUTAM a cada commit. O efeito medido: tres lacunas no relatorio, e os
revisores nao veriam o codigo que roda na maquina. A lista de nomes ja havia falhado duas vezes pelo
mesmo motivo (.npmrc e .gitkeep); esta foi a terceira, entao a PERGUNTA mudou em vez de a lista
crescer. `Test-ExtensaoDeTexto` virou `Test-ArquivoDeTexto`: com extensao decide a lista, sem
extensao decide o CONTEUDO - byte NUL nos primeiros 8 KB significa binario, como o proprio Git
decide e como o harness ja decidia. So ALARGA cobertura, continua fail-closed, e os CINCO sitios
de chamada foram atualizados - security-scan, collect-diff, scan-historico, scan-dado-pessoal e
scan-exposicao -, mais a definicao em scan-comum.

**`--no-verify` existe e nao e combatido.** Fingir que hook local e incontornavel seria falsa
garantia. Hook = feedback local rapido; `pre-push` = portao antes de o historico sair; CI da 2.8 =
verificacao independente. Protecao de branch no servidor nao esta disponivel neste repositorio
privado no plano atual, entao a camada que vale e a CI - nao esta.

**O que a 2.6 deliberadamente NAO fez:** o template nao ganhou hooks, porque as duas saidas tem
custo real (duplicar a plataforma em cada projeto, ou criar segunda implementacao da mesma regra), e
a terceira - caminho absoluto para o plugin desta maquina - e a dependencia oculta do computador
atual que o contrato proibe. Esta no backlog com as duas opcoes e as duas consequencias. E os hooks
de PLUGIN do Claude Code continuam zero, registrados nominalmente para nao sumirem por homonimia.

### Subfase 2.5 — `/os:doctor`, o diagnostico que nenhuma das outras duas faz

`tests` responde se o comportamento funciona. `/os:security` responde se ha risco. Nenhuma das duas
responde **se o projeto e continuavel sem a conversa** — que e a pergunta que da razao de existir a
plataforma inteira, e ate agora nenhuma ferramenta a fazia.

**A regra de separacao e o criterio de aceite mais importante da subfase, e ela e medida:** o doctor
**nao roda a suite** e **nao varre conteudo**. Contra uma fixture com uma suite que deixaria rastro
no disco e um segredo em formato reconhecivel, ele nao executou a suite, nao transcreveu o segredo e
nao o acusou. Duplicar significaria dois detectores divergindo em silencio.

**E ele nao conserta nada.** Medido byte a byte: zero arquivo alterado ou apagado, `HEAD` identico
antes e depois, e nada criado fora dos proprios `artifacts/doctor/`. Ferramenta que conserta sozinha
esconde o problema que deveria mostrar.

**Seis dimensoes**, cada uma com `PASS`/`WARN`/`FAIL`/`INCONCLUSIVO`, e **`INCONCLUSIVO` domina**:
uma dimensao que nao conseguiu rodar faz o diagnostico inteiro sair com `2`, mesmo com todas as
outras em `PASS`. "Nao verifiquei" nunca vira "esta bom".

**A camada 0 resolve a raiz real antes de qualquer predicado** — `git rev-parse --show-toplevel`,
com guarda —, e e o que permite rodar de subdiretorio. As sete formas foram executadas: raiz,
subdiretorio, worktree ligado, `.git` como arquivo, recem-init, fora de repositorio e *bare*. As
duas ultimas sao respostas DIFERENTES de proposito: "nao ha repositorio aqui" e um fato e sai `1`;
*bare* e forma nao suportada e sai `2`.

**Frescor sem reexecutar nada:** o doctor le o carimbo de `HEAD` que os coletores deixaram e
distingue quatro estados — inexistente, do `HEAD` atual, de outro `HEAD`, invalido. **"Nao existe
evidencia recente" nunca e `PASS`.**

**Dependencia so e cobrada quando declarada.** Campo `ambiente.dependencias` novo, aditivo, na
plataforma e no template: ausente e `WARN` ("ainda nao declarou"), `[]` e declaracao explicita
valida, obrigatoria e ausente e `FAIL`, opcional e ausente e `WARN`. Ausencia de `gh` num projeto
que nao fala com o GitHub nao gera diagnostico nenhum — detector que grita sobre o que ninguem
pediu e detector que se aprende a ignorar.

**Saida estruturada versionada por `schema_version`**, alem do relatorio humano, para a Fase 3/4 nao
ter de parsear Markdown. Contrato desenhado, nenhuma integracao escrita.

#### Sete defeitos reais na propria implementacao, nenhum achado por leitura

Acento em `.ps1` virando mojibake e fazendo o detector acusar ausencia de secoes que existiam;
comparacao de `mtime` com data de commit, que e falso positivo **por construcao**; regex de carimbo
ancorado em inicio de linha, inventando lacuna sobre evidencia valida; guarda de raiz comparando
caminhos, que nao pegava o caso do `GIT_DIR` e acusava falso sob caminho 8.3; `return @()`
colapsando para `$null` e apagando a diferenca entre `dependencias: []` e campo ausente; cobertura
de dimensao que nao chegava a saida nenhuma; e a suite nova fora da ordem declarada do runner.

Os dois ultimos foram apontados pelos guarda-corpos que a 2.4 construiu. O quinto tem regressao no
ponto exato onde morava — o leitor, nao a dimensao —, com mutacao conferida.

#### Numeros fechados da subfase

**Dezenove rodadas de revisao independente**, com os dois revisores em contexto isolado. O
`qa-reviewer` emitiu dezenove vereditos; o `security-reviewer`, treze — rodadas 1 a 11, 14 e 19.
**34 mutacoes aplicadas contra o repositorio real, 34 mortas**, com restauracao conferida por
SHA-256 em cada uma. A suite fechou em 350 casos.

Os vereditos vivem em `artifacts/`, que e **ignorado pelo Git**: quem clonar este repositorio nao
consegue conferir nenhuma destas contagens. Elas estao aqui como registro datado, nao como prova — a
prova e o `docs/STATE.md`, rodada a rodada.

#### O que a revisao independente corrigiu nesta subfase

> **A contagem de rodadas entra aqui no FECHAMENTO**, quando for um numero fechado; enquanto a
> subfase esta aberta, o registro rodada a rodada vive no `docs/STATE.md`. O mesmo vale para o
> total de mutacoes.
>
> E **placar AGREGADO por veredito nao entra ENQUANTO A SUBFASE ESTA ABERTA**: nem "reprovou em
> todas", nem "aprovou em todas", nem faixa de rodadas por tipo de achado. O que cada rodada achou
> **fica na narrativa dela** - isso e fato datado, conferivel contra o `STATE`, e nao placar.
>
> Em subfase **FECHADA** o agregado e numero fechado, e entra - e por isso que a secao da 2.4, no fim
> deste arquivo, pode dizer quantas rodadas teve e que o `qa-reviewer` reprovou todas sem
> contradizer esta regra: aquela subfase esta FECHADA. O
> `qa-reviewer` cobrou a distincao na rodada 15: a primeira versao desta nota proibia nominalmente
> uma frase que o proprio arquivo mantem, e quem fosse escrever o fechamento nao teria como saber
> qual das duas valia.
>
> A regra e a licao da 2.4, no fim deste arquivo: *"a contagem de rodadas fica, o placar por
> veredito sai. Numero em prosa que ninguem pode conferir e afirmacao, nao registro."* Os vereditos
> vivem em `artifacts/`, que e **ignorado pelo Git** - quem clonar este repositorio nao consegue
> conferir nenhuma afirmacao sobre rodadas.
>
> Eu tinha feito o INVERSO na primeira tentativa de consertar isto: tirei a contagem e mantive o
> placar. As duas afirmacoes que sobraram estavam **erradas** - uma subdimensionava a faixa de
> rodadas com achado de codigo, a outra afirmava aprovacao de seguranca numa rodada sem revisor de
> seguranca. Achados do `qa-reviewer` na decima terceira rodada.

Abaixo, o que mudou no produto. Os tres achados bloqueantes da rodada 2:

**O fail-open sobreviveu um ramo ao lado.** A regex que decide o que e `chave: valor` estava
COPIADA em tres lugares do leitor de manifesto. A correcao da rodada 1 endureceu a copia da chave
de TOPO e deixou a da continuacao de item de lista com `if ($m.Success)` sem `else` — no unico
campo de lista que o doctor le. Com `obrigatoria : true`, um espaco antes dos dois-pontos que o
YAML aceita e o gemeo do template le, a linha sumia em silencio, `ObrigatoriasAusentes` ficava
zero, e o doctor saia **0 no lugar de 1**: a unica regra `FAIL` da dimensao ambiente, desarmada.
Conserto na causa: **uma** funcao, `Split-LinhaDeChaveDoManifesto`, e os tres sitios a chamam.

**A quarta divergencia com o gemeo estava na CHAVE, nao no escalar.** O doctor aceitava
`^([A-Za-z0-9_-]+):`; o gemeo aceita `^([^\s:#][^:]*):`, e a docstring dele diz que aceitar ponto,
acento, aspas e espaco foi DELIBERADO. Um `project.yaml` com chave acentuada — pt-BR — derrubava o
doctor em duas dimensoes e saia exit 2, enquanto a suite do mesmo projeto lia o arquivo sem
reclamar. A regex passou a ser a do gemeo, caractere a caractere. O que tornava isto bloqueante nao
era a direcao — e fail-closed — mas a **afirmacao**: o cabecalho do modulo declarava paridade para
todo campo, e a fixture so tinha chaves `[a-z_]`. A fixture passou a carregar chave entre aspas,
com espaco antes do `:`, com ponto e com acento; o cabecalho passou a declarar tambem o teto
**compartilhado** (`---`, escalar multi-linha, ancora, merge), que nao e divergencia.

**Um ponto do registro contraditorio nao foi corrigido, e eu afirmei ter corrigido todos.** O
`STATE.md` continuava dizendo "Skills: 6" e anunciando `doctor` como trabalho futuro, com 7 skills
no disco, o manifesto declarando 7 e o cabecalho declarando a subfase concluida. A contagem de
skills em prosa ganhou **detector** em `tests/suites/docs.ps1` — o registro sobreviveu duas rodadas
porque nenhum teste olhava para ele.

**E o caminho em que o doctor nao produzia diagnostico nenhum.** `Test-TemHistorico` estava fora de
`try/catch`: com ref quebrada — estado que a propria suite exercita — a excecao subia ate o `trap`
e o processo saia 2 **sem gravar nem o relatorio nem o JSON**, contra o proprio desenho. Agora a
dimensao vira `INCONCLUSIVO` nomeando a causa, como a dimensao `git` ja fazia.

Cada correcao ganhou mutacao, e **todas morreram** pelos casos certos, com restauracao conferida
por SHA-256. A que reverte a regex da chave mata **dois** casos. *(Subtotal corrente em prosa foi o que fez
`CHANGELOG` e `STATE` divergirem duas vezes, e ele nao e conferivel pelo repositorio - o script de
mutacao vive no scratchpad, item 31. **O total da subfase entra no FECHAMENTO**, quando for numero
fechado; cada rodada abaixo diz so o que aconteceu nela.)*

**E a quarta rodada achou a quinta divergencia, no VALOR.** Alinhar a regex da chave nao bastava: o
`qa-reviewer` respondeu a minha propria pergunta mostrando que em YAML a aspa escapada e a aspa
**dobrada**, e o `IndexOf` do leitor cai na primeira metade dela. Medido com os dois leitores lado a
lado: `criterio_de_pronto: 'o relatorio diz ''pronto'''` voltava do doctor como `o relatorio diz ` — **truncado, sem erro e sem lacuna** —,
enquanto o gemeo devolvia a frase inteira. Eu tinha endurecido a chave e deixado a mesma afirmacao
larga sobre o valor. Agora a estrutura e a do gemeo, em dois passos: cortar comentario aqui, tirar um
par das pontas na funcao que ja trata a chave. A fixture de paridade carrega a forma, e o caso passou
a comparar **leitor contra leitor** — antes ele chamava o acessor de um lado e lia o dicionario cru
do outro, e o acessor tem politica propria para campo declarado vazio.

Duas mutacoes nesta rodada, **as duas mortas**: a que devolve o corte na aspa dobrada mata o caso
de paridade; a que tira o par de aspas do valor mata cinco casos.

#### A quinta rodada: a ORDEM entre normalizar e decidir a estrutura

O `qa-reviewer` reprovou pela quarta vez, e o achado foi o de maior raio da subfase: as decisoes
ESTRUTURAIS do manifesto - 'chave:' sem valor abre bloco, '[]', '{}', escalar de bloco - eram
tomadas sobre o valor CRU, e o comentario so era cortado depois. O gemeo do template normaliza
antes. Medido com os dois leitores lado a lado:

'verificacao:  # o que este projeto verifica' fazia o valor nao ser vazio, o ramo do bloco nao
rodava, 'verificacao' virava STRING, e as linhas indentadas seguintes nasciam na RAIZ. Resultado:
'DeclaraTests' falso, a UNICA regra FAIL da dimensao manifesto desarmada, exit 0, sem erro e sem
lacuna. E 'dependencias: []   # nenhuma por enquanto' - o idioma publicado pelo proprio template -
virava a string '[]', com o doctor sondando no PATH uma ferramenta com esse nome e saindo
INCONCLUSIVO: exit 2 sobre projeto saudavel, contra a decisao de governanca de que '[]' e
declaracao explicita valida.

'Remove-ComentarioDoEscalar' virou funcao propria e a normalizacao passou a acontecer antes.
E o conserto expos a camada seguinte, que nenhuma fixture alcancava: com o comentario cortado
primeiro, 'criterio_de_pronto:  # preencher depois' passa a chegar VAZIO - e o doctor abria bloco
para qualquer valor vazio, enquanto o gemeo abre bloco so quando a proxima linha significativa e
MAIS indentada. Regra copiada, e foi o caso de paridade que pegou, no mesmo ciclo.

Duas mutacoes nesta rodada, **as duas mortas**. A que devolve a decisao ao valor cru mata cinco
casos.

#### A sexta rodada: placeholder de instanciacao virando silencio

O `qa-reviewer` aprovou o CODIGO na quinta rodada e reprovou o REGISTRO. Na sexta, com o registro
consertado, ele achou o mesmo fail-open **de novo um ramo ao lado** - a terceira vez nesta subfase.

`Get-CampoDoProjeto` LANCA de proposito quando o valor ainda e placeholder de instanciacao - que e o
estado exato de um projeto copiado do template pelo `/os:new-project` e nao terminado. Os dois
consumidores da dimensao manifesto engoliam a excecao com `catch { $v = $null }`. Medido em
execucao, com o campo `nome` valendo `{{NOME}}` e `tests` valendo `{{TEM_TESTS}}`:

    status ......... WARN      (exit 0)
    lacunas ........ 0
    achado: WARN - o manifesto nao declara 'identidade.nome'

O campo ESTA declarado. A dimensao afirmava o contrario, `DeclaraTests` ficava falso, e a UNICA
regra `FAIL` nao disparava. Afirmacao falsa somada a fail-open. E **nenhum caso exercitava esse ramo
em dimensao nenhuma** - foi o que o deixou atravessar cinco rodadas.

Agora os dois sitios emitem lacuna nomeada, a dimensao sai `INCONCLUSIVO`, e a afirmacao falsa
sumiu. O caso novo mede os **dois sitios separadamente**, porque reverter so um deixaria o outro
sustentando o `INCONCLUSIVO` sozinho - que e exatamente a forma pela qual o defeito sobreviveu.

**As mutacoes desta rodada morreram**, e da decima em diante elas passaram a ser aplicadas A MAO: o script de mutacao
relatou `SOBREVIVEU` para duas que, aplicadas manualmente, matam o caso. Erro para o lado do falso
alarme, e ainda assim e a segunda vez que o instrumento de mutacao mente nesta plataforma - a
primeira foi o `Write-Host` indo para o fluxo 6 sem o `>` capturar. Backlog item 62.


#### A setima e a oitava rodada: o artefato afirmando e negando o mesmo fato

O `doctor.json` - contrato de maquina da Fase 3/4 - saia com `coverage.nao_verificado` dizendo que a
regra NAO foi aplicada e `coverage.verificado` dizendo que o mesmo fato era `True`. Duas dimensoes
faziam isso, e o conserto NAO foi nos dois pontos: `New-DimensaoDoDoctor` passou a LANCAR quando o
mesmo `O_que` aparece nos dois canais. A invariante vive no construtor, entao dimensao nova nasce
coberta sem ninguem precisar lembrar.

A oitava rodada mostrou que isso ainda nao bastava: a invariante compara STRING, e havia um ramo -
`git log` falhando com o HEAD nao nascido sobre refs que existem, o estado de 'git checkout
--orphan' e de 'fetch-only' - que emitia a lacuna com OUTRO rotulo e escapava. Guarda por string
tem a mesma fragilidade do defeito que ela conserta. A emissao da verificacao passou a ser decidida
por um FATO DO FLUXO: ela sai no ramo que estabeleceu o fato, e nao no fim atras de uma comparacao
de texto. Caso novo para o ramo orfao, que nao tinha nenhum.

Junto: campo AUSENTE deixou de virar 'True'. `verificacao.tests` nao declarado e
`docs/STATE.md` nunca commitado passaram a sair como `nao se aplica: <motivo>`, em vez de uma
verdade vacua apresentada como verificacao feita.

**As mutacoes desta rodada morreram**, e uma delas pegou um caso NOVO passando por vacuidade:
o cruzamento dos dois canais lia `dimensions[].nao_verificado`, que e sempre nulo - as lacunas vivem
em `coverage`, no topo do JSON. Reancorado, as mutacoes passaram a matar os dois casos.


#### A nona rodada: o canal que nenhum caso lia

O `qa-reviewer` derivou por leitura que **nenhum caso da suite lia o campo `Resultado`** - so o
`O_que`. A correcao da oitava rodada ("campo ausente deixou de virar `True`") podia ser revertida
INTEIRA com a suite verde: o construtor nao lanca, porque nao ha lacuna com aquele rotulo nesses
ramos, e nenhum codigo de saida muda. Ele estava certo.

E a classe estava viva em mais duas dimensoes, que eu tinha declarado seguras:

- **`ambiente`**: campo ausente emitia uma lacuna que NAO dominava. O relatorio imprimia a linha em
  "O que NAO foi verificado", logo abaixo do paragrafo que diz que lacuna faz sair com `2`, e o
  processo saia `0`. Virou verificacao `nao se aplica: <motivo>` mais o achado `WARN` que a decisao
  de governanca exige.
- **`frescor`**: a verificacao saia para TODO artefato, fora do `switch`, convivendo com a lacuna do
  ramo `invalido` sobre o mesmo artefato, com outro rotulo. Passou a sair no ramo.

Duas afirmacoes MINHAS cairam junto, e ficam registradas porque a forma se repete: eu tinha escrito
no backlog que a classe estava "fechada na setima rodada" - nao estava, a setima fechou colisao de
ROTULO - e que os ramos do `frescor` eram "mutuamente exclusivos" - eram falsos, e a condicao de
disparo que eu reservei para o futuro ja estava no disco.

**As mutacoes desta rodada morreram**, e da decima em diante elas passaram a ser aplicadas a mao.
O total da subfase entra aqui no fechamento - escrever um total corrente foi o que ja bloqueou duas
rodadas, inclusive a que o escreveu.

#### O contrato publicado ganhou detector

`skills/doctor/SKILL.md` afirma comportamento verificavel - a escada de status, o mapa de codigo de
saida, e os cenarios que ela nomeia. Nada disso tinha detector: `plugin validate` olha estrutura, nao
conteudo. Consequencia medida nesta subfase: uma afirmacao FALSA sobre codigo de saida sobreviveu
uma rodada inteira de revisao depois de o comportamento ter sido corrigido.

Dois casos novos **extraem da prosa as afirmacoes estruturadas e perguntam ao codigo**: a escada de
status contra `Get-StatusDoDoctor`; cada par status->codigo da linha "Codigos de saida" contra
`Get-CodigoDeSaidaDoDoctor`; e cada cenario nomeado e EXECUTADO, com o codigo esperado
**extraido da propria prosa**, clausula a clausula. O relatorio tambem passou a ter o proprio
codigo de saida conferido: ele imprime "(codigo de saida N)", e esse N tem de ser o do processo.

**Consequencia pratica: editar `skills/doctor/SKILL.md` pode derrubar a suite.** E para isso que
ele existe - foi a primeira vez nesta subfase que mudanca de documentacao derruba um teste.

**Mudanca de comportamento, para quem le o CHANGELOG antes de atualizar:** a dimensao `manifesto`
passou a sair `INCONCLUSIVO` (codigo **2**) em tres situacoes que antes saiam `0` em silencio -
valor de `verificacao.tests` que nao e `true` nem `false`, placeholder de instanciacao em campo
obrigatorio, e placeholder em `verificacao.tests`. E a `retomabilidade` deixou de afirmar
'STATE atualizado no ultimo commit' quando nao conseguiu medir. Projeto instanciado pela metade
agora e diagnosticado como tal, em vez de aprovado.


### Subfase 2.4 — infraestrutura de testes por projeto

O template **declarava** ter verificação e entregava `tests/` com um `.gitkeep` dentro. Estrutura vazia é exatamente o que a política 4.4 proíbe, e estava no arquivo que governa todo projeto novo. Junto com isso, a skill `new-project` documentava um placeholder `{{TEST_CMD}}` que **não existia em lugar nenhum do template**: o passo 6 mandava rodar "o comando que você escreveu no `{{TEST_CMD}}`", sobre um valor que nunca era substituído. Nenhum teste pegava nem um nem outro — o teste de placeholder comparava só a direção template → skill, e o que apodreceu foi a outra.

**Um comando, igual em todo projeto.** `.\tests\run-tests.ps1`, declarado literal em `project.yaml` → `verificacao.comando`. Ele detecta a trilha (Python via `pytest` no `.venv`, ou PowerShell via harness e `suites/`), e o `/os:new-project` apaga a trilha que não se aplica — mesmo padrão já usado com o `requirements.txt`. Se as duas sobreviverem, o runner **recusa rodar**: escolher uma em silêncio esconderia metade dos testes. Isso substitui o caminho longo do `python.exe` do `.venv`, que estava copiado em `CLAUDE.md` e `README.md` de cada projeto e divergia dos dois lados.

**`exit 2` = a suíte não rodou**, e não é uma variação de `1`. Sem suíte, sem `.venv`, sem `pytest`, trilha ambígua, ou suítes que carregaram e não executaram caso nenhum. Um runner que não acha suíte e sai com `0` está afirmando aprovação sobre nada — a violação da política 4.5, aplicada agora aos projetos governados e não só à plataforma. O `bootstrap.ps1` **roda a suíte** e bloqueia quando o manifesto declara `tests: true` e a suíte não roda: declaração não é verificação. É a semente do `/os:doctor` da 2.5, com o caso mais comum já coberto.

**Critério de aceite mora no manifesto, não na asserção.** Campos novos: `verificacao.comando`, `verificacao.criterio_de_pronto` e `verificacao.limites`. Os harnesses das duas trilhas leem de lá — `limite("nome")` em Python, `Get-LimiteDoManifesto` em PowerShell — e **falham quando o limite não está declarado**, sem valor padrão em nenhuma das duas. Padrão silencioso transformaria "o projeto não declarou seu critério" em "passou". O defeito que originou isso é medido: no `conversor-utm`, "dentro de 1 metro" existia na prosa do `README.md`, na docstring do teste e como `1.0` cravado na asserção — três lugares, nenhuma fonte de verdade. Terceira aparição da mesma classe nesta plataforma.

O `conversor-utm` foi usado **só como caso de comparação**, sem ser tocado: dos 29 testes dele saiu a separação entre infraestrutura reaproveitável (caminho de import, limite lido do manifesto, fixture de CSV com BOM, convenção de docstring que declara o que o teste **não** prova) e o que é específico daquele projeto (a matemática UTM inteira). Continua fixture e evidência do ciclo — migração é decisão dela, um projeto por vez (ADR-0001).

**Suíte nova `project-tests`, e todos os casos rodam em projeto recém-instanciado** — não leem o template. Instanciação, escolha de trilha e execução ficaram em três funções do harness (`New-ProjetoDeTeste`, `Remove-ProjetoDeTeste`, `Invoke-RunnerDoProjeto`), e a substituição de placeholder ali **não filtra por extensão**: o teste de instanciação antigo usava o glob `*.md,*.yaml,*.ps1` que a própria skill proíbe, e um teste que usa o fluxo proibido não testa o fluxo real. *(A primeira versão desta função ainda filtrava — por uma allowlist de 13 extensões — enquanto afirmava não filtrar. O `qa-reviewer` chamou a afirmação de falsa, com razão; hoje a decisão é por conteúdo, byte `0x00` nos primeiros 8 KB, como o próprio Git decide.)* A trilha Python é exercitada com `.venv` e `pytest` de verdade (~20 s), porque conferir `conftest.py` por leitura não prova que as fixtures funcionam.

E tres defeitos reais, os tres achados pelos testes novos:

- **`[double]::TryParse('1.0')` devolve `10` nesta máquina.** A cultura do sistema é pt-BR, o ponto vira separador de milhar, `TryParse` devolve `$true`, e uma tolerância de 1 metro declarada no manifesto passava a valer 10 — com o teste **verde**, porque ele apenas comparava contra o número errado. Só o caso que exigia o valor **exato** pegou; um caso de "cabe no limite" teria passado. Corrigido com `InvariantCulture` e guardado por um caso próprio. No runbook, junto com o aviso de `stderr` do `py -m venv` em caminho 8.3 e a colisão de nomes entre os dois harnesses.
- **O coletor de evidência morreu por causa de um aviso do Git**, na hora de coletar a evidência desta subfase. `eol=lf` no `.gitattributes`, um `.md` gravado com CRLF, `git diff` avisando *"CRLF will be replaced by LF"* — e no 5.1 stderr de executável nativo é erro terminante sob `Stop`: `exit 2` e **sem relatório**. Corrigido por **classe**: todo `git` dos coletores passa por `Invoke-Git`, e `2>$null` deixou de ser tratado como proteção (nunca foi — já estava medido). 34 chamadas convertidas, nenhuma solta restou.
- **Suíte-fixture em here-string inflava a contagem de testes da plataforma.** As suítes que os testes escrevem dentro de projetos temporários tinham `Test-Caso` na coluna 0, e o guarda-corpo que confere `Testes: N/N` contra o disco acusou 210 no disco com 206 executados. O guarda-corpo funcionou — foi ele que denunciou. Corrigido indentando as fixtures, com a convenção escrita no topo da suíte.
#### A revisão independente da 2.4 reprovou, e o achado central era a minha própria correção

Os dois revisores reprovaram e convergiram no mesmo defeito — que não estava no escopo da subfase, mas na correção feita no meio dela.

**A primeira versão do `Invoke-Git` engolia o código de saída junto com o aviso.** `ALTA` para o QA. Das ~34 chamadas, **6** consultavam `$LASTEXITCODE`; nas outras 28, falha de git virava lista vazia — indistinguível de "nada a acusar". Antes da 2.4 a mesma falha abortava e o `trap` dava `exit 2`. Um modo de falha ruidoso trocado por um silencioso, dentro de um detector de segurança. Consequências traçadas linha por linha: `security-scan.ps1` examinando **zero** arquivo e declarando as seis áreas cobertas com `exit 0`; `scan-historico.ps1` com `0 de 0 blobs lidos` **reconciliando** e passando pelo próprio guarda-corpo; `remote -v` vazio deixando um remoto público sair sem `ALTA`. O `security-reviewer` nomeou a assimetria: o mesmo arquivo é escrupuloso quando o `gh` falha e era cego quando o `git` falhava.

**Corrigido por classe:** `Invoke-Git` lança quando o git falha — `exit 2` pelo `trap`, o terceiro estado do ADR-0009 — e aviso com código `0` continua ignorado. As **oito** chamadas em que código `!= 0` é resposta (`check-ignore` ×4, `rev-parse --verify` ×3, `config --get-all`) usam `-PermitirFalha` explícito **e leem o código** — duas não liam, e o `qa-reviewer` pegou. Mais quatro guardas para o caso em que o git sai com `0` e contradiz o disco. Dois casos novos **plantam** a falha (o `.git` virando arquivo, o índice corrompido) e exigem `exit 2` sem relatório afirmativo — e um terceiro prova que repositório legitimamente sem commits **continua** funcionando, que é o fluxo normal do `/os:new-project`.

**`Get-CampoDoManifesto` falhava aberto**, e viaja para todo projeto governado: procurava a sequência de chaves sem exigir aninhamento real, então `verificacao.limites.erro_maximo_m` era satisfeito por um `limites:` de qualquer outro bloco. Ausente não virava padrão — virava **o valor de outro bloco**, enquanto o docstring afirmava fail-closed. Mais duas variantes do QA: escalar de bloco (`>`) devolvendo o indicador como valor, e filha mal indentada aceita. E os **dois leitores gêmeos divergiam**: `criterio_de_pronto: ""` virava `{}` em Python e lançava em PowerShell — rigor diferente conforme a linguagem, sobre o mesmo manifesto. Alinhados, com caso espelhado nas duas trilhas.

Mais cinco: o `bootstrap.ps1` morria antes do resumo com erro de sintaxe na suíte do projeto (a proteção existia no harness da plataforma e não no arquivo entregue); o runner do template mapeava só o código `5` do pytest como "não rodou"; o runner **da plataforma** não cumpria para si a guarda de vacuidade que impôs aos outros; o `New-ProjetoDeTeste` filtrava por extensão afirmando não filtrar; e o relatório de segurança se declarava "subfase 2.3" literal.

Dois tropeços meus, os dois pegos pela suíte: `"$codigo:"` numa mensagem é lido como variável qualificada por drive e dá `ParseError` — e o erro fez **toda** execução sair com `2`, então os dois casos novos que exigem `exit 2` passaram **por motivo errado**, e só o resto ficando vermelho denunciou. E os casos da trilha Python compartilham um `.venv`: um deles alterava o manifesto sem restaurar, e o seguinte passava sem exercitar o ramo. Agora quem mexe restaura, e a fixture confere que a condição existe antes de exigir o resultado.

#### Treze rodadas de revisão independente, e o padrão que elas expuseram

A 2.4 passou por **treze** rodadas com os dois revisores em contexto isolado, e o `qa-reviewer` reprovou **todas**. *(Esta frase já teve duas versões erradas. A primeira dizia "quatro" quando eram cinco. A segunda tentou detalhar quantas vezes o `security-reviewer` aprovou e quantas devolveu `INCONCLUSIVO`, e a soma dava seis para sete rodadas — o `qa-reviewer` conferiu a aritmética e apontou que os relatórios das rodadas anteriores nem estão versionados, então o número não é conferível no disco. Terceira tentativa, e a lição está na forma: **a contagem de rodadas fica, o placar por veredito sai.** Número em prosa que ninguém pode conferir é afirmação, não registro.)* Nenhuma rodada foi de graça, e o que elas mostraram não é uma lista de bugs: é uma **classe** de erro meu, com quatro aparições distintas.

**Afirmar corrigido o que não estava.** A linha de proveniência do relatório passou duas rodadas declarada como corrigida no `STATE.md` enquanto o artefato coletado dizia `(1 linhas) + 0 detectores`. Dois casos de teste passaram uma rodada chamando-se "as duas trilhas" com corpo que instanciava uma. E a contagem de testes voltou a existir em três lugares com dois números — as duas cópias erradas **adicionadas no mesmo commit** que devia protegê-las.

**Corrigir o sintoma e deixar o portão a jusante.** O `security-reviewer` nomeou isso melhor do que eu: a correção do balanço de cobertura acrescentou a **linha** de lacuna e esqueceu o **contador** que decide imprimir `(nenhuma)` — e o teste novo mediu a linha, não o contador. Terceira vez na plataforma.

**O que fecha a classe não é atenção, é guarda-corpo.** Entraram três: um caso que exige que a contagem corrente apareça **uma vez só** no `STATE.md` (o anterior conferia só o cabeçalho e não podia pegar prosa); um que **lê a linha `Gerador` do relatório gerado** e exige a contagem real e os seis detectores nomeados; e um que compara os **dois leitores gêmeos sobre a mesma entrada**, porque cinco das seis divergências entre eles só apareciam com o mesmo manifesto dos dois lados. Mais nomes de função distintos onde a confusão era possível de escrever — `Measure-LinhasDoArquivo` recebe caminho, `Measure-Linhas` recebe conteúdo.

**E o guarda-corpo pode ser imune ao defeito que o originou.** Este é o achado mais útil de todas as rodadas, e ele é recursivo: os dois guardas de símbolo órfão contavam referências no texto cru de todo `.ps1` do repositório — **inclusive no próprio arquivo do teste**, cujo comentário cita os símbolos pelo nome justamente para explicar por que o guarda existe. Reverter a correção deixava o símbolo com referências suficientes vindas do comentário do guarda: **verde com o defeito de volta**. A primeira emenda foi *menção em comentário não é chamador*. **Ela não fechou**, e a rodada seguinte mostrou por quê: a via seguinte era a **string literal** — a mensagem de asserção de um caso de teste citava o símbolo entre aspas, e sobrevivia inteira a qualquer despiste de comentário. Junto veio um terceiro campo órfão que ninguém sabia existir, `RedeConsultada`, que escapava porque a lista branca de inicializadores do regex não previa expressão entre parênteses.

**O conserto que fechou não foi a terceira emenda — foi trocar a pergunta.** Contar texto sempre precisa de uma lista de coisas-que-não-contam, e alguém tem de mantê-la: comentário, aspas, here-string, título de teste. Contar **chamada** não precisa de lista nenhuma. Os dois guardas passaram a usar `[System.Management.Automation.Language.Parser]`: um `CommandAst` é uma chamada e um literal não é; uma chave de tabela hash é um campo e uma janela de indentação não decide nada. A pergunta deixou de ser *"o nome aparece?"* e passou a ser *"alguém chama?"*.

De brinde, o parser enxerga função **aninhada** (que o regex de coluna zero não via), **não** enxerga definição dentro de here-string de fixture (que o regex contava como código real), e revelou que os quatro campos de cobertura de `scan-dado-pessoal.ps1` — declarados numa linha só, separados por `;` — **nunca tinham sido verificados por ninguém**. Lista branca é a classe de guarda-corpo que cobre menos do que promete, e o jeito de não ter esse problema é não ter lista branca.

**E o contrato pode estar escrito trinta linhas acima do defeito.** O último achado bloqueante da subfase foi esse: `security-scan.ps1` documenta, em comentário, que *"fato que emite linha na tabela de lacunas entra no acumulador do `(nenhuma)` **E** na coluna `Coberta`; são dois portões que consomem o mesmo fato; consertar um deixa o outro mentindo"* — e a lacuna de negação de `.gitignore`, criada seis rodadas antes, alimentava só o primeiro. Um projeto governado com `.gitignore` simples (`/output/*` mais `!/output/`) sairia com a coluna dizendo **`sim`** e, trinta linhas abaixo, a lacuna dizendo que a razão de nomes canônicos não vale ali. Falsa garantia na tabela que o protocolo manda ler primeiro. Passou verde treze rodadas porque **não dispara neste repositório** — aqui o `.gitignore` do template já força `parcial` por classe de caractere e `**` —, e o caso que existia mascarava pelo mesmo motivo. O conserto é uma cláusula; o que fecha é a fixture construída para que a negação seja a **única** lacuna, exigindo explicitamente a ausência das irmãs.

**E "lacuna declarada só em conversa não é lacuna declarada."** Os ramos-guarda sem par negativo estavam combinados com o revisor e ausentes da tabela de backlog do `STATE.md`. O que bloqueia não é a lacuna — é ela não estar escrita onde a próxima pessoa lê.

E dois defeitos nos meus próprios casos de teste, os dois pegos pela suíte: `-ne` entre strings no PowerShell é **case-insensitive**, e o guarda-corpo de uma fixture cujo assunto *era a caixa* acusou a fixture de não ter mudado nada; e o delimitador `VALOR_LIDO<...>` **colidia com o próprio valor** — a entrada `">"` produzia `VALOR_LIDO<>>` e o padrão não-guloso capturava vazio, acusando divergência inexistente. Canal de evidência que depende de o valor não colidir com o delimitador não é canal.

#### Correcoes obrigatorias antes da 2.5 — itens 26, 30 e 11 do backlog

**O scanner deixou de declarar como "examinado" o arquivo que ele nao consegue ler.** Os leitores de conteudo usavam `[System.Text.Encoding]::UTF8`, que troca byte invalido por `U+FFFD` em silencio: arquivo salvo em ANSI entrava na contagem de cobertura com todo padrao de credencial quebrado. A leitura agora recusa — e recusa **duas** coisas, porque a estrita sozinha nao basta: UTF-16 sem BOM de conteudo ASCII e UTF-8 valido byte a byte, e so a verificacao de `NUL` no texto decodificado o pega. Arquivo recusado sai como **lacuna nomeada**, com o caminho, e derruba a coluna `Coberta` das areas que dependiam dele.

E o leitor decide o **preambulo** ele mesmo, em vez de deixar o `StreamReader` decidir: com deteccao automatica ligada, o BOM de UTF-8 fazia o `StreamReader` descartar a codificacao estrita e voltar a leniente — os mesmos bytes eram recusados sem BOM e aceitos **com** BOM. O detector de **historico** tambem entrou: ele le `stdout` do `git cat-file` e ficou de fora da primeira passada, enquanto a tabela de teto ja afirmava completude sobre as seis areas. Os dois defeitos vieram da revisao independente, um de cada revisor, e nenhum dos dois da suite.

A linha de teto do relatorio foi reescrita, e agora em duas linhas: o que sobra e texto de byte unico cujos bytes por acaso formem sequencia UTF-8 valida — e, no `historico`, a recusa e por sinal **indireto**, porque ali o byte original ja se perdeu na decodificacao do console.

**A guarda que impede remoto publico passar sem achado `ALTA` ganhou par de execucao nos quatro estados que a alcancam** — tres `throw`, e o de `[remote` atingido por dois caminhos. Ela existia desde a 2.4 e nada provava que funcionava — foi escrita para responder a um achado, e o `security-reviewer` contestou a classificacao `BAIXA` por isso. Os estados que os casos montam: secao `[remote "x"]` sem chaves (o `git remote -v` fica mudo com codigo 0), a mesma secao vista de **worktree ligado** (unico estado em que `ComumDir` e `GitDir` diferem), `GIT_DIR` no ambiente com `.git` local irresolvivel (e o estado de todo hook do Git), e `.git/config` ilegivel como texto. As quatro regressoes foram reintroduzidas por mutacao e mortas pelos casos certos, um a um.

### Revisão pendente da 2.3 — rodou, e achou defeito real no mecanismo de exceção

O fechamento da 2.3 registrou uma lacuna `INCONCLUSIVO`: o mecanismo de exceções não passara pelos revisores porque o OAuth do CLI expirou. Com o `/login` renovado, a revisão rodou. **Ela não fechou de graça.**

Os **dois revisores convergiram independentemente** no mesmo achado, e a implementação **não cumpria a regra 2 do próprio ADR-0010**: a comparação de caminho era por **prefixo**, porque extraía o caminho do início de uma string de prosa (`arquivo linha ~N, ...`). Duas ampliações alcançáveis com uma linha de manifesto — exceção para `x.md` cobrindo `x.md-copia.md`, e `caminho: "docs"` funcionando como **allowlist de diretório**, o buraco recusado nominalmente. E o relatório *afirmava ao leitor* "correspondência exata de caminho E categoria", garantia que o código não entregava.

O teste que devia provar a regra usava dois nomes **sem prefixo comum**: passava com `StartsWith`, com `-like` ou com igualdade — verde sobre ramo não exercitado, a mesma classe de ponto cego que já tinha mordido no `-Out`.

**Causa raiz, não sintoma.** O problema não era o `StartsWith`: era extrair caminho de prosa. O achado passou a carregar `Caminho` como **campo estruturado** (`New-Achado`), e a comparação é igualdade. Achado sem caminho não casa com nada — falha fechado. O ramo perigoso deixou de existir.

Mais quatro correções, cada uma com teste que exercita o ramo:

- **Exceção nunca cobre `ALTA`.** O mecanismo é agnóstico de área, mas o campo se chama `dados_sensiveis_excecoes` e o ADR foi escrito em torno de dado pessoal: uma entrada com categoria de credencial dispensaria um `ALTA` de working tree e o scanner sairia com `0`. Limite por severidade, do lado de recusar. Alargar é decisão da mantenedora, em ADR.
- **`status` correto com campo faltando aparece no relatório, com o motivo.** A separação olhava só o `status`, então a entrada incompleta caía em "aceitas", era descartada em silêncio no casamento e nunca aparecia na subseção que a regra 4 exige — sem sinal que distinguisse "malformada" de "não casou".
- **Blob do histórico sem conteúdo passou a ser contado e declarado.** O `continue` silencioso deixava um candidato fora do balanço, e o relatório dizia "125 de 126 lidos" sem lacuna nenhuma. O `security-reviewer` derrubou `historico` para `INCONCLUSIVO` por isso, com razão: `-not $txt` também dispara para conteúdo `"0"` e para falha do `cat-file`.
- **Teto permanente passou a listar estrutura de diretório e nome de cliente corporativo.** Nenhum detector representa isso, e a consequência prática é que `-ParaPublicacao` com `exit 0` **não** significa publicável.

**`collect-diff.ps1` ganhou `-Contra <ref>`**, sem o qual esta revisão não teria evidência: com a árvore limpa o coletor comparava contra `HEAD` e produzia diff **vazio**. Revisão depois do commit é o caso normal de fechamento de subfase, não a exceção.

E dois tropeços meus, os dois pegos por teste: fixture com extensão `.old`, que o scanner não varre — o teste passava por ausência de achado em vez de por bloqueio; e um `replace_all` que pegou só uma das duas cópias do portão de aceitação, deixando para trás justamente a que trata lista de uma entrada. As duas armadilhas foram para o runbook.

#### Segunda rodada de revisão — e um terceiro defeito, também `ALTA`

Evidência nova sobre o código corrigido, revisores em contexto isolado, veredito anterior **descartado** porque o mecanismo mudou materialmente. O `security-reviewer` aprovou as seis áreas. O `qa-reviewer` **reprovou**: o parser YAML das exceções reconhecia o início de uma entrada **só quando `caminho` era a primeira chave**.

Fail-open, e composto. Numa lista de duas entradas com a segunda começando por `categoria`: a segunda entrada não era criada, o `caminho:` dela **sobrescrevia o da entrada 1**, e a entrada 1 mantinha o `status: "aceito-por-excecao"` já lido. A varredura passava a aceitar um par (caminho, categoria) que **ninguém decidiu**, com a lista de recusadas vazia — nenhum sinal no relatório. Reordenar chaves em YAML é a coisa mais natural do mundo, e nenhum teste verde pegaria isso.

**Causa raiz:** a entrada passou a ser reconhecida pelo marcador `-` de item de lista, em qualquer ordem de chaves, e o portão de aceitação (`status` exato **e** completude) é aplicado uma única vez a todas as entradas coletadas — não mais em duas cópias. Dois testes novos: segunda entrada com chaves fora de ordem não contamina a primeira; entrada única com chave antes de `caminho` é reconhecida.

O relatório também parou de dizer que os achados `ALTA` "foram avaliados": a recusa é **por severidade, antes de qualquer comparação com o manifesto**, e o texto agora diz isso.

#### Três fatos BAIXA declarados abertos pelo `security-reviewer`

Aprovação **com** itens latentes nomeados, registrados em `docs/STATE.md` e não corrigidos: o marcador de fixture é rota mais larga que o mecanismo de exceção (rebaixa `ALTA` sem exigir caminho, categoria ou justificativa, e sobrevive a `-ParaPublicacao`); `Test-ExcecaoCompleta` cobra 5 dos 9 campos que o ADR-0010 declara obrigatórios; e uma exceção cobre ocorrências ilimitadas no mesmo par (caminho, categoria). Estreitar cada um é decisão da mantenedora.

### Subfase 2.3 — scanner completo e `/os:security`

Fecha as **quatro áreas** que a 2.2 deixou explicitamente `INCONCLUSIVO`. Cada uma virou um detector próprio em `scripts/lib/`, como **função pura** — recebe o caminho, devolve achados, não escreve arquivo e não chama `exit`. O motivo é a política 4.1: detector embutido no meio de um script só se testa pela ponta, e foi assim que a 2.2 chegou a ter dois scripts sem um único teste funcional.

**Histórico do Git** (`scan-historico.ps1`) — `rev-list --all --objects` mais `cat-file`. O caso que faz o detector existir: apagar o arquivo e commitar **não** remove o blob, e varredura de working tree diz "limpo" exatamente aí. Também acusa nome sensível que existiu e foi removido. Achado que coincide com o working tree não é repetido, e a contagem de coincidências vai no relatório — suprimir sem contar seria esconder.

**`.gitignore` regra por regra** (`scan-gitignore.ps1`) — pergunta ao Git com `check-ignore`, em vez de interpretar o texto. Duas direções: para cada regra, uma sonda derivada dela e a pergunta "foi esta regra que decidiu?"; e uma lista de doze nomes de segredo canônicos com a pergunta "este repositório ignora isto, e **qual arquivo** aplica a regra?". A segunda pergunta achou uma falha de portabilidade que ler o `.gitignore` nunca mostraria: **proteção que vem do `excludesfile` global não viaja em clone nenhum**.

**Dado de terceiro** (`scan-dado-pessoal.ps1`) — CPF e CNPJ só com **dígito verificador válido**, telefone e CEP só pontuados ou anunciados por palavra-chave. É o que separa detector de gerador de ruído: sem validar o dígito, `111.111.111-11` e todo número de protocolo viram achado, e scanner que grita sempre é ignorado. E-mail é **classificado**, não acusado em bloco: quem assina os commits deste repositório é a identidade de quem mantém o projeto, e isso é **derivado do próprio `git log`** — não há lista de pessoas escrita em lugar nenhum, e derivado não envelhece.

**Exposição externa** (`scan-exposicao.ps1`) — visibilidade real do remoto pela API, webhook e endpoint em arquivo versionado, e credencial literal em configuração de CI. Ler `.git/config` dá a URL, não a visibilidade: visibilidade é estado do servidor.

**`ADR-0009`** — a escada de severidade e o que trava. Com quatro detectores novos, o scanner passou a produzir um tipo de fato diferente em natureza: guarda-corpo ausente, fixture declarada e identidade do autor não são exposição. Com a regra antiga de "qualquer achado sai com 1", **todo checkpoint desta plataforma falharia para sempre** por causa de uma fixture e do e-mail da autora. A linha ficou entre MEDIA e BAIXA; BAIXA aparece no relatório em seção própria e não trava — reclassificar, não silenciar. A política 4.6 ganhou a precisão, com ponteiro para o ADR.

**`/os:security`** — a sexta skill. Opera scanner e revisor sem substituir nenhum, decide o rigor pelo `project.yaml` (ADR-0007), aplica o veredito de três valores por área e trata `exit 2` como "a varredura não aconteceu", que não é uma variação de "falhou".

O relatório passou a declarar **cobertura por área**, nas mesmas seis áreas do veredito parcial do revisor, e a dizer quais modificadores reduziram a cobertura naquela execução.

#### Defeitos que a própria varredura encontrou no que acabava de ser escrito

- **O marcador de fixture podia ser desarmado por prosa.** A checagem era `Contains()` no arquivo inteiro, então `CHANGELOG.md` e `docs/STATE.md` — que **citam** o marcador para documentar a convenção — tiveram os achados reclassificados. Qualquer arquivo neutralizaria a varredura sobre si mesmo escrevendo uma frase. Agora declaração vale só no **cabeçalho**, e fixture com marcador no fim falha para o lado seguro.
- **Achado de histórico duplicado por blob:** 18 linhas para 3 arquivos. Agrupado por caminho, com a contagem de versões.
- **`gh` instalado e fora do PATH** deixava a visibilidade do remoto sem resposta com o `gh` na máquina.
- **Falso positivo de sombreamento** em `!/examples/` — o par que o Git exige para liberar diretório e conteúdo. Negação passou a ser julgada pelo **resultado**, não por quem decidiu.
- **Bug herdado da 2.2:** `rev-parse --short HEAD` em repositório sem commits derrubava o scanner com `exit 2` e sem relatório. É o fluxo normal do `/os:new-project`. Não havia teste de repositório sem commit para o scanner; agora há.
- **Cinco testes verdes por vacuidade.** `$SkillsEsperadas` era usada em cinco casos da suite `skills` e **não era definida em lugar nenhum** desde a modularização da 2.0: `foreach ($x in $null)` itera zero vezes e passa. A lista agora é descoberta do disco, e há um caso que prova que ela não está vazia.

`.gitignore` do repositório e do template ganharam `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519` e `service-account.json` — lacuna apontada pelo próprio detector no `.gitignore` da raiz, e levada ao template por analogia. No template, `*secrets*` saiu por ser redundante com `*secret*`, que já o subsome.

#### O que os dois revisores independentes acharam, e que os testes verdes não pegaram

Primeira vez que a plataforma se submete aos revisores que ela construiu na 2.2. Os dois **reprovaram**, e o mais valioso não estava em nenhum teste:

- **`security-reviewer` · o `.gitignore` do template não protegia `examples/` como o comentário prometia.** O bloco de binários de escritório vinha **antes** de `!/examples/**`, e o Git aplica o último padrão que casa: em todo projeto instanciado do template, uma planilha ou PDF real colocado em `examples/` **entrava no Git**, e o único guarda-corpo era o comentário. Confirmado com `check-ignore`: `examples/planilha.xlsx` não era ignorado. Ironia útil — essa é justamente uma das 4 regras que a sonda do detector não representa, então o scanner novo **não podia** achar. Corrigido movendo o bloco para depois da negação, com teste que pergunta ao Git em 12 caminhos concretos.
- **`qa-reviewer` · a deduplicação working tree ↔ histórico era código morto para dado pessoal.** As chaves eram populadas só pela varredura de credencial (`caminho|nome-do-padrão`) e o detector de histórico testava `caminho|categoria-de-dado-pessoal` na mesma lista: espaços de chave disjuntos, condição inalcançável. O dano não era estético — a área `historico` exibia o achado como se a exposição fosse **só** no histórico, e exposição só no histórico tem remediação destrutiva e diferente. Nenhum teste cobria a dedup em nenhuma direção. Corrigido, com par de testes, e o teste provado contra o código antigo em cópia isolada.
- **`qa-reviewer` · a coleta estava obsoleta e não se anunciava.** O working tree andou depois dos coletores, e o relatório seguiu descrevendo uma versão que já não existia; o revisor detectou por acaso, contando linhas. `collect-diff.ps1` passou a gravar um **carimbo de integridade** — bytes e linhas de cada arquivo descrito, em unidade que um revisor read-only consegue conferir sozinho — e o `qa-reviewer` foi instruído a começar por ele.
- **`qa-reviewer` · contagem de testes errada em três lugares, com três números diferentes.** A contagem passou a viver num único lugar, o cabeçalho do `STATE.md`, com teste que a confere contra o disco. O teste pegou o número errado na primeira execução.
- **`security-reviewer` · exceção de dado sensível só em comentário.** `dados_sensiveis: false` com a exceção explicada em prosa que nenhuma ferramenta lê. Virou o campo `dados_sensiveis_excecoes`, com teste que exige que cada caminho declarado exista em disco.
- Mais: limite de 400 linhas para arquivo novo deixou de fora justamente a suíte que **era** a evidência da subfase (agora parâmetro, default 800); `Get-CaminhoDoGh` quebrava com `exit 2` em host sem `ProgramFiles(x86)`; `estado.fase` do manifesto desatualizado; e o `-Out` do scanner apontando para fora do repositório derrubava a varredura — defeito herdado da 2.2, porque nenhum teste usava `-Out` externo.

**Uma lacuna de desenho que o `security-reviewer` levantou e que continua aberta:** o ADR-0009 não prevê **`MEDIA` aceita**. Se a decisão sobre o achado do relatório da Fase 0 for "registrar exceção e seguir", o scanner sairá com `1` neste repositório para sempre e todo checkpoint falhará — o mesmo modo de falha que o ADR foi escrito para evitar, uma camada acima. Registrado em `docs/STATE.md`; a decisão é da Emmily.

#### Terceira rodada de revisão: o furo que esta própria subfase repudiava

Com a evidência refeita e a árvore parada, os dois revisores voltaram. O `security-reviewer` aprovou `working tree`, `historico`, `staging` e `exposicao externa` — o que ainda reprova é o achado do arquivo de auditoria, que é decisão da Emmily. E acrescentou um fato que muda a decisão dela: **o arquivo já está em `HEAD` e `origin/main` = `HEAD`, então aquele blob já subiu para o GitHub** — o caminho de sanitizar só o working tree não fecha nada.

O `qa-reviewer` achou o pior defeito do ciclo: **o detector de `remoto PUBLICO` não tinha teste nenhum**, nem positivo nem negativo. As 24 invocações funcionais passavam `-SemRede`, e o único sinal de que ele funcionava era a execução real deste repositório, que exercita apenas o ramo `PRIVATE`. A plataforma afirmava a política 4.1 numa subfase inteira dedicada a impô-la, e a descumpria no próprio código. Pior: sem guarda, um `gh` que renomeasse o campo devolveria vazio com exit 0, a área seria declarada **coberta** com valor lixo e o achado `ALTA` nunca sairia — cobertura reduzida em silêncio. Corrigido com uma costura de teste declarada (`$env:OS_SCAN_GH`), guarda para resposta irreconhecível, e 4 casos: `PUBLIC`, `PRIVATE`, resposta vazia e `gh` que falha.

Mais cinco, todos com teste:

- **`rev-list --objects` imprime cada objeto uma vez, com um caminho só.** Depois de `git mv`, o caminho antigo do blob é invisível ali — e `filter-repo` no caminho novo deixaria o segredo no lugar. Medido e resolvido com `git log --all --find-object`, chamado só para blob que já produziu achado.
- **O relatório afirmava cronologia que o código não conhecia.** `"a partir do blob X"` vinha da ordem indefinida de uma hashtable: podia citar o blob mais novo, apontar quem fosse limpar o histórico para o ponto errado, e variar entre execuções sobre o mesmo repositório. Agora lista shas ordenados, rotulados como **não** cronológicos, com o comando que dá a linha do tempo de verdade.
- **A chave de deduplicação de dado pessoal era instável sob o marcador de fixture** — marcador adicionado num commit posterior tornava as chaves disjuntas outra vez, e o relatório passaria a emitir `MEDIA` bloqueante no histórico para sempre. Chave passou a usar a categoria base.
- **A pergunta dos nomes canônicos só alcançava a raiz.** Agora é feita em cada diretório com `.gitignore` próprio, e são **14** nomes, não 12 — o que torna a cobertura do template **detectada** em vez de analógica. E a sonda passou a representar `**`, `?` e classe de caractere (por um membro, declarado como tal).
- **`STATE.md` contradizia o `STATE.md`**: dizia que as 5 skills que faltam são das Fases 3 e 5, contra a tabela de roadmap 40 linhas abaixo, que põe `doctor` na 2.5 e `eval` na 2.9. Num arquivo cujo trabalho é ser a fonte de verdade para quem chega.

Mais o carimbo de integridade também no relatório de segurança, a contagem de blobs não-texto do histórico, a linha do histórico deixando de mostrar `0` enganoso quando há achados deduplicados, e `collect-diff.ps1` passando a usar a lista única de extensões de texto em vez de manter uma segunda com metade das entradas.

#### Quarta rodada: o guarda-corpo contra evidência velha disparava sempre

O `security-reviewer` fechou cinco das seis áreas — `working tree`, `historico`, `staging`, `.gitignore` e `exposicao externa` — sem nenhuma `INCONCLUSIVO`, e disse com essas palavras que **a 2.3 não introduz exposição nenhuma**. O que reprova é o achado pré-existente do relatório da Fase 0, que é decisão da Emmily, e ele acrescentou o fato que a decide: `.git/refs/heads/main` e `.git/refs/remotes/origin/main` são o mesmo sha, então **aquele blob já está publicado** — sanitizar só o working tree não fecha nada.

O `qa-reviewer` achou o defeito mais grave do ciclo, e ele estava **no guarda-corpo que a rodada anterior criou**: os dois coletores contavam linhas de formas diferentes (`ReadAllLines` contra `split "\n"`), e para arquivo terminado em newline o segundo dá +1. Resultado: o carimbo de integridade acusava coleta obsoleta em **todas as 27 linhas**, com a árvore parada e a coleta válida. Seguindo a instrução do revisor ao pé da letra, o veredito correto seria `INCONCLUSIVO` para sempre. E o único teste do carimbo fixava a convenção divergente e passava verde; o carimbo do relatório de segurança não tinha teste nenhum. Agora há uma função única, os dois relatórios declaram a convenção, e há teste com arquivo com newline final, sem newline final e vazio.

Mais quatro, todos com teste:

- **A deduplicação ignorava o valor.** A chave era `caminho|categoria`: um token **rotacionado** no mesmo arquivo — token novo hoje, antigo no blob — produzia a mesma chave, e o antigo era descartado como "coincidente com o working tree". Segredo rotacionado é o caso mais comum de segredo real, e ele desaparecia do relatório incrementando um contador. A chave passou a carregar uma **impressão** do conjunto de valores: hash truncado, nunca o valor, e nunca impresso.
- **`-Out` com prefixo comum ao repositório inventava achado bloqueante.** `"C:\projeto-relatorios\r.md".StartsWith("C:\proj")` é verdadeiro; sem separador, o destino virava "dentro do repositório", o caminho relativo virava `eto-relatorios\r.md` e saía um `MEDIA`. O teste anterior não pegava porque fixture e destino eram nomes irmãos sem prefixo comum.
- **O padrão de SharePoint travaria todo projeto governado que documentasse a origem dos dados.** Era `MEDIA`, e não existe `MEDIA` aceita — o modo de falha do ADR-0009 deslocado para os projetos que a plataforma governa, e o Programa é exatamente esse caso. Passou a `BAIXA`: URL de SharePoint exige autenticação, não é capacidade como um webhook. E 7 dos 8 padrões de exposição não tinham par negativo, contra a política 4.1 que esta subfase impõe — agora têm, mais teste positivo para `URL com credencial embutida`, que é `ALTA` e não tinha nenhum.
- **A costura de teste `$env:OS_SCAN_GH` não aparecia na linha de modificadores.** Uma variável esquecida na sessão faria o relatório afirmar `PRIVATE` com resposta fabricada e a área continuar "coberta" — costura ativa e não declarada é cobertura reduzida em silêncio, o mesmo defeito que esta subfase corrigiu no detector de visibilidade. O `collect-diff.ps1` também passou a declarar os parâmetros da própria invocação.

Mais: `check-ignore` em lotes de 150 sondas, porque uma linha de comando única estouraria o limite do Windows num repositório com muitas regras — e o efeito seria o pior possível, com toda regra virando um falso "sem efeito observável"; o par `!/examples/` + `!/examples/**`, que o Git exige junto, passou a ser verificado **pelo resultado, em conjunto**, com o relatório declarando que a atribuição individual não foi feita; e o rótulo `e-mail de terceiro` virou **`e-mail que não assina commits deste repositório`**, porque é o que o detector sabe: identidade derivada do `git log` nunca reconhece um segundo endereço da mesma pessoa, e o rótulo antigo apontava a remediação errada.

E dois erros meus no caminho, os dois pegos por teste: a **variável case-insensitive** do PowerShell outra vez — `$LOTE` e `$lote` são a mesma variável, então a fatia sobrescreveu o tamanho do lote e o contador do laço virou array, derrubando 52 casos de uma vez; e um texto novo do relatório (*"a visibilidade do remoto NÃO veio da API real"*) colidindo com a sonda de um teste, porque `-match` é case-insensitive. A primeira armadilha já estava escrita no runbook desta casa. Ambas agora com nome distinto e sonda ancorada.

#### Quinta rodada: o gêmeo esquecido e o manifesto decidindo pela mantenedora

Os dois revisores voltaram sobre a árvore parada. O `security-reviewer` fechou `working tree`, `staging`, `.gitignore` e `exposicao externa`, fechou as duas lacunas contingentes por inspeção própria — achou os 9 `.gitkeep` por `Glob` e leu todos, confirmando vazios — e corroborou o scanner de forma independente: `Grep` por domínios de e-mail devolveu 8 ocorrências em 6 arquivos, exatamente o conjunto do relatório. Nas palavras dele: *"Nada da subfase 2.3 bloqueia. Os 19 arquivos modificados e os 8 novos não introduziram um único achado que não seja fixture declarada. O que reprova é anterior a ela — e foi a própria 2.3 que passou a enxergá-lo."*

Dois achados novos, e o segundo é o mais sério de todo o ciclo porque é de governança:

- **`qa-reviewer` · o bug de prefixo do `-Out` foi corrigido num coletor e o gêmeo ficou esquecido.** A rodada anterior consertou `security-scan.ps1` e deixou a linha idêntica viva em `collect-diff.ps1`, sem guarda. Dois efeitos medidos: destino com prefixo comum ao repositório fazia o coletor declarar **uma lacuna que não existe** e sair com `1`, que a skill `/os:checkpoint` lê como coleta incompleta; e destino inteiramente fora fazia `git check-ignore` recusar com *"is outside repository"*, derrubando o script pelo `trap` com `exit 2` **e sem relatório**. Coletor que morre ou inventa lacuna produz `INCONCLUSIVO` com a árvore parada — o mesmo modo de falha que o carimbo de integridade acabara de eliminar.
- **`security-reviewer` · o manifesto declarava decidido o que ninguém decidiu.** `dados_sensiveis_excecoes[0].decisao` dizia *"mantido em repositório privado"* enquanto o `STATE.md` diz textualmente **"Nada foi feito"** e que a escolha é da Emmily. O perigo era concreto e não hipotético: o próprio `STATE.md` prevê esse campo passar a ser lido pelo detector para reclassificar o caminho para `BAIXA`. Com a contradição de pé, **o scanner silenciaria automaticamente um achado que ninguém decidiu aceitar** — numa plataforma de criticidade alta que governa outros repositórios. O campo virou `status: "pendente-decisao-da-mantenedora"`, e há teste que proíbe qualquer status de aceitação enquanto o `STATE` disser que nada foi feito, **e** proíbe qualquer detector de ler o campo enquanto houver exceção pendente. *(Estado intermediário desta rodada. A decisão foi tomada logo depois — ver **Fechamento da 2.3**, abaixo: hoje o status é `aceito-por-excecao`, com o mecanismo do ADR-0010.)*

Mais três, todos com teste onde cabia:

- **`-MaxLinhasArquivoNovo`, `-Out` e o truncamento do diff não tinham nenhum caso** — os três guarda-corpos que decidem se código novo chega ao revisor, e a falha real desta subfase (o limite de 400 escondeu justamente a suíte que *era* a evidência) foi dessa classe. Agora têm par positivo e negativo.
- **A coluna "Coberta" dizia `sim` incondicionalmente** para `working tree` e `dado de terceiro`, enquanto a seção de lacunas da mesma execução declarava arquivos sem conteúdo lido. Dois sinais contraditórios no mesmo documento, e a tabela é o que se lê primeiro. Passou a `**parcial**`, como as linhas vizinhas já faziam.
- **O contador de coincidências era irreconciliável:** dizia "23" enquanto havia 21 linhas de achado, porque conta por blob × caminho × categoria e não por fato distinto. O rótulo agora diz isso. Número que não fecha convida à desconfiança do relatório inteiro.

O `security-reviewer` também **contestou um achado para baixo**: o e-mail `dynatest.com.br` no relatório da Fase 0 é o endereço corporativo da própria mantenedora, não de terceiro — e por ADR-0009 identidade do próprio autor é `BAIXA`. O detector não tinha como saber, porque identidade derivada do `git log` só conhece quem assinou commit. Então é **um** achado `MEDIA` de dado de terceiro, não dois. E `.npmrc`, `.netrc` e `.pypirc` entraram na lista de nomes de texto para terem o **conteúdo** examinado — pelo conteúdo e não pelo nome, porque `.npmrc` sem token é comum e legítimo.

#### Sexta rodada: a terceira área com cobertura reduzida em silêncio, e o manifesto contra o próprio schema

O `security-reviewer` **fechou as quatro lacunas contingentes por inspeção própria** — inventariou os 9 arquivos sem extensão por `Glob`, confirmou que são todos `.gitkeep` vazios, fechou o blob único do histórico por aritmética verificável (9 caminhos idênticos e vazios ⇒ um só objeto, e o blob vazio canônico `e69de29b…` está presente em `.git/objects/`), e localizou as duas classes de caractere (`*.py[cod]`, sem semântica de segredo) e as duas negações irmãs (`!/logs/.gitkeep`, `!/artifacts/.gitkeep`). **Nenhuma área ficou `INCONCLUSIVO`**, e ele disse o que reabre cada uma. Cinco das seis áreas aprovadas, e o veredito dele sobre a subfase: *"Não bloqueia o commit da subfase 2.3. O achado que reprova está em `docs/audits/…`, que não aparece entre os 19 modificados nem os 8 novos."*

Quatro achados novos, e os dois primeiros são de governança:

- **`dados_sensiveis: false` contradizia a definição do próprio schema.** O template define o campo como *"true se toca dado corporativo/pessoal de terceiro"*, e este repositório toca — a exceção declarada logo abaixo diz isso. Ficou `false` por um raciocínio que parecia razoável e não era: *"o código-fonte da plataforma não contém dado corporativo"*. O campo não pergunta sobre o código-fonte, pergunta sobre o repositório. Aqui não houve subverificação porque `criticidade: alta` já forçava `qa+security`; o problema é o padrão, porque **ferramenta que lê só o booleano deriva rigor menor** — e esta plataforma governa outros repositórios. Agora é `true`, com a distinção entre os dois campos preservada e **explicada**: cada um é verdadeiro pelo seu próprio motivo. E há regra mecânica: exceção declarada **força** `dados_sensiveis: true`.
- **`dados_sensiveis_excecoes` era formato paralelo.** O cabeçalho do manifesto abre com *"Não existe formato paralelo para a plataforma"* — e o campo tinha nascido na plataforma e não no schema do template. Consequência concreta: projeto governado que toque dado de terceiro **não tinha onde declarar exceção**, e o `/os:new-project` não perguntaria. O campo foi para o template, a skill passou a instruir, e um teste novo transforma a frase do cabeçalho em regra verificada: **nenhuma chave de `classificacao` pode existir na plataforma e não no template.**
- **A terceira área ainda reduzia cobertura em silêncio.** A rodada anterior corrigiu `working tree` e `dado de terceiro`; `exposicao externa` descartava arquivo sem extensão com um `continue` sem contador, e a coluna dizia `sim`. Cenário do revisor: um `deploy.conf` rastreado com um webhook dentro — conteúdo não lido, nenhuma lacuna declarada, e o revisor aprovando a área com base numa declaração falsa. Corrigido com par positivo e negativo.
- **`docs/STATE.md` dizia "3 MEDIA"** quando a varredura dizia 2 e a contestação aceita fazia 1. Três lugares, três números, outra vez — e a consequência é operacional: o número esperado de bloqueantes é o único sinal que separa *"trava conhecida"* de *"trava nova"*. A correção não foi acertar o número: foi **trocar contagem por identidade**. O `STATE` agora nomeia o único bloqueante conhecido pela localização e categoria; qualquer bloqueante com outra identidade é novo e interrompe. Identidade não envelhece.

Mais dois de guarda: o `.gitignore` da **raiz** ganhou teste que pergunta ao `git check-ignore` pelos 14 nomes canônicos — antes só o template tinha, e apagar as 5 linhas novas da raiz deixaria os testes verdes com o único sinal sendo um `BAIXA` que por ADR-0009 não trava; e uma sonda solta (`-match '\*\*parcial\*\*'`, que casava com qualquer linha da tabela) foi ancorada na célula da área.

E o teto permanente ganhou a linha que faltava: **`rev-list --all` alcança só objeto referenciado por ref**, então segredo em commit pendurado após `commit --amend` ou `reset --hard` não é varrido — não vai para o remoto, mas fica no disco local até o `gc`.

#### Fechamento da 2.3 — as três decisões da Emmily

**1. O achado do relatório da Fase 0: aceito por exceção (`ADR-0010`).** Repositório privado, uso permitido no ambiente dela, e reescrita de histórico recusada para este achado — destrutiva e desproporcional. O fato que descartou o caminho barato foi verificado pelo `security-reviewer` por leitura própria dos refs: `main` e `origin/main` são o mesmo sha, então o blob já está no remoto e sanitizar o working tree não desfaria nada.

**2. Mecanismo de exceção legível por máquina, estreito e auditável.** A exigência dela foi explícita: sem allowlist genérica por padrão ou domínio, exceção vinculada a caminho/categoria/justificativa/decisão, citável no relatório, e sem correspondência exata o achado continua bloqueando.

O que foi construído, e cada regra existe contra um modo de falha concreto:

- **Não silencia.** O achado continua no relatório, com a **severidade original**, em seção própria — *"Achados ACEITOS POR EXCEÇÃO"* —, citando justificativa, decisão e data. O que muda é a **disposição**, não o que o achado é. Separar severidade de disposição é o que torna o relatório honesto.
- **Correspondência exata de caminho E categoria**, por igualdade — não prefixo, não glob, não domínio. Achado da mesma categoria em outro arquivo continua bloqueando; categoria diferente no mesmo arquivo continua bloqueando.
- **Nove campos obrigatórios.** Faltando qualquer um, a exceção não cobre nada — `status: "aceito-por-excecao"` com o resto vazio seria allowlist de uma linha.
- **`status` com valor único e exato.** `aceita`, `aprovado`, `ok` não contam: status aproximado abre a porta para aceitação por descuido de digitação.
- **`-ParaPublicacao` ignora toda exceção.** Publicar exige sanitização, não exceção. Verificado nos dois modos no repositório real: privado `exit 0`, publicação `exit 1`.
- **Aplicado num lugar só**, no orquestrador, depois de todos os detectores. Nenhum detector conhece exceção — eles só acham. Cada detector segue testável em isolamento, e a regra de aceitação fica num ponto auditável.

**Oito testes**, incluindo os quatro que ela pediu nominalmente: a exceção exata é reconhecida; achado parecido em outro arquivo continua bloqueando; o achado aceito continua no relatório com a severidade original e a citação; publicação continua exigindo sanitização. Mais quatro de borda: categoria diferente no mesmo arquivo, `status` pendente, campo obrigatório faltando, e o par negativo do mecanismo inteiro — repositório sem exceção nenhuma bloqueia igual.

`dados_sensiveis_excecoes` está no **schema do template**, com os nove campos documentados, e o `/os:new-project` instrui a nunca escrever `status: "aceito-por-excecao"` por conta própria: aceitar risco é decisão dela, e `decidido_em` registra quando ela decidiu, não quando alguém preencheu.

**3. CSV em `examples/`: liberado só em caminho declarado.** `*.csv` volta a ser ignorado dentro de `examples/`, e apenas `examples/fixtures/` e `examples/synthetic/` o liberam — os dois criados no template com `.gitkeep`, para a convenção ser visível em todo projeto instanciado. O **caminho** passou a ser o guarda-corpo em lugar do comentário, que era a mesma forma do defeito achado com `.xlsx`. Binário de escritório continua barrado mesmo lá dentro. Provado por `git check-ignore` em mais de 20 caminhos concretos.

**Lacuna declarada no fechamento:** o mecanismo de exceção **não passou por revisão independente**. A sessão OAuth do CLI expirou em 2026-09-09, e os revisores só são acionáveis por `claude -p --agent`, porque a ferramenta `Agent` do app desktop não os endereça. As cinco rodadas anteriores cobrem tudo **menos** este mecanismo, que nasceu depois delas. Registrado como `INCONCLUSIVO` no `STATE.md` — ausência de evidência não é aprovação, e 12 testes mais verificação determinística nos dois modos não substituem revisor independente.

**Todos os testes passando** — a contagem vive só no cabeçalho de `docs/STATE.md`, com teste que a confere contra o disco.

E é reincidência registrada: esta entrada dizia "154/154" quando a execução real dava 156. O `qa-reviewer` pegou, e a ironia é exata — a própria subfase centralizou a contagem porque *"número repetido em prosa é número que envelhece"*, e repetiu o número na entrada de CHANGELOG que descreve isso. Número removido em vez de corrigido: corrigir envelheceria de novo.

### Handoff pré-compactação

`docs/runbooks/gotchas-windows-powershell.md`: as armadilhas de Windows, PowerShell 5.1, Git e Claude Code que custaram tempo real nas Fases 1 e 2 e que só existiam em comentários espalhados ou no contexto de uma conversa. Referenciado pelo `CLAUDE.md`, para quem for escrever `.ps1` encontrar antes de tropeçar.

`docs/STATE.md` recebeu os **critérios obrigatórios da subfase 2.3**: os quatro pontos hoje `INCONCLUSIVO` (histórico do Git, `.gitignore` regra por regra, dado pessoal de terceiro, exposição externa), com a regra de que nenhum deles pode ser forçado a `PASS` — se não for verificável deterministicamente, mantém `INCONCLUSIVO`, documenta o limite e propõe a camada complementar. Registrou também a lista de bloqueio textual do `security-reviewer`, o que já foi fechado nela, como os coletores são acionados hoje (manualmente, sem hook) e a convenção do marcador de fixture.

Nada necessário para continuar a 2.3 depende de conversa.

### Manifesto da própria plataforma

Defeito apontado pelos **dois** revisores independentes na 2.2: a plataforma exigia `project.yaml` dos projetos governados e não declarava o próprio. Uma plataforma que se dá uma exceção que não concede a ninguém.

`project.yaml` criado no **mesmo schema** de `templates/project-standard/` — sem formato paralelo: se o schema não serve para a plataforma, não serve para os projetos dela.

A distinção que o manifesto torna explícita: **`criticidade: alta` é operacional, não classificação de dados.** A plataforma decide como projetos são criados, versionados, revisados e publicados — inclusive corporativos —, então um defeito nela não quebra um projeto: quebra a garantia de todos. Mas `dados_sensiveis: false`, porque o código-fonte dela não contém dado corporativo. A única exceção está declarada: o relatório da Fase 0 descreve estrutura de pastas Programa/Dynatest, é compatível com repositório privado (ADR-0003) e veda publicação sem sanitizar.

Estado real, nada prometido: `ci: false` (não existe `.github/workflows/`), `evals: false` (não há comportamento probabilístico para medir), `hooks: 0` (subfase 2.6), `integration_tests: false`. Derivado: `revisao_independente: qa+security`, por criticidade alta (ADR-0007).

**Sete testes de regressão**, com o mais importante conferindo cada capacidade declarada **contra o disco**: `ci` contra a existência de `.github/workflows`, `evals` contra casos em `evals/`, contagem de skills e agents contra as pastas, `hooks` contra `hooks/hooks.json`. Manifesto que promete o que não há é o modo mais barato de mentir para quem chega, e agora é detectável.

Mais três: a versão do manifesto tem de bater com a tag mais recente; manifesto, `STATE.md` e `CHANGELOG.md` não podem divergir — foi exatamente o defeito que a retomada em contexto isolado achou na Fase 1; e a criticidade não pode colapsar com a classificação de dados.

Quatro detectores provados em cópia isolada: manifesto ausente acusa; `ci: true` sem workflow acusa; 9 skills declaradas com 5 no disco acusa; versão divergente da tag acusa em dois testes.

Efeito colateral verificado: o `collect-diff.ps1` passou a ler criticidade e rigor do manifesto, e a lacuna que ele declarava a cada execução desapareceu — **lacunas: 1 → 0**.

**89/89 passando.**

### Subfase 2.2 — revisores read-only e coletores determinísticos

Decisão da Emmily, com o trade-off apresentado antes da implementação e registrada em **ADR-0008**: os dois revisores são **estritamente read-only** (`tools: Read, Grep, Glob`), e toda execução determinística fica fora deles.

O fato que decide o desenho: **agente de plugin ignora `permissionMode`, `hooks` e `mcpServers` em silêncio**, então `tools` é o único limite de privilégio real. E `Bash` é acesso de escrita — um revisor com `Bash` não é read-only, e chamá-lo assim documentaria uma garantia inexistente.

**Adicionado**

- `agents/qa-reviewer.md` e `agents/security-reviewer.md`.
- `scripts/collect-diff.ps1` — materializa diff, status, arquivos novos e a **saída real** dos testes.
- `scripts/security-scan.ps1` — versão **mínima**, 6 detectores, com o escopo não varrido declarado.
- `tests/suites/agents.ps1` (17 casos declarativos) e `tests/suites/collectors.ps1` (15 casos de **execução real**).
- Política 4.5: **ausência de evidência não é aprovação.** Veredito em três valores — `APROVADO`, `REPROVADO`, `INCONCLUSIVO` — por área, e o global é o pior dos parciais.

**Verificação em execução, não por declaração**

- `plugin validate --strict` aprovado; `Total plugin agents loaded: 2`.
- O read-only foi testado **no runtime**: pedi ao `security-reviewer` para rodar `git log`. Resposta: *"Não tenho ferramenta para rodar comandos shell"*, e listou as três que tem. A restrição é real, não declarada.
- Os 6 detectores do scanner exercitados contra fixture com credenciais fabricadas.
- Três detectores da suíte `agents` provados em cópia isolada.

**O `qa-reviewer` reprovou a primeira tentativa, e estava certo**

Builder ≠ Evaluator aplicado à subfase que o construiu. Oito defeitos que eu não tinha visto:

| # | Achado | Correção |
|---|---|---|
| B1 | **Os dois scripts novos não tinham teste funcional nenhum.** Os 17 casos eram regex sobre o texto-fonte — verificavam que a string `ls-files --others` aparece no arquivo, não que a função funciona. **Viola a política 4.1 que eu escrevi na subfase anterior.** | Nova suíte `collectors.ps1`: 15 casos de execução real contra fixtures, com par positivo e negativo |
| A1 | `collect-diff.ps1` **abortava em repositório sem nenhum commit** (`fatal: ambiguous argument 'HEAD'`) — que é o fluxo normal: `/os:new-project` roda `git init` e para, então o primeiro checkpoint acontece antes do primeiro commit. E o exit 1 do abort era indistinguível do exit 1 que significa "coletou com lacunas" | Guarda de `rev-parse --verify HEAD`; sem HEAD, todo arquivo entra como novo; `trap` que sai com 2 em erro inesperado |
| A2 | Fence fixo de três backticks na seção de arquivos novos: um arquivo que contém ``` fechava o bloco no meio e o resto do relatório alternava código e prosa. **Aconteceu de verdade** ao coletar os próprios agentes e o ADR-0008 | Fence calculado a partir do conteúdo |
| A3 | A tabela de rigor do `/os:checkpoint` não tinha linha para **campo ausente** — e esta plataforma não tem `project.yaml` | Campo ausente agora é tratado como `qa+security`: ausência de declaração não é permissão |
| A4 | Os coletores escreviam em `artifacts/review/` sem verificar se o destino está ignorado no repo-alvo. Repos anteriores ao template não ignoram, e o relatório contém o diff completo | Checagem de `check-ignore`, com lacuna declarada ou achado MÉDIA |
| B4 | O ramo de remoção de BOM que eu havia acrescentado ao harness era **código morto com diagnóstico errado** — `ReadAllText(path, Encoding.UTF8)` já consome o BOM. Verifiquei: um arquivo `EF BB BF` devolve `-` como primeiro char | Removido, com o diagnóstico real no lugar |
| D2 | O diff **removeu** a expressão "em contexto isolado" da tabela de rigor — o mecanismo nomeado pelo ADR-0007 | Restaurada, com a nota de que é mecanismo e não estilo |
| C2 | Caminho da máquina (`C:\AI-WORKSPACE\ai-lab\conversor-utm`) embutido no `.EXAMPLE` de script distribuído por plugin | Substituído por placeholder |

Dois bugs meus foram achados pelos **próprios testes funcionais** ao rodarem pela primeira vez: `TrimStart('\\','/')` — o PowerShell não usa `\` como escape, então `'\\'` são dois caracteres e não convertem para `Char` — e o aviso de CRLF do `git` em stderr virando erro terminante sob `ErrorActionPreference='Stop'`.

**O `security-reviewer` achou um ponto cego estrutural**

Segunda revisão independente, e o achado ALTA é o mais importante da subfase:

> **O scanner iterava só `git ls-files` — arquivos rastreados.** Os 6 arquivos novos da 2.2 eram não rastreados, então o scanner **nunca leu o código sob revisão.** Nas palavras dele: *"aprovar a 2.2 com base neste relatório seria aprovar precisamente o que ele não leu."*

Corrigido: o scanner passou a varrer rastreados **e** não rastreados, marcando cada achado com a origem. Arquivos examinados: 44 → 51. Arquivo ignorado pelo `.gitignore` continua fora de propósito — não vai para o remoto.

E, ao ganhar visão dos não rastreados, o scanner imediatamente acusou as **próprias fixtures de teste** — que o revisor havia previsto no mesmo relatório. A solução **não** foi allowlist que silencia: um arquivo pode declarar o marcador `SEGREDO-FABRICADO-PARA-TESTE` e os achados dele são **reclassificados** para BAIXA, com categoria própria, **continuando no relatório**. O revisor exigiu prova de que isso não engole segredo de verdade, e há teste: o mesmo conteúdo com e sem marcador, e em ambos o achado aparece. O relatório também avisa que o marcador é *afirmação de quem escreveu o arquivo, não verificação*.

Outros achados dele, resolvidos:

- **Relatórios defasados** em relação ao disco (`collectors.ps1` criado depois da coleta). Recoletados.
- **Três commits pós-Fase 1 nunca varridos com ferramenta de histórico.** Varredura manual sobre todos os blobs de toda a história: limpo. Nenhum arquivo sensível introduzido.
- **Visibilidade do remoto era declaração do `STATE.md`, não evidência.** Confirmada pela API: `isPrivate: true`. Ele não podia verificar — não tem `gh`, por desenho — e corretamente registrou como `INCONCLUSIVO` em vez de assumir.

Áreas que seguem `INCONCLUSIVO` por ausência de evidência, e são o escopo declarado da 2.3: histórico do Git, eficácia do `.gitignore` regra por regra, dado pessoal de terceiro, e exposição externa. **Isso não é aprovação parcial** — é o mecanismo da política 4.5 funcionando na primeira vez que foi usado de verdade.

**82/82 passando** (eram 46).

### Subfase 2.1 — política de verificação e Builder ≠ Evaluator

**`docs/VERIFICATION-POLICY.md`** passa a ser a fonte única do que conta como verificado. A definição: **verificado = executado e observado**. O documento nomeia os quatro modos de falha que a Fase 1 produziu de verdade — comando documentado e nunca rodado, pasta de verificação vazia, teste que nunca foi visto falhar, e estrutura conferida só no lugar onde foi construída.

Regras que passam a valer sempre:

- **Todo detector precisa de teste positivo e negativo.** Scanner que nunca acusou nada não foi testado, foi só executado.
- **Verificação em clone limpo antes de handoff ou release.** Verificar no lugar onde a coisa foi construída tem ponto cego estrutural: herda o ambiente de quem construiu. Foi assim que apareceu o bug de BOM da Fase 1, com 27 testes verdes.
- Teste que falha interrompe checkpoint, release e push. Achado de segurança interrompe sempre, qualquer que seja a criticidade.
- Pasta de verificação vazia não conta, e `evals/` sem sujeito não deve ser criada.
- O que a verificação não cobre vai escrito na seção Parcial do `STATE.md`.

**ADR-0007** define onde fica a linha do Builder ≠ Evaluator, derivada de `classificacao.criticidade`: `baixa` dispensa revisão independente, `media` exige QA, `alta` exige QA e security, e `dados_sensiveis: true` força QA e security qualquer que seja a criticidade. O mecanismo é **contexto isolado**, e a ignorância do revisor é o instrumento — se ele souber que algo já foi testado, não testa.

O ADR se sustenta em quatro evidências da própria Fase 1, não em princípio abstrato. As duas decisivas: o bug de BOM passou por 27 testes verdes porque a mesma cabeça escreveu código e teste; e o `project.yaml` desatualizado só apareceu quando um agente sem acesso a nenhuma conversa leu o repositório.

Ligações, para a política não ficar órfã: `templates/project-standard/CLAUDE.md` e `project.yaml` (novo campo derivado `verificacao.revisao_independente`), `skills/new-project`, `skills/checkpoint` (o passo de QA agora consulta o campo antes de reler o diff) e `docs/ARCHITECTURE.md` §6 e §7, que passaram a apontar para a fonte em vez de repetir a tabela.

Nova suíte `tests/suites/policy.ps1`, 10 casos. Três deles existem contra o modo de falha mais provável de documentação: a política ficar órfã, a tabela ser duplicada em outro lugar e divergir, e a matriz criticidade→revisão discordar entre política, ADR e template.

Aplicando a regra 4.1 à própria entrega, três detectores foram provados em cópia isolada do repositório: quebrar a referência da política acusa; reintroduzir a tabela duplicada acusa; apagar o ADR-0007 acusa.

Um defeito meu pego pelo teste da Fase 1: adicionei `{{REVISAO_INDEPENDENTE}}` ao template e não o documentei na tabela de placeholders da skill — exatamente a classe de erro que aquele teste passou a existir para pegar, no commit anterior.

**46/46 passando.**

### Subfase 2.0 — modularização dos testes

`tests/run-tests.ps1` tinha 477 linhas num arquivo único, e cada subfase da Fase 2 depositaria mais testes nele. Dividido em seis suítes por área (`tests/suites/`), com harness compartilhado (`tests/_harness.ps1`) e runner raiz que descobre as suítes.

- Execução completa, seletiva (`-Suite security`), múltipla (`-Suite skills,docs`) e listagem (`-List`).
- Ordem deliberada — do que sustenta tudo para o que depende de tudo — para que a primeira falha aponte a camada mais provável.
- 35 casos preservados na divisão, mais 1 novo: detecta deriva entre as suítes em disco e a lista de ordem do runner.
- Três testes estavam na seção errada — falavam de skill e moravam na seção de template — e foram para `suites/skills.ps1`.

Dois defeitos meus, ambos pegos pelos próprios testes:

- A exceção do teste de sintaxe do PowerShell 7 apontava para `run-tests.ps1` por **nome**, e ficou obsoleta na divisão: o arquivo que cita os padrões proibidos passou a ser `suites/scripts.ps1`. Substituída por um marcador que o arquivo declara sobre si mesmo, com limite de um por repositório para não virar porta de silenciamento.
- Erro de suíte inexistente saía como stack trace. Agora imprime os nomes válidos e sai com código 2.

Verificado nos dois sentidos: a deriva é detectada quando existe, e uma suíte que falha não impede as outras de rodar.

### Preparação da Fase 2 — o que a pesquisa de documentação mudou no plano

- **`claude plugin eval` está em early access** e não habilitado nesta conta. A infraestrutura de evals será o formato compatível com o runner nativo mais um runner conversacional leve e explicitamente temporário. Registrado também que o runner nativo **publica o relatório no claude.ai por padrão** — `--no-publish` precisa ser regra escrita, não lembrança.
- **Branch protection e rulesets exigem GitHub Pro** em repositório privado (403 verificado em três chamadas de API). A disciplina de PR será client-side, por hook e skill, com a limitação registrada em ADR.
- **Agentes de plugin ignoram `permissionMode`, `hooks` e `mcpServers`** em silêncio. O campo `tools` é o único limite real — decisão de desenho para o `security-reviewer`.
- **Hooks de plugin disparam**, verificado com plugin descartável: `Registered 2 hooks from 2 plugins`, e o `SessionStart` criou o arquivo de prova. Era a maior premissa técnica da Fase 2.
- Versões atuais das actions: `checkout@v7`, `setup-python@v7`, `upload-artifact@v7`, `cache@v6` — não `@v4`, que é o que eu escreveria de memória.

## [0.1.0] — 2026-09-08 — Fase 1, Fundação

Primeira versão validada ponta a ponta. Bloco H (remoto no GitHub) pendente da autenticação da Emmily.

### Bloco I — teste de aceitação em projeto descartável

Projeto `ai-lab/conversor-utm` criado pelo `/os:new-project` e levado pelos 11 passos: estrutura, Git, `project.yaml`, `CLAUDE.md`, `STATE.md`, `/os:status`, alteração real, `/os:checkpoint`, `/os:handoff` e retomada em contexto isolado.

Veredito da retomada, por um agente sem acesso a nenhuma conversa: **"Sim — um desenvolvedor novo continua este projeto sozinho, só com o repositório."**

O ciclo achou três coisas que nenhum teste interno da plataforma acharia:

1. **Um teste que eu escrevi estava errado, não o código.** Presumia que declarar o fuso UTM errado seria detectável; não é, porque a longitude de saída é por construção próxima ao meridiano central do fuso declarado.
2. **Um bug real de encoding**, achado pelo passo de portabilidade em clone limpo e não pelos 27 testes que já passavam: CSV com BOM (Excel, PowerShell) quebrava a leitura, e o erro apontava para o lugar errado (`colunas ausentes: ['Este']`).
3. **`project.yaml` mentindo sobre a própria versão**, porque a skill de checkpoint nunca mandava atualizá-lo — e é dele que `/os:status` e `/os:handoff` leem.

### Bloco J — 8 defeitos corrigidos, cada um com teste que impede a volta

| Defeito | Causa raiz | Correção |
|---|---|---|
| `{{PROJECT_TITLE}}` sobreviveu em `.env.example` e `.gitignore` | `/os:new-project` mandava substituir em `*.md`, `*.yaml`, `*.ps1` — dotfile não casa com nenhum | A skill agora proíbe filtrar por extensão e exige `grep -rn '{{'` com saída vazia como critério |
| `project.yaml` desatualizado após checkpoint | `/os:checkpoint` passo 5 só citava `STATE.md` e `CHANGELOG.md` | Passou a exigir os **três**, com `versao` e `ultimo_checkpoint` |
| Comando de teste documentado que não funcionava | `bootstrap.ps1` não criava venv nem instalava dependências | Bootstrap ganhou seção de ambiente Python; a skill exige **rodar** o `{{TEST_CMD}}` antes de fechar |
| Template sem `requirements.txt` | — | Criado, com orientação de fixar teto de versão |
| Template sem `CHANGELOG.md`, exigido pela skill de checkpoint | — | Criado |
| `project.yaml` nascia com `versao: "0.1"` | Contra o SemVer do ADR-0006 | `"0.1.0"` |
| `CLAUDE.md` do template exigia deleção manual de linhas | Forma genérica em vez de placeholder | Virou `{{VERIFICACAO_TESTS}}` / `{{VERIFICACAO_EVALS}}` / `{{VERIFICACAO_SECURITY}}` |
| Nenhum dado de exemplo possível | `.gitignore` bloqueava `*.csv` sem exceção | Liberado `examples/`, com regra escrita: só dado fabricado |

Mais uma armadilha documentada na skill `/os:handoff`: o handoff não pode citar o commit que o contém, porque nasce antes dele.

### Validação

- Testes internos: **35/35** (eram 28).
- `claude plugin validate --strict`: aprovado, no marketplace e nos componentes.
- `claude --plugin-dir`: `Loaded 5 skills from plugin os default directory`, e o aviso `Skill listing over budget` desapareceu após o encurtamento das descrições.
- Cópia instalada refrescada e conferida contra o repositório.
- Descoberto e documentado: `claude plugin update` sem bump de `version` é **no-op silencioso**; refrescar no mesmo número exige `uninstall` + `install`.

---

## [Não lançado anteriormente] — Fase 1, blocos A–G

### Revisão de 2026-09-08 (pedida pela Emmily antes do primeiro checkpoint)

**Skills, não `commands/`.** A pasta `commands/` foi **removida**. A documentação atual do Claude Code é explícita: `commands/` é a forma antiga e plana de skills (*"Use `skills/` for new plugins"*), não uma camada de atalho sobre elas — e `skills/<nome>/SKILL.md` num plugin chamado `os` já produz `/os:<nome>`. Manter as duas significaria dois arquivos por procedimento divergindo. Registrado em ADR-0004.

**Skills da Fase 1 escritas:** `new-project`, `resume`, `checkpoint`, `status`, `handoff` — cada uma com seção de anti-falsos-positivos.

**Validação em 4 camadas** (ADR-0004), todas passando:

1. Testes internos — 27/27
2. `claude plugin validate --strict` — `✔ Validation passed`
3. `claude --plugin-dir` — `Loaded 5 skills from plugin os default directory`
4. `marketplace add` + `install` — `os@emmily-platform`, `Skills (5)`, ~267 tok always-on

**`.gitignore_global` reescrito** sob política estrita: só lixo universal de SO, editor e artefato gerado. Removidos `.vscode/`, `.idea/`, `*.key`, `*.pem`, `*.pfx`, `*.p12`, `credentials.json`, `.msal_cache*`, `*.log`, `scratchpad/` — todos são decisão do `.gitignore` de cada projeto, não de uma regra global invisível. Nunca bloqueou `.pdf`/`.docx`/`.xlsx`/`.png`, e agora isso está escrito como política no próprio arquivo.

**`.env` mantido no `.gitignore_global` como exceção deliberada**, por decisão da Emmily: o benefício de evitar commit acidental de credencial supera o custo de uma regra global invisível. Ampliado para preservar todas as convenções de arquivo de exemplo — `.env.example`, `.env.*.example`, `.env.sample`, `.env.*.sample`, `.env.template`, `.env.*.template`. Verificado funcionalmente com `git check-ignore` sobre 9 variantes, e fixado como teste (28º).

**Política de versionamento (ADR-0006):** Semantic Versioning de três componentes, e **tag só depois de validação ponta a ponta**. O primeiro commit da fundação não recebe tag; `v0.1.0` fica reservada para depois do bloco I. A skill `/os:checkpoint` foi atualizada para refletir isso.

**Precisão documentada:** o remoto GitHub é backup off-machine **do conteúdo versionado** — não de dados ignorados, artefatos locais nem trabalho não commitado. Registrado em ADR-0003 e em `ARCHITECTURE.md`; o risco R1 do `STATE.md` foi desdobrado em R1 e R1b.

### Adicionado

- **Ambiente (A):** identidade Git global `Emmily Maciel <(e-mail removido)>`; `init.defaultBranch=main`; `credential.helper=manager`; `core.longpaths=true`; `pull.rebase=false`; `~/.gitignore_global` como rede de segurança contra lixo de Office/SO e segredos óbvios.
- **Workspace (B):** árvore `C:\AI-WORKSPACE\{work/{prog,dynatest,cliente-b},university,personal,ai-lab,portfolio}` e `OneDrive\AI-ARCHIVE\{releases,handoffs,portfolio-assets,backups}`, com `README.md` na raiz do workspace.
- **Repositório (C):** `git init` em `_platform/emmily-ai-project-os` na branch `main`, com `.gitignore` próprio.
- **Documentação (D):** `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `docs/STATE.md`, `docs/ARCHITECTURE.md`, `docs/SETUP.md`.
- **Decisões (D):** ADR-0001 (workspace único e migração progressiva), ADR-0002 (preservar o repo no OneDrive), ADR-0003 (GitHub privado por padrão), ADR-0004 (distribuição como plugin), ADR-0005 (5 skills na Fase 1), ADR-0006 (SemVer e tags validadas).
- **Template (E):** `templates/project-standard/` com `project.yaml`, `CLAUDE.md`, `STATE.md`, `.gitignore`, `.gitattributes`, `.env.example` e `bootstrap.ps1`.
- **Plugin (F):** `.claude-plugin/plugin.json` e `.claude-plugin/marketplace.json`, estabelecendo o namespace `/os:*`.

### Movido

- `EMMILY_AI_PROJECT_OS_HANDOFF.md` → `docs/VISION.md` (conforme a nota final do próprio handoff).
- `FASE0_AUDITORIA.md` → `docs/audits/2026-09-05-fase0-auditoria.md`.

### Corrigido durante a execução

- `core.autocrlf=false` foi definido e **revertido** ao ser detectado que sobrescreveria o `true` do escopo *system* e causaria ruído de fim de linha no `PROG_Relatorio_Grupo1_Automacao`, o único repositório sem `.gitattributes`.
- **Auditoria da Fase 0 corrigida:** o CLI `claude` havia sido reportado como não instalado. Ele existe — `~\.local\bin\claude.exe`, versão 2.1.252, instalador nativo — apenas fora do PATH da sessão. O `gh` segue realmente ausente, agora confirmado nos dois lugares.
- Dois bugs nos próprios testes: `\b` gravado como byte de backspace literal dentro de um regex, e falso positivo do teste de placeholder sobre a skill `new-project`, que documenta os placeholders por nome.
- Descrições das 5 skills encurtadas de 1.747 para 1.009 caracteres, depois de o log de carregamento avisar `Skill listing over budget: 23 skills, 10000 chars > 8000` — descrição truncada degrada exatamente o disparo automático que o handoff §32 exige.

### Segurança

- Nenhum segredo, token ou dado corporativo introduzido.
- Os três repositórios existentes foram apenas lidos. `git status` de cada um verificado antes e depois dos blocos A–F, sem alteração.

## [0.0.0] — 2026-09-05 — Fase 0

### Adicionado

- Auditoria read-only do ambiente: ferramentas, configuração do Claude, três repositórios Git, lacunas, 11 riscos e recomendação de projeto piloto (`PROG_Repositorio_Juridico`).
