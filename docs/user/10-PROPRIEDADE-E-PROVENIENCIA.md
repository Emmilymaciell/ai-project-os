# 10 — Propriedade e proveniência

> Este documento descreve **registro e evidência** de autoria e titularidade. Não é parecer
> jurídico: o que vale entre você e um empregador ou cliente é o contrato entre as partes. O que o
> Project OS faz é garantir que os fatos (quem criou, quando, com que ferramentas, o que é de
> terceiros) estejam escritos, conferidos e assinados.
>
> A decisão está no [ADR-0018](../decisions/ADR-0018-ownership-e-provenance.md) e a especificação
> completa em [`docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md`](../vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md).

## 1. Por que isso importa no seu caso

| Situação real | O risco sem registro |
|---|---|
| projetos Programa feitos no ambiente pessoal autorizado, com GitHub pessoal privado | não saber depois o que foi criado por você, em que contexto contratual |
| automações extraídas do acervo Dynatest, com versões antecessoras | perder a cadeia de custódia (de onde veio cada versão) |
| portfólio Empresa X | publicar algo cuja autoria ou cujos componentes de terceiro não estão claros |
| uso de IA e, às vezes, de contas de ferramenta que não são suas | confundir "ferramenta usada" com "autor" |
| bibliotecas de terceiros (openpyxl, pandas...) | parecer reivindicar o que é de outros |

## 2. A seção `ownership` do contrato

Opcional no formato do contrato, **obrigatória por política** para todo `PROJECT`: o `eos validate`
aceita contrato sem ela, mas o `ownership-check` dá FAIL e o `eos new` sempre a cria. Desde
2026-10-12 os 21 `PROJECT` do registry têm a seção. Exemplo (o de `conversor-utm`, com os campos
opcionais que ele não usa acrescentados como comentário):

```yaml
ownership:
  declared_owner: Emmily Maciel        # a titular declarada (obrigatório)
  owner_github: Emmilymaciell          # dono esperado do remoto e do CODEOWNERS
  creators:                            # quem criou (obrigatório)
    - Emmily Maciel
  contributors: []                     # contribuição real de terceiro: só o NOME, nunca se apaga
  tool_accounts:                       # contas/ferramentas usadas SEM autoria
    - 'assistentes de IA (Claude Code, Codex) usados como ferramenta, sem autoria'
  # employer_or_client: PROG           # contexto contratual (não é autoria)
  license: proprietary                 # SPDX (ex.: MIT) ou 'proprietary'
  third_party: []                      # componentes de terceiro: name, license, path (opcional)
  provenance_file: PROVENANCE.md
  signing: required                    # required | recommended | none
  identities:                          # identidades Git que SÃO suas
    - Emmily Maciel
    - Emmily Melo
  evidence:
    - 'identidades Git do repo levantadas em 2026-10-12 (git log --all): so identidades da titular'
```

Duas regras de formato: listas **em bloco** (um item por linha com `- `), porque o leitor de YAML
do motor recusa lista entre colchetes com conteúdo (`['a']`; o `[]` vazio é aceito); e caminho
Windows entre aspas simples.

As distinções que a seção existe para manter:

| Campo | É | Não é |
|---|---|---|
| `creators` | quem criou o projeto | quem pagou por ele |
| `contributors` | pessoa que de fato contribuiu (só o nome: e-mail de terceiro é dado pessoal e dá WARN) | revisor que só olhou |
| `tool_accounts` | conta ou ferramenta usada sem autoria (ex.: a conta de Claude de uma colega usada numa sessão) | autora |
| `employer_or_client` | o contexto contratual (Programa, Dynatest, Empresa X) | autoria |
| `identities` | os nomes (ou `Nome <e-mail>`) com que **você** commitou (pessoal, corporativo) | identidades de terceiros |

A conferência com o histórico do Git é por e-mail **ou** por nome, sem diferenciar maiúscula, então
declarar só o nome basta — e é o que os contratos existentes fazem, para não pôr e-mail num arquivo
versionado. O `eos new` faz o mesmo: grava em `identities` só o nome configurado no Git
(`user.name`), sem e-mail.

O registry também aceita o tipo `REFERENCE_DATA` (dado de referência: normas, bases públicas),
classificado como `COLLECTION` e `ARCHIVE`, sem nível L0–L6. Nenhum item usa esse tipo ainda.

## 3. Os arquivos de proveniência no projeto

| Arquivo | Conteúdo |
|---|---|
| `PROVENANCE.md` | origem, data de criação, criadora, contexto (empresa/cliente), ferramentas usadas (inclusive IA e contas), componentes de terceiro, cadeia de custódia: onde o original vive, hashes |
| `OWNERSHIP.md` | titular declarada, base da declaração, o que **não** é reivindicado (dependências, terceiros), contato |
| `AUTHORS.md` | criadora(s) e contribuidores reais |
| `NOTICE` | atribuições de terceiros (licenças das bibliotecas); existe mesmo vazio |
| `.github/CODEOWNERS` | `* @Emmilymaciell`: quem responde pelo código no GitHub |

