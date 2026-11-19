<#
.SYNOPSIS
    Suite de testes: Template de projeto.

.DESCRIPTION
    O esqueleto dos projetos governados, e a prova de que ele instancia.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite template

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite template"
}

Test-Caso "template tem os arquivos do contrato de portabilidade" {
    $esperados = @('CLAUDE.md', 'README.md', 'project.yaml', 'bootstrap.ps1',
                   '.gitignore', '.gitattributes', '.env.example', 'docs\STATE.md')
    foreach ($f in $esperados) {
        Assert-True (Test-Path (Join-Path $Template $f)) "ausente no template: $f"
    }
}

Test-Caso "project.yaml do template e YAML plausivel e tem os campos-chave" {
    $txt = Get-Texto (Join-Path $Template 'project.yaml')
    foreach ($campo in @('identidade:', 'classificacao:', 'versionamento:', 'verificacao:', 'execucao:', 'portfolio:')) {
        Assert-True ($txt -match [regex]::Escape($campo)) "campo ausente: $campo"
    }
    # Comentario de YAML e '#', nunca '//'
    Assert-True ($txt -notmatch '(?m)^\s*//') "usa '//' como comentario, que nao e YAML"
}

Test-Caso ".gitignore do template bloqueia .env mas preserva .env.example" {
    $txt = Get-Texto (Join-Path $Template '.gitignore')
    Assert-True ($txt -match '(?m)^\.env$')          ".env nao esta bloqueado"
    Assert-True ($txt -match '(?m)^!\.env\.example$') ".env.example nao esta preservado"
}

