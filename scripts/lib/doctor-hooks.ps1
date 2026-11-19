<#
.SYNOPSIS
    Dimensao HOOKS do /os:doctor: os guarda-corpos locais estao ativos?

.DESCRIPTION
    Pergunta desta dimensao: **o que deveria barrar erro previsivel antes do
    historico esta ligado neste clone?** Ela nasce da 2.6, e da mesma natureza
    das outras seis - diagnostico, nunca acao.

    O DOCTOR NAO INSTALA NADA. Ele diz qual comando instala, e quem roda e a
    mantenedora. A regra e a mesma que o resto da ferramenta cumpre e que a
    2.5 mediu byte a byte: ferramenta que conserta sozinha esconde o problema
    que deveria mostrar.

    A pergunta nao e respondida aqui: quem responde e 'Get-EstadoDosHooks', em
    'hooks-comum.ps1', a MESMA funcao que o instalador chama no '-Verificar'.
    Duas implementacoes da mesma pergunta divergem - a 2.5 pagou isso sete
    vezes, sempre do mesmo jeito: endurece-se uma e a irma fica para tras.

    Severidade, e a razao de cada escolha:

      PASS          instalado e na versao esperada.
      WARN          nao instalado, apontando para outro lugar, ou algum shim
                    fora da versao. NAO e FAIL: hook ausente nao torna o
                    projeto incorreto - torna-o desprotegido contra erro
                    previsivel, que e coisa diferente. E hook local nunca foi
                    fronteira de seguranca: '--no-verify' o contorna, e a
                    verificacao independente e a CI da 2.8.
      INCONCLUSIVO  a pergunta nao pode ser respondida - 'git config' nao
                    respondeu, ou um shim existe e nao le como texto.
                    "Nao consegui perguntar" nunca vira "esta bom".

    Repositorio sem a pasta 'githooks/' versionada nao e defeito: e projeto
    que ainda nao adotou os hooks, e cobrar o que ninguem declarou seria o
    ruido que a dimensao 'ambiente' foi desenhada para nao produzir.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-DiagnosticoHooks {
    param([Parameter(Mandatory = $true)][string]$Raiz)

    $cob = @{
        PastaVersionada = $false
        Esperados       = @($OS_HOOKS_ESPERADOS).Count
        Instalados      = 0
        Ausentes        = 0
        Desatualizados  = 0
        VersaoEsperada  = $OS_HOOKS_VERSAO
        Aponta          = 'indeterminado'
    }
    $verif = @()
    $achados = @()
    $naoVerificado = @()

    $pasta = Join-Path $Raiz $OS_HOOKS_DIR
    $temPasta = (Test-Path $pasta -PathType Container)
    $cob.PastaVersionada = $temPasta

    if (-not $temPasta) {
        # Fato DETERMINADO, nao lacuna: o projeto nao versiona hooks. A
        # distincao entre "nao tem" e "nao consegui ver" e a mesma que a
        # dimensao 'ambiente' faz entre campo ausente e sonda que falhou, e e
        # por isso que isto emite VERIFICACAO e nao 'NaoVerificado'. Lacuna
        # decorativa - a que aparece na tabela de nao-verificado sem mudar o
        # status - foi nomeada na rodada 5 da 2.5 e nao volta aqui.
        $verif += New-VerificacaoDoDoctor -O_que 'hooks versionados' `
            -Resultado "nao se aplica: o projeto nao tem a pasta '$OS_HOOKS_DIR/'"
        return New-DimensaoDoDoctor -Nome 'hooks' -Status 'PASS' -Cobertura $cob -Verificacoes $verif `
            -Motivo 'o projeto nao versiona hooks de Git'
    }

    $estado = Get-EstadoDosHooks -Raiz $Raiz
    $cob.Aponta = $estado.Aponta

    if ($estado.Indeterminado) {
        $naoVerificado += New-NaoVerificadoDoDoctor -O_que 'hooks instalados' -Porque $estado.Motivo
        return New-DimensaoDoDoctor -Nome 'hooks' -Status 'INCONCLUSIVO' -Cobertura $cob -NaoVerificado $naoVerificado `
            -Motivo 'nao deu para saber se os hooks estao ativos'
    }

    $cob.Instalados     = @($estado.Presentes).Count
    $cob.Ausentes       = @($estado.Ausentes).Count
    $cob.Desatualizados = @($estado.Desatualizados).Count

    if ($estado.Instalado) {
        $verif += New-VerificacaoDoDoctor -O_que 'core.hooksPath' -Resultado "aponta para '$OS_HOOKS_DIR'"
        $verif += New-VerificacaoDoDoctor -O_que 'hooks ativos' `
            -Resultado (($estado.Presentes -join ', ') + " - versao $OS_HOOKS_VERSAO")
        return New-DimensaoDoDoctor -Nome 'hooks' -Status 'PASS' -Cobertura $cob -Verificacoes $verif `
            -Motivo "os $($cob.Instalados) hook(s) esperados estao ativos e na versao $OS_HOOKS_VERSAO"
    }

    # Nao instalado, ou instalado pela metade. Os dois sao FATOS medidos - a
    # verificacao registra o que FOI apurado, e o achado diz o que fazer.
    $verif += New-VerificacaoDoDoctor -O_que 'core.hooksPath' `
        -Resultado $(if ($estado.HooksPath) { "vale '$($estado.HooksPath)'" } else { 'nao esta configurado' })

    if (@($estado.Ausentes).Count -gt 0) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'hooks' `
            -Mensagem ("hook(s) nao ativo(s): " + ($estado.Ausentes -join ', ') +
                       " - erro previsivel que eles barrariam entra no historico sem aviso") `
            -Acao '.\scripts\install-hooks.ps1'
    }
    if (@($estado.Desatualizados).Count -gt 0) {
        $achados += New-AchadoDoDoctor -Severidade 'WARN' -Dimensao 'hooks' `
            -Mensagem ("hook(s) fora da versao $($OS_HOOKS_VERSAO): " + ($estado.Desatualizados -join ', ') +
                       " - o arquivo no disco nao e o que este codigo espera") `
            -Acao 'atualize o repositorio, ou rode .\scripts\install-hooks.ps1 -Reparar'
    }

    return New-DimensaoDoDoctor -Nome 'hooks' -Status 'WARN' -Cobertura $cob -Verificacoes $verif -Achados $achados `
        -Motivo $estado.Motivo
}
