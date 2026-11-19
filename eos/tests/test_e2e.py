"""Ciclo real sobre repositorios Git temporarios e nuvem em diretorio (DirStore).

Cada caso negativo existe porque o positivo sozinho passaria com um motor que nao protege
nada: "o backup rodou sem erro" nao prova que o WIP esta na nuvem.
"""
import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import unittest

from eos import backup as bk
from eos import cloud, gitinfo, portability, restore


def sh(cwd, *args):
    r = subprocess.run(["git", "-c", "core.autocrlf=false", *args], cwd=cwd, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode())
    return r.stdout.decode()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="eos-t-"))
        self.proj = os.path.join(self.tmp, "proj")
        self.nuvem = os.path.join(self.tmp, "nuvem")
        os.makedirs(self.proj)
        sh(self.proj, "init", "-q", "-b", "main")
        sh(self.proj, "config", "user.email", "t@t")
        sh(self.proj, "config", "user.name", "t")
        sh(self.proj, "config", "core.autocrlf", "false")
        # o .gitignore_global desta maquina ignora .env*: sem isolar, os casos de segredo no WIP
        # nunca chegariam ao cenario que dizem testar (runbook de armadilhas)
        sh(self.proj, "config", "core.excludesfile", os.path.join(self.tmp, "sem-excludes-global"))
        os.makedirs(os.path.join(self.proj, "docs"))
        self._w("docs/STATE.md", "estado\n")
        self._w("app.py", "print(1)\n")
        self._w("requirements.txt", "")
        self._w("secrets.manifest", "API_TOKEN\n")
        self._w(".gitignore", "data/\n.venv/\n")
        sh(self.proj, "add", "-A")
        sh(self.proj, "commit", "-q", "-m", "c1")
        sh(self.proj, "branch", "feature")
        # worktree com trabalho nao commitado
        self.wt = os.path.join(self.tmp, "wt-feature")
        sh(self.proj, "worktree", "add", "-q", self.wt, "feature")
        with open(os.path.join(self.wt, "novo.txt"), "w") as f:
            f.write("trabalho da worktree\n")
        # banco ignorado pelo git
        os.makedirs(os.path.join(self.proj, "data"))
        self.db = os.path.join(self.proj, "data", "x.db")
        con = sqlite3.connect(self.db)
        con.execute("create table t (v integer)")
        con.executemany("insert into t values (?)", [(i,) for i in range(500)])
        con.commit()
        con.close()
        # WIP na arvore principal: modificado, staged e nao rastreado
        self._w("app.py", "print(2)\n")
        self._w("staged.txt", "no index\n")
        sh(self.proj, "add", "staged.txt")
        self._w("rascunho.md", "ideia\n")
        os.makedirs(os.path.join(self.proj, ".venv"))
        self._w(".venv/lixo.txt", "nao copiar\n")
        self.maquina = {"_arquivo": "teste", "vars": {"T": self.tmp}, "projects": {}}
        self.store = cloud.DirStore(self.nuvem)
        self.contrato = {
            "contract_version": 1,
            "identity": {"id": "proj", "name": "P", "type": "PROJECT", "category": "LAB", "status": "active", "criticality": "low"},
            "workspace": {"local_path": "${T}/proj"},
            "git": {"enabled": True, "remote": ""},
            "cloud": {"drive_root": "05 LAB/proj"},
            "state": {"strategy": "sqlite", "databases": [{"path": "data/x.db", "engine": "sqlite"}]},
            "environment": {"runtime": "python", "manifest": "requirements.txt", "bootstrap": "echo ok",
                            "smoke_command": "if (Test-Path app.py) { exit 0 } else { exit 3 }"},
            "secrets": {"manifest": "secrets.manifest", "store": "local-env"},
            "backup": {"wip": "snapshot"},
            "ai": {"canonical": ["docs/STATE.md"]},
            "portability": {"target_level": "L6"},
        }

    def tearDown(self):
        subprocess.run(["git", "worktree", "prune"], cwd=self.proj, capture_output=True)
        self.assertTrue(gitinfo.remover_arvore(self.tmp), "o teste deixou lixo em %s" % self.tmp)

    def _w(self, rel, txt, base=None):
        p = os.path.join(base or self.proj, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", newline="\n") as f:
            f.write(txt)

    @staticmethod
    def _r(p):
        with open(p, encoding="utf-8") as f:
            return f.read()

    def _backup(self):
        return bk.backup(self.contrato, self.store, self.maquina, staging=os.path.join(self.tmp, "stg"), log=lambda *_: None)


class TestBackupRestore(Base):
    def test_backup_cobre_refs_wip_de_todas_as_worktrees_e_banco(self):
        m = self._backup()
        self.assertIn("git_bundle", m["artifacts"])
        self.assertIn("wip", m["artifacts"])
        rotulos = {w["rotulo"] for w in m["wip_index"]}
        self.assertEqual(rotulos, {"main", "wt-feature"})
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertIn("app.py", main["arquivos"])
        self.assertIn("rascunho.md", main["arquivos"])
        self.assertIn("staged.txt", main["arquivos"])
        self.assertFalse(any(k.startswith(".venv/") for k in main["arquivos"]), "excluido entrou no snapshot")
        self.assertEqual(m["databases"][0]["integrity_check"], "ok")
        self.assertTrue(self.store.existe("99 RECOVERY/manifests/proj/%s.json" % m["timestamp"]))

    def test_restore_isolado_reproduz_tudo_e_verifica_por_fato(self):
        self._backup()
        dst = os.path.join(self.tmp, "restaurado")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None)
        self.assertTrue(rel["ok"], json.dumps(rel["verificacoes"], indent=1))
        self.assertEqual(self._r(os.path.join(dst, "app.py")), "print(2)\n")
        self.assertEqual(self._r(os.path.join(dst, "rascunho.md")), "ideia\n")
        staged = sh(dst, "diff", "--cached", "--name-only").split()
        self.assertEqual(staged, ["staged.txt"], "o estado do index nao foi restaurado")
        wt = os.path.join(dst, ".eos-worktrees", "wt-feature", "novo.txt")
        self.assertEqual(self._r(wt), "trabalho da worktree\n")
        con = sqlite3.connect(os.path.join(dst, "data", "x.db"))
        self.assertEqual(con.execute("select count(*) from t").fetchone()[0], 500)
        con.close()
        self.assertIn("refs/heads/feature", gitinfo.refs(dst))

    def test_restore_recusa_destino_nao_vazio(self):
        self._backup()
        dst = os.path.join(self.tmp, "ocupado")
        self._w("x.txt", "existe", base=dst)
        with self.assertRaisesRegex(restore.RestoreErro, "nao esta vazio"):
            restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None)

    def test_restore_recusa_artefato_adulterado(self):
        m = self._backup()
        p = os.path.join(self.nuvem, *m["artifacts"]["wip"]["rel"].split("/"))
        with open(p, "ab") as f:
            f.write(b"x")
        with self.assertRaisesRegex(restore.RestoreErro, "hash divergente"):
            restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "r2"), fonte="cloud", log=lambda *_: None)

    def test_backup_sem_manifesto_nao_conta(self):
        # artefato orfao (execucao interrompida antes do ponto de commit) nao e backup
        self.store.escrever_texto("99 RECOVERY/git-recovery/proj/20990101T000000Z/proj.bundle", "x")
        self.assertIsNone(bk.ultimo_manifesto(self.store, "proj"))


