"""Espelho de dados cloud-mirror (eos/mirror.py) sobre repositorio temporario e nuvem em DirStore.

Cada caso negativo existe porque o positivo sozinho passaria com um espelho que nao protege nada:
"a copia rodou sem erro" nao prova que o arquivo na nuvem e o arquivo local.
"""
import contextlib
import hashlib
import io
import json
import os
import shutil
import unittest
from unittest import mock

from eos import __main__ as cli
from eos import backup as bk
from eos import cloud, gitinfo, mirror, portability, restore
from eos.tests.test_e2e import Base

DADOS = "05 LAB/proj/dados"


def _md5(p):
    with open(p, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


class StoreCorrompido(cloud.DirStore):
    """Corrompe um arquivo NO DESTINO entre a copia e a verificacao (injecao do teste)."""

    def __init__(self, raiz, alvo):
        super().__init__(raiz)
        self.alvo = alvo

    def enviar_lote(self, base_local, rels, rel_destino, rel_anteriores=None):
        super().enviar_lote(base_local, rels, rel_destino, rel_anteriores)
        p = self._p(self.alvo)
        if os.path.isfile(p):
            with open(p, "r+b") as f:
                b = f.read(1)
                f.seek(0)
                f.write(bytes([b[0] ^ 0xFF]))


class StoreForaDoAr(cloud.DirStore):
    def listar(self, rel):
        raise cloud.NuvemErro("sem rede")


class BaseMirror(Base):
    def setUp(self):
        super().setUp()
        self._w("data/brutos/a.txt", "conteudo a\n")
        self._w("data/brutos/sub/b.csv", "x;y\n1;2\n")
        self._w("config/mes.py", "MES = 10\n")
        self.contrato["data"] = [{"path": "data/brutos", "policy": "cloud-mirror"},
                                 {"path": "config/mes.py", "policy": "cloud-mirror"},
                                 {"path": "data/sumiu", "policy": "cloud-mirror"},
                                 {"path": "data/x.db", "policy": "none"}]
        self.journal = os.path.join(self.tmp, "journal")

    def _espelhar(self, store=None):
        return mirror.espelhar(self.contrato, store or self.store, self.maquina, journal=self.journal, log=lambda *_: None)

    def _so_aqui(self, store=None):
        return portability._so_nesta_pasta(self.contrato, self.proj, {}, store or self.store)

    def _nuvem(self, rel):
        return os.path.join(self.nuvem, *rel.split("/"))


class TestEspelho(BaseMirror):
    def test_espelho_completo_copia_confere_e_grava_manifesto_e_journal(self):
        r = self._espelhar()
        self.assertTrue(r["ok"], json.dumps(r["manifesto"], indent=1))
        self.assertEqual(r["enviados"], 3)
        for rel in ("data/brutos/a.txt", "data/brutos/sub/b.csv", "config/mes.py"):
            self.assertEqual(_md5(self._nuvem(DADOS + "/" + rel)), _md5(os.path.join(self.proj, rel)), rel)
        m = r["manifesto"]
        self.assertEqual(m["project"], "proj")
        self.assertEqual(m["paths"]["data/sumiu"]["estado"], "ausente")
        self.assertEqual(m["paths"]["data/brutos"]["estado"], "ok")
        self.assertEqual(m["paths"]["data/brutos"]["destino"], DADOS + "/data/brutos")
        self.assertNotIn("data/x.db", m["paths"], "policy none nao e espelhada")
        st = os.stat(os.path.join(self.proj, "data", "brutos", "a.txt"))
        self.assertEqual(m["paths"]["data/brutos"]["arquivos"]["data/brutos/a.txt"],
                         [st.st_size, st.st_mtime_ns, _md5(os.path.join(self.proj, "data", "brutos", "a.txt"))])
        self.assertEqual(m["paths"]["config/mes.py"]["arquivos"].keys(), {"config/mes.py"})
        rel = "99 RECOVERY/manifests/proj/mirror-%s.json" % m["ts"]
        self.assertEqual(r["nuvem"], rel)
        self.assertEqual(json.loads(self.store.ler_texto(rel)), m)
        with open(os.path.join(self.journal, "proj", m["ts"] + ".json"), encoding="utf-8") as f:
            self.assertEqual(json.load(f), m)
        self.assertEqual(mirror.ultimo_espelho(self.store, "proj")["ts"], m["ts"])

    def test_incremental_nao_reenvia_e_preserva_a_versao_substituida(self):
        self._espelhar()
        enviados = []
        original = cloud.DirStore.enviar_lote

        def espia(st, base, rels, dest, ant=None):
            enviados.extend(rels)
            return original(st, base, rels, dest, ant)
        with mock.patch.object(cloud.DirStore, "enviar_lote", espia):
            r2 = self._espelhar()
            self.assertTrue(r2["ok"])
            self.assertEqual((r2["enviados"], r2["ja_presentes"]), (0, 3))
            self.assertEqual(enviados, [], "arquivo com mesmo tamanho e md5 na nuvem foi reenviado")
            self._w("data/brutos/a.txt", "conteudo a, versao 2\n")
            r3 = self._espelhar()
        self.assertTrue(r3["ok"])
        self.assertEqual((r3["enviados"], r3["substituidos"], r3["ja_presentes"]), (1, 1, 2))
        self.assertEqual(enviados, ["a.txt"])
        self.assertEqual(self._r(self._nuvem(DADOS + "/data/brutos/a.txt")), "conteudo a, versao 2\n")
        anterior = self._nuvem("05 LAB/proj/dados-anteriores/%s/data/brutos/a.txt" % r3["manifesto"]["ts"])
        self.assertEqual(self._r(anterior), "conteudo a\n", "a versao substituida tem de ficar na nuvem")

    def test_alterado_depois_do_espelho_volta_a_ser_so_nesta_pasta(self):
        self.assertTrue(any("ainda sem copia verificada" in x for x in self._so_aqui()), self._so_aqui())
        self._espelhar()
        self.assertEqual(self._so_aqui(), [])
        self._w("data/brutos/a.txt", "mudou depois do espelho\n")
        self._w("data/brutos/novo.txt", "novo\n")
        mot = self._so_aqui()
        self.assertEqual(len(mot), 1, mot)
        self.assertIn("'data/brutos': 2 arquivo(s) novo(s)/alterado(s) desde o espelho de", mot[0])
        self._espelhar()
        self.assertEqual(self._so_aqui(), [])

    def test_mtime_mudado_sem_mudar_conteudo_tambem_conta(self):
        self._espelhar()
        p = os.path.join(self.proj, "config", "mes.py")
        st = os.stat(p)
        os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns + 5_000_000_000))
        self.assertTrue(any("'config/mes.py': 1 arquivo(s)" in x for x in self._so_aqui()))

    def test_store_indisponivel_mantem_o_motivo(self):
        self._espelhar()
        mot = self._so_aqui(StoreForaDoAr(self.nuvem))
        self.assertEqual(len(mot), 2, mot)
        self.assertTrue(all("nao verificavel" in x for x in mot), mot)

    def test_pasta_ausente_localmente_nao_e_motivo(self):
        self._espelhar()
        self.assertFalse(any("data/sumiu" in x for x in self._so_aqui()))

    def test_nome_de_segredo_nao_sobe_e_continua_so_nesta_pasta(self):
        self._w("data/brutos/.env", "API_TOKEN=valor-falso\n")
        self._w("data/brutos/sub/api_token.txt", "valor-falso\n")
        r = self._espelhar()
        self.assertTrue(r["ok"], "recusa de segredo nao e falha de verificacao")
        self.assertEqual(r["recusados"], 2)
        self.assertEqual(sorted(x["rel"] for x in r["manifesto"]["recusados"]),
                         ["data/brutos/.env", "data/brutos/sub/api_token.txt"])
        self.assertTrue(all(x["motivo"] == "nome de segredo" for x in r["manifesto"]["recusados"]))
        self.assertFalse(os.path.exists(self._nuvem(DADOS + "/data/brutos/.env")))
        self.assertFalse(os.path.exists(self._nuvem(DADOS + "/data/brutos/sub/api_token.txt")))
        self.assertNotIn("data/brutos/.env", r["manifesto"]["paths"]["data/brutos"]["arquivos"])
        mot = self._so_aqui()
        self.assertEqual(len(mot), 1, mot)
        self.assertIn("nome de segredo", mot[0])
        self.assertIn("data/brutos/.env", mot[0])

    def test_hash_divergente_no_destino_falha_fechada(self):
        st = StoreCorrompido(self.nuvem, DADOS + "/data/brutos/sub/b.csv")
        r = self._espelhar(st)
        self.assertFalse(r["ok"])
        reg = r["manifesto"]["paths"]["data/brutos"]
        self.assertEqual(reg["estado"], "falhou")
        self.assertEqual(reg["divergentes"], ["data/brutos/sub/b.csv"])
        self.assertIsNone(mirror.ultimo_espelho(self.store, "proj"), "manifesto de espelho falho contou como ok")
        self.assertTrue(any("data/brutos" in x and "ainda sem copia verificada" in x for x in self._so_aqui()))

    def test_data_aninhado_com_outra_policy_nao_sobe_nem_bloqueia(self):
        self._w("data/brutos/TESTE_1/lixo.txt", "descartavel\n")
        self.contrato["data"].append({"path": "data/brutos/TESTE_1", "policy": "none"})
        r = self._espelhar()
        self.assertTrue(r["ok"])
        self.assertEqual(r["manifesto"]["paths"]["data/brutos"]["excluidos"], ["data/brutos/TESTE_1"])
        self.assertFalse(os.path.exists(self._nuvem(DADOS + "/data/brutos/TESTE_1/lixo.txt")))
        self._w("data/brutos/TESTE_1/lixo.txt", "mudou, e pode perder\n")
        self.assertEqual(self._so_aqui(), [])

    def test_sem_drive_root_e_erro(self):
        self.contrato.pop("cloud")
        with self.assertRaisesRegex(mirror.MirrorErro, "drive_root"):
            self._espelhar()

    def test_path_que_escapa_e_recusado(self):
        self.contrato["data"] = [{"path": "../fora", "policy": "cloud-mirror"}]
        with self.assertRaisesRegex(mirror.MirrorErro, "invalido"):
            self._espelhar()

    def test_ultimo_manifesto_de_backup_ignora_mirror(self):
        m = self._backup()
        self._espelhar()
        self.assertEqual(bk.ultimo_manifesto(self.store, "proj")["timestamp"], m["timestamp"])


