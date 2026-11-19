# Documentação do usuário: Emmily AI Project OS

Esta pasta é o manual de uso do Project OS, escrito para quem **usa** a plataforma no dia a dia
e não precisa dominar Git. A documentação técnica (como o motor funciona por dentro, por que cada
decisão foi tomada) continua em `docs/ARCHITECTURE.md`, `docs/decisions/` e `docs/vnext/`.

> **Regra de leitura:** se algo aqui divergir do que o motor responde (`py -3.13 -m eos ...`), **o
> motor vence**. Ele mede o estado real; este texto descreve como as coisas deveriam funcionar.

## Por onde começar

| Você quer... | Leia |
|---|---|
| entender o que é isto em 5 minutos | [00 — O que é o Emmily AI Project OS](00-O-QUE-E-O-EMMILY-AI-PROJECT-OS.md) |
| usar hoje, sem ler o resto | [01 — Guia rápido](01-GUIA-RAPIDO.md) |
| a referência completa, com todos os comandos | [02 — Manual completo](02-MANUAL-COMPLETO.md) |
| um procedimento passo a passo, em checklist | [03 — POP operacional](03-POP-OPERACIONAL.md) |
| ver os fluxos desenhados | [04 — Fluxogramas de uso](04-FLUXOGRAMA-DE-USO.md) |

## Por tarefa

| Tarefa | Documento |
|---|---|
| criar um projeto novo | [05 — Como criar um projeto](05-COMO-CRIAR-UM-PROJETO.md) |
| abrir, trabalhar e salvar versão | [06 — Como trabalhar em um projeto](06-COMO-TRABALHAR-EM-UM-PROJETO.md) |
| encerrar a sessão sem perder nada | [07 — Como encerrar uma sessão](07-COMO-ENCERRAR-UMA-SESSAO.md) |
| backup, restauração e recuperação de desastre | [08 — Backup e recovery](08-BACKUP-E-RECOVERY.md) |
| trocar de computador | [09 — Troca de computador](09-TROCA-DE-COMPUTADOR.md) |
| propriedade, autoria e assinatura de commits | [10 — Propriedade e proveniência](10-PROPRIEDADE-E-PROVENIENCIA.md) |
| entender Git, GitHub e Google Drive | [11 — Git, GitHub e Drive](11-GIT-GITHUB-E-DRIVE.md) |
| senhas, tokens e o cofre | [12 — Segredos e Bitwarden](12-SEGREDOS-E-BITWARDEN.md) |
| saber se um projeto está seguro (níveis L0–L6) | [13 — Health e continuity](13-HEALTH-E-CONTINUITY.md) |
| entender quando o Claude para e pede você | [14 — Human gates](14-HUMAN-GATES.md) |
| algo deu errado | [15 — Troubleshooting](15-TROUBLESHOOTING.md) |

## Convenções desta documentação

- **Comandos do motor** rodam no PowerShell, **na raiz da plataforma**:
  `C:\AI-WORKSPACE\_platform\emmily-ai-project-os`. Exemplo: `py -3.13 -m eos status`.
- **Comandos do plugin** (`/os:status`, `/os:checkpoint`...) são digitados **dentro do Claude Code**,
  em qualquer pasta.
- **Frases em linguagem natural** ("Esse projeto está seguro?") funcionam igual aos comandos: o
  Claude reconhece a intenção e roda o que estiver por baixo. Cada documento mostra o que acontece
  por baixo de cada frase.
- `eos new`, `eos ownership-check`, `eos ownership-certify` e a seção `ownership` do contrato
  foram conferidos contra o código integrado em 2026-10-12. A lista oficial de comandos é sempre
  `py -3.13 -m eos --help`.
