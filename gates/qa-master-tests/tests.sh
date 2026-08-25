#!/usr/bin/env bash
# =============================================================================
#  Prueba de qa-master.pl · control POSITIVO y controles NEGATIVOS
# =============================================================================
#  Run it with one line:
#    bash gates/qa-master-tests/tests.sh
#
#  On Windows, `bash` is not on PowerShell's PATH. From PowerShell:
#    & "C:\Program Files\Git\bin\bash.exe" "<repo>/gates/qa-master-tests/tests.sh"
#
#  🔴 POR QUE EXISTE, y por que hay que volver a correrla cada vez que se toque
#     el gate: «un gate que solo se ha visto en verde no prueba nada», y su
#     gemela, «un QA que no encuentra lo que ya sabes que esta roto no sirve».
#     Aqui hay las tres clases de caso, y las tres hacen falta:
#       · POSITIVO  — webs nuestras con defectos CONOCIDOS: tiene que cazarlos.
#       · PASA      — algo que esta bien: no puede salir acusado.
#       · FRONTERA  — casos que PARECEN defectos y no lo son. Son los que
#                     distinguen un gate de un generador de ruido.
#
#  ⚠️ Toca la red: tres de estas webs estan LIVE. Solo hace GET. No despliega.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"
QA="../qa-master.pl"
# Donde viven los repos de nuestras 5 webs. Se puede sobreescribir:
#   REPOS=/path/to/your/repos bash tests.sh
# There is no sensible default here — it names YOUR checkouts — so it must be
# set. Failing loudly beats silently measuring a directory that does not exist.
REPOS="${REPOS:-}"
CACHE="${TMPDIR:-/tmp}/qa-master-tests-cache"
mkdir -p "$CACHE"
ok=0; ko=0

# ── LA CACHE CONGELADA DE KINE ──────────────────────────────────────────────
# 🔴 POR QUE (11-ago-2026). Esta bateria decia «OK 180 · MAL 0» y con una cache
#    NUEVA daba «OK 172 · MAL 10». Los 10 eran de site-a.example y todos
#    decian lo mismo: *esperaba FALLO y salio PASA*. No es que el gate fallara:
#    es que site-a SE DESPLEGO el 11-ago y esos defectos ya no existen. La cache
#    tibia de /tmp guardaba los bytes de ANTES. Lado a lado:
#        --primary   oklch(0.58 ...) en cache   ·  oklch(0.54 ...) en vivo
#        favicon     320 KB en cache            ·  3.280 B en vivo
#        retrato     2.338.296 B en cache       ·  49.826 B en vivo
#    O sea: el numero que decia «no puede bajar» NO ERA REPRODUCIBLE. El dia que
#    alguien limpiara /tmp bajaba a 172 y se leia como «he roto el gate».
#
#    LA CAUSA ES ESTRUCTURAL, no de esas 10 lineas: un control POSITIVO anclado
#    a una web VIVA caduca el dia que arreglas esa web. **Arreglar el sitio
#    rompe la prueba.** Por eso la evidencia se CONGELA —igual que `--dom
#    dom-*.json` y `fixtures-seo14/`— y el caso pasa a probar EL GATE en vez del
#    estado de produccion.
#
#    QUE ES fixtures-frozen-site/: la cache exacta que esta bateria estaba
#    leyendo el 11-ago-2026, trio a trio (.meta/.body/.hdr). Detalle y como se
#    regenera, en su LEEME.md.
#    ⚠️ Se COPIA a un directorio de trabajo antes de correr: qa-maestro escribe
#       en su --cache, y el fixture tiene que quedar intacto.
#    ⚠️ site-a deja de ser un control VIVO. La cobertura sobre webs vivas la
#       siguen dando bc, site-c, cm y site-b. Cuando a una de esas se le arregle
#       un defecto que aqui es control positivo, toca el mismo tratamiento.
KFIX="fixtures-frozen-site"
KCACHE="$CACHE-site-a"

# ── UN 404 MALO, SERVIDO EN LOCAL ────────────────────────────────────────────
# 🔴 19-ago-2026 · LOS DOS CASOS DE EST-03 SONDEABAN site-d.example VIVA, y
#    caducaron el dia que se le genero un 404 propio. No se podian arreglar
#    congelando una cache: EST-03 pide una URL ALEATORIA para provocar el 404, y
#    una URL aleatoria NUNCA esta en cache — siempre golpea el host de verdad.
#    Por eso aqui se levanta un servidor propio: su respuesta para lo que no
#    encuentra son 3 bytes, sin <h1> y sin un solo enlace, que es exactamente el
#    callejon sin salida que EST-03 existe para cazar. Y ya no depende de que
#    ninguna web de cliente siga rota.
P404=$(( 8600 + ($$ % 300) ))
CENT404="centinela-$$-$(date +%s)"
printf '%s\n' "$CENT404" > "fixtures-fingerprint/_sentinel.txt"
perl "../receipt-tests/test-server.pl" "fixtures-fingerprint" "$P404" >/dev/null 2>&1 &
SRV404=$!
trap 'kill $SRV404 2>/dev/null; rm -f fixtures-fingerprint/_sentinel.txt' EXIT
sleep 1
# CENTINELA: sin esto, un puerto ocupado por otra sesion mide OTRA web y las
# pruebas pasan por el motivo equivocado. Ya paso una vez, media hora.
RESP404="$(curl -sS --max-time 5 "http://127.0.0.1:$P404/_sentinel.txt" 2>/dev/null)"
if [ "$RESP404" != "$CENT404" ]; then
  printf '  MAL   %-46s no arranco mi servidor en el puerto %s\n' "servidor del 404 malo" "$P404"; ko=$((ko+1))
  U404=""
else
  U404="http://127.0.0.1:$P404/"
fi
rm -f fixtures-fingerprint/_sentinel.txt
rm -rf "$KCACHE"; mkdir -p "$KCACHE"
#  🔴 THE FROZEN FIXTURE DOES NOT SHIP. It was a byte-for-byte capture of a real
#     client's site — 95 HTTP triples, a live clinic's home page — and publishing
#     somebody else's website to make a test pass is not a trade this repository
#     makes. Freeze your own with `freeze-fixture.pl`; its README says how.
#     Exit 3, not 2 and not 1: in this system 3 means I DID NOT MEASURE IT, and
#     `run-all.sh` prints it as NOT MEASURED and names it in the summary. A 1
#     would send somebody hunting a defect that does not exist, and a 0 would let
#     a hole read as a pass — which is the failure this whole repository is about.
if [ ! -d "$KFIX" ]; then
  echo
  echo "  NOT MEASURED · the frozen fixture $KFIX/ is not here."
  echo "  It is not missing by accident: it was a capture of a real client site"
  echo "  and it is deliberately not published. Everything in this battery that"
  echo "  depends on a frozen site is therefore unmeasured — not passing."
  echo "  To measure it, freeze a site you own:"
  echo "      perl freeze-fixture.pl <URL> $KFIX"
  echo
  echo "  OK 0 · MAL 0"
  exit 3
fi
cp "$KFIX"/* "$KCACHE"/ 2>/dev/null || { echo "🔴 $KFIX is present but empty: cannot run"; exit 2; }
ls "$KCACHE" | sort > "$CACHE/kfix-antes.lst"
KFIX_N0="$(wc -l < "$CACHE/kfix-antes.lst")"

# espera <etiqueta> <ESTADO> <ID> <comando...>
espera() {
  local eti="$1" est="$2" id="$3"; shift 3
  local out; out="$("$@" 2>&1)"
  local linea; linea="$(printf '%s\n' "$out" | grep -E "^\s+\[[A-Z ]+\] +$id " | head -1)"
  local real; real="$(printf '%s' "$linea" | sed -E 's/^\s+\[([A-Z ]+)\].*/\1/' | tr -d ' ')"
  [ -z "$real" ] && real="AUSENTE"
  if [ "$real" = "$est" ]; then
    printf '  OK    %-46s %-8s -> %s\n' "$eti" "$id" "$real"; ok=$((ok+1))
  else
    printf '  MAL   %-46s %-8s esperaba %s y salio %s\n' "$eti" "$id" "$est" "$real"; ko=$((ko+1))
    printf '%s\n' "$linea" | sed 's/^/          /'
  fi
}

# texto <etiqueta> SI|NO <literal> <comando...>
#   Un ESTADO no basta para varios de los arreglos: A11Y-03 sigue siendo FALLO
#   en climentmedia, pero por DOS pares honestos en vez de por siete contra un
#   fondo blanco que no existe. Lo que hay que fijar es el NUMERO, no el color
#   del semaforo.
texto() {
  local eti="$1" quiero="$2" lit="$3"; shift 3
  local out; out="$("$@" 2>&1)"
  local hay=NO; printf '%s' "$out" | grep -qF -- "$lit" && hay=SI
  if [ "$hay" = "$quiero" ]; then
    printf '  OK    %-46s %s "%s"\n' "$eti" "$quiero" "$lit"; ok=$((ok+1))
  else
    printf '  MAL   %-46s esperaba %s "%s" y salio %s\n' "$eti" "$quiero" "$lit" "$hay"; ko=$((ko+1))
  fi
}

echo "== CONTROLES POSITIVOS · defectos CONOCIDOS de la sintesis del 10-ago-2026"
espera "site-a · paleta bajo AA (--primary L=0,58)"        FALLO A11Y-03 perl $QA https://site-a.example/ --solo a11y --cache "$KCACHE"
espera "site-a · el comentario dice 4,84 y son 4,11"        FALLO A11Y-04 perl $QA https://site-a.example/ --solo a11y --cache "$KCACHE"
espera "site-a · favicon de 320 KB en 13 paginas"           FALLO REN-07  perl $QA https://site-a.example/ --solo rendimiento --cache "$KCACHE"
# 🔴 ESTE CASO ESPERABA `FALLO REN-04` Y ERA UN FALSO POSITIVO DEL GATE, no un
#    defecto de site-a. Sumaba los 4 .woff2 DECLARADOS; los cuatro llevan
#    `unicode-range` y Chrome baja 2 (112,9 KB), medido. Verificado aparte del
#    gate sobre el arbol entero: 25 ficheros, 37 codepoints no-ASCII, 0 en
#    latin-ext. Se cambia la expectativa Y se fija el numero, que es lo que
#    distingue «lo he arreglado» de «lo he apagado». Los controles negativos
#    —fuente sin unicode-range, y rango que el sitio SI usa— estan al final.
espera "site-a · las 2 fuentes que el navegador SI baja"    PASA  REN-04  perl $QA https://site-a.example/ --solo rendimiento --cache "$KCACHE"
texto  "site-a · REN-04 dice cuantas descuenta y por que"   SI "2 de 4 NO se bajan" \
       perl $QA https://site-a.example/ --solo rendimiento --cache "$KCACHE"
espera "site-a · PNG de 2,3 MB / logo a 200 B/px"           FALLO REN-02  perl $QA https://site-a.example/ --solo rendimiento --cache "$KCACHE"
espera "bc · page_view_gracias sin disparador (G1)"       FALLO MED-03  perl $QA https://site-d.example/ --gracias /gracias/ --solo medicion --cache "$CACHE"
# ⚠️ `--sin-recibo` en TODA prueba que apunte a un repo de verdad (anadido el
#    11-ago-2026). Sin el, estas dos lineas escribian un `.qa-recibo` DENTRO de
#    site-d-web cada vez que se corria la bateria —y encima un recibo de
#    `--solo`, con cuatro lentes en «NO CORRIDA»—, pisando el que hubiera. La
#    bateria del gate no puede dejar rastro en el repo de una web viva.
# 🔴 RETIRADO EL 11-ago-2026 · aqui habia:
#      espera "bc · data-thanks sin lector (G12)"  FALLO MED-05  ... site-d-web
#    **El defecto de site-d ESTA ARREGLADO**: `script.js:203` hace
#    `getAttribute('data-thanks')`. El caso seguia en verde por otro motivo —el
#    HTML VIEJO DEL CLIENTE en `_migrate/origen/`, que el check escaneaba y que
#    no se despliega—. O sea: verde por el motivo equivocado, igual que las 10
#    de site-a con la cache tibia (07-trampas §17).
#    Al dejar de escanear `_migrate/` (no es codigo nuestro), site-d paso a
#    PASA y este caso canto. Se sustituye por un FIXTURE con el defecto dentro:
#    asi la prueba no depende de que una web de cliente siga rota.
espera "MED-05 · atributo emitido y SIN lector: FALLA"    FALLO MED-05 \
       perl $QA https://climentmedia.com --repo fixtures-med05/huerfano --candidato --una-sola --solo medicion --sin-recibo
texto  "MED-05 · y lo nombra por su nombre"               SI "data-thanks" \
       perl $QA https://climentmedia.com --repo fixtures-med05/huerfano --candidato --una-sola --solo medicion --sin-recibo
# 🔴 LA FRONTERA · el mismo arbol CON el lector no puede salir acusado.
espera "MED-05 · el mismo, con lector: PASA"              PASA  MED-05 \
       perl $QA https://climentmedia.com --repo fixtures-med05/con-lector --candidato --una-sola --solo medicion --sin-recibo
# 🔴 Y que no se acuse al codigo DEL CLIENTE: `_migrate/` guarda su web
#    capturada como evidencia y no se despliega. En site-c daba 16 atributos, de
#    los que 4 de los 5 visibles eran de su Elementor.
texto  "MED-05 · no acusa al HTML del cliente (_migrate)"  NO "_migrate/origen" \
       perl $QA https://site-d.example/ --repo $REPOS/site-d-web --solo medicion --sin-recibo --cache "$CACHE"
espera "404 malo servido en local · sin h1 ni enlaces"             FALLO EST-03  perl $QA $U404 --solo estructura
espera "bc · styles.css del repo NO desplegado (G11)"     FALLO EST-09  perl $QA https://site-d.example/ --repo $REPOS/site-d-web --solo estructura --sin-recibo --cache "$CACHE"
espera "bc · politica «pendiente de revision juridica»"   FALLO MED-08  perl $QA https://site-d.example/ --solo medicion --cache "$CACHE"
espera "bc · casillas de analitica premarcadas (G13)"     FALLO MED-06  perl $QA https://site-d.example/ --solo medicion --cache "$CACHE"
espera "cm · og:image:alt al 0% donde vive el estandar"   FALLO SEO-06  perl $QA https://climentmedia.com/ --solo seo --cache "$CACHE"
espera "site-b · ficha que solo existe con JS (G10)"     FALLO SEO-14  perl $QA "https://shop.site-b.example/produto.html?sku=MOB-001" --solo seo --cache "$CACHE"
espera "site-c(fixture) · 27,7 pantallas y 1 CTA"           FALLO EST-06  perl $QA https://site-c.example/ --solo estructura --dom dom-site-c-broken.json --cache "$CACHE"
espera "site-c(fixture) · fila coja y titular huerfano"     FALLO EST-07  perl $QA https://site-c.example/ --solo estructura --dom dom-site-c-broken.json --cache "$CACHE"

echo
echo "== CONTROLES QUE DEBEN PASAR"
espera "bc REPO con --primary ya corregido a L=0,54"      PASA  A11Y-03 perl $QA https://site-d.example/ --solo a11y --css $REPOS/site-d-web/styles.css --cache "$CACHE"
espera "site-c · su 404 (la unica que pasa maqueta)"        PASA  EST-03  perl $QA https://site-c.example/ --solo estructura --cache "$CACHE"
espera "bc · comprime html/css/js (PC17)"                 PASA  REN-08  perl $QA https://site-d.example/ --solo rendimiento --cache "$CACHE"
espera "bc · 0 webfonts, la mejor maqueta sin ninguna"    PASA  REN-04  perl $QA https://site-d.example/ --solo rendimiento --cache "$CACHE"
espera "cm · sitemap con la pagina dentro"                PASA  SEO-16  perl $QA https://climentmedia.com/ --solo seo --cache "$CACHE"

