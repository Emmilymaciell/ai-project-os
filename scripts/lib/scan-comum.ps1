<#
.SYNOPSIS
    Pecas compartilhadas pelos detectores do security-scan.

.DESCRIPTION
    Carregado por dot-source pelo scripts/security-scan.ps1.

    Cada detector vive num arquivo proprio de scripts/lib/ e e uma FUNCAO
    PURA: recebe o caminho do repositorio, devolve achados. Nao escreve
    arquivo, nao chama exit, nao emite veredito. Quem monta o relatorio e
    decide o codigo de saida e o orquestrador.

    O motivo do desenho e a politica 4.1: todo detector precisa de teste
    positivo E negativo. Detector embutido no meio de um script grande so se
    testa pela ponta - foi assim que a subfase 2.2 chegou a ter dois scripts
    sem um unico teste funcional. Funcao pura se testa direto.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

# =============================================================================
# Severidade - ver ADR-0009
# =============================================================================
# ALTA  : algo indevido esta exposto, ou entraria num commit agora.
# MEDIA : algo questionavel esta presente e exige decisao de uma pessoa.
# BAIXA : fato registrado para contestacao - guarda-corpo ausente, fixture
#         declarada, identidade do proprio autor. NAO trava o fluxo.
#
# A escada e sobre EXPOSICAO, nao sobre importancia. Guarda-corpo ausente e
# risco, nao vazamento; por isso e BAIXA - e por isso BAIXA continua no
# relatorio em vez de ser silenciada.

function New-Achado {
    <#
      'Caminho' e campo ESTRUTURADO, e existe por causa de um defeito real.

      A correspondencia de excecao aprovada comparava o caminho declarado
      contra o INICIO da string 'Detalhe', que e prosa - 'arquivo linha ~N,
      ...'. Isso e comparacao por prefixo, e os dois revisores independentes
      pegaram: uma excecao para 'docs/audits/x.md' cobria tambem
      'docs/audits/x.md.old', e uma excecao declarada como 'docs' cobria a
      arvore inteira naquela categoria - exatamente a allowlist por diretorio
      que o ADR-0010 diz ter recusado.

      A causa raiz nao era o StartsWith: era extrair caminho de prosa. Com o
      caminho num campo proprio, a comparacao e igualdade e o ramo perigoso
      deixa de existir. Achado sem caminho ('') NAO casa com excecao nenhuma -
      falha fechado.
    #>
    param(
        [ValidateSet('ALTA', 'MEDIA', 'BAIXA')][string]$Severidade,
        [string]$Categoria,
        [string]$Detalhe,
        [ValidateSet('working tree', 'historico', 'staging', 'gitignore',
                     'dado de terceiro', 'exposicao externa')]
        [string]$Area = 'working tree',
        [string]$Caminho = ''
    )
    return [pscustomobject]@{
        Severidade = $Severidade
        Categoria  = $Categoria
        Detalhe    = $Detalhe
        Area       = $Area
        # Normalizado para barra normal: o relatorio usa a forma do
        # 'git ls-files', e o YAML pode ter sido escrito de qualquer jeito.
        Caminho    = ($Caminho -replace '\\', '/')
    }
}

# As seis areas sobre as quais o security-reviewer emite veredito parcial.
# A lista vive aqui porque o relatorio e o agente tem de concordar sobre ela.
function Get-AreasDeVeredito {
    return @('working tree', 'historico', 'staging', 'gitignore',
             'dado de terceiro', 'exposicao externa')
}

# =============================================================================
# Padroes
# =============================================================================

function Get-PadraoNomeSensivel {
    # Nomes que nunca deveriam estar rastreados, nem agora nem no historico.
    return '(^|/)\.env$|\.(key|pem|pfx|p12|jks|keystore)$|(^|/)credentials\.json$|(^|/)secrets\.(json|ya?ml)$|(^|/)id_(rsa|dsa|ecdsa|ed25519)$|\.msal_cache'
}

function Get-PadroesConteudo {
    # Prefixos de credencial real, nao a palavra "senha" num comentario.
    # Padrao generico de "password" produz falso positivo em documentacao, e
    # scanner que grita sempre e ignorado - o que e pior que nao ter scanner.
    return @(
        @{ nome = 'token do GitHub';        re = 'gh[pousr]_[A-Za-z0-9]{16,}' },
        @{ nome = 'PAT fino do GitHub';     re = 'github_pat_[A-Za-z0-9_]{20,}' },
        @{ nome = 'chave da Anthropic';     re = 'sk-ant-[A-Za-z0-9_\-]{20,}' },
        @{ nome = 'chave OpenAI-like';      re = 'sk-[A-Za-z0-9]{32,}' },
        @{ nome = 'access key da AWS';      re = 'AKIA[0-9A-Z]{16}' },
        @{ nome = 'chave privada PEM';      re = '-----BEGIN [A-Z ]*PRIVATE KEY-----' },
        @{ nome = 'token Bearer literal';   re = 'Bearer [A-Za-z0-9_\-\.]{20,}' },
        @{ nome = 'string de conexao';      re = '(?i)(mongodb|postgres|mysql|redis)://[^\s:]+:[^\s@]+@' }
    )
}

function Get-ExtensoesTexto {
    # MEDIDO, e corrige um erro do ciclo anterior: para o .NET, '.npmrc' e
    # '.gitkeep' tem EXTENSAO - 'GetExtension(".npmrc")' devolve '.npmrc', nao
    # string vazia. Entao adiciona-los a lista de nomes-sem-extensao era
    # codigo morto: aquele ramo nunca rodava para eles, e a observacao do
    # security-reviewer sobre '.npmrc' nao tinha sido fechada de verdade.
    # O lugar deles e aqui.
    #
    # '.gitkeep' entra porque e marcador vazio por convencao, e ficava
    # contado como "sem extensao de texto" em toda execucao - lacuna que o
    # revisor precisou fechar a mao em duas rodadas seguidas.
    #
    # '.manifest' (r13, S4): 'cofre.manifest'/'secrets.manifest' listam NOMES de
    # segredo e onde vivem - texto que o scanner tem de ler, para que um valor
    # colado ali por engano seja visto.
    return @('.md','.txt','.ps1','.py','.js','.ts','.json','.yaml','.yml',
             '.csv','.tsv','.xml','.html','.css','.sh','.bat','.cmd','.sql',
             '.env','.example','.cfg','.ini','.toml','.conf',
             '.gitignore','.gitattributes','.gitkeep',
             '.npmrc','.netrc','.pypirc',
             '.manifest')
}

