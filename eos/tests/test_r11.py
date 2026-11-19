"""Rodada r11 (2026-10-15): correcoes dos achados da revisao r10 (QA 1-8 e Security 1-8).

Cada caso prova o NEGATIVO: o motor anterior passava nele (dado pendente na nuvem, falso FAIL,
erro engolido, caminho/segredo vazando).
"""
import base64
import builtins
import json
import os
import sys
import unittest
from unittest import mock

from eos import cloud, cofre, gitinfo, mirror, ownership, paths, portability, restore
from eos.tests.test_cofre import ENV, SESSAO, VALOR, BaseCofre
from eos.tests.test_e2e import Base, sh
from eos.tests.test_mirror import DADOS, BaseMirror

# montado por concatenacao: o fonte do teste nao carrega um token com a forma real
TOKEN_GH = "gh" + "p_" + "Z9y8X7w6" * 5
AT = chr(64)


def _existe_na_nuvem(t, rel):
    return os.path.exists(os.path.join(t.nuvem, *(DADOS + "/" + rel).split("/")))


def _arquivos_na_nuvem(t, prefixo):
    base = os.path.join(t.nuvem, *(DADOS + "/" + prefixo).split("/"))
    out = []
    for r, _, fs in os.walk(base):
        out += [os.path.relpath(os.path.join(r, f), base).replace("\\", "/") for f in fs]
    return out


class TestPendenteAninhado(BaseMirror):
    """QA1/Sec1: decisao_pendente nao e contornada por aninhamento (mesma policy ou outra)."""

    def test_pai_cloud_mirror_nao_leva_filho_pendente_da_mesma_policy(self):
        self._w("data/raw/segredo-juridico.pdf", "conteudo pendente\n")
        self._w("data/raw/sub/x.csv", "1;2\n")
        self._w("data/ok.txt", "pode subir\n")
        self.contrato["data"] = [{"path": "data", "policy": "cloud-mirror"},
                                 {"path": "data/raw", "policy": "cloud-mirror", "decisao_pendente": True},
                                 {"path": "data/x.db", "policy": "none"}]
        r = self._espelhar()
        m = r["manifesto"]
        self.assertEqual(_arquivos_na_nuvem(self, "data/raw"), [], "o pai subiu o filho com decisao pendente")
        self.assertTrue(_existe_na_nuvem(self, "data/ok.txt"))
        self.assertEqual(m["paths"]["data/raw"]["estado"], "decisao-pendente")
        self.assertIn("data/raw", m["paths"]["data"]["excluidos"])
        self.assertFalse([k for k in m["paths"]["data"]["arquivos"] if k.startswith("data/raw/")])
        self.assertEqual(r["pendentes"], ["data/raw"])
        self.assertIn("dado com decisao pendente: data/raw", self._so_aqui())

    @unittest.skipUnless(os.name == "nt", "caixa so e indiferente no Windows")
    def test_filho_pendente_com_outra_caixa(self):
        self._w("data/raw/p.txt", "pendente\n")
        self.contrato["data"] = [{"path": "data", "policy": "cloud-mirror"},
                                 {"path": "DATA/Raw", "policy": "cloud-mirror", "decisao_pendente": True},
                                 {"path": "data/x.db", "policy": "none"}]
        self._espelhar()
        self.assertEqual(_arquivos_na_nuvem(self, "data/raw"), [])

    def test_alvo_dentro_de_caminho_pendente_de_outra_policy_e_recusado(self):
        self.contrato["data"] = [{"path": "data", "policy": "none", "decisao_pendente": True},
                                 {"path": "data/brutos", "policy": "cloud-mirror"},
                                 {"path": "config/mes.py", "policy": "cloud-mirror"}]
        r = self._espelhar()
        self.assertEqual(r["manifesto"]["paths"]["data/brutos"]["estado"], "decisao-pendente")
        self.assertEqual(_arquivos_na_nuvem(self, "data/brutos"), [], "alvo dentro de caminho pendente subiu")
        self.assertTrue(_existe_na_nuvem(self, "config/mes.py"))
        self.assertIn("data/brutos", r["pendentes"])
        ms = self._so_aqui()
        self.assertIn("dado com decisao pendente: data", ms)
        self.assertTrue(any("data/brutos" in x and "dentro de caminho pendente" in x for x in ms), ms)

    def test_alvo_dentro_de_pendente_cloud_mirror(self):
        self.contrato["data"] = [{"path": "data/brutos", "policy": "cloud-mirror", "decisao_pendente": True},
                                 {"path": "data/brutos/sub", "policy": "cloud-mirror"},
                                 {"path": "config/mes.py", "policy": "cloud-mirror"}]
        r = self._espelhar()
        self.assertEqual(r["manifesto"]["paths"]["data/brutos/sub"]["estado"], "decisao-pendente")
        self.assertEqual(_arquivos_na_nuvem(self, "data/brutos"), [])


