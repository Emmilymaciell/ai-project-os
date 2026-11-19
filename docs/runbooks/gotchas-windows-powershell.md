# Armadilhas de Windows, PowerShell 5.1 e Git nesta máquina

Cada item aqui **custou tempo de verdade** durante as Fases 1 e 2. Estão registrados porque nenhum é óbvio, e todos voltam a acontecer com quem não os conhece — inclusive um Claude futuro nesta mesma plataforma.

## PowerShell 5.1

**Variável é case-insensitive.** `$T` e `$t` são **a mesma variável**. Um script de teste quebrou porque `$t = <conteúdo do arquivo>` sobrescreveu `$T = <pasta temporária>`. Use nomes distintos, não apenas caixa distinta.

Isso aconteceu **duas vezes**, e a segunda foi pior: `$LOTE = 150` como tamanho de lote e `$lote = @(...)` como a fatia, dentro do mesmo laço. A fatia sobrescreveu o tamanho, `$i += $LOTE` passou a somar um array a um inteiro, e o erro que sai é `[System.Object[]] não contém um método denominado 'op_Addition'` — que não menciona a variável nem sugere colisão de nome. Derrubou 52 testes de uma vez. Se um erro de tipo aparecer num laço que "não mudou", procure colisão de caixa antes de qualquer outra coisa.

**E `-eq`/`-ne` entre strings TAMBÉM.** `'Verificacao:' -ne 'verificacao:'` é **falso**. Isso apareceu na 2.4 num teste cujo assunto era justamente a sensibilidade a caixa: o guarda-corpo `Assert-True ($com -ne $original)` acusou a fixture de "não ter capitalizado o bloco" depois de capitalizar corretamente — e num caso sobre caixa, o operador errado transforma o teste em nada. Use `-ceq`/`-cne`, ou `[string]::Equals($a, $b, [System.StringComparison]::Ordinal)`. Vale para `-contains`, `-in` e as chaves de `@{}` pelo mesmo motivo: a hashtable do PowerShell é case-insensitive, e o `dict` do Python não — o que fez os dois leitores de manifesto do template divergirem.
**`-match` e `-replace` são case-insensitive por padrão.** Uma sonda de teste `-notmatch 'Visibilidade do remoto'` passou a falhar quando o relatório ganhou a frase *"a visibilidade do remoto NÃO veio da API real"* em outra seção. Ancore o padrão em algo estrutural (o `|` de uma célula de tabela, um `^` de início de linha) em vez de confiar na frase.

**`\` não é caractere de escape.** O escape é o backtick `` ` ``. Então:
- `'\\'` são **dois** caracteres, não um. `TrimStart('\\','/')` falha com *"não é possível converter para System.Char"* — o correto é `TrimStart([char]'\', [char]'/')`.
- Em string de aspas duplas, `$` literal se escapa com `` `$ ``, nunca com `\$`. Um `"\$Ordem:"` é interpretado como variável com qualificador de drive e dá erro de parse.
- **`"\"texto\""` não dá erro: ele fecha a string e descarta o resto, em silêncio.** Foi a terceira aparição desta armadilha na plataforma, e a pior, porque não houve exceção nenhuma — o relatório de segurança passou a gravar `**\` no lugar de uma frase inteira, e só um teste que procurava a frase pegou. Para aspa dupla literal, use string de **aspas simples** ou `` `" ``.

**Aspas duplas aninhadas dentro de `$()` dentro de aspas duplas não funcionam.** `"texto $(if ($x) { "$y" })"` é erro de parse. Pré-compute o valor numa variável.

**`Assert-True` e qualquer parâmetro `[bool]` não aceitam string.** `Assert-True ($minhaString)` falha com *"não é possível converter System.String em System.Boolean"*. Use `-not [string]::IsNullOrWhiteSpace($x)`.

**`Set-Content` e `Out-File -Encoding utf8` gravam UTF-8 com BOM.** Já `Get-Content -Raw` **sem** `-Encoding` lê UTF-8 como ANSI da codepage do sistema, o que corrompe acentos na regravação. A combinação ler-sem-encoding + gravar-com-encoding destrói acentos silenciosamente e o teste falha apontando conteúdo, não encoding. Nesta plataforma, leia com `tests/_harness.ps1` → `Get-Texto`, que usa `[System.IO.File]::ReadAllText(path, UTF8)`.

