#!/usr/bin/env bash
# =============================================================================
#  deploy.sh  ·  LA PUERTA
# =============================================================================
#  Se lanza asi (ruta absoluta a las dos cosas: `bash` NO esta en el PATH de
#  PowerShell, y `Program Files` lleva espacio, por eso el `&`):
#
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/deploy.sh" /path/to/site-a-web
#
#  Sin --subir NO SUBE NADA: comprueba, enseña el comando exacto que ejecutaria,
#  y para. Subir es un gesto explicito.
#
#    deploy.sh REPO                 comprueba (no sube)
#    deploy.sh REPO --subir         comprueba, sube, y verifica lo servido
#    deploy.sh REPO --servido       solo la verificacion de despues (G11)
#    deploy.sh REPO --aun-asi "..." permite subir con cosas SIN MIRAR,
#                                      dejando el motivo escrito en el historial
#
#  🔴 EL FLUJO, Y SON DOS MOMENTOS (11-ago-2026)
#  ---------------------------------------------
#      1 · MEDIR EL CANDIDATO
#            perl qa-master.pl https://dominio.tld --repo REPO --candidato
#          Mide EL ARBOL DEL REPO (servido por HTTP en local), no produccion.
#          Escribe el recibo con MEDIDO-CONTRA: CANDIDATO.
#      2 · SUBIR
#            deploy.sh REPO --subir
#      3 · G11 · LO SERVIDO FRENTE AL RECIBO   (lo hace solo el paso anterior)
#            deploy.sh REPO --servido
#
#  Los dos momentos hacen falta y ninguno sustituye al otro:
#      · el candidato contesta «¿lo que voy a subir esta bien?»
#      · G11 contesta «¿el visitante esta viendo eso?»
#  EL FALLO QUE ESTO ARREGLA, encontrado en el primer uso real de la puerta: el
#  recibo sellaba el arbol del repo con un veredicto sacado de medir PRODUCCION.
#  site-d salio «VEREDICTO: FALLA» por los 11 defectos que el despliegue
#  pendiente venia a arreglar: la puerta se negaba a subir el arreglo porque
#  produccion estaba mal, y produccion estaba mal porque no se habia subido el
#  arreglo. El gate bloqueaba justo la mejora que existe para permitir. Y al
#  reves era peor: un arbol con un defecto NUEVO sacaba recibo verde si la web
#  ya subida estaba bien.
#
#  Un recibo de PRODUCCION sigue valiendo para subir —no se rompe el flujo de
#  antes— pero se avisa en voz alta de que su veredicto NO habla del arbol que
#  se esta subiendo. El recibo bueno para esta puerta es el de CANDIDATO.
#
#  POR QUE EXISTE
#  --------------
#  «En rojo no se despliega» estaba escrito en UN sitio (site-d-web/CLAUDE.md)
#  y era una frase. Aqui es una condicion de arranque: si el recibo no vale, el
#  script no llega a la linea que sube.
#
#  Y despues de subir hace lo que NADIE hacia: comprobar que lo servido es lo
#  medido. El 10-ago el arreglo de contraste de site-d llevaba horas en el
#  repo con todos los gates en verde, y produccion seguia sirviendo el CSS
#  viejo. Ningun gate lo vio porque ninguno miraba DESPUES.
#
#  LO QUE ESTE FICHERO **NO** HACE
#  -------------------------------
#  No sabe subir. Cada web sube distinto (scp a Hostinger, tar|ssh a Caddy,
#  Vercel) y ese conocimiento ya vive en cada repo. Este script no lo duplica:
#  lo LLAMA, desde `SUBIDA=` de <repo>/_deploy/deploy.conf. Reescribirlo aqui
#  seria inventar cinco despliegues nuevos sin probar ninguno.
# =============================================================================
set -u

REF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=""; SUBIR=0; SOLO_SERVIDO=0; AUN_ASI=""; HORAS=12; VER_SUBIDA=0

while [ $# -gt 0 ]; do
  # English aliases. Additive: they cannot break an existing invocation.
  # Both spellings are supported and documented in gates/README.md.
  case "$1" in
    --upload)      set -- "--subir" "${@:2}" ;;
    --served)      set -- "--servido" "${@:2}" ;;
    --show-upload) set -- "--ver-subida" "${@:2}" ;;
    --anyway)      set -- "--aun-asi" "${@:2}" ;;
    --hours)       set -- "--horas" "${@:2}" ;;
  esac
  case "$1" in
    --subir)    SUBIR=1 ;;
    --servido)  SOLO_SERVIDO=1 ;;
    --ver-subida) VER_SUBIDA=1 ;;
    --aun-asi)  shift; AUN_ASI="${1:-}" ;;
    --horas)    shift; HORAS="${1:-12}" ;;
    -h|--help)  sed -n '2,66p' "${BASH_SOURCE[0]}"; exit 2 ;;
    -*)         echo "opcion desconocida: $1"; exit 2 ;;
    *)          REPO="$1" ;;
  esac
  shift
done

[ -n "$REPO" ] || { echo "uso: deploy.sh REPO [--subir] [--servido]"; exit 2; }
[ -d "$REPO" ] || { echo "no existe el repo: $REPO"; exit 2; }
REPO="$(cd "$REPO" && pwd)"

CONF="$REPO/_deploy/deploy.conf"
linea() { printf '%s\n' "------------------------------------------------------------------------------"; }

echo "=============================================================================="
echo "  DESPLIEGUE  ·  $REPO"
echo "=============================================================================="

# ── 0 · el repo tiene que declarar como se sube ──────────────────────────────
#    Sin esto el script no puede saber que ejecutar, y adivinarlo seria peor que
#    pararse: un despliegue inventado sube a un sitio que nadie ha comprobado.
if [ ! -f "$CONF" ]; then
  echo
  echo "  NO HAY $CONF"
  echo
  echo "  Este repo no declara como se despliega, asi que no se despliega. Escribe"
  echo "  ese fichero con dos lineas (hay un ejemplo comentado en"
  echo "  $REF/config/deploy.conf.example):"
  echo
  echo "      SITIO=https://dominio.tld         # o SITE="
  echo "      SUBIDA=_deploy/subir.sh          # o UPLOAD= · relativo al repo, o comando entero"
  echo
  echo "  🔴 SUBIDA tiene que subir EL ARBOL ENTERO, no un fichero suelto. Si sube"
  echo "     solo el CSS, la verificacion de despues (G11) lo dira: comparara los"
  echo "     $(perl "$REF/receipt.pl" --arbol --repo "$REPO" 2>/dev/null | awk '/FICHEROS/{print $2}') ficheros del recibo con lo servido."
  exit 2
fi
# shellcheck disable=SC1090
. "$CONF"
# 26-sep-2026 · La plantilla publica (config/deploy.conf.example) escribe SITE y
# UPLOAD, y los cuatro caminos SPEC_MODE: aqui solo se leian los nombres en
# castellano, asi que siguiendo la plantilla al pie de la letra la puerta salia con
# «no define SITIO» y el paso 2-bis quedaba NO MEDIDO. Mismo patron que las claves
# de navegador del 21-sep, mas abajo: los dos nombres valen.
SITIO="${SITIO:-${SITE:-}}"
SUBIDA="${SUBIDA:-${UPLOAD:-}}"
MODO_SPEC="${MODO_SPEC:-${SPEC_MODE:-}}"
[ -n "$SITIO" ] || { echo "  $CONF no define SITIO"; exit 2; }

# ── modo «enseñame que subirias» ─────────────────────────────────────────────
#  🔴 NO PASA POR EL GATE, Y ES A PROPOSITO. Esto no despliega: corre la subida
#  EN SECO para contestar una pregunta de diagnostico —«¿que le pasaria al
#  contact.php?»— y escribe cero bytes. Exigirle recibo verde lo haria inutil
#  justo cuando hace falta: cuando el recibo esta en rojo y hay que decidir que
#  se arregla. Un gate que impide MIRAR no protege nada; solo empuja a mirar por
#  fuera, que es de donde venimos.
#  Los dos cerrojos son los mismos del ensayo de mas abajo: el repo tiene que
#  declarar SUBIDA_ENSAYO=1 y SUBIDA tiene que ser un script suyo.
if [ "$VER_SUBIDA" = 1 ]; then
  # shellcheck disable=SC1090
  . "$CONF"
  SUBIDA="${SUBIDA:-}"
  linea; echo "  EN SECO · que haria la subida (NO despliega, NO escribe)"; linea
  if [ "${SUBIDA_ENSAYO:-0}" != 1 ] || [ -z "$SUBIDA" ] || [ ! -f "$REPO/$SUBIDA" ]; then
    echo "  $CONF no declara SUBIDA_ENSAYO=1 con un script propio en SUBIDA."
    echo "  Sin eso no se corre nada: un comando que no entiende --ensayo se"
    echo "  comeria la bandera como un argumento mas y subiria de verdad."
    exit 2
  fi
  bash "$REPO/$SUBIDA" --ensayo
  RC=$?
  echo
  echo "  Esto NO sustituye al gate. Para desplegar sigue haciendo falta recibo"
  echo "  verde: deploy.sh \"$REPO\" --subir"
  exit $RC
