<#
.SYNOPSIS
    Leitura estrutural do project.yaml, para o /os:doctor.

.DESCRIPTION
    TERCEIRA implementacao de leitor de manifesto nesta plataforma, e isso e
    declarado aqui em vez de descoberto depois. As outras duas sao gemeas e
    vivem no harness do template - 'Read-ManifestoDoProjeto' em PowerShell e
    'ler_manifesto' em Python -, e elas ja divergiram OITO vezes ao longo da
    2.4, cada divergencia significando rigor diferente sobre o mesmo arquivo.

    Por que uma terceira, em vez de reusar: aquelas vivem em 'tests/' do
    TEMPLATE, que e outra camada - 'scripts/' da plataforma nao pode
    dot-source o harness de teste de um projeto instanciado. E elas RECUSAM
    lista de proposito, enquanto o doctor precisa ler 'ambiente.dependencias',
    que e lista. A diferenca e deliberada, nao acidental.

    O que impede a divergencia de virar defeito: um caso da suite alimenta o
    MESMO manifesto aos dois leitores e exige a MESMA resposta. A fixture
    carrega, nomeadamente, as formas que ja divergiram - no VALOR: aspas com
    comentario alinhado, valor que e so comentario, TAB antes do comentario;
    na CHAVE: entre aspas, com espaco antes do ':', com ponto, e com acento.
    Lista e a UNICA diferenca permitida, e o caso a declara.

    A afirmacao acima ja foi mais LARGA do que o caso media: dizia "todo campo
    escalar" enquanto a fixture so tinha chaves '[a-z_]', e a divergencia
    estava viva exatamente na chave - o doctor LANCAVA onde o gemeo lia, e um
    project.yaml com chave acentuada saia exit 2. Achado do qa-reviewer.

    O que o caso NAO mede, e que e teto COMPARTILHADO - os dois leitores
    recusam igual, entao nao e divergencia: '---' e '...', continuacao de
    escalar simples multi-linha (o 'yaml.dump' do Python quebra em ~80
    colunas), colecao em fluxo quebrada em linhas, ancora/alias e o merge
    '<<: *base'. Backlog item 42: o manifesto e um SUBCONJUNTO de YAML.

    As quatro coisas que este leitor nao faz, cada uma um defeito real ja
    corrigido do outro lado:
      - nao devolve bloco onde se esperava valor
      - nao devolve valor de bloco IRMAO que por acaso tenha a mesma chave
      - nao devolve campo declarado vazio como se fosse declarado
      - nao devolve placeholder de instanciacao como se fosse valor

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function New-BlocoDoManifesto {
    # Comparacao ORDINAL, e nao a @{} do PowerShell, que e case-insensitive.
    # Duas chaves que diferem so na caixa colapsavam em silencio, e o gemeo
    # Python - onde dict e case-sensitive - discordava. Achado do qa-reviewer
    # na 2.4, herdado aqui de proposito.
    return New-Object 'System.Collections.Hashtable' ([System.StringComparer]::Ordinal)
}

function Get-ChaveSemAspasDoManifesto {
    # Um par de aspas nas pontas, e so quando ha par - identico ao
    # 'Get-ValorSemAspas' do gemeo. O .Trim() com aspa comeria aspa sem par.
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Valor)
    if ($Valor.Length -ge 2) {
        $a = $Valor[0]
        $b = $Valor[$Valor.Length - 1]
        if ($a -eq $b -and ($a -eq '"' -or $a -eq "'")) {
            return $Valor.Substring(1, $Valor.Length - 2)
        }
    }
    return $Valor
}

function Get-TrechoParaDiagnostico {
    # O doctor se documenta como ferramenta que NAO transcreve conteudo do
    # projeto para dentro do artefato, e a mensagem de erro deste leitor
    # viajava VERBATIM para 'doctor-report.md' e 'doctor.json'. O numero da
    # linha localiza sem copiar o valor. Achado do security-reviewer.
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Texto)
    if ($Texto.Length -le 40) { return $Texto }
    return ($Texto.Substring(0, 40) + '...')
}

