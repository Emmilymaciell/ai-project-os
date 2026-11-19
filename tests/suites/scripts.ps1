<#
.SYNOPSIS
    Suite de testes: Sintaxe dos scripts.

.DESCRIPTION
    O codigo deterministico da plataforma roda no PowerShell 5.1 desta maquina.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite scripts

.NOTES
    TESTE-CITA-PADROES-PROIBIDOS - esta suite cita '??' e '-AsHashtable' para
    poder procura-los nos outros scripts, e por isso se isenta da propria
    verificacao. O marcador e lido pelo teste; nao remova sem entender.

    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite scripts"
}

Test-Caso "todos os .ps1 tem sintaxe valida" {
    # .claude\worktrees\ guarda worktrees de agente (outras copias do repo,
    # ignoradas pelo Git): contariam cada script varias vezes.
    $arquivos = Get-ChildItem $OsRoot -Recurse -File -Filter '*.ps1' |
                Where-Object { $_.FullName -notmatch '\\\.git\\|\\\.claude\\worktrees\\' }
    Assert-True ($arquivos.Count -ge 3) "esperava pelo menos 3 scripts, achei $($arquivos.Count)"
    foreach ($a in $arquivos) {
        $erros = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $a.FullName -Raw), [ref]$erros)
        Assert-True ($erros.Count -eq 0) "$($a.Name): $($erros[0].Message)"
    }
}