fi

# ── modo «solo verificar lo servido» ─────────────────────────────────────────
if [ "$SOLO_SERVIDO" = 1 ]; then
  linea; echo "  G11 · lo servido frente al recibo"; linea
  perl "$REF/receipt.pl" --servido --repo "$REPO" --sitio "$SITIO"
  exit $?
fi

# ── 0-bis · ¿CONTRA QUE SE MIDIO EL RECIBO? ──────────────────────────────────
#    Se lee y se dice ANTES del gate, no despues, y a proposito: cuando el gate
#    sale en ROJO es justo cuando hace falta saberlo. Un recibo de PRODUCCION en
#    rojo puede estar rojo por defectos que el arbol de al lado YA arregla —el
#    bucle de site-d— y quien lo lea tiene que poder distinguir «esto que voy
#    a subir esta mal» de «lo que hay subido esta mal».
#    Un recibo sin la linea es anterior al 11-ago-2026: eran todos de PRODUCCION.
MEDIDO="$(grep -m1 '^MEDIDO-CONTRA:' "$REPO/.qa-recibo" 2>/dev/null | sed 's/^MEDIDO-CONTRA:[[:space:]]*//' | tr -d '\r')"
[ -n "$MEDIDO" ] || MEDIDO="PRODUCCION"

# ── 1 · EL GATE ──────────────────────────────────────────────────────────────
linea; echo "  1 · el recibo"; linea
perl "$REF/receipt.pl" --verificar --repo "$REPO" --para-desplegar --horas "$HORAS"
GATE=$?

# ── 1-bis · SE DICE CONTRA QUE SE MIDIO, PASE O NO PASE ──────────────────────
#    Un recibo de CANDIDATO habla del arbol que se va a subir: es el que vale
#    aqui. Uno de PRODUCCION habla de la web que YA esta subida —sella este
#    arbol, pero su veredicto no es de este arbol— y por eso se acepta con un
#    aviso en voz alta en vez de en silencio. Silencio es como se leia antes.
#    (cuando el recibo VALE, esto ya lo ha impreso receipt.pl con mas detalle;
#     aqui se dice solo en el camino rojo, que es donde receipt.pl no llega)
if [ "$GATE" != 0 ]; then
  echo
  if [ "$MEDIDO" = "CANDIDATO" ]; then
    echo "  medido contra: CANDIDATO · el veredicto es del arbol que se va a subir."
  else
    echo "  ⚠ medido contra: PRODUCCION · el veredicto es de la web YA SUBIDA."
    echo "    Este recibo sella este arbol, pero NO lo ha medido: si el repo trae un"
    echo "    arreglo sin subir o un defecto nuevo, aqui no consta ninguno de los dos."
  fi
fi

if [ "$GATE" != 0 ]; then
  echo
  echo "  🔴 NO SE DESPLIEGA."
  echo
  echo "     Esto no es un aviso que se pueda leer y seguir adelante: el script"
  echo "     termina aqui. Para desplegar hay que arreglar lo que falla y volver"
  echo "     a medir, que es exactamente lo que costaba que ocurriera."
  echo
  if [ "$MEDIDO" = "CANDIDATO" ]; then
    echo "     Lo que falla esta EN EL ARBOL: se arregla en el repo y se vuelve a medir."
    echo "     perl \"$REF/qa-master.pl\" $SITIO --repo \"$REPO\" --candidato"
  else
    echo "     🔴 OJO: este recibo mide PRODUCCION. Puede estar rojo por defectos que"
    echo "        el arbol del repo YA arregla y que solo faltan por subir —y entonces"
    echo "        el gate estaria bloqueando justo la mejora que existe para permitir."
    echo "        Antes de tocar nada, mide lo que vas a subir:"
    echo "     perl \"$REF/qa-master.pl\" $SITIO --repo \"$REPO\" --candidato"
  fi
  exit 1
fi

# ── 2 · lo que NADIE ha mirado ───────────────────────────────────────────────
#    NO bloquea. Si bloqueara, el primer despliegue sin navegador ensenaria a
#    saltarse el gate, y un gate que se saltan una vez ya no vuelve. Pero deja
#    constancia: quien despliega con huecos, los firma.
#
#    🔴 Y NO TODO SIN-MIRAR ES UN HUECO. Midiendo el candidato, la compresion,
#    las cabeceras de cache, el estado 404 del host y G11 salen NO VERIFICADO
#    por fuerza: son configuracion del SERVIDOR, y el que contestaba era el
#    servidor local de pruebas. Esas se contestan en el paso 4, no mirando mas.
#    Si contaran para el `--aun-asi`, haria falta `--aun-asi` en CADA despliegue
#    y en una semana dejaria de significar nada —y entonces tampoco protegeria a
#    los huecos de verdad, que es para lo que existe.
NV="$(grep -m1 '^NO-VERIFICADO:' "$REPO/.qa-recibo" | tr -dc '0-9')"
NV="${NV:-0}"
NVC_LISTA="$(grep -m1 '^NV-POR-CANDIDATO:' "$REPO/.qa-recibo" 2>/dev/null | sed 's/^NV-POR-CANDIDATO:[[:space:]]*//')"
NVC=0
[ -n "$NVC_LISTA" ] && NVC="$(printf '%s\n' "$NVC_LISTA" | wc -w | tr -dc '0-9')"
NVC="${NVC:-0}"
NV_REALES=$(( NV - NVC ))
[ "$NV_REALES" -lt 0 ] && NV_REALES=0
if [ "$NV" != 0 ]; then
  linea; echo "  2 · lo que nadie ha mirado"; linea
  echo "  $NV comprobaciones quedaron SIN VERIFICAR:"
  grep -m1 '^SIN-MIRAR:' "$REPO/.qa-recibo" | sed 's/^/    /'
  if [ "$NVC" != 0 ]; then
    echo
    echo "  De esas, $NVC NO son huecos: son las preguntas que solo produccion"
    echo "  contesta, y las contesta G11 en el paso 4."
    echo "    $NVC_LISTA"
    echo "  Quedan $NV_REALES sin mirar de verdad."
  fi
  echo
  if [ -z "$AUN_ASI" ] && [ "$SUBIR" = 1 ] && [ "$NV_REALES" != 0 ]; then
    echo "  🔴 NO VERIFICADO NO ES UN APROBADO."
    echo "     Para subir con huecos, dilos en voz alta:"
    echo "         --aun-asi \"el motivo\""
    echo "     Queda en el historial con tu motivo al lado. No pide permiso: pide"
    echo "     que conste, porque lo que no consta se repite."
    exit 1
  fi
  # ── EL MOTIVO SE ESCRIBE, O NO EXISTE ──────────────────────────────────────
  # 🔴 13-ago-2026 · AQUI HABIA UN `echo` Y NADA MAS, y cuatro lineas mas arriba
  #    este mismo script promete que «queda en el historial con tu motivo al
  #    lado». No quedaba. MEDIDO: `~/.qa-receipts/history.tsv` tiene 621
  #    acciones -467 QA y 153 SERVIDO- y CERO NOTA. El mecanismo
  #    (`receipt.pl --anotar`) ya existia y no lo llamaba nadie salvo en subida
  #    fallida. Ese mismo dia se firmaron tres despliegues nombrando una a una
  #    las 11 comprobaciones sin medir, y los tres motivos se imprimieron en
  #    pantalla y se perdieron.
  #
  #    Por que pesa mas que un check: el dano de firmar no es firmar una vez, es
  #    firmar LO MISMO muchas veces. Eso no se puede ver sin registro. Un hueco
  #    firmado tres veces en un dia es una decision que nadie llego a tomar.
  #
  #    Se anota SOLO al subir de verdad: en ensayo no ha pasado nada que contar.
  if [ -n "$AUN_ASI" ] && [ "$SUBIR" = 1 ]; then
    echo "  se sube igualmente. Motivo: $AUN_ASI"
    # Los huecos DE VERDAD = SIN-MIRAR menos los que solo contesta produccion.
    # Se guarda la LISTA, no el total: un numero suelto no dice cual se repite.
    SIN_MIRAR="$(grep -m1 '^SIN-MIRAR:' "$REPO/.qa-recibo" 2>/dev/null | sed 's/^SIN-MIRAR:[[:space:]]*//')"
    HUECOS=""
    for x in $SIN_MIRAR; do
      case " $NVC_LISTA " in *" $x "*) ;; *) HUECOS="$HUECOS $x" ;; esac
    done
    HUECOS="${HUECOS# }"
    if perl "$REF/receipt.pl" --anotar "AUN-ASI [$NV_REALES sin mirar: $HUECOS] $AUN_ASI" \
            --repo "$REPO" >/dev/null 2>&1; then
      echo "  anotado en el historial: $NV_REALES sin mirar, con su motivo."
    else
      # No se traga el fallo: el despliegue sigue, pero quien lo lea tiene que
      # saber que esta firma no ha quedado en ningun sitio.
      echo "  NO he podido anotarlo en el historial. Esta firma NO consta."
    fi
  elif [ -n "$AUN_ASI" ]; then
    echo "  (ensayo: el motivo se anotara cuando se suba de verdad)"
  fi
