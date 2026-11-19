# 05 — Como criar um projeto

> O objetivo não é criar pastas: é que o projeto **já nasça sobrevivendo à perda desta conversa**,
> sem depender de uma migração futura para ficar seguro.

## 1. É mesmo um projeto?

| É | Não é |
|---|---|
| tem continuidade (vai ser retomado) | pergunta pontual: é conversa |
| tem estado (fase, pendências, decisões) | script de 20 linhas de uso único: é tarefa |
| vale a pena retomar daqui a meses | teste rápido de uma biblioteca: é tarefa |

Se não for projeto, o Claude diz isso e faz a tarefa. Nada é registrado.

## 2. Como pedir

Qualquer uma destas, em qualquer pasta:

- *"Crie um projeto novo para calcular a vazão de projeto das bacias da P1"*
- *"Quero transformar o script de capas de dossiê num projeto"*
- `/os:new-project`

## 3. O que o Claude pergunta (no máximo 4 perguntas, de uma vez)

1. **Que problema resolve, e como se sabe que foi resolvido?** Sem a segunda metade, o projeto não
   tem critério de pronto. Se a resposta for vaga, ele insiste uma vez.
2. **Categoria:** Programa, pessoal, faculdade, portfólio, laboratório.
3. **Toca dado corporativo, pessoal de terceiro ou confidencial?** Define `.gitignore`, varredura e
   o que vai para o Drive em vez do Git.
4. **Alguma saída depende de julgamento de IA?** Define se precisa de `evals/`.

O que ele **não** pergunta (propõe, e você corrige): nome da pasta, interpretador, porte, se precisa
de Git (sempre precisa).

## 4. O plano que você aprova

```
Projeto:        Hidrologia P1 - vazão de projeto
Problema:       calcular a vazão de projeto por bacia a partir das séries históricas
Pronto quando:  vazões das 4 bacias reproduzem a planilha de referência com erro < 1%
Id:             hidrologia-p1-vazao
Categoria:      UNIVERSITY
Local:          C:\AI-WORKSPACE\work\university\hidrologia-p1-vazao
Remoto:         github.com/Emmilymaciell/<repo privado>
Drive:          EMMILY PROJECT CLOUD/03 UNIVERSITY/hidrologia-p1-vazao
Classificação:  ferramenta · criticidade low · dados sensíveis não · componente LLM não
Verificação:    tests (cálculo determinístico); evals não se aplica
```

**Nada é criado antes do seu "sim".**

Classificação sem inflar: um script de uso próprio classificado como criticidade alta só produz
cerimônia. A criticidade decide o rigor da revisão:

| Criticidade | Revisão no checkpoint |
|---|---|
| `low` | auto-revisão |
| `medium` | revisor de QA independente |
| `high` ou dados sensíveis | QA + Security independentes |

## 5. O nascimento protegido

A especificação está em [`docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md`](../vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md)
(seção 5) e a decisão de propriedade no
[ADR-0018](../decisions/ADR-0018-ownership-e-provenance.md).

Depois do seu sim, o Claude roda o motor. Primeiro um ensaio sem efeito (não cria pasta, não grava
nada, não chama GitHub nem Drive):

```powershell
cd C:\AI-WORKSPACE\_platform\emmily-ai-project-os
py -3.13 -m eos new hidrologia-p1-vazao --name "Hidrologia P1 - vazão de projeto" --category UNIVERSITY --runtime python --dry-run
```

O ensaio imprime o plano: pasta (`${AI_WORKSPACE}\university\hidrologia-p1-vazao` →
`C:\AI-WORKSPACE\university\hidrologia-p1-vazao`), contrato, remoto
(`https://github.com/Emmilymaciell/university-exemplo-projeto`, privado), pasta no Drive
(`03 UNIVERSITY/hidrologia-p1-vazao`), se o commit inicial sairá assinado, os 8 passos e a lista
de arquivos.

Depois, de verdade (o mesmo comando, sem `--dry-run`). O motor executa em ordem, confere cada passo
e, se algum falhar, **para, relata o que já fez e mostra o comando para retomar, sem apagar nada**:

