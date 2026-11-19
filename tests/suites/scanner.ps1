<#
.SYNOPSIS
    Suite de testes: os quatro detectores da subfase 2.3 FAZEM o que dizem.

.DESCRIPTION
    Historico do Git, .gitignore regra por regra, dado de terceiro e
    exposicao externa. Cada detector com par positivo e negativo, como a
    politica 4.1 exige: o positivo evita o detector que nunca grita, o
    negativo evita o que grita sempre.

    Duas camadas, de proposito:

      UNITARIA  - as funcoes puras de scripts/lib/ chamadas direto. E por
                  isso que os detectores viraram funcoes puras: da para
                  provar o digito verificador sem montar repositorio.
      FUNCIONAL - o script EXECUTADO contra repositorio de verdade em
                  $env:TEMP, com commit, apagamento de arquivo e .gitignore
                  proprio. Nada e escrito fora de $env:TEMP.

    Este arquivo contem, de proposito, strings em formato de credencial, uma
    URL de webhook e um CPF com digito verificador valido. Todas inventadas.
    O marcador abaixo esta no CABECALHO porque e ali que uma declaracao vale
    (ver Test-DeclaraFixture): ele faz o scanner RECLASSIFICAR os achados
    deste arquivo para BAIXA, e nao silencia nenhum.

      SEGREDO-FABRICADO-PARA-TESTE

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite scanner

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite scanner"
}

$Scanner = Join-Path $OsRoot 'scripts\security-scan.ps1'
$LibDir  = Join-Path $OsRoot 'scripts\lib'

foreach ($m in @('scan-comum.ps1', 'scan-historico.ps1', 'scan-gitignore.ps1',
                 'scan-dado-pessoal.ps1', 'scan-exposicao.ps1', 'scan-excecoes.ps1')) {
    . (Join-Path $LibDir $m)
}

# CPF e CNPJ fabricados, com digito verificador valido - sao os numeros de
# teste classicos, nao pertencem a ninguem.
$CPF_VALIDO   = '123.456.789-09'
$CPF_INVALIDO = '123.456.789-00'
$CNPJ_VALIDO  = '11.222.333/0001-81'
$TOKEN_FALSO  = 'ghp_HISTORICOFABRICADO1234'
$WEBHOOK_FALSO = 'https://hooks.slack.com/services/T00000000/B00000000/abcdefghijklmnop'

function New-RepoFx2 {
    <#
      Repositorio descartavel em $env:TEMP.
      -Passos: lista de hashtables, uma por commit:
         @{ Escreve = @{ 'a.py' = 'conteudo' }; Apaga = @('b.py') }
      -Gitignore: conteudo do .gitignore da raiz (aplicado antes do 1o commit)
      -Excludesfile: caminho de um arquivo de exclusao FORA do repositorio
      -SemCommit: nao commita nada
      -Pasta: caminho exato do repositorio a criar (item 156: alvo com
              espaco e acento no caminho). Sem isto, $env:TEMP\sc-<guid>.
    #>
    param(
        [hashtable[]]$Passos = @(),
        [string]$Gitignore = "/artifacts/*`n",
        [string]$Excludesfile,
        [switch]$SemCommit,
        [string]$Pasta
    )
    # git escreve aviso de CRLF em stderr, e no 5.1 stderr de executavel
    # nativo vira ErrorRecord: sob ErrorActionPreference=Stop isso aborta o
    # teste com uma mensagem sobre fim de linha que nao tem relacao com o que
    # se testa. Duas defesas: desligar a conversao no fixture e nao tratar
    # stderr como terminante aqui.
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $t = Join-Path $env:TEMP ("sc-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
        if ($Pasta) { $t = $Pasta }
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q 2>$null
        git -C $t config user.name  'Fixture'    2>$null
        git -C $t config user.email 'fx@invalid' 2>$null
        git -C $t config core.autocrlf false     2>$null
        git -C $t config core.safecrlf false     2>$null
        # Isola do .gitignore_global da maquina: sem isto um fixture com .env
        # nao consegue rastrear o .env, e o detector nao pode ser exercitado.
        if ($Excludesfile) {
            git -C $t config core.excludesfile $Excludesfile 2>$null
        } else {
            git -C $t config core.excludesfile (Join-Path $t '.git/vazio-de-proposito') 2>$null
        }
        # IsNullOrEmpty, nao '$null -ne': o parametro e [string], e o PowerShell
        # converte $null em '' - '-Gitignore $null' gravava um .gitignore VAZIO, e o
        # caso 'alvo sem .gitignore' do item 157 nao existia de verdade.
        if (-not [string]::IsNullOrEmpty($Gitignore)) {
            [System.IO.File]::WriteAllText((Join-Path $t '.gitignore'), $Gitignore, (New-Object System.Text.UTF8Encoding($false)))
        }
        foreach ($p in $Passos) {
            if ($p.Escreve) {
                foreach ($nome in $p.Escreve.Keys) {
                    $dest = Join-Path $t $nome
                    $pai = Split-Path -Parent $dest
                    if ($pai -and -not (Test-Path $pai)) { New-Item -ItemType Directory -Path $pai -Force | Out-Null }
                    [System.IO.File]::WriteAllText($dest, $p.Escreve[$nome], (New-Object System.Text.UTF8Encoding($false)))
                }
            }
            if ($p.Apaga) {
                foreach ($nome in $p.Apaga) {
                    $dest = Join-Path $t $nome
                    if (Test-Path $dest) { Remove-Item $dest -Force }
                }
            }
            if (-not $SemCommit) {
                git -C $t add -A 2>$null
                git -C $t commit -q -m 'passo' 2>$null
            }
        }
        if ($Passos.Count -eq 0 -and -not $SemCommit) {
            git -C $t add -A 2>$null
            git -C $t commit -q -m 'inicial' 2>$null
        }
        return $t
    } finally { $ErrorActionPreference = $anterior }
}

function Invoke-Scan {
    param([string]$Repo, [string[]]$Extra = @(), [string]$ScriptAlternativo)
    $s = $Scanner
    if ($ScriptAlternativo) { $s = $ScriptAlternativo }
    $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $s, '-Path', $Repo) + $Extra
    $saida = (& powershell @argumentos 2>&1 | Out-String)
    return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
}

function Get-Rel {
    param([string]$Repo)
    $p = Join-Path $Repo 'artifacts\review\security-report.md'
    if (-not (Test-Path $p)) { return $null }
    return Get-Texto $p
}

function Remove-Fx {
    param([string]$Caminho)
    if ($Caminho -and (Test-Path $Caminho)) {
        Remove-Item $Caminho -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# UNITARIA - digito verificador
# =============================================================================

Test-Caso "CPF: aceita digito verificador valido e rejeita o invalido" {
    Assert-True (Test-CPF '12345678909') "nao aceitou um CPF com digito valido"
    Assert-True (-not (Test-CPF '12345678900')) "aceitou um CPF com digito INVALIDO"
}

Test-Caso "CPF: rejeita sequencia repetida, que passa na conta mas nunca e real" {
    Assert-True (-not (Test-CPF '11111111111')) "aceitou 111.111.111-11"
    Assert-True (-not (Test-CPF '00000000000')) "aceitou 000.000.000-00"
}

Test-Caso "CPF: rejeita o que nao tem 11 digitos" {
    Assert-True (-not (Test-CPF '1234567890'))  "aceitou 10 digitos"
    Assert-True (-not (Test-CPF '123456789099')) "aceitou 12 digitos"
    Assert-True (-not (Test-CPF 'abcdefghijk')) "aceitou letras"
}

Test-Caso "CNPJ: aceita digito verificador valido e rejeita o invalido" {
    Assert-True (Test-CNPJ '11222333000181') "nao aceitou um CNPJ com digito valido"
    Assert-True (-not (Test-CNPJ '11222333000180')) "aceitou um CNPJ com digito INVALIDO"
    Assert-True (-not (Test-CNPJ '11111111111111')) "aceitou sequencia repetida"
}

# =============================================================================
# UNITARIA - dado pessoal
# =============================================================================

Test-Caso "dado pessoal: ACUSA CPF valido e NAO acusa CPF de digito errado" {
    $comValido = Find-DadoPessoalEmTexto -Texto ("Cliente: " + $CPF_VALIDO) -Origem 'x.md' -Identidades @()
    Assert-True (@($comValido | Where-Object { $_.Categoria -like 'CPF*' }).Count -eq 1) `
        "nao acusou o CPF valido"
    $comInvalido = Find-DadoPessoalEmTexto -Texto ("Cliente: " + $CPF_INVALIDO) -Origem 'x.md' -Identidades @()
    Assert-True (@($comInvalido | Where-Object { $_.Categoria -like 'CPF*' }).Count -eq 0) `
        "acusou um CPF com digito INVALIDO - o detector viraria gerador de ruido"
}

Test-Caso "dado pessoal: 11 digitos soltos NAO viram CPF sem a palavra por perto" {
    # '12345678909' e um CPF valido. Solto, num texto qualquer, poderia ser
    # protocolo, telefone ou timestamp: nao basta o digito fechar.
    $r = Find-DadoPessoalEmTexto -Texto "protocolo 12345678909 recebido" -Origem 'x.md' -Identidades @()
    Assert-True (@($r | Where-Object { $_.Categoria -like 'CPF*' }).Count -eq 0) `
        "acusou 11 digitos soltos como CPF"
    # Com a palavra CPF por perto, acusa.
    $r2 = Find-DadoPessoalEmTexto -Texto "CPF: 12345678909" -Origem 'x.md' -Identidades @()
    Assert-True (@($r2 | Where-Object { $_.Categoria -like 'CPF*' }).Count -eq 1) `
        "nao acusou CPF anunciado pela palavra-chave"
}

Test-Caso "dado pessoal: ACUSA telefone pontuado e NAO acusa numero solto" {
    $r = Find-DadoPessoalEmTexto -Texto "ligar para (62) 99999-1234" -Origem 'x.md' -Identidades @()
    Assert-True (@($r | Where-Object { $_.Categoria -eq 'telefone' }).Count -eq 1) "nao acusou o telefone"
    $r2 = Find-DadoPessoalEmTexto -Texto "faixa 2026-0908 e intervalo 1234-5678" -Origem 'x.md' -Identidades @()
    Assert-True (@($r2 | Where-Object { $_.Categoria -eq 'telefone' }).Count -eq 0) `
        "acusou numero solto como telefone"
}

Test-Caso "dado pessoal: CEP so conta com a palavra CEP por perto" {
    $r = Find-DadoPessoalEmTexto -Texto "CEP 74000-000" -Origem 'x.md' -Identidades @()
    Assert-True (@($r | Where-Object { $_.Categoria -like '*CEP*' }).Count -eq 1) "nao acusou o CEP anunciado"
    $r2 = Find-DadoPessoalEmTexto -Texto "codigo da peca 74000-000" -Origem 'x.md' -Identidades @()
    Assert-True (@($r2 | Where-Object { $_.Categoria -like '*CEP*' }).Count -eq 0) `
        "acusou um codigo de peca como CEP"
}

Test-Caso "dado pessoal: CNPJ valido e BAIXA - registro publico nao trava" {
    $r = Find-DadoPessoalEmTexto -Texto ("Contratada CNPJ " + $CNPJ_VALIDO) -Origem 'x.md' -Identidades @()
    $c = @($r | Where-Object { $_.Categoria -like 'CNPJ*' })
    Assert-True ($c.Count -eq 1) "nao acusou o CNPJ valido"
    Assert-True ($c[0].Severidade -eq 'BAIXA') "classificou CNPJ como $($c[0].Severidade), deveria ser BAIXA"
}

Test-Caso "dado pessoal: e-mail do autor e BAIXA, e-mail de terceiro e MEDIA" {
    $txt = "autor: dono@exemplo-real.com e contato: outro@empresa-terceira.com.br"
    $r = Find-DadoPessoalEmTexto -Texto $txt -Origem 'x.md' -Identidades @('dono@exemplo-real.com')
    $autor = @($r | Where-Object { $_.Categoria -like '*identidade do proprio*' })
    # O rotulo diz o que o detector SABE: "nao assina commits deste
    # repositorio". Um segundo endereco da MESMA pessoa nunca pode ser
    # reconhecido por identidade derivada do git log, e chamar isso de
    # "terceiro" apontava a remediacao errada.
    $terc  = @($r | Where-Object { $_.Categoria -eq 'e-mail que nao assina commits deste repositorio' })
    Assert-True ($autor.Count -eq 1) "nao classificou o e-mail do autor"
    Assert-True ($autor[0].Severidade -eq 'BAIXA') "e-mail do autor deveria ser BAIXA"
    Assert-True ($terc.Count -eq 1) "nao acusou o e-mail que nao assina commits"
    Assert-True ($terc[0].Severidade -eq 'MEDIA') "deveria ser MEDIA"
}

Test-Caso "dado pessoal: e-mail de placeholder de documentacao NAO e achado" {
    $txt = "use user@example.com, noreply@qualquer.com.br ou fx@invalid"
    $r = Find-DadoPessoalEmTexto -Texto $txt -Origem 'x.md' -Identidades @()
    Assert-True (@($r | Where-Object { $_.Categoria -like 'e-mail*' }).Count -eq 0) `
        "acusou placeholder de documentacao como dado de terceiro"
}

Test-Caso "dado pessoal: NUNCA transcreve o valor, so a localizacao" {
    $txt = "CPF " + $CPF_VALIDO + " tel (62) 99999-1234 mail joao.silva@empresa-terceira.com.br"
    $r = Find-DadoPessoalEmTexto -Texto $txt -Origem 'x.md' -Identidades @()
    Assert-True ($r.Count -ge 3) "esperava tres achados, veio $($r.Count)"
    foreach ($a in $r) {
        Assert-True ($a.Detalhe -notmatch '12345678909') "transcreveu os digitos do CPF"
        Assert-True ($a.Detalhe -notmatch '99999-1234')  "transcreveu o telefone"
        Assert-True ($a.Detalhe -notmatch 'joao\.silva') "transcreveu a parte local do e-mail"
    }
}

# =============================================================================
# UNITARIA - marcador de fixture: declarar nao e mencionar
# =============================================================================

Test-Caso "extensao de texto: arquivo de ponto e classificado pela EXTENSAO, nao pelo nome" {
    # Medido: para o .NET, 'GetExtension(".npmrc")' devolve '.npmrc', nao
    # string vazia. Uma versao anterior punha '.npmrc' na lista de
    # nomes-SEM-extensao, e aquele ramo nunca rodava - codigo morto que
    # parecia ter fechado uma observacao do security-reviewer e nao tinha.
    Assert-True (Test-ArquivoDeTexto '.npmrc')  "'.npmrc' deveria ter o conteudo examinado"
    Assert-True (Test-ArquivoDeTexto '.netrc')  "'.netrc' deveria ter o conteudo examinado"
    Assert-True (Test-ArquivoDeTexto 'logs/.gitkeep') "'.gitkeep' deveria ser reconhecido como texto"
    Assert-True (Test-ArquivoDeTexto 'Jenkinsfile') "nome sem ponto deveria continuar reconhecido"
    # E o par negativo: binario continua fora.
    Assert-True (-not (Test-ArquivoDeTexto 'planilha.xlsx')) "binario de Office nao deveria ser lido como texto"
    Assert-True (-not (Test-ArquivoDeTexto 'deploy.bin')) "extensao desconhecida nao deveria ser lida"
}

Test-Caso "arquivo de texto: nome SEM extensao e decidido pelo CONTEUDO, nao por lista" {
    # A lista de nomes falhou TRES vezes pelo mesmo motivo - '.npmrc',
    # '.gitkeep', e os shims de githooks/, que sao os primeiros arquivos sem
    # extensao que este repositorio versiona E os que executam a cada commit.
    # Eles sairam do coletor como "nao e texto reconhecido": os revisores nao
    # veriam o codigo que roda na maquina da mantenedora.
    #
    # A pergunta mudou: sem extensao e fora da lista de nomes, decide o
    # CONTEUDO - byte NUL nos primeiros 8 KB significa binario, que e como o
    # proprio Git decide.
    $dir = Join-Path $env:TEMP ("txt-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        [System.IO.File]::WriteAllText((Join-Path $dir 'meu-hook'), "#!/bin/sh`nexec algo`n", (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllBytes((Join-Path $dir 'binario-sem-ext'), [byte[]](0x50, 0x4B, 0x03, 0x04, 0x00, 0x01))

        Assert-True (Test-ArquivoDeTexto 'meu-hook' -Raiz $dir) `
            "arquivo SEM extensao e com conteudo de texto deveria ser lido"
        Assert-True (-not (Test-ArquivoDeTexto 'binario-sem-ext' -Raiz $dir)) `
            "arquivo SEM extensao e com NUL deveria continuar fora"
        # Fail-closed: o que nao da para abrir nao vira 'e texto'.
        Assert-True (-not (Test-ArquivoDeTexto 'nao-existe-nenhum' -Raiz $dir)) `
            "nome sem extensao que nao existe no disco deveria devolver falso"
        # Sem -Raiz, caminho relativo nao e resolvido contra o diretorio
        # corrente: seria ler arquivo de outro lugar por acidente.
        Assert-True (-not (Test-ArquivoDeTexto 'meu-hook')) `
            "sem -Raiz o caminho relativo nao deveria ser resolvido"
    } finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "arquivo de texto: os shims REAIS de githooks/ sao reconhecidos" {
    # O caso acima prova a regra; este prova que ela alcanca os arquivos que
    # motivaram a mudanca. Sem ele, a regra poderia estar certa e os shims
    # continuarem fora por outro motivo - nome, caminho, ou a pasta.
    $raiz = $OsRoot
    foreach ($nome in @('commit-msg', 'pre-commit', 'pre-push')) {
        Assert-True (Test-ArquivoDeTexto "githooks/$nome" -Raiz $raiz) `
            "o shim 'githooks/$nome' nao seria lido como texto - revisor nao veria o que roda a cada commit"
    }
}

Test-Caso "extensao de texto: conteudo de .npmrc E examinado, credencial dentro dele ACUSA" {
    # A observacao do security-reviewer, agora fechada de verdade: o que
    # importa e o CONTEUDO. Pelo nome, '.npmrc' sem token e comum e legitimo -
    # acusar pelo nome seria gerador de falso positivo.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        '.npmrc' = "//registry.npmjs.org/:_authToken=" + $TOKEN_FALSO + "`n"
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'possivel token do GitHub') "nao leu o conteudo do .npmrc"
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
        Assert-True ($rel -notmatch 'HISTORICOFABRICADO') "transcreveu o valor do token"
    } finally { Remove-Fx $fx }
}

Test-Caso "marcador: DECLARADO no cabecalho reclassifica; MENCIONADO no meio nao" {
    # Este e o furo que a propria varredura da 2.3 encontrou: CHANGELOG.md e
    # STATE.md citam o marcador para documentar a convencao, e a checagem por
    # Contains() no arquivo inteiro reclassificava os achados dos dois.
    # Qualquer arquivo poderia desarmar o scanner sobre si mesmo.
    $m = Get-MarcadorFixture
    $cabecalho = "# " + $m + "`n" + ("linha`n" * 5) + "CPF: " + $CPF_VALIDO
    $meio = ("linha`n" * 60) + "texto que cita " + $m + " em prosa`n" + "CPF: " + $CPF_VALIDO

    Assert-True (Test-DeclaraFixture $cabecalho) "nao reconheceu declaracao no cabecalho"
    Assert-True (-not (Test-DeclaraFixture $meio)) "aceitou MENCAO no meio do arquivo como declaracao"

    $rC = Find-DadoPessoalEmTexto -Texto $cabecalho -Origem 'fx.md' -Identidades @()
    $rM = Find-DadoPessoalEmTexto -Texto $meio -Origem 'doc.md' -Identidades @()
    Assert-True (@($rC | Where-Object { $_.Categoria -like 'fixture declarada*' }).Count -eq 1) `
        "declaracao no cabecalho nao reclassificou"
    Assert-True (@($rM | Where-Object { $_.Severidade -eq 'MEDIA' }).Count -eq 1) `
        "mencao no meio reclassificou - o scanner pode ser desarmado por prosa"
}

Test-Caso "marcador: reclassifica, NUNCA silencia - o achado continua no relatorio" {
    $m = Get-MarcadorFixture
    $txt = "# " + $m + "`nCPF: " + $CPF_VALIDO
    # @() obrigatorio: funcao que devolve UM PSCustomObject nao tem .Count no
    # PowerShell 5.1 - '$r.Count' vem vazio e '$null -ge 1' e falso. Este
    # teste falhou por isso, apontando "silenciou" quando o detector estava
    # correto. Sempre embrulhe a saida antes de contar.
    $r = @(Find-DadoPessoalEmTexto -Texto $txt -Origem 'fx.md' -Identidades @())
    Assert-True ($r.Count -ge 1) "silenciou o achado em vez de reclassificar"
    Assert-True ($r[0].Severidade -eq 'BAIXA') "nao reclassificou para BAIXA"
}

# =============================================================================
# UNITARIA - sonda do .gitignore
# =============================================================================

Test-Caso "sonda: deriva caminho concreto para as formas comuns de regra" {
    Assert-True ((Get-SondaParaRegra -Regra '*.pem').Sonda -match '\.pem$') "nao derivou sonda para '*.pem'"
    Assert-True ((Get-SondaParaRegra -Regra 'node_modules/').Sonda -match '^node_modules/') "nao derivou sonda para diretorio"
    Assert-True ((Get-SondaParaRegra -Regra '/logs/*').Sonda -match '^logs/') "nao derivou sonda para '/logs/*'"
    Assert-True ((Get-SondaParaRegra -Regra '*token*').Sonda -match 'token') "nao derivou sonda para '*token*'"
    Assert-True ((Get-SondaParaRegra -Regra '.env').Sonda -eq '.env') "nao derivou sonda para nome literal"
    $neg = Get-SondaParaRegra -Regra '!.env.example'
    Assert-True ($neg.Negacao -and $neg.Sonda -eq '.env.example') "nao tratou negacao"
}

Test-Caso "sonda: devolve nada quando nao da para derivar sem chutar" {
    # Chutar aqui produziria 'regra sem efeito' falso, que e pior que
    # declarar a lacuna. Politica 4.5.
    #
    # Este caso EXIGIA null para classe de caractere, '**' e '?' ate a
    # extensao da sonda desta subfase. Agora as tres formas sao sondaveis (ver
    # o caso "sonda alcanca '**' e classe de caractere"), e o que sobra sem
    # representacao honesta e: classe NEGADA, onde o primeiro caractere nao e
    # membro, e as formas de '**' que nao sao nem sufixo nem separador de
    # diretorio.
    Assert-True ($null -eq (Get-SondaParaRegra -Regra '*.py[!co]')) "chutou sonda para classe negada"
    Assert-True ($null -eq (Get-SondaParaRegra -Regra '*.py[^co]')) "chutou sonda para classe negada com circunflexo"
    Assert-True ($null -eq (Get-SondaParaRegra -Regra '**/foo')) "chutou sonda para '**' no inicio"
    Assert-True ($null -eq (Get-SondaParaRegra -Regra 'a/**b')) "chutou sonda para '**' colado no nome"
    Assert-True ($null -eq (Get-SondaParaRegra -Regra '[abc')) "chutou sonda para classe sem fechamento"
}