class TestCheck(Base):
    def _check(self):
        return portability.verificar(self.contrato, self.store, self.maquina, rede=False)

    def test_sem_backup_nao_e_seguro_apagar_nada(self):
        r = self._check()
        self.assertEqual(r["nivel"], "L1")
        self.assertFalse(r["seguro_apagar_clone"])
        self.assertFalse(r["seguro_apagar_sessao"], "WIP sem snapshot nao pode liberar a sessao")
        self.assertEqual(r["safety"], "AT_RISK")

    def test_sem_remoto_para_em_L1_mesmo_com_backup(self):
        self._backup()
        r = self._check()
        self.assertEqual(r["nivel"], "L1")
        self.assertEqual(r["dimensoes"]["backup"]["status"], "PASS")
        self.assertTrue(r["seguro_apagar_sessao"], "estado presente e WIP protegido")
        self.assertFalse(r["seguro_trocar_computador"])

    def test_wip_mudado_depois_do_backup_invalida_a_protecao(self):
        self._backup()
        self._w("rascunho.md", "ideia NOVA\n")
        r = self._check()
        self.assertEqual(r["dimensoes"]["backup"]["status"], "FAIL")
        self.assertIn("WIP", r["dimensoes"]["backup"]["motivo"])
        self.assertFalse(r["seguro_apagar_sessao"])

    def test_wip_da_worktree_mudado_tambem(self):
        self._backup()
        self._w("novo.txt", "outro\n", base=self.wt)
        self.assertEqual(self._check()["dimensoes"]["backup"]["status"], "FAIL")

    def test_commit_novo_invalida_o_bundle(self):
        self._backup()
        sh(self.proj, "add", "-A")
        sh(self.proj, "commit", "-q", "-m", "c2")
        self.assertIn("refs mudaram", self._check()["dimensoes"]["backup"]["motivo"])

    def test_banco_mudado_depois_do_snapshot(self):
        self._backup()
        import time
        time.sleep(1.2)
        con = sqlite3.connect(self.db)
        con.execute("insert into t values (9999)")
        con.commit()
        con.close()
        self.assertIn("mudou depois do snapshot", self._check()["dimensoes"]["backup"]["motivo"])

    def test_unborn_nao_passa_de_L0(self):
        os.makedirs(os.path.join(self.tmp, "u"))
        sh(os.path.join(self.tmp, "u"), "init", "-q")
        c = dict(self.contrato, workspace={"local_path": "${T}/u"}, state={"strategy": "git-only"})
        r = portability.verificar(c, self.store, self.maquina, rede=False)
        self.assertEqual(r["nivel"], "L0")
        self.assertIn("unborn", r["dimensoes"]["git"]["motivo"])
        self.assertEqual(r["safety"], "UNSAFE")

    def test_env_rastreado_reprova_secrets(self):
        self._w(".env", "API_TOKEN=valor-falso\n")
        sh(self.proj, "add", "-f", ".env")
        sh(self.proj, "commit", "-q", "-m", "oops")
        self.assertIn("RASTREADO", self._check()["dimensoes"]["secrets"]["motivo"])

    def test_fonte_externa_fora_derruba_operacao_e_nao_seguranca(self):
        self._backup()
        c = dict(self.contrato, external_sources=[{"id": "sp", "type": "sharepoint", "role": "source_documents",
                                                     "required_for_operation": True, "location": "${T}/nao-existe"}])
        r = portability.verificar(c, self.store, self.maquina, rede=False)
        self.assertEqual(r["operation"], "DEGRADED")
        self.assertIn("sp", r["operation_motivo"])


class TestCertify(Base):
    def test_certificacao_restaura_isolado_e_roda_smoke(self):
        self._backup()
        c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertTrue(c["ok"], json.dumps(c, indent=1, default=str)[:3000])
        self.assertTrue(c["destino_removido"])
        self.assertFalse(os.path.exists(c["destino"]))
        self.assertIsNotNone(bk.ultima_certificacao(self.store, "proj"))

    def test_certificacao_sem_smoke_declarado_reprova(self):
        self._backup()
        self.contrato["environment"].pop("smoke_command")
        c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertFalse(c["ok"])

    def test_certificacao_com_smoke_falhando_reprova(self):
        self._backup()
        self.contrato["environment"]["smoke_command"] = "exit 7"
        c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertFalse(c["ok"])
        self.assertEqual(c["smoke"]["rc"], 7)


if __name__ == "__main__":
    unittest.main()
