"""Ownership & Provenance (spec de 2026-10-12): um caso positivo E um negativo por item da tabela.

Repositorios Git temporarios com config LOCAL (a global desta maquina assina com a chave real da
mantenedora: aqui ela e sobrescrita no repositorio, nunca alterada), nuvem em diretorio
(DirStore) e journal em diretorio temporario. A assinatura usa uma chave ssh gerada no teste.
"""
import contextlib
import io
import json
import os
import re
import subprocess
import tempfile
import unittest
from unittest import mock

from eos import __main__ as cli
from eos import backup as bk
from eos import cloud, contract, gitinfo, ownership, paths, portability, registry
from eos.tests.test_e2e import Base, sh as sh_e2e


def sh(cwd, *args):
    r = subprocess.run(["git", "-c", "core.autocrlf=false", *args], cwd=cwd, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace"))
    return r.stdout.decode("utf-8", "replace")


def _sem_assinatura(repo):
    """Neutraliza a assinatura GLOBAL desta maquina so neste repositorio (config local)."""
    sh(repo, "config", "commit.gpgsign", "false")
    sh(repo, "config", "tag.gpgsign", "false")
    sh(repo, "config", "user.signingkey", "")


class BaseOwn(unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="eos-own-"))
        self.proj = os.path.join(self.tmp, "proj")
        os.makedirs(self.proj)
        sh(self.proj, "init", "-q", "-b", "main")
        sh(self.proj, "config", "user.name", "Dona Teste")
        sh(self.proj, "config", "user.email", "dona@example.com")
        sh(self.proj, "config", "core.autocrlf", "false")
        sh(self.proj, "config", "core.excludesfile", os.path.join(self.tmp, "sem-excludes-global"))
        _sem_assinatura(self.proj)
        sh(self.proj, "remote", "add", "origin", "https://github.com/dona/proj.git")
        self.maquina = {"_arquivo": "teste", "vars": {"T": self.tmp}, "projects": {}}
        self.store = cloud.DirStore(os.path.join(self.tmp, "nuvem"))
        self.journal = os.path.join(self.tmp, "journal")
        self.contrato = {
            "contract_version": 1,
            "identity": {"id": "proj", "name": "Proj", "type": "PROJECT", "category": "LAB", "status": "active",
                         "criticality": "low"},
            "workspace": {"local_path": "${T}/proj"},
            "git": {"enabled": True, "remote": "https://github.com/dona/proj"},
            "cloud": {"drive_root": "05 LAB/proj"},
            "backup": {"wip": "snapshot"},
            "portability": {"target_level": "L6"},
            "ownership": ownership.secao_padrao("Dona Teste", "dona", "LAB"),
        }
        self.contrato["ownership"]["signing"] = "none"
        gerados = ownership.gerar_arquivos(self.proj, self.contrato)
        self.assertEqual(set(gerados.values()), {"criado"}, gerados)
        self._w("README.md", "# Proj\n\nFerramenta interna.\n")
        self._w("app.py", "print(1)\n")
        sh(self.proj, "add", "-A")
        sh(self.proj, "commit", "-q", "-m", "c1")

    def tearDown(self):
        self.assertTrue(gitinfo.remover_arvore(self.tmp), "o teste deixou lixo em %s" % self.tmp)

    def _w(self, rel, txt):
        p = os.path.join(self.proj, *rel.split("/"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)

    def _commit(self, msg="c", nome=None, email=None):
        sh(self.proj, "add", "-A")
        extra = []
        if nome:
            extra = ["-c", "user.name=" + nome, "-c", "user.email=" + email]
        sh(self.proj, *extra, "commit", "-q", "--allow-empty", "-m", msg)

    def _v(self, contrato=None):
        return ownership.verificar(contrato or self.contrato, self.maquina, store=self.store, journal=self.journal)

    def _item(self, nome, contrato=None, r=None):
        r = r or self._v(contrato)
        return next(i for i in r["itens"] if i["item"] == nome)

    def _assinar(self, repo=None):
        """Chave ed25519 SEM senha gerada no teste; config so LOCAL ao repositorio."""
        repo = repo or self.proj
        kg = ownership.ssh_keygen()
        if not kg:
            self.skipTest("ssh-keygen indisponivel nesta maquina")
        chave = os.path.join(self.tmp, "chave-teste")
        if not os.path.exists(chave):
            subprocess.run([kg, "-q", "-t", "ed25519", "-N", "", "-C", "dona@example.com", "-f", chave],
                           check=True, capture_output=True)
        with open(chave + ".pub", encoding="utf-8") as f:
            tipo, b64 = f.read().split()[:2]
        allowed = os.path.join(self.tmp, "allowed_signers")
        with open(allowed, "w", encoding="utf-8", newline="\n") as f:
            f.write("dona@example.com %s %s\n" % (tipo, b64))
        for k, v in (("gpg.format", "ssh"), ("user.signingkey", chave), ("commit.gpgsign", "true"),
                     ("gpg.ssh.allowedSignersFile", allowed), ("gpg.ssh.program", kg)):
            sh(repo, "config", k, v)
        return chave


class TestCoerente(BaseOwn):
    def test_tudo_coerente_passa(self):
        r = self._v()
        self.assertEqual(r["status"], "PASS", json.dumps(r["itens"], indent=1, ensure_ascii=False))
        st = {i["item"]: i["status"] for i in r["itens"]}
        self.assertEqual(list(st), list(ownership.ITENS), "itens fora da ordem/tabela da spec")
        self.assertEqual(st["manifest"], "N/A")
        self.assertEqual(st["notice"], "N/A")
        self.assertEqual(st["signing"], "N/A")

    def test_check_e_read_only(self):
        antes = sh(self.proj, "status", "--porcelain", "--ignored")
        refs = gitinfo.refs(self.proj)
        self._v()
        self.assertEqual(sh(self.proj, "status", "--porcelain", "--ignored"), antes)
        self.assertEqual(gitinfo.refs(self.proj), refs)
        self.assertFalse(os.path.exists(self.journal), "o check gravou no journal")


class TestDeclaredOwner(BaseOwn):
    def test_project_sem_secao_falha(self):
        self.contrato.pop("ownership")
        r = self._v()
        self.assertEqual(r["status"], "FAIL")
        self.assertEqual(r["falhas"], ["declared_owner"])
        self.assertTrue(all(i["status"] == "N/A" for i in r["itens"][1:]))

    def test_classificado_sem_secao_e_na(self):
        for tipo in ("ARCHIVE", "COLLECTION", "REFERENCE_DATA"):
            c = dict(self.contrato, identity=dict(self.contrato["identity"], type=tipo))
            c.pop("ownership")
            self.assertEqual(self._v(c)["status"], "N/A", tipo)

    def test_secao_sem_creators_falha(self):
        self.contrato["ownership"]["creators"] = []
        it = self._item("declared_owner")
        self.assertEqual(it["status"], "FAIL")
        self.assertIn("creators", it["motivo"])


class TestArquivos(BaseOwn):
    def test_falta_ownership_md_e_warn(self):
        os.remove(os.path.join(self.proj, "OWNERSHIP.md"))
        it = self._item("ownership_files")
        self.assertEqual(it["status"], "WARN")
        self.assertIn("OWNERSHIP.md", it["motivo"])

    def test_authors_sem_extensao_vale(self):
        os.replace(os.path.join(self.proj, "AUTHORS.md"), os.path.join(self.proj, "AUTHORS"))
        self.assertEqual(self._item("ownership_files")["status"], "PASS")

    def test_provenance_file_declarado_e_o_exigido(self):
        self.contrato["ownership"]["provenance_file"] = "docs/ORIGEM.md"
        it = self._item("ownership_files")
        self.assertEqual(it["status"], "WARN")
        self.assertIn("docs/ORIGEM.md", it["motivo"])

    def test_notice(self):
        self.contrato["ownership"]["third_party"] = [{"name": "openpyxl", "license": "MIT"}]
        self.assertEqual(self._item("notice")["status"], "PASS")
        os.remove(os.path.join(self.proj, "NOTICE"))
        self.assertEqual(self._item("notice")["status"], "WARN")

    def test_license(self):
        self.assertEqual(self._item("license")["status"], "PASS")  # proprietary
        self.contrato["ownership"]["license"] = "MIT"
        it = self._item("license")
        self.assertEqual(it["status"], "WARN")
        self.assertIn("sem arquivo LICENSE", it["motivo"])
        self._w("LICENSE", "MIT License\n\nCopyright (c) 2026 Dona Teste\n")
        self.assertEqual(self._item("license")["status"], "PASS")
        self.contrato["ownership"]["license"] = ""
        self.assertEqual(self._item("license")["status"], "WARN")

    def test_caminho_local_ausente_nunca_passa(self):
        c = dict(self.contrato, workspace={"local_path": "${T}/nao-existe"})
        r = self._v(c)
        for nome in ("ownership_files", "git_identities", "contradictions"):
            self.assertEqual(self._item(nome, r=r)["status"], "WARN", nome)


class TestIdentidades(BaseOwn):
    def test_autor_fora_da_declaracao_e_contradicao(self):
        self._commit("intruso", "Intruso", "intruso@example.com")
        it = self._item("git_identities")
        self.assertEqual(it["status"], "FAIL")
        self.assertIn("contradicao", it["motivo"])
        self.assertIn("Intruso <intruso@example.com>", it["fora"])

    def test_contribuidor_declarado_explica(self):
        self._commit("contrib", "Colega Externa", "colega@example.com")
        self.contrato["ownership"]["contributors"] = ["Colega Externa"]  # terceiro: so o nome
        r = self._v()
        self.assertEqual(self._item("git_identities", r=r)["status"], "PASS")
        self.assertEqual(self._item("declared_owner", r=r)["status"], "PASS")

    def test_contributor_com_email_e_warn(self):
        self.contrato["ownership"]["contributors"] = ["Colega <colega@example.com>"]
        it = self._item("declared_owner")
        self.assertEqual(it["status"], "WARN")
        self.assertIn("so o nome", it["motivo"])

    def test_nome_acentuado_no_historico(self):
        self._commit("acento", "Emília Açaí", "emilia@example.com")
        it = self._item("git_identities")
        self.assertEqual(it["status"], "FAIL")
        self.assertIn("Emília Açaí <emilia@example.com>", it["fora"], "nome acentuado lido errado")
        self.contrato["ownership"]["contributors"] = ["EMÍLIA AÇAÍ"]
        self.assertEqual(self._item("git_identities")["status"], "PASS")

    def test_tool_account_explica(self):
        self._commit("ia", "Claude", "noreply@anthropic.com")
        self.assertEqual(self._item("git_identities")["status"], "FAIL")
        self.contrato["ownership"]["tool_accounts"] = ["Claude <noreply@anthropic.com>"]
        self.assertEqual(self._item("git_identities")["status"], "PASS")

    def test_comparacao_sem_caixa_por_email(self):
        self.contrato["ownership"]["creators"] = ["Outro Nome"]
        self.contrato["ownership"]["identities"] = ["Qualquer <DONA@Example.COM>"]
        self.assertEqual(self._item("git_identities")["status"], "PASS")

    def test_comparacao_sem_caixa_por_nome(self):
        self.contrato["ownership"]["creators"] = ["DONA teste"]
        self.assertEqual(self._item("git_identities")["status"], "PASS")

    def test_committer_tambem_conta(self):
        env = dict(os.environ, GIT_COMMITTER_NAME="Robo", GIT_COMMITTER_EMAIL="robo@ci")
        subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", "por robo"], cwd=self.proj, env=env,
                       check=True, capture_output=True)
        it = self._item("git_identities")
        self.assertEqual(it["status"], "FAIL")
        self.assertIn("Robo <robo@ci>", it["fora"])

    def test_mailmap_nao_mascara_intruso(self):
        # r8 Q3: %aN/%aE aplicavam o .mailmap do proprio repo, e um commit de terceiro passava como da titular
        self._commit("intruso", "Intruso", "intruso@example.com")
        self._w(".mailmap", "Dona Teste <dona@example.com> Intruso <intruso@example.com>\n")
        self._commit("mailmap")
        self.assertEqual(sh(self.proj, "log", "-1", "--skip=1", "--format=%aN").strip(), "Dona Teste",
                         "premissa: o .mailmap reescreve o intruso como a titular")
        it = self._item("git_identities")
        self.assertEqual(it["status"], "FAIL", it)
        self.assertIn("Intruso <intruso@example.com>", it["fora"])

    def test_nome_com_anotacao_explica(self):
        # r8 Q6: entrada declarada 'Nome (anotacao livre)' explica commit de 'Nome'
        self._commit("contrib", "Fulano Tal", "fulano@example.com")
        self.contrato["ownership"]["contributors"] = ["Fulano Tal (atribuido no pacote)"]
        self.assertEqual(self._item("git_identities")["status"], "PASS")
        self.contrato["ownership"]["contributors"] = ["Fulano (Tal)"]
        self.assertEqual(self._item("git_identities")["status"], "FAIL", "anotacao nao pode virar parte do nome")


