#!/bin/sh
# =============================================================================
#  Bench for consent-count.php — the anonymous accept/reject counter
# =============================================================================
#  3-nov-2026. The receiver is copied to `_deploy/consent-count.php` of each
#  site. Like form-handler.php, nothing on this machine runs PHP, so it runs on
#  the measurement host: `php -l`, then the real thing behind `php -S`, hit with
#  curl. What it must never do is write anything about the person: every line
#  on disk is checked to be exactly «date TAB choice», with no time.
# =============================================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
REF="$(dirname "$DIR")"
. "$REF/nav-host.sh"
HOST="$(nav_host "$REF")"
if [ -z "$HOST" ]; then
  echo "BANCO · consent-count.php (php -l y ejecucion)"
  echo
  echo "  NO VERIFICADO · NAV_HOST sin configurar: ni el entorno ni"
  echo "  $(nav_host_conf "$REF") dicen desde donde medir."
  echo; echo "  NO MEDIDO (NAV_HOST sin configurar)"; exit 3
fi
CC="$REF/consent-count.php"
OK=0; MAL=0

echo "BANCO · consent-count.php (php -l y ejecucion) · en $HOST"
echo
if [ ! -f "$CC" ]; then
  echo "  MAL   no encuentro $CC"; echo; echo "  OK 0 · MAL 1"; exit 1
fi
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOST" 'command -v php >/dev/null && command -v curl >/dev/null' </dev/null 2>/dev/null; then
  echo "  NO VERIFICADO · no se llega a $HOST o no tiene php y curl"
  echo; echo "  NO MEDIDO (sin host con php)"; exit 3
fi

REM="$(ssh "$HOST" 'echo $HOME' </dev/null 2>/dev/null)/.cc-pruebas"
ssh "$HOST" "rm -rf $REM && mkdir -p $REM/www $REM/datos" </dev/null >/dev/null 2>&1
scp -q "$CC" "$HOST:$REM/www/consent-count.php" </dev/null
# A free port, the server in the background, and its pid to stop it at the end.
PORT=$(( 20000 + $$ % 20000 ))
ssh "$HOST" "cd $REM/www || exit 1; CONSENT_DIR=$REM/datos nohup php -S 127.0.0.1:$PORT </dev/null >/dev/null 2>&1 & echo \$! > $REM/pid" </dev/null >/dev/null 2>&1
ssh "$HOST" "for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -o /dev/null http://127.0.0.1:$PORT/ && exit 0; sleep 0.3; done" </dev/null >/dev/null 2>&1

comp () {                    # comp <title> <remote command> <pattern that MUST appear>
  t="$1"; orden="$2"; pat="$3"
  out="$(ssh "$HOST" "cd $REM && $orden" </dev/null 2>&1)"
  case "$out" in
    *"$pat"*) printf "  ok    %-56s\n" "$t"; OK=$((OK+1)) ;;
    *)        printf "  MAL   %-56s esperaba «%s»\n" "$t" "$pat"
              printf "        salio: %s\n" "$(printf '%s' "$out" | head -1)"; MAL=$((MAL+1)) ;;
  esac
}
CURL="curl -s -o /dev/null -w %{http_code} http://127.0.0.1:$PORT/consent-count.php"

echo "== EL FICHERO"
comp "parsea sin errores de sintaxis"                 "php -l www/consent-count.php" "No syntax errors"

echo
echo "== LO QUE CUENTA"
comp "aceptar: 204"                                    "$CURL -d e=accept" "204"
comp "rechazar: 204"                                   "$CURL -d e=reject" "204"
comp "parcial: 204"                                    "$CURL -d e=partial" "204"
comp "tres lineas en el fichero del mes"               "cat datos/consent-*.tsv | wc -l | tr -d ' '" "3"
comp "una de cada eleccion"                            "cut -f2 datos/consent-*.tsv | sort | tr '\n' ' '" "accept partial reject"

echo
echo "== LO QUE NO CUENTA"
comp "una eleccion inventada: 400"                     "$CURL -d e=hola" "400"
comp "sin eleccion: 400"                               "$CURL -d x=1" "400"
comp "un GET: 405"                                     "curl -s -o /dev/null -w %{http_code} http://127.0.0.1:$PORT/consent-count.php?e=accept" "405"
comp "y ninguno de los tres escribio nada"             "cat datos/consent-*.tsv | wc -l | tr -d ' '" "3"

echo
echo "== NADA DE LA PERSONA"
ssh "$HOST" "cd $REM && $CURL -d 'e=accept&ip=203.0.113.9&page=/contacto&ua=Mozilla' -H 'User-Agent: Mozilla/5.0 Prueba' -H 'Cookie: _ga=GA1.1.1' >/dev/null" </dev/null 2>/dev/null
comp "cada linea es «fecha TAB eleccion», sin hora"    "grep -cvE '^[0-9]{4}-[0-9]{2}-[0-9]{2}	(accept|reject|partial)\$' datos/consent-*.tsv" "0"
comp "ni la IP, ni la pagina, ni el navegador"         "grep -cE '203\.0\.113|127\.0\.0\.1|contacto|Mozilla|GA1' datos/consent-*.tsv" "0"
comp "la fecha es la de hoy en Madrid"                 "TZ=Europe/Madrid date +%F > hoy && grep -c -f hoy datos/consent-*.tsv" "4"

echo
echo "== CONTROLES DE QUE ESTE BANCO SABE PONERSE ROJO"
ssh "$HOST" "cd $REM && printf '<?php\nfunction rota( {\n' > rota.php" </dev/null 2>/dev/null
comp "un fichero roto SI lo caza php -l"               "php -l rota.php" "syntax error"
# A receiver that wrote the time would fail the format check above: prove that check can see it.
ssh "$HOST" "cd $REM && printf '2026-11-03T10:00:00\taccept\n' > hora.tsv" </dev/null 2>/dev/null
comp "una linea con hora SI la caza el formato"        "grep -cvE '^[0-9]{4}-[0-9]{2}-[0-9]{2}	(accept|reject|partial)\$' hora.tsv" "1"

ssh "$HOST" "kill \$(cat $REM/pid) 2>/dev/null; rm -rf $REM" </dev/null >/dev/null 2>&1
echo
echo "  OK $OK · MAL $MAL"
[ "$MAL" -eq 0 ] || exit 1
exit 0
