"""Casos da rodada 3: um caso por achado da r2 (QA e Security)."""
import gzip
import json
import os
import subprocess
import tarfile
import unittest
from unittest import mock

from eos import backup as bk
from eos import gitinfo, portability, restore
from eos.tests.test_e2e import Base, sh
from eos.tests.test_r2 import _check

VALOR = "VALOR-FABRICADO-QUE-NAO-PODE-SUBIR-7f3a9c"


def _bytes_do_tar(caminho):
    """Todo o conteudo de todos os membros do tar, concatenado."""
    out = b""
    with tarfile.open(caminho, "r:gz") as tar:
        for m in tar.getmembers():
            if m.isfile():
                out += m.name.encode() + b"\n" + tar.extractfile(m).read()
    return out


class TestR3Seguranca(Base):
    def _tar(self, m):
        return os.path.join(self.nuvem, *m["artifacts"]["wip"]["rel"].split("/"))

    def test_segredo_STAGED_nao_sobe_nem_no_patch(self):
        with open(os.path.join(self.proj, ".env"), "w") as f:
            f.write("API_TOKEN=%s\n" % VALOR)
        sh(self.proj, "add", "-f", ".env")
        m = self._backup()
        self.assertNotIn(VALOR.encode(), _bytes_do_tar(self._tar(m)), "o valor do segredo staged subiu no tar")
        self.assertTrue(any(".env" in x for x in m["pendencias"]))

    def test_segredo_RASTREADO_e_modificado_nao_sobe_no_patch(self):
        with open(os.path.join(self.proj, "credentials.json"), "w") as f:
            f.write('{"k": "antigo"}\n')
        sh(self.proj, "add", "credentials.json")
        sh(self.proj, "commit", "-q", "-m", "cred")
        with open(os.path.join(self.proj, "credentials.json"), "w") as f:
            f.write('{"k": "%s"}\n' % VALOR)
        m = self._backup()
        self.assertNotIn(VALOR.encode(), _bytes_do_tar(self._tar(m)))
        self.assertIn("credentials.json", _check(self)["dimensoes"]["secrets"]["motivo"])

    def test_stash_fica_fora_do_bundle(self):
        with open(os.path.join(self.proj, "x.txt"), "w") as f:
            f.write(VALOR)
        sh(self.proj, "stash", "push", "-q", "-u")
        m = self._backup()
        b = os.path.join(self.tmp, "b.bundle")
        self.store.get(m["artifacts"]["git_bundle"]["rel"], b)
        heads = sh(self.proj, "bundle", "list-heads", b)
        self.assertNotIn("refs/stash", heads)
        self.assertNotIn("refs/stash", m["refs"])

    def test_nome_reservado_do_windows_e_recusado_no_restore(self):
        # cenario real: o atacante controla o tar E o manifesto (o manifesto nao e assinado)
        m = self._backup()
        tar_p = self._tar(m)
        novo = tar_p + ".novo"
        with tarfile.open(tar_p, "r:gz") as velho, tarfile.open(novo, "w:gz") as tar:
            for mb in velho.getmembers():
                tar.addfile(mb, velho.extractfile(mb) if mb.isfile() else None)
            import io
            info = tarfile.TarInfo("main/files/NUL.txt")
            info.size = 4
            tar.addfile(info, io.BytesIO(b"nulo"))
        os.replace(novo, tar_p)
        m["artifacts"]["wip"]["sha256"] = gitinfo.sha256_arquivo(tar_p)
        import hashlib
        m["wip_index"][0]["arquivos"]["NUL.txt"] = hashlib.sha256(b"nulo").hexdigest()
        with self.assertRaisesRegex(restore.RestoreErro, "reservado"):
            restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "r"), manifesto=m, fonte="cloud",
                              log=lambda *_: None)

    def test_cauda_do_smoke_nao_leva_valor_de_ambiente(self):
        self._backup()
        self.contrato["environment"]["smoke_command"] = "Write-Output $env:EOS_TESTE_SEGREDO; exit 0"
        with mock.patch.dict(os.environ, {"EOS_TESTE_SEGREDO": VALOR}):
            c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertNotIn(VALOR, json.dumps(c))
        cert = bk.ultima_certificacao(self.store, "proj")
        self.assertNotIn(VALOR, json.dumps(cert))


