# ADR-0001 — Workspace único em `C:\AI-WORKSPACE`, migração progressiva

- **Data:** 2026-09-05
- **Status:** Aceita
- **Fase:** 1 (bloco B)

## Contexto

Os projetos existentes estão espalhados: dois na raiz da pasta do usuário (`C:\caminho\exemplo\PROG_*`), um dentro do OneDrive pessoal, um no Desktop sem Git. Não há convenção de local, e a busca por "onde está aquele projeto" é manual.

O handoff (`docs/VISION.md`, §5) especifica uma árvore única em `C:\AI-WORKSPACE`.

## Decisão

1. `C:\AI-WORKSPACE` passa a ser a raiz canônica de projetos novos, com `_platform/`, `work/{prog,dynatest,cliente-b}/`, `university/`, `personal/`, `ai-lab/`, `portfolio/`.
2. `C:\AI-WORKSPACE` **não é** um repositório Git. Um projeto = um repositório.
3. `OneDrive\AI-ARCHIVE\{releases,handoffs,portfolio-assets,backups}` recebe artefatos, não repositórios.
4. **Os projetos existentes não são movidos agora.** A migração é progressiva, um projeto por vez, começando por um piloto, e cada migração é uma decisão própria.

## Alternativas consideradas

- **Mover os 3 repos imediatamente.** Rejeitada: quebra caminhos absolutos em scripts, atalhos, agendamentos do Windows e a configuração `gui.recentrepo`. Ganho estético, risco operacional real, e nenhuma urgência.
- **Não criar workspace; padronizar só o conteúdo.** Rejeitada: sem raiz previsível, `/os:status` e `/os:new-project` não têm onde procurar nem onde criar.

## Consequências

- Positiva: projetos novos nascem no lugar certo desde o começo.
- Positiva: a migração pode falhar em um projeto sem afetar os outros.
- Negativa: por um período haverá projetos dentro e fora da árvore. Aceito — é o preço de não quebrar o que funciona.
- `/os:status` precisa saber olhar para fora do workspace enquanto durar a transição.
