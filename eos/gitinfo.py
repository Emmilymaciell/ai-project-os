"""Fatos de Git, colhidos SEM escrever no repositorio.

GIT_OPTIONAL_LOCKS=0 impede o `status` de regravar o index; nada de fetch (escreve refs), nada
de stash (escreve objeto e ref). A verdade do remoto vem de `ls-remote`, que le sem escrever.

Toda funcao devolve fato ou levanta GitErro - nunca devolve "vazio" quando nao conseguiu ler,
porque vazio aqui significaria "nada a proteger", que e exatamente o falso verde que esta
plataforma existe para impedir.
"""
import hashlib
import os
import re
import subprocess

ENV_EXTRA = {"GIT_OPTIONAL_LOCKS": "0", "GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C"}


class GitErro(RuntimeError):
    pass


def remover_arvore(path):
    """Remove uma arvore CRIADA PELO MOTOR (temp de restore/certificacao/staging). Trata os
    objetos somente-leitura do .git no Windows, que fazem shutil.rmtree falhar em silencio com
    ignore_errors. Devolve True se o caminho deixou de existir - fato medido, nao suposto."""
    import shutil
    import stat

    def _forca(func, p, _exc):
        try:
            os.chmod(p, stat.S_IWRITE)
            func(p)
        except OSError:
            pass
    if os.path.exists(path):
        shutil.rmtree(path, onexc=_forca)
    return not os.path.exists(path)


# Configuracao que o motor FIXA em toda chamada: a da usuaria (diff.noprefix, color.diff=always,
# diff.external...) deixaria o patch inaplicavel ou mudaria o que se mede (pre-revisao r3, achado 7).
FIXOS = ["-c", "core.fsmonitor=false", "-c", "core.quotepath=false", "-c", "color.ui=false", "-c", "color.diff=false",
         "-c", "diff.noprefix=false", "-c", "diff.mnemonicPrefix=false", "-c", "diff.relative=false"]
# diff externo (diff.external, atributo diff=...) e desligado por OPCAO, nao por config vazia: medido
# que '-c diff.external=' faz o git tentar executar um programa sem nome


def _ambiente():
    """Ambiente sem NENHUMA variavel GIT_* herdada: GIT_DIR/GIT_WORK_TREE fariam o motor medir
    outro repositorio, GIT_LITERAL_PATHSPECS desarmaria a exclusao de segredo do patch
    (pre-revisao r3, achado 8)."""
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith("GIT_")}
    env.update(ENV_EXTRA)
    return env


def git(repo, *args, check=True, binario=False, timeout=600):
    env = _ambiente()
    try:
        if args and args[0] == "diff":
            args = ("diff", "--no-ext-diff", "--no-color", "--no-textconv") + tuple(args[1:])
        r = subprocess.run(["git", *FIXOS, "-C", repo, *args],
                           capture_output=True, env=env, timeout=timeout)
    except subprocess.TimeoutExpired:
        # tempo esgotado e "nao consegui ler", nunca resposta (r2 do QA, achado 8)
        raise GitErro("git %s (em %s): tempo esgotado em %ds" % (" ".join(args[:3]), repo, timeout))
    if check and r.returncode != 0:
        raise GitErro("git %s (em %s): %s" % (" ".join(args), repo, r.stderr.decode("utf-8", "replace").strip()))
    if binario:
        return r.stdout
    return r.stdout.decode("utf-8", "replace") if check else (r.returncode, r.stdout.decode("utf-8", "replace"))


def eh_repo(path):
    if not os.path.isdir(path):
        return False
    rc, _ = git(path, "rev-parse", "--git-dir", check=False)
    return rc == 0


def tem_commit(path):
    rc, _ = git(path, "rev-parse", "--verify", "--quiet", "HEAD^{commit}", check=False)
    return rc == 0


def refs(path):
    """{refname: sha} de todas as refs locais (heads, tags, remotes, notes, stash...)."""
    out = git(path, "for-each-ref", "--format=%(objectname) %(refname)")
    d = {}
    for linha in out.splitlines():
        sha, _, nome = linha.partition(" ")
        if nome:
            d[nome] = sha
    return d


def refs_do_projeto(todas):
    """As refs que sao TRABALHO do projeto: tudo menos refs/remotes/* (copia do remoto) e
    refs/stash (o motor nao protege stash e o declara). Inclui notes e refs proprias."""
    return {k: v for k, v in todas.items() if not k.startswith("refs/remotes/") and k != "refs/stash"}


def remotos(path):
    """{nome: url de fetch}. A verdade completa e `remotos_completos`."""
    return {n: v["fetch"][0] for n, v in remotos_completos(path).items() if v["fetch"]}


