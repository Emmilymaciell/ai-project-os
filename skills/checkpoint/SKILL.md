---
name: checkpoint
description: Salva uma versao verificada: testes, QA, seguranca, STATE, CHANGELOG, diff e commit. Use SOMENTE por pedido explicito - "salva essa versao", "commita", "atualiza o git", /os:checkpoint. Nunca por iniciativa propria.
---

# /os:checkpoint

Transformar trabalho pronto em uma versão verificada no histórico.

## A regra de ouro vem antes de tudo

**Esta skill só roda por pedido explícito.** Nunca ao terminar uma tarefa, nunca ao corrigir um bug, nunca no fim da sessão, nunca porque "parece um bom momento".

Frases que autorizam: *"salva essa versão"*, *"salvar versão"*, *"atualiza o git"*, *"manda pro git"*, *"commita isso"*, *"marca como versão X"*, *"essa é a versão boa"*, `/os:checkpoint`, `/versionar`.

**Se houver dúvida se a frase foi um pedido de commit, não commite. Pergunte em uma linha.**

Testes, tentativas e refinamentos intermediários ficam apenas no disco. Isso é intencional, não uma limitação.

## Sequência — nesta ordem, sem pular

```
1. INSPECT   status + diff
2. TEST      rodar a verificação que o projeto tem
3. QA        revisar o próprio diff com olhos de terceiro
4. SECURITY  varrer segredos e dados sensíveis
5. STATE     atualizar STATE.md + CHANGELOG.md + project.yaml (os TRES)
6. DIFF      apresentar o resumo à Emmily
7. APPROVAL  esperar o "sim"
8. COMMIT    add seletivo + commit
9. TAG       só se for marco
```

### 1. INSPECT

```bash
git status --porcelain
git diff --stat
git diff
```

Leia o diff inteiro. Se for grande demais para ler, isso é sinal de que deveriam ser dois ou três checkpoints, não um.

### 2. TEST

Rode o que o projeto tem. Não invente comando: procure em `tests/`, `scripts/`, `project.yaml` ou `CLAUDE.md`.

Se não houver teste nenhum e o projeto tiver código determinístico, diga isso — uma vez, em uma linha. Não bloqueie o checkpoint por isso, mas não deixe passar em silêncio.

**Teste que falha interrompe o checkpoint.** Reporte a saída real, não um resumo otimista.

### 3. QA

**Antes de reler o diff, consulte `project.yaml` → `verificacao.revisao_independente`** (política em `docs/VERIFICATION-POLICY.md`, regra em ADR-0007):

| Valor | O que fazer |
|---|---|
| `nenhuma` | Auto-revisão basta. Siga com a lista abaixo. |
| `qa` | Rode `scripts/collect-diff.ps1` e acione o `qa-reviewer` |
| `qa+security` | O de `qa` **mais** o fluxo de `/os:security` — varredura, leitura do relatório na ordem certa e `security-reviewer` |
| **campo ausente, ou sem `project.yaml`** | **Trate como `qa+security`**, e diga isso à Emmily em uma linha |

A última linha não é detalhe. Sem o campo, quem escolhe o rigor é quem acabou de construir — exatamente a decisão que o ADR-0007 existe para tirar da mão dele. Na dúvida, o rigor é o **máximo**, não o mínimo: ausência de declaração não é permissão (política 4.5). E registre a lacuna, porque um projeto sem `project.yaml` tem um defeito a corrigir.

Os revisores são **estritamente read-only** — `Read`, `Grep`, `Glob`, sem `Bash` (ADR-0008). Eles não rodam `git diff` nem os testes: os coletores determinísticos fazem isso e gravam os fatos em `artifacts/review/`. Você roda os coletores; eles leem.

**Acione o revisor em contexto isolado, e não conte a ele o que você já verificou.** É a ignorância dele que faz o mecanismo funcionar — é o mecanismo nomeado pelo ADR-0007, não uma recomendação de estilo.

O veredito tem **três** valores, e o do meio é o que importa: `APROVADO`, `REPROVADO` e `INCONCLUSIVO`. **`INCONCLUSIVO` bloqueia como `REPROVADO`** — ausência de evidência não é aprovação (política 4.5). Se o revisor disser que não pôde concluir sobre uma área, o checkpoint para naquela área até haver evidência.

Você acabou de escrever este código. Já formou a hipótese de que está certo e vai procurar confirmação, não defeito. A auto-revisão abaixo é útil e insuficiente — na Fase 1 um bug de encoding passou por 27 testes verdes porque a mesma cabeça escreveu código e teste.

Auto-revisão, sempre: releia o diff procurando

- mudança que entrou sem relação com o assunto do checkpoint;
- código morto ou comentado que deveria ter saído;
- caminho absoluto codificado (`C:\Users\...`) que quebraria em outra máquina;
- `TODO`/`FIXME` novo sem registro no `STATE.md`;
- alteração em arquivo que a Emmily não pediu para mexer.

