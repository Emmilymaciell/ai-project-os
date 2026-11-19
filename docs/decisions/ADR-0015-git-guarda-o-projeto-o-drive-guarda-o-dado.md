# ADR-0015 — O Git guarda o projeto; o Drive guarda o dado bruto

- **Data:** 2026-10-11
- **Status:** Aceita — decisão da mantenedora, canônica para projetos atuais e futuros
- **Estende:** ADR-0003 (GitHub privado) e ADR-0013 (Drive como plano de dados)

## Contexto

Em 2026-10-11 a mantenedora autorizou remoto GitHub **privado** para **todos** os projetos lógicos
do ecossistema, inclusive os Programa e o Organizador Dynatest, e fixou uma condição: o histórico Git
não é depósito de dado pessoal de terceiro.

A varredura de histórico de 2026-10-08 (relatórios em `RUN-20261008-001/F6-scans/`) mediu por que a
condição importa. Encontrou CPF com dígito verificador válido em dois repositórios, e-mails e
telefones de terceiros em cinco, e documentos operacionais brutos (`.xlsx`, `.pdf`, `.docx`)
rastreados em três. Fazer push desses repositórios, como estão, replicaria tudo isso.

## Decisão

1. **Todo projeto lógico tem Git e remoto privado.** Isso **não** significa que todo arquivo do projeto
   está no Git.
2. **No Git:** código, arquitetura, scripts, `STATE`, decisões, manifestos, documentação técnica,
   configuração sem segredo. Também referências ao dado bruto: manifestos, hashes, IDs e caminhos
   lógicos, quando isso basta.
3. **No Drive** (`EMMILY PROJECT CLOUD/<categoria>/<id>/`): documentos brutos, PDFs, planilhas,
   bancos, evidências, e todo arquivo com CPF, e-mail ou telefone de terceiro.
4. **Arquivo técnico ou documental que precisa estar no Git é redigido antes**: o dado pessoal de
   terceiro sai, e o original fica no Drive.
5. **O original nunca é apagado nem alterado para sanitizar o Git.** Ele é preservado no Drive, com
   hash, antes de qualquer sanitização.
6. **Titularidade incerta é dado de terceiro.** CPF, e-mail ou telefone que não se prove ser da
   mantenedora é tratado como de terceiro.
7. **Segredos** (tokens, cookies, senhas, códigos de 2FA) nunca entram no Git. Isso já valia; fica
   registrado aqui junto.

## Como se aplica a repositório que JÁ tem o dado no histórico

Remover o arquivo da árvore atual não basta: o push levaria o histórico. Sanitizar o histórico é
**reescrevê-lo**, e reescrever histórico é ação destrutiva. A mantenedora exigiu um gate H3
**específico** para isso. Então:

- **Preparação, sem gate e não destrutiva:**
  1. o original vai para o Drive, com hash;
  2. num clone **separado**, o histórico é sanitizado (`git filter-repo` 2.47.0, num venv isolado);
  3. o resultado é varrido de novo pelo scanner da plataforma, que tem de dar zero dado de
     terceiro;
  4. sai um relatório do que foi removido e do que foi redigido, por caminho.

  O repositório de trabalho não é tocado.
- **Adoção, com gate H3:** o histórico sanitizado passa a ser o do projeto, e só então vai para o
  remoto. O histórico original continua recuperável pelo bundle no Drive, preservado em 2026-10-08
  e antes da adoção. O WIP da árvore de trabalho não é tocado.
- **Repositório sem o dado no histórico:** remoto e push direto, sem gate.
- **Documento bruto SEM dado pessoal já no histórico** (planilha, PDF ou `.docx` de referência):
  o histórico **não** é reescrito, porque a razão da reescrita é o dado de terceiro e ele não está
  lá. O arquivo sai do rastreamento daqui para a frente (`git rm --cached` + `.gitignore`, com o
  original no Drive) quando não for necessário ao funcionamento. Arquivo grande que o projeto
  precisa para funcionar, como os vídeos do frontend do Dashboard, fica no Git.

  "Sem dado pessoal" é **medido**, não suposto: um leitor stdlib abre o XML de `.docx`, `.xlsx` e
  `.pptx`, os streams Flate de PDF e o texto, e procura CPF com dígito válido, e-mail que não é de
  papel e celular formatado. O leitor foi validado por controle positivo: detectou CPF, e-mail e
  celular num `.docx` sintético e num arquivo real do Semanal. Em 2026-10-11 ele deu zero nos
  documentos do Cérebro e do Grupo 1. PDF sem texto extraível conta como **incerto**, e incerto é
  dado de terceiro.
- **Repositório sem nenhum commit (unborn):** o primeiro commit já nasce sanitizado.

## Para projetos novos

O `/os:new-project` já nasce com remoto privado. O `.gitignore` do template bloqueia documento de
escritório e dado bruto (`data/`, `output/`). A pasta do Drive do projeto é criada junto, e é o
lugar do dado bruto.

## Alternativas consideradas

- **Fazer push do histórico como está, com exceção registrada (o caminho do ADR-0010).** Rejeitada
  pela mantenedora para dado de terceiro. O ADR-0010 continua valendo para o caso dele, a auditoria
  da Fase 0 desta plataforma.
- **Espelho sanitizado permanente** (o trabalho segue no histórico bruto e um processo recria o
  espelho a cada push). Rejeitada: duas linhagens do mesmo projeto divergem, e o L2 ("tudo
  publicado") deixaria de ser medível.
- **Só Drive, sem GitHub, para os repositórios com dado.** Rejeitada pela mantenedora: todo projeto
  tem remoto.