Test-Caso "sonda: prefixo do subdiretorio entra no caminho" {
    $s = Get-SondaParaRegra -Regra '*.log' -Prefixo 'sub/dir'
    Assert-True ($s.Sonda -match '^sub/dir/') "nao aplicou o prefixo do .gitignore aninhado"
}

# =============================================================================
# FUNCIONAL - historico do Git
# =============================================================================

Test-Caso "historico: ACUSA segredo em arquivo APAGADO depois - o falso negativo classico" {
    # O caso que faz este detector existir: apagar o arquivo e commitar NAO
    # remove o blob. Varredura de working tree diria 'limpo'.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'config.py' = "TOKEN = '" + $TOKEN_FALSO + "'`n" } },
        @{ Apaga   = @('config.py') }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($null -ne $rel) "nao gravou relatorio"
        Assert-True ($rel -match 'token do GitHub no historico') "nao acusou o token no historico"
        Assert-True ($rel -match 'config\.py') "nao apontou o arquivo apagado"
        Assert-True ($r.Exit -eq 1) "esperava exit 1 com achado ALTA, veio $($r.Exit)"
        Assert-True ($rel -notmatch 'HISTORICOFABRICADO') "o relatorio TRANSCREVEU o valor do token"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: ACUSA nome sensivel que existiu e foi removido" {
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ '.env' = "API_KEY=qualquer`n" } },
        @{ Apaga   = @('.env') }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'arquivo sensivel no historico') "nao acusou o .env que existiu"
        Assert-True ($rel -match 'viaja em todo clone') "nao explicou por que isso importa"
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: repo sem segredo nenhum NAO acusa nada no historico" {
    # O par negativo do detector de historico.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'a.py' = "def f():`n    return 1`n" } },
        @{ Escreve = @{ 'b.md' = "# doc`nnada sensivel`n" } }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -notmatch 'no historico') "acusou algo no historico de um repo limpo"
        Assert-True ($rel -match '\| historico \| sim \|') "nao declarou o historico como coberto"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: dado pessoal que segue no working tree NAO e contado duas vezes" {
    # O bug que este caso existe para impedir: as chaves de deduplicacao do
    # working tree eram populadas SO pela varredura de credencial, no formato
    # 'caminho|nome-do-padrao'. O detector de historico montava
    # 'caminho|categoria-de-dado-pessoal' e testava naquela lista - espacos de
    # chave disjuntos, condicao inalcancavel, dedup morta para todo dado
    # pessoal.
    #
    # E o dano nao era estetico: a area 'historico' exibia o achado como se a
    # exposicao fosse SO no historico, e exposicao so no historico tem
    # remediacao destrutiva e diferente (filter-repo + push --force) da de um
    # arquivo que ainda esta no disco. Nenhum teste cobria isso.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'contatos.md' = "contato: alguem@empresa-terceira.com.br`n" } },
        @{ Escreve = @{ 'outro.md'    = "# so para criar um segundo commit`n" } }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $nWT   = @([regex]::Matches($rel, '\| dado de terceiro \| e-mail que nao assina commits deste repositorio \|')).Count
        $nHist = @([regex]::Matches($rel, 'e-mail que nao assina commits deste repositorio no historico')).Count
        Assert-True ($nWT -eq 1) "esperava 1 achado no working tree, veio $nWT"
        Assert-True ($nHist -eq 0) `
            "o mesmo e-mail foi repetido como achado de historico ($nHist), sugerindo exposicao exclusiva no historico"
        Assert-True ($rel -match 'suprimidas por coincidir com o working tree: [1-9]') `
            "a coincidencia foi suprimida sem ser contada - suprimir sem contar e esconder"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: dado pessoal APAGADO do working tree continua acusado" {
    # O par do caso acima, na outra direcao: a dedup nao pode engolir o que
    # so existe no historico, que e justamente o achado de maior valor.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'contatos.md' = "contato: alguem@empresa-terceira.com.br`n" } },
        @{ Apaga   = @('contatos.md') }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'e-mail que nao assina commits deste repositorio no historico') `
            "nao acusou o e-mail que so existe no historico"
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: -SemHistorico declara a LACUNA em vez de fingir cobertura" {
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'config.py' = "TOKEN = '" + $TOKEN_FALSO + "'`n" } },
        @{ Apaga   = @('config.py') }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemHistorico', '-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match '\| historico \| \*\*NAO\*\* \|') "nao declarou o historico como NAO coberto"
        Assert-True ($rel -match 'INCONCLUSIVO') "nao disse que a area fica INCONCLUSIVO"
        Assert-True ($rel -notmatch 'token do GitHub no historico') "varreu o historico apesar do -SemHistorico"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: repo SEM NENHUM COMMIT nao quebra e declara historico vazio" {
    # Fluxo normal do /os:new-project: git init e para.
    $fx = New-RepoFx2 -SemCommit -Passos @(@{ Escreve = @{ 'a.py' = "x = 1`n" } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($null -ne $rel) "nao gravou relatorio em repo sem commits"
        Assert-True ($rel -match 'sem nenhum commit') "nao declarou a ausencia de historico"
        Assert-True ($r.Exit -ne 2) "quebrou com exit 2 em repo sem commits"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# FUNCIONAL - .gitignore regra por regra
# =============================================================================

Test-Caso "historico: MESMO blob em DOIS caminhos aponta os dois" {
    # 'git mv' com o segredo dentro: conteudo identico, um unico sha, dois
    # caminhos. A versao anterior guardava um caminho representativo por sha,
    # sorteado pela ordem indefinida de uma hashtable - se o sorteado fosse o
    # que ainda esta rastreado, o achado era deduplicado e o relatorio NUNCA
    # mencionava o caminho antigo. Quem fizesse 'filter-repo' no caminho novo
    # deixaria o blob no lugar. Achado do qa-reviewer.
    $conteudo = "TOKEN = '" + $TOKEN_FALSO + "'`n"
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'config.py' = $conteudo } },
        @{ Escreve = @{ 'legacy/config.py' = $conteudo }; Apaga = @('config.py') },
        @{ Apaga   = @('legacy/config.py') }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'config\.py') "nao apontou nenhum dos caminhos"
        Assert-True ($rel -match 'legacy/config\.py') "nao apontou o caminho novo"
        # Uma craseblack, nao duas: em string de aspas simples do PowerShell o
        # backtick e literal, entao '``' seriam DUAS crases e o padrao nunca
        # casaria com a celula do relatorio.
        Assert-True ($rel -match '(?m)\| `config\.py') "nao apontou o caminho ANTIGO, que filter-repo tambem tem de limpar"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: o relatorio nao afirma ordem cronologica que nao conhece" {
    # 'a partir do blob X' afirmava cronologia derivada da ordem indefinida de
    # uma hashtable: o relatorio podia citar o blob mais NOVO e apontar quem
    # fosse limpar o historico para o ponto errado da linha do tempo. E a
    # saida variava entre execucoes sobre o mesmo repositorio.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'seg.py' = "T = '" + $TOKEN_FALSO + "'`n" } },
        @{ Escreve = @{ 'seg.py' = "T = '" + $TOKEN_FALSO + "'`n# editado`n" } },
        @{ Apaga   = @('seg.py') }
    )
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $a = Get-Rel $fx
        Assert-True ($a -match 'NAO cronologica') "o relatorio nao avisa que a ordem dos blobs nao e cronologica"
        Assert-True ($a -match 'git log --') "nao diz como obter a linha do tempo de verdade"
        Assert-True ($a -notmatch 'a partir do blob') "ainda afirma 'a partir do blob', que o codigo nao entrega"
        # Determinismo: duas execucoes sobre o mesmo repo dao a mesma lista.
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $b = Get-Rel $fx
        $la = [regex]::Match($a, 'Blobs \(ordem de sha, NAO cronologica\): ([^.]+)').Groups[1].Value
        $lb = [regex]::Match($b, 'Blobs \(ordem de sha, NAO cronologica\): ([^.]+)').Groups[1].Value
        Assert-True ($la -eq $lb) "a lista de blobs mudou entre duas execucoes sobre o mesmo repositorio"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: marcador de fixture ADICIONADO depois nao quebra a deduplicacao" {
    # Chave de dedup pela categoria RECLASSIFICADA era instavel: um arquivo
    # commitado com CPF de fixture SEM o marcador, e o marcador entrando num
    # commit posterior, produzia 'fixture declarada: CPF...' no working tree e
    # 'CPF...' no blob antigo. Chaves disjuntas, dedup nao pega, e o relatorio
    # passava a emitir MEDIA bloqueante no historico para sempre - sem caminho
    # de reclassificacao, porque o ADR-0009 nao preve MEDIA aceita.
    $m = Get-MarcadorFixture
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'caso.md' = "CPF: " + $CPF_VALIDO + "`n" } },
        @{ Escreve = @{ 'caso.md' = "# " + $m + "`nCPF: " + $CPF_VALIDO + "`n" } }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match '\| fixture declarada: CPF') "nao reclassificou o achado do working tree"
        Assert-True ($rel -notmatch 'CPF com digito verificador valido no historico') `
            "emitiu MEDIA bloqueante no historico para o mesmo CPF que o working tree ja declara como fixture"
        Assert-True ($r.Exit -eq 0) "travou o fluxo por um CPF de fixture (exit $($r.Exit))"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: sonda alcanca '**' e classe de caractere" {
    # As 4 regras que a sonda declarava nao representar deixavam a area
    # 'gitignore' INCONCLUSIVA - e uma delas era '!/examples/**', exatamente
    # onde a revisao humana achou um furo real. Detector que nao alcanca a
    # regra mais perigosa nao fecha a area.
    Assert-True ((Get-SondaParaRegra -Regra '*.py[cod]').Sonda -match '\.pyc$') `
        "nao sondou classe de caractere pelo primeiro membro"
    Assert-True ((Get-SondaParaRegra -Regra '*.py[cod]').PorMembroDeClasse) `
        "nao marcou que a sonda usou um membro da classe"
    $ex = Get-SondaParaRegra -Regra '!/examples/**'
    Assert-True ($ex.Negacao -and $ex.Sonda -match '^examples/') "nao sondou '!/examples/**'"
    $png = Get-SondaParaRegra -Regra '!.claude/skills/**/assets/*.png'
    Assert-True ($png.Sonda -match '^\.claude/skills/.+/assets/.+\.png$') "nao sondou '**' no meio do caminho"
    Assert-True ((Get-SondaParaRegra -Regra 'arquivo?.txt').Sonda -match '^arquivox\.txt$') "nao sondou '?'"
    # Classe NEGADA continua recusada: ali o primeiro caractere nao e membro,
    # e chutar produziria 'regra sem efeito' falso.
    Assert-True ($null -eq (Get-SondaParaRegra -Regra '*.py[!co]')) "chutou sonda para classe negada"
}

Test-Caso "gitignore: nomes canonicos sao perguntados em CADA .gitignore, nao so na raiz" {
    # A pergunta 'de fora para dentro' so alcancava a raiz. O .gitignore de um
    # subdiretorio - no caso real, o do template, que governa todo projeto
    # futuro - ficava sem verificacao, e os nomes canonicos tinham entrado
    # nele por analogia. Os DOIS revisores apontaram.
    # Regras ANCORADAS na raiz de proposito ('/.env' em vez de '.env'): sem a
    # ancora, uma regra da raiz protege qualquer profundidade e o
    # subdiretorio aparece coberto de graca - foi o que a primeira versao
    # deste teste descobriu, e e comportamento correto do Git. Com a ancora, a
    # raiz fica coberta e o subdiretorio nao, que e a situacao que o detector
    # precisa saber enxergar.
    $alvos = @('.env', '.env.local', '.env.production',
               'secrets.json', 'secrets.yaml', 'credentials.json',
               'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519',
               'chave-privada.pem', 'certificado.pfx',
               '.msal_cache', 'service-account.json')
    $ign = (@('/artifacts/') + @($alvos | ForEach-Object { '/' + $_ })) -join "`n"
    $fx = New-RepoFx2 -Gitignore ($ign + "`n") -Passos @(
        @{ Escreve = @{ 'sub/.gitignore' = "*.log`n"; 'sub/a.md' = "# x`n" } }
    )
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'em sub/: 14 de 14') `
            "nao perguntou os nomes canonicos dentro de sub/"
        Assert-True ($rel -notmatch 'na raiz: \d+ de 14') "acusou falta de cobertura na raiz, que esta completa"
        Assert-True ($rel -match 'e 14 de 28 nome\(s\) de segredo canonico cobertos') `
            "a cobertura nao soma os alvos por diretorio"
        Assert-True ($rel -match 'contando cada diretorio com `\.gitignore` proprio') `
            "a cobertura nao declara que a pergunta e por diretorio"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: ACUSA regra sombreada por outra POSTERIOR" {
    # Medido: o Git aplica o ULTIMO padrao que casa, nao o primeiro. A
    # primeira versao deste teste punha '*.log' antes de 'debug.log' e
    # esperava sombreamento - e a regra especifica, sendo a ultima, era
    # justamente quem decidia. Aqui a especifica vem primeiro, e quem decide
    # e a generica de baixo: 'debug.log' nunca decide nada.
    $ign = "/artifacts/*`ndebug.log`n*.log`n"
    $fx = New-RepoFx2 -Gitignore $ign
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'regra de \.gitignore sombreada') "nao acusou a regra sombreada"
        Assert-True ($rel -match 'debug\.log|\*\.log') "nao apontou qual regra"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: ACUSA segredo canonico sem cobertura, e isso NAO trava (BAIXA)" {
    # Guarda-corpo ausente e risco, nao vazamento. ADR-0009.
    $fx = New-RepoFx2 -Gitignore "/artifacts/*`n"
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'segredo canonico sem cobertura') "nao acusou a ausencia de cobertura"
        Assert-True ($rel -match 'Guarda-corpo ausente, nao vazamento') "nao explicou a classificacao"
        Assert-True ($r.Exit -eq 0) "achado BAIXA travou o fluxo (exit $($r.Exit)) - contraria o ADR-0009"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: ACUSA protecao que vem de FORA do repositorio" {
    # Regra que mora no excludesfile global protege esta maquina e mais
    # ninguem: quem clonar nao recebe. E uma falha de portabilidade que so
    # aparece no clone, e ler o .gitignore do repo nunca a mostraria.
    $glob = Join-Path $env:TEMP ("ign-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
    [System.IO.File]::WriteAllText($glob, ".env`n.env.local`n.env.production`n", (New-Object System.Text.UTF8Encoding($false)))
    $fx = New-RepoFx2 -Gitignore "/artifacts/*`n" -Excludesfile $glob
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'protecao de segredo nao viaja com o repositorio') `
            "nao acusou protecao vinda de fora do repositorio"
        Assert-True ($rel -match 'quem clonar nao recebe') "nao explicou a consequencia"
    } finally { Remove-Fx $fx; Remove-Item $glob -Force -ErrorAction SilentlyContinue }
}

Test-Caso "gitignore: .gitignore completo e sem redundancia NAO produz achado" {
    # O par negativo. Todos os alvos canonicos cobertos, cada regra decidindo
    # a propria sonda.
    $ign = @('/artifacts/', '.env', '.env.local', '.env.production',
             'secrets.json', 'secrets.yaml', 'credentials.json',
             'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519',
             'chave-privada.pem', 'certificado.pfx',
             '.msal_cache', 'service-account.json') -join "`n"
    $fx = New-RepoFx2 -Gitignore ($ign + "`n")
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match '\| gitignore \| 0 \| 0 \| 0 \|') `
            "acusou algo num .gitignore completo. Relatorio: $rel"
        Assert-True ($rel -match '15 de 15 regra') "nao verificou todas as regras"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# FUNCIONAL - dado de terceiro
# =============================================================================

Test-Caso "dado de terceiro: ACUSA CPF valido em arquivo rastreado e trava" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'clientes.md' = "Fulano - CPF " + $CPF_VALIDO + "`n" } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'CPF com digito verificador valido') "nao acusou o CPF"
        Assert-True ($r.Exit -eq 1) "esperava exit 1 com MEDIA, veio $($r.Exit)"
        Assert-True ($rel -notmatch '12345678909') "o relatorio TRANSCREVEU os digitos"
        Assert-True ($rel -notmatch '123\.456\.789-09') "o relatorio TRANSCREVEU o CPF pontuado"
    } finally { Remove-Fx $fx }
}

Test-Caso "dado de terceiro: CPF de digito invalido NAO trava o fluxo" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'notas.md' = "numero de teste " + $CPF_INVALIDO + "`n" } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -notmatch 'CPF com digito verificador valido') "acusou CPF invalido"
        Assert-True ($r.Exit -eq 0) "travou por causa de um numero que nao e CPF (exit $($r.Exit))"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# FUNCIONAL - exposicao externa
# =============================================================================

Test-Caso "exposicao: ACUSA webhook em arquivo versionado" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'notifica.py' = "URL = '" + $WEBHOOK_FALSO + "'`n" } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'webhook do Slack') "nao acusou o webhook"
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
        Assert-True ($rel -notmatch 'abcdefghijklmnop') "o relatorio TRANSCREVEU a URL do webhook"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: ACUSA credencial LITERAL em configuracao de CI" {
    $wf = "name: ci`non: push`njobs:`n  build:`n    steps:`n      - env:`n          API_TOKEN: 'abcdefghij1234567890ABCD'`n"
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ '.github/workflows/ci.yml' = $wf } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'credencial literal em configuracao de CI') "nao acusou o segredo literal no CI"
        Assert-True ($rel -notmatch 'abcdefghij1234567890ABCD') "o relatorio TRANSCREVEU o valor"
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: referencia ao cofre no CI NAO e achado" {
    # O par negativo que evita o detector que grita sempre: referenciar
    # '${{ secrets.X }}' e justamente a forma CERTA.
    $wf = "name: ci`non: push`njobs:`n  build:`n    steps:`n      - env:`n          API_TOKEN: " + '"${{ secrets.API_TOKEN }}"' + "`n"
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ '.github/workflows/ci.yml' = $wf } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -notmatch 'credencial literal em configuracao de CI') `
            "acusou uma referencia legitima ao cofre de segredos"
        Assert-True ($rel -match '1 arquivo\(s\) de CI') "nao declarou ter examinado o arquivo de CI"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: ACUSA gatilho de CI que expoe segredo a fork" {
    $wf = "name: ci`non:`n  pull_request_target:`njobs:`n  build:`n    steps:`n      - run: echo oi`n"
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ '.github/workflows/ci.yml' = $wf } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'expoe segredo a fork') "nao acusou pull_request_target"
    } finally { Remove-Fx $fx }
}

function New-GhFalso {
    <#
      Executavel de mentira que responde no lugar do 'gh'. Devolve o caminho.

      Existe porque o detector de 'remoto PUBLICO' - o unico achado ALTA da
      area de exposicao - nao tinha teste NENHUM: as 24 invocacoes funcionais
      passavam -SemRede, e o unico sinal de que ele funcionava era a execucao
      real deste repositorio, que exercita so o ramo PRIVATE. A plataforma
      afirmava a politica 4.1 e a descumpria. Achado do qa-reviewer.

      .cmd em vez de .ps1 porque o scanner invoca o gh como executavel.
    #>
    param([string]$Resposta, [int]$Codigo = 0)
    $p = Join-Path $env:TEMP ("gh-" + [guid]::NewGuid().ToString('N').Substring(0, 10) + '.cmd')
    $linhas = "@echo off`r`n"
    if ($Resposta) { $linhas += "echo $Resposta`r`n" }
    $linhas += ("exit /b " + $Codigo + "`r`n")
    [System.IO.File]::WriteAllText($p, $linhas, (New-Object System.Text.ASCIIEncoding))
    return $p
}

