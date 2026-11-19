<#
.SYNOPSIS
    Suite do fluxo client-side: branch, evidencia e PR.

.DESCRIPTION
    Este arquivo NAO declara o marcador de fixture, de proposito. O caso de
    CONTRATO precisa de um token em formato valido para que o scanner REAL
    produza uma linha de achado real - mas o token e montado POR PARTES, como
    'hooks.ps1' e 'doctor.ps1' ja fazem, em vez de escrito inteiro.
    A razao esta no item 9 do backlog: o marcador e a unica rota de
    rebaixamento que '-ParaPublicacao' nao anula, e ele cobre o arquivo todo.

    A subfase 2.7 e client-side por decisao registrada (ADR-0011): nao ha
    branch protection neste plano, e isto NAO equivale a enforcement no
    servidor. O que esta suite mede e o guarda-corpo local - e ela mede
    justamente onde ele PODE falhar em silencio.

    Duas camadas, como as outras suites desta plataforma:

      UNITARIA  - as funcoes de 'branch-comum.ps1' e 'pr-comum.ps1' chamadas
                  direto, sobre repositorio descartavel ou sobre texto.
      FUNCIONAL - 'branch.ps1' e 'pr.ps1' rodando como PROCESSO FILHO, para
                  medir o codigo de saida de verdade. Codigo de saida aferido
                  por leitura de codigo nao e codigo de saida medido.

    O 'gh' e MOCKADO por um .cmd posto na frente do PATH. Nenhum teste aqui
    toca a rede, e nenhum toca o repositorio da plataforma.

    LIMITE DECLARADO DO MOCK, e ele e a razao de 'Get-ArgumentosDePrCreate'
    existir como funcao: o 'gh' real e um .exe e o mock e um .cmd, que passa
    pelo cmd.exe. MEDIDO nesta maquina: um argumento multilinha - que e
    exatamente o caso do '--body' - chega TRUNCADO na primeira quebra de
    linha, sem erro nenhum.

    (A versao anterior desta frase dizia que "o PowerShell entrega argumento
    direto ao .exe". Nao entrega: ele monta uma linha de comando, e a regra de
    citacao dele quebra argumento com aspa dupla ou barra invertida no fim.
    Medido, e corrigido tambem em 'Test-TituloDePr'.) O mock serve para medir codigo de saida e QUAL subcomando foi
    chamado; ele NAO serve para medir o conteudo dos argumentos. Por isso a
    montagem da linha de comando e pinada em memoria, no caso unitario, e nao
    atraves do mock. Um teste que afirmasse '--body' correto pelo log do mock
    estaria afirmando o que o mock nao pode testemunhar.

    O par negativo e obrigatorio em todo caso de bloqueio: uma regra que
    reprova tudo passaria em qualquer teste que so mostrasse a reprovacao.

    Nada e escrito fora de $env:TEMP.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite fluxo"
}

$LibDir       = Join-Path $OsRoot 'scripts\lib'
$ScriptBranch = Join-Path $OsRoot 'scripts\branch.ps1'
$ScriptPr     = Join-Path $OsRoot 'scripts\pr.ps1'

foreach ($m in @('scan-comum.ps1', 'hooks-comum.ps1', 'branch-comum.ps1', 'pr-comum.ps1')) {
    . (Join-Path $LibDir $m)
}

# =============================================================================
# FIXTURES
# =============================================================================

function New-RepoFluxo {
    <#
      Repositorio descartavel, com um commit.
        -BranchInicial   nome do primeiro branch (default 'main')
        -ComRemoto       cria refs/remotes/origin/<inicial> e o HEAD remoto,
                         SEM rede: 'update-ref' e 'symbolic-ref' escrevem no
                         disco. E assim que o caso do 'origin' fantasma e
                         reproduzido sem depender de um clone de verdade.
    #>
    param(
        [string]$BranchInicial = 'main',
        [switch]$ComRemoto
    )
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $t = Join-Path $env:TEMP ("fx-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q -b $BranchInicial 2>$null
        # O init tem de ter funcionado ANTES de qualquer 'add': sem isto, um
        # init falho faria o 'add -A' subir procurando repositorio ancestral.
        if (-not (Test-Path (Join-Path $t '.git'))) { throw "git init falhou em '$t'" }
        git -C $t config user.name  'Fixture'    2>$null
        git -C $t config user.email 'fx@invalid' 2>$null
        git -C $t config core.autocrlf false     2>$null
        git -C $t config core.safecrlf false     2>$null

        [System.IO.File]::WriteAllText((Join-Path $t '.gitignore'), "/artifacts/`n", (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText((Join-Path $t 'leia.md'), "fixture`n", (New-Object System.Text.UTF8Encoding($false)))
        git -C $t add -A 2>$null
        git -C $t commit -q -m "chore: estado inicial da fixture" --no-verify 2>$null

        if ($ComRemoto) {
            git -C $t remote add origin 'https://invalid.invalid/fixture/repo.git' 2>$null
            git -C $t update-ref ("refs/remotes/origin/" + $BranchInicial) HEAD 2>$null
            git -C $t symbolic-ref refs/remotes/origin/HEAD ("refs/remotes/origin/" + $BranchInicial) 2>$null
        }
        return $t
    } finally { $ErrorActionPreference = $anterior }
}

function Remove-RepoFluxo {
    param([string]$Caminho)
    if ($Caminho -and (Test-Path $Caminho)) {
        Remove-Item $Caminho -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Set-RemotoNoBranch {
    <#
      Cria 'refs/remotes/origin/<branch>' apontando para o SHA pedido, SEM
      REDE. E assim que o portao de divergencia com o remoto fica mensuravel:
      'update-ref' escreve a ref de acompanhamento direto no disco, que e o
      que 'Test-PublicavelNoRemoto' le.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Branch,
        [string]$Sha = ''
    )
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if (-not $Sha) { $Sha = (git -C $Repo rev-parse HEAD 2>$null); $Sha = ("" + $Sha).Trim() }
        git -C $Repo update-ref ("refs/remotes/origin/" + $Branch) $Sha 2>$null
    } finally { $ErrorActionPreference = $anterior }
}

function Get-BranchAtual {
    param([string]$Repo)
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $n = (git -C $Repo symbolic-ref --short HEAD 2>$null)
        if ($LASTEXITCODE -ne 0) { return '' }
        return ("" + $n).Trim()
    } finally { $ErrorActionPreference = $anterior }
}

function Get-HeadDoRepo {
    param([string]$Repo)
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $n = (git -C $Repo rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -ne 0) { return '' }
        return ("" + $n).Trim()
    } finally { $ErrorActionPreference = $anterior }
}

