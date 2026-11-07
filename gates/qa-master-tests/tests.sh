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
#  ⚠️ NINGUN CASO SALE A INTERNET (22-sep-2026). Los hosts `.example` los
#     contesta `fake-production.pl` con arboles SINTETICOS de `fixtures-sites/`,
#     y todo lo demas (terceros por HTTPS, webs vivas) se rechaza en el proxy.
#     No despliega.
#
#  🔑 Todas las rutas son RELATIVAS a este directorio (el `cd` de abajo). Un
#     trozo de este fichero copiado a otro sitio no mide nada: `../qa-master.pl`
#     deja de existir y todos los casos salen AUSENTE, con el gate viejo y con
#     el nuevo por igual. Medido el 21-sep-2026 (360 lineas: fuera de aqui 47
#     MAL, dentro de aqui 49 OK).
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"
QA="../qa-master.pl"
# Los repos de las webs que mide este banco son ARBOLES SINTETICOS suyos desde
# el 22-sep-2026. Antes $REPOS apuntaba a los checkouts de nuestras webs de
# cliente, que un repositorio publico no puede traer, y 13 casos no los podia
# correr nadie mas. Un caso que nombre un repo que no esta aqui sale NO MEDIDO
# con su nombre (ver `falta`).
REPOS="fixtures-repos"
# 🔴 LA CACHE ES DE ESTA CORRIDA Y NACE VACIA (22-sep-2026). Antes era una
#    carpeta fija de /tmp que sobrevivia entre corridas: con webs vivas hacia
#    de cache tibia, y el 11-ago costo diez falsos rojos (abajo). Hoy todo lo
#    que se mide sale de un fixture del repo, asi que una cache de ayer solo
#    puede devolver los bytes de ayer de un fixture cambiado hoy. Y con $$ en el
#    nombre, dos corridas a la vez no se pisan.
CACHE="${TMPDIR:-/tmp}/qa-master-tests-cache-$$"
rm -rf "$CACHE"; mkdir -p "$CACHE"
SRVPROD=""
ok=0; ko=0
# nm = cases NOT MEASURED · nmb = hand-written blocks NOT MEASURED. The per-
# reason counters can add up to more than nm: one case can lack two things.
nm=0; nmb=0; nm_repo=0; nm_anon=0; nm_https=0; nm_vivo=0; nm_lista=0; nm_prod=0

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
#    Se congelo en fixtures-frozen-site/: la cache exacta que esta bateria
#    leia el 11-ago-2026, trio a trio (.meta/.body/.hdr).
#    🔴 Y NO SE PUDO PUBLICAR: era la captura byte a byte de la web de un
#    cliente, y publicar la web de otro para que pase una prueba no es un trato
#    que haga este repositorio. Desde entonces esos 18 casos salian NO MEDIDO
#    en todas partes. Y las otras webs «vivas» (bc, site-c, site-b, site-e) se
#    anonimizaron a `*.example`, que no resuelve nunca: otros 89 casos y un
#    bloque de 14 que tampoco podia correr nadie. Los 18 de climentmedia.com
#    EN VIVO si corrian, y varios ya habian caducado: la web se arreglo.
#
# 🔴 22-sep-2026 · LA SALIDA DE VERDAD: SITIOS SINTETICOS EN UNA PRODUCCION
#    LOCAL. `fixtures-sites/<host>/` es un arbol escrito para este banco que
#    reproduce, con contenido inventado, justo el defecto (o el acierto) que
#    cada caso comprueba. `fake-production.pl` lo sirve por HTTP con cabeceras
#    de produccion (estado, tipo, gzip, Cache-Control), y el banco le manda
#    todo el trafico por `http_proxy`: los casos conservan su nombre de host
#    (`site-d.example`) y miden en modo PRODUCCION, no candidato. Lo que no es
#    un `.example` servido por un fixture NO se alcanza: HTTPS se rechaza en el
#    proxy y un host desconocido recibe 502. El banco entero es hermetico, y
#    el ultimo bloque lo comprueba en el registro del propio servidor.
#    ⚠️ El contenedor de GTM se descargaba de googletagmanager.com por HTTPS,
#       y MED-03/07/08 viven dentro de «si se ha podido descargar». Esos casos
#       pasan el suyo con `--contenedor` (la costura que el gate tiene para
#       esto): `fixtures-sites/<host>/_gtm.js`, que el servidor no sirve nunca
#       (nada que empiece por `_`).

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
# 🔴 22-sep-2026 · EL CENTINELA SE ESCRIBIA DENTRO DEL REPO (fixtures-fingerprint/),
#    que comparten todas las corridas. Dos a la vez se pisaban: la segunda
#    sobrescribia el centinela de la primera, la primera leia el ajeno y daba su
#    servidor por caido -- y el `rm -f` de cualquiera borraba el del otro. Visto
#    con cinco corridas del banco a la vez. Ahora se sirve una COPIA de la
#    corrida, dentro de su cache: mismos ficheros, y el repo no se toca.
R404="$CACHE/raiz-404"
cp -r fixtures-fingerprint "$R404"
printf '%s\n' "$CENT404" > "$R404/_sentinel.txt"
perl "../receipt-tests/test-server.pl" "$R404" "$P404" >/dev/null 2>&1 &
SRV404=$!
trap 'kill $SRV404 $SRVPROD 2>/dev/null; rm -rf "$CACHE"' EXIT
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
rm -f "$R404/_sentinel.txt"
# ── LA PRODUCCION DE MENTIRA (22-sep-2026) ──────────────────────────────────
#    Mismo trato que los otros dos servidores de este banco: puerto libre
#    comprobado ANTES, y centinela DESPUES. Un puerto ocupado por otra sesion
#    contestaria con otra web y los casos pasarian por el motivo equivocado.
PPROD=$(( 30000 + ($$ % 20000) ))
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if (exec 3<>/dev/tcp/127.0.0.1/$PPROD) 2>/dev/null; then PPROD=$(( PPROD + 1 )); else break; fi
done
TOKPROD="produccion-$$-$(date +%s)"
perl fake-production.pl fixtures-sites "$PPROD" "$TOKPROD" "$CACHE/produccion.log" > "$CACHE/produccion.out" 2>&1 &
SRVPROD=$!
PROD_OK=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  # ⚠️ Nada de `--noproxy '*'` aqui: ANULA el -x, y la primera version de este
  #    centinela preguntaba por `centinela.example` a un DNS que no lo conoce.
  #    Medido: el servidor habia arrancado («listo») y el banco lo daba por caido.
  if [ "$(curl -s --max-time 2 -x "http://127.0.0.1:$PPROD" http://centinela.example/_centinela-produccion 2>/dev/null)" = "$TOKPROD" ]; then
    PROD_OK=1; break
  fi
  sleep 0.3
done
if [ "$PROD_OK" = 1 ]; then
  # 🔑 curl solo lee `http_proxy` en MINUSCULA (la mayuscula la ignora a
  #    proposito, por seguridad); `https_proxy` en las dos. Todo lo HTTPS acaba
  #    en un CONNECT que el servidor rechaza al instante: ningun tercero sale.
  export http_proxy="http://127.0.0.1:$PPROD" https_proxy="http://127.0.0.1:$PPROD" HTTPS_PROXY="http://127.0.0.1:$PPROD"
  export no_proxy="127.0.0.1,localhost" NO_PROXY="127.0.0.1,localhost"
  unset ALL_PROXY all_proxy
else
  printf '  MAL   %-46s no arranco en el puerto %s\n' "la produccion de mentira" "$PPROD"; ko=$((ko+1))
fi

#  🔴 LA HISTORIA DE LA SALIDA ANTICIPADA, que es de donde sale `falta`:
#     Hasta el 22-sep este banco dependia de un sitio congelado que no se
#     publica. Exit 3, not 2 and not 1: in this system 3 means I DID NOT MEASURE
#     IT, and `run-all.sh` prints it as NOT MEASURED. A 1 would send somebody
#     hunting a defect that does not exist, and a 0 would let a hole read as a
#     pass — which is the failure this whole repository is about.
#     🔴 1-sep-2026 · Y HASTA HOY ESTE ABANDONO SE LLEVABA POR DELANTE PRUEBAS
#     QUE NO NECESITAN LA FIXTURE. Salia aqui mismo con «OK 0 · MAL 0», asi que
#     en un checkout sin el sitio congelado —o sea, en CUALQUIERA menos el
#     nuestro— este banco no medía absolutamente nada, incluidas las que solo
#     usan sus propias carpetas de `fixtures-*`. «Existe un control» es la
#     version debil de «el control corre».
#     Ahora se ANOTA que falta y se sale mas abajo, despues de correr todo lo
#     que si se puede medir sin ella.
#     🔴 21-sep-2026 · «TODO LO QUE SI SE PUEDE MEDIR» ERAN 18 CASOS DE ~100.
#     La salida se puso en la linea 260 y todo lo de debajo se perdia con ella,
#     incluidas las secciones que solo usan `fixtures-*` —las cinco lentes,
#     EST-10/11/12, la puerta, la huella, la colision de cache—: CERO
#     referencias al sitio congelado y nunca corrian. Los dos casos de MED-09
#     del 21-sep solo se pudieron probar a mano por esto.
#     Y medido con la salida quitada, el sitio congelado no era la unica
#     dependencia: 132 MAL, de cuatro clases (el congelado, $REPOS, capturas de
#     hosts anonimizados y webs vivas), y ademas DIEZ casos en VERDE por el
#     motivo equivocado: un `texto ... NO` o un diff de dos ficheros vacios
#     sobre un gate que no ha medido nada pasan solos.
#     → Ya no hay salida anticipada. Cada caso se clasifica ANTES de correr,
#       con sus propios argumentos (`falta`), y lo que no se puede medir se
#       imprime con nombre y se cuenta. La lista de dependencias se DERIVA del
#       comando: un caso nuevo queda clasificado sin que nadie se acuerde.
#     🔴 22-sep-2026 · Y con los sitios sinteticos, esas clases dejan de ser
#       dependencias externas: un `.example` se mide si su fixture existe.

# ── LO QUE UN CASO NECESITA Y ESTE CHECKOUT NO TIENE ────────────────────────
# falta <argumentos del caso...>
#   Imprime lo que le falta al caso para poder medirse, o nada. Se DERIVA de
#   los argumentos del propio caso, no de en que seccion esta: las secciones
#   mezclan casos de muchas clases, y una lista escrita al lado envejece sola.
#   Las clases que existen desde el 22-sep-2026:
#     · un repo              · un argumento bajo $REPOS que no existe
#     · un sitio sintetico   · http://*.example sin --candidato ni --sin-red, y
#                              sin carpeta en fixtures-sites/: la produccion de
#                              mentira contestaria 502. Se DERIVA del disco.
#     · https a un .example  · la produccion de mentira no habla TLS: un caso asi
#                              es un caso mal escrito, y se dice con ese nombre
#     · una web viva         · cualquier otro host sin --candidato ni --sin-red.
#                              El banco no sale a internet NUNCA: se congela.
#     · la produccion        · no arranco: nada de lo servido por ella se mide
#   Con --candidato el sitio se sirve desde --repo en 127.0.0.1, asi que el host
#   de la URL no se descarga. Un `@lista` se lee: lleva URLs dentro.
MOT_REPO="a repository fixture under $REPOS/"
MOT_ANON="a site fixture under fixtures-sites/"
MOT_HTTPS="http, not https: the fake production does not speak TLS"
MOT_VIVO="a live site: this bench never goes online, freeze it under fixtures-sites/"
MOT_LISTA="a URL list its block did not write"
MOT_PROD="the fake production, which did not start"
falta() {
  local a f u h cand=0 sinred=0 urls="" m=""
  for a in "$@"; do
    case "$a" in --candidato) cand=1 ;; --sin-red) sinred=1 ;; esac
  done
  for a in "$@"; do
    case "$a" in "$REPOS"/*) [ -e "$a" ] || { m="$m + $MOT_REPO (${a#"$REPOS"/})"; break; } ;; esac
  done
  for a in "$@"; do
    case "$a" in
      http://*|https://*) urls="$urls $a" ;;
      @*) f="${a#@}"
          if [ -f "$f" ]; then urls="$urls $(grep -oE 'https?://[^[:space:]]+' "$f" | tr '\n' ' ')"
          else m="$m + $MOT_LISTA (${f##*/})"; fi ;;
    esac
  done
  if [ "$cand" = 0 ] && [ "$sinred" = 0 ]; then
    for u in $urls; do
      h="${u#*://}"; h="${h%%/*}"; h="${h%%:*}"
      case "$h" in
        127.0.0.1|localhost) ;;
        *.example)
          if   [ "$PROD_OK" != 1 ];      then m="$m + $MOT_PROD"; break
          elif [ "${u%%://*}" = https ]; then m="$m + $MOT_HTTPS ($h)"; break
          elif [ ! -d "fixtures-sites/$h" ]; then m="$m + $MOT_ANON ($h)"; break
          fi ;;
        *) m="$m + $MOT_VIVO ($h)"; break ;;
      esac
    done
  fi
  printf '%s' "${m# + }"
}

# sin_medir <etiqueta> <comando...>
#   Si al caso le falta algo, lo imprime como NO MEDIDO con el motivo, lo
#   cuenta y devuelve 0 (= no lo corras). Si no le falta nada, devuelve 1.
#   🔴 La clasificacion va ANTES de correr, nunca se deduce del resultado: un
#   `texto ... NO "<literal>"` sobre un gate que no ha medido nada sale VERDE
#   (medido el 21-sep: «no acusa al HTML del cliente (_migrate)» pasaba con
#   $REPOS sin definir y el host sin resolver). Leer AUSENTE como «no medido»
#   no lo veria, porque ahi no sale AUSENTE: sale OK.
sin_medir() {
  local eti="$1"; shift
  local m; m="$(falta "$@")"
  [ -z "$m" ] && return 1
  printf '  N/M   %-46s NOT MEASURED: needs %s\n' "$eti" "$m"; nm=$((nm+1))
  case "$m" in *"$MOT_REPO"*) nm_repo=$((nm_repo+1)) ;; esac
  case "$m" in *"$MOT_ANON"*) nm_anon=$((nm_anon+1)) ;; esac
  case "$m" in *"$MOT_HTTPS"*) nm_https=$((nm_https+1)) ;; esac
  case "$m" in *"$MOT_VIVO"*) nm_vivo=$((nm_vivo+1)) ;; esac
  case "$m" in *"$MOT_LISTA"*) nm_lista=$((nm_lista+1)) ;; esac
  case "$m" in *"$MOT_PROD"*) nm_prod=$((nm_prod+1)) ;; esac
  return 0
}

# mide_bloque <nombre> <argumentos de lo que el bloque mide...>
#   Lo mismo, para los bloques que comprueban a mano (su propio printf OK/MAL)
#   en vez de por `espera`/`texto`. Devuelve 0 si se puede medir; si no, UNA
#   linea por el bloque entero, y 1. Se cuentan BLOQUES, no casos: cuantos
#   casos lleva un bloque solo se sabe corriendolo, y un numero escrito a mano
#   al lado caducaria el dia que alguien le anada uno.
mide_bloque() {
  local nom="$1"; shift
  local m; m="$(falta "$@")"
  [ -z "$m" ] && return 0
  printf '  N/M   %-46s NOT MEASURED (block): needs %s\n' "$nom" "$m"; nmb=$((nmb+1))
  return 1
}

# espera <etiqueta> <ESTADO> <ID> <comando...>
espera() {
  local eti="$1" est="$2" id="$3"; shift 3
  sin_medir "$eti" "$@" && return 0
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
  sin_medir "$eti" "$@" && return 0
  local out; out="$("$@" 2>&1)"
  local hay=NO; printf '%s' "$out" | grep -qF -- "$lit" && hay=SI
  if [ "$hay" = "$quiero" ]; then
    printf '  OK    %-46s %s "%s"\n' "$eti" "$quiero" "$lit"; ok=$((ok+1))
  else
    printf '  MAL   %-46s esperaba %s "%s" y salio %s\n' "$eti" "$quiero" "$lit" "$hay"; ko=$((ko+1))
  fi
}

echo
echo "== METADATOS QUE SE CONTRADICEN ENTRE SI · SEO-02b / 05 / 05b · 1-sep-2026"
# 🔴 EL HUECO MEDIDO: habia CINCO comprobaciones de metadatos —largo del title,
#    titles duplicados, description ausente, largo de la description y
#    canonical— y ninguna miraba si las tres superficies HABLAN DE LO MISMO.
#    Una pagina podia llevar title perfecto de 58 caracteres, description
#    perfecta de 140 y un h1 unico, y decir cada uno una cosa distinta: pasaba
#    las cinco. El caso real esta en este repo: un sitio publico <h1>hero</h1>.
#    Y de duplicados solo se miraba el title; la description no la miraba nadie,
#    asimetria pura — medido el 1-sep, un sitio real tenia DOS descriptions
#    repetidas en CUATRO documentos, una de ellas la de otra pagina.
#
# Las cinco carpetas son la MISMA base con un fichero cambiado (`diff -rq` lo
# comprueba abajo). Sin eso, un rojo no dice si viene del defecto inyectado o
# de algo que se colo en la copia.
FSEO05="fixtures-seo05"
FU="https://fixture.test/"
QA5="--candidato --solo seo --sin-recibo"

espera "SEO-05 · base alineada: title y h1 pasan"      PASA  SEO-05 \
       perl $QA $FU --repo "$FSEO05/alineado" $QA5
espera "SEO-05 · base alineada: descriptions unicas"   PASA  SEO-02b \
       perl $QA $FU --repo "$FSEO05/alineado" $QA5
espera "SEO-05 · base alineada: description alineada"  PASA  SEO-05b \
       perl $QA $FU --repo "$FSEO05/alineado" $QA5

# 🔴 26-sep-2026 · LENTES Y TIPOS CON EL NOMBRE EN INGLES. `--solo measurement`
#    (la orden de paths/3 para la pagina legal) no casaba con ninguna lente
#    -empieza por «mea», no por «med»- y no corria nada, callado. `--tipo service`
#    no estaba en la tabla y la anatomia exigia cero roles. Los casos 2 y 4 son
#    los que el programa anterior daba al reves.
texto "--solo measurement no es una lente desconocida"  NO "Lente desconocida" \
      perl $QA $FU --repo "$FSEO05/alineado" --candidato --solo measurement --sin-recibo
texto "...y corre la lente: sale una comprobacion MED"  SI "MED-0" \
      perl $QA $FU --repo "$FSEO05/alineado" --candidato --solo measurement --sin-recibo
texto "una lente que no existe se nombra y sale"        SI "Lente desconocida" \
      perl $QA $FU --repo "$FSEO05/alineado" --candidato --solo diseno --sin-recibo
texto "--tipo service es servicio (alias ingles)"       NO "Tipo desconocido" \
      perl $QA $FU --repo "$FSEO05/alineado" $QA5 --tipo service
texto "un tipo que no esta en la tabla se nombra y sale" SI "Tipo desconocido" \
      perl $QA $FU --repo "$FSEO05/alineado" $QA5 --tipo servicioo

# 🔴 26-sep-2026 · SEO-15 NO PODIA SALTAR NUNCA. `!~ /Allow:/i` casaba dentro de
#    «Disallow:», asi que un robots.txt de staging con `Disallow: /` salia «robots.txt
#    correcto». No tenia ni un caso en este banco. El primero es el que el programa
#    anterior daba en verde; el segundo, el control de que no acusa a un robots abierto.
RB15="$(mktemp -d)"; cp -r "$FSEO05/alineado/." "$RB15/"
printf 'User-agent: *\nDisallow: /\n' > "$RB15/robots.txt"
espera "SEO-15 · robots.txt de staging (Disallow: /) FALLA" FALLO SEO-15 \
       perl $QA $FU --repo "$RB15" $QA5
printf 'User-agent: *\nAllow: /\n' > "$RB15/robots.txt"
espera "SEO-15 · robots.txt abierto PASA"                  PASA  SEO-15 \
       perl $QA $FU --repo "$RB15" $QA5
rm -rf "$RB15"

# --- el defecto documentado: el titular cayo en el nombre del rol ---
espera "SEO-05 · <h1>hero</h1> contra su title: AVISA"  AVISO SEO-05 \
       perl $QA $FU --repo "$FSEO05/h1-hero" $QA5

# 🔴 EL CASO QUE PRUEBA EL FILTRO DE CROMO, y sin el no esta probado: el h1
#    «Fixture Nora te escucha» comparte con su title las DOS palabras de marca
#    y ninguna mas. Si el gate no descontara el cromo —medido del propio sitio,
#    no escrito en una lista— esto saldria PASA y el check no serviria en
#    ninguna web con sufijo de marca en el title, o sea en casi ninguna.
espera "SEO-05 · comparte SOLO la marca: AVISA"        AVISO SEO-05 \
       perl $QA $FU --repo "$FSEO05/solo-marca" $QA5

# --- la description que habla de otra cosa ---
espera "SEO-05b · description ajena al title y al h1"  AVISO SEO-05b \
       perl $QA $FU --repo "$FSEO05/desc-ajena" $QA5
espera "SEO-05b · y eso NO ensucia el veredicto de 05" PASA  SEO-05 \
       perl $QA $FU --repo "$FSEO05/desc-ajena" $QA5

# --- el gemelo que faltaba de SEO-02 ---
espera "SEO-02b · description repetida en 2 docs"      FALLO SEO-02b \
       perl $QA $FU --repo "$FSEO05/desc-duplicada" $QA5
espera "SEO-02b · y el duplicado no dispara 05"        PASA  SEO-05 \
       perl $QA $FU --repo "$FSEO05/desc-duplicada" $QA5

# 🔴 EL TEXTO DE LA PAGINA SALE EN BYTES Y STDOUT YA CODIFICA. La primera
#    version imprimia «qué» como C3 83 C2 A9 —doble-codificado, que es UTF-8
#    VALIDO y por tanto no lo caza `iconv` ni da error—. La description que se
#    duplica lleva «sesión» a proposito para fijar el arreglo aqui.
texto  "SEO-02b · el acento sale SIN doblar"           SI "sesión inicial" \
       perl $QA $FU --repo "$FSEO05/desc-duplicada" $QA5
texto  "SEO-02b · y no aparece la forma doblada"       NO "sesiÃ³n" \
       perl $QA $FU --repo "$FSEO05/desc-duplicada" $QA5

# 🔑 El control que sostiene a los cinco de arriba: cada variante es la base
#    con UN fichero distinto. Si alguna vez difiere en dos, el rojo de esa
#    variante deja de significar lo que dice la etiqueta.
for _v in h1-hero solo-marca desc-ajena desc-duplicada; do
  _n="$(diff -rq "$FSEO05/alineado" "$FSEO05/$_v" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$_n" = "1" ]; then
    printf '  OK    %-46s %-8s -> 1 fichero\n' "SEO-05 · $_v difiere de la base en 1" "fixture"; ok=$((ok+1))
  else
    printf '  MAL   %-46s %-8s esperaba 1 fichero y son %s\n' "SEO-05 · $_v difiere de la base en 1" "fixture" "$_n"; ko=$((ko+1))
  fi
done

echo
echo "== MED-07 · UN TERCERO CARGADO DESDE EL JS PROPIO · 8-sep-2026"
# 🔴 8-sep-2026 · MED-07 MIRABA SOLO EL CONTENEDOR, Y ESA PREMISA ES FALSA.
#    Una web puede cargar un tercero desde su PROPIO JavaScript, y hay un motivo
#    bueno: el Consent Mode de Google no gobierna un pixel de Meta, asi que dentro
#    de GTM harian falta dos permisos en dos sitios que pueden divergir.
#    Antes del arreglo, sobre el fixture de abajo MED-07 listaba solo Google y
#    MED-07b acusaba a la politica de declarar un proveedor que el sitio no carga
#    — siendo la politica CIERTA. Un aviso falso ensena a ignorar los avisos.
#
#    🔑 EL CASO QUE VALE ES EL SEGUNDO. El primero (PASA MED-07) sale verde con el
#    arreglo y SIN el: sin el, MED-07 tambien pasa, solo que sin Meta en la lista.
#    Lo que discrimina es la AUSENCIA de MED-07b. Medido las dos veces con el mismo
#    fixture: con el arreglo, MED-07b no aparece y MED-07 lista "Google Ads ·
#    Google Analytics · Meta / Facebook"; con el arreglo QUITADO de una copia del
#    gate, MED-07b sale AVISO con DATO "Facebook/Meta".
espera "MED-07 · tercero cargado por el JS del sitio"    PASA  MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-tercero-en-js-propio --contenedor fixtures-lenses/contenedor-solo-google.js --candidato --una-sola --solo medicion --sin-recibo
espera "MED-07b · y por tanto NO lo acusa de fantasma"   AUSENTE MED-07b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-tercero-en-js-propio --contenedor fixtures-lenses/contenedor-solo-google.js --candidato --una-sola --solo medicion --sin-recibo
# 🔴 Y LA CARA CONTRARIA, para que ensanchar MED-07 no deje CIEGO a MED-07b: una
#    politica que nombra a Meta cuando no lo carga nadie —ni el contenedor ni el JS
#    propio— tiene que seguir saliendo en aviso. "Una politica que sobra tambien es
#    una politica falsa, y se audita igual."
espera "MED-07b · declarado y no cargado, sigue avisando" AVISO MED-07b \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-tercero-declarado-que-no-existe --contenedor fixtures-lenses/contenedor-solo-google.js --candidato --una-sola --solo medicion --sin-recibo

echo
echo "== MED-15 · DATOS PERSONALES HACIA LA MEDICION · 3-nov-2026"
# MED-03 cruza el NOMBRE del evento; MED-15 mira lo que LLEVA: la web (dataLayer.push,
# gtag event) y las variables que usa cada etiqueta del contenedor que no esta en pausa.
# 🔑 EL CASO QUE DISCRIMINA ES EL PRIMERO: `link:'tel:+32...'` no es una clave `tel`.
#    Con la clave leida tras cualquier caracter (y no solo tras `{` o `,`) sale FALLO
#    «la web manda tel»: medido el 3-nov con la regla cambiada en una copia del gate.
_M15="--candidato --una-sola --solo medicion --sin-recibo"
espera "MED-15 · un clic tel: no es un dato personal"   PASA  MED-15 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med15-tel --contenedor fixtures-lenses/med15-contenedor-limpio.js $_M15
espera "MED-15 · la web empuja el correo"               FALLO MED-15 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med15-email --contenedor fixtures-lenses/med15-contenedor-limpio.js $_M15
espera "MED-15 · una etiqueta manda form.email"         FALLO MED-15 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med15-tel --contenedor fixtures-lenses/med15-contenedor-pii.js $_M15
texto  "MED-15 · y dice cual y como que"                SI "manda la variable «form.email» como «user_email»" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med15-tel --contenedor fixtures-lenses/med15-contenedor-pii.js $_M15
espera "MED-15 · una etiqueta en pausa no manda nada"   PASA  MED-15 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med15-tel --contenedor fixtures-lenses/med15-contenedor-pausado.js $_M15
espera "MED-15 · datos de usuario automaticos avisan"   AVISO MED-15 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med15-tel --contenedor fixtures-lenses/med15-contenedor-auto.js $_M15
# Sin JSON legible en el contenedor no se dice PASA: solo se miro la mitad.
espera "MED-15 · contenedor sin JSON: aviso, no pasa"   AVISO MED-15 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med15-tel --contenedor fixtures-lenses/contenedor-solo-google.js $_M15

