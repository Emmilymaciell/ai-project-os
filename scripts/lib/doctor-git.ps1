<#
.SYNOPSIS
    Dimensao GIT do /os:doctor: o estado do Git permite trabalhar?

.DESCRIPTION
    Primeiro consumidor dos tres predicados que roda sobre uma raiz RESOLVIDA
    em vez de assumida. Toda chamada aqui recebe a raiz de
    'Get-RaizDoRepositorio', nunca o caminho que a mantenedora digitou.

    Repositorio recem-inicializado NAO e defeito: 'HEAD' nao nascido e
    historico vazio sao o estado esperado logo depois de '/os:new-project'.
    Tratar isso como FAIL faria o doctor reprovar todo projeto no dia em que
    ele nasce - e um diagnostico que reprova o fluxo normal e um diagnostico
    que se desliga.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-DiagnosticoGit {
    param(
        [Parameter(Mandatory = $true)][string]$Raiz,
        [Parameter(Mandatory = $true)][string]$Forma
    )

    $cob = @{
        HeadResolve         = $false
        TemHistorico        = $false
        RepoNovo            = $false
        ArquivosModificados = 0
        Forma               = $Forma
        StatusLido          = $false
    }
    $achados = @()
    $verif = @()
    $naoVerificado = @()

    # Os predicados LANCAM quando nao conseguem ler - e essa e a resposta
    # certa, nao um inconveniente. Aqui o throw vira INCONCLUSIVO da dimensao,
    # com a razao que o predicado deu: 'nao consegui ler o Git' nunca pode
    # virar 'o Git esta bem'.
    try {
        $cob.TemHistorico = [bool](Test-TemHistorico $Raiz)
        $cob.HeadResolve  = [bool](Test-HeadResolvivel $Raiz)
    } catch {
        return New-DimensaoDoDoctor -Nome 'git' -Status 'INCONCLUSIVO' -Cobertura $cob `
            -Motivo ("o estado do Git NAO foi determinado: " + $_.Exception.Message) `
            -NaoVerificado @(New-NaoVerificadoDoDoctor -O_que 'estado do Git' -Porque $_.Exception.Message)
    }

    $verif += New-VerificacaoDoDoctor -O_que 'HEAD resolve' -Resultado ([string]$cob.HeadResolve)
    $verif += New-VerificacaoDoDoctor -O_que 'historico legivel' -Resultado ([string]$cob.TemHistorico)
    $verif += New-VerificacaoDoDoctor -O_que 'forma do repositorio' -Resultado $Forma

    $saida = @(Invoke-Git @('-C', $Raiz, 'status', '--porcelain') -PermitirFalha)
    if ($LASTEXITCODE -ne 0) {
        return New-DimensaoDoDoctor -Nome 'git' -Status 'INCONCLUSIVO' -Cobertura $cob -Verificacoes $verif `
            -Motivo "o 'git status' falhou: o que esta ou nao commitado NAO foi determinado" `
            -NaoVerificado @(New-NaoVerificadoDoDoctor -O_que 'trabalho nao commitado' -Porque "o 'git status' saiu com codigo $LASTEXITCODE")
    }
    $cob.StatusLido = $true
    $cob.ArquivosModificados = @($saida | Where-Object { $_ }).Count
    $verif += New-VerificacaoDoDoctor -O_que 'arquivos com mudanca nao commitada' -Resultado ([string]$cob.ArquivosModificados)

    # Repositorio novo: sem historico E sem HEAD. Estado ESPERADO, nao desvio.
    $cob.RepoNovo = ((-not $cob.TemHistorico) -and (-not $cob.HeadResolve))
    if ($cob.RepoNovo) {
        return New-DimensaoDoDoctor -Nome 'git' -Status 'PASS' -Cobertura $cob -Verificacoes $verif `
            -Motivo 'repositorio recem-inicializado: HEAD nao nascido e historico vazio sao o estado esperado aqui, nao defeito'
    }

    # Historico existe e o HEAD nao resolve: e o estado 'fetch-only', e ele
    # nao impede trabalhar - impede afirmar em que commit se esta.
    if ($cob.TemHistorico -and -not $cob.HeadResolve) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'git' `
            -Mensagem 'ha historico buscado mas o HEAD local nao resolve: o repositorio tem commits e nao tem branch checada' `
            -Acao 'git checkout -b <branch> <ref remota>'
        return New-DimensaoDoDoctor -Nome 'git' -Status 'WARN' -Cobertura $cob -Verificacoes $verif -Achados $achados `
            -Motivo 'HEAD local nao nascido sobre historico existente'
    }

    if ($cob.ArquivosModificados -gt 0) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'git' `
            -Mensagem "$($cob.ArquivosModificados) arquivo(s) com mudanca nao commitada" `
            -Acao 'revise com git status e decida o que entra no proximo checkpoint'
        return New-DimensaoDoDoctor -Nome 'git' -Status 'WARN' -Cobertura $cob -Verificacoes $verif -Achados $achados `
            -Motivo 'ha trabalho no disco que o historico nao registra'
    }

    return New-DimensaoDoDoctor -Nome 'git' -Status 'PASS' -Cobertura $cob -Verificacoes $verif `
        -Motivo 'HEAD resolve, historico legivel, nada pendente no disco'
}
