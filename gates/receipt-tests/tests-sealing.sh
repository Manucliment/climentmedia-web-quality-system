#!/usr/bin/env bash
# =============================================================================
#  tests-sealing.sh · la excepcion del asset sellado con ?v=, y sus limites
# =============================================================================
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/receipt-tests/tests-sealing.sh"
#
#  POR QUE EXISTE
#  --------------
#  25-ago-2026, site-a.example. G11 daba esto despues de un despliegue bueno:
#      G11 · identicos 48 · distintos 1
#        DISTINTO  styles.css -> 200 pero md5 distinto (repo 86dcf007 / servido 7f5b0a00)
#  Y el sitio estaba PERFECTO. El HTML enlaza `/styles.css?v=86dcf007` -el sello
#  anti-cache- y esa URL sirve el md5 bueno en 5 de 5 peticiones. Lo viejo estaba
#  SOLO en la URL desnuda `/styles.css`, que no enlaza ninguna pagina y que es
#  exactamente la que el sello existe para no usar. G11 pedia esa.
#  Un rojo que salta en cada despliegue por algo que ningun visitante ve enseña a
#  ignorar el gate, y un gate ignorado no protege nada.
#
#  🔴 PERO LA EXCEPCION TIENE QUE SER LA MAS PEQUEÑA QUE RESUELVE EL CASO.
#     "Si el md5 no casa, prueba con cualquier ?v=" tambien mata el rojo, y de
#     paso deja pasar un CSS que no se ha subido. Por eso aqui hay UN positivo y
#     CINCO negativos: cada negativo es una forma concreta de que esto este mal
#     de verdad, y la excepcion no puede tapar ninguna.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
REF="$(cd .. && pwd)"
T="${TEMP:-/tmp}/sello-pruebas-$$"
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
no_contiene() { if printf '%s' "$ULTIMA" | grep -qF "$2"; then MAL=$((MAL+1)); printf '  FALLA %-52s (NO deberia decir: %s)\n' "$1" "$2"
       printf '%s\n' "$ULTIMA" | sed 's/^/          /'
  else OK=$((OK+1)); printf '  PASA  %-52s\n' "$1"; fi; }

# ── puerto LIBRE, no un puerto a ojo ─────────────────────────────────────────
#  Un puerto ya ocupado responde 200 y mide OTRA cosa; y un servidor que no
#  arranca en silencio contamina las pruebas de al lado. Las dos ya han pasado.
PUERTO=$(( 41000 + ($$ % 9000) ))
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if (exec 3<>/dev/tcp/127.0.0.1/$PUERTO) 2>/dev/null; then
    exec 3<&- 2>/dev/null; exec 3>&- 2>/dev/null
    PUERTO=$(( PUERTO + 1 ))
  else break; fi
done

rm -rf "$T"; mkdir -p "$T/repo" "$T/servido/_sellado"

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

perl "$REF/receipt-tests/sealing-server.pl" "$T/servido" "$PUERTO" > "$T/srv.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
arranco=no
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  grep -q LISTO "$T/srv.log" 2>/dev/null && { arranco=si; break; }
  sleep 0.3
done
if [ "$arranco" != si ]; then
  echo "  🔴 NO ARRANCO el servidor de sello en el puerto $PUERTO."
  echo "  Sin esto las pruebas medirian otra cosa y algunas PASARIAN igual."
  cat "$T/srv.log" 2>/dev/null | sed 's/^/      /'
  exit 2
fi

# ── el fixture ───────────────────────────────────────────────────────────────
#  portada <SELLO>  → un index.html que enlaza el CSS con el ?v= que se le diga
portada() { printf '<!doctype html><html><head><link rel="stylesheet" href="/styles.css%s"></head><body><h1>hola</h1></body></html>\n' "$1"; }

sella() { perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
               --sitio "http://127.0.0.1:$PUERTO" >/dev/null; }

echo "==============================================================================="
echo "  EL ASSET SELLADO CON ?v= Y EL CACHE VIEJO DE LA URL DESNUDA (127.0.0.1)"
echo "==============================================================================="

echo
echo "-- 0 · CONTROL: todo identico, sin nada que excusar --------------------------"
printf 'body{color:red}\n' > "$T/repo/styles.css"
portada "?v=nuevo" > "$T/repo/index.html"
cp "$T/repo/styles.css" "$T/servido/styles.css"
cp "$T/repo/index.html" "$T/servido/index.html"
rm -f "$T/servido/_sellado/styles.css"
sella
r "todo identico: G11 en verde"              0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "y lo cuenta como identico"           "distintos 0"
no_contiene "sin excepcion que aplicar"        "SELLADO-OK"

