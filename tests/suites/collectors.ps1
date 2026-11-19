<#
.SYNOPSIS
    Suite de testes: os coletores FAZEM o que dizem (execucao real).

.DESCRIPTION
    Esta suite existe porque o qa-reviewer reprovou a subfase 2.2 na primeira
    tentativa, com razao: os testes da suite 'agents' sao regex sobre o
    TEXTO-FONTE dos scripts. Verificam que a string 'ls-files --others'
    aparece no arquivo - nao que a funcao funciona.
    Isso viola a politica 4.1: "um scanner que nunca acusou nada nao foi
    testado, foi so executado".

    Aqui os scripts sao EXECUTADOS contra fixtures em $env:TEMP, com par
    positivo e negativo. Nada e escrito fora de $env:TEMP.

    Este arquivo contem strings em formato de credencial, de proposito, para
    exercitar os detectores. Todas sao inventadas. O marcador abaixo faz o
    security-scan.ps1 RECLASSIFICAR os achados deste arquivo como fixture
    declarada, severidade BAIXA - reclassificar, nao silenciar: o achado
    continua aparecendo no relatorio, e quem revisa decide.

      SEGREDO-FABRICADO-PARA-TESTE

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite collectors

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite collectors"
}

$Scanner  = Join-Path $OsRoot 'scripts\security-scan.ps1'
$Coletor  = Join-Path $OsRoot 'scripts\collect-diff.ps1'

function New-RepoFixture {
    <#
      Cria um repositorio Git descartavel em $env:TEMP.
      -SemCommit deixa o repo sem nenhum commit (caso do /os:new-project).
      Devolve o caminho.
    #>
    param([hashtable]$Arquivos = @{}, [switch]$SemCommit, [switch]$IgnorarArtifacts)

    # git escreve aviso de CRLF em stderr, e no PowerShell 5.1 stderr de
    # executavel nativo vira ErrorRecord: sob ErrorActionPreference=Stop isso
    # aborta o teste com uma mensagem sobre fim de linha, que nao tem nada a
    # ver com o que se esta testando. Duas defesas: desligar a conversao no
    # fixture (remove a causa) e nao tratar stderr como terminante aqui.
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $t = Join-Path $env:TEMP ("fx-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q 2>$null
        git -C $t config user.name  'Fixture'    2>$null
        git -C $t config user.email 'fx@invalid' 2>$null
        git -C $t config core.autocrlf false     2>$null
        git -C $t config core.safecrlf false     2>$null
        # Isola do .gitignore_global da maquina: sem isto um fixture com .env
        # nao consegue rastrear o .env, e o detector nao pode ser exercitado.
        git -C $t config core.excludesfile (Join-Path $t '.git/vazio-de-proposito') 2>$null

        if ($IgnorarArtifacts) {
            [System.IO.File]::WriteAllText((Join-Path $t '.gitignore'), "/artifacts/*`n", (New-Object System.Text.UTF8Encoding($false)))
        }
        foreach ($nome in $Arquivos.Keys) {
            $dest = Join-Path $t $nome
            $pai = Split-Path -Parent $dest
            if ($pai -and -not (Test-Path $pai)) { New-Item -ItemType Directory -Path $pai -Force | Out-Null }
            [System.IO.File]::WriteAllText($dest, $Arquivos[$nome], (New-Object System.Text.UTF8Encoding($false)))
        }
        if (-not $SemCommit) {
            git -C $t add -A 2>$null
            git -C $t commit -q -m 'fixture' 2>$null
        }
        return $t
    } finally { $ErrorActionPreference = $anterior }
}

function Invoke-Script {
    param([string]$Script, [string]$Repo, [string[]]$Extra = @())
    $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-Path', $Repo) + $Extra
    $saida = (& powershell @argumentos 2>&1 | Out-String)
    return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
}

function Get-Relatorio {
    param([string]$Repo, [string]$Nome)
    $p = Join-Path $Repo "artifacts\review\$Nome"
    if (-not (Test-Path $p)) { return $null }
    return Get-Texto $p
}

# =============================================================================
# security-scan.ps1 - positivo e negativo
# =============================================================================