echo
echo "== CASOS FRONTERA · PARECEN defectos y NO lo son"
espera "cm · 8 de 9 <img> con alt=\"\" DECORATIVO (X3)"     PASA  SEO-10  perl $QA https://climentmedia.com/ --solo seo --cache "$CACHE"
espera "configurador · 0 CTA y 14 <button> (excepcion)"   PASA  EST-06  perl $QA https://site-c.example/ --solo estructura --dom dom-configurator.json --cache "$CACHE"
espera "configurador · se anota, no se arregla"           AVISO EST-06b perl $QA https://site-c.example/ --solo estructura --dom dom-configurator.json --cache "$CACHE"
espera "guia de PROSA de 12,4 pantallas (sospecha)"       PASA  EST-06  perl $QA https://site-c.example/ --solo estructura --dom dom-long-prose.json --cache "$CACHE"
espera "tactil 44x44: es AAA, nunca FALLO"                AVISO A11Y-12 perl $QA https://site-d.example/ --solo a11y --cache "$CACHE"
espera "sin hoja de tokens: NO medido != aprobado (X12)"  NOVERIF A11Y-03 perl $QA https://site-d.example/ --solo a11y --css /no/existe.css --cache "$CACHE"
espera "ancho clampado: la medida se tira entera (PC15)"  NOVERIF EST-05  perl $QA https://site-c.example/ --solo estructura --dom dom-unmeasured.json --cache "$CACHE"
espera "hover sin fondo declarado: no se acusa"           NOVERIF A11Y-03b perl $QA https://site-a.example/ --solo a11y --cache "$KCACHE"

echo
echo "== ARREGLO 0.1 · EL FONDO SE LEE, NO SE ASUME BLANCO"
texto  "cm · lee el fondo REAL de body (rgb(7,7,8))"   SI "= #070708" \
       perl $QA https://climentmedia.com/ --solo a11y --una-sola --cache "$CACHE"
texto  "site-c · lee el fondo REAL (oklch 16%)"          SI "var(--noche) = #12071c" \
       perl $QA https://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
texto  "cm · ya NO mide contra un blanco inventado"    NO "sobre #ffffff" \
       perl $QA https://climentmedia.com/ --solo a11y --una-sola --cache "$CACHE"
espera "site-c · su paleta oscura PASA (era FALLO falso)" PASA  A11Y-03 perl $QA https://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: en una web que SI es blanca, el fallo real sigue vivo.
espera "site-a · fondo blanco de verdad: sigue FALLANDO"  FALLO A11Y-03 perl $QA https://site-a.example/ --solo a11y --una-sola --cache "$KCACHE"
texto  "site-a · y sigue senalando el par real 4,11:1"    SI "#258998 sobre #ffffff = 4.11:1" \
       perl $QA https://site-a.example/ --solo a11y --una-sola --cache "$KCACHE"
espera "CENTINELA: ratio 1,00:1 -> grita, no acusa"     NOVERIF A11Y-03z perl $QA https://site-c.example/ --solo a11y --una-sola --css css-sentinel.css --cache "$CACHE"
espera "CENTINELA: y el par imposible NO es fallo"      PASA    A11Y-03  perl $QA https://site-c.example/ --solo a11y --una-sola --css css-sentinel.css --cache "$CACHE"
espera "CENTINELA: sin regla imposible, no salta"       AUSENTE A11Y-03z perl $QA https://site-c.example/ --solo a11y --una-sola --css css-no-sentinel.css --cache "$CACHE"

echo
echo "== ARREGLO 0.2 · LA LISTA SALE DEL SITEMAP QUE YA SE DESCARGABA"
#  🔴 REAPUNTADO POR EL ARREGLO P2 (10-ago-2026), NO RETIRADO.
#     Este par medía la expansión con `site-b + SEO-02`. Estaba midiendo el
#     defecto en el sitio equivocado: las «50 fichas con el mismo title» son UN
#     fichero (md5 39f60689ed61) servido en 50 URLs, así que SEO-02 contaba
#     ocho veces el mismo documento. El defecto es real y sigue cazado —lo caza
#     SEO-14, que es de quien es— y la expansión se sigue midiendo con él: con
#     --una-sola solo se mira la home, que sí tiene contenido, y el fallo
#     desaparece. Se añade además site-c, donde SEO-02 sí tiene dos duplicados
#     entre DOCUMENTOS DISTINTOS (md5 3f9d37425d/75548f7c5d y 4b523fac03/
#     7a411caae4), para que quede probado que SEO-02 no se ha apagado.
espera "site-b · el defecto real, en su sitio (G10)"       FALLO SEO-14 perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
espera "site-b · con --una-sola vuelve el falso PASA"      PASA  SEO-14 perl $QA https://shop.site-b.example/ --solo seo --una-sola --cache "$CACHE"
espera "site-c · 2 titles repetidos entre docs DISTINTOS"     FALLO SEO-02 perl $QA https://site-c.example/ --solo seo --cache "$CACHE"
espera "site-c · con --una-sola vuelve el falso PASA"         PASA  SEO-02 perl $QA https://site-c.example/ --solo seo --una-sola --cache "$CACHE"
texto  "el informe DECLARA el alcance de cada lente"        SI "ALCANCE      cuantas paginas ha mirado cada lente" \
       perl $QA https://site-c.example/ --solo a11y --cache "$CACHE"
texto  "y dice de donde ha sacado la lista"                 SI "del sitemap" \
       perl $QA https://site-c.example/ --solo a11y --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: SEO-16 pregunta si la pagina PEDIDA esta en el sitemap.
#    Si se comparara contra la lista expandida seria PASA por construccion.
espera "SEO-16 sigue midiendo (URL pedida fuera del sitemap)" AVISO SEO-16 perl $QA https://site-c.example/no-esta-en-el-sitemap --solo seo --una-sola --cache "$CACHE"

echo
echo "== ARREGLO 0.5b · EL ENLACE DE SALTO, EN EL IDIOMA QUE SEA"
espera "site-c · <a class=saltar href=#principal> (castellano)" PASA  A11Y-02 perl $QA https://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
espera "site-a · <a class=skip>Aller au contenu (frances)"      PASA  A11Y-02 perl $QA https://site-a.example/ --solo a11y --una-sola --cache "$KCACHE"
espera "bc · <a class=skip>Saltar al contenido"               PASA  A11Y-02 perl $QA https://site-d.example/ --solo a11y --una-sola --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: las dos que de verdad NO lo tienen siguen acusadas.
espera "cm · no tiene ninguno: sigue FALLANDO"                FALLO A11Y-02 perl $QA https://climentmedia.com/ --solo a11y --una-sola --cache "$CACHE"
espera "site-b · no tiene ninguno: sigue FALLANDO"           FALLO A11Y-02 perl $QA https://shop.site-b.example/ --solo a11y --una-sola --cache "$CACHE"

echo
echo "== ARREGLO 0.6 · 404 O 0 KB ES FALLO, NO «LIGERO»"
espera "bc · favicon.svg devuelve 404 (salia PASA 0 KB)"   FALLO REN-07 perl $QA https://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
espera "bc · y el barrido general lo caza tambien"         FALLO REN-13 perl $QA https://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
texto  "bc · lo dice con su estado, no con su peso"        SI "HTTP 404" \
       perl $QA https://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: el check de PESO no se ha perdido por el camino, y una
#    web cuyos recursos responden todos no puede salir acusada por esto.
espera "site-a · 320 KB de favicon: sigue siendo FALLO de PESO" FALLO REN-07 perl $QA https://site-a.example/ --solo rendimiento --una-sola --cache "$KCACHE"
espera "site-c · todos sus recursos responden"                  PASA  REN-13 perl $QA https://site-c.example/ --solo rendimiento --una-sola --cache "$CACHE"
espera "site-c · su favicon existe y es ligero"                 PASA  REN-07 perl $QA https://site-c.example/ --solo rendimiento --una-sola --cache "$CACHE"
# 19-ago-2026 - UN FAVICON EN data: NO SE DESCARGA, asi que nunca entraba en la
#   lista de RECURSOS, y la web que lo declara del mejor modo posible -cero
#   peticiones- salia como "sin favicon declarado". Este caso es el que lo fija.
espera "cm - favicon en data: URI, no es un hueco"          PASA  REN-07 perl $QA https://climentmedia.com/ --solo rendimiento --una-sola --cache "$CACHE"
# 🔴 FRONTERA que este mismo arreglo destapo y casi cuesta un FALLO FALSO en una
#    web viva: /ad-account-audit/ declara href="ad-account-audit.css". La lista
#    de paginas viaja SIN barra final, y resolverlo contra `.../audit` daba
#    `/ad-account-audit.css` (404) en vez de `/ad-account-audit/...` (200). Se
#    resuelve contra la URL EFECTIVA. Sin esto, REN-13 acusaba en falso.
espera "cm · href relativo bajo URL con barra: NO es 404"     PASA  REN-13 perl $QA https://climentmedia.com/ad-account-audit/ --solo rendimiento --una-sola --cache "$CACHE"

# 🔴 24-ago-2026 · REN-13 EN MODO CANDIDATO · DOS BACKENDS BAJO UN DOMINIO.
#    El candidato sirve SOLO el arbol que se va a subir. Si el dominio lo sirven
#    dos webs —site-b.example son 69 paginas estaticas nuestras y un WordPress—, los
#    recursos del otro backend dan 404 ahi POR CONSTRUCCION. Medido ese dia: el
#    gate dejaba el veredicto en FALLA por una imagen de `/wp-content/`, y las
#    330 que declara el arbol responden 200 en PRODUCCION.
#    El discriminador no es «existe el fichero» —eso absolveria a una ruta mal
#    escrita de las nuestras— sino DE QUIEN ES LA ZONA: si el primer segmento
#    esta en el arbol, la servimos nosotros.
espera "candidato · lo que sirve OTRO backend no se acusa"    PASA    REN-13  perl $QA https://climentmedia.com/ --repo fixtures-ren13/dos-backends --candidato --una-sola --solo rendimiento --sin-recibo
espera "candidato · y no se calla: se dice con nombre"        NOVERIF REN-13b perl $QA https://climentmedia.com/ --repo fixtures-ren13/dos-backends --candidato --una-sola --solo rendimiento --sin-recibo
# 🔴 EL CONTROL NEGATIVO. Sin este, el arreglo habria cambiado un falso positivo
#    por un falso negativo — que es peor, porque no se ve.
espera "candidato · una ruta rota de las NUESTRAS sigue roja" FALLO   REN-13  perl $QA https://climentmedia.com/ --repo fixtures-ren13/nuestra-rota --candidato --una-sola --solo rendimiento --sin-recibo
texto  "cm · y ademas ahora SI pesa su CSS (antes, invisible)" SI "css 15 KB" \
       perl $QA https://climentmedia.com/ad-account-audit/ --solo rendimiento --una-sola --cache "$CACHE"

echo
echo "== ARREGLO P1 · EL PESO DE UNA PAGINA NO DEPENDE DE SU SITIO EN LA LISTA"
#  🔴 `@font-face` cargaba TODAS las fuentes a $URLS[0] en vez de a las paginas
#     que cargan esa hoja. Medido en site-a, la MISMA pagina:
#         primera de la lista -> 1053 KB (font 254 KB)
#         segunda de la lista ->  912 KB (font 113 KB)
#     Y la direccion del error es la mala: INFRAVALORA. Un sitio pesado podia
#     colarse por debajo del tope segun en que orden se escribiera la lista.
texto  "site-a · la home SOLA pesa 1053 KB con font 254 KB"  SI "1053 KB · icon 313 KB · img 313 KB · font 254 KB" \
       perl $QA https://site-a.example/ --solo rendimiento --una-sola --cache "$KCACHE"
{
  printf 'https://site-a.example/\nhttps://site-a.example/services\n' > "$CACHE/ren-A.txt"
  printf 'https://site-a.example/services\nhttps://site-a.example/\n' > "$CACHE/ren-B.txt"
  for o in A B; do
    perl $QA "@$CACHE/ren-$o.txt" --solo rendimiento --sin-recibo --cache "$KCACHE" 2>&1 \
      | grep -A2 'REN-01' | grep -E 'DATO|DONDE' | sed 's/  */ /g' > "$CACHE/ren-$o.peso"
  done
  if diff -q "$CACHE/ren-A.peso" "$CACHE/ren-B.peso" >/dev/null; then
    printf '  OK    %-46s %s\n' "el peso NO depende del orden" "$(sed -n '1p' "$CACHE/ren-A.peso" | sed 's/^ *//')"; ok=$((ok+1))
  else
    printf '  MAL   %-46s el peso DEPENDE del orden:\n' "el peso NO depende del orden"; ko=$((ko+1))
    diff "$CACHE/ren-A.peso" "$CACHE/ren-B.peso" | sed 's/^/          /'
  fi
}
# 🔴 CONTROL NEGATIVO: el VEREDICTO de REN-04 tampoco depende del orden.
#    Ojo, cambio del 11-ago-2026: aqui se esperaba FALLO, y ese FALLO era el
#    falso positivo del unicode-range (ver arriba). Lo que esta linea vigila no
#    es el color del semaforo sino que sea EL MISMO en los dos ordenes; el
#    numero de KB lo fija el `texto` de arriba y el peso lo fija el diff de
#    REN-01, que sigue contando los 4 ficheros declarados.
for o in A B; do
  espera "site-a · REN-04 no depende del orden (orden $o)" PASA REN-04 perl $QA "@$CACHE/ren-$o.txt" --solo rendimiento --sin-recibo --cache "$CACHE"
done
texto  "la muestra dice que ha cogido una MUESTRA repartida" SI "MUESTRA repartida por la lista" \
       perl $QA https://climentmedia.com/ --solo rendimiento --cache "$CACHE"

echo
echo "== ARREGLO P2 · SE DEDUPLICA POR DOCUMENTO, NO POR CADENA DE URL"
#  site-b: 25 URLs auditadas -> 11 documentos. loja.html?cat=* es UN fichero
#  (md5 e55587a629cc) y produto.html?sku=* otro (39f60689ed61). Verificado a
#  mano con curl+md5sum el 10-ago-2026.
texto  "site-b · declara que 25 URLs son 11 documentos"  SI "25 URLs sirven 11 documentos distintos" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · SEO-02 cuenta DOCUMENTOS, no URLs"      SI "11 documentos distintos" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · el defecto NO se pierde: lo dice SEO-14" SI "este MISMO documento se sirve en" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
# 🔴 CONTROL NEGATIVO de SEO-04: deja de castigar la canonicalizacion BIEN
#    hecha (?cat=* -> loja.html, verificado a mano) y sigue acusando a la que
#    de verdad no tiene canonical (produto.html?sku=*).
espera "site-b · SEO-04 sigue acusando (falta canonical)" FALLO SEO-04 perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · y ya NO acusa a ?cat= con canonical OK"  NO "loja.html?cat=" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · SI acusa a la ficha sin canonical"       SI "produto.html?sku=MOB-001 (sin canonical)" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: en una web SIN duplicados de fichero no cambia nada.
texto  "site-c · sin ficheros repetidos, no deduplica nada"  NO "documentos distintos (" \
       perl $QA https://site-c.example/ --solo seo --cache "$CACHE"

echo
echo "== ARREGLO P3 · EL ENLACE DE SALTO SE RECONOCE POR DONDE ESTA, NO SOLO POR SU DESTINO"
#  Seis controles de laboratorio en p3-controls.pl: los 4 que ya salian bien y
#  los 2 que salian MAL (<a href="#inicio">Inicio</a> de un menu y
#  <a href="#contenido">Contenido del curso</a> de un indice).
if perl p3-controls.pl >/dev/null 2>&1; then
  printf '  OK    %-46s %s\n' "los 6 controles del enlace de salto" "6 OK / 0 MAL"; ok=$((ok+1))
else
  printf '  MAL   %-46s\n' "los 6 controles del enlace de salto"; ko=$((ko+1))
  perl p3-controls.pl 2>&1 | sed 's/^/          /'
