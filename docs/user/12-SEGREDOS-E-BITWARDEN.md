# 12 — Segredos e Bitwarden

> Por que o arquivo se chama *SEGREDOS* e não *SECRETS*: o `.gitignore` da plataforma ignora todo
> caminho com `secret` no nome, e o motor trata um arquivo assim como arquivo de segredo (ele
> derrubaria a dimensão `secrets` da própria plataforma). Abrir exceção num guarda de segurança para
> acomodar um nome seria a direção errada; é o mesmo motivo de o manifesto da plataforma se chamar
> `cofre.manifest`.

## 1. O que conta como segredo

Senha, token, chave de API, *client secret*, cookie de sessão, código de 2FA, código de recuperação,
chave privada (SSH, `.pem`, `.pfx`), configuração com credencial (`rclone.conf`, `.npmrc`,
`.pypirc`), perfil de navegador.

## 2. As regras

1. **Valor de segredo nunca entra no Git**, nem no histórico, nem num commit "temporário".
2. **Valor de segredo nunca vai para o backup** do Drive (que não é criptografado no cliente).
3. **O Git guarda só os nomes**: num manifesto de segredos e no `.env.example`.
4. **O Claude nunca lê, mostra ou repete um valor** em chat, log, relatório ou journal.
5. **Você nunca digita senha no chat nem no terminal** quando há login por navegador ou prompt
   seguro. Senha mestra do cofre nunca é gravada em lugar nenhum.
6. **Segredo real encontrado no Git = incidente (gate H5).**

## 3. Onde vivem os nomes e onde vivem os valores

| Arquivo (versionado) | Contém |
|---|---|
| `secrets.manifest` (por projeto) | os **nomes** dos segredos que o projeto usa e onde o valor vive |
| `.env.example` (por projeto) | as variáveis de ambiente esperadas, com valores vazios ou fictícios |
| `cofre.manifest` (na plataforma) | os segredos de que a **plataforma** depende |

O `cofre.manifest` da plataforma hoje lista quatro nomes, com onde vivem e como recriar:

| Nome | Onde vive nesta máquina | Como recriar numa máquina nova |
|---|---|---|
| `GITHUB_AUTH` | keyring do Windows, gerido pelo `gh` | `gh auth login` (navegador) |
| `RCLONE_GDRIVE_TOKEN` | `rclone.conf` do usuário, gerido pelo rclone | `rclone config reconnect gdrive:` (navegador) |
| `RCLONE_GDRIVE_OAUTH_CLIENT` | item `rclone-gdrive-oauth-client` do Bitwarden | `bw get item ...` e `rclone config create gdrive drive client_id=.. client_secret=.. scope=drive` (ADR-0013, emenda de 2026-10-16) |
| `CLAUDE_CODE_OAUTH` | sessão do Claude Code | `/login` no Claude Code |

Três deles (`GITHUB_AUTH`, `RCLONE_GDRIVE_TOKEN`, `CLAUDE_CODE_OAUTH`) são recriados por login
(gate H1), não copiados. O quarto, `RCLONE_GDRIVE_OAUTH_CLIENT`, **não** se recria por login,
porque é a identidade do seu app no Google:

| Item no Bitwarden | Conteúdo | Usado para |
|---|---|---|
| `rclone-gdrive-oauth-client` | Username = Client ID, Password = Client secret do app OAuth `Emmily OS rclone` (projeto Google Cloud `emmily-os-rclone`) | criar o remoto `gdrive` numa máquina nova ([09](09-TROCA-DE-COMPUTADOR.md), B2) |

Os valores existem só ali e no `rclone.conf` local. Se o item se perder, cria-se um client novo no
Google Cloud Console (*Clients* → *Create client*, tipo *Desktop app*), guarda-se no mesmo item e
reconecta-se o rclone. O `cofre.manifest` da plataforma lista esse item pelo nome
`RCLONE_GDRIVE_OAUTH_CLIENT` (nunca o valor).

## 4. Onde ficam os valores: o campo `secrets.store` do contrato

| `store` | Significa | Efeito no "posso apagar a pasta / trocar de PC?" |
|---|---|---|
| `bitwarden` | os valores estão no cofre Bitwarden | não bloqueia **se** cada `.env` local bate (sha256) com o último `eos secrets-push`; `.env` alterado depois do push volta a bloquear |
| `local-env` | os valores estão num `.env` local, ignorado pelo Git | **bloqueia** enquanto existir `.env` ou `.env.local` na pasta: *"segredos com valor só nesta pasta: leve para o cofre antes"* |
| `none` | o projeto não usa segredo | não bloqueia |

Exemplos reais: o Portability Lab usa `bitwarden`; Relatório G2, Grupo 1, Cérebro Documental,
Organização SharePoint e a própria plataforma estão em `local-env`; a maioria dos demais está em
`none`.

## 5. Bitwarden: o papel e a situação atual

**Papel (arquitetura vNext):** o Bitwarden é a **fonte de verdade de segredos**: senhas, tokens,
chaves de API, códigos de recuperação e credenciais.

**Situação em 2026-10-12:**