echo
echo "== MEDICION DE LA CASA · EL CONTENEDOR VIVE EN UN consent.js PROPIO · 26-sep-2026"
# 🔴 26-sep-2026 · LA LENTE BUSCABA EL CONTENEDOR SOLO EN EL HTML. Nuestras webs
#    cargan un consent.js propio que declara el Consent Mode v2 en `denied` e
#    inyecta gtm.js solo al aceptar; el id vive en ese fichero y en ninguna
#    pagina. Resultado: MED-01 «sin medicion ninguna» en cada recibo, y MED-02,
#    MED-03 y MED-07 sin correr nunca. Misma leccion que audit-vs-spec.pl el
#    mismo dia (trampa §85): un script PROPIO de la pagina es parte de la pagina.
#
#    VISTO EN ROJO PRIMERO, con el gate de antes sobre estos mismos fixtures:
#    OK 8 · MAL 18 de 26. El bueno daba AVISO MED-01 «sin medicion ninguna» y
#    MED-02/07 AUSENTES; los dos de orden en la pagina, FALLO pero por «sin
#    consent default» (no «DESPUES»), y el de orden dentro de consent.js,
#    AUSENTE; el marcador, «sin medicion ninguna»; la red, igual que el bueno;
#    el del comentario HTML, PASA «contenedor»; y los de la politica, AUSENTES.
#    Los 8 verdes eran los controles de «no es nuestro» (tercero y fichero sin
#    cargar), el ESTADO de los dos de orden, el del marcador (AVISO, por otro
#    motivo) y el de Meta en un comentario (MED-07 no corria): tienen que seguir
#    igual con el nuevo. Con el gate nuevo, 26 de 26. Y cada mecanismo apagado
#    en una copia del gate pone rojo su control (nueve mutantes, nueve rojos;
#    ver docs/traps/85.md).
MCJ="--contenedor fixtures-lenses/contenedor-solo-google.js --candidato --una-sola --solo medicion --sin-recibo"
espera "casa · MED-01 encuentra el contenedor en consent.js" PASA MED-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js $MCJ
# 🔑 El fichero nombra DOS ids falsos en comentarios ANTES del bueno (un
#    marcador y uno viejo). El que cuenta es el que ejecuta el codigo.
texto  "casa · y es el del codigo, no el de un comentario" SI "GTM-CASA123 · en /consent.js" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js $MCJ
espera "casa · MED-02 default antes de cargar gtm.js"   PASA  MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js $MCJ
espera "casa · MED-07 corre y la politica nombra a Google" PASA MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js $MCJ
# El comentario de consent.js nombra el pixel de Meta (fbevents.js) como
# descartado. Un comentario no carga nada: si se leyera como codigo, MED-07
# sumaria a Meta y FALLARIA contra una politica que dice la verdad.
texto  "casa · MED-07 no suma proveedores de un comentario" NO "Meta / Facebook" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js $MCJ

# ── Controles: lo que NO es la medicion del sitio ──
# Un tercero no es nuestro: el MISMO consent.js servido desde otro host (la
# produccion de mentira SI lo sirve, con GTM-AJENO77 dentro). No se descarga.
espera "no nuestro · consent.js de otro host no cuenta" AVISO MED-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-externo $MCJ
texto  "no nuestro · y no aparece su contenedor"        NO "GTM-AJENO77" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-externo $MCJ
# Un fichero en el arbol que ninguna pagina carga no mide nada.
espera "sin cargar · consent.js en el arbol, sin <script>" AVISO MED-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-sin-cargar $MCJ
texto  "sin cargar · y lo dice como «sin medicion»"     SI "sin medicion ninguna" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-sin-cargar $MCJ
# 🔴 Un comentario HTML que NOMBRA un contenedor no es un contenedor. Salio al
#    escribir estos casos: la segunda busqueda de MED-01 (pagina a pagina, si la
#    home no lo traia) leia el cuerpo SIN quitar comentarios, y esta pagina
#    —sin un solo script de medicion— daba PASA «contenedor GTM-COMENT1».
espera "comentario · un id en un <!-- --> no mide"      AVISO MED-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-comentario-html $MCJ

# ── Controles de ORDEN: el default bien escrito que llega tarde ──
espera "orden · gtm.js directo ANTES de consent.js"     FALLO MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-gtm-directo $MCJ
texto  "orden · y por llegar tarde, no por no existir"  SI "consent default DESPUES del contenedor" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-gtm-directo $MCJ
# 🔴 El que distingue ordenar por EJECUCION de ordenar por TEXTO: consent.js va
#    arriba con defer y el fragmento de GTM abajo en linea. En el texto el
#    default esta antes; al ejecutar, el fragmento corre primero.
espera "orden · fragmento en linea DESPUES, corre ANTES" FALLO MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-inline-despues $MCJ
texto  "orden · defer no adelanta al script en linea"   SI "consent default DESPUES del contenedor" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-inline-despues $MCJ
espera "orden · dentro de consent.js la carga va antes" FALLO MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-orden-interno $MCJ

# ── El marcador de plantilla y MED-07 ──
espera "marcador · GTM-XXXXXXX avisa"                   AVISO MED-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-marcador $MCJ
texto  "marcador · y dice cual, no «sin medicion»"      SI "GTM-XXXXXXX · en /consent.js" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-marcador $MCJ
texto  "marcador · NO dice «sin medicion ninguna»"      NO "sin medicion ninguna" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-marcador $MCJ
# Con un marcador no hay contenedor que descargar: el cruce se declara no hecho.
espera "marcador · MED-03 no verificado, no aprobado"   NOVERIF MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-marcador $MCJ
espera "politica muda · MED-07 caza al proveedor"       FALLO MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-politica-muda $MCJ
# 🔴 En cuanto MED-07 empezo a correr sobre la medicion de la casa, la web de la
#    agencia salio FALLO «hay contenedor y no hay pagina de cookies/privacidad»:
#    su politica esta en /privacy.html, fuera de las rutas fijas que MED-07
#    conocia (todas en castellano o frances), y un FALLO de aqui cierra la puerta.
#    La politica se busca ahora tambien en los enlaces internos de la portada,
#    por RUTA o por TEXTO. Cada mitad tiene su caso, en rutas que ninguna ruta
#    fija alcanza, y cada uno se vio ROJO con su mitad quitada de una copia del
#    gate. El tercero guarda el otro lado: enlazar una politica que no existe no
#    es tener una.
espera "politica · la encuentra por el TEXTO del enlace" PASA MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-politica-por-texto $MCJ
espera "politica · la encuentra por la RUTA del enlace"  PASA MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-politica-por-ruta $MCJ
espera "politica · un enlace a un 404 no es politica"   FALLO MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-consent-js-politica-rota $MCJ

# ── Modo RED (produccion, sin --candidato): la misma web servida por HTTP, con
#    la portada pidiendo consent.js por ruta RELATIVA y con ?v= ──
espera "red · MED-01 lee el consent.js servido"         PASA  MED-01 \
       perl $QA http://casa.example/ --solo medicion --una-sola --contenedor fixtures-lenses/contenedor-solo-google.js --cache "$CACHE"
espera "red · MED-02 default antes de cargar gtm.js"    PASA  MED-02 \
       perl $QA http://casa.example/ --solo medicion --una-sola --contenedor fixtures-lenses/contenedor-solo-google.js --cache "$CACHE"
espera "red · MED-07 corre sobre lo servido"            PASA  MED-07 \
       perl $QA http://casa.example/ --solo medicion --una-sola --contenedor fixtures-lenses/contenedor-solo-google.js --cache "$CACHE"

echo
echo "== MEDICION EN MODULOS · el JS que se carga con import · 5-nov-2026"
# 🔴 Una tienda nuestra carga todo su JS como modulos: un <script type="module">
#    en linea que importa ./js/site.js, sin un solo src. El id del contenedor vive
#    en js/config.js, que importa site.js. MED-01 decia «sin medicion ninguna» y
#    MED-02/03/07 no corrian: ids_en_pagina y el cruce leian el HTML y los src
#    propios, nunca los import. Ahora pasan por js_de_la_pagina (la del formulario
#    del JS del mismo dia), y MED-02 fecha cada modulo por el <script> desde el que
#    se llega a el. Lo que no se puede ordenar (el default y la carga en dos
#    ficheros del mismo turno) es NO VERIFICADO con los dos nombres.
#    VISTO EN ROJO PRIMERO, con el programa de antes sobre estos fixtures: los de
#    modulo daban MED-01 AVISO «sin medicion ninguna» y MED-02/03/07 AUSENTES; el
#    del fragmento en linea, FALLO pero por «sin consent default»; y el de la
#    politica leida sin la home, PASA «1 paginas» sin haber medido ninguna (ese
#    estaba roto tambien con un consent.js clasico). Y cada mecanismo apagado en
#    una copia del gate pone rojo su caso (doce mutantes: once rojos, y el de la
#    medicion directa solo se ve en el TEXTO, que es como se prueba abajo).
MMO="--contenedor fixtures-lenses/contenedor-solo-google.js --candidato --una-sola --solo medicion --sin-recibo"
espera "modulo · MED-01 encuentra el contenedor importado" PASA MED-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo $MMO
texto  "modulo · dice en que modulo y quien lo importa"  SI "GTM-MODULO1 · en /js/config.js (lo importa /js/sitio.js)" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo $MMO
texto  "modulo · no el id de un comentario del modulo"   NO "GTM-VIEJO02" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo $MMO
espera "modulo · MED-02 default antes, en el mismo fichero" PASA MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo $MMO
texto  "modulo · y cuenta las paginas que midio"         SI "1 de 1 paginas cargan contenedor" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo $MMO
espera "modulo · MED-07 corre y la politica nombra a Google" PASA MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo $MMO
texto  "modulo · G- en un modulo es medicion directa"    SI "G-MODULO1234 · en /js/config.js (lo importa /js/sitio.js)" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-gtag $MMO
texto  "modulo · y no «sin medicion ninguna»"            NO "sin medicion ninguna" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-gtag $MMO
# ── Los rojos de MED-02: el contenedor en un modulo no puede salir PASA sin medir ──
espera "modulo · sin consent default, FALLA"             FALLO MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-sin-consent $MMO
texto  "modulo · y por no existir"                       SI "sin consent default: cookies antes de aceptar" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-sin-consent $MMO
# El modulo es diferido: el fragmento clasico escrito DESPUES corre ANTES.
espera "modulo · fragmento en linea despues, corre antes" FALLO MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-fragmento-antes $MMO
texto  "modulo · y por llegar tarde, no por no existir"  SI "consent default DESPUES del contenedor" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-fragmento-antes $MMO
espera "modulo · dentro del modulo la carga va antes"    FALLO MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-orden-interno $MMO
# Dos ficheros del mismo turno: el orden es el de las llamadas, que no se siguen.
espera "modulo · default y carga en dos modulos: sin verificar" NOVERIF MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-orden-incierto $MMO
texto  "modulo · y nombra los dos ficheros"              SI "el default en /js/consentimiento.js, gtm.js en /js/etiquetas.js" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-orden-incierto $MMO
espera "modulo · sin carga de gtm.js legible: sin verificar" NOVERIF MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-sin-carga $MMO
# 0 paginas medidas no es un PASA: el contenedor sale de la home y se lee otra.
espera "modulo · ninguna leida carga el contenedor"      NOVERIF MED-02 \
       perl $QA https://climentmedia.com/politica-privacidad/ --repo fixtures-lenses/med-modulo $MMO
espera "clasico · igual con un consent.js de los de antes" NOVERIF MED-02 \
       perl $QA https://climentmedia.com/politica-privacidad/ --repo fixtures-lenses/med-consent-js $MMO
# ── MED-03 y MED-07 leen tambien lo importado ──
espera "modulo · evento de un modulo que nadie escucha"  FALLO MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-tercero $MMO
texto  "modulo · y dice cual"                            SI "solicitud_presupuesto" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-tercero $MMO
espera "modulo · pixel de un modulo, politica muda"      FALLO MED-07 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-modulo-tercero $MMO

echo
echo "== CONTROLES POSITIVOS · defectos CONOCIDOS de la sintesis del 10-ago-2026"
espera "site-a · paleta bajo AA (--primary L=0,58)"        FALLO A11Y-03 perl $QA http://site-a.example/ --solo a11y --cache "$CACHE"
espera "site-a · el comentario dice 4,84 y son 4,11"        FALLO A11Y-04 perl $QA http://site-a.example/ --solo a11y --cache "$CACHE"
espera "site-a · favicon de 320 KB en 13 paginas"           FALLO REN-07  perl $QA http://site-a.example/ --solo rendimiento --cache "$CACHE"
# 🔴 ESTE CASO ESPERABA `FALLO REN-04` Y ERA UN FALSO POSITIVO DEL GATE, no un
#    defecto de site-a. Sumaba los 4 .woff2 DECLARADOS; los cuatro llevan
#    `unicode-range` y Chrome baja 2 (112,9 KB), medido. Verificado aparte del
#    gate sobre el arbol entero: 25 ficheros, 37 codepoints no-ASCII, 0 en
#    latin-ext. Se cambia la expectativa Y se fija el numero, que es lo que
#    distingue «lo he arreglado» de «lo he apagado». Los controles negativos
#    —fuente sin unicode-range, y rango que el sitio SI usa— estan al final.
espera "site-a · las 2 fuentes que el navegador SI baja"    PASA  REN-04  perl $QA http://site-a.example/ --solo rendimiento --cache "$CACHE"
texto  "site-a · REN-04 dice cuantas descuenta y por que"   SI "2 de 4 NO se bajan" \
       perl $QA http://site-a.example/ --solo rendimiento --cache "$CACHE"
espera "site-a · PNG de 2,3 MB / logo a 200 B/px"           FALLO REN-02  perl $QA http://site-a.example/ --solo rendimiento --cache "$CACHE"
# ⚠️ 22-sep-2026 · `--contenedor` en los casos de site-d que necesitan el
#    contenedor (MED-03/07/08): antes se descargaba de googletagmanager.com por
#    HTTPS, y el banco ya no sale a internet. Sin el, esos checks salen NO
#    VERIFICADO o ausentes. Es la costura que el gate trae para esto.
espera "bc · page_view_gracias sin disparador (G1)"       FALLO MED-03  perl $QA http://site-d.example/ --gracias /gracias/ --solo medicion --contenedor fixtures-sites/site-d.example/_gtm.js --cache "$CACHE"
texto  "bc · y lo nombra"                                  SI "page_view_gracias" perl $QA http://site-d.example/ --gracias /gracias/ --solo medicion --contenedor fixtures-sites/site-d.example/_gtm.js --cache "$CACHE"
# 🔴 6-nov-2026 · MED-03 LEE LOS PREDICADOS SOBRE {{Event}}. Un activador por expresion regular no
#    escribe el nombre entre comillas, y una web que lo escuchaba salia FALLO (visto en ROJO contra el
#    gate anterior: med03-patron daba FALLO). Y al reves: un nombre entre comillas en un predicado de la
#    URL o en uno negado daba PASA (med03-patron-otro, VERDE contra el gate anterior: era un falso PASA).
_M03="--candidato --una-sola --solo medicion --sin-recibo"
espera "MED-03 · un activador por patron lo escucha: PASA"       PASA    MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-patron --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
texto  "MED-03 · y dice que es por un patron"                    SI "por un disparador con patron: devis_envoye" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-patron --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
espera "MED-03 · patron que no lo cubre, URL y negado: FALLO"    FALLO   MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-patron --contenedor fixtures-lenses/contenedor-med03-patron-otro.js $_M03
espera "MED-03 · patrones que no se pueden leer: NO VERIFICADO"  NOVERIF MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-patron --contenedor fixtures-lenses/contenedor-med03-patron-ilegible.js $_M03
# Medido en nueve webs nuestras antes de creerselo: dos pasaban de PASA a FALLO por un nombre que el
# contenedor ENVIA desde otro activador (una etiqueta con ese vtp_eventName). Llega a GA4: es AVISO.
espera "MED-03 · lo manda otro activador (vtp_eventName): AVISO" AVISO   MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-patron --contenedor fixtures-lenses/contenedor-med03-patron-envia.js $_M03
# 🔴 6-nov-2026 · LA CLAVE SIN COMILLAS. `dataLayer.push({ event: "x" })` no se leia: med03-sin-comillas
#    salia «no emite ningun evento» (AVISO) con los dos contenedores, el que lo escucha y el que no
#    (visto en ROJO contra el gate anterior en los dos casos de abajo). Y un nombre compuesto
#    (`"cm_" + nombre`) no es un nombre: si se tomara el trozo entre comillas, med03-compuesto cruzaria
#    «cm_» y saldria FALLO (visto en ROJO quitando el `(?!\s*\+)`). El objeto de libreria
#    (`{ event: "scroll_libreria" }`, fuera de un push) no se cruza: si se cruzara, el PASA seria FALLO.
espera "MED-03 · clave sin comillas, el contenedor la escucha: PASA" PASA  MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-sin-comillas --contenedor fixtures-lenses/contenedor-med03-sin-comillas.js $_M03
texto  "MED-03 · y nombra el compuesto, sin cruzarlo"               SI "y 1 con un nombre que el JS compone" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-sin-comillas --contenedor fixtures-lenses/contenedor-med03-sin-comillas.js $_M03
texto  "MED-03 · un {event:} de libreria no es un evento"           NO "scroll_libreria" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-sin-comillas --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
espera "MED-03 · clave sin comillas que nadie escucha: FALLO"       FALLO MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-sin-comillas --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
espera "MED-03 · solo nombres compuestos: AVISO, no FALLO"          AVISO MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-compuesto --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
texto  "MED-03 · y dice que el JS compone el nombre"                SI "el JS compone el nombre del evento" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-compuesto --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
# 🔴 6-nov-2026 · LA CLAVE ABREVIADA. `push({ event, site, ...params })` (un ayudante `track(event, …)`)
#    no tiene dos puntos y ninguna regla la veia: una tienda nuestra salia «no emite ningun evento con
#    nombre». De los cuatro push de med03-abreviada cuentan 2; el valor (`origen: event`) y la clave que
#    empieza igual (`event_id`) no. El estado es AVISO con las dos reglas: lo que la separa es el texto
#    (visto en ROJO contra el gate anterior en los dos `texto`, y la cifra exacta, con cuatro mutantes).
espera "MED-03 · clave abreviada: AVISO"                            AVISO MED-03 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-abreviada --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
texto  "MED-03 · la clave abreviada cuenta: 2 de los 4 push"        SI "2 push con un nombre que se construye" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-abreviada --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
texto  "MED-03 · y no dice que el sitio no emite"                   NO "no emite ningun evento" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med03-abreviada --contenedor fixtures-lenses/contenedor-med03-patron.js $_M03
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
# 🔴 6-nov-2026 · EL LECTOR QUE LEE POR UNA CONSTANTE. El tema de una tienda guarda el
#    nombre en `const X="data-…"` y lee con getAttribute(X), hasAttribute(X) y
#    `[${X}]`; MED-05 solo veia el nombre escrito en la llamada y lo daba por
#    huerfano (medido con el .js servido por la tienda: FALLO antes, PASA despues).
#    El fixture es con-lector con el lector reescrito asi. Su negativo: la MISMA
#    constante usada solo para ESCRIBIR (setAttribute), que no es leer: sigue FALLO.
espera "MED-05 · lee por una constante: PASA"             PASA  MED-05 \
       perl $QA https://climentmedia.com --repo fixtures-med05/lector-por-constante --candidato --una-sola --solo medicion --sin-recibo
espera "MED-05 · la constante solo escribe: FALLO"        FALLO MED-05 \
       perl $QA https://climentmedia.com --repo fixtures-med05/constante-que-solo-escribe --candidato --una-sola --solo medicion --sin-recibo
# 🔴 Y que no se acuse al codigo DEL CLIENTE: `_migrate/` guarda su web
#    capturada como evidencia y no se despliega. En site-c daba 16 atributos, de
#    los que 4 de los 5 visibles eran de su Elementor.
texto  "MED-05 · no acusa al HTML del cliente (_migrate)"  NO "_migrate/origen" \
       perl $QA http://site-d.example/ --repo $REPOS/site-d-web --solo medicion --sin-recibo --cache "$CACHE"
espera "404 malo servido en local · sin h1 ni enlaces"             FALLO EST-03  perl $QA $U404 --solo estructura
espera "bc · styles.css del repo NO desplegado (G11)"     FALLO EST-09  perl $QA http://site-d.example/ --repo $REPOS/site-d-web --solo estructura --sin-recibo --cache "$CACHE"
# 🔴 5-nov-2026 · EST-09 PIDE LA URL SELLADA, COMO EL NAVEGADOR. Una tienda servia
#    la hoja nueva en `styles.css?v=…` (lo que pide cada visitante) y su CDN
#    guardaba en la URL desnuda la copia de una semana antes. EST-09 quitaba el ?v=
#    tambien al PEDIR y daba FALLO por un fichero que nadie ve. `sinsello` en el
#    _prod.txt del sitio reproduce ese CDN. Rojo contra la regla de antes.
espera "sello · sellada = repo, desnuda vieja (CDN): PASA"  PASA  EST-09  perl $QA http://sello.example/ --repo fixtures-repos/sello-web --solo estructura --una-sola --sin-recibo --cache "$CACHE"
# El control: si la hoja del repo no es la servida (ni sellada ni desnuda), sigue cazando.
espera "sello · la hoja del repo sin subir: FALLO"         FALLO EST-09  perl $QA http://sello.example/ --repo fixtures-repos/sello-web-sin-subir --solo estructura --una-sola --sin-recibo --cache "$CACHE"
texto  "sello · y nombra la hoja"                           SI "/css/styles.css" \
       perl $QA http://sello.example/ --repo fixtures-repos/sello-web-sin-subir --solo estructura --una-sola --sin-recibo --cache "$CACHE"
# 🔴 5-nov-2026 · UNA MEDIDA DE PRODUCCION NO PISA UN RECIBO DE CANDIDATO. Una web
#    midio su produccion con --repo y su recibo de CANDIDATO quedo sustituido por
#    uno de PRODUCCION, que la puerta acepta en verde. Copia en la cache de la
#    corrida: el banco no deja recibos en un fixture.
RCAND="$CACHE/sello-con-recibo"; rm -rf "$RCAND"; cp -r fixtures-repos/sello-web "$RCAND"
printf 'ARBOL-HASH: 0000\nMEDIDO-CONTRA: CANDIDATO\nVEREDICTO: PASA\n' > "$RCAND/.qa-recibo"
H_ANTES="$(md5sum "$RCAND/.qa-recibo" | cut -c1-32)"
texto  "recibo · produccion no pisa el de CANDIDATO: lo dice" SI "es de CANDIDATO, y esta medida es de" \
       perl $QA http://sello.example/ --repo "$RCAND" --solo estructura --una-sola --cache "$CACHE"
if [ "$(md5sum "$RCAND/.qa-recibo" | cut -c1-32)" = "$H_ANTES" ]; then
  printf '  OK    %-46s el fichero no ha cambiado\n' "recibo · y el de CANDIDATO sigue intacto"; ok=$((ok+1))
else
  printf '  MAL   %-46s el .qa-recibo de CANDIDATO ha cambiado\n' "recibo · y el de CANDIDATO sigue intacto"; ko=$((ko+1))
fi
# El control: uno de PRODUCCION si se sustituye (el flujo de antes no se rompe).
printf 'ARBOL-HASH: 0000\nMEDIDO-CONTRA: PRODUCCION\nVEREDICTO: PASA\n' > "$RCAND/.qa-recibo"
texto  "recibo · el de PRODUCCION si se reescribe"        SI "MEDIDO-CONTRA: PRODUCCION (la web ya subida)" \
       perl $QA http://sello.example/ --repo "$RCAND" --solo estructura --una-sola --cache "$CACHE"
rm -rf "$RCAND"

# 🔴 5-nov-2026 · TRES FALSOS POSITIVOS EN UNA TIENDA SHOPIFY, medidos desde el
#    servidor. MED-10 pedia GET a /contact (404 por diseño: el formulario va por
#    POST al receptor de Shopify); REN-13 daba FALLO al preloads.js que inyecta la
#    plataforma desde otro dominio (200, 0 bytes). Cada uno con su caso que TIENE
#    que seguir en rojo: un tema que manda a /contacto, el mismo formulario en una
#    pagina que no es de Shopify, y un script PROPIO de 0 bytes. (EST-10, el cajon
#    del carrito, va con los demas casos de EST-10.)
espera "shopify · /contact por POST: el de la plataforma" PASA  MED-10 perl $QA http://tienda.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
texto  "shopify · y dice que no ha enviado nada"          SI "no se ha enviado nada" \
       perl $QA http://tienda.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "shopify · el tema manda a /contacto: FALLO"       FALLO MED-10 perl $QA http://tienda-mal.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "shopify · /contact sin ser Shopify: FALLO"        FALLO MED-10 perl $QA http://imita.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "shopify · el tercero vacio no es FALLO"           PASA  REN-13 perl $QA http://tienda.example/ --solo rendimiento --una-sola --sin-recibo --cache "$CACHE"
espera "shopify · y sale como aviso aparte"               AVISO REN-13c perl $QA http://tienda.example/ --solo rendimiento --una-sola --sin-recibo --cache "$CACHE"
espera "shopify · uno PROPIO a 0 bytes sigue FALLO"       FALLO REN-13 perl $QA http://tienda-mal.example/ --solo rendimiento --una-sola --sin-recibo --cache "$CACHE"
# 🔴 5-nov-2026 · MED-12 CONTRA PRODUCCION, LOS TRES ESTADOS. Hasta hoy solo hablaba
#    si una ruta interna daba 200: con todo cerrado no decia nada y una web lo leyo
#    como «no lo mide nadie». Una que sirve sus instrucciones de agente y su spec
#    (FALLO, y las nombra), una que lo cierra todo (PASA) y una cuya carpeta de
#    leads contesta 503 (NO VERIFICADO: sin respuesta no es cerrada).
espera "MED-12 · sirve lo interno del repo: FALLO"        FALLO MED-12 perl $QA http://fuga.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
texto  "MED-12 · y nombra lo que sirve"                   SI "http://fuga.example/CLAUDE.md (HTTP 200)" \
       perl $QA http://fuga.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
