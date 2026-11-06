#!/usr/bin/env bash
# =============================================================================
#  BANCO DE `botones-gate.js`  ·  6-nov-2026
# =============================================================================
#
#  Se mide en el servidor, como el de `marca-gate.js` (en Windows Chrome clampa
#  el ancho), y en modo CANDIDATO de `run-gate.js`: las fixturas se sirven del
#  disco con un origen de verdad.
#
#  QUE CUBRE: cada regla en rojo y en verde, y los casos que impiden que una
#  regla se ensanche hasta no decir nada o se apague sin que se vea:
#    BT1  el boton del formulario con otro cuerpo (FALLA) · el <button> que no
#         hereda el tipo (FALLA; con `font-family: inherit`, PASA) · medio pixel
#         de cuerpo (PASA) y dos (FALLA) · un borde del color del relleno (PASA)
#         y uno que se ve (FALLA)
#    BT2  otro fondo sobre el mismo fondo (FALLA) · el boton invertido de una
#         banda oscura (PASA, en `verde`) y el mismo invertido sobre claro (FALLA:
#         el fondo de detras no es una exencion para todo)
#    BT3  el margin-top que estira a los vecinos (FALLA) · un texto en dos lineas
#         (PASA: la altura solo se compara en una linea)
#    BT4  con `familias`: un boton de ninguna (AVISO) · una variante con nombre
#         que dentro de su familia ya no vale (FALLA)
#    y lo que no se cuenta: el aviso de cookies por su caja (PASA), el <body> con
#    `has-consent` que NO es un aviso (FALLA: el 6-nov apagaba una web entera),
#    el boton que abre el menu (PASA), botones sin clase y una pagina sin botones
#    (PASA, dicho).
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
REMOTO="/tmp/gate-botones-fixtures"
SITIO="https://botones.invalid"
OK=0; MAL=0

ssh "$HOST" "rm -rf $REMOTO && mkdir -p $REMOTO" >/dev/null 2>&1 || {
  echo "  NO SE PUEDE MEDIR: sin acceso a $HOST. Esto NO es un aprobado."; exit 3; }
scp -q "$D/fixtures/"* "$HOST:$REMOTO/" || { echo "  fallo al copiar fixtures"; exit 2; }
# El gate va a una carpeta propia del banco: ~/webtools/gates/ es la copia que usa la puerta.
ssh "$HOST" "mkdir -p ~/webtools/banco-botones" >/dev/null 2>&1
# GATE_BOTONES=<fichero> mide otra copia del gate (un mutante, para ver en rojo lo que el banco dice
# proteger); SOLO=<regex> corre solo los casos cuyo id casa.
scp -q "${GATE_BOTONES:-$REF/botones-gate.js}" "$HOST:webtools/banco-botones/botones-gate.js" || { echo "  fallo al copiar el gate"; exit 2; }
scp -q "$REF/run-gate.js" "$HOST:webtools/run-gate.js" || { echo "  fallo al copiar el corredor"; exit 2; }

