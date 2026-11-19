<#
.SYNOPSIS
    Suite do /os:doctor: ele DIAGNOSTICA, e nao faz mais nada.

.DESCRIPTION
    Duas camadas, como as outras suites desta plataforma:

      UNITARIA  - as funcoes puras de scripts/lib/doctor-*.ps1 chamadas
                  direto, contra estados montados a mao.
      FUNCIONAL - o scripts/doctor.ps1 EXECUTADO contra repositorio de
                  verdade em $env:TEMP.

    Os dois criterios de aceite que nenhuma outra suite pode provar por mim:
    que o doctor NAO altera nada (comparacao byte a byte da arvore inteira) e
    que ele NAO roda a suite nem varre conteudo - que e a fronteira com
    'tests' e '/os:security'.

    Nada e escrito fora de $env:TEMP.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite doctor"
}

$Doctor = Join-Path $OsRoot 'scripts\doctor.ps1'
$LibDir = Join-Path $OsRoot 'scripts\lib'
foreach ($m in @('scan-comum.ps1', 'doctor-comum.ps1', 'doctor-manifesto.ps1',
                 'doctor-retomabilidade.ps1', 'doctor-git.ps1', 'doctor-ambiente.ps1', 'doctor-frescor.ps1')) {
    . (Join-Path $LibDir $m)
}

function New-RepoDoctor {
    <#
      Repositorio descartavel com o minimo para o doctor ter o que olhar.
      -Manifesto: conteudo do project.yaml ($null nao cria)
      -State: conteudo do docs/STATE.md ($null nao cria)
      -SemCommit: nao commita
    #>
    param(
        [string]$Manifesto = "identidade:`n  nome: `"fixture`"`nclassificacao:`n  criticidade: `"media`"`nverificacao:`n  comando: `".\tests\run-tests.ps1`"`n  tests: false`nambiente:`n  dependencias: []`n",
        [string]$State = "# Estado`n`n- Ultima atualizacao: 2026-01-01`n`n## Proximo passo`n`nnada`n",
        [switch]$SemCommit
    )
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $t = Join-Path $env:TEMP ("dr-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        git -C $t init -q 2>$null
        git -C $t config user.name  'Fixture'    2>$null
        git -C $t config user.email 'fx@invalid' 2>$null
        git -C $t config core.autocrlf false     2>$null
        git -C $t config core.safecrlf false     2>$null
        [System.IO.File]::WriteAllText((Join-Path $t '.gitignore'), "/artifacts/*`n", (New-Object System.Text.UTF8Encoding($false)))
        if ($Manifesto) {
            [System.IO.File]::WriteAllText((Join-Path $t 'project.yaml'), $Manifesto, (New-Object System.Text.UTF8Encoding($false)))
        }
        if ($State) {
            New-Item -ItemType Directory -Path (Join-Path $t 'docs') -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $t 'docs\STATE.md'), $State, (New-Object System.Text.UTF8Encoding($false)))
        }
        if (-not $SemCommit) {
            git -C $t add -A 2>$null
            git -C $t commit -q -m 'fixture' 2>$null
        }
        return $t
    } finally { $ErrorActionPreference = $anterior }
}

function Remove-RepoDoctor {
    param([string]$Caminho)
    if ($Caminho -and (Test-Path $Caminho)) { Remove-Item $Caminho -Recurse -Force -ErrorAction SilentlyContinue }
}

function Invoke-Doctor {
    # Processo filho, para o codigo de saida ser o de verdade.
    param([string]$Repo, [string[]]$Extra = @())
    $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Doctor, '-Path', $Repo) + $Extra
    $saida = (& powershell @argumentos 2>&1 | Out-String)
    return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
}

function Get-RelDoctor {
    param([string]$Repo)
    $p = Join-Path $Repo 'artifacts\doctor\doctor-report.md'
    if (-not (Test-Path $p)) { return $null }
    return Get-Texto $p
}

function Get-JsonDoctor {
    param([string]$Repo)
    $p = Join-Path $Repo 'artifacts\doctor\doctor.json'
    if (-not (Test-Path $p)) { return $null }
    return ((Get-Texto $p) | ConvertFrom-Json)
}

# =============================================================================
# CAMADA 0 - resolucao da raiz, as sete formas
# =============================================================================

