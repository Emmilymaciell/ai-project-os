<#
    Suite: infraestrutura de testes POR PROJETO (subfase 2.4).

    O que se prova aqui e diferente do que as outras suites provam. As outras
    verificam a plataforma; esta verifica o que a plataforma ENTREGA aos
    projetos governados - e verifica rodando, num projeto recem-instanciado,
    nao lendo o template.

    A distincao importa porque o defeito que esta subfase existe para corrigir
    era exatamente desse tipo: o template declarava ter verificacao e entregava
    uma pasta com .gitkeep dentro, e a skill documentava um placeholder
    ({{TEST_CMD}}) que nao existia em lugar nenhum do template. Nenhum teste
    pegava nem um nem outro, porque nenhum teste instanciava e rodava.

    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Rode pelo tests\run-tests.ps1 da plataforma."
}

# CONVENCAO desta suite: as suites-fixture escritas em here-string tem o
# Test-Caso INDENTADO. O teste "a contagem de testes declarada no STATE bate
# com o disco" conta linhas que comecam com 'Test-Caso ' na coluna 0; uma
# fixture nao indentada entra na contagem da plataforma sem nunca ser
# executada por ela, e o numero do STATE passa a nao bater com nada. Foi o
# que aconteceu na primeira execucao desta suite.

$TemplateTests = Join-Path $Template 'tests'

# =============================================================================
# 1. O template entrega uma pasta de verificacao que verifica
# =============================================================================

Test-Caso "template: tests/ nao e mais pasta vazia com .gitkeep" {
    Assert-True (-not (Test-Path (Join-Path $TemplateTests '.gitkeep'))) `
        "tests/.gitkeep continua no template: pasta de verificacao vazia nao conta (politica 4.4)"

    foreach ($f in @('run-tests.ps1', 'README.md', 'conftest.py', 'test_smoke.py', '_harness.ps1', 'suites\smoke.ps1')) {
        Assert-True (Test-Path (Join-Path $TemplateTests $f) -PathType Leaf) `
            "template nao traz tests\$f"
    }
}

Test-Caso "template: o README de tests declara o que NAO e coberto" {
    # Politica 4.7. Sem isto, suite verde passa a impressao de escopo completo.
    $txt = Get-Texto (Join-Path $TemplateTests 'README.md')
    # Padrao sem acento de proposito: este .ps1 e ASCII puro (o 5.1 le UTF-8
    # sem BOM como ANSI), entao um 'NAO' acentuado no padrao vira mojibake e
    # nunca casa. O '.' cobre o caractere acentuado do arquivo lido.
    Assert-True ($txt -match 'N.O cobrem') "o README de tests nao tem secao do que nao e coberto"
    foreach ($tema in @('evals', 'integra', 'clone limpo', 'dado sens')) {
        Assert-True ($txt -match $tema) "o README de tests nao declara a lacuna: $tema"
    }
}

Test-Caso "template: o manifesto declara comando, criterio de pronto e limites" {
    $txt = Get-Texto (Join-Path $Template 'project.yaml')
    Assert-True ($txt -match "(?m)^\s+comando:\s*'\.\\tests\\run-tests\.ps1'") `
        "project.yaml do template nao declara verificacao.comando com o comando canonico"
    Assert-True ($txt -match '(?m)^\s+criterio_de_pronto:') "sem verificacao.criterio_de_pronto"
    Assert-True ($txt -match '(?m)^\s+limites:') "sem verificacao.limites"
}

Test-Caso "template: o comando de teste NAO esta duplicado em forma longa" {
    # O defeito medido no conversor-utm: o caminho do python do .venv copiado
    # em CLAUDE.md e README.md, divergindo dos dois lados.
    foreach ($f in @('CLAUDE.md', 'README.md')) {
        $txt = Get-Texto (Join-Path $Template $f)
        Assert-True ($txt -notmatch '\.venv\\Scripts\\python\.exe -m pytest') `
            "$f do template repete o comando longo do pytest em vez de apontar para run-tests.ps1"
    }
}

# =============================================================================
# 2. Placeholder: as DUAS direcoes
# =============================================================================
# A direcao template -> skill ja tinha teste. A direcao skill -> template nao
# tinha, e foi por ali que {{TEST_CMD}} apodreceu: documentado no passo 6 da
# skill new-project, ausente do template, portanto nunca substituido e nunca
# executado.

