# ADR-0010 — Exceções de segurança aprovadas: estreitas, citáveis e que não silenciam

- **Data:** 2026-09-08
- **Status:** Aceita
- **Fase:** 2 (subfase 2.3)
- **Decisão da Emmily**, com o trade-off apresentado pelos dois revisores independentes antes da implementação.

## Contexto

O **ADR-0009** define que `ALTA` e `MEDIA` travam o fluxo. Ele não previu um caso que apareceu logo na primeira execução real do scanner completo: **um achado verdadeiro, analisado, e deliberadamente aceito.**

O caso concreto é `docs/audits/2026-09-05-fase0-auditoria.md`, o relatório da Fase 0. Ele carrega o e-mail de coordenação de uma organização terceira (Programa), o e-mail corporativo da própria mantenedora e estrutura de pastas corporativas. O `security-reviewer` verificou, por leitura própria de `.git/refs/heads/main` e `.git/refs/remotes/origin/main`, que **os dois são o mesmo sha** — o blob já está no remoto desde a Fase 0.

Isso descarta o caminho barato. Sanitizar o working tree não desfaz nada; só reescrever o histórico fecharia, e reescrever histórico é destrutivo, exige `push --force` e é desproporcional para este achado num repositório privado.

Sem mecanismo de aceitação, a consequência era mecânica e conhecida: `security-scan.ps1` sairia com `1` neste repositório **para sempre**, e todo `/os:checkpoint` falharia. O `security-reviewer` nomeou o problema com precisão — é o modo de falha do próprio ADR-0009 reaparecendo uma camada acima: **o detector que trava sempre é o detector que se aprende a ignorar.**

E havia um risco simétrico, que a Emmily nomeou explicitamente: uma allowlist genérica — por domínio, por extensão, por diretório — resolveria o ruído criando um buraco. Achado novo cairia na allowlist antiga e desapareceria sem ninguém decidir nada.

## Decisão

**Exceção aprovada existe, é legível por máquina, e é estreita.**

Vive em `project.yaml` → `classificacao.dados_sensiveis_excecoes[]`, no schema do template — não em formato paralelo da plataforma. Cada entrada exige **todos** estes campos:

| Campo | Papel |
|---|---|
| `caminho` | Caminho **exato**. Não diretório, não curinga |
| `categoria` | A categoria **exata** do achado, como o relatório a escreve |
| `natureza` | O que existe naquele caminho |
| `justificativa` | Por que é aceitável |
| `decisao` | O que foi decidido, **e o que continua exigido** |
| `status` | `aceito-por-excecao` é o **único** valor que vale |
| `decidido_em` | Data |
| `escopo` | `privado` |
| `onde_esta_registrado` | O ADR que registra a decisão |

### Quatro regras, cada uma contra um modo de falha concreto

**1. Não silencia.** O achado continua no relatório, com a **severidade original**, em seção própria — *"Achados ACEITOS POR EXCEÇÃO"* —, citando a exceção que o cobre, com justificativa e data. Aceitar é uma decisão registrada, não um apagamento. Quem lê o relatório vê o achado e vê quem o aceitou.

**2. Correspondência exata de caminho E categoria.** Comparação por igualdade, não por prefixo, glob ou domínio. Um achado da mesma categoria em **outro arquivo** continua bloqueando. Uma categoria **diferente** no mesmo arquivo continua bloqueando. É o que separa exceção de allowlist.

**3. Só vale no fluxo privado autorizado.** Sob `-ParaPublicacao`, **toda** exceção é ignorada e os achados voltam a bloquear. Publicar ou exportar publicamente exige **sanitização**, não exceção. `portfolio.exposicao: nenhuma` permanece.

**4. Pendente não é aceita.** `status` diferente de `aceito-por-excecao`, ou qualquer campo obrigatório faltando, significa que a exceção **não cobre nada**. O relatório lista essas entradas numa subseção própria, dizendo que existem e que não liberam nada.

### Onde a regra é aplicada

Num lugar só, no orquestrador, **depois** de todos os detectores. Nenhum detector conhece exceção — eles apenas acham. Isso mantém cada detector testável em isolamento e concentra a regra de aceitação num ponto auditável.

## Emenda de 2026-09-10 — o que a revisão independente corrigiu

A revisão pendente da 2.3 rodou depois que o `/login` foi renovado, e os **dois revisores convergiram independentemente** no mesmo defeito: a implementação **não cumpria a regra 2 deste ADR**. Emendas incorporadas:

**1. A comparação de caminho era por prefixo, não por igualdade.** O código comparava o caminho declarado contra o **início da string `Detalhe`**, que é prosa (`arquivo linha ~N, ...`). Consequências alcançáveis com uma linha de manifesto: uma exceção para `docs/audits/x.md` cobria também `docs/audits/x.md-copia.md`, e `caminho: "docs"` cobria a árvore inteira naquela categoria — **a allowlist por diretório que este ADR diz ter recusado**. Pior: o relatório gerado *afirmava ao leitor* "correspondência exata de caminho E categoria", garantia que o código não entregava.

