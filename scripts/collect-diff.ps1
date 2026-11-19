<#
.SYNOPSIS
    Reune os fatos que o qa-reviewer precisa. Produz FATOS, nao veredito.

.DESCRIPTION
    Parte do desenho da subfase 2.2 (ADR-0008): os revisores sao estritamente
    read-only (Read, Grep, Glob), sem Bash. Diff nao e arquivo - e consulta ao
    Git - entao alguem tem que materializa-lo. E este script.

    Ele tambem RODA os testes, se o projeto tiver, e grava a saida real. O
    revisor le o resultado em vez de acreditar num resumo, e nao precisa de
    Bash para isso.

    O relatorio declara explicitamente o que foi coletado e o que NAO foi.
    Lacuna de coleta nao e aprovacao: o revisor e instruido a tratar escopo
    nao coberto como INCONCLUSIVO.

    Codigo de saida: 0 coleta completa, 1 coleta parcial (algo faltou),
    2 erro de execucao.

.PARAMETER Path
    Raiz do repositorio. Default: diretorio atual.

.PARAMETER Out
    Arquivo de relatorio. Default: <Path>/artifacts/review/diff-report.md

.PARAMETER TestCommand
    Comando de teste a executar. Se omitido, tenta descobrir.

.PARAMETER SkipTests
    Nao rodar testes. A ausencia fica declarada no relatorio.

.EXAMPLE
    .\scripts\collect-diff.ps1
    .\scripts\collect-diff.ps1 -Path <raiz-de-outro-repositorio>

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [string]$Out,
    [string]$TestCommand,
    [switch]$SkipTests,
    # Limite de linhas de arquivo novo incluido inteiro. Era 400 fixo, e a
    # consequencia foi concreta: na subfase 2.3 o arquivo novo que ERA a
    # evidencia da subfase (a suite de testes, 599 linhas) ficou de fora, e o
    # revisor de QA declarou a area de cobertura bloqueada por causa disso.
    # Parametro para poder subir quando o arquivo novo e o que se quer revisar.
    [int]$MaxLinhasArquivoNovo = 800,
    # Limite de linhas do diff. Era 2000 fixo, e ficou parametro pelo mesmo
    # motivo do limite de arquivo novo: os dois decidem se o codigo chega ao
    # revisor, e mudanca grande e legitima. Quando o limite morde, a lacuna e
    # declarada - mas declarar lacuna nao substitui poder ver o diff.
    [int]$MaxLinhasDiff = 2000,
    # Referencia de comparacao. Default 'HEAD' = trabalho ainda nao commitado.
    #
    # Existe porque com a arvore LIMPA o coletor produzia diff VAZIO, e o
    # revisor de QA nao teria a mudanca sob revisao. Isso aparece sempre que a
    # revisao acontece DEPOIS do commit - que passou a ser o caso normal de
    # fechamento de subfase, e foi exatamente o que travou a revisao pendente
    # da 2.3. Com '-Contra <ref>' o coletor descreve tudo desde aquele ponto,
    # commitado ou nao.
    [string]$Contra = 'HEAD'
)

$ErrorActionPreference = 'Stop'

# Erro inesperado sai com 2, nao com 1. Sem isto um abort seria indistinguivel
# de "coletou com lacunas", e quem chama (skill ou hook) decidiria errado.
trap { Write-Host "ERRO inesperado: $_" -ForegroundColor Red; exit 2 }
$MAX_DIFF_LINHAS = $MaxLinhasDiff

if (-not (Test-Path (Join-Path $Path '.git'))) {
    Write-Host "ERRO: $Path nao e um repositorio Git." -ForegroundColor Red
    exit 2
}

# Uma definicao so de "arquivo de texto", compartilhada com o scanner.
$libComum = Join-Path $PSScriptRoot 'lib\scan-comum.ps1'
if (-not (Test-Path $libComum)) {
    Write-Host "ERRO: falta $libComum" -ForegroundColor Red
    exit 2
}
. $libComum