**`[System.IO.File]::ReadAllText(path, Encoding.UTF8)` já consome o BOM.** Verificado: arquivo que começa com `EF BB BF` devolve o primeiro caractere real, não `U+FEFF`. Não escreva código para remover BOM aqui — houve um ramo desses no harness, era morto, e o comentário registrava um diagnóstico errado.

**Sem `??`, sem `?:`, sem `?.`, sem `-AsHashtable`, sem `&&`/`||`.** É 5.1, não 7. `pwsh` não está instalado. `A; if ($?) { B }` no lugar de `A && B`.

**Função que devolve UM `[pscustomobject]` não tem `.Count`.** Vem vazio, e `$null -ge 1` é falso — então um teste de "achou pelo menos um" **falha com o detector correto**. Aconteceu na 2.3: o teste acusou "silenciou o achado" quando nada tinha sido silenciado. Sempre `@(...)` antes de contar.

**`foreach ($x in $null)` não é erro: itera zero vezes e o teste passa.** É a forma mais barata de ter teste verde que não verifica nada. Na 2.3 descobriu-se que `$SkillsEsperadas` era usada em cinco testes e não era definida em lugar nenhum desde a modularização da 2.0 — cinco testes verdes por vacuidade. Toda suite que itera sobre uma lista precisa de um caso que **prove que a lista não está vazia**.

**Função aninhada vê a variável da função que a envolve, mas `$script:` não.** `$script:x` aponta para o escopo do arquivo, que numa lib carregada por dot-source não é o mesmo lugar. Dentro de função aninhada, use o nome sem prefixo: o PowerShell resolve dinamicamente, e mexer nas chaves de uma hashtable altera o mesmo objeto.

**`.ps1` deve ser ASCII puro.** O 5.1 lê `.ps1` UTF-8 sem BOM como ANSI, então acento no fonte vira mojibake. Há teste que falha se qualquer `.ps1` tiver byte acima de 127. Escreva os scripts sem acento; a documentação `.md` pode ter.

**Leitura estrita de UTF-8 NÃO detecta UTF-16 sem BOM.** É contraintuitivo e derrubou a primeira versão da correção do item 11: `UTF8Encoding($false, $true)` — o segundo argumento é `throwOnInvalidBytes` — recusa byte inválido, mas UTF-16LE de conteúdo ASCII é UTF-8 **válido byte a byte**, porque `A` vira `41 00` e `U+0000` é *code point* legítimo. A leitura passa e devolve o texto com um NUL entre cada letra, que quebra todo regex. Quem pega isso é uma segunda verificação: **NUL no texto decodificado**. Arquivo de texto de verdade não tem NUL — é assim que o próprio Git decide se um blob é binário. E UTF-16 **com** BOM não precisa de nenhuma das duas: `ReadAllText` detecta o preâmbulo e decodifica certo.

**`Write-Host` não é capturado por `>`.** No 5.1 ele escreve no *stream* 6 (Information), não no de sucesso, então `& .\script.ps1 > saida.txt` produz **arquivo vazio** quando o script reporta com `Write-Host`. Um script de prova por mutação desta plataforma concluiu "nenhum caso caiu" quatro vezes seguidas por causa disso — ausência de dado lida como ausência de falha, dentro da ferramenta que existia para provar o contrário. Use `*> arquivo`, ou `6>&1`, ou rode em processo filho com `powershell.exe -File`.

**Literal de várias linhas dentro de um `.ps1` carrega `CRLF` depois do checkout.** O `.gitattributes` deste repositório fixa `*.ps1 text eol=crlf`, então o arquivo que você editou com `LF` volta com `CRLF` em qualquer clone novo — e o conteúdo do literal muda junto. Uma asserção que compara esse literal contra um texto do qual o `CR` foi removido passa na sua máquina e **falha em clone limpo, com o código correto**. Escreva o padrão numa linha só, com escapes `\n`: quem os interpreta é o regex, não o parser. E cuidado com ferramenta de edição: script Python que lê em modo texto e regrava sem `newline` original **remove todo `CR`** do arquivo, o que esconde exatamente esse defeito enquanto você trabalha.

## Git nesta máquina

