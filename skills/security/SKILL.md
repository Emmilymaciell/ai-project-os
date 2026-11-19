---
name: security
description: Varre o repositorio contra segredo, dado de terceiro e exposicao externa - working tree, historico do Git, .gitignore e remoto. Use antes de push, release ou handoff, ao mexer com credencial, ou /os:security.
---

# /os:security

Responder uma pergunta só: **algo indevido pode sair deste repositório?**

O que conta como verificado está em `docs/VERIFICATION-POLICY.md`. Esta skill **não repete** a política — consulta. Se houver divergência, a política vence.

## O princípio que organiza tudo aqui

**Quem varre não julga, e quem julga não varre** (ADR-0008).

`scripts/security-scan.ps1` executa e grava fatos. O `security-reviewer` lê os fatos e emite veredito. Você opera os dois, e não substitui nenhum: **não julgue no lugar do revisor** quando o rigor exigir revisão independente, e não peça ao revisor o que o scanner deveria coletar.

## 1. Varrer

```powershell
.\scripts\security-scan.ps1
```

Relatório em `artifacts/review/security-report.md` — ignorado pelo Git de propósito: relatório de revisão é gerado, não versionado.

Código de saída (ADR-0009): `0` sem achado bloqueante · `1` com achado ALTA ou MEDIA · `2` erro de execução.

**`2` não é uma versão pior de `1`.** É "a varredura não aconteceu", e ausência de varredura nunca é aprovação (política 4.5). Se vier `2`, conserte a execução e rode de novo — não interprete o relatório parcial.

Os dois modificadores existem para caso de latência, e **cada um custa cobertura**:

| Modificador | O que deixa de ser verificado |
|---|---|
| `-SemHistorico` | Segredo que foi commitado e depois apagado do working tree. Área `historico` fica `INCONCLUSIVO` |
| `-SemRede` | Visibilidade real do remoto. Área `exposicao externa` fica parcial |

Antes de push, release, handoff ou publicação, rode **sem modificador nenhum**. Se usou algum, diga qual e o que ficou de fora.

## 2. Ler o relatório na ordem certa

1. **Cobertura por área** — o que foi olhado, e com que volume.
2. **Escopo NÃO VARRIDO** — o que não foi olhado.
3. Só então os **Achados**.

Ler os achados primeiro cria a impressão de que o escopo era completo. É a mesma razão pela qual o `security-reviewer` recebe essa instrução: a ordem de leitura muda a conclusão.

As seis áreas são `working tree`, `historico`, `staging`, `gitignore`, `dado de terceiro` e `exposicao externa` — as mesmas sobre as quais o revisor emite veredito parcial.

## 3. Decidir o rigor pelo `project.yaml`, não pelo tamanho do achado

Leia `classificacao.criticidade` e `classificacao.dados_sensiveis`. A matriz criticidade → rigor está na política, seção 3, e no ADR-0007.

| `verificacao.revisao_independente` | O que fazer |
|---|---|
| `nenhuma` | O relatório mais a sua leitura bastam |
| `qa` | Idem — segurança não é o escopo do `qa-reviewer` |
| `qa+security` | Acione o `security-reviewer` **em contexto isolado** |
| **campo ausente, ou sem `project.yaml`** | **Trate como `qa+security`** e registre a lacuna |

A última linha não é detalhe: sem o campo, quem escolhe o rigor é quem acabou de construir — exatamente a decisão que o ADR-0007 tira da mão dele. Na dúvida o rigor é o máximo.

**Não conte ao revisor o que você já verificou.** É a ignorância dele que faz o mecanismo funcionar.

## 4. Veredito: três valores, por área

| Veredito | Quando | Efeito |
|---|---|---|
| `APROVADO` | Evidência suficiente para a área, e nada encontrado | Libera a área |
| `REPROVADO` | Achado concreto, com localização | Bloqueia |
| `INCONCLUSIVO` | Evidência insuficiente | **Bloqueia a área.** Não é aprovação parcial |

O global é **o pior dos parciais**. Um `INCONCLUSIVO` em qualquer área derruba o global.

**Não force `PASS`.** Se uma área não é verificável deterministicamente aqui, mantenha `INCONCLUSIVO`, escreva o limite no `STATE.md` e proponha a camada complementar — revisão humana, ferramenta externa, ou um detector novo. Aprovação por omissão é o modo de falha que a política 4.5 existe para impedir.

## 4b. Achado aceito por exceção — ADR-0010

