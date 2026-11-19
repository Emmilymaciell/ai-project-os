<#
.SYNOPSIS
    Detector: segredo e arquivo sensivel no HISTORICO do Git.

.DESCRIPTION
    Fecha o ponto que a subfase 2.2 deixou explicitamente INCONCLUSIVO.

    Por que importa: apagar o arquivo do working tree e commitar NAO remove o
    segredo. O blob antigo continua no repositorio, viaja em todo clone e vai
    para o remoto. Varredura que olha so o working tree diz "limpo" nesse
    exato caso - o pior falso negativo possivel, porque parece resolvido.

    O security-reviewer nao consegue fazer isto: objeto do Git e comprimido e
    ele so tem Read, Grep e Glob (ADR-0008). Por isso mora aqui, num script
    com Bash, e o resultado chega a ele como evidencia em arquivo.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-CaminhosDoBlob {
    <#
      Todos os caminhos em que um blob ja viveu.

      MEDIDO, nao suposto: 'git rev-list --all --objects' imprime cada objeto
      UMA vez, com um caminho so. Depois de 'git mv config.py
      legacy/config.py', o mesmo blob aparece so como 'legacy/config.py' - o
      caminho antigo e invisivel ali. Quem fosse limpar o historico com
      'filter-repo --path legacy/config.py' deixaria o blob no lugar, porque
      ele tambem esta alcancavel pelo caminho antigo.

      'git log --all --find-object' recupera os dois. Custa um processo por
      blob, entao so e chamado para blob que JA produziu achado - raro por
      definicao. Achado do qa-reviewer.
    #>
    param([string]$Path, [string]$Sha, [string[]]$Fallback = @())
    $cams = @()
    # '-z' (item 156): sem ele, caminho com acento volta citado e com escape
    # octal, e nao casa com o caminho que o resto do detector conhece.
    foreach ($l in @(Invoke-GitCaminhos @('-C', $Path, 'log', '--all', ('--find-object=' + $Sha), '--format=', '--name-only', '-z'))) {
        $t = ("$l").Trim()
        if ($t -and ($cams -notcontains $t)) { $cams += $t }
    }
    foreach ($f in $Fallback) { if ($f -and ($cams -notcontains $f)) { $cams += $f } }
    return @($cams | Sort-Object)
}

