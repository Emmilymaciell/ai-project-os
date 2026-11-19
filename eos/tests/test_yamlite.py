import unittest

from eos import yamlite


class TestYamlite(unittest.TestCase):
    def test_mapa_lista_escalares(self):
        d = yamlite.loads(
            "a: 1\n"
            "b: texto simples  # comentario\n"
            "c: 'C:\\Users\\x'\n"
            "d: \"aspas \\\"dupla\\\"\"\n"
            "e: true\n"
            "f: null\n"
            "g:\n"
            "  - um\n"
            "  - dois\n"
            "h:\n"
            "  - id: x\n"
            "    req: false\n"
            "  - id: y\n"
            "    req: true\n"
            "i: []\n"
            "j:\n"
            "  k: v\n")
        self.assertEqual(d["a"], 1)
        self.assertEqual(d["b"], "texto simples")
        self.assertEqual(d["c"], "C:\\Users\\x")  # aspas simples: barra invertida literal
        self.assertEqual(d["d"], 'aspas "dupla"')
        self.assertIs(d["e"], True)
        self.assertIsNone(d["f"])
        self.assertEqual(d["g"], ["um", "dois"])
        self.assertEqual(d["h"], [{"id": "x", "req": False}, {"id": "y", "req": True}])
        self.assertEqual(d["i"], [])
        self.assertEqual(d["j"], {"k": "v"})

    def test_lista_no_mesmo_recuo_da_chave(self):
        self.assertEqual(yamlite.loads("a:\n- x\n- y\nb: 1\n"), {"a": ["x", "y"], "b": 1})

    def test_recusas_falham_fechado_com_linha(self):
        casos = {
            "a: [x, y]\n": "fluxo",
            "a: &ancora 1\n": "nao suportado",
            "a: |\n  bloco\n": "nao suportado",
            "a: 1\na: 2\n": "duplicada",
            "a:\n\t- x\n": "TAB",
            "a: \"C:\\Users\"\n": "escape",
            "a: 1\n   b: 2\n": "indentacao",
        }
        for texto, trecho in casos.items():
            with self.assertRaises(yamlite.YamlErro, msg=texto) as cm:
                yamlite.loads(texto)
            self.assertIn(trecho, str(cm.exception), texto)
            self.assertIn("linha", str(cm.exception))

    def test_ida_e_volta(self):
        doc = {"identity": {"id": "x-1", "name": "Nome: com dois pontos", "n": 3, "b": False},
               "lista": [{"id": "a", "v": "C:\\x y"}, {"id": "b", "v": "true"}],
               "vazia": [], "simples": ["um", "dois #nao comentario"], "nulo": None, "num_txt": "007"}
        self.assertEqual(yamlite.loads(yamlite.dumps(doc) + "\n"), doc)

    def test_comentario_dentro_de_aspas_nao_corta(self):
        self.assertEqual(yamlite.loads("a: 'x # y'\n")["a"], "x # y")


if __name__ == "__main__":
    unittest.main()