### 4. SECURITY

Obrigatório. Não é opcional por o projeto ser pequeno.

```bash
git diff --cached --name-only
git ls-files | grep -iE '\.env$|\.key$|\.pem$|\.pfx$|credential|secret|token'
git diff | grep -inE 'password|senha|api[_-]?key|secret|bearer |ghp_|sk-[a-zA-Z0-9]{20}'
```

Verifique também:

- documento operacional (`.xlsx`, `.docx`, `.pdf`) entrando onde não deveria;
- dado pessoal de terceiro;
- e-mail, telefone ou CPF em arquivo que vai para remoto.

**Achado de segurança interrompe o checkpoint.** Reporte, proponha a correção, espere.

### 5. STATE, CHANGELOG e `project.yaml` — os três

Atualize **antes** do commit, não depois — assim eles entram no mesmo commit que descrevem.

**`docs/STATE.md`:** mover itens de pendência para concluído, atualizar riscos, escrever o **próximo passo** e a data.

**`CHANGELOG.md`:** uma entrada sob a versão, agrupada em Adicionado / Alterado / Corrigido / Removido / Segurança. Se algo foi tentado e revertido, registre — é a informação que se perde primeiro. Em Corrigido, diga **como o bug foi descoberto**, não só o que era.

**`project.yaml`:** atualizar `identidade.versao` e `estado.ultimo_checkpoint`, e `estado.fase` se mudou.

> Não esqueça o terceiro. O teste de aceitação da Fase 1 pegou exatamente isto: `STATE.md` e `CHANGELOG.md` diziam `0.1.1`, o `project.yaml` continuava em `0.1.0` com `ultimo_checkpoint` vazio. Como `/os:status` e `/os:handoff` leem do `project.yaml`, um recém-chegado veria a versão errada — e o próprio arquivo abre avisando "se estiver desatualizado, eles mentem".

Versão em Semantic Versioning, três componentes (ADR-0006): PATCH para correção, MINOR para capacidade nova.

### 6. DIFF — apresentar

```
Checkpoint proposto: <assunto em uma linha>

Arquivos:   <n> alterados (+<x> / -<y>)
            <lista, uma linha por arquivo, com o que mudou em cada um>
Testes:     <resultado real>
Segurança:  <o que foi verificado e o que se achou>
STATE:      <o que mudou>
Versão:     <de X.Y.Z para X.Y.Z, nos TRES arquivos>

Mensagem de commit proposta:
  <mensagem>
```

### 7. APPROVAL

Espere. Não commite sem resposta.

### 8. COMMIT

```bash
git add <arquivo> <arquivo> ...   # seletivo, sempre
git commit -m "<mensagem>"
```

**Nunca `git add .` nem `git add -A`.** Adicione os arquivos que você listou no resumo, um por um.

Mensagem: uma linha de assunto no imperativo, em português, sem ponto final. Corpo explicando **por quê**, não o quê — o quê está no diff. Se a mudança implementa uma decisão, referencie o ADR (`ADR-0004`) ou a convenção do projeto (`DEC-039`).

### 9. TAG — só se for marco validado

**Tag significa versão validada ponta a ponta**, não "commit que parece importante" (ADR-0006). Se o ciclo real do projeto não foi exercitado, não há tag — por bem estruturado que o código esteja.

Semantic Versioning, três componentes, sempre: `v0.1.0`, nunca `v0.1`.

```bash
git tag -a v0.2.0 -m "<descrição>"
```

Pergunte antes. Nunca crie tag sem pedido.

## Escolher entre commit direto, branch e PR

| Situação | Caminho |
|---|---|
| Mudança pequena e contida | commit direto em `main` |
| Feature relevante, projeto com remoto | branch + PR |
| Mudança arriscada ou que pede revisão | branch + PR, sempre |
| Projeto local sem remoto | commit direto — PR não existe sem remoto |

Não crie branch no meio de um trabalho já em andamento sem avisar.

## Nunca

- `push` sem aprovação explícita.
- `reset --hard`, `checkout --`, `clean -fd`.
- `rebase`, `commit --amend`, `push --force`.
- Trocar de branch no meio de um trabalho.
- Commitar credenciais, tokens ou dados pessoais de terceiros.

## Anti-falsos-positivos

- **"Ficou bom" não é pedido de commit.** É elogio ao resultado. Você pode *oferecer* o checkpoint em uma linha; não executá-lo.
- **"Terminei" também não é.** Nem "pronto", nem "funcionou".
- Um `.env.example` versionado está **correto** — não é vazamento. O que não pode entrar é o `.env`.
- Segredo em `.gitignore` não é achado de segurança: é o sistema funcionando. O achado é segredo **rastreado**.
- Não trate ausência de `evals/` como bloqueio num projeto sem componente LLM.