function Split-LinhaDeChaveDoManifesto {
    <#
      A UNICA definicao, neste leitor, do que e uma linha 'chave: valor'.
      Devolve $null quando a linha nao e isso; quem chama decide se isso e
      erro - dentro de lista, um item SEM ':' e escalar legitimo.

      Existir como funcao e o conserto na causa. A regex estava COPIADA em
      tres lugares - inicio de item de lista, continuacao de item, e chave de
      topo -, e quando a 2.5 tornou estrita a copia do TOPO, a copia da
      CONTINUACAO ficou com 'if ($m.Success)' sem 'else': a linha continuava
      sumindo em silencio, dentro do unico campo de lista que o doctor le.
      Mesmo fail-open, um ramo ao lado. Achado do qa-reviewer.

      A regex e a do gemeo do template ('_harness.ps1'), e a docstring de la
      diz que aceitar ponto, acento, aspas e espaco antes do ':' foi
      DELIBERADO, "porque recusar em silencio foi um dos fail-open da 2.4".
      Recusar aqui o que o gemeo aceita e rigor diferente sobre o mesmo
      arquivo: um project.yaml com chave acentuada - pt-BR - derrubava o
      doctor em duas dimensoes e saia exit 2, enquanto a suite do proprio
      projeto lia o mesmo arquivo sem reclamar.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Conteudo)
    $m = [regex]::Match($Conteudo, '^([^\s:#][^:]*):(.*)$')
    if (-not $m.Success) { return $null }
    $chave = Get-ChaveSemAspasDoManifesto ($m.Groups[1].Value.Trim())
    if ([string]::IsNullOrEmpty($chave)) { return $null }
    return [pscustomobject]@{ Chave = $chave; Bruto = $m.Groups[2].Value.Trim() }
}

