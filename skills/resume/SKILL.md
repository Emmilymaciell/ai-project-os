---
name: resume
description: Retoma um projeto reconstruindo o contexto pelo repositorio, nao pela conversa. Use para "vamos voltar naquele projeto", "me lembra onde paramos", /os:resume, ou ao reabrir algo parado ha dias ou meses.
---

# /os:resume

Reconstruir o contexto de trabalho **sem depender de nenhuma conversa anterior**.

Esta skill é a prova do princípio central da plataforma: projeto ≠ sessão. Se ela funcionar, o chat deixou de ser ponto único de falha. Se ela não conseguir reconstruir o contexto, isso é um **defeito do projeto**, e o defeito deve ser nomeado — não contornado com suposição.

## 1. Ler, em ordem de autoridade

Leia tudo antes de dizer qualquer coisa. Não vá relatando conforme lê.

| Ordem | Fonte | Autoridade |
|---|---|---|
| 1 | `docs/STATE.md` | Onde o projeto está. Fonte de verdade operacional. |
| 2 | `docs/decisions/` | Por que está assim. **Decisão registrada não se reabre sem motivo técnico novo.** |
| 3 | `CLAUDE.md` | Como se trabalha aqui. |
| 4 | `project.yaml` | Classificação, modo de execução, nível de autonomia. |
| 5 | `git log` das últimas 10–15 entradas | O que realmente aconteceu. |
| 6 | `README.md` | Qual problema o projeto resolve. |

```bash
git log -15 --format='%h %ad %s' --date=short
git status --porcelain
git diff --stat
```

## 2. Confrontar o registro com a realidade

Este é o passo que dá valor à skill. O `STATE.md` pode estar mentindo — não por má-fé, mas por estar velho.

Verifique:

- A data de `docs/STATE.md` é anterior ao último commit? Então houve trabalho não registrado.
- O "próximo passo" do `STATE.md` já foi feito? Confira no `git log`.
- Existem arquivos modificados que não correspondem a nenhuma pendência declarada?
- O `project.yaml` declara `tests: true` mas não existe `tests/`?

**Quando o registro divergir da realidade, diga qual dos dois você está usando e por quê.**

## 3. Apresentar a retomada

Máximo ~15 linhas. Ela quer voltar ao trabalho, não ler um dossiê.

```
<Título> — retomando

O projeto:     <uma frase: que problema resolve>
Última mexida: <quando> — <assunto do último commit>
Estado:        <concluído / parcial, em uma linha cada>
Decisões que restringem o que podemos fazer agora:
               <só as que afetam o próximo passo, com o número do ADR>
Não commitado: <o que está no working tree, se houver>

Próximo passo registrado: <do STATE.md>
```

Depois, **uma pergunta só**: confirmar se o próximo passo registrado ainda é o que ela quer, ou se mudou de ideia. Não faça bateria de perguntas.

## 4. Recomendar a arquitetura de execução

Antes de começar a trabalhar, avalie se o próximo passo pede algo diferente de "main Claude". Ela não deve precisar lembrar disso.

| Se o próximo passo… | Recomende |
|---|---|
| é uma mudança localizada | main Claude — não diga nada, só trabalhe |
| exige pesquisa ou revisão especializada | subagent, dizendo qual papel |
| tem partes independentes que não se tocam | subagentes paralelos, listando as partes |
| toca módulos independentes do mesmo repo | worktrees — **com o mapa completo, ver abaixo** |
| é um fluxo grande que vai se repetir | Dynamic Workflow |
| é uma varredura enorme e particionável | batch |

Só levante o assunto quando houver **benefício material**. O modo de falha mais provável aqui é superdimensionar: sugerir worktrees para uma edição de dois arquivos.

Se recomendar worktrees ou sessões paralelas, nunca pare em "use worktrees". Diga: quantas sessões, o nome de cada frente, a branch, o objetivo, os arquivos sob responsabilidade de cada uma, as dependências entre elas, o critério de conclusão e como integrar depois.

## 5. Detectar verificação faltando

Se o projeto tem código determinístico sem `tests/`, ou componente LLM sem `evals/`, mencione **uma vez**, em uma linha, e siga. Não bloqueie a retomada por isso.

## Quando o projeto não registrou seu estado

Se não houver `docs/STATE.md`, nem ADRs, nem README útil:

1. Diga claramente que o projeto não é retomável pelo repositório e que isso é um defeito.
2. Reconstrua o que for possível do `git log` e da estrutura de arquivos — e **marque isso como reconstrução, não como registro**.
3. Ofereça criar o `STATE.md` a partir dessa reconstrução, para que a próxima retomada não dependa de arqueologia.

## Anti-falsos-positivos

- **Não reabra decisões.** Se um ADR diz que algo foi rejeitado, ele já pesou as alternativas. Reabrir exige fato novo, não uma preferência sua.
- **Não trate o `git log` como intenção.** Ele mostra o que foi feito, não o que se queria fazer. A intenção está no `STATE.md`.
- **Não sugira migrar o projeto para o padrão novo** só porque ele é antigo. Migração é decisão dela, um projeto por vez (ADR-0001).
- **Não comece a trabalhar antes de confirmar o próximo passo.** Meses depois, a prioridade pode ter mudado.