class TestAssinatura(BaseOwn):
    def test_required_sem_config_falha(self):
        self.contrato["ownership"]["signing"] = "required"
        it = self._item("signing")
        self.assertEqual(it["status"], "FAIL", it)
        self.assertIn("nao configurada", it["motivo"])

    def test_recommended_sem_config_e_warn(self):
        self.contrato["ownership"]["signing"] = "recommended"
        self.assertEqual(self._item("signing")["status"], "WARN")

    def test_chave_declarada_inexistente_falha(self):
        self.contrato["ownership"]["signing"] = "required"
        sh(self.proj, "config", "gpg.format", "ssh")
        sh(self.proj, "config", "user.signingkey", os.path.join(self.tmp, "nao-existe.pub"))
        sh(self.proj, "config", "commit.gpgsign", "true")
        it = self._item("signing")
        self.assertEqual(it["status"], "FAIL")
        self.assertIn("NAO existe", it["motivo"])

    def test_repo_assinado_passa_e_o_nao_assinado_nao(self):
        self.contrato["ownership"]["signing"] = "required"
        self._assinar()
        # premissa: commit legado sem assinatura antes do primeiro assinado
        self._commit("assinado 1")
        self._commit("assinado 2")
        self.assertEqual(sh(self.proj, "log", "-1", "--format=%G?").strip(), "G", "premissa: commit assinado com G")
        it = self._item("signing")
        self.assertEqual(it["status"], "PASS", it)
        self.assertEqual(it["fatos"]["head"], "G")
        self.assertEqual(it["fatos"]["pct"], 100.0)
        self.assertEqual(it["fatos"]["commits_desde"], 2, "o legado nao assinado entrou na conta")
        # commit sem assinatura DEPOIS do primeiro assinado: deixa de passar
        sh(self.proj, "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", "sem assinatura")
        it = self._item("signing")
        self.assertEqual(it["status"], "WARN")
        self.assertEqual(it["fatos"]["pct"], 66.7)

    def test_principal_desconhecido_U_e_warn(self):
        self.contrato["ownership"]["signing"] = "required"
        self._assinar()
        self._commit("assinado")
        vazio = os.path.join(self.tmp, "allowed_vazio")
        with open(vazio, "w", encoding="utf-8") as f:
            f.write("")
        sh(self.proj, "config", "gpg.ssh.allowedSignersFile", vazio)
        it = self._item("signing")
        self.assertEqual(it["fatos"]["head"], "U", "premissa: assinatura boa de principal desconhecido")
        self.assertEqual(it["status"], "WARN")

    def _commit_com_outra_chave(self, msg):
        """Commit assinado por chave FORA do allowedSignersFile: %G?=U."""
        outra = os.path.join(self.tmp, "chave-outra")
        if not os.path.exists(outra):
            subprocess.run([ownership.ssh_keygen(), "-q", "-t", "ed25519", "-N", "", "-C", "outra@example.com",
                            "-f", outra], check=True, capture_output=True)
        sh(self.proj, "-c", "user.signingkey=" + outra, "commit", "-q", "--allow-empty", "-m", msg)

    def test_U_no_meio_com_G_no_head_e_warn(self):
        # r8 Q4: so G e assinado-verificado; U em qualquer commit desde o primeiro assinado -> WARN
        self.contrato["ownership"]["signing"] = "required"
        self._assinar()
        self._commit("G 1")
        self._commit_com_outra_chave("U no meio")
        self._commit("G 2")
        self.assertEqual(sh(self.proj, "log", "--format=%G?", "-3").split(), ["G", "U", "G"], "premissa")
        it = self._item("signing")
        self.assertEqual(it["status"], "WARN", it)
        self.assertEqual(it["fatos"]["assinados_desde"], 2)
        self.assertEqual(it["fatos"]["nao_verificados_desde"], 1)
        self.assertIn("allowedSignersFile", it["motivo"])

    def test_B_no_meio_e_fail(self):
        # r8 Q4: assinatura invalida em QUALQUER commit (nao so no HEAD) -> FAIL
        self.contrato["ownership"]["signing"] = "recommended"
        self._assinar()
        self._commit("G 1")
        self._commit("vai ser adulterado")
        corpo = sh(self.proj, "cat-file", "commit", "HEAD").replace("vai ser adulterado", "adulterado")
        r = subprocess.run(["git", "hash-object", "-t", "commit", "-w", "--stdin"], cwd=self.proj,
                           input=corpo.encode("utf-8"), capture_output=True, check=True)
        sh(self.proj, "update-ref", "refs/heads/main", r.stdout.decode().strip())
        self._commit("G 2")
        self.assertEqual(sh(self.proj, "log", "--format=%G?", "-3").split(), ["G", "B", "G"], "premissa")
        it = self._item("signing")
        self.assertEqual(it["status"], "FAIL", it)
        self.assertEqual(it["fatos"]["invalidos"], 1)
        self.assertIn("invalida", it["motivo"])

    def test_config_efetiva_local_vence_a_global(self):
        # a global desta maquina tem commit.gpgsign=true; a local do fixture diz false: vale a local
        f = ownership.fatos_assinatura(self.proj)
        self.assertFalse(f["commit_gpgsign"])
        self.assertIsNone(f["signingkey"])

    def test_none_e_na(self):
        self.assertEqual(self._item("signing")["status"], "N/A")