def remotos_completos(path):
    """{nome: {"fetch": [urls], "push": [urls]}} - TODAS as URLs, inclusive pushurl adicionais."""
    out = git(path, "remote", "-v")
    d = {}
    # "<nome>\t<url> (fetch|push)"; a URL pode ter espaco (perfil Windows desta maquina tem)
    for linha in out.splitlines():
        nome, sep, resto = linha.partition("\t")
        url, _, tipo = resto.rpartition(" ")
        if sep and url and tipo in ("(fetch)", "(push)"):
            d.setdefault(nome, {"fetch": [], "push": []})["push" if tipo == "(push)" else "fetch"].append(url)
    return d


def stash(path):
    """Entradas do stash. Stash NAO e protegido pelo motor: fica fora do bundle (pode carregar
    segredo de arquivo nao rastreado) e o restore nao o recria. Existir stash e bloqueio nomeado.

    Falha de leitura levanta (r2 do QA, achado 5). refs/stash sem reflog conta como 1 entrada."""
    rc, out = git(path, "stash", "list", check=False)
    if rc != 0:
        raise GitErro("nao consegui listar o stash em %s" % path)
    entradas = [l for l in out.splitlines() if l.strip()]
    if not entradas and "refs/stash" in refs(path):
        entradas = ["refs/stash sem reflog"]
    return entradas


def ls_remote(path, remoto="origin", timeout=120):
    """{refname: sha} do remoto. Levanta GitErro sem rede/sem acesso - nunca devolve {}."""
    out = git(path, "ls-remote", remoto, timeout=timeout)
    d = {}
    for linha in out.splitlines():
        sha, _, nome = linha.partition("\t")
        if nome and not nome.endswith("^{}") and nome != "HEAD":
            d[nome] = sha
    return d


def eh_ancestral(path, a, b):
    rc, _ = git(path, "merge-base", "--is-ancestor", a, b, check=False)
    return rc == 0


def objeto_existe(path, sha):
    rc, _ = git(path, "cat-file", "-e", sha + "^{commit}", check=False)
    return rc == 0


PRESERVADO = "refs/preservado/"


def nao_publicados(path, refs_remotas):
    """Refs do projeto que o remoto nao tem.

    - branch: publicada se a homonima remota e igual ou descende dela;
    - tag: publicada se a homonima remota e igual;
    - qualquer outra ref do projeto (notes, refs proprias): publicada so se igual no remoto
      (r2 do QA, achado 6: antes nem era olhada).
    Branch sem homonima no remoto conta como nao publicada: a ref se perderia num clone.

    Excecao deliberada: `refs/preservado/*` (PRESERVADO). E a convencao para ref que protege
    conteudo que NAO pode ir ao remoto (ex.: stash orfao anterior a uma sanitizacao de historico).
    Ela nunca e publicada; a protecao dela e o bundle do backup na nuvem (`bundle --all`), e a
    dimensao `backup` continua exigindo que o bundle a contenha (refs iguais ao manifesto).
    """
    faltam = []
    for nome, sha in refs_do_projeto(refs(path)).items():
        if nome.startswith(PRESERVADO):
            continue
        rsha = refs_remotas.get(nome)
        if rsha == sha:
            continue
        if nome.startswith("refs/heads/") and rsha and objeto_existe(path, rsha) and eh_ancestral(path, sha, rsha):
            continue
        faltam.append(nome)
    return sorted(faltam)


def worktrees(path):
    out, wts, cur = git(path, "worktree", "list", "--porcelain"), [], {}
    for linha in out.splitlines() + [""]:
        if not linha.strip():
            if cur:
                wts.append(cur)
                cur = {}
            continue
        k, _, v = linha.partition(" ")
        cur[k] = v if v else True
    for w in wts:
        w["worktree"] = w["worktree"].replace("/", os.sep)
    return wts


EXCLUIR_SEMPRE = {".venv", "venv", "node_modules", "__pycache__", ".pytest_cache", ".mypy_cache", ".git"}

