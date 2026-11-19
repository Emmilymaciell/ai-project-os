# {{PROJECT_TITLE}}

{{PROJECT_DESC}}

## Antes de mudar qualquer coisa

Leia `docs/STATE.md` (onde o projeto está) e `docs/decisions/` (o que já foi decidido).
**Não reabra decisão registrada sem motivo técnico novo.**

## Regra de ouro do Git

Nunca `git add` / `git commit` / `git tag` por iniciativa própria. Só quando a Emmily pedir explicitamente ("salva essa versão", "commita", `/os:checkpoint`).

Nunca `git add .` às cegas: `status` → `diff` → varredura de segredos → resumo → `add` seletivo.

## O que NUNCA entra no Git deste projeto

<!-- Ajustar por projeto. O padrão abaixo é conservador de propósito. -->
- Documentos operacionais (`.xlsx`, `.docx`, `.pdf`, `.pptx`) — o `.gitignore` já bloqueia.
- Saídas de execução (`output/`, `logs/`).
- Credenciais, tokens, `.env`, caches de autenticação.
- Dados pessoais de terceiros.

## Ciclo de trabalho

```
INSPECT → PLAN → EXPLAIN → APPROVAL → IMPLEMENT → TEST → QA → SECURITY
→ DIFF → UPDATE STATE → CHECKPOINT → NEXT STEP
```

## Verificação deste projeto

<!--
  /os:new-project preenche o bloco abaixo e APAGA este comentário.
  Cada linha diz o que se aplica OU por que não se aplica — nunca deixe a
  forma genérica do template. "Só se houver componente LLM" não é informação
  sobre este projeto; é instrução para quem escreve o template.
-->

- **Tests:** {{VERIFICACAO_TESTS}} — rodar com `.\tests\run-tests.ps1` (o comando é o mesmo em todo projeto; o valor canônico está em `project.yaml` → `verificacao.comando`)
- **Evals:** {{VERIFICACAO_EVALS}}
- **Security check:** {{VERIFICACAO_SECURITY}}
- **Revisão independente:** {{REVISAO_INDEPENDENTE}} — derivada da criticidade, ver ADR-0007

A regra do que conta como verificado é do Project OS, não deste projeto: `docs/VERIFICATION-POLICY.md`. O resumo que importa aqui: **verificado = executado e observado**. Comando documentado e nunca rodado não conta; teste que nunca foi visto falhar não é detector.

**Critério de aceite vem do manifesto, nunca de um número cravado na asserção.** Declare em `project.yaml` → `verificacao.criterio_de_pronto` e `verificacao.limites`, e leia com a fixture `limite("nome")` (Python) ou `Get-LimiteDoManifesto` (PowerShell). Limite ausente faz o teste **falhar**, não passar. Ver `tests/README.md`.

**Saída `2` da suíte significa que ela não rodou** — terceiro estado, não uma variação de falha. Não trate como verde.

## Ambiente

Windows 11, PowerShell 5.1. Python **{{PYTHON}}** (a máquina tem 3.12 e 3.13 — não deixar implícito qual). Para scripts COM/Office, usar scratchpad em `Temp`, **nunca** pasta sincronizada pelo OneDrive.

## Decisões

Registrar em `docs/decisions/ADR-NNNN-titulo.md`. Referenciar o ADR na mensagem de commit quando a mudança implementar uma decisão.