Test-Caso "template traz CHANGELOG.md (o /os:checkpoint manda atualiza-lo)" {
    # Achado no teste de aceitacao da Fase 1: a skill exigia um arquivo que o
    # template nao criava, e ele teve que ser escrito a mao.
    Assert-True (Test-Path (Join-Path $Template 'CHANGELOG.md')) `
        "template sem CHANGELOG.md, mas a skill de checkpoint exige"
}

Test-Caso "project.yaml do template usa SemVer de tres componentes (ADR-0006)" {
    $txt = Get-Texto (Join-Path $Template 'project.yaml')
    $v = ([regex]::Match($txt, '(?m)^\s*versao:\s*"([^"]+)"')).Groups[1].Value
    Assert-True ($v -match '^\d+\.\d+\.\d+$') "versao e '$v', esperado MAJOR.MINOR.PATCH"
}

Test-Caso ".gitignore do template libera examples/ para dado de exemplo" {
    # Sem isto o comando do README aponta para um arquivo que nao existe no clone.
    $txt = Get-Texto (Join-Path $Template '.gitignore')
    Assert-True ($txt -match '(?m)^!/examples/') "template nao libera examples/"
}

Test-Caso "gitignore do template: examples/ libera exemplo em TEXTO e barra binario de escritorio" {
    # PERGUNTANDO AO GIT, nao lendo o arquivo. O Git aplica o ULTIMO padrao
    # que casa, e ate a subfase 2.3 o bloco de binarios vinha ANTES da
    # negacao de examples/: 'examples/planilha.xlsx' e 'examples/relatorio.pdf'
    # NAO eram ignorados em nenhum projeto instanciado deste template, e o
    # unico guarda-corpo contra commitar planilha real era um comentario.
    # Achado do security-reviewer na 2.3. Ler o texto do .gitignore nunca
    # mostraria isso - so check-ignore mostra.
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $t = Join-Path $env:TEMP ("tg-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q 2>$null
        git -C $t config core.excludesfile (Join-Path $t '.git/vazio-de-proposito') 2>$null
        Copy-Item (Join-Path $Template '.gitignore') (Join-Path $t '.gitignore')

        function Test-Ignorado {
            param([string]$Repo, [string]$Caminho)
            $l = @(git -C $Repo check-ignore -v --no-index --non-matching -- $Caminho 2>$null)
            if ($l.Count -eq 0) { return $false }
            $esq = $l[0].Substring(0, $l[0].IndexOf("`t"))
            $m = [regex]::Match($esq, '^(.*):(\d+):(.*)$')
            if (-not $m.Success) { return $false }
            # Exit 0 significa "alguma regra casou", inclusive negacao. Quem
            # decide se esta ignorado e o '!' no inicio do padrao.
            return (-not $m.Groups[3].Value.StartsWith('!'))
        }

        foreach ($p in @('examples/planilha.xlsx', 'examples/relatorio.pdf',
                         'examples/sub/planilha.xlsx', 'examples/slides.pptx',
                         'relatorio.xlsx', 'dados.csv', 'examples/.env')) {
            Assert-True (Test-Ignorado $t $p) "'$p' deveria estar IGNORADO e nao esta"
        }
        foreach ($p in @('examples/notas.md', 'examples/dados.json')) {
            Assert-True (-not (Test-Ignorado $t $p)) "'$p' deveria estar LIBERADO e esta ignorado"
        }

        # CSV em examples/ so em diretorio DECLARADO de dado sintetico.
        # Decisao da Emmily na subfase 2.3: a negacao ampla liberava qualquer
        # csv dentro de examples/, e CSV e o formato mais provavel de um
        # extrato operacional real - o unico guarda-corpo era o comentario,
        # a mesma forma do defeito que o security-reviewer achou com '.xlsx'.
        # Agora o CAMINHO e o guarda-corpo.
        foreach ($p in @('examples/dados.csv', 'examples/sub/dados.csv', 'dados.csv')) {
            Assert-True (Test-Ignorado $t $p) "'$p' deveria estar IGNORADO: csv so em fixtures/ ou synthetic/"
        }
        foreach ($p in @('examples/fixtures/dados.csv', 'examples/synthetic/dados.csv',
                         'examples/fixtures/sub/dados.csv')) {
            Assert-True (-not (Test-Ignorado $t $p)) "'$p' deveria estar LIBERADO: e diretorio declarado de dado sintetico"
        }
        # E binario de escritorio continua barrado mesmo la dentro.
        Assert-True (Test-Ignorado $t 'examples/fixtures/planilha.xlsx') `
            "planilha em fixtures/ deveria continuar ignorada"

        # Os 12 nomes canonicos de segredo, os mesmos que scan-gitignore.ps1
        # pergunta - mas ele so pergunta na RAIZ do repositorio varrido, e
        # este .gitignore e aninhado dentro da plataforma. Sem este bloco,
        # nada provava que um projeto instanciado ignora estes nomes: eles
        # tinham entrado no template por analogia. Achado do qa-reviewer.
        foreach ($p in @('.env', '.env.local', '.env.production',
                         'secrets.json', 'secrets.yaml', 'credentials.json',
                         'id_rsa', 'id_ed25519', 'chave-privada.pem',
                         'certificado.pfx', '.msal_cache', 'service-account.json')) {
            Assert-True (Test-Ignorado $t $p) "segredo canonico '$p' NAO e ignorado num projeto instanciado deste template"
        }
        # E a excecao que existe de proposito continua valendo.
        Assert-True (-not (Test-Ignorado $t '.env.example')) ".env.example deveria continuar versionavel"
    } finally {
        $ErrorActionPreference = $anterior
        if (Test-Path $t) { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "bootstrap do template cria venv e instala dependencias" {
    $txt = Get-Texto (Join-Path $Template 'bootstrap.ps1')
    Assert-True ($txt -match '-m venv')      "bootstrap nao cria .venv"
    Assert-True ($txt -match 'requirements') "bootstrap nao le requirements.txt"
}

Test-Caso "template instancia: copia + substituicao + bootstrap -Check roda" {
    $tmp = Join-Path $env:TEMP ("os-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        Copy-Item $Template $tmp -Recurse -Force

        # Substituicao dos placeholders, como /os:new-project fara.
        $valores = @{
            '{{PROJECT_NAME}}'  = 'projeto-teste'
            '{{PROJECT_TITLE}}' = 'Projeto Teste'
            '{{PROJECT_DESC}}'  = 'Instancia descartavel criada pelos testes.'
            '{{DATE}}'          = (Get-Date -Format 'yyyy-MM-dd')
            '{{PYTHON}}'        = 'nao-usa'
            '{{REMOTO}}'        = 'nenhum'
        }
        Get-ChildItem $tmp -Recurse -File -Include '*.md', '*.yaml', '*.ps1' | ForEach-Object {
            $t = Get-Content $_.FullName -Raw
            foreach ($k in $valores.Keys) { $t = $t.Replace($k, $valores[$k]) }
            Set-Content $_.FullName $t -Encoding UTF8
        }

        $bootstrap = Join-Path $tmp 'bootstrap.ps1'
        Assert-True (Test-Path $bootstrap) "bootstrap.ps1 nao veio na copia"

        # Deve rodar sem excecao. Sai != 0 se detectar bloqueio, o que aqui e
        # esperado (a copia nao e repositorio Git) - o que importa e nao quebrar.
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File $bootstrap -Check 2>&1 | Out-String
        Assert-True ($saida -match 'resumo') "bootstrap nao chegou ao resumo. Saida: $saida"
        Assert-True ($saida -notmatch 'ParserError') "bootstrap tem erro de sintaxe. Saida: $saida"

        # E precisa DETECTAR a ausencia de repositorio, nao passar batido.
        Assert-True ($saida -match 'sem repositorio Git') "bootstrap nao detectou a ausencia de repositorio Git"
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# =============================================================================
