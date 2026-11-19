<#
.SYNOPSIS
    Varredura de seguranca deterministica. Produz FATOS, nao veredito.

.DESCRIPTION
    Parte do desenho do ADR-0008: toda execucao deterministica acontece FORA
    dos agentes revisores. Este script varre e escreve um relatorio; o
    security-reviewer le o relatorio e julga.

    Versao da subfase 2.3. Fecha as quatro areas que a 2.2 deixou
    INCONCLUSIVO - historico do Git, .gitignore regra por regra, dado de
    terceiro e exposicao externa - cada uma num detector proprio em
    scripts/lib/, testavel isoladamente com par positivo e negativo.

    O relatorio declara cobertura POR AREA, porque o veredito do revisor e
    por area. Area sem evidencia nao vira aprovacao: vira lacuna declarada,
    e o revisor le a secao de lacunas antes dos achados (politica 4.5).

    Codigo de saida - ver ADR-0009:
      0  nenhum achado ALTA nem MEDIA (pode haver BAIXA no relatorio)
      1  pelo menos um achado ALTA ou MEDIA
      2  erro de execucao

    BAIXA nao trava porque BAIXA nao e exposicao: e guarda-corpo ausente,
    fixture declarada ou identidade do proprio autor. Continua no relatorio.

.PARAMETER Path
    Raiz do repositorio a varrer. Default: diretorio atual.

.PARAMETER Out
    Arquivo de relatorio. Default: <Path>/artifacts/review/security-report.md
    QUANDO esse destino esta ignorado pelo .gitignore do alvo. Se nao estiver
    (repositorio de terceiro, anterior ao template), o default passa a ser
    %TEMP%\emmily-os-scan\<repo>-<data-hora>\security-report.md, e o caminho
    e impresso - varrer nao pode sujar o working tree de outro repositorio
    (item 157 do backlog). '-Out' explicito e sempre respeitado.

.PARAMETER SemHistorico
    Pula a varredura do historico. Use apenas onde a latencia importa (hook
    de pre-commit). A area fica com lacuna declarada, nao aprovada.

.PARAMETER SemRede
    Nao consulta a visibilidade do remoto pela API. Mesma regra: a lacuna e
    declarada.

.EXAMPLE
    .\scripts\security-scan.ps1
    .\scripts\security-scan.ps1 -Path <raiz-de-outro-repositorio>
    .\scripts\security-scan.ps1 -SemHistorico -SemRede

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [string]$Out,
    [switch]$SemHistorico,
    [switch]$SemRede,
    # Modo publicacao: TODA excecao aprovada e ignorada e o achado bloqueia.
    # Excecao de seguranca vale para o fluxo privado autorizado; publicar ou
    # exportar publicamente exige sanitizacao (ADR-0010).
    [switch]$ParaPublicacao,
    [int]$MaxBlobKB = 512,
    [int]$MaxBlobs = 5000
)

$ErrorActionPreference = 'Stop'

# Erro inesperado sai com 2, nao com 1. Sem isto um abort seria
# indistinguivel de "coletou com lacunas", e quem chama decidiria errado.
trap { Write-Host "ERRO inesperado: $_" -ForegroundColor Red; exit 2 }

if (-not (Test-Path (Join-Path $Path '.git'))) {
    Write-Host "ERRO: $Path nao e um repositorio Git." -ForegroundColor Red
    exit 2
}

# Lista explicita, nao glob: se um detector desaparecer, isto quebra alto em
# vez de varrer menos em silencio. Cobertura reduzida sem aviso e o modo de
# falha que a politica 4.5 existe para impedir.
$lib = Join-Path $PSScriptRoot 'lib'
$LIBS = @('scan-comum.ps1', 'scan-historico.ps1', 'scan-gitignore.ps1',
          'scan-dado-pessoal.ps1', 'scan-exposicao.ps1', 'scan-excecoes.ps1')
foreach ($m in $LIBS) {
    $p = Join-Path $lib $m
    if (-not (Test-Path $p)) {
        Write-Host "ERRO: detector ausente: $p" -ForegroundColor Red
        exit 2
    }
    . $p
}

# Quem assina os commits deste repositorio, derivado do proprio historico.
# Publicado aqui, uma vez, para que a ordem em que os detectores rodam nao
# altere o resultado: o detector de historico tambem classifica e-mail, e
# depender de ter rodado depois do detector de dado pessoal seria um
# acoplamento invisivel.
$Global:OsScanIdentidades = Get-IdentidadesDoRepositorio -Path $Path