Test-Caso "scripts .ps1 nao usam sintaxe de PowerShell 7 (a maquina tem 5.1)" {
    # Um arquivo precisa CITAR os padroes proibidos para poder procura-los, e
    # se auto-acusaria. A excecao e declarada pelo proprio arquivo, com o
    # marcador abaixo - nao por nome de arquivo, que envelhece a cada
    # refatoracao. Foi exatamente o que aconteceu quando o monolito de testes
    # virou suites: a excecao apontava para run-tests.ps1 e o citador passou a
    # ser este arquivo.
    $marcador = 'TESTE-CITA-PADROES-PROIBIDOS'
    $todos = Get-ChildItem $OsRoot -Recurse -File -Filter '*.ps1' |
             Where-Object { $_.FullName -notmatch '\\\.git\\|\\\.claude\\worktrees\\' }
    $isentos = @($todos | Where-Object { (Get-Texto $_.FullName) -match $marcador })
    # Marcador solto viraria porta para silenciar problema real.
    Assert-True ($isentos.Count -le 1) `
        ("mais de um arquivo se declara isento: " + (($isentos | ForEach-Object { $_.Name }) -join ', '))
    $arquivos = $todos | Where-Object { $isentos -notcontains $_ }
    Assert-True ($arquivos.Count -ge 3) "esperava pelo menos 3 scripts a verificar, achei $($arquivos.Count)"
    foreach ($a in $arquivos) {
        $txt = Get-Texto $a.FullName
        Assert-True ($txt -notmatch '\?\?') "$($a.Name): usa '??', que nao existe no 5.1"
        Assert-True ($txt -notmatch '-AsHashtable') "$($a.Name): usa -AsHashtable, que nao existe no 5.1"
    }
}

function Get-BytesNaoAscii {
    <#
      Bytes acima de 127. UMA definicao, usada pelo guarda e pelo par positivo.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    return @($Bytes | Where-Object { $_ -gt 127 })
}

function Get-BytesDeControle {
    <#
      Caractere de controle que nao tem o que fazer num .ps1: tudo abaixo de
      0x20 mais o 0x7F (DEL), menos TAB, CR e LF.

      Isto e FUNCAO, e nao expressao repetida, porque os dois revisores
      acharam o mesmo defeito na primeira versao: o caso positivo COPIAVA o
      predicado, entao mutar o guarda real - '-lt 32' para '-lt 0' - nao
      derrubava nada. O caso testava a propria copia.

      O registro desta casa ja prescrevia o conserto, e eu nao o apliquei:
      "a causa raiz era o detector viver DENTRO do caso de teste", e "o
      conserto que funcionou foi tirar a regra de dentro do caso e dar par
      proprio a ela".
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    return @($Bytes | Where-Object { ($_ -lt 32 -or $_ -eq 127) -and $_ -ne 9 -and $_ -ne 10 -and $_ -ne 13 })
}

function Get-CrSoltos {
    <#
      Posicoes de CR (0x0D) que NAO sao seguidos de LF.

      O guarda acima PERMITE 0x0D, e tem de permitir: CRLF e fim de linha
      legitimo. Mas um CR sozinho, no meio de uma linha, nunca e fim de linha
      - e byte que entrou dentro de um literal.

      Isto nasceu de um defeito real na subfase 2.7. O '\r' de
      'artifacts\review' passou por uma camada de ferramenta que interpretou
      escapes e virou 0x0D DE VERDADE dentro da string. O caminho ficou
      'artifacts<CR>eview\security-report.md', e o arquivo continuou ASCII,
      continuou sem caractere de controle proibido, continuou com sintaxe
      valida e a suite continuou verde - enquanto o portao de seguranca que
      aquela linha sustentava simplesmente nunca encontrava o relatorio.

      E a mesma classe do 0x08 da 2.6, e a licao e a mesma: uma regra errada
      falha; uma regra DESARMADA passa.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $soltos = @()
    for ($i = 0; $i -lt $Bytes.Count; $i++) {
        if ($Bytes[$i] -ne 13) { continue }
        if ($i -eq ($Bytes.Count - 1) -or $Bytes[$i + 1] -ne 10) { $soltos += $i }
    }
    return @($soltos)
}

Test-Caso "scripts .ps1 sao ASCII (evita mojibake no PowerShell 5.1)" {
    $arquivos = Get-ChildItem $OsRoot -Recurse -File -Filter '*.ps1' |
                Where-Object { $_.FullName -notmatch '\\\.git\\|\\\.claude\\worktrees\\' }
    foreach ($a in $arquivos) {
        $bytes = [System.IO.File]::ReadAllBytes($a.FullName)
        $naoAscii = Get-BytesNaoAscii $bytes
        Assert-True ($naoAscii.Count -eq 0) "$($a.Name): tem $($naoAscii.Count) byte(s) nao-ASCII"

        # ASCII nao e o mesmo que IMPRIMIVEL, e a diferenca custou uma rodada.
        #
        # Um caractere 0x08 (backspace) entrou dentro de uma regex desta suite
        # - um heredoc interpretou '\b' como escape em vez de passar as duas
        # letras. O padrao virou 'Start-Process<BS>[^#]*powershell' e deixou de
        # casar com qualquer coisa: o guarda que ele sustentava passou a estar
        # desarmado, em silencio, com a suite verde. E este caso aqui nao viu
        # nada, porque 0x08 e MENOR que 127.
        #
        # TAB, CR e LF sao os unicos controles legitimos num .ps1.
        # 0x7F (DEL) tambem e controle, e passava nos DOIS guardas: o de
        # ASCII recusa > 127 e este recusava < 32, entao exatamente 127
        # escapava pelo meio. Achado dos dois revisores na sexta rodada.
        $controle = Get-BytesDeControle $bytes
        Assert-True ($controle.Count -eq 0) `
            "$($a.Name): tem $($controle.Count) caractere(s) de controle fora de TAB/CR/LF - regex ou string pode estar desarmada em silencio"

        # E o CR SOLTO, que escapa dos dois guardas acima por ser um byte de
        # fim de linha legitimo em outro contexto. Ver 'Get-CrSoltos'.
        $cr = Get-CrSoltos $bytes
        Assert-True ($cr.Count -eq 0) `
            "$($a.Name): tem $($cr.Count) CR solto (sem LF depois), na(s) posicao(oes) $($cr -join ', ') - byte entrou dentro de um literal"
    }
}

# =============================================================================

Test-Caso "guardas de byte: ACUSAM amostra plantada, e nao passam por vacuidade" {
    # A politica 4.1 exige que todo detector prove que ACUSA. Os dois guardas
    # acima varrem o repositorio inteiro e, com ele limpo, dao zero - entao
    # trocar '-lt 32' por '-lt 0' os desligaria sem derrubar nada.
    #
    # E a falha que a propria 2.6 descreve: um caractere 0x08 desarmou uma
    # regex e a suite ficou verde. O conserto daquilo nasceu com o mesmo
    # defeito, e foi o qa-reviewer quem apontou.
    #
    # As amostras sao BYTES plantados num arquivo temporario, nunca em script
    # do repositorio.
    #
    # E o caso CHAMA as mesmas funcoes que os guardas chamam. A primeira
    # versao copiava o predicado, e os dois revisores acharam isso
    # independentemente: mutar o guarda real nao derrubava o caso, porque
    # ele testava a propria copia.
    $dir = Join-Path $env:TEMP ("bytes-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    try {
        $casos = @(
            @{ Nome = 'backspace'; Byte = 8 },
            @{ Nome = 'DEL';       Byte = 127 },
            @{ Nome = 'NUL';       Byte = 0 },
            @{ Nome = 'ESC';       Byte = 27 }
        )
        foreach ($c in $casos) {
            $f = Join-Path $dir ("sujo-" + $c.Nome + ".ps1")
            $b = [System.Text.Encoding]::ASCII.GetBytes("# amostra`n") + [byte]$c.Byte + [System.Text.Encoding]::ASCII.GetBytes("`n")
            [System.IO.File]::WriteAllBytes($f, $b)
            $lidos = [System.IO.File]::ReadAllBytes($f)
            $achou = @(Get-BytesDeControle $lidos)
            Assert-True ($achou.Count -eq 1) `
                "a regra de controle NAO acusou o byte $($c.Byte) ($($c.Nome)): achou $($achou.Count)"
        }

        # Par negativo: TAB, CR e LF sao legitimos e nao podem ser acusados.
        $limpo = Join-Path $dir 'limpo.ps1'
        [System.IO.File]::WriteAllBytes($limpo, [System.Text.Encoding]::ASCII.GetBytes("# com tab`tfim`r`n"))
        $bytesLimpo = [System.IO.File]::ReadAllBytes($limpo)
        $falso = @(Get-BytesDeControle $bytesLimpo)
        Assert-True ($falso.Count -eq 0) "a regra acusou TAB, CR ou LF, que sao legitimos: $($falso.Count) byte(s)"

        # E o de ASCII, pela mesma razao: ele tambem nunca teve positivo.
        $acentuado = Join-Path $dir 'acento.ps1'
        [System.IO.File]::WriteAllBytes($acentuado, [byte[]](0x23, 0x20, 0xC3, 0xA1, 0x0A))
        $naoAscii = @(Get-BytesNaoAscii ([System.IO.File]::ReadAllBytes($acentuado)))
        Assert-True ($naoAscii.Count -eq 2) "a regra de ASCII NAO acusou byte acentuado: achou $($naoAscii.Count)"

        # E o do CR solto, com o defeito REAL da 2.7 reproduzido byte a byte:
        # 'artifacts' + 0x0D + 'eview'. Note que este mesmo arquivo passa nos
        # DOIS guardas acima - e exatamente por isso ele precisa de um terceiro.
        $comCr = Join-Path $dir 'cr-solto.ps1'
        [System.IO.File]::WriteAllBytes($comCr,
            ([System.Text.Encoding]::ASCII.GetBytes("`$p = 'artifacts") +
             [byte]13 +
             [System.Text.Encoding]::ASCII.GetBytes("eview\x.md'`n")))
        $bytesCr = [System.IO.File]::ReadAllBytes($comCr)
        Assert-True (@(Get-CrSoltos $bytesCr).Count -eq 1) `
            "a regra NAO acusou o CR solto: achou $(@(Get-CrSoltos $bytesCr).Count)"
        Assert-True (@(Get-BytesDeControle $bytesCr).Count -eq 0) `
            "o guarda de controle acusou o CR solto - entao o guarda novo seria redundante, e esta assercao e que esta errada"
        Assert-True (@(Get-BytesNaoAscii $bytesCr).Count -eq 0) `
            "o guarda de ASCII acusou o CR solto - mesma observacao"

        # Par negativo do guarda novo: CRLF de verdade nao pode ser acusado,
        # senao ele reprovaria todo arquivo com fim de linha do Windows.
        $crlf = Join-Path $dir 'crlf.ps1'
        [System.IO.File]::WriteAllBytes($crlf, [System.Text.Encoding]::ASCII.GetBytes("# uma`r`n# duas`r`n"))
        Assert-True (@(Get-CrSoltos ([System.IO.File]::ReadAllBytes($crlf))).Count -eq 0) `
            "a regra acusou CRLF legitimo"
    } finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

