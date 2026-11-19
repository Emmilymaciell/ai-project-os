<#
.SYNOPSIS
    Fatos compartilhados dos hooks de Git: o que se espera, e o que esta no disco.

.DESCRIPTION
    Os hooks da subfase 2.6 sao ORQUESTRADORES. Eles nao varrem conteudo, nao
    diagnosticam e nao rodam suite propria: chamam o que ja existe -
    security-scan.ps1, doctor.ps1, e o 'verificacao.comando' do manifesto - e
    decidem passar ou barrar pelo codigo de saida que aqueles ja definem
    (ADR-0009). Detector novo aqui significaria dois detectores divergindo em
    silencio, que e o defeito que esta plataforma ja pagou mais de uma vez.

    ESTE arquivo existe para que a pergunta "os hooks estao instalados?" tenha
    UMA resposta. Ela e feita pelo instalador ('-Verificar') e pelo /os:doctor
    (dimensao 'hooks'), e a licao de sete rodadas da 2.5 e que duas copias da
    mesma pergunta divergem: endurece-se uma e a outra fica para tras. Aqui ha
    uma funcao, e os dois consumidores a chamam.

    MECANISMO: 'core.hooksPath' apontando para a pasta VERSIONADA 'githooks/'.
    Nao ha copia para '.git/hooks', e isso e desenho, nao economia: o que nao
    e copiado nao diverge da origem. O que pode divergir - e por isso e
    medido - e o proprio arquivo versionado ficar para tras da versao que o
    codigo espera, e a marca de versao dentro de cada shim responde isso.

    MEDIDO nesta maquina, nao suposto:
      - 'core.hooksPath' RELATIVO funciona, e resolve contra o topo da working
        tree: o hook disparou identico a partir da raiz e de um subdiretorio;
      - o diretorio corrente do hook e o topo da working tree;
      - 'GIT_DIR' NAO veio preenchido no commit-msg deste Git for Windows.
        Por isso nada aqui depende dela: a raiz e resolvida por
        Get-RaizDoRepositorio, que ja trata as duas situacoes;
      - caminho com espaco (OneDrive) funciona, desde que toda expansao no
        shim esteja entre aspas;
      - o bit de execucao nao e exigido no Windows.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

# Versao do CONTRATO dos shims. Subir isto sem regravar os arquivos de
# 'githooks/' e exatamente o que a dimensao 'hooks' do doctor acusa como
# desatualizado - a afirmacao de versao tem detector, que e a licao que a 2.5
# fechou com quatro mutacoes de prosa.
$OS_HOOKS_VERSAO = '1'

# Pasta VERSIONADA. Nao e '.git/hooks' de proposito: aquilo nao viaja num
# clone, e o contrato desta plataforma e que um clone novo se configure por
# mecanismo documentado e deterministico.
#
# Tambem nao e 'hooks/', que ja esta reservada para os hooks de PLUGIN do
# Claude Code ('hooks/hooks.json', contado em project.yaml como 'plugin.hooks').
# Sao duas coisas diferentes com o mesmo nome, e misturar as duas numa pasta
# so faria a contagem do manifesto deixar de significar alguma coisa.
$OS_HOOKS_DIR = 'githooks'

$OS_HOOKS_ESPERADOS = @('commit-msg', 'pre-commit', 'pre-push')

function Get-MarcaDeVersaoDeHook {
    # A linha que todo shim carrega. E o unico jeito de saber se o arquivo no
    # disco e da versao que este codigo espera.
    param([string]$Versao = $OS_HOOKS_VERSAO)
    return "# os-hooks-versao: $Versao"
}