if (-not $Out) { $Out = Join-Path $Path 'artifacts\review\diff-report.md' }
$dirOut = Split-Path -Parent $Out
if (-not (Test-Path $dirOut)) { New-Item -ItemType Directory -Path $dirOut -Force | Out-Null }

# O relatorio contem o diff completo e a saida dos testes. Se o destino nao
# estiver ignorado no repo-alvo, um 'git add .' o versiona - e a proxima
# execucao ainda o listaria como arquivo novo, inflando o relatorio com a
# propria saida. Repos anteriores ao template do OS nao ignoram artifacts/.
# A pergunta so faz sentido se o destino estiver DENTRO do repositorio-alvo, e
# a comparacao precisa do separador.
#
# Esta linha era identica a de security-scan.ps1, e a correcao la foi feita e
# aqui NAO - o qa-reviewer achou o gemeo esquecido. Dois defeitos, os dois
# medidos:
#   1. Prefixo sem separador: '-Path C:\proj -Out C:\projeto-relatorios\r.md'
#      passava por "dentro do repo", o caminho relativo virava
#      'eto-relatorios\r.md', e o coletor declarava uma LACUNA QUE NAO EXISTE,
#      saindo com 1. Quem chama - a skill /os:checkpoint - le exit 1 como
#      coleta incompleta.
#   2. Destino inteiramente fora: 'git check-ignore' recusa com "is outside
#      repository", e sob ErrorActionPreference=Stop isso derruba o script pelo
#      trap, com exit 2 e SEM relatorio.
# Coletor que morre ou inventa lacuna produz INCONCLUSIVO com a arvore parada -
# o mesmo modo de falha que o carimbo de integridade eliminou.
$destinoIgnorado = $true
$relDestino = $Out
$destinoDentroDoRepo = $false
$raizComSep = $Path.TrimEnd([char]'\', [char]'/') + [System.IO.Path]::DirectorySeparatorChar
if ($Out.StartsWith($raizComSep, [System.StringComparison]::OrdinalIgnoreCase)) {
    $destinoDentroDoRepo = $true
    $relDestino = $Out.Substring($raizComSep.Length).TrimStart([char]'\', [char]'/')
}
if ($destinoDentroDoRepo) {
    Invoke-Git @('-C', $Path, 'check-ignore', '-q', $relDestino) -PermitirFalha | Out-Null
    if ($LASTEXITCODE -ne 0) { $destinoIgnorado = $false }
}

$lacunas = @()
if ($destinoDentroDoRepo -and -not $destinoIgnorado) {
    $lacunas += "O destino do relatorio NAO esta ignorado pelo .gitignore deste repositorio. Este arquivo contem o diff completo e a saida dos testes: se for versionado por engano, o vazamento e do processo de revisao, nao do projeto."
}

# --- git ------------------------------------------------------------------------
# Saida que o relatorio TRANSCREVE (status, stat, diff) vem em UTF-8 a partir dos
# bytes e sem citacao octal de caminho: com Invoke-Git ('& git'), nome acentuado
# saia como "CAPA DOSSI\303\212.md" ou em mojibake da codepage do console
# (residuo do item 156 do backlog).
function Get-LinhasGitUtf8 {
    param([string[]]$Argumentos)
    $s = Invoke-GitUtf8 (@('-c', 'core.quotepath=false') + $Argumentos)
    if ($s.EndsWith("`n")) { $s = $s.Substring(0, $s.Length - 1) }
    if ($s.EndsWith("`r")) { $s = $s.Substring(0, $s.Length - 1) }
    if ($s -eq '') { return @() }
    return @($s -split "`r?`n")
}
$branch  = (Invoke-Git @('-C', $Path, 'branch', '--show-current'))
$status  = @(Get-LinhasGitUtf8 @('-C', $Path, 'status', '--porcelain'))

# Repositorio recem-init'ado, sem nenhum commit, NAO tem HEAD: 'git diff HEAD'
# falha com "fatal: ambiguous argument 'HEAD'". E o fluxo normal da plataforma -
# /os:new-project roda git init e para, entao o primeiro /os:checkpoint acontece
# antes do primeiro commit. Sem esta guarda o script abortava sob
# ErrorActionPreference=Stop, e o exit 1 do abort era indistinguivel do exit 1
# que significa "coletou com lacunas".
# Test-HeadResolvivel, de scripts/lib/scan-comum.ps1, que este arquivo ja
# carrega na secao de dependencias. Havia aqui uma QUARTA copia do
# predicado, inline, com o codigo PRE-correcao - achado do qa-reviewer, e o
# pior lugar possivel para ela: este e o coletor que produz a evidencia das
# revisoes.
#
# Os dois defeitos que a copia tinha:
#   - 'rev-parse --verify --quiet HEAD' sem '^{commit}': com o sha nulo em
#     .git/HEAD ela devolvia verdadeiro e o carimbo nomeava '0000000' como
#     se fosse o HEAD, para um objeto que nao existe;
#   - QUALQUER codigo != 0 virava falso, entao HEAD ilegivel, ref corrompida
#     ou permissao negada faziam o relatorio escrever a afirmacao POSITIVA
#     "o repositorio nao tem nenhum commit... todo o conteudo e novo".
#
# O predicado LANCA quando nao consegue determinar, e o trap deste script
# converte isso em exit 2 sem relatorio - que e a resposta certa: "nao
# coletei", nunca "coletei e esta vazio".
$temHead = Test-HeadResolvivel -Path $Path

# A referencia de comparacao tem de existir. Ref inventada faria o 'git diff'
# falhar e, sob ErrorActionPreference=Stop, derrubar o script pelo trap - exit 2
# sem relatorio, indistinguivel de erro de coleta.
if ($temHead -and $Contra -ne 'HEAD') {
    Invoke-Git @('-C', $Path, 'rev-parse', '--verify', '--quiet', $Contra) -PermitirFalha | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: a referencia '-Contra $Contra' nao existe neste repositorio." -ForegroundColor Red
        exit 2
    }
}

if ($temHead) {
    $commit = (Invoke-Git @('-C', $Path, 'rev-parse', '--short', 'HEAD'))
    $stat   = @(Get-LinhasGitUtf8 @('-C', $Path, 'diff', '--stat', $Contra))
    $nomes  = @(Invoke-GitCaminhos @('-C', $Path, 'diff', '--name-only', '-z', $Contra))
    $diff   = @(Get-LinhasGitUtf8 @('-C', $Path, 'diff', $Contra))
} else {
    $commit = '(sem commits)'
    $stat   = @()
    $nomes  = @()
    $diff   = @()
    $lacunas += "O repositorio nao tem nenhum commit, entao nao existe HEAD para comparar: NAO HA DIFF. Todo o conteudo e novo, e esta na secao de arquivos novos - se estiver rastreado, nem ali aparece. Revise o repositorio inteiro, nao um diff."
}

$diffTruncado = $false
if ($diff.Count -gt $MAX_DIFF_LINHAS) {
    $diffTruncado = $true
    $lacunas += "O diff tem $($diff.Count) linhas e foi truncado em $MAX_DIFF_LINHAS. O revisor NAO viu o diff inteiro."
    $diff = $diff[0..($MAX_DIFF_LINHAS - 1)]
}

# --- arquivos novos, que o diff NAO mostra --------------------------------------
# git diff HEAD ignora arquivo nao rastreado. Sem isto o relatorio diria
# "sem alteracoes" com arquivos novos no disco, e o revisor aprovaria o nada.
# Descoberto ao rodar este proprio coletor na subfase 2.2.
# Sem HEAD, "novo" e TODO arquivo - rastreado ou nao. Um repo com arquivos
# staged e zero commits nao apareceria em diff nem em ls-files --others, e o
# revisor veria um relatorio vazio sobre um projeto inteiro.
if ($temHead) {
    $naoRastreados = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '--others', '--exclude-standard', '-z'))
} else {
    $naoRastreados = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z')) + @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '--others', '--exclude-standard', '-z'))
    $naoRastreados = @(Get-CaminhosUnicos $naoRastreados)
}
$MAX_NOVO_LINHAS = $MaxLinhasArquivoNovo
$novos = @()
foreach ($f in $naoRastreados) {
    $abs = Join-Path $Path $f
    $ext = [System.IO.Path]::GetExtension($f).ToLower()
    # Lista unica, vinda de scripts/lib/scan-comum.ps1. Este coletor mantinha
    # uma SEGUNDA lista de extensoes de texto, com 13 entradas contra as 24 de
    # Get-ExtensoesTexto - a mesma duplicacao que a subfase 2.3 centralizou do
    # outro lado. Apontada pelo qa-reviewer.
    # -Raiz: sem ela um caminho relativo seria resolvido contra o diretorio
    # corrente. O coletor ja roda com -Path absoluto, e e essa a raiz.
    $textoOk = Test-ArquivoDeTexto $f -Raiz $Path
    $conteudo = $null
    $bruto = $null
    if ($textoOk -and (Test-Path -LiteralPath $abs)) { $bruto = Read-TextoDeArquivo $abs }
    if ($textoOk -and (Test-Path -LiteralPath $abs) -and $null -eq $bruto) {
        # Mesma regra do scanner: nao transcrever texto lido com U+FFFD no
        # lugar do byte, nem texto salpicado de NUL. O revisor tem de saber
        # que nao viu o arquivo, e nao receber uma versao corrompida dele.
        $lacunas += "Arquivo novo ``$f`` nao e legivel como texto (UTF-8 invalido, ou NUL no conteudo); conteudo nao incluido."
    } elseif ($textoOk -and (Test-Path -LiteralPath $abs)) {
        $l = @(($bruto -replace "`r`n", "`n") -split "`n")
        # O caso de UM elemento tem de ser tratado a parte: com Count = 1 a
        # poda vira '$l[0..-1]', e em PowerShell '0..-1' e a sequencia @(0,-1)
        # - devolve DOIS elementos em vez de nenhum. Arquivo novo VAZIO (um
        # '.gitkeep', tipicamente) saia com uma linha em branco transcrita
        # contra '0 linhas' no carimbo: a divergencia que faz o revisor
        # concluir "coleta obsoleta" com a arvore parada, que e o falso
        # positivo que Measure-Linhas existe para eliminar. Achado do
        # qa-reviewer.
        if ($l.Count -gt 0 -and $l[$l.Count - 1] -eq '') {
            if ($l.Count -eq 1) { $l = @() } else { $l = @($l[0..($l.Count - 2)]) }
        }
        if ($l.Count -le $MAX_NOVO_LINHAS) {
            $conteudo = ($l -join "`n")
        } else {
            $lacunas += "Arquivo novo ``$f`` tem $($l.Count) linhas e nao foi incluido inteiro (limite $MAX_NOVO_LINHAS). O revisor nao viu o conteudo completo."
        }
    } elseif (-not $textoOk) {
        $lacunas += "Arquivo novo ``$f`` nao e texto reconhecido; conteudo nao incluido."
    }
    $novos += [pscustomobject]@{ Caminho = $f; Conteudo = $conteudo }
}

