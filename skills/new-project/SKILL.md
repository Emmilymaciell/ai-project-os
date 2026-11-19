---
name: new-project
description: Cria um projeto novo estruturado: discovery, classificacao, template, Git e estado. Use quando ela tiver uma ideia que merece virar projeto, pedir para criar um projeto, ou invocar /os:new-project.
---

# /os:new-project

Transformar uma ideia descrita em português num projeto estruturado, versionado e portátil.

O objetivo não é criar pastas: é que o projeto **já nasça sobrevivendo à perda desta conversa**.

## 1. Discovery — antes de criar qualquer arquivo

Pergunte só o que você não consegue deduzir. No máximo 4 perguntas, de uma vez, não em série.

O que você precisa saber:

| Precisa saber | Por que |
|---|---|
| Que problema resolve, e **como se sabe que foi resolvido** | Sem a segunda metade, o projeto não tem critério de pronto |
| Categoria: trabalho / faculdade / pessoal / experimento | Define onde mora no workspace |
| Se toca dado corporativo, pessoal de terceiro ou confidencial | Define `.gitignore`, security check e exposição |
| Se alguma saída depende de julgamento de modelo | Define se precisa de `evals/` |

**Não pergunte** o que dá para inferir: porte, nome de pasta, interpretador, se precisa de Git. Proponha e deixe ela corrigir.

Se a resposta ao "como se sabe que foi resolvido" for vaga, insista **uma vez**. Projeto sem critério de pronto é o que vira retrabalho depois.

## 2. Classificar

Preencha a classificação você mesmo, e mostre a ela junto com o plano:

- **porte:** `script` (um arquivo, uma tarefa) · `ferramenta` (vários scripts, uso recorrente) · `aplicacao` (interface, usuários) · `plataforma` (governa outras coisas)
- **criticidade:** `baixa` (se quebrar, ninguém sofre) · `media` (retrabalho) · `alta` (impacto em entrega, cliente ou obrigação)
- **dados_sensiveis:** `true` se houver qualquer dado Programa, Dynatest, cliente ou pessoa física
- **componente_llm:** `true` se alguma saída depende de julgamento de modelo

**Não infle.** Um script de uso próprio classificado como `aplicacao`/`alta` só produz cerimônia. O erro comum é para cima, não para baixo.

## 3. Escolher o local

Regra (ADR-0001): projeto novo nasce em `C:\AI-WORKSPACE`. O local **não é escolhido à mão**: o `eos new` o deriva da categoria do contrato, `${AI_WORKSPACE}\<base>\<id>`.