Test-Caso "exposicao: ACUSA remoto PUBLICO - o unico achado ALTA da area" {
    $gh = New-GhFalso -Resposta 'PUBLIC'
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/alguem/repo-fabricado.git' 2>$null
        $env:OS_SCAN_GH = $gh
        $r = Invoke-Scan $fx
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'remoto PUBLICO') "nao acusou o remoto publico"
        Assert-True ($rel -match 'ADR-0003 define privado por padrao') "nao explicou por que isso e achado"
        Assert-True ($rel -match 'ALTA \| exposicao externa') "nao classificou como ALTA na area de exposicao"
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit)"
    } finally {
        Remove-Item Env:\OS_SCAN_GH -ErrorAction SilentlyContinue
        Remove-Fx $fx; Remove-Item $gh -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "exposicao: remoto PRIVADO nao acusa, e a visibilidade entra na cobertura" {
    # O par negativo. Sem ele, um detector que acusa todo remoto passaria.
    $gh = New-GhFalso -Resposta 'PRIVATE'
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/alguem/repo-fabricado.git' 2>$null
        $env:OS_SCAN_GH = $gh
        $r = Invoke-Scan $fx
        $rel = Get-Rel $fx
        Assert-True ($rel -notmatch 'remoto PUBLICO') "acusou remoto publico com resposta PRIVATE"
        Assert-True ($rel -match 'alguem/repo-fabricado = PRIVATE') "nao registrou a visibilidade verificada"
        # Ancorado na celula da tabela de lacunas. Sem a ancora, o padrao
        # tambem casava com a frase 'a visibilidade do remoto NAO veio da API
        # real' da linha de modificadores - '-match' e case-insensitive, e o
        # teste acusava lacuna onde nao havia.
        Assert-True ($rel -notmatch '\| Visibilidade do remoto') "declarou lacuna de visibilidade tendo obtido resposta"
    } finally {
        Remove-Item Env:\OS_SCAN_GH -ErrorAction SilentlyContinue
        Remove-Fx $fx; Remove-Item $gh -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "exposicao: resposta irreconhecivel NAO conta como visibilidade verificada" {
    # O cenario de degradacao silenciosa que o qa-reviewer descreveu: se o gh
    # renomear o campo, '-q .visibility' devolve vazio COM exit 0. Sem guarda,
    # a area era declarada COBERTA com valor lixo ('owner/repo = ') e o achado
    # ALTA nunca saia. Cobertura reduzida em silencio - politica 4.5.
    $gh = New-GhFalso -Resposta ''
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/alguem/repo-fabricado.git' 2>$null
        $env:OS_SCAN_GH = $gh
        $r = Invoke-Scan $fx
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'Visibilidade do remoto') "nao declarou a lacuna de visibilidade"
        Assert-True ($rel -match '\*\*parcial\*\*') "declarou a area COBERTA com resposta vazia"
        Assert-True ($rel -notmatch 'repo-fabricado = \|') "registrou visibilidade com valor lixo"
        Assert-True ($rel -notmatch 'remoto PUBLICO') "acusou publico sem resposta"
    } finally {
        Remove-Item Env:\OS_SCAN_GH -ErrorAction SilentlyContinue
        Remove-Fx $fx; Remove-Item $gh -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "exposicao: gh que falha declara lacuna, nao aprova por omissao" {
    $gh = New-GhFalso -Resposta 'erro qualquer' -Codigo 1
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/alguem/repo-fabricado.git' 2>$null
        $env:OS_SCAN_GH = $gh
        $r = Invoke-Scan $fx
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'a API nao respondeu') "nao declarou que a API falhou"
        Assert-True ($rel -match '\*\*parcial\*\*') "declarou a area coberta apesar da falha"
    } finally {
        Remove-Item Env:\OS_SCAN_GH -ErrorAction SilentlyContinue
        Remove-Fx $fx; Remove-Item $gh -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "exposicao: -SemRede declara a lacuna de visibilidade do remoto" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/alguem/repo-fabricado.git' 2>$null
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'Visibilidade do remoto') "nao declarou a lacuna de visibilidade"
        Assert-True ($rel -match 'consulta de rede desligada') "nao disse por que a lacuna existe"
        # Ancorado na CELULA da linha de exposicao. Solto, '**parcial**' casava
        # com qualquer linha da tabela: numa fixture em que 'working tree'
        # tambem caisse para parcial, o teste ficaria verde sem verificar a
        # area que ele existe para verificar. Achado do qa-reviewer.
        Assert-True ($rel -match '\| exposicao externa \| \*\*parcial\*\* \|') `
            "declarou a AREA DE EXPOSICAO como coberta apesar da lacuna"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# FUNCIONAL - contrato do relatorio e do codigo de saida
# =============================================================================

Test-Caso "relatorio: declara cobertura nas SEIS areas de veredito do revisor" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match '## Cobertura por area') "nao tem secao de cobertura por area"
        foreach ($area in (Get-AreasDeVeredito)) {
            Assert-True ($rel -match ('\| ' + [regex]::Escape($area) + ' \|')) "a area '$area' nao aparece no relatorio"
        }
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: manda ler a secao de lacunas ANTES dos achados" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $iCob = $rel.IndexOf('## Cobertura por area')
        $iNao = $rel.IndexOf('## Escopo NAO VARRIDO')
        $iAch = $rel.IndexOf('## Achados')
        Assert-True ($iCob -gt 0 -and $iNao -gt $iCob -and $iAch -gt $iNao) `
            "a ordem das secoes deixa os achados antes das lacunas"
        Assert-True ($rel -match 'antes dos achados') "nao instrui a ordem de leitura"
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: separa lacuna DESTA execucao de teto permanente da ferramenta" {
    # Sem a separacao, a instrucao "toda linha aqui derruba a area para
    # INCONCLUSIVO" deixaria 'working tree' inconclusivo PARA SEMPRE, porque
    # 'segredo sem formato reconhecivel' nunca vai ser varrido por scanner de
    # padrao. O security-reviewer teve de divergir da instrucao para nao
    # errar - regra que nunca pode ser satisfeita nao e rigor, e ruido.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $iLac = $rel.IndexOf('### Lacunas DESTA execucao')
        $iTet = $rel.IndexOf('### Teto permanente da ferramenta')
        Assert-True ($iLac -gt 0) "nao existe secao de lacunas desta execucao"
        Assert-True ($iTet -gt $iLac) "nao existe secao de teto permanente, depois das lacunas"
        # O teto NAO pode derrubar area, e o relatorio tem de dizer isso.
        $teto = $rel.Substring($iTet)
        Assert-True ($teto -match 'nao\*\* derrubam area') "o teto nao declara que nao derruba area"
        # \s+ porque a frase atravessa a quebra de linha do relatorio.
        Assert-True ($teto -match 'nenhum\s+padrao detectavel') "nao define o que APROVADO significa sob o teto"
        Assert-True ($teto -match 'sem formato reconhecivel') "o teto nao lista o limite da deteccao por padrao"
        # E uma execucao de cobertura cheia sobre repo simples nao deve ter
        # lacuna contingente nenhuma.
        $lac = $rel.Substring($iLac, $iTet - $iLac)
        Assert-True ($lac -match '\(nenhuma\)') `
            "declarou lacuna contingente numa execucao de cobertura cheia sobre repo trivial. Secao: $lac"
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: -SemHistorico aparece como lacuna DESTA execucao, nao como teto" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede', '-SemHistorico')
        $rel = Get-Rel $fx
        $iLac = $rel.IndexOf('### Lacunas DESTA execucao')
        $iTet = $rel.IndexOf('### Teto permanente da ferramenta')
        $lac = $rel.Substring($iLac, $iTet - $iLac)
        Assert-True ($lac -match 'Historico do Git') "a lacuna de historico nao entrou na secao contingente"
        Assert-True ($lac -notmatch '\(nenhuma\)') "disse que nao ha lacuna contingente tendo usado -SemHistorico"
        Assert-True ($rel.Substring($iTet) -notmatch 'Historico do Git') "tratou o historico como teto permanente"
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: explica a escada de severidade e o que trava" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'ADR-0009') "nao aponta o ADR que define a escada"
        foreach ($s in @('ALTA', 'MEDIA', 'BAIXA')) {
            Assert-True ($rel -match ('\*\*' + $s + '\*\*')) "nao explica a severidade $s"
        }
    } finally { Remove-Fx $fx }
}

Test-Caso "scanner: -Out FORA do repositorio funciona e declara que a pergunta nao se aplica" {
    # Defeito herdado da 2.2: 'git check-ignore' recusa caminho de fora com
    # "is outside repository", e sob ErrorActionPreference=Stop isso derrubava
    # o script com exit 2. Nenhum teste usava -Out fora do repo, e varrer sem
    # escrever dentro do alvo e uso legitimo - inclusive para nao sujar
    # repositorio de terceiro.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    $fora = Join-Path $env:TEMP ("rel-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.md')
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede', '-Out', $fora)
        Assert-True ($r.Exit -ne 2) "quebrou com exit 2 por causa do -Out externo. Saida: $($r.Saida)"
        Assert-True (Test-Path $fora) "nao gravou o relatorio no destino externo"
        $rel = Get-Texto $fora
        Assert-True ($rel -match 'FORA do repositorio-alvo') "nao declarou que a verificacao do destino nao se aplica"
    } finally { Remove-Fx $fx; Remove-Item $fora -Force -ErrorAction SilentlyContinue }
}

Test-Caso "carimbo: os DOIS coletores contam linhas do mesmo jeito" {
    # O defeito mais grave do ciclo, e ele estava no proprio guarda-corpo
    # contra evidencia velha: 'ReadAllLines().Count' num coletor e
    # '($txt -split "`n").Count' no outro. Para arquivo terminado em newline o
    # segundo da +1, entao os dois relatorios discordavam em TODAS as linhas
    # do carimbo, com a arvore parada. Seguindo a instrucao do revisor ao pe
    # da letra, o veredito correto seria INCONCLUSIVO sempre - o detector que
    # dispara sempre e o que se aprende a ignorar.
    # Os tres arquivos ficam NAO RASTREADOS de proposito: o carimbo do
    # collect-diff.ps1 cobre arquivo alterado e arquivo novo, e arquivo
    # rastreado e inalterado nao entra em nenhum dos dois.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'base.md' = "# base`n" } })
    try {
        foreach ($par in @(@('com-newline.md', "a`nb`nc`n"), @('sem-newline.md', "a`nb`nc"), @('vazio.md', ''))) {
            [System.IO.File]::WriteAllText((Join-Path $fx $par[0]), $par[1], (New-Object System.Text.UTF8Encoding($false)))
        }
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $relSec = Get-Rel $fx
        $null = Invoke-Scan $fx -Extra @('-SkipTests') -ScriptAlternativo (Join-Path $OsRoot 'scripts\collect-diff.ps1')
        $relDiff = Get-Texto (Join-Path $fx 'artifacts\review\diff-report.md')

        foreach ($arq in @('com-newline\.md', 'sem-newline\.md')) {
            $mS = [regex]::Match($relSec,  ('\| `' + $arq + '` \| \d+ \| (\d+) \|'))
            $mD = [regex]::Match($relDiff, ('\| `' + $arq + '` \| \d+ \| (\d+) \|'))
            Assert-True ($mS.Success) "o security-report nao carimbou $arq"
            Assert-True ($mD.Success) "o diff-report nao carimbou $arq"
            Assert-True ($mS.Groups[1].Value -eq $mD.Groups[1].Value) `
                ("os dois coletores discordam em " + $arq + ": security=" + $mS.Groups[1].Value + " diff=" + $mD.Groups[1].Value)
        }
        # Convencao: 3 linhas de conteudo com ou sem newline final.
        Assert-True ($relSec -match '\| `com-newline\.md` \| \d+ \| 3 \|') "newline final criou linha extra"
        Assert-True ($relSec -match '\| `sem-newline\.md` \| \d+ \| 3 \|') "contagem sem newline final divergiu"
        # E os dois relatorios declaram a convencao, para que um leitor cujo
        # visualizador conte diferente nao leia isso como deriva.
        Assert-True ($relSec  -match 'NAO cria linha vazia extra') "o security-report nao declara a convencao"
        Assert-True ($relDiff -match 'NAO cria linha vazia extra') "o diff-report nao declara a convencao"
    } finally { Remove-Fx $fx }
}

Test-Caso "carimbo: arquivo vazio conta 0 linhas, nao 1" {
    Assert-True ((Measure-Linhas '') -eq 0) "arquivo vazio contou como 1 linha"
    Assert-True ((Measure-Linhas "a`n") -eq 1) "uma linha com newline final contou errado"
    Assert-True ((Measure-Linhas "a") -eq 1) "uma linha sem newline final contou errado"
    Assert-True ((Measure-Linhas "a`r`nb`r`n") -eq 2) "CRLF contou errado"
    Assert-True ((Measure-Linhas "`n") -eq 1) "arquivo com so um newline contou errado"
}

Test-Caso "scanner: -Out com PREFIXO comum ao repo nao inventa achado bloqueante" {
    # 'C:\projeto-relatorios\r.md'.StartsWith('C:\proj') e verdadeiro, e sem
    # separador o destino era tratado como DENTRO do repositorio: o caminho
    # relativo virava 'eto-relatorios\r.md', check-ignore dizia "nao
    # ignorado", e saia um MEDIA bloqueante por um arquivo que esta fora.
    # O teste anterior nao pegava porque fixture e destino eram nomes irmaos
    # sem prefixo comum. Achado do qa-reviewer.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    $fora = $fx + '-relatorios'
    try {
        New-Item -ItemType Directory -Path $fora -Force | Out-Null
        $destino = Join-Path $fora 'r.md'
        $r = Invoke-Scan $fx -Extra @('-SemRede', '-Out', $destino)
        Assert-True (Test-Path $destino) "nao gravou o relatorio no destino"
        $rel = Get-Texto $destino
        Assert-True ($rel -notmatch 'destino do relatorio nao ignorado') `
            "inventou achado bloqueante para um destino que esta FORA do repositorio"
        Assert-True ($rel -match 'FORA do repositorio-alvo') `
            "nao declarou que a verificacao do destino nao se aplica"
        Assert-True ($r.Exit -eq 0) "travou o fluxo por colisao de prefixo (exit $($r.Exit))"
    } finally { Remove-Fx $fx; Remove-Fx $fora }
}

Test-Caso "historico: valor DIFERENTE no mesmo caminho nao e engolido pela deduplicacao" {
    # O falso negativo mais perigoso da dedup: a chave era
    # 'caminho|categoria', sem nada que dissesse QUAL valor. Um token
    # rotocionado - token novo hoje, token antigo no blob - produzia a mesma
    # chave, e o antigo era descartado como "coincidente com o working tree".
    # Segredo rotacionado e o caso mais comum de segredo real. Achado do
    # qa-reviewer.
    $antigo = 'ghp_ANTIGOFABRICADO0000001'
    $novo   = 'ghp_NOVOFABRICADO000000002'
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'config.py' = "TOKEN = '" + $antigo + "'`n" } },
        @{ Escreve = @{ 'config.py' = "TOKEN = '" + $novo + "'`n" } }
    )
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'ALTA \| working tree \| possivel token do GitHub') "nao acusou o token atual"
        Assert-True ($rel -match 'token do GitHub no historico') `
            "engoliu o token ANTIGO como se fosse o mesmo fato do working tree"
        Assert-True ($rel -notmatch 'ANTIGOFABRICADO') "transcreveu o valor antigo"
        Assert-True ($rel -notmatch 'NOVOFABRICADO') "transcreveu o valor novo"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: MESMO valor no mesmo caminho continua deduplicado" {
    # O par do caso acima. A impressao de valor nao pode reintroduzir a
    # duplicacao que a dedup existe para evitar.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'contatos.md' = "contato: alguem@empresa-terceira.com.br`n" } },
        @{ Escreve = @{ 'contatos.md' = "contato: alguem@empresa-terceira.com.br`n# editado`n" } }
    )
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -notmatch 'no historico') `
            "voltou a duplicar o mesmo e-mail entre working tree e historico"
        Assert-True ($rel -match 'suprimidas por coincidir com o working tree: [1-9]') `
            "nao contou a coincidencia"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: ACUSA credencial embutida na URL, que e ALTA e nao tinha teste" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'deploy.sh' = "curl https://usuario:senhafabricada@interno.exemplo-real.com/api`n"
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'URL com credencial embutida') "nao acusou credencial na URL"
        Assert-True ($rel -match 'ALTA \| exposicao externa') "nao classificou como ALTA"
        Assert-True ($rel -notmatch 'senhafabricada') "TRANSCREVEU a senha"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: SharePoint e BAIXA - nao trava projeto que documenta a origem dos dados" {
    # Como MEDIA, um README de projeto governado que documenta de onde vem o
    # dado travava TODO checkpoint daquele projeto para sempre, porque nao
    # existe 'MEDIA aceita'. Era o modo de falha do ADR-0009 deslocado para
    # os projetos governados. URL de SharePoint exige autenticacao: nao e
    # capacidade como um webhook, e revela o tenant - fato para contestar.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'README.md' = "Origem dos dados: https://empresa-exemplo.sharepoint.com/sites/Projeto/Documentos`n"
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'endpoint corporativo do SharePoint') "nao registrou o endpoint"
        Assert-True ($rel -match '\| exposicao externa \| endpoint corporativo do SharePoint') `
            "nao classificou como BAIXA (a linha de BAIXA nao tem coluna de severidade)"
        Assert-True ($r.Exit -eq 0) "travou o fluxo por um link de documentacao (exit $($r.Exit))"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: URL comum de documentacao NAO produz achado nenhum" {
    # O par negativo que faltava para 7 dos 8 padroes. Sem ele, um detector
    # que acusa qualquer https passaria.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'README.md' = @'
Links: https://github.com/alguem/projeto
Documentacao: https://docs.python.org/3/library/re.html
API publica: https://api.exemplo-real.com/v1/status
Discord da comunidade: https://discord.com/invite/abc123
Slack: https://exemplo-real.slack.com/archives/C012345
'@
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        foreach ($cat in @('webhook do Slack', 'webhook do Discord', 'webhook do Teams',
                           'URL com credencial embutida', 'webhook do n8n',
                           'tunel publico \(ngrok\)', 'coletor de requisicao publico',
                           'endpoint corporativo do SharePoint')) {
            Assert-True ($rel -notmatch $cat) "acusou '$cat' num README com links comuns"
        }
        Assert-True ($r.Exit -eq 0) "travou o fluxo por links de documentacao"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: arquivo sem extensao reconhecida derruba a area para parcial" {
    # O par positivo. A area de exposicao descartava arquivo sem extensao com
    # um 'continue' SEM contador, e a coluna 'Coberta' nunca refletia isso -
    # a rodada anterior corrigiu 'working tree' e 'dado de terceiro' e esta
    # ficou. Cenario do qa-reviewer: arquivo rastreado com um webhook dentro,
    # de extensao que o scanner nao reconhece. O conteudo nao e lido, nenhuma
    # lacuna e declarada, e o revisor - instruido a ler a cobertura antes dos
    # achados - aprova a area com base numa declaracao falsa.
    #
    # A fixture usava 'deploy.conf' e passou a usar '.dat': '.conf' entrou na
    # lista de extensoes de texto junto com '.npmrc'/'.netrc'/'.pypirc',
    # porque arquivo de configuracao carrega credencial. O que este caso testa
    # e o comportamento diante de extensao NAO reconhecida - qualquer uma
    # serve, e '.dat' nao e texto por convencao nenhuma.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'a.md'       = "# nada`n"
        'deploy.dat' = "URL = " + $WEBHOOK_FALSO + "`n"
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match '\| exposicao externa \| \*\*parcial\*\* \|') `
            "declarou a area de exposicao COBERTA com arquivo sem extensao nao lido"
        Assert-True ($rel -match 'sem extensao de texto nao lido') `
            "nao quantificou os arquivos nao lidos na linha de cobertura"
        # E o webhook de dentro dele realmente nao foi visto - a lacuna e real,
        # nao decorativa. E por isso que ela tem de ser declarada.
        Assert-True ($rel -notmatch 'webhook do Slack') `
            "leu o conteudo de um arquivo sem extensao reconhecida"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: sem arquivo desses, a area e declarada COBERTA" {
    # O par negativo: a coluna nao pode dizer 'parcial' sempre, senao para de
    # significar algo.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n"; 'b.py' = "x = 1`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match '\| exposicao externa \| sim \|') `
            "declarou a area parcial sem nenhum arquivo nao lido"
        Assert-True ($rel -match '0 sem extensao de texto nao lido') "nao declarou o volume zero"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: visibilidade INTERNAL e aceita e nao acusa" {
    $gh = New-GhFalso -Resposta 'INTERNAL'
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/org/repo-fabricado.git' 2>$null
        $env:OS_SCAN_GH = $gh
        $r = Invoke-Scan $fx
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'org/repo-fabricado = INTERNAL') "nao registrou INTERNAL como verificado"
        Assert-True ($rel -notmatch 'remoto PUBLICO') "acusou publico com INTERNAL"
        Assert-True ($r.Exit -eq 0) "travou por visibilidade INTERNAL"
    } finally {
        Remove-Item Env:\OS_SCAN_GH -ErrorAction SilentlyContinue
        Remove-Fx $fx; Remove-Item $gh -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "relatorio: a costura de teste do gh e DECLARADA na linha de modificadores" {
    # Costura ativa e nao declarada e cobertura reduzida em silencio: uma
    # variavel esquecida na sessao faria o relatorio afirmar PRIVATE com
    # resposta fabricada, e a area continuaria "coberta". Achado do
    # security-reviewer.
    $gh = New-GhFalso -Resposta 'PRIVATE'
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/org/repo-fabricado.git' 2>$null
        $env:OS_SCAN_GH = $gh
        $null = Invoke-Scan $fx
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'OS_SCAN_GH` \*\*ATIVA\*\*') "nao declarou a costura ativa"
        Assert-True ($rel -match 'NAO veio da API real') "nao disse o que a costura invalida"
    } finally {
        Remove-Item Env:\OS_SCAN_GH -ErrorAction SilentlyContinue
        Remove-Fx $fx; Remove-Item $gh -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "historico: blob acima do limite de tamanho e declarado, nao varrido em silencio" {
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'grande.md' = ("linha de enchimento`n" * 200) } },
        @{ Apaga   = @('grande.md') }
    )
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede', '-MaxBlobKB', '1')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'blob\(s\) do historico acima de 1 KB') "nao declarou o blob nao lido por tamanho"
        Assert-True ($rel -match '-MaxBlobKB 1') "nao registrou o limite usado nesta execucao"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# Excecoes de seguranca aprovadas - ADR-0010
# =============================================================================
# Os quatro casos que a Emmily exigiu ao decidir o mecanismo, mais os de borda
# que separam excecao de allowlist.

function New-ManifestoComExcecao {
    <#
      project.yaml minimo com uma excecao. -Status e -Campos permitem montar
      as variacoes que NAO devem cobrir nada.
    #>
    param(
        [string]$Caminho,
        [string]$Categoria,
        [string]$Status = 'aceito-por-excecao',
        [switch]$SemJustificativa
    )
    $l = @()
    $l += 'identidade:'
    $l += '  nome: "fixture"'
    $l += '  versao: "0.1.0"'
    $l += 'classificacao:'
    $l += '  criticidade: "alta"'
    $l += '  dados_sensiveis: true'
    $l += '  dados_sensiveis_excecoes:'
    $l += ('    - caminho: "' + $Caminho + '"')
    $l += ('      categoria: "' + $Categoria + '"')
    $l += '      natureza: "fixture de teste"'
    if (-not $SemJustificativa) { $l += '      justificativa: "repositorio de teste"' }
    $l += '      decisao: "aceito no fluxo privado; publicacao exige sanitizacao"'
    $l += ('      status: "' + $Status + '"')
    $l += '      decidido_em: "2026-09-08"'
    $l += '      escopo: "privado"'
    $l += '      onde_esta_registrado: "ADR-0010"'
    $l += 'verificacao:'
    $l += '  revisao_independente: "qa+security"'
    return (($l -join "`n") + "`n")
}

$EMAIL_TERCEIRO = 'contato: alguem@empresa-terceira.com.br'
$CAT_EMAIL = 'e-mail que nao assina commits deste repositorio'