function Add-SujeiraNoRepo {
    param([string]$Repo, [string]$Nome = 'novo.txt')
    [System.IO.File]::WriteAllText((Join-Path $Repo $Nome), "nao commitado`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Write-EvidenciaDePr {
    <#
      Escreve os dois relatorios que 'pr.ps1' exige, carimbados com o SHA
      pedido. '-Segredo' planta um texto no CORPO dos relatorios: ele existe
      para o caso que verifica que o corpo do PR NAO transcreve o relatorio.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Sha,
        [string]$Segredo = '',
        [switch]$ComAchadoBloqueante,
        [switch]$ComAchadoAceitoPorExcecao,
        [switch]$SemSecaoDeAchados,
        [switch]$CarimboSoNoCorpo,
        [switch]$CarimboEmProsaNoPreambulo,
        [int]$ExitDaSuite = 0,
        [switch]$SemLinhaDeExit,
        [string]$Comparacao = 'main',
        [int]$LinhasDeDiff = 120,
        [switch]$SemEscopoColetado,
        [switch]$ExitForaDaSecaoDeTestes,
        [switch]$SecaoDeTestesDuplicada
    )
    $dir = Join-Path $Repo 'artifacts\review'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    # O cabecalho imita o REAL, porque e o cabecalho que o portao le:
    # '- Branch: `x`  HEAD: `<sha>`' antes do primeiro '## '. A fixture
    # anterior escrevia 'HEAD: <sha>' solto, e por isso ela nao conseguia
    # distinguir carimbo de cabecalho de SHA citado em prosa - que e
    # exatamente o falso verde que o qa-reviewer achou.
    $diff = "# relatorio de fixture`n`n"
    if (-not $CarimboSoNoCorpo -and -not $CarimboEmProsaNoPreambulo) {
        $diff += "- Branch: ``fixture``  HEAD: ``$Sha```n"
    }
    # PROSA no preambulo: antes do primeiro '## ', e portanto dentro da janela
    # que a ancora examina, mas NAO um campo de cabecalho. O relatorio real
    # tem prosa ali - um bloco '>' explicando como ler o arquivo. Carimbo e o
    # que o GERADOR escreveu como campo, nao qualquer mencao a um SHA.
    if ($CarimboEmProsaNoPreambulo) { $diff += "> nota: a coleta anterior tinha HEAD: ``$Sha```n" }
    $diff += "- Gerador: ``scripts/collect-diff.ps1```n"

    # A tabela de escopo imita a REAL, porque e dela que o portao le contra
    # que referencia a coleta foi feita e quantas linhas de diff ela achou.
    if (-not $SemEscopoColetado) {
        # AS DUAS LINHAS, na ORDEM REAL - e a primeira e a do '--stat'.
        #
        # A fixture anterior escrevia so a segunda, e foi isso que escondeu o
        # defeito mais grave da subfase: a regex de 'Get-ComparacaoDaColeta'
        # casava com a linha do '--stat' primeiro, extraia
        # 'Referencia = --stat HEAD', e o portao devolvia INDETERMINADO para
        # TODA coleta real. O caso positivo do '-Abrir' ficava verde sobre um
        # formato que nao existe.
        #
        # A licao, que ja custou caro na Fase 1: fixture que fabrica a
        # entrada a partir do MEU modelo do formato nao mede o formato. Por
        # isso existe tambem o caso de CONTRATO, que roda o coletor de
        # verdade e entrega a saida dele ao portao.
        $diff += "`n## Escopo COLETADO`n`n"
        $diff += "| O que | Volume |`n|---|---|`n"
        $diff += "| ``git status --porcelain`` | 3 entrada(s) |`n"
        $diff += "| ``git diff --stat $Comparacao`` | 4 linha(s) |`n"
        $diff += "| ``git diff $Comparacao`` | $LinhasDeDiff linha(s) |`n"
    }

    $diff += "`n## Resultado real dos testes`n`n"
    if (-not $SemLinhaDeExit) {
        $rotulo = $(if ($ExitDaSuite -eq 0) { 'passou' } else { 'FALHOU' })
        $diff += "Codigo de saida: **$ExitDaSuite** ($rotulo)`n"
    }
    # A linha de codigo de saida PLANTADA FORA da secao de testes, na coluna 0,
    # imitando o que o coletor faz com arquivo novo: ele transcreve literalmente,
    # sem prefixo. E o cenario da oitava instancia da classe.
    if ($ExitForaDaSecaoDeTestes) {
        $diff += "`n## Arquivos novos (invisiveis ao git diff)`n`n"
        $diff += "### ``rascunho.md```n`n"
        $diff += "Codigo de saida: **0** (passou)`n"
    }
    # O TITULO DA SECAO REPETIDO mais abaixo, que e o caso realista do 'break'
    # em 'Get-SecaoDeRelatorio': o coletor transcreve arquivo novo
    # LITERALMENTE, entao um arquivo que contenha esse cabecalho - esta
    # propria suite poderia - cria uma segunda secao com o mesmo nome. Sem o
    # 'break', a leitura voltaria a ligar ali e juntaria o conteudo das duas.
    if ($SecaoDeTestesDuplicada) {
        $diff += "`n## Arquivos novos (invisiveis ao git diff)`n`n"
        $diff += "### ``suite-de-exemplo.ps1```n`n"
        $diff += "## Resultado real dos testes`n`n"
        $diff += "Codigo de saida: **0** (passou)`n"
    }
    # '-CarimboSoNoCorpo' poe uma linha com a FORMA EXATA de um carimbo de
    # cabecalho, so que DEPOIS do primeiro '## ' - que e onde o diff-report
    # real transcreve o 'STATE.md' e o diff de outros arquivos.
    #
    # A forma tem de ser exata, e a primeira versao desta fixture errou isso:
    # ela escrevia 'commit citado em prosa: `<sha>`', que falha por TRES
    # motivos de uma vez (sem '- ', sem 'HEAD:', fora do cabecalho). Um caso
    # desses passaria ate com um predicado que so exigisse 'HEAD:' em qualquer
    # lugar - ele nao mediria a ancoragem, que e a unica coisa que ele existe
    # para medir. Assim, o UNICO motivo da recusa e a posicao.
    if ($CarimboSoNoCorpo) { $diff += "`n- Branch: ``fixture``  HEAD: ``$Sha```n" }
    if ($Segredo) { $diff += "`nachado: $Segredo`n" }
    [System.IO.File]::WriteAllText((Join-Path $dir 'diff-report.md'), $diff, (New-Object System.Text.UTF8Encoding($false)))

    # O relatorio de seguranca imita a ESTRUTURA do real, porque e a estrutura
    # que o portao le: '## Achados' e a secao que bloqueia, e
    # '## Achados ACEITOS POR EXCECAO' comeca com o mesmo prefixo e NAO
    # bloqueia (ADR-0010). As duas tem linhas 'MEDIA' - e por isso que o
    # leitor nao pode ser um grep por severidade.
    $seg = "# relatorio de fixture`n`n"
    if (-not $CarimboSoNoCorpo -and -not $CarimboEmProsaNoPreambulo) { $seg += "- HEAD: ``$Sha```n" }
    if ($CarimboEmProsaNoPreambulo) { $seg += "> nota: a varredura anterior tinha HEAD: ``$Sha```n" }
    if (-not $SemSecaoDeAchados) {
        $seg += "`n## Achados`n`n"
        if ($ComAchadoBloqueante) { $seg += "| ALTA | chave privada versionada | segredo.pem |`n" }
    }
    $seg += "`n## Achados ACEITOS POR EXCECAO (aparecem e nao bloqueiam o fluxo privado)`n`n"
    if ($ComAchadoAceitoPorExcecao) { $seg += "| MEDIA | caminho de auditoria aprovado | docs/audits/x.md |`n" }
    # O carimbo deslocado precisa existir nos DOIS relatorios, e a mutacao
    # provou por que: com ele so no diff-report, o relatorio de seguranca
    # reprovava sozinho por falta de carimbo e o caso passava sem nunca
    # exercitar a ancoragem. Apagar a ancora do codigo nao derrubava nada.
    if ($CarimboSoNoCorpo) { $seg += "`n- HEAD: ``$Sha```n" }
    if ($Segredo) { $seg += "`nachado: $Segredo`n" }
    [System.IO.File]::WriteAllText((Join-Path $dir 'security-report.md'), $seg, (New-Object System.Text.UTF8Encoding($false)))

    return $dir
}

function New-GhFalso {
    <#
      Um 'gh' de mentira: um .cmd que delega para um .ps1 irmao.

      E .cmd porque e o que o PATH resolve como executavel - ver o LIMITE
      DECLARADO DO MOCK no cabecalho desta suite. O comportamento dele e
      configurado por variavel de ambiente, herdada pelo processo filho:
        OS_GH_FALSO_LOG          arquivo onde ele registra cada invocacao
        OS_GH_FALSO_AUTH         '1' autenticado, qualquer outra coisa nao
        OS_GH_FALSO_PRLIST       JSON que o 'pr list' devolve
        OS_GH_FALSO_CREATE_EXIT  codigo de saida do 'pr create'
    #>
    $d = Join-Path $env:TEMP ("gh-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null

    $cmd = "@echo off`r`n" +
           "powershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh-falso.ps1`" %*`r`n" +
           "exit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText((Join-Path $d 'gh.cmd'), $cmd, (New-Object System.Text.ASCIIEncoding))

    $ps = @'
$log = $env:OS_GH_FALSO_LOG
if ($log) { [System.IO.File]::AppendAllText($log, (($args -join ' ') + [Environment]::NewLine)) }
if ($args.Count -eq 0) { exit 1 }
if ($args[0] -eq '--version') { Write-Output 'gh version 2.99.0 (falso)'; exit 0 }
if ($args[0] -eq 'auth') {
    if ($env:OS_GH_FALSO_AUTH -eq '1') {
        Write-Output 'github.com'
        Write-Output '  - Logged in to github.com account fixture (keyring)'
        exit 0
    }
    Write-Output 'You are not logged into any GitHub hosts. Run gh auth login'
    exit 1
}
if ($args.Count -ge 2 -and $args[0] -eq 'pr' -and $args[1] -eq 'list') {
    $j = $env:OS_GH_FALSO_PRLIST
    if (-not $j) { $j = '[]' }
    Write-Output $j
    $c = 0
    if ($env:OS_GH_FALSO_PRLIST_EXIT) { $c = [int]$env:OS_GH_FALSO_PRLIST_EXIT }
    exit $c
}
if ($args.Count -ge 2 -and $args[0] -eq 'pr' -and $args[1] -eq 'create') {
    $c = 0
    if ($env:OS_GH_FALSO_CREATE_EXIT) { $c = [int]$env:OS_GH_FALSO_CREATE_EXIT }
    if ($c -eq 0) { Write-Output 'https://github.com/fixture/repo/pull/7' }
    else { Write-Output 'erro falso do gh' }
    exit $c
}
exit 1
'@
    [System.IO.File]::WriteAllText((Join-Path $d 'gh-falso.ps1'), $ps, (New-Object System.Text.ASCIIEncoding))
    return $d
}

function Get-PathSemGh {
    <#
      O PATH desta maquina, sem nenhuma pasta que contenha um 'gh'.

      Isto e o que torna o caso "gh ausente" mensuravel sem desinstalar nada e
      sem esvaziar o PATH - esvaziar tiraria tambem o 'git', e o script
      morreria por outro motivo que nao o que se quer medir. Um teste que sai
      2 pelo motivo errado nao prova nada.
    #>
    $partes = @()
    foreach ($p in ($env:PATH -split ';')) {
        $t = ("" + $p).Trim()
        if (-not $t) { continue }
        $tem = $false
        foreach ($e in @('gh.exe', 'gh.cmd', 'gh.bat')) {
            try { if (Test-Path (Join-Path $t $e) -PathType Leaf) { $tem = $true } } catch { }
        }
        if (-not $tem) { $partes += $t }
    }
    return ($partes -join ';')
}

function Invoke-ScriptFilho {
    <#
      Roda um .ps1 da plataforma como PROCESSO FILHO e devolve Saida e Exit.

      '-File' e nao '-Command' de proposito: com '-File' o PowerShell liga os
      argumentos ao 'param()' do script como faria na linha de comando, e
      switch continua switch. Com '-Command' e uma string montada, '-Confirmar'
      entre aspas chega como VALOR posicional, nao como switch - e o teste da
      troca confirmada passaria a medir o caminho nao-confirmado sem avisar.

      '-Path' aqui e o PATH do processo: o filho herda o ambiente, entao o
      mock do 'gh' entra pela frente da variavel do processo de teste.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Script,
        [string[]]$Argumentos = @(),
        [string]$PathDoProcesso
    )
    $pathAnterior = $env:PATH
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($PSBoundParameters.ContainsKey('PathDoProcesso')) { $env:PATH = $PathDoProcesso }
        $todos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script) + $Argumentos
        $saida = (& powershell @todos 2>&1 | Out-String)
        $codigo = $LASTEXITCODE
    } finally {
        $env:PATH = $pathAnterior
        $ErrorActionPreference = $anterior
    }
    return [pscustomobject]@{ Saida = $saida; Exit = $codigo }
}