# --- carimbo de integridade -----------------------------------------------------
# Bytes e linhas de cada arquivo descrito, no momento da coleta.
#
# Existe porque na subfase 2.3 o working tree mudou DEPOIS da coleta, e o
# relatorio seguiu descrevendo uma versao que nao existia mais. O qa-reviewer
# detectou por acaso, comparando a contagem de linhas de um arquivo que ele
# leu no disco - e disse, com razao, que coleta obsoleta deveria se anunciar
# em vez de depender de alguem tropecar nela.
#
# Linha e a unidade certa aqui: o revisor e read-only, nao tem Bash e nao
# consegue ler data de modificacao nem calcular hash, mas consegue ler o
# arquivo e contar linhas. Um carimbo que ele nao pode conferir nao serve.
$carimbo = @()
foreach ($f in @(Get-CaminhosUnicos (@($nomes) + @($novos | ForEach-Object { $_.Caminho })))) {
    if (-not $f) { continue }
    $abs = Join-Path $Path $f
    if (-not (Test-Path -LiteralPath $abs)) {
        $carimbo += [pscustomobject]@{ Nome = $f; Bytes = '(apagado)'; Linhas = '-' }
        continue
    }
    $bytes = (Get-Item $abs).Length
    # Mesma funcao que o security-scan.ps1 usa. As duas contagens divergiam em
    # +1 para arquivo terminado em newline, e o carimbo acusava coleta
    # obsoleta em TODA linha, com a arvore parada.
    #
    # Arquivo ilegivel como texto entra com marcador, e nao com numero: o
    # carimbo existe para o revisor conferir, e numero derivado de leitura
    # corrompida e pior que marcador nenhum. Os bytes continuam valendo.
    $txtC = Read-TextoDeArquivo $abs
    $linhas = if ($null -eq $txtC) { '(ilegivel como texto)' } else { Measure-Linhas $txtC }
    $carimbo += [pscustomobject]@{ Nome = $f; Bytes = $bytes; Linhas = $linhas }
}

