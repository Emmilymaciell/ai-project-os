<#
.SYNOPSIS
    Suite de testes: Politica de verificacao.

.DESCRIPTION
    A politica so vale se for consultada. Estes testes garantem que ela existe,
    que diz o que precisa dizer, que esta ligada a quem depende dela, e que
    ninguem duplicou a tabela em outro lugar - copia divergiria em silencio.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite policy

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite policy"
}

$Politica = Join-Path $OsRoot 'docs\VERIFICATION-POLICY.md'
$Adr7     = Join-Path $OsRoot 'docs\decisions\ADR-0007-builder-diferente-de-evaluator.md'

Test-Caso "a politica de verificacao existe e define o que conta como verificado" {
    Assert-True (Test-Path $Politica) "docs\VERIFICATION-POLICY.md nao existe"
    $txt = Get-Texto $Politica
    # A definicao e o coracao do documento: sem ela o resto e so tabela.
    Assert-True ($txt -match '(?i)executado e observado') `
        "a politica nao define verificado como executado e observado"
}

Test-Caso "a politica cobre natureza->tipo e criticidade->rigor" {
    $txt = Get-Texto $Politica
    foreach ($nat in @('tests/', 'evals/', 'integration test', 'security check')) {
        Assert-True ($txt -match [regex]::Escape($nat)) "politica nao menciona: $nat"
    }
    foreach ($crit in @('baixa', 'media', 'alta')) {
        Assert-True ($txt -match "\*\*$crit\*\*") "politica nao trata criticidade $crit"
    }
}

Test-Caso "a politica exige teste negativo em todo detector" {
    # Foi a licao mais cara da Fase 1: detector que nunca acusou nao foi testado.
    $txt = Get-Texto $Politica
    Assert-True ($txt -match '(?i)positivo') "politica nao exige teste positivo de detector"
    Assert-True ($txt -match '(?i)negativo') "politica nao exige teste negativo de detector"
}

Test-Caso "a politica exige verificacao em clone limpo antes de handoff ou release" {
    $txt = Get-Texto $Politica
    Assert-True ($txt -match '(?i)clone limpo') "politica nao exige verificacao em clone limpo"
}

Test-Caso "ADR-0007 existe, esta aceito e define a linha por criticidade" {
    Assert-True (Test-Path $Adr7) "ADR-0007 nao existe"
    $txt = Get-Texto $Adr7
    Assert-True ($txt -match '(?i)\*\*Status:\*\*\s*Aceita') "ADR-0007 nao esta Aceita"
    foreach ($v in @('nenhuma', 'qa', 'alta', 'dados_sensiveis')) {
        Assert-True ($txt -match [regex]::Escape($v)) "ADR-0007 nao menciona: $v"
    }
    # Sem contexto isolado o mecanismo nao funciona; e o instrumento, nao um detalhe.
    Assert-True ($txt -match '(?i)contexto isolado') "ADR-0007 nao define contexto isolado"
}

Test-Caso "a politica nao ficou orfa: template e skills apontam para ela" {
    # Politica que ninguem consulta e documentacao decorativa.
    $consumidores = @(
        'templates\project-standard\CLAUDE.md',
        'templates\project-standard\project.yaml',
        'skills\new-project\SKILL.md',
        'skills\checkpoint\SKILL.md',
        'docs\ARCHITECTURE.md'
    )
    foreach ($c in $consumidores) {
        $txt = Get-Texto (Join-Path $OsRoot $c)
        Assert-True ($txt -match 'VERIFICATION-POLICY') "$c nao referencia a politica"
    }
}

Test-Caso "as skills que decidem rigor referenciam o ADR-0007" {
    foreach ($s in @('skills\new-project\SKILL.md', 'skills\checkpoint\SKILL.md')) {
        $txt = Get-Texto (Join-Path $OsRoot $s)
        Assert-True ($txt -match 'ADR-0007') "$s nao referencia o ADR-0007"
    }
}

Test-Caso "a matriz criticidade->revisao aparece igual na politica, no ADR e no template" {
    # O modo de falha real nao e a tabela faltar: e ela existir em tres lugares
    # e divergir. Este teste compara os tres mapeamentos.
    $fontes = @{
        'politica' = Get-Texto $Politica
        'adr'      = Get-Texto $Adr7
        'template' = Get-Texto (Join-Path $OsRoot 'templates\project-standard\project.yaml')
    }
    foreach ($nome in $fontes.Keys) {
        $txt = $fontes[$nome]
        Assert-True ($txt -match '(?i)baixa') "$nome nao cita criticidade baixa"
        Assert-True ($txt -match '(?i)media') "$nome nao cita criticidade media"
        Assert-True ($txt -match '(?i)alta')  "$nome nao cita criticidade alta"
    }
    # O template declara os tres valores possiveis do campo derivado.
    $tpl = $fontes['template']
    foreach ($v in @('nenhuma', 'qa', 'security')) {
        Assert-True ($tpl -match [regex]::Escape($v)) "project.yaml nao documenta o valor '$v'"
    }
}

Test-Caso "a skill new-project nao duplicou a tabela da politica" {
    # Antes da 2.1 a skill trazia a propria copia da tabela natureza->tipo.
    # Duas copias divergem; a skill agora aponta para a fonte.
    $txt = Get-Texto (Join-Path $OsRoot 'skills\new-project\SKILL.md')
    $linhasDeTabela = ([regex]::Matches($txt, '(?m)^\| (tem c.digo|tem sa.da|depende de servi.o)')).Count
    Assert-True ($linhasDeTabela -eq 0) `
        "a skill new-project ainda tem $linhasDeTabela linha(s) da tabela que agora vive na politica"
}

Test-Caso "REVISAO_INDEPENDENTE e um placeholder de verdade do template" {
    # Se o campo existe mas ninguem o substitui, ele nasce mentindo.
    $tpl = Get-Texto (Join-Path $OsRoot 'templates\project-standard\project.yaml')
    Assert-True ($tpl -match '\{\{REVISAO_INDEPENDENTE\}\}') "project.yaml nao usa o placeholder"
    $skill = Get-Texto (Join-Path $OsRoot 'skills\new-project\SKILL.md')
    Assert-True ($skill -match 'revisao_independente') `
        "a skill new-project nao sabe preencher revisao_independente"
}
