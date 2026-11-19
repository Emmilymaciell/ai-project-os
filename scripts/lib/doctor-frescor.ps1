<#
.SYNOPSIS
    Dimensao FRESCOR do /os:doctor: a ultima verificacao descreve ESTE commit?

.DESCRIPTION
    O doctor NAO roda a suite e NAO varre conteudo. Se uma verificacao precisa
    disso, ela pertence a 'tests' ou a '/os:security' - duplicar significa dois
    detectores divergindo em silencio, e esta plataforma ja pagou por isso.

    O que ele faz e ler o CARIMBO que aquelas ferramentas deixaram, e
    distinguir quatro estados. A regra que separa WARN de INCONCLUSIVO e uma
    so, e vale para os dois artefatos:

      WARN          eu DETERMINEI o fato, e o fato e ruim
                    (nao existe evidencia; ou ela e de outro HEAD)
      INCONCLUSIVO  eu NAO consegui determinar
                    (o artefato existe e nao da para dizer a que estado se
                    refere: sem carimbo de HEAD, truncado, ilegivel)

    'Nao existe evidencia recente' NUNCA e PASS. Um doctor que dissesse PASS
    para um projeto que nunca rodou a varredura estaria afirmando saude a
    partir de ausencia de dado - o mesmo erro que o scanner corrigiu na
    politica 4.5, e o mesmo que ja apareceu na ferramenta de mutacao desta
    casa.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-EstadoDoArtefato {
    <#
      Devolve o estado de UM artefato de evidencia, sem executar nada.

        ausente | do-head | de-outro-head | invalido

      'invalido' cobre as tres formas de "existe e nao da para usar": nao e
      legivel como texto, nao tem a linha de carimbo, ou tem carimbo que nao
      parece um sha. As tres levam a INCONCLUSIVO, e nenhuma pode ser
      confundida com 'ausente', que e um fato determinado.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Caminho,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$HeadAtual
    )

    if (-not (Test-Path $Caminho -PathType Leaf)) {
        return [pscustomobject]@{ Estado = 'ausente'; Head = $null; Porque = 'o arquivo nao existe' }
    }
    $txt = Read-TextoDeArquivo $Caminho
    if ($null -eq $txt) {
        return [pscustomobject]@{ Estado = 'invalido'; Head = $null; Porque = 'o arquivo existe e nao e legivel como texto' }
    }
    # Os dois coletores carimbam em linha de lista, e NAO na mesma forma: o
    # relatorio de seguranca abre a linha com 'HEAD:', o de diff escreve
    # 'Branch: `x`  HEAD: `sha`'. A primeira versao ancorava em inicio de
    # linha e declarava INVALIDO um carimbo perfeitamente valido - lacuna
    # inventada, que e tao ruim quanto lacuna escondida.
    $m = [regex]::Match($txt, '(?im)^\s*-\s.*?\bHEAD:\s*`?([0-9a-f]{7,40})`?')
    if (-not $m.Success) {
        return [pscustomobject]@{ Estado = 'invalido'; Head = $null; Porque = 'o arquivo nao traz a linha de carimbo `HEAD:`, entao nao da para dizer que estado ele descreve' }
    }
    $sha = $m.Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($HeadAtual)) {
        return [pscustomobject]@{ Estado = 'invalido'; Head = $sha; Porque = 'o HEAD atual nao foi determinado, entao nao ha contra o que comparar o carimbo' }
    }
    # Comparacao por PREFIXO, nos dois sentidos: o carimbo guarda a forma
    # curta e o HEAD atual vem completo.
    $curto = [Math]::Min($sha.Length, $HeadAtual.Length)
    if ($sha.Substring(0, $curto) -eq $HeadAtual.Substring(0, $curto)) {
        return [pscustomobject]@{ Estado = 'do-head'; Head = $sha; Porque = '' }
    }
    return [pscustomobject]@{ Estado = 'de-outro-head'; Head = $sha; Porque = "o carimbo e de '$sha', e o HEAD atual e '$HeadAtual'" }
}

function Get-DiagnosticoFrescor {
    param(
        [Parameter(Mandatory = $true)][string]$Raiz,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$HeadAtual
    )

    $cob = @{
        Artefatos       = 0
        DoHeadAtual     = 0
        DeOutroHead     = 0
        Ausentes        = 0
        Invalidos       = 0
    }
    $achados = @()
    $verif = @()
    $naoVerificado = @()

    $alvos = @(
        @{ Nome = 'varredura de seguranca'; Caminho = 'artifacts\review\security-report.md'; Acao = '/os:security' },
        @{ Nome = 'coleta de evidencia (inclui o resultado da suite)'; Caminho = 'artifacts\review\diff-report.md'; Acao = 'scripts\collect-diff.ps1' }
    )

    foreach ($a in $alvos) {
        $cob.Artefatos++
        $e = Get-EstadoDoArtefato -Caminho (Join-Path $Raiz $a.Caminho) -HeadAtual $HeadAtual

        # A verificacao sai NO RAMO, e nao antes do switch. Emitida para todo
        # artefato, ela convivia com a lacuna do ramo 'invalido' sobre o MESMO
        # artefato - dois canais, mesmo fato, rotulos diferentes ('$($a.Nome)'
        # e 'o frescor de $($a.Nome)'). A invariante do construtor compara
        # igualdade, entao nao alcancava. O conteudo nao se contradizia -
        # 'invalido' nao afirma saude -, mas a justificativa que eu tinha
        # registrado no backlog ("os ramos sao mutuamente exclusivos") era
        # falsa, e a condicao de disparo que eu reservei para o futuro ja
        # estava no disco. Achado do qa-reviewer na nona rodada.
        if ($e.Estado -ne 'invalido') {
            $verif += New-VerificacaoDoDoctor -O_que "o frescor de $($a.Nome)" -Resultado $e.Estado
        }

        switch ($e.Estado) {
            'do-head' { $cob.DoHeadAtual++ }
            'ausente' {
                $cob.Ausentes++
                $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'frescor' `
                    -Mensagem "nao existe evidencia de $($a.Nome) neste repositorio" `
                    -Caminho $a.Caminho -Acao "rode $($a.Acao)"
            }
            'de-outro-head' {
                $cob.DeOutroHead++
                $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'frescor' `
                    -Mensagem "a evidencia de $($a.Nome) descreve OUTRO commit - $($e.Porque)" `
                    -Caminho $a.Caminho -Acao "rode $($a.Acao) de novo sobre o estado atual"
            }
            'invalido' {
                $cob.Invalidos++
                $naoVerificado += New-NaoVerificadoDoDoctor -O_que "o frescor de $($a.Nome)" -Porque $e.Porque
            }
        }
    }

    $status = 'PASS'
    $motivo = 'a evidencia existente descreve o commit atual'
    if ($cob.Ausentes -gt 0 -or $cob.DeOutroHead -gt 0) {
        $status = 'WARN'
        $motivo = "$($cob.Ausentes) artefato(s) inexistente(s) e $($cob.DeOutroHead) de outro commit: a evidencia nao descreve este estado"
    }
    if ($cob.Invalidos -gt 0) {
        $status = 'INCONCLUSIVO'
        $motivo = "$($cob.Invalidos) artefato(s) existem e nao da para dizer que estado descrevem"
    }

    return New-DimensaoDoDoctor -Nome 'frescor' -Status $status -Cobertura $cob `
        -Verificacoes $verif -Achados $achados -NaoVerificado $naoVerificado -Motivo $motivo
}
