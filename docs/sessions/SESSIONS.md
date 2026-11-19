# Sessões

Mais recente no topo. Formato e regras em [README.md](README.md). Escrito pelo `/session-close`, lido pelo `/session-start`.

---

> **Versão pública:** os blocos das sessões 1 a 4 foram omitidos (citavam projetos e caminhos privados). O bloco abaixo fica como exemplo real do formato, já sanitizado.

## 5 — Decisões da titular e execução dos gates · 2026-10-16

- **Objetivo:** executar as decisões da titular sobre os gates do `FINAL-ACCEPTANCE`
  (`SURGE/decisoes-20261016.md`) e atualizar a documentação para o estado real.
- **HEAD inicial:** `3335fc3` (main) · `vnext` até `566ee74` e o commit de docs que traz este registro.
- **Concluído:**
  - rclone com client OAuth próprio (`emmily-os-rclone`, *In production*, ADR-0019 para as páginas públicas);
    `gdrive:` mantido, `gdrive-legacy` removido; leitura, escrita, backup, certify L6 e mirror sem aviso.
  - H4 Escritório Jurídico: MANTER no Drive; os dois projetos L6 SAFE com três SIM.
  - GF: SWITCH (base 641/641 DEMO conferida pelo Backup da Base da titular; certify L6); IndexedDB copiado ao Drive.
  - Fase 9 pelo H2: 35 worktrees (G2 28, Cérebro 7; 6 KEEP), E3 na lixeira do Drive, D1 47 + D6 18 cópias e o exe
    do Gerador removidos com sha256 no momento; D4 KEEP.
  - Guarda `PreToolUse` contra git destrutivo (`hooks/guarda_git.py`, plugin 0.1.1 na época; hoje 0.1.4) integrado na `vnext`.
    Rodada 1 (`9f248ca`): QA REPROVADO (falso negativo PowerShell com `-ExecutionPolicy Bypass`, registro
    `hooks: 0`, risco de saída 2), Security INCONCLUSIVO; correção `4a4508f`. r14 sobre `0b43992`: coleta 504/504,
    `unittest` Ran 371 OK (skipped=1), security completo ALTA 0; Security APROVADO, QA REPROVADO só por registro
    (plugin `0.2.0` contra ADR-0006, cofre com três nomes, rodadas não registradas) e itens BAIXA do guarda —
    corrigidos na r15 (plugin `0.1.1` + emenda do ADR-0006). r15 sobre `de2c933`: Security APROVADO, QA REPROVADO
    só por registro (CHANGELOG, TECHNICAL-REFERENCE) e 2 falsos negativos BAIXA, corrigidos na r16 (`e53717d`,
    `5d32fcc`); r16: Security APROVADO, QA REPROVADO só por registro (manuais 02/06/14, STATE, TR, SESSIONS),
    corrigido em seguida.
  - Docs atualizadas (ADR-0013 emenda, manuais 02/06/08/09/12/13/14/15, referência técnica, runbook, SETUP, STATE).
- **Decisões:** ADR-0019; ADR-0010 (emenda 2026-10-16, nome de terceiro em engenharia-rodoviaria); ADR-0006 (emenda
  2026-10-16, PATCH do plugin entre tags); e-mail de 28/08 = `EXTERNAL_EVIDENCE_PENDING_VERIFICATION`.
- **Validação:** por item no journal (`CHECKPOINTS/rclone-own-*`, `gf-*-20261016`, `worktrees-remocao-20261016.txt`,
  `h2-duplicatas-remocao*`); coletas completas r14 (`0b43992`) e r16 (`5d32fcc`), ambas verdes.
- **Fechamento:** integração na `main` por fast-forward + push (`ef5a1d9`, verified); a primeira aceitação COMPLETE (`198ddee`) foi
  reprovada pelo QA; o teste ao vivo da guarda levou a `0.1.2`–`0.1.4` (r17, r18: código aprovado por QA e
  Security; registro corrigido em `d6d85ce`); plataforma recertificada L6 SAFE; `FINAL-ACCEPTANCE` reemitido
  **COMPLETE**. Pendente só a conferência do token do rclone em 2026-10-23 ou depois.
- **Próximo passo:** o "Próximo passo" do `docs/STATE.md`.

