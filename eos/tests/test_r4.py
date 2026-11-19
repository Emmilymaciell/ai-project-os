"""Casos da rodada 4: um caso por achado da pre-revisao adversarial r3 (pre-revisao-r3.md).

Cada caso descreve o comportamento CORRETO, depois da correcao. Contra o codigo de hoje,
os casos de defeito tem de falhar, e pelo motivo do achado.
"""
# =====================================================================================
# RESULTADO CONTRA O CODIGO ATUAL (2026-10-11, Python 3.13.9, Git 2.55.0.windows.3)
#
# Base: HEAD c0887c2, extraido com `git archive` para %TEMP% (o working tree do vnext ja
# tinha edicao em andamento; nada foi escrito no repositorio). 12 casos: 11 FALHAM e 1 PASSA.
#
#  01 FALHA: L5 com .env local e saidas/ ignorado. seguro_trocar_computador=True, e o
#     so_nesta_pasta lista os dois motivos. O defeito e exatamente o do achado 1.
#  02 FALHA: com status AD, o valor esta em main/staged.patch E em main/unstaged.patch (o
#     unstaged mostra a remocao do .env com o conteudo). A pendencia tambem falta.
#  03 FALHA: com o segredo so no historico, pendencias == [] (o bundle leva o valor).
#  04 FALHA nos 3 subcasos: manifesto com machine trocado -> backup PASS; com source_path
#     trocado -> PASS; banco esvaziado e com mtime recuado em 1h -> PASS (variacao P04b).
#  05 FALHA: com backup.exclude=config/, o valor esta em main/files/config/local.json e
#     em main/unstaged.patch.
#  06 FALHA nos 3 subcasos: .git/hooks/post-checkout e .GIT/hooks/post-checkout fazem o hook
#     RODAR (o marcador FORA-DO-DESTINO-n.txt foi criado fora do destino); .git/config foi
#     sobrescrito com o conteudo do atacante. Nenhum dos tres levantou RestoreErro.
#  07 FALHA nos 2 subcasos: com diff.noprefix o apply da "git diff header lacks filename
#     information"; com color.diff=always da "No valid patches in input".
#  08 FALHA nos 2 subcasos: com GIT_LITERAL_PATHSPECS=1 o valor vai em main/staged.patch;
#     com GIT_DIR/GIT_WORK_TREE herdados, resumo() devolve o HEAD do OUTRO repositorio.
#  09 FALHA: o index mudou depois do staged.patch (mock em bk._tar_add_bytes), e mesmo assim
#     o check deu backup PASS ("bundle, WIP e bancos atuais na nuvem").
#  10 FALHA: 18 janelas de 8 caracteres do valor (os ultimos 25 chars) ficaram no cert.
#  11 PASSA, e e o esperado: o achado 11 e sobre a QUALIDADE dos testes, nao sobre defeito
#     do motor (o motor ja diz NAO nesses dois cenarios). O que muda e que agora o NAO e
#     medido num fixture com remoto: exclude exige L3+ e o motivo citando o caminho;
#     stash exige remote PASS, nivel L2 e proximo_nivel L3 (o stash derruba o degrau do
#     backup por desenho, entao L3 nao e alcancavel). Prova de que o caso nao e vazio: num
#     mutante em que o verificar NAO repassa backup.exclude, este caso FALHA (nivel cai
#     para L2), enquanto test_r3.test_exclude_por_contrato_nao_vira_pode_perder PASSA.
#  12 FALHA nos 2 subcasos: sem remoto, fonte="github" nao levanta e cai no bundle; com
#     remoto, refs/heads/feature fica no sha velho do bundle, e nao no do remoto.
#
# Controle positivo: numa copia de c0887c2 com correcoes minimas (uma por achado), os 12
# passam, e os 66 testes existentes continuam verdes. Ou seja, nenhum caso pede o impossivel.
# Para referencia: o working tree em andamento (nao commitado) do vnext passava 11 de 12. So
# falhava o subcaso 04 "mtime recuado", porque ali a comparacao continua sendo `>` e nao `!=`.
# =====================================================================================
import copy
import hashlib
import io
import json
import os
import sqlite3
import subprocess
import tarfile
import time
import unittest
from unittest import mock