- o **Bitwarden CLI está instalado** (`bw` 2026.9.1, via winget, em 2026-10-12) mas **sem login**:
  `bw login` e `bw unlock` são o gate **H1** seu;
- por isso os projetos `local-env` ainda guardam valores num `.env` local, e, **enquanto existir
  `.env` ou `.env.local` na pasta**, respondem NÃO a *"posso apagar a pasta?"* e *"posso trocar de
  computador?"* mesmo em L6 (a plataforma é `local-env` mas não tem `.env`, e por isso responde SIM);
- a **criptografia dos backups no cliente** também depende do Bitwarden (a senha do cofre de backup
  não pode morar no repositório nem em texto puro na máquina).

O motor integra o cofre desde 2026-10-12 (`eos/cofre.py`). Procedimento por projeto, depois do H1:

1. desbloquear: `bw login` (uma vez) e `bw unlock` — guarde a sessão na variável `BW_SESSION`
   **da sua janela de terminal**;
2. `py -3.13 -m eos secrets-push <id>`: grava cada `.env`/`.env.local` como **nota segura** no
   Bitwarden, com o nome `emmily-os/<id>/.env`, relê e confere o sha256. Na nuvem fica só um
   manifesto com os NOMES das variáveis e o sha256 (`99 RECOVERY/manifests/<id>/cofre-<ts>.json`);
3. trocar `secrets.store` de `local-env` para `bitwarden` no contrato (commit da plataforma);
4. `py -3.13 -m eos secrets-status <id>` e `eos check <id>`: o bloqueio *"segredos com valor só nesta
   pasta"* some enquanto o `.env` local bater com o último push.

Na máquina nova: `py -3.13 -m eos secrets-pull <id>` escreve o `.env` de volta na raiz do projeto
(confere o sha256; **não** sobrescreve um `.env` diferente sem `--sobrescrever`). Nenhum dos três
comandos imprime valor; os valores trafegam só pelo stdin do `bw`.

Projetos com `.env` real hoje: Cérebro Documental, Organização SharePoint e Relatório G2.

## 6. Como o motor impede segredo de vazar para o backup

A regra olha o **nome** do arquivo, em duas famílias:

| Família | Casa | Exceção |
|---|---|---|
| dura | `.env*`, `.envrc`, chaves SSH, `*.pem`, `*.key`, `*.pfx`, `*.ppk`, `*.jks`, `rclone.conf`, `.npmrc`, `.pypirc`, perfis de navegador | nenhuma |
| da palavra | `secret`, `token`, `credential`, `senha`, `password`, `api_key`, `cookie` como **palavra** (`Secretaria/` e `tokenizer.py` não casam), em qualquer extensão | só por caminho exato em `secrets.allowed_paths`, depois de conferência humana do conteúdo |

O que acontece:

- arquivo **ignorado** pelo Git nunca entra no WIP;
- arquivo **não ignorado** com nome de segredo **não sobe**, nem inteiro nem dentro dos patches; o
  backup fica INCOMPLETO e o `eos check` reprova `secrets` até você decidir (ignorar ou excluir);
- arquivo com nome de segredo **já commitado** vai no bundle (o bundle é o histórico): o motor
  declara isso, reprova `secrets` e o projeto fica abaixo de L4 até a sanitização;
- o stash fica fora do bundle, porque pode carregar um `.env` não rastreado.

Limite declarado: segredo **dentro** de um arquivo de nome inocente (um `config.json` com token) não é
detectado pelo nome. Quem pega isso é a varredura de conteúdo (`/os:security` e o hook
`pre-commit`).

### `secrets.allowed_paths`: falso positivo legítimo

Documentação ou teste **sobre** segredo (ex.: `docs/decisions/DEC-004-client-secret-...md`,
`tests/test_check_secrets.py`) tem nome que casa a regra sem conter segredo nenhum. A saída é
declarar o **caminho exato** em `secrets.allowed_paths` no contrato, depois de alguém conferir o
conteúdo. A validação recusa ali `.env`, chave, curinga e caminho fora do projeto.

## 7. "Achei um segredo no Git" (gate H5)

1. O Claude para com `HUMAN ACTION REQUIRED — Gate: H5`, sem reproduzir o valor.
2. **Você rotaciona a credencial na origem** (revoga e gera outra). Isso vem antes de tudo: o valor
   antigo deve ser considerado público.
3. Se estiver no histórico: sanitização é reescrita de histórico (H3). O original é preservado no
   Drive com hash, o plano é simulado, os testes passam no histórico sanitizado, e só então, com seu
   sim, as refs são trocadas. Se já estava no GitHub, entra *force push*, também H3.
4. Não existe exceção por "valor já rotacionado": enquanto o nome estiver no histórico, o projeto
   fica abaixo de L4.
5. O incidente é registrado no `STATE.md` do projeto, **sem o valor**.

## 8. Checklist de segredo novo num projeto

- [ ] Nome da variável no `secrets.manifest` e no `.env.example` (sem valor).
- [ ] Valor no cofre (ou, enquanto não houver Bitwarden, no `.env` local ignorado).
- [ ] `git status` não mostra o `.env`.
- [ ] `py -3.13 -m eos check <id>`: dimensão `secrets` em PASS.
