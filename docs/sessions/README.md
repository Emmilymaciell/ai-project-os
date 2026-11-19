# Registro de sessões

Histórico compacto, uma entrada por sessão de trabalho. Escrito pelo `/session-close` e lido pelo `/session-start` — que descobre aqui o número da sessão seguinte.

## Por que existe, e por que é um arquivo novo

As quatro camadas de memória deste repositório (`docs/ARCHITECTURE.md` §9) respondem perguntas diferentes, e **nenhuma delas respondia "o que aconteceu naquela sessão"**:

| Camada | Pergunta |
|---|---|
| `docs/STATE.md` | onde o projeto **está** — snapshot, não diário |
| `docs/decisions/` | **por que** está assim |
| `CHANGELOG.md` | o que mudou **entre versões** |
| `docs/handoff/` | como **outra pessoa ou máquina** assume o projeto |

A ausência tinha consequência medida: em 2026-09-10 um *"Handoff pré-compactação"* foi escrito **dentro do `CHANGELOG.md`**, porque não havia onde. Registro de sessão no changelog de versões é a mistura que a separação de responsabilidades existe para evitar.

Este arquivo é a camada que faltava, e é deliberadamente **a menor possível**: um arquivo, blocos curtos, mais recente no topo. Não vira documentação extensa; o que crescer vai para o destino canônico e aqui fica só o ponteiro.

## Formato

Um bloco por sessão, **mais recente primeiro**, em `SESSIONS.md`:

```markdown
## <N> — <nome objetivo> · <AAAA-MM-DD>

- **Objetivo:** <uma frase>
- **HEAD final:** `<curto>` · working tree: <limpa | N alterações não commitadas>
- **Concluído:** <o que ficou pronto e verificado>
- **Parcial / investigado:** <o que avançou sem fechar, e o que foi investigado e NÃO implementado>
- **Decisões:** <ADR-NNNN, ou "nenhuma">
- **Validação:** `<comando exato>` → `<resultado real>`
- **Não executado:** <verificação que não rodou, com o motivo>
- **Próximo passo:** <uma ação executável>
```

Campo que não se aplica **sai do bloco** — não fica como `n/a`.

## Regras

- **Não repita o `STATE.md`.** Ele diz onde o projeto está; aqui diz o que esta sessão fez.
- **Nunca reescreva bloco de sessão passada.** Se um fato antigo se revelar errado, o bloco novo registra a correção e cita o antigo. Histórico que se reescreve deixa de ser histórico.
- **Resultado de validação é literal:** o comando exato e a saída real. "Passou" sem execução não entra.
- **Sem dado sensível:** nenhum segredo, token, caminho de rede corporativa ou dado pessoal de terceiro — este arquivo é versionado e vai para o remoto.
