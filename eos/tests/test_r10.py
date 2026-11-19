"""Rodada r10 (2026-10-15): correcoes dos achados da revisao r9 (QA e security).

Cada caso prova o NEGATIVO: o motor anterior passava nele (SIM falso, ref perdida, vazamento).
"""
import json
import os
import tempfile
import unittest

from eos import cofre, gitinfo, portability, restore
from eos.tests.test_cofre import ENV, VALOR, BaseCofre
from eos.tests.test_e2e import Base, sh


class TestPreservadoNoRestore(Base):
    """QA-A1: refs/preservado/* viaja SO no bundle; o restore tem de traze-la e conferi-la."""

    def setUp(self):
        super().setUp()
        self.orfao = sh(self.proj, "rev-parse", "HEAD").strip()
        sh(self.proj, "update-ref", "refs/preservado/stash-x", self.orfao)

    def test_restore_traz_refs_preservado_do_bundle(self):
        m = self._backup()
        self.assertIn("refs/preservado/stash-x", m["refs"])
        dst = os.path.join(self.tmp, "restaurado")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None)
        self.assertTrue(rel["ok"], json.dumps(rel["verificacoes"], indent=1))
        self.assertEqual(gitinfo.refs(dst).get("refs/preservado/stash-x"), self.orfao)

    def _manifesto_com_preservado_ausente(self):
        m = self._backup()
        p = os.path.join(self.nuvem, "99 RECOVERY", "manifests", "proj", m["timestamp"] + ".json")
        with open(p, encoding="utf-8") as f:
            mj = json.load(f)
        # ref que o manifesto declara e o bundle NAO tem: o restore tem de acusar a falta
        mj["refs"]["refs/preservado/fantasma"] = "1" * 40
        with open(p, "w", encoding="utf-8") as f:
            json.dump(mj, f)
        return mj

    def test_restore_nao_aprova_sem_a_ref_preservado(self):
        self._manifesto_com_preservado_ausente()
        dst = os.path.join(self.tmp, "r-falta")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None)
        self.assertFalse(rel["ok"])
        v = next(x for x in rel["verificacoes"] if x["o_que"] == "refs locais iguais ao manifesto")
        self.assertIn("refs/preservado/fantasma", v["faltam"])

    def test_certificacao_nao_aprova_sem_a_ref_preservado(self):
        self._manifesto_com_preservado_ausente()
        c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertFalse(c["ok"])


class TestCofrePushAtomico(BaseCofre):
    """QA-A2: push parcial nunca deixa o cofre alterado sem manifesto que o denuncie."""

    def test_segundo_arquivo_nao_utf8_nada_vai_ao_cofre(self):
        with open(os.path.join(self.proj, ".env.local"), "wb") as f:
            f.write(b"X=\xff\xfe-nao-utf8\n")
        with self.assertRaisesRegex(cofre.CofreErro, "nao e UTF-8"):
            self._push()
        self.assertEqual(self._vault()["itens"], [], "o .env foi ao cofre antes do .env.local ser validado")
        self.assertFalse([a for a in self._argv_log() if a[:1] in (["create"], ["edit"], ["encode"])])
        self.assertEqual(self._manifestos_cofre(), [])

    def test_falha_depois_de_gravar_deixa_manifesto_incompleto_e_check_nao_diz_sim(self):
        self._push()  # manifesto 1: .env com ENV
        outra = os.path.join(self.tmp, "outra-maquina")  # tem o .env ANTIGO, igual ao manifesto 1
        os.makedirs(outra)
        with open(os.path.join(outra, ".env"), "w", newline="\n") as f:
            f.write(ENV)
        self.assertTrue(cofre.verificar_cofre(self.contrato, self.store, self.maquina, raiz=outra)["ok"])
        self._w(".env", ENV + "NOVA=VALOR-FALSO-NOVO-1\n")
        self._w(".env.local", "L=VALOR-FALSO-LOCAL-2\n")
        db = self._vault()
        db["corromper"] = True  # so o create (o .env.local) sai corrompido; o edit do .env vai certo
        self._vault(db)
        import time
        time.sleep(1.1)  # carimbo novo
        with self.assertRaises(cofre.ConferenciaFalhou):
            self._push()
        self.assertTrue(self._vault()["itens"][0]["notes"].endswith("NOVA=VALOR-FALSO-NOVO-1\n"), "o cofre mudou")
        m = cofre.ultimo_manifesto_cofre(self.store, "proj")
        self.assertTrue(m.get("incompleto"), m)
        v = cofre.verificar_cofre(self.contrato, self.store, self.maquina, raiz=outra)
        self.assertFalse(v["ok"], "SIM falso: o cofre mudou e o manifesto antigo ainda bate na outra maquina")
        self.assertTrue(any("incompleto" in x for x in v["motivos"]), v["motivos"])
        self.assertNotIn(VALOR, json.dumps(m))