fi


# ── 2-bis-a · LO QUE FALTA Y NO ES NUESTRO ───────────────────────────────────
#
#  19-ago-2026. Va pegado al paso 2 -«lo que NADIE ha mirado»- porque es la otra
#  mitad de la misma pregunta: el paso 2 dice que comprobaciones se han quedado
#  sin medir, y esto dice que le estamos esperando a otro.
#
#  POR QUE HACIA FALTA. El mecanismo existia -`_spec/site.json -> huecos[]`- y
#  solo lo usaba la web de PRUEBA: las cuatro de cliente declaraban CERO. Y aun
#  ahi era inerte, porque NINGUN gate lo leia. Resultado: «falta el NIF de
#  site-d» o «hay que tocar 4 disparadores en el GTM de site-a» vivian en fichas
#  de Notion y en la cabeza de quien estuvo ese dia. Se podia desplegar sin que
#  nadie viera lo que sigue faltando.
#
#  NO BLOQUEA, y no es por prudencia: un hueco abierto NO es un defecto del
#  arbol. Es informacion que tiene que estar DELANTE de quien despliega. Lo que
#  si falla es un `_huecos.tsv` mal formado, o un hueco sin la prueba de que
#  falta -- una suposicion en esa lista bloquea trabajo por nada.
if [ -f "$REF/holes.pl" ]; then
  HU_SALIDA="$(perl "$REF/holes.pl" --repo "$REPO" 2>&1)"
  HU_RC=$?
  printf '%s\n' "$HU_SALIDA" | sed 's/^/  /'
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "HUECOS $(printf '%s' "$HU_SALIDA" | grep -m1 -oE '[0-9]+ abiertos' || echo 'sin declarar') (exit $HU_RC)" --repo "$REPO" >/dev/null 2>&1
  if [ "$HU_RC" = 1 ]; then
    echo
    echo "  🔴 El fichero de huecos esta mal formado. Se arregla antes de subir:"
    echo "     un hueco mal declarado no avisa a nadie y ensucia el recibo."
  fi
fi
# ── 2-bis · la SPEC contra el arbol ──────────────────────────────────────────
#
#  14-ago-2026 · el segundo gate que se cablea a la puerta (el primero fue el de
#  enlazado). `audit-vs-spec.pl` hace una pregunta que ningun otro hace: «¿esta
#  en disco todo lo que la spec dice que existe, y dice el sitio lo que la spec
#  dice?». El recibo mide LO QUE HAY; este mide lo que FALTA.
#
#  VA ANTES DE SUBIR, al reves que el de enlazado, y por la misma razon que aquel
#  va despues: mide el ARBOL DEL REPO, y el repo se puede arreglar antes de
#  publicarlo. Enterarse despues de que falta una pagina no sirve de nada.
#
#  🔴 NO BLOQUEA, y la decision tiene fecha y motivo: el 14-ago los cinco repos
#  daban FALLA, y al mirarlo de cerca en site-c.example **las tres
#  acusaciones eran falsas** (paginas retiradas a proposito, un comentario leido
#  como codigo, y tres paginas legales que el gate no sabia reconocer). Se
#  arreglaron las tres con su caso rojo y su caso verde, pero un gate que acaba
#  de tener tres falsos positivos no se cablea como bloqueo el mismo dia: se
#  cablea para que se vea, se mira unas cuantas corridas, y entonces se sube el
#  liston. Lo que NO se hace es dejarlo sin correr, que es donde estaba.
#
#  El modo lo declara el repo (`MODO_SPEC=migracion|greenfield` en deploy.conf).
#  Sin declaracion no se adivina: se dice que no se ha medido y por que.
if [ ! -f "$REF/audit-vs-spec.pl" ]; then
  echo
  echo "  2-bis · spec contra arbol: no encuentro audit-vs-spec.pl. NO MEDIDO."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "SPEC no medida: falta el programa" --repo "$REPO" >/dev/null 2>&1
elif [ -z "${MODO_SPEC:-}" ]; then
  echo
  echo "  2-bis · spec contra arbol: $CONF no declara MODO_SPEC. NO MEDIDO."
  echo "          ponle MODO_SPEC=migracion (venia de una web) o =greenfield (no la habia)."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "SPEC no medida: sin MODO_SPEC en deploy.conf" --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  2-bis · la spec contra el arbol (modo $MODO_SPEC)"; linea
  SPEC_SALIDA="$(perl "$REF/audit-vs-spec.pl" --modo "$MODO_SPEC" --repo "$REPO" -q 2>&1)"
  SPEC_RC=$?
  printf '%s\n' "$SPEC_SALIDA" | grep -E 'FALLO|AVISO|NO VERIF|VEREDICTO|PASA [0-9]' | sed 's/^/  /'
  SPEC_VER="$(printf '%s\n' "$SPEC_SALIDA" | grep -m1 'VEREDICTO' | sed 's/.*VEREDICTO:[[:space:]]*//')"
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "SPEC ${SPEC_VER:-sin veredicto} (exit $SPEC_RC)" --repo "$REPO" >/dev/null 2>&1
  if [ "$SPEC_RC" != 0 ]; then
    echo
    echo "  La spec y el arbol NO cuadran. Queda anotado y NO bloquea todavia"
    echo "  (ver el motivo con fecha arriba, en el comentario de este bloque)."
    echo "  Si lo de arriba es un falso positivo, se arregla EL GATE con su caso"
    echo "  rojo, no se calla: audit-vs-spec-tests/tests.pl."
  fi
fi

# ── 2-ter · ¿SE PIERDE TEXTO DEL CLIENTE AL SUBIR ESTO? ──────────────────────
# 🔴 17-ago-2026 · `same-text.pl` existia desde el 14-ago y **no lo corria
#    nadie**. Es el programa que descubrio que, remaquetando site-c.example,
#    **10 paginas perdian hasta 207 palabras del cliente** -- y ningun otro gate
#    lo miraba, porque la pagina seguia siendo HTML valido, seccionada y verde.
#
#    VA AQUI, ANTES DE SUBIR, y ese es todo el asunto: es el unico momento en
#    que existen LAS DOS versiones. Despues de subir, la de antes ya no esta y
#    la pregunta «¿que palabras habia?» no se puede contestar.
#
#    La regla de la casa que vigila: **se conserva el CONTENIDO, se rehace la
#    MAQUETA**. Es material de cliente; comerse un parrafo suyo no es un bug de
#    maqueta, es entregar menos de lo que habia.
#
#    NO BLOQUEA todavia, y por el mismo motivo que 2-bis: quitar una seccion a
#    proposito tambien sale como «perdida», y un gate que impide desplegar el
#    primer dia que da un falso positivo ensena a saltarse la puerta. Se ve, se
#    anota, se mira unas corridas, y entonces se sube el liston.
if [ "$SUBIR" != 1 ]; then
  :   # en ensayo no se descarga nada