function Test-ArquivoDeTexto {
    <#
      Este arquivo deve ser lido como texto?

      O NOME mudou junto com a pergunta, e nao por gosto: enquanto ela se
      chamava 'Test-ExtensaoDeTexto' ela prometia decidir pela extensao, e era
      isso que fazia - inclusive para arquivo que NAO TEM extensao, onde a
      unica saida era uma lista de nomes.

      A lista falhou TRES vezes, sempre igual e sempre com roupa diferente:
      '.npmrc' (achado do security-reviewer), '.gitkeep' (lacuna que o revisor
      fechou a mao em duas rodadas), e agora 'githooks/commit-msg',
      'pre-commit' e 'pre-push' - os primeiros arquivos SEM EXTENSAO que este
      repositorio versiona, e justamente os que EXECUTAM a cada commit. Eles
      sairam do coletor como "nao e texto reconhecido", o que significa que os
      revisores nao veriam o codigo que roda na maquina da mantenedora.

      A regra desta casa para guarda que falha pela terceira vez pelo mesmo
      motivo e trocar a PERGUNTA, nao acrescentar a quarta entrada na lista.
      Entao:

        tem extensao        -> a lista de extensoes decide, como antes;
        nome conhecido      -> continua valendo (Jenkinsfile, Dockerfile...);
        sem extensao        -> decide o CONTEUDO: byte NUL nos primeiros 8 KB
                               significa binario. E como o proprio Git decide,
                               e como 'New-ProjetoDeTeste' ja decidia no
                               harness - a regra existia na casa, sem estar
                               aqui.

      Isto so ALARGA cobertura: nenhum arquivo que hoje e lido deixa de ser.
      E continua fail-closed - arquivo que nao da para abrir devolve $false, e
      quem chama declara a lacuna.

      -Raiz e necessario porque os chamadores passam caminho RELATIVO a raiz do
      repositorio (e o que 'git status' devolve). Sem ela, um caminho relativo
      seria resolvido contra o diretorio corrente, que nao e o repositorio.
    #>
    param([string]$Caminho, [string]$Raiz)

    $ext = [System.IO.Path]::GetExtension($Caminho).ToLower()
    if ($ext) { return ((Get-ExtensoesTexto) -contains $ext) }

    # So nome SEM ponto chega aqui. Arquivo de ponto ('.npmrc', '.gitkeep')
    # tem extensao para o .NET e e tratado na lista - ver Get-ExtensoesTexto.
    $base = [System.IO.Path]::GetFileName($Caminho)
    if (@('Jenkinsfile', 'Dockerfile', 'Makefile') -contains $base) { return $true }

    $abs = $Caminho
    try {
        if ($Raiz -and -not [System.IO.Path]::IsPathRooted($abs)) { $abs = Join-Path $Raiz $Caminho }
    } catch { return $false }
    if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) { return $false }

    try {
        $fs = [System.IO.File]::OpenRead($abs)
        try {
            $buf = New-Object byte[] 8192
            $lidos = $fs.Read($buf, 0, $buf.Length)
            for ($i = 0; $i -lt $lidos; $i++) {
                if ($buf[$i] -eq 0) { return $false }
            }
        } finally { $fs.Dispose() }
    } catch { return $false }

    return $true
}

function Get-MarcadorFixture {
    # Arquivo que DECLARA este marcador tem os achados RECLASSIFICADOS para
    # BAIXA, categoria "fixture declarada". Reclassificar, nao silenciar: o
    # achado continua no relatorio, e o relatorio avisa que o marcador e
    # afirmacao de quem escreveu o arquivo, nao verificacao.
    return 'SEGREDO-FABRICADO-PARA-TESTE'
}

function Get-LinhasDeCabecalho {
    # Quantas linhas iniciais contam como cabecalho para uma declaracao.
    return 40
}

function Test-DeclaraFixture {
    <#
      Declarar e diferente de MENCIONAR, e a diferenca e de seguranca.

      A primeira versao disto era Contains() sobre o arquivo inteiro. A
      propria varredura da subfase 2.3 mostrou o furo: CHANGELOG.md e
      docs/STATE.md CITAM o marcador porque documentam a convencao, e os
      achados dos dois foram reclassificados por causa disso. Pior que o
      ruido: qualquer arquivo poderia desarmar o scanner sobre si mesmo
      escrevendo o marcador numa frase.

      Declaracao e uma afirmacao do arquivo sobre si mesmo, e isso mora no
      cabecalho. Fixture com o marcador no fim do arquivo deixa de ser
      reclassificada e passa a produzir achado ALTA - falha para o lado
      seguro, que e o lado certo para falhar.
    #>
    param([string]$Texto)
    if (-not $Texto) { return $false }
    $m = Get-MarcadorFixture
    $linhas = $Texto -split "`n"
    $n = [Math]::Min((Get-LinhasDeCabecalho), $linhas.Count)
    for ($i = 0; $i -lt $n; $i++) {
        if ($linhas[$i].Contains($m)) { return $true }
    }
    return $false
}

# =============================================================================
# Utilidades
# =============================================================================

function Measure-Linhas {
    <#
      UMA convencao de contagem de linhas, usada pelos DOIS coletores.

      Motivo, e foi um defeito grave: o carimbo de integridade nasceu com
      'ReadAllLines().Count' num coletor e '($txt -split "`n").Count' no
      outro. Para arquivo terminado em newline o segundo da +1, entao os dois
      relatorios discordavam em TODAS as linhas do carimbo. Seguindo a
      instrucao do qa-reviewer ao pe da letra - "se divergir, a coleta esta
      obsoleta" - o veredito correto seria INCONCLUSIVO com a arvore parada e
      a coleta valida. O guarda-corpo contra evidencia velha virou o detector
      que dispara sempre, que e o detector que se aprende a ignorar.

      A convencao: linhas de CONTEUDO. Um '\n' final nao cria linha vazia
      extra, e arquivo vazio tem 0 linhas. O relatorio declara isso, para que
      um leitor cujo visualizador mostre um numero a mais saiba que e
      convencao e nao deriva.
    #>
    param([string]$Texto)
    if ($null -eq $Texto -or $Texto.Length -eq 0) { return 0 }
    $t = $Texto -replace "`r`n", "`n"
    if ($t.EndsWith("`n")) { $t = $t.Substring(0, $t.Length - 1) }
    if ($t.Length -eq 0) { return 1 }
    return ($t.Split("`n")).Count
}