**`core.autocrlf=true` vive no escopo *system*** (posto pelo instalador). Não sobrescreva no global: o repositório `PROG_Relatorio_Grupo1_Automacao` não tem `.gitattributes` e passaria a produzir ruído de fim de linha. A solução correta é `.gitattributes` por repositório.

**Aviso de CRLF do `git` vai para stderr, e no 5.1 stderr de executável nativo vira `ErrorRecord`.** Sob `$ErrorActionPreference = 'Stop'`, isso **aborta o script** com uma mensagem sobre fim de linha que não tem relação com o que se está fazendo. Em fixture de teste, resolva na causa: `git config core.autocrlf false` e `core.safecrlf false` no repositório temporário, e `$ErrorActionPreference = 'Continue'` em volta do bloco.

**E isto voltou, na pior forma possível, no fechamento da 2.4.** O `.gitattributes` deste repositório fixa `eol=lf` para `.md`; um `docs/STATE.md` gravado com CRLF fez o `git diff` do `collect-diff.ps1` avisar *"CRLF will be replaced by LF"*, o aviso virou erro terminante, o `trap` pegou, e o **coletor saiu com 2 e sem relatório** — no meio de um fechamento de subfase, com os revisores prontos para rodar. Coletor que morre não produz evidência, e sem evidência a revisão é `INCONCLUSIVO`.

Duas lições, e a segunda é a que importa:

- **`2>$null` sozinho NÃO protege.** Já estava medido no caso do `rev-parse` em repositório sem commits, e o padrão `git ... 2>$null` espalhado pelos scripts dava uma falsa sensação de proteção. O que protege é **baixar o `$ErrorActionPreference` em volta da chamada**.
- **Guarda por caso não escala.** Havia guarda para repositório sem commits, para ref inexistente e para destino fora do repositório — e o quarto aviso, que ninguém previu, derrubou tudo igual. A correção certa é de **classe**: todo `git` dos coletores passa por `Invoke-Git` (em `scripts/lib/scan-comum.ps1`), que devolve stdout, deixa o código em `$LASTEXITCODE` e não permite que aviso nenhum aborte quem chama. 34 chamadas convertidas; nenhuma `git` solta restou.

**`git check-ignore -v` tem três comportamentos que invertem conclusão se você supor errado.** Todos medidos:

- **Exit `0` significa "alguma regra casou", inclusive regra de negação.** Não significa "ignorado". Quem decide isso é o `!` no início do padrão reportado. Confundir os dois inverte o veredito de toda negação.
- **O Git aplica o ÚLTIMO padrão que casa, não o primeiro.** Então uma regra é sombreada por uma regra **posterior**. Um teste escrito com a intuição contrária afirma o oposto do que verifica.
- **No Windows o Git CITA o caminho da fonte e DUPLICA as barras invertidas** quando há alguma: o `excludesfile` global volta como `"C:\\Users\\...\\.gitignore_global"`. Sem desfazer as aspas e as barras, qualquer teste de caminho sobre esse valor opera em cima de lixo — e `[System.IO.Path]::IsPathRooted` **lança exceção**, porque `"` é caractere inválido de caminho. Prefira regex (`^[A-Za-z]:/`) a `IsPathRooted` para dados que vêm do Git.

**`git rev-list --objects` imprime cada objeto UMA vez, com um caminho só.** Depois de `git mv config.py legacy/config.py`, o blob aparece apenas como `legacy/config.py` — o caminho antigo é **invisível** ali, e um `filter-repo --path legacy/config.py` deixaria o segredo alcançável pelo caminho antigo. Para recuperar todos os caminhos de um blob: `git log --all --find-object=<sha> --format= --name-only`. Custa um processo por blob, então chame só para blob que já produziu achado.

**`git check-ignore` com muitas sondas numa linha de comando única estoura o limite do Windows.** E o modo de falha é silencioso e péssimo: a chamada falha, nenhuma sonda casa, e *toda* regra vira um falso "sem efeito observável". Passe em lotes (`scan-gitignore.ps1` usa 150).

