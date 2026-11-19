"""Casos da rodada 5: um caso por achado das revisoes formais da r4 (QA e security, HEAD 508618f).

Cada caso descreve o comportamento CORRETO. Contra o 508618f os casos de defeito tem de
falhar, e pelo motivo do achado (resultado anotado abaixo depois da execucao).

  01 QA-1 / SEC-1  restore: grafias de .git que o NTFS aceita (GIT~1, '.git.', '.git ')
  02 QA-1 / SEC-1  restore: a recusa vale sobre o caminho RESOLVIDO pelo SO, nao so sobre o texto
  03 QA-1 / SEC-1  restore de ponta a ponta com GIT~1/hooks/post-checkout no indice do WIP
  04 QA-2          nome de segredo: .env.<ext de codigo>, secrets_prod.py etc. voltam a contar
  05 QA-2          a excecao e por CAMINHO EXATO declarado no contrato (secrets.allowed_paths);
                   05c cobre o backup (WIP e historico). Nao e caso de defeito: no 508618f ele
                   passa, porque la a regra relaxada nem marcava esses nomes. Existe para que a
                   mutacao do encadeamento de allowed_paths no backup tenha quem a mate
  06 QA-3          historico: segredo que so aparece em commit de merge; stash nao conta
  07 SEC-4         redacao: formas JSON e URL do valor, e o campo erro do cert
  08 QA-6          o motor recusa Python < 3.12 com mensagem, em vez de TypeError no meio
"""
import copy
import ctypes
import hashlib
import io
import json
import os
import tarfile
import unittest
import urllib.parse
from unittest import mock

from eos import __main__ as M
from eos import backup as bk
from eos import contract, gitinfo, portability, restore
from eos.tests.test_e2e import Base, sh
from eos.tests.test_r2 import _check


def _nome_curto(p):
    """Nome curto 8.3 do ultimo componente de p, ou None se o volume nao gera (ou nao e Windows)."""
    if os.name != "nt":
        return None
    buf = ctypes.create_unicode_buffer(1024)
    n = ctypes.windll.kernel32.GetShortPathNameW(p, buf, 1024)
    if not n:
        return None
    curto = os.path.basename(buf.value)
    return None if curto.lower() == os.path.basename(p).lower() else curto