elif [ ! -f "$REF/same-text.pl" ]; then
  echo
  echo "  2-ter · texto del cliente: no encuentro same-text.pl. NO MEDIDO."
  perl "$REF/receipt.pl" --anotar "TEXTO no medido: falta same-text.pl" \
       --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  2-ter · ¿se pierde texto del cliente con esta subida?"; linea
  ANT="${TMPDIR:-/tmp}/texto-antes-$$"
  rm -rf "$ANT"; mkdir -p "$ANT"
  BAJADAS=0; NUEVAS=0
  # Solo el HTML del arbol desplegable, y solo el que YA existe en produccion:
  # una pagina nueva no puede perder palabras.
  for rel in $(perl "$REF/receipt.pl" --arbol --listar --repo "$REPO" 2>/dev/null \
               | awk '$3 ~ /\.html$/ {print $3}'); do
    # index.html -> /   ·   sub/index.html -> /sub/   ·   otra.html -> /otra.html
    case "$rel" in
      index.html)   ruta="/" ;;
      */index.html) ruta="/${rel%/index.html}/" ;;
      *)            ruta="/$rel" ;;
    esac
    cod="$(curl -s -o "$ANT/$rel.tmp" -w '%{http_code}' --max-time 25 \
           --create-dirs "${SITIO%/}$ruta" 2>/dev/null)"
    # 🔴 LA BARRA FINAL NO ES UNIVERSAL, y darla por hecha convierte este paso
    #    en decoracion. Medido el 17-ago en el primer despliegue real: site-c usa
    #    barra final y comparo 31 de 31; site-a NO la usa -su .htaccess lleva
    #    `DirectorySlash Off`- y comparo **1 de 19**, informando «0 con perdida».
    #    O sea: el check no encontraba las paginas, contaba 18 como NUEVAS, y el
    #    resultado se leia como un aprobado. Exactamente el fallo que este paso
    #    existe para evitar, cometido por el paso.
    #    Se prueba la otra forma antes de darla por nueva. No se elige por
    #    configuracion a proposito: una convencion declarada y equivocada vuelve
    #    a mentir; un 200 no.
    if [ "$cod" != 200 ] && [ "$ruta" != "/" ]; then
      case "$ruta" in
        */) alt="${ruta%/}" ;;
        *)  alt="$ruta/" ;;
      esac
      cod="$(curl -s -o "$ANT/$rel.tmp" -w '%{http_code}' --max-time 25 \
             --create-dirs "${SITIO%/}$alt" 2>/dev/null)"
    fi
    if [ "$cod" = 200 ]; then
      mkdir -p "$(dirname "$ANT/$rel")"; mv "$ANT/$rel.tmp" "$ANT/$rel"
      BAJADAS=$((BAJADAS+1))
    else
      rm -f "$ANT/$rel.tmp"; NUEVAS=$((NUEVAS+1))
    fi
  done
  if [ "$BAJADAS" = 0 ]; then
    echo "  no he podido bajar ni una pagina servida. NO MEDIDO."
    perl "$REF/receipt.pl" --anotar "TEXTO no medido: produccion no dio ninguna pagina" \
         --repo "$REPO" >/dev/null 2>&1
  else
    TXT_SALIDA="$(perl "$REF/same-text.pl" "$ANT" "$REPO" 2>&1)"
    TXT_RC=$?
    printf '%s\n' "$TXT_SALIDA" | grep -E '^\s*MAL|conservan todas' | head -12 | sed 's/^/  /'
    echo "  ($BAJADAS paginas comparadas, $NUEVAS nuevas que no existian antes)"
    TXT_RES="$(printf '%s\n' "$TXT_SALIDA" | grep -o '[0-9]* con perdida' | tail -1)"
    perl "$REF/receipt.pl" \
         --anotar "TEXTO $BAJADAS comparadas · ${TXT_RES:-sin recuento} (exit $TXT_RC)" \
         --repo "$REPO" >/dev/null 2>&1
    if [ "$TXT_RC" != 0 ]; then
      echo
      echo "  🔴 Hay paginas que pierden palabras del cliente. NO se para la subida"
      echo "     -- todavia --, pero esto no es un detalle de maqueta: es entregar"
      echo "     menos texto suyo del que habia. Mirarlo ANTES de dar por buena la"
      echo "     tanda, porque despues de subir ya no existe con que comparar."
    fi
  fi
  rm -rf "$ANT"
fi

# ── 2-quater · EL AUDITOR DE SITIO ───────────────────────────────────────────
#
#  19-ago-2026 · el tercer gate que se cablea a la puerta. Y el motivo de que
#  llegue el ultimo es el defecto en si: `audit.sh` era el UNICO instrumento que
#  no vivia en la skill sino COPIADO dentro de cada repo -4 copias, 3 versiones
#  distintas- y por eso ni la puerta ni nadie podia correrlo de forma uniforme.
#  Tres webs (site-c, site-a, site-b) directamente no lo tenian: sus ~30
#  comprobaciones no las corrio nadie NUNCA, mientras sus CLAUDE.md decian «en
#  rojo no se despliega» refiriendose a un fichero que no existia.
#
#  QUE MIRA QUE NINGUN OTRO MIRA. Es el unico que mide EL ARBOL EN DISCO:
#  ficheros para maquinas (sitemap/robots/llms.txt) contra lo que hay, mojibake,
#  integridad de edicion, hojas de estilo que resuelven, animaciones que solo
#  tocan transform/opacity. `qa-maestro` mide LO SERVIDO y `enlazado-gate` EL
#  GRAFO: son tres puntos de vista, no tres opiniones sobre lo mismo.
#
#  VA ANTES DE SUBIR, como 2-bis y por la misma razon: lo que mide se puede
#  arreglar antes de publicarlo.
#
#  🔴 NO BLOQUEA TODAVIA, con fecha y motivo, siguiendo la norma que 2-bis dejo
#  escrita: *un gate que acaba de tener falsos positivos no se cablea como
#  bloqueo el mismo dia*. Hoy este ha tenido 347. La primera corrida sobre site-a
#  dio 363 FALLOS en un sitio correcto porque el auditor solo conocia UNA
#  convencion de URL (`carpeta/index.html`) y site-a sirve ficheros planos
#  (`/a-propos` -> `a-propos.html`). Se arreglo -las dos convenciones viven ya
#  en una sola funcion, `resolver_ruta`, y se probo que sigue cazando un enlace
#  roto de verdad en las dos- y bajo a 16. Pero un gate que se ha tocado esta
#  manana se cablea PARA QUE SE VEA, se mira unas cuantas corridas, y entonces
#  se sube el liston.
#
#  CUANDO PASA A BLOQUEAR: cuando las 6 webs hayan pasado por aqui sin que
#  aparezca un falso positivo nuevo. Hoy 3 estan en FAIL 0 (climentmedia,
#  site-d, site-f) y 3 no (site-c 1, site-a 16, site-b 73).
if [ ! -f "$REF/audit.sh" ]; then
  echo
  echo "  2-quater · auditor de sitio: no encuentro audit.sh. NO MEDIDO."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "AUDITOR no medido: falta el programa" --repo "$REPO" >/dev/null 2>&1
elif [ ! -f "$REPO/_audit.conf" ] && [ ! -f "$REPO/audit.conf" ]; then
  echo
  echo "  2-quater · auditor de sitio: el repo no trae _audit.conf. NO MEDIDO."
  echo "            sin dominio ni marca ni carpetas excluidas, el auditor mide otra cosa."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "AUDITOR no medido: sin _audit.conf" --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  2-quater · el auditor de sitio (el arbol en disco)"; linea
  AUD_SALIDA="$(bash "$REF/audit.sh" --root "$REPO" 2>&1)"
  AUD_RC=$?
  printf '%s\n' "$AUD_SALIDA" | grep -E '^\s*\[FAIL\]|FAIL: [0-9]' | head -20 | sed 's/^/  /'
  AUD_RES="$(printf '%s\n' "$AUD_SALIDA" | grep -m1 'FAIL: [0-9]')"
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "AUDITOR ${AUD_RES:-sin resumen} (exit $AUD_RC)" --repo "$REPO" >/dev/null 2>&1
  if [ "$AUD_RC" != 0 ]; then
    echo
    echo "  El arbol en disco tiene fallos. Queda anotado y NO bloquea todavia"
    echo "  (ver el motivo con fecha arriba, en el comentario de este bloque)."
    echo "  Si alguno es un falso positivo, se arregla EL AUDITOR con su caso rojo."
  fi
fi

# ── 2-quinquies · ¿SOBREVIVE UN PARRAFO SACADO DE LA PAGINA? ─────────────────
#
#  28-ago-2026 · el cuarto gate que se cablea a la puerta, y llega tarde por una
#  razon que conviene no repetir: `citable.pl` existia, medido y con su banco de
#  54 casos, DOCUMENTADO en tres sitios... y no lo corria nadie salvo cuando
#  alguien se acordaba. Es la definicion de un gate fuera de la cadena.
#
#  LO QUE COSTO, medido el mismo dia: la rutina semanal de una web desplego con
#  TODOS los gates en verde y publico dos pasajes que abrian con un pronombre sin
#  antecedente -- uno de ellos el texto que se habia corregido en otra pagina del
#  mismo sitio unas horas antes, copiado en su version vieja. No fallo ningun
#  gate. El que sabia verlo no estaba aqui. Se cazó a mano DESPUES de servirse.
#
#  QUE MIRA QUE NINGUN OTRO MIRA. Un motor de respuesta no lee la pagina: extrae
#  un trozo. Este es el unico que lee cada parrafo COMO SI FUERA LO UNICO QUE HAY
#  en la pagina. `qa-master` mide lo servido, `audit.sh` el arbol y `same-text`
#  que no se pierdan palabras: ninguno pregunta si el parrafo se sostiene solo.
#
#  🔴 NO BLOQUEA TODAVIA, y es la norma de la casa escrita en 2-quater: *un gate
#  que se ha tocado esta manana se cablea PARA QUE SE VEA, se mira unas corridas,
#  y entonces se sube el liston*. Hoy mismo se le han anadido dos idiomas.
#  CUANDO PASA A BLOQUEAR: cuando las 6 webs hayan pasado por aqui sin un falso
#  positivo nuevo. Hoy las 5 medidas dan 0 BLOQUEA, asi que subir el liston no
#  frenaria nada -- que es exactamente la ventana buena para hacerlo, con datos.
#
#  ⚠️ SOLO se mira `BLOQUEA`. `DEBILITA` y `PULIDO` son consejo de redaccion: si
#  contaran, hoy no subiria ninguna web (una tiene 29 de pulido) y la puerta se
#  volveria ruido el primer dia.
if [ ! -f "$REF/citable.pl" ]; then
  echo
  echo "  2-quinquies · citabilidad: no encuentro citable.pl. NO MEDIDO."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "CITABLE no medido: falta el programa" --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  2-quinquies · ¿sobrevive un parrafo sacado de la pagina?"; linea
  CIT_SALIDA="$(perl "$REF/citable.pl" --repo "$REPO" 2>&1)"
  CIT_RC=$?
  printf '%s\n' "$CIT_SALIDA" | grep -E '^\s*\[BLOQUEA\]|^VEREDICTO|paginas medidas' | head -14 | sed 's/^/  /'
  CIT_RES="$(printf '%s\n' "$CIT_SALIDA" | grep -m1 '^VEREDICTO')"
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "CITABLE ${CIT_RES:-sin veredicto} (exit $CIT_RC)" --repo "$REPO" >/dev/null 2>&1
  # exit 3 = el idioma no tiene patrones. NO es un aprobado y se dice.
  if [ "$CIT_RC" = 3 ]; then
    echo
    echo "  🔴 NO MEDIDO: este arbol esta en un idioma sin patrones. Eso NO es un"
    echo "     aprobado -- es un hueco. Anadir el idioma, o decir que no se mide."
  elif [ "$CIT_RC" != 0 ]; then
    echo
    echo "  🔴 Hay parrafos que NO se sostienen fuera de la pagina. Queda anotado y"
    echo "     NO bloquea todavia (ver el motivo con fecha arriba). Se arregla en la"
    echo "     FUENTE -- el _spec/ del que nace la pagina --, nunca en el HTML."
    echo "     Si alguno es falso positivo, se arregla EL GATE con su caso rojo."
  fi