# --- classificacao do projeto ---------------------------------------------------
$projYaml = Join-Path $Path 'project.yaml'
$criticidade = '(nao declarada)'
$revisao     = '(nao declarada)'
$sensiveis   = '(nao declarado)'
if (Test-Path $projYaml) {
    $y = Read-TextoDeArquivo $projYaml
    if ($null -eq $y) {
        $lacunas += "O ``project.yaml`` nao e legivel como texto: criticidade, revisao independente e dados sensiveis NAO foram lidos, e o rigor exigido desta revisao nao pode ser afirmado."
        $y = ''
    }
    $m = [regex]::Match($y, '(?m)^\s*criticidade:\s*"?([a-z]+)"?')
    if ($m.Success) { $criticidade = $m.Groups[1].Value }
    $m = [regex]::Match($y, '(?m)^\s*revisao_independente:\s*"?([a-z+]+)"?')
    if ($m.Success) { $revisao = $m.Groups[1].Value }
    $m = [regex]::Match($y, '(?m)^\s*dados_sensiveis:\s*([a-z]+)')
    if ($m.Success) { $sensiveis = $m.Groups[1].Value }
} else {
    $lacunas += "Nao existe project.yaml: criticidade e revisao_independente nao puderam ser lidas, entao o rigor exigido pelo ADR-0007 e desconhecido."
}

