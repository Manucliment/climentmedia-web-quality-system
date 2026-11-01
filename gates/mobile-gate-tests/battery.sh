#!/usr/bin/env bash
# =============================================================================
#  BANCO DE `mobile-gate.js`  ·  20-ago-2026
# =============================================================================
#
#  🔴 SE MIDE EN EL SERVIDOR, Y NO ES UNA PREFERENCIA. El arnes de los otros
#  gates de navegador (`structure-gate-tests/run-gate.sh`) usa el Chrome de
#  Windows con `--window-size`, y Windows CLAMPA el ancho a ~500px: una fixtura
#  "a 390" se mediria a 504 y el gate devolveria `coincide:false`, o sea basura.
#  Ademas `mobile-gate.js` es ASINCRONO -- espera a que salga el cromo tardio --
#  y aquel arnes serializa el valor sin esperarlo: guardaria una Promise.
#  Por eso va por `run-gate.js` (puppeteer) en el servidor, sobre `file://`.
#
#  QUE CUBRE, y por que cada caso existe:
#    M1        verde / rojo / no-aplica-legal
#    M2        rojo EN EL HERO  vs  aviso FUERA del hero  (la distincion es
#              deliberada: sin ella toda web con banner abajo queda condenada)
#    M3        aviso por encima del tercio
#    tardio    cromo que sale a 1800ms -- el fallo que tuvo este gate en su
#              primera version, que salio "estable" a 911ms y firmo un PASA
#    no medible  cascaron vacio: `ctas:0` no puede leerse como defecto
#    whatsapp  wa.me cuenta: es el canal de conversion de tres de las webs
#    boton     un <button> con texto es accion... Y SU CONTROL NEGATIVO, que
#              es lo que impide que la regla se ensanche hasta no decir nada
#    1-nov-2026 · M1 pide la accion de CONVERTIR, entera a la vista: reserva
#              externa conocida y propia (con y sin hostsReserva), hero que
#              enlaza, ancla a una hoja que recoge el dato y a una que no, la
#              barra flotante sola, y los cuatro tamanos de la puerta (el boton
#              que cabe a 390 y asoma a 360). Mas el modo CANDIDATO de
#              run-gate.js y la copia del bloque CONVIERTE con structure-gate.js
#    1-nov-2026 · M2 en parte: el CTA del hero con el borde bajo el aviso de
#              cookies y el centro libre (solo se miraba el centro)
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
REF="$(cd "$D/.." && pwd)"
# 21-sep-2026 · GATE_MOVIL_HOST sigue mandando si esta puesto; si no, el host sale
# de ../nav-host.sh, como en la puerta. Aqui ponia `:-example-host`, el marcador
# de la anonimizacion, y este banco salio NO MEDIDO en cada bateria.
. "$REF/nav-host.sh"
HOST="${GATE_MOVIL_HOST:-$(nav_host "$REF")}"
if [ -z "$HOST" ]; then
  echo "  NO SE PUEDE MEDIR: NAV_HOST sin configurar (ni GATE_MOVIL_HOST, ni el"
  echo "  entorno, ni $(nav_host_conf "$REF")). Esto NO es un aprobado."
  exit 3
fi
REMOTO="/tmp/gate-movil-fixtures"

OK=0; MAL=0

# --- empujar fixtures y gate ------------------------------------------------
ssh "$HOST" "rm -rf $REMOTO && mkdir -p $REMOTO" >/dev/null 2>&1 || {
  # exit 3 = NO MEDIDO, la convencion de run-all.sh. Solo ESTE camino: un fallo
  # al copiar (abajo) sigue siendo 2, porque ahi el host SI responde.
  echo "  NO SE PUEDE MEDIR: sin acceso a $HOST. Esto NO es un aprobado."; exit 3; }