class TestRemoto(BaseOwn):
    def test_remote_owner_divergente_falha(self):
        sh(self.proj, "remote", "set-url", "origin", "https://github.com/outra/proj.git")
        it = self._item("remote_owner")
        self.assertEqual(it["status"], "FAIL")
        self.assertIn("outra", it["motivo"])

    def test_remote_sem_caixa(self):
        sh(self.proj, "remote", "set-url", "origin", "https://github.com/DONA/proj.git")
        self.assertEqual(self._item("remote_owner")["status"], "PASS")

    def test_sem_remoto_e_na(self):
        sh(self.proj, "remote", "remove", "origin")
        r = self._v()
        self.assertEqual(self._item("remote_owner", r=r)["status"], "N/A")
        self.assertEqual(self._item("codeowners", r=r)["status"], "N/A")

    def test_codeowners(self):
        self.assertEqual(self._item("codeowners")["status"], "PASS")
        self._w(".github/CODEOWNERS", "* @donaoutra\n")
        self.assertEqual(self._item("codeowners")["status"], "WARN", "@donaoutra nao e @dona")
        os.remove(os.path.join(self.proj, ".github", "CODEOWNERS"))
        self.assertEqual(self._item("codeowners")["status"], "WARN")
        self._w("docs/CODEOWNERS", "* @Dona\n")
        self.assertEqual(self._item("codeowners")["status"], "PASS")


