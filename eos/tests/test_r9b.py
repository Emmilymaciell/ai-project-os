"""Rodada r9 (2026-10-12): caminho com mais de 260 caracteres numa pasta cloud-mirror.

Achado real: um arquivo em output/ do Grupo1 com caminho longo dava FileNotFoundError no os.stat e
derrubava portability.verificar (logo, `eos status`) e o espelho do projeto.
"""
import os
import tempfile
import unittest

from eos import gitinfo, mirror, portability


def _longo(p):
    return "\\\\?\\" + os.path.abspath(p) if os.name == "nt" else p


@unittest.skipUnless(os.name == "nt", "caminho longo e limite do Windows")
class TestCaminhoLongo(unittest.TestCase):
    def setUp(self):
        self.raiz = tempfile.mkdtemp(prefix="eos-r9b-")
        partes = ["pasta-com-nome-comprido-%02d-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" % i for i in range(6)]
        self.dir = os.path.join(self.raiz, "dados", *partes)
        os.makedirs(_longo(self.dir))
        self.arq = os.path.join(self.dir, "Nota Tecnica de Analise.pdf")
        with open(_longo(self.arq), "wb") as f:
            f.write(b"conteudo")
        self.assertGreater(len(self.arq), 260, "a fixture nao produziu caminho longo")

    def tearDown(self):
        gitinfo.remover_arvore(_longo(self.raiz))

    def test_inventario_ve_o_arquivo_de_caminho_longo(self):
        tipo, arquivos, recusados = mirror.inventario_local(self.raiz, "dados")
        self.assertEqual(tipo, "dir")
        self.assertEqual(len(arquivos), 1, arquivos)
        (chave, (size, _)), = arquivos.items()
        self.assertTrue(chave.endswith("Nota Tecnica de Analise.pdf"))
        self.assertEqual(size, len(b"conteudo"))
        self.assertEqual(recusados, [])

    def test_check_nao_estoura(self):
        contrato = {"identity": {"id": "x"}, "cloud": {"drive_root": "05 LAB/x"},
                    "data": [{"path": "dados", "policy": "cloud-mirror"}]}
        motivos = portability._so_nesta_pasta(contrato, self.raiz, {}, store=None)
        self.assertTrue(any("dados" in m for m in motivos), motivos)


if __name__ == "__main__":
    unittest.main()