from eos import backup as bk
from eos import gitinfo, portability, restore
from eos.tests.test_e2e import Base, sh
from eos.tests.test_r2 import _check


def _valor(n):
    return "VALOR-FABRICADO-R4-%d-QWERTYUIOPASDFGHJKLZXCVBNM" % n


def _nivel(r):
    return int((r["nivel"] or "L0")[1])


class _Ajuda:
    """Helpers comuns. Mixin, nao TestCase: assim nenhum caso roda duas vezes."""

    def _tar(self, m):
        return os.path.join(self.nuvem, *m["artifacts"]["wip"]["rel"].split("/"))

    def _membros(self, m):
        """{nome: bytes} de TODOS os membros do tar de WIP (inclusive patches e status.txt)."""
        out = {}
        with tarfile.open(self._tar(m), "r:gz") as tar:
            for mb in tar.getmembers():
                out[mb.name] = tar.extractfile(mb).read() if mb.isfile() else b""
        return out

    def _assert_valor_fora_do_tar(self, m, valor):
        achados = [n for n, d in self._membros(m).items() if valor.encode() in d or valor in n]
        self.assertEqual(achados, [], "o valor fabricado subiu para a nuvem nestes membros do tar: %s" % achados)

    def _rel_manifesto(self, m):
        return "99 RECOVERY/manifests/%s/%s.json" % (m["project"], m["timestamp"])

    @staticmethod
    def _proximo_segundo():
        # carimbo() tem resolucao de segundo: dois backups no mesmo segundo gravariam o mesmo
        # manifesto e os mesmos artefatos
        time.sleep(1.1)


