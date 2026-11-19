<#
.SYNOPSIS
    Excecoes de seguranca aprovadas: legiveis por maquina, estreitas e citaveis.

.DESCRIPTION
    Decisao da Emmily na subfase 2.3, registrada no ADR-0010. O problema que
    isto resolve: o ADR-0009 nao previa 'MEDIA aceita', entao um achado real
    analisado e aceito deliberadamente fazia o scanner sair com 1 para sempre -
    e detector que trava sempre e detector que se aprende a ignorar.

    Quatro regras que definem o mecanismo, e cada uma existe contra um modo de
    falha concreto:

      1. NAO SILENCIA. O achado continua no relatorio, com a severidade
         original, e ganha a disposicao ACEITO-POR-EXCECAO mais a citacao da
         excecao que o cobre. Aceitar e uma decisao registrada, nao um
         apagamento.

      2. CORRESPONDENCIA EXATA de caminho E categoria. Nao existe allowlist
         por dominio, por extensao, por diretorio nem por padrao. Um achado
         parecido em outro arquivo continua bloqueando; o MESMO arquivo com
         outra categoria de achado continua bloqueando.

      3. SO VALE NO FLUXO PRIVADO AUTORIZADO. Sob '-ParaPublicacao', toda
         excecao e ignorada e o achado bloqueia. Publicar exige sanitizar.

      4. PENDENTE NAO E ACEITA. Entrada cujo 'status' nao seja exatamente
         'aceito-por-excecao' nao cobre nada. Declarar que a excecao existe e
         diferente de decidir aceita-la - foi a contradicao que o
         security-reviewer pegou no manifesto.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-StatusDeExcecaoAceita {
    # Valor unico e exato. 'aceita', 'aprovado', 'ok' nao contam: status
    # aproximado abre a porta para aceitacao por descuido de digitacao.
    return 'aceito-por-excecao'
}

function Get-DisposicaoAceita {
    return 'ACEITO-POR-EXCECAO'
}

function Get-ExcecoesDeSeguranca {
    <#
      Le 'classificacao.dados_sensiveis_excecoes' do project.yaml do
      repositorio varrido.

      Parser proprio e deliberadamente pequeno: a plataforma nao tem
      dependencia de YAML, e trazer uma para ler quatro campos seria custo
      novo em toda maquina que rodar isto. Em troca, o formato aceito e
      estrito - uma entrada comeca com '- caminho:' e os campos dela sao
      'chave: "valor"' indentados abaixo. Campo fora desse formato nao e lido,
      e nao ser lido significa NAO COBRIR NADA: o erro cai para o lado
      seguro, que e continuar bloqueando.

      Devolve tambem as entradas nao aceitas, para o relatorio poder dizer que
      existem sem que elas cubram achado nenhum.
    #>
    param([string]$Path)

    $vazio = [pscustomobject]@{ Aceitas = @(); NaoAceitas = @(); Arquivo = $null }
    $yaml = Join-Path $Path 'project.yaml'
    if (-not (Test-Path $yaml)) { return $vazio }

    # LANCA, e nao devolve vazio: excecao que a mantenedora decidiu e que a
    # ferramenta nao conseguiu ler nao pode virar "nao ha excecao" em
    # silencio. Vazio aqui erra para o lado seguro no veredito - bloqueia mais
    # - mas mente sobre o que foi lido, e o relatorio afirmaria que o
    # project.yaml foi consultado.
    $txt = Read-TextoDeArquivo $yaml
    if ($null -eq $txt) {
        throw "'$yaml' nao e legivel como texto (UTF-8 invalido, ou NUL no conteudo). As excecoes aprovadas NAO foram lidas, e esta varredura nao pode afirmar nada sobre elas. Salve o project.yaml em UTF-8 e rode de novo."
    }
    $m = [regex]::Match($txt, '(?ms)^\s*dados_sensiveis_excecoes:\s*\r?\n(.*?)(?=^\s{0,2}[a-z_]+:|\z)')
    if (-not $m.Success) { return $vazio }

    # ENTRADA e reconhecida pelo marcador de lista '-', em QUALQUER ordem de
    # chave. Nao por '- caminho:'.
    #
    # A versao anterior exigia 'caminho' como PRIMEIRA chave, e YAML nao impoe
    # ordem de chave - o ADR-0010 tampouco. O qa-reviewer derivou o cenario
    # fail-OPEN, e ele e alcancavel com YAML valido: numa segunda entrada
    # escrita com 'categoria' antes de 'caminho', a linha '- categoria:' nao
    # casava nem inicio nem campo, NENHUMA entrada nova nascia, e a linha
    # 'caminho:' seguinte sobrescrevia o caminho da entrada 1 - que mantinha
    # categoria, justificativa e 'status: aceito-por-excecao'. Resultado: a
    # varredura passava a aceitar um par (caminho, categoria) que a
    # mantenedora nunca decidiu, e 'NaoAceitas' ficava vazio, entao nao havia
    # sinal nenhum. Mesma familia do defeito de prefixo desta rodada:
    # ampliacao silenciosa por suposicao sobre layout de texto.
    #
    # E no caso de UMA entrada com qualquer chave antes de 'caminho', a
    # excecao ficava invisivel nas duas listas - recriando o modo de falha
    # que a emenda 3 do ADR-0010 existe para eliminar.
    $aceitas = @()
    $naoAceitas = @()

    function New-EntradaVazia {
        return [pscustomobject]@{
            caminho = ''; categoria = ''; natureza = ''; justificativa = ''
            decisao = ''; status = ''; decidido_em = ''; escopo = ''
            onde_esta_registrado = ''
        }
    }

    $entradas = @()
    $atual = $null
    foreach ($linha in ($m.Groups[1].Value -split "`r?`n")) {
        if ($linha -match '^\s*#') { continue }
        if (-not $linha.Trim()) { continue }
        $ehInicio = $linha -match '^\s*-\s'
        if ($ehInicio) {
            if ($atual) { $entradas += $atual }
            $atual = New-EntradaVazia
            # O primeiro campo pode vir na propria linha do '-'.
            $linha = ($linha -replace '^\s*-\s+', '        ')
        }
        if (-not $atual) { continue }
        $campo = [regex]::Match($linha, '^\s+([a-z_]+):\s*"([^"]*)"\s*$')
        if ($campo.Success) {
            $nome = $campo.Groups[1].Value
            if ($atual.PSObject.Properties.Name -contains $nome) {
                $atual.$nome = $campo.Groups[2].Value
            }
        }
    }
    if ($atual) { $entradas += $atual }

    # Um portao so, aplicado a todas as entradas. Antes eram dois pontos de
    # decisao para a mesma regra - o do laco e o da descarga final - e um
    # deles ficou para tras numa substituicao, justamente o que trata lista de
    # uma entrada.
    foreach ($e in $entradas) {
        if (Test-ExcecaoAceita $e) { $aceitas += $e } else { $naoAceitas += $e }
    }

    return [pscustomobject]@{ Aceitas = @($aceitas); NaoAceitas = @($naoAceitas); Arquivo = 'project.yaml' }
}

