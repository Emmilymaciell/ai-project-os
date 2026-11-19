"""Subconjunto ESTRITO de YAML, so com a stdlib.

Por que existe: nem a stdlib do Python nem o PowerShell 5.1 leem YAML, e o registry tem de ser
legivel por gente E por maquina, sem dependencia instalada (o motor precisa rodar numa maquina
recem-formatada, antes de qualquer `pip`).

O que aceita:
  - mapas em bloco (`chave: valor`, `chave:` seguido de bloco indentado)
  - listas em bloco (`- valor`, `- chave: valor` abrindo um mapa)
  - escalares: "aspas duplas" (com \\ \" \n \t), 'aspas simples' ('' = '), inteiros,
    true/false, null/~, e texto simples
  - lista vazia `[]` e mapa vazio `{}`
  - comentario `#` em linha propria ou depois de espaco

O que RECUSA, com numero de linha (falhar fechado e melhor que adivinhar):
  - TAB na indentacao, ancora/alias/tag (& * !), fluxo nao vazio ([a, b] / {a: 1}),
    escalar de bloco (| >), chave duplicada, indentacao inconsistente.

A lista de fluxo e recusada de proposito: o leitor de manifesto da plataforma ja leu
`["a", "b"]` como UM valor (backlog 42). Aqui ela nao e lida errado - ela nao e lida.
"""
import re


class YamlErro(ValueError):
    def __init__(self, linha, msg):
        super().__init__("linha %d: %s" % (linha, msg))
        self.linha = linha


_INT = re.compile(r"^[-+]?[0-9]+$")


def _sem_comentario(texto):
    """Remove comentario fora de aspas."""
    em, i = None, 0
    while i < len(texto):
        c = texto[i]
        if em:
            if c == "\\" and em == '"':
                i += 2
                continue
            if c == em:
                if em == "'" and i + 1 < len(texto) and texto[i + 1] == "'":
                    i += 2
                    continue
                em = None
        elif c in "\"'":
            em = c
        elif c == "#" and (i == 0 or texto[i - 1] in " \t"):
            return texto[:i].rstrip()
        i += 1
    return texto.rstrip()


def _escalar(bruto, n):
    s = bruto.strip()
    if s == "":
        return None
    if s[0] == '"':
        if len(s) < 2 or s[-1] != '"':
            raise YamlErro(n, "aspas duplas sem fechamento")
        corpo, out, i = s[1:-1], [], 0
        while i < len(corpo):
            c = corpo[i]
            if c == "\\":
                if i + 1 >= len(corpo):
                    raise YamlErro(n, "barra invertida no fim da string")
                e = corpo[i + 1]
                mapa = {"\\": "\\", '"': '"', "n": "\n", "t": "\t", "/": "/"}
                if e not in mapa:
                    raise YamlErro(n, "escape nao suportado: \\%s (use aspas simples para caminho Windows)" % e)
                out.append(mapa[e])
                i += 2
                continue
            if c == '"':
                raise YamlErro(n, "aspas duplas no meio do valor")
            out.append(c)
            i += 1
        return "".join(out)
    if s[0] == "'":
        if len(s) < 2 or s[-1] != "'":
            raise YamlErro(n, "aspas simples sem fechamento")
        return s[1:-1].replace("''", "'")
    if s[0] in "&*!|>":
        raise YamlErro(n, "recurso de YAML nao suportado (%s)" % s[0])
    if s == "[]":
        return []
    if s == "{}":
        return {}
    if s[0] in "[{":
        raise YamlErro(n, "lista/mapa de fluxo nao suportado: use lista em bloco")
    if s in ("true", "True"):
        return True
    if s in ("false", "False"):
        return False
    if s in ("null", "~", "Null"):
        return None
    if _INT.match(s):
        return int(s)
    return s


def _linhas(texto):
    out = []
    for n, bruta in enumerate(texto.splitlines(), 1):
        if bruta.strip() == "" or bruta.lstrip().startswith("#"):
            continue
        ind = len(bruta) - len(bruta.lstrip(" "))
        if bruta[:ind + 1].count("\t") or (bruta.lstrip(" ")[:1] == "\t"):
            raise YamlErro(n, "TAB na indentacao")
        conteudo = _sem_comentario(bruta[ind:])
        if conteudo == "":
            continue
        out.append((n, ind, conteudo))
    return out


_CHAVE = re.compile(r"^([A-Za-z0-9_][A-Za-z0-9_.\-]*)\s*:(?:\s+(.*))?$|^([A-Za-z0-9_][A-Za-z0-9_.\-]*):$")


def _chave_valor(conteudo, n):
    m = _CHAVE.match(conteudo)
    if not m:
        return None
    chave = m.group(1) or m.group(3)
    resto = m.group(2) if m.group(1) else None
    return chave, resto


