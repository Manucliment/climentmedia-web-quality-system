#!/bin/sh
# =============================================================================
#  Banco de form-handler.php — el receptor de formularios de las webs de cliente
# =============================================================================
#  🔴 POR QUE EXISTE (18-ago-2026)
#  Este fichero se COPIA a `_deploy/contact.php` de cada web de cliente, y hasta
#  hoy **no lo validaba ninguna herramienta**: no habia `php` ni en la maquina de
#  Manuel ni en el servidor. Se leia a mano. Un error de sintaxis ahi es un 500
#  en el formulario de un cliente vivo, y el fichero existe precisamente porque
#  en Site A el formulario contestaba 200 sin que llegara nada.
#
#  Manuel autorizo instalar `php-cli` en example-host ese dia. SOLO la CLI:
#  ni `php-fpm` ni modulo de servidor web, asi que nada quedo accesible desde
#  fuera. Verificado: 0 servicios php, 0 paquetes fpm.
#
#  ⚠️ `php -l` dice que PARSEA, no que funcione. Por eso los casos 2 y 3 lo
#  EJECUTAN, y el 4 y el 5 son los controles de que este banco sabe ponerse rojo.
#
#  🔴 16-nov-2026 · LA FICHA DE LEAD (blueprint/05-forms.md, «The lead card»)
#  Un aviso que decia «Nombre, Email» obligo a sacar de la analitica, dos dias
#  despues, de que web venia el lead y que queria. Desde hoy la plantilla abre
#  el aviso con QUE BUSCA, DONDE ESTABA y COMO LLEGO, y el banco lo comprueba
#  enviando de verdad: `php -S` en 127.0.0.1 del host de medida (no se abre
#  nada hacia fuera, y se para al acabar), curl con cada forma de llegar, y el
#  correo a un fichero (`sendmail_path`): no sale ningun correo. Lo que se mira
#  es el aviso entero (asunto descodificado, orden de los bloques, destinatario,
#  Reply-To), la linea del disco y la respuesta (la pagina de gracias, o nada en
#  modo prueba). Y dos controles rojos: sin el bloque QUE BUSCA y sin Google Ads
#  en la llegada, el banco TIENE que fallar.
# =============================================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
REF="$(dirname "$DIR")"
# 21-sep-2026 · el host sale de ../nav-host.sh, como en la puerta. Aqui ponia
# `${NAV_HOST:-example-host}`, un marcador de la anonimizacion: este banco salio
# NO MEDIDO en cada bateria sin que ninguna lo contara como otra cosa que red.
. "$REF/nav-host.sh"
HOST="$(nav_host "$REF")"
if [ -z "$HOST" ]; then
  echo "BANCO · form-handler.php (php -l y ejecucion)"
  echo
  echo "  NO VERIFICADO · NAV_HOST sin configurar: ni el entorno ni"
  echo "  $(nav_host_conf "$REF") dicen desde donde medir."
  echo; echo "  NO MEDIDO (NAV_HOST sin configurar)"; exit 3
fi
# FORM_HANDLER=<ruta>: el banco contra otra copia (asi se vio en rojo la plantilla de antes de la ficha, 16-nov).
FH="${FORM_HANDLER:-$REF/form-handler.php}"
OK=0; MAL=0

echo "BANCO · form-handler.php (php -l, ejecucion y ficha de lead) · en $HOST"
echo

if [ ! -f "$FH" ]; then
  echo "  MAL   no encuentro $FH"; echo; echo "  OK 0 · MAL 1"; exit 1
fi
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOST" 'command -v php >/dev/null && command -v curl >/dev/null' </dev/null 2>/dev/null; then
  echo "  NO VERIFICADO · no se llega a $HOST o no tiene php y curl"
  echo "  Esto NO es un aprobado: sin interprete la plantilla no la valida nadie,"
  echo "  que es exactamente el estado del que viene este banco."
  # exit 3 = NO MEDIDO, la convencion de run-all.sh. NO es 1: un fallo medido y
  # un hueco declarado no pueden contarse igual, o la bateria acaba diciendo
  # «no se toca ninguna web» por un host que no existe en una instalacion limpia.
  echo; echo "  NO MEDIDO (sin host con php)"; exit 3
fi

