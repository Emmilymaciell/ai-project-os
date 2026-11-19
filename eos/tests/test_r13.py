"""Rodada r13 (2026-10-15): polimento dos achados da revisao r12 (Security S1-S3, QA3).

7 dos 9 casos provam o NEGATIVO (o motor anterior, a9e8764, falha neles; os outros 2 sao pares de
nao-regressao) -fragmento da pasta do usuario
no certificado gravado, chave de dict com caminho da maquina, '=' tratado como valor de segredo,
guarda cego a core.hooksPath/GIT_CONFIG_* fora de argv executado.
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

from eos import backup as bk
from eos import cofre, paths, portability
from eos.tests.test_e2e import Base
from eos.tests.test_guardas import analisar


def _ps(texto):
    """Literal de aspas simples do PowerShell."""
    return "'" + texto.replace("'", "''") + "'"


class TestCertRedigeAntesDeCortar(Base):
    """S1: a cauda do smoke e o erro sao redigidos ANTES do corte; cortado primeiro, o texto pode
    comecar (ou terminar) no meio da pasta do usuario e o fragmento escapa da redacao."""

    def setUp(self):
        super().setUp()
        # variante de caixa: escapa da troca exata de valores de ambiente (USERPROFILE), e so a
        # redacao de caminho (sem distincao de caixa) a pega
        self.casa = os.path.expanduser("~").rstrip("\\/").upper()
        self.assertNotEqual(self.casa, os.path.expanduser("~"), "premissa: a variante difere em caixa")

    def test_cauda_que_comeca_no_meio_da_casa(self):
        self._backup()
        k = len(self.casa) - 6
        sufixo = "\\saida.txt"
        n = 2000 - (len(self.casa) - k) - len(sufixo)  # a cauda [-2000:] comeca em casa[k:]
        self.contrato["environment"]["smoke_command"] = "[Console]::Out.Write('inicio ' + %s + %s + ('Z' * %d))" % (
            _ps(self.casa), _ps(sufixo), n)
        c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertEqual(c["smoke"]["rc"], 0, c["smoke"])
        nuvem = bk.ultima_certificacao(self.store, "proj")
        cauda = nuvem["smoke"]["cauda"].lower()
        self.assertTrue(cauda.endswith("z" * 100), "premissa: a cauda e a saida do smoke")
        frag = (self.casa[k:] + sufixo).lower()
        self.assertNotIn(frag, cauda, "fragmento da pasta do usuario na cauda gravada")
        self.assertNotIn(self.casa[k:].lower(), cauda)

    def test_erro_cortado_no_meio_da_casa(self):
        self._backup()
        k = min(12, len(self.casa) - 1)
        n = 500 - len("RuntimeError: ") - k  # o corte [:500] cai em casa[:k]
        msg = "x" * n + self.casa + "\\y"
        with mock.patch.object(portability.restore, "restaurar", side_effect=RuntimeError(msg)):
            c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertFalse(c["ok"])
        nuvem = bk.ultima_certificacao(self.store, "proj")
        self.assertTrue(nuvem["erro"].startswith("RuntimeError: xxx"), "premissa: o erro foi gravado")
        self.assertNotIn(self.casa[:k].lower(), nuvem["erro"].lower(), "fragmento da pasta do usuario no erro")
        self.assertNotIn(self.casa[:k].lower(), c["erro"].lower())


class TestRedigirChaves(unittest.TestCase):
    """S2: `paths.redigir` redige tambem as chaves str de dict."""

    def test_chaves(self):
        casa, temp = os.path.expanduser("~"), tempfile.gettempdir()
        out = paths.redigir({os.path.join(casa, "a"): {os.path.join(temp, "b"): [os.path.join(casa, "c")]}, 3: "x"})
        self.assertEqual(out, {os.path.join("~", "a"): {os.path.join("%TEMP%", "b"): [os.path.join("~", "c")]}, 3: "x"})


class TestCofreValorSoIgual(unittest.TestCase):
    """QA3: linha base64 com padding dentro de PEM casa CHAVE_RE; o 'valor' '=' (ou vazio) nao e
    segredo e nao pode redigir todo '=' da mensagem."""

    PEM = ('K="-----BEGIN FAKE KEY-----\n'
           'MIIBVQIBADANBgkqhkiG9w0BAQEFAASCAT8wggE7AgEAAkEA==\n'
           '-----END FAKE KEY-----"\n')

    def test_so_igual_nao_e_valor(self):
        v = cofre._valores(self.PEM)
        self.assertEqual([x for x in v if not x.strip("=")], [], "valor vazio ou so '='")
        self.assertIn("MIIBVQIBADANBgkqhkiG9w0BAQEFAASCAT8wggE7AgEAAkEA==", v, "a linha do PEM continua valor")
        self.assertEqual(cofre._redigir("erro: chave = valor; b64 ==", v), "erro: chave = valor; b64 ==")

    def test_valor_real_continua_redigido(self):
        v = cofre._valores(self.PEM + "TOKEN=abcd1234efgh\n")
        self.assertNotIn("abcd1234efgh", cofre._redigir("bw: abcd1234efgh =", v))


class TestGuardaHooksPathEAmbiente(unittest.TestCase):
    """S3: core.hooksPath em qualquer literal e GIT_CONFIG* como chave/argumento de ambiente."""

    def test_acusa(self):
        amostras = {
            "hooksPath fora de argv executado": "def f(d):\n    a = ['-c', 'core.hooksPath=/dev/null']\n    return a\n",
            "hookspath sem caixa": "X = 'CORE.HOOKSPATH'\n",
            "chave GIT_CONFIG_COUNT": "def f():\n    return {'GIT_CONFIG_COUNT': '1'}\n",
            "GIT_CONFIG_PARAMETERS por subscrito": "def f(env):\n    env['GIT_CONFIG_PARAMETERS'] = 'x'\n",
            "GIT_CONFIG_KEY_0 por argumento": "def f():\n    return dict(os.environ, GIT_CONFIG_KEY_0='core.x')\n",
        }
        for rotulo, src in amostras.items():
            pr, _ = analisar(src, "x.py")
            self.assertTrue(pr, "guarda nao acusou: %s" % rotulo)

    def test_nao_acusa_o_que_o_motor_usa(self):
        pr, _ = analisar("def f():\n    return _git_config_efetiva('user.name'), {'GIT_DIR': 'x'}\n", "x.py")
        self.assertEqual(pr, [])


RAIZ_OS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# montado por partes: o literal inteiro seria um achado do proprio scanner neste arquivo
WEBHOOK_FALSO = "https://hooks.slack.com/" + "services/T00000000/B00000000/abcdefghijklmnop"


@unittest.skipUnless(os.name == "nt", "o scanner e PowerShell 5.1")
class TestScannerLeManifest(unittest.TestCase):
    """S4: `.manifest` e extensao de texto para o scanner (scripts/lib/scan-comum.ps1): um valor
    colado num cofre.manifest e visto, e o manifesto so com NOMES nao gera achado nem fica como
    'sem extensao de texto nao lido'. Pelo script real, num repositorio descartavel."""

    def _scan(self, manifesto):
        tmp = os.path.realpath(tempfile.mkdtemp(prefix="eos-r13-scan-"))
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        for args in (["init", "-q"], ["config", "user.name", "t"], ["config", "user.email", "t@invalid"],
                     ["config", "core.autocrlf", "false"],
                     ["config", "core.excludesfile", os.path.join(tmp, ".git", "vazio")]):
            subprocess.run(["git", "-C", tmp] + args, capture_output=True, check=True)
        for nome, txt in (("a.md", "# nada\n"), ("cofre.manifest", manifesto)):
            with open(os.path.join(tmp, nome), "w", encoding="utf-8", newline="\n") as fh:
                fh.write(txt)
        subprocess.run(["git", "-C", tmp, "add", "-A"], capture_output=True, check=True)
        subprocess.run(["git", "-C", tmp, "commit", "-q", "-m", "c"], capture_output=True, check=True)
        fora = os.path.realpath(tempfile.mkdtemp(prefix="eos-r13-rel-"))
        self.addCleanup(shutil.rmtree, fora, ignore_errors=True)
        rel = os.path.join(fora, "security-report.md")  # fora do alvo: o repo fica intocado
        p = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                            os.path.join(RAIZ_OS, "scripts", "security-scan.ps1"), "-Path", tmp, "-SemRede",
                            "-Out", rel], capture_output=True, timeout=600)
        self.assertTrue(os.path.isfile(rel), "o scanner nao gravou o relatorio (rc %d)" % p.returncode)
        with open(rel, encoding="utf-8") as fh:
            return p.returncode, fh.read()

    def test_valor_colado_no_manifest_e_visto(self):
        rc, rel = self._scan("SLACK_URL = " + WEBHOOK_FALSO + "\n")
        self.assertIn("webhook do Slack", rel, "o scanner nao leu o cofre.manifest")
        self.assertEqual(rc, 1)
        self.assertNotIn("abcdefghijklmnop", rel, "o relatorio transcreveu o valor")

    def test_manifest_so_com_nomes_nao_gera_achado(self):
        rc, rel = self._scan("# nome | onde vive | como recriar\nAPI_TOKEN | Bitwarden: proj/API_TOKEN | painel\n")
        self.assertEqual(rc, 0, "nomes sem valor viraram achado")
        self.assertIn("0 sem extensao de texto nao lido", rel, "o .manifest ficou fora da leitura")


if __name__ == "__main__":
    unittest.main()