texto  "MED-12 · tambien la carpeta de spec"              SI "http://fuga.example/_spec/ (HTTP 200)" \
       perl $QA http://fuga.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "MED-12 · todo cerrado: PASA, no silencio"         PASA  MED-12 perl $QA http://cerrado.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "MED-12 · una ruta que da 503: NO VERIFICADO"      NOVERIF MED-12 perl $QA http://a-medias.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
texto  "MED-12 · y no la cuenta como cerrada"             SI "1 de 11 sin respuesta valida; 10 cerradas" \
       perl $QA http://a-medias.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
# 🔴 6-nov-2026 · MED-12 EN UNA TIENDA QUE CONTESTA 200 A TODO. Una plataforma de
#    tienda devolvia /.env y /.qa-recibo con 200 y su pagina HTML entera (medido ese
#    dia: text/html, la tienda), y MED-12 la daba por expuesta: un rojo que no se
#    puede arreglar, porque no hay fichero. Una ruta de FICHERO que contesta con una
#    pagina HTML no sirve el fichero. Las dos caras que TIENEN que seguir en rojo: un
#    .env de verdad (no empieza por <html: es el fichero) y una CARPETA que da 200
#    con HTML (un listado tambien es HTML).
espera "MED-12 · fichero que contesta con su pagina: PASA" PASA  MED-12 perl $QA http://pagina-200.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
texto  "MED-12 · y lo dice, no lo calla"                  SI "/.env 200 (una pagina HTML, no el fichero)" \
       perl $QA http://pagina-200.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "MED-12 · un .env de verdad sigue FALLO"           FALLO MED-12 perl $QA http://env-real.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
texto  "MED-12 · y lo nombra"                             SI "http://env-real.example/.env (HTTP 200)" \
       perl $QA http://env-real.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "MED-12 · carpeta con 200 y HTML sigue FALLO"      FALLO MED-12 perl $QA http://carpeta-200.example/ --solo medicion --una-sola --sin-recibo --cache "$CACHE"
espera "bc · politica «pendiente de revision juridica»"   FALLO MED-08  perl $QA http://site-d.example/ --solo medicion --contenedor fixtures-sites/site-d.example/_gtm.js --cache "$CACHE"
espera "bc · casillas de analitica premarcadas (G13)"     FALLO MED-06  perl $QA http://site-d.example/ --solo medicion --cache "$CACHE"
# 8-sep-2026 - LA CARA CONTRARIA, y hacia falta: el caso de arriba solo prueba que
# el check CAZA. Este prueba que no acusa a quien esta bien, que es donde estaba el
# defecto: la exencion decia "necess" y en castellano es "necesarias", con una sola
# ese, asi que la casilla obligatoria de cualquier banner en espanol salia acusada.
espera "site-e · «necesarias» en castellano NO es premarcada"  PASA  MED-06  perl $QA http://site-e.example/ --solo medicion --cache "$CACHE"
espera "cm · og:image:alt al 0% donde vive el estandar"   FALLO SEO-06  perl $QA http://cm.example/ --solo seo --cache "$CACHE"
espera "site-b · ficha que solo existe con JS (G10)"     FALLO SEO-14  perl $QA "http://shop.site-b.example/produto.html?sku=MOB-001" --solo seo --cache "$CACHE"
espera "site-c(fixture) · 27,7 pantallas y 1 CTA"           FALLO EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-site-c-broken.json --cache "$CACHE"
espera "site-c(fixture) · fila coja y titular huerfano"     FALLO EST-07  perl $QA http://site-c.example/ --solo estructura --dom dom-site-c-broken.json --cache "$CACHE"

echo
echo "== CONTROLES QUE DEBEN PASAR"
espera "bc REPO con --primary ya corregido a L=0,54"      PASA  A11Y-03 perl $QA http://site-d.example/ --solo a11y --css $REPOS/site-d-web/styles.css --cache "$CACHE"
espera "site-c · su 404 (la unica que pasa maqueta)"        PASA  EST-03  perl $QA http://site-c.example/ --solo estructura --cache "$CACHE"
espera "bc · comprime html/css/js (PC17)"                 PASA  REN-08  perl $QA http://site-d.example/ --solo rendimiento --cache "$CACHE"
espera "bc · 0 webfonts, la mejor maqueta sin ninguna"    PASA  REN-04  perl $QA http://site-d.example/ --solo rendimiento --cache "$CACHE"
espera "cm · sitemap con la pagina dentro"                PASA  SEO-16  perl $QA http://cm.example/ --solo seo --cache "$CACHE"

echo
echo "== CASOS FRONTERA · PARECEN defectos y NO lo son"
espera "cm · 8 de 9 <img> con alt=\"\" DECORATIVO (X3)"     PASA  SEO-10  perl $QA http://cm.example/ --solo seo --cache "$CACHE"
espera "configurador · 0 CTA y 14 <button> (excepcion)"   PASA  EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-configurator.json --cache "$CACHE"
espera "configurador · se anota, no se arregla"           AVISO EST-06b perl $QA http://site-c.example/ --solo estructura --dom dom-configurator.json --cache "$CACHE"
espera "guia de PROSA de 12,4 pantallas (sospecha)"       PASA  EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-long-prose.json --cache "$CACHE"
# 🔴 6-nov-2026 · EL LARGO DE LA PAGINA, CON LA REGLA DE LA PUERTA. measure-screens.js
#    cambio el 6 fijo por un presupuesto de palabras el 19-ago (6 pantallas + 1 por
#    cada 80 palabras visibles pasadas las 400, techo 12), y EST-06 siguio con el 6:
#    una portada medida el 6-nov a 390 (6,9 pantallas en produccion, 8,1 en el candidato,
#    limite 10,5 en la puerta) salia FALLO aqui y PASA en la puerta [trap:design-E3]. El snippet copia ahora el limite que calcula
#    measure-screens.js y EST-06 juzga con el. Vistos en ROJO contra el qa-master de
#    antes: la portada de 8,2 pantallas con 760 palabras daba FALLO, el FALLO de 11,2 no
#    nombraba su limite, el DOM viejo no pedia recapturar y el snippet no copiaba nada.
espera "portada de 8,2 pantallas y 760 palabras: limite 10,5" PASA  EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-portada-con-texto.json --cache "$CACHE"
texto  "...y lo que la dejo pasar es el limite de la puerta"  SI "limite 10.5 para 760 palabras visibles" perl $QA http://site-c.example/ --solo estructura --dom dom-portada-con-texto.json --cache "$CACHE"
espera "la misma con 11,2 pantallas: pasa del limite"     FALLO EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-portada-pasada.json --cache "$CACHE"
texto  "...y el FALLO dice su limite, no el 6"            SI "pagina: 11.2 pantallas (limite 10.5 para 760 palabras visibles" perl $QA http://site-c.example/ --solo estructura --dom dom-portada-pasada.json --cache "$CACHE"
espera "DOM de un snippet viejo: sin limite, sigue el 6"  FALLO EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-portada-snippet-viejo.json --cache "$CACHE"
texto  "...y pide recapturar"                             SI "sin el limite de measure-screens.js" perl $QA http://site-c.example/ --solo estructura --dom dom-portada-snippet-viejo.json --cache "$CACHE"
texto  "el snippet copia el limite de measure-screens.js"  SI "out.limite_pantallas = ms.resumen.limitePantallas" perl $QA --snippet
espera "tactil 44x44: es AAA, nunca FALLO"                AVISO A11Y-12 perl $QA http://site-d.example/ --solo a11y --cache "$CACHE"
espera "sin hoja de tokens: NO medido != aprobado (X12)"  NOVERIF A11Y-03 perl $QA http://site-d.example/ --solo a11y --css /no/existe.css --cache "$CACHE"
espera "ancho clampado: la medida se tira entera (PC15)"  NOVERIF EST-05  perl $QA http://site-c.example/ --solo estructura --dom dom-unmeasured.json --cache "$CACHE"
# 3-nov-2026 · EL TESTIGO DEL DOM. El 28-oct el snippet midio el 403 de una CDN y salio
# FALLO EST-06 (1,0 pantallas, 0 CTA) sin error. Vistos en ROJO contra el qa-master de
# antes: el muro daba FALLO EST-06 y PASA REN-11, el error maquetado FALLO EST-06, y el
# JSON sin testigo PASA EST-06.
espera "muro de la CDN (403): la medida no es la web"     NOVERIF EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-muro-403.json --cache "$CACHE"
espera "muro de la CDN (403): EST-05 dice por que"        NOVERIF EST-05  perl $QA http://site-c.example/ --solo estructura --dom dom-muro-403.json --cache "$CACHE"
espera "muro de la CDN (403): su LCP tampoco vale"        NOVERIF REN-11  perl $QA http://site-c.example/ --solo rendimiento --dom dom-muro-403.json --cache "$CACHE"
# 🔴 5-nov-2026 · UN null NO ES 0. El snippet leia el LCP con getEntriesByType, que
#    Chrome deja vacio; llegaba null y `//0` lo hacia «LCP 0 ms»: PASA sin medir en
#    todo recibo con --dom. El primero salia PASA con el programa de antes.
espera "LCP y CLS sin medir (null): no es 0, NO VERIFICADO" NOVERIF REN-11 perl $QA http://site-c.example/ --solo rendimiento --dom dom-lcp-sin-medir.json --cache "$CACHE"
espera "LCP lento y CLS sin medir: lo medido falla igual"   FALLO   REN-11 perl $QA http://site-c.example/ --solo rendimiento --dom dom-lcp-lento-sin-cls.json --cache "$CACHE"
espera "LCP y CLS medidos y buenos: PASA"                  PASA    REN-11 perl $QA http://site-c.example/ --solo rendimiento --dom dom-lcp-y-cls-medidos.json --cache "$CACHE"
texto  "el snippet lee el LCP con PerformanceObserver"     SI "type: 'largest-contentful-paint', buffered: true" perl $QA --snippet
texto  "...y ya no con getEntriesByType"                   NO "getEntriesByType('largest-contentful-paint')" perl $QA --snippet
espera "error maquetado con 403 y testigo que miente"     NOVERIF EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-error-maquetado.json --cache "$CACHE"
espera "JSON sin testigo: no prueba nada"                 NOVERIF EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-sin-testigo.json --cache "$CACHE"
# 3-nov-2026 · LA DENSIDAD DE UNA SOLA FUENTE: el snippet lleva measure-screens.js dentro
# y qa-master lee sus dos recuentos. Vistos en ROJO contra el qa-master de antes: el
# contenedor gigante salia PASA (no leia contenedores_gigantes) y la densidad sin medir
# tambien PASA (un 0 por defecto).
espera "contenedor de 3,4 pantallas (regla de la puerta)" FALLO EST-06    perl $QA http://site-c.example/ --solo estructura --dom dom-contenedor-gigante.json --cache "$CACHE"
texto  "...y cae POR el contenedor, no por otra cosa"     SI "contenedor > 3 pantallas: 1" perl $QA http://site-c.example/ --solo estructura --dom dom-contenedor-gigante.json --cache "$CACHE"
espera "measure-screens no corrio: no hay veredicto"      NOVERIF EST-06  perl $QA http://site-c.example/ --solo estructura --dom dom-densidad-sin-medir.json --cache "$CACHE"
texto  "el snippet lleva dentro la regla de la puerta"    SI "tramoSinParada" perl $QA --snippet
# 7-nov-2026 · UN PARRAFO NO ES UNA REJILLA. La «rejilla con 1 elemento» de EST-07 contaba
#    cualquier [class*="grid"] con un hijo estrecho, y en una portada cogio un
#    <p class="grid__more"> en bloque. El umbral dice «de >=2 columnas»: ahora solo cuenta
#    una caja que reparte en columnas. Su comportamiento se mide en Chrome con
#    fixtures-g6/ (seis cajas: 3 cuentan; con el snippet de antes, 6), ver su POR-QUE.txt.
texto  "EST-07 · una rejilla de 1 tiene que ser de columnas" SI "if (deColumnas && cols === 1 && hijos.length === 1" perl $QA --snippet
texto  "...y lo mira por el display, no por la clase"      SI "/grid/.test(cs.display) ? cs.gridTemplateColumns" perl $QA --snippet
espera "hover sin fondo declarado: no se acusa"           NOVERIF A11Y-03b perl $QA http://site-a.example/ --solo a11y --cache "$CACHE"

echo
echo "== ARREGLO 0.1 · EL FONDO SE LEE, NO SE ASUME BLANCO"
texto  "cm · lee el fondo REAL de body (rgb(7,7,8))"   SI "= #070708" \
       perl $QA http://cm.example/ --solo a11y --una-sola --cache "$CACHE"
texto  "site-c · lee el fondo REAL (oklch 16%)"          SI "var(--noche) = #12071c" \
       perl $QA http://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
texto  "cm · ya NO mide contra un blanco inventado"    NO "sobre #ffffff" \
       perl $QA http://cm.example/ --solo a11y --una-sola --cache "$CACHE"
espera "site-c · su paleta oscura PASA (era FALLO falso)" PASA  A11Y-03 perl $QA http://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: en una web que SI es blanca, el fallo real sigue vivo.
espera "site-a · fondo blanco de verdad: sigue FALLANDO"  FALLO A11Y-03 perl $QA http://site-a.example/ --solo a11y --una-sola --cache "$CACHE"
texto  "site-a · y sigue senalando el par real 4,11:1"    SI "#258998 sobre #ffffff = 4.11:1" \
       perl $QA http://site-a.example/ --solo a11y --una-sola --cache "$CACHE"
espera "CENTINELA: ratio 1,00:1 -> grita, no acusa"     NOVERIF A11Y-03z perl $QA http://site-c.example/ --solo a11y --una-sola --css css-sentinel.css --cache "$CACHE"
espera "CENTINELA: y el par imposible NO es fallo"      PASA    A11Y-03  perl $QA http://site-c.example/ --solo a11y --una-sola --css css-sentinel.css --cache "$CACHE"
espera "CENTINELA: sin regla imposible, no salta"       AUSENTE A11Y-03z perl $QA http://site-c.example/ --solo a11y --una-sola --css css-no-sentinel.css --cache "$CACHE"
# 🔴 22-sep-2026 · EL AUSENTE DE ARRIBA SALE VERDE TAMBIEN SIN MEDIR NADA: con la
#    home vacia, A11Y-03z no aparece porque no hay nada que mirar (medido al
#    construir site-c.example). Su testigo: con la MISMA hoja, la paleta se mide.
espera "CENTINELA: sin regla imposible, la lente SI mide" PASA A11Y-03 perl $QA http://site-c.example/ --solo a11y --una-sola --css css-no-sentinel.css --cache "$CACHE"

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
espera "site-b · el defecto real, en su sitio (G10)"       FALLO SEO-14 perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
espera "site-b · con --una-sola vuelve el falso PASA"      PASA  SEO-14 perl $QA http://shop.site-b.example/ --solo seo --una-sola --cache "$CACHE"
espera "site-c · 2 titles repetidos entre docs DISTINTOS"     FALLO SEO-02 perl $QA http://site-c.example/ --solo seo --cache "$CACHE"
espera "site-c · con --una-sola vuelve el falso PASA"         PASA  SEO-02 perl $QA http://site-c.example/ --solo seo --una-sola --cache "$CACHE"
# 🔴 22-sep-2026 · Y ESE PASA TAMBIEN SALE SIN HOME: la lente SEO no tiene la guarda
#    de «cero paginas leidas» que si tienen accesibilidad y estructura, y con la
#    home en 404 da SEO-02 PASA con «0 documentos distintos». Testigo: leyo UNO.
texto  "site-c · --una-sola SI ha leido la home"              SI "DATO   1 documentos distintos" \
       perl $QA http://site-c.example/ --solo seo --una-sola --cache "$CACHE"
texto  "el informe DECLARA el alcance de cada lente"        SI "ALCANCE      cuantas paginas ha mirado cada lente" \
       perl $QA http://site-c.example/ --solo a11y --cache "$CACHE"
texto  "y dice de donde ha sacado la lista"                 SI "del sitemap" \
       perl $QA http://site-c.example/ --solo a11y --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: SEO-16 pregunta si la pagina PEDIDA esta en el sitemap.
#    Si se comparara contra la lista expandida seria PASA por construccion.
espera "SEO-16 sigue midiendo (URL pedida fuera del sitemap)" AVISO SEO-16 perl $QA http://site-c.example/no-esta-en-el-sitemap --solo seo --una-sola --cache "$CACHE"

echo
echo "== ARREGLO 0.5b · EL ENLACE DE SALTO, EN EL IDIOMA QUE SEA"
espera "site-c · <a class=saltar href=#principal> (castellano)" PASA  A11Y-02 perl $QA http://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
espera "site-a · <a class=skip>Aller au contenu (frances)"      PASA  A11Y-02 perl $QA http://site-a.example/ --solo a11y --una-sola --cache "$CACHE"
espera "bc · <a class=skip>Saltar al contenido"               PASA  A11Y-02 perl $QA http://site-d.example/ --solo a11y --una-sola --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: las dos que de verdad NO lo tienen siguen acusadas.
espera "cm · no tiene ninguno: sigue FALLANDO"                FALLO A11Y-02 perl $QA http://cm.example/ --solo a11y --una-sola --cache "$CACHE"
espera "site-b · no tiene ninguno: sigue FALLANDO"           FALLO A11Y-02 perl $QA http://shop.site-b.example/ --solo a11y --una-sola --cache "$CACHE"

echo
echo "== ARREGLO 0.6 · 404 O 0 KB ES FALLO, NO «LIGERO»"
espera "bc · favicon.svg devuelve 404 (salia PASA 0 KB)"   FALLO REN-07 perl $QA http://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
espera "bc · y el barrido general lo caza tambien"         FALLO REN-13 perl $QA http://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
# 🔴 22-sep-2026 · EN EL BANCO HERMETICO, ESE FALLO TIENE DOS MOTIVOS. El gate
#    reconstruye la URL del contenedor (https://www.googletagmanager.com/gtm.js?id=...)
#    y la cuenta como recurso; aqui el proxy rechaza todo HTTPS, asi que sale
#    «HTTP 0» y REN-13 seguiria en FALLO aunque el favicon existiera (medido:
#    con favicon.svg presente, REN-07 y «HTTP 404» caen y REN-13 no). El
#    «HTTP 404» de abajo lo imprime tambien REN-07, asi que tampoco lo ata.
#    Este literal es el del DONDE de REN-13, con su «icon ·»: es el unico testigo
#    de que el barrido general sigue viendo el favicon.
texto  "bc · REN-13 nombra el favicon, no solo el contenedor" SI "favicon.svg (icon · HTTP 404)" \
       perl $QA http://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
texto  "bc · lo dice con su estado, no con su peso"        SI "HTTP 404" \
       perl $QA http://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: el check de PESO no se ha perdido por el camino, y una
#    web cuyos recursos responden todos no puede salir acusada por esto.
espera "site-a · 320 KB de favicon: sigue siendo FALLO de PESO" FALLO REN-07 perl $QA http://site-a.example/ --solo rendimiento --una-sola --cache "$CACHE"
espera "site-c · todos sus recursos responden"                  PASA  REN-13 perl $QA http://site-c.example/ --solo rendimiento --una-sola --cache "$CACHE"
espera "site-c · su favicon existe y es ligero"                 PASA  REN-07 perl $QA http://site-c.example/ --solo rendimiento --una-sola --cache "$CACHE"
# 19-ago-2026 - UN FAVICON EN data: NO SE DESCARGA, asi que nunca entraba en la
#   lista de RECURSOS, y la web que lo declara del mejor modo posible -cero
#   peticiones- salia como "sin favicon declarado". Este caso es el que lo fija.
espera "cm - favicon en data: URI, no es un hueco"          PASA  REN-07 perl $QA http://cm.example/ --solo rendimiento --una-sola --cache "$CACHE"
# 🔴 FRONTERA que este mismo arreglo destapo y casi cuesta un FALLO FALSO en una
#    web viva: /ad-account-audit/ declara href="ad-account-audit.css". La lista
#    de paginas viaja SIN barra final, y resolverlo contra `.../audit` daba
#    `/ad-account-audit.css` (404) en vez de `/ad-account-audit/...` (200). Se
#    resuelve contra la URL EFECTIVA. Sin esto, REN-13 acusaba en falso.
espera "cm · href relativo bajo URL con barra: NO es 404"     PASA  REN-13 perl $QA http://cm.example/ad-account-audit/ --solo rendimiento --una-sola --cache "$CACHE"

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
       perl $QA http://cm.example/ad-account-audit/ --solo rendimiento --una-sola --cache "$CACHE"

echo
echo "== ARREGLO P1 · EL PESO DE UNA PAGINA NO DEPENDE DE SU SITIO EN LA LISTA"
#  🔴 `@font-face` cargaba TODAS las fuentes a $URLS[0] en vez de a las paginas
#     que cargan esa hoja. Medido en site-a, la MISMA pagina:
#         primera de la lista -> 1053 KB (font 254 KB)
#         segunda de la lista ->  912 KB (font 113 KB)
#     Y la direccion del error es la mala: INFRAVALORA. Un sitio pesado podia
#     colarse por debajo del tope segun en que orden se escribiera la lista.
# ⚠️ 22-sep-2026 · LOS NUMEROS SON DEL SITIO SINTETICO, NO DE LA WEB REAL. Aquella
#    pesaba 1053 KB (icon 313 · img 313 · font 254), y reproducirla costaba ~880 KB
#    de binarios en cada arbol. Lo que el caso fija sigue igual: REN-01 suma los 4
#    woff2 declarados y se los atribuye a la home SOLA, e icon e img son el mismo
#    PNG. Visto en rojo contra una copia del gate sin el arreglo P1: 253 frente a 252.
texto  "site-a · la home SOLA pesa 253 KB con font 202 KB"  SI "253 KB · font 202 KB · icon 23 KB · img 23 KB" \
       perl $QA http://site-a.example/ --solo rendimiento --una-sola --cache "$CACHE"
# ⚠️ Las listas se BORRAN antes: $CACHE sobrevive entre corridas, y una lista
#    de ayer haria que el caso de abajo midiera lo de ayer. Sin su bloque, el
#    caso de REN-04 que la lee sale NO MEDIDO por nombre, no con la vieja.
rm -f "$CACHE"/ren-A.txt "$CACHE"/ren-B.txt "$CACHE"/ren-A.peso "$CACHE"/ren-B.peso
# 🔴 Sin el sitio congelado este diff comparaba DOS FICHEROS VACIOS y salia OK.
if mide_bloque "el peso NO depende del orden" http://site-a.example/ --cache "$CACHE"; then
  printf 'http://site-a.example/\nhttp://site-a.example/services\n' > "$CACHE/ren-A.txt"
  printf 'http://site-a.example/services\nhttp://site-a.example/\n' > "$CACHE/ren-B.txt"
  for o in A B; do
    perl $QA "@$CACHE/ren-$o.txt" --solo rendimiento --sin-recibo --cache "$CACHE" 2>&1 \
      | grep -A2 'REN-01' | grep -E 'DATO|DONDE' | sed 's/  */ /g' > "$CACHE/ren-$o.peso"
  done
  if diff -q "$CACHE/ren-A.peso" "$CACHE/ren-B.peso" >/dev/null; then
    printf '  OK    %-46s %s\n' "el peso NO depende del orden" "$(sed -n '1p' "$CACHE/ren-A.peso" | sed 's/^ *//')"; ok=$((ok+1))
  else
    printf '  MAL   %-46s el peso DEPENDE del orden:\n' "el peso NO depende del orden"; ko=$((ko+1))
    diff "$CACHE/ren-A.peso" "$CACHE/ren-B.peso" | sed 's/^/          /'
  fi
fi
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
       perl $QA http://cm.example/ --solo rendimiento --cache "$CACHE"
# 🔴 22-sep-2026 · EL LITERAL DE ARRIBA ES UNA NOTA FIJA de la lente: sale aunque no
#    se haya descargado nada (medido: con el host en 502 sigue apareciendo). El
#    testigo de que la muestra es REAL: 3 de las 6 URLs del sitemap.
texto  "la muestra mira 3 de las 6 del sitemap"              SI "3 de  6 del sitio · PARCIAL" \
       perl $QA http://cm.example/ --solo rendimiento --cache "$CACHE"

echo
echo "== ARREGLO P2 · SE DEDUPLICA POR DOCUMENTO, NO POR CADENA DE URL"
#  site-b: 25 URLs auditadas -> 11 documentos. loja.html?cat=* es UN fichero
#  (md5 e55587a629cc) y produto.html?sku=* otro (39f60689ed61). Verificado a
#  mano con curl+md5sum el 10-ago-2026.
texto  "site-b · declara que 25 URLs son 11 documentos"  SI "25 URLs sirven 11 documentos distintos" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · SEO-02 cuenta DOCUMENTOS, no URLs"      SI "11 documentos distintos" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · el defecto NO se pierde: lo dice SEO-14" SI "este MISMO documento se sirve en" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
# 🔴 CONTROL NEGATIVO de SEO-04: deja de castigar la canonicalizacion BIEN
#    hecha (?cat=* -> loja.html, verificado a mano) y sigue acusando a la que
#    de verdad no tiene canonical (produto.html?sku=*).
espera "site-b · SEO-04 sigue acusando (falta canonical)" FALLO SEO-04 perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · y ya NO acusa a ?cat= con canonical OK"  NO "loja.html?cat=" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "site-b · SI acusa a la ficha sin canonical"       SI "produto.html?sku=MOB-001 (sin canonical)" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
# 🔴 22-sep-2026 · Y EL ARREGLO DE ARRIBA SE CAIA CON UN SOLO COMENTARIO HTML.
#    SEO-04 hasheaba esta pagina SIN comentarios y el destino del canonical
#    CRUDO: con cualquier comentario dentro, «el mismo fichero» salia distinto y
#    la variante bien canonicalizada volvia a salir acusada. Lo encontro quien
#    construyo shop.site-b.example, que tuvo que escribir sus paginas sin
#    comentarios para esquivarlo. Medido con este fixture: el mismo loja.html con
#    comentario FALLO y sin comentario PASA, con el gate viejo.
#    El negativo es el que importa: comparar lo mismo en los dos lados no puede
#    volverse «perdonar cualquier canonical». La ficha lleva el MISMO comentario y
#    apunta a OTRO documento: sigue en FALLO.
espera "SEO-04 · variante con comentario, mismo fichero: PASA" PASA  SEO-04 \
       perl $QA "https://tienda.example/loja.html?cat=espejos" --repo fixtures-seo04/canonical-con-comentario --candidato --una-sola --solo seo --sin-recibo
