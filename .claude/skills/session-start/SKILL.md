---
name: session-start
description: Abre uma sessão reconstruindo o estado real pelo repositório, reconcilia com Git e disco, apresenta o briefing e PARA antes de implementar. Use ao abrir qualquer sessão nova, ou /session-start.
disable-model-invocation: true
disallowed-tools: Edit Write NotebookEdit
---

# /session-start

Reconstruir o estado real **sem nenhuma conversa anterior**, reconciliar com a realidade verificável, relatar, e **parar**.

Esta skill é o protocolo oficial de abertura. Ela existe porque o princípio central desta plataforma é `projeto ≠ sessão`: o repositório é a fonte canônica, a conversa é descartável. Se esta skill não conseguir reconstruir o contexto, **isso é defeito do projeto** — nomeie o defeito, não o contorne com suposição.

> **A proibição é mecânica até onde dá, e o limite está declarado.** O frontmatter remove `Edit`, `Write` e `NotebookEdit` deste turno: alterar arquivo por essas ferramentas é **impossível**, não apenas proibido.
>
> O que **continua sendo regra, e não mecanismo**: `Bash` permanece disponível porque a reconstrução precisa de `git` e do doctor — então commit, push, stash, reset, `clean`, instalação de dependência e qualquer escrita por linha de comando dependem de disciplina, como em todo o resto deste repositório. Nada disso acontece aqui. Inspeção read-only e verificação barata e não destrutiva: só isso.

## Relação com as skills do plugin — não duplique

| Precisa de | Use |
|---|---|
| reconstruir contexto em linguagem natural ("onde paramos?") | `/os:resume` |
| só o estado resumido | `/os:status` |
| diagnóstico determinístico das sete dimensões | `scripts/doctor.ps1` |
| passar o projeto para outra pessoa/máquina | `/os:handoff` |

`/session-start` **compõe** essas peças e acrescenta o que nenhuma tem: identidade da sessão, reconciliação explícita de divergências, separação entre resultado registrado e verificação feita agora, e a parada obrigatória.

## 1. Ambiente e repositório

```bash
pwd && git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD && git rev-parse HEAD && git rev-parse --short HEAD
git status --porcelain
git log -10 --format='%h %ad %s' --date=short
```

Confirme explicitamente que está na raiz certa. Separe **staged**, **não staged** e **untracked** — aqui os três contam, porque arquivo novo não rastreado é trabalho real que o `git diff` não mostra.

## 2. Regras permanentes, nesta ordem e só o necessário

1. `CLAUDE.md` — como se trabalha aqui. **Inteiro**, é curto e é a maior autoridade.
2. `docs/STATE.md` — **só o cabeçalho, a fase atual e a seção *Próximo passo***. O arquivo tem milhares de linhas; ler inteiro é desperdício e é o oposto de progressive disclosure.
3. `docs/decisions/` — **só os ADRs que restringem o próximo passo**, pelo título. Decisão registrada não se reabre sem fato técnico novo.
4. `project.yaml` — classificação, rigor exigido, `verificacao.comando`.

Só depois, e só se o próximo passo exigir: `docs/ARCHITECTURE.md`, `docs/VERIFICATION-POLICY.md`, runbooks.

## 3. Reconciliar o registro com a realidade

