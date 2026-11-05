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
  # 🔴 5-nov-2026 · EL CASO DE ESA NOCHE: a media puerta otro qa-master, sobre otro
  #    commit, reescribio el recibo en FALLA; aqui solo se comparaba el arbol con el
  #    recibo (el nuevo: cuadraba) y subio. Contra la puerta de antes, los dos «NO
  #    sube» de aqui salen en rojo: subia.
  RREC="$(mktemp -d -t recibo-XXXXXXXX)"
  printf 'SELLO: bbbb\nVEREDICTO: FALLA\nFECHA: 2026-11-05T22:17:00\n' > "$RREC/.qa-recibo"
  recibo() { # nombre · SELLO que leyo el paso 1 · condicion perl de «no vale» · rc esperado · TIENE · NO
    local n="$1" rc bien=1
    printf 'if (%s) { print "  VEREDICTO: FALLA - EN ROJO NO SE DESPLIEGA\\n"; exit 1 } exit 0;\n' "$3" > "$FREF/receipt.pl"
    ( REF="$FREF"; REPO="$RREC"; RECIBO_SELLO_1="$2"; CMD="echo SUBIDOR-EJECUTADO"; . "$SEL"; exit "$RC" ) > "$TMP" 2>&1; rc=$?
    [ "$rc" = "$4" ] || bien=0
    [ -n "$5" ] && ! grep -qF -- "$5" "$TMP" && bien=0
    [ -n "$6" ] &&   grep -qF -- "$6" "$TMP" && bien=0
    if [ "$bien" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s (rc %s, esperaba %s)\n' "$n" "$rc" "$4"; sed 's/^/        /' "$TMP"; fi
  }
  PARA_DESP='grep { $_ eq "--para-desplegar" } @ARGV'
  recibo "el recibo cambio a media puerta: NO sube"          "SELLO: aaaa" 0 1 "EL RECIBO YA NO ES EL QUE DEJO PASAR EL PASO 1" "SUBIDOR-EJECUTADO"
  recibo "y dice el veredicto y la hora del recibo nuevo"    "SELLO: aaaa" 0 1 "VEREDICTO: FALLA · FECHA: 2026-11-05T22:17:00" ""
  recibo "el mismo recibo del paso 1: sube"                  "SELLO: bbbb" 0 0 "SUBIDOR-EJECUTADO" "YA NO ES"
  recibo "vuelto a verificar ENTERO: en FALLA no sube"       "SELLO: bbbb" "$PARA_DESP" 1 "ya no deja subir: NO se sube" "SUBIDOR-EJECUTADO"
  recibo "y ensena el veredicto que lo para"                 "SELLO: bbbb" "$PARA_DESP" 1 "VEREDICTO: FALLA" ""
  rm -rf "$RREC"
fi
rm -rf "$SEL" "$FREF"

# =============================================================================
#  EL CERROJO DE SUBIDA (3-ter-0, 5-nov-2026). Medido el 19-oct: dos sesiones con
#  permiso para la misma subida la hicieron dos veces, con 11 s de diferencia.
#  Los bytes de la puerta entre sus marcas; el directorio central, uno de prueba.
# =============================================================================
CER="$(mktemp -t cerrojo-XXXXXXXX)"; CDIR="$(mktemp -d -t recibos-XXXXXXXX)"
A5=$(grep -n '^# >>> cerrojo-de-subida' "$PUERTA" | head -1 | cut -d: -f1)
B5=$(grep -n '^# <<< cerrojo-de-subida' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A5:-}" ] || [ -z "${B5:-}" ] || [ "$A5" -ge "$B5" ]; then
  ko=$((ko+1)); echo "  MAL   no encuentro el bloque cerrojo-de-subida en $PUERTA (marcas movidas o borradas)"
else
  sed -n "${A5},${B5}p" "$PUERTA" > "$CER"
  T0=100000
  cerrojo() { # nombre · sesion que sube · OTRA_VEZ · cerrojo que ya hay («» = ninguno) · rc esperado · TIENE · NO
    local n="$1" rc bien=1
    rm -rf "$CDIR/subidas"
    ( QA_RECIBOS_DIR="$CDIR"; CLAUDE_CODE_SESSION_ID="$2"; OTRA_VEZ="$3"
      SITIO="https://www.ejemplo.test/"; REPO="/repo/ejemplo"; . "$CER"
      if [ -n "$4" ]; then mkdir -p "$CERROJO_DIR"; printf '%b' "$4" > "$(cerrojo_fichero)"; fi
      cerrojo_decide "$T0"; r=$?; printf '\nNOTA=%s\n' "$CERROJO_NOTA"; exit $r ) > "$TMP" 2>&1; rc=$?
    [ "$rc" = "$5" ] || bien=0
    [ -n "$6" ] && ! grep -qF -- "$6" "$TMP" && bien=0
    [ -n "$7" ] &&   grep -qF -- "$7" "$TMP" && bien=0
    if [ "$bien" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s (rc %s, esperaba %s)\n' "$n" "$rc" "$5"; sed 's/^/        /' "$TMP"; fi
  }
  HACE5="$((T0-300))\tsesion-otra\t/repo/otro\n"
  cerrojo "sin cerrojo: sube, sin nota"                          sesion-yo "" ""                                      0 "NOTA=" "SE SUBIO"
  # 🔴 EL CASO DEL 19-OCT: otra sesion acaba de subir el mismo sitio.
  cerrojo "otra sesion hace 5 min: NO sube"                      sesion-yo "" "$HACE5"                                1 "SE SUBIO HACE 5 MIN DESDE OTRA SESION" ""
  cerrojo "y dice como repetir a sabiendas"                      sesion-yo "" "$HACE5"                                1 "--otra-vez" ""
  cerrojo "con --otra-vez: sube y deja la nota con el motivo"    sesion-yo "la otra se paro a medias" "$HACE5"        0 "NOTA=SUBIDA REPETIDA a los 5 min de otra sesion: la otra se paro a medias" "SE SUBIO HACE"
  cerrojo "la misma sesion repite: sube"                         sesion-otra "" "$HACE5"                              0 "esta misma sesion" "SE SUBIO HACE"
  cerrojo "otra sesion hace 20 min: sube"                        sesion-yo "" "$((T0-1200))\tsesion-otra\t/repo/otro\n" 0 "NOTA=" "SE SUBIO"
  cerrojo "a los 14 min aun para"                                sesion-yo "" "$((T0-840))\tsesion-otra\t/repo/otro\n"  1 "HACE 14 MIN" ""
  cerrojo "un cerrojo ilegible no para (no es una medida)"       sesion-yo "" "basura\tsin\tfecha\n"                  0 "NOTA=" "SE SUBIO"
  # La escritura y la lectura casan, y el fichero es del SITIO, con o sin barra final.
  rm -rf "$CDIR/subidas"
  ( QA_RECIBOS_DIR="$CDIR"; CLAUDE_CODE_SESSION_ID="sesion-a"; SITIO="https://www.ejemplo.test"; REPO="/repo/a"; . "$CER"; cerrojo_escribe "$T0" )
  ( QA_RECIBOS_DIR="$CDIR"; CLAUDE_CODE_SESSION_ID="sesion-b"; OTRA_VEZ=""; SITIO="https://www.ejemplo.test/"; REPO="/repo/b"; . "$CER"; cerrojo_decide "$((T0+30))" ) > "$TMP" 2>&1; rc=$?
  if [ "$rc" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "lo que escribe una sesion lo ve la otra (con y sin barra)"
  else ko=$((ko+1)); printf '  MAL   %s (rc %s)\n' "lo que escribe una sesion lo ve la otra (con y sin barra)" "$rc"; sed 's/^/        /' "$TMP"; fi
  ( QA_RECIBOS_DIR="$CDIR"; CLAUDE_CODE_SESSION_ID="sesion-b"; OTRA_VEZ=""; SITIO="https://otra-web.test/"; REPO="/repo/b"; . "$CER"; cerrojo_decide "$((T0+30))" ) > "$TMP" 2>&1; rc=$?
  if [ "$rc" = 0 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "el cerrojo de un sitio no para otro"
  else ko=$((ko+1)); printf '  MAL   %s (rc %s)\n' "el cerrojo de un sitio no para otro" "$rc"; sed 's/^/        /' "$TMP"; fi
fi
# Y la puerta lo escribe ANTES del subidor y DESPUES del sello (un sello que para no ha subido nada).
LE=$(grep -n 'cerrojo_escribe "\${AHORA_SUBE' "$PUERTA" | head -1 | cut -d: -f1)
LS=$(grep -n '^if ! SELLO_SAL=' "$PUERTA" | head -1 | cut -d: -f1)
LC=$(grep -n '^eval "\$CMD"$' "$PUERTA" | head -1 | cut -d: -f1)
if [ -n "${LE:-}" ] && [ -n "${LS:-}" ] && [ -n "${LC:-}" ] && [ "$LS" -lt "$LE" ] && [ "$LE" -lt "$LC" ]; then
  ok=$((ok+1)); printf '  PASA  %s\n' "el cerrojo se escribe entre el sello y el subidor"
else ko=$((ko+1)); printf '  MAL   %s (sello %s · cerrojo %s · subidor %s)\n' "el cerrojo se escribe entre el sello y el subidor" "${LS:-?}" "${LE:-?}" "${LC:-?}"; fi
rm -rf "$CER" "$CDIR"

# =============================================================================
#  UNA PUERTA QUE SE PARA DE VERDAD (0-ter, 5-nov-2026). Medido esa noche: el chat
#  paro la puerta con TaskStop a las 22:12 («parada, produccion sin cambiar») y
#  subio a las 22:25: en Windows TaskStop mata la orden, no a la puerta. Los bytes
#  de la puerta entre sus marcas; procesos de verdad (uno vivo, uno muerto).
# =============================================================================
PEC="$(mktemp -t encurso-XXXXXXXX)"; PDIR="$(mktemp -d -t recibos-XXXXXXXX)"
A7=$(grep -n '^# >>> puerta-en-curso' "$PUERTA" | head -1 | cut -d: -f1)
B7=$(grep -n '^# <<< puerta-en-curso' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A7:-}" ] || [ -z "${B7:-}" ] || [ "$A7" -ge "$B7" ]; then
  ko=$((ko+1)); echo "  MAL   no encuentro el bloque puerta-en-curso en $PUERTA (marcas movidas o borradas)"
else
  sed -n "${A7},${B7}p" "$PUERTA" > "$PEC"
  sleep 120 & VIVO=$!
  ( exit 0 ) & MUERTO=$!; wait "$MUERTO" 2>/dev/null
  AHORA="$(date +%s)"
  SUB="$PDIR/subidas"; ENC="$SUB/www.ejemplo.test.en-curso"; PAR="$SUB/www.ejemplo.test.parar"
  encurso() { local t; t="$(date +%s)"; mkdir -p "$SUB"; printf '%s\t1\tsesion-otra\t%s\t%s\t%s\n' "$1" "$((t-600))" "$2" "$((t-${3:-60}))" > "$ENC"; }
  pc() { # nombre · rc esperado · TIENE · NO · orden (tras cargar el bloque)
    local n="$1" want="$2" tiene="$3" no="$4" rc bien=1; shift 4
    ( QA_RECIBOS_DIR="$PDIR"; SITIO="https://www.ejemplo.test/"; . "$PEC"; eval "$*" ) > "$TMP" 2>&1; rc=$?
    [ "$rc" = "$want" ] || bien=0
    [ -n "$tiene" ] && ! grep -qF -- "$tiene" "$TMP" && bien=0
    [ -n "$no" ]    &&   grep -qF -- "$no" "$TMP" && bien=0
    if [ "$bien" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s (rc %s, esperaba %s)\n' "$n" "$rc" "$want"; sed 's/^/        /' "$TMP"; fi
  }
  hay() { # nombre · 0|1 (se espera que la condicion se cumpla) · condicion
    if eval "$3"; then r=1; else r=0; fi
    if [ "$r" = "$2" ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$1"; else ko=$((ko+1)); printf '  MAL   %s\n' "$1"; fi
  }
  # --parar: dice la verdad en los cinco estados
  rm -rf "$SUB"
  pc "--parar sin puerta ni subida: 4, y lo dice"            4 "no hay ninguna puerta de https://www.ejemplo.test/ en curso" "YA SUBIO" 'puerta_parar "m"'
  mkdir -p "$SUB"; printf '%s\tsesion-otra\t/repo/x\n' "$(( $(date +%s) - 180 ))" > "$SUB/www.ejemplo.test"
  # 🔴 EL CASO DE ESA NOCHE, visto desde quien para: la puerta ya habia acabado.
  pc "--parar tarde: ninguna en curso, y que la ultima subida fue hace 3 min" 4 "fue hace 3 min" "" 'puerta_parar "m"'
  rm -f "$SUB/www.ejemplo.test"
  encurso "$VIVO" MIDIENDO
  pc "--parar una puerta viva midiendo: 0, NO subira"        0 "NO subira" "YA SUBIO" 'puerta_parar "el revisor dijo VUELVE"'
  hay "y la orden de parar es para ESE proceso, con su motivo" 1 '[ "$(cut -f1,3 "$PAR" 2>/dev/null)" = "$VIVO$(printf "\t")el revisor dijo VUELVE" ]'
  rm -f "$PAR"; encurso "$VIVO" SUBIENDO 20
  pc "--parar mientras sube: 3, produccion YA esta cambiando" 3 "ESTA SUBIENDO desde hace 2" "NO subira" 'puerta_parar "m"'
  rm -f "$PAR"; encurso "$VIVO" "SUBIDO rc=0" 120
  pc "--parar cuando ya subio: 3, y lo dice"                 3 "YA SUBIO hace 2 min" "NO subira" 'puerta_parar "m"'
  rm -f "$PAR"; encurso "$MUERTO" MIDIENDO
  pc "--parar una puerta que ya no existe: 4"                4 "ya no existe" "produccion ha cambiado" 'puerta_parar "m"'
  hay "y borra su fichero" 0 '[ -e "$ENC" ]'
  encurso "$MUERTO" SUBIENDO
  pc "muerta tras empezar a subir: 4, y que produccion cambio" 4 "produccion ha cambiado" "" 'puerta_parar "m"'
  # la puerta, justo antes del subidor
  rm -rf "$SUB"
  pc "con la orden de parar para ESTA puerta: no sube"       1 "PUERTA PARADA con --parar" "" 'mkdir -p "$SUB"; printf "%s\tsesion-x\tel revisor dijo VUELVE\n" "$$" > "$PAR"; puerta_sigue'
  pc "y dice el motivo de quien la paro"                     1 "el revisor dijo VUELVE" "" 'mkdir -p "$SUB"; printf "%s\tsesion-x\tel revisor dijo VUELVE\n" "$$" > "$PAR"; puerta_sigue'
  pc "una orden de parar para OTRA puerta no la para"        0 "" "PARADA" 'mkdir -p "$SUB"; printf "%s\tsesion-x\tm\n" "$VIVO" > "$PAR"; puerta_sigue'
  rm -rf "$SUB"
  # 🔴 EL CASO DE ESA NOCHE, visto desde la puerta: la orden que la lanzo murio (TaskStop).
  pc "huerfana (la orden que la lanzo murio): no sube"       1 "LA ORDEN QUE LANZO ESTA PUERTA YA NO EXISTE" "" "PUERTA_PADRE=$MUERTO; puerta_sigue"
  pc "con la orden que la lanzo viva: sube"                  0 "" "YA NO EXISTE" "PUERTA_PADRE=$VIVO; puerta_sigue"
  pc "padre 1 (no es de esta shell): no se puede mirar, no para" 0 "" "YA NO EXISTE" "PUERTA_PADRE=1; puerta_sigue"
  # de punta a punta: lo que escribe --parar lo ve la puerta
  pc "--parar escribe y la puerta en curso lo ve: no sube"   1 "PUERTA PARADA" "" 'PUERTA_PADRE=1; en_curso_escribe MIDIENDO; puerta_parar "a mano" >/dev/null; puerta_sigue'
  rm -rf "$SUB"
  pc "al salir se borra lo suyo"                             0 "" "" 'en_curso_escribe MIDIENDO; en_curso_fin; [ ! -e "$ENC" ]'
  encurso "$VIVO" MIDIENDO
  pc "y no lo de otra puerta"                                0 "" "" 'en_curso_fin; [ -e "$ENC" ]'
  kill "$VIVO" 2>/dev/null; wait "$VIVO" 2>/dev/null
fi
# Y en la puerta, el orden: SUBIENDO antes de mirar la orden de parar, las dos antes
# del subidor; el recibo del paso 1 apuntado tras el paso 1; --parar antes de medir nada.
L_SUB=$(grep -n '^declare -F en_curso_escribe >/dev/null && en_curso_escribe SUBIENDO$' "$PUERTA" | head -1 | cut -d: -f1)
L_SIG=$(grep -n '^if declare -F puerta_sigue >/dev/null && ! puerta_sigue; then$' "$PUERTA" | head -1 | cut -d: -f1)
L_EVA=$(grep -n '^eval "\$CMD"$' "$PUERTA" | head -1 | cut -d: -f1)
L_GAT=$(grep -n '^GATE=\$?$' "$PUERTA" | head -1 | cut -d: -f1)
L_PIN=$(grep -n '^RECIBO_SELLO_1=' "$PUERTA" | head -1 | cut -d: -f1)
L_REV=$(grep -n '^RECIBO_SELLO_AHORA=' "$PUERTA" | head -1 | cut -d: -f1)
L_PAR=$(grep -n '^  puerta_parar "\$PARAR"; exit \$?$' "$PUERTA" | head -1 | cut -d: -f1)
L_PA1=$(grep -n '^linea; echo "  1 · el recibo"; linea$' "$PUERTA" | head -1 | cut -d: -f1)
hay "en la puerta: SUBIENDO, despues la orden de parar, despues el subidor" 1 '[ -n "$L_SUB" ] && [ -n "$L_SIG" ] && [ -n "$L_EVA" ] && [ "$L_SUB" -lt "$L_SIG" ] && [ "$L_SIG" -lt "$L_EVA" ]'
hay "el recibo del paso 1 se apunta tras el paso 1 y se compara antes de subir" 1 '[ -n "$L_GAT" ] && [ -n "$L_PIN" ] && [ -n "$L_REV" ] && [ "$L_GAT" -lt "$L_PIN" ] && [ "$L_PIN" -lt "$L_REV" ] && [ "$L_REV" -lt "$L_EVA" ]'
hay "--parar se atiende antes de medir nada" 1 '[ -n "$L_PAR" ] && [ -n "$L_PA1" ] && [ "$L_PAR" -lt "$L_PA1" ]'
hay "la trampa de salida de 3-bis no pisa la de la puerta en curso" 1 'grep -q "^trap .*en_curso_fin.* EXIT$" "$PUERTA"'
rm -rf "$PEC" "$PDIR"

# =============================================================================
#  LAS PAGINAS DE ESTA SUBIDA, ¿SE SIRVEN? (4-0, 5-nov-2026). Medido ese dia: una
#  subida cerro «G11 lo ha verificado» con sus dos paginas NUEVAS en 404. G11 da
#  la lista entera (G11_NO_HALLADOS, su banco: recibo-404); aqui se cruza con
#  CAMBIADAS_TODAS. Los bytes de la puerta entre sus marcas.
# =============================================================================
ALT="$(mktemp -t altas-XXXXXXXX)"; ADIR="$(mktemp -d -t altas-XXXXXXXX)"
A6=$(grep -n '^# >>> altas-servidas' "$PUERTA" | head -1 | cut -d: -f1)
B6=$(grep -n '^# <<< altas-servidas' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A6:-}" ] || [ -z "${B6:-}" ] || [ "$A6" -ge "$B6" ]; then
  ko=$((ko+1)); echo "  MAL   no encuentro el bloque altas-servidas en $PUERTA (marcas movidas o borradas)"
else
  sed -n "${A6},${B6}p" "$PUERTA" > "$ALT"
  altas() { # nombre · CAMBIADAS_TODAS · lo que da G11 («-» = no dio fichero) · rc|FALLA|NO MEDIDO esperados
    local n="$1" got
    ( . "$ALT"; CAMBIADAS_TODAS="$2"; f="$ADIR/nohay.tsv"; rm -f "$f"
      [ "$3" = "-" ] || printf '%b' "$3" > "$f"
      altas_juzga "$f"; r=$?; printf '%s|%s|%s\n' "$r" "$ALTAS_FALLA" "$ALTAS_NM" ) > "$TMP" 2>&1
    got="$(cat "$TMP")"
    if [ "$got" = "$4" ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s\n        sale:     %s\n        esperaba: %s\n' "$n" "$got" "$4"; fi
  }
  # 🔴 EL CASO DEL 5-NOV: dos altas en 404.
  altas "dos altas en 404: FALLA, y las nombra"          "guias/a.html guias/b.html" "guias/a.html\t404\nguias/b.html\t404\n" "1|guias/a.html (404), guias/b.html (404)|"
  altas "un 410 en una cambiada: FALLA"                  "index.html"                "index.html\t410\n"                     "1|index.html (410)|"
  altas "un 200 con otros bytes no es servido: FALLA"    "guias/a.html"              "guias/a.html\t200\n"                   "1|guias/a.html (200)|"
  altas "negado (403) no es ausente: NO MEDIDO"          "guias/a.html"              "guias/a.html\t403\n"                   "0||guias/a.html (403)"
  altas "sin respuesta (0) y 503: NO MEDIDO"             "a.html b.html"             "a.html\t0\nb.html\t503\n"              "0||a.html (0), b.html (503)"
  altas "pasado el tope de G11: NO MEDIDO"               "guias/a.html"              "guias/a.html\t-\n"                     "0||guias/a.html (pasado el tope de G11)"
  altas "uno falta y otro negado: FALLA y NO MEDIDO"     "a.html b.html"             "a.html\t404\nb.html\t403\n"            "1|a.html (404)|b.html (403)"
  # NEGATIVOS: sin estos, el aviso no valdria nada
  altas "un 404 en un fichero que NO cambio: no es de esta subida" "guias/a.html"    "viejo.html\t404\n"                     "0||"
  altas "la ruta entera, no un trozo"                    "a.html"                    "guias/a.html\t404\n"                   "0||"
  altas "lista vacia: todo servido"                      "guias/a.html"              ""                                      "0||"
  altas "sin paginas de esta subida: nada que mirar"     ""                          "-"                                     "0||"
  # 🔴 Sin lista de G11 no es «no falta nada»: es «nadie lo ha dicho».
  altas "G11 sin lista: NO MEDIDO, no verde"             "guias/a.html"              "-"                                     "0||G11 no dio su lista de no hallados"
fi
rm -rf "$ALT" "$ADIR"

# =============================================================================
#  EL CIERRE (5-nov-2026): una linea al final, que dice lo que se midio. Antes:
#  «El despliegue esta hecho y G11 lo ha verificado» con el navegador en NO
#  MEDIDO sobre las paginas nuevas. Los bytes de la puerta entre sus marcas.
# =============================================================================
CIE="$(mktemp -t cierre-XXXXXXXX)"
A7=$(grep -n '^# >>> cierre-de-la-subida' "$PUERTA" | head -1 | cut -d: -f1)
B7=$(grep -n '^# <<< cierre-de-la-subida' "$PUERTA" | head -1 | cut -d: -f1)
if [ -z "${A7:-}" ] || [ -z "${B7:-}" ] || [ "$A7" -ge "$B7" ]; then
  ko=$((ko+1)); echo "  MAL   no encuentro el bloque cierre-de-la-subida en $PUERTA (marcas movidas o borradas)"
else
  sed -n "${A7},${B7}p" "$PUERTA" > "$CIE"
  cierra() { # nombre · variables del paso (eval) · el CIERRE TIENE que empezar asi · y decir · y NO decir
    local n="$1" got bien=1
    ( unset ENL_RC ENL_NM NAV_FALLOS NAV_CORRIO NAV_BASURA NAV_NM_CAMB URLS_FORM ALTAS_NM REDIR SIN_NAVEGADOR CAMBIADAS_FUERA
      . "$CIE"; eval "$2"; cierre_dice; printf '%s\n' "$CIERRE" ) > "$TMP" 2>&1
    got="$(cat "$TMP")"
    case "$got" in "$3"*) ;; *) bien=0 ;; esac
    [ -n "$4" ] && ! grep -qF -- "$4" "$TMP" && bien=0
    [ -n "$5" ] &&   grep -qF -- "$5" "$TMP" && bien=0
    grep -qi 'verificado' "$TMP" && bien=0      # la palabra no sale nunca del cierre
    if [ "$bien" = 1 ]; then ok=$((ok+1)); printf '  PASA  %s\n' "$n"
    else ko=$((ko+1)); printf '  MAL   %s\n        sale:     %s\n        esperaba: %s… (%s)\n' "$n" "$got" "$3" "$4"; fi
  }
  VERDE="ENL_RC=0; NAV_CORRIO=1; NAV_FALLOS=0; NAV_BASURA=0; URLS_FORM=/contacto"
  cierra "todo medido y en verde: PASA"                          "$VERDE"                                   "PASA" "medido en lo servido" "formularios"
  cierra "sin formularios declarados: PASA, y lo dice"           "$VERDE; URLS_FORM="                       "PASA" "el repo no declara ninguno" ""
  # 🔴 EL CASO DEL 5-NOV: el navegador no midio las paginas nuevas.
  cierra "paginas de esta subida sin medir: NO MEDIDO, y las nombra" "$VERDE; NAV_BASURA=2; NAV_NM_CAMB='/guias/a /guias/b'" "NO MEDIDO" "paginas de esta subida: /guias/a /guias/b" "PASA"
  cierra "otra medida sin respuesta: NO MEDIDO"                  "$VERDE; NAV_BASURA=1"                     "NO MEDIDO" "1 medida(s) de navegador sin respuesta" "PASA"
  cierra "el navegador no corrio (sin host): NO MEDIDO"          "ENL_RC=0; URLS_FORM=/c"                   "NO MEDIDO" "(no corrio)" "PASA"
  cierra "SIN_NAVEGADOR=1: NO MEDIDO (un hueco declarado sigue siendo un hueco)" "ENL_RC=0; SIN_NAVEGADOR=1" "NO MEDIDO" "SIN_NAVEGADOR=1" "PASA"
  cierra "el enlazado no pudo rastrear: NO MEDIDO"               "$VERDE; unset ENL_RC; ENL_NM='enlazado (el rastreo fallo)'" "NO MEDIDO" "el rastreo fallo" ""
  cierra "G11 negado en una pagina nueva: NO MEDIDO"             "$VERDE; ALTAS_NM='guias/a.html (403)'"   "NO MEDIDO" "G11 no pudo mirar: guias/a.html (403)" ""
  cierra "cambiadas fuera del tope: NO MEDIDO"                   "$VERDE; CAMBIADAS_FUERA=3"                "NO MEDIDO" "3 pagina(s) cambiada(s) fuera del tope" ""
  cierra "el navegador en rojo: FALLA"                           "$VERDE; NAV_FALLOS=2"                     "FALLA" "2 medida(s) de navegador" ""
  cierra "el enlazado en rojo: FALLA"                            "$VERDE; ENL_RC=1"                         "FALLA" "el enlazado de lo servido" ""
  cierra "FALLA y sin medir: manda FALLA y dice lo otro"         "$VERDE; NAV_FALLOS=1; ALTAS_NM='a.html (0)'" "FALLA" "y sin medir: G11 no pudo mirar" ""
  cierra "arbol de redirecciones: PASA sin navegador ni enlazado" "REDIR=1"                                 "PASA" "redirecciones" "NO MEDIDO"
fi
rm -f "$CIE"
# Y nadie mas en la puerta dice «verificado» de una subida (lo hacian tres lineas).
VER=$(grep -nE '^[[:space:]]*echo .*(G11 lo ha verificado|desplegado y verificado)' "$PUERTA" | head -3)
if [ -z "$VER" ]; then ok=$((ok+1)); printf '  PASA  %s\n' "ninguna linea de la puerta dice «verificado» de la subida"
else ko=$((ko+1)); printf '  MAL   %s\n' "ninguna linea de la puerta dice «verificado» de la subida"; printf '%s\n' "$VER" | sed 's/^/        /'; fi

rm -f "$TMP" "$VACIO" "$ANT" "$RET"
echo
printf '  %d bien · %d mal\n' "$ok" "$ko"
# 26-sep-2026 · run-all.sh no sabia leer «bien · mal» y contaba este banco como
# PASA con CERO casos («no he sabido leer su recuento»). En DOS lineas y con el
# formato que lee: en una sola, `[0-9]+ +MAL` casaria con el recuento de verdes.
printf '  OK %d\n' "$ok"
printf '  MAL %d\n' "$ko"
[ "$ko" = 0 ]
