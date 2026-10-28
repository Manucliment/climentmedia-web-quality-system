#!/usr/bin/env bash
# =============================================================================
#  Banco de `extract-wordpress.py` — el extractor de una migracion de WordPress.
#
#  🔴 POR QUE EXISTE. Un extractor que se deja datos no falla: entrega menos.
#  Por eso imprime su bloque de CONTROL (extraido contra fuente) y sale 1 si
#  algo DESCUADRA. Pero ese control no tenia ni un caso que lo viera en rojo, y
#  al escribirlo aparecio un agujero: una imagen con carga diferida
#  (`src="data:…"` y la foto en `data-src`) la perdian el extractor Y el
#  control a la vez -> 0 = 0, «OK», con la imagen fuera.
#
#  Casos verdes sobre un origen de mentira, y casos rojos sobre una COPIA del
#  extractor con un fallo ya sufrido metido a mano (paginacion que se deja la
#  ultima, testimonios fuera de la lista, respuesta de FAQ que no es un <p>).
#  Cada mutacion comprueba que cambio exactamente una linea antes de fiarse.
#
#  Uso: bash gates/extract-wordpress-tests/tests.sh      (necesita python3)
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
GATE="$(cd "$D/.." && pwd)/extract-wordpress.py"
ok=0; ko=0
T="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/exw-$$")"
trap 'rm -rf "$T"' EXIT
command -v python3 >/dev/null || { echo "  NO MEDIDO: no hay python3"; exit 2; }
[ -f "$GATE" ] || { echo "  no encuentro extract-wordpress.py"; exit 2; }