function Get-EstadoDosHooks {
    <#
      Responde, para um repositorio: os hooks esperados estao instalados?

      Devolve SEMPRE um objeto, nunca $null:
        Instalado      $true so quando tudo esta no lugar
        HooksPath      o valor configurado, '' quando nao ha
        Aponta         'certo' | 'outro-lugar' | 'ausente' | 'indeterminado'
        Ausentes       nomes de hook esperados que nao existem no disco
        Desatualizados nomes de hook cuja marca de versao nao e a esperada
        Presentes      nomes de hook no disco com a marca certa
        Indeterminado  $true quando a PERGUNTA nao pode ser respondida
        Motivo         por que, quando nao deu

      'Indeterminado' e o terceiro estado, e ele existe pela mesma razao que o
      INCONCLUSIVO do doctor: "nao consegui perguntar" nunca pode virar "esta
      instalado" nem "nao esta". Quem consome decide o que fazer com isso, e
      as duas decisoes ja estao tomadas - o instalador repara, o doctor
      declara lacuna.
    #>
    param([Parameter(Mandatory = $true)][string]$Raiz)

    $r = [pscustomobject]@{
        Instalado      = $false
        HooksPath      = ''
        Aponta         = 'indeterminado'
        Ausentes       = @()
        Desatualizados = @()
        Presentes      = @()
        Indeterminado  = $false
        Motivo         = ''
    }

    if ([string]::IsNullOrWhiteSpace($Raiz) -or -not (Test-Path $Raiz -PathType Container)) {
        $r.Indeterminado = $true
        $r.Motivo = "a raiz '$Raiz' nao existe no disco"
        return $r
    }

    $valor = ''
    try {
        $saida = @(Invoke-Git @('-C', $Raiz, 'config', '--get', 'core.hooksPath') -PermitirFalha)
        $codigo = $LASTEXITCODE
        if ($codigo -eq 0 -and @($saida).Count -gt 0) { $valor = ("" + @($saida)[0]).Trim() }
        elseif ($codigo -ne 1) {
            # 1 e a resposta NORMAL do git para "essa chave nao existe".
            # Qualquer outro codigo e o git nao tendo respondido, e tratar
            # isso como "nao configurado" seria transformar falha de leitura
            # em fato sobre o repositorio.
            $r.Indeterminado = $true
            $r.Motivo = "'git config --get core.hooksPath' saiu com $codigo"
            return $r
        }
    } catch {
        $r.Indeterminado = $true
        $r.Motivo = "nao foi possivel ler 'core.hooksPath': $($_.Exception.Message)"
        return $r
    }

    $r.HooksPath = $valor
    if ([string]::IsNullOrWhiteSpace($valor)) {
        $r.Aponta = 'ausente'
        $r.Ausentes = @($OS_HOOKS_ESPERADOS)
        $r.Motivo = "'core.hooksPath' nao esta configurado neste repositorio"
        return $r
    }

    # O valor pode ser relativo (o esperado) ou absoluto (alguem configurou na
    # mao). Os dois sao resolvidos contra a raiz antes de comparar, senao
    # 'githooks' e '<raiz>\githooks' pareceriam destinos diferentes.
    $alvo = $valor
    try {
        if (-not [System.IO.Path]::IsPathRooted($alvo)) { $alvo = Join-Path $Raiz $valor }
        $alvo = [System.IO.Path]::GetFullPath($alvo)
    } catch {
        $r.Indeterminado = $true
        $r.Motivo = "'core.hooksPath' vale '$valor', que nao resolve para um caminho"
        return $r
    }

    $esperado = ''
    try { $esperado = [System.IO.Path]::GetFullPath((Join-Path $Raiz $OS_HOOKS_DIR)) }
    catch {
        $r.Indeterminado = $true
        $r.Motivo = "nao foi possivel resolver '$OS_HOOKS_DIR' a partir de '$Raiz'"
        return $r
    }

    if ($alvo.TrimEnd('\') -ne $esperado.TrimEnd('\')) {
        $r.Aponta = 'outro-lugar'
        $r.Ausentes = @($OS_HOOKS_ESPERADOS)
        $r.Motivo = "'core.hooksPath' aponta para '$valor', e os hooks versionados estao em '$OS_HOOKS_DIR'"
        return $r
    }

    $r.Aponta = 'certo'
    $marca = Get-MarcaDeVersaoDeHook
    $ausentes = @()
    $velhos = @()
    $ok = @()
    foreach ($nome in $OS_HOOKS_ESPERADOS) {
        $p = Join-Path $esperado $nome
        if (-not (Test-Path $p -PathType Leaf)) { $ausentes += $nome; continue }
        $txt = Read-TextoDeArquivo $p
        if ($null -eq $txt) {
            # Arquivo que nao le como texto nao pode ser declarado nem em dia
            # nem desatualizado. E lacuna, e sobe como indeterminado.
            $r.Indeterminado = $true
            $r.Motivo = "o hook '$nome' existe e nao pode ser lido como texto"
            return $r
        }
        if ($txt -like "*$marca*") { $ok += $nome } else { $velhos += $nome }
    }

    $r.Ausentes = @($ausentes)
    $r.Desatualizados = @($velhos)
    $r.Presentes = @($ok)
    $r.Instalado = (@($ausentes).Count -eq 0 -and @($velhos).Count -eq 0)
    if (-not $r.Instalado) {
        $partes = @()
        if (@($ausentes).Count -gt 0) { $partes += "ausente(s): $($ausentes -join ', ')" }
        if (@($velhos).Count -gt 0)  { $partes += "fora da versao $($OS_HOOKS_VERSAO): $($velhos -join ', ')" }
        $r.Motivo = ($partes -join '; ')
    }
    return $r
}

function Test-MensagemDeCommit {
    <#
      As regras do commit-msg, como FUNCAO PURA sobre o texto. O hook so le o
      arquivo e chama isto; toda a decisao esta aqui, onde o teste alcanca sem
      precisar de repositorio.

      Tres regras, todas ESTRUTURAIS e conferiveis por qualquer um. Convencao
      estilistica - tipo do Conventional Commits, modo verbal, ponto final -
      NAO entra: bloquear gosto transforma o hook em coisa que se contorna por
      habito, e hook contornado por habito nao protege nada.

        A  o assunto nao pode ser vazio;
        B  se existir uma linha 2, ela TEM de ser vazia;
        C  o assunto nao pode passar de 100 caracteres.

      B e a regra que o defeito real desta casa pede: em 2026-09-22 o commit
      de fechamento da 2.5 foi criado sem a linha em branco separadora, e o
      assunto engoliu o primeiro paragrafo inteiro do corpo - 350 caracteres
      numa linha que 'git log --oneline' e toda interface de repositorio
      truncam. O conteudo estava certo; a estrutura, nao.

      C existe porque B sozinha nao alcanca a mesma frase escrita em UMA linha
      so, sem corpo nenhum. O limite e deliberadamente generoso - a convencao
      do Git recomenda 50, e 72 e o teto usual - justamente para nao virar
      regra de estilo: 100 caracteres so barra o que ja nao e um assunto.

      Devolve: Ok, Problemas (lista de string), Assunto, Isento.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Texto,
        [string]$CaractereDeComentario = '#',
        [int]$LimiteDoAssunto = 100
    )

    $problemas = @()

    # 1. O que o git nao considera mensagem sai antes de qualquer regra.
    $linhas = @(($Texto -replace "`r`n", "`n" -replace "`r", "`n") -split "`n")

    # A tesoura do '--verbose': tudo abaixo dela e o diff que o git mostra
    # para quem escreve, e nunca entra na mensagem.
    $corte = -1
    for ($i = 0; $i -lt $linhas.Count; $i++) {
        if ($linhas[$i] -match '^\s*' + [regex]::Escape($CaractereDeComentario) + '\s*-+\s*>8\s*-+') { $corte = $i; break }
    }
    if ($corte -ge 0) { $linhas = @($linhas[0..([Math]::Max($corte - 1, 0))]) ; if ($corte -eq 0) { $linhas = @() } }

    $uteis = @()
    foreach ($l in $linhas) {
        if ($l -match ('^\s*' + [regex]::Escape($CaractereDeComentario))) { continue }
        $uteis += $l
    }

    # Linhas vazias das pontas nao sao estrutura: o proprio git as descarta.
    #
    # A guarda de UM elemento tem de estar nos DOIS lacos, e o motivo e uma
    # armadilha do PowerShell que custou um travamento aqui: com um elemento
    # so, '$uteis[1..0]' NAO e intervalo vazio - o operador INVERTE o sentido
    # e devolve dois itens ($null e o elemento). O array nunca encolhia, e o
    # laco rodava para sempre sobre uma mensagem feita so de espaco.
    #
    # Corrigir so o laco de baixo - onde a guarda ja estava - teria deixado o
    # de cima aberto: e o "mesmo defeito, um ramo ao lado" que a 2.5 viu sete
    # vezes. Por isso os dois lacos saem pela mesma porta.
    while (@($uteis).Count -gt 0 -and [string]::IsNullOrWhiteSpace($uteis[0])) {
        if (@($uteis).Count -eq 1) { $uteis = @(); break }
        $uteis = @($uteis[1..($uteis.Count - 1)])
    }
    while (@($uteis).Count -gt 0 -and [string]::IsNullOrWhiteSpace($uteis[-1])) {
        if (@($uteis).Count -eq 1) { $uteis = @(); break }
        $uteis = @($uteis[0..($uteis.Count - 2)])
    }

    $assunto = ''
    if (@($uteis).Count -gt 0) { $assunto = $uteis[0] }

    # Mensagens GERADAS pelo proprio git para serem consumidas por ele: o
    # 'rebase --autosquash' exige o formato de uma linha, e bloquea-las seria
    # o hook brigando com o Git. Nao e cortesia estilistica - e correcao.
    $isento = ($assunto -match '^(fixup|squash|amend)!\s')
    if ($isento) {
        return [pscustomobject]@{ Ok = $true; Problemas = @(); Assunto = $assunto; Isento = $true }
    }

    if (@($uteis).Count -eq 0 -or [string]::IsNullOrWhiteSpace($assunto)) {
        $problemas += 'a mensagem esta vazia: sem assunto nao ha o que registrar'
        return [pscustomobject]@{ Ok = $false; Problemas = $problemas; Assunto = ''; Isento = $false }
    }

    if (@($uteis).Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($uteis[1])) {
        $problemas += ("a linha 2 nao esta em branco: o assunto e o corpo precisam de UMA linha vazia entre eles, " +
                       "senao o assunto absorve o primeiro paragrafo (linha 2 comeca com: '" +
                       (Get-TrechoCurtoDeLinha $uteis[1]) + "')")
    }

    if ($assunto.Length -gt $LimiteDoAssunto) {
        $problemas += ("o assunto tem $($assunto.Length) caracteres e o limite e ${LimiteDoAssunto}: " +
                       "acima disso nao e assunto, e 'git log --oneline' e toda interface de repositorio truncam")
    }

    return [pscustomobject]@{
        Ok        = (@($problemas).Count -eq 0)
        Problemas = @($problemas)
        Assunto   = $assunto
        Isento    = $false
    }
}