scp -q "$D/fixtures/"* "$HOST:$REMOTO/" || { echo "  fallo al copiar fixtures"; exit 2; }
scp -q "$REF/mobile-gate.js" "$HOST:webtools/mobile-gate.js" || { echo "  fallo al copiar el gate"; exit 2; }
# 1-nov-2026 · el corredor tambien: el modo CANDIDATO (GATE_CANDIDATO) vive en el
# run-gate.js de la skill, y un banco que mide con la copia vieja del servidor mide
# otro programa. La puerta lo empuja en cada corrida; el banco, igual.
scp -q "$REF/run-gate.js" "$HOST:webtools/run-gate.js" || { echo "  fallo al copiar el corredor"; exit 2; }

# --- un caso ----------------------------------------------------------------
# res <id> <fixtura> <VEREDICTO esperado> [subcadena que DEBE aparecer] [cfg]
# El tamano es 390x844 salvo que se pida otro delante:  TAM="360 740" res ...
res() {
  local id="$1" fx="$2" esp="$3" debe="${4:-}" cfg="${5:-}"
  local j v iw
  j=$(ssh "$HOST" "cd ~/webtools && node run-gate.js 'file://$REMOTO/$fx' ${TAM:-390 844} mobile-gate.js ${cfg:+'$cfg'}" 2>/dev/null | tail -n +2)
  v=$(printf '%s' "$j"  | grep -o '"VEREDICTO": "[A-Z]*"' | grep -o 'PASA\|FALLA')
  iw=$(printf '%s' "$j" | grep -o '"coincide": [a-z]*' | grep -o 'true\|false')

  local estado="OK" motivo=""
  # 🔴 innerWidth SIEMPRE. Una medida que no coincide con lo pedido no es un
  # resultado: es basura, y no cuenta como OK ni como MAL util.
  if [ "${iw:-x}" != "true" ]; then estado="MAL"; motivo="coincide=$iw (ancho clampado o pagina no cargada)"
  elif [ "${v:-x}" != "$esp" ]; then estado="MAL"; motivo="esperaba $esp, obtuvo ${v:-SIN-VEREDICTO}"
  elif [ -n "$debe" ] && ! printf '%s' "$j" | grep -q -- "$debe"; then
    estado="MAL"; motivo="falta en el informe: «$debe»"
  fi

  if [ "$estado" = OK ]; then OK=$((OK+1)); else MAL=$((MAL+1)); fi
  printf "  %-22s | esp %-5s | obt %-5s | %-3s | iw=%-5s %s\n" \
    "$id" "$esp" "${v:-—}" "$estado" "${iw:-—}" "$motivo"
}

