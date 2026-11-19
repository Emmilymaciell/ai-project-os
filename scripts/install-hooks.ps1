<#
.SYNOPSIS
    Ativa os hooks VERSIONADOS deste repositorio. Idempotente.

.DESCRIPTION
    O mecanismo e uma linha: 'core.hooksPath' apontando para 'githooks/', que
    esta versionada. Nao ha copia para '.git/hooks', e isso e desenho:

      - '.git/' nao viaja num clone. Hook que mora la depende de alguem
        lembrar de recria-lo, e e exatamente o "arquivo manual escondido" que
        o contrato de portabilidade desta plataforma nao aceita;
      - copia diverge da origem. Sem copia, o que roda E o arquivo versionado
        que a revisao leu.

    O valor gravado e RELATIVO ('githooks'), medido nesta maquina: resolve
    contra o topo da working tree e dispara igual a partir de subdiretorio.
    Relativo tambem e o que sobrevive a mover ou renomear a pasta do projeto -
    caminho absoluto gravado no '.git/config' de um repositorio no OneDrive
    quebra na primeira sincronizacao para outra maquina.

    IDEMPOTENTE e NAO-DESTRUTIVO. Se 'core.hooksPath' ja aponta para outro
    lugar, ele NAO e sobrescrito em silencio: o script mostra o valor atual e
    exige '-Reparar'. Configuracao que alguem escolheu nao se troca por
    conta propria.

.PARAMETER Path
    Raiz do repositorio. Aceita subdiretorio: a raiz e resolvida antes.

.PARAMETER Verificar
    So diagnostica, nao configura nada. Sai 0 quando esta tudo instalado e 1
    quando falta algo - util em script.

.PARAMETER Reparar
    Autoriza sobrescrever um 'core.hooksPath' que aponta para outro lugar.

.EXAMPLE
    .\scripts\install-hooks.ps1
    .\scripts\install-hooks.ps1 -Verificar
    .\scripts\install-hooks.ps1 -Reparar

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [switch]$Verificar,
    [switch]$Reparar
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ""
    Write-Host "install-hooks NAO rodou: $_" -ForegroundColor Red
    Write-Host "Nenhuma afirmacao sobre o estado dos hooks e valida." -ForegroundColor Yellow
    Write-Host ""
    exit 2
}

$LibDir = Join-Path $PSScriptRoot 'lib'
foreach ($m in @('scan-comum.ps1', 'hooks-comum.ps1')) {
    $p = Join-Path $LibDir $m
    if (-not (Test-Path $p -PathType Leaf)) {
        Write-Host "ERRO: biblioteca ausente: '$p'" -ForegroundColor Red
        exit 2
    }
    . $p
}

$r = Get-RaizDoRepositorio -Path $Path
if (-not $r.Resolvida) {
    Write-Host "ERRO: $($r.Motivo)" -ForegroundColor Red
    exit 2
}
$raiz = $r.Raiz
$pastaHooks = Join-Path $raiz $OS_HOOKS_DIR

Write-Host ""
Write-Host "Hooks do Project OS - $raiz" -ForegroundColor Cyan
Write-Host ""

# A pasta versionada precisa existir E ter os shims. Sem isso, apontar
# 'core.hooksPath' para ela produziria uma instalacao que nao faz nada, e
# esse e o pior resultado possivel: a pessoa acredita estar protegida.
if (-not (Test-Path $pastaHooks -PathType Container)) {
    Write-Host "FALTA  a pasta versionada '$OS_HOOKS_DIR/' nao existe neste repositorio." -ForegroundColor Red
    Write-Host "       Sem ela, apontar core.hooksPath produziria instalacao que nao verifica nada." -ForegroundColor Yellow
    exit 2
}

$faltandoNoDisco = @()
foreach ($nome in $OS_HOOKS_ESPERADOS) {
    if (-not (Test-Path (Join-Path $pastaHooks $nome) -PathType Leaf)) { $faltandoNoDisco += $nome }
}
if (@($faltandoNoDisco).Count -gt 0) {
    Write-Host ("FALTA  '$OS_HOOKS_DIR/' existe e nao tem: " + ($faltandoNoDisco -join ', ')) -ForegroundColor Red
    Write-Host "       Instalar assim deixaria buraco sem aviso." -ForegroundColor Yellow
    exit 2
}

$estado = Get-EstadoDosHooks -Raiz $raiz

if ($estado.Indeterminado) {
    Write-Host "NAO SEI  $($estado.Motivo)" -ForegroundColor Red
    Write-Host "         'nao consegui perguntar' nao e 'esta instalado' nem 'nao esta'." -ForegroundColor Yellow
    exit 2
}

# --- modo -Verificar: diagnostica e sai --------------------------------------
if ($Verificar) {
    if ($estado.Instalado) {
        Write-Host "OK     core.hooksPath = '$($estado.HooksPath)'" -ForegroundColor Green
        Write-Host ("OK     " + ($estado.Presentes -join ', ') + " - versao $OS_HOOKS_VERSAO") -ForegroundColor Green
        Write-Host ""
        exit 0
    }
    Write-Host "FALTA  $($estado.Motivo)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Para instalar: .\scripts\install-hooks.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- modo de instalacao ------------------------------------------------------
if ($estado.Aponta -eq 'outro-lugar' -and -not $Reparar) {
    Write-Host "PARADO core.hooksPath ja aponta para '$($estado.HooksPath)'." -ForegroundColor Yellow
    Write-Host "       Nao sobrescrevo configuracao que alguem escolheu." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Se foi voce e quer trocar: .\scripts\install-hooks.ps1 -Reparar" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if ($estado.Aponta -ne 'certo' -or $Reparar) {
    $null = Invoke-Git @('-C', $raiz, 'config', 'core.hooksPath', $OS_HOOKS_DIR)
    Write-Host "GRAVADO core.hooksPath = '$OS_HOOKS_DIR'" -ForegroundColor Green
} else {
    # Idempotencia de verdade: ja estava certo, nada e gravado.
    Write-Host "OK     core.hooksPath ja valia '$OS_HOOKS_DIR' - nada a fazer" -ForegroundColor Green
}

$depois = Get-EstadoDosHooks -Raiz $raiz
if ($depois.Indeterminado -or -not $depois.Instalado) {
    Write-Host ""
    Write-Host "ERRO   gravei a configuracao e a verificacao seguinte ainda acusa: $($depois.Motivo)" -ForegroundColor Red
    Write-Host "       Nao declaro instalado o que eu mesmo nao consegui confirmar." -ForegroundColor Yellow
    Write-Host ""
    exit 2
}

Write-Host ("OK     " + ($depois.Presentes -join ', ') + " - versao $OS_HOOKS_VERSAO") -ForegroundColor Green
Write-Host ""
Write-Host "  O que eles fazem, e como contornar quando for preciso:" -ForegroundColor DarkGray
Write-Host "    docs/runbooks/hooks.md" -ForegroundColor DarkGray
Write-Host ""
exit 0
