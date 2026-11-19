# Programa vNext — texto integral

> Entregue pela mantenedora em 2026-10-08, na sessão 3. Transcrito **sem edição** do
> transcript da sessão (SHA-256 do corpo: `6b42885c2f3b3a7cce3c88203a87908a19419875cc07dc2d6b5279215f1923e7`).
> Versionado porque o princípio central desta plataforma proíbe que um requisito exista só na
> conversa. Decisões tomadas a partir dele estão nos ADR-0012 em diante; o estado de execução,
> em `docs/vnext/EXECUCAO.md`.

---

# EMMILY AI PROJECT OS vNext
## MASTER AUTONOMOUS IMPLEMENTATION PROGRAM — CLAUDE CODE LOCAL

Você é o LEAD ORCHESTRATOR responsável por recuperar o estado atual do Emmily AI Project OS, implementar o vNext e migrar progressivamente todo o ecossistema de projetos da Emmily para uma arquitetura profissional de continuidade, Git/GitHub, Google Drive, backup, restore, portabilidade, segurança, governança e independência de sessões de IA.

Isto NÃO é uma tarefa curta e NÃO deve ser tratado como uma sequência de prompts manuais.

Trate como UM PROGRAMA DE IMPLEMENTAÇÃO CONTÍNUO, RESUMÍVEL E AUDITÁVEL.

Seu objetivo é trabalhar autonomamente do estado atual até os critérios de conclusão definidos abaixo, interrompendo a Emmily apenas em HUMAN GATES legítimos.

==================================================
0. PRINCÍPIO MÁXIMO
==================================================

SESSÃO DE IA = DESCARTÁVEL
COMPUTADOR = SUBSTITUÍVEL
PROJETO = PERMANENTE

Perder Claude, conta Claude, ChatGPT, sessões, computador, clone local ou cache de plugin NÃO pode significar perder um projeto.

O Emmily AI Project OS deve se tornar o gerente central de TODOS os projetos atuais e futuros da Emmily.

Ele deve saber responder e/ou executar com segurança coisas como:

- Como estão meus projetos?
- Esse projeto está seguro?
- Qual projeto precisa de atenção?
- Faça backup.
- Salve um checkpoint.
- Posso apagar esta sessão?
- Posso apagar esta pasta local?
- Posso trocar de computador?
- Prepare a troca de computador.
- Restaure o projeto X.
- Crie um projeto novo.

A Emmily NÃO deve precisar decorar Git internals, refs, worktrees, checksums, restore procedures ou caminhos específicos de máquina.

==================================================
1. ESTADO ATUAL CRÍTICO — RECOVERY 2.7 PRIMEIRO
==================================================

ANTES de implementar o vNext, RECUPERE E RECONCILIE o trabalho já existente do Emmily AI Project OS.

Último estado conhecido informado pela sessão anterior:

- Repositório: C:\AI-WORKSPACE\_platform\emmily-ai-project-os
- Fase 2.6 fechada no commit/HEAD conhecido: 85cbafd
- origin/main também estava nesse commit na última observação local.
- Fase 2.7 estava em desenvolvimento NÃO COMMITADO.
- Arquivos conhecidos envolvidos no WIP 2.7 incluem:
  - scripts/branch.ps1
  - scripts/lib/branch-comum.ps1
  - scripts/pr.ps1
  - scripts/lib/pr-comum.ps1
  - tests/suites/fluxo.ps1
  - possivelmente registro correspondente no runner e outros arquivos relacionados; REVALIDAR NO DISCO.
- tests/suites/fluxo.ps1 tinha 36 casos passando em uma execução inicial.
- 14 mutações tinham sido iniciadas em background antes da pausa/restart.
- O notebook foi reiniciado/pausado.
- A sessão anterior declarou que nenhuma das cinco tarefas de background interrompidas havia alterado o estado observado naquele momento, mas NÃO ASSUMA que isso continua verdadeiro: revalide.
- Defeitos já encontrados/corrigidos no WIP incluíam:
  - caractere não ASCII U+00B7 em pr-comum.ps1;
  - atribuição indevida à variável automática $args em pr.ps1;
  - asserções de teste fracas que poderiam aprovar pelo motivo errado;
  - mock .cmd que não testemunha fielmente --body multilinha, motivando Get-ArgumentosDePrCreate.
- A suite fluxo tinha aproximadamente 969 linhas; a coleta de evidência planejada precisava considerar limite superior, historicamente algo como -MaxLinhasArquivoNovo 1100 -MaxLinhasDiff 6000. Revalide a interface atual do coletor antes de usar qualquer parâmetro.

REGRA:

NÃO resetar.
NÃO clean.
NÃO checkout destrutivo.
NÃO sobrescrever esses arquivos.
NÃO assumir que o último estado de chat é a verdade atual.

Primeiro:

