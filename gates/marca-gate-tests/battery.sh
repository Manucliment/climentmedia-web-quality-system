#!/usr/bin/env bash
# =============================================================================
#  BANCO DE `marca-gate.js`  ·  1-nov-2026
# =============================================================================
#
#  Se mide en el servidor, como el de `mobile-gate.js` (en Windows Chrome clampa
#  el ancho), y en modo CANDIDATO de `run-gate.js`: las fixturas se sirven del
#  disco con un origen de verdad. Sobre `file://` el gate no podria pedir el
#  manifest (fetch no lee file://) y todo icono saldria «no carga»: un banco
#  que acusa por el arnes no prueba nada.
#
#  QUE CUBRE: cada regla en rojo y en verde, y los casos que impiden que una
#  regla se ensanche hasta no decir nada o se apague sin que se vea:
#    B1  sin marca (FALLA) · logo (PASA) · marca hecha con texto (PASA con aviso)
#    B2  sin SVG (y sin logo en vector: AVISO, con sus 3 que siguen en FALLA) · sin 32 · un PNG de 48 vale · uno de 16 no · sin apple · apple
#        declarado que no carga · sin manifest · manifest sin 512 · manifest que
#        no es JSON
#    B3  sin theme-color
#    B4  un color fuera (FALLA) · el mismo color de la paleta escrito como rgb()
#        y como oklch() (PASA: no es otro color) · un widget de un tercero, con y
#        sin `ignorar`
#    B5  un tipo fuera
#    y sin configuracion: B4 y B5 NO MEDIDO, dicho, y PASA solo por lo demas.
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
REMOTO="/tmp/gate-marca-fixtures"
SITIO="https://marca.invalid"
PAL='{"colores":["#1a1a2e","#ffffff","#c2410c","#f5f0e8"],"tipos":["Inter"],"marca":"Una marca"}'
OK=0; MAL=0

ssh "$HOST" "rm -rf $REMOTO && mkdir -p $REMOTO" >/dev/null 2>&1 || {
  echo "  NO SE PUEDE MEDIR: sin acceso a $HOST. Esto NO es un aprobado."; exit 3; }
scp -q "$D/fixtures/"* "$HOST:$REMOTO/" || { echo "  fallo al copiar fixtures"; exit 2; }
scp -q "$REF/marca-gate.js" "$HOST:webtools/marca-gate.js" || { echo "  fallo al copiar el gate"; exit 2; }
scp -q "$REF/run-gate.js" "$HOST:webtools/run-gate.js" || { echo "  fallo al copiar el corredor"; exit 2; }

# res <id> <fixtura> <VEREDICTO esperado> [subcadena que DEBE aparecer] [cfg]   (cfg vacio = la paleta)
# El tamano es 1366x768 salvo que se pida otro delante:  TAM="390 844" res ...
res() {
  local id="$1" fx="$2" esp="$3" debe="${4:-}" cfg="${5-$PAL}"
  local j v iw n
  j=$(ssh "$HOST" "cd ~/webtools && GATE_CANDIDATO='$REMOTO' GATE_SITIO='$SITIO' node run-gate.js '$SITIO/$fx' ${TAM:-1366 768} marca-gate.js ${cfg:+'$cfg'}" 2>/dev/null)
  n=$(printf '%s' "$j" | head -1 | grep -o '"candidato":[0-9]*' | grep -o '[0-9]*$')
  j=$(printf '%s' "$j" | tail -n +2)
  v=$(printf '%s' "$j"  | grep -o '"VEREDICTO": "[A-Z]*"' | grep -o 'PASA\|FALLA')
  iw=$(printf '%s' "$j" | grep -o '"coincide": [a-z]*' | grep -o 'true\|false')
  local estado="OK" motivo=""
  if [ "${n:-0}" = 0 ]; then estado="MAL"; motivo="no se sirvio del disco (candidato=0): lo medido no es la fixtura"
  elif [ "${iw:-x}" != "true" ]; then estado="MAL"; motivo="coincide=$iw (ancho clampado o pagina no cargada)"
  elif [ "${v:-x}" != "$esp" ]; then estado="MAL"; motivo="esperaba $esp, obtuvo ${v:-SIN-VEREDICTO}"
  elif [ -n "$debe" ] && ! printf '%s' "$j" | grep -q -- "$debe"; then estado="MAL"; motivo="falta en el informe: «$debe»"
  fi
  if [ "$estado" = OK ]; then OK=$((OK+1)); else MAL=$((MAL+1)); printf '%s\n' "$j" | grep -A4 '"fallos"' | head -5 | sed 's/^/        /'; fi
  printf "  %-20s | esp %-5s | obt %-5s | %-3s | iw=%-5s %s\n" "$id" "$esp" "${v:-—}" "$estado" "${iw:-—}" "$motivo"
}

