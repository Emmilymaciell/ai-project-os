# ADR-0003 — GitHub pessoal privado por padrão, inclusive para projetos corporativos

- **Data:** 2026-09-05
- **Status:** Aceita
- **Fase:** 1 (bloco H)

## Contexto

A auditoria da Fase 0 identificou o risco **R1 — sem backup fora da máquina**: três repositórios, um único disco, 80% ocupado. Falha de disco significa perda total de histórico. É o risco mais grave e o mais barato de resolver.

Ao mesmo tempo, os três projetos tocam material Programa/Dynatest. A política do handoff (`docs/VISION.md`, §4) permite projetos corporativos no ambiente pessoal autorizado, incluindo GitHub pessoal privado.

## Decisão

1. Todo repositório criado ou publicado pelo Project OS é **privado por padrão**. Tornar público é ato deliberado, nunca default nem efeito colateral.
2. A identidade Git global é pessoal (`Emmily Maciel` / `(e-mail removido)`), não corporativa, para que a autoria sobreviva a mudança de emprego. Repositórios existentes mantêm a identidade local que já têm — inclusive a identidade de projeto do `PROG_Repositorio_Juridico`.
3. **Nenhum dado corporativo é publicado automaticamente.** Portfólio é permitido, preferencialmente sanitizado, com exposição declarada explicitamente por projeto.
4. **Nenhum repositório existente recebe remoto antes de auditoria de segredos sobre o histórico já commitado** — não basta o working tree estar limpo. Isso é o risco R4 e precede qualquer push desses repos.
5. O `gh` autentica por navegador. O Claude não manipula senha nem token.

## Escopo do que o remoto protege — e do que não protege

Precisão importante, porque a confusão aqui produz falsa segurança:

**O remoto no GitHub é backup off-machine do conteúdo versionado — nada além disso.**

| Protegido pelo remoto | **Não** protegido |
|---|---|
| Arquivos rastreados e já commitados | Trabalho no working tree ainda não commitado |
| Histórico de commits, branches e tags | Tudo que o `.gitignore` exclui |
| — | Saídas de execução (`output/`, `logs/`) |
| — | Dados operacionais e baselines mantidos apenas em disco |
| — | Artefatos locais, caches, `.env` |

Consequências práticas:

- Um `git push` não é um backup da pasta do projeto. Nos repositórios da Emmily, a maior parte do volume — os 146 MB de `output/` e os 42 MB de `examples/baseline/` do Programa Relatório, por exemplo — está **corretamente fora** do Git e permanece com cópia única em disco.
- Backup de dados operacionais e de artefatos é problema separado, e o lugar dele é `OneDrive\AI-ARCHIVE\` (releases, handoffs, backups) ou o próprio SharePoint corporativo, quando a fonte é de lá.
- "Está no GitHub" responde *o histórico está seguro*. Não responde *os dados estão seguros*.
- Por isso o risco R1 só se fecha para o **conteúdo versionado**. Fechar o R1 dos dados é outra decisão, de outra fase.

## Alternativas consideradas

- **Backup só por bundle no OneDrive.** Rejeitada como solução principal: resolve durabilidade, mas não dá branch, PR, CI, review nem colaboração — e as Fases 2 e 4 dependem disso. Mantida como camada complementar.
- **Conta GitHub corporativa.** Rejeitada: a plataforma é pessoal e precisa sobreviver a mudança de emprego.
- **Repositórios públicos sanitizados desde o início.** Rejeitada: sanitização é trabalho a fazer, não pressuposto. Público só depois do `/os:portfolio`, com decisão explícita.

## Consequências

- Positiva: fecha o R1 para a plataforma imediatamente.
- Positiva: destrava PR, CI e Actions (Fase 2).
- Negativa: cria dependência de serviço externo. Mitigada pelo bundle e por o Git local continuar sendo a fonte de verdade.
- **O R1 dos três projetos existentes continua aberto** até que cada um passe pela auditoria de segredos. Fechar o R1 da plataforma não fecha o deles.
