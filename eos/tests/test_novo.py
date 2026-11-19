"""Nascimento protegido (`eos new`) sobre diretorio temporario, SEM rede.

  - gh falso: registra cada chamada; `repo create` cria um repo bare local; `repo view` responde
    a visibilidade configurada (PRIVATE por padrao);
  - git de rede falso: o MESMO git real, com `-c url.<dir>/.insteadOf=https://github.com/` so na
    chamada (push/ls-remote vao para o bare local; a config do repo continua com a URL do GitHub);
  - nuvem: cloud.DirStore num diretorio;
  - config global do Git ISOLADA: HOME aponta para um .gitconfig do fixture (a do computador nunca
    e lida nem tocada). E por ela que o caso de assinatura liga commit.gpgsign.
"""
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

from eos import cloud, contract, gitinfo, novo, ownership, registry, yamlite


def sh(cwd, *args):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode("utf-8", "replace"))
    return r.stdout.decode("utf-8", "replace")


def _url_local(base):
    return "url.%s/.insteadOf=https://github.com/" % base.replace("\\", "/")


class GhFalso:
    def __init__(self, base, visibilidade="PRIVATE"):
        self.base, self.vis, self.chamadas, self.falhar_create = base, visibilidade, [], False

    def bare(self, alvo):
        return os.path.join(self.base, *alvo.split("/"))

    def __call__(self, args):
        args = list(args)
        self.chamadas.append(args)
        if args[:2] == ["repo", "view"]:
            if not os.path.isdir(self.bare(args[2])):
                return 1, "", "GraphQL: Could not resolve to a Repository with the name '%s'. (repository)" % args[2]
            return 0, json.dumps({"visibility": self.vis}), ""
        if args[:2] == ["repo", "create"]:
            if self.falhar_create:
                return 1, "", "HTTP 502: falha simulada"
            if "--private" not in args:
                raise AssertionError("repo create sem --private: %s" % args)
            os.makedirs(self.bare(args[2]))
            sh(self.bare(args[2]), "init", "-q", "--bare")
            return 0, "https://github.com/%s\n" % args[2], ""
        return 99, "", "nao simulado: %s" % args

    def criacoes(self):
        return [c for c in self.chamadas if c[:2] == ["repo", "create"]]


class GitRedeFalso:
    def __init__(self, base):
        self.base, self.chamadas = base, []

    def __call__(self, raiz, *args):
        self.chamadas.append(args)
        r = subprocess.run(["git", "-c", _url_local(self.base), "-C", raiz, *args], capture_output=True)
        return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


class ScanFalso:
    """Varredura de seguranca falsa: devolve o rc configurado e registra quem varreu e quando
    (quantos pushes ja tinham acontecido no momento da varredura)."""

    def __init__(self, rede, rc=0):
        self.rede, self.rc, self.chamadas = rede, rc, []

    def __call__(self, destino, pid):
        pushes = len([c for c in self.rede.chamadas if c[:1] == ("push",)])
        self.chamadas.append((destino, pid, pushes))
        return self.rc, os.path.join(destino, "..", "relatorio-%s.md" % pid), "saida simulada"


def _ssh_keygen():
    r = subprocess.run(["git", "--exec-path"], capture_output=True, text=True)
    raiz_git = os.path.normpath(os.path.join(r.stdout.strip(), "..", "..", ".."))
    for c in (os.path.join(raiz_git, "usr", "bin", "ssh-keygen.exe"), shutil.which("ssh-keygen")):
        if c and os.path.isfile(c):
            return c
    return None