Test-Caso "toda suite de teste esta declarada na ordem do runner" {
    # Suite fora da lista $Ordem ainda roda (o runner anexa no fim), mas roda
    # na hora errada. Este teste pega a deriva entre a pasta e a lista.
    $runner = Get-Texto (Join-Path $OsRoot 'tests\run-tests.ps1')
    $declaradas = ([regex]::Match($runner, "(?m)^\`$Ordem\s*=\s*@\((.+?)\)")).Groups[1].Value
    $declaradas = [regex]::Matches($declaradas, "'([a-z-]+)'") | ForEach-Object { $_.Groups[1].Value }
    Assert-True ($declaradas.Count -ge 6) "nao consegui ler a lista `$Ordem do runner"

    $emDisco = Get-ChildItem (Join-Path $OsRoot 'tests\suites') -Filter '*.ps1' |
               ForEach-Object { $_.BaseName }

    $naoDeclaradas = $emDisco | Where-Object { $declaradas -notcontains $_ }
    Assert-True ($naoDeclaradas.Count -eq 0) ("suite em disco fora de `$Ordem: " + ($naoDeclaradas -join ', '))

    $fantasmas = $declaradas | Where-Object { $emDisco -notcontains $_ }
    Assert-True ($fantasmas.Count -eq 0) ("`$Ordem cita suite que nao existe: " + ($fantasmas -join ', '))
}

