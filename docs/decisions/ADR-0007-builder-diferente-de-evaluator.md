# ADR-0007 — Builder ≠ Evaluator: quando separar, e quando não

- **Data:** 2026-09-08
- **Status:** Aceita
- **Fase:** 2 (subfase 2.1)

## Contexto

`docs/VISION.md` §16 estabelece o princípio: *"Quem implementou não deve ser a única fonte de validação"*, com o fluxo `Architect/Planner → Builder → Tests/Evals → QA independente → Security → Human Review`.

O princípio é correto e tem custo. Aplicá-lo a tudo transforma um script de vinte linhas em processo de release. Não aplicá-lo a nada devolve o problema que ele resolve. Este ADR define **onde fica a linha**, para que a decisão não seja tomada de novo a cada tarefa.

O problema é real e específico. Quem acabou de implementar não é um revisor ruim por descuido: é um revisor comprometido. Já formou a hipótese de que está certo, sabe onde olhou, e revisar o próprio trabalho vira procurar confirmação em vez de procurar defeito. A Fase 1 produziu quatro evidências disso na própria plataforma:

1. Escrevi um teste que **presumia** que declarar o fuso UTM errado seria detectável. Não era — a longitude de saída é, por construção, próxima ao meridiano central do fuso declarado. O teste estava errado, o código estava certo, e eu só descobri porque ele falhou.
2. O bug de CSV com BOM passou por **27 testes verdes**, porque os testes geravam o arquivo pelo próprio Python, sem BOM. Quem escreveu o código escreveu o teste, e os dois compartilharam o mesmo ponto cego.
3. O `project.yaml` desatualizado só apareceu quando um **agente sem acesso a nenhuma conversa** leu o repositório e percebeu que a versão declarada contradizia o `STATE.md`.
4. A exceção do teste de sintaxe apontava para `run-tests.ps1` **por nome**, e ficou obsoleta na refatoração que eu mesmo fiz — no mesmo commit em que a criei.

Os itens 2 e 3 são o argumento inteiro: nenhum dos dois seria achado por mais testes escritos por quem escreveu os primeiros.

## Decisão

**A separação é obrigatória a partir de criticidade `media`, e o mecanismo é contexto isolado.**

| Criticidade | Revisão independente | Como |
|---|---|---|
| `baixa` | Não exigida | Auto-revisão no `/os:checkpoint` basta. O dano de errar é refazer. |
| `media` | **QA obrigatório** | `qa-reviewer` (subfase 2.2), contexto isolado, sem acesso à conversa que produziu o código |
| `alta` | **QA + security obrigatórios** | `qa-reviewer` + `security-reviewer`, ambos isolados, mais revisão humana antes de release |

Independentemente da criticidade:

- **`dados_sensiveis: true` sempre dispara o `security-reviewer`.** Exposição de dado de terceiro não tem versão barata.
- **Antes de qualquer release ou handoff**, a verificação em clone limpo é obrigatória. É a forma mais barata de revisão independente que existe: o clone não sabe o que estava instalado na máquina de quem construiu.

### O que "contexto isolado" significa aqui, concretamente

O revisor recebe: o diff, o `STATE.md`, os ADRs e o repositório. Não recebe a conversa em que o código foi escrito, nem o raciocínio de quem o escreveu, nem a lista do que já foi verificado.

Isso é deliberado e é o ponto todo. Se o revisor souber que "isso já foi testado", ele não testa. A ignorância é o instrumento.

### O que o revisor tem que produzir

Não "está bom". Um veredito com evidência: o que ele executou, o que observou, e o que **não** conseguiu determinar. "Não determinável pelo repositório" é resultado válido e frequentemente o mais útil.

## Alternativas consideradas

- **Sempre separar.** Rejeitada: um script pessoal de criticidade baixa não paga o custo de dois revisores, e processo desproporcional treina a pessoa a contorná-lo. Cerimônia que se ignora é pior que ausência de processo, porque dá a impressão de cobertura.
- **Nunca separar; confiar em mais testes.** Rejeitada pelas evidências 2 e 3 do contexto. Mais testes escritos pela mesma cabeça herdam o mesmo ponto cego — o caso do BOM é a demonstração exata.
- **Separar por tamanho do diff em vez de criticidade.** Rejeitada: diff pequeno em projeto crítico é justamente onde o erro caro se esconde. Uma linha de `encoding=` mudou o comportamento com toda planilha real de Excel.
- **Revisão humana sempre, sem revisor automático.** Rejeitada como regra geral: a atenção da Emmily é o recurso escasso desta plataforma. Ela deve ser gasta onde o julgamento humano é insubstituível — decisão, prioridade, aceitação — e não em reler diffs que um revisor isolado leria melhor.

## Consequências

- Positiva: os defeitos que sobrevivem a testes verdes passam a ter um mecanismo que os pega, em vez de depender de sorte.
- Positiva: a linha está escrita, então a decisão não é renegociada a cada tarefa.
- Positiva: a criticidade do `project.yaml` deixa de ser rótulo e passa a ter consequência operacional. Isso também melhora a honestidade da classificação.
- Negativa: cada revisão isolada custa contexto próprio e tempo. Aceito para `media` e `alta`; é exatamente por isso que `baixa` está de fora.
- Negativa: o revisor isolado vai produzir falso positivo, porque desconhece decisões que estão registradas fora do que ele leu. Mitigação: ele recebe `docs/decisions/`, e a seção de armadilhas do handoff existe para essa classe de mal-entendido. Falso positivo do revisor é barato; falso negativo de quem construiu, não.
- **Aplica-se à própria plataforma.** A partir da subfase 2.3, cada subfase da Fase 2 passa pelos revisores construídos na 2.2. Uma plataforma que prega Builder ≠ Evaluator e não se submete a ele estaria se dando uma exceção que não concede a ninguém.
