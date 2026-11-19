"""Casos da rodada 6: defeitos achados pela CERTIFICACAO de projetos reais (Fase 8, 2026-10-11).

  01  intent-to-add (`git add -N`): o G2 tinha 3 arquivos assim numa worktree. O restore os trazia
      como nao rastreados ('??' em vez de ' A'), e a impressao do WIP divergia: a certificacao
      reprovou com "impressao do WIP de 'agent-a3ad82...' igual a do manifesto" FALHOU.
  01b na worktree ligada; 01c caminho hostil recusado PELO RESTORE (nao pelo git); 01d intencao
      malformada recusada na validacao; 01e nome de segredo fora da intencao; 01f pathspec literal.
"""
import os

from eos import restore
from eos.tests.test_e2e import Base, sh


class TestR6IntentToAdd(Base):
    def test_01_intent_to_add_volta_como_intent_to_add(self):
        self._w("novo_ita.py", "print('ita')\n")
        sh(self.proj, "add", "-N", "novo_ita.py")
        self.assertIn(" A novo_ita.py", sh(self.proj, "status", "--porcelain"), "premissa: status ' A'")
        m = self._backup()
        dst = os.path.join(self.tmp, "r6-01")
        rel = restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
        st = sh(dst, "status", "--porcelain")
        self.assertIn(" A novo_ita.py", st, "o intent-to-add nao voltou como ' A':\n%s" % st)
        falhas = [v["o_que"] for v in rel["verificacoes"] if not v["ok"]]
        self.assertEqual(falhas, [], "verificacoes do restore falharam: %s" % falhas)

    def test_01b_intent_to_add_em_worktree_ligada(self):
        # 'zz_' de proposito: na worktree ja ha 'novo.txt' nao rastreado, e so com o intent-to-add
        # ordenado DEPOIS dele a troca de lista ('modificados' -> 'nao_rastreados') muda a impressao
        self._w("zz_ita.py", "x = 1\n", base=self.wt)
        sh(self.wt, "add", "-N", "zz_ita.py")
        m = self._backup()
        dst = os.path.join(self.tmp, "r6-01b")
        rel = restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
        wt = os.path.join(dst, ".eos-worktrees")
        st = sh(os.path.join(wt, os.listdir(wt)[0]), "status", "--porcelain")
        self.assertIn(" A zz_ita.py", st, "o intent-to-add da worktree nao voltou como ' A':\n%s" % st)
        falhas = [v["o_que"] for v in rel["verificacoes"] if not v["ok"]]
        self.assertEqual(falhas, [], "verificacoes do restore falharam: %s" % falhas)

    def test_01c_intencao_com_caminho_hostil_e_recusada(self):
        self._w("ok.py", "y = 2\n")
        sh(self.proj, "add", "-N", "ok.py")
        m = self._backup()
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertIn("ok.py", main.get("intencao", []), "premissa: o manifesto registra a intencao")
        main["intencao"] = ["../fora.py"]
        # Exception + isinstance de proposito: sem a guarda, quem recusa e o proprio git (GitErro), e o
        # caso precisa FALHAR, nao dar ERROR - a recusa tem de ser do restore, antes de chamar o git
        with self.assertRaises(Exception) as cm:
            restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "r6-01c"), manifesto=m,
                              fonte="cloud", log=lambda *_: None)
        self.assertIsInstance(cm.exception, restore.RestoreErro, "quem recusou: %r" % cm.exception)

    def test_01d_intencao_malformada_e_recusada_na_validacao(self):
        self._w("ok.py", "y = 2\n")
        sh(self.proj, "add", "-N", "ok.py")
        m = self._backup()
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        main["intencao"] = "ok.py"  # texto, nao lista: iterar daria 'o', 'k', '.', ...
        with self.assertRaises(Exception) as cm:
            restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "r6-01d"), manifesto=m,
                              fonte="cloud", log=lambda *_: None)
        self.assertIsInstance(cm.exception, restore.RestoreErro, "quem recusou: %r" % cm.exception)
        self.assertIn("intencao", str(cm.exception))

    def test_01e_intencao_com_nome_de_segredo_nao_entra_no_manifesto(self):
        # o arquivo nao sobe (nao_enviados); listar a intencao faria o restore pedir -N de um arquivo
        # que nao existe no destino
        self._w("token.txt", "nao-e-segredo-de-verdade\n")
        sh(self.proj, "add", "-N", "token.txt")
        m = self._backup()
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertIn("token.txt", main["nao_enviados"], "premissa: o nome conta como segredo")
        self.assertNotIn("token.txt", main["intencao"])

    def test_01f_intencao_com_colchete_e_literal_nao_curinga(self):
        # 'a[1].py' como curinga casaria tambem 'a1.py' (nao rastreado), que viraria ' A' no destino
        self._w("a[1].py", "z = 3\n")
        self._w("a1.py", "w = 4\n")
        sh(self.proj, "add", "-N", "--", ":(literal)a[1].py")
        st0 = sh(self.proj, "status", "--porcelain")
        self.assertIn("?? a1.py", st0, "premissa: a1.py nao rastreado na origem:\n%s" % st0)
        m = self._backup()
        dst = os.path.join(self.tmp, "r6-01f")
        rel = restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
        st = sh(dst, "status", "--porcelain")
        self.assertIn("?? a1.py", st, "a1.py mudou de estado no destino:\n%s" % st)
        falhas = [v["o_que"] for v in rel["verificacoes"] if not v["ok"]]
        self.assertEqual(falhas, [], "verificacoes do restore falharam: %s" % falhas)
