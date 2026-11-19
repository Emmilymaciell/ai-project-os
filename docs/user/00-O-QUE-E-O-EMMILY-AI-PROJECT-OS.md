# 00 — O que é o Emmily AI Project OS

## Em uma frase

É o sistema que garante que **nenhum projeto seu depende de uma conversa, de um computador ou da
sua memória** para continuar existindo: ele cria, registra, versiona, faz backup, testa a
restauração e diz, com fatos medidos, se é seguro apagar uma sessão, apagar uma pasta ou trocar de
máquina.

## Por que existe

Antes do Project OS, a situação real era esta:

- cada projeto era montado do zero, com uma estrutura diferente;
- o estado do trabalho ("onde parei, o que falta") vivia no histórico do chat, que some;
- o backup era um ZIP numa pasta pessoal, sem saber se abria;
- vários projetos não tinham Git, ou tinham Git sem nenhuma cópia fora do disco;
- saber se era seguro apagar uma pasta ou formatar o computador dependia de lembrar.

Depois:

- uma ideia vira projeto estruturado em um pedido;
- o estado vive em arquivos do próprio projeto (`STATE.md`, decisões, contrato);
- o histórico vive no Git, com cópia **privada** no GitHub;
- dados, trabalho não salvo e bancos têm cópia conferida por hash no Google Drive;
- a restauração é **provada** em pasta isolada, não suposta;
- uma pergunta como *"Posso trocar de computador?"* tem resposta SIM/NÃO com o motivo.

## O princípio central

**Projeto ≠ sessão.** A conversa com o Claude é descartável. O projeto precisa sobreviver a:

- `/compact` ou perda do chat;
- uma sessão nova, uma conta nova do Claude, ou outra IA (Codex, por exemplo);
- um computador novo, roubado ou com disco queimado;
- outra pessoa assumindo;
- meses sem uso.

Por isso há uma pergunta que o Claude faz a si mesmo antes de encerrar qualquer trabalho: *se esta
conversa sumisse agora, o que se perderia?* O que se perderia vai para o disco antes.

## O que ele protege

| Ameaça | Como é coberta |
|---|---|
| perder o chat | estado em `docs/STATE.md`, decisões em ADRs, contrato no registry |
| perder o computador | histórico no GitHub privado + bundle Git, WIP e bancos no Google Drive |
| perder o GitHub | o bundle Git no Drive tem o histórico completo |
| perder o acesso ao Drive pelo rclone | segundo transporte: o app Google Drive para desktop |
| trabalho não commitado | snapshot de WIP (arquivos modificados e novos, de todas as worktrees) |
| banco SQLite em uso | snapshot consistente pela API de backup do SQLite, conferido |
| backup que "existe" mas não abre | certificação: restaura em pasta isolada, roda o teste do projeto e registra a prova |
| segredo vazando para o backup | arquivo com nome de segredo não sobe; segredo commitado reprova o projeto |
| dado pessoal de terceiro no GitHub | política: o Git guarda o projeto, o Drive guarda o dado bruto (ADR-0015) |
| decisão destrutiva por engano | o Claude **para** e pede você antes (human gate H3) |
| dúvida sobre autoria | seção de propriedade no contrato, arquivos de proveniência e commits assinados |

## O que ele **não** é

- **Não é backup do computador inteiro.** Protege o que está registrado como projeto.
- **Não é o SharePoint.** O SharePoint da Programa é **fonte externa** de documentos; ele não é backup
  de projeto nenhum.
- **Não é uma IA que decide sozinha.** O Claude executa; decisões materiais, destrutivas, de
  autenticação ou de segurança são suas.
- **Não commita por conta própria.** Commit, tag e push só quando você pede.

## Arquitetura em linguagem simples

Pense em cinco lugares, cada um com um papel só:

```
 SEU COMPUTADOR (C:\AI-WORKSPACE)        onde o trabalho acontece
        │
        ├── GitHub privado (Emmilymaciell/<repo>)    o histórico do código, decisões, STATE
        │
        ├── Google Drive (EMMILY PROJECT CLOUD/)     dados brutos + cópias de recuperação
        │
        ├── Bitwarden                                 senhas e tokens (fonte de verdade de segredo)
        │
        └── SharePoint / OneDrive corporativo         documentos do Programa: fonte, não backup
```

E por cima disso, a **plataforma** (este repositório, `C:\AI-WORKSPACE\_platform\emmily-ai-project-os`):

| Peça | O que é | Como você usa |
|---|---|---|
| **Registry** | um arquivo `registry/projects/<id>.yaml` por projeto: o **contrato** | não precisa editar; o Claude mantém |
| **Motor `eos`** | programa Python que mede, faz backup, restaura e certifica | `py -3.13 -m eos <comando>`, ou pedindo ao Claude |
| **Plugin `/os:*`** | comandos do Claude Code que funcionam em qualquer pasta | `/os:status`, `/os:checkpoint`... ou em português |
| **Protocolo de sessão** | `/session-start` e `/session-close` | abrir e fechar sessões sem perder nada |
| **Hooks de Git** | travas locais antes de commit e push | automático |
| **Revisores** | `qa-reviewer` e `security-reviewer`, agentes só-leitura | o Claude aciona quando a criticidade exige |

## Os projetos que ele governa

O registry tem um contrato para cada item do seu ecossistema, separado por **categoria**:

| Categoria | Exemplos reais | Pasta no Drive |
|---|---|---|
| PLATFORM | a própria plataforma | `00 PLATFORM/` |
| Programa | Relatório G2, Grupo 1, Semanal, Cérebro Documental, Organização SharePoint, Dashboard e Repositório Jurídico, automações extraídas do acervo Dynatest | `01 PROG/` |
| PERSONAL | Organizador Dynatest, Projeto Pessoal A | `02 PERSONAL/` |
| UNIVERSITY | TRABALHO SISTEMAS, P1 HIDROLOGIA (acervos) | `03 UNIVERSITY/` |
| PORTFOLIO | Empresa X Portfolio, Empresa X Gestão | `04 PORTFOLIO/` |
| LAB | conversor-utm, Portability Lab, Documents/Codex | `05 LAB/` |

E por **tipo**:

| Tipo | O que é | Tem nível L0–L6? |
|---|---|---|
| `PROJECT` | projeto vivo, com Git | sim |
| `COLLECTION` | acervo de arquivos sem Git próprio (ex.: material da faculdade) | não, é classificado |
| `EXTERNAL_SOURCE` | fonte externa (ex.: SharePoint Programa) | não |
| `ARCHIVE` | coisa encerrada, guardada | não |
| `REFERENCE_DATA` | dado de referência (normas, bases públicas); nenhum item usa ainda | não |

Para ver o retrato atual: diga ao Claude *"Como estão meus projetos?"* ou rode
`py -3.13 -m eos status`.

## As regras que não mudam

1. **Projeto ≠ sessão.** O que importa vai para o disco antes de a conversa acabar.
2. **"Não consegui verificar" nunca conta como "passou".** Toda verificação é PASS, WARN, FAIL ou
   UNKNOWN, e UNKNOWN bloqueia.
3. **GitHub privado por padrão.** Tornar algo público é decisão sua, explícita, nunca padrão.
4. **Segredo nunca entra no Git.** Só o **nome** dele, num manifesto.
5. **Nada destrutivo sem você.** Apagar, reescrever histórico, sobrescrever: o Claude para (H3).
6. **O Claude não commita sozinho.** Só com "salva essa versão", "commita", `/os:checkpoint`.

## Próximo passo

Leia o [Guia rápido](01-GUIA-RAPIDO.md). Ele cobre 90% do uso diário em uma página.