Test-Caso "placeholder: todo placeholder citado na skill EXISTE no template" {
    $skill = Get-Texto (Join-Path $OsRoot 'skills\new-project\SKILL.md')
    $noTemplate = @{}
    Get-ChildItem $Template -Recurse -File -Force | ForEach-Object {
        $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        foreach ($m in [regex]::Matches($t, '\{\{[A-Z_]+\}\}')) { $noTemplate[$m.Value] = $true }
    }

    # Na skill, placeholder citado dentro de tabela de valores ou em passo de
    # instrucao. Exemplos genericos como {{...}} nao casam com o padrao.
    $citados = @{}
    foreach ($m in [regex]::Matches($skill, '\{\{[A-Z_]+\}\}')) { $citados[$m.Value] = $true }
    Assert-True ($citados.Count -gt 0) "nenhum placeholder citado na skill: o teste ficaria vacuo"

    $orfaos = @($citados.Keys | Where-Object { -not $noTemplate.ContainsKey($_) })
    Assert-True ($orfaos.Count -eq 0) `
        ("a skill cita placeholder que o template nao tem: " + ($orfaos -join ', ') + ". Placeholder documentado e inexistente nunca e substituido nem executado.")
}

# =============================================================================
# 3. O runner, rodando em projeto recem-instanciado
# =============================================================================

Test-Caso "instancia: trilha PowerShell roda e passa, com casos de verdade" {
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $r = Invoke-RunnerDoProjeto -Projeto $proj
        Assert-True ($r.Codigo -eq 0) "esperava saida 0, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'passou: [1-9]') `
            "a suite nao executou caso nenhum - verde por vacuidade. Saida: $($r.Saida)"
        Assert-True ($r.Saida -notmatch '\[FAIL\]') "algum caso falhou. Saida: $($r.Saida)"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "instancia: nenhuma suite sai com 2 e cita a politica, nao com 0" {
    # O caso que separa "nao verificado" de "passou". Runner que nao acha
    # suite e sai com 0 esta afirmando aprovacao sobre nada (politica 4.5).
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'nenhuma'
    try {
        $r = Invoke-RunnerDoProjeto -Projeto $proj
        Assert-True ($r.Codigo -eq 2) "esperava saida 2, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'NAO RODOU') "a saida nao diz que a suite nao rodou"
        Assert-True ($r.Saida -match '4\.4') "a saida nao aponta a politica que foi violada"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "instancia: as DUAS trilhas ao mesmo tempo faz o runner RECUSAR" {
    # Instanciacao incompleta. Escolher uma em silencio esconderia metade dos
    # testes, e o projeto pareceria verde com uma trilha inteira nao executada.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'ambas'
    try {
        $r = Invoke-RunnerDoProjeto -Projeto $proj
        Assert-True ($r.Codigo -eq 2) "esperava saida 2, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'DUAS trilhas') "a saida nao explica a ambiguidade"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "instancia: trilha Python sem .venv sai com 2 e manda rodar o bootstrap" {
    # Cair para o python global daria ModuleNotFoundError de pytest, que parece
    # defeito do projeto e nao falta de ambiente. Medido na Fase 1.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'python'
    try {
        $r = Invoke-RunnerDoProjeto -Projeto $proj
        Assert-True ($r.Codigo -eq 2) "esperava saida 2, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match '\.venv') "a saida nao diz que o problema e o .venv"
        Assert-True ($r.Saida -match 'bootstrap') "a saida nao diz como resolver"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "instancia: suite que carrega e nao executa caso nenhum sai com 2" {
    # Verde por vacuidade e o defeito mais barato que existe: foreach sobre
    # lista vazia passa. Na 2.3 havia cinco testes assim na plataforma.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        Remove-Item (Join-Path $proj 'tests\suites\smoke.ps1') -Force
        Set-Content (Join-Path $proj 'tests\suites\vazia.ps1') `
            '# suite sem nenhum Test-Caso' -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $proj
        Assert-True ($r.Codigo -eq 2) "esperava saida 2, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'nenhum caso') "a saida nao nomeia o problema"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "instancia: -List lista a suite e sai com 0 sem rodar nada" {
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $r = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-List')
        Assert-True ($r.Codigo -eq 0) "esperava saida 0, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'smoke') "-List nao mostrou a suite smoke"
        Assert-True ($r.Saida -notmatch '\[PASS\]') "-List executou casos, e nao deveria"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "instancia: codigo em scripts/ sem suite propria REPROVA (politica 4.4)" {
    # Projeto novo passa porque nao ha codigo. No minuto em que entra o
    # primeiro script, a pasta tests/ para de poder ser decoracao.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $antes = Invoke-RunnerDoProjeto -Projeto $proj
        Assert-True ($antes.Codigo -eq 0) "projeto sem codigo deveria passar, veio $($antes.Codigo)"

        Set-Content (Join-Path $proj 'scripts\converter.ps1') 'function Convert-Algo { 1 }' -Encoding ASCII
        $depois = Invoke-RunnerDoProjeto -Projeto $proj
        Assert-True ($depois.Codigo -eq 1) `
            "codigo sem teste deveria reprovar, veio $($depois.Codigo). Saida: $($depois.Saida)"
        Assert-True ($depois.Saida -match '4\.4') "a falha nao aponta a politica"
    } finally { Remove-ProjetoDeTeste $proj }
}

# =============================================================================
# 4. Criterio de aceite lido do manifesto - o defeito do conversor-utm
# =============================================================================
# No conversor-utm o criterio "dentro de 1 metro" existia em tres lugares -
# prosa do README, docstring do teste, e um 1.0 cravado na assercao - e em
# nenhum era fonte de verdade. Aqui o numero mora no manifesto, e estes casos
# provam que ele e LIDO de la, nao que ele existe la.

function Set-LimiteNoManifesto {
    param([string]$Projeto, [string]$Bloco)
    $arq = Join-Path $Projeto 'project.yaml'
    $txt = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8)
    $txt = $txt.Replace('  limites: {}', $Bloco)
    [System.IO.File]::WriteAllText($arq, $txt, (New-Object System.Text.UTF8Encoding($false)))
}

Test-Caso "manifesto: o limite lido pelo teste vem do project.yaml, e muda com ele" {
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        Set-LimiteNoManifesto -Projeto $proj -Bloco "  limites:`n    erro_maximo_m: 1.0"

        # Suite que ASSERTA contra o limite declarado. Se o harness devolvesse
        # padrao em vez de ler, este caso passaria com qualquer numero - por
        # isso o segundo trecho, que troca o manifesto e espera o oposto.
        $suite = @'
    Test-Caso "erro medido cabe no limite declarado" {
    $lim = Get-LimiteDoManifesto 'erro_maximo_m'
    Assert-True ($lim -eq 1.0) "esperava 1.0 do manifesto, veio $lim"
    Assert-True (0.4 -lt $lim) "0.4 deveria caber em $lim"
}
'@
        Set-Content (Join-Path $proj 'tests\suites\criterio.ps1') $suite -Encoding ASCII
        $r1 = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'criterio')
        Assert-True ($r1.Codigo -eq 0) "com limite 1.0 deveria passar. Saida: $($r1.Saida)"

        # Mesmo teste, manifesto apertado: o valor tem de vir de la.
        $arq = Join-Path $proj 'project.yaml'
        $txt = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($arq, $txt.Replace('erro_maximo_m: 1.0', 'erro_maximo_m: 0.2'), (New-Object System.Text.UTF8Encoding($false)))
        $r2 = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'criterio')
        Assert-True ($r2.Codigo -eq 1) `
            "trocar o manifesto nao mudou o resultado: o limite nao esta sendo lido de la. Saida: $($r2.Saida)"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "manifesto: limite AUSENTE faz o teste falhar, nunca passar" {
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        # limites: {} - nada declarado.
        $suite = @'
    Test-Caso "asserta contra limite que ninguem declarou" {
    $lim = Get-LimiteDoManifesto 'erro_maximo_m'
    Assert-True (0.4 -lt $lim) "0.4 deveria caber em $lim"
}
'@
        Set-Content (Join-Path $proj 'tests\suites\ausente.ps1') $suite -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'ausente')
        Assert-True ($r.Codigo -eq 1) `
            "limite ausente deveria reprovar, veio $($r.Codigo). Padrao silencioso transforma 'nao declarou' em 'passou'. Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'nao declara') "a falha nao diz que o manifesto nao declara o limite"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "manifesto: 1.0 le como UM, nao como DEZ - cultura pt-BR" {
    # Regressao de um defeito real, achado pelo teste acima quando ele exigiu
    # o valor exato. Esta maquina roda em pt-BR, onde o separador decimal e a
    # virgula: [double]::TryParse('1.0') pela cultura ATUAL le o ponto como
    # separador de milhar e devolve 10. Uma tolerancia de 1 metro declarada no
    # manifesto passava a valer 10 metros, e nenhum teste ficava vermelho - a
    # assercao apenas comparava contra o numero errado. A correcao e
    # InvariantCulture no harness do template.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        Set-LimiteNoManifesto -Projeto $proj -Bloco "  limites:`n    erro_maximo_m: 1.0"
        $suite = @"
    Test-Caso "1.0 do manifesto vale UM" {
    `$lim = Get-LimiteDoManifesto 'erro_maximo_m'
    Assert-True (`$lim -eq 1.0) "leu `$lim - se veio 10, a cultura do sistema comeu o ponto decimal"
    Assert-True (5.0 -gt `$lim) "5 nao deveria caber num limite de 1"
}
"@
        Set-Content (Join-Path $proj 'tests\suites\locale.ps1') $suite -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'locale')
        Assert-True ($r.Codigo -eq 0) "1.0 nao foi lido como um. Saida: $($r.Saida)"
    } finally { Remove-ProjetoDeTeste $proj }
}
Test-Caso "manifesto: placeholder nao substituido LANCA em vez de virar valor" {
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell' `
                               -Valores @{ '{{CRITERIO_PRONTO}}' = '{{CRITERIO_PRONTO}}' }
    try {
        $suite = @'
    Test-Caso "le o criterio de pronto" {
    $c = Get-CampoDoManifesto 'verificacao.criterio_de_pronto'
    Assert-True (-not [string]::IsNullOrWhiteSpace($c)) "criterio vazio"
}
'@
        Set-Content (Join-Path $proj 'tests\suites\criterio.ps1') $suite -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'criterio')
        Assert-True ($r.Codigo -eq 1) "placeholder deveria reprovar, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'placeholder') "a falha nao nomeia o placeholder"
    } finally { Remove-ProjetoDeTeste $proj }
}

# =============================================================================
# 5. Trilha Python, com ambiente de verdade
# =============================================================================
# O .venv e criado UMA vez para todos os casos desta secao (custa ~20 s e
# rede). A versao anterior punha seis cenarios dentro de um Test-Caso so, e o
# qa-reviewer apontou o preco: como Assert-True lanca, a primeira falha
# abortava os cinco restantes e o relatorio mostrava 1 caso - a contagem
# informava menos do que o esforco gasto.
#
# Se o preparo falhar (sem rede, sem o interpretador), os casos NAO passam
# nem reprovam em silencio: cada um falha dizendo que NAO FOI POSSIVEL
# VERIFICAR. O PyPI esta declarado no project.yaml da plataforma, em
# ambiente.dependencias_externas.

$ProjPy = $null
$PrepPyErro = $null
$PyVersao = $null
try {
    $anteriorPrep = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # Nao fixar 3.13: numa maquina que so tenha 3.12 o caso reprovava sem que
    # nada estivesse quebrado. Usa o que existe, e declara qual usou.
    $listaPy = ((& py -0 2>&1) -join "`n")
    foreach ($v in @('3.13', '3.12', '3.11')) {
        if ($listaPy -match [regex]::Escape($v)) { $PyVersao = $v; break }
    }
    $ErrorActionPreference = $anteriorPrep
    if (-not $PyVersao) { throw "nenhum Python 3.11-3.13 no launcher 'py'" }

    $ProjPy = New-ProjetoDeTeste -Template $Template -Trilha 'python' -Valores @{ '{{PYTHON}}' = $PyVersao }
    $ErrorActionPreference = 'Continue'
    & py "-$PyVersao" -m venv (Join-Path $ProjPy '.venv') 2>&1 | Out-Null
    $pyExe = Join-Path $ProjPy '.venv\Scripts\python.exe'
    if (-not (Test-Path $pyExe -PathType Leaf)) { throw "nao criou o .venv com py -$PyVersao" }
    & $pyExe -m pip install --quiet --disable-pip-version-check -r (Join-Path $ProjPy 'requirements.txt') 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "pip install falhou - o PyPI e dependencia externa declarada; sem rede este bloco nao e verificavel" }
    $ErrorActionPreference = $anteriorPrep
} catch {
    $PrepPyErro = $_.Exception.Message
    $ErrorActionPreference = 'Stop'
}

function Assert-TrilhaPythonPronta {
    if ($PrepPyErro) {
        throw ("NAO FOI POSSIVEL VERIFICAR a trilha Python: " + $PrepPyErro +
               ". Isto nao e o mesmo que o codigo estar errado.")
    }
}

Test-Caso "Python: projeto recem-instanciado passa a suite de fumaca" {
    Assert-TrilhaPythonPronta
    $r = Invoke-RunnerDoProjeto -Projeto $ProjPy
    Assert-True ($r.Codigo -eq 0) "smoke deveria passar. Saida: $($r.Saida)"
    Assert-True ($r.Saida -match 'passed') "pytest nao reportou teste passando. Saida: $($r.Saida)"
}

Test-Caso "Python: limite AUSENTE reprova, e o mesmo teste passa quando declarado" {
    Assert-TrilhaPythonPronta
    # O manifesto e COMPARTILHADO pelos casos desta secao (o .venv custa 20 s
    # e rede, entao o projeto e um so). Quem mexe nele restaura: sem isto o
    # caso seguinte tenta substituir um texto que ja mudou, a substituicao
    # vira no-op, e o caso passa sem exercitar o ramo. Aconteceu.
    $manifOrig = [System.IO.File]::ReadAllText((Join-Path $ProjPy 'project.yaml'), [System.Text.Encoding]::UTF8)
    Set-Content (Join-Path $ProjPy 'tests\test_criterio.py') "def test_limite_vem_do_manifesto(limite):`n    assert limite('erro_maximo_m') == 1.0`n" -Encoding ASCII
    try {
        $r1 = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r1.Codigo -eq 1) "limite ausente deveria reprovar, veio $($r1.Codigo). Saida: $($r1.Saida)"
        Assert-True ($r1.Saida -match 'nao declara') "a falha nao diz que o manifesto nao declara o limite"

        Set-LimiteNoManifesto -Projeto $ProjPy -Bloco "  limites:`n    erro_maximo_m: 1.0"
        $r2 = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r2.Codigo -eq 0) "com o limite declarado deveria passar. Saida: $($r2.Saida)"
    } finally {
        Remove-Item (Join-Path $ProjPy 'tests\test_criterio.py') -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText((Join-Path $ProjPy 'project.yaml'), $manifOrig, (New-Object System.Text.UTF8Encoding($false)))
    }
}