O nascimento protegido ([05](05-COMO-CRIAR-UM-PROJETO.md)) cria todos. Para projeto antigo, peça
*"crie os arquivos de proveniência deste projeto"*; por baixo roda
`py -3.13 -m eos ownership-init <id>`, que os gera a partir da seção `ownership` do contrato e
**nunca sobrescreve** arquivo existente. Ele usa a mesma pasta que `check` e `backup` (se o
`machine.yaml` desta máquina tem um caminho próprio para o projeto, vale esse) e **recusa**, sem
criar nada, se a pasta não existir ou não for a raiz de um repositório Git. Os arquivos ficam no
disco até você pedir o commit. A própria plataforma recebeu os seus em 2026-10-12.

## 4. "Qual é a propriedade/proveniência deste projeto?"

Por baixo:

```powershell
py -3.13 -m eos ownership-check <id>          # legível
py -3.13 -m eos ownership-check <id> --json   # estruturado
```

Só lê, não altera nada. Cada item sai PASS, WARN, FAIL ou N/A, com o motivo. Exemplo real
(2026-10-12):

```
Ownership: conversor-utm   (verificado em 20261012T112414Z)   PASS
    declared_owner   PASS  titular declarada: Emmily Maciel
    ownership_files  PASS  PROVENANCE.md, OWNERSHIP.md e AUTHORS presentes
    notice           N/A   sem componente de terceiro declarado
    license          PASS  proprietary
    git_identities   PASS  1 identidade(s) do historico explicada(s) pela declaracao
    signing          PASS  configurada (gpg.format=ssh); 1 commit(s) assinados desde o primeiro assinado
    remote_owner     PASS  remoto de Emmilymaciell
    codeowners       PASS  .github/CODEOWNERS cita @Emmilymaciell
    manifest         N/A   nunca certificado
    contradictions   PASS  nenhuma atribuicao de autoria contraditoria em README/LICENSE/NOTICE/cabecalhos
```

| Item | Confere | Resultado ruim |
|---|---|---|
| `declared_owner` | a seção existe, com titular e criadoras | FAIL se faltar algum ou se `PROJECT` sem seção (aí os outros itens saem N/A); WARN se `contributors` tiver e-mail |
| `ownership_files` | `PROVENANCE.md`, `OWNERSHIP.md` e `AUTHORS.md` (ou `AUTHORS`) existem | WARN |
| `notice` | se há terceiros declarados, existe `NOTICE` | WARN; N/A sem terceiros |
| `license` | licença preenchida; se não for `proprietary`, existe `LICENSE` | WARN |
| `git_identities` | **todo** autor e committer do `git log` (todas as branches) está explicado por `identities`, `creators`, `contributors` ou `tool_accounts`. O histórico é lido **sem** o `.mailmap`: esse arquivo é do próprio repositório e poderia reescrever um terceiro com o seu nome | FAIL: autor não explicado é contradição |
| `signing` | assinatura configurada no repositório e % de commits **assinados e verificados** (`%G?` = `G`) desde o primeiro assinado | FAIL se `required` sem configuração (WARN se `recommended`). Com configuração: **FAIL** se **qualquer** commit do histórico tiver assinatura inválida ou revogada (`B`/`R`); WARN se o último commit não estiver assinado (`N`), se algum commit estiver assinado mas sem prova de quem assinou (`U`, `E`, `X`, `Y` — em geral a chave não está no `gpg.ssh.allowedSignersFile`) ou se nem todos forem `G` |
| `remote_owner` | o dono do remoto (`github.com/<dono>/...`) é o `owner_github` | FAIL se diferente; N/A sem remoto |
| `codeowners` | `CODEOWNERS` cita `@owner_github` | WARN; N/A sem remoto |
| `manifest` | os arquivos de ownership não mudaram desde a última certificação | WARN se mudaram; N/A nunca certificado |
| `contradictions` | texto em README, LICENSE, NOTICE ou no cabeçalho do código (`Author:`, `Autor:`, `Copyright 2024`, `©`) atribuindo autoria a nome fora da declaração | WARN com arquivo:linha |

Código de saída: `0` sem FAIL (WARN não reprova); `1` com FAIL; `2` erro (id desconhecido, id
faltando).

O Claude responde em linguagem simples: quem é a titular declarada, quem criou, em que contexto,
o que é de terceiros, se a assinatura está em dia e se há alguma contradição a resolver.

Integrações:

