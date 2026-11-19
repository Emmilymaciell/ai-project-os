---
name: session-close
description: Encerra a sessão: para o desenvolvimento, reconcilia o estado real, persiste no repositório o que só existe na conversa, atualiza STATE e o registro de sessões, confere o Git e PARA. Use SOMENTE por pedido explícito, ou /session-close.
disable-model-invocation: true
---

# /session-close

**Se esta conversa desaparecer agora, nenhum conhecimento importante pode desaparecer junto.**

Esta skill é o protocolo oficial de encerramento. Ao ser invocada, o desenvolvimento **para**.

> **Não é um `/os:checkpoint`.** Encerrar sessão não é salvar versão, e **não implica commit**. A regra de ouro deste repositório continua valendo: `git add` / `commit` / `tag` só quando a mantenedora pedir com todas as letras. Ver §7.

## Proibido durante o encerramento

Começar funcionalidade nova · iniciar a próxima tarefa · refatorar de oportunidade · aumentar escopo · corrigir coisa não relacionada · descartar, esconder ou resetar alteração · `stash` desnecessário · declarar como executado um teste que não rodou · declarar investigação como implementação, intenção como resultado, ou hipótese como fato.

## 1. Reconciliar o estado real

```bash
pwd && git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD && git rev-parse HEAD && git rev-parse --short HEAD
git status --porcelain
git log --format='%h %ad %s' --date=short -10
```

Confronte o que a sessão **acredita** ter feito com o que o Git e o disco **mostram**. A realidade verificável prevalece. Divergência se registra, não se apaga.

## 2. A pergunta obrigatória

> **Existe alguma informação importante que está apenas no contexto desta conversa?**

Varra a sessão e classifique cada coisa, sem misturar as categorias:

concluído · parcialmente concluído · investigado e **não** implementado · decisão tomada · descoberta · hipótese · hipótese descartada · bug encontrado · limitação · risco · pendência · bloqueio · pergunta aberta · arquivo criado · arquivo modificado · artefato gerado · alteração ainda não commitada.

Tudo que estiver só na conversa e importar para a próxima sessão **vai para o disco antes de encerrar**.

## 3. Onde cada coisa pertence neste projeto

Use o que já existe. **Não crie arquitetura paralela.**

| Tipo de informação | Destino canônico |
|---|---|
| estado operacional atual | `docs/STATE.md` |
| decisão arquitetural durável | `docs/decisions/ADR-NNNN-<slug>.md` |
| o que mudou no produto | `CHANGELOG.md` |
| armadilha técnica que custou tempo | `docs/runbooks/` |
| histórico compacto da sessão | `docs/sessions/SESSIONS.md` |
| handoff para outra pessoa/máquina | `/os:handoff` → `docs/handoff/` |
| evidência de execução (diff, scan, doctor) | `artifacts/` — **ignorado pelo Git, não viaja** |

**`docs/STATE.md` é snapshot, não diário.** Ele responde *onde o projeto está*; o que aconteceu nesta sessão vai para `docs/sessions/SESSIONS.md`. Informação obsoleta no `STATE.md` se **corrige ou se remove** — não se acumula.

**ADR só para decisão durável de verdade.** Não crie um para preencher documentação. Quando criar: contexto, decisão, motivo, alternativas consideradas, consequências, restrições.

## 4. Validação — comando exato e resultado real

Rode apenas o que o trabalho desta sessão justifica, do mais barato para o mais caro:

1. os testes diretamente relacionados — `.\tests\run-tests.ps1 -Suite <nome>`
2. regressão relevante
3. `scripts/doctor.ps1` (~2 s)
4. a suíte completa — `.\tests\run-tests.ps1` (~14 min), quando a mudança for ampla
5. `security-scan.ps1`, quando a sessão tocou em coleta, segredo ou `.gitignore`
6. `py -3.13 -m eos ownership-check <id>`, quando o contrato do projeto em `registry/projects/<id>.yaml` tiver seção `ownership`. É só leitura e não muda o nível L0–L6. `FAIL`, por exemplo um autor fora da declaração, vai para o relatório como inconsistência. Não se corrige no encerramento.