class TestRestorePendente(BaseMirror):
    """QA2: restore --com-dados pula a entrada pendente com verificacao explicita que nao reprova."""

    def test_restore_com_dados_pula_pendente_sem_reprovar(self):
        self.contrato["data"][0]["decisao_pendente"] = True  # data/brutos
        self._backup()
        self._espelhar()
        dst = os.path.join(self.tmp, "rest-pend")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None, com_dados=True)
        self.assertTrue(rel["ok"], json.dumps(rel["verificacoes"], indent=1))
        v = [x for x in rel["verificacoes"] if "decisao pendente, nao restaurado" in x["o_que"]]
        self.assertEqual(len(v), 1, rel["verificacoes"])
        self.assertIn("data/brutos", v[0]["o_que"])
        self.assertTrue(v[0]["ok"])
        self.assertFalse(os.path.exists(os.path.join(dst, "data", "brutos", "a.txt")))
        self.assertEqual(self._r(os.path.join(dst, "config", "mes.py")), "MES = 10\n")

    def test_sem_copia_continua_reprovando(self):
        # o pulo e SO para decisao-pendente: path sem copia verificada continua FALHOU
        self._backup()
        m = self._espelhar()["manifesto"]
        m["paths"]["data/brutos"]["estado"] = "falhou"  # manifesto ok com um path sem copia
        self.store.escrever_texto(mirror.rel_manifesto("proj", m["ts"]), json.dumps(m))
        dst = os.path.join(self.tmp, "rest-falha")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="cloud", log=lambda *_: None, com_dados=True)
        self.assertFalse(rel["ok"])
        self.assertFalse([x for x in rel["verificacoes"] if "decisao pendente" in x["o_que"]])


class StoreQueFalha(cloud.DirStore):
    """enviar_lote levanta OSError com caminho absoluto da maquina na mensagem."""

    msg = None

    def enviar_lote(self, base_local, rels, rel_destino, rel_anteriores=None):
        raise OSError(self.msg or "[WinError 5] Acesso negado: '%s'" % os.path.join(base_local, rels[0] if rels else "x"))


class TestErroDoManifestoRedigido(BaseMirror):
    """Sec4: o campo `erro` do manifesto de espelho nao leva caminho absoluto da maquina."""

    def test_erro_sem_caminho_absoluto(self):
        casa = os.path.expanduser("~")
        st = StoreQueFalha(self.nuvem)
        st.msg = "falhou em %s e em %s e em %s" % (
            os.path.join(self.proj, "data", "brutos", "a.txt"), self.proj.replace("\\", "/").upper(),
            os.path.join(casa, "outra", "coisa.txt"))
        r = self._espelhar(st)
        erro = r["manifesto"]["paths"]["data/brutos"]["erro"]
        self.assertEqual(r["manifesto"]["paths"]["data/brutos"]["estado"], "falhou")
        bruto = json.dumps(r["manifesto"])
        for x in (self.proj, self.tmp, casa):
            self.assertNotIn(x.lower(), erro.lower())
            self.assertNotIn(json.dumps(x)[1:-1].lower(), bruto.lower())
        self.assertIn(os.path.join(".", "data", "brutos", "a.txt"), erro)
        self.assertIn(os.path.join("~", "outra", "coisa.txt"), erro)