function Read-ManifestoDoDoctor {
    <#
      Le o project.yaml inteiro numa estrutura aninhada e devolve a raiz.

      Le a ARVORE e procura depois: a estrutura decide, nao a ordem de
      aparicao. Foi o que fechou os dois fail-open da 2.4 - bloco irmao
      satisfazendo o caminho pedido, e chave nao reconhecida descartada em
      silencio sem encerrar o bloco da mae.

      LE lista, ao contrario do gemeo do template:
        - lista de escalares  -> array de string
        - lista de mapas      -> array de hashtable
      Escalar de bloco ('>' e '|') continua NAO lido, e e registrado como tal
      em vez de virar o indicador como valor.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)

    if (-not (Test-Path $Caminho -PathType Leaf)) {
        throw "project.yaml nao encontrado em '$Caminho'."
    }
    # Leitura estrita: manifesto ilegivel nao pode virar manifesto vazio.
    $txt = Read-TextoDeArquivo $Caminho
    if ($null -eq $txt) {
        throw "'$Caminho' nao e legivel como texto (UTF-8 invalido, ou NUL no conteudo). O manifesto NAO foi lido, e nada pode ser afirmado sobre o que ele declara. Salve o project.yaml em UTF-8 e rode de novo."
    }

    $linhas = $txt -split "`r?`n"
    $raiz = New-BlocoDoManifesto
    $pilha = New-Object System.Collections.ArrayList
    [void]$pilha.Add([pscustomobject]@{ Indent = -1; Bloco = $raiz })

    $ultimoPai = $raiz
    $ultimaChave = $null
    $indentEscalar = -1

    # Lista em curso: indentacao do marcador '-', a lista sendo montada, e o
    # mapa do item corrente quando os itens sao mapas.
    $indentLista = -1
    $listaAtual = $null
    $itemAtual = $null

    for ($i = 0; $i -lt $linhas.Count; $i++) {
        $linha = $linhas[$i]
        if (-not $linha.Trim()) { continue }
        if ($linha.Trim().StartsWith('#')) { continue }

        $indent = $linha.Length - $linha.TrimStart(' ').Length
        $conteudo = $linha.Trim()
        $ehItem = ($conteudo.StartsWith('- ') -or $conteudo -eq '-')

        # --- escalar de bloco em curso ---------------------------------------
        if ($indentEscalar -ge 0) {
            if ($indent -gt $indentEscalar) { continue }
            $indentEscalar = -1
        }

        # --- lista em curso ---------------------------------------------------
        if ($indentLista -ge 0) {
            if ($ehItem -and $indent -eq $indentLista) {
                $itemAtual = $null
                $resto = $conteudo.Substring(1).Trim()
                if ($resto) {
                    # Aqui o $null NAO e erro: '- git' e item escalar legitimo.
                    $par = Split-LinhaDeChaveDoManifesto $resto
                    if ($null -ne $par) {
                        $itemAtual = New-BlocoDoManifesto
                        $itemAtual[$par.Chave] = (ConvertFrom-EscalarDoManifesto $par.Bruto)
                        [void]$listaAtual.Add($itemAtual)
                    } else {
                        [void]$listaAtual.Add((ConvertFrom-EscalarDoManifesto $resto))
                    }
                }
                continue
            }
            if ($indent -gt $indentLista) {
                # Continuacao do item corrente: 'chave: valor' dentro do mapa.
                #
                # LANCA, pelo mesmo motivo do topo - e este ramo e PIOR, porque
                # e onde vive 'ambiente.dependencias'. Com 'obrigatoria : true'
                # descartada em silencio, '$obrigatoria' ficava $false em
                # 'doctor-ambiente.ps1', 'ObrigatoriasAusentes' ficava zero, a
                # dimensao saia WARN e o doctor saia 0 no lugar de 1: a UNICA
                # regra FAIL da dimensao, desarmada por uma linha que o YAML
                # aceita e o gemeo le. Achado do qa-reviewer.
                if ($null -eq $itemAtual) {
                    throw "project.yaml, linha $($i + 1): '$(Get-TrechoParaDiagnostico $conteudo)' esta indentada sob um item de lista ESCALAR, e este leitor nao adivinha a que mapa ela pertence."
                }
                $par = Split-LinhaDeChaveDoManifesto $conteudo
                if ($null -eq $par) {
                    throw "project.yaml, linha $($i + 1): '$(Get-TrechoParaDiagnostico $conteudo)' nao e 'chave: valor' dentro do item de lista, e este leitor nao adivinha. Linha descartada em silencio faz o doctor afirmar ausencia de campo declarado."
                }
                $itemAtual[$par.Chave] = (ConvertFrom-EscalarDoManifesto $par.Bruto)
                continue
            }
            # Chave irma no indent do marcador ENCERRA a lista. Sem isto, o
            # estilo compacto do YAML - que e a saida do yaml.dump e o estilo
            # do ADR-0010 - fazia o leitor pular metade do manifesto em
            # silencio. Achado dos dois revisores na 2.4.
            $indentLista = -1
            $listaAtual = $null
            $itemAtual = $null
        }

        if ($ehItem) {
            # Item de lista sem lista aberta: ignorado, mas nao em silencio -
            # a chave mae fica marcada como nao legivel.
            if ($null -ne $ultimaChave -and $ultimoPai.ContainsKey($ultimaChave)) {
                $ultimoPai[$ultimaChave] = [pscustomobject]@{ NaoLegivel = 'lista fora de bloco' }
            }
            continue
        }

        $par = Split-LinhaDeChaveDoManifesto $conteudo
        if ($null -eq $par) {
            # LANCA, e nao 'continue'. O gemeo do template e estrito de
            # proposito, e a versao anterior daqui descartava a linha em
            # SILENCIO: chave com ponto, espaco ou aspas sumia do manifesto
            # lido, e o doctor passava a dizer "o manifesto nao declara X"
            # sobre um campo declarado. Em 'ambiente.dependencias' isso
            # colapsaria a distincao entre ausente e '[]' - que e a decisao de
            # governanca desta subfase - por um motivo que ninguem veria.
            throw "project.yaml, linha $($i + 1): '$(Get-TrechoParaDiagnostico $conteudo)' nao e 'chave: valor' nem item de lista, e este leitor nao adivinha. Linha descartada em silencio faz o doctor afirmar ausencia de campo declarado."
        }
        $chave = $par.Chave
        # NORMALIZAR ANTES de decidir a estrutura. Ver Remove-ComentarioDoEscalar:
        # decidir 'e bloco?', 'e []?' sobre o valor CRU fazia um comentario na
        # linha de cabecalho derrubar o bloco inteiro para dentro da raiz.
        $valor = Remove-ComentarioDoEscalar $par.Bruto

        while ($pilha.Count -gt 1 -and $pilha[$pilha.Count - 1].Indent -ge $indent) {
            $pilha.RemoveAt($pilha.Count - 1)
        }
        $pai = $pilha[$pilha.Count - 1].Bloco
        $ultimoPai = $pai
        $ultimaChave = $chave

        if ($valor -eq '' ) {
            # Bloco, lista, ou campo declarado VAZIO. Decidido olhando a
            # proxima linha significativa - e nao chutando.
            #
            # 'chave:' sem valor abre bloco SO se a proxima linha significativa
            # for MAIS indentada; se estiver no mesmo indent, ou nao houver
            # proxima, o campo foi declarado vazio, e vazio nao e bloco. E a
            # regra do gemeo (_harness.ps1), e ela so passou a importar aqui
            # quando o comentario passou a ser cortado ANTES desta decisao:
            # 'criterio_de_pronto:  # preencher depois' agora chega vazio, e
            # sem esta guarda viraria um BLOCO vazio onde o gemeo devolve ''.
            $prox = Get-ProximaLinhaSignificativa -Linhas $linhas -Depois $i
            if ($null -ne $prox -and $prox.EhItem -and $prox.Indent -ge $indent) {
                $listaAtual = New-Object System.Collections.ArrayList
                $pai[$chave] = $listaAtual
                $indentLista = $prox.Indent
                $itemAtual = $null
                continue
            }
            if ($null -eq $prox -or $prox.Indent -le $indent) {
                $pai[$chave] = ''
                continue
            }
            $novo = New-BlocoDoManifesto
            $pai[$chave] = $novo
            [void]$pilha.Add([pscustomobject]@{ Indent = $indent; Bloco = $novo })
            continue
        }

        if ($valor -eq '[]') { $pai[$chave] = @(); continue }
        if ($valor -eq '{}') { $pai[$chave] = (New-BlocoDoManifesto); continue }
        if ($valor.StartsWith('>') -or $valor.StartsWith('|')) {
            $pai[$chave] = [pscustomobject]@{ NaoLegivel = 'escalar de bloco' }
            $indentEscalar = $indent
            continue
        }

        # 'ConvertFrom' de novo tiraria comentario ja tirado - inofensivo, mas
        # o que falta aqui e so o par de aspas.
        $pai[$chave] = (Get-ChaveSemAspasDoManifesto $valor)
    }

    return $raiz
}

