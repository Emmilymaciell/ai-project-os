<#
.SYNOPSIS
    Hook commit-msg: barra mensagem de commit estruturalmente invalida.

.DESCRIPTION
    Chamado por 'githooks/commit-msg'. As regras vivem em
    'scripts/lib/hooks-comum.ps1', como funcao pura sobre o texto - aqui so
    acontece o que depende do mundo: ler o arquivo que o git passou, e decidir
    o codigo de saida.

    Codigo de saida:
      0  a mensagem passa
      1  a mensagem tem problema estrutural (o git aborta o commit)
      2  NAO foi possivel verificar - e isto tambem barra, de proposito.
         "nao consegui conferir" nunca pode virar "esta bom": e a politica 4.5
         aplicada ao hook.

.PARAMETER Caminho
    O arquivo de mensagem que o git passa como primeiro argumento.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Caminho
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ''
    Write-Host "[commit-msg] NAO consegui verificar a mensagem: $_" -ForegroundColor Red
    Write-Host "Isto NAO e um veredito sobre a mensagem. Nada foi aprovado." -ForegroundColor Yellow
    Write-Host ''
    exit 2
}

$LibDir = Join-Path $PSScriptRoot 'lib'
foreach ($m in @('scan-comum.ps1', 'hooks-comum.ps1')) {
    $p = Join-Path $LibDir $m
    if (-not (Test-Path $p -PathType Leaf)) {
        Write-Host "[commit-msg] biblioteca ausente: '$p'" -ForegroundColor Red
        exit 2
    }
    . $p
}

if (-not (Test-Path $Caminho -PathType Leaf)) {
    Write-Host "[commit-msg] o arquivo de mensagem '$Caminho' nao existe." -ForegroundColor Red
    exit 2
}

# Leitura estrita, a mesma dos detectores: arquivo que nao le como texto nao
# pode virar mensagem vazia e passar por outro ramo.
$texto = Read-TextoDeArquivo $Caminho
if ($null -eq $texto) {
    Write-Host "[commit-msg] o arquivo de mensagem existe e nao le como texto UTF-8." -ForegroundColor Red
    exit 2
}

# 'core.commentChar' pode nao ser '#'. Perguntar custa uma chamada e evita
# tratar todo o corpo como comentario - ou nenhum.
$comentario = '#'
$cc = @(Invoke-Git @('config', '--get', 'core.commentChar') -PermitirFalha)
if ($LASTEXITCODE -eq 0 -and @($cc).Count -gt 0) {
    $v = ("" + @($cc)[0]).Trim()
    if ($v.Length -eq 1) { $comentario = $v }
}

$r = Test-MensagemDeCommit -Texto $texto -CaractereDeComentario $comentario

if ($r.Ok) { exit 0 }

Write-ProblemaDeHook -Hook 'commit-msg' -Problemas $r.Problemas -Acoes @(
    "corrija a mensagem e repita o commit;",
    "o formato e: assunto numa linha, UMA linha em branco, depois o corpo;",
    "detalhes e como contornar: docs/runbooks/hooks.md"
)
exit 1
