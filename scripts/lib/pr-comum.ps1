<#
.SYNOPSIS
    Fatos compartilhados de PR: o 'gh' responde, e a evidencia autoriza?

.DESCRIPTION
    NENHUMA funcao aqui le, escreve ou transcreve token. O 'gh' autentica por
    navegador (ADR-0003, item 5); o que estas funcoes fazem e perguntar a ele
    se ele esta autenticado, e invoca-lo.

    'Invoke-Gh' existe pelo mesmo motivo de 'Invoke-FilhoDoHook' e
    'Invoke-NativoLocal', e e a quarta porta da mesma armadilha: no PowerShell
    5.1, stderr de executavel nativo vira ErrorRecord, e sob
    '$ErrorActionPreference = Stop' isso e TERMINANTE. O 'gh' escreve avisos em
    stderr com frequencia - e um aviso derrubaria o script inteiro.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Invoke-Gh {
    <#
      Roda o 'gh' e devolve Ok, Saida e Exit. NUNCA lanca por stderr.
    #>
    param([Parameter(Mandatory = $true)][string[]]$Argumentos)

    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = (& gh @Argumentos 2>&1 | Out-String)
        $codigo = $LASTEXITCODE
    } catch {
        $ErrorActionPreference = $anterior
        return [pscustomobject]@{ Ok = $false; Saida = $_.Exception.Message; Exit = -1 }
    } finally {
        $ErrorActionPreference = $anterior
    }
    return [pscustomobject]@{ Ok = ($codigo -eq 0); Saida = $saida; Exit = $codigo }
}

function Get-EstadoDoGh {
    <#
      Devolve SEMPRE um objeto:
        Instalado    o executavel existe no PATH
        Autenticado  'gh auth status' respondeu 0
        Conta        login, quando da para extrair
        Versao       primeira linha de 'gh --version'
        Disponivel   Instalado E Autenticado
        Motivo       por que nao, quando nao

      Os dois estados negativos sao DIFERENTES de proposito: 'nao instalado' e
      'instalado e deslogado' levam a acoes diferentes, e juntar os dois daria
      o conselho errado.
    #>
    $r = [pscustomobject]@{
        Instalado = $false; Autenticado = $false; Conta = ''
        Versao = ''; Disponivel = $false; Motivo = ''
    }

    $cmd = $null
    try { $cmd = Get-Command gh -ErrorAction SilentlyContinue } catch { $cmd = $null }
    if (-not $cmd) {
        $r.Motivo = "o 'gh' nao esta no PATH. Instale: winget install --id GitHub.cli"
        return $r
    }
    $r.Instalado = $true

    $v = Invoke-Gh @('--version')
    if ($v.Ok -and $v.Saida) {
        $r.Versao = (@($v.Saida -split "`r?`n") | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
    }

    $a = Invoke-Gh @('auth', 'status')
    if (-not $a.Ok) {
        $r.Motivo = "o 'gh' esta instalado e NAO esta autenticado"
        return $r
    }
    $r.Autenticado = $true

    # A conta sai do texto do 'auth status'. NENHUM token e lido: o proprio
    # 'gh' imprime o token mascarado, e nada daqui o transcreve.
    $m = [regex]::Match(("" + $a.Saida), 'account\s+(\S+)')
    if (-not $m.Success) { $m = [regex]::Match(("" + $a.Saida), 'Logged in to \S+ as (\S+)') }
    if ($m.Success) { $r.Conta = $m.Groups[1].Value }

    $r.Disponivel = $true
    return $r
}

function Get-SecaoDeRelatorio {
    <#
      Devolve so o texto de UMA secao '## <Titulo>', ate o proximo '## '.

      Existe porque procurar um campo no relatorio INTEIRO e falso verde, e
      esta casa ja pagou duas vezes por isso na mesma subfase: primeiro com o
      carimbo do HEAD, depois com o codigo de saida da suite. O relatorio
      transcreve arquivos novos LITERALMENTE, entao qualquer linha que se
      pareca com um campo pode aparecer no corpo sem ser um campo.

      Devolve '' quando a secao nao existe - e quem chama trata isso como
      "nao reconheco o formato", nunca como "o campo nao estava la".
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Texto,
        [Parameter(Mandatory = $true)][string]$Titulo
    )

    $linhas = @(($Texto -replace "`r`n", "`n") -split "`n")
    $dentro = $false
    $saida = @()
    foreach ($l in $linhas) {
        if ($l -match '^##\s') {
            if ($dentro) { break }
            $dentro = ($l -match ('^##\s+' + [regex]::Escape($Titulo) + '\s*$'))
            continue
        }
        if ($dentro) { $saida += $l }
    }
    return ($saida -join "`n")
}