| # | Passo | Verificado como |
|---|---|---|
| 1 | valida o id (minúsculas, dígitos e hífen), a categoria e o runtime; recusa se o id, a pasta ou o remoto já são de outro projeto no registry, se a pasta existe com conteúdo, ou se o destino cai dentro de pasta sincronizada: OneDrive (pessoal ou `OneDrive - <empresa>`), Google Drive (`Meu Drive`, `My Drive`, `Shared drives`, `Drives compartilhados`), Dropbox ou biblioteca SharePoint sincronizada (`<Site> - Documentos`). Olha só as pastas **acima** do projeto, então um id como `onedrive-limpeza` não é confundido com nuvem | recusa fechada, nada criado |
| 2 | cria a pasta do projeto, **fora** do Drive e do OneDrive (tabela abaixo) | pasta existe |
| 3 | copia o template e os arquivos de nascimento, sem sobrescrever nada | todos os arquivos existem e nenhum `{{...}}` sobrou |
| 4 | `git init` na branch `main` e commit inicial; recusa arquivo com nome de segredo. Se o commit falhar (hook, assinatura indisponível), a retomada refaz o commit com o que ficou preparado | commit existe, árvore limpa; se a assinatura estiver ligada no Git, o commit **tem** de estar assinado |
| 5 | escreve `registry/projects/<id>.yaml` completo, meta `L6`, seção `ownership` | validado pelo schema; **a plataforma não é commitada** (o relatório lembra disso) |
| 6 | **primeiro a varredura de segurança** (`scripts/security-scan.ps1`) no projeto; só depois cria o remoto **privado** e faz o push da `main` | achado ALTA/MEDIA, ou varredura que não terminou, **para** sem criar nem enviar nada (relatório em `%TEMP%\emmily-os-scan\`); visibilidade conferida = `PRIVATE` **antes** do push; `ls-remote` confirma |
| 7 | cria a pasta do projeto no Drive | existe no Drive |
| 8 | primeiro backup e verificação de nível | relatório com o nível atingido (nunca L0) |

Onde cada categoria nasce:

| Categoria | Pasta local | Repositório no GitHub | Pasta no Drive |
|---|---|---|---|
| Programa | `C:\AI-WORKSPACE\work\prog\<id>` | `prog-<id>` | `01 PROG/<id>` |
| PERSONAL | `C:\AI-WORKSPACE\personal\<id>` | `personal-<id>` | `02 PERSONAL/<id>` |
| UNIVERSITY | `C:\AI-WORKSPACE\university\<id>` | `university-<id>` | `03 UNIVERSITY/<id>` |
| PORTFOLIO | `C:\AI-WORKSPACE\portfolio\<id>` | `portfolio-<id>` | `04 PORTFOLIO/<id>` |
| LAB | `C:\AI-WORKSPACE\ai-lab\<id>` | `lab-<id>` | `05 LAB/<id>` |
| PLATFORM | `C:\AI-WORKSPACE\_platform\<id>` | `<id>` (sem prefixo) | `00 PLATFORM/<id>` |

O repositório é sempre `Emmilymaciell/<nome>`, e o prefixo só entra se o id ainda não começar por
ele (`prog-relatorio-g2` continua `prog-relatorio-g2`). No contrato a pasta fica gravada com
`${AI_WORKSPACE}`, para valer em qualquer máquina.

Opções:

| Opção | Quando |
|---|---|
| `--runtime python\|node\|none` | linguagem do projeto (define manifesto, bootstrap e trilha de teste); padrão `python` |
| `--sem-remoto` | quando não pode haver GitHub (ex.: remoto bloqueado por licença externa). Fica registrado no contrato, e o projeto não passa de L1 |
| `--sem-rede` | sem nenhuma chamada ao GitHub (`gh`) nem push; **implica `--sem-remoto`** |
| `--certificar` | roda a certificação por restauração no fim: é o que leva a L6 já no nascimento |
| `--descricao "<frase>"` | a descrição do projeto no contrato (sem ela: "A definir no discovery") |
| `--dry-run` | ver o plano sem efeito nenhum |

O commit inicial sai **assinado** quando a assinatura está ligada no Git da máquina (está, nesta
máquina); sem ela, sai sem assinatura e o contrato declara `signing: recommended` em vez de
`required`.

### O que nasce dentro do projeto

| Arquivo | Para quê |
|---|---|
| `README.md` | como rodar, para quem chega |
| `docs/STATE.md` | onde o projeto está; próximo passo |
| `docs/HANDOFF.md` | como outra pessoa ou máquina assume |
| `docs/decisions/` | ADRs do projeto, começando por `ADR-0001-nascimento-protegido.md` |
| `CLAUDE.md`, `AGENTS.md` | adaptadores para Claude e para qualquer outra IA |
| `project.yaml` | classificação e verificação exigida |
| `PROVENANCE.md`, `OWNERSHIP.md`, `AUTHORS.md`, `NOTICE`, `.github/CODEOWNERS` | propriedade e proveniência (ver [10](10-PROPRIEDADE-E-PROVENIENCIA.md)) |
| `.env.example` | **nomes** das variáveis de ambiente, sem valores |
| `.gitignore`, `.gitattributes` | o que nunca entra no Git; fim de linha consistente |
| `bootstrap.ps1` | prepara o ambiente (cria `.venv`, instala dependências) |
| `tests/run-tests.ps1` + suíte de fumaça | o mesmo comando de teste em todo projeto |
| `examples/fixtures/`, `examples/synthetic/` | o **único** lugar onde CSV de exemplo pode ser versionado |
| `CHANGELOG.md`, `logs/`, `output/`, `scripts/`, `docs/runbooks/` | histórico de versões e pastas de trabalho |

O template é o máximo possível, não o mínimo obrigatório: o que o projeto não usa é removido depois.
As skills de sessão (`/session-start`, `/session-close`) **não** são copiadas: o projeto nasce com
`.claude/skills/` vazio (ver [01](01-GUIA-RAPIDO.md)). Depois do nascimento, corrija no
`project.yaml` o que o discovery decidiu diferente do padrão conservador (criticidade baixa, porte
script).

## 6. Se algo travar no nascimento

| Mensagem | O que é | O que fazer |
|---|---|---|
| `PENDENCIA HUMANA sem remoto (H2): ...` | o ambiente negou o `gh repo create`, o `gh` está sem login ou o push foi recusado | o resto do nascimento **continua** (Drive e backup) e o projeto fica em L1; resolva a pendência e rode **o mesmo comando** de novo: ele faz só o que falta |
| `PAROU no primeiro passo que falhou` | um passo não pôde ser conferido | ler o motivo; corrigir; rodar o comando de retomada que ele imprime (mesmos parâmetros) |
| `varredura de seguranca acusou achado ALTA/MEDIA` | a varredura achou possível segredo ou dado sensível antes da publicação | nada foi criado no GitHub nem enviado; ler o relatório indicado (`%TEMP%\emmily-os-scan\novo-<id>-<carimbo>.md`), resolver e rodar o mesmo comando |
| `RECUSADO: ...` | id inválido ou já usado, pasta com conteúdo, destino no Drive/OneDrive, parâmetros diferentes de um nascimento pela metade | nada foi criado nem sobrescrito; escolher outro id ou repetir os parâmetros originais |
| `gh` ou `rclone` sem login (H1) | credencial expirada | `gh auth login` ou `rclone config reconnect gdrive:` no navegador |
| assinatura ligada mas commit sem assinatura | chave de assinatura ausente ou inválida | ver [10](10-PROPRIEDADE-E-PROVENIENCIA.md) |
| remoto público ou `origin` apontando para outro lugar | falha fechada, não é pendência | nada foi enviado; conferir à mão antes de qualquer coisa |

O diário que permite retomar fica em `%LOCALAPPDATA%\emmily-os\novo\<id>.json`, fora do projeto e
do Git.

Foi exatamente o H2 que deixou 7 projetos extraídos do acervo Dynatest em L1 em 2026-10-11: o
`gh repo create` foi negado pela permissão do ambiente, e **nada foi contornado**. Depois da
permissão, os 7 receberam remoto privado.

## 7. Depois de nascer: até L6

```powershell
py -3.13 -m eos check hidrologia-p1-vazao      # nível atual e o que falta
```

1. Trabalhe normalmente ([06](06-COMO-TRABALHAR-EM-UM-PROJETO.md)), com checkpoints a seu pedido.
2. `eos backup <id>` ao fim do dia.
3. Quando o projeto tiver comando de teste (`environment.smoke_command`, que o `eos new` já
   declara), certifique: `py -3.13 -m eos certify <id>` → **L6**.

## 8. E um projeto que já existe numa pasta?

Peça *"estrutura este projeto no lugar"*. O Claude **não sobrescreve nada**: mostra exatamente o que
seria criado e o que seria preservado, e espera seu sim. Projeto existente com dados ou histórico
passa primeiro por **proteger → copiar → verificar → registrar**, e só depois por qualquer mudança
(é a ordem DISCOVER → PROTECT → COPY → VERIFY → REGISTER → SWITCH → CERTIFY → CLEANUP).

## 9. O que muda em relação ao fluxo antigo

O `/os:new-project` original criava a estrutura e parava no `git init`, **sem commit e sem remoto**,
deixando o primeiro commit para você. Agora a skill faz o discovery e o plano, roda o
`eos new ... --dry-run`, espera o seu sim e então roda o mesmo comando de verdade: ela não cria
mais nada à mão. O seu "sim" ao plano autoriza o commit inicial (assinado automaticamente, porque a
assinatura está ligada nesta máquina), o remoto privado e o push que o `eos new` faz; os commits
seguintes voltam a ser só a seu pedido, via `/os:checkpoint`. O contrato gravado na plataforma
fica sem commit até você pedir. O nascimento protegido completa o caminho até remoto privado,
pasta no Drive e primeiro backup, porque um projeto sem commit e sem cópia fora da máquina nasce em
L0.
