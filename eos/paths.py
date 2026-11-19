"""Resolucao de caminhos portaveis.

Cada maquina resolve variaveis localmente. Nada aqui assume letra de unidade nem usuario.

Ordem de resolucao de ${VAR}:
  1. machine.yaml (fora do Git): %USERPROFILE%\\.emmily-os\\machine.yaml  -> vars.<VAR>
  2. variavel de ambiente
  3. padrao embutido (so para as variaveis canonicas que tem padrao seguro)

Variavel sem valor e ERRO: um caminho meio resolvido ("${DATA_ROOT}/x") nunca pode chegar a
uma operacao de arquivo.
"""
import os
import re

from . import yamlite

VAR_RE = re.compile(r"\$\{([A-Z_][A-Z0-9_]*)\}")
CANONICAS = ("AI_WORKSPACE", "PROJECT_ROOT", "GDRIVE_REMOTE", "GDRIVE_ROOT", "DATA_ROOT",
             "OUTPUT_ROOT", "BACKUP_ROOT", "PROG_SHAREPOINT_ROOT", "USERPROFILE", "EOS_STAGING")


class CaminhoNaoResolvido(ValueError):
    pass


def arquivo_da_maquina():
    return os.environ.get("EOS_MACHINE_FILE") or os.path.join(os.path.expanduser("~"), ".emmily-os", "machine.yaml")


def carregar_maquina(caminho=None):
    p = caminho or arquivo_da_maquina()
    if not os.path.isfile(p):
        return {"_arquivo": p, "_existe": False, "vars": {}, "projects": {}}
    d = yamlite.load_file(p) or {}
    d.setdefault("vars", {})
    d.setdefault("projects", {})
    d["_arquivo"], d["_existe"] = p, True
    return d


def padroes():
    home = os.path.expanduser("~")
    return {
        "USERPROFILE": home,
        "AI_WORKSPACE": r"C:\AI-WORKSPACE" if os.name == "nt" else os.path.join(home, "AI-WORKSPACE"),
        "GDRIVE_REMOTE": "gdrive:",
        "GDRIVE_ROOT": "EMMILY PROJECT CLOUD",
        "EOS_STAGING": os.path.join(os.environ.get("LOCALAPPDATA") or os.path.join(home, ".cache"), "emmily-os", "staging"),
    }


def resolver(texto, maquina=None, extras=None):
    maquina = maquina if maquina is not None else carregar_maquina()
    fontes = [extras or {}, maquina.get("vars") or {}, os.environ, padroes()]

    def troca(m):
        nome = m.group(1)
        for f in fontes:
            v = f.get(nome)
            if v not in (None, ""):
                return str(v)
        raise CaminhoNaoResolvido("variavel ${%s} sem valor nesta maquina (defina em %s)" % (nome, maquina.get("_arquivo")))

    anterior, atual = None, texto
    for _ in range(5):  # variavel que aponta para variavel
        if anterior == atual:
            break
        anterior, atual = atual, VAR_RE.sub(troca, atual)
    if VAR_RE.search(atual):
        raise CaminhoNaoResolvido("referencia circular em '%s'" % texto)
    return os.path.normpath(atual) if (":" in atual[:3] or atual.startswith(("/", "\\", "."))) else atual


def caminho_local(contrato, maquina=None):
    """Caminho local do projeto nesta maquina: override por id > workspace.local_path."""
    maquina = maquina if maquina is not None else carregar_maquina()
    pid = contrato["identity"]["id"]
    ov = (maquina.get("projects") or {}).get(pid) or {}
    bruto = ov.get("local_path") or (contrato.get("workspace") or {}).get("local_path")
    if not bruto:
        return None
    return resolver(bruto, maquina)


def hardcodes(texto):
    """Caminhos de maquina embutidos (usuario/letra) - para o check de portabilidade."""
    return re.findall(r"[A-Za-z]:\\\\?Users\\\\?[^\\\"'\s]+|C:/Users/[^/\"'\s]+", texto)


