#!/usr/bin/env python3
"""INVENTARIO CONTRA INVENTARIO — origen WordPress

POR QUE ESTE GATE Y NO UNA LISTA DE COMPROBACION
Un checklist responde "¿esta lo que espero?". Esto responde "¿que tenian ellos
que nosotros no?". Enumera desde SU LADO, asi que detecta categorias enteras que
no se me habian ocurrido. En Site A a Domicile los checklists dejaron pasar 13
imagenes, 5 fichas de equipo, GTM entero y un formulario completo, todos los
gates en verde.

POR QUE PYTHON Y NO BASH
El `audit-vs-source.sh` de la skill asume un origen Lovable (`src/*.tsx`) y aqui
el origen es WordPress. Y en esta migracion he roto cuatro barridos con grep
sobre HTML y JSON en un solo dia: `<p[^>]*>` casa con `<path`, `[^"]` se corta en
la primera comilla escapada, `sed 's|\\/|/|g'` no desescapa dentro de un heredoc
por ssh, y un diagnostico mio marco 30 de 31 FAQ como rotas. Para HTML y JSON:
parser, no regex.

SE COMPARA CONTRA LA CAPTURA, NO CONTRA SU WEB VIVA. Al mover el DNS su web deja
de existir; `_migrate/origen/` es permanente.
"""
import json
import re
import sys
import unicodedata
from html.parser import HTMLParser
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "_migrate" / "origen"
SPEC = RAIZ / "_spec"

fallos = []
avisos = []


def ok(que, det=""):
    print(f"  OK       {que:<34} {det}")


def falta(que, det=""):
    print(f"  !! FALTA {que:<34} {det}")
    fallos.append(que)


def revisar(que, det=""):
    print(f"  ?  MIRAR {que:<34} {det}")
    avisos.append(que)


# ---------------------------------------------------------------- utilidades
class Texto(HTMLParser):
    """Saca el texto visible. Ignora script, style y svg — `<p[^>]*>` de un grep
    casa con `<path` y se traga media seccion; un parser no puede."""

    # nav/header/footer fuera: es el mismo menu en las 33 paginas y su texto no
    # es contenido. Contarlo inflaba los fallos de fidelidad y daba 8 paginas en
    # rojo donde el medidor independiente daba 4.
    SALTAR = {"script", "style", "svg", "noscript", "nav", "header", "footer"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.partes = []
        self.saltando = 0

    # ⚠️ Un ESPACIO en cada frontera de etiqueta. Sin esto, "</h3><p>" pega las
    # dos frases: en su HTML salia "hipnosis apertura de caminoshipnosis para
    # abrir caminos" y en el nuestro, con los bloques separados, salia con
    # espacio. 10 frases por pagina daban por perdidas estando puestas.
    def handle_starttag(self, t, a):
        if t in self.SALTAR:
            self.saltando += 1
        elif not self.saltando:
            self.partes.append(" ")

    def handle_endtag(self, t):
        if t in self.SALTAR and self.saltando:
            self.saltando -= 1
        elif not self.saltando:
            self.partes.append(" ")

    def handle_data(self, d):
        if not self.saltando:
            self.partes.append(d)


def texto_de(html):
    p = Texto()
    p.feed(html)
    return re.sub(r"\s+", " ", "".join(p.partes))


def norm(s):
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    # ⚠️ Colapsar espacios DESPUES de quitar la puntuacion. Sin esto,
    # "<strong>El Ermitano</strong>: puede" deja DOS espacios donde estaban los
    # dos puntos y no casa con nuestro texto, que tiene uno. Daba frases por
    # perdidas que estaban puestas.
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]", " ", s.lower())).strip()


def leer(p):
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


NUESTRAS = {}
for f in RAIZ.rglob("index.html"):
    if "_migrate" in f.parts or "origen" in f.parts:
        continue
    ruta = "/" + str(f.relative_to(RAIZ).parent).replace("\\", "/").strip(".") + "/"
    NUESTRAS[ruta.replace("//", "/")] = leer(f)
TODO_NUESTRO = "\n".join(NUESTRAS.values())

spec = json.loads(leer(SPEC / "site.json"))
RETIRADAS = {k.rstrip("/") for k in spec["urls"]["se_retiran"].keys()}