# res <id> <fixtura> <VEREDICTO esperado> [subcadena que DEBE aparecer] [cfg]
# El tamano es 1366x768 salvo que se pida otro delante:  TAM="390 844" res ...
res() {
  local id="$1" fx="$2" esp="$3" debe="${4:-}" cfg="${5:-}"
  local j v iw n
  [ -n "${SOLO:-}" ] && ! printf '%s' "$id" | grep -qE "$SOLO" && return 0
  j=$(ssh "$HOST" "cd ~/webtools && GATE_CANDIDATO='$REMOTO' GATE_SITIO='$SITIO' node run-gate.js '$SITIO/$fx' ${TAM:-1366 768} banco-botones/botones-gate.js ${cfg:+'$cfg'}" 2>/dev/null)
  n=$(printf '%s' "$j" | head -1 | grep -o '"candidato":[0-9]*' | grep -o '[0-9]*$')
  j=$(printf '%s' "$j" | tail -n +2)
  v=$(printf '%s' "$j"  | grep -o '"VEREDICTO": "[A-Z]*"' | grep -o 'PASA\|FALLA')
  iw=$(printf '%s' "$j" | grep -o '"coincide": [a-z]*' | grep -o 'true\|false')
  local estado="OK" motivo=""
  if [ "${n:-0}" = 0 ]; then estado="MAL"; motivo="no se sirvio del disco (candidato=0): lo medido no es la fixtura"
  elif [ "${iw:-x}" != "true" ]; then estado="MAL"; motivo="coincide=$iw (ancho clampado o pagina no cargada)"
  elif [ "${v:-x}" != "$esp" ]; then estado="MAL"; motivo="esperaba $esp, obtuvo ${v:-SIN-VEREDICTO}"
  elif [ -n "$debe" ] && ! printf '%s' "$j" | grep -qF -- "$debe"; then estado="MAL"; motivo="falta en el informe: «$debe»"
  fi
  if [ "$estado" = OK ]; then OK=$((OK+1)); else MAL=$((MAL+1)); printf '%s\n' "$j" | grep -A4 '"fallos"' | head -5 | sed 's/^/        /'; fi
  printf "  %-22s | esp %-5s | obt %-5s | %-3s | iw=%-5s %s\n" "$id" "$esp" "${v:-—}" "$estado" "${iw:-—}" "$motivo"
}
FAM_PRI='{"familias":{"primario":".btn-primary"}}'
FAM_AUD='{"familias":{"primario":".btn-primary, .aud-cta","secundario":".btn-ghost"}}'
FAM_DOS='{"familias":{"primario":".btn-primary","secundario":".btn-ghost"}}'

echo "=========== verde: el mismo boton, igual; el invertido de la banda oscura, tambien ==========="
res VERDE              verde.html               PASA
TAM="390 844" res VERDE-390 verde.html          PASA
echo
echo "=========== BT1 · un grupo, dos formas ==========="
res FORMA-TAMANO       forma-tamano.html        FALLA 'BT1 · .btn.btn-primary con 2 formas a 1366 px: cambia tamaño'
res FORMA-TIPO         forma-tipo.html          FALLA 'cambia tipo'
res TIPO-HEREDADO      forma-tipo-heredado.html PASA
res TOLERANCIA         tolerancia.html          PASA
res TOLERANCIA-FUERA   tolerancia-fuera.html    FALLA 'cambia tamaño'
res BORDE-IGUAL        borde-igual.html         PASA
res BORDE-VISIBLE      borde-visible.html       FALLA 'cambia borde'
echo
echo "=========== BT2 · sobre el mismo fondo, dos pinturas ==========="
res PINTURA            pintura.html             FALLA 'BT2 · .btn.btn-primary sobre fondo claro con 2 pinturas'
res INVERTIDO-CLARO    invertido-en-claro.html  FALLA 'BT2 · .btn.btn-primary sobre fondo claro'
echo
echo "=========== BT3 · la misma forma en una linea, otra altura ==========="
res ALTURA             altura.html              FALLA 'BT3 · .btn.btn-ghost en una linea mide'
res DOS-LINEAS         dos-lineas.html          PASA
echo
echo "=========== BT4 · las familias ==========="
res FAMILIA-CON-OTRO   familias.html            FALLA 'BT1 · primario con 2 formas' "$FAM_AUD"
res FAMILIA-AVISO      familias.html            PASA  'BT4 · 2 clase(s) de boton fuera de las familias' "$FAM_DOS"
res VARIANTE-NOMBRADA  menu-sin-aria.html       PASA
res VARIANTE-EN-FAMILIA menu-sin-aria.html      FALLA 'BT1 · primario con 2 formas' "$FAM_PRI"
echo
echo "=========== lo que no se cuenta, y lo que si ==========="
res COOKIES            cookies.html             PASA
res BODY-CONSENT       body-consent.html        FALLA 'cambia tamaño'
res MENU               menu.html                PASA
res SIN-CLASE          sin-clase.html           PASA  'sin clase: no se comparan'
res NINGUNO            ninguno.html             PASA  'BT1-BT3 · NO MEDIDO'
echo
ssh "$HOST" "rm -rf $REMOTO ~/webtools/banco-botones" >/dev/null 2>&1
echo "  $OK OK · $MAL MAL"
[ "$MAL" = 0 ] && exit 0 || exit 1
