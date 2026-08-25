#!/usr/bin/env python3
"""Extractor de Site E de Tora: wp-json + HTML servido -> _spec/pages.jsonl

POR QUE ASI, y no con regex:
  Hoy he roto tres barridos con grep sobre HTML. `<p[^>]*>` casa con `<path`,
  `[^"]` se corta en la primera comilla escapada del JSON, y `per_page=100` sin
  paginar entrego 100 de 129 sin dar error. Un parser de verdad no tiene ninguno
  de esos tres fallos.

DE DONDE SALE CADA COSA:
  contenido, fechas, ids  -> origen/api/{pages,posts}.json   (wp-json)
  meta title/description  -> origen/paginas/<slug>.html      (Yoast NO expone
                             yoast_head_json en esta instalacion: comprobado,
                             0 de 21 y 0 de 12)
  alt de imagenes         -> origen/api/media.json           (129 registros)

EL EXTRACTOR NO ARREGLA, COPIA. Si el origen trae basura (invisibles, titulos
duplicados), sale tal cual y se anota. Las correcciones van a
_spec/site.json -> overrides, con su campo `why`, porque este fichero SE
REGENERA y cualquier arreglo escrito aqui se pierde.
"""
import json
import re
import sys
import unicodedata
from html.parser import HTMLParser
from pathlib import Path
from collections import Counter

RAIZ = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
API = RAIZ / "origen" / "api"
HTML = RAIZ / "origen" / "paginas"
SALIDA = RAIZ.parent / "_spec"
DOMINIO = "https://site-e.example"

# Tags cuyo contenido NO es texto de la pagina
IGNORAR_SUBARBOL = {"script", "style", "svg", "noscript"}
# Tags que producen un bloque de texto
TEXTO = {"h1", "h2", "h3", "h4", "h5", "h6", "p", "li", "blockquote", "cite", "summary"}
INVISIBLES = re.compile("[​-‍﻿­]")


def limpia(s):
    s = s.replace("\xa0", " ")
    s = unicodedata.normalize("NFC", s)
    return re.sub(r"\s+", " ", s).strip()


VACIOS = {"br", "img", "hr", "input", "meta", "link", "source", "area", "col"}

# Elementos EN LINEA: no crean bloque, su texto pertenece al padre.
# Sin esto, <li><strong>Los Enamorados</strong>: indica una eleccion...</li> se
# partia en dos y la lista salia con items que empiezan por dos puntos.
# La regla es la de HTML: bloque crea bloque, en linea es transparente.
INLINE = {"a", "span", "strong", "b", "em", "i", "u", "s", "mark", "small",
          "sub", "sup", "code", "abbr", "time", "label", "font", "q", "wbr"}


