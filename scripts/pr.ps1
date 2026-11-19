<#
.SYNOPSIS
    Pull request via 'gh': abrir e consultar, com portao de evidencia.

.DESCRIPTION
    Client-side por decisao registrada (ADR-0011). Este script NAO substitui
    enforcement no servidor, que nao existe neste plano, e nao finge substituir:
    ele exige a evidencia que a plataforma ja sabe produzir antes de abrir um PR,
    e quem verifica de forma independente e a CI da 2.8.

    NAO MANIPULA TOKEN. O 'gh' autentica por navegador (ADR-0003, item 5), e
    este script so o invoca. Nenhum valor de credencial e lido, escrito ou
    transcrito para artefato.

    OS TRES PORTOES ANTES DE ABRIR, e nenhum deles e opcional:

      1. 'gh' presente e AUTENTICADO. Ausente ou deslogado sai 2 - "nao
         consegui verificar" nunca vira "pode abrir";
      2. EVIDENCIA coletada: 'artifacts/review/diff-report.md' tem de existir e
         estar carimbado com o HEAD atual. Diff de outro commit descreve outro
         codigo;
      3. SEGURANCA: 'artifacts/review/security-report.md' carimbado com o HEAD
         atual E SEM ACHADO BLOQUEANTE na secao '## Achados'. Abrir PR com
         achado bloqueante em aberto e levar o problema para a revisao de
         outra pessoa.

         Esta frase ja prometeu mais do que o codigo entregava: ela dizia "e o
         fluxo privado tendo saido 0" enquanto a verificacao so conferia que o
         arquivo existia e citava o commit. Um relatorio cheio de ALTA
         passava. O codigo foi corrigido, nao a frase - mas a frase fica
         registrada aqui porque falsa garantia e pior que lacuna: a lacuna se
         ve, a garantia falsa tranquiliza.

         Achado ACEITO POR EXCECAO (ADR-0010) nao bloqueia, e o relatorio sem
         a secao '## Achados' nao vira "nada achado": vira codigo 2.

    Codigo de saida - ADR-0009:
      0  abriu, ou respondeu a consulta
      1  RECUSOU: portao de evidencia ou de seguranca nao passou
      2  NAO CONSEGUIU determinar: sem 'gh', sem autenticacao, sem remoto,
         ou o 'gh' nao respondeu

.PARAMETER Path
    Raiz do repositorio.

.PARAMETER Abrir
    Abre o PR do branch atual para a base.

.PARAMETER Titulo
    Titulo do PR. Obrigatorio com -Abrir.

.PARAMETER Base
    Branch de destino. Default: o detectado por Get-BaseDeIntegracao.

.PARAMETER Rascunho
    Abre como draft.

.EXAMPLE
    .\scripts\pr.ps1
    .\scripts\pr.ps1 -Abrir -Titulo "feat(2.8): CI no GitHub Actions"

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [switch]$Abrir,
    [string]$Titulo,
    [string]$Base,
    [switch]$Rascunho
)

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ""
    Write-Host "pr.ps1 NAO rodou: $_" -ForegroundColor Red
    Write-Host "Nenhuma afirmacao sobre o PR e valida." -ForegroundColor Yellow
    Write-Host ""
    exit 2
}

$LibDir = Join-Path $PSScriptRoot 'lib'
# 'hooks-comum.ps1' entra aqui pela UNICA funcao que ele tem e que nao e de
# hook: 'Get-AchadosBloqueantesDoRelatorio', que le o relatorio do scanner e ja
# sabe a distincao dificil - achado real nao e achado ACEITO POR EXCECAO
# (ADR-0010). Reusar e o que a 2.6 estabeleceu; uma segunda copia dessa leitura
# divergiria da primeira, que foi o preco pago sete vezes naquela subfase.
foreach ($m in @('scan-comum.ps1', 'hooks-comum.ps1', 'branch-comum.ps1', 'pr-comum.ps1')) {
    $p = Join-Path $LibDir $m
    if (-not (Test-Path $p -PathType Leaf)) {
        Write-Host "ERRO: biblioteca ausente: '$p'" -ForegroundColor Red
        exit 2
    }
    . $p
}

$r = Get-RaizDoRepositorio -Path $Path
if (-not $r.Resolvida) {
    Write-Host "ERRO: $($r.Motivo)" -ForegroundColor Red
    exit 2
}
$raiz = $r.Raiz

