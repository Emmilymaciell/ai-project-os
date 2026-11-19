<#
.SYNOPSIS
    Suite dos hooks de Git: o que eles barram, e o que eles NAO barram.

.DESCRIPTION
    Duas camadas, como as outras suites desta plataforma:

      UNITARIA  - 'Test-MensagemDeCommit', 'Get-EstadoDosHooks' e
                  'Get-AchadosBloqueantesDoRelatorio' chamadas direto. A
                  decisao inteira do commit-msg e funcao pura sobre texto
                  justamente para caber aqui, sem commit de verdade.
      FUNCIONAL - 'git commit' e 'git push' DE VERDADE contra repositorio
                  descartavel em $env:TEMP, com os shims reais disparando.

    O par negativo e obrigatorio em todo caso de bloqueio: uma regra que
    reprova tudo passaria em qualquer teste que so mostrasse a reprovacao. Foi
    o padrao que custou cinco casos vacuos na subfase 2.3.

    O caso que da razao de ser a esta suite esta nomeado: a mensagem EXATA que
    criou o commit 'f6e3d5b' em 2026-09-22 - assunto que engoliu o primeiro
    paragrafo do corpo - e reprovada, e a versao corrigida passa.

    Nada e escrito fora de $env:TEMP.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite hooks"
}

$LibDir      = Join-Path $OsRoot 'scripts\lib'
$GithooksDir = Join-Path $OsRoot 'githooks'
$Instalador  = Join-Path $OsRoot 'scripts\install-hooks.ps1'
$Doctor      = Join-Path $OsRoot 'scripts\doctor.ps1'

foreach ($m in @('scan-comum.ps1', 'doctor-comum.ps1', 'doctor-manifesto.ps1',
                 'doctor-retomabilidade.ps1', 'doctor-git.ps1', 'doctor-ambiente.ps1',
                 'doctor-frescor.ps1', 'hooks-comum.ps1', 'doctor-hooks.ps1')) {
    . (Join-Path $LibDir $m)
}

# =============================================================================
# FIXTURES
# =============================================================================

function New-RepoHooks {
    <#
      Repositorio descartavel.
        -ComGithooks         copia githooks/ para dentro (testes do instalador)
        -LigadoNaPlataforma  aponta core.hooksPath para o githooks/ DA
                             PLATAFORMA, em caminho absoluto. E assim que os
                             testes funcionais disparam os shims REAIS: o shim
                             resolve '../scripts/' a partir de si mesmo, entao
                             ele acha o codigo de verdade enquanto o
                             diretorio corrente - e o repositorio diagnosticado
                             - e a fixture.
    #>
    param(
        [switch]$ComGithooks,
        [switch]$LigadoNaPlataforma,
        [switch]$ComEspaco,
        [string]$Manifesto
    )
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $pasta = "hk-" + [guid]::NewGuid().ToString('N').Substring(0, 10)
        # -ComEspaco poe um ESPACO no caminho, que e o cenario real do OneDrive
        # corporativo. Ele existe porque o qa-reviewer marcou portabilidade
        # INCONCLUSIVO: eu afirmava ter medido por sonda, e a sonda vivia fora
        # da suite - entao a afirmacao nao tinha lastro na evidencia dele.
        if ($ComEspaco) { $pasta = "hk com espaco " + [guid]::NewGuid().ToString('N').Substring(0, 8) }
        $t = Join-Path $env:TEMP $pasta
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q 2>$null
        # O init tem de ter funcionado ANTES de qualquer 'add': sem isto, um
        # init falho faria o 'add -A' subir procurando repositorio ancestral.
        # E o item 89 do backlog, aberto pelo security-reviewer na 2.5.
        if (-not (Test-Path (Join-Path $t '.git'))) { throw "git init falhou em '$t'" }
        git -C $t config user.name  'Fixture'    2>$null
        git -C $t config user.email 'fx@invalid' 2>$null
        git -C $t config core.autocrlf false     2>$null
        git -C $t config core.safecrlf false     2>$null

        # Sem isto o proprio scanner acusa MEDIA por o destino do relatorio
        # nao estar ignorado - achado legitimo, que atrapalharia medir outra
        # coisa. O template ja entrega este .gitignore.
        [System.IO.File]::WriteAllText((Join-Path $t '.gitignore'), "/artifacts/`n", (New-Object System.Text.UTF8Encoding($false)))

        if ($Manifesto) {
            [System.IO.File]::WriteAllText((Join-Path $t 'project.yaml'), $Manifesto, (New-Object System.Text.UTF8Encoding($false)))
        }
        if ($ComGithooks) {
            Copy-Item $GithooksDir (Join-Path $t 'githooks') -Recurse -Force
        }
        if ($LigadoNaPlataforma) {
            git -C $t config core.hooksPath $GithooksDir 2>$null
        }
        return $t
    } finally { $ErrorActionPreference = $anterior }
}

function Remove-RepoHooks {
    param([string]$Caminho)
    if ($Caminho -and (Test-Path $Caminho)) { Remove-Item $Caminho -Recurse -Force -ErrorAction SilentlyContinue }
}

function Invoke-CommitComMensagem {
    # Commit de verdade, com a mensagem num arquivo - e nao em '-m' - para que
    # a linha em branco separadora sobreviva a passagem pelo shell.
    param([string]$Repo, [string]$Mensagem)
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $f = Join-Path $env:TEMP ("msg-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + ".txt")
        [System.IO.File]::WriteAllText($f, $Mensagem, (New-Object System.Text.UTF8Encoding($false)))
        Push-Location $Repo
        $saida = (git commit -F $f 2>&1 | Out-String)
        $codigo = $LASTEXITCODE
        Pop-Location
        Remove-Item $f -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Saida = $saida; Exit = $codigo }
    } finally { $ErrorActionPreference = $anterior }
}

function Get-QuantosCommits {
    param([string]$Repo)
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $n = (git -C $Repo rev-list --count HEAD 2>$null)
        if ($LASTEXITCODE -ne 0) { return 0 }
        return [int]("" + $n).Trim()
    } finally { $ErrorActionPreference = $anterior }
}

function Add-ArquivoEStage {
    param([string]$Repo, [string]$Nome = 'a.txt', [string]$Conteudo = "conteudo`n")
    [System.IO.File]::WriteAllText((Join-Path $Repo $Nome), $Conteudo, (New-Object System.Text.UTF8Encoding($false)))
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { git -C $Repo add -A 2>$null } finally { $ErrorActionPreference = $anterior }
}

function Test-LinhaInvocaPowershell {
    <#
      A linha invoca 'powershell' como processo filho?

      Isto era um array de regex DENTRO do caso estrutural, e por isso a
      largura dele nao era medida por nada: estreita-la de volta para so a
      forma com '&' nao derrubava caso nenhum, porque NENHUM script do
      repositorio usa as outras formas. O guarda prometia cobrir quatro
      grafias e so uma tinha exemplo.

      Virou funcao para ter par proprio - o caso logo abaixo alimenta as
      quatro grafias e as negativas, sem precisar plantar chamada ruim em
      script de producao.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Linha)

    if ($Linha -match '^\s*#') { return $false }
    foreach ($f in @(
        '&\s*[''"]?powershell(\.exe)?[''"]?',   # & powershell | & 'powershell.exe'
        '(^\s*|[=(|&;]\s*)powershell(\.exe)?\s+-',  # powershell -... | $x = powershell -... | (powershell -...)
        'Start-Process[^#]*powershell',       # Start-Process powershell | -FilePath powershell
        '&\s*["''][^"'']*powershell(\.exe)?["'']'  # & "$env:windir\...\powershell.exe"
    )) {
        if ($Linha -match $f) { return $true }
    }
    return $false
}

function Invoke-Instalador {
    param([string]$Repo, [string[]]$Extra = @())
    $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Instalador, '-Path', $Repo) + $Extra
    $saida = (& powershell @argumentos 2>&1 | Out-String)
    return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
}

# A mensagem REAL do defeito de 2026-09-22, e a correcao dela. As duas ficam
# aqui em cima, uma ao lado da outra, porque a diferenca entre elas e UMA linha
# em branco - e e essa diferenca que esta suite existe para pinar.
$MSG_DEFEITUOSA = @"
feat(2.5): fecha o /os:doctor, o diagnostico de continuidade
Subfase 2.5 concluida apos dezenove rodadas de revisao independente em
contexto isolado. tests responde se o comportamento funciona; /os:security
responde se ha risco.
"@

$MSG_CORRIGIDA = @"
feat(2.5): fecha o /os:doctor, o diagnostico de continuidade

Subfase 2.5 concluida apos dezenove rodadas de revisao independente em
contexto isolado. tests responde se o comportamento funciona; /os:security
responde se ha risco.
"@

# =============================================================================
# UNITARIO - as regras do commit-msg
# =============================================================================

Test-Caso "commit-msg: a mensagem REAL que quebrou o commit da 2.5 e reprovada" {
    $r = Test-MensagemDeCommit -Texto $MSG_DEFEITUOSA
    Assert-True (-not $r.Ok) "a mensagem defeituosa passou"
    # E pela regra CERTA: nao basta reprovar, tem de reprovar pelo motivo que
    # descreve o defeito. Reprovar por outro motivo esconderia o buraco.
    $porLinha2 = @($r.Problemas | Where-Object { $_ -match 'linha 2' })
    Assert-True (@($porLinha2).Count -eq 1) ("esperava a reprovacao pela linha 2; vieram: " + ($r.Problemas -join ' | '))
}