class TestContradicoes(BaseOwn):
    def test_autor_estranho_no_readme_e_warn_com_arquivo_e_linha(self):
        self._w("README.md", "# Proj\n\n" + "Au" + "tor: Fulano de Tal\n")
        self._commit()
        it = self._item("contradictions")
        self.assertEqual(it["status"], "WARN")
        self.assertTrue(any(a.startswith("README.md:3:") for a in it["achados"]), it["achados"])

    def test_cabecalho_de_codigo_com_copyright_de_terceiro(self):
        self._w("app.py", "# " + "Copy" + "right 2020 Empresa Qualquer Ltda\nprint(1)\n")
        self._commit()
        it = self._item("contradictions")
        self.assertEqual(it["status"], "WARN")
        self.assertIn("app.py:1:", it["achados"][0])

    def test_nomes_declarados_e_terceiros_nao_contradizem(self):
        self._w("LICENSE", "Copy" + "right (c) 2026 Dona Teste\n\nTHE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE\n")
        self._w("NOTICE", "Copy" + "right (c) 2010-2024 openpyxl\n")
        self._commit()
        self.contrato["ownership"]["third_party"] = [{"name": "openpyxl", "license": "MIT"}]
        self.assertEqual(self._item("contradictions")["status"], "PASS")

    def test_variantes_do_marcador_de_autoria(self):
        # r8 Q5: negrito/sublinhado markdown e sufixo (a)/(s) tambem sao marcador de autoria
        for marcador in ("**Au" + "tor**:", "__Au" + "tor__:", "Au" + "tor(a):", "Au" + "thor(s):", "**Au" + "tor:**"):
            with self.subTest(marcador=marcador):
                self._w("README.md", "# Proj\n\n%s Fulano de Tal\n" % marcador)
                it = self._item("contradictions")
                self.assertEqual(it["status"], "WARN", marcador)
                self.assertTrue(any(a.startswith("README.md:3:") for a in it["achados"]), it)

    def test_nome_declarado_casa_por_palavra_inteira(self):
        # r8 Q5: contribuidor 'Ana' NAO cobre 'Juliana Souza' (substring)
        self.contrato["ownership"]["contributors"] = ["Ana"]
        self._w("README.md", "# Proj\n\n" + "Au" + "tor: Juliana Souza\n")
        self.assertEqual(self._item("contradictions")["status"], "WARN")
        self._w("README.md", "# Proj\n\n" + "Au" + "tor: Ana\n")
        self.assertEqual(self._item("contradictions")["status"], "PASS")

    def test_nome_declarado_sem_acento_e_sem_caixa(self):
        self.contrato["ownership"]["contributors"] = ["Jose Conceicao"]
        self._w("README.md", "# Proj\n\n" + "Au" + "tor: JOSÉ CONCEIÇÃO\n")
        self.assertEqual(self._item("contradictions")["status"], "PASS")

    def test_corte_de_arquivos_e_warn_dizendo_que_truncou(self):
        # r8 Q5: atingir MAX_ARQUIVOS nao pode sair PASS como se tudo tivesse sido lido
        with mock.patch.object(ownership, "MAX_ARQUIVOS", 1):
            it = self._item("contradictions")
        self.assertEqual(it["status"], "WARN", it)
        self.assertIn("truncad", it["motivo"])