fi

# ── 2-sexies · ¿DEJAMOS ENTRAR A LOS MOTORES DE RESPUESTA? ───────────────────
#
#  La pregunta anterior es «¿el texto sirve para que me citen?». Esta es la de
#  antes: **¿pueden siquiera leerlo?** Un `robots.txt` que bloquea a GPTBot o a
#  ClaudeBot convierte en decoracion todo el trabajo de citabilidad, y no lo dice
#  ningun otro gate -- `audit.sh` comprueba que el fichero EXISTA y cuadre con el
#  sitemap, no a quien deja pasar.
#
#  Se mide sobre el ARBOL (--repo), no sobre produccion, porque aqui todavia se
#  puede arreglar. Lo servido lo vuelve a mirar G11 despues.
#
#  🔴 NO BLOQUEA TODAVIA, misma norma. Y ademas hay una decision de negocio
#  legitima detras: un cliente puede querer NO dejar entrar a un motor. Cuando
#  eso pase, va a `aceptado.conf` firmado, no callado aqui.
if [ ! -f "$REF/ai-crawlers.pl" ]; then
  echo
  echo "  2-sexies · rastreadores de IA: no encuentro ai-crawlers.pl. NO MEDIDO."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "CRAWLERS-IA no medido: falta el programa" --repo "$REPO" >/dev/null 2>&1
elif [ ! -f "$REPO/robots.txt" ]; then
  echo
  echo "  2-sexies · rastreadores de IA: el arbol no trae robots.txt. NO MEDIDO."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "CRAWLERS-IA no medido: sin robots.txt" --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  2-sexies · ¿dejamos entrar a los motores de respuesta?"; linea
  IA_SALIDA="$(perl "$REF/ai-crawlers.pl" --repo "$REPO" 2>&1)"
  IA_RC=$?
  printf '%s\n' "$IA_SALIDA" | grep -E '^\s*(FALLA|BLOQUEA|PASA|VEREDICTO)|bloquead' | head -12 | sed 's/^/  /'
  IA_RES="$(printf '%s\n' "$IA_SALIDA" | grep -m1 -E '^VEREDICTO|^\s*(PASA|FALLA)')"
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "CRAWLERS-IA ${IA_RES:-sin veredicto} (exit $IA_RC)" --repo "$REPO" >/dev/null 2>&1
  if [ "$IA_RC" = 3 ]; then
    echo
    echo "  🔴 NO MEDIDO. No es un aprobado: nadie ha comprobado quien puede entrar."
  elif [ "$IA_RC" != 0 ]; then
    echo
    echo "  🔴 Hay motores de respuesta que NO pueden rastrear este sitio. Queda"
    echo "     anotado y NO bloquea todavia. Si es deliberado, va FIRMADO en"
    echo "     _deploy/aceptado.conf -- una decision callada aqui no es una decision."
  fi
fi

# ── 3 · subir ────────────────────────────────────────────────────────────────
linea; echo "  3 · subida"; linea
if [ -z "$SUBIDA" ]; then
  echo "  $CONF no define SUBIDA: no hay nada que ejecutar."
  echo "  El gate ha pasado; la subida se hace a mano y luego:"
  echo "      deploy.sh \"$REPO\" --servido"
  if [ "$MEDIDO" = "CANDIDATO" ]; then
    echo
    echo "  🔴 Y esa segunda linea NO es opcional: el recibo es de CANDIDATO, asi que"
    echo "     todo lo verde de arriba habla del arbol del repo. Nadie ha mirado aun"
    echo "     lo que sirve $SITIO."
  fi
  exit 0