A causa raiz não era o `StartsWith`: era **extrair caminho de prosa**. O achado passou a carregar `Caminho` como **campo estruturado** (`New-Achado`), e a comparação é igualdade. Achado sem caminho não casa com exceção nenhuma — falha fechado. O ramo perigoso deixou de existir em vez de ser ajustado.

E o teste que devia provar a regra usava dois nomes **sem prefixo comum**, então passava com `StartsWith`, com `-like` ou com igualdade: verde sobre ramo não exercitado. Agora há caso com nome irmão que começa igual, e caso com caminho declarado como diretório.

**2. Exceção não cobre achado de severidade `ALTA`. Nunca.** O mecanismo percorre todos os achados, mas o campo se chama `dados_sensiveis_excecoes` e este ADR foi escrito inteiro em torno de dado pessoal. O `security-reviewer` mediu a distância: uma entrada com categoria de credencial dispensaria um achado `ALTA` de `working tree` e o scanner sairia com `0`. Neste repositório governante, é a diferença entre *"aceitar um e-mail num relatório de auditoria"* e *"dispensar um token vivo"*.

O limite é **por severidade**, aplicado antes do casamento, e o relatório declara quando recusou. **Alargar isso é decisão da mantenedora, registrada em ADR — não inferência da ferramenta.** A escolha de estreitar não precisou de decisão nova porque ela *retira* permissão; conceder é que precisaria.

**3. `status` correto com campo obrigatório faltando agora aparece no relatório, com o motivo.** A separação entre aceitas e não-aceitas olhava **só** o `status`, então a entrada incompleta caía em "aceitas", era descartada em silêncio no casamento e **nunca** aparecia na subseção que a regra 4 exige. Quem escreveu a exceção não tinha sinal que distinguisse *"malformada"* de *"não casou"*, num fluxo em que `exit 1` reprova todo checkpoint. Agora aceita exige status **e** completude, e o relatório nomeia o campo que falta.

**4. O guarda-corpo de teste aceitava diretório.** `Test-Path` sem `-PathType Leaf` devolve verdadeiro para diretório — era o único obstáculo a `caminho: "docs"`. Passou a exigir arquivo.

**5. O parser reconhecia uma entrada só quando `caminho` era a primeira chave — e falhava aberto.** Achado da **segunda rodada** de revisão, sobre o código já corrigido pelos itens 1 a 4: o `qa-reviewer` reprovou com um `ALTA`. Numa lista de duas entradas em que a segunda começasse por `categoria`, a segunda entrada não era criada, o `caminho:` dela **sobrescrevia o caminho da entrada 1**, e a entrada 1 conservava o `status: "aceito-por-excecao"` já lido. A varredura passava a aceitar um par (caminho, categoria) que **ninguém decidiu**, e a lista de recusadas ficava vazia — portanto **nenhum sinal no relatório**. Ordem de chaves em YAML é livre; depender dela é depender de acidente.

A entrada passou a ser reconhecida pelo **marcador `-` de item de lista**, em qualquer ordem de chaves, e o portão de aceitação é aplicado **uma única vez** a todas as entradas coletadas. Guardado por dois casos: segunda entrada com chaves fora de ordem não contamina a primeira; entrada única com chave antes de `caminho` é reconhecida.

Isto emenda o custo declarado nº 2 abaixo: o parser continua próprio e estrito quanto ao **formato do campo** (`chave: "valor"`), mas não é mais sensível à **ordem** das chaves.

## Fatos declarados abertos pela revisão de 2026-09-10 (severidade `BAIXA`)

Aprovados **com** estes itens nomeados, registrados em `docs/STATE.md`. Nenhum é defeito do mecanismo; todos são superfície que existe. Estreitar cada um é decisão da mantenedora.

1. **O marcador de fixture é rota mais larga que este mecanismo.** `SEGREDO-FABRICADO-PARA-TESTE` no cabeçalho rebaixa `ALTA`→`BAIXA` sem exigir caminho, categoria, justificativa nem decisão registrada, e **não** é ignorado por `-ParaPublicacao`. O mecanismo mais rigoroso recusa `ALTA`; o mais frouxo não.
2. **A completude cobra 5 dos 9 campos** que a regra 3 declara obrigatórios. Os outros quatro são documentais e nada os exige.
3. **Uma exceção cobre ocorrências ilimitadas** dentro do mesmo par (caminho, categoria), sem limite de contagem nem carimbo do conteúdo aceito.

