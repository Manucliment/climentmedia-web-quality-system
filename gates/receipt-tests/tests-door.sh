#!/usr/bin/env bash
# =============================================================================
#  tests-door.sh · G11 (lo servido) y deploy.sh (la puerta)
# =============================================================================
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/receipt-tests/tests-door.sh"
#
#  🔴 NO TOCA NINGUNA WEB VIVA. Levanta un servidor de pruebas en 127.0.0.1 y
#     mide contra el. Asi se puede probar el caso que importa —«produccion
#     sirve una cosa distinta de la que se midio»— fabricandolo a mano, en vez
#     de esperar a que vuelva a pasar en una web con leads reales.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
REF="$(cd .. && pwd)"
T="${TEMP:-/tmp}/puerta-pruebas-$$"
# Puerto distinto en cada corrida: un puerto fijo ya estaba ocupado por el
# servidor local de otra sesion, y las pruebas midieron esa web durante media
# hora sin dar un solo error. Ver el comentario de test-server.pl.
PUERTO=$(( 8400 + ($$ % 900) ))
# las pruebas NO escriben en el historial de verdad
export QA_RECIBOS_DIR="$T/historial-de-pruebas"
OK=0; MAL=0

r() { local nombre="$1" esp="$2"; shift 2
  local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$esp" ]; then OK=$((OK+1)); printf '  PASA  %-52s (exit %s)\n' "$nombre" "$rc"
  else MAL=$((MAL+1)); printf '  FALLA %-52s (exit %s, esperaba %s)\n' "$nombre" "$rc" "$esp"
       printf '%s\n' "$out" | sed 's/^/          /'; fi
  ULTIMA="$out"; }
contiene() { if printf '%s' "$ULTIMA" | grep -qF -- "$2"; then OK=$((OK+1)); printf '  PASA  %-52s\n' "$1"
  else MAL=$((MAL+1)); printf '  FALLA %-52s (no dice: %s)\n' "$1" "$2"
       printf '%s\n' "$ULTIMA" | sed 's/^/          /'; fi; }

rm -rf "$T"; mkdir -p "$T/repo/_deploy" "$T/repo/sub" "$T/servido"
printf 'portada v1\n'   > "$T/repo/index.html"
printf 'a{color:red}\n' > "$T/repo/styles.css"
printf 'hija\n'         > "$T/repo/sub/index.html"
printf 'notas\n'        > "$T/repo/CLAUDE.md"
cp -r "$T/repo/index.html" "$T/repo/styles.css" "$T/servido/"
mkdir -p "$T/servido/sub"; cp "$T/repo/sub/index.html" "$T/servido/sub/"

