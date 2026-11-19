"""Rodada r9 (2026-10-12): refs/preservado/* e ref local DELIBERADA.

Caso real: o Semanal tinha um stash orfao (anterior a sanitizacao do historico) preservado em
refs/preservado/stash-20260917. Ele NAO pode ir ao GitHub, e o motor o contava como "ref nao
publicada", derrubando o projeto para L1. A protecao dessa ref e o bundle do backup na nuvem.
"""
import os
import subprocess
import tempfile
import unittest

from eos import gitinfo


def sh(cwd, *args):
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.com",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.com")
    r = subprocess.run(["git", "-C", cwd, "-c", "commit.gpgsign=false"] + list(args), capture_output=True,
                       text=True, env=env)
    if r.returncode:
        raise AssertionError("git %s: %s" % (" ".join(args), r.stderr))
    return r.stdout


class TestPreservado(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="eos-r9-")
        self.repo = os.path.join(self.tmp, "repo")
        self.bare = os.path.join(self.tmp, "remoto.git")
        os.makedirs(self.repo)
        sh(self.tmp, "init", "-q", "--bare", self.bare)
        sh(self.repo, "init", "-q", "-b", "main")
        with open(os.path.join(self.repo, "a.txt"), "w") as f:
            f.write("a\n")
        sh(self.repo, "add", "a.txt")
        sh(self.repo, "commit", "-q", "-m", "a")
        sh(self.repo, "remote", "add", "origin", self.bare)
        sh(self.repo, "push", "-q", "origin", "main")
        with open(os.path.join(self.repo, "a.txt"), "w") as f:
            f.write("b\n")
        sh(self.repo, "commit", "-q", "-am", "orfao")
        self.orfao = sh(self.repo, "rev-parse", "HEAD").strip()
        sh(self.repo, "update-ref", "refs/preservado/stash-x", self.orfao)
        sh(self.repo, "reset", "-q", "--keep", "HEAD~1")

    def tearDown(self):
        gitinfo.remover_arvore(self.tmp)

    def test_preservado_nao_conta_como_nao_publicado(self):
        self.assertEqual(gitinfo.nao_publicados(self.repo, gitinfo.ls_remote(self.repo)), [])

    def test_outra_ref_propria_continua_contando(self):
        sh(self.repo, "update-ref", "refs/minha/x", self.orfao)
        self.assertEqual(gitinfo.nao_publicados(self.repo, gitinfo.ls_remote(self.repo)), ["refs/minha/x"])

    def test_preservado_continua_sendo_ref_do_projeto_para_o_backup(self):
        # A dimensao backup compara refs_do_projeto com o manifesto: o bundle TEM de conte-la.
        self.assertIn("refs/preservado/stash-x", gitinfo.refs_do_projeto(gitinfo.refs(self.repo)))


class TestCommitSoDeProveniencia(unittest.TestCase):
    """Commit que so mexe em PROVENANCE/OWNERSHIP/AUTHORS/NOTICE/CODEOWNERS nao torna o STATE
    desatualizado (achado real da r9: derrubou para L4 projeto com STATE em WIP da titular)."""

    def _commit(self, arquivo, quando):
        os.makedirs(os.path.dirname(os.path.join(self.repo, arquivo)) or self.repo, exist_ok=True)
        with open(os.path.join(self.repo, arquivo), "a") as f:
            f.write("x\n")
        sh(self.repo, "add", arquivo)
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.com", GIT_COMMITTER_NAME="t",
                   GIT_COMMITTER_EMAIL="t@example.com", GIT_AUTHOR_DATE=quando, GIT_COMMITTER_DATE=quando)
        subprocess.run(["git", "-C", self.repo, "-c", "commit.gpgsign=false", "commit", "-q", "-m", arquivo],
                       env=env, check=True, capture_output=True)

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="eos-r9p-")
        self.repo = os.path.join(self.tmp, "repo")
        os.makedirs(self.repo)
        sh(self.repo, "init", "-q", "-b", "main")
        self._commit("app.py", "2026-01-01T10:00:00")

    def tearDown(self):
        gitinfo.remover_arvore(self.tmp)

    def test_commit_so_de_proveniencia_nao_conta(self):
        from eos import portability
        base = portability._ultimo_commit_epoch(self.repo)
        for f in ("PROVENANCE.md", "OWNERSHIP.md", "AUTHORS.md", "NOTICE", ".github/CODEOWNERS"):
            self._commit(f, "2026-06-01T10:00:00")
        self.assertEqual(portability._ultimo_commit_epoch(self.repo), base)

    def test_commit_de_trabalho_continua_contando(self):
        from eos import portability
        base = portability._ultimo_commit_epoch(self.repo)
        self._commit("NOTICE", "2026-06-01T10:00:00")
        self._commit("app.py", "2026-07-01T10:00:00")
        self.assertGreater(portability._ultimo_commit_epoch(self.repo), base)

    def test_provenance_file_do_contrato_tambem_e_metadado(self):
        from eos import portability
        base = portability._ultimo_commit_epoch(self.repo)
        self._commit("docs/ORIGEM.md", "2026-06-01T10:00:00")
        c = {"ownership": {"provenance_file": "docs/ORIGEM.md"}}
        self.assertEqual(portability._ultimo_commit_epoch(self.repo, c), base)
        self.assertGreater(portability._ultimo_commit_epoch(self.repo), base)


if __name__ == "__main__":
    unittest.main()
