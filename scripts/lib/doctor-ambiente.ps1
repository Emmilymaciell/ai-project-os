<#
.SYNOPSIS
    Dimensao AMBIENTE do /os:doctor: as dependencias DECLARADAS existem?

.DESCRIPTION
    A regra que organiza esta dimensao inteira, e que a mantenedora fixou:
    **ausencia de ferramenta que o projeto nao declara usar NAO e diagnostico
    negativo.** Um doctor que reclamasse de 'gh' ausente num projeto que nao
    fala com o GitHub seria ruido que se aprende a ignorar - e detector que se
    ignora nao protege nada.

    Semantica do campo 'ambiente.dependencias', tambem decidida por ela:

      campo AUSENTE  -> WARN. Dependencias ainda nao declaradas: nao ha o que
                        cobrar, e tambem nao da para dizer PASS, porque nada
                        foi verificado. Declarar e trabalho pendente.
      []             -> valido. Declaracao EXPLICITA de que nao ha dependencia
                        verificavel. A diferenca entre isto e o campo ausente
                        e a diferenca entre 'nao tenho' e 'nao pensei'.
      lista          -> verifica SOMENTE o que esta ali.

    'obrigatoria: true' e como uma entrada diz que uma capacidade declarada
    depende dela. Obrigatoria e ausente derruba para FAIL; opcional e ausente
    e WARN.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Test-FerramentaNoPath {
    # Sonda o PATH. Devolve $true, $false, ou $null quando a propria sonda
    # falhou - e $null NAO pode virar 'ausente': 'nao consegui perguntar' e
    # lacuna, nao resposta.
    param([Parameter(Mandatory = $true)][string]$Nome)
    try {
        $c = Get-Command $Nome -ErrorAction SilentlyContinue
        return [bool]$c
    } catch { return $null }
}

