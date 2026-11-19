# ADR-0004 — Distribuir o Project OS como plugin com marketplace local

- **Data:** 2026-09-05
- **Status:** Aceita
- **Fase:** 1 (bloco F)

## Contexto

Os comandos `/os:*` precisam funcionar em **qualquer pasta** — inclusive em pastas onde o projeto ainda não existe, que é justamente o caso de `/os:new-project`.

O Claude Code oferece três lugares onde skills e comandos podem morar:

| Lugar | Alcance |
|---|---|
| `.claude/skills/` do projeto | Só dentro daquele projeto |
| `~/.claude/skills/` | Global, mas fora de qualquer repositório |
| Plugin | Global, versionado, com namespace próprio |

## Decisão

Empacotar o OS como plugin, com `.claude-plugin/plugin.json` declarando `"name": "os"` — é esse nome que produz o namespace `/os:*` — e um `.claude-plugin/marketplace.json` **no próprio repositório**, registrado como marketplace local via caminho de arquivo.

Estrutura: `skills/<nome>/SKILL.md`, `agents/*.md`, `hooks/hooks.json` — todos na **raiz do plugin**, nunca dentro de `.claude-plugin/`, que contém somente o `plugin.json`.

## Skills, não `commands/` — e por quê

Decisão revista em 2026-09-08, antes do primeiro checkpoint.

A versão anterior deste ADR previa **duas peças por procedimento**: a skill carregando o conhecimento e um `commands/<nome>.md` fino servindo de atalho. Isso estava errado, e a documentação atual do Claude Code é explícita:

- `skills/` — "Skills as `<name>/SKILL.md` directories"
- `commands/` — "Skills as flat Markdown files. **Use `skills/` for new plugins**"

Ou seja: `commands/` não é uma camada de atalho sobre `skills/`. É a **forma antiga e plana da mesma coisa**, mantida por compatibilidade. Não há o que orquestrar entre as duas.

E o namespace já resolve a invocação: *"The folder name becomes the skill name, prefixed with the plugin's namespace"* — `skills/status/` num plugin chamado `os` produz `/os:status` diretamente. A skill **é** o comando.

Manter as duas teria custado: dois arquivos por procedimento a manter em sincronia, duas fontes divergindo com o tempo, e dois nomes para a mesma coisa aparecendo no `/help`.

**Nenhuma necessidade técnica justifica manter `commands/` neste plugin.** A pasta havia sido criada apenas como reserva para essa duplicação, e foi removida.

O único caso em que `commands/` seria necessário é a compatibilidade com uma versão do Claude Code anterior ao suporte a skills em plugin — o que não se aplica: a máquina tem a CLI 2.1.252.

Para skills que só devem ser invocadas pela Emmily, e nunca escolhidas pelo modelo por conta própria, existe o frontmatter `disable-model-invocation: true`. Não é o caso de nenhuma das cinco: todas se beneficiam de o Claude reconhecê-las em linguagem natural, que é justamente o requisito de UX do handoff (§32).

## Camadas de validação

Um plugin não é aceito por "os arquivos parecem certos". São quatro camadas distintas, e cada uma responde a uma pergunta diferente:

| Camada | Comando | Responde |
|---|---|---|
| 1. Testes internos | `tests/run-tests.ps1` | Nossas próprias regras — estrutura, ADRs, template, segurança |
| 2. Validação estrutural oficial | `claude plugin validate . --strict` | O Claude Code considera este plugin bem-formado? |
| 3. Carregamento em desenvolvimento | `claude --plugin-dir .` | As skills realmente carregam e aparecem como `/os:*`? |
| 4. Carregamento após instalação | `/plugin marketplace add` + `install` | O caminho que a Emmily vai usar de fato funciona? |

A camada 1 passar não diz nada sobre a 2. A 2 passar não diz nada sobre a 3 — manifesto válido não garante skill carregada. E a 3 passar não diz nada sobre a 4, porque instalar por marketplace exercita a resolução de `source` e a cópia para `~/.claude/plugins/`, que `--plugin-dir` não exercita.

**O plugin não é considerado aceito até as quatro passarem.**

Resultado da execução em 2026-09-08, com CLI 2.1.252:

| Camada | Resultado | O que a camada revelou |
|---|---|---|
| 1 | 27/27 | Dois bugs próprios: `\b` gravado como byte de backspace num regex, e um falso positivo do teste de placeholder sobre a skill que documenta os placeholders |
| 2 | `✔ Validation passed` (com `--strict`) | Que com os dois manifestos no mesmo `.claude-plugin/`, o comando valida o **marketplace** e não o plugin — é preciso validar `./skills` ou uma cópia sem `marketplace.json` |
| 3 | `Loaded 5 skills from plugin os default directory` | Um aviso: `Skill listing over budget: 23 skills, 10000 chars > 8000` — descrições longas seriam truncadas, degradando o disparo automático. As 5 descrições foram encurtadas de 1.747 para 1.009 caracteres |
| 4 | `os@emmily-platform` · `Skills (5)` · ~267 tok always-on | Que a instalação faz uma **cópia congelada** em `~\.claude\plugins\cache\`, e que editar o repositório não a atualiza — verificado empiricamente. Desenvolvimento usa `--plugin-dir`; propagar para o instalado exige subir `version` e `claude plugin update` |

Nenhuma dessas quatro descobertas apareceria se apenas a camada 1 tivesse rodado.

## Alternativas consideradas

- **`~/.claude/skills/`.** Rejeitada: funcionaria, mas fica fora de repositório — sem histórico, sem versão, sem portabilidade, sem sincronização entre as duas máquinas. Contradiz o princípio "projeto ≠ sessão" aplicado à própria plataforma.
- **`.claude/skills/` por projeto.** Rejeitada: não resolve `/os:new-project` (a pasta ainda não existe) e cria N cópias divergindo.
- **Marketplace remoto no GitHub desde o início.** Rejeitada como forma principal: criaria dependência de rede e de o bloco H estar pronto para a plataforma sequer funcionar. O marketplace local funciona offline e antes do GitHub existir. Publicar também como remoto é possível depois, e é aditivo.
- **`claude plugin init` em `~/.claude/skills/`.** A CLI oferece isso: o plugin carrega automaticamente como `os@skills-dir`, sem marketplace nem passo de instalação. Tentador pela simplicidade. Rejeitada pelo mesmo motivo que rejeitou `~/.claude/skills/` acima — o conteúdo fica fora de repositório, sem histórico, sem versão e sem portabilidade entre as duas máquinas. Vale como atalho para experimento descartável, não para a plataforma.
- **Duas peças por procedimento (`skills/` + `commands/`).** Rejeitada — ver a seção acima.

## Consequências

- Positiva: `/os:*` disponível em qualquer pasta, versionado, com uma origem única.
- Positiva: a plataforma funciona offline e sem GitHub.
- Positiva: instalar em outra máquina é `git clone` + registrar o marketplace local.
- Negativa: exige um passo de registro na instalação. Automatizado em `scripts/bootstrap.ps1` e documentado em `docs/SETUP.md`.
- Negativa: alterações nas skills podem exigir recarregar o plugin para surtir efeito. Aceitável.