class TestR4Local(_Ajuda, Base):
    """Fixture padrao (sem remoto)."""

    # ---- achado 2 ---------------------------------------------------------------------
    def test_02_env_staged_e_apagado_do_disco_nao_sobe_no_patch(self):
        v = _valor(2)
        with open(os.path.join(self.proj, ".env"), "w") as f:
            f.write("API_TOKEN=%s\n" % v)
        sh(self.proj, "add", "-f", ".env")
        os.remove(os.path.join(self.proj, ".env"))
        self.assertIn("AD .env", sh(self.proj, "status", "--porcelain"), "premissa: status AD")
        m = self._backup()
        self._assert_valor_fora_do_tar(m, v)
        self.assertTrue(any(".env" in p for p in m["pendencias"]),
                        "o .env so-do-index nao subiu, mas o backup nao registrou pendencia: %s" % m["pendencias"])
        self.assertTrue(m.get("incompleto"))

    # ---- achado 3 ---------------------------------------------------------------------
    def test_03_segredo_so_no_historico_gera_pendencia_e_reprova_secrets(self):
        v = _valor(3)
        with open(os.path.join(self.proj, "credentials.json"), "w") as f:
            f.write('{"token": "%s"}\n' % v)
        sh(self.proj, "add", "credentials.json")
        sh(self.proj, "commit", "-q", "-m", "oops", "--", "credentials.json")
        sh(self.proj, "rm", "-q", "credentials.json")
        sh(self.proj, "commit", "-q", "-m", "remove", "--", "credentials.json")
        self.assertNotIn("credentials.json", sh(self.proj, "ls-files"), "premissa: fora da arvore atual")
        self.assertIn(v, sh(self.proj, "log", "--all", "-p"), "premissa: o valor esta no historico")
        m = self._backup()
        self.assertTrue(any("credentials.json" in p for p in m["pendencias"]),
                        "o bundle leva o historico com o segredo e o backup nao registrou pendencia: %s" % m["pendencias"])
        self.assertTrue(m.get("incompleto"))
        sec = _check(self)["dimensoes"]["secrets"]
        self.assertEqual(sec["status"], "FAIL", "segredo no historico e a dimensao secrets aprovou: %s" % sec)
        self.assertIn("credentials.json", sec["motivo"])

    # ---- achado 4 ---------------------------------------------------------------------
    def test_04_frescor_do_banco_nao_vale_com_manifesto_de_outra_copia(self):
        m = self._backup()
        rel = self._rel_manifesto(m)
        original = self.store.ler_texto(rel)
        premissa = _check(self)["dimensoes"]["backup"]
        self.assertEqual(premissa["status"], "PASS", "premissa: backup atual aprovado (%s)" % premissa)
        casos = {
            "outra maquina": lambda x: x.update(machine="MAQUINA-NOVA-R4"),
            "outro caminho": lambda x: x.update(source_path=os.path.join(self.tmp, "outro-clone", "proj")),
        }
        for nome, mexe in casos.items():
            with self.subTest(nome):
                adulterado = json.loads(original)
                mexe(adulterado)
                self.store.escrever_texto(rel, json.dumps(adulterado, ensure_ascii=False, indent=2))
                b = _check(self)["dimensoes"]["backup"]
                self.assertEqual(b["status"], "FAIL",
                                 "banco medido por mtime contra manifesto de %s, e o check aprovou: %s" % (nome, b))
                self.assertRegex(b["motivo"], r"(?i)m[aá]quina|machine|caminho|source_path|outr[ao] (c[oó]pia|clone)")
            self.store.escrever_texto(rel, original)
        with self.subTest("banco trocado por copia com mtime mais antigo"):
            velho = os.path.getmtime(self.db) - 3600
            con = sqlite3.connect(self.db)
            con.execute("delete from t")
            con.commit()
            con.close()
            os.utime(self.db, (velho, velho))  # Copy-Item/robocopy preservam LastWriteTime
            b = _check(self)["dimensoes"]["backup"]
            self.assertEqual(b["status"], "FAIL", "banco com 0 linhas e mtime recuado passou como salvo: %s" % b)
            self.assertIn("x.db", b["motivo"])

    # ---- achado 6 ---------------------------------------------------------------------
    def test_06_restore_recusa_componente_git_no_indice_do_wip(self):
        m0 = self._backup()
        tar_p = self._tar(m0)
        with open(tar_p, "rb") as f:
            tar_original = f.read()
        casos = {
            "hook": ".git/hooks/post-checkout",
            "hook com caixa trocada": ".GIT/hooks/post-checkout",
            "config": ".git/config",
        }
        for i, (nome, alvo) in enumerate(casos.items()):
            with self.subTest(nome):
                marca = os.path.join(self.tmp, "FORA-DO-DESTINO-%d.txt" % i)
                if "hooks" in alvo:
                    carga = ("#!/bin/sh\necho executado > '%s'\n" % marca.replace("\\", "/")).encode()
                else:
                    carga = b"[core]\n\trepositoryformatversion = 0\n\tbare = false\n[eos]\n\tadulterado = r4\n"
                # o atacante controla tar E manifesto (o manifesto nao e assinado)
                with tarfile.open(fileobj=io.BytesIO(tar_original), mode="r:gz") as velho, \
                        tarfile.open(tar_p, "w:gz") as tar:
                    for mb in velho.getmembers():
                        tar.addfile(mb, velho.extractfile(mb) if mb.isfile() else None)
                    info = tarfile.TarInfo("main/files/" + alvo)
                    info.size = len(carga)
                    tar.addfile(info, io.BytesIO(carga))
                m = copy.deepcopy(m0)
                m["artifacts"]["wip"]["sha256"] = gitinfo.sha256_arquivo(tar_p)
                main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
                main["arquivos"][alvo] = hashlib.sha256(carga).hexdigest()
                m["wip_index"].sort(key=lambda w: w["rotulo"] != "main")  # main antes da worktree ligada
                dst = os.path.join(self.tmp, "r6-%d" % i)
                erro = None
                try:
                    restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="cloud", log=lambda *_: None)
                except Exception as e:  # noqa: BLE001
                    erro = e
                # primeiro o dano, depois a forma da recusa
                self.assertFalse(os.path.exists(marca), "hook executado pelo restore: escrita FORA do destino (%s)" % marca)
                self.assertFalse(os.path.exists(os.path.join(dst, ".git", "hooks", "post-checkout")),
                                 "o restore escreveu um hook em destino/.git/hooks")
                cfg = os.path.join(dst, ".git", "config")
                if os.path.isfile(cfg):
                    self.assertNotIn("adulterado", self._r(cfg), "o restore sobrescreveu destino/.git/config")
                self.assertIsInstance(erro, restore.RestoreErro,
                                      "esperava RestoreErro pelo componente .git em '%s', veio %r" % (alvo, erro))
                self.assertRegex(str(erro), r"(?i)\.git")

    # ---- achado 7 ---------------------------------------------------------------------
    def test_07_config_de_diff_da_usuaria_nao_quebra_o_staged_patch(self):
        self._w("docs/novo.md", "staged em subpasta\n")
        sh(self.proj, "add", "docs/novo.md")
        for i, (chave, valor) in enumerate((("diff.noprefix", "true"), ("color.diff", "always"))):
            with self.subTest(chave):
                if i:
                    self._proximo_segundo()
                sh(self.proj, "config", chave, valor)
                try:
                    self._backup()
                    dst = os.path.join(self.tmp, "r7-%d" % i)
                    try:
                        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None)
                    except Exception as e:  # noqa: BLE001
                        self.fail("com %s=%s o staged.patch ficou inaplicavel: %r" % (chave, valor, e))
                    self.assertTrue(rel["ok"], [v for v in rel["verificacoes"] if not v["ok"]])
                    staged = sorted(sh(dst, "diff", "--cached", "--name-only").split())
                    self.assertEqual(staged, ["docs/novo.md", "staged.txt"])
                finally:
                    sh(self.proj, "config", "--unset", chave)

    # ---- achado 8 ---------------------------------------------------------------------
    def test_08_ambiente_git_herdado_nao_muda_o_que_o_motor_mede(self):
        with self.subTest("GIT_LITERAL_PATHSPECS"):
            v = _valor(8)
            with open(os.path.join(self.proj, ".env"), "w") as f:
                f.write("API_TOKEN=%s\n" % v)
            sh(self.proj, "add", "-f", ".env")
            with mock.patch.dict(os.environ, {"GIT_LITERAL_PATHSPECS": "1"}):
                m = self._backup()
            self._assert_valor_fora_do_tar(m, v)
            self.assertTrue(any(".env" in p for p in m["pendencias"]), m["pendencias"])
        with self.subTest("GIT_DIR/GIT_WORK_TREE de outro repositorio"):
            outro = os.path.join(self.tmp, "outro")
            os.makedirs(outro)
            sh(outro, "init", "-q", "-b", "main")
            sh(outro, "config", "user.email", "t@t")
            sh(outro, "config", "user.name", "t")
            self._w("a.txt", "a\n", base=outro)
            sh(outro, "add", "-A")
            sh(outro, "commit", "-q", "-m", "x")
            real = gitinfo.resumo(self.proj)
            self.assertTrue(real["worktrees"][0]["sujo"], "premissa: o projeto esta sujo")
            with mock.patch.dict(os.environ, {"GIT_DIR": os.path.join(outro, ".git"), "GIT_WORK_TREE": outro}):
                medido = gitinfo.resumo(self.proj)
            self.assertEqual(medido.get("head"), real["head"], "o motor mediu o HEAD de outro repositorio")
            self.assertEqual(sorted(medido.get("refs", {})), sorted(real["refs"]))
            self.assertEqual([w["sujo"] for w in medido["worktrees"]], [w["sujo"] for w in real["worktrees"]],
                             "projeto sujo medido como limpo: caminho para SIM falso")

    # ---- achado 9 ---------------------------------------------------------------------
    def test_09_index_muda_entre_staged_patch_e_impressao(self):
        orig = bk._tar_add_bytes
        disparou = []

        def depois_do_patch(tar, nome, dados):
            orig(tar, nome, dados)
            if nome == "main/staged.patch" and not disparou:
                disparou.append(nome)
                # a usuaria faz 'git add -p': conteudo que so existe no index, depois do patch gerado
                r = subprocess.run(["git", "hash-object", "-w", "--stdin"], cwd=self.proj,
                                   input=b"print('so no index')\n", capture_output=True)
                sh(self.proj, "update-index", "--cacheinfo", "100644,%s,app.py" % r.stdout.decode().strip())

        try:
            with mock.patch.object(bk, "_tar_add_bytes", depois_do_patch):
                self._backup()
        except RuntimeError as e:
            # correcao aceitavel: o backup percebe que o index mudou e falha
            self.assertTrue(disparou)
            self.assertRegex(str(e), r"(?i)mudou|index|staged")
            return
        self.assertTrue(disparou, "premissa: o index mudou depois do staged.patch")
        self.assertIn("so no index", sh(self.proj, "show", ":app.py"), "premissa")
        b = _check(self)["dimensoes"]["backup"]
        self.assertEqual(b["status"], "FAIL",
                         "o staged.patch na nuvem nao tem o index atual, e o check considera o WIP protegido: %s" % b)
        self.assertIn("WIP", b["motivo"])

    # ---- achado 10 --------------------------------------------------------------------
    def test_10_cauda_do_smoke_nao_vaza_pedaco_de_segredo_no_corte(self):
        self._backup()
        seg = _valor(10)
        # sem quebra de linha: saida = seg + 1975 'z'; o corte em -2000 cai dentro de seg
        self.contrato["environment"]["smoke_command"] = "[Console]::Out.Write($env:EOS_R4_SEG + ('z' * 1975)); exit 0"
        with mock.patch.dict(os.environ, {"EOS_R4_SEG": seg}):
            c = portability.certificar(self.contrato, self.store, self.maquina, log=lambda *_: None)
        self.assertIn("smoke", c, c.get("erro"))
        self.assertEqual(c["smoke"]["rc"], 0)
        self.assertTrue(c["smoke"]["cauda"].endswith("z" * 100), "premissa: a cauda e a saida do smoke")
        nuvem = json.dumps(bk.ultima_certificacao(self.store, "proj"))
        local = json.dumps(c)
        vazados = sorted({seg[i:i + 8] for i in range(len(seg) - 7) if seg[i:i + 8] in nuvem or seg[i:i + 8] in local})
        self.assertEqual(vazados, [], "pedaco do valor de ambiente (8+ caracteres) no cert: %s" % vazados[:3])


