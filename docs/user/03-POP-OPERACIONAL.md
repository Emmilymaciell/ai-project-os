# 03 — POP operacional

**Procedimento Operacional Padrão** do Emmily AI Project OS. Permanente: vale para todo projeto,
atual e futuro, até que um ADR diga o contrário.

| Campo | Valor |
|---|---|
| Objetivo | garantir que todo projeto nasça protegido e continue retomável sem depender de conversa, máquina ou memória |
| Escopo | projetos `PROJECT` do registry, em todas as categorias (PLATFORM, Programa, PERSONAL, UNIVERSITY, PORTFOLIO, LAB) |
| Responsável pelas decisões | a titular (Emmily) |
| Executor | o Claude (ou outra IA que leia `AGENTS.md`), seguindo este POP |
| Ferramentas | Claude Code com o plugin `os`, motor `py -3.13 -m eos`, Git, GitHub CLI (`gh`), rclone |
| Onde rodar o motor | `C:\AI-WORKSPACE\_platform\emmily-ai-project-os` |

Legenda dos checklists: **[V]** = você faz ou aprova · **[C]** = o Claude faz · **[M]** = o motor
mede, e a resposta dele vale mais que qualquer texto.

---

## POP-01 — NOVO PROJETO

`IDEIA → abrir o OS → NEW PROJECT → nascimento protegido → SESSION START → trabalho → checkpoints →
SESSION CLOSE → backup → remoto → portabilidade → recovery ready`

### 1. Ideia

- [ ] [V] Descrever a ideia em português: que problema resolve e **como saber que ficou pronto**.
- [ ] [C] Decidir se é **projeto**, **tarefa** ou **conversa**. Se for tarefa (script de uso único,
      pergunta pontual), o Claude diz isso e faz a tarefa; o POP termina aqui.

### 2. Abrir o OS

- [ ] [V] Abrir o Claude Code (qualquer pasta serve; o plugin `os` é global).
- [ ] [C] Confirmar que a plataforma responde: `py -3.13 -m eos validate` sai com `0`.

### 3. NEW PROJECT

- [ ] [V] Dizer *"Crie um projeto novo para X"* (ou `/os:new-project`).
- [ ] [C] Discovery: no máximo 4 perguntas, todas de uma vez: problema e critério de pronto;
      categoria; se toca dado corporativo, pessoal de terceiro ou confidencial; se alguma saída
      depende de julgamento de IA.
- [ ] [C] Classificar: porte, criticidade (`low`/`medium`/`high`), dados sensíveis, componente LLM.
      Sem inflar.
- [ ] [C] Propor: id em `kebab-case`, categoria, local (derivado da categoria: Programa `work\prog`, LAB `ai-lab`, demais pelo nome da categoria),
      nome do repositório privado, pasta no Drive, verificações que se aplicam.
- [ ] [V] **Aprovar o plano** (ou corrigir). Nada é criado antes do seu sim.

### 4. Nascimento protegido

- [ ] [C] Ensaiar sem efeito: `py -3.13 -m eos new <id> --name "<Nome>" --category <CAT> --dry-run`
      (não cria pasta, não grava nada, não chama GitHub nem Drive). Mostrar o plano.
- [ ] [V] Dizer "sim" ao plano. O sim autoriza o commit inicial, o remoto privado e o push.
- [ ] [C] Executar: `py -3.13 -m eos new <id> --name "<Nome>" --category <CAT> [--runtime python|node|none] [--descricao "<frase>"]`.
      Na ordem, cada passo verificado, falhando fechado sem apagar nada:
  - [ ] pasta criada pela categoria, fora de pasta sincronizada (OneDrive, Google Drive, Dropbox,
        biblioteca SharePoint);
  - [ ] template copiado, com `docs/STATE.md`, `docs/HANDOFF.md`, `docs/decisions/ADR-0001-nascimento-protegido.md`,
        `PROVENANCE.md`, `OWNERSHIP.md`, `AUTHORS.md`, `NOTICE`, `.github/CODEOWNERS`, `.env.example`,
        `.gitignore`, `.gitattributes`, `CLAUDE.md`, `AGENTS.md`, `project.yaml`, bootstrap e testes;
  - [ ] `git init` na `main` e commit inicial (assinado, porque a assinatura está ligada nesta máquina);
  - [ ] contrato `registry/projects/<id>.yaml` completo, com meta L6 e seção `ownership` — gravado
        na plataforma **sem commit**;
  - [ ] varredura de segurança no projeto **antes** do remoto (achado ALTA/MEDIA = para, nada é
        publicado);
  - [ ] remoto **privado** criado no GitHub, conferido como `PRIVATE` antes do push;
  - [ ] pasta do projeto criada no Drive;
  - [ ] primeiro backup e verificação de nível.