- `eos status` tem a coluna `own` (PASS/WARN/FAIL; `-` quando não se aplica) por projeto;
- `eos check <id>` mostra a dimensão `ownership` como **informativa**: ela não altera o nível L0–L6
  nem as respostas SIM/NÃO;
- o `doctor.ps1`, rodado na plataforma, avisa (WARN na dimensão `git`) se a assinatura do próprio
  repositório não estiver configurada ou se o último commit não estiver assinado **e verificado**:
  só `G` passa; `U` (chave fora do `allowedSignersFile`) também é WARN, com a ação "inclua a chave
  pública no arquivo de `gpg.ssh.allowedSignersFile`";
- o `/session-close` roda o `ownership-check` em projeto com seção `ownership` e só relata: um FAIL
  vira inconsistência no relatório, não correção no encerramento.

## 5. Certificar a propriedade

```powershell
py -3.13 -m eos ownership-certify <id>
py -3.13 -m eos ownership-certify <id> --tag
```

- Roda o check e **recusa** se houver FAIL, sem gravar nada.
- Grava a evidência em JSON: projeto, data, HEAD, a seção `ownership`, hash SHA-256 de cada arquivo
  de ownership, autores do histórico, situação da assinatura, remoto, resultado de cada item. Os
  autores saem com o **nome** e o SHA-256 do e-mail, nunca o e-mail em claro; da chave de
  assinatura, só o **nome do arquivo** (o caminho completo traria o seu usuário do Windows). Vai
  para a nuvem em `99 RECOVERY/manifests/<id>/ownership-<carimbo>.json` (ao lado dos certificados
  de restauração) e para o journal da máquina em `%LOCALAPPDATA%\emmily-os\ownership\<id>\`;
  **não** suja o working tree do projeto.
- `--tag` cria uma tag **assinada** `ownership-AAAAMMDD` no último commit. Recusa se a assinatura
  não estiver configurada ou se a tag do dia já existir (nunca sobrescreve). A tag é nova no
  projeto: rode `eos backup <id>` e publique a tag, senão o nível acusa ref não publicada. Se a
  gravação do certificado na nuvem falhar, a tag criada nessa mesma execução é removida (tag sem
  certificado seria prova órfã).

## 6. Assinatura de commits

Nesta máquina a assinatura por chave SSH está ativa para todos os repositórios:

| Configuração global | Valor |
|---|---|
| `gpg.format` | `ssh` |
| `user.signingkey` | `~/.ssh/id_ed25519_git_signing.pub` |
| `commit.gpgsign` | `true` |
| `tag.gpgsign` | `true` |

Todo commit e toda tag saem assinados. O que a assinatura prova: que o commit foi feito com a sua
chave, nesta máquina. O que não prova: a qualidade do conteúdo.

### Para aparecer "Verified" no GitHub

O GitHub só mostra **Verified** se a chave **pública** estiver registrada na sua conta como chave
de *assinatura* (não basta ser chave de acesso). Isso exige uma permissão extra do `gh`, concedida
no navegador: **gate H1**.

```powershell
gh auth refresh -h github.com -s admin:ssh_signing_key
gh ssh-key add "$env:USERPROFILE\.ssh\id_ed25519_git_signing.pub" --type signing --title "<nome-da-maquina>"
```

Enquanto isso não for feito, os commits continuam assinados localmente, mas o GitHub mostra
**Unverified**. Em 2026-10-12 esse registro **ainda está pendente** (H1).

### Em máquina nova

Gera-se uma chave **nova** e registra-se a pública nova (ver [09](09-TROCA-DE-COMPUTADOR.md)). A
chave privada antiga **não** é copiada. As assinaturas antigas continuam verificáveis enquanto a
chave pública antiga continuar registrada no GitHub: não a remova ao trocar de máquina.

### Conferir

```powershell
git log --show-signature -1        # assinatura do último commit
git log --format='%h %G? %an %s' -10   # G = assinatura boa; N = sem assinatura
```

Só `G` conta como assinado e verificado. `U` quer dizer "assinatura boa de uma chave que este
computador não conhece": falta a linha da sua chave pública no `gpg.ssh.allowedSignersFile`. `B`
(inválida) ou `R` (revogada) em qualquer commit reprova o `ownership-check`.

## 7. Identidades Git

A identidade global desta máquina é **pessoal** (ADR-0003), para que a autoria sobreviva a uma
mudança de emprego. Repositórios antigos mantêm a identidade local que já tinham, inclusive a de
projeto do Repositório Jurídico (cujo e-mail Programa você confirmou, em 2026-10-11, ser seu ou da sua
equipe). É por isso que `identities` aceita mais de uma linha: todas as identidades que são suas
entram lá, e qualquer outra precisa estar em `contributors` ou `tool_accounts`.
