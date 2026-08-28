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
  echo "  $REF/deploy.conf.ejemplo):"
  echo
  echo "      SITIO=https://dominio.tld"
  echo "      SUBIDA=_deploy/subir.sh          # relativo al repo, o comando entero"
  echo
  echo "  🔴 SUBIDA tiene que subir EL ARBOL ENTERO, no un fichero suelto. Si sube"
  echo "     solo el CSS, la verificacion de despues (G11) lo dira: comparara los"
  echo "     $(perl "$REF/receipt.pl" --arbol --repo "$REPO" 2>/dev/null | awk '/FICHEROS/{print $2}') ficheros del recibo con lo servido."
  exit 2
fi
# shellcheck disable=SC1090
. "$CONF"
SITIO="${SITIO:-}"
SUBIDA="${SUBIDA:-}"
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
perl "$REF/receipt.pl" --servido --repo "$REPO" --sitio "$SITIO"
G11=$?
if [ "$G11" != 0 ]; then
  echo
  echo "  🔴 HAS SUBIDO Y PRODUCCION NO SIRVE ESO."
  echo "     Causas ya vistas: cache (Cache-Control 86400 en css/js sin versionar),"
  echo "     ruta remota equivocada, o SUBIDA que solo sube parte del arbol."
  echo "     No lo des por hecho hasta que esto salga en verde."
  exit 1
fi
echo
echo "  PASA · desplegado y verificado contra el recibo."
if [ "$MEDIDO" = "CANDIDATO" ]; then
  echo "  Los dos momentos cerrados: el candidato se midio ANTES y lo servido AHORA."
  if [ "$NVC" != 0 ]; then
    echo "  Las $NVC que el candidato no podia medir ($NVC_LISTA) ya tienen respuesta"
    echo "  para el md5 de cada fichero. Lo que G11 NO mira son las cabeceras: para"
    echo "  compresion y cache, medir la URL real sin --candidato."
  fi
fi

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
NAV_HOST="${NAV_HOST:-example-host}"
if [ "${SIN_NAVEGADOR:-0}" = 1 ]; then
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
  perl "$REF/receipt.pl" --anotar "NAVEGADOR no medido: falta references/run-gate.js" \
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
