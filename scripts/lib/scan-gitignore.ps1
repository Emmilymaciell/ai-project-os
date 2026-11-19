<#
.SYNOPSIS
    Detector: o .gitignore faz o que o texto dele promete?

.DESCRIPTION
    Fecha o segundo ponto INCONCLUSIVO da subfase 2.2, onde so o caso do
    '.env' era verificado - e verificado LENDO o arquivo, o que nao prova
    nada. Ler '.env' numa linha do .gitignore nao prova que o Git ignora o
    .env: uma regra posterior pode negar, a regra pode nunca casar com nada,
    ou a protecao pode estar vindo do excludesfile GLOBAL da maquina, que nao
    viaja em clone nenhum.

    Duas verificacoes, e as duas usam 'git check-ignore', ou seja, perguntam
    ao Git em vez de interpretar o texto:

      1. REGRA POR REGRA. Para cada regra, uma sonda derivada dela, e a
         pergunta: foi ESTA regra que casou? Se casou outra, a regra esta
         sombreada. Se nao casou nenhuma, ela nao tem efeito observavel.

      2. DE FORA PARA DENTRO. Uma lista de nomes de segredo canonicos, e a
         pergunta: este repositorio ignora isto? E QUAL arquivo aplica a
         regra? Protecao que vem do global, ou de .git/info/exclude, nao
         acompanha o repositorio - e essa e uma falha de portabilidade que
         so aparece quando alguem clona.

    Regra que a sonda nao consegue representar com honestidade ('**',
    classe de caractere, '?') NAO e reportada como aprovada: entra na conta
    de nao verificavel, e o relatorio diz quantas sao. Politica 4.5.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

$script:ALVO_SONDA = 'sonda-scan-alvo'

function Get-SondaParaRegra {
    <#
      Deriva um caminho concreto que a regra DEVERIA casar.
      Devolve $null quando nao da para derivar sem chutar - e chutar aqui
      produziria "regra sem efeito" falso, que e pior que declarar a lacuna.
    #>
    param([string]$Regra, [string]$Prefixo = '')

    $r = $Regra
    $negacao = $false
    if ($r.StartsWith('!')) { $negacao = $true; $r = $r.Substring(1) }

    # --- classe de caractere: sondada com UM membro concreto ------------------
    # '*.py[cod]' vira '*.pyc'. Testa a regra com um membro de verdade, e o
    # relatorio diz que foi um membro - nao afirma cobertura da classe toda.
    # Classe negada ('[!abc]', '[^abc]') e recusada: ali o primeiro caractere
    # NAO e um membro, e chutar produziria "regra sem efeito" falso.
    $porMembro = $false
    if ($r.Contains('[')) {
        $novo = New-Object System.Text.StringBuilder
        $i = 0
        while ($i -lt $r.Length) {
            if ($r[$i] -eq '[') {
                $fim = $r.IndexOf(']', $i)
                if ($fim -lt 0) { return $null }
                $conteudo = $r.Substring($i + 1, $fim - $i - 1)
                if (-not $conteudo) { return $null }
                if ($conteudo.StartsWith('!') -or $conteudo.StartsWith('^')) { return $null }
                $null = $novo.Append($conteudo[0])
                $porMembro = $true
                $i = $fim + 1
            } else {
                $null = $novo.Append($r[$i])
                $i++
            }
        }
        $r = $novo.ToString()
    }

    # '?' casa exatamente um caractere.
    if ($r.Contains('?')) { $r = $r.Replace('?', 'x') }

    # --- '**' -----------------------------------------------------------------
    # '/**' no fim libera o conteudo do diretorio; '/**/' no meio casa zero ou
    # mais diretorios, e uma sonda com UM diretorio concreto e representativa.
    $ehDiretorio = $false
    if ($r.EndsWith('/**')) {
        $ehDiretorio = $true
        $r = $r.Substring(0, $r.Length - 3)
    } elseif ($r.EndsWith('/')) {
        $ehDiretorio = $true
        $r = $r.TrimEnd('/')
    }
    if ($r.Contains('/**/')) { $r = $r.Replace('/**/', '/sonda-dir/') }
    # Qualquer '**' que sobrou tem forma que esta sonda nao representa.
    if ($r.Contains('**')) { return $null }

    if ($r.StartsWith('/')) { $r = $r.TrimStart('/') }
    if (-not $r) { return $null }

    # --- separa diretorio do ultimo segmento ---------------------------------
    # Generaliza '/logs/*' e '.claude/skills/**/assets/*.png': o glob mora no
    # ultimo segmento, o resto e caminho literal.
    $alvo = $script:ALVO_SONDA
    $dirParte = ''
    $ultimo = $r
    $iBarra = $r.LastIndexOf('/')
    if ($iBarra -ge 0) {
        $dirParte = $r.Substring(0, $iBarra)
        $ultimo = $r.Substring($iBarra + 1)
    }
    if (-not $ultimo) { return $null }

    $p = $null
    if ($ultimo -notmatch '\*') {
        $p = $ultimo
    } elseif ($ultimo -eq '*') {
        # '/logs/*' - o glob e o segmento inteiro. Sem este ramo a derivacao
        # devolvia nada e a regra virava "nao verificavel" por engano.
        $p = $alvo
    } elseif ($ultimo -match '^\*(\.[A-Za-z0-9]+)$') {
        $p = $alvo + $Matches[1]
    } elseif ($ultimo -match '^\*(.+)\*$') {
        $p = 'sonda-' + $Matches[1] + '-alvo'
    } elseif ($ultimo -match '^\*(.+)$') {
        $p = $alvo + $Matches[1]
    } elseif ($ultimo -match '^(.+)\*$') {
        $p = $Matches[1] + $alvo
    }
    if (-not $p) { return $null }

    if ($dirParte) { $p = $dirParte + '/' + $p }
    if ($ehDiretorio) { $p = $p + '/' + $alvo + '.txt' }
    if ($Prefixo) { $p = $Prefixo + '/' + $p }

    return [pscustomobject]@{ Sonda = $p; Negacao = $negacao; PorMembroDeClasse = $porMembro }
}

