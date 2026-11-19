<#
.SYNOPSIS
    Hook pre-push: o portao antes de o historico sair da maquina.

.DESCRIPTION
    Orquestrador. Nao verifica nada por conta propria: compoe o que ja existe,
    e QUEM compoe e o manifesto do projeto, nao este arquivo.

      verificacao:
        hooks:
          pre_push: ["security", "doctor"]

    Vocabulario FECHADO - 'security', 'doctor', 'tests', 'nenhum' - e valor
    fora dele BARRA, com o nome do valor. Essa direcao foi decidida na 2.5,
    quando 'verificacao.tests' com valor nao reconhecido passou a gerar lacuna
    em vez de virar falso: o que o leitor nao entende nunca pode virar
    "entao nao precisa".

    CAMPO AUSENTE e caso diferente de valor invalido, e segue a semantica que
    a mantenedora fixou em 2026-09-17 para 'ambiente.dependencias':

      ausente  -> o padrao declarado aqui: 'security' + 'doctor'. Medido:
                  ~30 s. Ausente nao e 'nao verifique', e tambem nao autoriza
                  impor o caro.
      ["nenhum"] -> desligado EXPLICITAMENTE. A diferenca entre isto e o campo
                  ausente e a diferenca entre "nao quero" e "nao pensei".
      lista    -> exatamente o que esta ali.

    'tests' NAO entra no padrao de proposito. A suite completa desta
    plataforma leva ~12 min; impor isso a todo push seria o "executa tudo
    porque existe" - e o efeito real seria ensinar '--no-verify'.

    Codigo de saida:
      0  tudo o que o manifesto pediu passou
      1  alguma verificacao reprovou
      2  alguma verificacao NAO pode rodar, ou a politica e ilegivel. Barra
         tambem: "nao consegui conferir" nunca vira "pode subir".

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

trap {
    Write-Host ''
    Write-Host "[pre-push] NAO consegui rodar as verificacoes: $_" -ForegroundColor Red
    Write-Host "Isto NAO e um veredito sobre o que seria enviado. Nada foi aprovado." -ForegroundColor Yellow
    Write-Host ''
    exit 2
}

$LibDir = Join-Path $PSScriptRoot 'lib'
foreach ($m in @('scan-comum.ps1', 'doctor-comum.ps1', 'doctor-manifesto.ps1', 'hooks-comum.ps1')) {
    $p = Join-Path $LibDir $m
    if (-not (Test-Path $p -PathType Leaf)) {
        Write-Host "[pre-push] biblioteca ausente: '$p'" -ForegroundColor Red
        exit 2
    }
    . $p
}