class TestCertificar(BaseOwn):
    def _no_ledger(self):
        return [n for n in self.store.listar("99 RECOVERY/manifests/proj") if n.startswith("ownership-")]

    def _cert(self, **kw):
        return ownership.certificar(self.contrato, self.store, self.maquina, journal=self.journal, **kw)

    def test_certifica_grava_na_nuvem_e_no_journal_e_nao_no_projeto(self):
        antes = sh(self.proj, "status", "--porcelain", "--ignored")
        c = self._cert()
        self.assertTrue(c["ok"], c.get("recusado"))
        self.assertEqual(sh(self.proj, "status", "--porcelain", "--ignored"), antes, "certificar sujou o WIP")
        self.assertRegex(c["nuvem"], r"^99 RECOVERY/manifests/proj/ownership-\d{8}T\d{6}Z\.json$")
        salvo = json.loads(self.store.ler_texto(c["nuvem"]))
        with open(c["journal"], encoding="utf-8") as f:
            self.assertEqual(json.load(f), salvo)
        for k in ("project", "certified_at", "head", "ownership", "files", "authors", "signing", "remote",
                  "checks", "tool_version"):
            self.assertIn(k, salvo)
        self.assertEqual(salvo["head"], sh(self.proj, "rev-parse", "HEAD").strip())
        self.assertIn("AUTHORS.md", salvo["files"])
        self.assertEqual(salvo["files"]["AUTHORS.md"], gitinfo.sha256_arquivo(os.path.join(self.proj, "AUTHORS.md")))
        self.assertEqual(self._item("manifest")["status"], "PASS")

    def test_manifesto_divergente_depois_de_certificar(self):
        self.assertTrue(self._cert()["ok"])
        self._w("AUTHORS.md", "# Autoria\n\n- outra pessoa\n")
        it = self._item("manifest")
        self.assertEqual(it["status"], "WARN")
        self.assertIn("mudou: AUTHORS.md", it["motivo"])

    def test_manifesto_le_a_nuvem_quando_o_journal_nao_tem(self):
        c = self._cert()
        gitinfo.remover_arvore(self.journal)
        it = self._item("manifest")
        self.assertEqual(it["status"], "PASS")
        self.assertEqual(it["certificado"], c["certificado"]["certified_at"])

    def test_recusa_com_fail_e_nao_grava_nada(self):
        self._commit("intruso", "Intruso", "intruso@example.com")
        c = self._cert()
        self.assertFalse(c["ok"])
        self.assertIn("git_identities", c["recusado"])
        self.assertEqual(self._no_ledger(), [])
        self.assertFalse(os.path.exists(self.journal))

    def test_tag_assinada(self):
        self._assinar()
        self._commit("assinado")
        c = self._cert(tag=True)
        self.assertTrue(c["ok"], c.get("recusado"))
        t = c["certificado"]["tag"]
        self.assertRegex(t["name"], r"^ownership-\d{8}$")
        self.assertEqual(t["target"], sh(self.proj, "rev-parse", "HEAD").strip())
        obj = sh(self.proj, "cat-file", "-p", "refs/tags/" + t["name"])
        self.assertIn("-----BEGIN SSH SIGNATURE-----", obj)
        self.assertEqual(sh(self.proj, "cat-file", "-t", "refs/tags/" + t["name"]).strip(), "tag")
        # tag do dia ja existe: recusa, nao sobrescreve e nao grava outro certificado
        n = len(self._no_ledger())
        c2 = self._cert(tag=True)
        self.assertFalse(c2["ok"])
        self.assertIn("ja existe", c2["recusado"])
        self.assertEqual(len(self._no_ledger()), n)

    def test_certificado_nao_grava_email_em_claro(self):
        # r8 S2: authors com nome + SHA-256 do e-mail normalizado, nunca o e-mail
        import hashlib
        self._commit("contrib", "Colega Externa", " Colega@Example.COM ")
        self.contrato["ownership"]["contributors"] = ["Colega Externa"]
        c = self._cert()
        self.assertTrue(c["ok"], c.get("recusado"))
        # '@' so pode aparecer como handle do GitHub ('cita @dona'), nunca em endereco de e-mail
        email_re = r"[\w.+-]+@[\w-]+(\.[\w-]+)+"
        texto = self.store.ler_texto(c["nuvem"])
        self.assertNotRegex(texto, email_re)
        self.assertEqual(re.findall(r"@\S*", texto), ["@dona\""], "outro '@' alem do handle de CODEOWNERS")
        with open(c["journal"], encoding="utf-8") as f:
            self.assertNotRegex(f.read(), email_re)
        aut = json.loads(texto)["authors"]
        esperado = hashlib.sha256(b"colega@example.com").hexdigest()
        self.assertTrue(any(a["name"] == "Colega Externa" and a["email_sha256"] == esperado for a in aut), aut)
        self.assertTrue(all(re.fullmatch(r"[0-9a-f]{64}", a["email_sha256"]) for a in aut), aut)

    def test_tag_removida_se_a_gravacao_na_nuvem_falha(self):
        # r8 Q9: tag criada nesta execucao nao pode ficar orfa de certificado
        self._assinar()
        self._commit("assinado")
        with mock.patch.object(self.store, "escrever_texto", side_effect=cloud.NuvemErro("nuvem fora")):
            with self.assertRaises(ownership.OwnershipErro) as cm:
                self._cert(tag=True)
        self.assertIn("nuvem fora", str(cm.exception))
        self.assertRegex(str(cm.exception), r"tag ownership-\d{8} criada nesta execucao foi removida")
        self.assertEqual(sh(self.proj, "tag", "--list").strip(), "")
        self.assertFalse(os.path.exists(self.journal))

    def test_tag_preexistente_nao_e_removida_pela_falha(self):
        # so a tag criada NESTA execucao sai; a do dia ja existente recusa antes e fica
        self._assinar()
        self._commit("assinado")
        self.assertTrue(self._cert(tag=True)["ok"])
        nome = sh(self.proj, "tag", "--list").strip()
        with mock.patch.object(self.store, "escrever_texto", side_effect=cloud.NuvemErro("nuvem fora")):
            c = self._cert(tag=True)
        self.assertIn("ja existe", c["recusado"])
        self.assertEqual(sh(self.proj, "tag", "--list").strip(), nome)

    def test_tag_sem_assinatura_configurada_falha_fechado(self):
        c = self._cert(tag=True)
        self.assertFalse(c["ok"])
        self.assertIn("assinatura configurada", c["recusado"])
        self.assertEqual(sh(self.proj, "tag", "--list").strip(), "")
        self.assertEqual(self._no_ledger(), [])


