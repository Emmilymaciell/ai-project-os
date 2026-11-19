"""CLI do motor vNext.  py -3 -m eos <comando> ...

  validate                         valida todos os contratos do registry
  status [--sem-rede]              portfolio: nivel, seguranca, operacao e ownership (own) de cada projeto
  check <id> [--json] [--sem-rede] portability check com respostas objetivas (+ ownership, informativa)
  backup <id>... | --todos         backup na nuvem (git + WIP + bancos), conferido por hash
  certify <id> [--manter]          restauracao isolada + verificacoes + smoke; grava evidencia
  restore <id> --para <dir> [--fonte auto|cloud|github] [--com-dados]
                                   --com-dados: depois do Git, baixa o ultimo espelho cloud-mirror para
                                   <dir>/<path> e confere tamanho e md5 de cada arquivo
  mirror <id>... | --todos         espelha os data[] cloud-mirror em <drive_root>/dados/<path>: copia
                                   ADITIVA (nada apagado; versao substituida vai para dados-anteriores/
                                   <ts>/), incremental, conferida por tamanho e md5; nome de segredo
                                   nao sobe. Manifesto 99 RECOVERY/manifests/<id>/mirror-<ts>.json +
                                   journal %LOCALAPPDATA%/emmily-os/mirror/<id>/. --todos: so PROJECT
                                   com algum cloud-mirror
  prepare-machine-migration        o que falta para trocar de computador, projeto a projeto
  index                            reconstroi o indice SQLite derivado
  resolve <texto>                  resolve ${VARS} nesta maquina
  new <id> --name "<nome>" --category <CAT> [--runtime python|node|none] [--sem-remoto] [--dry-run] [--certificar] [--descricao "<frase>"]
                                   nascimento protegido: projeto novo nunca nasce L0 (eos/novo.py)
  ownership-check <id> [--json]    titularidade declarada x fatos (Git, assinatura, remoto, arquivos);
                                   read-only; PASS/WARN/FAIL/N/A por item
  ownership-init <id>              gera PROVENANCE/OWNERSHIP/AUTHORS/NOTICE/CODEOWNERS que faltam num
                                   projeto existente (nunca sobrescreve, nao commita; recusa se a
                                   pasta local nao for a raiz de um repositorio Git)
  ownership-certify <id> [--tag]   roda o check, recusa com FAIL; grava o certificado na nuvem
                                   (99 RECOVERY/manifests/<id>/ownership-<ts>.json) e no journal da
                                   maquina (%LOCALAPPDATA%/emmily-os/ownership/<id>/), nunca no
                                   working tree. --tag: tag ASSINADA ownership-YYYYMMDD no HEAD
  secrets-push <id>                leva .env/.env.local da raiz do projeto para o Bitwarden (Secure Note
                                   emmily-os/<id>/<arquivo>, conteudo SO pelo stdin do bw), rele e confere
                                   o sha256; grava 99 RECOVERY/manifests/<id>/cofre-<ts>.json SEM valores
  secrets-pull <id> [--para <dir>] [--sobrescrever]
                                   traz os itens do cofre para a raiz do projeto (ou <dir>), conferindo o
                                   sha256; arquivo local diferente so com --sobrescrever
  secrets-status <id>              bw encontrado? cofre desbloqueado? cada .env bate com o ultimo push?
                                   Push/pull exigem cofre desbloqueado (H1 humano: bw login + bw unlock e
                                   BW_SESSION no ambiente). Saida so com nomes de variavel, item e sha curto

Codigos de saida: 0 ok; 1 verificacao reprovou / algo nao seguro; 2 erro de uso ou execucao
(secrets-*: 2 tambem para H1 - cofre sem sessao desbloqueada).
"""
import json
import os
import sys

from . import backup as bk
from . import cloud, cofre, contract, gitinfo, mirror, ownership, paths, portability, registry, restore

SIM = {True: "SIM", False: "NAO"}


def _store(maquina):
    return cloud.store_da_maquina(maquina)


def _own(status):
    return {"PASS": "PASS", "WARN": "WARN", "FAIL": "FAIL"}.get(status, "-")


def _linha_check(r, own="-"):
    return "%-30s %-4s %-8s %-9s %-4s sessao=%s clone=%s pc=%s" % (
        r["project"], r.get("nivel") or "-", r.get("safety", "-"), r.get("operation", "-"), own,
        SIM[r.get("seguro_apagar_sessao", False)], SIM[r.get("seguro_apagar_clone", False)],
        SIM[r.get("seguro_trocar_computador", False)])