# Destino padrao so DENTRO do alvo quando o alvo o ignora - item 157 do
# backlog. A versao anterior gravava 'artifacts/review/security-report.md'
# em qualquer repositorio, e num repositorio de terceiro sem 'artifacts/' no
# .gitignore isso deixava 'artifacts/' nao rastreado no 'git status' dele: a varredura,
# que so devia LER, sujava o WIP de outra pessoa. E o achado MEDIA que o
# scanner emitia a seguir ("destino nao ignorado") era sobre um problema que
# o proprio scanner tinha acabado de criar.
#
# Perguntado ao git, nao inferido do texto do .gitignore: regra de
# subdiretorio, negacao e excludesfile global so o git resolve. Codigo 0 e
# ignorado, 1 e NAO ignorado, e qualquer outro e falha - que nao pode virar
# "ignorado" (sujaria o alvo) nem "nao ignorado" sem dizer nada.
$destinoRedirecionado = $false
if (-not $Out) {
    Invoke-Git @('-C', $Path, 'check-ignore', '-q', 'artifacts/review/security-report.md') -PermitirFalha | Out-Null
    $codDestino = $LASTEXITCODE
    if ($codDestino -eq 0) {
        $Out = Join-Path $Path 'artifacts\review\security-report.md'
    } elseif ($codDestino -eq 1) {
        $baseTemp = $env:TEMP
        if ($baseTemp -and (Test-Path -LiteralPath $baseTemp -PathType Container)) {
            # Nome longo, nao o 8.3: '$env:TEMP' nesta maquina e 'USUARI~1', e
            # o caminho impresso tem de ser o que a pessoa reconhece.
            $baseTemp = (Get-Item -LiteralPath $baseTemp).FullName
        } else {
            $baseTemp = [System.IO.Path]::GetTempPath()
        }
        $nomeRepo = Split-Path -Leaf ($Path.TrimEnd([char]'\', [char]'/'))
        if (-not $nomeRepo) { $nomeRepo = 'repositorio' }
        $carimboDir = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $Out = Join-Path $baseTemp ('emmily-os-scan\' + $nomeRepo + '-' + $carimboDir + '\security-report.md')
        $destinoRedirecionado = $true
        Write-Host ("AVISO: 'artifacts/' NAO esta ignorado em '" + $Path + "'. Para nao sujar o working tree " +
                    "desse repositorio, o relatorio vai FORA dele: " + $Out) -ForegroundColor Yellow
    } else {
        throw ("git check-ignore saiu com " + $codDestino + " ao decidir o destino do relatorio. " +
               "A varredura NAO aconteceu - nao confunda com ausencia de achado.")
    }
}
$dirOut = Split-Path -Parent $Out
if (-not (Test-Path $dirOut)) { New-Item -ItemType Directory -Path $dirOut -Force | Out-Null }

$achados = @()
function Add-Achado {
    param([string]$Severidade, [string]$Categoria, [string]$Detalhe,
          [string]$Area = 'working tree', [string]$Caminho = '')
    $script:achados += New-Achado -Severidade $Severidade -Categoria $Categoria `
        -Detalhe $Detalhe -Area $Area -Caminho $Caminho
}

# =============================================================================
# 0. o proprio destino do relatorio esta protegido?
# =============================================================================
# O relatorio aponta onde estao os problemas. Se o destino nao estiver
# ignorado no repo-alvo, um 'git add .' o versiona - e a execucao seguinte
# ainda o listaria como arquivo novo, inflando o relatorio com a propria
# saida. Repositorios anteriores ao template do OS nao ignoram artifacts/.
# A pergunta so faz sentido se o destino estiver DENTRO do repositorio-alvo.
# Com '-Out' apontando para fora, o 'git check-ignore' recusa o caminho com
# "is outside repository", e sob ErrorActionPreference=Stop isso derruba o
# script com exit 2 - defeito herdado da versao 2.2, onde nenhum teste usava
# '-Out' fora do repo. Varrer um repositorio sem escrever nada dentro dele e
# uso legitimo, inclusive para nao sujar repo de terceiro.
# Comparacao com separador, nao prefixo solto. Sem o separador,
# '-Path C:\proj -Out C:\projeto-relatorios\r.md' passava por "dentro do
# repositorio": o caminho relativo virava 'eto-relatorios\r.md',
# 'check-ignore' dizia "nao ignorado" e saia um MEDIA bloqueante por um
# arquivo que esta FORA do repo - alem de o relatorio afirmar ter feito uma
# verificacao que nao se aplica. Achado do qa-reviewer; o teste anterior nao
# pegava porque fixture e destino eram nomes irmaos sem prefixo comum.
$relDestino = $Out
$destinoDentroDoRepo = $false
$raizComSep = $Path.TrimEnd([char]'\', [char]'/') + [System.IO.Path]::DirectorySeparatorChar
if ($Out.StartsWith($raizComSep, [System.StringComparison]::OrdinalIgnoreCase)) {
    $destinoDentroDoRepo = $true
    $relDestino = $Out.Substring($raizComSep.Length).TrimStart([char]'\', [char]'/')
}
if ($destinoDentroDoRepo) {
    Invoke-Git @('-C', $Path, 'check-ignore', '-q', $relDestino) -PermitirFalha | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Achado 'MEDIA' 'destino do relatorio nao ignorado' `
            ($relDestino + ' - o relatorio de varredura pode acabar versionado')
    }
}

# =============================================================================
# 1. working tree: nome de arquivo
# =============================================================================
# Rastreados E nao rastreados. O security-reviewer achou o ponto cego na 2.2:
# iterar so 'git ls-files' torna o scanner CEGO ao codigo recem-escrito - que
# e exatamente o codigo sob revisao. Arquivo ignorado pelo .gitignore fica
# fora de proposito: ele nao vai para o remoto.
$rastreados    = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z'))
$naoRastreados = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z', '--others', '--exclude-standard'))
$todos = @(Get-CaminhosUnicos @($rastreados + $naoRastreados))
# Pertinencia por ORDINAL: '-contains' confunde NFC com NFD (item 156).
$conjNaoRastreados = New-ConjuntoOrdinal $naoRastreados

# Guarda de sanidade: git que SAI COM 0 e contradiz o disco.
#
# O Invoke-Git ja lanca quando o git FALHA. Falta o caso em que ele responde
# com sucesso e a resposta e implausivel - indice ilegivel devolvendo lista
# vazia, por exemplo. O security-reviewer mediu a consequencia: zero arquivo
# examinado, as seis areas declaradas cobertas, secao de lacunas dizendo
# "(nenhuma)", exit 0. Scanner afirmando "limpo" sobre repositorio que nunca
# leu e a violacao da politica 4.5 dentro de um detector de seguranca.
if ($todos.Count -eq 0) {
    $noDisco = @(Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notmatch '\\\.git\\' } |
                 Select-Object -First 1)
    if ($noDisco.Count -gt 0) {
        throw ("o git devolveu ZERO arquivo, mas existe arquivo no disco (ex.: '" +
               $noDisco[0].Name + "'). Leitura do repositorio falhou sem codigo de erro. " +
               "A varredura NAO aconteceu - nao confunda com repositorio limpo.")
    }
}

$reNome = Get-PadraoNomeSensivel
foreach ($f in $rastreados) {
    if ($f -match $reNome) { Add-Achado 'ALTA' 'arquivo sensivel rastreado' $f 'working tree' $f }
}
foreach ($f in $naoRastreados) {
    if ($f -match $reNome) { Add-Achado 'ALTA' 'arquivo sensivel nao rastreado (entraria num git add)' $f 'working tree' $f }
}

# =============================================================================
# 2. working tree: conteudo
# =============================================================================
# Fixture de teste negativo contem, por necessidade, algo em formato de
# credencial. Sem tratamento o scanner acusa o proprio teste, e o ruido faz
# ignorarem o scanner - pior que nao ter scanner. A solucao NAO e allowlist
# que silencia: e RECLASSIFICAR. O achado continua no relatorio, com
# severidade BAIXA e categoria propria, e quem revisa decide. Por isso um
# segredo de verdade num arquivo marcado ainda aparece, e ha teste que prova.
$padroes = Get-PadroesConteudo

$examinados = 0
$ignoradosPorTipo = 0
$chavesWT = @()      # 'caminho|padrao' - o historico usa para nao repetir
# Carimbo de integridade: bytes e linhas de cada arquivo examinado. Em unidade
# que um revisor read-only consegue conferir sozinho - ele nao tem Bash para
# hash nem data de modificacao, mas le o arquivo e conta linhas.
$ausentesDoDisco = 0
$listaAusentes = @()
# Arquivo com extensao de texto que NAO da para ler como texto. Contado e
# nomeado, nunca somado aos examinados - backlog item 11.
$naoLidosPorCodificacao = 0
$listaNaoLidos = @()
$carimbo = @()
foreach ($f in $todos) {
    if (-not (Test-ArquivoDeTexto $f -Raiz $Path)) { $ignoradosPorTipo++; continue }
    $abs = Join-Path $Path $f
    if (-not (Test-Path -LiteralPath $abs)) {
        # CONTADO, nao descartado. Arquivo rastreado que nao esta no disco -
        # deletado sem 'git add', tipicamente - nao pode sair do balanco em
        # silencio: o security-reviewer somou 78 + 7 = 85 unicos contra 84
        # examinados e nao achou linha para o que faltava. E a mesma classe do
        # BlobsSemConteudo, corrigida na 2.3 no detector de historico e
        # reaparecida aqui, no scanner principal.
        $script:ausentesDoDisco++
        # Guarda o CAMINHO, nao so o numero. O security-reviewer so conseguiu
        # fechar esta lacuna cruzando com o relatorio de diff: quem receba
        # apenas o relatorio de seguranca cai em INCONCLUSIVO por falta de um
        # dado que o scanner tem em maos aqui. Relatorio que declara a propria
        # cobertura tem de ser autossuficiente.
        if ($script:listaAusentes.Count -lt 20) { $script:listaAusentes += $f }
        continue
    }
    # Lido ANTES de contar e ANTES de carimbar. O leitor anterior
    # ([Text.Encoding]::UTF8) trocava byte invalido por U+FFFD em silencio, e
    # um arquivo UTF-16 sem BOM - que e UTF-8 VALIDO, byte a byte - saia como
    # texto salpicado de NUL: nenhum dos 8 padroes de credencial casava, o
    # arquivo entrava no carimbo com contagem de linha derivada do lixo, e o
    # relatorio o declarava examinado. Falso verde de manual.
    $txt = Read-TextoDeArquivo $abs
    if ($null -eq $txt) {
        $script:naoLidosPorCodificacao++
        if ($script:listaNaoLidos.Count -lt 20) { $script:listaNaoLidos += $f }
        continue
    }
    $examinados++
    $carimbo += [pscustomobject]@{
        Nome   = $f
        Bytes  = (Get-Item -LiteralPath $abs).Length
        Linhas = (Measure-Linhas $txt)
    }
    $ehFixture = Test-DeclaraFixture $txt
    $sufixo = ''
    if ($conjNaoRastreados.Contains($f)) { $sufixo = ' [nao rastreado]' }
    foreach ($p in $padroes) {
        $m = [regex]::Matches($txt, $p.re)
        if ($m.Count -eq 0) { continue }
        # A chave carrega a impressao do CONJUNTO de valores, nao so o nome do
        # padrao: token rotacionado no mesmo arquivo produzia a mesma chave, e
        # o token ANTIGO do historico era descartado como coincidente.
        $chavesWT += ($f + '|' + $p.nome + '|' + (Get-ImpressaoDeValores @($m | ForEach-Object { $_.Value })))
        # Nunca ecoar o valor. Reportar onde, nao o que.
        $linha = Get-LinhaAproximada -Texto $txt -Index $m[0].Index
        $detalhe = "$f linha ~$linha ($($m.Count) ocorrencia(s))$sufixo"
        if ($ehFixture) {
            Add-Achado 'BAIXA' ('fixture declarada: ' + $p.nome) $detalhe 'working tree' $f
        } else {
            Add-Achado 'ALTA' ('possivel ' + $p.nome) $detalhe 'working tree' $f
        }
    }
}

# =============================================================================
# 3. .env existe e esta ignorado?
# =============================================================================
$envReal = Join-Path $Path '.env'
if (Test-Path $envReal) {
    Invoke-Git @('-C', $Path, 'check-ignore', '-q', '.env') -PermitirFalha | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Add-Achado 'ALTA' '.env nao ignorado' '.env existe no disco e NAO esta coberto pelo .gitignore'
    }
}

# =============================================================================
# 4. staging area
# =============================================================================
$staged = @(Invoke-GitCaminhos @('-C', $Path, 'diff', '--cached', '--name-only', '-z'))
foreach ($f in $staged) {
    if ($f -match $reNome) { Add-Achado 'ALTA' 'arquivo sensivel na staging area' $f 'staging' $f }
}

# =============================================================================
# 5. documento operacional rastreado
# =============================================================================
foreach ($f in $todos) {
    if ($f -match '\.(xlsx|xlsm|xlsb|docx|doc|pptx|pdf|pbix)$') {
        Add-Achado 'MEDIA' 'documento operacional' $f 'working tree' $f
    }
}

# =============================================================================
# 6-9. os quatro detectores da subfase 2.3
# =============================================================================
$rGitignore = Get-AchadosGitignore -Path $Path
$achados += $rGitignore.Achados

$rPessoal = Get-AchadosDadoPessoal -Path $Path
$achados += $rPessoal.Achados

