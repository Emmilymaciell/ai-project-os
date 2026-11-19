<#
.SYNOPSIS
    Harness compartilhado pelas suites de teste.

.DESCRIPTION
    Carregado por dot-source pelo runner raiz. As suites nao carregam isto
    sozinhas: elas verificam se Test-Caso existe e falham com mensagem clara
    se alguem tentar roda-las direto.

    Contadores em escopo de script: como o runner faz dot-source deste arquivo
    e depois de cada suite, tudo compartilha o escopo do runner.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

$script:passou = 0
$script:falhou = 0
$script:falhas = @()

function Test-Caso {
    <#
      Executa um caso. Excecao = falha; retornar $false tambem.
      Nunca deixa uma suite derrubar as outras.
    #>
    param([string]$Nome, [scriptblock]$Bloco)
    try {
        $r = & $Bloco
        if ($r -eq $false) { throw "retornou falso" }
        Write-Host ("  [PASS] " + $Nome) -ForegroundColor Green
        $script:passou++
    } catch {
        Write-Host ("  [FAIL] " + $Nome) -ForegroundColor Red
        Write-Host ("         " + $_.Exception.Message) -ForegroundColor DarkRed
        $script:falhou++
        $script:falhas += $Nome
    }
}

function Assert-True {
    param([bool]$Condicao, [string]$Mensagem)
    if (-not $Condicao) { throw $Mensagem }
}

function Get-Texto {
    <#
      Le um arquivo como UTF-8, sempre.
      Get-Content -Raw sem -Encoding no PowerShell 5.1 assume a codepage ANSI:
      um "Proximo" com acento vira dois caracteres e qualquer regex sobre ele
      falha de forma silenciosa. A documentacao deste repositorio e toda UTF-8
      com acento, entao ler errado nao e um detalhe.
    #>
    param([string]$Caminho)
    # ReadAllText com Encoding.UTF8 usa StreamReader com deteccao de preambulo,
    # entao o BOM JA e consumido aqui - verificado: um arquivo que comeca com
    # EF BB BF devolve '-' como primeiro char, nao U+FEFF.
    # Houve um ramo de remocao manual de BOM neste ponto. Era codigo morto, com
    # um diagnostico errado no comentario, e foi removido: o problema real que
    # ele tentava resolver era outro - Get-Content -Raw SEM -Encoding lendo
    # UTF-8 como ANSI e corrompendo acentos na regravacao. A regra que resolve
    # isso e usar esta funcao, nao remendar o sintoma.
    # UTF8Encoding($false, $true): o segundo argumento e throwOnInvalidBytes.
    #
    # A leitura anterior era [Text.Encoding]::UTF8, que substitui byte
    # invalido por U+FFFD em SILENCIO. O gemeo deste harness, no template,
    # foi endurecido na 2.4 e este ficou para tras - a mesma assimetria
    # que a rodada 11 corrigiu em scan-excecoes.ps1, agora na direcao
    # inversa. O qa-reviewer nomeou a consequencia: STATE.md salvo em ANSI
    # pelo Bloco de Notas (cenario que o runbook documenta como recorrente)
    # devolveria o texto com U+FFFD em cada acento, e as assercoes que
    # casam string sem acento continuariam VERDES sobre arquivo corrompido.
    $codificacao = New-Object System.Text.UTF8Encoding($false, $true)
    try { return [System.IO.File]::ReadAllText($Caminho, $codificacao) }
    catch [System.Text.DecoderFallbackException] {
        throw "'$Caminho' nao e UTF-8 valido (byte invalido solto). Salvo em ANSI/Windows-1252, tipicamente. Recusar e melhor que ler com U+FFFD no lugar do acento e passar verde."
    }
}

function Write-Suite {
    param([string]$Nome)
    Write-Host ""
    Write-Host $Nome -ForegroundColor White
}