E uma nota de comportamento: a igualdade de caminho e de categoria usa os operadores do PowerShell, que são **case-insensitive**. Coerente com o sistema de arquivos do Windows; num clone em Linux, `Docs/a.md` casaria com uma exceção para `docs/a.md`.

## O que isso custa, declarado

1. **A exceção envelhece com o texto da categoria.** Se o nome de uma categoria de achado mudar, a exceção deixa de casar e o achado volta a bloquear. Isso é o lado seguro da falha, e é deliberado: exceção que sobrevive a mudança de detector é exceção que ninguém revisou.
2. **O parser de YAML é próprio e estrito.** A plataforma não tem dependência de YAML e não vai ganhar uma para ler nove campos. Em troca, campo fora do formato `chave: "valor"` não é lido — e não ser lido significa não cobrir nada.
3. **Alguém pode ler `exit 0` como "repositório limpo".** Mitigado pelo relatório, que mostra o achado aceito na frente e diz o que o `0` afirma. Não é eliminado.

## Alternativas consideradas

- **Reescrever o histórico** (`git filter-repo` + `push --force`). Rejeitada pela Emmily para este achado: destrutivo e desproporcional num repositório privado onde o uso é permitido. Continua sendo o único caminho que fecha de verdade, e fica disponível se a classificação do repositório mudar.
- **Allowlist por domínio ou por padrão.** Rejeitada explicitamente. Resolveria o ruído criando um buraco: achado novo cairia na allowlist antiga e desapareceria sem decisão.
- **Reclassificar o achado para `BAIXA`.** Rejeitada: mentiria sobre a severidade. O achado é `MEDIA` — o que muda é a **disposição**, não o que ele é. Separar as duas coisas é o que torna o relatório honesto.
- **Deixar sem mecanismo e conviver com `exit 1` permanente.** Rejeitada por ser exatamente o modo de falha que o ADR-0009 existe para evitar.

## Consequências

- Positiva: `exit 0` volta a significar "nada exige ação **que já não tenha sido decidida**", e o relatório mostra o que foi decidido.
- Positiva: a decisão fica no repositório, com justificativa e data, e é citada em toda execução. Não vive numa conversa.
- Positiva: o mecanismo serve aos projetos governados, porque o campo está no schema do template e o `/os:new-project` pergunta.
- Negativa: mais uma superfície onde um achado pode deixar de bloquear. Mitigada por: correspondência exata, campos obrigatórios, o achado continuar visível, `-ParaPublicacao` ignorar tudo, e um bloco de testes dedicado na suite `scanner` (casos com prefixo `excecao:`) — inclusive os que provam que achado parecido em outro arquivo **continua** bloqueando e que achado `ALTA` **nunca** é coberto.
- O `docs/VERIFICATION-POLICY.md` §4.6 ganhou a precisão: a linha de interrupção é `MEDIA` ou acima **e sem exceção aprovada**.

## Emenda de 2026-10-16 — dado de terceiro aceito SEM detector (registro de provenance)

**Fato.** `registry/projects/engenharia-rodoviaria.yaml` (bloco `tool_accounts`, linhas ~88-92) contém o **nome completo de uma pessoa física terceira** — titular de uma conta de ferramenta usada pela mantenedora. O nome não é transcrito aqui nem em lugar nenhum fora daquele arquivo.

**Decisão:** aceito por exceção no fluxo privado.

| Campo | Valor |
|---|---|
| `caminho` | `registry/projects/engenharia-rodoviaria.yaml` |
| `categoria` | nome de pessoa física terceira em registro de provenance |
| `natureza` | nome de titular de conta de ferramenta, num registro de provenance |
| `justificativa` | repositório privado (ADR-0003); necessário para explicar metadados de ferramenta **sem atribuir autoria** (H4, opção C, 2026-10-15); o blob já está no remoto |
| `decisao` | aceito por exceção no fluxo privado; publicação ou export público exige sanitização (`security-scan.ps1 -ParaPublicacao` **e** revisão manual, porque nenhum detector acha nome de pessoa) |
| `status` | `aceito-por-excecao` |
| `decidido_em` | 2026-10-16 |
| `escopo` | `privado` |

**Por que NÃO está em `project.yaml` → `dados_sensiveis_excecoes`.** Aquela lista é a entrada **de máquina** do mecanismo, e a suíte `docs` exige que toda `categoria` dela seja **emitida por algum detector** de `scripts/lib/` — senão a exceção "não cobriria nada, e em silêncio". Nenhum detector emite nome de pessoa: registrar lá quebraria esse guarda-corpo e criaria uma entrada que nunca casa. Por isso a decisão vive **só neste ADR**, como decisão humana documentada. Consequência declarada: o scanner **não** acusa este dado, então o portão de publicação depende de revisão manual deste item além do `-ParaPublicacao`.