function Get-AchadosHistorico {
    <#
      Varre todos os objetos alcancaveis por qualquer ref (--all): commits de
      qualquer branch e de qualquer tag.

      -ChavesDoWorkingTree recebe as chaves 'caminho|padrao' que a varredura
      do working tree JA achou. Achado do historico que coincide com uma
      delas nao e repetido: seria o mesmo segredo contado duas vezes, e o
      valor deste detector esta justamente no que NAO esta mais visivel.
      A contagem de coincidencias vai para o relatorio - suprimir sem contar
      seria esconder.

      Devolve Achados + Cobertura (numeros para o relatorio declarar volume).
    #>
    param(
        [string]$Path,
        [int]$MaxBlobKB = 512,
        [int]$MaxBlobs = 5000,
        [string[]]$ChavesDoWorkingTree = @()
    )

    $achados = @()
    $cob = @{
        SemCommits      = $false
        Commits         = 0
        ObjetosTotais   = 0
        CaminhosUnicos  = 0
        BlobsCandidatos = 0
        BlobsLidos      = 0
        BlobsGrandes    = 0
        BlobsAcimaDoCap = 0
        # Quantificado porque o relatorio quantificava a lacuna equivalente do
        # working tree (9 arquivos) e deixava a do historico sem numero -
        # ressalva do security-reviewer. Lacuna sem volume nao da para pesar.
        BlobsNaoTexto   = 0
        # Contado, e nao descartado por um 'continue' silencioso.
        #
        # O ramo 'if (-not $txt) { continue }' nao incrementava contador
        # nenhum, entao o relatorio dizia "125 de 126 blob(s) de texto lidos"
        # com BlobsNaoTexto=0, BlobsGrandes=0 e cap nao atingido: um candidato
        # fora do balanco, sem linha de lacuna. Num relatorio cuja premissa e
        # declarar a propria cobertura, isso e o modo de falha central - e o
        # security-reviewer derrubou a area 'historico' para INCONCLUSIVO por
        # causa disso, com razao: '-not $txt' tambem dispara para conteudo "0"
        # e para falha do 'cat-file', e ele nao tinha como distinguir.
        BlobsSemConteudo = 0
        # Blob que o git devolveu e que NAO da para tratar como texto: NUL no
        # conteudo, ou U+FFFD posto pelo decodificador no lugar de byte
        # invalido. Contado e nomeado, nunca somado a BlobsLidos.
        BlobsIlegiveis  = 0
        ListaBlobsIlegiveis = @()
        # Se a troca de [Console]::OutputEncoding pegou. Quando nao pega, a
        # metade da recusa que depende de U+FFFD deixa de valer - e o
        # relatorio tem de dizer isso em vez de afirmar o teto incondicional.
        CodificacaoDoConsoleTrocada = $false
        # QUAIS blobs vieram vazios: sha abreviado + caminho. So a contagem
        # obriga o revisor a fechar por ARITMETICA - ele consegue montar o
        # limite (marcadores de 0 byte colapsam num objeto so), mas nao
        # consegue excluir o maligno: uma falha de LEITURA num blob COM
        # conteudo satisfaz o mesmo limite, porque o contador sobe no mesmo
        # 'if (-not $txt)' para os dois casos. E ele nao tem ferramenta para
        # abrir objeto do Git - sao comprimidos, e isso e por desenho do
        # ADR-0008. Com sha e caminho o fechamento passa a ser por
        # IDENTIDADE. Foi o unico achado que mudou veredito na rodada 5.
        ListaSemConteudo = @()
        Coincidencias   = 0
    }

    # Test-TemHistorico: a linha seguinte e "rev-list --all", que tambem nao
    # passa pelo HEAD. Perguntar pelo HEAD aqui faria o detector declarar
    # "SemCommits" - afirmacao POSITIVA de cobertura - sobre um repositorio
    # com historico buscado por fetch.
    # Pertinencia ORDINAL (item 156): '-contains' compara por cultura, e a
    # chave de um arquivo NFC casaria com a de um NFD - o achado do historico
    # seria descartado como "coincidente" com outro arquivo.
    $conjChavesWT = New-ConjuntoOrdinal $ChavesDoWorkingTree

    if (-not (Test-TemHistorico $Path)) {
        $cob.SemCommits = $true
        return [pscustomobject]@{ Achados = $achados; Cobertura = $cob }
    }

    $cob.Commits = @(Invoke-Git @('-C', $Path, 'rev-list', '--all')).Count

    # 'sha caminho' para blob e tree; commit e tag vem sem caminho.
    # Caminho pode conter espaco, entao corta so no primeiro.
    #
    # $mapa guarda TODOS os caminhos de cada sha, nao um representativo.
    # Conteudo identico em dois caminhos tem um unico sha, e guardar so o
    # primeiro encontrado perdia o outro. Cenario real apontado pelo
    # qa-reviewer: 'git mv config.py legacy/config.py' com o token dentro -
    # se o caminho sorteado fosse o rastreado, o achado era deduplicado e o
    # relatorio NUNCA mencionava que o segredo esteve em 'config.py'. Quem
    # fizesse 'filter-repo --path legacy/config.py' deixaria o blob antigo no
    # lugar.
    $mapa = @{}          # sha -> lista de caminhos
    # ORDINAL (item 156): a '@{}' do PowerShell compara chave por cultura e
    # sem caixa, e para ela o nome NFC e o NFD do mesmo texto sao UM caminho so.
    $caminhos = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)   # caminho -> $true
    # Com '-z' (item 156) o formato muda, e foi MEDIDO no git 2.55: cada
    # objeto e um campo '<sha>' terminado em NUL, e quando ha caminho ele vem
    # no campo SEGUINTE, como 'path=<caminho>', sem citacao nenhuma. Sem '-z'
    # o caminho com acento saia entre aspas com escape octal, e o mesmo
    # arquivo tinha um nome no historico e outro no working tree. Campo que
    # nao comeca com 'path=' e sempre sha: caminho nunca chega sem o prefixo.
    $shaAtual = $null
    foreach ($campo in @(Invoke-GitCaminhos @('-C', $Path, 'rev-list', '--all', '--objects', '-z'))) {
        if ($campo.StartsWith('path=', [System.StringComparison]::Ordinal)) {
            if ($null -eq $shaAtual) { continue }
            $cam = $campo.Substring(5)
            if (-not $caminhos.ContainsKey($cam)) { $caminhos[$cam] = $true }
            if (-not $mapa.ContainsKey($shaAtual)) { $mapa[$shaAtual] = @() }
            if (@($mapa[$shaAtual] | Where-Object { [string]::Equals($_, $cam, [System.StringComparison]::Ordinal) }).Count -eq 0) { $mapa[$shaAtual] += $cam }
            continue
        }
        $cob.ObjetosTotais++
        $shaAtual = $campo
    }
    $cob.CaminhosUnicos = $caminhos.Keys.Count

    # --- 1. nome sensivel que JA EXISTIU -------------------------------------
    $rastreadosAgora = New-ConjuntoOrdinal @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z'))
    $reNome = Get-PadraoNomeSensivel
    foreach ($cam in $caminhos.Keys) {
        if ($cam -notmatch $reNome) { continue }
        if ($rastreadosAgora.Contains($cam)) {
            # A varredura do working tree ja acusou este, com mais contexto.
            $cob.Coincidencias++
            continue
        }
        $achados += New-Achado -Severidade 'ALTA' -Area 'historico' -Caminho $cam `
            -Categoria 'arquivo sensivel no historico' `
            -Detalhe ($cam + ' - nao esta mais no working tree, mas o blob continua no repositorio e viaja em todo clone')
    }

    # --- 2. conteudo dos blobs -----------------------------------------------
    # Tipo e tamanho de TODOS os objetos numa chamada, sem passar sha por
    # stdin: --batch-all-objects evita a fragilidade de alimentar processo
    # nativo pelo pipeline no PowerShell 5.1.
    $tipoTam = @{}
    foreach ($l in @(Invoke-Git @('-C', $Path, 'cat-file', '--batch-all-objects', '--batch-check'))) {
        $p = $l -split '\s+'
        if ($p.Count -ge 3 -and $p[1] -eq 'blob') { $tipoTam[$p[0]] = [int64]$p[2] }
    }

    # Ordenado por sha: a iteracao de hashtable no PowerShell nao tem ordem
    # definida, e sem ordenar a saida do relatorio variava entre execucoes
    # sobre o MESMO repositorio.
    $candidatos = @()
    foreach ($sha in ($mapa.Keys | Sort-Object)) {
        if (-not $tipoTam.ContainsKey($sha)) { continue }   # tree, nao blob
        $temTexto = $false
        # SEM -Raiz de proposito: estes caminhos vem do HISTORICO e podem nao
        # existir no disco. Sem raiz, o ramo de conteudo devolve $false, que e
        # o mesmo fail-closed de antes - blob de nome sem extensao continua
        # fora, e continua contado.
        foreach ($c in $mapa[$sha]) { if (Test-ArquivoDeTexto $c) { $temTexto = $true; break } }
        if (-not $temTexto) { $cob.BlobsNaoTexto++; continue }
        $candidatos += $sha
    }
    $cob.BlobsCandidatos = $candidatos.Count

    # Guarda de sanidade, e este e o caso mais traicoeiro que o
    # security-reviewer achou: se o 'cat-file --batch-check' devolvesse vazio
    # com codigo 0, $tipoTam ficaria vazia, o 'continue' da linha acima
    # classificaria TODO sha como tree - antes de qualquer contador -, e o
    # balanco fecharia em "0 de 0 blobs lidos". A conciliacao que o
    # BlobsSemContudo existe para garantir passaria por cima do caso, porque
    # 0 = 0 reconcilia. Objeto existe e blob nenhum e candidato so e possivel
    # num repositorio de arvores puras, que nao existe na pratica.
    if ($cob.ObjetosTotais -gt 0 -and $tipoTam.Count -eq 0) {
        throw ("o git listou " + $cob.ObjetosTotais + " objeto(s) e o 'cat-file --batch-check' " +
               "nao classificou nenhum: sem tipo de objeto nao ha detector de historico. " +
               "A varredura do historico NAO aconteceu.")
    }

    $padroes = Get-PadroesConteudo
    $limite = $MaxBlobKB * 1024

    # git escreve UTF-8; o PowerShell 5.1 decodifica saida de executavel
    # nativo pela codepage do console. Sem isto, acento em conteudo antigo
    # chega corrompido.
    #
    # A versao anterior deste comentario seguia com "os padroes sao ASCII,
    # entao isso nao muda deteccao de credencial". Isso vale para o problema
    # de codepage que a linha abaixo trata, e e FALSO para o caso do NUL: um
    # blob em UTF-16 sem BOM decodifica sem erro e chega aos regex com um NUL
    # entre cada letra, e nenhum padrao casa. Comentario errado no ponto exato
    # do defeito e como ele sobrevive a proxima revisao - achado do
    # security-reviewer, que notou que esta area ficou de fora da correcao do
    # item 11 enquanto o relatorio afirmava completude.
    #
    # E o relatorio precisa SABER se a troca pegou. Ela vive num 'catch'
    # silencioso porque sem console anexado - hook do Git, execucao com stdout
    # redirecionado - o setter lanca. No estado degradado a recusa por U+FFFD
    # deixa de valer (byte invalido nao vira U+FFFD, vira mojibake da codepage)
    # e a linha de teto afirmaria incondicionalmente algo que so vale as vezes.
    # A recusa por NUL continua valendo em qualquer codepage. Achado do
    # security-reviewer.
    $encAnterior = $null
    try {
        $encAnterior = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $cob.CodificacaoDoConsoleTrocada = $true
    } catch { }

    # Agrupado por caminho + categoria, nao por blob. Um arquivo editado dez
    # vezes tem dez blobs, e um achado por blob produziria dez linhas
    # dizendo a mesma coisa - foi exatamente o que a primeira execucao desta
    # varredura fez: 18 linhas para 3 arquivos. O que interessa e "este
    # caminho carregou isto em algum momento", com quantas versoes.
    # Ordinal pelo mesmo motivo de $caminhos acima: caminho NFC e NFD sao
    # grupos distintos.
    $grupos = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
    function Add-Grupo {
        # Sem prefixo de escopo de proposito: o PowerShell resolve $grupos na
        # funcao que envolve esta, e mexer nas chaves altera o MESMO objeto.
        # '$script:grupos' apontaria para outra variavel - a do escopo do
        # arquivo, que nao existe - e os achados sumiriam sem erro.
        #
        # Guarda a LISTA de shas, nao um "primeiro". A versao anterior gravava
        # 'PrimeiroSha' com o primeiro sha encontrado numa iteracao de
        # hashtable sem ordem definida, e o relatorio dizia "a partir do blob
        # X" - nome de campo e texto afirmando cronologia que o codigo nao
        # entrega. Cenario apontado pelo qa-reviewer: o token entra no commit
        # 5, o arquivo e editado no 6 e no 7, e o relatorio podia citar o blob
        # do 7 - apontando quem fosse fazer filter-repo para o ponto errado da
        # linha do tempo.
        param([string]$Cam, [string]$Sev, [string]$Cat, [string]$Sha, [int]$Linha)
        $k = $Cam + '||' + $Cat
        if (-not $grupos.ContainsKey($k)) {
            $grupos[$k] = [pscustomobject]@{
                Cam = $Cam; Sev = $Sev; Cat = $Cat
                Shas = @(); Linha = $Linha
            }
        }
        if ($grupos[$k].Shas -notcontains $Sha) { $grupos[$k].Shas += $Sha }
    }

    try {
        $n = 0
        foreach ($sha in $candidatos) {
            if ($n -ge $MaxBlobs) { $cob.BlobsAcimaDoCap = $candidatos.Count - $n; break }
            if ($tipoTam[$sha] -gt $limite) { $cob.BlobsGrandes++; continue }
            $n++
            # Revisao r8 (S6): a legibilidade e decidida sobre os BYTES do blob,
            # com UTF-8 ESTRITO (byte invalido lanca), e nao sobre o stdout ja
            # decodificado pelo console. Antes, qualquer U+FFFD no texto era
            # recusado - inclusive o legitimo (EF BF BD e UTF-8 valido), e uma
            # unica mencao literal ao caractere num STATE.md tornava ilegiveis
            # TODAS as versoes seguintes do arquivo, para sempre.
            $bytesBlob = [byte[]](Invoke-GitUtf8 -Argumentos @('-C', $Path, 'cat-file', '-p', $sha) -Bytes)
            $txt = ''
            $invalido = $false
            if ($bytesBlob.Length -gt 0) {
                try {
                    $txt = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytesBlob)
                } catch {
                    $invalido = $true
                    $txt = '(bytes invalidos para UTF-8)'
                }
                $txt = $txt -replace "`r`n", "`n"
            }
            if (-not $txt) {
                $cob.BlobsSemConteudo++
                if ($cob.ListaSemConteudo.Count -lt 20) {
                    $camDoSha = ''
                    if ($mapa.ContainsKey($sha) -and @($mapa[$sha]).Count -gt 0) { $camDoSha = @($mapa[$sha])[0] }
                    $cob.ListaSemConteudo += ('{0} ({1})' -f $sha.Substring(0, [Math]::Min(8, $sha.Length)), $camDoSha)
                }
                continue
            }
            # As mesmas duas recusas de 'Read-TextoDeArquivo', agora sobre os
            # bytes: UTF-8 invalido (decodificador estrito lancou) ou NUL no
            # texto (UTF-16 sem BOM, binario). U+FFFD decodificado de EF BF BD
            # e caractere legitimo e o blob e lido.
            if ($invalido -or $txt.IndexOf([char]0) -ge 0) {
                $cob.BlobsIlegiveis++
                if ($cob.ListaBlobsIlegiveis.Count -lt 20) {
                    $camIleg = ''
                    if ($mapa.ContainsKey($sha) -and @($mapa[$sha]).Count -gt 0) { $camIleg = @($mapa[$sha])[0] }
                    $cob.ListaBlobsIlegiveis += ('{0} ({1})' -f $sha.Substring(0, [Math]::Min(8, $sha.Length)), $camIleg)
                }
                continue
            }
            $cob.BlobsLidos++
            $ehFixture = Test-DeclaraFixture $txt

            # Primeiro detecta sobre o CONTEUDO, que nao depende de caminho.
            $doBlob = @()
            foreach ($p in $padroes) {
                $m = [regex]::Matches($txt, $p.re)
                if ($m.Count -eq 0) { continue }
                $linha = Get-LinhaAproximada -Texto $txt -Index $m[0].Index
                $imp = Get-ImpressaoDeValores @($m | ForEach-Object { $_.Value })
                if ($ehFixture) {
                    $doBlob += [pscustomobject]@{ Sev = 'BAIXA'; Cat = ('fixture declarada: ' + $p.nome); Base = $p.nome; Linha = $linha; Impressao = $imp }
                } else {
                    $doBlob += [pscustomobject]@{ Sev = 'ALTA'; Cat = ('possivel ' + $p.nome); Base = $p.nome; Linha = $linha; Impressao = $imp }
                }
            }
            # Dado pessoal tambem sobrevive no historico. O detector e funcao
            # pura de texto, entao da para reaproveitar aqui de graca - o blob
            # ja esta em memoria.
            if (Get-Command Find-DadoPessoalEmTexto -ErrorAction SilentlyContinue) {
                foreach ($a in (Find-DadoPessoalEmTexto -Texto $txt -Origem '(historico)')) {
                    $doBlob += [pscustomobject]@{ Sev = $a.Severidade; Cat = $a.Categoria; Base = $a.Base; Linha = 0; Impressao = $a.Impressao }
                }
            }
            if ($doBlob.Count -eq 0) { continue }

            # So agora vale o processo extra: TODOS os caminhos deste blob.
            foreach ($cam in (Get-CaminhosDoBlob -Path $Path -Sha $sha -Fallback $mapa[$sha])) {
                foreach ($a in $doBlob) {
                    # Categoria BASE (sobrevive a mudanca de status de
                    # fixture) e IMPRESSAO dos valores (distingue valor
                    # diferente no mesmo caminho). Sem a impressao, um token
                    # rotacionado ou um segundo e-mail de terceiro numa versao
                    # antiga era descartado como "coincidente com o working
                    # tree" e desaparecia do relatorio - falso negativo
                    # justamente no que so existe no historico.
                    $chave = $cam + '|' + $a.Base + '|' + $a.Impressao
                    if ($conjChavesWT.Contains($chave)) { $cob.Coincidencias++; continue }
                    Add-Grupo $cam $a.Sev $a.Cat $sha $a.Linha
                }
            }
        }
    } finally {
        if ($encAnterior) { try { [Console]::OutputEncoding = $encAnterior } catch { } }
    }

    foreach ($k in ($grupos.Keys | Sort-Object)) {
        $g = $grupos[$k]
        $onde = $g.Cam
        if ($g.Linha -gt 0) { $onde = ('{0} linha ~{1}' -f $g.Cam, $g.Linha) }
        # Shas ordenados e rotulados como NAO cronologicos. O relatorio nao
        # afirma ordem no tempo porque este detector nao sabe a ordem no
        # tempo - quem quer a linha do tempo roda 'git log -- <caminho>'.
        $lista = @($g.Shas | Sort-Object | ForEach-Object { $_.Substring(0, 8) })
        $mostra = $lista
        $sufixo = ''
        if ($lista.Count -gt 3) { $mostra = $lista[0..2]; $sufixo = ', ...' }
        $achados += New-Achado -Severidade $g.Sev -Area 'historico' -Caminho $g.Cam `
            -Categoria ($g.Cat + ' no historico') `
            -Detalhe ('{0} - em {1} versao(oes) do arquivo. Blobs (ordem de sha, NAO cronologica): {2}{3}. Para a linha do tempo: git log -- {4}' -f `
                      $onde, $lista.Count, ($mostra -join ', '), $sufixo, $g.Cam)
    }

    return [pscustomobject]@{ Achados = $achados; Cobertura = $cob }
}