1. leia CLAUDE.md, STATE, sessões, decisões, runbooks e instruções locais relevantes;
2. execute o mecanismo session-start/recovery existente do próprio projeto, se aplicável;
3. capture Git status, HEAD, branch, refs, worktrees e processos relevantes;
4. verifique se existe qualquer mutator/processo residual;
5. compare o estado real com o checkpoint acima;
6. preserve o diff/WIP antes de qualquer alteração estrutural;
7. conclua, valide ou congele a fase 2.7 em checkpoint seguro segundo as regras existentes do projeto;
8. somente depois crie isolamento para o trabalho vNext.

Se encontrar divergência material entre este checkpoint e o disco, o DISCO + GIT + documentos canônicos vencem. Registre a reconciliação.

==================================================
2. AUTONOMY POLICY
==================================================

NÃO pare rotineiramente para:

- informar progresso;
- perguntar se deve continuar;
- pedir autorização para iniciar a próxima fase não destrutiva;
- pedir confirmação de decisões já definidas neste programa;
- mostrar cada resultado intermediário;
- perguntar preferências cosméticas;
- pedir que a Emmily escolha detalhes técnicos reversíveis que você pode decidir profissionalmente.

Depois de iniciar, CONTINUE AUTONOMAMENTE até:

A. concluir o programa; ou
B. atingir um HUMAN GATE legítimo; ou
C. encontrar risco material que não possa ser mitigado com segurança; ou
D. encontrar falha técnica realmente bloqueante após diagnóstico e tentativas razoáveis.

Quando precisar da Emmily, PARE EM ESTADO SEGURO e responda exatamente com uma seção clara:

HUMAN ACTION REQUIRED

Gate: H1/H2/H3/H4/H5
Reason:
...
Exact action for Emmily:
...
What I have already protected:
...
What will continue automatically afterward:
...

Depois da ação humana, reconcilie o estado e CONTINUE automaticamente. Não recomece o programa.

==================================================
3. HUMAN GATES PERMITIDOS
==================================================

H1 — AUTHENTICATION
Somente quando login, OAuth, 2FA, Bitwarden unlock, Google, GitHub ou Microsoft realmente exigirem ação humana.

H2 — EXTERNAL PERMISSION / CONSENT
Somente para autorização externa que a IA não pode conceder legitimamente.

H3 — DESTRUCTIVE ACTION
Obrigatório antes de DELETE, overwrite irrecuperável, history rewrite, remoção final de clone/cópia, descarte de worktree, limpeza destrutiva ou exclusão de backup antigo.

H4 — MATERIAL AMBIGUITY
Somente quando duas ou mais opções plausíveis puderem causar perda ou mudança arquitetural relevante e a evidência não permitir decisão segura.

H5 — SECURITY INCIDENT
Ex.: secret real versionado, credencial exposta, suspeita de comprometimento, token no histórico.

Fora desses gates: NÃO PARE.

==================================================
4. SEGURANÇA ABSOLUTA DA MIGRAÇÃO
==================================================

A ordem universal é:

DISCOVER
-> PROTECT
-> COPY
-> VERIFY
-> REGISTER
-> SWITCH
-> CERTIFY
-> CLEANUP

NUNCA faça MOVE/DELETE/CLEAN/NORMALIZE antes da proteção correspondente ter sido VERIFICADA.

Não faça reorganização estética antes de proteção.

Não use git reset --hard.
Não use git clean destrutivo.
Não reescreva histórico.
Não force push.
Não descarte branches/worktrees.
Não transforme dirty state em commit apenas para “deixar limpo” sem entender o conteúdo.

Commits e pushes NÃO destrutivos podem ser feitos autonomamente quando:

- o conteúdo foi revisado;
- testes/gates previstos passaram;
- secret scan não encontrou incidente;
- o remote correto foi validado;
- a ação preserva história e é coerente com a política do projeto.

Repos novos no GitHub devem ser PRIVATE por padrão.
Nunca publique repositório sem autorização explícita.

==================================================
5. ARQUITETURA CANÔNICA vNEXT
==================================================

Responsabilidades oficiais:

GITHUB PRIVATE
= remote Git oficial, código, scripts, histórico, branches, tags, documentação, manifests, STATE textual, HANDOFF, ADRs, decisões, runbooks, testes, config sem secrets, adapters de IA.

GOOGLE DRIVE 5 TB
= nuvem pessoal principal de dados e recovery: PDFs, DOCX, XLSX, imagens, vídeos, datasets, assets, inputs, outputs, DB snapshots, WIP snapshots, Git recovery bundles/mirrors, disaster-recovery packages.

BITWARDEN
= source of truth de secrets: passwords, tokens, API keys, recovery codes, credenciais.

SHAREPOINT / ONEDRIVE CORPORATIVO
= EXTERNAL OPERATIONAL SOURCE quando um projeto usa documentos do contrato, Microsoft Graph, API ou fontes corporativas. NÃO é o backup canônico do projeto.

LOCAL WORKSPACE
= execução ativa.

