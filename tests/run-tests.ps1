<#
.SYNOPSIS
    Runner raiz dos testes do Emmily AI Project OS.

.DESCRIPTION
    Descobre as suites em tests/suites/ e roda todas, ou apenas as que voce
    pedir. Uma suite quebrada nao derruba as outras: cada caso e isolado, e o
    codigo de saida reflete o total.

    O OS e majoritariamente texto lido por um modelo. O que da para testar de
    forma deterministica e: os manifestos sao validos, a estrutura esta
    completa, o template instancia, o bootstrap detecta o que promete
    detectar, e nada sensivel esta versionado.

    Comportamento probabilistico (o Orchestrator recomendando arquitetura)
    NAO se testa aqui: isso e assunto de evals/.

    Nao escreve nada fora de $env:TEMP.

.PARAMETER Suite
    Nomes das suites a rodar. Aceita varios. Sem isto, roda todas.

.PARAMETER List
    Lista as suites disponiveis e sai.

.EXAMPLE
    .\tests\run-tests.ps1
    .\tests\run-tests.ps1 -List
    .\tests\run-tests.ps1 -Suite template
    .\tests\run-tests.ps1 -Suite skills,security

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string[]]$Suite,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$TestsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OsRoot    = Split-Path -Parent $TestsRoot
$SuitesDir = Join-Path $TestsRoot 'suites'

# Ordem deliberada: do que sustenta tudo para o que depende de tudo.
# Assim a primeira falha ja aponta para a camada mais provavel.
$Ordem = @('plugin', 'docs', 'policy', 'template', 'project-tests', 'skills', 'agents', 'collectors', 'scanner', 'doctor', 'hooks', 'fluxo', 'vnext', 'scripts', 'security')

$disponiveis = Get-ChildItem $SuitesDir -Filter '*.ps1' -ErrorAction SilentlyContinue |
               ForEach-Object { $_.BaseName }
if (-not $disponiveis) { throw "Nenhuma suite encontrada em $SuitesDir" }

# Conhecidas primeiro, na ordem; qualquer suite nova entra no fim sozinha.
$ordenadas = @()
foreach ($n in $Ordem) { if ($disponiveis -contains $n) { $ordenadas += $n } }
foreach ($n in $disponiveis) { if ($ordenadas -notcontains $n) { $ordenadas += $n } }

if ($List) {
    Write-Host ""
    Write-Host "Suites disponiveis:" -ForegroundColor Cyan
    foreach ($n in $ordenadas) {
        $casos = (Select-String -Path (Join-Path $SuitesDir "$n.ps1") -Pattern '^Test-Caso ').Count
        Write-Host ("  {0,-10} {1} casos" -f $n, $casos)
    }
    Write-Host ""
    exit 0
}

if ($Suite) {
    $invalidas = $Suite | Where-Object { $ordenadas -notcontains $_ }
    if ($invalidas) {
        # Mensagem util em vez de stack trace: quem erra o nome de uma suite
        # quer saber os nomes validos, nao a linha do runner.
        Write-Host ""
        Write-Host ("  Suite desconhecida: " + ($invalidas -join ', ')) -ForegroundColor Red
        Write-Host ("  Disponiveis: " + ($ordenadas -join ', ')) -ForegroundColor Yellow
        Write-Host ""
        exit 2
    }
    $aRodar = $ordenadas | Where-Object { $Suite -contains $_ }
} else {
    $aRodar = $ordenadas
}

. (Join-Path $TestsRoot '_harness.ps1')

# O que as suites esperam encontrar definido.
$Template = Join-Path $OsRoot 'templates\project-standard'

Write-Host ""
Write-Host "=== testes do Project OS ===" -ForegroundColor Cyan
Write-Host "    $OsRoot"
if ($Suite) { Write-Host ("    suites: " + ($aRodar -join ', ')) -ForegroundColor DarkGray }

foreach ($n in $aRodar) {
    Write-Suite $n
    . (Join-Path $SuitesDir "$n.ps1")
}

Write-Host ""
Write-Host "=== resultado ===" -ForegroundColor Cyan
Write-Host ("  passou: {0}   falhou: {1}" -f $script:passou, $script:falhou)

# A regua que a 2.4 impos aos projetos governados vale aqui tambem: suite que
# carrega e nao executa caso nenhum NAO sai com 0. Verde por vacuidade e o
# defeito mais barato que existe - na 2.3 havia cinco casos assim -, e a
# plataforma nao pode exigir dos outros o que nao cumpre para si.
# Achado do qa-reviewer no fechamento da 2.4.
if (($script:passou + $script:falhou) -eq 0) {
    Write-Host ""
    Write-Host "  A SUITE NAO RODOU (saida 2)" -ForegroundColor Red
    Write-Host "  As suites carregaram e nao executaram nenhum caso." -ForegroundColor Yellow
    Write-Host "  Isto NAO e o mesmo que teste passando - ver docs/VERIFICATION-POLICY.md 4.5." -ForegroundColor DarkGray
    Write-Host ""
    exit 2
}

if ($script:falhou -gt 0) {
    Write-Host ""
    Write-Host "  falhas:" -ForegroundColor Red
    foreach ($f in $script:falhas) { Write-Host "    - $f" -ForegroundColor Red }
    Write-Host ""
    exit 1
}
Write-Host ""
exit 0
