"""Rodada r12 (2026-10-15): correcoes dos achados da revisao r11 (QA A1-A3, Security 1-3; o
Security 4 esta em test_guardas.test_r12_*).

Cada caso prova o NEGATIVO: o motor anterior passava nele (restore [ok] sem restaurar, filho
pendente subindo com o pai, valor de .env sem redacao, caminho da maquina no certificado).
"""
import json
import os
import tempfile
import unittest

from eos import backup as bk
from eos import cofre, contract, mirror, paths, portability, restore
from eos.tests.test_mirror import BaseMirror
from eos.tests.test_r11 import _arquivos_na_nuvem, _existe_na_nuvem


class TestRestorePendenteSoPeloContrato(BaseMirror):
    """QA-A1: a marca `decisao-pendente` do manifesto so pula o path se o CONTRATO atual tambem o
    tem pendente; senao e 'sem copia verificada' e reprova."""

    def _restaurar(self, nome):
        dst = os.path.join(self.tmp, nome)
        return restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None, com_dados=True)

    def test_titular_decidiu_depois_do_espelho(self):
        self.contrato["data"][0]["decisao_pendente"] = True  # data/brutos
        self._backup()
        m = self._espelhar()["manifesto"]
        self.assertEqual(m["paths"]["data/brutos"]["estado"], "decisao-pendente", "premissa")
        del self.contrato["data"][0]["decisao_pendente"]  # decidido, mas sem espelho novo
        rel = self._restaurar("rest-decidido")
        self.assertIs(rel["ok"], False, json.dumps(rel["verificacoes"], indent=1))
        self.assertFalse([x for x in rel["verificacoes"] if "decisao pendente" in x["o_que"]])
        v = [x for x in rel["verificacoes"] if "'data/brutos'" in x["o_que"]]
        self.assertEqual(len(v), 1, rel["verificacoes"])
        self.assertFalse(v[0]["ok"])
        self.assertIn("sem copia", v[0]["motivo"])

    def test_manifesto_adulterado_com_marca_pendente(self):
        self._backup()
        m = self._espelhar()["manifesto"]
        m["paths"]["data/brutos"] = {"estado": "decisao-pendente", "destino": "x", "arquivos": {}}
        self.store.escrever_texto(mirror.rel_manifesto("proj", m["ts"]), json.dumps(m))
        rel = self._restaurar("rest-adulterado")
        self.assertIs(rel["ok"], False)
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "rest-adulterado", "data", "brutos", "a.txt")))

    def test_pendente_no_contrato_continua_pulando(self):
        # o caso da r11 (QA2) nao regride
        self.contrato["data"][0]["decisao_pendente"] = True
        self._backup()
        self._espelhar()
        rel = self._restaurar("rest-pendente")
        self.assertTrue(rel["ok"], json.dumps(rel["verificacoes"], indent=1))


class TestPathInvalidoFalhaFechado(BaseMirror):
    """QA-A2/Sec1: data[].path invalido em qualquer entrada nao e descartado em silencio."""

    def setUp(self):
        super().setUp()
        self._w("data/raw/juridico.pdf", "conteudo pendente\n")
        self._w("data/ok.txt", "pode subir\n")

    def _contrato_com(self, ruim):
        self.contrato["data"] = [{"path": "data", "policy": "cloud-mirror"},
                                 {"path": ruim, "policy": "none", "decisao_pendente": True}]

    def test_pendente_com_ponto_barra_nao_deixa_o_pai_subir_o_filho(self):
        for ruim in ("./data/raw", "data//raw", "data/raw/.", "data /raw", "data/raw."):
            self._contrato_com(ruim)
            with self.assertRaisesRegex(mirror.MirrorErro, "invalido", msg=ruim):
                self._espelhar()
            self.assertEqual(_arquivos_na_nuvem(self, "data/raw"), [], "o pai subiu o filho pendente: %r" % ruim)
            self.assertFalse(_existe_na_nuvem(self, "data/ok.txt"), "algo subiu antes da validacao: %r" % ruim)

    def test_funcoes_levantam(self):
        self._contrato_com("./data/raw")
        with self.assertRaises(mirror.MirrorErro):
            mirror._pendentes_norm(self.contrato)
        with self.assertRaises(mirror.MirrorErro):
            mirror.aninhados(self.contrato, "data")
        with self.assertRaises(mirror.MirrorErro):
            mirror.separar(self.contrato)

    def test_check_acusa_sem_quebrar(self):
        self._contrato_com("./data/raw")
        ms = self._so_aqui()
        self.assertTrue(any("invalido" in x and "./data/raw" in x for x in ms), ms)

    def test_restore_com_dados_recusa(self):
        self._backup()
        self._contrato_com("./data/raw")
        with self.assertRaisesRegex(restore.RestoreErro, "invalido"):
            restore.restaurar(self.contrato, self.store, os.path.join(self.tmp, "rest-inv"), fonte="cloud",
                              log=lambda *_: None, com_dados=True)

    def test_docstring_nao_promete_mais_o_descarte(self):
        self.assertNotIn("nao se\n    compara com nada", mirror._pendentes_norm.__doc__)
        self.assertIn("MirrorErro", mirror._pendentes_norm.__doc__)


