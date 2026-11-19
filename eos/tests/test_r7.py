"""Casos da rodada 7: respostas aos vereditos da r6 (QA REPROVADO, Security APROVADO com BAIXA).

  01  QA achado 1 (MEDIA): arquivo movido com `mv` + `git add -N` sai do `git status` como renomeacao
      NA ARVORE (' R novo\\0velho', coluna Y). O parser lia o par como duas linhas e o backup abortava.
  02  QA achado 2 (BAIXA): a impressao do WIP nao via o intent-to-add; um manifesto sem `intencao`
      (anterior a r6) restaurava com o arquivo como '??' e passava em silencio.
  03  Security obs. 2: caractere de controle no caminho e recusado pelo restore, nao pelo git/Windows.
  04  Security obs. 1: `git add -N` (como o restore o chama) nao roda filtro `clean`. Premissa do Git,
      provada com controle positivo.
  05  QA achado 3 (BAIXA): intent-to-add apagado do disco falha FECHADO no restore (documentado).
"""
import os

from eos import gitinfo, restore
from eos.tests.test_e2e import Base, sh


def _verif(rel):
    return {v["o_que"]: v["ok"] for v in rel["verificacoes"]}


class TestR7(Base):
    def _backup_sem_abortar(self):
        try:
            return self._backup()
        except Exception as e:  # o caso tem de FALHAR (nao dar ERROR) quando o parser regride
            self.fail("o backup abortou: %r" % e)

    def test_01_mv_mais_intent_to_add_nao_derruba_o_backup(self):
        conteudo = "".join("linha %d do arquivo movido\n" % i for i in range(30))
        self._w("velho.py", conteudo)
        sh(self.proj, "add", "velho.py")
        sh(self.proj, "commit", "-qm", "velho")
        os.replace(os.path.join(self.proj, "velho.py"), os.path.join(self.proj, "novo.py"))
        sh(self.proj, "add", "-N", "novo.py")
        st0 = sh(self.proj, "status", "--porcelain", "-z")
        self.assertIn(" R novo.py\0velho.py\0", st0, "premissa: renomeacao na arvore (coluna Y)")
        m = self._backup_sem_abortar()
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertIn("novo.py", main["intencao"])
        self.assertIn("velho.py", main["removidos"])
        dst = os.path.join(self.tmp, "r7-01")
        rel = restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
        # '.eos-worktrees/' e onde o restore poe as worktrees ligadas da Base: fora da comparacao
        st = sh(dst, "status", "--porcelain", "-z").replace("?? .eos-worktrees/\0", "")
        self.assertEqual(st, st0, "o destino nao reproduz o status da origem")
        falhas = [o for o, ok in _verif(rel).items() if not ok]
        self.assertEqual(falhas, [], "verificacoes do restore falharam: %s" % falhas)

    def test_02_manifesto_sem_intencao_nao_passa_em_silencio(self):
        # WIP da Base commitado (fixture temporaria): com o intent-to-add como UNICO item, a lista
        # concatenada modificados+nao_rastreados e a mesma quando ele e ' A' e quando volta '??'.
        # So a intencao dentro da impressao distingue os dois estados
        sh(self.proj, "add", "-A")
        sh(self.proj, "commit", "-qm", "limpa o WIP da fixture")
        self.assertEqual(sh(self.proj, "status", "--porcelain").strip(), "", "premissa: arvore limpa")
        self._w("b_ita.py", "k = 1\n")
        sh(self.proj, "add", "-N", "b_ita.py")
        w0 = gitinfo.wip(self.proj)
        m = self._backup()
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertEqual(main["intencao"], ["b_ita.py"], "premissa")
        main["intencao"] = []  # como um manifesto de antes da r6
        dst = os.path.join(self.tmp, "r7-02")
        rel = restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
        self.assertIn("?? b_ita.py", sh(dst, "status", "--porcelain"), "premissa: voltou como nao rastreado")
        w1 = gitinfo.wip(dst)
        self.assertEqual(w0["modificados"] + w0["nao_rastreados"],
                         [x for x in w1["modificados"] + w1["nao_rastreados"] if not x.startswith(".eos-worktrees")],
                         "premissa: a ordem concatenada e a mesma (o caso cego que o QA apontou)")
        self.assertFalse(_verif(rel)["impressao do WIP de 'main' igual a do manifesto"],
                         "o restore aprovou um intent-to-add que voltou como '??'")
        self.assertFalse(rel["ok"])

    def test_03_caractere_de_controle_e_recusado_pelo_restore(self):
        for ruim in ("a\nb.py", "a\rb.py", "a\tb.py", "a\x1fb.py", "a\x7fb.py", "a\x00b.py"):
            with self.subTest(caminho=repr(ruim)):
                with self.assertRaises(restore.RestoreErro):
                    restore._caminho_seguro(self.tmp, ruim)
        self.assertTrue(restore._caminho_seguro(self.tmp, "normal.py").endswith("normal.py"))

    def test_04_add_intent_to_add_nao_roda_filtro_clean(self):
        repo = os.path.join(self.tmp, "r7-04")
        os.makedirs(repo)
        sh(repo, "init", "-q", "-b", "main")
        marca = os.path.join(repo, "MARCADOR").replace("\\", "/")
        sh(repo, "config", "filter.marca.clean", "echo rodou > '%s' && cat" % marca)
        sh(repo, "config", "filter.marca.required", "true")
        self._w(".gitattributes", "*.dat filter=marca\n", base=repo)
        self._w("x.dat", "dado\n", base=repo)
        self._w("y.dat", "dado\n", base=repo)
        gitinfo.git(repo, "add", "--intent-to-add", "--", ":(literal)x.dat")
        self.assertFalse(os.path.exists(marca), "o -N rodou o filtro clean")
        gitinfo.git(repo, "add", "--", ":(literal)y.dat")  # controle positivo: o filtro esta ligado
        self.assertTrue(os.path.exists(marca), "controle: o add normal deveria rodar o filtro")

    def test_05_intent_to_add_apagado_falha_fechado(self):
        self._w("sumiu.py", "z = 9\n")
        sh(self.proj, "add", "-N", "sumiu.py")
        os.remove(os.path.join(self.proj, "sumiu.py"))
        self.assertIn(" D sumiu.py", sh(self.proj, "status", "--porcelain"), "premissa")
        m = self._backup()
        dst = os.path.join(self.tmp, "r7-05")
        rel = restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
        # o caminho nao existe no indice do destino: a impressao diverge e o restore NAO se declara ok
        self.assertFalse(rel["ok"], "intent-to-add apagado passou como restaurado")
