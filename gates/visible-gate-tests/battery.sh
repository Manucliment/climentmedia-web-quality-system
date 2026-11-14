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
#         emulacion de antes, «nearest», daba FALLA) · enlaces a 385 px, que hacia atras
#         asoman 15 px por arriba (FALLA: Chrome los lleva al borde, no al centro) · la barra de llamar fija abajo,
#         a 1366 y a 390 (FALLA) · el aviso de cookies (AVISO) · tapado en parte
#         (AVISO, no FALLA). Cada fixtura de VI2 se paso el 6-nov por Tab y Shift+Tab
#         DE VERDAD (puppeteer keyboard) en el mismo Chrome: mismo veredicto.
#    VI3  (7-nov) el anillo claro sobre blanco, a 1366 y a 390, el oscuro sobre una
#         seccion oscura, el escrito en oklch y el de una sombra al 30 % (FALLA) · el
#         oscuro sobre blanco, el par de dos tonos sobre oscuro y unos botones oscuros
#         pegados (PASA: el vecino no es el fondo) · el foco que no cambia nada (AVISO)
#         y el que cambia el fondo (PASA, contado aparte) · los campos de borde claro y
#         los rellenos casi blancos sin borde (FALLA) · el borde gris oscuro, la sombra
#         que hace de borde y el campo blanco en una caja oscura (PASA) · sobre un
#         degradado (PASA, NO MEDIDO dicho).
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
res ASOMA              foco-asoma.html         FALLA 'tapadas enteras por la cabecera fija (header, 141 px)'
res SCROLL-PADDING     foco-padding.html       PASA  '"tapadasEnteras": 0' 'quedan tapadas'
res BARRA              foco-barra.html         FALLA 'tapadas enteras por la barra fija de abajo (div.barra-llamar, 80 px)'
TAM="390 844" res BARRA-390 foco-barra.html    FALLA 'tapadas enteras por la barra fija de abajo (div.barra-llamar, 80 px)'
res COOKIES            foco-cookies.html       PASA  'por el aviso de cookies mientras esta abierto' 'tapadas enteras por la barra'
res PARCIAL            foco-parcial.html       PASA  'en mas de la mitad' 'tapadas enteras por'
echo
echo "=========== VI3 · el anillo de foco y el borde de los campos (WCAG 1.4.11) ==========="
res ANILLO-FLOJO       anillo-flojo.html       FALLA 'el anillo #9fd3e6 sobre #ffffff'
TAM="390 844" res ANILLO-FLOJO-390 anillo-flojo.html FALLA 'el anillo #9fd3e6 sobre #ffffff'
res ANILLO-BUENO       anillo-bueno.html       PASA  '"medidos": 4' 'parada(s) de Tab con el anillo'
res ANILLO-OSCURO      anillo-oscuro.html      FALLA 'sobre #10243e'
res DOS-TONOS          anillo-dos-tonos.html   PASA  '"medidos": 4' 'parada(s) de Tab con el anillo'
res OKLCH              anillo-oklch.html       FALLA 'parada(s) de Tab con el anillo'
res ALFA               anillo-alfa.html        FALLA 'al 30 % sobre #ffffff, 1.6'   # el lienzo da #1a4c8e y 1.68 (redondeo de la alfa); a mano, #1a4d8f y 1.67
res VECINOS            anillo-vecinos.html     PASA  '"medidos": 4' 'parada(s) de Tab con el anillo'
res SIN-CAMBIO         foco-sin-cambio.html    PASA  'no cambian nada al recibir el foco'
res OTRO-INDICADOR     foco-otro.html          PASA  'otra cosa que un anillo' 'no cambian nada'
res CAMPOS-FLOJOS      campos-flojos.html      FALLA '3 campo(s) del formulario no se distinguen'
res CAMPOS-BUENOS      campos-buenos.html      PASA  '"camposFlojos": 0' 'no se distinguen'
res CAMPOS-RELLENO     campos-relleno.html     FALLA 'campo(s) del formulario no se distinguen'
res CAMPOS-SOMBRA      campos-sombra.html      PASA  '"camposFlojos": 0' 'no se distinguen'
res CAMPOS-OSCURO      campos-oscuro.html      PASA  '"camposFlojos": 0' 'no se distinguen'
res CAMPOS-IMAGEN      campos-imagen.html      PASA  'sobre una imagen, un degradado' 'no se distinguen'
# 14-nov-2026 · el contorno lo lleva el envoltorio (quantity-selector-component de Horizon). Visto en ROJO contra el
# gate de antes (1:1). El espejo, la misma caja sin borde, sigue cayendo.
res CAMPOS-ENVOLTORIO  campos-envoltorio.html  PASA  '"camposPorEnvoltorio": 1' 'no se distinguen'
res CAMPOS-ENV-SIN-BORDE campos-envoltorio-sin-borde.html FALLA '1 campo(s) del formulario no se distinguen'
echo
ssh "$HOST" "rm -rf $REMOTO ~/webtools/banco-visible" >/dev/null 2>&1
echo "  $OK OK · $MAL MAL"
[ "$MAL" = 0 ] && exit 0 || exit 1