# LISTA UNICA de nome de segredo, usada pelo WIP, pelo L4 e pelo check (r2 do security, achado 3).
# Olha so o NOME DO ARQUIVO (nao as pastas): 'Secretaria/' (orgao publico) nao vira segredo, e
# uma pasta larga nao retem tudo o que tem dentro.
#
# Duas familias. A DURA (.env, chaves, certificados, cofres de navegador) nunca tem excecao. A da
# PALAVRA (secrets, token, credentials...) tambem conta em codigo e documentacao, porque o nome nao
# diz se o arquivo e o cofre ou o teste do verificador (r4 do QA, achado 2: a regra "so a palavra
# exata" deixava subir .env.ps1 e secrets_prod.py). Falso positivo sai por CAMINHO EXATO declarado
# no contrato (secrets.allowed_paths), nunca por heuristica.
NOME_DURO = re.compile(
    r"^(\.env(\..+)?|\.envrc|id_(rsa|dsa|ecdsa|ed25519)(\.pub)?|\.netrc|\.pgpass|\.npmrc|\.pypirc|"
    r"rclone\.conf|login data|web data|cookies|local state|logins\.json|key[34]\.db|"
    r".*\.(pem|key|pfx|p12|ppk|jks|keystore|kdbx|ovpn))$",
    re.IGNORECASE)
NOME_PALAVRA = re.compile(
    r"^(.*[^a-z])?(secrets?|tokens?|credentials?|senhas?|passwords?|passwd|api[_-]?keys?|apikeys?|cookies?)([^a-z].*)?$",
    re.IGNORECASE)
# Excecoes por NOME exato: modelos de .env e manifestos que, por contrato, so tem nomes.
EXEMPLO_OK = re.compile(r"^(\.env\.(example|sample|template)|secrets\.manifest|cofre\.manifest)$", re.IGNORECASE)


def _norm(rel):
    return rel.replace("\\", "/")


def _em(rel, prefixos):
    r = _norm(rel).rstrip("/")
    return any(r == e.rstrip("/") or r.startswith(e.rstrip("/") + "/") for e in prefixos)


def _reconstruivel(rel):
    return any(p in EXCLUIR_SEMPRE for p in _norm(rel).rstrip("/").split("/"))


def permitivel(rel):
    """Erro (texto) se `rel` NAO pode entrar em secrets.allowed_paths, ou None. So entra caminho
    relativo, exato (sem curinga), cujo nome e da familia da PALAVRA: .env e chave nunca."""
    r = _norm(rel) if isinstance(rel, str) else ""
    partes = r.split("/")
    if not r or r.startswith("/") or re.match(r"^[A-Za-z]:", r) or any(p in ("", ".", "..") for p in partes):
        return "caminho relativo exato, sem '..' (%r)" % rel
    if any(ch in r for ch in "*?[]"):
        return "curinga nao vale: declare cada arquivo (%r)" % rel
    if NOME_DURO.match(partes[-1]):
        return "%r e .env/chave/cofre: esse nome nunca tem excecao" % rel
    if not NOME_PALAVRA.match(partes[-1]):
        return "%r nao tem nome de segredo: a excecao e desnecessaria" % rel
    return None


def nome_de_segredo(rel, permitidos=()):
    """True se o NOME do arquivo e de segredo. `permitidos`: caminhos exatos de
    secrets.allowed_paths (documentacao/teste sobre segredo), que so isentam a familia da PALAVRA."""
    r = _norm(rel).rstrip("/")
    base = r.split("/")[-1]
    if EXEMPLO_OK.match(base):
        return False
    if NOME_DURO.match(base):
        return True
    if not NOME_PALAVRA.match(base):
        return False
    return r not in {_norm(p) for p in permitidos}


def segredos_no_historico(path, permitidos=()):
    """Caminhos com nome de segredo que existem em QUALQUER commit alcancavel. O bundle leva o
    historico inteiro: segredo commitado sobe, e isso precisa virar pendencia e reprovar o L4
    (pre-revisao r3, achado 3). Sanitizar historico e decisao humana (ADR-0015).
    `-m`: sem ele o log nao mostra o diff de commit de merge, e um .env que entrou e saiu so em
    resolucao de merge ficava invisivel. refs/stash fica de fora porque o bundle o exclui
    (r4 do QA, achado 3)."""
    out = git(path, "log", "--exclude=refs/stash", "--all", "-m", "--format=", "--name-only", "--no-renames", timeout=900)
    return sorted({c for c in out.splitlines() if c.strip() and nome_de_segredo(c, permitidos)})


def _escondidos_do_status(path):
    """Arquivos rastreados com --skip-worktree ou --assume-unchanged cujo CONTEUDO difere do
    index. O `status` nao os mostra; sem isto a edicao some sem aviso (r2 do QA, achado 2)."""
    out = git(path, "ls-files", "-v", "-s")
    # formato -v -s: "<tag> <modo> <sha> <estagio>\t<caminho>"; tag minuscula = assume-unchanged,
    # 'S' = skip-worktree
    candidatos = []
    for linha in out.splitlines():
        cab, _, cam = linha.partition("\t")
        partes = cab.split()
        if len(partes) == 4 and (partes[0] == "S" or partes[0].islower()):
            candidatos.append((cam, partes[2]))
    mudados = []
    for cam, sha_index in candidatos:
        p = os.path.join(path, cam)
        if os.path.isfile(p) and git(path, "hash-object", "--", cam).strip() != sha_index:
            mudados.append(cam)
    return mudados