# --- o 'gh' responde? -----------------------------------------------------------
$gh = Get-EstadoDoGh
if (-not $gh.Disponivel) {
    Write-Host ""
    Write-Host "NAO SEI: $($gh.Motivo)" -ForegroundColor Red
    Write-Host "  Sem o 'gh' autenticado eu nao consigo falar com o GitHub, e" -ForegroundColor Yellow
    Write-Host "  'nao consegui verificar' nunca vira 'esta tudo certo'." -ForegroundColor Yellow
    if ($gh.Instalado -and -not $gh.Autenticado) {
        Write-Host ""
        Write-Host "  Rode:  gh auth login   (ele autentica por navegador; eu nao toco em token)" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 2
}

$estado = Get-EstadoDeBranch -Raiz $raiz
if ($estado.Indeterminado) {
    Write-Host "NAO SEI: $($estado.Motivo)" -ForegroundColor Red
    exit 2
}

# =============================================================================
# CONSULTAR (default)
# =============================================================================
if (-not $Abrir) {
    Write-Host ""
    Write-Host "Pull requests - $raiz" -ForegroundColor Cyan
    Write-Host "  gh .......... $($gh.Versao), autenticado como $($gh.Conta)" -ForegroundColor DarkGray
    Write-Host "  branch ...... $($estado.Atual)   base: $($estado.Base)" -ForegroundColor DarkGray
    Write-Host ""

    $lista = Invoke-Gh @('pr', 'list', '--state', 'open', '--json', 'number,title,headRefName', '--limit', '30')
    if (-not $lista.Ok) {
        Write-Host "NAO SEI: o 'gh' nao respondeu a consulta de PRs." -ForegroundColor Red
        exit 2
    }
    # O 'ForEach-Object { $_ }' DESENROLA, e sem ele a lista vazia imprimia
    # uma linha fantasma: '#    ()'.
    #
    # MEDIDO, e o primeiro diagnostico que eu dei estava errado:
    # 'ConvertFrom-Json' sobre '[]' NAO devolve $null - ele devolve um
    # System.Object[] VAZIO como UM item do pipeline. Filtrar por '$null -ne $_'
    # mantem esse item, porque array vazio nao e nulo, e a contagem da 1.
    # Filtrar pela FORMA tambem nao serve: com um PR real o array de um
    # elemento chega igualmente inteiro, e o filtro o descartaria.
    #
    # Conferido nos tres casos: zero, um e dois PRs.
    #
    # O 'catch' NAO devolve lista vazia, e essa foi uma correcao do
    # qa-reviewer: 'Invoke-Gh' junta stderr na saida, e o proprio cabecalho
    # desta casa diz que o 'gh' escreve aviso em stderr com frequencia. Um
    # aviso faria o 'ConvertFrom-Json' lancar, o script imprimiria "nenhum PR
    # aberto" e sairia 0 - "nao consegui ler" virando fato.
    $prs = @()
    $naoLi = ''
    try {
        if ($lista.Saida.Trim()) {
            $prs = @($lista.Saida | ConvertFrom-Json | ForEach-Object { $_ } | Where-Object { $null -ne $_ })
        }
    } catch { $naoLi = $_.Exception.Message }

    if ($naoLi) {
        Write-Host "NAO SEI: o 'gh' respondeu, e eu nao consegui interpretar a resposta." -ForegroundColor Red
        Write-Host "  $naoLi" -ForegroundColor DarkGray
        Write-Host "  'lista vazia' seria uma afirmacao, e eu nao a tenho." -ForegroundColor Yellow
        exit 2
    }

    if (@($prs).Count -eq 0) {
        Write-Host "  nenhum PR aberto" -ForegroundColor DarkGray
    } else {
        foreach ($pr in $prs) {
            Write-Host ("  #{0}  {1}  ({2})" -f $pr.number, $pr.title, $pr.headRefName) -ForegroundColor Gray
        }
    }
    Write-Host ""
    exit 0
}

# =============================================================================
# ABRIR
# =============================================================================
# UMA verificacao de titulo, nao duas. Havia aqui um 'if (-not $Titulo)'
# separado, e depois do refactor ele virou codigo morto: 'Test-TituloDePr' ja
# recusa titulo vazio. A mutacao mostrou - apagar o 'if' nao derrubava caso
# nenhum, porque a funcao pegava o mesmo caso logo abaixo. Guarda sem caso
# proprio nao e protecao em dobro; e uma linha que ninguem mede.
#
# A validacao vive na funcao porque o teste funcional NAO consegue alcanca-la:
# pelo 'powershell -File', um titulo com aspa dupla e desmontado na travessia
# de processo e o filho falha a ligacao de parametros antes de executar
# qualquer coisa. Ver o docstring da funcao.
$erroTitulo = Test-TituloDePr -Titulo $Titulo
if ($erroTitulo) {
    Write-Host "RECUSADO: $erroTitulo" -ForegroundColor Red
    Write-Host '  Use aspas simples dentro do texto do titulo.' -ForegroundColor Yellow
    exit 1
}

$destino = $Base
if (-not $destino) { $destino = $estado.Base }
if (-not $destino) {
    Write-Host "NAO SEI: nao consegui determinar o branch de destino." -ForegroundColor Red
    Write-Host "  Passe -Base explicitamente. Chutar 'main' abriria PR contra o nada." -ForegroundColor Yellow
    exit 2
}

if ($estado.Atual -eq $destino) {
    Write-Host "RECUSADO: o branch atual E a base ('$destino'). Nao ha o que integrar." -ForegroundColor Red
    Write-Host "  Crie um branch:  .\scripts\branch.ps1 -Criar <nome>" -ForegroundColor Yellow
    exit 1
}

# --- PORTAO 1: evidencia e seguranca, carimbadas com o HEAD atual ---------------
$head = ''
$sha = @(Invoke-Git @('-C', $raiz, 'rev-parse', 'HEAD^{commit}') -PermitirFalha)
if ($LASTEXITCODE -eq 0 -and @($sha).Count -gt 0) { $head = @($sha)[0] }
if (-not $head) {
    Write-Host "NAO SEI: o HEAD nao resolve para um commit." -ForegroundColor Red
    exit 2
}

$portoes = Test-EvidenciaParaPr -Raiz $raiz -Head $head -Base $destino

# INDETERMINADO vem antes de RECUSADO, e sai 2 e nao 1, porque as duas coisas
# sao diferentes: 1 e "eu li e nao autoriza"; 2 e "eu nao consegui ler o
# suficiente para dizer". Juntar as duas faria 'nao sei' virar conselho.
if ($portoes.Indeterminado) {
    Write-Host ""
    Write-Host "NAO SEI: $($portoes.MotivoIndeterminado)" -ForegroundColor Red
    Write-Host ""
    # O conselho segue a CAUSA, e nao um comando fixo. Antes, todo
    # INDETERMINADO mandava rodar o scanner - inclusive quando o problema
    # estava na COLETA, que e a causa mais comum. Achado 4 do qa-reviewer.
    if ($portoes.CausaIndeterminada -eq 'seguranca') {
        Write-Host "  Regere a varredura:  .\scripts\security-scan.ps1" -ForegroundColor Yellow
    } else {
        Write-Host "  Regere a coleta:     .\scripts\collect-diff.ps1 -Contra $destino" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 2
}

if (-not $portoes.Ok) {
    Write-Host ""
    Write-Host "RECUSADO: a evidencia nao autoriza abrir o PR." -ForegroundColor Red
    foreach ($p in $portoes.Problemas) { Write-Host "  - $p" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  O que fazer:" -ForegroundColor Yellow
    Write-Host "    .\scripts\collect-diff.ps1 -Contra $destino" -ForegroundColor Yellow
    Write-Host "    .\scripts\security-scan.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Abrir PR sem isso e levar o problema para a revisao de outra pessoa." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# --- PORTAO 2: o remoto mostra o que a evidencia descreve? ----------------------
# Ver 'Test-PublicavelNoRemoto'. Sem isto, os tres portoes acima garantem
# alguma coisa sobre o HEAD LOCAL enquanto o PR publica o REMOTO.
$publicavel = Test-PublicavelNoRemoto -Raiz $raiz -Branch $estado.Atual -Head $head -Sujos $estado.Sujos
if (-not $publicavel.Ok) {
    Write-Host ""
    Write-Host "RECUSADO: o que o GitHub mostraria nao e o que esta evidencia descreve." -ForegroundColor Red
    foreach ($p in $publicavel.Problemas) { Write-Host "  - $p" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  O corpo do PR afirma, para quem le no GitHub, que a evidencia e DESTA" -ForegroundColor Yellow
    Write-Host "  mudanca. Abrir assim publicaria uma afirmacao falsa." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Isto foi lido da ref de acompanhamento LOCAL, sem rede: ela pode estar" -ForegroundColor DarkGray
    Write-Host "  velha se ninguem buscou." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

# --- abrir ---------------------------------------------------------------------
# '$args' NAO: e variavel automatica do PowerShell, e escrever nela e pedir
# para colidir com o que o proprio shell usa.
$argumentos = Get-ArgumentosDePrCreate -Base $destino -Origem $estado.Atual -Titulo $Titulo `
                  -Corpo (Get-CorpoDePr -Raiz $raiz -Head $head -Base $destino) -Rascunho:$Rascunho

Write-Host ""
Write-Host "Abrindo PR: $($estado.Atual) -> $destino" -ForegroundColor Cyan
$res = Invoke-Gh $argumentos
if (-not $res.Ok) {
    Write-Host "NAO SEI: o 'gh' nao conseguiu abrir o PR." -ForegroundColor Red
    if ($res.Saida) { Write-Host $res.Saida.Trim() -ForegroundColor DarkGray }
    exit 2
}

Write-Host ""
Write-Host "ABERTO" -ForegroundColor Green
if ($res.Saida) { Write-Host "  $($res.Saida.Trim())" -ForegroundColor Gray }
Write-Host ""
Write-Host "  Lembre: nao ha protecao de branch neste plano (ADR-0011)." -ForegroundColor DarkGray
Write-Host "  O PR organiza a revisao; ele nao impede merge sem ela." -ForegroundColor DarkGray
Write-Host ""
exit 0