# --- testes ---------------------------------------------------------------------
$testeSaida = ''
$testeExit  = $null
$testeCmd   = ''

if ($SkipTests) {
    $lacunas += "Testes NAO foram executados (-SkipTests). Nenhuma afirmacao sobre correcao pode se apoiar em teste."
} else {
    if ($TestCommand) {
        $testeCmd = $TestCommand
    } elseif (Test-Path (Join-Path $Path 'tests\run-tests.ps1')) {
        $testeCmd = '.\tests\run-tests.ps1'
    } elseif (Test-Path (Join-Path $Path '.venv\Scripts\python.exe')) {
        if (Test-Path (Join-Path $Path 'tests')) { $testeCmd = '.\.venv\Scripts\python.exe -m pytest tests -q' }
    }

    if (-not $testeCmd) {
        $lacunas += "Nenhum comando de teste encontrado nem informado. O projeto pode nao ter testes, ou o descobridor pode ter falhado - o revisor nao consegue distinguir os dois casos."
    } else {
        Push-Location $Path
        try {
            $testeSaida = (& powershell -NoProfile -ExecutionPolicy Bypass -Command $testeCmd 2>&1 | Out-String)
            $testeExit = $LASTEXITCODE
        } catch {
            $testeSaida = "ERRO ao executar: " + $_.Exception.Message
            $testeExit = -1
            $lacunas += "O comando de teste falhou ao ser executado (nao e o mesmo que teste reprovando)."
        } finally { Pop-Location }
    }
}

# --- relatorio ------------------------------------------------------------------
$sb = New-Object System.Text.StringBuilder
function W { param([string]$t = '') ; $null = $sb.AppendLine($t) }

