#!/usr/bin/env bash
# =============================================================================
#  tests.sh · el recibo de QA, probado
# =============================================================================
#  Se lanza asi (ruta absoluta a las dos cosas; se situa solo):
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/receipt-tests/tests.sh"
#
#  POR QUE ESTAS PRUEBAS Y NO OTRAS
#  --------------------------------
#  Un gate solo vale por lo que RECHAZA. Probar unicamente el caso bueno
#  demuestra que el fichero compila, no que el gate exista: por eso hay un
#  positivo y doce negativos, y cada negativo es una forma concreta de saltarse
#  el paso que ya ha ocurrido o que ocurriria el primer dia con prisa.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
REF="$(cd .. && pwd)"
T="${TEMP:-/tmp}/receipt-tests-$$"
# las pruebas NO escriben en el historial de verdad
export QA_RECIBOS_DIR="$T/historial-de-pruebas"
OK=0; MAL=0

r() { # r <nombre> <esperado_exit> <comando...>
  local nombre="$1" esp="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$esp" ]; then
    OK=$((OK+1)); printf '  PASA  %-52s (exit %s)\n' "$nombre" "$rc"
  else
    MAL=$((MAL+1)); printf '  FALLA %-52s (exit %s, esperaba %s)\n' "$nombre" "$rc" "$esp"
    printf '%s\n' "$out" | sed 's/^/          /'
  fi
  ULTIMA="$out"
}

contiene() { # contiene <nombre> <texto>
  # el «--» no es adorno: sin el, buscar un texto que empieza por guion
  # («--max-urls 40») lo interpreta grep como una opcion suya y la prueba FALLA
  # sin que falle nada del programa. Pasado el 11-ago-2026.
  if printf '%s' "$ULTIMA" | grep -qF -- "$2"; then
    OK=$((OK+1)); printf '  PASA  %-52s\n' "$1"
  else
    MAL=$((MAL+1)); printf '  FALLA %-52s (no dice: %s)\n' "$1" "$2"
    printf '%s\n' "$ULTIMA" | sed 's/^/          /'
  fi
}

# ── fixture ─────────────────────────────────────────────────────────────────
rm -rf "$T"; mkdir -p "$T/repo/sub" "$T/repo/_deploy" "$T/repo/assets"
printf 'hola\n'          > "$T/repo/index.html"
printf 'a{color:red}\n'  > "$T/repo/styles.css"
printf 'x\n'             > "$T/repo/sub/index.html"
printf 'no se sube\n'    > "$T/repo/CLAUDE.md"
printf 'no se sube\n'    > "$T/repo/_deploy/contact.php"
printf 'svg\n'           > "$T/repo/assets/logo.svg"