Rode o diagnóstico determinístico — ele é read-only, não roda a suíte e custa ~2 s:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
```

Depois confronte, e **mostre toda divergência em vez de corrigi-la em silêncio**:

| Compare | Contra | O que a divergência significa |
|---|---|---|
| data do `STATE.md` | data do último commit | houve trabalho não registrado |
| "próximo passo" do `STATE.md` | `git log` | o passo já pode ter sido feito |
| arquivos modificados | pendências declaradas | trabalho que ninguém anotou |
| contagens em prosa | disco | número envelhecido — classe conhecida aqui |
| `artifacts/review/` | `HEAD` atual | evidência de outro commit não descreve este código |

**Evidência verificável prevalece sobre resumo textual.** Quando divergirem, diga qual dos dois você está usando e por quê.

> **`artifacts/` é ignorado pelo Git e não viaja num clone.** Num clone novo não há vereditos de revisão, relatório de segurança nem diff coletado. A ausência deles **não** é defeito do registro: é o esperado. Diga isso em vez de reportar lacuna.

## 4. Baseline — o que foi medido agora, e o que só está escrito

Separe sempre, e nunca apresente resultado histórico como recém-executado:

- **Último resultado registrado:** o que o `STATE.md` declara no cabeçalho.
- **Verificado agora:** o que você realmente executou neste turno.

**Não rode a suíte completa por padrão** — ela leva ~14 minutos aqui. Rode `scripts/doctor.ps1`, que é barato e não destrutivo. Se o próximo passo depender do verde da suíte, diga que ela **não foi executada** e ofereça rodá-la.

**Pré-requisito que já travou sessão real:** se o próximo passo exigir revisão independente (`qa-reviewer` / `security-reviewer`), confirme a sessão OAuth antes de qualquer coleta:

```bash
"$USERPROFILE/.local/bin/claude.exe" -p "responda apenas: ok"
```

Sessão expirada = revisores inacionáveis, e `/login` é ação da mantenedora. Descobrir isso depois de coletar evidência custa a coleta inteira.

## 5. Trabalho incremental

Se o próximo passo for parte de um processamento por lotes — rodadas de revisão, varredura de arquivos, itens de backlog, mutações —, recupere **de onde parar de continuar**: total conhecido, feitos, pendentes, último lote, próximo lote, erros. Nesta plataforma isso vive em `docs/STATE.md` (tabela de backlog numerada, narrativa por rodada) e, quando existirem, em `artifacts/review/`.

Nunca reinicie em silêncio o que já foi feito. Nunca pule pendência em silêncio.

## 6. Identidade da sessão

Leia `docs/sessions/SESSIONS.md` e descubra o último número. Proponha:

```
<N+1> - <nome objetivo, 2 a 5 palavras>
```

Se o arquivo não existir ou a numeração for ambígua, **diga isso** e proponha `1`. Não invente número.

## 7. A próxima unidade de trabalho

A **menor** unidade coerente que faz sentido executar em seguida — não um replanejamento do projeto. Determine objetivo, por que agora, critério de conclusão, arquivos prováveis, dependências, riscos, verificações esperadas e quais skills/subagentes ajudam.

Antes de perguntar qualquer coisa à mantenedora, tente descobrir por: arquivos, Git, ADRs, `STATE.md`, backlog, runbooks, código e testes. Pergunte **só** quando a informação não existir no repositório, houver decisão material entre alternativas, ou a ação for de risco. Nunca invente resposta para evitar a pergunta.

## 8. Briefing

```
PROJETO        <nome> — <uma frase: que problema resolve>
DIRETÓRIO      <raiz>

SESSÃO         <N> — <nome sugerido>
OBJETIVO       <o que esta sessão deve concluir>

GIT            branch <b> · HEAD <curto> (<completo>)
               staged <n> · modificados <n> · não rastreados <n>

ÚLTIMO MARCO VERIFICÁVEL
CONCLUÍDO              <uma linha cada>
PARCIAL / EM ANDAMENTO
PENDENTE

PRÓXIMA TAREFA EXATA
CRITÉRIO DE CONCLUSÃO
ARQUIVOS DE ALTO SINAL
DECISÕES QUE RESTRINGEM   <ADR-NNNN: o que proíbe>

VALIDAÇÃO
  Último resultado registrado: <do STATE>
  Executado agora:             <o que você rodou, com o resultado real>

PENDÊNCIAS / BLOQUEIOS
INCONSISTÊNCIAS ENCONTRADAS   <ou "nenhuma">
SKILLS / SUBAGENTES ÚTEIS
```

Omita campo que não se aplica em vez de preenchê-lo com "n/a". Termine **exatamente** com:

```
Contexto reconstruído. Nenhuma alteração foi realizada.
```

E **pare**. Não comece a próxima tarefa. Aguarde autorização explícita.

## Anti-falsos-positivos

- **Não reabra decisão registrada.** ADR que rejeitou algo já pesou as alternativas; reabrir exige fato técnico novo, não preferência.
- **Não trate `git log` como intenção.** Ele mostra o que foi feito; o que se queria está no `STATE.md`.
- **Não corrija a divergência que encontrar.** Mostrar é o trabalho desta skill; corrigir é a próxima sessão, com autorização.
- **Não declare lacuna sobre `artifacts/` em clone novo** — ver §3.
- **Não rode a suíte "só para conferir".** São ~14 minutos, e o resultado registrado já responde a maior parte das perguntas.
- **Não transforme hipótese em fato** nem investigação em implementação ao resumir o estado.
- **Não sugira migrar o projeto** para um padrão novo só porque notou um arquivo antigo.