Test-Caso "Python: scripts/ e importavel sem sys.path.insert em cada arquivo" {
    Assert-TrilhaPythonPronta
    # calc.py e removido no finally. A versao anterior o deixava no disco, e
    # isso criava acoplamento de ordem: com codigo em scripts/ e sem teste
    # proprio, o test_smoke.py reprova pela politica 4.4 - entao o caso
    # "projeto recem-instanciado passa a suite de fumaca" so passava porque
    # rodava ANTES deste, e nada declarava nem impunha essa ordem. Achado do
    # qa-reviewer, e a segunda dependencia de ordem desta secao.
    Set-Content (Join-Path $ProjPy 'scripts\calc.py') 'def dobro(x): return 2 * x' -Encoding ASCII
    Set-Content (Join-Path $ProjPy 'tests\test_import.py') "from calc import dobro`n`ndef test_importa_sem_boilerplate():`n    assert dobro(21) == 42`n" -Encoding ASCII
    try {
        $r = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r.Codigo -eq 0) "import de scripts/ falhou. Saida: $($r.Saida)"
    } finally {
        Remove-Item (Join-Path $ProjPy 'tests\test_import.py') -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $ProjPy 'scripts\calc.py') -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "Python: codigo em scripts/ sem teste proprio REPROVA (politica 4.4)" {
    Assert-TrilhaPythonPronta
    # Cria e REMOVE: nao depende de sobra de caso anterior nem deixa sobra
    # para o proximo. E confere o par positivo antes, para nao passar por
    # engano num projeto que ja estivesse reprovando por outro motivo.
    Set-Content (Join-Path $ProjPy 'scripts\calc.py') 'def dobro(x): return 2 * x' -Encoding ASCII
    try {
        $r = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r.Codigo -eq 1) "codigo sem teste proprio deveria reprovar, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match '4\.4') "a falha nao aponta a politica"
    } finally {
        Remove-Item (Join-Path $ProjPy 'scripts\calc.py') -Force -ErrorAction SilentlyContinue
    }
    # E sem o codigo, o mesmo projeto volta a passar - prova que foi o codigo
    # que reprovou, nao um estado herdado.
    $depois = Invoke-RunnerDoProjeto -Projeto $ProjPy
    Assert-True ($depois.Codigo -eq 0) `
        "sem codigo em scripts/ o projeto deveria voltar a passar, veio $($depois.Codigo). Saida: $($depois.Saida)"
}

Test-Caso "Python: pytest que nao coleta nada sai com 2, nao com 0 nem com 1" {
    # A guarda de vacuidade da trilha Python nao tinha teste, e a equivalente
    # PowerShell tinha. Dado o historico de cinco testes verdes por vacuidade
    # na 2.3, era a lacuna mais desconfortavel da lista do qa-reviewer.
    Assert-TrilhaPythonPronta
    $tmpGuarda = Join-Path $ProjPy 'guardados'
    New-Item -ItemType Directory -Force $tmpGuarda | Out-Null
    try {
        foreach ($g in @(Get-ChildItem (Join-Path $ProjPy 'tests') -Filter 'test_*.py' -File)) {
            Move-Item $g.FullName (Join-Path $tmpGuarda $g.Name) -Force
        }
        # Nome que o pytest coleta, e nenhuma funcao de teste dentro: a suite
        # existe, o pytest roda, e coleta zero.
        Set-Content (Join-Path $ProjPy 'tests\test_vazio.py') '# nenhuma funcao test_*' -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r.Codigo -eq 2) "esperava saida 2, veio $($r.Codigo). Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'nao coletou') "a saida nao nomeia o problema"
    } finally {
        Remove-Item (Join-Path $ProjPy 'tests\test_vazio.py') -Force -ErrorAction SilentlyContinue
        foreach ($g in @(Get-ChildItem $tmpGuarda -File -ErrorAction SilentlyContinue)) {
            Move-Item $g.FullName (Join-Path $ProjPy ('tests\' + $g.Name)) -Force
        }
        Remove-Item $tmpGuarda -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "Python: conftest com erro de coleta sai com 2 - nao rodou, nao falhou" {
    # Codigo 4 do pytest (erro de USO, tipicamente falha de coleta) caia no
    # exit 1 e virava "a suite rodou e falhou". Achado do qa-reviewer: o
    # contrato declarado em quatro lugares diz que 2 e "nao rodou", e apagar a
    # distincao apaga a razao de existir desta subfase.
    Assert-TrilhaPythonPronta
    $conf = Join-Path $ProjPy 'tests\conftest.py'
    $original = [System.IO.File]::ReadAllText($conf, [System.Text.Encoding]::UTF8)
    try {
        [System.IO.File]::WriteAllText($conf, ($original + "`nsintaxe ((( invalida de proposito`n"), (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r.Codigo -eq 2) "erro de coleta deveria dar 2 (nao rodou), veio $($r.Codigo). Saida: $($r.Saida)"
    } finally {
        [System.IO.File]::WriteAllText($conf, $original, (New-Object System.Text.UTF8Encoding($false)))
    }
}

Test-Caso "Python: leitor recusa bloco IRMAO e campo declarado VAZIO" {
    # Dois dos modos de falha ABERTA que os revisores acharam no leitor de
    # manifesto. O gemeo PowerShell tem o caso espelhado logo abaixo: os dois
    # leitores tem de recusar as MESMAS coisas, senao projeto Python e projeto
    # PowerShell ficam com rigor diferente sobre o mesmo manifesto.
    Assert-TrilhaPythonPronta
    $manif = Join-Path $ProjPy 'project.yaml'
    $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)
    try {
        # (a) 'limites' existe, mas dentro de OUTRO bloco.
        #
        # O manifesto e CONSTRUIDO, nao remendado por substituicao de texto:
        # a versao anterior deste caso dependia de achar '  limites: {}', que
        # um caso anterior desta mesma secao ja tinha alterado. A substituicao
        # virou no-op e o caso passou sem exercitar o ramo - verde por
        # vacuidade, a classe de defeito que esta subfase existe para nao
        # repetir. Agora a condicao e conferida antes de ser exigida.
        Set-Content (Join-Path $ProjPy 'tests\test_leitor.py') "def test_limite(limite):`n    assert limite('erro_maximo_m') > 0`n" -Encoding ASCII
        $semLimites = ($original -split "`r?`n" | Where-Object { $_ -notmatch '^\s+limites:' -and $_ -notmatch '^\s+erro_maximo_m:' }) -join "`n"
        $comIrmao = $semLimites + "`noutro_bloco:`n  limites:`n    erro_maximo_m: 99`n"
        # A checagem e sobre $semLimites, nao sobre $comIrmao: um padrao
        # '^verificacao:[\s\S]*?^\s+limites:' casaria o 'limites' do bloco
        # IRMAO tambem, porque ele vem depois no arquivo - o guarda-corpo
        # acusaria a propria fixture correta.
        Assert-True ($semLimites -notmatch '(?m)^\s+limites:') `
            "a fixture deixou 'limites' dentro de verificacao: o caso nao exercitaria o ramo"
        Assert-True ($comIrmao -match '(?m)^outro_bloco:') "a fixture nao criou o bloco irmao"
        [System.IO.File]::WriteAllText($manif, $comIrmao, (New-Object System.Text.UTF8Encoding($false)))
        $r1 = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r1.Codigo -eq 1) `
            "o leitor aceitou 'limites' de outro bloco como se fosse de verificacao. Saida: $($r1.Saida)"
        Assert-True ($r1.Saida -match 'nao declara') "a falha nao diz que o campo nao esta declarado"

        # (b) campo declarado e VAZIO nao e campo declarado.
        Set-Content (Join-Path $ProjPy 'tests\test_leitor.py') "def test_criterio(criterio_de_pronto):`n    assert len(criterio_de_pronto) > 10`n" -Encoding ASCII
        $comVazio = $original.Replace('criterio_de_pronto: "a instancia roda a propria suite e ela passa"', 'criterio_de_pronto: ""')
        Assert-True ($comVazio -ne $original) "a fixture nao conseguiu esvaziar o criterio: o caso nao exercitaria o ramo"
        [System.IO.File]::WriteAllText($manif, $comVazio, (New-Object System.Text.UTF8Encoding($false)))
        $r2 = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r2.Codigo -eq 1) "criterio declarado VAZIO deveria reprovar, veio $($r2.Codigo). Saida: $($r2.Saida)"
        Assert-True ($r2.Saida -match 'VAZIO') "a falha nao diz que o campo esta vazio"
    } finally {
        [System.IO.File]::WriteAllText($manif, $original, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_leitor.py') -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "Python: a suite de fumaca traz o par NEGATIVO do leitor (politica 4.1)" {
    # Todo projeto PowerShell nascia com teste negativo do detector e todo
    # projeto Python nascia sem - rigor diferente conforme a linguagem.
    $txt = Get-Texto (Join-Path $TemplateTests 'test_smoke.py')
    Assert-True ($txt -match 'campo_inexistente_no_manifesto_FALHA') `
        "test_smoke.py nao tem o par negativo do leitor de manifesto"
}

Test-Caso "as duas trilhas exigem a MESMA lista de extensoes de codigo" {
    # Divergir aqui faz a politica 4.4 valer conforme a linguagem do harness,
    # nao conforme o codigo: um scripts/analise.R nao exigiria teste num
    # projeto PowerShell, e um scripts/util.psm1 nao exigiria num Python.
    # Le a LISTA, nao o arquivo inteiro. A versao anterior extraia toda
    # string com cara de extensao dos dois arquivos: quebraria por engano no
    # dia em que alguem escrevesse '.venv' numa mensagem, e - pior - poderia
    # PASSAR com as listas divergentes, se a extensao removida da tupla
    # sobrevivesse entre aspas numa docstring. Achado do qa-reviewer.
    $py = Get-Texto (Join-Path $TemplateTests 'test_smoke.py')
    $ps = Get-Texto (Join-Path $TemplateTests 'suites\smoke.ps1')

    $mPy = [regex]::Match($py, 'EXTENSOES_DE_CODIGO\s*=\s*\(([^)]*)\)')
    Assert-True $mPy.Success "nao achei a tupla EXTENSOES_DE_CODIGO no test_smoke.py"
    $extPy = @([regex]::Matches($mPy.Groups[1].Value, '"(\.[a-z0-9]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

    $mPs = [regex]::Match($ps, '\$_\.Extension\s+-in\s+@\(([^)]*)\)')
    Assert-True $mPs.Success "nao achei a lista de extensoes no smoke.ps1"
    $extPs = @([regex]::Matches($mPs.Groups[1].Value, "'(\.[a-z0-9]+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

    Assert-True ($extPy.Count -gt 3) "a tupla EXTENSOES_DE_CODIGO veio com menos de 4 itens"
    Assert-True ($extPs.Count -eq $extPy.Count) `
        ("as listas tem tamanhos diferentes: Python " + $extPy.Count + ", PowerShell " + $extPs.Count)
    foreach ($e in $extPy) {
        Assert-True ($extPs -contains $e) "a trilha PowerShell nao exige teste para '$e', e a Python exige"
    }
    foreach ($e in $extPs) {
        Assert-True ($extPy -contains $e) "a trilha Python nao exige teste para '$e', e a PowerShell exige"
    }
}

Test-Caso "PowerShell: leitor recusa bloco IRMAO e escalar de bloco" {
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $manif = Join-Path $proj 'project.yaml'
        $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)

        # (a) 'limites' dentro de OUTRO bloco nao conta como declarado.
        Set-Content (Join-Path $proj 'tests\suites\leitor.ps1') `
            "    Test-Caso `"le o limite`" {`n        `$lim = Get-LimiteDoManifesto 'erro_maximo_m'`n        Assert-True (`$lim -gt 0) `"limite invalido: `$lim`"`n    }`n" -Encoding ASCII
        $comIrmao = $original.Replace("  limites: {}", "outro_bloco:`n  limites:`n    erro_maximo_m: 99")
        Assert-True ($comIrmao -ne $original) "a fixture nao conseguiu mover 'limites': o caso nao exercitaria o ramo"
        [System.IO.File]::WriteAllText($manif, $comIrmao, (New-Object System.Text.UTF8Encoding($false)))
        $r1 = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'leitor')
        Assert-True ($r1.Codigo -eq 1) `
            "o leitor aceitou 'limites' de outro bloco: devolveu 99 como se fosse de verificacao. Saida: $($r1.Saida)"
        Assert-True ($r1.Saida -match 'terminou|nao declara') "a falha nao explica que o bloco terminou"

        # (b) escalar de bloco RECUSADO, em vez de devolver '>' como valor.
        Set-Content (Join-Path $proj 'tests\suites\leitor.ps1') `
            "    Test-Caso `"le o criterio`" {`n        `$c = Get-CampoDoManifesto 'verificacao.criterio_de_pronto'`n        Assert-True (`$c.Length -gt 10) `"criterio curto: '`$c'`"`n    }`n" -Encoding ASCII
        $comEscalar = $original.Replace('criterio_de_pronto: "a instancia roda a propria suite e ela passa"', "criterio_de_pronto: >`n    uma frase que continua na linha seguinte")
        Assert-True ($comEscalar -ne $original) "a fixture nao conseguiu por o escalar de bloco"
        [System.IO.File]::WriteAllText($manif, $comEscalar, (New-Object System.Text.UTF8Encoding($false)))
        $r2 = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'leitor')
        Assert-True ($r2.Codigo -eq 1) "escalar de bloco passou batido, veio $($r2.Codigo). Saida: $($r2.Saida)"
        Assert-True ($r2.Saida -match 'escalar de bloco') "a falha nao nomeia o escalar de bloco"
    } finally { Remove-ProjetoDeTeste $proj }
}

# =============================================================================
# 6. O bootstrap RODA a suite - nao apenas confere que a pasta existe
# =============================================================================