def nome_curto(p):
    """Nome curto 8.3 do Windows (GetShortPathNameW) de uma pasta que existe, ou None. Qualquer
    falha (outro SO, sem ctypes, 8.3 desligado no volume) e silenciosa: so deixa de redigir essa
    grafia (r11, Sec5)."""
    if os.name != "nt" or not p:
        return None
    try:
        import ctypes
        from ctypes import wintypes
        f = ctypes.windll.kernel32.GetShortPathNameW
        f.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, wintypes.DWORD]
        f.restype = wintypes.DWORD
        n = f(p, None, 0)
        if not n:
            return None
        buf = ctypes.create_unicode_buffer(n + 1)
        if not f(p, buf, n + 1):
            return None
        return buf.value or None
    except Exception:
        return None


def _formas_de_pasta(p):
    """Grafias de uma pasta num texto: longa e curta 8.3, com barra e contrabarra, e a forma com
    contrabarra dobrada (escapada em JSON). Da mais longa para a mais curta."""
    formas = set()
    for x in (p, nome_curto(p)):
        x = (x or "").rstrip("\\/")
        if len(x) > 3:
            formas |= {x, x.replace("\\", "/"), x.replace("/", "\\"), x.replace("/", "\\").replace("\\", "\\\\")}
    return sorted(formas, key=len, reverse=True)


def redigir_caminhos(texto, raiz=None):
    """Texto que vai para fora da maquina (manifesto, certificado) sem caminho local: a raiz do
    projeto vira '.', a pasta do usuario vira '~'. Sem distincao de caixa no Windows (o sistema de
    arquivos nao distingue) e cobrindo o nome curto 8.3 (r11, Sec4/Sec5). So troca a grafia
    seguida de separador, fim, ponto final de frase ou caractere que nao continua um nome
    ('C:/Users/Ana' nao redige 'C:/Users/Ana2' nem 'C:/Users/Ana.bak', mas redige 'C:/Users/Ana.'
    no fim de uma frase; r12, Sec2). A pasta temporaria vira '%TEMP%' (r12, Sec3), antes da
    pasta do usuario, que normalmente a contem."""
    if not isinstance(texto, str) or not texto:
        return texto
    pares = []
    if raiz:
        pares.append((os.path.abspath(raiz), "."))
    pares += [(t, "%TEMP%") for t in _pastas_temp()]
    casa = os.path.expanduser("~")
    if casa and casa != "~":
        pares.append((casa, "~"))
    flags = re.IGNORECASE if os.name == "nt" else 0
    for pasta, para in pares:
        for forma in _formas_de_pasta(pasta):
            texto = re.sub(re.escape(forma) + FIM_DE_NOME, lambda _m, s=para: s, texto, flags=flags)
    return texto


# a grafia termina aqui: nao segue letra/digito/_-~$ nem ponto que continua um nome ('.bak')
FIM_DE_NOME = r"(?![A-Za-z0-9_\-~$]|\.[A-Za-z0-9_\-])"


def _pastas_temp():
    """A pasta temporaria (como o processo a ve e resolvida, que pode trocar o nome curto 8.3)."""
    import tempfile  # tardio: so quem redige precisa
    out = []
    try:
        t = tempfile.gettempdir()
        for x in (t, os.path.realpath(t)):
            if x and x not in out:
                out.append(x)
    except OSError:
        pass
    return out


def redigir(obj, raiz=None):
    """redigir_caminhos em qualquer parte de um objeto JSON (dict/list/str), recursivo; copia nova.
    Para certificado/relatorio que vai para a nuvem (r12, Sec3). As CHAVES str de dict tambem sao
    redigidas (r13, S2): um mapa indexado por caminho levaria a maquina na chave.
    Limite: duas chaves que redigem para o mesmo texto colapsam (a ultima vence); nenhum dict do
    certificado e indexado por caminho absoluto hoje."""
    if isinstance(obj, str):
        return redigir_caminhos(obj, raiz)
    if isinstance(obj, dict):
        return {redigir_caminhos(k, raiz) if isinstance(k, str) else k: redigir(v, raiz) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [redigir(v, raiz) for v in obj]
    return obj