class TestR4Remoto(_Ajuda, Base):
    """Com remoto bare real e visibilidade simulada: o fixture CHEGA a L3+, entao 'NAO' nao passa por vacuidade."""

    def setUp(self):
        super().setUp()
        self.bare = os.path.join(self.tmp, "remoto.git")
        sh(self.tmp, "init", "-q", "--bare", self.bare)
        sh(self.proj, "remote", "add", "origin", self.bare)
        sh(self.proj, "push", "-q", "origin", "main", "feature")
        self.contrato["git"] = {"enabled": True, "remote": self.bare}
        self.vis = mock.patch.object(portability, "_visibilidade_github", lambda url: "private")
        self.vis.start()

    def tearDown(self):
        self.vis.stop()
        super().tearDown()

    def _commit_e_push(self, msg, *arquivos):
        sh(self.proj, "add", *arquivos)
        sh(self.proj, "commit", "-q", "-m", msg, "--", *arquivos)
        sh(self.proj, "push", "-q", "origin", "main")

    # ---- achado 1 ---------------------------------------------------------------------
    def test_01_trocar_de_computador_e_NAO_com_dado_so_nesta_pasta_mesmo_em_L5(self):
        with open(os.path.join(self.proj, ".gitignore"), "a") as f:
            f.write(".env\nsaidas/\n")
        self._commit_e_push("ignora", ".gitignore")
        with open(os.path.join(self.proj, ".env"), "w") as f:
            f.write("API_TOKEN=%s\n" % _valor(1))
        self._w("saidas/relatorio-final.xlsx", "so existe aqui\n")
        self._backup()
        r = _check(self, rede=True)
        self.assertEqual(r["nivel"], "L5", "premissa: o fixture chega a L5 (%s)" % r["bloqueios"])
        self.assertTrue(r["so_nesta_pasta"], "premissa: o motor ve o que so existe aqui")
        self.assertFalse(r["seguro_trocar_computador"],
                         "SIM para trocar de computador com dado so nesta pasta: %s" % r["so_nesta_pasta"])
        comp = r["motivos_nao"]["computador"]
        self.assertTrue(any("cofre" in x for x in comp), comp)
        self.assertTrue(any("relatorio-final.xlsx" in x for x in comp), comp)

    # ---- achado 5 ---------------------------------------------------------------------
    def test_05_backup_exclude_vale_para_arquivo_rastreado(self):
        v = _valor(5)
        self._w("config/local.json", '{"a": 1}\n')
        self._commit_e_push("cfg", "config/local.json")
        self._w("config/local.json", '{"senha_do_banco": "%s"}\n' % v)
        self.contrato["backup"]["exclude"] = ["config/"]
        m = self._backup()
        self._assert_valor_fora_do_tar(m, v)  # nem files/ nem unstaged.patch
        main = next(w for w in m["wip_index"] if w["rotulo"] == "main")
        self.assertNotIn("config/local.json", main["arquivos"])
        r = _check(self, rede=True)
        self.assertGreaterEqual(_nivel(r), 3, "premissa: L3+ (%s)" % r["bloqueios"])
        self.assertFalse(r["seguro_apagar_clone"], "arquivo em backup.exclude so existe aqui, e o clone deu SIM")
        self.assertTrue(any("config/local.json" in x for x in r["motivos_nao"]["clone"]), r["motivos_nao"]["clone"])

    # ---- achado 11 --------------------------------------------------------------------
    def test_11_NAO_do_clone_medido_em_fixture_que_chega_a_L3(self):
        with self.subTest("backup.exclude, repassado pelo verificar"):
            v = _valor(11)
            self.contrato["backup"]["exclude"] = ["saidas-locais/"]
            self._w("saidas-locais/planilha.xlsx", v + "\n")  # nome inocente, nao ignorado
            m = self._backup()
            self._assert_valor_fora_do_tar(m, v)
            r = _check(self, rede=True)
            self.assertGreaterEqual(_nivel(r), 3, "premissa: L3+, senao o NAO passa por vacuidade (%s)" % r["bloqueios"])
            self.assertFalse(r["seguro_apagar_clone"])
            self.assertTrue(any("saidas-locais" in x for x in r["motivos_nao"]["clone"]), r["motivos_nao"]["clone"])
            # (seguro_trocar_computador aqui e o achado 1; fica no test_01 para nao misturar motivos)
        self.contrato["backup"].pop("exclude")
        gitinfo.remover_arvore(os.path.join(self.proj, "saidas-locais"))
        with self.subTest("stash"):
            self._proximo_segundo()
            sh(self.proj, "stash", "push", "-q", "-m", "guardado", "--", "app.py")
            self._backup()
            r = _check(self, rede=True)
            # o remoto passa (L2); o que derruba e o stash, no degrau do backup - nao a falta de remoto
            self.assertEqual(r["dimensoes"]["remote"]["status"], "PASS", r["dimensoes"]["remote"])
            self.assertEqual(r["nivel"], "L2")
            self.assertEqual(r["proximo_nivel"], "L3")
            self.assertFalse(r["seguro_apagar_clone"])
            self.assertTrue(any("stash" in x for x in r["motivos_nao"]["clone"]), r["motivos_nao"]["clone"])

    # ---- achado 12 --------------------------------------------------------------------
    def test_12_fonte_github_respeitada(self):
        with self.subTest("sem remoto: erro, nao cai no bundle em silencio"):
            self._backup()
            sem_remoto = dict(self.contrato, git={"enabled": True, "remote": ""})
            with self.assertRaisesRegex(restore.RestoreErro, r"(?i)remoto|github"):
                restore.restaurar(sem_remoto, self.store, os.path.join(self.tmp, "r12a"), fonte="github",
                                  log=lambda *_: None)
        with self.subTest("com remoto: refs do bundle nao sobrescrevem as do remoto"):
            self._proximo_segundo()
            m = self._backup()
            antigo = m["refs"]["refs/heads/feature"]
            self._w("feat2.txt", "depois do backup\n", base=self.wt)
            sh(self.wt, "add", "feat2.txt")
            sh(self.wt, "commit", "-q", "-m", "f2", "--", "feat2.txt")
            sh(self.wt, "push", "-q", "origin", "feature")
            novo = sh(self.wt, "rev-parse", "HEAD").strip()
            self.assertNotEqual(novo, antigo, "premissa")
            dst = os.path.join(self.tmp, "r12b")
            rel = restore.restaurar(self.contrato, self.store, dst, manifesto=m, fonte="github", log=lambda *_: None)
            refs = gitinfo.refs(dst)
            self.assertEqual(refs.get("refs/remotes/origin/feature"), novo)
            self.assertNotEqual(refs.get("refs/heads/feature"), antigo,
                                "com fonte=github o bundle sobrescreveu a branch local com a ref velha")
            self.assertIn(refs.get("refs/heads/feature"), (None, novo))
            self.assertFalse(any(f.endswith(".bundle") or ".bundle " in f for f in rel["fontes"]), rel["fontes"])


if __name__ == "__main__":
    unittest.main()
