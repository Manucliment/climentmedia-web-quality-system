#!/usr/bin/env bash
# =============================================================================
#  BANCO DE `huellas-gate.js`  ·  7-nov-2026
# =============================================================================
#
#  Se mide en el servidor, como el de `visible-gate.js` (en Windows Chrome clampa
#  el ancho), y en modo CANDIDATO de `run-gate.js`: las fixturas se sirven del
#  disco con un origen de verdad. Las fixturas las escribe un generador, pero son
#  HTML a la vista: cada una es un caso, y su nombre dice cual.
#
#  QUE CUBRE: cada regla en rojo y en verde, y lo que impide que se ensanche
#  hasta no decir nada o se apague sin que se vea:
#    HU1  cuatro antetitulos en cinco h2 (FALLA) · dos en cinco (PASA, con AVISO) ·
#         el de encima del H1 (PASA: lleva un dato) · mayusculas sin espaciar (PASA) ·
#         los mismos en una seccion con opacity 0 que nunca aparece (FALLA: el CSS es
#         el mismo, y no mirar la opacidad es a proposito) · cinco secciones con
#         antetitulo entre quince tarjetas en h3 (FALLA: sobre h2 y h3 juntos eran 5
#         de 20 y pasaba) · seis tarjetas con su etiqueta encima del h3 (PASA, con
#         la nota: sobre h2 y h3 juntos eran 6 de 8 y fallaba)
#    HU2  el texto en degradado (FALLA) · un degradado de fondo (PASA)
#    HU3  el borde de un lado a la izquierda y arriba (FALLA) · la cita sin radio, la
#         caja con borde entero, el borde de 1 px, la celda de tabla y el enlace del
#         menu (PASA)
#    HU4  el halo en rgba y en oklch (FALLA) · la sombra gris, el anillo sin
#         difuminado, la sombra inset y la doble sombra gris de una tarjeta (PASA)
#    HU5  transition: all con duracion (PASA, con AVISO)
#    HU6  un parrafo a 1,15 (FALLA) · a 1,6, una linea corta a 1 y un titulo a 1,05
#         (PASA: solo el texto corrido de dos lineas)
#    HU7  un h2 cuya ultima linea es una palabra sola (PASA, con AVISO) · con
#         text-wrap: balance, partido con <br> o con las lineas parejas (PASA)
#    HU8  el pattern de 9 cifras, el maxlength de 9 y el script que se come las cifras
#         (FALLA) · el que reescribe los espacios y el placeholder de mascara (PASA,
#         con AVISO) · el campo de telefono normal y un campo «hotel» de 5 (PASA)
#    y lo que no se cuenta: el aviso de cookies con su halo, su borde y su
#    transicion (PASA) · un <body> con `has-consent` que NO es un aviso (FALLA) ·
#    una pagina limpia (PASA, con todo a 0 y la nota de lo que no mide).
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
REMOTO="/tmp/gate-huellas-fixtures"
SITIO="https://huellas.invalid"
OK=0; MAL=0

ssh "$HOST" "rm -rf $REMOTO && mkdir -p $REMOTO" >/dev/null 2>&1 || {
  echo "  NO SE PUEDE MEDIR: sin acceso a $HOST. Esto NO es un aprobado."; exit 3; }
scp -q "$D/fixtures/"* "$HOST:$REMOTO/" || { echo "  fallo al copiar fixtures"; exit 2; }
# El gate va a una carpeta propia del banco: ~/webtools/gates/ es la copia que usa la puerta.
ssh "$HOST" "mkdir -p ~/webtools/banco-huellas" >/dev/null 2>&1
# GATE_HUELLAS=<fichero> mide otra copia del gate (un mutante, para ver en rojo lo que el banco dice
# proteger); SOLO=<regex> corre solo los casos cuyo id casa.
scp -q "${GATE_HUELLAS:-$REF/huellas-gate.js}" "$HOST:webtools/banco-huellas/huellas-gate.js" || { echo "  fallo al copiar el gate"; exit 2; }
scp -q "$REF/run-gate.js" "$HOST:webtools/run-gate.js" || { echo "  fallo al copiar el corredor"; exit 2; }

