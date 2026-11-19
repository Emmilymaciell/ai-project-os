import copy
import os
import unittest

from eos import contract, registry

BASE = {
    "contract_version": 1,
    "identity": {"id": "proj-x", "name": "X", "type": "PROJECT", "category": "LAB", "status": "active", "criticality": "low"},
    "workspace": {"local_path": "${AI_WORKSPACE}/x"},
    "git": {"enabled": True, "remote": "https://github.com/dona/proj-x", "visibility": "private"},
    "cloud": {"drive_root": "05 LAB/proj-x"},
    "backup": {"wip": "snapshot"},
    "portability": {"target_level": "L6"},
}


class TestContrato(unittest.TestCase):
    def test_valido(self):
        self.assertEqual(contract.validar(copy.deepcopy(BASE), "proj-x.yaml"), [])

    def _erros(self, mut):
        d = copy.deepcopy(BASE)
        mut(d)
        return " | ".join(contract.validar(d, "proj-x.yaml"))

    def test_campo_desconhecido_e_erro_nao_padrao(self):
        self.assertIn("campo desconhecido", self._erros(lambda d: d["git"].update(remtoe="x")))

    def test_enum_fora_do_vocabulario(self):
        self.assertIn("fora do vocabulario", self._erros(lambda d: d["identity"].update(type="REPO")))

    def test_publico_nunca_e_padrao(self):
        self.assertIn("public exige decisao", self._erros(lambda d: d["git"].update(visibility="public")))

    def test_id_bate_com_arquivo(self):
        self.assertIn("nao bate com o arquivo", self._erros(lambda d: d["identity"].update(id="outro")))

    def test_project_exige_blocos(self):
        self.assertIn("backup: obrigatorio para type PROJECT", self._erros(lambda d: d.pop("backup")))

    def test_remoto_nao_github(self):
        self.assertIn("nao e URL https do GitHub", self._erros(lambda d: d["git"].update(remote="git@x:y")))

    def test_sharepoint_nao_e_backup(self):
        e = self._erros(lambda d: d.update(external_sources=[{"id": "sp", "type": "sharepoint", "role": "backup",
                                                               "required_for_operation": True}]))
        self.assertIn("SharePoint nao e backup", e)

    def test_tipo_errado(self):
        self.assertIn("esperava true/false", self._erros(lambda d: d["git"].update(enabled="sim")))

    def test_registry_real_do_repositorio_e_valido(self):
        if not os.path.isdir(registry.pasta()):
            self.skipTest("registry ainda nao existe")
        itens = registry.carregar()
        self.assertGreater(len(itens), 0, "registry vazio passaria por vacuidade")


if __name__ == "__main__":
    unittest.main()