class Base(unittest.TestCase):
    PID = "lab-teste"

    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="eos-novo-"))
        self.home = os.path.join(self.tmp, "home")
        os.makedirs(self.home)
        self._gitconfig({"user": {"name": "Teste Titular", "email": "titular@exemplo.invalid"},
                         "core": {"autocrlf": "false", "safecrlf": "false"}})
        p = mock.patch.dict(os.environ, {"HOME": self.home, "XDG_CONFIG_HOME": os.path.join(self.home, ".config")})
        p.start()
        self.addCleanup(p.stop)
        self.ws = os.path.join(self.tmp, "ws")
        self.plat = os.path.join(self.tmp, "plat")
        os.makedirs(os.path.join(self.plat, "registry", "projects"))
        self.nuvem = os.path.join(self.tmp, "nuvem")
        self.github = os.path.join(self.tmp, "github")
        self.estado = os.path.join(self.tmp, "estado")
        self.maquina = {"_arquivo": "teste", "projects": {},
                        "vars": {"AI_WORKSPACE": self.ws, "EOS_STAGING": os.path.join(self.tmp, "stg")}}
        self.gh = GhFalso(self.github)
        self.rede = GitRedeFalso(self.github)
        self.deps = novo.Dependencias(gh=self.gh, git_rede=self.rede, store=cloud.DirStore(self.nuvem), rede=False)
        self.scan = ScanFalso(self.rede)
        self.deps.scan = self.scan  # nunca a varredura real (powershell) nos testes de fluxo

    def tearDown(self):
        self.assertTrue(gitinfo.remover_arvore(self.tmp), "o teste deixou lixo em %s" % self.tmp)

    def _gitconfig(self, secoes):
        with open(os.path.join(self.home, ".gitconfig"), "w", encoding="utf-8", newline="\n") as f:
            for s, kv in secoes.items():
                f.write("[%s]\n" % s)
                for k, v in kv.items():
                    f.write("\t%s = %s\n" % (k, v))

    def destino(self, pid=None, cat="LAB"):
        return os.path.join(self.ws, *novo.BASE_WORKSPACE[cat].split("\\"), pid or self.PID)

    def yaml(self, pid=None):
        return os.path.join(self.plat, "registry", "projects", (pid or self.PID) + ".yaml")

    def nascer(self, pid=None, nome="Projeto Teste", categoria="LAB", **kw):
        return novo.nascer(pid or self.PID, nome, categoria, maquina=self.maquina, deps=self.deps, raiz_repo=self.plat,
                           dir_estado=self.estado, log=lambda *_: None, **kw)

    def cli(self, *args, **kw):
        linhas = []
        rc = novo.cli(list(args), self.maquina, deps=self.deps, out=linhas.append, raiz_repo=self.plat,
                      dir_estado=self.estado, log=lambda *_: None, **kw)
        return rc, "\n".join(linhas)

    def arvore(self):
        out = set()
        for r, ds, fs in os.walk(self.tmp):
            for x in ds + fs:
                out.add(os.path.relpath(os.path.join(r, x), self.tmp))
        return out

    def commits(self, d):
        return sh(d, "rev-list", "--count", "HEAD").strip()


class TestRegras(unittest.TestCase):
    def test_nome_do_repo_por_prefixo_da_categoria(self):
        self.assertEqual(novo.nome_repo("prog-grd", "PROG"), "prog-grd")
        self.assertEqual(novo.nome_repo("grd", "PROG"), "prog-grd")
        self.assertEqual(novo.nome_repo("conversor-utm", "LAB"), "lab-conversor-utm")
        self.assertEqual(novo.nome_repo("personal-x", "PERSONAL"), "personal-x")
        self.assertEqual(novo.nome_repo("x", "UNIVERSITY"), "university-x")
        self.assertEqual(novo.nome_repo("x", "PORTFOLIO"), "portfolio-x")
        self.assertEqual(novo.nome_repo("progx", "PROG"), "prog-progx", "prefixo exige o hifen")
        self.assertEqual(novo.nome_repo("emmily-ai-project-os", "PLATFORM"), "emmily-ai-project-os")

    def test_drive_root_e_o_mesmo_mapeamento_do_registry_real(self):
        usados = {}
        for pid, c in registry.carregar().items():
            raiz = (c.get("cloud") or {}).get("drive_root")
            if not raiz:  # EXTERNAL_SOURCE nao tem nuvem propria
                continue
            usados.setdefault(c["identity"]["category"], set()).add(raiz.split("/")[0])
        self.assertTrue(usados, "registry real vazio: o teste passaria por vacuidade")
        for cat, raizes in usados.items():
            self.assertEqual(raizes, {novo.DRIVE_ROOT[cat]}, "categoria %s" % cat)

    def test_caminho_do_workspace(self):
        self.assertEqual(novo.caminho_bruto("x", "PROG"), "${AI_WORKSPACE}\\work\\prog\\x")
        self.assertEqual(novo.caminho_bruto("x", "LAB"), "${AI_WORKSPACE}\\ai-lab\\x")
        self.assertEqual(novo.caminho_bruto("x", "PERSONAL"), "${AI_WORKSPACE}\\personal\\x")
        self.assertEqual(novo.caminho_bruto("x", "UNIVERSITY"), "${AI_WORKSPACE}\\university\\x")
        self.assertEqual(novo.caminho_bruto("x", "PORTFOLIO"), "${AI_WORKSPACE}\\portfolio\\x")
        self.assertEqual(novo.caminho_bruto("x", "PLATFORM"), "${AI_WORKSPACE}\\_platform\\x")


class TestDryRun(Base):
    def test_dry_run_nao_cria_nada(self):
        antes = self.arvore()
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB", "--dry-run")
        self.assertEqual(rc, 0, saida)
        self.assertEqual(self.arvore(), antes, "o dry-run criou ou mudou algo")
        self.assertEqual(self.gh.chamadas, [], "o dry-run chamou o gh")
        self.assertEqual(self.rede.chamadas, [], "o dry-run falou com o remoto")
        self.assertFalse(os.path.exists(self.yaml()))
        self.assertFalse(os.path.exists(self.destino()))
        self.assertFalse(os.path.exists(self.estado), "o dry-run gravou diario")
        for esperado in ("PLANO (dry-run", "https://github.com/Emmilymaciell/lab-teste", "05 LAB/lab-teste",
                         "PROVENANCE.md", "AGENTS.md", ".github/CODEOWNERS", "planejado"):
            self.assertIn(esperado, saida)