class TestContratoRecusaDataPath(unittest.TestCase):
    """Sec1: contract.validar recusa data[].path invalido, inclusive componente terminado em espaco
    ou ponto (o Windows o descarta)."""

    def _doc(self, p):
        return {"contract_version": 1, "identity": {"id": "xx", "name": "X", "type": "ARCHIVE", "category": "LAB",
                                                    "status": "active", "criticality": "low"},
                "cloud": {"drive_root": "x"}, "data": [{"path": p, "policy": "none"}]}

    def test_invalidos(self):
        for ruim in ("./data/raw", "data//raw", "../x", "C:/x", "/x", "data/*", "data /raw", "data/raw.",
                     "data/raw ", "data/.", "a:b"):
            erros = contract.validar(self._doc(ruim))
            self.assertTrue(any(e.startswith("data[0].path") for e in erros), (ruim, erros))

    def test_validos(self):
        for bom in ("data/raw", "data/x.db", "output/TESTE", ".venv", "data/.cache/x"):
            self.assertEqual(contract.validar(self._doc(bom)), [], bom)

    def test_validar_path_do_espelho_tambem(self):
        for ruim in ("data /raw", "data/raw.", "data/raw "):
            with self.assertRaises(mirror.MirrorErro, msg=ruim):
                mirror.validar_path(ruim)


class TestCofreComentarioEmLinha(unittest.TestCase):
    """QA-A3: `CHAVE="v" # comentario` nao abre bloco multilinha, e dentro de um bloco a linha
    `CHAVE=valor` tem o valor extraido."""

    def test_comentario_em_linha_seguido_de_outra_chave(self):
        env = 'PRIMEIRA="valorUmQualquer" # comentario\nSEGUNDA=valorDoisSecreto\nTERCEIRA=3\n'
        segs = cofre._valores(env)
        self.assertIn("valorUmQualquer", segs)
        self.assertIn("valorDoisSecreto", segs)
        for v in ("valorUmQualquer", "valorDoisSecreto"):
            self.assertNotIn(v, cofre._redigir("bw ecoou: %s." % v, segs))

    def test_sem_espaco_antes_do_comentario(self):
        segs = cofre._valores("A='abcdefgh'#nota\nB=ijklmnopq\n")
        self.assertIn("abcdefgh", segs)
        self.assertIn("ijklmnopq", segs)

    def test_bloco_de_verdade_extrai_valor_de_chave(self):
        env = 'CHAVE="inicio\nmiolo1234\nOUTRA=escondido99"\n'
        segs = cofre._valores(env)
        self.assertIn("escondido99", segs)
        self.assertIn("miolo1234", segs)


class TestRedacaoPontoFinal(unittest.TestCase):
    """Sec2: o caminho da casa no fim de uma frase ('...\\Ana.') e redigido; '.bak' continua sendo
    outro nome."""

    def setUp(self):
        self.casa = os.path.expanduser("~")

    def test_ponto_final(self):
        self.assertEqual(paths.redigir_caminhos("ficou em %s." % self.casa), "ficou em ~.")
        self.assertEqual(paths.redigir_caminhos("em %s. Depois" % self.casa), "em ~. Depois")

    def test_ponto_que_continua_nome(self):
        self.assertEqual(paths.redigir_caminhos(self.casa + ".bak"), self.casa + ".bak")
        self.assertEqual(paths.redigir_caminhos(self.casa + "2"), self.casa + "2")


def _formas(p):
    out = set()
    for x in (p, os.path.realpath(p), paths.nome_curto(p) or p):
        x = x.rstrip("\\/")
        out |= {x.lower(), x.replace("\\", "/").lower(), json.dumps(x)[1:-1].lower()}
    return out


class TestCertificadoSemCaminhoDaMaquina(BaseMirror):
    """Sec3: o certificado gravado na nuvem nao leva %TEMP% nem a pasta do usuario; o devolvido
    a quem chamou continua com o `destino` real."""

    def test_cert_na_nuvem_redigido(self):
        self._backup()
        c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        bruto = json.dumps(bk.ultima_certificacao(self.store, "proj"), ensure_ascii=False).lower()
        temp, casa = tempfile.gettempdir(), os.path.expanduser("~")
        for f in _formas(temp) | _formas(casa):
            self.assertNotIn(f, bruto, "caminho da maquina no cert da nuvem")
        nuvem = bk.ultima_certificacao(self.store, "proj")
        self.assertTrue(nuvem["destino"].startswith("%TEMP%"), nuvem["destino"])
        self.assertTrue(os.path.isabs(c["destino"]), "o retorno perdeu o destino real")
        self.assertEqual(nuvem["ok"], c["ok"])

    def test_redigir_recursivo(self):
        t = tempfile.gettempdir()
        out = paths.redigir({"a": [os.path.join(t, "x")], "b": {"c": os.path.join(os.path.expanduser("~"), "y")}, "n": 3})
        self.assertEqual(out, {"a": [os.path.join("%TEMP%", "x")], "b": {"c": os.path.join("~", "y")}, "n": 3})


class TestGitignoreWorktrees(unittest.TestCase):
    """Obs. da r11: `.claude/worktrees/` (repos embutidos) ignorado na raiz da plataforma."""

    def test_regra_presente(self):
        raiz = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        p = os.path.join(raiz, ".gitignore")
        if not os.path.isfile(p):
            self.skipTest("fora do repositorio da plataforma")
        with open(p, encoding="utf-8") as f:
            linhas = [x.strip() for x in f.read().splitlines()]
        self.assertIn(".claude/worktrees/", linhas)


if __name__ == "__main__":
    unittest.main()
