# ADR-0011 — Fluxo de branch, diff e PR é client-side; não há enforcement server-side

- **Data:** 2026-10-02
- **Status:** Aceita
- **Fase:** 2 (subfase 2.7)

## Contexto

A subfase 2.7 entrega branch, diff e PR. A pergunta que precedia o desenho era se o rigor desse fluxo seria **imposto pelo servidor** ou **sustentado pelo cliente**.

**O fato que decide, e ele foi medido, não suposto:** branch protection e rulesets estão **indisponíveis** neste repositório. A API devolve `403 Upgrade to GitHub Pro` — repositório privado em plano gratuito. Verificado por três chamadas de API e registrado em `docs/STATE.md` desde então, como *"decisão a registrar em ADR"*. Este é o ADR.

As saídas possíveis eram três, e duas já estavam fechadas por decisão anterior:

| Saída | Situação |
|---|---|
| Tornar o repositório **público** para ganhar proteção gratuita | **Descartada por ADR-0003** — privado por padrão; tornar público é ato deliberado e este não é o motivo |
| **Contratar GitHub Pro** só para ter branch protection | **Descartada pela mantenedora em 2026-10-01**: o custo não se justifica agora |
| **Client-side**: ferramenta local + hooks + disciplina de PR + CI futura | **Escolhida** |

## Decisão

1. O fluxo de branch, diff e PR da 2.7 é **client-side**. `branch.ps1` cuida de criação, listagem, estado e guarda-corpos de troca; `collect-diff.ps1 -Contra <base>` produz a evidência; `pr.ps1` integra via `gh`, **sem manipular token** (ADR-0003, item 5).
2. Os hooks da 2.6 são os **portões locais** — `commit-msg`, `pre-commit`, `pre-push` — e continuam **contornáveis por `--no-verify`, por desenho**.
3. A **CI da 2.8** é a camada de verificação **independente**, fora da máquina de quem escreve. É ela que responde pelo que o cliente não pode garantir.
4. **Esta limitação é conhecida e aceita, e não é equivalente a enforcement server-side.** Nenhuma skill, documento ou relatório desta plataforma pode apresentar o modelo client-side como se fosse proteção de branch. Afirmar isso seria falsa garantia — a classe que este repositório trata como pior que lacuna.

## Consequências

- **O que se perde:** nada impede, no servidor, um push direto em `main`, um force-push, ou um merge sem revisão. Quem tem acesso de escrita tem acesso de escrita.
- **O que resta:** feedback local rápido (8,2 s no `pre-commit`), portão antes do push condicionado ao manifesto, e — a partir da 2.8 — verificação independente que o autor do commit não contorna.
- **O que isso exige da ferramenta:** como a disciplina não é imposta, ela tem de ser **barata e clara**. Portão que custa minutos, ou que barra sem dizer o que fazer, ensina `--no-verify` em uma semana — e aí a camada client-side deixa de existir de fato.
- **Fronteira que fica declarada em toda documentação do fluxo:** hook local ≠ portão de push ≠ CI independente. As três respondem perguntas diferentes, e só a terceira não depende de boa vontade.

## Revisão desta decisão

Reabre-se com **fato novo**, não com preferência: mudança de plano do GitHub, mudança de necessidade (mais de uma pessoa com acesso de escrita, por exemplo), ou migração para outra forja com proteção disponível. Até lá, decisão registrada não se reabre (ADR-0001).
