<#
.SYNOPSIS
    Suite de testes: Manifestos do plugin.

.DESCRIPTION
    Os manifestos que fazem o /os:* existir. Se estes quebram, nada carrega.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite plugin

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite plugin"
}

Test-Caso "plugin.json e JSON valido" {
    $p = Join-Path $OsRoot '.claude-plugin\plugin.json'
    Assert-True (Test-Path $p) "plugin.json nao existe"
    $null = Get-Content $p -Raw | ConvertFrom-Json
}

Test-Caso "plugin.json declara name='os' (e o que produz o namespace /os:*)" {
    $j = Get-Content (Join-Path $OsRoot '.claude-plugin\plugin.json') -Raw | ConvertFrom-Json
    Assert-True ($j.name -eq 'os') "name e '$($j.name)', esperado 'os'"
    Assert-True (-not [string]::IsNullOrWhiteSpace($j.description)) "description vazia"
    Assert-True (-not [string]::IsNullOrWhiteSpace($j.version)) "version vazia"
}

Test-Caso "marketplace.json e JSON valido e aponta para o plugin 'os'" {
    $p = Join-Path $OsRoot '.claude-plugin\marketplace.json'
    Assert-True (Test-Path $p) "marketplace.json nao existe"
    $j = Get-Content $p -Raw | ConvertFrom-Json
    Assert-True ($j.plugins.Count -ge 1) "nenhum plugin declarado"
    $os = $j.plugins | Where-Object { $_.name -eq 'os' }
    Assert-True ($null -ne $os) "plugin 'os' ausente do marketplace"
    Assert-True ($os.source -eq './') "source e '$($os.source)', esperado './'"
}

Test-Caso "source './' aponta para um diretorio que contem .claude-plugin" {
    # Regra do Claude Code: o path do plugin resolve a partir da raiz do marketplace.
    Assert-True (Test-Path (Join-Path $OsRoot '.claude-plugin\plugin.json')) `
        "source './' nao resolve para um plugin valido"
}

Test-Caso "hooks/hooks.json e JSON valido e o PreToolUse Bash|PowerShell aponta para um arquivo existente" {
    # Guarda de git destrutivo para agentes (incidente r13; docs/runbooks/hooks.md).
    $p = Join-Path $OsRoot 'hooks\hooks.json'
    Assert-True (Test-Path $p -PathType Leaf) "hooks/hooks.json nao existe"
    $j = Get-Texto $p | ConvertFrom-Json
    $entradas = @($j.hooks.PreToolUse)
    Assert-True ($entradas.Count -ge 1) "nenhuma entrada PreToolUse"
    $alvo = @($entradas | Where-Object { (($_.matcher -split '\|') -ccontains 'Bash') -and (($_.matcher -split '\|') -ccontains 'PowerShell') })
    Assert-True ($alvo.Count -eq 1) ("esperada 1 entrada com matcher Bash|PowerShell, achei " + $alvo.Count)
    $cmds = @($alvo[0].hooks | Where-Object { $_.type -ceq 'command' })
    Assert-True ($cmds.Count -eq 1) "esperado 1 hook do tipo command"
    $m = [regex]::Match($cmds[0].command, '\$\{CLAUDE_PLUGIN_ROOT\}/([^"\s]+)')
    Assert-True $m.Success ("o comando nao referencia um arquivo sob CLAUDE_PLUGIN_ROOT: " + $cmds[0].command)
    $arq = Join-Path $OsRoot ($m.Groups[1].Value -replace '/', '\')
    Assert-True (Test-Path $arq -PathType Leaf) ("o hook aponta para arquivo inexistente: " + $m.Groups[1].Value)
}