Existe um caminho para **aceitar deliberadamente** um achado verdadeiro, e ele é estreito de propósito.

A exceção vive em `project.yaml` → `classificacao.dados_sensiveis_excecoes[]`, exige **caminho exato + categoria exata** e mais sete campos (`natureza`, `justificativa`, `decisao`, `status`, `decidido_em`, `escopo`, `onde_esta_registrado`). `status: "aceito-por-excecao"` é o **único** valor que vale.

O que ela faz e o que ela **não** faz:

| Faz | Não faz |
|---|---|
| Tira o achado da contagem de bloqueantes no fluxo privado | Não remove o achado do relatório |
| Cita justificativa, decisão e data no relatório | Não muda a severidade |
| Vale para aquele caminho e aquela categoria | Não cobre achado parecido em outro arquivo, nem outra categoria no mesmo arquivo |

**Nunca proponha allowlist por domínio, extensão, diretório ou padrão.** Foi recusada explicitamente: resolveria o ruído criando um buraco, porque achado novo cairia na allowlist antiga e desapareceria sem decisão.

**Publicação exige sanitização, não exceção.** Antes de qualquer export ou release público:

```powershell
.\scripts\security-scan.ps1 -ParaPublicacao
```

Nesse modo **toda** exceção é ignorada e os achados aceitos voltam a bloquear. Se o `project.yaml` disser `portfolio.exposicao: nenhuma`, isso continua valendo por cima de qualquer exceção.

E se você identificar um achado que merece exceção: **não crie a entrada.** Apresente o achado, o custo de cada caminho, e espere — aceitar risco é decisão dela, e o campo `decidido_em` existe para registrar quando ela decidiu, não quando você preencheu.

## 5. Achado interrompe, sempre

Política 4.6: independe de criticidade e de tamanho do projeto. **Reportar, propor a correção, esperar.** Não siga para o commit, o push ou o release.

Reporte **onde**, nunca **o quê**. Valor de credencial, número de documento e parte local de e-mail não são transcritos — nem no relatório, nem na conversa. Para inspecionar, abra o arquivo apontado.

### Segredo no histórico é um problema diferente

Apagar o arquivo e commitar **não** remove o blob: ele viaja em todo clone e já está no remoto. Limpar exige reescrever o histórico (`git filter-repo`) e `push --force`, mais rotação da credencial exposta.

Isso é **decisão da Emmily**, não sua: reescrever histórico é destrutivo e o `CLAUDE.md` proíbe fazê-lo por iniciativa própria. Apresente o achado, o custo de cada caminho, e espere. E diga o que vale independentemente da decisão: **credencial que vazou tem de ser rotacionada**, porque quem a copiou não a devolve.

## 6. Registrar

Se algo mudou de estado, atualize `docs/STATE.md` e o campo `verificacao.security_check` do `project.yaml`. Se ficou lacuna, ela vai na seção **Parcial** do `STATE.md`, com o que falta para fechar (política 4.7).

O relatório em si **não** é versionado. O que fica registrado é a conclusão e a lacuna, não o artefato.

## Anti-falsos-positivos

- **`.env.example` versionado está correto.** É a convenção que documenta quais variáveis existem. O que não pode entrar é o `.env`.
- **Segredo coberto pelo `.gitignore` não é achado** — é o sistema funcionando. Achado é segredo **rastreado**.
- **BAIXA não é ALTA pequena.** Guarda-corpo ausente, fixture declarada e identidade do próprio autor são fatos para contestar, não exposição. Não escale severidade para parecer diligente, e não trate BAIXA como resolvido só porque não travou.
- **Exceção registrada em ADR não é achado.** Vai como observação, e você pode discordar — citando o ADR.
- **Padrão de credencial dentro do scanner ou de um teste não é vazamento.** `scripts/lib/scan-*.ps1` contêm, por necessidade, os padrões que procuram. Olhe o propósito do arquivo antes de acusar.
- **CNPJ é registro público de empresa**, não dado pessoal. Aparece legitimamente em contrato e nota fiscal.
- **Não invente severidade.** Sem impacto que você consiga descrever, não é ALTA.
- **Marcador de fixture é afirmação de quem escreveu o arquivo, não verificação.** Confira que o propósito do arquivo justifica. E ele só vale **declarado no cabeçalho**: mencionado no meio do texto não desarma nada — se desarmasse, qualquer arquivo neutralizaria a varredura sobre si mesmo escrevendo uma frase.