class TestRestoreComDados(BaseMirror):
    def test_restore_com_dados_traz_os_arquivos_com_hash_igual(self):
        self._backup()
        self._espelhar()
        dst = os.path.join(self.tmp, "rest")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None, com_dados=True)
        self.assertTrue(rel["ok"], json.dumps(rel["verificacoes"], indent=1))
        for r_ in ("data/brutos/a.txt", "data/brutos/sub/b.csv", "config/mes.py"):
            self.assertEqual(_md5(os.path.join(dst, r_)), _md5(os.path.join(self.proj, r_)), r_)
        self.assertTrue(any("dados 'data/brutos'" in v["o_que"] and v["ok"] for v in rel["verificacoes"]))

    def test_restore_sem_com_dados_nao_traz_dados(self):
        self._backup()
        self._espelhar()
        dst = os.path.join(self.tmp, "rest")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None)
        self.assertTrue(rel["ok"])
        self.assertFalse(os.path.exists(os.path.join(dst, "data", "brutos")))

    def test_restore_com_dados_adulterados_na_nuvem_reprova(self):
        self._backup()
        self._espelhar()
        with open(self._nuvem(DADOS + "/data/brutos/a.txt"), "ab") as f:
            f.write(b"!")
        dst = os.path.join(self.tmp, "rest")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None, com_dados=True)
        self.assertFalse(rel["ok"])
        v = next(v for v in rel["verificacoes"] if "dados 'data/brutos'" in v["o_que"])
        self.assertEqual(v["divergentes"], ["data/brutos/a.txt"])

    def test_restore_com_dados_sem_espelho_reprova(self):
        self._backup()
        rel = restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "rest"), fonte="cloud",
                                log=lambda *_: None, com_dados=True)
        self.assertFalse(rel["ok"])

    def test_restore_recusa_chave_de_manifesto_fora_do_path(self):
        self._backup()
        r = self._espelhar()
        m = r["manifesto"]
        m["paths"]["data/brutos"]["arquivos"]["app.py"] = [1, 1, "0" * 32]
        self.store.escrever_texto(r["nuvem"], json.dumps(m))
        with self.assertRaisesRegex(restore.RestoreErro, "fora de"):
            restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "rest"), fonte="cloud",
                              log=lambda *_: None, com_dados=True)

    def test_certificacao_nao_baixa_dados(self):
        self._backup()
        self._espelhar()
        baixou = []
        original = cloud.DirStore.get

        def espia(st, rel, local):
            baixou.append(rel)
            return original(st, rel, local)
        with mock.patch.object(cloud.DirStore, "get", espia):
            c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None, manter=True)
        try:
            self.assertTrue(c.get("restore"), c.get("erro"))
            self.assertFalse(os.path.exists(os.path.join(c["destino"], "data", "brutos")))
            self.assertFalse([x for x in baixou if "/dados/" in x], "a certificacao baixou dados: %s" % baixou)
        finally:
            gitinfo.remover_arvore(c["destino"])


