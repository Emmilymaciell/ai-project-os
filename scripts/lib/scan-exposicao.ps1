<#
.SYNOPSIS
    Detector: exposicao externa (remoto, webhook, endpoint, credencial em CI).

.DESCRIPTION
    Fecha o quarto ponto INCONCLUSIVO da subfase 2.2.

    Tres perguntas, porque sao tres riscos diferentes:

      1. PARA ONDE este repositorio empurra? Um remoto publico transforma
         todo commit em publicacao. Ler '.git/config' diz a URL, nao a
         visibilidade - visibilidade e estado do servidor, e a unica forma
         deterministica de saber e perguntar a API. Se nao der para
         perguntar, isso NAO vira aprovacao: vira lacuna declarada.

      2. Para onde o CODIGO fala? Webhook do Slack, do Teams, do Discord ou
         do n8n num arquivo versionado e um canal de saida que qualquer
         pessoa com o repositorio passa a poder usar. URL de tunel publico
         (ngrok) versionada e o inverso: um canal de ENTRADA.

      3. A automacao carrega segredo literal? Em configuracao de CI, o certo
         e referenciar o cofre. Valor literal no YAML e credencial commitada
         com outra roupa.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-PadroesExposicao {
    return @(
        @{ nome = 'webhook do Slack';     sev = 'ALTA';  re = 'https://hooks\.slack\.com/services/[A-Za-z0-9/]{8,}' },
        @{ nome = 'webhook do Discord';   sev = 'ALTA';  re = 'https://discord(app)?\.com/api/webhooks/[0-9]{5,}' },
        @{ nome = 'webhook do Teams';     sev = 'ALTA';  re = 'https://[A-Za-z0-9\-]+\.webhook\.office\.com/webhookb2/' },
        @{ nome = 'URL com credencial embutida'; sev = 'ALTA'; re = 'https?://[^\s/:@]+:[^\s/@]{3,}@' },
        @{ nome = 'webhook do n8n';       sev = 'MEDIA'; re = 'https://[A-Za-z0-9\-]+\.app\.n8n\.cloud/webhook/' },
        @{ nome = 'tunel publico (ngrok)'; sev = 'MEDIA'; re = 'https://[A-Za-z0-9\-]+\.ngrok(-free)?\.(io|app)' },
        @{ nome = 'coletor de requisicao publico'; sev = 'MEDIA'; re = 'https://webhook\.site/[A-Za-z0-9\-]{8,}' },
        # BAIXA, e a diferenca importa. URL de SharePoint nao e capacidade:
        # ela exige autenticacao para ser usada, ao contrario de um webhook,
        # que qualquer um com a URL dispara. O que ela revela e o tenant do
        # cliente - fato para contestar, nao exposicao.
        #
        # Como MEDIA, ela travava para sempre todo projeto governado que
        # documentasse a origem dos dados no README - e nao existe 'MEDIA
        # aceita'. Era o modo de falha do ADR-0009 deslocado para os projetos
        # que a plataforma governa, e o PROG e exatamente esse caso. Achado do
        # qa-reviewer.
        @{ nome = 'endpoint corporativo do SharePoint'; sev = 'BAIXA'; re = 'https://[A-Za-z0-9\-]+\.sharepoint\.com/' }
    )
}

function Get-ArquivosDeCI {
    param([string]$Path)
    $rastreados    = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z'))
    $naoRastreados = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z', '--others', '--exclude-standard'))
    $todos = @(Get-CaminhosUnicos @($rastreados + $naoRastreados))
    return @($todos | Where-Object {
        $n = $_ -replace '\\', '/'
        ($n -match '^\.github/workflows/.+\.ya?ml$') -or
        ($n -match '(^|/)\.gitlab-ci\.ya?ml$') -or
        ($n -match '(^|/)azure-pipelines\.ya?ml$') -or
        ($n -match '(^|/)Jenkinsfile$') -or
        ($n -match '^\.circleci/config\.ya?ml$')
    })
}