fi

echo
echo "== LARGO VISIBLE · SEO-01 y SEO-03b MIDEN CARACTERES, NO BYTES NI ENTIDADES"
#  Ocho controles en length-controls.pl. La funcion se habia arreglado ya una
#  vez (entidades) y seguia contando BYTES: una vocal acentuada valia 2 y un
#  guion largo 3, asi que el umbral castigaba al frances y al castellano -- el
#  idioma de las cinco webs. Comprobado el 20-ago contra la version SIN
#  arreglar: 4 de los 8 salen MAL. Es decir, este control SI se pone rojo.
if perl length-controls.pl >/dev/null 2>&1; then
  printf '  OK    %-46s %s
' "los 8 controles de largo_visible" "8 OK / 0 MAL"; ok=$((ok+1))
else
  printf '  MAL   %-46s
' "los 8 controles de largo_visible"; ko=$((ko+1))
  perl length-controls.pl 2>&1 | sed 's/^/          /'
fi
# 🔴 CONTROLES SOBRE WEBS VIVAS: las 3 que lo tienen siguen pasando y las 2 que
#    NO lo tienen siguen acusadas. Sin esto, «6 OK» podria ser un gate apagado.
espera "site-c · sigue detectando su salto real"       PASA  A11Y-02 perl $QA https://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
espera "site-a · sigue detectando su salto real"       PASA  A11Y-02 perl $QA https://site-a.example/ --solo a11y --una-sola --cache "$KCACHE"
espera "bc · sigue detectando su salto real"         PASA  A11Y-02 perl $QA https://site-d.example/ --solo a11y --una-sola --cache "$CACHE"
espera "cm · no lo tiene: SIGUE acusada"             FALLO A11Y-02 perl $QA https://climentmedia.com/ --solo a11y --una-sola --cache "$CACHE"
espera "site-b · no lo tiene: SIGUE acusada"        FALLO A11Y-02 perl $QA https://shop.site-b.example/ --solo a11y --una-sola --cache "$CACHE"

echo
echo "== ARREGLO P4 · UN VECTOR NO TIENE RESOLUCION: NO SE MIDE EN B/px"
#  cm declara meta.svg (738 B), googleads.svg (755 B) y ga4.svg (404 B) a 18x18,
#  y REN-02 los acusaba de «sobredimensionados» por 2,278 / 2,330 / 1,247 B/px,
#  mandando «reencodear a WebP» un logo vectorial. Bytes verificados con curl.
texto  "cm · ya NO acusa a meta.svg por B/px"         NO "meta.svg" \
       perl $QA https://climentmedia.com/ --solo rendimiento --cache "$CACHE"
texto  "cm · ya NO acusa a googleads.svg por B/px"    NO "googleads.svg" \
       perl $QA https://climentmedia.com/ --solo rendimiento --cache "$CACHE"
espera "cm · los SVG se vigilan por PESO, y pasan"    PASA REN-02b perl $QA https://climentmedia.com/ --solo rendimiento --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: el check de B/px NO se ha desactivado. El logo BITMAP de
#    site-a (1080x1080 en un hueco de 40x40) sigue siendo FALLO.
espera "site-a · el PNG sobredimensionado sigue FALLANDO" FALLO REN-02 perl $QA https://site-a.example/ --solo rendimiento --una-sola --cache "$KCACHE"
texto  "site-a · y lo sigue diciendo en B/px"           SI "B/px" \
       perl $QA https://site-a.example/ --solo rendimiento --una-sola --cache "$KCACHE"

echo
echo "== ARREGLO P5 · EL ALCANCE SE EMITE Y EL DENOMINADOR ES EL SITIO"
texto  "el denominador ya NO es la lista auditada"    SI "denominador: el SITIO" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "y dice cuantas de la lista, aparte"           SI "de la lista auditada)" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: «TODAS» solo puede salir si de verdad se han mirado
#    todas las del SITIO. En site-b se miran 11 de 67: no puede aparecer.
texto  "site-b · 11 de 67: NO dice «TODAS»"          NO "· TODAS" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "y cuando no sabe el total del sitio, lo DICE" SI "no se cuantas paginas tiene el sitio" \
       perl $QA https://climentmedia.com/ --sin-red --sin-recibo
# 🔴 EL RECIBO. Antes decia SIEMPRE «ALCANCE: NO DECLARADO».
{
  RREPO="$CACHE/repo-alcance"; mkdir -p "$RREPO"; printf '<!doctype html><title>x</title>\n' > "$RREPO/index.html"
  perl $QA https://site-c.example/ --solo seo --una-sola --repo "$RREPO" --recibo "$CACHE/recibo-alcance" --cache "$CACHE" >/dev/null 2>&1
  if grep -q '^ALCANCE-URLS:' "$CACHE/recibo-alcance" 2>/dev/null; then
    printf '  OK    %-46s %s\n' "el recibo YA declara su alcance" "$(grep -m1 '^ALCANCE-URLS:' "$CACHE/recibo-alcance")"; ok=$((ok+1))
  else
    printf '  MAL   %-46s sigue sin declararlo\n' "el recibo YA declara su alcance"; ko=$((ko+1))
  fi
  if grep -q '^ALCANCE-URL-001:' "$CACHE/recibo-alcance" 2>/dev/null; then
    printf '  OK    %-46s %s\n' "y sella la LISTA de URLs medidas" "$(grep -m1 '^ALCANCE-URL-001:' "$CACHE/recibo-alcance")"; ok=$((ok+1))
  else
    printf '  MAL   %-46s no hay lista de URLs\n' "y sella la LISTA de URLs medidas"; ko=$((ko+1))
  fi
  # 🔴 CONTROL NEGATIVO: la linea vieja NO puede seguir apareciendo.
  if grep -q '^ALCANCE: NO DECLARADO' "$CACHE/recibo-alcance" 2>/dev/null; then
    printf '  MAL   %-46s sigue diciendo NO DECLARADO\n' "ya no dice «ALCANCE: NO DECLARADO»"; ko=$((ko+1))
  else
    printf '  OK    %-46s NO\n' "ya no dice «ALCANCE: NO DECLARADO»"; ok=$((ok+1))
  fi
  rm -rf "$RREPO"
}

echo
echo "== CERO PAGINAS LEIDAS ES «NO VERIFICADO», NUNCA «PASA»"
#  Lo destapo el propio arreglo 0.3: al agregar sobre @PAGES con un `next` por
#  cada pagina ilegible, una lente sobre CERO paginas salia entera en verde.
espera "sin red · la lente de a11y NO sale por PASA"   NOVERIF A11Y-00 perl $QA https://climentmedia.com/ --sin-red --sin-recibo
espera "sin red · dice cuales no ha podido leer"       NOVERIF A11Y-0x perl $QA https://climentmedia.com/ --sin-red --sin-recibo
espera "sin red · la de rendimiento tampoco"           NOVERIF REN-00  perl $QA https://climentmedia.com/ --sin-red --sin-recibo
espera "sin red · ni la de estructura"                 NOVERIF EST-01  perl $QA https://climentmedia.com/ --sin-red --sin-recibo
# 🔴 CONTROL NEGATIVO: con red, ninguno de esos avisos aparece.
espera "con red · A11Y-00 no existe"                   AUSENTE A11Y-00 perl $QA https://climentmedia.com/ --solo a11y --una-sola --cache "$CACHE"
espera "con red · A11Y-0x no existe"                   AUSENTE A11Y-0x perl $QA https://climentmedia.com/ --solo a11y --una-sola --cache "$CACHE"

echo
echo "== ARREGLO 0.3 · LA LOTERIA DEL ORDEN"
#  Las MISMAS dos URLs, solo cambia el orden. Antes: A11Y-08 FALLO / PASA.
{
  printf 'https://site-c.example/\nhttps://site-c.example/tarot-del-amor\n' > "$CACHE/ord-A.txt"
  printf 'https://site-c.example/tarot-del-amor\nhttps://site-c.example/\n' > "$CACHE/ord-B.txt"
  for o in A B; do
    perl $QA "@$CACHE/ord-$o.txt" --sin-recibo --cache "$CACHE" 2>&1 \
      | grep -E '^\s+\[[A-Z ]+\] ' | sed 's/  *$//' > "$CACHE/ord-$o.veredictos"
  done
  if diff -q "$CACHE/ord-A.veredictos" "$CACHE/ord-B.veredictos" >/dev/null; then
    printf '  OK    %-46s %s\n' "mismo veredicto en los dos ordenes" "$(wc -l < "$CACHE/ord-A.veredictos") checks identicos"; ok=$((ok+1))
  else
    printf '  MAL   %-46s el veredicto DEPENDE del orden:\n' "mismo veredicto en los dos ordenes"; ko=$((ko+1))
    diff "$CACHE/ord-A.veredictos" "$CACHE/ord-B.veredictos" | sed 's/^/          /'
  fi
}
# 🔴 CONTROL NEGATIVO: que coincidan no puede ser por haberse callado. El fallo
#    real de jerarquia de la home tiene que seguir ahi en LOS DOS ordenes.
for o in A B; do
  if grep -qE '^\s+\[FALLO   \] A11Y-08' "$CACHE/ord-$o.veredictos"; then
    printf '  OK    %-46s orden %s -> A11Y-08 FALLO\n' "el fallo real sigue vivo, no se ha apagado" "$o"; ok=$((ok+1))
  else
    printf '  MAL   %-46s orden %s: A11Y-08 ya no falla\n' "el fallo real sigue vivo, no se ha apagado" "$o"; ko=$((ko+1))
  fi
done

echo
echo "== ARREGLO CANDIDATO · MEDIR EL ARBOL QUE SE VA A SUBIR (11-ago-2026)"
#  🔴 EL FALLO QUE ESTA SECCION VIGILA. El recibo SELLABA EL ARBOL DEL REPO y
#     sacaba el VEREDICTO de medir PRODUCCION. Los dos sentidos hacen dano:
#       · site-d, 11-ago: recibo FALLA por 11 defectos que el arbol YA arregla.
#         El gate se negaba a subir el arreglo porque produccion estaba mal, y
#         produccion estaba mal porque no se habia subido el arreglo.
#       · y al reves: un arbol con un defecto NUEVO sacaba VERDE en ese check si
#         produccion estaba bien. Eso es el par 「roto·candidato / roto·produccion」
#         de aqui abajo, y es el control negativo mas importante del fichero.
#  ⚠️ TODO lo que toca un repo de verdad va con --sin-recibo o con --recibo a la
#     cache: la bateria NO puede pisar el .qa-recibo de una web viva.
BCREPO="$REPOS/site-d-web"

# --- 1 · lo que el candidato NO puede medir sale NO VERIFICADO, nunca PASA ---
#     Los cuatro. Si alguno saliera PASA, el gate estaria aprobando algo que ha
#     contestado su propio servidor de pruebas.
espera "candidato · G11 no se mide contra si mismo"    NOVERIF EST-09 perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo estructura --sin-recibo
espera "candidato · la compresion es del host"         NOVERIF REN-08 perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo rendimiento --sin-recibo
espera "candidato · Cache-Control es del host"         NOVERIF REN-09 perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo rendimiento --sin-recibo
espera "candidato · el ESTADO 404 es del host"         NOVERIF EST-03 perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo estructura --sin-recibo
# 🔴 CONTROLES NEGATIVOS: los mismos checks contra PRODUCCION siguen midiendo.
#    Sin esto, «NO VERIFICADO en candidato» podria ser un check apagado del todo.
espera "produccion · REN-08 sigue midiendo y pasa"     PASA  REN-08 perl $QA https://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
espera "produccion · EST-09 sigue cazando el desfase"  FALLO EST-09 perl $QA https://site-d.example/ --repo "$BCREPO" --solo estructura --sin-recibo --cache "$CACHE"
espera "EST-03 sigue cazando un 404 callejon" FALLO EST-03 perl $QA $U404 --solo estructura --una-sola

# --- 2 · el candidato VE los arreglos que produccion todavia no tiene --------
#     Verificado a mano el 11-ago: el repo declara --primary oklch(0.54 ...) y
#     produccion sirve oklch(0.58 ...); el repo trae favicon.svg (262 B) y
#     produccion devuelve HTTP 404 en /favicon.svg.
espera "candidato · la paleta del repo YA llega a AA"  PASA  A11Y-03 perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo a11y --sin-recibo
espera "produccion · la paleta subida sigue por debajo" FALLO A11Y-03 perl $QA https://site-d.example/ --solo a11y --una-sola --cache "$CACHE"
espera "candidato · el favicon del repo existe"        PASA  REN-07 perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo rendimiento --sin-recibo
espera "produccion · el favicon subido sigue en 404"   FALLO REN-07 perl $QA https://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"

# --- 3 · el informe dice CONTRA QUE se midio --------------------------------
texto  "el informe declara que mide el CANDIDATO"    SI "MEDIDO       🔴 CANDIDATO" \
       perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo seo --sin-recibo
texto  "y enumera lo que no ha podido medir"         SI "LO QUE EL CANDIDATO NO PUEDE MEDIR" \
       perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo estructura --sin-recibo
# 🔴 CONTROL NEGATIVO: midiendo produccion NO puede decir que mide el candidato.
texto  "produccion NO se hace pasar por candidato"   NO "MEDIDO       🔴 CANDIDATO" \
       perl $QA https://site-d.example/ --solo seo --una-sola --cache "$CACHE"
texto  "produccion lo dice tambien, con su aviso"    SI "MEDIDO       PRODUCCION" \
       perl $QA https://site-d.example/ --solo seo --una-sola --cache "$CACHE"

# --- 4 · 🔴 EL CONTROL NEGATIVO DE VERDAD: UN ARBOL ROTO NO SACA VERDE ------
#     Se rompe una COPIA (nunca el repo real): se quita el <h1> de la home.
{
  ROTO="$CACHE/bc-roto"
  rm -rf "$ROTO"
  if cp -r "$BCREPO" "$ROTO" 2>/dev/null; then
    rm -f "$ROTO/.qa-recibo"
    perl -i -pe 's{<h1([^>]*)>(.*?)</h1>}{<p$1>$2</p>}' "$ROTO/index.html"
    if grep -q '<h1' "$ROTO/index.html"; then
      printf '  MAL   %-46s la copia sigue teniendo <h1>: la prueba no probaria nada\n' "preparar el arbol roto"; ko=$((ko+1))
    else
      printf '  OK    %-46s <h1> fuera de la home de la copia\n' "preparar el arbol roto"; ok=$((ok+1))
      espera "roto · el candidato LO CAZA"            FALLO SEO-09 perl $QA https://site-d.example/ --repo "$ROTO" --candidato --una-sola --solo seo --sin-recibo
      # 🔴 EXPECTATIVA CADUCADA EL 11-ago-2026 · aqui se esperaba FALLO SEO-14
      #    sobre este mismo arbol, y era un ARTEFACTO del umbral viejo
      #    (`length($txt) < 200 || @h1 == 0`). El fixture solo pierde el <h1>
      #    —pasa a <p>— y sigue sirviendo 1.435 caracteres de contenido, medidos.
      #    Un SEO-14 en FALLO ahi decia «esta pagina solo existe si se ejecuta
      #    JS» de una pagina que trae su contenido entero en el HTML: era la
      #    acusacion de SEO-09 —la linea de arriba, que SIGUE en FALLO— repetida
      #    bajo un titulo que no es el suyo.
      #    La linea NO se borra: se le da la vuelta y pasa a ser el CONTROL
      #    NEGATIVO del arreglo. Si SEO-14 vuelve a apuntarse el tanto de
      #    SEO-09, esto sale MAL.
      espera "roto · SEO-14 NO se apunta el tanto de SEO-09" PASA SEO-14 perl $QA https://site-d.example/ --repo "$ROTO" --candidato --una-sola --solo seo --sin-recibo
      # 🔴 LA OTRA MITAD DEL FALLO, EN UNA LINEA: el MISMO arbol roto, medido
      #    contra produccion, saca PASA en el mismo check. Este caso tiene que
      #    seguir saliendo PASA: es la prueba de que sin --candidato el recibo
      #    no dice nada del arbol que sella.
      espera "roto · midiendo PRODUCCION el defecto NO existe" PASA SEO-09 perl $QA https://site-d.example/ --repo "$ROTO" --solo seo --una-sola --sin-recibo --cache "$CACHE"
    fi
  else
    printf '  MAL   %-46s no he podido copiar %s\n' "preparar el arbol roto" "$BCREPO"; ko=$((ko+1))
  fi
  rm -rf "$ROTO"
}

