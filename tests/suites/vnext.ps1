<#
.SYNOPSIS
    Suite de testes: motor vNext (eos) - backup, restore, portabilidade, registry.

.DESCRIPTION
    O motor e Python so com a stdlib (ADR-0014). Os casos de comportamento vivem em
    eos/tests/ (unittest, sobre repositorios Git temporarios e nuvem em diretorio); esta suite
    os roda em processo separado e acrescenta os guardas que nao cabem la: dependencia so da
    stdlib, e nenhum verbo destrutivo de rclone no codigo.

    Nao rodar direto: use o runner raiz, que carrega o harness.
      .\tests\run-tests.ps1 -Suite vnext

.NOTES
    Sem acentos de proposito: PowerShell 5.1 le .ps1 UTF-8 sem BOM como ANSI.
#>

if (-not (Get-Command Test-Caso -ErrorAction SilentlyContinue)) {
    throw "Harness nao carregado. Rode: .\tests\run-tests.ps1 -Suite vnext"
}

function Invoke-PyDoMotor {
    param([string[]]$Argumentos)
    $antes = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Push-Location $OsRoot
    try {
        $saida = & py -3.13 @Argumentos 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Codigo = $LASTEXITCODE; Saida = ($saida -join "`n") }
    } finally {
        Pop-Location
        $ErrorActionPreference = $antes
    }
}

Test-Caso "motor vNext: a suite unittest do eos passa, e nao por vacuidade" {
    $r = Invoke-PyDoMotor @('-m', 'unittest', 'discover', '-s', 'eos/tests', '-t', '.')
    # A contagem vai para a saida da suite (e dali para o diff-report do coletor), passe ou falhe:
    # sem ela o revisor ve so "[PASS]" e nao quantos casos rodaram nem quantos pularam (r10).
    $ran = [regex]::Match($r.Saida, '(?m)^Ran \d+ tests? in [0-9.]+s')
    $fim = [regex]::Match($r.Saida, '(?m)^(OK|FAILED)\b.*$')
    Write-Host ("         unittest: " + $(if ($ran.Success) { $ran.Value } else { '(sem linha Ran)' }) + " | " + $(if ($fim.Success) { $fim.Value.Trim() } else { '(sem linha OK/FAILED)' }))
    Assert-True ($r.Codigo -eq 0) ("unittest saiu " + $r.Codigo + ": " + $r.Saida.Substring([Math]::Max(0, $r.Saida.Length - 1500)))
    $m = [regex]::Match($r.Saida, 'Ran (\d+) tests?')
    Assert-True $m.Success "a saida nao traz a linha 'Ran N tests' - execucao invalida, nunca aprovacao"
    Assert-True ([int]$m.Groups[1].Value -ge 30) ("so " + $m.Groups[1].Value + " casos rodaram")
    Assert-True ($r.Saida -match '(?m)^OK') "a linha final nao e OK"
}

Test-Caso "motor vNext: o registry versionado e valido e nao esta vazio" {
    $r = Invoke-PyDoMotor @('-m', 'eos', 'validate')
    Assert-True ($r.Codigo -eq 0) ("validate saiu " + $r.Codigo + ": " + $r.Saida)
    $m = [regex]::Match($r.Saida, '(\d+) contrato\(s\) valido\(s\), 0 erro')
    Assert-True $m.Success ("saida inesperada: " + $r.Saida)
    Assert-True ([int]$m.Groups[1].Value -ge 1) "registry vazio passaria por vacuidade"
}

Test-Caso "motor vNext: guardas estruturais (so stdlib; nenhum verbo destrutivo de rclone ou git)" {
    # Os guardas vivem em eos/tests/test_guardas.py: o PowerShell 5.1 remove aspas duplas de
    # argumento passado a executavel nativo, entao codigo Python inline chegaria corrompido.
    $r = Invoke-PyDoMotor @('-m', 'unittest', '-v', 'eos.tests.test_guardas')
    Assert-True ($r.Codigo -eq 0) ("guardas falharam: " + $r.Saida)
    foreach ($nome in @('test_so_stdlib', 'test_codigo_real_passa_no_guarda_e_o_guarda_ve_o_codigo', 'test_amostras_plantadas_sao_acusadas_pela_funcao_real', 'test_permissao_por_contexto_nao_vaza', 'test_lista_de_arquivos_nao_vazia')) {
        Assert-True ($r.Saida -match ($nome + ' .*\.\.\. ok')) ("o guarda " + $nome + " nao rodou ou nao passou")
    }
}