echo "=========== M1 · accion sobre el pliegue ==========="
res M1-verde     m1-verde.html          PASA
res M1-rojo      m1-rojo.html           FALLA  'M1 · ninguna accion'
res M1-legal     m1-legal.html          PASA   'M1 no aplica'
echo
echo "=========== M2 · CTA tapado · la distincion hero/fuera ==========="
res M2-rojo-hero m2-rojo-hero.html      FALLA  'del HERO TAPADOS'
res M2-aviso     m2-aviso-fuera.html    PASA   'tapados al cargar, fuera del hero'
# 1-nov-2026 · tapado EN PARTE: el centro libre y el borde bajo el aviso. El que
# convierte, fallo; el que solo enlaza, aviso. Mas sus dos controles: el mismo boton
# entero por encima del aviso, y un boton pildora (su esquina da el fondo).
res M2-borde     m2-borde-tapado.html   FALLA  'en parte: 3 de 9 puntos'
res M2-borde-ok  m2-borde-libre.html    PASA
res M2-pildora   m2-pildora-libre.html  PASA
res M2-enlace    m2-borde-enlace.html   PASA   'tapados EN PARTE'
echo
echo "=========== M3 · cromo por encima del tercio (AVISO, no fallo) ==========="
res M3-aviso     m3-aviso.html          PASA   'M3 · el cromo flotante cubre'
echo
echo "=========== El cromo que sale TARDE (1800 ms) ==========="
res TARDIO       tardio-rojo.html       FALLA  'del HERO TAPADOS'
echo
echo "=========== Lo que NO se juzga ==========="
res NO-MEDIBLE   no-medible.html        PASA   'NO MEDIBLE'
echo
echo "=========== Que cuenta como accion, y que no ==========="
res WHATSAPP     whatsapp-verde.html    PASA
# 1-nov-2026 · el configurador de botones sueltos es una TIENDA: con ecommerce, la
# accion cuenta aunque no convierta (09 §3.1). Sin la declaracion, en una pagina de
# servicio, un boton que no recoge nada ni lleva a reservar no es la conversion.
res BOTON-OK     boton-suelto-verde.html PASA   ''  '{"ecommerce":true}'
res BOTON-NO-CONV boton-suelto-verde.html FALLA 'ninguna accion de la pagina CONVIERTE'
res BOTON-CROMO  boton-cromo-rojo.html  FALLA  'M1 ·'
echo
echo "=========== M1 · la accion de CONVERTIR, entera a la vista (1-nov-2026) ==========="
res RESERVA-EXT      m1-reserva-externa-verde.html PASA
res RESERVA-PROPIA-R m1-reserva-propia.html  FALLA 'ninguna accion de la pagina CONVIERTE'
res RESERVA-PROPIA-V m1-reserva-propia.html  PASA  ''  '{"hostsReserva":["mijnsalon.example"]}'
res ENLAZA           m1-enlaza-rojo.html     FALLA 'DE CONVERSION'
res ANCLA-HOJA       m1-ancla-hoja-verde.html PASA
res ANCLA-SIN-DATO   m1-ancla-sin-dato-rojo.html FALLA 'es un hero que ENLAZA'
res SOLO-FLOTANTE    m1-solo-flotante-rojo.html FALLA 'DE CONVERSION'
# 1-nov-2026 · el barrido de las webs publicadas: el alta de la aplicacion en un subdominio (app.) de la
# misma web no contaba como convertir. El mismo fichero con dos origenes: de la casa, y de otra web.
res SUBDOMINIO-V     m1-subdominio.html PASA  ''  '{"origen":"https://www.ejemplo.test"}'
res SUBDOMINIO-R     m1-subdominio.html FALLA 'CONVIERTE' '{"origen":"https://www.otro.test"}'
# Los cuatro tamanos de la puerta: el mismo boton cabe a 390 y asoma cortado a 360.
TAM="390 844"  res ASOMA-390   m1-asoma.html  PASA
TAM="360 740"  res ASOMA-360   m1-asoma.html  FALLA 'ASOMA CORTADA'
TAM="1366 768" res VERDE-1366  m1-verde.html  PASA
TAM="1440 900" res VERDE-1440  m1-verde.html  PASA
TAM="1366 768" res ROJO-1366   m1-rojo.html   FALLA 'M1 · ninguna accion'
TAM="1440 900" res ROJO-1440   m1-rojo.html   FALLA 'M1 · ninguna accion'
echo
echo "=========== El candidato: la URL de produccion, servida del disco (1-nov-2026) ==========="
# run-gate.js con GATE_CANDIDATO contesta desde el disco cada peticion al origen de
# GATE_SITIO. El rojo prueba que el CSS tambien llega del disco: sin `_base.css` el
# relleno no mide 1400 px y el boton de m1-rojo caeria dentro de la pantalla.
cand() {
  local id="$1" ruta="$2" esp="$3"
  local j v n estado="OK" motivo=""
  j=$(ssh "$HOST" "cd ~/webtools && GATE_CANDIDATO='$REMOTO' GATE_SITIO='https://candidato.invalid' node run-gate.js 'https://candidato.invalid$ruta' 390 844 mobile-gate.js" 2>/dev/null)
  v=$(printf '%s' "$j" | grep -o '"VEREDICTO": "[A-Z]*"' | grep -o 'PASA\|FALLA')
  n=$(printf '%s' "$j" | head -1 | grep -o '"candidato":[0-9]*' | grep -o '[0-9]*$')
  if [ "${n:-0}" -lt 2 ]; then estado="MAL"; motivo="servidas del disco: ${n:-0} (la pagina y su CSS, minimo 2)"
  elif [ "${v:-x}" != "$esp" ]; then estado="MAL"; motivo="esperaba $esp, obtuvo ${v:-SIN-VEREDICTO}"; fi
  if [ "$estado" = OK ]; then OK=$((OK+1)); else MAL=$((MAL+1)); fi
  printf "  %-22s | esp %-5s | obt %-5s | %-3s | del disco=%-3s %s\n" "$id" "$esp" "${v:-—}" "$estado" "${n:-0}" "$motivo"
}
cand CAND-VERDE /m1-verde PASA
cand CAND-ROJO  /m1-rojo  FALLA
echo
# ===========================================================================
#  La regla CONVIERTE vive en DOS gates. Hasta que haya una sola fuente, las dos
#  copias tienen que ser iguales byte a byte (07-trampas §68: dos copias divergen).
# ===========================================================================
bloque() { sed -n '/^\/\/ ── CONVIERTE ·/,/^\/\/ ── \/CONVIERTE /p' "$1"; }
NB=$(bloque "$REF/mobile-gate.js" | wc -l | tr -dc '0-9')
if [ "${NB:-0}" -lt 10 ]; then
  MAL=$((MAL+1)); echo "  CONVIERTE-COPIA        | MAL | no encuentro el bloque en mobile-gate.js (${NB:-0} lineas)"
