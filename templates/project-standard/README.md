# {{PROJECT_TITLE}}

{{PROJECT_DESC}}

## O problema

<!-- Que problema real isto resolve? Como se sabe que foi resolvido?
     Se não souber responder à segunda pergunta, o discovery ainda não terminou. -->

## Como rodar

```powershell
.\bootstrap.ps1
```

O bootstrap verifica Git, Python, `.env` e estrutura, cria o `.venv` com as dependências, **roda a suíte de testes** e diz o que falta. É idempotente — pode rodar quantas vezes quiser.

Rodar os testes isoladamente:

```powershell
.\tests\run-tests.ps1
```

Um comando só, igual em todo projeto governado pelo Project OS. Saída `0` passou, `1` falhou, `2` **a suíte não rodou** — e `2` não é uma variação de `1`. Ver [tests/README.md](tests/README.md).

<!-- Depois do bootstrap, o comando principal do projeto: -->
```powershell
# 
```

## Estrutura

```
{{PROJECT_NAME}}/
├── CLAUDE.md        como trabalhar neste projeto
├── project.yaml     cartão de identidade (lido por /os:status e /os:handoff)
├── bootstrap.ps1    preparar a máquina
├── docs/
│   ├── STATE.md     onde o projeto está agora  ← leia primeiro
│   └── decisions/   por que está assim
├── scripts/
└── tests/           suíte deste projeto  ← rodar com .\tests\run-tests.ps1
```

## Estado

Ver [docs/STATE.md](docs/STATE.md).

## Assumir este projeto

Quem chegar depois — outra pessoa, outra máquina, outro Claude — deve conseguir continuar lendo `docs/STATE.md`, `docs/decisions/` e este README, sem depender de nenhum histórico de conversa.

Se algo essencial só existir na cabeça de alguém ou num chat, isso é um bug do projeto. Gere o documento de transferência com `/os:handoff`.