echo "=========== B1 · la marca en la cabecera ==========="
res VERDE          verde.html          PASA
TAM="390 844" res VERDE-390 verde.html PASA
res SIN-LOGO       sin-logo.html       FALLA 'B1 · sin marca en la cabecera'
res LOGO-TEXTO     logo-texto.html     PASA  'hecha con texto y CSS'
echo
echo "=========== B2 · los iconos, declarados y que cargan ==========="
res SIN-SVG        sin-svg.html        FALLA 'B2 · sin icono SVG'
# 2-nov: sin logo en vector (logoVector:false, logo de la cabecera en PNG), el SVG que falta es AVISO. Y que no se
# ensanche: sin la clave, con el logo en vector en el repo o con un logo SVG en la cabecera, sigue en FALLA.
res SVG-SIN-VECTOR sin-svg-raster.html PASA  'no tiene el logo en vector' '{"colores":["#1a1a2e","#ffffff","#c2410c","#f5f0e8"],"tipos":["Inter"],"marca":"Una marca","logoVector":false}'
res SVG-SIN-CLAVE  sin-svg-raster.html FALLA 'B2 · sin icono SVG'
res SVG-CON-VECTOR sin-svg-raster.html FALLA 'B2 · sin icono SVG' '{"colores":["#1a1a2e","#ffffff","#c2410c","#f5f0e8"],"tipos":["Inter"],"marca":"Una marca","logoVector":true}'
res SVG-LOGO-SVG   sin-svg.html        FALLA 'B2 · sin icono SVG' '{"colores":["#1a1a2e","#ffffff","#c2410c","#f5f0e8"],"tipos":["Inter"],"marca":"Una marca","logoVector":false}'
res SIN-32         sin-32.html         FALLA 'B2 · sin icono PNG o .ico de 32'
# Un sitio real servia su icono en un PNG de 48: vale (el navegador lo reduce). Uno de 16, no.
res ICONO-48       icono-48.html       PASA
res ICONO-16       icono-16.html       FALLA 'B2 · sin icono PNG o .ico de 32'
res SIN-APPLE      sin-apple.html      FALLA 'B2 · sin apple-touch-icon'
res APPLE-ROTO     apple-roto.html     FALLA 'declarado y NO carga'
res SIN-MANIFEST   sin-manifest.html   FALLA 'B2 · sin manifest'
res MANIF-SIN-512  manifest-sin-512.html FALLA 'no nombra un icono de 512x512'
res MANIF-ROTO     manifest-roto.html  FALLA 'no se lee como JSON'
echo
echo "=========== B3 · theme-color ==========="
res SIN-TEMA       sin-tema.html       FALLA 'B3 · sin <meta name=\\"theme-color\\">'
echo
echo "=========== B4 y B5 · nada fuera de la marca ==========="
res COLOR-FUERA    color-fuera.html    FALLA 'B4 · 1 color(es) fuera de la paleta'
res COLOR-FORMAS   color-otra-forma.html PASA
res TIPO-FUERA     tipo-fuera.html     FALLA 'B5 · 1 tipo(s) fuera de la marca'
res WIDGET         widget.html         FALLA '#00a2ff'
res WIDGET-IGNORA  widget.html         PASA  '' '{"colores":["#1a1a2e","#ffffff","#c2410c","#f5f0e8"],"tipos":["Inter"],"ignorar":["#chat-widget"]}'
echo
echo "=========== Sin configuracion: no se mide, y se dice ==========="
res SIN-CFG        color-fuera.html    PASA  'B4 · NO MEDIDO' ''
echo
ssh "$HOST" "rm -rf $REMOTO" >/dev/null 2>&1
echo "  $OK OK · $MAL MAL"
[ "$MAL" = 0 ] && exit 0 || exit 1