print(f"\n{'=' * 70}\nINVENTARIO CONTRA INVENTARIO — {len(NUESTRAS)} paginas nuestras\n{'=' * 70}")

# ------------------------------------------------------------------ 1. URLs
print("\n=== 1. URLs que ellos publicaban ===")
suyas = [l.strip().rstrip("/") for l in leer(ORIGEN / "api" / "urls.txt").splitlines() if l.strip()]
faltan_urls = []
for u in suyas:
    ruta = u.replace("https://site-e.example", "") or "/"
    if not ruta.endswith("/"):
        ruta += "/"
    if ruta in NUESTRAS:
        continue
    if ruta.rstrip("/") in RETIRADAS:
        continue
    faltan_urls.append(ruta)
if faltan_urls:
    for r in faltan_urls:
        falta("url", r)
else:
    ok("las 33 URLs suyas", f"{len(NUESTRAS)} nuestras, {len(RETIRADAS)} retiradas a proposito")

# --------------------------------------------------------------- 2. imagenes
print("\n=== 2. Imagenes que ellos mostraban ===")
paginas = [json.loads(l) for l in (SPEC / "pages.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()]
sus_img = {i["src"].split("/")[-1] for p in paginas for i in p["imagenes"] if i.get("src", "").startswith("http")}
perdidas = []
for f in sorted(sus_img):
    base = re.sub(r"\.(jpg|jpeg|png|webp)$", "", f, flags=re.I)
    if f"/assets/img/{base}.webp" in TODO_NUESTRO:
        continue
    # ⚠️ WordPress genera variantes por tamano del MISMO original
    # (foo.jpg, foo-1024x683.jpg, foo-300x200.jpg). La pregunta es "perdimos
    # esta IMAGEN", no "perdimos este fichero exacto": si usamos otra variante
    # de la misma base, no falta nada. Sin esto el gate reclamaba las 11
    # miniaturas de su widget de entradas relacionadas.
    raiz_img = re.sub(r"-\d+x\d+$", "", base)
    if re.search(rf"/assets/img/{re.escape(raiz_img)}(-\d+x\d+)?\.webp", TODO_NUESTRO):
        continue
    # puede estar en una pagina retirada: no es un hueco
    en_retirada = any(
        i["src"].endswith(f) for p in paginas if p["slug"] in {r.strip("/") for r in RETIRADAS}
        for i in p["imagenes"])
    if not en_retirada:
        perdidas.append(f)
if perdidas:
    for f in perdidas[:12]:
        falta("imagen", f)
    if len(perdidas) > 12:
        print(f"           ... y {len(perdidas)-12} mas")
else:
    ok("imagenes", f"{len(sus_img)} suyas, todas presentes")

# --------------------------------------------------------- 3. vias de contacto
print("\n=== 3. Vias de contacto que ellos ofrecian ===")
sus_wa, sus_tel, sus_mail = set(), set(), set()
for f in (ORIGEN / "paginas").glob("*.html"):
    h = leer(f)
    sus_wa |= set(re.findall(r"phone=(\d{9,15})", h))
    sus_tel |= set(re.findall(r'href="tel:([^"]+)"', h))
    sus_mail |= set(re.findall(r'href="mailto:([^"?]+)', h))
for n in sorted(sus_wa):
    if n in TODO_NUESTRO:
        ok("whatsapp", n)
    elif n == spec["contacto"].get("whatsapp_retirado"):
        revisar("whatsapp retirado", f"{n} - decision de Manuel, no un olvido")
    else:
        falta("whatsapp", n)
for t in sorted(sus_tel):
    ok("tel", t) if t in TODO_NUESTRO else revisar("tel", f"{t} suyo, no en el nuestro")
for m in sorted(sus_mail):
    if m in TODO_NUESTRO:
        ok("email", m)
    else:
        revisar("email", f"{m} - es un Gmail personal, se sustituye por buzon del dominio")

# ------------------------------------------------------------- 4. formularios
print("\n=== 4. Formularios ===")
suyos = sum(1 for f in (ORIGEN / "paginas").glob("*.html") if "<form" in leer(f).lower())
nuestros = sum(1 for h in NUESTRAS.values() if "<form" in h.lower())
print(f"  suyos: {suyos} pagina(s) con <form>   nuestros: {nuestros}")
if nuestros >= 1:
    ok("formulario de captacion", "su web tenia CERO (solo el login de WooCommerce)")
else:
    falta("formulario de captacion")
if "mailto:" in "".join(h for h in NUESTRAS.values() if "<form" in h):
    falta("formulario por mailto", "no envia si no hay cliente de correo y no deja copia")

# --------------------------------------------------------------- 5. medicion
print("\n=== 5. Medicion ===")
sus_ids = set()
for f in (ORIGEN / "paginas").glob("*.html"):
    sus_ids |= set(re.findall(r"GTM-[A-Z0-9]+|AW-\d+|G-[A-Z0-9]{8,}", leer(f)))
for i in sorted(sus_ids):
    if i in TODO_NUESTRO:
        ok("id", i)
    else:
        falta("id", f"{i} - su web lo carga y la nuestra no")
if "consent" not in TODO_NUESTRO.lower():
    revisar("consent mode v2", "ni ellos lo tenian; va con GTM cuando haya accesos")

# ------------------------------------------------------------------- 6. FAQ
print("\n=== 6. FAQ y testimonios ===")
sus_faq = sum(len(p["faq"]) for p in paginas)
nuestras_faq = TODO_NUESTRO.count("<summary")
ok("faq", f"{nuestras_faq} de {sus_faq}") if nuestras_faq >= sus_faq - len(RETIRADAS) \
    else falta("faq", f"{nuestras_faq} frente a {sus_faq} suyas")
# ⚠️ Se cuentan los NOMBRES uno a uno. La primera version buscaba la palabra
# "testimon" en nuestro HTML y daba OK — pero esa palabra aparece en SU propio
# texto ("miles de testimonios"), asi que el gate pasaba en verde con 43 de los
# 61 testimonios perdidos. Un gate que busca una palabra mide mi hipotesis, no
# el hecho.
sus_nombres = [t.strip() for p in paginas
               if p["slug"] not in {r.strip("/") for r in RETIRADAS}
               for t in p["testimonios"] if t.strip()]
puestos = sum(1 for t in sus_nombres if t in TODO_NUESTRO)
if puestos >= len(sus_nombres):
    ok("testimonios", f"{puestos} de {len(sus_nombres)}")
else:
    falta("testimonios", f"solo {puestos} de {len(sus_nombres)} nombres presentes")

# --------------------------------------------------------- 7. meta por pagina
print("\n=== 7. Metadatos ===")
# ⚠️ No basta con que el og:image ESTE: tiene que RESOLVER. La primera version
# de este gate solo comprobaba su presencia y dio verde con 23 de 30 paginas
# apuntando a /wp-content/uploads/..., que no existe en nuestro sitio. Al
# compartir por WhatsApp -su unico canal- habrian salido sin imagen.
sin_og = []
og_roto = []
for r, h in NUESTRAS.items():
    m = re.search(r'og:image" content="([^"]+)"', h)
    if not m:
        sin_og.append(r)
        continue
    destino = m.group(1).replace("https://site-e.example", "").lstrip("/")
    if not (RAIZ / destino).exists():
        og_roto.append(f"{r} -> /{destino}")
if og_roto:
    for x in og_roto[:6]:
        falta("og:image no resuelve", x)
    if len(og_roto) > 6:
        print(f"           ... y {len(og_roto)-6} mas")
sin_canon = [r for r, h in NUESTRAS.items() if 'rel="canonical"' not in h]
sin_h1 = [r for r, h in NUESTRAS.items() if "<h1" not in h]
ok("og:image", "en las %d" % len(NUESTRAS)) if not sin_og else falta("og:image", f"faltan en {len(sin_og)}: {', '.join(sin_og[:4])}")
ok("canonical", "en las %d" % len(NUESTRAS)) if not sin_canon else falta("canonical", f"faltan en {len(sin_canon)}")
ok("h1", "en las %d" % len(NUESTRAS)) if not sin_h1 else falta("h1", f"faltan en {len(sin_h1)}: {', '.join(sin_h1[:4])}")

# ------------------------------------------------ 8. fidelidad del texto suyo
print("\n=== 8. Fidelidad: cuanto de SU texto sobrevive ===")
# 🔴 Se compara contra SU HTML SERVIDO, no contra los bloques ya extraidos.
# La primera version hacia lo segundo y era CIRCULAR: si el extractor se dejaba
# algo, no estaba en los bloques y el gate no lo echaba de menos. Daba ">=90% en
# todas" mientras se perdia el 32% del contenido y las 6 paginas de anuncios
# estaban al 25-31%.
# Lo que ellos tienen y nosotros NO a proposito se descuenta aqui, por nombre.
# Lo que ellos tienen y nosotros NO, a proposito. Se declara por nombre para que
# no se cuele nada mas por descuido: todo lo demas que falte es un hueco de
# verdad. Sus DOS plugins de cookies desaparecen y ponemos banner propio, asi
# que su panel de configuracion no se replica.
SUYO_A_PROPOSITO = (
    "utilizamos cookies", "cerrar el banner", "entradas relacionadas",
    "ir al contenido", "aceptar rechazar", "ajustes de cookies",
    "cookies se almacena en tu navegador", "ver cookies", "activar o desactivar",
    "guardar cambios", "rechazar todo", "activar todo",
)
peores = []
tot_suyas = tot_puestas = 0
for f in sorted((ORIGEN / "paginas").glob("*.html")):
    slug = f.stem
    ruta = "/" if slug == "home" else f"/{slug}/"
    if ruta not in NUESTRAS:
        continue
    nuestro = norm(texto_de(NUESTRAS[ruta]))
    # ⚠️ Partir en frases ANTES de normalizar. norm() quita la puntuacion, asi
    # que hacerlo al reves deja un unico bloque gigante y el gate media 0%
    # cantando "todas >= 90%": dos afirmaciones contradictorias a la vez.
    suyas = [norm(s) for s in re.split(r"[.!?]\s+", texto_de(leer(f)))]
    suyas = [s for s in suyas
             if len(s.split()) >= 6 and not any(x in s for x in SUYO_A_PROPOSITO)]
    if not suyas:
        continue
    faltan = [s for s in suyas if s[:60] not in nuestro]
    tot_suyas += len(suyas)
    tot_puestas += len(suyas) - len(faltan)
    pct = (len(suyas) - len(faltan)) * 100 // len(suyas)
    if pct < 90:
        peores.append((pct, slug, len(faltan), len(suyas)))
glob_pct = tot_puestas * 100 // max(tot_suyas, 1)
if peores:
    for pct, slug, n, t in sorted(peores)[:8]:
        falta("fidelidad", f"{slug}: {pct}% (faltan {n} de {t} frases)")
else:
    ok("fidelidad de texto", f"{glob_pct}% global, todas >= 90%")

# ------------------------------------------------------- 9. ficheros de sitio
print("\n=== 9. Ficheros de sitio ===")
for f in ("robots.txt", "sitemap.xml", "llms.txt", "styles.css", "script.js", "assets/favicon.svg"):
    ok(f) if (RAIZ / f).exists() else falta(f)
sm = leer(RAIZ / "sitemap.xml").count("<loc>")
lm = len(re.findall(r"^- \[", leer(RAIZ / "llms.txt"), re.M))
ok("sitemap == llms", f"{sm} URLs") if sm == lm else falta("sitemap != llms", f"{sm} frente a {lm}")

# -------------------------------------------------------------- 10. legales
print("\n=== 10. Legales ===")
for slug, nombre in (("aviso-legal", "aviso legal"), ("politica-privacidad", "privacidad"),
                     ("politica-de-cookies-ue", "cookies")):
    h = NUESTRAS.get(f"/{slug}/", "")
    if not h:
        falta(nombre, "no existe")
    elif "El titular del sitio" in h or "Domicilio: -" in h:
        revisar(nombre, "plantilla SIN RELLENAR - lo aporta el cliente (LSSI art. 10)")
    else:
        ok(nombre)

# ------------------------------------------------------------------ veredicto
print("\n" + "-" * 70)
print(f"  huecos: {len(fallos)}    a mirar: {len(avisos)}")
if fallos:
    print("  NO se despliega asi.")
else:
    print("  SIN HUECOS frente a su captura.")
sys.exit(1 if fallos else 0)
