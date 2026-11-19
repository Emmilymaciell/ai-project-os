# Política de verificação

Este documento responde a uma pergunta só: **o que conta como verificado.**

Ele existe porque a resposta não pode depender de gosto nem de alguém lembrar. As skills `/os:new-project`, `/os:checkpoint`, `/os:doctor` e `/os:security` consultam esta política; ela é a fonte, e elas não repetem o conteúdo.

## 1. A definição

> **Verificado = executado e observado.**

Não é verificado:

- o que "deveria funcionar";
- comando documentado e nunca rodado;
- pasta `tests/` que existe e está vazia;
- teste que só foi visto passar, sem nunca ter sido visto falhar;
- estrutura conferida no lugar onde foi construída, e nunca num clone limpo.

Os quatro últimos não são hipóteses. Cada um foi encontrado de verdade na Fase 1, e é por isso que estão nomeados.

## 2. Natureza do que se faz → tipo de verificação

Detectar isto é responsabilidade do Claude. A Emmily não deve precisar pedir.

| Se o trabalho… | Verificação | O que ela cobre |
|---|---|---|
| sempre dá o mesmo resultado para a mesma entrada | `tests/` | Correção lógica |
| depende de julgamento de modelo | `evals/` | Qualidade de saída probabilística |
| depende de serviço externo (SharePoint, Notion, n8n, API, Excel via COM) | integration test + mock | Contrato com o de fora |
| produz documento como entregável | validação de estrutura do artefato | O arquivo existe, abre e tem as partes esperadas |
| toca dado corporativo, pessoal de terceiro ou credencial | security check | Nada indevido sai daqui |
| será assumido por outra pessoa ou máquina | verificação em clone limpo | O contrato de portabilidade |

Um mesmo projeto pode cair em várias linhas. Nenhuma linha dispensa outra.

## 3. Criticidade → rigor

Rigor se ajusta ao dano de errar, não ao tamanho do código. Vem de `project.yaml` → `classificacao.criticidade`.

| Criticidade | O dano de errar | Exigido |
|---|---|---|
| **baixa** | Ninguém sofre; refazer é barato | Verificação do tipo apropriado (seção 2). Sem revisão independente. |
| **media** | Retrabalho, prazo apertado, alguém percebe | O de baixa **+ QA independente** no checkpoint (ver ADR-0007) |
| **alta** | Impacto em entrega, cliente, obrigação contratual ou dado de terceiro | O de média **+ security-reviewer independente + revisão humana antes de release** |

**Não inflar.** Script de uso próprio classificado como `alta` só produz cerimônia, e cerimônia treina a pessoa a ignorar o processo. O erro comum é para cima.

**Não desinflar.** Se `dados_sensiveis: true`, a criticidade é no mínimo `media`, independentemente do tamanho.

## 4. Regras que valem sempre

### 4.1 Todo detector precisa provar que acusa

Um scanner de segredos que nunca acusou nada não foi testado — foi só executado. Todo mecanismo cuja função é *detectar* algo precisa de dois testes:

- **positivo:** com o problema presente, ele acusa;
- **negativo:** sem o problema, ele fica quieto.

O segundo evita o detector que grita sempre; o primeiro evita o que nunca grita. Falta o primeiro com muito mais frequência.

### 4.2 Verificação em clone limpo antes de handoff ou release

Clonar em pasta nova, seguir **só** o que o README manda, e rodar. Nada de atalho, nada de "aqui eu já tenho instalado".

Foi assim que apareceu o bug de encoding de CSV do projeto de teste da Fase 1 — com 27 testes passando, porque os testes geravam o arquivo pelo próprio Python, sem BOM. Verificação no lugar onde a coisa foi construída tem um ponto cego estrutural: ela herda o ambiente de quem construiu.

### 4.3 Teste que falha interrompe o fluxo

Checkpoint, release e push param. Reportar a saída real, não um resumo otimista. "Quase tudo passou" não é um estado.

### 4.4 Pasta de verificação vazia não conta

Criou `tests/`? Escreve um teste, mesmo trivial, e roda. Criou `evals/`? Se ainda não há comportamento probabilístico para medir, **não crie** — escreva num README por que ela não existe ainda. Estrutura vazia mente sobre maturidade.

