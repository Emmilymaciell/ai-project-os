<#
.SYNOPSIS
    Suite de testes: Skills do plugin.

.DESCRIPTION
    As 5 skills da Fase 1 e as regras que elas nao podem esquecer.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite skills

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite skills"
}

# DESCOBERTA DO DISCO, e nao uma lista escrita a mao: assim toda skill nova
# entra automaticamente nas regras desta suite.
#
# Antes disto, $SkillsEsperadas era usada em cinco testes e NAO era definida
# em lugar nenhum. Ela vivia no monolito de testes, a modularizacao da subfase
# 2.0 a perdeu, e ninguem percebeu porque 'foreach ($x in $null)' nao e erro
# no PowerShell: os cinco testes passaram a iterar zero vezes e a passar sem
# verificar nada. Verde por vacuidade e a pior forma de verde, e e por isso
# que o teste logo abaixo existe.
$SkillsEmDisco = @(Get-ChildItem (Join-Path $OsRoot 'skills') -Directory |
                   ForEach-Object { $_.Name } | Sort-Object)
$SkillsEsperadas = $SkillsEmDisco
$SkillsDaFase1 = @('new-project', 'resume', 'checkpoint', 'status', 'handoff')

Test-Caso "a lista de skills sob teste nao esta vazia (senao a suite passa por vacuidade)" {
    Assert-True ($SkillsEsperadas.Count -ge 6) `
        "esperava pelo menos 6 skills em disco, achei $($SkillsEsperadas.Count)"
    $faltando = @($SkillsDaFase1 | Where-Object { $SkillsEsperadas -notcontains $_ })
    Assert-True ($faltando.Count -eq 0) ("skill da Fase 1 desapareceu: " + ($faltando -join ', '))
}

Test-Caso "toda skill existe como <nome>/SKILL.md" {
    foreach ($nome in $SkillsEsperadas) {
        $p = Join-Path $OsRoot "skills\$nome\SKILL.md"
        Assert-True (Test-Path $p) "ausente: skills\$nome\SKILL.md"
    }
}

Test-Caso "nao existe pasta commands/ (ADR-0004: skills/ e a forma canonica)" {
    Assert-True (-not (Test-Path (Join-Path $OsRoot 'commands'))) `
        "commands/ existe. Para plugin novo a documentacao manda usar skills/."
}

Test-Caso "cada SKILL.md tem frontmatter com name e description" {
    foreach ($nome in $SkillsEsperadas) {
        $txt = Get-Texto (Join-Path $OsRoot "skills\$nome\SKILL.md")
        Assert-True ($txt.StartsWith('---')) "$nome : nao comeca com frontmatter"
        $fm = ($txt -split '(?m)^---\s*$')[1]
        Assert-True ($fm -match '(?m)^name:\s*\S')        "$nome : frontmatter sem 'name'"
        Assert-True ($fm -match '(?m)^description:\s*\S') "$nome : frontmatter sem 'description'"
    }
}

Test-Caso "o 'name' do frontmatter bate com o nome da pasta (define /os:<nome>)" {
    # Se divergirem, o comando invocavel nao e o que a documentacao promete.
    foreach ($nome in $SkillsEsperadas) {
        $txt = Get-Texto (Join-Path $OsRoot "skills\$nome\SKILL.md")
        $fm = ($txt -split '(?m)^---\s*$')[1]
        $declarado = ([regex]::Match($fm, '(?m)^name:\s*(.+?)\s*$')).Groups[1].Value
        Assert-True ($declarado -eq $nome) "pasta '$nome' declara name '$declarado'"
    }
}

Test-Caso "description diz QUANDO usar, nao apenas o que a skill faz" {
    # Uma description sem gatilho e a causa numero um de skill que nunca dispara.
    foreach ($nome in $SkillsEsperadas) {
        $txt = Get-Texto (Join-Path $OsRoot "skills\$nome\SKILL.md")
        $fm = ($txt -split '(?m)^---\s*$')[1]
        $desc = ([regex]::Match($fm, '(?ms)^description:\s*(.+?)(?=^\w+:|\z)')).Groups[1].Value
        Assert-True ($desc.Length -ge 80) "$nome : description curta demais ($($desc.Length) chars)"
        Assert-True ($desc -match '(?i)\buse\b')    "$nome : description nao diz quando usar"
        Assert-True ($desc -match '(?i)/os:')        "$nome : description nao cita o comando /os:$nome"
    }
}

Test-Caso "cada skill declara seus anti-falsos-positivos" {
    # Convencao desta plataforma: dizer quando NAO agir vale tanto quanto o procedimento.
    foreach ($nome in $SkillsEsperadas) {
        $txt = Get-Texto (Join-Path $OsRoot "skills\$nome\SKILL.md")
        Assert-True ($txt -match '(?i)anti-falsos-positivos') "$nome : sem secao de anti-falsos-positivos"
    }
}