$rExpo = Get-AchadosExposicao -Path $Path -SemRede:$SemRede
$achados += $rExpo.Achados

$rHist = $null
if (-not $SemHistorico) {
    # As chaves do detector de dado pessoal entram junto com as de credencial.
    # Sem isto a deduplicacao existe so para credencial, e o mesmo e-mail
    # aparece duas vezes - uma como working tree, outra como historico -
    # sugerindo exposicao exclusiva no historico, que tem remediacao
    # destrutiva e diferente.
    $chavesTodas = @($chavesWT + $rPessoal.Chaves)
    $rHist = Get-AchadosHistorico -Path $Path -MaxBlobKB $MaxBlobKB -MaxBlobs $MaxBlobs `
                                  -ChavesDoWorkingTree $chavesTodas
    $achados += $rHist.Achados
}

# =============================================================================
# relatorio
# =============================================================================
# =============================================================================
# disposicao: quais achados estao cobertos por excecao APROVADA
# =============================================================================
# Aplicada aqui, num lugar so, depois de TODOS os detectores. Nenhum detector
# conhece excecao - eles so acham. Isso mantem cada detector testavel em
# isolamento e concentra a regra de aceitacao num ponto auditavel.
$rExc = Get-ExcecoesDeSeguranca -Path $Path
$rDisp = Set-DisposicaoDosAchados -Achados $achados -Aceitas $rExc.Aceitas -ParaPublicacao:$ParaPublicacao

# Duas contagens da MESMA coisa por caminhos diferentes: o contador do
# portao, e a lista que a tabela de aceitos renderiza. Se divergirem, uma
# das duas esta errada - e o modo de falha ruim e "o portao desarmou N e a
# tabela mostra zero", em que o achado desarmado sumiria do relatorio.
#
# Calculado AQUI, e nao la embaixo, por achado do security-reviewer: na
# secao de aceitos a comparacao ficava dentro do ramo alcancavel so quando
# a tabela JA tinha linha - cega no caso perigoso - e tarde demais para
# entrar no acumulador de lacunas. A guarda se dizia "lacuna" e nao
# aparecia onde o protocolo manda procurar lacuna.
$aceitosDoPortao = @($achados | Where-Object { $_.Disposicao -eq (Get-DisposicaoAceita) })
# COSTURA DE TESTE, declarada na linha de modificadores do relatorio,
# como a do gh. Hoje os dois numeros sao a mesma medicao lida duas vezes
# e nao podem divergir - o security-reviewer provou isso lendo o fluxo.
# Sem a costura, a guarda so poderia ser verificada por leitura, e este
# repositorio ja aprendeu o que isso vale.
# A costura perturba um OPERANDO, nao o resultado. Na primeira versao ela
# ficava a esquerda de um -or, entao com a costura ligada a comparacao
# nunca era avaliada: trocar o predicado inteiro por $false sobrevivia
# verde nos dois casos. Achado do qa-reviewer. Assim a comparacao REAL
# roda nos dois caminhos, e o que a costura muda e so a entrada dela.
$desvioForcado = 0
if ($env:OS_SCAN_FORCAR_DIVERGENCIA) { $desvioForcado = 1 }
$divergenciaDeExcecao = ($rDisp.Cobertos -ne ($aceitosDoPortao.Count + $desvioForcado))


$agora = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
# Guardado por Test-HeadResolvivel, nao por '2>$null': em repositorio sem nenhum
# commit o 'rev-parse --short HEAD' escreve "fatal: Needed a single revision"
# em stderr, e no PowerShell 5.1 stderr de executavel nativo vira ErrorRecord
# terminante sob ErrorActionPreference=Stop - o trap pegava e o script saia
# com 2 sem gravar relatorio. Este e o fluxo normal do /os:new-project, que
# roda 'git init' e para. Defeito herdado da versao 2.2, achado pelo teste de
# repositorio sem commit que so existe agora.
$commit = '(sem commits)'
# Test-HeadResolvivel, nao Test-TemHistorico: o que vem a seguir e
# 'rev-parse --short HEAD', que precisa de um HEAD que resolva. Num
# repositorio com historico buscado e HEAD nao nascido, perguntar pelo
# historico daria verdadeiro e o rev-parse lancaria.
if (Test-HeadResolvivel $Path) { $commit = (Invoke-Git @('-C', $Path, 'rev-parse', '--short', 'HEAD')) }

$sb = New-Object System.Text.StringBuilder
function W { param([string]$t = '') ; $null = $sb.AppendLine($t) }

$altas  = @($achados | Where-Object { $_.Severidade -eq 'ALTA' }).Count
$medias = @($achados | Where-Object { $_.Severidade -eq 'MEDIA' }).Count
$baixas = @($achados | Where-Object { $_.Severidade -eq 'BAIXA' }).Count

W "# Relatorio de varredura de seguranca"
W ""
W "- Gerado em: $agora"
W "- Repositorio: ``$Path``"
W "- HEAD: ``$commit``"
# Numero de subfase literal envelhece: os relatorios que embasaram a revisao
# da 2.4 se declaravam "subfase 2.3", e quem lesse depois nao teria como saber
# se a camada Invoke-Git estava em vigor na coleta. Achado do security-reviewer.
# O que identifica a versao do scanner sem envelhecer e o proprio codigo: as
# libs carregadas e o tamanho de cada uma. O carimbo de integridade cobre os
# arquivos varridos; esta linha cobre o VARREDOR.
#
# TRES defeitos nesta linha na primeira tentativa, todos achados pelo
# security-reviewer, e o conjunto e instrutivo: o relatorio saiu dizendo
# "(1 linhas) + 0 detectores" - ou seja, um mecanismo de PROVENIENCIA que
# nunca funcionou, num relatorio cuja premissa e declarar a propria
# cobertura. E "0 detectores" contradizia a linha seguinte, que declarava as
# seis areas cobertas.
#   1. 'Join-Path $PSScriptRoot ("lib" + $nome)' sem separador produzia
#      'scripts\libscan-comum.ps1', que nao existe: Test-Path falso para os
#      seis, lista vazia. O carregador acima faz certo; esta linha duplicou o
#      join e errou.
#   2. Measure-Linhas recebe CONTEUDO, nao caminho (o parametro se chama
#      $Texto). Passar caminho devolvia 1, porque caminho nao tem '\n'.
#   3. O mesmo erro de caminho-vs-conteudo em cada detector.
# Agora ha um caso de teste que LE a linha do relatorio gerado e exige a
# contagem real e os seis detectores nomeados.
$assinaturaLibs = @()
foreach ($nomeLib in ($LIBS | Sort-Object)) {
    $cLib = Join-Path $lib $nomeLib
    if (Test-Path $cLib -PathType Leaf) {
        $assinaturaLibs += ('{0}:{1}' -f ($nomeLib -replace '^scan-|\.ps1$', ''),
                            (Measure-LinhasDoArquivo $cLib))
    }
}
W ("- Gerador: ``scripts/security-scan.ps1`` (" + (Measure-LinhasDoArquivo $PSCommandPath) +
   " linhas) + " + $assinaturaLibs.Count + " detectores: " + ($assinaturaLibs -join ', '))
$mods = @()
if ($SemHistorico) { $mods += '`-SemHistorico`' }
if ($SemRede)      { $mods += '`-SemRede`' }
# A costura de teste tambem e um modificador de cobertura, e tem de aparecer.
# Uma variavel exportada e esquecida na sessao faria o relatorio afirmar
# PRIVATE com resposta fabricada, e a area continuaria "coberta" - costura
# ativa e nao declarada e cobertura reduzida em silencio, o mesmo defeito que
# esta subfase corrigiu no detector de visibilidade. Achado do
# security-reviewer.
if ($env:OS_SCAN_GH) { $mods += ('`$env:OS_SCAN_GH` **ATIVA** (' + $env:OS_SCAN_GH + ') - a visibilidade do remoto NAO veio da API real') }
if ($env:OS_SCAN_FORCAR_DIVERGENCIA) { $mods += '`$env:OS_SCAN_FORCAR_DIVERGENCIA` **ATIVA** - a divergencia entre o contador do portao e a lista de aceitos foi FORCADA para exercitar a guarda; ela NAO indica defeito nesta execucao' }
if ($ParaPublicacao) { $mods += '`-ParaPublicacao` **toda excecao aprovada foi IGNORADA**: publicacao exige sanitizacao' }
# 'cobertura cheia' era afirmacao de COBERTURA numa linha que mede
# MODIFICADOR, e ela aparece ANTES da tabela de cobertura por area. Com duas
# areas em '**parcial**' logo abaixo, quem parasse aqui levava a frase errada
# para o veredito. Achado do security-reviewer.
if ($mods.Count -eq 0) { $mods = @('nenhum - a cobertura REAL esta na tabela "Cobertura por area", abaixo') }
W ("- Modificadores desta execucao: " + ($mods -join ' | '))
W "- Limites: ``-MaxBlobKB $MaxBlobKB``, ``-MaxBlobs $MaxBlobs``"
W ""
W "> Este relatorio contem FATOS, nao veredito. Quem julga e o"
W "> ``security-reviewer``, que le este arquivo."
W ""
W "**Leia a secao _Cobertura por area_ antes dos achados.** Achado lido"
W "primeiro cria a impressao de que o escopo era completo (politica 4.5)."
W ""
W "### Como ler a severidade (ADR-0009)"
W ""
W "| Severidade | Significa | Trava |"
W "|---|---|---|"
W "| **ALTA** | Algo indevido esta exposto, ou entraria num commit agora | sim |"
W "| **MEDIA** | Algo questionavel esta presente e exige decisao de uma pessoa | sim |"
W "| **BAIXA** | Fato para contestar: guarda-corpo ausente, fixture declarada, identidade do proprio autor | nao |"
W ""
W "A severidade diz **o que o achado e**. Quem decide se ele trava e a"
W "**disposicao**: achado ALTA ou MEDIA coberto por excecao aprovada mantem a"
W "severidade, aparece em secao propria com a excecao citada, e nao bloqueia o"
W "fluxo privado autorizado (ADR-0010). Sob ``-ParaPublicacao`` nenhuma excecao"
W "vale."
W ""

# --- cobertura por area --------------------------------------------------------
W "## Carimbo de integridade desta varredura"
W ""
W "Tamanho de cada arquivo de texto examinado, **no momento da varredura**. Se"
W "o que voce ler no disco tiver outra contagem de linhas, esta varredura esta"
W "obsoleta e o veredito nao se aplica ao codigo atual: peca varredura nova."
W ""
W "O ``HEAD`` acima nao ancora isto. A varredura olha o **working tree**, e a"
W "maior parte do que ela examina pode nao estar commitada - foi a ressalva do"
W "``security-reviewer``, que conseguia casar a evidencia com o commit e nao"
W "com o disco."
W ""
W ("**" + (Get-NotaDaConvencaoDeLinhas) + "** O ``collect-diff.ps1`` usa a mesma convencao: se os dois relatorios discordarem, isso e defeito de ferramenta, nao deriva de arquivo.")
W ""
W "| Arquivo | bytes | linhas |"
W "|---|---|---|"
foreach ($c in ($carimbo | Sort-Object Nome)) {
    W "| ``$($c.Nome)`` | $($c.Bytes) | $($c.Linhas) |"
}
W ""
W "## Cobertura por area"
W ""
W "As seis areas sao as mesmas sobre as quais o ``security-reviewer`` emite"
W "veredito parcial. Area com lacuna nao pode receber ``APROVADO``."
W ""
W "| Area | Coberta | Como, e com que volume |"
W "|---|---|---|"
# A coluna "Coberta" tem de refletir lacuna contingente, como as linhas de
# 'historico' e 'exposicao externa' ja faziam. Ela dizia 'sim' incondicional
# para 'working tree' e 'dado de terceiro' enquanto a secao de lacunas da
# mesma execucao declarava arquivos sem conteudo lido - dois sinais
# contraditorios no mesmo documento, e a tabela e o que se le primeiro.
# Achado do qa-reviewer.
# QUARTA aparicao do mesmo padrao, e o security-reviewer contou: a correcao
# anterior pos $ausentesDoDisco no acumulador que decide "(nenhuma)" e esqueceu
# ESTE portao, que consome o mesmo fato. A tabela abre dizendo "Area com lacuna
# nao pode receber APROVADO" e se desmentia 30 linhas depois, em 3 de 6 areas -
# e o protocolo manda ler esta tabela PRIMEIRO e trata-la como autoritativa.
#
# REGRA, e ela vale para as duas pontas: fato que emite linha na tabela de
# lacunas entra no acumulador do "(nenhuma)" E na coluna "Coberta" desta
# tabela. Sao dois portoes que consomem o mesmo fato; consertar um deixa o
# outro mentindo.
$cobWT = 'sim'
if ($ignoradosPorTipo -gt 0 -or $ausentesDoDisco -gt 0 -or $naoLidosPorCodificacao -gt 0) { $cobWT = '**parcial**' }
W "| working tree | $cobWT | nome sensivel e 8 padroes de credencial em $examinados arquivo(s) de texto, rastreado(s) e nao rastreado(s); $ignoradosPorTipo sem extensao de texto nao lido(s), $naoLidosPorCodificacao com extensao de texto mas ILEGIVEL como texto |"
if ($SemHistorico) {
    W "| historico | **NAO** | ``-SemHistorico`` foi usado nesta execucao |"
} elseif ($rHist.Cobertura.SemCommits) {
    W "| historico | sim (vazio) | repositorio sem nenhum commit: nao existe historico a varrer |"
} else {
    $c = $rHist.Cobertura
    $cobHist = 'sim'
    if ($c.BlobsNaoTexto -gt 0 -or $c.BlobsGrandes -gt 0 -or $c.BlobsAcimaDoCap -gt 0 -or $c.BlobsSemConteudo -gt 0 -or
        $c.BlobsIlegiveis -gt 0) {
        $cobHist = '**parcial**'
    }
    W "| historico | $cobHist | $($c.Commits) commit(s), $($c.ObjetosTotais) objeto(s), $($c.CaminhosUnicos) caminho(s) unico(s); $($c.BlobsLidos) de $($c.BlobsCandidatos) blob(s) de texto lidos, $($c.BlobsNaoTexto) blob(s) sem extensao de texto nao lidos, $($c.BlobsIlegiveis) ILEGIVEL(eis) como texto; $($c.Coincidencias) ocorrencia(s) suprimida(s) por coincidir com achado do working tree - contadas por blob x caminho x categoria, entao este numero e MAIOR que o de fatos distintos e nao reconcilia com a contagem de linhas de achado |"
}
W "| staging | sim | nome sensivel entre os $($staged.Count) arquivo(s) em staging |"
$g = $rGitignore.Cobertura
# Negacao que reabre diretorio: as sondas de nome canonico nao entram na
# subarvore liberada, entao a razao "N de N nomes canonicos cobertos" vale
# para a arvore FORA dela. A ressalva existia so no backlog do STATE.md, e
# o security-reviewer aplicou contra ela a regra que esta subfase escreveu:
# lacuna declarada so em conversa nao e lacuna declarada. Agora sai na
# tabela de lacunas DESTA execucao, que e o que o revisor le.
$negacoesQueAbremSubarvore = $g.NegacoesQueAbremSubarvore
$listaNegacoes = (($g.ListaNegacoes | ForEach-Object { '`' + $_ + '`' }) -join ', ')
if (-not $listaNegacoes) { $listaNegacoes = '(nenhuma listada)' }
$cobGi = 'sim'
# NegacoesQueAbremSubarvore tem de estar AQUI tambem. Ele nasceu na rodada 9
# emitindo linha de lacuna, entrou no acumulador do "(nenhuma)" na 12, e
# ficou fora deste portao ate a 13 - a SEXTA aparicao da classe que o
# comentario 30 linhas acima documenta, desta vez contra o proprio contrato
# que ele escreve.
#
# O cenario que o qa-reviewer derivou nao dispara neste repositorio, e e por
# isso que passou verde: aqui o .gitignore do template ja tem classe de
# caractere e "**", que forcam parcial por outro motivo. Num projeto
# governado com ".gitignore" simples - "/output/*" mais "!/output/" -
# nenhuma outra lacuna dispara, e a celula sairia "sim" com a lacuna de
# negacao logo abaixo dizendo que a razao de nomes canonicos nao vale.
# Falsa garantia na tabela que o protocolo manda ler PRIMEIRO.
if ($g.NaoVerificaveis -gt 0 -or $g.PorMembroDeClasse -gt 0 -or $g.VerificadasEmConjunto -gt 0 -or
    $g.ArquivosDeRegraAusentes -gt 0 -or $g.NegacoesQueAbremSubarvore -gt 0 -or
    $g.ArquivosDeRegraNaoLidos -gt 0) {
    $cobGi = '**parcial**'
}
W "| gitignore | $cobGi | $($g.RegrasEfetivas) de $($g.RegrasVerificadas) regra(s) provadas EFETIVAS; $($g.RegrasVerificadas) de $($g.RegrasTotais) regra(s) sondadas com ``git check-ignore``, em $($g.ArquivosDeRegra) arquivo(s) de regra listado(s) - $($g.PorMembroDeClasse) por um membro de classe de caractere, $($g.VerificadasEmConjunto) em conjunto com regra irma de negacao; e $($g.AlvosCobertos) de $($g.AlvosCanonicos) nome(s) de segredo canonico cobertos, contando cada diretorio com ``.gitignore`` proprio; $($g.ArquivosDeRegraNaoLidos) arquivo(s) de regra ILEGIVEL(eis) como texto |"
$dp = $rPessoal.Cobertura
$cobDP = 'sim'
if ($dp.SemExtensaoDeTexto -gt 0 -or $dp.AusentesDoDisco -gt 0 -or $dp.NaoLidosPorCodificacao -gt 0) { $cobDP = '**parcial**' }
W "| dado de terceiro | $cobDP | CPF e CNPJ com digito verificador, telefone e CEP pontuados, e-mail classificado contra $($dp.Identidades) identidade(s) do historico; $($dp.Examinados) arquivo(s) examinado(s), $($dp.SemExtensaoDeTexto) sem extensao de texto nao lido(s), $($dp.AusentesDoDisco) rastreado(s) e ausente(s) do disco, $($dp.NaoLidosPorCodificacao) ILEGIVEL(eis) como texto |"
$ex = $rExpo.Cobertura
$visTxt = 'nenhum remoto'
if ($ex.Remotos -gt 0) {
    if ($ex.VisibilidadeVerificada.Count -gt 0) { $visTxt = ($ex.VisibilidadeVerificada -join '; ') }
    else { $visTxt = 'visibilidade NAO consultada' }
}
$cobEx = 'sim'
if ($ex.VisibilidadeSemResposta.Count -gt 0 -or $ex.SemExtensaoDeTexto -gt 0 -or $ex.AusentesDoDisco -gt 0 -or
    $ex.NaoLidosPorCodificacao -gt 0) { $cobEx = '**parcial**' }
# GhDisponivel e ArquivosDeCIAusentes eram CAMPOS SEM LEITOR - contadores que
# subiam e nunca chegavam ao relatorio. O guarda-corpo novo de
# tests/suites/scripts.ps1 os encontrou; o qa-reviewer tinha achado o segundo
# a mao, na rodada anterior. Contador que ninguem le nao corrige nada, e o
# comentario ao lado dele afirmava que corrigia.
# Tres campos que nasceram sem leitor - GhDisponivel, RegrasEfetivas e
# RedeConsultada. Os dois primeiros o guarda-corpo novo achou; o terceiro
# escapava do regex por ter inicializador de expressao, e o qa-reviewer achou
# a mao DEPOIS de os dois primeiros terem sido corrigidos. Contador que sobe e
# nao chega ao relatorio nao corrige nada.
$ghTxt = if ($ex.GhDisponivel) { 'gh disponivel' } else { '**gh NAO disponivel** - a visibilidade do remoto nao pode ser consultada por API' }
if (-not $ex.RedeConsultada) { $ghTxt = '**rede NAO consultada** (`-SemRede`) - a visibilidade do remoto nao foi verificada nesta execucao' }
W "| exposicao externa | $cobEx | $($ex.Remotos) remoto(s) ($visTxt; $ghTxt), 8 padroes de webhook/endpoint em $($ex.ArquivosExaminados) arquivo(s), $($ex.SemExtensaoDeTexto) sem extensao de texto nao lido(s), $($ex.AusentesDoDisco) rastreado(s) e ausente(s) do disco, $($ex.ArquivosDeCI) arquivo(s) de CI lido(s) e $($ex.ArquivosDeCIAusentes) ausente(s) do disco, $($ex.NaoLidosPorCodificacao) ILEGIVEL(eis) como texto |"
W ""

# --- escopo nao varrido -------------------------------------------------------
W "## Escopo NAO VARRIDO"
W ""
W "Duas naturezas, e confundi-las torna a regra inutil."
W ""
W "**A distincao existe porque o ``security-reviewer`` teve de divergir da"
W "instrucao anterior deste relatorio para nao errar.** Ela mandava derrubar"
W "para ``INCONCLUSIVO`` toda area com qualquer linha aqui - aplicada ao pe da"
W "letra, deixaria ``working tree`` inconclusivo **para sempre**, porque"
W 'segredo sem formato reconhecivel nunca vai ser varrido por scanner de'
W "padrao. Regra que nunca pode ser satisfeita nao e rigor, e ruido."
W ""
W "### Lacunas DESTA execucao"
W ""
W "Contingentes: dependem de como o scanner foi chamado ou do que ele"
W "encontrou. **Cada linha aqui e ausencia de evidencia, nao aprovacao**, e"
W "derruba a area correspondente para ``INCONCLUSIVO`` - a menos que quem"
W "revisa a feche por inspecao propria, e nesse caso ele diz que fechou e como."
W ""
W "| O que NAO foi varrido | Consequencia para o veredito |"
W "|---|---|"
if ($SemHistorico) {
    W "| **Historico do Git** - ``-SemHistorico`` nesta execucao | Segredo commitado e depois apagado do working tree **nao apareceria aqui**. Area ``historico``: ``INCONCLUSIVO`` |"
}
if ($ignoradosPorTipo -gt 0) {
    W "| Conteudo de arquivo sem extensao de texto | $ignoradosPorTipo arquivo(s) do working tree nao tiveram o conteudo lido |"
}
if ($ausentesDoDisco -gt 0) {
    # Sem esta linha o balanco nao fechava e ninguem sabia: rastreados + nao
    # rastreados dava 85 unicos, o relatorio dizia 0 nao lidos por tipo, e
    # examinava 84. O security-reviewer somou e nao achou o que faltava.
    $quais = ($listaAusentes -join ', ')
    if ($ausentesDoDisco -gt $listaAusentes.Count) { $quais += (', e mais ' + ($ausentesDoDisco - $listaAusentes.Count)) }
    W "| Conteudo de $ausentesDoDisco arquivo(s) RASTREADO(S) e ausente(s) do disco | ``$quais`` - o Git lista, o disco nao tem: deletado sem ``git add``, tipicamente. Nenhuma das tres areas que leem conteudo do working tree leu esses arquivos. O blob segue alcancavel pelo ``historico``, mas **so para padrao de CREDENCIAL e de dado pessoal**: o detector de historico nao aplica os padroes de EXPOSICAO (webhook, endpoint, credencial em URL). Arquivo rastreado com webhook, apagado do disco sem ``git add``, nao e lido por area nenhuma - foi achado do ``qa-reviewer``, e a versao anterior desta linha afirmava o contrario |"
}
if ($rHist -and $rHist.Cobertura.BlobsIlegiveis -gt 0) {
    # Area separada, lista separada: o detector de historico nao le por
    # caminho de arquivo, le stdout do git, e por isso ficou de fora da
    # primeira passada da correcao do item 11. Enquanto ele nao tinha
    # contador, o mesmo arquivo que o working tree RECUSAVA e nomeava era
    # contado como 'lido' aqui - duas areas relatando o oposto sobre os
    # mesmos bytes. Achado do security-reviewer.
    $quaisBl = ($rHist.Cobertura.ListaBlobsIlegiveis -join ', ')
    if ($rHist.Cobertura.BlobsIlegiveis -gt $rHist.Cobertura.ListaBlobsIlegiveis.Count) {
        $quaisBl += (', e mais ' + ($rHist.Cobertura.BlobsIlegiveis - $rHist.Cobertura.ListaBlobsIlegiveis.Count))
    }
    W "| Conteudo de $($rHist.Cobertura.BlobsIlegiveis) blob(s) ILEGIVEL(eis) como texto | ``$quaisBl`` - bytes invalidos para UTF-8 (decodificacao ESTRITA sobre os bytes do ``git cat-file``) ou NUL no conteudo. Nenhum padrao de credencial nem de dado pessoal foi aplicado a esses blobs. O sha e o caminho estao acima para quem quiser conferir com ``git cat-file`` |"
}
if ($naoLidosPorCodificacao -gt 0 -or $g.ArquivosDeRegraNaoLidos -gt 0) {
    # UMA linha para as quatro areas: o conjunto de arquivos e o mesmo
    # ('ls-files' mais nao rastreados), entao repetir a lista por area seria
    # ruido. O que muda por area e o contador, e ele ja esta na tabela de
    # cobertura acima.
    $quaisNL = ($listaNaoLidos -join ', ')
    if ($naoLidosPorCodificacao -gt $listaNaoLidos.Count) { $quaisNL += (', e mais ' + ($naoLidosPorCodificacao - $listaNaoLidos.Count)) }
    if (-not $quaisNL) { $quaisNL = '(nenhum no working tree)' }
    $quaisGiNL = ($g.ListaArquivosNaoLidos -join ', ')
    if (-not $quaisGiNL) { $quaisGiNL = 'nenhum' }
    W "| Conteudo de $naoLidosPorCodificacao arquivo(s) ILEGIVEL(eis) como texto | ``$quaisNL`` - extensao de texto, mas o conteudo nao decodifica como UTF-8 (salvo em ANSI, tipicamente) ou tem NUL (UTF-16 sem BOM, que e UTF-8 valido byte a byte e por isso escapava da leitura estrita). **Nenhuma** das areas que leem conteudo do working tree varreu esses arquivos: credencial, dado pessoal e webhook dentro deles nao apareceriam em achado nenhum. Arquivos de regra ``.gitignore`` ilegiveis: ``$quaisGiNL`` |"
}
if ($g.NaoVerificaveis -gt 0) {
    W "| $($g.NaoVerificaveis) regra(s) de ``.gitignore`` que a sonda nao representa | Regra com ``**``, classe de caractere, ``?`` ou sonda ambigua. Listadas no fim deste relatorio |"
}
# As duas linhas abaixo imprimiam CONTAGEM sem IDENTIDADE - o mesmo defeito
# que o F6 corrigiu para o blob vazio, intacto uma area ao lado. Consequencia
# medida pelo security-reviewer: ele fechou 'historico' por identidade do sha e
# NAO conseguiu fechar 'gitignore', porque nao sabia quais regras sondar no
# disco. Area que ele nao fecha vira INCONCLUSIVO, e INCONCLUSIVO bloqueia.
if ($g.PorMembroDeClasse -gt 0) {
    $quaisClasse = ($g.ListaPorMembroDeClasse -join '; ')
    W "| Classe de caractere completa em $($g.PorMembroDeClasse) regra(s) de ``.gitignore`` | ``$quaisClasse`` - a sonda usou **um** membro da classe. A regra esta provada para aquele membro, nao para a classe inteira. Com ``arquivo:linha`` acima, quem revisa confere no disco quais membros ficaram de fora |"
}
if ($g.ArquivosDeRegraAusentes -gt 0) {
    $quaisGi = ($g.ListaArquivosAusentes -join ', ')
    W "| $($g.ArquivosDeRegraAusentes) arquivo(s) ``.gitignore`` que o Git lista e o disco NAO tem | ``$quaisGi`` - as regras deles nao entraram na contagem, entao a razao ``N de N`` acima e sobre o que SOBROU. Um ``.gitignore`` ausente do disco tambem nao e aplicado pelo Git, mas a protecao que ele descreve deixou de existir e ninguem verificou o que ficou descoberto |"
}
if ($g.VerificadasEmConjunto -gt 0) {
    $quaisConjunto = ($g.ListaVerificadasEmConjunto -join '; ')
    W "| Atribuicao individual de $($g.VerificadasEmConjunto) regra(s) de ``.gitignore`` que compartilham sonda | ``$quaisConjunto`` - sao negacoes irmas (o par que o Git exige para liberar diretorio e conteudo). O RESULTADO foi verificado; qual das duas decidiu, nao |"
}
if ($rHist -and $rHist.Cobertura.BlobsSemConteudo -gt 0) {
    $quaisBlobs = ($rHist.Cobertura.ListaSemConteudo -join '; ')
    if ($rHist.Cobertura.BlobsSemConteudo -gt $rHist.Cobertura.ListaSemConteudo.Count) {
        $quaisBlobs += ('; e mais ' + ($rHist.Cobertura.BlobsSemConteudo - $rHist.Cobertura.ListaSemConteudo.Count))
    }
    W "| $($rHist.Cobertura.BlobsSemConteudo) blob(s) do historico que o ``cat-file`` devolveu vazio | ``$quaisBlobs`` - nao lidos, e **nao da para distinguir daqui** blob vazio de falha de leitura ou de conteudo ``0``. Com o sha e o caminho acima, quem revisa fecha por IDENTIDADE (conferir se aquele caminho e mesmo um marcador vazio) em vez de por aritmetica. Enquanto nao fechar, a area ``historico`` fica ``INCONCLUSIVO`` |"
}
if ($rHist -and $rHist.Cobertura.BlobsNaoTexto -gt 0) {
    W "| Conteudo de $($rHist.Cobertura.BlobsNaoTexto) blob(s) do historico sem extensao de texto | Nao lidos. A checagem por **nome** cobre todos os caminhos do historico independentemente disso |"
}
if ($rHist -and $rHist.Cobertura.BlobsGrandes -gt 0) {
    W "| $($rHist.Cobertura.BlobsGrandes) blob(s) do historico acima de $MaxBlobKB KB | Nao lidos por limite de tamanho |"
}
if ($rHist -and $rHist.Cobertura.BlobsAcimaDoCap -gt 0) {
    W "| $($rHist.Cobertura.BlobsAcimaDoCap) blob(s) do historico acima do limite de $MaxBlobs | Nao lidos por limite de quantidade |"
}
foreach ($v in $ex.VisibilidadeSemResposta) {
    W "| Visibilidade do remoto: $v | Area ``exposicao externa``: nao da para afirmar que o remoto e privado |"
}
if (-not $destinoDentroDoRepo) {
    if ($destinoRedirecionado) {
        # Item 157: o redirecionamento automatico tem de aparecer no proprio
        # relatorio, nao so no console - quem le o arquivo depois nao viu o
        # aviso, e precisa saber que 'artifacts/' segue NAO ignorado no alvo.
        W "| Se o destino deste relatorio esta ignorado | O destino padrao ``artifacts/review/`` **NAO esta ignorado** no repositorio-alvo, entao o relatorio foi gravado FORA do repositorio-alvo, em ``$Out``, para nao sujar o working tree dele (item 157). A pergunta nao se aplica a este arquivo; para manter o relatorio junto do projeto, ignore ``artifacts/`` no ``.gitignore`` do alvo |"
    } else {
        W "| Se o destino deste relatorio esta ignorado | O relatorio foi gravado FORA do repositorio-alvo (``-Out``), entao a pergunta nao se aplica |"
    }
}
# Com a costura ligada, o par CRU sai SEMPRE - fora do predicado. Sem isto
# havia um caso cego: divergencia real de exatamente +1 fazia a comparacao
# dar falso e nenhuma linha era emitida, justamente no caso N=1 do modo de
# falha que a guarda existe para pegar. Achado do security-reviewer, com o
# conserto dele: quem le subtrai sozinho.
if ($desvioForcado -ne 0) {
    W "| Contadores de excecao, valores crus | Com a costura ligada o predicado nao e confiavel: o portao contou $($rDisp.Cobertos) e a lista de aceitos tem $($aceitosDoPortao.Count), antes do desvio de +$($desvioForcado). Compare os dois voce mesmo |"
}
if ($divergenciaDeExcecao) {
    W "| Quantos achados a excecao desarmou | **Divergencia interna:** o portao contou $($rDisp.Cobertos) e a lista de aceitos tem $($aceitosDoPortao.Count). Os dois medem a mesma coisa; um deles esta errado. NAO trate o numero da secao de aceitos como confiavel nesta execucao |"
}
if ($negacoesQueAbremSubarvore -gt 0) {
    W "| Nome canonico de segredo DENTRO de subarvore liberada por negacao | $($negacoesQueAbremSubarvore) regra(s) de negacao (``!``) reabrem diretorio, e as sondas canonicas NAO perguntam por caminho dentro delas: $listaNegacoes. A razao de nomes canonicos cobertos vale para a arvore FORA dessas subarvores |"
}
# TODA linha emitida na tabela acima tem de entrar neste acumulador, porque e
# ele que decide imprimir "(nenhuma)".
#
# Duas linhas ficaram de fora e o security-reviewer achou: a de arquivo
# rastreado ausente do disco - que ESTA correcao acrescentou na rodada
# anterior - e a de blob sem conteudo, da 2.3. Numa execucao cuja unica lacuna
# fosse uma dessas duas, a MESMA tabela imprimia a lacuna E imprimia
# "(nenhuma) - nenhuma area cai para INCONCLUSIVO". Declaracao de cobertura
# que se autocontradiz, na secao que o protocolo manda ler PRIMEIRO e tratar
# como autoritativa.
#
# O padrao de fundo, que ele nomeou e vale mais que o conserto: a correcao
# acrescentou a LINHA e esqueceu o CONTADOR, e o teste novo mediu a linha e
# nao o contador. Terceira vez nesta plataforma que o conserto cobre o sintoma
# declarado e deixa o portao a jusante. Quem acrescentar linha aqui: acrescente
# no acumulador, e escreva o caso que exige a AUSENCIA de "(nenhuma)".
$lacunasContingentes = @($SemHistorico) + @($ignoradosPorTipo -gt 0) + @($g.NaoVerificaveis -gt 0) +
                       @($g.PorMembroDeClasse -gt 0) + @($g.VerificadasEmConjunto -gt 0) +
                       @($ex.VisibilidadeSemResposta.Count -gt 0) + @(-not $destinoDentroDoRepo) +
                       @($ausentesDoDisco -gt 0) + @($g.ArquivosDeRegraAusentes -gt 0) +
                       @($divergenciaDeExcecao) + @($negacoesQueAbremSubarvore -gt 0) +
                       @($naoLidosPorCodificacao -gt 0) + @($g.ArquivosDeRegraNaoLidos -gt 0) +
                       @($desvioForcado -ne 0)
if ($rHist) {
    $lacunasContingentes += @($rHist.Cobertura.BlobsNaoTexto -gt 0) + @($rHist.Cobertura.BlobsGrandes -gt 0) +
                            @($rHist.Cobertura.BlobsAcimaDoCap -gt 0) + @($rHist.Cobertura.BlobsSemConteudo -gt 0) +
                            @($rHist.Cobertura.BlobsIlegiveis -gt 0)
}
if (@($lacunasContingentes | Where-Object { $_ }).Count -eq 0) {
    W "| (nenhuma) | Esta execucao nao tem lacuna contingente. Nenhuma area cai para ``INCONCLUSIVO`` por causa desta secao |"
}
W ""
W "### Teto permanente da ferramenta"
W ""
W "Nao sao lacunas desta execucao: sao coisas que **nenhuma execucao** deste"
W "scanner cobre, por natureza. Elas **nao** derrubam area para"
W "``INCONCLUSIVO`` - do contrario nenhuma area jamais poderia ser aprovada."
W ""
# Aspas simples: em PowerShell '\' NAO e escape, entao '\"' fecha a string de
# aspas duplas e o resto da frase e descartado em silencio. Ja aconteceu tres
# vezes nesta plataforma, e esta versao chegou a gravar '**\' no relatorio.
W 'O que elas fazem e definir o que `APROVADO` significa aqui: **"nenhum'
W 'padrao detectavel, e eu li os arquivos apontados"**, e nao "limpo em'
W 'sentido absoluto".'
W ""
W "| Fora do alcance, sempre | Camada complementar |"
W "|---|---|"
W "| Segredo sem formato reconhecivel - senha curta, token sem prefixo conhecido | Revisao humana; rotacao periodica de credencial |"
W "| Objeto do Git nao alcancavel por ref - commit pendurado apos ``commit --amend`` ou ``reset --hard`` | ``rev-list --all`` alcanca so o que alguma ref aponta. Objeto inalcancavel nao vai para o remoto, mas segue no disco local ate o ``gc``. Camada complementar: ``git reflog expire --expire=now --all`` seguido de ``git gc --prune=now`` |"
W "| Dado pessoal sem formato - nome de pessoa, matricula, cargo | Revisao humana antes de tornar publico |"
# String de ASPAS SIMPLES, e o motivo esta 12 linhas acima: aspa dupla nao
# escapada dentro de string de aspas duplas FECHA a string e o resto e
# descartado em silencio. Esta linha foi a QUARTA aparicao da armadilha, e a
# pior - ela caiu justamente na frase que documenta um achado do
# security-reviewer, e o caso de regressao que eu escrevi para ela afirmava
# duas frases que ficavam ANTES do ponto de corte: verde sobre relatorio
# corrompido. Os dois revisores acharam.
W '| **Marcador de fixture atravessa a fronteira de publicacao** | `SEGREDO-FABRICADO-PARA-TESTE` declarado nas 40 primeiras linhas de um arquivo rebaixa `ALTA` para `BAIXA` por AUTODECLARACAO - sem exigir caminho, categoria, justificativa nem decisao registrada -, e o rebaixamento acontece DENTRO dos detectores, antes do portao de disposicao, que e o unico ponto onde ``-ParaPublicacao`` age. Consequencia: e a unica rota de rebaixamento que NAO e anulada na publicacao, ao contrario do mecanismo de excecao (ADR-0010), que recusa `ALTA` e cai sob ``-ParaPublicacao``. Levantado pelo security-reviewer em tres rodadas; estreita-lo e decisao da mantenedora, declara-lo nao - backlog item 9 |'
W '| **Arquivo de texto com codificacao que decodifica sem erro e nao e a certa** | Os leitores RECUSAM byte invalido para UTF-8 e conteudo com NUL, e o recusado sai como lacuna nomeada em vez de "examinado" (backlog item 11). O preambulo e decidido pelo proprio leitor, e nao pelo StreamReader - com deteccao automatica, BOM de UTF-8 DESARMAVA a recusa de byte invalido. O que sobra: texto de byte unico - Windows-1252, Latin-1 - cujos bytes por acaso formem sequencia UTF-8 valida. E lido, decodifica para caracteres errados, e um segredo com acento no meio pode nao casar o padrao. Nao ha como distinguir isso de texto legitimo sem adivinhar a codificacao. Vale para as CINCO areas que leem conteudo - ``staging`` nao le conteudo nenhum; no ``historico`` o sinal e indireto, ver a linha seguinte |'
# TRES estados, e o terceiro faltava. Com '-SemHistorico' o detector nao roda,
# '$rHist' e nulo, e a versao anterior caia na redacao AFIRMATIVA - dizendo que
# a troca de codificacao foi aplicada numa execucao em que nada foi medido.
# Mesma forma do defeito que esta rodada corrigiu, deslocada para o ramo do
# modificador. Achado do security-reviewer.
#
# E 'FOI aplicada' e mais forte do que o que se sabe: o que se mediu e que o
# setter nao lancou. A frase diz isso agora.
$notaEnc = 'o setter de ``[Console]::OutputEncoding`` aceitou a troca para UTF-8 nesta execucao, entao byte invalido vira ``U+FFFD`` e a recusa por esse sinal vale'
if (-not $rHist) {
    $notaEnc = '**nao se aplica** - o historico NAO foi varrido nesta execucao, entao nada foi medido sobre a decodificacao de blob'
} elseif (-not $rHist.Cobertura.CodificacaoDoConsoleTrocada) {
    $notaEnc = '**a troca de ``[Console]::OutputEncoding`` NAO foi aplicada nesta execucao** (sem console anexado, ou stdout redirecionado): byte invalido NAO vira ``U+FFFD``, vira mojibake da codepage, e SO a recusa por NUL valeu. Esta area esta mais fraca do que esta linha descreveria sem esta ressalva'
}
W ('| **Blob do historico: legibilidade decidida pelos BYTES** | Desde a revisao r8 (S6) o detector le os bytes do ``git cat-file`` e decodifica em UTF-8 ESTRITO: byte invalido vira lacuna nomeada, e ``U+FFFD`` legitimo (EF BF BD) e lido. O que continua fora: blob em outra codificacao VALIDA para ela mas nao UTF-8 (UTF-16 com NUL, Latin-1) e declarado ilegivel em vez de varrido. Decodificacao do console nesta execucao (so afeta os nomes exibidos, nao a recusa): ' + $notaEnc + ' |')
W ('| **Estrutura de diretorio interna, nome de projeto e de cliente corporativo** | Nenhum detector representa isso: a area de exposicao cobre webhook, endpoint e credencial, tudo por URL. Consequencia pratica: `-ParaPublicacao` com `exit 0` **nao** significa publicavel. Camada complementar: **sanitizacao manual obrigatoria do REPOSITORIO INTEIRO, com inventario proprio**, antes de qualquer publicacao. A versao anterior prescrevia sanitizar apenas o que `portfolio.exposicao` e `dados_sensiveis_excecoes` apontassem - e o security-reviewer mediu: aqueles dois ponteiros cobrem UM arquivo, e o grep dele achou nome de cliente corporativo em 21 arquivos rastreados. Mitigacao dimensionada para uma fracao da superficie e pior que nenhuma: da a impressao de que ha roteiro suficiente |')
W "| Vulnerabilidade de dependencia | ``pip-audit``, ``npm audit``, Dependabot |"
W "| Arquivo **ignorado** pelo ``.gitignore`` | Fora de proposito: nao vai para o remoto. A eficacia da propria regra e verificada na area ``gitignore`` |"
W "| Intencao de quem escreveu | Nenhuma ferramenta responde isso |"
W ""

# --- achados ------------------------------------------------------------------
W "## Achados"
W ""
# Bloqueante = ALTA ou MEDIA que NAO esta coberto por excecao aprovada.
# O achado coberto continua na contagem de severidade e aparece no relatorio,
# em secao propria: aceitar e decisao registrada, nao apagamento (ADR-0010).
$aceitos = @($achados | Where-Object { $_.Disposicao -eq (Get-DisposicaoAceita) })
$bloqueantes = @($achados | Where-Object {
    ($_.Severidade -eq 'ALTA' -or $_.Severidade -eq 'MEDIA') -and $_.Disposicao -ne (Get-DisposicaoAceita)
})
if ($bloqueantes.Count -eq 0) {
    W "Nenhum achado de severidade ALTA ou MEDIA **no escopo coberto acima**."
    W ""
    W "Isto nao significa que o repositorio esta limpo: significa que nada"
    W "bloqueante foi encontrado nas areas declaradas como cobertas."
} else {
    W "| Severidade | Area | Categoria | Detalhe |"
    W "|---|---|---|---|"
    foreach ($a in ($bloqueantes | Sort-Object Severidade, Area, Categoria)) {
        W "| $($a.Severidade) | $($a.Area) | $($a.Categoria) | ``$($a.Detalhe)`` |"
    }
    W ""
    W "Valor de credencial, numero de documento e parte local de e-mail"
    W "**nunca** sao transcritos - so a localizacao. Para inspecionar, abra o"
    W "arquivo apontado."
}
W ""

W "## Achados ACEITOS POR EXCECAO (aparecem, com a severidade original, e nao bloqueiam o fluxo privado)"
W ""
if ($rDisp.ParaPublicacao) {
    W "``-ParaPublicacao`` foi usado: **nenhuma excecao vale nesta execucao.** Todo"
    W "achado ALTA ou MEDIA bloqueia, inclusive os que teriam excecao aprovada."
    W "Publicar ou exportar publicamente exige **sanitizacao**, nao excecao."
} elseif ($aceitos.Count -eq 0) {
    W "Nenhum."
} else {
    # 'Cobertos' e o contador do PORTAO: quantos achados a funcao de disposicao
    # efetivamente desarmou. A tabela abaixo e renderizada a partir de outra
    # lista - os achados que ficaram com Disposicao preenchida. Eram duas
    # contagens da mesma coisa e nenhuma conferia a outra: 'Cobertos' era
    # escrito e lido por ninguem, a QUARTA orfa desta subfase, achada assim que
    # o guarda de campo passou a exigir a forma '.Campo'. Agora o relatorio diz
    # o numero do portao E denuncia divergencia, em vez de mostrar uma tabela e
    # confiar que ela corresponde ao que o portao decidiu.
    W "**$($rDisp.Cobertos) achado(s)** tiveram a disposicao alterada por excecao aprovada."
    if ($divergenciaDeExcecao) {
        W ""
        W "> **Divergencia interna:** o portao de excecoes desarmou $($rDisp.Cobertos)"
        W "> achado(s), mas a lista de aceitos tem $($aceitosDoPortao.Count). Os dois"
        W "> numeros medem a mesma coisa por caminhos diferentes; divergirem"
        W "> significa que um deles esta errado. A divergencia tambem esta na"
        W "> tabela de lacunas DESTA execucao, que e onde o protocolo manda procurar."
    }
    W ""
    W "Estes achados foram **analisados e aceitos deliberadamente**, e continuam"
    W "aqui de proposito: aceitar e uma decisao registrada, nao um apagamento."
    W "A severidade e a original. O que muda e a **disposicao**."
    W ""
    W "A excecao e **estreita**: **igualdade** de caminho E de categoria - nao"
    W "prefixo, nao curinga, nao diretorio. Um achado parecido em outro arquivo,"
    W "um nome irmao que apenas comece igual, ou outra categoria no mesmo"
    W "arquivo, **continuam bloqueando**. E achado de severidade **ALTA nunca e"
    W "coberto**, qualquer que seja a excecao."
    W ""
    W "| Severidade | Area | Categoria | Detalhe | Excecao citada |"
    W "|---|---|---|---|---|"
    foreach ($a in ($aceitos | Sort-Object Severidade, Area, Categoria)) {
        W "| $($a.Severidade) | $($a.Area) | $($a.Categoria) | ``$($a.Detalhe)`` | ``$($a.ExcecaoCitada)`` |"
    }
    W ""
    W "Justificativa e decisao de cada excecao, como declaradas em"
    W "``project.yaml`` -> ``classificacao.dados_sensiveis_excecoes``:"
    W ""
    foreach ($e in $rDisp.Usadas) {
        W "- **$($e.caminho)** / *$($e.categoria)*"
        W "  - justificativa: $($e.justificativa)"
        W "  - decisao: $($e.decisao)"
        W "  - decidido em: $($e.decidido_em) | escopo: $($e.escopo)"
        W "  - registrado em: $($e.onde_esta_registrado)"
    }
    W ""
    W "**Publicacao continua exigindo sanitizacao.** Rode com ``-ParaPublicacao``"
    W "antes de qualquer export ou release publico: nesse modo toda excecao e"
    W "ignorada e estes achados voltam a bloquear."
}
if ($rExc.NaoAceitas.Count -gt 0) {
    W ""
    W "### Excecoes declaradas que NAO cobrem nada"
    W ""
    W "Declarar que a excecao existe e diferente de decidir aceita-la. Estas"
    W "entradas estao no manifesto e **nao** reclassificam nem liberam achado"
    W "nenhum, porque o ``status`` nao e exatamente ``aceito-por-excecao`` ou"
    W "porque falta campo obrigatorio (caminho, categoria, justificativa,"
    W "decisao, decidido_em)."
    W ""
    foreach ($e in $rExc.NaoAceitas) {
        # O MOTIVO, nao so o status: sem ele, quem escreveu a excecao nao
        # distingue "status errado" de "campo faltando" de "nao casou".
        $motivo = 'status nao e exatamente ' + (Get-StatusDeExcecaoAceita)
        if ($e.status -eq (Get-StatusDeExcecaoAceita)) {
            $faltando = @()
            foreach ($c in @('caminho', 'categoria', 'justificativa', 'decisao', 'decidido_em')) {
                if (-not $e.$c) { $faltando += $c }
            }
            $motivo = 'status correto, mas falta campo obrigatorio: ' + ($faltando -join ', ')
        }
        W "- ``$($e.caminho)`` - status: ``$($e.status)`` - **$motivo**"
    }
}
if ($rDisp.RecusadosPorSeveridade -gt 0 -and -not $rDisp.ParaPublicacao) {
    W ""
    W "### Achados ALTA: excecao NAO se aplica"
    W ""
    W "$($rDisp.RecusadosPorSeveridade) achado(s) de severidade **ALTA** tiveram a"
    W "disposicao **recusada por severidade**, ANTES de qualquer comparacao com o"
    W "manifesto - a ferramenta nem consultou as entradas. O limite e por severidade"
    W "e nao depende de existir entrada casando caminho e categoria. Alargar isso e"
    W "decisao da mantenedora, registrada em ADR, nao inferencia da ferramenta."
}
W ""
W "## Fatos registrados (BAIXA - nao bloqueiam)"
W ""
if ($baixas -eq 0) {
    W "Nenhum."
} else {
    W "| Area | Categoria | Detalhe |"
    W "|---|---|---|"
    foreach ($a in ($achados | Where-Object { $_.Severidade -eq 'BAIXA' } | Sort-Object Area, Categoria)) {
        W "| $($a.Area) | $($a.Categoria) | ``$($a.Detalhe)`` |"
    }
    W ""
    W "Estes nao travam o fluxo (ADR-0009), e continuam aqui de proposito:"
    W "quem revisa pode discordar da classificacao."
    if (@($achados | Where-Object { $_.Categoria -like '*fixture declarada*' }).Count -gt 0) {
        W ""
        W "Achado de categoria **fixture declarada** vem de arquivo que DECLARA o"
        W "marcador ``SEGREDO-FABRICADO-PARA-TESTE`` no proprio cabecalho: e teste"
        W "negativo, com valor inventado. Foi **reclassificado, nao silenciado**."
        W ""
        W "Mencionar o marcador no meio do texto nao vale como declaracao - se"
        W "valesse, qualquer arquivo desarmaria a varredura sobre si mesmo"
        W "escrevendo o marcador numa frase."
        W ""
        W "Confira que o proposito do arquivo justifica: o marcador e uma afirmacao de quem escreveu o arquivo, nao uma verificacao."
    }
}
W ""

# --- resumo -------------------------------------------------------------------
W "## Resumo por area"
W ""
W "| Area | ALTA | MEDIA | BAIXA |"
W "|---|---|---|---|"
foreach ($area in (Get-AreasDeVeredito)) {
    $daArea = @($achados | Where-Object { $_.Area -eq $area })
    $a1 = @($daArea | Where-Object { $_.Severidade -eq 'ALTA' }).Count
    $a2 = @($daArea | Where-Object { $_.Severidade -eq 'MEDIA' }).Count
    $a3 = @($daArea | Where-Object { $_.Severidade -eq 'BAIXA' }).Count
    W "| $area | $a1 | $a2 | $a3 |"
}
W ""
W "## Resumo numerico"
W ""
W "- Achados ALTA: $altas"
W "- Achados MEDIA: $medias"
W "- Fatos BAIXA: $baixas"
W "- Destes, ACEITOS POR EXCECAO (aparecem e nao bloqueiam): $($aceitos.Count)"
W "- Bloqueantes de verdade nesta execucao: $($bloqueantes.Count)"
W "- Arquivos rastreados: $($rastreados.Count)"
W "- Arquivos nao rastreados: $($naoRastreados.Count)"
W "- Arquivos com conteudo examinado: $examinados"
if ($rHist -and -not $rHist.Cobertura.SemCommits) {
    W "- Blobs do historico lidos: $($rHist.Cobertura.BlobsLidos)"
    W "- Ocorrencias do historico suprimidas por coincidir com o working tree: $($rHist.Cobertura.Coincidencias) (por blob x caminho x categoria, nao por fato distinto)"
}
W "- Codigo de saida desta execucao: $(if ($bloqueantes.Count -gt 0) { '1 (ha achado bloqueante)' } else { '0' })"

if ($g.NaoVerificaveis -gt 0) {
    W ""
    W "## Regras de ``.gitignore`` que a sonda nao representa"
    W ""
    W "Nao foram aprovadas nem reprovadas. Verificar estas exige sonda"
    W "especifica, e chutar produziria ``regra sem efeito`` falso."
    W ""
    foreach ($r in $g.ListaNaoVerificavel) { W "- ``$r``" }
}

[System.IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Relatorio: $Out" -ForegroundColor Cyan
if ($destinoRedirecionado) {
    Write-Host "  (FORA do repositorio-alvo: 'artifacts/' nao e ignorado la - item 157)" -ForegroundColor Yellow
}
Write-Host ("  ALTA: {0}   MEDIA: {1}   BAIXA: {2}   arquivos examinados: {3}" -f $altas, $medias, $baixas, $examinados)
Write-Host ""
if ($bloqueantes.Count -gt 0) { exit 1 }
exit 0