W "# Relatorio de coleta para revisao de QA"
W ""
W "- Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
W "- Repositorio: ``$Path``"
W "- Branch: ``$branch``  HEAD: ``$commit``"
W "- Gerador: ``scripts/collect-diff.ps1``"
# Parametro de invocacao entra no relatorio. O security-report ecoava os
# modificadores dele e este nao ecoava nenhum: com -MaxLinhasArquivoNovo em
# valor nao-default, o revisor tinha de INFERIR que a cobertura estava
# completa em vez de ler a declaracao. Achado do qa-reviewer.
$modsColeta = @("``-MaxLinhasArquivoNovo $MaxLinhasArquivoNovo``", "``-MaxLinhasDiff $MaxLinhasDiff``")
if ($SkipTests)   { $modsColeta += '``-SkipTests`` **os testes NAO foram executados**' }
if ($TestCommand) { $modsColeta += ('``-TestCommand`` ' + $TestCommand) }
W ("- Modificadores desta coleta: " + ($modsColeta -join ' | '))
W ""
W "> Este relatorio contem FATOS, nao veredito. Quem julga e o ``qa-reviewer``."
W ""
W "## Rigor exigido (ADR-0007)"
W ""
W "| Campo | Valor lido do ``project.yaml`` |"
W "|---|---|"
W "| ``classificacao.criticidade`` | $criticidade |"
W "| ``classificacao.dados_sensiveis`` | $sensiveis |"
W "| ``verificacao.revisao_independente`` | $revisao |"
W ""
W "## Escopo COLETADO"
W ""
W "| O que | Volume |"
W "|---|---|"
W "| ``git status --porcelain`` | $($status.Count) entrada(s) |"
W "| ``git diff --stat $Contra`` | $($stat.Count) linha(s) |"
W "| ``git diff $Contra`` | $($diff.Count) linha(s)$(if ($diffTruncado) { ' **TRUNCADO**' }) |"
W "| Arquivos alterados (rastreados) | $($nomes.Count) |"
W "| Arquivos NOVOS (nao rastreados) | $($novos.Count) |"
$celulaTeste = 'nenhuma'
if ($testeCmd) { $celulaTeste = '`' + $testeCmd + '`' }
W "| Execucao de teste | $celulaTeste |"
W ""
W "## Carimbo de integridade desta coleta"
W ""
W "Tamanho de cada arquivo descrito **no momento da coleta**. Se o que voce ler"
W "no disco tiver outra contagem de linhas, **esta coleta esta obsoleta**: o"
W "veredito nao se aplica ao codigo atual. Nesse caso peca coleta nova, com a"
W "arvore parada, em vez de concluir sobre evidencia velha."
W ""
W ("**" + (Get-NotaDaConvencaoDeLinhas) + "** O ``security-scan.ps1`` usa a mesma convencao: se os dois relatorios discordarem, isso e defeito de ferramenta, nao deriva de arquivo.")
W ""
W "| Arquivo | bytes | linhas |"
W "|---|---|---|"
foreach ($c in ($carimbo | Sort-Object Nome)) {
    W "| ``$($c.Nome)`` | $($c.Bytes) | $($c.Linhas) |"
}
W ""
W "## Escopo NAO COLETADO"
W ""
if ($lacunas.Count -eq 0) {
    W "Nenhuma lacuna de coleta. Ainda assim, note o que este coletor **nunca** reune:"
} else {
    W "**Lacunas nesta coleta. Cada uma delas impede conclusao sobre a area"
    W "correspondente - ausencia de evidencia nao e aprovacao:**"
    W ""
    foreach ($l in $lacunas) { W "- $l" }
    W ""
    W "Alem dessas, este coletor **nunca** reune:"
}
W ""
W "- **Historico do Git.** So o diff contra ``$Contra``. O que veio antes dessa referencia nao entra."
W "- **Comportamento em outra maquina.** Verificacao em clone limpo e passo separado."
W "- **Cobertura de teste.** Saber que os testes passam nao diz o que eles cobrem."
W "- **Varredura de seguranca.** Isso e ``scripts/security-scan.ps1``, relatorio proprio."
W "- **Intencao.** O diff mostra o que mudou, nao o que se queria mudar. Isso esta no ``STATE.md``."
if (-not $destinoDentroDoRepo) {
    W "- **Se o destino deste relatorio esta ignorado.** Ele foi gravado FORA do repositorio-alvo (``-Out``), entao a pergunta nao se aplica."
}
W ""
W "## git status"
W ""
W '```'
if ($status.Count -eq 0) { W "(working tree limpa)" } else { foreach ($l in $status) { W $l } }
W '```'
W ""
W "## git diff --stat $Contra"
W ""
W '```'
if ($stat.Count -eq 0) { W "(sem alteracoes contra $Contra)" } else { foreach ($l in $stat) { W $l } }
W '```'
W ""
W "## Resultado real dos testes"
W ""
if (-not $testeCmd) {
    W "**Nenhum teste executado.** Ver Escopo NAO COLETADO."
} else {
    W "Comando: ``$testeCmd``"
    W ""
    W "Codigo de saida: **$testeExit** $(if ($testeExit -eq 0) { '(passou)' } else { '(NAO passou)' })"
    W ""
    W '```'
    W $testeSaida.TrimEnd()
    W '```'
}
W ""
W "## git diff $Contra"
W ""
if ($diffTruncado) {
    W "**ATENCAO: truncado em $MAX_DIFF_LINHAS linhas.** O revisor nao viu o diff"
    W "inteiro e nao pode concluir sobre o que ficou de fora."
    W ""
}
W '```diff'
if ($diff.Count -eq 0) {
    W "(sem alteracoes em arquivo RASTREADO contra $Contra)"
    if ($novos.Count -gt 0) {
        W "-- atencao: existem $($novos.Count) arquivo(s) NOVO(S), na secao abaixo --"
    }
} else { foreach ($l in $diff) { W $l } }
W '```'
W ""
W "## Arquivos novos (invisiveis ao git diff)"
W ""
if ($novos.Count -eq 0) {
    W "Nenhum arquivo nao rastreado."
} else {
    W "``git diff`` nao mostra arquivo nao rastreado. Estes sao codigo novo, e"
    W "revisa-los importa mais que revisar uma linha alterada."
    W ""
    foreach ($n in $novos) {
        W "### ``$($n.Caminho)``"
        W ""
        if ($null -eq $n.Conteudo) {
            W "*Conteudo nao incluido - ver Escopo NAO COLETADO.*"
        } else {
            # Fence calculado a partir do conteudo. Com ``` fixo, um arquivo que
            # contem ``` fecha o bloco no meio e o resto do relatorio alterna
            # codigo e prosa por acidente - a evidencia chega mutilada. Isto
            # aconteceu de fato ao coletar os proprios agentes e o ADR-0008,
            # que sao markdown com blocos de codigo dentro.
            $maiorInterna = 0
            foreach ($mm in [regex]::Matches($n.Conteudo, '(?m)^\s*(`{3,})')) {
                if ($mm.Groups[1].Value.Length -gt $maiorInterna) { $maiorInterna = $mm.Groups[1].Value.Length }
            }
            $fence = '`' * ([Math]::Max(3, $maiorInterna + 1))
            W $fence
            # Arquivo VAZIO nao escreve linha nenhuma dentro do bloco. Escrever
            # a string vazia produzia uma linha em branco transcrita contra
            # '0 linhas' no carimbo, e divergencia entre bloco e carimbo e o
            # sinal que o revisor foi instruido a ler como coleta obsoleta.
            if ($n.Conteudo.Length -gt 0) { W $n.Conteudo }
            W $fence
        }
        W ""
    }
}

[System.IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Relatorio: $Out" -ForegroundColor Cyan
Write-Host ("  arquivos alterados: {0}   diff: {1} linha(s)   lacunas: {2}" -f $nomes.Count, $diff.Count, $lacunas.Count)
if ($testeCmd) { Write-Host ("  teste: {0} -> exit {1}" -f $testeCmd, $testeExit) }
Write-Host ""
if ($lacunas.Count -gt 0) { exit 1 }
exit 0
