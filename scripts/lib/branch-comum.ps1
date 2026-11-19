<#
.SYNOPSIS
    Fatos compartilhados de branch: estado, nome valido, base.

.DESCRIPTION
    UMA funcao responde "em que branch estamos, o que existe, e a arvore esta
    limpa?", e os dois consumidores a chamam - 'branch.ps1' e 'pr.ps1'. Duas
    copias da mesma pergunta divergem: a subfase 2.6 pagou isso sete vezes,
    sempre do mesmo jeito - endurece-se uma e a irma fica para tras.

    O terceiro estado existe aqui pela mesma razao do INCONCLUSIVO do doctor:
    "nao consegui perguntar" nunca pode virar "esta limpo" nem "esta sujo".

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-EstadoDeBranch {
    <#
      Devolve SEMPRE um objeto, nunca $null:
        Atual          nome do branch corrente, ou '' em HEAD destacado
        Destacado      $true quando nao ha branch corrente
        Locais         nomes dos branches locais
        Remotos        nomes dos branches do remoto, sem o prefixo
        Sujos          caminhos nao commitados (rastreados E nao rastreados)
        Base           branch de integracao detectado (ver Get-BaseDeIntegracao)
        Indeterminado  $true quando a PERGUNTA nao pode ser respondida
        Motivo         por que, quando nao deu
    #>
    param([Parameter(Mandatory = $true)][string]$Raiz)

    $r = [pscustomobject]@{
        Atual         = ''
        Destacado     = $false
        Locais        = @()
        Remotos       = @()
        Sujos         = @()
        Base          = ''
        Indeterminado = $false
        Motivo        = ''
    }

    if ([string]::IsNullOrWhiteSpace($Raiz) -or -not (Test-Path $Raiz -PathType Container)) {
        $r.Indeterminado = $true
        $r.Motivo = "a raiz '$Raiz' nao existe no disco"
        return $r
    }

    # --- branch atual ---------------------------------------------------------
    # 'symbolic-ref --short HEAD' falha em HEAD destacado, e isso e RESPOSTA,
    # nao erro: por isso -PermitirFalha e a leitura do codigo.
    $atual = @(Invoke-Git @('-C', $Raiz, 'symbolic-ref', '--short', 'HEAD') -PermitirFalha)
    $codigo = $LASTEXITCODE
    if ($codigo -eq 0 -and @($atual).Count -gt 0) {
        $r.Atual = ("" + @($atual)[0]).Trim()
    } else {
        # Pode ser HEAD destacado, ou repositorio sem commit nenhum. As duas
        # sao fatos diferentes, e confundi-las daria conselho errado.
        $tem = @(Invoke-Git @('-C', $Raiz, 'rev-parse', '--verify', '--quiet', 'HEAD^{commit}') -PermitirFalha)
        if ($LASTEXITCODE -eq 0 -and @($tem).Count -gt 0) {
            $r.Destacado = $true
        } else {
            $r.Atual = ''
        }
    }

    # --- branches locais ------------------------------------------------------
    try {
        $r.Locais = @(Invoke-Git @('-C', $Raiz, 'for-each-ref', '--format=%(refname:short)', 'refs/heads') |
                      ForEach-Object { ("" + $_).Trim() } | Where-Object { $_ -ne '' })
    } catch {
        $r.Indeterminado = $true
        $r.Motivo = "nao foi possivel listar os branches locais: $($_.Exception.Message)"
        return $r
    }

    # --- branches do remoto ---------------------------------------------------
    # Sem rede: 'for-each-ref' le o que ja esta no disco. Um remoto que nunca
    # foi buscado devolve lista vazia, e isso e fato, nao lacuna.
    # O filtro e sobre o refname COMPLETO, e nao sobre a forma curta. MEDIDO:
    # '%(refname:short)' de 'refs/remotes/origin/HEAD' e 'origin' - sem o
    # '/HEAD' -, entao filtrar a forma curta deixava passar um 'origin' que
    # virava um branch chamado 'origin' na listagem. O nome completo sempre
    # termina em '/HEAD', e por isso o filtro vai nele.
    try {
        $r.Remotos = @(Invoke-Git @('-C', $Raiz, 'for-each-ref', '--format=%(refname)', 'refs/remotes') |
                       ForEach-Object { ("" + $_).Trim() } |
                       Where-Object { $_ -ne '' -and $_ -notmatch '/HEAD$' } |
                       ForEach-Object { ($_ -replace '^refs/remotes/[^/]+/', '') } |
                       Where-Object { $_ -ne '' } |
                       Sort-Object -Unique)
    } catch {
        # INDETERMINADO, e nao lista vazia. Achado do qa-reviewer, e ele
        # contradizia o principio escrito no topo deste proprio arquivo:
        # lista vazia aqui fazia '-Trocar' para um branch so remoto sair 1
        # ("nao existe") em vez de 2, e a base cair em ''. "Nao consegui
        # perguntar" virando "nao ha".
        #
        # ESTE CAMINHO NAO TEM CASO DE TESTE, e eu declaro isso em vez de
        # fingir que tem: para faze-lo disparar seria preciso que o
        # 'for-each-ref' sobre 'refs/remotes' falhasse DEPOIS de o de
        # 'refs/heads' ter funcionado, e eu nao achei como forcar isso sem
        # instrumentar o 'Invoke-Git'. Esta no backlog. A correcao e de uma
        # linha e fail-CLOSED - o risco de te-la sem caso e menor que o de
        # deixar o fail-open no lugar -, mas "corrigido" aqui quer dizer
        # "escrito", nao "medido".
        $r.Indeterminado = $true
        $r.Motivo = "nao foi possivel listar os branches do remoto: $($_.Exception.Message)"
        return $r
    }

    # --- arvore suja ----------------------------------------------------------
    # RASTREADO E NAO RASTREADO. Arquivo novo tambem se perde numa troca, e
    # contar so o rastreado daria uma garantia mais estreita que o nome dela.
    try {
        $r.Sujos = @(Invoke-Git @('-C', $Raiz, 'status', '--porcelain') |
                     ForEach-Object { ("" + $_) } | Where-Object { $_.Trim() -ne '' })
    } catch {
        $r.Indeterminado = $true
        $r.Motivo = "nao foi possivel ler 'git status': $($_.Exception.Message)"
        return $r
    }

    $r.Base = Get-BaseDeIntegracao -Raiz $Raiz -Locais $r.Locais -Remotos $r.Remotos
    return $r
}