Test-Caso "excecao: a excecao EXATA e reconhecida e o achado deixa de bloquear" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 0) "a excecao aprovada nao destravou o fluxo (exit $($r.Exit))"
        Assert-True ($rel -match 'Bloqueantes de verdade nesta execucao: 0') "ainda conta bloqueante"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: o achado ACEITO continua no relatorio, com a severidade original" {
    # Aceitar e decisao registrada, nao apagamento. Se o achado desaparecer,
    # o mecanismo virou allowlist silenciosa.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL)
    } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'ACEITOS POR EXCECAO') "nao existe secao de achados aceitos"
        Assert-True ($rel -match 'contatos\.md') "o achado aceito desapareceu do relatorio"
        Assert-True ($rel -match '\| MEDIA \| dado de terceiro \| ' + [regex]::Escape($CAT_EMAIL)) `
            "perdeu a severidade original do achado aceito"
        # E a excecao e CITAVEL: justificativa e data no relatorio.
        Assert-True ($rel -match 'decidido em 2026-09-08') "nao citou a excecao que cobre o achado"
        Assert-True ($rel -match 'repositorio de teste') "nao trouxe a justificativa declarada"
        # A contagem de severidade continua contando o achado.
        Assert-True ($rel -match 'Achados MEDIA: 1') "removeu o achado da contagem de severidade"
        Assert-True ($rel -match 'ACEITOS POR EXCECAO \(aparecem e nao bloqueiam\): 1') "nao contabilizou o aceito"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: achado PARECIDO em OUTRO arquivo continua bloqueando" {
    # A regra que separa excecao de allowlist. Mesma categoria, outro caminho.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'outro.md'     = "contato: outra.pessoa@empresa-diferente.com.br`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "o achado em outro arquivo deixou de bloquear (exit $($r.Exit))"
        Assert-True ($rel -match 'Bloqueantes de verdade nesta execucao: 1') "nao contou o bloqueante de outro arquivo"
        Assert-True ($rel -match 'outro\.md') "o achado bloqueante nao aparece"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: nome IRMAO que comeca com o caminho declarado continua bloqueando" {
    # O ramo que o teste anterior NAO exercitava, e por onde o defeito passou.
    #
    # 'achado PARECIDO em OUTRO arquivo' usava 'outro.md' contra a excecao de
    # 'contatos.md' - dois nomes SEM prefixo comum. Aquele teste passava com
    # StartsWith, com -like ou com igualdade: verde sobre ramo nao exercitado.
    # E a comparacao ERA por prefixo, entao 'contatos.md.old' era coberto pela
    # excecao de 'contatos.md'. Os dois revisores independentes pegaram na
    # mesma rodada.
    # O irmao precisa de extensao que o scanner LEIA, senao o conteudo nunca e
    # examinado e o teste passa por ausencia de achado em vez de por
    # bloqueio - foi o que aconteceu com '.old' na primeira versao deste caso.
    # 'contatos.md-copia.md' e realista (nome de copia no Windows), comeca com
    # o caminho declarado e tem extensao varrida.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'           = $EMAIL_TERCEIRO + "`n"
        'contatos.md-copia.md'  = "contato: outro.alguem@empresa-terceira.com.br`n"
        'project.yaml'          = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) `
            "o nome irmao 'contatos.md-copia.md' deixou de bloquear: a comparacao voltou a ser por prefixo (exit $($r.Exit))"
        Assert-True ($rel -match 'contatos\.md-copia\.md') "o achado do nome irmao nao aparece como bloqueante"
        Assert-True ($rel -match 'Bloqueantes de verdade nesta execucao: 1') `
            "esperava exatamente 1 bloqueante - o irmao - e o de 'contatos.md' coberto"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: caminho declarado como DIRETORIO nao cobre nada" {
    # A allowlist por diretorio que a Emmily recusou nominalmente. Com
    # comparacao por prefixo, 'caminho: "docs"' cobria a arvore inteira naquela
    # categoria - e o guarda de teste usava Test-Path, que devolve verdadeiro
    # para diretorio.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'docs/contatos.md' = $EMAIL_TERCEIRO + "`n"
        'project.yaml'     = (New-ManifestoComExcecao -Caminho 'docs' -Categoria $CAT_EMAIL)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "excecao declarada em DIRETORIO cobriu achado dentro dele (exit $($r.Exit))"
        Assert-True ($rel -match 'docs/contatos\.md') "o achado dentro do diretorio nao aparece"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: achado de severidade ALTA nunca e coberto" {
    # Limite por severidade, do lado de recusar. O mecanismo percorre todos os
    # achados, mas o campo se chama 'dados_sensiveis_excecoes' e o ADR-0010 foi
    # escrito em torno de dado pessoal: uma entrada com categoria de credencial
    # dispensaria um ALTA de working tree e o scanner sairia com 0.
    # Contestacao do security-reviewer, aceita.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'app.js'       = "const t = '" + $TOKEN_FALSO + "';`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'app.js' -Categoria 'possivel token do GitHub')
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "uma excecao dispensou um achado ALTA (exit $($r.Exit))"
        Assert-True ($rel -match 'ALTA \| working tree \| possivel token do GitHub') `
            "o achado ALTA nao aparece como bloqueante"
        Assert-True ($rel -match 'excecao NAO se aplica') "o relatorio nao declara que recusou por severidade"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: status correto e campo faltando aparece no relatorio, com o motivo" {
    # Regra 4 do ADR-0010: campo obrigatorio faltando nao cobre nada E aparece
    # na subsecao propria. A separacao era so por status, entao a incompleta
    # caia em 'Aceitas', era descartada em silencio no casamento e nunca
    # aparecia na lista - a mantenedora nao teria sinal que distinguisse
    # "excecao malformada" de "excecao nao casou".
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL -SemJustificativa)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "excecao incompleta liberou o achado (exit $($r.Exit))"
        Assert-True ($rel -match 'NAO cobrem nada') "a excecao incompleta nao aparece na subsecao propria"
        Assert-True ($rel -match 'falta campo obrigatorio: justificativa') `
            "o relatorio nao diz QUAL campo falta - sem isso nao da para distinguir de 'nao casou'"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: SEGUNDA entrada com chaves fora de ordem nao contamina a primeira" {
    # Fail-OPEN derivado pelo qa-reviewer, alcancavel com YAML valido: a
    # entrada era reconhecida so por '- caminho:' como PRIMEIRA chave. Numa
    # segunda entrada com 'categoria' antes, nenhuma entrada nova nascia e o
    # 'caminho:' seguinte SOBRESCREVIA o da primeira - que mantinha categoria,
    # justificativa e status aceito. A varredura passava a aceitar um par que
    # ninguem decidiu, sem sinal nenhum.
    $y = @()
    $y += 'identidade:'
    $y += '  nome: "fixture"'
    $y += 'classificacao:'
    $y += '  criticidade: "alta"'
    $y += '  dados_sensiveis: true'
    $y += '  dados_sensiveis_excecoes:'
    $y += '    - caminho: "contatos.md"'
    $y += ('      categoria: "' + $CAT_EMAIL + '"')
    $y += '      natureza: "fixture"'
    $y += '      justificativa: "repositorio de teste"'
    $y += '      decisao: "aceito no fluxo privado"'
    $y += '      status: "aceito-por-excecao"'
    $y += '      decidido_em: "2026-09-08"'
    $y += '      escopo: "privado"'
    $y += '      onde_esta_registrado: "ADR-0010"'
    # Segunda entrada com a ORDEM INVERTIDA, e de outra categoria.
    $y += '    - categoria: "CPF com digito verificador valido"'
    $y += '      caminho: "notas.md"'
    $y += '      natureza: "fixture"'
    $y += 'verificacao:'
    $y += '  revisao_independente: "qa+security"'

    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'notas.md'     = "contato: terceiro.outro@empresa-diferente.com.br`n"
        'project.yaml' = (($y -join "`n") + "`n")
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        # 'contatos.md' segue coberto pela entrada 1, bem formada.
        Assert-True ($rel -match '\| MEDIA \| dado de terceiro \| ' + [regex]::Escape($CAT_EMAIL)) `
            "a entrada 1, bem formada, deixou de cobrir o proprio caminho"
        # 'notas.md' NAO pode ser coberto: a entrada 2 esta incompleta.
        Assert-True ($r.Exit -eq 1) `
            "a segunda entrada contaminou a primeira e liberou um caminho que ninguem aprovou (exit $($r.Exit))"
        Assert-True ($rel -match 'notas\.md') "o achado de 'notas.md' nao aparece como bloqueante"
        # E a entrada 2 tem de aparecer como nao-cobrindo-nada, com o motivo.
        Assert-True ($rel -match 'NAO cobrem nada') "a entrada incompleta nao aparece na subsecao propria"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: entrada UNICA com chave antes de 'caminho' e reconhecida e declarada" {
    # O par do caso acima: antes, a entrada nao nascia e ficava invisivel nas
    # DUAS listas. O achado bloqueava - lado seguro -, mas o relatorio nao
    # dizia uma palavra sobre a excecao, recriando o modo de falha que a
    # emenda 3 do ADR-0010 existe para eliminar.
    $y = @()
    $y += 'classificacao:'
    $y += '  criticidade: "alta"'
    $y += '  dados_sensiveis: true'
    $y += '  dados_sensiveis_excecoes:'
    $y += ('    - categoria: "' + $CAT_EMAIL + '"')
    $y += '      caminho: "contatos.md"'
    $y += '      natureza: "fixture"'
    $y += '      justificativa: "repositorio de teste"'
    $y += '      decisao: "aceito no fluxo privado"'
    $y += '      status: "aceito-por-excecao"'
    $y += '      decidido_em: "2026-09-08"'
    $y += '      escopo: "privado"'
    $y += '      onde_esta_registrado: "ADR-0010"'
    $y += 'verificacao:'
    $y += '  revisao_independente: "qa+security"'

    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (($y -join "`n") + "`n")
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 0) `
            "entrada completa com chaves fora de ordem nao foi reconhecida (exit $($r.Exit))"
        Assert-True ($rel -match 'ACEITOS POR EXCECAO') "o achado aceito nao aparece"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: blob que o cat-file devolve vazio e CONTADO e declarado" {
    # O CHANGELOG afirmava teste para este ramo e ele nao existia - achado do
    # qa-reviewer. O ramo era um 'continue' silencioso que deixava candidato
    # fora do balanco, num relatorio cuja premissa e declarar a propria
    # cobertura. Arquivo VAZIO com extensao de texto produz exatamente isso.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'vazio.md' = ''; 'a.md' = "# nada`n" } },
        @{ Apaga   = @('vazio.md') }
    )
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'devolveu vazio') `
            "o blob sem conteudo nao foi declarado como lacuna: voltou a ser descartado em silencio"
        Assert-True ($rel -match '(?m)^\| [1-9]\d* blob\(s\) do historico que o') `
            "a lacuna do blob sem conteudo nao traz volume"

        # Mede o CONTADOR, nao so a linha. O security-reviewer achou este caso
        # emitindo a lacuna E o "(nenhuma)" na mesma tabela: a correcao
        # acrescentou a LINHA e esqueceu o acumulador que decide imprimir
        # "(nenhuma)", e este caso media a linha - logo passava por cima da
        # contradicao. Terceira vez na plataforma que o conserto cobre o
        # sintoma declarado e deixa o portao a jusante. O caso irmao de
        # '-SemHistorico' ja fazia certo, e este e o molde dele.
        $iLacBlob = $rel.IndexOf('### Lacunas DESTA execucao')
        $iTetBlob = $rel.IndexOf('### Teto permanente da ferramenta')
        $lacBlob = $rel.Substring($iLacBlob, $iTetBlob - $iLacBlob)
        Assert-True ($lacBlob -notmatch '\(nenhuma\)') `
            "a tabela emitiu a lacuna do blob vazio E disse '(nenhuma)': declaracao de cobertura que se autocontradiz"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: MESMO arquivo, categoria DIFERENTE, continua bloqueando" {
    # A outra metade da correspondencia exata.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`nCPF: " + $CPF_VALIDO + "`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "o CPF no mesmo arquivo deixou de bloquear (exit $($r.Exit))"
        Assert-True ($rel -match 'CPF com digito verificador valido') "o achado de CPF nao aparece"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: -ParaPublicacao ignora TODA excecao e o achado volta a bloquear" {
    # Publicacao exige sanitizacao, nao excecao.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede', '-ParaPublicacao')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "a excecao sobreviveu ao modo publicacao (exit $($r.Exit))"
        Assert-True ($rel -match 'ParaPublicacao') "nao declarou o modo na linha de modificadores"
        Assert-True ($rel -match '(?i)publicacao exige sanitizacao') "nao diz que publicar exige sanitizar"
        Assert-True ($rel -match 'nenhuma excecao vale nesta execucao') "nao avisa que as excecoes foram ignoradas"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: status que nao e exatamente 'aceito-por-excecao' NAO cobre nada" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL -Status 'pendente-decisao-da-mantenedora')
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "excecao PENDENTE liberou o achado (exit $($r.Exit))"
        Assert-True ($rel -match 'NAO cobrem nada') "nao declarou que a excecao pendente nao cobre nada"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: sem justificativa, a excecao NAO cobre nada" {
    # Campo obrigatorio faltando e allowlist de uma linha disfarcada.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (New-ManifestoComExcecao -Caminho 'contatos.md' -Categoria $CAT_EMAIL -SemJustificativa)
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        Assert-True ($r.Exit -eq 1) "excecao sem justificativa liberou o achado (exit $($r.Exit))"
    } finally { Remove-Fx $fx }
}

Test-Caso "excecao: repositorio SEM excecao nenhuma continua bloqueando igual" {
    # O par negativo do mecanismo inteiro: ele nao pode afrouxar nada por
    # existir.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'contatos.md' = $EMAIL_TERCEIRO + "`n" } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) "sem excecao, o achado deveria bloquear (exit $($r.Exit))"
        Assert-True ($rel -match '(?ms)ACEITOS POR EXCECAO.*?Nenhum\.') "nao declarou ausencia de aceitos"
    } finally { Remove-Fx $fx }
}

Test-Caso "scanner: detector ausente sai com 2, nao varre menos em silencio" {
    # Cobertura reduzida sem aviso e o modo de falha que a politica 4.5
    # existe para impedir. A lista de libs e explicita justamente por isso.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    $mutilado = Join-Path $env:TEMP ("sc-mut-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        New-Item -ItemType Directory -Path (Join-Path $mutilado 'lib') -Force | Out-Null
        Copy-Item $Scanner (Join-Path $mutilado 'security-scan.ps1')
        foreach ($m in @('scan-comum.ps1', 'scan-gitignore.ps1', 'scan-dado-pessoal.ps1', 'scan-exposicao.ps1')) {
            Copy-Item (Join-Path $LibDir $m) (Join-Path $mutilado ('lib\' + $m))
        }
        $r = Invoke-Scan $fx -Extra @('-SemRede') -ScriptAlternativo (Join-Path $mutilado 'security-scan.ps1')
        Assert-True ($r.Exit -eq 2) "esperava exit 2 com detector ausente, veio $($r.Exit)"
        Assert-True ($r.Saida -match 'detector ausente') "nao disse qual detector faltou"
    } finally { Remove-Fx $fx; Remove-Fx $mutilado }
}

Test-Caso "scanner: arquivo RASTREADO ausente do disco e contado, nomeado e vira lacuna" {
    # Os DOIS revisores acharam a mesma metade faltando: o ramo
    # $ausentesDoDisco, criado numa rodada anterior, nao tinha caso nenhum -
    # nem da linha, nem do acumulador. Apagar o termo do acumulador deixava a
    # suite verde com o defeito de volta.
    #
    # E o comentario que eu mesmo escrevi no codigo dizia: "Quem acrescentar
    # linha aqui: acrescente no acumulador, e escreva o caso que exige a
    # AUSENCIA de '(nenhuma)'." Escrevi a instrucao e nao a segui - o caso foi
    # escrito para a metade que o security-reviewer nomeou e nao para a metade
    # que o mesmo commit criou.
    #
    # Aqui o cenario e plantado: arquivo rastreado, com conteudo, APAGADO do
    # disco sem 'git add'. Exatamente o estado em que este repositorio estava.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'sobrevive.md' = "# fica`n"; 'apagado.md' = "# vai sumir do disco`n" } }
    )
    try {
        # Apaga do disco SEM estagiar a delecao: o Git continua listando.
        Remove-Item (Join-Path $fx 'apagado.md') -Force
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $listados = @(& git -C $fx ls-files 2>$null)
        $ErrorActionPreference = $anterior
        Assert-True ($listados -contains 'apagado.md') `
            "a fixture nao produziu a condicao: o git deixou de listar o arquivo apagado"

        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx

        # 1. a linha existe, com volume e com o CAMINHO - so o numero obrigava
        #    o revisor a cruzar com o relatorio de diff para fechar.
        Assert-True ($rel -match 'RASTREADO\(S\) e ausente\(s\) do disco') `
            "o arquivo rastreado ausente do disco nao virou lacuna declarada"
        Assert-True ($rel -match 'apagado\.md') `
            "a lacuna nao nomeia o arquivo: fechar exige cruzar com outro relatorio"

        # 2. o CONTADOR: a tabela nao pode dizer "(nenhuma)" tendo emitido a
        #    linha. Este era o portao que a correcao esqueceu.
        $iLac = $rel.IndexOf('### Lacunas DESTA execucao')
        $iTet = $rel.IndexOf('### Teto permanente da ferramenta')
        $lac = $rel.Substring($iLac, $iTet - $iLac)
        Assert-True ($lac -notmatch '\(nenhuma\)') `
            "a tabela emitiu a lacuna E disse '(nenhuma)': declaracao de cobertura que se autocontradiz"

        # 3. a coluna 'Coberta' das TRES areas que leem conteudo tem de dizer
        #    parcial. Era o OUTRO portao que consome o mesmo fato, e a
        #    correcao anterior alcancou um dos dois - quarta aparicao do
        #    padrao, contada pelo security-reviewer.
        $iCob = $rel.IndexOf('| Area | Coberta |')
        $iFimCob = $rel.IndexOf('## ', $iCob)
        $tabCob = $rel.Substring($iCob, $iFimCob - $iCob)
        foreach ($area in @('working tree', 'dado de terceiro', 'exposicao externa')) {
            $linhaArea = @($tabCob -split "`r?`n" | Where-Object { $_ -match ('^\| ' + [regex]::Escape($area) + ' \|') })
            Assert-True ($linhaArea.Count -eq 1) "nao achei a linha da area '$area' na tabela de cobertura"
            Assert-True ($linhaArea[0] -match 'parcial') `
                "a area '$area' se declarou coberta tendo deixado arquivo sem ler. Linha: $($linhaArea[0])"
        }
    } finally { Remove-Fx $fx }
}

Test-Caso "scanner: a lacuna de ausente NAO promete que o historico cobre exposicao" {
    # A linha que eu havia escrito afirmava "o blob ainda e alcancavel pelo
    # historico, e e la que ele aparece". Para credencial, verdade. Para
    # EXPOSICAO, falso: o scan-historico carrega so Get-PadroesConteudo, nunca
    # Get-PadroesExposicao. Um arquivo rastreado com webhook, apagado do disco
    # sem 'git add', nao era lido por area nenhuma - e o relatorio afirmava o
    # contrario. Achado do qa-reviewer, e o melhor das cinco rodadas.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'notify.ps1' = "# webhook`n`$u = 'https://hooks.slack.com/services/T00/B00/XXXXXXXXXXXXXXXXXXXXXXXX'`n" } }
    )
    try {
        Remove-Item (Join-Path $fx 'notify.ps1') -Force
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'RASTREADO\(S\) e ausente\(s\) do disco') "a lacuna nao apareceu"
        Assert-True ($rel -match 'padroes de EXPOSICAO|padrao de CREDENCIAL') `
            "a lacuna nao declara que o historico NAO aplica os padroes de exposicao"
        Assert-True ($rel -notmatch 'e e la que ele aparece') `
            "a linha ainda promete que o achado aparece no historico - falso para exposicao"
    } finally { Remove-Fx $fx }
}

Test-Caso "scanner: a lacuna do blob vazio traz o SHA e o caminho, nao so a contagem" {
    # F6, o unico achado da rodada 5 que mudou veredito: com so a contagem, o
    # revisor fecha por ARITMETICA (marcadores de 0 byte colapsam num objeto
    # so) e nao consegue excluir o maligno - uma falha de LEITURA num blob COM
    # conteudo satisfaz o mesmo limite, porque o contador sobe no mesmo
    # 'if (-not $txt)' para os dois casos. E ele nao pode abrir objeto do Git:
    # sao comprimidos, e ele nao tem Bash, por desenho do ADR-0008.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ 'vazio.md' = ''; 'a.md' = "# nada`n" } },
        @{ Apaga   = @('vazio.md') }
    )
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'devolveu vazio') "a lacuna do blob vazio nao apareceu"
        # SHA abreviado de 8 hex, entre crases, e o caminho ao lado.
        # Sem crase no padrao: em string de aspas SIMPLES a crase e literal,
        # entao '``' sao DUAS crases e a saida tem uma. O caso reprovou por
        # isso, com a correcao ja funcionando - e ainda bem que reprovou por
        # exigir a forma exata.
        Assert-True ($rel -match '[0-9a-f]{8} \(vazio\.md\)') `
            "a lacuna nao traz o sha abreviado e o caminho: fechar continua sendo por aritmetica"
        Assert-True ($rel -match 'por IDENTIDADE') `
            "a lacuna nao diz ao revisor que agora ele fecha por identidade"
    } finally { Remove-Fx $fx }
}