function New-ProjetoDeTeste {
    <#
      Instancia o template numa pasta temporaria, como o /os:new-project faria,
      e devolve o caminho.

      Existe para os testes pararem de reimplementar a instanciacao caso a
      caso - e para ela ser feita do jeito CERTO. A substituicao NAO filtra
      por extensao: filtrar por '*.md','*.yaml','*.ps1' foi exatamente o
      defeito da Fase 1, em que .env.example e .gitignore ficaram com
      {{PROJECT_TITLE}} dentro. A skill proibe o glob; um teste que usasse o
      glob estaria testando um fluxo que a skill nao permite.

      -Trilha decide qual trilha de teste sobra, como o /os:new-project decide:
        python      apaga _harness.ps1 e suites/
        powershell  apaga conftest.py e test_smoke.py
        ambas       nao apaga nada (para provar que o runner RECUSA)
        nenhuma     apaga as duas (para provar a saida 2 por falta de suite)
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Template,
        [hashtable]$Valores = @{},
        [ValidateSet('python', 'powershell', 'ambas', 'nenhuma')][string]$Trilha = 'python'
    )

    # $env:TEMP nesta maquina devolve caminho 8.3 ("USUARI~1"), e o venv do
    # Python reclama em stderr sobre "environment location may have moved".
    # Resolver para o caminho longo evita o aviso e um diagnostico falso.
    $raizTemp = (Get-Item $env:TEMP).FullName
    $destino = Join-Path $raizTemp ("os-proj-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Copy-Item $Template $destino -Recurse -Force

    $padrao = @{
        '{{PROJECT_NAME}}'          = 'projeto-teste'
        '{{PROJECT_TITLE}}'         = 'Projeto Teste'
        '{{PROJECT_DESC}}'          = 'Instancia descartavel criada pelos testes da plataforma.'
        '{{CATEGORY}}'              = 'ai-lab'
        '{{CLIENT}}'                = 'pessoal'
        '{{PORTE}}'                 = 'script'
        '{{CRITICIDADE}}'           = 'baixa'
        '{{DADOS_SENSIVEIS}}'       = 'false'
        '{{COMPONENTE_LLM}}'        = 'false'
        '{{TEM_TESTS}}'             = 'true'
        '{{TEM_EVALS}}'             = 'false'
        '{{TEM_INTEGRACAO}}'        = 'false'
        '{{TEM_SECURITY}}'          = 'false'
        '{{PYTHON}}'                = 'nao-usa'
        '{{NODE}}'                  = 'nao-usa'
        '{{REMOTO}}'                = 'nenhum'
        '{{PORTFOLIO}}'             = 'false'
        '{{DATE}}'                  = (Get-Date -Format 'yyyy-MM-dd')
        '{{REVISAO_INDEPENDENTE}}'  = 'nenhuma'
        '{{VERIFICACAO_TESTS}}'     = 'suite de fumaca do template'
        '{{VERIFICACAO_EVALS}}'     = 'nao se aplica - sem componente LLM'
        '{{VERIFICACAO_SECURITY}}'  = 'nao se aplica - sem dado sensivel'
        '{{CRITERIO_PRONTO}}'       = 'a instancia roda a propria suite e ela passa'
    }
    foreach ($k in $Valores.Keys) { $padrao[$k] = $Valores[$k] }

    # Todo arquivo de TEXTO, e a decisao e pelo CONTEUDO, nao pela extensao.
    #
    # A primeira versao disto tinha uma allowlist de 13 extensoes, e o
    # qa-reviewer chamou a afirmacao de falsa com razao: o docstring dizia
    # "sem filtrar por extensao" e o codigo filtrava. Hoje cobria o template
    # inteiro por acidente; 'pyproject.toml', '.editorconfig' ou 'Makefile'
    # seriam pulados EM SILENCIO - e o teste que se apresenta como o fluxo
    # real da skill nao seria o fluxo real da skill. A regra da skill existe
    # porque na Fase 1 '.env.example' e '.gitignore' ficaram com
    # {{PROJECT_TITLE}} dentro justamente por causa de um glob de extensao.
    #
    # Binario e reconhecido por byte 0x00 nos primeiros 8 KB, que e como o
    # proprio Git decide: ler .xlsx como texto e regravar corromperia o
    # arquivo.
    Get-ChildItem $destino -Recurse -File -Force | ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $limite = [Math]::Min($bytes.Length, 8192)
        $ehBinario = $false
        for ($i = 0; $i -lt $limite; $i++) { if ($bytes[$i] -eq 0) { $ehBinario = $true; break } }
        if ($ehBinario) { return }
        $txt = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        $antes = $txt
        foreach ($k in $padrao.Keys) { $txt = $txt.Replace($k, $padrao[$k]) }
        if ($txt -ne $antes) {
            [System.IO.File]::WriteAllText($_.FullName, $txt, (New-Object System.Text.UTF8Encoding($false)))
        }
    }

    $tests = Join-Path $destino 'tests'
    switch ($Trilha) {
        'python' {
            Remove-Item (Join-Path $tests '_harness.ps1') -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $tests 'suites') -Recurse -Force -ErrorAction SilentlyContinue
        }
        'powershell' {
            Remove-Item (Join-Path $tests 'conftest.py') -Force -ErrorAction SilentlyContinue
            Get-ChildItem $tests -Filter 'test_*.py' -File -ErrorAction SilentlyContinue | Remove-Item -Force
        }
        'nenhuma' {
            Remove-Item (Join-Path $tests '_harness.ps1') -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $tests 'suites') -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $tests 'conftest.py') -Force -ErrorAction SilentlyContinue
            Get-ChildItem $tests -Filter 'test_*.py' -File -ErrorAction SilentlyContinue | Remove-Item -Force
        }
    }

    return $destino
}

