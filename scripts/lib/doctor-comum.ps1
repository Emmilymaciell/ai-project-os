<#
.SYNOPSIS
    Formas compartilhadas pelas dimensoes do /os:doctor.

.DESCRIPTION
    Uma dimensao do doctor devolve SEMPRE o mesmo objeto, e e isso que permite
    o agregador tratar todas igual - inclusive a que nao conseguiu rodar.

    A escada de status e a mesma do ADR-0009, aplicada a diagnostico:
      PASS          rodou e passou
      WARN          rodou, achou desvio que nao impede continuar
      FAIL          rodou e achou o que impede continuar
      INCONCLUSIVO  NAO conseguiu rodar, OU rodou e nao conseguiu verificar
                    parte do que promete verificar

    'Nao verifiquei' nunca vira 'esta bom' - politica 4.5. E por isso
    INCONCLUSIVO DOMINA na agregacao: uma dimensao inconclusiva no meio de
    tudo PASS sai com 2. Um doctor que arredondasse isso para WARN seria um
    detector que se aprende a ignorar.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-StatusDoDoctor {
    # A lista canonica, do melhor para o pior. Existe como funcao, e nao como
    # literal repetido, porque a ordem E a regra de agregacao: escrever a
    # ordem em dois lugares e como os dois portoes do scanner divergiram.
    return @('PASS', 'WARN', 'FAIL', 'INCONCLUSIVO')
}

function Get-PiorStatus {
    <#
      O pior de uma lista de status. Lista vazia LANCA, em vez de devolver
      'PASS': agregar nada e afirmar saude sobre nada, que e exatamente o
      falso verde que este projeto passou treze rodadas fechando.
    #>
    param([string[]]$Status)
    $ordem = Get-StatusDoDoctor
    $lista = @($Status | Where-Object { $_ })
    if ($lista.Count -eq 0) {
        throw "Get-PiorStatus: nenhuma dimensao foi avaliada. Agregar zero dimensoes e afirmar saude sobre nada."
    }
    $pior = 0
    foreach ($s in $lista) {
        $i = $ordem.IndexOf($s)
        if ($i -lt 0) { throw "Get-PiorStatus: status desconhecido '$s'." }
        if ($i -gt $pior) { $pior = $i }
    }
    return $ordem[$pior]
}

function Get-CodigoDeSaidaDoDoctor {
    # PASS e WARN saem 0; FAIL sai 1; INCONCLUSIVO sai 2.
    param([Parameter(Mandatory = $true)][string]$Status)
    switch ($Status) {
        'PASS'         { return 0 }
        'WARN'         { return 0 }
        'FAIL'         { return 1 }
        'INCONCLUSIVO' { return 2 }
        default        { throw "Get-CodigoDeSaidaDoDoctor: status desconhecido '$Status'." }
    }
}

function New-AchadoDoDoctor {
    param(
        [Parameter(Mandatory = $true)][string]$Severidade,
        [Parameter(Mandatory = $true)][string]$Dimensao,
        [Parameter(Mandatory = $true)][string]$Mensagem,
        [string]$Caminho,
        [string]$Acao
    )
    return [pscustomobject]@{
        Severidade = $Severidade
        Dimensao   = $Dimensao
        Mensagem   = $Mensagem
        Caminho    = $Caminho
        Acao       = $Acao
    }
}

