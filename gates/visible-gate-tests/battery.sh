#!/usr/bin/env bash
# =============================================================================
#  BANCO DE `visible-gate.js`  ·  6-nov-2026
# =============================================================================
#
#  Se mide en el servidor, como el de `botones-gate.js` (en Windows Chrome clampa
#  el ancho), y en modo CANDIDATO de `run-gate.js`: las fixturas se sirven del
#  disco con un origen de verdad.
#
#  QUE CUBRE: cada regla en rojo y en verde, y lo que impide que se ensanche
#  hasta no decir nada o se apague sin que se vea:
#    VI1  las apariciones que saltan al bajar (PASA) · la que mira otra clase y
#         la que no tiene script (FALLA) · visibility hidden (FALLA) · poco texto
#         (AVISO) · un h2 oculto aunque sea corto (FALLA) · la que solo salta tras
#         medio segundo a la vista (PASA: la segunda mirada, centrada, la ve) ·
#         lo oculto a proposito:
#         <details>, [hidden], aria-hidden, un carrusel, una pestana, un dialogo,
#         display:none, la capa de una tarjeta y el aviso de cookies (PASA) · un
#         <body> con `has-consent` (FALLA: el estado no es el aviso, y el 6-nov
#         eso apagaba una web entera en botones-gate)
#    VI2  con enlaces seguidos, la cabecera pegada sin scroll-padding (FALLA, y solo
#         hacia atras: hacia delante Chrome no deja nada debajo) y con el (PASA) · la
#         misma cabecera con enlaces separados (PASA: Chrome centra cada uno; la
#         emulacion de antes, «nearest», daba FALLA) · la barra de llamar fija abajo,
#         a 1366 y a 390 (FALLA) · el aviso de cookies (AVISO) · tapado en parte
#         (AVISO, no FALLA). Cada fixtura de VI2 se paso el 6-nov por Tab y Shift+Tab
#         DE VERDAD (puppeteer keyboard) en el mismo Chrome: mismo veredicto.
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
REF="$(cd "$D/.." && pwd)"
. "$REF/nav-host.sh"
HOST="${GATE_MOVIL_HOST:-$(nav_host "$REF")}"
if [ -z "$HOST" ]; then
  echo "  NO SE PUEDE MEDIR: NAV_HOST sin configurar (ni GATE_MOVIL_HOST, ni el"
  echo "  entorno, ni $(nav_host_conf "$REF")). Esto NO es un aprobado."
  exit 3
fi
REMOTO="/tmp/gate-visible-fixtures"
SITIO="https://visible.invalid"
OK=0; MAL=0

ssh "$HOST" "rm -rf $REMOTO && mkdir -p $REMOTO" >/dev/null 2>&1 || {
  echo "  NO SE PUEDE MEDIR: sin acceso a $HOST. Esto NO es un aprobado."; exit 3; }
scp -q "$D/fixtures/"* "$HOST:$REMOTO/" || { echo "  fallo al copiar fixtures"; exit 2; }
# El gate va a una carpeta propia del banco: ~/webtools/gates/ es la copia que usa la puerta.
ssh "$HOST" "mkdir -p ~/webtools/banco-visible" >/dev/null 2>&1
# GATE_VISIBLE=<fichero> mide otra copia del gate (un mutante, para ver en rojo lo que el banco dice
# proteger); SOLO=<regex> corre solo los casos cuyo id casa.
scp -q "${GATE_VISIBLE:-$REF/visible-gate.js}" "$HOST:webtools/banco-visible/visible-gate.js" || { echo "  fallo al copiar el gate"; exit 2; }
scp -q "$REF/run-gate.js" "$HOST:webtools/run-gate.js" || { echo "  fallo al copiar el corredor"; exit 2; }

