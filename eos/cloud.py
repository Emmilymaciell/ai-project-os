"""Nuvem como servico LOGICO, nao como letra de unidade.

Dois transportes com a mesma interface:
  RcloneStore  - API do Google Drive via rclone (remote configurado, ex. 'gdrive:')
  DirStore     - diretorio montado: o Drive Desktop (descoberto, nunca adivinhado) ou uma
                 pasta qualquer (testes, disco externo)

Toda escrita e seguida de VERIFICACAO de conteudo (hash) contra o local. Upload sem
verificacao nao conta como protecao. Nenhum metodo apaga nada: nao existe delete aqui, de
proposito - limpeza e gate H3, nunca efeito colateral de backup.
"""
import hashlib
import json
import os
import shutil
import subprocess
import tempfile


class NuvemErro(RuntimeError):
    pass


def _md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def _sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


class DirStore:
    """Raiz logica num diretorio local/montado."""

    tipo = "dir"

    def __init__(self, raiz):
        self.raiz = raiz

    def descricao(self):
        return "dir:" + self.raiz

    def _p(self, rel):
        rel = rel.replace("\\", "/")
        if rel.startswith("/") or ":" in rel or ".." in rel.split("/"):
            raise NuvemErro("caminho relativo invalido: %s" % rel)
        rel = rel.strip("/")
        return os.path.join(self.raiz, *rel.split("/"))

    def disponivel(self):
        return os.path.isdir(self.raiz)

    def put(self, local, rel):
        dst = self._p(rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        tmp = dst + ".part"
        shutil.copyfile(local, tmp)
        os.replace(tmp, dst)
        if _sha256(dst) != _sha256(local):
            raise NuvemErro("verificacao falhou apos copia: %s" % rel)
        return {"rel": rel, "bytes": os.path.getsize(dst)}

    def get(self, rel, local):
        os.makedirs(os.path.dirname(local) or ".", exist_ok=True)
        shutil.copyfile(self._p(rel), local)
        return local

    def existe(self, rel):
        return os.path.exists(self._p(rel))

    def listar(self, rel):
        p = self._p(rel)
        if not os.path.isdir(p):
            return []
        return sorted(os.listdir(p))

    def ler_texto(self, rel):
        with open(self._p(rel), "r", encoding="utf-8") as f:
            return f.read()

    def escrever_texto(self, rel, texto):
        dst = self._p(rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        tmp = dst + ".part"
        with open(tmp, "w", encoding="utf-8", newline="\n") as f:
            f.write(texto)
        os.replace(tmp, dst)

    def mkdir(self, rel):
        os.makedirs(self._p(rel), exist_ok=True)

    def inventario(self, rel, recursivo=True):
        """{subcaminho: (bytes, md5)} dos arquivos sob `rel`; vazio se a pasta nao existe."""
        base = self._p(rel)
        out = {}
        if not os.path.isdir(base):
            return out
        for r, _, fs in os.walk(base):
            for f in fs:
                p = os.path.join(r, f)
                out[os.path.relpath(p, base).replace("\\", "/")] = (os.path.getsize(p), _md5(p))
            if not recursivo:
                break
        return out

    def enviar_lote(self, base_local, rels, rel_destino, rel_anteriores=None):
        """Copia ADITIVA de `base_local/<rel>` para `rel_destino/<rel>`. Objeto que ja existe e vai
        ser substituido e antes copiado para `rel_anteriores/<rel>` (nada se perde na nuvem)."""
        for r in rels:
            alvo = _junta(rel_destino, r)
            if rel_anteriores and os.path.isfile(self._p(alvo)):
                ant = self._p(_junta(rel_anteriores, r))
                os.makedirs(os.path.dirname(ant), exist_ok=True)
                shutil.copyfile(self._p(alvo), ant)
            self.put(os.path.join(base_local, *r.split("/")), alvo)

    def baixar_lote(self, rel_origem, rels, base_local):
        for r in rels:
            self.get(_junta(rel_origem, r), os.path.join(base_local, *r.split("/")))


def _junta(*partes):
    return "/".join(p.strip("/") for p in partes if p and p.strip("/"))


def _lista_raw(rels, pasta):
    """Arquivo para --files-from-raw: um caminho por linha, sem comentario nem curinga."""
    lista = os.path.join(pasta, "arquivos.txt")
    with open(lista, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(r + "\n" for r in rels))
    return lista


class RcloneStore:
    """Raiz logica num remote do rclone. Nunca usa `sync` nem `delete`."""

    tipo = "rclone"

    def __init__(self, remote, raiz, exe="rclone"):
        self.remote = remote if remote.endswith(":") else remote + ":"
        self.raiz = raiz.strip("/")
        self.exe = exe

    def descricao(self):
        return "rclone:%s%s" % (self.remote, self.raiz)

    def _alvo(self, rel):
        rel = rel.replace("\\", "/").strip("/")
        if ".." in rel.split("/"):
            raise NuvemErro("caminho relativo invalido: %s" % rel)
        return "%s%s/%s" % (self.remote, self.raiz, rel) if rel else "%s%s" % (self.remote, self.raiz)

    def _run(self, *args, timeout=3600, check=True):
        try:
            r = subprocess.run([self.exe, *args], capture_output=True, timeout=timeout)
        except FileNotFoundError:
            raise NuvemErro("rclone nao encontrado")
        err = r.stderr.decode("utf-8", "replace")
        # O aviso do client_id compartilhado sai em stderr em TODA chamada. Nao e erro, mas e
        # risco registrado (ADR-0013) - quem chama decide; aqui so nao pode virar falha.
        if check and r.returncode != 0:
            linhas = [l for l in err.splitlines() if "client_id" not in l]
            raise NuvemErro("rclone %s: %s" % (args[0], " | ".join(linhas[-3:])))
        return r.returncode, r.stdout.decode("utf-8", "replace"), err

    def disponivel(self):
        rc, _, _ = self._run("about", self.remote, "--json", timeout=60, check=False)
        return rc == 0

    def put(self, local, rel):
        alvo = self._alvo(rel)
        # --immutable: objeto ja existente com conteudo diferente e ERRO, nunca sobrescrita
        self._run("copyto", local, alvo, "--retries", "3", "--immutable")
        md5_remoto = self.md5(rel)
        if md5_remoto != _md5(local):
            raise NuvemErro("verificacao falhou apos upload (md5): %s" % rel)
        return {"rel": rel, "bytes": os.path.getsize(local), "md5": md5_remoto}

    def md5(self, rel):
        alvo = self._alvo(rel)
        pai, nome = alvo.rsplit("/", 1)
        _, out, _ = self._run("lsjson", pai, "--hash", "--hash-type", "md5", "--files-only", timeout=300)
        for item in json.loads(out or "[]"):
            if item.get("Name") == nome:
                return (item.get("Hashes") or {}).get("md5") or (item.get("Hashes") or {}).get("MD5")
        raise NuvemErro("objeto nao encontrado apos upload: %s" % rel)

    def get(self, rel, local):
        os.makedirs(os.path.dirname(local) or ".", exist_ok=True)
        self._run("copyto", self._alvo(rel), local, "--retries", "3")
        return local

    def existe(self, rel):
        alvo = self._alvo(rel)
        pai, nome = alvo.rsplit("/", 1)
        rc, out, _ = self._run("lsf", pai, check=False, timeout=300)
        return rc == 0 and (nome in out.splitlines() or nome + "/" in out.splitlines())

    def listar(self, rel):
        rc, out, _ = self._run("lsf", self._alvo(rel), check=False, timeout=300)
        if rc != 0:
            return []
        return sorted(x.rstrip("/") for x in out.splitlines() if x)

    def ler_texto(self, rel):
        _, out, _ = self._run("cat", self._alvo(rel), timeout=300)
        return out

    def escrever_texto(self, rel, texto):
        import tempfile
        fd, tmp = tempfile.mkstemp(suffix=".txt")
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
                f.write(texto)
            self.put(tmp, rel)
        finally:
            os.remove(tmp)

    def mkdir(self, rel):
        self._run("mkdir", self._alvo(rel))

    def inventario(self, rel, recursivo=True):
        """{subcaminho: (bytes, md5)} numa chamada so (o Drive guarda o md5: nada e baixado)."""
        rc, out, err = self._run("lsjson", self._alvo(rel), "--hash", "--hash-type", "md5", "--files-only",
                                 *(["-R"] if recursivo else []), timeout=3600, check=False)
        if rc == 3:  # rclone: directory not found
            return {}
        if rc != 0:
            linhas = [l for l in err.splitlines() if "client_id" not in l]
            raise NuvemErro("rclone lsjson: %s" % " | ".join(linhas[-3:]))

        def md5(i):
            h = i.get("Hashes") or {}
            return (h.get("md5") or h.get("MD5") or "").lower() or None
        return {i["Path"]: (i.get("Size"), md5(i)) for i in json.loads(out or "[]")}

    def enviar_lote(self, base_local, rels, rel_destino, rel_anteriores=None):
        """`rclone copy` (nunca sync): so a lista dada, comparada por tamanho+md5; o objeto que vai
        ser substituido e levado antes para --backup-dir (movido no servidor, nunca apagado)."""
        if not rels:
            return
        with tempfile.TemporaryDirectory(prefix="eos-rc-", ignore_cleanup_errors=True) as d:
            args = ["copy", base_local, self._alvo(rel_destino), "--files-from-raw", _lista_raw(rels, d),
                    "--checksum", "--retries", "3"]
            if rel_anteriores:
                args += ["--backup-dir", self._alvo(rel_anteriores)]
            self._run(*args, timeout=24 * 3600)

    def baixar_lote(self, rel_origem, rels, base_local):
        if not rels:
            return
        os.makedirs(base_local, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="eos-rc-", ignore_cleanup_errors=True) as d:
            self._run("copy", self._alvo(rel_origem), base_local, "--files-from-raw", _lista_raw(rels, d),
                      "--checksum", "--retries", "3", timeout=24 * 3600)


def descobrir_drive_desktop():
    """Raiz 'Meu Drive'/'My Drive' do Drive Desktop, procurada nas unidades - nunca suposta."""
    if os.name != "nt":
        return None
    import string
    for letra in string.ascii_uppercase:
        for nome in ("Meu Drive", "My Drive"):
            p = "%s:\\%s" % (letra, nome)
            if os.path.isdir(p):
                return p
    return None


def store_da_maquina(maquina):
    """Transporte declarado na maquina; padrao = rclone 'gdrive:' na raiz logica."""
    from .paths import resolver
    cfg = (maquina.get("cloud") or {})
    transporte = cfg.get("transport", "rclone")
    raiz = resolver("${GDRIVE_ROOT}", maquina)
    if transporte == "rclone":
        return RcloneStore(resolver("${GDRIVE_REMOTE}", maquina), raiz)
    if transporte == "drive-desktop":
        base = cfg.get("mount") or descobrir_drive_desktop()
        if not base:
            raise NuvemErro("Drive Desktop nao encontrado em nenhuma unidade")
        return DirStore(os.path.join(base, raiz))
    if transporte == "dir":
        return DirStore(resolver(cfg["path"], maquina))
    raise NuvemErro("transporte desconhecido: %s" % transporte)
