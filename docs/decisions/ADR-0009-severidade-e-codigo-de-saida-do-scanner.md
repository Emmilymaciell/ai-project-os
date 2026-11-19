# ADR-0009 — Escada de severidade do scanner, e o que trava o fluxo

- **Data:** 2026-09-08
- **Status:** Aceita
- **Fase:** 2 (subfase 2.3)

## Contexto

Até a subfase 2.2, `scripts/security-scan.ps1` saía com `1` diante de **qualquer** achado. Funcionava porque o scanner mínimo só produzia duas classes de achado, ambas concretas: credencial em arquivo e nome de arquivo sensível.

A 2.3 fecha as quatro áreas que estavam `INCONCLUSIVO`, e com isso o scanner passa a produzir uma classe de fato **diferente em natureza**:

| Fato | É exposição? |
|---|---|
| Token do GitHub num arquivo rastreado | Sim |
| `.env` que existiu no histórico | Sim |
| Nome de segredo canônico sem regra no `.gitignore` | **Não.** É guarda-corpo ausente |
| Fixture de teste negativo com valor fabricado | **Não.** É o teste existindo |
| E-mail que assina os commits deste repositório | **Não.** É a identidade do autor |

Com a regra antiga, os três últimos travariam o fluxo. E o dano é concreto, não hipotético: este repositório tem uma fixture declarada e o e-mail da autora em cinco arquivos, então **todo checkpoint desta plataforma passaria a falhar para sempre**, por fatos que ninguém deveria agir sobre.

O modo de falha seguinte é conhecido e pior que o primeiro: quando o scanner trava por ruído, a pessoa aprende a ignorar o scanner. Um detector que grita sempre é equivalente a não ter detector — com o agravante de produzir a sensação de estar protegido.

A alternativa óbvia — **não reportar** esses fatos — cai na regra que a 2.2 estabeleceu ao tratar as fixtures: *reclassificar, não silenciar*. Guarda-corpo ausente **importa**; ele só não é urgente.

## Decisão

**Três severidades, e a linha de bloqueio fica entre MEDIA e BAIXA.**

| Severidade | Significa | Trava | Exemplo |
|---|---|---|---|
| **ALTA** | Algo indevido está exposto, ou entraria num commit agora | sim | credencial rastreada, `.env` no histórico, remoto público, webhook versionado |
| **MEDIA** | Algo questionável está presente e exige decisão de uma pessoa | sim | documento operacional versionado, CPF válido, e-mail de terceiro, `pull_request_target` |
| **BAIXA** | Fato registrado para contestação | **não** | segredo canônico sem cobertura no `.gitignore`, fixture declarada, identidade do próprio autor, regra de `.gitignore` sombreada |

A escada mede **exposição**, não importância.

Código de saída de `scripts/security-scan.ps1`:

| Código | Significado |
|---|---|
| `0` | Nenhum achado ALTA nem MEDIA. Pode haver BAIXA no relatório |
| `1` | Pelo menos um achado ALTA ou MEDIA |
| `2` | Erro de execução — inclui detector ausente |

`2` não é uma variação de `1`. É "a varredura não aconteceu", e quem chama tem de tratar diferente: ausência de varredura nunca é aprovação (política 4.5).

### O que impede isto de virar uma porta dos fundos

Três coisas, e as três têm teste:

1. **BAIXA continua no relatório**, em seção própria — "Fatos registrados (BAIXA — não bloqueiam)". Nada é engolido.
2. **A seção diz que quem revisa pode discordar da classificação.** Reclassificar não é ter razão.
3. **O relatório explica a escada e aponta este ADR.** Quem lê sabe o que o `exit 0` está afirmando, e o que não está.

## Precisão sobre a política 4.6

A política diz *"achado de segurança interrompe, sempre"*. Isso continua valendo, e a linha de bloqueio é **MEDIA ou acima**. BAIXA não é achado de segurança no sentido da 4.6: é fato de higiene. A política ganhou essa precisão na seção 4.6, com ponteiro para cá — o mesmo texto em dois lugares divergiria, e um deles envelheceria.

## Alternativas consideradas

- **Manter `exit 1` para qualquer achado.** Rejeitada: travaria esta plataforma permanentemente por causa de uma fixture e do e-mail da autora, e ensinaria a ignorar o scanner.
- **Não emitir BAIXA.** Rejeitada: guarda-corpo ausente é informação real. Silenciar contraria a convenção de reclassificar, e a lacuna do `.gitignore` deste repositório (`id_rsa` e `service-account.json` descobertos) só apareceu porque o detector fala.
- **Um código de saída próprio para "só BAIXA"** (`0` nada, `3` só BAIXA, `1` bloqueante). Rejeitada: quebraria o contrato `0/1/2` que a skill, os testes e o futuro hook de pre-push já usam, em troca de informação que o relatório e a saída de console já dão. Complexidade de interface sem ganho de decisão.
- **Arquivo de exceções declaradas** (`.security-allowlist`). Rejeitada por agora: allowlist envelhece e vira lugar onde problema real se esconde. A reclassificação atual é **derivada** — identidade vem do `git log`, fixture vem de declaração no cabeçalho do próprio arquivo — e derivado não envelhece.

## Consequências

- Positiva: `exit 0` volta a significar "nada exige ação", que é a única coisa útil que um código de saída pode significar.
- Positiva: o relatório fica mais informativo, não menos — os fatos BAIXA deste repositório são dezenas, e a versão anterior não teria mostrado nenhum. (Sem número aqui de propósito: um ADR que carrega contagem volátil envelhece, e este chegou a nascer dizendo "13" quando eram 21.)
- Positiva: o futuro hook de pre-push (subfase 2.6) pode usar o código de saída direto, sem interpretar texto.
- Negativa: alguém pode ler `exit 0` como "repositório limpo". Mitigado no texto do relatório, que diz explicitamente o que o `0` afirma — e não afirma.
- Negativa: a linha entre MEDIA e BAIXA é um julgamento, e julgamento erra. Mitigado por: a classificação de cada categoria está no código, tem teste, e o revisor é instruído a contestá-la.
