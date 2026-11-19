<#
.SYNOPSIS
    Diagnostico do estado global do projeto. NAO roda testes, NAO varre segredo.

.DESCRIPTION
    Responde a uma pergunta que nem 'tests' nem '/os:security' respondem:
    **este projeto e continuavel sem a conversa?**

      tests            o comportamento deterministico funciona?
      /os:security     existe risco de exposicao?
      /os:doctor       o projeto como sistema e coerente e retomavel?

    A regra de separacao e o criterio de aceite mais importante desta
    ferramenta: o doctor **nunca roda a suite** e **nunca varre conteudo
    procurando segredo**. Se uma verificacao precisa disso, ela pertence as
    outras duas; aqui so se relata o que elas declararam, com o HEAD de
    quando declararam. Duplicar significa dois detectores divergindo em
    silencio - esta plataforma ja pagou por isso mais de uma vez.

    E o doctor e ESTRITAMENTE diagnostico. Ele recomenda por texto; nao
    executa a recomendacao, nao corrige arquivo, nao toca em Git. Ferramenta
    que conserta sozinha esconde o problema que deveria mostrar.

.PARAMETER Path
    Onde olhar. Aceita a raiz OU um subdiretorio: a primeira camada resolve a
    raiz real antes de qualquer outra coisa.

.PARAMETER Out
    Relatorio humano. Padrao: artifacts/doctor/doctor-report.md na raiz.

.PARAMETER OutJson
    Saida estruturada. Padrao: artifacts/doctor/doctor.json na raiz.

.PARAMETER RaizDaPlataforma
    Repositorio da PLATAFORMA (padrao: a pasta acima deste script). Quando a
    raiz diagnosticada e ela, a dimensao 'git' ganha a verificacao de
    assinatura (gpg.format, user.signingkey, commit.gpgsign, HEAD assinado):
    falta vira WARN, nunca FAIL. Parametro existe para a suite poder apontar
    uma fixture como "a plataforma".

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$Out,
    [string]$OutJson,
    [string]$RaizDaPlataforma
)
# No 5.1 o $PSScriptRoot ainda e vazio no default do param() sob -File: resolve aqui.
if (-not $RaizDaPlataforma) { $RaizDaPlataforma = Split-Path $PSScriptRoot -Parent }

$ErrorActionPreference = 'Stop'

# Excecao inesperada = A FERRAMENTA NAO RODOU, e isso e o terceiro estado do
# ADR-0009, nao uma variacao de "achou problema". Sair com 1 aqui faria um
# defeito do proprio doctor parecer defeito do projeto.
trap {
    Write-Host ""
    Write-Host "O /os:doctor NAO conseguiu rodar: $_" -ForegroundColor Red
    Write-Host "Isto NAO e um diagnostico do projeto. Nenhuma afirmacao sobre ele e valida." -ForegroundColor Yellow
    Write-Host ""
    exit 2
}

$LibDir = Join-Path $PSScriptRoot 'lib'
foreach ($m in @('scan-comum.ps1', 'doctor-comum.ps1', 'doctor-manifesto.ps1',
                 'doctor-retomabilidade.ps1', 'doctor-git.ps1', 'doctor-ambiente.ps1', 'doctor-frescor.ps1',
                 'hooks-comum.ps1', 'doctor-hooks.ps1')) {
    $p = Join-Path $LibDir $m
    if (-not (Test-Path $p -PathType Leaf)) {
        throw "detector ausente: '$p'. O doctor nao roda com menos dimensoes do que declara - varrer menos em silencio e o que a politica 4.5 proibe."
    }
    . $p
}

$SCHEMA_VERSION = 1

# =============================================================================
# CAMADA 0 - a raiz, antes de qualquer predicado
# =============================================================================
$r = Get-RaizDoRepositorio -Path $Path