function Get-ProximaLinhaSignificativa {
    # Proxima linha que nao e vazia nem comentario, com indentacao e se e item
    # de lista. Existe para que 'chave:' sem valor seja decidida por FATO -
    # bloco ou lista - e nao por suposicao.
    param([string[]]$Linhas, [int]$Depois)
    for ($j = $Depois + 1; $j -lt $Linhas.Count; $j++) {
        $l = $Linhas[$j]
        if (-not $l.Trim()) { continue }
        if ($l.Trim().StartsWith('#')) { continue }
        $ind = $l.Length - $l.TrimStart(' ').Length
        $c = $l.Trim()
        return [pscustomobject]@{ Indent = $ind; EhItem = ($c.StartsWith('- ') -or $c -eq '-') }
    }
    return $null
}

function Remove-ComentarioDoEscalar {
    <#
      Tira SO o comentario de fim de linha, e normaliza "valor que e so
      comentario" para vazio. NAO tira aspas.

      Existe separada porque a ORDEM importa, e essa foi a diferenca entre os
      dois leitores. As decisoes ESTRUTURAIS do manifesto - 'chave:' sem valor
      abre bloco ou lista, '[]', '{}', escalar de bloco - eram tomadas aqui
      sobre o valor CRU, e o comentario so era cortado depois. O gemeo do
      template normaliza ANTES (_harness.ps1, antes do teste de vazio).

      O que isso produzia, medido em execucao:

        verificacao:  # o que este projeto verifica
          tests: true
          comando: ".\tests\run-tests.ps1"

      O valor de 'verificacao' era '# o que...', diferente de vazio: o ramo do
      bloco nao rodava, 'verificacao' virava STRING, e as duas linhas de baixo
      reancoravam na RAIZ. 'verificacao.tests' sumia, 'DeclaraTests' ficava
      falso, e a UNICA regra FAIL da dimensao manifesto ficava desarmada - com
      exit 0, sem erro e sem lacuna. E:

        ambiente:
          dependencias: []   # nenhuma por enquanto

      que e o idioma publicado pelo proprio template, virava a STRING '[]': o
      doctor passava a sondar no PATH uma ferramenta chamada '[]', contava uma
      dependencia fantasma e saia INCONCLUSIVO - exit 2 sobre projeto saudavel,
      contra a decisao de governanca de que '[]' e declaracao explicita valida.

      Achado do qa-reviewer na quarta rodada.
    #>
    param([string]$Bruto)
    $v = $Bruto

    # As regras abaixo sao COPIA DELIBERADA do gemeo do template, e cada uma
    # existe porque ja foi divergencia medida entre os dois leitores de la.
    #
    # 1. Valor entre aspas: o comentario so e cortado depois da PRIMEIRA aspa
    #    repetida, e exige '\s+#'. Cortar no primeiro ' #' truncaria
    #    'comando: ".\x.ps1 # roda"', que e string literal em YAML.
    #
    #    "a aspa que FECHA" seria afirmacao mais larga que o codigo: com aspa
    #    dobrada - o escape do YAML -, o 'IndexOf' acha a primeira metade dela,
    #    e um comentario alinhado depois disso NAO e cortado. O gemeo tem o
    #    mesmo 'IndexOf' e erra igual, entao e teto COMPARTILHADO e nao
    #    divergencia; esta no backlog item 57. Achado do qa-reviewer, que
    #    cobrou a afirmacao, nao o comportamento.
    #
    #    O que este ramo NAO pode fazer e devolver o miolo ate a aspa que
    #    fecha. Em YAML a aspa escapada e a aspa DOBRADA, e o 'IndexOf' cai na
    #    primeira metade dela: o valor
    #        criterio: 'o relatorio diz __pronto__'
    #    escrito com aspas dobradas em volta de 'pronto' voltava aqui como
    #    'o relatorio diz ' - TRUNCADO, sem erro e sem lacuna -, enquanto o
    #    gemeo devolvia a frase inteira. Quinta divergencia medida entre os
    #    leitores desta plataforma, e a que a docstring de 'Get-ValorSemAspas'
    #    no gemeo ja registrava. Achado do qa-reviewer na terceira rodada, em
    #    resposta direta a pergunta "alinhar a chave criou divergencia nova?".
    #
    #    Por isso a estrutura e a de la, em DOIS passos: aqui so se corta
    #    comentario; tirar UM par das pontas e do 'Get-ChaveSemAspasDoManifesto',
    #    que exige par e nao toca no que esta no meio.
    if ($v.Length -ge 2 -and ($v[0] -eq '"' -or $v[0] -eq "'")) {
        $fecha = $v.IndexOf($v[0], 1)
        if ($fecha -gt 0) {
            $depois = $v.Substring($fecha + 1)
            if ($depois -match '^\s+#') { $v = $v.Substring(0, $fecha + 1) }
        }
    } elseif ($v -match '^(.*?)\s#') {
        # '\s#', e nao o literal ' #': com TAB antes do comentario o corte nao
        # acontecia, e 'tests: true<TAB># roda a suite' era lido como
        # 'true<TAB># roda a suite'. Isso fazia 'DeclaraTests' virar falso e
        # desarmava a UNICA regra FAIL da dimensao manifesto - fail-open no
        # detector mais barato da subfase. Sexta divergencia entre os gemeos,
        # agora achada tambem aqui.
        $v = $Matches[1]
    }

    # 2. Valor que e SO comentario e valor AUSENTE. Em YAML,
    #      comando:  # preencher depois
    #    e null - e a remocao acima nao alcanca, porque depois do Trim() o '#'
    #    fica na posicao 0. Sem esta linha o leitor devolvia
    #    '# preencher depois' como se fosse o comando de verificacao, e a
    #    dimensao manifesto saia PASS afirmando um criterio que ninguem
    #    declarou.
    $v = $v.Trim()
    if ($v.StartsWith('#')) { return '' }
    return $v
}