function Get-CaminhoDoGh {
    <#
      O gh esta instalado nesta maquina e NAO esta no PATH desta sessao -
      medido, nao suposto: a primeira execucao da varredura reportou "gh nao
      disponivel" e deixou a visibilidade do remoto sem resposta, com o gh em
      'C:\Program Files\GitHub CLI\gh.exe'. Mesmo padrao do CLI claude, que
      tambem vive fora do PATH aqui.

      Procurar no PATH e, se nao achar, nos lugares conhecidos. Se nao achar
      em nenhum, devolve $null - e a area fica com lacuna declarada, nunca
      aprovada por omissao.
    #>
    # COSTURA DE TESTE, declarada. $env:OS_SCAN_GH substitui o executavel
    # consultado.
    #
    # Existe porque o detector de 'remoto PUBLICO' - um dos achados ALTA da
    # area de exposicao - nao tinha teste nenhum, nem positivo nem negativo:
    # as 24 invocacoes funcionais da suite passavam -SemRede, e o unico sinal
    # de que ele funcionava era a execucao real deste repositorio, que
    # exercita so o ramo PRIVATE. Isso viola a politica 4.1 que esta propria
    # subfase impoe. Achado do qa-reviewer.
    #
    # Alternativa seria nao testar. Codigo que fala com a rede so e testavel
    # com costura; a costura fica visivel e nomeada, nao escondida.
    if ($env:OS_SCAN_GH) { return $env:OS_SCAN_GH }

    $c = Get-Command gh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    # Cada base e testada ANTES do Join-Path: com a variavel de ambiente
    # ausente, 'Join-Path $null' lanca sob ErrorActionPreference=Stop e o
    # trap devolve exit 2 - ou seja, "a varredura nao aconteceu" por causa de
    # uma variavel que nem existe em host de 32 bits. Achado de
    # portabilidade do qa-reviewer na subfase 2.3.
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not $base) { continue }
        $p = Join-Path $base 'GitHub CLI\gh.exe'
        if (Test-Path $p) { return $p }
    }
    if ($env:LOCALAPPDATA) {
        $p = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\gh.exe'
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-OwnerRepoDoGitHub {
    param([string]$Url)
    $m = [regex]::Match($Url, '(?i)github\.com[:/]+([A-Za-z0-9._\-]+)/([A-Za-z0-9._\-]+?)(\.git)?/?$')
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value + '/' + $m.Groups[2].Value)
}