function Read-TextoDeArquivo {
    <#
      Le o arquivo como TEXTO, ou devolve $null quando ele NAO pode ser lido
      como texto. $null e "nao consegui ler", nunca "nao ha nada dentro": quem
      chama TEM de contar a lacuna, e nunca seguir com string vazia.

      Duas recusas, e a segunda e a que fecha o cenario do backlog item 11:

      1. Byte invalido para UTF-8. '[Text.Encoding]::UTF8' substitui por
         U+FFFD EM SILENCIO; 'UTF8Encoding($false, $true)' - o segundo
         argumento e throwOnInvalidBytes - recusa. Arquivo salvo em ANSI pelo
         Bloco de Notas, cenario que o runbook documenta como recorrente nesta
         casa, cai aqui.

      2. NUL no texto ja decodificado. NAO e redundante com a recusa 1, e
         supor que fosse era o erro do desenho anterior: UTF-16 sem BOM de
         conteudo ASCII e UTF-8 VALIDO - 'A' vira 41 00, e U+0000 e um code
         point legitimo. A leitura estrita PASSA, e devolve o texto com um NUL
         entre cada letra, que quebra todo regex de credencial. Era exatamente
         o cenario nomeado no item 11, e a leitura estrita SOZINHA nao o pega:
         medido, nao suposto. Arquivo de texto de verdade nao tem NUL.

      UTF-16 COM BOM nao cai em nenhuma das duas, e esta certo: e decodificado
      corretamente. So o caso sem BOM e indecifravel.

      POR QUE ISTO LE BYTES, e nao usa 'ReadAllText($caminho, $codificacao)':
      aquela forma abre um StreamReader com deteccao de preambulo ligada, e
      quando ha BOM reconhecido o StreamReader DESCARTA a codificacao que se
      passou e usa a dele. Para o BOM de UTF-8 ele troca pelo 'Encoding.UTF8'
      estatico, que substitui em SILENCIO - ou seja, o BOM de UTF-8
      DESARMAVA a recusa 1. Medido: 'EF BB BF 61 E7 0A' devolvia 'a', U+FFFD,
      newline, sem lancar, enquanto os mesmos bytes SEM o BOM eram recusados.
      Era o falso verde do item 11 vivo, dentro da propria correcao do item 11.
      Achado do qa-reviewer, e ele o derivou por leitura, sem executar.

      Entao o preambulo e decidido AQUI, explicitamente, e a decodificacao
      usada e sempre a estrita.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)
    # LANCA quando nao da para ABRIR, e devolve $null so quando nao da para
    # INTERPRETAR como texto. Sao dois fatos diferentes, e confundi-los manda
    # quem for consertar para o lugar errado: arquivo travado pelo OneDrive ou
    # pelo Excel - cenario real nesta casa pelo ADR-0002 - recebia a lacuna
    # "nao e legivel como texto" e a instrucao "salve em UTF-8", que nao
    # resolve nada. Achado do qa-reviewer.
    $bytes = $null
    try { $bytes = [System.IO.File]::ReadAllBytes($Caminho) }
    catch {
        throw "nao foi possivel ABRIR '$Caminho' para leitura: $($_.Exception.Message). Isto NAO e problema de codificacao - arquivo travado por outro programa, permissao ou caminho longo sao as causas comuns."
    }
    if ($null -eq $bytes -or $bytes.Length -eq 0) { return '' }

    $inicio = 0
    $codificacao = $null
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $codificacao = New-Object System.Text.UTF8Encoding($false, $true)
        $inicio = 3
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        # UnicodeEncoding(bigEndian, byteOrderMark, throwOnInvalidBytes)
        $codificacao = New-Object System.Text.UnicodeEncoding($false, $false, $true)
        $inicio = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $codificacao = New-Object System.Text.UnicodeEncoding($true, $false, $true)
        $inicio = 2
    } else {
        $codificacao = New-Object System.Text.UTF8Encoding($false, $true)
    }

    $txt = $null
    try { $txt = $codificacao.GetString($bytes, $inicio, $bytes.Length - $inicio) }
    catch [System.Text.DecoderFallbackException] { return $null }
    catch { return $null }
    if ($null -eq $txt) { return $null }
    if ($txt.IndexOf([char]0) -ge 0) { return $null }
    return $txt
}

function Measure-LinhasDoArquivo {
    <#
      Conta as linhas de um arquivo, pelo CAMINHO.

      Existe porque a confusao caminho-vs-conteudo nao da erro: passar um
      caminho para Measure-Linhas devolve 1, silenciosamente, porque caminho
      nao tem '\n'. Aconteceu na 2.4, na linha de proveniencia do relatorio de
      seguranca - que passou a declarar "(1 linhas) + 0 detectores" e ninguem
      notou ate o security-reviewer conferir. Duas funcoes com nomes distintos
      tornam o erro impossivel de escrever.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)
    if (-not (Test-Path -LiteralPath $Caminho -PathType Leaf)) {
        throw "Measure-LinhasDoArquivo: '$Caminho' nao e um arquivo existente."
    }
    $txt = Read-TextoDeArquivo $Caminho
    if ($null -eq $txt) {
        throw "Measure-LinhasDoArquivo: '$Caminho' nao e legivel como texto (UTF-8 invalido, ou NUL no conteudo). Contar linha sobre U+FFFD seria carimbar um numero derivado de leitura corrompida."
    }
    return (Measure-Linhas $txt)
}

function Get-NotaDaConvencaoDeLinhas {
    return 'Linhas = linhas de conteudo: um fim de linha final NAO cria linha vazia extra. Se o seu visualizador mostrar um numero a mais, isso e convencao de contagem, nao deriva de arquivo.'
}

