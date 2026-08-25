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
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
REF="$(cd "$D/.." && pwd)"
HOST="${GATE_MOVIL_HOST:-example-host}"
REMOTO="/tmp/gate-movil-fixtures"

OK=0; MAL=0

# --- empujar fixtures y gate ------------------------------------------------
ssh "$HOST" "rm -rf $REMOTO && mkdir -p $REMOTO" >/dev/null 2>&1 || {
  echo "  NO SE PUEDE MEDIR: sin acceso a $HOST. Esto NO es un aprobado."; exit 2; }
scp -q "$D/fixtures/"* "$HOST:$REMOTO/" || { echo "  fallo al copiar fixtures"; exit 2; }
scp -q "$REF/mobile-gate.js" "$HOST:webtools/mobile-gate.js" || { echo "  fallo al copiar el gate"; exit 2; }

# --- un caso ----------------------------------------------------------------
# res <id> <fixtura> <VEREDICTO esperado> [subcadena que DEBE aparecer] [cfg]
res() {
  local id="$1" fx="$2" esp="$3" debe="${4:-}" cfg="${5:-}"
  local j v iw
  j=$(ssh "$HOST" "cd ~/webtools && node run-gate.js 'file://$REMOTO/$fx' 390 844 mobile-gate.js ${cfg:+'$cfg'}" 2>/dev/null | tail -n +2)
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
res BOTON-OK     boton-suelto-verde.html PASA
res BOTON-CROMO  boton-cromo-rojo.html  FALLA  'M1 ·'
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
