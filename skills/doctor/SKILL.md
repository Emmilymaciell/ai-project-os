---
name: doctor
description: Diagnostica o estado global do projeto - se ele e coerente, saudavel e retomavel sem a conversa. Le manifesto, STATE, ADRs, Git, dependencias declaradas e o frescor da ultima verificacao. Use ao retomar algo parado, antes de um handoff ou release, quando algo parecer fora do lugar, ou /os:doctor. NAO roda testes nem varre segredo.
---

# /os:doctor

Responder a uma pergunta que nenhuma outra ferramenta responde: **este projeto é continuável sem esta conversa?**

## As três perguntas, e por que não se sobrepõem

| Ferramenta | Pergunta |
|---|---|
| `tests` | o comportamento determinístico funciona? |
| `/os:security` | existe risco de exposição? |
| `/os:doctor` | o projeto **como sistema** é coerente, saudável e retomável? |

**A regra de separação é o critério mais importante desta skill:** o doctor **nunca roda a suíte** e **nunca varre conteúdo procurando segredo**. Se uma verificação precisa disso, ela pertence às outras duas — o doctor apenas **relata o que elas declararam**, com o `HEAD` de quando declararam.

Duplicar significaria dois detectores divergindo em silêncio, e esta plataforma já pagou por isso mais de uma vez.

## Como rodar

```
.\scripts\doctor.ps1                      # sobre o diretorio atual
.\scripts\doctor.ps1 -Path <caminho>      # aceita a raiz OU um subdiretorio
```

Sai em `artifacts/doctor/doctor-report.md` (humano) e `artifacts/doctor/doctor.json` (estruturado, versionado por `schema_version`).

## Como ler o resultado

| Status | Significa |
|---|---|
| `PASS` | rodou e passou |
| `WARN` | rodou, achou desvio que **não impede continuar** |
| `FAIL` | rodou e achou o que **impede** continuar |
| `INCONCLUSIVO` | **não conseguiu rodar**, ou rodou e **não conseguiu verificar parte** do que promete verificar |

**`INCONCLUSIVO` domina a agregação e sai com `2`.** Uma dimensão cujo **status** é `INCONCLUSIVO` derruba o diagnóstico inteiro, mesmo com todas as outras em `PASS`: *"não verifiquei" nunca vira "está bom"* (política 4.5).

**Quem decide é o status de cada dimensão, não a presença de lacuna.** Uma lacuna listada em *"O que NÃO foi verificado"* nem sempre muda o status de quem a declarou — quando o fato da **própria** dimensão está determinado, ela responde o fato. O caso é `raiz` sobre um caminho que não é repositório: sai `FAIL` e `1`, e a lacuna é sobre as **outras** dimensões, que não tiveram sobre o que rodar.

A regra importa na prática: um `project.yaml` com **placeholder de instanciação** (`{{NOME}}`), ou com `verificacao.tests` num valor que não é `true` nem `false`, sai `2` com a lacuna nomeando a causa. O conserto é no `project.yaml`, não na ferramenta — e a lacuna diz isso.

**Códigos de saída:** `0` para `PASS` e `WARN`; `1` para `FAIL`, e também para caminho **fora de repositório**, que é resposta determinada e não falta de evidência; `2` para `INCONCLUSIVO`, inclusive a forma não suportada (`bare`).

**Leia a seção "O que NÃO foi verificado" antes dos achados.** Ela é o que separa um `PASS` que significa alguma coisa de um `PASS` sobre o que ninguém olhou.

## O que fazer com cada dimensão

- **raiz** — se não resolveu, nada mais vale. *Bare* não é forma de projeto governado.
- **manifesto** — `FAIL` aqui é declaração contradita pelo disco. Corrija a declaração ou a realidade; nunca deixe as duas divergindo.
- **retomabilidade** — é a dimensão que justifica a plataforma. `FAIL` significa que retomar dependeria de arqueologia do histórico.
- **git** — repositório recém-criado com `HEAD` não nascido é **esperado**, não defeito.
- **ambiente** — só cobra dependência **declarada**. Se disser "não declaradas", o conserto é declarar, não instalar.
- **frescor** — `WARN` não é ruído: significa que a última evidência descreve outro commit.

## Anti-falsos-positivos

- **Não conclua nada a partir de `PASS` sem ler a cobertura.** Um `PASS` significa "as verificações que rodaram passaram", não "está tudo certo".
- **Não trate `WARN` de frescor como formalidade.** Evidência de outro `HEAD` é evidência de outro código.
- **Não interprete `ambiente: WARN` como ferramenta faltando.** Campo `dependencias` ausente significa que o projeto ainda não declarou quais são — ausência de declaração, não ausência de ferramenta.
- **Não conserte nada por conta do diagnóstico.** O doctor diz o que rodar; quem roda é a mantenedora. A skill **não** executa `/os:security`, não edita arquivo e não toca em Git.
- **Não rode o doctor esperando que ele substitua `tests` ou `/os:security`.** Ele não executa nenhuma das duas, e um `PASS` dele não diz nada sobre comportamento nem sobre risco.
- **Não reabra decisão registrada** porque o doctor apontou algo: os ADRs continuam valendo (ADR-0001).