**Nos projetos governados isto não depende de ninguém lembrar.** O `templates/project-standard/` nasce com a suíte de fumaça e um ponto de entrada único — `.\tests\run-tests.ps1`, declarado em `project.yaml` → `verificacao.comando`, o mesmo comando em todo projeto qualquer que seja a linguagem. O runner aplica os códigos de saída do ADR-0009: `0` passou, `1` falhou, **`2` a suíte não rodou** — sem suíte, sem `.venv`, trilha ambígua, ou nenhum caso executado. `2` não é uma variação de `1`, e o `bootstrap.ps1` do projeto **roda a suíte** e bloqueia quando o manifesto declara `tests: true` e a suíte não roda: declaração não é verificação.

**Critério de aceite mora no manifesto, não na asserção.** `verificacao.criterio_de_pronto` para a frase e `verificacao.limites` para os números que as asserções comparam. Os harnesses dos projetos leem de lá e **falham quando o limite não está declarado** — sem valor padrão, porque padrão silencioso transforma "o projeto não declarou seu critério" em "passou", que é a violação da 4.5 logo abaixo. Isso nasceu de um defeito medido: no `conversor-utm` o critério "dentro de 1 metro" existia em três lugares — prosa do README, docstring do teste e um `1.0` cravado — e em nenhum era fonte de verdade.

### 4.5 Ausência de evidência não é aprovação

A regra mais fácil de violar sem perceber, porque a violação é silenciosa.

Se uma verificação **não foi feita**, o resultado não é "passou": é **`INCONCLUSIVO`**, e `INCONCLUSIVO` bloqueia a área correspondente exatamente como `REPROVADO`.

O vocabulário de veredito tem três valores, nunca dois:

| Veredito | Significado |
|---|---|
| `APROVADO` | Evidência suficiente para a área, e nada encontrado |
| `REPROVADO` | Achado concreto, com localização e cenário |
| `INCONCLUSIVO` | Evidência insuficiente para concluir. **Não é aprovação parcial.** |

E é **por área**, não global. O veredito global é o pior dos parciais.

Consequências práticas:

- Todo coletor e todo scanner declara, em seção separada, **o que cobriu** e **o que não cobriu**.
- Quem revisa lê a seção do que *não* foi coberto **antes** dos achados. Ler os achados primeiro cria a impressão de que o escopo era completo.
- Contestar a cobertura recebida é parte do trabalho de quem revisa. *"O scanner não olhou X, e neste projeto X importa"* é um achado, não uma reclamação.
- "Os testes passaram" responde apenas sobre o que os testes exercitam. Passar não é cobrir.

Ver ADR-0008 para o mecanismo.

### 4.6 Achado de segurança interrompe, sempre

Independe de criticidade. Independe do tamanho do projeto. Reportar, propor a correção, esperar.

**Precisão sobre o que conta como achado aqui.** O scanner classifica em três severidades, e a linha de interrupção é **MEDIA ou acima, e sem exceção aprovada** — ver **ADR-0009** (a escada) e **ADR-0010** (as exceções). Exceção aprovada é estreita (caminho + categoria exatos), **não silencia** o achado e **não vale para publicação**: sob `-ParaPublicacao` toda exceção é ignorada. `BAIXA` é fato de higiene registrado para contestação (guarda-corpo ausente, fixture declarada, identidade do próprio autor), não exposição: continua no relatório e **não** interrompe. Reclassificar não é silenciar, e quem revisa pode discordar da classificação.

### 4.7 O que a verificação não cobre precisa estar escrito

Se o critério de pronto está parcialmente atendido, isso vai em `docs/STATE.md` na seção **Parcial**, com o que falta para fechar. Critério de pronto tratado como atendido quando não está é a forma mais cara de erro, porque ninguém procura o que acha que já resolveu.

## 5. Onde cada coisa mora

| Artefato | Onde | Quem atualiza |
|---|---|---|
| Testes determinísticos | `tests/` | Quem implementa |
| Evals | `evals/` | Ver `docs/EVAL-POLICY.md` (subfase 2.9) |
| Resultado da última verificação | `docs/STATE.md` | `/os:checkpoint` |
| O que a verificação declarou cobrir | `project.yaml` → `verificacao` | `/os:new-project` e `/os:checkpoint` |
| Divergência entre o declarado e o existente | detectada por `/os:doctor` | — |

O último item é o mais importante: `project.yaml` pode declarar `tests: true` sem que exista um único teste. Declaração não é verificação, e o `/os:doctor` existe em parte para pegar essa mentira.

## 6. Quem valida não deve ser só quem construiu

Ver **ADR-0007**. Resumo: a partir de criticidade `media`, o QA é feito com contexto isolado, porque quem implementou já formou a hipótese de que está certo e passa a procurar confirmação.