# res <id> <fixtura> <VEREDICTO esperado> [subcadena que DEBE aparecer] [subcadena que NO debe aparecer]
# El tamano es 1366x768 salvo que se pida otro delante:  TAM="390 844" res ...
res() {
  local id="$1" fx="$2" esp="$3" debe="${4:-}" nodebe="${5:-}"
  local j v iw n
  [ -n "${SOLO:-}" ] && ! printf '%s' "$id" | grep -qE "$SOLO" && return 0
  j=$(ssh "$HOST" "cd ~/webtools && GATE_CANDIDATO='$REMOTO' GATE_SITIO='$SITIO' node run-gate.js '$SITIO/$fx' ${TAM:-1366 768} banco-huellas/huellas-gate.js" 2>/dev/null)
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

echo "=========== HU1 · el antetitulo encima de cada titulo ==========="
res ANTETITULOS        antetitulos.html          FALLA 'HU1 · 4 de 5 titulos de seccion (h2)'
TAM="390 844" res ANTETITULOS-390 antetitulos.html FALLA 'HU1 · 4 de 5 titulos de seccion (h2)'
res ANTETITULO-H1      antetitulo-h1.html        PASA  '"conAntetitulo": 0' 'HU1 · '
res ANTETITULO-DOS     antetitulo-dos.html       PASA  'HU1 · 2 de 5 titulos de seccion (h2) con antetitulo'
res SIN-TRACKING       antetitulo-sin-tracking.html PASA '"conAntetitulo": 0'
res REVEAL             antetitulo-reveal.html    FALLA 'HU1 · 3 de 3 titulos de seccion (h2)'
res ENTRE-TARJETAS     antetitulos-entre-tarjetas.html FALLA 'HU1 · 5 de 5 titulos de seccion (h2)'
res ETIQUETAS-TARJETA  etiquetas-de-tarjeta.html PASA  'Antetitulos encima de un h3: 6 de 6' 'HU1 · '
echo
echo "=========== HU2 a HU5 · degradado, borde de un lado, halo y transition: all ==========="
res DEGRADADO          degradado.html            FALLA 'HU2 · 1 texto(s) en degradado'
res DEGRADADO-FONDO    degradado-fondo.html      PASA  '"degradados": 0'
res BORDE-LADO         borde-lado.html           FALLA '(4 px a la izquierda, radio 12 px)'
res BORDE-ARRIBA       borde-arriba.html         FALLA '(4 px arriba, radio 10 px)'
res BORDES-BIEN        bordes-bien.html          PASA  '"bordesDeUnLado": 0'
res HALO               halo.html                 FALLA 'HU4 · 1 elemento(s) con un halo de color'
TAM="390 844" res HALO-390 halo.html             FALLA 'HU4 · 1 elemento(s) con un halo de color'
res HALO-OKLCH         halo-oklch.html           FALLA 'HU4 · 1 elemento(s) con un halo de color'
res SOMBRAS-BIEN       sombras-bien.html         PASA  '"halos": 0'
res TRANSITION-ALL     transition-all.html       PASA  'HU5 · 2 elemento(s) con transition: all'
echo
echo "=========== HU6 y HU7 · la lectura ==========="
res APRETADO           apretado.html             FALLA 'HU6 · 1 bloque(s) de texto corrido con el interlineado por debajo de 1.3: p.apretado (1.15'
res INTERLINEADO-BIEN  interlineado-bien.html    PASA  '"parrafosApretados": 0'
res COLA               cola.html                 PASA  'HU7 · 1 titulo(s) acaban con una palabra sola o casi'
res COLA-BIEN          cola-bien.html            PASA  '"conPalabraSola": 0' 'HU7 · '
echo
echo "=========== HU8 · el telefono con mascara ==========="
res TEL-PATTERN        tel-pattern.html          FALLA 'no acepta +34 600 12 34 56'
res TEL-MAXLENGTH      tel-maxlength.html        FALLA 'maxlength 9'
res TEL-COME           tel-come.html             FALLA 'se come cifras'
res TEL-REESCRIBE      tel-reescribe.html        PASA  'queda «+34-600-12-34-56»'
res TEL-PLACEHOLDER    tel-placeholder.html      PASA  'placeholder de mascara'
res TEL-BIEN           tel-bien.html             PASA  '"camposDeTelefono": 1' 'campo(s) de telefono'
res TEL-BIEN-NADA      tel-bien.html             PASA  '"reescriben": 0'
echo
echo "=========== lo que no es de la pagina, y la pagina limpia ==========="
res AVISO-COOKIES      aviso-cookies.html        PASA  '"halos": 0' 'HU5 · '
res BODY-CONSENT       body-consent.html         FALLA 'HU4 · 1 elemento(s) con un halo de color'
res LIMPIA             limpia.html               PASA  '"avisos": []'
res LIMPIA-NOTA        limpia.html               PASA  'NO mide hover ni foco'
echo
ssh "$HOST" "rm -rf $REMOTO ~/webtools/banco-huellas" >/dev/null 2>&1
echo "  $OK OK · $MAL MAL"
[ "$MAL" = 0 ] && exit 0 || exit 1