class TestRedacaoDaCasa(unittest.TestCase):
    """Sec5: a pasta do usuario some do certificado sem distincao de caixa e pelo nome curto 8.3."""

    def setUp(self):
        self.casa = os.path.expanduser("~")

    @unittest.skipUnless(os.name == "nt", "caixa so e indiferente no Windows")
    def test_caixa_trocada(self):
        for v in (self.casa.upper(), self.casa.lower(), self.casa.replace("\\", "/").upper()):
            out = ownership._redigir_certificado({"x": [v + "\\.ssh\\id"]})
            self.assertNotIn(v.lower(), json.dumps(out).lower().replace("\\\\", "\\"))
            self.assertTrue(out["x"][0].startswith("~"), out)

    @unittest.skipUnless(os.name == "nt", "nome curto 8.3 e do Windows")
    def test_nome_curto_simulado(self):
        falso = "C:\\PROGRA~9\\USUAR~1"
        with mock.patch.object(paths, "nome_curto", lambda p: falso if p == self.casa else None):
            out = ownership._redigir_certificado({"msg": "chave em %s\\.ssh\\k" % falso})
        self.assertEqual(out["msg"], "chave em ~\\.ssh\\k")

    def test_nome_curto_real_quando_existe(self):
        curto = paths.nome_curto(self.casa)
        if not curto or curto.lower() == self.casa.lower():
            self.skipTest("sem nome curto 8.3 distinto para a pasta do usuario nesta maquina")
        out = ownership._redigir_certificado("em %s\\x" % curto)
        self.assertNotIn(curto.lower(), out.lower())

    def test_nao_redige_prefixo_de_outro_nome(self):
        self.assertEqual(paths.redigir_caminhos(self.casa + "2\\x"), self.casa + "2\\x")

    def test_falha_do_ctypes_e_silenciosa(self):
        with mock.patch.dict(sys.modules, {"ctypes": None}):
            self.assertIsNone(paths.nome_curto(self.casa))
            self.assertEqual(paths.redigir_caminhos(os.path.join(self.casa, "a")), os.path.join("~", "a"))


class TestVarreduraDeConteudo(BaseMirror):
    """Sec2: leitura que falha recusa; UTF-16 e varrido; string de conexao e URL com credencial;
    binario e arquivo grande sobem (limite declarado)."""

    def _recusados(self, r):
        return {x["rel"]: x["motivo"] for x in r["manifesto"]["recusados"]}

    def test_oserror_na_leitura_recusa(self):
        real = builtins.open
        alvo = os.path.join("data", "brutos", "a.txt")

        def falso(f, *a, **k):
            if isinstance(f, str) and f.endswith(alvo):
                raise PermissionError(13, "bloqueado pelo antivirus", f)
            return real(f, *a, **k)
        with mock.patch.object(mirror, "open", falso, create=True):
            r = self._espelhar()
        self.assertEqual(self._recusados(r).get("data/brutos/a.txt"), mirror.MSG_ILEGIVEL)
        self.assertFalse(_existe_na_nuvem(self, "data/brutos/a.txt"), "arquivo nao varrido subiu")
        self.assertNotIn(self.proj.lower(), json.dumps(r["manifesto"]).lower())

    def test_utf16_com_e_sem_bom_e_varrido(self):
        linha = "token=%s\r\n" % TOKEN_GH
        with open(os.path.join(self.proj, "data", "brutos", "le-bom.txt"), "wb") as f:
            f.write(linha.encode("utf-16"))
        with open(os.path.join(self.proj, "data", "brutos", "le-sem-bom.txt"), "wb") as f:
            f.write(linha.encode("utf-16-le"))
        with open(os.path.join(self.proj, "data", "brutos", "be-sem-bom.txt"), "wb") as f:
            f.write(linha.encode("utf-16-be"))
        r = self._espelhar()
        rec = self._recusados(r)
        for f in ("le-bom.txt", "le-sem-bom.txt", "be-sem-bom.txt"):
            self.assertIn("credencial", rec.get("data/brutos/" + f, ""), (f, rec))
            self.assertFalse(_existe_na_nuvem(self, "data/brutos/" + f), f)

    def test_string_de_conexao_e_url_com_credencial(self):
        casos = {
            "conn.config": "Server=db01;Database=x;User Id=app;Password=k9z;\n",
            "azure.txt": "DefaultEndpointsProtocol=https;AccountName=x;AccountKey=abcdEFGH1234ijklMNOP5678==;\n",
            # montados por concatenacao: o scanner da plataforma acusaria a forma literal no fonte
            # e com o '@' separado: o scanner leria 'senha@host' como e-mail de terceiro
            "url.txt": "DATABASE_URL=" + "post" + "gres://app:S3gr3d0x" + AT + "db.interno:5432/prod\n",
            "mongo.txt": "uri = mongodb+srv://u:pw" + AT + "cluster0.example.net/db\n",
            "bearer.txt": "Authorization: " + "Bea" + "rer abcdefghijABCDEFGHIJ0123456789\n",
        }
        for f, t in casos.items():
            self._w("data/brutos/" + f, t)
        rec = self._recusados(self._espelhar())
        for f in casos:
            self.assertIn("credencial", rec.get("data/brutos/" + f, ""), (f, rec))
            self.assertFalse(_existe_na_nuvem(self, "data/brutos/" + f), f)

    def test_texto_e_binario_legitimos_sobem(self):
        self._w("data/brutos/links.md", "veja https://example.com:8443/a/b?x=1 e http://host/p@q e user@example.com\n"
                                         "Server=db01;Database=x;Integrated Security=true;\n")
        # binario com NUL espalhado (como xlsx/pdf/docx): nao e varrido e SOBE (limite declarado)
        with open(os.path.join(self.proj, "data", "brutos", "planilha.xlsx"), "wb") as f:
            f.write(b"PK\x03\x04" + bytes(range(256)) * 64 + ("token=%s" % TOKEN_GH).encode())
        r = self._espelhar()
        rec = self._recusados(r)
        self.assertNotIn("data/brutos/links.md", rec)
        self.assertNotIn("data/brutos/planilha.xlsx", rec)
        self.assertTrue(_existe_na_nuvem(self, "data/brutos/planilha.xlsx"))

    def test_limite_declarado_na_docstring(self):
        doc = mirror.credencial_no_conteudo.__doc__
        self.assertIn("LIMITE DECLARADO", doc)
        self.assertIn("2 MB", doc)
        guia = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                            "docs", "user", "08-BACKUP-E-RECOVERY.md")
        with open(guia, encoding="utf-8") as f:
            texto = f.read()
        for termo in ("UTF-16", "binário", "maior que 2 MB", "string de conexão", "não deu para ler"):
            self.assertTrue(termo in texto, "o guia 08 nao declara: %s" % termo)
        self.assertTrue("com 2 quando **todas**" in texto,"o guia 08 nao documenta o rc 2 de todas pendentes")