class Lector(HTMLParser):
    """Recorre el HTML y emite bloques EN ORDEN de documento.

    🔴 SIN LISTA BLANCA DE ETIQUETAS. La primera version solo miraba
    p/li/h1-h6/blockquote/cite/summary, y Elementor mete muchisimo texto suelto
    dentro de <div>: se perdio el 32% del contenido del sitio, y las 6 paginas
    que reciben los anuncios se quedaron al 25-31%. No fallo nada — el gate de
    fidelidad comparaba los bloques ya extraidos contra nuestra pagina, o sea,
    la extraccion contra si misma.

    Modelo nuevo: cada elemento abierto tiene su propio bufer y solo recoge SUS
    nodos de texto DIRECTOS. Al cerrarlo, o al abrirse un hijo, se vuelca. Asi
    se captura el texto de cualquier etiqueta y nunca se duplica: cada nodo de
    texto pertenece a un unico padre.
    """

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.bloques = []
        self.pila = []          # [{tag, buf}]
        self.saltando = 0
        self.en_details = 0
        self.en_summary = 0
        self.en_cite = 0

    # -- volcado -------------------------------------------------------------
    def _volcar(self, tag, buf):
        txt = limpia("".join(buf))
        if not txt or len(txt) < 2:
            return
        # ⚠️ Se mira el ANCESTRO, no solo la etiqueta propia. Elementor envuelve
        # el contenido de <summary> y <cite> en un <span>: el texto directo de
        # summary esta vacio y sin esto los 61 testimonios y las 31 preguntas
        # salian clasificados como parrafos. El control lo canto: 0 de 61.
        if tag == "summary" or self.en_summary:
            self.bloques.append({"t": "faq_q", "x": txt})
            return
        if tag == "cite" or self.en_cite:
            self.bloques.append({"t": "cite", "x": txt})
            return
        if self.en_details:
            self.bloques.append({"t": "faq_a", "x": txt,
                                 "origen": tag if tag in ("li", "blockquote") else "p"})
            return
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote"):
            self.bloques.append({"t": tag, "x": txt})
        else:
            # div, span, strong, td, figcaption... todo lo demas es un parrafo
            self.bloques.append({"t": "p", "x": txt})

    def _flush_actual(self):
        """Vuelca el texto directo pendiente del elemento abierto, para que salga
        ANTES que su hijo y se conserve el orden del documento."""
        if self.pila and self.pila[-1]["buf"]:
            self._volcar(self.pila[-1]["tag"], self.pila[-1]["buf"])
            self.pila[-1]["buf"] = []

    # -- eventos -------------------------------------------------------------
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if self.saltando:
            if tag in IGNORAR_SUBARBOL:
                self.saltando += 1
            return
        if tag in IGNORAR_SUBARBOL:
            self.saltando = 1
            return
        if tag == "br":
            # Un <br> separa dos frases. Sin esto se pegan: salia
            # "...especializada en amor.Resuelve tus dudas...".
            if self.pila:
                self.pila[-1]["buf"].append(" ")
            return
        if tag == "img":
            self._flush_actual()
            src = a.get("src") or a.get("data-src") or ""
            if not src.startswith("data:"):
                self.bloques.append({
                    "t": "img", "src": src, "alt": limpia(a.get("alt", "")),
                    "w": a.get("width"), "h": a.get("height"),
                    "loading": a.get("loading"),
                })
            return
        if tag in VACIOS:
            return
        # Dentro de <cite> o <summary> los hijos son TRANSPARENTES: su texto se
        # acumula en el ancestro y sale como una sola pieza. Sin esto, un
        # <cite><span>Carla S.</span><span>Valencia</span></cite> emitia DOS
        # testimonios y el control daba 104 sobre 61. Una firma es una unidad.
        if (self.en_cite or self.en_summary) and tag not in ("cite", "summary"):
            return
        if tag in INLINE:
            return            # transparente: el texto se queda en el padre
        self._flush_actual()
        if tag == "details":
            self.en_details += 1
        elif tag == "summary":
            self.en_summary += 1
        elif tag == "cite":
            self.en_cite += 1
        self.pila.append({"tag": tag, "buf": []})

    def handle_endtag(self, tag):
        if self.saltando:
            if tag in IGNORAR_SUBARBOL:
                self.saltando -= 1
            return
        if tag in VACIOS:
            return
        # el cierre de un hijo transparente dentro de cite/summary no cierra nada
        if (self.en_cite or self.en_summary) and tag not in ("cite", "summary"):
            return
        if tag in INLINE:
            return
        # cerrar hasta el tag correspondiente (HTML mal formado incluido)
        while self.pila:
            el = self.pila.pop()
            if el["buf"]:
                self._volcar(el["tag"], el["buf"])
            if el["tag"] == "details" and self.en_details:
                self.en_details -= 1
            elif el["tag"] == "summary" and self.en_summary:
                self.en_summary -= 1
            elif el["tag"] == "cite" and self.en_cite:
                self.en_cite -= 1
            if el["tag"] == tag:
                break

    def handle_data(self, data):
        if self.saltando or not self.pila:
            return
        self.pila[-1]["buf"].append(data)

    def close(self):
        super().close()
        while self.pila:
            el = self.pila.pop()
            if el["buf"]:
                self._volcar(el["tag"], el["buf"])


