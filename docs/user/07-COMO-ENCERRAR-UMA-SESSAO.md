# 07 — Como encerrar uma sessão

> **Se esta conversa desaparecer agora, nenhum conhecimento importante pode desaparecer junto.**

## 1. Como pedir

`/session-close`, ou *"encerra a sessão"*. A partir daí o desenvolvimento **para**: nada de começar
funcionalidade nova, refatorar de oportunidade ou corrigir coisa não relacionada.

## 2. Encerrar não é salvar versão

| | `/session-close` | `/os:checkpoint` |
|---|---|---|
| Para que serve | não perder conhecimento | pôr uma versão no histórico do Git |
| Faz commit? | **não** | sim, depois do seu sim |
| Atualiza `STATE.md`? | sim | sim |
| Quando | sempre que parar de trabalhar | só quando você pedir |

Se quiser as duas coisas, peça as duas: *"salva essa versão e encerra a sessão"*.

## 3. O que acontece, passo a passo

| # | Passo | Detalhe |
|---|---|---|
| 1 | reconciliar | branch, HEAD, `git status`, últimos commits. O que a sessão **acredita** ter feito é confrontado com o que o Git **mostra**; vence o Git |
| 2 | a pergunta obrigatória | *existe informação importante que está só nesta conversa?* Cada item é classificado: concluído, parcial, investigado e não implementado, decisão, descoberta, hipótese, bug, risco, pendência, bloqueio, pergunta aberta, arquivo criado ou alterado, alteração não commitada |
| 3 | persistir | cada item vai para o lugar certo (tabela abaixo) |
| 4 | validar | roda só o que o trabalho justifica, do mais barato ao mais caro, e registra **o comando exato e o resultado real**. O que não rodou entra como *não executado*, com motivo e risco |
| 5 | atualizar o estado | `STATE.md`: fase, último marco, trabalho em andamento, **próximo passo exato**, pendências, bloqueios |
| 6 | registrar a sessão | um bloco no topo de `docs/sessions/SESSIONS.md` |
| 7 | Git | relata branch, HEAD e se a working tree está limpa. **Não commita.** Não faz push |
| 8 | próxima unidade | **uma** ação executável, com objetivo e critério de conclusão. Nunca "continuar o trabalho" |
| 9 | relatório | termina com *"Handoff concluído. Nenhuma nova implementação foi iniciada."* e para |

Na validação (passo 4), em projeto com seção `ownership` no contrato (hoje, todo `PROJECT`), o
encerramento também roda `py -3.13 -m eos ownership-check <id>`. É só leitura e não muda o nível
L0–L6; um FAIL (por exemplo, um autor fora da declaração) entra no relatório como inconsistência e
**não** é corrigido no encerramento.

### Onde cada coisa vai parar

| Informação | Destino |
|---|---|
| estado operacional atual | `docs/STATE.md` |
| decisão durável | `docs/decisions/ADR-NNNN-<assunto>.md` (só se restringir o futuro) |
| o que mudou no produto | `CHANGELOG.md` |
| armadilha técnica que custou tempo | `docs/runbooks/` |
| histórico compacto da sessão | `docs/sessions/SESSIONS.md` |
| passagem para outra pessoa ou máquina | `/os:handoff` → `docs/handoff/` (não é rotina de toda sessão) |
| evidência de execução (diff, scan, doctor) | `artifacts/` — **ignorado pelo Git, não viaja num clone** |

`STATE.md` é **snapshot**, não diário: informação velha é corrigida ou removida. O histórico vai para
`SESSIONS.md`.

## 4. O relatório final

```
SESSÃO         <N> — <nome> · <objetivo>
REPOSITÓRIO    <raiz> · branch · HEAD · working tree limpa | n alterações

CONCLUÍDO / PARCIALMENTE CONCLUÍDO / INVESTIGADO, NÃO IMPLEMENTADO
DESCOBERTAS / DECISÕES DURÁVEIS / HIPÓTESES ABERTAS
VALIDAÇÕES EXECUTADAS        <comando exato> → <resultado real>
VERIFICAÇÕES NÃO EXECUTADAS  <motivo e risco residual>
ALTERAÇÕES NÃO COMMITADAS
PRÓXIMO PASSO EXATO
GIT FINAL      branch · HEAD · status · push: feito | não feito

Handoff concluído. Nenhuma nova implementação foi iniciada.
```

## 5. "Posso apagar essa sessão?"

Depois do encerramento, pergunte isso ao Claude. Por baixo:

```powershell
py -3.13 -m eos check <id>
```

A linha *Posso apagar esta sessão?* responde **SIM** só quando:

1. a dimensão `state` está em PASS: os arquivos canônicos existem e o `STATE.md` não é mais velho
   que o último commit por mais de 1 dia; **e**
2. não há WIP desprotegido: ou a working tree está limpa, ou o último backup tem o WIP atual
   (mesma impressão digital).

Se responder NÃO, o motivo vem junto. Os dois casos comuns:

| Motivo | O que fazer |
|---|---|
| `trabalho nao commitado sem snapshot atual` | `py -3.13 -m eos backup <id>` e perguntar de novo |
| `estado canonico: ... mais velho que o ultimo commit` | atualizar o `STATE.md` (o `/session-close` faz isso) |

"Apagar a sessão" é apagar a **conversa**. Apagar a **pasta** do projeto é outra pergunta, com outra
exigência (ver [08](08-BACKUP-E-RECOVERY.md) e [13](13-HEALTH-E-CONTINUITY.md)).

## 6. Checklist de fim de sessão

- [ ] `/session-close` concluído, terminando com a frase de handoff.
- [ ] `STATE.md` diz o próximo passo exato.
- [ ] Se quiser versão no histórico: *"salva essa versão"* (antes ou depois do close).
- [ ] `py -3.13 -m eos backup <id>` se houve WIP ou banco alterado.
- [ ] `py -3.13 -m eos mirror <id>` se o projeto tem pasta `cloud-mirror` e ela mudou (*"espelhe
      os dados"*); ver [08](08-BACKUP-E-RECOVERY.md), seção 4.
- [ ] Se for o caso, *"manda pro GitHub"*.
- [ ] `eos check <id>` → *Posso apagar esta sessão? SIM*.
