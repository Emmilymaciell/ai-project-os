<#
.SYNOPSIS
    Suite de testes: revisores read-only e coletores deterministicos.

.DESCRIPTION
    O desenho da subfase 2.2 (ADR-0008) tem uma garantia central: o campo
    tools e o UNICO limite de privilegio de um agente de plugin, porque
    permissionMode, hooks e mcpServers sao ignorados em silencio.

    Se alguem acrescentar Bash a um destes agentes, o read-only deixa de
    existir e nada avisa. Estes testes avisam.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite agents

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite agents"
}

$AgentesEsperados = @('qa-reviewer', 'security-reviewer')
$FerramentasProibidas = @('Bash', 'Write', 'Edit', 'NotebookEdit', 'PowerShell')

function Get-Frontmatter {
    param([string]$Caminho)
    $txt = Get-Texto $Caminho
    return ($txt -split '(?m)^---\s*$')[1]
}

Test-Caso "os 2 agentes revisores existem em agents/" {
    foreach ($a in $AgentesEsperados) {
        Assert-True (Test-Path (Join-Path $OsRoot "agents\$a.md")) "ausente: agents\$a.md"
    }
}

Test-Caso "cada agente tem frontmatter com name, description e tools" {
    foreach ($a in $AgentesEsperados) {
        $fm = Get-Frontmatter (Join-Path $OsRoot "agents\$a.md")
        foreach ($campo in @('name', 'description', 'tools')) {
            Assert-True ($fm -match "(?m)^${campo}:\s*\S") "$a : frontmatter sem '$campo'"
        }
    }
}

Test-Caso "o name do frontmatter bate com o nome do arquivo" {
    foreach ($a in $AgentesEsperados) {
        $fm = Get-Frontmatter (Join-Path $OsRoot "agents\$a.md")
        $declarado = ([regex]::Match($fm, '(?m)^name:\s*(.+?)\s*$')).Groups[1].Value
        Assert-True ($declarado -eq $a) "arquivo '$a' declara name '$declarado'"
    }
}

Test-Caso "os revisores sao read-only: tools tem apenas Read, Grep e Glob" {
    # A garantia central do ADR-0008. Bash e acesso de ESCRITA (Set-Content,
    # git commit, Remove-Item); um revisor com Bash nao e read-only, e chamar
    # de read-only documentaria uma garantia que nao existe.
    $permitidas = @('Read', 'Grep', 'Glob')
    foreach ($a in $AgentesEsperados) {
        $fm = Get-Frontmatter (Join-Path $OsRoot "agents\$a.md")
        $linha = ([regex]::Match($fm, '(?m)^tools:\s*(.+?)\s*$')).Groups[1].Value
        $lista = $linha -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        Assert-True ($lista.Count -gt 0) "$a : tools vazio"
        foreach ($t in $lista) {
            Assert-True ($permitidas -contains $t) "$a : tools contem '$t', que nao e read-only"
        }
    }
}

Test-Caso "os revisores negam explicitamente as ferramentas de escrita" {
    # Redundancia defensiva: tools ja restringe, mas disallowedTools deixa a
    # intencao legivel para quem editar o arquivo depois.
    foreach ($a in $AgentesEsperados) {
        $fm = Get-Frontmatter (Join-Path $OsRoot "agents\$a.md")
        $linha = ([regex]::Match($fm, '(?m)^disallowedTools:\s*(.+?)\s*$')).Groups[1].Value
        Assert-True (-not [string]::IsNullOrWhiteSpace($linha)) "$a : sem disallowedTools"
        foreach ($t in @('Write', 'Edit', 'Bash')) {
            Assert-True ($linha -match [regex]::Escape($t)) "$a : disallowedTools nao nega '$t'"
        }
    }
}