function Remove-ProjetoDeTeste {
    param([string]$Caminho)
    if ($Caminho -and (Test-Path $Caminho)) {
        Remove-Item $Caminho -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-RunnerDoProjeto {
    <#
      Roda o tests\run-tests.ps1 do projeto instanciado e devolve
      @{ Codigo = <int>; Saida = <string> }.

      Em processo separado de proposito: o runner faz dot-source do proprio
      harness, e carregar aquele harness DENTRO desta suite sobrescreveria
      Test-Caso e os contadores da plataforma. Ja aconteceu classe parecida de
      colisao com variavel de caixa diferente.
    #>
    param([Parameter(Mandatory = $true)][string]$Projeto, [string[]]$Argumentos = @())
    $runner = Join-Path $Projeto 'tests\run-tests.ps1'
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File $runner @Argumentos 2>&1 | Out-String
        $codigo = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $anterior
    }
    return @{ Codigo = $codigo; Saida = $saida }
}

function Get-AstDoArquivo {
    <#
        Arvore de sintaxe de um .ps1, ou excecao.

        Arquivo que nao compila NAO pode ser pulado em silencio: pular reduz
        tanto as definicoes quanto os chamadores, e a reducao das definicoes e
        do lado do falso VERDE. Recusar e a resposta certa.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)
    $erros = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Caminho, [ref]$null, [ref]$erros)
    if ($erros -and $erros.Count -gt 0) {
        throw "Get-AstDoArquivo: '$Caminho' nao compila ($($erros[0].Message)). Um guarda nao pode pular arquivo ilegivel: pular esconde definicao e produz verde falso."
    }
    return $ast
}

function Get-ArquivosDePowerShell {
    param([Parameter(Mandatory = $true)][string]$Raiz)
    return @(Get-ChildItem $Raiz -Recurse -File -Include '*.ps1' |
             Where-Object { $_.FullName -notmatch '\\artifacts\\' })
}

