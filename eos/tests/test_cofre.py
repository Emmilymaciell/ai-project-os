"""Cofre de segredos (eos/cofre.py) contra um `bw` FALSO: script Python que simula o vault num
arquivo JSON temporario e grava o argv de cada chamada, para o teste provar que o valor de um
segredo nunca passou por linha de comando. O `bw` real nunca e chamado aqui.

Os valores sao falsos e obvios (VALOR-FALSO-...). O caso negativo de cada positivo existe porque
"o push rodou sem erro" nao prova que o cofre tem o arquivo, nem que nada vazou no caminho.
"""
import base64
import contextlib
import hashlib
import io
import json
import os
import sys
import unittest
from unittest import mock

from eos import __main__ as cli
from eos import backup as bk
from eos import cofre, gitinfo, portability
from eos.tests.test_e2e import Base, sh

SESSAO = "SESSAO-FALSA-DE-TESTE-0001"
VALOR = "VALOR-FALSO-SECRETO-123456"
VALOR2 = "VALOR-FALSO-DOIS-abcdef"
ENV = "API_TOKEN=%s\nexport OUTRA_CHAVE=\"%s\"\n# comentario\n" % (VALOR, VALOR2)

BW_FALSO = r'''
import base64, json, os, sys
vault, args = sys.argv[1], sys.argv[2:]
with open(vault + ".argv.log", "a", encoding="utf-8") as f:
    f.write(json.dumps(args) + "\n")
with open(vault, encoding="utf-8") as f:
    db = json.load(f)

def salvar():
    with open(vault, "w", encoding="utf-8") as f:
        json.dump(db, f)

def sair(msg, rc=1):
    sys.stderr.write(msg + "\n")
    sys.exit(rc)

def item_do_stdin():
    raw = sys.stdin.buffer.read().decode("ascii").strip()
    return json.loads(base64.b64decode(raw).decode("utf-8"))

def responder(obj):
    sys.stdout.write(json.dumps(obj))

aberto = db.get("logado", True) and os.environ.get("BW_SESSION") == db["sessao"]
if args[:1] == ["status"]:
    responder({"status": "unlocked" if aberto else ("locked" if db.get("logado", True) else "unauthenticated")})
    sys.exit(0)
if args[:1] == ["encode"]:
    sys.stdout.write(base64.b64encode(sys.stdin.buffer.read()).decode("ascii"))
    sys.exit(0)
if not aberto:
    sair("Vault is locked.")
if args[:1] == ["sync"]:
    sys.stdout.write("Syncing complete.")
elif args[:2] == ["list", "items"]:
    busca = args[args.index("--search") + 1].lower() if "--search" in args else ""
    responder([i for i in db["itens"] if busca in i["name"].lower()])
elif args[:2] == ["get", "item"]:
    i = next((i for i in db["itens"] if i["id"] == args[2]), None)
    if i is None:
        sair("Not found.")
    responder(i)
elif args[:2] == ["create", "item"]:
    if len(args) > 2:
        sair("o falso so aceita o item pelo stdin", 2)
    novo = item_do_stdin()
    db["prox"] = db.get("prox", 0) + 1
    novo["id"] = "id-falso-%04d" % db["prox"]
    if db.get("corromper"):
        novo["notes"] = (novo.get("notes") or "") + "X"
    db["itens"].append(novo)
    salvar()
    responder(novo)
elif args[:2] == ["edit", "item"]:
    if len(args) != 3:
        sair("o falso so aceita o item pelo stdin", 2)
    novo = item_do_stdin()
    novo["id"] = args[2]
    db["itens"] = [novo if i["id"] == args[2] else i for i in db["itens"]]
    salvar()
    responder(novo)
else:
    sair("comando desconhecido: %r" % args, 2)
'''


def _sha(b):
    return hashlib.sha256(b).hexdigest()


