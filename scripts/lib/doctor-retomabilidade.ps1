<#
.SYNOPSIS
    Dimensao RETOMABILIDADE do /os:doctor: o repositorio sozinho basta?

.DESCRIPTION
    E a pergunta que da razao de existir a plataforma inteira - projeto nao e
    sessao -, e ate aqui nenhuma ferramenta a fazia. 'tests' responde se o
    comportamento funciona; '/os:security' responde se ha risco; nenhuma das
    duas responde se alguem consegue retomar isto daqui a seis meses sem
    nenhuma conversa.

    Tudo aqui e deterministico: existencia de arquivo, presenca de secao,
    comparacao de data. Nada depende de julgamento sobre a QUALIDADE do texto -
    isso nao e diagnostico, e opiniao, e opiniao nao entra em ferramenta que
    sai com codigo.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-DiagnosticoRetomabilidade {
    param([Parameter(Mandatory = $true)][string]$Raiz)

    $cob = @{
        StateExiste     = $false
        StateLegivel    = $false
        TemData         = $false
        TemProximoPasso = $false
        Adrs            = 0
        ReadmeExiste    = $false
        StateDesatualizado = $false
        SemHistorico    = $false
    }
    $achados = @()
    $verif = @()
    $naoVerificado = @()

    $state = Join-Path $Raiz 'docs\STATE.md'
    $cob.StateExiste = (Test-Path $state -PathType Leaf)
    $cob.ReadmeExiste = (Test-Path (Join-Path $Raiz 'README.md') -PathType Leaf)

    $dirAdr = Join-Path $Raiz 'docs\decisions'
    if (Test-Path $dirAdr -PathType Container) {
        $cob.Adrs = @(Get-ChildItem $dirAdr -File -Filter 'ADR-*.md' -ErrorAction SilentlyContinue).Count
    }
    $verif += New-VerificacaoDoDoctor -O_que 'ADRs em docs/decisions' -Resultado ([string]$cob.Adrs)
    $verif += New-VerificacaoDoDoctor -O_que 'README.md existe' -Resultado ([string]$cob.ReadmeExiste)

    if (-not $cob.StateExiste) {
        $achados += New-AchadoDoDoctor -Severidade 'FAIL' -Dimensao 'retomabilidade' `
            -Mensagem 'nao existe docs/STATE.md: o repositorio nao registra onde o trabalho parou' `
            -Caminho 'docs/STATE.md' -Acao 'rode /os:resume, que oferece reconstruir o STATE.md a partir do que der para inferir'
        return New-DimensaoDoDoctor -Nome 'retomabilidade' -Status 'FAIL' -Cobertura $cob -Verificacoes $verif -Achados $achados `
            -Motivo 'sem STATE.md, retomar depende de arqueologia do historico - que e reconstrucao, nao registro'
    }

    # Ilegivel NAO e ausente. Sao dois fatos diferentes e levam a status
    # diferentes: ausente e determinado (FAIL), ilegivel e 'nao consegui'
    # (INCONCLUSIVO).
    $txt = Read-TextoDeArquivo $state
    if ($null -eq $txt) {
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que 'conteudo do docs/STATE.md' `
            -Porque 'o arquivo existe e NAO e legivel como texto (UTF-8 invalido, ou NUL no conteudo)'
        return New-DimensaoDoDoctor -Nome 'retomabilidade' -Status 'INCONCLUSIVO' -Cobertura $cob -Verificacoes $verif -NaoVerificado $naoVerificado `
            -Motivo 'o STATE.md existe e nao foi lido: nada pode ser afirmado sobre o que ele registra'
    }
    $cob.StateLegivel = $true

    # SEM acento no padrao, e isto nao e estilo: o 5.1 le '.ps1' UTF-8 sem BOM
    # como ANSI, entao um 'u' com acento no fonte chega ao regex como mojibake e
    # nunca casa. Ha teste que reprova qualquer byte acima de 127 em '.ps1'.
    # O '.' cobre a letra acentuada sem depender da codificacao do fonte, e o
    # primeiro diagnostico deste detector contra o repositorio real acusou
    # AUSENCIA de duas secoes que estavam la.
    $cob.TemData = [bool]($txt -match '(?i)ltima atualiza')
    $cob.TemProximoPasso = [bool]($txt -match '(?i)pr.ximo passo')
    $verif += New-VerificacaoDoDoctor -O_que 'STATE declara data de atualizacao' -Resultado ([string]$cob.TemData)
    $verif += New-VerificacaoDoDoctor -O_que 'STATE declara proximo passo' -Resultado ([string]$cob.TemProximoPasso)

    # STATE atras da realidade: compara o COMMIT que tocou o STATE pela ultima
    # vez com o ultimo commit do repositorio.
    #
    # A primeira versao comparava a data de MODIFICACAO do arquivo com a data
    # do ultimo commit, e era falso positivo POR CONSTRUCAO: commitar nao muda
    # o mtime, entao o arquivo e sempre mais antigo que o commit que o contem.
    # O proprio repositorio da plataforma acusou isso na primeira execucao,
    # com o STATE.md recem-atualizado e commitado.
    # PERGUNTAR ANTES se ha historico, em vez de deduzir da falha do 'git log'.
    #
    # Em repositorio sem nenhum commit o 'git log' sai com 128, nao com 0 e
    # saida vazia. A versao anterior caia no ramo de falha, emitia a lacuna
    # "o 'git log' nao respondeu", e isso derrubava a dimensao para
    # INCONCLUSIVO - que domina e faz o doctor sair com 2 sobre um repositorio
    # RECEM-CRIADO. Ou seja: o estado exato logo depois de '/os:new-project',
    # onde a regra de ouro proibe commitar sem pedido, era reprovado pelo
    # diagnostico. Contradizia o principio escrito no proprio doctor-git.ps1 e
    # na SKILL.md - "repositorio recem-criado e esperado, nao defeito" - e o
    # ramo escrito para esse caso era INALCANCAVEL. Achado do qa-reviewer.
    # O predicado dentro de try/catch, como a dimensao 'git' ja fazia. Fora
    # dele, com ref QUEBRADA - estado que a propria suite exercita - a excecao
    # subia ate o 'trap' de doctor.ps1 e o doctor saia 2 SEM GRAVAR nem o
    # relatorio nem o JSON: o unico caminho em que ele nao produz diagnostico
    # nenhum, contra o proprio desenho ("dimensao que nao conseguiu rodar vira
    # INCONCLUSIVO, e o relatorio sai mesmo assim"). Achado do qa-reviewer.
    # UM rotulo para UM fato, e a verificacao emitida NO RAMO que estabeleceu o
    # fato - nao no fim, atras de uma guarda que compara string.
    #
    # A versao anterior perguntava, no fim, se existia lacuna com um literal
    # escrito a mao. Havia DUAS emissoes de lacuna sobre o mesmo fato, com
    # rotulos diferentes ('STATE atualizado no ultimo commit' e 'se o STATE
    # esta atras do ultimo commit'), e a segunda passava pela guarda: o
    # artefato voltava a afirmar 'True' sobre o que a dimensao dissera nao ter
    # medido. Quinta aparicao da mesma forma, e a terceira vez que um conserto
    # por string deixou o ramo vizinho aberto. Achado do qa-reviewer na oitava
    # rodada, com a entrada concreta 'git checkout --orphan': 'rev-list --all'
    # enxerga refs/heads/main e diz que HA historico, e o 'git log -1' sai 128
    # porque o HEAD nao nasceu.
    #
    # Guarda-corpo desta escolha: a invariante de 'New-DimensaoDoDoctor' compara
    # 'O_que' por igualdade. Enquanto houver UM rotulo por fato, ela alcanca -
    # e e por isso que o rotulo aparece uma vez por ramo, e nunca numa condicao.
    $ROTULO_STATE = 'STATE atualizado no ultimo commit'

    $temHistorico = $null
    try { $temHistorico = [bool](Test-TemHistorico $Raiz) } catch { $temHistorico = $null }

    if ($null -eq $temHistorico) {
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que $ROTULO_STATE `
            -Porque "nao deu para saber se o repositorio tem historico: o git falhou ao responder (ref quebrada, ou .git ilegivel). A dimensao NAO conseguiu medir"
    } elseif (-not $temHistorico) {
        $verif += New-VerificacaoDoDoctor -O_que $ROTULO_STATE `
            -Resultado 'nao se aplica: repositorio sem commits'
        $cob.SemHistorico = $true
    } else {

    $ultimoDoState = @(Invoke-Git @('-C', $Raiz, 'log', '-1', '--format=%H', '--', 'docs/STATE.md') -PermitirFalha)
    $codigoState = $LASTEXITCODE
    $ultimoDoRepo = @(Invoke-Git @('-C', $Raiz, 'log', '-1', '--format=%H') -PermitirFalha)
    $codigoRepo = $LASTEXITCODE

    if ($codigoState -ne 0 -or $codigoRepo -ne 0) {
        # MESMO rotulo do ramo de cima. Era aqui que a divergencia vivia.
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que $ROTULO_STATE `
            -Porque "o 'git log' nao respondeu num repositorio que TEM historico: isso e falha de leitura (HEAD nao nascido sobre refs existentes, ou .git ilegivel)"
    } elseif (@($ultimoDoState).Count -eq 0 -or -not $ultimoDoState[0]) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'retomabilidade' `
            -Mensagem 'o docs/STATE.md existe no disco e nunca foi commitado: o registro nao viaja com o repositorio' `
            -Caminho 'docs/STATE.md' -Acao 'inclua o STATE.md no proximo checkpoint'
        # 'Nunca commitado' e fato determinado, e NAO e 'esta em dia': afirmar
        # 'True' aqui seria a mesma verdade vacua que o manifesto ja corrigiu.
        $verif += New-VerificacaoDoDoctor -O_que $ROTULO_STATE `
            -Resultado 'nao se aplica: o docs/STATE.md nunca foi commitado'
    } elseif ($ultimoDoState[0] -ne $ultimoDoRepo[0]) {
        # Quantos commits entraram DEPOIS do que tocou o STATE. Um so ja e
        # sinal; o numero diz o tamanho do atraso.
        $desde = @(Invoke-Git @('-C', $Raiz, 'rev-list', '--count', ($ultimoDoState[0] + '..HEAD')) -PermitirFalha)
        $quantos = '?'
        if ($LASTEXITCODE -eq 0 -and @($desde).Count -gt 0) { $quantos = $desde[0] }
        if ($quantos -ne '0') {
            $cob.StateDesatualizado = $true
            # Contagem que NAO foi lida nao vira numero na mensagem. Com o
            # 'rev-list --count' falhando, '$quantos' e '?' - e escrever
            # "entraram ? commit(s)" apresenta uma leitura que falhou como
            # contagem medida, na dimensao que acabou de trocar 'True' por
            # 'nao se aplica' justamente para nao fazer isso. O FATO - o STATE
            # esta atras - continua determinado pelos dois shas. Achado do
            # qa-reviewer na nona rodada.
            $quanto = if ($quantos -eq '?') { 'entrou trabalho' } else { "entraram $quantos commit(s)" }
            $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'retomabilidade' `
                -Mensagem "$quanto depois do ultimo commit que tocou o docs/STATE.md: houve trabalho que o registro nao descreve" `
                -Caminho 'docs/STATE.md' -Acao 'atualize o STATE.md antes do proximo checkpoint'
        }
        $verif += New-VerificacaoDoDoctor -O_que $ROTULO_STATE -Resultado ([string](-not $cob.StateDesatualizado))
    } else {
        # Os dois shas batem: o STATE foi tocado pelo ultimo commit. Medido.
        $verif += New-VerificacaoDoDoctor -O_que $ROTULO_STATE -Resultado ([string](-not $cob.StateDesatualizado))
    }

    }

    if (-not $cob.TemData) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'retomabilidade' `
            -Mensagem 'o STATE.md nao declara quando foi atualizado: nao da para saber se esta velho' `
            -Caminho 'docs/STATE.md' -Acao 'acrescente a linha de ultima atualizacao'
    }
    if (-not $cob.TemProximoPasso) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'retomabilidade' `
            -Mensagem 'o STATE.md nao declara o proximo passo: quem retomar nao sabe por onde continuar' `
            -Caminho 'docs/STATE.md' -Acao 'acrescente a secao de proximo passo'
    }
    if ($cob.Adrs -eq 0) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'retomabilidade' `
            -Mensagem 'nenhum ADR em docs/decisions: as decisoes que restringem o trabalho nao estao registradas' `
            -Acao 'registre as decisoes que ja foram tomadas antes que elas sejam reabertas por esquecimento'
    }

    $status = 'PASS'
    $motivo = 'o repositorio registra onde o trabalho parou, e as decisoes estao escritas'
    if (@($achados).Count -gt 0) {
        $status = 'WARN'
        $motivo = 'o registro existe, com lacunas que atrapalham quem retomar'
    }
    if (@($naoVerificado).Count -gt 0) {
        # Lacuna de leitura nao vira WARN nem PASS. A regra e a mesma do
        # scanner: fato que emite linha de lacuna derruba a dimensao.
        $status = 'INCONCLUSIVO'
        $motivo = 'parte desta dimensao nao pode ser verificada'
    }
    return New-DimensaoDoDoctor -Nome 'retomabilidade' -Status $status -Cobertura $cob `
        -Verificacoes $verif -Achados $achados -NaoVerificado $naoVerificado -Motivo $motivo
}
