<#
.SYNOPSIS
    Instala o Emmily AI Project OS nesta maquina.

.DESCRIPTION
    Verifica o ambiente, cria a arvore do workspace se faltar, e mostra o passo
    de registro do plugin. IDEMPOTENTE e NAO-DESTRUTIVO: nunca sobrescreve
    configuracao existente nem apaga nada.

    E o outro lado do contrato de portabilidade: quem clonar este repositorio
    em outra maquina roda ISTO e sabe exatamente o que falta.

.PARAMETER Check
    So verifica e reporta. Nao cria pasta nenhuma.

.EXAMPLE
    .\scripts\bootstrap.ps1
    .\scripts\bootstrap.ps1 -Check

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

# stderr de executavel nativo vira ErrorRecord no PowerShell 5.1, e sob 'Stop'
# isso e TERMINANTE. Este script diagnostica um ambiente que pode estar
# incompleto - e o modo de falha era o pior possivel: sem git instalado, ele
# registrava "Git nao encontrado. Instale: winget..." e ABORTAVA na linha
# seguinte, antes do resumo que dava a instrucao. O qa-reviewer apontou que
# este e o arquivo espelho do bootstrap do template, que a 2.4 corrigiu.
function Invoke-NativoLocal {
    param([Parameter(Mandatory = $true)][string]$Comando,
          [string[]]$Argumentos = @())
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & $Comando @Argumentos 2>$null
        $codigo = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $anterior
    }
    # 'Codigo' entrou na subfase 2.6: o passo de hooks precisa distinguir 0, 1
    # e 2, e nao so passou/nao passou. Os chamadores antigos usam .Ok e .Saida
    # e seguem valendo.
    return @{ Ok = ($codigo -eq 0); Saida = @($saida); Codigo = $codigo }
}
$OsRoot    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Workspace = Split-Path -Parent (Split-Path -Parent $OsRoot)

$problemas = @()
$avisos    = @()

function Write-Item {
    param([string]$Estado, [string]$Texto)
    $cor = switch ($Estado) {
        'OK'    { 'Green' }
        'FALTA' { 'Red' }
        'AVISO' { 'Yellow' }
        default { 'Gray' }
    }
    Write-Host ("  [{0,-5}] {1}" -f $Estado, $Texto) -ForegroundColor $cor
}

Write-Host ""
Write-Host "=== Emmily AI Project OS - bootstrap ===" -ForegroundColor Cyan
Write-Host "    OS       : $OsRoot"
Write-Host "    Workspace: $Workspace"
Write-Host ""

# --- 1. Ferramentas -----------------------------------------------------------
Write-Host "Ferramentas" -ForegroundColor White

# TODAS as chamadas abaixo passam por Invoke-NativoLocal. A funcao foi
# adicionada numa rodada anterior e NAO foi conectada - o qa-reviewer achou:
# "correcao adicionada e nao conectada", com o comentario afirmando que o
# defeito tinha sido corrigido enquanto as chamadas continuavam soltas.
# Afirmar corrigido o que nao estava, dentro do conserto dessa mesma classe.
#
# O cenario que o comentario descrevia seguia vivo: sem git no PATH, a linha
# que DETECTA a ausencia registrava o problema e a proxima lancava
# CommandNotFoundException terminante - o script morria antes do resumo que
# carrega a instrucao 'winget install --id Git.Git'.
$temGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
if ($temGit) {
    $rVersao = Invoke-NativoLocal 'git' @('--version')
    if ($rVersao.Ok -and $rVersao.Saida.Count -gt 0) {
        Write-Item 'OK' ("git " + (($rVersao.Saida[0] -split ' ')[2]))
    } else {
        Write-Item 'AVISO' "git esta no PATH mas nao respondeu a --version"
    }
} else {
    $problemas += "Git nao encontrado. Instale: winget install --id Git.Git"
    Write-Item 'FALTA' "git"
}

# 'config --global' sai com 1 quando a chave nao existe: aqui codigo != 0 e
# RESPOSTA, nao falha. E sem git no PATH nao ha o que perguntar - perguntar
# assim mesmo era o que matava o script.
$gitNome  = ''
$gitEmail = ''
$branch   = ''
if ($temGit) {
    $gitNome  = (Invoke-NativoLocal 'git' @('config', '--global', 'user.name')).Saida  | Select-Object -First 1
    $gitEmail = (Invoke-NativoLocal 'git' @('config', '--global', 'user.email')).Saida | Select-Object -First 1
}
if (-not $temGit) {
    Write-Item 'AVISO' "identidade Git nao verificada: git ausente"
} elseif ([string]::IsNullOrWhiteSpace($gitNome) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
    $problemas += "Identidade Git global ausente. Configure: git config --global user.name / user.email"
    Write-Item 'FALTA' "identidade Git global"
} else {
    Write-Item 'OK' "identidade: $gitNome <$gitEmail>"
}