REM="$(ssh "$HOST" 'echo $HOME' </dev/null 2>/dev/null)/.fh-pruebas"
LOC="$(mktemp -d 2>/dev/null || mktemp -d -t fh)"
ssh "$HOST" "rm -rf $REM && mkdir -p $REM" </dev/null >/dev/null 2>&1
scp -q "$FH" "$HOST:$REM/base.php" </dev/null
scp -q "$DIR/polyfill-mb.php" "$DIR/servicios.html" "$HOST:$REM/" </dev/null

comp () {                    # comp <titulo> <orden remota> <patron que DEBE salir>
  t="$1"; orden="$2"; pat="$3"
  out="$(ssh "$HOST" "cd $REM && $orden" </dev/null 2>&1)"
  case "$out" in
    *"$pat"*) printf "  ok    %-60s\n" "$t"; OK=$((OK+1)) ;;
    *)        printf "  MAL   %-60s esperaba «%s»\n" "$t" "$pat"
              printf "        salio: %s\n" "$(printf '%s' "$out" | head -1)"; MAL=$((MAL+1)) ;;
  esac
}
nocomp () {                  # nocomp <titulo> <orden remota> <patron que NO debe salir>
  t="$1"; orden="$2"; pat="$3"
  out="$(ssh "$HOST" "cd $REM && $orden" </dev/null 2>&1)"
  case "$out" in
    *"$pat"*) printf "  MAL   %-60s NO deberia decir «%s»\n" "$t" "$pat"; MAL=$((MAL+1)) ;;
    *)        printf "  ok    %-60s\n" "$t"; OK=$((OK+1)) ;;
  esac
}

echo "== LA PLANTILLA TAL CUAL SALE DE AQUI"
comp   "parsea sin errores de sintaxis"        "php -l base.php" "No syntax errors"
comp   "sin configurar, SE NIEGA a funcionar"  "php base.php"    "sin configurar"

echo
echo "== CONFIGURADA CON VALORES REALES"
# La clave de prueba del banco es «clave-del-banco»; en la plantilla va su sha256.
SHA="$( (printf 'clave-del-banco' | sha256sum 2>/dev/null || printf 'clave-del-banco' | shasum -a 256) | cut -c1-64)"
ssh "$HOST" "cd $REM && sed -e 's/RELLENAR@ejemplo.tld/info@ejemplo-real.be/g' -e 's/RELLENAR nombre del cliente/Cliente Real/' \
  -e 's/RELLENAR.ejemplo.tld/ejemplo-real.be/' -e \"s|__DIR__ . '/../_leads'|__DIR__ . '/_leads'|\" \
  -e \"s/^const TEST_KEY_SHA256 = '';/const TEST_KEY_SHA256 = '$SHA';/\" -e \"s/^const TEST_TO         = '';/const TEST_TO         = 'prueba@ejemplo-real.be';/\" \
  base.php > ok.php" </dev/null 2>/dev/null
nocomp "ya no se queja de estar sin configurar"     "php ok.php" "sin configurar"
nocomp "y no suelta avisos de PHP por el camino"    "php ok.php" "PHP Warning"
comp   "la copia configurada lleva la clave de prueba" "grep -c \"$SHA\" ok.php" "1"
comp   "y el disco dentro de la carpeta del banco"   "grep -c \"__DIR__ . '/_leads'\" ok.php" "1"

echo
echo "== CONTROLES DE QUE ESTE BANCO SABE PONERSE ROJO"
# 4 · si el linter no estuviera corriendo de verdad, esto pasaria
ssh "$HOST" "cd $REM && printf '<?php\nfunction rota( {\n' > rota.php" </dev/null 2>/dev/null
comp   "un fichero roto SI lo caza php -l"          "php -l rota.php" "syntax error"
# 5 · y si el guardia no existiera, el caso 2 estaria midiendo otra cosa
ssh "$HOST" "cd $REM && grep -v 'sin configurar' base.php > singuardia.php" </dev/null 2>/dev/null
nocomp "sin el guardia, la plantilla YA no avisa"   "php singuardia.php" "sin configurar"

# --- LA FICHA DE LEAD, enviando de verdad ------------------------------------
echo
echo "== LA FICHA DE LEAD (php -S en 127.0.0.1, el correo a un fichero)"
# Variantes: en frances (el idioma del buzon) y los dos controles rojos.
ssh "$HOST" "cd $REM && sed \"s/^const ALERT_LANG   = 'es';/const ALERT_LANG   = 'fr';/\" ok.php > fr.php \
  && grep -v \"^\\\$body .= \\\$L\\['want'\\]\" ok.php > sinbusca.php \
  && sed \"s/if (\\\$qv('gclid') !== ''/if (false \\&\\& \\\$qv('gclid') !== ''/\" ok.php > sinads.php" </dev/null 2>/dev/null