class TestRedigir(unittest.TestCase):
    """A5/S-A7: forma escapada em JSON e valores curtos como token isolado."""

    def test_forma_escapada_em_json(self):
        v = 'abc"def\\ghi'
        msg = 'erro: {"notes": %s}' % json.dumps(v)
        self.assertNotIn("def", cofre._redigir(msg, cofre._valores("K=%s\n" % v)))

    def test_valor_curto_como_token_isolado(self):
        segs = cofre._valores("PIN=k9\n")
        out = cofre._redigir("falhou com valor k9 recusado; k9x e ok9 ficam", segs)
        self.assertNotIn(" k9 ", out)
        self.assertIn("k9x", out)
        self.assertIn("ok9", out)


class TestProvenanceFile(unittest.TestCase):
    """QA-A3: provenance_file e caminho LITERAL; erro do git nunca vira PASS silencioso."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="eos-r10p-")
        self.repo = os.path.join(self.tmp, "repo")
        os.makedirs(os.path.join(self.repo, "docs"))
        sh(self.tmp, "init", "-q", "-b", "main", self.repo)
        for f, t in (("docs/STATE.md", "estado"), ("app.py", "x")):
            with open(os.path.join(self.repo, f), "w") as fh:
                fh.write(t)
        sh(self.repo, "add", "-A")
        sh(self.repo, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "commit", "-q", "-m", "c")

    def tearDown(self):
        gitinfo.remover_arvore(self.tmp)

    def test_glob_no_provenance_file_nao_exclui_tudo(self):
        # antes: ':(exclude)*' excluia o repositorio inteiro, devolvia None e o STATE nunca ficava velho
        with self.assertRaises(portability.CommitNaoVerificavel):
            portability._ultimo_commit_epoch(self.repo, {"ownership": {"provenance_file": "*"}})
        self.assertIsInstance(portability._ultimo_commit_epoch(self.repo, {"ownership": {"provenance_file": "docs/O.md"}}), int)

    def test_contrato_recusa_glob_e_ponto_ponto(self):
        from eos import contract
        for ruim in ("*", "docs/*.md", "../x", "docs/../../x", "C:/x.md", "/x.md", "a?b", "[ab]"):
            doc = {"contract_version": 1, "identity": {"id": "xx", "name": "X", "type": "ARCHIVE", "category": "LAB",
                                                       "status": "active", "criticality": "low"},
                   "cloud": {"drive_root": "x"},
                   "ownership": {"declared_owner": "a", "creators": ["a"], "provenance_file": ruim}}
            erros = contract.validar(doc)
            self.assertTrue(any("provenance_file" in e for e in erros), (ruim, erros))
        doc["ownership"]["provenance_file"] = "docs/ORIGEM.md"
        self.assertEqual(contract.validar(doc), [])


class TestProvenanceErroDoGit(Base):
    def test_erro_do_git_e_unknown_nunca_pass(self):
        # contrato com valor que o contrato recusaria, lido mesmo assim (registry editado a mao)
        self.contrato["ownership"] = {"declared_owner": "a", "creators": ["a"], "provenance_file": "../fora.md"}
        r = portability.verificar(self.contrato, self.store, self.maquina, rede=False)
        self.assertEqual(r["dimensoes"]["state"]["status"], portability.UNKNOWN, r["dimensoes"]["state"])
        self.assertIn("ultimo commit", r["dimensoes"]["state"]["motivo"])


from eos import contract, mirror  # noqa: E402
from eos.tests import test_mirror as tm  # noqa: E402 (modulo: importar TestCli rodaria os casos dela de novo)
from eos.tests.test_mirror import DADOS, BaseMirror  # noqa: E402

# montados por concatenacao: o fonte do teste nao pode carregar um token com a forma real
TOKEN_GH = "gh" + "p_" + "A1b2C3d4" * 5
AWS = "AK" + "IA" + "ABCDEFGHIJKLMNOP"
PEM = "-----BEGIN " + "RSA PRIVATE KEY-----\nMIIabc\n"


class TestDecisaoPendente(BaseMirror):
    """S-A1: entrada de data com decisao pendente nunca e espelhada e nunca da SIM."""

    def setUp(self):
        super().setUp()
        self.contrato["data"][0]["decisao_pendente"] = True  # data/brutos

    def test_contrato_aceita_bool_e_recusa_outro_tipo(self):
        self.assertEqual([e for e in contract.validar(self.contrato) if "decisao_pendente" in e], [])
        self.contrato["data"][0]["decisao_pendente"] = "sim"
        self.assertTrue(any("decisao_pendente" in e for e in contract.validar(self.contrato)))

    def test_mirror_recusa_a_entrada_e_nada_sobe(self):
        r = self._espelhar()
        self.assertEqual(r["manifesto"]["paths"]["data/brutos"]["estado"], "decisao-pendente")
        self.assertEqual(r["pendentes"], ["data/brutos"])
        self.assertFalse(os.path.exists(os.path.join(self.nuvem, *(DADOS + "/data/brutos").split("/"))),
                         "dado com decisao pendente foi para a nuvem")
        self.assertTrue(os.path.exists(os.path.join(self.nuvem, *(DADOS + "/config/mes.py").split("/"))))

    def test_check_acusa_mesmo_com_espelho_antigo_ok(self):
        # o espelho de 2026-10-12 ja subiu o dado ANTES da marcacao: a copia nao vale como decisao
        self.contrato["data"][0].pop("decisao_pendente")
        self.assertTrue(self._espelhar()["ok"])
        self.assertEqual(self._so_aqui(), [])
        self.contrato["data"][0]["decisao_pendente"] = True
        ms = self._so_aqui()
        self.assertIn("dado com decisao pendente: data/brutos", ms)

    def test_todas_pendentes_e_erro(self):
        for d in self.contrato["data"]:
            d["decisao_pendente"] = True
        with self.assertRaisesRegex(mirror.MirrorErro, "decisao pendente"):
            self._espelhar()


class TestDecisaoPendenteCli(tm.TestCli):
    def setUp(self):
        super().setUp()
        self.contrato["data"][0]["decisao_pendente"] = True

    def test_mirror_todos_recusa_com_mensagem_e_sai_1(self):
        rc, out = self._main(["mirror", "--todos"])
        self.assertEqual(rc, 1, out)
        self.assertIn("RECUSADO (decisao pendente): data/brutos", out)

    # os casos herdados assumem data/brutos espelhavel
    test_mirror_ok_e_todos_so_com_cloud_mirror = None
    test_mirror_com_verificacao_falha_sai_1 = None
    test_mirror_sem_alvo_ou_desconhecido_sai_2 = None

    def test_restore_com_dados_pela_cli(self):
        # r11 QA2: substitui o herdado (desligado na r10). A entrada pendente e pulada com
        # verificacao explicita que NAO reprova; o resto e restaurado e o comando sai com 0
        self._backup()
        self._main(["mirror", "proj"])
        dst = os.path.join(self.tmp, "rest-cli")
        rc, out = self._main(["restore", "proj", "--para", dst, "--fonte", "cloud", "--com-dados"])
        self.assertEqual(rc, 0, out)
        self.assertIn("[ok] dados 'data/brutos': decisao pendente, nao restaurado", out)
        self.assertFalse(os.path.exists(os.path.join(dst, "data", "brutos", "a.txt")))
        self.assertEqual(self._r(os.path.join(dst, "config", "mes.py")), "MES = 10\n")

    def test_mirror_todas_pendentes_sai_2(self):
        # r11 QA3: o guia 08 diz rc 2 quando todas as entradas estao pendentes (e no --todos)
        for d in self.contrato["data"]:
            d["decisao_pendente"] = True
        rc, out = self._main(["mirror", "proj"])
        self.assertEqual(rc, 2, out)
        self.assertIn("todo data[] cloud-mirror esta com decisao pendente", out)
        self.assertEqual(self._main(["mirror", "--todos"])[0], 2)


class TestMirrorConteudoCaixaManifesto(BaseMirror):
    """S-A6: conteudo com credencial nao sobe; aninhado ignora caixa no Windows; manifesto sem
    caminho absoluto da maquina."""

    def test_credencial_no_conteudo_e_recusada(self):
        self._w("data/brutos/notas.txt", "ok\ntoken=%s\n" % TOKEN_GH)
        self._w("data/brutos/aws.cfg", "id = %s\n" % AWS)
        self._w("data/brutos/k.txt", PEM)
        self._w("data/brutos/cfg.ini", "senha=Abc12345xyz\n")
        r = self._espelhar()
        recus = {x["rel"]: x["motivo"] for x in r["manifesto"]["recusados"]}
        for f in ("notas.txt", "aws.cfg", "k.txt", "cfg.ini"):
            self.assertIn("data/brutos/" + f, recus)
            self.assertIn("credencial", recus["data/brutos/" + f])
            self.assertFalse(os.path.exists(os.path.join(self.nuvem, *(DADOS + "/data/brutos/" + f).split("/"))), f)
        self.assertTrue(os.path.exists(os.path.join(self.nuvem, *(DADOS + "/data/brutos/a.txt").split("/"))))
        self.assertNotIn(TOKEN_GH, json.dumps(r["manifesto"]))
        self.assertTrue(self._so_aqui(), "arquivo recusado tem de continuar acusado como so nesta pasta")

    def test_texto_comum_passa(self):
        self._w("data/brutos/doc.txt", "a palavra senha aparece aqui; sk- e AKIA sozinhos tambem\n")
        r = self._espelhar()
        self.assertNotIn("data/brutos/doc.txt", {x["rel"] for x in r["manifesto"]["recusados"]})

    @unittest.skipUnless(os.name == "nt", "caixa so e indiferente no Windows")
    def test_aninhado_com_outra_caixa_nao_sobe(self):
        self.contrato["data"].append({"path": "DATA/Brutos/sub", "policy": "none"})
        r = self._espelhar()
        self.assertFalse(os.path.exists(os.path.join(self.nuvem, *(DADOS + "/data/brutos/sub/b.csv").split("/"))),
                         "aninhado com policy none subiu porque a caixa era diferente")
        self.assertTrue(r["manifesto"]["paths"]["data/brutos"].get("excluidos"))

    def test_manifesto_sem_caminho_absoluto_da_maquina(self):
        r = self._espelhar()
        bruto = json.dumps(r["manifesto"])
        for x in (self.tmp, self.tmp.replace("\\", "/"), self.proj):
            self.assertNotIn(json.dumps(x)[1:-1], bruto)
        self.assertFalse(os.path.isabs(r["manifesto"]["source_path"]))


from eos import ownership  # noqa: E402
from eos.tests.test_ownership import BaseOwn, sh as sh_own  # noqa: E402


class TestCertificadoOwnershipRedigido(BaseOwn):
    """S-A2: o certificado GRAVADO nao leva caminho com o usuario do Windows nem e-mail em claro."""

    def test_certificado_gravado_sem_caminho_nem_email(self):
        self.contrato["ownership"]["signing"] = "recommended"
        pasta = os.path.join(self.tmp, "Usuario Fulano", ".ssh")
        sh_own(self.proj, "config", "gpg.format", "ssh")
        sh_own(self.proj, "config", "user.signingkey", os.path.join(pasta, "id_teste.pub"))
        sh_own(self.proj, "config", "gpg.ssh.allowedSignersFile", os.path.join(pasta, "allowed"))
        self._commit("contrib", "Colega Externa", "colega@example.com")
        self.contrato["ownership"]["contributors"] = ["Colega Externa <colega@example.com>"]
        c = ownership.certificar(self.contrato, self.store, self.maquina, journal=self.journal)
        self.assertTrue(c["ok"], c.get("recusado"))
        texto = self.store.ler_texto(c["nuvem"])
        self.assertNotIn("Usuario Fulano", texto)
        self.assertNotIn(self.tmp.replace("\\", "\\\\"), texto)
        self.assertNotIn("colega@example.com", texto.lower())
        cert = json.loads(texto)
        sig = next(i for i in cert["checks"] if i["item"] == "signing")
        self.assertEqual(sig["fatos"]["signingkey"], "id_teste.pub")
        self.assertIn("id_teste.pub", sig["fatos"]["signingkey_motivo"])
        self.assertIn("Colega Externa", json.dumps(cert["ownership"]["contributors"]))
        with open(c["journal"], encoding="utf-8") as f:
            self.assertNotIn("Usuario Fulano", f.read())


RELATORIO_SCAN = (
    "# Varredura\n\n## Escopo NAO VARRIDO\n\n### Lacunas DESTA execucao\n\n"
    "Contingentes.\n\n| O que NAO foi varrido | Consequencia para o veredito |\n|---|---|\n"
    "%s"
    "| Se o destino deste relatorio esta ignorado | O relatorio foi gravado FORA do repositorio-alvo (``-Out``), entao a pergunta nao se aplica |\n"
    "\n### Teto permanente da ferramenta\n\n| x | y |\n|---|---|\n| teto | nao e lacuna |\n")


class TestScanLacuna(unittest.TestCase):
    """S-A4: varredura rc 0 com lacuna NESTA execucao e falha fechada (rc 2), nao limpa."""

    def _scan(self, linhas, rc=0, escrever=True):
        from unittest import mock
        import subprocess
        from eos import novo

        def run_falso(argv, **kw):
            if escrever:
                with open(argv[argv.index("-Out") + 1], "w", encoding="utf-8") as f:
                    f.write(RELATORIO_SCAN % linhas)
            return subprocess.CompletedProcess(argv, rc, b"ok\n", b"")
        with mock.patch("eos.novo.subprocess.run", side_effect=run_falso):
            r = novo._scan_padrao("C:\\x\\proj", "proj-lacuna")
        if os.path.isfile(r[1]):
            os.remove(r[1])
        return r

    def test_lacuna_nomeada_e_falha_fechada(self):
        rc, _, saida = self._scan("| Conteudo de 3 arquivo(s) ILEGIVEL(eis) como texto | nao varridos |\n")
        self.assertEqual(rc, 2, saida)
        self.assertIn("ILEGIVEL", saida)

    def test_sem_lacuna_alem_do_destino_continua_limpo(self):
        self.assertEqual(self._scan("")[0], 0)

    def test_lacunas_do_template_fechadas_pelo_motor(self):
        # as que o template do eos new produz em todo nascimento (medido na r10)
        linhas = ("| Classe de caractere completa em 1 regra(s) de `.gitignore` | x |\n"
                  "| Atribuicao individual de 2 regra(s) de `.gitignore` que compartilham sonda | x |\n"
                  "| 1 blob(s) do historico que o `cat-file` devolveu vazio | `e69de29b (.claude/skills/.gitkeep)` - nao lidos |\n"
                  "| Nome canonico de segredo DENTRO de subarvore liberada por negacao | x |\n")
        self.assertEqual(self._scan(linhas)[0], 0)

    def test_blob_vazio_que_nao_e_o_blob_vazio_do_git_e_lacuna(self):
        rc, _, saida = self._scan("| 1 blob(s) do historico que o `cat-file` devolveu vazio | `0123abcd (x.txt)` - nao lidos |\n")
        self.assertEqual(rc, 2, saida)

    def test_linha_desconhecida_e_lacuna(self):
        self.assertEqual(self._scan("| Algo novo que o scanner passou a declarar | x |\n")[0], 2)

    def test_relatorio_ausente_e_falha_fechada(self):
        self.assertEqual(self._scan("", escrever=False)[0], 2)


if __name__ == "__main__":
    unittest.main()