function ConvertFrom-EscalarDoManifesto {
    # O escalar completo: comentario fora, e UM par de aspas fora - e so
    # quando ha par, pela mesma funcao que trata a chave, porque o gemeo
    # tambem usa uma so. '.Trim()' com aspa come aspa sem par e corrompe.
    param([string]$Bruto)
    return (Get-ChaveSemAspasDoManifesto (Remove-ComentarioDoEscalar $Bruto))
}

function Get-CampoDoProjeto {
    <#
      Le um campo pelo caminho pontuado, a partir de uma raiz ja lida.

        Get-CampoDoProjeto -Raiz $m -Caminho 'verificacao.comando'

      -Opcional muda o CONTRATO, nao so o tipo de retorno: sem ele, campo
      ausente LANCA; com ele, devolve $null. O doctor precisa dos dois, e a
      diferenca importa - 'ausente' e uma resposta legitima para
      'ambiente.dependencias' e e defeito para 'identidade.nome'.
    #>
    param(
        [Parameter(Mandatory = $true)]$Raiz,
        [Parameter(Mandatory = $true)][string]$Caminho,
        [switch]$Opcional
    )
    $atual = $Raiz
    $andado = @()
    foreach ($parte in ($Caminho -split '\.')) {
        if ($atual -is [pscustomobject] -and $atual.PSObject.Properties.Name -contains 'NaoLegivel') {
            throw "project.yaml: um trecho de '$Caminho' e $($atual.NaoLegivel), que este leitor nao le."
        }
        if ($atual -isnot [System.Collections.Hashtable]) {
            if ($Opcional) { return $null }
            throw "project.yaml: '$($andado -join '.')' nao e um bloco, entao '$Caminho' nao existe."
        }
        if (-not $atual.ContainsKey($parte)) {
            if ($Opcional) { return $null }
            $andado += $parte
            throw "project.yaml nao declara '$Caminho' (parou em '$($andado -join '.')')."
        }
        $andado += $parte
        $atual = $atual[$parte]
    }

    if ($atual -is [pscustomobject] -and $atual.PSObject.Properties.Name -contains 'NaoLegivel') {
        throw "project.yaml declara '$Caminho' como $($atual.NaoLegivel), que este leitor nao le."
    }
    # Lista e array vazio sao valores legitimos para o doctor - e o que
    # 'dependencias: []' significa. Voltam como estao.
    #
    # A VIRGULA nao e enfeite, e a ausencia dela era defeito: 'return @()' no
    # PowerShell colapsa para $null no chamador, entao 'dependencias: []'
    # chegava indistinguivel de campo AUSENTE. Declaracao explicita de "nao
    # tenho dependencia verificavel" virava "ainda nao declarei" - exatamente
    # a distincao que a mantenedora fixou, apagada por uma regra da linguagem.
    # O operador virgula preserva o array vazio. Medido pelo par de casos.
    if ($atual -is [System.Collections.ArrayList] -or $atual -is [array]) { return ,@($atual) }
    if ($atual -is [System.Collections.Hashtable]) {
        if ($Opcional) { return $null }
        $vazio = ''
        if ($atual.Count -eq 0) { $vazio = ' vazio' }
        throw "project.yaml declara '$Caminho' como bloco$vazio, nao como valor."
    }

    $v = ("" + $atual)
    # IsNullOrWhiteSpace, nao '-not $v': string de tres espacos e TRUTHY no
    # PowerShell, e 'declarado vazio' nao e 'declarado'.
    if ([string]::IsNullOrWhiteSpace($v)) {
        if ($Opcional) { return $null }
        throw "project.yaml declara '$Caminho' VAZIO (ou so com espacos)."
    }
    if ($v.StartsWith('{{')) {
        throw "project.yaml ainda tem placeholder em '$Caminho': a instanciacao nao terminou."
    }
    return $v
}