def _bloco(linhas, i, ind):
    """Le o bloco que comeca em linhas[i] com indentacao `ind`."""
    n, li, c = linhas[i]
    if c == "-" or c.startswith("- "):
        return _lista(linhas, i, ind)
    return _mapa(linhas, i, ind)


def _valor_depois_de_chave(linhas, i, ind_pai, resto, n):
    if resto is not None and resto.strip() != "":
        return _escalar(resto, n), i + 1
    if i + 1 < len(linhas) and linhas[i + 1][1] > ind_pai:
        return _bloco(linhas, i + 1, linhas[i + 1][1])
    if i + 1 < len(linhas) and linhas[i + 1][1] == ind_pai and (linhas[i + 1][2] == "-" or linhas[i + 1][2].startswith("- ")):
        # lista no mesmo recuo da chave (estilo comum)
        return _lista(linhas, i + 1, ind_pai)
    return None, i + 1


def _mapa(linhas, i, ind):
    d = {}
    while i < len(linhas):
        n, li, c = linhas[i]
        if li < ind:
            break
        if li > ind:
            raise YamlErro(n, "indentacao inesperada")
        if c == "-" or c.startswith("- "):
            break
        kv = _chave_valor(c, n)
        if kv is None:
            raise YamlErro(n, "esperava 'chave: valor'")
        k, resto = kv
        if k in d:
            raise YamlErro(n, "chave duplicada: %s" % k)
        d[k], i = _valor_depois_de_chave(linhas, i, ind, resto, n)
    return d, i


def _lista(linhas, i, ind):
    lst = []
    while i < len(linhas):
        n, li, c = linhas[i]
        if li < ind or not (c == "-" or c.startswith("- ")):
            if li > ind:
                raise YamlErro(n, "indentacao inesperada dentro da lista")
            break
        if li > ind:
            raise YamlErro(n, "indentacao inesperada")
        item = c[1:].lstrip(" ")
        if item == "":
            if i + 1 < len(linhas) and linhas[i + 1][1] > ind:
                v, i = _bloco(linhas, i + 1, linhas[i + 1][1])
            else:
                v, i = None, i + 1
            lst.append(v)
            continue
        kv = _chave_valor(item, n)
        if kv is not None and not item.startswith(("'", '"')):
            # item e um mapa: a primeira chave esta na linha do '-'
            ind_item = li + (len(c) - len(item))
            sint = list(linhas)
            sint[i] = (n, ind_item, item)
            v, i = _mapa(sint, i, ind_item)
            lst.append(v)
            continue
        lst.append(_escalar(item, n))
        i += 1
    return lst, i


def loads(texto):
    if texto.startswith("﻿"):
        texto = texto[1:]
    linhas = _linhas(texto)
    if not linhas:
        return {}
    if linhas[0][1] != 0:
        raise YamlErro(linhas[0][0], "documento deve comecar sem indentacao")
    v, i = _bloco(linhas, 0, 0)
    if i != len(linhas):
        raise YamlErro(linhas[i][0], "conteudo que nao pertence a nenhum bloco")
    return v


def load_file(caminho):
    with open(caminho, "r", encoding="utf-8") as f:
        return loads(f.read())


_SIMPLES = re.compile(r"^[A-Za-z0-9_./@][A-Za-z0-9_ ./@()+-]*$")


def _fmt(v):
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int):
        return str(v)
    s = str(v)
    if (_SIMPLES.match(s) and s not in ("true", "false", "null", "True", "False", "Null", "~")
            and not _INT.match(s) and not s.endswith(" ") and ": " not in s and " #" not in s):
        return s
    return "'" + s.replace("'", "''") + "'"


def dumps(obj, ind=0):
    pad = " " * ind
    out = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, dict) and v:
                out.append("%s%s:" % (pad, k))
                out.append(dumps(v, ind + 2))
            elif isinstance(v, list) and v:
                out.append("%s%s:" % (pad, k))
                out.append(dumps(v, ind + 2))
            elif isinstance(v, (dict, list)):
                out.append("%s%s: %s" % (pad, k, "{}" if isinstance(v, dict) else "[]"))
            else:
                out.append("%s%s: %s" % (pad, k, _fmt(v)))
    elif isinstance(obj, list):
        for v in obj:
            if isinstance(v, dict) and v:
                sub = dumps(v, ind + 2).split("\n")
                sub[0] = pad + "- " + sub[0].lstrip(" ")
                out.extend(sub)
            elif isinstance(v, list) and v:
                out.append(pad + "-")
                out.append(dumps(v, ind + 2))
            else:
                out.append(pad + "- " + (_fmt(v) if not isinstance(v, (dict, list)) else ("{}" if isinstance(v, dict) else "[]")))
    return "\n".join(x for x in out if x != "")