class TestNascimento(Base):
    def test_nascimento_completo_nunca_L0(self):
        rel = self.nascer()
        self.assertTrue(rel["ok"], json.dumps(rel["passos"], indent=1, ensure_ascii=False))
        d = self.destino()
        for f in ("docs/STATE.md", "docs/HANDOFF.md", "docs/decisions/ADR-0001-nascimento-protegido.md",
                  "PROVENANCE.md", "OWNERSHIP.md", "AUTHORS.md", "NOTICE", ".github/CODEOWNERS", ".env.example",
                  ".gitignore", ".gitattributes", "CLAUDE.md", "AGENTS.md", "project.yaml", "requirements.txt",
                  "tests/run-tests.ps1", "tests/conftest.py", "bootstrap.ps1"):
            self.assertTrue(os.path.isfile(os.path.join(d, *f.split("/"))), f)
        # trilha python: a PowerShell sai (o runner recusa as duas)
        self.assertFalse(os.path.exists(os.path.join(d, "tests", "_harness.ps1")))
        self.assertFalse(os.path.exists(os.path.join(d, "tests", "suites")))
        # nenhum placeholder sobreviveu, dotfiles incluidos
        for r, ds, fs in os.walk(d):
            ds[:] = [x for x in ds if x != ".git"]
            for f in fs:
                with open(os.path.join(r, f), encoding="utf-8", errors="replace") as fh:
                    self.assertIsNone(re.search(r"\{\{[A-Z_]+\}\}", fh.read()), os.path.join(r, f))
        with open(os.path.join(d, ".github", "CODEOWNERS"), encoding="utf-8") as fh:
            self.assertIn("* @Emmilymaciell", fh.read())
        # git: um commit em main, arvore limpa, tudo rastreado
        self.assertEqual(self.commits(d), "1")
        self.assertEqual(sh(d, "symbolic-ref", "--short", "HEAD").strip(), "main")
        self.assertEqual(sh(d, "status", "--porcelain", "--ignored").strip(), "")
        self.assertEqual(sh(d, "config", "--get", "remote.origin.url").strip(), "https://github.com/Emmilymaciell/lab-teste")
        # remoto: criado PRIVADO e com a main publicada
        self.assertEqual(len(self.gh.criacoes()), 1)
        self.assertIn("--private", self.gh.criacoes()[0])
        bare = self.gh.bare("Emmilymaciell/lab-teste")
        self.assertEqual(sh(bare, "rev-parse", "main").strip(), sh(d, "rev-parse", "HEAD").strip())
        # contrato no registry, valido, carregavel
        itens = registry.carregar(self.plat)
        c = itens[self.PID]
        self.assertEqual(c["cloud"]["drive_root"], "05 LAB/lab-teste")
        self.assertEqual(c["workspace"]["local_path"], "${AI_WORKSPACE}\\ai-lab\\lab-teste")
        self.assertEqual(c["git"]["remote"], "https://github.com/Emmilymaciell/lab-teste")
        self.assertEqual(c["git"]["visibility"], "private")
        self.assertEqual(c["portability"]["target_level"], "L6")
        self.assertEqual(c["ai"]["adapters"], ["CLAUDE.md", "AGENTS.md"])
        # Drive root e primeiro backup na nuvem
        self.assertTrue(os.path.isdir(os.path.join(self.nuvem, "05 LAB", "lab-teste")))
        store = cloud.DirStore(self.nuvem)
        from eos import backup as bk
        m = bk.ultimo_manifesto(store, self.PID)
        self.assertIsNotNone(m)
        self.assertFalse(m.get("incompleto"), m.get("pendencias"))
        # nivel: sem rede o remoto fica UNKNOWN (nunca PASS por suposicao), mas nunca L0
        self.assertEqual(rel["nivel"], "L1")
        dims = rel["verificacao"]["dimensoes"]
        self.assertEqual(dims["remote"]["status"], "UNKNOWN")
        for dim in ("git", "backup", "environment", "secrets", "paths", "state"):
            self.assertEqual(dims[dim]["status"], "PASS", "%s: %s" % (dim, dims[dim]["motivo"]))
        with open(os.path.join(self.estado, self.PID + ".json"), encoding="utf-8") as fh:
            self.assertTrue(json.load(fh)["concluido"])

    def test_com_remoto_verificado_chega_a_L5(self):
        base = self.github

        def ls_remote_local(path, remoto="origin", timeout=120):
            out = subprocess.run(["git", "-c", _url_local(base), "-C", path, "ls-remote", remoto],
                                 capture_output=True, text=True, check=True).stdout
            return {n: s for s, _, n in (l.partition("\t") for l in out.splitlines()) if n and n != "HEAD"}
        self.deps.rede = True
        with mock.patch("eos.portability._visibilidade_github", return_value="private"), \
                mock.patch("eos.gitinfo.ls_remote", side_effect=ls_remote_local):
            rel = self.nascer()
        self.assertTrue(rel["ok"], rel["passos"])
        self.assertEqual(rel["nivel"], "L5", rel["verificacao"].get("bloqueios"))
        self.assertEqual(rel["verificacao"]["bloqueios"], ["recovery: nunca certificado por restauracao"])

    def test_identidade_e_assinatura_vem_da_config_efetiva_isolada(self):
        rel = self.nascer()
        own = rel["plano"]["ownership"]
        self.assertEqual(own["identities"], ["Teste Titular"],
                         "a config global do fixture nao foi a usada: o teste leria a do computador")
        self.assertEqual(own["signing"], "recommended")
        self.assertFalse(rel["assinado"])
        obj = sh(self.destino(), "cat-file", "commit", "HEAD")
        self.assertNotIn("gpgsig", obj)

    def test_commit_inicial_assinado_quando_a_config_pede(self):
        kg = _ssh_keygen()
        if not kg:
            self.skipTest("ssh-keygen indisponivel")
        chave = os.path.join(self.home, "chave_teste")
        subprocess.run([kg, "-q", "-t", "ed25519", "-N", "", "-C", "teste", "-f", chave], check=True, capture_output=True)
        self._gitconfig({"user": {"name": "Teste Titular", "email": "titular@exemplo.invalid",
                                  "signingkey": chave.replace("\\", "/")},
                         "core": {"autocrlf": "false", "safecrlf": "false"},
                         "gpg": {"format": "ssh"}, "gpg \"ssh\"": {"program": kg.replace("\\", "/")},
                         "commit": {"gpgsign": "true"}})
        rel = self.nascer()
        self.assertTrue(rel["ok"], rel["passos"])
        self.assertTrue(rel["assinado"])
        self.assertIn("ASSINADO", rel["passos"]["git"]["detalhe"])
        self.assertIn("\ngpgsig ", sh(self.destino(), "cat-file", "commit", "HEAD"))
        self.assertEqual(rel["plano"]["ownership"]["signing"], "required")

    def test_sem_remoto_pula_e_registra(self):
        rel = self.nascer(sem_remoto=True)
        self.assertTrue(rel["ok"], rel["passos"])
        self.assertEqual(self.gh.chamadas, [])
        self.assertEqual(self.rede.chamadas, [])
        self.assertIn("--sem-remoto", rel["passos"]["remoto"]["detalhe"])
        c = registry.carregar(self.plat)[self.PID]
        self.assertEqual(c["git"]["remote"], "")
        self.assertEqual(rel["nivel"], "L1")
        self.assertEqual(rel["verificacao"]["dimensoes"]["remote"]["status"], "FAIL")
        self.assertEqual(sh(self.destino(), "remote").strip(), "")

    def test_prog_runtime_none(self):
        rel = self.nascer(pid="grd-novo", nome="GRD Novo", categoria="PROG", runtime="none", sem_remoto=True)
        self.assertTrue(rel["ok"], rel["passos"])
        d = self.destino("grd-novo", "PROG")
        self.assertTrue(d.endswith(os.path.join("work", "prog", "grd-novo")), d)
        self.assertEqual(rel["plano"]["repo"], "prog-grd-novo")
        self.assertTrue(os.path.isfile(os.path.join(d, "tests", "_harness.ps1")))
        for f in ("tests/conftest.py", "tests/test_smoke.py", "requirements.txt"):
            self.assertFalse(os.path.exists(os.path.join(d, *f.split("/"))), f)
        with open(os.path.join(d, "project.yaml"), encoding="utf-8") as fh:
            y = fh.read()
        self.assertIn("dados_sensiveis: true", y)
        self.assertIn('revisao_independente: "qa+security"', y)
        with open(os.path.join(d, "PROVENANCE.md"), encoding="utf-8") as fh:
            self.assertIn("PROG — contexto, não autoria", fh.read())
        c = registry.carregar(self.plat)["grd-novo"]
        self.assertEqual(c["environment"]["runtime"], "none")
        self.assertEqual(c["cloud"]["drive_root"], "01 PROG/grd-novo")
        self.assertEqual(rel["plano"]["ownership"]["employer_or_client"], "PROG")

    def test_runtime_node_traz_manifesto(self):
        rel = self.nascer(runtime="node", sem_remoto=True)
        self.assertTrue(rel["ok"], rel["passos"])
        self.assertTrue(os.path.isfile(os.path.join(self.destino(), "package.json")))
        self.assertEqual(registry.carregar(self.plat)[self.PID]["environment"]["manifest"], "package.json")