function Invoke-FilhoDoHook {
    <#
      Roda um processo filho e devolve saida e codigo, SEM deixar stderr
      derrubar o hook.

      Isto existe por um defeito medido, achado pelo qa-reviewer: os hooks
      rodam sob '$ErrorActionPreference = Stop', e no PowerShell 5.1 o stderr
      de executavel nativo redirecionado com '2>&1' vira ErrorRecord - que sob
      'Stop' e TERMINANTE. O 'trap' do hook pegava, e o push saia com 2
      dizendo "NAO consegui rodar as verificacoes".

      Consequencia medida, com uma suite falsa que escreve em stderr e sai 0:
      sob 'Stop' LANCOU; sob 'Continue' devolveu exit 0. Ou seja, uma suite
      que PASSOU e imprimiu um aviso barrava o push - e uma que REPROVOU e
      imprimiu algo saia 2 em vez de 1, trocando "reprovou" por "nao consegui
      medir". Atrito e diagnostico errado, que e o par que ensina
      '--no-verify'.

      A armadilha esta documentada em docs/runbooks/gotchas-windows-powershell.md
      e ja custou tempo real nesta plataforma tres vezes: 'Invoke-Git' e
      'Invoke-NativoLocal' nasceram dela. Esta e a terceira porta, e por isso e
      UMA funcao usada pelos QUATRO sitios de chamada dos dois hooks, e nao
      quatro trechos parecidos.

      SOBRE O 'finally' QUE RESTAURA: ele e simetria, nao protecao, e o
      comentario diz isso para nao prometer o que nao entrega. MEDIDO: atribuir
      '$ErrorActionPreference' dentro de uma funcao e de ESCOPO DA FUNCAO - a
      preferencia de quem chamou nunca e tocada, com ou sem o restauro. Ele
      fica porque e a forma que 'Invoke-Git' e 'Invoke-NativoLocal' ja usam, e
      porque protege o resto DESTA funcao se ela crescer.
    #>
    param([Parameter(Mandatory = $true)][string[]]$Argumentos)

    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # Esta e a chamada direta a 'powershell' que o guarda de regressao
        # da suite permite neste arquivo - e ele a conhece pelo CONTEUDO
        # EXATO desta linha, numa lista fechada, com contagem.
        #
        # Nao ha marcador em comentario, e a razao e um achado do
        # qa-reviewer: marcador e permissao que SE AUTODECLARA. Bastava
        # copiar a linha com o comentario junto - que e o que alguem faria,
        # copiando a unica chamada que funciona no repositorio - para o
        # guarda ficar verde com o defeito de volta.
        $saida = (& powershell @Argumentos 2>&1 | Out-String)
        $codigo = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $anterior
    }
    return [pscustomobject]@{ Saida = $saida; Exit = $codigo }
}