**`git rev-parse --short HEAD` em repositório sem commits escreve em stderr e derruba o script.** A mensagem é `fatal: Needed a single revision`, e sob `ErrorActionPreference = 'Stop'` ela vira erro terminante — mesmo com `2>$null`. Guarde com `git rev-parse --verify --quiet HEAD^{commit}`, não com redirecionamento — e **não** com `HEAD` puro, pela razão da entrada seguinte. Esse é o fluxo normal do `/os:new-project`, que roda `git init` e para.

**`git diff HEAD` falha em repositório sem nenhum commit** — `fatal: ambiguous argument 'HEAD'`. E esse é o fluxo normal desta plataforma: `/os:new-project` roda `git init` e para. Guarde com `git rev-parse --verify --quiet HEAD^{commit}`.

**`git rev-parse --verify HEAD` não prova que o `HEAD` é um commit — prova que a string tem forma de sha.** Com o **sha nulo** (40 zeros) escrito em `.git/HEAD`, ele sai com **`0`** e imprime os 40 zeros. Uma guarda escrita assim devolve "o HEAD resolve", e o chamador carimba o relatório com `0000000` como se fosse um commit. Use **`'HEAD^{commit}'`, entre aspas simples** — chave em argumento não-citado é candidata a outra armadilha —, que obriga o objeto a existir *e* a ser commit: sai `1` para o sha nulo, `1` para repositório sem commits, `0` só quando há commit de verdade. Achado em 2026-09-15 **dentro da função escrita para eliminar falso verde**, por um caso de teste que passou a exigir a mensagem certa da exceção em vez de aceitar qualquer falha.

**Texto de prompt passado por parâmetro ao CLI é cortado no primeiro token que pareça uma opção.** Ao invocar um revisor com `-p "<texto>"`, qualquer sequência iniciada por dois hifens dentro do texto é interpretada como opção de linha de comando: o executável responde `error: unknown option` e **a mensagem chega truncada ali**. Como os prompts desta casa citam nomes de flags do Git o tempo todo, isso cortou três submissões em rodadas diferentes — e o diagnóstico errado foi "prompt longo demais", que levou a encurtar sem resolver. **A forma correta é briefing em arquivo**: escreva o texto em `artifacts/review/brief-*.md` e passe um prompt curto mandando lê-lo. Os revisores têm `Read`. O que salvou os vereditos foi o desenho do ADR-0008 — eles leem artefatos, não o relato de quem construiu; se o mecanismo dependesse da prosa, três rodadas teriam concluído sobre informação incompleta sem ninguém notar.

**Comparar bytes pega o que comparar linhas não pega.** Um arquivo pode mudar 521 bytes mantendo a mesma contagem de linhas — foi assim que uma revisão foi emitida contra um texto que já não estava no disco. Dos dois revisores, o que conferiu byte achou; o que conferiu linha, não. E a causa foi processual: **aplicar a prescrição de um revisor não dispensa recoletar antes de considerar o veredito válido.** "Apliquei exatamente o que ele pediu" é julgamento de quem construiu sobre a própria execução, que é o que o carimbo existe para dispensar.

**Asserção de exceção que não casa a mensagem aceita qualquer falha** — inclusive a de o código sob teste não existir. Três casos desta plataforma ficaram verdes esperando exceção e recebendo `o termo não é reconhecido`, por estarem numa suíte que não carregava a lib. Case a mensagem, e a **específica**: um prefixo comum a cinco exceções da mesma função não distingue qual delas ocorreu.

**`git diff` não mostra arquivo não rastreado.** Um relatório de diff sobre trabalho novo diria "sem alterações" com o projeto inteiro no disco. Use `git ls-files --others --exclude-standard`.

**O `.gitignore_global` desta máquina bloqueia `.env`.** Fixture que precise de um `.env` rastreado tem de isolar: `git config core.excludesfile <caminho inexistente>` no repositório temporário.

**Seção `[remote "x"]` sem nenhuma chave deixa `git remote -v` mudo, com código 0.** O config declara um remoto e o git não imprime nada — estado real quando a escrita do config é truncada ou alguém apaga a `url` à mão. É por isso que o scanner confere o `.git/config` quando a lista de remotos vem vazia: sem essa guarda, um repositório **público** sairia sem achado `ALTA`. Cuidado ao montar a fixture: com `fetch` e sem `url`, o `remote -v` imprime o **nome seguido de tabulação**, e um `-split '\s+'` produz uma entrada vazia em vez de lista vazia.

