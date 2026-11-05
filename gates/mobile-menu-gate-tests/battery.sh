#!/usr/bin/env bash
# =============================================================================
#  BANCO DE `mobile-menu-gate.js`  ·  1-nov-2026
# =============================================================================
#
#  Se mide en el SERVIDOR, por `run-gate.js` y sobre `file://`, por lo mismo que
#  el banco de `mobile-gate.js`: en Windows Chrome recorta el ancho a ~500 px, y
#  este gate es asincrono (pulsa el boton y espera a que el menu se abra).
#
#  QUE CUBRE: cada regla con un caso que pasa y uno que falla.
#    N1   una fila sin boton (verde)     · siete enlaces apilados (rojo)
#         marca e idiomas arriba, menu en una fila (verde) · el menu partido (rojo)
#    N1b  tira con scroll propio (verde) · un enlace cortado por el borde (rojo)
#    N2   boton con aria-expanded (verde) · el mismo sin el (rojo)
#    N3   el boton abre (verde)          · el JS no cargo y no abre (rojo)
#    N4   <details>/<summary> nativo (verde) · <div role=button> sin tabindex (rojo)
#    N5   cajon que se oculta al cerrar (verde) · cajon movido con transform, con
#         sus enlaces en el orden de Tab (rojo)
#    N6   capa encima que Escape cierra y devuelve el foco (verde) · capa encima sin
#         Escape (rojo) · cierra sin devolver el foco (verde con aviso) · menu que
#         empuja sin Escape (verde con aviso)
#    N7   foco atrapado en la capa (verde) · capa que se cierra al salir el foco
#         (verde) · enlaces antes que el boton y la pagina tapada (rojo, el caso
#         real) · lo tapa el aviso de cookies y no el menu (verde con aviso)
#    no medible  un cascaron vacio no se juzga
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
REF="$(cd "$D/.." && pwd)"
. "$REF/nav-host.sh"
HOST="$(nav_host "$REF")"
if [ -z "$HOST" ]; then
  echo "  NO SE PUEDE MEDIR: NAV_HOST sin configurar (ni el entorno, ni"
  echo "  $(nav_host_conf "$REF")). Esto NO es un aprobado."
  exit 3
fi
REMOTO="/tmp/gate-menu-fixtures"
OK=0; MAL=0

ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "rm -rf $REMOTO && mkdir -p $REMOTO" >/dev/null 2>&1 || {
  echo "  NO SE PUEDE MEDIR: sin acceso a $HOST. Esto NO es un aprobado."; exit 3; }
scp -q "$D/fixtures/"* "$HOST:$REMOTO/" </dev/null || { echo "  fallo al copiar fixtures"; exit 2; }
scp -q "$REF/mobile-menu-gate.js" "$HOST:webtools/mobile-menu-gate.js" </dev/null || { echo "  fallo al copiar el gate"; exit 2; }
scp -q "$REF/run-gate.js" "$HOST:webtools/run-gate.js" </dev/null || { echo "  fallo al copiar el corredor"; exit 2; }

# res <id> <fixtura> <VEREDICTO esperado> [subcadena que DEBE aparecer]
res() {
  local id="$1" fx="$2" esp="$3" debe="${4:-}"
  local j v iw estado="OK" motivo=""
  j=$(ssh -n "$HOST" "cd ~/webtools && node run-gate.js 'file://$REMOTO/$fx' 390 844 mobile-menu-gate.js" 2>/dev/null | tail -n +2)
  v=$(printf '%s' "$j"  | grep -o '"VEREDICTO": "[A-Z]*"' | grep -o 'PASA\|FALLA')
  iw=$(printf '%s' "$j" | grep -o '"coincide": [a-z]*' | grep -o 'true\|false')
  if [ "${iw:-x}" != "true" ]; then estado="MAL"; motivo="coincide=$iw (ancho clampado o pagina no cargada)"
  elif [ "${v:-x}" != "$esp" ]; then estado="MAL"; motivo="esperaba $esp, obtuvo ${v:-SIN-VEREDICTO}"
  elif [ -n "$debe" ] && ! printf '%s' "$j" | grep -q -- "$debe"; then
    estado="MAL"; motivo="falta en el informe: «$debe»"
  fi
  if [ "$estado" = OK ]; then OK=$((OK+1)); else MAL=$((MAL+1)); fi
  printf "  %-20s | esp %-5s | obt %-5s | %-3s | iw=%-5s %s\n" "$id" "$esp" "${v:-—}" "$estado" "${iw:-—}" "$motivo"
}