class TestContratoEGeracao(unittest.TestCase):
    BASE = {
        "contract_version": 1,
        "identity": {"id": "proj-x", "name": "X", "type": "PROJECT", "category": "PROG", "status": "active",
                     "criticality": "low"},
        "workspace": {"local_path": "${AI_WORKSPACE}/x"},
        "git": {"enabled": True, "remote": "", "visibility": "private"},
        "cloud": {"drive_root": "01 PROG/proj-x"},
        "backup": {"wip": "snapshot"},
        "portability": {"target_level": "L6"},
    }

    def _c(self, **sec):
        import copy
        d = copy.deepcopy(self.BASE)
        d["ownership"] = ownership.secao_padrao("Dona", "dona", "PROG")
        d["ownership"].update(sec)
        return d

    def test_secao_padrao_valida_e_campo_desconhecido_e_erro(self):
        c = self._c()
        self.assertEqual(contract.validar(c, "proj-x.yaml"), [])
        self.assertEqual(c["ownership"]["employer_or_client"], "PROG")
        self.assertEqual(c["ownership"]["signing"], "required")
        self.assertIn("campo desconhecido", " ".join(contract.validar(self._c(dono="x"), "proj-x.yaml")))
        self.assertIn("fora do vocabulario", " ".join(contract.validar(self._c(signing="talvez"), "proj-x.yaml")))
        self.assertIn("obrigatorio", " ".join(contract.validar(self._c(third_party=[{"name": "a"}]), "proj-x.yaml")))

    def test_reference_data_e_tipo_classificado(self):
        import copy
        d = copy.deepcopy(self.BASE)
        d["identity"]["type"] = "REFERENCE_DATA"
        self.assertEqual(contract.validar(d, "proj-x.yaml"), [])
        self.assertIn("REFERENCE_DATA", contract.CLASSIFICADOS)
        r = portability.verificar(d, cloud.DirStore(tempfile.gettempdir()), {"vars": {}, "projects": {}}, rede=False)
        self.assertIsNone(r["nivel"])

    def test_gerar_arquivos_nao_sobrescreve(self):
        d = os.path.realpath(tempfile.mkdtemp(prefix="eos-own-g-"))
        try:
            c = self._c()
            with open(os.path.join(d, "NOTICE"), "w", encoding="utf-8") as f:
                f.write("meu")
            res = ownership.gerar_arquivos(d, c)
            self.assertEqual(res["NOTICE"], "existente")
            self.assertEqual(res[".github/CODEOWNERS"], "criado")
            with open(os.path.join(d, "NOTICE"), encoding="utf-8") as f:
                self.assertEqual(f.read(), "meu")
            with open(os.path.join(d, ".github", "CODEOWNERS"), encoding="utf-8") as f:
                self.assertEqual(f.read(), "* @dona\n")
            c["ownership"].pop("owner_github")
            self.assertIn("nao gerado", ownership.gerar_arquivos(d, c)[".github/CODEOWNERS"])
        finally:
            gitinfo.remover_arvore(d)

    def test_gerar_arquivos_respeita_equivalentes(self):
        # r8 Q10: CODEOWNERS na raiz/docs/.github e AUTHORS sem extensao ja cumprem o papel
        d = os.path.realpath(tempfile.mkdtemp(prefix="eos-own-g-"))
        try:
            os.makedirs(os.path.join(d, "docs"))
            for rel in ("docs/CODEOWNERS", "AUTHORS"):
                with open(os.path.join(d, *rel.split("/")), "w", encoding="utf-8") as f:
                    f.write("da titular")
            res = ownership.gerar_arquivos(d, self._c())
            self.assertEqual(res[".github/CODEOWNERS"], "existente (equivalente: docs/CODEOWNERS)")
            self.assertEqual(res["AUTHORS.md"], "existente (equivalente: AUTHORS)")
            self.assertFalse(os.path.exists(os.path.join(d, ".github")))
            self.assertFalse(os.path.exists(os.path.join(d, "AUTHORS.md")))
            self.assertEqual(res["OWNERSHIP.md"], "criado")
        finally:
            gitinfo.remover_arvore(d)
        d = os.path.realpath(tempfile.mkdtemp(prefix="eos-own-g-"))
        try:
            with open(os.path.join(d, "CODEOWNERS"), "w", encoding="utf-8") as f:
                f.write("* @dona\n")
            res = ownership.gerar_arquivos(d, self._c(), sobrescrever=True)
            self.assertEqual(res[".github/CODEOWNERS"], "existente (equivalente: CODEOWNERS)")
            self.assertFalse(os.path.exists(os.path.join(d, ".github")))
        finally:
            gitinfo.remover_arvore(d)

    def test_gerar_arquivos_nao_cria_a_raiz_do_projeto(self):
        # r8 Q2: so subpastas (.github); a pasta do projeto tem de existir
        d = os.path.realpath(tempfile.mkdtemp(prefix="eos-own-g-"))
        try:
            alvo = os.path.join(d, "nao-existe")
            with self.assertRaises(ownership.OwnershipErro):
                ownership.gerar_arquivos(alvo, self._c())
            self.assertFalse(os.path.exists(alvo))
        finally:
            gitinfo.remover_arvore(d)