# ⚠️ Heredoc SIN comillas a proposito: el puerto cambia en cada corrida y las
#    URLs del `alcance` tienen que ser las de ESTE servidor, o no casan con los
#    ficheros del arbol y el mapeo no prueba nada. Dentro no hay ningun otro
#    `$` ni backtick, que es lo que haria peligrosa la expansion.
cat > "$T/qa-verde.json" <<JSON
{"sitio":"http://127.0.0.1:${PUERTO}","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":0,"no_verificado":0,"pasa":50},
 "instrumento":{"perl":"5.042002","dom":"qa.json"},
 "alcance":{"sitio_urls":2,"lista_urls":2,"documentos":2,"por_lente":{
  "SEO":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""},
  "RENDIMIENTO":{"miradas":1,"urls":["http://127.0.0.1:${PUERTO}"],"nota":"muestra"},
  "ACCESIBILIDAD":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""},
  "MEDICION":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""},
  "ESTRUCTURA":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""}}},
 "comprobaciones":[
  {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
  {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
  {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},
  {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
  {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}
JSON
cat > "$T/qa-rojo.json" <<'JSON'
{"sitio":"http://127.0.0.1:0","veredicto":"FALLA",
 "resumen":{"fallo":1,"aviso":0,"no_verificado":0,"pasa":40},
 "instrumento":{"perl":"5.042002","dom":"qa.json"},
 "comprobaciones":[
  {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
  {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
  {"lente":"ACCESIBILIDAD","id":"A11-04","estado":"FALLO","titulo":"contraste"},
  {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
  {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}
JSON
cat > "$T/qa-nv.json" <<JSON
{"sitio":"http://127.0.0.1:${PUERTO}","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":0,"no_verificado":2,"pasa":40},
 "instrumento":{"perl":"5.042002","dom":null},
 "alcance":{"sitio_urls":2,"lista_urls":2,"documentos":2,"por_lente":{
  "SEO":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""},
  "RENDIMIENTO":{"miradas":1,"urls":["http://127.0.0.1:${PUERTO}"],"nota":"muestra"},
  "ACCESIBILIDAD":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""},
  "MEDICION":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""},
  "ESTRUCTURA":{"miradas":2,"urls":["http://127.0.0.1:${PUERTO}","http://127.0.0.1:${PUERTO}/sub"],"nota":""}}},
 "comprobaciones":[
  {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
  {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
  {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},
  {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
  {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"secciones"},
  {"lente":"ESTRUCTURA","id":"EST-06","estado":"NV","titulo":"densidad"},
  {"lente":"ESTRUCTURA","id":"EST-08","estado":"NV","titulo":"grafo"}]}
JSON
# 🔴 EST-01 en PASA se anadio el 13-ago-2026, y no es decoracion. Antes este
#    fixture dejaba la lente ESTRUCTURA con SUS DOS comprobaciones en NV, y con
#    la regla nueva de §18 -«una lente que corrio y no midio nada no es PASA»-
#    el recibo pasa a sellarla NO VERIFICADA y la puerta lo rechaza en el paso 1.
#    Con eso, los bloques 8 y 8-bis dejaban de probar lo suyo: se paraban antes
#    de llegar al `--aun-asi`. El escenario que quieren medir es el REAL -unas
#    cuantas comprobaciones sin mirar dentro de una lente que si midio-, no una
#    lente entera a oscuras, que ya se prueba en tests-coverage.sh.
#    Lo cazo `run-all.sh` en la corrida siguiente al cambio: 7 FALLA.

# ── arrancar el servidor de pruebas y COMPROBAR QUE ES EL MIO ────────────────
#  🔴 No basta con que conteste algo. Un 200 solo dice que ALGUIEN contesta en
#     ese puerto. Se pide un fichero centinela con un valor unico de esta
#     corrida y se comprueba que vuelve ESE valor: si vuelve otra cosa, hay otro
#     servidor delante y todo lo que midieramos despues seria de otra web.
CENTINELA="centinela-$$-$(date +%s)"
printf '%s\n' "$CENTINELA" > "$T/servido/_centinela.txt"
perl "$REF/receipt-tests/test-server.pl" "$T/servido" "$PUERTO" >"$T/srv.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
sleep 1
RESP="$(curl -sS --max-time 5 "http://127.0.0.1:$PUERTO/_centinela.txt" 2>/dev/null)"
if [ "$RESP" != "$CENTINELA" ]; then
  echo "  NO ARRANCO MI SERVIDOR DE PRUEBAS en el puerto $PUERTO."
  echo "  Pedi el centinela y me contestaron: '${RESP:0:60}'"
  echo "  Log del servidor: $(cat "$T/srv.log" 2>/dev/null)"
  echo "  🔴 Sin esto las pruebas medirian otra web y algunas PASARIAN igual."
  exit 2
fi
echo "  (servidor de pruebas propio verificado en 127.0.0.1:$PUERTO)"
rm -f "$T/servido/_centinela.txt"

echo "==============================================================================="
echo "  G11 Y LA PUERTA · pruebas (contra 127.0.0.1, ninguna web viva)"
echo "==============================================================================="

echo
echo "-- 1 · POSITIVO: lo servido ES lo del recibo ----------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "G11 pasa"                                0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "cuenta los identicos"               "identicos 3"
contiene "0 distintos"                        "distintos 0"

echo
echo "-- 2 · NEGATIVO: produccion sirve OTRA COSA (el caso de site-d) -------------"
# Exactamente el fallo del 10-ago: el arreglo esta en el repo, produccion sirve
# el CSS viejo, y todos los demas gates en verde.
printf 'a{color:blue}\n' > "$T/repo/styles.css"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "G11 lo caza"                             1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "nombra el fichero"                  "styles.css"
contiene "dice que el md5 no cuadra"          "md5 distinto"
contiene "lo dice claro"                      "PRODUCCION NO SIRVE LO QUE SE MIDIO"

echo
echo "-- 3 · tras «desplegar», G11 vuelve a verde -----------------------------------"
cp "$T/repo/styles.css" "$T/servido/styles.css"
r "ahora si"                                0 perl "$REF/receipt.pl" --servido --repo "$T/repo"

echo
echo "-- 4 · NEGATIVO: un fichero del arbol que no esta subido ----------------------"
printf 'nueva pagina\n' > "$T/repo/nueva.html"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "no lo da por bueno"                      0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "lo marca como no hallado"           "NO HALLADO nueva.html"
contiene "y avisa de que eso no es aprobar"   "NO he encontrado, y eso NO es un aprobado"
rm "$T/repo/nueva.html"

echo
echo "-- 5 · LA PUERTA: sin deploy.conf --------------------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "se niega y explica que falta"            2 bash "$REF/deploy.sh" "$T/repo"
contiene "nombra el fichero que falta"        "deploy.conf"

# 🔴 `SIN_NAVEGADOR=1` en el fixture, y NO es para que el banco corra mas
#    rapido: el paso 6 mide con Chrome DESDE EL SERVIDOR, y
#    `http://127.0.0.1:$PUERTO` visto desde el servidor es el localhost DEL
#    SERVIDOR -- otra maquina. Medir ahi no daria un numero peor: daria el
#    numero de otra cosa, o 60 s de espera por llamada. Un hueco declarado sigue
#    siendo un hueco, y sus dos ramas tienen sus casos en el bloque 12.
cat > "$T/repo/_deploy/deploy.conf" <<CONF
SITIO=http://127.0.0.1:$PUERTO
SUBIDA=_deploy/subir.sh
SIN_NAVEGADOR=1
CONF
cat > "$T/repo/_deploy/subir.sh" <<'SH'
#!/usr/bin/env bash
# "subida" de mentira: copia el arbol a la carpeta que sirve el servidor
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
cp -r index.html styles.css sub "$SERVIDO/" 2>/dev/null
echo "  (subida de pruebas hecha)"
SH

echo
echo "-- 6 · LA PUERTA: recibo en rojo ---------------------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-rojo.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "no llega ni a ensenar el comando"        1 bash "$REF/deploy.sh" "$T/repo" --subir
contiene "cita la regla"                      "EN ROJO NO SE DESPLIEGA"
contiene "dice como arreglarlo"               "qa-master.pl"

echo
echo "-- 7 · LA PUERTA: verde, sin --subir = ensayo ---------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "ensaya y no sube"                        0 bash "$REF/deploy.sh" "$T/repo"
contiene "avisa de que no sube"               "NO se sube nada"
contiene "ensena el comando exacto"           "subir.sh"

echo
echo "-- 8 · LA PUERTA: verde con cosas SIN MIRAR, sin --aun-asi --------------------"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-nv.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "se para y pide que conste el motivo"     1 bash "$REF/deploy.sh" "$T/repo" --subir
contiene "lo dice"                            "NO VERIFICADO NO ES UN APROBADO"
contiene "nombra lo que no se miro"           "EST-06"

echo
echo "-- 8-bis · EL --aun-asi SE ESCRIBE (13-ago-2026) ------------------------------"
# 🔴 EL DEFECTO: la puerta prometia -y sigue prometiendo cuatro lineas mas
#    arriba- que el motivo «queda en el historial con tu motivo al lado», y lo
#    unico que hacia era un `echo`. MEDIDO en el historial real: 621 acciones,
#    467 QA + 153 SERVIDO, CERO NOTA. Tres despliegues firmados el mismo dia se
#    perdieron enteros.
#    Lo que se prueba aqui es que la linea EXISTE y que lleva la lista de huecos,
#    no solo el motivo: sin la lista no se puede ver CUAL se repite, que es lo
#    unico para lo que sirve el registro.
HIST="$QA_RECIBOS_DIR/history.tsv"
# ⚠️ `grep -c` imprime 0 Y sale 1 cuando no casa, asi que `grep -c ... || echo 0`
#    escupe DOS lineas ("0\n0") y `[ -gt ]` revienta con «integer expected».
#    Me paso en la primera version de esta misma prueba. Un contador siempre
#    devuelve UN numero, y para eso esta esta funcion.
nnota() { [ -f "$HIST" ] || { printf '0'; return; }; grep -c 'NOTA' "$HIST" 2>/dev/null | head -1 | tr -dc '0-9'; }
ANTES=$(nnota); ANTES="${ANTES:-0}"
export SERVIDO="$T/servido"
cp "$T/repo/index.html" "$T/servido/index.html" 2>/dev/null
r "sube firmando el hueco"                  0 bash "$REF/deploy.sh" "$T/repo" --subir \
    --aun-asi "no hay navegador en esta maquina"
contiene "dice que lo ha anotado"             "anotado en el historial"
DESPUES="$(nnota)"; DESPUES="${DESPUES:-0}"
if [ "$DESPUES" -gt "$ANTES" ]; then OK=$((OK+1)); printf '  PASA  %-52s\n' "la linea NOTA esta en el historial"
else MAL=$((MAL+1)); printf '  FALLA %-52s (NOTA: %s -> %s)\n' "la linea NOTA esta en el historial" "$ANTES" "$DESPUES"; fi
if grep -q 'AUN-ASI \[' "$HIST" 2>/dev/null && grep -q 'no hay navegador en esta maquina' "$HIST" 2>/dev/null; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "lleva la lista de huecos Y el motivo"
else MAL=$((MAL+1)); printf '  FALLA %-52s\n' "lleva la lista de huecos Y el motivo"
     grep 'NOTA' "$HIST" 2>/dev/null | tail -2 | sed 's/^/          /'; fi
# NEGATIVO: en ENSAYO no se anota. Si se anotara, el historial contaria firmas
# que nadie llego a hacer, y el numero dejaria de significar nada.
ANTES2="$(nnota)"; ANTES2="${ANTES2:-0}"
r "en ensayo no sube y no anota"            0 bash "$REF/deploy.sh" "$T/repo" \
    --aun-asi "esto es solo un ensayo"
DESPUES2="$(nnota)"; DESPUES2="${DESPUES2:-0}"
if [ "$DESPUES2" = "$ANTES2" ]; then OK=$((OK+1)); printf '  PASA  %-52s\n' "el ensayo NO ensucia el historial"
else MAL=$((MAL+1)); printf '  FALLA %-52s (%s -> %s)\n' "el ensayo NO ensucia el historial" "$ANTES2" "$DESPUES2"; fi

echo
echo "-- 9 · POSITIVO COMPLETO: gate -> subida -> G11 -------------------------------"
printf 'portada v2 desplegada\n' > "$T/repo/index.html"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
export SERVIDO="$T/servido"
r "sube y verifica lo servido"              0 bash "$REF/deploy.sh" "$T/repo" --subir
contiene "hizo la subida"                     "subida de pruebas hecha"
contiene "corrio G11"                         "G11"
contiene "termina en verde"                   "desplegado y verificado"
# 🔴 13-ago-2026 · LA PUERTA CORRE EL GATE DE ENLAZADO, y no como consejo.
#    Antes de hoy invocaba UN gate de los seis (receipt.pl); los otros se
#    imprimian como texto y dependian de que alguien se acordara de correrlos.
#    Se comprueba que el paso 5 EXISTE, que produce un veredicto, y -lo que de
#    verdad importa- que ese veredicto queda ANOTADO: si solo se imprimiera,
#    manana nadie podria contar cuantas veces se desplego con el grafo roto.
contiene "corre el gate de enlazado"          "5 · el enlazado"
contiene "y da un veredicto"                  "VEREDICTO"
if grep -q 'ENLAZADO ' "$HIST" 2>/dev/null; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "el veredicto del enlazado queda anotado"
else MAL=$((MAL+1)); printf '  FALLA %-52s\n' "el veredicto del enlazado queda anotado"
     tail -3 "$HIST" 2>/dev/null | sed 's/^/          /'; fi

# 🔴 14-ago-2026 · Y EL SEGUNDO GATE CABLEADO: la spec contra el arbol (2-bis).
#    El repo de pruebas NO declara MODO_SPEC, asi que lo que se comprueba aqui
#    es el caso mas importante de los dos: **que el hueco se DIGA**. Un gate que
#    no se puede correr y no lo cuenta se lee como un gate que paso -- y eso es
#    exactamente la enfermedad que esta puerta existe para curar.
contiene "corre el paso de la spec"           "2-bis"
contiene "y dice por que no la ha medido"     "no declara MODO_SPEC"
if grep -q 'SPEC ' "$HIST" 2>/dev/null; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "el hueco de la spec queda anotado"
else MAL=$((MAL+1)); printf '  FALLA %-52s\n' "el hueco de la spec queda anotado"
     tail -3 "$HIST" 2>/dev/null | sed 's/^/          /'; fi

# Con el modo declarado y una spec de verdad, el paso corre y da veredicto.
# ⚠️ Estas dos comprobaciones son sobre la SALIDA y no sobre el historial, y la
#    razon es un fallo que este mismo banco cazo el dia que se escribio el paso:
#    anotaba tambien en los ENSAYOS. El historial es el registro de lo que se ha
#    PUBLICADO; el ensayo enseña y no escribe. Lo anotado se comprueba arriba,
#    en la corrida con --subir.
echo "MODO_SPEC=greenfield" >> "$T/repo/_deploy/deploy.conf"
mkdir -p "$T/repo/_spec"
printf '{"sitio":"http://127.0.0.1","nombre":"Pruebas"}\n' > "$T/repo/_spec/site.json"
ANTES3="$(nnota)"; ANTES3="${ANTES3:-0}"
r "corre la spec con el modo declarado"     0 bash "$REF/deploy.sh" "$T/repo"
contiene "dice el modo que usa"               "modo greenfield"
contiene "y da un veredicto de la spec"       "VEREDICTO"
DESPUES3="$(nnota)"; DESPUES3="${DESPUES3:-0}"
if [ "$DESPUES3" = "$ANTES3" ]; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "el ensayo de la spec tampoco ensucia el historial"
else MAL=$((MAL+1)); printf '  FALLA %-52s (%s -> %s)\n' "el ensayo de la spec tampoco ensucia el historial" "$ANTES3" "$DESPUES3"; fi

echo
echo "-- 10 · NEGATIVO: la subida no sube lo que dice (SUBIDA parcial) --------------"
# El caso de site-d/_deploy/subir-css.sh usado como SUBIDA: sube el CSS y
# nada mas. El gate de despues tiene que verlo.
cat > "$T/repo/_deploy/subir.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
cp styles.css "$SERVIDO/"
echo "  (solo he subido el CSS)"
SH
printf 'portada v3 que no se sube\n' > "$T/repo/index.html"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "G11 caza la subida parcial"              1 bash "$REF/deploy.sh" "$T/repo" --subir
contiene "lo dice sin rodeos"                 "PRODUCCION NO SIRVE ESO"

echo
echo "-- 12 · PASO 6: lo que solo se ve con un navegador ----------------------------"
# 🔴 POR QUE HAY CASOS DE ALGO QUE NO BLOQUEA. Este paso mide la maqueta, la
#    densidad y el formulario de lo servido, y hasta hoy los tres gates estaban
#    en `deploy.sh` SOLO DENTRO DE UN COMENTARIO: `grep` los encontraba y no
#    los ejecutaba nadie. Lo que hay que fijar aqui no es el veredicto -eso
#    depende de la web- sino que **el paso no se salte en silencio**: sus dos
#    ramas de «no he medido» tienen que decirlo y quedar anotadas.
# Se repara el subir.sh, que el bloque 10 dejo subiendo solo el CSS.
cat > "$T/repo/_deploy/subir.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
cp -r index.html styles.css sub "$SERVIDO/" 2>/dev/null
echo "  (subida de pruebas hecha)"
SH
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "declarado SIN_NAVEGADOR, sube igual"     0 bash "$REF/deploy.sh" "$T/repo" --subir
contiene "y dice que no lo ha medido"         "SIN_NAVEGADOR=1"
# ⚠️ Se comprueba en el HISTORIAL, no en `.qa-recibo`: `--anotar` escribe alli.
#    Mi primera version miraba el recibo, salio FALLA, y el fallo era del caso
#    -no del paso-. Es la misma trampa de mirar el fichero equivocado y leer el
#    cero como una ausencia.
grep -q "NAVEGADOR no medido: SIN_NAVEGADOR=1" "$QA_RECIBOS_DIR/history.tsv" \
  && { OK=$((OK+1)); echo "  PASA  el hueco declarado queda ANOTADO en el historial"; } \
  || { MAL=$((MAL+1)); echo "  FALLA el hueco declarado NO se anota"; }

# La otra rama: el repo NO lo declara y el host no existe. Tiene que decirlo y
# anotarlo, no callar y aparentar que se midio. NAV_HOST inventado a proposito
# para no depender de la red del que corra el banco.
perl -i -pe 's/^SIN_NAVEGADOR=1\n$//' "$T/repo/_deploy/deploy.conf"
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "sin host de medida, sube y lo dice"      0 env NAV_HOST=no-existe-este-host.invalid \
                                              bash "$REF/deploy.sh" "$T/repo" --subir
contiene "nombra el host al que no llega"     "no-existe-este-host.invalid"
grep -q "NAVEGADOR no medido: sin no-existe-este-host.invalid" "$QA_RECIBOS_DIR/history.tsv" \
  && { OK=$((OK+1)); echo "  PASA  la falta de host queda ANOTADA en el historial"; } \
  || { MAL=$((MAL+1)); echo "  FALLA la falta de host NO se anota"; }

echo
echo "-- 13 · PASO 2-ter: no perder texto del cliente -------------------------------"
# 🔴 EL DEFECTO QUE LO TRAJO: remaquetando site-c.example, **10 paginas
#    perdian hasta 207 palabras del cliente**. Ningun gate lo veia: la pagina
#    seguia siendo HTML valido, seccionada y verde. `same-text.pl` lo cazo, y
#    llevaba desde el 14-ago sin que lo corriera nadie.
#    VA ANTES DE SUBIR porque es el unico momento con LAS DOS versiones
#    delante: despues, la de antes ya no esta y la pregunta no se puede hacer.
cat > "$T/repo/index.html" <<'H'
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Portada</title></head>
<body><main><h1>Consulta de hipnosis</h1>
<p>Trabajo con personas que quieren recuperar una relacion y no saben por donde empezar.</p>
<p>La primera sesion dura noventa minutos y sirve para ver si puedo ayudarte.</p>
</main></body></html>
H
cat > "$T/repo/_deploy/subir.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
cp -r index.html styles.css sub "$SERVIDO/" 2>/dev/null
echo "  (subida de pruebas hecha)"
SH
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "primera subida, deja la version de referencia" 0 bash "$REF/deploy.sh" "$T/repo" --subir

# La REMAQUETACION que se come un parrafo: misma pagina, otra maqueta, y el
# segundo parrafo desaparecido. Es la forma exacta del defecto real.
cat > "$T/repo/index.html" <<'H'
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Portada</title></head>
<body><main><section><h1>Consulta de hipnosis</h1>
<p>Trabajo con personas que quieren recuperar una relacion y no saben por donde empezar.</p>
</section></main></body></html>
H
perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
     --sitio "http://127.0.0.1:$PUERTO" >/dev/null
r "caza que la remaqueta se come un parrafo"  0 bash "$REF/deploy.sh" "$T/repo" --subir
contiene "dice cuantas palabras faltan"        "FALTAN"
contiene "y las nombra"                        "noventa"
# 🔴 EL CONTROL DE QUE NO COMPARA DE MENOS, y no es teorico: en el primer
#    despliegue real (17-ago) este paso comparo **1 pagina de 19** en site-a
#    -sus URLs van SIN barra final- y reporto «0 con perdida». Un check que no
#    encuentra las paginas cuenta las que faltan como NUEVAS y su silencio se
#    lee como un aprobado. El arreglo prueba las dos formas de URL; esta linea
#    vigila el sintoma, que es el numero.
contiene "y compara TODAS las paginas, no una"  "2 paginas comparadas"
# NO bloquea todavia, a proposito e igual que 2-bis: quitar una seccion aposta
# tambien sale como perdida, y un gate que impide desplegar el primer dia que da
# un falso positivo ensena a saltarse la puerta. Pero queda ESCRITO.
# ⚠️ Se busca solo «1 con perdida», no la linea entera: el numero de paginas
#    comparadas depende del fixture (aqui son 2, con `sub/index.html`), y el
#    `·` lo normaliza `solo_ascii` a `--` al escribir el historial. Mi primera
#    version fijaba las dos cosas y salio FALLA teniendo el paso razon.
grep -q "TEXTO .* 1 con perdida" "$QA_RECIBOS_DIR/history.tsv" \
  && { OK=$((OK+1)); echo "  PASA  la perdida queda ANOTADA en el historial"; } \
  || { MAL=$((MAL+1)); echo "  FALLA la perdida NO se anota"
       grep TEXTO "$QA_RECIBOS_DIR/history.tsv" | tail -2 | sed 's/^/          /'; }

echo
echo "==============================================================================="
printf "  %d PASA · %d FALLA\n" "$OK" "$MAL"
echo "==============================================================================="
[ "$MAL" = 0 ] || exit 1