elif diff <(bloque "$REF/mobile-gate.js") <(bloque "$REF/structure-gate.js") >/dev/null; then
  OK=$((OK+1)); echo "  CONVIERTE-COPIA        | OK  | el bloque ($NB lineas) es identico en mobile-gate.js y structure-gate.js"
else
  MAL=$((MAL+1)); echo "  CONVIERTE-COPIA        | MAL | mobile-gate.js y structure-gate.js ya no dicen lo mismo de que convierte:"
  diff <(bloque "$REF/mobile-gate.js") <(bloque "$REF/structure-gate.js") | head -6 | sed 's/^/        /'
fi
echo

# ===========================================================================
#  El propio `coincide`: que significa, y como se pone en ROJO
#  21-ago-2026 · nacio de un fallo REAL de este gate, no de un ejercicio.
#  Estaba escrito `coincide: vw === 390`, asi que TODA medida a otro ancho
#  salia marcada como basura. A 360 -- ancho de Android muy comun -- el gate
#  encontro un CTA tapado de verdad en site-a.example y ese hallazgo se leia
#  como «no coincide, no es un resultado». El guardia contra el clampeo de
#  Windows estaba tapando el defecto que el gate existe para ver.
#  Ahora compara contra el ancho PEDIDO, que `run-gate.js` inyecta.
# ===========================================================================
# coincide <id> <fixtura> <ancho> <esperado true|false> [cfg]
coincide() {
  local id="$1" fx="$2" w="$3" esp="$4" cfg="${5:-}"
  local j iw estado="OK" motivo=""
  j=$(ssh "$HOST" "cd ~/webtools && node run-gate.js 'file://$REMOTO/$fx' $w 800 mobile-gate.js ${cfg:+'$cfg'}" 2>/dev/null | tail -n +2)
  iw=$(printf '%s' "$j" | grep -o '"coincide": [a-z]*' | grep -o 'true\|false')
  if [ "${iw:-x}" != "$esp" ]; then estado="MAL"; motivo="esperaba coincide=$esp, obtuvo ${iw:-SIN-DATO}"; fi
  if [ "$estado" = OK ]; then OK=$((OK+1)); else MAL=$((MAL+1)); fi
  printf "  %-22s | esp coincide=%-5s | obt %-5s | %-3s %s\n" "$id" "$esp" "${iw:-—}" "$estado" "$motivo"
}
echo
echo '=========== coincide compara contra lo PEDIDO, no contra 390 ==========='
coincide ANCHO-390     m1-verde.html 390 true
coincide ANCHO-360     m1-verde.html 360 true
coincide ANCHO-MENTIRA m1-verde.html 390 false '{"anchoPedido":400}'
echo "-------------------------------------------------------------"
echo "  OK $OK · MAL $MAL"
[ "$MAL" -eq 0 ] || exit 1