function Get-ImpressaoDeValores {
    <#
      Impressao curta do CONJUNTO de valores achados, para entrar na chave de
      deduplicacao. Nunca e o valor: e um hash truncado, e nao aparece em
      lugar nenhum do relatorio.

      Existe porque a chave era 'caminho|categoria', sem nada que
      distinguisse QUAL valor foi encontrado. Cenario do qa-reviewer:
      'config.py' com o token novo hoje e o token ANTIGO num blob - mesma
      chave, e o achado do historico era descartado como "coincidente com o
      working tree". O segredo rotacionado, que e o caso mais comum de
      segredo real, desaparecia do relatorio e so incrementava um contador.
      Vale igual para dois e-mails de terceiros diferentes no mesmo arquivo.
    #>
    param([string[]]$Valores)
    $lista = @($Valores | Where-Object { $_ } | Sort-Object -Unique)
    if ($lista.Count -eq 0) { return 'vazio' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lista -join "`n"))
        $hash = $sha.ComputeHash($bytes)
        return (($hash[0..3] | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

function Get-LinhaAproximada {
    param([string]$Texto, [int]$Index)
    if ($Index -le 0) { return 1 }
    return ($Texto.Substring(0, $Index) -split "`n").Count
}

function Invoke-Git {
    <#
      Roda o git e devolve as linhas de stdout. AVISO do git nao aborta nada;
      FALHA do git aborta - e essa distincao e o ponto inteiro da funcao.

      Isto existe porque no PowerShell 5.1 stderr de executavel nativo vira
      ErrorRecord, e sob $ErrorActionPreference = 'Stop' isso e TERMINANTE -
      um aviso derruba o script inteiro com uma mensagem que nao tem relacao
      com o que se estava fazendo. Ja aconteceu tres vezes nesta plataforma,
      e a terceira foi a pior: o collect-diff.ps1 saiu com 2 e SEM RELATORIO
      no meio de um fechamento de subfase, porque o git avisou
      "CRLF will be replaced by LF" sobre um .md gravado com CRLF. Coletor que
      morre nao produz evidencia, e sem evidencia a revisao e INCONCLUSIVO.

      MEDIDO: '2>$null' sozinho NAO protege - o caso do 'rev-parse' em
      repositorio sem commits aborta mesmo redirecionado. O que protege e
      baixar o ErrorActionPreference em volta da chamada.

      MAS baixar a preferencia e parar ai foi um DEFEITO, achado pelos dois
      revisores independentes no fechamento da 2.4, e o QA classificou como
      ALTA: a versao anterior desta funcao engolia tambem o codigo de saida.
      Das ~34 chamadas, so 6 consultavam $LASTEXITCODE; nas outras 28 uma
      falha de git virava LISTA VAZIA, e lista vazia e indistinguivel de
      "nada a acusar". Consequencia medida por leitura: com o indice travado
      por outro processo, o security-scan.ps1 examinava ZERO arquivo,
      declarava as seis areas cobertas, imprimia "(nenhuma)" na secao de
      lacunas e saia com 0. Antes da 2.4 a mesma falha abortava e o trap dava
      exit 2 - alto e visivel. Eu havia trocado um modo de falha ruidoso por
      um silencioso.

      Por isso o contrato agora e: FALHA DO GIT LANCA. Sob
      $ErrorActionPreference = 'Stop' e o 'trap { exit 2 }' dos coletores,
      isso volta a produzir exit 2 - "a varredura nao aconteceu" -, que e
      exatamente o terceiro estado do ADR-0009. Aviso com codigo 0 continua
      sendo ignorado, que era o defeito que originou a funcao.

      -PermitirFalha e para o punhado de chamadas em que codigo != 0 e
      RESPOSTA, nao erro: 'check-ignore' devolve 1 para caminho nao ignorado,
      'rev-parse --verify --quiet' devolve != 0 para ref ausente,
      'config --get-all' devolve 1 quando a chave nao existe. Nessas, quem
      chama LE $LASTEXITCODE e decide. Em nenhuma outra.

      Uso:
          $arquivos = @(Invoke-Git @('-C', $Path, 'ls-files'))          # falha = exit 2
          Invoke-Git @('-C', $Path, 'check-ignore', '-q', $rel) -PermitirFalha | Out-Null
          if ($LASTEXITCODE -eq 0) { ... }
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$Argumentos,
        [switch]$PermitirFalha
    )
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & git @Argumentos 2>$null
        $codigo = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $anterior
    }
    if (-not $PermitirFalha -and $codigo -ne 0) {
        # ${codigo} com chaves, e nao por estilo: "$codigo:" e lido como
        # variavel qualificada por drive e da ParseError - a mesma familia do
        # "\$Ordem:" que ja esta no runbook. E o modo de falha foi instrutivo:
        # o erro de sintaxe fez TODA execucao sair com 2, e os dois casos
        # novos que exigem exit 2 passaram por motivo errado.
        throw ("git saiu com ${codigo}: git " + ($Argumentos -join ' ') +
               ". A varredura NAO aconteceu - nao confunda com ausencia de achado.")
    }
    # $LASTEXITCODE fica com o codigo real para quem usou -PermitirFalha.
    return $saida
}