Test-Caso "a skill checkpoint reafirma a regra de ouro do commit" {
    # Se esta skill esquecer isso, ela passa a commitar por conta propria.
    $txt = Get-Texto (Join-Path $OsRoot 'skills\checkpoint\SKILL.md')
    Assert-True ($txt -match '(?i)explicit') "checkpoint: nao exige pedido explicito"
    Assert-True ($txt -match '(?i)git add \.') "checkpoint: nao proibe 'git add .'"
}

Test-Caso "todo placeholder do template esta documentado na skill new-project" {
    # A causa do bug: a skill listava globs (*.md, *.yaml, *.ps1) que nao
    # pegavam dotfiles, e {{PROJECT_TITLE}} sobreviveu em .env.example e
    # .gitignore. Agora a skill precisa citar cada placeholder que existe.
    $skill = Get-Texto (Join-Path $OsRoot 'skills\new-project\SKILL.md')
    $usados = @{}
    Get-ChildItem $Template -Recurse -File -Force |
        Where-Object { $_.Name -ne '.gitkeep' } |
        ForEach-Object {
            foreach ($m in [regex]::Matches((Get-Texto $_.FullName), '\{\{[A-Z_]+\}\}')) {
                $usados[$m.Value] = $true
            }
        }
    Assert-True ($usados.Count -ge 10) "achei so $($usados.Count) placeholders no template"
    $ausentes = $usados.Keys | Where-Object { $skill -notmatch [regex]::Escape($_) }
    Assert-True ($ausentes.Count -eq 0) ("placeholders nao documentados na skill: " + ($ausentes -join ', '))
}

Test-Caso "a skill new-project proibe filtrar por extensao na substituicao" {
    $txt = Get-Texto (Join-Path $OsRoot 'skills\new-project\SKILL.md')
    Assert-True ($txt -match '(?i)dotfiles') "a skill nao menciona dotfiles"
    Assert-True ($txt -match "grep -rn '\{\{'") "a skill nao manda verificar placeholder restante"
}

Test-Caso "a skill checkpoint manda atualizar o project.yaml, nao so o STATE" {
    # /os:status e /os:handoff leem do project.yaml. Se o checkpoint nao o
    # atualiza, ele passa a mentir - foi o achado mais grave da Fase 1.
    $txt = Get-Texto (Join-Path $OsRoot 'skills\checkpoint\SKILL.md')
    Assert-True ($txt -match 'project\.yaml') "checkpoint nao menciona project.yaml"
    Assert-True ($txt -match 'ultimo_checkpoint') "checkpoint nao menciona estado.ultimo_checkpoint"
}

# =============================================================================
# SKILLS LOCAIS DO REPOSITORIO - .claude/skills/
#
# Sao coisa diferente das skills do plugin: estas valem SO neste repositorio e
# sao invocadas sem namespace ('/session-start'), enquanto as de 'skills/' sao
# o produto distribuido e saem como '/os:<nome>'. Por isso a lista e descoberta
# separadamente e nao entra em $SkillsEsperadas - se entrasse, os testes acima
# cobrariam '/os:' numa description que nunca tera '/os:'.
#
# Descoberta do DISCO pelo mesmo motivo da lista de cima: skill local nova
# entra nestas regras sem ninguem lembrar de acrescentar.
# =============================================================================

$SkillsLocais = @()
$DirSkillsLocais = Join-Path $OsRoot '.claude\skills'
if (Test-Path $DirSkillsLocais -PathType Container) {
    $SkillsLocais = @(Get-ChildItem $DirSkillsLocais -Directory | ForEach-Object { $_.Name } | Sort-Object)
}

Test-Caso "o protocolo de sessao existe como skill local, e nao por vacuidade" {
    # Sem esta pre-condicao, os casos abaixo iterariam zero vezes e passariam
    # verdes sobre nada - que e exatamente como cinco testes desta suite
    # passaram a nao verificar coisa nenhuma na subfase 2.0.
    Assert-True ($SkillsLocais.Count -ge 2) "esperava pelo menos 2 skills locais, achei $($SkillsLocais.Count)"
    foreach ($exigida in @('session-start', 'session-close')) {
        Assert-True ($SkillsLocais -contains $exigida) "skill local ausente: $exigida"
    }
}