pasa() { ok=$((ok+1)); echo "  PASA  $1"; }
falla() { ko=$((ko+1)); echo "  FALLA $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/        /' | head -20; }

# El origen: dos paginas y una entrada, como las deja `wp-json` + el HTML servido.
mkdir -p "$T/sitio/origen/api" "$T/sitio/origen/paginas"
cat > "$T/sitio/origen/api/pages.json" <<'EOF'
[
 {"id": 1, "slug": "inicio", "link": "https://site-e.example/", "date": "2026-01-01T00:00:00", "modified": "2026-02-01T00:00:00",
  "title": {"rendered": "Inicio"},
  "content": {"rendered": "<div data-elementor-type=\"wp-page\"><h1>Bienvenida</h1><div>Texto suelto dentro de un div.</div><img src=\"https://site-e.example/wp-content/uploads/a.jpg\" alt=\"A\"><img src=\"data:image/svg+xml,%3Csvg%3E\" data-src=\"https://site-e.example/wp-content/uploads/diferida.jpg\" alt=\"Diferida\"><blockquote><p>Me cambio la vida.</p><cite><span>Carla S.</span> <span>Valencia</span></cite></blockquote></div>"}},
 {"id": 2, "slug": "preguntas", "link": "https://site-e.example/preguntas/", "date": "2026-01-02T00:00:00", "modified": "2026-02-02T00:00:00",
  "title": {"rendered": "Preguntas"},
  "content": {"rendered": "<h1>Preguntas</h1><details><summary><span>¿Cuanto dura?</span></summary><p>Una hora.</p></details><details><summary>¿Que incluye?</summary><ul><li>La primera consulta.</li><li>El informe escrito.</li></ul></details>"}}
]
EOF
cat > "$T/sitio/origen/api/posts.json" <<'EOF'
[
 {"id": 3, "slug": "una-entrada", "link": "https://site-e.example/una-entrada/", "date": "2026-01-03T00:00:00", "modified": "2026-01-03T00:00:00",
  "title": {"rendered": "Una entrada"},
  "content": {"rendered": "<p>Primera frase.<br>Segunda frase.</p><img src=\"https://site-e.example/wp-content/uploads/b.jpg\" alt=\"\">"}}
]
EOF
echo '[{"source_url": "https://site-e.example/wp-content/uploads/a.jpg", "alt_text": "A de la biblioteca"}]' > "$T/sitio/origen/api/media.json"
echo '<html><head><title>Inicio | Site E</title><meta name="description" content="La portada"></head></html>' > "$T/sitio/origen/paginas/home.html"

corre() { # corre <script> -> deja $out y $rc
  rm -rf "$T/_spec"
  out="$(cd "$T" && python3 "$1" "$T/sitio" 2>&1)"; rc=$?
}

# --- verde ------------------------------------------------------------------
corre "$GATE"
J="$T/_spec/pages.jsonl"
if [ "$rc" = 0 ] && ! grep -q DESCUADRA <<<"$out"; then pasa "origen sano: sale 0 y nada DESCUADRA"; else falla "origen sano: sale 0 y nada DESCUADRA (rc=$rc)" "$out"; fi
[ "$(grep -c . "$J" 2>/dev/null)" = 3 ] && pasa "3 registros (2 paginas y 1 entrada)" || falla "3 registros" "$(cat "$J" 2>/dev/null)"
grep -q 'diferida.jpg' "$J" && pasa "la imagen con carga diferida (src data: + data-src) se extrae" || falla "la imagen con carga diferida se extrae"
grep -qE 'imagenes <img> +3 +3 +OK' <<<"$out" && pasa "el control cuenta 3 imagenes en la fuente, la diferida incluida" || falla "el control cuenta 3 imagenes en la fuente" "$(grep imagenes <<<"$out")"
grep -qE 'testimonios <cite> +1 +1 +OK' <<<"$out" && pasa "una firma con dos <span> es UN testimonio" || falla "una firma con dos <span> es UN testimonio" "$(grep testimonios <<<"$out")"
grep -q '"t": "li", "x": "El informe escrito."' "$J" && pasa "la respuesta de FAQ que es un <ul> se queda en la FAQ, como lista" || falla "la respuesta de FAQ que es un <ul> se queda en la FAQ"
grep -q 'Texto suelto dentro de un div.' "$J" && pasa "el texto suelto de un <div> de Elementor no se pierde" || falla "el texto suelto de un <div> no se pierde"
grep -q 'Primera frase. Segunda frase.' "$J" && pasa "un <br> separa las frases (no «frase.Segunda»)" || falla "un <br> separa las frases"

# --- rojo: fallos ya sufridos, metidos en una copia --------------------------
muta() { # muta <nombre> <perl -pe> <espera en la salida>
  local nom="$1" expr="$2" espera="$3" m="$T/mut.py" n
  cp "$GATE" "$m"
  perl -i -pe "$expr" "$m"
  n="$(diff "$GATE" "$m" | grep -c '^>')"
  if [ "$n" != 1 ]; then falla "$nom: la mutacion tenia que cambiar 1 linea y cambio $n"; return; fi
  corre "$m"
  if [ "$rc" != 0 ] && grep -qE "$espera" <<<"$out"; then pasa "$nom: sale $rc y lo dice"; else falla "$nom (rc=$rc, se esperaba «$espera»)" "$out"; fi
}
muta "paginacion que se deja el ultimo (per_page=100 con 129)" 's/^(\s+)for it in datos:/$1for it in datos[:-1]:/' 'paginas .*DESCUADRA'
muta "testimonios solo al flujo, fuera de la lista (0 de 61)" 's/^(\s+)quotes\.append\(b\["x"\]\)/$1pass/' 'testimonios .*DESCUADRA'
muta "la respuesta de FAQ que no es un <p> se pierde (30 de 31)" 's/elif b\["t"\] == "faq_a" and q:/elif b["t"] == "faq_a" and q and b.get("origen") == "p":/' 'FAQ SIN RESPUESTA'
muta "volver a tomar el src de relleno (la imagen diferida fuera)" 's/^(\s+)if not src or src\.startswith\("data:"\):/$1if not src:/' 'imagenes <img> +2 +3 +<-- DESCUADRA'

echo
echo "OK $ok · MAL $ko"
[ "$ko" = 0 ]
