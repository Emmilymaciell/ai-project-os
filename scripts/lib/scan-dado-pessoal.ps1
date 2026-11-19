<#
.SYNOPSIS
    Detector: dado pessoal e de terceiro (CPF, CNPJ, telefone, CEP, e-mail).

.DESCRIPTION
    Fecha o terceiro ponto INCONCLUSIVO da subfase 2.2. Importa nesta
    plataforma porque ela governa projetos PROG e Dynatest, onde documento de
    terceiro circula de verdade.

    O risco deste detector nao e deixar passar: e gritar sempre. Um scanner
    que acusa todo numero formatado de 11 digitos treina quem le a ignora-lo,
    e ai ele deixa de existir na pratica. Duas defesas:

      1. CPF e CNPJ so viram achado com o DIGITO VERIFICADOR valido.
      2. Telefone e CEP exigem forma pontuada ou palavra-chave por perto.

    E-mail e classificado, nao acusado em bloco: e-mail que aparece como
    autor de commit deste repositorio e a identidade de quem mantem o
    projeto, nao dado de terceiro. Essa distincao e DERIVADA do proprio
    historico do Git - nao ha lista de pessoas escrita em lugar nenhum.

    Nunca transcreve o valor. Para e-mail de terceiro reporta o dominio e a
    localizacao, nunca a parte local: dominio basta para triar e identifica
    muito menos.

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

function Get-IdentidadesDoRepositorio {
    <#
      Quem assina os commits deste repositorio. Derivado, nunca declarado a
      mao: lista de pessoas escrita num arquivo envelhece e vira allowlist
      silenciosa. Se um e-mail esta no historico como autor, ele ja esta no
      repositorio por construcao - acusa-lo como dado de terceiro seria
      ruido garantido.
    #>
    param([string]$Path)
    $ids = @()
    # Test-TemHistorico, nao Test-HeadResolvivel: "log --all" varre REFS,
    # nao o HEAD. Repositorio com "refs/remotes/origin/main" buscado e HEAD
    # nao nascido TEM identidades a ler, e a pergunta certa e a do historico.
    if (Test-TemHistorico $Path) {
        foreach ($e in @(Invoke-Git @('-C', $Path, 'log', '--all', '--format=%ae'))) { $ids += $e }
        foreach ($e in @(Invoke-Git @('-C', $Path, 'log', '--all', '--format=%ce'))) { $ids += $e }
    }
    # 'config --get-all' devolve 1 quando a chave nao existe - resposta, nao
    # erro. Qualquer outro codigo e falha, e falha aqui esconde a identidade
    # de quem mantem o projeto: todo e-mail viraria MEDIA "nao assina commits
    # deste repositorio", inclusive o dela. Superacusar e a direcao segura,
    # mas o contrato do Invoke-Git diz que quem usa -PermitirFalha LE o
    # codigo - e este ponto nao lia. Achado do qa-reviewer.
    foreach ($e in @(Invoke-Git @('-C', $Path, 'config', '--get-all', 'user.email') -PermitirFalha)) { $ids += $e }
    if ($LASTEXITCODE -gt 1) {
        throw ("git config --get-all user.email saiu com $LASTEXITCODE : a identidade do repositorio " +
               "NAO foi lida, e sem ela a classificacao de e-mail nao vale.")
    }
    return @($ids | Where-Object { $_ } | ForEach-Object { $_.ToLower().Trim() } | Sort-Object -Unique)
}

function Test-EhEmailDeExemplo {
    <#
      Placeholder de documentacao nao e dado de ninguem. .example, .invalid,
      .test e .localhost sao reservados pela RFC 2606/6761 exatamente para
      isso, e por isso entram sem ressalva.
    #>
    param([string]$Email)
    $e = $Email.ToLower()
    if ($e -match '@(example|exemplo)\.(com|org|net|com\.br)$') { return $true }
    if ($e -match '\.(invalid|test|localhost|example)$') { return $true }
    if ($e -match '@(dominio|empresa|meudominio|seudominio)\.') { return $true }
    if ($e -match '^(noreply|no-reply|user|usuario|voce|seu-email|seuemail|someone|fulano|teste|test|email|nome)@') { return $true }
    return $false
}

