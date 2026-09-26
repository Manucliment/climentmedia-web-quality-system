#!/usr/bin/env bash
# =============================================================================
#  tests-404-host.sh · G11 le pregunta al HOST por su 404 (EST-03)
# =============================================================================
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/receipt-tests/tests-404-host.sh"
#
#  EL FALLO QUE ESTAS PRUEBAS EXISTEN PARA QUE NO VUELVA (26-sep-2026)
#  ------------------------------------------------------------------
#  Una web recien publicada: recibo PASA, G11 PASA... y cada URL rota ensenaba
#  la pagina GENERICA del servidor (805 bytes, sin menu ni salida). EST-03 tiene
#  dos mitades: el candidato mide el CONTENIDO del 404.html, y que el host lo
#  SIRVA quedaba «para despues de subir». Despues de subir no lo preguntaba
#  nadie, y la puerta decia que G11 ya lo contestaba.
#
#  Aqui el servidor de pruebas se porta como los tres hosts que importan:
#    sin marcador    -> 404 de 3 bytes: la pagina del servidor     -> G11 FALLA
#    _errordoc.txt   -> 404 con el 404.html: un ErrorDocument bueno -> G11 PASA
#    _soft404.txt    -> 200 con el 404.html: un soft 404            -> G11 FALLA
#  y un arbol SIN 404.html dice NO VERIFICADO: ni aprueba ni suspende.
#  Y el 404.html bloqueado en su propia URL («la pagina de error no es una
#  pagina») cuenta como servido SOLO si la 404 del host es ese fichero byte a
#  byte; con el <title> a secas, no.
#  NO TOCA NINGUNA WEB VIVA: todo es 127.0.0.1.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
REF="$(cd .. && pwd)"
T="${TEMP:-/tmp}/g11-404-pruebas-$$"
PUERTO=$(( 9300 + ($$ % 600) ))
export QA_RECIBOS_DIR="$T/historial-de-pruebas"
OK=0; MAL=0

r() { local nombre="$1" esp="$2"; shift 2
  local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$esp" ]; then OK=$((OK+1)); printf '  PASA  %-52s (exit %s)\n' "$nombre" "$rc"
  else MAL=$((MAL+1)); printf '  FALLA %-52s (exit %s, esperaba %s)\n' "$nombre" "$rc" "$esp"
       printf '%s\n' "$out" | sed 's/^/          /'; fi
  ULTIMA="$out"; }
contiene() { if printf '%s' "$ULTIMA" | grep -qF "$2"; then OK=$((OK+1)); printf '  PASA  %-52s\n' "$1"
  else MAL=$((MAL+1)); printf '  FALLA %-52s (no dice: %s)\n' "$1" "$2"
       printf '%s\n' "$ULTIMA" | sed 's/^/          /'; fi; }
no_contiene() { if printf '%s' "$ULTIMA" | grep -qF "$2"; then MAL=$((MAL+1)); printf '  FALLA %-52s (dice: %s)\n' "$1" "$2"
  else OK=$((OK+1)); printf '  PASA  %-52s\n' "$1"; fi; }

rm -rf "$T"; mkdir -p "$T/repo" "$T/servido"
printf '<!doctype html><html lang="fr"><head><title>Accueil | Site</title></head><body><main><h1>Accueil</h1></main></body></html>\n' > "$T/repo/index.html"
printf '<!doctype html><html lang="fr"><head><title>Page introuvable | Site</title><meta name="robots" content="noindex,follow"></head><body><main><h1>Page introuvable</h1><a href="/">Accueil</a></main></body></html>\n' > "$T/repo/404.html"
cp "$T/repo/"*.html "$T/servido/"