function ConvertTo-ArgumentoNativo {
    <#
      Cita UM argumento para a linha de comando do Windows, pelas regras do
      CommandLineToArgvW (as mesmas que o git para Windows segue): aspas em
      volta quando ha espaco ou aspa, aspa interna escapada com barra, e
      barras invertidas dobradas SO quando precedem uma aspa. Usado por
      Invoke-GitUtf8, que monta a linha de comando a mao porque o
      ProcessStartInfo do .NET Framework so aceita uma string unica.
    #>
    param([AllowEmptyString()][string]$Valor)
    if ($Valor.Length -gt 0 -and $Valor -notmatch '[\s"]') { return $Valor }
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.Append('"')
    $barras = 0
    foreach ($ch in $Valor.ToCharArray()) {
        if ($ch -eq [char]92) { $barras++; continue }
        if ($ch -eq [char]34) {
            $null = $sb.Append(('\' * (2 * $barras + 1)))
            $null = $sb.Append('"')
        } else {
            if ($barras -gt 0) { $null = $sb.Append(('\' * $barras)) }
            $null = $sb.Append($ch)
        }
        $barras = 0
    }
    if ($barras -gt 0) { $null = $sb.Append(('\' * (2 * $barras))) }
    $null = $sb.Append('"')
    return $sb.ToString()
}

function Invoke-GitUtf8 {
    <#
      Roda o git e devolve o stdout INTEIRO como uma string, decodificada
      como UTF-8 a partir dos BYTES - sem passar pelo console.

      Existe por causa do item 156 do backlog. O Invoke-Git usa '& git', e
      no PowerShell 5.1 a saida de executavel nativo e decodificada pela
      codepage do console ([Console]::OutputEncoding). O git escreve UTF-8;
      com o console em 850 ou 1252, todo acento vira mojibake. E trocar o
      [Console]::OutputEncoding nao serve como correcao: sem console anexado
      (hook do Git, stdout redirecionado) o setter LANCA - o detector de
      historico ja convive com isso e declara a degradacao no relatorio.
      Aqui a decodificacao nao depende do console em estado nenhum.

      Mesmo contrato do Invoke-Git: FALHA do git lanca, aviso em stderr nao
      aborta nada, e -PermitirFalha deixa o codigo em $LASTEXITCODE para quem
      chama ler. -Entrada e escrita no stdin do git como UTF-8 (sem BOM) e o
      stdin e fechado em seguida - e o que o 'check-ignore --stdin -z' exige.

      O executavel e resolvido como o '& git' resolveria (Get-Command, tipo
      Application): o CreateProcess sozinho procuraria 'git.exe' tambem no
      diretorio corrente, e varrer um repositorio de terceiro com um
      'git.exe' plantado na raiz executaria o binario dele.
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$Argumentos,
        [switch]$PermitirFalha,
        # Sem tipo de proposito: '[string]' converteria $null em '', e a
        # ausencia de entrada deixaria de ser distinguivel de entrada vazia.
        $Entrada = $null,
        # Devolve os BYTES do stdout em vez de texto. Para quem precisa decidir
        # legibilidade sobre o byte original (blob do historico, revisao r8).
        [switch]$Bytes
    )
    $exe = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($exe.Count -eq 0) {
        throw "git nao encontrado no PATH. A varredura NAO aconteceu - nao confunda com ausencia de achado."
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe[0].Source
    $psi.Arguments = (@($Argumentos | ForEach-Object { ConvertTo-ArgumentoNativo $_ }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # stdin SEMPRE redirecionado e fechado: herdado, ele seria o stdin de
    # quem chamou - num hook de pre-push, a lista de refs -, e um git que
    # resolvesse le-lo ficaria esperando.
    $psi.RedirectStandardInput = $true
    # O '& git' herda o diretorio corrente do PowerShell, nao o do processo.
    # Sem isto, '-C .' apontaria para outro lugar.
    $loc = Get-Location
    if ($loc.Provider.Name -eq 'FileSystem') { $psi.WorkingDirectory = $loc.ProviderPath }

    $p = [System.Diagnostics.Process]::Start($psi)
    try {
        # stdout e stderr lidos de forma ASSINCRONA antes de escrever o
        # stdin: com tudo sincrono, o git pode encher o pipe de saida
        # enquanto este processo ainda escreve a entrada, e os dois esperam
        # um pelo outro para sempre.
        $ms = New-Object System.IO.MemoryStream
        $tarefaOut = $p.StandardOutput.BaseStream.CopyToAsync($ms)
        $tarefaErr = $p.StandardError.ReadToEndAsync()
        if ($null -ne $Entrada) {
            $bytesIn = (New-Object System.Text.UTF8Encoding($false)).GetBytes([string]$Entrada)
            $p.StandardInput.BaseStream.Write($bytesIn, 0, $bytesIn.Length)
            $p.StandardInput.BaseStream.Flush()
        }
        $p.StandardInput.Close()
        $tarefaOut.Wait()
        $null = $tarefaErr.Result
        $p.WaitForExit()
        $codigo = $p.ExitCode
    } finally {
        $p.Dispose()
    }
    $global:LASTEXITCODE = $codigo
    if (-not $PermitirFalha -and $codigo -ne 0) {
        throw ("git saiu com ${codigo}: git " + ($Argumentos -join ' ') +
               ". A varredura NAO aconteceu - nao confunda com ausencia de achado.")
    }
    # Leniente de proposito: caminho gravado no historico por outra maquina
    # em Latin-1 nao pode abortar a varredura inteira. Ele chega com U+FFFD,
    # nao existe no disco com esse nome, e cai na contagem de 'ausente do
    # disco' - lacuna declarada, nao silencio.
    if ($Bytes) { return ,($ms.ToArray()) }
    return [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
}

function Invoke-GitCaminhos {
    <#
      Toda listagem de CAMINHOS do Git nos detectores passa por aqui - item
      156 do backlog.

      Sem '-z', o git CITA o caminho que tem byte fora do ASCII: 'CAPAS/CAPA
      DOSSIE.docx' com acento no E sai como "CAPAS/CAPA DOSSI\303\212.docx",
      com aspas e escape octal. O 'Join-Path' recebia as aspas e lancava
      "Caracteres invalidos no caminho"; o trap transformava isso em exit 2
      e a varredura do repositorio INTEIRO nao acontecia por causa de um
      nome de arquivo. 'core.quotepath=false' sozinho nao basta: aspa, barra
      invertida, tab e quebra de linha no nome continuam citados. Com '-z'
      nada e citado e o separador e NUL, que nao existe em nome de arquivo.

      Exige '-z' entre os argumentos e LANCA sem ele: esquecer o '-z' faria
      a lista voltar como um unico item com quebras de linha dentro, sem
      erro nenhum. O 'core.quotepath=false' vai junto como segunda camada
      para subcomandos cujo '-z' nao cobre todos os campos.

      Devolve os registros nao vazios, na ordem do git. Com -ManterVazios,
      devolve TODOS os campos, inclusive os vazios, tirando so o terminador
      final - o 'check-ignore -v -z' emite quatro campos por sonda, e sonda
      que nao casou tem os tres primeiros vazios: filtrar vazio desalinharia
      os grupos.
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$Argumentos,
        [switch]$PermitirFalha,
        [switch]$ManterVazios,
        $Entrada = $null
    )
    if ($Argumentos -cnotcontains '-z') {
        throw "Invoke-GitCaminhos sem '-z': git $($Argumentos -join ' '). Listagem de caminho sem '-z' volta citada para nome com acento (item 156)."
    }
    $texto = Invoke-GitUtf8 -Argumentos (@('-c', 'core.quotepath=false') + $Argumentos) `
                            -PermitirFalha:$PermitirFalha -Entrada $Entrada
    $campos = $texto.Split([char]0)
    if ($ManterVazios) {
        $n = $campos.Length
        if ($n -gt 0 -and $campos[$n - 1] -eq '') { $n-- }
        if ($n -eq 0) { return @() }
        return @($campos[0..($n - 1)])
    }
    return @($campos | Where-Object { $_ -ne '' })
}

function Get-CaminhosUnicos {
    <#
      Lista de caminhos sem repeticao, comparando por ORDINAL.

      'Sort-Object -Unique' compara por CULTURA e sem caixa, e para essa
      comparacao 'forma-E.py' com E-agudo pre-composto (NFC) e o mesmo nome
      com E + acento combinante (NFD) sao IGUAIS - o NTFS os guarda como dois
      arquivos distintos. Medido no teste adversarial do item 156: o arquivo
      NFD com um token dentro era descartado como duplicata do NFC limpo, e
      o working tree nunca o lia. Um nome escolhido a dedo escondia o
      conteudo do scanner.

      A ORDEM continua a do 'Sort-Object' (cultura), para nao mexer na ordem
      do relatorio; so a deduplicacao passou a ser exata.
    #>
    param([string[]]$Caminhos)
    $vistos = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $saida = New-Object 'System.Collections.Generic.List[string]'
    foreach ($c in @($Caminhos | Where-Object { $_ } | Sort-Object)) {
        if ($vistos.Add($c)) { $saida.Add($c) }
    }
    return @($saida)
}

function New-ConjuntoOrdinal {
    <#
      HashSet de string com comparacao ORDINAL, para pertinencia de caminho.
      '-contains' compara por cultura e sem caixa, e confunde NFC com NFD
      pelo mesmo motivo descrito em Get-CaminhosUnicos. Devolvido com ','
      para o PowerShell nao desenrolar o conjunto na saida da funcao.
    #>
    param([string[]]$Itens)
    $conj = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($i in @($Itens)) { if ($null -ne $i) { $null = $conj.Add($i) } }
    return ,$conj
}

function Get-CaminhosDoGit {
    <#
      Devolve onde moram o HEAD e as refs deste repositorio.

      Nem sempre e '.git/': em worktree ligado e em submodulo, '.git' e um
      ARQUIVO com 'gitdir: <caminho>'. A versao anterior destes predicados
      LANCAVA nesse caso - "nao da para conferir" -, o que estava certo
      enquanto ninguem precisava rodar sobre worktree. O /os:doctor precisa.

      Em worktree ligado os dois caminhos DIFEREM, e a distincao importa:
        GitDir     - onde vive o HEAD DESTE worktree
        ComumDir   - onde vivem refs/ e packed-refs, compartilhados com o
                     repositorio principal
      Num repositorio comum os dois sao o mesmo '.git'.

      Devolve $null quando o caminho nao e repositorio nenhum: nao lanca,
      porque "nao e repositorio" e uma resposta legitima que o chamador
      trata. O que nao pode e virar "repositorio vazio".
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $git = Join-Path $Path '.git'
    if (Test-Path $git -PathType Container) {
        return [pscustomobject]@{ GitDir = $git; ComumDir = $git; Ligado = $false }
    }
    if (-not (Test-Path $git -PathType Leaf)) { return $null }

    # '.git' e arquivo: worktree ligado ou submodulo.
    $conteudo = ''
    try { $conteudo = [System.IO.File]::ReadAllText($git) } catch { return $null }
    $m = [regex]::Match($conteudo, '(?m)^\s*gitdir:\s*(.+?)\s*$')
    if (-not $m.Success) { return $null }

    $alvo = $m.Groups[1].Value
    if (-not [System.IO.Path]::IsPathRooted($alvo)) { $alvo = Join-Path $Path $alvo }
    try { $alvo = [System.IO.Path]::GetFullPath($alvo) } catch { return $null }
    if (-not (Test-Path $alvo -PathType Container)) { return $null }

    # 'commondir' aponta o .git principal, onde ficam as refs.
    $comum = $alvo
    $arqComum = Join-Path $alvo 'commondir'
    if (Test-Path $arqComum -PathType Leaf) {
        $rel = ''
        try { $rel = ([System.IO.File]::ReadAllText($arqComum)).Trim() } catch { $rel = '' }
        if ($rel) {
            $c = $rel
            if (-not [System.IO.Path]::IsPathRooted($c)) { $c = Join-Path $alvo $c }
            try { $c = [System.IO.Path]::GetFullPath($c) } catch { $c = '' }
            if ($c -and (Test-Path $c -PathType Container)) { $comum = $c }
        }
    }
    return [pscustomobject]@{ GitDir = $alvo; ComumDir = $comum; Ligado = $true }
}

function Get-RaizDoRepositorio {
    <#
      Onde comeca o repositorio que contem este caminho, e que FORMA ele tem.

      Existe porque 'Get-CaminhosDoGit' e os dois predicados assumem que
      '$Path' E a raiz - contrato de entrada do scanner, garantido pelo portao
      que exige '.git' em '$Path'. O /os:doctor e o primeiro consumidor que
      roda FORA desse contrato: invocado de um subdiretorio, 'Get-CaminhosDoGit'
      devolve $null e todo ramo negativo lanca com diagnostico errado - diz
      "nao e repositorio" sobre um subdiretorio de um repositorio perfeito.

      Devolve sempre um objeto, nunca $null, com:
        Raiz       caminho absoluto da raiz, ou $null
        Forma      normal | worktree | bare | fora-de-repo | indeterminada
        Resolvida  $true so quando da para trabalhar sobre a Raiz
        Motivo     por que nao deu, quando nao deu

      As tres respostas negativas sao DIFERENTES de proposito, e confundi-las
      e o falso verde que esta funcao existe para impedir:
        fora-de-repo   - determinado: nao ha repositorio aqui
        bare           - determinado: ha repositorio, e esta forma nao e
                         suportada por projeto governado
        indeterminada  - NAO determinado: o git nao respondeu, ou respondeu
                         algo que o disco contradiz
      So a terceira e "nao consegui". As duas primeiras sao fatos.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $vazio = { param($forma, $motivo) [pscustomobject]@{ Raiz = $null; Forma = $forma; Resolvida = $false; Motivo = $motivo } }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return (& $vazio 'indeterminada' 'caminho vazio: nao ha o que resolver')
    }
    if (-not (Test-Path $Path)) {
        return (& $vazio 'indeterminada' "o caminho '$Path' nao existe no disco")
    }

    $abs = ''
    try { $abs = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).ProviderPath) }
    catch { return (& $vazio 'indeterminada' "nao foi possivel resolver '$Path' para um caminho absoluto") }

    # --- e repositorio? ------------------------------------------------------
    $dentro = @(Invoke-Git @('-C', $abs, 'rev-parse', '--is-inside-work-tree') -PermitirFalha)
    $codigoDentro = $LASTEXITCODE

    if ($codigoDentro -ne 0) {
        # Pode ser bare, ou pode nao ser repositorio nenhum. Perguntar, e nao
        # supor: as duas respostas levam a vereditos diferentes.
        $bare = @(Invoke-Git @('-C', $abs, 'rev-parse', '--is-bare-repository') -PermitirFalha)
        if ($LASTEXITCODE -eq 0 -and @($bare)[0] -eq 'true') {
            return (& $vazio 'bare' "'$abs' e um repositorio BARE. Projeto governado tem working tree: nao ha o que diagnosticar aqui, e afirmar saude sobre uma forma que a ferramenta nao representa seria falsa garantia")
        }
        return (& $vazio 'fora-de-repo' "'$abs' nao pertence a repositorio Git nenhum")
    }

    if (@($dentro)[0] -ne 'true') {
        # Dentro do diretorio .git de um repositorio comum, o git responde
        # 'false' com codigo 0. Nao e "nao consegui", e tambem nao e lugar de
        # diagnosticar projeto.
        return (& $vazio 'bare' "o git respondeu que '$abs' nao esta numa working tree (resposta: '$(@($dentro)[0])'). Diretorio interno do Git, ou repositorio bare")
    }

    $topo = @(Invoke-Git @('-C', $abs, 'rev-parse', '--show-toplevel') -PermitirFalha)
    if ($LASTEXITCODE -ne 0 -or @($topo).Count -eq 0 -or [string]::IsNullOrWhiteSpace(@($topo)[0])) {
        return (& $vazio 'indeterminada' "o git confirmou que '$abs' esta numa working tree mas NAO devolveu a raiz. A raiz NAO foi determinada, e todo veredito a jusante sairia sobre o caminho errado")
    }

    $raiz = @($topo)[0]
    try { $raiz = [System.IO.Path]::GetFullPath($raiz) }
    catch { return (& $vazio 'indeterminada' "o git devolveu uma raiz que nao resolve para caminho absoluto: '$(@($topo)[0])'") }

    if (-not (Test-Path $raiz -PathType Container)) {
        return (& $vazio 'indeterminada' "o git devolveu a raiz '$raiz', que NAO existe no disco. Resposta do git contradita pelo disco e falha de leitura, nao repositorio")
    }

    # Guarda: a raiz que o git devolveu tem de TER um '.git'.
    #
    # 'GIT_DIR' no ambiente - o estado de todo hook do Git - faz o git usar o
    # repositorio apontado pela variavel e tratar o diretorio CORRENTE como
    # working tree. O 'show-toplevel' devolve entao um diretorio que nao e
    # repositorio nenhum, carregando o historico de outro. Sem esta guarda o
    # doctor diagnosticaria esse diretorio relatando o Git de outro lugar.
    #
    # A primeira versao comparava CAMINHOS - se a raiz contem o caminho
    # perguntado - e falhava nas DUAS pontas, as duas medidas pela suite:
    #   - nao pegava o caso do 'GIT_DIR', porque ali a raiz devolvida E o
    #     caminho perguntado;
    #   - acusava falso em toda fixture sob '%TEMP%', porque '$env:TEMP' nesta
    #     maquina e a forma 8.3 ('USUARI~1') e o git responde com o nome
    #     longo ('Usuaria Exemplo').
    # Comparar caminho como string e fragil; perguntar pelo '.git' e sobre o
    # fato.
    $marcaGit = Join-Path $raiz '.git'
    if (-not (Test-Path $marcaGit)) {
        return (& $vazio 'indeterminada' "o git devolveu a raiz '$raiz', que NAO tem um '.git'. O git esta usando outro repositorio - 'GIT_DIR' no ambiente e a causa comum, e e o estado de todo hook do Git. A raiz NAO foi determinada")
    }

    # E o '.git' que o git esta USANDO tem de ser o '.git' desta raiz.
    #
    # Testar so a existencia nao basta, e o security-reviewer achou o estado
    # que sobrava: com 'GIT_DIR' apontando para o repositorio A e o diretorio
    # corrente sendo a raiz do repositorio B, 'show-toplevel' devolve B, B TEM
    # '.git', e a guarda anterior passava. Como 'Invoke-Git' herda o ambiente,
    # todo comando a jusante responderia sobre A: o diagnostico sairia com a
    # RAIZ de B e o HEAD, o status e o log de A - com status PASS. Falsa
    # garantia, e nao hipotetica: 'GIT_DIR' e o estado de todo hook, e a
    # subfase 2.6 e justamente hooks.
    $gitEmUso = @(Invoke-Git @('-C', $raiz, 'rev-parse', '--absolute-git-dir') -PermitirFalha)
    if ($LASTEXITCODE -ne 0 -or @($gitEmUso).Count -eq 0 -or -not $gitEmUso[0]) {
        return (& $vazio 'indeterminada' "o git nao disse qual diretorio Git esta usando para a raiz '$raiz'. Sem isso nao da para afirmar que o diagnostico e sobre este repositorio")
    }
    $gEsperado = Get-CaminhosDoGit -Path $raiz
    if ($null -eq $gEsperado) {
        return (& $vazio 'indeterminada' "a raiz '$raiz' tem um '.git' que nao da para resolver. A raiz NAO foi determinada")
    }
    $usado = ''
    $esperado = ''
    try {
        $usado    = ([System.IO.Path]::GetFullPath($gitEmUso[0])).TrimEnd('\', '/')
        $esperado = ([System.IO.Path]::GetFullPath($gEsperado.GitDir)).TrimEnd('\', '/')
    } catch {
        return (& $vazio 'indeterminada' "nao foi possivel normalizar os caminhos do diretorio Git para conferir se o git responde sobre esta raiz")
    }
    if ($usado -ne $esperado) {
        return (& $vazio 'indeterminada' "o git esta usando o diretorio Git '$usado', e o '.git' da raiz '$raiz' aponta para '$esperado'. O git responde sobre OUTRO repositorio - 'GIT_DIR' no ambiente e a causa comum. Todo veredito a jusante sairia com a raiz de um e o historico de outro")
    }

    $forma = 'normal'
    $g = Get-CaminhosDoGit -Path $raiz
    if ($null -ne $g -and $g.Ligado) { $forma = 'worktree' }

    return [pscustomobject]@{ Raiz = $raiz.TrimEnd('\', '/'); Forma = $forma; Resolvida = $true; Motivo = '' }
}

function Get-RefsNoDisco {
    <#
      Quantas refs existem no repositorio, contando soltas e empacotadas.

      Serve a UMA pergunta: um repositorio de verdade sem nenhum commit nao
      tem ref nenhuma. Se o git disse "nao resolvi" e existem refs no disco,
      quem falhou foi o git - e isso e falha de leitura, nao repositorio
      vazio. A diferenca entre as duas e a diferenca entre declarar lacuna e
      afirmar cobertura sobre o que nao foi lido.
    #>
    param([Parameter(Mandatory = $true)][string]$ComumDir)
    $n = 0
    $dirRefs = Join-Path $ComumDir 'refs'
    if (Test-Path $dirRefs -PathType Container) {
        $n += @(Get-ChildItem $dirRefs -Recurse -File -ErrorAction SilentlyContinue).Count
    }
    $packed = Join-Path $ComumDir 'packed-refs'
    if (Test-Path $packed -PathType Leaf) {
        $n += @(Get-Content $packed -ErrorAction SilentlyContinue |
                Where-Object { $_ -and -not $_.StartsWith('#') }).Count
    }
    return $n
}

function Test-HeadResolvivel {
    <#
      O HEAD DESTE diretorio de trabalho aponta para um commit que existe?

      Metade de 'Test-TemCommits', que respondia a duas perguntas e era usada
      para as duas. Depois de 'git init' + 'remote add' + 'fetch' as respostas
      divergem: ha historico buscado e o HEAD ainda nao nasceu. As duas
      correcoes obvias estavam erradas - devolver falso fazia o detector
      afirmar "nao existe historico a varrer" sobre um repositorio com blobs;
      devolver verdadeiro fazia 'rev-parse --short HEAD' lancar.

      Quem pergunta isto: quem vai chamar 'rev-parse HEAD', 'git show HEAD',
      'git diff HEAD' - tudo que precisa de um ponto de partida resolvivel.

      FALSO significa "HEAD nao nascido, e eu confirmei": o HEAD aponta para
      uma ref que nao existe. Qualquer outro motivo de nao resolver LANCA -
      "nao consegui determinar" nunca vira falso verde.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    # 'HEAD^{commit}', nao 'HEAD'. A diferenca nao e estilo: com o sha NULO
    # escrito em .git/HEAD - 40 zeros -, 'rev-parse --verify --quiet HEAD'
    # sai com 0 e IMPRIME os 40 zeros. O predicado devolveria verdadeiro e o
    # chamador carimbaria o relatorio com '0000000' como se fosse commit.
    # Falso verde, achado pelo proprio caso desta correcao quando ele passou
    # a exigir a MENSAGEM da excecao em vez de aceitar qualquer falha.
    #
    # '^{commit}' obriga o objeto a existir E a ser commit: sai 1 para o sha
    # nulo, 1 para repositorio sem commits, 0 so quando ha commit de verdade.
    Invoke-Git @('-C', $Path, 'rev-parse', '--verify', '--quiet', 'HEAD^{commit}') -PermitirFalha | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }

    $g = Get-CaminhosDoGit -Path $Path
    if ($null -eq $g) {
        throw "Test-HeadResolvivel: '$Path' nao expoe um diretorio Git legivel, e o git nao resolveu o HEAD. Nao da para distinguir HEAD nao nascido de repositorio ilegivel: a verificacao NAO aconteceu."
    }

    $arqHead = Join-Path $g.GitDir 'HEAD'
    if (-not (Test-Path $arqHead -PathType Leaf)) {
        throw "Test-HeadResolvivel: nao existe '$arqHead'. Repositorio sem HEAD nao e repositorio recem-criado: a verificacao NAO aconteceu."
    }
    $bruto = ''
    try { $bruto = ([System.IO.File]::ReadAllText($arqHead)).Trim() } catch {
        throw "Test-HeadResolvivel: '$arqHead' existe e nao pode ser lido. A verificacao NAO aconteceu."
    }

    $mr = [regex]::Match($bruto, '^ref:\s*(\S+)$')
    if (-not $mr.Success) {
        # HEAD destacado: o conteudo e um sha. Se o git nao resolveu um sha
        # escrito la, o objeto sumiu - isso e corrupcao, nao repositorio novo.
        # Truncado: com '.git' sendo arquivo, este caminho e controlado pelo
        # conteudo do repositorio, e o que se ecoa e conteudo de arquivo
        # arbitrario. Vai so para stderr, e o throw impede o relatorio de ser
        # escrito, entao nao contamina artefato - mas nao ha razao para ecoar
        # tudo. Higiene apontada pelo security-reviewer.
        $amostra = $bruto
        if ($amostra.Length -gt 60) { $amostra = $amostra.Substring(0, 60) + '...' }
        throw "Test-HeadResolvivel: HEAD nao e simbolico ('$amostra') e mesmo assim o git nao o resolveu. Objeto ausente ou repositorio corrompido: a verificacao NAO aconteceu."
    }

    $refAlvo = $mr.Groups[1].Value
    $existeSolta = Test-Path (Join-Path $g.ComumDir $refAlvo) -PathType Leaf
    $existeNoWorktree = Test-Path (Join-Path $g.GitDir $refAlvo) -PathType Leaf
    $existeEmpacotada = $false
    $packed = Join-Path $g.ComumDir 'packed-refs'
    if (Test-Path $packed -PathType Leaf) {
        foreach ($l in @(Get-Content $packed -ErrorAction SilentlyContinue)) {
            if ($l -and -not $l.StartsWith('#') -and $l.EndsWith(" $refAlvo")) { $existeEmpacotada = $true; break }
        }
    }
    if ($existeSolta -or $existeNoWorktree -or $existeEmpacotada) {
        throw "Test-HeadResolvivel: HEAD aponta para '$refAlvo', a ref EXISTE no disco e o git nao a resolveu. Isto e falha de leitura, nao HEAD nao nascido: a verificacao NAO aconteceu."
    }

    # HEAD simbolico apontando para ref que nao existe: nao nascido. E o
    # estado de 'git init' e o de 'git checkout -b' antes do primeiro commit.
    return $false
}

function Test-TemHistorico {
    <#
      Existe algum commit alcancavel por ALGUMA ref deste repositorio?

      A outra metade. 'rev-list --all' nao passa pelo HEAD: um repositorio com
      'refs/remotes/origin/main' buscado tem historico a varrer mesmo com o
      HEAD nao nascido. Quem pergunta isto: os detectores que varrem historico
      - 'log --all', 'rev-list --all', 'cat-file' sobre o que elas devolvem.

      FALSO significa "nenhuma ref, nenhum commit, e eu confirmei contra o
      disco". Se o git devolveu vazio e existem refs, quem falhou foi o git.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $saida = @(Invoke-Git @('-C', $Path, 'rev-list', '--all', '--max-count=1') -PermitirFalha)
    $codigo = $LASTEXITCODE
    if ($codigo -ne 0) {
        throw "Test-TemHistorico: 'git rev-list --all' saiu com $codigo. O historico NAO foi lido, e sem isso nao da para dizer que ele esta vazio."
    }
    $shas = @($saida | Where-Object { $_ -and $_.Trim() })
    if ($shas.Count -gt 0) { return $true }

    $g = Get-CaminhosDoGit -Path $Path
    if ($null -eq $g) {
        throw "Test-TemHistorico: '$Path' nao expoe um diretorio Git legivel. 'rev-list' vazio sem poder conferir refs nao prova repositorio vazio: a verificacao NAO aconteceu."
    }
    $refs = Get-RefsNoDisco -ComumDir $g.ComumDir
    if ($refs -gt 0) {
        throw "Test-TemHistorico: 'rev-list --all' nao devolveu commit nenhum, mas existem $refs ref(s) em '$($g.ComumDir)'. Isto e FALHA de leitura do repositorio, nao repositorio sem commits. A varredura NAO aconteceu."
    }
    return $false
}

# =============================================================================
# Digito verificador - o que separa detector de gerador de ruido
# =============================================================================
# Sem validar o digito, qualquer sequencia formatada de 11 numeros vira
# achado, inclusive '111.111.111-11' e numero de processo. Com validacao, a
# chance de um numero aleatorio passar e de cerca de 1 em 100 - e isso muda a
# ferramenta de "gera ruido" para "acusa".

function Test-CPF {
    param([string]$Digitos)
    if ($Digitos -notmatch '^\d{11}$') { return $false }
    # Sequencia repetida passa na conta dos digitos e nunca e CPF de verdade.
    if ($Digitos -match '^(\d)\1{10}$') { return $false }
    $n = @()
    foreach ($c in $Digitos.ToCharArray()) { $n += [int]::Parse($c) }
    $s = 0
    for ($i = 0; $i -lt 9; $i++) { $s += $n[$i] * (10 - $i) }
    $d1 = 11 - ($s % 11)
    if ($d1 -ge 10) { $d1 = 0 }
    if ($n[9] -ne $d1) { return $false }
    $s = 0
    for ($i = 0; $i -lt 10; $i++) { $s += $n[$i] * (11 - $i) }
    $d2 = 11 - ($s % 11)
    if ($d2 -ge 10) { $d2 = 0 }
    return ($n[10] -eq $d2)
}

function Test-CNPJ {
    param([string]$Digitos)
    if ($Digitos -notmatch '^\d{14}$') { return $false }
    if ($Digitos -match '^(\d)\1{13}$') { return $false }
    $n = @()
    foreach ($c in $Digitos.ToCharArray()) { $n += [int]::Parse($c) }
    $p1 = @(5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)
    $s = 0
    for ($i = 0; $i -lt 12; $i++) { $s += $n[$i] * $p1[$i] }
    $r = $s % 11
    $d1 = 0
    if ($r -ge 2) { $d1 = 11 - $r }
    if ($n[12] -ne $d1) { return $false }
    $p2 = @(6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)
    $s = 0
    for ($i = 0; $i -lt 13; $i++) { $s += $n[$i] * $p2[$i] }
    $r = $s % 11
    $d2 = 0
    if ($r -ge 2) { $d2 = 11 - $r }
    return ($n[13] -eq $d2)
}
