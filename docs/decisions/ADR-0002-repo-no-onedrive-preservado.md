# ADR-0002 — Preservar o repositório `Organizador_Dynatest_Pessoal` dentro do OneDrive

- **Data:** 2026-09-05
- **Status:** Aceita — **substituída em parte pelo ADR-0016 (2026-10-11)**: o repositório ganhou
  remoto privado no GitHub. A localização no OneDrive e as mitigações abaixo continuam valendo. O
  texto original segue intacto, como histórico da decisão.
- **Fase:** 1 (bloco B) — decisão de *não* agir

## Contexto

O handoff (`docs/VISION.md`, §3) diz que o OneDrive serve para releases e backups, **não** para repositórios Git ativos sincronizados. A regra é boa: a pasta `.git` são dezenas de arquivos pequenos, e o OneDrive os sincroniza um a um, sem ordem garantida — o cenário clássico de corrupção de histórico.

O repositório `C:\caminho\exemplo\OneDrive\Documentos\Claude\Organizador_Dynatest_Pessoal` viola essa regra.

A auditoria da Fase 0 encontrou, porém, que a violação é **deliberada, justificada e já mitigada**. O commit `b64b696` ("Protege o historico contra a sincronizacao do OneDrive") documenta:

- o motivo: a Emmily alterna entre a máquina do trabalho e o notebook de casa, e o projeto precisa estar nos dois;
- `gc.auto=0` e `maintenance.auto=false`, impedindo que o garbage collector reescreva packfiles em segundo plano dentro de pasta sincronizada;
- `scripts/backup_historico.ps1`, que gera `backups/historico.bundle` — o histórico inteiro em **um arquivo único** (71 KB contra 72 arquivos no `.git`), que o OneDrive sincroniza inteiro ou não sincroniza;
- restauração testada: `git clone` do bundle devolve os 34 arquivos, o histórico e os testes passando.

Os 158 arquivos do repositório estão todos locais (nenhum em modo cloud-only).

## Decisão

**Preservar.** O repositório continua onde está, com a mitigação atual. Não mover, não "corrigir".

A regra geral do §3 permanece válida para projetos novos: nenhum repositório novo nasce dentro de pasta sincronizada.

## Alternativas consideradas

- **Mover para `C:\AI-WORKSPACE\work\dynatest\` por conformidade.** Rejeitada: quebraria o caso de uso real (duas máquinas) e substituiria uma mitigação testada por um problema não resolvido. Conformidade não é objetivo em si.
- **Mover e resolver as duas máquinas via GitHub privado.** Adiada, não rejeitada. É a solução tecnicamente superior e vira viável assim que o bloco H estiver pronto. Deve ser reavaliada então — e essa reavaliação gera um ADR novo, não uma edição deste.

## Consequências

- Positiva: nenhuma regressão em um projeto que funciona.
- Positiva: fica registrado *por que* a exceção existe, para que ninguém a "conserte" por engano — inclusive um Claude futuro.
- Negativa: existe uma exceção à regra. Aceita, porque está documentada e é revisável.
- **Gatilho de revisão:** quando o GitHub privado estiver operante (bloco H concluído).