class BaseCofre(Base):
    def setUp(self):
        super().setUp()
        self._w(".gitignore", "data/\n.venv/\n.env\n.env.local\n")
        self._w(".env", ENV)
        self.contrato["secrets"] = {"manifest": "secrets.manifest", "store": "bitwarden"}
        os.makedirs(self.nuvem)  # a raiz da nuvem existe (Drive montado); o push confere antes de tocar no cofre
        d = os.path.join(self.tmp, "bw-falso")
        os.makedirs(d)
        self.script = os.path.join(d, "bw_falso.py")
        with open(self.script, "w", encoding="utf-8") as f:
            f.write(BW_FALSO)
        self.vault = os.path.join(d, "vault.json")
        self._vault({"sessao": SESSAO, "itens": []})
        self.bw = [sys.executable, "-I", self.script, self.vault]
        self.env = mock.patch.dict(os.environ)
        self.env.start()
        os.environ.pop("BW_SESSION", None)

    def tearDown(self):
        self.env.stop()
        super().tearDown()

    def _vault(self, db=None):
        if db is not None:
            with open(self.vault, "w", encoding="utf-8") as f:
                json.dump(db, f)
        with open(self.vault, encoding="utf-8") as f:
            return json.load(f)

    def _argv_log(self):
        p = self.vault + ".argv.log"
        if not os.path.exists(p):
            return []
        with open(p, encoding="utf-8") as f:
            return [json.loads(l) for l in f if l.strip()]

    def _push(self, **kw):
        kw.setdefault("sessao", SESSAO)
        return cofre.push(self.contrato, self.maquina, store=self.store, bw=self.bw, log=lambda *_: None, **kw)

    def _pull(self, **kw):
        kw.setdefault("sessao", SESSAO)
        return cofre.pull(self.contrato, self.maquina, bw=self.bw, **kw)

    def _manifestos_cofre(self):
        pasta = os.path.join(self.nuvem, bk.RECOVERY, "manifests", "proj")
        return sorted(n for n in os.listdir(pasta) if n.startswith("cofre-")) if os.path.isdir(pasta) else []

    def _motivos_segredo(self, store="padrao"):
        fatos = gitinfo.resumo(self.proj, [], [])
        ms = portability._so_nesta_pasta(self.contrato, self.proj, fatos, self.store if store == "padrao" else store)
        return [m for m in ms if ".env" in m or "cofre" in m or "segredo" in m]


class TestPush(BaseCofre):
    def test_push_cria_secure_note_confere_e_grava_manifesto_sem_valores(self):
        r = self._push()
        self.assertEqual([i["estado"] for i in r["itens"]], ["criado"])
        itens = self._vault()["itens"]
        self.assertEqual(len(itens), 1)
        it = itens[0]
        self.assertEqual(it["name"], "emmily-os/proj/.env")
        self.assertEqual(it["type"], 2)
        self.assertEqual(it["notes"], ENV)
        self.assertIn({"name": "sha256", "value": _sha(ENV.encode()), "type": 0}, it["fields"])
        nomes = self._manifestos_cofre()
        self.assertEqual(len(nomes), 1)
        m = json.loads(self.store.ler_texto("/".join([bk.RECOVERY, "manifests", "proj", nomes[0]])))
        self.assertEqual(m["project"], "proj")
        self.assertEqual(m["itens"], [{"arquivo": ".env", "item_nome": "emmily-os/proj/.env", "item_id": it["id"],
                                       "sha256": _sha(ENV.encode()), "chaves": ["API_TOKEN", "OUTRA_CHAVE"]}])
        bruto = json.dumps(m)
        self.assertNotIn(VALOR, bruto)
        self.assertNotIn(VALOR2, bruto)

    def test_push_de_novo_atualiza_o_mesmo_item(self):
        self._push()
        self._w(".env", ENV + "NOVA=VALOR-FALSO-NOVO-999\n")
        self._w(".env.local", "LOCAL_X=VALOR-FALSO-LOCAL-777\n")
        r = self._push()
        self.assertEqual({i["arquivo"]: i["estado"] for i in r["itens"]}, {".env": "atualizado", ".env.local": "criado"})
        itens = {i["name"]: i for i in self._vault()["itens"]}
        self.assertEqual(sorted(itens), ["emmily-os/proj/.env", "emmily-os/proj/.env.local"])
        self.assertTrue(itens["emmily-os/proj/.env"]["notes"].endswith("NOVA=VALOR-FALSO-NOVO-999\n"))
        self.assertEqual(itens["emmily-os/proj/.env"]["id"], "id-falso-0001", "editou outro item em vez do existente")
        r3 = self._push()
        self.assertEqual({i["estado"] for i in r3["itens"]}, {"inalterado"})
        self.assertEqual(len(self._vault()["itens"]), 2)

    def test_sem_sessao_erro_h1_e_nada_e_feito(self):
        with self.assertRaises(cofre.SemSessao) as ctx:
            self._push(sessao=None)
        self.assertIn("H1", str(ctx.exception))
        self.assertIn("bw login", str(ctx.exception))
        # sessao errada (cofre trancado): o motor pergunta o status e para
        with self.assertRaises(cofre.SemSessao):
            self._push(sessao="SESSAO-ERRADA-0002")
        chamadas = [a[0] for a in self._argv_log()]
        self.assertEqual(set(chamadas) - {"status"}, set(), chamadas)
        self.assertEqual(self._vault()["itens"], [])
        self.assertEqual(self._manifestos_cofre(), [])

    def test_conferencia_divergente_falha_e_nao_grava_manifesto_completo(self):
        db = self._vault()
        db["corromper"] = True
        self._vault(db)
        with self.assertRaises(cofre.ConferenciaFalhou) as ctx:
            self._push()
        self.assertNotIn(VALOR, str(ctx.exception))
        # o cofre ja foi alterado: o manifesto que fica e o INCOMPLETO, que o check acusa (r10, QA-A2)
        self.assertEqual(len(self._manifestos_cofre()), 1)
        m = cofre.ultimo_manifesto_cofre(self.store, "proj")
        self.assertTrue(m["incompleto"])
        self.assertEqual(m["itens"], [])
        self.assertFalse(cofre.verificar_cofre(self.contrato, self.store, self.maquina)["ok"])

    def test_nuvem_indisponivel_nada_vai_ao_cofre(self):
        from eos import cloud
        with self.assertRaises(cofre.CofreErro):
            cofre.push(self.contrato, self.maquina, store=cloud.DirStore(os.path.join(self.tmp, "nao-existe")),
                       bw=self.bw, sessao=SESSAO, log=lambda *_: None)
        self.assertEqual(self._vault()["itens"], [])
        self.assertFalse([a for a in self._argv_log() if a[:1] in (["create"], ["edit"], ["encode"])])

    def test_duplicata_no_cofre_recusa(self):
        self._push()
        db = self._vault()
        db["itens"].append(dict(db["itens"][0], id="id-falso-9999"))
        self._vault(db)
        with self.assertRaises(cofre.CofreErro):
            self._push()

    def test_ultimo_manifesto_de_backup_ignora_cofre(self):
        m = self._backup()
        self._push()
        self.assertTrue(self._manifestos_cofre())
        self.assertEqual(bk.ultimo_manifesto(self.store, "proj")["timestamp"], m["timestamp"])