class TestCli(BaseMirror):
    def _main(self, argv, store=None):
        out = io.StringIO()
        itens = {"proj": self.contrato,
                 "outro": dict(self.contrato, identity=dict(self.contrato["identity"], id="outro"), data=[])}
        with mock.patch.object(cli.registry, "carregar", return_value=itens), \
                mock.patch.object(cli, "_store", return_value=store or self.store), \
                mock.patch.object(cli.paths, "carregar_maquina", return_value=self.maquina), \
                mock.patch.dict(os.environ, {"LOCALAPPDATA": os.path.join(self.tmp, "lad")}), \
                contextlib.redirect_stdout(out):
            rc = cli.main(argv)
        return rc, out.getvalue()

    def test_mirror_ok_e_todos_so_com_cloud_mirror(self):
        rc, out = self._main(["mirror", "--todos"])
        self.assertEqual(rc, 0, out)
        self.assertIn("mirror proj", out)
        self.assertNotIn("mirror outro", out)
        self.assertIn("enviados 3", out)
        self.assertTrue(os.path.isdir(os.path.join(self.tmp, "lad", "emmily-os", "mirror", "proj")))
        rc, out = self._main(["mirror", "proj"])
        self.assertIn("ja presentes 3", out)

    def test_mirror_com_verificacao_falha_sai_1(self):
        rc, out = self._main(["mirror", "proj"], StoreCorrompido(self.nuvem, DADOS + "/data/brutos/a.txt"))
        self.assertEqual(rc, 1, out)
        self.assertIn("FALHOU", out)

    def test_mirror_sem_alvo_ou_desconhecido_sai_2(self):
        self.assertEqual(self._main(["mirror"])[0], 2)
        self.assertEqual(self._main(["mirror", "nao-existe"])[0], 2)

    def test_restore_com_dados_pela_cli(self):
        self._backup()
        self._main(["mirror", "proj"])
        dst = os.path.join(self.tmp, "rest-cli")
        rc, out = self._main(["restore", "proj", "--para", dst, "--fonte", "cloud", "--com-dados"])
        self.assertEqual(rc, 0, out)
        self.assertEqual(self._r(os.path.join(dst, "data", "brutos", "a.txt")), "conteudo a\n")


