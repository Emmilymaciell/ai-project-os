# 11 — Git, GitHub e Drive

Para quem não domina Git. Você não precisa digitar nenhum comando daqui: o Claude faz. Mas
entender o que cada coisa é evita sustos.

## 1. Git em 10 conceitos

| Conceito | Analogia | Comando que o Claude usa |
|---|---|---|
| **repositório** | a pasta do projeto com um "caderno de versões" escondido (`.git`) | `git init` |
| **working tree** | os arquivos como estão agora no disco | `git status` |
| **commit** | uma página do caderno: uma versão salva, com data, autora e mensagem | `git commit` (só a seu pedido) |
| **HEAD** | a página em que você está | `git log -1` |
| **branch** | uma linha de trabalho paralela; `main` é a principal | `git branch` |
| **tag** | um marcador numa versão importante: `v0.2.0` | `git tag` (só a seu pedido) |
| **remoto** | uma cópia do caderno em outro lugar: aqui, o GitHub privado | `git remote -v` |
| **push** | mandar as páginas novas para o remoto | `git push` (só a seu pedido) |
| **worktree** | uma segunda pasta ligada ao mesmo caderno, para trabalhar em paralelo | `git worktree list` |
| **stash** | uma gaveta temporária de alterações. **Evite**: o backup não a protege | `git stash list` |

E dois termos do Project OS:

- **WIP** (*work in progress*): tudo que mudou desde o último commit. O commit não o protege; o
  `eos backup` sim.
- **bundle**: o caderno inteiro (todas as páginas, branches e tags) num arquivo só, guardado no
  Drive.

## 2. A regra de ouro do commit

**O Claude nunca faz `git add`, `git commit` ou `git tag` por iniciativa própria.** Nem ao terminar
uma tarefa, nem ao corrigir um bug, nem no fim da sessão.

| Autoriza commit | Não autoriza |
|---|---|
| "salva essa versão", "salvar versão" | "ficou bom" |
| "commita isso", "atualiza o git", "manda pro git" | "terminei", "pronto" |
| "marca como versão X", "essa é a versão boa" | "funcionou" |
| `/os:checkpoint`, `/versionar` | silêncio |

Proibido sem pedido explícito: `push`, `reset --hard`, `checkout --`, `clean -fd`, `rebase`,
`commit --amend`, `push --force`, trocar de branch no meio de um trabalho. Reescrever histórico é
sempre gate H3.

Por que tanto cuidado: tentativas e testes intermediários ficam só no disco, de propósito. O
histórico guarda versões que você decidiu guardar.

## 3. GitHub

| Regra | Detalhe |
|---|---|
| **privado por padrão** | todo repositório nasce privado; público é decisão sua, explícita (ADR-0003). O contrato que declarar `visibility: public` é recusado pela validação sem essa decisão |
| conta | GitHub pessoal: `github.com/Emmilymaciell/<repo>`, inclusive para projetos Programa (ambiente pessoal autorizado) |
| nada corporativo é publicado automaticamente | portfólio é permitido, com sanitização e controle de exposição explícito |
| antes de qualquer push | varredura de segredo, token, `.env`, dado pessoal de terceiro e documento interno, **inclusive no histórico já commitado** |
| nomes | prefixo da categoria: `prog-...`, `personal-...`, `portfolio-...`, `lab-...` |
| proteção de branch | não disponível (repositório privado no plano gratuito). O fluxo é client-side: hooks locais e revisão (ADR-0011) |

O GitHub guarda o **conteúdo versionado**. Não guarda: arquivos ignorados, saídas, dados, `.env`,
trabalho não commitado. Por isso existe o Drive.

## 4. O que vai para o Git e o que vai para o Drive (ADR-0015)

> **O Git guarda o projeto; o Drive guarda o dado bruto.**

