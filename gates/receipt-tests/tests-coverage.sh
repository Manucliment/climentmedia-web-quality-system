#!/usr/bin/env bash
# =============================================================================
#  tests-coverage.sh · G11 se mide a SI MISMO antes de opinar de la web
# =============================================================================
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/receipt-tests/tests-coverage.sh"
#
#  EL FALLO QUE ESTAS PRUEBAS EXISTEN PARA QUE NO VUELVA
#  ----------------------------------------------------
#  El 10-ago-2026, contra shop.site-b.example:
#      G11 · identicos 0 · distintos 0 · no hallados 95        exit 0
#  El gate no habia comparado NI UN FICHERO —le devolvian 403 a todo— y quien
#  lo lanzo se llevo un aprobado. Dos fallos en uno:
#    · la causa: `curl --compressed` sin cabecera `Accept` (mod_security de
#      Hostinger). Estaba diagnosticado en crawl-links.pl:85 y receipt.pl
#      culpaba al User-Agent, que no tenia nada que ver.
#    · el agujero de fondo: **«N de N no hallado» salia por la misma puerta que
#      «todo correcto»**. Un gate que no ha medido nada no esta diciendo que la
#      web este bien: esta diciendo que EL no funciona.
#
#  Por eso aqui se fabrica el 403 de site-b en 127.0.0.1: el arreglo se prueba
#  sin volver a medir una web de cliente con leads reales, y la prueba seguira
#  ahi cuando nadie se acuerde de por que.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
REF="$(cd .. && pwd)"
T="${TEMP:-/tmp}/cobertura-pruebas-$$"
PUERTO=$(( 8400 + ($$ % 900) ))
MUERTO=$(( 8400 + (($$ + 371) % 900) ))
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

rm -rf "$T"; mkdir -p "$T/repo" "$T/servido"
for n in index styles a b c; do printf 'contenido de %s\n' "$n" > "$T/repo/$n.html"; done
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
sella

echo "==============================================================================="
echo "  COBERTURA DE G11 (127.0.0.1, ninguna web viva)"
echo "==============================================================================="

echo
echo "-- 0 · CONTROL POSITIVO: todo servido -----------------------------------------"
r "G11 compara y pasa"                      0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "y DICE cuantos comparo"             "COMPARADOS 5"