function Find-FuncaoSemChamador {
    <#
        Devolve as funcoes definidas em -DirDefinicao que ninguem CHAMA em
        -DirReferencia. Lista vazia significa nenhuma orfa.

        Conta chamada pelo PARSER, nao mencao por regex, e a diferenca nao e
        cosmetica - e o terceiro conserto do mesmo guarda:

          1a versao: contava o texto cru. O comentario do proprio teste citava
             os simbolos pelo nome, entao reverter a correcao deixava o simbolo
             com referencias suficientes vindas do comentario do guarda.
          2a versao: despia comentario. Passou a errar por STRING LITERAL - e a
             instancia estava viva no repositorio: a MENSAGEM DE ASSERCAO de um
             caso de teste dizia "... Invoke-NativoLocal nao foi exercitada",
             entre aspas duplas. Desconectar as seis chamadas do bootstrap
             deixava definicao + literal = 2 referencias, uma delas descontada
             como definicao, e o guarda ficava VERDE sobre o defeito exato pelo
             qual foi escrito. Achado do qa-reviewer, com a aritmetica.
          3a versao, esta: um CommandAst e uma chamada. Um literal nao e. Nao ha
             lista de coisas-que-nao-contam para manter atualizada, porque a
             pergunta deixou de ser "o nome aparece?" e passou a ser "alguem
             chama?".

        De brinde, o parser enxerga funcao ANINHADA (que o regex de coluna zero
        nao via) e NAO enxerga definicao dentro de here-string de fixture (que o
        regex contava como codigo real).

        Limite declarado: chamada indireta - '& $nomeEmVariavel',
        'Invoke-Expression', 'Get-Command $x | & $_' - nao e vista como chamada.
        O erro cai do lado de acusar orfa a mais, que e ruidoso e nao silencioso.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$DirDefinicao,
        [Parameter(Mandatory = $true)][string]$DirReferencia
    )
    $defs = @(Get-ArquivosDePowerShell -Raiz $DirDefinicao)
    if ($defs.Count -eq 0) {
        throw "Find-FuncaoSemChamador: nenhum .ps1 em '$DirDefinicao' - sem isto o guarda passaria por vacuidade."
    }

    # Nome de comando no PowerShell e case-insensitive: 'get-texto' chama
    # 'Get-Texto'. Aqui a insensibilidade e a semantica da linguagem, nao um
    # acidente do comparador - diferente do caso dos campos, onde ela vinha de
    # '-notmatch' e escondia defeito.
    $chamados = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($a in (Get-ArquivosDePowerShell -Raiz $DirReferencia)) {
        $ast = Get-AstDoArquivo -Caminho $a.FullName
        foreach ($c in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $nome = $c.GetCommandName()
            if ($nome) { $null = $chamados.Add($nome) }
        }
    }

    $orfas = @()
    foreach ($arq in $defs) {
        $ast = Get-AstDoArquivo -Caminho $arq.FullName
        foreach ($f in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
            if (-not $chamados.Contains($f.Name)) { $orfas += ($arq.Name + ': ' + $f.Name) }
        }
    }
    return ,@($orfas)
}

function Get-CamposDeCobertura {
    <#
        Nomes declarados no bloco de cobertura de um detector: a atribuicao a
        '$cob' cujo lado direito e uma tabela hash.

        Isto era um regex de linha - '^\s{4,12}([A-Z][A-Za-z0-9]{2,})\s*=\s*\S' -
        e o qa-reviewer mostrou o tamanho do buraco: campo com indentacao de 13
        espacos ou mais ficava invisivel (os blocos aninhados de scan-gitignore
        e scan-dado-pessoal JA estavam fora da janela), assim como segundo campo
        depois de ';' na mesma linha, nome minusculo e nome de ate 2 letras.
        Na pratica os QUATRO campos de scan-dado-pessoal.ps1, declarados numa
        linha so com ';', nunca tinham sido verificados por ninguem.

        Era a mesma "lista branca que cobre menos do que promete" que este
        repositorio ja nomeou duas vezes - agora na metade da funcao que tinha
        ficado sem converter, enquanto a outra metade ja usava o parser.

        O AST nao tem janela nem lista: chave de tabela hash e chave de tabela
        hash. E como so olha atribuicao a '$cob', a tabela de PADROES de um
        detector nao e confundida com bloco de cobertura.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)
    $arv = Get-AstDoArquivo -Caminho $Caminho
    $nomes = @()
    foreach ($a in $arv.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ($a.Left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
        if ($a.Left.VariablePath.UserPath -ne 'cob') { continue }
        foreach ($h in $a.Right.FindAll({ $args[0] -is [System.Management.Automation.Language.HashtableAst] }, $true)) {
            foreach ($par in $h.KeyValuePairs) {
                if ($par.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $nomes += $par.Item1.Value
                }
            }
        }
    }
    return ,@($nomes)
}

function Get-MembrosLidos {
    <#
        Nomes de membro LIDOS num arquivo. Escrita nao conta.

        '$g.X = 0' tambem produz um MemberExpressionAst, entao a versao anterior
        dava por lido um campo que o consumidor apenas escrevia. Hoje isso e
        inalcancavel - os dois geradores de relatorio so leem -, e o
        qa-reviewer apontou que estar inalcancavel e diferente de estar
        declarado. Descontar o lado esquerdo das atribuicoes custa cinco linhas.
    #>
    param([Parameter(Mandatory = $true)][string]$Caminho)
    $arv = Get-AstDoArquivo -Caminho $Caminho
    $escritos = @{}
    foreach ($a in $arv.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ($a.Left -is [System.Management.Automation.Language.MemberExpressionAst]) {
            $escritos[$a.Left.Extent.Text] = $true
        }
    }
    $nomes = @()
    foreach ($m in $arv.FindAll({ $args[0] -is [System.Management.Automation.Language.MemberExpressionAst] }, $true)) {
        if ($escritos.ContainsKey($m.Extent.Text)) { continue }
        if ($m.Member -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $nomes += $m.Member.Value
        }
    }
    return ,@($nomes)
}

