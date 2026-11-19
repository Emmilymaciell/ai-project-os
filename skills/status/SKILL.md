---
name: status
description: Mostra onde o trabalho esta - projeto, estado, pendencias e proximo passo - lendo o repositorio, nao a conversa. Use para "onde eu estava", "o que falta", "qual o status", ou /os:status.
---

# /os:status

Responder **onde o trabalho está**, com base no que está escrito no disco.

Nada nesta skill depende do histórico da conversa. Se você não conseguir responder lendo arquivos e o Git, a resposta correta é dizer que o projeto não registrou seu estado — não preencher a lacuna com memória ou suposição.

## 1. Descobrir o contexto

Determine, em ordem:

1. **O diretório atual é um projeto?** Existe `project.yaml`, `CLAUDE.md` ou `.git`?
2. **Se não for**, o pedido é sobre a visão geral do workspace. Vá para a seção 3.

```bash
git rev-parse --show-toplevel 2>/dev/null
```

## 2. Status de um projeto

Leia, nesta ordem, e não invente o que não estiver lá:

| Fonte | O que extrair |
|---|---|
| `project.yaml` | nome, categoria, porte, criticidade, remoto, modo de execução, nível de autonomia |
| `docs/STATE.md` | concluído, parcial, pendências, riscos, próximo passo, último checkpoint |
| `docs/decisions/` | quantos ADRs, e o título dos 2 ou 3 mais recentes |
| Git | branch, nº de commits, última tag, data do último commit, arquivos modificados |

```bash
git status --porcelain
git log -1 --format='%h %s (%ar)'
git tag --sort=-creatordate | head -3
git branch --show-current
```

### Formato da resposta

Curto. A Emmily está se reorientando, não lendo um relatório.

```
<Título do projeto>  ·  <branch> · <n> commits · último: <tag ou hash> (<quando>)

Estado:        <uma linha do STATE.md>
Não commitado: <n arquivos, ou "nada">
Próximo passo: <o próximo passo do STATE.md>
```

Depois disso, no máximo três linhas de observação — e só se houver algo que mereça atenção.

## 3. Status do workspace

Quando não estiver dentro de um projeto, varra `C:\AI-WORKSPACE` **e também os projetos legados fora dela** (ver ADR-0001: a migração é progressiva, então por um tempo existem projetos nos dois lugares).

Para cada projeto encontrado, uma linha: nome, branch, commits, arquivos modificados, data do último commit.

Ordene por **data do último commit, mais recente primeiro** — é quase sempre o que ela quer ver.

## 4. Sinalizar o que merece atenção

Levante estes casos, e só estes. Não transforme o status num diagnóstico completo — isso é `/os:doctor`.

| Sinal | O que dizer |
|---|---|
| Working tree com muitos arquivos modificados | Quantos, e que um checkpoint pode estar atrasado |
| `docs/STATE.md` mais antigo que o último commit | O estado registrado não reflete o código |
| Sem `docs/STATE.md` | O projeto não sobrevive à perda desta conversa |
| Sem remoto e com histórico relevante | Não há backup fora da máquina |
| Última atividade há mais de 30 dias | Sugerir `/os:resume` em vez de continuar direto |

## Anti-falsos-positivos

- **Working tree sujo não é problema por si.** Trabalho em andamento é normal. Só vale nota se for grande ou antigo.
- **Ausência de tags não é problema.** Só o projeto Programa Relatório usa tags; os outros não, e está tudo bem.
- **Não sugira commit.** Nunca. Reportar que existe trabalho não commitado é informação; pedir para commitar é decisão dela.
- **Não confunda "sem remoto" com "abandonado".** Vários projetos são deliberadamente locais.
- Se o `project.yaml` estiver desatualizado em relação ao repositório, **diga isso** em vez de reportar o conteúdo dele como verdade.
