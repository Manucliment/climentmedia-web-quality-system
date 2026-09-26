#!/usr/bin/env bash
# =============================================================================
#  BANCO DE LA PUERTA · el bloque 4-bis (lo que se retiro, ¿sigue servido?)
# =============================================================================
#  POR QUE EXISTE, y por que no existia antes:
#
#  Los subidores de este sistema extraen un `tar` ENCIMA del docroot: anaden y
#  sobrescriben, y NUNCA borran. Un fichero retirado del repo SIGUE SERVIDO.
#  G11 no lo ve por construccion -comprueba que lo del recibo se sirva, no que
#  no sobre nada-, asi que durante meses una limpieza se podia reportar como
#  hecha estando viva. Medido en un sitio real el 9-sep-2026: 13 ficheros
#  retirados del arbol, G11 en verde, y los 13 devolviendo 200.
#
#  4-bis contesta la otra mitad. Este banco existe para que no se apague sola:
#  lo que decide un rojo es la clasificacion del codigo HTTP, y eso solo se
#  prueba pidiendo de verdad.
#
#  🔑 SE EJECUTAN LOS BYTES REALES DE deploy.sh, extraidos entre dos marcas. No
#     una copia: una copia se queda atras y el banco pasaria midiendo su propio
#     doble, que es la enfermedad que este repositorio lleva documentada. Si las
#     marcas desaparecen, el banco NO pasa en silencio: da MAL y lo dice.
#
#  Servidor propio en 127.0.0.1 con centinela, como el banco de qa-master: sin
#  el, un puerto ocupado por otra sesion mide OTRA cosa y las pruebas pasan por
#  el motivo equivocado. Cero webs de cliente: este repositorio es publico.
#
#  uso:  bash tests.sh
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"

ok=0; ko=0
PUERTA="../deploy.sh"

# ── el bloque real, extraido entre sus dos marcas ────────────────────────────
BLOQUE="$(mktemp -t bloque4bis-XXXXXXXX)"
A=$(grep -n 'linea; echo "  4-bis' "$PUERTA" | head -1 | cut -d: -f1)
B=$(grep -n '^# La lista de ESTE despliegue' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A:-}" ] || [ -z "${B:-}" ] || [ "$A" -ge "$B" ]; then
  echo "  MAL   no encuentro el bloque 4-bis en $PUERTA (marcas movidas o borradas)"
  echo "        Esto NO es un banco en verde: es un banco que no ha podido medir."
  exit 1
fi
sed -n "${A},$((B-1))p" "$PUERTA" > "$BLOQUE"

# ── servidor local con centinela ─────────────────────────────────────────────
DIR="$(mktemp -d -t docroot-XXXXXXXX)"
CENT="centinela-$$-$(date +%s)"
printf '%s\n' "$CENT" > "$DIR/_sentinel.txt"
printf 'body{}\n'     > "$DIR/viva.css"
P=$(( 8900 + ($$ % 300) ))
perl "../receipt-tests/test-server.pl" "$DIR" "$P" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; rm -rf "$DIR" "$BLOQUE"' EXIT
sleep 1
if [ "$(curl -sS --max-time 5 "http://127.0.0.1:$P/_sentinel.txt" 2>/dev/null)" != "$CENT" ]; then
  echo "  MAL   no arranco mi servidor en el puerto $P · nada de lo de abajo mide nada"
  exit 1
fi

# el bloque usa estas: `linea` es decoracion, REF/REPO solo para la anotacion
linea(){ :; }
SITIO="http://127.0.0.1:$P"
REF="$(cd .. && pwd)"
REPO="$DIR"

TMP="$(mktemp -t salida-XXXXXXXX)"
espera() { # nombre · lo que TIENE que salir · lo que NO puede salir
  local n="$1" si="$2" no="$3"
  ( . "$BLOQUE" ) > "$TMP" 2>&1
  local bien=1
  [ -n "$si" ] && ! grep -q -- "$si" "$TMP" && bien=0
  [ -n "$no" ] &&   grep -q -- "$no" "$TMP" && bien=0
  if [ "$bien" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
  else ko=$((ko+1)); printf '  MAL   %s\n' "$n"; sed 's/^/        /' "$TMP"; fi
}

VACIO="$(mktemp -t vacio-XXXXXXXX)"; : > "$VACIO"
ANT="$(mktemp -t ant-XXXXXXXX)";     echo "viva.css" > "$ANT"
RET="$(mktemp -t ret-XXXXXXXX)"

# 🔴 EL CASO QUE MAS IMPORTA. Sin lista anterior no se puede comparar, y eso NO
#    es «no sobra nada»: es «nadie ha mirado». Un instrumento que calla cuando no
#    puede medir se lee como un aprobado, y ese es el fallo que este sistema
#    persigue en todas partes.
LISTA_ANT="/no/existe/esta/lista"; RETIRADAS="$VACIO"
espera "sin lista anterior dice NO MEDIDO, no 'limpio'" "NO MEDIDO" "ningun fichero se ha retirado"

LISTA_ANT="$ANT"; RETIRADAS="$VACIO"
espera "con lista y nada retirado, lo dice" "ningun fichero se ha retirado" "SIGUEN SERVIDOS"

# POSITIVO: retirado del arbol y el servidor sigue dandolo -> rojo
LISTA_ANT="$ANT"; RETIRADAS="$RET"; echo "viva.css" > "$RET"
espera "un retirado que SIGUE servido sale en rojo" "SIGUEN SERVIDOS" "El destino cuadra"

# NEGATIVO: retirado y ya no esta -> no puede dar rojo, o el aviso no valdria nada
RETIRADAS="$RET"; echo "borrada-de-verdad.css" > "$RET"
espera "un retirado ya borrado NO da falso rojo" "El destino cuadra" "SIGUEN SERVIDOS"

# Y que CUENTE, no que solo avise: 1 de 2, no 2 de 2 ni 1 de 1.
RETIRADAS="$RET"; printf 'viva.css\nborrada-de-verdad.css\n' > "$RET"
espera "cuenta solo los vivos: 1 de 2" "1 de 2 SIGUEN SERVIDOS" ""

rm -f "$TMP" "$VACIO" "$ANT" "$RET"
echo
printf '  %d bien · %d mal\n' "$ok" "$ko"
# 26-sep-2026 · run-all.sh no sabia leer «bien · mal» y contaba este banco como
# PASA con CERO casos («no he sabido leer su recuento»). En DOS lineas y con el
# formato que lee: en una sola, `[0-9]+ +MAL` casaria con el recuento de verdes.
printf '  OK %d\n' "$ok"
printf '  MAL %d\n' "$ko"
[ "$ko" = 0 ]
