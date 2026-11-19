"""Casos da rodada 2: um caso negativo por achado da r1 (QA e Security), e o caso que faltava -
o que PRODUZ o SIM, com remoto de verdade (repositorio bare local) e ls-remote real.
"""
import gzip
import io
import json
import os
import sqlite3
import tarfile
import time
import unittest
from unittest import mock

from eos import backup as bk
from eos import gitinfo, portability, restore
from eos.tests.test_e2e import Base, sh


def _check(t, contrato=None, rede=False):
    return portability.verificar(contrato or t.contrato, t.store, t.maquina, rede=rede)


class TestR2Falsos(Base):
    def test_stash_bloqueia_e_nunca_vira_SIM(self):
        sh(self.proj, "stash", "push", "-q", "-m", "guardado", "--", "app.py")
        m = self._backup()
        self.assertTrue(m.get("incompleto"))
        self.assertTrue(any("stash" in x for x in m["pendencias"]))
        r = _check(self)
        self.assertEqual(r["dimensoes"]["backup"]["status"], "FAIL")
        self.assertIn("stash", r["dimensoes"]["backup"]["motivo"])
        self.assertFalse(r["seguro_apagar_clone"])

    def test_commit_em_head_destacado_depois_do_backup(self):
        sh(self.wt, "add", "-A")
        sh(self.wt, "commit", "-q", "-m", "na feature")
        self._backup()
        sh(self.wt, "checkout", "-q", "--detach")
        with open(os.path.join(self.wt, "solto.txt"), "w") as f:
            f.write("x")
        sh(self.wt, "add", "-A")
        sh(self.wt, "commit", "-q", "-m", "commit destacado")
        r = _check(self)
        self.assertIn("nao esta no ultimo bundle", r["dimensoes"]["backup"]["motivo"])

    def test_repositorio_aninhado_nao_e_protegivel(self):
        sub = os.path.join(self.proj, "vendor", "lib")
        os.makedirs(sub)
        sh(sub, "init", "-q")
        with open(os.path.join(sub, "a.txt"), "w") as f:
            f.write("dentro do aninhado")
        m = self._backup()
        self.assertTrue(any("aninhado" in x for x in m["pendencias"]), m["pendencias"])
        r = _check(self)
        self.assertEqual(r["dimensoes"]["backup"]["status"], "FAIL")
        self.assertIn("aninhado", r["dimensoes"]["backup"]["motivo"])

    def test_banco_em_wal_mudado_depois_do_snapshot(self):
        con = sqlite3.connect(self.db)
        con.execute("pragma journal_mode=wal")
        con.commit()
        con.close()
        self._backup()
        time.sleep(1.1)
        con = sqlite3.connect(self.db)
        con.execute("pragma wal_autocheckpoint=0")
        con.execute("insert into t values (7)")
        con.commit()
        # conexao aberta de proposito: sem checkpoint, o dado novo esta SO no -wal
        try:
            r = _check(self)
            self.assertIn("mudou depois do snapshot", r["dimensoes"]["backup"]["motivo"])
        finally:
            con.close()

    def test_segredo_no_wip_nao_sobe_e_reprova(self):
        with open(os.path.join(self.proj, ".env.local"), "w") as f:
            f.write("API_TOKEN=valor-fabricado\n")
        m = self._backup()
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertNotIn(".env.local", main["arquivos"], "segredo subiu para a nuvem")
        self.assertIn(".env.local", main["nao_enviados"])
        with tarfile.open(os.path.join(self.nuvem, *m["artifacts"]["wip"]["rel"].split("/"))) as tar:
            self.assertFalse(any(n.endswith(".env.local") for n in tar.getnames()))
        r = _check(self)
        self.assertEqual(r["dimensoes"]["secrets"]["status"], "FAIL")
        self.assertIn(".env.local", r["dimensoes"]["secrets"]["motivo"])

    def test_symlink_no_wip_nao_e_protegivel(self):
        alvo = os.path.join(self.proj, "link.txt")
        try:
            os.symlink(os.path.join(self.proj, "app.py"), alvo)
        except (OSError, NotImplementedError):
            self.skipTest("esta maquina nao permite criar symlink sem privilegio")
        m = self._backup()
        self.assertTrue(any("symlink" in x for x in m["pendencias"]))

    def test_banco_declarado_ausente_deixa_backup_incompleto(self):
        self.contrato["state"]["databases"].append({"path": "data/nao-existe.db", "engine": "sqlite"})
        m = self._backup()
        self.assertTrue(m["incompleto"])
        self.assertIn("incompleto", _check(self)["dimensoes"]["backup"]["motivo"])

    def test_env_ponto_qualquer_rastreado_reprova(self):
        with open(os.path.join(self.proj, ".env.production"), "w") as f:
            f.write("X=1\n")
        sh(self.proj, "add", "-f", ".env.production")
        sh(self.proj, "commit", "-q", "-m", "oops")
        self.assertIn(".env.production", _check(self)["dimensoes"]["secrets"]["motivo"])

    def test_caminho_fixo_reprova_paths(self):
        c = dict(self.contrato, workspace={"local_path": self.proj})
        self.assertEqual(_check(self, c)["dimensoes"]["paths"]["status"], "FAIL")

    def test_remoto_extra_ou_pushurl_extra_reprova(self):
        c = dict(self.contrato, git={"enabled": True, "remote": "https://github.com/x/y"})
        sh(self.proj, "remote", "add", "origin", "https://github.com/x/y")
        sh(self.proj, "remote", "set-url", "--add", "--push", "origin", "https://github.com/x/y")
        sh(self.proj, "remote", "set-url", "--add", "--push", "origin", "https://github.com/x/publico")
        self.assertIn("origin aponta", _check(self, c, rede=True)["dimensoes"]["remote"]["motivo"])
        sh(self.proj, "remote", "add", "outro", "https://github.com/x/z")
        self.assertIn("alem de origin", _check(self, c, rede=True)["dimensoes"]["remote"]["motivo"])