Não coloque working trees Git ativos dentro de pasta sincronizada do Google Drive.

==================================================
6. GOOGLE DRIVE — PRINCÍPIOS
==================================================

Root lógico alvo:

EMMILY PROJECT CLOUD/
  00 PLATFORM/
  01 PROG/
  02 PERSONAL/
  03 UNIVERSITY/
  04 PORTFOLIO/
  05 LAB/
  99 RECOVERY/

Em 99 RECOVERY, estruturar conforme implementação validada, cobrindo no mínimo:

- git recovery
- wip snapshots
- database snapshots
- manifests
- disaster recovery

NÃO adivinhe a letra/caminho do Google Drive no Windows.
Descubra a instalação real.

Para automação, avalie e implemente a opção mais robusta e portátil entre transporte por API/CLI e Drive Desktop. A arquitetura deve tratar Google Drive como serviço lógico, não como uma letra fixa.

Se rclone/restic forem escolhidos após prova no Portability Lab:

- registre versão e bootstrap;
- não exponha tokens;
- use OAuth com H1 quando necessário;
- mantenha backup criptografado para WIP/state quando adequado;
- prove restore antes de promover a solução.

==================================================
7. AI-NEUTRAL CORE
==================================================

NENHUMA IA é source of truth.

Claude session, ChatGPT session, AutoMemory e cache de plugin NÃO podem conter o único exemplar de conhecimento necessário à continuidade.

Arquivos canônicos devem ser provider-neutral, por exemplo:

project.yaml
STATE.md
HANDOFF.md
DECISIONS/
ADRs/
RUNBOOKS/
ENVIRONMENT/
RECOVERY/
storage.yaml ou equivalente
secrets.manifest ou equivalente

Adapters podem existir:

CLAUDE.md
.claude/
AGENTS.md
config Codex
outros adapters futuros

Mas adapters derivam/consomem o mesmo core.

Trocar de Claude para Codex ou outra IA não deve exigir reconstrução intelectual do projeto.

Antes de session-close, pergunte internamente:

“Existe informação necessária para uma futura IA continuar este projeto que ainda só existe nesta conversa?”

Se sim: PERSIST FIRST, CLOSE SECOND.

==================================================
8. PATH PORTABILITY
==================================================

Eliminar progressivamente hardcodes de máquina/usuário quando seguro.

Usar abstrações como:

${AI_WORKSPACE}
${PROJECT_ROOT}
${GDRIVE_ROOT}
${DATA_ROOT}
${OUTPUT_ROOT}
${BACKUP_ROOT}
${PROG_SHAREPOINT_ROOT}

Cada máquina resolve seus paths localmente.

Não faça substituição em massa antes da preservação e dos testes.

==================================================
9. PROJECT MODEL E REGISTRY
==================================================

O OS deve reconhecer quatro tipos:

PROJECT
COLLECTION
EXTERNAL_SOURCE
ARCHIVE

Exemplos:

Programa Relatório G2 = PROJECT
Dynatest Engenharia - Pessoal = COLLECTION
SharePoint Programa = EXTERNAL_SOURCE

Todo PROJECT lógico pode ter seu próprio Git repo.

Não confunda “projeto ter Git” com “todos os arquivos grandes entrarem no Git”.

Crie Registry canônico versionado, preferencialmente YAML por projeto:

registry/projects/<project-id>.yaml

Pode haver registry.db SQLite como índice/cache DERIVADO e reconstruível.

YAML/arquivos canônicos vencem.
SQLite derivado nunca deve ser a única fonte do registry.

Cada registro deve cobrir no mínimo:

identity
name
category
status
local workspace
git repo
GitHub remote
Google Drive root
external sources
state strategy
environment
secrets manifest
backup policy
portability
health
recovery
last verified checkpoint

==================================================
10. PROJECT CONTRACT
==================================================

Implemente schema versionado de contrato de projeto.

A sintaxe final deve ser projetada e testada, mas semanticamente deve cobrir:

project identity
workspace
Git
cloud
external sources
state/database
environment
secrets
backup
AI/session independence
portability
recovery
health

Valide schema automaticamente.

==================================================
11. PORTABILITY
==================================================

Níveis oficiais:

L0 — Local Only
L1 — Git Versioned
L2 — Remote Protected
L3 — Data Protected
L4 — Environment Reproducible
L5 — Session Independent
L6 — Disaster Recovery Tested

Meta de projetos importantes: L6.

Implemente duas operações distintas:

PORTABILITY CHECK
= verificação rápida do estado atual.

PORTABILITY CERTIFY
= prova real por restauração isolada quando aplicável.

Não marque CERTIFIED porque arquivos/configs “parecem corretos”.
Certificação exige prova suficiente.

O check deve responder de forma legível para leigo, incluindo respostas objetivas para:

Safe to delete session?
Safe to delete local clone?
Safe to change computer?