class TestRecusas(Base):
    def _intacto(self, antes):
        self.assertEqual(self.arvore(), antes, "a recusa criou algo")
        self.assertEqual(self.gh.chamadas, [])

    def test_id_invalido(self):
        antes = self.arvore()
        rc, saida = self.cli("Lab_Teste", "--name", "x", "--category", "LAB")
        self.assertEqual(rc, 2)
        self.assertIn("RECUSADO: id 'Lab_Teste' invalido", saida)
        self._intacto(antes)

    def test_id_ja_no_registry(self):
        with open(self.yaml(), "w", encoding="utf-8") as f:
            f.write("contract_version: 1\n")
        antes = self.arvore()
        with self.assertRaisesRegex(novo.NovoErro, "ja existe no registry"):
            self.nascer()
        self._intacto(antes)

    def test_diretorio_nao_vazio(self):
        os.makedirs(self.destino())
        with open(os.path.join(self.destino(), "meu.txt"), "w") as f:
            f.write("nao toque\n")
        antes = self.arvore()
        with self.assertRaisesRegex(novo.NovoErro, "NAO esta vazio"):
            self.nascer()
        self._intacto(antes)

    def test_destino_dentro_do_onedrive(self):
        self.maquina["vars"]["AI_WORKSPACE"] = os.path.join(self.tmp, "OneDrive - Empresa", "ws")
        with self.assertRaisesRegex(novo.NovoErro, "pasta sincronizada"):
            self.nascer()
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "OneDrive - Empresa")))

    def test_id_com_nome_de_nuvem_em_base_normal_nao_e_recusado(self):
        # r8 Q7: o sinal de nuvem vem do diretorio PAI, nunca do id
        for pid in ("onedrive-limpeza", "dropbox-export", "my-drive-sync"):
            p = novo.planejar(pid, "x", "LAB", maquina=self.maquina, raiz_repo=self.plat)
            self.assertEqual(p["id"], pid)

    def test_destino_em_drive_compartilhado_e_recusado(self):
        for base in ("G:\\Drives compartilhados\\x", "G:\\Shared drives\\x", "G:\\Meu Drive\\ws", "G:\\My Drive\\ws",
                     "D:\\Google Drive\\ws", "C:\\Users\\fulano\\OneDrive\\ws"):
            self.maquina["vars"]["AI_WORKSPACE"] = base
            with self.assertRaisesRegex(novo.NovoErro, "pasta sincronizada", msg=base):
                novo.planejar(self.PID, "x", "LAB", maquina=self.maquina, raiz_repo=self.plat)

    def test_destino_em_biblioteca_sharepoint_sincronizada_e_recusado(self):
        for base in ("C:\\Users\\fulano\\Contoso\\Site - Documentos\\ws", "C:\\Users\\fulano\\Contoso\\Site - Documents",
                     os.path.join(self.tmp, "Contoso", "Projetos - Documentos")):
            self.maquina["vars"]["AI_WORKSPACE"] = base
            with self.assertRaisesRegex(novo.NovoErro, "pasta sincronizada", msg=base):
                novo.planejar(self.PID, "x", "LAB", maquina=self.maquina, raiz_repo=self.plat)
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "Contoso")))

    def test_sem_rede_implica_sem_remoto(self):
        # r8 Q11: --sem-rede nao pode deixar o gh/push rodarem
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB", sem_rede=True)
        self.assertEqual(rc, 0, saida)
        self.assertIn("--sem-rede implica --sem-remoto", saida)
        self.assertEqual(self.gh.chamadas, [], "--sem-rede chamou o gh")
        self.assertEqual(self.rede.chamadas, [], "--sem-rede falou com o remoto")
        self.assertEqual(registry.carregar(self.plat)[self.PID]["git"]["remote"], "")
        self.assertIn("--sem-remoto", saida.split("NASCEU")[0])

    def test_uso_sem_name(self):
        rc, saida = self.cli(self.PID, "--category", "LAB")
        self.assertEqual(rc, 2)
        self.assertIn("obrigatorios", saida)

    def test_opcao_desconhecida(self):
        rc, saida = self.cli(self.PID, "--name", "x", "--category", "LAB", "--publico")
        self.assertEqual(rc, 2)
        self.assertIn("--publico", saida)