function Get-ComparacaoDaColeta {
    <#
      Contra que referencia a coleta foi feita, e quantas linhas de diff ela
      achou? Le a tabela 'Escopo COLETADO', que e onde o coletor registra isso:

          | `git diff HEAD` | 514 linha(s) |

      Devolve Referencia e Linhas; Referencia vazia significa "nao reconheco o
      formato".

      ISTO EXISTE POR UM ACHADO QUE EU NAO TINHA VISTO, e e o melhor da
      subfase. As duas correcoes que eu fiz na rodada 1 INTERAGEM:
      'Test-PublicavelNoRemoto' passou a EXIGIR arvore limpa, e com a arvore
      limpa o 'collect-diff.ps1' padrao - que compara contra HEAD - produz
      diff VAZIO. Ou seja: depois da minha correcao, toda coleta feita do jeito
      padrao que chegasse ao '-Abrir' teria necessariamente zero linhas de
      diff, e passaria. O corpo publicado continuaria afirmando "diff e
      resultado da suite".

      Eu tinha fechado METADE do achado da rodada 1 e escrito no comentario
      que havia fechado os dois.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Texto)

    # A TABELA TEM DUAS LINHAS QUE CASAM, e a primeira NAO e a que interessa:
    #
    #   | `git diff --stat HEAD` | 7 linha(s) |     <- vem primeiro
    #   | `git diff HEAD` | 551 linha(s) |
    #
    # Pegar a primeira dava 'Referencia = --stat HEAD', que nao resolve para
    # commit nenhum - e o portao entao devolvia INDETERMINADO para TODA coleta
    # real. O '-Abrir' nao autorizava nada, nunca, e a suite ficava verde
    # porque a minha fixture escrevia so a segunda linha.
    #
    # Foi o 'qa-reviewer' quem achou, na rodada 3, e eu confirmei por execucao
    # antes de consertar: 'Referencia = [--stat HEAD]', 'rev-parse' saiu 1.
    # Este e o defeito mais grave da subfase, e ele era invisivel por um
    # motivo que vale escrever: o teste fabricava a propria entrada, a partir
    # do meu modelo do formato, e nao do formato.
    #
    # O filtro e sobre a FORMA do que foi capturado: referencia de Git nunca
    # comeca com '-', e opcao de linha de comando sempre comeca. Percorro
    # todas as linhas e fico com a primeira que e mesmo uma referencia.
    $secao = Get-SecaoDeRelatorio -Texto $Texto -Titulo 'Escopo COLETADO'
    foreach ($m in [regex]::Matches($secao, '(?m)^\|\s*`git diff ([^`]+)`\s*\|\s*(\d+)\s*linha')) {
        $ref = $m.Groups[1].Value.Trim()
        if (-not $ref -or $ref.StartsWith('-')) { continue }
        return [pscustomobject]@{ Referencia = $ref; Linhas = [int]$m.Groups[2].Value }
    }
    return [pscustomobject]@{ Referencia = ''; Linhas = -1 }
}