fi
CMD="$SUBIDA"
case "$SUBIDA" in
  /*|[A-Za-z]:*) ;;
  *) [ -f "$REPO/$SUBIDA" ] && CMD="bash \"$REPO/$SUBIDA\"" ;;
esac

if [ "$SUBIR" != 1 ]; then
  echo "  (ensayo: NO se sube nada)"
  echo
  echo "  El gate ha pasado. El comando que se ejecutaria es:"
  echo "      $CMD"
  # ── 🔴 EL ENSAYO QUE DE VERDAD ENSEÑA ALGO (11-ago-2026) ──────────────────
  #  Hasta hoy el ensayo imprimia la linea y paraba. Servia cuando la subida era
  #  «el arbol entero»: se sabe lo que hay en el arbol. Desde que la subida
  #  incluye los RECEPTORES —contact.php y compania—, la pregunta que hay que
  #  poder contestar antes de subir es «¿que le va a pasar al receptor de leads?»
  #  y esa no la contesta imprimir un comando.
  #
  #  DOS CERROJOS, porque el modo de fallo aqui seria «un ensayo que despliega»:
  #    1 · el repo tiene que PEDIRLO (`SUBIDA_ENSAYO=1` en su deploy.conf). Un
  #        repo que no lo declare se comporta como siempre.
  #    2 · y SUBIDA tiene que ser un script DEL PROPIO REPO, no un comando
  #        suelto. Un conf copiado de otro sitio con un `tar | ssh` en SUBIDA no
  #        entra aqui ni aunque lleve la bandera: ese comando no sabe que es
  #        `--ensayo` y se lo comeria como un argumento mas.
  if [ "${SUBIDA_ENSAYO:-0}" = 1 ] && [ -f "$REPO/$SUBIDA" ]; then
    echo
    echo "  $CONF declara SUBIDA_ENSAYO=1: se corre EN SECO."
    echo "  Escribe CERO bytes en produccion; solo lee y comprueba."
    echo
    eval "$CMD --ensayo"
    RCE=$?
    echo
    [ "$RCE" != 0 ] && echo "  ⚠ el ensayo ha terminado en $RCE: miralo antes de subir."
  fi
  echo
  echo "  Para subir de verdad, repetir con --subir."
  exit 0
fi

# ── 3-bis · QUE SE HA RETIRADO DEL ARBOL DESDE EL DESPLIEGUE ANTERIOR ────────
# 🔴 9-sep-2026 · EL AGUJERO QUE ESTO CIERRA, Y QUE LLEVABA ESCRITO SIN MEDIRSE.
#    Los subidores de este sistema extraen un `tar` ENCIMA del docroot: anaden y
#    sobrescriben, y NUNCA borran. Un fichero retirado del repo SIGUE SERVIDO.
#    Y G11 no lo ve POR CONSTRUCCION: comprueba que lo del recibo se sirva, no
#    que no sobre nada. Son dos preguntas distintas y solo se hacia una.
#
#    MEDIDO el 9-sep-2026 en un sitio real: se retiraron 13 imagenes del arbol,
#    se desplego, G11 dio «113 de 113 identicos» ... y las 13 seguian devolviendo
#    200. La limpieza se habria reportado como hecha estando viva. El subidor de
#    ese sitio ya lo AVISABA en un comentario desde hacia semanas: un comentario
#    no es una comprobacion, y lo que no se mide no lo mira nadie.
#
#    POR QUE CONTRA LA LISTA ANTERIOR Y NO CONTRA EL DOCROOT: enumerar el destino
#    exige SSH, y cada web sube distinto -por eso el subidor es de cada repo-.
#    La lista de lo que ESTE sistema subio la tenemos sin salir de aqui.
#    ⚠️ LIMITE, declarado y no disimulado: solo ve lo que este pipeline desplego
#    alguna vez y despues dejo de desplegar. La basura anterior a la primera
#    lista NO la ve, y para esa hace falta el listado remoto del subidor.
LISTA_HOY="$(mktemp -t desplegado-XXXXXXXX)"
RETIRADAS="$(mktemp -t retiradas-XXXXXXXX)"
LISTA_ANT="$REPO/_deploy/.desplegado.txt"
trap 'rm -f "$LISTA_HOY" "$RETIRADAS"' EXIT
perl "$REF/receipt.pl" --arbol --listar --repo "$REPO" 2>/dev/null \
  | sed -nE 's/^[0-9a-f]+[[:space:]]+[0-9]+[[:space:]]+//p' \
  | LC_ALL=C sort > "$LISTA_HOY"
: > "$RETIRADAS"
if [ -s "$LISTA_ANT" ] && [ -s "$LISTA_HOY" ]; then
  LC_ALL=C sort "$LISTA_ANT" > "$LISTA_ANT.orden.tmp"
  LC_ALL=C comm -23 "$LISTA_ANT.orden.tmp" "$LISTA_HOY" > "$RETIRADAS"
  rm -f "$LISTA_ANT.orden.tmp"
fi

echo "  $CMD"
eval "$CMD"
RC=$?
if [ "$RC" != 0 ]; then
  echo
  echo "  🔴 la subida ha fallado (exit $RC). NO doy por desplegado nada."
  perl "$REF/receipt.pl" --anotar "subida fallida rc=$RC" --repo "$REPO" >/dev/null 2>&1
  exit 1
fi

# ── 4 · G11 · ¿lo servido es lo medido? ──────────────────────────────────────
#    El paso que no existia. Sin el, «desplegado» es otra afirmacion de palabra.
linea; echo "  4 · G11 · lo servido frente al recibo"; linea
# La salida se guarda ademas de verse: el resumen de abajo dice que preguntas
# ha CONTESTADO G11 leyendolo de lo que G11 ha dicho, no de una lista fija.
# `tee` lee hasta el final, asi que no hay SIGPIPE; el codigo es el de perl.
G11_LOG="${TEMP:-/tmp}/g11-puerta-$$.log"
perl "$REF/receipt.pl" --servido --repo "$REPO" --sitio "$SITIO" | tee "$G11_LOG"
G11=${PIPESTATUS[0]}
if [ "$G11" != 0 ]; then
  echo
  echo "  🔴 HAS SUBIDO Y PRODUCCION NO SIRVE ESO."
  echo "     Causas ya vistas: cache (Cache-Control 86400 en css/js sin versionar),"
  echo "     ruta remota equivocada, o SUBIDA que solo sube parte del arbol."
  echo "     Y si lo que falla es la 404 del host (EST-03), el arbol esta bien subido:"
  echo "     lo que no sirve el 404.html es la configuracion del host (su .htaccess)."
  echo "     No lo des por hecho hasta que esto salga en verde."
  rm -f "$G11_LOG"
  exit 1
fi
echo
# ── 4-bis · LO QUE SE RETIRO DEL ARBOL, ¿SIGUE SERVIDO? ──────────────────────
#    G11 acaba de decir que lo del recibo se sirve. Esta es la OTRA mitad: que no
#    sobre nada. Se PIDE cada fichero retirado; un 200 no es una sospecha, es el
#    resto vivo con su URL. No se borra nada desde aqui a proposito: el docroot
#    tiene ficheros que NO estan en el arbol y son legitimos -los receptores, y
#    lo que se escribe en ejecucion, como los leads del formulario-, asi que un
#    borrado a ciegas es la unica forma de convertir esta comprobacion en una
#    perdida de datos. Se dice QUE sobra y se deja la orden preparada.
linea; echo "  4-bis · lo que se retiro del arbol, ¿sigue servido?"; linea
if [ ! -s "$LISTA_ANT" ]; then
  echo "  ⚠ NO MEDIDO: no hay lista del despliegue anterior con la que comparar."
  echo "    Esto NO es «no sobra nada»: es «nadie ha mirado». La lista se escribe"
  echo "    al final de este despliegue, asi que desde el proximo si se compara."
elif [ ! -s "$RETIRADAS" ]; then
  echo "  ningun fichero se ha retirado del arbol desde el despliegue anterior."
else
  N_RET="$(grep -c . "$RETIRADAS")"
  VIVAS=0
  echo "  $N_RET fichero(s) estaban en el despliegue anterior y ya no en el arbol."
  echo "  Se pide cada uno a produccion:"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    cod="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$SITIO/$f" 2>/dev/null)"
    case "$cod" in
      2*|3*) VIVAS=$((VIVAS+1)); echo "    🔴 $cod  $SITIO/$f" ;;
      *)     echo "       $cod  $f" ;;
    esac
  done < "$RETIRADAS"
  echo
  if [ "$VIVAS" = 0 ]; then
    echo "  Los $N_RET retirados ya no se sirven. El destino cuadra con el arbol."
  else
    echo "  🔴 $VIVAS de $N_RET SIGUEN SERVIDOS. El arbol y el destino NO cuadran."
    echo "     No es un fallo de la subida: el tar no borra, y G11 no mira lo que"
    echo "     sobra. Hay que quitarlos en el destino, y eso lo hace el subidor de"
    echo "     este repo, que es quien tiene las credenciales."
    echo "     La lista exacta esta arriba, con su URL. Antes de borrar ninguno:"
    echo "     mirar QUE es. Hoy un 'resto' resulto ser el fichero de licencia que"
    echo "     la OFL exige que acompane a las fuentes."
    perl "$REF/receipt.pl" --anotar "SOBRAN $VIVAS de $N_RET retirados siguen servidos" --repo "$REPO" >/dev/null 2>&1
  fi
fi

# La lista de ESTE despliegue, para que el proximo pueda comparar. Se escribe
# solo si G11 paso: una lista de un despliegue que no se pudo verificar mentiria
# sobre lo que hay en el destino.
if [ -s "$LISTA_HOY" ]; then
  mkdir -p "$REPO/_deploy" 2>/dev/null
  cp "$LISTA_HOY" "$LISTA_ANT" 2>/dev/null \
    && echo "  (lista de $(grep -c . "$LISTA_HOY") ficheros guardada para el proximo despliegue)"
fi

echo
echo "  PASA · desplegado y verificado contra el recibo."
if [ "$MEDIDO" = "CANDIDATO" ]; then
  echo "  Los dos momentos cerrados: el candidato se midio ANTES y lo servido AHORA."
  # 🔴 26-sep-2026 · AQUI PONIA «Las N que el candidato no podia medir (...) ya
  #    tienen respuesta», con EST-03 dentro de la lista, y G11 no pedia ninguna
  #    URL inexistente: esa pregunta no la contestaba nadie, y una web salio con
  #    la 404 GENERICA del servidor en cada URL rota y esta linea en verde. Ahora
  #    se dice, id a id, que ha contestado G11 y que no — y se lee de LO QUE G11
  #    HA DICHO en esta corrida: una lista fija volveria a afirmar EST-03 el dia
  #    que el arbol no traiga 404.html y G11 conteste NO VERIFICADO.
  #    EST-09 es G11 mismo · EST-03 si G11 da bien/mal de la 404 del host ·
  #    MED-10 si G11 ha mirado receptores.
  if [ "$NVC" != 0 ]; then
    G11_CONTESTA=" EST-09 "
    grep -q '404 del host (EST-03): [0-9]' "$G11_LOG" 2>/dev/null && G11_CONTESTA="${G11_CONTESTA}EST-03 "
    grep -q '^  receptores: ' "$G11_LOG" 2>/dev/null && G11_CONTESTA="${G11_CONTESTA}MED-10 "
    NVC_SI=""; NVC_NO=""
    for id in $NVC_LISTA; do
      case "$G11_CONTESTA" in *" $id "*) NVC_SI="$NVC_SI $id" ;; *) NVC_NO="$NVC_NO $id" ;; esac
    done
    [ -n "$NVC_SI" ] && echo "  De las $NVC que el candidato no podia medir, G11 acaba de contestar:$NVC_SI"
    if [ -n "$NVC_NO" ]; then
      echo "  Y NO ha contestado:$NVC_NO."
      echo "  Compresion, cache y rutas internas son cabeceras y configuracion del host:"
      echo "  se miden contra la URL real (qa-master.pl sin --candidato). Si EST-03 esta"
      echo "  en esa lista, la linea «404 del host» de G11, arriba, dice por que."
    fi
  fi
fi
rm -f "$G11_LOG"

# ── 5 · EL ENLAZADO DE LO QUE ACABA DE QUEDAR SERVIDO ────────────────────────
# 🔴 13-ago-2026 · POR QUE ESTE PASO EXISTE AHORA.
#    Hasta hoy, de los seis gates de la skill la puerta invocaba UNO: receipt.pl.
#    `linking-gate.pl`, `structure-gate.js` y `measure-screens.js` solo se
#    imprimian como consejo. Yo los corria a mano despues de cada despliegue --
#    y lo que depende de que alguien se acuerde, falla el dia que no se acuerda.
#
#    VA DESPUES DE SUBIR, y no antes, a proposito: mide el GRAFO DE LO SERVIDO.
#    Correrlo antes mediria la web vieja, que es justo la clase de error que este
#    fichero existe para matar (medir una cosa y desplegar otra).
#
#    NO BLOQUEA, y tampoco es opcional: deja el veredicto escrito en el historial.
#    No bloquea porque ya se ha subido -parar aqui no deshace nada- y porque
#    `linking-gate.pl` sale 1 tambien cuando NO PUEDE medir: shop.site-b.example
#    pinta el grafo con JS, asi que cableado como bloqueo esa web no volveria a
#    desplegarse nunca. Un gate que impide desplegar por no poder medir no
#    protege: ensena a saltarse la puerta.
#
#    Se salta solo si el repo lo declara (`SIN_ENLAZADO=1` en deploy.conf), y esa
#    declaracion tambien se anota: un hueco declarado sigue siendo un hueco.
if [ "${SIN_ENLAZADO:-0}" = 1 ]; then
  echo
  echo "  5 · enlazado: $CONF declara SIN_ENLAZADO=1, no se mide."
  perl "$REF/receipt.pl" --anotar "ENLAZADO no medido: SIN_ENLAZADO=1 en deploy.conf" \
       --repo "$REPO" >/dev/null 2>&1
elif [ ! -f "$REF/crawl-links.pl" ] || [ ! -f "$REF/linking-gate.pl" ]; then
  echo
  echo "  5 · enlazado: no encuentro crawl-links.pl o linking-gate.pl. NO MEDIDO."
  perl "$REF/receipt.pl" --anotar "ENLAZADO no medido: falta el programa" \
       --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  5 · el enlazado de lo que acaba de quedar servido"; linea
  # Cache NUEVA en cada corrida y propia: `crawl-links.pl` y `qa-master.pl`
  # comparten la clave md5(url), y compartir directorio ya sirvio una vez bytes
  # de otro programa sin dar un solo error (07-trampas §16). Y una cache de la
  # corrida anterior serviria el sitio de ANTES de este despliegue.
  CE="${TMPDIR:-/tmp}/enlazado-$$"
  rm -rf "$CE"; mkdir -p "$CE"
  CEJSON="$CE/grafo.json"
  echo "  rastreando $SITIO ..."
  if perl "$REF/crawl-links.pl" "$SITIO/" "$CE" "$CEJSON" 200 >/dev/null 2>&1 && [ -s "$CEJSON" ]; then
    ENL_SALIDA="$(perl "$REF/linking-gate.pl" "$CEJSON" 2>&1)"
    ENL_RC=$?
    printf '%s\n' "$ENL_SALIDA" | sed 's/^/  /'
    ENL_VER="$(printf '%s\n' "$ENL_SALIDA" | grep -m1 'VEREDICTO' | sed 's/.*VEREDICTO:[[:space:]]*//')"
    perl "$REF/receipt.pl" --anotar "ENLAZADO ${ENL_VER:-sin veredicto} (exit $ENL_RC)" \
         --repo "$REPO" >/dev/null 2>&1
    if [ "$ENL_RC" != 0 ]; then
      echo
      echo "  El despliegue esta hecho y G11 lo ha verificado: los ficheros estan."
      echo "  Lo que falla es el ENLAZADO de lo servido, y queda anotado. No se"
      echo "  deshace nada por esto, pero tampoco se puede decir que salio limpio."
    fi
  else
    echo "  no he podido rastrear $SITIO. El enlazado queda NO MEDIDO."
    perl "$REF/receipt.pl" --anotar "ENLAZADO no medido: el rastreo fallo" \
         --repo "$REPO" >/dev/null 2>&1
  fi
  rm -rf "$CE"
