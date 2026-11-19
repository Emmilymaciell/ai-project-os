<#
.SYNOPSIS
    Hook pre-commit: varredura RAPIDA de segredo sobre o WORKING TREE.

.LIMITACAO
    ELE LE O DISCO, NAO O INDICE. Esta linha vem antes de tudo porque a versao
    anterior deste cabecalho dizia "antes de o conteudo entrar", que e mais
    largo que o fato - e falsa garantia e a classe que esta plataforma trata
    como pior que lacuna. Achado do security-reviewer na primeira rodada da
    2.6, com o mesmo fato registrado pelo qa-reviewer.

    O que isso significa, nos dois sentidos:

      FALSO VERDE   'git add' de um arquivo com segredo, seguido de edicao ou
                    remocao do segredo NO DISCO: o blob com o segredo entra no
                    commit, e este hook aprova. O 'pre-push' completo - que le
                    os blobs do historico - barraria depois, mas a essa altura
                    o segredo ja esta num commit local.
      FRICCAO       um arquivo NAO RASTREADO com segredo barra um commit que
                    nao o contem. Barrar demais tambem tem custo: e assim que
                    se aprende a usar '--no-verify' por reflexo.

    Ler o indice de verdade - os blobs de 'git ls-files -s' - esta no backlog
    como item nominal. Nao foi feito aqui porque significaria superficie nova
    dentro do scanner, que e justamente o que a 2.6 evitou.

.DESCRIPTION
    Orquestrador, nao detector. Chama 'scripts/security-scan.ps1' com
    '-SemHistorico -SemRede' - os dois modificadores que a subfase 2.3 criou
    dizendo, no proprio docstring, "use apenas onde a latencia importa (hook
    de pre-commit)". Medido nesta maquina: 8,2 s contra o repositorio inteiro,
    93 arquivos.

    O QUE ELE NAO FAZ, e cada linha foi decidida:
      - nao roda a suite. Isso e o pre-push, e so quando o manifesto pedir;
      - nao varre o historico nem consulta a rede: nao e a pergunta deste
        momento, e as duas sao caras. As duas areas saem com LACUNA DECLARADA
        no relatorio, nao como aprovadas;
      - nao altera arquivo, nao faz 'git add', nao corrige nada. Hook que
        conserta sozinho muda o que a pessoa esta commitando sem ela ver;
      - nao escreve em 'artifacts/review/'. O destino e 'artifacts/hooks/',
        e isso nao e organizacao: 'artifacts/review/security-report.md' e a
        EVIDENCIA das revisoes independentes, e um hook que a regravasse a
        cada commit destruiria a evidencia do fechamento em curso.

    Codigo de saida - os do scanner, ADR-0009, sem reinterpretacao:
      0  nenhum achado ALTA ou MEDIA fora de excecao aprovada
      1  achou algo que bloqueia
      2  NAO conseguiu varrer - e isto BARRA tambem. Um scanner que nao rodou
         nao autoriza commit nenhum.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ''
    Write-Host "[pre-commit] NAO consegui rodar a verificacao: $_" -ForegroundColor Red
    Write-Host "Isto NAO e um veredito sobre o que esta em staging. Nada foi aprovado." -ForegroundColor Yellow
    Write-Host ''
    exit 2
}

$LibDir = Join-Path $PSScriptRoot 'lib'
foreach ($m in @('scan-comum.ps1', 'hooks-comum.ps1')) {
    $p = Join-Path $LibDir $m
    if (-not (Test-Path $p -PathType Leaf)) {
        Write-Host "[pre-commit] biblioteca ausente: '$p'" -ForegroundColor Red
        exit 2
    }
    . $p
}

$r = Get-RaizDoRepositorio -Path (Get-Location).Path
if (-not $r.Resolvida) {
    Write-Host "[pre-commit] nao consegui resolver a raiz do repositorio: $($r.Motivo)" -ForegroundColor Red
    exit 2
}
$raiz = $r.Raiz

$scanner = Join-Path $PSScriptRoot 'security-scan.ps1'
if (-not (Test-Path $scanner -PathType Leaf)) {
    Write-ProblemaDeHook -Hook 'pre-commit' -Problemas @(
        "o scanner nao existe em '$scanner', entao NADA foi verificado"
    ) -Acoes @(
        "restaure 'scripts/security-scan.ps1', ou remova o hook conscientemente com 'git config --unset core.hooksPath'"
    )
    exit 2
}

$destino = Join-Path $raiz 'artifacts\hooks\pre-commit-security.md'

Write-Host "[pre-commit] varredura rapida de segredo (sem historico, sem rede)..." -ForegroundColor DarkGray

# Processo filho: o codigo de saida tem de ser o do scanner, nao o efeito de
# ter sido dot-sourced aqui dentro.
# Invoke-FilhoDoHook, e nao a chamada direta: sob '$ErrorActionPreference =
# Stop' o stderr do filho vira ErrorRecord terminante e o 'trap' deste hook
# sairia com 2 sobre uma varredura que terminou bem. O qa-reviewer achou no
# pre-push; o MESMO defeito estava aqui, um hook ao lado - e e por isso que a
# funcao vive em hooks-comum.ps1 e os dois a chamam.
$argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scanner,
                '-Path', $raiz, '-Out', $destino, '-SemHistorico', '-SemRede')
$r = Invoke-FilhoDoHook -Argumentos $argumentos
$saida = $r.Saida
$codigo = $r.Exit

if ($codigo -eq 0) {
    # A mensagem de sucesso diz O QUE foi verificado, e nao so que passou.
    # "ok - sem achado bloqueante" sozinho deixava quem le acreditando que o
    # conteudo do commit tinha sido conferido; o que foi conferido e o disco.
    Write-Host "[pre-commit] ok - sem achado bloqueante NO WORKING TREE (disco, nao o indice)." -ForegroundColor DarkGray
    Write-Host "             Relatorio: $destino" -ForegroundColor DarkGray
    exit 0
}

if ($codigo -eq 1) {
    # Dizer O QUE bloqueou, nao so que bloqueou. Mensagem de hook que obriga a
    # abrir outro arquivo para descobrir a causa e mensagem que ensina a usar
    # '--no-verify' por reflexo.
    $problemas = @('a varredura de seguranca achou pelo menos um ALTA ou MEDIA que bloqueia')
    $problemas += @(Get-AchadosBloqueantesDoRelatorio -Caminho $destino)
    Write-ProblemaDeHook -Hook 'pre-commit' -Problemas $problemas -Acoes @(
        "leia o relatorio: $destino",
        "se o achado for legitimo e deliberado, registre a excecao em project.yaml (ADR-0010) - nao a contorne;",
        "detalhes e como contornar: docs/runbooks/hooks.md"
    )
    exit 1
}

Write-ProblemaDeHook -Hook 'pre-commit' -Problemas @(
    "o scanner saiu com ${codigo}: ele NAO conseguiu varrer, entao nao ha o que aprovar"
) -Acoes @(
    "rode a mao para ver o erro: .\scripts\security-scan.ps1 -SemHistorico -SemRede",
    "detalhes: docs/runbooks/hooks.md"
)
Write-Host $saida.Trim() -ForegroundColor DarkGray
exit 2