Test-Caso "bootstrap: roda a suite do projeto e reporta o resultado" {
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        Assert-True ($saida -match '(?m)^Testes') "o bootstrap nao tem secao de testes"
        Assert-True ($saida -match 'a suite rodou e passou') `
            "o bootstrap nao rodou a suite. Comando de teste documentado e nunca executado foi a lacuna da Fase 1. Saida: $saida"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "bootstrap: manifesto diz tests true e a suite nao roda - isso BLOQUEIA" {
    # Declaracao nao e verificacao. Este e o caso que o /os:doctor da 2.5 vai
    # generalizar; aqui ele custa uma linha e pega o mais comum.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'nenhuma' -Valores @{ '{{TEM_TESTS}}' = 'true' }
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        $codigo = $LASTEXITCODE
        Assert-True ($saida -match 'BLOQUEIA') "o bootstrap nao bloqueou. Saida: $saida"
        Assert-True ($saida -match 'Declaracao nao e verificacao') "o bootstrap nao explica o que esta errado"
        Assert-True ($codigo -eq 1) "esperava saida 1 do bootstrap, veio $codigo"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "bootstrap: sem suite e SEM declarar tests, avisa e nao bloqueia" {
    # O par negativo do caso acima. Sem ele, um bootstrap que bloqueasse
    # sempre passaria pelo teste anterior e travaria todo projeto sem teste.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'nenhuma' -Valores @{ '{{TEM_TESTS}}' = 'false' }
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        $codigo = $LASTEXITCODE
        Assert-True ($saida -match 'atencao') "esperava aviso. Saida: $saida"
        # Conferir o CODIGO, nao uma string: o caso irmao exige 1, e este se
        # contentava com -notmatch de uma frase. Salvava-se porque -match e
        # case-insensitive e pegava a mutacao obvia, mas qualquer outra fonte
        # de bloqueio passava despercebida. Achado do qa-reviewer.
        Assert-True ($codigo -eq 0) "bloqueou um projeto que nao declara tests (saida $codigo). Saida: $saida"
        Assert-True ($saida -notmatch 'BLOQUEIA') "reportou bloqueio num projeto que nao declara tests. Saida: $saida"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "bootstrap: run-tests.ps1 AUSENTE com tests true no manifesto BLOQUEIA" {
    # Ramo nao exercitado, apontado pelo qa-reviewer: nenhum teste apagava o
    # runner. Declarar verificacao que nao existe e a mentira que o /os:doctor
    # da 2.5 vai generalizar.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell' -Valores @{ '{{TEM_TESTS}}' = 'true' }
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Remove-Item (Join-Path $proj 'tests\run-tests.ps1') -Force
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        $codigo = $LASTEXITCODE
        Assert-True ($saida -match 'declarado no manifesto') "o bootstrap nao acusou o runner ausente. Saida: $saida"
        Assert-True ($codigo -eq 1) "esperava saida 1, veio $codigo"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "bootstrap: run-tests.ps1 ausente SEM declarar tests apenas avisa" {
    # O par negativo do caso acima. Sem ele, um bootstrap que bloqueasse
    # sempre passaria pelo caso anterior e travaria todo projeto sem teste.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'nenhuma' -Valores @{ '{{TEM_TESTS}}' = 'false' }
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Remove-Item (Join-Path $proj 'tests\run-tests.ps1') -Force
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        $codigo = $LASTEXITCODE
        Assert-True ($saida -match 'sem suite de testes') "esperava aviso de suite ausente. Saida: $saida"
        Assert-True ($codigo -eq 0) "projeto que nao declara tests nao deveria bloquear, veio $codigo"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "bootstrap: suite que FALHA aparece como problema e bloqueia" {
    # Terceiro ramo nao exercitado: nenhum teste fazia a suite reprovar sob o
    # bootstrap.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Set-Content (Join-Path $proj 'tests\suites\quebrada.ps1') `
            "    Test-Caso `"caso que reprova de proposito`" { Assert-True `$false `"reprovei`" }`n" -Encoding ASCII
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        $codigo = $LASTEXITCODE
        Assert-True ($saida -match 'a suite rodou e falhou') "o bootstrap nao reportou a suite reprovando. Saida: $saida"
        Assert-True ($codigo -eq 1) "esperava saida 1, veio $codigo"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "bootstrap: erro de SINTAXE na suite nao mata o bootstrap antes do resumo" {
    # Achado do qa-reviewer, e a classe que o runbook diz ter corrigido: o
    # '2>&1' trazia o ParserError do filho para o pipeline do pai e, sob
    # ErrorActionPreference=Stop, virava NativeCommandError terminante - o
    # bootstrap abortava ANTES do '=== resumo ===', sem [FALTA] e sem lista de
    # problemas, com uma mensagem sobre 'powershell :'. O diagnostico que o
    # bootstrap existe para dar nao saia. A protecao existia no harness de
    # teste da plataforma e nao no arquivo entregue.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        Set-Content (Join-Path $proj 'tests\suites\sintaxe.ps1') `
            "    Test-Caso `"aberta` { esta chave nunca fecha`n" -Encoding ASCII
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        Assert-True ($saida -match 'resumo') `
            "o bootstrap abortou antes do resumo por causa de erro de sintaxe na suite. Saida: $saida"
        Assert-True ($saida -match 'BLOQUEIA|FALTA') `
            "o bootstrap chegou ao resumo mas nao reportou problema nenhum. Saida: $saida"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "plataforma: o runner raiz tambem recusa sair com 0 sem executar caso" {
    # A regua que a 2.4 impos aos projetos governados valia para eles e nao
    # para a plataforma. Achado do qa-reviewer. Aqui a prova e por execucao:
    # uma copia do runner e das suites, com uma suite vazia so.
    $tmp = Join-Path (Get-Item $env:TEMP).FullName ("os-runner-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        New-Item -ItemType Directory -Force (Join-Path $tmp 'tests\suites') | Out-Null
        Copy-Item (Join-Path $OsRoot 'tests\run-tests.ps1') (Join-Path $tmp 'tests\run-tests.ps1')
        Copy-Item (Join-Path $OsRoot 'tests\_harness.ps1')  (Join-Path $tmp 'tests\_harness.ps1')
        Set-Content (Join-Path $tmp 'tests\suites\vazia.ps1') '# suite sem nenhum Test-Caso' -Encoding ASCII
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp 'tests\run-tests.ps1') -Suite vazia 2>&1 | Out-String
        $codigo = $LASTEXITCODE
        Assert-True ($codigo -eq 2) "o runner da plataforma saiu com $codigo em vez de 2. Saida: $saida"
        Assert-True ($saida -match 'NAO RODOU') "a saida nao diz que a suite nao rodou"
    } finally {
        $ErrorActionPreference = $anterior
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "instanciacao: substituicao alcanca arquivo de texto de extensao DESCONHECIDA" {
    # O harness afirmava "nao filtra por extensao" e filtrava por uma
    # allowlist de 13 extensoes - afirmacao falsa, achada pelo qa-reviewer.
    # Hoje cobria o template por acidente; 'pyproject.toml' ou 'Makefile'
    # seriam pulados EM SILENCIO. E o teste que se apresenta como o fluxo real
    # da skill nao seria o fluxo real da skill.
    $tmpTpl = Join-Path (Get-Item $env:TEMP).FullName ("os-tpl-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        Copy-Item $Template $tmpTpl -Recurse -Force
        # Extensao que a allowlist antiga nao tinha, e um arquivo sem extensao.
        Set-Content (Join-Path $tmpTpl 'pyproject.toml') 'name = "{{PROJECT_NAME}}"' -Encoding ASCII
        Set-Content (Join-Path $tmpTpl 'Makefile') 'all: ; @echo {{PROJECT_TITLE}}' -Encoding ASCII
        # E um BINARIO, que NAO pode ser reescrito como texto.
        $bin = [byte[]]@(0x50, 0x4B, 0x03, 0x04, 0x00, 0x01, 0x02, 0x00)
        [System.IO.File]::WriteAllBytes((Join-Path $tmpTpl 'planilha.xlsx'), $bin)

        $proj = New-ProjetoDeTeste -Template $tmpTpl -Trilha 'powershell'
        try {
            $toml = Get-Texto (Join-Path $proj 'pyproject.toml')
            Assert-True ($toml -notmatch '\{\{') "placeholder sobreviveu em pyproject.toml: a substituicao filtrou por extensao"
            $mk = Get-Texto (Join-Path $proj 'Makefile')
            Assert-True ($mk -notmatch '\{\{') "placeholder sobreviveu em Makefile (arquivo sem extensao)"
            $depois = [System.IO.File]::ReadAllBytes((Join-Path $proj 'planilha.xlsx'))
            Assert-True ($depois.Length -eq $bin.Length) "o binario foi reescrito: comparar por conteudo tem de excluir binario"
            Assert-True ($depois[0] -eq 0x50 -and $depois[4] -eq 0x00) "o binario foi corrompido pela substituicao"
        } finally { Remove-ProjetoDeTeste $proj }
    } finally {
        if (Test-Path $tmpTpl) { Remove-Item $tmpTpl -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "relatorio: a linha Gerador traz a contagem REAL e nomeia os seis detectores" {
    # A correcao do rotulo literal 'subfase 2.3' saiu QUEBRADA na primeira
    # tentativa, e nenhum dos 225 casos tocava essa linha: o relatorio passou
    # a dizer '(1 linhas) + 0 detectores', contradizendo o proprio carimbo no
    # mesmo arquivo. Tres defeitos numa linha - Join-Path sem separador, e
    # Measure-Linhas recebendo caminho em vez de conteudo, duas vezes.
    # Os dois revisores acharam; este caso e o que os dois pediram nominalmente.
    $tmpOut = Join-Path (Get-Item $env:TEMP).FullName ("os-prov-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + ".md")
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $OsRoot 'scripts\security-scan.ps1') `
            -Path $OsRoot -Out $tmpOut -SemHistorico -SemRede 2>&1 | Out-Null
        $ErrorActionPreference = $anterior
        Assert-True (Test-Path $tmpOut -PathType Leaf) "o scanner nao gerou relatorio"

        $rel = Get-Texto $tmpOut
        $m = [regex]::Match($rel, '(?m)^- Gerador: .*?\((\d+) linhas\) \+ (\d+) detectores: (.*)$')
        Assert-True $m.Success "o relatorio nao tem a linha Gerador na forma esperada"

        $linhasDeclaradas = [int]$m.Groups[1].Value
        # Parenteses em volta do Get-Texto: sem eles o PowerShell entrega o
        # resultado do -split como ARGUMENTO da funcao, e a contagem sai 1.
        # Foi este mesmo caso que denunciou - a assercao exigia o valor exato.
        $linhasReais = (((Get-Texto (Join-Path $OsRoot 'scripts\security-scan.ps1'))) -split "`r?`n").Count
        # Tolera 1 de diferenca pela convencao de contagem (fim de linha final).
        Assert-True ([Math]::Abs($linhasDeclaradas - $linhasReais) -le 1) `
            "a linha Gerador declara $linhasDeclaradas linhas e o arquivo tem $linhasReais - o numero nao vem do arquivo"
        Assert-True ($linhasDeclaradas -gt 100) `
            "declarou $linhasDeclaradas linhas: e o valor constante que aparece quando se passa CAMINHO para uma funcao que espera CONTEUDO"

        Assert-True ([int]$m.Groups[2].Value -eq 6) `
            ("declarou " + $m.Groups[2].Value + " detectores, e sao 6. Zero era o Join-Path sem separador")
        foreach ($det in @('comum', 'historico', 'gitignore', 'dado-pessoal', 'exposicao', 'excecoes')) {
            Assert-True ($m.Groups[3].Value -match ([regex]::Escape($det) + ':\d+')) `
                "a linha Gerador nao nomeia o detector '$det' com a contagem dele"
        }
    } finally {
        $ErrorActionPreference = $anterior
        if (Test-Path $tmpOut) { Remove-Item $tmpOut -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "leitor: chave com HIFEN nao deixa a busca cair no bloco errado" {
    # Segunda porta do mesmo fail-open, achada pelos DOIS revisores na segunda
    # rodada: a versao anterior descartava em silencio toda linha cuja chave a
    # regex nao reconhecia - hifen, aspas, digito inicial - e a linha
    # descartada nunca encerrava o bloco da mae. Um 'dados-extra:' no caminho
    # deixava a chave seguinte casar no nivel errado, e
    # 'verificacao.limites.erro_maximo_m' devolvia o valor de outro bloco.
    #
    # O caso anterior usava 'outro_bloco', que PASSAVA pela regex - por isso
    # exercitava o ramo do aninhamento e nao alcancava este.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $manif = Join-Path $proj 'project.yaml'
        $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)
        $semLimites = ($original -split "`r?`n" | Where-Object { $_ -notmatch '^\s+limites:' }) -join "`n"
        Assert-True ($semLimites -notmatch '(?m)^\s+limites:') "a fixture nao removeu 'limites' de verificacao"
        $comHifen = $semLimites + "`ndados-extra:`n  limites:`n    erro_maximo_m: 99`n"

        [System.IO.File]::WriteAllText($manif, $comHifen, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $proj 'tests\suites\hifen.ps1') `
            "    Test-Caso `"le o limite`" {`n        `$lim = Get-LimiteDoManifesto 'erro_maximo_m'`n        Assert-True (`$lim -gt 0) `"limite `$lim`"`n    }`n" -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'hifen')
        Assert-True ($r.Codigo -eq 1) `
            "o leitor devolveu o limite de 'dados-extra' como se fosse de 'verificacao'. Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'nao declara') "a falha nao diz que o campo nao esta declarado"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "leitor PowerShell: LISTA no manifesto nao impede ler OUTRO campo" {
    # O achado que mais importava dos dois revisores nesta rodada, porque
    # recusava manifesto VALIDO: o gemeo Python levantava excecao em lista em
    # QUALQUER posicao do arquivo, derrubando a suite inteira; o PowerShell
    # lancava se a lista viesse ANTES do campo procurado. E lista nao e
    # exotica - o project.yaml da PROPRIA PLATAFORMA tem
    # 'ambiente.dependencias_externas' como lista, e o ADR-0010 manda
    # preencher 'dados_sensiveis_excecoes' com entradas de lista.
    #
    # Regra dos dois agora: lista e escalar de bloco viram valor REGISTRADO
    # como nao legivel. Pedir a chave da lista falha; pedir outra funciona.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $manif = Join-Path $proj 'project.yaml'
        $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)
        # Lista ANTES do bloco verificacao, como o schema do template convida.
        $comLista = $original.Replace('  dados_sensiveis_excecoes: []',
            "  dados_sensiveis_excecoes:`n    - caminho: `"docs/x.md`"`n    - caminho: `"docs/y.md`"")
        Assert-True ($comLista -ne $original) "a fixture nao conseguiu inserir a lista"
        $comLista = $comLista.Replace('  limites: {}', "  limites:`n    erro_maximo_m: 2.5")
        [System.IO.File]::WriteAllText($manif, $comLista, (New-Object System.Text.UTF8Encoding($false)))

        Set-Content (Join-Path $proj 'tests\suites\lista.ps1') `
            "    Test-Caso `"le limite com lista no manifesto`" {`n        `$lim = Get-LimiteDoManifesto 'erro_maximo_m'`n        Assert-True (`$lim -eq 2.5) `"esperava 2.5, veio `$lim`"`n    }`n" -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'lista')
        Assert-True ($r.Codigo -eq 0) `
            "lista no manifesto impediu ler um campo que nao e lista. Saida: $($r.Saida)"

        # E pedir A PROPRIA lista tem de falhar, dizendo o motivo.
        Set-Content (Join-Path $proj 'tests\suites\lista.ps1') `
            "    Test-Caso `"pede a lista`" {`n        `$v = Get-CampoDoManifesto 'classificacao.dados_sensiveis_excecoes'`n        Assert-True (`$v.Length -gt 0) `"veio '`$v'`"`n    }`n" -Encoding ASCII
        $r2 = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'lista')
        Assert-True ($r2.Codigo -eq 1) "pedir a lista deveria falhar, veio $($r2.Codigo). Saida: $($r2.Saida)"
        Assert-True ($r2.Saida -match 'lista') "a falha nao diz que o campo e lista"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "leitor PowerShell: o manifesto da PROPRIA PLATAFORMA e legivel" {
    # O teste mais direto contra a classe "o leitor recusa manifesto valido":
    # o project.yaml da plataforma tem lista, comentario de fim de linha,
    # bloco vazio e valor com barra invertida. Se o leitor novo nao consegue
    # ler ISSO, ele nao serve.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        Copy-Item (Join-Path $OsRoot 'project.yaml') (Join-Path $proj 'project.yaml') -Force
        Set-Content (Join-Path $proj 'tests\suites\real.ps1') `
            "    Test-Caso `"le campos do manifesto da plataforma`" {`n        Assert-True ((Get-CampoDoManifesto 'identidade.nome') -eq 'emmily-ai-project-os') `"nome errado`"`n        Assert-True ((Get-CampoDoManifesto 'classificacao.criticidade') -eq 'alta') `"criticidade errada`"`n        Assert-True ((Get-CampoDoManifesto 'verificacao.revisao_independente') -eq 'qa+security') `"revisao errada`"`n        Assert-True ((Get-CampoDoManifesto 'verificacao.comando') -match 'run-tests') `"comando errado`"`n    }`n" -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $proj -Argumentos @('-Suite', 'real')
        Assert-True ($r.Codigo -eq 0) `
            "o leitor nao consegue ler o manifesto da propria plataforma. Saida: $($r.Saida)"
    } finally { Remove-ProjetoDeTeste $proj }
}

Test-Caso "bootstrap: git que FALHA nao vira '[OK] nenhum .env versionado'" {
    # O achado mais grave da segunda rodada, do qa-reviewer: o Invoke-Git da
    # plataforma vive em scripts/lib/, que NAO e entregue, e o bootstrap tinha
    # tres 'git' soltos sob ErrorActionPreference=Stop. Com o indice
    # corrompido, 'ls-files' falhava, a lista de vazamentos ficava vazia e o
    # bootstrap imprimia [OK] nenhum .env ou chave versionada - afirmacao de
    # seguranca sobre um git que nao respondeu, dentro do UNICO check de
    # seguranca que um projeto governado roda sozinho.
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # Repositorio de verdade, depois quebrado: sem .git o bloco nao roda.
        & git -C $proj init -q 2>$null
        & git -C $proj config core.autocrlf false 2>$null
        Assert-True (Test-Path (Join-Path $proj '.git') -PathType Container) "a fixture nao criou o repositorio"
        [System.IO.File]::WriteAllText((Join-Path $proj '.git\index'), "indice corrompido`n", (New-Object System.Text.UTF8Encoding($false)))
        & git -C $proj ls-files 2>&1 | Out-Null
        Assert-True ($LASTEXITCODE -ne 0) "a fixture nao conseguiu quebrar o ls-files: o caso nao exercitaria o ramo"

        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-String
        $codigoBoot = $LASTEXITCODE
        Assert-True ($saida -match 'resumo') "o bootstrap nao chegou ao resumo. Saida: $saida"
        Assert-True ($saida -notmatch 'nenhum \.env ou chave versionada') `
            "o bootstrap AFIRMOU que nao ha arquivo sensivel versionado com o git sem responder. Saida: $saida"
        # Confere o CODIGO tambem, e exige a palavra que so aparece no
        # resumo de problemas. A versao anterior aceitava a mensagem do
        # Write-Item, que sai sem alimentar $problemas: apagar a linha
        # '$problemas += "NAO FOI POSSIVEL VERIFICAR..."' passaria pelo teste,
        # e a metade que BLOQUEIA nao estava provada. Achado do qa-reviewer.
        Assert-True ($saida -match 'NAO FOI POSSIVEL VERIFICAR') `
            "o bootstrap nao declarou que a verificacao nao aconteceu. Saida: $saida"
        Assert-True ($saida -match 'BLOQUEIA') `
            "o bootstrap declarou a lacuna mas nao a tratou como bloqueio. Saida: $saida"
        Assert-True ($codigoBoot -eq 1) `
            "esperava saida 1 do bootstrap, veio $codigoBoot"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "bootstrap: -Check declara que RODA a suite, e nao cria .venv nem .env" {
    # Regressao de contrato apontada pelo qa-reviewer: -Check estava
    # documentado como "nao cria nada" e passou a executar a suite do
    # PROJETO - que pode escrever em logs/ ou output/. O texto foi corrigido
    # em vez de a capacidade ser removida: rodar o teste e o unico jeito de
    # saber que o comando documentado funciona.
    $txt = Get-Texto (Join-Path $Template 'bootstrap.ps1')
    Assert-True ($txt -match '(?s)\.PARAMETER Check.*?RODA a suite') `
        "o bootstrap nao declara que -Check roda a suite do projeto"
    $proj = New-ProjetoDeTeste -Template $Template -Trilha 'powershell' -Valores @{ '{{PYTHON}}' = '3.13' }
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'bootstrap.ps1') -Check 2>&1 | Out-Null
        Assert-True (-not (Test-Path (Join-Path $proj '.venv'))) "-Check criou o .venv"
        Assert-True (-not (Test-Path (Join-Path $proj '.env'))) "-Check criou o .env"
    } finally {
        $ErrorActionPreference = $anterior
        Remove-ProjetoDeTeste $proj
    }
}

Test-Caso "Python: LISTA e ESCALAR DE BLOCO viram valor registrado, nao ignorado" {
    # Achado do qa-reviewer na rodada 3: a regra nova - lista e escalar de
    # bloco viram ValorNaoLegivel - estava verificada SO do lado PowerShell.
    # O project.yaml do template traz 'dados_sensiveis_excecoes: []' e
    # 'dependencias_externas: []' INLINE, sem nenhum item '- ', e os manifestos
    # que os outros casos Python plantavam tambem nao tinham lista nem escalar.
    # Em 231 casos verdes, ValorNaoLegivel e os dois ramos de _exigir nunca
    # eram executados: verde sobre codigo nao exercitado, terceira vez.
    Assert-TrilhaPythonPronta
    $manif = Join-Path $ProjPy 'project.yaml'
    $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)
    try {
        # Lista de VERDADE, no estilo que o ADR-0010 produz, ANTES do bloco
        # verificacao - e um escalar de bloco com indicador de indentacao,
        # que era a forma que escapava das seis reconhecidas.
        $com = $original.Replace('  dados_sensiveis_excecoes: []',
            "  dados_sensiveis_excecoes:`n    - caminho: `"docs/a.md`"`n      categoria: `"x`"`n    - caminho: `"docs/b.md`"`n      categoria: `"y`"")
        Assert-True ($com -ne $original) "a fixture nao inseriu a lista"
        $com = $com.Replace('  limites: {}', "  limites:`n    erro_maximo_m: 3.5")
        [System.IO.File]::WriteAllText($manif, $com, (New-Object System.Text.UTF8Encoding($false)))

        Set-Content (Join-Path $ProjPy 'tests\test_naolegivel.py') @'
import pytest
import conftest


def test_lista_nao_impede_ler_outro_campo(limite):
    # A lista vem ANTES de verificacao no arquivo. Se ela contaminasse a
    # leitura, este limite nao seria encontrado.
    assert limite("erro_maximo_m") == 3.5


def test_a_chave_da_lista_FALHA_dizendo_que_e_lista():
    m = conftest.ler_manifesto()
    with pytest.raises(BaseException) as e:
        conftest._exigir(m, "classificacao", "dados_sensiveis_excecoes")
    assert "lista" in str(e.value)


def test_chave_irma_DEPOIS_da_lista_continua_visivel():
    # A lista engolia as chaves irmas seguintes no estilo compacto. Aqui a
    # lista esta indentada, mas o par negativo importa: componente_llm vem
    # depois dela dentro do mesmo bloco.
    m = conftest.ler_manifesto()
    assert conftest._exigir(m, "classificacao", "componente_llm") == "false"
'@ -Encoding ASCII
        $r1 = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r1.Codigo -eq 0) `
            "o leitor Python nao trata lista como valor registrado. Saida: $($r1.Saida)"

        # Escalar de bloco COM indicador de indentacao: '|2' escapava das seis
        # formas reconhecidas, o indicador virava o valor, e as linhas de prosa
        # do bloco viravam chaves fabricadas no bloco pai.
        $comEscalar = $original.Replace('  criterio_de_pronto: "a instancia roda a propria suite e ela passa"',
            "  criterio_de_pronto: |2`n    uma frase de criterio`n    que continua aqui")
        Assert-True ($comEscalar -ne $original) "a fixture nao inseriu o escalar de bloco"
        [System.IO.File]::WriteAllText($manif, $comEscalar, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $ProjPy 'tests\test_naolegivel.py') @'
import pytest
import conftest


def test_escalar_de_bloco_com_indicador_e_recusado():
    m = conftest.ler_manifesto()
    with pytest.raises(BaseException) as e:
        conftest._exigir(m, "verificacao", "criterio_de_pronto")
    assert "escalar de bloco" in str(e.value)


def test_a_prosa_do_bloco_nao_vira_campo_fabricado():
    m = conftest.ler_manifesto()
    # 'uma frase de criterio' seria lida como chave se as continuacoes nao
    # fossem puladas. Nada com esse nome pode existir em verificacao.
    for chave in m.get("verificacao", {}):
        assert "frase" not in chave, f"campo fabricado: {chave}"
'@ -Encoding ASCII
        $r2 = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($r2.Codigo -eq 0) `
            "o leitor Python nao recusa escalar de bloco com indicador. Saida: $($r2.Saida)"
    } finally {
        [System.IO.File]::WriteAllText($manif, $original, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_naolegivel.py') -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "os DOIS gemeos devolvem o MESMO valor para o mesmo manifesto" {
    # Cinco divergencias entre os leitores apareceram ao longo da 2.4, e as
    # duas ultimas eram de VALOR, nao de aceite: '.Trim(''"'')' do PowerShell
    # removia TODAS as aspas das pontas sem exigir par, entao
    # 'roda no modo ''privado''' perdia a apostrofe final - e o gemeo Python
    # devolvia a frase inteira. E aspas em volta de um indicador ('">"')
    # divergiam porque um tirava as aspas antes de testar o indicador.
    #
    # Este caso compara os dois SOBRE A MESMA ENTRADA, que era o que nenhum
    # caso fazia. Achado do qa-reviewer.
    Assert-TrilhaPythonPronta
    $manif = Join-Path $ProjPy 'project.yaml'
    $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $entradas = @(
            @{ Nome = 'apostrofe interna';   Valor = '"roda no modo ''privado''"' },
            @{ Nome = 'indicador entre aspas'; Valor = '">"' },
            @{ Nome = 'chaves entre aspas';  Valor = '"{}"' },
            @{ Nome = 'dois pontos no valor'; Valor = '"antes: depois"' }
        )
        foreach ($e in $entradas) {
            $com = $original.Replace('  criterio_de_pronto: "a instancia roda a propria suite e ela passa"',
                                     ('  criterio_de_pronto: ' + $e.Valor))
            Assert-True ($com -ne $original) ("a fixture nao inseriu a entrada: " + $e.Nome)

            # --- lado Python: imprime o valor lido -------------------------
            [System.IO.File]::WriteAllText($manif, $com, (New-Object System.Text.UTF8Encoding($false)))
            # GRAVA em arquivo em vez de imprimir: 'pytest -q' nao mostra
            # print de teste que PASSA, e o caso lia a saida vazia. Canal de
            # evidencia que depende da verbosidade do runner nao e canal.
            $arqValor = Join-Path $ProjPy 'valor-lido.txt'
            Remove-Item $arqValor -Force -ErrorAction SilentlyContinue
            Set-Content (Join-Path $ProjPy 'tests\test_valor.py') @'
import pathlib

import conftest


def test_grava_o_valor():
    m = conftest.ler_manifesto()
    v = m.get("verificacao", {}).get("criterio_de_pronto")
    if isinstance(v, conftest.ValorNaoLegivel):
        texto = "NAOLEGIVEL"
    else:
        texto = str(v)
    destino = pathlib.Path(__file__).resolve().parents[1] / "valor-lido.txt"
    destino.write_text(texto, encoding="utf-8")
'@ -Encoding ASCII
            $rPy = Invoke-RunnerDoProjeto -Projeto $ProjPy -Argumentos @()
            Remove-Item (Join-Path $ProjPy 'tests\test_valor.py') -Force -ErrorAction SilentlyContinue
            Assert-True (Test-Path $arqValor -PathType Leaf) `
                ("a trilha Python nao gravou o valor para '" + $e.Nome + "'. Saida: " + $rPy.Saida)
            $vPy = Get-Texto $arqValor
            Remove-Item $arqValor -Force -ErrorAction SilentlyContinue

            # --- lado PowerShell: mesma entrada -----------------------------
            # GRAVA em arquivo, igual ao lado Python. A versao anterior
            # imprimia 'VALOR_LIDO<valor>' e o caso extraia por regex - o que
            # nao funciona quando o VALOR pode ser o proprio delimitador: a
            # entrada '">"' produzia 'VALOR_LIDO<>>' e o padrao nao-guloso
            # capturava vazio. O caso acusou divergencia que nao existia, e o
            # defeito era do proprio caso. Canal de evidencia que depende de
            # o valor nao colidir com o delimitador nao e canal.
            $arqValorPs = Join-Path $projPs 'valor-lido.txt'
            Remove-Item $arqValorPs -Force -ErrorAction SilentlyContinue
            [System.IO.File]::WriteAllText((Join-Path $projPs 'project.yaml'), $com, (New-Object System.Text.UTF8Encoding($false)))
            Set-Content (Join-Path $projPs 'tests\suites\valor.ps1') `
                "    Test-Caso `"grava o valor`" {`n        `$raiz = Read-ManifestoDoProjeto (Join-Path (Get-RaizDoProjeto) 'project.yaml')`n        `$v = `$raiz['verificacao']['criterio_de_pronto']`n        `$txt = if (`$v -is [pscustomobject]) { 'NAOLEGIVEL' } else { '' + `$v }`n        [System.IO.File]::WriteAllText((Join-Path (Get-RaizDoProjeto) 'valor-lido.txt'), `$txt, (New-Object System.Text.UTF8Encoding(`$false)))`n    }`n" -Encoding ASCII
            $rPs = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'valor')

            Assert-True (Test-Path $arqValorPs -PathType Leaf) `
                ("a trilha PowerShell nao gravou o valor para '" + $e.Nome + "'. Saida: " + $rPs.Saida)
            $vPs = Get-Texto $arqValorPs
            Remove-Item $arqValorPs -Force -ErrorAction SilentlyContinue

            # Comparacao ORDINAL: '-eq' entre strings no PowerShell e
            # case-insensitive, e aqui a diferenca de caixa e exatamente uma
            # das divergencias que se quer pegar.
            Assert-True ([string]::Equals($vPy, $vPs, [System.StringComparison]::Ordinal)) `
                ("divergencia em '" + $e.Nome + "': Python leu '" + $vPy + "' e PowerShell leu '" + $vPs + "'")
        }
    } finally {
        [System.IO.File]::WriteAllText($manif, $original, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_valor.py') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}

Test-Caso "leitor: sequencia COMPACTA nao engole a chave irma seguinte (as duas trilhas)" {
    # Estilo compacto do YAML - saida padrao do yaml.dump, e o estilo que o
    # ADR-0010 produz:
    #
    #     dados_sensiveis_excecoes:
    #     - caminho: "x"
    #     componente_llm: false
    #
    # O item esta no MESMO indent da chave, e os dois leitores pulavam tudo com
    # 'indent >= indentIgnoravel': o 'componente_llm' ia embora em SILENCIO.
    # O leitor lia meio manifesto sem dizer que leu meio. Achado dos dois
    # revisores na rodada 3.
    Assert-TrilhaPythonPronta
    $manif = Join-Path $ProjPy 'project.yaml'
    $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $com = $original.Replace('  dados_sensiveis_excecoes: []',
            "  dados_sensiveis_excecoes:`n  - caminho: `"docs/a.md`"`n  - caminho: `"docs/b.md`"")
        Assert-True ($com -ne $original) "a fixture nao inseriu a sequencia compacta"
        Assert-True ($com -match '(?m)^  - caminho:') "a sequencia nao ficou no estilo compacto"

        # --- Python -------------------------------------------------------
        [System.IO.File]::WriteAllText($manif, $com, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $ProjPy 'tests\test_compacta.py') @'
import conftest


def test_chave_irma_depois_da_sequencia_compacta_continua_visivel():
    m = conftest.ler_manifesto()
    assert conftest._exigir(m, "classificacao", "componente_llm") == "false"
'@ -Encoding ASCII
        $rPy = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($rPy.Codigo -eq 0) `
            "a trilha Python perdeu a chave irma depois da sequencia compacta. Saida: $($rPy.Saida)"

        # --- PowerShell ---------------------------------------------------
        [System.IO.File]::WriteAllText((Join-Path $projPs 'project.yaml'), $com, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $projPs 'tests\suites\compacta.ps1') `
            "    Test-Caso `"chave irma depois da sequencia compacta`" {`n        `$v = Get-CampoDoManifesto 'classificacao.componente_llm'`n        Assert-True (`$v -eq 'false') `"leu '`$v'`"`n    }`n" -Encoding ASCII
        $rPs = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'compacta')
        Assert-True ($rPs.Codigo -eq 0) `
            "a trilha PowerShell perdeu a chave irma depois da sequencia compacta. Saida: $($rPs.Saida)"
    } finally {
        [System.IO.File]::WriteAllText($manif, $original, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_compacta.py') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}

Test-Caso "leitor: chave e case-SENSITIVE nas duas trilhas" {
    # Hashtable do PowerShell e case-insensitive e dict do Python nao: um
    # manifesto com 'Verificacao:' capitalizado era lido pela trilha PowerShell
    # e falhava na Python, e duas chaves que diferiam so na caixa colapsavam em
    # silencio no PS. Achado do qa-reviewer.
    #
    # E este caso rodava SO a trilha PowerShell com nome de duas - quarta
    # aparicao da mesma classe, achada pelo qa-reviewer na rodada seguinte, no
    # caso que nasceu da correcao dela. Agora roda as duas de verdade.
    Assert-TrilhaPythonPronta
    $manifPy = Join-Path $ProjPy 'project.yaml'
    $origPy = [System.IO.File]::ReadAllText($manifPy, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        # --- trilha Python: 'Verificacao:' capitalizado NAO e 'verificacao' --
        $comPy = $origPy -replace '(?m)^verificacao:', 'Verificacao:'
        Assert-True ($comPy -cne $origPy) "a fixture nao capitalizou o bloco (Python)"
        [System.IO.File]::WriteAllText($manifPy, $comPy, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $ProjPy 'tests\test_caixa.py') "def test_criterio(criterio_de_pronto):`n    assert len(criterio_de_pronto) > 5`n" -Encoding ASCII
        $rPy = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($rPy.Codigo -eq 1) `
            "o leitor Python casou 'verificacao' com 'Verificacao:'. Saida: $($rPy.Saida)"
        Assert-True ($rPy.Saida -match 'nao declara') "a falha Python nao diz que o campo nao esta declarado"

        $manif = Join-Path $projPs 'project.yaml'
        $original = [System.IO.File]::ReadAllText($manif, [System.Text.Encoding]::UTF8)
        $com = $original -replace '(?m)^verificacao:', 'Verificacao:'
        # -cne, nao -ne: comparacao de string no PowerShell e
        # CASE-INSENSITIVE por padrao, entao 'Verificacao:' -ne 'verificacao:'
        # e FALSO e o guarda-corpo acusava a fixture de nao ter mudado nada.
        # Num caso cujo assunto e justamente a caixa, o operador errado
        # transforma o teste em nada.
        Assert-True ($com -cne $original) "a fixture nao capitalizou o bloco"
        Assert-True ($com -match '(?m)^Verificacao:') "a capitalizacao nao ficou no arquivo"
        [System.IO.File]::WriteAllText($manif, $com, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $projPs 'tests\suites\caixa.ps1') `
            "    Test-Caso `"le verificacao minuscula`" {`n        `$v = Get-CampoDoManifesto 'verificacao.comando'`n        Assert-True (`$v -match 'run-tests') `"leu '`$v'`"`n    }`n" -Encoding ASCII
        $r = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'caixa')
        Assert-True ($r.Codigo -eq 1) `
            "o leitor PowerShell casou 'verificacao' com 'Verificacao:'. Saida: $($r.Saida)"
        Assert-True ($r.Saida -match 'nao declara') "a falha nao diz que o campo nao esta declarado"
    } finally {
        [System.IO.File]::WriteAllText($manifPy, $origPy, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_caixa.py') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}

Test-Caso "leitor: valor que e SO comentario nao vira criterio (as duas trilhas)" {
    # 'criterio_de_pronto:  # preencher depois' e null em YAML, e os dois
    # gemeos devolviam a string '# preencher depois' como se fosse o criterio
    # de aceite - direcao proibida, afirmando criterio onde nao ha, no campo
    # que esta subfase existe para tornar fonte de verdade. Os DOIS erravam
    # igual, entao o caso de comparacao nao podia alcancar por construcao.
    # Achado do qa-reviewer.
    Assert-TrilhaPythonPronta
    $manifPy = Join-Path $ProjPy 'project.yaml'
    $origPy = [System.IO.File]::ReadAllText($manifPy, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $alvo = '  criterio_de_pronto: "a instancia roda a propria suite e ela passa"'
        $comComentario = '  criterio_de_pronto:  # preencher depois'

        # --- Python ------------------------------------------------------
        $comPy = $origPy.Replace($alvo, $comComentario)
        Assert-True ($comPy -cne $origPy) "a fixture nao trocou o criterio por comentario (Python)"
        [System.IO.File]::WriteAllText($manifPy, $comPy, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $ProjPy 'tests\test_comentario.py') "def test_criterio(criterio_de_pronto):`n    assert len(criterio_de_pronto) > 5`n" -Encoding ASCII
        $rPy = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($rPy.Codigo -eq 1) `
            "o leitor Python devolveu o comentario como criterio. Saida: $($rPy.Saida)"
        Assert-True ($rPy.Saida -match 'VAZIO|nao declara') "a falha Python nao diz que o campo esta vazio"

        # --- PowerShell --------------------------------------------------
        $manifPs = Join-Path $projPs 'project.yaml'
        $origPs = [System.IO.File]::ReadAllText($manifPs, [System.Text.Encoding]::UTF8)
        $comPs = $origPs.Replace($alvo, $comComentario)
        Assert-True ($comPs -cne $origPs) "a fixture nao trocou o criterio por comentario (PowerShell)"
        [System.IO.File]::WriteAllText($manifPs, $comPs, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $projPs 'tests\suites\comentario.ps1') `
            "    Test-Caso `"le o criterio`" {`n        `$c = Get-CampoDoManifesto 'verificacao.criterio_de_pronto'`n        Assert-True (`$c.Length -gt 5) `"leu '`$c'`"`n    }`n" -Encoding ASCII
        $rPs = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'comentario')
        Assert-True ($rPs.Codigo -eq 1) `
            "o leitor PowerShell devolveu o comentario como criterio. Saida: $($rPs.Saida)"
        Assert-True ($rPs.Saida -match 'VAZIO') "a falha PowerShell nao diz que o campo esta vazio"
    } finally {
        [System.IO.File]::WriteAllText($manifPy, $origPy, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_comentario.py') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}

# =============================================================================
# Limpeza do projeto compartilhado da trilha Python
# =============================================================================
# O $ProjPy tem .venv com pytest instalado - dezenas de MB - e nao tinha
# cleanup nenhum: cada execucao de run-tests.ps1 deixava um os-proj-XXXXXXXX
# no TEMP. Todo outro projeto de teste passa por Remove-ProjetoDeTeste num
# finally; este ficou de fora. Achado do qa-reviewer.
#
# Fica no FIM da suite de proposito: os casos da secao Python compartilham o
# projeto, e remover antes tiraria o chao deles.

Test-Caso "leitor: project.yaml com BOM e lido igual nas duas trilhas" {
    # SETIMA divergencia entre os gemeos, e a mais bem achada de todas:
    # _harness.ps1 usa File.ReadAllText(..., Encoding.UTF8), que CONSOME o BOM;
    # conftest.py usava read_text(encoding="utf-8"), que nao consome - e o
    # caractere U+FEFF nao e whitespace, entao nem .strip() nem .lstrip() o
    # removem.
    #
    # Consequencia tracada pelo qa-reviewer: com BOM, a linha 1 do manifesto
    # ('# Preenchido por /os:new-project...') deixa de ser reconhecida como
    # comentario, contem ':' e vira CHAVE-LIXO na raiz. Um leitor cujo contrato
    # e "o que nao entende, recusa" aceitando comentario como dado.
    #
    # E o PowerShell 5.1 'Out-File -Encoding UTF8' SEMPRE grava BOM, assim como
    # o Bloco de Notas - entao o manifesto com BOM nao e hipotese exotica: e o
    # que acontece quando alguem edita o project.yaml fora do editor certo.
    #
    # Por que nenhum caso pegava: TODAS as fixtures gravam com
    # UTF8Encoding($false). O teste gerava o arquivo pelo proprio codigo e
    # nunca via o artefato real - o mesmo padrao do defeito de encoding da
    # Fase 1.
    Assert-TrilhaPythonPronta
    $manifPy = Join-Path $ProjPy 'project.yaml'
    $origPy = [System.IO.File]::ReadAllText($manifPy, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        # COM BOM: UTF8Encoding($true).
        $comBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($manifPy, $origPy, $comBom)
        $bytes = [System.IO.File]::ReadAllBytes($manifPy)
        Assert-True ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) `
            "a fixture nao gravou o BOM: o caso passaria sem exercitar o ramo"

        Set-Content (Join-Path $ProjPy 'tests\test_bom.py') @'
import conftest


def test_o_bom_nao_vira_chave_lixo():
    m = conftest.ler_manifesto()
    # Nenhuma chave da raiz pode conter o BOM nem comecar por '#'.
    for chave in m:
        assert chr(0xFEFF) not in chave, f"BOM virou parte da chave: {chave!r}"
        assert not chave.startswith("#"), f"comentario virou chave: {chave!r}"
    # E o manifesto continua legivel de verdade.
    assert conftest._exigir(m, "identidade", "nome")
    assert conftest._exigir(m, "verificacao", "comando")
'@ -Encoding ASCII
        $rPy = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($rPy.Codigo -eq 0) `
            "a trilha Python nao le project.yaml com BOM. Saida: $($rPy.Saida)"

        # O gemeo PowerShell sobre o MESMO arquivo, com BOM.
        $manifPs = Join-Path $projPs 'project.yaml'
        $origPs = [System.IO.File]::ReadAllText($manifPs, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($manifPs, $origPs, $comBom)
        Set-Content (Join-Path $projPs 'tests\suites\bom.ps1') `
            "    Test-Caso `"le manifesto com BOM`" {`n        `$raiz = Read-ManifestoDoProjeto (Join-Path (Get-RaizDoProjeto) 'project.yaml')`n        foreach (`$k in `$raiz.Keys) { Assert-True (-not `$k.StartsWith('#')) `"comentario virou chave: `$k`" }`n        Assert-True ((Get-CampoDoManifesto 'identidade.nome') -eq 'projeto-teste') `"nome errado`"`n    }`n" -Encoding ASCII
        $rPs = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'bom')
        Assert-True ($rPs.Codigo -eq 0) `
            "a trilha PowerShell nao le project.yaml com BOM. Saida: $($rPs.Saida)"
    } finally {
        [System.IO.File]::WriteAllText($manifPy, $origPy, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_bom.py') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}

Test-Caso "leitor: '#' DENTRO de valor citado nao trunca o valor (as duas trilhas)" {
    # O ramo corrigido na rodada anterior nao tinha caso em trilha nenhuma, e o
    # qa-reviewer mostrou a mutacao que sobrevivia: apagar o bloco inteiro dos
    # dois gemeos e deixar so o '\s#' generico continua passando em
    # 'remoto: "{{REMOTO}}"   # comentario' e em
    # 'revisao_independente: "qa+security"   # derivado' - as duas formas que
    # os casos existentes exercitavam. So um '#' DENTRO das aspas discrimina,
    # e nao havia fixture assim em tests/ nem em templates/.
    #
    # A protecao que pegou o defeito anterior foi INCIDENTAL, nao desenhada.
    Assert-TrilhaPythonPronta
    $manifPy = Join-Path $ProjPy 'project.yaml'
    $origPy = [System.IO.File]::ReadAllText($manifPy, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    try {
        $alvo = '  criterio_de_pronto: "a instancia roda a propria suite e ela passa"'
        $comHash = '  criterio_de_pronto: "roda o passo #3 e compara"   # nota de fim de linha'

        # --- Python -------------------------------------------------------
        $comPy = $origPy.Replace($alvo, $comHash)
        Assert-True ($comPy -cne $origPy) "a fixture nao inseriu o valor com # interno (Python)"
        [System.IO.File]::WriteAllText($manifPy, $comPy, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $ProjPy 'tests\test_hash.py') @'
def test_hash_dentro_das_aspas_nao_trunca(criterio_de_pronto):
    assert criterio_de_pronto == "roda o passo #3 e compara", (
        "valor truncado ou com aspa orfa: " + repr(criterio_de_pronto)
    )
'@ -Encoding ASCII
        $rPy = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Assert-True ($rPy.Codigo -eq 0) `
            "a trilha Python truncou o valor no '#' interno. Saida: $($rPy.Saida)"

        # --- PowerShell ---------------------------------------------------
        $manifPs = Join-Path $projPs 'project.yaml'
        $origPs = [System.IO.File]::ReadAllText($manifPs, [System.Text.Encoding]::UTF8)
        $comPs = $origPs.Replace($alvo, $comHash)
        Assert-True ($comPs -cne $origPs) "a fixture nao inseriu o valor com # interno (PowerShell)"
        [System.IO.File]::WriteAllText($manifPs, $comPs, (New-Object System.Text.UTF8Encoding($false)))
        Set-Content (Join-Path $projPs 'tests\suites\hash.ps1') `
            "    Test-Caso `"hash dentro das aspas nao trunca`" {`n        `$c = Get-CampoDoManifesto 'verificacao.criterio_de_pronto'`n        Assert-True (`$c -ceq 'roda o passo #3 e compara') `"leu '`$c'`"`n    }`n" -Encoding ASCII
        $rPs = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'hash')
        Assert-True ($rPs.Codigo -eq 0) `
            "a trilha PowerShell truncou o valor no '#' interno. Saida: $($rPs.Saida)"
    } finally {
        [System.IO.File]::WriteAllText($manifPy, $origPy, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_hash.py') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}


Test-Caso "leitor: os dois gemeos recusam as MESMAS coisas no ACESSOR, nao so no parser" {
    # O qa-reviewer mostrou por que a oitava divergencia era inalcancavel: o
    # caso de comparacao existente compara a camada do PARSER
    # (ler_manifesto / Read-ManifestoDoProjeto), e a divergencia morava na
    # camada do ACESSOR (_exigir / Get-CampoDoManifesto). Estruturalmente fora
    # de alcance, com qualquer entrada.
    #
    # A oitava era 'criterio_de_pronto: "   "' - aspas com so espacos. Python
    # testava atual.strip() == "" e recusava; PowerShell testava '-not $v', e
    # string de tres espacos e TRUTHY, entao devolvia "   " como criterio
    # declarado. Fail-open do lado que aceita.
    #
    # Este caso pergunta ao ACESSOR dos dois lados, sobre as MESMAS entradas, e
    # exige o mesmo veredito - aceita ou recusa. Nao compara o texto do erro:
    # compara a DECISAO.
    Assert-TrilhaPythonPronta
    $manifPy = Join-Path $ProjPy 'project.yaml'
    $origPy = [System.IO.File]::ReadAllText($manifPy, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    $manifPs = Join-Path $projPs 'project.yaml'
    $origPs = [System.IO.File]::ReadAllText($manifPs, [System.Text.Encoding]::UTF8)
    try {
        $alvo = '  criterio_de_pronto: "a instancia roda a propria suite e ela passa"'
        $entradas = @(
            @{ Nome = 'so espacos entre aspas'; Linha = '  criterio_de_pronto: "   "';  DeveAceitar = $false },
            @{ Nome = 'aspas vazias';           Linha = '  criterio_de_pronto: ""';     DeveAceitar = $false },
            @{ Nome = 'um caractere';           Linha = '  criterio_de_pronto: "x"';    DeveAceitar = $true }
        )
        foreach ($e in $entradas) {
            # --- Python: o acessor aceita ou recusa? ------------------------
            [System.IO.File]::WriteAllText($manifPy, $origPy.Replace($alvo, $e.Linha), (New-Object System.Text.UTF8Encoding($false)))
            Set-Content (Join-Path $ProjPy 'tests\test_acessor.py') @'
import conftest


def test_o_acessor_decide():
    m = conftest.ler_manifesto()
    try:
        conftest._exigir(m, "verificacao", "criterio_de_pronto")
        veredito = "ACEITOU"
    except BaseException:
        veredito = "RECUSOU"
    destino = conftest.RAIZ / "veredito.txt"
    destino.write_text(veredito, encoding="utf-8")
'@ -Encoding ASCII
            $arqPy = Join-Path $ProjPy 'veredito.txt'
            Remove-Item $arqPy -Force -ErrorAction SilentlyContinue
            $null = Invoke-RunnerDoProjeto -Projeto $ProjPy
            Remove-Item (Join-Path $ProjPy 'tests\test_acessor.py') -Force -ErrorAction SilentlyContinue
            Assert-True (Test-Path $arqPy -PathType Leaf) ("a trilha Python nao gravou o veredito para '" + $e.Nome + "'")
            $vPy = (Get-Texto $arqPy).Trim()
            Remove-Item $arqPy -Force -ErrorAction SilentlyContinue

            # --- PowerShell: mesma pergunta ---------------------------------
            [System.IO.File]::WriteAllText($manifPs, $origPs.Replace($alvo, $e.Linha), (New-Object System.Text.UTF8Encoding($false)))
            Set-Content (Join-Path $projPs 'tests\suites\acessor.ps1') `
                "    Test-Caso `"o acessor decide`" {`n        `$v = 'RECUSOU'`n        try { `$null = Get-CampoDoManifesto 'verificacao.criterio_de_pronto'; `$v = 'ACEITOU' } catch { `$v = 'RECUSOU' }`n        [System.IO.File]::WriteAllText((Join-Path (Get-RaizDoProjeto) 'veredito.txt'), `$v, (New-Object System.Text.UTF8Encoding(`$false)))`n    }`n" -Encoding ASCII
            $arqPs = Join-Path $projPs 'veredito.txt'
            Remove-Item $arqPs -Force -ErrorAction SilentlyContinue
            $null = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'acessor')
            Assert-True (Test-Path $arqPs -PathType Leaf) ("a trilha PowerShell nao gravou o veredito para '" + $e.Nome + "'")
            $vPs = (Get-Texto $arqPs).Trim()
            Remove-Item $arqPs -Force -ErrorAction SilentlyContinue

            $esperado = if ($e.DeveAceitar) { 'ACEITOU' } else { 'RECUSOU' }
            Assert-True ([string]::Equals($vPy, $vPs, [System.StringComparison]::Ordinal)) `
                ("divergencia de ACESSOR em '" + $e.Nome + "': Python " + $vPy + ", PowerShell " + $vPs)
            Assert-True ([string]::Equals($vPy, $esperado, [System.StringComparison]::Ordinal)) `
                ("os dois concordaram, mas no veredito ERRADO para '" + $e.Nome + "': esperava " + $esperado + ", veio " + $vPy)
        }
    } finally {
        [System.IO.File]::WriteAllText($manifPy, $origPy, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_acessor.py') -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $ProjPy 'veredito.txt') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}

Test-Caso "leitor: byte INVALIDO e recusado nas duas trilhas, nao substituido em silencio" {
    # NONA assimetria, achada pelo qa-reviewer: ReadAllText com
    # [Text.Encoding]::UTF8 substitui byte invalido por U+FFFD EM SILENCIO,
    # enquanto read_text('utf-8-sig') levanta UnicodeDecodeError. Um
    # project.yaml salvo em ANSI pelo Bloco de Notas - cenario que o runbook
    # desta plataforma documenta como recorrente - fazia a trilha PowerShell
    # seguir VERDE com o criterio corrompido e a Python errar duro.
    #
    # Mesma direcao de todas as outras oito: o lado PowerShell aceitava o que
    # o Python recusava.
    Assert-TrilhaPythonPronta
    $manifPy = Join-Path $ProjPy 'project.yaml'
    $origPy = [System.IO.File]::ReadAllText($manifPy, [System.Text.Encoding]::UTF8)
    $projPs = New-ProjetoDeTeste -Template $Template -Trilha 'powershell'
    $manifPs = Join-Path $projPs 'project.yaml'
    $origPs = [System.IO.File]::ReadAllText($manifPs, [System.Text.Encoding]::UTF8)
    try {
        # 0xE7 solto e 'c cedilha' em ANSI (Windows-1252) e byte INVALIDO em
        # UTF-8: nao inicia sequencia valida de continuacao.
        $ansi = [System.Text.Encoding]::GetEncoding(1252)
        $comAcento = $origPy.Replace('  criterio_de_pronto: "a instancia roda a propria suite e ela passa"',
                                     '  criterio_de_pronto: "roda em producao"')
        $bytesAnsi = $ansi.GetBytes($comAcento.Replace('producao', "produ" + [char]0xE7 + "ao"))
        [System.IO.File]::WriteAllBytes($manifPy, $bytesAnsi)
        $lidos = [System.IO.File]::ReadAllBytes($manifPy)
        Assert-True ($lidos -contains 0xE7) "a fixture nao gravou o byte invalido: o caso passaria sem exercitar o ramo"

        Set-Content (Join-Path $ProjPy 'tests\test_ansi.py') @'
import conftest


def test_byte_invalido_e_recusado():
    try:
        conftest.ler_manifesto()
        veredito = "ACEITOU"
    except BaseException:
        veredito = "RECUSOU"
    (conftest.RAIZ / "veredito.txt").write_text(veredito, encoding="utf-8")
'@ -Encoding ASCII
        $arqPy = Join-Path $ProjPy 'veredito.txt'
        Remove-Item $arqPy -Force -ErrorAction SilentlyContinue
        $null = Invoke-RunnerDoProjeto -Projeto $ProjPy
        Remove-Item (Join-Path $ProjPy 'tests\test_ansi.py') -Force -ErrorAction SilentlyContinue
        Assert-True (Test-Path $arqPy -PathType Leaf) "a trilha Python nao gravou o veredito"
        $vPy = (Get-Texto $arqPy).Trim()
        Remove-Item $arqPy -Force -ErrorAction SilentlyContinue

        [System.IO.File]::WriteAllBytes($manifPs, $ansi.GetBytes($origPs.Replace('"a instancia roda a propria suite e ela passa"', '"roda em produ' + [char]0xE7 + 'ao"')))
        Set-Content (Join-Path $projPs 'tests\suites\ansi.ps1') `
            "    Test-Caso `"byte invalido`" {`n        `$v = 'RECUSOU'`n        try { `$null = Get-CampoDoManifesto 'identidade.nome'; `$v = 'ACEITOU' } catch { `$v = 'RECUSOU' }`n        [System.IO.File]::WriteAllText((Join-Path (Get-RaizDoProjeto) 'veredito.txt'), `$v, (New-Object System.Text.UTF8Encoding(`$false)))`n    }`n" -Encoding ASCII
        $arqPs = Join-Path $projPs 'veredito.txt'
        Remove-Item $arqPs -Force -ErrorAction SilentlyContinue
        $null = Invoke-RunnerDoProjeto -Projeto $projPs -Argumentos @('-Suite', 'ansi')
        Assert-True (Test-Path $arqPs -PathType Leaf) "a trilha PowerShell nao gravou o veredito"
        $vPs = (Get-Texto $arqPs).Trim()
        Remove-Item $arqPs -Force -ErrorAction SilentlyContinue

        Assert-True ([string]::Equals($vPy, 'RECUSOU', [System.StringComparison]::Ordinal)) `
            "a trilha Python aceitou um manifesto com byte invalido"
        Assert-True ([string]::Equals($vPs, 'RECUSOU', [System.StringComparison]::Ordinal)) `
            "a trilha PowerShell aceitou um manifesto com byte invalido - substituindo por U+FFFD em silencio, como fazia antes"
    } finally {
        [System.IO.File]::WriteAllText($manifPy, $origPy, (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item (Join-Path $ProjPy 'tests\test_ansi.py') -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $ProjPy 'veredito.txt') -Force -ErrorAction SilentlyContinue
        Remove-ProjetoDeTeste $projPs
    }
}

if ($ProjPy) { Remove-ProjetoDeTeste $ProjPy }