espera "SEO-04 · canonical a OTRO documento: sigue FALLO"  FALLO SEO-04 \
       perl $QA "https://tienda.example/ficha.html?sku=ESP-60" --repo fixtures-seo04/canonical-con-comentario --candidato --una-sola --solo seo --sin-recibo
# 🔴 CONTROL NEGATIVO: en una web SIN duplicados de fichero no cambia nada.
texto  "site-c · sin ficheros repetidos, no deduplica nada"  NO "documentos distintos (" \
       perl $QA http://site-c.example/ --solo seo --cache "$CACHE"

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
espera "site-c · sigue detectando su salto real"       PASA  A11Y-02 perl $QA http://site-c.example/ --solo a11y --una-sola --cache "$CACHE"
espera "site-a · sigue detectando su salto real"       PASA  A11Y-02 perl $QA http://site-a.example/ --solo a11y --una-sola --cache "$CACHE"
espera "bc · sigue detectando su salto real"         PASA  A11Y-02 perl $QA http://site-d.example/ --solo a11y --una-sola --cache "$CACHE"
espera "cm · no lo tiene: SIGUE acusada"             FALLO A11Y-02 perl $QA http://cm.example/ --solo a11y --una-sola --cache "$CACHE"
espera "site-b · no lo tiene: SIGUE acusada"        FALLO A11Y-02 perl $QA http://shop.site-b.example/ --solo a11y --una-sola --cache "$CACHE"

echo
echo "== ARREGLO P4 · UN VECTOR NO TIENE RESOLUCION: NO SE MIDE EN B/px"
#  cm declara meta.svg (738 B), googleads.svg (755 B) y ga4.svg (404 B) a 18x18,
#  y REN-02 los acusaba de «sobredimensionados» por 2,278 / 2,330 / 1,247 B/px,
#  mandando «reencodear a WebP» un logo vectorial. Bytes verificados con curl.
texto  "cm · ya NO acusa a meta.svg por B/px"         NO "meta.svg" \
       perl $QA http://cm.example/ --solo rendimiento --cache "$CACHE"
texto  "cm · ya NO acusa a googleads.svg por B/px"    NO "googleads.svg" \
       perl $QA http://cm.example/ --solo rendimiento --cache "$CACHE"
espera "cm · los SVG se vigilan por PESO, y pasan"    PASA REN-02b perl $QA http://cm.example/ --solo rendimiento --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: el check de B/px NO se ha desactivado. El logo BITMAP de
#    site-a (1080x1080 en un hueco de 40x40) sigue siendo FALLO.
espera "site-a · el PNG sobredimensionado sigue FALLANDO" FALLO REN-02 perl $QA http://site-a.example/ --solo rendimiento --una-sola --cache "$CACHE"
texto  "site-a · y lo sigue diciendo en B/px"           SI "B/px" \
       perl $QA http://site-a.example/ --solo rendimiento --una-sola --cache "$CACHE"

echo
echo "== ARREGLO P5 · EL ALCANCE SE EMITE Y EL DENOMINADOR ES EL SITIO"
texto  "el denominador ya NO es la lista auditada"    SI "denominador: el SITIO" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "y dice cuantas de la lista, aparte"           SI "de la lista auditada)" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
# 🔴 CONTROL NEGATIVO: «TODAS» solo puede salir si de verdad se han mirado
#    todas las del SITIO. En site-b se miran 11 de 67: no puede aparecer.
texto  "site-b · 11 de 67: NO dice «TODAS»"          NO "· TODAS" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "y cuando no sabe el total del sitio, lo DICE" SI "no se cuantas paginas tiene el sitio" \
       perl $QA https://climentmedia.com/ --sin-red --sin-recibo
# 🔴 EL RECIBO. Antes decia SIEMPRE «ALCANCE: NO DECLARADO».
#    Sin captura de site-c no hay nada que declarar: medido el 21-sep, el
#    recibo sale con «ALCANCE: NO DECLARADO» y los tres casos en MAL, por lo
#    que falta y no por el gate. Por eso el bloque se clasifica entero. Y el
#    recibo de una corrida vieja se borra antes: si el fichero FALTARA, el
#    tercer caso («ya no dice NO DECLARADO») saldria OK sin haber mirado nada.
rm -f "$CACHE/recibo-alcance"
if mide_bloque "el recibo declara su alcance" http://site-c.example/ --cache "$CACHE"; then
  RREPO="$CACHE/repo-alcance"; mkdir -p "$RREPO"; printf '<!doctype html><title>x</title>\n' > "$RREPO/index.html"
  perl $QA http://site-c.example/ --solo seo --una-sola --repo "$RREPO" --recibo "$CACHE/recibo-alcance" --cache "$CACHE" >/dev/null 2>&1
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
fi

echo
echo "== CERO PAGINAS LEIDAS ES «NO VERIFICADO», NUNCA «PASA»"
#  Lo destapo el propio arreglo 0.3: al agregar sobre @PAGES con un `next` por
#  cada pagina ilegible, una lente sobre CERO paginas salia entera en verde.
espera "sin red · la lente de a11y NO sale por PASA"   NOVERIF A11Y-00 perl $QA https://climentmedia.com/ --sin-red --sin-recibo
espera "sin red · dice cuales no ha podido leer"       NOVERIF A11Y-0x perl $QA https://climentmedia.com/ --sin-red --sin-recibo
espera "sin red · la de rendimiento tampoco"           NOVERIF REN-00  perl $QA https://climentmedia.com/ --sin-red --sin-recibo
espera "sin red · ni la de estructura"                 NOVERIF EST-01  perl $QA https://climentmedia.com/ --sin-red --sin-recibo
# 🔴 CONTROL NEGATIVO: con red, ninguno de esos avisos aparece.
espera "con red · A11Y-00 no existe"                   AUSENTE A11Y-00 perl $QA http://cm.example/ --solo a11y --una-sola --cache "$CACHE"
espera "con red · A11Y-0x no existe"                   AUSENTE A11Y-0x perl $QA http://cm.example/ --solo a11y --una-sola --cache "$CACHE"
# 🔴 22-sep-2026 · LA LENTE SEO NO TENIA ESTA GUARDA, y MED-01 tampoco. Con
#   --sin-red la SEO firmaba trece PASA sin haber leido nada (y SEO-15/16 FALLO
#   sin haber pedido robots ni sitemap), y MED-01 decia «sin medicion ninguna».
espera "sin red · ni la de SEO"                        NOVERIF SEO-00  perl $QA https://climentmedia.com/ --sin-red --sin-recibo
espera "sin red · MED-01 no afirma «sin medicion»"     NOVERIF MED-01  perl $QA https://climentmedia.com/ --sin-red --sin-recibo
#   Y CON RED TAMBIEN SE LEEN CERO PAGINAS: una home que responde 404 CON
#   CUERPO no apaga $NET_OK -la red contesta-, y ahi la SEO salia en verde:
#   quince PASA, «SEO-02 · 0 documentos distintos», exit 0. sin-home.example no
#   tiene index.html; su raiz sirve su 404.html. Los seis que arreglan algo -los
#   dos de sin red y estos cuatro- se vieron en ROJO contra el gate anterior
#   (AUSENTE, AVISO · AUSENTE, PASA, AVISO, AUSENTE).
espera "home en 404 · la de SEO NO sale por PASA"      NOVERIF SEO-00  perl $QA http://sin-home.example/ --solo seo --una-sola --cache "$CACHE"
espera "home en 404 · SEO-02 no aprueba 0 documentos"  AUSENTE SEO-02  perl $QA http://sin-home.example/ --solo seo --una-sola --cache "$CACHE"
espera "home en 404 · MED-01 no afirma «sin medicion»" NOVERIF MED-01  perl $QA http://sin-home.example/ --solo medicion --una-sola --cache "$CACHE"
espera "home en 404 · dice cual no ha podido leer"     NOVERIF SEO-0x  perl $QA http://sin-home.example/ --solo seo --cache "$CACHE"
# 🔴 CONTROLES NEGATIVOS. La 404 NO es «sin red»: con el sitemap expandido la
#   otra pagina SI se lee y su defecto tiene que seguir saliendo. Y con una
#   home legible ni SEO-00 ni SEO-0x existen, y MED-01 sigue midiendo. Cada uno
#   se vio en ROJO contra una copia del gate con la guarda disparando siempre
#   (SEO-0x, contra una que daba por ilegible toda pagina).
espera "home en 404 · la otra pagina SI se mide"       FALLO   SEO-03  perl $QA http://sin-home.example/ --solo seo --cache "$CACHE"
espera "con red · SEO-00 no existe"                    AUSENTE SEO-00  perl $QA http://cm.example/ --solo seo --una-sola --cache "$CACHE"
espera "con red · SEO-0x no existe"                    AUSENTE SEO-0x  perl $QA http://cm.example/ --solo seo --una-sola --cache "$CACHE"
espera "con red · MED-01 sigue midiendo"               AVISO   MED-01  perl $QA http://cm.example/ --solo medicion --una-sola --cache "$CACHE"

echo
echo "== ARREGLO 0.3 · LA LOTERIA DEL ORDEN"
#  Las MISMAS dos URLs, solo cambia el orden. Antes: A11Y-08 FALLO / PASA.
#  🔴 Sin captura de site-c los dos veredictos salen VACIOS, el diff los da por
#     iguales y el primer caso salia OK. Se clasifican los tres juntos: el
#     negativo de abajo lee los mismos ficheros.
rm -f "$CACHE"/ord-A.txt "$CACHE"/ord-B.txt "$CACHE"/ord-A.veredictos "$CACHE"/ord-B.veredictos
if mide_bloque "la loteria del orden" http://site-c.example/ --cache "$CACHE"; then
  printf 'http://site-c.example/\nhttp://site-c.example/tarot-del-amor\n' > "$CACHE/ord-A.txt"
  printf 'http://site-c.example/tarot-del-amor\nhttp://site-c.example/\n' > "$CACHE/ord-B.txt"
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
  # 🔴 CONTROL NEGATIVO: que coincidan no puede ser por haberse callado. El fallo
  #    real de jerarquia de la home tiene que seguir ahi en LOS DOS ordenes.
  for o in A B; do
    if grep -qE '^\s+\[FALLO   \] A11Y-08' "$CACHE/ord-$o.veredictos"; then
      printf '  OK    %-46s orden %s -> A11Y-08 FALLO\n' "el fallo real sigue vivo, no se ha apagado" "$o"; ok=$((ok+1))
    else
      printf '  MAL   %-46s orden %s: A11Y-08 ya no falla\n' "el fallo real sigue vivo, no se ha apagado" "$o"; ko=$((ko+1))
    fi
  done
fi

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
espera "candidato · G11 no se mide contra si mismo"    NOVERIF EST-09 perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo estructura --sin-recibo
espera "candidato · la compresion es del host"         NOVERIF REN-08 perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo rendimiento --sin-recibo
espera "candidato · Cache-Control es del host"         NOVERIF REN-09 perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo rendimiento --sin-recibo
espera "candidato · el ESTADO 404 es del host"         NOVERIF EST-03 perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo estructura --sin-recibo
# 🔴 CONTROLES NEGATIVOS: los mismos checks contra PRODUCCION siguen midiendo.
#    Sin esto, «NO VERIFICADO en candidato» podria ser un check apagado del todo.
espera "produccion · REN-08 sigue midiendo y pasa"     PASA  REN-08 perl $QA http://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"
espera "produccion · EST-09 sigue cazando el desfase"  FALLO EST-09 perl $QA http://site-d.example/ --repo "$BCREPO" --solo estructura --sin-recibo --cache "$CACHE"
espera "EST-03 sigue cazando un 404 callejon" FALLO EST-03 perl $QA $U404 --solo estructura --una-sola

# --- 2 · el candidato VE los arreglos que produccion todavia no tiene --------
#     Verificado a mano el 11-ago: el repo declara --primary oklch(0.54 ...) y
#     produccion sirve oklch(0.58 ...); el repo trae favicon.svg (262 B) y
#     produccion devuelve HTTP 404 en /favicon.svg.
espera "candidato · la paleta del repo YA llega a AA"  PASA  A11Y-03 perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo a11y --sin-recibo
espera "produccion · la paleta subida sigue por debajo" FALLO A11Y-03 perl $QA http://site-d.example/ --solo a11y --una-sola --cache "$CACHE"
espera "candidato · el favicon del repo existe"        PASA  REN-07 perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo rendimiento --sin-recibo
espera "produccion · el favicon subido sigue en 404"   FALLO REN-07 perl $QA http://site-d.example/ --solo rendimiento --una-sola --cache "$CACHE"

# --- 3 · el informe dice CONTRA QUE se midio --------------------------------
texto  "el informe declara que mide el CANDIDATO"    SI "MEDIDO       🔴 CANDIDATO" \
       perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo seo --sin-recibo
texto  "y enumera lo que no ha podido medir"         SI "LO QUE EL CANDIDATO NO PUEDE MEDIR" \
       perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --solo estructura --sin-recibo
# 🔴 CONTROL NEGATIVO: midiendo produccion NO puede decir que mide el candidato.
texto  "produccion NO se hace pasar por candidato"   NO "MEDIDO       🔴 CANDIDATO" \
       perl $QA http://site-d.example/ --solo seo --una-sola --cache "$CACHE"
texto  "produccion lo dice tambien, con su aviso"    SI "MEDIDO       PRODUCCION" \
       perl $QA http://site-d.example/ --solo seo --una-sola --cache "$CACHE"

# --- 4 · 🔴 EL CONTROL NEGATIVO DE VERDAD: UN ARBOL ROTO NO SACA VERDE ------
#     Se rompe una COPIA (nunca el repo real): se quita el <h1> de la home.
if mide_bloque "el arbol roto no saca verde (copia)" "$BCREPO"; then
  ROTO="$CACHE/bc-roto"
  rm -rf "$ROTO"
  if cp -r "$BCREPO" "$ROTO" 2>/dev/null; then
    rm -f "$ROTO/.qa-recibo"
    perl -i -pe 's{<h1([^>]*)>(.*?)</h1>}{<p$1>$2</p>}' "$ROTO/index.html"
    if grep -q '<h1' "$ROTO/index.html"; then
      printf '  MAL   %-46s la copia sigue teniendo <h1>: la prueba no probaria nada\n' "preparar el arbol roto"; ko=$((ko+1))
    else
      printf '  OK    %-46s <h1> fuera de la home de la copia\n' "preparar el arbol roto"; ok=$((ok+1))
      espera "roto · el candidato LO CAZA"            FALLO SEO-09 perl $QA http://site-d.example/ --repo "$ROTO" --candidato --una-sola --solo seo --sin-recibo
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
      espera "roto · SEO-14 NO se apunta el tanto de SEO-09" PASA SEO-14 perl $QA http://site-d.example/ --repo "$ROTO" --candidato --una-sola --solo seo --sin-recibo
      # 🔴 LA OTRA MITAD DEL FALLO, EN UNA LINEA: el MISMO arbol roto, medido
      #    contra produccion, saca PASA en el mismo check. Este caso tiene que
      #    seguir saliendo PASA: es la prueba de que sin --candidato el recibo
      #    no dice nada del arbol que sella.
      espera "roto · midiendo PRODUCCION el defecto NO existe" PASA SEO-09 perl $QA http://site-d.example/ --repo "$ROTO" --solo seo --una-sola --sin-recibo --cache "$CACHE"
    fi
  else
    printf '  MAL   %-46s no he podido copiar %s\n' "preparar el arbol roto" "$BCREPO"; ko=$((ko+1))
  fi
  rm -rf "$ROTO"
fi

# --- 5 · el RECIBO dice contra que se midio ---------------------------------
#     Dos mitades con dependencias distintas: la del candidato solo necesita el
#     repo; la de produccion, ademas, la captura de site-d. Y el recibo de una
#     corrida vieja se borra: «el SITIO no es 127.0.0.1» salia OK sin recibo.
rm -f "$CACHE/recibo-candidato" "$CACHE/recibo-produccion"
if mide_bloque "el recibo de candidato dice contra que midio" "$BCREPO"; then
  RC="$CACHE/recibo-candidato"
  perl $QA http://site-d.example/ --repo "$BCREPO" --candidato --una-sola --recibo "$RC" >/dev/null 2>&1
  for par in "MEDIDO-CONTRA: CANDIDATO|el recibo dice que midio el CANDIDATO" \
             "SITIO: http://site-d.example|el SITIO sigue siendo el dominio real" \
             "NV-POR-CANDIDATO:|separa los NV que contesta G11"; do
    lit="${par%%|*}"; eti="${par#*|}"
    if grep -q "^$lit" "$RC" 2>/dev/null; then
      printf '  OK    %-46s %s\n' "$eti" "$(grep -m1 "^$lit" "$RC")"; ok=$((ok+1))
    else
      printf '  MAL   %-46s falta la linea «%s»\n' "$eti" "$lit"; ko=$((ko+1))
    fi
  done
  # 🔴 CONTROL NEGATIVO: el SITIO del recibo NUNCA puede ser el localhost donde
  #    se midio. Lo compara deploy.sh, y un recibo apuntando a 127.0.0.1
  #    haria que G11 midiera el servidor de pruebas en vez de la web.
  if grep -q '^SITIO:.*127\.0\.0\.1' "$RC" 2>/dev/null; then
    printf '  MAL   %-46s el SITIO se ha contaminado con el localhost\n' "el SITIO no es 127.0.0.1"; ko=$((ko+1))
  else
    printf '  OK    %-46s NO\n' "el SITIO no es 127.0.0.1"; ok=$((ok+1))
  fi
fi
# y el de PRODUCCION se declara como tal
if mide_bloque "el recibo de produccion se declara" http://site-d.example/ --repo "$BCREPO" --cache "$CACHE"; then
  RP="$CACHE/recibo-produccion"
  perl $QA http://site-d.example/ --repo "$BCREPO" --una-sola --recibo "$RP" --cache "$CACHE" >/dev/null 2>&1
  if grep -q '^MEDIDO-CONTRA: PRODUCCION' "$RP" 2>/dev/null; then
    printf '  OK    %-46s %s\n' "el recibo de produccion se declara" "$(grep -m1 '^MEDIDO-CONTRA:' "$RP")"; ok=$((ok+1))
  else
    printf '  MAL   %-46s no dice MEDIDO-CONTRA: PRODUCCION\n' "el recibo de produccion se declara"; ko=$((ko+1))
  fi
fi

# --- 6 · las guardas de --candidato -----------------------------------------
#     «No se pudo correr» sale en 2, nunca en 0. Un modo que no arranca y un
#     modo que arranca y aprueba NO se pueden ver igual desde un script.
{
  out="$(perl $QA http://site-d.example/ --candidato 2>&1)"; rc=$?
  if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q -- '--candidato necesita --repo'; then
    printf '  OK    %-46s exit 2 y lo dice\n' "--candidato sin --repo no arranca"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s\n' "--candidato sin --repo no arranca" "$rc"; ko=$((ko+1))
  fi
  # 🔴 21-sep-2026 · ESTE CASO PASABA POR EL MOTIVO EQUIVOCADO. Apuntaba a
  #    "$BCREPO", y sin ese repo el gate sale 2 por la guarda de ANTES («necesita
  #    --repo DIR»), sin llegar a la de --sin-red, que es la que el caso dice
  #    probar. Medido: exit 2 con el mensaje del repo. Ahora el repo es una
  #    fixture que existe, y se exige el mensaje de ESTA guarda, no solo el 2.
  out="$(perl $QA http://site-d.example/ --repo fixtures-lenses/seo-bueno --candidato --sin-red 2>&1)"; rc=$?
  if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q -- '--candidato y --sin-red se excluyen'; then
    printf '  OK    %-46s exit 2 y lo dice\n' "--candidato con --sin-red no arranca"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s (deberia ser 2, por --sin-red)\n' "--candidato con --sin-red no arranca" "$rc"; ko=$((ko+1))
  fi
}

# --- 7 · LA PUERTA · acepta el candidato Y SIGUE EXIGIENDO G11 --------------
#     Fixture entera: un repo de dos ficheros, su recibo escrito por el propio
#     receipt.pl a partir de un JSON, y un servidor de mentira para el G11.
#     NADA de esto toca una web viva: SITIO es 127.0.0.1 y SUBIDA es un `echo`.
#  🔴 21-sep-2026 · LLAMABA A ../desplegar.sh, QUE NO EXISTE DESDE EL 25-ago (la
#     puerta paso a llamarse deploy.sh al unificar la skill con este repo). Los
#     cuatro casos daban exit 127 y nadie lo vio: vivian debajo de la salida
#     anticipada. Mismas opciones (--subir, --servido) y mismos mensajes en
#     deploy.sh y receipt.pl, comprobado antes de cambiar la ruta.
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
  # 🔴 21-sep-2026 · DESDE 14bed08 EL PASO 6 DE LA PUERTA LEE EL HOST DE MEDIDA DE
  #    LA MAQUINA (config/nav-host.local.conf). Sin aislarlo, este fixture servido
  #    en 127.0.0.1 se mandaria a medir por ssh al host real de quien corra el
  #    banco: sale en 0 igual -el paso 6 va despues del PASA-, asi que ningun caso
  #    se pondria rojo, y el banco dependeria de la maquina sin decirlo. Se aisla
  #    igual que receipt-tests/tests-door.sh: sin NAV_HOST y con un fichero que
  #    no existe. El paso 6 dice entonces «NO MEDIDO: NAV_HOST sin configurar».
  NAVAIS="$CACHE/no-hay-nav-host.conf"; rm -f "$NAVAIS"

  salida="$(NAV_HOST= BROWSER_HOST= NAV_HOST_CONF="$NAVAIS" bash ../deploy.sh "$RV" 2>&1)"; rc=$?
  if [ "$rc" = 0 ] && printf '%s' "$salida" | grep -q 'medido contra: CANDIDATO'; then
    printf '  OK    %-46s el gate acepta el recibo de candidato\n' "deploy.sh · recibo de CANDIDATO vale"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s\n' "deploy.sh · recibo de CANDIDATO vale" "$rc"; ko=$((ko+1))
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
  salida="$(NAV_HOST= BROWSER_HOST= NAV_HOST_CONF="$NAVAIS" bash ../deploy.sh "$RV" --subir 2>&1)"; rc=$?
  # 🔴 6-nov · desde de6af6c la puerta ya no dice «desplegado y verificado contra
  #    el recibo» (lo decia con paginas de la subida en 404): G11 dice lo suyo y el
  #    veredicto de la subida es el CIERRE. Este caso esperaba la frase vieja.
  if [ "$rc" = 0 ] && printf '%s' "$salida" | grep -q 'G11 · PASA: lo del recibo se sirve' \
     && printf '%s' "$salida" | grep -q 'Los dos momentos cerrados'; then
    printf '  OK    %-46s candidato -> subir -> G11 verde\n' "los DOS momentos, de punta a punta"; ok=$((ok+1))
  else
    printf '  MAL   %-46s exit %s\n' "los DOS momentos, de punta a punta" "$rc"; ko=$((ko+1))
    printf '%s\n' "$salida" | tail -8 | sed 's/^/          /'
  fi
  # 🔴 26-sep-2026 · la puerta decia «Las N que el candidato no podia medir (...)
  #    ya tienen respuesta», con EST-03 dentro, y G11 no preguntaba por la 404
  #    del host. Ahora dice que ha contestado G11 LEYENDOLO DE G11. Este arbol no
  #    trae 404.html, asi que EST-03 NO puede salir como contestada.
  if printf '%s' "$salida" | grep -q 'G11 acaba de contestar: EST-09$' \
     && printf '%s' "$salida" | grep -q 'Y NO ha contestado: REN-08 REN-09 EST-03\.$'; then
    printf '  OK    %-46s EST-09 si, EST-03 no (no hay 404.html)\n' "la puerta dice lo que G11 ha contestado"; ok=$((ok+1))
  else
    printf '  MAL   %-46s\n' "la puerta dice lo que G11 ha contestado"; ko=$((ko+1))
    printf '%s\n' "$salida" | grep -n 'contestar\|contestado' | sed 's/^/          /'
  fi
  # 🔴 CONTROL NEGATIVO: si lo servido NO es lo del recibo, G11 tiene que
  #    seguir cerrando la puerta. Un recibo de candidato NO exime de G11: esa
  #    es la mitad de todo el arreglo.
  printf ':root{--a:#fff} /* lo servido ya no es lo medido */\n' > "$RV/styles.css.bak"
  mv "$RV/styles.css" "$RV/styles.css.medido"; mv "$RV/styles.css.bak" "$RV/styles.css"
  salida="$(NAV_HOST= BROWSER_HOST= NAV_HOST_CONF="$NAVAIS" bash ../deploy.sh "$RV" --servido 2>&1)"; rc=$?
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
KREPO="$REPOS/site-a-web"
KURL="http://site-a.example"
# Sin el repo, las copias no se hacian y el bloque imprimia MAL «no se pudo
# copiar el repo»: un rojo por algo que este checkout no tiene, no por el gate.
if mide_bloque "falsos positivos de site-a (copias del repo)" "$KREPO"; then

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
  # 🔴 5-nov-2026 · Este caso pedia AUSENTE: el banco fijaba el silencio. Con todo
  #    cerrado MED-12 no decia nada, y una web lo leyo al subir como «nadie lo mide».
  espera "MED-12 · en produccion, todo cerrado: PASA"      PASA MED-12 \
         perl $QA "$KURL/" --solo medicion --cache "$CACHE"
  texto  "MED-12 · y dice cuantas y con que codigo"        SI "11 de 11 cerradas: /_leads/ 404" \
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
fi