| No Git (GitHub privado) | No Drive (`EMMILY PROJECT CLOUD/<categoria>/<id>/`) |
|---|---|
| código, scripts, testes | documentos brutos: PDF, DOCX, XLSX |
| STATE, HANDOFF, ADRs, runbooks | bancos, datasets, imagens, vídeos |
| contrato, manifestos, configuração sem segredo | evidências e saídas grandes |
| `.env.example`, `secrets.manifest` (nomes) | **todo arquivo com CPF, e-mail ou telefone de terceiro** |
| referências ao dado bruto: hash, ID, caminho lógico | os originais, preservados com hash |

Regras que vêm junto:

- arquivo técnico que precisa estar no Git é **redigido antes**: o dado de terceiro sai, o original
  fica no Drive;
- o original **nunca** é apagado nem alterado para limpar o Git;
- titularidade incerta é tratada como dado de terceiro;
- segredos nunca entram, nem no Git nem no Drive.

Por que essa regra existe: a varredura de 2026-10-08 achou CPF válido em dois repositórios, e-mails
e telefones de terceiros em cinco e documentos operacionais brutos em três. Fazer push deles como
estavam replicaria tudo isso. Os históricos com esse tipo de dado foram **sanitizados** (com sua
aprovação, gate H3) antes de ir para o GitHub; os que a varredura achou limpos foram publicados
direto. Um caso ficou pendente: as imagens `golden` do Relatório Semanal saíram do rastreamento, mas
continuam no histórico já publicado, e tirá-las de lá exige *force push*, que aguarda sua
autorização explícita (H3).

## 5. Google Drive

Raiz lógica, igual em qualquer máquina:

```
EMMILY PROJECT CLOUD/
  00 PLATFORM/  01 PROG/  02 PERSONAL/  03 UNIVERSITY/  04 PORTFOLIO/  05 LAB/
      <id>/dados/, <id>/dados-anteriores/  (espelho das pastas cloud-mirror: eos mirror)
  99 RECOVERY/  (bundles, WIP, bancos, manifestos, certificados, preservação de emergência)
```

| Regra | Por quê |
|---|---|
| **nunca** trabalhe com um repositório Git ativo dentro de pasta sincronizada (Drive ou OneDrive) | a sincronização corrompe o `.git` e trava arquivos |
| nunca use um banco SQLite vivo dentro de pasta sincronizada | idem; o backup tira snapshot consistente |
| o Drive é acessado pelo **rclone** (remoto `gdrive:`), e pelo app Drive para desktop como reserva | não depende de letra de unidade |
| o motor só acrescenta na nuvem | não tem comando de apagar, mover ou sincronizar; o espelho de dados (`eos mirror`) guarda a versão substituída em `dados-anteriores/` antes de subir a nova |

Para ver o que há no Drive sem abrir o navegador (só leitura):

```powershell
rclone lsf "gdrive:EMMILY PROJECT CLOUD/"
rclone lsf "gdrive:EMMILY PROJECT CLOUD/99 RECOVERY/manifests/conversor-utm/"
```

## 6. OneDrive e SharePoint

| | Papel |
|---|---|
| OneDrive pessoal | não é o backup canônico (substituído pelo Drive no programa vNext) |
| OneDrive corporativo / SharePoint Programa | **fonte operacional externa** de documentos do contrato. Nunca é backup de projeto |
| exceção | o Organizador Dynatest vive dentro do OneDrive (ADR-0002); não abre precedente |

## 7. Commits assinados

Todos os commits e tags saem **assinados** com a sua chave SSH (`commit.gpgsign=true`,
`tag.gpgsign=true`). No GitHub aparecem como **Verified** depois que a chave pública for registrada
como chave de assinatura (gate H1). Ver [10](10-PROPRIEDADE-E-PROVENIENCIA.md).

## 8. Comandos de leitura que você pode rodar sem medo

Nenhum destes altera nada:

```powershell
git status                       # o que mudou desde o último commit
git log --oneline -10            # as últimas 10 versões
git branch -a                    # branches locais e remotas
git remote -v                    # para onde vai o push
git worktree list                # pastas paralelas ligadas ao projeto
git stash list                   # se houver algo aqui, peça para virar branch
git log --show-signature -1      # a assinatura do último commit
```