def gitlinks(path):
    """Submodulos/repositorios embutidos ja commitados (modo 160000). Os commits deles NAO vao
    no bundle do pai; mesmo limpos, apagar a pasta os leva (r2 do QA, achado 1)."""
    return [l.split("\t", 1)[1] for l in git(path, "ls-files", "-s").splitlines()
            if l.startswith("160000 ") and "\t" in l]


def wip(path, excluir=None, worktrees_internas=(), permitidos=()):
    """Trabalho nao protegido pelo historico.

    Listas:
      modificados / removidos / nao_rastreados   - o WIP normal
      escondidos      - skip-worktree/assume-unchanged com conteudo diferente do index (entram
                        em `modificados` tambem: sao trabalho)
      excluidos       - reconstruiveis (.venv, node_modules...)
      excluidos_contrato - excluidos por backup.exclude: NAO sobem, e por isso o check os trata
                        como "so nesta pasta" (r2 do QA, achado 3)
      aninhados       - repositorio aninhado/submodulo sujo (aparece como pasta)
      symlinks        - o restore recusa link
      segredos        - nome de segredo entre modificados/nao rastreados: nao sobe (`permitidos`:
                        secrets.allowed_paths do contrato)
      intencao        - intent-to-add (`git add -N`, status ' A'): tambem em `modificados`, mas o
                        restore precisa refazer o -N, senao o arquivo volta como '??' e a
                        impressao diverge (certificacao do G2, 2026-10-11)
    `worktrees_internas`: worktrees deste mesmo repositorio que moram dentro da pasta - sao
    protegidas como worktree, nao viram 'aninhado' (r2 do QA, achado 8).
    """
    # --no-renames: desde o Git 2.18 o intent-to-add de um arquivo movido sai como ' R novo<NUL>velho'
    # (renomeacao NA ARVORE, coluna Y), e o par seria lido como duas linhas (r6 do QA, achado 1).
    # Sem deteccao de renomeacao, o mesmo caso vira ' A novo' (intencao) + ' D velho' (removidos).
    st = git(path, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--no-renames")
    modificados, removidos, nao_rastreados, excluidos, excl_contrato, aninhados, symlinks = [], [], [], [], [], [], []
    intencao = []
    internas = [os.path.normcase(os.path.abspath(w)) for w in worktrees_internas]
    ents, i = st.split("\0"), 0
    while i < len(ents):
        e = ents[i]
        if not e:
            i += 1
            continue
        xy, rel = e[:2], e[3:]
        if xy[0] in "RC" or xy[1] in "RC":
            i += 1  # defensivo: com --no-renames nao ha par origem/destino
        p = os.path.join(path, rel)
        if xy == "??" and _reconstruivel(rel):
            excluidos.append(rel)
        elif _em(rel, excluir or ()):
            # vale para rastreado tambem: o que o contrato exclui nao sobe nem inteiro nem no patch
            excl_contrato.append(rel)
        elif "D" in xy and not os.path.lexists(p):
            removidos.append(rel)
        elif os.path.islink(p):
            symlinks.append(rel)
        elif rel.endswith("/") or os.path.isdir(p):
            if os.path.normcase(os.path.abspath(p.rstrip("/\\"))) not in internas:
                aninhados.append(rel.rstrip("/"))
        elif xy == "??":
            nao_rastreados.append(rel)
        else:
            modificados.append(rel)
            if xy == " A":
                intencao.append(rel)
        i += 1
    escondidos = _escondidos_do_status(path) if tem_commit(path) else []
    modificados = sorted(set(modificados) | set(escondidos))
    # removidos tambem: um .env staged e depois apagado do disco ('AD') ainda esta no index e
    # subiria no staged.patch (pre-revisao r3, achado 2)
    segredos = sorted({r for r in modificados + nao_rastreados + removidos if nome_de_segredo(r, permitidos)})
    return {"status": st.replace("\0", "\n"), "modificados": modificados, "removidos": sorted(removidos),
            "nao_rastreados": sorted(nao_rastreados), "excluidos": sorted(excluidos),
            "excluidos_contrato": sorted(excl_contrato), "escondidos": sorted(escondidos),
            "aninhados": sorted(aninhados), "symlinks": sorted(symlinks), "segredos": sorted(segredos),
            "intencao": sorted(intencao)}


def ignorados_nao_declarados(path, declarados):
    """Arquivos IGNORADOS que existem so nesta pasta e que o contrato nao declara."""
    # 'traditional' + '-uall' lista ARQUIVO por arquivo dentro de pasta ignorada (medido: 'matching'
    # devolve so 'data/'). As pastas reconstruiveis saem ja na pathspec.
    exc = [":(exclude,glob)**/%s/**" % d for d in sorted(EXCLUIR_SEMPRE) if d != ".git"]
    rc, out = git(path, "status", "--porcelain=v1", "--ignored=traditional", "--untracked-files=all", "--", ".", *exc, check=False)
    if rc != 0:
        raise GitErro("status --ignored falhou em %s" % path)
    achados = []
    for linha in out.splitlines():
        if not linha.startswith("!! "):
            continue
        rel = linha[3:].strip().strip('"')
        if not _reconstruivel(rel) and not _em(rel, declarados):
            achados.append(rel)
    return achados


def sha256_arquivo(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def impressao_wip(path, w=None, excluir=None):
    """Impressao digital do WIP: muda se e so se o trabalho nao commitado mudar.

    Cobre conteudo de modificados (inclusive escondidos) e nao rastreados, removidos, o diff
    staged, e os itens nao protegiveis pelo nome, para que nunca passem como "igual ao snapshot".
    """
    w = w or wip(path, excluir)
    h = hashlib.sha256()
    for rel in w["modificados"] + w["nao_rastreados"]:
        p = os.path.join(path, rel)
        h.update(_norm(rel).encode("utf-8") + b"\0")
        if not os.path.isfile(p):
            raise GitErro("arquivo do WIP sumiu durante a leitura: %s" % rel)
        h.update(sha256_arquivo(p).encode() + b"\n")
    # intencao: um intent-to-add que volta como '??' tem o mesmo conteudo e a mesma lista
    # concatenada; sem isto a impressao so mudava por acaso de ordem (r6 do QA, achado 2)
    for rotulo in ("removidos", "aninhados", "symlinks", "intencao"):
        for rel in w.get(rotulo, []):
            h.update(rotulo.encode() + b"\0" + _norm(rel).encode("utf-8") + b"\n")
    if tem_commit(path):
        h.update(hashlib.sha256(git(path, "diff", "--cached", "--binary", binario=True)).hexdigest().encode())
    return h.hexdigest()


def resumo(path, excluir=None, permitidos=()):
    """Fatos de Git de um projeto inteiro (arvore principal + worktrees)."""
    f = {"caminho": path, "existe": os.path.isdir(path), "repo": False}
    if not f["existe"] or not eh_repo(path):
        return f
    f["repo"] = True
    f["tem_commit"] = tem_commit(path)
    f["branch"] = git(path, "symbolic-ref", "-q", "--short", "HEAD", check=False)[1].strip()
    f["head"] = git(path, "rev-parse", "HEAD").strip() if f["tem_commit"] else None
    f["refs"] = refs(path)
    f["remotos"] = remotos(path)
    f["remotos_completos"] = remotos_completos(path)
    f["stash"] = stash(path) if f["tem_commit"] else []
    f["gitlinks"] = gitlinks(path) if f["tem_commit"] else []
    f["worktrees"] = []
    lista = worktrees(path) if f["tem_commit"] else [{"worktree": path, "HEAD": None, "branch": f["branch"]}]
    caminhos = [wt["worktree"] for wt in lista]
    for idx, wt in enumerate(lista):
        p = wt["worktree"]
        info = {"caminho": p, "principal": idx == 0, "head": wt.get("HEAD"), "branch": wt.get("branch"),
                "locked": wt.get("locked"), "existe": os.path.isdir(p)}
        if info["existe"]:
            w = wip(p, excluir, worktrees_internas=[c for c in caminhos if c != p], permitidos=permitidos)
            info["modificados"] = len(w["modificados"])
            info["removidos"] = len(w["removidos"])
            info["nao_rastreados"] = len(w["nao_rastreados"])
            info["nao_protegiveis"] = (["aninhado: " + x for x in w["aninhados"]] +
                                       ["symlink: " + x for x in w["symlinks"]])
            info["segredos"] = w["segredos"]
            info["excluidos_contrato"] = w["excluidos_contrato"]
            info["sujo"] = bool(w["modificados"] or w["removidos"] or w["nao_rastreados"] or
                                w["aninhados"] or w["symlinks"])
            info["impressao_wip"] = impressao_wip(p, w, excluir) if info["sujo"] else None
        f["worktrees"].append(info)
    return f