echo
echo "== ACEPTADO · el silenciador, y las cerraduras que lleva (11-ago-2026)"
#  🔴 Un silenciador SIN pruebas no deberia existir. Estos casos no comprueban
#     que sepa ACEPTAR —eso es lo facil y se ve a simple vista—: comprueban que
#     se NIEGUE. Seis de los ocho son controles NEGATIVOS a proposito, porque el
#     modo de fallo de esta funcion no es «no acepta», es «acepta de mas».
#  ⚠️ Fixture entera dentro de $CACHE: NO toca el repo de ninguna web viva, y
#     todo va con --sin-recibo salvo el caso que comprueba el recibo, que
#     escribe en $CACHE y no en el repo.
#  🔴 21-sep-2026 · EL REPO ES SINTETICO, PERO EL HALLAZGO QUE SE ACEPTA NO: es
#     el FALLO MED-07 que da PRODUCCION de site-d, asi que el bloque entero
#     necesita esa captura. Sin ella, los 14 salian MAL. Se clasifica entero.
if mide_bloque "ACEPTADO: el silenciador y sus cerraduras" http://site-d.example/ --cache "$CACHE"; then
  RA="$CACHE/repo-aceptado"; rm -rf "$RA"; mkdir -p "$RA/_deploy"
  printf '<!doctype html><html lang="es"><head><title>x</title></head><body><main><h1>x</h1></main></body></html>\n' > "$RA/index.html"
  BCQA="perl $QA http://site-d.example/ --repo $RA --solo medicion --contenedor fixtures-sites/site-d.example/_gtm.js --sin-recibo --cache $CACHE"

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
      # 🔴 6-nov-2026 · LA FECHA POR DEFECTO ES HOY. Era 2026-08-11 escrita a mano, y sin
      #    HASTA una aceptacion vale 90 dias: el 10-nov los casos 1, 7, 7-bis y 8 de este
      #    bloque habrian salido MAL a la vez, sin que cambiara nada del gate (una fecha
      #    escrita en un test es una mecha). Los casos que necesitan una fecha concreta
      #    (la caducada, el tope) la siguen pasando.
      echo "FECHA:    ${2:-$(date +%Y-%m-%d)}"
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
    echo "HALLAZGO: DONDE=http://site-d.example/politica-cookies"
    echo "MOTIVO:   El cliente dice que su abogado la esta revisando."
    echo "ACEPTA:   Manuel Climent"
    echo "FECHA:    2026-08-11"
  } >> "$RA/_deploy/aceptado.conf"
  espera "PROHIBIDO (politica en borrador) · no se puede" FALLO  MED-08 $BCQA -q
  espera "y la entrada legitima del mismo fichero SI"     ACEPTADO MED-07 $BCQA -q
  texto "y dice que no es aceptable, no que falte algo"   SI "NO ES ACEPTABLE" $BCQA -q

  # 7-bis · 26-sep-2026 · EL NOMBRE EN INGLES. La documentacion publica manda
  #     escribir `_deploy/accepted.conf`, y hasta hoy solo se leia `aceptado.conf`:
  #     la aceptacion firmada no surtia efecto y el FALLO seguia contando.
  conf "$H"; mv "$RA/_deploy/aceptado.conf" "$RA/_deploy/accepted.conf"
  espera "accepted.conf (el nombre en ingles) tambien vale" ACEPTADO MED-07 $BCQA -q
  # 7-ter · 28-oct-2026 · Y LOS CAMPOS EN INGLES. config/accepted.conf.example
  #     (publico) escribe [ACCEPTED], FINDING, REASON, ACCEPTS, DATE y UNTIL, y el
  #     lector solo conocia los nombres en castellano: siguiendo el ejemplo, la
  #     entrada salia rechazada por «faltan campos» y el FALLO seguia contando.
  { echo "[ACCEPTED]"
    echo "CHECK:     MED-07"
    echo "FINDING:   $H"
    echo "REASON:    Client legal copy: proposed, never invented."
    echo "ACCEPTS:   Firstname Lastname"
    echo "DATE:      $(date +%Y-%m-%d)"
  } > "$RA/_deploy/accepted.conf"
  espera "campos en ingles (los del ejemplo publico) valen" ACEPTADO MED-07 $BCQA -q
  rm -f "$RA/_deploy/accepted.conf"

  # 8 · el recibo lo lleva dentro, bajo el SELLO
  conf "$H"
  RAC="$CACHE/recibo-aceptado"
  perl $QA http://site-d.example/ --repo "$RA" --solo medicion --contenedor fixtures-sites/site-d.example/_gtm.js --recibo "$RAC" --cache "$CACHE" >/dev/null 2>&1
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
fi

echo
echo "== MEDIDO A MANO · los siete que ningun script mide, firmados y con fecha (28-oct-2026)"
#  🔴 POR QUE: SEO-17, A11Y-13, A11Y-14, MED-13, MED-14, EST-08 y EST-12f salian
#     NO VERIFICADO siempre, y toda subida de toda web necesitaba --aun-asi.
#     Como ACEPTADO, esto es un silenciador: la mayoria de los casos son
#     NEGATIVOS, porque el modo de fallo no es «no lo cuenta», es «lo cuenta de mas».
#  Misma fixture que ACEPTADO: site-d en PRODUCCION sintetica, repo en $CACHE.
if mide_bloque "MEDIDO A MANO: las siete y sus cerraduras" http://site-d.example/ --cache "$CACHE"; then
  RM="$CACHE/repo-medido"; rm -rf "$RM"; mkdir -p "$RM/_deploy"
  printf '<!doctype html><html lang="es"><head><title>x</title></head><body><main><h1>x</h1></main></body></html>\n' > "$RM/index.html"
  MQA="perl $QA http://site-d.example/ --repo $RM --solo medicion --contenedor fixtures-sites/site-d.example/_gtm.js --sin-recibo --cache $CACHE"
  SQA="perl $QA http://site-d.example/ --repo $RM --solo seo --sin-recibo --cache $CACHE"
  # med <CHECK> <RESULTADO> <FECHA> [<campo extra>]  ·  escribe UNA entrada
  med() {
    { echo "[MEDIDO]"
      echo "CHECK:     $1"
      echo "RESULTADO: $2"
      echo "COMO:      rama de Rechazar abierta en el panel, cookies y dataLayer mirados"
      [ "${4:-}" = "sin-mide" ] || echo "MIDE:      banco de pruebas"
      echo "FECHA:     $3"
      case "${4:-}" in HASTA) echo "HASTA:     2026-12-31" ;; DATO=*) echo "DATO:      ${4#DATO=}" ;; esac
    } > "$RM/_deploy/measured.conf"
  }
  HOY="$(date +%Y-%m-%d)"

  # 0 · sin fichero: sigue NO VERIFICADO, y el informe dice como cerrarlo
  rm -f "$RM/_deploy/measured.conf"
  espera "sin fichero · sigue sin verificar"            NOVERIF MED-14 $MQA -q
  texto  "y dice que se miden a mano y donde se firman" SI "NO LOS PUEDE MEDIR NINGUN SCRIPT" $MQA -q
  # 1 · POSITIVO · entrada completa y de hoy: pasa a la casilla declarada
  med MED-14 PASA "$HOY"
  espera "medida completa · PASA declarado"             PASA    MED-14 $MQA
  texto  "y el informe la firma"                        SI "MEDIDO A MANO: 1" $MQA -q
  # 2 · un FALLO declarado es un FALLO: bloquea igual
  med MED-13 FALLO "$HOY"
  espera "FALLO declarado · bloquea"                    FALLO   MED-13 $MQA -q
  # 3 · NEGATIVO · un check que el gate SI mide no se puede declarar medido
  med MED-07 PASA "$HOY"
  espera "MED-07 (lo mide el gate) · sigue en FALLO"    FALLO   MED-07 $MQA -q
  texto  "y dice que no es de los siete"                SI "no se puede declarar medido a mano" $MQA -q
  # 4 · NEGATIVO · falta quien mide
  med MED-14 PASA "$HOY" sin-mide
  espera "sin MIDE · NO vale"                           NOVERIF MED-14 $MQA -q
  texto  "y dice que falta"                             SI "faltan campos obligatorios: MIDE" $MQA -q
  # 5 · NEGATIVO · caducada (90 dias desde FECHA)
  med MED-14 PASA "2026-01-01"
  espera "medida CADUCADA · vuelve a sin verificar"     NOVERIF MED-14 $MQA -q
  texto  "y lo dice con su fecha"                       SI "CADUCADA el 2026-04-01" $MQA -q
  # 6 · NEGATIVO · FECHA futura
  med MED-14 PASA "2099-01-01"
  espera "FECHA futura · NO vale"                       NOVERIF MED-14 $MQA -q
  # 7 · NEGATIVO · HASTA no se puede poner para estirarla
  med MED-14 PASA "$HOY" HASTA
  espera "con HASTA · NO vale"                          NOVERIF MED-14 $MQA -q
  # 8 · NEGATIVO · RESULTADO que no es PASA/AVISO/FALLO
  med MED-14 "BIEN" "$HOY"
  espera "RESULTADO inventado · NO vale"                NOVERIF MED-14 $MQA -q
  # 9 · ATADA AL DATO: SEO-17 trae dato; firmado sobre otro, no vale
  rm -f "$RM/_deploy/measured.conf"
  D17="$($SQA -q 2>&1 | grep -m1 -E '^[[:space:]]+SEO-17[[:space:]]+DATO: ' | sed -E 's/^[[:space:]]+SEO-17[[:space:]]+DATO: //')"
  if [ -n "$D17" ]; then
    printf '  OK    %-46s %s\n' "el informe imprime el DATO de SEO-17" "$D17"; ok=$((ok+1))
    med SEO-17 PASA "$HOY" "DATO=hay etiquetas hreflang de otra web"
    espera "DATO distinto · NO vale"                    NOVERIF SEO-17 $SQA -q
    texto  "y dice que hay que volver a medir"          SI "DATO distinto" $SQA -q
    med SEO-17 PASA "$HOY" "DATO=$D17"
    espera "DATO el de hoy · PASA declarado"            PASA    SEO-17 $SQA
  else
    printf '  MAL   %-46s no hay linea DATO de SEO-17\n' "el informe imprime el DATO de SEO-17"; ko=$((ko+1))
  fi
  # 9-bis · 🔴 5-nov-2026 · LA OCTAVA, A11Y-03b (contraste en hover y focus): el
  #    gate lee la hoja y no la pinta, y no habia forma de firmarlo: toda subida
  #    pedia --aun-asi. Atada a su DATO (cuantas reglas), como SEO-17. Con el
  #    programa de antes el positivo salia NO VERIFICADO.
  rm -f "$RM/_deploy/measured.conf"
  AQA="perl $QA http://site-a.example/ --repo $RM --solo a11y --sin-recibo --cache $CACHE"
  D03="$($AQA -q 2>&1 | grep -m1 -E '^[[:space:]]+A11Y-03b[[:space:]]+DATO: ' | sed -E 's/^[[:space:]]+A11Y-03b[[:space:]]+DATO: //')"
  if [ -n "$D03" ]; then
    printf '  OK    %-46s %s\n' "el informe imprime el DATO de A11Y-03b" "$D03"; ok=$((ok+1))
    med A11Y-03b PASA "$HOY" "DATO=999 reglas"
    espera "A11Y-03b · DATO distinto · NO vale"         NOVERIF A11Y-03b $AQA -q
    med A11Y-03b PASA "$HOY" "DATO=$D03"
    espera "A11Y-03b · DATO el de hoy · PASA declarado" PASA    A11Y-03b $AQA
  else
    printf '  MAL   %-46s no hay linea DATO de A11Y-03b\n' "el informe imprime el DATO de A11Y-03b"; ko=$((ko+1))
  fi
  # 9-ter · 🔴 6-nov-2026 · D-063 · MED-13 EN UNA WEB SIN ADS. El umbral pedia una conversion en
  #    Ads, y una web sin campañas no la tiene nunca: tres webs paradas sin firma honesta. Con
  #    SIN_ADS en deploy.conf (y un arbol sin etiqueta de Ads) se mide en GA4, y la firma va atada
  #    a ese DATO: el dia que se quita SIN_ADS, deja de valer sola. Con el programa de antes, el
  #    informe no habla de GA4 ni trae DATO, y la firma de GA4 seguia valiendo sin SIN_ADS.
  rm -f "$RM/_deploy/measured.conf"
  printf '# una web sin campañas\nSIN_ADS="sin campañas hasta el encendido"   # D-063\n' > "$RM/_deploy/deploy.conf"
  texto  "SIN_ADS · MED-13 se mide en GA4"              SI "que el lead haya LLEGADO a GA4" $MQA -q
  D13="$($MQA -q 2>&1 | grep -m1 -E '^[[:space:]]+MED-13[[:space:]]+DATO: ' | sed -E 's/^[[:space:]]+MED-13[[:space:]]+DATO: //')"
  if [ "$D13" = "SIN_ADS: sin campañas hasta el encendido" ]; then
    printf '  OK    %-46s %s\n' "el informe imprime el DATO de MED-13" "$D13"; ok=$((ok+1))
  else
    printf '  MAL   %-46s salio «%s»\n' "el informe imprime el DATO de MED-13" "$D13"; ko=$((ko+1))
  fi
  med MED-13 PASA "$HOY" "DATO=SIN_ADS: sin campañas hasta el encendido"
  espera "SIN_ADS · firmado en GA4 con su DATO · PASA"  PASA    MED-13 $MQA
  # NEGATIVO · se enciende Ads y se quita SIN_ADS: la firma de GA4 ya no vale
  rm -f "$RM/_deploy/deploy.conf"
  espera "sin SIN_ADS · la firma de GA4 no vale"        NOVERIF MED-13 $MQA -q
  texto  "y dice por que"                               SI "DATO de otra situacion" $MQA -q
  # NEGATIVO · SIN_ADS con una etiqueta de Ads en el arbol: la declaracion no es verdad
  printf 'SIN_ADS="sin campañas"\n' > "$RM/_deploy/deploy.conf"
  printf '<!doctype html><html><head><script>gtag("config","AW-1234567")</script></head><body></body></html>\n' > "$RM/conversion.html"
  rm -f "$RM/_deploy/measured.conf"
  espera "SIN_ADS con AW- en el arbol · FALLO"          FALLO   MED-13 $MQA -q
  texto  "y nombra la pagina"                           SI "/conversion.html: AW-1234567" $MQA -q
  # y la misma etiqueta en un comentario no cuenta: sigue midiendose en GA4
  printf '<!doctype html><html><head><!-- gtag("config","AW-1234567") --></head><body></body></html>\n' > "$RM/conversion.html"
  texto  "AW- en un comentario · sigue en GA4"          SI "que el lead haya LLEGADO a GA4" $MQA -q
  rm -f "$RM/conversion.html" "$RM/_deploy/deploy.conf" "$RM/_deploy/measured.conf"
  # 10 · el nombre en castellano tambien vale
  med MED-14 PASA "$HOY"; mv "$RM/_deploy/measured.conf" "$RM/_deploy/medido.conf"
  espera "medido.conf (castellano) tambien vale"        PASA    MED-14 $MQA
  rm -f "$RM/_deploy/medido.conf"
  # 10-bis · los campos en ingles del ejemplo publico, con PASS en vez de PASA
  { echo "[MEASURED]"; echo "CHECK:        MED-14"; echo "RESULT:       PASS"
    echo "HOW:          pressed Reject, looked at cookies and dataLayer"
    echo "MEASURED-BY:  test bench"; echo "DATE:         $HOY"; } > "$RM/_deploy/measured.conf"
  espera "campos en ingles (ejemplo publico) valen"     PASA    MED-14 $MQA
  # 11 · el recibo la lleva, ya no la cuenta en SIN-MIRAR, y va BAJO el sello
  med MED-14 PASA "$HOY"
  RMC="$CACHE/recibo-medido"
  perl $QA http://site-d.example/ --repo "$RM" --solo medicion --contenedor fixtures-sites/site-d.example/_gtm.js --recibo "$RMC" --cache "$CACHE" >/dev/null 2>&1
  if grep -q '^MEDIDO-A-MANO: 1' "$RMC" 2>/dev/null && grep -q '^MEDIDO-001: MED-14 | PASA' "$RMC" 2>/dev/null \
     && ! grep -E '^SIN-MIRAR:' "$RMC" | grep -qw 'MED-14'; then
    printf '  OK    %-46s %s\n' "el recibo lleva la medida, fuera de SIN-MIRAR" "$(grep -m1 '^MEDIDO-001:' "$RMC" | cut -c1-40)"; ok=$((ok+1))
  else
    printf '  MAL   %-46s el recibo no la lleva o sigue en SIN-MIRAR\n' "el recibo lleva la medida, fuera de SIN-MIRAR"; ko=$((ko+1))
  fi
  perl -i -pe 's/^(MEDIDO-001: MED-14 \| )PASA/${1}FALLO/' "$RMC"
  if perl ../receipt.pl --verificar --repo "$RM" --recibo "$RMC" 2>&1 | grep -q 'el SELLO no cuadra'; then
    printf '  OK    %-46s cambiar el resultado rompe el sello\n' "la medida va BAJO el sello"; ok=$((ok+1))
  else
    printf '  MAL   %-46s se pudo cambiar el resultado a mano\n' "la medida va BAJO el sello"; ko=$((ko+1))
  fi
  rm -rf "$RM" "$RMC"
fi

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
        perl $QA http://site-d.example/ --solo rendimiento --sin-recibo -q --cache "$CACHE"
  texto "y el informe dice que la aceptacion es PARCIAL" SI "PARCIAL MUESTRA: se han mirado" \
        perl $QA http://site-d.example/ --solo rendimiento --sin-recibo -q --cache "$CACHE"
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
BCU="http://site-d.example/"

# --- el caso real que bloqueaba el despliegue de site-a ---
espera "SEO-14 · site-a /merci: corta y COMPLETA, pasa"   PASA  SEO-14 \
       perl $QA http://site-a.example/ --solo seo --gracias /merci --sin-recibo --cache "$CACHE"

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
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"
texto  "SEO-14 · y dice que la region esta VACIA"       SI "region de contenido servida esta VACIA" \
       perl $QA http://shop.site-b.example/ --solo seo --cache "$CACHE"

echo
echo "== EL TECHO DE --max-urls SE DECLARA · 11-ago-2026"
# 🔴 EL DEFECTO MEDIDO: site-d.example declara 40 URLs en su sitemap, el
#    tope por defecto mide 25, y A11Y-08 imprimia «DATO 25 de 25 paginas». «25
#    de 25» se lee como «todas». Las 15 que faltaban no aparecian en la linea
#    del check, y una aceptacion firmada sobre ese hallazgo se leia como una
#    decision sobre el sitio entero cubriendo el 62%.
texto  "TECHO · el bloque ALCANCE dice PARCIAL"          SI "· PARCIAL" \
       perl $QA http://site-d.example --solo a11y --cache "$CACHE"
texto  "TECHO · y con el denominador del SITIO"          SI "25 de 40 del sitio" \
       perl $QA http://site-d.example --solo a11y --cache "$CACHE"
texto  "TECHO · nombra el tope que recorto"              SI "tope --max-urls 25" \
       perl $QA http://site-d.example --solo a11y --cache "$CACHE"
# La huella de un check recortado tiene que llevar EVP (no EV): es lo que impide
# que una aceptacion tomada sobre 25 de 40 se presente como si cubriera 40.
texto  "TECHO · la huella de A11Y-08 lleva EVP, no EV"   SI "EVP=" \
       perl $QA http://site-d.example --solo a11y --cache "$CACHE"
# 🔴 LA FRONTERA · un sitio que se mide ENTERO no puede salir PARCIAL. Sin este
#    caso, «marcarlo todo PARCIAL siempre» pasaria por arreglo, y entonces la
#    palabra dejaria de significar nada —que es como muere un aviso—.
texto  "TECHO · un sitio medido ENTERO dice TODAS"       SI "· TODAS" \
       perl $QA http://site-a.example --solo a11y --cache "$CACHE"
texto  "TECHO · y ese NO declara recorte"                NO "TECHO: se han mirado" \
       perl $QA http://site-a.example --solo a11y --cache "$CACHE"

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
COL="$CACHE/colision"; rm -rf "$COL"; mkdir -p "$COL"   # DENTRO de la cache de la corrida: el trap la borra entera
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
# 🔴 22-sep-2026 · ESTE CASO PASABA GRACIAS AL DEFECTO QUE SE ARREGLO ESE DIA.
#     Solo se sembraba la clave CON barra, la de la home (fetch("$ROOT/")). La
#     lista normaliza la raiz SIN barra, y esa clave no estaba: la lente SEO iba
#     a la red, el puerto 1 la rechazaba y leia CERO paginas -medido contra el
#     gate anterior: «SEO-02 · 0 documentos distintos» y trece PASA-. SEO-00 no
#     salia porque entonces solo queria decir «sin red». Ahora tambien quiere
#     decir «cero paginas leidas», asi que se siembran las DOS claves y se exige
#     ademas que la pagina se LEYO de la cache: con el puerto muerto no hay otra
#     forma de tener un documento.
COLK2="$(perl -MDigest::MD5=md5_hex -e 'print md5_hex($ARGV[0])' "${COLURL%/}")"
for k in "$COLK" "$COLK2"; do
  printf '<!doctype html><html lang="es"><head><title>Semilla</title></head><body><main><h1>Semilla</h1></main></body></html>' > "$COL/$k.body"
done
printf '200\t118\ttext/html; charset=utf-8\t%s\t0.001' "$COLURL"      > "$COL/$COLK.meta"
printf '200\t118\ttext/html; charset=utf-8\t%s\t0.001' "${COLURL%/}"  > "$COL/$COLK2.meta"
# 🔴 7-oct-2026 · Y AHORA LLEVA FECHA Y PIDE LA REUTILIZACION. Desde ese dia una
#     descarga de otra corrida solo se reutiliza si dice CUANDO se bajo (el
#     `.when`) y si se pide con --cache-horas: el bloque siguiente cuenta por que.
#     Este caso sigue probando lo mismo -que una semilla PROPIA se lee-, ahora
#     con las dos condiciones puestas.
date +%s > "$COL/$COLK.when"; date +%s > "$COL/$COLK2.when"
espera "cache PROPIA (\\t de qa-maestro) SIGUE valiendo"  AUSENTE SEO-00 \
       perl $QA "$COLURL" --solo seo --cache "$COL" --cache-horas 1 --sin-recibo
texto  "cache PROPIA · y la pagina se LEYO de ella"      SI "DATO   1 documentos distintos" \
       perl $QA "$COLURL" --solo seo --cache "$COL" --cache-horas 1 --sin-recibo

echo
echo "== LA CACHE NO MIDE EL PASADO · 7-oct-2026"
# 🔴 EL DEFECTO: `fetch` reutilizaba CUALQUIER descarga propia que encontrara en
#    --cache, sin mirar de cuando era. Una web de cliente llevaba su carpeta de
#    cache DENTRO del repo, y commiteada: siete semanas de antiguedad. Una
#    medida «de produccion» con esa cache dio cuatro FALLOS a la vez -«28 de 28
#    ficheros distintos» entre ellos- sobre un sitio que servia, byte a byte, lo
#    del repo. Era la web de siete semanas antes, impresa como la de hoy.
#    ⚠️ Y la fecha del FICHERO no sirve para saberlo: lo que sale de git, de un
#       `cp` o de un `tar` lleva la fecha de HOY. Por eso la fecha de cada
#       descarga va DENTRO de un `.when` que escribe este programa al bajarla.
#    LA REGLA: se reutiliza lo bajado EN ESTA CORRIDA. Lo de otra corrida, solo
#    si lleva fecha y si se pide con --cache-horas N (y entonces se declara);
#    sin fecha, nunca. Cada caso usa el puerto muerto del bloque anterior: si la
#    semilla NO se reutiliza, la descarga falla al instante y la lente se queda
#    sin paginas (SEO-00); si se reutiliza, la pagina se lee de ella.
CAD="$CACHE/caducidad"
CADURL="http://127.0.0.1:1/"
CADK="$(perl -MDigest::MD5=md5_hex -e 'print md5_hex($ARGV[0])' "$CADURL")"
CADK2="$(perl -MDigest::MD5=md5_hex -e 'print md5_hex($ARGV[0])' "${CADURL%/}")"
# siembra <fecha epoch | -> : la misma semilla PROPIA de siempre, con o sin `.when`
siembra() {
  local k
  rm -rf "$CAD"; mkdir -p "$CAD"
  for k in "$CADK" "$CADK2"; do
    printf '<!doctype html><html lang="es"><head><title>Semilla</title></head><body><main><h1>Semilla</h1></main></body></html>' > "$CAD/$k.body"
  done
  printf '200\t118\ttext/html; charset=utf-8\t%s\t0.001' "$CADURL"      > "$CAD/$CADK.meta"
  printf '200\t118\ttext/html; charset=utf-8\t%s\t0.001' "${CADURL%/}"  > "$CAD/$CADK2.meta"
  if [ "$1" != "-" ]; then printf '%s\n' "$1" > "$CAD/$CADK.when"; printf '%s\n' "$1" > "$CAD/$CADK2.when"; fi
}
HACE_1MIN=$(( $(date +%s) - 60 ))
HACE_30D=$(( $(date +%s) - 30*86400 ))
# (1) SIN FECHA -la forma de una cache commiteada o de una de antes del 7-oct-:
#     no vale, ni por defecto ni pidiendo horas. Es EL caso del defecto.
siembra -
espera "sin fecha (cache commiteada) NO vale"            NOVERIF SEO-00 \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --sin-recibo
siembra -
espera "sin fecha NO vale ni con --cache-horas 24"       NOVERIF SEO-00 \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --cache-horas 24 --sin-recibo
siembra -
texto  "y se DECLARA que se volvio a bajar"              SI "una descarga sin fecha" \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --sin-recibo
# (2) DE OTRA CORRIDA, con fecha: por defecto tampoco. Bajar a las 13:10, subir a
#     las 13:51 y volver a medir a las 14:00 con la misma --cache es el flujo
#     normal de mejorar una web, y el «despues» saldria identico al «antes».
siembra "$HACE_1MIN"
espera "de hace 1 min NO vale por defecto"               NOVERIF SEO-00 \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --sin-recibo
# (3) PEDIDA: con --cache-horas la de hace 1 min SI vale... (sin este caso,
#     «no reutilizar nunca» pasaria por arreglo y --cache-horas no haria nada)
siembra "$HACE_1MIN"
espera "de hace 1 min SI vale con --cache-horas 1"       AUSENTE SEO-00 \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --cache-horas 1 --sin-recibo
siembra "$HACE_1MIN"
texto  "· y la pagina se LEYO de ella"                   SI "DATO   1 documentos distintos" \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --cache-horas 1 --sin-recibo
siembra "$HACE_1MIN"
texto  "· y lo reutilizado se DECLARA"                   SI "LO REUTILIZADO NO ES DE HOY" \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --cache-horas 1 --sin-recibo
# (4) ...pero no la de hace 30 dias: las horas son un tope, no un permiso general
siembra "$HACE_30D"
espera "de hace 30 dias NO vale con --cache-horas 24"    NOVERIF SEO-00 \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --cache-horas 24 --sin-recibo
# (5) Lo que se baja en una corrida lleva su fecha, para que la siguiente pueda decidir
siembra -
perl $QA "$CADURL" --solo seo --cache "$CAD" --sin-recibo >/dev/null 2>&1
if [ -s "$CAD/$CADK.when" ] && grep -qE '^[0-9]{9,}$' "$CAD/$CADK.when"; then
  printf '  OK    %-46s %s\n' "lo bajado sale con su fecha (.when)" "$(cat "$CAD/$CADK.when")"; ok=$((ok+1))