class TestCli(BaseOwn):
    def _main(self, *argv):
        out = io.StringIO()
        with mock.patch.object(registry, "carregar", return_value={"proj": self.contrato}), \
                mock.patch.object(registry, "rebuild_index", return_value="(teste)"), \
                mock.patch.object(paths, "carregar_maquina", return_value=self.maquina), \
                mock.patch.object(cloud, "store_da_maquina", return_value=self.store), \
                mock.patch.object(ownership, "journal_padrao", return_value=self.journal), \
                contextlib.redirect_stdout(out):
            rc = cli.main(list(argv))
        return rc, out.getvalue()

    def test_ownership_check_codigos_de_saida(self):
        rc, out = self._main("ownership-check", "proj", "--json")
        self.assertEqual(rc, 0, out)
        self.assertEqual(json.loads(out)["status"], "PASS")
        self._commit("intruso", "Intruso", "intruso@example.com")
        rc, out = self._main("ownership-check", "proj")
        self.assertEqual(rc, 1)
        self.assertIn("contradicao", out)

    def test_ownership_certify_cli(self):
        rc, out = self._main("ownership-certify", "proj")
        self.assertEqual(rc, 0, out)
        self.assertIn("99 RECOVERY/manifests/proj/ownership-", out)

    def test_ownership_init_gera_so_o_que_falta_e_nao_commita(self):
        head = sh_e2e(self.proj, "rev-parse", "HEAD").strip()
        alvo = os.path.join(self.proj, "NOTICE")
        if os.path.exists(alvo):
            os.remove(alvo)
        with open(alvo, "w", encoding="utf-8") as f:
            f.write("da titular")
        rc, out = self._main("ownership-init", "proj")
        self.assertEqual(rc, 0, out)
        self.assertIn("NOTICE", out)
        self.assertIn("existente", out)
        with open(alvo, encoding="utf-8") as f:
            self.assertEqual(f.read(), "da titular", "ownership-init sobrescreveu arquivo da titular")
        self.assertEqual(sh_e2e(self.proj, "rev-parse", "HEAD").strip(), head, "ownership-init commitou")
        sem = dict(self.contrato)
        sem.pop("ownership")
        with mock.patch.object(registry, "carregar", return_value={"proj": sem}),                 mock.patch.object(paths, "carregar_maquina", return_value=self.maquina),                 mock.patch.object(cloud, "store_da_maquina", return_value=self.store),                 contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.main(["ownership-init", "proj"]), 2)

    def test_ownership_init_recusa_pasta_inexistente(self):
        # r8 Q2: antes criava a pasta (e os arquivos) num caminho que nao e o projeto
        self.contrato["workspace"] = {"local_path": "${T}/nao-existe"}
        rc, out = self._main("ownership-init", "proj")
        self.assertEqual(rc, 2, out)
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "nao-existe")))

    def test_ownership_init_recusa_pasta_que_nao_e_raiz_de_repo(self):
        os.makedirs(os.path.join(self.proj, "sub"))
        os.makedirs(os.path.join(self.tmp, "solta"))
        for alvo in ("proj/sub", "solta"):
            with self.subTest(alvo=alvo):
                self.contrato["workspace"] = {"local_path": "${T}/" + alvo}
                rc, out = self._main("ownership-init", "proj")
                self.assertEqual(rc, 2, out)
                self.assertEqual(os.listdir(os.path.join(self.tmp, *alvo.split("/"))), [], "criou arquivo fora da raiz")

    def test_ownership_init_respeita_override_da_maquina(self):
        # mesmo caminho que check/backup usam: override por id > workspace.local_path
        self.contrato["workspace"] = {"local_path": "${T}/nao-existe"}
        self.maquina["projects"] = {"proj": {"local_path": "${T}/proj"}}
        os.remove(os.path.join(self.proj, "NOTICE"))
        rc, out = self._main("ownership-init", "proj")
        self.assertEqual(rc, 0, out)
        self.assertTrue(os.path.isfile(os.path.join(self.proj, "NOTICE")))
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "nao-existe")))

    def test_status_tem_coluna_own(self):
        rc, out = self._main("status", "--sem-rede")
        cab = out.splitlines()[0].split()
        self.assertEqual(cab[:5], ["projeto", "niv", "safety", "operacao", "own"])
        linha = next(l for l in out.splitlines() if l.startswith("proj "))
        self.assertEqual(linha.split()[4], "PASS", out)


