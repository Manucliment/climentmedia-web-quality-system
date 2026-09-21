#!/bin/sh
# =============================================================================
#  Banco de measure-screens.js — densidad y CTAs
# =============================================================================
#  🔴 SE MIDE EN EL SERVIDOR, SIEMPRE. Chrome headless en Windows clampa
#  --window-size a ~500 px de ancho: una medida «a 390» sale recortada y el
#  numero es basura. `run-gate.js` imprime innerWidth y `coincide`, y aqui
#  una corrida con coincide:false NO cuenta como resultado -- cuenta como MAL.
#
#  ⚠️ Y el HOME remoto se resuelve UNA vez, en una variable. Dentro de comillas
#  simples `$HOME` no se expande: la primera version mandaba `file://$HOME/...`
#  literal y Chrome devolvia ERR_INVALID_URL en las 24 corridas. Salieron 24 MAL,
#  que al menos es ruidoso -- pero si el banco hubiera contado eso como «no se
#  pudo medir» habria sido un cero con cara de aprobado.
#
#  Que fija este banco:
#   1 · los moldes de blueprint/moulds/ PASAN la regla de la unidad.
#       (Eran 19 en references/moldes/. Al pasar las rutas a ingles la carpeta
#       cambio de sitio y este banco siguio buscando en la vieja: el bucle no
#       encontraba nada y media un unico «caso» llamado `[0-9]*`. Nadie lo vio
#       porque el banco salia NO MEDIDO por el host marcador. 21-sep-2026.)
#       Es la contradiccion del 18-ago (07-trampas §47): diez de ellos pasan de
#       una pantalla como SECCION y ninguno como UNIDAD. Si alguien vuelve a
#       medir el contenedor, esto se pone rojo en diez moldes a la vez.
#   2 · los cuatro muros que TIENEN que seguir cayendo.
#   3 · una lista bien hecha, que tiene que pasar.
# =============================================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
REF="$(dirname "$DIR")"
MOLDES="$REF/../blueprint/moulds"
# 21-sep-2026 · el host sale de ../nav-host.sh, como en la puerta (ver su cabecera).
. "$REF/nav-host.sh"
HOST="$(nav_host "$REF")"
if [ -z "$HOST" ]; then
  echo "BANCO · measure-screens.js (densidad y CTAs)"
  echo
  echo "  NO VERIFICADO · NAV_HOST sin configurar: ni el entorno ni"
  echo "  $(nav_host_conf "$REF") dicen desde donde medir."
  echo; echo "  NO MEDIDO (NAV_HOST sin configurar)"; exit 3
fi
SUB="pruebas-densidad"
OK=0; MAL=0

echo "BANCO · measure-screens.js (densidad y CTAs) · medido en $HOST"
echo

HOME_R="$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOST" 'echo $HOME' </dev/null 2>/dev/null)"
if [ -z "$HOME_R" ] || [ ! -f "$REF/run-gate.js" ]; then
  echo "  NO VERIFICADO · no se llega a $HOST, o falta $REF/run-gate.js"
  echo "  Esto NO es un aprobado: sin navegador no se ha medido nada."
  echo
  # exit 3 = NO MEDIDO, la convencion de run-all.sh. NO es 1: un hueco declarado
  # y un defecto medido son cosas distintas, y contarlos igual gasta la senal.
  echo "  NO MEDIDO (sin navegador)"
  exit 3
fi

ssh "$HOST" "mkdir -p $HOME_R/$SUB" </dev/null >/dev/null 2>&1
scp -q "$DIR/fixtures/"*.html "$HOST:$HOME_R/$SUB/" </dev/null
scp -q "$MOLDES/"*.html "$MOLDES/"_*.css "$HOST:$HOME_R/$SUB/" </dev/null
# 🔴 El corredor se empuja igual que el gate: vive en la skill, no en el servidor.
# Verificado el 18-ago borrandolo de ~/webtools: sin esta linea el banco da
# OK 0 · MAL 24, y con ella lo repone y vuelve a 24 de 24.
scp -q "$REF/run-gate.js" "$HOST:$HOME_R/webtools/run-gate.js" </dev/null
scp -q "$REF/measure-screens.js" "$HOST:$HOME_R/webtools/gates/measure-screens.js" </dev/null

# correr <fichero> -> "<coincide>|<VEREDICTO>|<los fallos en una linea>"
correr () {
  ssh "$HOST" "cd $HOME_R/webtools && node run-gate.js file://$HOME_R/$SUB/$1 390 844 gates/measure-screens.js" </dev/null 2>&1 |
  awk '/"coincide"/ { c = (/"coincide":true/) ? "true" : "false" }
       /"VEREDICTO"/ { v = (/PASA/) ? "PASA" : "FALLA" }
       /pantalla|contenedor|CTA|scroll/ { f = f " " $0 }
       END { printf "%s|%s|%s\n", c, v, f }'
}