Test-Caso "scanner: repo limpo NAO acusa e sai com 0" {
    # O par negativo. Sem ele, um scanner que grita sempre passaria.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{
        'README.md'   = "# Projeto limpo`nNada sensivel aqui.`n"
        'scripts.py'  = "def somar(a, b):`n    return a + b`n"
    }
    try {
        $r = Invoke-Script $Scanner $fx
        Assert-True ($r.Exit -eq 0) "esperava exit 0 em repo limpo, veio $($r.Exit). Saida: $($r.Saida)"
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($null -ne $rel) "o scanner nao gravou relatorio"
        Assert-True ($rel -match 'Nenhum achado') "relatorio nao diz que nao houve achado"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: ACUSA credencial no conteudo de arquivo rastreado" {
    # Valores fabricados, com formato valido para os padroes do scanner.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{
        'app.js' = "const auth = 'ghp_FAKEFAKEFAKEFAKEFAKE1234';`n"
        'db.py'  = "DB = 'postgres://usuario:senhafabricada@host/base'`n"
    }
    try {
        $r = Invoke-Script $Scanner $fx
        Assert-True ($r.Exit -eq 1) "esperava exit 1 com achado, veio $($r.Exit)"
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'token do GitHub') "nao acusou o token do GitHub"
        Assert-True ($rel -match 'string de conexao') "nao acusou a string de conexao"
        # Reportar onde, nunca o que: o valor nao pode aparecer no relatorio.
        Assert-True ($rel -notmatch 'FAKEFAKEFAKEFAKEFAKE1234') "o relatorio TRANSCREVEU o valor da credencial"
        Assert-True ($rel -notmatch 'senhafabricada') "o relatorio TRANSCREVEU a senha"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: ACUSA arquivo sensivel rastreado por nome" {
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{
        '.env'       = "API_KEY=qualquer`n"
        'deploy.pem' = "-----BEGIN RSA PRIVATE KEY-----`nFABRICADO`n-----END RSA PRIVATE KEY-----`n"
    }
    try {
        $r = Invoke-Script $Scanner $fx
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'arquivo sensivel rastreado') "nao acusou arquivo sensivel"
        Assert-True ($rel -match '\.env')       "nao apontou o .env"
        Assert-True ($rel -match 'deploy\.pem') "nao apontou o deploy.pem"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: ACUSA documento operacional rastreado, com severidade MEDIA" {
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'relatorio.xlsx' = "conteudo`n" }
    try {
        $r = Invoke-Script $Scanner $fx
        $rel = Get-Relatorio $fx 'security-report.md'
        # A tabela ganhou a coluna Area na 2.3; o achado e o mesmo.
        Assert-True ($rel -match 'MEDIA \|.*\| documento operacional') "nao acusou documento operacional como MEDIA"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: ACUSA quando o proprio destino do relatorio nao esta ignorado" {
    # Sem -IgnorarArtifacts de proposito: o relatorio ficaria versionavel.
    # '-Out' EXPLICITO dentro do alvo desde o item 157: sem ele o scanner
    # agora grava FORA de um alvo que nao ignora artifacts/ (para nao sujar o
    # repositorio), e o achado deixa de se aplicar. Com o destino pedido pela
    # pessoa, o aviso continua sendo devido.
    $fx = New-RepoFixture -Arquivos @{ 'README.md' = "# nada`n" }
    try {
        $r = Invoke-Script $Scanner $fx @('-Out', (Join-Path $fx 'artifacts\review\security-report.md'))
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'destino do relatorio nao ignorado') `
            "nao avisou que o destino do relatorio nao esta protegido"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: sai com 2 quando o alvo nao e repositorio Git" {
    $t = Join-Path $env:TEMP ("nr-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    try {
        $r = Invoke-Script $Scanner $t
        Assert-True ($r.Exit -eq 2) "esperava exit 2 fora de repo, veio $($r.Exit)"
    } finally { if (Test-Path $t) { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: o relatorio sempre declara o que NAO foi varrido" {
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'a.md' = "# a`n" }
    try {
        $null = Invoke-Script $Scanner $fx
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'Escopo NAO VARRIDO') "relatorio sem secao de escopo nao varrido"
        # Ate a 2.2 este teste exigia 'historico do Git' aqui. A 2.3 passou a
        # varrer o historico, entao a lacuna permanente virou outra: deteccao
        # por padrao nao pega segredo sem formato reconhecivel, e isso nunca
        # deixa de ser verdade.
        Assert-True ($rel -match '(?i)sem formato reconhecivel') "nao declara o limite da deteccao por padrao"
        Assert-True ($rel -match '(?i)vulnerabilidade de dependencia') "nao declara a lacuna de dependencia"
        Assert-True ($rel -match '(?i)ausencia de evidencia') "nao avisa que lacuna nao e aprovacao"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: ACUSA credencial em arquivo NAO RASTREADO" {
    # O ponto cego que o security-reviewer achou na 2.2: iterando so
    # 'git ls-files', o scanner ficava cego ao codigo recem-escrito - que e
    # exatamente o codigo sob revisao.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'novo.js'),
            "const t = 'ghp_NAORASTREADOFAKE12345';`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Script $Scanner $fx
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'novo\.js') "nao examinou o arquivo nao rastreado"
        Assert-True ($rel -match 'nao rastreado') "nao marcou o achado como de arquivo nao rastreado"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: ACUSA nome sensivel em arquivo NAO RASTREADO" {
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'segredo.pem'), "conteudo`n", (New-Object System.Text.UTF8Encoding($false)))
        $null = Invoke-Script $Scanner $fx
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'nao rastreado \(entraria num git add\)') `
            "nao avisou que o arquivo sensivel entraria num git add"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: marcador de fixture RECLASSIFICA, nunca silencia" {
    # Exigencia do security-reviewer: provar que a allowlist nao engole
    # segredo de verdade. Aqui o mesmo conteudo aparece com e sem marcador;
    # nos dois casos o achado tem de estar no relatorio.
    $credencial = "const t = 'ghp_MARCADORTESTEFAKE99999';`n"
    $marcador = 'SEGREDO-FABRICADO-PARA-TESTE'

    $comMarca = New-RepoFixture -IgnorarArtifacts -Arquivos @{
        'teste.js' = "// $marcador`n$credencial"
    }
    try {
        $null = Invoke-Script $Scanner $comMarca
        $rel = Get-Relatorio $comMarca 'security-report.md'
        # Reclassificado, e AINDA PRESENTE.
        Assert-True ($rel -match 'fixture declarada') "com marcador: nao reclassificou"
        Assert-True ($rel -match 'teste\.js') "com marcador: ENGOLIU o achado - o arquivo nao aparece"
        Assert-True ($rel -match 'BAIXA') "com marcador: nao usou severidade BAIXA"
    } finally { if (Test-Path $comMarca) { Remove-Item $comMarca -Recurse -Force -ErrorAction SilentlyContinue } }

    $semMarca = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'teste.js' = $credencial }
    try {
        $r = Invoke-Script $Scanner $semMarca
        Assert-True ($r.Exit -eq 1) "sem marcador: esperava exit 1"
        $rel = Get-Relatorio $semMarca 'security-report.md'
        Assert-True ($rel -match 'ALTA \|.*\| possivel token do GitHub') "sem marcador: nao acusou como ALTA"
        # Ancorado no '|' da coluna de categoria, nao na frase solta: desde a
        # 2.3 o relatorio EXPLICA a escada de severidade e a expressao
        # 'fixture declarada' aparece nessa explicacao. Procurar a frase solta
        # daria positivo em todo relatorio, e o teste passaria a acusar
        # sempre - o mesmo defeito que ele existe para pegar no scanner.
        Assert-True ($rel -notmatch '\| fixture declarada') "sem marcador: reclassificou sem marcador"
    } finally { if (Test-Path $semMarca) { Remove-Item $semMarca -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "scanner: o relatorio explica que fixture declarada e afirmacao, nao verificacao" {
    # O marcador e escrito por quem criou o arquivo. Quem revisa precisa saber
    # que confiar nele e uma decisao, nao um fato verificado.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{
        'teste.js' = "// SEGREDO-FABRICADO-PARA-TESTE`nconst t = 'ghp_EXPLICATESTEFAKE1234';`n"
    }
    try {
        $null = Invoke-Script $Scanner $fx
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'reclassificado, nao silenciado') "o relatorio nao explica a reclassificacao"
        Assert-True ($rel -match 'afirmacao de quem escreveu') "o relatorio nao avisa que o marcador e afirmacao"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

# =============================================================================
# collect-diff.ps1 - execucao real
# =============================================================================

Test-Caso "coletor: repo SEM NENHUM COMMIT nao quebra e declara a ausencia de HEAD" {
    # O caso que o qa-reviewer achou: /os:new-project roda git init e para,
    # entao o primeiro checkpoint acontece sem HEAD. 'git diff HEAD' falharia
    # com "fatal: ambiguous argument 'HEAD'".
    $fx = New-RepoFixture -SemCommit -IgnorarArtifacts -Arquivos @{
        'README.md'  = "# projeto novo`n"
        'scripts.py' = "print('oi')`n"
    }
    try {
        $r = Invoke-Script $Coletor $fx @('-SkipTests')
        Assert-True ($r.Exit -ne 2) "o coletor abortou (exit 2) num repo sem commits. Saida: $($r.Saida)"
        Assert-True ($r.Saida -notmatch 'ambiguous argument') "vazou o erro 'ambiguous argument' do Git"
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($null -ne $rel) "o coletor nao gravou relatorio"
        Assert-True ($rel -match '(?i)nao tem nenhum commit') "nao declarou a ausencia de commits"
        Assert-True ($rel -match 'sem commits') "nao marcou o HEAD como inexistente"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: repo sem commits mostra TODO arquivo, inclusive o rastreado" {
    # Arquivo staged sem commit nao aparece em diff nem em ls-files --others.
    $fx = New-RepoFixture -SemCommit -IgnorarArtifacts -Arquivos @{ 'rastreado.md' = "# conteudo unico ABC123`n" }
    try {
        git -C $fx add rastreado.md 2>$null
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'rastreado\.md') "nao listou o arquivo rastreado sem commit"
        Assert-True ($rel -match 'ABC123') "nao incluiu o conteudo do arquivo rastreado sem commit"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: inclui conteudo de arquivo NOVO, que git diff nao mostra" {
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'novo.md'), "# novo`nMARCA-UNICA-XYZ`n", (New-Object System.Text.UTF8Encoding($false)))
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'MARCA-UNICA-XYZ') "nao incluiu o conteudo do arquivo novo"
        Assert-True ($rel -match 'Arquivos novos') "nao criou a secao de arquivos novos"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: nome NAO-ASCII nao aborta a coleta (residuo do item 156)" {
    # Antes: 'ls-files'/'diff --name-only' sem -z devolviam o nome citado com
    # escape octal ("CAPA DOSSI\303\212.md"), o Join-Path lancava "Caracteres
    # invalidos no caminho" e o coletor saia com 2 sem relatorio.
    $E = [string][char]0x00CA; $o = [string][char]0x00F3
    $rastreado = "relat${o}rio [v1].md"
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ $rastreado = "# base`n" }
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx $rastreado), "# base`nMUDOU-ACENTO-77`n", (New-Object System.Text.UTF8Encoding($false)))
        New-Item -ItemType Directory -Path (Join-Path $fx 'CAPAS') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $fx "CAPAS\CAPA DOSSI$E.md"), "# novo`nMARCA-ACENTO-156`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Script $Coletor $fx @('-SkipTests')
        Assert-True ($r.Exit -ne 2) ("o coletor abortou com nome acentuado (exit 2): " + $r.Saida)
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($null -ne $rel) "o coletor nao gravou relatorio"
        Assert-True ($rel -match 'MARCA-ACENTO-156') "nao transcreveu o arquivo novo de nome acentuado"
        Assert-True ($rel.Contains("CAPA DOSSI$E.md")) "o nome do arquivo novo nao saiu legivel (UTF-8) no relatorio"
        Assert-True ($rel.Contains($rastreado)) "o arquivo rastreado de nome acentuado/colchete nao foi listado"
        Assert-True ($rel -notmatch '\\303|\\212') "o relatorio traz o nome citado com escape octal"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: fence do arquivo novo sobrevive a conteudo que contem fence" {
    # Com fence fixo de 3 backticks, um arquivo que contem ``` fecha o bloco no
    # meio e o resto do relatorio alterna codigo e prosa. Aconteceu de verdade
    # ao coletar os agentes e o ADR-0008 na subfase 2.2.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $comFence = "# doc`n" + '```' + "powershell`nWrite-Host 'oi'`n" + '```' + "`nfim do doc`n"
        [System.IO.File]::WriteAllText((Join-Path $fx 'doc.md'), $comFence, (New-Object System.Text.UTF8Encoding($false)))
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'fim do doc') "o conteudo apos o fence interno nao chegou ao relatorio"
        # O fence externo tem de ser maior que o interno.
        Assert-True ($rel -match '(?m)^`{4,}') "o coletor nao ampliou o fence externo"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: grava a saida REAL do teste, inclusive quando o teste falha" {
    # Se o coletor maquiasse o resultado, o revisor aprovaria com base em mentira.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $r = Invoke-Script $Coletor $fx @('-TestCommand', 'Write-Host "SAIDA-DO-TESTE-FALSO"; exit 3')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'SAIDA-DO-TESTE-FALSO') "nao gravou a saida real do comando de teste"
        Assert-True ($rel -match 'Codigo de saida: \*\*3\*\*') "nao gravou o codigo de saida real"
        Assert-True ($rel -match 'NAO passou') "nao marcou o teste como reprovado"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: carimbo de integridade permite detectar coleta obsoleta" {
    # Na subfase 2.3 o working tree andou DEPOIS da coleta, e o relatorio
    # seguiu descrevendo uma versao que nao existia mais. O revisor detectou
    # por acaso. O carimbo faz a deriva se anunciar: bytes e linhas de cada
    # arquivo descrito, em unidade que um revisor read-only consegue conferir
    # sozinho - ele nao tem Bash para hash nem data de modificacao, mas le o
    # arquivo e conta linhas.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $novo = Join-Path $fx 'recem-escrito.py'
        [System.IO.File]::WriteAllText($novo, "a = 1`nb = 2`nc = 3`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'Carimbo de integridade') "o relatorio nao tem carimbo de integridade"
        Assert-True ($rel -match 'recem-escrito\.py`? \| \d+ \| 3 \|') `
            "o carimbo nao registrou bytes e as 3 linhas do arquivo novo"
        Assert-True ($rel -match '(?i)coleta esta obsoleta') `
            "o carimbo nao diz ao revisor o que fazer quando os numeros divergirem"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: -SkipTests declara a lacuna em vez de fingir cobertura" {
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $r = Invoke-Script $Coletor $fx @('-SkipTests')
        Assert-True ($r.Exit -eq 1) "esperava exit 1 com lacuna, veio $($r.Exit)"
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'Testes NAO foram executados') "nao declarou que os testes nao rodaram"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: -Out FORA do repositorio nao quebra nem inventa lacuna" {
    # Achado do qa-reviewer: a correcao de prefixo do -Out foi feita no
    # security-scan.ps1 e o gemeo aqui ficou com a linha antiga. Dois efeitos
    # medidos: destino fora do repo faz 'git check-ignore' recusar com "is
    # outside repository", e sob ErrorActionPreference=Stop isso derruba o
    # script pelo trap - exit 2, sem relatorio. Coletor que morre produz
    # INCONCLUSIVO com a arvore parada.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'a.md' = "# nada`n" }
    $fora = Join-Path $env:TEMP ("rel-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.md')
    try {
        $r = Invoke-Script $Coletor $fx @('-SkipTests', '-Out', $fora)
        Assert-True ($r.Exit -ne 2) "quebrou com exit 2 por causa do -Out externo. Saida: $($r.Saida)"
        Assert-True (Test-Path $fora) "nao gravou o relatorio no destino externo"
        $rel = Get-Texto $fora
        Assert-True ($rel -notmatch 'destino do relatorio NAO esta ignorado') `
            "inventou lacuna de destino para um arquivo que esta FORA do repositorio"
        Assert-True ($rel -match 'FORA do repositorio-alvo') `
            "nao declarou que a verificacao do destino nao se aplica"
    } finally {
        if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
        Remove-Item $fora -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "coletor: -Out com PREFIXO comum ao repo nao inventa lacuna" {
    # 'C:\projeto-relatorios\r.md'.StartsWith('C:\proj') e verdadeiro, e sem
    # separador o caminho relativo virava 'eto-relatorios\r.md': check-ignore
    # dizia nao-ignorado, o coletor declarava lacuna inexistente e saia com 1,
    # que a skill /os:checkpoint le como coleta incompleta.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'a.md' = "# nada`n" }
    $fora = $fx + '-relatorios'
    try {
        New-Item -ItemType Directory -Path $fora -Force | Out-Null
        $destino = Join-Path $fora 'r.md'
        $r = Invoke-Script $Coletor $fx @('-SkipTests', '-Out', $destino)
        Assert-True (Test-Path $destino) "nao gravou o relatorio"
        $rel = Get-Texto $destino
        Assert-True ($rel -notmatch 'destino do relatorio NAO esta ignorado') `
            "inventou lacuna por colisao de prefixo"
        Assert-True ($rel -match 'FORA do repositorio-alvo') "nao reconheceu o destino como externo"
    } finally {
        if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $fora) { Remove-Item $fora -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "coletor: arquivo novo ACIMA do limite declara a lacuna e respeita o parametro" {
    # O guarda-corpo que decide se codigo novo chega ao revisor, e que nao
    # tinha teste: na subfase 2.3 o limite de 400 escondeu justamente a suite
    # que ERA a evidencia da subfase, e o revisor bloqueou a area de cobertura
    # por causa disso. Politica 4.1 exige par positivo e negativo.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $grande = Join-Path $fx 'grande.md'
        [System.IO.File]::WriteAllText($grande, ("linha`n" * 30), (New-Object System.Text.UTF8Encoding($false)))

        # Positivo: acima do limite -> lacuna declarada, conteudo NAO incluido.
        $r1 = Invoke-Script $Coletor $fx @('-SkipTests', '-MaxLinhasArquivoNovo', '10')
        $rel1 = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel1 -match 'grande\.md`? tem 30 linhas e nao foi incluido inteiro \(limite 10\)') `
            "nao declarou a lacuna de truncamento com o limite usado"
        Assert-True ($rel1 -match '-MaxLinhasArquivoNovo 10') "nao registrou o parametro da invocacao"

        # Negativo: abaixo do limite -> nenhuma lacuna, conteudo incluido.
        $r2 = Invoke-Script $Coletor $fx @('-SkipTests', '-MaxLinhasArquivoNovo', '100')
        $rel2 = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel2 -notmatch 'nao foi incluido inteiro') `
            "declarou truncamento com o arquivo abaixo do limite"
        Assert-True ($rel2 -match '-MaxLinhasArquivoNovo 100') "nao registrou o parametro novo"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: diff ACIMA do limite declara a lacuna e respeita o parametro" {
    # O terceiro guarda-corpo que decide se codigo chega ao revisor, e o
    # ultimo que ainda nao tinha caso. Politica 4.1.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        # Altera um arquivo RASTREADO, para virar diff e nao arquivo novo.
        [System.IO.File]::WriteAllText((Join-Path $fx 'base.md'), ("# base`n" + ("linha alterada`n" * 40)), (New-Object System.Text.UTF8Encoding($false)))

        $r1 = Invoke-Script $Coletor $fx @('-SkipTests', '-MaxLinhasDiff', '5')
        $rel1 = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel1 -match 'foi truncado em 5') "nao declarou a lacuna de truncamento do diff"
        Assert-True ($rel1 -match '-MaxLinhasDiff 5') "nao registrou o parametro da invocacao"
        Assert-True ($rel1 -match '\*\*TRUNCADO\*\*') "a tabela de escopo nao marcou o diff como truncado"

        $r2 = Invoke-Script $Coletor $fx @('-SkipTests', '-MaxLinhasDiff', '5000')
        $rel2 = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel2 -notmatch 'foi truncado em') "declarou truncamento com o diff abaixo do limite"
        Assert-True ($rel2 -notmatch '\*\*TRUNCADO\*\*') "marcou o diff como truncado abaixo do limite"
        # '-SkipTests' declara a SUA lacuna sempre, e isso e correto: a
        # ausencia que interessa aqui e so a do truncamento.
        Assert-True ($rel2 -match '(?i)teste') "nao declarou a lacuna dos testes nao executados"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: -Contra descreve mudanca JA COMMITADA, com a arvore limpa" {
    # O caso que travou a revisao pendente da 2.3: subfase commitada, arvore
    # limpa, e 'git diff HEAD' devolvendo vazio - o revisor de QA nao teria a
    # mudanca sob revisao. Revisao depois do commit e o caso NORMAL de
    # fechamento de subfase, nao a excecao.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $primeiro = (git -C $fx rev-parse --short HEAD 2>$null)
        [System.IO.File]::WriteAllText((Join-Path $fx 'novo.py'), "def f():`n    return 1`n", (New-Object System.Text.UTF8Encoding($false)))
        git -C $fx add -A 2>$null
        git -C $fx commit -q -m 'segundo' 2>$null
        $ErrorActionPreference = $anterior

        # Contra HEAD (default): arvore limpa, diff vazio.
        $r1 = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel1 = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel1 -match '\(working tree limpa\)') "a arvore deveria estar limpa apos o commit"
        Assert-True ($rel1 -notmatch 'def f\(\)') "com -Contra HEAD o diff deveria estar vazio"

        # Contra o commit anterior: a mudanca commitada aparece.
        $r2 = Invoke-Script $Coletor $fx @('-SkipTests', '-Contra', $primeiro)
        $rel2 = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel2 -match 'def f\(\)') "com -Contra <commit anterior> o diff da mudanca commitada nao apareceu"
        Assert-True ($rel2 -match 'novo\.py') "nao listou o arquivo da mudanca commitada"
        # E o relatorio diz contra QUE ele comparou, senao o revisor nao sabe
        # o que esta lendo.
        Assert-True ($rel2 -match ('git diff.*' + [regex]::Escape($primeiro))) `
            "o relatorio nao declara a referencia de comparacao usada"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: AVISO do git sobre fim de linha NAO derruba a coleta" {
    # Defeito real, achado no fechamento da 2.4 e sobre o proprio repositorio
    # da plataforma: o .gitattributes fixa 'eol=lf' para .md, um .md foi
    # gravado com CRLF, e o 'git diff' do coletor avisou "CRLF will be
    # replaced by LF". No 5.1, stderr de executavel nativo vira ErrorRecord;
    # sob ErrorActionPreference=Stop isso e TERMINANTE, o trap pegou, e o
    # coletor saiu com 2 e SEM RELATORIO - no meio de um fechamento de
    # subfase. Coletor que morre nao produz evidencia, e sem evidencia a
    # revisao e INCONCLUSIVO.
    #
    # A correcao e de classe, nao deste aviso: todo git passa por Invoke-Git,
    # que baixa o ErrorActionPreference em volta da chamada. Este caso planta
    # exatamente a condicao do aviso e exige relatorio.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        # eol=lf no repositorio, e autocrlf/safecrlf de volta ao padrao que
        # produz o aviso (a fixture desliga os dois na causa, de proposito).
        [System.IO.File]::WriteAllText((Join-Path $fx '.gitattributes'), "* text eol=lf`n", (New-Object System.Text.UTF8Encoding($false)))
        git -C $fx config core.autocrlf true 2>$null
        git -C $fx config core.safecrlf warn 2>$null
        git -C $fx add -A 2>$null
        git -C $fx commit -q -m 'atributos' 2>$null
        # Agora o arquivo rastreado ganha CRLF na arvore: e o que o git avisa.
        [System.IO.File]::WriteAllText((Join-Path $fx 'base.md'), "# base`r`nlinha nova com CRLF`r`n", (New-Object System.Text.UTF8Encoding($false)))
        # Confirma que a condicao existe de verdade - sem isto o caso passaria
        # por vacuidade, provando nada.
        $aviso = (& git -C $fx diff --stat 2>&1 | Out-String)
        $ErrorActionPreference = $anterior
        Assert-True ($aviso -match 'CRLF|LF will be') `
            "a fixture nao produziu o aviso do git: este caso passaria sem exercitar o ramo. Saida: $aviso"

        $r = Invoke-Script $Coletor $fx @('-SkipTests')
        Assert-True ($r.Exit -ne 2) `
            "o coletor abortou por causa de um AVISO do git (exit $($r.Exit)). Saida: $($r.Saida)"
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True (-not [string]::IsNullOrWhiteSpace($rel)) "nao gerou relatorio nenhum"
        Assert-True ($rel -match 'linha nova com CRLF') `
            "o relatorio nao contem a mudanca: a coleta foi interrompida antes do diff"
    } finally {
        if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "coletor: git que FALHA sai com 2 e sem relatorio afirmativo" {
    # O achado ALTA do qa-reviewer e o MEDIA convergente do security-reviewer
    # no fechamento da 2.4, e o par que faltava do caso do aviso acima.
    #
    # A primeira versao do Invoke-Git baixava o ErrorActionPreference E
    # engolia o codigo de saida. Das ~34 chamadas, so 6 consultavam
    # $LASTEXITCODE; nas outras 28 uma falha de git virava LISTA VAZIA, que e
    # indistinguivel de "nada a acusar". Antes da 2.4 a mesma falha abortava e
    # o trap dava exit 2. Eu havia trocado um modo de falha ruidoso por um
    # silencioso, dentro de um coletor de evidencia.
    #
    # Aqui a falha e PLANTADA: o diretorio .git e substituido por um arquivo,
    # entao todo comando git falha de verdade. O coletor tem de recusar.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        Remove-Item (Join-Path $fx '.git') -Recurse -Force
        [System.IO.File]::WriteAllText((Join-Path $fx '.git'), "nao sou um repositorio`n", (New-Object System.Text.UTF8Encoding($false)))
        # Confirma que a condicao existe: sem isto o caso passaria por
        # vacuidade, provando nada.
        & git -C $fx ls-files 2>&1 | Out-Null
        $codigoGit = $LASTEXITCODE
        $ErrorActionPreference = $anterior
        Assert-True ($codigoGit -ne 0) "a fixture nao produziu falha de git: este caso nao exercitaria o ramo"

        $r = Invoke-Script $Coletor $fx @('-SkipTests')
        Assert-True ($r.Exit -eq 2) `
            "git falhando deveria dar exit 2 (a coleta nao aconteceu), veio $($r.Exit). Saida: $($r.Saida)"

        # E o mais importante: NAO pode existir relatorio afirmando cobertura.
        $rel = Get-Relatorio $fx 'diff-report.md'
        if (-not [string]::IsNullOrWhiteSpace($rel)) {
            Assert-True ($rel -notmatch 'Nenhuma lacuna') `
                "o coletor gravou relatorio declarando cobertura cheia com o git falhando"
        }
    } finally {
        if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "scanner: git que FALHA sai com 2, nao com relatorio dizendo limpo" {
    # O gemeo do caso acima no scanner de seguranca, e aqui a consequencia era
    # pior: zero arquivo examinado, as seis areas declaradas COBERTAS, secao
    # de lacunas imprimindo "(nenhuma)" e exit 0. Um scanner dizendo "limpo"
    # sobre um repositorio que ele nunca leu.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'a.md' = "# nada`n" }
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        # .git continua sendo DIRETORIO (o scanner exige isso na entrada, e
        # sair com 2 por 'nao e repositorio' seria outro caminho), mas o
        # conteudo dele fica inutilizavel.
        Remove-Item (Join-Path $fx '.git\objects') -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $fx '.git\refs') -Recurse -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText((Join-Path $fx '.git\HEAD'), "lixo que nao e ref`n", (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText((Join-Path $fx '.git\index'), "indice corrompido`n", (New-Object System.Text.UTF8Encoding($false)))
        & git -C $fx ls-files 2>&1 | Out-Null
        $codigoGit = $LASTEXITCODE
        $ErrorActionPreference = $anterior
        Assert-True ($codigoGit -ne 0) "a fixture nao produziu falha de git no ls-files: veio $codigoGit"

        $r = Invoke-Script $Scanner $fx @('-SemRede')
        Assert-True ($r.Exit -eq 2) `
            "git falhando deveria dar exit 2 (a varredura nao aconteceu), veio $($r.Exit). Saida: $($r.Saida)"
        $rel = Get-Relatorio $fx 'security-report.md'
        if (-not [string]::IsNullOrWhiteSpace($rel)) {
            Assert-True ($rel -notmatch 'Nenhum achado de severidade ALTA ou MEDIA') `
                "o scanner gravou relatorio afirmando ausencia de achado com o git falhando"
        }
    } finally {
        if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "scanner: 'sem commits' de VERDADE continua funcionando, e nao vira erro" {
    # O par negativo dos dois casos acima, e ele importa: sem este caso, uma
    # correcao que fizesse toda falha de rev-parse lancar quebraria o fluxo
    # NORMAL da plataforma - o /os:new-project roda git init e para, e o
    # primeiro checkpoint acontece antes do primeiro commit.
    $fx = New-RepoFixture -SemCommit -IgnorarArtifacts -Arquivos @{ 'a.md' = "# novo`n" }
    try {
        $r = Invoke-Script $Scanner $fx @('-SemRede')
        Assert-True ($r.Exit -ne 2) "repositorio legitimamente sem commits nao deveria dar exit 2, veio $($r.Exit)"
        $rel = Get-Relatorio $fx 'security-report.md'
        Assert-True ($rel -match 'sem nenhum commit') "o relatorio nao declara a ausencia de commits"
    } finally {
        if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "coletor: -Contra com referencia inexistente sai com 2, nao com relatorio errado" {
    # Ref inventada faria o 'git diff' falhar e, sob ErrorActionPreference=Stop,
    # derrubar o script pelo trap - exit 2 sem relatorio, indistinguivel de
    # erro de coleta. Melhor recusar com mensagem.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'a.md' = "# nada`n" }
    try {
        $r = Invoke-Script $Coletor $fx @('-SkipTests', '-Contra', 'nao-existe-esta-ref')
        Assert-True ($r.Exit -eq 2) "esperava exit 2 com referencia inexistente, veio $($r.Exit)"
        Assert-True ($r.Saida -match 'nao existe neste repositorio') "nao explicou o motivo da recusa"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: le criticidade e revisao_independente do project.yaml" {
    $yaml = @"
classificacao:
  criticidade: "alta"
  dados_sensiveis: true
verificacao:
  revisao_independente: "qa+security"
"@
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'project.yaml' = $yaml; 'base.md' = "# base`n" }
    try {
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'criticidade` \| alta')            "nao leu a criticidade"
        Assert-True ($rel -match 'revisao_independente` \| qa\+security') "nao leu revisao_independente"
        Assert-True ($rel -match 'dados_sensiveis` \| true')        "nao leu dados_sensiveis"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: sai com 2 quando o alvo nao e repositorio Git" {
    $t = Join-Path $env:TEMP ("nr2-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    try {
        $r = Invoke-Script $Coletor $t
        Assert-True ($r.Exit -eq 2) "esperava exit 2 fora de repo, veio $($r.Exit)"
    } finally { if (Test-Path $t) { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue } }
}


Test-Caso "coletor: arquivo novo ILEGIVEL como texto vira lacuna, e o carimbo o marca" {
    # Os tres ramos novos do coletor nao tinham caso nenhum - o qa-reviewer
    # deixou a area de cobertura INCONCLUSIVO por isso. Transcrever texto lido
    # com U+FFFD entregaria ao revisor uma versao corrompida do arquivo, e ele
    # nao teria como saber.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        [System.IO.File]::WriteAllBytes((Join-Path $fx 'ansi.md'), ([byte[]](0x61, 0xE7, 0x0A)))
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'nao e legivel como texto') `
            "o coletor nao declarou a lacuna do arquivo ilegivel"
        Assert-True ($rel -match 'ansi\.md') "a lacuna nao nomeia o arquivo"
        Assert-True ($rel -match 'ilegivel como texto\)? \|') `
            "o carimbo nao marcou o arquivo: com numero de linhas ali, o revisor conferiria contra uma contagem derivada de leitura corrompida"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: arquivo novo LEGIVEL continua transcrito e carimbado com numero" {
    # O par negativo do caso acima. Sem ele, um coletor que declarasse todo
    # arquivo ilegivel passaria.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'ok.md'), "# ok`nMARCA-LEGIVEL-ABC`n", (New-Object System.Text.UTF8Encoding($false)))
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'MARCA-LEGIVEL-ABC') "nao transcreveu o conteudo de um arquivo perfeitamente legivel"
        Assert-True ($rel -notmatch 'nao e legivel como texto') "declarou lacuna de codificacao sobre arquivo UTF-8 valido"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}


Test-Caso "coletor: project.yaml ILEGIVEL vira lacuna, e o rigor exigido nao e afirmado" {
    # O outro ramo novo sem caso. O relatorio declara para o revisor qual
    # rigor a revisao exige - criticidade, revisao independente, dados
    # sensiveis. Lidos de um manifesto corrompido, esses tres campos sairiam
    # como '(nao declarada)' sem que ninguem soubesse por que.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        $y = Join-Path $fx 'project.yaml'
        [System.IO.File]::WriteAllText($y, "criticidade: `"alta`"`n", (New-Object System.Text.UTF8Encoding($false)))
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $relOk = Get-Relatorio $fx 'diff-report.md'
        # Ancorado na CELULA da tabela de rigor, e nao na palavra solta: o
        # project.yaml da fixture e arquivo NOVO, entao o coletor transcreve o
        # corpo dele, e 'alta' casava a transcricao em vez da tabela. Mesma
        # vacuidade que a assercao negativa deste caso ja tinha corrigido, no
        # par oposto - achado do qa-reviewer.
        Assert-True ($relOk -match 'classificacao\.criticidade.{0,4}\| alta \|') `
            "o par positivo falhou: a tabela de rigor devia trazer a criticidade lida do manifesto"
        Assert-True ($relOk -notmatch 'nao e legivel como texto') "declarou lacuna sobre manifesto UTF-8 valido"

        [System.IO.File]::WriteAllBytes($y, ([byte[]](0x63, 0x72, 0x69, 0x74, 0x69, 0x63, 0x69, 0x64, 0x61, 0x64, 0x65, 0x3A, 0x20, 0xE7, 0x0A)))
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        # Ancorado no texto da lacuna do MANIFESTO, e nao em 'project.yaml' +
        # 'nao e legivel'. A primeira versao desta assercao casava a lacuna do
        # *arquivo novo* - o mesmo project.yaml, lido pelo outro ramo, que nao
        # e o que este caso existe para cobrir. A mutacao provou: reverter o
        # leitor do manifesto deixava o caso VERDE.
        Assert-True ($rel -match 'criticidade, revisao independente e dados sensiveis NAO foram lidos') `
            "manifesto ilegivel nao virou lacuna: o relatorio diria '(nao declarada)' e o revisor nao saberia se o projeto nao declara ou se a ferramenta nao leu"
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}

Test-Caso "coletor: arquivo novo VAZIO nao ganha linha em branco no bloco transcrito" {
    # Regressao concreta que o qa-reviewer derivou: com UM elemento, a poda
    # do fim de linha virava '\$l[0..-1]', e em PowerShell '0..-1' e @(0,-1) -
    # devolve DOIS elementos. O carimbo dizia '0 linhas' e o bloco mostrava
    # uma, que e a divergencia que faz o revisor concluir 'coleta obsoleta'
    # com a arvore parada.
    $fx = New-RepoFixture -IgnorarArtifacts -Arquivos @{ 'base.md' = "# base`n" }
    try {
        [System.IO.File]::WriteAllBytes((Join-Path $fx 'vazio.md'), (New-Object byte[] 0))
        $null = Invoke-Script $Coletor $fx @('-SkipTests')
        $rel = Get-Relatorio $fx 'diff-report.md'
        Assert-True ($rel -match 'vazio\.md`? \| 0 \| 0 \|') `
            "o carimbo nao registrou o arquivo vazio com 0 bytes e 0 linhas"
        # O bloco transcrito do arquivo VAZIO tem de estar vazio: fence,
        # fence, nada no meio. Com a regressao ele trazia uma linha em
        # branco, contra o '0 linhas' do carimbo - e divergencia entre bloco
        # e carimbo e o sinal que o revisor le como coleta obsoleta.
        $iH = $rel.IndexOf('### `vazio.md`')
        Assert-True ($iH -ge 0) "o arquivo novo vazio nao aparece na secao de arquivos novos"
        $trecho = ($rel.Substring($iH, [Math]::Min(60, $rel.Length - $iH)) -replace "`r", '')
        # O padrao NAO pode ser literal de varias linhas: '.gitattributes'
        # fixa 'eol=crlf' para '.ps1', entao num checkout limpo o literal
        # carrega CRLF enquanto o sujeito acabou de ter o CR removido - o
        # '-match' nao casa e o caso fica VERMELHO com o codigo correto.
        # Achado do qa-reviewer, e a suite inteira deixaria de valer em
        # outra maquina. Escapes '\n' num literal de UMA linha nao tem esse
        # problema: quem interpreta e o regex, nao o parser.
        $padraoVazio = '^### `vazio\.md`\n\n```\n```'
        Assert-True ($trecho -match $padraoVazio) `
            ("o bloco do arquivo VAZIO nao veio vazio. Trecho: '" + ($trecho -replace "`n", '<eol>') + "'")
    } finally { if (Test-Path $fx) { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue } }
}