function Test-CarimboDeHead {
    <#
      O relatorio esta carimbado com ESTE commit?

      A busca e ANCORADA no bloco de cabecalho - as linhas '- ' antes do
      primeiro '## '. A versao anterior procurava o SHA em QUALQUER ponto do
      texto, e o qa-reviewer mostrou por que isso e falso verde: o
      diff-report TRANSCREVE o diff do 'STATE.md', que cita SHAs de commit
      (hoje, seis deles). Bastava que o SHA do branch B aparecesse em prosa
      dentro da evidencia do branch A para a evidencia de A ser aceita como
      evidencia de B.

      O cabecalho dos dois relatorios tem a forma '- ... HEAD: `<sha>`', e o
      SHA pode ser curto ou inteiro - os dois geradores escrevem diferente, e
      exigir so um deles rejeitaria evidencia valida.

      Parar no primeiro '## ' importa: num diff unificado, a linha REMOVIDA
      comeca com '-', entao um cabecalho de relatorio citado dentro do corpo
      teria exatamente a forma que esta funcao procura.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Texto,
        [Parameter(Mandatory = $true)][string]$Head
    )

    foreach ($l in @(($Texto -replace "`r`n", "`n") -split "`n")) {
        if ($l -match '^##\s') { break }
        if ($l -notmatch '^-\s') { continue }
        $m = [regex]::Match($l, 'HEAD:\s*`([0-9a-fA-F]{7,40})`')
        if (-not $m.Success) { continue }
        $v = $m.Groups[1].Value
        if ($Head.StartsWith($v, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-EvidenciaParaPr {
    <#
      A evidencia autoriza abrir o PR?

      Devolve Ok, Problemas, Indeterminado e MotivoIndeterminado. Exige os
      DOIS relatorios existindo e carimbados com o HEAD atual. Relatorio de
      outro commit descreve outro codigo - e e a mesma regra que a dimensao
      'frescor' do doctor ja aplica.

      Esta funcao NAO roda o scanner nem o coletor: ela LE o que eles
      deixaram. Rodar aqui duplicaria ferramenta, que e o que a 2.6 evitou.

      O TERCEIRO PORTAO, e ele nasceu de um defeito meu: o cabecalho do
      'pr.ps1' prometia que a seguranca era verificada "com o fluxo privado
      tendo saido 0", e o codigo so conferia que o arquivo EXISTIA e citava o
      commit. Um relatorio cheio de achado ALTA passava. Falsa garantia em
      prosa e a classe que esta plataforma trata como pior que lacuna - a
      lacuna se ve, a garantia falsa tranquiliza.

      A ORDEM DOS DOIS PASSOS ABAIXO E O QUE IMPEDE O FAIL-OPEN, e ela nao e
      arbitraria:

        1. a secao '## Achados' tem de EXISTIR no relatorio. Sem ela eu nao
           entendo o formato, e isso e INDETERMINADO - exit 2, nao "nada
           achado";
        2. so entao 'Get-AchadosBloqueantesDoRelatorio' le os achados.

      O passo 1 existe porque aquela funcao devolve LISTA VAZIA quando o
      relatorio nao existe ou nao le - o que e deliberado no contexto dela, o
      hook, onde quem chama ja sabe pelo codigo de saida do scanner que houve
      bloqueio. Aqui ninguem sabe: usa-la crua faria "nao consegui ler" virar
      "pode abrir". Ela e reusada, e nao copiada, porque ela ja sabe a unica
      distincao dificil - achado real nao e achado ACEITO POR EXCECAO
      (ADR-0010), e as duas secoes tem linhas 'MEDIA'.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Raiz,
        [Parameter(Mandatory = $true)][string]$Head,
        [Parameter(Mandatory = $true)][string]$Base
    )

    $problemas = @()
    $indeterminado = $false
    $motivoIndeterminado = ''
    # A CAUSA e campo, e nao texto a ser procurado depois. O 'pr.ps1' escolhia
    # que comando sugerir procurando a palavra 'seguranca' na mensagem - e a
    # mensagem INTERPOLA nomes de referencia, entao uma base chamada
    # 'seguranca' mandava o usuario rodar o scanner quando o problema era a
    # coleta. Achado 4 do qa-reviewer na rodada 4.
    $causaIndeterminada = ''
    $textos = @{}
    $esperados = @(
        @{ Caminho = 'artifacts\review\diff-report.md'
           Nome    = 'a coleta de evidencia'
           Comando = '.\scripts\collect-diff.ps1' },
        @{ Caminho = 'artifacts\review\security-report.md'
           Nome    = 'a varredura de seguranca'
           Comando = '.\scripts\security-scan.ps1' }
    )

    foreach ($e in $esperados) {
        $p = Join-Path $Raiz $e.Caminho
        if (-not (Test-Path $p -PathType Leaf)) {
            $problemas += "$($e.Nome) nao existe ($($e.Caminho)). Rode: $($e.Comando)"
            continue
        }
        $txt = Read-TextoDeArquivo $p
        if ($null -eq $txt) {
            $problemas += "$($e.Nome) existe e nao le como texto: $($e.Caminho)"
            continue
        }
        $textos[$e.Caminho] = $txt
        # O carimbo e lido do CABECALHO, nao procurado no texto inteiro.
        # Ver 'Test-CarimboDeHead' para o falso verde que isso fecha.
        if (-not (Test-CarimboDeHead -Texto $txt -Head $Head)) {
            $curto = $Head.Substring(0, 7)
            $problemas += "$($e.Nome) nao esta carimbada com o HEAD atual ($curto) no cabecalho: ela descreve outro commit"
        }
    }

    # --- segundo portao, completado: a coleta ATESTA uma suite que passou? -------
    #
    # So existir e estar carimbada nao bastava, e o qa-reviewer nomeou a
    # consequencia: um diff-report gerado com a arvore limpa sai com
    # "(sem alteracoes contra HEAD)", e um gerado com '-SkipTests' declara a
    # lacuna - os dois passavam. O corpo do PR, enquanto isso, afirma para
    # quem le no GitHub que a evidencia traz "diff e resultado da suite".
    #
    # E a MESMA classe que o terceiro portao corrigiu, aplicada ao segundo: eu
    # consertei a seguranca e deixei o irmao dela como estava.
    $caminhoDiff = 'artifacts\review\diff-report.md'
    if ($textos.ContainsKey($caminhoDiff)) {
        # A BUSCA E ANCORADA NA SECAO, e a versao anterior nao era. O
        # qa-reviewer chamou isso de OITAVA instancia da mesma classe, e
        # estava certo: e exatamente o defeito do carimbo da rodada 1,
        # aplicado ao campo vizinho na mesma correcao.
        #
        # O que torna a busca solta perigosa: o 'collect-diff' transcreve os
        # arquivos novos LITERALMENTE, sem prefixo '+'. Uma linha
        # 'Codigo de saida: **0**' na coluna 0 de qualquer arquivo nao
        # rastreado entraria no relatorio e seria aceita como se fosse o
        # resultado da suite - inclusive numa coleta feita com '-SkipTests',
        # onde a secao de testes nao tem linha nenhuma.
        $secao = Get-SecaoDeRelatorio -Texto $textos[$caminhoDiff] -Titulo 'Resultado real dos testes'
        $m = [regex]::Match($secao, '(?m)^Codigo de saida:\s*\*\*(-?\d+)\*\*')
        if (-not $m.Success) {
            # Sem a linha, eu nao sei se a suite rodou. Isso e 2, nao 1: a
            # mesma regra do '## Achados'.
            if (-not $indeterminado) {
                $indeterminado = $true
                $causaIndeterminada = 'coleta'
                $motivoIndeterminado = "a coleta de evidencia nao registra o codigo de saida da suite. " +
                    "Ou o formato mudou, ou ela foi gerada sem rodar os testes - e eu nao afirmo que passou"
            }
        } elseif ($m.Groups[1].Value -ne '0') {
            $problemas += "a coleta de evidencia registra a suite saindo com $($m.Groups[1].Value): ela NAO passou"
        }

        # --- e a coleta DESCREVE a mudanca que o PR vai publicar? ---------------
        # Ver 'Get-ComparacaoDaColeta'. Sem isto, a coleta padrao - contra HEAD,
        # com a arvore limpa que o portao do remoto agora EXIGE - tem diff vazio
        # e passa, enquanto o corpo publicado afirma que traz o diff.
        $cmp = Get-ComparacaoDaColeta -Texto $textos[$caminhoDiff]
        if (-not $cmp.Referencia) {
            if (-not $indeterminado) {
                $indeterminado = $true
                $causaIndeterminada = 'coleta'
                $motivoIndeterminado = "a coleta de evidencia nao declara contra que referencia foi feita. " +
                    "Sem isso eu nao sei se ela descreve a mudanca deste PR"
            }
        } else {
            # A referencia tem de resolver para o MESMO commit que a base. Comparo
            # commits, e nao nomes: 'main' e 'origin/main' podem ser o mesmo ponto,
            # e exigir o nome literal rejeitaria coleta valida.
            $shaRef = ''
            $shaBase = ''
            $a = @(Invoke-Git @('-C', $Raiz, 'rev-parse', '--verify', '--quiet', ($cmp.Referencia + '^{commit}')) -PermitirFalha)
            if ($LASTEXITCODE -eq 0 -and @($a).Count -gt 0) { $shaRef = ("" + @($a)[0]).Trim() }
            $b = @(Invoke-Git @('-C', $Raiz, 'rev-parse', '--verify', '--quiet', ($Base + '^{commit}')) -PermitirFalha)
            if ($LASTEXITCODE -eq 0 -and @($b).Count -gt 0) { $shaBase = ("" + @($b)[0]).Trim() }

            if (-not $shaRef -or -not $shaBase) {
                if (-not $indeterminado) {
                    $indeterminado = $true
                    $causaIndeterminada = 'coleta'
                    $motivoIndeterminado = "nao consegui resolver '$($cmp.Referencia)' ou '$Base' para um commit, " +
                        "entao nao sei se a coleta descreve a mudanca deste PR"
                }
            } elseif ($shaRef -ne $shaBase) {
                $problemas += ("a coleta foi feita contra '$($cmp.Referencia)', e o PR vai contra '$Base': " +
                               "ela descreve outra comparacao. Rode: .\scripts\collect-diff.ps1 -Contra $Base")
            } elseif ($cmp.Linhas -le 0) {
                $problemas += ("a coleta contra '$($cmp.Referencia)' tem diff VAZIO: nao ha mudanca descrita nela, " +
                               "e o corpo do PR afirmaria trazer o diff")
            }
        }
    }

    # --- terceiro portao: a varredura de seguranca PASSOU? ----------------------
    $caminhoSeg = 'artifacts\review\security-report.md'
    if ($textos.ContainsKey($caminhoSeg)) {
        $txtSeg = $textos[$caminhoSeg]
        if ($txtSeg -notmatch '(?m)^##\s+Achados\s*$') {
            if (-not $indeterminado) {
                $indeterminado = $true
                $causaIndeterminada = 'seguranca'
                $motivoIndeterminado = "o relatorio de seguranca nao tem a secao '## Achados'. " +
                    "Eu nao reconheco o formato, e por isso nao afirmo que a varredura passou"
            }
        } else {
            $bloqueantes = @(Get-AchadosBloqueantesDoRelatorio -Caminho (Join-Path $Raiz $caminhoSeg))
            if (@($bloqueantes).Count -gt 0) {
                $problemas += "a varredura de seguranca tem $(@($bloqueantes).Count) achado(s) que bloqueiam:"
                foreach ($b in @($bloqueantes | Select-Object -First 5)) { $problemas += "    $b" }
            }
        }
    }

    return [pscustomobject]@{
        Ok                  = (@($problemas).Count -eq 0 -and -not $indeterminado)
        Problemas           = @($problemas)
        Indeterminado       = $indeterminado
        MotivoIndeterminado = $motivoIndeterminado
        CausaIndeterminada  = $causaIndeterminada
    }
}

function Test-PublicavelNoRemoto {
    <#
      O que o GitHub vai MOSTRAR e o que esta evidencia DESCREVE?

      Achado dos dois revisores independentes, e e o mais grave desta subfase.
      Todo o portao de evidencia compara os relatorios com o HEAD LOCAL - mas
      'gh pr create --head <branch>' NAO FAZ PUSH: o PR e montado pelo GitHub
      a partir do que esta no REMOTO.

      O caso e comum, nao exotico: empurro Y, commito Z aqui, regero a
      evidencia em Z, abro o PR. O PR mostra Y, e o corpo PUBLICADO afirma que
      "a evidencia desta mudanca" esta carimbada com Z. E falsa garantia num
      texto que SAI DA MAQUINA - exatamente o que o portao dizia impedir
      ("diff de outro commit descreve outro codigo").

      Duas condicoes, e as duas recusam:
        1. arvore suja - a evidencia descreve o HEAD MAIS o que so existe no
           disco, e nada disso esta no remoto;
        2. ponta do remoto diferente do HEAD local.

      LIMITE DECLARADO, e ele e parte da garantia: isto le a ref de
      acompanhamento LOCAL, SEM REDE, e ela pode estar velha se ninguem
      buscou.

      A JUSTIFICATIVA ANTERIOR ESTAVA ERRADA, e fica registrada porque o erro
      era meu: eu escrevi "nao busco porque 'fetch' escreve refs". O
      'security-reviewer' desmontou - 'git ls-remote' LE o remoto sem escrever
      ref nenhuma, e este script ja vai a rede no passo seguinte, no proprio
      'gh'. "Fetch ou nada" era um falso dilema que eu mesmo construi.

      O QUE DE FATO ACONTECE HOJE: a correcao foi ADIADA, nao resolvida. O
      portao pega o caso comum - commitei e nao empurrei -, porque todo push
      FEITO DESTA MAQUINA atualiza a ref de acompanhamento. O que ele NAO pega
      e um remoto alterado de outro lugar: outra maquina, edicao pela
      interface web, ou uma CI que empurre.

      GATILHO PARA REVISITAR, e ele e concreto: antes de a subfase 2.8 passar
      a empurrar branches, OU na primeira vez que o remoto for alterado por
      outro meio que nao um push feito DESTE clone.

      A ref local esta certa enquanto o remoto so mudar por push feito deste
      clone. A redacao anterior dizia "enquanto so uma pessoa empurra, desta
      maquina" - e o security-reviewer apontou que isso nao exclui a mesma
      pessoa editando pela interface web, nem o botao "Update branch" do
      GitHub, nem outro clone na mesma maquina. Item 121 no backlog do STATE.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Raiz,
        [Parameter(Mandatory = $true)][string]$Branch,
        [Parameter(Mandatory = $true)][string]$Head,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Sujos
    )

    $problemas = @()

    if (@($Sujos).Count -gt 0) {
        $problemas += ("a arvore tem $(@($Sujos).Count) arquivo(s) nao commitado(s): a evidencia descreve " +
                       "o HEAD mais o que esta so no disco, e nada disso esta no remoto")
    }

    # 'refs/remotes/origin/<branch>' PRIMEIRO, e a ordem foi invertida pelos
    # DOIS revisores na rodada 2, pelo mesmo motivo: o 'gh pr create --head
    # <branch>' pede ao GitHub o branch com ESTE NOME, e nao o upstream
    # configurado. Comparar com o upstream da o resultado errado quando os
    # dois divergem - um branch local 'feat' que acompanha 'origin/feat-x'
    # seria conferido contra 'feat-x' enquanto o GitHub mostraria 'feat'.
    #
    # O upstream fica como fallback, para o caso de o remoto nao se chamar
    # 'origin'. Ele e pior que a ref direta, e por isso vem depois.
    $remoto = ''
    $o = @(Invoke-Git @('-C', $Raiz, 'rev-parse', '--verify', '--quiet', ('refs/remotes/origin/' + $Branch)) -PermitirFalha)
    if ($LASTEXITCODE -eq 0 -and @($o).Count -gt 0) {
        $remoto = ("" + @($o)[0]).Trim()
    } else {
        $u = @(Invoke-Git @('-C', $Raiz, 'rev-parse', '--verify', '--quiet', ($Branch + '@{upstream}')) -PermitirFalha)
        if ($LASTEXITCODE -eq 0 -and @($u).Count -gt 0) { $remoto = ("" + @($u)[0]).Trim() }
    }

    # Duas condicoes INDEPENDENTES, e nao um if/elseif: encadeadas, desligar a
    # primeira fazia a segunda tentar '$remoto.Substring(0,7)' sobre vazio e
    # morrer por excecao. Uma guarda que, quando removida, derruba o teste por
    # ERRO em vez de por VEREDITO esconde o que o teste mede.
    if (-not $remoto) {
        $problemas += ("o branch '$Branch' nao existe no remoto que esta maquina conhece: nao ha o que o " +
                       "GitHub possa mostrar. Empurre primeiro, com 'git push -u origin $Branch'")
    }
    if ($remoto -and $remoto -ne $Head) {
        $problemas += ("o remoto esta em $($remoto.Substring(0, 7)) e o HEAD local em $($Head.Substring(0, 7)): " +
                       "o PR mostraria o primeiro, e o corpo afirmaria o segundo")
    }

    return [pscustomobject]@{ Ok = (@($problemas).Count -eq 0); Problemas = @($problemas) }
}

function Test-TituloDePr {
    <#
      Devolve a mensagem do problema, ou '' quando o titulo serve.

      ISTO E FUNCAO, e nao um 'if' dentro do pr.ps1, por um motivo medido: o
      teste funcional NAO CONSEGUE exercitar esta regra. A suite roda os
      scripts como processo filho, com 'powershell -File', e nessa travessia
      um titulo com aspa dupla e desmontado ANTES de chegar ao script -
      'fix "a --draft"' faz o filho falhar a ligacao de parametros, porque
      '-draft' nao e parametro dele, e o processo sai 1 sem nunca executar
      esta verificacao.

      O caso funcional que eu havia escrito passava por causa DISSO, e nao da
      guarda: apagar a guarda nao o derrubava. Era a decima vez, nesta
      subfase, que um caso meu media outra coisa que nao o que anunciava.

      A regra vale para o uso REAL, que e a chamada direta numa sessao do
      PowerShell: ali o parser entrega a string inteira ao script, a aspa
      chega, e a injecao abaixo e possivel. Medido com uma sonda .exe:

        -Titulo 'fix "a --draft"'                 ->  [1]=fix a  [2]=--draft
        -Titulo 'corrige o "modo seguro" do hook' ->  [1]=corrige o modo
                                                      [2]=seguro do hook

      Recusar e mais honesto que escapar: escapar exigiria reproduzir a regra
      de citacao do PowerShell 5.1, que e justamente a regra que me enganou
      duas vezes nesta subfase.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Titulo)

    if ([string]::IsNullOrWhiteSpace($Titulo)) { return 'o titulo esta vazio' }
    if ($Titulo.Contains('"')) {
        return 'o titulo tem aspa dupla, e no PowerShell 5.1 isso parte o argumento - o que vier depois pode chegar ao gh como FLAG'
    }
    # BARRA INVERTIDA NO FIM, e isto e a OUTRA metade da mesma regra de
    # citacao. Os dois revisores previram, nenhum podia medir, e a medicao
    # mostrou que e pior do que os dois supunham - eles achavam que falharia
    # fechado:
    #
    #   -Titulo 'corrige path C:\temp\'  ->  COUNT=2
    #                                        [1]=corrige path C:\temp" --body corpo --base main
    #
    # O titulo ENGOLE os argumentos seguintes inteiros. '--body' e '--base'
    # nao chegam ao 'gh', e o PR sairia sem corpo e contra a base que o 'gh'
    # escolhesse sozinho. Nao e falha fechada: e a chamada errada, silenciosa.
    if ($Titulo.EndsWith('\')) {
        return 'o titulo termina em barra invertida, e no PowerShell 5.1 isso faz o titulo ENGOLIR os argumentos seguintes - o PR sairia sem corpo e contra outra base'
    }
    return ''
}

function Get-ArgumentosDePrCreate {
    <#
      Monta a linha de comando do 'gh pr create'.

      Isto e funcao, e nao um array montado dentro do pr.ps1, por um motivo
      que a suite nomeia: o 'gh' REAL e um .exe e o 'gh' MOCKADO do teste e um
      .cmd, e o .cmd TRUNCA argumento multilinha na primeira quebra - medido.
      Pinar a montagem aqui, em memoria, mede o que o mock nao consegue medir.

      A prosa anterior dizia tambem que "o PowerShell entrega argumento direto
      ao .exe". O qa-reviewer contestou, e MEDI os dois lados - ele estava
      certo quanto a minha afirmacao e errado quanto a consequencia. Passando
      'x" --repo "outro/repo' como um argumento para um .exe de sonda:

        COUNT=6 ... [3]=x --repo outro/repo

      A CONCLUSAO QUE EU TIREI DISSO ESTAVA ERRADA, e ela sobreviveu aqui por
      duas rodadas. Eu havia escrito "nao houve injecao de flag, so
      corrupcao" - generalizando de UMA entrada, sem espaco antes da aspa. O
      'qa-reviewer' insistiu, e a medicao com espaco antes da aspa mostrou o
      contrario:

        -Titulo 'fix "a --draft"'       ->  [1]=fix a   [2]=--draft
        -Titulo 'corrige path C:\temp\'  ->  COUNT=2, o titulo engole
                                             '--body corpo --base main'

      HA injecao, e no caso da barra invertida ha ate supressao dos
      argumentos seguintes. Por isso 'Test-TituloDePr' RECUSA aspa dupla e
      barra no fim: este array garante a FORMA da chamada, e nao sobrevive a
      um titulo que quebre a citacao.

      NENHUM argumento de token entra aqui. O 'gh' autentica por navegador
      (ADR-0003, item 5); flag de credencial nesta lista seria credencial
      vazando para a linha de comando, que e visivel na lista de processos.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Base,
        [Parameter(Mandatory = $true)][string]$Origem,
        [Parameter(Mandatory = $true)][string]$Titulo,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Corpo,
        [switch]$Rascunho
    )
    # 'Origem', e nao 'Head': neste arquivo '$Head' ja quer dizer o SHA do
    # commit, e '--head' do 'gh' quer dizer o BRANCH. Dois sentidos para o
    # mesmo nome no mesmo arquivo e como se troca um pelo outro sem ver.
    $a = @('pr', 'create', '--base', $Base, '--head', $Origem, '--title', $Titulo, '--body', $Corpo)
    if ($Rascunho) { $a += '--draft' }
    return $a
}