# ⚠️ El bloque `alcance` NO es adorno: desde el 11-ago-2026 un recibo que no
#    declara su alcance no vale como verde para desplegar, y una corrida de
#    verdad de qa-maestro SIEMPRE lo trae. Un fixture sin el probaria un recibo
#    que ya no existe. La forma es la del --json de qa-maestro (`por_lente`),
#    que es distinta de la que se le pasa a escribe_recibo() —ese desajuste
#    hacia que esta via escribiera «ALCANCE-URLS: 0», ver §16—.
cat > "$T/qa-verde.json" <<'JSON'
{"generado":"2026-08-10 14:00","sitio":"https://ejemplo.test","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":2,"no_verificado":3,"pasa":69},
 "instrumento":{"perl":"5.042002","dom":null},
 "alcance":{"sitio_urls":2,"lista_urls":2,"documentos":2,"por_lente":{
   "SEO":{"miradas":2,"urls":["https://ejemplo.test","https://ejemplo.test/sub"],"nota":""},
   "RENDIMIENTO":{"miradas":1,"urls":["https://ejemplo.test"],"nota":"muestra"},
   "ACCESIBILIDAD":{"miradas":2,"urls":["https://ejemplo.test","https://ejemplo.test/sub"],"nota":""},
   "MEDICION":{"miradas":2,"urls":["https://ejemplo.test","https://ejemplo.test/sub"],"nota":""},
   "ESTRUCTURA":{"miradas":2,"urls":["https://ejemplo.test","https://ejemplo.test/sub"],"nota":""}}},
 "comprobaciones":[
   {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
   {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
   {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},
   {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
   {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"maqueta"},
   {"lente":"ESTRUCTURA","id":"EST-06","estado":"NV","titulo":"densidad"},
   {"lente":"ESTRUCTURA","id":"EST-08","estado":"NV","titulo":"grafo"},
   {"lente":"ESTRUCTURA","id":"EST-09","estado":"NV","titulo":"repo vs produccion"}]}
JSON

cat > "$T/qa-rojo.json" <<'JSON'
{"generado":"2026-08-10 14:00","sitio":"https://ejemplo.test","veredicto":"FALLA",
 "resumen":{"fallo":2,"aviso":1,"no_verificado":0,"pasa":40},
 "instrumento":{"perl":"5.042002","dom":null},
 "alcance":{"sitio_urls":2,"lista_urls":2,"documentos":2,"por_lente":{
   "SEO":{"miradas":2,"urls":["https://ejemplo.test","https://ejemplo.test/sub"],"nota":""},
   "ACCESIBILIDAD":{"miradas":2,"urls":["https://ejemplo.test","https://ejemplo.test/sub"],"nota":""},
   "ESTRUCTURA":{"miradas":2,"urls":["https://ejemplo.test","https://ejemplo.test/sub"],"nota":""}}},
 "comprobaciones":[
   {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
   {"lente":"ACCESIBILIDAD","id":"A11-04","estado":"FALLO","titulo":"contraste AA"},
   {"lente":"ESTRUCTURA","id":"EST-07","estado":"FALLO","titulo":"fila coja"}]}
JSON

P="perl $REF/receipt.pl"
R="$T/repo"

echo "==============================================================================="
echo "  RECIBO DE QA · pruebas"
echo "==============================================================================="
echo
echo "-- 1 · que cuenta como arbol desplegable --------------------------------------"
r "el arbol se calcula"                     0 perl "$REF/receipt.pl" --arbol --repo "$R" --listar
contiene "incluye index.html"                 "index.html"
contiene "incluye el CSS"                     "styles.css"
contiene "incluye assets/"                    "assets/logo.svg"
if printf '%s' "$ULTIMA" | grep -q "CLAUDE.md"; then
  MAL=$((MAL+1)); echo "  FALLA CLAUDE.md NO debe estar en el arbol desplegable"
else OK=$((OK+1)); printf '  PASA  %-52s\n' "excluye CLAUDE.md (.md)"; fi
if printf '%s' "$ULTIMA" | grep -q "_deploy"; then
  MAL=$((MAL+1)); echo "  FALLA _deploy/ NO debe estar en el arbol desplegable"
else OK=$((OK+1)); printf '  PASA  %-52s\n' "excluye _deploy/ (andamiaje)"; fi

echo
echo "-- 2 · NEGATIVO: no hay recibo ------------------------------------------------"
r "sin recibo, se niega"                    1 perl "$REF/receipt.pl" --verificar --repo "$R"
contiene "dice que nadie ha mirado"           "NADIE HA CORRIDO EL QA"

echo
echo "-- 3 · POSITIVO: recibo verde y arbol intacto ---------------------------------"
r "se escribe el recibo"                    0 perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-verde.json"
r "verifica"                                0 perl "$REF/receipt.pl" --verificar --repo "$R"
r "verifica PARA DESPLEGAR"                 0 perl "$REF/receipt.pl" --verificar --repo "$R" --para-desplegar
contiene "avisa de lo que nadie miro"         "NO VERIFICADO NO ES UN APROBADO"
contiene "lista QUE no se miro"               "EST-09"

echo
echo "-- 4 · NEGATIVO: el arbol cambia despues del QA -------------------------------"
cp "$R/styles.css" "$T/styles.css.orig"
printf 'a{color:blue}\n' > "$R/styles.css"
r "un byte distinto invalida el recibo"     1 perl "$REF/receipt.pl" --verificar --repo "$R"
contiene "dice que el arbol cambio"           "el arbol ha CAMBIADO"
contiene "dice CUAL fichero"                  "CAMBIADO  styles.css"
cp "$T/styles.css.orig" "$R/styles.css"
r "al revertir, vuelve a valer"             0 perl "$REF/receipt.pl" --verificar --repo "$R"

echo
echo "-- 5 · NEGATIVO: fichero nuevo sin pasar por el QA ----------------------------"
printf 'nueva\n' > "$R/nueva.html"
r "una pagina nueva invalida el recibo"     1 perl "$REF/receipt.pl" --verificar --repo "$R"
contiene "la nombra"                          "NUEVO     nueva.html"
rm "$R/nueva.html"

echo
echo "-- 6 · NEGATIVO: fichero borrado ----------------------------------------------"
mv "$R/assets/logo.svg" "$T/logo.svg"
r "un borrado invalida el recibo"           1 perl "$REF/receipt.pl" --verificar --repo "$R"
contiene "lo nombra"                          "BORRADO   assets/logo.svg"
mv "$T/logo.svg" "$R/assets/logo.svg"

echo
echo "-- 7 · NEGATIVO: recibo retocado a mano ---------------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-rojo.json" >/dev/null
perl -i -pe 's/^VEREDICTO: FALLA/VEREDICTO: PASA/' "$R/.qa-recibo"
r "cambiar FALLA por PASA rompe el SELLO"   1 perl "$REF/receipt.pl" --verificar --repo "$R"
contiene "lo dice"                            "el SELLO no cuadra"

echo
echo "-- 8 · NEGATIVO: recibo en rojo (sin retocar) ---------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-rojo.json" >/dev/null
r "en rojo: el arbol cuadra, asi que --verificar pasa" 0 perl "$REF/receipt.pl" --verificar --repo "$R"
r "en rojo: NO se despliega"                1 perl "$REF/receipt.pl" --verificar --repo "$R" --para-desplegar
contiene "cita la regla"                      "EN ROJO NO SE DESPLIEGA"
contiene "dice que lente"                     "lente ACCESIBILIDAD: FALLA"

echo
echo "-- 9 · NEGATIVO: recibo caducado ----------------------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-verde.json" >/dev/null
r "con ventana 0 h, caduca al instante"     1 perl "$REF/receipt.pl" --verificar --repo "$R" --para-desplegar --horas 0
contiene "lo dice"                            "CADUCADO"

echo
echo "-- 10 · NEGATIVO: recibo inventado a mano -------------------------------------"
printf 'VEREDICTO: PASA\nARBOL-HASH: 0\n' > "$R/.qa-recibo"
r "un recibo sin SELLO no es un recibo"     1 perl "$REF/receipt.pl" --verificar --repo "$R"
contiene "lo dice"                            "no tiene SELLO"

echo
echo "-- 11 · NEGATIVO: recibo borrado para saltarse el gate ------------------------"
rm -f "$R/.qa-recibo"
r "borrarlo no abre la puerta"              1 perl "$REF/receipt.pl" --verificar --repo "$R" --para-desplegar
contiene "lo dice"                            "NADIE HA CORRIDO EL QA"

echo
echo "-- 12 · .qa-arbol: declarar lo que NO se sube ---------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-verde.json" >/dev/null
H1="$(perl "$REF/receipt.pl" --arbol --repo "$R" | awk '/ARBOL-HASH/{print $2}')"
printf 'EXCLUIR: assets/**\n' > "$R/.qa-arbol"
H2="$(perl "$REF/receipt.pl" --arbol --repo "$R" | awk '/ARBOL-HASH/{print $2}')"
if [ "$H1" != "$H2" ]; then OK=$((OK+1)); printf '  PASA  %-52s\n' "una exclusion cambia el arbol"
else MAL=$((MAL+1)); echo "  FALLA .qa-arbol no se esta leyendo"; fi
r "y por tanto invalida el recibo anterior" 1 perl "$REF/receipt.pl" --verificar --repo "$R"
rm -f "$R/.qa-arbol"

echo
echo "-- 13 · NEGATIVO: recibo escrito con --solo (lentes sin correr) ---------------"
# El atajo mas comodo que existe, y el que aparecio solo en la primera corrida
# real: `qa-master.pl --solo seo` sale PASA en 20 segundos.
cat > "$T/qa-parcial.json" <<'JSON'
{"sitio":"https://ejemplo.test","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":0,"no_verificado":1,"pasa":12},
 "instrumento":{"perl":"5.042002","dom":null},
 "comprobaciones":[{"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"}]}
JSON
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-parcial.json" >/dev/null
r "el recibo parcial es integro (arbol y sello OK)" 0 perl "$REF/receipt.pl" --verificar --repo "$R"
r "pero NO se despliega"                    1 perl "$REF/receipt.pl" --verificar --repo "$R" --para-desplegar
contiene "dice que faltan lentes"             "hay lentes SIN CORRER"
contiene "las nombra"                         "ESTRUCTURA"

echo
echo "-- 14 · el recibo es ASCII puro (el SELLO es un md5 sobre bytes) --------------"
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-verde.json" \
     --instrumento 'perl 5.042 · curl · sin DOM' >/dev/null
if LC_ALL=C grep -qP '[\x80-\xff]' "$R/.qa-recibo" 2>/dev/null \
   || LC_ALL=C grep -q '[^ -~	]' "$R/.qa-recibo"; then
  # el manifiesto puede llevar bytes altos si un fichero tiene tilde; aqui no hay
  MAL=$((MAL+1)); echo "  FALLA hay bytes no-ASCII en la cabecera del recibo"
else OK=$((OK+1)); printf '  PASA  %-52s\n' "sin bytes no-ASCII"; fi
r "y sigue verificando"                     0 perl "$REF/receipt.pl" --verificar --repo "$R"

echo
echo "-- 15 · el recibo NO se hashea a si mismo -------------------------------------"
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-verde.json" >/dev/null
r "escribir el recibo no invalida el recibo" 0 perl "$REF/receipt.pl" --verificar --repo "$R"

echo
echo "-- 16 · EL ALCANCE DECIDE (11-ago-2026) --------------------------------------"
#  Hermanas de las de §13. Alli el hueco era «he corrido 1 de 5 LENTES»; aqui es
#  «he mirado 1 de 40 PAGINAS». Las dos producen un recibo integro, verde y
#  vacio, y hasta hoy solo estaba tapada la primera.
#
#  🔴 El positivo de 16d es tan importante como los negativos: un gate que no
#     deje desplegar un sitio grande se apaga, y entonces tampoco caza 16c.

# ── 16a · POSITIVO: alcance completo (2 de 2 paginas) ────────────────────────
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-verde.json" >/dev/null
r "alcance completo: vale para desplegar"   0 perl "$REF/receipt.pl" --verificar --repo "$R" --para-desplegar
contiene "y dice cuantas de cuantas"          "de 2 paginas HTML selladas"
contiene "y QUE URLs mira cada lente"         "RENDIMIENTO 1 de 2 del sitio - URLS 1"

# ── 16b · NEGATIVO: recibo SIN alcance declarado ─────────────────────────────
#  Es el recibo de ayer: cinco lentes corridas, veredicto PASA, y ni una linea
#  sobre cuanto se midio. Se rechaza, y el mensaje tiene que decir QUE HACER —un
#  gate que solo dice «no» se acaba puenteando—.
cat > "$T/qa-sin-alcance.json" <<'JSON'
{"sitio":"https://ejemplo.test","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":0,"no_verificado":0,"pasa":60},
 "instrumento":{"perl":"5.042002","dom":null},
 "comprobaciones":[
   {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
   {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
   {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},
   {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
   {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}
JSON
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-sin-alcance.json" >/dev/null
if grep -q '^ALCANCE: NO DECLARADO' "$R/.qa-recibo"; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "el recibo dice NO DECLARADO, no se calla"
else MAL=$((MAL+1)); printf '  FALLA %-52s\n' "el recibo se calla el alcance"; fi
r "sin alcance: el recibo es integro"       0 perl "$REF/receipt.pl" --verificar --repo "$R"
r "sin alcance: NO vale para desplegar"     1 perl "$REF/receipt.pl" --verificar --repo "$R" --para-desplegar
contiene "dice que no declara alcance"        "NO DECLARA SU ALCANCE"
contiene "y dice QUE HACER"                   "perl qa-master.pl"

# ── 16c · NEGATIVO: 1 pagina medida de un arbol de 40 ────────────────────────
#  El caso del encargo, tal cual: «un recibo que sella 192 ficheros habiendo
#  medido 1 pagina es una afirmacion sin respaldo». Aqui son 40 paginas y una.
G="$T/grande"; mkdir -p "$G"
i=1; while [ $i -le 40 ]; do printf 'pagina %02d\n' "$i" > "$G/$(printf 'p%03d' $i).html"; i=$((i+1)); done
cat > "$T/qa-grande-1.json" <<'JSON'
{"sitio":"https://grande.test","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":0,"no_verificado":0,"pasa":60},
 "instrumento":{"perl":"5.042002","dom":null},
 "alcance":{"sitio_urls":40,"lista_urls":1,"documentos":1,"por_lente":{
   "SEO":{"miradas":1,"urls":["https://grande.test/p001"],"nota":""},
   "RENDIMIENTO":{"miradas":1,"urls":["https://grande.test/p001"],"nota":""},
   "ACCESIBILIDAD":{"miradas":1,"urls":["https://grande.test/p001"],"nota":""},
   "MEDICION":{"miradas":1,"urls":["https://grande.test/p001"],"nota":""},
   "ESTRUCTURA":{"miradas":1,"urls":["https://grande.test/p001"],"nota":""}}},
 "comprobaciones":[
   {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
   {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
   {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},
   {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
   {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}
JSON
perl "$REF/receipt.pl" --escribir --repo "$G" --json "$T/qa-grande-1.json" >/dev/null
r "1 de 40: el recibo es integro"           0 perl "$REF/receipt.pl" --verificar --repo "$G"
r "1 de 40: NO vale para desplegar"         1 perl "$REF/receipt.pl" --verificar --repo "$G" --para-desplegar
contiene "lo llama por su nombre"             "ALCANCE IRRISORIO"
contiene "da los dos numeros"                 "1 pagina medida de las 40"
contiene "ofrece medir mas"                   "--max-urls 40"
contiene "y ofrece dejar de sellar lo que no se sube" ".qa-arbol"
# 🔴 y el motivo tiene que ser SOLO el alcance: si de paso saltara otra regla,
#    esta prueba no estaria midiendo lo que cree medir.
if printf '%s' "$ULTIMA" | grep -qF "lentes SIN CORRER"; then
  MAL=$((MAL+1)); printf '  FALLA %-52s\n' "rechaza por otra cosa, no por el alcance"
else OK=$((OK+1)); printf '  PASA  %-52s\n' "el unico motivo es el alcance"; fi

# ── 16d · POSITIVO: 25 paginas de un arbol de 120 ────────────────────────────
#  La regla (b). Sin ella, un sitio grande no podria desplegarse NUNCA con el
#  tope por defecto, y el gate se apagaria entero —incluido 16c—.
E="$T/enorme"; mkdir -p "$E"
i=1; while [ $i -le 120 ]; do printf 'pagina %03d\n' "$i" > "$E/$(printf 'p%03d' $i).html"; i=$((i+1)); done
{ printf '{"sitio":"https://enorme.test","veredicto":"PASA",\n'
  printf ' "resumen":{"fallo":0,"aviso":0,"no_verificado":0,"pasa":60},\n'
  printf ' "instrumento":{"perl":"5.042002","dom":null},\n'
  U=''; i=1
  while [ $i -le 25 ]; do U="$U${U:+,}\"https://enorme.test/$(printf 'p%03d' $i)\""; i=$((i+1)); done
  printf ' "alcance":{"sitio_urls":120,"lista_urls":25,"documentos":25,"por_lente":{\n'
  printf '   "SEO":{"miradas":25,"urls":[%s],"nota":""},\n' "$U"
  printf '   "RENDIMIENTO":{"miradas":25,"urls":[%s],"nota":""},\n' "$U"
  printf '   "ACCESIBILIDAD":{"miradas":25,"urls":[%s],"nota":""},\n' "$U"
  printf '   "MEDICION":{"miradas":25,"urls":[%s],"nota":""},\n' "$U"
  printf '   "ESTRUCTURA":{"miradas":25,"urls":[%s],"nota":""}}},\n' "$U"
  printf ' "comprobaciones":[\n'
  printf '   {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},\n'
  printf '   {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},\n'
  printf '   {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},\n'
  printf '   {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},\n'
  printf '   {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}\n'
} > "$T/qa-enorme-25.json"
perl "$REF/receipt.pl" --escribir --repo "$E" --json "$T/qa-enorme-25.json" >/dev/null
r "25 de 120 (21%): SI vale para desplegar" 0 perl "$REF/receipt.pl" --verificar --repo "$E" --para-desplegar
contiene "pero lo dice en voz alta"           "95 paginas HTML van FIRMADAS y NO MEDIDAS"

# ── 16e · el alcance NO se cuela en --verificar a secas ──────────────────────
#  `--verificar` contesta «¿se corrio el QA sobre este arbol?». El alcance no
#  cambia esa respuesta, y meterlo ahi romperia a todo el que solo comprueba
#  integridad.
r "un alcance irrisorio sigue siendo un recibo valido" 0 perl "$REF/receipt.pl" --verificar --repo "$G"

# ── 16f · la via `--escribir --json` estampa el alcance de verdad ────────────
#  Comprobado el 11-ago: escribia ALCANCE-URLS: 0 con el JSON lleno delante,
#  porque el JSON y escribe_recibo() usaban DOS FORMAS de la misma clave. Un
#  cero silencioso, que es la unica forma de error que no se ve.
perl "$REF/receipt.pl" --escribir --repo "$R" --json "$T/qa-verde.json" >/dev/null
if grep -q '^ALCANCE-URLS: 2$' "$R/.qa-recibo"; then
  OK=$((OK+1)); printf '  PASA  %-52s\n' "no rellena el alcance con ceros"
else MAL=$((MAL+1)); printf '  FALLA %-52s\n' "ALCANCE-URLS no es 2: $(grep -m1 '^ALCANCE-URLS:' "$R/.qa-recibo")"; fi
for L in SITIO PAGINAS-SELLADAS PAGINAS-MEDIDAS; do
  if grep -q "^ALCANCE-$L: " "$R/.qa-recibo"; then
    OK=$((OK+1)); printf '  PASA  %-52s\n' "el recibo lleva ALCANCE-$L"
  else MAL=$((MAL+1)); printf '  FALLA %-52s\n' "falta ALCANCE-$L"; fi
done

# ── 16g · el mapeo ruta->URL falla: NO se acusa a la web de un fallo mio ─────
#  Si ninguna URL medida casa con ningun fichero (una web bajo subcarpeta, otro
#  dominio, un CMS), la cobertura calculada es 0 y bloquearia un despliegue
#  legitimo por un limite MIO. Se cae al numero que no depende de ninguna
#  hipotesis —cuantas URLs se midieron— y se dice en voz alta.
#  🔴 Y el control que impide que esa salida sea una puerta trasera: con UNA
#     sola URL sigue bloqueando, porque 1 es irrisorio venga de donde venga.
mkfake() { # mkfake <fichero_json> <n_urls>
  { printf '{"sitio":"https://grande.test","veredicto":"PASA",\n'
    printf ' "resumen":{"fallo":0,"aviso":0,"no_verificado":0,"pasa":60},\n'
    printf ' "instrumento":{"perl":"5.042002","dom":null},\n'
    U=''; i=1
    while [ $i -le "$2" ]; do U="$U${U:+,}\"https://OTRO-DOMINIO.test/$(printf 'p%03d' $i)\""; i=$((i+1)); done
    printf ' "alcance":{"sitio_urls":40,"lista_urls":%s,"documentos":%s,"por_lente":{\n' "$2" "$2"
    for L in SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA; do
      printf '   "%s":{"miradas":%s,"urls":[%s],"nota":""}%s\n' "$L" "$2" "$U" \
             "$([ "$L" = ESTRUCTURA ] || printf ,)"
    done
    printf ' }},\n "comprobaciones":[\n'
    printf '   {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},\n'
    printf '   {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},\n'
    printf '   {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},\n'
    printf '   {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},\n'
    printf '   {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}\n'
  } > "$1"
}
mkfake "$T/qa-mapeo-25.json" 25
perl "$REF/receipt.pl" --escribir --repo "$G" --json "$T/qa-mapeo-25.json" >/dev/null
r "mapeo roto con 25 URLs: no bloquea"      0 perl "$REF/receipt.pl" --verificar --repo "$G" --para-desplegar
contiene "y avisa de que no casan"            "no casan con ningun fichero del arbol"
mkfake "$T/qa-mapeo-1.json" 1
perl "$REF/receipt.pl" --escribir --repo "$G" --json "$T/qa-mapeo-1.json" >/dev/null
r "mapeo roto con 1 URL: SIGUE bloqueando"  1 perl "$REF/receipt.pl" --verificar --repo "$G" --para-desplegar
contiene "y dice que el numero son URLs, no paginas" "el mapeo ruta->URL no ha casado NI UNA"

echo
echo "==============================================================================="
printf "  %d PASA · %d FALLA\n" "$OK" "$MAL"
echo "==============================================================================="
rm -rf "$T"
[ "$MAL" = 0 ] || exit 1