Test-Caso "commit-msg: a mensagem CORRIGIDA passa - par negativo da regra" {
    $r = Test-MensagemDeCommit -Texto $MSG_CORRIGIDA
    Assert-True ($r.Ok) ("a mensagem correta foi reprovada: " + ($r.Problemas -join ' | '))
}

Test-Caso "commit-msg: assunto sozinho, sem corpo, passa" {
    $r = Test-MensagemDeCommit -Texto "fix: corrige o leitor de manifesto"
    Assert-True ($r.Ok) ("reprovou assunto sozinho: " + ($r.Problemas -join ' | '))
}

Test-Caso "commit-msg: mensagem vazia e reprovada" {
    $r = Test-MensagemDeCommit -Texto "   `n`n  `n"
    Assert-True (-not $r.Ok) "mensagem vazia passou"
    Assert-True (@($r.Problemas | Where-Object { $_ -match 'vazia' }).Count -eq 1) "nao acusou vazia"
}

Test-Caso "commit-msg: mensagem so de comentarios do git conta como vazia" {
    $texto = "# Please enter the commit message`n# Lines starting with '#' will be ignored`n"
    $r = Test-MensagemDeCommit -Texto $texto
    Assert-True (-not $r.Ok) "mensagem so de comentario passou"
}

Test-Caso "commit-msg: comentario do git na linha 2 NAO conta como corpo colado" {
    # O git sempre injeta comentarios depois do assunto. Se eles contassem
    # como corpo, o hook reprovaria TODO commit feito pelo editor - e a
    # primeira coisa que alguem faria e desinstalar o hook.
    $texto = "feat: algo`n# Please enter the commit message for your changes.`n"
    $r = Test-MensagemDeCommit -Texto $texto
    Assert-True ($r.Ok) ("reprovou por causa de comentario do proprio git: " + ($r.Problemas -join ' | '))
}

Test-Caso "commit-msg: a tesoura do --verbose corta o diff, que nao vira corpo" {
    $texto = "feat: algo`n# ------------------------ >8 ------------------------`ndiff --git a/x b/x`n+linha`n"
    $r = Test-MensagemDeCommit -Texto $texto
    Assert-True ($r.Ok) ("o diff do --verbose foi lido como corpo: " + ($r.Problemas -join ' | '))
}

Test-Caso "commit-msg: sem a tesoura, a MESMA linha 2 reprova - o corte e o que muda" {
    # Par do caso acima. Sem ele, um bug que descartasse tudo depois da linha
    # 1 passaria nos dois, e o teste da tesoura nao mediria a tesoura.
    $texto = "feat: algo`ndiff --git a/x b/x`n+linha`n"
    $r = Test-MensagemDeCommit -Texto $texto
    Assert-True (-not $r.Ok) "a linha 2 colada passou quando nao havia tesoura"
}

Test-Caso "commit-msg: fixup! e squash! sao isentos - o Git precisa deles assim" {
    foreach ($p in @('fixup! feat: algo', 'squash! feat: algo', 'amend! feat: algo')) {
        $r = Test-MensagemDeCommit -Texto $p
        Assert-True ($r.Ok -and $r.Isento) "reprovou '$p', que o rebase --autosquash exige numa linha"
    }
}