class TestPull(BaseCofre):
    def setUp(self):
        super().setUp()
        self._push()
        self.novo = os.path.join(self.tmp, "novo-pc")
        os.makedirs(self.novo)

    def _ler(self, p):
        with open(p, "rb") as f:
            return f.read()

    def test_pull_restaura_identico_e_depois_ja_presente(self):
        r = self._pull(destino_dir=self.novo)
        self.assertTrue(r["ok"], r)
        self.assertEqual([(i["arquivo"], i["estado"]) for i in r["itens"]], [(".env", "restaurado")])
        self.assertEqual(self._ler(os.path.join(self.novo, ".env")), ENV.encode())
        r2 = self._pull(destino_dir=self.novo)
        self.assertEqual([i["estado"] for i in r2["itens"]], ["ja-presente"])
        self.assertTrue(r2["ok"])

    def test_pull_recusa_sobrescrever_conteudo_diferente(self):
        alvo = os.path.join(self.novo, ".env")
        with open(alvo, "wb") as f:
            f.write(b"API_TOKEN=VALOR-FALSO-LOCAL-DIFERENTE\n")
        r = self._pull(destino_dir=self.novo)
        self.assertFalse(r["ok"])
        self.assertEqual([i["estado"] for i in r["itens"]], ["recusado-diferente"])
        self.assertEqual(self._ler(alvo), b"API_TOKEN=VALOR-FALSO-LOCAL-DIFERENTE\n")
        r2 = self._pull(destino_dir=self.novo, sobrescrever=True)
        self.assertTrue(r2["ok"], r2)
        self.assertEqual([i["estado"] for i in r2["itens"]], ["sobrescrito"])
        self.assertEqual(self._ler(alvo), ENV.encode())

    def test_pull_na_raiz_do_projeto(self):
        os.remove(os.path.join(self.proj, ".env"))
        r = self._pull()
        self.assertTrue(r["ok"], r)
        self.assertEqual(self._ler(os.path.join(self.proj, ".env")), ENV.encode())

    def test_pull_recusa_destino_em_repo_que_nao_ignora_o_env(self):
        repo = os.path.join(self.tmp, "repo-sem-ignore")
        os.makedirs(repo)
        sh(repo, "init", "-q")
        sh(repo, "config", "core.excludesfile", os.path.join(self.tmp, "sem-excludes-global"))
        r = self._pull(destino_dir=repo)
        self.assertFalse(r["ok"])
        self.assertEqual([i["estado"] for i in r["itens"]], ["recusado-nao-ignorado"])
        self.assertFalse(os.path.exists(os.path.join(repo, ".env")))

    def test_pull_ignora_item_com_nome_fora_da_lista(self):
        db = self._vault()
        db["itens"].append({"id": "id-falso-0666", "type": 2, "name": "emmily-os/proj/../../fuga.txt",
                            "notes": "VALOR-FALSO-FUGA", "fields": []})
        self._vault(db)
        r = self._pull(destino_dir=self.novo)
        self.assertIn(("../../fuga.txt", "ignorado"), [(i["arquivo"], i["estado"]) for i in r["itens"]])
        self.assertFalse(os.path.exists(os.path.join(self.tmp, "fuga.txt")))
        self.assertFalse(os.path.exists(os.path.join(os.path.dirname(self.tmp), "fuga.txt")))

    def test_pull_recusa_item_com_hash_que_nao_confere(self):
        db = self._vault()
        db["itens"][0]["notes"] += "ADULTERADO\n"
        self._vault(db)
        r = self._pull(destino_dir=self.novo)
        self.assertFalse(r["ok"])
        self.assertEqual([i["estado"] for i in r["itens"]], ["recusado-hash"])
        self.assertFalse(os.path.exists(os.path.join(self.novo, ".env")))

    def test_pull_sem_sessao_e_h1(self):
        with self.assertRaises(cofre.SemSessao):
            self._pull(destino_dir=self.novo, sessao=None)
        self.assertFalse(os.path.exists(os.path.join(self.novo, ".env")))


