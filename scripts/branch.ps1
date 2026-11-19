<#
.SYNOPSIS
    Branch: listar, estado, criar e trocar - com guarda-corpo em toda troca.

.DESCRIPTION
    A 2.7 e client-side por decisao registrada (ADR-0011): branch protection e
    rulesets estao indisponiveis neste plano, e isso **nao e equivalente** a
    enforcement no servidor. Este script nao finge o contrario. Ele torna o
    fluxo barato e explicito; quem garante de verdade e a CI da 2.8.

    A REGRA QUE ORGANIZA O ARQUIVO INTEIRO: trocar de branch com trabalho nao
    commitado no disco e como se perde trabalho sem perceber. O CLAUDE.md
    desta casa proibe 'trocar de branch no meio de um trabalho' desde a Fase 1,
    e aqui isso deixa de ser prosa:

      - '-Trocar' com working tree SUJA recusa, e nomeia os arquivos;
      - '-Trocar' exige '-Confirmar'. Sem ele, mostra o que faria e recusa.
        Troca implicita, feita 'de passagem' por outro comando, nao existe.

    Codigo de saida - ADR-0009:
      0  fez o que foi pedido, ou respondeu a pergunta
      1  RECUSOU: a arvore esta suja, falta confirmacao, o nome ja existe
      2  NAO CONSEGUIU determinar: fora de repositorio, git nao respondeu

.PARAMETER Path
    Raiz do repositorio. Aceita subdiretorio: a raiz e resolvida antes.

.PARAMETER Criar
    Nome do branch novo. Nao troca para ele sozinho - ver -Trocar.

.PARAMETER Trocar
    Nome do branch para o qual ir. Exige -Confirmar.

.PARAMETER Confirmar
    Autoriza a troca. Sem isto, '-Trocar' so mostra o que faria.

.PARAMETER De
    Base do branch novo. Default: o HEAD atual.

.EXAMPLE
    .\scripts\branch.ps1
    .\scripts\branch.ps1 -Criar 2.8-ci
    .\scripts\branch.ps1 -Trocar main -Confirmar

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [string]$Criar,
    [string]$Trocar,
    [switch]$Confirmar,
    [string]$De
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ""
    Write-Host "branch.ps1 NAO rodou: $_" -ForegroundColor Red
    Write-Host "Nenhuma afirmacao sobre o estado dos branches e valida." -ForegroundColor Yellow
    Write-Host ""
    exit 2
}