Test-Caso "commit-msg: o limite do assunto e conferido nas DUAS bordas" {
    $limite = 100
    $no = 'x' * $limite
    $r1 = Test-MensagemDeCommit -Texto $no
    Assert-True ($r1.Ok) "reprovou assunto de exatamente $limite caracteres"

    $passou = 'x' * ($limite + 1)
    $r2 = Test-MensagemDeCommit -Texto $passou
    Assert-True (-not $r2.Ok) "aceitou assunto de $($limite + 1) caracteres"
    Assert-True (@($r2.Problemas | Where-Object { $_ -match 'caracteres e o limite' }).Count -eq 1) `
        ("reprovou por outro motivo: " + ($r2.Problemas -join ' | '))
}

Test-Caso "commit-msg: CRLF nao muda o veredito" {
    $r1 = Test-MensagemDeCommit -Texto "feat: algo`r`n`r`ncorpo"
    Assert-True ($r1.Ok) "CRLF fez a mensagem correta reprovar"
    $r2 = Test-MensagemDeCommit -Texto "feat: algo`r`ncorpo"
    Assert-True (-not $r2.Ok) "CRLF fez a mensagem defeituosa passar"
}

Test-Caso "commit-msg: core.commentChar diferente de '#' e respeitado" {
    $texto = "feat: algo`n; comentario com outro caractere`n"
    $r = Test-MensagemDeCommit -Texto $texto -CaractereDeComentario ';'
    Assert-True ($r.Ok) ("nao respeitou o commentChar declarado: " + ($r.Problemas -join ' | '))
    # Par: com o padrao '#', a mesma linha e corpo colado e reprova.
    $r2 = Test-MensagemDeCommit -Texto $texto
    Assert-True (-not $r2.Ok) "tratou ';' como comentario mesmo com commentChar '#'"
}

# =============================================================================
# UNITARIO - o estado dos hooks
# =============================================================================

Test-Caso "estado: repositorio sem core.hooksPath e 'ausente', e NAO indeterminado" {
    $fx = New-RepoHooks
    try {
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True (-not $e.Indeterminado) "declarou indeterminado o que e fato determinado: $($e.Motivo)"
        Assert-True ($e.Aponta -eq 'ausente') "Aponta veio '$($e.Aponta)'"
        Assert-True (-not $e.Instalado) "declarou instalado sem core.hooksPath"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "estado: core.hooksPath apontando para OUTRO lugar nao e 'instalado'" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx config core.hooksPath '.git/hooks' 2>$null
        $ErrorActionPreference = $ea
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True ($e.Aponta -eq 'outro-lugar') "Aponta veio '$($e.Aponta)'"
        Assert-True (-not $e.Instalado) "declarou instalado apontando para outro lugar"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "estado: caminho ABSOLUTO para a pasta certa e reconhecido como certo" {
    # Comparar string crua diria 'outro-lugar' para 'C:\...\githooks' contra
    # 'githooks'. Sao o mesmo destino, e um instalador que reinstalasse aqui
    # deixaria de ser idempotente.
    $fx = New-RepoHooks -ComGithooks
    try {
        $abs = Join-Path $fx 'githooks'
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx config core.hooksPath $abs 2>$null
        $ErrorActionPreference = $ea
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True ($e.Aponta -eq 'certo') "Aponta veio '$($e.Aponta)' para o caminho absoluto da propria pasta"
        Assert-True ($e.Instalado) "nao reconheceu como instalado: $($e.Motivo)"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "estado: shim AUSENTE e shim DESATUALIZADO sao fatos diferentes" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx config core.hooksPath 'githooks' 2>$null
        $ErrorActionPreference = $ea

        Remove-Item (Join-Path $fx 'githooks\pre-push') -Force
        # Marca de versao trocada: o arquivo existe e NAO e o que o codigo espera.
        $p = Join-Path $fx 'githooks\pre-commit'
        $txt = Get-Texto $p
        [System.IO.File]::WriteAllText($p, $txt.Replace((Get-MarcaDeVersaoDeHook), '# os-hooks-versao: 0'), (New-Object System.Text.UTF8Encoding($false)))

        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True (-not $e.Instalado) "declarou instalado com um shim fora e outro velho"
        Assert-True ($e.Ausentes -contains 'pre-push') "nao acusou 'pre-push' como ausente"
        Assert-True ($e.Desatualizados -contains 'pre-commit') "nao acusou 'pre-commit' como desatualizado"
        Assert-True ($e.Presentes -contains 'commit-msg') "nao reconheceu 'commit-msg' como em dia"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "estado: raiz inexistente e INDETERMINADO, nunca 'nao instalado'" {
    $e = Get-EstadoDosHooks -Raiz (Join-Path $env:TEMP ('nao-existe-' + [guid]::NewGuid().ToString('N')))
    Assert-True ($e.Indeterminado) "transformou falha de leitura em fato sobre o repositorio"
    Assert-True (-not $e.Instalado) "declarou instalado sem conseguir olhar"
}

Test-Caso "achados: a extracao le '## Achados' e NAO a secao de excecoes" {
    # Despejar a secao de excecao na mensagem do hook acusaria como causa do
    # barramento justamente o que foi aceito de proposito (ADR-0010).
    $f = Join-Path $env:TEMP ("rel-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + ".md")
    $conteudo = @"
# Relatorio

## Achados

| Severidade | Area | Categoria | Detalhe |
|---|---|---|---|
| ALTA | working tree | token | ``x.txt`` |

## Achados ACEITOS POR EXCECAO (nao bloqueiam)

| MEDIA | dado de terceiro | e-mail | ``y.md`` |
"@
    [System.IO.File]::WriteAllText($f, $conteudo, (New-Object System.Text.UTF8Encoding($false)))
    try {
        $a = @(Get-AchadosBloqueantesDoRelatorio -Caminho $f)
        Assert-True (@($a).Count -eq 1) ("esperava 1 achado bloqueante, vieram $(@($a).Count): " + ($a -join ' | '))
        Assert-True ($a[0] -match 'ALTA') "trouxe a linha errada: $($a[0])"
    } finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

Test-Caso "filho: stderr do processo filho NAO derruba quem chama, e o codigo chega inteiro" {
    # Unitario da funcao que fechou o segundo bloqueante da rodada 2. O caso
    # funcional dela existe no pre-push, mas o MESMO defeito estava no
    # pre-commit, onde o filho e o scanner - e nao da para fazer o scanner
    # escrever em stderr numa fixture sem adulterar o scanner.
    #
    # Entao o fato e medido aqui, onde ele mora: sob '$ErrorActionPreference =
    # Stop' - que e o modo dos dois hooks -, a funcao nao pode lancar e tem de
    # devolver o codigo do filho.
    $s = Join-Path $env:TEMP ("fh-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + ".ps1")
    try {
        [System.IO.File]::WriteAllText($s, "[Console]::Error.WriteLine('aviso')`nexit 3`n", (New-Object System.Text.UTF8Encoding($false)))

        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
        try {
            $r = Invoke-FilhoDoHook -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $s)
            Assert-True ($r.Exit -eq 3) "o codigo do filho nao chegou inteiro: veio $($r.Exit)"
        } catch {
            Assert-True $false "a funcao LANCOU com stderr do filho sob 'Stop': $($_.Exception.Message)"
        } finally { $ErrorActionPreference = $anterior }

        # NAO ha assercao sobre "a funcao restaurou a preferencia de quem
        # chamou", e a ausencia e deliberada. Duas tentativas de escreve-la
        # morreram, e a segunda ensinou o porque: MEDIDO que atribuir
        # '$ErrorActionPreference' dentro de uma funcao e de ESCOPO DA FUNCAO -
        # mesmo com um 'finally' atribuindo o valor errado, quem chamou
        # continua com o seu. A mutacao que troca o restauro e EQUIVALENTE:
        # nao muda comportamento observavel, e por isso sobrevive por direito,
        # nao por buraco de teste.
        #
        # Uma assercao que a linguagem ja garante nunca falha. Ela pareceria
        # rigor e nao mediria nada, que e a classe que esta subfase perseguiu a
        # rodada inteira.
    } finally { Remove-Item $s -Force -ErrorAction SilentlyContinue }
}

Test-Caso "filho: a deteccao reconhece as grafias LITERAIS, e ignora comentario" {
    # A largura da deteccao nao era medida por nada: estreita-la de volta para
    # so a forma com '&' sobrevivia a suite inteira, porque nenhum script usa
    # as outras grafias. O guarda prometia quatro e so uma tinha exemplo -
    # achado do qa-reviewer, confirmado por mutacao sobrevivente.
    #
    # As amostras vivem AQUI, e nao plantadas num script de producao: plantar
    # chamada ruim para o guarda achar e exatamente o que ele existe para
    # impedir.
    #
    # O QUE ESTE GUARDA NAO ALCANCA, e esta no titulo e no item 115:
    #
    #   & $exe -File $x 2>&1      com $exe = 'powershell'
    #   & (Join-Path $PSHOME 'powershell.exe') -File $x
    #
    # O nome nao aparece na linha, entao NENHUMA regex o acha. E a mesma
    # forma da porta legitima em bootstrap.ps1 ('& $Comando @Argumentos'),
    # o que torna impossivel distinguir uma da outra por texto. O guarda
    # cobre as grafias LITERAIS; o resto depende de revisao humana, e esta
    # declarado em vez de prometido - e o item 115 do backlog. (O item 114 e
    # outro: ficou so com 'Start-Process', cujo risco e menor porque sem
    # redirecionamento ele nao traz o stderr do filho.)
    #
    # E as negativas medem COMENTARIO, nao 'texto': uma string com o nome
    # dentro ('Write-Host "rode: Start-Process powershell"') CASA, e isso e
    # fail-closed de proposito - acusar demais custa uma revisao, acusar de
    # menos custa o defeito.
    $invocam = @(
        '    $x = & powershell -NoProfile -File $s',
        "    & 'powershell.exe' -NoProfile -Command $c",
        '    & "powershell" -File $p',
        '    powershell -NoProfile -ExecutionPolicy Bypass -File $s',
        '    powershell.exe -Command $c',
        '    Start-Process powershell -ArgumentList $a',
        "    Start-Process 'powershell.exe' -Wait",
        # SEM '&' e COM atribuicao - a forma que o qa-reviewer mostrou que
        # escapava, porque a regex estava ancorada em inicio de linha. E a
        # forma habitual neste repositorio: as chamadas reais atribuem.
        '    $saida = powershell -NoProfile -File $s 2>&1',
        '    $r = (powershell -Command $c)',
        '    $t = $algo | powershell -Command -',
        # Formas que escapavam da versao anterior: o nome nao vem logo depois
        # do comando, ou vem dentro de um caminho montado por variavel.
        # Achado do qa-reviewer na quinta rodada.
        '    Start-Process -FilePath powershell -ArgumentList $a',
        '    & "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -File $s',
        "    & '$PSHOME\powershell.exe' -Command $c"
    )
    foreach ($l in $invocam) {
        Assert-True (Test-LinhaInvocaPowershell $l) "nao reconheceu como invocacao: $l"
    }

    # Negativas: COMENTARIO e nome dentro de outra palavra. String com o
    # nome e uma invocacao plausivel casam de proposito - ver o bloco acima.
    $naoInvocam = @(
        '    # & powershell -NoProfile - exemplo em comentario',
        '        # powershell -Command algo, so documentando',
        '    $msg = "sem powershell aqui"',
        '    $caminho = "C:\Windows\System32\WindowsPowerShell"'
    )
    foreach ($l in $naoInvocam) {
        Assert-True (-not (Test-LinhaInvocaPowershell $l)) "reconheceu como invocacao o que nao e: $l"
    }
}

Test-Caso "filho: NENHUM script de scripts/ invoca 'powershell' direto - todos passam por uma porta" {
    # DUAS vezes este caso foi mais estreito que o proprio titulo, e as duas o
    # qa-reviewer mostrou:
    #
    #   1. ele varria so os tres 'hook-*.ps1'. O MESMO defeito do stderr estava
    #      em 'scripts/bootstrap.ps1', escrito nesta mesma subfase - e o
    #      arquivo ja declarava, na linha 75, que "TODAS as chamadas abaixo
    #      passam por Invoke-NativoLocal". A afirmacao era mais larga que o
    #      codigo, dentro do arquivo que a fazia;
    #   2. a regex pegava so a forma com '&'. 'powershell -NoProfile ...' sem
    #      '&', "& 'powershell.exe'" e 'Start-Process powershell' passavam
    #      verdes, e as tres sao chamada direta.
    #
    # Agora varre scripts/ inteiro e as quatro formas. As portas legitimas sao
    # 'Invoke-FilhoDoHook' (hooks) e 'Invoke-NativoLocal' (bootstrap): as duas
    # baixam a preferencia em volta da chamada, que e o unico jeito de o stderr
    # do filho nao virar ErrorRecord terminante no PowerShell 5.1.
    # UMA excecao, NOMEADA, com prazo por EVENTO, e nao uma lista anonima que cresce.
    # 'collect-diff.ps1' tem o mesmo padrao, e ele e ANTERIOR a esta subfase: o
    # qa-reviewer o apontou como observacao e disse, com todas as letras, que
    # NAO e achado desta delta. Consertar tudo o que este guarda novo alcanca
    # estenderia o escopo para alem do bloqueante, que e o oposto da disciplina
    # desta casa.
    #
    # A excecao existe com prazo: ela sai quando o item 110 do backlog fechar.
    # La esta o estrago - uma suite que PASSA e escreve em stderr e registrada
    # pelo coletor como "falhou ao ser executado", com exit -1, bem na
    # ferramenta que produz a evidencia da revisao.
    # LISTA FECHADA, por arquivo + CONTEUDO EXATO da linha, com CONTAGEM.
    #
    # Esta e a terceira forma deste guarda, e as duas primeiras cairam pela
    # mesma razao - permissao que se autodeclara:
    #
    #   1. isencao por ARQUIVO: uma chamada direta NOVA no arquivo isento
    #      passava calada. Era o defeito da rodada 3, no mesmo arquivo;
    #   2. marcador em comentario: bastava COPIAR a linha com o comentario
    #      junto - que e o que alguem faz, copiando a unica chamada que
    #      funciona no repositorio - e o guarda ficava verde;
    #   3. desvio por MENCAO de porta: uma linha com 'Invoke-FilhoDoHook'
    #      num comentario ao lado de uma chamada direta era liberada.
    #
    # Agora nao ha nada a declarar: a lista esta AQUI, cada entrada tem de
    # casar EXATAMENTE UMA linha, e qualquer chamada fora dela e acusada.
    # Duplicar uma linha permitida tambem quebra, porque a contagem passa a
    # dois. Achados do qa-reviewer nas rodadas 4 e 5.
    $PERMITIDAS = @(
        @{ Arquivo = 'scripts\lib\hooks-comum.ps1'
           Linha   = '$saida = (& powershell @Argumentos 2>&1 | Out-String)'
           Porque  = 'a porta dos hooks: e ela que baixa a preferencia em volta da chamada' },
        @{ Arquivo = 'scripts\collect-diff.ps1'
           Linha   = '$testeSaida = (& powershell -NoProfile -ExecutionPolicy Bypass -Command $testeCmd 2>&1 | Out-String)'
           Porque  = 'anterior a esta subfase; item 110 do backlog, com try/catch proprio' }
    )

    $arquivos = @(Get-ChildItem (Join-Path $OsRoot 'scripts') -Recurse -File -Filter '*.ps1')
    Assert-True ($arquivos.Count -ge 5) "esperava pelo menos 5 scripts, achei $($arquivos.Count) - o caso mediria nada"

    $naoPermitidas = @()
    $contagem = @{}
    foreach ($e in $PERMITIDAS) { $contagem[$e.Arquivo + '|' + $e.Linha] = 0 }

    foreach ($a in $arquivos) {
        $n = 0
        foreach ($l in @((Get-Texto $a.FullName) -split "`r?`n")) {
            $n++
            if (-not (Test-LinhaInvocaPowershell $l)) { continue }
            # Caminho RELATIVO, e nao so o nome: dois arquivos homonimos em
            # subdiretorios diferentes de scripts/ teriam a mesma chave, e a
            # permissao de um valeria para o outro. Achado do qa-reviewer.
            $rel = $a.FullName.Substring($OsRoot.Length).TrimStart([char]92)
            $chave = $rel + '|' + $l.Trim()
            if ($contagem.ContainsKey($chave)) { $contagem[$chave]++ ; continue }
            $naoPermitidas += ("$($a.Name):$n " + $l.Trim())
        }
    }

    Assert-True ($naoPermitidas.Count -eq 0) `
        ("chamada direta a 'powershell' fora da lista permitida: " + ($naoPermitidas -join ' | '))

    # Cada entrada tem de casar EXATAMENTE UMA linha. Zero significa que a
    # permissao sobreviveu ao motivo dela - e permissao sem motivo vira
    # autorizacao silenciosa. Mais de uma significa linha duplicada, que e
    # como o achado 3 da quinta rodada contornava a versao anterior.
    foreach ($e in $PERMITIDAS) {
        $c = $contagem[$e.Arquivo + '|' + $e.Linha]
        Assert-True ($c -eq 1) `
            "a permissao para '$($e.Arquivo)' casou $c linha(s), e tem de casar exatamente 1. Motivo declarado: $($e.Porque)"
    }

    # Par positivo: as portas SAO usadas. Sem isto o caso passaria num mundo
    # em que nenhum script chama processo filho nenhum.
    $usam = @()
    foreach ($nome in @('hook-pre-commit.ps1', 'hook-pre-push.ps1')) {
        $txt = Get-Texto (Join-Path $OsRoot "scripts\$nome")
        if ($txt -match 'Invoke-FilhoDoHook\s+-Argumentos') { $usam += $nome }
    }
    Assert-True ($usam.Count -eq 2) ("esperava os dois hooks usando a funcao, achei: " + ($usam -join ', '))

    $boot = Get-Texto (Join-Path $OsRoot 'scripts\bootstrap.ps1')
    Assert-True ($boot -match "Invoke-NativoLocal 'powershell'") `
        "o bootstrap nao chama o instalador de hooks por Invoke-NativoLocal"
}

Test-Caso "achados: relatorio inexistente devolve lista vazia, nao lanca" {
    $a = @(Get-AchadosBloqueantesDoRelatorio -Caminho (Join-Path $env:TEMP ('nada-' + [guid]::NewGuid().ToString('N') + '.md')))
    Assert-True (@($a).Count -eq 0) "inventou achado sobre relatorio que nao existe"
}

# =============================================================================
# FUNCIONAL - o instalador
# =============================================================================

Test-Caso "instalador: instala, e a segunda execucao NAO regrava nada" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $r1 = Invoke-Instalador -Repo $fx
        Assert-True ($r1.Exit -eq 0) "primeira instalacao saiu com $($r1.Exit): $($r1.Saida)"
        Assert-True ($r1.Saida -match 'GRAVADO') "a primeira execucao nao gravou nada"

        $r2 = Invoke-Instalador -Repo $fx
        Assert-True ($r2.Exit -eq 0) "segunda execucao saiu com $($r2.Exit)"
        Assert-True ($r2.Saida -notmatch 'GRAVADO') "regravou o que ja estava certo - nao e idempotente"
        Assert-True ($r2.Saida -match 'nada a fazer') "nao declarou que nao havia o que fazer"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "instalador: -Verificar sai 1 antes e 0 depois, sem configurar nada" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $antes = Invoke-Instalador -Repo $fx -Extra @('-Verificar')
        Assert-True ($antes.Exit -eq 1) "-Verificar saiu com $($antes.Exit) num repositorio sem hooks"

        # E o -Verificar NAO pode ter instalado nada pelo caminho.
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True (-not $e.Instalado) "-Verificar configurou o repositorio: ele so pode diagnosticar"

        $null = Invoke-Instalador -Repo $fx
        $depois = Invoke-Instalador -Repo $fx -Extra @('-Verificar')
        Assert-True ($depois.Exit -eq 0) "-Verificar saiu com $($depois.Exit) depois de instalar"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "instalador: nao sobrescreve core.hooksPath de outro lugar sem -Reparar" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx config core.hooksPath 'meus-hooks' 2>$null
        $ErrorActionPreference = $ea

        $r = Invoke-Instalador -Repo $fx
        Assert-True ($r.Exit -eq 1) "saiu com $($r.Exit) em vez de parar"
        Assert-True ($r.Saida -match 'PARADO') "nao avisou que parou"
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True ($e.HooksPath -eq 'meus-hooks') "sobrescreveu configuracao alheia: virou '$($e.HooksPath)'"

        $rep = Invoke-Instalador -Repo $fx -Extra @('-Reparar')
        Assert-True ($rep.Exit -eq 0) "-Reparar saiu com $($rep.Exit)"
        $e2 = Get-EstadoDosHooks -Raiz $fx
        Assert-True ($e2.Instalado) "-Reparar nao deixou instalado: $($e2.Motivo)"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "instalador: pasta versionada sem os shims NAO vira instalacao" {
    # O pior resultado possivel e instalar com sucesso e nao verificar nada:
    # a pessoa passa a acreditar que esta protegida.
    $fx = New-RepoHooks -ComGithooks
    try {
        Remove-Item (Join-Path $fx 'githooks\commit-msg') -Force
        $r = Invoke-Instalador -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit) em vez de 2"
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True ($e.Aponta -ne 'certo') "configurou apontando para uma pasta incompleta"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "instalador: repositorio sem a pasta githooks/ sai 2 e nao configura" {
    $fx = New-RepoHooks
    try {
        $r = Invoke-Instalador -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit)"
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True ($e.Aponta -eq 'ausente') "configurou algo sem ter pasta para onde apontar"
    } finally { Remove-RepoHooks $fx }
}

# =============================================================================
# FUNCIONAL - os hooks disparando de verdade
# =============================================================================

Test-Caso "commit-msg de verdade: a mensagem defeituosa e BARRADA e o commit nao acontece" {
    $fx = New-RepoHooks -LigadoNaPlataforma
    try {
        Add-ArquivoEStage -Repo $fx
        $antes = Get-QuantosCommits -Repo $fx
        $r = Invoke-CommitComMensagem -Repo $fx -Mensagem $MSG_DEFEITUOSA
        Assert-True ($r.Exit -ne 0) "o git aceitou o commit com a mensagem defeituosa"
        Assert-True ($r.Saida -match 'linha 2') ("a saida nao explica o motivo: " + $r.Saida)
        Assert-True ((Get-QuantosCommits -Repo $fx) -eq $antes) "o commit entrou mesmo com o hook barrando"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "commit-msg de verdade: a mensagem corrigida PASSA e o commit acontece" {
    $fx = New-RepoHooks -LigadoNaPlataforma
    try {
        Add-ArquivoEStage -Repo $fx
        $antes = Get-QuantosCommits -Repo $fx
        $r = Invoke-CommitComMensagem -Repo $fx -Mensagem $MSG_CORRIGIDA
        Assert-True ($r.Exit -eq 0) ("o hook barrou uma mensagem valida: " + $r.Saida)
        Assert-True ((Get-QuantosCommits -Repo $fx) -eq ($antes + 1)) "o commit nao entrou"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-commit de verdade: repositorio limpo passa, com segredo e barrado" {
    $fx = New-RepoHooks -LigadoNaPlataforma
    try {
        Add-ArquivoEStage -Repo $fx
        $ok = Invoke-CommitComMensagem -Repo $fx -Mensagem "chore: conteudo inofensivo"
        Assert-True ($ok.Exit -eq 0) ("barrou um commit sem nada a acusar: " + $ok.Saida)

        # Token sintetico, no formato que o detector reconhece, MONTADO por
        # concatenacao e escrito dentro da fixture temporaria - nunca literal
        # neste arquivo. Por isso esta suite nao precisa do marcador de
        # isencao, e declarar um seria roubar a isencao que pertence a
        # tests/suites/scripts.ps1: o guarda-corpo aceita UM arquivo isento,
        # e foi ele que acusou quando eu declarei o segundo.
        $token = 'ghp_' + ('A' * 36)
        Add-ArquivoEStage -Repo $fx -Nome 'vaza.txt' -Conteudo ("token=" + $token + "`n")
        $mau = Invoke-CommitComMensagem -Repo $fx -Mensagem "chore: agora com segredo"
        Assert-True ($mau.Exit -ne 0) "deixou entrar um commit com credencial reconhecivel"
        Assert-True ($mau.Saida -match '(?i)pre-commit') ("a saida nao identifica o hook: " + $mau.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-commit de verdade: NAO altera arquivo e NAO mexe no staging" {
    # Hook que conserta sozinho muda o que a pessoa esta commitando sem ela
    # ver. E a mesma regra que o /os:doctor cumpre, medida do mesmo jeito.
    $fx = New-RepoHooks -LigadoNaPlataforma
    try {
        Add-ArquivoEStage -Repo $fx
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $stageAntes = (git -C $fx diff --cached --name-status 2>$null | Out-String)
        $ErrorActionPreference = $ea
        $hashAntes = (Get-FileHash (Join-Path $fx 'a.txt') -Algorithm SHA256).Hash

        $null = Invoke-CommitComMensagem -Repo $fx -Mensagem "chore: nada de especial"

        $hashDepois = (Get-FileHash (Join-Path $fx 'a.txt') -Algorithm SHA256).Hash
        Assert-True ($hashAntes -eq $hashDepois) "o hook alterou um arquivo do projeto"
        Assert-True ($stageAntes -match 'a.txt') "a pre-condicao nao montou staging - o caso mediria nada"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-commit de verdade: escreve em artifacts/hooks/, nunca em artifacts/review/" {
    # 'artifacts/review/security-report.md' e a EVIDENCIA das revisoes
    # independentes. Um hook que a regravasse a cada commit destruiria a
    # evidencia do fechamento em curso.
    $fx = New-RepoHooks -LigadoNaPlataforma
    try {
        $review = Join-Path $fx 'artifacts\review'
        New-Item -ItemType Directory -Path $review -Force | Out-Null
        $marcado = Join-Path $review 'security-report.md'
        [System.IO.File]::WriteAllText($marcado, "EVIDENCIA ANTERIOR`n", (New-Object System.Text.UTF8Encoding($false)))
        $hashAntes = (Get-FileHash $marcado -Algorithm SHA256).Hash

        Add-ArquivoEStage -Repo $fx
        $null = Invoke-CommitComMensagem -Repo $fx -Mensagem "chore: commit qualquer"

        Assert-True (Test-Path (Join-Path $fx 'artifacts\hooks\pre-commit-security.md')) `
            "o hook nao escreveu o relatorio dele em artifacts/hooks/"
        Assert-True ((Get-FileHash $marcado -Algorithm SHA256).Hash -eq $hashAntes) `
            "o hook sobrescreveu a evidencia de revisao em artifacts/review/"
    } finally { Remove-RepoHooks $fx }
}

# =============================================================================
# FUNCIONAL - a politica do pre-push
# =============================================================================

function Invoke-PrePush {
    param([string]$Repo)
    $script = Join-Path $OsRoot 'scripts\hook-pre-push.ps1'
    $anterior = (Get-Location).Path
    try {
        Set-Location -LiteralPath $Repo
        $saida = (& powershell @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) 2>&1 | Out-String)
        return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
    } finally { Set-Location -LiteralPath $anterior }
}

function New-ManifestoComPrePush {
    # O bloco 'hooks' tem de ficar DENTRO de 'verificacao', e o append
    # ingenuo no fim do arquivo o punha dentro de 'ambiente' - onde o leitor
    # nunca o acharia, e o caso mediria o PADRAO achando que media a politica.
    # Por isso o manifesto e montado, e nao concatenado.
    param([string[]]$Valores, [switch]$SemComando)
    $s = "identidade:`n  nome: `"fixture`"`nclassificacao:`n  criticidade: `"media`"`nverificacao:`n"
    if (-not $SemComando) { $s += "  comando: `".\tests\run-tests.ps1`"`n" }
    $s += "  tests: false`n"
    if ($Valores) {
        $s += "  hooks:`n    pre_push:`n"
        foreach ($v in $Valores) { $s += "      - `"$v`"`n" }
    }
    $s += "ambiente:`n  dependencias: []`n"
    return $s
}

Test-Caso "pre-push: politica 'nenhum' nao roda nada e deixa passar" {
    $fx = New-RepoHooks -Manifesto (New-ManifestoComPrePush -Valores @('nenhum'))
    try {
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 0) ("saiu com $($r.Exit): " + $r.Saida)
        Assert-True ($r.Saida -match "nenhum") "nao declarou que o proprio projeto desligou a verificacao"
    } finally { Remove-RepoHooks $fx }
}

function Invoke-PrePushComRefs {
    # O Git entrega as refs do push no STDIN; o Invoke-PrePush roda sem stdin.
    param([string]$Repo, [string]$Refs)
    $script = Join-Path $OsRoot 'scripts\hook-pre-push.ps1'
    $anterior = (Get-Location).Path
    try {
        Set-Location -LiteralPath $Repo
        $saida = ($Refs | & powershell @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) 2>&1 | Out-String)
        return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
    } finally { Set-Location -LiteralPath $anterior }
}

Test-Caso "pre-push: refs/preservado/* no stdin barra, mesmo com politica 'nenhum' (r10 S-A5)" {
    # Ref local deliberada (stash orfao anterior a sanitizacao): a protecao dela e o
    # bundle do eos backup, e um push --mirror manual a levaria ao remoto.
    $fx = New-RepoHooks -Manifesto (New-ManifestoComPrePush -Valores @('nenhum'))
    try {
        $z = '0' * 40
        $a = 'a' * 40
        $r = Invoke-PrePushComRefs -Repo $fx -Refs ("refs/heads/main $a refs/heads/main $z`nrefs/preservado/stash-x $a refs/preservado/stash-x $z`n")
        Assert-True ($r.Exit -eq 1) ("saiu com $($r.Exit) em vez de 1: " + $r.Saida)
        Assert-True ($r.Saida -match 'refs/preservado/stash-x') ("nao nomeou a ref recusada: " + $r.Saida)
        $r = Invoke-PrePushComRefs -Repo $fx -Refs ("refs/heads/main $a refs/preservado/x $z`n")
        Assert-True ($r.Exit -eq 1) ("ref REMOTA refs/preservado/* tambem tem de barrar; saiu com $($r.Exit)")
        # par negativo: so branch, mesma politica, passa
        $r = Invoke-PrePushComRefs -Repo $fx -Refs ("refs/heads/main $a refs/heads/main $z`n")
        Assert-True ($r.Exit -eq 0) ("push so de branch barrou: saiu com $($r.Exit): " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: valor FORA do vocabulario barra, e diz qual valor" {
    # A direcao foi decidida na 2.5 para 'verificacao.tests': o que o leitor
    # nao entende nunca vira 'entao nao precisa'.
    $fx = New-RepoHooks -Manifesto (New-ManifestoComPrePush -Valores @('turbinado'))
    try {
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit) em vez de 2"
        Assert-True ($r.Saida -match 'turbinado') ("nao nomeou o valor desconhecido: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: 'nenhum' junto com outro valor e contradicao, e barra" {
    $fx = New-RepoHooks -Manifesto (New-ManifestoComPrePush -Valores @('nenhum', 'doctor'))
    try {
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit): adivinhar qual vale seria inventar politica"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: 'tests' declarado sem 'verificacao.comando' BARRA, nao supoe o comando" {
    $fx = New-RepoHooks -Manifesto (New-ManifestoComPrePush -Valores @('tests') -SemComando)
    try {
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit) - chutar o comando seria inventar o contrato"
        Assert-True ($r.Saida -match 'verificacao.comando') ("nao nomeou o campo que falta: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: lista em FLUXO barra e diz que a causa e a FORMA da lista" {
    # O leitor de manifesto desta plataforma le lista de BLOCO e nao de fluxo
    # (item 42 do backlog): 'pre_push: ["doctor"]' chega como UMA string com
    # colchete dentro. Sem esta deteccao, a mensagem diria "nao reconheco
    # '["doctor"]'" e mandaria procurar erro de digitacao num valor certo.
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n  hooks:`n    pre_push: [`"doctor`"]`n"
    $fx = New-RepoHooks -Manifesto $m
    try {
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit)"
        Assert-True ($r.Saida -match '(?i)fluxo') ("nao apontou a forma da lista como causa: " + $r.Saida)
        Assert-True ($r.Saida -match 'pre_push:') "nao mostrou como declarar em bloco"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: a MESMA lista em BLOCO e lida - par do caso de fluxo" {
    # Sem este par, uma implementacao que barrasse toda politica declarada
    # passaria no caso acima.
    $fx = New-RepoHooks -Manifesto (New-ManifestoComPrePush -Valores @('doctor'))
    try {
        Add-ArquivoEStage -Repo $fx
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx commit -q -m 'base' 2>$null
        $ErrorActionPreference = $ea

        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Saida -match 'declarada em project.yaml') ("nao leu a politica do manifesto: " + $r.Saida)
        Assert-True ($r.Saida -notmatch 'security \(varredura') "rodou 'security', que a politica desta fixture nao pediu"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: manifesto ausente cai no padrao, e o padrao e EXATAMENTE doctor + security" {
    # Campo ausente nao e 'nao verifique' e tambem nao autoriza impor o caro:
    # a mesma semantica que a mantenedora fixou para ambiente.dependencias.
    #
    # A PRIMEIRA versao deste caso passava por qualquer implementacao, e o
    # qa-reviewer derivou a mutacao que sobrevivia: acrescentar 'tests' ao
    # $PADRAO. Com a fixture sem project.yaml, a etapa 'tests' caia no ramo de
    # 'comando ausente', cuja mensagem nao contem 'run-tests' - entao o
    # '-notmatch run-tests' continuava verde. E o '-match doctor' casava com a
    # LINHA DA POLITICA, nao com a execucao: tirar 'doctor' de $ordem tambem
    # sobrevivia.
    #
    # Agora o caso mede os dois fatos separadamente:
    #   1. a linha da POLITICA nomeia exatamente doctor e security;
    #   2. o MARCADOR DE ETAPA do doctor aparece - e ele so e impresso quando
    #      a etapa executa.
    $fx = New-RepoHooks
    try {
        Add-ArquivoEStage -Repo $fx
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx commit -q -m 'base' 2>$null
        $ErrorActionPreference = $ea

        $r = Invoke-PrePush -Repo $fx

        $linha = @(($r.Saida -split "`r?`n") | Where-Object { $_ -match 'politica:' })
        Assert-True (@($linha).Count -eq 1) ("esperava UMA linha de politica, vieram $(@($linha).Count): " + $r.Saida)
        Assert-True ($linha[0] -match 'padrao') ("nao declarou que estava no padrao: " + $linha[0])
        Assert-True ($linha[0] -match '(?i)\bdoctor\b')    "a politica padrao nao inclui doctor: $($linha[0])"
        Assert-True ($linha[0] -match '(?i)\bsecurity\b')  "a politica padrao nao inclui security: $($linha[0])"
        Assert-True ($linha[0] -notmatch '(?i)\btests\b') `
            "a politica padrao inclui 'tests', que custa minutos e nunca foi pedida: $($linha[0])"

        # O marcador de etapa - duas colunas de recuo - so sai quando a etapa
        # EXECUTA. E o que separa 'o doctor esta na politica' de 'o doctor rodou'.
        Assert-True ($r.Saida -match '(?m)^\s+doctor\.\.\.') `
            ("a etapa doctor nao chegou a executar: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: lista VAZIA declarada e o mesmo que 'nenhum', e nao uma aprovacao calada" {
    # Achado do qa-reviewer, confirmado por execucao: o leitor devolve um
    # Object[] de ZERO itens para 'pre_push: []', e '$null -ne @()' e
    # verdadeiro. A politica virava lista vazia, nada entrava na fila, e o
    # hook imprimia "ok -  passaram" com exit 0 - aprovacao sobre zero
    # verificacao, por um caminho que nenhuma documentacao mencionava.
    # A forma importa, e foi MEDIDA: 'pre_push: []' devolve Object[] de zero
    # itens (o caminho do defeito), enquanto 'pre_push:' sem valor devolve
    # $null e cai no padrao - que e o comportamento certo para campo sem
    # valor. Usar a forma errada aqui mediria outra coisa.
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n  hooks:`n    pre_push: []`n"
    $fx = New-RepoHooks -Manifesto $m
    try {
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 0) "saiu com $($r.Exit): lista vazia e desligamento legitimo, nao erro"
        Assert-True ($r.Saida -match 'nenhum') `
            ("nao caiu na mensagem honesta de 'nenhum': " + $r.Saida)
        Assert-True ($r.Saida -notmatch 'passaram') `
            ("anunciou que algo 'passou' sem ter rodado nada: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: item VAZIO na lista barra - nao e desligamento disfarcado" {
    # Achado do qa-reviewer na segunda rodada, e e a classe que esta subfase
    # mais repetiu: o conserto do '[]' filtrava vazio ANTES de conferir o
    # vocabulario, entao '- ""' sumia, a contagem caia para zero, e a lista
    # caia no ramo de 'nenhum' DESLIGANDO TUDO com exit 0 - sob o rotulo falso
    # de "lista vazia ([])". Fechei um ramo e joguei o irmao no mesmo caminho.
    #
    # Medido: '- ""' e '- "   "' devolvem lista de UM item vazio; '[]' e o
    # hifen sozinho devolvem ZERO itens. Fatos diferentes, tratamento diferente.
    foreach ($forma in @('      - ""', '      - "   "')) {
        $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n  hooks:`n    pre_push:`n$forma`n"
        $fx = New-RepoHooks -Manifesto $m
        try {
            Add-ArquivoEStage -Repo $fx
            $r = Invoke-PrePush -Repo $fx
            Assert-True ($r.Exit -eq 2) "forma '$($forma.Trim())' saiu com $($r.Exit) em vez de barrar"
            Assert-True ($r.Saida -match '(?i)vazio') ("nao nomeou o item vazio como causa: " + $r.Saida)
            Assert-True ($r.Saida -notmatch 'nada foi verificado') `
                ("tratou item vazio como desligamento declarado: " + $r.Saida)
        } finally { Remove-RepoHooks $fx }
    }
}

Test-Caso "pre-push: suite que escreve em STDERR e passa NAO derruba o hook" {
    # Sonda prescrita pelo qa-reviewer e confirmada por execucao antes do
    # conserto: sob '$ErrorActionPreference = Stop', o stderr de executavel
    # nativo redirecionado com '2>&1' vira ErrorRecord TERMINANTE, o 'trap' do
    # hook pegava, e o push saia com 2 dizendo "NAO consegui rodar".
    #
    # Ou seja: uma suite que PASSOU e imprimiu um aviso barrava o push. E a
    # armadilha que o runbook desta casa documenta, e que ja criou
    # 'Invoke-Git' e 'Invoke-NativoLocal'. Esta e a terceira porta.
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n" +
         "  comando: `".\suite-fake.ps1`"`n" +
         "  hooks:`n    pre_push:`n      - `"tests`"`n"
    $fx = New-RepoHooks -Manifesto $m
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'suite-fake.ps1'),
            "[Console]::Error.WriteLine('aviso em stderr')`nexit 0`n",
            (New-Object System.Text.UTF8Encoding($false)))
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 0) `
            ("uma suite que passou e escreveu em stderr barrou o push (exit $($r.Exit)): " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: suite que REPROVA e escreve em stderr sai 1, e nao 2" {
    # Par do caso acima, e ele mede a outra metade do estrago: sem o conserto,
    # 'reprovou' virava 'nao consegui medir' - duas acoes diferentes, trocadas.
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n" +
         "  comando: `".\suite-fake.ps1`"`n" +
         "  hooks:`n    pre_push:`n      - `"tests`"`n"
    $fx = New-RepoHooks -Manifesto $m
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'suite-fake.ps1'),
            "[Console]::Error.WriteLine('falhou feio')`nexit 1`n",
            (New-Object System.Text.UTF8Encoding($false)))
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 1) "suite que reprova escrevendo em stderr saiu $($r.Exit), e deveria sair 1"
        Assert-True ($r.Saida -match '(?i)reprovou') ("nao disse que a suite reprovou: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: suite que termina SEM codigo de saida barra pelo sentinela 98" {
    # O sentinela 98 estava no codigo e sem caso nenhum - 'afirmacao sem
    # medicao', nas palavras do qa-reviewer. Medido: um .ps1 que termina sem
    # 'exit' deixa $LASTEXITCODE nulo dentro de '-Command', e o sentinela e
    # alcancado de fato.
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n" +
         "  comando: `".\suite-fake.ps1`"`n" +
         "  hooks:`n    pre_push:`n      - `"tests`"`n"
    $fx = New-RepoHooks -Manifesto $m
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'suite-fake.ps1'),
            "Write-Host 'rodei e nao chamei exit'`n",
            (New-Object System.Text.UTF8Encoding($false)))
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit): sem codigo de saida nao da para afirmar que a suite rodou"
        Assert-True ($r.Saida -match '(?i)sem devolver codigo') ("nao nomeou a causa: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: comando de teste que NAO EXISTE barra - e nao vira 'passou'" {
    # O pior fail-open desta subfase, achado pelo qa-reviewer e confirmado por
    # execucao antes do conserto: '& $comando' lanca, a instrucao morre, e o
    # 'exit $LASTEXITCODE' seguinte sai com ZERO num processo novo, onde
    # $LASTEXITCODE nunca foi definido. O hook dizia "tests passaram" sobre
    # uma suite que nao rodou - exatamente o contrario da regra central da 2.6.
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n" +
         "  comando: `".\nao-existe-nenhum.ps1`"`n" +
         "  hooks:`n    pre_push:`n      - `"tests`"`n"
    $fx = New-RepoHooks -Manifesto $m
    try {
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit): comando que nao roda nunca pode virar 'passou'"
        # A mensagem cobre os DOIS casos que caem no sentinela 97 - comando que
        # nao existe, e comando que comecou e lancou no meio. O qa-reviewer
        # mostrou que a redacao anterior ("nao consegui invocar") era mais
        # estreita que o ramo: barrava certo, com a causa impressa errada.
        Assert-True ($r.Saida -match '(?i)nao pode ser invocado') `
            ("nao nomeou a causa do barramento: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: a etapa tests EXECUTA de verdade - par positivo do caso acima" {
    # Sem este par, uma implementacao que barrasse TODA etapa 'tests' passaria
    # no caso de cima. Ele tambem e o unico caso que exercita a etapa inteira:
    # antes dele, 'tests' nunca rodava em caso nenhum, e o qa-reviewer cobrou.
    $script = "exit 0`n"
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n" +
         "  comando: `".\suite-fake.ps1`"`n" +
         "  hooks:`n    pre_push:`n      - `"tests`"`n"
    $fx = New-RepoHooks -Manifesto $m
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'suite-fake.ps1'), $script, (New-Object System.Text.UTF8Encoding($false)))
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 0) ("barrou uma suite que passou: " + $r.Saida)
        Assert-True ($r.Saida -match '(?m)^\s+tests \(') ("a etapa tests nao executou: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "pre-push: suite que REPROVA sai 1, e suite que NAO RODA sai 2 - sao fatos diferentes" {
    # 'reprovou' e 'nao consegui medir' levam a acoes diferentes, e o ADR-0009
    # existe justamente para nao confundir os dois.
    $m = "identidade:`n  nome: `"fixture`"`nverificacao:`n  tests: false`n" +
         "  comando: `".\suite-fake.ps1`"`n" +
         "  hooks:`n    pre_push:`n      - `"tests`"`n"

    $fxA = New-RepoHooks -Manifesto $m
    try {
        [System.IO.File]::WriteAllText((Join-Path $fxA 'suite-fake.ps1'), "exit 1`n", (New-Object System.Text.UTF8Encoding($false)))
        Add-ArquivoEStage -Repo $fxA
        $rA = Invoke-PrePush -Repo $fxA
        Assert-True ($rA.Exit -eq 1) "suite que reprova deveria sair 1, saiu $($rA.Exit)"
        Assert-True ($rA.Saida -match '(?i)reprovou') ("nao disse que a suite reprovou: " + $rA.Saida)
    } finally { Remove-RepoHooks $fxA }

    $fxB = New-RepoHooks -Manifesto $m
    try {
        # Codigo que nao e 0 nem 1: pelo ADR-0009 isso e 'nao rodou'.
        [System.IO.File]::WriteAllText((Join-Path $fxB 'suite-fake.ps1'), "exit 2`n", (New-Object System.Text.UTF8Encoding($false)))
        Add-ArquivoEStage -Repo $fxB
        $rB = Invoke-PrePush -Repo $fxB
        Assert-True ($rB.Exit -eq 2) "suite que nao roda deveria sair 2, saiu $($rB.Exit)"
    } finally { Remove-RepoHooks $fxB }
}

Test-Caso "pre-push: manifesto ILEGIVEL barra, e a causa nomeada e o manifesto" {
    # Assumir o padrao sobre manifesto quebrado seria verificar MENOS do que o
    # projeto pode ter pedido, em silencio.
    #
    # A PRIMEIRA versao deste caso passava pela razao errada, e foi a mutacao
    # que mostrou: o manifesto que eu escolhi - uma lista solta dentro de
    # 'identidade' - o leitor LE sem lancar, devolvendo a chave que entendeu.
    # O 'exit 2' vinha da politica PADRAO falhando num repositorio sem commit,
    # e a mutacao que desligava a guarda continuava verde. Duas correcoes:
    #
    #   1. o manifesto agora e ILEGIVEL DE VERDADE - byte invalido para UTF-8,
    #      que a leitura estrita dos detectores recusa por contrato;
    #   2. a fixture tem commit, entao o caminho padrao ESTARIA limpo: o unico
    #      motivo possivel para barrar e o manifesto. E a assercao exige que a
    #      mensagem NOMEIE o manifesto, em vez de aceitar qualquer 2.
    # A fixture precisa ser boa o bastante para o caminho PADRAO sair 0 - com
    # manifesto valido E com docs/STATE.md, senao o doctor sai 2 por nao ter o
    # que medir, e o caso voltaria a barrar por outro motivo. Foi a propria
    # pre-condicao que mostrou isso na primeira tentativa do conserto.
    $fx = New-RepoHooks -Manifesto (New-ManifestoComPrePush -Valores @('doctor'))
    try {
        New-Item -ItemType Directory -Path (Join-Path $fx 'docs') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $fx 'docs\STATE.md'),
            "# Estado`n`n- Ultima atualizacao: 2026-01-01`n`n## Proximo passo`n`nnada`n",
            (New-Object System.Text.UTF8Encoding($false)))
        Add-ArquivoEStage -Repo $fx
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx commit -q -m 'base' 2>$null
        $ErrorActionPreference = $ea

        # Pre-condicao: SEM o manifesto quebrado, este repositorio passa. Sem
        # isto o caso mediria "barra por algum motivo", que e o defeito que a
        # mutacao expos.
        $limpo = Invoke-PrePush -Repo $fx
        Assert-True ($limpo.Exit -eq 0) `
            ("a pre-condicao falhou: o repositorio ja barrava antes do manifesto quebrado (exit $($limpo.Exit)): " + $limpo.Saida)

        $bytes = [System.Text.Encoding]::UTF8.GetBytes("identidade:`n  nome: `"x`"`n")
        $bytes += [byte]0xFF   # byte que NAO forma sequencia UTF-8 valida
        [System.IO.File]::WriteAllBytes((Join-Path $fx 'project.yaml'), $bytes)

        $r = Invoke-PrePush -Repo $fx
        Assert-True ($r.Exit -eq 2) "saiu com $($r.Exit) sobre manifesto que nao le"
        Assert-True ($r.Saida -match 'project.yaml') ("nao nomeou o manifesto como causa: " + $r.Saida)
    } finally { Remove-RepoHooks $fx }
}

# =============================================================================
# O DOCTOR DIAGNOSTICA OS HOOKS - e nao os instala
# =============================================================================

function Invoke-DoctorEm {
    param([string]$Repo)
    $saida = (& powershell @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Doctor, '-Path', $Repo) 2>&1 | Out-String)
    return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
}

Test-Caso "doctor: projeto SEM githooks/ sai PASS 'nao se aplica', e sem lacuna" {
    # Cobrar o que ninguem declarou e o ruido que a dimensao 'ambiente' foi
    # desenhada para nao produzir.
    $fx = New-RepoHooks
    try {
        $d = Get-DiagnosticoHooks -Raiz $fx
        Assert-True ($d.Status -eq 'PASS') "status veio '$($d.Status)' sobre projeto que nao versiona hooks"
        Assert-True (@($d.NaoVerificado).Count -eq 0) "declarou lacuna sobre um fato determinado"
        Assert-True (@($d.Achados).Count -eq 0) "acusou projeto que nao adotou hooks"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "doctor: githooks/ versionada e NAO instalada sai WARN, com acao concreta" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $d = Get-DiagnosticoHooks -Raiz $fx
        Assert-True ($d.Status -eq 'WARN') "status veio '$($d.Status)'"
        Assert-True (@($d.Achados).Count -ge 1) "nao produziu achado nenhum"
        Assert-True (@($d.Achados | Where-Object { $_.Acao -match 'install-hooks' }).Count -ge 1) `
            "o achado nao diz qual comando resolve"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "doctor: instalado sai PASS e nomeia os tres hooks" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $null = Invoke-Instalador -Repo $fx
        $d = Get-DiagnosticoHooks -Raiz $fx
        Assert-True ($d.Status -eq 'PASS') "status veio '$($d.Status)': $($d.Motivo)"
        $r = ($d.Verificacoes | ForEach-Object { $_.Resultado }) -join ' '
        foreach ($h in @('commit-msg', 'pre-commit', 'pre-push')) {
            Assert-True ($r -match [regex]::Escape($h)) "a verificacao nao nomeia '$h'"
        }
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "doctor: o diagnostico NAO instala os hooks que ele acusa" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $null = Invoke-DoctorEm -Repo $fx
        $e = Get-EstadoDosHooks -Raiz $fx
        Assert-True (-not $e.Instalado) "o doctor instalou os hooks - ele so pode diagnosticar"
        Assert-True ($e.Aponta -eq 'ausente') "o doctor mexeu em core.hooksPath: virou '$($e.Aponta)'"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "doctor: a dimensao hooks chega ao relatorio humano E ao JSON" {
    $fx = New-RepoHooks -ComGithooks
    try {
        $null = Invoke-DoctorEm -Repo $fx
        $rel = Get-Texto (Join-Path $fx 'artifacts\doctor\doctor-report.md')
        Assert-True ($rel -match '\| hooks \|') "a dimensao nao aparece na tabela do relatorio"
        $json = (Get-Texto (Join-Path $fx 'artifacts\doctor\doctor.json')) | ConvertFrom-Json
        Assert-True (@($json.dimensions | Where-Object { $_.nome -eq 'hooks' }).Count -eq 1) `
            "a dimensao nao chega a saida estruturada"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "doctor: as dimensoes emitidas sao EXATAMENTE a lista canonica, na ordem" {
    # A expectativa vem do CODIGO, nao de um numero repetido aqui. Era a
    # classe que custou uma rodada inteira na 2.5: contagem em prosa que
    # ninguem podia conferir.
    $fx = New-RepoHooks -ComGithooks
    try {
        $null = Invoke-DoctorEm -Repo $fx
        $json = (Get-Texto (Join-Path $fx 'artifacts\doctor\doctor.json')) | ConvertFrom-Json
        $emitidas = (@($json.dimensions | ForEach-Object { $_.nome }) -join ',')
        $canonicas = (@(Get-DimensoesDoDoctor) -join ',')
        Assert-True ($emitidas -eq $canonicas) "emitiu '$emitidas' e a lista canonica e '$canonicas'"
    } finally { Remove-RepoHooks $fx }
}

# =============================================================================
# OS PROPRIOS SHIMS
# =============================================================================

Test-Caso "portabilidade: os hooks disparam em caminho COM ESPACO (cenario OneDrive)" {
    # O qa-reviewer marcou portabilidade INCONCLUSIVO na primeira rodada, e com
    # razao: o registro dizia "medido por sonda" e a sonda nao deixava saida
    # nenhuma na evidencia. Agora o fato esta na suite.
    #
    # O espaco no caminho quebra duas coisas se o shim nao citar as expansoes:
    # o 'dirname "$0"' e o '-File "$dir/../scripts/..."'. Os dois casos abaixo
    # medem o commit-msg ponta a ponta - barrando e deixando passar - porque e
    # o hook que recebe argumento (o arquivo de mensagem).
    $fx = New-RepoHooks -LigadoNaPlataforma -ComEspaco
    try {
        Assert-True ($fx -match ' ') "a fixture nao tem espaco no caminho: o caso mediria outra coisa ($fx)"
        Add-ArquivoEStage -Repo $fx

        $antes = Get-QuantosCommits -Repo $fx
        $mau = Invoke-CommitComMensagem -Repo $fx -Mensagem $MSG_DEFEITUOSA
        Assert-True ($mau.Exit -ne 0) ("em caminho com espaco o hook deixou passar a mensagem defeituosa: " + $mau.Saida)
        Assert-True ($mau.Saida -match 'linha 2') ("barrou por outro motivo: " + $mau.Saida)
        Assert-True ((Get-QuantosCommits -Repo $fx) -eq $antes) "o commit entrou mesmo com o hook barrando"

        $bom = Invoke-CommitComMensagem -Repo $fx -Mensagem $MSG_CORRIGIDA
        Assert-True ($bom.Exit -eq 0) ("em caminho com espaco o hook barrou mensagem valida: " + $bom.Saida)
        Assert-True ((Get-QuantosCommits -Repo $fx) -eq ($antes + 1)) "o commit nao entrou"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "portabilidade: o pre-commit tambem roda em caminho COM ESPACO" {
    # O commit-msg recebe o caminho do arquivo como ARGUMENTO; o pre-commit
    # nao recebe nada e resolve a raiz sozinho. Sao dois caminhos de codigo
    # diferentes, e o espaco pode quebrar so um deles.
    $fx = New-RepoHooks -LigadoNaPlataforma -ComEspaco
    try {
        Add-ArquivoEStage -Repo $fx
        $r = Invoke-CommitComMensagem -Repo $fx -Mensagem "chore: conteudo inofensivo"
        Assert-True ($r.Exit -eq 0) ("o pre-commit falhou em caminho com espaco: " + $r.Saida)
        Assert-True (Test-Path (Join-Path $fx 'artifacts\hooks\pre-commit-security.md')) `
            "o pre-commit nao chegou a gravar o relatorio: ele nao rodou"
    } finally { Remove-RepoHooks $fx }
}

Test-Caso "portabilidade: a FERRAMENTA tambem pode morar em caminho com espaco" {
    # Este caso nasceu de uma mutacao que SOBREVIVEU: tirar as aspas de
    # '"$dir/../scripts/..."' no shim nao derrubava nada.
    #
    # A razao e que os dois casos de espaco acima poem o espaco no
    # REPOSITORIO, enquanto 'core.hooksPath' aponta para o githooks/ DA
    # PLATAFORMA - que vive em C:\AI-WORKSPACE\..., sem espaco nenhum. O
    # '$dir' do shim nunca continha espaco, entao as aspas nunca eram
    # exercitadas. Dois lugares diferentes, e eu tinha coberto so um.
    #
    # Aqui a ferramenta e copiada para uma pasta COM espaco, e a assercao que
    # discrimina e a POSITIVA: com as aspas quebradas o caminho se parte, o
    # shim falha, e a mensagem VALIDA passa a ser barrada.
    $ferramenta = Join-Path $env:TEMP ("os com espaco " + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $fx = $null
    try {
        # SO o shim do commit-msg e copiado. Git pula hook que nao existe, e
        # copiar 'githooks/' inteiro arrastaria o pre-commit - que chama o
        # scanner, e ai seria preciso copiar metade da plataforma.
        #
        # Isto nao e economia: a PRIMEIRA versao deste caso copiava a pasta
        # inteira e falhava com "o argumento ... hook-pre-commit.ps1 nao
        # existe". O diagnostico importa, e ele confirma o oposto do que a
        # falha sugeria: o caminho COM ESPACO chegou inteiro ao '-File'. As
        # aspas do shim ja funcionavam; a fixture e que estava incompleta.
        New-Item -ItemType Directory -Path (Join-Path $ferramenta 'scripts\lib') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ferramenta 'githooks') -Force | Out-Null
        Copy-Item (Join-Path $GithooksDir 'commit-msg') (Join-Path $ferramenta 'githooks') -Force
        Copy-Item (Join-Path $OsRoot 'scripts\hook-commit-msg.ps1') (Join-Path $ferramenta 'scripts') -Force
        foreach ($m in @('scan-comum.ps1', 'hooks-comum.ps1')) {
            Copy-Item (Join-Path $LibDir $m) (Join-Path $ferramenta 'scripts\lib') -Force
        }

        $fx = New-RepoHooks
        $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        git -C $fx config core.hooksPath (Join-Path $ferramenta 'githooks') 2>$null
        $ErrorActionPreference = $ea

        Add-ArquivoEStage -Repo $fx
        $antes = Get-QuantosCommits -Repo $fx

        # POSITIVO: e esta assercao que morre quando a expansao perde as aspas.
        $bom = Invoke-CommitComMensagem -Repo $fx -Mensagem $MSG_CORRIGIDA
        Assert-True ($bom.Exit -eq 0) `
            ("com a ferramenta em caminho com espaco, o hook barrou mensagem valida: " + $bom.Saida)
        Assert-True ((Get-QuantosCommits -Repo $fx) -eq ($antes + 1)) "o commit nao entrou"

        # NEGATIVO: e o hook continua barrando o que deve barrar - senao o
        # caso passaria com um shim que nao faz nada.
        #
        # O arquivo NOVO aqui nao e detalhe: o commit positivo acima consumiu o
        # staging, e sem isto o git responde "nothing to commit" com codigo 1.
        # A assercao de 'exit -ne 0' passaria pelo motivo errado, e foi
        # exatamente assim que este caso falhou na primeira execucao.
        Add-ArquivoEStage -Repo $fx -Nome 'b.txt' -Conteudo "outro conteudo`n"
        $mau = Invoke-CommitComMensagem -Repo $fx -Mensagem $MSG_DEFEITUOSA
        Assert-True ($mau.Exit -ne 0) ("deixou passar a mensagem defeituosa: " + $mau.Saida)
        Assert-True ($mau.Saida -match 'linha 2') ("barrou por outro motivo: " + $mau.Saida)
    } finally {
        if ($fx) { Remove-RepoHooks $fx }
        Remove-Item $ferramenta -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "shims: os tres existem, sao ASCII, terminam em LF e carregam a marca da versao" {
    $marca = Get-MarcaDeVersaoDeHook
    foreach ($nome in $OS_HOOKS_ESPERADOS) {
        $p = Join-Path $GithooksDir $nome
        Assert-True (Test-Path $p -PathType Leaf) "shim ausente: $nome"
        $bytes = [System.IO.File]::ReadAllBytes($p)
        Assert-True (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0) "$nome tem byte fora de ASCII"
        Assert-True (@($bytes | Where-Object { $_ -eq 13 }).Count -eq 0) `
            "$nome tem CR: shim com CRLF quebra o '#!/bin/sh' no Git for Windows"
        $txt = [System.Text.Encoding]::ASCII.GetString($bytes)
        Assert-True ($txt.StartsWith('#!/bin/sh')) "$nome nao comeca com a shebang"
        Assert-True ($txt -like "*$marca*") "$nome nao carrega '$marca'"
    }
}

Test-Caso "shims: cada um chama um .ps1 que EXISTE" {
    # Shim apontando para script inexistente falharia so no primeiro commit de
    # quem instalasse - e falharia parecendo problema do Git.
    foreach ($nome in $OS_HOOKS_ESPERADOS) {
        $txt = Get-Texto (Join-Path $GithooksDir $nome)
        $m = [regex]::Match($txt, 'scripts/(hook-[a-z-]+\.ps1)')
        Assert-True ($m.Success) "$nome nao chama nenhum scripts/hook-*.ps1"
        $alvo = Join-Path $OsRoot ('scripts\' + $m.Groups[1].Value)
        Assert-True (Test-Path $alvo -PathType Leaf) "$nome chama '$($m.Groups[1].Value)', que nao existe"
    }
}