Se não for seguro, diga exatamente o bloqueador e NÃO permita falso positivo.

==================================================
12. HEALTH / SAFETY / OPERATION
==================================================

Implemente health derivado de verificações reais, não números decorativos.

Avaliar dimensões como:

Git
Remote
Cloud
Backup
State
Secrets
Environment
Portability
Recovery
External Sources

Separar:

PROJECT SAFETY
vs
PROJECT OPERATION

Exemplo:

GitHub PASS
Google recovery PASS
Restore PASS
SharePoint unavailable

=> SAFETY SAFE
=> OPERATION DEGRADED

Não gerar alarme de perda quando só uma fonte externa está indisponível.

==================================================
13. BACKUP MODEL
==================================================

Três necessidades diferentes:

A. HISTÓRICO GIT
GitHub como live remote + recovery independente no Google Drive usando mecanismo válido, como bundle/mirror, preservando refs necessárias.

B. DADOS GRANDES
Google Drive.

C. WIP / ESTADO LOCAL NÃO COMMITADO
Snapshots específicos, porque GitHub e git bundle NÃO protegem dirty/untracked/worktrees não commitados.

WIP protection deve cobrir conforme o projeto:

modified
untracked relevante
worktrees relevantes
databases
artifacts necessários
state ainda não commitado

Sempre diferenciar backup de versionamento.

==================================================
14. DATABASES
==================================================

Nunca operar SQLite vivo diretamente dentro de Google Drive sincronizado.

Modelo:

LIVE DB LOCAL
-> consistent snapshot
-> integrity validation
-> checksum
-> encrypted/cloud backup

Para Cérebro Documental, Organização SharePoint e outros stateful projects, implementar policy específica.

Schema/migrations/código podem ficar no Git.
State real precisa de snapshot/restore próprio.

==================================================
15. SECRETS
==================================================

Nunca revelar nem versionar valores secretos.

Git pode conter:

.env.example
secrets.manifest
nomes/referências dos secrets

Valores ficam em Bitwarden/local runtime.

Se encontrar segredo real no Git/histórico: H5.

Não abra arquivos sensíveis além do necessário.
Nunca reproduza token/password em journal/log/report.

==================================================
16. CLAUDE CODE — ORQUESTRAÇÃO
==================================================

Você é o TEAM LEAD.

Agent Teams está disponível nesta sessão, mas é experimental e NÃO é mecanismo de persistência.

Use uma combinação profissional:

- Lead principal: coordena arquitetura, integração, decisões e gates.
- Subagents: tarefas focadas, pesquisa, leitura, análise, revisão, testes onde a comunicação direta entre trabalhadores não é necessária.
- Agent Team: somente quando vários trabalhadores realmente precisam compartilhar descobertas, contestar resultados ou coordenar módulos independentes.
- Worktree isolation: para qualquer worker que escreva em Git quando houver paralelismo.

Comece normalmente com 3-5 workers no máximo quando paralelismo trouxer benefício real. Não crie exército de agentes sem necessidade.

Papéis sugeridos, reutilizando/criando definições especializadas quando fizer sentido:

Preservation Agent
Git/GitHub Agent
Google Drive/Backup Agent
Registry/Schema Agent
OS Core Agent
Environment/Portability Agent
Security Agent
Project Migration Agent(s)
Recovery/QA Agent

REGRAS:

1. Nenhum dois agentes podem editar a mesma working tree simultaneamente.
2. Nenhum dois agentes podem possuir o mesmo conjunto de arquivos de escrita simultaneamente.
3. Use isolation: worktree ou worktree explícita quando houver escritores concorrentes.
4. Read-only review pode ser paralelo.
5. O Lead é dono de merge/integration.
6. Teammates não guardam estado canônico.
7. Toda decisão/material result deve ser persistida em journal/arquivos canônicos.
8. Nunca dependa do shared task list do Agent Team como único registro do programa.
9. Não crie nested teams.
10. Se uma sessão for retomada e teammates anteriores não existirem, reconstrua o estado pelo journal e crie workers substitutos.

==================================================
17. AGENT SDK / NON-INTERACTIVE MODE
==================================================

NÃO migre esta implementação inicial para Agent SDK ou `claude -p` apenas por parecer mais “automatizado”.

A implantação principal deve permanecer INTERACTIVE Claude Code local porque:

- precisamos de Human Gates legítimos;
- precisamos de Agent Teams quando úteis;
- precisamos de acesso local progressivo e observável;
- o projeto já possui lifecycle de sessão.

Agent SDK poderá ser considerado posteriormente como adapter/programmatic runtime do próprio Emmily OS DEPOIS de o core vNext estar estável e certificado.

Não torne o sucesso do vNext dependente do SDK.

==================================================
18. RESILIÊNCIA / JOURNAL / RESUME
==================================================

A implantação deve sobreviver a:

- notebook reiniciar;
- internet cair;
- Claude crashar;
- limite de uso;
- sessão ser fechada;
- compactação de contexto;
- teammate morrer.