class TestNadaVaza(BaseCofre):
    def _cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(cli.paths, "carregar_maquina", return_value=self.maquina), \
                mock.patch.object(cli.registry, "carregar", return_value={"proj": self.contrato}), \
                mock.patch.object(cli, "_store", return_value=self.store), \
                mock.patch.object(cofre, "resolver_bw", return_value=self.bw), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = cli.main(list(argv))
        return rc, out.getvalue() + err.getvalue()

    def test_cli_completo_sem_valor_em_saida_argv_manifesto_ou_nuvem(self):
        os.environ["BW_SESSION"] = SESSAO
        saidas = []
        rc, o = self._cli("secrets-push", "proj")
        saidas.append(o)
        self.assertEqual(rc, 0, o)
        self.assertIn("API_TOKEN", o)
        self.assertIn("emmily-os/proj/.env", o)
        rc, o = self._cli("secrets-status", "proj")
        saidas.append(o)
        self.assertEqual(rc, 0, o)
        novo = os.path.join(self.tmp, "novo-pc")
        os.makedirs(novo)
        rc, o = self._cli("secrets-pull", "proj", "--para", novo)
        saidas.append(o)
        self.assertEqual(rc, 0, o)
        rc, o = self._cli("secrets-pull", "proj", "--para", novo)
        saidas.append(o)
        self.assertEqual(rc, 0, o)
        with open(os.path.join(novo, ".env"), "w", newline="\n") as f:
            f.write("API_TOKEN=VALOR-FALSO-OUTRO-PC-42\n")
        rc, o = self._cli("secrets-pull", "proj", "--para", novo)
        saidas.append(o)
        self.assertEqual(rc, 1, o)
        b64 = base64.b64encode(ENV.encode()).decode()
        proibidos = [VALOR, VALOR2, SESSAO, b64, "VALOR-FALSO-OUTRO-PC-42"]
        texto = "\n".join(saidas)
        argv = json.dumps(self._argv_log())
        self.assertTrue(self._argv_log(), "o bw falso nao foi chamado: o teste passaria por vacuidade")
        nuvem = []
        for r_, _, fs in os.walk(self.nuvem):
            for f_ in fs:
                with open(os.path.join(r_, f_), encoding="utf-8", errors="replace") as fh:
                    nuvem.append(fh.read())
        self.assertTrue(nuvem, "nenhum manifesto na nuvem: o teste passaria por vacuidade")
        for v in proibidos:
            self.assertNotIn(v, texto, "valor vazou na saida do CLI")
            self.assertNotIn(v, argv, "valor vazou no argv do bw")
            self.assertNotIn(v, "\n".join(nuvem), "valor vazou na nuvem")

    def test_cli_sem_sessao_sai_com_2_e_pede_h1(self):
        rc, o = self._cli("secrets-push", "proj")
        self.assertEqual(rc, 2, o)
        self.assertIn("H1", o)
        self.assertNotIn(VALOR, o)
        self.assertEqual(self._vault()["itens"], [])

    def test_cli_status_aponta_env_mudado(self):
        os.environ["BW_SESSION"] = SESSAO
        self._cli("secrets-push", "proj")
        self._w(".env", ENV + "X=VALOR-FALSO-X-31337\n")
        rc, o = self._cli("secrets-status", "proj")
        self.assertEqual(rc, 1, o)
        self.assertIn("mudou desde o ultimo push", o)
        self.assertNotIn("VALOR-FALSO-X-31337", o)