Test-Caso "scanner: o teto de nome de cliente prescreve sanitizar o REPOSITORIO, nao dois ponteiros" {
    # A mitigacao prescrevia sanitizar "o que portfolio.exposicao e
    # dados_sensiveis_excecoes apontarem" - dois ponteiros que cobrem UM
    # arquivo, enquanto o grep do security-reviewer achou nome de cliente
    # corporativo em 21 arquivos rastreados. Prescricao dimensionada para uma
    # fracao da superficie e pior que nenhuma: da a impressao de que ha um
    # roteiro suficiente.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'REPOSITORIO INTEIRO') `
            "o teto nao prescreve sanitizacao do repositorio inteiro"
        Assert-True ($rel -match 'inventario proprio') `
            "o teto nao exige inventario proprio"
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: NENHUMA linha de tabela sai truncada - toda celula fecha com barra" {
    # A QUARTA aparicao da aspa nao escapada caiu justamente na linha que eu
    # tinha acabado de corrigir, e o caso de regressao que escrevi para ela
    # afirmava duas frases que ficavam ANTES do ponto de corte: verde sobre
    # relatorio corrompido. Os dois revisores acharam, no mesmo lugar.
    #
    # Este caso nao afirma sobre UMA linha: varre as linhas de tabela do
    # relatorio e exige que fechem. Uma string que perde o resto por aspa nao
    # escapada perde tambem o '|' final - entao a FORMA da linha denuncia o
    # defeito, sem precisar conhecer o texto dela.
    #
    # ALCANCE, e isto e limitacao declarada e nao promessa: a varredura so ve
    # as linhas que ESTA execucao emite. A primeira versao rodava sobre uma
    # fixture minima - um unico .md sem achado e sem lacuna - e o qa-reviewer
    # mostrou que ~14 linhas condicionais do relatorio nunca saiam ali: as
    # quatro lacunas de gitignore, as cinco de historico, o '(nenhuma)', e as
    # tres tabelas de achado. Uma aspa nao escapada em qualquer uma delas
    # passaria. A generalizacao que o comentario anterior fazia - "qualquer
    # linha que alguem escreva no futuro" - era falsa, e era a mesma classe de
    # afirmacao-sem-fato que este caso existe para impedir.
    #
    # A fixture agora e RICA de proposito: produz achado de credencial, achado
    # de dado pessoal, blob vazio no historico, classe de caractere e o par de
    # negacoes irmas. Continua nao cobrindo TUDO - '-SemHistorico', '-SemRede'
    # e '.gitignore' ausente do disco emitem linhas que esta execucao nao tem.
    # O que o caso garante e a forma das linhas que ele ve, e ele ve a maior
    # parte delas. Quem acrescentar linha condicional nova: acrescente tambem
    # a condicao aqui.
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{
            'a.md'         = "# nada`n"
            'vazio.md'     = ''
            'contatos.md'  = $EMAIL_TERCEIRO + "`nCPF: " + $CPF_VALIDO + "`n"
            'config.yml'   = "api_key: " + $TOKEN_FALSO + "`n"
            '.gitignore'   = "*.py[cod]`n/examples/`n!/examples/`n!/examples/**`nartifacts/`n"
        } },
        @{ Apaga = @('vazio.md') }
    )
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $quebradas = @()
        $linhasDeTabela = 0
        foreach ($linha in ($rel -split "`r?`n")) {
            $t = $linha.TrimEnd()
            if (-not $t.StartsWith('|')) { continue }
            $linhasDeTabela++
            if (-not $t.EndsWith('|')) { $quebradas += $t }
        }
        # Anti-vacuidade DE VERDADE. A versao anterior era
        # 'Assert-True ($emTabela -or $true)', que e sempre verdadeiro e nao
        # podia falhar nunca - guarda-corpo que PARECE guarda-corpo, num
        # repositorio cuja tese e exatamente essa. E '$emTabela' guardava o
        # estado da ULTIMA linha, nao "houve alguma tabela", entao nem sem a
        # tautologia serviria. Achado do qa-reviewer.
        Assert-True ($linhasDeTabela -gt 30) `
            "o relatorio trouxe so $linhasDeTabela linha(s) de tabela: a varredura passaria por vacuidade"
        Assert-True ($quebradas.Count -eq 0) `
            ("linha(s) de tabela sem o '|' de fechamento - tipicamente aspa dupla nao escapada que fechou a string e descartou o resto em silencio: " + ($quebradas -join ' /// '))
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: a linha do teto de nome de cliente chega ao FIM, com a medicao" {
    # O par especifico da linha que quebrou. Afirma sobre o FIM da frase, nao
    # sobre o comeco - era exatamente o erro do caso anterior.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $linha = @($rel -split "`r?`n" | Where-Object { $_ -match 'Estrutura de diretorio interna' })
        Assert-True ($linha.Count -eq 1) "nao achei a linha do teto de estrutura/cliente"
        Assert-True ($linha[0].TrimEnd().EndsWith('|')) `
            "a linha do teto nao fecha a celula: foi truncada"
        Assert-True ($linha[0] -match 'roteiro suficiente') `
            "a frase nao chega ao fim - o trecho final sumiu"
        Assert-True ($linha[0] -match '21 arquivos rastreados') `
            "a MEDICAO que justifica alargar a mitigacao sumiu da linha"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: as duas lacunas trazem arquivo:linha, nao so a contagem" {
    # O security-reviewer fechou 'historico' por identidade do sha e NAO
    # conseguiu fechar 'gitignore', porque as duas lacunas de la imprimiam
    # contagem sem identidade - o mesmo defeito que o F6 corrigiu uma area ao
    # lado. Area que o revisor nao fecha vira INCONCLUSIVO, e INCONCLUSIVO
    # bloqueia igual a REPROVADO.
    #
    # A fixture planta as duas condicoes: uma classe de caractere (sondavel
    # por UM membro) e o par de negacoes irmas que o Git exige junto.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'a.md' = "# nada`n"
        '.gitignore' = "*.py[cod]`n!/examples/`n!/examples/**`nartifacts/`n"
    } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $iLac = $rel.IndexOf('### Lacunas DESTA execucao')
        $iTet = $rel.IndexOf('### Teto permanente da ferramenta')
        $lac = $rel.Substring($iLac, $iTet - $iLac)
        # As DUAS, sem "if". A versao anterior afirmava dentro de um "if", e o
        # qa-reviewer mostrou a mutacao que sobrevivia: suprimir a emissao da
        # lacuna de classe de caractere deixava o "if" falso, o assert de
        # identidade nunca rodava, e o anti-vacuidade passava pela lacuna IRMA.
        # Verde sobre lacuna que sumiu do relatorio - e lacuna que some vira
        # APROVADO indevido do lado de quem revisa. A fixture planta as duas
        # condicoes de proposito; exigir as duas e o unico par honesto.
        Assert-True ($lac -match 'Classe de caractere completa.*\.gitignore:\d+') `
            "a lacuna de classe de caractere sumiu do relatorio, ou nao traz arquivo:linha da regra. Secao: $lac"
        Assert-True ($lac -match 'compartilham sonda.*\.gitignore:\d+') `
            "a lacuna de sonda compartilhada sumiu do relatorio, ou nao traz arquivo:linha da regra. Secao: $lac"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: arquivo de regra que o disco NAO tem e contado, nao some da razao" {
    # QUINTO 'continue' silencioso da 2.4, e o pior deles: 'ArquivosDeRegra' e
    # fixado ANTES do laco, entao um .gitignore rastreado e apagado do disco
    # fazia RegrasTotais despencar e a linha imprimir "N de N regras sondadas"
    # - razao PERFEITA sobre metade do universo. O arquivo que protege o
    # segredo de todo projeto governado deixava de ser lido com o relatorio
    # declarando cobertura cheia. Achado do security-reviewer.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'a.md' = "# nada`n"
        '.gitignore' = "artifacts/`n*.log`n"
        'sub/.gitignore' = "*.tmp`n*.bak`n"
        'sub/b.md' = "# sub`n"
    } })
    try {
        Remove-Item (Join-Path $fx 'sub\.gitignore') -Force
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $listados = @(& git -C $fx ls-files 2>$null)
        $ErrorActionPreference = $anterior
        Assert-True ($listados -contains 'sub/.gitignore') `
            "a fixture nao produziu a condicao: o git deixou de listar o .gitignore apagado"

        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $iLac = $rel.IndexOf('### Lacunas DESTA execucao')
        $iTet = $rel.IndexOf('### Teto permanente da ferramenta')
        $lac = $rel.Substring($iLac, $iTet - $iLac)
        Assert-True ($lac -match 'que o Git lista e o disco NAO tem') `
            "o .gitignore ausente do disco nao virou lacuna: a razao de regras mente com aparencia perfeita"
        Assert-True ($lac -match 'sub/\.gitignore') "a lacuna nao nomeia o arquivo"
        Assert-True ($lac -notmatch '\(nenhuma\)') `
            "a tabela emitiu a lacuna E disse '(nenhuma)'"

        $iCob = $rel.IndexOf('| Area | Coberta |')
        $iFimCob = $rel.IndexOf('## ', $iCob)
        $linhaGi = @($rel.Substring($iCob, $iFimCob - $iCob) -split "`r?`n" | Where-Object { $_ -match '^\| gitignore \|' })
        Assert-True ($linhaGi.Count -eq 1) "nao achei a linha do gitignore na tabela de cobertura"
        Assert-True ($linhaGi[0] -match 'parcial') `
            "a area gitignore se declarou coberta com um arquivo de regra por ler. Linha: $($linhaGi[0])"
    } finally { Remove-Fx $fx }
}

Test-Caso "bootstrap da plataforma: SEM git no PATH chega ao resumo com a instrucao" {
    # A correcao que conectou Invoke-NativoLocal nao tinha teste NENHUM - o
    # qa-reviewer procurou e achou so 'o arquivo existe' em docs.ps1. O
    # arquivo-espelho do template tem casos; este nao tinha.
    #
    # O cenario e o do proprio comentario da correcao: sem git no PATH, a linha
    # que DETECTA a ausencia registrava o problema e a proxima lancava
    # CommandNotFoundException terminante - o script morria antes do resumo que
    # carrega 'winget install --id Git.Git'. Quem mais precisa da instrucao era
    # exatamente quem nao a via.
    #
    # PATH reduzido ao diretorio do PowerShell: git, gh e py somem. Isso
    # exercita os tres ramos de AUSENCIA - nao as tres conversoes, que ficam
    # dentro dos ramos de presenca. A primeira versao deste comentario afirmava
    # "as tres conversoes de uma vez", e o qa-reviewer mostrou que era falso.
    # O par que exercita a conversao de verdade e o caso seguinte.
    #
    # -Check e obrigatorio aqui, e nao e detalhe. SEM ele a secao 2 do
    # bootstrap faz New-Item -Force para nove pastas sob o diretorio-avo do
    # repositorio: nesta maquina e C:\AI-WORKSPACE, mas num clone limpo em
    # D:\tmp\repo - a verificacao que a politica 4.2 exige antes de handoff -
    # a suite criaria D:\_platform, D:\work, D:\university e outras na raiz do
    # drive. Sem permissao de escrita la, New-Item sob 'Stop' mataria o script
    # antes do resumo e este caso falharia com a mensagem ERRADA, apontando um
    # defeito que nao existe. Achado do qa-reviewer; com -Check as assercoes
    # sao identicas e nao ha efeito colateral.
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $soPowerShell = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -Command `
            "`$env:PATH = '$soPowerShell'; & '$(Join-Path $OsRoot 'scripts\bootstrap.ps1')' -Check" 2>&1 | Out-String
        $codigo = $LASTEXITCODE

        Assert-True ($saida -match 'resumo') `
            "o bootstrap da plataforma nao chegou ao resumo sem git no PATH - morreu na chamada solta. Saida: $saida"
        Assert-True ($saida -match 'winget install --id Git\.Git') `
            "o resumo nao traz a instrucao de instalar o git, que e a razao de ele existir. Saida: $saida"
        Assert-True ($saida -match 'BLOQUEIA') `
            "a ausencia de git deveria ser problema bloqueante. Saida: $saida"
        Assert-True ($codigo -eq 1) "esperava saida 1 com git ausente, veio $codigo"
        Assert-True ($saida -notmatch 'CommandNotFoundException') `
            "o script morreu por chamada nativa solta em vez de reportar. Saida: $saida"
        # Sem git, NADA pode ser afirmado sobre init.defaultBranch. A versao
        # anterior imprimia "init.defaultBranch nao e 'main'" sobre uma
        # configuracao que ninguem leu - misturando um fato (git ausente) com
        # uma afirmacao nao medida, justamente para o publico do bootstrap, que
        # e a maquina nova sem Git. Achado do qa-reviewer.
        Assert-True ($saida -match 'init\.defaultBranch nao verificado') `
            "sem git, o resumo nao declara que init.defaultBranch NAO foi verificado. Saida: $saida"
        Assert-True ($saida -notmatch "init\.defaultBranch nao e 'main'") `
            "sem git, o resumo afirma sobre init.defaultBranch sem ter consultado nada. Saida: $saida"
    } finally { $ErrorActionPreference = $anterior }
}

Test-Caso "bootstrap da plataforma: COM git no PATH a conversao nativa roda e le a versao" {
    # O par que faltava. O caso acima remove git, gh e py do PATH, entao as
    # tres chamadas a Invoke-NativoLocal ficam dentro de ramos nao tomados:
    # a funcao inteira ficava sem execucao provada em lugar nenhum - nem o
    # '($rVersao.Saida[0] -split ' ')[2]' que extrai o numero da versao, nem
    # o ramo em que o executavel responde.
    #
    # Aqui o PATH e o normal, com -Check para nao escrever nada. Se a conversao
    # devolvesse Saida vazia ou o -split errasse, a linha viraria o AVISO de
    # "esta no PATH mas nao respondeu", que este caso recusa.
    $anterior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # Sem git no PATH este caso falharia dizendo 'a conversao nao
        # produziu o numero de versao', que manda procurar defeito onde nao
        # ha. A suite ja exige git em outros pontos, entao a dependencia nao
        # piora - o que estava errado era a MENSAGEM. Achado do qa-reviewer.
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "este caso exige 'git' no PATH para exercitar a conversao nativa; sem ele nao ha o que verificar, e a suite nao deve inventar um defeito."
        }
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -Command `
            "& '$(Join-Path $OsRoot 'scripts\bootstrap.ps1')' -Check" 2>&1 | Out-String

        Assert-True ($saida -match 'resumo') "o bootstrap nao chegou ao resumo com o PATH normal. Saida: $saida"
        Assert-True ($saida -match '(?m)git\s+\d+\.\d+') `
            "a conversao nativa nao produziu o numero de versao do git - Invoke-NativoLocal nao foi exercitada. Saida: $saida"
        Assert-True ($saida -notmatch 'git esta no PATH mas nao respondeu') `
            "a conversao rodou e a saida nao foi lida. Saida: $saida"
        Assert-True ($saida -notmatch 'CommandNotFoundException') `
            "chamada nativa solta sobreviveu no caminho de presenca. Saida: $saida"
    } finally { $ErrorActionPreference = $anterior }
}

Test-Caso "relatorio: as linhas de cobertura novas dizem o que os campos medem" {
    # Os tres campos que ganharam leitor - GhDisponivel, RegrasEfetivas,
    # RedeConsultada - passaram a aparecer no relatorio, e o qa-reviewer
    # apontou que NENHUM caso afirmava sobre essas linhas: as correcoes
    # estavam provadas por leitura, nao por execucao.
    #
    # A fixture tem DOIS arquivos de CI e apaga UM do disco depois do commit,
    # para que 'lido' e 'ausente' saiam com numeros DIFERENTES e nao-zero. Com
    # zero dos dois lados, trocar um campo pelo outro - ou pelo literal 0 -
    # nao mudava o relatorio: era verde sobre ramo que nao podia falhar.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'a.md'                        = "# nada`n"
        '.gitignore'                  = "artifacts/`n*.log`n"
        '.github/workflows/ci.yml'    = "name: ci`non: [push]`n"
        '.github/workflows/solto.yml' = "name: solto`non: [push]`n"
    } })
    try {
        # Rastreado e apagado do disco: o caso de ArquivosDeCIAusentes.
        Remove-Item (Join-Path $fx '.github/workflows/solto.yml') -Force

        # -SemRede: o caminho em que RedeConsultada e falso.
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        # Escopa a TABELA DE COBERTURA: '| exposicao externa |' tambem casa a
        # linha de contagem de achados no fim do relatorio, e o filtro cru
        # devolvia duas. Acusar "nao achei" quando havia duas e mensagem que
        # manda procurar no lugar errado.
        $iCob = $rel.IndexOf('| Area | Coberta |')
        $iFimCob = $rel.IndexOf('## ', $iCob)
        $tabCob = $rel.Substring($iCob, $iFimCob - $iCob)
        $linhaEx = @($tabCob -split "`r?`n" | Where-Object { $_ -match '^\| exposicao externa \|' })
        Assert-True ($linhaEx.Count -eq 1) "nao achei a linha de exposicao na tabela de cobertura"
        Assert-True ($linhaEx[0] -match 'rede NAO consultada') `
            "com -SemRede a linha nao declara que a visibilidade do remoto nao foi verificada. Linha: $($linhaEx[0])"
        # Os DOIS numeros, exatos e distintos: 1 lido, 1 ausente. Sem isto,
        # trocar $ex.ArquivosDeCI por 0 literal nao seria detectado.
        Assert-True ($linhaEx[0] -match '1 arquivo\(s\) de CI lido\(s\) e 1 ausente\(s\) do disco') `
            "a linha nao traz a contagem correta de CI lido e ausente. Linha: $($linhaEx[0])"

        $linhaGi = @($tabCob -split "`r?`n" | Where-Object { $_ -match '^\| gitignore \|' })
        Assert-True ($linhaGi.Count -eq 1) "nao achei a linha de gitignore"
        Assert-True ($linhaGi[0] -match 'provadas EFETIVAS') `
            "a linha de gitignore nao traz a razao de regras provadas efetivas"
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: com gh disponivel a linha de exposicao DIZ que ele estava" {
    # A metade de GhDisponivel que o caso acima nao alcanca: sob -SemRede o
    # texto do gh e SOBRESCRITO pelo da rede, entao 'gh disponivel' nunca
    # aparecia em assercao nenhuma - grep em tests/ devolvia zero. O ramo
    # verdadeiro do campo so e visivel numa execucao COM rede, usando a
    # costura de teste declarada.
    $gh = New-GhFalso -Resposta 'PRIVATE'
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        git -C $fx remote add origin 'https://github.com/alguem/repo-fabricado.git' 2>$null
        $env:OS_SCAN_GH = $gh
        $null = Invoke-Scan $fx
        $rel = Get-Rel $fx
        $iCob = $rel.IndexOf('| Area | Coberta |')
        $iFimCob = $rel.IndexOf('## ', $iCob)
        $tabCob = $rel.Substring($iCob, $iFimCob - $iCob)
        $linhaEx = @($tabCob -split "`r?`n" | Where-Object { $_ -match '^\| exposicao externa \|' })
        Assert-True ($linhaEx.Count -eq 1) "nao achei a linha de exposicao na tabela de cobertura"
        Assert-True ($linhaEx[0] -match 'gh disponivel') `
            "com gh respondendo, a linha nao declara que ele estava disponivel. Linha: $($linhaEx[0])"
        Assert-True ($linhaEx[0] -notmatch 'rede NAO consultada') `
            "sem -SemRede a linha ainda diz que a rede nao foi consultada. Linha: $($linhaEx[0])"
    } finally {
        Remove-Item Env:\OS_SCAN_GH -ErrorAction SilentlyContinue
        Remove-Fx $fx; Remove-Item $gh -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "excecao: campo so com ESPACOS nao cobre nada - declarado e vazio nao e declarado" {
    # O portao que rebaixa achado MEDIA no fluxo privado foi corrigido neste
    # delta - de '-not $Excecao.$c' para IsNullOrWhiteSpace - e nao tinha caso
    # nenhum. O qa-reviewer mostrou a assimetria: o gemeo desse mesmo conserto,
    # no harness do template, GANHOU caso ('so espacos entre aspas'); o portao
    # de seguranca, nao. O caso vizinho usa -SemJustificativa, que OMITE a
    # linha - condicao que o '-not' antigo tambem rejeitava, entao reverter
    # deixava a suite verde.
    #
    # Campo declarado e vazio nao e criterio declarado. Espaco entre aspas e
    # YAML valido e passa por 'a chave existe'.
    $y = @()
    $y += 'classificacao:'
    $y += '  criticidade: "alta"'
    $y += '  dados_sensiveis: true'
    $y += '  dados_sensiveis_excecoes:'
    $y += '    - caminho: "contatos.md"'
    $y += ('      categoria: "' + $CAT_EMAIL + '"')
    $y += '      natureza: "fixture"'
    $y += '      justificativa: "   "'
    $y += '      decisao: "aceito no fluxo privado"'
    $y += '      status: "aceito-por-excecao"'
    $y += '      decidido_em: "2026-09-08"'
    $y += '      escopo: "privado"'
    $y += '      onde_esta_registrado: "ADR-0010"'
    $y += 'verificacao:'
    $y += '  revisao_independente: "qa+security"'

    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{
        'contatos.md'  = $EMAIL_TERCEIRO + "`n"
        'project.yaml' = (($y -join "`n") + "`n")
    } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($r.Exit -eq 1) `
            "excecao com justificativa so de espacos desarmou o achado (exit $($r.Exit)) - declarado e vazio virou declarado"
        Assert-True ($rel -match 'NAO cobrem nada') `
            "a excecao incompleta nao aparece na subsecao de excecoes que nao cobrem nada"
        Assert-True ($rel -match 'justificativa') `
            "o relatorio nao diz QUAL campo esta vazio - sem isso nao da para distinguir de 'nao casou'"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: negacao que REABRE diretorio vira lacuna DESTA execucao" {
    # A ressalva vivia so no item 4 do backlog do STATE.md: as 28 sondas de nome
    # canonico perguntam pela raiz e por cada diretorio com .gitignore proprio,
    # nunca por um caminho DENTRO da subarvore que um '!' liberou. O relatorio
    # dizia "28 de 28 nomes canonicos cobertos" sem essa qualificacao.
    #
    # O security-reviewer aplicou contra isso a regra que esta subfase escreveu:
    # lacuna declarada so em conversa - ou so no backlog - nao e lacuna
    # declarada. O alvo real e o projeto governado que copiar o template e
    # colocar dado de verdade em examples/.
    $gi = @(
        'artifacts/'
        '*.log'
        '/examples/'
        '!/examples/'
        '!/examples/**'
    ) -join "`n"
    $fx = New-RepoFx2 -Gitignore ($gi + "`n") -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'subarvore liberada por negacao') `
            "o relatorio nao declara que as sondas canonicas nao entram na subarvore reaberta por '!'"
        Assert-True ($rel -match '2 regra\(s\) de negacao') `
            "a lacuna nao traz QUANTAS negacoes reabrem diretorio"
        Assert-True ($rel -match 'examples') `
            "a lacuna nao nomeia a regra - sem isso nao da para ir conferir"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: SEM negacao de diretorio, a lacuna de subarvore NAO aparece" {
    # O par negativo. Uma lacuna que aparece sempre nao informa nada, e a tabela
    # de lacunas e a secao que o protocolo manda ler PRIMEIRO: enche-la de linha
    # incondicional e a forma mais rapida de fazer o revisor parar de le-la.
    $fx = New-RepoFx2 -Gitignore "artifacts/`n*.log`n" -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -notmatch 'subarvore liberada por negacao') `
            "sem nenhuma negacao de diretorio, o relatorio ainda declara a lacuna de subarvore"
    } finally { Remove-Fx $fx }
}

