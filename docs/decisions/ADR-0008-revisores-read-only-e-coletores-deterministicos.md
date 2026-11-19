# ADR-0008 — Revisores estritamente read-only, com coletores determinísticos separados

- **Data:** 2026-09-08
- **Status:** Aceita
- **Fase:** 2 (subfase 2.2)
- **Decisão da Emmily**, com o desenho e as limitações apresentados antes da implementação.

## Contexto

O ADR-0007 exige revisão independente a partir de criticidade `media`, e nomeia dois agentes: `qa-reviewer` e `security-reviewer`. `docs/VISION.md` §18 diz que o security reviewer deve ser *"preferencialmente read-only"*.

A pesquisa de documentação da Fase 2 encontrou o fato que decide o desenho: **agente de plugin ignora `permissionMode`, `hooks` e `mcpServers` — em silêncio.** O campo `tools` é o único limite de privilégio que existe para um agente distribuído por plugin.

E `Bash` não é "um pouco mais de acesso". `Bash` **é** acesso de escrita: `Set-Content`, `git commit`, `Remove-Item`. Um agente com `Read, Grep, Glob, Bash` é indistinguível, em capacidade, de um agente sem restrição alguma. Chamá-lo de "read-only" documentaria uma garantia inexistente, o que é pior que não ter a restrição — porque alguém confiaria nela.

## Decisão

**Os dois revisores são estritamente read-only: `tools: Read, Grep, Glob`, com `disallowedTools: Write, Edit, Bash, NotebookEdit` explícito por redundância defensiva.**

Toda execução determinística acontece **fora** dos agentes e produz evidência em arquivo:

```
scripts/collect-diff.ps1    → artifacts/review/diff-report.md
scripts/security-scan.ps1   → artifacts/review/security-report.md
                                        ↓ Read
              qa-reviewer          security-reviewer
                                        ↓
                    veredito com cobertura declarada
```

`artifacts/` é ignorado pelo Git: relatório de revisão é gerado, não versionado.

### Ausência de evidência não é aprovação

Esta é a regra que faz o desenho funcionar, e é exigência explícita da Emmily.

O veredito **não é binário**. São três:

| Veredito | Significado |
|---|---|
| `APROVADO` | Evidência suficiente para a área, e nada encontrado |
| `REPROVADO` | Achado concreto |
| `INCONCLUSIVO` | Evidência insuficiente. **Bloqueia a área**, não a aprova |

E o veredito é **por área**, não global. O global é o pior dos parciais: um `INCONCLUSIVO` em qualquer área derruba o global para `INCONCLUSIVO`.

Cada relatório de coletor declara, em seções separadas, **o que foi coberto** e **o que não foi**. Os agentes são instruídos a ler a seção do que *não* foi coberto **antes** dos achados — se lerem os achados primeiro, formam a impressão de que o escopo era completo.

Contestar a cobertura recebida é parte do trabalho do revisor, não uma cortesia: *"o scanner não olhou X, e neste projeto X importa"* é um dos achados mais valiosos que ele pode produzir.

## O que isso custa, declarado antes de implementar

1. **O `security-reviewer` não consegue consultar o Git.** `Read`/`Grep`/`Glob` veem o working tree, não `git log` nem blob de commit antigo. Um segredo commitado e depois removido do working tree é invisível para ele. Só o scanner o vê — e a **versão mínima da subfase 2.2 ainda não varre histórico**. Até a 2.3, o veredito sobre histórico é `INCONCLUSIVO`, e o relatório diz isso com essas palavras.

2. **O revisor fica limitado ao escopo do coletor.** Se o coletor não olhou algo, o revisor não pode ir buscar. Mitigado por: a seção de escopo não coberto ser obrigatória, e por contestar cobertura ser parte do papel dele. Não é eliminado.

3. **O `qa-reviewer` não roda os testes.** Quem roda é `collect-diff.ps1`, que grava a **saída real e o código de saída** — não um resumo. Se o coletor mentir, isso é bug de script, que é testável; um revisor complacente não é.

## Alternativas consideradas

- **`Bash` restrito por instrução no prompt do agente.** Rejeitada. Instrução não é limite; `tools` é. Um agente com `Bash` instruído a "usar só leitura" tem acesso de escrita, e a instrução é a única coisa entre ele e um `git commit`.
- **`Bash` só no `qa-reviewer`,** para ele rodar `git diff` e os testes por conta própria. Rejeitada por simetria de princípio e porque o ganho é pequeno: o coletor já entrega diff e saída real de teste. O custo seria abrir mão do read-only justamente no agente que revisa mudança de código.
- **Copiar os agentes para `.claude/agents/` para poder usar `permissionMode`.** Rejeitada: sairia do repositório do plugin, perdendo distribuição, versão e portabilidade — o mesmo motivo que o ADR-0004 usou para rejeitar `~/.claude/skills/`.
- **Sem revisores; confiar em mais testes.** Rejeitada pelo ADR-0007, com evidência.

## Consequências

- Positiva: "read-only" passa a ser uma garantia estrutural, não uma promessa. O limite é o campo `tools`, que o runtime aplica.
- Positiva: separar varredura de julgamento torna a varredura **testável** com teste positivo e negativo, como a política 4.1 exige. Um agente que varre e julga ao mesmo tempo não é testável deterministicamente.
- Positiva: o revisor não pode consertar o que revisa, então não há como ele "resolver" um achado silenciosamente.
- Negativa: mais peças — dois scripts e dois agentes em vez de dois agentes. Aceito: os scripts são a parte que se testa.
- Negativa: cobertura do revisor é limitada pela do coletor, e coletor incompleto produz muito `INCONCLUSIVO` no começo. Aceito e desejado: `INCONCLUSIVO` visível é melhor que aprovação otimista.
- `model: inherit` nos dois: a revisão roda no modelo da sessão. Se a Emmily estiver em Opus, a revisão é em Opus — e revisão é onde qualidade de julgamento paga.