# =============================================================================
# Dimensao MANIFESTO
#
# Acima e leitor - generico, sem politica. Daqui para baixo e a politica do
# doctor sobre o que o manifesto precisa declarar. A separacao importa: quem
# quiser so ler um campo nao deve herdar veredito.
# =============================================================================

function Get-DiagnosticoManifesto {
    param([Parameter(Mandatory = $true)][string]$Raiz)

    $cob = @{
        Existe          = $false
        Legivel         = $false
        CamposObrigatorios = 0
        CamposAusentes  = 0
        DeclaraTests    = $false
        TemPastaTests   = $false
    }
    $achados = @()
    $verif = @()
    $naoVerificado = @()

    $arq = Join-Path $Raiz 'project.yaml'
    $cob.Existe = (Test-Path $arq -PathType Leaf)
    if (-not $cob.Existe) {
        $achados += New-AchadoDoDoctor -Severidade 'FAIL' -Dimensao 'manifesto' `
            -Mensagem 'nao existe project.yaml: o projeto nao declara o que e, e nao ha declaracao para conferir contra o disco' `
            -Caminho 'project.yaml' -Acao 'crie o manifesto a partir de templates/project-standard/project.yaml'
        return [pscustomobject]@{
            Dimensao = (New-DimensaoDoDoctor -Nome 'manifesto' -Status 'FAIL' -Cobertura $cob -Achados $achados `
                          -Motivo 'sem manifesto, nenhuma das perguntas condicionais do doctor pode ser respondida')
            Raiz = $null
        }
    }

    $m = $null
    try { $m = Read-ManifestoDoDoctor -Caminho $arq }
    catch {
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que 'o conteudo do project.yaml' -Porque $_.Exception.Message
        return [pscustomobject]@{
            Dimensao = (New-DimensaoDoDoctor -Nome 'manifesto' -Status 'INCONCLUSIVO' -Cobertura $cob -NaoVerificado $naoVerificado `
                          -Motivo 'o manifesto existe e nao foi lido: o que ele declara e desconhecido')
            Raiz = $null
        }
    }
    $cob.Legivel = $true

    foreach ($campo in @('identidade.nome', 'classificacao.criticidade', 'verificacao.comando')) {
        $cob.CamposObrigatorios++
        $v = $null
        # O 'catch' NAO pode devolver silencio. 'Get-CampoDoProjeto' LANCA de
        # proposito quando o valor ainda e placeholder de instanciacao - que e o
        # estado exato de um projeto copiado do template pelo /os:new-project e
        # nao terminado. Engolindo a excecao, o campo virava "ausente": a
        # dimensao dizia "o manifesto nao declara 'identidade.nome'" sobre um
        # campo que ESTA declarado, com WARN e exit 0. Afirmacao falsa somada a
        # fail-open, pela terceira vez nesta subfase e sempre no ramo ao lado
        # do que acabou de ser endurecido. Achado do qa-reviewer na sexta rodada.
        $porqueNaoLeu = $null
        try { $v = Get-CampoDoProjeto -Raiz $m -Caminho $campo -Opcional } catch { $porqueNaoLeu = "" + $_.Exception.Message }
        if ($null -ne $porqueNaoLeu) {
            $naoVerificado += New-NaoVerificadoDoDoctor -O_que "se '$campo' esta declarado" -Porque $porqueNaoLeu
            continue
        }
        if ([string]::IsNullOrWhiteSpace(("" + $v))) {
            $cob.CamposAusentes++
            $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'manifesto' `
                -Mensagem "o manifesto nao declara '$campo'" -Caminho 'project.yaml' `
                -Acao "declare '$campo' no project.yaml"
        } else {
            $verif += New-VerificacaoDoDoctor -O_que $campo -Resultado ("" + $v)
        }
    }

    # Coerencia declaracao x disco. E a unica coisa desta dimensao que pode
    # dar FAIL depois de ler: 'declaracao nao e verificacao' e o principio que
    # a 2.4 escreveu, e um manifesto que afirma ter testes sobre uma pasta
    # inexistente e a forma mais barata de mentir para quem chega.
    # UM rotulo para UM fato, numa constante - e o fato de ter medido carregado
    # numa VARIAVEL do fluxo, nao reconstruido no fim por comparacao de string.
    #
    # A versao anterior perguntava, no fim, se existia lacuna com o literal
    # escrito a mao. Funcionava aqui e NAO funcionava em 'retomabilidade', onde
    # havia dois rotulos para o mesmo fato: a guarda passava e o artefato
    # voltava a afirmar o que a dimensao dissera nao ter medido. Guarda por
    # string tem a mesma fragilidade do defeito que ela conserta - trocar o
    # texto da lacuna a desarma em silencio. Achado do qa-reviewer na oitava
    # rodada.
    $ROTULO_TESTS = 'verificacao.tests coerente com o disco'
    $mediuTests = $true

    $t = $null
    $porqueTests = $null
    try { $t = Get-CampoDoProjeto -Raiz $m -Caminho 'verificacao.tests' -Opcional } catch { $porqueTests = "" + $_.Exception.Message }
    if ($null -ne $porqueTests) {
        # Mesmo motivo do laco acima, e aqui e a UNICA regra FAIL da dimensao:
        # placeholder de instanciacao fazia 'DeclaraTests' virar falso e a regra
        # nao disparar, sem ninguem dizer por que.
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que $ROTULO_TESTS -Porque $porqueTests
        $mediuTests = $false
    }
    $cob.DeclaraTests = ((("" + $t).Trim().ToLower()) -eq 'true')

    # 'declarei algo que voce nao entendeu' NAO pode colapsar em 'nao declarei'.
    # Valor presente que nao e nem 'true' nem 'false' saia daqui em SILENCIO, e
    # a UNICA regra FAIL da dimensao simplesmente nao disparava. O caso concreto
    # e 'tests: true# nota': em YAML o '#' sem espaco antes NAO abre comentario,
    # entao o valor e mesmo 'true# nota' - os dois leitores concordam e os dois
    # estao certos. O defeito nao e a leitura, e esta dimensao nao dizer nada
    # sobre um valor que ela nao reconheceu. Contestacao de severidade do
    # security-reviewer na quinta rodada, aceita: nao e fail-open do leitor, mas
    # e 'nao verifiquei' virando 'esta bom', que a politica 4.5 proibe.
    $tBruto = ("" + $t).Trim()
    if ($tBruto -and ($tBruto.ToLower() -ne 'true') -and ($tBruto.ToLower() -ne 'false')) {
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que $ROTULO_TESTS `
            -Porque "'verificacao.tests' esta declarado com um valor que nao e 'true' nem 'false', e esta dimensao nao sabe o que ele significa. A regra que compara a declaracao com a pasta tests/ NAO foi aplicada"
        $mediuTests = $false
    }
    $cob.TemPastaTests = (Test-Path (Join-Path $Raiz 'tests') -PathType Container)
    if ($cob.DeclaraTests -and -not $cob.TemPastaTests) {
        $achados += New-AchadoDoDoctor -Severidade 'FAIL' -Dimensao 'manifesto' `
            -Mensagem "o manifesto declara 'verificacao.tests: true' e nao existe pasta tests/ no disco" `
            -Caminho 'project.yaml' -Acao 'crie a suite, ou corrija a declaracao - estrutura vazia e o que a politica 4.4 proibe'
    }
    # SO emite quando houve o que verificar, e o criterio e '$mediuTests' - um
    # fato do fluxo, nao uma string reconstruida. Com o campo AUSENTE a resposta
    # honesta e 'nao se aplica', e nao 'True': afirmar verdade VACUA como
    # verificacao feita era o segundo lado do mesmo achado.
    if ($mediuTests) {
        if ([string]::IsNullOrWhiteSpace(("" + $t))) {
            $verif += New-VerificacaoDoDoctor -O_que $ROTULO_TESTS `
                -Resultado 'nao se aplica: o manifesto nao declara verificacao.tests'
        } else {
            $verif += New-VerificacaoDoDoctor -O_que $ROTULO_TESTS `
                -Resultado ([string](-not ($cob.DeclaraTests -and -not $cob.TemPastaTests)))
        }
    }

    $status = 'PASS'
    $motivo = 'o manifesto declara o minimo e nao contradiz o disco'
    if (@($achados | Where-Object { $_.Severidade -eq 'WARN' }).Count -gt 0) { $status = 'WARN'; $motivo = 'o manifesto tem campo obrigatorio ausente' }
    if (@($achados | Where-Object { $_.Severidade -eq 'FAIL' }).Count -gt 0) { $status = 'FAIL'; $motivo = 'o manifesto declara o que o disco contradiz' }
    # Lacuna declarada DOMINA. Esta dimensao computava o status so a partir dos
    # achados, entao um 'NaoVerificado' era decorativo: saia no relatorio e nao
    # mexia no status nem no codigo de saida - enquanto 'retomabilidade' ja
    # respeitava o seu. Duas dimensoes com regras diferentes para o mesmo fato,
    # e a mais permissiva era a que guarda a UNICA regra FAIL do manifesto.
    # "Nao verifiquei" nunca vira "esta bom": politica 4.5.
    if (@($naoVerificado).Count -gt 0) {
        $status = 'INCONCLUSIVO'
        $motivo = 'a dimensao nao conseguiu verificar parte do que ela promete verificar'
    }

    return [pscustomobject]@{
        Dimensao = (New-DimensaoDoDoctor -Nome 'manifesto' -Status $status -Cobertura $cob `
                      -Verificacoes $verif -Achados $achados -NaoVerificado $naoVerificado -Motivo $motivo)
        Raiz = $m
    }
}
