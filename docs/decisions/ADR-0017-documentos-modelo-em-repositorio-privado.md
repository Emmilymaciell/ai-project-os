# ADR-0017 — Documentos-modelo e dados de demonstração em repositório privado de projeto

- **Data:** 2026-10-12
- **Status:** Aceita
- **Base:** ADR-0003 (GitHub privado por padrão), ADR-0009 (severidade), ADR-0010 (exceções aprovadas,
  estreitas e citáveis), ADR-0015 (o Git guarda o projeto, o Drive guarda o dado).
- **Decisão da Emmily** (programa vNext, 2026-10-12, §11 e §18: "nenhum projeto elegível deve
  permanecer apenas L1 por falta de um remote se a única barreira é autorização"), aplicada pelo
  Lead com inspeção de conteúdo arquivo a arquivo.

## Contexto

Na varredura pré-push de 2026-10-12 dos repositórios novos da Fase 7, o scanner marcou `MEDIA`
"documento operacional" em arquivos Office que **fazem parte do funcionamento do código**:

| Repositório | Arquivo | O que é (inspecionado) |
|---|---|---|
| `prog-gerador-dossie` | `CAPAS/CAPA DOSSIÊ.docx`, `CAPAS/CAPA GRUPO PROG.docx`, `CAPAS/prog_capa_documento_tecnica_minimalista_escura.docx`, `CAPAS/prog_capa_subsecao_produtos.docx` | modelos de capa usados pelo gerador; autoria Emmily; só títulos genéricos ("Título do Produto", "Descrição do Documento") |
| `prog-indice-produtos` | `modelo_referencia.docx` | modelo de referência do índice; lista títulos de entregáveis da Programa (jan/2026), sem dado pessoal de terceiro |
| `portfolio-empresax-gestao` | `public/demo/Extrato_Banco_Cerrado_DEMO.xlsx`, `public/demo/Extrato_Banco_Horizonte_DEMO.xlsx`, `data/demo/Extrato_Banco_Cerrado_DEMO.xlsx`, `data/demo/Extrato_Banco_Horizonte_DEMO.xlsx` (2 pares idênticos) | extratos de **demonstração**, declarados no próprio arquivo como "DADOS FICTÍCIOS" |

`MEDIA` exige decisão de uma pessoa (ADR-0009). Sem ela, o repositório fica sem remoto, e sem remoto
não passa de L1 — o que contraria a decisão da titular de proteger todo projeto elegível.

## Decisão

1. Cada arquivo acima vira **exceção aprovada do ADR-0010**, no `project.yaml` do próprio
   repositório (`classificacao.dados_sensiveis_excecoes[]`), com caminho **exato** e categoria
   exata. Nada de diretório, curinga ou extensão.
2. O fluxo continua **privado**. Sob `-ParaPublicacao` as exceções não valem (regra 3 do ADR-0010).
   `portfolio-empresax-gestao` é portfólio: qualquer exposição pública continua
   exigindo sanitização e decisão explícita.
3. Dados financeiros **reais** do GF continuam fora do Git (ADR-0015); a exceção cobre só os
   arquivos de demonstração listados.
4. Arquivo Office **novo** nesses repositórios continua bloqueando até nova decisão — é o que
   separa exceção de allowlist.

## Consequências

- Os três repositórios recebem remoto privado e podem chegar a L6.
- O relatório de cada varredura continua listando os achados, na seção "ACEITOS POR EXCEÇÃO".
- Projeto novo criado por `eos new` não herda nenhuma destas exceções.