class TestCofreRedacao(unittest.TestCase):
    """Sec3: valor multilinha (PEM) linha a linha e a forma base64 do item entregue ao bw."""

    def test_linhas_de_valor_multilinha(self):
        miolo = ["MIIEowIBAAKCAQEAx7FAKEFAKEFAKEline1", "q9ZFAKEFAKEFAKEFAKEline2xyz"]
        env = 'CHAVE="-----BEGIN FAKE KEY-----\n%s\n%s\n-----END FAKE KEY-----"\nOUTRA=1\n' % tuple(miolo)
        segs = cofre._valores(env)
        for linha in miolo:
            msg = "bw ecoou: %s ..." % linha
            self.assertNotIn(linha, cofre._redigir(msg, segs))
        inteiro = "\n".join(["-----BEGIN FAKE KEY-----"] + miolo + ["-----END FAKE KEY-----"])
        self.assertNotIn(miolo[0], cofre._redigir("json: %s" % json.dumps({"notes": inteiro}), segs))


class TestCofreBase64(BaseCofre):
    BW_ECO = r'''
import base64, json, sys
args = sys.argv[1:]
if args[:1] == ["status"]:
    sys.stdout.write(json.dumps({"status": "unlocked"})); sys.exit(0)
if args[:1] == ["encode"]:
    sys.stdout.write(base64.b64encode(sys.stdin.buffer.read()).decode("ascii")); sys.exit(0)
if args[:1] == ["sync"]:
    sys.exit(0)
if args[:2] == ["list", "items"]:
    sys.stdout.write("[]"); sys.exit(0)
# create: ecoa o que recebeu no stdin (o item em base64) e falha
sys.stderr.write("Invalid item: " + sys.stdin.buffer.read().decode("ascii")); sys.exit(1)
'''

    def test_base64_do_item_nao_aparece_no_erro(self):
        p = os.path.join(self.tmp, "bw-falso", "bw_eco.py")
        with open(p, "w", encoding="utf-8") as f:
            f.write(self.BW_ECO)
        bw = [sys.executable, "-I", p]
        with self.assertRaises(cofre.CofreErro) as cm:
            cofre.push(self.contrato, self.maquina, store=self.store, bw=bw, sessao=SESSAO, log=lambda *_: None)
        msg = str(cm.exception)
        self.assertIn("rc=1", msg)
        self.assertIn("<redigido>", msg)
        self.assertNotIn(VALOR, msg)
        # o item que o motor entrega e base64 de JSON que comeca com '{"': 'eyJ'
        self.assertNotIn("eyJ", msg)