fi

# ── 6 · LO QUE SOLO SE VE CON UN NAVEGADOR ───────────────────────────────────
# 🔴 17-ago-2026 · POR QUE ESTE PASO EXISTE AHORA.
#    `structure-gate.js` (¿esta maquetado o es un articulo disfrazado?),
#    `measure-screens.js` (cuanto ocupa y donde caen los CTAs) y el nuevo
#    `forms-gate.js` (el paso 10) aparecian en este fichero **solo dentro
#    de un comentario**. Un `grep` los encontraba y aun asi no los ejecutaba
#    nadie: un gate MENCIONADO no es un gate CABLEADO, y la diferencia no se ve
#    leyendo por encima. Se comprueba con `grep -n` y mirando si la linea es
#    codigo o prosa.
#
# ⚠️ SE MIDE EN EL SERVIDOR, NO AQUI, y no es comodidad: en Windows, Chrome
#    headless CLAMPA `--window-size` a ~500 px de ancho minimo, asi que una
#    medida «a 390» sale de una pagina compuesta a 504 y la captura es un
#    RECORTE. Eso ya costo dos defectos inventados y un arreglo de algo que no
#    estaba roto. En Linux, pedido 390 = `innerWidth` 390, verificado.
#
# 🔴 LOS GATES SE EMPUJAN EN CADA CORRIDA (`scp`), no se confia en la copia del
#    servidor. Habia dos copias de cada gate -la de la skill y la de
#    `~/webtools/gates/`- y dos copias divergen el primer dia. Lo que se mide
#    tiene que ser el fichero canonico, o el veredicto es de otro programa.
#
#    NO BLOQUEA, por lo mismo que el paso 5: ya se ha subido, y parar aqui no
#    deshace nada. Lo que hace es dejar el veredicto en el historial. Se salta
#    declarandolo (`SIN_NAVEGADOR=1` en deploy.conf), y la declaracion tambien
#    se anota: un hueco declarado sigue siendo un hueco.
#
# 🔴 21-sep-2026 · EL HOST POR DEFECTO ERA UN MARCADOR, Y EL PASO 6 NO MEDIA NADA.
#    Aqui ponia `NAV_HOST="${NAV_HOST:-example-host}"`: el nombre real se quito al
#    anonimizar el repo y quedo el marcador. Toda web que no declarase NAV_HOST en
#    su deploy.conf intentaba conectar a `example-host`, no llegaba, y el paso lo
#    anotaba como «sin example-host» y seguia. **77 despliegues en cuatro webs, del
#    26-ago al 17-sep, sin que los gates de navegador midieran lo servido**, y cada
#    uno dejo una linea en el historial que no leia nadie. El banco no lo veia: su
#    unico caso de esta rama traia un NAV_HOST inventado a proposito, asi que nunca
#    ejercio el valor por defecto.
#    → **El host de medida es un dato de la MAQUINA, no de la web ni del repo**, y
#      en un repo publico no puede ir escrito. Orden, de mas especifico a menos:
#        1) NAV_HOST del deploy.conf de la web (o del entorno),
#        2) el fichero local `config/nav-host.local.conf` (NAV_HOST=...), que
#           `*.conf` deja fuera de git igual que leak-terms.local.conf,
#        3) nada: **NO MEDIDO en alto, sin intentar ningun host**. Un marcador
#           que «falla al conectar» se lee como un problema de red; esto es
#           configuracion que falta, y tiene que decirlo con ese nombre.
#    La ruta del fichero se puede cambiar con NAV_HOST_CONF (lo usa el banco
#    para no leer la configuracion de la maquina que lo corre).
#    ⚠️ Y el mismo dia salio el hermano: `config/deploy.conf.example`, que es lo
#    que copia quien clona el repo, documentaba estas cuatro claves CON NOMBRE
#    INGLES (BROWSER_HOST, BROWSER_URLS, FORM_URLS, NO_BROWSER) y esta puerta
#    solo leia los nombres en castellano. Quien siguiera la plantilla se quedaba
#    sin medir igual, y sin ningun aviso. Se aceptan los dos; manda el castellano
#    si estan los dos, porque es el que ya usan los deploy.conf que existen.
# 🔴 21-sep-2026 (tarde) · LA LECTURA DEL HOST SE FUE A `nav-host.sh`. Aqui habia
#    una lectura propia, y los tres bancos que miden en el servidor seguian con
#    su `example-host` escrito a mano: el arreglo de la puerta no habia salido de
#    la puerta. Ahora los cuatro cargan el mismo fichero. Ver su cabecera.
URLS_NAVEGADOR="${URLS_NAVEGADOR:-${BROWSER_URLS:-}}"
URLS_FORMULARIO="${URLS_FORMULARIO:-${FORM_URLS:-}}"
SIN_NAVEGADOR="${SIN_NAVEGADOR:-${NO_BROWSER:-0}}"
. "$REF/nav-host.sh"
NAV_HOST="$(nav_host "$REF")"
NAV_HOST_CONF="$(nav_host_conf "$REF")"
if [ "${SIN_NAVEGADOR:-0}" != 1 ] && [ -z "${NAV_HOST:-}" ]; then
  echo
  echo "  ============================================================================"
  echo "  6 · navegador: NO MEDIDO: NAV_HOST sin configurar."
  echo "      Ni $CONF ni el entorno lo declaran, y no hay una linea NAV_HOST= en"
  echo "      $NAV_HOST_CONF"
  echo "      Los gates de maqueta, pantallas, movil y formularios NO han mirado"
  echo "      lo servido. Se arregla con una linea NAV_HOST=<alias ssh> en ese fichero."
  echo "      (Ese fichero no viaja con git: si corres la puerta desde un worktree,"
  echo "       no esta alli. Lanzala por la ruta de la skill o exporta NAV_HOST.)"
  echo "  ============================================================================"
  perl "$REF/receipt.pl" --anotar "NAVEGADOR no medido: NAV_HOST sin configurar" \
       --repo "$REPO" >/dev/null 2>&1