cat > "$T/qa-verde.json" <<'JSON'
{"sitio":"http://127.0.0.1:0","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":0,"no_verificado":0,"pasa":50},
 "instrumento":{"perl":"5.042002","dom":"qa.json"},
 "comprobaciones":[
  {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
  {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
  {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},
  {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
  {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}
JSON

# ── el servidor es MIO antes de creerme nada de lo que conteste ─────────────
CENTINELA="centinela-$$-$(date +%s)"
printf '%s\n' "$CENTINELA" > "$T/servido/_centinela.txt"
perl "$REF/receipt-tests/test-server.pl" "$T/servido" "$PUERTO" >"$T/srv.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
sleep 1
RESP="$(curl -sS --max-time 5 "http://127.0.0.1:$PUERTO/_centinela.txt" 2>/dev/null)"
if [ "$RESP" != "$CENTINELA" ]; then
  echo "  NO ARRANCO MI SERVIDOR DE PRUEBAS en el puerto $PUERTO ('${RESP:0:60}')"
  exit 2
fi
rm -f "$T/servido/_centinela.txt"

sella() { perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
               --sitio "http://127.0.0.1:$PUERTO" >/dev/null; }
g11()   { perl "$REF/receipt.pl" --servido --repo "$T/repo"; }
sella

echo "== 1 · el host contesta con SU pagina (la generica), no con la del arbol"
r "404 generica del servidor: G11 FALLA"         1 g11
contiene "lo nombra como EST-03, las dos rutas"     "404 del host (EST-03): 0 bien · 2 mal"
contiene "dice que el cuerpo no es el del arbol"    "NO con la pagina del arbol"
contiene "y lo dice en rojo"                        "UNA URL ROTA NO ENSENA LA PAGINA 404 DEL SITIO"
contiene "los ficheros SI estan: no los acusa"      "distintos 0"

echo
echo "== 2 · un ErrorDocument bien puesto: 404 y el 404.html del arbol"
printf '404.html\n' > "$T/servido/_errordoc.txt"
r "ErrorDocument bueno: G11 PASA"                 0 g11
contiene "las dos rutas, byte a byte"               "404 del host (EST-03): 2 bien · 0 mal"
contiene "y dice como lo ha comprobado"             "404 con el 404.html del arbol, byte a byte"
no_contiene "sin rojo"                              "UNA URL ROTA"

echo
echo "== 3 · el host retoca bytes pero sirve la pagina del arbol"
{ cat "$T/servido/404.html"; printf '<!-- anadido por el host -->\n'; } > "$T/servido/404-retocado.html"
printf '404-retocado.html\n' > "$T/servido/_errordoc.txt"
r "mismo <title>, bytes distintos: G11 PASA"      0 g11
contiene "y dice que es por el <title>"             "mismo <title>; el host cambia bytes"

echo
echo "== 3-bis · el 404.html bloqueado en su propia URL: la 404 del host ES ese fichero"
# «La pagina de error no es una pagina»: /404.html pedida a mano da 404 y el host
# la sirve en cada URL rota. Sin esto, G11 la contaba NO HALLADO en cada subida y
# la puerta avisaba de algo que no es un fallo. Se simula sirviendola con otro
# nombre: /404.html no existe, y la 404 del host es ese fichero byte a byte.
mv "$T/servido/404.html" "$T/servido/pagina-de-error.html"
printf 'pagina-de-error.html\n' > "$T/servido/_errordoc.txt"
r "404.html servido solo por la 404: G11 PASA"    0 g11
contiene "lo da por servido, y dice por que"        "VERIFICADO-POR-LA-404  404.html"
no_contiene "y no lo cuenta como no hallado"        "NO HALLADO 404.html"
# control: con el <title> a secas NO esta probado que sea ese fichero
printf '404-retocado.html\n' > "$T/servido/_errordoc.txt"
r "control: la 404 por <title> sigue pasando"     0 g11
contiene "pero el 404.html NO se da por servido"    "NO HALLADO 404.html"
no_contiene "ni se inventa la verificacion"         "VERIFICADO-POR-LA-404"
mv "$T/servido/pagina-de-error.html" "$T/servido/404.html"

echo
echo "== 4 · soft 404: la pagina de error con 200"
rm -f "$T/servido/_errordoc.txt"; printf '404.html\n' > "$T/servido/_soft404.txt"
r "soft 404: G11 FALLA"                           1 g11
contiene "nombra el 200"                            "HTTP 200 · tiene que ser 404 (un 200 es un soft 404"

echo
echo "== 5 · un arbol SIN 404.html: NO VERIFICADO, ni aprueba ni suspende"
rm -f "$T/servido/_soft404.txt" "$T/repo/404.html"
sella
r "sin 404.html: G11 no falla por esto"           0 g11
contiene "lo declara como no verificado"            "404 del host (EST-03): NO VERIFICADO · el arbol no trae 404.html"
no_contiene "y no inventa un recuento"              "404 del host (EST-03): 0 bien"

echo
echo "==============================================================================="
printf "  %d PASA · %d FALLA\n" "$OK" "$MAL"
echo "==============================================================================="
[ "$MAL" = 0 ] || exit 1