- [ ] [V] Se aparecer `PENDENCIA HUMANA sem remoto (H2)` (`gh repo create` negado pelo ambiente,
      `gh` sem login), o resto do nascimento já aconteceu e o projeto está em L1: resolver a
      pendência e rodar **o mesmo comando**, que faz só o remoto. Se aparecer `PAROU`, rodar o
      comando de retomada que ele imprime.
- [ ] [M] O relatório final mostra o nível atingido; `py -3.13 -m eos check <id>` confirma.

### 5. SESSION START

- [ ] [V] Abrir o Claude Code **na pasta do projeto**.
- [ ] [V] `/session-start` (ou *"onde paramos?"* / `/os:resume`).
- [ ] [C] Briefing: Git, último marco, próxima tarefa, critério de conclusão, pendências,
      divergências. Termina em *"Contexto reconstruído. Nenhuma alteração foi realizada."* e para.

### 6. Trabalho

- [ ] [V] Autorizar a próxima tarefa.
- [ ] [C] Ciclo obrigatório: INSPECT → PLAN → EXPLAIN → APPROVAL (quando relevante) → IMPLEMENT →
      TEST → QA → SECURITY → DIFF/RESULT → UPDATE STATE/DOCS.
- [ ] [C] Recomendar o modo de execução (subagente, worktrees...) quando houver benefício real.

### 7. Checkpoints

- [ ] [V] Pedir explicitamente: *"salva essa versão"* / `/os:checkpoint`.
- [ ] [C] TEST → QA (revisores se a criticidade exigir) → SECURITY → STATE + CHANGELOG +
      `project.yaml` → apresentar diff e mensagem.
- [ ] [V] Aprovar o commit.
- [ ] [C] `git add` **seletivo**, commit assinado. Tag só se for marco validado ponta a ponta, e só
      com sua confirmação.

### 8. SESSION CLOSE

- [ ] [V] `/session-close`.
- [ ] [C] Persistir no disco tudo que só existe na conversa; atualizar `STATE.md` e
      `docs/sessions/SESSIONS.md`; registrar validações **realmente executadas**; relatar o Git.
      Não commita.

### 9. Backup

- [ ] [C] `py -3.13 -m eos backup <id>`.
- [ ] [M] Saída `manifesto <carimbo>` sem `(INCOMPLETO)`. Se vier `INCOMPLETO`, ler as pendências
      (segredo, stash, submódulo) antes de seguir.
- [ ] [C] Se o contrato tem pasta `cloud-mirror` com dados: `py -3.13 -m eos mirror <id>`.
- [ ] [M] Saída sem `-- FALHOU NA VERIFICACAO` (cada pasta `ok`).

### 10. Remoto

- [ ] [V] Pedir o push: *"manda pro GitHub"*.
- [ ] [C] `/os:security` antes; push só sem achado bloqueante; remoto conferido como privado.
- [ ] [M] Dimensão `remote` em PASS: *"privado, todas as branches e tags publicadas"*.

### 11. Portabilidade

- [ ] [M] `py -3.13 -m eos check <id>`: o nível deve chegar a **L5** (ambiente reproduzível,
      segredos só por nome, caminho por variável, STATE em dia).
- [ ] [C] Para cada bloqueio listado em *"Para chegar a Lx falta"*, propor a correção.

### 12. Recovery ready

- [ ] [C] `py -3.13 -m eos certify <id>`.
- [ ] [M] `CERTIFICACAO APROVADA - nivel agora: L6`.
- [ ] [M] `eos check <id>`: *Posso apagar esta sessão? SIM*, *Posso apagar a pasta local? SIM*,
      *Posso trocar de computador? SIM*. Se algum for NÃO, o motivo diz o que falta.

**Critério de conclusão do POP-01:** projeto em L6, SAFE, com as três respostas em SIM.

---

## POP-02 — PROJETO EXISTENTE