**Byte inválido no `.git/config` não incomoda o git.** Ele responde `remote -v` vazio com código 0 e segue funcionando. Quem lê esse arquivo com leitura leniente recebe `U+FFFD` no lugar do byte, o `-match '\[remote '` não casa, e a guarda fica **inerte pelo exato motivo que ela existe para cobrir**.

**Todo hook do Git roda com `GIT_DIR` no ambiente.** Nesse estado o git responde sobre o repositório apontado pela variável, e não pelo caminho que você passou em `-C` — então o git pode ter sucesso enquanto a sua própria resolução de `.git` falha. "Não consegui localizar o repositório" nunca pode virar "não há remoto": são respostas diferentes.

**Em worktree ligado o `config` mora no diretório *comum*, não no `gitdir` do worktree.** `.git/worktrees/<nome>/` tem `HEAD`, `index`, `refs` e `commondir` — e **não** tem `config`, a menos que `extensions.worktreeConfig` esteja ligado. Fora de worktree ligado, `GitDir` e `ComumDir` são o mesmo caminho, então qualquer teste que confunda os dois passa em repositório comum sem provar nada.

## Ambiente

**Dois Pythons:** 3.12 no `PATH`, 3.13 como default do launcher `py`. **Nunca deixe implícito** — o `project.yaml` de cada projeto fixa qual.

**`pytest` não existe em nenhum dos dois interpretadores globais.** Projeto Python precisa de venv próprio; o `bootstrap.ps1` do template cria e instala.

**O CLI `claude` não está no PATH.** Fica em `~\.local\bin\claude.exe` (instalador nativo). Invoque pelo caminho completo.

**`Test-Path` devolve verdadeiro para DIRETÓRIO.** Guarda-corpo que quer garantir "aponta para um arquivo existente" precisa de `-PathType Leaf`. Sem isso, um caminho de diretório passa por caminho de arquivo — e no mecanismo de exceção de segurança esse era o único obstáculo entre `caminho: "docs"` e uma allowlist de árvore inteira.

**Função que recebe CONTEÚDO e chamada com CAMINHO não dá erro: devolve lixo plausível.** `Measure-Linhas` tem `param([string]$Texto)`, e `Measure-Linhas $caminho` devolve **1** — porque um caminho não tem `\n`. Na 2.4 isso fez a linha de proveniência do relatório de segurança declarar `(1 linhas) + 0 detectores` em todas as execuções, num relatório cuja premissa é declarar a própria cobertura, e nenhum dos 225 testes tocava aquela linha. Os dois revisores acharam conferindo o artefato. A correção que impede a reincidência não é cuidado: é **nome distinto** — `Measure-LinhasDoArquivo` recebe caminho, `Measure-Linhas` recebe conteúdo, e o erro fica impossível de escrever.

**`-split` come o parêntese seguinte.** `Get-Texto $p -split "``r?``n"` não conta linhas do arquivo: o PowerShell entrega o resultado do `-split` como **argumento** da função. `((Get-Texto $p) -split "``r?``n").Count` é a forma que funciona. Custou um teste falhando com "declara 714 linhas e o arquivo tem 1" — e só porque a asserção exigia o valor **exato**; um `-gt 0` teria passado.
**`[double]::TryParse('1.0')` devolve `10` nesta máquina.** A cultura do sistema é pt-BR, onde o separador decimal é a vírgula — então o ponto é lido como separador de **milhar**. A sobrecarga de dois argumentos usa a cultura atual, e não avisa nada: `TryParse` devolve `$true`, o número sai dez vezes maior, e um teste que compara contra ele continua **verde**. Foi assim que uma tolerância de `erro_maximo_m: 1.0` declarada no manifesto passou a valer 10 metros na 2.4, e só um caso que exigia o valor **exato** pegou. Sempre a sobrecarga de quatro argumentos: `[double]::TryParse($s, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)`. Vale para todo número que venha de arquivo de configuração — YAML, JSON e CSV são invariantes; o `TryParse` padrão não é.