Test-Caso "scripts e tests: toda funcao definida tem pelo menos um CHAMADOR" {
    # O guarda-corpo que o qa-reviewer recomendou nominalmente, depois de achar
    # DOIS simbolos adicionados e nunca conectados na mesma rodada:
    #
    #   - Invoke-NativoLocal, no bootstrap da plataforma, criada com um
    #     comentario afirmando que o defeito estava corrigido enquanto as
    #     chamadas de git continuavam soltas. "Afirmar corrigido o que nao
    #     estava", dentro do conserto dessa mesma classe.
    #   - ArquivosDeCIAusentes, em scan-exposicao.ps1, incrementado e nunca
    #     lido, com o comentario dizendo que corrigia a sobre-contagem.
    #
    # A observacao dele e o que importa: e uma classe que o 'git diff' MOSTRA e
    # nenhum teste pega. Atencao nao fecha isso; referencia fecha.
    # As DUAS arvores. Ate a rodada 11 o guarda so olhava scripts/, e o
    # titulo dizia "toda funcao definida" sem dizer onde - guarda que
    # examina metade do que o nome promete. O qa-reviewer achou a primeira
    # instancia viva exatamente no ponto cego: Remove-ComentarioDePowerShell
    # ficou orfa DENTRO do proprio harness de teste, sobrevivendo a rodada
    # que a tornou desnecessaria, com a docstring ensinando o mecanismo
    # abandonado. templates/ continua fora, e isso esta no backlog.
    $orfas = @()
    foreach ($arvore in @('scripts', 'tests')) {
        $orfas += Find-FuncaoSemChamador -DirDefinicao (Join-Path $OsRoot $arvore) -DirReferencia $OsRoot
    }
    Assert-True ($orfas.Count -eq 0) `
        ("funcao definida em scripts/ ou tests/ e nunca chamada - correcao que entrou e nao foi conectada, ou resto de mecanismo abandonado: " + ($orfas -join ', '))
}

Test-Caso "scripts: o guarda de funcao ACUSA orfa plantada, e nao se engana com comentario" {
    # O par positivo que faltava, e que derrubou a rodada anterior.
    #
    # O qa-reviewer descreveu a mutacao que sobrevivia: trocar o despiste de
    # comentario por identidade deixava a suite verde, porque hoje todo simbolo
    # de scripts/ tem chamador real. Guarda que nunca acusou nada nao foi
    # testado - foi so executado (politica 4.1).
    #
    # Esta fixture separa os tres casos que importam, e o terceiro e o unico
    # que discrimina o despiste de comentario.
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ("guarda-fn-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $fx -Force | Out-Null
    try {
        $conteudo = @(
            'function Get-Chamada {',
            '    return 1',
            '}',
            'function Get-Orfa {',
            '    return 2',
            '}',
            'function Get-SoEmComentario {',
            '    return 3',
            '}',
            'function Remove-Irma {',
            '    return 4',
            '}',
            '# Get-SoEmComentario e citada aqui de proposito: mencao em',
            '# comentario nao e chamador.',
            '$x = Get-Chamada',
            # E a forma que derrubou a rodada 8: a MENSAGEM de uma assercao
            # citando o simbolo pelo nome. Entre aspas, sem cerquilha na
            # linha, sobrevivia inteira a qualquer despiste de comentario.
            'Assert-True $ok "Get-SoEmLiteral nao foi exercitada"',
            'function Get-SoEmLiteral {',
            '    return 6',
            '}',
            '$y = Remove-IrmaMaior',
            'function Remove-IrmaMaior {',
            '    return 5',
            '}'
        ) -join "`r`n"
        Set-Content -Path (Join-Path $fx 'alvo.ps1') -Value $conteudo -Encoding ASCII

        $achadas = Find-FuncaoSemChamador -DirDefinicao $fx -DirReferencia $fx
        $nomes = @($achadas | ForEach-Object { ($_ -split ': ')[1] })

        Assert-True ($nomes -contains 'Get-Orfa') `
            "o guarda nao acusou a orfa plantada. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'Get-SoEmComentario') `
            "o guarda aceitou MENCAO EM COMENTARIO como chamador. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'Get-SoEmLiteral') `
            "o guarda aceitou MENCAO EM STRING LITERAL como chamador - foi assim que a mensagem de assercao de um caso de teste manteve 'Invoke-NativoLocal' vivo depois de desconectada. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'Remove-Irma') `
            "o guarda deu 'Remove-Irma' por chamada porque o texto tem 'Remove-IrmaMaior' - nome irmao cobrindo o irmao menor. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -notcontains 'Get-Chamada') `
            "o guarda acusou uma funcao que TEM chamador real - falso positivo. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -notcontains 'Remove-IrmaMaior') `
            "o guarda acusou 'Remove-IrmaMaior', que e chamada. Acusou: $($nomes -join ', ')"
    } finally {
        Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "scripts: o guarda de funcao RECUSA arvore vazia em vez de passar por vacuidade" {
    # Detector que nao encontra nada para examinar tem de dizer que nao rodou,
    # nunca devolver "nenhuma orfa". E a regra do exit 2 da plataforma aplicada
    # dentro de uma funcao.
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ("guarda-vazio-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $fx -Force | Out-Null
    try {
        $lancou = $false
        try { $null = Find-FuncaoSemChamador -DirDefinicao $fx -DirReferencia $fx }
        catch { $lancou = $true }
        Assert-True $lancou "diretorio sem nenhum .ps1 devolveu 'nenhuma orfa' em vez de recusar"
    } finally {
        Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "scripts: todo campo de Cobertura criado e LIDO em algum lugar" {
    # A outra metade do mesmo achado. Um contador que sobe e ninguem le nao
    # corrige nada - e o comentario ao lado dele afirma que corrige.
    # SO os dois geradores de relatorio. A versao anterior incluia
    # tests/suites, e o qa-reviewer apontou que isso alarga o guarda alem
    # do que a mensagem promete: campo lido apenas por um Assert-True, e
    # nunca impresso, satisfazia um guarda cuja falha diz 'nao chega ao
    # relatorio'. Hoje nenhum campo depende disso - conferi campo a campo -,
    # entao estreitar nao quebra nada e passa a medir o que anuncia.
    $consumidores = @(
        (Join-Path $OsRoot 'scripts\security-scan.ps1'),
        (Join-Path $OsRoot 'scripts\collect-diff.ps1')
    )
    $semLeitor = Find-CampoSemLeitor -DirDefinicao (Join-Path $OsRoot 'scripts\lib') -Consumidor $consumidores
    Assert-True ($semLeitor.Count -eq 0) `
        ("campo de cobertura que ninguem le - contador que sobe e nao chega ao relatorio nao corrige nada: " + ($semLeitor -join ', '))

    # O DOCTOR nao entra aqui, e a razao esta escrita para nao virar ponto
    # cego por esquecimento.
    #
    # Este guarda mede ACESSO A MEMBRO ('$cob.X'), que e o proxy certo para o
    # scanner: la a cobertura vira prosa composta campo a campo, entao campo
    # sem acesso e campo que nao chega ao relatorio. No doctor a cobertura de
    # cada dimensao e serializada INTEIRA - para a tabela do relatorio e para
    # 'dimensions[].cobertura' no JSON -, entao nao ha acesso por membro e o
    # guarda acusaria todo campo, inclusive os que chegam.
    #
    # Forcar '$cob.X' no relator para satisfazer este guarda seria culto de
    # carga: passaria a medir a forma, e nao o fato. O fato - toda chave de
    # cobertura chega as duas saidas - tem caso proprio, e ele e mais forte
    # que este: 'doctor: toda chave de Cobertura chega ao relatorio E ao JSON'
    # em tests/suites/doctor.ps1. Quem mexer aqui confira aquele.
}

Test-Caso "scripts: o guarda de campo ACUSA campo sem leitor, titulo de teste e nome irmao" {
    # O par positivo do segundo guarda, com as tres mutacoes que o qa-reviewer
    # descreveu sobrevivendo verdes na versao anterior.
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ("guarda-campo-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $fx -Force | Out-Null
    try {
        $lib = @(
            '$cob = [pscustomobject]@{',
            '    Lido = 0',
            '    Orfao = 0',
            '    Commits = 0',
            '    ArquivosDeCI = 0',
            '    ArquivosDeCIAusentes = 0',
            # Formas que a janela de indentacao e a lista branca do regex
            # perdiam em silencio. A de ';' nao e hipotetica: os QUATRO
            # campos de scan-dado-pessoal.ps1 sao declarados assim e nunca
            # tinham sido verificados.
            '    DepoisDePontoEVirgula = 0; SegundoNaMesmaLinha = 0',
            '                MuitoIndentado = 0',
            '    SoEscrito = 0',
            '}',
            '<#',
            '    Fantasma = este campo so existe dentro de um bloco de',
            '    documentacao e nao deve ser extraido.',
            '#>'
        ) -join "`r`n"
        Set-Content -Path (Join-Path $fx 'scan-fixture.ps1') -Value $lib -Encoding ASCII

        $cons = Join-Path $fx 'consumidor.ps1'
        Set-Content -Path $cons -Encoding ASCII -Value (@(
            'W "lidos: $($c.Lido)"',
            'Test-Caso "coletor: repo sem commits mostra TODO arquivo" { }',
            'W "ci ausentes: $($c.ArquivosDeCIAusentes)"',
            # Escrever num membro NAO e ler: consumidor que so atribui nao
            # leva o valor a lugar nenhum.
            '$c.SoEscrito = 5',
            '# $c.Orfao aparece so em comentario'
        ) -join "`r`n")

        $achados = Find-CampoSemLeitor -DirDefinicao $fx -Consumidor @($cons) -FiltroDeArquivo 'scan-*.ps1'
        $nomes = @($achados | ForEach-Object { ($_ -split ': ')[1] })

        Assert-True ($nomes -contains 'Orfao') `
            "campo citado so em comentario passou por lido. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'Commits') `
            "o TITULO de um caso de teste ('repo sem commits') contou como leitor do campo 'Commits'. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'ArquivosDeCI') `
            "'ArquivosDeCIAusentes' cobriu o irmao menor 'ArquivosDeCI'. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -notcontains 'Lido') `
            "campo com leitor de verdade foi acusado - falso positivo. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -notcontains 'ArquivosDeCIAusentes') `
            "campo lido foi acusado. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -notcontains 'Fantasma') `
            "linha dentro de bloco de documentacao virou campo. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'SegundoNaMesmaLinha') `
            "campo declarado depois de ';' na mesma linha ficou invisivel - foi assim que os quatro campos de scan-dado-pessoal.ps1 passaram sem verificacao nenhuma. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'MuitoIndentado') `
            "campo com indentacao fora da janela do regex antigo ficou invisivel. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'SoEscrito') `
            "consumidor que apenas ESCREVE no membro contou como leitor. Acusou: $($nomes -join ', ')"
        Assert-True ($nomes -contains 'DepoisDePontoEVirgula') `
            "o primeiro campo da linha com ';' tambem sumiu. Acusou: $($nomes -join ', ')"
    } finally {
        Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Test-Caso "scripts: o guarda de campo RECUSA consumidor ilegivel em vez de acusar tudo" {
    # Sem consumidor nenhum, TODO campo pareceria orfao: o guarda diria a coisa
    # certa pela razao errada, e a proxima pessoa iria atras de defeito que nao
    # existe. Recusar e a resposta correta.
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ("guarda-cons-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $fx -Force | Out-Null
    try {
        Set-Content -Path (Join-Path $fx 'scan-x.ps1') -Encoding ASCII -Value "`$cob = @{`r`n    Campo = 0`r`n}"
        $lancou = $false
        try { $null = Find-CampoSemLeitor -DirDefinicao $fx -Consumidor @((Join-Path $fx 'nao-existe.ps1')) }
        catch { $lancou = $true }
        Assert-True $lancou "consumidor inexistente devolveu acusacao em vez de recusar"
    } finally {
        Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue
    }
}
