---
name: handoff
description: Gera o documento para outra pessoa, maquina ou conta assumir o projeto sem acesso a nenhuma conversa. Use para "gera um handoff", "vou passar isso pra alguem", "quero seguir noutro computador", ou /os:handoff.
---

# /os:handoff

Produzir `docs/handoff/HANDOFF-<data>.md`: o documento com que outra pessoa, outra máquina, outra conta ou outro Claude assume o projeto.

O critério de qualidade é único e severo: **quem receber isto não tem acesso a nenhuma conversa, nem a esta máquina, nem à Emmily para perguntar.** Tudo que só existe na cabeça de alguém tem que estar escrito aqui.

## 1. Levantar

```bash
git log --format='%h %ad %s' --date=short | head -30
git tag --sort=-creatordate
git branch -a
git remote -v
git status --porcelain
```

Leia `docs/STATE.md`, `docs/decisions/`, `CLAUDE.md`, `project.yaml`, `README.md`, `.env.example`, e o conteúdo de `scripts/` e `tests/`.

## 2. Testar o próprio contrato de portabilidade

Este é o passo que separa um handoff real de um resumo bonito. **Verifique, não presuma:**

| Verificar | Como |
|---|---|
| As dependências estão declaradas? | Comparar o que os scripts importam com o que está documentado |
| Existe `.env.example` cobrindo todas as variáveis usadas? | Procurar `os.environ` / `$env:` no código e conferir contra o exemplo |
| Existe caminho absoluto codificado? | `grep -rniE 'C:\\\\Users' --include='*.py' --include='*.ps1' .` |
| O `bootstrap`/`doctor` roda? | Rodar em modo `-Check` e reportar a saída real |
| Os testes passam? | Rodar. Reportar o resultado real, inclusive se falharem |
| Há algo que só funciona nesta máquina? | Pasta do OneDrive corporativo, Excel via COM, tarefa agendada, credencial local |

Cada item que falhar entra na seção **"O que falta para ser portátil"** do documento. Não maquie: um handoff que esconde um bloqueio é pior que nenhum.

## 3. Verificar segurança antes de gerar

O handoff frequentemente sai da máquina. Antes de escrever:

```bash
git ls-files | grep -iE '\.env$|\.key$|\.pem$|credential|secret|token'
```

E ao escrever o documento: **nunca** transcreva valor de credencial, token, senha, string de conexão ou dado pessoal de terceiro. Descreva *qual* variável é necessária e *onde* se obtém o valor, nunca o valor.

Se o projeto tiver `dados_sensiveis: true`, marque a sensibilidade no cabeçalho do handoff e diga explicitamente por quais canais ele pode circular.

## 4. Estrutura do documento

```markdown
# HANDOFF — <Título do projeto>

- Data: <AAAA-MM-DD>
- Versão / último commit: <tag ou hash>
- Autor do handoff: <nome>
- Sensibilidade: <baixa | média | alta> — <por quê, e por onde pode circular>

## 1. O que é e por que existe
O problema, em linguagem de negócio. Quem usa. O que acontece se o projeto parar.

## 2. Como se sabe que está funcionando
O critério de pronto. As verificações que existem e o que cada uma cobre.

## 3. Como rodar
Pré-requisitos com versão exata. Passo a passo do zero até a primeira execução
bem-sucedida. Comandos literais, não descrições de comandos.

## 4. Arquitetura
Como está organizado e **por que** — não só o quê. Onde ficam os dados, o que é
gerado, o que é fonte.

## 5. Decisões que restringem mudanças futuras
Uma linha por ADR, com o número. Especialmente as decisões de "não fazer X":
são as que alguém desfaz por engano.

## 6. Estado atual
Concluído · parcial · pendências · riscos abertos. Copiado do STATE.md e conferido
contra o repositório.

## 7. O que falta para ser portátil
Tudo que só funciona nesta máquina ou com este acesso. Se estiver vazio, diga
que foi verificado e não que não há nada.

## 8. Armadilhas
O que parece errado e está certo (exceções deliberadas). O que já foi tentado e
não funcionou. O que quebra silenciosamente.

## 9. Próximos passos
Ordenados por o que desbloqueia mais coisa.

## 10. Quem procurar
Só se aplicável. Nunca inclua dado pessoal de terceiro sem necessidade.
```

## 5. O handoff não pode citar o commit que o contém

O documento nasce antes do commit que o versiona, então o `HEAD` que ele cita fica desatualizado no instante seguinte. O teste de aceitação da Fase 1 pegou isso: o cabeçalho dizia `8d0e271`, e o `HEAD` já era `8e34505` — o próprio commit do handoff. Contagens de arquivo têm o mesmo problema.

Resolva escrevendo o que é verdade, não um número que vai envelhecer:

- **Versão / último commit:** `<hash> (HEAD no momento da geração; o commit que adiciona este handoff vem depois)`
- Em contagem de arquivos, diga "<n> arquivos versionados, fora este documento".

## 6. Entregar

Salve em `docs/handoff/HANDOFF-<AAAA-MM-DD>.md`, informe o caminho completo, e diga:

- o que foi verificado de fato (com resultado real);
- o que ficou como pendência de portabilidade;
- a sensibilidade e por onde o documento pode circular.

Se a Emmily quiser o pacote portátil completo — sem segredos, sem caches, sem dados proibidos — isso é `/os:export-project`, que é da Fase 5 e ainda não existe. Diga isso em vez de improvisar um zip.

## Anti-falsos-positivos

- **Não gere um resumo do README.** Handoff é o que *não* está no README: as armadilhas, as decisões de não-fazer, o que só funciona nesta máquina.
- **Não afirme que os testes passam sem rodar.** Rode. Se falharem, o handoff registra que falham.
- **Não invente métrica nem resultado.** Se não foi medido, escreva "não medido".
- **Não copie credencial nem caminho de rede corporativa** para dentro do documento.
- **Não trate exceção documentada como problema.** Se um ADR explica por que algo está "errado", isso vai na seção 8 como armadilha — não como pendência.
- **Não faça commit.** Gerar o handoff não é salvar versão. Se ela quiser versioná-lo, é `/os:checkpoint`.