`OS STATUS → SESSION START → WORK → CHECKPOINT → SESSION CLOSE`

### 1. OS STATUS

- [ ] [V] *"Como estão meus projetos?"* (ou `py -3.13 -m eos status`).
- [ ] [M] Conferir a linha do projeto: nível, `SAFE`/`AT_RISK`/`UNSAFE`, `OK`/`DEGRADED`.
- [ ] [C] Se o projeto caiu de nível desde a última vez, dizer **por quê** antes de começar
      (`eos check <id>`).

### 2. SESSION START

- [ ] [V] Claude Code na pasta do projeto, `/session-start` (ou `/os:resume`).
- [ ] [C] Separar *"último resultado registrado"* de *"verificado agora"*. Nunca apresentar
      resultado antigo como recém-executado.
- [ ] [C] Mostrar toda divergência entre `STATE.md` e Git, sem corrigir em silêncio.
- [ ] [V] Ler o briefing e autorizar a tarefa.

### 3. WORK

- [ ] [C] Ciclo INSPECT → ... → UPDATE STATE/DOCS.
- [ ] [C] Ação destrutiva, autenticação, decisão material ou incidente: **parar** com
      `HUMAN ACTION REQUIRED` (H1–H5).
- [ ] [C] Antes de qualquer coisa arriscada, `eos backup <id>` primeiro.

### 4. CHECKPOINT

- [ ] [V] *"salva essa versão"* quando quiser uma versão no histórico.
- [ ] [C] Sequência completa do `/os:checkpoint`; commit só depois do seu sim.

### 5. SESSION CLOSE

- [ ] [V] `/session-close`.
- [ ] [C] `eos backup <id>` se houver WIP ou banco alterado (pergunte se quiser pular).
- [ ] [C] Se o projeto tem pasta `cloud-mirror` e ela mudou na sessão: espelhar os dados,
      `eos mirror <id>` (pergunte se quiser pular).
- [ ] [M] `eos check <id>`: *Posso apagar esta sessão?*

**Critério de conclusão do POP-02:** `STATE.md` diz o próximo passo exato, e *Posso apagar esta
sessão?* responde SIM.

---

## POP-03 — Rotina periódica

| Quando | O quê | Comando |
|---|---|---|
| fim de cada dia de trabalho num projeto | backup | `py -3.13 -m eos backup <id>` |
| fim do dia, se a pasta `cloud-mirror` mudou | espelhar os dados | `py -3.13 -m eos mirror <id>` |
| semanal | retrato do portfólio | `py -3.13 -m eos status` |
| a cada 30 dias, por projeto L6 | recertificar (a certificação vence em 30 dias e o projeto cai para L5) | `py -3.13 -m eos certify <id>` |
| antes de push, release ou handoff | varredura de segurança | `/os:security` |
| antes de trocar de computador | backup, espelho dos dados e prontidão | `py -3.13 -m eos backup --todos`, depois `py -3.13 -m eos mirror --todos`, depois `py -3.13 -m eos prepare-machine-migration` |
| quando um contrato for editado | validação | `py -3.13 -m eos validate` |

---

## POP-04 — Antes de apagar qualquer coisa

1. [M] `eos check <id>` responde SIM para a pergunta certa (sessão, pasta ou computador).
2. [C] Mostrar onde está a cópia protegida e como foi verificada.
3. [C] Mostrar o espaço que será liberado, o risco e o caminho de volta (rollback).
4. [V] Aprovar explicitamente (gate H3).
5. [C] Executar só o que foi aprovado, nada além.

Sem os quatro primeiros passos, não se apaga nada.

---

## POP-05 — Incidente de segurança

Gatilhos: segredo real versionado, credencial exposta num log, suspeita de comprometimento, token no
histórico.

1. [C] Parar com `HUMAN ACTION REQUIRED — Gate: H5`. Não reproduzir o valor em lugar nenhum.
2. [V] Rotacionar a credencial na origem (GitHub, Google, Microsoft, serviço da API).
3. [C] Propor a sanitização do histórico, se o segredo estiver no Git. Reescrever histórico é H3:
      original preservado no Drive com hash antes, plano simulado, sua aprovação.
4. [M] `eos check <id>`: dimensão `secrets` volta a PASS.
5. [C] Registrar o incidente no `STATE.md` do projeto (sem o valor).
