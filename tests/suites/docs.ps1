<#
.SYNOPSIS
    Suite de testes: Estrutura e documentacao.

.DESCRIPTION
    Os arquivos de que a portabilidade depende: STATE, ADRs, docs essenciais.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite docs

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite docs"
}

Test-Caso "arquivos essenciais do OS existem" {
    $esperados = @('CLAUDE.md', 'README.md', 'CHANGELOG.md', '.gitignore',
                   'docs\STATE.md', 'docs\ARCHITECTURE.md', 'docs\SETUP.md', 'docs\VISION.md',
                   'scripts\bootstrap.ps1')
    foreach ($f in $esperados) {
        Assert-True (Test-Path (Join-Path $OsRoot $f)) "ausente: $f"
    }
}

Test-Caso "existe pelo menos um ADR e todos seguem o padrao de nome" {
    $adrs = Get-ChildItem (Join-Path $OsRoot 'docs\decisions') -Filter '*.md' -ErrorAction SilentlyContinue
    Assert-True ($adrs.Count -ge 1) "nenhum ADR encontrado"
    foreach ($a in $adrs) {
        Assert-True ($a.Name -match '^ADR-\d{4}-[a-z0-9-]+\.md$') "nome fora do padrao: $($a.Name)"
    }
}

Test-Caso "ADRs tem Status e Contexto" {
    $adrs = Get-ChildItem (Join-Path $OsRoot 'docs\decisions') -Filter 'ADR-*.md'
    foreach ($a in $adrs) {
        $txt = Get-Texto $a.FullName
        Assert-True ($txt -match '(?i)\*\*Status:\*\*') "$($a.Name): sem campo Status"
        Assert-True ($txt -match '(?i)##\s*Contexto') "$($a.Name): sem secao Contexto"
    }
}