**`py -m venv` escreve em stderr quando o caminho tem nome curto 8.3.** `$env:TEMP` nesta máquina devolve `C:\Users\USUARI~1\...` (o nome de usuário tem espaço), e o venv reclama *"Actual environment location may have moved due to redirects, links or junctions"*. É aviso, não erro — mas sob `$ErrorActionPreference = 'Stop'` stderr de executável nativo vira erro terminante e **aborta o script**, com uma mensagem que não tem nada a ver com o que se está fazendo. Mesma família do aviso de CRLF do Git. Resolva na causa: `(Get-Item $env:TEMP).FullName` devolve o caminho longo.

**Suite de teste de projeto rodada em processo separado, não por dot-source.** O harness do template define `Test-Caso`, `Assert-True` e os contadores `$script:passou`/`$script:falhou` com os **mesmos nomes** que o harness da plataforma. Carregar um dentro do outro sobrescreveria as funções e **zeraria os contadores** no meio da execução: a suíte da plataforma reportaria menos casos do que rodou, sem erro nenhum. Use `Invoke-RunnerDoProjeto`, que chama `powershell -NoProfile -File`.
**Caminho do Windows dentro de heredoc de Python vira caractere de controle.** Editar `.md` por `python - <<'PY'` funciona bem, mas a barra invertida atravessa duas camadas de escape antes de chegar ao interpretador: o que se escreve como `\\bin` chega ao Python como `\bin` e é interpretado como **backspace** (`0x08`). O efeito no arquivo é `\.local` seguido de um byte invisível, e o `grep` mostra `\.localin` — nem erro, nem sinal. Aconteceu ao documentar a própria linha de comando dos revisores, e resistiu a duas tentativas de correção pelo mesmo caminho. Em heredoc de Python com caminho do Windows, use string **crua** (`r'''...'''`), ou corrija por `[System.IO.File]::ReadAllText`/`WriteAllText` com `[char]8` explícito.

**E aconteceu de novo na 2.4, com `\t` e `\r`.** Escrevendo `comando: '.\tests\run-tests.ps1'` num script Python, o `project.yaml` da plataforma recebeu um **tab** e uma **quebra de linha** de verdade no meio do valor — YAML que ainda parseia, valor que aponta para nada. E o guarda-corpo que pegou foi outro, por acidente: o de placeholder, porque o mesmo commit tinha um `{{...}}` em prosa. A regra, agora com duas aparições: **caminho do Windows não passa por heredoc de Python.** Use `r'''...'''`, ou grave por `[System.IO.File]::WriteAllText` a partir do PowerShell, onde a barra invertida é literal.
**`replace_all` em texto indentado pega só as ocorrências com a MESMA indentação.** Duas cópias da mesma linha de decisão, uma dentro de um laço e outra na descarga final, têm recuos diferentes: a substituição atinge uma e a outra fica para trás em silêncio. Aconteceu no portão de aceitação de exceção, e a que ficou era justamente a do caso mais comum — lista de uma entrada. Depois de substituição em massa, `grep` pelo padrão antigo antes de confiar.

**O `gh` também não está no PATH.** Está instalado (2.100.0) e vive em `C:\Program Files\GitHub CLI\gh.exe`. `Get-Command gh` devolve nada, e código que depende disso conclui "gh indisponível" com o gh instalado — foi o que deixou a visibilidade do remoto sem resposta na primeira execução da varredura da 2.3. Procure no PATH **e** nos lugares conhecidos; ver `Get-CaminhoDoGh` em `scripts/lib/scan-exposicao.ps1`.

## Claude Code

**Agente de plugin ignora `permissionMode`, `hooks` e `mcpServers` — em silêncio.** O campo `tools` é o único limite de privilégio real. Ver ADR-0008.

**`claude plugin validate` valida o *marketplace* quando `marketplace.json` e `plugin.json` estão no mesmo `.claude-plugin/`.** Para validar componentes, aponte para a pasta: `validate ./skills`, `validate ./agents`.

**`claude plugin update` sem bump de `version` é no-op silencioso.** Para refrescar no mesmo número: `uninstall` seguido de `install`.

**`claude plugin install` faz cópia congelada** em `~\.claude\plugins\cache\`. Editar o repositório não altera a cópia instalada. Em desenvolvimento use `--plugin-dir`, que lê o repositório ao vivo.

**Descrição longa de skill é truncada.** O log avisa `Skill listing over budget`, e descrição truncada degrada o disparo automático. Mantenha cada uma em torno de 200 caracteres.