# --- 0. refs/preservado/* nunca sai da maquina (r10, S-A5) --------------------
# Convencao da plataforma: ref local que protege conteudo que NAO pode ir ao
# remoto (ex.: stash orfao anterior a uma sanitizacao). A protecao dela e o
# bundle do 'eos backup'. Um 'push --mirror' ou 'push origin refs/preservado/x'
# manual a levaria - e isso barra ANTES da politica, inclusive com 'nenhum'.
# O Git entrega no stdin uma linha por ref: <local ref> <local sha> <remote ref> <remote sha>.
# So le se o stdin vem de pipe, e com prazo: o Git escreve as linhas e FECHA o
# pipe na hora, mas quem chama o hook a mao herda um stdin que nunca fecha, e
# ReadToEnd esperaria para sempre (medido: a suite de hooks travou assim).
# Sem fim em 5 s = nao foi o Git que chamou; segue sem refs para conferir.
# Duas armadilhas MEDIDAS: o ReadToEndAsync de [Console]::In e sincrono por
# dentro no .NET Framework; e uma leitura PENDENTE no stdin (ReadAsync com
# prazo) trava todo executavel nativo lancado depois (o git do doctor) ate o
# pipe fechar. Por isso nunca ha leitura pendente: PeekNamedPipe diz quantos
# bytes ha, e so se le o que ja chegou.
$refsDoPush = ''
if ([Console]::IsInputRedirected) {
    if (-not ('EosStdinPeek' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class EosStdinPeek {
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool PeekNamedPipe(IntPtr h, IntPtr b, uint n, IntPtr r, out uint avail, IntPtr left);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetStdHandle(int n);
    // >= 0: bytes disponiveis; -1: pipe fechado (fim); -2: stdin nao e pipe
    public static int Disponivel() {
        uint a;
        if (PeekNamedPipe(GetStdHandle(-10), IntPtr.Zero, 0, IntPtr.Zero, out a, IntPtr.Zero)) { return (int)a; }
        return Marshal.GetLastWin32Error() == 109 ? -1 : -2;
    }
}
'@
    }
    $entradaPush = [Console]::OpenStandardInput()
    $bufPush = New-Object byte[] 65536
    $acumPush = New-Object System.IO.MemoryStream
    $prazoPush = [DateTime]::UtcNow.AddSeconds(5)
    while ([DateTime]::UtcNow -lt $prazoPush) {
        $dispPush = [EosStdinPeek]::Disponivel()
        if ($dispPush -eq -1) { break }
        # -2: stdin nao e pipe (arquivo, NUL). O Git sempre entrega por pipe; e ler
        # o console stream nesse caso tambem travou (medido). Nada a conferir.
        if ($dispPush -eq -2) { break }
        if ($dispPush -eq 0) { Start-Sleep -Milliseconds 50; continue }
        $nPush = $entradaPush.Read($bufPush, 0, [Math]::Min($dispPush, $bufPush.Length))
        if ($nPush -le 0) { break }
        $acumPush.Write($bufPush, 0, $nPush)
    }
    $refsDoPush = [System.Text.Encoding]::UTF8.GetString($acumPush.ToArray())
}
$preservadas = @()
foreach ($linhaRef in ($refsDoPush -split "`r?`n")) {
    $campos = @($linhaRef.Trim() -split '\s+')
    if ($campos.Count -ge 3) {
        foreach ($nomeRef in @($campos[0], $campos[2])) {
            if ($nomeRef.StartsWith('refs/preservado/', [System.StringComparison]::OrdinalIgnoreCase)) { $preservadas += $nomeRef }
        }
    }
}
if (@($preservadas).Count -gt 0) {
    Write-ProblemaDeHook -Hook 'pre-push' -Problemas @(
        ('push de ref local deliberada recusado: ' + ((@($preservadas) | Select-Object -Unique) -join ', ')),
        'refs/preservado/* protege conteudo que nao pode ir ao remoto; a copia dela e o bundle do eos backup'
    ) -Acoes @('envie so branches e tags (sem --mirror e sem refs/preservado/*)')
    exit 1
}

$VOCABULARIO = @('security', 'doctor', 'tests', 'nenhum')
$PADRAO      = @('security', 'doctor')

$r = Get-RaizDoRepositorio -Path (Get-Location).Path
if (-not $r.Resolvida) {
    Write-Host "[pre-push] nao consegui resolver a raiz do repositorio: $($r.Motivo)" -ForegroundColor Red
    exit 2
}
$raiz = $r.Raiz

# --- 1. a politica, lida do manifesto ----------------------------------------
$manifesto = Join-Path $raiz 'project.yaml'
$politica = @($PADRAO)
$origemDaPolitica = "padrao (o manifesto nao declara 'verificacao.hooks.pre_push')"

if (Test-Path $manifesto -PathType Leaf) {
    $lido = $null
    try { $lido = Read-ManifestoDoDoctor -Caminho $manifesto }
    catch {
        # Manifesto ilegivel nao pode virar "usa o padrao": o projeto PODE ter
        # declarado algo mais forte ali dentro, e assumir o padrao seria
        # verificar menos do que ele pediu, em silencio.
        Write-ProblemaDeHook -Hook 'pre-push' -Problemas @(
            "o project.yaml existe e nao pode ser lido: $($_.Exception.Message)",
            'sem ler a politica eu nao sei o que este projeto exige antes de um push'
        ) -Acoes @("conserte o project.yaml, ou rode as verificacoes a mao e veja docs/runbooks/hooks.md")
        exit 2
    }

    $declarado = $null
    try { $declarado = Get-CampoDoProjeto -Raiz $lido -Caminho 'verificacao.hooks.pre_push' -Opcional }
    catch {
        Write-ProblemaDeHook -Hook 'pre-push' -Problemas @(
            "'verificacao.hooks.pre_push' existe e nao pode ser lido: $($_.Exception.Message)"
        ) -Acoes @('declare uma lista de: ' + ($VOCABULARIO -join ', '))
        exit 2
    }

    if ($null -ne $declarado) {
        # SEM filtrar vazio aqui. O filtro era '| Where-Object { $_ -ne "" }',
        # e ele rodava ANTES da conferencia de vocabulario - entao um item
        # vazio sumia, a contagem caia para zero, e a lista caia no ramo de
        # 'nenhum' DESLIGANDO TUDO com exit 0, sob o rotulo falso de "lista
        # vazia ([])".
        #
        # Achado do qa-reviewer na segunda rodada, e e a classe que esta
        # subfase mais repetiu: o conserto do '[]' fechou um ramo e jogou o
        # irmao vazio no mesmo caminho. Medido: '- ""' e '- "   "' devolvem
        # lista de UM item vazio; '[]' e o hifen sozinho devolvem ZERO itens.
        # Sao fatos diferentes e agora tem tratamento diferente.
        $politica = @($declarado | ForEach-Object { ("" + $_).Trim().ToLower() })
        $origemDaPolitica = 'declarada em project.yaml -> verificacao.hooks.pre_push'

        # LISTA VAZIA DECLARADA e desligamento EXPLICITO, igual a ["nenhum"].
        #
        # Achado do qa-reviewer, confirmado por execucao: o leitor devolve um
        # Object[] de zero itens para 'pre_push: []', e '$null -ne @()' e
        # VERDADEIRO. A politica virava lista vazia, nenhum valor era
        # desconhecido, 'nenhum' nao estava la, nada entrava na fila - e o
        # hook terminava imprimindo "ok -  passaram" com exit 0. Duas coisas
        # erradas ao mesmo tempo: um segundo jeito de desligar, sem
        # documentacao, e uma mensagem de APROVACAO sobre zero verificacao.
        #
        # A semantica que a mantenedora fixou em 2026-09-17 para
        # 'ambiente.dependencias' ja respondia isto: [] e declaracao
        # EXPLICITA de "nao ha". Entao [] cai no mesmo ramo de 'nenhum', com a
        # mesma mensagem honesta - e nao num terceiro comportamento calado.
        if (@($politica).Count -eq 0) {
            # LISTA SEM NENHUM ITEM - '[]' ou o hifen sozinho, que foram
            # medidos e devolvem os dois contagem zero. O rotulo nao cita mais
            # a grafia '[]': ele dizia isso para formas que nao eram '[]', e
            # afirmar a grafia errada no proprio aviso e registro falso.
            $politica = @('nenhum')
            $origemDaPolitica = "declarada em project.yaml como lista SEM ITENS, que e o mesmo que ['nenhum']"
        }
    }
}

# Colecao em FLUXO - pre_push: ["doctor"] - chega aqui como UMA string com
# colchete dentro, porque o leitor de manifesto desta plataforma le lista de
# bloco e nao de fluxo (item 42 do backlog). Sem esta deteccao a pessoa leria
# "nao reconheco '["doctor"]'" e procuraria erro de digitacao num valor que
# ela escreveu certo.
# ITEM VAZIO e declaracao incompleta, nao desligamento. Barra, e diz onde.
$itensVazios = @($politica | Where-Object { $_ -eq '' })
if (@($itensVazios).Count -gt 0) {
    Write-ProblemaDeHook -Hook 'pre-push' -Problemas @(
        ("'verificacao.hooks.pre_push' tem $(@($itensVazios).Count) item(ns) VAZIO(s) na lista"),
        'item vazio nao e desligamento: nao da para saber se faltou escrever o valor ou se era para nao verificar nada'
    ) -Acoes @(
        'para NAO verificar nada, declare explicitamente:',
        '    pre_push:',
        '      - "nenhum"',
        'para verificar, use um de: ' + ($VOCABULARIO -join ', ')
    )
    exit 2
}

$emFluxo = @($politica | Where-Object { $_ -like '`[*' -or $_ -like '*`]' })
if (@($emFluxo).Count -gt 0) {
    Write-ProblemaDeHook -Hook 'pre-push' -Problemas @(
        "'verificacao.hooks.pre_push' parece estar em colecao de FLUXO: $($politica -join ' ')",
        'este leitor de manifesto le lista de BLOCO, e leu a linha inteira como um valor so'
    ) -Acoes @(
        'declare assim:',
        '    hooks:',
        '      pre_push:',
        '        - "doctor"',
        '        - "security"'
    )
    exit 2
}

$desconhecidos = @($politica | Where-Object { $VOCABULARIO -notcontains $_ })
if (@($desconhecidos).Count -gt 0) {
    Write-ProblemaDeHook -Hook 'pre-push' -Problemas @(
        ("'verificacao.hooks.pre_push' tem valor(es) que eu nao reconheco: '" + ($desconhecidos -join "', '") + "'"),
        'nao sei o que eles mandam fazer, entao nao posso dizer que o push foi verificado'
    ) -Acoes @('o vocabulario e fechado: ' + ($VOCABULARIO -join ', '))
    exit 2
}

if ($politica -contains 'nenhum' -and @($politica).Count -gt 1) {
    Write-ProblemaDeHook -Hook 'pre-push' -Problemas @(
        ("a politica diz 'nenhum' junto com '" + (@($politica | Where-Object { $_ -ne 'nenhum' }) -join "', '") + "'"),
        'as duas coisas nao podem valer ao mesmo tempo, e adivinhar qual vale seria inventar politica'
    ) -Acoes @("deixe so 'nenhum', ou tire 'nenhum' da lista")
    exit 2
}

if ($politica -contains 'nenhum') {
    # A ORIGEM entra na mensagem: quem declarou [] precisa ver que isso foi
    # lido como 'nenhum', senao a equivalencia fica so no runbook.
    Write-Host "[pre-push] o projeto declara 'nenhum': nada foi verificado, por decisao registrada no manifesto." -ForegroundColor Yellow
    Write-Host "           origem: $origemDaPolitica" -ForegroundColor DarkGray
    exit 0
}

Write-Host "[pre-push] politica: $($politica -join ', ')  ($origemDaPolitica)" -ForegroundColor DarkGray

# --- 2. executar, na ordem do mais barato para o mais caro -------------------
# A ordem e deliberada: quem for barrar, que barre rapido. Doctor mede 2 s;
# o scanner completo, dezenas; a suite, minutos.
$ordem = @('doctor', 'security', 'tests')
$aRodar = @($ordem | Where-Object { $politica -contains $_ })

$falhou = @()
$naoRodou = @()

foreach ($etapa in $aRodar) {
    switch ($etapa) {

        'doctor' {
            $doctor = Join-Path $PSScriptRoot 'doctor.ps1'
            if (-not (Test-Path $doctor -PathType Leaf)) {
                $naoRodou += "doctor: 'scripts/doctor.ps1' nao existe, entao o diagnostico nao aconteceu"
                break
            }
            Write-Host '  doctor...' -ForegroundColor DarkGray
            $rd = Invoke-FilhoDoHook -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $doctor,
                                      '-Path', $raiz,
                                      '-Out', (Join-Path $raiz 'artifacts\hooks\pre-push-doctor.md'),
                                      '-OutJson', (Join-Path $raiz 'artifacts\hooks\pre-push-doctor.json'))
            $cd = $rd.Exit
            # WARN sai 0 e passa: WARN e "olhe isto", nao "isto esta quebrado".
            if ($cd -eq 1) { $falhou += 'doctor: o diagnostico saiu FAIL (artifacts/hooks/pre-push-doctor.md)' }
            elseif ($cd -ne 0) { $naoRodou += "doctor: saiu com $cd - alguma dimensao nao conseguiu medir" }
        }

        'security' {
            $scanner = Join-Path $PSScriptRoot 'security-scan.ps1'
            if (-not (Test-Path $scanner -PathType Leaf)) {
                $naoRodou += "security: 'scripts/security-scan.ps1' nao existe, entao nada foi varrido"
                break
            }
            Write-Host '  security (varredura completa, com historico)...' -ForegroundColor DarkGray
            $rs = Invoke-FilhoDoHook -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scanner,
                                      '-Path', $raiz,
                                      '-Out', (Join-Path $raiz 'artifacts\hooks\pre-push-security.md'))
            $cs = $rs.Exit
            if ($cs -eq 1) {
                $falhou += 'security: achado ALTA ou MEDIA que bloqueia (artifacts/hooks/pre-push-security.md)'
                $falhou += @(Get-AchadosBloqueantesDoRelatorio -Caminho (Join-Path $raiz 'artifacts\hooks\pre-push-security.md'))
            }
            elseif ($cs -ne 0) { $naoRodou += "security: o scanner saiu com $cs - ele nao conseguiu varrer" }
        }

        'tests' {
            $comando = $null
            if (Test-Path $manifesto -PathType Leaf) {
                try {
                    $lido2 = Read-ManifestoDoDoctor -Caminho $manifesto
                    $comando = Get-CampoDoProjeto -Raiz $lido2 -Caminho 'verificacao.comando' -Opcional
                } catch { $comando = $null }
            }
            if ([string]::IsNullOrWhiteSpace($comando)) {
                # A politica pede 'tests' e o manifesto nao diz como roda-los.
                # Isto e contradicao do proprio projeto, e nao ha o que supor:
                # chutar '.\tests\run-tests.ps1' seria inventar o contrato.
                $naoRodou += "tests: a politica pede 'tests' e o manifesto nao declara 'verificacao.comando'"
                break
            }
            Write-Host "  tests ($comando)..." -ForegroundColor DarkGray

            # FAIL-OPEN FECHADO AQUI, e ele era o pior desta subfase.
            #
            # A versao anterior era: "& $comando; exit $LASTEXITCODE". Achado
            # do qa-reviewer, e CONFIRMADO por execucao: quando '& $comando'
            # lanca - comando com erro de digitacao, arquivo renomeado,
            # 'pytest' sem o venv no PATH -, a excecao encerra SO aquela
            # instrucao. O 'exit' seguinte roda, e num processo NOVO
            # '$LASTEXITCODE' nunca foi definido: 'exit $null' sai com ZERO.
            # O hook classificava "passou" sobre uma suite que nao rodou.
            # Medido: comando inexistente devolveu 0; o controle, com comando
            # existente saindo 3, devolveu 3.
            #
            # Agora o filho responde por si: try/catch em volta, e um codigo
            # SENTINELA para cada forma de "nao rodou". Nenhum deles e 0 nem 1,
            # entao os dois caem no ramo de 'naoRodou' e o push barra com 2.
            #
            # As aspas simples de '$raiz' sao DOBRADAS: caminho com apostrofo
            # quebrava a sintaxe do filho e o resultado era rotulado "a suite
            # reprovou", quando a suite nem tinha comecado. Achado do
            # security-reviewer, mesma familia - diagnostico errado sobre o que
            # nao aconteceu.
            $raizEscapada = $raiz.Replace("'", "''")
            $filho = "Set-Location -LiteralPath '$raizEscapada'; " +
                     "try { & $comando } catch { Write-Host `$_.Exception.Message; exit 97 }; " +
                     "if (`$null -eq `$LASTEXITCODE) { exit 98 }; exit `$LASTEXITCODE"
            $rt = Invoke-FilhoDoHook -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $filho)
            $saidaT = $rt.Saida
            $ct = $rt.Exit
            if ($ct -eq 0) { }
            elseif ($ct -eq 1) { $falhou += 'tests: a suite do projeto reprovou' }
            # A mensagem cobre os DOIS casos que caem aqui, e nao so o primeiro:
            # o comando que nao existe, e o que comecou e lancou no meio. O
            # qa-reviewer mostrou que 'tests/run-tests.ps1' tem um 'throw' que
            # cai neste ramo - barrar estava certo, a causa impressa, errada.
            elseif ($ct -eq 97) { $naoRodou += "tests: '$comando' nao pode ser invocado ou lancou durante a execucao - nao existe, nao e executavel, depende de algo ausente, ou abortou no meio" }
            elseif ($ct -eq 98) { $naoRodou += "tests: '$comando' terminou sem devolver codigo de saida - nao da para afirmar que a suite rodou" }
            else { $naoRodou += "tests: a suite saiu com $ct - ela NAO rodou (ADR-0009)" }

            # A saida do filho e CAPTURADA, entao sem isto quem leva o barramento
            # nao ve uma linha sequer do motivo. Limitado as ultimas linhas de
            # proposito: despejar a suite inteira no terminal do hook afogaria a
            # mensagem que importa.
            if ($ct -ne 0) {
                $ultimas = @(($saidaT -split "`r?`n") | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 10)
                if (@($ultimas).Count -gt 0) {
                    Write-Host '  ultimas linhas da suite:' -ForegroundColor DarkGray
                    foreach ($l in $ultimas) { Write-Host "    $l" -ForegroundColor DarkGray }
                }
            }
        }
    }
}

if (@($naoRodou).Count -gt 0) {
    Write-ProblemaDeHook -Hook 'pre-push' -Problemas (@($naoRodou) + @($falhou)) -Acoes @(
        'uma verificacao que nao roda nao autoriza push: conserte o que falhou e repita;',
        'os relatorios desta execucao estao em artifacts/hooks/;',
        'detalhes e como contornar: docs/runbooks/hooks.md'
    )
    exit 2
}

if (@($falhou).Count -gt 0) {
    Write-ProblemaDeHook -Hook 'pre-push' -Problemas $falhou -Acoes @(
        'corrija o que foi apontado e repita o push;',
        'os relatorios desta execucao estao em artifacts/hooks/;',
        'detalhes e como contornar: docs/runbooks/hooks.md'
    )
    exit 1
}

Write-Host "[pre-push] ok - $($aRodar -join ', ') passaram." -ForegroundColor DarkGray
exit 0