elif [ "${SIN_NAVEGADOR:-0}" = 1 ]; then
  echo
  echo "  6 · navegador: $CONF declara SIN_NAVEGADOR=1, no se mide."
  perl "$REF/receipt.pl" --anotar "NAVEGADOR no medido: SIN_NAVEGADOR=1 en deploy.conf" \
       --repo "$REPO" >/dev/null 2>&1
# 🔴 18-ago-2026 · EL CORREDOR SE EMPUJA, NO SE SUPONE. Esta rama comprobaba si el
#    servidor TENIA `~/webtools/run-gate.js` y, si no, bajaba los tres gates de
#    navegador a NO MEDIDO -- en el mismo paso que ya empujaba los gates «porque
#    dos copias divergen el primer dia». El corredor era la excepcion, y no estaba
#    versionado en ningun sitio: un `rm` en el servidor apagaba media puerta y el
#    despliegue seguia, con su NO MEDIDO bien anotado y a nadie extranandole.
#    Ahora la fuente es `references/run-gate.js` y lo unico que se comprueba es
#    llegar al servidor. Si no se llega, sigue siendo NO MEDIDO: eso si es honesto.
elif ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$NAV_HOST" 'true' 2>/dev/null; then
  echo
  echo "  6 · navegador: no llego a $NAV_HOST. NO MEDIDO."
  perl "$REF/receipt.pl" --anotar "NAVEGADOR no medido: sin $NAV_HOST" \
       --repo "$REPO" >/dev/null 2>&1
elif [ ! -f "$REF/run-gate.js" ]; then
  echo
  echo "  6 · navegador: falta $REF/run-gate.js. NO MEDIDO."
  echo "      Es el corredor de los tres gates de navegador y vive EN LA SKILL."
  perl "$REF/receipt.pl" --anotar "NAVEGADOR no medido: falta gates/run-gate.js" \
       --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  6 · maqueta, densidad y formularios de lo servido"; linea
  ssh "$NAV_HOST" 'mkdir -p ~/webtools/gates' >/dev/null 2>&1
  scp -q "$REF/run-gate.js" "$NAV_HOST:webtools/run-gate.js" 2>/dev/null
  for g in structure-gate.js measure-screens.js forms-gate.js mobile-gate.js; do
    [ -f "$REF/$g" ] && scp -q "$REF/$g" "$NAV_HOST:webtools/gates/$g" 2>/dev/null
  done

  # Que URLs. Por defecto la portada; el repo puede declarar mas. Las de
  # formulario van aparte porque ahi el paso 10 se EXIGE: si esa pagina se queda
  # sin formulario es un FALLO, no un «no aplica».
  URLS_NAV="${URLS_NAVEGADOR:-/}"
  URLS_FORM="${URLS_FORMULARIO:-}"
  NAV_FALLOS=0; NAV_MIRADAS=0; NAV_BASURA=0

  corre_gate() {   # <ruta> <gate> <ancho> <alto> [json de __GATE__]
    ruta="$1"; gate="$2"; w="$3"; h="$4"; cfg="${5:-}"
    url="${SITIO%/}${ruta}"
    # ⚠️ El JSON va entre COMILLAS SIMPLES para el shell remoto. Con dobles,
    #    `"{"exigeFormulario":true}"` pierde las suyas por el camino y `node`
    #    recibe `{exigeFormulario:true}`, que no es JSON. Y el sintoma engana:
    #    `run-gate.js` muere con RUNNER-ERROR, la salida no lleva
    #    `"coincide":true`, y este paso lo contaria como NO MEDIDO -- o sea,
    #    parecia un problema de red. Probado antes de darlo por bueno.
    out="$(ssh "$NAV_HOST" "cd ~/webtools && node run-gate.js '$url' $w $h gates/$gate ${cfg:+'$cfg'}" 2>&1)"
    # ⚠️ REGLA DE LA CASA: `coincide` PRIMERO. Una medida hecha a un ancho que no
    #    es el pedido no es un resultado peor: es basura, y darla por numero es
    #    peor que no medir.
    # 🔴 18-ago-2026 · Y ANTES QUE `coincide`, QUE SEA LA PAGINA. `coincide` dice
    #    que el ancho es el pedido; no dice que se haya medido el sitio. site-a y
    #    loja.site-b sirven a este Chrome un muro anti-bot y el gate media el
    #    muro: 1 pantalla, 0 CTA, FALLA. Una acusacion falsa contra dos de las
    #    cinco webs, con el ancho cuadrando. `run-gate.js` ahora lo marca.
    if printf '%s' "$out" | grep -q '"sospechoso":true'; then
      NAV_BASURA=$((NAV_BASURA+1))
      titulo="$(printf '%s' "$out" | grep -oE '"titulo":"[^"]*"' | head -1 | sed 's/.*://;s/"//g' | cut -c1-40)"
      printf '    %-22s %-26s %4spx  NO MEDIDO (no parece la pagina: %s)\n' "$gate" "$ruta" "$w" "$titulo"
      return
    fi
    if ! printf '%s' "$out" | grep -q '"coincide":true'; then
      NAV_BASURA=$((NAV_BASURA+1))
      printf '    %-22s %-26s %4spx  NO MEDIDO (el ancho no coincide)\n' "$gate" "$ruta" "$w"
      return
    fi
    NAV_MIRADAS=$((NAV_MIRADAS+1))
    ver="$(printf '%s' "$out" | grep -m1 '"VEREDICTO"' | grep -o 'PASA\|FALLA')"
    printf '    %-22s %-26s %4spx  %s\n' "$gate" "$ruta" "$w" "${ver:-SIN VEREDICTO}"
    if [ "$ver" = "FALLA" ]; then
      NAV_FALLOS=$((NAV_FALLOS+1))
      printf '%s' "$out" | grep -A6 '"fallos"' | head -7 | sed 's/^/        /'
    fi
  }

  for r in $URLS_NAV; do
    corre_gate "$r" structure-gate.js 1298 720
    corre_gate "$r" measure-screens.js 1298 720
    corre_gate "$r" measure-screens.js  390 844
    # 🔴 20-ago-2026 · EL GATE DE MOVIL. Se cablea aqui el mismo dia que se
    # escribe, y no despues: un gate fuera de la cadena no guarda nada -- este
    # sitio ya tiene dos casos escritos de gates dias en rojo sin que nadie los
    # viera. Lo que caza no lo ve ningun otro: si el visitante puede ACTUAR
    # desde el telefono (accion sobre el pliegue, y sin nada encima).
    # Mismo ancho que la linea de arriba, a proposito: los dos hablan del mismo
    # movil y se leen juntos.
    # ⚠️ Mide la PRIMERA VISITA. El escenario "ya acepto cookies" exige pulsar
    # el banner, y esta puerta no toma decisiones de consentimiento por nadie;
    # el informe del gate lo declara en cada corrida.
    corre_gate "$r" mobile-gate.js 390 844
  done
  for r in $URLS_FORM; do
    corre_gate "$r" forms-gate.js 1298 720 '{"exigeFormulario":true}'
    corre_gate "$r" forms-gate.js  390 844 '{"exigeFormulario":true}'
  done

  # Un formulario no medido NO es un formulario correcto. Si el repo no declara
  # donde estan, se dice -- callarlo dejaria el paso 10 en el mismo sitio del
  # que viene: una promesa.
  if [ -z "$URLS_FORM" ]; then
    echo "    (el repo no declara URLS_FORMULARIO: el paso 10 NO se ha medido)"
    perl "$REF/receipt.pl" --anotar "PASO 10 no medido: deploy.conf no declara URLS_FORMULARIO" \
         --repo "$REPO" >/dev/null 2>&1
  fi
  perl "$REF/receipt.pl" \
       --anotar "NAVEGADOR $NAV_MIRADAS medidas · $NAV_FALLOS FALLA · $NAV_BASURA sin medir por ancho" \
       --repo "$REPO" >/dev/null 2>&1
  if [ "$NAV_FALLOS" != 0 ]; then
    echo
    echo "  El despliegue esta hecho y G11 lo ha verificado: los ficheros estan."
    echo "  Lo que falla es lo que solo se ve con un navegador, y queda anotado."
    echo "  No se deshace nada por esto, pero tampoco salio limpio."
  fi
fi
exit 0