Crie um RUN_ID antes de alterações do vNext.

Persistir uma estrutura equivalente a:

runs/
  RUN-YYYYMMDD-NNN/
    RUN_STATE.json
    EVENTS.jsonl
    BLOCKERS.json
    CHECKPOINTS/
    REPORT.md

A localização final pode ser refinada conforme a arquitetura atual, mas os requisitos semânticos são obrigatórios.

Estados mínimos:

NOT_STARTED
RUNNING
DONE
BLOCKED
FAILED_SAFE
VERIFIED

Para cada etapa registre:

step
status
started
completed
artifacts/evidence
verification
blocker
next action
relevant commit/ref/snapshot

Operações devem ser idempotentes sempre que razoável.

Em retomada:

1. leia journal;
2. leia Git/filesystem real;
3. reconcilie divergência;
4. NÃO repita cegamente ação material;
5. continue do último checkpoint seguro.

Depois que Google Drive recovery estiver operacional, replique também o material crítico de run/recovery na nuvem conforme policy.

==================================================
19. SESSION LIFECYCLE vNEXT
==================================================

SESSION START deve futuramente verificar, conforme aplicável:

registry
project identity
Git/branch/HEAD
remote status
working tree
worktrees
environment
cloud/data availability
state/handoff
continuity alerts

SESSION CLOSE deve futuramente executar ou orquestrar, conforme política:

persist cognition
STATE update
HANDOFF update
decision extraction
QA/test
secret scan
Git inspection
checkpoint quando autorizado/policy exigir
remote sync/verification
state/data backup
portability quick check

Resultado humano deve incluir:

SAFE TO DELETE SESSION: YES/NO
SAFE TO DELETE LOCAL CLONE: YES/NO

Não minta se houver unprotected WIP.

==================================================
20. COMANDOS/OPERAÇÕES DE ALTO NÍVEL
==================================================

Implemente capacidades equivalentes a:

os new / os-new-project
os onboard
os portfolio
os status
os doctor
os backup
os checkpoint
os portability-check
os portability-certify
os prepare-machine-migration
os restore
os session-start
os session-close
os resume

Os nomes finais devem harmonizar com a arquitetura já existente. Evite duplicar comandos se já houver equivalentes melhores.

A experiência humana deve ser linguagem natural + comandos simples.

==================================================
21. WORKSPACE LOCAL ALVO
==================================================

Estrutura conceitual:

C:\AI-WORKSPACE\
  _platform\
    emmily-ai-project-os\
  prog\
  personal\
  university\
  lab\
  portfolio\

IMPORTANTE:

Não mova projetos atuais para essa estrutura só para “ficar bonito”.
Primeiro protect, verify, register, certify.
A mudança física de localização é posterior e deve preservar referências.

==================================================
22. INVENTÁRIO BASE A REVALIDAR
==================================================

A auditoria anterior encontrou os seguintes logical projects/repos/collections relevantes. Revalide antes de escrever:

Git/projetos principais:

C:\caminho\exemplo\PROG_Relatorio_G2_Automacao
C:\caminho\exemplo\Projeto_Pessoal_A
C:\caminho\exemplo\PROG_Relatorio_Semanal_Automacao
C:\caminho\exemplo\PROG_Cerebro_Documental
C:\caminho\exemplo\PROG_Relatorio_Grupo1_Automacao
C:\caminho\exemplo\PROG_Dashboard_Juridico
C:\caminho\exemplo\PROG_Repositorio_Juridico
C:\AI-WORKSPACE\_platform\emmily-ai-project-os
C:\caminho\exemplo\PROG_Organizacao_SharePoint
C:\AI-WORKSPACE\ai-lab\conversor-utm
C:\caminho\exemplo\EmpresaX_Portfolio

Projeto adicional encontrado:

C:\caminho\exemplo\OneDrive\Documentos\Claude\Organizador_Dynatest_Pessoal

Collections/pastas sem Git ou heterogêneas:

C:\caminho\exemplo\Desktop\engenharia-rodoviaria_1.4\engenharia-rodoviaria_1.3
C:\caminho\exemplo\OneDrive\Documentos\Trabalho\Dynatest Engenharia - Pessoal
C:\caminho\exemplo\Documents\Codex
C:\caminho\exemplo\Downloads\TRABALHO SISTEMAS
C:\caminho\exemplo\Downloads\P1 HIDROLOGIA
C:\caminho\exemplo\Downloads\teste claude

Auditoria anterior também encontrou aproximadamente:

- 18 pastas de projeto/acervo;
- 12 repositórios Git verdadeiros;
- 41 worktrees adicionais;
- somente o Emmily AI Project OS com remote conhecido naquele momento;
- G2 com múltiplas alterações e cinco worktrees dirty;
- Empresa X com Git unborn/zero commits;
- bancos SQLite/backups locais relevantes no Cérebro e Organização SharePoint;
- vários projetos MOSTLY SESSION-INDEPENDENT, mas sem proteção externa comprovada.