class TestR2Restore(Base):
    def _manifesto_adulterado(self, mexe):
        m = self._backup()
        mexe(m)
        return m

    def _restaurar(self, m):
        return restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "r"), manifesto=m, fonte="cloud",
                                 log=lambda *_: None)

    def test_caminho_do_manifesto_com_ponto_ponto_e_recusado_em_todo_campo(self):
        vitima = os.path.join(self.tmp, "vitima.txt")
        with open(vitima, "w") as f:
            f.write("nao pode sumir")
        casos = {
            "removidos": lambda m: m["wip_index"][0]["removidos"].append("../vitima.txt"),
            "arquivos": lambda m: m["wip_index"][0]["arquivos"].update({"../../fora.txt": "0" * 64}),
            "rotulo": lambda m: m["wip_index"][1].update(rotulo="../fora"),
            "db": lambda m: m["databases"][0].update(path="../fora.db"),
            "absoluto": lambda m: m["wip_index"][0]["arquivos"].update({"C:/Windows/x.txt": "0" * 64}),
            "head": lambda m: m.update(head="HEAD; rm -rf /"),
        }
        for nome, mexe in casos.items():
            m = self._manifesto_adulterado(mexe)
            with self.assertRaises(restore.RestoreErro, msg=nome):
                self._restaurar(m)
            gitinfo.remover_arvore(os.path.join(self.tmp, "r"))
            self.assertTrue(os.path.isfile(vitima), "o restore apagou arquivo fora do destino (%s)" % nome)
            self.assertFalse(os.path.exists(os.path.join(self.tmp, "fora.txt")))

    def test_tar_com_membro_que_escapa_e_recusado(self):
        m = self._backup()
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w:gz") as tar:
            info = tarfile.TarInfo("../escapou.txt")
            info.size = 1
            tar.addfile(info, io.BytesIO(b"x"))
        p = os.path.join(self.nuvem, *m["artifacts"]["wip"]["rel"].split("/"))
        with open(p, "wb") as f:
            f.write(buf.getvalue())
        m["artifacts"]["wip"]["sha256"] = gitinfo.sha256_arquivo(p)  # atacante controla manifesto e hash
        with self.assertRaisesRegex(restore.RestoreErro, "suspeito"):
            self._restaurar(m)
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "escapou.txt")))