else
  printf '  MAL   %-46s no hay .when, o no es una fecha\n' "lo bajado sale con su fecha (.when)"; ko=$((ko+1))
fi
# (6) Un numero de horas que no es un numero PARA y dice por que: ignorarlo en
#     silencio seria reutilizar o no reutilizar sin que nadie lo haya decidido.
texto  "--cache-horas que no es un numero PARA"          SI "--cache-horas tiene que ser un numero de horas" \
       perl $QA "$CADURL" --solo seo --cache "$CAD" --cache-horas mucho --sin-recibo
# (7) qa-diff lo dice ARRIBA cuando un lado reutilizo: un diff contra una cache vieja
#     sale «NADA HA CAMBIADO» sobre un despliegue que si cambio cosas. Y no lo dice
#     cuando nadie reutilizo (sin este negativo, «avisar siempre» pasaria por arreglo).
siembra -
perl $QA "$CADURL" --solo seo --cache "$CAD" --sin-recibo --json "$CACHE/cad-a.json" >/dev/null 2>&1
siembra "$HACE_1MIN"
perl $QA "$CADURL" --solo seo --cache "$CAD" --cache-horas 1 --sin-recibo --json "$CACHE/cad-b.json" >/dev/null 2>&1
texto  "qa-diff avisa si un lado reutilizo"              SI "DESPUES reutiliza" \
       perl ../qa-diff.pl "$CACHE/cad-a.json" "$CACHE/cad-b.json"
texto  "· y calla si ninguno reutilizo"                  NO "de una corrida anterior" \
       perl ../qa-diff.pl "$CACHE/cad-a.json" "$CACHE/cad-a.json"
# el NO de arriba sale verde tambien si el diff no llega a correr: se exige que corrio
texto  "· (y ese diff de control SI corrio)"            SI "NADA HA CAMBIADO" \
       perl ../qa-diff.pl "$CACHE/cad-a.json" "$CACHE/cad-a.json"

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
# 🔴 6-nov-2026 · Y LAS DECLARACIONES DE forms-gate.js (data-pasos, data-envio-js, data-guarda-doble). Las lee ese gate,
#    no el JS del sitio. Visto en ROJO contra el gate anterior: FALLO con 3 atributos. Y el control negativo es un
#    nombre CASI igual (data-envio): la exencion es por nombre exacto, asi que sigue saltando y se nombra.
espera "MED-05 · las declaraciones de forms-gate no son huerfanos" PASA MED-05 \
       perl $QA https://climentmedia.com --repo fixtures-med05/vocabulario-forms --candidato --una-sola --solo medicion --sin-recibo
espera "MED-05 · un nombre casi igual (data-envio) SIGUE cazandose" FALLO MED-05 \
       perl $QA https://climentmedia.com --repo fixtures-med05/vocabulario-forms-casi --candidato --una-sola --solo medicion --sin-recibo
texto  "MED-05 · y lo nombra"                          SI "data-envio (escrito" \
       perl $QA https://climentmedia.com --repo fixtures-med05/vocabulario-forms-casi --candidato --una-sola --solo medicion --sin-recibo

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
# 🔴 6-nov-2026 · DOS LISTAS DE TIPOS. page-types.tsv tiene 22 tipos (plp, faq,
#    carrito…) y este gate solo aceptaba los 15 de anatomy.tsv: una tienda que
#    declaraba data-tipo="plp" en sus colecciones -lo que pide page-type-gate- salia
#    con EST-02d «valor que no existe» y se le inferia «servicio» por la ruta, con la
#    anatomia de un servicio. Ahora el vocabulario es page-types.tsv (tipos y
#    alias); un tipo sin anatomia medida se acepta y sale EST-02e, a la vista: su
#    maqueta no se juzga. La frontera de arriba (un valor inventado) sigue en rojo.
texto  "data-tipo · plp (page-types.tsv) es un tipo"   SI "tipos: plp x1" \
       perl $QA https://climentmedia.com --repo fixtures-type/plp --candidato --una-sola --solo estructura --sin-recibo
espera "data-tipo · plp no es un valor que no existe"  AUSENTE EST-02d \
       perl $QA https://climentmedia.com --repo fixtures-type/plp --candidato --una-sola --solo estructura --sin-recibo
espera "data-tipo · y avisa: sin anatomia medida"      AVISO EST-02e \
       perl $QA https://climentmedia.com --repo fixtures-type/plp --candidato --una-sola --solo estructura --sin-recibo
texto  "data-tipo · y cuenta por tipo"                 SI "1 pagina(s) · plp x1" \
       perl $QA https://climentmedia.com --repo fixtures-type/plp --candidato --una-sola --solo estructura --sin-recibo
# sin roles que juzgar, EST-02c no puede decir «anatomia completa»: seria un 0 de 0 · PASA
espera "data-tipo · sin anatomia, EST-02c no aprueba"  AUSENTE EST-02c \
       perl $QA https://climentmedia.com --repo fixtures-type/plp --candidato --una-sola --solo estructura --sin-recibo
texto  "data-tipo · un alias (preguntas) es su tipo"   SI "tipos: faq x1" \
       perl $QA https://climentmedia.com --repo fixtures-type/alias-faq --candidato --una-sola --solo estructura --sin-recibo
espera "data-tipo · un tipo CON anatomia no avisa"     AUSENTE EST-02e \
       perl $QA https://climentmedia.com --repo fixtures-type/declarado --candidato --una-sola --solo estructura --sin-recibo

# 🔴 6-nov-2026 · UNA LEGAL NO TIENE ROLES, Y EST-02 SE LOS PEDIA. anatomy.tsv da 0
#    roles a legal y a 404 (09 §2.11: prosa a proposito), y EST-02 contaba una legal sin
#    data-sec como «no declara data-sec»: el sitio entero quedaba en NO VERIFICADO y
#    ninguna web con legales podia cerrarlo. Cuatro webs marcaban su prosa legal con
#    data-sec="contexto" («quien hay detras») para esquivarlo, y entonces EST-02c la
#    daba por «anatomia completa»: un 0 de 0 · PASA. Ahora legal y 404 no cuentan en
#    EST-02 ni en EST-02c, y lo dice EST-02f. Un tipo sin anatomia medida (plp) sin
#    data-sec tampoco cuenta: no hay roles contra los que medirlo, y EST-02e lo dice.
#    La frontera: una pagina de servicio sin data-sec sigue en NO VERIFICADO (est-02b).
espera "EST-02 · una legal sin data-sec no lo deja abierto" AUSENTE EST-02 \
       perl $QA https://climentmedia.com --repo fixtures-type/legal-prosa --candidato --una-sola --solo estructura --sin-recibo
espera "EST-02f · y dice que no hay roles que declarar"    PASA EST-02f \
       perl $QA https://climentmedia.com --repo fixtures-type/legal-prosa --candidato --una-sola --solo estructura --sin-recibo
espera "EST-02c · una legal con roles no es un 0 de 0"     AUSENTE EST-02c \
       perl $QA https://climentmedia.com --repo fixtures-type/legal-con-roles --candidato --una-sola --solo estructura --sin-recibo
espera "EST-02f · y la cuenta como prosa"                  PASA EST-02f \
       perl $QA https://climentmedia.com --repo fixtures-type/legal-con-roles --candidato --una-sola --solo estructura --sin-recibo
espera "EST-02 · un plp sin data-sec no lo deja abierto"   AUSENTE EST-02 \
       perl $QA https://climentmedia.com --repo fixtures-type/plp-sin-datasec --candidato --una-sola --solo estructura --sin-recibo
espera "EST-02e · y el plp sigue a la vista"               AVISO EST-02e \
       perl $QA https://climentmedia.com --repo fixtures-type/plp-sin-datasec --candidato --una-sola --solo estructura --sin-recibo
espera "EST-02 · un servicio sin data-sec SIGUE abierto"   NOVERIF EST-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/est-02b --candidato --una-sola --solo estructura --sin-recibo
echo
echo "== LOS TIPOS nosotros Y empleo (09 §2.13 y §2.14) · 26-sep-2026"
# 🔴 EL HUECO: una «a propos» y una pagina de empleo no tenian tipo. Sin
#    declarar, el gate las inferia «servicio» por la ruta y les pedia
#    calificacion, proceso y objeciones; declararlas como el tipo mas cercano
#    habria aprobado un check que no se hizo. Los dos fixtures estan en la RAIZ,
#    que se inferiria «home»: si sale su tipo, gano la declaracion.
texto  "nosotros · lo declarado gana a la ruta"        SI "tipos: nosotros x1" \
       perl $QA https://climentmedia.com --repo fixtures-type/nosotros --candidato --una-sola --solo estructura --sin-recibo
espera "nosotros · con sus cuatro roles, PASA"         PASA EST-02c \
       perl $QA https://climentmedia.com --repo fixtures-type/nosotros --candidato --una-sola --solo estructura --sin-recibo
espera "empleo · sin catalogo de puestos, FALLA"       FALLO EST-02c \
       perl $QA https://climentmedia.com --repo fixtures-type/empleo-incompleto --candidato --una-sola --solo estructura --sin-recibo
texto  "empleo · y nombra el rol que falta"            SI "«empleo» faltan: catalogo" \
       perl $QA https://climentmedia.com --repo fixtures-type/empleo-incompleto --candidato --una-sola --solo estructura --sin-recibo
# 🔑 LA FRONTERA: `evidencia` es condicional (OBL solo si hay empleados a los
#    que citar) y el fixture no la lleva. Si la echara de menos, el tipo pediria
#    lo imposible a quien contrata a su primera persona.
texto  "empleo · y NO echa de menos la condicional"    NO "catalogo evidencia" \
       perl $QA https://climentmedia.com --repo fixtures-type/empleo-incompleto --candidato --una-sola --solo estructura --sin-recibo

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
       perl $QA http://site-d.example/ --solo rendimiento --cache "$CACHE" --max-urls 40
# 🔴 EL CONTROL DE REGRESION, y es el que justifica el arreglo entero: el mismo
#    sitio tiene que dar el MISMO veredicto mire una pagina, tres o cuarenta.
espera "REN-05 · mismo veredicto con 1 pagina"           FALLO REN-05 \
       perl $QA http://site-d.example/ --solo rendimiento --cache "$CACHE" --una-sola
espera "REN-05 · mismo veredicto con las 40"             FALLO REN-05 \
       perl $QA http://site-d.example/ --solo rendimiento --cache "$CACHE" --max-urls 40 --muestra 40
# Un porcentaje sin pagina no es accionable: hay que poder ir a mirarla.
texto  "REN-05 · NOMBRA la peor pagina"                  SI "politica-cookies" \
       perl $QA http://site-d.example/ --solo rendimiento --cache "$CACHE" --max-urls 40
# Segundo positivo con otro perfil: site-b carga su propio dominio principal.
espera "REN-05 · site-b: 89% en la home"                FALLO REN-05 \
       perl $QA http://shop.site-b.example/ --solo rendimiento --cache "$CACHE"
# 🔴 LA FRONTERA · una web sin terceros no puede salir acusada.
espera "REN-05 · cm no tiene terceros: PASA"             PASA  REN-05 \
       perl $QA http://cm.example/ --solo rendimiento --cache "$CACHE"
# 🔴 Y el negativo del arreglo del arreglo: con el peor inicializado a 0 y `>`,
#    una web con CERO terceros no fijaba pagina y el DATO decia «sin pagina
#    medible» — que se lee «no he podido mirar» siendo «he mirado y es cero».
texto  "REN-05 · cero terceros dice 0%, no «no medible»" NO "sin pagina medible" \
       perl $QA http://cm.example/ --solo rendimiento --cache "$CACHE"
# 🔴 5-nov-2026 · EL EMPATE. La HUELLA lleva la peor pagina, y con dos paginas
#    al mismo % ganaba la que llegaba antes: una web aceptada dejaba de casar
#    con su propia aceptacion porque cambiaba el orden, no la web. Ahora, a %
#    igual (el que se imprime), gana la URL menor en orden alfabetico. En
#    empate.example el sitemap pone zeta delante de alfa a proposito; medido
#    contra el gate de antes: nombraba zeta.
texto  "REN-05 · empate: nombra la menor (alfa)"         SI "peor pagina http://empate.example/alfa.html" \
       perl $QA http://empate.example/ --solo rendimiento --cache "$CACHE" --max-urls 40
texto  "REN-05 · empate: no la que llega antes (zeta)"   NO "peor pagina http://empate.example/zeta.html" \
       perl $QA http://empate.example/ --solo rendimiento --cache "$CACHE" --max-urls 40
# 🔴 6-nov-2026 · LA HUELLA DE REN-05 ES SU CLAVE, no su DATO. El DATO lleva cuantas
#    paginas se midieron, cual salio la peor y los KB exactos: el mismo site-d daba TRES
#    huellas con 1, 3 y 40 paginas (visto en ROJO contra el gate anterior: el primer caso
#    de abajo sale MAL), y una web nuestra necesitaba dos aceptados para una decision.
#    La clave lleva los hosts de los RECURSOS que pesan, la rama del umbral y el tramo de
#    100 KB. Los dos controles que TIENEN que separar: un host mas que pesa, al mismo
#    tramo (terceros-otro: una imagen de site-b) y los mismos hosts con 100 KB mas
#    (terceros-crece); vistos en ROJO con un mutante sin los hosts y otro sin el tramo.
#    Y el que NO tiene que separar: dos ENLACES a otros hosts (terceros-enlace) dan la
#    huella de empate; visto en ROJO con los hosts de @third_hosts, que coge toda URL
#    entre comillas del HTML (en una web nuestra, el host de un chat entraba o no segun
#    las paginas de la muestra).
#    Y lo firmado antes sigue casando: un aceptado con la huella vieja (DATO y DONDE).
if mide_bloque "REN-05: la huella es la clave" http://site-d.example/ http://empate.example/ http://terceros-crece.example/ http://terceros-otro.example/ http://terceros-enlace.example/ --cache "$CACHE"; then
  huella_ren05() { "$@" 2>&1 | grep -A8 -E '^\s+\[[A-Z ]+\] +REN-05 ' | grep -m1 'HUELLA ' | sed -E 's/^[[:space:]]*HUELLA //'; }
  linea_ren05()  { local k="$1"; shift; "$@" 2>&1 | grep -A8 -E '^\s+\[[A-Z ]+\] +REN-05 ' | grep -m1 -E "^\s+$k " | sed -E "s/^[[:space:]]*$k +//"; }
  igual() { # igual <etiqueta> SI|NO <a> <b>
    local r=NO; [ -n "$3" ] && [ -n "$4" ] && [ "$3" = "$4" ] && r=SI
    if [ -z "$3" ] || [ -z "$4" ]; then
      printf '  MAL   %-46s falta una HUELLA de REN-05\n' "$1"; ko=$((ko+1))
    elif [ "$r" = "$2" ]; then
      printf '  OK    %-46s %s\n' "$1" "$(printf '%.40s' "$3")"; ok=$((ok+1))
    else
      printf '  MAL   %-46s %s | %s\n' "$1" "$3" "$4"; ko=$((ko+1))
    fi
  }
  _R5="--solo rendimiento --cache $CACHE"
  R5_1="$(huella_ren05 perl $QA http://site-d.example/ $_R5 --una-sola)"
  R5_3="$(huella_ren05 perl $QA http://site-d.example/ $_R5 --max-urls 40)"
  R5_40="$(huella_ren05 perl $QA http://site-d.example/ $_R5 --max-urls 40 --muestra 40)"
  R5_E="$(huella_ren05 perl $QA http://empate.example/ $_R5 --max-urls 40)"
  R5_C="$(huella_ren05 perl $QA http://terceros-crece.example/ $_R5 --max-urls 40)"
  R5_O="$(huella_ren05 perl $QA http://terceros-otro.example/ $_R5 --max-urls 40)"
  R5_L="$(huella_ren05 perl $QA http://terceros-enlace.example/ $_R5 --max-urls 40)"
  igual "REN-05 · huella igual con 1 y con 40 paginas"     SI "$R5_1" "$R5_40"
  igual "REN-05 · huella igual con 3 y con 40 paginas"     SI "$R5_3" "$R5_40"
  igual "REN-05 · un host mas que pesa: otra huella"       NO "$R5_O" "$R5_E"
  igual "REN-05 · mismos hosts, 100 KB mas: otra huella"   NO "$R5_C" "$R5_E"
  igual "REN-05 · un enlace no mueve la huella"            SI "$R5_L" "$R5_E"
  # Los aceptados: el de antes (DATO y DONDE de la corrida de 1 pagina) y el de la clave.
  R5A="$CACHE/repo-ren05"; rm -rf "$R5A"; mkdir -p "$R5A/_deploy"
  printf '<!doctype html><html lang="es"><head><title>x</title></head><body><main><h1>x</h1></main></body></html>\n' > "$R5A/index.html"
  acepta_ren05() {
    { echo "[ACEPTADO]"; echo "CHECK:    REN-05"; echo "HALLAZGO: $1"
      echo "MOTIVO:   Los terceros son la medicion del cliente: se quedan hasta su plan."
      echo "ACEPTA:   Cliente de prueba"; echo "FECHA:    $(date +%Y-%m-%d)"; } > "$R5A/_deploy/aceptado.conf"
  }
  R5_D="$(linea_ren05 DATO perl $QA http://site-d.example/ $_R5 --una-sola)"
  R5_W="$(linea_ren05 DONDE perl $QA http://site-d.example/ $_R5 --una-sola)"
  acepta_ren05 "DATO=$R5_D DONDE=$R5_W"
  espera "REN-05 · el aceptado de antes sigue casando"     ACEPTADO REN-05 perl $QA http://site-d.example/ $_R5 --una-sola --repo "$R5A" --sin-recibo
  acepta_ren05 "$R5_1"
  espera "REN-05 · el de la clave casa con 40 paginas"     ACEPTADO REN-05 perl $QA http://site-d.example/ $_R5 --max-urls 40 --muestra 40 --repo "$R5A" --sin-recibo
  acepta_ren05 "$R5_E"
  espera "REN-05 · la clave de empate NO tapa el doble"    FALLO    REN-05 perl $QA http://terceros-crece.example/ $_R5 --max-urls 40 --repo "$R5A" --sin-recibo
fi

# 🔴 6-nov-2026 · LA HUELLA DE REN-11 ES LA FRANJA DE GOOGLE, no los milisegundos. Dos
#    capturas de la misma pagina no dan nunca el mismo LCP: con la huella del DATO, un
#    aceptado caducaba en la captura siguiente y D-057 no podia llamar viejo a un LCP
#    lento que produccion tiene igual. El primer caso sale MAL con el gate de antes
#    (2.900 y 3.700 ms, dos huellas). Los dos que TIENEN que separar: pasar a la franja
#    mala (>4 s) y que falle tambien el CLS; vistos en ROJO con un mutante sin la franja
#    del LCP y otro sin el CLS.
if mide_bloque "REN-11: la huella es la franja" http://site-c.example/ --cache "$CACHE"; then
  huella_ren11() { "$@" 2>&1 | grep -A8 -E '^\s+\[[A-Z ]+\] +REN-11 ' | grep -m1 'HUELLA ' | sed -E 's/^[[:space:]]*HUELLA //'; }
  igual_r11() { # igual_r11 <etiqueta> SI|NO <a> <b>
    local r=NO; [ -n "$3" ] && [ -n "$4" ] && [ "$3" = "$4" ] && r=SI
    if [ -z "$3" ] || [ -z "$4" ]; then
      printf '  MAL   %-46s falta una HUELLA de REN-11\n' "$1"; ko=$((ko+1))
    elif [ "$r" = "$2" ]; then
      printf '  OK    %-46s %s\n' "$1" "$(printf '%.40s' "$3")"; ok=$((ok+1))
    else
      printf '  MAL   %-46s %s | %s\n' "$1" "$3" "$4"; ko=$((ko+1))
    fi
  }
  _R11="--solo rendimiento --cache $CACHE"
  R11_A="$(huella_ren11 perl $QA http://site-c.example/ $_R11 --dom dom-ren11-lcp-2900.json)"
  R11_B="$(huella_ren11 perl $QA http://site-c.example/ $_R11 --dom dom-ren11-lcp-3700.json)"
  R11_M="$(huella_ren11 perl $QA http://site-c.example/ $_R11 --dom dom-ren11-lcp-4600.json)"
  R11_C="$(huella_ren11 perl $QA http://site-c.example/ $_R11 --dom dom-ren11-lcp-y-cls.json)"
  R11_N="$(huella_ren11 perl $QA http://site-c.example/ $_R11 --dom dom-lcp-lento-sin-cls.json)"
  igual_r11 "REN-11 · 2.900 y 3.700 ms: la misma huella"     SI "$R11_A" "$R11_B"
  igual_r11 "REN-11 · mas de 4 s: otra huella"               NO "$R11_M" "$R11_A"
  igual_r11 "REN-11 · falla tambien el CLS: otra huella"     NO "$R11_C" "$R11_A"
  igual_r11 "REN-11 · un CLS sin medir no entra en la clave" SI "$R11_N" "$R11_A"
  R11R="$CACHE/repo-ren11"; rm -rf "$R11R"; mkdir -p "$R11R/_deploy"
  printf '<!doctype html><html lang="es"><head><title>x</title></head><body><main><h1>x</h1></main></body></html>\n' > "$R11R/index.html"
  { echo "[ACEPTADO]"; echo "CHECK:    REN-11"; echo "HALLAZGO: $R11_A"
    echo "MOTIVO:   El LCP lo pone el video del cliente en la portada: se queda hasta su plan."
    echo "ACEPTA:   Cliente de prueba"; echo "FECHA:    $(date +%Y-%m-%d)"; } > "$R11R/_deploy/aceptado.conf"
  espera "REN-11 · el aceptado casa en la captura siguiente" ACEPTADO REN-11 perl $QA http://site-c.example/ $_R11 --dom dom-ren11-lcp-3700.json --repo "$R11R" --sin-recibo
  espera "REN-11 · y no tapa un LCP de mas de 4 s"           FALLO    REN-11 perl $QA http://site-c.example/ $_R11 --dom dom-ren11-lcp-4600.json --repo "$R11R" --sin-recibo
fi