function Set-GhFalso {
    <#
      Configura o mock. Devolve o caminho do log, que comeca vazio.
    #>
    param(
        [switch]$Autenticado,
        [string]$PrList = '[]',
        [int]$CreateExit = 0,
        [int]$PrListExit = 0
    )
    $log = Join-Path $env:TEMP ("ghlog-" + [guid]::NewGuid().ToString('N').Substring(0, 10) + ".txt")
    [System.IO.File]::WriteAllText($log, '', (New-Object System.Text.ASCIIEncoding))
    $env:OS_GH_FALSO_LOG = $log
    $env:OS_GH_FALSO_AUTH = $(if ($Autenticado) { '1' } else { '0' })
    $env:OS_GH_FALSO_PRLIST = $PrList
    $env:OS_GH_FALSO_CREATE_EXIT = ("" + $CreateExit)
    $env:OS_GH_FALSO_PRLIST_EXIT = ("" + $PrListExit)
    return $log
}

function Clear-GhFalso {
    param([string]$Pasta, [string]$Log)
    foreach ($v in @('OS_GH_FALSO_LOG', 'OS_GH_FALSO_AUTH', 'OS_GH_FALSO_PRLIST',
                     'OS_GH_FALSO_CREATE_EXIT', 'OS_GH_FALSO_PRLIST_EXIT')) {
        Remove-Item ("env:" + $v) -ErrorAction SilentlyContinue
    }
    if ($Pasta -and (Test-Path $Pasta)) { Remove-Item $Pasta -Recurse -Force -ErrorAction SilentlyContinue }
    if ($Log -and (Test-Path $Log)) { Remove-Item $Log -Force -ErrorAction SilentlyContinue }
}

function Test-LogChamouCreate {
    param([string]$Log)
    if (-not (Test-Path $Log)) { return $false }
    $txt = [System.IO.File]::ReadAllText($Log)
    return ($txt -match '(?m)^pr create')
}

# =============================================================================
# UNITARIO - branch-comum
# =============================================================================

Test-Caso "Test-NomeDeBranch: aceita nome valido e recusa os quatro casos ruins" {
    # O par positivo primeiro: sem ele, uma funcao que recusasse TUDO passaria
    # nas quatro negativas abaixo.
    Assert-True ((Test-NomeDeBranch -Nome '2.8-ci') -eq '') "recusou um nome valido"
    Assert-True ((Test-NomeDeBranch -Nome 'feat/pr-local') -eq '') "recusou um nome valido com barra"

    Assert-True ((Test-NomeDeBranch -Nome '') -ne '') "aceitou nome vazio"

    # A MENSAGEM, e nao so o veredito. Achado do qa-reviewer nas DUAS rodadas:
    # o 'check-ref-format' recusa espaco e hifen inicial sozinho (medido: 128
    # nos dois), entao apagar as duas regras manuais nao mudaria veredito
    # nenhum e este caso continuaria verde. O que as regras acrescentam e a
    # mensagem - entao e a mensagem que tem de ser medida, senao elas nao tem
    # caso e some sem ninguem notar.
    #
    # O TRECHO CASADO E UNICO DA MENSAGEM PROPRIA, e a primeira versao disto
    # nao era: ela procurava 'espaco', e a mensagem generica de fallback e
    # "o Git recusa 'com espaco' como nome de branch" - que contem a palavra
    # porque o NOME contem. A assercao passava com a regra apagada. Achado
    # pela mutacao 05, e e a nona instancia da mesma classe nesta subfase.
    Assert-True ((Test-NomeDeBranch -Nome 'com espaco') -match 'quebra a citacao') "nao explicou o espaco"
    Assert-True ((Test-NomeDeBranch -Nome '-flag') -match 'seria lido como flag') "nao explicou o hifen inicial"
    # Este o Git recusa, e quem recusa e o 'check-ref-format', nao uma lista
    # de caracteres escrita a mao nesta casa.
    Assert-True ((Test-NomeDeBranch -Nome 'a..b') -ne '') "aceitou nome que o proprio Git recusa"
}