Test-Caso "relatorio: a divergencia entre portao e tabela de aceitos VIRA lacuna, nao so nota" {
    # A guarda nova compara o contador do portao de excecoes com a lista que a
    # tabela de aceitos renderiza. O security-reviewer achou dois defeitos nela:
    # vivia dentro do ramo alcancavel so quando a tabela JA tinha linha - cega
    # exatamente no caso "o portao desarmou N e a tabela mostra zero" -, e,
    # dizendo-se lacuna, nao entrava no acumulador que decide imprimir
    # "(nenhuma)". Uma execucao cuja unica anomalia fosse a divergencia
    # imprimiria a nota E "(nenhuma) - nenhuma area cai para INCONCLUSIVO".
    #
    # Hoje a divergencia e INALCANCAVEL: os dois numeros sao a mesma medicao
    # lida duas vezes. Por isso a costura declarada - sem ela esta guarda so
    # poderia ser verificada por leitura, e o valor dela e futuro.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $env:OS_SCAN_FORCAR_DIVERGENCIA = '1'
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'Quantos achados a excecao desarmou') `
            "a divergencia nao aparece na tabela de lacunas DESTA execucao"
        Assert-True ($rel -notmatch '\| \(nenhuma\) \|') `
            "o relatorio declara a divergencia E imprime '(nenhuma)' - a tabela se autocontradiz, que e a classe que esta secao existe para fechar"
        Assert-True ($rel -match 'OS_SCAN_FORCAR_DIVERGENCIA` \*\*ATIVA\*\*') `
            "a costura de teste nao esta declarada na linha de modificadores - costura silenciosa e pior que costura nenhuma"
    } finally {
        Remove-Item Env:\OS_SCAN_FORCAR_DIVERGENCIA -ErrorAction SilentlyContinue
        Remove-Fx $fx
    }
}

Test-Caso "relatorio: SEM a costura, nenhuma divergencia e declarada" {
    # O par negativo da costura: se ela vazasse ligada, todo relatorio traria
    # uma lacuna falsa - e lacuna falsa gasta a atencao que a verdadeira precisa.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -notmatch 'Quantos achados a excecao desarmou') `
            "sem a costura, o relatorio ainda declara divergencia"
        Assert-True ($rel -notmatch 'OS_SCAN_FORCAR_DIVERGENCIA') `
            "a costura aparece como ativa sem ter sido ativada"
    } finally { Remove-Fx $fx }
}

Test-Caso "gitignore: a lacuna de negacao SOZINHA derruba a coluna Coberta" {
    # O MEDIA BLOQUEANTE da rodada 13, e o unico de toda a subfase classificado
    # assim pela regra de encerramento.
    #
    # 'NegacoesQueAbremSubarvore' emitia linha de lacuna e entrava no acumulador
    # do "(nenhuma)", mas NAO no portao da coluna "Coberta". O contrato esta
    # escrito no proprio security-scan.ps1, 30 linhas acima do defeito: "fato que
    # emite linha na tabela de lacunas entra no acumulador E na coluna; sao dois
    # portoes que consomem o mesmo fato; consertar um deixa o outro mentindo".
    #
    # Nao dispara no scan DESTE repositorio, e e por isso que passou verde: aqui
    # o .gitignore do template tem classe de caractere e "**", que ja forcam
    # parcial por outro motivo. O caso anterior tambem mascarava, porque a
    # fixture dele produzia 'NaoVerificaveis' junto.
    #
    # Esta fixture e a do qa-reviewer, e a escolha dela e o ponto: a negacao tem
    # de ser a UNICA lacuna. '/output/*' e '!/output/' derivam sondas DIFERENTES,
    # entao nenhuma e ambigua, nao ha classe de caractere e nao ha arquivo de
    # regra ausente. Se a coluna sair 'sim', a celula afirma cobertura cheia
    # sobre a mesma razao que a lacuna, trinta linhas abaixo, acaba de qualificar
    # - falsa garantia na tabela que o protocolo manda ler PRIMEIRO.
    $fx = New-RepoFx2 -Gitignore "artifacts/`n/output/*`n!/output/`n" `
                      -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        $iCob = $rel.IndexOf('| Area | Coberta |')
        $iFimCob = $rel.IndexOf('## ', $iCob)
        $tabCob = $rel.Substring($iCob, $iFimCob - $iCob)
        $linhaGi = @($tabCob -split "`r?`n" | Where-Object { $_ -match '^\| gitignore \|' })
        Assert-True ($linhaGi.Count -eq 1) "nao achei a linha de gitignore na tabela de cobertura"

        # A lacuna TEM de estar la - senao o caso passaria pela razao errada.
        $iLac = $rel.IndexOf('### Lacunas DESTA execucao')
        $iTet = $rel.IndexOf('### Teto permanente da ferramenta')
        $lac = $rel.Substring($iLac, $iTet - $iLac)
        Assert-True ($lac -match 'subarvore liberada por negacao') `
            "a fixture nao produziu a lacuna de negacao: o caso passaria sem exercitar o ramo"
        # E nenhuma das OUTRAS lacunas de gitignore, senao a coluna cairia por
        # outro motivo e o defeito continuaria mascarado.
        Assert-True ($lac -notmatch 'Classe de caractere completa') `
            "a fixture produziu lacuna de classe de caractere: a coluna cairia por outro motivo e o defeito ficaria mascarado"
        Assert-True ($lac -notmatch 'compartilham sonda') `
            "a fixture produziu lacuna de sonda compartilhada: mesmo mascaramento"

        Assert-True ($linhaGi[0] -match '\| \*\*parcial\*\* \|') `
            "a lacuna de negacao esta declarada e a coluna Coberta diz 'sim': a tabela que o protocolo manda ler PRIMEIRO afirma cobertura cheia sobre a razao que a lacuna acaba de qualificar. Linha: $($linhaGi[0])"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# Test-TemHistorico e Test-HeadResolvivel - as duas metades de Test-TemCommits
#
# O backlog item 1 nomeava a ambiguidade: um predicado respondia "ha historico?"
# e "o HEAD resolve?", e era usado para as duas. Depois de 'git init' +
# 'remote add' + 'fetch' as respostas DIVERGEM, e as duas correcoes obvias
# estavam erradas nos dois sentidos. O /os:doctor roda sobre repositorio em
# estado arbitrario, que e onde isso sai do improvavel - por isso a separacao
# e pre-requisito da 2.5.
#
# Os casos abaixo cobrem os cinco estados, e para cada um as DUAS perguntas.
# =============================================================================

function New-RepoVazio {
    # 'git init' e para. E o fluxo normal do /os:new-project.
    #
    # O par Continue/finally e obrigatorio, e nao e estilo: o runner fixa
    # ErrorActionPreference='Stop', e o runbook desta casa registra que
    # '2>$null' NAO impede stderr de executavel nativo de virar erro
    # terminante. Em maquina SEM 'init.defaultBranch' configurado, o 'git
    # init' escreve o hint sobre 'master' em stderr - e os casos destes
    # predicados falhariam com mensagem que nao tem relacao com eles.
    # Achado do qa-reviewer; aqui passava verde so porque esta maquina tem
    # init.defaultBranch=main.
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $t = Join-Path $env:TEMP ("pred-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q 2>$null
        git -C $t config user.name  'Fixture'    2>$null
        git -C $t config user.email 'fx@invalid' 2>$null
        # As outras tres defesas de New-RepoFx2, que a primeira versao desta
        # fixture nao copiou junto com o par Continue/finally. O qa-reviewer
        # nomeou o cenario: com 'core.safecrlf=true' no --global, o 'git add'
        # recusa o a.md gravado com CRLF, nada e indexado, o commit nao
        # acontece - e como stderr vai para $null, isso e SILENCIOSO. A
        # fixture devolveria um repo SEM commit, e cinco casos ficariam
        # vermelhos culpando os predicados.
        git -C $t config core.autocrlf false 2>$null
        git -C $t config core.safecrlf false 2>$null
        git -C $t config core.excludesfile (Join-Path $t '.git/vazio-de-proposito') 2>$null
        return $t
    } finally { $ErrorActionPreference = $anterior }
}

function New-RepoComCommit {
    # Mesmo par da irma acima, e pela mesma razao: 'git add' emite o aviso
    # de fim de linha em stderr, que sob 'Stop' seria terminante.
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $t = New-RepoVazio
        Set-Content -Path (Join-Path $t 'a.md') -Value "# nada" -Encoding ASCII
        git -C $t add -A 2>$null
        git -C $t commit -q -m 'inicial' 2>$null
        return $t
    } finally { $ErrorActionPreference = $anterior }
}

Test-Caso "predicados: repo recem-init nao tem historico NEM HEAD resolvivel" {
    $t = New-RepoVazio
    try {
        Assert-True ((Test-TemHistorico $t) -eq $false) `
            "repositorio sem nenhum commit foi dado por COM historico"
        Assert-True ((Test-HeadResolvivel $t) -eq $false) `
            "repositorio sem nenhum commit teve o HEAD dado por resolvivel"
    } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "predicados: repo com commit tem historico E HEAD resolvivel" {
    $t = New-RepoComCommit
    try {
        Assert-True (Test-TemHistorico $t)   "repositorio com commit foi dado por SEM historico"
        Assert-True (Test-HeadResolvivel $t) "repositorio com commit teve o HEAD dado por nao resolvivel"
    } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "predicados: com FETCH e sem HEAD local, as duas respostas DIVERGEM" {
    # O caso que motivou a separacao inteira, e o unico em que o predicado
    # antigo nao tinha resposta certa: ha historico buscado, e o HEAD nao
    # nasceu. Devolver falso fazia o detector afirmar "nao existe historico a
    # varrer" sobre um repositorio com blobs; devolver verdadeiro fazia o
    # 'rev-parse --short HEAD' lancar.
    $origem = New-RepoComCommit
    $clone = New-RepoVazio
    try {
        git -C $clone remote add origin $origem 2>$null
        git -C $clone fetch -q origin 2>$null

        Assert-True (Test-TemHistorico $clone) `
            "ha commits buscados em refs/remotes e o predicado disse que NAO ha historico - o detector declararia 'SemCommits' sobre um repositorio com blobs"
        Assert-True ((Test-HeadResolvivel $clone) -eq $false) `
            "o HEAD local nao nasceu e o predicado disse que resolve - 'rev-parse --short HEAD' lancaria"
    } finally {
        Remove-Item $clone -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $origem -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "predicados: WORKTREE ligado responde as duas, em vez de recusar" {
    # A versao anterior LANCAVA quando '.git' era arquivo - "nao da para
    # conferir". Estava certo enquanto ninguem rodava sobre worktree; o
    # /os:doctor roda. Num worktree ligado o HEAD e proprio e as refs sao
    # compartilhadas, entao os dois caminhos DIFEREM e a distincao importa.
    $princ = New-RepoComCommit
    $wt = Join-Path $env:TEMP ("wt-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        git -C $princ worktree add -q -b outra $wt 2>$null
        Assert-True (Test-Path (Join-Path $wt '.git') -PathType Leaf) `
            "a fixture nao produziu um worktree ligado: '.git' devia ser ARQUIVO, e o caso passaria sem exercitar o ramo"
        Assert-True (Test-TemHistorico $wt)   "worktree ligado foi dado por SEM historico"
        Assert-True (Test-HeadResolvivel $wt) "worktree ligado teve o HEAD dado por nao resolvivel"
    } finally {
        git -C $princ worktree remove --force $wt 2>$null
        Remove-Item $wt -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $princ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "predicados: HEAD apontando para ref INEXISTENTE e nao-nascido, nao erro" {
    # 'git checkout -b' antes do primeiro commit produz exatamente isto, e e
    # estado legitimo: HEAD simbolico para uma ref que ainda nao existe.
    $t = New-RepoVazio
    try {
        [System.IO.File]::WriteAllText((Join-Path $t '.git\HEAD'), "ref: refs/heads/nunca-existiu`n")
        Assert-True ((Test-HeadResolvivel $t) -eq $false) `
            "HEAD simbolico para ref inexistente devia ser 'nao nascido', e o predicado recusou ou afirmou o contrario"
    } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "predicados: HEAD ILEGIVEL LANCA em vez de virar 'repo novo'" {
    # O achado do security-reviewer que originou a guarda: o relatorio dizia
    # "repositorio sem nenhum commit: nao existe historico a varrer" - uma
    # AFIRMACAO POSITIVA de cobertura, com exit 0 - para um repositorio cujo
    # historico ele nao conseguiu ler. "Nao consegui determinar" nunca pode
    # virar falso verde.
    $t = New-RepoComCommit
    try {
        # sha de 40 zeros: HEAD destacado apontando para objeto que nao existe.
        [System.IO.File]::WriteAllText((Join-Path $t '.git\HEAD'), ('0' * 40) + "`n")
        # A mensagem importa: assercao que aceita QUALQUER excecao passa
        # tambem quando o codigo sob teste nao existe. Foi o que aconteceu na
        # primeira versao destes casos, postos numa suite que nao carrega a
        # lib: tres deles ficaram verdes com "comando nao reconhecido".
        $erro = ''
        try { $null = Test-HeadResolvivel $t } catch { $erro = "$_" }
        # A mensagem ESPECIFICA, nao o prefixo: 'Test-HeadResolvivel:' e comum
        # as cinco excecoes da funcao, entao o caso ficaria verde pelo throw
        # errado - por exemplo se Get-CaminhosDoGit passasse a devolver nulo.
        # E uma casa mais fina do mesmo vicio que esta entrega documenta.
        Assert-True ($erro -match 'nao e simbolico') `
            "HEAD destacado para objeto inexistente devia LANCAR pela razao certa - HEAD nao simbolico que o git nao resolveu. Erro recebido: '$erro'"
    } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "predicados: ref EXISTE e o git nao resolve - isso e falha de leitura" {
    # A guarda de sanidade que o predicado antigo ja tinha, preservada: se o
    # git disse "nao resolvi" e a ref esta la no disco, quem falhou foi o git.
    $t = New-RepoComCommit
    try {
        $ref = (Get-Content (Join-Path $t '.git\HEAD') -Raw).Trim() -replace '^ref:\s*', ''
        # Corrompe o CONTEUDO da ref, mantendo o arquivo: rev-parse falha e a
        # ref continua existindo - exatamente a condicao da guarda.
        [System.IO.File]::WriteAllText((Join-Path $t (Join-Path '.git' $ref)), "nao-e-um-sha`n")
        $erro = ''
        try { $null = Test-HeadResolvivel $t } catch { $erro = "$_" }
        Assert-True ($erro -match 'a ref EXISTE no disco') `
            "a ref existe no disco e o git nao a resolveu: isso e falha de leitura e tem de LANCAR com essa razao, nao virar 'HEAD nao nascido'. Erro recebido: '$erro'"
    } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "predicados: caminho que NAO e repositorio nao vira 'repositorio vazio'" {
    $t = Join-Path $env:TEMP ("naorepo-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    try {
        $erroH = ''
        try { $null = Test-TemHistorico $t } catch { $erroH = "$_" }
        # Num diretorio que nao e repositorio, 'rev-list --all' sai com 128 e o
        # predicado lanca NO PORTAO DO CODIGO DE SAIDA, antes de chegar ao
        # resolvedor de caminhos. A razao que ele da - 'o historico NAO foi
        # lido' - e a correta para este estado.
        Assert-True ($erroH -match 'O historico NAO foi lido') `
            "diretorio que nao e repositorio devia LANCAR dizendo que o historico nao foi lido. Erro recebido: '$erroH'"

        $erroR = ''
        try { $null = Test-HeadResolvivel $t } catch { $erroR = "$_" }
        Assert-True ($erroR -match 'nao expoe um diretorio Git legivel') `
            "diretorio que nao e repositorio devia LANCAR pela razao certa. Erro recebido: '$erroR'"
    } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "predicados: worktree com HEAD NAO NASCIDO forca a leitura de gitdir e commondir" {
    # O achado bloqueante em que os DOIS revisores convergiram, por caminhos
    # independentes. O caso de worktree que existia criava um worktree de
    # verdade e ate provava a fixture - e mesmo assim passava sem executar UMA
    # LINHA de Get-CaminhosDoGit: os dois predicados retornam $true nos ramos
    # POSITIVOS, antes de chamar o resolvedor. Trocar o bloco inteiro de
    # gitdir:/commondir por 'return $null' mantinha os oito casos verdes.
    #
    # A assercao anti-vacuidade de la confere que a FIXTURE e um worktree, nao
    # que o RAMO foi alcancado. Da a impressao de cobrir e nao cobre - a mesma
    # classe que esta entrega documenta, um nivel adiante.
    #
    # Aqui o HEAD do worktree e reescrito para uma ref que nao existe. Isso
    # OBRIGA o caminho negativo: o predicado tem de ler o arquivo '.git', seguir
    # 'gitdir:', achar o HEAD proprio do worktree, ler 'commondir' para saber
    # onde moram as refs, e concluir "nao nascido" em vez de lancar. Se o
    # resolvedor devolver $null ou um ComumDir errado, o resultado e excecao ou
    # verdadeiro - nunca falso -, e o caso fica vermelho.
    $princ = New-RepoComCommit
    $wt = Join-Path $env:TEMP ("wtneg-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        git -C $princ worktree add -q -b ramo-novo $wt 2>$null
        $arqGit = Join-Path $wt '.git'
        Assert-True (Test-Path $arqGit -PathType Leaf) `
            "a fixture nao produziu worktree ligado: '.git' devia ser ARQUIVO"

        # O resolvedor, exercitado DIRETAMENTE - e nao de raspao.
        $g = Get-CaminhosDoGit -Path $wt
        Assert-True ($null -ne $g) "Get-CaminhosDoGit devolveu nulo para um worktree ligado valido"
        Assert-True $g.Ligado "o worktree ligado nao foi reconhecido como ligado"
        Assert-True ($g.GitDir -ne $g.ComumDir) `
            "em worktree ligado o GitDir e o ComumDir TEM de diferir - o HEAD e proprio e as refs sao compartilhadas. GitDir='$($g.GitDir)' ComumDir='$($g.ComumDir)'"
        Assert-True (Test-Path (Join-Path $g.GitDir 'HEAD') -PathType Leaf) `
            "o GitDir resolvido nao contem o HEAD do worktree: 'gitdir:' foi lido errado"
        Assert-True (Test-Path (Join-Path $g.ComumDir 'refs') -PathType Container) `
            "o ComumDir resolvido nao contem 'refs/': 'commondir' foi lido errado"

        # E agora o ramo NEGATIVO, que so chega ao fim se o resolvedor acertou.
        [System.IO.File]::WriteAllText((Join-Path $g.GitDir 'HEAD'), "ref: refs/heads/nunca-existiu`n")
        $r = Test-HeadResolvivel $wt
        Assert-True ($r -eq $false) `
            "worktree com HEAD apontando para ref inexistente devia responder 'nao nascido'. Responder verdadeiro, ou lancar, significa que gitdir:/commondir nao foram resolvidos"

        # O historico continua alcancavel: as refs sao as do repositorio
        # principal, e e exatamente isso que ComumDir existe para achar.
        Assert-True (Test-TemHistorico $wt) `
            "o worktree compartilha as refs do principal: ha historico a varrer mesmo com o HEAD nao nascido"
    } finally {
        git -C $princ worktree remove --force $wt 2>$null
        Remove-Item $wt -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $princ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "predicados: ref QUEBRADA faz o git falhar, e falha nao vira 'sem historico'" {
    # A guarda de sanidade de Test-TemHistorico, apontada pelos dois revisores
    # como sem caso. E a traducao, para o lado do historico, do achado original
    # do security-reviewer: git diz vazio, disco diz o contrario, e quem falhou
    # foi o git. So a gemea de Test-HeadResolvivel ('a ref EXISTE no disco')
    # estava provada.
    #
    # A fixture cria uma ref solta apontando para um sha que nao existe:
    # 'rev-list --all' ignora ref quebrada e devolve vazio, e o disco tem ref.
    $t = New-RepoVazio
    try {
        $dir = Join-Path $t '.git\refs\heads'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'fantasma'), ('a' * 40) + "`n")

        $erro = ''
        try { $null = Test-TemHistorico $t } catch { $erro = "$_" }
        # O que a fixture produz de verdade: 'rev-list --all' encontra a ref
        # quebrada e sai com codigo != 0. O predicado lanca dizendo que o
        # historico NAO foi lido - e nao devolve falso, que o detector
        # traduziria em 'nao existe historico a varrer'.
        #
        # A guarda seguinte - 'rev-list vazio COM refs no disco' - NAO e
        # alcancada por esta fixture nem por nenhuma outra que eu tenha achado:
        # o git falha antes de devolver vazio. Ela fica como segunda linha de
        # defesa sem par de execucao, declarada no backlog. Errar alto sem
        # caso e diferente de errar baixo sem caso.
        Assert-True ($erro -match 'O historico NAO foi lido') `
            "ref quebrada faz o git falhar, e falha de leitura tem de LANCAR, nao virar 'repositorio sem commits'. Erro recebido: '$erro'"
    } finally { Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "detectores: em repo so com FETCH, historico e IDENTIDADES sao lidos - nao 'SemCommits'" {
    # Item 28 do backlog, e a unica lacuna daquele conjunto cuja direcao era
    # FALSO VERDE - as outras erram alto, lancando.
    #
    # Os predicados estao bem cobertos por dez casos. O que NAO estava pinado
    # e a correcao em si: QUAL detector faz QUAL pergunta. Reverter
    # scan-historico.ps1 ou scan-dado-pessoal.ps1 para Test-HeadResolvivel
    # mantinha os 275 casos verdes - e voltaria a sair 'SemCommits', que e
    # AFIRMACAO POSITIVA de cobertura, sobre um repositorio com historico
    # buscado e blobs no banco.
    #
    # O estado e o mesmo do caso de predicado: 'git init' + 'remote add' +
    # 'fetch'. Ha commits alcancaveis por refs/remotes e o HEAD local nao
    # nasceu. Aqui a assercao muda de lugar: sai dos predicados e vai para o
    # que os CONSUMIDORES declaram.
    $origem = New-RepoComCommit
    $clone = New-RepoVazio
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            # O autor do commit da ORIGEM tem de ser diferente do e-mail
            # configurado no CLONE. Sem isso, 'git config --get-all user.email'
            # devolve a identidade de qualquer jeito e a assercao passa mesmo
            # com o ramo de historico desligado - foi o que a mutacao mostrou.
            # Guarda ANTES do verbo destrutivo, e no ponto da chamada - nao na
            # fixture. 'git -C ""' NAO muda de diretorio: com $origem vazio, o
            # '--amend --reset-author' logo abaixo reescreveria o historico do
            # repositorio REAL da plataforma, que e o diretorio corrente da
            # suite, e com stderr suprimido isso seria silencioso. Nao e
            # alcancavel hoje - Join-Path lanca antes -, mas a protecao estava
            # so na fixture. Achado do security-reviewer; o raio de dano e
            # exatamente o que o CLAUDE.md proibe.
            if ([string]::IsNullOrWhiteSpace($origem) -or -not (Test-Path (Join-Path $origem '.git'))) {
                throw "fixture nao produziu repositorio de origem valido ('$origem'): abortando ANTES de qualquer comando que reescreva historico."
            }
            git -C $origem config user.email 'autor@origem.invalid' 2>$null
            git -C $origem commit -q --amend --reset-author -m 'inicial' 2>$null
            git -C $clone config user.email 'local@clone.invalid' 2>$null
            git -C $clone remote add origin $origem 2>$null
            git -C $clone fetch -q origin 2>$null
        } finally { $ErrorActionPreference = $anterior }

        # Pre-condicao: se a fixture nao produzir a divergencia, o caso passa
        # por vacuidade e nao prova nada.
        Assert-True (Test-TemHistorico $clone) "a fixture nao produziu historico buscado"
        Assert-True ((Test-HeadResolvivel $clone) -eq $false) "a fixture produziu HEAD resolvivel: o estado divergente nao foi criado"

        # 1. O detector de historico TEM de varrer.
        $rh = Get-AchadosHistorico -Path $clone
        Assert-True ($rh.Cobertura.SemCommits -eq $false) `
            "o detector de historico declarou 'SemCommits' sobre um repositorio com commits buscados por fetch - afirmacao POSITIVA de cobertura sobre o que ele nao varreu"
        Assert-True ($rh.Cobertura.Commits -gt 0) `
            "o detector declarou 0 commit num repositorio cujas refs remotas apontam para commit: a varredura nao aconteceu"

        # 2. O detector de dado pessoal TEM de enxergar a identidade que
        #    assinou o commit buscado. Se perguntasse pelo HEAD, a lista
        #    voltaria vazia e todo e-mail viraria 'de terceiro'.
        $ids = @(Get-IdentidadesDoRepositorio -Path $clone)
        Assert-True ($ids -contains 'autor@origem.invalid') `
            "a identidade que assina o commit BUSCADO nao foi lida - e ela so pode vir do historico, porque o config local declara outro e-mail. Sem ela, todo e-mail do repositorio seria classificado como de TERCEIRO. Lidas: $($ids -join ', ')"
        Assert-True ($ids -contains 'local@clone.invalid') `
            "a identidade do config local sumiu: a leitura de config quebrou. Lidas: $($ids -join ', ')"
    } finally {
        Remove-Item $clone -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $origem -Recurse -Force -ErrorAction SilentlyContinue
    }
}


# =============================================================================
# LEITURA DE CONTEUDO - backlog item 11
#
# A pergunta que estes casos existem para responder: um arquivo que a
# ferramenta NAO consegue ler como texto pode entrar no relatorio como
# "examinado"? Ate aqui podia, e essa e a definicao de falso verde - o numero
# da cobertura subia sobre um arquivo cujo conteudo ninguem viu.
# =============================================================================

Test-Caso "codificacao: Read-TextoDeArquivo ACEITA UTF-8 valido e UTF-16 COM BOM" {
    # O par positivo. Sem ele, um leitor que recusasse tudo passaria nos dois
    # casos negativos abaixo e derrubaria a cobertura do repositorio inteiro.
    $d = Join-Path $env:TEMP ("enc-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $u8 = Join-Path $d 'u8.md'
        [System.IO.File]::WriteAllText($u8, "acentuacao: cao, coracao`n", (New-Object System.Text.UTF8Encoding($false)))
        $t8 = Read-TextoDeArquivo $u8
        Assert-True ($null -ne $t8) "recusou um arquivo UTF-8 perfeitamente valido"
        Assert-True ($t8 -match 'coracao') "leu o arquivo UTF-8 e perdeu o conteudo"

        # UTF-16 COM BOM nao e ilegivel: ReadAllText detecta o preambulo e
        # decodifica certo. Recusar aqui seria recusar arquivo legitimo - e o
        # modo de falha oposto, igualmente caro.
        $u16 = Join-Path $d 'u16bom.md'
        [System.IO.File]::WriteAllBytes($u16, ([System.Text.Encoding]::Unicode.GetPreamble() + [System.Text.Encoding]::Unicode.GetBytes('token: ' + $TOKEN_FALSO)))
        $t16 = Read-TextoDeArquivo $u16
        Assert-True ($null -ne $t16) "recusou UTF-16 COM BOM, que ReadAllText decodifica corretamente"
        Assert-True ($t16 -match ([regex]::Escape($TOKEN_FALSO))) `
            "leu UTF-16 com BOM e o conteudo nao saiu legivel: o padrao de credencial nao casaria"
    } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "codificacao: Read-TextoDeArquivo RECUSA byte invalido E recusa NUL" {
    $d = Join-Path $env:TEMP ("enc-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        # 0xE7 solto: 'c cedilha' em Windows-1252, sequencia invalida em
        # UTF-8. E o arquivo salvo em ANSI pelo Bloco de Notas.
        $ansi = Join-Path $d 'ansi.md'
        [System.IO.File]::WriteAllBytes($ansi, ([byte[]](0x61, 0xE7, 0x61, 0x0A)))
        Assert-True ($null -eq (Read-TextoDeArquivo $ansi)) `
            "aceitou arquivo com byte invalido para UTF-8: a leitura devolveria U+FFFD no lugar do byte, em silencio"

        # E o caso que a leitura estrita SOZINHA nao pega, e supor que pegava
        # era o erro: UTF-16LE sem BOM de conteudo ASCII e UTF-8 VALIDO byte a
        # byte, porque U+0000 e code point legitimo.
        $u16 = Join-Path $d 'u16.md'
        [System.IO.File]::WriteAllBytes($u16, [System.Text.Encoding]::Unicode.GetBytes('token: ' + $TOKEN_FALSO))
        $estrita = New-Object System.Text.UTF8Encoding($false, $true)
        $decodificou = $false
        try { $null = [System.IO.File]::ReadAllText($u16, $estrita); $decodificou = $true } catch { }
        Assert-True $decodificou `
            "PRE-CONDICAO do caso: UTF-16 sem BOM tinha de passar pela leitura estrita. Se nao passa, este caso virou copia do anterior e nao prova que a recusa de NUL e necessaria"
        Assert-True ($null -eq (Read-TextoDeArquivo $u16)) `
            "aceitou UTF-16 sem BOM: o texto sai com um NUL entre cada letra e nenhum padrao de credencial casa - exatamente o cenario do item 11"
    } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "codificacao: arquivo ILEGIVEL nao entra como examinado e sai como lacuna NOMEADA" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n"; 'ansi.md' = "provisorio`n" } })
    try {
        # O token entra DEPOIS do commit: o historico guarda 'provisorio', e
        # assim o caso mede o working tree, e nao o detector de historico.
        $alvo = Join-Path $fx 'ansi.md'
        [System.IO.File]::WriteAllBytes($alvo, ([byte[]](0x61, 0xE7, 0x20) + [System.Text.Encoding]::ASCII.GetBytes($TOKEN_FALSO)))
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx

        Assert-True ($rel -match 'ILEGIVEL\(eis\) como texto') `
            "o relatorio nao declarou a lacuna de arquivo ilegivel: o arquivo sumiu do balanco em silencio"
        Assert-True ($rel -match 'ansi\.md') `
            "a lacuna nao NOMEIA o arquivo - contagem sem identidade nao deixa o revisor conferir no disco"
        # As tres areas que leem conteudo do working tree. Nenhuma pode dizer
        # 'sim' sobre um conjunto de arquivos do qual uma parte nao foi lida.
        foreach ($a in @('working tree', 'dado de terceiro', 'exposicao externa')) {
            Assert-True ($rel -match ('\| ' + [regex]::Escape($a) + ' \| \*\*parcial\*\* \|')) `
                "a area '$a' foi declarada COBERTA com um arquivo que ela nao conseguiu ler"
        }
        Assert-True ($rel -notmatch '\| \(nenhuma\) \|') `
            "o acumulador de lacunas contingentes declarou '(nenhuma)' com uma lacuna impressa na mesma tabela - os dois portoes tem de consumir o mesmo fato"
    } finally { Remove-Fx $fx }
}

Test-Caso "codificacao: UTF-16 sem BOM no working tree tambem derruba a cobertura" {
    # O caso irmao do anterior, e nao e redundante: aquele exercita a recusa
    # por byte invalido, este exercita a recusa por NUL. Reverter so uma das
    # duas deixaria o outro caso verde.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n"; 'u16.md' = "provisorio`n" } })
    try {
        $alvo = Join-Path $fx 'u16.md'
        [System.IO.File]::WriteAllBytes($alvo, [System.Text.Encoding]::Unicode.GetBytes('token: ' + $TOKEN_FALSO))
        $estrita = New-Object System.Text.UTF8Encoding($false, $true)
        $decodificou = $false
        try { $null = [System.IO.File]::ReadAllText($alvo, $estrita); $decodificou = $true } catch { }
        Assert-True $decodificou "PRE-CONDICAO: o arquivo tinha de ser UTF-8 valido, senao este caso repete o anterior"

        $r = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'u16\.md') "a lacuna nao nomeia o arquivo UTF-16 sem BOM"
        Assert-True ($rel -match '\| working tree \| \*\*parcial\*\* \|') `
            "declarou 'working tree' coberta com um arquivo cujo conteudo saiu salpicado de NUL"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# GUARDA DE REMOTO VAZIO - backlog itens 26 e 30
#
# A guarda existe porque remoto PUBLICO e o unico achado ALTA da area de
# exposicao: se o 'git remote -v' vier vazio por qualquer motivo que nao seja
# "nao ha remoto", a area saia 'sim' sem nunca ter olhado. Ela tinha TRES
# ramos de 'throw' e nenhum par de execucao - correcao escrita para responder
# a um achado, sem nada provando que responde.
# =============================================================================

function Add-SecaoDeRemotoOrfa {
    <#
      Escreve no config a secao '[remote "orfao"]' SEM nenhuma chave.

      Medido: nesse estado 'git remote -v' nao imprime NADA e sai 0, enquanto
      o config declara um remoto. E o estado que a guarda existe para pegar -
      config truncado no meio da escrita, ou 'url' apagada a mao.

      'git remote add' NAO serve como fixture: com url, 'remote -v' imprime e
      a lista de remotos nao fica vazia, entao o ramo nem e alcancado. E uma
      secao COM 'fetch' e sem 'url' tambem nao serve: 'remote -v' imprime o
      nome seguido de tabulacao, e a lista fica com uma entrada vazia.
    #>
    param([Parameter(Mandatory = $true)][string]$Config)
    if (-not (Test-Path $Config -PathType Leaf)) { throw "Add-SecaoDeRemotoOrfa: '$Config' nao existe." }
    Add-Content -Path $Config -Value '[remote "orfao"]' -Encoding Ascii
}

Test-Caso "guarda de remoto: sem remoto e sem [remote no config, a guarda fica CALADA" {
    # O par positivo dos tres ramos. Sem ele, uma guarda que lancasse sempre
    # passaria nos tres casos negativos abaixo.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $r = Get-AchadosExposicao -Path $fx -SemRede
        Assert-True ($r.Cobertura.Remotos -eq 0) "a fixture nao produziu repositorio sem remoto"
    } finally { Remove-Fx $fx }
}

Test-Caso "guarda de remoto: config declara [remote e 'remote -v' vem vazio - LANCA" {
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        Add-SecaoDeRemotoOrfa (Join-Path $fx '.git\config')
        Assert-True (@(git -C $fx remote -v 2>$null).Count -eq 0) `
            "PRE-CONDICAO: 'remote -v' imprimiu algo, entao o ramo da guarda nem e alcancado e o caso passaria por vacuidade"
        $erro = ''
        try { $null = Get-AchadosExposicao -Path $fx -SemRede } catch { $erro = "$_" }
        Assert-True ($erro -match 'declara pelo menos um \[remote') `
            "config declarando remoto com 'remote -v' vazio tem de LANCAR: a area sairia 'sim' sem ter verificado visibilidade nenhuma, e remoto PUBLICO e o unico achado ALTA dela. Erro recebido: '$erro'"
    } finally { Remove-Fx $fx }
}

Test-Caso "guarda de remoto: em WORKTREE ligado, so ComumDir acha o config - item 30" {
    # O caso que discrimina a escolha 'ComumDir'. Num repositorio comum
    # 'Get-CaminhosDoGit' devolve GitDir e ComumDir com o MESMO valor, entao
    # trocar um pelo outro e inerte e o caso acima nao prova nada sobre a
    # escolha. So worktree ligado separa os dois.
    $princ = New-RepoComCommit
    $wt = Join-Path $env:TEMP ("wt-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        git -C $princ worktree add -q -b remotoorfao $wt 2>$null
        Assert-True (Test-Path (Join-Path $wt '.git') -PathType Leaf) `
            "PRE-CONDICAO: a fixture nao produziu worktree ligado ('.git' tinha de ser ARQUIVO)"
        Add-SecaoDeRemotoOrfa (Join-Path $princ '.git\config')

        $g = Get-CaminhosDoGit -Path $wt
        Assert-True ($g.Ligado) "PRE-CONDICAO: Get-CaminhosDoGit nao reconheceu o worktree como ligado"
        Assert-True (Test-Path (Join-Path $g.ComumDir 'config') -PathType Leaf) `
            "PRE-CONDICAO: nao ha config em ComumDir - a fixture nao monta o estado do caso"
        Assert-True (-not (Test-Path (Join-Path $g.GitDir 'config') -PathType Leaf)) `
            "PRE-CONDICAO: o worktree ganhou config PROPRIO. Com ele, GitDir tambem acharia um config e a escolha deixaria de discriminar - o caso passaria sem provar a diferenca"

        Assert-True (@(git -C $wt remote -v 2>$null).Count -eq 0) `
            "PRE-CONDICAO: 'remote -v' imprimiu algo dentro do worktree"
        $erro = ''
        try { $null = Get-AchadosExposicao -Path $wt -SemRede } catch { $erro = "$_" }
        Assert-True ($erro -match 'declara pelo menos um \[remote') `
            "dentro de worktree ligado o config mora no diretorio COMUM, nao no GitDir do worktree. Procurando no GitDir a guarda nao acha arquivo nenhum e fica INERTE em silencio - a unica guarda ALTA desta area. Erro recebido: '$erro'"
    } finally {
        git -C $princ worktree remove --force $wt 2>$null
        Remove-Item $wt -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $princ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "guarda de remoto: git responde por GIT_DIR e o '.git' local nao resolve - LANCA" {
    # O terceiro ramo, e o cenario nao e exotico: TODO hook do Git roda com
    # GIT_DIR no ambiente. Nesse estado o git responde sobre outro
    # repositorio enquanto a resolucao local de '.git' falha, e "nao consegui
    # localizar o repositorio" nunca pode virar "nao ha remoto".
    $outro = New-RepoComCommit
    $alvo = Join-Path $env:TEMP ("gd-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        New-Item -ItemType Directory -Path $alvo -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $alvo '.git'), "isto nao e um ponteiro de gitdir`n")
        Assert-True ($null -eq (Get-CaminhosDoGit -Path $alvo)) `
            "PRE-CONDICAO: a fixture nao produziu '.git' irresolvivel"
        $env:GIT_DIR = (Join-Path $outro '.git')
        try {
            Assert-True (@(git -C $alvo remote -v 2>$null).Count -eq 0) `
                "PRE-CONDICAO: 'remote -v' nao veio vazio sob GIT_DIR"
            $erro = ''
            try { $null = Get-AchadosExposicao -Path $alvo -SemRede } catch { $erro = "$_" }
            Assert-True ($erro -match 'nao foi possivel localizar') `
                "o git respondeu sobre OUTRO repositorio e a resolucao local falhou: isso e lacuna de leitura, nao 'repositorio sem remoto'. Erro recebido: '$erro'"
        } finally { Remove-Item Env:\GIT_DIR -ErrorAction SilentlyContinue }
    } finally {
        # Duas vezes de proposito: GIT_DIR vazando para os casos seguintes
        # faria o git responder sobre o repositorio errado em toda a suite.
        Remove-Item Env:\GIT_DIR -ErrorAction SilentlyContinue
        Remove-Item $alvo -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $outro -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "guarda de remoto: config ILEGIVEL como texto LANCA, em vez de decidir sobre lixo" {
    # O quarto ramo, criado ao fechar o item 11. Guarda nova sem par de
    # execucao e a divida que estes tres casos existem para pagar; nao se
    # abre outra no mesmo arquivo.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $cfg = Join-Path $fx '.git\config'
        [System.IO.File]::WriteAllBytes($cfg, ([System.IO.File]::ReadAllBytes($cfg) + [byte[]](0x23, 0x20, 0xE7, 0x0A)))
        Assert-True (@(git -C $fx remote -v 2>$null).Count -eq 0) `
            "PRE-CONDICAO: 'remote -v' nao veio vazio - o git recusou o config e o ramo nem e alcancado"
        $erro = ''
        try { $null = Get-AchadosExposicao -Path $fx -SemRede } catch { $erro = "$_" }
        Assert-True ($erro -match 'nao e legivel') `
            "o config nao decodifica como UTF-8: com leitura leniente o '[remote' nao casa e a guarda fica inerte pelo proprio motivo que ela cobre. Erro recebido: '$erro'"
    } finally { Remove-Fx $fx }
}


# =============================================================================
# SEGUNDA RODADA - o que os dois revisores acharam na primeira
# =============================================================================

Test-Caso "codificacao: BOM de UTF-8 NAO desarma a recusa de byte invalido" {
    # O defeito que o qa-reviewer derivou por leitura, e que estava vivo na
    # propria correcao do item 11: 'ReadAllText($caminho, $codificacao)' abre
    # um StreamReader com deteccao de preambulo, e com BOM reconhecido ele
    # DESCARTA a codificacao passada. Para o BOM de UTF-8 trocava pelo
    # 'Encoding.UTF8' estatico, que substitui em silencio - os MESMOS bytes
    # eram recusados sem BOM e aceitos com BOM.
    $d = Join-Path $env:TEMP ("enc-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $semBom = Join-Path $d 'sem-bom.md'
        $comBom = Join-Path $d 'com-bom.md'
        $corpo = [byte[]](0x61, 0xE7, 0x0A)
        [System.IO.File]::WriteAllBytes($semBom, $corpo)
        [System.IO.File]::WriteAllBytes($comBom, ([byte[]](0xEF, 0xBB, 0xBF) + $corpo))
        Assert-True ($null -eq (Read-TextoDeArquivo $semBom)) `
            "PRE-CONDICAO: os mesmos bytes SEM o BOM tinham de ser recusados"
        Assert-True ($null -eq (Read-TextoDeArquivo $comBom)) `
            "o BOM de UTF-8 desarmou a recusa: os mesmos bytes que sao recusados sem BOM passaram com BOM, com U+FFFD no lugar do byte invalido. E o falso verde do item 11 dentro da correcao do item 11"
    } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "codificacao: BOM de UTF-8 com conteudo VALIDO e lido, e o BOM nao entra no texto" {
    # O par positivo da correcao acima. Sem ele, um leitor que passasse a
    # recusar todo arquivo com BOM tambem passaria no caso anterior - e
    # arquivo com BOM de UTF-8 e o que o proprio PowerShell 5.1 grava com
    # 'Out-File -Encoding utf8'.
    $d = Join-Path $env:TEMP ("enc-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $p = Join-Path $d 'com-bom-ok.md'
        [System.IO.File]::WriteAllBytes($p, ([byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes('token: ' + $TOKEN_FALSO)))
        $t = Read-TextoDeArquivo $p
        Assert-True ($null -ne $t) "recusou arquivo UTF-8 valido so por ter BOM"
        Assert-True ($t.StartsWith('token:')) `
            "o BOM entrou no texto devolvido: um padrao ancorado em inicio de arquivo deixaria de casar. Primeiro char: $([int]$t[0])"
        Assert-True ($t -match ([regex]::Escape($TOKEN_FALSO))) "o conteudo nao sobreviveu a leitura"
    } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "codificacao: Measure-LinhasDoArquivo LANCA em arquivo ilegivel" {
    # Par de execucao da guarda nova. Carimbar linha contada sobre U+FFFD
    # seria um numero derivado de leitura corrompida, e o carimbo existe
    # justamente para o revisor conferir.
    $d = Join-Path $env:TEMP ("enc-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $ok = Join-Path $d 'ok.md'
        [System.IO.File]::WriteAllText($ok, "uma`nduas`n", (New-Object System.Text.UTF8Encoding($false)))
        Assert-True ((Measure-LinhasDoArquivo $ok) -eq 2) "o par positivo falhou: arquivo legivel tinha de contar 2 linhas"

        $ruim = Join-Path $d 'ruim.md'
        [System.IO.File]::WriteAllBytes($ruim, ([byte[]](0x61, 0xE7, 0x0A)))
        $erro = ''
        try { $null = Measure-LinhasDoArquivo $ruim } catch { $erro = "$_" }
        Assert-True ($erro -match 'nao e legivel como texto') `
            "arquivo ilegivel tinha de LANCAR em vez de devolver contagem. Erro recebido: '$erro'"
    } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "excecao: project.yaml ILEGIVEL LANCA e manda salvar em UTF-8" {
    # Par de execucao da outra guarda nova. Devolver lista vazia bloquearia
    # MAIS no veredito - e faria o relatorio afirmar que consultou as
    # excecoes. Mentir sobre cobertura e pior que parar: e a posicao do
    # security-reviewer, e ela e coerente com o 'exit 2' do ADR-0009.
    $d = Join-Path $env:TEMP ("exc-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $y = Join-Path $d 'project.yaml'
        [System.IO.File]::WriteAllText($y, "nome: teste`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Get-ExcecoesDeSeguranca -Path $d
        Assert-True ($r.Aceitas.Count -eq 0) "o par positivo falhou: manifesto legivel sem excecoes devia devolver lista vazia"

        [System.IO.File]::WriteAllBytes($y, ([byte[]](0x6E, 0x6F, 0x6D, 0x65, 0x3A, 0x20, 0xE7, 0x0A)))
        $erro = ''
        try { $null = Get-ExcecoesDeSeguranca -Path $d } catch { $erro = "$_" }
        Assert-True ($erro -match 'nao e legivel como texto') `
            "manifesto ilegivel tinha de LANCAR. Erro recebido: '$erro'"
        Assert-True ($erro -match 'UTF-8 e rode de novo') `
            "a mensagem nao diz o que fazer. Diagnostico sem acao deixa a mantenedora sem saida num projeto governado. Erro recebido: '$erro'"
    } finally { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "historico: U+FFFD LEGITIMO no blob e lido; byte INVALIDO e recusado (revisao r8, S6)" {
    # Antes: o detector recusava qualquer U+FFFD no texto que o console
    # devolvia. Um STATE.md que citava o caractere ficou ilegivel em todas as
    # versoes seguintes, e a area de historico nunca podia ser aprovada.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $ok = Join-Path $fx 'cita-fffd.md'
        $legit = ('o caractere ' + [string][char]0xFFFD + ' aparece aqui. token: ' + $TOKEN_FALSO + "`n")
        [System.IO.File]::WriteAllText($ok, $legit, (New-Object System.Text.UTF8Encoding($false)))
        $ruim = Join-Path $fx 'latin1.md'
        [System.IO.File]::WriteAllBytes($ruim, [byte[]](0x63, 0x61, 0xE7, 0xE3, 0x6F, 0x0A))
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            git -C $fx add -A 2>$null
            git -C $fx commit -q -m 'fffd legitimo e latin1' 2>$null
        } finally { $ErrorActionPreference = $anterior }

        $r = Get-AchadosHistorico -Path $fx
        $ileg = ($r.Cobertura.ListaBlobsIlegiveis -join ' ')
        Assert-True ($ileg -notmatch 'cita-fffd\.md') `
            "blob UTF-8 VALIDO com U+FFFD literal foi recusado como ilegivel: a recusa ainda olha o texto decodificado, nao os bytes"
        Assert-True ($ileg -match 'latin1\.md') `
            "blob com byte invalido para UTF-8 (Latin-1) nao foi recusado: o decodificador nao esta estrito"
        $detalhes = (@($r.Achados) | ForEach-Object { $_.Detalhe + ' ' + $_.Caminho }) -join ' '
        Assert-True ($detalhes -match 'cita-fffd\.md') `
            "o token plantado no blob com U+FFFD legitimo nao foi achado: o blob nao foi realmente lido"
    } finally { Remove-Fx $fx }
}

Test-Caso "historico: blob ILEGIVEL nao conta como lido, e sai nomeado" {
    # O achado do security-reviewer: a primeira passada da correcao converteu
    # os leitores POR CAMINHO e deixou o detector de historico, que le stdout
    # do git. O mesmo arquivo que o working tree recusava e nomeava era
    # contado como 'lido' aqui - duas areas relatando o oposto sobre os
    # mesmos bytes, com a tabela de teto afirmando completude.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $rOk = Get-AchadosHistorico -Path $fx
        Assert-True ($rOk.Cobertura.BlobsLidos -gt 0) "o par positivo falhou: blob de texto normal tinha de ser lido"
        Assert-True ($rOk.Cobertura.BlobsIlegiveis -eq 0) "acusou blob ilegivel num repositorio que so tem texto UTF-8"

        # UTF-16 sem BOM, commitado: o git devolve o conteudo, o decodificador
        # do console entrega o texto com NUL entre cada letra, e nenhum dos 8
        # padroes casa. Sem a recusa, isso entrava em BlobsLidos.
        $alvo = Join-Path $fx 'u16.md'
        [System.IO.File]::WriteAllBytes($alvo, [System.Text.Encoding]::Unicode.GetBytes('token: ' + $TOKEN_FALSO))
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            git -C $fx add -A 2>$null
            git -C $fx commit -q -m 'blob ilegivel' 2>$null
        } finally { $ErrorActionPreference = $anterior }

        $r = Get-AchadosHistorico -Path $fx
        Assert-True ($r.Cobertura.BlobsIlegiveis -gt 0) `
            "o blob em UTF-16 sem BOM foi contado como LIDO: o texto chega aos regex com um NUL entre cada letra, nenhum padrao casa, e a area sai declarando cobertura sobre o que nao varreu"
        Assert-True (($r.Cobertura.ListaBlobsIlegiveis -join ' ') -match 'u16\.md') `
            "a lacuna nao nomeia o caminho do blob - contagem sem identidade nao deixa ninguem conferir com 'git cat-file'"
    } finally { Remove-Fx $fx }
}

Test-Caso "exposicao: arquivo de CI ilegivel e contado UMA vez, nao duas" {
    # O conjunto de CI e subconjunto do de conteudo, entao o mesmo arquivo
    # passa pelos dois lacos. Contar nos dois faz a linha de cobertura dizer
    # '2' com UM arquivo na lista nomeada. Achado do qa-reviewer.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n"; '.github/workflows/ci.yml' = "name: ci`n" } })
    try {
        $alvo = Join-Path $fx '.github\workflows\ci.yml'
        [System.IO.File]::WriteAllBytes($alvo, ([byte[]](0x6E, 0x61, 0x6D, 0x65, 0x3A, 0x20, 0xE7, 0x0A)))
        $r = Get-AchadosExposicao -Path $fx -SemRede
        Assert-True ($r.Cobertura.NaoLidosPorCodificacao -eq 1) `
            "o arquivo de CI ilegivel foi contado $($r.Cobertura.NaoLidosPorCodificacao) vez(es); a lista nomeada tem um so, e numero de cobertura que nao reconcilia com a lista e a sobre-contagem que este arquivo ja corrigiu uma vez"
    } finally { Remove-Fx $fx }
}


Test-Caso "gitignore: arquivo de regra ILEGIVEL e contado, nomeado, e derruba a area" {
    # O unico leitor convertido que ficou sem par de execucao - mutar a linha
    # de volta para 'ReadAllLines' mantinha a suite inteira verde. Achado do
    # qa-reviewer, e ele nomeou o efeito: o arquivo que protege o segredo de
    # todo projeto governado deixa de ser lido, e a razao 'N de N regras' sai
    # como se valesse para a arvore inteira.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $gi = Join-Path $fx 'sub\.gitignore'
        New-Item -ItemType Directory -Path (Split-Path $gi -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($gi, "*.log`n", (New-Object System.Text.UTF8Encoding($false)))
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { git -C $fx add -A 2>$null; git -C $fx commit -q -m 'gitignore no sub' 2>$null }
        finally { $ErrorActionPreference = $anterior }

        # Par positivo: legivel, nada contado.
        $rOk = Get-AchadosGitignore -Path $fx
        Assert-True ($rOk.Cobertura.ArquivosDeRegraNaoLidos -eq 0) `
            "acusou arquivo de regra ilegivel num repositorio cujos .gitignore sao UTF-8 validos"

        # Par negativo: mesma regra, gravada com byte invalido.
        [System.IO.File]::WriteAllBytes($gi, ([byte[]](0x2A, 0x2E, 0x6C, 0xE7, 0x67, 0x0A)))
        $r = Get-AchadosGitignore -Path $fx
        Assert-True ($r.Cobertura.ArquivosDeRegraNaoLidos -eq 1) `
            "o .gitignore ilegivel nao foi contado: as regras dele nao entraram na conta e a razao 'N de N' sairia como se valesse para a arvore inteira"
        Assert-True (($r.Cobertura.ListaArquivosNaoLidos -join ' ') -match 'gitignore') `
            "a lacuna nao nomeia o arquivo de regra - contagem sem identidade nao deixa ninguem conferir no disco"

        # E o PORTAO no relatorio, que e outro consumidor do mesmo fato. O
        # contador subindo no detector nao prova que a coluna 'Coberta' cai:
        # sao dois portoes, e consertar um deixando o outro mentindo e a
        # classe de defeito que este arquivo ja registrou seis vezes.
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $rel = Get-Rel $fx
        Assert-True ($rel -match '\| gitignore \| \*\*parcial\*\* \|') `
            "a area gitignore foi declarada COBERTA com um arquivo de regra que a ferramenta nao conseguiu ler"
        Assert-True ($rel -match 'ilegiveis') `
            "a linha de lacuna nao menciona os arquivos de regra ilegiveis"
    } finally { Remove-Fx $fx }
}


Test-Caso "relatorio: com -SemHistorico o teto do blob diz 'nao se aplica', e nao que mediu" {
    # Tres estados, e o terceiro faltava: sem o detector de historico nada e
    # medido sobre decodificacao de blob, e a versao anterior caia na redacao
    # afirmativa - dizendo que a troca de codificacao foi aplicada numa
    # execucao em que ela nunca aconteceu. Achado do security-reviewer.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# nada`n" } })
    try {
        $null = Invoke-Scan $fx -Extra @('-SemRede', '-SemHistorico')
        $rel = Get-Rel $fx
        Assert-True ($rel -match 'nao se aplica.*historico NAO foi varrido') `
            "com -SemHistorico o teto do blob tem de dizer que nao se aplica, em vez de afirmar que mediu a decodificacao"
        Assert-True ($rel -notmatch 'aceitou a troca para UTF-8 nesta execucao') `
            "o relatorio afirmou ter aplicado a troca de codificacao numa execucao em que o detector de historico nem rodou"

        # O par: COM historico, a frase afirmativa volta.
        $null = Invoke-Scan $fx -Extra @('-SemRede')
        $relCom = Get-Rel $fx
        Assert-True ($relCom -match 'aceitou a troca para UTF-8 nesta execucao') `
            "com o historico varrido, o relatorio devia registrar que a troca de codificacao foi aceita"
    } finally { Remove-Fx $fx }
}

# =============================================================================
# ITEM 156 - nome de arquivo fora do ASCII
# =============================================================================
# Reproduzido antes da correcao: um repositorio com 'CAPAS/CAPA DOSSIE.docx'
# (E com circunflexo) fazia o scanner inteiro sair com 2 - "Caracteres
# invalidos no caminho". O 'git ls-files' sem '-z' devolvia o nome entre
# aspas com escape octal ("CAPAS/CAPA DOSSI\303\212.docx"), e o 'Join-Path'
# recusava as aspas. Um nome de arquivo derrubava a varredura do repositorio
# todo. Os nomes sao montados com [char] porque este .ps1 e ASCII de
# proposito (o 5.1 le UTF-8 sem BOM como ANSI).

$CHAR_E_CIRC  = [string][char]0x00CA   # E circunflexo
$CHAR_A_AGUDO = [string][char]0x00C1   # A agudo
$CHAR_C_CED   = [string][char]0x00C7   # C cedilha
$CHAR_I_AGUDO = [string][char]0x00ED   # i agudo

function Get-LinhasDeStatus {
    param([string]$Repo)
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { return ((@(git -C $Repo status --porcelain --untracked-files=all 2>$null)) -join "`n") }
    finally { $ErrorActionPreference = $anterior }
}

Test-Caso "nomes (item 156): acento e espaco no nome NAO abortam, e o segredo no arquivo acentuado e achado" {
    $docx = 'CAPAS/CAPA DOSSI' + $CHAR_E_CIRC + '.docx'
    $py   = 'CAPAS/config DOSSI' + $CHAR_E_CIRC + '.py'
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ $docx = "binario fingido`n"; $py = "TOKEN = '$TOKEN_FALSO'`n" } })
    try {
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        Assert-True ($r.Exit -ne 2) "o scanner ABORTOU com nome acentuado (exit 2) - o defeito do item 156. Saida: $($r.Saida)"
        Assert-True ($r.Exit -eq 1) "havia um token plantado e o scanner saiu com $($r.Exit)"
        $rel = Get-Rel $fx
        Assert-True ($null -ne $rel) "o scanner nao gravou relatorio"
        # O caminho tem de sair DECODIFICADO, com o acento, e nao citado.
        Assert-True ($rel.Contains('| possivel token do GitHub | `' + $py + ' linha ~1')) `
            "o token dentro do arquivo acentuado nao foi acusado com o nome real do arquivo"
        Assert-True ($rel.Contains('| documento operacional | `' + $docx + '`')) `
            "o .docx de nome acentuado nao foi acusado como documento operacional com o nome real"
        Assert-True ($rel -notmatch '\\303\\212') "o relatorio carrega o nome CITADO pelo git (escape octal)"
        # E o arquivo entrou no carimbo: foi LIDO, nao so listado.
        Assert-True ($rel.Contains('| `' + $py + '` |')) "o arquivo acentuado nao aparece no carimbo de integridade"
        # '-cnotmatch': a tabela de cobertura tem "0 rastreado(s) e ausente(s)
        # do disco" em minusculas, e o '-match' padrao nao distingue caixa.
        Assert-True ($rel -cnotmatch 'RASTREADO\(S\) e ausente\(s\) do disco') `
            "o arquivo acentuado virou 'ausente do disco': o nome devolvido pelo git nao bate com o do disco"
    } finally { Remove-Fx $fx }
}

Test-Caso "nomes (item 156): historico, nao rastreado e staging tambem enxergam o nome acentuado" {
    # As outras listagens de caminho do git: 'rev-list --objects' e
    # 'log --find-object --name-only' (historico), 'ls-files --others' (nao
    # rastreado) e 'diff --cached --name-only' (staging). Cada uma tinha o
    # mesmo defeito de citacao.
    $velho = 'velho ' + $CHAR_E_CIRC + '.py'
    $novo  = 'novo ' + $CHAR_C_CED + $CHAR_A_AGUDO + '.js'
    $pem   = 'chave ' + $CHAR_I_AGUDO + '.pem'
    $fx = New-RepoFx2 -Passos @(
        @{ Escreve = @{ $velho = "TOKEN = '$TOKEN_FALSO'`n"; 'base.md' = "# base`n" } },
        @{ Apaga = @($velho) }
    )
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx $novo), "const t = 'ghp_NAORASTREADOACENTO12345';`n", (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText((Join-Path $fx $pem), "conteudo`n", (New-Object System.Text.UTF8Encoding($false)))
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $fx add -- $pem 2>$null
        $ErrorActionPreference = $anterior

        $r = Invoke-Scan $fx -Extra @('-SemRede')
        Assert-True ($r.Exit -eq 1) "esperava exit 1, veio $($r.Exit). Saida: $($r.Saida)"
        $rel = Get-Rel $fx
        Assert-True ($rel.Contains('possivel token do GitHub no historico | `' + $velho)) `
            "o segredo do arquivo acentuado APAGADO nao foi acusado no historico com o nome real"
        Assert-True ($rel.Contains('`' + $novo + ' linha ~1 (1 ocorrencia(s)) [nao rastreado]`')) `
            "o arquivo NAO RASTREADO de nome acentuado nao foi examinado"
        Assert-True ($rel.Contains('| staging | arquivo sensivel na staging area | `' + $pem + '`')) `
            "o arquivo sensivel acentuado em staging nao foi acusado com o nome real"
    } finally { Remove-Fx $fx }
}

Test-Caso "nomes (item 156): ADVERSARIAL - alvo com espaco, aspa e acento; nome com aspa, colchete, NFC e NFD" {
    # O caminho do ALVO tambem e hostil: espaco (o 'Usuaria Exemplo' desta
    # maquina), aspa simples e acento. E dois arquivos cujos nomes sao o
    # MESMO texto em NFC (E-agudo pre-composto) e em NFD (E + acento
    # combinante): o NTFS guarda os dois como nomes distintos, e o segredo so
    # esta no NFD. Normalizar em qualquer ponto faria o achado cair no
    # arquivo errado - ou sumir.
    $baseLonga = (Get-Item -LiteralPath $env:TEMP).FullName
    $pasta = Join-Path $baseLonga ("sc 156 'x' " + $CHAR_A_AGUDO + "rea-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $hostil = 'd' + $CHAR_I_AGUDO + "r/arq '" + $CHAR_C_CED + "' [1].py"
    $nfc = 'forma-' + [string][char]0x00C9 + '.py'
    $nfd = 'forma-E' + [string][char]0x0301 + '.py'
    Assert-True (-not [string]::Equals($nfc, $nfd, [System.StringComparison]::Ordinal)) "a fixture NFC/NFD nao produziu nomes distintos"
    # Hashtable ORDINAL: a '@{}' do PowerShell compara chave por cultura e sem
    # caixa, e para ela NFC e NFD sao a MESMA chave - o literal nem compila.
    $escreve = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
    $escreve[$hostil] = "TOKEN = 'ghp_HOSTILFABRICADO1234567'`n"
    $escreve[$nfc]    = "x = 1`n"
    $escreve[$nfd]    = "TOKEN = 'ghp_NFDFABRICADO123456789'`n"
    $fx = New-RepoFx2 -Pasta $pasta -Gitignore ("/artifacts/*`n/sa" + $CHAR_I_AGUDO + "da/`n") -Passos @(@{ Escreve = $escreve })
    try {
        Assert-True (Test-Path -LiteralPath (Join-Path $fx $nfd)) "a fixture nao criou o arquivo NFD"
        Assert-True (Test-Path -LiteralPath (Join-Path $fx $nfc)) "a fixture nao criou o arquivo NFC"
        $antes = Get-LinhasDeStatus $fx
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        Assert-True ($r.Exit -eq 1) "esperava exit 1 (dois tokens plantados), veio $($r.Exit). Saida: $($r.Saida)"
        $rel = Get-Rel $fx
        Assert-True ($null -ne $rel) "o relatorio nao ficou em artifacts/ do alvo, que IGNORA artifacts/"
        Assert-True ($rel.Contains('| possivel token do GitHub | `' + $hostil + ' linha ~1')) `
            "o nome com aspa, colchete e acento nao foi acusado com o nome real"
        Assert-True ($rel.Contains('| possivel token do GitHub | `' + $nfd + ' linha ~1')) `
            "o token no arquivo NFD nao foi acusado com o nome NFD exato"
        Assert-True (-not $rel.Contains('| possivel token do GitHub | `' + $nfc + ' ')) `
            "o achado foi atribuido ao arquivo NFC, que nao tem token - nome normalizado em algum ponto"
        Assert-True ($rel -cnotmatch 'RASTREADO\(S\) e ausente\(s\) do disco') `
            "algum nome hostil virou 'ausente do disco': o nome do git nao bate com o do disco"
        # Os dois arquivos NFC/NFD foram LIDOS no working tree - nao so o
        # historico achou o token. Antes, 'Sort-Object -Unique' descartava um
        # deles como duplicata.
        Assert-True ($rel.Contains('| `' + $nfc + '` |') -and $rel.Contains('| `' + $nfd + '` |')) `
            "o carimbo nao tem os DOIS arquivos NFC e NFD: um foi descartado como duplicata do outro"
        # A regra de .gitignore com acento e SONDADA e provada: antes do '-z'
        # a sonda voltava citada, nao casava a chave, e a regra virava
        # 'nao verificavel'.
        Assert-True ($rel -notmatch 'que a sonda nao representa') `
            "a regra de .gitignore acentuada ficou 'nao verificavel'"
        Assert-True ($rel -match '\| gitignore \| [^|]*\| 2 de 2 regra\(s\) provadas EFETIVAS') `
            "as duas regras do .gitignore (uma acentuada) nao foram provadas efetivas"
        Assert-True ((Get-LinhasDeStatus $fx) -ceq $antes) "a varredura alterou o 'git status' do alvo"
    } finally { Remove-Fx $fx }
}

Test-Caso "nomes (item 156): Invoke-GitCaminhos RECUSA listagem sem '-z'" {
    # Esquecer o '-z' faria a lista voltar como um unico registro com quebras
    # de linha dentro, sem erro nenhum. A guarda torna o erro impossivel de
    # passar calado.
    $fx = New-RepoFx2 -Passos @(@{ Escreve = @{ 'a.md' = "# a`n" } })
    try {
        $msg = ''
        try { $null = Invoke-GitCaminhos @('-C', $fx, 'ls-files') } catch { $msg = $_.Exception.Message }
        Assert-True ($msg -match "Invoke-GitCaminhos sem '-z'") "a listagem sem '-z' nao foi recusada (mensagem: '$msg')"
        $lista = @(Invoke-GitCaminhos @('-C', $fx, 'ls-files', '-z'))
        Assert-True ($lista.Count -eq 2) "com '-z' a listagem devia ter 2 arquivos (.gitignore e a.md), veio $($lista.Count): $($lista -join ' | ')"
        Assert-True (($lista -ccontains 'a.md') -and ($lista -ccontains '.gitignore')) "a listagem com '-z' nao trouxe os nomes certos"
    } finally { Remove-Fx $fx }
}

Test-Caso "nomes (item 156): citacao de argumento para a linha de comando do Windows" {
    # O Invoke-GitUtf8 monta a linha de comando a mao (o ProcessStartInfo do
    # .NET Framework so aceita uma string). Errar aqui troca o caminho do
    # alvo por outro - e 'Usuaria Exemplo' tem espaco.
    $casos = @(
        @('simples', 'simples'),
        @('com espaco', '"com espaco"'),
        @('', '""'),
        @('C:\a b\', '"C:\a b\\"'),
        @('a"b', '"a\"b"'),
        @('a\"b', '"a\\\"b"'),
        @('C:\sem\espaco', 'C:\sem\espaco')
    )
    foreach ($c in $casos) {
        $obtido = ConvertTo-ArgumentoNativo $c[0]
        Assert-True ([string]::Equals($obtido, $c[1], [System.StringComparison]::Ordinal)) `
            ("citacao errada para [" + $c[0] + "]: esperado [" + $c[1] + "], veio [" + $obtido + "]")
    }
}

# =============================================================================
# ITEM 157 - o scanner nao pode sujar o repositorio que ele so devia LER
# =============================================================================
# Reproduzido antes da correcao: num repositorio sem 'artifacts/' no
# .gitignore, a varredura gravava 'artifacts/review/security-report.md' la
# dentro e o 'git status' do alvo passava a mostrar 'artifacts/' nao rastreado. Varrer
# o repositorio de outra pessoa deixava WIP no repositorio dela.

function Get-DestinoImpresso {
    param([string]$Saida)
    $m = [regex]::Match($Saida, 'Relatorio: (.+?security-report\.md)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

Test-Caso "destino (item 157): alvo SEM .gitignore - o 'git status' do alvo fica identico e o relatorio vai para fora" {
    $fx = New-RepoFx2 -Gitignore $null -Passos @(@{ Escreve = @{ 'README.md' = "# terceiro`n" } })
    $destino = $null
    try {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $fx '.gitignore'))) "a fixture nao devia ter .gitignore"
        $antes = Get-LinhasDeStatus $fx
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        Assert-True ($r.Exit -ne 2) "a varredura nao aconteceu (exit 2). Saida: $($r.Saida)"
        $depois = Get-LinhasDeStatus $fx
        Assert-True ($depois -ceq $antes) "o scanner SUJOU o alvo. Antes: [$antes] Depois: [$depois]"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $fx 'artifacts'))) "o scanner criou 'artifacts/' dentro do alvo"
        $destino = Get-DestinoImpresso $r.Saida
        Assert-True ($null -ne $destino) "o scanner nao imprimiu onde gravou o relatorio. Saida: $($r.Saida)"
        Assert-True ($destino -match '\\emmily-os-scan\\') "o destino impresso nao e o diretorio de varredura fora do repo: $destino"
        Assert-True (-not $destino.StartsWith($fx, [System.StringComparison]::OrdinalIgnoreCase)) "o destino impresso esta DENTRO do alvo: $destino"
        Assert-True (Test-Path -LiteralPath $destino -PathType Leaf) "o relatorio nao existe no caminho impresso: $destino"
        Assert-True ($r.Saida -match "NAO esta ignorado") "o console nao explicou POR QUE o relatorio foi para fora"
        $rel = Get-Texto $destino
        # O proprio relatorio diz o que aconteceu: quem le o arquivo depois
        # nao viu o console.
        Assert-True ($rel -match 'NAO esta ignorado\*\* no repositorio-alvo') "o relatorio nao registra que artifacts/ nao e ignorado no alvo"
        Assert-True ($rel -match 'FORA do repositorio-alvo') "o relatorio nao declara que foi gravado fora do alvo"
        Assert-True ($rel -notmatch 'destino do relatorio nao ignorado') `
            "o achado MEDIA de destino nao ignorado saiu, mas o relatorio NAO foi gravado no alvo"
    } finally {
        Remove-Fx $fx
        if ($destino) { Remove-Fx (Split-Path -Parent $destino) }
    }
}

Test-Caso "destino (item 157): alvo que IGNORA artifacts/ mantem o relatorio no lugar de sempre" {
    # O par negativo, e e o caso da propria plataforma: o comportamento
    # antigo continua onde ele nao sujava nada.
    $fx = New-RepoFx2 -Gitignore "/artifacts/`n" -Passos @(@{ Escreve = @{ 'README.md' = "# governado`n" } })
    try {
        $antes = Get-LinhasDeStatus $fx
        $r = Invoke-Scan $fx -Extra @('-SemRede')
        Assert-True ($r.Exit -ne 2) "a varredura nao aconteceu (exit 2). Saida: $($r.Saida)"
        $esperado = Join-Path $fx 'artifacts\review\security-report.md'
        Assert-True (Test-Path -LiteralPath $esperado -PathType Leaf) "o relatorio nao ficou em artifacts/review/ do alvo"
        $destino = Get-DestinoImpresso $r.Saida
        Assert-True ($destino -eq $esperado) "o destino impresso devia ser o de sempre ($esperado), veio $destino"
        Assert-True ($r.Saida -notmatch 'emmily-os-scan') "redirecionou para fora um alvo que ignora artifacts/"
        Assert-True ((Get-LinhasDeStatus $fx) -ceq $antes) "o relatorio dentro de artifacts/ ignorado mudou o 'git status' do alvo"
        Assert-True ((Get-Rel $fx) -notmatch 'destino do relatorio nao ignorado') "acusou destino nao ignorado num alvo que ignora artifacts/"
    } finally { Remove-Fx $fx }
}

Test-Caso "destino (item 157): -Out EXPLICITO dentro do alvo e respeitado, e o MEDIA de destino continua valendo" {
    # Quem pede o destino decide. O redirecionamento e so para o DEFAULT; com
    # '-Out' explicito num lugar nao ignorado, o achado MEDIA continua sendo
    # a forma de avisar que aquele relatorio pode acabar versionado.
    $fx = New-RepoFx2 -Gitignore $null -Passos @(@{ Escreve = @{ 'README.md' = "# terceiro`n" } })
    try {
        $dentro = Join-Path $fx 'artifacts\review\security-report.md'
        $r = Invoke-Scan $fx -Extra @('-SemRede', '-Out', $dentro)
        Assert-True ($r.Exit -ne 2) "a varredura nao aconteceu (exit 2). Saida: $($r.Saida)"
        Assert-True (Test-Path -LiteralPath $dentro -PathType Leaf) "o -Out explicito nao foi respeitado"
        Assert-True ($r.Saida -notmatch 'emmily-os-scan') "redirecionou um -Out explicito"
        Assert-True ((Get-Texto $dentro) -match 'destino do relatorio nao ignorado') "o MEDIA de destino nao ignorado sumiu com -Out explicito"
    } finally { Remove-Fx $fx }
}