function Get-AchadosExposicao {
    <#
      -SemRede desliga a consulta de visibilidade. Nao e um atalho para
      passar: sem rede a area fica com lacuna declarada, e o revisor le isso
      antes dos achados.
    #>
    param([string]$Path, [switch]$SemRede)

    $achados = @()
    $cob = @{
        Remotos               = 0
        VisibilidadeVerificada = @()
        VisibilidadeSemResposta = @()
        ArquivosDeCI          = 0
        ArquivosDeCIAusentes  = 0
        ArquivosExaminados    = 0
        # Contado, e nao descartado com um 'continue' silencioso.
        #
        # A rodada anterior corrigiu isso em 'working tree' e 'dado de
        # terceiro' e ESTA area ficou. Cenario do qa-reviewer: um
        # 'deploy.conf' rastreado, sem extensao reconhecida, contendo um
        # webhook do Slack - conteudo nao lido, nenhuma lacuna declarada, e o
        # relatorio afirmando 'exposicao externa | sim'. O revisor, que e
        # instruido a ler a cobertura ANTES dos achados, aprovaria a area com
        # base numa declaracao falsa.
        SemExtensaoDeTexto    = 0
        AusentesDoDisco       = 0
        NaoLidosPorCodificacao = 0
        GhDisponivel          = $false
        RedeConsultada        = (-not $SemRede)
    }

    # --- 1. remotos -----------------------------------------------------------
    $urls = @()
    foreach ($l in @(Invoke-Git @('-C', $Path, 'remote', '-v'))) {
        $p = $l -split '\s+'
        if ($p.Count -ge 2) { $urls += $p[1] }
    }
    $urls = @($urls | Sort-Object -Unique)
    $cob.Remotos = $urls.Count

    # Guarda de sanidade. O security-reviewer nomeou a assimetria que condena
    # a versao anterior: este arquivo e escrupuloso quando o 'gh' falha - tem
    # quatro motivos distintos de "sem resposta" logo abaixo - e era cego
    # quando o 'git' falhava. Sem remoto nenhum, VisibilidadeSemResposta
    # ficava vazia, a area saia 'sim' com "nenhum remoto", e um repositorio
    # com remoto PUBLICO cujo 'remote -v' falhou era declarado coberto, sem
    # achado ALTA. O .git/config e texto puro: da para conferir.
    if ($urls.Count -eq 0) {
        # ComumDir, nao '$Path/.git/config'. A guarda testava o caminho literal, e em
        # worktree ligado '.git' e ARQUIVO: Test-Path dava falso e a guarda ficava
        # INERTE em silencio - justamente a unica guarda ALTA desta area.
        #
        # O defeito e PRE-EXISTENTE, e mais antigo e mais largo do que qualquer
        # um de nos supos. A primeira versao deste comentario dizia que a
        # separacao dos predicados tinha tornado o defeito alcancavel; o
        # qa-reviewer mostrou que nao - o predicado antigo so lancava quando o
        # 'rev-parse' FALHAVA, e em worktree COM commits ele resolve. O scanner
        # ja rodava aqui. O security-reviewer fechou a questao com uma terceira
        # evidencia: o portao de entrada do scanner testa '.git' SEM -PathType,
        # entao worktree e submodulo sempre passaram pela porta.
        #
        # E a inercia nunca foi especifica de worktree: '.git' como ARQUIVO e
        # tambem submodulo e '--separate-git-dir' - esta ultima aplicada ao
        # repositorio PRINCIPAL, que e como se tira o .git de pasta
        # sincronizada, cenario real nesta casa (ADR-0002).
        #
        # Corrigido aqui por custar duas linhas, nao por ter sido criado aqui.
        $gDir = Get-CaminhosDoGit -Path $Path
        if ($null -eq $gDir) {
            throw ("o 'git remote -v' nao devolveu remoto nenhum, e nao foi possivel localizar " +
                   "o diretorio Git para conferir o config. A visibilidade do remoto NAO foi " +
                   "verificada - e remoto publico e um dos achados ALTA desta area.")
        }
        $cfg = Join-Path $gDir.ComumDir 'config'
        if (Test-Path $cfg -PathType Leaf) {
            # LANCA quando o config nao e legivel, em vez de seguir com o
            # texto corrompido. A leitura leniente trocava byte invalido por
            # U+FFFD, o '-match' nao casava, e a guarda ficava INERTE pelo
            # unico motivo que ela existe para cobrir: nao da para afirmar que
            # nao ha remoto declarado.
            $txtCfg = Read-TextoDeArquivo $cfg
            if ($null -eq $txtCfg) {
                throw ("o 'git remote -v' nao devolveu remoto nenhum, e o .git/config nao e legivel " +
                       "como texto para conferir. A visibilidade do remoto NAO foi verificada - " +
                       "e remoto publico e um dos achados ALTA desta area.")
            }
            if ($txtCfg -match '(?m)^\s*\[remote ') {
                throw ("o 'git remote -v' nao devolveu remoto nenhum, mas o .git/config declara " +
                       "pelo menos um [remote]. A visibilidade do remoto NAO foi verificada - " +
                       "e remoto publico e um dos achados ALTA desta area.")
            }
        }
    }

    $gh = Get-CaminhoDoGh
    $cob.GhDisponivel = [bool]$gh

    foreach ($u in $urls) {
        if ($u -match 'https?://[^\s/:@]+:[^\s/@]{3,}@') {
            $achados += New-Achado -Severidade 'ALTA' -Area 'exposicao externa' `
                -Categoria 'credencial embutida na URL do remoto' `
                -Detalhe 'a URL de um remoto carrega usuario e senha - valor nao transcrito'
            continue
        }
        $slug = Get-OwnerRepoDoGitHub $u
        if (-not $slug) {
            $cob.VisibilidadeSemResposta += ($u + ' (host nao reconhecido: visibilidade nao consultavel)')
            continue
        }
        if ($SemRede -or -not $gh) {
            $motivo = 'consulta de rede desligada'
            if (-not $gh) { $motivo = 'gh nao disponivel' }
            $cob.VisibilidadeSemResposta += ($slug + ' (' + $motivo + ')')
            continue
        }
        $vis = $null
        try { $vis = (& $gh repo view $slug --json visibility -q .visibility 2>$null) } catch { $vis = $null }
        if ($LASTEXITCODE -ne 0 -or -not $vis) {
            $cob.VisibilidadeSemResposta += ($slug + ' (a API nao respondeu)')
            continue
        }
        $vis = (@($vis) -join '').Trim().ToUpper()
        # Resposta que nao e um dos valores conhecidos NAO conta como
        # verificada. Sem esta guarda, um 'gh' que renomeie o campo devolve
        # vazio com exit 0, a area e declarada COBERTA com valor lixo
        # ('owner/repo = ') e o achado ALTA nunca sai - cobertura reduzida em
        # silencio, que e o modo de falha que a politica 4.5 existe para
        # impedir. Cenario apontado pelo qa-reviewer.
        if (@('PUBLIC', 'PRIVATE', 'INTERNAL') -notcontains $vis) {
            $cob.VisibilidadeSemResposta += ($slug + ' (a API respondeu algo que nao e uma visibilidade conhecida)')
            continue
        }
        $cob.VisibilidadeVerificada += ($slug + ' = ' + $vis)
        if ($vis -eq 'PUBLIC') {
            $achados += New-Achado -Severidade 'ALTA' -Area 'exposicao externa' `
                -Categoria 'remoto PUBLICO' `
                -Detalhe ($slug + ' - todo push publica. ADR-0003 define privado por padrao')
        }
    }

    # --- 2. webhook e endpoint no conteudo -----------------------------------
    $rastreados    = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z'))
    $naoRastreados = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z', '--others', '--exclude-standard'))
    $todos = @(Get-CaminhosUnicos @($rastreados + $naoRastreados))
    $conjNaoRastreados = New-ConjuntoOrdinal $naoRastreados
    $padroes = Get-PadroesExposicao

    foreach ($f in $todos) {
        if (-not (Test-ArquivoDeTexto $f -Raiz $Path)) { $cob.SemExtensaoDeTexto++; continue }
        $abs = Join-Path $Path $f
        if (-not (Test-Path -LiteralPath $abs)) {
            # CONTADO, nao descartado - e aqui o silencio era pior que nas
            # outras areas. O qa-reviewer mostrou por que: a linha de lacuna
            # que eu havia escrito afirmava "o blob ainda e alcancavel pelo
            # historico, e e la que ele aparece". Para credencial, verdade.
            # Para EXPOSICAO, FALSO - o scan-historico carrega so
            # Get-PadroesConteudo, nunca Get-PadroesExposicao. Um arquivo
            # rastreado com webhook, apagado do disco sem 'git add', nao era
            # lido aqui, nao era procurado no historico com padrao de webhook,
            # e o relatorio saia exit 0 dizendo 'exposicao externa | sim'.
            $cob.AusentesDoDisco++
            continue
        }
        $txt = Read-TextoDeArquivo $abs
        if ($null -eq $txt) { $cob.NaoLidosPorCodificacao++; continue }
        $cob.ArquivosExaminados++
        $ehFixture = Test-DeclaraFixture $txt
        $sufixo = ''
        if ($conjNaoRastreados.Contains($f)) { $sufixo = ' [nao rastreado]' }
        foreach ($p in $padroes) {
            $m = [regex]::Matches($txt, $p.re)
            if ($m.Count -eq 0) { continue }
            $linha = Get-LinhaAproximada -Texto $txt -Index $m[0].Index
            $det = ('{0}{1} linha ~{2}, {3} ocorrencia(s) - URL nao transcrita' -f $f, $sufixo, $linha, $m.Count)
            if ($ehFixture) {
                $achados += New-Achado -Severidade 'BAIXA' -Area 'exposicao externa' -Caminho $f `
                    -Categoria ('fixture declarada: ' + $p.nome) -Detalhe $det
            } else {
                $achados += New-Achado -Severidade $p.sev -Area 'exposicao externa' -Caminho $f `
                    -Categoria $p.nome -Detalhe $det
            }
        }
    }

    # --- 3. configuracao de CI ------------------------------------------------
    $ci = Get-ArquivosDeCI -Path $Path
    # NAO fixar aqui. 'ArquivosDeCI' passou a contar o que foi de fato LIDO, e
    # o que o git lista mas o disco nao tem entra em ArquivosDeCIAusentes -
    # que agora tem consumidor no relatorio. A versao anterior fixava o total
    # antes do laco e imprimia "1 arquivo(s) de CI" tendo lido zero, sem
    # nenhuma razao "X de N" para reconciliar. Achado do qa-reviewer, e ele
    # notou que eu tinha criado o contador e nunca o lido - simbolo adicionado
    # sem consumidor, a classe que o teste novo de referencias agora pega.
    foreach ($f in $ci) {
        $abs = Join-Path $Path $f
        if (-not (Test-Path -LiteralPath $abs)) {
            # Quarto laco, achado pelos dois. Nao produz 'sim' falso - o mesmo
            # arquivo ja cai em AusentesDoDisco no laco de conteudo, e isso
            # derruba a area para parcial. O que se corrige aqui e a
            # SOBRE-CONTAGEM: "N arquivo(s) de CI" contava arquivo nao lido.
            $cob.ArquivosDeCIAusentes++
            continue
        }
        # NAO incrementa o contador aqui, de proposito. O conjunto de CI e
        # SUBCONJUNTO do de conteudo - '.yml' e Jenkinsfile sao extensoes de
        # texto -, entao o mesmo arquivo ja passou pelo laco de cima e ja foi
        # contado. Incrementar nos dois faz a linha de cobertura dizer "2
        # ILEGIVEL(eis)" com UM arquivo na lista nomeada: numero de cobertura
        # que nao reconcilia com a lista. E a mesma sobre-contagem que o
        # comentario de 'ArquivosDeCIAusentes' logo acima diz ter corrigido,
        # reintroduzida no contador novo. Achado do qa-reviewer.
        $txt = Read-TextoDeArquivo $abs
        if ($null -eq $txt) { continue }
        $cob.ArquivosDeCI++
        $ehFixture = Test-DeclaraFixture $txt

        # Valor literal, e nao referencia a cofre. Referencia legitima -
        # '${{ secrets.X }}' no GitHub, '$VAR' em shell - nao casa porque a
        # classe de caractere do valor exclui '$', '{' e '}'. Ou seja: o
        # filtro esta no padrao, e nao ha um segundo teste depois dele.
        foreach ($m in [regex]::Matches($txt, '(?im)^\s*[A-Za-z0-9_\-]*(token|secret|key|password|senha|pat)[A-Za-z0-9_\-]*\s*[:=]\s*[''"]([A-Za-z0-9_\-\/\+=\.]{16,})[''"]')) {
            $linha = Get-LinhaAproximada -Texto $txt -Index $m.Index
            $sev = 'ALTA'
            $cat = 'credencial literal em configuracao de CI'
            if ($ehFixture) { $sev = 'BAIXA'; $cat = 'fixture declarada: ' + $cat }
            $achados += New-Achado -Severidade $sev -Area 'exposicao externa' -Caminho $f `
                -Categoria $cat -Detalhe ('{0} linha ~{1} - valor nao transcrito' -f $f, $linha)
        }

        foreach ($m in [regex]::Matches($txt, 'pull_request_target')) {
            $linha = Get-LinhaAproximada -Texto $txt -Index $m.Index
            $sev = 'MEDIA'
            $cat = 'gatilho de CI que expoe segredo a fork'
            if ($ehFixture) { $sev = 'BAIXA'; $cat = 'fixture declarada: ' + $cat }
            $achados += New-Achado -Severidade $sev -Area 'exposicao externa' -Caminho $f `
                -Categoria $cat `
                -Detalhe ('{0} linha ~{1} - pull_request_target roda com os segredos do repositorio sobre codigo de fora' -f $f, $linha)
            break
        }
    }

    return [pscustomobject]@{ Achados = $achados; Cobertura = $cob }
}