class StoreQueFalha(cloud.DirStore):
    """Nuvem que recusa o mkdir: falha REAL de passo (nao pendencia humana)."""
    quebrado = True

    def mkdir(self, rel):
        if self.quebrado:
            raise cloud.NuvemErro("mkdir recusado (simulado)")
        super().mkdir(rel)


class TestFalhaFechadoERetomada(Base):
    def test_gh_negado_vira_H2_nasce_em_L1_e_retoma_so_o_remoto(self):
        self.gh.falhar_create = True
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 1, saida)
        self.assertRegex(saida, r"\[H2\s*\] remoto\s+sem remoto \(H2\)")
        self.assertIn("PENDENCIA HUMANA sem remoto (H2)", saida)
        self.assertIn('py -3.13 -m eos new lab-teste --name "Projeto Teste" --category LAB --runtime python', saida)
        self.assertIn("LEMBRETE", saida)
        # o resto do nascimento aconteceu: drive, backup, nivel informado
        self.assertTrue(os.path.isdir(os.path.join(self.nuvem, "05 LAB", "lab-teste")))
        self.assertIn("Nivel atingido: L1", saida)
        self.assertEqual(self.commits(self.destino()), "1")
        with open(os.path.join(self.estado, self.PID + ".json"), encoding="utf-8") as fh:
            self.assertFalse(json.load(fh)["concluido"], "com H2 o nascimento nao pode ser dado como concluido")
        with open(self.yaml(), "rb") as f:
            contrato_antes = f.read()
        # o mesmo comando, com o gh liberado, faz so o que falta
        self.gh.falhar_create = False
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 0, saida)
        self.assertEqual(self.commits(self.destino()), "1", "a retomada refez o commit")
        with open(self.yaml(), "rb") as f:
            self.assertEqual(f.read(), contrato_antes, "a retomada reescreveu o contrato")
        self.assertEqual(len(self.gh.criacoes()), 2, "uma criacao negada e a outra criou")
        bare = self.gh.bare("Emmilymaciell/lab-teste")
        self.assertEqual(sh(bare, "rev-parse", "main").strip(), sh(self.destino(), "rev-parse", "HEAD").strip())
        self.assertIn("NASCEU", saida)
        self.assertIn("eos certify lab-teste", saida)
        # e um terceiro pedido e recusado: ja nasceu
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 2)
        self.assertIn("ja nasceu", saida)

    def test_commit_inicial_que_falha_depois_do_add_e_retomavel(self):
        # r8 Q1: o commit falha DEPOIS do `git add` (hook que reprova, assinatura indisponivel): o
        # index fica com tudo e `ls-files --others` volta vazio. A retomada tem de commitar o index.
        hooks = os.path.join(self.home, "hooks")
        os.makedirs(hooks)
        gancho = os.path.join(hooks, "pre-commit")
        with open(gancho, "w", encoding="utf-8", newline="\n") as f:
            f.write("#!/bin/sh\necho 'reprovado pelo hook de teste' >&2\nexit 1\n")
        self._gitconfig({"user": {"name": "Teste Titular", "email": "titular@exemplo.invalid"},
                         "core": {"autocrlf": "false", "safecrlf": "false", "hooksPath": hooks.replace("\\", "/")}})
        rel = self.nascer()
        self.assertFalse(rel["ok"])
        self.assertEqual(rel["passos"]["git"]["status"], "FALHOU", rel["passos"])
        d = self.destino()
        self.assertFalse(gitinfo.tem_commit(d))
        self.assertTrue(sh(d, "ls-files").strip(), "o fixture nao reproduziu o index cheio sem commit")
        self.assertEqual(sh(d, "ls-files", "--others", "--exclude-standard").strip(), "")
        # causa corrigida; o MESMO pedido retoma e faz o commit inicial com o que esta no index
        os.remove(gancho)
        rel = self.nascer()
        self.assertTrue(rel["ok"], rel["passos"])
        self.assertEqual(self.commits(d), "1")
        self.assertEqual(sh(d, "status", "--porcelain", "--ignored").strip(), "")
        self.assertIn("PROVENANCE.md", sh(d, "ls-tree", "-r", "--name-only", "HEAD").split())

    def test_varredura_limpa_segue_e_roda_antes_do_push(self):
        rel = self.nascer()
        self.assertTrue(rel["ok"], rel["passos"])
        self.assertEqual(self.scan.chamadas, [(self.destino(), self.PID, 0)], "varredura ausente ou depois do push")
        self.assertEqual(len([c for c in self.rede.chamadas if c[:1] == ("push",)]), 1)
        self.assertIn("varredura", rel["passos"]["remoto"]["detalhe"])

    def test_varredura_com_achado_para_fechado_sem_push(self):
        self.scan.rc = 1
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 2, saida)
        self.assertRegex(saida, r"\[FALHOU\s*\] remoto\s+.*varredura de seguranca")
        self.assertIn("relatorio-lab-teste.md", saida, "o relatorio nao aponta o arquivo da varredura")
        self.assertEqual([c for c in self.rede.chamadas if c[:1] == ("push",)], [], "houve push com achado na varredura")
        self.assertEqual(self.gh.criacoes(), [], "criou o repo com achado na varredura")
        self.assertFalse(os.path.exists(os.path.join(self.nuvem, "05 LAB")), "achado nao e H2: o nascimento para")
        # corrigido o achado, o mesmo comando varre de novo e segue
        self.scan.rc = 0
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 0, saida)
        self.assertEqual(len(self.scan.chamadas), 2)

    def test_varredura_que_nao_conclui_para_fechado(self):
        self.scan.rc = 2
        rel = self.nascer()
        self.assertFalse(rel["ok"])
        self.assertIn("nao concluiu", rel["passos"]["remoto"]["detalhe"])
        self.assertEqual([c for c in self.rede.chamadas if c[:1] == ("push",)], [])

    def test_varredura_padrao_chama_o_script_da_plataforma_sem_rede(self):
        chamadas = []

        def run_falso(argv, **kw):
            chamadas.append(argv)
            return subprocess.CompletedProcess(argv, 1, b"achado simulado\n", b"")
        with mock.patch("eos.novo.subprocess.run", side_effect=run_falso):
            rc, relatorio, saida = novo.Dependencias().scan("C:\\x\\proj", "proj")
        self.assertEqual(rc, 1)
        argv = chamadas[0]
        self.assertEqual(argv[argv.index("-File") + 1], os.path.join(registry.RAIZ_REPO, "scripts", "security-scan.ps1"))
        self.assertEqual(argv[argv.index("-Path") + 1], "C:\\x\\proj")
        self.assertIn("-SemRede", argv)
        self.assertEqual(argv[argv.index("-Out") + 1], relatorio)
        self.assertTrue(os.path.basename(relatorio).startswith("novo-proj-"), relatorio)
        self.assertEqual(os.path.dirname(relatorio), os.path.join(tempfile.gettempdir(), "emmily-os-scan"))

    def test_varredura_real_limpa_no_recem_nascido_e_acusa_segredo_commitado(self):
        # integracao com scripts/security-scan.ps1 (sem rede): o template nao pode travar todo nascimento,
        # e um segredo commitado depois (o que a retomada pos-H2 enviaria) tem de parar o push
        if not shutil.which("powershell"):
            self.skipTest("powershell indisponivel")
        rel = self.nascer(sem_remoto=True)
        self.assertTrue(rel["ok"], rel["passos"])
        d = self.destino()
        relatorios = []
        try:
            rc, relatorio, saida = novo._scan_padrao(d, self.PID)
            relatorios.append(relatorio)
            self.assertEqual(rc, 0, "projeto recem-nascido reprovado pela varredura: %s\n%s" % (relatorio, saida))
            with open(os.path.join(d, "config.py"), "w", encoding="utf-8") as f:
                f.write('TOKEN = "ghp_' + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8" + '"\n')
            sh(d, "add", "config.py")
            sh(d, "commit", "-q", "-m", "teste: segredo plantado")
            rc, relatorio, saida = novo._scan_padrao(d, self.PID)
            relatorios.append(relatorio)
            self.assertEqual(rc, 1, "segredo commitado passou na varredura: %s\n%s" % (relatorio, saida))
        finally:
            for r in relatorios:
                if os.path.isfile(r):
                    os.remove(r)

    def test_falha_real_para_sem_apagar_sai_2_e_retoma_do_pendente(self):
        self.deps = novo.Dependencias(gh=self.gh, git_rede=self.rede, store=StoreQueFalha(self.nuvem), rede=False)
        self.deps.scan = self.scan
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 2, saida)
        self.assertIn("Nada foi apagado", saida)
        self.assertRegex(saida, r"\[FALHOU\s*\] drive\s+NuvemErro: mkdir recusado")
        self.assertRegex(saida, r"\[pendente\s*\] backup")
        self.assertIn('py -3.13 -m eos new lab-teste --name "Projeto Teste" --category LAB --runtime python', saida)
        # o que ja tinha sido feito continua la
        self.assertEqual(self.commits(self.destino()), "1")
        self.assertTrue(os.path.isfile(self.yaml()))
        self.assertEqual(len(self.gh.criacoes()), 1)
        self.assertFalse(os.path.exists(os.path.join(self.nuvem, "99 RECOVERY")), "passo depois da falha rodou")
        # retomada: nada e refeito (nem commit, nem repo), so o pendente
        self.deps._store.quebrado = False
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 0, saida)
        self.assertEqual(self.commits(self.destino()), "1")
        self.assertEqual(len(self.gh.criacoes()), 1, "a retomada recriou o repo")
        self.assertTrue(os.path.isdir(os.path.join(self.nuvem, "05 LAB", "lab-teste")))

    def test_retomada_com_parametros_diferentes_e_recusada(self):
        self.gh.falhar_create = True
        self.assertTrue(self.nascer()["h2"])
        antes = self.arvore()
        with self.assertRaisesRegex(novo.NovoErro, "parametros diferentes"):
            self.nascer(runtime="none")
        self.assertEqual(self.arvore(), antes)

    def test_remoto_publico_falha_fechado_sem_push(self):
        self.gh.vis = "PUBLIC"
        rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB")
        self.assertEqual(rc, 2, saida)
        self.assertRegex(saida, r"\[FALHOU\s*\] remoto\s+.*nao PRIVATE")
        self.assertEqual([c for c in self.rede.chamadas if c[:1] == ("push",)], [], "houve push para repo publico")
        bare = self.gh.bare("Emmilymaciell/lab-teste")
        self.assertEqual(sh(bare, "for-each-ref").strip(), "", "o repo publico recebeu refs")
        self.assertFalse(os.path.exists(os.path.join(self.nuvem, "05 LAB")), "publico nao e H2: o nascimento para")

    def test_contrato_existente_divergente_nao_e_sobrescrito(self):
        self.gh.falhar_create = True
        self.assertTrue(self.nascer()["h2"])
        # muda um campo de verdade, mantendo o YAML valido
        with open(self.yaml(), encoding="utf-8") as f:
            txt = f.read()
        with open(self.yaml(), "w", encoding="utf-8", newline="\n") as f:
            f.write(txt.replace("criticality: low", "criticality: high"))
        # a retomada re-confere CADA passo pelo fato (nao pelo diario): o contrato editado e visto
        self.gh.falhar_create = False
        rel = self.nascer()
        self.assertFalse(rel["ok"])
        self.assertIn("DIVERGE", rel["passos"]["contrato"]["detalhe"])
        with open(self.yaml(), encoding="utf-8") as f:
            self.assertIn("criticality: high", f.read())

    def test_certificar_roda_no_fim_com_o_contrato_do_registry(self):
        chamadas = []

        def cert_falso(contrato, store, maquina=None, log=print, manter=False):
            chamadas.append(contrato)
            return {"ok": True, "nivel_depois": "L6", "verificacoes": [{"o_que": "x", "ok": True}]}
        with mock.patch("eos.portability.certificar", side_effect=cert_falso):
            rc, saida = self.cli(self.PID, "--name", "Projeto Teste", "--category", "LAB", "--certificar")
        self.assertEqual(rc, 0, saida)
        self.assertEqual(len(chamadas), 1)
        self.assertEqual(chamadas[0], yamlite.load_file(self.yaml()), "certificou outro contrato que nao o gravado")
        self.assertIn("Certificacao APROVADA; nivel agora L6", saida)