class TestR5Restore(Base):
    # ---- 01 ---------------------------------------------------------------------------
    def test_01_grafias_ntfs_de_git_sao_recusadas(self):
        base = os.path.join(self.tmp, "dst01")
        os.makedirs(base)
        for rel in ("GIT~1/hooks/post-checkout", "git~2/config", "sub/GIT~1/config",
                    ".git./config", ".git /hooks/x", ".Git../config"):
            with self.subTest(rel):
                with self.assertRaises(restore.RestoreErro, msg="aceitou %r" % rel) as cm:
                    restore._caminho_seguro(base, rel)
                self.assertRegex(str(cm.exception), r"(?i)git")
        # controle negativo: nomes legitimos que lembram git continuam aceitos
        for rel in ("docs/.gitignore", ".gitattributes", "notas/git~rascunho.md", "src/digit~1x.py"):
            with self.subTest("aceito " + rel):
                restore._caminho_seguro(base, rel)

    # ---- 02 ---------------------------------------------------------------------------
    def test_02_recusa_vale_sobre_o_caminho_resolvido(self):
        base = os.path.realpath(os.path.join(self.tmp, "dst02"))
        os.makedirs(os.path.join(base, ".git", "hooks"))
        curto = _nome_curto(os.path.join(base, ".git"))
        if not curto:
            self.skipTest("o volume de %%TEMP%% nao gera nome 8.3 para .git: sem alias para resolver")
        # desliga a recusa lexica: so a checagem sobre o caminho resolvido pode recusar
        with mock.patch.object(restore, "_componente_git", lambda _n: False):
            with self.assertRaises(restore.RestoreErro, msg="alias %s aceito" % curto) as cm:
                restore._caminho_seguro(base, curto + "/hooks/post-checkout")
        self.assertRegex(str(cm.exception), r"(?i)\.git")

    # ---- 03 ---------------------------------------------------------------------------
    def test_03_restore_ponta_a_ponta_com_GIT_1_no_indice_do_wip(self):
        sonda = os.path.join(self.tmp, "sonda83")
        os.makedirs(os.path.join(sonda, ".git"))
        if not _nome_curto(os.path.join(sonda, ".git")):
            self.skipTest("o volume de %TEMP% nao gera nome 8.3: o vetor nao existe aqui")
        m0 = self._backup()
        tar_p = os.path.join(self.nuvem, *m0["artifacts"]["wip"]["rel"].split("/"))
        with open(tar_p, "rb") as f:
            tar_original = f.read()
        marca = os.path.join(self.tmp, "FORA-DO-DESTINO-r5.txt")
        carga = ("#!/bin/sh\necho executado > '%s'\n" % marca.replace("\\", "/")).encode()
        alvo = "GIT~1/hooks/post-checkout"
        with tarfile.open(fileobj=io.BytesIO(tar_original), mode="r:gz") as velho, tarfile.open(tar_p, "w:gz") as tar:
            for mb in velho.getmembers():
                tar.addfile(mb, velho.extractfile(mb) if mb.isfile() else None)
            info = tarfile.TarInfo("main/files/" + alvo)
            info.size = len(carga)
            tar.addfile(info, io.BytesIO(carga))
        m = copy.deepcopy(m0)
        m["artifacts"]["wip"]["sha256"] = gitinfo.sha256_arquivo(tar_p)
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        main["arquivos"][alvo] = hashlib.sha256(carga).hexdigest()
        m["wip_index"].sort(key=lambda w: w["rotulo"] != "main")
        dst = os.path.join(self.tmp, "r5-03")
        erro = None
        try:
            restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
        except Exception as e:  # noqa: BLE001
            erro = e
        self.assertFalse(os.path.exists(marca), "hook executado pelo restore: escrita FORA do destino")
        self.assertFalse(os.path.exists(os.path.join(dst, ".git", "hooks", "post-checkout")),
                         "o restore escreveu um hook em destino/.git/hooks pelo alias GIT~1")
        self.assertIsInstance(erro, restore.RestoreErro, "esperava RestoreErro, veio %r" % erro)