# res <id> <fixtura> <VEREDICTO esperado> [subcadena que DEBE aparecer] [subcadena que NO debe aparecer]
# El tamano es 1366x768 salvo que se pida otro delante:  TAM="390 844" res ...
res() {
  local id="$1" fx="$2" esp="$3" debe="${4:-}" nodebe="${5:-}"
  local j v iw n
  [ -n "${SOLO:-}" ] && ! printf '%s' "$id" | grep -qE "$SOLO" && return 0
  j=$(ssh "$HOST" "cd ~/webtools && GATE_CANDIDATO='$REMOTO' GATE_SITIO='$SITIO' node run-gate.js '$SITIO/$fx' ${TAM:-1366 768} banco-visible/visible-gate.js" 2>/dev/null)
  n=$(printf '%s' "$j" | head -1 | grep -o '"candidato":[0-9]*' | grep -o '[0-9]*$')
  j=$(printf '%s' "$j" | tail -n +2)
  v=$(printf '%s' "$j"  | grep -o '"VEREDICTO": "[A-Z]*"' | grep -o 'PASA\|FALLA')
  iw=$(printf '%s' "$j" | grep -o '"coincide": [a-z]*' | grep -o 'true\|false')
  local estado="OK" motivo=""
  if [ "${n:-0}" = 0 ]; then estado="MAL"; motivo="no se sirvio del disco (candidato=0): lo medido no es la fixtura"
  elif [ "${iw:-x}" != "true" ]; then estado="MAL"; motivo="coincide=$iw (ancho clampado o pagina no cargada)"
  elif [ "${v:-x}" != "$esp" ]; then estado="MAL"; motivo="esperaba $esp, obtuvo ${v:-SIN-VEREDICTO}"
  elif [ -n "$debe" ] && ! printf '%s' "$j" | grep -qF -- "$debe"; then estado="MAL"; motivo="falta en el informe: «$debe»"
  elif [ -n "$nodebe" ] && printf '%s' "$j" | grep -qF -- "$nodebe"; then estado="MAL"; motivo="sobra en el informe: «$nodebe»"
  fi
  if [ "$estado" = OK ]; then OK=$((OK+1)); else MAL=$((MAL+1)); printf '%s\n' "$j" | grep -A6 '"fallos"\|"avisos"' | head -10 | sed 's/^/        /'; fi
  printf "  %-20s | esp %-5s | obt %-5s | %-3s | iw=%-5s %s\n" "$id" "$esp" "${v:-—}" "$estado" "${iw:-—}" "$motivo"
}

echo "=========== VI1 · lo que sigue invisible tras bajar y esperar ==========="
res APARECE            aparece.html            PASA  '"caracteresInvisibles": 0'
TAM="390 844" res APARECE-390 aparece.html     PASA  '"caracteresInvisibles": 0'
res APARECE-ROTO       aparece-roto.html       FALLA 'VI1 · '
res SIN-SCRIPT         sin-script.html         FALLA 'section.reveal'
res VISIBILITY         visibility.html         FALLA 'visibility hidden'
res POCO               poco.html               PASA  'VI1 · 52 caracteres del contenido siguen invisibles tras recorrer la pagina:'
res TITULO             titulo.html             FALLA 'con un titulo h1/h2'
res TARDE              tarde.html              PASA  '"caracteresInvisibles": 0'
res A-PROPOSITO        a-proposito.html        PASA  '"caracteresInvisibles": 0' 'siguen invisibles'
res BODY-CONSENT       body-consent.html       FALLA 'VI1 · '
echo
echo "=========== VI2 · el foco tapado por lo fijo ==========="
res CABECERA           foco-cabecera.html      FALLA 'tapadas enteras por la cabecera fija (header, 141 px)'
TAM="390 844" res CABECERA-390 foco-cabecera.html FALLA '"adelante": 0'
res ESPACIADA          foco-espaciada.html     PASA  '"tapadasEnteras": 0' 'quedan tapadas'
res SCROLL-PADDING     foco-padding.html       PASA  '"tapadasEnteras": 0' 'quedan tapadas'
res BARRA              foco-barra.html         FALLA 'tapadas enteras por la barra fija de abajo (div.barra-llamar, 80 px)'
TAM="390 844" res BARRA-390 foco-barra.html    FALLA 'tapadas enteras por la barra fija de abajo (div.barra-llamar, 80 px)'
res COOKIES            foco-cookies.html       PASA  'por el aviso de cookies mientras esta abierto' 'tapadas enteras por la barra'
res PARCIAL            foco-parcial.html       PASA  'en mas de la mitad' 'tapadas enteras por'
echo
ssh "$HOST" "rm -rf $REMOTO ~/webtools/banco-visible" >/dev/null 2>&1
echo "  $OK OK · $MAL MAL"
[ "$MAL" = 0 ] && exit 0 || exit 1