function New-DimensaoDoDoctor {
    <#
      -Verificacoes e o que a dimensao CONSEGUIU verificar; -NaoVerificado e o
      que ela nao conseguiu, com o porque. Os dois viajam para a saida
      estruturada: consumidor que recebe 'PASS' sem saber o que ficou de fora
      repete o erro que o relatorio de seguranca ja corrigiu.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Nome,
        [Parameter(Mandatory = $true)][string]$Status,
        [string]$Motivo = '',
        [object[]]$Verificacoes = @(),
        [object[]]$Achados = @(),
        [object[]]$NaoVerificado = @(),
        [hashtable]$Cobertura = @{}
    )
    if ((Get-StatusDoDoctor) -notcontains $Status) {
        throw "New-DimensaoDoDoctor: status desconhecido '$Status' para a dimensao '$Nome'."
    }

    # A MESMA pergunta nao pode estar nos dois canais. 'Verificacoes' diz o que
    # a dimensao CONSEGUIU verificar e 'NaoVerificado' diz o que ela nao
    # conseguiu: um 'O_que' nos dois e o artefato afirmando e negando o mesmo
    # fato, no contrato de maquina que a Fase 3/4 vai consumir.
    #
    # Isto vive AQUI, e nao nos sitios, de proposito. O defeito apareceu em
    # 'manifesto' e em 'retomabilidade' ao mesmo tempo, porque cada dimensao
    # decidia sozinha - e quatro vezes nesta subfase um endurecimento deixou o
    # ramo vizinho aberto. Uma dimensao nova nasce coberta por esta guarda sem
    # ninguem precisar lembrar. Achado do qa-reviewer na setima rodada, com a
    # forma do conserto sugerida por ele.
    $doisCanais = @()
    foreach ($nv in @($NaoVerificado)) {
        $oQue = ("" + $nv.O_que)
        foreach ($v in @($Verificacoes)) {
            if (("" + $v.O_que) -eq $oQue) { $doisCanais += $oQue }
        }
    }
    if ($doisCanais.Count -gt 0) {
        throw ("New-DimensaoDoDoctor: a dimensao '$Nome' afirma ter verificado o que ela mesma declara NAO ter verificado: '" +
               (($doisCanais | Select-Object -Unique) -join "', '") +
               "'. Um dos dois canais esta errado, e o artefato de maquina nao pode sair afirmando e negando o mesmo fato.")
    }
    return [pscustomobject]@{
        Nome          = $Nome
        Status        = $Status
        Motivo        = $Motivo
        Verificacoes  = @($Verificacoes)
        Achados       = @($Achados)
        NaoVerificado = @($NaoVerificado)
        Cobertura     = $Cobertura
    }
}

function Get-DimensoesDoDoctor {
    <#
      A lista CANONICA, na ordem em que o relatorio as apresenta.

      Existe para que "quantas dimensoes o doctor tem" tenha uma resposta no
      CODIGO, e nao um numero repetido em prosa e em teste. Na 2.5 a mesma
      classe custou uma rodada inteira: a expectativa estava embutida no caso
      enquanto o comentario dizia que vinha do contrato. Aqui o doctor confere
      o que emitiu contra esta lista antes de escrever qualquer coisa - uma
      dimensao que sumisse em silencio seria varrer menos sem avisar, que e
      justamente o que a politica 4.5 proibe.
    #>
    return @('raiz', 'manifesto', 'retomabilidade', 'git', 'ambiente', 'frescor', 'hooks')
}

function New-VerificacaoDoDoctor {
    param([Parameter(Mandatory = $true)][string]$O_que, [Parameter(Mandatory = $true)][string]$Resultado)
    return [pscustomobject]@{ O_que = $O_que; Resultado = $Resultado }
}

function New-NaoVerificadoDoDoctor {
    param([Parameter(Mandatory = $true)][string]$O_que, [Parameter(Mandatory = $true)][string]$Porque)
    return [pscustomobject]@{ O_que = $O_que; Porque = $Porque }
}

function New-AcaoRecomendada {
    # Texto, nunca execucao. O doctor diz o que rodar; quem roda e a
    # mantenedora. Ferramenta que conserta sozinha esconde o problema que
    # deveria mostrar.
    param([Parameter(Mandatory = $true)][string]$Comando, [Parameter(Mandatory = $true)][string]$Porque)
    return [pscustomobject]@{ Comando = $Comando; Porque = $Porque }
}

# =============================================================================
# Saida: relatorio humano E saida estruturada
#
# As duas saem da MESMA agregacao, de proposito. Se o Markdown e o JSON
# fossem montados em lugares diferentes, eles divergiriam - foi exatamente
# assim que os dois carimbos de integridade desta casa passaram a discordar
# na 2.3, e o conserto foi uma convencao unica para os dois lados.
# =============================================================================