# --- 5 · el RECIBO dice contra que se midio ---------------------------------
{
  RC="$CACHE/recibo-candidato"
  perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --una-sola --recibo "$RC" >/dev/null 2>&1
  for par in "MEDIDO-CONTRA: CANDIDATO|el recibo dice que midio el CANDIDATO" \
             "SITIO: https://site-d.example|el SITIO sigue siendo el dominio real" \
             "NV-POR-CANDIDATO:|separa los NV que contesta G11"; do
    lit="${par%%|*}"; eti="${par#*|}"
    if grep -q "^$lit" "$RC" 2>/dev/null; then
      printf '  OK    %-46s %s\n' "$eti" "$(grep -m1 "^$lit" "$RC")"; ok=$((ok+1))
    else
      printf '  MAL   %-46s falta la linea «%s»\n' "$eti" "$lit"; ko=$((ko+1))
    fi
  done
  # 🔴 CONTROL NEGATIVO: el SITIO del recibo NUNCA puede ser el localhost donde
  #    se midio. Lo compara desplegar.sh, y un recibo apuntando a 127.0.0.1
  #    haria que G11 midiera el servidor de pruebas en vez de la web.
  if grep -q '^SITIO:.*127\.0\.0\.1' "$RC" 2>/dev/null; then
    printf '  MAL   %-46s el SITIO se ha contaminado con el localhost\n' "el SITIO no es 127.0.0.1"; ko=$((ko+1))
  else
    printf '  OK    %-46s NO\n' "el SITIO no es 127.0.0.1"; ok=$((ok+1))
  fi
  # y el de PRODUCCION se declara como tal
  RP="$CACHE/recibo-produccion"
  perl $QA https://site-d.example/ --repo "$BCREPO" --una-sola --recibo "$RP" --cache "$CACHE" >/dev/null 2>&1
  if grep -q '^MEDIDO-CONTRA: PRODUCCION' "$RP" 2>/dev/null; then
    printf '  OK    %-46s %s\n' "el recibo de produccion se declara" "$(grep -m1 '^MEDIDO-CONTRA:' "$RP")"; ok=$((ok+1))
  else
    printf '  MAL   %-46s no dice MEDIDO-CONTRA: PRODUCCION\n' "el recibo de produccion se declara"; ko=$((ko+1))
  fi
}

# --- 6 · las guardas de --candidato -----------------------------------------
#     «No se pudo correr» sale en 2, nunca en 0. Un modo que no arranca y un
#     modo que arranca y aprueba NO se pueden ver igual desde un script.
{
  out="$(perl $QA https://site-d.example/ --candidato 2>&1)"; rc=$?
  if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q -- '--candidato necesita --repo'; then
    printf '  OK    %-46s exit 2 y lo dice\n' "--candidato sin --repo no arranca"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s\n' "--candidato sin --repo no arranca" "$rc"; ko=$((ko+1))
  fi
  out="$(perl $QA https://site-d.example/ --repo "$BCREPO" --candidato --sin-red 2>&1)"; rc=$?
  if [ "$rc" = 2 ]; then
    printf '  OK    %-46s exit 2\n' "--candidato con --sin-red no arranca"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s (deberia ser 2)\n' "--candidato con --sin-red no arranca" "$rc"; ko=$((ko+1))
  fi
}