function Find-DadoPessoalEmTexto {
    <#
      Funcao PURA sobre texto: recebe conteudo, devolve achados. Nao toca
      disco nem Git. E por isso que o detector de historico consegue
      reaproveita-la sobre um blob antigo que ja esta em memoria.

      -Identidades: e-mails que pertencem a quem mantem o repositorio. Se
      nao vier, cai no que o orquestrador tiver publicado em
      $Global:OsScanIdentidades. Os testes passam explicitamente.

      Devolve objetos com Severidade, Categoria, Detalhe e Contagens - a Area
      quem define e quem chama, porque o mesmo texto pode vir do working tree
      ou do historico.
    #>
    param(
        [string]$Texto,
        [string]$Origem,
        [string[]]$Identidades
    )

    if (-not $PSBoundParameters.ContainsKey('Identidades')) {
        $Identidades = @()
        if ($Global:OsScanIdentidades) { $Identidades = $Global:OsScanIdentidades }
    }
    $ids = @($Identidades | ForEach-Object { $_.ToLower() })

    $achados = @()
    if (-not $Texto) { return $achados }

    # Arquivo que se DECLARA fixture no cabecalho tem os achados
    # RECLASSIFICADOS para BAIXA, nunca silenciados - a mesma convencao que
    # vale para credencial. Um CPF valido dentro de teste negativo e
    # fabricado por necessidade: sem ele nao ha como provar que o detector
    # acusa. Ver Test-DeclaraFixture: mencionar o marcador no meio do texto
    # nao conta, e o motivo esta documentado la.
    $ehFixture = Test-DeclaraFixture $Texto

    function New-DP2 {
        # Igual a New-DP, mas carrega a impressao do conjunto de valores
        # achados. Nunca e o valor: e hash truncado, e nao aparece no
        # relatorio. Ver Get-ImpressaoDeValores.
        param([string]$Sev, [string]$Cat, [string]$Det, [string[]]$Valores)
        $o = New-DP $Sev $Cat $Det
        Add-Member -InputObject $o -NotePropertyName 'Impressao' -NotePropertyValue (Get-ImpressaoDeValores $Valores)
        return $o
    }

    function New-DP {
        # 'Base' e a categoria SEM a reclassificacao de fixture, e existe para
        # ser chave de deduplicacao estavel.
        #
        # Motivo, apontado pelo qa-reviewer: a chave de credencial e o nome do
        # padrao, que nao muda; a de dado pessoal era a Categoria, que MUDA
        # sob o marcador. Cenario real - um arquivo de teste e commitado com
        # CPF de fixture SEM o marcador no cabecalho, e o marcador entra num
        # commit posterior. Dali em diante o working tree produz
        # 'fixture declarada: CPF...' e o blob antigo produz 'CPF...': chaves
        # disjuntas, dedup nao pega, e o relatorio emite MEDIA bloqueante no
        # historico para sempre - sem caminho de reclassificacao, porque o
        # ADR-0009 nao preve MEDIA aceita. Mesma classe de bug de chaves
        # disjuntas, sobrevivendo na outra metade.
        param([string]$Sev, [string]$Cat, [string]$Det)
        if ($ehFixture) {
            return [pscustomobject]@{
                Severidade = 'BAIXA'
                Categoria  = ('fixture declarada: ' + $Cat)
                Base       = $Cat
                Detalhe    = $Det
            }
        }
        return [pscustomobject]@{ Severidade = $Sev; Categoria = $Cat; Base = $Cat; Detalhe = $Det }
    }

    # --- CPF ------------------------------------------------------------------
    # Pontuado, ou 11 digitos com a palavra CPF por perto. Onze digitos soltos
    # NAO entram: bate em telefone, protocolo, timestamp e numero de processo.
    $cpfs = @()
    foreach ($m in [regex]::Matches($Texto, '(?<!\d)(\d{3})\.(\d{3})\.(\d{3})-(\d{2})(?!\d)')) {
        $cpfs += [pscustomobject]@{ D = ($m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value + $m.Groups[4].Value); I = $m.Index }
    }
    foreach ($m in [regex]::Matches($Texto, '(?i)cpf\D{0,12}?(\d{11})(?!\d)')) {
        $cpfs += [pscustomobject]@{ D = $m.Groups[1].Value; I = $m.Index }
    }
    $nCpf = 0
    $iCpf = 0
    $vCpf = @()
    foreach ($c in $cpfs) {
        if (Test-CPF $c.D) { $nCpf++; $vCpf += $c.D; if ($iCpf -eq 0) { $iCpf = $c.I } }
    }
    if ($nCpf -gt 0) {
        $linha = Get-LinhaAproximada -Texto $Texto -Index $iCpf
        $achados += New-DP2 'MEDIA' 'CPF com digito verificador valido' `
            ('{0} linha ~{1}, {2} ocorrencia(s) - valor nao transcrito' -f $Origem, $linha, $nCpf) $vCpf
    }

    # --- CNPJ -----------------------------------------------------------------
    # BAIXA de proposito: CNPJ e registro publico de empresa, nao dado
    # pessoal. Aparece legitimamente em contrato e nota fiscal. Vale
    # registrar, nao vale travar.
    $cnpjs = @()
    foreach ($m in [regex]::Matches($Texto, '(?<!\d)(\d{2})\.(\d{3})\.(\d{3})/(\d{4})-(\d{2})(?!\d)')) {
        $cnpjs += [pscustomobject]@{ D = ($m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value + $m.Groups[4].Value + $m.Groups[5].Value); I = $m.Index }
    }
    foreach ($m in [regex]::Matches($Texto, '(?i)cnpj\D{0,12}?(\d{14})(?!\d)')) {
        $cnpjs += [pscustomobject]@{ D = $m.Groups[1].Value; I = $m.Index }
    }
    $nCnpj = 0
    $iCnpj = 0
    $vCnpj = @()
    foreach ($c in $cnpjs) {
        if (Test-CNPJ $c.D) { $nCnpj++; $vCnpj += $c.D; if ($iCnpj -eq 0) { $iCnpj = $c.I } }
    }
    if ($nCnpj -gt 0) {
        $linha = Get-LinhaAproximada -Texto $Texto -Index $iCnpj
        $achados += New-DP2 'BAIXA' 'CNPJ valido (registro publico de empresa)' `
            ('{0} linha ~{1}, {2} ocorrencia(s)' -f $Origem, $linha, $nCnpj) $vCnpj
    }

    # --- telefone -------------------------------------------------------------
    # Exige DDD entre parenteses ou palavra-chave. Sem isso, qualquer
    # '2026-09' ou intervalo numerico entraria.
    $tels = @()
    $vTel = @()
    foreach ($m in [regex]::Matches($Texto, '(?<!\d)\(\d{2}\)\s?9?\d{4}-\d{4}(?!\d)')) { $tels += $m.Index; $vTel += $m.Value }
    foreach ($m in [regex]::Matches($Texto, '(?i)(?:telefone|celular|whatsapp|fone)\D{0,12}?(?<!\d)\d{2}\s?9?\d{4}-?\d{4}(?!\d)')) { $tels += $m.Index; $vTel += $m.Value }
    if ($tels.Count -gt 0) {
        $linha = Get-LinhaAproximada -Texto $Texto -Index $tels[0]
        $achados += New-DP2 'MEDIA' 'telefone' `
            ('{0} linha ~{1}, {2} ocorrencia(s) - valor nao transcrito' -f $Origem, $linha, $tels.Count) $vTel
    }

    # --- CEP ------------------------------------------------------------------
    # So com a palavra CEP por perto. '12345-678' solto bate em faixa de
    # numeracao, codigo de peca e intervalo de linha.
    $ceps = @()
    $vCep = @()
    foreach ($m in [regex]::Matches($Texto, '(?i)\bcep\b\D{0,12}?(?<!\d)\d{5}-?\d{3}(?!\d)')) { $ceps += $m.Index; $vCep += $m.Value }
    if ($ceps.Count -gt 0) {
        $linha = Get-LinhaAproximada -Texto $Texto -Index $ceps[0]
        $achados += New-DP2 'BAIXA' 'endereco (CEP)' `
            ('{0} linha ~{1}, {2} ocorrencia(s)' -f $Origem, $linha, $ceps.Count) $vCep
    }

    # --- e-mail ---------------------------------------------------------------
    $terceiros = @{}
    $vTerceiro = @{}
    $nAutor = 0
    $vAutor = @()
    $nExemplo = 0
    $iTerceiro = @{}
    foreach ($m in [regex]::Matches($Texto, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')) {
        $e = $m.Value.ToLower()
        if ($ids -contains $e) { $nAutor++; $vAutor += $e; continue }
        if (Test-EhEmailDeExemplo $e) { $nExemplo++; continue }
        $dom = $e.Substring($e.IndexOf('@') + 1)
        if (-not $terceiros.ContainsKey($dom)) { $terceiros[$dom] = 0; $iTerceiro[$dom] = $m.Index; $vTerceiro[$dom] = @() }
        $terceiros[$dom]++
        $vTerceiro[$dom] += $e
    }
    if ($nAutor -gt 0) {
        $achados += New-DP2 'BAIXA' 'e-mail de identidade do proprio repositorio' `
            ('{0}, {1} ocorrencia(s) - assina commits deste repositorio' -f $Origem, $nAutor) $vAutor
    }
    foreach ($dom in $terceiros.Keys) {
        $linha = Get-LinhaAproximada -Texto $Texto -Index $iTerceiro[$dom]
        # Dominio sim, parte local nao: o dominio tria e identifica muito menos.
        #
        # E o rotulo diz o que o detector SABE, nao mais que isso: ele
        # reconhece "nao assina commits deste repositorio". Um segundo
        # endereco da MESMA pessoa - o corporativo dela, por exemplo - nunca
        # pode ser reconhecido por identidade derivada do 'git log', que so
        # ve quem assinou commit. Chamar isso de "terceiro" apontava a
        # remediacao errada. Contestacao do security-reviewer, aceita.
        $achados += New-DP2 'MEDIA' 'e-mail que nao assina commits deste repositorio' `
            ('{0} linha ~{1}, dominio {2}, {3} ocorrencia(s) - parte local nao transcrita. Pode ser de terceiro OU um segundo endereco de quem mantem o projeto: a identidade derivada do git log so reconhece quem assinou commit' -f $Origem, $linha, $dom, $terceiros[$dom]) $vTerceiro[$dom]
    }

    return $achados
}

function Get-AchadosDadoPessoal {
    <#
      Aplica o detector nos arquivos de texto rastreados E nao rastreados.
      Nao rastreado entra porque e exatamente o codigo recem-escrito - o
      ponto cego que o security-reviewer achou na subfase 2.2.
    #>
    param([string]$Path)

    $achados = @()
    # Chaves 'caminho|categoria' do que foi achado AQUI, para o detector de
    # historico nao repetir o mesmo fato.
    #
    # Existir e obrigatorio, e o motivo esta num defeito real: na primeira
    # versao so a varredura de credencial contribuia chave, no formato
    # 'caminho|nome-do-padrao'. O detector de historico montava
    # 'caminho|categoria-de-dado-pessoal' e testava nessa mesma lista - dois
    # espacos de chave disjuntos, condicao nunca verdadeira, deduplicacao
    # morta para todo dado pessoal. O efeito visivel era pior que a
    # duplicacao: a area 'historico' exibia achado como se a exposicao fosse
    # SO no historico, e exposicao so no historico tem remediacao destrutiva
    # e diferente. Achado do qa-reviewer na subfase 2.3.
    $chaves = @()
    $cob = @{ Examinados = 0; SemExtensaoDeTexto = 0; Identidades = 0; AusentesDoDisco = 0
              NaoLidosPorCodificacao = 0 }

    $ids = Get-IdentidadesDoRepositorio -Path $Path
    $cob.Identidades = $ids.Count
    $Global:OsScanIdentidades = $ids

    $rastreados    = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z'))
    $naoRastreados = @(Invoke-GitCaminhos @('-C', $Path, 'ls-files', '-z', '--others', '--exclude-standard'))
    $todos = @(Get-CaminhosUnicos @($rastreados + $naoRastreados))
    # Pertinencia por ORDINAL: '-contains' confunde NFC com NFD (item 156).
    $conjNaoRastreados = New-ConjuntoOrdinal $naoRastreados

    foreach ($f in $todos) {
        if (-not (Test-ArquivoDeTexto $f -Raiz $Path)) { $cob.SemExtensaoDeTexto++; continue }
        $abs = Join-Path $Path $f
        if (-not (Test-Path -LiteralPath $abs)) {
            # CONTADO, nao descartado. A correcao da rodada anterior alcancou
            # o laco do security-scan.ps1 e deixou este e o de exposicao - o
            # qa-reviewer somou: 85 arquivos no conjunto, 84 examinados,
            # "0 nao lidos", area declarada 'sim'. Mesma classe, um ramo ao
            # lado.
            $cob.AusentesDoDisco++
            continue
        }
        # Lido ANTES de contar como examinado. Arquivo que nao e texto
        # legivel nao foi varrido, e conta-lo como examinado e a definicao de
        # falso verde: a leitura leniente devolvia U+FFFD ou NUL, nenhum
        # padrao casava, e o relatorio somava o arquivo na cobertura.
        $txt = Read-TextoDeArquivo $abs
        if ($null -eq $txt) { $cob.NaoLidosPorCodificacao++; continue }
        $cob.Examinados++
        $sufixo = ''
        if ($conjNaoRastreados.Contains($f)) { $sufixo = ' [nao rastreado]' }
        foreach ($a in (Find-DadoPessoalEmTexto -Texto $txt -Origem ($f + $sufixo) -Identidades $ids)) {
            $achados += New-Achado -Severidade $a.Severidade -Area 'dado de terceiro' `
                -Categoria $a.Categoria -Detalhe $a.Detalhe -Caminho $f
            # Caminho limpo, sem o sufixo '[nao rastreado]'; categoria BASE,
            # sem a reclassificacao de fixture; e a impressao dos VALORES.
            # Os tres importam: o caminho localiza, a base sobrevive a mudanca
            # de status de fixture entre commits, e a impressao impede que um
            # valor diferente no mesmo caminho - outro e-mail de terceiro numa
            # versao antiga - seja descartado como se fosse o mesmo fato.
            $chaves += ($f + '|' + $a.Base + '|' + $a.Impressao)
        }
    }

    return [pscustomobject]@{ Achados = $achados; Cobertura = $cob; Chaves = $chaves }
}