function Get-CorpoDePr {
    <#
      Corpo do PR: ponteiros para a evidencia, nunca a evidencia transcrita.

      NADA de conteudo de relatorio entra aqui. Os relatorios vivem em
      'artifacts/', que e ignorado pelo Git e NAO viaja - entao quem le o PR
      no GitHub nao os tem. Dizer onde estao e honesto; colar o conteudo
      publicaria achado de seguranca num lugar que esta plataforma nunca
      autorizou.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Raiz,
        [Parameter(Mandatory = $true)][string]$Head,
        [Parameter(Mandatory = $true)][string]$Base
    )

    $linhas = @(
        "Base: ``$Base``  -  HEAD: ``$($Head.Substring(0,7))``",
        "",
        "## Verificacao",
        "",
        "A evidencia desta mudanca foi coletada e esta carimbada com este HEAD:",
        "",
        "- ``artifacts/review/diff-report.md`` - diff e resultado da suite",
        "- ``artifacts/review/security-report.md`` - varredura de seguranca, fluxo privado",
        "",
        "**Os dois vivem em ``artifacts/``, que e ignorado pelo Git e nao viaja num clone.**",
        "Quem for revisar precisa regera-los localmente, com os mesmos comandos.",
        "",
        "## Limite deste PR",
        "",
        "Nao ha protecao de branch neste repositorio (ADR-0011): o plano atual nao a",
        "oferece. Este PR organiza a revisao; ele **nao impede** merge sem revisao, e os",
        "hooks locais da subfase 2.6 sao contornaveis com ``--no-verify``, por desenho.",
        "A verificacao independente e a CI da subfase 2.8."
    )
    return ($linhas -join "`n")
}