class TestEscadaIntocada(Base):
    """Ownership e INFORMATIVA: um projeto L6 sem secao (ou com ownership FAIL) continua L6."""

    def setUp(self):
        super().setUp()
        self.bare = os.path.join(self.tmp, "remoto.git")
        sh_e2e(self.tmp, "init", "-q", "--bare", self.bare)
        sh_e2e(self.proj, "remote", "add", "origin", self.bare)
        sh_e2e(self.proj, "push", "-q", "origin", "main", "feature")
        self.contrato["git"] = {"enabled": True, "remote": self.bare}
        cert = {"ok": True, "timestamp": bk.carimbo()}
        self.p = [mock.patch.object(portability, "_visibilidade_github", lambda url: "private"),
                  mock.patch.object(bk, "ultima_certificacao", lambda store, pid: cert)]
        for p in self.p:
            p.start()

    def tearDown(self):
        for p in self.p:
            p.stop()
        super().tearDown()

    def test_l6_sem_secao_ownership_continua_l6(self):
        self._backup()
        r = portability.verificar(self.contrato, self.store, self.maquina, rede=True)
        self.assertEqual(r["nivel"], "L6", json.dumps(r["dimensoes"], indent=1, ensure_ascii=False))
        self.assertEqual(r["dimensoes"]["ownership"]["status"], "FAIL")
        self.assertTrue(r["dimensoes"]["ownership"]["informativa"])
        self.assertNotIn("ownership", " ".join(r["bloqueios"]))

    def test_certificado_de_ownership_nao_vira_manifesto_de_backup(self):
        m = self._backup()
        self.store.escrever_texto(ownership.rel_ledger("proj", "29991231T235959Z"), json.dumps({"files": {}}))
        self.assertEqual(bk.ultimo_manifesto(self.store, "proj")["timestamp"], m["timestamp"])

    def test_l6_com_ownership_reprovado_continua_l6(self):
        self.contrato["ownership"] = ownership.secao_padrao("Outra Pessoa", "", "LAB")  # autor 't' nao explicado
        self._backup()
        r = portability.verificar(self.contrato, self.store, self.maquina, rede=True)
        self.assertEqual(r["dimensoes"]["ownership"]["status"], "FAIL")
        self.assertTrue(any(i["item"] == "git_identities" and i["status"] == "FAIL"
                            for i in r["dimensoes"]["ownership"]["itens"]))
        self.assertEqual(r["nivel"], "L6")
        self.assertTrue(r["seguro_trocar_computador"], r["motivos_nao"])


class TestTextosProjetoExistente(unittest.TestCase):
    """Projeto EXISTENTE: data do primeiro commit (nao 'hoje'), caminho real do certificado e ressalva
    de titularidade patrimonial so quando ha contexto contratual (2026-10-12)."""

    def _contrato(self, categoria):
        from eos import ownership
        return {"identity": {"id": "x", "name": "X"}, "git": {"remote": "https://github.com/o/x"},
                "cloud": {"drive_root": "05 LAB/x"},
                "ownership": ownership.secao_padrao("Fulana", "o", categoria)}

    def test_primeiro_commit_e_ressalva(self):
        import subprocess
        import tempfile
        from eos import ownership
        with tempfile.TemporaryDirectory() as d:
            env = dict(os.environ, GIT_AUTHOR_DATE="2020-01-02T03:04:05", GIT_COMMITTER_DATE="2020-01-02T03:04:05")
            for a in (["init", "-q"], ["-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false",
                                       "commit", "-q", "--allow-empty", "-m", "a"]):
                subprocess.run(["git", "-C", d] + a, check=True, env=env, capture_output=True)
            prog = ownership._textos(self._contrato("PROG"), d)
            lab = ownership._textos(self._contrato("LAB"), d)
            self.assertIn("- Primeiro commit: 2020-01-02", prog["PROVENANCE.md"])
            self.assertIn("99 RECOVERY/manifests/x/ownership-", prog["PROVENANCE.md"])
            self.assertIn("Lei 9.609/1998", prog["OWNERSHIP.md"])
            self.assertNotIn("Lei 9.609/1998", lab["OWNERSHIP.md"])
            self.assertIn("ainda sem commit", ownership._textos(self._contrato("LAB"), None)["PROVENANCE.md"])



class TestCertificadoSemCaminhoDaMaquina(unittest.TestCase):
    """O certificado vai para a nuvem e serve em outra maquina: caminho com o usuario do Windows
    nao entra (residuo apontado na r9)."""

    def test_caminhos_viram_nome(self):
        from eos import ownership
        g = ownership._sem_caminho_da_maquina({"signingkey": "C:/Users/Fulana Tal/.ssh/k.pub",
                                               "allowed_signers": r"C:\Users\Fulana\.ssh\allowed_signers",
                                               "pct": 100})
        self.assertEqual(g["signingkey"], "k.pub")
        self.assertEqual(g["allowed_signers"], "allowed_signers")
        self.assertEqual(g["pct"], 100)
        self.assertNotIn("Users", repr(g))

    def test_chave_literal_fica(self):
        from eos import ownership
        self.assertEqual(ownership._sem_caminho_da_maquina({"signingkey": "key::ssh-ed25519 AAAA"})["signingkey"],
                         "key::ssh-ed25519 AAAA")

if __name__ == "__main__":
    unittest.main()