function Write-RelatorioDoDoctor {
    param(
        [Parameter(Mandatory = $true)][object[]]$Dimensoes,
        [Parameter(Mandatory = $true)][string]$Raiz,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Head,
        [Parameter(Mandatory = $true)][string]$Forma,
        [Parameter(Mandatory = $true)][string]$Out,
        [Parameter(Mandatory = $true)][string]$OutJson,
        [Parameter(Mandatory = $true)][int]$SchemaVersion
    )

    $global = Get-PiorStatus -Status @($Dimensoes | ForEach-Object { $_.Status })
    $codigo = Get-CodigoDeSaidaDoDoctor -Status $global
    $agora  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')

    $achados = @()
    foreach ($d in $Dimensoes) { $achados += @($d.Achados) }
    $achados = @($achados | Where-Object { $_ })

    # Acoes recomendadas: TEXTO. O doctor nao executa nenhuma delas, e o teste
    # que prova isso compara a arvore byte a byte antes e depois.
    $acoes = @()
    foreach ($a in $achados) {
        if ($a.Acao) { $acoes += (New-AcaoRecomendada -Comando $a.Acao -Porque $a.Mensagem) }
    }

    $sb = New-Object System.Text.StringBuilder
    $W = { param($t) [void]$sb.AppendLine($t) }

    & $W "# Diagnostico do projeto (/os:doctor)"
    & $W ""
    & $W "- Gerado em: $agora"
    & $W "- Raiz: ``$Raiz``"
    & $W "- Forma: ``$Forma``"
    & $W ("- HEAD: " + $(if ($Head) { "``$Head``" } else { '**nao determinado**' }))
    & $W "- Status global: **$global**   (codigo de saida $codigo)"
    & $W ""
    & $W "> Este relatorio e DIAGNOSTICO, nao acao. O doctor nao roda a suite, nao"
    & $W "> varre conteudo procurando segredo, nao corrige arquivo e nao toca em Git."
    & $W "> Ele diz o que rodar; quem roda e voce."
    & $W ""
    & $W "## Dimensoes"
    & $W ""
    & $W "| Dimensao | Status | Motivo |"
    & $W "|---|---|---|"
    foreach ($d in $Dimensoes) {
        & $W ("| {0} | **{1}** | {2} |" -f $d.Nome, $d.Status, $d.Motivo)
    }
    & $W ""
    & $W "**``INCONCLUSIVO`` domina a AGREGACAO.** Uma dimensao que nao conseguiu"
    & $W "rodar - ou que rodou e nao conseguiu verificar parte do que promete -"
    & $W "faz o diagnostico inteiro sair com ``2``, mesmo que todas as outras"
    & $W 'passem: "nao verifiquei" nunca vira "esta bom".'
    & $W ""
    & $W "Quem decide e o STATUS de cada dimensao, na tabela acima. Uma lacuna"
    & $W "listada abaixo nem sempre muda esse status: quando o fato da PROPRIA"
    & $W "dimensao esta determinado, ela responde o fato. E o caso de ``raiz``"
    & $W "sobre um caminho que nao e repositorio - sai ``FAIL``, e a lacuna e"
    & $W "sobre as OUTRAS dimensoes, que nao tiveram sobre o que rodar."
    & $W ""

    & $W "## O que NAO foi verificado"
    & $W ""
    & $W "| Dimensao | O que | Por que |"
    & $W "|---|---|---|"
    $temLacuna = $false
    foreach ($d in $Dimensoes) {
        foreach ($n in @($d.NaoVerificado)) {
            if (-not $n) { continue }
            $temLacuna = $true
            & $W ("| {0} | {1} | {2} |" -f $d.Nome, $n.O_que, $n.Porque)
        }
    }
    if (-not $temLacuna) { & $W "| (nenhuma) | todas as dimensoes conseguiram rodar | - |" }
    & $W ""

    & $W "## Cobertura medida por dimensao"
    & $W ""
    & $W "Os numeros que cada dimensao apurou, como ela os apurou. Estao aqui - e"
    & $W "na saida estruturada - porque contador que sobe e nao chega ao relatorio"
    & $W "nao corrige nada."
    & $W ""
    & $W "| Dimensao | Campo | Valor |"
    & $W "|---|---|---|"
    foreach ($d in $Dimensoes) {
        foreach ($k in (@($d.Cobertura.Keys) | Sort-Object)) {
            & $W ("| {0} | {1} | {2} |" -f $d.Nome, $k, $d.Cobertura[$k])
        }
    }
    & $W ""

    & $W "## Achados"
    & $W ""
    if ($achados.Count -eq 0) {
        & $W "Nenhum achado."
    } else {
        & $W "| Severidade | Dimensao | O que | Onde |"
        & $W "|---|---|---|---|"
        foreach ($a in $achados) {
            $onde = $(if ($a.Caminho) { '`' + $a.Caminho + '`' } else { '-' })
            & $W ("| {0} | {1} | {2} | {3} |" -f $a.Severidade, $a.Dimensao, $a.Mensagem, $onde)
        }
    }
    & $W ""

    & $W "## Proxima acao recomendada"
    & $W ""
    if ($acoes.Count -eq 0) {
        & $W "Nada a fazer a partir deste diagnostico."
    } else {
        foreach ($a in $acoes) { & $W ("- ``{0}`` - {1}" -f $a.Comando, $a.Porque) }
    }
    & $W ""
    & $W "## O que este diagnostico NAO responde"
    & $W ""
    & $W "- **Se o comportamento funciona.** Isso e ``tests``, e o doctor nao o executa."
    & $W "- **Se ha segredo ou dado de terceiro exposto.** Isso e ``/os:security``, que tem"
    & $W "  seis areas, escada de severidade e mecanismo de excecao. O doctor so le o"
    & $W "  carimbo do relatorio que ele deixou."
    & $W "- **Se o codigo e bom, ou se o STATE esta bem escrito.** Nao e deterministico,"
    & $W "  e nao e diagnostico."

    $dirOut = Split-Path $Out -Parent
    if ($dirOut -and -not (Test-Path $dirOut)) { New-Item -ItemType Directory -Path $dirOut -Force | Out-Null }
    [System.IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

    # ---- saida estruturada ---------------------------------------------------
    # schema_version PRIMEIRO e obrigatorio: sem ele, a primeira mudanca de
    # formato quebra em silencio quem ja estiver consumindo. Campo nunca e
    # removido nem tem o significado trocado sem subir a versao.
    $estrutura = [ordered]@{
        schema_version = $SchemaVersion
        status         = $global
        exit_code      = $codigo
        head           = $(if ($Head) { $Head } else { $null })
        root           = [ordered]@{ path = $Raiz; forma = $Forma; resolvida = ($Forma -ne 'fora-de-repo' -and $Forma -ne 'bare' -and $Forma -ne 'indeterminada') }
        timestamp      = $agora
        dimensions     = @($Dimensoes | ForEach-Object {
            [ordered]@{
                nome         = $_.Nome
                status       = $_.Status
                motivo       = $_.Motivo
                verificacoes = @($_.Verificacoes | ForEach-Object { [ordered]@{ o_que = $_.O_que; resultado = $_.Resultado } })
                # A cobertura CRUA da dimensao, inteira. Contador que sobe e
                # nao chega a saida nao corrige nada - e a regra que o guarda
                # de campo sem leitor existe para impor, e que esta versao
                # violava: as dimensoes carregavam cobertura que ninguem via.
                cobertura    = $_.Cobertura
            }
        })
        findings       = @($achados | ForEach-Object {
            [ordered]@{ severidade = $_.Severidade; dimensao = $_.Dimensao; mensagem = $_.Mensagem; caminho = $_.Caminho; acao = $_.Acao }
        })
        coverage       = [ordered]@{
            verificado     = @($Dimensoes | ForEach-Object { $n = $_.Nome; @($_.Verificacoes | ForEach-Object { [ordered]@{ dimensao = $n; o_que = $_.O_que; resultado = $_.Resultado } }) })
            nao_verificado = @($Dimensoes | ForEach-Object { $n = $_.Nome; @($_.NaoVerificado | ForEach-Object { [ordered]@{ dimensao = $n; o_que = $_.O_que; porque = $_.Porque } }) })
        }
        recommended_actions = @($acoes | ForEach-Object { [ordered]@{ comando = $_.Comando; porque = $_.Porque } })
    }

    $dirJson = Split-Path $OutJson -Parent
    if ($dirJson -and -not (Test-Path $dirJson)) { New-Item -ItemType Directory -Path $dirJson -Force | Out-Null }
    [System.IO.File]::WriteAllText($OutJson, ($estrutura | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($false)))

    Write-Host ""
    Write-Host "Diagnostico: $Out" -ForegroundColor Cyan
    Write-Host "Estruturado: $OutJson" -ForegroundColor DarkGray
    Write-Host ("  status: {0}   dimensoes: {1}   achados: {2}" -f $global, @($Dimensoes).Count, $achados.Count)
    Write-Host ""
}