echo
echo "-- 1 · EL CASO SITE-B: 403 a la huella de curl -------------------------------
     (el servidor rechaza la huella exacta de \`curl --compressed\`, como el WAF
      de Hostinger. Si baja() dejara de mandar su -H Accept, esto volveria a
      ser «5 de 5 no hallado». VERIFICADO quitando el arreglo: la prueba se
      pone en ROJO —ver la cabecera de test-server.pl)"
printf 'x\n' > "$T/servido/_huella-curl.txt"
# primero: que el 403 fabricado DISCRIMINE de verdad, no que rechace a todos
CODE_HUELLA="$(curl -sS -L --compressed -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PUERTO/a.html")"
CODE_ARREGLO="$(curl -sS -L --compressed -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PUERTO/a.html")"
if [ "$CODE_HUELLA" = "403" ] && [ "$CODE_ARREGLO" = "200" ]; then
  OK=$((OK+1)); printf '  PASA  %-52s (huella %s · con Accept %s)\n' "el 403 fabricado discrimina" "$CODE_HUELLA" "$CODE_ARREGLO"
else
  MAL=$((MAL+1)); printf '  FALLA %-52s (huella %s · con Accept %s)\n' "el 403 fabricado NO discrimina" "$CODE_HUELLA" "$CODE_ARREGLO"
fi
r "con la cabecera Accept: sigue comparando" 0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "compara los 5"                      "COMPARADOS 5"
contiene "y no hay nada negado"               "negados 0"
rm -f "$T/servido/_huella-curl.txt"

echo
echo "-- 2 · NEGATIVO: el gate no compara NADA (403 a todo) -------------------------
     🔴 Esto es lo que salia con exit 0. Ahora sale con 2."
printf '%s\n' index.html styles.html a.html b.html c.html > "$T/servido/_403.txt"
r "0 comparados = FALLO DEL GATE, no aprobado" 2 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "lo dice como lo que es"             "NO HA COMPARADO NI UN FICHERO"
contiene "y no lo llama aprobado"             "NUNCA es un aprobado"
contiene "enseña los codigos"                 "403 x5"
contiene "y apunta a la causa conocida"       "Accept"
rm -f "$T/servido/_403.txt"

echo
echo "-- 3 · NEGATIVO: mas rechazos que medidas (cobertura no fiable) ---------------"
printf '%s\n' styles.html a.html b.html c.html > "$T/servido/_403.txt"
r "1 comparado y 4 negados: exit 2"         2 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "lo llama por su nombre"             "COBERTURA NO FIABLE"
contiene "y no lo da por bueno"               "no es un aprobado"
rm -f "$T/servido/_403.txt"

echo
echo "-- 4 · CONTROL: pocos negados NO son un rojo ----------------------------------
     (una web puede negar .htaccess o /api/*.php con toda la razon: el gate no
      puede volverse rojo por eso o se apaga en una semana)"
printf '%s\n' c.html > "$T/servido/_403.txt"
r "4 comparados y 1 negado: sigue en verde"  0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "pero lo cuenta aparte"              "negados 1"
contiene "y avisa de que no es un aprobado"   "NO es un aprobado"
rm -f "$T/servido/_403.txt"

echo
echo "-- 5 · NEGATIVO: no hay nadie escuchando (SITIO equivocado) -------------------"
r "sin servidor: exit 2, no exit 0"         2 perl "$REF/receipt.pl" --servido --repo "$T/repo" \
                                                --sitio "http://127.0.0.1:$MUERTO"
contiene "no se lo inventa"                   "NO HA COMPARADO NI UN FICHERO"

echo
echo "-- 6 · NEGATIVO: nada subido (404 a todo) -------------------------------------
     (0 comparados tambien cuando la causa es que el arbol no esta)"
mkdir -p "$T/vacio"
kill $SRV 2>/dev/null; sleep 1
perl "$REF/receipt-tests/test-server.pl" "$T/vacio" "$MUERTO" >"$T/srv2.log" 2>&1 &
SRV=$!
sleep 1
r "arbol sin subir: exit 2"                 2 perl "$REF/receipt.pl" --servido --repo "$T/repo" \
                                                --sitio "http://127.0.0.1:$MUERTO"
contiene "y dice que no ha medido"            "NO HA COMPARADO NI UN FICHERO"
contiene "con los codigos a la vista"         "404"

echo
echo "-- 7 · la cache NO puede guardar un error como si fuera una pagina ------------
     (curl escribe el cuerpo del 403 en el mismo fichero, y la cache devolvia
      «200» de oficio: un DISTINTO inventado en la corrida siguiente)"
kill $SRV 2>/dev/null; sleep 1
perl "$REF/receipt-tests/test-server.pl" "$T/servido" "$MUERTO" >"$T/srv3.log" 2>&1 &
SRV=$!
sleep 1
printf '%s\n' a.html > "$T/servido/_403.txt"
perl "$REF/receipt.pl" --servido --repo "$T/repo" --sitio "http://127.0.0.1:$MUERTO" \
     --cache "$T/cache" >/dev/null 2>&1
rm -f "$T/servido/_403.txt"
NCACHE=$(ls "$T/cache" 2>/dev/null | wc -l)
r "segunda corrida: ni un DISTINTO inventado" 0 perl "$REF/receipt.pl" --servido --repo "$T/repo" \
                                                 --sitio "http://127.0.0.1:$MUERTO" --cache "$T/cache"
contiene "0 distintos"                        "distintos 0"
printf '  (la cache guardo %s ficheros: solo los 200)\n' "$NCACHE"

echo
echo "-- UNA LENTE QUE CORRIO Y NO MIDIO NADA NO ES «PASA» (§18, 13-ago-2026) ------"
# 🔴 EL DEFECTO: apuntando el gate a un puerto muerto con `--solo seo` salia
#    «[NO VERIF] SEO-00 la lente entera», `PASA 0` -ni una sola comprobacion
#    pasada- y aun asi `VEREDICTO: PASA`, exit 0, y el recibo sellaba
#    «LENTE-SEO: PASA». `--para-desplegar` acepta cualquier lente que diga PASA
#    o FALLA, asi que la puerta se lo tragaba por PASA, no por los huecos.
#    La trampa §18 llevaba abierta desde el 11-ago con la nota «NO he comprobado
#    si deploy.sh dejaria pasar un recibo asi». Esto es esa comprobacion.
NVREPO="$T/repo-lente-nv"
mkdir -p "$NVREPO/_deploy"; printf 'x\n' > "$NVREPO/index.html"
# ⚠️ NO se usa $MUERTO: deja de estar muerto en la linea 145, donde este mismo
#    banco arranca un servidor encima para probar el 403. Mi primera version lo
#    uso y el caso salio FALLA en vez de NO VERIFICADO -- la lente SI midio,
#    porque habia una web contestando. Un nombre no es una garantia: se COMPRUEBA
#    que no contesta nadie antes de medir, o el caso pasa o falla por otra razon.
NADIE=$(( 8400 + (($$ + 613) % 900) ))
if curl -sS -o /dev/null --max-time 2 "http://127.0.0.1:$NADIE" 2>/dev/null; then
  MAL=$((MAL+1)); printf '  FALLA %-52s (alguien contesta en %s)\n' "el puerto de control esta libre" "$NADIE"
else
  OK=$((OK+1)); printf '  PASA  %-52s (%s)\n' "el puerto de control no contesta" "$NADIE"
fi
perl "$REF/qa-master.pl" "http://127.0.0.1:$NADIE" --solo seo --repo "$NVREPO" \
     --una-sola >"$T/nv.txt" 2>&1
NVRC=$?
# 🔴 14-ago-2026 · Y EL CODIGO DE SALIDA, que era la mitad que faltaba (regla 10).
#    El veredicto ya lo decia desde el 13-ago, pero el programa salia 0: la
#    frase la lee una PERSONA y el exit lo lee TODO LO DEMAS -- un `&&`, un
#    script de despliegue, una tarea programada. Arreglar la frase y dejar el
#    numero es arreglar la mitad que se ve.
#    Sale 3 y no 1 a proposito: 1 es «medido y mal», 3 es «no medido». Mandar a
#    alguien a buscar un defecto que no existe cuesta una tarde.
if [ "$NVRC" = 3 ]; then
  OK=$((OK+1)); printf '  PASA  %-52s (exit 3)\n' "y sale != 0, no solo lo dice"
else
  MAL=$((MAL+1)); printf '  FALLA %-52s (exit %s, esperaba 3)\n' "y sale != 0, no solo lo dice" "$NVRC"
fi
LSEO="$(grep -m1 '^LENTE-SEO:' "$NVREPO/.qa-recibo" 2>/dev/null | sed 's/^LENTE-SEO:[[:space:]]*//')"
if [ "$LSEO" = "NO VERIFICADA" ]; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "el recibo NO la sella como PASA"
else
  MAL=$((MAL+1)); printf '  FALLA %-52s (LENTE-SEO: %s)\n' "el recibo NO la sella como PASA" "$LSEO"
fi
if grep -q 'lente SIN MEDIR' "$T/nv.txt"; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "el veredicto lo dice en su cara"
else
  MAL=$((MAL+1)); printf '  FALLA %-52s\n' "el veredicto lo dice en su cara"
  grep -m1 'VEREDICTO' "$T/nv.txt" | sed 's/^/          /'
fi
# Y la parte que de verdad protege: que la PUERTA lo rechace, y que lo diga
# BIEN -- «corrio y no midio» no es «no la has corrido», y confundirlos manda a
# arreglar lo que no es.
r "la puerta rechaza ese recibo"            1 perl "$REF/receipt.pl" --verificar --repo "$NVREPO" --para-desplegar
contiene "distingue no-medida de no-corrida"  "no midieron NADA: SEO"

echo
echo "==============================================================================="
printf "  %d PASA · %d FALLA\n" "$OK" "$MAL"
echo "==============================================================================="
[ "$MAL" = 0 ] || exit 1