# --- 7 · LA PUERTA · acepta el candidato Y SIGUE EXIGIENDO G11 --------------
#     Fixture entera: un repo de dos ficheros, su recibo escrito por el propio
#     receipt.pl a partir de un JSON, y un servidor de mentira para el G11.
#     NADA de esto toca una web viva: SITIO es 127.0.0.1 y SUBIDA es un `echo`.
{
  RV="$CACHE/repo-verde"; rm -rf "$RV"; mkdir -p "$RV/_deploy"
  printf '<!doctype html><html lang="es"><head><title>x</title></head><body><main><h1>x</h1></main></body></html>\n' > "$RV/index.html"
  printf ':root{--a:#000}\n' > "$RV/styles.css"
  # servidor de mentira para G11: sirve ESOS dos ficheros y nada mas
  cat > "$CACHE/fixture-server.pl" <<'SRV'
use strict; use warnings; use IO::Socket::INET;
my ($puerto, $dir) = @ARGV;
my $s = IO::Socket::INET->new(Listen=>16, LocalAddr=>'127.0.0.1', LocalPort=>$puerto,
                              Proto=>'tcp', ReuseAddr=>1) or die "socket: $!\n";
$| = 1; print "LISTO\n";
while (my $c = $s->accept) {
    my $l = <$c>; next unless defined $l;
    while (defined(my $x = <$c>)) { last if $x =~ /^\r?\n$/ }
    my ($ruta) = $l =~ m{^\w+\s+(\S+)} ? ($1) : ('/');
    $ruta =~ s/\?.*$//;
    my $f = $ruta eq '/' ? "$dir/index.html" : "$dir$ruta";
    my $b = ''; my $code = '404 Not Found';
    if (-f $f && open my $fh, '<:raw', $f) { local $/; $b = <$fh> // ''; close $fh; $code = '200 OK' }
    print $c "HTTP/1.1 $code\r\nContent-Type: text/plain\r\nContent-Length: " . length($b) . "\r\nConnection: close\r\n\r\n$b";
    close $c;
}
SRV
  # 🔴 25-ago-2026 · ESTO ERA EL BANCO INTERMITENTE, y costo encontrarlo.
  # Antes: `PUERTO=$(( 40000 + ($$ % 20000) ))` sin comprobar que estuviera
  # libre, y una espera de 3 s que **se rendia EN SILENCIO**. Si el puerto ya
  # estaba ocupado -por otra corrida, o por un servidor de pruebas olvidado en
  # la maquina- el fixture NO arrancaba, la prueba seguia como si nada, y el
  # control negativo de G11 salia MAL sin motivo aparente.
  # Medido en cuatro corridas seguidas del MISMO arbol: 874/12rojo · 886/0 ·
  # 888/0 · 887/1rojo. Un banco que da un numero distinto cada vez no puede
  # decir si un defecto de una web es un defecto o es suyo.
  # Es la misma trampa que el CLAUDE.md de site-a ya tenia escrita en §14.6: un
  # puerto ocupado responde 200 y mides el arbol de otro.
  PUERTO=$(( 40000 + ($$ % 20000) ))
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    # /dev/tcp es portable a Git Bash; `ss` no existe en esta maquina
    if (exec 3<>/dev/tcp/127.0.0.1/$PUERTO) 2>/dev/null; then
      exec 3<&- 2>/dev/null; exec 3>&- 2>/dev/null
      PUERTO=$(( PUERTO + 1 ))
    else
      break
    fi
  done
  perl "$CACHE/fixture-server.pl" "$PUERTO" "$RV" > "$CACHE/srv.log" 2>&1 &
  SRVPID=$!
  # 🔑 Y el arranque se AFIRMA. Rendirse en silencio es lo que convertia un
  # fallo de infraestructura en un fallo de G11 que no existia.
  arranco=no
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    grep -q LISTO "$CACHE/srv.log" 2>/dev/null && { arranco=si; break; }
    sleep 0.3
  done
  if [ "$arranco" != si ]; then
    printf '  MAL   %-46s puerto %s\n' "el servidor de fixture NO arranco" "$PUERTO"; ko=$((ko+1))
  else
    printf '  OK    %-46s puerto %s\n' "el servidor de fixture arranco" "$PUERTO"; ok=$((ok+1))
  fi
  printf 'SITIO=http://127.0.0.1:%s\nSUBIDA=%s\n' "$PUERTO" "'echo \"   (subida simulada)\"'" > "$RV/_deploy/deploy.conf"
  sed -e "s|__SITIO__|http://127.0.0.1:$PUERTO|g" > "$CACHE/qa-verde.json" <<'JSON'
{ "sitio": "__SITIO__", "veredicto": "PASA",
  "medido_contra": "CANDIDATO", "medido_en": "http://127.0.0.1:55555",
  "nv_por_candidato": ["REN-08","REN-09","EST-03","EST-09"],
  "resumen": { "fallo": 0, "aviso": 0, "no_verificado": 4, "pasa": 4 },
  "instrumento": { "perl": "5.0" },
  "alcance": { "sitio_urls": 1, "lista_urls": 1, "documentos": 1, "por_lente": {
      "SEO": { "miradas": 1, "urls": ["__SITIO__/"], "nota": "" },
      "RENDIMIENTO": { "miradas": 1, "urls": ["__SITIO__/"], "nota": "" },
      "ACCESIBILIDAD": { "miradas": 1, "urls": ["__SITIO__/"], "nota": "" },
      "MEDICION": { "miradas": 1, "urls": ["__SITIO__/"], "nota": "" },
      "ESTRUCTURA": { "miradas": 1, "urls": ["__SITIO__/"], "nota": "" } } },
  "comprobaciones": [
    { "lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t" },
    { "lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t" },
    { "lente":"RENDIMIENTO","id":"REN-08","estado":"NV","titulo":"t" },
    { "lente":"RENDIMIENTO","id":"REN-09","estado":"NV","titulo":"t" },
    { "lente":"ACCESIBILIDAD","id":"A11Y-01","estado":"PASA","titulo":"t" },
    { "lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t" },
    { "lente":"ESTRUCTURA","id":"EST-03","estado":"NV","titulo":"t" },
    { "lente":"ESTRUCTURA","id":"EST-09","estado":"NV","titulo":"t" },
    { "lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t" } ] }
JSON
  perl ../receipt.pl --escribir --repo "$RV" --json "$CACHE/qa-verde.json" --sitio "http://127.0.0.1:$PUERTO" >/dev/null 2>&1

  salida="$(bash ../desplegar.sh "$RV" 2>&1)"; rc=$?
  if [ "$rc" = 0 ] && printf '%s' "$salida" | grep -q 'medido contra: CANDIDATO'; then
    printf '  OK    %-46s el gate acepta el recibo de candidato\n' "desplegar.sh · recibo de CANDIDATO vale"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s\n' "desplegar.sh · recibo de CANDIDATO vale" "$rc"; ko=$((ko+1))
    printf '%s\n' "$salida" | tail -6 | sed 's/^/          /'
  fi
  # 🔴 los NV que son «del candidato» NO pueden exigir --aun-asi: si lo
  #    exigieran en cada despliegue, --aun-asi dejaria de significar nada.
  if printf '%s' "$salida" | grep -q 'Quedan 0 sin mirar de verdad'; then
    printf '  OK    %-46s 4 NV, 0 huecos reales\n' "los NV del candidato no piden --aun-asi"; ok=$((ok+1))
  else
    printf '  MAL   %-46s no separa los NV del candidato\n' "los NV del candidato no piden --aun-asi"; ko=$((ko+1))
  fi
  # el bucle entero: subir (simulado) y G11 EN VERDE contra lo servido
  salida="$(bash ../desplegar.sh "$RV" --subir 2>&1)"; rc=$?
  if [ "$rc" = 0 ] && printf '%s' "$salida" | grep -q 'desplegado y verificado contra el recibo'; then
    printf '  OK    %-46s candidato -> subir -> G11 verde\n' "los DOS momentos, de punta a punta"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s\n' "los DOS momentos, de punta a punta" "$rc"; ko=$((ko+1))
    printf '%s\n' "$salida" | tail -8 | sed 's/^/          /'
  fi
  # 🔴 CONTROL NEGATIVO: si lo servido NO es lo del recibo, G11 tiene que
  #    seguir cerrando la puerta. Un recibo de candidato NO exime de G11: esa
  #    es la mitad de todo el arreglo.
  printf ':root{--a:#fff} /* lo servido ya no es lo medido */\n' > "$RV/styles.css.bak"
  mv "$RV/styles.css" "$RV/styles.css.medido"; mv "$RV/styles.css.bak" "$RV/styles.css"
  salida="$(bash ../desplegar.sh "$RV" --servido 2>&1)"; rc=$?
  if [ "$rc" != 0 ] && printf '%s' "$salida" | grep -q 'PRODUCCION NO SIRVE LO QUE SE MIDIO'; then
    printf '  OK    %-46s exit %s\n' "G11 sigue cerrando con recibo de candidato" "$rc"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s: G11 dejo pasar un desfase\n' "G11 sigue cerrando con recibo de candidato" "$rc"; ko=$((ko+1))
  fi
  kill "$SRVPID" 2>/dev/null
  rm -rf "$RV"
}

echo
echo "== ARREGLO FALSOS POSITIVOS · MED-05 · MED-10 · REN-04 (11-ago-2026)"
#  🔴 POR QUE. El gate de site-a daba 8 FALLOS y CERO eran defectos del arbol:
#     tres eran falsos positivos SUYOS (estos) y cinco decisiones del cliente.
#     Un gate que acusa de lo que no existe se apaga solo, y el dia que lo
#     apaguen tampoco protegera de los defectos de verdad.
#  ⚠️ CADA ARREGLO VA CON SU CONTROL NEGATIVO. Sin el, «ya no acusa» no se
#     distingue de «ya no mira», que es exactamente el modo de fallo que este
#     fichero existe para impedir. Los tres negativos se construyen ROMPIENDO
#     UNA COPIA del arbol de site-a —nunca el repo real— y comprobando que el
#     gate vuelve a acusar.
{
  KREPO="$REPOS/site-a-web"
  KURL="https://site-a.example"

  # --- 1 · MED-05 · el patron no entendia un selector CON VALOR -------------
  #     Verificado a mano: el lector existe y esta en script.js:263,
  #     `[data-pop-act="close"]`. El patron viejo era `\[data-([a-z0-9-]+)\]`
  #     y por llevar `="close"` no casaba. Y ademas se acusaba a data-col y
  #     data-sec, que viven en ramas de _gen.ps1 que hoy no emite ninguna
  #     pagina: eso es NO APLICA, no FALLO.
  espera "MED-05 · site-a ya no acusa (lector con valor)"   PASA MED-05 \
         perl $QA "$KURL/" --repo "$KREPO" --solo medicion --sin-red --sin-recibo
  texto  "MED-05 · y dice cuales son NO APLICA y por que"  SI "NO APLICA (escritos y nunca emitidos)" \
         perl $QA "$KURL/" --repo "$KREPO" --solo medicion --sin-red --sin-recibo

  # 🔴 CONTROL NEGATIVO 1a · EL FALLO MAS CARO DEL PARQUE, REPRODUCIDO.
  #    site-d emitia `data-thanks` en una pagina y no lo leia nadie: la
  #    conversion estaba muerta. Se reproduce quitandole a la COPIA de site-a su
  #    lector de data-thanks (script.js:188), dejando el atributo emitido en
  #    merci.html. Si esto deja de saltar, el arreglo esta roto.
  KROTO="$CACHE/site-a-med05"; rm -rf "$KROTO"
  if cp -r "$KREPO" "$KROTO" 2>/dev/null; then
    rm -f "$KROTO/.qa-recibo"
    perl -i -pe "s/getAttribute\('data-thanks'\)/getAttribute('data-OTRA-COSA')/" "$KROTO/script.js"
    if grep -q "getAttribute('data-thanks')" "$KROTO/script.js" || ! grep -q 'data-thanks' "$KROTO/merci.html"; then
      printf '  MAL   %-46s la copia no reproduce el caso: no probaria nada\n' "preparar el caso data-thanks"; ko=$((ko+1))
    else
      printf '  OK    %-46s lector fuera, atributo emitido en merci.html\n' "preparar el caso data-thanks"; ok=$((ok+1))
      espera "MED-05 · data-thanks emitido y SIN lector: FALLA" FALLO MED-05 \
             perl $QA "$KURL/" --repo "$KROTO" --solo medicion --sin-red --sin-recibo
      texto  "MED-05 · y lo nombra por su nombre"              SI "data-thanks" \
             perl $QA "$KURL/" --repo "$KROTO" --solo medicion --sin-red --sin-recibo
    fi
    # 🔴 CONTROL NEGATIVO 1b · que el reconocimiento del selector CON VALOR
    #    este haciendo trabajo de verdad: se le quita a la copia ese lector y
    #    data-pop-act tiene que volver a salir acusado.
    rm -rf "$KROTO"; cp -r "$KREPO" "$KROTO" 2>/dev/null
    rm -f "$KROTO/.qa-recibo"
    perl -i -pe 's/\[data-pop-act="close"\]/[data-NADA="close"]/' "$KROTO/script.js"
    espera "MED-05 · sin ese lector, data-pop-act vuelve"  FALLO MED-05 \
           perl $QA "$KURL/" --repo "$KROTO" --solo medicion --sin-red --sin-recibo
  else
    printf '  MAL   %-46s no se pudo copiar el repo\n' "preparar copias de site-a"; ko=$((ko+1))
  fi

  # --- 2 · MED-10 · el servidor del candidato no ejecuta PHP ----------------
  #     Daba 404 a /contact.php porque el servidor de pruebas sirve ficheros.
  #     Produccion contesta 405 a un GET, medido. La cabecera ya tenia la
  #     doctrina («lo que el candidato no puede medir sale NO VERIFICADO») y
  #     este check no estaba en la lista.
  espera "MED-10 · el candidato NO juzga un receptor PHP"  NOVERIF MED-10 \
         perl $QA "$KURL/" --repo "$KREPO" --candidato --una-sola --contacto /contact --solo medicion --sin-recibo
  texto  "MED-10 · y dice por que no lo puede medir"       SI "manejador de servidor (.php)" \
         perl $QA "$KURL/" --repo "$KREPO" --candidato --una-sola --contacto /contact --solo medicion --sin-recibo
  # el barrido encontro un segundo check con la misma dependencia
  espera "MED-12 · /_leads/ lo cierra el host, no el arbol" NOVERIF MED-12 \
         perl $QA "$KURL/" --repo "$KREPO" --candidato --una-sola --solo medicion --sin-recibo

  # 🔴 CONTROL NEGATIVO 2a · PRODUCCION SI LO MIDE. Si esto no fuera PASA, el
  #    NO VERIFICADO de arriba seria un check apagado del todo.
  espera "MED-10 · produccion SI mide el receptor"         PASA MED-10 \
         perl $QA "$KURL/" --contacto /contact --solo medicion --cache "$CACHE"
  espera "MED-12 · en produccion no sale NO VERIFICADO"    AUSENTE MED-12 \
         perl $QA "$KURL/" --solo medicion --cache "$CACHE"
  # 🔴 CONTROL NEGATIVO 2b · el NV NO es un interruptor general: un receptor
  #    ESTATICO que no existe sigue siendo FALLO contra el candidato.
  KROTO2="$CACHE/site-a-med10"; rm -rf "$KROTO2"
  if cp -r "$KREPO" "$KROTO2" 2>/dev/null; then
    rm -f "$KROTO2/.qa-recibo"
    perl -i -pe 's{action="/contact\.php"}{action="/receptor-que-no-existe.html"}' "$KROTO2/contact.html"
    if grep -q 'action="/receptor-que-no-existe.html"' "$KROTO2/contact.html"; then
      printf '  OK    %-46s action a un .html inexistente\n' "preparar el receptor estatico roto"; ok=$((ok+1))
      espera "MED-10 · receptor ESTATICO en 404: sigue FALLO" FALLO MED-10 \
             perl $QA "$KURL/" --repo "$KROTO2" --candidato --una-sola --contacto /contact --solo medicion --sin-recibo
    else
      printf '  MAL   %-46s no se pudo cambiar el action\n' "preparar el receptor estatico roto"; ko=$((ko+1))
    fi
  fi

  # --- 3 · REN-04 · sumaba fuentes que el navegador no descarga -------------
  #     Los 4 .woff2 de site-a llevan `unicode-range`; Chrome baja 2 (112,9 KB).
  #     Y hay 0 caracteres latin-ext en todo el arbol, contado aparte.
  texto  "REN-04 · declara el metodo dentro del DATO"       SI "metodo: unicode-range cruzado con" \
         perl $QA "$KURL/" --solo rendimiento --cache "$CACHE"
  # 🔴 CONTROL NEGATIVO 3a · UNA FUENTE SIN unicode-range SIGUE SUMANDO.
  #    Se le quitan los rangos a la COPIA: vuelven los 4 ficheros y los 254 KB.
  KROTO3="$CACHE/site-a-ren04"; rm -rf "$KROTO3"
  if cp -r "$KREPO" "$KROTO3" 2>/dev/null; then
    rm -f "$KROTO3/.qa-recibo"
    # ⚠️ `-0777`: la declaracion `unicode-range:` de site-a OCUPA DOS LINEAS. Con
    #    el `-pe` de siempre no casaba, el fichero salia intacto y la prueba
    #    «pasaba» midiendo el arbol bueno. Un control negativo que no rompe
    #    nada no es un control negativo: por eso debajo se comprueba que ya no
    #    queda ni un `unicode-range` ANTES de creerse el resultado.
    perl -i -0777 -pe 's/\s*unicode-range\s*:[^;}]*;//g' "$KROTO3/styles.css"
    if grep -q 'unicode-range' "$KROTO3/styles.css"; then
      printf '  MAL   %-46s siguen los unicode-range: no probaria nada\n' "preparar fuentes sin unicode-range"; ko=$((ko+1))
    else
      printf '  OK    %-46s 0 unicode-range en la copia\n' "preparar fuentes sin unicode-range"; ok=$((ok+1))
      espera "REN-04 · sin unicode-range vuelven a contar" FALLO REN-04 \
             perl $QA "$KURL/" --repo "$KROTO3" --candidato --una-sola --solo rendimiento --sin-recibo
      texto  "REN-04 · y son los 4 ficheros otra vez"      SI "4 ficheros" \
             perl $QA "$KURL/" --repo "$KROTO3" --candidato --una-sola --solo rendimiento --sin-recibo
    fi
  fi
  # 🔴 CONTROL NEGATIVO 3b · UN RANGO QUE EL SITIO SI USA TAMBIEN SUMA.
  #    Se mete un caracter latin-ext (U+0101 «a» con macron) en la home de la
  #    copia: los dos ficheros latin-ext pasan a bajarse y REN-04 vuelve a
  #    acusar. Esto es lo que impide que el arreglo sea un descuento general.
  KROTO4="$CACHE/site-a-ren04b"; rm -rf "$KROTO4"
  if cp -r "$KREPO" "$KROTO4" 2>/dev/null; then
    rm -f "$KROTO4/.qa-recibo"
    perl -i -pe 's{</main>}{<p>\&#x101;</p></main>}' "$KROTO4/index.html"
    if grep -q '&#x101;' "$KROTO4/index.html"; then
      printf '  OK    %-46s U+0101 metido en la home de la copia\n' "preparar un caracter latin-ext"; ok=$((ok+1))
      espera "REN-04 · rango que el sitio SI usa: sigue FALLO" FALLO REN-04 \
             perl $QA "$KURL/" --repo "$KROTO4" --candidato --una-sola --solo rendimiento --sin-recibo
    else
      printf '  MAL   %-46s no se pudo meter el caracter\n' "preparar un caracter latin-ext"; ko=$((ko+1))
    fi
  fi
  rm -rf "$KROTO" "$KROTO2" "$KROTO3" "$KROTO4"
}

echo
echo "== ACEPTADO · el silenciador, y las cerraduras que lleva (11-ago-2026)"
#  🔴 Un silenciador SIN pruebas no deberia existir. Estos casos no comprueban
#     que sepa ACEPTAR —eso es lo facil y se ve a simple vista—: comprueban que
#     se NIEGUE. Seis de los ocho son controles NEGATIVOS a proposito, porque el
#     modo de fallo de esta funcion no es «no acepta», es «acepta de mas».
#  ⚠️ Fixture entera dentro de $CACHE: NO toca el repo de ninguna web viva, y
#     todo va con --sin-recibo salvo el caso que comprueba el recibo, que
#     escribe en $CACHE y no en el repo.
{
  RA="$CACHE/repo-aceptado"; rm -rf "$RA"; mkdir -p "$RA/_deploy"
  printf '<!doctype html><html lang="es"><head><title>x</title></head><body><main><h1>x</h1></main></body></html>\n' > "$RA/index.html"
  BCQA="perl $QA https://site-d.example/ --repo $RA --solo medicion --sin-recibo --cache $CACHE"

  # La huella NO se escribe a mano: se saca de la linea HUELLA que imprime el
  # propio informe. Asi este caso prueba ademas el flujo real —copiar la huella
  # del informe al conf— y no se rompe si cambia la evidencia de site-d.
  H="$($BCQA -q 2>&1 | grep -A4 -E '^\s+\[FALLO\s*\] MED-07 ' | grep -m1 'HUELLA ' | sed -E 's/^[[:space:]]*HUELLA //')"
  if [ -n "$H" ]; then
    printf '  OK    %-46s %s\n' "el informe imprime la HUELLA de cada FALLO" "$(printf '%.42s...' "$H")"; ok=$((ok+1))
  else
    printf '  MAL   %-46s no hay linea HUELLA en el FALLO MED-07\n' "el informe imprime la HUELLA de cada FALLO"; ko=$((ko+1))
  fi

  # conf <HALLAZGO> [<FECHA>] [<HASTA>] [<sin-motivo>]
  conf() {
    { echo "[ACEPTADO]"
      echo "CHECK:    MED-07"
      echo "HALLAZGO: $1"
      [ "${4:-}" = "sin-motivo" ] || echo "MOTIVO:   Texto legal del cliente: se propone, no se inventa."
      echo "ACEPTA:   Manuel Climent"
      echo "FECHA:    ${2:-2026-08-11}"
      [ -z "${3:-}" ] || echo "HASTA:    $3"
    } > "$RA/_deploy/aceptado.conf"
  }

  # 1 · POSITIVO · entrada completa y en fecha: deja de contar
  conf "$H"
  espera "entrada completa · deja de contar"            ACEPTADO MED-07 $BCQA -q
  # 2 · y el veredicto NUNCA se lee «PASA» a secas
  texto "el veredicto declara los aceptados"            SI "(con 1 aceptado)" $BCQA -q
  # 3 · NEGATIVO · sin MOTIVO no vale: el fallo sigue contando
  conf "$H" "" "" sin-motivo
  espera "sin MOTIVO · NO vale, sigue contando"         FALLO    MED-07 $BCQA -q
  texto "y dice por que no vale"                        SI "faltan campos obligatorios: MOTIVO" $BCQA -q
  # 4 · NEGATIVO · huella cambiada: se acepto OTRO hallazgo, no este
  conf "${H}-Y-UN-PROVEEDOR-MAS"
  espera "hallazgo CAMBIADO · vuelve a contar"          FALLO    MED-07 $BCQA -q
  # 5 · NEGATIVO · caducada
  conf "$H" "2026-03-01" "2026-05-30"
  espera "aceptacion CADUCADA · vuelve a contar"        FALLO    MED-07 $BCQA -q
  texto "y lo dice con su fecha"                        SI "CADUCADA el 2026-05-30" $BCQA -q
  # 6 · NEGATIVO · el tope duro de 180 dias se RECHAZA entero, no se recorta
  conf "$H" "2026-08-11" "2099-01-01"
  espera "HASTA fuera del tope · vuelve a contar"       FALLO    MED-07 $BCQA -q
  # 7 · NEGATIVO · lo que no se puede aceptar NUNCA. Se prueba con MED-08 en el
  #     MISMO fichero que una entrada legitima: la lista es quirurgica, no un
  #     apagon. Si esta prueba se cae, el gate ha dejado de proteger de nada.
  { conf "$H"
    echo ""
    echo "[ACEPTADO]"
    echo "CHECK:    MED-08"
    echo "HALLAZGO: DONDE=https://site-d.example/politica-cookies"
    echo "MOTIVO:   El cliente dice que su abogado la esta revisando."
    echo "ACEPTA:   Manuel Climent"
    echo "FECHA:    2026-08-11"
  } >> "$RA/_deploy/aceptado.conf"
  espera "PROHIBIDO (politica en borrador) · no se puede" FALLO  MED-08 $BCQA -q
  espera "y la entrada legitima del mismo fichero SI"     ACEPTADO MED-07 $BCQA -q
  texto "y dice que no es aceptable, no que falte algo"   SI "NO ES ACEPTABLE" $BCQA -q

  # 8 · el recibo lo lleva dentro, bajo el SELLO
  conf "$H"
  RAC="$CACHE/recibo-aceptado"
  perl $QA https://site-d.example/ --repo "$RA" --solo medicion --recibo "$RAC" --cache "$CACHE" >/dev/null 2>&1
  if grep -q '^ACEPTADO: 1' "$RAC" 2>/dev/null && grep -q '^ACEPTADO-001-HUELLA: ' "$RAC" 2>/dev/null; then
    printf '  OK    %-46s %s\n' "el recibo lleva el aceptado y su huella" "$(grep -m1 '^ACEPTADO-001:' "$RAC" | cut -c1-46)"; ok=$((ok+1))
  else
    printf '  MAL   %-46s el recibo no lo lleva\n' "el recibo lleva el aceptado y su huella"; ko=$((ko+1))
  fi
  # y editarlo a mano rompe el sello: la fecha de caducidad no se estira
  perl -i -pe 's/^(ACEPTADO-001: MED-07 \| hasta )\d{4}/${1}2099/' "$RAC"
  if perl ../receipt.pl --verificar --repo "$RA" --recibo "$RAC" 2>&1 | grep -q 'el SELLO no cuadra'; then
    printf '  OK    %-46s estirar la caducidad rompe el sello\n' "el aceptado va BAJO el sello"; ok=$((ok+1))
  else
    printf '  MAL   %-46s se pudo estirar la caducidad a mano\n' "el aceptado va BAJO el sello"; ko=$((ko+1))
  fi
  rm -rf "$RA"
}

echo
echo "== HUELLA sobre la evidencia COMPLETA (11-ago-2026) · el agujero cerrado"
#  🔴 POR QUE EXISTE ESTE BLOQUE. La huella se calculaba sobre lo que se
#     IMPRIME, y varios checks imprimen una lista TRUNCADA. Medido en site-d
#     con A11Y-08 (25 paginas con saltos, 4 en pantalla):
#       defecto nuevo DENTRO de las 4 visibles -> volvia a contar
#       defecto nuevo FUERA de las 4           -> SEGUIA SILENCIADO
#     Huella identica byte a byte en el segundo caso. Fallaba hacia el lado
#     INSEGURO, que es el unico que un silenciador no se puede permitir.
#  ⚠️ Los tres casos son NEGATIVOS o de CONTROL a proposito: que acepte es lo
#     facil; lo que hay que fijar es que NO acepte de mas y que no rompa una
#     aceptacion buena.
{
  # 🔴 19-ago-2026 · ESTE BLOQUE MEDIA EL REPO VIVO DE site-d, Y CADUCO EL DIA
  #    QUE SE ARREGLO ESA WEB. Los saltos de titular se corrigieron esa manana,
  #    asi que A11Y-08 dejo de fallar, y con el se cayeron los dos primeros
  #    casos: no habia defecto que aceptar. Ademas el «cubre 25» estaba ESCRITO
  #    A MANO y el sitio paso de 25 a 42 paginas.
  #    Es la trampa de `fixtures-frozen-site`, otra vez: *un control positivo
  #    anclado a una web VIVA caduca el dia que se arregla esa web*.
  #    Ahora el especimen es SINTETICO (`fixtures-fingerprint/`, 9 paginas, 7 con
  #    salto h1->h3 a proposito) y no depende de ninguna web: ni de que este
  #    rota, ni de que siga existiendo. Y el numero de la huella se DERIVA de la
  #    propia salida en vez de escribirse, que es lo que lo hizo caducar.
  RH="$CACHE/repo-huella"; rm -rf "$RH"; mkdir -p "$RH/_deploy"
  ( cd "fixtures-fingerprint" 2>/dev/null && tar cf - . ) | ( cd "$RH" && tar xf - ) 2>/dev/null
  if [ ! -f "$RH/p8/index.html" ]; then
    printf '  MAL   %-46s no esta fixtures-fingerprint\n' "huella completa: preparar arbol"; ko=$((ko+1))
  else
    HQA="perl $QA https://ejemplo.test/ --repo $RH --candidato --solo a11y --sin-recibo -q"
    # La huella se saca ACOTADA AL BLOQUE de A11Y-08: un `grep -m1 HUELLA` coge
    # la del primer FALLO del informe y la prueba pasaria sin probar.
    hue() { $HQA 2>&1 | awk '/\[[A-Z ]+\][ \t]+A11Y-08 /{f=1} f && /HUELLA /{sub(/^[ \t]*HUELLA /,"");print;exit}'; }
    H8="$(hue)"
    { echo "[ACEPTADO]"; echo "CHECK:    A11Y-08"; echo "HALLAZGO: $H8"
      echo "MOTIVO:   Prueba."; echo "ACEPTA:   Manuel Climent"
      echo "FECHA:    $(date +%Y-%m-%d)"; } > "$RH/_deploy/aceptado.conf"
    # 1 · la huella dice CUANTO cubre, no solo lo que cabe en pantalla.
    #     El numero se CUENTA del fixture: paginas con <h3> tras el <h1>. Si
    #     alguien anade una pagina al fixture, la prueba sigue valiendo sola.
    ESPERADAS=$(grep -rl '<h3>' "$RH" --include='index.html' | wc -l | tr -d ' ')
    texto "la huella declara su alcance completo"        SI "ALCANCE la huella cubre $ESPERADAS" $HQA
    # 2 · POSITIVO de control: recien copiada, casa
    espera "huella completa · la aceptacion casa"        ACEPTADO A11Y-08 $HQA
    # 3 · 🔴 EL CASO QUE DECIDE · defecto nuevo en una pagina MEDIDA pero que NO
    #     sale impresa. Antes del arreglo esto seguia ACEPTADO. p8 es la pagina
    #     SANA del fixture: al romperla, la huella pasa de 7 a 8.
    perl -i -pe 's|<h2>Subtitulo correcto</h2>|<h6>Subtitulo roto</h6>|' "$RH/p8/index.html"
    espera "defecto FUERA de lo impreso · vuelve a contar" FALLO A11Y-08 $HQA
    # 4 · y la huella ha cambiado (es lo que hace que vuelva a contar)
    H8B="$(hue)"
    if [ "$H8" != "$H8B" ]; then
      printf '  OK    %-46s la huella se mueve con la evidencia\n' "huella != tras el defecto nuevo"; ok=$((ok+1))
    else
      printf '  MAL   %-46s huella IDENTICA con un defecto nuevo dentro\n' "huella != tras el defecto nuevo"; ko=$((ko+1))
    fi
    # 5 · DETERMINISMO · dos corridas del mismo comando, la misma huella. Sin
    #     esto, una aceptacion VALIDA deja de casar sola y alguien apaga el fichero.
    if [ "$(hue)" = "$(hue)" ]; then
      printf '  OK    %-46s dos corridas, la misma huella\n' "la huella es determinista"; ok=$((ok+1))
    else
      printf '  MAL   %-46s la huella baila entre corridas\n' "la huella es determinista"; ko=$((ko+1))
    fi
    rm -rf "$RH"
  fi

  # 6 · ALCANCE PARCIAL · RENDIMIENTO mide una MUESTRA (3 de 25). Su aceptacion
  #     NO puede presentarse como si cubriera el sitio entero: huella con EVP y
  #     el aviso en la cara del informe.
  texto "muestra -> la huella sale marcada EVP"         SI "EVP=" \
        perl $QA https://site-d.example/ --solo rendimiento --sin-recibo -q --cache "$CACHE"
  texto "y el informe dice que la aceptacion es PARCIAL" SI "PARCIAL MUESTRA: se han mirado" \
        perl $QA https://site-d.example/ --solo rendimiento --sin-recibo -q --cache "$CACHE"
}

echo
echo "== SEO-14 · «no tiene contenido» NO es «es corta» (11-ago-2026)"
# 🔴 EL FALLO QUE ESTA SECCION CIERRA. SEO-14 disparaba con
#      length($txt) < 200 || @h1 == 0
#    que no mide su propio titulo: mide si la pagina es CORTA. Medido sobre el
#    HTML SERVIDO, los dos lados del corte, los dos reales:
#      site-a /merci        173 car., 1 h1, sin marcador ..... gracias, LEGITIMA
#      site-b loja.html    0 car., 0 h1, class="skeleton" . la tienda, DEFECTO
#    Entre 0 y 173 no hay ninguna pagina: el corte es un abismo, no un umbral
#    que haya que afinar.
#
# 🔴 LA SENAL NO ES EL noindex. La tienda de site-b esta ENTERA en noindex a
#    proposito; eximir por noindex borraba justo el defecto que hay que ver (se
#    intento el 11-ago y la bateria lo cazo: 167 -> 164). Tampoco vale eximir
#    por TIPO de pagina: eso se rodea renombrando el fichero. La senal es
#    POSITIVA: la region servida esta VACIA **y** el HTML ensena quien la va a
#    rellenar (marcador de carga, o contenedor vacio que nombra su guion).
FSEO14="fixtures-seo14"
BCU="https://site-d.example/"

# --- el caso real que bloqueaba el despliegue de site-a ---
espera "SEO-14 · site-a /merci: corta y COMPLETA, pasa"   PASA  SEO-14 \
       perl $QA https://site-a.example/ --solo seo --gracias /merci --sin-recibo --cache "$KCACHE"

# --- fixtures: los dos lados, aislados de la red ---
espera "SEO-14 · pagina corta legitima (132 car., 1 h1)" PASA  SEO-14 \
       perl $QA $BCU --repo "$FSEO14/corta-legitima" --candidato --una-sola --solo seo --sin-recibo
espera "SEO-14 · region VACIA + esqueleto: FALLA"        FALLO SEO-14 \
       perl $QA $BCU --repo "$FSEO14/esqueleto" --candidato --una-sola --solo seo --sin-recibo

# 🔴 EL RODEO · engordar el contorno del esqueleto con una miga y un parrafo
#    pasa de los 40 caracteres. Si esto sale PASA, el arreglo se burla con
#    relleno y hemos vuelto a medir longitud por otra puerta.
espera "SEO-14 · esqueleto DISFRAZADO de pagina: FALLA"  FALLO SEO-14 \
       perl $QA $BCU --repo "$FSEO14/esqueleto-disfrazado" --candidato --una-sola --solo seo --sin-recibo

# 🔴 LA FRONTERA · usar JS no es el defecto. Mismo marcador de carga, pero la
#    pagina SI viene servida (es la forma de la home de site-b, con #catGrid).
#    Sin este caso el arreglo seria «prohibido usar JS», que es otra cosa.
espera "SEO-14 · esqueleto pero la pagina SI se sirve"   PASA  SEO-14 \
       perl $QA $BCU --repo "$FSEO14/esqueleto-con-pagina" --candidato --una-sola --solo seo --sin-recibo

# --- la acusacion tiene que NOMBRAR la senal, no soltar un numero ---
#     Si el mensaje vuelve a ser «N caracteres» a secas, el check ha vuelto a
#     medir longitud aunque el veredicto salga igual.
texto  "SEO-14 · la acusacion NOMBRA la senal"          SI "marcador de carga" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "SEO-14 · y dice que la region esta VACIA"       SI "region de contenido servida esta VACIA" \
       perl $QA https://shop.site-b.example/ --solo seo --cache "$CACHE"

echo
echo "== EL TECHO DE --max-urls SE DECLARA · 11-ago-2026"
# 🔴 EL DEFECTO MEDIDO: site-d.example declara 40 URLs en su sitemap, el
#    tope por defecto mide 25, y A11Y-08 imprimia «DATO 25 de 25 paginas». «25
#    de 25» se lee como «todas». Las 15 que faltaban no aparecian en la linea
#    del check, y una aceptacion firmada sobre ese hallazgo se leia como una
#    decision sobre el sitio entero cubriendo el 62%.
texto  "TECHO · el bloque ALCANCE dice PARCIAL"          SI "· PARCIAL" \
       perl $QA https://site-d.example --solo a11y --cache "$CACHE"
texto  "TECHO · y con el denominador del SITIO"          SI "25 de 40 del sitio" \
       perl $QA https://site-d.example --solo a11y --cache "$CACHE"
texto  "TECHO · nombra el tope que recorto"              SI "tope --max-urls 25" \
       perl $QA https://site-d.example --solo a11y --cache "$CACHE"
# La huella de un check recortado tiene que llevar EVP (no EV): es lo que impide
# que una aceptacion tomada sobre 25 de 40 se presente como si cubriera 40.
texto  "TECHO · la huella de A11Y-08 lleva EVP, no EV"   SI "EVP=" \
       perl $QA https://site-d.example --solo a11y --cache "$CACHE"
# 🔴 LA FRONTERA · un sitio que se mide ENTERO no puede salir PARCIAL. Sin este
#    caso, «marcarlo todo PARCIAL siempre» pasaria por arreglo, y entonces la
#    palabra dejaria de significar nada —que es como muere un aviso—.
texto  "TECHO · un sitio medido ENTERO dice TODAS"       SI "· TODAS" \
       perl $QA https://site-a.example --solo a11y --cache "$KCACHE"
texto  "TECHO · y ese NO declara recorte"                NO "TECHO: se han mirado" \
       perl $QA https://site-a.example --solo a11y --cache "$KCACHE"

echo
echo "== COLISION DE CACHE CON crawl-links.pl · 11-ago-2026"
# 🔴 EL DEFECTO: los dos cachean con la MISMA clave -md5(url)- en el MISMO
#    directorio, y `08-qa-final.md` mandaba /tmp/cache a los dos. El `.meta` de
#    crawl va por | con 4 campos; el de aqui, por \t con 5.
#    Leyendo el suyo, `split /\t/` devuelve UN campo. Y ojo con lo que se creia:
#    NO es que $code deje de ser un numero -"200|https://..." numifia a 200 y
#    pasa todos los `code == 200`-. Lo que se pierde es el RESTO: wire, ctype y
#    eff salen undef, y el `.hdr` ni existe porque crawl no lo escribe.
#    MEDIDO en site-a.example, misma web y mismo binario, cambiando solo la
#    cache: limpia -> REN-08 PASA (html=br js=br css=br); de crawl -> REN-08
#    FALLO «texto servido SIN comprimir». Un FALSO ROJO que bloquea un
#    despliegue legitimo. Con otros checks el signo se invierte; lo comun es que
#    el numero sale de una pagina que qa-maestro nunca descargo.
#    ⚠️ La RAIZ no colisiona (crawl la cachea con barra, aqui se normaliza sin
#       ella): chocan las SUBPAGINAS. Con --una-sola no se ve nada.
#    El arreglo es VALIDAR AL LEER (`_meta_qam`), no cambiar la clave -- el
#    prefijo invalida las caches pre-pobladas y tumbo esta bateria de 180 a 170.
COL="$CACHE-colision"; rm -rf "$COL"; mkdir -p "$COL"
# Puerto muerto: si la semilla NO se acepta, la re-descarga falla al instante
# (connection refused) y la prueba sigue sin tocar la red.
COLURL="http://127.0.0.1:1/"
COLK="$(perl -MDigest::MD5=md5_hex -e 'print md5_hex($ARGV[0])' "$COLURL")"
printf '<!doctype html><html lang="es"><head><title>Semilla</title></head><body><main><h1>Semilla</h1></main></body></html>' > "$COL/$COLK.body"
# (a) meta AJENO -> MISS -> la home no se puede leer -> la lente entera es
#     NO VERIFICADO. Antes se tragaba la semilla y seguia midiendo tan tranquilo.
printf '200|%s|0|text/html; charset=utf-8' "$COLURL" > "$COL/$COLK.meta"
espera "cache AJENA (| de crawl) NO vale como HIT"       NOVERIF SEO-00 \
       perl $QA "$COLURL" --solo seo --cache "$COL" --sin-recibo
# (b) meta PROPIO -> HIT. Sin este caso, «rechazarlo todo» pasaria por arreglo
#     y el gate se quedaria sin cache sin que nadie se entere.
printf '200\t118\ttext/html; charset=utf-8\t%s\t0.001' "$COLURL" > "$COL/$COLK.meta"
espera "cache PROPIA (\\t de qa-maestro) SIGUE valiendo"  AUSENTE SEO-00 \
       perl $QA "$COLURL" --solo seo --cache "$COL" --sin-recibo

echo
echo "== MED-05 · EL VOCABULARIO DEL GATE NO ES UN HUERFANO · 11-ago-2026"
# 🔴 `data-sec` y `data-tipo` no los lee el JS del sitio: los lee el GATE, y
#    `09 §1` los EXIGE. climentmedia salia FALLO MED-05 por el unico `data-sec`
#    que tenia: una lente pedia el atributo y otra acusaba de emitirlo, en la
#    misma corrida. La exencion es por nombre exacto y solo para esos dos.
espera "MED-05 · data-sec no cuenta como huerfano"     PASA  MED-05 \
       perl $QA https://climentmedia.com --repo "$REPOS/climentmedia-website" --candidato --una-sola --solo medicion --sin-recibo
# 🔴 EL CONTROL NEGATIVO, y es el que impide que esto sea un apagon: un
#    atributo emitido y sin lector sigue saltando. Antes este caso apuntaba a
#    site-d; se cambio al fixture el 11-ago porque su defecto ESTA ARREGLADO
#    (script.js:203 lo lee) y el rojo venia del `_migrate/` del cliente.
espera "MED-05 · un huerfano de verdad SIGUE cazandose" FALLO MED-05 \
       perl $QA https://climentmedia.com --repo fixtures-med05/huerfano --candidato --una-sola --solo medicion --sin-recibo

echo
echo "== LA PAGINA DECLARA SU TIPO (data-tipo) · 11-ago-2026"
# 🔴 EL DEFECTO: el tipo se INFERIA de la ruta y no habia forma de declararlo
#    salvo `--tipo`, que aplica a TODAS las paginas de la corrida. climentmedia
#    .com/agents es un INDICE y se auditaba como pagina de SERVICIO —se le
#    exigian oferta, calificacion, proceso y objeciones— porque `agents` no
#    estaba en la lista de hubs del gate. No se arreglo anadiendo `agents` a esa
#    lista: la siguiente web tendra /tools/ o /soluciones/ y volveriamos aqui.
#    Una lista de nombres mide MI hipotesis sobre como se llaman las cosas.
# 🔴 EL CONTROL QUE IMPORTA: el fixture «declarado» esta en la RAIZ, que la ruta
#    inferiria como «home». Si sale `hub`, la declaracion ha ganado de verdad y
#    no es que coincidiera con la inferencia.
texto  "data-tipo · lo declarado gana a la ruta"      SI "tipos: hub x1" \
       perl $QA https://climentmedia.com --repo fixtures-type/declarado --candidato --una-sola --solo estructura --sin-recibo
espera "data-tipo · y con su anatomia de hub, PASA"   PASA EST-02c \
       perl $QA https://climentmedia.com --repo fixtures-type/declarado --candidato --una-sola --solo estructura --sin-recibo
# 🔴 LA FRONTERA · un valor inventado no se acepta en silencio. Si se aceptara,
#    cualquiera esquiva la anatomia que le moleste escribiendo una palabra nueva.
espera "data-tipo · un valor inventado AVISA"         AVISO EST-02d \
       perl $QA https://climentmedia.com --repo fixtures-type/basura --candidato --una-sola --solo estructura --sin-recibo
texto  "data-tipo · y vuelve a inferir por la ruta"   SI "tipos: home x1" \
       perl $QA https://climentmedia.com --repo fixtures-type/basura --candidato --una-sola --solo estructura --sin-recibo

echo
echo "== REN-05 · EL COCIENTE DE TERCEROS ES POR PAGINA · 11-ago-2026"
# 🔴 EL DEFECTO: el % se calculaba sobre la UNION de recursos de las paginas
#    muestreadas, asi que dependia de CUANTAS midieras. Medido en site-d con
#    los mismos 152 KB de etiquetas:
#        1 pagina -> 56% FALLO  ·  muestra 3 -> 46% PASA  ·  las 40 -> 8% PASA
#    Ampliar la cobertura APAGABA el fallo. Y estaba declarado en el codigo
#    desde el 10-ago: el aviso era honesto, pero **el `if` no lee el DATO**.
#    Ahora manda el cociente DENTRO de la peor pagina, que no se mueve al medir
#    mas. Este check no tenia NI UN CASO en esta bateria hasta hoy.
espera "REN-05 · bc: terceros al 93% de una pagina"      FALLO REN-05 \
       perl $QA https://site-d.example/ --solo rendimiento --cache "$CACHE" --max-urls 40
# 🔴 EL CONTROL DE REGRESION, y es el que justifica el arreglo entero: el mismo
#    sitio tiene que dar el MISMO veredicto mire una pagina, tres o cuarenta.
espera "REN-05 · mismo veredicto con 1 pagina"           FALLO REN-05 \
       perl $QA https://site-d.example/ --solo rendimiento --cache "$CACHE" --una-sola
espera "REN-05 · mismo veredicto con las 40"             FALLO REN-05 \
       perl $QA https://site-d.example/ --solo rendimiento --cache "$CACHE" --max-urls 40 --muestra 40
# Un porcentaje sin pagina no es accionable: hay que poder ir a mirarla.
texto  "REN-05 · NOMBRA la peor pagina"                  SI "politica-cookies" \
       perl $QA https://site-d.example/ --solo rendimiento --cache "$CACHE" --max-urls 40
# Segundo positivo con otro perfil: site-b carga su propio dominio principal.
espera "REN-05 · site-b: 89% en la home"                FALLO REN-05 \
       perl $QA https://shop.site-b.example/ --solo rendimiento --cache "$CACHE"
# 🔴 LA FRONTERA · una web sin terceros no puede salir acusada.
espera "REN-05 · cm no tiene terceros: PASA"             PASA  REN-05 \
       perl $QA https://climentmedia.com/ --solo rendimiento --cache "$CACHE"
# 🔴 Y el negativo del arreglo del arreglo: con el peor inicializado a 0 y `>`,
#    una web con CERO terceros no fijaba pagina y el DATO decia «sin pagina
#    medible» — que se lee «no he podido mirar» siendo «he mirado y es cero».
texto  "REN-05 · cero terceros dice 0%, no «no medible»" NO "sin pagina medible" \
       perl $QA https://climentmedia.com/ --solo rendimiento --cache "$CACHE"

echo
echo "== EST-10 · UN DESPLEGABLE CON MENOS DE 3 DESTINOS · 17-ago-2026"
# 🔴 EL DEFECTO: el 13-ago se sacaron 3 agentes del megapanel «Agents» de
#    climentmedia por la razon correcta —era una seleccion a mano de 3 de los 7,
#    y una lista a mano dentro de una plantilla envejece sin avisar—, y NO SE
#    MIRO con que se quedaba el panel: dos enlaces, uno el mismo del padre y el
#    otro ya presente en otro panel. Un chevron que promete un menu y entrega
#    eso es peor que no tenerlo. Lo vio Manuel abriendo la web; ningun gate lo
#    miraba, y R10 del gate de enlazado no vale: mide destinos del cromo sobre
#    el sitio entero, no el reparto DENTRO de cada panel.
espera "EST-10 · el desplegable pobre FALLA"          FALLO EST-10 \
       perl $QA https://climentmedia.com --repo fixtures-menu/pobre --candidato --una-sola --solo estructura --sin-recibo
# El numero importa tanto como el color: si acusara a los dos paneles, estaria
# dando por malo tambien el que reparte 4 destinos, y el arreglo seria otro.
texto  "EST-10 · y senala UNO de los dos paneles"     SI "1 de 2 paneles mirados" \
       perl $QA https://climentmedia.com --repo fixtures-menu/pobre --candidato --una-sola --solo estructura --sin-recibo
# El fixture «lleno» es el ARREGLO del «pobre», no otro fichero: el panel de 2
# colapsado a <a>. Ademas su panel bueno lleva DOS <div> anidados, que es lo que
# rompe un `.*?</div>` -- si el recorte se pasara de largo, contaria enlaces de
# fuera y el caso pasaria por la razon equivocada.
espera "EST-10 · colapsado a enlace, PASA"            PASA  EST-10 \
       perl $QA https://climentmedia.com --repo fixtures-menu/lleno --candidato --una-sola --solo estructura --sin-recibo
# 🔴 EL CONTROL NEGATIVO, y es el que decide si el check se puede encender:
#    `aria-controls` NO es exclusivo de los menus. Un acordeon de FAQ lo usa
#    igual y sus paneles tienen CERO enlaces con toda la razon. Sin acotar el
#    check a <header>/<nav>, este caso saldria en rojo y el gate acusaria a las
#    FAQ de las 5 webs -- un gate que da falsos positivos se acaba ignorando.
espera "EST-10 · un acordeon de FAQ NO es un menu"    PASA  EST-10 \
       perl $QA https://climentmedia.com --repo fixtures-menu/faq --candidato --una-sola --solo estructura --sin-recibo
texto  "EST-10 · y lo dice: ese sitio no tiene ninguno" SI "no tiene desplegables" \
       perl $QA https://climentmedia.com --repo fixtures-menu/faq --candidato --una-sola --solo estructura --sin-recibo

echo
echo "== EST-11 · VOCABULARIO NUESTRO DELANTE DEL VISITANTE · 14-ago-2026"
# 🔴 LOS CUATRO DEFECTOS SON REALES, no inventados para la prueba. Salieron
#    PUBLICADOS el 14-ago remaquetando site-c.example y mirando site-d:
#      <h1>hero</h1> · diez <h2>calificacion</h2> · una miga pintando el slug
#      crudo · y el campo cepo («No rellenar») a la vista en el formulario.
#    Los cuatro son HTML perfectamente valido: ni _audit.sh, ni el gate de
#    enlazado, ni las cinco lentes decian una palabra. Los vio Manuel mirando
#    la pantalla, que es justo lo que un gate viene a ahorrar.
espera "EST-11 · los defectos reales, cazados"          FALLO EST-11 \
       perl $QA https://climentmedia.com --repo fixtures-vocab/sucio --candidato --una-sola --solo estructura --sin-recibo
texto  "EST-11 · y los cuenta: son tres"                SI "3 caso(s)" \
       perl $QA https://climentmedia.com --repo fixtures-vocab/sucio --candidato --una-sola --solo estructura --sin-recibo
# El verde es el ARREGLO del rojo, no otro fichero: mismos roles declarados en
# data-sec -donde tienen que estar- y ninguno a la vista.
espera "EST-11 · arreglado, PASA"                      PASA  EST-11 \
       perl $QA https://climentmedia.com --repo fixtures-vocab/limpio --candidato --una-sola --solo estructura --sin-recibo
# 🔴 EL CONTROL QUE DECIDE SI ESTO SE PUEDE ENCENDER. El fixture limpio lleva
#    DOS cebos: la palabra «proceso» dentro de un parrafo -castellano normal- y
#    un enlace de prosa cuyo texto ES un slug con guiones, que es feo pero
#    legitimo. Si EST-11 acusa alguno, esta mirando la PROSA en vez de los
#    titulares, y entonces no se puede encender en ninguna web en español.
texto  "EST-11 · «proceso» en un parrafo NO es un rol" NO "es el nombre de un rol" \
       perl $QA https://climentmedia.com --repo fixtures-vocab/limpio --candidato --una-sola --solo estructura --sin-recibo
texto  "EST-11 · un slug en PROSA no es una miga"      NO "slug crudo" \
       perl $QA https://climentmedia.com --repo fixtures-vocab/limpio --candidato --una-sola --solo estructura --sin-recibo

echo
echo "== EST-12 · EL PIE (paso 2 de la revision) · 17-ago-2026"
# 🔴 EL PASO 2 no lo miraba NINGUN programa, y era uno de los cuatro asi -- los
#    mismos cuatro donde caen todos los defectos que ha encontrado Manuel.
espera "EST-12 · un pie completo PASA"                PASA  EST-12 \
       perl $QA https://climentmedia.com --repo fixtures-footer/bueno --candidato --una-sola --solo estructura --sin-recibo
# 🔴 EL QUE MAS VALE: el telefono del pie contra el del schema. Es el defecto de
#    las DOS LISTAS para el mismo hecho -el mismo que caza R6 con las migas-:
#    cuando el numero cambia se toca uno de los dos sitios, y desde ahi Google
#    publica un telefono y el visitante ve otro. Las dos cosas son HTML valido
#    por separado, y por eso no lo miraba nada.
espera "EST-12c · el telefono que no cuadra, FALLA"   FALLO EST-12c \
       perl $QA https://climentmedia.com --repo fixtures-footer/nap-discrepa --candidato --una-sola --solo estructura --sin-recibo
espera "EST-12c · y cuando cuadra, PASA"              PASA  EST-12c \
       perl $QA https://climentmedia.com --repo fixtures-footer/bueno --candidato --una-sola --solo estructura --sin-recibo
# El control de que no se inventa el defecto: sin `telephone` en el schema no
# hay dos listas que puedan discrepar, asi que no puede acusar a nadie.
espera "EST-12c · sin schema no acusa a nadie"        PASA  EST-12c \
       perl $QA https://climentmedia.com --repo fixtures-footer/sin-legales --candidato --una-sola --solo estructura --sin-recibo
espera "EST-12b · un solo enlace legal FALLA"         FALLO EST-12b \
       perl $QA https://climentmedia.com --repo fixtures-footer/sin-legales --candidato --una-sola --solo estructura --sin-recibo
# 🔴 EL MATIZ DEL BACKLINK, que es la parte que se pierde si no esta escrita:
#    el mismo enlace en el pie de las cinco webs es un patron que Google lee
#    como RED DE ENLACES. Lo que aguanta es un enlace de autoria con texto
#    distinto por sitio. Por eso la marca pelada de ancla es un FALLO.
espera "EST-12e · la marca pelada de ancla FALLA"     FALLO EST-12e \
       perl $QA https://climentmedia.com --repo fixtures-footer/sin-legales --candidato --una-sola --solo estructura --sin-recibo
espera "EST-12e · un ancla descriptiva no se acusa"   AUSENTE EST-12e \
       perl $QA https://climentmedia.com --repo fixtures-footer/bueno --candidato --una-sola --solo estructura --sin-recibo
# Y lo que un solo sitio NO puede saber, dicho en vez de aprobado: si esa ancla
# se repite en las otras cuatro webs. Hace falta mirar las cinco.
espera "EST-12f · lo que un solo sitio no puede saber" NOVERIF EST-12f \
       perl $QA https://climentmedia.com --repo fixtures-footer/bueno --candidato --una-sola --solo estructura --sin-recibo
# 🔴 EST-12d es AVISO y no FALLO, y el caso lo fija para que no se endurezca por
#    descuido: el 17-ago las CINCO webs estaban a cero enlaces de autoria, y un
#    check que se pone rojo en todas a la vez ensena a ignorar el gate. Cuando
#    las cuatro de cliente lo lleven, se sube a fallo -- y este caso se pondra
#    rojo, que es exactamente como tiene que enterarse quien lo cambie.
espera "EST-12d · sin credito de autoria, AVISA"      AVISO EST-12d \
       perl $QA https://climentmedia.com --repo fixtures-footer/sin-autoria --candidato --una-sola --solo estructura --sin-recibo
espera "EST-12d · con credito, ni avisa"              AUSENTE EST-12d \
       perl $QA https://climentmedia.com --repo fixtures-footer/bueno --candidato --una-sola --solo estructura --sin-recibo

echo
echo "== LA LENTE SEO, PAGINA A PAGINA · 17-ago-2026"
# Cuatro checks que no tenian caso y que son los defectos mas comunes de una
# pagina escrita a mano sin plantilla. Van juntos en el mismo fixture a
# proposito: en la vida real tambien viajan juntos.
espera "SEO-03 · sin meta description, FALLA"         FALLO SEO-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-pobre --candidato --una-sola --solo seo --sin-recibo
espera "SEO-03 · con description, PASA"               PASA  SEO-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-bueno --candidato --una-sola --solo seo --sin-recibo
# La longitud avisa y no bloquea: una description corta desaprovecha espacio,
# pero no rompe nada. Es el aviso que sale hoy en 12 paginas de site-d.
espera "SEO-03b · una description de 11 caracteres AVISA" AVISO SEO-03b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/desc-corta --candidato --una-sola --solo seo --sin-recibo
espera "SEO-03b · una dentro de rango no avisa"       AUSENTE SEO-03b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-bueno --candidato --una-sola --solo seo --sin-recibo
# 🔴 SEO-01 medía el title EN CRUDO. La portada de climentmedia lleva `&amp;`
#    y `length` contaba CINCO caracteres donde el usuario ve UNO: 67 acusados,
#    63 reales. El aviso era del instrumento, y solo se ve cuando el title cae
#    en la frontera -- que es justo cuando el aviso importa. Los dos fixtures
#    llevan el MISMO check y solo cambia si el texto trae entidades.
espera "SEO-01 · 66 en crudo pero 62 visibles: en rango" PASA    SEO-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-title-entidad --candidato --una-sola --solo seo --sin-recibo
espera "SEO-01 · 79 visibles de verdad: SI avisa"       AVISO SEO-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-title-largo --candidato --una-sola --solo seo --sin-recibo
# 🔴 SEO-09b · el segundo h1 es de los que se cuelan maquetando una seccion
#    nueva: HTML valido, nadie lo ve, y el titular de la pagina deja de ser uno.
espera "SEO-09b · dos h1, FALLA"                      FALLO SEO-09b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-pobre --candidato --una-sola --solo seo --sin-recibo
espera "SEO-09b · con uno solo, no se acusa"          AUSENTE SEO-09b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-bueno --candidato --una-sola --solo seo --sin-recibo
espera "SEO-11 · sin JSON-LD, FALLA"                  FALLO SEO-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-pobre --candidato --una-sola --solo seo --sin-recibo
espera "SEO-11 · con JSON-LD, PASA"                   PASA  SEO-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-bueno --candidato --una-sola --solo seo --sin-recibo
espera "SEO-13 · sin BreadcrumbList, AVISA"           AVISO SEO-13 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-pobre --candidato --una-sola --solo seo --sin-recibo

echo
echo "== LA LENTE DE ACCESIBILIDAD · cinco defectos que son HTML valido"
# Ninguno de los cinco da error en ningun validador, y por eso viajan a
# produccion. Van en el mismo fixture porque en la vida real tambien van juntos:
# son lo que le pasa a una pagina que nadie ha recorrido con teclado.
espera "A11Y-05 · un SVG decorativo sin marcar, FALLA"  FALLO A11Y-05 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-pobre --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-05 · con aria-hidden, PASA"                PASA  A11Y-05 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-bueno --candidato --una-sola --solo accesibilidad --sin-recibo
# Un enlace que solo lleva un icono no tiene NADA que anunciar: el lector dice
# «enlace» y se acabo.
espera "A11Y-06 · un enlace solo-icono, FALLA"          FALLO A11Y-06 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-pobre --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-06 · con aria-label, PASA"                 PASA  A11Y-06 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-bueno --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-07 · dos <main>, FALLA"                    FALLO A11Y-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-pobre --candidato --una-sola --solo accesibilidad --sin-recibo
# 🔴 ESTE CASO ES EL QUE ENCONTRO UN FALLO DEL GATE. El fixture bueno tiene UN
#    solo <main>... y llevaba un comentario explicando el defecto, con la
#    palabra `<main>` dentro. El gate contaba ESE tambien y decia que habia dos.
#    Un barrido que no distingue codigo de prosa acusa a la documentacion de ser
#    el defecto que documenta. Arreglado quitando los comentarios antes de contar.
espera "A11Y-07 · uno solo PASA (aunque el comentario lo nombre)" PASA A11Y-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-bueno --candidato --una-sola --solo accesibilidad --sin-recibo
# A11Y-09 · sin autocomplete el movil no autorrellena, y un formulario que
# obliga a teclear el correo a mano se abandona.
espera "A11Y-09 · campos sin autocomplete, FALLA"       FALLO A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-pobre --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-09 · con autocomplete, PASA"               PASA  A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-bueno --candidato --una-sola --solo accesibilidad --sin-recibo
# 🔴 Y EL SEGUNDO FALLO DEL GATE QUE ENCONTRARON ESTOS CASOS: A11Y-11 buscaba
#    `honeypot|hp_|_gotcha|bot-field`, y el cepo que tenemos EN VIVO en
#    site-d.example se llama **`website`** -- el nombre clasico, elegido
#    precisamente porque parece un campo normal. El check no se disparaba nunca
#    sobre el unico formulario del parque que tiene cepo, y ese cepo estaba
#    VISIBLE en pantalla. Ahora reconoce los tres nombres clasicos y el
#    `tabindex=-1`, alineado con `gate-formularios.js` F3.
espera "A11Y-11 · un cepo alcanzable con teclado, AVISA" AVISO A11Y-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-pobre --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-11 · uno blindado, PASA"                   PASA  A11Y-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/a11y-bueno --candidato --una-sola --solo accesibilidad --sin-recibo

echo
echo "== LA LENTE DE RENDIMIENTO · lo que cuesta y no se ve"
# 🔴 REN-03 · el navegador no sabe cuanto hueco reservar hasta que descarga la
#    imagen, y el contenido SALTA cuando llega. En site-a eran **111 de 141
#    imagenes** sin dimensionar. Y la regla que salio de alli: las medidas se
#    LEEN del fichero, no se estiman -- una inventada desplaza igual, en otra
#    direccion.
espera "REN-03 · una <img> sin dimensiones, FALLA"    FALLO REN-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/ren-pobre --candidato --una-sola --solo rendimiento --sin-recibo
espera "REN-03 · con width y height, PASA"            PASA  REN-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/ren-bueno --candidato --una-sola --solo rendimiento --sin-recibo
# ⚠️ REN-10 mide RECURSOS QUE SE DESCARGAN, no etiquetas del HTML. La primera
#    version de este fixture declaraba el <script src="/vendor.js"> sin crear el
#    fichero, y el check decia «sin scripts bloqueantes» teniendo uno delante:
#    no estaba en la lista de recursos porque nunca se bajo. El fixture tiene
#    que traer el fichero, o el caso mide otra cosa.
espera "REN-10 · script sin defer en el <head>, AVISA" AVISO REN-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/ren-pobre --candidato --una-sola --solo rendimiento --sin-recibo
espera "REN-10 · con defer, PASA"                     PASA  REN-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/ren-bueno --candidato --una-sola --solo rendimiento --sin-recibo

echo
echo "== SEO-08 · UNA SOLA og:image PARA TODO EL SITIO · 17-ago-2026"
# 🔴 EL DEFECTO REAL: el `og:image` del Yoast de site-c apuntaba a /wp-content/,
#    que en nuestro arbol no existe, y **23 de 30 paginas se compartian sin
#    imagen**. En un negocio local que capta por WhatsApp, una vista previa sin
#    imagen es un rectangulo gris en el unico canal de recomendacion que tiene.
#    El check pide >=5 paginas a proposito: en un sitio de 3 compartir la misma
#    imagen es razonable, y acusarlo seria un falso positivo.
espera "SEO-08 · las 5 con la misma imagen, FALLA"    FALLO SEO-08 \
       perl $QA https://climentmedia.com --repo fixtures-seo08/ogimg-una --candidato --solo seo --sin-recibo --max-urls 10
espera "SEO-08 · una por pagina, PASA"                PASA  SEO-08 \
       perl $QA https://climentmedia.com --repo fixtures-seo08/ogimg-varias --candidato --solo seo --sin-recibo --max-urls 10

echo

echo
echo "== LA LENTE DE MEDICION · lo que decide si el sitio cumple y si mide"
# 🔴 MED-02 · EL ORDEN NO ES NEGOCIABLE. El `consent default` con todo en denied
#    va ANTES de que cargue GTM. Al reves, el contenedor pone cookies antes de
#    que nadie haya aceptado nada, **el banner se ve igual de bien** y el sitio
#    esta en infraccion. No se detecta mirando la pagina: hay que mirar el ORDEN.
espera "MED-02 · consent DESPUES del contenedor, FALLA"  FALLO MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-pobre --candidato --una-sola --solo medicion --sin-recibo
espera "MED-02 · consent antes, PASA"                    PASA  MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-bueno --candidato --una-sola --solo medicion --sin-recibo
# 🔴 MED-09 · el plazo de conservacion. En site-a, `_leads/*.jsonl` guarda nombre,
#    telefono, email, IP y texto libre -que en una web de fisioterapia puede ser
#    dato de salud- sin plazo escrito y sin purga.
espera "MED-09 · sin plazo de conservacion, FALLA"       FALLO MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-pobre --candidato --una-sola --solo medicion --sin-recibo
espera "MED-09 · con «durante 12 meses», PASA"           PASA  MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-bueno --candidato --una-sola --solo medicion --sin-recibo
# 🔴 21-ago-2026 · EL NUMERO EN LETRA. El patron exigia cifras, asi que la
#    politica de site-a diciendo «conservees DEUX MOIS ... puis supprimees
#    automatiquement» salia FALLO teniendo el plazo escrito Y un cron que lo
#    cumple. El texto legal en frances y espanol escribe en letra los numeros
#    pequenos: exigir cifras medi­a el estilo, no el hecho. El fixture es
#    med-bueno con «12» cambiado por «dos», y nada mas: si algun dia vuelve a
#    salir FALLO, es que alguien ha retocado el patron sin mirar esto.
espera "MED-09 · el plazo EN LETRA («dos meses»), PASA"  PASA  MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-en-letra --candidato --una-sola --solo medicion --sin-recibo
# 🔴 Y ESTE ES EL CASO REAL, con la frase EXACTA de site-a.example en frances.
#    El de arriba no bastaba: estaba en espanol y decia «se conservan DURANTE dos
#    meses», asi que disparaba por `durante` y nunca ejercito la palabra
#    `conserv`. La frase francesa -«sont conservees deux mois a compter de leur
#    reception»- no lleva `durante` ni `pendant`, y `conserva\w*` no casaba
#    porque «conservees» tiene una vocal acentuada donde el patron pedia una `a`.
#    Resultado: el fixture en verde y la web REAL en FALLO. Un banco que prueba
#    la frase parecida y no la del cliente no prueba nada.
espera "MED-09 · la frase REAL en frances, PASA"        PASA  MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-frances --candidato --una-sola --solo medicion --sin-recibo
# 🔴 MED-11 · cada pulsacion de mas era un correo duplicado a la clinica y una
#    conversion de mas en su cuenta de Ads.
espera "MED-11 · sin guarda de doble envio, FALLA"       FALLO MED-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-pobre --candidato --una-sola --solo medicion --sin-recibo
espera "MED-11 · con el boton deshabilitado, PASA"       PASA  MED-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-bueno --candidato --una-sola --solo medicion --sin-recibo
# A11Y-10 y SEO-07 viven en el mismo fixture porque son del mismo formulario y
# de la misma cabecera: no hace falta un repo aparte para cada uno.
espera "A11Y-10 · sin region viva para los errores, FALLA" FALLO A11Y-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-pobre --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-10 · con role=alert, PASA"                  PASA  A11Y-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-bueno --candidato --una-sola --solo accesibilidad --sin-recibo
# 19-ago-2026 - LAS TRES DEL FORMULARIO PODIAN DESAPARECER DEL INFORME.
#   Sin --contacto, el gate sustituia la pagina de contacto por la portada y,
#   si esa no tenia <form>, A11Y-09/10/11 no se emitian: ni PASA, ni FALLO, ni
#   NO VERIFICADO. Hoy el formulario se busca entre las paginas leidas y, si no
#   hay ninguno, se DICE. Estos tres casos son los que impiden que vuelva.
espera "A11Y-10 - sin ningun <form>: NO VERIFICADO, no ausente" NOVERIF A11Y-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/sin-formulario --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-09 - sin ningun <form>: NO VERIFICADO, no ausente" NOVERIF A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/sin-formulario --candidato --una-sola --solo accesibilidad --sin-recibo
espera "A11Y-11 - sin ningun <form>: NO VERIFICADO, no ausente" NOVERIF A11Y-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/sin-formulario --candidato --una-sola --solo accesibilidad --sin-recibo

espera "SEO-07 · sin tarjeta de Twitter/X, AVISA"        AVISO SEO-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-pobre --candidato --una-sola --solo seo --sin-recibo
espera "SEO-07 · con twitter:card, PASA"                 PASA  SEO-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-bueno --candidato --una-sola --solo seo --sin-recibo

echo
echo "== ESTRUCTURA Y RENDIMIENTO · los cuatro que faltaban"
# 🔴 EST-02b es la HEURISTICA que sustituye a EST-02 mientras las webs no
#    declaren `data-sec`: cuenta secciones contra roles obligatorios. Es la que
#    senalo 12 paginas de site-c -6 mas de las que yo habia contado a mano- en
#    cuanto empezaron a declarar su tipo.
espera "EST-02b · 2 secciones para 7 roles, AVISA"       AVISO EST-02b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/est-02b --candidato --una-sola --solo estructura --sin-recibo
# EST-10b · un boton que anuncia un panel inexistente no abre nada, y con
# teclado deja el foco muerto. Nacio con EST-10 y no tenia caso.
espera "EST-10b · aria-controls a un id que no existe, FALLA" FALLO EST-10b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/est-10b --candidato --una-sola --solo estructura --sin-recibo
espera "EST-10b · y en un menu bien montado, no aparece" AUSENTE EST-10b \
       perl $QA https://climentmedia.com --repo fixtures-menu/lleno --candidato --una-sola --solo estructura --sin-recibo
# REN-12 · el mismo fichero con dos nombres se descarga DOS VECES. Se detecta
# por md5 del contenido, no por el nombre: es la unica forma de verlo.
espera "REN-12 · la misma imagen con dos nombres, FALLA" FALLO REN-12 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/ren-dup --candidato --una-sola --solo rendimiento --sin-recibo
# REN-06 · el identificador citado de mas suele ser el mismo contenedor pegado
# dos veces: mide el doble y nadie lo nota hasta que los numeros no cuadran.
espera "REN-06 · el mismo GTM citado 4 veces, AVISA"     AVISO REN-06 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/ren-dup --candidato --una-sola --solo rendimiento --sin-recibo

echo
echo "== 🔴 EL CONTROL DE LOS COMENTARIOS · 17-ago-2026"
# Una pagina CORRECTA cuyos comentarios nombran el vocabulario de cada check.
# Es lo que hace una plantilla bien documentada, y por eso el detonante es
# perverso: **cuanto mejor documentas, mas facil es enganar al gate**.
#
# Medido antes del arreglo, sobre esta misma pagina sin un solo defecto:
#     SEO-09b  «mas de un h1»        <- el comentario dice <h1>
#     A11Y-05  «SVG sin aria-hidden» <- el comentario dice <svg>
#     A11Y-08  «saltos de titular»   <- el comentario dice <h2> tras <h4>
#     REN-13   «recurso que no responde 200» <- un <script src> comentado
#     MED-02   «sin consent default» <- el comentario nombra un GTM
#     A11Y-07  «dos <main>»          <- ya arreglado antes, mismo origen
#
# El de MED-02 es el peligroso: en el fixture de al lado APROBABA una pagina que
# carga GTM sin consentimiento. Un falso positivo se descubre solo porque
# molesta; **un falso negativo sale verde**.
#
# Arreglado en el PUNTO DONDE CADA LENTE COGE EL CUERPO (`sin_com`), no check a
# check: la lista de checks crece y la de puntos de entrada no.
# OJO con la expectativa: SEO-09b solo imprime cuando falla -asi que lo
# correcto es AUSENTE-, y los otros cinco imprimen su linea de PASA. Mi primera
# version esperaba AUSENTE en los seis y salieron cinco MAL: el fallo era del
# caso, no del gate.
espera "comentarios · SEO-09b no se cree la prosa"  AUSENTE SEO-09b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo seo --sin-recibo
espera "comentarios · A11Y-05 no se cree la prosa"  PASA A11Y-05 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo accesibilidad --sin-recibo
espera "comentarios · A11Y-07 no se cree la prosa"  PASA A11Y-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo accesibilidad --sin-recibo
espera "comentarios · A11Y-08 no se cree la prosa"  PASA A11Y-08 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo accesibilidad --sin-recibo
espera "comentarios · REN-13 no se cree la prosa"   PASA REN-13 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo rendimiento --sin-recibo
espera "comentarios · MED-02 no se cree la prosa"   PASA MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo medicion --sin-recibo
echo "== EL FIXTURE DE KINE CUBRE TODO LO QUE SE LE PIDE · 11-ago-2026"
# 🔴 ESTE ES EL GATE SOBRE EL FIXTURE, y sin el lo demas no vale. Un fixture
#    INCOMPLETO no da error: qa-maestro simplemente sale a la red a por lo que
#    falte, y entonces la mitad de la medida vuelve a ser produccion sin que se
#    note -- exactamente el defecto que se vino a matar. Como la unica forma de
#    que aparezca un fichero nuevo en la cache es una DESCARGA, contar ficheros
#    antes y despues responde la pregunta de verdad: ¿ha salido a internet?
ls "$KCACHE" | sort > "$CACHE/kfix-despues.lst"
KFIX_N1="$(wc -l < "$CACHE/kfix-despues.lst")"
if [ "$KFIX_N0" -eq "$KFIX_N1" ]; then
  printf '  OK    %-46s %s entradas, 0 descargas\n' "fixture de site-a hermetico" "$KFIX_N0"; ok=$((ok+1))
else
  printf '  MAL   %-46s han bajado %d ficheros de la RED:\n' "fixture de site-a INCOMPLETO" "$((KFIX_N1-KFIX_N0))"; ko=$((ko+1))
  # Se imprime la URL, no el md5: un hash no dice que falta anadir al fixture.
  comm -13 "$CACHE/kfix-antes.lst" "$CACHE/kfix-despues.lst" | grep '\.meta$' | head -20 | while read -r f; do
    printf '          %s\n' "$(cut -f4 < "$KCACHE/$f")"
  done
fi

echo
echo "-----------------------------------------------------------------"
printf "  OK %d   ·   MAL %d\n" "$ok" "$ko"
[ "$ko" -eq 0 ] && echo "  El gate caza lo conocido, deja pasar lo bueno y no inventa." \
                || echo "  🔴 Hay casos MAL: el gate NO se usa hasta arreglarlos."
exit "$ko"
