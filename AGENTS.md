# AGENTS.md — Emmily AI Project OS

Adaptador **neutro de provedor** (Codex, e qualquer agente que leia `AGENTS.md`). O `CLAUDE.md` é o
adaptador do Claude Code. Os dois consomem o mesmo core, e nenhum deles contém estado.

## O core canônico — leia nesta ordem

1. `docs/STATE.md`: onde a plataforma está. Leia o cabeçalho e a seção *Próximo passo*; o arquivo
   é longo.
2. `docs/vnext/EXECUCAO.md`: andamento do programa vNext (gates, fases, como retomar).
3. `docs/decisions/`: ADRs. Decisão registrada não se reabre sem fato técnico novo.
4. `registry/projects/*.yaml`: um contrato por projeto, coleção ou fonte externa do ecossistema.

## Regras que valem para qualquer agente

- **Projeto ≠ sessão.** O que só existe na conversa se perde. Antes de encerrar, persista em
  `docs/STATE.md`, num ADR ou no código.
- **Git:** nunca `reset --hard`, `clean`, `rebase`, `commit --amend`, `push --force`, nem descartar
  branch ou worktree. Commit e push só pelos critérios do ADR-0012. Repositório novo no GitHub
  nasce **privado**.
- **Segredos:** valores nunca entram no Git. Só nomes, em `secrets.manifest`.
- **Ambiente:** Windows 11, PowerShell 5.1, Python 3.13 via `py -3.13`. Antes de escrever `.ps1`,
  leia `docs/runbooks/gotchas-windows-powershell.md`.

## Comandos

| Para | Rode |
|---|---|
| suíte da plataforma | `.\tests\run-tests.ps1` (~14 min); por área: `-Suite docs`, `-Suite vnext` |
| portfólio: como estão os projetos | `py -3.13 -m eos status` |
| um projeto: posso apagar, posso trocar de PC | `py -3.13 -m eos check <id>` |
| backup verificado na nuvem | `py -3.13 -m eos backup <id>` |
| prova de restauração (L6) | `py -3.13 -m eos certify <id>` |
| restaurar | `py -3.13 -m eos restore <id> --para <diretório vazio> [--com-dados]` |
| espelhar dados fora do Git (`cloud-mirror`) no Drive | `py -3.13 -m eos mirror <id>` ou `--todos` |
| projeto novo, já protegido | `py -3.13 -m eos new <id> --name "<nome>" --category <CAT> --dry-run` (depois sem `--dry-run`) |
| segredos no cofre (Bitwarden, depois de `bw unlock`) | `py -3.13 -m eos secrets-push <id>` · `secrets-pull <id>` · `secrets-status <id>` |
| proveniência / titularidade | `py -3.13 -m eos ownership-check <id>` · `ownership-certify <id>` · `ownership-init <id>` |
| preparar troca de computador | `py -3.13 -m eos prepare-machine-migration` |