class TestR5Segredos(Base):
    # ---- 04 ---------------------------------------------------------------------------
    def test_04_nomes_que_a_r4_deixava_passar_voltam_a_contar(self):
        for n in (".env.ps1", ".env.sh", "config/.env.py", "secrets_prod.py", "local_secrets.py",
                  "credentials_dev.py", "api_keys_backup.md", "secrets.py", "tokens.md",
                  "tests/test_check_secrets.py", "docs/secret-handling.md"):
            with self.subTest(n):
                self.assertTrue(gitinfo.nome_de_segredo(n), "%s nao conta como nome de segredo" % n)
        for n in (".env.example", "secrets.manifest", "docs/Secretaria/ata.pdf", "app.py"):
            with self.subTest("nao conta " + n):
                self.assertFalse(gitinfo.nome_de_segredo(n))

    def test_04b_env_ps1_nao_rastreado_nao_sobe(self):
        v = "VALOR-FABRICADO-R5-04-QWERTYUIOPASDFGH"
        self._w(".env.ps1", "$env:API_TOKEN='%s'\n" % v)
        m = self._backup()
        tar_p = os.path.join(self.nuvem, *m["artifacts"]["wip"]["rel"].split("/"))
        with tarfile.open(tar_p, "r:gz") as tar:
            vazou = [mb.name for mb in tar.getmembers() if mb.isfile() and v.encode() in tar.extractfile(mb).read()]
        self.assertEqual(vazou, [], ".env.ps1 subiu para a nuvem: %s" % vazou)
        self.assertEqual(_check(self)["dimensoes"]["secrets"]["status"], "FAIL")

    # ---- 05 ---------------------------------------------------------------------------
    def test_05_excecao_por_caminho_exato_no_contrato(self):
        self._w("docs/secret-handling.md", "# politica: valores nunca no Git\n")
        self._w("tests/test_check_secrets.py", "def test(): pass\n")
        sh(self.proj, "add", "docs/secret-handling.md", "tests/test_check_secrets.py")
        sh(self.proj, "commit", "-q", "-m", "docs", "--", "docs/secret-handling.md", "tests/test_check_secrets.py")
        sec = _check(self)["dimensoes"]["secrets"]
        self.assertEqual(sec["status"], "FAIL", "sem declaracao, o nome conta: %s" % sec)
        self.contrato["secrets"]["allowed_paths"] = ["docs/secret-handling.md"]
        self.assertEqual(contract.validar(self.contrato), [])
        sec = _check(self)["dimensoes"]["secrets"]
        self.assertEqual(sec["status"], "FAIL", "so um dos dois foi declarado: %s" % sec)
        self.assertIn("test_check_secrets.py", sec["motivo"])
        self.assertNotIn("secret-handling.md", sec["motivo"])
        self.contrato["secrets"]["allowed_paths"].append("tests/test_check_secrets.py")
        sec = _check(self)["dimensoes"]["secrets"]
        self.assertNotIn("test_check_secrets.py", sec["motivo"])
        self.assertNotIn("secret-handling.md", sec["motivo"])
        # o MESMO nome em outra pasta nao herda a excecao
        self._w("outro/secret-handling.md", "x\n")
        w = gitinfo.wip(self.proj, permitidos=self.contrato["secrets"]["allowed_paths"])
        self.assertIn("outro/secret-handling.md", w["segredos"])
        self.assertNotIn("docs/secret-handling.md", w["segredos"])

    def test_05b_excecao_nunca_vale_para_env_chave_ou_caminho_fora(self):
        # controle positivo: o campo existe e aceita um caminho de documentacao; sem isto, a
        # recusa abaixo poderia ser so "campo desconhecido"
        c = copy.deepcopy(self.contrato)
        c["secrets"]["allowed_paths"] = ["docs/secret-handling.md", "tests/test_check_secrets.py"]
        self.assertEqual(contract.validar(c), [])
        for p in (".env", "config/.env.local", ".env.ps1", "id_rsa", "deploy/server.pem", "cookies",
                  "../fora/secrets.py", "C:/x/secrets.py", "/abs/secrets.py", "docs/*secrets*.md"):
            with self.subTest(p):
                c = copy.deepcopy(self.contrato)
                c["secrets"]["allowed_paths"] = [p]
                erros = contract.validar(c)
                self.assertTrue(any("allowed_paths" in e for e in erros), "aceitou %r: %s" % (p, erros))

    def test_05c_backup_respeita_a_excecao_no_wip_e_no_historico(self):
        self._w("docs/secret-handling.md", "# politica\n")
        sh(self.proj, "add", "docs/secret-handling.md")
        sh(self.proj, "commit", "-q", "-m", "politica", "--", "docs/secret-handling.md")
        self._w("docs/tokens-howto.md", "como girar tokens, sem valor\n")  # nao rastreado
        self.contrato["secrets"]["allowed_paths"] = ["docs/secret-handling.md", "docs/tokens-howto.md"]
        m = self._backup()
        cita = [p for p in m["pendencias"] if "secret-handling" in p or "tokens-howto" in p]
        self.assertEqual(cita, [], "caminho declarado em allowed_paths virou pendencia: %s" % cita)
        self.assertNotIn("docs/secret-handling.md", m.get("segredos_no_historico", []))
        tar_p = os.path.join(self.nuvem, *m["artifacts"]["wip"]["rel"].split("/"))
        with tarfile.open(tar_p, "r:gz") as tar:
            nomes = tar.getnames()
        self.assertIn("main/files/docs/tokens-howto.md", nomes, "o arquivo declarado nao subiu no WIP")

    # ---- 06 ---------------------------------------------------------------------------
    def test_06_segredo_que_so_aparece_em_merge_e_achado(self):
        sh(self.proj, "stash", "push", "-q", "-u", "-m", "limpa")  # arvore limpa para os merges
        sh(self.proj, "checkout", "-q", "-b", "lado")
        self._w("lado.txt", "1\n")
        sh(self.proj, "add", "lado.txt")
        sh(self.proj, "commit", "-q", "-m", "lado")
        sh(self.proj, "checkout", "-q", "main")
        self._w("main.txt", "1\n")
        sh(self.proj, "add", "main.txt")
        sh(self.proj, "commit", "-q", "-m", "main")
        sh(self.proj, "merge", "-q", "--no-ff", "--no-commit", "lado")
        self._w(".env", "API_TOKEN=VALOR-FABRICADO-R5-06\n")
        sh(self.proj, "add", "-f", ".env")
        sh(self.proj, "commit", "-q", "-m", "merge que adiciona .env")
        sh(self.proj, "checkout", "-q", "-b", "lado2", "HEAD~1")
        self._w("lado2.txt", "1\n")
        sh(self.proj, "add", "lado2.txt")
        sh(self.proj, "commit", "-q", "-m", "lado2")
        sh(self.proj, "checkout", "-q", "main")
        sh(self.proj, "merge", "-q", "--no-ff", "--no-commit", "lado2")
        sh(self.proj, "rm", "-q", "--cached", ".env")
        os.remove(os.path.join(self.proj, ".env"))
        sh(self.proj, "commit", "-q", "-m", "merge que remove .env")
        sh(self.proj, "branch", "-D", "lado2")
        sh(self.proj, "stash", "drop", "-q")
        simples = sh(self.proj, "log", "--all", "--format=", "--name-only")
        self.assertNotIn(".env", simples.split(), "premissa: o log sem -m nao mostra o .env")
        self.assertIn("API_TOKEN=VALOR-FABRICADO-R5-06", sh(self.proj, "log", "--all", "-m", "-p"))
        self.assertIn(".env", gitinfo.segredos_no_historico(self.proj))

    def test_06b_stash_nao_e_historico(self):
        self._w(".env", "API_TOKEN=x\n")
        sh(self.proj, "stash", "push", "-q", "-u", "-m", "so no stash")
        self.assertNotIn(".env", gitinfo.segredos_no_historico(self.proj),
                         "o .env so existe no stash, que nao vai no bundle")