espera () {                      # espera <fichero> <PASA|FALLA> <trozo del fallo> <titulo>
  fich="$1"; quiero="$2"; motivo="$3"; titulo="$4"
  linea="$(correr "$fich")"
  coin="${linea%%|*}"; resto="${linea#*|}"; ver="${resto%%|*}"; fallos="${resto#*|}"
  if [ "$coin" != "true" ]; then
    printf "  MAL   %-46s innerWidth no coincide: la medida es basura\n" "$titulo"; MAL=$((MAL+1)); return
  fi
  if [ "$ver" != "$quiero" ]; then
    printf "  MAL   %-46s esperaba %s y salio %s\n" "$titulo" "$quiero" "${ver:-sin-veredicto}"; MAL=$((MAL+1)); return
  fi
  if [ -n "$motivo" ]; then
    case "$fallos" in
      *"$motivo"*) : ;;
      *) printf "  MAL   %-46s %s pero no por «%s»\n" "$titulo" "$ver" "$motivo"; MAL=$((MAL+1)); return ;;
    esac
  fi
  printf "  ok    %-46s %s\n" "$titulo" "$ver"
  OK=$((OK+1))
}

echo "== LOS MUROS QUE TIENEN QUE CAER"
espera f1-muro-prosa.html      FALLA "SIN UNA PARADA" "seis parrafos seguidos son un muro"
espera f2-prosa-con-hijos.html FALLA "SIN UNA PARADA" "y con enlace y negrita dentro, tambien"
espera f3-unidad-enorme.html   FALLA "SIN UNA PARADA" "una sola unidad de 1628 px"
espera f4-seccion-gigante.html FALLA "limite del contenedor"         "doce unidades que suman 5 pantallas"
# 20-ago-2026 (07-trampas §66). f8 y f9 llevan EXACTAMENTE el mismo texto
# visible: lo unico que cambia es si la pregunta es <p> o <h3>. Si alguien
# mete <p> en la lista de PARADA, f8 se pone verde y este par lo canta.
espera f8-faq-parrafos.html    FALLA "SIN UNA PARADA" "5 preguntas de FAQ en <p> son un muro"
echo
echo "== LO QUE TIENE QUE PASAR"
espera f5-lista-buena.html     PASA  ""                              "tres unidades, dos CTA"
espera f9-faq-titulares.html   PASA  ""                              "el mismo texto con la pregunta en <h3>"

# 19-ago-2026 - EL LIMITE DE ALTURA CUENTA PALABRAS. Antes era un 6 fijo anclado
#   a una portada de 206 palabras, y por eso suspendia a la pagina MAS DENSA del
#   parque solo por traer mas texto del cliente. Estos dos casos son los que
#   sostienen la regla nueva, y el segundo es el que la pone a prueba de verdad:
#   con el umbral viejo salia FALLA.
espera f6-alto-sin-texto.html  FALLA "pantallas de scroll"          "mucho alto y 48 palabras: es aire"
espera f7-largo-pero-denso.html PASA  ""                            "mismo alto, pero lo compra el texto"
echo
# 🔴 Se CUENTAN antes de medir. Con la carpeta equivocada, el patron no casaba,
#    `sh` dejaba el literal `[0-9]*.html` y el bucle media UN caso inexistente --
#    un «MAL» que parecia un problema de ancho. Cero moldes no es un repertorio
#    que pasa: es un repertorio que no se ha encontrado, y se dice con ese nombre.
N_MOLDES="$(ls "$MOLDES"/[0-9]*.html 2>/dev/null | wc -l | tr -dc '0-9')"
echo "== EL REPERTORIO: los ${N_MOLDES:-0} moldes de blueprint/moulds, por la regla de la UNIDAD (07-trampas §47)"
if [ "${N_MOLDES:-0}" -eq 0 ]; then
  printf "  MAL   %-46s no hay ni un molde en %s\n" "repertorio" "$MOLDES"; MAL=$((MAL+1))
fi
for f in "$MOLDES"/[0-9]*.html; do
  [ -f "$f" ] || continue
  n="$(basename "$f")"
  linea="$(correr "$n")"
  coin="${linea%%|*}"; resto="${linea#*|}"; fallos="${resto#*|}"
  if [ "$coin" != "true" ]; then
    printf "  MAL   %-46s innerWidth no coincide\n" "${n%.html}"; MAL=$((MAL+1)); continue
  fi
  case "$fallos" in
    # Se aceptan las DOS redacciones a proposito: la nueva («UNIDAD») y la
    # vieja («ocupan mas de una pantalla»). Si alguien revierte el gate a medir
    # el contenedor, este banco tiene que ponerse rojo en diez moldes a la vez
    # -- y con solo la redaccion nueva se quedaba ciego y los daba por buenos.
    *"SIN UNA PARADA"*|*"UNIDAD de mas de una pantalla"*|*"ocupan mas de una pantalla"*|*"limite del contenedor"*)
      printf "  MAL   %-46s desborda con su propio ejemplo\n" "${n%.html}"; MAL=$((MAL+1)) ;;
    *)
      printf "  ok    %-46s ninguna unidad pasa de una pantalla\n" "${n%.html}"; OK=$((OK+1)) ;;
  esac
done

echo
printf "  OK %d · MAL %d\n" "$OK" "$MAL"
[ "$MAL" -eq 0 ] || exit 1