Esses números são BASELINE HISTÓRICO, não verdade atual. Revalide.

==================================================
23. GITHUB ORGANIZATION LOGIC
==================================================

Todo projeto lógico real deve poder ter repo Git separado e organizado.

Não é necessário criar uma GitHub Organization paga.
Pode usar a conta pessoal da Emmily com naming consistente e repositórios PRIVATE.

Convenção sugerida, a validar sem renomear o repo atual desnecessariamente:

platform-...
prog-...
personal-...
university-...
portfolio-...
lab-...

Use topics/metadata para category/status quando útil.

O repo existente `Emmilymaciell/emmily-ai-project-os` NÃO deve ser renomeado só por estética durante a migração.

==================================================
24. FASE -1 — RECOVERY 2.7
==================================================

Esta fase é OBRIGATÓRIA e vem antes do vNext.

Objetivo:

- recuperar contexto real da 2.7;
- confirmar que não existe mutator ativo/resíduo;
- reconciliar os testes/mutations/evidências;
- preservar WIP;
- concluir ou congelar a 2.7 em checkpoint verificável;
- NÃO perder trabalho anterior.

Use arquitetura/testes/regras existentes do projeto.

Se finalizar 2.7 com segurança for mais correto que congelar, finalize.
Se houver impedimento não destrutivo, preserve e crie checkpoint explícito antes do vNext.

Gate:

RECOVERY_2_7_GATE = PASS

antes da Phase 0 vNext.

==================================================
25. FASE 0 — PREFLIGHT vNEXT
==================================================

Leia e reconcilie:

CLAUDE.md
project manifest
STATE
ADRs/decisions
runbooks
skills
agents
hooks
plugin metadata
tests
Git status
branches
worktrees
remote
cache/plugin instalado
source atual
existing dirty/untracked

Diferencie:

IMPLEMENTED
PARTIAL
DOCUMENTED_ONLY
PLANNED
OBSOLETE

Não reescreva componentes bons.
Projete evolução incremental.

Crie RUN_ID e journal do vNext.

==================================================
26. FASE 1 — EMERGENCY PRESERVATION
==================================================

ANTES de migração estrutural, proteja o estado atual dos projetos mais vulneráveis.

Prioridade mínima:

1. G2 principal + TODOS os worktrees dirty/relevantes
2. Empresa X
3. Cérebro Documental DB/state + Git refs
4. Organização SharePoint DB/state
5. Grupo1/Entrega
6. Dashboard Jurídico
7. Emmily AI Project OS current WIP
8. Organizador Dynatest

Depois amplie para todo projeto relevante conforme inventário.

Proteção deve cobrir separadamente:

- refs/commits;
- dirty tracked;
- relevant untracked;
- worktrees;
- DB/state;
- artifacts essenciais à retomada.

Não assuma que git bundle protege uncommitted content.

Pode usar staging local seguro temporário antes da nuvem, mas isso NÃO conta como disaster recovery.
Assim que Google Drive estiver disponível/autenticado, replique recovery verificável para lá.

Calcule/verifique hashes/manifests onde apropriado.

Gate:

PRESERVATION_GATE = PASS

Somente então prossiga para alterações estruturais.

==================================================
27. FASE 2 — PORTABILITY LAB
==================================================

Crie projeto isolado descartável:

emmily-portability-lab

Use-o para PROVAR a arquitetura sem arriscar projeto real.

Deve testar no mínimo:

Git local
GitHub private remote
Google Drive data/recovery
Git recovery bundle/mirror
WIP snapshot
project contract
registry entry
portable paths
environment manifest
backup
restore
portability-check
portability-certify
session-independent state
security/secret manifest sem valores

Faça um restore realmente isolado.

Não promova implementação do lab para produção até:

PORTABILITY_LAB_CERTIFICATION = PASS

Registre ADR das escolhas definitivas, incluindo mecanismo Google Drive/backup.

==================================================
28. FASE 3 — vNEXT CORE
==================================================

Desenvolva vNext em branch/worktree isolado do stable/current line.

Não sobrescreva prematuramente a implementação existente.

Implementar/reutilizar de forma integrada:

Project Contract schema
Registry
Portfolio manager
Cloud abstraction
Google Drive integration
Git/GitHub integration
Backup engine
WIP protection
Database snapshot policies
Recovery engine
Portability check
Portability certification
Health/safety/operation
Environment/bootstrap
Portable path resolver
Secrets manifest/injection interface
AI-neutral canonical state
Claude adapter
Codex adapter
Session start/close evolution
Journaling/resume
Doctor
Machine migration readiness
Security checks
QA/evidence

Utilize testes, mutation testing e reviewers proporcionais ao risco.

Não considere feature “done” apenas porque happy path funciona.

==================================================
29. FASE 4 — SELF MIGRATION
==================================================