function Get-AchadosBloqueantesDoRelatorio {
    <#
      Extrai do relatorio do scanner as linhas de achado que BLOQUEIAM, para
      que a mensagem do hook diga O QUE achou e nao so que achou.

      Le apenas a secao '## Achados' - nao o arquivo inteiro. A secao
      seguinte, '## Achados ACEITOS POR EXCECAO', tambem tem linhas 'MEDIA', e
      elas NAO bloqueiam: despeja-las aqui faria o hook acusar como causa do
      barramento justamente o que foi deliberadamente aceito (ADR-0010).

      Devolve lista vazia quando nao acha nada - inclusive quando o relatorio
      nao existe ou nao le. Quem chama ja sabe, pelo codigo de saida do
      scanner, que houve bloqueio; isto so enriquece a mensagem, e nunca
      substitui aquele fato.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho, [int]$Max = 10)

    if (-not (Test-Path $Caminho -PathType Leaf)) { return @() }
    $txt = Read-TextoDeArquivo $Caminho
    if ($null -eq $txt) { return @() }

    $linhas = @(($txt -replace "`r`n", "`n") -split "`n")
    $dentro = $false
    $achados = @()
    foreach ($l in $linhas) {
        if ($l -match '^##\s') {
            # Entra em '## Achados' e sai em QUALQUER cabecalho seguinte,
            # inclusive no de excecoes, que comeca com o mesmo prefixo.
            $dentro = ($l -match '^##\s+Achados\s*$')
            continue
        }
        if (-not $dentro) { continue }
        if ($l -match '^\|\s*(ALTA|MEDIA)\s*\|') {
            $achados += $l.Trim()
            if (@($achados).Count -ge $Max) { break }
        }
    }
    return @($achados)
}

function Get-TrechoCurtoDeLinha {
    # Pedaco curto, para a mensagem de erro mostrar ONDE sem despejar a linha
    # inteira no terminal.
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Linha, [int]$Max = 40)
    $t = $Linha.Trim()
    if ($t.Length -le $Max) { return $t }
    return ($t.Substring(0, $Max) + '...')
}

function Write-ProblemaDeHook {
    # Toda saida de bloqueio passa por aqui, para que TODA mensagem carregue
    # acao concreta. Mensagem de hook sem "e agora o que eu faco" e o que
    # ensina a usar '--no-verify' por reflexo.
    param(
        [Parameter(Mandatory = $true)][string]$Hook,
        [Parameter(Mandatory = $true)][string[]]$Problemas,
        [string[]]$Acoes = @()
    )
    Write-Host ''
    Write-Host "[$Hook] BARRADO" -ForegroundColor Red
    foreach ($p in $Problemas) { Write-Host "  - $p" -ForegroundColor Red }
    if (@($Acoes).Count -gt 0) {
        Write-Host ''
        Write-Host '  O que fazer:' -ForegroundColor Yellow
        foreach ($a in $Acoes) { Write-Host "    $a" -ForegroundColor Yellow }
    }
    Write-Host ''
}