Test-Caso "raiz: resolve da propria raiz, e a forma e normal" {
    $fx = New-RepoDoctor
    try {
        # Identidade de DIRETORIO, por marcador - e nao igualdade de string.
        # '$env:TEMP' nesta maquina e a forma 8.3 ('USUARI~1') e o git
        # responde com o nome longo: comparar os dois como texto reprova a
        # resposta certa. O marcador prova que e a mesma pasta, em qualquer
        # forma de caminho.
        $marca = 'marca-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt'
        [System.IO.File]::WriteAllText((Join-Path $fx $marca), 'x', (New-Object System.Text.UTF8Encoding($false)))

        $r = Get-RaizDoRepositorio -Path $fx
        Assert-True $r.Resolvida "nao resolveu a raiz a partir dela mesma"
        Assert-True ($r.Forma -eq 'normal') "forma errada: '$($r.Forma)'"
        Assert-True (Test-Path (Join-Path $r.Raiz $marca)) `
            "a raiz devolvida nao e o mesmo diretorio da fixture: '$($r.Raiz)'"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "raiz: de SUBDIRETORIO resolve para a raiz - e e por isso que a camada existe" {
    # O caso que motivou a camada inteira. 'Get-CaminhosDoGit' devolve $null
    # de dentro de um subdiretorio, e todo ramo negativo a jusante lanca
    # dizendo "nao e repositorio" sobre um subdiretorio de um repositorio
    # perfeito - diagnostico errado pela razao errada.
    $fx = New-RepoDoctor
    try {
        $sub = Join-Path $fx 'scripts\lib'
        New-Item -ItemType Directory -Path $sub -Force | Out-Null

        Assert-True ($null -eq (Get-CaminhosDoGit -Path $sub)) `
            "PRE-CONDICAO: 'Get-CaminhosDoGit' tinha de falhar no subdiretorio, senao este caso nao prova o que diz"

        $marca = 'marca-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt'
        [System.IO.File]::WriteAllText((Join-Path $fx $marca), 'x', (New-Object System.Text.UTF8Encoding($false)))

        $r = Get-RaizDoRepositorio -Path $sub
        Assert-True $r.Resolvida "nao resolveu a raiz a partir de um subdiretorio"
        Assert-True (Test-Path (Join-Path $r.Raiz $marca)) `
            "resolveu para '$($r.Raiz)', que nao e a raiz do repositorio"
        Assert-True (-not (Test-Path (Join-Path $r.Raiz 'lib'))) `
            "resolveu para o proprio subdiretorio em vez de subir ate a raiz"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "raiz: WORKTREE ligado resolve, e a forma DIZ que e worktree" {
    $princ = New-RepoDoctor
    $wt = Join-Path $env:TEMP ("dw-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { git -C $princ worktree add -q -b outra $wt 2>$null } finally { $ErrorActionPreference = $anterior }
        Assert-True (Test-Path (Join-Path $wt '.git') -PathType Leaf) `
            "PRE-CONDICAO: a fixture nao produziu worktree ligado ('.git' tinha de ser ARQUIVO)"

        $r = Get-RaizDoRepositorio -Path $wt
        Assert-True $r.Resolvida "nao resolveu a raiz dentro de um worktree ligado"
        Assert-True ($r.Forma -eq 'worktree') `
            "a forma saiu '$($r.Forma)': o doctor precisa saber que e worktree, porque GitDir e ComumDir diferem ali"
    } finally {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { git -C $princ worktree remove --force $wt 2>$null } finally { $ErrorActionPreference = $anterior }
        Remove-RepoDoctor $wt; Remove-RepoDoctor $princ
    }
}

Test-Caso "raiz: repositorio RECEM-INICIADO resolve - HEAD nao nascido nao impede" {
    $fx = New-RepoDoctor -SemCommit
    try {
        Assert-True ((Test-HeadResolvivel $fx) -eq $false) "PRE-CONDICAO: a fixture tinha de ter HEAD nao nascido"
        $r = Get-RaizDoRepositorio -Path $fx
        Assert-True $r.Resolvida "repositorio sem commit nenhum nao resolveu a raiz - e o estado do /os:new-project"
        Assert-True ($r.Forma -eq 'normal') "forma errada para repositorio recem-iniciado: '$($r.Forma)'"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "raiz: caminho FORA de repositorio e resposta determinada, nao 'nao consegui'" {
    # A distincao que a camada existe para preservar: 'nao ha repositorio' e
    # um FATO; 'nao consegui determinar' e uma lacuna. Colapsar os dois faria
    # o doctor sair com o codigo errado.
    $t = Join-Path $env:TEMP ("dn-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    try {
        $r = Get-RaizDoRepositorio -Path $t
        Assert-True (-not $r.Resolvida) "declarou raiz resolvida fora de repositorio nenhum"
        Assert-True ($r.Forma -eq 'fora-de-repo') `
            "a forma saiu '$($r.Forma)': 'fora-de-repo' e determinado e nao pode virar 'indeterminada'"
    } finally { Remove-RepoDoctor $t }
}

Test-Caso "raiz: repositorio BARE responde 'nao suportado', e nao quebra" {
    $t = Join-Path $env:TEMP ("db-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { git init -q --bare $t 2>$null } finally { $ErrorActionPreference = $anterior }
    try {
        Assert-True (Test-Path (Join-Path $t 'HEAD') -PathType Leaf) "PRE-CONDICAO: a fixture nao produziu repositorio bare"
        $r = Get-RaizDoRepositorio -Path $t
        Assert-True (-not $r.Resolvida) "declarou raiz resolvida num repositorio bare"
        Assert-True ($r.Forma -eq 'bare') "a forma saiu '$($r.Forma)' em vez de 'bare'"
        Assert-True ($r.Motivo -match '(?i)bare') "o motivo nao explica que a forma nao e suportada: '$($r.Motivo)'"
    } finally { Remove-RepoDoctor $t }
}

Test-Caso "raiz: git respondendo por GIT_DIR sobre OUTRO repositorio nao vira raiz" {
    # Todo hook do Git roda com GIT_DIR no ambiente. Sem a guarda, o doctor
    # diagnosticaria um repositorio e diria o nome de outro - e diria com
    # confianca, que e o pior modo de falha possivel num diagnostico.
    $outro = New-RepoDoctor
    $alvo = Join-Path $env:TEMP ("dg-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    try {
        New-Item -ItemType Directory -Path $alvo -Force | Out-Null
        $env:GIT_DIR = (Join-Path $outro '.git')
        try {
            $r = Get-RaizDoRepositorio -Path $alvo
            Assert-True (-not $r.Resolvida) `
                "aceitou como raiz um repositorio que NAO contem o caminho perguntado: '$($r.Raiz)'"
            Assert-True ($r.Forma -eq 'indeterminada') `
                "a forma saiu '$($r.Forma)': isto e 'nao consegui determinar', nao um fato sobre o caminho"
        } finally { Remove-Item Env:\GIT_DIR -ErrorAction SilentlyContinue }
    } finally {
        Remove-Item Env:\GIT_DIR -ErrorAction SilentlyContinue
        Remove-RepoDoctor $alvo; Remove-RepoDoctor $outro
    }
}

# =============================================================================
# AGREGACAO - a regra que impede 'nao verifiquei' de virar 'esta bom'
# =============================================================================

Test-Caso "agregacao: INCONCLUSIVO domina PASS, e o codigo de saida e 2" {
    $status = @('PASS', 'PASS', 'PASS', 'INCONCLUSIVO', 'PASS')
    Assert-True ((Get-PiorStatus -Status $status) -eq 'INCONCLUSIVO') `
        "uma dimensao inconclusiva no meio de tudo PASS tem de dominar"
    Assert-True ((Get-CodigoDeSaidaDoDoctor -Status 'INCONCLUSIVO') -eq 2) "INCONCLUSIVO tem de sair com 2"
    # O par: FAIL nao vira 2, e WARN nao vira 1. Sem estas duas, um mapeamento
    # que devolvesse 2 para tudo passaria na assercao de cima.
    Assert-True ((Get-PiorStatus -Status @('PASS', 'FAIL', 'WARN')) -eq 'FAIL') "FAIL tem de vencer WARN e PASS"
    Assert-True ((Get-CodigoDeSaidaDoDoctor -Status 'FAIL') -eq 1) "FAIL tem de sair com 1"
    Assert-True ((Get-CodigoDeSaidaDoDoctor -Status 'WARN') -eq 0) "WARN nao impede continuar: sai com 0"
}

Test-Caso "agregacao: agregar ZERO dimensoes LANCA, em vez de devolver PASS" {
    # Sem isto, um doctor que perdesse todas as dimensoes por um erro de
    # montagem sairia dizendo PASS - saude afirmada sobre nada, que e o falso
    # verde que esta plataforma passou treze rodadas fechando.
    $erro = ''
    try { $null = Get-PiorStatus -Status @() } catch { $erro = "$_" }
    Assert-True ($erro -match 'nenhuma dimensao') `
        "agregar lista vazia devia LANCAR. Erro recebido: '$erro'"
}

# =============================================================================
# FRESCOR - os quatro estados
# =============================================================================

Test-Caso "frescor: os QUATRO estados do artefato sao distinguidos" {
    $d = Join-Path $env:TEMP ("df-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $head = '1234567890abcdef1234567890abcdef12345678'

        $ausente = Join-Path $d 'nao-existe.md'
        Assert-True ((Get-EstadoDoArtefato -Caminho $ausente -HeadAtual $head).Estado -eq 'ausente') `
            "arquivo inexistente tinha de sair 'ausente'"

        $doHead = Join-Path $d 'do-head.md'
        [System.IO.File]::WriteAllText($doHead, "# r`n`n- HEAD: ``1234567``\n", (New-Object System.Text.UTF8Encoding($false)))
        Assert-True ((Get-EstadoDoArtefato -Caminho $doHead -HeadAtual $head).Estado -eq 'do-head') `
            "carimbo curto do MESMO commit tinha de sair 'do-head' - a comparacao e por prefixo"

        $outro = Join-Path $d 'outro.md'
        [System.IO.File]::WriteAllText($outro, "# r`n`n- Branch: ``main``  HEAD: ``deadbee``\n", (New-Object System.Text.UTF8Encoding($false)))
        Assert-True ((Get-EstadoDoArtefato -Caminho $outro -HeadAtual $head).Estado -eq 'de-outro-head') `
            "carimbo de outro commit tinha de sair 'de-outro-head'"

        $sem = Join-Path $d 'sem-carimbo.md'
        [System.IO.File]::WriteAllText($sem, "# relatorio sem carimbo nenhum`n", (New-Object System.Text.UTF8Encoding($false)))
        Assert-True ((Get-EstadoDoArtefato -Caminho $sem -HeadAtual $head).Estado -eq 'invalido') `
            "artefato SEM carimbo tinha de sair 'invalido': nao da para dizer que estado ele descreve"

        # E o que separa 'invalido' de 'ausente': os dois levam a status
        # diferentes, e colapsa-los faria 'nunca rodou' e 'rodou e nao da para
        # ler' virarem a mesma coisa.
        Assert-True ((Get-EstadoDoArtefato -Caminho $sem -HeadAtual $head).Estado -ne
                     (Get-EstadoDoArtefato -Caminho $ausente -HeadAtual $head).Estado) `
            "'invalido' e 'ausente' colapsaram no mesmo estado"
    } finally { Remove-RepoDoctor $d }
}

Test-Caso "frescor: artefato AUSENTE e WARN, e artefato INVALIDO e INCONCLUSIVO" {
    # A regra que a mantenedora fixou: WARN e 'determinei o fato e ele e
    # ruim'; INCONCLUSIVO e 'nao consegui determinar'. E 'nao existe evidencia
    # recente' NUNCA e PASS.
    $fx = New-RepoDoctor
    try {
        $semNada = Get-DiagnosticoFrescor -Raiz $fx -HeadAtual '1234567890abcdef1234567890abcdef12345678'
        Assert-True ($semNada.Status -eq 'WARN') `
            "repositorio sem evidencia nenhuma saiu '$($semNada.Status)': ausencia de evidencia nao e PASS, e tambem nao e 'nao consegui'"

        $dir = Join-Path $fx 'artifacts\review'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir 'security-report.md'), "# r`nsem carimbo`n", (New-Object System.Text.UTF8Encoding($false)))
        $comLixo = Get-DiagnosticoFrescor -Raiz $fx -HeadAtual '1234567890abcdef1234567890abcdef12345678'
        Assert-True ($comLixo.Status -eq 'INCONCLUSIVO') `
            "artefato existente e sem carimbo saiu '$($comLixo.Status)': isto e 'nao consegui determinar'"

        # O artefato invalido tem de aparecer NUM canal so. A verificacao saia
        # para TODO artefato, fora do switch, e o ramo 'invalido' emitia lacuna
        # sobre o MESMO artefato com outro rotulo - dois canais, mesmo fato. A
        # invariante do construtor compara igualdade e nao alcancava.
        # Achado do qa-reviewer na nona rodada.
        $lacunas = @($comLixo.NaoVerificado | ForEach-Object { "" + $_.O_que })
        $afirmados = @($comLixo.Verificacoes | ForEach-Object { "" + $_.O_que })
        $doInvalido = @($lacunas | Where-Object { $_ -match 'seguranca' })
        Assert-True ($doInvalido.Count -eq 1) `
            "esperava lacuna sobre a varredura de seguranca. Lacunas: '$($lacunas -join ' | ')'"
        Assert-True ($afirmados -notcontains $doInvalido[0]) `
            "o mesmo artefato aparece nos DOIS canais: '$($doInvalido[0])'"
        Assert-True (@($afirmados | Where-Object { $_ -match 'seguranca' }).Count -eq 0) `
            "o artefato invalido ainda e afirmado no canal de verificacao: '$($afirmados -join ' | ')'"

        # O par: o artefato AUSENTE - fato determinado - continua sendo
        # afirmado, com o estado como resultado. Sem esta metade, um frescor
        # que parasse de emitir verificacao passaria acima.
        $ausente = @($semNada.Verificacoes | Where-Object { ("" + $_.Resultado) -eq 'ausente' })
        Assert-True ($ausente.Count -ge 1) `
            "artefato ausente deixou de ser afirmado: '$(@($semNada.Verificacoes | ForEach-Object { $_.O_que + '=' + $_.Resultado }) -join ' | ')'"
    } finally { Remove-RepoDoctor $fx }
}

# =============================================================================
# AMBIENTE - dependencia condicional ao manifesto
# =============================================================================

Test-Caso "ambiente: campo AUSENTE e WARN - 'nao declarou' nao e 'nao tem'" {
    $m = Read-ManifestoDoDoctor -Caminho (Join-Path (New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`n") 'project.yaml')
    $d = Get-DiagnosticoAmbiente -Manifesto $m
    Assert-True ($d.Status -eq 'WARN') "campo ausente saiu '$($d.Status)' em vez de WARN"
    Assert-True ($d.Cobertura.CampoDeclarado -eq $false) "marcou o campo como declarado quando ele nao existe"
    # O relatorio tem de DIZER que nada foi verificado - e o canal certo para
    # isso e 'Verificacoes' com 'nao se aplica', nao 'NaoVerificado'. Campo
    # ausente e fato DETERMINADO, nao lacuna: era a unica lacuna do doctor
    # inteiro que nao derrubava para INCONCLUSIVO, e o processo saia 0 logo
    # abaixo do paragrafo que diz que lacuna faz sair com 2. Achado do
    # qa-reviewer na nona rodada; este caso fixava o canal errado.
    Assert-True (@($d.NaoVerificado).Count -eq 0) `
        "campo ausente declarou LACUNA: lacuna que nao domina e lacuna decorativa - $(@($d.NaoVerificado | ForEach-Object { $_.O_que }) -join ' | ')"
    $resultados = @($d.Verificacoes | ForEach-Object { "" + $_.Resultado })
    Assert-True (($resultados -join ' ') -match 'nao se aplica.*nao declarou') `
        "o relatorio nao diz que nada foi verificado: '$($resultados -join ' | ')'"
}

Test-Caso "ambiente: lista VAZIA e valido - declaracao explicita de que nao ha" {
    # O par do caso acima, e a diferenca entre os dois e o ponto inteiro do
    # desenho: '[]' e 'nao tenho'; ausente e 'nao pensei'.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias: []`n"
    try {
        $m = Read-ManifestoDoDoctor -Caminho (Join-Path $fx 'project.yaml')
        $d = Get-DiagnosticoAmbiente -Manifesto $m
        Assert-True ($d.Status -eq 'PASS') "'dependencias: []' saiu '$($d.Status)': declaracao explicita de ausencia e valida"
        Assert-True ($d.Cobertura.CampoDeclarado -eq $true) "nao marcou o campo como declarado"
        Assert-True ($d.Cobertura.Declaradas -eq 0) "contou dependencia onde a lista e vazia"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "ambiente: ferramenta NAO declarada e ausente nao gera diagnostico negativo" {
    # A regra da mantenedora, medida: um projeto que nao fala com o GitHub nao
    # pode ser diagnosticado por nao ter 'gh'. Detector que grita sobre o que
    # ninguem pediu e detector que se aprende a ignorar.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias:`n    - ferramenta: `"git`"`n      obrigatoria: true`n"
    try {
        $m = Read-ManifestoDoDoctor -Caminho (Join-Path $fx 'project.yaml')
        $d = Get-DiagnosticoAmbiente -Manifesto $m
        Assert-True ($d.Status -eq 'PASS') "saiu '$($d.Status)' num projeto cuja unica dependencia declarada existe"
        Assert-True ($d.Cobertura.Declaradas -eq 1) "contou $($d.Cobertura.Declaradas) declaracoes onde ha uma"
        $texto = (@($d.Achados | ForEach-Object { $_.Mensagem }) -join ' ')
        Assert-True ($texto -notmatch 'ferramenta-que-nao-existe') "acusou ferramenta que o projeto nao declara"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "ambiente: declarada OBRIGATORIA e ausente e FAIL; opcional e ausente e WARN" {
    $inexistente = 'ferramenta-inexistente-' + [guid]::NewGuid().ToString('N').Substring(0, 8)

    $fxF = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias:`n    - ferramenta: `"$inexistente`"`n      obrigatoria: true`n"
    try {
        $d = Get-DiagnosticoAmbiente -Manifesto (Read-ManifestoDoDoctor -Caminho (Join-Path $fxF 'project.yaml'))
        Assert-True ($d.Status -eq 'FAIL') "obrigatoria e ausente saiu '$($d.Status)' em vez de FAIL"
        Assert-True ($d.Cobertura.ObrigatoriasAusentes -eq 1) "nao contou a obrigatoria ausente"
    } finally { Remove-RepoDoctor $fxF }

    $fxW = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias:`n    - ferramenta: `"$inexistente`"`n      obrigatoria: false`n"
    try {
        $d = Get-DiagnosticoAmbiente -Manifesto (Read-ManifestoDoDoctor -Caminho (Join-Path $fxW 'project.yaml'))
        Assert-True ($d.Status -eq 'WARN') "opcional e ausente saiu '$($d.Status)' em vez de WARN"
        Assert-True ($d.Cobertura.ObrigatoriasAusentes -eq 0) "contou como obrigatoria uma dependencia opcional"
    } finally { Remove-RepoDoctor $fxW }
}


Test-Caso "ambiente: 'obrigatoria : true' com espaco antes do ':' NAO desarma a regra FAIL" {
    # O fail-open do ramo de LISTA, na regressao exata. O 'throw' da primeira
    # correcao foi posto so na chave de TOPO; dentro de um item de lista a
    # mesma regex ficou em 'if ($m.Success)' sem 'else', e a linha continuava
    # sumindo em silencio - no unico campo de lista que o doctor le.
    #
    # 'obrigatoria : true' e YAML valido, e o gemeo do template le. Com a
    # linha descartada, '$obrigatoria' ficava $false, 'ObrigatoriasAusentes'
    # ficava zero, a dimensao saia WARN e o doctor saia 0 no lugar de 1.
    # Achado do qa-reviewer na segunda rodada.
    $inexistente = 'ferramenta-inexistente-' + [guid]::NewGuid().ToString('N').Substring(0, 8)

    $fxF = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias:`n    - ferramenta: `"$inexistente`"`n      obrigatoria : true`n"
    try {
        $d = Get-DiagnosticoAmbiente -Manifesto (Read-ManifestoDoDoctor -Caminho (Join-Path $fxF 'project.yaml'))
        Assert-True ($d.Status -eq 'FAIL') `
            "com espaco antes do ':' a linha sumiu: saiu '$($d.Status)' em vez de FAIL, e a UNICA regra FAIL da dimensao ficou desarmada por uma linha que o YAML aceita"
        Assert-True ($d.Cobertura.ObrigatoriasAusentes -eq 1) `
            "contou $($d.Cobertura.ObrigatoriasAusentes) obrigatorias ausentes onde ha uma - sinal de que 'obrigatoria' nao foi lida"
    } finally { Remove-RepoDoctor $fxF }

    # O PAR que prova que o FAIL acima veio do VALOR lido, e nao de a dimensao
    # reprovar qualquer ferramenta ausente: mesma linha, mesmo espaco, valor
    # 'false'. Sem esta metade, um leitor que devolvesse sempre 'true' - ou
    # uma dimensao que reprovasse toda ausencia - passaria na metade de cima.
    $fxW = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias:`n    - ferramenta: `"$inexistente`"`n      obrigatoria : false`n"
    try {
        $d = Get-DiagnosticoAmbiente -Manifesto (Read-ManifestoDoDoctor -Caminho (Join-Path $fxW 'project.yaml'))
        Assert-True ($d.Status -eq 'WARN') "opcional com espaco antes do ':' saiu '$($d.Status)' em vez de WARN"
        Assert-True ($d.Cobertura.ObrigatoriasAusentes -eq 0) "leu 'false' como obrigatoria"
    } finally { Remove-RepoDoctor $fxW }
}

Test-Caso "manifesto: continuacao de item de lista que nao e 'chave: valor' LANCA" {
    # A outra metade do mesmo fail-open: linha indentada dentro do item que
    # nao e 'chave: valor'. Antes, descartada em silencio - e o doctor passava
    # a afirmar ausencia sobre um campo declarado.
    $dir = Join-Path $env:TEMP ("cl-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        $arq = Join-Path $dir 'project.yaml'
        [System.IO.File]::WriteAllText($arq, "ambiente:`n  dependencias:`n    - ferramenta: `"git`"`n      isto nao e chave valor`n", (New-Object System.Text.UTF8Encoding($false)))
        $erro = ''
        try { $null = Read-ManifestoDoDoctor -Caminho $arq } catch { $erro = "$_" }
        Assert-True ($erro -match 'dentro do item de lista') `
            "continuacao malformada foi descartada em silencio. Erro recebido: '$erro'"

        # O par: item de lista bem formado continua sendo lido, com as DUAS
        # chaves. Sem isto, um leitor que lancasse sempre passaria acima.
        [System.IO.File]::WriteAllText($arq, "ambiente:`n  dependencias:`n    - ferramenta: `"git`"`n      para: `"versionar`"`n", (New-Object System.Text.UTF8Encoding($false)))
        # Atribuir ANTES de '@()': 'Get-CampoDoProjeto' devolve com o operador
        # virgula para preservar lista vazia, e '@(chamada)' aninha o array
        # dentro de outro - '$lista[0]' vira Object[] e a assercao mede nada.
        $lista = Get-CampoDoProjeto -Raiz (Read-ManifestoDoDoctor -Caminho $arq) -Caminho 'ambiente.dependencias'
        $lista = @($lista)
        Assert-True ($lista.Count -eq 1 -and $lista[0]['ferramenta'] -eq 'git' -and $lista[0]['para'] -eq 'versionar') `
            "a regra estrita passou a recusar item de lista bem formado"

        # E o item ESCALAR continua legitimo: '- git' nao tem ':' e nao pode
        # lancar. E a razao de 'Split-LinhaDeChaveDoManifesto' devolver $null
        # em vez de lancar ela mesma - quem chama decide se $null e erro.
        [System.IO.File]::WriteAllText($arq, "ambiente:`n  dependencias:`n    - git`n    - gh`n", (New-Object System.Text.UTF8Encoding($false)))
        $lista = Get-CampoDoProjeto -Raiz (Read-ManifestoDoDoctor -Caminho $arq) -Caminho 'ambiente.dependencias'
        $lista = @($lista)
        Assert-True ($lista.Count -eq 2 -and ("" + $lista[0]) -eq 'git') `
            "lista de escalares deixou de ser lida: '$($lista -join ',')'"
    } finally { Remove-RepoDoctor $dir }
}

# =============================================================================
# MANIFESTO - e o gemeo que nao pode divergir
# =============================================================================

Test-Caso "manifesto: lista VAZIA sobrevive ao retorno e NAO vira campo ausente" {
    # A regressao no ponto exato em que o defeito morava: o leitor. No
    # PowerShell 'return @()' colapsa para $null no chamador, entao
    # 'dependencias: []' chegava a dimensao indistinguivel de campo AUSENTE - e
    # a diferenca entre os dois e a decisao de governanca desta subfase:
    # '[]' e "nao tenho dependencia verificavel"; ausente e "ainda nao
    # declarei". Um vale, o outro e WARN.
    #
    # Sem este caso, a correcao vive apenas num operador virgula que a proxima
    # pessoa remove sem perceber o que quebrou.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias: []`n  node: `"nao-usa`"`n"
    try {
        $m = Read-ManifestoDoDoctor -Caminho (Join-Path $fx 'project.yaml')

        $vazia = Get-CampoDoProjeto -Raiz $m -Caminho 'ambiente.dependencias' -Opcional
        Assert-True ($null -ne $vazia) `
            "lista vazia voltou como NULO: '[]' ficou indistinguivel de campo ausente, e a declaracao explicita da mantenedora foi apagada pelo retorno"
        Assert-True (@($vazia).Count -eq 0) "a lista vazia voltou com $(@($vazia).Count) item(ns)"

        # O par: campo REALMENTE ausente continua devolvendo nulo. Sem esta
        # metade, um leitor que devolvesse array vazio para tudo passaria.
        $ausente = Get-CampoDoProjeto -Raiz $m -Caminho 'ambiente.dependencias_que_nao_existem' -Opcional
        Assert-True ($null -eq $ausente) `
            "campo ausente devolveu algo diferente de nulo: ausente e '[]' voltariam a colapsar, agora pelo outro lado"

        # E a chave irma continua legivel: se a lista vazia tivesse engolido o
        # resto do bloco, este campo sumiria em silencio.
        Assert-True ((Get-CampoDoProjeto -Raiz $m -Caminho 'ambiente.node') -eq 'nao-usa') `
            "a chave irma depois da lista vazia nao foi lida: a lista engoliu o resto do bloco"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "manifesto: campo ausente com -Opcional devolve nulo; sem ele, LANCA" {
    $fx = New-RepoDoctor
    try {
        $m = Read-ManifestoDoDoctor -Caminho (Join-Path $fx 'project.yaml')
        Assert-True ($null -eq (Get-CampoDoProjeto -Raiz $m -Caminho 'nao.existe.nada' -Opcional)) `
            "-Opcional devia devolver nulo para campo ausente"
        $erro = ''
        try { $null = Get-CampoDoProjeto -Raiz $m -Caminho 'nao.existe.nada' } catch { $erro = "$_" }
        Assert-True ($erro -match 'nao declara') `
            "sem -Opcional, campo ausente tinha de LANCAR: padrao silencioso transforma 'nao declarou' em 'passou'. Erro: '$erro'"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "manifesto: o leitor do doctor NAO diverge do gemeo do template nos escalares NEM nas chaves" {
    # Terceira implementacao de leitor nesta plataforma, e as duas primeiras ja
    # divergiram oito vezes na 2.4. Este caso e o que impede a terceira de
    # repetir a historia - e a primeira versao dele NAO fazia isso: declarava
    # um scriptblock, descartava em '$null = $bloco', e afirmava num comentario
    # que o gemeo era "exercitado abaixo, por comparacao de VALOR". Abaixo nao
    # havia comparacao nenhuma. Verde sobre caminho nao exercitado, que e o
    # modo de falha mais caro que existe aqui. Achado do qa-reviewer.
    #
    # Agora o gemeo roda de verdade, em PROCESSO FILHO: o harness do template
    # define 'Test-Caso' e derrubaria a suite em execucao se fosse carregado
    # aqui dentro.
    $harnessTemplate = Join-Path $OsRoot 'templates\project-standard\tests\_harness.ps1'
    Assert-True (Test-Path $harnessTemplate -PathType Leaf) `
        "PRE-CONDICAO: o harness do template nao esta onde este caso espera - sem ele nao ha com quem comparar, e o caso passaria por vacuidade"

    # Manifesto sintetico com as formas que ja divergiram entre gemeos.
    #
    # VALOR: entre aspas com comentario alinhado, valor que e SO comentario, e
    # TAB antes do comentario.
    #
    # CHAVE: entre aspas, com espaco antes do ':', com ponto, e com acento. A
    # fixture anterior so tinha chaves '[a-z_]', e por isso a afirmacao do
    # cabecalho de 'doctor-manifesto.ps1' - "mesma resposta para todo campo" -
    # era mais larga do que o caso media. A divergencia estava viva exatamente
    # ali: o doctor LANCAVA onde o gemeo lia. Achado do qa-reviewer.
    $d = Join-Path $env:TEMP ("par-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        # Montada por codigo de proposito: .ps1 e ASCII puro nesta plataforma
        # (a suite rejeita byte > 127), e o acento tem de entrar por codigo.
        $acentuada = 'descri' + [char]0xE7 + [char]0xE3 + 'o'
        $yaml = "identidade:`n  `"nome`": `"fixture-paridade`"`n" +
                "  $acentuada`: `"com acento, que e pt-BR`"`n" +
                "classificacao:`n  criticidade : `"alta`"   # alinhado com varios espacos`n" +
                "verificacao:  # comentario na linha que ABRE o bloco`n" +
                "  comando: `".\tests\run-tests.ps1`"`n" +
                "  criterio_de_pronto:  # preencher depois`n" +
                "  aspa_escapada: 'o relatorio diz ''pronto'''`n" +
                "  tests: true`t# com TAB antes do comentario`n" +
                "chave.composta: com ponto`n"
        $arq = Join-Path $d 'project.yaml'
        [System.IO.File]::WriteAllText($arq, $yaml, (New-Object System.Text.UTF8Encoding($false)))

        # 'criterio_de_pronto' estava na fixture e FORA da comparacao: a forma
        # "valor que e so comentario" era medida de um lado so. E
        # 'aspa_escapada' e a quinta divergencia medida entre os leitores - em
        # YAML a aspa escapada e a DOBRADA, e o doctor devolvia o valor cortado
        # no meio dela enquanto o gemeo devolvia a frase inteira, sem erro e
        # sem lacuna. Achado do qa-reviewer na terceira rodada.
        $campos = @('identidade.nome', 'classificacao.criticidade', 'verificacao.comando',
                    'verificacao.criterio_de_pronto', 'verificacao.aspa_escapada', 'verificacao.tests')

        # --- o GEMEO, em processo filho ------------------------------------
        $script = @"
. '$harnessTemplate'
`$raiz = Read-ManifestoDoProjeto -Caminho '$arq'
`$r = @{}
foreach (`$c in @('$($campos -join "','")')) {
    `$atual = `$raiz
    `$ok = `$true
    foreach (`$parte in (`$c -split '\.')) {
        if (`$atual -isnot [System.Collections.Hashtable] -or -not `$atual.ContainsKey(`$parte)) { `$ok = `$false; break }
        `$atual = `$atual[`$parte]
    }
    if (-not `$ok) { `$r[`$c] = '<AUSENTE>' }
    elseif (`$atual -is [pscustomobject] -and `$atual.PSObject.Properties.Name -contains 'NaoLegivel') { `$r[`$c] = '<NAOLEGIVEL>' }
    elseif (`$atual -is [System.Collections.Hashtable]) { `$r[`$c] = '<BLOCO>' }
    else { `$r[`$c] = ('' + `$atual) }
}

# As duas chaves que nao dao para enderecar por caminho pontuado - o '.' e o
# separador -, perguntadas direto ao dicionario.
`$ac = 'descri' + [char]0xE7 + [char]0xE3 + 'o'
if (`$raiz.ContainsKey('chave.composta')) { `$r['chave_com_ponto'] = ('' + `$raiz['chave.composta']) } else { `$r['chave_com_ponto'] = '<AUSENTE>' }
if (`$raiz['identidade'] -is [System.Collections.Hashtable] -and `$raiz['identidade'].ContainsKey(`$ac)) { `$r['chave_acentuada'] = ('' + `$raiz['identidade'][`$ac]) } else { `$r['chave_acentuada'] = '<AUSENTE>' }
`$r.GetEnumerator() | ForEach-Object { `$_.Key + '=' + `$_.Value }
"@
        $arqScript = Join-Path $d 'gemeo.ps1'
        [System.IO.File]::WriteAllText($arqScript, $script, (New-Object System.Text.UTF8Encoding($false)))
        $saida = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $arqScript 2>&1)

        $doGemeo = @{}
        foreach ($l in $saida) {
            $mm = [regex]::Match(("" + $l), '^([a-z_.]+)=(.*)$')
            if ($mm.Success) { $doGemeo[$mm.Groups[1].Value] = $mm.Groups[2].Value }
        }
        # +2: as duas chaves perguntadas direto ao dicionario do gemeo.
        Assert-True ($doGemeo.Count -eq ($campos.Count + 2)) `
            "o gemeo do template NAO foi exercitado: esperava $($campos.Count + 2) campos, vieram $($doGemeo.Count). Saida: $($saida -join ' | ')"

        # --- o leitor do DOCTOR --------------------------------------------
        # Andar a ESTRUTURA, e nao chamar 'Get-CampoDoProjeto'. O acessor
        # aplica uma politica propria - campo declarado VAZIO nao conta como
        # declarado, que e um dos quatro defeitos que ele existe para nao
        # repetir - e o filho le o dicionario cru do gemeo. Comparar acessor
        # contra leitor acusava 'criterio_de_pronto' como divergencia sendo
        # que os dois LEITORES guardam a mesma string vazia: assimetria do
        # caso, nao do codigo. A afirmacao do cabecalho e sobre os LEITORES.
        $lerCru = {
            param($raiz, $caminho)
            $atual = $raiz
            foreach ($parte in ($caminho -split '\.')) {
                if ($atual -isnot [System.Collections.Hashtable] -or -not $atual.ContainsKey($parte)) { return '<AUSENTE>' }
                $atual = $atual[$parte]
            }
            if ($atual -is [pscustomobject] -and $atual.PSObject.Properties.Name -contains 'NaoLegivel') { return '<NAOLEGIVEL>' }
            if ($atual -is [System.Collections.Hashtable]) { return '<BLOCO>' }
            return ('' + $atual)
        }

        $meu = Read-ManifestoDoDoctor -Caminho $arq
        $divergentes = @()
        foreach ($c in $campos) {
            $vMeu = & $lerCru $meu $c
            if (("" + $vMeu) -ne $doGemeo[$c]) { $divergentes += ("$c : doctor='$vMeu' gemeo='$($doGemeo[$c])'") }
        }

        # E o par que impede o caso de ficar verde por os dois nao lerem nada:
        # os seis campos tem de ter vindo do gemeo com resposta, e pelo menos
        # um deles com valor NAO vazio.
        $comValor = @($campos | Where-Object { $doGemeo[$_] -and $doGemeo[$_] -ne '<AUSENTE>' })
        Assert-True ($comValor.Count -ge 4) `
            "o gemeo devolveu valor para so $($comValor.Count) dos $($campos.Count) campos - a comparacao estaria medindo ausencia contra ausencia"
        # As duas chaves nao enderecaveis por caminho, comparadas tambem.
        $comPonto = '<AUSENTE>'
        if ($meu.ContainsKey('chave.composta')) { $comPonto = ('' + $meu['chave.composta']) }
        if ($comPonto -ne $doGemeo['chave_com_ponto']) { $divergentes += ("chave.composta : doctor='$comPonto' gemeo='$($doGemeo['chave_com_ponto'])'") }

        $comAcento = '<AUSENTE>'
        if ($meu['identidade'] -is [System.Collections.Hashtable] -and $meu['identidade'].ContainsKey($acentuada)) {
            $comAcento = ('' + $meu['identidade'][$acentuada])
        }
        if ($comAcento -ne $doGemeo['chave_acentuada']) { $divergentes += ("chave acentuada : doctor='$comAcento' gemeo='$($doGemeo['chave_acentuada'])'") }

        Assert-True ($divergentes.Count -eq 0) `
            ("o leitor do doctor DIVERGE do gemeo do template: " + ($divergentes -join ' ; ') + ". Rigor diferente sobre o mesmo manifesto e o defeito que a 2.4 corrigiu oito vezes entre os dois primeiros")

        # E o par que impede o caso de passar por vacuidade: as duas chaves
        # nao podem estar AUSENTES dos dois lados. Sem isto, um leitor que
        # ignorasse ambas concordaria com o outro e o caso ficaria verde.
        Assert-True ($comPonto -eq 'com ponto' -and $comAcento -ne '<AUSENTE>') `
            "chave com ponto e chave acentuada tinham de ter sido LIDAS pelos dois: ponto='$comPonto' acento='$comAcento'. Concordar em nao ler nao e paridade"

        # E a diferenca DECLARADA continua sendo a unica: lista.
        $lista = Get-CampoDoProjeto -Raiz (Read-ManifestoDoDoctor -Caminho (Join-Path $OsRoot 'project.yaml')) -Caminho 'ambiente.dependencias'
        Assert-True (@($lista).Count -ge 1) `
            "o leitor do doctor tem de LER lista - e a unica diferenca permitida em relacao ao gemeo"
    } finally { Remove-RepoDoctor $d }
}

Test-Caso "manifesto: valor que e SO comentario NAO vira valor declarado" {
    # (a) das tres divergencias que o qa-reviewer achou com entrada concreta.
    # Sem esta regra, 'comando:  # preencher depois' era lido como o comando de
    # verificacao, e a dimensao manifesto saia PASS afirmando um criterio que
    # ninguem declarou - falsa garantia no campo que a 2.4 existiu para tornar
    # fonte de verdade.
    $d = Join-Path $env:TEMP ("cm-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $arq = Join-Path $d 'project.yaml'
        [System.IO.File]::WriteAllText($arq, "verificacao:`n  comando:  # preencher depois`n  outro: `"valor real`"`n", (New-Object System.Text.UTF8Encoding($false)))
        $m = Read-ManifestoDoDoctor -Caminho $arq
        $v = Get-CampoDoProjeto -Raiz $m -Caminho 'verificacao.comando' -Opcional
        Assert-True ([string]::IsNullOrWhiteSpace(("" + $v))) `
            "valor que e so comentario virou valor declarado: '$v'"
        # O par: o campo ao lado, com valor de verdade, continua sendo lido.
        Assert-True ((Get-CampoDoProjeto -Raiz $m -Caminho 'verificacao.outro') -eq 'valor real') `
            "a regra do comentario comeu o valor do campo irmao"
    } finally { Remove-RepoDoctor $d }
}

Test-Caso "manifesto: TAB antes do comentario nao gruda o comentario no valor" {
    # (b). Com o corte no literal ' #', 'tests: true<TAB># roda' era lido como
    # 'true<TAB># roda', 'DeclaraTests' virava falso, e a UNICA regra FAIL da
    # dimensao manifesto - declara tests sem pasta tests/ - deixava de
    # disparar. Fail-open no detector mais barato da subfase.
    $d = Join-Path $env:TEMP ("tb-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $arq = Join-Path $d 'project.yaml'
        [System.IO.File]::WriteAllText($arq, "verificacao:`n  tests: true`t# roda a suite`n", (New-Object System.Text.UTF8Encoding($false)))
        $m = Read-ManifestoDoDoctor -Caminho $arq
        Assert-True ((Get-CampoDoProjeto -Raiz $m -Caminho 'verificacao.tests') -eq 'true') `
            "TAB antes do comentario grudou o comentario no valor: '$(Get-CampoDoProjeto -Raiz $m -Caminho 'verificacao.tests')'"

        # E o efeito na dimensao: a regra FAIL tem de disparar.
        New-Item -ItemType Directory -Path (Join-Path $d 'docs') -Force | Out-Null
        $r = Get-DiagnosticoManifesto -Raiz $d
        Assert-True ($r.Dimensao.Cobertura.DeclaraTests) `
            "a dimensao nao reconheceu 'tests: true' com TAB antes do comentario - a regra FAIL ficaria desarmada"
    } finally { Remove-RepoDoctor $d }
}

Test-Caso "manifesto: linha irreconhecivel LANCA, em vez de sumir em silencio" {
    # (c). 'continue' descartava a linha, e o doctor passava a dizer "o
    # manifesto nao declara X" sobre um campo declarado. Em
    # 'ambiente.dependencias' isso colapsaria a distincao entre ausente e '[]'.
    $d = Join-Path $env:TEMP ("ln-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    try {
        $arq = Join-Path $d 'project.yaml'
        # 'cha ve: x' NAO serve aqui: e YAML que o gemeo do template LE, e
        # usar isso fixava em teste a divergencia de rigor entre os dois
        # leitores - o caso passava a PROTEGER o defeito. Achado do
        # qa-reviewer na segunda rodada. Linha sem ':' nenhum os dois recusam.
        [System.IO.File]::WriteAllText($arq, "ambiente:`n  isto nao e chave valor`n  dependencias: []`n", (New-Object System.Text.UTF8Encoding($false)))
        $erro = ''
        try { $null = Read-ManifestoDoDoctor -Caminho $arq } catch { $erro = "$_" }
        Assert-True ($erro -match "nao e 'chave: valor'") `
            "linha irreconhecivel foi descartada em silencio. Erro recebido: '$erro'"

        # O par: manifesto bem formado continua lendo sem lancar.
        [System.IO.File]::WriteAllText($arq, "ambiente:`n  chave: x`n  dependencias: []`n", (New-Object System.Text.UTF8Encoding($false)))
        $m = Read-ManifestoDoDoctor -Caminho $arq
        Assert-True ((Get-CampoDoProjeto -Raiz $m -Caminho 'ambiente.chave') -eq 'x') `
            "a regra estrita passou a recusar manifesto bem formado"
    } finally { Remove-RepoDoctor $d }
}

# =============================================================================
# FUNCIONAL - o doctor executado, e a fronteira com as outras duas ferramentas
# =============================================================================

Test-Caso "doctor: projeto sem defeito sai com 0 e o relatorio traz TODAS as dimensoes canonicas" {
    $fx = New-RepoDoctor
    try {
        $r = Invoke-Doctor $fx
        Assert-True ($r.Exit -eq 0) "esperava exit 0 num projeto sem defeito, veio $($r.Exit). Saida: $($r.Saida)"
        $rel = Get-RelDoctor $fx
        Assert-True ($null -ne $rel) "o doctor nao gravou relatorio"
        # A lista vem de Get-DimensoesDoDoctor, e nao escrita a mao aqui: o
        # titulo deste caso dizia "as SEIS dimensoes" e continuou dizendo
        # depois de a 2.6 acrescentar a setima. E o "numero em prosa que
        # envelhece" que esta mesma subfase afirmou ter fechado - sobrevivendo
        # dentro da suite. Achado do qa-reviewer.
        foreach ($d in @(Get-DimensoesDoDoctor)) {
            Assert-True ($rel -match ('\| ' + $d + ' \|')) "a dimensao '$d' nao aparece no relatorio"
        }
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: sem STATE.md o projeto nao e retomavel, e isso e FAIL com exit 1" {
    $fx = New-RepoDoctor -State $null
    try {
        $r = Invoke-Doctor $fx
        Assert-True ($r.Exit -eq 1) "esperava exit 1 sem STATE.md, veio $($r.Exit)"
        $rel = Get-RelDoctor $fx
        Assert-True ($rel -match 'nao existe docs/STATE\.md') "o relatorio nao diz que falta o STATE.md"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: manifesto ILEGIVEL sai com 2 - nao verificado nunca vira aprovado" {
    $fx = New-RepoDoctor
    try {
        [System.IO.File]::WriteAllBytes((Join-Path $fx 'project.yaml'), ([byte[]](0x6E, 0x6F, 0x6D, 0x65, 0x3A, 0x20, 0xE7, 0x0A)))
        $r = Invoke-Doctor $fx
        Assert-True ($r.Exit -eq 2) "manifesto ilegivel tinha de sair 2, veio $($r.Exit)"
        $rel = Get-RelDoctor $fx
        Assert-True ($rel -match '\| manifesto \| \*\*INCONCLUSIVO\*\*') "a dimensao manifesto nao saiu INCONCLUSIVO"
        Assert-True ($rel -notmatch '\| manifesto \| \*\*PASS\*\*') "declarou PASS sobre um manifesto que nao conseguiu ler"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: manifesto que declara tests sobre pasta inexistente e FAIL" {
    # 'declaracao nao e verificacao' e o principio que a 2.4 escreveu. Um
    # manifesto afirmando ter testes sobre uma pasta que nao existe e a forma
    # mais barata de mentir para quem chega.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nverificacao:`n  tests: true`nambiente:`n  dependencias: []`n"
    try {
        Assert-True (-not (Test-Path (Join-Path $fx 'tests'))) "PRE-CONDICAO: a fixture nao podia ter pasta tests/"
        $r = Invoke-Doctor $fx
        $rel = Get-RelDoctor $fx
        Assert-True ($rel -match 'declara .verificacao.tests: true. e nao existe pasta tests') `
            "o doctor nao acusou a declaracao contradita pelo disco"
        Assert-True ($r.Exit -eq 1) "esperava exit 1 com declaracao contradita, veio $($r.Exit)"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: NAO altera nada - a arvore e o .git ficam byte a byte identicos" {
    # O criterio de aceite que separa diagnostico de orquestrador, e o unico
    # que nenhuma outra suite pode provar por mim. Ferramenta que conserta
    # sozinha esconde o problema que deveria mostrar.
    $fx = New-RepoDoctor
    try {
        $antes = @{}
        foreach ($f in (Get-ChildItem $fx -Recurse -File -Force)) {
            $antes[$f.FullName] = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
        }
        Assert-True ($antes.Count -gt 5) `
            "PRE-CONDICAO: a fixture tem so $($antes.Count) arquivo(s) - pouco para a comparacao significar alguma coisa"

        $null = Invoke-Doctor $fx

        $mudados = @()
        $sumidos = @()
        foreach ($k in $antes.Keys) {
            if (-not (Test-Path -LiteralPath $k)) { $sumidos += $k; continue }
            if ((Get-FileHash -LiteralPath $k -Algorithm SHA256).Hash -ne $antes[$k]) { $mudados += $k }
        }
        Assert-True ($sumidos.Count -eq 0) ("o doctor APAGOU arquivo: " + ($sumidos -join ', '))
        Assert-True ($mudados.Count -eq 0) ("o doctor ALTEROU arquivo: " + ($mudados -join ', '))

        # O que ele criou tem de ser SO o proprio diagnostico.
        $novos = @(Get-ChildItem $fx -Recurse -File -Force | Where-Object { -not $antes.ContainsKey($_.FullName) })
        $foraDoDiagnostico = @($novos | Where-Object { $_.FullName -notmatch '\\artifacts\\doctor\\' })
        Assert-True ($foraDoDiagnostico.Count -eq 0) `
            ("o doctor criou arquivo fora do proprio diagnostico: " + (($foraDoDiagnostico | ForEach-Object { $_.Name }) -join ', '))
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: NAO roda a suite e NAO varre conteudo - a fronteira com as outras duas" {
    # Se o doctor rodasse a suite, viraria uma segunda suite: lenta, redundante
    # e falhando por motivo alheio ao diagnostico. Se varresse conteudo,
    # viraria um segundo /os:security - dois detectores divergindo em silencio.
    $marca = 'MARCA-QUE-A-SUITE-ESCREVERIA-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $fx = New-RepoDoctor
    try {
        # Uma suite que, SE executada, deixa rastro no disco.
        New-Item -ItemType Directory -Path (Join-Path $fx 'tests') -Force | Out-Null
        $prova = Join-Path $fx 'tests\prova.txt'
        $suite = "[System.IO.File]::WriteAllText('" + ($prova -replace '\\', '\\') + "', '$marca')`n"
        [System.IO.File]::WriteAllText((Join-Path $fx 'tests\run-tests.ps1'), $suite, (New-Object System.Text.UTF8Encoding($false)))

        # Um segredo em formato reconhecivel, que o /os:security acusaria -
        # montado em PARTES, e nao escrito literal.
        #
        # Nao e ofuscacao: literal aqui faria o scanner acusar ESTE arquivo
        # como ALTA (ele acusou, na primeira coleta), e o unico jeito de
        # calar seria declarar o marcador de fixture no cabecalho. Isso
        # alargaria para um TERCEIRO arquivo a superficie do backlog item 9 -
        # o marcador e a unica rota de rebaixamento que '-ParaPublicacao' nao
        # anula, e o security-reviewer contesta o tamanho dela ha quatro
        # rodadas. Montar em partes preserva a forca do caso (o arquivo em
        # disco TEM o padrao que o /os:security acusaria) sem pagar esse
        # preco.
        $token = 'ghp' + '_' + 'FABRICADOPARAODOCTOR' + '12'
        [System.IO.File]::WriteAllText((Join-Path $fx 'cfg.js'), "const t = '$token';`n", (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Doctor $fx
        Assert-True (-not (Test-Path $prova)) `
            "o doctor EXECUTOU o comando de verificacao do projeto: ele nao pode rodar a suite, e o rastro apareceu em $prova"
        $rel = Get-RelDoctor $fx
        Assert-True ($rel -notmatch ([regex]::Escape($token))) `
            "o doctor transcreveu conteudo de arquivo: ele nao varre conteudo, e transcrever valor de credencial e o que nem o scanner faz"
        Assert-True ($rel -notmatch '(?i)token do GitHub') `
            "o doctor acusou padrao de credencial: isso e /os:security, e duplicar significa dois detectores divergindo em silencio"
        Assert-True ($rel -match '(?i)nao roda a suite') `
            "o relatorio nao declara ao leitor que o doctor nao roda a suite"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: toda chave de Cobertura chega ao relatorio E ao JSON" {
    # Este caso substitui, para o doctor, o guarda generico de 'campo sem
    # leitor' de tests/suites/scripts.ps1 - e mede o FATO em vez da forma. La
    # a cobertura vira prosa campo a campo, entao acesso por membro e o proxy
    # certo; aqui ela e serializada inteira, e o que importa e chegar as duas
    # saidas. Contador que sobe e nao chega ao relatorio nao corrige nada.
    $fx = New-RepoDoctor
    try {
        $null = Invoke-Doctor $fx
        $rel = Get-RelDoctor $fx
        $json = Get-JsonDoctor $fx
        Assert-True ($null -ne $json) "o doctor nao gravou a saida estruturada"
        # A expectativa vem da lista CANONICA do codigo, e nao de um numero
        # escrito aqui. O numero repetido em teste e a forma que envelhece
        # sozinha: quando a 2.6 acrescentou a setima dimensao, um '-eq 6'
        # literal teria falhado sem dizer que a causa era uma dimensao NOVA e
        # legitima - e a correcao obvia seria trocar 6 por 7, que repete o
        # defeito na proxima.
        $canonicas = @(Get-DimensoesDoDoctor)
        Assert-True (@($json.dimensions).Count -eq @($canonicas).Count) `
            "esperava $(@($canonicas).Count) dimensoes no JSON, vieram $(@($json.dimensions).Count)"

        $semCobertura = @()
        $foraDoRelatorio = @()
        foreach ($d in $json.dimensions) {
            $chaves = @($d.cobertura.PSObject.Properties.Name)
            if ($chaves.Count -eq 0) { $semCobertura += $d.nome; continue }
            foreach ($k in $chaves) {
                if ($rel -notmatch ('\| ' + [regex]::Escape($d.nome) + ' \| ' + [regex]::Escape($k) + ' \|')) {
                    $foraDoRelatorio += ($d.nome + '.' + $k)
                }
            }
        }
        Assert-True ($semCobertura.Count -eq 0) ("dimensao sem nenhuma cobertura no JSON: " + ($semCobertura -join ', '))
        Assert-True ($foraDoRelatorio.Count -eq 0) ("campo de cobertura que nao chega ao relatorio humano: " + ($foraDoRelatorio -join ', '))
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: a saida estruturada declara schema_version e o codigo coerente" {
    # 'schema_version' e o que impede a primeira mudanca de formato de quebrar
    # em silencio quem ja estiver consumindo na Fase 3 ou 4.
    $fx = New-RepoDoctor
    try {
        $r = Invoke-Doctor $fx
        $json = Get-JsonDoctor $fx
        Assert-True ($json.schema_version -ge 1) "a saida estruturada nao declara schema_version"
        Assert-True ($json.exit_code -eq $r.Exit) `
            "o JSON diz exit_code $($json.exit_code) e o processo saiu com $($r.Exit): consumidor que confia no campo decidiria errado"
        Assert-True ($null -ne $json.coverage) "a saida estruturada nao traz 'coverage'"
        Assert-True ($null -ne $json.root) "a saida estruturada nao traz 'root'"
        Assert-True ($json.root.forma -eq 'normal') "a forma da raiz nao chegou ao JSON"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: fora de repositorio nao quebra, e o relatorio diz o motivo" {
    $t = Join-Path $env:TEMP ("dz-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    try {
        $r = Invoke-Doctor $t
        Assert-True ($r.Exit -eq 1) "fora de repositorio devia sair 1 (fato determinado), veio $($r.Exit)"
        Assert-True ($r.Saida -notmatch '(?i)nao conseguiu rodar') `
            "o doctor caiu no trap em vez de responder: 'nao ha repositorio aqui' e uma resposta, nao uma falha"
    } finally { Remove-RepoDoctor $t }
}


# =============================================================================
# O QUE A PRIMEIRA REVISAO MOSTROU QUE NAO ESTAVA MEDIDO
# =============================================================================

Test-Caso "git: repo com commit sai PASS; sem commit sai PASS com nota, nao defeito" {
    # 'Get-DiagnosticoGit' nao era chamado em ponto nenhum da suite - o
    # qa-reviewer apontou, e o ponto 3 do briefing pedia justamente "ausencia
    # de falso PASS quando o Git nao puder ser determinado".
    $fx = New-RepoDoctor
    try {
        $d = Get-DiagnosticoGit -Raiz $fx -Forma 'normal'
        Assert-True ($d.Status -eq 'PASS') "repo limpo com commit saiu '$($d.Status)'"
        Assert-True ($d.Cobertura.HeadResolve) "HEAD devia resolver"
        Assert-True (-not $d.Cobertura.RepoNovo) "marcou como repo novo um repositorio com commit"
    } finally { Remove-RepoDoctor $fx }

    $novo = New-RepoDoctor -SemCommit
    try {
        $d = Get-DiagnosticoGit -Raiz $novo -Forma 'normal'
        Assert-True ($d.Status -eq 'PASS') `
            "repositorio recem-inicializado saiu '$($d.Status)': HEAD nao nascido e o estado ESPERADO depois do /os:new-project, e um diagnostico que reprova o fluxo normal e um diagnostico que se desliga"
        Assert-True ($d.Cobertura.RepoNovo) "nao reconheceu o repositorio como recem-inicializado"
    } finally { Remove-RepoDoctor $novo }
}

Test-Caso "git: trabalho nao commitado e WARN, e nao PASS nem FAIL" {
    $fx = New-RepoDoctor
    try {
        [System.IO.File]::WriteAllText((Join-Path $fx 'novo.md'), "x`n", (New-Object System.Text.UTF8Encoding($false)))
        $d = Get-DiagnosticoGit -Raiz $fx -Forma 'normal'
        Assert-True ($d.Status -eq 'WARN') "trabalho nao commitado saiu '$($d.Status)'"
        Assert-True ($d.Cobertura.ArquivosModificados -ge 1) "nao contou o arquivo nao commitado"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "git: caminho que NAO e repositorio sai INCONCLUSIVO, nunca PASS" {
    # 'Nao consegui ler o Git' nao pode virar 'o Git esta bem'. Os predicados
    # LANCAM, e o throw tem de virar INCONCLUSIVO da dimensao - com a razao.
    $t = Join-Path $env:TEMP ("gn-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    try {
        $d = Get-DiagnosticoGit -Raiz $t -Forma 'normal'
        Assert-True ($d.Status -eq 'INCONCLUSIVO') `
            "caminho que nao e repositorio saiu '$($d.Status)': isso e 'nao consegui determinar'"
        Assert-True (@($d.NaoVerificado).Count -gt 0) "nao declarou a lacuna"
        Assert-True ((Get-PiorStatus -Status @('PASS','PASS',$d.Status)) -eq 'INCONCLUSIVO') `
            "a dimensao inconclusiva nao dominou a agregacao"
    } finally { Remove-RepoDoctor $t }
}

Test-Caso "retomabilidade: repositorio SEM COMMIT nao vira INCONCLUSIVO" {
    # O defeito que fazia o doctor sair com 2 sobre o estado exato do
    # /os:new-project. O 'git log' sai 128 em repo vazio, e a versao anterior
    # lia isso como falha de leitura. Perguntar ANTES se ha historico e o
    # conserto; este caso e o que impede a volta.
    $novo = New-RepoDoctor -SemCommit
    try {
        $d = Get-DiagnosticoRetomabilidade -Raiz $novo
        Assert-True ($d.Status -ne 'INCONCLUSIVO') `
            "repositorio recem-criado saiu INCONCLUSIVO e faria o doctor sair com 2 sobre um projeto que acabou de nascer. Motivo: $($d.Motivo)"
        Assert-True ($d.Cobertura.SemHistorico) "nao reconheceu a ausencia de historico"
        Assert-True (@($d.NaoVerificado | Where-Object { $_.Porque -match 'git log' }).Count -eq 0) `
            "declarou lacuna de 'git log' num repositorio que legitimamente nao tem commit"
    } finally { Remove-RepoDoctor $novo }
}

Test-Caso "retomabilidade: commits depois do ultimo que tocou o STATE viram WARN" {
    # A correcao do defeito de 'mtime' nao tinha caso: dava para voltar a
    # comparar data de modificacao sem nada ficar vermelho.
    $fx = New-RepoDoctor
    try {
        $d = Get-DiagnosticoRetomabilidade -Raiz $fx
        Assert-True (-not $d.Cobertura.StateDesatualizado) `
            "o par positivo falhou: o STATE acabou de ser commitado junto com tudo"

        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            [System.IO.File]::WriteAllText((Join-Path $fx 'outro.md'), "x`n", (New-Object System.Text.UTF8Encoding($false)))
            git -C $fx add -A 2>$null
            git -C $fx commit -q -m 'trabalho sem tocar o STATE' 2>$null
        } finally { $ErrorActionPreference = $anterior }

        $d2 = Get-DiagnosticoRetomabilidade -Raiz $fx
        Assert-True ($d2.Cobertura.StateDesatualizado) `
            "entrou um commit que nao tocou o STATE e o detector nao percebeu - ele voltaria a passar comparando mtime, que e falso positivo por construcao"
        Assert-True ($d2.Status -eq 'WARN') "o atraso do STATE saiu '$($d2.Status)'"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "ambiente: entrada sem 'ferramenta' vira lacuna, nao some da conta" {
    # 'NaoSondadas -> INCONCLUSIVO' nao tinha caso. Descartar a entrada em
    # silencio faria o total deixar de reconciliar com o que foi sondado.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias:`n    - para: `"algo`"`n"
    try {
        $m = Read-ManifestoDoDoctor -Caminho (Join-Path $fx 'project.yaml')
        $d = Get-DiagnosticoAmbiente -Manifesto $m
        Assert-True ($d.Status -eq 'INCONCLUSIVO') `
            "entrada sem 'ferramenta' saiu '$($d.Status)': nao da para sondar o que nao foi nomeado"
        Assert-True ($d.Cobertura.NaoSondadas -eq 1) "nao contou a entrada que nao deu para sondar"
        Assert-True ($d.Cobertura.Declaradas -eq 1) "a entrada sumiu do total: o numero deixa de reconciliar"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "doctor: fora de repositorio grava no caminho PERGUNTADO, nao no corrente" {
    # A suite escrevia no working tree da plataforma: com a raiz irresolvivel,
    # o destino caia em '(Get-Location)', e o 'doctor.json' canonico - o
    # contrato que a Fase 3/4 vai consumir - passava a descrever uma pasta
    # temporaria ja apagada. Evidencia falsa no lugar certo. Achado do
    # qa-reviewer, com o artefato no disco como prova.
    $t = Join-Path $env:TEMP ("fp-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $t -Force | Out-Null
    $naPlataforma = Join-Path $OsRoot 'artifacts\doctor\doctor-report.md'
    $antes = (Test-Path $naPlataforma)
    try {
        $r = Invoke-Doctor $t
        Assert-True ($r.Exit -eq 1) "fora de repositorio devia sair 1, veio $($r.Exit)"
        Assert-True (Test-Path (Join-Path $t 'artifacts\doctor\doctor-report.md')) `
            "o diagnostico nao foi gravado no caminho perguntado"
        Assert-True ((Test-Path $naPlataforma) -eq $antes) `
            "o doctor gravou no working tree da PLATAFORMA ao diagnosticar outra pasta"
    } finally { Remove-RepoDoctor $t }
}

Test-Caso "raiz: GIT_DIR de OUTRO repo com CWD numa raiz valida nao passa" {
    # O estado que sobrava depois da primeira guarda, achado pelo
    # security-reviewer: com GIT_DIR apontando para A e o caminho sendo a raiz
    # de B, 'show-toplevel' devolve B, B TEM '.git', e a guarda por existencia
    # passava. Como Invoke-Git herda o ambiente, o diagnostico sairia com a
    # RAIZ de B e o HEAD, o status e o log de A - com status PASS.
    $a = New-RepoDoctor
    $b = New-RepoDoctor
    try {
        $env:GIT_DIR = (Join-Path $a '.git')
        try {
            $r = Get-RaizDoRepositorio -Path $b
            Assert-True (-not $r.Resolvida) `
                "aceitou a raiz de B enquanto o git responde sobre A: o diagnostico sairia com a raiz de um e o historico de outro, com status PASS"
            Assert-True ($r.Forma -eq 'indeterminada') "a forma saiu '$($r.Forma)'"
            Assert-True ($r.Motivo -match '(?i)outro repositorio') "o motivo nao nomeia a causa: '$($r.Motivo)'"
        } finally { Remove-Item Env:\GIT_DIR -ErrorAction SilentlyContinue }

        # O par: SEM GIT_DIR, a mesma raiz resolve normalmente.
        $r2 = Get-RaizDoRepositorio -Path $b
        Assert-True $r2.Resolvida "sem GIT_DIR a raiz devia resolver - a guarda passou a recusar repositorio legitimo"
    } finally {
        Remove-Item Env:\GIT_DIR -ErrorAction SilentlyContinue
        Remove-RepoDoctor $a; Remove-RepoDoctor $b
    }
}

Test-Caso "doctor: ref QUEBRADA nao mata o diagnostico - a dimensao vira INCONCLUSIVO e o artefato SAI" {
    # O UNICO caminho em que o doctor saia sem produzir diagnostico nenhum.
    # 'Test-TemHistorico' estava FORA de try/catch em doctor-retomabilidade;
    # com ref quebrada o predicado lanca - de proposito, e ha caso proprio
    # disso em scanner.ps1 -, a excecao subia ate o 'trap' de doctor.ps1, e o
    # processo saia 2 SEM GRAVAR nem 'doctor-report.md' nem 'doctor.json'.
    # A dimensao 'git' ja tratava o mesmo predicado e devolvia INCONCLUSIVO
    # nomeando a causa. Contra o proprio desenho: "dimensao que nao conseguiu
    # rodar vira INCONCLUSIVO, e o relatorio sai mesmo assim".
    # Achado do qa-reviewer na segunda rodada.
    $fx = New-RepoDoctor
    try {
        $dirRefs = Join-Path $fx '.git\refs\heads'
        New-Item -ItemType Directory -Path $dirRefs -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dirRefs 'fantasma'), ('a' * 40) + "`n")

        $r = Invoke-Doctor $fx
        Assert-True ($r.Exit -eq 2) "ref quebrada tinha de sair 2 - INCONCLUSIVO domina -, saiu $($r.Exit)"

        # O que o achado realmente media era o ARTEFATO. Sem as duas
        # assercoes abaixo o caso ficaria verde com o doctor morrendo no trap,
        # porque o codigo de saida 2 e o MESMO nos dois mundos.
        $rel = Get-RelDoctor $fx
        Assert-True ($null -ne $rel) `
            "o doctor saiu sem gravar o doctor-report.md: o diagnostico inteiro morreu no trap, e exit 2 sozinho nao distingue isso de 'medi e nao consegui concluir'"
        $json = Get-JsonDoctor $fx
        Assert-True ($null -ne $json) "o doctor saiu sem gravar o doctor.json: o contrato de maquina nao foi produzido"
        Assert-True ($json.exit_code -eq 2) "o JSON registrou exit_code $($json.exit_code)"

        $dim = @($json.dimensions | Where-Object { $_.nome -eq 'retomabilidade' })
        Assert-True ($dim.Count -eq 1) "o JSON nao traz a dimensao retomabilidade"
        Assert-True ($dim[0].status -eq 'INCONCLUSIVO') `
            "a dimensao retomabilidade saiu '$($dim[0].status)' em vez de INCONCLUSIVO"
        Assert-True ($rel -match '(?i)historico') `
            "o relatorio nao nomeia a causa: 'nao verifiquei' sem motivo e indistinguivel de 'esta bom'"

        # O par que impede vacuidade: o MESMO repositorio, sem a ref quebrada,
        # volta a sair 0. Sem esta metade, uma fixture quebrada por outro
        # motivo qualquer daria o mesmo verde.
        Remove-Item (Join-Path $dirRefs 'fantasma') -Force
        $r2 = Invoke-Doctor $fx
        Assert-True ($r2.Exit -eq 0) "sem a ref quebrada o mesmo repositorio tinha de sair 0, saiu $($r2.Exit)"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "manifesto: comentario na linha que ABRE o bloco nao joga o bloco na raiz" {
    # As decisoes ESTRUTURAIS - 'chave:' sem valor abre bloco, '[]', '{}',
    # escalar de bloco - eram tomadas sobre o valor CRU, e o comentario so era
    # cortado depois. O gemeo normaliza ANTES.
    #
    # Com 'verificacao:  # o que este projeto verifica', o valor nao era vazio,
    # o ramo do bloco nao rodava, 'verificacao' virava STRING, e as linhas
    # indentadas seguintes reancoravam na RAIZ. Resultado medido: 'tests' e
    # 'comando' nasciam na raiz, 'DeclaraTests' ficava falso, e a UNICA regra
    # FAIL da dimensao manifesto ficava desarmada - exit 0, sem erro e sem
    # lacuna. Achado do qa-reviewer na quarta rodada.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nverificacao:  # o que este projeto verifica`n  tests: true`n  comando: `".\tests\run-tests.ps1`"`n"
    try {
        $m = Read-ManifestoDoDoctor -Caminho (Join-Path $fx 'project.yaml')

        Assert-True ($m['verificacao'] -is [System.Collections.Hashtable]) `
            "'verificacao' saiu como $($m['verificacao'].GetType().Name) em vez de bloco: o comentario na linha de cabecalho derrubou o bloco inteiro"
        Assert-True (-not $m.ContainsKey('tests')) `
            "'tests' nasceu na RAIZ: as linhas indentadas reancoraram no lugar errado"
        Assert-True ((Get-CampoDoProjeto -Raiz $m -Caminho 'verificacao.tests') -eq 'true') `
            "'verificacao.tests' nao foi lido"

        # O efeito que importa: a UNICA regra FAIL da dimensao tem de disparar.
        # 'New-RepoDoctor' nao cria 'tests/', entao 'tests: true' e declaracao
        # sobre pasta que nao existe.
        $r = Get-DiagnosticoManifesto -Raiz $fx
        Assert-True ($r.Dimensao.Cobertura.DeclaraTests) `
            "a dimensao nao reconheceu 'tests: true' - a regra FAIL ficaria desarmada por um comentario"
        Assert-True ($r.Dimensao.Status -eq 'FAIL') `
            "declara tests sobre pasta inexistente saiu '$($r.Dimensao.Status)' em vez de FAIL"
    } finally { Remove-RepoDoctor $fx }

    # O par: o MESMO manifesto com a pasta tests/ no lugar sai PASS. Sem esta
    # metade, uma dimensao que reprovasse tudo passaria na metade de cima.
    $fx2 = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nverificacao:  # comentario`n  tests: true`n"
    try {
        New-Item -ItemType Directory -Path (Join-Path $fx2 'tests') -Force | Out-Null
        $r2 = Get-DiagnosticoManifesto -Raiz $fx2
        Assert-True ($r2.Dimensao.Status -ne 'FAIL') `
            "com a pasta tests/ presente a dimensao ainda saiu FAIL: a regra esta disparando por outro motivo"
    } finally { Remove-RepoDoctor $fx2 }
}

Test-Caso "ambiente: '[] # comentario' continua sendo lista VAZIA, e nao dependencia fantasma" {
    # Mesma causa raiz, no outro ramo estrutural. '[]   # nenhuma por enquanto'
    # nao casava o teste de lista vazia, virava a STRING de dois colchetes, e
    # o doctor passava a sondar no PATH uma ferramenta com esse nome:
    # 'Declaradas = 1', 'NaoSondadas = 1',
    # dimensao INCONCLUSIVO, doctor exit 2 sobre projeto SAUDAVEL.
    #
    # E o idioma e o que o proprio template publica em
    # 'templates/project-standard/project.yaml'. Contra a decisao de governanca
    # de 2026-09-18: '[]' e declaracao explicita valida, nao WARN e nao defeito.
    # Achado do qa-reviewer na quarta rodada.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  dependencias: []   # nenhuma por enquanto`n"
    try {
        $m = Read-ManifestoDoDoctor -Caminho (Join-Path $fx 'project.yaml')
        $dep = Get-CampoDoProjeto -Raiz $m -Caminho 'ambiente.dependencias' -Opcional
        Assert-True ($null -ne $dep) "'[] # comentario' voltou NULO: virou campo ausente"
        Assert-True (@($dep).Count -eq 0) `
            "'[] # comentario' voltou com $(@($dep).Count) item(ns) - a string '[]' virou dependencia fantasma"

        $d = Get-DiagnosticoAmbiente -Manifesto $m
        Assert-True ($d.Status -eq 'PASS') "saiu '$($d.Status)': declaracao explicita de ausencia e valida"
        Assert-True ($d.Cobertura.Declaradas -eq 0) "contou $($d.Cobertura.Declaradas) dependencia(s) onde a lista e vazia"
        Assert-True ($d.Cobertura.NaoSondadas -eq 0) "$($d.Cobertura.NaoSondadas) entrada(s) nao sondada(s) - a string virou ferramenta"
    } finally { Remove-RepoDoctor $fx }

    # O par que preserva a decisao de governanca: campo AUSENTE continua WARN.
    # Sem ele, um leitor que devolvesse lista vazia para tudo passaria acima.
    $fx2 = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nambiente:`n  node: `"nao-usa`"`n"
    try {
        $d2 = Get-DiagnosticoAmbiente -Manifesto (Read-ManifestoDoDoctor -Caminho (Join-Path $fx2 'project.yaml'))
        Assert-True ($d2.Status -eq 'WARN') "campo AUSENTE saiu '$($d2.Status)' em vez de WARN"
        Assert-True (-not $d2.Cobertura.CampoDeclarado) "campo ausente ficou marcado como declarado"
    } finally { Remove-RepoDoctor $fx2 }
}

Test-Caso "manifesto: valor de tests que nao e true nem false vira LACUNA, e nao silencio" {
    # 'tests: true# nota' - o '#' colado, sem espaco antes. Em YAML isso NAO
    # abre comentario, entao o valor e mesmo 'true# nota': os dois leitores
    # concordam e os dois estao certos. O defeito era desta dimensao, que
    # tratava qualquer valor nao reconhecido como "nao declarou" e saia em
    # SILENCIO - a UNICA regra FAIL simplesmente nao disparava, sem ninguem
    # dizer por que. "Nao verifiquei" virando "esta bom", contra a politica 4.5.
    # Contestacao de severidade do security-reviewer na quinta rodada.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nverificacao:`n  tests: true# nota interna`n"
    try {
        $r = Get-DiagnosticoManifesto -Raiz $fx
        $lacunas = @($r.Dimensao.NaoVerificado | ForEach-Object { "" + $_.Porque })
        Assert-True (($lacunas -join ' ') -match "nao e 'true' nem 'false'") `
            "valor nao reconhecido saiu em silencio. Lacunas: '$($lacunas -join ' | ')'"
        Assert-True ($r.Dimensao.Status -eq 'INCONCLUSIVO') `
            "com lacuna declarada a dimensao saiu '$($r.Dimensao.Status)': lacuna que nao muda o status e lacuna decorativa"
    } finally { Remove-RepoDoctor $fx }

    # Os DOIS pares: 'true' e 'false' bem formados NAO produzem lacuna. Sem
    # eles, uma regra que reclamasse de qualquer valor passaria acima.
    foreach ($v in @('true', 'false')) {
        $fx2 = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nverificacao:`n  tests: $v`n"
        try {
            New-Item -ItemType Directory -Path (Join-Path $fx2 'tests') -Force | Out-Null
            $r2 = Get-DiagnosticoManifesto -Raiz $fx2
            $l2 = @($r2.Dimensao.NaoVerificado | ForEach-Object { "" + $_.Porque })
            Assert-True (($l2 -join ' ') -notmatch "nao e 'true' nem 'false'") `
                "'tests: $v' produziu lacuna de valor nao reconhecido"
        } finally { Remove-RepoDoctor $fx2 }
    }
}

Test-Caso "manifesto: placeholder de instanciacao vira LACUNA, e nao 'o manifesto nao declara'" {
    # O estado exato de um projeto copiado do template pelo /os:new-project e
    # nao terminado. 'Get-CampoDoProjeto' LANCA nesse caso, de proposito - e os
    # dois consumidores da dimensao engoliam a excecao com 'catch { $v = $null }'.
    #
    # Efeito medido: o campo virava "ausente", a dimensao dizia "o manifesto nao
    # declara 'identidade.nome'" sobre um campo que ESTA declarado, 'DeclaraTests'
    # ficava falso, a UNICA regra FAIL nao disparava, e tudo saia WARN/exit 0.
    # Afirmacao falsa somada a fail-open. Nenhum caso exercitava este ramo em
    # dimensao nenhuma. Achado do qa-reviewer na sexta rodada.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"{{NOME}}`"`nverificacao:`n  tests: {{TEM_TESTS}}`n"
    try {
        $r = Get-DiagnosticoManifesto -Raiz $fx
        $lacunas = @($r.Dimensao.NaoVerificado | ForEach-Object { "" + $_.Porque })
        Assert-True (($lacunas -join ' ') -match '(?i)placeholder') `
            "placeholder foi engolido em silencio. Lacunas: '$($lacunas -join ' | ')'"
        Assert-True ($r.Dimensao.Status -eq 'INCONCLUSIVO') `
            "com placeholder a dimensao saiu '$($r.Dimensao.Status)': 'nao verifiquei' virou 'esta bom'"

        # E a afirmacao FALSA tem de ter sumido: o campo esta declarado.
        $mensagens = @($r.Dimensao.Achados | ForEach-Object { "" + $_.Mensagem })
        Assert-True (($mensagens -join ' ') -notmatch "nao declara 'identidade.nome'") `
            "a dimensao ainda afirma que o manifesto nao declara um campo que ele DECLARA: '$($mensagens -join ' | ')'"
    } finally { Remove-RepoDoctor $fx }

    # O SEGUNDO sitio, isolado: tudo instanciado MENOS 'verificacao.tests'.
    # Sem este bloco, reverter so o 'catch' do 'tests' deixaria o caso verde -
    # a lacuna do laco acima sustentaria o INCONCLUSIVO sozinha, e a regra FAIL
    # ficaria desarmada sem ninguem perceber. Os dois sitios tem de ser medidos
    # separadamente, porque foi assim que o defeito sobreviveu: um endurecido,
    # o vizinho aberto.
    $fxT = New-RepoDoctor -Manifesto "identidade:`n  nome: `"projeto-real`"`nclassificacao:`n  criticidade: `"media`"`nverificacao:`n  comando: `".\tests\run-tests.ps1`"`n  tests: {{TEM_TESTS}}`n"
    try {
        $rT = Get-DiagnosticoManifesto -Raiz $fxT
        $lT = @($rT.Dimensao.NaoVerificado | ForEach-Object { "" + $_.Porque })
        Assert-True (($lT -join ' ') -match "(?i)placeholder.*verificacao\.tests|verificacao\.tests.*(?i)placeholder") `
            "placeholder em 'verificacao.tests' foi engolido: com os outros campos instanciados, NENHUMA lacuna o nomeia. Lacunas: '$($lT -join ' | ')'"
        Assert-True ($rT.Dimensao.Status -eq 'INCONCLUSIVO') `
            "placeholder so em 'verificacao.tests' saiu '$($rT.Dimensao.Status)': a UNICA regra FAIL ficaria desarmada em silencio"
    } finally { Remove-RepoDoctor $fxT }

    # O par: o MESMO manifesto instanciado nao produz lacuna de placeholder, e a
    # regra FAIL volta a disparar sobre pasta tests/ inexistente. Sem esta
    # metade, uma dimensao que saisse INCONCLUSIVO sempre passaria acima.
    $fx2 = New-RepoDoctor -Manifesto "identidade:`n  nome: `"projeto-real`"`nclassificacao:`n  criticidade: `"media`"`nverificacao:`n  comando: `".\tests\run-tests.ps1`"`n  tests: true`n"
    try {
        $r2 = Get-DiagnosticoManifesto -Raiz $fx2
        $l2 = @($r2.Dimensao.NaoVerificado | ForEach-Object { "" + $_.Porque })
        Assert-True (($l2 -join ' ') -notmatch '(?i)placeholder') `
            "manifesto instanciado produziu lacuna de placeholder: '$($l2 -join ' | ')'"
        Assert-True ($r2.Dimensao.Status -eq 'FAIL') `
            "manifesto instanciado que declara tests sem pasta tests/ saiu '$($r2.Dimensao.Status)' em vez de FAIL"
    } finally { Remove-RepoDoctor $fx2 }
}

Test-Caso "dimensao: o MESMO 'O_que' nos dois canais LANCA - o artefato nao afirma e nega o mesmo fato" {
    # A invariante vive no construtor, e nao nos sitios, de proposito. O defeito
    # apareceu em 'manifesto' e em 'retomabilidade' ao mesmo tempo, porque cada
    # dimensao decidia sozinha - e quatro vezes nesta subfase um endurecimento
    # deixou o ramo vizinho aberto. Com a guarda aqui, dimensao nova nasce
    # coberta sem ninguem precisar lembrar. Achado do qa-reviewer na setima
    # rodada, com a forma do conserto sugerida por ele.
    $v = New-VerificacaoDoDoctor -O_que 'a mesma pergunta' -Resultado 'True'
    $n = New-NaoVerificadoDoDoctor -O_que 'a mesma pergunta' -Porque 'nao deu para medir'

    $erro = ''
    try {
        $null = New-DimensaoDoDoctor -Nome 'fixture' -Status 'INCONCLUSIVO' -Verificacoes @($v) -NaoVerificado @($n)
    } catch { $erro = "$_" }
    Assert-True ($erro -match 'afirma ter verificado o que ela mesma declara NAO ter verificado') `
        "a dimensao aceitou o mesmo 'O_que' nos dois canais. Erro recebido: '$erro'"

    # O par: rotulos DIFERENTES continuam passando. Sem esta metade, uma guarda
    # que recusasse qualquer 'NaoVerificado' passaria acima.
    $n2 = New-NaoVerificadoDoDoctor -O_que 'outra pergunta' -Porque 'nao deu para medir'
    $d = New-DimensaoDoDoctor -Nome 'fixture' -Status 'INCONCLUSIVO' -Verificacoes @($v) -NaoVerificado @($n2)
    Assert-True (@($d.Verificacoes).Count -eq 1 -and @($d.NaoVerificado).Count -eq 1) `
        "a guarda passou a recusar dimensao legitima com canais disjuntos"
}

Test-Caso "doctor: NENHUMA dimensao afirma e nega o mesmo fato, num repo que produz lacuna de verdade" {
    # O caso acima prova a guarda; este prova que as dimensoes REAIS a respeitam
    # sobre uma fixture que gera lacuna em duas delas ao mesmo tempo -
    # placeholder no manifesto e ref quebrada na retomabilidade. Sem este, a
    # invariante ficaria provada so em fixture sintetica.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"{{NOME}}`"`nverificacao:`n  tests: {{TEM_TESTS}}`n"
    try {
        $dirRefs = Join-Path $fx '.git\refs\heads'
        New-Item -ItemType Directory -Path $dirRefs -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dirRefs 'fantasma'), ('a' * 40) + "`n")

        $r = Invoke-Doctor $fx
        Assert-True ($r.Exit -eq 2) "esperava exit 2 com lacuna em duas dimensoes, saiu $($r.Exit)"

        $json = Get-JsonDoctor $fx
        Assert-True ($null -ne $json) "o doctor nao gravou o doctor.json"

        # As lacunas NAO vivem dentro de 'dimensions[]': vivem no topo, em
        # 'coverage.nao_verificado', ao lado de 'coverage.verificado', e cada
        # entrada carrega o nome da dimensao. A primeira versao deste caso
        # cruzava '$dim.nao_verificado', que e SEMPRE nulo - passava por
        # vacuidade, e a mutacao mostrou isso: reverter a emissao incondicional
        # matava so o caso sintetico, e este ficava verde. Assercao ancorada no
        # lugar errado aceita qualquer coisa que se pareca com a resposta certa.
        $lacunas = @($json.coverage.nao_verificado)
        $verificados = @($json.coverage.verificado)

        # PRE-CONDICAO contra vacuidade, agora medindo o que existe: tem de
        # haver lacuna em pelo menos duas dimensoes, e verificacao registrada.
        $dimsComLacuna = @($lacunas | ForEach-Object { "" + $_.dimensao } | Select-Object -Unique)
        Assert-True ($dimsComLacuna.Count -ge 2) `
            "a fixture produziu lacuna em $($dimsComLacuna.Count) dimensao(oes) ($($dimsComLacuna -join ', ')): o cruzamento abaixo mediria nada"
        Assert-True ($verificados.Count -gt 0) `
            "nenhuma verificacao foi registrada: o cruzamento abaixo mediria nada"

        $conflitos = @()
        foreach ($nv in $lacunas) {
            foreach ($v in $verificados) {
                if ((("" + $v.dimensao) -eq ("" + $nv.dimensao)) -and (("" + $v.o_que) -eq ("" + $nv.o_que))) {
                    $conflitos += (("" + $nv.dimensao) + ': ' + ("" + $nv.o_que))
                }
            }
        }
        Assert-True ($conflitos.Count -eq 0) `
            ("o doctor.json afirma e nega o mesmo fato em: " + ($conflitos -join ' ; ') + ". O contrato de maquina da Fase 3/4 nao pode sair assim")
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "retomabilidade: HEAD nao nascido sobre refs que EXISTEM vira lacuna, e nao afirmacao contraria" {
    # O ramo que nenhum caso exercitava, e que fez a contradicao sobreviver a
    # quinta vez. 'git checkout --orphan' deixa o HEAD nao nascido enquanto
    # 'refs/heads/main' segue com commits: 'rev-list --all' diz que HA
    # historico, e o 'git log -1' sai 128. Antes, este ramo emitia lacuna com
    # um rotulo DIFERENTE do da verificacao, escapava da guarda que comparava
    # string, e o doctor.json saia afirmando 'STATE atualizado no ultimo
    # commit = True' no mesmo arquivo em que dizia nao ter medido.
    #
    # O estado nao e exotico: e o mesmo 'fetch-only' que doctor-git.ps1 trata
    # como primeira classe. Achado do qa-reviewer na oitava rodada.
    $fx = New-RepoDoctor
    try {
        # PRE-CONDICAO que o caso mede em vez de supor: a fixture tem de
        # produzir MESMO o estado descrito - ref no disco e 'git log' falhando.
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { git -C $fx checkout -q --orphan orfa 2>$null } finally { $ErrorActionPreference = $anterior }

        $refs = @(Get-ChildItem (Join-Path $fx '.git\refs\heads') -File -ErrorAction SilentlyContinue)
        Assert-True ($refs.Count -ge 1) "a fixture nao deixou ref nenhuma em refs/heads: o estado do achado nao foi reproduzido"

        $r = Get-DiagnosticoRetomabilidade -Raiz $fx
        $lacunas = @($r.NaoVerificado | ForEach-Object { "" + $_.O_que })
        Assert-True ($lacunas -contains 'STATE atualizado no ultimo commit') `
            "esperava lacuna sobre o STATE atualizado. Lacunas: '$($lacunas -join ' | ')'"

        # O RAMO, e nao so o rotulo: o ramo vizinho ('Test-TemHistorico'
        # lancando) emite lacuna com o MESMO rotulo, e uma lacuna vinda de la
        # satisfaria as assercoes com o ramo alvo intocado. Achado do
        # qa-reviewer na nona rodada.
        $porques = @($r.NaoVerificado | ForEach-Object { "" + $_.Porque })
        Assert-True (($porques -join ' ') -match "o 'git log' nao respondeu num repositorio que TEM historico") `
            "a lacuna veio de outro ramo: '$($porques -join ' | ')'"
        Assert-True ($r.Status -eq 'INCONCLUSIVO') `
            "a dimensao saiu '$($r.Status)': 'nao verifiquei' virou outra coisa"

        # O que o achado realmente media: a AUSENCIA da afirmacao contraria.
        $afirmados = @($r.Verificacoes | ForEach-Object { "" + $_.O_que })
        Assert-True ($afirmados -notcontains 'STATE atualizado no ultimo commit') `
            "a dimensao declarou lacuna e AFIRMOU o mesmo fato: '$($afirmados -join ' | ')'"
    } finally { Remove-RepoDoctor $fx }

    # O par: o MESMO repositorio, sem o orphan, mede e afirma. Sem esta metade,
    # uma dimensao que nunca afirmasse nada passaria acima.
    $fx2 = New-RepoDoctor
    try {
        $r2 = Get-DiagnosticoRetomabilidade -Raiz $fx2
        $afirmados2 = @($r2.Verificacoes | ForEach-Object { "" + $_.O_que })
        Assert-True ($afirmados2 -contains 'STATE atualizado no ultimo commit') `
            "em repositorio saudavel a dimensao deixou de afirmar o fato que ela mede: '$($afirmados2 -join ' | ')'"
        Assert-True (@($r2.NaoVerificado).Count -eq 0) `
            "repositorio saudavel produziu lacuna: '$(@($r2.NaoVerificado | ForEach-Object { $_.O_que }) -join ' | ')'"
    } finally { Remove-RepoDoctor $fx2 }
}

Test-Caso "dimensoes: campo ausente responde 'nao se aplica: <motivo>', e nao 'True'" {
    # O canal 'Resultado' NAO era lido por assercao nenhuma da suite - so o
    # 'O_que'. Reverter a correcao da rodada 8 devolvia a verdade vacua ('True'
    # sobre o que ninguem verificou) e a suite continuava verde: o construtor
    # nao lanca, porque nao ha lacuna com aquele rotulo nesses ramos, e nenhum
    # codigo de saida muda. Achado do qa-reviewer na nona rodada, derivado por
    # leitura das assercoes - e ele estava certo.
    #
    # 'nao se aplica' e a resposta honesta: o fato e DETERMINADO (o campo nao
    # foi declarado), e afirmar 'True' seria verdade vacua apresentada como
    # verificacao feita.

    # 1. manifesto: 'verificacao.tests' ausente.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nclassificacao:`n  criticidade: `"media`"`n"
    try {
        $r = Get-DiagnosticoManifesto -Raiz $fx
        $v = @($r.Dimensao.Verificacoes | Where-Object { ("" + $_.O_que) -eq 'verificacao.tests coerente com o disco' })
        Assert-True ($v.Count -eq 1) "a dimensao nao emitiu a verificacao de tests"
        Assert-True (("" + $v[0].Resultado) -match '^nao se aplica') `
            "campo ausente respondeu '$($v[0].Resultado)' em vez de 'nao se aplica': verdade vacua apresentada como verificacao"
    } finally { Remove-RepoDoctor $fx }

    # 2. retomabilidade: repositorio SEM commit nenhum.
    $fx2 = New-RepoDoctor -SemCommit
    try {
        $r2 = Get-DiagnosticoRetomabilidade -Raiz $fx2
        $v2 = @($r2.Verificacoes | Where-Object { ("" + $_.O_que) -eq 'STATE atualizado no ultimo commit' })
        Assert-True ($v2.Count -eq 1) "a dimensao nao emitiu a verificacao do STATE"
        Assert-True (("" + $v2[0].Resultado) -match '^nao se aplica') `
            "repositorio sem commits respondeu '$($v2[0].Resultado)' em vez de 'nao se aplica'"
    } finally { Remove-RepoDoctor $fx2 }

    # 3. O PAR, que impede a regra de virar 'responda sempre nao se aplica':
    #    repositorio saudavel responde o BOOLEANO, nao prosa.
    $fx3 = New-RepoDoctor
    try {
        $r3 = Get-DiagnosticoRetomabilidade -Raiz $fx3
        $v3 = @($r3.Verificacoes | Where-Object { ("" + $_.O_que) -eq 'STATE atualizado no ultimo commit' })
        Assert-True ($v3.Count -eq 1) "a dimensao nao emitiu a verificacao do STATE em repositorio saudavel"
        Assert-True (("" + $v3[0].Resultado) -eq 'True') `
            "repositorio saudavel respondeu '$($v3[0].Resultado)' em vez do booleano: a dimensao parou de medir"

    } finally { Remove-RepoDoctor $fx3 }

    # E o par do par: manifesto que DECLARA 'tests: true' responde o booleano, e
    # o booleano MUDA conforme a pasta exista ou nao. A fixture padrao declara
    # 'tests: false', entao criar 'tests/' nela nao mudava nada - o gesto
    # sugeria medir e nao media. Ressalva do qa-reviewer na decima rodada.
    $fx4 = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nclassificacao:`n  criticidade: `"media`"`nverificacao:`n  comando: `"x`"`n  tests: true`n"
    try {
        $semPasta = Get-DiagnosticoManifesto -Raiz $fx4
        $vSem = @($semPasta.Dimensao.Verificacoes | Where-Object { ("" + $_.O_que) -eq 'verificacao.tests coerente com o disco' })
        Assert-True ($vSem.Count -eq 1 -and ("" + $vSem[0].Resultado) -eq 'False') `
            "declara tests SEM a pasta respondeu '$(if ($vSem.Count) { $vSem[0].Resultado } else { '<ausente>' })' em vez de False"

        New-Item -ItemType Directory -Path (Join-Path $fx4 'tests') -Force | Out-Null
        $comPasta = Get-DiagnosticoManifesto -Raiz $fx4
        $vCom = @($comPasta.Dimensao.Verificacoes | Where-Object { ("" + $_.O_que) -eq 'verificacao.tests coerente com o disco' })
        Assert-True ($vCom.Count -eq 1 -and ("" + $vCom[0].Resultado) -eq 'True') `
            "com a pasta tests/ presente respondeu '$(if ($vCom.Count) { $vCom[0].Resultado } else { '<ausente>' })' em vez de True: o resultado nao acompanha o disco"
    } finally { Remove-RepoDoctor $fx4 }
}

# =============================================================================
# O CONTRATO PUBLICADO - a prosa da SKILL.md, medida contra o codigo
# =============================================================================

Test-Caso "contrato: a SKILL.md afirma comportamento verificavel, e o codigo responde o mesmo" {
    # O item 86 do backlog, fechado por decisao da mantenedora antes do
    # fechamento da 2.5.
    #
    # A 'skills/doctor/SKILL.md' afirma comportamento VERIFICAVEL - a escada de
    # status, o mapa de codigo de saida, e os cenarios que ela nomeia. Nada disso
    # tinha detector: 'plugin validate' olha estrutura, nao conteudo, e nenhum
    # caso comparava a prosa com o codigo. Consequencia medida: uma afirmacao
    # FALSA sobre codigo de saida sobreviveu uma RODADA INTEIRA de revisao
    # depois de eu ter corrigido o comportamento - eu consertei o relatorio e
    # esqueci o contrato publicado. O 'qa-reviewer' deu 'cobertura'
    # INCONCLUSIVO duas rodadas seguidas por isto, com a frase que nomeia a
    # classe: "o que mudou nesta delta e prosa, e prosa nao tem detector".
    #
    # Este caso nao valida prosa: extrai da prosa as AFIRMACOES ESTRUTURADAS e
    # pergunta ao codigo. Se a SKILL.md mudar de forma, ele falha em vez de
    # ficar verde sobre o que deixou de casar - que e a direcao certa para um
    # detector de contrato.
    $skill = Join-Path $OsRoot 'skills\doctor\SKILL.md'
    Assert-True (Test-Path $skill -PathType Leaf) `
        "PRE-CONDICAO: a SKILL.md nao esta onde este caso espera - sem ela o caso passaria por vacuidade"
    $txt = Get-Texto $skill

    # --- 1. a escada de status da tabela e a do codigo -------------------
    $daTabela = @([regex]::Matches($txt, '(?m)^\|\s*`([A-Z]+)`\s*\|') | ForEach-Object { $_.Groups[1].Value })
    $doCodigo = @(Get-StatusDoDoctor)
    Assert-True ($daTabela.Count -eq $doCodigo.Count) `
        "a tabela da SKILL.md lista $($daTabela.Count) status e o codigo tem $($doCodigo.Count): '$($daTabela -join ',')' contra '$($doCodigo -join ',')'"
    foreach ($s in $doCodigo) {
        Assert-True ($daTabela -contains $s) "o status '$s' existe no codigo e NAO esta na tabela da SKILL.md"
    }

    # --- 2. o mapa de codigo de saida que a prosa promete ----------------
    # 'Codigos de saida: 0 para PASS e WARN; 1 para FAIL...; 2 para INCONCLUSIVO...'
    $mCodigos = [regex]::Match($txt, '(?m)^\*\*C.digos de sa.da:\*\*(.+)$')
    Assert-True ($mCodigos.Success) `
        "a SKILL.md nao declara mais a linha 'Codigos de saida:'. Se a forma mudou, este detector precisa acompanhar - detector que deixa de casar em silencio e o defeito que ele existe para pegar"
    $linha = $mCodigos.Groups[1].Value

    $prometido = @{}
    foreach ($m in [regex]::Matches($linha, '`(\d)`\s*para\s*((?:\s*`[A-Z]+`(?:\s*e\s*)?)+)')) {
        $codigo = [int]$m.Groups[1].Value
        foreach ($s in [regex]::Matches($m.Groups[2].Value, '`([A-Z]+)`')) {
            $prometido[$s.Groups[1].Value] = $codigo
        }
    }
    Assert-True ($prometido.Count -eq $doCodigo.Count) `
        "a linha de codigos de saida promete $($prometido.Count) status e o codigo tem $($doCodigo.Count): '$linha'"
    foreach ($s in $doCodigo) {
        Assert-True ($prometido.ContainsKey($s)) "a SKILL.md nao promete codigo de saida para o status '$s'"
        $real = Get-CodigoDeSaidaDoDoctor -Status $s
        Assert-True ($prometido[$s] -eq $real) `
            "a SKILL.md promete $($prometido[$s]) para '$s' e o codigo devolve $real"
    }
}

Test-Caso "contrato: cada cenario que a SKILL.md nomeia sai com o codigo que ELA associa a ele" {
    # A outra metade: a prosa nomeia cenarios com codigo de saida. Aqui
    # eles sao EXECUTADOS. Foi um destes - 'fora de repositorio sai 1' contra
    # 'lacuna faz sair 2' - que ficou falso na SKILL.md por uma rodada inteira.
    $skill = Get-Texto (Join-Path $OsRoot 'skills\doctor\SKILL.md')

    # PRE-CONDICAO que impede vacuidade, ancorada na LINHA que carrega a
    # afirmacao - e nao no arquivo inteiro.
    #
    # A primeira versao deste caso procurava as palavras em qualquer lugar da
    # SKILL.md, e a mutacao mostrou o preco: tirar '(bare)' da linha de codigos
    # de saida NAO derrubava o caso, porque a palavra aparece de novo na
    # descricao da dimensao 'raiz', 6 linhas abaixo. Assercao ancorada
    # genericamente aceita qualquer coisa que se pareca com a resposta certa -
    # a forma que este repositorio ja registrou varias vezes, e que desta vez
    # quem pegou foi o instrumento de mutacao.
    $linhaCodigos = ''
    $mLinha = [regex]::Match($skill, '(?m)^\*\*C.digos de sa.da:\*\*(.+)$')
    if ($mLinha.Success) { $linhaCodigos = $mLinha.Groups[1].Value }
    # 'Assert-True $string' nao compila: o parametro e [bool], e PowerShell 5.1
    # recusa a conversao. O predicado tem de ser booleano de verdade.
    Assert-True (-not [string]::IsNullOrWhiteSpace($linhaCodigos)) "a SKILL.md nao declara mais a linha 'Codigos de saida:'"
    Assert-True ($linhaCodigos -match '(?i)fora de reposit.rio') `
        "a linha de codigos de saida nao nomeia mais 'fora de repositorio': '$linhaCodigos'"
    Assert-True ($linhaCodigos -match '(?i)\bbare\b') `
        "a linha de codigos de saida nao nomeia mais a forma 'bare': '$linhaCodigos'"

    $linhaPlaceholder = ''
    $mPh = [regex]::Match($skill, '(?m)^(.*placeholder de instancia.*)$')
    if ($mPh.Success) { $linhaPlaceholder = $mPh.Groups[1].Value }
    # O codigo de cada cenario e EXTRAIDO da prosa, clausula a clausula - nao
    # fixado aqui. A versao anterior comparava a execucao contra constantes no
    # teste, e por isso MOVER "fora de repositorio" da clausula do `1` para a do
    # `2` na SKILL.md passava verde: o contrato publicado prometia 2, o codigo
    # saia 1, e os dois casos ficavam verdes. Achado do qa-reviewer na decima
    # quarta rodada, com a mutacao pronta - dentro do detector que existia para
    # fechar exatamente essa classe. Afirmacao larga sobre verificacao estreita,
    # desta vez no guarda-corpo.
    # A pergunta certa NAO e "qual o primeiro codigo da clausula?" - e "qual
    # codigo a frase associa a ESTE cenario?".
    #
    # A versao anterior quebrava a linha em ';' e pegava o primeiro codigo de
    # cada pedaco. Trocar o ';' por ',' antes do cenario fazia a prosa prometer
    # 2 e o teste continuar medindo 1, com a suite inteira verde - o contrato
    # publicado voltando a poder mentir sobre codigo de saida. Quarta aparicao
    # da classe, e a terceira remenda seria a resposta errada: a linha passou a
    # ser varrida da esquerda para a direita, e cada cenario e amarrado ao
    # ULTIMO codigo anunciado ANTES dele, qualquer que seja a pontuacao.
    # Achado do qa-reviewer na decima quinta rodada.
    $marcas = @()
    foreach ($m in [regex]::Matches($linhaCodigos, '`(\d)`\s*para')) {
        $marcas += [pscustomobject]@{ Pos = $m.Index; Codigo = [int]$m.Groups[1].Value }
    }
    Assert-True ($marcas.Count -ge 2) `
        "a linha de codigos de saida anuncia $($marcas.Count) codigo(s): a varredura abaixo mediria nada"

    # O MESMO criterio do 'bare' nos dois lugares - a pre-condicao usava
    # '\bbare\b' e o mapa usava 'bare' solto. Dois criterios para o mesmo fato
    # no mesmo caso e a duplicacao que permite endurecer um lado e esquecer o
    # outro. Achado do qa-reviewer.
    #
    # E 'WARN', nao 'PASS': a fixture de 'New-RepoDoctor' nao tem 'artifacts/',
    # entao o frescor sai WARN e o status global e WARN. O rotulo dizia PASS e
    # media WARN - rotulo mais largo que a medicao, de novo.
    $cenarios = @{
        'fora-de-repo' = '(?i)fora de reposit'
        'bare'         = '(?i)\bbare\b'
        'sem-evidencia' = '`WARN`'
    }
    $porCenario = @{}
    foreach ($nome in @($cenarios.Keys)) {
        $mc = [regex]::Match($linhaCodigos, $cenarios[$nome])
        if (-not $mc.Success) { continue }
        $antes = @($marcas | Where-Object { $_.Pos -lt $mc.Index })
        if ($antes.Count -gt 0) { $porCenario[$nome] = $antes[$antes.Count - 1].Codigo }
    }
    Assert-True ($porCenario.ContainsKey('fora-de-repo')) `
        "nenhuma clausula da linha de codigos de saida nomeia 'fora de repositorio': '$linhaCodigos'"
    Assert-True ($porCenario.ContainsKey('bare')) `
        "nenhuma clausula da linha de codigos de saida nomeia 'bare': '$linhaCodigos'"

    # A MESMA pergunta, na outra linha. Eu tinha trocado a pergunta so na linha
    # de codigos e deixado o placeholder com a antiga - "qual o primeiro numero
    # da linha?" - numa linha que carrega DOIS cenarios: o placeholder e
    # 'verificacao.tests' com valor nao reconhecido. Reordenar a frase fazia a
    # prosa prometer 1 para o placeholder, o teste medir 2, e a suite ficar
    # verde. Quinta aparicao da classe, no mesmo guarda-corpo, num canal irmao.
    # Achado do qa-reviewer na decima sexta rodada, com a mutacao pronta.
    #
    # Aqui o codigo vem DEPOIS do cenario ("<cenario> ... sai `N`"), ao
    # contrario da linha de codigos ("`N` para <cenario>"). A pergunta e a
    # mesma - qual codigo a frase associa a ESTE cenario -, e a resposta e o
    # PRIMEIRO 'sai `N`' que aparece depois da mencao.
    $marcasSai = @()
    foreach ($m in [regex]::Matches($linhaPlaceholder, '(?i)sai .(\d).')) {
        $marcasSai += [pscustomobject]@{ Pos = $m.Index; Codigo = [int]$m.Groups[1].Value }
    }
    Assert-True ($marcasSai.Count -ge 1) `
        "a SKILL.md nao promete mais codigo de saida na linha do placeholder: '$linhaPlaceholder'"

    $doisDaLinha = @{ 'placeholder' = '(?i)placeholder de instancia'; 'tests-nao-reconhecido' = 'verificacao\.tests' }
    foreach ($nome in @($doisDaLinha.Keys)) {
        $mc = [regex]::Match($linhaPlaceholder, $doisDaLinha[$nome])
        if (-not $mc.Success) { continue }
        $depois = @($marcasSai | Where-Object { $_.Pos -gt $mc.Index })
        if ($depois.Count -gt 0) { $porCenario[$nome] = $depois[0].Codigo }
    }
    Assert-True ($porCenario.ContainsKey('placeholder')) `
        "a linha do placeholder nao associa codigo nenhum ao cenario do placeholder: '$linhaPlaceholder'"
    Assert-True ($porCenario.ContainsKey('tests-nao-reconhecido')) `
        "a linha do placeholder nao associa codigo nenhum a 'verificacao.tests': '$linhaPlaceholder'"

    # O paragrafo do caso 'raiz' promete status E codigo. Ele tem de concordar
    # com a clausula acima - foi a afirmacao deste paragrafo que ficou FALSA
    # por uma rodada inteira (item 83).
    $mRaiz = [regex]::Match($skill, '(?i)`raiz` sobre um caminho que n.o . reposit.rio: sai `([A-Z]+)` e `(\d)`')
    Assert-True ($mRaiz.Success) `
        "a SKILL.md nao promete mais status e codigo para o caso 'raiz' fora de repositorio"
    Assert-True ([int]$mRaiz.Groups[2].Value -eq $porCenario['fora-de-repo']) `
        "a SKILL.md se contradiz: o paragrafo do 'raiz' promete $($mRaiz.Groups[2].Value) e a linha de codigos promete $($porCenario['fora-de-repo'])"
    Assert-True ((Get-CodigoDeSaidaDoDoctor -Status $mRaiz.Groups[1].Value) -eq $porCenario['fora-de-repo']) `
        "a SKILL.md promete status '$($mRaiz.Groups[1].Value)' com codigo $($porCenario['fora-de-repo']), e esse status sai $(Get-CodigoDeSaidaDoDoctor -Status $mRaiz.Groups[1].Value)"

    # ------------------------------------------------------------------
    # E agora a EXECUCAO, contra o que a prosa prometeu - nao contra constante.
    # Cada fixture confere tambem o que o RELATORIO diz do proprio codigo de
    # saida: 'Write-RelatorioDoDoctor' imprime "(codigo de saida N)", e esse
    # texto nao tinha detector nenhum. Foi o texto fixo do relatorio que
    # carregou a afirmacao falsa do item 83.
    # ------------------------------------------------------------------
    $conferir = {
        param($raiz, $esperado, $cenario)
        $r = Invoke-Doctor $raiz
        Assert-True ($r.Exit -eq $esperado) `
            "a SKILL.md promete $esperado para '$cenario', e o doctor saiu $($r.Exit)"
        $rel = Get-RelDoctor $raiz
        Assert-True ($null -ne $rel) "o doctor nao gravou o relatorio para '$cenario'"
        $mDecl = [regex]::Match($rel, '\(codigo de saida (\d)\)')
        Assert-True ($mDecl.Success) "o relatorio de '$cenario' nao declara o proprio codigo de saida"
        Assert-True ([int]$mDecl.Groups[1].Value -eq $r.Exit) `
            "o relatorio de '$cenario' declara codigo $($mDecl.Groups[1].Value) e o processo saiu $($r.Exit)"
    }

    $fora = Join-Path $env:TEMP ("ct-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $fora -Force | Out-Null
    try { & $conferir $fora $porCenario['fora-de-repo'] 'fora de repositorio' } finally { Remove-RepoDoctor $fora }

    $bare = Join-Path $env:TEMP ("cb-" + [guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Path $bare -Force | Out-Null
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { git init -q --bare $bare 2>$null } finally { $ErrorActionPreference = $anterior }
        Assert-True (Test-Path (Join-Path $bare 'HEAD')) `
            "PRE-CONDICAO: a fixture nao virou repositorio bare - o cenario nao foi reproduzido"
        & $conferir $bare $porCenario['bare'] 'forma nao suportada (bare)'
    } finally { Remove-RepoDoctor $bare }

    $ph = New-RepoDoctor -Manifesto "identidade:`n  nome: `"{{NOME}}`"`nverificacao:`n  tests: {{TEM_TESTS}}`n"
    try { & $conferir $ph $porCenario['placeholder'] 'placeholder de instanciacao' } finally { Remove-RepoDoctor $ph }

    # O segundo cenario da mesma linha, que a prosa nomeia e que nao tinha
    # execucao nenhuma: 'verificacao.tests' com valor que nao e true nem false.
    $tn = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nverificacao:`n  tests: true`# nota`n"
    try { & $conferir $tn $porCenario['tests-nao-reconhecido'] 'verificacao.tests nao reconhecido' } finally { Remove-RepoDoctor $tn }

    # O PAR, que impede a regra de virar "sai sempre diferente de 0" - e que
    # tambem e o unico lugar onde o canal HUMANO mede o caminho 0. Os
    # fixtures passam pelo mesmo '$conferir': antes, dois deles olhavam so o
    # codigo do processo, e a frase "cada fixture confere o N" era mais larga
    # que a medicao. Achado do qa-reviewer na decima quinta rodada.
    Assert-True ($porCenario.ContainsKey('sem-evidencia')) `
        "nenhuma clausula da linha de codigos nomeia 'WARN': '$linhaCodigos'"
    $ok = New-RepoDoctor
    try {
        & $conferir $ok $porCenario['sem-evidencia'] 'projeto sem evidencia (WARN)'
        # O rotulo tem de bater com o que o doctor REALMENTE reporta.
        $relOk = Get-RelDoctor $ok
        Assert-True ($relOk -match '(?m)^- Status global: \*\*WARN\*\*') `
            "a fixture rotulada 'WARN' nao sai WARN: o rotulo seria mais largo que a medicao"
    } finally { Remove-RepoDoctor $ok }
}

Test-Caso "agregacao: projeto sem desvio nenhum sai com status global PASS, e exit 0" {
    # Nenhum caso da suite produzia status global PASS. Todos os PASS medidos
    # eram de DIMENSAO; a agregacao so era exercitada com INCONCLUSIVO ou FAIL
    # na lista. Mutacao que sobrevivia: um agregador que nunca devolvesse PASS -
    # default WARN, por exemplo - saia 0 nos dois mundos, e a suite inteira
    # ficava verde. Direcao segura, e ainda assim a enumeracao estava
    # incompleta. Achado do qa-reviewer na decima setima rodada.
    #
    # Construir PASS global exige TODAS as dimensoes canonicas em PASS ao mesmo
    # tempo, e e
    # por isso que nao existia: precisa de manifesto completo, pasta tests/,
    # STATE com data e proximo passo, arvore commitada, 'dependencias: []', e
    # os DOIS artefatos de evidencia carimbados com o HEAD corrente.
    $fx = New-RepoDoctor -Manifesto "identidade:`n  nome: `"x`"`nclassificacao:`n  criticidade: `"media`"`nverificacao:`n  comando: `"x`"`n  tests: false`nambiente:`n  dependencias: []`n"
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            # A ORDEM importa, e ela e o que tornava este caso impossivel de
            # escrever ingenuamente:
            #
            #   1. o STATE tem de ser tocado pelo ULTIMO commit, senao a
            #      retomabilidade sai WARN por "STATE atras do ultimo commit";
            #   2. o carimbo dos artefatos tem de citar o HEAD FINAL - carimbar
            #      antes de commitar faz o frescor sair 'de-outro-head';
            #   3. e a arvore tem de ficar limpa, senao a dimensao git sai WARN.
            #
            # As tres so fecham juntas porque 'artifacts/' e IGNORADO na fixture
            # ('/artifacts/*' no .gitignore de New-RepoDoctor): os artefatos sao
            # escritos DEPOIS do commit, citam o HEAD final, e nao sujam nada.
            New-Item -ItemType Directory -Path (Join-Path $fx 'docs\decisions') -Force | Out-Null
            [System.IO.File]::WriteAllText(
                (Join-Path $fx 'docs\decisions\ADR-0001-fixture.md'),
                ('# ADR-0001' + [char]10 + [char]10 + '- **Status:** aceita' + [char]10 + [char]10 + '## Contexto' + [char]10 + [char]10 + 'fixture' + [char]10),
                (New-Object System.Text.UTF8Encoding($false)))
            Add-Content -Path (Join-Path $fx 'docs\STATE.md') -Value 'evidencia carimbada' -Encoding UTF8

            git -C $fx add -A 2>$null
            git -C $fx commit -q -m 'registro' 2>$null

            $head = (git -C $fx rev-parse HEAD 2>$null)
            Assert-True (-not [string]::IsNullOrWhiteSpace(("" + $head))) `
                "PRE-CONDICAO: a fixture nao tem HEAD - o carimbo nao descreveria o commit atual"

            New-Item -ItemType Directory -Path (Join-Path $fx 'artifacts\review') -Force | Out-Null
            foreach ($alvo in @('security-report.md', 'diff-report.md')) {
                [System.IO.File]::WriteAllText(
                    (Join-Path $fx ('artifacts\review\' + $alvo)),
                    ('# evidencia' + [char]10 + [char]10 + '- HEAD: ' + [char]96 + $head + [char]96 + [char]10),
                    (New-Object System.Text.UTF8Encoding($false)))
            }

            # PRE-CONDICAO: a arvore tem de estar LIMPA depois disso, senao o
            # caso mediria WARN por outro motivo e o PASS seria inalcancavel
            # sem ninguem saber por que.
            $sujo = @(git -C $fx status --porcelain 2>$null)
            Assert-True (@($sujo).Count -eq 0) `
                "PRE-CONDICAO: a arvore ficou suja apos carimbar ($(@($sujo) -join ' | ')) - 'artifacts/' deveria estar ignorado"
        } finally { $ErrorActionPreference = $anterior }

        $r = Invoke-Doctor $fx
        $rel = Get-RelDoctor $fx
        Assert-True ($null -ne $rel) "o doctor nao gravou o relatorio"
        Assert-True ($rel -match '(?m)^- Status global: \*\*PASS\*\*') `
            "o status global nao saiu PASS. Dimensoes: $(@([regex]::Matches($rel, '(?m)^\| (\w+) \| \*\*(\w+)\*\*') | ForEach-Object { $_.Groups[1].Value + '=' + $_.Groups[2].Value }) -join ' ')"
        Assert-True ($r.Exit -eq 0) "status global PASS saiu com codigo $($r.Exit)"

        # O par que impede o caso de virar "sai sempre PASS": sujar a arvore faz
        # a dimensao git cair para WARN, e o global acompanha.
        [System.IO.File]::WriteAllText((Join-Path $fx 'sujeira.txt'), "x`n", (New-Object System.Text.UTF8Encoding($false)))
        $r2 = Invoke-Doctor $fx
        $rel2 = Get-RelDoctor $fx
        Assert-True ($rel2 -match '(?m)^- Status global: \*\*WARN\*\*') `
            "com trabalho nao commitado o global tinha de cair para WARN"
        Assert-True ($r2.Exit -eq 0) "WARN tambem sai 0, e saiu $($r2.Exit)"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "agregacao: com FAIL e INCONCLUSIVO ao mesmo tempo, quem domina e o INCONCLUSIVO" {
    # O unico par da escada que nenhuma fixture comparava. 'Get-StatusDoDoctor'
    # se documenta como "a lista canonica... a ordem E a regra de agregacao", e
    # cinco dos seis pares tinham caso; este nao.
    #
    # Mutacao que sobrevivia: reordenar a lista para @('PASS','WARN',
    # 'INCONCLUSIVO','FAIL'). Os codigos de saida nao mudam - eles saem de um
    # switch separado -, e o caso de contrato confere PERTINENCIA, nao ordem.
    # Suite inteira verde. Achado do qa-reviewer na decima oitava rodada,
    # derivado por leitura das sete assercoes que tocam a ordem.
    #
    # O que a mutacao produziria: 'FAIL' global e exit 1 sobre um projeto em
    # que uma dimensao NAO conseguiu medir - o doctor.json passaria a afirmar
    # "verifiquei e esta ruim" sobre o que nao foi verificado. E a forma que a
    # politica 4.5 proibe, no contrato de maquina da Fase 3/4.
    $fx = New-RepoDoctor -State $null
    try {
        # retomabilidade FAIL: sem docs/STATE.md o projeto nao e retomavel.
        # frescor INCONCLUSIVO: artefato existe e NAO tem carimbo de HEAD.
        New-Item -ItemType Directory -Path (Join-Path $fx 'artifacts\review') -Force | Out-Null
        [System.IO.File]::WriteAllText(
            (Join-Path $fx 'artifacts\review\security-report.md'),
            ('# relatorio sem carimbo' + [char]10),
            (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Doctor $fx
        $rel = Get-RelDoctor $fx
        Assert-True ($null -ne $rel) "o doctor nao gravou o relatorio"

        # PRE-CONDICAO: as DUAS dimensoes tem de estar no estado do par, senao
        # o caso mediria um par diferente do que o nome promete.
        $dims = @{}
        foreach ($m in [regex]::Matches($rel, '(?m)^\| (\w+) \| \*\*(\w+)\*\*')) {
            $dims[$m.Groups[1].Value] = $m.Groups[2].Value
        }
        Assert-True ($dims['retomabilidade'] -eq 'FAIL') `
            "a fixture nao produziu retomabilidade=FAIL (veio '$($dims['retomabilidade'])'): o par nao foi reproduzido"
        Assert-True ($dims['frescor'] -eq 'INCONCLUSIVO') `
            "a fixture nao produziu frescor=INCONCLUSIVO (veio '$($dims['frescor'])'): o par nao foi reproduzido"

        # E a regra: INCONCLUSIVO domina FAIL.
        Assert-True ($rel -match '(?m)^- Status global: \*\*INCONCLUSIVO\*\*') `
            "com FAIL e INCONCLUSIVO juntos o global saiu diferente de INCONCLUSIVO. Dimensoes: $(@($dims.Keys | ForEach-Object { $_ + '=' + $dims[$_] }) -join ' ')"
        Assert-True ($r.Exit -eq 2) `
            "o par FAIL+INCONCLUSIVO saiu com codigo $($r.Exit), e 'nao verifiquei' tem de sair 2"
    } finally { Remove-RepoDoctor $fx }
}

# =============================================================================
# ASSINATURA DA PLATAFORMA (spec de ownership, 2026-10-12): WARN, nunca FAIL,
# dentro da dimensao 'git'. A fixture vira "a plataforma" por -RaizDaPlataforma.
# A config global desta maquina assina commits: as fixtures sobrescrevem tudo
# na config LOCAL do repositorio temporario, nunca na global.
# =============================================================================

function Get-DimGitDoJson {
    param([string]$Repo)
    $j = Get-JsonDoctor $Repo
    if ($null -eq $j) { return $null }
    return @($j.dimensions | Where-Object { $_.nome -eq 'git' })[0]
}

Test-Caso "assinatura: plataforma sem assinatura configurada sai WARN na dimensao git, exit 0" {
    $fx = New-RepoDoctor
    try {
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            git -C $fx config commit.gpgsign false 2>$null
            git -C $fx config user.signingkey '""' 2>$null
            git -C $fx -c commit.gpgsign=false commit -q --allow-empty -m 'sem assinatura' 2>$null
            $sig = ("" + (git -C $fx log -1 '--format=%G?' 2>$null)).Trim()
        } finally { $ErrorActionPreference = $anterior }
        Assert-True ($sig -ceq 'N') "PRE-CONDICAO: o HEAD da fixture devia estar sem assinatura, veio '$sig'"

        $r = Invoke-Doctor $fx @('-RaizDaPlataforma', $fx)
        Assert-True ($r.Exit -eq 0) "assinatura ausente e WARN, que sai 0; saiu $($r.Exit). $($r.Saida)"
        $g = Get-DimGitDoJson $fx
        Assert-True ($null -ne $g) "o doctor nao gravou a dimensao git"
        Assert-True ($g.status -ceq 'WARN') "a dimensao git devia cair para WARN, veio '$($g.status)'"
        $j = Get-JsonDoctor $fx
        $msgs = @($j.findings | Where-Object { $_.dimensao -eq 'git' -and $_.mensagem -match '^assinatura da plataforma: ' } | ForEach-Object { $_.mensagem })
        Assert-True (@($msgs | Where-Object { $_ -match 'commit\.gpgsign' }).Count -eq 1) ("faltou o achado de commit.gpgsign: " + ($msgs -join ' | '))
        Assert-True (@($msgs | Where-Object { $_ -match 'signingkey nao configurado' }).Count -eq 1) ("faltou o achado da chave: " + ($msgs -join ' | '))
        Assert-True (@($msgs | Where-Object { $_ -match '%G\?=N' }).Count -eq 1) ("faltou o achado do HEAD sem assinatura: " + ($msgs -join ' | '))
        Assert-True (@($j.findings | Where-Object { $_.severidade -eq 'FAIL' }).Count -eq 0) "assinatura nunca e FAIL"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "assinatura: repositorio que NAO e a plataforma nao ganha a verificacao" {
    $fx = New-RepoDoctor
    try {
        $null = Invoke-Doctor $fx
        $g = Get-DimGitDoJson $fx
        Assert-True ($null -ne $g) "o doctor nao gravou a dimensao git"
        Assert-True (@($g.verificacoes).Count -ge 1) "PRE-CONDICAO: a dimensao git sem verificacao nenhuma provaria nada"
        $ass = @($g.verificacoes | Where-Object { $_.o_que -match '^assinatura: ' })
        Assert-True ($ass.Count -eq 0) "um projeto qualquer recebeu a verificacao de assinatura da plataforma"
    } finally { Remove-RepoDoctor $fx }
}

Test-Caso "assinatura: plataforma com chave ssh local e HEAD assinado nao gera achado" {
    $fx = New-RepoDoctor
    $dk = Join-Path $env:TEMP ("dr-chave-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        $kg = @(Get-Command ssh-keygen -ErrorAction SilentlyContinue)
        Assert-True ($kg.Count -gt 0) "PRE-CONDICAO: ssh-keygen nao encontrado no PATH"
        New-Item -ItemType Directory -Path $dk -Force | Out-Null
        $chaveTeste = Join-Path $dk 'k'
        # PS 5.1 descarta argumento vazio ('-N ""') ao chamar executavel nativo: linha de argumentos crua.
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $kg[0].Source
        $psi.Arguments = '-q -t ed25519 -N "" -C fx@invalid -f "' + $chaveTeste + '"'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        Assert-True (Test-Path -LiteralPath $chaveTeste -PathType Leaf) "PRE-CONDICAO: a chave de teste nao foi gerada"
        $pub = ((Get-Texto ($chaveTeste + '.pub')).Trim() -split ' ')
        $allowed = Join-Path $dk 'allowed_signers'
        [System.IO.File]::WriteAllText($allowed, ('fx@invalid ' + $pub[0] + ' ' + $pub[1] + "`n"), (New-Object System.Text.UTF8Encoding($false)))
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            git -C $fx config user.email 'fx@invalid' 2>$null
            git -C $fx config gpg.format ssh 2>$null
            git -C $fx config user.signingkey $chaveTeste 2>$null
            git -C $fx config commit.gpgsign true 2>$null
            git -C $fx config gpg.ssh.allowedSignersFile $allowed 2>$null
            git -C $fx config gpg.ssh.program $kg[0].Source 2>$null
            git -C $fx commit -q --allow-empty -m 'assinado' 2>$null
            $sig = ("" + (git -C $fx log -1 '--format=%G?' 2>$null)).Trim()
        } finally { $ErrorActionPreference = $anterior }
        Assert-True ($sig -ceq 'G') "PRE-CONDICAO: o HEAD devia sair assinado e verificado (G), veio '$sig'"

        $r = Invoke-Doctor $fx @('-RaizDaPlataforma', $fx)
        $g = Get-DimGitDoJson $fx
        Assert-True ($null -ne $g) "o doctor nao gravou a dimensao git. $($r.Saida)"
        $head = @($g.verificacoes | Where-Object { $_.o_que -eq 'assinatura: HEAD (%G?)' })
        Assert-True ($head.Count -eq 1 -and $head[0].resultado -ceq 'G') "a verificacao do HEAD nao saiu G"
        $j = Get-JsonDoctor $fx
        $ach = @($j.findings | Where-Object { $_.mensagem -match '^assinatura da plataforma' })
        Assert-True ($ach.Count -eq 0) ("achado de assinatura com tudo configurado: " + (@($ach | ForEach-Object { $_.mensagem }) -join ' | '))
        Assert-True ($g.status -ceq 'PASS') "repositorio limpo e assinado devia sair PASS na dimensao git, veio '$($g.status)'"
    } finally {
        Remove-RepoDoctor $fx
        if (Test-Path $dk) { Remove-Item $dk -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Test-Caso "assinatura: HEAD assinado com chave fora do allowedSignersFile (U) sai WARN, nunca PASS" {
    # r8 Q12: so G e assinado E verificado, coerente com o ownership (eos/ownership.py)
    $fx = New-RepoDoctor
    $dk = Join-Path $env:TEMP ("dr-chave-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        $kg = @(Get-Command ssh-keygen -ErrorAction SilentlyContinue)
        Assert-True ($kg.Count -gt 0) "PRE-CONDICAO: ssh-keygen nao encontrado no PATH"
        New-Item -ItemType Directory -Path $dk -Force | Out-Null
        $chaveTeste = Join-Path $dk 'k'
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $kg[0].Source
        $psi.Arguments = '-q -t ed25519 -N "" -C fx@invalid -f "' + $chaveTeste + '"'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        Assert-True (Test-Path -LiteralPath $chaveTeste -PathType Leaf) "PRE-CONDICAO: a chave de teste nao foi gerada"
        # allowedSignersFile existe, mas NAO tem a chave que assina: %G?=U
        $allowed = Join-Path $dk 'allowed_signers'
        [System.IO.File]::WriteAllText($allowed, '', (New-Object System.Text.UTF8Encoding($false)))
        $anterior = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            git -C $fx config user.email 'fx@invalid' 2>$null
            git -C $fx config gpg.format ssh 2>$null
            git -C $fx config user.signingkey $chaveTeste 2>$null
            git -C $fx config commit.gpgsign true 2>$null
            git -C $fx config gpg.ssh.allowedSignersFile $allowed 2>$null
            git -C $fx config gpg.ssh.program $kg[0].Source 2>$null
            git -C $fx commit -q --allow-empty -m 'assinado por chave desconhecida' 2>$null
            $sig = ("" + (git -C $fx log -1 '--format=%G?' 2>$null)).Trim()
        } finally { $ErrorActionPreference = $anterior }
        Assert-True ($sig -ceq 'U') "PRE-CONDICAO: o HEAD devia sair assinado por principal desconhecido (U), veio '$sig'"

        $r = Invoke-Doctor $fx @('-RaizDaPlataforma', $fx)
        Assert-True ($r.Exit -eq 0) "assinatura nao verificada e WARN, que sai 0; saiu $($r.Exit). $($r.Saida)"
        $g = Get-DimGitDoJson $fx
        Assert-True ($null -ne $g) "o doctor nao gravou a dimensao git. $($r.Saida)"
        $head = @($g.verificacoes | Where-Object { $_.o_que -eq 'assinatura: HEAD (%G?)' })
        Assert-True ($head.Count -eq 1 -and $head[0].resultado -ceq 'U') "a verificacao do HEAD nao saiu U"
        Assert-True ($g.status -ceq 'WARN') "HEAD com %G?=U devia derrubar a dimensao git para WARN, veio '$($g.status)'"
        $j = Get-JsonDoctor $fx
        $msgs = @($j.findings | Where-Object { $_.dimensao -eq 'git' -and $_.mensagem -match '^assinatura da plataforma: ' })
        Assert-True ($msgs.Count -eq 1) ("devia haver exatamente um achado de assinatura: " + (@($msgs | ForEach-Object { $_.mensagem }) -join ' | '))
        Assert-True ($msgs[0].mensagem -cmatch 'chave nao esta em allowedSignersFile \(%G\?=U\)') ("mensagem errada: " + $msgs[0].mensagem)
        Assert-True ($msgs[0].severidade -ceq 'WARN') "assinatura nunca e FAIL no doctor"
    } finally {
        Remove-RepoDoctor $fx
        if (Test-Path $dk) { Remove-Item $dk -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