class TestSoNestaPasta(BaseCofre):
    def test_bitwarden_sem_push_e_motivo(self):
        ms = self._motivos_segredo()
        self.assertTrue(any("sem push para o cofre" in m for m in ms), ms)

    def test_bitwarden_com_manifesto_batendo_sem_motivo(self):
        self._push()
        self.assertEqual(self._motivos_segredo(), [])
        v = cofre.verificar_cofre(self.contrato, self.store, self.maquina)
        self.assertTrue(v["ok"], v)

    def test_env_alterado_depois_do_push_motivo_volta(self):
        self._push()
        self._w(".env", ENV + "Y=VALOR-FALSO-Y\n")
        ms = self._motivos_segredo()
        self.assertTrue(any("'.env' mudou desde o ultimo push para o cofre" in m for m in ms), ms)
        self.assertFalse(cofre.verificar_cofre(self.contrato, self.store, self.maquina)["ok"])

    def test_env_local_nunca_enviado_e_motivo(self):
        self._push()
        self._w(".env.local", "Z=VALOR-FALSO-Z\n")
        ms = self._motivos_segredo()
        self.assertTrue(any("'.env.local'" in m for m in ms), ms)

    def test_local_env_continua_igual(self):
        self.contrato["secrets"]["store"] = "local-env"
        self._push()
        self.assertEqual(self._motivos_segredo(),
                         ["segredos com valor so nesta pasta (.env, store local-env): leve para o cofre antes"])

    def test_nuvem_ilegivel_falha_fechada(self):
        self._push()
        ms = self._motivos_segredo(store=None)
        self.assertTrue(any("cofre" in m and "nao verificavel" in m for m in ms), ms)


class TestEscadaIntocada(BaseCofre):
    """O cofre so responde 'posso trocar de PC': o nivel L6 nao muda por causa dele."""

    def setUp(self):
        super().setUp()
        self.bare = os.path.join(self.tmp, "remoto.git")
        sh(self.tmp, "init", "-q", "--bare", self.bare)
        sh(self.proj, "remote", "add", "origin", self.bare)
        sh(self.proj, "push", "-q", "origin", "main", "feature")
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

    def test_l6_troca_de_pc_so_depois_do_push_e_volta_a_nao_com_env_alterado(self):
        self._backup()
        r = portability.verificar(self.contrato, self.store, self.maquina, rede=True)
        self.assertEqual(r["nivel"], "L6", json.dumps(r["dimensoes"], indent=1, ensure_ascii=False))
        self.assertFalse(r["seguro_trocar_computador"])
        self.assertTrue(any("sem push para o cofre" in m for m in r["motivos_nao"]["computador"]), r["motivos_nao"])
        self._push()
        r = portability.verificar(self.contrato, self.store, self.maquina, rede=True)
        self.assertEqual(r["nivel"], "L6")
        self.assertTrue(r["seguro_trocar_computador"], r["motivos_nao"])
        self._w(".env", ENV + "W=VALOR-FALSO-W\n")
        r = portability.verificar(self.contrato, self.store, self.maquina, rede=True)
        self.assertEqual(r["nivel"], "L6")
        self.assertFalse(r["seguro_trocar_computador"])
        self.assertNotIn("VALOR-FALSO-W", json.dumps(r))


if __name__ == "__main__":
    unittest.main()