O próprio Emmily AI Project OS é o PRIMEIRO projeto real do padrão.

Ele deve ser capaz de:

backup itself
restore itself
install/bootstrap itself
doctor itself
portability-check itself
certify itself
rebuild derived state
reconstruct Claude integration from canonical source

Resolver explicitamente a divergência fonte vs cache instalado.

O cache em ~/.claude NÃO é source of truth.

Gate:

EMMILY_AI_PROJECT_OS = L6

antes de usá-lo como migrador oficial dos demais projetos.

==================================================
30. FASE 5 — REGISTRY COMPLETO
==================================================

Registrar todo o ecossistema real.

Categorias mínimas:

PLATFORM
Programa
PERSONAL
UNIVERSITY
PORTFOLIO
LAB

Tipos:

PROJECT
COLLECTION
EXTERNAL_SOURCE
ARCHIVE

Não invente projetos.
Não transforme collection em monorepo gigante.

Mapeie também:

SharePoint Programa e outras fontes externas
Google Drive logical roots
GitHub repos
local paths atuais
portability level
health
last backup
last certification

==================================================
31. FASE 6A — MIGRAÇÃO DE MENOR COMPLEXIDADE
==================================================

Migrar primeiro projetos mais simples/estáveis, revalidando ordem por risco atual:

conversor-utm
Projeto Pessoal A
Relatório Semanal
Repositório Jurídico
engenharia-rodoviaria

Cada PROJECT deve terminar com, conforme aplicável:

repo validado
private GitHub remote
Drive root
project contract
registry entry
environment
backup policy
WIP policy
secret manifest
portable paths
health
portability check
restore instructions

Não incluir dados gigantes no Git só porque o projeto possui repo.

==================================================
32. FASE 6B — MIGRAÇÃO COMPLEXA / STATEFUL
==================================================

Depois:

Cérebro Documental
Organização SharePoint
G2
Grupo1/Entrega
Dashboard Jurídico
Empresa X
Organizador Dynatest, se ainda não resolvido na onda adequada

Tratar explicitamente:

SQLite
worktrees
branches/refs adicionais
outputs
SharePoint/Graph
Office/COM
Power BI
junctions
assets
large files
credentials
external source availability

Para G2, NÃO simplifique as dezenas de worktrees sem entender e proteger cada estado relevante.

Para Empresa X, lembre que Git existir sem commit não é proteção.

==================================================
33. FASE 7 — COLLECTIONS E ACERVOS
==================================================

Analisar/decompor com segurança:

Dynatest Engenharia - Pessoal
Documents\Codex
TRABALHO SISTEMAS
P1 HIDROLOGIA
teste claude

Classificar conteúdos como:

PROJECT
COLLECTION
REFERENCE_DATA
ARCHIVE
OUTPUT

Todo projeto lógico real pode receber repo separado.

Documentos puros e arquivos grandes podem ficar no Google Drive vinculados ao projeto.

Não deletar duplicatas/cópias históricas nesta fase.
Apenas mapear, proteger e reorganizar de modo não destrutivo quando certificado.

==================================================
34. FASE 8 — DISASTER RECOVERY CERTIFICATION
==================================================

Para projetos críticos, simular perda da máquina atual usando localização limpa/isolada.

Provar conforme aplicável:

clone from GitHub
all required refs
restore cloud data
restore state/DB
resolve portable paths
rebuild environment
request/inject secrets sem persistir valor
run doctor
run tests/smokes
reconstruct project context sem chat anterior

Somente depois atribuir L6.

Mantenha evidência de certification date, commit/ref e recovery artifacts usados.

==================================================
35. FASE 9 — CLEANUP
==================================================

NÃO executar cleanup destrutivo autonomamente.

Produzir lista de candidatos:

clones antigos
backups manuais redundantes
ZIPs antigos
worktrees obsoletas
pastas temporárias
versões duplicadas
caches grandes

Para cada item informar:

por que parece redundante
onde está a cópia protegida
como foi verificada
espaço recuperável
risco
rollback/recovery source

Então abrir H3 e aguardar aprovação explícita.

==================================================
36. NOVOS PROJETOS FUTUROS
==================================================

Depois do vNext, “crie um projeto novo chamado X” deve criar automaticamente, conforme tipo:

Project ID
local workspace
Git repository
private GitHub remote
Google Drive root
project contract
STATE
HANDOFF
environment manifest
secrets manifest
backup policy
portability baseline
health baseline
Claude adapter
Codex adapter
registry entry
restore metadata

O projeto nasce protegido.
Não deve depender de uma futura migração para ficar seguro.

==================================================
37. MODELOS / USO EFICIENTE DOS AGENTES
==================================================

Priorize qualidade no Lead.
Use workers mais baratos/rápidos quando a tarefa for mecânica e bem delimitada, desde que isso não reduza segurança.

Para security review, arquitetura crítica, merge/integration e decisões destrutivas, use capacidade alta.

