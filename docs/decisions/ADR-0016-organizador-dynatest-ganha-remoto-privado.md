# ADR-0016 — O Organizador Dynatest ganha remoto privado no GitHub

- **Data:** 2026-10-11
- **Status:** Aceita
- **Substitui:** o ADR-0002 **na parte "sem remoto"**. O ADR-0002 não é apagado nem reescrito: o
  contexto dele continua verdadeiro e é a história desta decisão.

## Contexto

O ADR-0002 (2026-09-05) preservou o repositório `Organizador_Dynatest_Pessoal` dentro do OneDrive,
sem remoto. Era a forma de levar o projeto às duas máquinas da mantenedora, com mitigação testada:
`gc.auto=0`, `maintenance.auto=false` e um `backups/historico.bundle` em arquivo único. A
alternativa "mover e resolver as duas máquinas via GitHub privado" foi **adiada, não rejeitada**,
e o próprio ADR-0002 fixou o gatilho de revisão: "quando o GitHub privado estiver operante", com a
ressalva de que essa revisão gera ADR novo.

O gatilho disparou. O GitHub privado está operante desde a Fase 1. Em 2026-10-11 a mantenedora
autorizou explicitamente remoto privado para todos os projetos, citando o Organizador e este caso.

## Decisão

1. O Organizador recebe remoto **privado** no GitHub pessoal. A varredura de histórico de 2026-10-08
   deu zero `ALTA` e zero `MEDIA`, então o push vai direto, sem sanitização (ADR-0015).
2. **A pasta continua onde está, no OneDrive.** Mover é outra decisão, porque quebraria caminhos e o
   uso nas duas máquinas sem que o remoto, sozinho, resolva a segunda máquina. As mitigações do
   ADR-0002 continuam ativas.
3. A regra do `CLAUDE.md` do projeto ("Não sincroniza nem sobe nada. Git local, sem remoto") passa a
   estar **superada por este ADR** no que diz respeito ao remoto. Quem trabalha no projeto deve ler
   os dois.

## Consequências

- O histórico passa a ter cópia fora da máquina e fora do OneDrive.
- Gatilho de revisão: quando a segunda máquina passar a clonar do GitHub em vez de usar a pasta
  sincronizada, a mudança de pasta para fora do OneDrive vira um ADR novo.