function Test-ExcecaoAceita {
    <#
      Aceita = status exato E completa. As DUAS coisas.

      Separar so pelo status era violacao da regra 4 do ADR-0010, que exige
      que entrada com campo obrigatorio faltando "nao cubra nada" E apareca
      na subsecao propria do relatorio. Como 'Aceitas' era decidido apenas
      pelo status, a incompleta caia ali, era descartada em silencio na hora
      do casamento, e NUNCA aparecia na lista de "excecoes que nao cobrem
      nada" - que itera 'NaoAceitas'.

      O cenario que o qa-reviewer descreveu: a mantenedora escreve a
      justificativa em bloco dobrado ('justificativa: >'), formato que este
      parser estrito nao le. A varredura sai com 1, o relatorio mostra o
      achado como bloqueante comum, e nao diz uma palavra sobre a excecao
      rejeitada. Ela nao teria como distinguir "excecao malformada" de
      "excecao nao casou".
    #>
    param($Excecao)
    if ($Excecao.status -ne (Get-StatusDeExcecaoAceita)) { return $false }
    return (Test-ExcecaoCompleta $Excecao)
}

function Test-ExcecaoCompleta {
    <#
      Excecao aceita precisa dizer o QUE cobre, POR QUE e QUEM decidiu.
      Faltando qualquer um, ela nao cobre nada - e o relatorio diz por que.
      Sem isto, 'status: aceito-por-excecao' com o resto vazio seria uma
      allowlist de uma linha.
    #>
    param($Excecao)
    foreach ($c in @('caminho', 'categoria', 'justificativa', 'decisao', 'decidido_em')) {
        # IsNullOrWhiteSpace, nao '-not'. No PowerShell "   " e TRUTHY, entao
        # uma entrada com justificativa, decisao e decidido_em preenchidos so
        # com ESPACO contava como completa - e com o status exato passava a
        # dispor achado MEDIA no fluxo privado. A docstring desta funcao diz
        # exatamente o que ela existe para impedir: "status aceito-por-excecao
        # com o resto vazio seria uma allowlist de uma linha". Espaco em branco
        # vencia a guarda.
        #
        # O security-reviewer achou isto na rodada em que o MESMO padrao foi
        # corrigido no harness do template: eu endureci o harness de TESTE e
        # deixei o PORTAO DE SEGURANCA com a checagem antiga. Assimetria no
        # sentido errado.
        if ([string]::IsNullOrWhiteSpace(("" + $Excecao.$c))) { return $false }
    }
    return $true
}

