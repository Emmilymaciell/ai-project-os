# ADR-0006 — Semantic Versioning, e tag só depois de validação ponta a ponta

- **Data:** 2026-09-08
- **Status:** Aceita
- **Fase:** 1 (bloco J)

## Contexto

O plano original da Fase 1 criava a tag `v0.1` junto com o primeiro commit da fundação.

Isso confundiria duas coisas diferentes: *"o código existe e está estruturado"* e *"o sistema foi verificado funcionando"*. No momento do primeiro commit, a plataforma tinha 27 testes internos passando, validação estrutural oficial aprovada e o plugin carregando com 5 skills — mas **nenhuma das skills havia sido invocada de verdade**. Manifesto válido não é skill funcionando.

Havia também uma inconsistência: `plugin.json` já declarava `0.1.0` (três componentes), enquanto o plano falava de `v0.1` (dois).

## Decisão

1. **Semantic Versioning** (`MAJOR.MINOR.PATCH`) para todas as tags e para o campo `version` do `plugin.json`. Sem versão de dois componentes.
2. **Tag significa versão validada ponta a ponta**, não "commit que parece importante". Uma tag só nasce depois de o ciclo real ter sido exercitado.
3. Em consequência: o primeiro commit da fundação (`chore(platform): bootstrap Emmily AI Project OS foundation`) **não recebe tag**. `v0.1.0` fica reservada para depois do bloco I, quando as cinco skills tiverem sido usadas no Claude Desktop.
4. Interpretação do SemVer nesta plataforma, enquanto a MAJOR é 0:
   - **MINOR** — uma fase entregue e validada, ou skills novas.
   - **PATCH** — correção, ajuste de documentação, endurecimento de teste.
   - **MAJOR 1.0.0** — quando o critério de sucesso do handoff (§36) estiver atendido: ideia vira projeto com pouco trabalho manual, chats deixam de ser ponto único de falha, projetos são portáteis e a qualidade é verificável.
5. O `version` do `plugin.json` acompanha a tag. Não é decorativo: é o campo que decide se `claude plugin update` entrega a atualização para a cópia instalada.

## Critério de "validado ponta a ponta" para `v0.1.0`

O ciclo do bloco I, em projeto descartável, com os 11 passos verificados:

`/os:new-project` → estrutura gerada → Git inicializado corretamente → `project.yaml` → `CLAUDE.md` → `STATE.md` → `/os:status` → uma alteração pequena real → `/os:checkpoint` → `/os:handoff` → **retomada em sessão nova, confirmando que o projeto continua compreensível sem o chat anterior.**

O décimo primeiro passo é o que realmente importa: é o teste do princípio central (projeto ≠ sessão). Os dez anteriores podem passar num sistema que ainda depende da conversa; só o último prova que não depende.

## Alternativas consideradas

- **Tag no primeiro commit.** Rejeitada: rotularia como versão algo nunca executado. Numa plataforma cujo propósito é tornar qualidade verificável, seria o exemplo errado dado pela própria plataforma.
- **`v0.1` (duas componentes).** Rejeitada: divergiria do `plugin.json` e do que as ferramentas do ecossistema esperam.
- **Nenhuma tag até `1.0.0`.** Rejeitada: perderia os pontos de retorno intermediários, que são justamente o valor da tag.

## Consequências

- Positiva: tag passa a carregar informação — se existe, o ciclo foi exercitado.
- Positiva: fim da divergência entre a versão do plugin e a do repositório.
- Negativa: o primeiro commit fica sem marcador. Aceito — o commit tem mensagem descritiva, e a tag vem em seguida.
- **A skill `/os:checkpoint` deve refletir isso:** ela já diz "tag só se for marco" e "pergunte antes". A partir daqui, marco significa *validado ponta a ponta*.

## Emenda de 2026-10-16 — PATCH do plugin entre tags

**Motivo.** O guarda `PreToolUse` de git destrutivo (`hooks/hooks.json`) só chega à cópia instalada do plugin se o `version` do `plugin.json` mudar — `claude plugin update` sem bump é no-op silencioso. Esperar a próxima tag deixaria o guarda inativo até lá; subir para `0.2.0` anteciparia a MINOR que o item 4 reserva para o fechamento da Fase 2.

**Regra (acrescenta ao item 5, não o substitui):**

1. Entre duas tags, o `version` do `plugin.json` pode subir **só o PATCH** (`0.1.0` → `0.1.1` → ...), para que `claude plugin update` distribua hooks, skills ou agents já integrados.
2. Esse PATCH **não** cria tag nem afirma validação ponta a ponta: tag continua exigindo o item 2.
3. A próxima tag fixa um MINOR/MAJOR **maior que qualquer PATCH intermediário** (ex.: `v0.2.0` depois de `0.1.1`), e o `plugin.json` volta a acompanhar a tag a partir dela.

Primeira aplicação: `0.1.0` → `0.1.1` em 2026-10-16, para distribuir o guarda de git; `0.1.1` → `0.1.2` no mesmo dia,
para distribuir o `"shell": "powershell"` explícito do hook (medido: sem ele, saída ≠ 0/2 bloqueava); `0.1.3` para a
propagação do código de saída (medido: com `0.1.2` o `powershell -Command` devolvia `1` e o comando passava) e o caminho
pelo ambiente; `0.1.4` para o caminho seguro (ambiente primeiro, argumento só absoluto com unidade; achado da r17).