class TestR3FalsoSim(Base):
    def test_skip_worktree_modificado_entra_no_wip(self):
        sh(self.proj, "update-index", "--skip-worktree", "docs/STATE.md")
        with open(os.path.join(self.proj, "docs", "STATE.md"), "w") as f:
            f.write("edicao escondida do status\n")
        self.assertNotIn("STATE.md", sh(self.proj, "status", "--porcelain"), "premissa: o status esconde")
        m = self._backup()
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertIn("docs/STATE.md", main["arquivos"])
        with open(os.path.join(self.proj, "docs", "STATE.md"), "w") as f:
            f.write("outra edicao escondida\n")
        self.assertIn("WIP", _check(self)["dimensoes"]["backup"]["motivo"])

    def test_gitlink_limpo_nao_e_protegivel(self):
        sub = os.path.join(self.proj, "vendor")
        os.makedirs(sub)
        sh(sub, "init", "-q")
        sh(sub, "config", "user.email", "t@t")
        sh(sub, "config", "user.name", "t")
        with open(os.path.join(sub, "a.txt"), "w") as f:
            f.write("commit so do embutido")
        sh(sub, "add", "-A")
        sh(sub, "commit", "-q", "-m", "interno")
        sh(self.proj, "add", "vendor")
        sh(self.proj, "commit", "-q", "-m", "embute")
        self.assertIn("vendor", gitinfo.gitlinks(self.proj))
        m = self._backup()
        self.assertTrue(any("vendor" in x for x in m["pendencias"]))
        self.assertIn("vendor", _check(self)["dimensoes"]["backup"]["motivo"])

    def test_exclude_por_contrato_nao_vira_pode_perder(self):
        self.contrato["backup"]["exclude"] = ["deploy.key"]
        with open(os.path.join(self.proj, "deploy.key"), "w") as f:
            f.write(VALOR)
        self._backup()
        r = _check(self)
        self.assertTrue(any("deploy.key" in x for x in portability._so_nesta_pasta(
            self.contrato, self.proj, gitinfo.resumo(self.proj, ["deploy.key"]))))
        self.assertFalse(r["seguro_apagar_clone"])

    def test_worktree_dentro_da_pasta_nao_vira_aninhado(self):
        interna = os.path.join(self.proj, "wt-interna")
        sh(self.proj, "worktree", "add", "-q", interna, "-b", "interna")
        with open(os.path.join(self.proj, ".gitignore"), "a") as f:
            f.write("")
        w = gitinfo.wip(self.proj, worktrees_internas=[interna])
        self.assertNotIn("wt-interna", w["aninhados"])
        w2 = gitinfo.wip(self.proj)
        self.assertIn("wt-interna", w2["aninhados"], "premissa: sem a lista, ela pareceria aninhada")

    def test_override_absoluto_no_machine_yaml_e_o_lugar_certo(self):
        self.maquina["projects"] = {"proj": {"local_path": self.proj}}
        self.assertEqual(_check(self)["dimensoes"]["paths"]["status"], "PASS")

    def test_wal_do_banco_declarado_nao_conta_como_nao_declarado(self):
        with open(self.db + "-wal", "wb") as f:
            f.write(b"")
        r = portability._so_nesta_pasta(self.contrato, self.proj, gitinfo.resumo(self.proj))
        self.assertFalse(any("x.db-wal" in x for x in r), r)


class TestR3Remoto(Base):
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

    def test_notes_criadas_depois_do_backup_e_nao_publicadas(self):
        self._backup()
        sh(self.proj, "notes", "add", "-m", "nota", "HEAD")
        r = _check(self, rede=True)
        self.assertIn("refs/notes/commits", r["dimensoes"]["remote"].get("faltam", []))
        self.assertIn("refs mudaram", r["dimensoes"]["backup"]["motivo"])


if __name__ == "__main__":
    unittest.main()