Test-Caso "Get-BaseDeIntegracao: responde pelo HEAD do remoto quando ele existe" {
    # A TERCEIRA INSTANCIA da classe "o caso passa pelo motivo errado", e quem
    # a achou foi o qa-reviewer, exatamente onde o briefing pediu que
    # procurasse.
    #
    # A versao anterior usava um repo com branch 'main' e passava
    # '-Locais @(''main'')'. Apagar o bloco do 'symbolic-ref' inteiro nao
    # derrubava o caso: o fallback CONVENCIONAL devolvia 'main' do mesmo
    # jeito. O caso media a resposta certa por um caminho que ele nao estava
    # exercitando.
    #
    # Agora o branch se chama 'alfa', ha DOIS locais, e nenhum deles e
    # convencional - entao os dois fallbacks estao fechados e so o HEAD do
    # remoto pode responder. O cenario e real: remoto cujo default e
    # 'develop' com um 'main' local existente escolheria a base errada.
    $repo = New-RepoFluxo -BranchInicial 'alfa' -ComRemoto
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch beta 2>$null
        $ErrorActionPreference = $anterior

        $b = Get-BaseDeIntegracao -Raiz $repo -Locais @('alfa', 'beta') -Remotos @('alfa')
        Assert-True ($b -eq 'alfa') "esperava 'alfa' pelo HEAD do remoto, veio '$b'"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Get-BaseDeIntegracao: devolve VAZIO quando nao da para saber, em vez de chutar 'main'" {
    # O par negativo que importa, e o motivo de a funcao existir: supor 'main'
    # num repositorio que nao tem 'main' produziria diff contra o nada, e o
    # diff vazio e indistinguivel de "nao mudou nada".
    $repo = New-RepoFluxo -BranchInicial 'alfa'
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch beta 2>$null
        $ErrorActionPreference = $anterior

        $b = Get-BaseDeIntegracao -Raiz $repo -Locais @('alfa', 'beta') -Remotos @()
        Assert-True ($b -eq '') "chutou '$b' em vez de admitir que nao sabe"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Get-EstadoDeBranch: NAO lista 'origin' como se fosse um branch" {
    # O defeito REAL, achado rodando contra o proprio repositorio da
    # plataforma: '%(refname:short)' de 'refs/remotes/origin/HEAD' e 'origin',
    # sem o '/HEAD' - entao filtrar a forma curta deixava passar um branch
    # chamado 'origin'. O filtro passou a ser sobre o refname COMPLETO.
    $repo = New-RepoFluxo -ComRemoto
    try {
        $e = Get-EstadoDeBranch -Raiz $repo
        Assert-True (-not $e.Indeterminado) "nao conseguiu ler o estado: $($e.Motivo)"
        # A assercao e sobre o CONJUNTO INTEIRO, e nao sobre a ausencia da
        # palavra 'origin'. Medido antes de rodar a mutacao: afrouxar o filtro
        # para a forma curta faz 'refs/remotes/origin/HEAD' virar 'HEAD' - e um
        # teste que so procurasse 'origin' aprovaria esse vazamento. Guarda
        # mais estreito que o proprio titulo foi o padrao que a 2.6 pagou sete
        # vezes; aqui ele morre pela contagem.
        Assert-True (@($e.Remotos).Count -eq 1) ("esperava SO o branch remoto real: " + (@($e.Remotos) -join ', '))
        Assert-True (@($e.Remotos)[0] -eq 'main') ("o unico remoto nao e 'main': " + (@($e.Remotos) -join ', '))
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Get-EstadoDeBranch: arvore suja conta arquivo NAO RASTREADO, e limpa conta zero" {
    $repo = New-RepoFluxo
    try {
        $limpo = Get-EstadoDeBranch -Raiz $repo
        Assert-True (@($limpo.Sujos).Count -eq 0) ("fixture nasceu suja: " + (@($limpo.Sujos) -join ' | '))

        # Arquivo NOVO, nunca rastreado. Ele tambem se perde numa troca de
        # branch, e contar so o rastreado daria uma garantia mais estreita que
        # o nome dela - que foi o padrao que a 2.6 pagou sete vezes.
        Add-SujeiraNoRepo -Repo $repo
        $sujo = Get-EstadoDeBranch -Raiz $repo
        Assert-True (@($sujo.Sujos).Count -eq 1) ("esperava 1 sujo, vieram " + @($sujo.Sujos).Count)
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Get-EstadoDeBranch: raiz inexistente vira INDETERMINADO, nunca 'limpo'" {
    $e = Get-EstadoDeBranch -Raiz (Join-Path $env:TEMP ("nao-existe-" + [guid]::NewGuid().ToString('N')))
    Assert-True ($e.Indeterminado) "respondeu sobre um repositorio que nao existe"
    Assert-True ($e.Motivo -ne '') "nao disse por que nao sabe"
    # O ponto inteiro: 'nao consegui perguntar' nao pode virar 'esta limpo'.
    Assert-True (@($e.Sujos).Count -eq 0 -and $e.Indeterminado) "arvore limpa sem indeterminacao"
}

# =============================================================================
# UNITARIO - pr-comum
# =============================================================================

Test-Caso "Test-EvidenciaParaPr: sem os relatorios, RECUSA e nomeia os dois" {
    $repo = New-RepoFluxo
    try {
        $r = Test-EvidenciaParaPr -Raiz $repo -Head (Get-HeadDoRepo $repo) -Base 'main'
        Assert-True (-not $r.Ok) "autorizou abrir PR sem evidencia nenhuma"
        Assert-True (@($r.Problemas).Count -eq 2) ("esperava 2 problemas, vieram " + @($r.Problemas).Count)
        $txt = (@($r.Problemas) -join ' | ')
        Assert-True ($txt -match 'diff-report') "nao citou o diff-report"
        Assert-True ($txt -match 'security-report') "nao citou o security-report"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: com os dois carimbados no HEAD atual, AUTORIZA" {
    # O par positivo. Sem ele, uma funcao que recusasse sempre passaria em
    # todos os casos de recusa desta suite.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Ok) ("recusou evidencia valida: " + (@($r.Problemas) -join ' | '))
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: relatorio de OUTRO commit nao serve" {
    # Evidencia velha descreve outro codigo. E a mesma regra que a dimensao
    # 'frescor' do doctor ja aplica - e e por isso que ela nao foi reescrita
    # aqui, so aplicada ao par de relatorios do PR.
    $repo = New-RepoFluxo
    try {
        $outro = '0123456789abcdef0123456789abcdef01234567'
        $null = Write-EvidenciaDePr -Repo $repo -Sha $outro
        $r = Test-EvidenciaParaPr -Raiz $repo -Head (Get-HeadDoRepo $repo) -Base 'main'
        Assert-True (-not $r.Ok) "aceitou evidencia carimbada com outro commit"
        Assert-True ((@($r.Problemas) -join ' ') -match 'carimbada') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: o SHA curto tambem carimba" {
    # Relatorios diferentes desta plataforma gravam um ou outro. Exigir so o
    # longo rejeitaria evidencia valida, e o atrito empurraria para o
    # '--no-verify' mental de pular o portao.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head.Substring(0, 7)
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Ok) ("recusou o carimbo curto: " + (@($r.Problemas) -join ' | '))
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: achado BLOQUEANTE na varredura RECUSA o PR" {
    # O terceiro portao, e ele existe porque eu o tinha prometido em prosa e
    # nao em codigo: o cabecalho do 'pr.ps1' dizia que a seguranca era
    # verificada "com o fluxo privado tendo saido 0" enquanto a funcao so
    # conferia que o arquivo existia e citava o commit. Um relatorio cheio de
    # ALTA passava pelo portao.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -ComAchadoBloqueante
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True (-not $r.Ok) "autorizou o PR com achado bloqueante em aberto"
        Assert-True (-not $r.Indeterminado) "confundiu 'achei problema' com 'nao consegui ler'"
        Assert-True ((@($r.Problemas) -join ' ') -match 'bloqueiam') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: achado ACEITO POR EXCECAO nao bloqueia (ADR-0010)" {
    # O par positivo, e ele e a distincao dificil: as duas secoes do relatorio
    # tem linhas 'MEDIA', e um grep por severidade acusaria justamente o que
    # foi deliberadamente aceito. Esta e a razao de o leitor ser reusado de
    # 'hooks-comum.ps1' em vez de reescrito aqui.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -ComAchadoAceitoPorExcecao
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Ok) ("barrou por um achado aceito por excecao: " + (@($r.Problemas) -join ' | '))
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: relatorio SEM a secao '## Achados' e INDETERMINADO, nao 'limpo'" {
    # O que impede o fail-open. 'Get-AchadosBloqueantesDoRelatorio' devolve
    # lista VAZIA quando nao consegue ler - deliberado no contexto do hook,
    # onde quem chama ja sabe pelo codigo de saida do scanner que houve
    # bloqueio. Aqui ninguem sabe: sem esta exigencia, "nao reconheco o
    # formato" viraria "nada achado, pode abrir".
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -SemSecaoDeAchados
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Indeterminado) "um relatorio de formato desconhecido passou como se estivesse limpo"
        Assert-True (-not $r.Ok) "declarou Ok junto com Indeterminado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: SHA citado no CORPO nao carimba - so o cabecalho conta" {
    # Achado do qa-reviewer. O diff-report TRANSCREVE o diff do 'STATE.md', e
    # o STATE cita SHAs de commit - hoje, seis deles. Com a busca solta pelo
    # texto inteiro, bastava o SHA do branch B aparecer em prosa dentro da
    # evidencia do branch A para a evidencia de A valer como evidencia de B.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -CarimboSoNoCorpo
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True (-not $r.Ok) "aceitou um SHA citado em prosa como se fosse carimbo"
        Assert-True ((@($r.Problemas) -join ' ') -match 'cabecalho') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: SHA em PROSA no preambulo nao carimba - carimbo e campo" {
    # O par que faltava para a segunda metade da ancora. A mutacao mostrou que
    # o caso anterior nao media a exigencia do prefixo '- ': apagar essa
    # exigencia nao derrubava nada, porque naquele fixture nao havia linha
    # nenhuma com SHA antes do primeiro '## '.
    #
    # Aqui ha - e ela esta DENTRO da janela que a ancora examina. O que a
    # mantem fora e so ela nao ser um campo de cabecalho. O relatorio real tem
    # prosa nesse ponto, num bloco '>', entao o cenario nao e inventado.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -CarimboEmProsaNoPreambulo
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True (-not $r.Ok) "aceitou prosa do preambulo como carimbo"
        Assert-True ((@($r.Problemas) -join ' ') -match 'cabecalho') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: coleta que registra a suite FALHANDO recusa" {
    # So existir e estar carimbada nunca bastou: o corpo do PR afirma, para
    # quem le no GitHub, que a evidencia traz "diff e resultado da suite".
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -ExitDaSuite 1
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True (-not $r.Ok) "autorizou o PR com a suite vermelha"
        Assert-True (-not $r.Indeterminado) "confundiu 'a suite falhou' com 'nao consegui ler'"
        Assert-True ((@($r.Problemas) -join ' ') -match 'NAO passou') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: coleta SEM a linha de codigo de saida e INDETERMINADO" {
    # '-SkipTests' produz uma coleta que declara a lacuna, e a coleta de uma
    # arvore limpa sai "(sem alteracoes contra HEAD)". Os dois passavam.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -SemLinhaDeExit
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Indeterminado) "uma coleta sem resultado de teste passou como se tivesse passado"
        Assert-True (-not $r.Ok) "declarou Ok junto com Indeterminado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: 'Codigo de saida' FORA da secao de testes nao conta" {
    # A OITAVA instancia da classe, achada pelo qa-reviewer na rodada 2: e o
    # mesmo defeito do carimbo da rodada 1, aplicado ao campo vizinho dentro
    # da propria correcao daquele defeito.
    #
    # O 'collect-diff' transcreve arquivo novo LITERALMENTE, sem prefixo. Uma
    # linha 'Codigo de saida: **0**' na coluna 0 de um rascunho nao rastreado
    # entra no relatorio, e a busca solta a aceitava como resultado da suite -
    # inclusive numa coleta '-SkipTests', onde a secao de testes nao tem linha.
    #
    # A fixture tira a linha da secao CERTA e planta uma identica na secao de
    # arquivos novos. O unico motivo possivel de recusa e a ancoragem.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -SemLinhaDeExit -ExitForaDaSecaoDeTestes
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Indeterminado) "aceitou uma linha transcrita de arquivo novo como resultado da suite"
        Assert-True (-not $r.Ok) "declarou Ok junto com Indeterminado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: secao de testes REPETIDA mais abaixo nao e lida" {
    # O par que faltava para o 'break' de 'Get-SecaoDeRelatorio'. A mutacao 13
    # mostrou que, sem ele, nada caia - porque quem encerra a secao e a
    # reatribuicao de '$dentro', e o 'break' so importa quando o MESMO titulo
    # aparece outra vez.
    #
    # E ele aparece: o coletor transcreve arquivo novo literalmente, entao
    # qualquer arquivo que contenha '## Resultado real dos testes' no corpo
    # - esta suite poderia - cria a segunda secao. A fixture deixa a secao
    # VERDADEIRA sem linha de exit e poe a linha so na copia.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -SemLinhaDeExit -SecaoDeTestesDuplicada
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Indeterminado) "leu a secao repetida como se fosse a verdadeira"
        Assert-True ($r.MotivoIndeterminado -match 'codigo de saida da suite') `
            "indeterminou por outro motivo: $($r.MotivoIndeterminado)"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: coleta contra OUTRA referencia que nao a base recusa" {
    # A coleta padrao compara contra HEAD. O PR vai contra a base. Sao
    # comparacoes diferentes, e a de HEAD nao descreve a mudanca do PR.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch outra 2>$null
        git -C $repo commit -q --allow-empty -m "feat: avanca o main" --no-verify 2>$null
        $ErrorActionPreference = $anterior
        $head = Get-HeadDoRepo $repo

        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -Comparacao 'outra' -LinhasDeDiff 10
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True (-not $r.Ok) "aceitou coleta feita contra outra referencia"
        Assert-True ((@($r.Problemas) -join ' ') -match 'outra comparacao') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: coleta com diff VAZIO recusa, mesmo carimbada e com a suite verde" {
    # O achado que fecha a interacao entre as duas correcoes da rodada 1:
    # 'Test-PublicavelNoRemoto' passou a EXIGIR arvore limpa, e com arvore
    # limpa a coleta padrao contra HEAD tem diff vazio. Sem este portao, toda
    # coleta padrao que chegasse ao '-Abrir' passaria descrevendo NADA,
    # enquanto o corpo publicado afirma trazer o diff.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -Comparacao 'main' -LinhasDeDiff 0
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True (-not $r.Ok) "autorizou um PR cuja evidencia nao descreve mudanca nenhuma"
        Assert-True ((@($r.Problemas) -join ' ') -match 'VAZIO') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-EvidenciaParaPr: coleta SEM a tabela de escopo e INDETERMINADO" {
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -SemEscopoColetado
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Indeterminado) "nao declarou que desconhece o formato"
        Assert-True (-not $r.Ok) "declarou Ok junto com Indeterminado"
        # PELA RAZAO CERTA: a checagem seguinte, de SHA que nao resolve,
        # tambem devolve Indeterminado. Sem medir a mensagem, apagar esta
        # guarda nao derrubaria o caso - e foi o que a mutacao 16 mostrou.
        Assert-True ($r.MotivoIndeterminado -match 'nao declara contra que referencia') `
            "indeterminou por outro motivo: $($r.MotivoIndeterminado)"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "CONTRATO: os relatorios REAIS dos dois geradores sao aceitos pelo portao" {
    # O CASO QUE FECHA O ACOPLAMENTO ENTRE TRES ARQUIVOS, e a versao anterior
    # dele era, ela mesma, a 12a instancia da classe que ele existe para
    # corrigir:
    #
    #   - chamava-se "aceito pelo portao" e NAO chamava 'Test-EvidenciaParaPr';
    #   - rodava o coletor com '-SkipTests', que produz um relatorio SEM linha
    #     de codigo de saida - justamente o que o portao recusa.
    #
    # Ou seja: o caso afirmava que o portao aceita o relatorio real, e o
    # portao teria recusado aquele relatorio. Achado do qa-reviewer na rodada
    # 4, dentro do caso que eu tinha escrito na rodada 3 para corrigir essa
    # mesma classe.
    #
    # Agora os DOIS geradores rodam de verdade e o portao le a saida deles. O
    # contrato tem quatro partes, e as quatro passam a ser medidas:
    #   1. a referencia, na tabela 'Escopo COLETADO';
    #   2. o carimbo do HEAD, no cabecalho dos dois relatorios;
    #   3. a linha 'Codigo de saida', na secao de testes;
    #   4. a secao '## Achados', no relatorio de seguranca.
    #
    # Se qualquer um dos geradores mudar o formato, este caso cai - e era
    # disso que o '-Abrir' precisava para nao voltar a nunca autorizar nada.
    $repo = New-RepoFluxo -ComRemoto
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        [System.IO.File]::WriteAllText((Join-Path $repo 'mudanca.txt'),
            "uma mudanca de verdade, para o diff nao sair vazio`n",
            (New-Object System.Text.UTF8Encoding($false)))
        git -C $repo add -A 2>$null
        git -C $repo commit -q -m "feat: mudanca para o contrato" --no-verify 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $head = Get-HeadDoRepo $repo

        # '-TestCommand' em vez de '-SkipTests': o relatorio PRECISA ter a
        # linha de codigo de saida, senao nao e o relatorio que o portao
        # espera - e era esse o defeito da versao anterior deste caso.
        $coletor = Join-Path $OsRoot 'scripts\collect-diff.ps1'
        $rc = Invoke-ScriptFilho -Script $coletor `
                  -Argumentos @('-Path', $repo, '-Contra', 'main', '-TestCommand', 'cmd /c exit 0')
        $pDiff = Join-Path $repo 'artifacts\review\diff-report.md'
        Assert-True (Test-Path $pDiff) "o coletor nao produziu relatorio: $($rc.Saida)"

        # O scanner REAL, pelo mesmo motivo: e dele que sai a secao '## Achados'.
        $scanner = Join-Path $OsRoot 'scripts\security-scan.ps1'
        $rs = Invoke-ScriptFilho -Script $scanner -Argumentos @('-Path', $repo, '-SemHistorico', '-SemRede')
        $pSeg = Join-Path $repo 'artifacts\review\security-report.md'
        Assert-True (Test-Path $pSeg) "o scanner nao produziu relatorio: $($rs.Saida)"

        # 1. A tabela real TEM a linha do '--stat' antes da outra. Se um dia
        #    nao tiver, este caso deixa de medir o que existe e tem de cair.
        $txt = Get-Texto $pDiff
        Assert-True ($txt -match '(?m)^\|\s*`git diff --stat ') `
            "o formato mudou: a tabela nao tem mais a linha do '--stat'"

        # 2. E O PORTAO INTEIRO sobre os dois relatorios reais. Esta e a
        #    assercao que o caso anterior prometia e nao fazia.
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Ok) ("o portao RECUSOU os relatorios reais: " +
            $r.MotivoIndeterminado + " | " + (@($r.Problemas) -join ' | '))
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "CONTRATO: coleta real com -SkipTests e INDETERMINADO, nao aceita" {
    # O par negativo do caso acima, e ele vale por si: '-SkipTests' produz um
    # relatorio REAL, do gerador REAL, que o portao tem de recusar - porque
    # nele nao ha resultado de suite nenhum, e o corpo do PR afirmaria trazer
    # um.
    #
    # Sem este par, o caso positivo poderia passar com um portao que aceitasse
    # qualquer coisa vinda do coletor.
    $repo = New-RepoFluxo -ComRemoto
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        [System.IO.File]::WriteAllText((Join-Path $repo 'mudanca.txt'), "x`n",
            (New-Object System.Text.UTF8Encoding($false)))
        git -C $repo add -A 2>$null
        git -C $repo commit -q -m "feat: mudanca" --no-verify 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $head = Get-HeadDoRepo $repo

        $coletor = Join-Path $OsRoot 'scripts\collect-diff.ps1'
        $null = Invoke-ScriptFilho -Script $coletor `
                    -Argumentos @('-Path', $repo, '-Contra', 'main', '-SkipTests')
        $scanner = Join-Path $OsRoot 'scripts\security-scan.ps1'
        $null = Invoke-ScriptFilho -Script $scanner -Argumentos @('-Path', $repo, '-SemHistorico', '-SemRede')

        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($r.Indeterminado) "aceitou uma coleta real feita sem rodar os testes"
        Assert-True ($r.MotivoIndeterminado -match 'codigo de saida da suite') `
            "indeterminou por outro motivo: $($r.MotivoIndeterminado)"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "CONTRATO: achado REAL do scanner e lido pelo portao, e barra o PR" {
    # A terceira perna do contrato, e ela faltava: os dois casos acima rodam o
    # scanner sobre uma fixture LIMPA, entao o relatorio real nao tem linha de
    # achado nenhuma e o leitor de achados nunca e exercitado contra o formato
    # de verdade. Ele so tinha sido testado contra texto que EU escrevi.
    #
    # No caminho do PR esse leitor e o UNICO arbitro: o hook de pre-commit
    # barra pelo codigo de saida do scanner, mas o 'pr.ps1 -Abrir' so LE o
    # relatorio. Se o scanner mudar a forma da linha de achado, o leitor
    # devolve lista vazia, o portao responde 'Ok', e o PR sai com 'ALTA' em
    # aberto - falhando ABERTO, ao contrario do defeito da rodada 3.
    #
    # Os valores sao fabricados, com formato valido para os padroes do
    # scanner - os mesmos que a suite 'collectors' ja usa.
    $repo = New-RepoFluxo -ComRemoto
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        # O token e montado POR PARTES, e nao escrito inteiro, pelo mesmo
        # motivo que 'hooks.ps1:715' e 'doctor.ps1' ja fazem assim: escrever o
        # literal completo faria o scanner acusar ALTA neste arquivo, e a
        # saida seria declarar o marcador de fixture - que e a unica rota de
        # rebaixamento que '-ParaPublicacao' NAO anula, e que cobre o arquivo
        # INTEIRO. A subfase 2.5 enfrentou exatamente isto e decidiu nao
        # acrescentar um terceiro arquivo sob o marcador.
        #
        # A fixture no disco recebe o token completo, entao o scanner real
        # continua tendo o que acusar: o caso nao perde forca nenhuma.
        $tokenFabricado = 'ghp_' + ('F' * 36)
        [System.IO.File]::WriteAllText((Join-Path $repo 'app.js'),
            ("const auth = '" + $tokenFabricado + "';`n"),
            (New-Object System.Text.UTF8Encoding($false)))
        git -C $repo add -A 2>$null
        git -C $repo commit -q -m "feat: com credencial fabricada" --no-verify 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $head = Get-HeadDoRepo $repo

        $coletor = Join-Path $OsRoot 'scripts\collect-diff.ps1'
        $null = Invoke-ScriptFilho -Script $coletor `
                    -Argumentos @('-Path', $repo, '-Contra', 'main', '-TestCommand', 'cmd /c exit 0')
        $scanner = Join-Path $OsRoot 'scripts\security-scan.ps1'
        $null = Invoke-ScriptFilho -Script $scanner -Argumentos @('-Path', $repo, '-SemHistorico', '-SemRede')

        # DUAS perguntas diferentes, com mensagens diferentes - e a versao
        # anterior juntava as duas numa so, dizendo "o scanner nao produziu
        # linha de achado" quando a causa podia ser o FORMATO ter mudado. Isso
        # levava a consertar a fixture em vez do leitor. Achado 4 da rodada 6.
        #
        # 1. O scanner ACHOU alguma coisa? Conferido por um sinal INDEPENDENTE
        #    da regex do leitor: o resumo numerico.
        $txtSeg = Get-Texto (Join-Path $repo 'artifacts\review\security-report.md')
        $mAltas = [regex]::Match($txtSeg, '(?m)^- Achados ALTA:\s*(\d+)')
        Assert-True ($mAltas.Success -and [int]$mAltas.Groups[1].Value -gt 0) `
            "o scanner nao acusou o token fabricado: este caso deixou de medir o que promete"

        # 2. E a linha dele casa com o formato que o leitor espera? Se cair
        #    AQUI, o defeito e de FORMATO - o scanner mudou a forma da linha, e
        #    quem precisa mudar e o leitor, nao a fixture.
        Assert-True ($txtSeg -match '(?m)^\|\s*(ALTA|MEDIA)\s*\|') `
            "o scanner acusou, mas a linha nao casa com a regex do leitor: o FORMATO mudou"

        # E o PORTAO tem de LER essa linha e recusar.
        $r = Test-EvidenciaParaPr -Raiz $repo -Head $head -Base 'main'
        Assert-True (-not $r.Ok) "o portao autorizou o PR com achado bloqueante em aberto"
        Assert-True (-not $r.Indeterminado) "confundiu 'achei problema' com 'nao consegui ler'"
        Assert-True ((@($r.Problemas) -join ' ') -match 'bloqueiam') `
            "recusou por outro motivo: $(@($r.Problemas) -join ' | ')"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-PublicavelNoRemoto: arvore suja recusa - a evidencia descreve o que nao esta no remoto" {
    $repo = New-RepoFluxo -ComRemoto
    try {
        Add-SujeiraNoRepo -Repo $repo
        $e = Get-EstadoDeBranch -Raiz $repo
        $r = Test-PublicavelNoRemoto -Raiz $repo -Branch 'main' -Head (Get-HeadDoRepo $repo) -Sujos $e.Sujos
        Assert-True (-not $r.Ok) "autorizou abrir PR com trabalho so no disco"
        Assert-True ((@($r.Problemas) -join ' ') -match 'nao commitado') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-PublicavelNoRemoto: branch que o remoto nao conhece recusa" {
    $repo = New-RepoFluxo -ComRemoto
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        $r = Test-PublicavelNoRemoto -Raiz $repo -Branch 'trabalho' -Head (Get-HeadDoRepo $repo) -Sujos @()
        Assert-True (-not $r.Ok) "autorizou PR de um branch que o GitHub nao tem"
        Assert-True ((@($r.Problemas) -join ' ') -match 'push') "nao disse como resolver"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-PublicavelNoRemoto: remoto em OUTRO commit recusa" {
    # O caso que os DOIS revisores acharam: empurro Y, commito Z aqui, coleto
    # em Z, abro o PR. O PR mostra Y e o corpo publicado afirma Z.
    $repo = New-RepoFluxo -ComRemoto
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        # Um commit DEPOIS do "push": e isso que cria a divergencia.
        [System.IO.File]::WriteAllText((Join-Path $repo 'depois.txt'), "z`n", (New-Object System.Text.UTF8Encoding($false)))
        git -C $repo add -A 2>$null
        git -C $repo commit -q -m "feat: commit local depois do push" --no-verify 2>$null
        $ErrorActionPreference = $anterior

        $r = Test-PublicavelNoRemoto -Raiz $repo -Branch 'trabalho' -Head (Get-HeadDoRepo $repo) -Sujos @()
        Assert-True (-not $r.Ok) "deixou o corpo do PR afirmar um commit que o GitHub nao mostra"
        Assert-True ((@($r.Problemas) -join ' ') -match 'o remoto esta em') "recusou pelo motivo errado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Test-PublicavelNoRemoto: remoto igual ao HEAD e arvore limpa AUTORIZA" {
    # O par positivo. Sem ele, uma funcao que recusasse sempre passaria nos
    # tres casos acima e tornaria o '-Abrir' inalcancavel.
    $repo = New-RepoFluxo -ComRemoto
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'

        $r = Test-PublicavelNoRemoto -Raiz $repo -Branch 'trabalho' -Head (Get-HeadDoRepo $repo) -Sujos @()
        Assert-True ($r.Ok) ("barrou um estado publicavel: " + (@($r.Problemas) -join ' | '))
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Get-CorpoDePr: aponta para a evidencia e NAO transcreve o conteudo dela" {
    # 'artifacts/' e ignorado pelo Git e nao viaja num clone; o corpo do PR,
    # sim, vai para o GitHub. Colar achado de seguranca ali publicaria num
    # lugar que esta plataforma nunca autorizou.
    $repo = New-RepoFluxo
    try {
        $head = Get-HeadDoRepo $repo
        $segredo = 'ACHADO-DE-FIXTURE-nao-pode-vazar-9f3a2b'
        $null = Write-EvidenciaDePr -Repo $repo -Sha $head -Segredo $segredo

        $corpo = Get-CorpoDePr -Raiz $repo -Head $head -Base 'main'
        Assert-True ($corpo -notmatch [regex]::Escape($segredo)) "o corpo do PR transcreveu o conteudo do relatorio"
        # E o par positivo: ele PRECISA apontar, senao quem revisa nao sabe
        # o que regerar. Um corpo vazio tambem passaria na assercao de cima.
        Assert-True ($corpo -match 'diff-report\.md') "o corpo nao aponta para o diff-report"
        Assert-True ($corpo -match 'security-report\.md') "o corpo nao aponta para o security-report"
        Assert-True ($corpo -match 'ADR-0011') "o corpo nao declara o limite do modelo client-side"
        Assert-True ($corpo -match 'no-verify') "o corpo nao diz que os hooks locais sao contornaveis"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "Get-ArgumentosDePrCreate: monta base/head/title/body e NENHUMA flag de credencial" {
    $corpo = "corpo qualquer`nem duas linhas"
    $a = @(Get-ArgumentosDePrCreate -Base 'main' -Origem 'trabalho' -Titulo 'feat: x' -Corpo $corpo)

    Assert-True ($a[0] -eq 'pr' -and $a[1] -eq 'create') "nao e um 'pr create'"
    $i = [array]::IndexOf($a, '--base')
    Assert-True ($i -ge 0 -and $a[$i + 1] -eq 'main') "a base nao chegou"
    $i = [array]::IndexOf($a, '--head')
    Assert-True ($i -ge 0 -and $a[$i + 1] -eq 'trabalho') "o branch de origem nao chegou"
    $i = [array]::IndexOf($a, '--body')
    # A linha INTEIRA, com a quebra. E exatamente o que o mock nao consegue
    # testemunhar, e por isso a afirmacao vive aqui.
    Assert-True ($i -ge 0 -and $a[$i + 1] -eq $corpo) "o corpo chegou alterado"

    # Nenhuma credencial na linha de comando: linha de comando e visivel na
    # lista de processos da maquina. O 'gh' autentica por navegador.
    foreach ($x in $a) {
        Assert-True (("" + $x) -notmatch '(?i)(--with-token|gh_token|github_token|password|bearer)') `
            "flag de credencial na linha de comando: $x"
    }
}

Test-Caso "Get-ArgumentosDePrCreate: '-Rascunho' acrescenta '--draft', e sem ele nao ha '--draft'" {
    $com = @(Get-ArgumentosDePrCreate -Base 'main' -Origem 'b' -Titulo 't' -Corpo 'c' -Rascunho)
    $sem = @(Get-ArgumentosDePrCreate -Base 'main' -Origem 'b' -Titulo 't' -Corpo 'c')
    Assert-True ($com -contains '--draft') "'-Rascunho' nao virou '--draft'"
    Assert-True ($sem -notcontains '--draft') "'--draft' apareceu sem ninguem pedir"
}

# =============================================================================
# FUNCIONAL - branch.ps1
# =============================================================================

Test-Caso "branch.ps1: listar responde 0 e diz em que branch estamos" {
    $repo = New-RepoFluxo -ComRemoto
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo)
        Assert-True ($r.Exit -eq 0) "listar saiu $($r.Exit)"
        Assert-True ($r.Saida -match 'atual') "nao mostrou o branch atual"
        Assert-True ($r.Saida -match 'main') "nao nomeou 'main'"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Criar cria e NAO troca sozinho" {
    # Criar e ir sao decisoes diferentes. Juntar as duas e exatamente como a
    # troca implicita acontece sem ninguem decidir por ela.
    $repo = New-RepoFluxo
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Criar', '2.8-ci')
        Assert-True ($r.Exit -eq 0) "criar saiu $($r.Exit): $($r.Saida)"
        Assert-True ((Get-BranchAtual $repo) -eq 'main') "trocou de branch sem ninguem pedir"
        $e = Get-EstadoDeBranch -Raiz $repo
        Assert-True (@($e.Locais) -contains '2.8-ci') "o branch nao foi criado"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Criar com nome que ja existe RECUSA com 1" {
    $repo = New-RepoFluxo
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Criar', 'main')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit)"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Criar com nome invalido RECUSA com 1" {
    $repo = New-RepoFluxo
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Criar', 'a..b')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit)"
        $e = Get-EstadoDeBranch -Raiz $repo
        Assert-True (@($e.Locais).Count -eq 1) "criou alguma coisa mesmo recusando"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -De '-m' RECUSA, e o branch atual continua existindo" {
    # Achado do qa-reviewer, e e DESTRUTIVO: '-Criar x -De -m' virava
    # 'git branch x -m', e '-m' RENOMEIA o branch atual para 'x'. O script
    # entao imprimia "CRIADO x ... voce continua em 'main'" - e 'main' nao
    # existia mais. A justificativa que o 'Test-NomeDeBranch' ja dava para
    # barrar hifen inicial valia aqui e nao tinha sido aplicada.
    $repo = New-RepoFluxo
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Criar', 'x', '-De', '-m')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        # PELA GUARDA DO HIFEN, e nao por tabela: a mutacao mostrou que sem
        # ela o 'rev-parse --verify' logo abaixo tambem recusa, porque o git
        # le '-m' como opcao desconhecida. O exit 1 vinha de qualquer jeito, e
        # o caso aprovava a remocao da guarda. Dado que a correcao esta
        # coberta pelos dois lados, o que esta guarda acrescenta e a MENSAGEM
        # - entao e a mensagem que tem de ser medida, senao ela nao tem caso.
        Assert-True ($r.Saida -match 'comeca com hifen') `
            "recusou, mas nao pela guarda do hifen: $($r.Saida)"
        $e = Get-EstadoDeBranch -Raiz $repo
        Assert-True (@($e.Locais) -contains 'main') "o branch 'main' sumiu - o '-m' passou para o git"
        Assert-True (@($e.Locais) -notcontains 'x') "criou 'x' mesmo recusando"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -De que nao resolve para commit recusa com 1" {
    $repo = New-RepoFluxo
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Criar', 'x', '-De', 'fantasma')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True ((Get-EstadoDeBranch -Raiz $repo).Locais -notcontains 'x') "criou a partir do nada"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -De VALIDO cria a partir dele" {
    # O par positivo dos dois acima: uma validacao que recusasse tudo passaria
    # nos dois e tornaria o '-De' inutil.
    $repo = New-RepoFluxo
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch origem 2>$null
        $ErrorActionPreference = $anterior

        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Criar', 'x', '-De', 'origem')
        Assert-True ($r.Exit -eq 0) "esperava 0, saiu $($r.Exit): $($r.Saida)"
        Assert-True ((Get-EstadoDeBranch -Raiz $repo).Locais -contains 'x') "nao criou o branch"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Trocar com arvore SUJA recusa com 1 e NAO troca" {
    # Requisito nomeado da 2.7: nunca trocar de branch com working tree suja.
    $repo = New-RepoFluxo
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch destino 2>$null
        $ErrorActionPreference = $anterior
        Add-SujeiraNoRepo -Repo $repo

        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Trocar', 'destino')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit)"
        Assert-True ((Get-BranchAtual $repo) -eq 'main') "trocou mesmo com a arvore suja"
        Assert-True ($r.Saida -match 'novo\.txt') "nao nomeou o arquivo que seria perdido"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Trocar com arvore SUJA recusa MESMO com -Confirmar" {
    # Confirmar e autorizar a TROCA, nao autorizar perder trabalho. Se este
    # caso cair, a guarda virou um aviso que se apaga digitando mais uma flag.
    $repo = New-RepoFluxo
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch destino 2>$null
        $ErrorActionPreference = $anterior
        Add-SujeiraNoRepo -Repo $repo

        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Trocar', 'destino', '-Confirmar')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit)"
        Assert-True ((Get-BranchAtual $repo) -eq 'main') "'-Confirmar' atropelou a guarda da arvore suja"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Trocar com arvore limpa e SEM -Confirmar nao troca" {
    # Requisito nomeado da 2.7: nunca trocar de branch implicitamente.
    $repo = New-RepoFluxo
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch destino 2>$null
        $ErrorActionPreference = $anterior

        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Trocar', 'destino')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit)"
        Assert-True ((Get-BranchAtual $repo) -eq 'main') "trocou sem confirmacao"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Trocar com arvore limpa e COM -Confirmar TROCA" {
    # O par positivo dos dois casos acima. Sem ele, um script que recusasse
    # toda troca passaria em ambos - e o guarda-corpo viraria uma parede.
    $repo = New-RepoFluxo
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo branch destino 2>$null
        $ErrorActionPreference = $anterior

        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Trocar', 'destino', '-Confirmar')
        Assert-True ($r.Exit -eq 0) "esperava 0, saiu $($r.Exit): $($r.Saida)"
        Assert-True ((Get-BranchAtual $repo) -eq 'destino') "disse que trocou e nao trocou"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: -Trocar para branch inexistente recusa com 1" {
    $repo = New-RepoFluxo
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $repo, '-Trocar', 'fantasma', '-Confirmar')
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit)"
        Assert-True ((Get-BranchAtual $repo) -eq 'main') "saiu do branch por causa de um nome que nao existe"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "branch.ps1: fora de repositorio sai 2, nao 0 e nao 1" {
    # 2 e 'nao consegui determinar' (ADR-0009). Sair 0 aqui seria dizer que
    # esta tudo bem com branches que nao existem.
    $fora = Join-Path $env:TEMP ("semgit-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $fora -Force | Out-Null
    try {
        $r = Invoke-ScriptFilho -Script $ScriptBranch -Argumentos @('-Path', $fora)
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit): $($r.Saida)"
    } finally { Remove-Item $fora -Recurse -Force -ErrorAction SilentlyContinue }
}

# =============================================================================
# FUNCIONAL - pr.ps1, com o 'gh' mockado
# =============================================================================

Test-Caso "pr.ps1: 'gh' AUSENTE sai 2 - nunca falso sucesso" {
    # Requisito nomeado da 2.7. O PATH e o da maquina MENOS as pastas que tem
    # 'gh': tirar o PATH inteiro tiraria o 'git' junto, e o script sairia 2
    # pelo motivo errado - um 2 certo pela razao errada nao mede nada.
    $repo = New-RepoFluxo -ComRemoto
    try {
        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo) -PathDoProcesso (Get-PathSemGh)
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit): $($r.Saida)"
        # Pelo motivo CERTO, e nao por um 2 qualquer: sem o portao, o script
        # ainda sairia 2 mais adiante - o 'gh' ausente faz a consulta falhar
        # de qualquer jeito. Um 2 pela razao errada aprovaria a remocao do
        # portao. So a mensagem do PATH distingue os dois caminhos.
        Assert-True ($r.Saida -match 'PATH') "saiu 2, mas nao pelo portao do 'gh' ausente"
    } finally { Remove-RepoFluxo $repo }
}

Test-Caso "pr.ps1: 'gh' instalado e DESLOGADO sai 2 e manda rodar 'gh auth login'" {
    # Os dois estados negativos sao diferentes de proposito: 'nao instalado' e
    # 'instalado e deslogado' levam a acoes diferentes, e juntar os dois daria
    # o conselho errado.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso
    try {
        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo) -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit): $($r.Saida)"
        Assert-True ($r.Saida -match 'auth login') "nao disse como autenticar"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: consulta com ZERO PRs diz 'nenhum PR aberto', sem linha fantasma" {
    # O defeito MEDIDO no dogfooding: 'ConvertFrom-Json' sobre '[]' nao
    # devolve $null - devolve um Object[] VAZIO como UM item do pipeline, e a
    # contagem dava 1. A lista vazia imprimia uma linha '#    ()'.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo) -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 0) "esperava 0, saiu $($r.Exit): $($r.Saida)"
        Assert-True ($r.Saida -match 'nenhum PR aberto') "nao disse que nao ha PR"
        Assert-True ($r.Saida -notmatch '(?m)^\s*#\s') "imprimiu uma linha de PR fantasma"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: consulta com DOIS PRs lista os dois" {
    # O par positivo do caso acima: um filtro que apagasse tudo passaria la e
    # cairia aqui. Foi essa a correcao errada que eu quase apliquei.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $json = '[{"number":7,"title":"primeiro","headRefName":"a"},{"number":8,"title":"segundo","headRefName":"b"}]'
    $log = Set-GhFalso -Autenticado -PrList $json
    try {
        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo) -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 0) "esperava 0, saiu $($r.Exit): $($r.Saida)"
        Assert-True ($r.Saida -match 'primeiro') "nao listou o primeiro PR"
        Assert-True ($r.Saida -match 'segundo') "nao listou o segundo PR"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: consulta com UM PR lista esse um" {
    # O caso do meio, e ele existe porque a correcao errada que eu considerei
    # - filtrar pela FORMA do que sai do ConvertFrom-Json - passaria com zero
    # e com dois, e descartaria exatamente este. Testar so as pontas teria
    # aprovado o conserto errado.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado -PrList '[{"number":9,"title":"unico","headRefName":"c"}]'
    try {
        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo) -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 0) "esperava 0, saiu $($r.Exit): $($r.Saida)"
        Assert-True ($r.Saida -match 'unico') "perdeu o unico PR aberto"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: resposta ILEGIVEL do 'gh' sai 2, e nao 'nenhum PR aberto'" {
    # Fail-open achado pelo qa-reviewer: 'Invoke-Gh' junta stderr na saida
    # (2>&1), e o cabecalho desta casa diz que o 'gh' escreve aviso em stderr
    # com frequencia. Um aviso fazia o 'ConvertFrom-Json' lancar, o
    # 'catch { $prs = @() }' devolvia lista vazia, e o script imprimia
    # "nenhum PR aberto" com exit 0. "Nao consegui ler" virando fato.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado -PrList 'warning: isto nao e JSON'
    try {
        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo) `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit): $($r.Saida)"
        Assert-True ($r.Saida -notmatch 'nenhum PR aberto') "declarou lista vazia sem ter lido lista nenhuma"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: 'gh pr list' FALHANDO sai 2" {
    # A guarda '-not $lista.Ok' nao tinha caso nenhum: o mock nunca falhava
    # no 'pr list'. Guarda sem caso nao foi testada, foi so executada.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado -PrListExit 1
    try {
        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo) `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit): $($r.Saida)"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir com o REMOTO em outro commit recusa com 1 e nao chama 'pr create'" {
    # Os tres portoes de evidencia passam, e mesmo assim nao se abre: o que o
    # GitHub mostraria nao e o que a evidencia descreve.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        [System.IO.File]::WriteAllText((Join-Path $repo 'depois.txt'), "z`n", (New-Object System.Text.UTF8Encoding($false)))
        git -C $repo add -A 2>$null
        git -C $repo commit -q -m "feat: commit local depois do push" --no-verify 2>$null
        $ErrorActionPreference = $anterior
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo)

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "publicou um corpo que afirma um commit que o GitHub nao mostra"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir com a arvore SUJA recusa com 1 e nao chama 'pr create'" {
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo)
        Add-SujeiraNoRepo -Repo $repo

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "abriu PR descrevendo trabalho que so existe no disco"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir do branch que E a base recusa com 1" {
    # A EVIDENCIA AQUI E VALIDA DE PROPOSITO, e isso nao e detalhe de arranjo.
    #
    # A primeira versao deste caso nao escrevia evidencia nenhuma - e a
    # mutacao mostrou que ele passava pelo motivo errado: com a guarda de
    # 'branch == base' removida, o fluxo so caia no portao SEGUINTE e saia 1
    # de qualquer jeito. O caso media o numero certo pela razao errada, que e
    # a mesma classe que a 2.6 pagou sete vezes.
    #
    # Satisfazendo todos os outros portoes, so esta guarda pode recusar.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo)
        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "chamou 'pr create' mesmo recusando"
        Assert-True ($r.Saida -match 'E a base') "recusou, mas nao por ser a propria base"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir SEM evidencia recusa com 1 e NAO chama 'pr create'" {
    # Requisito nomeado da 2.7: nunca abrir PR sem diff/evidencia e security
    # valido. A segunda assercao e a que importa: sair 1 depois de ja ter
    # aberto o PR seria o pior dos mundos.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "abriu o PR antes de checar a evidencia"
        Assert-True ($r.Saida -match 'collect-diff') "nao disse como produzir a evidencia"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir com evidencia de OUTRO commit recusa com 1" {
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        # Achado 3 do qa-reviewer: sem a ref remota este caso sai 1 por DOIS
        # motivos - carimbo errado E branch ausente no remoto -, e entao ele
        # nao mede o portao que o titulo dele anuncia. A mutacao do carimbo
        # confirmou: ela morreu pelos casos unitarios, nao por este.
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $null = Write-EvidenciaDePr -Repo $repo -Sha '0123456789abcdef0123456789abcdef01234567'

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "abriu PR com evidencia velha"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir com evidencia carimbada ABRE e chama 'pr create'" {
    # O par positivo de todos os portoes acima. Sem ele, um pr.ps1 que
    # recusasse sempre passaria em cinco casos desta suite.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        # O remoto PRECISA estar na mesma ponta: sem isto o portao de
        # divergencia recusa, e com razao - o GitHub nao teria o que mostrar.
        # Satisfazer os outros portoes e o que faz este caso medir SO o seu.
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo)

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 0) "esperava 0, saiu $($r.Exit): $($r.Saida)"
        Assert-True (Test-LogChamouCreate $log) "disse que abriu e nao chamou 'pr create'"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir com achado BLOQUEANTE recusa com 1 e nao chama 'pr create'" {
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo) -ComAchadoBloqueante

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "levou o achado bloqueante para a revisao de outra pessoa"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir com relatorio de formato desconhecido sai 2, nao 0 nem 1" {
    # 2 e 'nao consegui determinar' (ADR-0009), e aqui ele e a diferenca entre
    # "a varredura passou" e "eu nao sei se a varredura passou".
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo) -SemSecaoDeAchados

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "abriu PR sem saber se a varredura passou"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: o INDETERMINADO sugere o comando da CAUSA, nao um fixo" {
    # Achado 4 do qa-reviewer: a orientacao era escolhida procurando a palavra
    # 'seguranca' DENTRO da mensagem - e a mensagem interpola nomes de
    # referencia, entao uma base chamada 'seguranca' mandaria rodar o scanner
    # quando o problema era a coleta. Virou campo.
    #
    # Campo sem caso nao e correcao, e sim outra linha nao medida. Aqui os
    # DOIS lados sao aferidos, porque so o par distingue "escolhe pela causa"
    # de "responde sempre a mesma coisa".
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'

        # Causa na COLETA: sem a linha de codigo de saida.
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo) -SemLinhaDeExit
        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit)"
        Assert-True ($r.Saida -match 'collect-diff') "nao sugeriu o coletor para um problema de coleta"
        Assert-True ($r.Saida -notmatch 'Regere a varredura') "sugeriu o scanner para um problema de coleta"

        # Causa na SEGURANCA: relatorio sem a secao '## Achados'.
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo) -SemSecaoDeAchados
        $r2 = Invoke-ScriptFilho -Script $ScriptPr `
                  -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                  -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r2.Exit -eq 2) "esperava 2, saiu $($r2.Exit)"
        Assert-True ($r2.Saida -match 'security-scan') "nao sugeriu o scanner para um problema de varredura"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: 'gh' falhando ao criar sai 2, e nao 0" {
    # O 'gh' pode recusar por motivo que este script nao controla - remoto
    # sem permissao, PR ja existente. Isso e 'nao consegui determinar', nao
    # 'abriu'. Declarar aberto o que nao abriu e o falso verde desta subfase.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado -CreateExit 1
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        # O remoto PRECISA estar na mesma ponta: sem isto o portao de
        # divergencia recusa, e com razao - o GitHub nao teria o que mostrar.
        # Satisfazer os outros portoes e o que faz este caso medir SO o seu.
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo)

        $r = Invoke-ScriptFilho -Script $ScriptPr `
                 -Argumentos @('-Path', $repo, '-Abrir', '-Titulo', 'feat: x') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 2) "esperava 2, saiu $($r.Exit): $($r.Saida)"
        Assert-True ($r.Saida -notmatch 'ABERTO') "disse 'ABERTO' depois de o gh falhar"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