echo "=========== N1 · sin boton, una fila ==========="
res N1-verde       una-fila-verde.html      PASA  'caben en una fila'
res N1-rojo        dos-filas-rojo.html      FALLA 'N1 · los 6 enlaces del menu'
# 1-nov-2026 · el barrido de las webs publicadas: N1 contaba TODOS los enlaces de la
# cabecera y daba rojo a dos con el menu en una fila (marca e idiomas arriba, telefono
# abajo). Visto en rojo con la regla vieja antes de cambiarla. El gemelo tiene que seguir cayendo.
res N1-marca-verde marca-e-idiomas-verde.html PASA 'caben en una fila'
res N1-partido     menu-partido-rojo.html   FALLA 'N1 · los 4 enlaces del menu ocupan 2 filas'
echo "=========== N1b · nada cortado por el borde ==========="
res N1b-verde      tira-scroll-verde.html   PASA
res N1b-rojo       cortado-rojo.html        FALLA 'N1b ·'
echo "=========== N2 · aria-expanded ==========="
res N2-verde       boton-verde.html         PASA
res N2-rojo        boton-sin-aria-rojo.html FALLA 'N2 ·'
echo "=========== N3 · el boton abre ==========="
res N3-rojo        boton-no-abre-rojo.html  FALLA 'N3 · el boton de menu NO ABRE'
echo "=========== N4 · teclado y nombre ==========="
res N4-verde       details-verde.html       PASA
res N4-rojo        div-rol-rojo.html        FALLA 'N4 ·'
echo "=========== N5 · cerrado, fuera del orden de Tab (A11Y-13) ==========="
res N5-verde       cajon-inert-verde.html   PASA
res N5-rojo        cajon-tab-rojo.html      FALLA 'N5 ·'
echo "=========== N6 y N7 · con el menu ABIERTO: Tab y Escape (5-nov-2026) ==========="
# Una web nuestra PASABA con el cajon abierto mandando el foco a la pagina tapada
# (sus enlaces iban antes que el boton) y sin cerrarse con Escape. Los dos rojos
# salian PASA con el gate de antes; los dos arreglos validos tienen que pasar.
res N7-atrapa      capa-atrapa-verde.html          PASA  '"focoVuelveAlBoton": true'
res N7-cierra      capa-cierra-al-salir-verde.html PASA  'el menu se cierra al salir el foco'
res N7-rojo        capa-enlaces-antes-rojo.html    FALLA 'N7 · con el menu abierto, Tab lleva el foco a 3 elemento(s) de la pagina que no se ven: «Reservar cita», tapado por el menu'
res N6-rojo        capa-sin-escape-rojo.html       FALLA 'N6 · Escape no cierra el menu abierto, y el menu es modal (tapa el'
res N6-foco        capa-escape-sin-foco-verde.html PASA  'el foco no vuelve al boton'
res N6-empuja      details-verde.html              PASA  'Escape no cierra el menu abierto (no es modal'
# 5-nov · la primera version de N6 daba FALLA a todo menu «encima» (fixed): caia un
# desplegable de cabecera fija con la pagina a mano (una web nuestra). Modal, si; eso no.
res N6-fija        desplegable-cabecera-fija-verde.html PASA 'Escape no cierra el menu abierto (no es modal'
res N6-scroll      cajon-bloquea-scroll-rojo.html  FALLA 'y el menu es modal (bloquea el scroll de la pagina)'
# Lo que tapa otra cosa (el aviso de cookies) no es del menu: AVISO con su nombre.
res N7-otro        empuja-bajo-aviso-verde.html    PASA  'tapa OTRA cosa, no el menu: «Reservar cita», tapado por «cookie-bar»'
echo "=========== Lo que no se juzga ==========="
res NO-MEDIBLE     no-medible.html          PASA  'NO MEDIBLE'
echo "-------------------------------------------------------------"
echo "  OK $OK · MAL $MAL"
[ "$MAL" -eq 0 ] || exit 1