Test-Caso "nenhum agente usa campo que plugin ignora em silencio" {
    # permissionMode, hooks e mcpServers sao aceitos na sintaxe e IGNORADOS
    # quando o agente vem de plugin. Declarar um deles cria falsa seguranca.
    foreach ($a in $AgentesEsperados) {
        $fm = Get-Frontmatter (Join-Path $OsRoot "agents\$a.md")
        foreach ($campo in @('permissionMode', 'mcpServers', 'hooks')) {
            Assert-True ($fm -notmatch "(?m)^${campo}:") `
                "$a : declara '$campo', que plugin ignora em silencio - falsa seguranca"
        }
    }
}

Test-Caso "cada revisor conhece os tres vereditos e que inconclusivo bloqueia" {
    # Veredito binario e o modo de falha: sem INCONCLUSIVO, falta de evidencia
    # vira aprovacao por omissao.
    foreach ($a in $AgentesEsperados) {
        $txt = Get-Texto (Join-Path $OsRoot "agents\$a.md")
        foreach ($v in @('APROVADO', 'REPROVADO', 'INCONCLUSIVO')) {
            Assert-True ($txt -match $v) "$a : nao define o veredito $v"
        }
        Assert-True ($txt -match '(?i)aus.ncia de evid.ncia') `
            "$a : nao afirma que ausencia de evidencia nao e aprovacao"
    }
}

Test-Caso "cada revisor exige declarar a cobertura recebida" {
    foreach ($a in $AgentesEsperados) {
        $txt = Get-Texto (Join-Path $OsRoot "agents\$a.md")
        Assert-True ($txt -match '(?i)cobertura') "$a : nao fala de cobertura recebida"
        Assert-True ($txt -match '(?i)NAO foi (coberto|coletado)|n.o foi (coberto|coletado)') `
            "$a : nao exige declarar o que nao foi coberto"
    }
}

Test-Caso "cada revisor declara seus anti-falsos-positivos" {
    foreach ($a in $AgentesEsperados) {
        $txt = Get-Texto (Join-Path $OsRoot "agents\$a.md")
        Assert-True ($txt -match '(?i)anti-falsos-positivos') "$a : sem secao de anti-falsos-positivos"
    }
}

Test-Caso "os revisores referenciam o ADR que os define" {
    foreach ($a in $AgentesEsperados) {
        $txt = Get-Texto (Join-Path $OsRoot "agents\$a.md")
        Assert-True ($txt -match 'ADR-000[78]') "$a : nao referencia ADR-0007 nem ADR-0008"
    }
}

# =============================================================================

$Coletores = @('scripts\collect-diff.ps1', 'scripts\security-scan.ps1')

Test-Caso "os coletores deterministicos existem" {
    foreach ($c in $Coletores) {
        Assert-True (Test-Path (Join-Path $OsRoot $c)) "ausente: $c"
    }
}

Test-Caso "cada coletor declara escopo coberto E escopo nao coberto" {
    # Sem a segunda secao, o relatorio induz o revisor a achar que o escopo
    # era completo - e ausencia de evidencia viraria aprovacao.
    foreach ($c in $Coletores) {
        $txt = Get-Texto (Join-Path $OsRoot $c)
        # 'Cobertura por area' e a forma da 2.3: mesma exigencia, granularidade
        # maior - por area de veredito, e nao uma lista unica.
        Assert-True ($txt -match 'Escopo (VARRIDO|COLETADO)|Cobertura por area') "$c : nao declara escopo coberto"
        Assert-True ($txt -match 'Escopo NAO (VARRIDO|COLETADO)') "$c : nao declara escopo NAO coberto"
        Assert-True ($txt -match '(?i)ausencia de evidencia|nao e aprovacao') `
            "$c : nao avisa que lacuna nao e aprovacao"
    }
}

Test-Caso "o scanner varre o historico por padrao, e so declara lacuna quando pedem" {
    # Este teste substitui um da 2.2 que exigia o oposto - que o scanner
    # DECLARASSE nao varrer o historico. Depois da 2.3 ele varre, e o teste
    # antigo continuava PASSANDO, porque a string 'Historico do Git' seguia no
    # arquivo dentro do ramo do -SemHistorico. Teste que passa pelo motivo
    # errado e pior que teste que falha: ele afirma uma garantia que nao
    # existe mais. A cobertura funcional de verdade esta na suite 'scanner'.
    $txt = Get-Texto (Join-Path $OsRoot 'scripts\security-scan.ps1')
    Assert-True ($txt -match 'Get-AchadosHistorico') "o scanner nao chama o detector de historico"
    Assert-True ($txt -match 'SemHistorico') "nao existe forma explicita de desligar a varredura de historico"
    # E o desligamento tem de dizer o que custa.
    Assert-True ($txt -match 'INCONCLUSIVO') `
        "o scanner nao diz que a area fica INCONCLUSIVO quando o historico nao e varrido"
}

Test-Caso "o coletor de diff enxerga arquivo novo, que git diff nao mostra" {
    # git diff HEAD ignora arquivo nao rastreado. Sem isto o relatorio diria
    # "sem alteracoes" com codigo novo no disco - achado real da subfase 2.2.
    $txt = Get-Texto (Join-Path $OsRoot 'scripts\collect-diff.ps1')
    # Padrao tolerante a forma da chamada: desde a 2.4 todo git passa por
    # Invoke-Git com array de argumentos ('ls-files', '--others', ...), e nao
    # mais pela linha de comando solta. O que importa e a bandeira, nao a
    # sintaxe - amarrar o teste a sintaxe fez este caso reprovar por um
    # refactor que nao mudou comportamento nenhum.
    # Ancorado em Invoke-Git, nao so nas bandeiras: com \s* solto o padrao
    # podia ser satisfeito por um COMENTARIO que mencionasse as bandeiras, e
    # deixaria de provar que o coletor as usa. Achado do qa-reviewer.
    Assert-True ($txt -match "Invoke-GitCaminhos @\('-C', \`$Path, 'ls-files', '--others', '--exclude-standard', '-z'\)") `
        "o coletor nao lista arquivo nao rastreado via Invoke-Git"
    Assert-True ($txt -match '(?i)invisiveis ao git diff|arquivos novos') `
        "o coletor nao apresenta arquivo novo em secao propria"
}

Test-Caso "os coletores nunca transcrevem valor de credencial" {
    $txt = Get-Texto (Join-Path $OsRoot 'scripts\security-scan.ps1')
    Assert-True ($txt -match '(?i)nunca ecoar o valor|Reportar onde, nao o que') `
        "o scanner nao declara que reporta localizacao e nao valor"
}

Test-Caso "artifacts/ e ignorado: relatorio de revisao nao e versionado" {
    $gi = Get-Texto (Join-Path $OsRoot '.gitignore')
    Assert-True ($gi -match '(?m)^/artifacts/\*') ".gitignore nao ignora artifacts/"

    # A checagem via git so faz sentido se houver repositorio. Sem esta guarda
    # o teste quebra com "fatal: not a git repository" ao rodar sobre um export
    # ou uma copia sem .git - o que a CI e o proprio teste negativo fazem.
    if (-not (Test-Path (Join-Path $OsRoot '.git'))) {
        return $true
    }
    Push-Location $OsRoot
    try {
        $rastreados = @(git ls-files 2>$null)
        $vazando = @($rastreados | Where-Object { $_ -match '^artifacts/review/' })
        Assert-True ($vazando.Count -eq 0) ("relatorio de revisao versionado: " + ($vazando -join ', '))
    } finally { Pop-Location }
}

Test-Caso "a skill checkpoint sabe acionar os revisores" {
    $txt = Get-Texto (Join-Path $OsRoot 'skills\checkpoint\SKILL.md')
    Assert-True ($txt -match 'qa-reviewer') "checkpoint nao menciona o qa-reviewer"
    Assert-True ($txt -match 'security-reviewer') "checkpoint nao menciona o security-reviewer"
}