class TestR5Redacao(Base):
    SEG = 'VALOR-R5 "aspas" \\barra/QWERTY+=XYZ123'

    def test_07_formas_json_e_url_do_valor_sao_redigidas(self):
        self._backup()
        self.contrato["environment"]["smoke_command"] = (
            "Write-Output ($env:EOS_R5_SEG | ConvertTo-Json); "
            "Write-Output ([uri]::EscapeDataString($env:EOS_R5_SEG)); "
            "Write-Output ([uri]::EscapeDataString($env:EOS_R5_SEG).Replace('%20','+')); exit 0")
        with mock.patch.dict(os.environ, {"EOS_R5_SEG": self.SEG}):
            c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertIn("smoke", c, c.get("erro"))
        cauda = c["smoke"]["cauda"]
        formas = {"json": json.dumps(self.SEG)[1:-1], "url": urllib.parse.quote(self.SEG, safe=""),
                  "url+": urllib.parse.quote_plus(self.SEG, safe="")}
        self.assertIn("<redigido>", cauda, "premissa: o smoke imprimiu algo")
        for nome, f in formas.items():
            with self.subTest(nome):
                self.assertNotIn(f, cauda, "forma %s do valor ficou na cauda" % nome)

    def test_07b_campo_erro_do_cert_e_redigido(self):
        self._backup()
        with mock.patch.dict(os.environ, {"EOS_R5_SEG": self.SEG}), \
                mock.patch.object(restore, "restaurar", side_effect=RuntimeError("falhou com %s" % self.SEG)):
            c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertIn("erro", c)
        self.assertNotIn(self.SEG, c["erro"])
        self.assertNotIn("QWERTY+=XYZ123", c["erro"])
        nuvem = json.dumps(bk.ultima_certificacao(self.store, "proj"), ensure_ascii=False)
        self.assertNotIn("QWERTY+=XYZ123", nuvem)


class TestR5Python(unittest.TestCase):
    def test_08_python_antigo_e_recusado_com_mensagem(self):
        with self.assertRaises(SystemExit) as cm:
            M.exigir_python((3, 11, 9))
        self.assertRegex(str(cm.exception.code), r"3\.12")
        M.exigir_python((3, 12, 0))
        M.exigir_python((3, 13, 9))


if __name__ == "__main__":
    unittest.main()