@unittest.skipUnless(shutil.which("rclone"), "rclone ausente")
class TestRcloneLocal(BaseMirror):
    """O transporte real (rclone), sem rede: backend ':local:' sobre a mesma pasta temporaria."""

    def setUp(self):
        super().setUp()
        self.rc = cloud.RcloneStore(":local:", self.nuvem.replace("\\", "/"), exe=shutil.which("rclone"))

    def test_espelho_incremental_e_verificado_pelo_rclone(self):
        r = self._espelhar(self.rc)
        self.assertTrue(r["ok"], json.dumps(r["manifesto"], indent=1))
        self.assertEqual(r["enviados"], 3)
        self.assertEqual(_md5(self._nuvem(DADOS + "/data/brutos/sub/b.csv")),
                         _md5(os.path.join(self.proj, "data", "brutos", "sub", "b.csv")))
        r2 = self._espelhar(self.rc)
        self.assertEqual((r2["enviados"], r2["ja_presentes"]), (0, 3))
        self._w("data/brutos/a.txt", "v2 pelo rclone\n")
        r3 = self._espelhar(self.rc)
        self.assertEqual((r3["enviados"], r3["substituidos"]), (1, 1))
        anterior = self._nuvem("05 LAB/proj/dados-anteriores/%s/data/brutos/a.txt" % r3["manifesto"]["ts"])
        self.assertEqual(self._r(anterior), "conteudo a\n")
        self.assertEqual(self._so_aqui(self.rc), [])

    def test_restore_com_dados_pelo_rclone(self):
        self._backup()
        self._espelhar(self.rc)
        dst = os.path.join(self.tmp, "rest-rc")
        rel = restore.restaurar(self.contrato, self.rc, dst, fonte="cloud", log=lambda *_: None, com_dados=True)
        self.assertTrue(rel["ok"], json.dumps(rel["verificacoes"], indent=1))
        self.assertEqual(self._r(os.path.join(dst, "config", "mes.py")), "MES = 10\n")

    def test_argv_do_rclone_e_aditivo(self):
        chamadas = []
        with mock.patch.object(cloud.RcloneStore, "_run", lambda st, *a, **k: chamadas.append(a) or (0, "[]", "")):
            self.rc.enviar_lote(self.proj, ["app.py"], "x/dados", "x/dados-anteriores/1")
        a = chamadas[0]
        self.assertEqual(a[0], "copy")
        for flag in ("--checksum", "--files-from-raw", "--backup-dir"):
            self.assertIn(flag, a)
        self.assertFalse({"sync", "delete", "purge", "move", "moveto", "--delete-excluded"} & set(a))


if __name__ == "__main__":
    unittest.main()
