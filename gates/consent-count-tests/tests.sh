#!/bin/sh
# =============================================================================
#  Bench for consent-count.php — the anonymous accept/reject counter
# =============================================================================
#  3-nov-2026. The receiver is copied to `_deploy/consent-count.php` of each
#  site. Like form-handler.php, nothing on this machine runs PHP, so it runs on
#  the measurement host: `php -l`, then the real thing behind `php -S`, hit with
#  curl. What it must never do is write anything about the person, or the order
#  the choices came in: every row on disk is checked to be exactly «date TAB
#  accept TAB reject TAB partial», three totals, with no time (6-nov-2026).
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

# Its own folder per run (the pid): two runs at once on the shared host must not
# delete each other's server and files.
REM="$(ssh "$HOST" 'echo $HOME' </dev/null 2>/dev/null)/.cc-pruebas-$$"
ssh "$HOST" "rm -rf $REM && mkdir -p $REM/www $REM/datos" </dev/null >/dev/null 2>&1
scp -q "$CC" "$HOST:$REM/www/consent-count.php" </dev/null
# A free port, the server in the background, and its pid to stop it at the end.
# With workers (PHP_CLI_SERVER_WORKERS): alone, `php -S` serves one request at a
# time, and the twenty-at-once case below would never test the lock.
PORT=$(( 20000 + $$ % 20000 ))
ssh "$HOST" "cd $REM/www || exit 1; CONSENT_DIR=$REM/datos PHP_CLI_SERVER_WORKERS=8 nohup php -S 127.0.0.1:$PORT </dev/null >/dev/null 2>&1 & echo \$! > $REM/pid" </dev/null >/dev/null 2>&1
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

# The format of a data row: «date TAB accept TAB reject TAB partial», three whole numbers.
# The header row starts with «#». Anything else on disk is a defect.
T="$(printf '\t')"
FILA="^[0-9]{4}-[0-9]{2}-[0-9]{2}${T}[0-9]+${T}[0-9]+${T}[0-9]+\$"
HOY="\$(TZ=Europe/Madrid date +%F)"

echo
echo "== LO QUE CUENTA"
comp "aceptar: 204"                                    "$CURL -d e=accept" "204"
comp "rechazar: 204"                                   "$CURL -d e=reject" "204"
comp "parcial: 204"                                    "$CURL -d e=partial" "204"
comp "una sola fila para hoy, no una por eleccion"     "grep -vc '^#' datos/consent-*.tsv" "1"
comp "y lleva uno de cada: aceptan, rechazan, parcial" "grep \"^$HOY${T}\" datos/consent-*.tsv | cut -f2- | tr '${T}' ' '" "1 1 1"

echo
echo "== LO QUE NO CUENTA"
comp "una eleccion inventada: 400"                     "$CURL -d e=hola" "400"
comp "sin eleccion: 400"                               "$CURL -d x=1" "400"
comp "un GET: 405"                                     "curl -s -o /dev/null -w %{http_code} http://127.0.0.1:$PORT/consent-count.php?e=accept" "405"
comp "y ninguno de los tres sumo nada"                 "grep \"^$HOY${T}\" datos/consent-*.tsv | cut -f2- | tr '${T}' ' '" "1 1 1"

echo
echo "== NADA DE LA PERSONA, NI EL ORDEN"
# 6-nov-2026 · Until today the file kept one line per choice, in the order they
# arrived, and the server's access log keeps the IP and the time of every POST in
# that same order: line N was request N, so each IP's choice could be read back.
ssh "$HOST" "cd $REM && $CURL -d 'e=accept&ip=203.0.113.9&page=/contacto&ua=Mozilla' -H 'User-Agent: Mozilla/5.0 Prueba' -H 'Cookie: _ga=GA1.1.1' >/dev/null" </dev/null 2>/dev/null
comp "cada fila es «fecha y tres totales», sin hora"   "grep -v '^#' datos/consent-*.tsv | grep -cvE '$FILA'" "0"
comp "ni la IP, ni la pagina, ni el navegador"         "grep -cE '203\.0\.113|127\.0\.0\.1|contacto|Mozilla|GA1' datos/consent-*.tsv" "0"
comp "la fecha es la de hoy en Madrid, con su suma"    "grep \"^$HOY${T}\" datos/consent-*.tsv | cut -f2- | tr '${T}' ' '" "2 1 1"
comp "veinte a la vez: no se pierde ninguna (el cerrojo)" \
     "for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do $CURL -d e=reject >/dev/null & done; wait; grep \"^$HOY${T}\" datos/consent-*.tsv | cut -f2- | tr '${T}' ' '" "2 21 1"

echo
echo "== UN FICHERO DEL FORMATO VIEJO (una linea por eleccion) se suma y pierde el orden"
ssh "$HOST" "cd $REM && f=datos/consent-\$(TZ=Europe/Madrid date +%Y-%m).tsv && printf '%s\taccept\n%s\treject\n%s\taccept\n' $HOY $HOY $HOY > \$f" </dev/null 2>/dev/null
comp "la primera eleccion despues: 204"                "$CURL -d e=partial" "204"
comp "las tres viejas y la nueva, en una fila"         "grep \"^$HOY${T}\" datos/consent-*.tsv | cut -f2- | tr '${T}' ' '" "2 1 1"
comp "y no queda ninguna linea del formato viejo"      "grep -v '^#' datos/consent-*.tsv | grep -cvE '$FILA'" "0"

echo
echo "== CONTROLES DE QUE ESTE BANCO SABE PONERSE ROJO"
ssh "$HOST" "cd $REM && printf '<?php\nfunction rota( {\n' > rota.php" </dev/null 2>/dev/null
comp "un fichero roto SI lo caza php -l"               "php -l rota.php" "syntax error"
# A receiver that wrote the time, or still wrote one line per choice, would fail the
# format check above: prove that check can see both.
ssh "$HOST" "cd $REM && printf '2026-11-03T10:00:00\t1\t0\t0\n2026-11-03\taccept\n' > malas.tsv" </dev/null 2>/dev/null
comp "una fila con hora y una del formato viejo: las dos" "grep -v '^#' malas.tsv | grep -cvE '$FILA'" "2"

# The workers outlive their parent's pid: stop everything listening on this run's port.
ssh "$HOST" "kill \$(cat $REM/pid) 2>/dev/null; pkill -f 'php -S 127.0.0.1:$PORT' 2>/dev/null; rm -rf $REM" </dev/null >/dev/null 2>&1
echo
echo "  OK $OK · MAL $MAL"
[ "$MAL" -eq 0 ] || exit 1
exit 0