function Get-DiagnosticoAmbiente {
    param([Parameter(Mandatory = $true)]$Manifesto)

    $cob = @{
        Declaradas           = 0
        Encontradas          = 0
        Ausentes             = 0
        ObrigatoriasAusentes = 0
        NaoSondadas          = 0
        CampoDeclarado       = $false
    }
    $achados = @()
    $verif = @()
    $naoVerificado = @()

    $dep = $null
    try { $dep = Get-CampoDoProjeto -Raiz $Manifesto -Caminho 'ambiente.dependencias' -Opcional }
    catch {
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que 'ambiente.dependencias' -Porque $_.Exception.Message
        return New-DimensaoDoDoctor -Nome 'ambiente' -Status 'INCONCLUSIVO' -Cobertura $cob -NaoVerificado $naoVerificado `
            -Motivo 'o campo de dependencias existe e nao pode ser lido'
    }

    if ($null -eq $dep) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'ambiente' `
            -Mensagem "o manifesto nao declara 'ambiente.dependencias': nenhuma dependencia foi verificada, e isso NAO significa que nao ha" `
            -Caminho 'project.yaml' `
            -Acao "declare 'ambiente.dependencias' - use [] para dizer explicitamente que nao ha dependencia verificavel"
        # NAO e lacuna: e fato DETERMINADO. Campo ausente era a unica lacuna
        # que nao derrubava para INCONCLUSIVO DENTRO DE UMA DIMENSAO QUE MEDIU -
        # 'manifesto', 'retomabilidade', 'frescor' e 'git' todas dominam.
        #
        # A excecao declarada e 'raiz' sobre caminho que nao e repositorio: ali
        # o fato da PROPRIA dimensao esta determinado - sai FAIL, exit 1 -, e a
        # lacuna e sobre as OUTRAS dimensoes, que nao tiveram sobre o que rodar.
        # Eu tinha escrito aqui "a unica do doctor inteiro", que era afirmacao
        # mais larga que o fato, e o qa-reviewer cobrou na decima rodada. O
        # relatorio
        # imprimia a linha em "O que NAO foi verificado", logo abaixo do
        # paragrafo que diz que lacuna faz sair com 2, e o processo saia 0.
        # "Lacuna decorativa", a forma que a rodada 5 nomeou, viva na terceira
        # dimensao. O WARN e decisao de governanca e continua; o que estava
        # errado era o CANAL. Achado do qa-reviewer na nona rodada.
        $verif += New-VerificacaoDoDoctor -O_que 'dependencias declaradas' `
            -Resultado 'nao se aplica: o projeto ainda nao declarou ambiente.dependencias'
        return New-DimensaoDoDoctor -Nome 'ambiente' -Status 'WARN' -Cobertura $cob -Achados $achados `
            -Verificacoes $verif -Motivo 'dependencias ainda nao declaradas'
    }

    $cob.CampoDeclarado = $true
    $lista = @($dep)
    $cob.Declaradas = $lista.Count

    if ($cob.Declaradas -eq 0) {
        $verif += New-VerificacaoDoDoctor -O_que 'dependencias declaradas' -Resultado 'nenhuma, declarado explicitamente com []'
        return New-DimensaoDoDoctor -Nome 'ambiente' -Status 'PASS' -Cobertura $cob -Verificacoes $verif `
            -Motivo 'o projeto declara que nao tem dependencia externa verificavel'
    }

    foreach ($e in $lista) {
        $nome = $null
        $obrigatoria = $false
        $para = ''
        if ($e -is [System.Collections.Hashtable]) {
            if ($e.ContainsKey('ferramenta')) { $nome = ("" + $e['ferramenta']).Trim() }
            if ($e.ContainsKey('para')) { $para = ("" + $e['para']).Trim() }
            if ($e.ContainsKey('obrigatoria')) { $obrigatoria = (("" + $e['obrigatoria']).Trim().ToLower() -eq 'true') }
        } else {
            $nome = ("" + $e).Trim()
        }

        if ([string]::IsNullOrWhiteSpace($nome)) {
            # Entrada sem ferramenta e declaracao que nao declara nada. Nao
            # pode ser descartada em silencio: entraria no total e sairia da
            # conta, e o numero deixaria de reconciliar.
            $cob.NaoSondadas++
            $naoVerificado += New-NaoVerificadoDoDoctor -O_que 'uma entrada de ambiente.dependencias' `
                -Porque "a entrada nao declara 'ferramenta', entao nao ha o que sondar no PATH"
            continue
        }

        $achou = Test-FerramentaNoPath -Nome $nome
        if ($null -eq $achou) {
            $cob.NaoSondadas++
            $naoVerificado += New-NaoVerificadoDoDoctor -O_que "a ferramenta '$nome'" -Porque 'a sonda do PATH falhou'
            continue
        }
        if ($achou) {
            $cob.Encontradas++
            $verif += New-VerificacaoDoDoctor -O_que "ferramenta '$nome'" -Resultado 'encontrada no PATH'
            continue
        }

        $cob.Ausentes++
        if ($obrigatoria) {
            $cob.ObrigatoriasAusentes++
            $achados += New-AchadoDoDoctor -Severidade 'FAIL' -Dimensao 'ambiente' `
                -Mensagem ("a ferramenta '$nome' e declarada OBRIGATORIA e nao esta no PATH" + $(if ($para) { " - usada para: $para" } else { '' })) `
                -Acao "instale '$nome', ou corrija o manifesto se ela deixou de ser necessaria"
        } else {
            $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'ambiente' `
                -Mensagem ("a ferramenta '$nome' e declarada e nao esta no PATH" + $(if ($para) { " - usada para: $para" } else { '' })) `
                -Acao "instale '$nome' quando precisar do que depende dela"
        }
    }

    $status = 'PASS'
    $motivo = "as $($cob.Encontradas) dependencia(s) declarada(s) estao no PATH"
    if ($cob.Ausentes -gt 0) { $status = 'WARN'; $motivo = "$($cob.Ausentes) dependencia(s) declarada(s) ausente(s)" }
    if ($cob.ObrigatoriasAusentes -gt 0) { $status = 'FAIL'; $motivo = "$($cob.ObrigatoriasAusentes) dependencia(s) OBRIGATORIA(s) ausente(s)" }
    if ($cob.NaoSondadas -gt 0) { $status = 'INCONCLUSIVO'; $motivo = "$($cob.NaoSondadas) dependencia(s) nao puderam ser sondadas" }

    return New-DimensaoDoDoctor -Nome 'ambiente' -Status $status -Cobertura $cob `
        -Verificacoes $verif -Achados $achados -NaoVerificado $naoVerificado -Motivo $motivo
}
