#!/usr/bin/env bash
# =============================================================================
#  BANCO DE LA PUERTA · el bloque 4-bis (lo que se retiro, ¿sigue servido?)
#                       y, desde el 1-nov-2026, nav_decide (el 1-quater: ¿para
#                       la subida lo que los gates de navegador dicen del candidato?)
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

# =============================================================================
#  EL BLOQUE nav_decide (1-quater, 1-nov-2026): los gates de navegador sobre el
#  CANDIDATO, ¿paran la subida? Los mismos bytes de la puerta, entre sus marcas.
#  Sin red y sin servidor: la decision es pura (entra lo medido, sale el si o el no).
# =============================================================================
DEC="$(mktemp -t navdecide-XXXXXXXX)"
A2=$(grep -n '^# >>> nav_decide' "$PUERTA" | head -1 | cut -d: -f1)
B2=$(grep -n '^# <<< nav_decide' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A2:-}" ] || [ -z "${B2:-}" ] || [ "$A2" -ge "$B2" ]; then
  ko=$((ko+1)); echo "  MAL   no encuentro el bloque nav_decide en $PUERTA (marcas movidas o borradas)"
else
  sed -n "${A2},${B2}p" "$PUERTA" > "$DEC"
  # shellcheck disable=SC1090
  . "$DEC"
  decide() { # nombre · rc esperado · lo que TIENE que salir · lo que NO puede salir
    local n="$1" rc_esp="$2" si="$3" no="$4" rc bien=1
    ( nav_decide; r=$?; printf '\nNOTA=%s\n' "$NAVC_NOTA"; exit $r ) > "$TMP" 2>&1; rc=$?
    [ "$rc" = "$rc_esp" ] || bien=0
    [ -n "$si" ] && ! grep -qF -- "$si" "$TMP" && bien=0
    [ -n "$no" ] &&   grep -qF -- "$no" "$TMP" && bien=0
    if [ "$bien" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s (rc %s, esperaba %s)\n' "$n" "$rc" "$rc_esp"; sed 's/^/        /' "$TMP"; fi
  }
  NAVC_EXIGE=1; NAVC_HUECOS=""

  NAVC_ROJOS="mobile-gate structure-gate"; AUN_ASI=""; SUBIR=1
  decide "FALLA sin --aun-asi: NO sube"                      1 "EN ROJO EN EL NAVEGADOR NO SE SUBE" ""
  SUBIR=0
  decide "FALLA en ensayo: avisa y no para el ensayo"        0 "con --subir, esto para la subida" "NO SE DESPLIEGA"
  SUBIR=1; AUN_ASI="mobile-gate: el cliente quiere el hero asi"
  decide "el motivo nombra uno de dos: NO sube"              1 "no nombra: structure-gate" ""
  AUN_ASI="mobile-gate y structure-gate: decision del cliente, con fecha"
  decide "nombra los dos: sube y deja la nota"               0 "NOTA=NAVEGADOR-ROJO [mobile-gate structure-gate]" "NO SE DESPLIEGA"
  # 🔴 EL CASO QUE ORIGINO ESTO: el hueco se firmo con «lo contestan G11 y el navegador»
  #    y el navegador ya habia dicho FALLA. Aunque nombre el gate, ese motivo no vale.
  NAVC_ROJOS="mobile-gate"; AUN_ASI="mobile-gate firmado; EST-06 lo contestan G11 y el navegador"
  decide "motivo «lo contesta el navegador» con FALLA: NO"   1 "Y EL NAVEGADOR YA HA CONTESTADO" "NOTA=NAVEGADOR-ROJO"
  AUN_ASI="mobile-gate: the browser covers it after upload"
  decide "lo mismo en ingles: tambien NO"                    1 "Y EL NAVEGADOR YA HA CONTESTADO" ""
  # El espejo: nombrar el navegador sin apoyarse en el no es motivo de rechazo.
  AUN_ASI="mobile-gate: decision del cliente; en su oficina no hay navegador movil para probarlo"
  decide "nombrar el navegador sin decir que contesta: sube" 0 "NOTA=NAVEGADOR-ROJO [mobile-gate]" "YA HA CONTESTADO"
  # mobile-menu-gate no contiene «mobile-gate»: nombrar uno no firma el otro.
  NAVC_ROJOS="mobile-gate mobile-menu-gate"; AUN_ASI="mobile-menu-gate: el menu se rehace la semana que viene"
  decide "nombrar mobile-menu-gate no firma mobile-gate"     1 "no nombra: mobile-gate" ""

  # Lo que NO se pudo medir
  NAVC_ROJOS=""; NAVC_HUECOS="todo (sin host-de-prueba)"; AUN_ASI=""; SUBIR=1; NAVC_EXIGE=1
  decide "web con URLS_NAVEGADOR sin medir: NO sube"         1 "NO MEDIDO NO ES UN APROBADO" ""
  AUN_ASI="sin navegador: servidor de medida caido, arreglo urgente del formulario"
  decide "firmado con «navegador»: sube y lo anota"          0 "NOTA=NAVEGADOR-CANDIDATO no medido [todo (sin host-de-prueba)]" "NO SE DESPLIEGA"
  AUN_ASI="lo comprueba el navegador despues de subir"
  decide "«lo comprueba el navegador» sin medir: NO"         1 "NO HA MEDIDO EL CANDIDATO" ""
  AUN_ASI=""; NAVC_EXIGE=0
  decide "web sin URLS_NAVEGADOR sin medir: sube y anota"    0 "NOTA=NAVEGADOR-CANDIDATO no medido" "NO SE DESPLIEGA"
  NAVC_HUECOS=""; NAVC_EXIGE=1
  decide "todo verde y medido: sube sin nota"                0 "NOTA=" "NAVEGADOR"
fi
rm -f "$DEC"

# =============================================================================
#  LAS PAGINAS QUE CAMBIA LA SUBIDA (1-nov-2026): el 1-quater y el 6 miden las
#  declaradas Y las altas y las cambiadas. Dos casos del 31-oct: una guia nueva
#  servida con FALLA porque no estaba en URLS_NAVEGADOR, y una portada que se
#  rompio por una tarjeta mas. Los bytes de la puerta entre sus marcas; el arbol
#  se finge redefiniendo arbol_huellas, que es lo unico que toca receipt.pl.
# =============================================================================
PC="$(mktemp -t pagcamb-XXXXXXXX)"; RP="$(mktemp -d -t repo-XXXXXXXX)"
A3=$(grep -n '^# >>> paginas-cambiadas' "$PUERTA" | head -1 | cut -d: -f1)
B3=$(grep -n '^# <<< paginas-cambiadas' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A3:-}" ] || [ -z "${B3:-}" ] || [ "$A3" -ge "$B3" ]; then
  ko=$((ko+1)); echo "  MAL   no encuentro el bloque paginas-cambiadas en $PUERTA (marcas movidas o borradas)"
else
  sed -n "${A3},${B3}p" "$PUERTA" > "$PC"
  mkdir -p "$RP/_deploy"
  cambia() { # nombre · URLS_NAVEGADOR · tope · lo que TIENE que dar `urls_navegador` (en una linea) · y en la nota
    local n="$1" got
    ( REPO="$RP"; URLS_NAVEGADOR="$2"; URLS_CAMBIADAS_MAX="$3"; . "$PC"
      arbol_huellas() { cat "$RP/hoy"; }
      paginas_cambiadas; printf '%s|%s|%s\n' "$(urls_navegador | tr '\n' ' ' | sed 's/ $//')" "$CAMBIADAS_FUERA" "$CAMBIADAS_NOTA" ) > "$TMP" 2>&1
    got="$(cat "$TMP")"
    if [ "$got" = "$4" ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s\n        sale:     %s\n        esperaba: %s\n' "$n" "$got" "$4"; fi
  }
  V2="# huellas-v2 (html sin sellos ?v=)"
  printf '%s\n' "$V2" "aaaaaaaa 10 index.html" "bbbbbbbb 10 contact.html" "cccccccc 10 guias/index.html" "dddddddd 10 404.html" \
    "eeeeeeee 10 estilo.css" > "$RP/_deploy/.desplegado-huellas.txt"
  printf '%s\n' "aaaaaaaa 10 index.html" "bbbbbbbb 10 contact.html" "cccccccc 10 guias/index.html" "dddddddd 10 404.html" \
    "eeeeeeee 10 estilo.css" > "$RP/hoy"
  cambia "nada cambia: solo las declaradas"                "/ /contact" 8 "/ /contact|0|"
  # 🔴 EL CASO DE INFI: una guia nueva, que no esta en URLS_NAVEGADOR, se mide.
  printf '%s\n' "aaaaaaaa 10 index.html" "bbbbbbbb 10 contact.html" "c2c2c2c2 11 guias/index.html" "dddddddd 10 404.html" \
    "e2e2e2e2 10 estilo.css" "ffffffff 10 guias/reembolso.html" "11111111 10 _og/x.html" "22222222 10 google0a1b2c.html" > "$RP/hoy"
  cambia "un alta y su hub cambiado entran; ni CSS, ni _, ni 404, ni la de Google" "/ /contact" 8 "/ /contact /guias/reembolso /guias/|0|"
  cambia "lo ya declarado no se repite (con o sin barra)"  "/ /contact /guias" 8 "/ /contact /guias /guias/reembolso|0|"
  cambia "el tope deja fuera y lo cuenta (altas primero)"  "/" 1 "/ /guias/reembolso|1|"
  printf '%s\n' "index.html" "contact.html" "guias/index.html" > "$RP/_deploy/.desplegado.txt"
  # Unas huellas de la version vieja (sin cabecera, con el ?v= dentro) no se comparan.
  sed -i 1d "$RP/_deploy/.desplegado-huellas.txt"
  cambia "huellas de otra version: solo las altas"         "/" 8 "/ /guias/reembolso|0|sin huellas (de esta version) de la subida anterior: solo las altas (las cambiadas, desde la proxima subida)"
  rm -f "$RP/_deploy/.desplegado-huellas.txt"
  cambia "sin huellas: solo las altas, y lo dice"          "/" 8 "/ /guias/reembolso|0|sin huellas (de esta version) de la subida anterior: solo las altas (las cambiadas, desde la proxima subida)"
  rm -f "$RP/_deploy/.desplegado.txt"
  cambia "sin ninguna lista: las declaradas, y lo dice"    "/" 8 "/|0|sin lista de la subida anterior: solo URLS_NAVEGADOR"
  # 🔴 EL SELLO ?v= (1-nov, kine): cambiar el CSS reescribe `styles.css?v=` en todas las paginas.
  #    arbol_huellas de verdad (no la fingida), con un receipt.pl de mentira que solo lista.
  HREF="$(mktemp -d -t ref-XXXXXXXX)"
  printf '%s\n' 'print "aaaaaaaa 10 a.html\naaaaaaaa 10 b.html\naaaaaaaa 10 c.html\n"; exit 0;' > "$HREF/receipt.pl"
  printf '<link href="/styles.css?v=161204fb"><p>uno</p>\n' > "$RP/a.html"
  printf '<link href="/styles.css?v=aead9fbc4b"><p>uno</p>\n' > "$RP/b.html"
  printf '<link href="/styles.css?v=161204fb"><p>dos</p>\n' > "$RP/c.html"
  huella() { ( REPO="$RP"; REF="$HREF"; . "$PC"; arbol_huellas | awk -v f="$1" '$3 == f { print $1 }' ); }
  hA="$(huella a.html)"; hB="$(huella b.html)"; hC="$(huella c.html)"
  if [ -n "$hA" ] && [ "$hA" = "$hB" ] && [ "$hA" != "$hC" ]; then ok=$((ok+1)); printf '  PASA  %s\n' "un ?v= nuevo no cambia la huella; un texto nuevo si"
  else ko=$((ko+1)); printf '  MAL   %s (a=%s b=%s c=%s)\n' "un ?v= nuevo no cambia la huella; un texto nuevo si" "$hA" "$hB" "$hC"; fi
  rm -rf "$HREF"
fi
rm -rf "$PC" "$RP"

# =============================================================================
#  EL SELLO JUSTO ANTES DE SUBIR (3-ter, 1-nov-2026). Medido el 31-oct: el repo
#  se toco durante la puerta y subio un arbol que ningun recibo habia sellado.
#  Los bytes de la puerta entre sus marcas; receipt.pl se finge con un REF propio
#  (que receipt.pl detecta el cambio lo prueba su banco, receipt-tests).
# =============================================================================
SEL="$(mktemp -t sello-XXXXXXXX)"; FREF="$(mktemp -d -t ref-XXXXXXXX)"
A4=$(grep -n '^# >>> sello-antes-de-subir' "$PUERTA" | head -1 | cut -d: -f1)
B4=$(grep -n '^# <<< sello-antes-de-subir' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A4:-}" ] || [ -z "${B4:-}" ] || [ "$A4" -ge "$B4" ]; then
  ko=$((ko+1)); echo "  MAL   no encuentro el bloque sello-antes-de-subir en $PUERTA (marcas movidas o borradas)"
else
  sed -n "${A4},${B4}p" "$PUERTA" > "$SEL"
  sella() { # nombre · rc que da el receipt.pl fingido · rc esperado de la puerta · lo que TIENE que salir · lo que NO
    local n="$1" rc bien=1
    printf 'my $v = grep { $_ eq "--verificar" } @ARGV; if ($v && %s) { print "  el arbol ha CAMBIADO desde el QA\\n     CAMBIADO  estilo.css\\n"; exit 1 } exit 0;\n' "$2" > "$FREF/receipt.pl"
    ( REF="$FREF"; REPO="$DIR"; CMD="echo SUBIDOR-EJECUTADO"; . "$SEL"; exit "$RC" ) > "$TMP" 2>&1; rc=$?
    [ "$rc" = "$3" ] || bien=0
    [ -n "$4" ] && ! grep -qF -- "$4" "$TMP" && bien=0
    [ -n "$5" ] &&   grep -qF -- "$5" "$TMP" && bien=0
    if [ "$bien" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s (rc %s, esperaba %s)\n' "$n" "$rc" "$3"; sed 's/^/        /' "$TMP"; fi
  }
  sella "el arbol cambio despues del recibo: NO se ejecuta el subidor" 1 1 "NO se sube" "SUBIDOR-EJECUTADO"
  sella "y dice que fichero"                                           1 1 "CAMBIADO  estilo.css" ""
  sella "el arbol es el del recibo: sube"                              0 0 "SUBIDOR-EJECUTADO" "NO se sube"
fi
rm -rf "$SEL" "$FREF"

rm -f "$TMP" "$VACIO" "$ANT" "$RET"
echo
printf '  %d bien · %d mal\n' "$ok" "$ko"
# 26-sep-2026 · run-all.sh no sabia leer «bien · mal» y contaba este banco como
# PASA con CERO casos («no he sabido leer su recuento»). En DOS lineas y con el
# formato que lee: en una sola, `[0-9]+ +MAL` casaria con el recuento de verdes.
printf '  OK %d\n' "$ok"
printf '  MAL %d\n' "$ko"
[ "$ko" = 0 ]
