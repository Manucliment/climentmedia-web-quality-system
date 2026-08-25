#!/usr/bin/env bash
# =============================================================================
#  audit-source.sh — auditar la web ACTUAL del cliente, antes de tocar nada
# =============================================================================
#  Mide contra lo que sirve el servidor, NO contra el repo. Sin credenciales:
#  todo sale de endpoints publicos.
#
#  Uso:  bash audit-source.sh https://sudominio.tld
#
#  Por que existe: sin medida no hay mejora, hay opinion. Y la mitad del valor
#  esta en decir QUE YA ESTABA BIEN — una migracion que se apunta mejoras que no
#  ha hecho no es fiable.
# =============================================================================

set -u
BASE="${1:?uso: audit-source.sh https://dominio.tld}"
BASE="${BASE%/}"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

curl -s --compressed -L --max-time 20 "$BASE/" -o "$T/home.html" -D "$T/hdr"

say "1 · ENTREGA"
printf '  HTTP %s · %s KB de HTML\n' \
  "$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 15 "$BASE/")" \
  "$(( $(wc -c < "$T/home.html") / 1024 ))"
grep -iE '^(server|x-powered-by|cf-ray|x-vercel-id):' "$T/hdr" | sed 's/^/  /'
printf '  gzip: %s KB\n' "$(( $(gzip -c "$T/home.html" | wc -c) / 1024 ))"

say "2 · TERCEROS (lo que ejecuta codigo de otro)"
grep -aoE '(src|href)="https?://[^"]+"' "$T/home.html" \
  | sed 's/^[a-z]*="//; s/"$//' \
  | sed 's|^\(https\?://[^/]*\).*|\1|' | sort -u \
  | grep -v "$(printf '%s' "$BASE" | sed 's|https\?://||')" | sed 's/^/  /'
echo "  (vacio = cero terceros, que es lo deseable)"
echo "  ⚠️ Google Fonts cuenta: transfiere la IP del visitante a Google."

say "3 · IDs DE SEGUIMIENTO"
grep -aoE 'GTM-[A-Z0-9]{6,10}|G-[A-Z0-9]{8,12}|AW-[0-9]{9,12}|UA-[0-9]+-[0-9]+' "$T/home.html" \
  | sort -u | sed 's/^/  /'
for js in $(grep -aoE '/assets/[A-Za-z0-9._-]+\.js' "$T/home.html" | sort -u | head -8); do
  curl -s --compressed --max-time 12 "$BASE$js" -o "$T/j" 2>/dev/null
  grep -aoE 'GTM-[A-Z0-9]{6,10}|G-[A-Z0-9]{8,12}|AW-[0-9]{9,12}' "$T/j" 2>/dev/null
done | sort -u | sed 's/^/  (en JS) /'
grep -aq 'fbq(' "$T/home.html" && echo "  Meta Pixel: SI" || echo "  Meta Pixel: no"

say "4 · EL CONTENEDOR GTM, POR DENTRO"
# ⚠️ Un contenedor puede estar puesto y VACIO, o escuchar menos eventos de los
# que el sitio dispara. Es el fallo mas caro y el menos visible.
for g in $(grep -aoE 'GTM-[A-Z0-9]{6,10}' "$T/home.html" | sort -u); do
  curl -s --max-time 20 "https://www.googletagmanager.com/gtm.js?id=$g" -o "$T/gtm.js"
  printf '  %s · %s KB\n' "$g" "$(( $(wc -c < "$T/gtm.js") / 1024 ))"
  printf '    GA4/Ads dentro: %s\n' \
    "$(grep -oE 'G-[A-Z0-9]{8,12}|AW-[0-9]{9,12}' "$T/gtm.js" | sort -u | tr '\n' ' ')"
  printf '    tags: %s\n' \
    "$(grep -oE '"(gaawe|googtag|awct|html)"' "$T/gtm.js" | sort | uniq -c | tr '\n' ' ')"
done
echo "    → cruzar con los eventos que el sitio dispara: si el sitio habla"
echo "      mas eventos de los que el contenedor escucha, se estan tirando."

say "5 · FICHEROS PARA MAQUINAS"
for f in robots.txt sitemap.xml llms.txt; do
  printf '  %-12s HTTP %s\n' "$f" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE/$f")"
done
N=$(curl -s --compressed --max-time 15 "$BASE/sitemap.xml" | grep -c '<loc>')
echo "  URLs en sitemap: $N   ← se conservan TODAS"

say "6 · JSON-LD (que ya tienen y no hay que rehacer)"
grep -ao '"@type": *"[^"]*"' "$T/home.html" | sed 's/.*"\([A-Za-z]*\)"$/\1/' | sort | uniq -c | sed 's/^/  /'

say "7 · IMAGENES Y CLS"
# ⚠️ AQUI MISMO ME COMI LA TRAMPA 2 de 07-trampas.md: escribi `grep -aoc '<img'`
# y devolvio 1 (LINEAS, porque el HTML viene en una sola) mientras las otras dos
# medidas contaban coincidencias. Salio "1 img, 4 con width+height", que es
# imposible y por eso se vio. Con un HTML de varias lineas habria dado un numero
# plausible y me lo habria creido.
TOT=$(grep -ao '<img' "$T/home.html" | wc -l)
WH=$(grep -ao '<img[^>]*width="[^"]*"[^>]*height="' "$T/home.html" | wc -l)
ALT=$(grep -ao '<img[^>]*alt="' "$T/home.html" | wc -l)
printf '  <img>: %s · con width+height: %s · con alt: %s\n' "$TOT" "$WH" "$ALT"
[ "${TOT:-0}" -gt 0 ] && [ "$WH" -lt "$TOT" ] && \
  echo "  ⚠️ $((TOT - WH)) sin dimensiones → desplazamiento de layout (CLS)"

say "8 · TITULOS Y META (muestra del sitemap)"
curl -s --compressed --max-time 15 "$BASE/sitemap.xml" | grep -oE '<loc>[^<]*' | sed 's/<loc>//' | head -20 > "$T/urls"
: > "$T/titles"
while IFS= read -r u; do
  curl -s --compressed --max-time 12 "$u" | grep -ao '<title>[^<]*' | head -1 | sed 's/<title>//' >> "$T/titles"
done < "$T/urls"
printf '  paginas revisadas: %s · titulos unicos: %s\n' "$(wc -l < "$T/urls")" "$(sort -u "$T/titles" | wc -l)"
d=$(sort "$T/titles" | uniq -d)
[ -n "$d" ] && { echo "  ⚠️ TITULOS DUPLICADOS (canibalizacion):"; printf '%s\n' "$d" | sed 's/^/    /'; }
awk '{ if (length($0) > 60) printf "  ⚠️ %3d car: %s\n", length($0), $0 }' "$T/titles"

say "RESUMEN"
echo "  Lo que sale aqui es el ANTES. Guardarlo en ESTUDIO.md antes de tocar nada:"
echo "  sin el, cualquier mejora que reportemos despues es una opinion."
