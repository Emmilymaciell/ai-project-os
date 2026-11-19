# 04 — Fluxogramas de uso

Os diagramas estão em Mermaid: o GitHub e o VS Code os desenham automaticamente. Legenda das cores:
**azul** = você; **verde** = resultado seguro; **laranja** = o Claude para e pede você (human gate).

Índice: [1. Projeto novo](#1-projeto-novo) · [2. Projeto existente](#2-projeto-existente) ·
[3. Ciclo de sessão](#3-ciclo-de-sessão) · [4. Backup](#4-backup) · [5. Restore](#5-restore) ·
[6. Migração de máquina](#6-migração-de-máquina) · [7. Human gates](#7-human-gates) ·
[8. Ownership](#8-ownership) · [9. Disaster recovery](#9-disaster-recovery)

---

## 1. Projeto novo

```mermaid
flowchart TD
    A["Ideia"]:::voce --> B{"É projeto?<br/>tem continuidade e estado"}
    B -- "não: tarefa ou conversa" --> B1["O Claude faz a tarefa<br/>sem criar projeto"]
    B -- "sim" --> C["/os:new-project<br/>ou: Crie um projeto novo para X"]
    C --> D["Discovery<br/>até 4 perguntas"]
    D --> E["Classificação<br/>categoria, criticidade, dados sensíveis"]
    E --> F["Plano: id, local, repo privado,<br/>pasta no Drive, verificações"]
    G{"Você aprova?"}:::voce
    G -- "corrige" --> F
    F --> H["eos new --dry-run<br/>plano sem efeito"]
    H --> G
    G -- "sim" --> I["eos new: pasta pela categoria +<br/>template + arquivos de ownership"]
    I --> J["git init + commit inicial assinado"]
    J --> K["Contrato no registry<br/>(plataforma sem commit)"]
    K --> SC{"Varredura de segurança<br/>security-scan.ps1: achado?"}
    SC -- "ALTA/MEDIA ou não concluiu" --> SC1["PAROU: nada criado<br/>nem enviado ao GitHub"]:::gate
    SC -- "limpa" --> L{"gh repo create --private<br/>permitido?"}
    L -- "negado / sem login" --> L1["PENDENCIA HUMANA H2<br/>sem remoto: segue em L1"]:::gate
    L1 --> N
    L -- "sim" --> M["Visibilidade conferida PRIVATE + push"]
    M --> N["Pasta criada no Drive"]
    N --> O["Primeiro backup + nível atingido"]
    L1 -.->|"resolvida: mesmo comando,<br/>varre de novo e faz só o remoto"| SC
    O --> P["/session-start na pasta do projeto"]
    P --> Q["Trabalho + checkpoints a seu pedido"]
    Q --> R["/session-close"]
    R --> S["eos backup<br/>+ eos mirror se houver pasta cloud-mirror"]
    S --> T["eos certify"]
    T --> U["L6 · SAFE · três respostas SIM"]:::ok

    classDef voce fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
    classDef gate fill:#ffedd5,stroke:#c2410c,color:#111
```

---

## 2. Projeto existente

```mermaid
flowchart TD
    A["Como estão meus projetos?"]:::voce --> B["eos status"]
    B --> C{"Nível caiu<br/>desde a última vez?"}
    C -- "sim" --> C1["eos check id:<br/>motivo e o que falta"]
    C1 --> D
    C -- "não" --> D["Claude Code na pasta do projeto"]
    D --> E["/session-start ou /os:resume"]
    E --> F["Briefing + divergências<br/>o Claude PARA"]
    F --> G{"Você autoriza<br/>a próxima tarefa?"}:::voce
    G -- "sim" --> H["INSPECT, PLAN, IMPLEMENT,<br/>TEST, QA, SECURITY"]
    H --> I{"Pediu para salvar versão?"}:::voce
    I -- "sim" --> J["/os:checkpoint<br/>diff + seu sim + commit"]
    I -- "não" --> K
    J --> K["/session-close"]
    K --> L["eos backup se houver WIP<br/>eos mirror se a pasta cloud-mirror mudou"]
    L --> M["Posso apagar esta sessão? SIM"]:::ok

    classDef voce fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
```

---

## 3. Ciclo de sessão

```mermaid
flowchart LR
    S1["/session-start<br/>somente leitura"] --> S2["Briefing<br/>Nenhuma alteração foi realizada"]
    S2 --> S3["Trabalho autorizado"]
    S3 --> S4{"salva essa versão?"}
    S4 -- "sim" --> S5["/os:checkpoint<br/>commit com seu sim"]
    S5 --> S3
    S4 -- "não" --> S6["/session-close"]
    S5 --> S6
    S6 --> S7["Persistir o que só está na conversa"]
    S7 --> S8["STATE.md + SESSIONS.md"]
    S8 --> S9["Relatório + Git final<br/>Handoff concluído"]
    S9 --> S10["eos check id:<br/>Posso apagar esta sessão?"]
```

O `/session-close` **não** commita. Commit é sempre `/os:checkpoint`, a seu pedido.

---

## 4. Backup

```mermaid
flowchart TD
    A["eos backup id"] --> B{"Pasta existe e<br/>é repositório Git?"}
    B -- "não" --> B1["ERRO: COLLECTION usa outro caminho<br/>ou caminho inexistente"]
    B -- "sim" --> C["Aviso: sem criptografia no cliente"]
    C --> D["A. git bundle --all + verify<br/>sem refs/stash"]
    D --> E["B. wip.tar.gz de todas<br/>as worktrees sujas"]
    E --> F["C. snapshot SQLite<br/>dos bancos declarados"]
    F --> G["Upload de cada artefato<br/>para 99 RECOVERY"]
    G --> H{"Hash confere?"}
    H -- "não" --> H1["Falha: nenhum manifesto<br/>backup NÃO existe"]
    H -- "sim" --> I{"Há pendências?<br/>segredo, stash, submódulo"}
    I -- "sim" --> J["Manifesto gravado POR ÚLTIMO<br/>marcado INCOMPLETO"]
    I -- "não" --> K["Manifesto gravado POR ÚLTIMO"]:::ok
    J --> L["eos check reprova backup<br/>até resolver"]

    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
```

O backup protege o projeto. As pastas de dados `cloud-mirror` (fora do Git) têm o próprio
comando, o espelho:

```mermaid
flowchart TD
    A["eos mirror id<br/>ou: espelhe os dados"]:::voce --> B{"Contrato tem data[]<br/>cloud-mirror e drive_root?"}
    B -- "não" --> B1["ERRO: nada copiado"]
    B -- "sim" --> C["Inventário local:<br/>tamanho, data, md5"]
    C --> D["Recusa nome de segredo<br/>e symlink/junção"]
    D --> E["Inventário da nuvem<br/>drive_root/dados/pasta"]
    E --> F{"Mesmo tamanho e md5<br/>já na nuvem?"}
    F -- "sim" --> F1["Não sobe de novo"]
    F -- "não, arquivo novo" --> G["Copia"]
    F -- "não, arquivo alterado" --> G1["Versão anterior vai antes para<br/>dados-anteriores/carimbo/"]
    G1 --> G
    F1 --> H
    G --> H{"Depois da cópia: cada arquivo<br/>confere tamanho e md5?<br/>nada mudou durante?"}
    H -- "não" --> H1["Manifesto ok: false<br/>não conta: rode de novo"]
    H -- "sim" --> I["Manifesto mirror-carimbo.json<br/>na nuvem + journal da máquina"]:::ok
    I --> J["eos check: pasta coberta enquanto<br/>cada arquivo tiver o mesmo<br/>tamanho e data do espelho"]

    classDef voce fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
```

Nada é apagado na nuvem: arquivo que sumiu daqui continua em `dados/`.

---

## 5. Restore

```mermaid
flowchart TD
    A["Restaure este projeto"]:::voce --> B["eos restore id --para pasta"]
    B --> C{"Destino vazio<br/>ou inexistente?"}
    C -- "não" --> C1["Recusa: sobrescrever é H3"]:::gate
    C -- "sim" --> D{"--fonte"}
    D -- "auto" --> E["Clone do GitHub<br/>+ refs que só o bundle tem"]
    D -- "github" --> F["Clone do GitHub"]
    D -- "cloud" --> G["Bundle do Drive"]
    E --> H["Validar manifesto como dado não confiável:<br/>caminhos, refs, sha"]
    F --> H
    G --> H
    H --> I["Conferir SHA-256 de cada artefato"]
    I --> J["Aplicar WIP e restaurar bancos"]
    J --> K["Verificar: refs, HEAD, impressão do WIP,<br/>integrity_check dos bancos"]
    K --> CD{"--com-dados?"}
    CD -- "não" --> L
    CD -- "sim" --> CD1["Último espelho verificado:<br/>baixa cada pasta cloud-mirror<br/>e confere tamanho e md5"]
    CD1 --> CD2{"Arquivo já trazido pelo Git<br/>com outro conteúdo?"}
    CD2 -- "sim" --> CD3["Não sobrescreve:<br/>conflito, reprova"]
    CD2 -- "não" --> L
    CD3 --> L
    L{"Tudo ok?"}
    L -- "sim" --> M["RESTORE VERIFICADO"]:::ok
    L -- "não" --> N["RESTORE COM FALHA<br/>e o motivo"]

    classDef voce fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
    classDef gate fill:#ffedd5,stroke:#c2410c,color:#111
```

---

## 6. Migração de máquina

```mermaid
flowchart TD
    subgraph ANTIGA["Máquina antiga"]
        A1["Posso trocar de computador?"]:::voce --> A0["eos backup --todos<br/>eos mirror --todos"]
        A0 --> A2["eos prepare-machine-migration"]
        A2 --> A3{"PRONTO?"}
        A3 -- "não" --> A4["Resolver bloqueios por projeto:<br/>backup, push, .env para o cofre,<br/>declarar dados, eos mirror id"]
        A4 --> A2
        A3 -- "sim" --> A5["Guardar machine.yaml<br/>e listar logins necessários"]
    end
    subgraph NOVA["Máquina nova"]
        B1["Instalar Git, Python 3.13,<br/>gh, rclone, Claude Code"] --> B2["H1: gh auth login,<br/>rclone config, /login, Bitwarden"]:::gate
        B2 --> B3["Clonar a plataforma<br/>bootstrap.ps1 + plugin"]
        B3 --> B4["Recriar machine.yaml"]
        B4 --> B5["Nova chave de assinatura<br/>registrar no GitHub: H1"]:::gate
        B5 --> B6["eos restore cada projeto<br/>--com-dados se houver pasta cloud-mirror"]
        B6 --> B7["eos status: tudo SAFE"]:::ok
    end
    A5 --> B1
    B7 --> C["Só então: apagar a antiga? H3"]:::gate

    classDef voce fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
    classDef gate fill:#ffedd5,stroke:#c2410c,color:#111
```

---

## 7. Human gates

```mermaid
flowchart TD
    A["O Claude vai executar uma ação"] --> B{"Exige login, 2FA,<br/>OAuth ou unlock do cofre?"}
    B -- "sim" --> H1["H1 Autenticação"]:::gate
    B -- "não" --> C{"O ambiente bloqueou<br/>e pede permissão externa?"}
    C -- "sim" --> H2["H2 Permissão externa"]:::gate
    C -- "não" --> D{"Apaga, sobrescreve,<br/>reescreve histórico ou<br/>descarta WIP/backup?"}
    D -- "sim" --> H3["H3 Destrutivo"]:::gate
    D -- "não" --> E{"2+ alternativas plausíveis,<br/>sem evidência, mudança material?"}
    E -- "sim" --> H4["H4 Decisão da titular"]:::gate
    E -- "não" --> F{"Segredo exposto ou<br/>suspeita de comprometimento?"}
    F -- "sim" --> H5["H5 Incidente de segurança"]:::gate
    F -- "não" --> G["Segue sozinho<br/>sem perguntar"]:::ok
    H1 --> P["PARA em estado seguro:<br/>HUMAN ACTION REQUIRED"]
    H2 --> P
    H3 --> Q["Proteção e rollback<br/>PROVADOS antes"]
    Q --> P
    H4 --> P
    H5 --> P
    P --> R["Você age"]:::voce
    R --> S["O Claude reconcilia o estado<br/>e continua de onde parou"]

    classDef voce fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
    classDef gate fill:#ffedd5,stroke:#c2410c,color:#111
```

---

## 8. Ownership

```mermaid
flowchart TD
    A["Qual é a propriedade deste projeto?"]:::voce --> B["eos ownership-check id"]
    B --> C["declared_owner:<br/>titular e criadoras no contrato"]
    B --> D["ownership_files, notice, license:<br/>PROVENANCE, OWNERSHIP, AUTHORS, NOTICE"]
    B --> E["git_identities: autores do git log<br/>(sem .mailmap) explicados por identities,<br/>creators, contributors ou tool_accounts"]
    B --> F["signing: assinatura configurada,<br/>% de commits G (só G conta);<br/>B/R em qualquer commit = FAIL"]
    B --> G["remote_owner + codeowners:<br/>dono do remoto = owner_github"]
    B --> G2["manifest + contradictions:<br/>certificado em dia, autoria no texto"]
    C --> H{"Algum FAIL?"}
    D --> H
    E --> H
    F --> H
    G --> H
    G2 --> H
    H -- "sim" --> I["Corrigir: declarar contribuidor,<br/>configurar assinatura, ajustar remoto"]
    I --> B
    H -- "não (WARN não bloqueia)" --> J["eos ownership-certify id"]
    J --> K["Certificado JSON: 99 RECOVERY/manifests/id/<br/>ownership-carimbo.json + journal da máquina"]
    K --> L{"--tag?"}
    L -- "sim" --> M["Tag assinada ownership-AAAAMMDD<br/>depois: eos backup + publicar a tag"]:::ok
    L -- "não" --> N["Certificado gravado"]:::ok

    classDef voce fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
```

---

## 9. Disaster recovery

```mermaid
flowchart TD
    A{"O que foi perdido?"} -- "o chat / a sessão" --> B["/session-start na pasta:<br/>STATE + ADRs + Git"]:::ok
    A -- "a pasta local" --> C["eos restore id --para pasta vazia<br/>--com-dados se houver pasta cloud-mirror"]
    A -- "um arquivo de dados" --> DD["eos restore id --para pasta nova --com-dados<br/>e copiar o arquivo; versão mais antiga:<br/>dados-anteriores/carimbo/ no Drive"]
    A -- "o computador inteiro" --> D["Máquina nova: fluxo 6"]
    A -- "o GitHub" --> E["eos restore id --fonte cloud<br/>bundle do Drive"]
    A -- "acesso ao Drive pelo rclone" --> F["machine.yaml:<br/>cloud.transport drive-desktop"]
    F --> C
    D --> C
    E --> G["Conferir refs, HEAD,<br/>WIP, bancos e dados"]
    C --> G
    G --> H["eos certify id"]
    H --> I["L6 de volta"]:::ok
    A -- "um segredo vazou" --> J["H5: rotacionar na origem"]:::gate

    classDef ok fill:#dcfce7,stroke:#15803d,color:#111
    classDef gate fill:#ffedd5,stroke:#c2410c,color:#111
```

Detalhes de cada cenário em [08 — Backup e recovery](08-BACKUP-E-RECOVERY.md). A certificação
(`eos certify`) não baixa as pastas `cloud-mirror`; quem baixa e confere é o
`eos restore ... --com-dados`.