Registre **o comando exato e o resultado real**. Nunca escreva "os testes passaram" sem execução. O que não puder ser executado entra como **verificação não executada, com o motivo e o risco residual** — é a política 4.5 aplicada ao encerramento: ausência de evidência nunca vira aprovação.

## 5. Atualizar o estado

`docs/STATE.md`: fase atual, último marco comprovado, trabalho em andamento, **próximo passo exato**, pendências, bloqueios, decisões abertas, última validação. Corrija contagens que a sessão tornou falsas — o cabeçalho declara `- **Testes:** N/N passando`, e há detector que confere isso contra o disco.

## 6. Registrar a sessão

Acrescente **um bloco** no topo de `docs/sessions/SESSIONS.md`, seguindo o formato documentado em `docs/sessions/README.md`. Compacto: o registro de sessão não é documentação extensa, e não repete o que o `STATE.md` já diz.

## 7. Git — política do projeto, não automatismo

**Não commite porque a sessão acabou.** Commite **somente** se a mantenedora pedir nesta sessão ("salva essa versão", "commita", "atualiza o git", `/os:checkpoint`, `/versionar`).

Quando ela pedir, o caminho é `/os:checkpoint`, e a sequência obrigatória é: `status` → `diff` → security scan → resumo → **`add` seletivo**. Nunca `git add .` às cegas.

**Nunca** por iniciativa própria: `push`, `reset --hard`, `checkout --`, `clean -fd`, `rebase`, `commit --amend`, `push --force`, trocar de branch.

Ao final, reconfirme e relate: branch, `HEAD`, `git status`, e se a working tree está limpa.

## 8. A próxima unidade concreta

**Uma** ação executável. Nada de "continuar o trabalho" ou "dar prosseguimento". Informe objetivo, critério de conclusão, dependências, arquivos de alto sinal, riscos, verificações esperadas e skills/subagentes recomendados.

## 9. Relatório final

```
SESSÃO         <N> — <nome> · <objetivo>
REPOSITÓRIO    <raiz> · branch <b> · HEAD <curto> · working tree <limpa | n alterações>

CONCLUÍDO
PARCIALMENTE CONCLUÍDO
INVESTIGADO / NÃO IMPLEMENTADO
DESCOBERTAS IMPORTANTES
DECISÕES DURÁVEIS            <com o número do ADR, se criado>
HIPÓTESES / QUESTÕES ABERTAS

VALIDAÇÕES EXECUTADAS
  <comando exato> → <resultado real>
VERIFICAÇÕES NÃO EXECUTADAS  <com motivo e risco residual>

ALTERAÇÕES NÃO COMMITADAS
DOCUMENTAÇÃO ATUALIZADA
INCONSISTÊNCIAS ENCONTRADAS  <ou "nenhuma">

PRÓXIMO PASSO EXATO
ARQUIVOS DE ALTO SINAL PARA A PRÓXIMA SESSÃO
SKILLS / SUBAGENTES RECOMENDADOS
RISCOS / BLOQUEIOS

GIT FINAL      branch <b> · HEAD <curto> · status <...> · push: <feito | não feito>
```

Termine **exatamente** com:

```
Handoff concluído. Nenhuma nova implementação foi iniciada.
```

E **pare**.

## Anti-falsos-positivos

- **"Terminei" não é pedido de commit.** Nem "ficou bom", nem "pronto", nem "funcionou".
- **Não gere `/os:handoff` por rotina.** Ele é o documento pesado de portabilidade, para outra pessoa ou máquina assumir — não o fecho de toda sessão.
- **Não transforme `STATE.md` em diário.** O histórico é `docs/sessions/SESSIONS.md`.
- **Não registre ADR para decisão que não restringe nada** no futuro.
- **Não apague alteração não relacionada** que a mantenedora deixou na working tree. Ela aparece no relatório, intacta.
- **Não declare limpo o que não foi varrido.** Se o scan não rodou, diga que não rodou.
- **Não encerre apagando a divergência.** Se o `STATE.md` dizia uma coisa e o Git mostra outra, o relatório registra as duas e diz qual venceu.
