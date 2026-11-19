# 01 — Guia rápido

Uma página. O resto da documentação detalha o que está aqui.

## O dia a dia em 6 passos

```
1. ABRIR      Claude Code na pasta do projeto  →  /session-start   (ou "onde paramos?")
2. LER        o briefing: último marco, próxima tarefa, pendências. O Claude PARA aqui.
3. TRABALHAR  "pode seguir com a próxima tarefa"  (o Claude implementa e testa)
4. SALVAR     "salva essa versão"                 →  /os:checkpoint (só quando você pedir)
5. PROTEGER   "faça backup deste projeto"         →  eos backup <id>
              (+ "espelhe os dados" se o projeto tem pasta cloud-mirror e ela mudou → eos mirror <id>)
6. FECHAR     /session-close                      →  STATE atualizado; "posso apagar a sessão?"
```

Você não precisa decorar comandos. Fale em português; o Claude reconhece a intenção.

## Frases que funcionam, e o que acontece por baixo

| Você diz | O que acontece por baixo |
|---|---|
| "Como estão meus projetos?" | `py -3.13 -m eos status`: uma linha por projeto com nível (L0–L6), segurança, operação e as três respostas |
| "Onde eu estava?" / "Onde paramos?" | `/os:resume` ou `/session-start`: lê `STATE.md`, decisões e Git; mostra o briefing e para |
| "Crie um projeto novo para X" | `/os:new-project`: discovery, classificação, plano, sua aprovação, `eos new ... --dry-run`, seu sim, depois o nascimento protegido (`eos new`): pasta, commit inicial assinado, contrato, remoto privado, Drive e primeiro backup |
| "Esse projeto está seguro?" | `py -3.13 -m eos check <id>`: nível, as 8 dimensões da escada (mais `ownership`, informativa) e o que falta para o próximo nível |
| "Esse projeto está L6?" | o mesmo `eos check <id>`; L6 exige restauração certificada nos últimos 30 dias |
| "Faça backup" | `py -3.13 -m eos backup <id>`: bundle Git + WIP + bancos no Drive, conferidos por hash |
| "Espelhe os dados deste projeto" | `py -3.13 -m eos mirror <id>`: copia as pastas `cloud-mirror` para `<drive_root>/dados/` no Drive, só o que mudou, conferido por tamanho e md5; nunca apaga nada lá (a versão anterior vai para `dados-anteriores/`) |
| "Qual foi o último backup?" | `py -3.13 -m eos check <id> --json` → campo `dimensoes.backup.ultimo` (carimbo UTC, ex.: `20261011T183857Z`), que é o nome do último manifesto em `99 RECOVERY/manifests/<id>/` |
| "Posso apagar essa sessão?" | `eos check <id>` → linha *Posso apagar esta sessão?* (exige STATE em dia e WIP protegido) |
| "Posso apagar esse clone?" | `eos check <id>` → linha *Posso apagar a pasta local?* (exige L3+ e nada que exista só ali) |
| "Posso trocar de computador?" | `py -3.13 -m eos prepare-machine-migration`: lista, projeto a projeto, o que bloqueia. Antes: `eos backup --todos` e, se houver pastas `cloud-mirror`, `eos mirror --todos` |
| "Restaure este projeto" | `py -3.13 -m eos restore <id> --para <pasta vazia>`: nunca por cima de pasta existente. *"...com os dados"* acrescenta `--com-dados`: baixa o último espelho `cloud-mirror` e confere cada arquivo |
| "Qual é a propriedade/proveniência deste projeto?" | `py -3.13 -m eos ownership-check <id>` (só lê; PASS/WARN/FAIL/N/A por item) + leitura de `PROVENANCE.md`/`OWNERSHIP.md` |
| "Salva essa versão" / "commita" | `/os:checkpoint`: testes → QA → segurança → STATE → diff → **seu sim** → commit |
| "Encerra a sessão" | `/session-close`: persiste o que só está na conversa, atualiza STATE e registro de sessões |

## Comandos do motor (PowerShell, na raiz da plataforma)

```powershell
cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os

py -3.13 -m eos status                          # todos os projetos
py -3.13 -m eos check prog-relatorio-g2         # um projeto, com as respostas SIM/NÃO
py -3.13 -m eos backup prog-relatorio-g2        # backup verificado na nuvem
py -3.13 -m eos backup --todos                  # backup de todos os PROJECT
py -3.13 -m eos mirror prog-relatorio-g2        # espelho conferido das pastas cloud-mirror
py -3.13 -m eos certify prog-relatorio-g2       # prova de restauração (L6)
py -3.13 -m eos restore prog-relatorio-g2 --para C:\Temp\restauro-g2
py -3.13 -m eos restore prog-relatorio-g2 --para C:\Temp\restauro-g2b --com-dados   # + dados
py -3.13 -m eos prepare-machine-migration       # posso trocar de PC?
py -3.13 -m eos validate                        # os contratos estão bem escritos?
```

Códigos de saída do motor: `0` ok · `1` alguma verificação reprovou ou algo não é seguro ·
`2` erro de uso ou de execução.

## Comandos do plugin (dentro do Claude Code, em qualquer pasta)

| Comando | Para |
|---|---|
| `/os:status` | onde estou, o que falta |
| `/os:resume` | retomar um projeto parado |
| `/os:new-project` | criar um projeto |
| `/os:checkpoint` | salvar versão verificada (só a seu pedido) |
| `/os:doctor` | o projeto é coerente e retomável? |
| `/os:security` | varredura de segredos e dados sensíveis |
| `/os:handoff` | documento para outra pessoa/máquina assumir |

E o protocolo de sessão: `/session-start` e `/session-close`. Hoje essas duas skills moram em
`.claude/skills/` **da plataforma**; num projeto que ainda não as tem, o equivalente de abertura é
`/os:resume`, e o encerramento é pedir *"encerra a sessão seguindo o protocolo do session-close"*.
O nascimento protegido (`eos new`) **não** copia essas skills: o projeto nasce com `.claude/skills/`
vazio, então essa regra vale também para projeto novo.

> As horas que o motor mostra (`20261011T183857Z`) estão em **UTC**: no horário de Brasília,
> subtraia 3 horas.

## Como ler a resposta do `eos check`

```
Projeto: conversor-utm
  Nivel de portabilidade: L6    Seguranca: SAFE    Operacao: OK
  ...
  Posso apagar esta sessao?        SIM
  Posso apagar a pasta local?      SIM
  Posso trocar de computador?      SIM
```

- **Nível** L0 a L6: quanto o projeto sobrevive sem esta máquina. Meta dos importantes: **L6**.
- **Segurança**: `SAFE` (L3+, há cópia completa fora da máquina), `AT_RISK` (L1–L2),
  `UNSAFE` (L0 ou nem existe aqui).
- **Operação**: `OK` ou `DEGRADED` (ex.: SharePoint fora do ar). Operação degradada **não** é
  perda: o projeto continua seguro.
- **NÃO** sempre vem com o motivo. Exemplo real:
  `Posso apagar a pasta local?  NAO remote: nenhum remoto declarado`.

## Três coisas que o Claude nunca faz sem você

1. **Commit, tag ou push** sem pedido explícito.
2. **Apagar, sobrescrever ou reescrever histórico** (gate H3).
3. **Login, 2FA, desbloqueio do cofre** (gate H1): só você.

Quando precisar de você, ele para e mostra um bloco `HUMAN ACTION REQUIRED` com o gate, o motivo, a
ação exata e o que já foi protegido. Ver [14 — Human gates](14-HUMAN-GATES.md).