function Get-BaseDeIntegracao {
    <#
      Qual branch e a base para diff e PR?

      Ordem: o que o remoto aponta como HEAD, depois os nomes convencionais,
      depois o unico branch local quando so ha um. Devolve '' quando nao da
      para saber - e '' e resposta honesta, nao 'main' por chute. Supor 'main'
      num repositorio que usa 'master' produziria diff contra o nada.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Raiz,
        [string[]]$Locais = @(),
        [string[]]$Remotos = @()
    )

    $apontado = @(Invoke-Git @('-C', $Raiz, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD') -PermitirFalha)
    if ($LASTEXITCODE -eq 0 -and @($apontado).Count -gt 0) {
        $nome = ("" + @($apontado)[0]).Trim() -replace '^[^/]+/', ''
        if ($nome) { return $nome }
    }

    foreach ($convencional in @('main', 'master', 'trunk')) {
        if (@($Locais) -contains $convencional -or @($Remotos) -contains $convencional) { return $convencional }
    }

    if (@($Locais).Count -eq 1) { return @($Locais)[0] }
    return ''
}

function Test-NomeDeBranch {
    <#
      Devolve a mensagem do problema, ou '' quando o nome serve.

      A validacao e do PROPRIO Git ('check-ref-format'), e nao uma lista de
      caracteres escrita a mao: lista de caracteres proibidos envelhece e
      diverge da ferramenta.

      SOBRE AS REGRAS MANUAIS - e esta prosa ja esteve errada DUAS vezes, nas
      duas rodadas de revisao, sempre sobre as mesmas tres linhas.

      Versao 1, errada: "espaco e hifen sao o que o check-ref-format ACEITA e
      esta casa nao quer". O qa-reviewer contestou. Medido: os dois saem 128,
      entao o check-ref-format recusa os dois.

      Versao 2, tambem errada: "o 128 do '-flag' e o git lendo opcao
      desconhecida". O qa-reviewer contestou de novo e deu a medicao exata.
      Medida nesta maquina:

        check-ref-format --flag-inventada      -> 129   (erro de USO)
        check-ref-format --branch '-flag'      -> 128   (nome recusado)
        check-ref-format --branch 'com espaco' -> 128
        check-ref-format --branch 'a..b'       -> 128
        check-ref-format --branch 'ok/nome'    -> 0

      129 e o codigo de erro de uso; 128 e recusa de nome. Entao o '-flag' e
      recusado COMO NOME, e nao como opcao.

      A VERDADE, enfim: as DUAS regras manuais sao redundantes quanto ao
      veredito. O que elas acrescentam e so a MENSAGEM - dizer o que ha de
      errado no nome em vez de "o Git recusa". E por isso o caso de teste
      delas mede a MENSAGEM: medir so o veredito deixaria as duas linhas
      removiveis sem derrubar nada, que e o que o revisor apontou.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Nome)

    if ([string]::IsNullOrWhiteSpace($Nome)) { return 'o nome do branch esta vazio' }
    if ($Nome -match '\s') { return "o nome '$Nome' tem espaco, e isso quebra a citacao em toda linha de comando" }
    if ($Nome.StartsWith('-')) { return "o nome '$Nome' comeca com hifen, e seria lido como flag" }

    $null = Invoke-Git @('check-ref-format', '--branch', $Nome) -PermitirFalha
    if ($LASTEXITCODE -ne 0) { return "o Git recusa '$Nome' como nome de branch" }
    return ''
}