Test-Caso "nenhum placeholder {{...}} escapou para fora de templates/" {
    # Placeholder em templates/ e correto. Fora de la, e bug.
    #
    # Mas documentacao *sobre* um placeholder sempre o cita entre backticks
    # (a tabela da skill new-project, o CHANGELOG explicando uma correcao).
    # Placeholder ESQUECIDO aparece cru, sem backtick. A distincao e essa, e
    # e mais precisa que abrir excecao por arquivo.
    $cru = '(?<!`)\{\{[A-Z_]+\}\}(?!`)'
    $suspeitos = Get-ChildItem $OsRoot -Recurse -File -Include '*.md', '*.json', '*.yaml' -ErrorAction SilentlyContinue |
        # 'artifacts/' fica fora porque e GERADO e ignorado pelo Git: o
        # diff-report cita o diff do template, placeholders inclusive, e isso
        # nao e placeholder esquecido em arquivo versionado - e o relatorio
        # fazendo o trabalho dele. Sem esta excecao, gerar evidencia da
        # revisao derrubava um teste de estrutura.
        # '.claude\worktrees\' idem: worktrees de agente, copias ignoradas do repo.
        Where-Object { $_.FullName -notmatch '\\templates\\' -and $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\artifacts\\' -and $_.FullName -notmatch '\\\.claude\\worktrees\\' } |
        Where-Object { (Get-Texto $_.FullName) -match $cru }
    Assert-True ($suspeitos.Count -eq 0) ("placeholder nao substituido em: " + (($suspeitos | ForEach-Object { $_.Name }) -join ', '))
}

Test-Caso "excecao de dado sensivel e CAMPO, nao comentario, e aponta arquivo que existe" {
    # Achado do security-reviewer na 2.3: 'dados_sensiveis: false' com a
    # excecao explicada apenas em comentario. Comentario nenhuma ferramenta
    # le, e o campo legivel por maquina afirmava o oposto do que o
    # repositorio continha. Aqui nao houve subverificacao porque a
    # criticidade alta ja forcava qa+security - mas num projeto de
    # criticidade media a mesma prosa produziria rigor menor.
    $y = Get-Texto (Join-Path $OsRoot 'project.yaml')
    Assert-True ($y -match '(?m)^\s*dados_sensiveis_excecoes:') `
        "o manifesto nao declara as excecoes de dado sensivel como campo"
    $caminhos = @([regex]::Matches($y, '(?m)^\s*-\s+caminho:\s*"([^"]+)"') |
                  ForEach-Object { $_.Groups[1].Value })
    Assert-True ($caminhos.Count -ge 1) "a lista de excecoes esta vazia; remova o campo ou declare a excecao"
    foreach ($c in $caminhos) {
        $abs = Join-Path $OsRoot ($c -replace '/', '\')
        # -PathType Leaf: 'Test-Path' sem isso devolve verdadeiro para
        # DIRETORIO, e era o unico guarda contra 'caminho: "docs"' virar
        # allowlist de arvore inteira. Achado dos dois revisores.
        Assert-True (Test-Path $abs -PathType Leaf) "excecao declarada tem de apontar para um ARQUIVO existente, nao diretorio: $c"
        # Excecao sem natureza e sem status e so um caminho solto.
        Assert-True ($y -match 'natureza:') "excecao sem campo 'natureza'"
        Assert-True ($y -match '(?m)^\s+status:') "excecao sem campo 'status'"
    }
}

Test-Caso "excecao pendente nao pode se declarar aceita - o manifesto nao decide pela mantenedora" {
    # Achado do security-reviewer, e o perigo era concreto: o manifesto
    # escrevia 'decisao: "mantido em repositorio privado"' - afirmando decisao
    # tomada - enquanto o STATE.md diz textualmente "Nada foi feito" e que a
    # escolha e da Emmily.
    #
    # Isso importa porque o STATE preve este campo passar a ser lido pelo
    # detector de dado pessoal para reclassificar o caminho para BAIXA. Com a
    # contradicao de pe, o scanner silenciaria automaticamente um achado que
    # ninguem decidiu aceitar - numa plataforma de criticidade alta que
    # governa outros repositorios, esse e o modo de falha mais caro possivel.
    $y = Get-Texto (Join-Path $OsRoot 'project.yaml')
    $state = Get-Texto (Join-Path $OsRoot 'docs\STATE.md')

    $status = @([regex]::Matches($y, '(?m)^\s+status:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    Assert-True ($status.Count -ge 1) "nenhuma excecao declara status"

    # O manifesto nao pode afirmar aceitacao enquanto o STATE registra que a
    # decisao nao foi tomada.
    $stateDizPendente = ($state -match '(?i)nada foi feito')
    if ($stateDizPendente) {
        foreach ($s in $status) {
            Assert-True ($s -notmatch '(?i)aceita|aprovad|decidid|mantido') `
                ("o manifesto declara status '" + $s + "' enquanto o STATE.md diz que nada foi feito")
        }
    }
    # E enquanto houver excecao pendente, nenhum detector pode ler o campo
    # para reclassificar: se algum ler, este teste tem de ser revisto junto.
    $pendentes = @($status | Where-Object { $_ -match '(?i)pendente' })
    if ($pendentes.Count -gt 0) {
        $libs = Get-ChildItem (Join-Path $OsRoot 'scripts\lib') -Filter '*.ps1' -ErrorAction SilentlyContinue
        foreach ($l in $libs) {
            Assert-True ((Get-Texto $l.FullName) -notmatch 'dados_sensiveis_excecoes') `
                ("$($l.Name) le dados_sensiveis_excecoes com excecao PENDENTE: reclassificaria um achado que ninguem aceitou")
        }
    }
}

Test-Caso "a contagem de testes declarada no STATE bate com o disco" {
    # Existia em tres lugares com tres numeros diferentes - STATE (duas
    # vezes), CHANGELOG e ADR - e todos os tres estavam errados, porque a
    # contagem muda a cada teste novo e nenhum deles era conferido. O
    # qa-reviewer achou a divergencia; o teste 'manifesto, STATE e CHANGELOG
    # nao divergem' confere versao, fase e checkpoint, e passava verde por
    # cima disto.
    #
    # A contagem passou a viver num lugar so, o cabecalho do STATE, e aqui.
    # Numero repetido em prosa e numero que envelhece.
    $state = Get-Texto (Join-Path $OsRoot 'docs\STATE.md')
    $emDisco = (Select-String -Path (Join-Path $OsRoot 'tests\suites\*.ps1') -Pattern '^Test-Caso ').Count
    Assert-True ($emDisco -ge 100) "esperava pelo menos 100 casos em disco, achei $emDisco"
    $m = [regex]::Match($state, '(?m)^\-\s+\*\*Testes:\*\*\s+(\d+)/(\d+)\s+passando')
    Assert-True ($m.Success) "o cabecalho do STATE nao declara '- **Testes:** N/N passando'"
    Assert-True ([int]$m.Groups[1].Value -eq $emDisco) `
        ("STATE declara " + $m.Groups[1].Value + " testes; em disco ha " + $emDisco)
    Assert-True ($m.Groups[1].Value -eq $m.Groups[2].Value) `
        "o STATE declara execucao com falha; corrija os testes antes de registrar"
}

Test-Caso "a contagem de testes aparece UMA vez no STATE, e so no cabecalho" {
    # Quarta reincidencia da mesma classe, e na quarta as duas copias erradas
    # entraram no MESMO commit que o guarda-corpo devia proteger: o teste
    # anterior conferia apenas o cabecalho contra o disco, e nao tinha como
    # pegar copia em prosa. O remedio que esta plataforma ja adotou uma vez e
    # REMOVER o numero, nao corrigi-lo - corrigir envelhece de novo.
    #
    # A regra e precisa de proposito: o numero CORRENTE nao pode aparecer duas
    # vezes. Numero historico de subfase fechada ('36/36' na 2.0) e registro de
    # um momento e nao envelhece, entao continua permitido - ele e diferente do
    # corrente. Se um dia coincidirem, este caso acusa; e um falso positivo
    # raro, e olhar para ele nao faz mal.
    $casos = (Select-String -Path (Join-Path $OsRoot 'tests\suites\*.ps1') -Pattern '^Test-Caso ').Count
    $txt = Get-Texto (Join-Path $OsRoot 'docs\STATE.md')
    $padrao = ('{0}/{1}' -f $casos, $casos)
    $ocorrencias = @([regex]::Matches($txt, [regex]::Escape($padrao)))
    Assert-True ($ocorrencias.Count -eq 1) `
        ("a contagem corrente '$padrao' aparece " + $ocorrencias.Count + " vez(es) no STATE.md. " +
         "Ela vive SO no cabecalho: remova as outras, nao as corrija - numero em prosa envelhece.")

    # E a que existe tem de ser a do cabecalho, nao uma copia perdida no meio.
    $cab = @([regex]::Matches($txt, ('(?m)^\- \*\*Testes:\*\* ' + [regex]::Escape($padrao))))
    Assert-True ($cab.Count -eq 1) "a contagem corrente nao esta na linha de cabecalho do STATE.md"
}

Test-Caso "STATE.md declara fase e proximo passo" {
    $txt = Get-Texto (Join-Path $OsRoot 'docs\STATE.md')
    Assert-True ($txt -match '(?i)Fase atual') "STATE.md nao declara a fase atual"
    Assert-True ($txt -match '(?i)##\s*Pr.ximo passo') "STATE.md nao declara o proximo passo"
}

# =============================================================================

# =============================================================================
# Manifesto da propria plataforma
# =============================================================================

$ManifestoOs = Join-Path $OsRoot 'project.yaml'

function Get-CampoYaml {
    <#
      Le UM campo escalar do manifesto. Duas regras, e as duas nasceram de
      defeito medido na subfase 2.6:

      1. O VALOR TEM DE ESTAR NA MESMA LINHA DA CHAVE. A versao anterior usava
         '\s*' depois dos dois-pontos, e '\s' inclui quebra de linha: uma chave
         de BLOCO ('hooks:' com o mapa embaixo) capturava a primeira linha do
         bloco como se fosse o valor. Foi assim que 'hooks' passou a valer
         'pre_push:' e o caso morreu tentando converter isso para inteiro.

      2. NOME AMBIGUO LANCA, em vez de devolver a primeira ocorrencia. Quando a
         2.6 criou 'verificacao.hooks', passaram a existir DUAS chaves 'hooks'
         no manifesto - e um leitor por NOME entrega a de cima para quem pede a
         de baixo, em silencio. E o mesmo fail-open que o leitor do doctor
         fechou na 2.4 ("bloco irmao satisfazendo o caminho pedido"), vivo aqui
         dentro do harness que deveria pegar esse tipo de coisa.

      -Bloco limita a busca a um bloco de topo ('plugin', 'verificacao'), que e
      o mais perto de caminho pontuado que este leitor de teste precisa ter.
    #>
    param([string]$Texto, [string]$Campo, [string]$Bloco)

    $alvo = $Texto
    if ($Bloco) {
        $mb = [regex]::Match($Texto, ('(?ms)^' + [regex]::Escape($Bloco) + ':\r?\n(.*?)(?=^\S|\z)'))
        if (-not $mb.Success) { return $null }
        $alvo = $mb.Groups[1].Value
    }

    # '\r?$' e nao '$': no .NET, '$' com (?m) casa so antes de '\n'. Num checkout
    # com CRLF (o .gitattributes fixa eol=crlf para .ps1, entao todo literal de
    # varias linhas deste arquivo ganha '\r' num clone novo) a linha 'hooks: 0\r'
    # nao casava e o leitor devolvia $null. Passava na maquina onde o arquivo
    # tinha ficado em LF e falhava em clone limpo - achado pela certificacao do
    # programa vNext (2026-10-08), que roda a suite numa worktree recem-criada.
    $rx = "(?m)^[ \t]*$([regex]::Escape($Campo)):[ \t]*`"?([^`"#\r\n]+?)`"?[ \t]*(#[^\r\n]*)?\r?$"
    $ms = @([regex]::Matches($alvo, $rx))
    if ($ms.Count -eq 0) { return $null }
    if ($ms.Count -gt 1) {
        $onde = ''
        if ($Bloco) { $onde = " no bloco '$Bloco'" }
        throw "Get-CampoYaml: '$Campo' aparece $($ms.Count) vezes$onde. Devolver a primeira seria escolher por posicao; use -Bloco para desambiguar."
    }
    return $ms[0].Groups[1].Value.Trim()
}

Test-Caso "leitor: chave de BLOCO nao vira valor, e o bloco irmao nao responde pelo outro" {
    # Os dois defeitos reais que este leitor teve, pinados. Eles apareceram
    # juntos na 2.6, quando 'verificacao.hooks' passou a existir ao lado de
    # 'plugin.hooks':
    #
    #   1. '\s*' atravessava a quebra de linha, e 'hooks:' (chave de bloco)
    #      capturava 'pre_push:' da linha seguinte como se fosse o valor;
    #   2. a busca era por NOME, entao quem pedia 'hooks' recebia a primeira
    #      ocorrencia - o bloco irmao respondendo pelo caminho pedido, que e o
    #      mesmo fail-open que o leitor do doctor fechou na 2.4.
    $yaml = @"
plugin:
  hooks: 0
  skills: 7
verificacao:
  hooks:
    pre_push:
      - "doctor"
"@
    # 1. chave de bloco NAO devolve a linha de baixo como valor.
    $v = Get-CampoYaml $yaml 'hooks' -Bloco 'verificacao'
    Assert-True ($null -eq $v) "chave de bloco devolveu valor: '$v'"

    # 2. o bloco pedido e o que responde - e o par positivo que impede uma
    #    implementacao que devolvesse $null para tudo de passar no item 1.
    #    Nas DUAS convencoes de fim de linha, explicitamente: o literal acima
    #    herda o fim de linha do checkout, e o caso passava em LF e falhava em
    #    CRLF (clone limpo). Agora ele nao depende de como o arquivo foi baixado.
    $lf = $yaml -replace "`r`n", "`n"
    $crlf = $lf -replace "`n", "`r`n"
    foreach ($par in @(@('LF', $lf), @('CRLF', $crlf))) {
        Assert-True ((Get-CampoYaml $par[1] 'hooks' -Bloco 'plugin') -eq '0') `
            ("o bloco 'plugin' nao respondeu com o proprio valor em " + $par[0])
        Assert-True ((Get-CampoYaml $par[1] 'skills' -Bloco 'plugin') -eq '7') `
            ("o bloco 'plugin' nao respondeu 'skills' em " + $par[0])
        Assert-True ($null -eq (Get-CampoYaml $par[1] 'hooks' -Bloco 'verificacao')) `
            ("chave de bloco devolveu valor em " + $par[0])
    }
    Assert-True ($crlf.Contains("`r`n") -and -not $lf.Contains("`r")) "as duas fixtures nao diferem - o caso nao provaria nada"

    # 3. nome ambiguo LANCA, em vez de escolher por posicao.
    #
    # A fixture da ambiguidade e OUTRA de proposito, e a primeira versao deste
    # caso errou aqui: no YAML acima as duas chaves 'hooks' NAO sao ambiguas
    # para este leitor, porque uma delas e chave de BLOCO e a regra 1 ja a
    # torna invisivel - sobra uma so, e nao ha o que desempatar. A ambiguidade
    # de verdade e dois ESCALARES com o mesmo nome em blocos diferentes.
    $ambiguo = @"
plugin:
  hooks: 0
verificacao:
  hooks: 2
"@
    $lancou = $false
    try { $null = Get-CampoYaml $ambiguo 'hooks' } catch { $lancou = $true }
    Assert-True $lancou "nome ambiguo nao lancou: o leitor escolheu uma das duas chaves por posicao"

    # E o par: com o bloco, a MESMA fixture responde sem lancar.
    Assert-True ((Get-CampoYaml $ambiguo 'hooks' -Bloco 'verificacao') -eq '2') `
        "com -Bloco o leitor devia responder sem ambiguidade"
}

Test-Caso "a plataforma tem o proprio project.yaml" {
    # Os dois revisores independentes apontaram a ausencia na subfase 2.2: uma
    # plataforma que exige manifesto dos projetos e nao declara o proprio esta
    # se dando uma excecao que nao concede a ninguem.
    Assert-True (Test-Path $ManifestoOs) "a plataforma nao tem project.yaml"
}

Test-Caso "o manifesto da plataforma usa o schema canonico, sem formato paralelo" {
    if (-not (Test-Path $ManifestoOs)) { return $true }
    $txt = Get-Texto $ManifestoOs
    foreach ($bloco in @('identidade:', 'classificacao:', 'versionamento:', 'verificacao:', 'execucao:', 'ambiente:', 'portfolio:', 'estado:')) {
        Assert-True ($txt -match [regex]::Escape($bloco)) "manifesto sem o bloco '$bloco' do schema"
    }
    Assert-True ($txt -notmatch '(?m)^\s*//') "usa '//' como comentario, que nao e YAML"
}

Test-Caso "a plataforma declara criticidade alta e o rigor derivado dela" {
    if (-not (Test-Path $ManifestoOs)) { return $true }
    $txt = Get-Texto $ManifestoOs
    Assert-True ((Get-CampoYaml $txt 'criticidade' -Bloco 'classificacao') -eq 'alta') "criticidade nao e 'alta'"
    Assert-True ((Get-CampoYaml $txt 'revisao_independente' -Bloco 'verificacao') -eq 'qa+security') `
        "criticidade alta exige revisao_independente qa+security (ADR-0007)"
}

Test-Caso "criticidade operacional e classificacao de dados sao coisas distintas" {
    if (-not (Test-Path $ManifestoOs)) { return $true }
    # Os dois campos sao INDEPENDENTES, e a exigencia e que o manifesto explique
    # por que cada um vale o que vale - nao que um deles tenha valor fixo.
    #
    # Este caso ja exigiu 'dados_sensiveis: false', com a justificativa de que o
    # codigo-fonte da plataforma nao contem dado corporativo. O
    # security-reviewer desmontou o raciocinio: o campo nao pergunta sobre o
    # codigo-fonte, pergunta sobre o repositorio, e o schema do template define
    # 'true se toca dado corporativo/pessoal de terceiro'. Este repositorio
    # toca, e a propria excecao declarada diz isso.
    $txt = Get-Texto $ManifestoOs
    Assert-True ($txt -match '(?i)criticidade OPERACIONAL') `
        "o manifesto nao explica que a criticidade e operacional, nao de dados"
    Assert-True ($txt -match '(?i)independentes') `
        "o manifesto nao declara que os dois campos sao independentes"
}

Test-Caso "excecao de dado sensivel declarada FORCA dados_sensiveis true" {
    # A regra mecanica que impede a contradicao de voltar: se ha excecao
    # declarada, o repositorio toca dado sensivel por definicao. Um booleano
    # 'false' com excecao logo abaixo e o manifesto mentindo para toda
    # ferramenta que le so o booleano - e rigor derivado de campo mentiroso e
    # rigor menor.
    if (-not (Test-Path $ManifestoOs)) { return $true }
    $txt = Get-Texto $ManifestoOs
    $temExcecao = ([regex]::Matches($txt, '(?m)^\s+-\s+caminho:\s*"')).Count -gt 0
    if ($temExcecao) {
        Assert-True ((Get-CampoYaml $txt 'dados_sensiveis' -Bloco 'classificacao') -eq 'true') `
            "ha excecao de dado sensivel declarada e dados_sensiveis diz 'false'"
    }
}

Test-Caso "excecao aprovada e COERENTE entre manifesto, scanner, politica e docs" {
    # A coerencia que importa e a da CATEGORIA: ela tem de ser uma categoria
    # que algum detector realmente emite. Um erro de digitacao ali faz a
    # excecao nao cobrir nada - falha para o lado seguro, mas EM SILENCIO, e o
    # relatorio passaria a bloquear sem ninguem entender por que.
    if (-not (Test-Path $ManifestoOs)) { return $true }
    $y = Get-Texto $ManifestoOs

    # ESCOPADO no bloco de excecoes. 'categoria' tambem existe em
    # 'identidade', e um padrao solto no arquivo inteiro pegava
    # 'categoria: "platform"' de la - o teste acusava que a plataforma nao
    # emite a categoria 'platform', que e verdade e nao era a pergunta.
    $bloco = [regex]::Match($y, '(?ms)^\s*dados_sensiveis_excecoes:\s*\r?\n(.*?)(?=^\s{0,2}[a-z_]+:|\z)')
    if (-not $bloco.Success) { return $true }
    $y = $bloco.Groups[1].Value

    $aceitas = @([regex]::Matches($y, '(?ms)-\s+caminho:\s*"([^"]+)".*?status:\s*"aceito-por-excecao"'))
    if ($aceitas.Count -eq 0) { return $true }   # sem excecao aceita, nada a conferir

    # 1. Todos os nove campos obrigatorios, e o caminho existe em disco.
    # 'caminho' abre a entrada da lista, entao vem prefixado por '- '. Os
    # outros oito sao campos indentados. Sem essa distincao o padrao nunca
    # casa com o primeiro campo - e o teste acusava campo ausente que estava
    # ali.
    Assert-True ($y -match '(?m)^\s+-\s+caminho:\s*"') "excecao aceita sem o campo obrigatorio 'caminho'"
    foreach ($c in @('categoria', 'natureza', 'justificativa', 'decisao',
                     'status', 'decidido_em', 'escopo', 'onde_esta_registrado')) {
        Assert-True ($y -match ('(?m)^\s+' + $c + ':\s*"')) "excecao aceita sem o campo obrigatorio '$c'"
    }
    foreach ($m in $aceitas) {
        $abs = Join-Path $OsRoot ($m.Groups[1].Value -replace '/', '\')
        Assert-True (Test-Path $abs -PathType Leaf) ("excecao aceita tem de apontar para um ARQUIVO existente, nao diretorio: " + $m.Groups[1].Value)
    }

    # 2. A categoria declarada e emitivel por algum detector.
    $fonteLibs = ''
    foreach ($l in (Get-ChildItem (Join-Path $OsRoot 'scripts\lib') -Filter '*.ps1')) {
        $fonteLibs += (Get-Texto $l.FullName)
    }
    foreach ($cat in @([regex]::Matches($y, '(?m)^\s+categoria:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })) {
        $emitivel = $fonteLibs.Contains($cat)
        if (-not $emitivel -and $cat.StartsWith('possivel ')) {
            $emitivel = $fonteLibs.Contains($cat.Substring(9))
        }
        Assert-True $emitivel ("categoria '" + $cat + "' nao e emitida por nenhum detector: a excecao nao cobriria nada, e em silencio")
    }

    # 3. O escopo e privado, e o registro aponta para um ADR que existe.
    Assert-True ($y -match '(?m)^\s+escopo:\s*"privado"') "excecao aceita com escopo diferente de 'privado'"
    foreach ($reg in @([regex]::Matches($y, '(?m)^\s+onde_esta_registrado:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })) {
        $adr = [regex]::Match($reg, 'ADR-\d{4}[A-Za-z0-9\-]*\.md')
        Assert-True ($adr.Success) ("onde_esta_registrado nao aponta para um arquivo de ADR: " + $reg)
        Assert-True (Test-Path (Join-Path $OsRoot ('docs\decisions\' + $adr.Value))) `
            ("o ADR citado pela excecao nao existe: " + $adr.Value)
    }

    # 4. O mecanismo esta documentado nos quatro lugares que o consomem.
    Assert-True ((Get-Texto (Join-Path $OsRoot 'docs\VERIFICATION-POLICY.md')) -match 'ADR-0010') `
        "a politica de verificacao nao cita o ADR-0010"
    Assert-True ((Get-Texto (Join-Path $OsRoot 'docs\STATE.md')) -match 'ADR-0010') `
        "o STATE nao cita o ADR-0010"
    Assert-True ((Get-Texto (Join-Path $OsRoot 'skills\security\SKILL.md')) -match 'ParaPublicacao') `
        "a skill /os:security nao documenta o modo publicacao"
    Assert-True ((Get-Texto (Join-Path $OsRoot 'scripts\security-scan.ps1')) -match 'ParaPublicacao') `
        "o scanner nao tem o modo publicacao"
    # E o template distribui o campo, senao a plataforma governa por regra que
    # ela mesma nao entrega.
    Assert-True ((Get-Texto (Join-Path $Template 'project.yaml')) -match 'dados_sensiveis_excecoes') `
        "o schema do template nao tem o campo de excecao"
}

Test-Caso "o manifesto da plataforma nao usa campo de classificacao que o template nao tem" {
    # 'Nao existe formato paralelo para a plataforma' e a primeira frase do
    # cabecalho do manifesto, e era exatamente o que passou a existir: o campo
    # 'dados_sensiveis_excecoes' nasceu na plataforma e nao no schema do
    # template. Consequencia concreta apontada pelo security-reviewer: projeto
    # governado que toque dado de terceiro nao tem onde declarar excecao, e o
    # /os:new-project nao pergunta.
    #
    # Este teste transforma a frase do cabecalho em regra verificada, em vez de
    # promessa em comentario.
    if (-not (Test-Path $ManifestoOs)) { return $true }
    $osTxt   = Get-Texto $ManifestoOs
    $tplTxt  = Get-Texto (Join-Path $Template 'project.yaml')

    function Get-ChavesDoBloco {
        param([string]$Yaml, [string]$Bloco)
        $m = [regex]::Match($Yaml, ('(?ms)^' + $Bloco + ':\r?\n(.*?)(?=^\S|\z)'))
        if (-not $m.Success) { return @() }
        return @([regex]::Matches($m.Groups[1].Value, '(?m)^  ([a-z_]+):') |
                 ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    }

    $doOs  = Get-ChavesDoBloco $osTxt  'classificacao'
    $doTpl = Get-ChavesDoBloco $tplTxt 'classificacao'
    Assert-True ($doOs.Count -ge 4)  "nao consegui ler as chaves de classificacao do manifesto da plataforma"
    Assert-True ($doTpl.Count -ge 4) "nao consegui ler as chaves de classificacao do template"

    $soNaPlataforma = @($doOs | Where-Object { $doTpl -notcontains $_ })
    Assert-True ($soNaPlataforma.Count -eq 0) `
        ("campo de classificacao que existe na plataforma e nao no template: " + ($soNaPlataforma -join ', '))
}

Test-Caso "a versao do manifesto bate com a tag mais recente" {
    if (-not (Test-Path (Join-Path $OsRoot '.git'))) { return $true }
    if (-not (Test-Path $ManifestoOs)) { return $true }
    $txt = Get-Texto $ManifestoOs
    $versao = Get-CampoYaml $txt 'versao' -Bloco 'identidade'
    Push-Location $OsRoot
    try {
        $tag = (git tag --sort=-v:refname | Select-Object -First 1)
    } finally { Pop-Location }
    if (-not $tag) { return $true }
    Assert-True ($tag -eq ("v" + $versao)) "manifesto diz $versao, mas a tag mais recente e $tag"
}

Test-Caso "o manifesto NAO afirma capacidade que ainda nao existe" {
    if (-not (Test-Path $ManifestoOs)) { return $true }
    # O modo de falha mais caro de um manifesto e prometer o que nao ha.
    # Cada declaracao aqui e conferida contra o disco.
    $txt = Get-Texto $ManifestoOs

    $ci = Get-CampoYaml $txt 'ci' -Bloco 'verificacao'
    $temWorkflow = Test-Path (Join-Path $OsRoot '.github\workflows')
    Assert-True (($ci -eq 'true') -eq $temWorkflow) `
        "ci declarado '$ci' mas .github/workflows $(if ($temWorkflow) { 'existe' } else { 'nao existe' })"

    $evals = Get-CampoYaml $txt 'evals' -Bloco 'verificacao'
    $casos = @(Get-ChildItem (Join-Path $OsRoot 'evals') -Recurse -File -Filter 'case.yaml' -ErrorAction SilentlyContinue)
    Assert-True (($evals -eq 'true') -eq ($casos.Count -gt 0)) `
        "evals declarado '$evals' mas ha $($casos.Count) caso(s) em evals/"

    $skillsDecl = [int](Get-CampoYaml $txt 'skills' -Bloco 'plugin')
    $skillsDisco = @(Get-ChildItem (Join-Path $OsRoot 'skills') -Directory -ErrorAction SilentlyContinue).Count
    Assert-True ($skillsDecl -eq $skillsDisco) "manifesto declara $skillsDecl skills, o disco tem $skillsDisco"

    $agentsDecl = [int](Get-CampoYaml $txt 'agents' -Bloco 'plugin')
    $agentsDisco = @(Get-ChildItem (Join-Path $OsRoot 'agents') -File -Filter '*.md' -ErrorAction SilentlyContinue).Count
    Assert-True ($agentsDecl -eq $agentsDisco) "manifesto declara $agentsDecl agents, o disco tem $agentsDisco"

    # -Bloco 'plugin' e obrigatorio desde a 2.6: 'hooks' existe tambem em
    # 'verificacao', e sao coisas DIFERENTES - hook de PLUGIN do Claude Code
    # contra a politica do hook de GIT. Sem o bloco, este caso leria a chave
    # errada e conferiria a existencia de hooks/hooks.json contra ela.
    $hooksDecl = [int](Get-CampoYaml $txt 'hooks' -Bloco 'plugin')
    $temHooks = Test-Path (Join-Path $OsRoot 'hooks\hooks.json')
    Assert-True (($hooksDecl -gt 0) -eq $temHooks) `
        "manifesto declara $hooksDecl hooks mas hooks/hooks.json $(if ($temHooks) { 'existe' } else { 'nao existe' })"
}

Test-Caso "manifesto, STATE e CHANGELOG nao divergem" {
    if (-not (Test-Path $ManifestoOs)) { return $true }
    # Foi exatamente o defeito que a retomada em contexto isolado achou na
    # Fase 1: o project.yaml dizia uma versao e o STATE outra.
    $man   = Get-Texto $ManifestoOs
    $state = Get-Texto (Join-Path $OsRoot 'docs\STATE.md')
    $chlog = Get-Texto (Join-Path $OsRoot 'CHANGELOG.md')

    $versao = Get-CampoYaml $man 'versao'
    Assert-True ($state -match [regex]::Escape($versao)) "o STATE.md nao menciona a versao $versao do manifesto"
    Assert-True ($chlog -match [regex]::Escape($versao)) "o CHANGELOG.md nao menciona a versao $versao"

    # A fase declarada no manifesto tem de aparecer no STATE.
    $fase = Get-CampoYaml $man 'fase'
    Assert-True ($fase -match '(?i)fase 2') "o manifesto nao declara a fase atual"
    Assert-True ($state -match '(?i)2 . Qualidade') "o STATE.md nao declara a Fase 2"

    $checkpoint = Get-CampoYaml $man 'ultimo_checkpoint'
    Assert-True ($state -match [regex]::Escape($checkpoint.Split(' ')[0])) `
        "o ultimo_checkpoint do manifesto nao aparece no STATE.md"

    # A contagem de SKILLS em prosa no STATE. Era o quarto ponto do achado 5
    # da primeira rodada da 2.5, e sobreviveu a ela: o STATE dizia "Skills: 6"
    # e anunciava 'doctor' como trabalho FUTURO enquanto o disco tinha 7, o
    # manifesto declarava 7 e o cabecalho declarava a subfase concluida. Este
    # caso ja conferia versao, fase e checkpoint, e passava verde por cima -
    # a mesma forma do defeito que ele foi escrito para pegar. Quem chega le
    # este arquivo primeiro, por ordem do CLAUDE.md.
    $skillsMan = [int](Get-CampoYaml $man 'skills')
    $mSkills = [regex]::Match($state, '(?m)^-\s+\*\*Skills:\*\*\s+(\d+)')
    Assert-True ($mSkills.Success) `
        "o STATE.md nao declara mais '- **Skills:** N' em prosa. Se a linha mudou de forma, este detector precisa acompanhar - detector que deixa de casar em silencio e o defeito que ele existe para pegar"
    Assert-True ([int]$mSkills.Groups[1].Value -eq $skillsMan) `
        "o STATE.md diz $($mSkills.Groups[1].Value) skills em prosa e o manifesto declara $skillsMan"
}