def _imprimir_check(r):
    print("Projeto: %s   (verificado em %s)" % (r["project"], r["verificado_em"]))
    if r.get("nivel") is None and r.get("observacao"):
        print("  " + r["observacao"])
        return
    print("  Nivel de portabilidade: %s    Seguranca: %s    Operacao: %s" % (r["nivel"], r["safety"], r["operation"]))
    for nome, d in r["dimensoes"].items():
        print("    %-12s %-8s %s" % (nome, d["status"], d["motivo"]))
    if r.get("bloqueios"):
        print("  Para chegar a %s falta:" % r.get("proximo_nivel"))
        for b in r["bloqueios"]:
            print("    - " + b)
    print("  Posso apagar esta sessao?        %s %s" % (SIM[r["seguro_apagar_sessao"]], "; ".join(r["motivos_nao"]["sessao"])))
    print("  Posso apagar a pasta local?      %s %s" % (SIM[r["seguro_apagar_clone"]], "; ".join(r["motivos_nao"]["clone"][:3])))
    print("  Posso trocar de computador?      %s %s" % (SIM[r["seguro_trocar_computador"]], "; ".join(r["motivos_nao"]["computador"][:3])))
    if r.get("operation_motivo"):
        print("  Operacao degradada: " + r["operation_motivo"])


def _imprimir_ownership(o):
    print("Ownership: %s   (verificado em %s)   %s" % (o["project"], o["verificado_em"], o["status"]))
    for i in o["itens"]:
        print("    %-16s %-5s %s" % (i["item"], i["status"], i["motivo"]))
        for a in i.get("achados") or []:
            print("        - " + a)


def _cli_cofre(cmd, args, itens, store, maquina):
    """secrets-push/pull/status (eos/cofre.py). Nunca imprime valor: so nomes, item e sha curto."""
    if not args or args[0] not in itens:
        print("uso: %s <id>%s" % (cmd, " [--para <dir>] [--sobrescrever]" if cmd == "secrets-pull" else "")
              + (" (desconhecido: %s)" % args[0] if args else ""))
        return 2
    c = itens[args[0]]
    try:
        if cmd == "secrets-push":
            r = cofre.push(c, maquina, store=store, log=lambda *_: None)
            for i in r["itens"]:
                print("  %-12s %-10s item %s (id %s) sha256 %s  chaves: %s" % (
                    i["arquivo"], i["estado"], i["item_nome"], str(i["item_id"])[:8], i["sha256"][:12],
                    ", ".join(i["chaves"]) or "-"))
            print("COFRE OK: conferido por sha256; manifesto %s" % r["nuvem"])
            return 0
        if cmd == "secrets-pull":
            if "--para" in args and args.index("--para") + 1 >= len(args):
                print("uso: secrets-pull <id> [--para <dir>] [--sobrescrever]")
                return 2
            dst = args[args.index("--para") + 1] if "--para" in args else None
            r = cofre.pull(c, maquina, destino_dir=dst, sobrescrever="--sobrescrever" in args)
            for i in r["itens"]:
                print("  %-12s %-22s item %s%s" % (i["arquivo"], i["estado"], i["item_nome"],
                                                   "  sha256 %s  chaves: %s" % (i["sha256"][:12], ", ".join(i["chaves"]) or "-")
                                                   if "sha256" in i else ""))
            print("PULL %s em %s" % ("OK" if r["ok"] else "COM RECUSA (nada sobrescrito sem --sobrescrever)", r["destino"]))
            return 0 if r["ok"] else 1
        bw = cofre.resolver_bw()
        print("Cofre: %s   (secrets.store: %s)" % (args[0], (c.get("secrets") or {}).get("store")))
        print("  bw:     %s" % (bw if isinstance(bw, str) else ("injetado" if bw else "NAO ENCONTRADO")))
        if bw:
            try:
                print("  status: %s" % cofre.status(bw, os.environ.get("BW_SESSION")))
            except cofre.CofreErro as e:
                print("  status: nao lido (%s)" % e)
        v = cofre.verificar_cofre(c, store, maquina)
        print("  ultimo push: %s" % (v["manifesto"] or "nunca"))
        for a in v["arquivos"]:
            print("    %-12s %-4s local %s  cofre %s" % (a["arquivo"], "ok" if a["ok"] else "NAO", a["sha256_local"][:12],
                                                     (a["sha256_cofre"] or "-")[:12]))
        for m in v["motivos"]:
            print("  - " + m)
        return 0 if v["ok"] else 1
    except cofre.SemSessao as e:
        print("ERRO: %s" % e)
        return 2
    except cofre.ConferenciaFalhou as e:
        print("FALHOU NA CONFERENCIA: %s" % e)
        return 1
    except cofre.CofreErro as e:
        print("ERRO: %s" % e)
        return 2