class TestR2Sim(Base):
    """O caso que a r1 mostrou que nao existia: o motor dizendo SIM, com tudo medido."""

    def setUp(self):
        super().setUp()
        self.bare = os.path.join(self.tmp, "remoto.git")
        sh(self.tmp, "init", "-q", "--bare", self.bare)
        sh(self.proj, "remote", "add", "origin", self.bare)
        sh(self.proj, "push", "-q", "origin", "main", "feature")
        self.contrato["git"] = {"enabled": True, "remote": self.bare}
        self.vis = mock.patch.object(portability, "_visibilidade_github", lambda url: "private")
        self.vis.start()

    def tearDown(self):
        self.vis.stop()
        super().tearDown()

    def test_tudo_protegido_produz_SIM_e_L5(self):
        self._backup()
        r = _check(self, rede=True)
        self.assertEqual(r["dimensoes"]["remote"]["status"], "PASS", r["dimensoes"]["remote"])
        self.assertEqual(r["nivel"], "L5", json.dumps(r["dimensoes"], indent=1))
        self.assertTrue(r["seguro_apagar_clone"], r["motivos_nao"])
        self.assertTrue(r["seguro_trocar_computador"])
        self.assertEqual(r["safety"], "SAFE")

    def test_branch_nao_publicada_derruba_L2(self):
        sh(self.proj, "branch", "so-local")
        self._backup()
        r = _check(self, rede=True)
        self.assertEqual(r["dimensoes"]["remote"]["status"], "FAIL")
        self.assertIn("refs/heads/so-local", r["dimensoes"]["remote"]["faltam"])
        self.assertFalse(r["seguro_apagar_clone"])

    def test_ignorado_nao_declarado_impede_o_SIM_do_clone(self):
        with open(os.path.join(self.proj, ".gitignore"), "a") as f:
            f.write("saidas/\n")
        sh(self.proj, "add", ".gitignore")
        sh(self.proj, "commit", "-q", "-m", "ignora saidas")
        sh(self.proj, "push", "-q", "origin", "main")
        os.makedirs(os.path.join(self.proj, "saidas"))
        with open(os.path.join(self.proj, "saidas", "relatorio.pdf"), "w") as f:
            f.write("so existe aqui")
        self._backup()
        r = _check(self, rede=True)
        self.assertGreaterEqual(int(r["nivel"][1]), 3)
        self.assertFalse(r["seguro_apagar_clone"])
        self.assertTrue(any("saidas/relatorio.pdf" in x for x in r["motivos_nao"]["clone"]), r["motivos_nao"])

    def test_env_local_com_store_local_impede_o_SIM_do_clone(self):
        with open(os.path.join(self.proj, ".gitignore"), "a") as f:
            f.write(".env\n")
        sh(self.proj, "add", ".gitignore")
        sh(self.proj, "commit", "-q", "-m", "ignora env")
        sh(self.proj, "push", "-q", "origin", "main")
        with open(os.path.join(self.proj, ".env"), "w") as f:
            f.write("API_TOKEN=valor-fabricado\n")
        self._backup()
        r = _check(self, rede=True)
        self.assertFalse(r["seguro_apagar_clone"])
        self.assertTrue(any("cofre" in x for x in r["motivos_nao"]["clone"]))

    def test_restore_pelo_remoto_completa_refs_pelo_bundle(self):
        sh(self.proj, "branch", "so-no-bundle")
        self._backup()
        dst = os.path.join(self.tmp, "via-remoto")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="auto", log=lambda *_: None)
        self.assertTrue(rel["ok"], rel["verificacoes"])
        self.assertTrue(any(f.startswith("github:") for f in rel["fontes"]))
        self.assertIn("refs/heads/so-no-bundle", gitinfo.refs(dst))


if __name__ == "__main__":
    unittest.main()