function Find-CampoSemLeitor {
    <#
        Devolve os campos declarados em blocos de cobertura (-DirDefinicao,
        arquivos que casem -FiltroDeArquivo) que ninguem LE em -Consumidor.

        Os DOIS lados usam o parser. Leitura e acesso a membro; declaracao e
        chave de tabela hash. As formas de verde falso que o qa-reviewer
        demonstrou morrem juntas:

          - TITULO de caso de teste fazendo o campo 'Commits' parecer lido.
            Titulo e literal; literal nao e acesso.
          - NOME IRMAO: 'ArquivosDeCIAusentes' cobrindo 'ArquivosDeCI'. Nome de
            membro no AST e o nome inteiro.
          - CAIXA, que vinha de '-notmatch' ser case-insensitive por acidente.
          - ESCRITA contando como leitura.
          - E, do lado da declaracao, a janela de indentacao e a lista branca de
            nome que deixavam campo inteiro fora da verificacao.

        Apertar isto achou a QUARTA orfa da subfase, 'Cobertos', e revelou que
        os quatro campos de scan-dado-pessoal.ps1 nunca tinham sido verificados.

        DOIS limites declarados, e o segundo custou uma rodada:

          - acesso dinamico ('$obj.$nome') nao e visto como leitura. Erra
            para o lado de acusar campo a mais.
          - so enxerga bloco atribuido a '$cob'. Isso NAO e so controle de
            falso positivo: e uma convencao, e o que ela deixa de fora e
            invisivel. O qa-reviewer achou a instancia viva - o resumo de
            disposicao de scan-excecoes.ps1 era devolvido direto como
            [pscustomobject], entao seus quatro campos ficavam fora do
            alcance, inclusive "Cobertos", que foi a orfa que este mesmo
            guarda achou na rodada 9. A alternativa - varrer todo objeto
            devolvido - foi medida e acusa 18 estruturas internas de
            trabalho, entao a saida foi declarar a convencao e aplica-la
            ao detector que escapava. **Detector novo tem de montar a
            cobertura em '$cob', ou sai do alcance sem aviso.**
    #>
    param(
        [Parameter(Mandatory = $true)][string]$DirDefinicao,
        [Parameter(Mandatory = $true)][string[]]$Consumidor,
        [string]$FiltroDeArquivo = 'scan-*.ps1'
    )
    $libs = @(Get-ChildItem $DirDefinicao -File -Filter $FiltroDeArquivo)
    if ($libs.Count -eq 0) {
        throw "Find-CampoSemLeitor: nenhum arquivo '$FiltroDeArquivo' em '$DirDefinicao' - sem isto o guarda passaria por vacuidade."
    }

    $arquivosConsumidores = @()
    foreach ($c in $Consumidor) {
        if (Test-Path $c -PathType Container) {
            foreach ($f in @(Get-ChildItem $c -File -Filter '*.ps1')) { $arquivosConsumidores += $f.FullName }
        } elseif (Test-Path $c -PathType Leaf) {
            $arquivosConsumidores += $c
        }
    }
    if ($arquivosConsumidores.Count -eq 0) {
        throw "Find-CampoSemLeitor: nenhum consumidor legivel - todo campo seria acusado, e o guarda diria a coisa certa pela razao errada."
    }

    # Acesso a membro no PowerShell e case-insensitive por semantica da
    # linguagem: '$x.cobertos' le 'Cobertos'.
    $lidos = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($c in $arquivosConsumidores) {
        foreach ($n in (Get-MembrosLidos -Caminho $c)) { $null = $lidos.Add($n) }
    }

    $semLeitor = @()
    foreach ($lib in $libs) {
        foreach ($campo in (Get-CamposDeCobertura -Caminho $lib.FullName)) {
            if (-not $lidos.Contains($campo)) { $semLeitor += ($lib.Name + ': ' + $campo) }
        }
    }
    return ,@($semLeitor)
}