def exigir_python(versao=None):
    """O motor usa shutil.rmtree(onexc=), que so existe a partir do 3.12 (ADR-0014 manda 3.13).
    Sem esta guarda, Python antigo falhava com TypeError no meio do backup (r4 do QA, achado 6)."""
    v = tuple(versao or sys.version_info)[:3]
    if v < (3, 12):
        raise SystemExit("ERRO: o motor exige Python 3.12+ (use py -3.13); este e %s" % ".".join(map(str, v)))


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd, args = argv[0], argv[1:]
    sem_rede = "--sem-rede" in args
    args = [a for a in args if a != "--sem-rede"]
    maquina = paths.carregar_maquina()
    if cmd == "resolve":
        print(paths.resolver(" ".join(args), maquina))
        return 0
    if cmd == "validate":
        itens, erros = registry.carregar(estrito=False)
        for e in erros:
            print("ERRO " + e)
        print("%d contrato(s) valido(s), %d erro(s)" % (len(itens), len(erros)))
        return 1 if erros else 0
    if cmd == "new":
        # nascimento protegido (eos/novo.py): roda antes do carregar() estrito, que ele faz por conta
        from . import novo
        return novo.cli(args, maquina, sem_rede=sem_rede)
    itens = registry.carregar()
    if cmd == "index":
        print(registry.rebuild_index(itens))
        return 0
    store = _store(maquina)
    if cmd in ("status", "prepare-machine-migration"):
        res, ruim = {}, 0
        print("%-30s %-4s %-8s %-9s %-4s %s" % ("projeto", "niv", "safety", "operacao", "own", "respostas"))
        for pid in sorted(itens):
            r = portability.verificar(itens[pid], store, maquina, rede=not sem_rede)
            res[pid] = r
            if r.get("nivel") is None:
                # classificado (ARCHIVE/COLLECTION/REFERENCE_DATA/...): own so se houver secao declarada
                try:
                    own = _own(ownership.verificar(itens[pid], maquina)["status"])
                except Exception:
                    own = "ERR"
                print("%-30s %-4s %-8s %-9s %-4s %s" % (pid, "-", "-", "-", own, "(%s - classificado)" % r["type"]))
                continue
            print(_linha_check(r, _own((r["dimensoes"].get("ownership") or {}).get("status"))))
            ruim += 0 if r["seguro_trocar_computador"] else 1
        registry.rebuild_index(itens, verificacoes=res)
        if cmd == "prepare-machine-migration":
            print("\nAntes de trocar de computador:")
            for pid in sorted(res):
                r = res[pid]
                if r.get("nivel") is None or r["seguro_trocar_computador"]:
                    continue
                print("  %s (%s):" % (pid, r["nivel"]))
                for b in r["motivos_nao"]["computador"]:
                    print("    - " + b)
            print("\n%s" % ("PRONTO para trocar de computador." if not ruim else
                            "NAO esta pronto: %d projeto(s) com bloqueio. Nada foi alterado." % ruim))
        return 1 if ruim else 0
    if cmd == "check":
        r = portability.verificar(itens[args[0]], store, maquina, rede=not sem_rede)
        print(json.dumps(r, ensure_ascii=False, indent=2)) if "--json" in args else _imprimir_check(r)
        return 0 if r.get("seguro_apagar_clone") else 1
    if cmd in ("ownership-check", "ownership-certify", "ownership-init") and not args:
        print("uso: %s <id>" % cmd)
        return 2
    if cmd == "ownership-check":
        o = ownership.verificar(itens[args[0]], maquina, store=store)
        print(json.dumps(o, ensure_ascii=False, indent=2)) if "--json" in args else _imprimir_ownership(o)
        return 1 if o["falhas"] else 0
    if cmd == "ownership-init":
        # Projeto EXISTENTE adotado pelo OS: gera so os arquivos que faltam; nunca sobrescreve e
        # nao commita (commit continua sendo pedido explicito da titular).
        c = itens[args[0]]
        if "ownership" not in c:
            print("ERRO: o contrato de %s nao tem secao ownership; preencha-a antes" % args[0])
            return 2
        # mesmo caminho que check/backup usam (override da maquina > workspace.local_path); so gera na
        # RAIZ de um repositorio Git existente - nunca cria a pasta do projeto (r8, Q2)
        d = paths.caminho_local(c, maquina)
        if not d or not os.path.isdir(d):
            print("ERRO: pasta local de %s nao existe nesta maquina: %s (nada criado)" % (args[0], d))
            return 2
        rc, topo = gitinfo.git(d, "rev-parse", "--show-toplevel", check=False)
        if rc != 0 or os.path.normcase(os.path.realpath(topo.strip())) != os.path.normcase(os.path.realpath(d)):
            print("ERRO: %s nao e a raiz de um repositorio Git (toplevel: %s); nada criado"
                  % (d, topo.strip() if rc == 0 else "nenhum"))
            return 2
        for rel, estado in sorted(ownership.gerar_arquivos(d, c).items()):
            print("  %-22s %s" % (rel, estado))
        print("Nada commitado. Revise e commite so estes arquivos (git add <arquivos>; nunca git add .).")
        return 0
    if cmd == "ownership-certify":
        c = ownership.certificar(itens[args[0]], store, maquina, tag="--tag" in args)
        _imprimir_ownership(c["check"])
        if not c["ok"]:
            print("CERTIFICACAO DE OWNERSHIP RECUSADA: %s" % c.get("recusado"))
            return 1
        print("CERTIFICACAO DE OWNERSHIP GRAVADA: nuvem %s | journal %s" % (c["nuvem"], c["journal"]))
        if c["certificado"].get("tag"):
            t = c["certificado"]["tag"]
            print("  tag assinada %s -> %s. Ref NOVA: rode `backup %s` e publique a tag, senao o L2/L3 acusa."
                  % (t["name"], t["target"][:8], args[0]))
        return 0
    if cmd in ("secrets-push", "secrets-pull", "secrets-status"):
        return _cli_cofre(cmd, args, itens, store, maquina)
    if cmd == "backup":
        alvos =sorted(p for p, c in itens.items() if c["identity"]["type"] == "PROJECT") if "--todos" in args else args
        falhas = 0
        for pid in alvos:
            print("backup %s" % pid)
            try:
                m = bk.backup(itens[pid], store, maquina)
                print("  manifesto %s%s" % (m["timestamp"], " (INCOMPLETO)" if m.get("incompleto") else ""))
                falhas += 1 if m.get("incompleto") else 0
            except Exception as e:
                print("  FALHOU: %s" % e)
                falhas += 1
        return 1 if falhas else 0
    if cmd == "mirror":
        if "--todos" in args:
            alvos = sorted(p for p, c in itens.items() if c["identity"]["type"] == "PROJECT" and mirror.caminhos(c))
        else:
            alvos = [a for a in args if not a.startswith("--")]
        desconhecidos = [p for p in alvos if p not in itens]
        if not alvos or desconhecidos:
            print("uso: mirror <id>... | --todos" + (" (desconhecido: %s)" % ", ".join(desconhecidos) if desconhecidos else ""))
            return 2
        falhas, erros = 0, 0
        for pid in alvos:
            print("mirror %s" % pid)
            try:
                r = mirror.espelhar(itens[pid], store, maquina)
            except (mirror.MirrorErro, cloud.NuvemErro, paths.CaminhoNaoResolvido, OSError) as e:
                print("  ERRO: %s" % e)
                erros += 1
                continue
            for p, reg in r["manifesto"]["paths"].items():
                print("  %-40s %s" % (p, reg["estado"]))
            print("  enviados %d | ja presentes %d | substituidos %d (anterior preservada) | recusados %d"
                  % (r["enviados"], r["ja_presentes"], r["substituidos"], r["recusados"]))
            print("  manifesto %s%s" % (r["nuvem"], "" if r["ok"] else "  -- FALHOU NA VERIFICACAO"))
            if r.get("pendentes"):
                print("  decisao pendente (nada enviado): %s" % ", ".join(r["pendentes"]))
            falhas += 0 if (r["ok"] and not r.get("pendentes")) else 1
        return 2 if erros else (1 if falhas else 0)
    if cmd == "certify":
        c = portability.certificar(itens[args[0]], store, maquina, manter="--manter" in args)
        for v in c.get("verificacoes", []):
            print("  [%s] %s" % ("ok" if v["ok"] else "FALHOU", v["o_que"]))
        if c.get("erro"):
            print("  ERRO: " + c["erro"])
        print("CERTIFICACAO %s - nivel agora: %s" % ("APROVADA" if c["ok"] else "REPROVADA", c["nivel_depois"]))
        return 0 if c["ok"] else 1
    if cmd == "restore":
        if "--para" not in args:
            print("uso: restore <id> --para <diretorio vazio>")
            return 2
        dst = args[args.index("--para") + 1]
        fonte = args[args.index("--fonte") + 1] if "--fonte" in args else "auto"
        rel = restore.restaurar(itens[args[0]], store, dst, fonte=fonte, com_dados="--com-dados" in args)
        for v in rel["verificacoes"]:
            print("  [%s] %s" % ("ok" if v["ok"] else "FALHOU", v["o_que"]))
        print("RESTORE %s em %s" % ("VERIFICADO" if rel["ok"] else "COM FALHA", dst))
        return 0 if rel["ok"] else 1
    print("comando desconhecido: %s" % cmd)
    return 2


if __name__ == "__main__":
    exigir_python()
    try:
        sys.exit(main(sys.argv[1:]))
    except (paths.CaminhoNaoResolvido, ValueError, KeyError, cloud.NuvemErro, restore.RestoreErro,
            ownership.OwnershipErro, gitinfo.GitErro, mirror.MirrorErro, cofre.CofreErro) as e:
        print("ERRO: %s" % e, file=sys.stderr)
        sys.exit(2)
