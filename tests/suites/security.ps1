<#
.SYNOPSIS
    Suite de testes: Seguranca.

.DESCRIPTION
    O que nunca pode ser versionado, e a politica de ignore.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite security

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite security"
}


Test-Caso "nenhum arquivo sensivel versionado neste repositorio" {
    Push-Location $OsRoot
    try {
        $rastreados = git ls-files 2>$null
        if ($null -eq $rastreados) { return $true }  # ainda sem commits
        $vazando = $rastreados | Where-Object {
            $_ -match '(^|/)\.env$' -or $_ -match '\.(key|pem|pfx|p12)$'
        }
        Assert-True ($vazando.Count -eq 0) ("sensivel versionado: " + ($vazando -join ', '))
    } finally { Pop-Location }
}

Test-Caso "tipos de documento sao bloqueados no template, nao globalmente" {
    # Politica: o .gitignore_global cobre so lixo universal de SO/editor/temp.
    # Bloquear .pdf/.docx/.xlsx e decisao do projeto, e mora no template.
    $txt = Get-Texto (Join-Path $Template '.gitignore')
    foreach ($p in @('*.pdf', '*.docx', '*.xlsx', '*.pptx')) {
        Assert-True ($txt -match [regex]::Escape($p)) "template nao bloqueia $p"
    }
    $global = Join-Path $env:USERPROFILE '.gitignore_global'
    if (Test-Path $global) {
        $g = Get-Texto $global
        $linhas = ($g -split "`n") | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }
        foreach ($proibido in @('*.pdf', '*.docx', '*.xlsx', '*.pptx', '*.png', '*.jpg', '*.csv', '.vscode/', '.idea/')) {
            Assert-True ($linhas -notcontains $proibido) `
                "o .gitignore_global bloqueia '$proibido', que e decisao de projeto"
        }
    }
}

Test-Caso "o .gitignore_global ignora .env mas preserva os arquivos de exemplo" {
    # Excecao deliberada a politica do global (decisao de 2026-09-08).
    # Verificacao funcional pelo proprio git, nao leitura de padrao: ".env.*"
    # casa com ".env.example", ".env.sample" e ".env.template", entao a ordem
    # e a completude das negacoes e o que decide o comportamento real.
    $global = Join-Path $env:USERPROFILE '.gitignore_global'
    if (-not (Test-Path $global)) { return $true }

    $tmp = Join-Path $env:TEMP ("os-env-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        git -C $tmp init -q 2>$null

        $devemSerIgnorados  = @('.env', '.env.local', '.env.production')
        $devemSerVersionados = @('.env.example', '.env.prod.example',
                                 '.env.sample', '.env.dev.sample',
                                 '.env.template', '.env.staging.template')

        foreach ($f in ($devemSerIgnorados + $devemSerVersionados)) {
            Set-Content (Join-Path $tmp $f) '' -Encoding ASCII
        }
        foreach ($f in $devemSerIgnorados) {
            git -C $tmp check-ignore -q $f 2>$null
            Assert-True ($LASTEXITCODE -eq 0) "$f deveria ser ignorado e nao esta"
        }
        foreach ($f in $devemSerVersionados) {
            git -C $tmp check-ignore -q $f 2>$null
            Assert-True ($LASTEXITCODE -ne 0) "$f e arquivo de exemplo e esta sendo ignorado"
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso ".gitignore do OS bloqueia segredos e binarios de Office" {
    $txt = Get-Texto (Join-Path $OsRoot '.gitignore')
    foreach ($p in @('.env', '*.key', '*.xlsx', '*.pdf')) {
        Assert-True ($txt -match [regex]::Escape($p)) "padrao ausente no .gitignore: $p"
    }
}

Test-Caso ".gitignore da RAIZ cobre os 14 nomes canonicos - perguntado ao Git" {
    # O template ganhou teste com check-ignore e a raiz ficou so com regex
    # sobre o texto - a mesma fraqueza que esta subfase repudiou no template.
    # Cenario do qa-reviewer: alguem arruma o .gitignore da raiz e apaga
    # 'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519' e 'service-account.json';
    # todos os testes seguem verdes, e o unico sinal e um achado BAIXA do
    # scanner, que por ADR-0009 NAO trava.
    #
    # A lista e a mesma que scan-gitignore.ps1 pergunta: 14 nomes, nao 12.
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $t = Join-Path $env:TEMP ("rg-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q 2>$null
        git -C $t config core.excludesfile (Join-Path $t '.git/vazio-de-proposito') 2>$null
        Copy-Item (Join-Path $OsRoot '.gitignore') (Join-Path $t '.gitignore')

        foreach ($p in @('.env', '.env.local', '.env.production',
                         'secrets.json', 'secrets.yaml', 'credentials.json',
                         'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519',
                         'chave-privada.pem', 'certificado.pfx',
                         '.msal_cache', 'service-account.json')) {
            $l = @(git -C $t check-ignore -v --no-index --non-matching -- $p 2>$null)
            Assert-True ($l.Count -gt 0) "'$p' nao casou regra nenhuma no .gitignore da raiz"
            $esq = $l[0].Substring(0, $l[0].IndexOf("`t"))
            $m = [regex]::Match($esq, '^(.*):(\d+):(.*)$')
            Assert-True ($m.Success) "saida inesperada do check-ignore para '$p': $($l[0])"
            # Exit 0 significa "alguma regra casou", inclusive negacao: quem
            # decide se esta ignorado e o '!' no inicio do padrao.
            Assert-True (-not $m.Groups[3].Value.StartsWith('!')) `
                "'$p' NAO e ignorado no .gitignore da raiz (regra $($m.Groups[3].Value))"
        }
        # E a excecao deliberada continua valendo.
        $l = @(git -C $t check-ignore -v --no-index --non-matching -- '.env.example' 2>$null)
        $esq = $l[0].Substring(0, $l[0].IndexOf("`t"))
        $pad = ([regex]::Match($esq, '^(.*):(\d+):(.*)$')).Groups[3].Value
        Assert-True ($pad.StartsWith('!')) ".env.example deveria continuar versionavel (regra $pad)"
    } finally {
        $ErrorActionPreference = $anterior
        if (Test-Path $t) { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "nenhum e-mail corporativo vazou para os manifestos publicaveis" {
    # A identidade da plataforma e pessoal de proposito (ADR-0003).
    foreach ($f in @('.claude-plugin\plugin.json', '.claude-plugin\marketplace.json')) {
        $txt = Get-Texto (Join-Path $OsRoot $f)
        Assert-True ($txt -notmatch 'dynatest') "$f contem e-mail/dominio corporativo"
    }
}