if ($temGit) {
    $branch = (Invoke-NativoLocal 'git' @('config', '--global', 'init.defaultBranch')).Saida | Select-Object -First 1
}
# Sem git nao ha configuracao a ler, e "$branch" fica vazio: a versao
# anterior caia direto no ramo de aviso e imprimia "init.defaultBranch nao e
# 'main'" sobre uma configuracao que NINGUEM leu. A identidade ja tinha o
# ramo explicito; este ficou sem, e o publico do bootstrap e justamente a
# maquina nova sem Git. Achado do qa-reviewer.
if (-not $temGit) {
    Write-Item 'AVISO' "init.defaultBranch nao verificado: git ausente"
    $avisos += "init.defaultBranch nao verificado porque o git esta ausente. Confira depois de instalar."
} elseif ($branch -ne 'main') {
    $avisos += "init.defaultBranch nao e 'main'. Repos novos podem nascer em 'master'."
    Write-Item 'AVISO' "init.defaultBranch = '$branch'"
} else {
    Write-Item 'OK' "init.defaultBranch = main"
}

if (Get-Command py -ErrorAction SilentlyContinue) {
    # 'py -0' escreve a lista em stdout e avisos em stderr; sob 'Stop' o
    # aviso seria terminante. Mesma porta do git e do gh.
    $rPy = Invoke-NativoLocal 'py' @('-0')
    # Mesmo par que git e gh: launcher presente com nenhum runtime registrado
    # devolvia "[OK] python: " com o valor VAZIO - diagnostico dizendo OK
    # sobre ausencia. Achado do qa-reviewer.
    $versoesPy = (($rPy.Saida | Where-Object { $_ -match '-V:' }) -join ' ').Trim()
    if ($rPy.Ok -and $versoesPy) {
        Write-Item 'OK' ("python: " + $versoesPy)
    } else {
        $avisos += "O launcher 'py' responde mas nao listou nenhum runtime Python registrado."
        Write-Item 'AVISO' "py esta no PATH e nao listou runtime"
    }
} else {
    $avisos += "Launcher 'py' ausente. Projetos Python vao precisar dele."
    Write-Item 'AVISO' "launcher py"
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
    # Mesma porta do git: 'gh --version' escrevendo em stderr sob 'Stop'
    # mataria o script antes do resumo.
    $rGh = Invoke-NativoLocal 'gh' @('--version')
    if ($rGh.Ok -and $rGh.Saida.Count -gt 0) {
        Write-Item 'OK' ("gh " + (($rGh.Saida[0] -split ' ')[2]))
    } else {
        Write-Item 'AVISO' "gh esta no PATH mas nao respondeu a --version"
    }
} else {
    $avisos += "GitHub CLI ausente. Sem ele nao ha remoto, PR nem CI. Instale: winget install --id GitHub.cli"
    Write-Item 'AVISO' "gh nao instalado"
}

# --- 2. Workspace -------------------------------------------------------------
Write-Host ""
Write-Host "Workspace" -ForegroundColor White
$pastas = @('_platform', 'work', 'work\prog', 'work\dynatest', 'work\cliente-b',
            'university', 'personal', 'ai-lab', 'portfolio')
foreach ($p in $pastas) {
    $caminho = Join-Path $Workspace $p
    if (Test-Path $caminho) {
        Write-Item 'OK' $p
    } elseif ($Check) {
        $avisos += "Pasta ausente: $p"
        Write-Item 'AVISO' "$p ausente"
    } else {
        New-Item -ItemType Directory -Path $caminho -Force | Out-Null
        Write-Item 'OK' "$p (criada)"
    }
}

# --- 3. Estrutura do OS -------------------------------------------------------
Write-Host ""
Write-Host "Estrutura do OS" -ForegroundColor White
$esperados = @('.claude-plugin\plugin.json', '.claude-plugin\marketplace.json',
               'CLAUDE.md', 'README.md', 'CHANGELOG.md',
               'docs\STATE.md', 'docs\ARCHITECTURE.md', 'docs\VISION.md',
               'templates\project-standard\project.yaml')
foreach ($f in $esperados) {
    if (Test-Path (Join-Path $OsRoot $f)) {
        Write-Item 'OK' $f
    } else {
        $problemas += "Arquivo essencial ausente: $f"
        Write-Item 'FALTA' $f
    }
}