echo
echo "== D-057 · LO VIEJO IGUAL EN PRODUCCION NO PARA UNA SUBIDA (gates/d057.pl) · 5-nov-2026"
# 🔴 EL HUECO: cinco webs paradas el 5-nov por FALLOs que su subida no tocaba y que
#    la web publicada ya tenia igual. La regla para dejarlos pasar (D-045) existia y
#    la comprobaba la memoria del chat que subia. Ahora la comprueba d057.pl, que
#    mide produccion con la misma regla del recibo y busca la fila con fecha.
#    La escuela de musica de fixtures-d057/ es INVENTADA. Publicada (d057.example)
#    tiene dos descriptions repetidas: SEO-02b en FALLO, con 2 instancias. Las tres
#    carpetas son la misma web con UN fichero cambiado (`diff -rq` abajo):
#      igual        la que esta publicada, tal cual
#      arregla-una  arregla una de las dos repetidas (le quita 1 a produccion)
#      nueva        repite una tercera (una instancia que produccion no tiene)
#    Cada caso copia su carpeta a la cache, escribe su fila y mide el candidato alli:
#    el arbol de fixtures-d057/ no se ensucia con recibos.
D57="$CACHE/d057"
if mide_bloque "D-057 · d057.pl contra la produccion de mentira" http://d057.example/; then
  mkdir -p "$D57"
  # el banco no deja recibos ni historial en el de las webs
  d57_cand() {   # d57_cand <nombre> <carpeta> <lente> [mas de qa-master]: copia y mide el candidato
    local n="$1" fx="$2" lente="$3"; shift 3
    rm -rf "${D57:?}/$n"; cp -r "$fx" "$D57/$n"
    QA_RECIBOS_DIR="$D57/recibos" perl $QA http://d057.example/ --repo "$D57/$n" --candidato --solo "$lente" "$@" > "$D57/$n.qa.txt" 2>&1
  }
  d57_fila() {   # d57_fila <nombre> <fichero bajo _seo/> <cabecera> <fila>
    mkdir -p "$D57/$1/_seo"
    printf '%s\n%s\n%s\n' "$3" "$(printf '%s' "$3" | sed 's/[^|]*|/---|/g; s/^---//')" "$4" > "$D57/$1/_seo/$2"
  }
  B57="| Capa | Qué | Fuente | Estado | Fecha | Fila del plan |"
  d57() {        # d57 <etiqueta> <exit> <literal que tiene que salir> <nombre> [mas de d057.pl]
    local eti="$1" rcq="$2" lit="$3" n="$4"; shift 4
    local out rc; out="$(QA_RECIBOS_DIR="$D57/recibos" perl ../d057.pl --repo "$D57/$n" "$@" 2>&1)"; rc=$?
    if [ "$rc" = "$rcq" ] && printf '%s' "$out" | grep -qF -- "$lit"; then
      printf '  OK    %-46s exit %s · "%s"\n' "$eti" "$rc" "$lit"; ok=$((ok+1))
    else
      printf '  MAL   %-46s esperaba exit %s con "%s" y salio exit %s\n' "$eti" "$rcq" "$lit" "$rc"; ko=$((ko+1))
      printf '%s\n' "$out" | grep -E 'D057-|NO MEDIDO|^ +(PARA|SIGUE|D-057|NO-) ' | head -6 | sed 's/^/          /'
    fi
  }
  # las tres carpetas: la misma web con UN fichero distinto, y igual = la publicada
  D57_DIF="$(diff -rq fixtures-sites/d057.example fixtures-d057/igual | grep -v '_prod.txt' | wc -l | tr -dc '0-9')"
  D57_A="$(diff -rq fixtures-d057/igual fixtures-d057/arregla-una | wc -l | tr -dc '0-9')"
  D57_N="$(diff -rq fixtures-d057/igual fixtures-d057/nueva | wc -l | tr -dc '0-9')"
  if [ "$D57_DIF" = 0 ] && [ "$D57_A" = 1 ] && [ "$D57_N" = 1 ]; then
    printf '  OK    %-46s %s\n' "D-057 · las carpetas difieren en UN fichero" "igual=publicada · 1 · 1"; ok=$((ok+1))
  else
    printf '  MAL   %-46s igual/publicada %s · arregla-una %s · nueva %s\n' "D-057 · las carpetas difieren en UN fichero" "$D57_DIF" "$D57_A" "$D57_N"; ko=$((ko+1))
  fi

  # ── los cuatro que pide el encargo ──
  # 1 · igual en produccion, con fila abierta y fecha: PASA, nombrado
  d57_cand igual fixtures-d057/igual seo
  d57_fila igual BASE.md "$B57" "| 2 · Puerta | SEO-02b, las dos descriptions repetidas | qa-master | pendiente | 2099-12-31 | textos |"
  d57 "D-057 · igual en produccion y con fila: PASA"   0 "D057-FALLO: SEO-02b"       igual
  # 2 · solo en el candidato: una instancia que produccion no tiene. PARA
  d57_cand nueva fixtures-d057/nueva seo
  d57_fila nueva BASE.md "$B57" "| 2 · Puerta | SEO-02b, las descriptions repetidas | qa-master | pendiente | 2099-12-31 | textos |"
  d57 "D-057 · una instancia nueva: PARA"              1 "1 de 3 NUEVO en el candidato" nueva
  # 3 · igual en produccion pero SIN fila que lo arregle: PARA
  d57_cand sin-fila fixtures-d057/igual seo
  d57 "D-057 · sin fila con fecha: PARA"               1 "ninguna fila de _seo/BASE.md ni del plan nombra SEO-02b" sin-fila
  # 4 · de medicion: D-057 no lo cubre aunque fuera viejo. PARA, sin medir produccion
  d57_cand medicion fixtures-lenses/med-consent-js-gtm-directo medicion --una-sola --contenedor fixtures-lenses/contenedor-solo-google.js
  d57_fila medicion BASE.md "$B57" "| 2 · Puerta | MED-02, el consentimiento llega tarde | qa-master | pendiente | 2099-12-31 | medicion |"
  d57 "D-057 · un FALLO de medicion: PARA"             1 "MED-02    D-057 no cubre" medicion

  # ── los bordes ──
  # 🔴 el candidato que ARREGLA una de las dos tiene otra huella (otro conjunto) y es
  #    justo la subida que hay que dejar pasar: se compara instancia a instancia.
  d57_cand arregla fixtures-d057/arregla-una seo
  d57_fila arregla BASE.md "$B57" "| 2 · Puerta | SEO-02b, la que queda | qa-master | pendiente | 2099-12-31 | textos |"
  d57 "D-057 · arregla 1 de 2: PASA"                   0 "D057-FALLO: SEO-02b"       arregla
  d57 "D-057 · y cuenta lo que quita (condicion 2)"    0 "D057-QUITA: 1"             arregla
  d57 "D-057 · igual en produccion no quita nada"      0 "D057-QUITA: 0"             igual
  # un check entero que produccion no tiene (sin title en la portada)
  rm -rf "$D57/otro-check"; cp -r fixtures-d057/igual "$D57/otro-check"
  D57_T="$(perl -0pi -e '$n += s{<title>[^<]*</title>\n}{}; END { print STDERR $n // 0 }' "$D57/otro-check/index.html" 2>&1)"
  QA_RECIBOS_DIR="$D57/recibos" perl $QA http://d057.example/ --repo "$D57/otro-check" --candidato --solo seo > "$D57/otro-check.qa.txt" 2>&1
  # 🔴 6-nov · y lo que destapo este caso: una portada SIN <title> salia en SEO-01
  #    «title presente y en rango». Medido contra el gate de antes: PASA.
  espera "SEO-01 · una pagina sin <title>: FALLO"      FALLO SEO-01 \
         perl $QA http://d057.example/ --repo "$D57/otro-check" --candidato --solo seo --sin-recibo
  texto  "SEO-01 · y nombra la pagina"                 SI "1 de 6 paginas sin title" \
         perl $QA http://d057.example/ --repo "$D57/otro-check" --candidato --solo seo --sin-recibo
  espera "SEO-01 · con title en las seis: PASA"        PASA  SEO-01 \
         perl $QA http://d057.example/ --repo fixtures-d057/igual --candidato --solo seo --sin-recibo
  d57_fila otro-check BASE.md "$B57" "| 2 · Puerta | SEO-01 y SEO-02b | qa-master | pendiente | 2099-12-31 | textos |"
  if [ "$D57_T" = 1 ]; then
    d57 "D-057 · un check que produccion no tiene: PARA" 1 "solo en el candidato: en produccion no sale (es NUEVO)" otro-check
  else
    printf '  MAL   %-46s quitar el title hizo %s cambios, no 1\n' "D-057 · un check que produccion no tiene" "$D57_T"; ko=$((ko+1))
  fi
  # la fila: vencida, cerrada, sin fecha, sin dueño, tachada, y un id que se parece
  d57_fila sin-fila BASE.md "$B57" "| 2 · Puerta | SEO-02b | qa-master | pendiente | 2020-01-01 | textos |"
  d57 "D-057 · fila vencida: PARA"                     1 "vencio el 2020-01-01"      sin-fila
  d57_fila sin-fila BASE.md "$B57" "| 2 · Puerta | SEO-02b | qa-master | **hecho** (abc1234) | 2099-12-31 | textos |"
  d57 "D-057 · fila cerrada que sigue fallando: PARA"  1 "su fila esta cerrada"      sin-fila
  d57_fila sin-fila BASE.md "$B57" "| 2 · Puerta | SEO-02b | qa-master | pendiente | — | textos |"
  d57 "D-057 · fila sin fecha: PARA"                   1 "su fila no tiene fecha"    sin-fila
  d57_fila sin-fila BASE.md "$B57" "| 2 · Puerta | ~~SEO-02b~~ ya no | qa-master | pendiente | 2099-12-31 | textos |"
  d57 "D-057 · un id tachado no es fila: PARA"         1 "ninguna fila"              sin-fila
  d57_fila sin-fila BASE.md "$B57" "| 2 · Puerta | SEO-02 (titles) | qa-master | pendiente | 2099-12-31 | textos |"
  d57 "D-057 · SEO-02 no es SEO-02b: PARA"             1 "ninguna fila"              sin-fila
  rm -f "$D57/sin-fila/_seo/BASE.md"
  P57="| Fecha | Vertical | Qué | Resuelve | Firma | Cómo se mide | Dueño | Visible | Estado |"
  d57_fila sin-fila plan-ciclo-2099.md "$P57" "| 31-dic-2099 | todas | las descriptions | SEO-02b | D-011 | qa-master | | no | pendiente |"
  d57 "D-057 · fila del plan sin dueño: PARA"          1 "su fila no tiene dueno"    sin-fila
  d57_fila sin-fila plan-ciclo-2099.md "$P57" "| 31-dic-2099 | todas | las descriptions | SEO-02b | D-011 | qa-master | chat de la escuela | no | pendiente |"
  d57 "D-057 · fila del plan con dueño y fecha: PASA"  0 "dueno: chat de la escuela" sin-fila
  # 🔴 6-nov · y una fila fuera de BASE.md no hace hablar a Perl: «Odd number of elements in
  #    anonymous hash», una vez por fila (19 en una web, 17 en otra). La construccion de antes,
  #    en un `perl -w` aparte, da el aviso; con `? 1 : 0`, no, y una fila de BASE.md sigue en 1.
  D57_ODD="$(QA_RECIBOS_DIR="$D57/recibos" perl ../d057.pl --repo "$D57/sin-fila" 2>&1 | grep -c 'Odd number')"
  if [ "$D57_ODD" = 0 ]; then printf '  OK    %-46s %s\n' "D-057 · una fila fuera de BASE.md, sin avisos de Perl" "0 avisos"; ok=$((ok+1))
  else printf '  MAL   %-46s %s aviso(s) «Odd number»\n' "D-057 · una fila fuera de BASE.md, sin avisos de Perl" "$D57_ODD"; ko=$((ko+1)); fi
  # 🔴 6-nov · «espera X» da dueño solo al principio del Estado: en mitad («la portada espera la
  #    lectura…») daba «dueno: espera la». El primero, visto en ROJO contra la regla de antes (PASA).
  d57_fila sin-fila plan-ciclo-2099.md "$P57" "| 31-dic-2099 | todas | las descriptions | SEO-02b | D-011 | qa-master | | no | pendiente: la portada espera la lectura de ANUNCIOS |"
  d57 "D-057 · «espera» en mitad del Estado no es dueño" 1 "su fila no tiene dueno"    sin-fila
  d57_fila sin-fila plan-ciclo-2099.md "$P57" "| 31-dic-2099 | todas | las descriptions | SEO-02b | D-011 | qa-master | | no | **espera a ANUNCIOS** (su plan) |"
  d57 "D-057 · «espera a X» al principio: su dueño"    0 "dueno: espera ANUNCIOS"    sin-fila
  # 🔴 un sin mirar viejo con fila tambien pasa (Manuel: «lo viejo sin mirar va igual
  #    que lo viejo en rojo»); sin fila, sigue su camino de siempre en la puerta
  d57 "D-057 · sin mirar sin fila: SIGUE, no para"     0 "D057-SIGUE: SEO-17"        igual
  d57_fila igual BASE.md "$B57" "| 2 · Puerta | SEO-02b, y SEO-17 (idiomas) | qa-master | pendiente | 2099-12-31 | textos |"
  d57 "D-057 · sin mirar igual en produccion: pasa"   0 "D057-NV: SEO-17"           igual
  # MED-13 en una web sin GA4 ni Ads por decision: NO APLICA, si de verdad no lleva
  d57_cand sin-ga4 fixtures-d057/igual medicion
  d57 "D-057 · MED-13 sin declarar: SIGUE"             0 "SIGUE     NV    MED-13" sin-ga4
  d57 "D-057 · MED-13 con SIN_GA4_NI_ADS: NO APLICA"   0 "D057-NO-APLICA: MED-13"    sin-ga4 --sin-ga4-ni-ads "las citas van a la agenda de la clinica"
  rm -rf "$D57/con-ga4"; cp -r fixtures-d057/igual "$D57/con-ga4"
  D57_G="$(perl -0pi -e '$n += s{</head>}{<script async src="https://www.googletagmanager.com/gtag/js?id=G-PRUEBA1234"></script>\n</head>}; END { print STDERR $n // 0 }' "$D57/con-ga4/canto/index.html" 2>&1)"
  QA_RECIBOS_DIR="$D57/recibos" perl $QA http://d057.example/ --repo "$D57/con-ga4" --candidato --solo medicion > "$D57/con-ga4.qa.txt" 2>&1
  if [ "$D57_G" = 1 ]; then
    d57 "D-057 · lo declara y lleva GA4: PARA"         1 "y el arbol lleva canto/index.html: googletagmanager.com" con-ga4 --sin-ga4-ni-ads "sin GA4"
  else
    printf '  MAL   %-46s poner la etiqueta hizo %s cambios, no 1\n' "D-057 · lo declara y lleva GA4" "$D57_G"; ko=$((ko+1))
  fi
  # lo que no se puede medir no se da por bueno ni por nuevo
  rm -rf "$D57/prod"; cp -r fixtures-d057/igual "$D57/prod"
  QA_RECIBOS_DIR="$D57/recibos" perl $QA http://d057.example/ --repo "$D57/prod" --solo seo > "$D57/prod.qa.txt" 2>&1
  d57 "D-057 · un recibo de PRODUCCION: NO MEDIDO"     2 "D-057 compara el CANDIDATO con produccion" prod
  rm -rf "$D57/nadie"; cp -r fixtures-d057/igual "$D57/nadie"
  # 🔴 6-nov · por un proxy que no escucha, no por la produccion de mentira: un host
  #    sin fixture alli es un 502 en su registro, y el centinela del final («la
  #    produccion no se ha inventado nada») lo cuenta, con razon, como un caso que
  #    midio algo inventado. Aqui no contesta nadie, que es lo que se prueba.
  P57MUERTO="http://127.0.0.1:9"
  http_proxy="$P57MUERTO" https_proxy="$P57MUERTO" HTTPS_PROXY="$P57MUERTO" \
    QA_RECIBOS_DIR="$D57/recibos" perl $QA http://d057.example/ --repo "$D57/nadie" --candidato --solo seo > "$D57/nadie.qa.txt" 2>&1
  d57_fila nadie BASE.md "$B57" "| 2 · Puerta | SEO-02b | qa-master | pendiente | 2099-12-31 | textos |"
  http_proxy="$P57MUERTO" https_proxy="$P57MUERTO" HTTPS_PROXY="$P57MUERTO" \
    d57 "D-057 · produccion que no contesta: NO MEDIDO"  2 "qa-master sobre produccion salio con 3" nadie
  # la misma regla = el mismo qa-master: con otro (aqui, una copia con UNA linea de
  # mas) produccion no se mediria con la regla del recibo
  G57="$D57/gates-otro"; rm -rf "$G57"; mkdir -p "$G57"
  cp ../d057.pl ../receipt.pl ../qa-master.pl "$G57/" && printf '\n# una linea de mas\n' >> "$G57/qa-master.pl"
  D57_OUT="$(QA_RECIBOS_DIR="$D57/recibos" perl "$G57/d057.pl" --repo "$D57/igual" 2>&1)"; D57_RC=$?
  if [ "$D57_RC" = 2 ] && printf '%s' "$D57_OUT" | grep -qF "qa-master ha cambiado desde el recibo"; then
    printf '  OK    %-46s exit 2 · "qa-master ha cambiado"\n' "D-057 · otro qa-master: NO MEDIDO"; ok=$((ok+1))
  else
    printf '  MAL   %-46s esperaba exit 2 y salio %s\n' "D-057 · otro qa-master: NO MEDIDO" "$D57_RC"; ko=$((ko+1))
  fi
  # el recibo que juzgo va en la salida: la fila de SEGUIMIENTO-14D solo se fia de
  # un .d057-ultima.txt que sea de ESTE recibo (scripts/apuntar-seguimiento.mjs)
  S57="$(grep -m1 '^SELLO:' "$D57/igual/.qa-recibo" | sed 's/^SELLO:[[:space:]]*//' | tr -d '\r')"
  d57 "D-057 · nombra el recibo que juzgo"              0 "D057-RECIBO: $S57"         igual
  # --except-verdict es --salvo-veredicto, y cambia lo que dice el recibo
  R57A="$(perl ../receipt.pl --verify --repo "$D57/igual" --for-deploy --except-verdict 2>&1 | tr -d '0-9')"
  R57B="$(perl ../receipt.pl --verificar --repo "$D57/igual" --para-desplegar --salvo-veredicto 2>&1 | tr -d '0-9')"
  R57C="$(perl ../receipt.pl --verificar --repo "$D57/igual" --para-desplegar 2>&1 | tr -d '0-9')"
  if [ "$R57A" = "$R57B" ] && printf '%s' "$R57C" | grep -qF "EN ROJO NO SE DESPLIEGA" \
     && ! printf '%s' "$R57A" | grep -qF "EN ROJO NO SE DESPLIEGA"; then
    printf '  OK    %-46s %s\n' "receipt.pl · --except-verdict = --salvo-veredicto" "y sin el, EN ROJO"; ok=$((ok+1))
  else
    printf '  MAL   %-46s %s\n' "receipt.pl · --except-verdict = --salvo-veredicto" "la salida no es la misma, o sin el no dice EN ROJO"; ko=$((ko+1))
  fi

  # ── 6-nov · LO QUE SALE DEL DOM (EST-06, EST-07: infi y ecomm) ──
  # 🔴 la puerta vuelve a medir produccion sin --dom (el del candidato es del
  #    candidato): alli EST-06 sale sin medir y EST-07 ni sale, y el FALLO viejo
  #    paraba como «NUEVO». Con el DOM de produccion se compara; sin el, o si no es
  #    de produccion, de la misma pagina, al mismo ancho y alto y de hoy: NO MEDIDO.
  d57_dom() {   # d57_dom <fichero> <innerWidth> <url> <horas de antiguedad>
    perl -MPOSIX=strftime -e 'my ($f, $w, $u, $h) = @ARGV; open my $o, ">", $f or die;
      print $o qq({ "innerWidth": $w, "innerHeight": 844, "url": "$u", "ts": ")
             . strftime("%Y-%m-%dT%H:%M:%SZ", gmtime(time - $h * 3600))
             . qq(", "http": 200, "titulo": "Escuela de musica", "hay_main": true, "secciones": 6, "texto_len": 4200,)
             . qq( "testigo": { "valido": true, "motivos": [] }, "screens": 5.0, "blocks": 8, "blocks_over_1screen": 0,)
             . qq( "ctas": 3, "buttons_visibles": 0, "max_gap_screens": 3.4, "es_pagina_prosa": false,)
             . qq( "filas_cojas": 1, "titulares_huerfanos": 0, "alturas_desiguales": 0, "listas_de_uno": 0 }\n)' "$@"
  }
  d57_dom "$D57/dom-cand.json" 390 https://d057.example/ 0
  d57_cand dom fixtures-d057/igual estructura --dom "$D57/dom-cand.json"
  d57_fila dom BASE.md "$B57" "| 2 · Puerta | EST-01, EST-06, EST-07 y EST-12 de la portada | qa-master | pendiente | 2099-12-31 | diseno |"
  d57 "D-057 · del DOM sin el de produccion: NO MEDIDO" 2 "D057_DOM_PRODUCCION en deploy.conf" dom
  d57 "D-057 · y EST-07 no sale NUEVO"                  2 "NO-MEDIDO FALLO EST-07    sale del DOM" dom
  d57_dom "$D57/dom-prod.json" 390 https://d057.example/ 1
  d57 "D-057 · del DOM, con el de produccion: PASA"     0 "D057-RESULTADO: PASA"      dom --dom-produccion "$D57/dom-prod.json"
  d57 "D-057 · y lo pasa por viejo"                     0 "D-057     FALLO EST-07"    dom --production-dom "$D57/dom-prod.json"
  d57_dom "$D57/dom-ancho.json" 1366 https://d057.example/ 1
  d57 "D-057 · DOM de produccion a otro ancho"          2 "innerWidth=1366 innerHeight=844 y el del candidato de 390x844" dom --dom-produccion "$D57/dom-ancho.json"
  d57_dom "$D57/dom-viejo.json" 390 https://d057.example/ 30
  d57 "D-057 · DOM de produccion de ayer"               2 "es de hace 30 h"           dom --dom-produccion "$D57/dom-viejo.json"
  d57_dom "$D57/dom-local.json" 390 http://127.0.0.1:8123/ 1
  d57 "D-057 · el DOM del candidato como produccion"    2 "es el del candidato, no el de produccion" dom --dom-produccion "$D57/dom-local.json"
  d57_dom "$D57/dom-otra.json" 390 https://d057.example/canto/ 1
  d57 "D-057 · DOM de produccion de otra pagina"        2 "otra pagina"               dom --dom-produccion "$D57/dom-otra.json"
  # 🔴 7-nov-2026 · LA FILA DE OTRA PAGINA NO VALE PARA ESTA. Lo que sale del DOM es
  #    de una pagina, y la fila se buscaba solo por el ID del check: en una web,
  #    EST-06 de una guia salio «igual en produccion» con la fila de EST-06 de la
  #    portada. Con la fila de una sola pagina, el mismo FALLO viejo pasaba en
  #    cualquier otra. Ahora la fila nombra el check Y la pagina del DOM, con la
  #    regla del navegador (1-quater): la ruta entera, no la de una hija.
  d57_dom "$D57/dom-canto-cand.json" 390 https://d057.example/canto/ 0
  rm -rf "${D57:?}/dom-canto"; cp -r fixtures-d057/igual "$D57/dom-canto"
  QA_RECIBOS_DIR="$D57/recibos" perl $QA http://d057.example/canto/ --repo "$D57/dom-canto" --candidato --solo estructura \
    --dom "$D57/dom-canto-cand.json" > "$D57/dom-canto.qa.txt" 2>&1
  d57_dom "$D57/dom-canto-prod.json" 390 https://d057.example/canto/ 1
  d57_fila dom-canto BASE.md "$B57" "| 2 · Puerta | EST-01, EST-06, EST-07 y EST-12 de la portada | qa-master | pendiente | 2099-12-31 | diseno |"
  d57 "D-057 · la fila de la portada no vale en /canto/" 1 "PARA      FALLO EST-07    ninguna fila de _seo/BASE.md ni del plan nombra EST-07 y la pagina /canto" \
      dom-canto --dom-produccion "$D57/dom-canto-prod.json"
  # EST-01 y EST-12 no salen del DOM: su fila se sigue buscando solo por el ID
  d57_fila dom-canto BASE.md "$B57" "| 2 · Puerta | EST-01 y EST-12 del sitio; EST-06 y EST-07 de \`/canto/\` a 390 | qa-master | pendiente | 2099-12-31 | diseno |"
  d57 "D-057 · la fila de /canto/ si vale"              0 "D-057     FALLO EST-07"    dom-canto --dom-produccion "$D57/dom-canto-prod.json"
  d57_fila dom-canto BASE.md "$B57" "| 2 · Puerta | EST-01 y EST-12 del sitio; EST-06 y EST-07 de \`/canto/coro/\` a 390 | qa-master | pendiente | 2099-12-31 | diseno |"
  d57 "D-057 · ni la de una pagina hija"                1 "PARA      FALLO EST-07    ninguna fila de _seo/BASE.md ni del plan nombra EST-07 y la pagina /canto" \
      dom-canto --dom-produccion "$D57/dom-canto-prod.json"
  d57 "D-057 · y el check del sitio, por su ID"         1 "D-057     FALLO EST-01"    dom-canto --dom-produccion "$D57/dom-canto-prod.json"
fi

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
# 🔴 5-nov-2026 · EL CAJON DEL CARRITO NO ES UN DESPLEGABLE DEL MENU. Una tienda
#    Shopify daba FALLO: su boton del carrito (aria-haspopup="dialog") vive en la
#    cabecera y su cajon tiene 2 enlaces. Se saltan los dialogos (por el control o
#    por el panel); el control rojo es la misma cabecera con el desplegable de
#    verdad en 2 destinos, que tiene que seguir en FALLO.
espera "EST-10 · el cajon del carrito y el buscador, no"   PASA  EST-10 \
       perl $QA https://climentmedia.com --repo fixtures-menu/cajon-carrito --candidato --una-sola --solo estructura --sin-recibo
texto  "EST-10 · y solo mira el panel del menu"            SI "1 panel(es) mirados" \
       perl $QA https://climentmedia.com --repo fixtures-menu/cajon-carrito --candidato --una-sola --solo estructura --sin-recibo
espera "EST-10 · con el cajon, uno de 2 sigue FALLO"       FALLO EST-10 \
       perl $QA https://climentmedia.com --repo fixtures-menu/cajon-y-pobre --candidato --una-sola --solo estructura --sin-recibo
texto  "EST-10 · y lo cuenta solo a el"                    SI "1 de 1 paneles mirados" \
       perl $QA https://climentmedia.com --repo fixtures-menu/cajon-y-pobre --candidato --una-sola --solo estructura --sin-recibo
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
# 🔴 26-sep-2026 · EL UMBRAL DEPENDE DE SI EL SITIO PUEDE CAPTAR. Una web personal
#    estatica -sin <form>, sin <script> ejecutable, sin <iframe> ni pixel- con su
#    privacidad enlazada salia FALLO por no tener una segunda pagina legal que
#    no necesita. Tres casos, y los dos rojos son los que impiden pasarse:
#    sin ninguna legal sigue fallando, y un <script> basta para volver a exigir 2
#    (el identificador de medicion puede vivir dentro del .js, como en consent.js).
espera "EST-12b · sin captacion, la privacidad basta"  PASA  EST-12b \
       perl $QA https://climentmedia.com --repo fixtures-footer/sin-captacion --candidato --una-sola --solo estructura --sin-recibo
espera "EST-12b · sin captacion y sin legal, FALLA"   FALLO EST-12b \
       perl $QA https://climentmedia.com --repo fixtures-footer/sin-captacion-sin-legal --candidato --una-sola --solo estructura --sin-recibo
espera "EST-12b · un <script> vuelve a exigir 2"      FALLO EST-12b \
       perl $QA https://climentmedia.com --repo fixtures-footer/script-sin-form --candidato --una-sola --solo estructura --sin-recibo
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
# 🔴 6-nov-2026 · LA RAIZ NO PIDE MIGAS AUNQUE DECLARE OTRO TIPO. Este caso esperaba AVISO en seo-pobre, que es la
#    RAIZ con data-tipo="hub": era el mismo falso positivo, porque el umbral es «todas menos la home» y la home es la
#    raiz. Una portada con data-tipo="nosotros" salia AVISO igual (visto en ROJO contra el gate anterior). El aviso
#    de verdad se prueba ahora donde vive, en una pagina interior: la MISMA pagina en /sobre/ sigue avisando.
espera "SEO-13 · la raiz (data-tipo hub) no pide migas" AUSENTE SEO-13 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-pobre --candidato --una-sola --solo seo --sin-recibo
espera "SEO-13 · la raiz con otro data-tipo no pide migas" AUSENTE SEO-13 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/seo-raiz-otro-tipo --candidato --una-sola --solo seo --sin-recibo
espera "SEO-13 · la misma pagina en /sobre/, AVISA"     AVISO SEO-13 \
       perl $QA https://climentmedia.com/sobre/ --repo fixtures-lenses/seo-raiz-otro-tipo --candidato --una-sola --solo seo --sin-recibo

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
# 🔴 5-nov-2026 · UNA WEB SIN FORMULARIO. A11Y-09/10/11 y MED-09/10/11 salian NO
#    VERIFICADO en cada recibo sin forma de cerrarlo (una web nuestra: 83 de 83
#    paginas sin <form>). Ahora se lee el ARBOL entero: sin <form> ni campos de
#    escribir en ninguna pagina ni en su JS, NO APLICA medido. Los dos primeros
#    salian NO VERIFICADO con el programa de antes; los otros cuatro son los que
#    NO pueden pasar. Y los seis de sin-formulario/ (mas abajo: campos sueltos
#    en un <div>, sin <form>) siguen en NO VERIFICADO: recogen datos igual.
espera "sin formulario en el arbol: A11Y-09 NO APLICA"     PASA    A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/arbol-sin-formulario --candidato --una-sola --solo a11y --sin-recibo
espera "sin formulario en el arbol: MED-10 NO APLICA"      PASA    MED-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/arbol-sin-formulario --candidato --una-sola --solo medicion --sin-recibo
espera "form en una pagina NO leida: sigue sin verificar" NOVERIF A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-fuera-de-la-lista --candidato --una-sola --solo a11y --sin-recibo
espera "...y en MEDICION tambien"                          NOVERIF MED-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-fuera-de-la-lista --candidato --una-sola --solo medicion --sin-recibo
espera "form creado desde el JS: sigue sin verificar"     NOVERIF A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-solo-en-js --candidato --una-sola --solo a11y --sin-recibo
espera "...y en MEDICION tambien"                          NOVERIF MED-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-solo-en-js --candidato --una-sola --solo medicion --sin-recibo
espera "campo de correo creado en JS, sin <form>: tampoco" NOVERIF A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/campo-creado-en-js --candidato --una-sola --solo a11y --sin-recibo
texto  "NO APLICA dice cuantas paginas leyo del arbol"     SI "0 <form> y 0 campos de escribir en sus 1 paginas" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/arbol-sin-formulario --candidato --una-sola --solo medicion --sin-recibo
# 🔴 5-nov-2026 · EL FORMULARIO QUE ESCRIBE EL JS. Una tienda nuestra monta su
#    formulario de leads en una cadena de su configurador, y sus paginas cargan el
#    JS como modulos (`import ... from './js/configurator.js'` en un <script
#    type="module"> en linea, sin un solo src). Las seis salian NO VERIFICADO en
#    cada recibo con el formulario entero escrito delante. Ahora se lee el marcado
#    de <form a </form> en el JS de la pagina, siguiendo sus import, y se mide con
#    las mismas reglas. Los casos ROJOS (-pobre) salian NO VERIFICADO con el
#    programa de antes: comprobado contra el. Y siguen NO VERIFICADO, diciendo por
#    que, el createElement de arriba, el formulario a trozos y el .js que nadie carga.
espera "form escrito en el JS, bien hecho: A11Y-09 PASA"   PASA    A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js --candidato --una-sola --solo a11y --sin-recibo
espera "...A11Y-10 PASA (aria-live en la cadena)"          PASA    A11Y-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js --candidato --una-sola --solo a11y --sin-recibo
espera "...A11Y-11 PASA (cepo dentro de un aria-hidden)"   PASA    A11Y-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js --candidato --una-sola --solo a11y --sin-recibo
espera "...MED-11 PASA (el boton se deshabilita)"          PASA    MED-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js --candidato --una-sola --solo medicion --sin-recibo
espera "...MED-09 PASA (la politica del pie)"              PASA    MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js --candidato --una-sola --solo medicion --sin-recibo
texto  "...MED-10 lee el destino del JS, no el del primer fetch" SI "lo envia /js/app.js por JS (CONFIG.LEAD_ENDPOINT)" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js --candidato --una-sola --solo medicion --sin-recibo
texto  "...y lo mide contra /api/lead"                     SI "https://climentmedia.com/api/lead" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js --candidato --una-sola --solo medicion --sin-recibo
espera "form escrito en el JS, MAL: A11Y-09 FALLA"         FALLO   A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js-pobre --candidato --una-sola --solo a11y --sin-recibo
espera "...A11Y-10 FALLA"                                  FALLO   A11Y-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js-pobre --candidato --una-sola --solo a11y --sin-recibo
espera "...A11Y-11 AVISA (el aria-hidden va delante, cerrado)" AVISO A11Y-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js-pobre --candidato --una-sola --solo a11y --sin-recibo
espera "...MED-11 FALLA"                                   FALLO   MED-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js-pobre --candidato --una-sola --solo medicion --sin-recibo
espera "...MED-10 sin destino legible: NO VERIFICADO, no «SIN action»" NOVERIF MED-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js-pobre --candidato --una-sola --solo medicion --sin-recibo
texto  "...y dice la expresion que no resolvio"            SI "«window.DESTINO_LEADS»" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-marcado-en-js-pobre --candidato --una-sola --solo medicion --sin-recibo
espera "form en un MODULO importado (sin src): A11Y-09 PASA" PASA  A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-en-modulo --candidato --una-sola --solo a11y --sin-recibo
espera "...MED-11 PASA (la guarda esta en el modulo)"      PASA    MED-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-en-modulo --candidato --una-sola --solo medicion --sin-recibo
texto  "...y el destino sale de ../config.js"              SI "lo envia /js/ui/formulario.js por JS (CONFIG.LEAD_ENDPOINT)" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-en-modulo --candidato --una-sola --solo medicion --sin-recibo
espera "un .js con form que NINGUNA pagina carga: sin verificar" NOVERIF A11Y-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-js-sin-cargar --candidato --una-sola --solo a11y --sin-recibo
texto  "...y dice cual"                                    SI "el arbol lo crea en el JS (/js/viejo.js)" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-js-sin-cargar --candidato --una-sola --solo a11y --sin-recibo
espera "form a trozos (sin su </form>): sin verificar"     NOVERIF MED-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-js-a-trozos --candidato --una-sola --solo medicion --sin-recibo
texto  "...y dice que va a trozos"                         SI "/app.js trae un <form> sin su </form> en el mismo texto" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/form-js-a-trozos --candidato --una-sola --solo medicion --sin-recibo
# El cepo dentro de un <p aria-hidden="true"> esta oculto al lector igual que si
# lo llevara el campo. Con el programa de antes salia AVISO en un formulario
# SERVIDO: el arreglo no es solo del JS. Su negativo es el -pobre de arriba: el
# aria-hidden de un <span> cerrado antes del campo no lo oculta, y sigue AVISO.
espera "cepo dentro de un bloque aria-hidden: A11Y-11 PASA" PASA   A11Y-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/cepo-dentro-de-oculto --candidato --una-sola --solo a11y --sin-recibo
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
echo "== SEO-18 a SEO-22 · LO QUE UN MOTOR DE RESPUESTAS SACA DE LA PAGINA · 7-nov-2026"
# 🔴 Un benchmark GEO para una universidad: los costes de la carrera, todos dentro de un acordeon cerrado;
#    17 paginas en ingles que eran cascaras; la marca nombrada de dos formas. Antes del check, un censo en
#    50 paginas de 10 sitios: 23 cifras que solo vivian dentro de un <details> cerrado, en 9 paginas, y dos
#    sitios con el nombre repartido. geo-mal tiene que avisar en los cuatro (son checks nuevos: contra el
#    gate anterior salen AUSENTE, en rojo); geo-bien lleva dentro lo que NO debe contar (el summary de un
#    bloque cerrado, un <details open>, la cifra que tambien sale fuera, la tabla de maqueta, la sociedad
#    anidada en el schema y el lugar al final de dos titles). Ver fixtures-geo/POR-QUE.txt.
QG="--candidato --solo seo --sin-recibo"
espera "SEO-18 · cifra solo en un bloque cerrado: AVISO" AVISO SEO-18 perl $QA $FU --repo fixtures-geo/geo-mal $QG
texto  "SEO-18 · nombra la de dentro, no la de fuera"  SI "(1: 14 días)" perl $QA $FU --repo fixtures-geo/geo-mal $QG
espera "SEO-18 · summary, open y la de fuera: PASA"    PASA  SEO-18 perl $QA $FU --repo fixtures-geo/geo-bien $QG
espera "SEO-19 · tabla sin <th>: AVISO"                AVISO SEO-19 perl $QA $FU --repo fixtures-geo/geo-mal $QG
espera "SEO-19 · con <th>: PASA"                       PASA  SEO-19 perl $QA $FU --repo fixtures-geo/geo-bien $QG
texto  "SEO-19 · la tabla de maqueta no se cuenta"     SI "DATO   1 tabla(s)" perl $QA $FU --repo fixtures-geo/geo-bien $QG
espera "SEO-20 · la marca de dos formas: AVISO"        AVISO SEO-20 perl $QA $FU --repo fixtures-geo/geo-mal $QG
texto  "SEO-20 · el final del title es una forma"      SI "«Marca» (title en 3)" perl $QA $FU --repo fixtures-geo/geo-mal $QG
espera "SEO-20 · una sola forma: PASA"                 PASA  SEO-20 perl $QA $FU --repo fixtures-geo/geo-bien $QG
texto  "SEO-20 · ni la sociedad anidada ni el lugar"   SI "«Marca Real» (og:site_name en 4, schema en 4, title en 2)" perl $QA $FU --repo fixtures-geo/geo-bien $QG
texto  "SEO-20 · la sociedad anidada no sale"          NO "Sociedad Detras" perl $QA $FU --repo fixtures-geo/geo-bien $QG
espera "SEO-21 · la cascara en ingles: AVISO"          AVISO SEO-21 perl $QA $FU --repo fixtures-geo/geo-mal $QG
texto  "SEO-21 · vacia y sin vuelta, contadas"         SI "1 con menos del 40 % de las palabras, 0 sin 200, 1 sin vuelta" perl $QA $FU --repo fixtures-geo/geo-mal $QG
espera "SEO-21 · traducida y con vuelta: PASA"         PASA  SEO-21 perl $QA $FU --repo fixtures-geo/geo-bien $QG
espera "SEO-21 · sin hreflang: PASA (decide SEO-17)"   PASA  SEO-21 perl $QA $FU --repo "$FSEO05/alineado" $QG
# SEO-22 · el autor y la fecha de un articulo (D-065 punto 8). Censo antes del check: un sitio firma sus 9
#    articulos como «<marca> Admin», otro nombra al autor solo por un @id de otra web, otro tiene 13 articulos
#    «modificados» anos antes de publicarse, y tres guias ensenan otro mes que su marcado. art-mal lleva un
#    articulo por cada cosa, y desde el 7-nov uno que ensena octubre con dateModified en noviembre (antes bastaba
#    con que se viera una de las dos fechas: un chat lo encontro en una guia sin aviso); art-bien, lo que NO debe contar (enlace por url sin barra final, @id definido en la
#    pagina, fecha solo por <time> o al mes, organizacion como autor, una pagina noindex, una
#    modificacion del mismo mes o escrita a la vista). Los 9 mutantes de
#    sus excepciones salieron en rojo (7-nov).
espera "SEO-22 · autor y fecha mal: AVISO"             AVISO SEO-22 perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · los cinco articulos, contados"        SI "5 de 5 articulo(s)" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · el usuario del gestor como autor"     SI "autor de relleno «Marca Admin»" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · modificado antes de publicado"        SI "publicado 2026-08-28, modificado 2024-05-06" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · el autor por un @id de otra web"      SI "1 autor sin nombre en el marcado" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · la pagina ensena otro mes"            SI "el marcado dice 2026-11-01, la pagina ensena «octubre de 2026»" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · se ve y no enlaza"                    SI "1 el autor no enlaza a su pagina" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · sin fecha en el marcado"              SI "1 sin fecha en el marcado" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · el autor que no sale en la pagina"    SI "1 el autor no se ve" perl $QA $FU --repo fixtures-geo/art-mal $QG
texto  "SEO-22 · se ve octubre y se modifico en nov."  SI "1 la modificacion no se ve" perl $QA $FU --repo fixtures-geo/art-mal $QG
espera "SEO-22 · lo que no cuenta: PASA"               PASA  SEO-22 perl $QA $FU --repo fixtures-geo/art-bien $QG
texto  "SEO-22 · la pagina noindex no cuenta"          SI "DATO   4 articulo(s)" perl $QA $FU --repo fixtures-geo/art-bien $QG
texto  "SEO-22 · modificada el mismo mes, o a la vista" NO "la modificacion no se ve" perl $QA $FU --repo fixtures-geo/art-bien $QG
espera "SEO-22 · sin articulos: PASA"                  PASA  SEO-22 perl $QA $FU --repo fixtures-geo/geo-bien $QG
texto  "SEO-22 · y dice por que"                       SI "ninguna pagina leida es un articulo" perl $QA $FU --repo fixtures-geo/geo-bien $QG

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
# 🔴 31-oct-2026 · EN INGLES. Ninguna palabra disparadora era inglesa: «we keep them for 12 months» salia FALLO
#    (climentmedia, T2). Fixture = med-bueno con la frase en ingles, y nada mas. Visto en ROJO contra el gate anterior.
espera "MED-09 · el plazo en ingles («keep them for 12 months»), PASA" PASA MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-ingles --candidato --una-sola --solo medicion --sin-recibo
# 🔴 21-sep-2026 · LA POLITICA EN OTRA RUTA. El gate la buscaba en cinco rutas
#    fijas; una web con un solo documento legal (`/mentions-legales/` con ancla
#    `#confidentialite`) salia FALLO con el plazo escrito. Ahora sigue tambien el
#    enlace de privacidad del formulario. Visto en ROJO contra el gate anterior.
#    Y el negativo es el que importa: encontrar la pagina NO es aprobar. Mismo
#    fixture con la frase del plazo quitada, y nada mas -> tiene que seguir FALLO.
espera "MED-09 · politica en /mentions-legales/, PASA"   PASA  MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-otra-ruta --candidato --una-sola --solo medicion --sin-recibo
espera "MED-09 · la misma, SIN plazo, sigue FALLO"      FALLO MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-otra-ruta-sin-plazo --candidato --una-sola --solo medicion --sin-recibo
# 🔴 31-oct-2026 · EL NEERLANDES. «Twaalf maanden na je aanvraag worden je gegevens
#    gewist»: plazo en letra, unidad neerlandesa y el plazo DELANTE del verbo. Salia
#    «sin plazo». El negativo es el mismo fixture con la frase del plazo quitada.
espera "MED-09 · politica en neerlandes con plazo, PASA"   PASA  MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-nl --candidato --una-sola --solo medicion --sin-recibo
espera "MED-09 · la misma, SIN plazo, sigue FALLO"        FALLO MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-nl-sin-plazo --candidato --una-sola --solo medicion --sin-recibo
# 🔴 6-nov-2026 · EL PORTUGUES, CON SU FRASE. A la lista le faltaban «quatro», «doze» y
#    «vinte e quatro», y una web en portugues espera a que su cliente le de el plazo:
#    con «doze meses» habria seguido «sin plazo». El fixture es la frase de esa web con
#    el plazo puesto; el negativo, la de hoy («apenas o tempo necessário») con la
#    «garantia de 3 anos» de otro bloque al lado: ni lo uno ni lo otro es un plazo.
espera "MED-09 · portugues, «doze meses», PASA"           PASA  MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-pt --candidato --una-sola --solo medicion --sin-recibo
espera "MED-09 · «o tempo necessário» no es plazo: FALLO" FALLO MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/med-plazo-pt-sin-plazo --candidato --una-sola --solo medicion --sin-recibo
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
# 🔴 22-sep-2026 · Y LA BUSQUEDA DEL 19-ago EMPEZABA POR LA PRIMERA URL DE LA
#   LISTA, no por la home (`$h` es `$URLS[0]`), y el DONDE decia la home aunque
#   el formulario saliera de otra pagina. Con dos formularios, el veredicto
#   dependia del orden: a.html primera, FALLO en la home -que no tiene
#   formulario-; b.html primera, PASA. Ahora la pagina la elige
#   pagina_del_formulario, la MISMA funcion que usa MEDICION, en orden fijo.
#   «b.html primera», el DONDE y «mide el de CONTACTO» se vieron en ROJO contra
#   el gate anterior (PASA, la home, FALLO).
espera "A11Y-10 · dos formularios, a.html primera: FALLO" FALLO A11Y-10 \
       perl $QA https://tienda.example/a.html https://tienda.example/b.html --repo fixtures-lenses/a11y-formulario-orden --candidato --solo accesibilidad --sin-recibo
espera "A11Y-10 · el mismo sitio, b.html primera: FALLO" FALLO A11Y-10 \
       perl $QA https://tienda.example/b.html https://tienda.example/a.html --repo fixtures-lenses/a11y-formulario-orden --candidato --solo accesibilidad --sin-recibo
texto  "A11Y-10 · y nombra la pagina del formulario"    SI "DONDE  https://tienda.example/a.html" \
       perl $QA https://tienda.example/a.html https://tienda.example/b.html --repo fixtures-lenses/a11y-formulario-orden --candidato --solo accesibilidad --sin-recibo
# 🔴 LAS DOS LENTES MIDEN EL MISMO FORMULARIO. Con un boletin en la portada y el
#   formulario de los leads en /contacto, accesibilidad juzgaba el boletin y
#   medicion el de contacto, en la misma corrida. Ahora las dos, el de contacto.
espera "A11Y-10 · portada y contacto: mide el de CONTACTO" PASA A11Y-10 \
       perl $QA https://tienda.example/ https://tienda.example/contacto.html --repo fixtures-lenses/a11y-formulario-contacto --candidato --solo accesibilidad --sin-recibo
espera "MED-11 · y MEDICION mide ese MISMO formulario" PASA MED-11 \
       perl $QA https://tienda.example/ https://tienda.example/contacto.html --repo fixtures-lenses/a11y-formulario-contacto --candidato --solo medicion --sin-recibo
# 🔴 22-sep-2026 · Y MEDICION TENIA EL MISMO DEFECTO, UN MES MAS. Sin --contacto
#   y sin una URL que nombrara «contacto», MED-10/11 (y la busqueda de la
#   politica de MED-09) miraban solo la PRIMERA URL de la lista. Con el
#   formulario en la portada y la portada SEGUNDA, las tres desaparecian: ni
#   FALLO ni NO VERIFICADO. Los dos ordenes tienen que dar el mismo veredicto;
#   los de «portada SEGUNDA» y los tres «sin ningun <form>» se vieron en ROJO
#   (AUSENTE) contra el gate anterior.
espera "MED-11 · form en la portada, portada PRIMERA: FALLO" FALLO MED-11 \
       perl $QA https://tienda.example/ https://tienda.example/servicios.html --repo fixtures-lenses/med-formulario-en-portada --candidato --solo medicion --sin-recibo
espera "MED-11 · el mismo sitio, portada SEGUNDA: FALLO" FALLO MED-11 \
       perl $QA https://tienda.example/servicios.html https://tienda.example/ --repo fixtures-lenses/med-formulario-en-portada --candidato --solo medicion --sin-recibo
espera "MED-09 · el mismo sitio, portada SEGUNDA: FALLO" FALLO MED-09 \
       perl $QA https://tienda.example/servicios.html https://tienda.example/ --repo fixtures-lenses/med-formulario-en-portada --candidato --solo medicion --sin-recibo
espera "MED-10 - sin ningun <form>: NO VERIFICADO"      NOVERIF MED-10 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/sin-formulario --candidato --una-sola --solo medicion --sin-recibo
espera "MED-11 - sin ningun <form>: NO VERIFICADO"      NOVERIF MED-11 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/sin-formulario --candidato --una-sola --solo medicion --sin-recibo
espera "MED-09 - sin ningun <form>: NO VERIFICADO"      NOVERIF MED-09 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/sin-formulario --candidato --una-sola --solo medicion --sin-recibo

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
# 🔴 5-nov-2026 · EST-02 imprimia «(0 de 121 paginas nuestras lo hacen)» y «decidir
#    de una vez», tres meses despues de que la mayoria de nuestras webs ya emitiera
#    data-sec: una web pregunto si se decidia o no. Sin data-sec sigue siendo NO
#    VERIFICADO (nunca PASA), dice el contrato y no lleva cifras de otras webs.
espera "EST-02 · sin data-sec, NO VERIFICADO"            NOVERIF EST-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/est-02b --candidato --una-sola --solo estructura --sin-recibo
texto  "EST-02 · y dice el contrato, no lo deja abierto" SI "el contrato esta decidido" \
       perl $QA https://climentmedia.com --repo fixtures-lenses/est-02b --candidato --una-sola --solo estructura --sin-recibo
texto  "EST-02 · sin la cifra vieja de otras webs"       NO "0 de 121" \
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
# 🔴 26-sep-2026 · ESTE CASO ESPERABA `PASA MED-02` Y ESE PASA ERA SOBRE NADA.
#    La pagina no carga ningun contenedor: solo NOMBRA uno en un comentario. Con
#    el gate de antes, la segunda busqueda de MED-01 leia el cuerpo sin quitar
#    comentarios, encontraba GTM-ZZZ9999 ahi y daba PASA «contenedor»; MED-02, que
#    SI quita comentarios, se saltaba la pagina y firmaba «PASA · 1 paginas» sin
#    haber comprobado ninguna. El caso fijaba como contrato ese verde vacio.
#    Lo que el caso quiere probar -que la prosa no hace FALLAR a MED-02- se
#    cumple mejor asi: sin contenedor, MED-01 dice «sin medicion ninguna» y
#    MED-02 no se emite, porque no hay nada cuyo orden mirar.
espera "comentarios · MED-02 no se cree la prosa"   AUSENTE MED-02 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo medicion --sin-recibo
espera "comentarios · MED-01 tampoco: prosa no es contenedor" AVISO MED-01 \
       perl $QA https://climentmedia.com --repo fixtures-lenses/comentarios --candidato --una-sola --solo medicion --sin-recibo
echo
echo "== LA RUTA DEL SCRIPT CON BARRAS DE WINDOWS · 7-nov-2026"
# 🔴 qa-master.pl buscaba anatomy.tsv y page-types.tsv junto a $0 con un patron
#    que solo partia por «/». Lanzado por su ruta de Windows (C:\...\gates\...,
#    o gates\qa-master.pl desde PowerShell), $0 lleva «\» y el directorio salia
#    «.»: desde una carpeta sin las tablas paraba con «no encuentro anatomy.tsv»,
#    y desde una con copias viejas (una carpeta de trabajo, 7-nov) las leia sin
#    decir nada y medía con las tablas de otro dia. Solo en Windows: en Linux «\»
#    no separa directorios, y ahi este caso no tiene nada que medir.
if command -v cygpath >/dev/null 2>&1; then
  WIN_QA="$(cygpath -w "$(cd .. && pwd)/qa-master.pl")"
  WIN_VACIO="$(mktemp -d)"
  texto "por su ruta de Windows, desde una carpeta sin tablas" SI "QA MAESTRO" \
    bash -c 'cd "$1" && perl "$2" http://site-a.example/ --solo a11y --sin-recibo --cache "$3"' _ "$WIN_VACIO" "$WIN_QA" "$CACHE"
  # page-types.tsv, igual, pero callado: sin el, «plp» volvia a ser un valor que no existe.
  texto "...y lee page-types.tsv (plp es un tipo)" SI "tipos: plp x1" \
    bash -c 'cd "$1" && perl "$2" https://climentmedia.com --repo "$3" --candidato --una-sola --solo estructura --sin-recibo' _ "$WIN_VACIO" "$WIN_QA" "$(pwd)/fixtures-type/plp"
  rm -rf "$WIN_VACIO"
else
  printf '  --    %-46s solo en Windows: aqui «\\» no separa directorios\n' "la ruta del script con barras de Windows"
fi

echo "== LA PRODUCCION DE MENTIRA NO HA TENIDO QUE INVENTARSE NADA · 22-sep-2026"
# 🔴 EL HEREDERO DEL «FIXTURE DE KINE HERMETICO» (11-ago-2026). Aquel contaba
#    los ficheros de la cache congelada antes y despues: uno nuevo solo podia
#    ser una DESCARGA, o sea media medida hecha contra produccion sin decirlo.
#    Aqui la pregunta es la misma y se contesta en el registro del servidor:
#      · 502 = un caso pidio un host que no tiene fixture. Un fixture INCOMPLETO
#        no da error: el gate mide lo que le devuelven, y un 502 es «algo».
#      · y tiene que haber pasado trafico de verdad: con el proxy mal exportado,
#        el registro sale VACIO, «0 hosts sin fixture» seria cierto, y el banco
#        entero habria medido otra cosa. Un registro vacio no es hermetico: es mudo.
if [ "$PROD_OK" != 1 ]; then
  printf '  N/M   %-46s NOT MEASURED (block): needs %s\n' "la produccion no se ha inventado nada" "$MOT_PROD"; nmb=$((nmb+1))
elif [ "$(ls -d fixtures-sites/*.example 2>/dev/null | wc -l | tr -d ' ')" = 0 ]; then
  printf '  N/M   %-46s NOT MEASURED (block): needs %s\n' "la produccion no se ha inventado nada" "$MOT_ANON"; nmb=$((nmb+1))
else
  servidas="$(awk -F'\t' '$1 != "CONNECT" && $3 != 502' "$CACHE/produccion.log" 2>/dev/null | wc -l | tr -d ' ')"
  sin_fixture="$(awk -F'\t' '$3 == 502' "$CACHE/produccion.log" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$servidas" -gt 0 ] && [ "$sin_fixture" = 0 ]; then
    printf '  OK    %-46s %s peticiones servidas, 0 a hosts sin fixture\n' "la produccion no se ha inventado nada" "$servidas"; ok=$((ok+1))
  elif [ "$servidas" = 0 ]; then
    printf '  MAL   %-46s su registro esta VACIO: el proxy no se ha usado\n' "la produccion no se ha inventado nada"; ko=$((ko+1))
  else
    printf '  MAL   %-46s %s peticiones a hosts SIN fixture:\n' "la produccion no se ha inventado nada" "$sin_fixture"; ko=$((ko+1))
    awk -F'\t' '$3 == 502 {print $1}' "$CACHE/produccion.log" | sort | uniq -c | head -10 | sed 's/^/          /'
  fi
fi

echo
echo "-----------------------------------------------------------------"
# ⚠️ run-all.sh lee el ULTIMO «OK n» y el ultimo «MAL n» de esta salida: nada
#    de lo que se imprime debajo puede llevar esa forma.
printf "  OK %d   ·   MAL %d\n" "$ok" "$ko"
if [ "$nm" -gt 0 ] || [ "$nmb" -gt 0 ]; then
  printf "  NOT MEASURED: %d case(s) and %d hand-written block(s), each named above (N/M)\n" "$nm" "$nmb"
  echo "  with the reason. Cases that need:"
  [ "$nm_repo" -gt 0 ]  && printf "      %-52s %d\n" "$MOT_REPO" "$nm_repo"
  [ "$nm_anon" -gt 0 ]  && printf "      %-52s %d\n" "$MOT_ANON" "$nm_anon"
  [ "$nm_https" -gt 0 ] && printf "      %-52s %d\n" "$MOT_HTTPS" "$nm_https"
  [ "$nm_vivo" -gt 0 ]  && printf "      %-52s %d\n" "$MOT_VIVO" "$nm_vivo"
  [ "$nm_lista" -gt 0 ] && printf "      %-52s %d\n" "$MOT_LISTA" "$nm_lista"
  [ "$nm_prod" -gt 0 ]  && printf "      %-52s %d\n" "$MOT_PROD" "$nm_prod"
fi
# 3 = no lo he medido todo · 1 = lo he medido y esta MAL · 0 = todo medido y bien.
# 🔴 Antes esto era `exit "$ko"`: con exactamente 3 casos MAL salia 3, y
#    run-all.sh lo habria contado como NO MEDIDO en vez de como rojo. Con 256,
#    salia 0. Un rojo tiene que salir 1 sea cual sea su recuento, y gana a un
#    hueco declarado: un rojo convertido en «no medido» es un fallo escondido.
if [ "$ko" -gt 0 ]; then
  echo "  🔴 Hay casos MAL: el gate NO se usa hasta arreglarlos."
  exit 1
fi
if [ "$nm" -gt 0 ] || [ "$nmb" -gt 0 ]; then
  echo "  Lo medido esta bien; lo NO MEDIDO no esta aprobado."
  exit 3
fi
echo "  El gate caza lo conocido, deja pasar lo bueno y no inventa."
exit 0