function Invoke-CheckIgnore {
    <#
      Pergunta ao Git, em lote. Devolve hashtable caminho -> resultado.

      Tres detalhes medidos, nao supostos:

      1. Com --verbose o codigo de saida 0 significa "alguma regra casou",
         INCLUSIVE regra de negacao. Exit 0 NAO quer dizer ignorado. Quem
         decide e o '!' no inicio do padrao reportado. Confundir os dois
         inverteria o veredito de toda negacao.

      2. O Git aplica o ULTIMO padrao que casa, nao o primeiro. Por isso
         "sombreada" quer dizer sombreada por uma regra POSTERIOR.

      3. No Windows o Git CITA o caminho da fonte e DUPLICA as barras
         invertidas quando ha alguma: o excludesfile global volta como
         "C:\\Users\\...\\.gitignore_global". Sem desfazer isso, qualquer
         teste de caminho sobre a fonte trabalha em cima de lixo - e
         IsPathRooted chega a lancar excecao, porque '"' e caractere
         invalido de caminho. Foi o que derrubou o detector de "protecao que
         nao viaja" na primeira execucao do teste.
    #>
    param([string]$Path, [string[]]$Caminhos)

    $res = @{}
    if (-not $Caminhos -or $Caminhos.Count -eq 0) { return $res }

    # Em lotes: passar todas as sondas numa linha de comando unica estoura o
    # limite do Windows num repositorio com muitas regras, e o efeito seria o
    # pior possivel - a chamada falha, nenhuma sonda casa, e TODA regra virava
    # um falso "sem efeito observavel". Ressalva de portabilidade do
    # qa-reviewer.
    # Nomes distintos, nao apenas caixa distinta: variavel do PowerShell e
    # case-insensitive, entao '$LOTE' e '$lote' seriam A MESMA variavel - a
    # fatia sobrescreveria o tamanho do lote e '$i += $LOTE' tentaria somar um
    # array a um inteiro. Foi exatamente o que aconteceu aqui, e a armadilha
    # ja estava escrita em docs/runbooks/gotchas-windows-powershell.md.
    $TAMANHO_LOTE = 150
    $saida = @()
    for ($i = 0; $i -lt $Caminhos.Count; $i += $TAMANHO_LOTE) {
        $fim = [Math]::Min($i + $TAMANHO_LOTE - 1, $Caminhos.Count - 1)
        $fatia = @($Caminhos[$i..$fim])
        # '--stdin -z' (item 156): sem '-z' o git CITA a sonda com acento na
        # saida ("d/arquivo \303\212.env"), e a chave da hashtable deixava de
        # casar com a sonda perguntada - a regra virava "nao verificavel" sem
        # motivo. E o '-z' do check-ignore SO existe com '--stdin' (medido:
        # "fatal: -z only makes sense with --stdin"). Bonus: as sondas saem
        # da linha de comando, que era o limite que obrigava o lote.
        #
        # A SENTINELA na frente do lote e MEDIDA, nao enfeite: o .NET
        # Framework cria o stdin do processo filho com a codificacao de
        # entrada do console e AutoFlush ligado, e quando essa codificacao e
        # UTF-8 o BOM sai no pipe ANTES de qualquer byte nosso. O git lia
        # entao '<BOM>artifacts/sonda-scan-alvo' como primeira sonda, ela
        # nao casava com regra nenhuma, e a regra '/artifacts/*' saia como
        # "sem efeito observavel" - achado falso, so na primeira sonda de
        # cada lote, e so quando o console esta em UTF-8. A sentinela absorve
        # o BOM quando ele existe, e e descartada nos dois casos.
        $SENTINELA = 'sonda-descartavel-do-scanner/inicio-de-lote'
        $entrada = $SENTINELA + [char]0 + (($fatia | ForEach-Object { $_ + [char]0 }) -join '')
        $campos = @(Invoke-GitCaminhos @('-C', $Path, 'check-ignore', '-v', '--no-index', '--non-matching', '--stdin', '-z') `
                                       -Entrada $entrada -PermitirFalha -ManterVazios)
        # -PermitirFalha sem ler o codigo era achado do qa-reviewer, e aqui
        # doia: 'check-ignore' devolve 0 (algo casou) e 1 (nada casou) como
        # RESPOSTA, mas 128 e falha de verdade - e as tres ficavam
        # indistinguiveis. Com o lote perdido, TODA regra virava um falso
        # "sem efeito observavel", que o comentario acima chama de o pior
        # modo de falha possivel. Antes da correcao por classe isso abortava
        # com exit 2; para este ponto o silencio tinha voltado.
        if ($LASTEXITCODE -gt 1) {
            throw ("git check-ignore saiu com $LASTEXITCODE no lote de " + $fatia.Count +
                   " sonda(s): a verificacao de .gitignore NAO aconteceu para esse lote.")
        }
        # O primeiro registro TEM de ser a sentinela (com ou sem BOM na
        # frente). Se nao for, o alinhamento entre sonda perguntada e
        # resposta e desconhecido, e adivinhar seria pior que parar.
        if ($campos.Count -lt 4 -or -not ([string]$campos[3]).EndsWith($SENTINELA, [System.StringComparison]::Ordinal)) {
            throw ("git check-ignore nao devolveu a sentinela do lote como primeiro registro: " +
                   "a verificacao de .gitignore NAO aconteceu para esse lote.")
        }
        if ($campos.Count -gt 4) { $saida += @($campos[4..($campos.Count - 1)]) }
    }
    # Com '-v -z' cada sonda vira QUATRO campos: fonte, linha, padrao,
    # caminho. Sonda que nao casou (--non-matching) tem os tres primeiros
    # vazios. Contagem que nao fecha em multiplo de 4 e saida que este codigo
    # nao entende - lancar, e nao adivinhar o alinhamento.
    if (($saida.Count % 4) -ne 0) {
        throw ("git check-ignore -v -z devolveu " + $saida.Count + " campo(s), que nao e multiplo de 4: " +
               "a verificacao de .gitignore NAO aconteceu.")
    }
    for ($k = 0; $k -lt $saida.Count; $k += 4) {
        $fonte  = [string]$saida[$k]
        $numLin = [string]$saida[$k + 1]
        $padrao = [string]$saida[$k + 2]
        $cam    = [string]$saida[$k + 3]
        if ($fonte -ne '' -and $numLin -match '^\d+$') {
            # Com '-z' nada e citado. O ramo de desfazer aspas fica como
            # defesa: ele e inerte quando a fonte nao vem entre aspas.
            if ($fonte.Length -ge 2 -and $fonte.StartsWith('"') -and $fonte.EndsWith('"')) {
                $fonte = $fonte.Substring(1, $fonte.Length - 2).Replace('\\', '\')
            }
            $res[$cam] = [pscustomobject]@{
                Fonte    = $fonte
                Linha    = [int]$numLin
                Padrao   = $padrao
                Ignorado = (-not $padrao.StartsWith('!'))
                Casou    = $true
            }
        } else {
            $res[$cam] = [pscustomobject]@{
                Fonte = ''; Linha = 0; Padrao = ''; Ignorado = $false; Casou = $false
            }
        }
    }
    return $res
}

function Test-FonteViajaComRepositorio {
    <#
      .gitignore versionado viaja. O excludesfile global e o
      .git/info/exclude NAO viajam: quem clonar nao recebe a protecao.
    #>
    param([string]$Fonte)
    if (-not $Fonte) { return $false }
    $n = $Fonte -replace '\\', '/'
    # Por regex, nao por IsPathRooted: a fonte vem do Git e pode conter
    # caractere que faz o IsPathRooted lancar excecao. Detector nao pode
    # quebrar por causa da forma do caminho que ele recebeu.
    if ($n -match '^[A-Za-z]:/' -or $n -match '^//') { return $false }
    if ($n -match '^\.git/') { return $false }
    return $true
}

function Get-AchadosGitignore {
    param([string]$Path)

    $achados = @()
    $cob = @{
        ArquivosDeRegra    = 0
        ArquivosDeRegraAusentes = 0
        ListaArquivosAusentes   = @()
        ArquivosDeRegraNaoLidos = 0
        ListaArquivosNaoLidos   = @()
        RegrasTotais       = 0
        RegrasVerificadas  = 0
        RegrasEfetivas     = 0
        NaoVerificaveis    = 0
        ListaNaoVerificavel = @()
        # Regras sondadas com UM membro de classe de caractere. Contadas
        # separadamente porque a sonda prova a regra para aquele membro, nao
        # para a classe inteira - e o relatorio nao deve afirmar mais do que
        # foi verificado.
        PorMembroDeClasse  = 0
        ListaPorMembroDeClasse = @()
        # Regras que compartilham sonda com uma regra irma, sendo todas
        # negacao: verificadas pelo resultado, em conjunto.
        VerificadasEmConjunto = 0
        ListaVerificadasEmConjunto = @()
        AlvosCanonicos     = 0
        AlvosCobertos      = 0
        # Negacao que REABRE diretorio. As 28 sondas de nome canonico
        # perguntam pela raiz e por cada diretorio com .gitignore proprio -
        # nunca por um caminho DENTRO da subarvore que um "!" liberou.
        # Enquanto isso nao muda, a razao "N de N nomes canonicos cobertos"
        # vale para a arvore FORA dessas subarvores, e o relatorio tem de
        # dizer isso. Estava so no backlog do STATE.md ate a nona rodada.
        NegacoesQueAbremSubarvore = 0
        ListaNegacoes      = @()
    }

    # --- descobrir os arquivos de regra -------------------------------------
    $rastreados    = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z'))
    $naoRastreados = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z', '--others', '--exclude-standard'))
    $arquivos = @(Get-CaminhosUnicos @(@($rastreados + $naoRastreados) |
                  Where-Object { $_ -and (Split-Path $_ -Leaf) -eq '.gitignore' }))
    $cob.ArquivosDeRegra = $arquivos.Count

    # --- 1. regra por regra --------------------------------------------------
    $sondas = @()
    foreach ($arq in $arquivos) {
        $abs = Join-Path $Path $arq
        if (-not (Test-Path -LiteralPath $abs)) {
            # QUINTO 'continue' silencioso da 2.4, e o security-reviewer
            # mostrou por que este e o pior: 'ArquivosDeRegra' e fixado ANTES
            # do laco, entao apagar templates/project-standard/.gitignore sem
            # 'git add' fazia RegrasTotais cair de 138 para ~71 e a linha
            # imprimir "71 de 71 regra(s) sondadas em 2 arquivo(s)" - razao
            # PERFEITA. O arquivo que protege o segredo de todo projeto
            # governado deixava de ser lido, com o relatorio declarando
            # cobertura cheia.
            $cob.ArquivosDeRegraAusentes++
            if ($cob.ListaArquivosAusentes.Count -lt 20) { $cob.ListaArquivosAusentes += $arq }
            continue
        }
        $prefixo = ''
        $d = (Split-Path $arq -Parent) -replace '\\', '/'
        if ($d) { $prefixo = $d }
        # O arquivo que protege o segredo de todo projeto governado nao pode
        # ser lido "mais ou menos": regra com acento corrompido em U+FFFD nao
        # e a regra que o Git aplica, e a contagem sairia como se fosse.
        $txtGi = Read-TextoDeArquivo $abs
        if ($null -eq $txtGi) {
            $cob.ArquivosDeRegraNaoLidos++
            if ($cob.ListaArquivosNaoLidos.Count -lt 20) { $cob.ListaArquivosNaoLidos += $arq }
            continue
        }
        $linhas = @(($txtGi -replace "`r`n", "`n") -split "`n")
        for ($i = 0; $i -lt $linhas.Count; $i++) {
            $bruta = $linhas[$i]
            $regra = $bruta.TrimEnd()
            if (-not $regra) { continue }
            if ($regra.StartsWith('#')) { continue }
            $cob.RegrasTotais++
            # Negacao que termina em barra, ou em "/**", reabre DIRETORIO.
            # "!arquivo.txt" libera um arquivo so e nao cria subarvore.
            if ($regra.StartsWith('!') -and ($regra.EndsWith('/') -or $regra.EndsWith('/**'))) {
                $cob.NegacoesQueAbremSubarvore++
                if ($cob.ListaNegacoes.Count -lt 20) {
                    $cob.ListaNegacoes += ('{0}:{1} {2}' -f $arq, ($i + 1), $regra)
                }
            }
            $s = Get-SondaParaRegra -Regra $regra -Prefixo $prefixo
            if (-not $s) {
                $cob.NaoVerificaveis++
                $cob.ListaNaoVerificavel += ('{0}:{1} {2}' -f $arq, ($i + 1), $regra)
                continue
            }
            if ($s.PorMembroDeClasse) {
                # Com arquivo:linha, quem revisa confere no disco QUAIS
                # membros da classe ficaram de fora. So a contagem obrigava
                # a fechar por aritmetica - e o security-reviewer nao fechou
                # 'gitignore' por causa disso, enquanto fechou 'historico'
                # porque la o F6 ja imprimia a identidade.
                $cob.PorMembroDeClasse++
                if ($cob.ListaPorMembroDeClasse.Count -lt 20) {
                    $cob.ListaPorMembroDeClasse += ('{0}:{1} {2}' -f $arq, ($i + 1), $regra)
                }
            }
            $sondas += [pscustomobject]@{
                Arquivo = $arq
                Linha   = $i + 1
                Regra   = $regra
                Sonda   = $s.Sonda
                Negacao = $s.Negacao
            }
        }
    }

    # Sonda repetida entre regras diferentes tornaria a atribuicao ambigua.
    # Ambiguidade nao vira achado: vira nao verificavel.
    $contagem = @{}
    foreach ($s in $sondas) {
        if (-not $contagem.ContainsKey($s.Sonda)) { $contagem[$s.Sonda] = 0 }
        $contagem[$s.Sonda]++
    }

    $res = Invoke-CheckIgnore -Path $Path -Caminhos @($sondas | ForEach-Object { $_.Sonda } | Sort-Object -Unique)

    # Quantas regras compartilham cada sonda, e se todas elas sao negacao.
    $soNegacoes = @{}
    foreach ($s in $sondas) {
        if (-not $soNegacoes.ContainsKey($s.Sonda)) { $soNegacoes[$s.Sonda] = $true }
        if (-not $s.Negacao) { $soNegacoes[$s.Sonda] = $false }
    }

    foreach ($s in $sondas) {
        if ($contagem[$s.Sonda] -gt 1) {
            # Ambiguidade entre NEGACOES nao e lacuna: negacao se julga pelo
            # resultado, e o resultado da sonda compartilhada vale para todas.
            #
            # O caso real e o par '!/examples/' e '!/examples/**' do template,
            # que o Git EXIGE junto para liberar diretorio e conteudo. Contar
            # os dois como "nao verificaveis" mantinha a area 'gitignore'
            # INCONCLUSIVA por causa da regra mais perigosa do arquivo - a
            # mesma onde a revisao humana achou um furo de verdade. Declarar
            # lacuna onde o resultado E observavel nao e prudencia, e ruido.
            if ($soNegacoes[$s.Sonda]) {
                $cob.VerificadasEmConjunto++
                if ($cob.ListaVerificadasEmConjunto.Count -lt 20) {
                    $cob.ListaVerificadasEmConjunto += ('{0}:{1} {2}' -f $s.Arquivo, $s.Linha, $s.Regra)
                }
            } else {
                $cob.NaoVerificaveis++
                $cob.ListaNaoVerificavel += ('{0}:{1} {2} (sonda ambigua entre regras que nao sao todas negacao)' -f $s.Arquivo, $s.Linha, $s.Regra)
                continue
            }
        }
        $r = $res[$s.Sonda]
        $ondeRegra = ('{0}:{1}' -f $s.Arquivo, $s.Linha)

        # Sonda que nao voltou NAO e regra verificada. O contador ficava aqui,
        # antes de olhar $r, e a linha de cobertura dizia "138 de 138 regras
        # sondadas" mesmo que nenhuma sonda tivesse voltado - contava
        # tentativa como verificacao. Achado do security-reviewer no
        # fechamento da 2.4.
        if ($null -eq $r) {
            $cob.NaoVerificaveis++
            $cob.ListaNaoVerificavel += ('{0} {1} (a sonda nao voltou do git check-ignore)' -f $ondeRegra, $s.Regra)
            continue
        }
        $cob.RegrasVerificadas++

        # Negacao se julga pelo RESULTADO, nao por quem decidiu.
        #
        # Medido na primeira execucao: o template usa o par '!/examples/' e
        # '!/examples/**', que o Git exige para liberar o diretorio e o
        # conteudo. A sonda de conteudo e sempre decidida pela segunda linha,
        # e exigir "mesma linha" acusava a primeira de sombreada - falso
        # positivo puro, porque o resultado pretendido (nao ignorado) e
        # exatamente o que acontece. Para negacao, so importa: o caminho
        # continua ignorado, ou nao?
        if ($s.Negacao) {
            if ($r -and $r.Casou -and $r.Ignorado) {
                $achados += New-Achado -Severidade 'BAIXA' -Area 'gitignore' `
                    -Categoria 'negacao de .gitignore anulada' `
                    -Detalhe ('{0}  ->  "{1}" continua ignorado por {2}:{3} ({4})' -f $ondeRegra, $s.Sonda, $r.Fonte, $r.Linha, $r.Padrao)
            } else {
                # $r nulo ja foi desviado acima; aqui 'nao ignorado' e
                # resultado de verdade, e a negacao esta fazendo efeito.
                $cob.RegrasEfetivas++
            }
            continue
        }

        if (-not $r -or -not $r.Casou) {
            $achados += New-Achado -Severidade 'BAIXA' -Area 'gitignore' `
                -Categoria 'regra de .gitignore sem efeito observavel' `
                -Detalhe ('{0}  ->  a sonda "{1}" nao foi casada por regra nenhuma' -f $ondeRegra, $s.Sonda)
            continue
        }

        $mesmaRegra = (($r.Fonte -replace '\\', '/') -eq ($s.Arquivo -replace '\\', '/')) -and ($r.Linha -eq $s.Linha)
        if ($mesmaRegra) {
            $cob.RegrasEfetivas++
            continue
        }

        # O Git aplica o ULTIMO padrao que casa. Uma regra cuja propria sonda
        # e decidida por outra linha nunca decide nada: e peso morto, ou e
        # engano de quem escreveu.
        $achados += New-Achado -Severidade 'BAIXA' -Area 'gitignore' `
            -Categoria 'regra de .gitignore sombreada' `
            -Detalhe ('{0}  ->  quem decidiu foi {1}:{2} ({3})' -f $ondeRegra, $r.Fonte, $r.Linha, $r.Padrao)
    }

    # --- 2. de fora para dentro: segredo canonico esta coberto? -------------
    # A pergunta que importa nao e "a regra existe", e "este nome entraria
    # num commit?". Nomes que nao existem no disco de proposito: a pergunta e
    # sobre o guarda-corpo, nao sobre o arquivo.
    $alvos = @('.env', '.env.local', '.env.production',
               'secrets.json', 'secrets.yaml', 'credentials.json',
               'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519',
               'chave-privada.pem', 'certificado.pfx',
               '.msal_cache', 'service-account.json')

    # A pergunta e feita em CADA diretorio que tem .gitignore, nao so na raiz.
    #
    # Antes era so a raiz, e o efeito estava documentado como defeito pelos
    # dois revisores: o .gitignore de templates/project-standard governa TODO
    # projeto futuro, e os nomes canonicos entraram nele por analogia com a
    # lacuna achada na raiz - sem ninguem perguntar ao Git se um projeto
    # instanciado realmente os ignora.
    $prefixos = @('')
    foreach ($arq in $arquivos) {
        $d = (Split-Path $arq -Parent) -replace '\\', '/'
        if ($d -and ($prefixos -notcontains $d)) { $prefixos += $d }
    }

    foreach ($pref in $prefixos) {
        $comPrefixo = @($alvos | ForEach-Object { if ($pref) { $pref + '/' + $_ } else { $_ } })
        $cob.AlvosCanonicos += $comPrefixo.Count
        $resAlvo = Invoke-CheckIgnore -Path $Path -Caminhos $comPrefixo

        # Agregado, nao um achado por nome: quatorze linhas dizendo a mesma
        # coisa viram ruido, e ruido faz ignorarem o relatorio inteiro.
        $semCobertura = @()
        $naoViaja = @{}
        for ($i = 0; $i -lt $comPrefixo.Count; $i++) {
            $r = $resAlvo[$comPrefixo[$i]]
            if (-not $r -or -not $r.Casou -or -not $r.Ignorado) { $semCobertura += $alvos[$i]; continue }
            if (-not (Test-FonteViajaComRepositorio $r.Fonte)) {
                if (-not $naoViaja.ContainsKey($r.Fonte)) { $naoViaja[$r.Fonte] = @() }
                $naoViaja[$r.Fonte] += $alvos[$i]
                continue
            }
            $cob.AlvosCobertos++
        }
        $onde = 'na raiz'
        if ($pref) { $onde = 'em ' + $pref + '/' }
        if ($semCobertura.Count -gt 0) {
            $achados += New-Achado -Severidade 'BAIXA' -Area 'gitignore' `
                -Categoria 'segredo canonico sem cobertura no .gitignore' `
                -Detalhe ('{0}: {1} de {2} - {3}. Um "git add" versionaria estes nomes. Guarda-corpo ausente, nao vazamento' -f `
                          $onde, $semCobertura.Count, $alvos.Count, ($semCobertura -join ', '))
        }
        foreach ($fonte in $naoViaja.Keys) {
            $achados += New-Achado -Severidade 'BAIXA' -Area 'gitignore' `
                -Categoria 'protecao de segredo nao viaja com o repositorio' `
                -Detalhe ('{0}: {1} cobre {2}, mas nao esta versionado: quem clonar nao recebe a protecao' -f `
                          $onde, $fonte, (($naoViaja[$fonte]) -join ', '))
        }
    }

    return [pscustomobject]@{ Achados = $achados; Cobertura = $cob }
}