class TestOwnershipIntegracao(Base):
    """Integrado com eos.ownership: a secao entra no YAML e o schema do contrato a valida."""

    def test_a_secao_entra_no_yaml_e_o_contrato_a_valida(self):
        self.assertIn("ownership", contract.SCHEMA)
        rel = self.nascer(sem_remoto=True)
        self.assertTrue(rel["ok"], rel["passos"])
        doc = yamlite.load_file(self.yaml())
        self.assertIn("ownership", doc)
        self.assertEqual(doc["ownership"]["declared_owner"], "Emmily Maciel")
        self.assertEqual(contract.validar(doc, self.PID + ".yaml"), [])
        completo = {k: v for k, v in rel["plano"]["contrato"].items() if not k.startswith("_")}
        self.assertEqual(novo._validar_ownership_local(completo["ownership"]), [])
        self.assertEqual(novo._ownership_padrao("A", "b", "LAB"), ownership.secao_padrao("A", "b", "LAB"))
        ruim = dict(completo["ownership"], signing="talvez")
        self.assertTrue(novo._validar_ownership_local(ruim))
        sem_dono = {k: v for k, v in completo["ownership"].items() if k != "declared_owner"}
        self.assertIn("ownership.declared_owner: obrigatorio", novo._validar_ownership_local(sem_dono))
        for f in ("PROVENANCE.md", "OWNERSHIP.md", "AUTHORS.md", "NOTICE", ".github/CODEOWNERS"):
            self.assertTrue(os.path.isfile(os.path.join(self.destino(), *f.split("/"))), f)

    def test_com_schema_integrado_a_secao_entra_no_contrato(self):
        p = novo.planejar(self.PID, "Projeto Teste", "LAB", maquina=self.maquina, raiz_repo=self.plat)
        c, erros = novo._contrato_para_registry(p["contrato"])
        self.assertEqual(erros, [])
        self.assertEqual(c["ownership"]["declared_owner"], "Emmily Maciel")
        self.assertEqual(c["ownership"]["owner_github"], "Emmilymaciell")
        self.assertEqual(yamlite.loads(yamlite.dumps(c)), c)
        self.assertNotIn("_data", c)

    def test_spec_citada_e_a_do_repositorio(self):
        # r8 Q15: o contrato gerado cita a spec versionada, nunca um arquivo fora do repo
        rel = self.nascer(sem_remoto=True)
        self.assertTrue(rel["ok"], rel["passos"])
        with open(self.yaml(), encoding="utf-8") as f:
            texto = f.read()
        self.assertIn("docs/vnext/SPEC-OWNERSHIP-NOVO-PROJETO.md", texto)
        self.assertNotIn("SURGE", texto)
        with open(novo.__file__, encoding="utf-8") as f:
            self.assertNotIn("SURGE/", f.read())


if __name__ == "__main__":
    unittest.main()
