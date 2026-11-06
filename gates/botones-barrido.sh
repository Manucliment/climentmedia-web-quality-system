#!/usr/bin/env bash
# =============================================================================
#  BOTONES DE TODO EL SITIO  ·  6-nov-2026
#  bash gates/botones-barrido.sh https://dominio.tld [max-paginas] [json de config]
# =============================================================================
#
#  La puerta mide los botones de las paginas que declara y de las que cambia la
#  subida: a veces una sola. El 2-nov, lo que se vio fueron cinco estilos de
#  boton repartidos por 82 URL. Esto mide TODO el sitemap servido (hasta
#  max-paginas, 40 por defecto) con `botones-gate.js` a 1366 y 390 en el Chrome
#  de NAV_HOST, y junta las salidas con `botones-sitio.js` (la misma regla).
#  Lo corre el repaso mensual de diseño; cualquiera puede correrlo: solo lee.
#
#  Imprime, por pagina y ancho, PASA / FALLA / NO MEDIDO con el primer fallo, y
#  despues lo de entre paginas. Sale con 0 (todo PASA), 1 (algun FALLA) o 3 (no
#  se pudo medir: sin host, sin sitemap o sin ninguna medida valida).
#  La config es la de la puerta (BOTONES_FAMILIAS ya hecho JSON):
#    '{"familias":{"primario":".btn-primary"},"ignorar":["#chat"]}'
# =============================================================================
set -u
SITIO="${1:-}"; MAX="${2:-40}"; CFG="${3:-}"
[ -n "$SITIO" ] || { echo "uso: bash gates/botones-barrido.sh https://dominio.tld [max-paginas] [json]"; exit 2; }
SITIO="${SITIO%/}"
case "$MAX" in ''|*[!0-9]*) echo "max-paginas tiene que ser un numero"; exit 2 ;; esac
REF="$(cd "$(dirname "$0")" && pwd)"
. "$REF/nav-host.sh"
HOST="$(nav_host "$REF")"
[ -n "$HOST" ] || { echo "  NO MEDIDO: NAV_HOST sin configurar ($(nav_host_conf "$REF")). Esto NO es un aprobado."; exit 3; }
command -v node >/dev/null 2>&1 || { echo "  NO MEDIDO: sin node en esta maquina (botones-sitio.js)"; exit 3; }
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36"
LOCAL="$(mktemp -d)"; REMOTO="barrido-botones-$$"
trap 'rm -rf "$LOCAL"; ssh -n -o BatchMode=yes "$HOST" "rm -rf ~/webtools/$REMOTO" >/dev/null 2>&1' EXIT

# Las URL, del sitemap servido (y de un indice de sitemaps, un nivel). Solo las del mismo host.
urls() { curl -s -A "$UA" --max-time 30 "$1" | grep -o '<loc>[^<]*</loc>' | sed 's/<[^>]*>//g'; }
LISTA="$(urls "$SITIO/sitemap.xml")"
if printf '%s\n' "$LISTA" | grep -q '\.xml$'; then
  LISTA="$(printf '%s\n' "$LISTA" | grep '\.xml$' | while read -r s; do urls "$s"; done)"
fi
LISTA="$(printf '%s\n' "$LISTA" | grep -F "$SITIO" | grep -v '\.xml$' | awk '!v[$0]++' | head -n "$MAX")"
N="$(printf '%s\n' "$LISTA" | grep -c .)"
[ "$N" -gt 0 ] || { echo "  NO MEDIDO: el sitemap de $SITIO no da ninguna URL de ese host"; exit 3; }
echo "  $N paginas de $SITIO (tope $MAX), a 1366 y 390, en $HOST"

ssh -n -o BatchMode=yes "$HOST" "mkdir -p ~/webtools/$REMOTO" || { echo "  NO MEDIDO: sin acceso a $HOST"; exit 3; }
scp -q "$REF/run-gate.js" "$HOST:webtools/run-gate.js" </dev/null && scp -q "$REF/botones-gate.js" "$HOST:webtools/$REMOTO/botones-gate.js" </dev/null \
  || { echo "  NO MEDIDO: no se pudo copiar el gate a $HOST"; exit 3; }
i=0
while read -r u; do
  for t in "1366 768" "390 844"; do
    i=$((i+1))
    ( ssh -n -o BatchMode=yes "$HOST" "cd ~/webtools && timeout 120 node run-gate.js '$u' $t $REMOTO/botones-gate.js ${CFG:+'$CFG'}" > "$LOCAL/$i.out" 2>&1 ) &
    [ $((i % 4)) = 0 ] && wait
  done
done <<EOF
$LISTA
EOF
wait

FALLAN=0; MEDIDAS=0
for f in $(ls -v "$LOCAL"/*.out); do
  linea="$(node -e '
    const t = require("fs").readFileSync(process.argv[1], "utf8").split("\n");
    let d = {}, g = null; try { d = JSON.parse(t[0]); } catch (e) {} try { g = JSON.parse(t.slice(1).join("\n")); } catch (e) {}
    const u = (d.url || "").replace(/^https?:\/\/[^/]+/, "") || "?";
    if (!g || !g.VEREDICTO || d.sospechoso || d.coincide !== true) { console.log(`NO MEDIDO ${u} ${d.pedido || ""}`); process.exit(); }
    console.log(`${g.VEREDICTO} ${u} ${g.innerWidth}${g.fallos && g.fallos[0] ? "  " + g.fallos[0].slice(0, 220) : ""}`);' "$f")"
  printf '    %s\n' "$linea"
  case "$linea" in FALLA*) FALLAN=$((FALLAN+1)); MEDIDAS=$((MEDIDAS+1)) ;; PASA*) MEDIDAS=$((MEDIDAS+1)) ;; esac
done
echo
# shellcheck disable=SC2046
node "$REF/botones-sitio.js" $(ls "$LOCAL"/*.out); RC=$?
echo
echo "  $MEDIDAS medidas de $i · $FALLAN FALLA en una pagina · entre paginas: $( [ $RC = 0 ] && echo PASA || { [ $RC = 1 ] && echo FALLA || echo 'NO MEDIDO'; } )"
[ "$MEDIDAS" = 0 ] && exit 3
[ "$FALLAN" -gt 0 ] || [ "$RC" = 1 ] && exit 1
exit 0
