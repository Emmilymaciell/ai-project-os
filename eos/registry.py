"""Registry canonico: um YAML por item em registry/projects/<id>.yaml.

Os YAML versionados sao a fonte de verdade. O indice SQLite (registry.db) e DERIVADO: pode
ser apagado e reconstruido a qualquer momento por `rebuild_index`, e nunca e lido como fonte
de nada que nao esteja nos YAML.
"""
import json
import os
import sqlite3

from . import contract, yamlite

RAIZ_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def pasta(raiz_repo=None):
    return os.path.join(raiz_repo or RAIZ_REPO, "registry", "projects")


def carregar(raiz_repo=None, estrito=True):
    """{id: contrato}. Com estrito=True, qualquer contrato invalido levanta ValueError listando TODOS."""
    itens, erros = {}, []
    p = pasta(raiz_repo)
    if not os.path.isdir(p):
        raise ValueError("registry nao encontrado em %s" % p)
    for nome in sorted(os.listdir(p)):
        if not nome.endswith(".yaml"):
            continue
        try:
            doc = yamlite.load_file(os.path.join(p, nome))
        except yamlite.YamlErro as e:
            erros.append("%s: %s" % (nome, e))
            continue
        es = contract.validar(doc, nome)
        if es:
            erros.extend("%s: %s" % (nome, e) for e in es)
            continue
        itens[doc["identity"]["id"]] = doc
    if estrito and erros:
        raise ValueError("registry invalido:\n  " + "\n  ".join(erros))
    if not itens and estrito:
        raise ValueError("registry vazio em %s" % p)
    return itens if estrito else (itens, erros)


def caminho_indice():
    base = os.environ.get("LOCALAPPDATA") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "emmily-os", "registry.db")


def rebuild_index(itens, destino=None, verificacoes=None):
    destino = destino or caminho_indice()
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    tmp = destino + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    con = sqlite3.connect(tmp)
    con.execute("create table item (id text primary key, name text, type text, category text, status text,"
                " criticality text, local_path text, remote text, drive_root text, target_level text, contrato text)")
    con.execute("create table verificacao (id text primary key, nivel text, safety text, operation text, json text)")
    for pid, c in itens.items():
        i = c["identity"]
        con.execute("insert into item values (?,?,?,?,?,?,?,?,?,?,?)",
                    (pid, i["name"], i["type"], i["category"], i["status"], i["criticality"],
                     (c.get("workspace") or {}).get("local_path"), (c.get("git") or {}).get("remote"),
                     (c.get("cloud") or {}).get("drive_root"), (c.get("portability") or {}).get("target_level"),
                     json.dumps(c, ensure_ascii=False)))
    for pid, v in (verificacoes or {}).items():
        con.execute("insert into verificacao values (?,?,?,?,?)",
                    (pid, v.get("nivel"), v.get("safety"), v.get("operation"), json.dumps(v, ensure_ascii=False)))
    con.commit()
    con.close()
    os.replace(tmp, destino)
    return destino