Test-Caso "skill local: cada uma e <nome>/SKILL.md com frontmatter coerente" {
    foreach ($nome in $SkillsLocais) {
        $p = Join-Path $DirSkillsLocais "$nome\SKILL.md"
        Assert-True (Test-Path $p -PathType Leaf) "ausente: .claude\skills\$nome\SKILL.md"
        $txt = Get-Texto $p
        Assert-True ($txt.StartsWith('---')) "$nome : nao comeca com frontmatter"
        $fm = ($txt -split '(?m)^---\s*$')[1]
        Assert-True ($fm -match '(?m)^name:\s*\S')        "$nome : frontmatter sem 'name'"
        Assert-True ($fm -match '(?m)^description:\s*\S') "$nome : frontmatter sem 'description'"
        $declarado = ([regex]::Match($fm, '(?m)^name:\s*(.+?)\s*$')).Groups[1].Value
        # O nome define o comando invocavel: divergir dele e prometer um
        # comando que nao existe.
        Assert-True ($declarado -eq $nome) "pasta '$nome' declara name '$declarado'"
        Assert-True ($txt -match '(?i)anti-falsos-positivos') "$nome : sem secao de anti-falsos-positivos"
    }
}

Test-Caso "session-start e READ-ONLY por MECANISMO, nao por prosa" {
    # A skill promete nao alterar arquivo nenhum. Promessa em prosa nao tem
    # detector - foi a licao que custou uma rodada inteira na subfase 2.5.
    # O frontmatter REMOVE as ferramentas de escrita do turno, e e isso que
    # este caso pina: se alguem tirar a linha, a garantia some em silencio.
    $txt = Get-Texto (Join-Path $DirSkillsLocais 'session-start\SKILL.md')
    $fm = ($txt -split '(?m)^---\s*$')[1]
    $m = [regex]::Match($fm, '(?m)^disallowed-tools:\s*(.+?)\s*$')
    Assert-True ($m.Success) "session-start nao declara 'disallowed-tools'"
    foreach ($ferramenta in @('Edit', 'Write', 'NotebookEdit')) {
        Assert-True ($m.Groups[1].Value -match ('\b' + $ferramenta + '\b')) `
            "session-start nao remove '$ferramenta': a promessa de read-only fica so na prosa"
    }
}

Test-Caso "as duas skills de sessao nao disparam sozinhas" {
    # '/session-close' disparado por conta propria no meio do trabalho
    # encerraria a sessao sem pedido; '/session-start' competiria com o
    # gatilho em linguagem natural que ja pertence a /os:resume.
    foreach ($nome in @('session-start', 'session-close')) {
        $txt = Get-Texto (Join-Path $DirSkillsLocais "$nome\SKILL.md")
        $fm = ($txt -split '(?m)^---\s*$')[1]
        Assert-True ($fm -match '(?m)^disable-model-invocation:\s*true') `
            "$nome : nao desliga a invocacao automatica"
    }
}

Test-Caso "session-close NAO promete commit automatico" {
    # A regra de ouro deste repositorio: commit so a pedido explicito. Uma
    # skill de encerramento que commitasse por rotina a violaria toda sessao.
    #
    # As ancoras sao SEM ACENTO de proposito: este arquivo e .ps1, e o
    # PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI - um 'a' com til aqui
    # vira mojibake e o padrao deixa de casar com o texto que ele procura.
    # A primeira versao deste caso falhou exatamente assim.
    $txt = Get-Texto (Join-Path $DirSkillsLocais 'session-close\SKILL.md')
    Assert-True ($txt -match '(?i)implica commit') "session-close nao diz que encerrar NAO implica commit"
    Assert-True ($txt -match '(?i)regra de ouro')  "session-close nao reafirma a regra de ouro do commit"
    Assert-True ($txt -match 'os:checkpoint')      "session-close nao aponta /os:checkpoint como o caminho do commit"
}

Test-Caso "skill local: todo arquivo do repositorio que ela cita EXISTE" {
    # Caminho quebrado dentro de skill e pior que ausencia: a skill manda ler
    # um arquivo que nao esta la, e quem segue a instrucao conclui que o
    # repositorio esta incompleto.
    $quebrados = @()
    foreach ($nome in $SkillsLocais) {
        $txt = Get-Texto (Join-Path $DirSkillsLocais "$nome\SKILL.md")
        foreach ($m in [regex]::Matches($txt, '`((?:docs|scripts|tests|skills|agents|templates)/[A-Za-z0-9_./-]+)`')) {
            $rel = $m.Groups[1].Value
            # Diretorio citado com barra no fim, ou arquivo.
            $alvo = Join-Path $OsRoot ($rel -replace '/', '\')
            if (-not (Test-Path $alvo)) { $quebrados += "$nome -> $rel" }
        }
    }
    Assert-True ($quebrados.Count -eq 0) ("caminho citado que nao existe: " + ($quebrados -join ', '))
}