def bloques_de(html):
    p = Lector()
    p.feed(html or "")
    p.close()
    return p.bloques


def rendered(item, campo):
    v = item.get(campo)
    return (v or {}).get("rendered", "") if isinstance(v, dict) else (v or "")


def meta_de_html(slug):
    """Yoast no esta en la API: los meta se leen del HTML que sirve el sitio."""
    f = HTML / f"{slug}.html"
    if not f.exists():
        return {}
    h = f.read_text(encoding="utf-8", errors="replace")
    def uno(pat):
        m = re.search(pat, h, re.I)
        return limpia(m.group(1)) if m else ""
    return {
        "title": uno(r"<title>(.*?)</title>"),
        "description": uno(r'<meta name="description" content="([^"]*)"'),
        "canonical": uno(r'<link rel="canonical" href="([^"]*)"'),
        "robots": uno(r'<meta name="robots" content="([^"]*)"'),
        "og_image": uno(r'<meta property="og:image" content="([^"]*)"'),
        "og_title": uno(r'<meta property="og:title" content="([^"]*)"'),
    }


# --------------------------------------------------------------------------
def main():
    for n in ("pages", "posts", "media"):
        if not (API / f"{n}.json").exists():
            sys.exit(f"falta {API/f'{n}.json'}")

    media = json.loads((API / "media.json").read_text(encoding="utf-8"))
    alt_por_url = {}
    for m in media:
        u = m.get("source_url", "")
        if u:
            alt_por_url[u] = limpia(m.get("alt_text") or "")

    # El sitemap manda sobre que URLs son publicas
    sm = RAIZ / "origen" / "api" / "urls.txt"
    publicas = set()
    if sm.exists():
        publicas = {l.strip().rstrip("/") for l in sm.read_text().splitlines() if l.strip()}

    registros = []
    contadores = Counter()

    for tipo, fichero in (("page", "pages"), ("post", "posts")):
        datos = json.loads((API / f"{fichero}.json").read_text(encoding="utf-8"))
        contadores[f"{fichero}_origen"] = len(datos)
        for it in datos:
            slug = it.get("slug", "")
            url = it.get("link", "").rstrip("/")
            if slug == "inicio" or url == DOMINIO:
                slug, url = "home", DOMINIO
            contenido = rendered(it, "content")
            bl = bloques_de(contenido)

            imgs, faq, quotes, textos = [], [], [], []
            q = None
            for b in bl:
                if b["t"] == "img":
                    b["alt_biblioteca"] = alt_por_url.get(b["src"], "")
                    imgs.append(b)
                    # Y TAMBIEN al flujo: si la imagen solo va a la lista aparte,
                    # se pierde DONDE estaba. La primera version hacia eso y las
                    # paginas salieron sin una sola imagen - no fallo nada, el
                    # generador simplemente no tenia donde ponerlas.
                    textos.append(b)
                elif b["t"] == "faq_q":
                    q = {"q": b["x"], "a": []}
                    faq.append(q)
                elif b["t"] == "faq_a" and q:
                    # Toda pieza de texto dentro del <details> es la respuesta,
                    # sea parrafo o punto de lista. Se conserva de que era.
                    q["a"].append({"t": b.get("origen", "p"), "x": b["x"]})
                elif b["t"] == "cite":
                    quotes.append(b["x"])
                    # Y al flujo, igual que las imagenes: un <cite> es la FIRMA
                    # de un testimonio y va pegado a su cita. Sacarlo solo a la
                    # lista perdia 43 de los 61 - incluidos los 9 de cada pagina
                    # de ciudad, que son las que reciben los anuncios.
                    textos.append(b)
                else:
                    textos.append(b)

            meta = meta_de_html(slug if slug != "home" else "home")
            palabras = sum(len(b["x"].split()) for b in textos if b.get("x"))
            invis = len(INVISIBLES.findall(contenido))

            registros.append({
                "slug": slug,
                "url": url,
                "tipo": tipo,
                "en_sitemap": url in publicas,
                "wp_id": it.get("id"),
                "titulo_wp": limpia(rendered(it, "title")),
                "fecha": it.get("date", "")[:10],
                "modificado": it.get("modified", "")[:10],
                "meta": meta,
                "h1": next((b["x"] for b in textos if b["t"] == "h1" and b.get("x")), ""),
                "bloques": textos,
                "imagenes": imgs,
                "faq": faq,
                "testimonios": quotes,
                "palabras": palabras,
                "invisibles": invis,
                "forma": "elementor" if "data-elementor-type" in contenido
                         else ("clasico" if contenido.strip() else "vacio"),
            })
            contadores[f"{tipo}s"] += 1
            contadores["bloques"] += len(textos)
            contadores["imagenes"] += len(imgs)
            contadores["faq"] += len(faq)
            contadores["testimonios"] += len(quotes)
            contadores["invisibles"] += invis

    SALIDA.mkdir(parents=True, exist_ok=True)
    destino = SALIDA / "pages.jsonl"
    with destino.open("w", encoding="utf-8", newline="\n") as f:
        for r in sorted(registros, key=lambda x: (x["tipo"] != "page", x["slug"])):
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    # ---------------- BLOQUE DE CONTROL: contar contra la fuente -----------
    # No es opcional. Un extractor que pierde datos NO falla: entrega menos.
    print(f"escrito {destino}  ({destino.stat().st_size // 1024} KB)\n")
    print("CONTROL — extraido vs fuente")
    print(f"  {'que':<22} {'JSONL':>7} {'FUENTE':>7}  {'':4}")

    def linea(nombre, extraido, fuente):
        ok = "OK" if extraido == fuente else "<-- DESCUADRA"
        print(f"  {nombre:<22} {extraido:>7} {fuente:>7}  {ok}")
        return extraido == fuente

    todo_ok = True
    todo_ok &= linea("paginas", contadores["pages"], contadores["pages_origen"])
    todo_ok &= linea("entradas", contadores["posts"], contadores["posts_origen"])

    # Fuente independiente para imagenes y faq: se cuentan sobre el HTML crudo
    src_img = src_faq = src_cite = 0
    for fichero in ("pages", "posts"):
        for it in json.loads((API / f"{fichero}.json").read_text(encoding="utf-8")):
            c = rendered(it, "content")
            src_img += len([s for s in re.findall(r'<img\b[^>]*?\bsrc="([^"]*)"', c)
                            if not s.startswith("data:")])
            src_faq += len(re.findall(r"<summary\b", c))
            src_cite += len(re.findall(r"<cite\b", c))
    todo_ok &= linea("imagenes <img>", contadores["imagenes"], src_img)
    todo_ok &= linea("testimonios <cite>", contadores["testimonios"], src_cite)
    todo_ok &= linea("faq <summary>", contadores["faq"], src_faq)

    # Una FAQ sin respuesta cuenta igual en el total: hay que mirarla aparte
    huerfanas = [(r["slug"], f["q"]) for r in registros for f in r["faq"] if not f["a"]]
    if huerfanas:
        print(f"\n  🔴 FAQ SIN RESPUESTA ({len(huerfanas)}):")
        for s, q in huerfanas:
            print(f"       {s}: {q[:60]}")

    print(f"\n  bloques de texto totales : {contadores['bloques']}")
    print(f"  caracteres invisibles    : {contadores['invisibles']}"
          + ("  (se extraen tal cual, se limpian en el generador)" if contadores["invisibles"] else ""))
    print(f"  biblioteca de medios     : {len(media)} ficheros")

    sin_meta = [r["slug"] for r in registros if not r["meta"].get("title")]
    if sin_meta:
        print(f"\n  sin <title> capturado ({len(sin_meta)}): {', '.join(sin_meta[:8])}")
    vacias = [r["slug"] for r in registros if r["forma"] == "vacio"]
    if vacias:
        print(f"  paginas vacias en origen: {', '.join(vacias)}")

    return 0 if todo_ok else 1


if __name__ == "__main__":
    sys.exit(main())