# --- 4. Registro do plugin ----------------------------------------------------
Write-Host ""
Write-Host "Plugin" -ForegroundColor White
$marketplaces = Join-Path $env:USERPROFILE '.claude\plugins\known_marketplaces.json'
$registrado = $false
if (Test-Path $marketplaces) {
    $conteudo = Get-Content $marketplaces -Raw
    if ($conteudo -match 'emmily-platform') { $registrado = $true }
}

if ($registrado) {
    Write-Item 'OK' "marketplace 'emmily-platform' registrado"
} else {
    Write-Item 'AVISO' "marketplace ainda nao registrado"
    $avisos += "Registre o plugin: dentro do Claude Code, rode  /plugin marketplace add $OsRoot  e depois instale o plugin 'os'."
}

# --- 5. Hooks de Git ----------------------------------------------------------
# Um clone novo deste repositorio chega com 'githooks/' versionada e SEM
# 'core.hooksPath' configurado - a configuracao mora em '.git/config', que nao
# viaja. E exatamente este passo que fecha o contrato: quem clonou roda o
# bootstrap e sai com os guarda-corpos ativos, sem copiar nada a mao.
#
# Em '-Check' ele so diagnostica, como todo o resto deste script. Fora dele,
# instala - e a instalacao e idempotente: rodar de novo nao regrava nada.
Write-Host ""
Write-Host "Hooks de Git" -ForegroundColor White
$instalador = Join-Path $OsRoot 'scripts\install-hooks.ps1'
if (-not $temGit) {
    Write-Item 'AVISO' "hooks nao verificados: git ausente"
    $avisos += "Hooks de Git nao verificados porque o git esta ausente. Rode .\scripts\install-hooks.ps1 depois de instalar."
} elseif (-not (Test-Path $instalador -PathType Leaf)) {
    $problemas += "Arquivo essencial ausente: scripts\install-hooks.ps1"
    Write-Item 'FALTA' "scripts\install-hooks.ps1"
} else {
    # POR Invoke-NativoLocal, e nao por chamada direta. Achado do qa-reviewer
    # na terceira rodada da 2.6, e e o mesmo defeito que esta subfase fechou
    # dentro dos hooks - um arquivo ao lado, escrito por mim nesta subfase.
    #
    # O estrago: com '$ErrorActionPreference = Stop' no topo e sem 'trap' neste
    # arquivo, qualquer escrita do filho em stderr vira ErrorRecord TERMINANTE
    # e o bootstrap MORRE aqui - sem o '=== resumo ===', perdendo todos os
    # 'BLOQUEIA:' e 'atencao :' que ele ja tinha juntado. O cenario concreto
    # que ele deu: politica de execucao imposta por GPO corporativa, em que
    # '-ExecutionPolicy Bypass' e ignorado, o instalador nao carrega e o erro
    # de assinatura sai em stderr.
    #
    # E a linha 75 deste arquivo ja dizia "TODAS as chamadas abaixo passam por
    # Invoke-NativoLocal". Esta estava abaixo e nao passava: a afirmacao era
    # mais larga que o codigo, no arquivo que a faz.
    $argsHook = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $instalador, '-Path', $OsRoot)
    if ($Check) { $argsHook += '-Verificar' }
    $rHook = Invoke-NativoLocal 'powershell' $argsHook
    $codigoHook = $rHook.Codigo
    if ($codigoHook -eq 0) {
        Write-Item 'OK' "commit-msg, pre-commit, pre-push ativos"
    } elseif ($Check) {
        Write-Item 'AVISO' "hooks nao instalados"
        $avisos += "Hooks de Git nao instalados. Rode: .\scripts\install-hooks.ps1"
    } else {
        # Instalacao que nao terminou nao pode virar aviso discreto: quem le
        # "atencao" segue em frente acreditando estar protegido.
        $problemas += "Nao consegui ativar os hooks de Git (codigo $codigoHook). Rode .\scripts\install-hooks.ps1 e leia a saida."
        Write-Item 'FALTA' "hooks de Git (codigo $codigoHook)"
    }
}

# --- Resumo -------------------------------------------------------------------
Write-Host ""
Write-Host "=== resumo ===" -ForegroundColor Cyan
if ($problemas.Count -eq 0 -and $avisos.Count -eq 0) {
    Write-Host "  Tudo pronto. Use /os:status para comecar." -ForegroundColor Green
    exit 0
}
foreach ($p in $problemas) { Write-Host "  BLOQUEIA: $p" -ForegroundColor Red }
foreach ($a in $avisos)    { Write-Host "  atencao : $a" -ForegroundColor Yellow }
Write-Host ""
if ($problemas.Count -gt 0) { exit 1 }
exit 0