if (-not $r.Resolvida) {
    # Sem raiz nao ha o que diagnosticar, e as tres razoes levam a vereditos
    # DIFERENTES - confundi-las seria o falso verde que a camada 0 existe para
    # impedir.
    $statusRaiz = 'INCONCLUSIVO'
    if ($r.Forma -eq 'fora-de-repo') { $statusRaiz = 'FAIL' }

    $dimRaiz = New-DimensaoDoDoctor -Nome 'raiz' -Status $statusRaiz -Motivo $r.Motivo `
        -Cobertura @{ Forma = $r.Forma; Resolvida = $false } `
        -NaoVerificado @(New-NaoVerificadoDoDoctor -O_que 'todas as demais dimensoes' -Porque 'sem raiz resolvida nao ha sobre o que diagnosticar')

    # O destino cai no '-Path' PERGUNTADO, nunca no diretorio corrente.
    #
    # A versao anterior usava '(Get-Location).Path' quando a raiz nao
    # resolvia, e o efeito foi medido pelo qa-reviewer: rodar o doctor sobre
    # uma pasta temporaria fora de repositorio gravava o diagnostico dela em
    # 'artifacts/doctor/' da PLATAFORMA. O caminho canonico do contrato de
    # maquina - o mesmo 'doctor.json' que a Fase 3/4 vai consumir - passava a
    # descrever uma pasta que nem existe mais. Evidencia falsa no lugar certo,
    # que e pior do que evidencia ausente.
    $baseSaida = $Path
    if (Test-Path $Path -PathType Leaf) { $baseSaida = Split-Path $Path -Parent }
    if (-not $baseSaida) { $baseSaida = (Get-Location).Path }
    $destinoOut = $Out
    if (-not $destinoOut) { $destinoOut = Join-Path $baseSaida 'artifacts\doctor\doctor-report.md' }
    $destinoJson = $OutJson
    if (-not $destinoJson) { $destinoJson = Join-Path $baseSaida 'artifacts\doctor\doctor.json' }

    Write-RelatorioDoDoctor -Dimensoes @($dimRaiz) -Raiz $Path -Head '' -Forma $r.Forma `
        -Out $destinoOut -OutJson $destinoJson -SchemaVersion $SCHEMA_VERSION
    exit (Get-CodigoDeSaidaDoDoctor -Status $statusRaiz)
}

$raiz = $r.Raiz
if (-not $Out)     { $Out     = Join-Path $raiz 'artifacts\doctor\doctor-report.md' }
if (-not $OutJson) { $OutJson = Join-Path $raiz 'artifacts\doctor\doctor.json' }

$dimensoes = @()
$dimensoes += New-DimensaoDoDoctor -Nome 'raiz' -Status 'PASS' `
    -Motivo "raiz resolvida em '$raiz' (forma: $($r.Forma))" `
    -Cobertura @{ Forma = $r.Forma; Resolvida = $true } `
    -Verificacoes @(New-VerificacaoDoDoctor -O_que 'raiz do repositorio' -Resultado $raiz)

# HEAD atual, para o frescor. Falhar aqui NAO derruba o doctor: a dimensao de
# frescor declara a lacuna e sai INCONCLUSIVO, que e o comportamento certo.
$headAtual = ''
$sha = @(Invoke-Git @('-C', $raiz, 'rev-parse', 'HEAD^{commit}') -PermitirFalha)
if ($LASTEXITCODE -eq 0 -and @($sha).Count -gt 0) { $headAtual = @($sha)[0] }

$rm = Get-DiagnosticoManifesto -Raiz $raiz
$dimensoes += $rm.Dimensao
$dimensoes += Get-DiagnosticoRetomabilidade -Raiz $raiz
$dimGit = Get-DiagnosticoGit -Raiz $raiz -Forma $r.Forma

# Assinatura do PROPRIO repositorio da plataforma (spec de ownership, 2026-10-12).
# Le a config EFETIVA do repositorio (system < global < local) e o %G? do HEAD;
# so le, nunca configura. Falta de assinatura e WARN dentro da dimensao 'git':
# a lista canonica de dimensoes nao muda, e um PASS so cai para WARN.
function Get-TopoDoGit {
    param([string]$Caminho)
    if (-not $Caminho -or -not (Test-Path -LiteralPath $Caminho -PathType Container)) { return '' }
    $t = @(Invoke-Git @('-C', $Caminho, 'rev-parse', '--show-toplevel') -PermitirFalha)
    if ($LASTEXITCODE -ne 0 -or @($t).Count -eq 0) { return '' }
    return ("" + @($t)[0]).Trim()
}
function Get-ConfigEfetiva {
    param([string]$Repo, [string[]]$Chave)
    $v = @(Invoke-Git (@('-C', $Repo, 'config') + $Chave) -PermitirFalha)
    if ($LASTEXITCODE -ne 0 -or @($v).Count -eq 0) { return '' }
    return ("" + @($v)[0]).Trim()
}

$topoRaiz = Get-TopoDoGit $raiz
$topoPlataforma = Get-TopoDoGit $RaizDaPlataforma
if ($topoRaiz -and $topoPlataforma -and ($topoRaiz -eq $topoPlataforma) -and $dimGit.Status -ne 'INCONCLUSIVO') {
    $verifAss = @()
    $achAss = @()
    $fmt = Get-ConfigEfetiva $raiz @('--get', 'gpg.format')
    if (-not $fmt) { $fmt = 'openpgp' }
    $chave = Get-ConfigEfetiva $raiz @('--get', 'user.signingkey')
    $gpgsign = Get-ConfigEfetiva $raiz @('--type=bool', '--get', 'commit.gpgsign')
    $chaveOk = $false
    if ($chave) {
        if ($fmt -ne 'ssh' -or $chave.StartsWith('key::') -or $chave.StartsWith('ssh-')) {
            $chaveOk = $true
        } else {
            $arq = $chave
            if ($arq.StartsWith('~')) { $arq = Join-Path $HOME $arq.Substring(1).TrimStart([char]'/', [char]'\') }
            $chaveOk = Test-Path -LiteralPath $arq -PathType Leaf
        }
    }
    $headSig = ''
    if ($dimGit.Cobertura.HeadResolve) {
        $h = @(Invoke-Git @('-C', $raiz, 'log', '-1', '--format=%G?', 'HEAD') -PermitirFalha)
        if ($LASTEXITCODE -eq 0 -and @($h).Count -gt 0) { $headSig = ("" + @($h)[0]).Trim() }
    }
    $verifAss += New-VerificacaoDoDoctor -O_que 'assinatura: gpg.format' -Resultado $fmt
    $verifAss += New-VerificacaoDoDoctor -O_que 'assinatura: user.signingkey existe' -Resultado ([string]$chaveOk)
    $verifAss += New-VerificacaoDoDoctor -O_que 'assinatura: commit.gpgsign' -Resultado ([string]($gpgsign -eq 'true'))
    $verifAss += New-VerificacaoDoDoctor -O_que 'assinatura: HEAD (%G?)' -Resultado $headSig
    $faltas = @()
    if (-not $chave) { $faltas += 'user.signingkey nao configurado' }
    elseif (-not $chaveOk) { $faltas += "user.signingkey aponta para arquivo inexistente ($chave)" }
    if ($gpgsign -ne 'true') { $faltas += 'commit.gpgsign nao e true' }
    # So G e assinado E verificado (coerente com eos/ownership.py): U e assinatura boa de uma chave que o
    # allowedSignersFile nao conhece - sem prova de QUEM assinou, entao WARN, nunca PASS.
    $msgU = 'HEAD assinado, mas a chave nao esta em allowedSignersFile (%G?=U)'
    if ($dimGit.Cobertura.HeadResolve -and $headSig -ceq 'U') {
        $faltas += $msgU
    } elseif ($dimGit.Cobertura.HeadResolve -and $headSig -cne 'G') {
        $faltas += "HEAD sem assinatura valida (%G?=$headSig)"
    }
    foreach ($f in $faltas) {
        $acaoAss = 'configure gpg.format=ssh, user.signingkey e commit.gpgsign=true; o proximo commit sai assinado'
        if ($f -ceq $msgU) { $acaoAss = 'inclua a chave publica de assinatura no arquivo de gpg.ssh.allowedSignersFile' }
        $achAss += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'git' -Mensagem ("assinatura da plataforma: " + $f) `
            -Acao $acaoAss
    }
    $statusGit = $dimGit.Status
    $motivoGit = $dimGit.Motivo
    if ($faltas.Count -gt 0 -and $statusGit -eq 'PASS') {
        $statusGit = 'WARN'
        $motivoGit = $motivoGit + '; assinatura da plataforma incompleta'
    }
    $dimGit = New-DimensaoDoDoctor -Nome 'git' -Status $statusGit -Motivo $motivoGit -Cobertura $dimGit.Cobertura `
        -Verificacoes (@($dimGit.Verificacoes) + $verifAss) -Achados (@($dimGit.Achados) + $achAss) `
        -NaoVerificado @($dimGit.NaoVerificado)
}
$dimensoes += $dimGit

if ($null -ne $rm.Raiz) {
    $dimensoes += Get-DiagnosticoAmbiente -Manifesto $rm.Raiz
} else {
    $dimensoes += New-DimensaoDoDoctor -Nome 'ambiente' -Status 'INCONCLUSIVO' `
        -Motivo 'sem manifesto legivel nao da para saber quais dependencias o projeto declara' `
        -Cobertura @{ Declaradas = 0; Encontradas = 0; Ausentes = 0; ObrigatoriasAusentes = 0; NaoSondadas = 0; CampoDeclarado = $false } `
        -NaoVerificado @(New-NaoVerificadoDoDoctor -O_que 'dependencias declaradas' -Porque 'o project.yaml nao foi lido')
}

$dimensoes += Get-DiagnosticoFrescor -Raiz $raiz -HeadAtual $headAtual
$dimensoes += Get-DiagnosticoHooks -Raiz $raiz

# As dimensoes emitidas TEM de ser a lista canonica, na ordem dela. Sem esta
# guarda, uma dimensao que deixasse de ser chamada - por um 'if' novo, por um
# merge, por um erro de nome - produziria um relatorio menor e igualmente
# verde: o doctor afirmando saude sobre o que ele parou de olhar.
$nomesEmitidos = (@($dimensoes | ForEach-Object { $_.Nome }) -join ',')
$nomesCanonicos = (@(Get-DimensoesDoDoctor) -join ',')
if ($nomesEmitidos -ne $nomesCanonicos) {
    throw ("o doctor emitiu as dimensoes '$nomesEmitidos' e a lista canonica e '$nomesCanonicos'. " +
           "Diagnostico com dimensao a menos sairia igualmente verde, e isso e varrer menos em silencio.")
}

Write-RelatorioDoDoctor -Dimensoes $dimensoes -Raiz $raiz -Head $headAtual -Forma $r.Forma `
    -Out $Out -OutJson $OutJson -SchemaVersion $SCHEMA_VERSION

$global = Get-PiorStatus -Status @($dimensoes | ForEach-Object { $_.Status })
exit (Get-CodigoDeSaidaDoDoctor -Status $global)