| Categoria do contrato | Quando | Base em `C:\AI-WORKSPACE` | Drive |
|---|---|---|---|
| `PROG` | trabalho Programa/Dynatest | `work\prog\` | `01 PROG` |
| `UNIVERSITY` | faculdade | `university\` | `03 UNIVERSITY` |
| `PERSONAL` | pessoal | `personal\` | `02 PERSONAL` |
| `PORTFOLIO` | portfólio | `portfolio\` | `04 PORTFOLIO` |
| `LAB` | experimento | `ai-lab\` | `05 LAB` |
| `PLATFORM` | ferramenta da própria plataforma | `_platform\` | `00 PLATFORM` |

O id (`kebab-case`, descritivo, sem data e sem número de versão — o Git cuida disso) é o nome da pasta e do contrato. O repositório no GitHub leva o prefixo da categoria (`prog-`, `lab-`, `personal-`, `university-`, `portfolio-`) quando o id ainda não começa por ele.

**Nunca crie projeto novo dentro de pasta sincronizada pelo OneDrive.** O `eos new` recusa destino em OneDrive/Drive. Existe uma exceção histórica registrada (ADR-0002); ela não abre precedente.

## 4. Apresentar o plano e esperar aprovação

Antes de criar qualquer arquivo, rode o plano **sem efeito** e mostre a saída junto com a classificação:

```
py -3.13 -m eos new <id> --name "<título>" --category <CAT> [--runtime python|node|none] [--descricao "<frase>"] --dry-run
```

O `--dry-run` não cria diretório, não grava diário, não chama `gh` nem a nuvem. Acrescente ao que ele imprime:

```
Problema:       <uma frase>
Pronto quando:  <critério>
Classificação:  <porte> · criticidade <n> · dados sensíveis <s/n> · componente LLM <s/n>
Verificação:    <tests / evals / integration / security — o que se aplica e por quê>
```

E diga com todas as letras o que o "sim" autoriza: **commit inicial** (assinado se a config do Git pedir), **remoto GitHub privado** criado e com push, pasta no Drive e primeiro backup. Se ela não quiser remoto agora, o comando leva `--sem-remoto` (o projeto fica em L1 e o contrato registra isso).

Espere o "sim".

## 5. Instanciar — `eos new`

Rode o mesmo comando **sem** `--dry-run`. Ele executa, em ordem e conferindo cada passo por fato: validar → workspace → arquivos → git → contrato → remoto → drive → backup. Se um passo falhar, ele **para sem apagar nada**, mostra o que já foi feito e o comando para retomar — rodar o mesmo comando de novo continua do passo pendente; parâmetros diferentes são recusados. Mostre a saída inteira.

O que o `eos new` faz por você, e que antes era passo manual desta skill:

1. Copia `templates/project-standard/` para o destino, com STATE, `docs/HANDOFF.md`, `docs/decisions/ADR-0001-nascimento-protegido.md`, `PROVENANCE.md`, `OWNERSHIP.md`, `AUTHORS.md`, `NOTICE`, `.github/CODEOWNERS`, `.env.example` e os adaptadores `CLAUDE.md` e `AGENTS.md`.
2. Substitui os placeholders em **todo arquivo de texto, dotfiles incluídos**, e falha se algum restar. Mesmo assim, confira você:

   > Não use o glob `*.md`, `*.yaml`, `*.ps1`. O teste de aceitação da Fase 1 mostrou por quê: `.env.example` e `.gitignore` não casam com nenhum desses padrões, e `{{PROJECT_TITLE}}` sobreviveu nos dois. Varra os arquivos de texto do destino, sem filtrar por extensão, e confira no fim que **nenhum `{{` restou**:
   >
   > ```bash
   > grep -rn '{{' . --exclude-dir=.git | head
   > ```
   >
   > Saída vazia é o critério. Não é opcional.

   O `eos new` preenche cada placeholder com um padrão conservador (criticidade `baixa`, porte `script`, `dados_sensiveis` `true` só para Programa, `{{CRITERIO_PRONTO}}` "a definir no discovery"). **Depois do nascimento, corrija no `project.yaml` o que o discovery decidiu diferente** — a tabela diz o que cada um significa:

   | Placeholder | Valor |
   |---|---|
   | `{{PROJECT_NAME}}` | nome em kebab-case |
   | `{{PROJECT_TITLE}}` | título legível |
   | `{{PROJECT_DESC}}` | a frase do problema |
   | `{{CATEGORY}}` `{{CLIENT}}` | da classificação |
   | `{{PORTE}}` `{{CRITICIDADE}}` `{{DADOS_SENSIVEIS}}` `{{COMPONENTE_LLM}}` | da classificação |
   | `{{TEM_TESTS}}` `{{TEM_EVALS}}` `{{TEM_INTEGRACAO}}` `{{TEM_SECURITY}}` | da detecção (seção 6) |
   | `{{PYTHON}}` | `3.12`, `3.13` ou `nao-usa` — **fixar, nunca deixar implícito** |
   | `{{NODE}}` `{{REMOTO}}` `{{PORTFOLIO}}` `{{DATE}}` | conforme o caso |
   | `{{CRITERIO_PRONTO}}` | a frase que define "pronto" — vai para `verificacao.criterio_de_pronto`, e é de lá que os testes leem |
   | `{{VERIFICACAO_TESTS}}` `{{VERIFICACAO_EVALS}}` `{{VERIFICACAO_SECURITY}}` | uma linha cada: o que se aplica, ou **por que não se aplica neste projeto** |
   | `{{REVISAO_INDEPENDENTE}}` | `nenhuma`, `qa` ou `qa+security` — **derivado** da criticidade pelo ADR-0007, nunca escolhido a gosto |

   `classificacao.dados_sensiveis_excecoes` **não é placeholder**: nasce `[]` e fica vazio na esmagadora maioria dos projetos. Se `{{DADOS_SENSIVEIS}}` for `true`, pergunte **onde** o dado sensível está e registre uma entrada com `caminho`, `natureza`, `status` e `onde_esta_registrado`.

   **Declarar não é decidir.** `status: "aceito-por-excecao"` é o único valor que libera algo, e **você não o escreve por conta própria** — aceitar risco é decisão dela. Qualquer outro valor, ou campo obrigatório faltando, significa que a exceção não cobre nada (ADR-0010). E se houver exceção declarada, `dados_sensiveis` **tem** de ser `true`: booleano `false` com exceção logo abaixo é o manifesto mentindo para toda ferramenta que lê só o booleano, e rigor derivado de campo mentiroso é rigor menor.

   **Dado de exemplo em CSV vai em `examples/fixtures/` ou `examples/synthetic/`, e só lá.** O `.gitignore` do template ignora `*.csv` em todo lugar, inclusive no resto de `examples/`, e libera apenas esses dois diretórios — o **caminho** é o guarda-corpo, não o comentário. Se o projeto precisar de CSV de exemplo, ponha ali e diga isso no README. Planilha, PDF e apresentação continuam barrados mesmo dentro deles.

3. Já nasce sem a trilha de teste que não se aplica (pelo `--runtime`). O template traz as duas, e o runner **recusa rodar** (saída `2`) se as duas sobreviverem — escolher em silêncio esconderia metade dos testes.

   | Projeto | O `eos new` não copia |
   |---|---|
   | Python (`--runtime python`) | `tests/_harness.ps1` e `tests/suites/` |
   | PowerShell, ou `{{PYTHON}}` = `nao-usa` (`--runtime none`/`node`) | `tests/conftest.py`, `tests/test_smoke.py` e `requirements.txt` |

   Nunca apague `tests/run-tests.ps1` nem `tests/README.md`: são o contrato comum. Pasta vazia que nunca vai ser usada é ruído: um script simples não precisa de `docs/runbooks/` — remova depois, num commit pedido por ela.
4. Faz `git init -b main` e o **commit inicial** (assinado se a config efetiva do Git tiver `commit.gpgsign`), grava `registry/projects/<id>.yaml` na plataforma (validado pelo schema; **não commita a plataforma**), cria o remoto `gh repo create <owner>/<repo> --private`, confere que é `PRIVATE` **antes** do push, publica a `main`, cria a pasta do Drive e roda o primeiro backup + check de portabilidade. `gh` negado ou sem autenticação vira pendência **H2 "sem remoto"**: o resto do nascimento acontece, o relatório diz o nível (L1) e o mesmo comando, depois, faz só o remoto. Remoto público é falha fechada: nada é enviado. L6 exige certificação por restauração: `py -3.13 -m eos certify <id>` (ou `--certificar` no próprio `eos new`).

Depois do `eos new`, o que continua com você:

1. Ajustar o `.gitignore` ao domínio real do projeto. O do template é conservador de propósito; se o projeto **precisa** versionar um binário, abra exceção com `!` e escreva o motivo na linha de cima.
2. Rodar `bootstrap.ps1` **sem `-Check`**, para ele criar o `.venv` e instalar as dependências. Mostrar a saída. Se acusar algo, resolver antes de seguir.
3. **Rodar `.\tests\run-tests.ps1` e mostrar a saída.** Espere `exit 0`. Saída `2` significa que a suíte **não rodou** — trilha ambígua, `.venv` ausente, nenhum caso executado — e isso não é o mesmo que teste passando; conserte antes de fechar. Comando de teste documentado e nunca executado é a lacuna mais fácil de deixar passar e a que mais irrita quem chega depois: foi assim que a Fase 1 entregou um projeto cujo comando de teste não funcionava.

   O comando é o **mesmo em todo projeto** e já vem literal em `project.yaml` → `verificacao.comando`. Não personalize e não copie o caminho longo do `python.exe` do `.venv` para o `README.md`: era isso que divergia.
4. **Nenhum commit além do inicial.** O que você ajustar depois do nascimento (classificação, `.gitignore`, critério de pronto) fica no disco até ela pedir `/os:checkpoint`.

## 6. Detectar a verificação necessária

Ela não deve precisar pedir. **A política é `docs/VERIFICATION-POLICY.md`** — leia a seção 2 (natureza → tipo) e a 3 (criticidade → rigor) e aplique. Não decida de memória, e não reescreva a tabela aqui: uma cópia divergiria.

Preencha no `project.yaml` o bloco `verificacao`, incluindo `revisao_independente`, que é **derivado** de `classificacao.criticidade` conforme o ADR-0007 — `baixa` → `nenhuma`, `media` → `qa`, `alta` → `qa+security`. Se `dados_sensiveis: true`, o mínimo é `qa+security`, qualquer que seja a criticidade.

Pasta de verificação vazia não conta — e o template já resolve isso: `tests/` nasce com a suíte de fumaça, que verifica o **contrato** do projeto (manifesto legível, sem placeholder, comando de teste apontando para arquivo que existe, trilha única) e reprova quando entra código em `scripts/` sem nenhum teste próprio. Não apague a suíte de fumaça. Se ainda não há comportamento probabilístico para medir, **não crie** `evals/` — estrutura vazia mente sobre maturidade.

**Critério de aceite vai para o manifesto, não para a asserção.** Preencha `verificacao.criterio_de_pronto` com a frase, e `verificacao.limites` com os números que as asserções comparam. Os testes leem de lá (`limite("nome")` em Python, `Get-LimiteDoManifesto` em PowerShell) e **falham** quando o limite não está declarado. Isso existe porque no `conversor-utm` o critério "dentro de 1 metro" acabou em três lugares — prosa do README, docstring do teste e um `1.0` cravado — sem fonte de verdade em nenhum. Número repetido envelhece.

Se o projeto lê arquivo de fora (CSV, planilha, JSON), inclua um exemplo pequeno e inventado em `examples/` e faça o README apontar para ele. O `.gitignore` do template bloqueia `*.csv` mas libera `examples/`. Sem isso, o comando do README aponta para um arquivo que não existe no clone.

## 7. Recomendar a arquitetura de execução

Preencha `execucao.modo_atual` no `project.yaml`. Para projeto novo, quase sempre `main-claude` — e isso está certo.

Só recomende outro modo se houver benefício material **agora**, não hipotético. E registre em `docs/STATE.md` que o modo deve ser reavaliado quando o projeto crescer.

## 8. Fechar

```
Criado: <caminho completo>

Git: main, commit inicial <sha> (<assinado | sem assinatura>)
Remoto: <url privada | pendência H2 "sem remoto" | --sem-remoto>
Drive: EMMILY PROJECT CLOUD/<drive_root>
Nível atingido: <Ln> — falta: <o que o eos new listou>
Contrato: registry/projects/<id>.yaml gravado na plataforma, NÃO commitado
Bootstrap: <resultado>
Verificação: <o que foi criado e por quê>

Próximo passo: <o que está escrito no STATE.md>
Para chegar a L6: py -3.13 -m eos certify <id>
Ajustes posteriores ao nascimento: /os:checkpoint, quando você pedir
```

## Anti-falsos-positivos

- **Nem toda ideia é projeto.** Pergunta pontual é conversa. Script de 20 linhas de uso único é tarefa. Projeto é o que tem continuidade, estado e valor em ser retomável. Se for tarefa, diga isso e faça a tarefa.
- **Não rode `eos new` sem o "sim" ao plano do `--dry-run`.** O "sim" autoriza o commit inicial, o remoto privado e o push que ele faz; nenhum outro commit sai desta skill — os seguintes são da Emmily, via `/os:checkpoint`.
- **Não commite a plataforma.** O contrato que o `eos new` grava em `registry/projects/` fica no disco até ela pedir.
- **Remoto é sempre privado** (ADR-0003, ADR-0015). Se ela não quiser remoto agora, `--sem-remoto`; nunca público.
- **Não crie à mão o que o `eos new` cria.** Copiar o template, `git init` e commit por fora pulam as verificações e o diário de retomada.
- **Nunca rode `eos new` contra o GitHub/Drive reais para "testar".** O teste é `--dry-run`.
- **Não mova nem reorganize projeto existente** durante a criação de um novo.
- Se ela já estiver trabalhando numa pasta com arquivos, **não sobrescreva nada**: proponha estruturar no lugar, mostrando exatamente o que seria criado e o que seria preservado.