Test-Caso "pr.ps1: -Abrir sem -Titulo recusa com 1" {
    # Mesmo arranjo do caso acima, e pelo mesmo motivo medido: branch
    # DIFERENTE da base e evidencia VALIDA, para que a unica coisa capaz de
    # recusar seja a falta do titulo. Sem isso, a mutacao que apaga esta
    # exigencia sobrevivia - e sobreviveu, na primeira rodada.
    $repo = New-RepoFluxo -ComRemoto
    $gh = New-GhFalso
    $log = Set-GhFalso -Autenticado
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $repo checkout -q -b trabalho 2>$null
        $ErrorActionPreference = $anterior
        # O remoto PRECISA estar na mesma ponta: sem isto o portao de
        # divergencia recusa, e com razao - o GitHub nao teria o que mostrar.
        # Satisfazer os outros portoes e o que faz este caso medir SO o seu.
        Set-RemotoNoBranch -Repo $repo -Branch 'trabalho'
        $null = Write-EvidenciaDePr -Repo $repo -Sha (Get-HeadDoRepo $repo)

        $r = Invoke-ScriptFilho -Script $ScriptPr -Argumentos @('-Path', $repo, '-Abrir') `
                 -PathDoProcesso ($gh + ';' + (Get-PathSemGh))
        Assert-True ($r.Exit -eq 1) "esperava 1, saiu $($r.Exit): $($r.Saida)"
        Assert-True (-not (Test-LogChamouCreate $log)) "chamou 'pr create' sem titulo"
    } finally { Remove-RepoFluxo $repo; Clear-GhFalso -Pasta $gh -Log $log }
}

# =============================================================================
# ESTRUTURAL - credencial
# =============================================================================

Test-Caso "Test-TituloDePr: recusa aspa dupla e vazio, e aceita titulo normal" {
    # A regra que o teste FUNCIONAL nao consegue medir, e isso foi MEDIDO:
    # pelo 'powershell -File', um titulo com aspa dupla e desmontado na
    # travessia de processo e o filho falha a ligacao de parametros, saindo 1
    # ANTES de a guarda rodar. O caso funcional que eu tinha escrito passava
    # por causa disso, e sobrevivia a mutacao que apagava a guarda inteira -
    # foi a decima vez, nesta subfase, que um caso meu mediu outra coisa que
    # nao o que anunciava.
    #
    # Aqui a funcao e chamada direto, que e como o uso REAL a alcanca: numa
    # sessao do PowerShell o parser entrega a string inteira ao script.
    Assert-True ((Test-TituloDePr -Titulo 'feat(2.8): CI no GitHub Actions') -eq '') "recusou um titulo valido"
    Assert-True ((Test-TituloDePr -Titulo "usa 'aspas simples' no texto") -eq '') "recusou aspas simples, que sao seguras"

    Assert-True ((Test-TituloDePr -Titulo '') -ne '') "aceitou titulo vazio"
    # A MENSAGEM, e nao so o veredito: as duas recusas tem motivos diferentes,
    # e um predicado que recusasse TUDO passaria medindo apenas a diferenca
    # de vazio.
    Assert-True ((Test-TituloDePr -Titulo 'fix "a --draft"') -match 'aspa dupla') "nao explicou a aspa dupla"
    Assert-True ((Test-TituloDePr -Titulo 'corrige o "modo seguro"') -match 'FLAG') "nao disse qual e a consequencia"

    # BARRA INVERTIDA NO FIM, a outra metade da mesma regra de citacao. Os
    # dois revisores previram e nenhum podia medir; a medicao mostrou que e
    # PIOR do que eles supunham - nao falha fechado, o titulo engole os
    # argumentos seguintes:
    #   -Titulo 'corrige path C:\temp\'  ->  COUNT=2
    #   [1]=corrige path C:\temp" --body corpo --base main
    Assert-True ((Test-TituloDePr -Titulo 'corrige path C:\temp\') -match 'barra invertida') `
        "nao barrou barra invertida no fim"
    # E o par: barra NO MEIO e inofensiva, medida na mesma sonda. Barrar ela
    # recusaria titulo legitimo.
    Assert-True ((Test-TituloDePr -Titulo 'barra\no meio do texto') -eq '') `
        "recusou barra no meio, que a medicao mostrou ser inofensiva"
}

Test-Caso "fluxo: nenhum script da 2.7 le, escreve ou passa token" {
    # Requisito nomeado da 2.7: nenhuma credencial em artefato. O 'gh'
    # autentica por navegador (ADR-0003, item 5) e este codigo so o invoca.
    #
    # O guarda e por CONTEUDO e nao por nome de arquivo: nome envelhece a cada
    # refatoracao, e foi assim que a isencao de um guarda da 2.3 passou a
    # apontar para o arquivo errado sem ninguem notar.
    # '--show-token' e 'auth status -t' entraram por recomendacao do
    # security-reviewer: sao as flags que fazem o 'gh auth status' imprimir
    # o token SEM mascara. Nenhum uso desses existe hoje - e falta de
    # guarda-corpo, nao vazamento, e por isso o guarda vem antes do uso.
    $proibidos = @('GH_TOKEN', 'GITHUB_TOKEN', '--with-token', 'auth token',
                   'Get-Credential', '--show-token', 'auth status -t')
    foreach ($f in @($ScriptPr, $ScriptBranch,
                     (Join-Path $LibDir 'pr-comum.ps1'),
                     (Join-Path $LibDir 'branch-comum.ps1'))) {
        $txt = Get-Texto $f
        foreach ($p in $proibidos) {
            Assert-True ($txt -notmatch [regex]::Escape($p)) `
                ((Split-Path $f -Leaf) + ": contem '" + $p + "'")
        }
    }
}

Test-Caso "fluxo: o guarda de token ACUSA um arquivo plantado" {
    # O par positivo do caso acima, e ele existe por politica 4.1: um guarda
    # que nunca acusou nada nao foi testado, foi so executado. Sem este caso,
    # trocar a lista '$proibidos' por uma lista vazia deixaria a suite verde.
    $d = Join-Path $env:TEMP ("tok-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $f = Join-Path $d 'plantado.txt'
        [System.IO.File]::WriteAllText($f, "`$env:GH_TOKEN = 'abc'`n", (New-Object System.Text.UTF8Encoding($false)))
        $txt = Get-Texto $f
        $achou = $false
        foreach ($p in @('GH_TOKEN', 'GITHUB_TOKEN', '--with-token', 'auth token',
                         'Get-Credential', '--show-token', 'auth status -t')) {
            if ($txt -match [regex]::Escape($p)) { $achou = $true }
        }
        Assert-True $achou "o guarda nao viu um 'GH_TOKEN' plantado na cara dele"
    } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}