$LibDir = Join-Path $PSScriptRoot 'lib'
foreach ($m in @('scan-comum.ps1', 'branch-comum.ps1')) {
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

# --- estado, que todo caminho usa ---------------------------------------------
$estado = Get-EstadoDeBranch -Raiz $raiz
if ($estado.Indeterminado) {
    Write-Host "NAO SEI: $($estado.Motivo)" -ForegroundColor Red
    Write-Host "'nao consegui perguntar' nao e 'esta limpo'." -ForegroundColor Yellow
    exit 2
}

# =============================================================================
# CRIAR
# =============================================================================
if ($Criar) {
    $erro = Test-NomeDeBranch -Nome $Criar
    if ($erro) {
        Write-Host "RECUSADO: $erro" -ForegroundColor Red
        exit 1
    }
    if ($estado.Locais -contains $Criar) {
        Write-Host "RECUSADO: o branch '$Criar' ja existe localmente." -ForegroundColor Red
        Write-Host "  Para ir para ele: .\scripts\branch.ps1 -Trocar $Criar -Confirmar" -ForegroundColor Yellow
        exit 1
    }

    # '-De' PRECISA ser validado, e o qa-reviewer mostrou o custo de nao o ter
    # sido: '-Criar x -De -m' vira 'git branch x -m', e '-m' RENOMEIA o branch
    # atual para 'x'. O script entao imprimia "CRIADO x ... voce continua em
    # 'main'" - e 'main' nao existia mais. A justificativa que o proprio
    # 'Test-NomeDeBranch' da para barrar hifen inicial ("seria lido como flag")
    # valia aqui e nao tinha sido aplicada.
    $base = $De
    if (-not $base) { $base = 'HEAD' }
    if ($base.StartsWith('-')) {
        Write-Host "RECUSADO: -De '$base' comeca com hifen, e o git o leria como opcao." -ForegroundColor Red
        exit 1
    }
    $null = Invoke-Git @('-C', $raiz, 'rev-parse', '--verify', '--quiet', ($base + '^{commit}')) -PermitirFalha
    if ($LASTEXITCODE -ne 0) {
        Write-Host "RECUSADO: -De '$base' nao resolve para um commit neste repositorio." -ForegroundColor Red
        exit 1
    }

    # CRIA sem trocar. Criar e ir sao decisoes diferentes, e juntar as duas e
    # como a troca implicita acontece sem ninguem decidir por ela.
    $null = Invoke-Git @('-C', $raiz, 'branch', $Criar, $base)
    Write-Host ""
    Write-Host "CRIADO  $Criar  (base: $base)" -ForegroundColor Green
    Write-Host "        voce continua em '$($estado.Atual)'" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Para ir para ele:  .\scripts\branch.ps1 -Trocar $Criar -Confirmar" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# =============================================================================
# TROCAR
# =============================================================================
if ($Trocar) {
    if ($Trocar -eq $estado.Atual) {
        Write-Host "Voce ja esta em '$Trocar'. Nada a fazer." -ForegroundColor DarkGray
        exit 0
    }
    if (($estado.Locais -notcontains $Trocar) -and ($estado.Remotos -notcontains $Trocar)) {
        Write-Host "RECUSADO: nao existe branch '$Trocar', nem local nem remoto." -ForegroundColor Red
        Write-Host "  Para criar:  .\scripts\branch.ps1 -Criar $Trocar" -ForegroundColor Yellow
        exit 1
    }

    # A GUARDA, e ela vem antes da confirmacao de proposito: arvore suja
    # recusa mesmo com '-Confirmar'. Confirmar e autorizar a troca, nao
    # autorizar perder trabalho.
    if ($estado.Sujos.Count -gt 0) {
        Write-Host ""
        Write-Host "RECUSADO: ha $($estado.Sujos.Count) arquivo(s) nao commitado(s)." -ForegroundColor Red
        foreach ($f in @($estado.Sujos | Select-Object -First 15)) { Write-Host "    $f" -ForegroundColor Red }
        if ($estado.Sujos.Count -gt 15) { Write-Host "    ... e mais $($estado.Sujos.Count - 15)" -ForegroundColor Red }
        Write-Host ""
        Write-Host "  O que fazer:" -ForegroundColor Yellow
        Write-Host "    commite o que esta pronto, ou guarde o resto deliberadamente." -ForegroundColor Yellow
        Write-Host "    Este script NAO faz stash por voce: esconder trabalho sem" -ForegroundColor Yellow
        Write-Host "    pedido e a forma mais rapida de perde-lo." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    if (-not $Confirmar) {
        Write-Host ""
        Write-Host "PARADO: trocar de branch nao acontece sem confirmacao explicita." -ForegroundColor Yellow
        Write-Host "  de '$($estado.Atual)' para '$Trocar'" -ForegroundColor Yellow
        Write-Host "  arvore limpa, entao a troca e segura." -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Para fazer:  .\scripts\branch.ps1 -Trocar $Trocar -Confirmar" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    $null = Invoke-Git @('-C', $raiz, 'checkout', $Trocar)
    $depois = Get-EstadoDeBranch -Raiz $raiz
    if ($depois.Indeterminado -or $depois.Atual -ne $Trocar) {
        Write-Host "ERRO: pedi a troca e o branch atual e '$($depois.Atual)'." -ForegroundColor Red
        Write-Host "Nao declaro feito o que eu mesmo nao consegui confirmar." -ForegroundColor Yellow
        exit 2
    }
    Write-Host ""
    Write-Host "AGORA EM  $Trocar" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# =============================================================================
# LISTAR (default)
# =============================================================================
Write-Host ""
Write-Host "Branches - $raiz" -ForegroundColor Cyan
Write-Host ""
Write-Host "  atual ....... $($estado.Atual)" -ForegroundColor Green
if ($estado.Locais.Count -gt 1) {
    $outros = @($estado.Locais | Where-Object { $_ -ne $estado.Atual })
    Write-Host "  locais ...... $($outros -join ', ')" -ForegroundColor Gray
}
if ($estado.Remotos.Count -gt 0) {
    Write-Host "  remotos ..... $($estado.Remotos -join ', ')" -ForegroundColor DarkGray
}
Write-Host "  base ........ $($estado.Base)" -ForegroundColor DarkGray

if ($estado.Sujos.Count -gt 0) {
    Write-Host ""
    Write-Host "  $($estado.Sujos.Count) arquivo(s) nao commitado(s) - a troca de branch esta BLOQUEADA" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "  arvore limpa" -ForegroundColor DarkGray
}
Write-Host ""
exit 0