function Get-ExcecaoQueCobre {
    <#
      Correspondencia por IGUALDADE de caminho E de categoria. Devolve a
      excecao, ou $null.

      A versao anterior comparava o caminho declarado contra o INICIO do
      'Detalhe', que e prosa - 'arquivo linha ~N, ...'. Isso era comparacao
      por PREFIXO, e os dois revisores independentes pegaram na mesma rodada:

        (a) excecao para 'docs/audits/x.md' cobria tambem 'docs/audits/x.md.old'
            e qualquer nome irmao que comecasse com a string declarada;
        (b) 'caminho: "docs"' cobria a arvore INTEIRA naquela categoria - a
            allowlist por diretorio que o ADR-0010 diz ter recusado.

      E o teste que devia provar a regra ('achado PARECIDO em OUTRO arquivo
      continua bloqueando') usava dois nomes SEM prefixo comum, entao passava
      com StartsWith, com -like ou com igualdade: verde sobre ramo nao
      exercitado. Pior, o relatorio AFIRMAVA ao leitor "correspondencia exata
      de caminho E categoria" - garantia que o codigo nao entregava.

      A causa raiz nao era o StartsWith: era extrair caminho de prosa. O
      achado agora carrega 'Caminho' como campo estruturado (ver New-Achado),
      e aqui e igualdade. Achado sem caminho NAO casa - falha fechado.
    #>
    param($Achado, $Aceitas)
    if (-not $Aceitas) { return $null }
    # Sem caminho estruturado nao ha o que comparar, e adivinhar seria voltar
    # ao defeito. Achado assim continua bloqueando.
    $camAchado = ''
    if ($Achado.PSObject.Properties.Name -contains 'Caminho') {
        $camAchado = ("" + $Achado.Caminho) -replace '\\', '/'
    }
    if (-not $camAchado) { return $null }

    foreach ($e in $Aceitas) {
        if (-not (Test-ExcecaoCompleta $e)) { continue }
        if ($e.categoria -ne $Achado.Categoria) { continue }
        $camExc = (("" + $e.caminho) -replace '\\', '/').TrimEnd('/')
        if ($camAchado -eq $camExc) { return $e }
    }
    return $null
}

function Set-DisposicaoDosAchados {
    <#
      Marca cada achado coberto por excecao aprovada, e devolve o resumo para
      o relatorio.

      -ParaPublicacao ignora TODA excecao: publicacao exige sanitizacao, e
      excecao de fluxo privado nao atravessa essa fronteira. Sem esta guarda o
      mecanismo viraria autorizacao geral, que e exatamente o que ele nao e.
    #>
    param($Achados, $Aceitas, [switch]$ParaPublicacao)

    $disp = Get-DisposicaoAceita
    $cobertos = 0
    $recusadosPorSeveridade = 0
    $usadas = @{}
    foreach ($a in $Achados) {
        Add-Member -InputObject $a -NotePropertyName 'Disposicao' -NotePropertyValue '' -Force
        Add-Member -InputObject $a -NotePropertyName 'ExcecaoCitada' -NotePropertyValue '' -Force
        if ($ParaPublicacao) { continue }
        # ALTA nunca e coberta por excecao. Limite ESTREITO por decisao, e
        # deliberadamente do lado de recusar.
        #
        # O mecanismo e agnostico de area - percorre todos os achados -, mas o
        # campo se chama 'dados_sensiveis_excecoes' e o ADR-0010 foi escrito
        # inteiro em torno de dado pessoal. O security-reviewer apontou a
        # distancia: uma entrada com categoria de credencial dispensaria um
        # achado ALTA de working tree e o scanner sairia com 0. Neste
        # repositorio governante, e a diferenca entre "aceitar um e-mail num
        # relatorio de auditoria" e "dispensar um token vivo".
        #
        # Alargar isso e decisao da mantenedora, nao inferencia. Enquanto ela
        # nao decidir, ALTA bloqueia - e o relatorio diz que recusou.
        if ($a.Severidade -eq 'ALTA') { $recusadosPorSeveridade++; continue }
        $e = Get-ExcecaoQueCobre -Achado $a -Aceitas $Aceitas
        if ($e) {
            $a.Disposicao = $disp
            $a.ExcecaoCitada = ('{0} | {1} | decidido em {2}' -f $e.caminho, $e.categoria, $e.decidido_em)
            $cobertos++
            $usadas[$e.caminho + '||' + $e.categoria] = $e
        }
    }
    # Montado em $cob como todo bloco de cobertura desta plataforma. Nao e
    # estilo: e a convencao que o guarda "todo campo de Cobertura criado e
    # LIDO" usa para saber ONDE olhar, e ele exige que cada detector tenha
    # a sua. Enquanto este objeto era devolvido direto, os quatro campos
    # ficavam fora do alcance do guarda - inclusive "Cobertos", que foi o
    # campo orfao que o proprio guarda achou na rodada 9. Achado do
    # qa-reviewer na rodada 11: a lista branca tinha virado o NOME DA
    # VARIAVEL, e ninguem a tinha declarado como lista.
    $cob = @{
        Cobertos = $cobertos
        Usadas = @($usadas.Values)
        RecusadosPorSeveridade = $recusadosPorSeveridade
        ParaPublicacao = [bool]$ParaPublicacao
    }
    return [pscustomobject]$cob
}