echo
echo "-- 1 · POSITIVO: desnuda vieja, sellada buena (el caso de site-a) --------------"
printf 'body{color:blue}\n' > "$T/repo/styles.css"
portada "?v=nuevo" > "$T/repo/index.html"
cp "$T/repo/index.html" "$T/servido/index.html"
printf 'body{color:red}\n'  > "$T/servido/styles.css"            # cache viejo del CDN
cp "$T/repo/styles.css" "$T/servido/_sellado/styles.css"          # lo que sirve ?v=
sella
r "sello bueno + desnuda vieja: PASA"        0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "no lo llama DISTINTO"                "distintos 0"
contiene "pero lo DICE, no lo esconde"         "SELLADO-OK"
contiene "y nombra el sello que leyo del HTML" "?v=nuevo"

echo
echo "-- 2 · NEGATIVO: la URL SELLADA tampoco tiene lo bueno -----------------------"
#  El CSS no se subio. Las dos URLs sirven lo viejo. Esto es una averia de verdad.
printf 'body{color:green}\n' > "$T/repo/styles.css"
cp "$T/repo/index.html" "$T/servido/index.html"
printf 'body{color:red}\n' > "$T/servido/styles.css"
printf 'body{color:red}\n' > "$T/servido/_sellado/styles.css"
sella
r "CSS que no se subio: FALLA"               1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "y lo llama DISTINTO"                 "DISTINTO"
no_contiene "la excepcion NO se aplica"        "SELLADO-OK"

echo
echo "-- 3 · NEGATIVO: el HTML no sella nada --------------------------------------"
#  Sin sello no hay URL alternativa que pedir: la desnuda es la que ve el visitante.
printf 'body{color:green}\n' > "$T/repo/styles.css"
portada "" > "$T/repo/index.html"
cp "$T/repo/index.html" "$T/servido/index.html"
printf 'body{color:red}\n' > "$T/servido/styles.css"
cp "$T/repo/styles.css" "$T/servido/_sellado/styles.css"   # aunque la sellada fuera buena
sella
r "sin sello en el HTML: FALLA"              1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "y lo llama DISTINTO"                 "DISTINTO"
no_contiene "no se inventa la URL sellada"     "SELLADO-OK"

echo
echo "-- 4 · NEGATIVO: dos paginas sellan con valores DISTINTOS --------------------"
#  Eso no es cache viejo: es un arbol incoherente, y taparlo seria peor.
printf 'body{color:green}\n' > "$T/repo/styles.css"
portada "?v=nuevo" > "$T/repo/index.html"
portada "?v=otro"  > "$T/repo/otra.html"
cp "$T/repo/index.html" "$T/servido/index.html"
cp "$T/repo/otra.html"  "$T/servido/otra.html"
printf 'body{color:red}\n' > "$T/servido/styles.css"
cp "$T/repo/styles.css" "$T/servido/_sellado/styles.css"
sella
r "sellos incoherentes: FALLA"               1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "y lo llama DISTINTO"                 "DISTINTO"
no_contiene "no elige un sello a dedo"         "SELLADO-OK"
rm -f "$T/repo/otra.html" "$T/servido/otra.html"

echo
echo "-- 5 · NEGATIVO: la excepcion no vale para PAGINAS ---------------------------"
#  Una pagina que difiere es una pagina mal subida, tenga o no query por ahi.
printf 'body{color:red}\n' > "$T/repo/styles.css"
cp "$T/repo/styles.css" "$T/servido/styles.css"
cp "$T/repo/styles.css" "$T/servido/_sellado/styles.css"
portada "?v=nuevo" > "$T/repo/index.html"
printf '<!doctype html><html><body><h1>OTRA COSA</h1></body></html>\n' > "$T/servido/index.html"
cp "$T/repo/index.html" "$T/servido/_sellado/index.html"
sella
r "portada distinta: FALLA"                  1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "y lo llama DISTINTO"                 "DISTINTO"
no_contiene "la excepcion no toca las paginas" "SELLADO-OK"

echo
echo "==============================================================================="
printf '  OK %d  ·  MAL %d\n' "$OK" "$MAL"
echo "==============================================================================="
[ "$MAL" -eq 0 ] || exit 1
exit 0