PORT=$(( 18000 + $$ % 1000 ))
ssh "$HOST" "cd $REM && { nohup php -d 'sendmail_path=cat >> $REM/correo.txt' -d auto_prepend_file=$REM/polyfill-mb.php -d display_errors=stderr -d error_reporting=-1 \
  -S 127.0.0.1:$PORT -t $REM > servidor.log 2>&1 < /dev/null & echo \$! > servidor.pid; }" </dev/null >/dev/null 2>&1
# FH_GUARDA=<carpeta>: guarda ahi cada aviso capturado (<caso>.correo), para leerlo o adjuntarlo a una revision.
para () {
  if [ -n "${FH_GUARDA:-}" ]; then mkdir -p "$FH_GUARDA" && cp "$LOC"/*.correo "$FH_GUARDA"/ 2>/dev/null; fi
  ssh "$HOST" "kill \$(cat $REM/servidor.pid) 2>/dev/null; rm -rf $REM" </dev/null >/dev/null 2>&1; rm -rf "$LOC"
}
trap para EXIT
listo=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  c="$(ssh "$HOST" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/ok.php" </dev/null 2>/dev/null)"
  [ "$c" = "405" ] && { listo=1; break; }
  sleep 1
done
if [ "$listo" != 1 ]; then
  printf "  MAL   %-60s\n" "php -S no arranca en 127.0.0.1:$PORT (servidor.log: $(ssh "$HOST" "head -c 200 $REM/servidor.log" </dev/null 2>/dev/null))"
  MAL=$((MAL+1))
else
  # envia <caso> <fichero php> <cabeceras de curl> <campo=valor>...
  # Guarda en $LOC/<caso>: la respuesta (cabeceras y cuerpo), el correo tal cual
  # le llega a sendmail, el asunto descodificado y la ultima linea del disco.
  envia () {
    caso="$1"; php="$2"; extra="$3"; shift 3
    datos=""
    for kv in "$@"; do datos="$datos --data-urlencode '$kv'"; done
    ssh "$HOST" "cd $REM && : > correo.txt && rm -rf _leads && curl -s -i $extra $datos http://127.0.0.1:$PORT/$php; \
      echo; echo '=== CORREO'; cat correo.txt; echo '=== DISCO'; cat _leads/leads-*.jsonl 2>/dev/null | tail -1" \
      </dev/null > "$LOC/$caso" 2>&1
    sed -n 's/^Subject: =?UTF-8?B?\(.*\)?=\r\{0,1\}$/\1/p' "$LOC/$caso" | head -1 | base64 -d > "$LOC/$caso.asunto" 2>/dev/null
    sed -n '/^=== CORREO/,/^=== DISCO/p' "$LOC/$caso" | tr -d '\r' > "$LOC/$caso.correo"
    sed -n '/^=== DISCO/,$p' "$LOC/$caso" > "$LOC/$caso.disco"
  }
  si ()   { t="$1"; f="$2"; p="$3"           # el fichero lleva el texto (fijo)
    if grep -qF -- "$p" "$LOC/$f"; then printf "  ok    %-60s\n" "$t"; OK=$((OK+1))
    else printf "  MAL   %-60s esperaba «%s»\n" "$t" "$p"; printf "        %s: %s\n" "$f" "$(head -c 300 "$LOC/$f" | tr '\n' ' ')"; MAL=$((MAL+1)); fi; }
  no ()   { t="$1"; f="$2"; p="$3"           # el fichero NO lleva el texto
    if grep -qF -- "$p" "$LOC/$f"; then printf "  MAL   %-60s NO deberia decir «%s»\n" "$t" "$p"; MAL=$((MAL+1))
    else printf "  ok    %-60s\n" "$t"; OK=$((OK+1)); fi; }
  # El cuerpo del aviso ABRE con el bloque 1, y los cuatro van en orden.
  abre () { t="$1"; f="$2"; p="$3"
    primera="$(awk 'c&&NF{print;exit} /^$/&&!c&&s{c=1} /^=== CORREO/{s=1}' "$LOC/$f")"
    if [ "$primera" = "$p" ]; then printf "  ok    %-60s\n" "$t"; OK=$((OK+1))
    else printf "  MAL   %-60s la primera linea es «%s»\n" "$t" "$primera"; MAL=$((MAL+1)); fi; }
  orden () { t="$1"; f="$2"; shift 2; ant=0; bien=1
    for p in "$@"; do n="$(grep -nxF -- "$p" "$LOC/$f" | head -1 | cut -d: -f1)"
      if [ -z "$n" ] || [ "$n" -le "$ant" ]; then bien=0; break; fi; ant="$n"; done
    if [ "$bien" = 1 ]; then printf "  ok    %-60s\n" "$t"; OK=$((OK+1))
    else printf "  MAL   %-60s falta o fuera de orden: «%s»\n" "$t" "$p"; MAL=$((MAL+1)); fi; }
  palabras () { t="$1"; f="$2"; max="$3"     # el «que busca» del asunto, ≤ max palabras
    q="$(sed 's/^\[[^]]*\] //; s/ · .*$//' "$LOC/$f")"; n="$(printf '%s' "$q" | wc -w | tr -d ' ')"
    if [ "$n" -le "$max" ] && [ "$n" -gt 0 ]; then printf "  ok    %-60s\n" "$t"; OK=$((OK+1))
    else printf "  MAL   %-60s %s palabras: «%s»\n" "$t" "$n" "$q"; MAL=$((MAL+1)); fi; }

  BASE="name=Ana Prueba|phone=600111222|email=ana@ejemplo-real.be|city=Centro|consent=1|lang=es"
  MSG="message=Quiero saber si podeis venir a casa los martes por la tarde porque mi madre no puede moverse bien desde la operacion de cadera del mes pasado y necesita"
  IFS_OLD="$IFS"; IFS='|'; set -- $BASE; IFS="$IFS_OLD"

  echo "-- desde un anuncio de Google (gclid y campana), desde el bloque hero"
  envia ads ok.php "" "$@" "need=Fisioterapia a domicilio" "$MSG" "page=/servicios" "cta=hero" \
    "ref=https://www.ejemplo-real.be/precios" "qs=?gclid=abc123&utm_source=google&utm_campaign=marca" "title=no se usa"
  si    "va a la pagina de gracias"                     ads "Location: /merci"
  si    "el asunto: [web] que busca · como llego"       ads.asunto "[Cliente Real] Fisioterapia a domicilio — Centro · Google Ads"
  palabras "el que busca del asunto, 8 palabras o menos" ads.asunto 8
  abre  "el aviso ABRE con QUE BUSCA"                   ads.correo "QUÉ BUSCA"
  orden "y los cuatro bloques van en orden"             ads.correo "QUÉ BUSCA" "DÓNDE ESTABA" "CÓMO LLEGÓ" "QUIÉN ES Y CÓMO CONTESTARLE"
  si    "la opcion que marco abre el bloque 1"          ads.correo "Fisioterapia a domicilio — Centro"
  si    "con las 20 primeras palabras del mensaje"      ads.correo "« Quiero saber si podeis venir a casa los martes por la tarde porque mi madre no puede moverse bien desde… »"
  si    "y TODOS los campos con su etiqueta"            ads.correo "$(printf '  %-14s %s' 'Telefono:' 600111222)"
  si    "la pagina: el titulo del .html servido y la ruta" ads.correo "Página: Servicios a domicilio & precios (/servicios)"
  si    "el bloque que abrio el formulario (data-cta)"  ads.correo "Bloque del formulario: hero"
  si    "la pagina anterior del sitio (con www)"        ads.correo "Página anterior: /precios"
  si    "la pagina de entrada: NO MEDIDO en la fase 1"  ads.correo "Página de entrada de la visita: NO MEDIDO (no se guarda nada en el navegador)"
  si    "como llego, en palabras y con la campana"      ads.correo "Google Ads (clic en un anuncio) · campaña marca"
  si    "a quien contestar"                             ads.correo "Contestar: responder a este correo (va a ana@ejemplo-real.be)"
  si    "dispositivo e idioma de la pagina"             ads.correo "dispositivo: escritorio · idioma de la página: es"
  si    "al pie, la web y la referencia"                ads.correo "Web: ejemplo-real.be · ref. "
  si    "va al buzon del cliente"                       ads.correo "To: info@ejemplo-real.be"
  si    "Reply-To = quien escribe (igual que antes)"    ads.correo "Reply-To: Ana Prueba <ana@ejemplo-real.be>"
  si    "el disco lleva la ficha: como llego"           ads.disco '"llegada":"Google Ads (clic en un anuncio) · campaña marca"'
  si    "el disco lleva la ficha: que busca y bloque"   ads.disco '"busca":"Fisioterapia a domicilio — Centro"'
  si    "el disco lleva la ficha: el bloque"            ads.disco '"bloque":"hero"'
  si    "el disco lleva el gclid"                       ads.disco '"gclid":"abc123"'

  echo "-- desde Google organico, en movil, sin data-cta"
  envia org ok.php "-A 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148'" "$@" "need=Fisioterapia a domicilio" "page=/" "ref=https://www.google.com/"
  si    "Google organico en el asunto"                  org.asunto "· Google orgánico"
  si    "la pagina anterior dice de donde venia"        org.correo "Página anterior: ninguna en la web (venía de google.com)"
  si    "sin data-cta: NO MEDIDO con el porque"         org.correo "Bloque del formulario: NO MEDIDO (el formulario no lleva data-cta)"
  si    "un iPhone es movil"                            org.correo "dispositivo: móvil"

  echo "-- directo, sin mensaje ni opcion"
  envia dir ok.php "" "$@" "page=/contacto"
  si    "directo en el asunto"                          dir.asunto "· directo"
  si    "sin opcion: que busca es la ciudad marcada"    dir.asunto "[Cliente Real] Centro · directo"
  si    "la pagina anterior: ninguna"                   dir.correo "Página anterior: ninguna (entró directamente en esta página)"
  si    "una pagina sin .html: solo la ruta"            dir.correo "Página: /contacto"

  echo "-- desde otra pagina del sitio, sin parametros"
  envia sitio ok.php "" "$@" "page=/contacto" "ref=https://ejemplo-real.be/blog/una-guia"
  si    "desconocido, y dice por que"                   sitio.correo "Desconocido: la visita empezó en otra página del sitio"
  si    "con la pagina anterior del sitio"              sitio.correo "Página anterior: /blog/una-guia"

  echo "-- Meta, un enlace marcado de prueba, un asistente de IA y otro sitio"
  envia meta ok.php "" "$@" "page=/" "qs=?fbclid=xyz"
  si    "fbclid es Meta"                                meta.asunto "· Meta"
  envia prueba ok.php "" "$@" "page=/" "qs=?utm_source=prueba&utm_medium=correo"
  si    "utm_source=prueba se lee tal cual"             prueba.correo "Enlace marcado: prueba / correo"
  si    "y en el asunto"                                prueba.asunto "· prueba"
  envia ia ok.php "" "$@" "page=/" "ref=https://chatgpt.com/"
  si    "un asistente de IA"                            ia.correo "Asistente de IA: chatgpt.com"
  envia otro ok.php "" "$@" "page=/" "ref=https://directorio.example/ficha"
  si    "otro sitio, con su dominio"                    otro.asunto "· otro: directorio.example"

  echo "-- un campo que el receptor no conoce no se pierde"
  envia otros ok.php "" "$@" "page=/" "presupuesto=entre 500 y 800"
  si    "va a «Otros campos» en el aviso"               otros.correo "    presupuesto: entre 500 y 800"
  si    "y en el disco"                                 otros.disco '"otros":{"presupuesto":"entre 500 y 800"}'

  echo "-- segunda fase: la pagina de entrada, si el formulario la manda"
  envia fase2 ok.php "" "$@" "page=/" "landing=/blog/una-guia" "pages=4"
  si    "pagina de entrada y paginas vistas"            fase2.correo "Página de entrada de la visita: /blog/una-guia · 4 páginas vistas"
  envia sincons ok.php "" "$@" "page=/" "consent_analytics=denied"
  si    "sin consentimiento: NO MEDIDO con el porque"   sincons.correo "NO MEDIDO (sin consentimiento de analítica)"

  echo "-- modo prueba: con la cookie, solo a TEST_TO y sin pagina de gracias"
  envia test ok.php "-b fh_test=clave-del-banco" "$@" "page=/" "qs=?utm_source=prueba"
  si    "va SOLO a la direccion de prueba"              test.correo "To: prueba@ejemplo-real.be"
  no    "no va al buzon del cliente"                    test.correo "To: info@ejemplo-real.be"
  si    "el asunto lleva TEST"                          test.asunto "· prueba · TEST"
  abre  "el aviso abre diciendo que es una prueba"      test.correo "*** PRUEBA TÉCNICA: no es un cliente, no hay nada que hacer. ***"
  no    "sin pagina de gracias (no cuenta conversion)"  test "Location: /merci"
  si    "y la respuesta lo dice"                        test "TEST recibido"
  si    "el disco lo marca como prueba"                 test.disco '"prueba":true'
  envia malacookie ok.php "-b fh_test=otra-clave" "$@" "page=/"
  si    "con otra clave, es un envio normal"            malacookie.correo "To: info@ejemplo-real.be"
  si    "y va a la pagina de gracias"                   malacookie "Location: /merci"

  echo "-- lo que ya funcionaba sigue igual"
  envia trampa ok.php "" "$@" "page=/" "website=http://spam.example"
  si    "el campo trampa finge exito"                   trampa "Location: /merci"
  no    "y no manda aviso"                              trampa.correo "To:"
  envia inyecta ok.php "" "name=Ana
Bcc: victima@example.com" "phone=600111222" "email=ana@ejemplo-real.be" "city=Centro" "consent=1" "page=/"
  if grep -q '^Bcc:' "$LOC/inyecta.correo"; then printf "  MAL   %-60s\n" "un salto de linea en el nombre metio una cabecera Bcc"; MAL=$((MAL+1))
  else printf "  ok    %-60s\n" "un salto de linea en el nombre no mete cabeceras"; OK=$((OK+1)); fi
  si    "(el nombre llega en una linea)"                inyecta.correo "Reply-To: Ana Bcc: victima@example.com <ana@ejemplo-real.be>"
  envia falta ok.php "" "name=Ana" "email=ana@ejemplo-real.be" "consent=1"
  si    "sin un obligatorio: 422"                       falta "422"
  no    "y no manda aviso"                              falta.correo "To:"

  echo "-- en el idioma del buzon"
  envia fr fr.php "" "$@" "need=Osteo a domicile" "page=/" "ref=https://www.google.be/"
  abre  "en frances abre con CE QU'IL CHERCHE"          fr.correo "CE QU'IL CHERCHE"
  si    "y la llegada en frances"                       fr.correo "Google naturel"

  echo "-- controles: el banco TIENE que ponerse rojo"
  envia rojo1 sinbusca.php "" "$@" "need=Fisioterapia a domicilio" "page=/"
  if [ "$(awk 'c&&NF{print;exit} /^$/&&!c&&s{c=1} /^=== CORREO/{s=1}' "$LOC/rojo1.correo")" = "QUÉ BUSCA" ]; then
    printf "  MAL   %-60s\n" "sin el bloque QUE BUSCA el aviso sigue abriendo con el"; MAL=$((MAL+1))
  else printf "  ok    %-60s\n" "sin el bloque QUE BUSCA, «abre» lo caza"; OK=$((OK+1)); fi
  envia rojo2 sinads.php "" "$@" "page=/" "qs=?gclid=abc123"
  if grep -qF "Google Ads" "$LOC/rojo2.correo"; then
    printf "  MAL   %-60s\n" "sin la regla de gclid sigue diciendo Google Ads"; MAL=$((MAL+1))
  else printf "  ok    %-60s\n" "sin la regla de gclid, ya no dice Google Ads"; OK=$((OK+1)); fi
  w="$(ssh "$HOST" "grep -c 'PHP \\(Warning\\|Notice\\|Deprecated\\|Fatal\\)' $REM/servidor.log" </dev/null 2>/dev/null)"
  if [ "${w:-0}" = "0" ]; then printf "  ok    %-60s\n" "ni un aviso de PHP en todo el servidor de prueba"; OK=$((OK+1))
  else printf "  MAL   %-60s %s avisos\n" "avisos de PHP en el servidor de prueba" "$w"
    ssh "$HOST" "grep 'PHP ' $REM/servidor.log | head -3" </dev/null 2>/dev/null | sed 's/^/        /'; MAL=$((MAL+1)); fi
fi

echo
printf "  OK %d · MAL %d\n" "$OK" "$MAL"
[ "$MAL" -eq 0 ] || exit 1