Não maximize número de agentes. Maximize throughput VERIFICADO.

Se Agent Team estiver consumindo coordenação demais, volte para subagents/worktrees.

==================================================
38. EXTERNAL SOURCES — SHAREPOINT
==================================================

SharePoint contém documentos do contrato e pode ser necessário operacionalmente por API/Graph.

Modelar explicitamente como EXTERNAL_SOURCE.

Exemplo semântico:

external_sources:
  - id: prog-sharepoint
    type: sharepoint
    role: source_documents
    required_for_operation: true

Mas:

GitHub + Google Drive recovery preservam o PROJECT.
SharePoint não substitui project backup.

Se SharePoint estiver offline:

PROJECT SAFETY pode continuar SAFE
PROJECT OPERATION pode ser DEGRADED

==================================================
39. AUTHENTICATION PLAN
==================================================

Descubra antes de pedir intervenção:

GitHub CLI/auth status
Google Drive Desktop/rclone status
Bitwarden CLI/status
Microsoft auth status

Só abra H1 quando necessário.

Nunca peça senha em texto no chat/terminal se houver OAuth/browser/secure prompt.

Para GitHub, preserve remote existente do OS e crie novos repos private somente depois de validar owner/account.

Para Google Drive, use OAuth/secure login e descubra o root real.

Para Bitwarden, use secure unlock/session handling quando chegar a fase; nunca grave master password.

==================================================
40. PERMISSION / DESTRUCTIVE SAFEGUARDS
==================================================

Não tente contornar permission prompts legítimos.

Não recomende nem ative bypassPermissions/dangerously-skip-permissions nesta migração real.

Se uma operação legítima e repetitiva estiver gerando prompts excessivos, proponha/implemente permission rules mínimas e específicas, sem abrir acesso amplo desnecessário.

Nunca configure permissão ampla apenas para “ir mais rápido”.

==================================================
41. QA / ADVERSARIAL REVIEW
==================================================

Use reviewers independentes para gates críticos.

Pelo menos nas áreas:

preservation completeness
Git/ref preservation
backup/restore correctness
secret leakage
registry/schema consistency
portable paths
DB snapshot integrity
portability certification
cleanup candidate proof

Quando útil, faça reviewers contestarem a conclusão do implementador.

Um PASS deve ter evidência.

==================================================
42. CRITÉRIO FINAL DE SUCESSO
==================================================

NÃO declare o programa completo até que, conforme escopo real e aplicabilidade:

- Emmily AI Project OS esteja L6.
- Todos os PROJECTS ativos estejam registrados.
- Todas as COLLECTIONS/SOURCES/ARCHIVES relevantes estejam classificadas.
- Todo projeto lógico aplicável tenha Git.
- Todo Git repo aplicável tenha private remote validado.
- Google Drive Data/Recovery Plane esteja operacional.
- Git recovery independente esteja operacional.
- Dirty/untracked/worktree protection esteja operacional.
- DB snapshots estejam operacionais onde aplicável.
- Secrets estejam separados de Git.
- Paths portáveis estejam implantados onde necessário.
- AI sessions sejam non-canonical.
- Claude adapter funcione.
- Codex adapter funcione.
- Portfolio status funcione.
- Health/safety/operation funcionem.
- Portability check funcione.
- Portability certification funcione.
- Prepare-machine-migration funcione.
- Restore tenha sido testado de verdade para projetos críticos.
- New-project workflow crie projetos já protegidos.
- Run/journal permita retomada após interrupção.

==================================================
43. RELATÓRIO FINAL
==================================================

Ao concluir cada macrofase, NÃO pare esperando autorização se não houver Human Gate.
Persista relatório e continue.

Ao final do programa, entregue um relatório consolidado contendo:

- arquitetura implantada;
- versões/tools adotados;
- registry final;
- projetos e seus níveis L0-L6;
- health/safety/operation;
- GitHub remotes;
- Google Drive roots;
- backup/recovery status;
- last restore certification;
- secrets migration status sem valores;
- unresolved blockers;
- cleanup candidates que dependem de H3;
- manual operacional para a Emmily;
- comandos/frases de uso diário;
- plano de manutenção automática.

==================================================
44. START NOW
==================================================

Comece AGORA pela FASE -1 — RECOVERY 2.7.

Não altere nada antes de entender o estado real.
Não perca o WIP existente.
Não reinicie o projeto.
Não recrie o que já existe sem necessidade.
Não pare para me dar updates rotineiros.

Use subagents/Agent Teams apenas onde acelerarem com segurança.
Persista continuamente.

Quando Recovery 2.7 passar, siga automaticamente para Preflight, Preservation, Portability Lab e as demais fases.

PROTECT FIRST.
VERIFY EVERYTHING.
PERSIST BEFORE CONTEXT IS LOST.
CONTINUE UNTIL DONE OR A LEGITIMATE HUMAN GATE.