class TestCofreSemManifesto(BaseCofre):
    """QA6: se nem o manifesto `incompleto` grava, a excecao diz que o cofre mudou sem manifesto."""

    def test_falha_ao_gravar_incompleto_e_anexada(self):
        self._w(".env.local", "L=VALOR-FALSO-LOCAL-9\n")
        db = self._vault()
        db["corromper"] = True
        self._vault(db)
        with mock.patch.object(self.store, "escrever_texto", side_effect=cloud.NuvemErro("nuvem caiu")):
            with self.assertRaises(cofre.ConferenciaFalhou) as cm:
                self._push()
        self.assertIn("cofre alterado sem manifesto: refaça o secrets-push", str(cm.exception))
        self.assertIn("sha256 diferente", str(cm.exception), "a mensagem original tem de continuar la")
        self.assertNotIn(VALOR, str(cm.exception))
        self.assertTrue(self._vault()["itens"], "o cenario exige o cofre alterado")


class TestPreservadoComFonteGithub(Base):
    """QA7: fonte=github traz o historico do remoto e refs/preservado/* do bundle."""

    def setUp(self):
        super().setUp()
        self.orfao = sh(self.proj, "rev-parse", "HEAD").strip()
        sh(self.proj, "update-ref", "refs/preservado/stash-x", self.orfao)
        self.remoto = os.path.join(self.tmp, "remoto.git")
        sh(self.tmp, "init", "-q", "--bare", self.remoto)
        sh(self.proj, "push", "-q", self.remoto, "main", "feature")
        self.contrato["git"]["remote"] = self.remoto

    def test_restore_github_traz_preservado_do_bundle(self):
        m = self._backup()
        self.assertIn("refs/preservado/stash-x", m["refs"])
        self.assertNotIn("refs/preservado/stash-x", gitinfo.refs(self.remoto), "o remoto nao pode ter a ref")
        dst = os.path.join(self.tmp, "rest-gh")
        rel = restore.restaurar(self.contrato, self.store, dst, fonte="github", log=lambda *_: None)
        self.assertIn("github:" + self.remoto, rel["fontes"])
        self.assertEqual(gitinfo.refs(dst).get("refs/preservado/stash-x"), self.orfao)
        v = next(x for x in rel["verificacoes"] if x["o_que"] == "refs locais iguais ao manifesto")
        self.assertNotIn("refs/preservado/stash-x", v["faltam"])
        # achado ao escrever este caso: o clone so criava a branch padrao e refs/heads/feature
        # faltava, reprovando todo restore com fonte github de repositorio com mais de uma branch
        self.assertEqual(v["faltam"], [])
        self.assertTrue(rel["ok"], json.dumps(rel["verificacoes"], indent=1))


class TestUltimoCommitRcNaoZero(unittest.TestCase):
    """QA7: git log com rc != 0 levanta CommitNaoVerificavel (nunca vira 'sem commit')."""

    def test_rc_nao_zero(self):
        with mock.patch.object(portability.gitinfo, "git", return_value=(128, "")):
            with self.assertRaisesRegex(portability.CommitNaoVerificavel, r"git log falhou \(rc=128\)"):
                portability._ultimo_commit_epoch("C:\\nao-importa", {})


class TestCerebroSemDecidir(unittest.TestCase):
    """QA8/Sec7: a nota de data/backup do Cerebro nao pede DECIDIR e nao ganha decisao_pendente."""

    @unittest.skip("depende de dado real do contrato — removido na versão pública")
    def test_nota_reescrita(self):
        raiz = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        with open(os.path.join(raiz, "registry", "projects", "prog-cerebro-documental.yaml"), encoding="utf-8") as f:
            texto = f.read()
        self.assertNotIn("DECIDIR", texto)
        self.assertIn("poda futura so com decisao da titular", texto)
        from eos import yamlite
        doc = yamlite.loads(texto) if hasattr(yamlite, "loads") else None
        if doc:
            bk_ = next(d for d in doc["data"] if d["path"] == "data/backup")
            self.assertNotIn("decisao_pendente", bk_)


if __name__ == "__main__":
    unittest.main()
