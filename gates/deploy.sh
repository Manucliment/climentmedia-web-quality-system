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
#                                      dejando el motivo escrito en el historial.
#                                      Con gates de navegador en FALLA sobre el
#                                      candidato (paso 1-quater), el motivo tiene
#                                      que NOMBRAR cada gate en rojo, y no puede
#                                      decir que «lo contesta el navegador»
#    deploy.sh REPO --pierde-texto "..."  permite subir aunque alguna pagina
#                                      pierda palabras frente a lo que sirve
#                                      produccion (paso 2-ter), dejando en el
#                                      historial las paginas, cuantas y el motivo
#    deploy.sh REPO --sin-commit "..."  permite subir ficheros del arbol que no
#                                      estan commiteados (paso 1-ter, G1), dejando
#                                      la lista y el motivo en el historial
#    deploy.sh REPO --otra-vez "..."  permite subir un SITIO que otra sesion ha
#                                      subido hace menos de 15 min (paso 3-ter-0),
#                                      dejando el motivo en el historial
#    deploy.sh REPO --parar "..."     para la puerta de ese SITIO que esta en curso
#                                      en esta maquina, y dice la verdad: si no llego
#                                      a subir (0), si ya subio o esta subiendo (3)
#                                      o si no habia ninguna (4). TaskStop NO la para
#                                      en Windows: los procesos hijos siguen
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
#  1-nov-2026 · y entre los dos, la propia puerta mide EL CANDIDATO con los gates de
#  navegador (1-quater: maqueta, pantallas, primer pantallazo a 360/390/1366/1440 y
#  menu movil), en el Chrome de NAV_HOST, antes de la linea que sube. Un FALLA para.
#  Claves de deploy.conf que lo afinan: URLS_NAVEGADOR (que paginas), HOSTS_RESERVA
#  (plataformas de reserva propias, ademas de las conocidas), ECOMMERCE=1 (tienda:
#  el primer pantallazo no exige un contacto) y NAV_PARALELO (medidas a la vez, 3).
#  1-nov-2026 · y la marca (marca-gate.js a 1366 y 390: logo en la cabecera, iconos y
#  manifest que cargan, theme-color, nada fuera de la paleta de _diseno/MARCA.md).
#  SOLO AVISA hasta que la web pone MARCA_GATE=para (cuando su _diseno/ esta hecho);
#  MARCA_IGNORAR= lista los selectores de widgets de terceros que no cuentan.
#  6-nov-2026 · y los botones (botones-gate.js a 1366 y 390: un mismo boton con la
#  misma forma en la pagina, y la misma pintura sobre el mismo fondo; y botones-sitio.js,
#  lo mismo ENTRE las paginas medidas). Avisa hasta que la web pone BOTONES_GATE=para;
#  BOTONES_FAMILIAS="primario=.btn-primary,.btn-download; secundario=.btn-ghost" nombra
#  sus familias (sin ellas, el grupo de un boton son sus clases).
#  6-nov-2026 · y el aviso de cookies (banner-probe.js en la portada, a 1298 y 390: B0-B8,
#  como lo vive un visitante que rechaza). Avisa hasta que la web pone BANNER_GATE=para.
#  6-nov-2026 · y lo que se ve (visible-gate.js a 1366 y 390: el contenido que sigue
#  invisible tras bajar y esperar a las apariciones, y la parada de Tab que queda entera
#  debajo de la cabecera pegada o de la barra fija). Avisa hasta que la web pone VISIBLE_GATE=para.
#  7-nov-2026 · y las huellas (huellas-gate.js a 1366 y 390: el antetitulo encima de cada
#  h2, el texto en degradado, el borde de un lado, el halo de color, transition: all, el
#  interlineado, el titulo con una palabra sola y el telefono que no acepta un numero
#  escrito a su manera). Avisa hasta que la web pone HUELLAS_GATE=para.
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
REPO=""; SUBIR=0; SOLO_SERVIDO=0; AUN_ASI=""; PIERDE_TEXTO=""; HORAS=12; VER_SUBIDA=0; SIN_COMMIT=""; OTRA_VEZ=""; PARAR=""

while [ $# -gt 0 ]; do
  # English aliases. Additive: they cannot break an existing invocation.
  # Both spellings are supported and documented in gates/README.md.
  case "$1" in
    --upload)      set -- "--subir" "${@:2}" ;;
    --served)      set -- "--servido" "${@:2}" ;;
    --show-upload) set -- "--ver-subida" "${@:2}" ;;
    --anyway)      set -- "--aun-asi" "${@:2}" ;;
    --loses-text)  set -- "--pierde-texto" "${@:2}" ;;
    --uncommitted) set -- "--sin-commit" "${@:2}" ;;
    --hours)       set -- "--horas" "${@:2}" ;;
    --again)       set -- "--otra-vez" "${@:2}" ;;
    --stop)        set -- "--parar" "${@:2}" ;;
  esac
  case "$1" in
    --subir)    SUBIR=1 ;;
    --servido)  SOLO_SERVIDO=1 ;;
    --ver-subida) VER_SUBIDA=1 ;;
    --aun-asi)  shift; AUN_ASI="${1:-}" ;;
    --pierde-texto) shift; PIERDE_TEXTO="${1:-}" ;;
    --sin-commit) shift; SIN_COMMIT="${1:-}" ;;
    --otra-vez) shift; OTRA_VEZ="${1:-}" ;;
    --parar)    shift; PARAR="${1:-parada a mano, sin motivo}" ;;
    --horas)    shift; HORAS="${1:-12}" ;;
    -h|--help)  sed -n '2,/^set -u$/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 2 ;;
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
# D-057 · una web sin GA4 ni Ads POR DECISION lo dice con su motivo: MED-13 (una
# conversion que llega a GA4/Ads) es entonces NO APLICA, y d057.pl mira que el
# arbol de verdad no lleve ninguna etiqueta. Sin esto, MED-13 queda sin mirar.
SIN_GA4_NI_ADS="${SIN_GA4_NI_ADS:-${NO_GA4_OR_ADS:-}}"
# D-057 · el DOM de la pagina PUBLICADA (6-nov): lo que el candidato midio con su
# DOM (EST-05/06/07, REN-11) solo se compara con produccion con el de produccion.
# Ruta relativa al repo; d057.pl mira que sea de produccion, de esa pagina, al
# mismo ancho y alto y de las ultimas 12 h. Sin el, esos salen NO MEDIDO.
D057_DOM_PRODUCCION="${D057_DOM_PRODUCCION:-${D057_PRODUCTION_DOM:-}}"
case "$D057_DOM_PRODUCCION" in
  ''|/*|[A-Za-z]:[\\/]*) ;;
  *) D057_DOM_PRODUCCION="$REPO/$D057_DOM_PRODUCCION" ;;
esac
[ -n "$SITIO" ] || { echo "  $CONF no define SITIO"; exit 2; }

# ── ARBOL DE REDIRECCIONES (2-nov-2026) ──────────────────────────────────────
#    Un dominio retirado cuyo arbol es un robots.txt y un .htaccess que lo manda
#    todo con 301 a otra web. qa-master.pl no tiene ninguna pagina que medir y
#    deja sus cinco lentes sin medir, asi que ese arbol no tenia camino por la
#    puerta: o pagina de relleno, o subida por fuera. Con ARBOL=redirecciones
#    (TREE=redirects) el recibo lo escribe redirects-gate.pl, los pasos que miden
#    paginas dicen NO APLICA en voz alta, y despues de subir se piden las rutas
#    al dominio (4-ter). receipt.pl rechaza ese recibo si el arbol trae una pagina.
ARBOL_TIPO="${ARBOL:-${TREE:-paginas}}"
case "$ARBOL_TIPO" in
  paginas|pages)           REDIR=0 ;;
  redirecciones|redirects) REDIR=1 ;;
  *) echo "  $CONF: ARBOL=$ARBOL_TIPO no lo se leer (paginas | redirecciones)"; exit 2 ;;
esac
no_aplica() { echo; echo "  $1 · NO APLICA: ARBOL=redirecciones (no hay paginas que medir)"; }
if [ "$REDIR" = 1 ]; then
  MEDIR_CMD="perl \"$REF/redirects-gate.pl\" --repo \"$REPO\" --sitio $SITIO --candidato"
else
  MEDIR_CMD="perl \"$REF/qa-master.pl\" $SITIO --repo \"$REPO\" --candidato"
fi

# >>> puerta-en-curso (marca del banco deploy-tests: no la muevas sin moverlo)
# ── 0-ter · UNA PUERTA QUE SE PARA DE VERDAD, Y QUE DICE SI YA SUBIO (5-nov-2026) ─
#    Medido esa noche en una web: el chat paro la puerta con TaskStop a las 22:12 y
#    escribio «parada, produccion sin cambiar». En Windows TaskStop mata la orden
#    que la lanzo, no a la puerta: siguio midiendo y subio a las 22:25. Nadie lo supo
#    hasta mirar produccion. Ahora:
#      · la puerta apunta, mientras corre, quien es y en que paso esta (MIDIENDO,
#        SUBIENDO, SUBIDO), en ~/.qa-receipts/subidas/<sitio>.en-curso;
#      · `deploy.sh REPO --parar "motivo"` deja una orden de parar para ESA puerta
#        y dice la verdad: no llego a subir (0), ya subio o esta subiendo (3), o no
#        habia ninguna en curso (4, con la ultima subida de esta maquina);
#      · justo antes del subidor, la puerta mira si se la ha mandado parar, y si la
#        orden que la lanzo sigue viva: una puerta huerfana (TaskStop) NO sube.
#    El orden importa: la puerta escribe SUBIENDO y despues mira la orden de parar;
#    --parar escribe la orden y despues mira el estado. Asi uno de los dos ve al otro.
#    ⚠️ LIMITES, declarados: --parar NO mata procesos (un subidor cortado a medias
#    deja el docroot a medio escribir); la puerta termina el paso largo en que este
#    y para al llegar a la subida. Si la lanzo un proceso que no es de esta shell
#    (padre 1), la comprobacion de huerfana no se puede hacer. Solo esta maquina.
PUERTA_DIR="${QA_RECIBOS_DIR:-${HOME:-${USERPROFILE:-.}}/.qa-receipts}/subidas"
PUERTA_TAB="$(printf '\t')"
puerta_slug() { printf '%s' "$SITIO" | sed -E 's#^[a-z]+://##; s#[/:]+$##; s#[^A-Za-z0-9._-]#_#g'; }
puerta_fichero() { printf '%s/%s.%s\n' "$PUERTA_DIR" "$(puerta_slug)" "$1"; }   # en-curso | parar
puerta_sesion() { printf '%s\n' "${CLAUDE_CODE_SESSION_ID:-${USER:-${USERNAME:-alguien}}@$(hostname 2>/dev/null || echo maquina)}"; }
puerta_hace() { local s=$(( $(date +%s) - ${1:-0} )); [ "$s" -lt 120 ] && echo "$s s" || echo "$(( s / 60 )) min"; }
en_curso_escribe() {  # $1 = estado · pid, padre, sesion, inicio, estado, cuando
  mkdir -p "$PUERTA_DIR" 2>/dev/null
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$$" "${PUERTA_PADRE:-0}" "$(puerta_sesion)" "${PUERTA_INICIO:-$(date +%s)}" "$1" "$(date +%s)" \
    > "$(puerta_fichero en-curso)" 2>/dev/null
}
en_curso_fin() {  # al salir: se borra lo de ESTA puerta, no lo de otra
  local f pid resto
  for f in "$(puerta_fichero en-curso)" "$(puerta_fichero parar)"; do
    [ -s "$f" ] || continue
    IFS="$PUERTA_TAB" read -r pid resto < "$f"
    [ "$pid" = "$$" ] && rm -f "$f"
  done
  return 0
}
puerta_sigue() {  # justo antes del subidor · 1 = no se sube (y deja PUERTA_PARADA)
  local f pid quien motivo
  PUERTA_PARADA=""
  f="$(puerta_fichero parar)"
  if [ -s "$f" ]; then
    IFS="$PUERTA_TAB" read -r pid quien motivo < "$f"
    if [ "$pid" = "$$" ]; then
      echo "  🔴 PUERTA PARADA con --parar (${quien:0:13}…): $motivo"
      echo "     NO se sube: produccion sin cambiar."
      PUERTA_PARADA="parada con --parar: $motivo"; return 1
    fi
  fi
  case "${PUERTA_PADRE:-1}" in ''|*[!0-9]*|0|1) return 0 ;; esac
  if ! kill -0 "$PUERTA_PADRE" 2>/dev/null; then
    echo "  🔴 LA ORDEN QUE LANZO ESTA PUERTA YA NO EXISTE (proceso $PUERTA_PADRE): alguien la paro"
    echo "     (TaskStop, una ventana cerrada) y la puerta siguio viva. NO se sube: produccion sin cambiar."
    echo "     Si de verdad hay que subir, se lanza otra vez."
    PUERTA_PARADA="huerfana: la orden que la lanzo ($PUERTA_PADRE) ya no existe"; return 1
  fi
  return 0
}
puerta_parar() {  # $1 = motivo · 0 parada antes de subir · 3 ya subio o esta subiendo · 4 ninguna en curso
  local f c pid padre ses ini est cuando t cses crep
  f="$(puerta_fichero en-curso)"; c="$PUERTA_DIR/$(puerta_slug)"
  if [ ! -s "$f" ]; then
    echo "  no hay ninguna puerta de $SITIO en curso en esta maquina."
    if [ -s "$c" ] && IFS="$PUERTA_TAB" read -r t cses crep < "$c" && case "$t" in ''|*[!0-9]*) false ;; esac; then
      echo "  🔴 la ultima subida de $SITIO desde esta maquina fue hace $(puerta_hace "$t") (sesion ${cses:0:13}…, $crep):"
      echo "     si era la que querias parar, YA SUBIO. Lo servido: deploy.sh REPO --servido"
    else
      echo "  y ninguna subida de $SITIO apuntada desde esta maquina."
    fi
    return 4
  fi
  IFS="$PUERTA_TAB" read -r pid padre ses ini est cuando < "$f"
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "  la puerta $pid de $SITIO ya no existe: su ultimo estado apuntado fue $est, hace $(puerta_hace "$cuando")."
    case "$est" in SUBIENDO*|SUBIDO*) echo "  🔴 y ese estado es de DESPUES de empezar a subir: produccion ha cambiado." ;; esac
    rm -f "$f"; return 4
  fi
  # primero la orden, despues el estado (ver arriba: asi uno de los dos ve al otro)
  mkdir -p "$PUERTA_DIR" 2>/dev/null
  printf '%s\t%s\t%s\n' "$pid" "$(puerta_sesion)" "$1" > "$(puerta_fichero parar)" 2>/dev/null
  IFS="$PUERTA_TAB" read -r pid padre ses ini est cuando < "$f" 2>/dev/null
  case "$est" in
    SUBIENDO*) echo "  🔴 la puerta de $SITIO (proceso $pid) ESTA SUBIENDO desde hace $(puerta_hace "$cuando"):"
               echo "     produccion YA esta cambiando. No se corta un subidor a medias."
               echo "     Cuando acabe, lo servido: deploy.sh REPO --servido"
               return 3 ;;
    SUBIDO*)   echo "  🔴 la puerta de $SITIO (proceso $pid) YA SUBIO hace $(puerta_hace "$cuando") ($est): produccion ha cambiado."
               return 3 ;;
  esac
  echo "  parada la puerta de $SITIO: proceso $pid, en $est desde hace $(puerta_hace "$cuando"), sesion ${ses:0:13}…"
  echo "  NO subira: termina el paso en que esta y para al llegar a la subida. Produccion sin cambiar."
  return 0
}
# <<< puerta-en-curso
if [ -n "$PARAR" ]; then
  linea; echo "  PARAR la puerta de $SITIO"; linea
  puerta_parar "$PARAR"; exit $?
fi
if [ "$SUBIR" = 1 ]; then
  PUERTA_PADRE="$PPID"; PUERTA_INICIO="$(date +%s)"
  trap en_curso_fin EXIT
  en_curso_escribe MIDIENDO
  echo "  esta puerta es el proceso $$. Para pararla de verdad (TaskStop no la para en Windows):"
  echo "      deploy.sh \"$REPO\" --parar \"el motivo\""
fi

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

# ── 1-D057 · LO VIEJO QUE YA ESTA IGUAL EN PRODUCCION (5-nov-2026) ───────────
#    Un recibo de CANDIDATO en FALLA que vale en todo lo demas (sello, arbol, edad,
#    lentes, alcance) no para si TODO lo que falla esta igual en la web publicada y
#    tiene fila abierta con fecha y dueño en el plan: gates/d057.pl mide produccion
#    con la misma regla y lo decide, uno a uno. Nada nuevo pasa en rojo, y no cubre
#    medicion, cookies y consentimiento ni lo que no se acepta nunca. El por que y
#    el como, en la cabecera de d057.pl. Se corre UNA vez por puerta: el paso 2 lee
#    su salida para los sin mirar.
D057=0; D057_RC=""; RECIBO_SALVO=""; D057_SAL="$REPO/_deploy/.d057-ultima.txt"
d057_corre() {
  [ -n "$D057_RC" ] && return "$D057_RC"
  mkdir -p "$REPO/_deploy" 2>/dev/null
  perl "$REF/d057.pl" --repo "$REPO" ${SIN_GA4_NI_ADS:+--sin-ga4-ni-ads "$SIN_GA4_NI_ADS"} \
       ${D057_DOM_PRODUCCION:+--dom-produccion "$D057_DOM_PRODUCCION"} --salida "$D057_SAL" | sed 's/^/  /'
  D057_RC=${PIPESTATUS[0]}
  return "$D057_RC"
}
d057_lista() { [ -n "$D057_RC" ] && grep -m1 "^D057-$1:" "$D057_SAL" 2>/dev/null | sed "s/^D057-$1:[[:space:]]*//" | tr -d '\r'; }
if [ "$GATE" != 0 ] && [ "$MEDIDO" = CANDIDATO ] && [ -f "$REF/d057.pl" ] \
   && grep -q '^VEREDICTO: FALLA' "$REPO/.qa-recibo" 2>/dev/null \
   && perl "$REF/receipt.pl" --verificar --repo "$REPO" --para-desplegar --salvo-veredicto --horas "$HORAS" >/dev/null 2>&1; then
  echo
  echo "  El recibo vale en todo menos en su VEREDICTO (FALLA). ¿Es todo viejo? (D-057)"
  if d057_corre; then
    D057=1; GATE=0; RECIBO_SALVO="--salvo-veredicto"
    echo "  D-057: todo lo que falla ya esta igual en produccion y tiene fila con fecha. Sigue."
  else
    echo "  D-057: no lo cubre (arriba, cada uno con su motivo)."
  fi
fi

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
    echo "     $MEDIR_CMD"
  else
    echo "     🔴 OJO: este recibo mide PRODUCCION. Puede estar rojo por defectos que"
    echo "        el arbol del repo YA arregla y que solo faltan por subir —y entonces"
    echo "        el gate estaria bloqueando justo la mejora que existe para permitir."
    echo "        Antes de tocar nada, mide lo que vas a subir:"
    echo "     $MEDIR_CMD"
  fi
  exit 1
fi
# El recibo que ha dejado pasar el paso 1, por su SELLO: en el paso 3-ter, justo
# antes de subir, tiene que seguir siendo ESTE (5-nov-2026, ver alli).
RECIBO_SELLO_1="$(grep -m1 '^SELLO:' "$REPO/.qa-recibo" 2>/dev/null | tr -d '\r')"

# ── 1-bis-b · EL RECIBO Y EL deploy.conf DICEN LO MISMO DEL ARBOL ────────────
#    Un recibo de redirecciones vale sin lentes de pagina; uno de paginas, sin
#    medir las redirecciones. Si el conf y el recibo no coinciden, uno de los
#    dos esta mal, y subir con cualquiera es subir algo que nadie ha medido asi.
TIPO_RECIBO="$(grep -m1 '^TIPO:' "$REPO/.qa-recibo" 2>/dev/null | sed 's/^TIPO:[[:space:]]*//' | tr -d '\r')"
if [ "$REDIR" = 1 ] && [ "$TIPO_RECIBO" != "REDIRECCIONES" ]; then
  echo
  echo "  🔴 $CONF declara ARBOL=redirecciones y el recibo no es de redirects-gate.pl."
  echo "     Medir:  $MEDIR_CMD"
  echo "  🔴 NO SE DESPLIEGA."
  exit 1
fi
if [ "$REDIR" = 0 ] && [ -n "$TIPO_RECIBO" ]; then
  echo
  echo "  🔴 el recibo es de tipo $TIPO_RECIBO y $CONF no declara ARBOL=redirecciones."
  echo "     Si el arbol solo redirige, declararlo; si tiene paginas, medir con qa-master.pl."
  echo "  🔴 NO SE DESPLIEGA."
  exit 1
fi

# ── 1-ter · LO QUE SE SUBE ESTA COMMITEADO (trampa de despliegue G1) ──────────
#    27-oct-2026. El recibo sella el arbol que hay en disco, este o no en git, y la
#    subida sube ese arbol. Una tienda sirvio el 8-sep un configurator.js con 4 lineas
#    sin commitear: ese dia el formulario dejo de dar leads, y seis dias despues no
#    habia nada con que compararlo. Git no sabe nada de produccion; si lo servido no
#    esta en un commit, no hay vuelta atras ni diff.
#    Solo cuentan los ficheros DEL ARBOL (receipt.pl --arbol --listar): un CLAUDE.md o
#    una nota de _seo/ sin commitear no se sube y no para nada.
#    Para subir igualmente, como --aun-asi: --sin-commit "motivo", que queda anotado.
SIN_COMMIT_LISTA=""
if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ARBOL_LISTA="$(perl "$REF/receipt.pl" --arbol --repo "$REPO" --listar 2>/dev/null | awk '$1 ~ /^[0-9a-f]{8}$/ && $2 ~ /^[0-9]+$/ { $1=""; $2=""; sub(/^  */, ""); print }')"
  SUCIOS="$(git -C "$REPO" -c core.quotepath=off status --porcelain --untracked-files=all 2>/dev/null | sed -E 's/^.{3}//; s/^.* -> //; s/^"(.*)"$/\1/')"
  if [ -n "$SUCIOS" ] && [ -n "$ARBOL_LISTA" ]; then
    SIN_COMMIT_LISTA="$(printf '%s\n' "$SUCIOS" | grep -Fx -f <(printf '%s\n' "$ARBOL_LISTA") || true)"
  fi
  if [ -n "$SIN_COMMIT_LISTA" ]; then
    N_SC="$(printf '%s\n' "$SIN_COMMIT_LISTA" | grep -c .)"
    linea; echo "  1-ter · lo que se sube esta commiteado (G1)"; linea
    echo "  🔴 $N_SC fichero(s) del arbol SIN COMMITEAR:"
    printf '%s\n' "$SIN_COMMIT_LISTA" | head -10 | sed 's/^/       /'
    if [ "$SUBIR" = 1 ] && [ -z "${SIN_COMMIT:-}" ]; then
      echo
      echo "  NO SE DESPLIEGA. Lo servido tiene que poder nombrar un commit: haz commit"
      echo "  (por nombre, nunca git add -A) y vuelve a medir. Si de verdad hay que"
      echo "  subirlo asi, que conste:  --sin-commit \"el motivo\""
      exit 1
    elif [ "$SUBIR" = 1 ]; then
      echo "  se sube igualmente. Motivo: $SIN_COMMIT"
      perl "$REF/receipt.pl" --anotar "SIN-COMMIT [$(printf '%s ' $SIN_COMMIT_LISTA | head -c 300)] $SIN_COMMIT" \
           --repo "$REPO" >/dev/null 2>&1 && echo "  (anotado en el historial)"
    else
      echo "  (ensayo: con --subir, esto para la subida salvo --sin-commit \"motivo\")"
    fi
  fi
else
  echo "  G1 · NO MEDIDO: $REPO no es un repo git, no se puede saber si lo que se sube esta commiteado"
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "G1 no medido: no es un repo git" --repo "$REPO" >/dev/null 2>&1
fi

# ── 1-ter-b · EL PAQUETE ES LO QUE SELLO EL RECIBO (6-nov-2026) ─────────────────
#    Dos listas de lo que no viaja: la del recibo (receipt.pl: fuera toda carpeta
#    `_algo/` de primer nivel, los .md, .sh, .ps1...) y la del subidor, que empaqueta
#    `tar c…f <destino> $EXCLUIR .`. Lo que la segunda deja pasar y la primera no sella
#    SUBE sin que nadie lo haya medido, y G11 no lo ve: compara lo sellado con lo
#    servido, no lo subido con lo sellado. Medido el 20-oct en una web: 121 ficheros en
#    el paquete y 120 sellados; el de mas, una lista interna en una carpeta `_tareas/`
#    nueva que ningun --exclude cubria. Censo del 6-nov sobre las 9 webs que suben asi:
#    0 de mas en las 9, y por eso para desde el primer dia.
#    ⚠️ LIMITE, declarado: solo se rehace el paquete de un subidor que vive en
#    `_deploy/` del repo y empaqueta con `tar c…f <destino> $EXCLUIR .` (desde la raiz).
#    Uno que sube por pasos, o con otra herramienta, sale NO MEDIDO con su porque.
#    Y se mide aqui, en el paso 1, como G1: durante una subida el repo no se toca.
PAQ_SCRIPT=""
case "$SUBIDA" in
  ''|/*|[A-Za-z]:*) ;;
  *) [ -f "$REPO/$SUBIDA" ] && PAQ_SCRIPT="$REPO/$SUBIDA" ;;
esac
PAQ_NM=""
if [ "$REDIR" = 1 ]; then
  PAQ_NM=""   # un arbol de redirecciones lo mide redirects-gate.pl entero
elif [ -z "$PAQ_SCRIPT" ]; then
  PAQ_NM="SUBIDA no es un guion del repo: no se de que esta hecho su paquete"
elif [ "$(cd "$(dirname "$PAQ_SCRIPT")" && pwd)" != "$(cd "$REPO/_deploy" 2>/dev/null && pwd)" ]; then
  PAQ_NM="el subidor ($SUBIDA) no vive en _deploy/ de este repo: no se desde donde empaqueta"
elif ! grep -qE '^[^#]*\btar[[:space:]]+-?c[a-zA-Z]*f[[:space:]]+[^[:space:]]+[[:space:]]+\$\{?EXCLUIR\}?[[:space:]]+\.([[:space:]]|$)' "$PAQ_SCRIPT"; then
  PAQ_NM="el subidor no empaqueta con «tar c…f <destino> \$EXCLUIR .»: sube de otra forma"
elif [ -z "${EXCLUIR:-}" ]; then
  PAQ_NM="$CONF no define EXCLUIR, y el subidor lo usa"
fi
if [ "$REDIR" = 0 ] && [ -n "$PAQ_NM" ]; then
  echo "  1-ter-b · el paquete contra el recibo · NO MEDIDO: $PAQ_NM"
elif [ "$REDIR" = 0 ]; then
  PAQ_LISTA="$(mktemp -t paquete-XXXXXXXX)"; PAQ_SELLO="$(mktemp -t sellado-XXXXXXXX)"
  # shellcheck disable=SC2086
  ( cd "$REPO" && tar cf - $EXCLUIR . 2>/dev/null ) | tar tf - 2>/dev/null \
    | grep -v '/$' | sed 's|^\./||' | LC_ALL=C sort > "$PAQ_LISTA"
  perl "$REF/receipt.pl" --arbol --listar --repo "$REPO" 2>/dev/null \
    | sed -nE 's/^[0-9a-f]+[[:space:]]+[0-9]+[[:space:]]+//p' | LC_ALL=C sort > "$PAQ_SELLO"
  N_PAQ="$(grep -c . "$PAQ_LISTA")"
  if [ "$N_PAQ" = 0 ] || [ ! -s "$PAQ_SELLO" ]; then
    echo "  1-ter-b · el paquete contra el recibo · NO MEDIDO: no pude rehacer el paquete ($N_PAQ ficheros) o leer lo sellado"
  else
    PAQ_SOBRA="$(LC_ALL=C comm -23 "$PAQ_LISTA" "$PAQ_SELLO")"
    N_SOBRA="$(printf '%s' "$PAQ_SOBRA" | grep -c .)"
    N_APARTE="$(LC_ALL=C comm -13 "$PAQ_LISTA" "$PAQ_SELLO" | grep -c .)"
    if [ "$N_SOBRA" = 0 ]; then
      echo "  1-ter-b · el paquete es lo sellado: $N_PAQ fichero(s), todos en el recibo$([ "$N_APARTE" -gt 0 ] && echo " ($N_APARTE sellado(s) que el tar no lleva: los sube el subidor aparte)")"
    else
      linea; echo "  1-ter-b · el paquete contra el recibo"; linea
      echo "  🔴 EL PAQUETE LLEVA $N_SOBRA FICHERO(S) QUE EL RECIBO NO SELLA: subirian sin que"
      echo "     nadie los haya medido, y G11 no los veria."
      printf '%s\n' "$PAQ_SOBRA" | head -10 | sed 's/^/       /'
      [ "$N_SOBRA" -gt 10 ] && echo "       … y $((N_SOBRA - 10)) mas"
      echo "     Si no se sirven, su --exclude en EXCLUIR de $CONF (una carpeta _algo/ nueva,"
      echo "     su --exclude en el mismo commit). Si se tienen que servir, en SERVIDOS_PESE_A_EXCLUIR."
      if [ "$SUBIR" = 1 ]; then
        echo
        echo "  NO SE DESPLIEGA."
        perl "$REF/receipt.pl" --anotar "subida parada: el paquete lleva $N_SOBRA fichero(s) sin sellar" --repo "$REPO" >/dev/null 2>&1
        rm -f "$PAQ_LISTA" "$PAQ_SELLO"
        exit 1
      fi
      echo "  (ensayo: con --subir, esto para la subida)"
    fi
  fi
  rm -f "$PAQ_LISTA" "$PAQ_SELLO"
fi

# ── las claves y las medidas de navegador (las usan el 1-quater y el 6) ──────
#    Las claves aceptan los dos nombres (ver el paso 6, 21-sep-2026). Lo de este
#    bloque son funciones: medir aqui no mide nada hasta que alguien las llama.
URLS_NAVEGADOR="${URLS_NAVEGADOR:-${BROWSER_URLS:-}}"
URLS_FORMULARIO="${URLS_FORMULARIO:-${FORM_URLS:-}}"
SIN_NAVEGADOR="${SIN_NAVEGADOR:-${NO_BROWSER:-0}}"
# 1-nov-2026 · las plataformas de reserva de la web (ademas de las que ya conocen los
# gates) y si es una tienda: los dos cambian que cuenta como «convierte» en el
# primer pantallazo. Solo letras, cifras, punto y guion: va dentro de un JSON y de
# unas comillas simples del shell remoto.
HOSTS_RESERVA="$(printf '%s' "${HOSTS_RESERVA:-${BOOKING_HOSTS:-}}" | tr ',' ' ' | tr -cd 'A-Za-z0-9. -' | tr 'A-Z' 'a-z')"
ECOMMERCE="${ECOMMERCE:-0}"
NAV_CFG=""
if [ -n "$HOSTS_RESERVA" ] || [ "$ECOMMERCE" = 1 ]; then
  NAV_CFG="{$( [ -n "$HOSTS_RESERVA" ] && printf '"hostsReserva":"%s"' "$HOSTS_RESERVA" )$( [ -n "$HOSTS_RESERVA" ] && [ "$ECOMMERCE" = 1 ] && printf ',' )$( [ "$ECOMMERCE" = 1 ] && printf '"ecommerce":true' )}"
fi
NAV_PARALELO="${NAV_PARALELO:-3}"
# 1-nov-2026 · LA MARCA. marca-gate.js compara lo que se ve con la paleta y los tipos
#    del fichero de marca de la web (_diseno/MARCA.md: los #hex bajo «## Colores», los
#    nombres entre comillas invertidas bajo «## Tipos»). Sin el fichero, las listas van
#    vacias y el gate dice NO MEDIDO en esas dos reglas: no compara contra nada.
#    Al principio SOLO AVISA: una puerta que para a las diez webs el primer dia por algo
#    que ninguna tenia ensena a saltarsela. Para cuando la web pone MARCA_GATE=para.
#    Va dentro de un JSON y de comillas simples del shell remoto: solo #hex, letras,
#    cifras, espacio y guion (y en los selectores, # . _ ,).
MARCA_GATE="${MARCA_GATE:-avisa}"
MARCA_IGNORAR="$(printf '%s' "${MARCA_IGNORAR:-}" | tr -cd 'A-Za-z0-9#._, -')"
# 2-nov-2026 · ¿hay logo en vector? Sin el, B2 no puede pedir el icono SVG sin que
#    alguien lo redibuje a mano (un logo nuevo): el gate lo deja en AVISO. Se busca un
#    fichero de logo o de icono en SVG en el arbol (no en _seo/, que lleva QR y graficos).
MARCA_VECTOR=false
[ -n "$(find "$REPO" -maxdepth 4 \( -name node_modules -o -name .git -o -name _seo \) -prune -o -type f \
  \( -iname '*logo*.svg' -o -iname 'favicon.svg' -o -iname 'icon.svg' -o -ipath '*/marca/*.svg' -o -ipath '*/brand/*.svg' \) \
  -print 2>/dev/null | head -1)" ] && MARCA_VECTOR=true
MARCA_CFG="$(IGN="$MARCA_IGNORAR" LV="$MARCA_VECTOR" perl -e '
  # dos sentencias: un `my $f` no existe hasta la siguiente, y `open my $f … and <$f>` leia de otra $f, vacia
  my $s = ""; if (-f $ARGV[0]) { local $/; if (open my $f, "<", $ARGV[0]) { $s = <$f> // ""; } }
  my ($c) = $s =~ /^##[ \t]+Colores[^\n]*\n(.*?)(?=^##[ \t]|\z)/msi;
  my ($t) = $s =~ /^##[ \t]+Tipos[^\n]*\n(.*?)(?=^##[ \t]|\z)/msi;
  my %v; my @col = grep { !$v{$_}++ } map { my $h = lc $_; length($h) == 3 ? join("", map { $_ x 2 } split //, $h) : $h }
    (($c // "") =~ /#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b/g);
  my %w; my @tip = grep { length && !$w{lc $_}++ } map { (my $x = $_) =~ tr/A-Za-z0-9 -//cd; $x } (($t // "") =~ /`([^`]+)`/g);
  my @ign = grep { length } map { s/^\s+|\s+$//gr } split /,/, ($ENV{IGN} // "");
  my $l = sub { join ",", map { "\"$_\"" } @_ };
  my $lv = ($ENV{LV} // "") eq "true" ? "true" : "false";
  print "{\"colores\":[", $l->(map { "#$_" } @col), "],\"tipos\":[", $l->(@tip), "],\"ignorar\":[", $l->(@ign), "],\"logoVector\":$lv}";
' "$REPO/_diseno/MARCA.md" 2>/dev/null)"
# 6-nov-2026 · LOS BOTONES. botones-gate.js (y botones-sitio.js entre paginas). Como la
#    marca, al principio SOLO AVISA: medido ese dia en diez portadas, tres webs tenian un
#    mismo boton con dos formas (un CTA de cabecera mas pequeño, el boton del formulario
#    con otro cuerpo o con Arial). Para la subida cuando la web pone BOTONES_GATE=para.
#    BOTONES_FAMILIAS: «nombre=selector,selector; nombre=selector». Solo letras, cifras,
#    espacio y . # _ - , = ; (va dentro de un JSON y de comillas simples del shell remoto).
BOTONES_GATE="${BOTONES_GATE:-avisa}"
# 6-nov-2026 · EL AVISO DE COOKIES. banner-probe.js media solo lo servido, y por eso el B8 de
#    un cambio de aviso o de pie se veia despues de subir. Ahora mide el candidato, una vez por
#    subida (el aviso es de todo el sitio). Como marca y botones, al principio SOLO AVISA, y su
#    NO MEDIDO (una CMP en un iframe, por ejemplo) no es un hueco hasta BANNER_GATE=para.
BANNER_GATE="${BANNER_GATE:-avisa}"
# 6-nov-2026 · LO QUE SE VE. visible-gate.js (VI1, el contenido invisible al cargar; VI2, el
#    foco tapado por lo fijo, WCAG 2.4.11). Al principio SOLO AVISA, como marca y botones:
#    medido ese dia en 10 webs (5 paginas cada una, a 1366 y 390), 45 de las 100 medidas
#    dejaban paradas de Tab enteras debajo de la cabecera pegada (con Shift+Tab, en 6 webs);
#    la unica con scroll-padding-top, limpia. Para la subida cuando la web pone VISIBLE_GATE=para.
VISIBLE_GATE="${VISIBLE_GATE:-avisa}"
# 7-nov-2026 · LAS HUELLAS DE UNA PAGINA HECHA EN SERIE. huellas-gate.js (HU1-HU5, las huellas;
#    HU6-HU7, la lectura; HU8, el telefono). Al principio SOLO AVISA, como marca y botones:
#    medido ese dia en 10 webs (5 paginas cada una, a 1366 y 390), 18 paginas en FALLA a 1366
#    y 22 a 390, en 6 webs (halos de color en los botones, antetitulos encima de cada h2, un
#    telefono cuyo pattern rechaza un numero internacional valido); 4 webs, limpias. Para la
#    subida cuando la web pone HUELLAS_GATE=para.
HUELLAS_GATE="${HUELLAS_GATE:-avisa}"
# 6-nov-2026 · EL CONTRASTE DEL CROMO. structure-gate.js media el contraste de <main> y nada
#    mas: una miga fuera de <main> estaba a 3,6:1 en cuatro paginas de una tienda y ningun
#    gate lo veia. Ahora mide tambien la cabecera, la miga y el pie, y lo deja aparte, en
#    avisosCromo (nav_lee lo ensena como «aviso:»). Como marca, botones y aviso de cookies,
#    al principio SOLO AVISA: para la subida cuando la web pone CROMO_GATE=para, que llega
#    al gate como "cromo":"para" dentro de NAV_CFG. Fecha para ponerlo en las webs: 20-nov.
cromo_cfg() {    # NAV_CFG -> NAV_CFG con "cromo":"para" si CROMO_GATE=para
  [ "${CROMO_GATE:-avisa}" = para ] || return 0
  if [ -n "$NAV_CFG" ]; then NAV_CFG="${NAV_CFG%\}},\"cromo\":\"para\"}"; else NAV_CFG='{"cromo":"para"}'; fi
}
CROMO_GATE="${CROMO_GATE:-avisa}"
cromo_cfg
BOTONES_CFG="$(FAM="$(printf '%s' "${BOTONES_FAMILIAS:-}" | tr -cd 'A-Za-z0-9#._, =;-')" IGN="$MARCA_IGNORAR" perl -e '
  my @f = grep { length $_->[0] && length $_->[1] } map { my ($n, $s) = split /=/, $_, 2; [ ($n // "") =~ s/^\s+|\s+$//gr, ($s // "") =~ s/^\s+|\s+$//gr ] } split /;/, ($ENV{FAM} // "");
  my @ign = grep { length } map { s/^\s+|\s+$//gr } split /,/, ($ENV{IGN} // "");
  print "{", (@f ? "\"familias\":{" . join(",", map { "\"$_->[0]\":\"$_->[1]\"" } @f) . "}," : ""),
        "\"ignorar\":[", join(",", map { "\"$_\"" } @ign), "]}";
' 2>/dev/null)"
. "$REF/nav-host.sh"
NAV_HOST="$(nav_host "$REF")"
NAV_HOST_CONF="$(nav_host_conf "$REF")"
NAV_ENV=""   # en el 1-quater lleva GATE_CANDIDATO y GATE_SITIO; en el 6, nada

# 1-nov-2026 · QUE PAGINAS MIDE EL NAVEGADOR: las declaradas Y las que cambia esta
#    subida. Dos casos del 31-oct: una guia NUEVA paso la puerta con G11 en PASA y
#    quedo servida con measure-screens en FALLA (3 pantallas sin CTA), porque no
#    estaba en URLS_NAVEGADOR; y una tarjeta mas en la portada la rompio siendo
#    otra la pagina «cambiada». Una pagina nueva o cuyo HTML cambia se mide, en el
#    1-quater y en el 6. Un enlace nuevo cambia el HTML del hub que lo recibe: el
#    hub entra solo.
#    Contra que: las huellas (hash, tamano, ruta) del arbol de la subida anterior,
#    que la puerta guarda al acabar en _deploy/.desplegado-huellas.txt. Sin ellas
#    solo se ven las ALTAS, contra .desplegado.txt, y se dice.
#    Tope: URLS_CAMBIADAS_MAX (8 por defecto), altas primero. Un cambio de plantilla
#    toca todas las paginas y medirlas todas a ocho anchos tarda; las que quedan
#    fuera se dicen y se anotan, no se callan.
#    🔴 7-nov-2026 · LA MEDIDA CORTA PARA LAS DE MAS. Una subida cambio 28 paginas, el
#    1-quater midio 8 y las otras 20 subieron sin medir: entre ellas iba un FALLA nuevo
#    de structure-gate (PROSA-1) en la pieza de contenido de esa subida, y el cierre lo
#    dijo con todo ya subido. Las que pasan del tope se miden ahora con la medida corta
#    (structure-gate a 1298, measure-screens y mobile-gate a 390: lo que caza un defecto
#    de contenido), hasta URLS_CAMBIADAS_CORTA_MAX (40); solo las que pasan de los dos
#    topes quedan fuera, dichas y anotadas como antes.
# >>> paginas-cambiadas (marca del banco deploy-tests: no la muevas sin moverlo)
HUELLAS_ANT="$REPO/_deploy/.desplegado-huellas.txt"
# La primera linea dice como se tomaron. Unas huellas de otra version (las del 1-nov
# por la manana llevaban el ?v= dentro) no se comparan: daria la web entera por cambiada.
HUELLAS_VERSION="# huellas-v2 (html sin sellos ?v=)"
URLS_CAMBIADAS_MAX="${URLS_CAMBIADAS_MAX:-${CHANGED_URLS_MAX:-8}}"
URLS_CAMBIADAS_CORTA_MAX="${URLS_CAMBIADAS_CORTA_MAX:-${CHANGED_URLS_SHORT_MAX:-40}}"
URLS_CAMBIADAS=""; CAMBIADAS_ALTAS=0; CAMBIADAS_N=0; CAMBIADAS_FUERA=0; CAMBIADAS_NOTA=""; CAMBIADAS_TODAS=""
URLS_CAMBIADAS_CORTA=""; CAMBIADAS_CORTA_N=0
#    🔴 EL SELLO ?v= NO ES UN CAMBIO DE PAGINA (1-nov, el mismo dia): cambiar el CSS
#    reescribe `styles.css?v=…` en TODAS las paginas, y con el hash del fichero cada
#    subida «cambiaba» la web entera, llenaba el tope con las primeras por orden
#    alfabetico y arrastraba la legal. En el HTML la huella se toma sin los ?v=.
arbol_huellas() {   # hash tamano ruta, una linea por fichero del arbol desplegable
  local h t rel
  perl "$REF/receipt.pl" --arbol --listar --repo "$REPO" 2>/dev/null | awk '$1 ~ /^[0-9a-f]{8}$/ && $2 ~ /^[0-9]+$/' |
  while read -r h t rel; do
    case "$rel" in
      *.html) h="$(sed -E 's/\?v=[A-Za-z0-9._-]+//g' "$REPO/$rel" 2>/dev/null | md5sum | cut -c1-8)" ;;
    esac
    printf '%s %s %s\n' "$h" "$t" "$rel"
  done
}
pagina_ruta() {     # como sirve run-gate el candidato: index.html -> / · sub/index.html -> /sub/ · otra.html -> /otra
  case "$1" in
    index.html)   printf '/\n' ;;
    */index.html) printf '/%s/\n' "${1%/index.html}" ;;
    *)            printf '/%s\n' "${1%.html}" ;;
  esac
}
paginas_cambiadas() {   # -> URLS_CAMBIADAS, CAMBIADAS_ALTAS, CAMBIADAS_N, URLS_CAMBIADAS_CORTA, CAMBIADAS_FUERA, CAMBIADAS_NOTA
  local hoy lista tipo rel r d decl=" "
  hoy="$(arbol_huellas)"
  if [ -s "$HUELLAS_ANT" ] && [ "$(head -1 "$HUELLAS_ANT")" = "$HUELLAS_VERSION" ]; then
    lista="$(printf '%s\n' "$hoy" | awk 'NR==FNR { if ($0 !~ /^#/) h[$3]=$1; next } $3 ~ /\.html$/ { if (!($3 in h)) print "0 " $3; else if (h[$3] != $1) print "1 " $3 }' "$HUELLAS_ANT" -)"
  elif [ -s "$REPO/_deploy/.desplegado.txt" ]; then
    lista="$(printf '%s\n' "$hoy" | awk 'NR==FNR { v[$0]=1; next } $3 ~ /\.html$/ && !($3 in v) { print "0 " $3 }' "$REPO/_deploy/.desplegado.txt" -)"
    CAMBIADAS_NOTA="sin huellas (de esta version) de la subida anterior: solo las altas (las cambiadas, desde la proxima subida)"
  else
    CAMBIADAS_NOTA="sin lista de la subida anterior: solo URLS_NAVEGADOR"
    return 0
  fi
  for r in ${URLS_NAVEGADOR:-/}; do decl="$decl${r%/}| "; done
  while read -r tipo rel; do
    [ -n "$rel" ] || continue
    case "/$rel" in */_*|*/.*|/404.html) continue ;; esac
    [[ "$rel" =~ ^google[0-9a-f]+\.html$ ]] && continue   # verificacion de Search Console
    # todas, sin tope y tambien las declaradas: el cierre mira que se sirva CADA una (5-nov-2026)
    CAMBIADAS_TODAS="${CAMBIADAS_TODAS:+$CAMBIADAS_TODAS }$rel"
    r="$(pagina_ruta "$rel")"; d="${r%/}"
    case "$decl" in *" $d| "*) continue ;; esac
    if [ "$CAMBIADAS_N" -lt "$URLS_CAMBIADAS_MAX" ]; then
      URLS_CAMBIADAS="${URLS_CAMBIADAS:+$URLS_CAMBIADAS }$r"; decl="$decl$d| "
      CAMBIADAS_N=$((CAMBIADAS_N+1)); [ "$tipo" = 0 ] && CAMBIADAS_ALTAS=$((CAMBIADAS_ALTAS+1))
    elif [ "$CAMBIADAS_CORTA_N" -lt "$URLS_CAMBIADAS_CORTA_MAX" ]; then
      URLS_CAMBIADAS_CORTA="${URLS_CAMBIADAS_CORTA:+$URLS_CAMBIADAS_CORTA }$r"; decl="$decl$d| "
      CAMBIADAS_CORTA_N=$((CAMBIADAS_CORTA_N+1))
    else
      CAMBIADAS_FUERA=$((CAMBIADAS_FUERA+1))
    fi
  done <<EOF
$(printf '%s\n' "$lista" | LC_ALL=C sort -k1,1n -k2)
EOF
}
urls_navegador() { printf '%s\n' ${URLS_NAVEGADOR:-/} $URLS_CAMBIADAS; }   # la lista de las dos medidas
# <<< paginas-cambiadas

nav_empuja() {   # los gates y el corredor, canonicos, al servidor (dos copias divergen el primer dia)
  ssh -n -o BatchMode=yes "$NAV_HOST" 'mkdir -p ~/webtools/gates' >/dev/null 2>&1 || return 1
  scp -q "$REF/run-gate.js" "$NAV_HOST:webtools/run-gate.js" </dev/null 2>/dev/null || return 1
  local g
  for g in structure-gate.js measure-screens.js forms-gate.js mobile-gate.js mobile-menu-gate.js marca-gate.js botones-gate.js visible-gate.js huellas-gate.js; do
    [ -f "$REF/$g" ] && { scp -q "$REF/$g" "$NAV_HOST:webtools/gates/$g" </dev/null 2>/dev/null || return 1; }
  done
  # banner-probe.js va al lado de run-gate.js, no en gates/: de el saca como servir el arbol.
  [ -f "$REF/banner-probe.js" ] && { scp -q "$REF/banner-probe.js" "$NAV_HOST:webtools/banner-probe.js" </dev/null 2>/dev/null || return 1; }
  return 0
}

nav_mide() {     # <fichero de salida> <url> <gate> <ancho> <alto> [json de __GATE__]
  # ⚠️ El JSON va entre COMILLAS SIMPLES para el shell remoto. Con dobles,
  #    `"{"exigeFormulario":true}"` pierde las suyas por el camino y `node`
  #    recibe `{exigeFormulario:true}`, que no es JSON; `run-gate.js` muere con
  #    RUNNER-ERROR y parecia un problema de red. Probado antes de darlo por bueno.
  # `-n`: se llama en segundo plano dentro de un `while read`, y un ssh sin -n se
  # come el resto de la lista.
  # Una medida que no llega a dar veredicto, o que mide un muro, se repite UNA vez:
  # el barrido del 1-nov-2026 dio cuatro «504 Gateway Time-out» seguidos de un host
  # compartido que poco despues servia bien. La segunda tambien mal = NO MEDIDO.
  # 6-nov-2026 · Y EL MENU QUE «NO ABRE» SE REPITE UNA VEZ, CON LA CARGA ANOTADA. El 5-nov
  #    mobile-menu-gate dio N3 (nada nuevo en 1500 ms) con el host a carga 20 en 4 nucleos,
  #    y la misma medida, con carga 1,9, dio 5 de 5 PASA. Una espera que vence porque el
  #    servidor va lento no es un menu roto. Si la segunda tambien falla, cuenta, y lleva
  #    la carga de las dos al lado para que quien lo lea sepa con que se midio.
  local i carga=""
  for i in 1 2; do
    ssh -n -o BatchMode=yes "$NAV_HOST" \
        "cd ~/webtools && ${NAV_ENV}node run-gate.js '$2' $4 $5 gates/$3 ${6:+'$6'}" > "$1" 2>&1
    if grep -q '"VEREDICTO"' "$1" && ! grep -q '"sospechoso":true' "$1"; then
      if [ "$3" = mobile-menu-gate.js ] && grep -q 'N3 · el boton de menu NO ABRE' "$1"; then
        carga="${carga:+$carga, luego }$(ssh -n -o BatchMode=yes "$NAV_HOST" 'cut -d" " -f1 /proc/loadavg; nproc' 2>/dev/null | paste -sd/ -)"
        if [ "$i" = 1 ]; then sleep 5; continue; fi
        echo "NAV-NOTA: N3 dos veces; carga del host (1 min/nucleos): $carga" >> "$1"
      elif [ -n "$carga" ]; then
        echo "NAV-NOTA: la primera medida dio N3 con carga $carga (1 min/nucleos); repetida, abre" >> "$1"
      fi
      return 0
    fi
    [ "$i" = 1 ] && sleep 5
  done
  return 0
}

nav_lee() {      # <fichero> <gate> <ruta> <ancho> -> imprime la linea; NAV_R = PASA | FALLA | NO MEDIDO
  local out titulo ver
  out="$(cat "$1" 2>/dev/null)"
  NAV_R="NO MEDIDO"
  # 🔴 1-nov-2026 · EN EL CANDIDATO, ANTES QUE NADA, QUE SE HAYA SERVIDO EL CANDIDATO.
  #    `run-gate.js` sirve del disco lo que se pide al origen de la web y cuenta las
  #    respuestas en `candidato`. Con 0 lo medido es la web YA SUBIDA, y un PASA de
  #    produccion sobre un arbol que nadie ha mirado es el fallo del 11-ago otra vez.
  if [ -n "$NAV_ENV" ] && ! printf '%s' "$out" | grep -q '"candidato":[1-9]'; then
    printf '    %-22s %-26s %4spx  NO MEDIDO (no se ha servido el candidato)\n' "$2" "$3" "$4"; return
  fi
  # 🔴 18-ago-2026 · Y ANTES QUE `coincide`, QUE SEA LA PAGINA. `coincide` dice
  #    que el ancho es el pedido; no dice que se haya medido el sitio. site-a y
  #    loja.site-b sirven a este Chrome un muro anti-bot y el gate media el
  #    muro: 1 pantalla, 0 CTA, FALLA. Una acusacion falsa contra dos de las
  #    cinco webs, con el ancho cuadrando. `run-gate.js` ahora lo marca.
  if printf '%s' "$out" | grep -q '"sospechoso":true'; then
    titulo="$(printf '%s' "$out" | grep -oE '"titulo":"[^"]*"' | head -1 | sed 's/.*://;s/"//g' | cut -c1-40)"
    printf '    %-22s %-26s %4spx  NO MEDIDO (no parece la pagina: %s)\n' "$2" "$3" "$4" "$titulo"; return
  fi
  # ⚠️ REGLA DE LA CASA: `coincide` PRIMERO. Una medida hecha a un ancho que no
  #    es el pedido no es un resultado peor: es basura, y darla por numero es
  #    peor que no medir.
  if ! printf '%s' "$out" | grep -q '"coincide":true'; then
    printf '    %-22s %-26s %4spx  NO MEDIDO (el ancho no coincide o no cargo)\n' "$2" "$3" "$4"; return
  fi
  ver="$(printf '%s' "$out" | grep -m1 '"VEREDICTO"' | grep -o 'PASA\|FALLA')"
  if [ -z "$ver" ]; then
    printf '    %-22s %-26s %4spx  NO MEDIDO (el gate no dio veredicto)\n' "$2" "$3" "$4"; return
  fi
  NAV_R="$ver"
  # 1-nov-2026 · marca-gate solo avisa hasta MARCA_GATE=para: su FALLA se ensena
  #    entero, pero cuenta como AVISO y no para la subida.
  #    6-nov-2026 · y botones-gate, igual, hasta BOTONES_GATE=para; y visible-gate, hasta VISIBLE_GATE=para.
  #    7-nov-2026 · y huellas-gate, hasta HUELLAS_GATE=para.
  local clave=""
  case "$2" in
    marca-gate.js)   [ "${MARCA_GATE:-avisa}" != para ]   && clave=MARCA_GATE ;;
    botones-gate.js) [ "${BOTONES_GATE:-avisa}" != para ] && clave=BOTONES_GATE ;;
    visible-gate.js) [ "${VISIBLE_GATE:-avisa}" != para ] && clave=VISIBLE_GATE ;;
    huellas-gate.js) [ "${HUELLAS_GATE:-avisa}" != para ] && clave=HUELLAS_GATE ;;
  esac
  if [ "$ver" = FALLA ] && [ -n "$clave" ]; then
    NAV_R="AVISO"
    printf '    %-22s %-26s %4spx  AVISO (solo avisa hasta %s=para)\n' "$2" "$3" "$4" "$clave"
    printf '%s' "$out" | grep -A6 '"fallos"' | head -7 | sed 's/^/        /'
    return 0
  fi
  printf '    %-22s %-26s %4spx  %s\n' "$2" "$3" "$4" "$ver"
  [ "$ver" = FALLA ] && printf '%s' "$out" | grep -A6 '"fallos"' | head -7 | sed 's/^/        /'
  printf '%s\n' "$out" | grep '^NAV-NOTA: ' | sed 's/^NAV-NOTA: /        nota: /'
  # 6-nov-2026 · el contraste del cromo, mientras solo avisa (CROMO_GATE=avisa): structure-gate
  #    lo deja en avisosCromo, que no cuenta para su veredicto. Sin esta linea no lo veia nadie.
  [ "$2" = structure-gate.js ] && printf '%s' "$out" | perl -0ne '
    if (/"avisosCromo":\s*\[\s*"((?:[^"\\]|\\.)*)"/) { (my $m = $1) =~ s/\\"/"/g; print "        aviso: $m\n" }'
  return 0
}

nav_corre() {    # <dir> <lista: n ruta gate ancho alto conCfg>  -> mide en paralelo, cada una en <dir>/<n>.out
  local n r g w h c
  while read -r n r g w h c; do
    # `wait -n` es de bash 4.3; sin el (bash 3 de macOS) se espera a todas: mas lento, igual de correcto
    while [ "$(jobs -rp | wc -l)" -ge "$NAV_PARALELO" ]; do wait -n 2>/dev/null || wait; done
    nav_mide "$1/$n.out" "${SITIO%/}$r" "$g" "$w" "$h" "$( [ "$c" = c ] && printf '%s' "$NAV_CFG"; [ "$c" = m ] && printf '%s' "$MARCA_CFG"; [ "$c" = b ] && printf '%s' "$BOTONES_CFG" )" &
  done < "$2"
  wait
}

# >>> nav_decide · la decision del 1-quater (deploy-tests/tests.sh ejecuta estos bytes)
# 🔴 1-nov-2026 · Entra: NAVC_ROJOS (los gates en FALLA, por nombre), NAVC_HUECOS (lo
#    que no se pudo medir), NAVC_EXIGE (1 = la web declara URLS_NAVEGADOR), AUN_ASI y
#    SUBIR. Imprime la decision, deja en NAVC_NOTA lo que se anota y devuelve 1 si
#    la subida se para. No escribe en ningun sitio: eso lo hace quien la llama.
#    El motivo que dice que algo «lo contesta el navegador» se rechaza cuando el
#    navegador ya ha contestado otra cosa (FALLA) o no ha contestado nada (no medido):
#    un motivo que se apoya en un instrumento que dice lo contrario no es un motivo.
RE_NAV_CONTESTA='(contest|respond|cubr|cubre|mide|miden|medir|medira|comprueb|answer|cover|check)[a-z]*[^.;]{0,60}(navegador|browser|paso 6|step 6)|(navegador|browser|paso 6|step 6)[^.;]{0,30}(contest|respond|cubr|cubre|mide|miden|medir|medira|comprueb|answer|cover|check)'
nav_decide() {
  NAVC_NOTA=""
  local g faltan="" contesta=0 motivo
  # ⚠️ En minusculas con `tr` y comparado con `case`/`grep -E`, NUNCA con `grep -i`: el
  #    grep de Git Bash ABORTA con `-iF` (SIGABRT, medido en el banco el 1-nov-2026), y
  #    el `||` lo leia como «no lo nombra»: toda firma valida salia rechazada.
  motivo="$(printf '%s' "$AUN_ASI" | tr '[:upper:]' '[:lower:]')"
  if [ -n "$motivo" ] && printf '%s' "$motivo" | grep -qE "$RE_NAV_CONTESTA"; then contesta=1; fi
  if [ -n "$NAVC_ROJOS" ]; then
    if [ "$contesta" = 1 ]; then
      echo "  🔴 EL MOTIVO DICE QUE LO CONTESTA EL NAVEGADOR, Y EL NAVEGADOR YA HA CONTESTADO:"
      echo "     FALLA en $NAVC_ROJOS. Ese motivo no se acepta: se arregla el arbol, o se firma"
      echo "     cada gate en rojo con un motivo que no diga lo contrario de lo medido."
      [ "$SUBIR" = 1 ] && { echo "  NO SE DESPLIEGA."; return 1; }
      echo "  (ensayo: con --subir, este motivo se rechazaria y no se subiria)"; return 0
    fi
    for g in $NAVC_ROJOS; do
      case "$motivo" in *"${g%.js}"*) ;; *) faltan="$faltan $g" ;; esac
    done
    faltan="${faltan# }"
    if [ -n "$faltan" ]; then
      echo "  🔴 EN ROJO EN EL NAVEGADOR NO SE SUBE: FALLA en $NAVC_ROJOS"
      if [ -n "$AUN_ASI" ]; then
        echo "     El --aun-asi no nombra: $faltan. Cada gate en rojo se nombra, uno a uno."
      else
        echo "     Se arregla en el arbol y se vuelve a medir. Para subirlo asi, que conste cada uno:"
        echo "         --aun-asi \"${NAVC_ROJOS// /, }: el motivo\""
      fi
      [ "$SUBIR" = 1 ] && { echo "  NO SE DESPLIEGA."; return 1; }
      echo "  (ensayo: con --subir, esto para la subida)"; return 0
    fi
    echo "  se sube con el navegador en rojo, firmado gate a gate: $NAVC_ROJOS"
    echo "  Motivo: $AUN_ASI"
    NAVC_NOTA="NAVEGADOR-ROJO [$NAVC_ROJOS] $AUN_ASI"
  fi
  if [ -n "$NAVC_HUECOS" ]; then
    if [ "$contesta" = 1 ]; then
      echo "  🔴 EL MOTIVO DICE QUE LO CONTESTA EL NAVEGADOR, Y EL NAVEGADOR NO HA MEDIDO EL CANDIDATO:"
      echo "     $NAVC_HUECOS"
      [ "$SUBIR" = 1 ] && { echo "  NO SE DESPLIEGA."; return 1; }
      echo "  (ensayo: con --subir, este motivo se rechazaria y no se subiria)"; return 0
    fi
    if [ "$NAVC_EXIGE" = 1 ] && ! printf '%s' "$motivo" | grep -qE 'navegador|browser'; then
      echo "  🔴 NO MEDIDO NO ES UN APROBADO. Esta web declara URLS_NAVEGADOR y el candidato"
      echo "     no se ha podido medir entero: $NAVC_HUECOS"
      echo "     Para subir asi, que conste:  --aun-asi \"sin navegador: el motivo\""
      [ "$SUBIR" = 1 ] && { echo "  NO SE DESPLIEGA."; return 1; }
      echo "  (ensayo: con --subir, esto para la subida)"; return 0
    fi
    NAVC_NOTA="${NAVC_NOTA:+$NAVC_NOTA · }NAVEGADOR-CANDIDATO no medido [$NAVC_HUECOS]${AUN_ASI:+ $AUN_ASI}"
  fi
  return 0
}
# <<< nav_decide

# >>> navc_disco · el disco del servidor de medir (deploy-tests/tests.sh ejecuta estos bytes)
# 🔴 7-nov-2026 · EL DISCO DEL SERVIDOR DE MEDIR LLEGO AL 100 %. Alli corren las sondas de
#    todas las webs y otras herramientas de la casa, y un disco lleno las tumba a todas. La
#    puerta copiaba el candidato a /tmp sin mirar cuanto quedaba, y lo borraba solo si llegaba
#    al final del 1-quater: una puerta cortada a medias (Ctrl-C, un ssh que cae) lo dejaba alli.
#    Ahora: antes de copiar, df de /tmp; si tras el candidato (dos veces su tamano: el arbol y
#    lo que escribe Chrome al medirlo) quedan menos de CANDIDATO_LIBRE_MIN_MB, no se copia y el
#    1-quater sale NO MEDIDO, que para la subida de una web con URLS_NAVEGADOR como cualquier
#    otro hueco. Por debajo de CANDIDATO_LIBRE_AVISO_MB se mide y se avisa. Y se borra con un
#    trap, salga la puerta por donde salga. Lo viejo nuestro (wqs-candidato-* de mas de 6 h) se
#    barre antes de copiar; lo que no lleva ese nombre no se toca.
#    ⚠️ El 7-nov quedaban 3,5 GB: un tope de 5 GB para copiar habria dejado sin 1-quater a todas
#       las webs por un disco que llenan otros. Por eso el tope es lo que QUEDA (2 GB) y los 5 GB
#       son el aviso.
# navc_hay_sitio <MB libres en /tmp> <MB del candidato> -> 0 si se copia; la frase, en NAVC_DISCO
navc_hay_sitio() {
  local libre="$1" cand="${2:-0}" min="${CANDIDATO_LIBRE_MIN_MB:-2048}" aviso="${CANDIDATO_LIBRE_AVISO_MB:-5120}" queda
  NAVC_DISCO=""
  if ! printf '%s' "$libre" | grep -qE '^[0-9]+$'; then
    NAVC_DISCO="disco de ${NAV_HOST:-el servidor}: NO MEDIDO (df no ha contestado); se copia igual"; return 0
  fi
  printf '%s' "$cand" | grep -qE '^[0-9]+$' || cand=0
  queda=$(( libre - 2 * cand ))
  if [ "$queda" -lt "$min" ]; then
    NAVC_DISCO="disco de ${NAV_HOST:-el servidor}: $libre MB libres en /tmp; con el candidato ($cand MB, dos veces) quedarian $queda, menos de CANDIDATO_LIBRE_MIN_MB=$min. No se copia: un disco lleno tumba todo lo que mide alli"
    return 1
  fi
  [ "$libre" -lt "$aviso" ] && NAVC_DISCO="⚠ disco de ${NAV_HOST:-el servidor}: $libre MB libres en /tmp, menos de CANDIDATO_LIBRE_AVISO_MB=$aviso. Se mide igual"
  return 0
}
# navc_limpia: borra la copia del candidato en el servidor (solo una ruta /tmp/wqs-candidato-*) y la
# carpeta local. Se llama al final del 1-quater y desde el trap; dos veces no hace nada.
navc_limpia() {
  case "${NAVC_R:-}" in
    /tmp/wqs-candidato-?*) case "$NAVC_R" in *..*|*\'*|*" "*) ;; *) ssh -n -o BatchMode=yes "$NAV_HOST" "rm -rf '$NAVC_R'" >/dev/null 2>&1 ;; esac ;;
  esac
  NAVC_R=""
  [ -n "${NAVC_DIR:-}" ] && rm -rf "$NAVC_DIR"
  NAVC_DIR=""
  return 0
}
# <<< navc_disco

# >>> nav_d057 · D-057 en el 1-quater (deploy-tests/tests.sh ejecuta estos bytes)
# 🔴 6-nov-2026 · Una pieza de 5 lineas en el <head> de 89 paginas paso el paso 1-D057
#    y la paro el 1-quater: 5 FALLA en 4 paginas, las cinco iguales en produccion y con
#    su fila al 16/17-dic. La regla de D-057 solo se aplicaba a qa-master; al navegador
#    le quedaba el --aun-asi, que es de Manuel. Entra <rojas> (n ruta gate ancho alto c,
#    una FALLA por linea, en el orden de la lista que se le dio a d057.pl --navegador) y
#    la salida de d057.pl. Un gate sale de NAVC_ROJOS solo si TODAS sus FALLA son D-057;
#    lo que d057.pl no conteste (no corrio, NO MEDIDO, PARA) sigue en rojo. Deja en
#    NAVC_D057 las medidas que pasan por viejas y resta su cuenta de NAVC_FALLOS.
nav_d057_aplica() {
  local k=0 n r g w h c est quedan="" g2 tod
  NAVC_D057=""; NAVC_D057_N=0
  tod="$(while read -r n r g w h c; do
           k=$((k+1))
           est="$(grep -m1 "^D057-NAV: $k " "$2" 2>/dev/null | cut -d' ' -f3)"
           printf '%s %s %s %s\n' "${g%.js}" "$r" "$w" "${est:-NADA}"
         done < "$1")"
  for g in $NAVC_ROJOS; do
    if printf '%s\n' "$tod" | grep -q "^$g " && ! printf '%s\n' "$tod" | grep "^$g " | grep -qv ' D-057$'; then
      while read -r g2 r w est; do
        [ "$g2" = "$g" ] || continue
        NAVC_D057="${NAVC_D057:+$NAVC_D057, }$g $r ${w}px"; NAVC_D057_N=$((NAVC_D057_N+1))
      done <<EOF
$tod
EOF
      echo "  $g: sus FALLA son viejas, iguales en produccion y con fila: no paran (D-057)"
    else
      quedan="${quedan:+$quedan }$g"
      printf '%s\n' "$tod" | grep -q "^$g " && echo "  $g: sigue en rojo (no todas sus FALLA son viejas con fila)"
    fi
  done
  NAVC_ROJOS="$quedan"
  NAVC_FALLOS=$(( ${NAVC_FALLOS:-0} - NAVC_D057_N ))
  return 0
}
# <<< nav_d057

# ── 1-quater · LOS GATES DE NAVEGADOR, SOBRE EL CANDIDATO, ANTES DE SUBIR ─────
# 🔴 1-nov-2026 · POR QUE. Una web nueva subio con 10 FALLA de 16-18 medidas en los
#    gates de navegador: el paso 6 los corria DESPUES de subir y no bloqueaba («ya
#    se ha subido, parar no deshace nada»), asi que el rojo llego al historial y a
#    ningun sitio mas. Y el --aun-asi de esa subida firmaba un hueco con «lo
#    contestan G11 y el navegador» cuando el navegador ya habia dicho FALLA.
#    → Se mide EL ARBOL QUE SE VA A SUBIR, en el Chrome del servidor: se copia alli y
#      `run-gate.js` lo sirve del disco con el origen de produccion (enlaces,
#      sitemap y «misma web» no cambian). Un FALLA para la subida; solo pasa con un
#      --aun-asi que nombre cada gate en rojo, y nav_decide rechaza el motivo que
#      se apoya en el navegador cuando el navegador dice lo contrario.
#    Lo que NO para: SIN_NAVEGADOR=1 (un hueco declarado, como en el 6), y una web
#    que no declara URLS_NAVEGADOR y no se ha podido medir (se dice y se anota). Si
#    la web SI declara URLS_NAVEGADOR, no medirla pide --aun-asi con «navegador».
#    Medir no se pregunta: el ensayo (sin --subir) mide igual, y dice lo que pararia.
NAVC_ROJOS=""; NAVC_HUECOS=""; NAVC_EXIGE=0; NAVC_MIRADAS=0; NAVC_FALLOS=0
NAVC_MENU_PASA=0; NAVC_MENU_TOTAL=0; NAVC_MARCA_AVISOS=0; NAVC_D057=""; NAVC_D057_N=0
[ -n "$URLS_NAVEGADOR" ] && NAVC_EXIGE=1
paginas_cambiadas   # antes del 1-quater y de la subida: despues, la lista anterior ya es esta
if [ "$REDIR" = 1 ]; then
  no_aplica "1-quater · navegador sobre el candidato"
elif [ "${SIN_NAVEGADOR:-0}" = 1 ]; then
  linea; echo "  1-quater · navegador sobre el candidato: SIN_NAVEGADOR=1, no se mide"; linea
else
  linea; echo "  1-quater · maqueta, pantallas, movil y menu, sobre el CANDIDATO"; linea
  echo "  paginas: ${URLS_NAVEGADOR:-/} (declaradas)${URLS_CAMBIADAS:+ + $URLS_CAMBIADAS (las que cambia esta subida: $CAMBIADAS_ALTAS altas)}"
  [ "$CAMBIADAS_CORTA_N" -gt 0 ] && echo "  + $CAMBIADAS_CORTA_N cambiadas mas con la medida corta (structure-gate a 1298, measure-screens y mobile-gate a 390; pasan de URLS_CAMBIADAS_MAX=$URLS_CAMBIADAS_MAX): $URLS_CAMBIADAS_CORTA"
  [ "$CAMBIADAS_FUERA" -gt 0 ] && echo "  ⚠ $CAMBIADAS_FUERA paginas cambiadas mas quedan SIN MEDIR por los dos topes (URLS_CAMBIADAS_MAX=$URLS_CAMBIADAS_MAX, URLS_CAMBIADAS_CORTA_MAX=$URLS_CAMBIADAS_CORTA_MAX)"
  [ -n "$CAMBIADAS_NOTA" ] && echo "  ($CAMBIADAS_NOTA)"
  if [ -z "${NAV_HOST:-}" ]; then
    NAVC_HUECOS="todo (NAV_HOST sin configurar)"
    echo "  NO MEDIDO: NAV_HOST sin configurar (ni $CONF, ni el entorno, ni $NAV_HOST_CONF)."
  elif ! ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$NAV_HOST" 'true' 2>/dev/null; then
    NAVC_HUECOS="todo (sin $NAV_HOST)"
    echo "  NO MEDIDO: no llego a $NAV_HOST."
  elif [ ! -f "$REF/run-gate.js" ]; then
    NAVC_HUECOS="todo (falta gates/run-gate.js)"
    echo "  NO MEDIDO: falta $REF/run-gate.js."
  else
    NAVC_DIR="$(mktemp -d -t navcand-XXXXXXXX)"
    NAVC_R="/tmp/wqs-candidato-$(printf '%s' "${REPO%/}" | sed 's|.*/||; s/[^A-Za-z0-9._-]/_/g')-$$-$(date +%s)"
    # El de EXIT encadena el que ya habia (en_curso_fin, la marca de puerta en curso con --subir):
    # pisarlo dejaria la marca puesta si la puerta sale durante el 1-quater.
    trap 'navc_limpia; declare -F en_curso_fin >/dev/null && [ "$SUBIR" = 1 ] && en_curso_fin' EXIT
    trap 'navc_limpia; exit 130' INT; trap 'navc_limpia; exit 143' TERM; trap 'navc_limpia; exit 129' HUP
    NAVC_ARBOL="$(perl "$REF/receipt.pl" --arbol --repo "$REPO" --listar 2>/dev/null | awk '$1 ~ /^[0-9a-f]{8}$/ && $2 ~ /^[0-9]+$/ { $1=""; $2=""; sub(/^  */, ""); print }')"
    NAVC_MB="$( (cd "$REPO" && printf '%s\n' "$NAVC_ARBOL" | tr '\n' '\0' | xargs -0 -r du -ck -- 2>/dev/null) | awk '$2 == "total" { s += $1 } END { print int((s + 1023) / 1024) }')"
    NAVC_LIBRE="$(ssh -n -o BatchMode=yes "$NAV_HOST" "find /tmp -maxdepth 1 -name 'wqs-candidato-*' -mmin +360 -exec rm -rf {} + 2>/dev/null; df -P -m /tmp | awk 'NR == 2 { print \$4 }'" 2>/dev/null)"
    if [ -z "$NAVC_ARBOL" ]; then
      NAVC_HUECOS="todo (receipt.pl no lista el arbol)"
      echo "  NO MEDIDO: receipt.pl --arbol --listar no devuelve ningun fichero."
    elif ! navc_hay_sitio "$NAVC_LIBRE" "$NAVC_MB"; then
      NAVC_HUECOS="todo ($NAVC_DISCO)"
      echo "  NO MEDIDO: $NAVC_DISCO."
    elif ! nav_empuja \
         || ! ssh -n -o BatchMode=yes "$NAV_HOST" "mkdir -p '$NAVC_R/arbol'" 2>/dev/null \
         || ! printf '%s\n' "$NAVC_ARBOL" | (cd "$REPO" && tar -cf - -T -) 2>/dev/null \
              | ssh -o BatchMode=yes "$NAV_HOST" "tar -xf - -C '$NAVC_R/arbol'" 2>/dev/null; then
      NAVC_HUECOS="todo (no se ha podido copiar el candidato a $NAV_HOST)"
      echo "  NO MEDIDO: no se ha podido copiar el arbol ni los gates a $NAV_HOST."
    else
      echo "  $(printf '%s\n' "$NAVC_ARBOL" | grep -c .) ficheros del arbol copiados a $NAV_HOST (${NAVC_MB:-?} MB, en $NAVC_R); se sirven con el origen $SITIO"
      [ -n "$NAVC_DISCO" ] && echo "  $NAVC_DISCO"
      [ -n "$NAV_CFG" ] && echo "  configuracion de los gates de conversion: $NAV_CFG"
      # Los cuatro anchos del primer pantallazo (mobile-gate M1, 1-nov-2026), el menu
      # a 390 y la marca a 1366 y 390. `c` = esa medida recibe NAV_CFG (que cuenta como
      # convertir); `m`, MARCA_CFG (la paleta y los tipos).
      echo "  marca-gate: $( [ "$MARCA_GATE" = para ] && echo 'PARA la subida (MARCA_GATE=para)' || echo 'solo avisa (MARCA_GATE=para cuando _diseno/ este hecho)' )$( [ -f "$REPO/_diseno/MARCA.md" ] || echo '; sin _diseno/MARCA.md: colores y tipos NO MEDIDO' )"
      echo "  botones-gate: $( [ "$BOTONES_GATE" = para ] && echo 'PARA la subida (BOTONES_GATE=para)' || echo 'solo avisa (BOTONES_GATE=para cuando sus botones esten unificados)' )$( [ -n "${BOTONES_FAMILIAS:-}" ] || echo '; sin BOTONES_FAMILIAS: el grupo de un boton son sus clases' )"
      echo "  visible-gate: $( [ "$VISIBLE_GATE" = para ] && echo 'PARA la subida (VISIBLE_GATE=para)' || echo 'solo avisa (VISIBLE_GATE=para cuando nada quede invisible ni tapado)' )"
      echo "  huellas-gate: $( [ "$HUELLAS_GATE" = para ] && echo 'PARA la subida (HUELLAS_GATE=para)' || echo 'solo avisa (HUELLAS_GATE=para cuando la web no lleve huellas de plantilla)' )"
      : > "$NAVC_DIR/lista"; n=0
      for r in $(urls_navegador); do
        for m in "structure-gate.js 1298 720 c" "measure-screens.js 1298 720 -" "measure-screens.js 390 844 -" \
                 "mobile-gate.js 360 740 c" "mobile-gate.js 390 844 c" "mobile-gate.js 1366 768 c" \
                 "mobile-gate.js 1440 900 c" "mobile-menu-gate.js 390 844 -" \
                 "marca-gate.js 1366 768 m" "marca-gate.js 390 844 m" \
                 "botones-gate.js 1366 768 b" "botones-gate.js 390 844 b" \
                 "visible-gate.js 1366 768 -" "visible-gate.js 390 844 -" \
                 "huellas-gate.js 1366 768 -" "huellas-gate.js 390 844 -"; do
          n=$((n+1)); printf '%s %s %s\n' "$n" "$r" "$m" >> "$NAVC_DIR/lista"
        done
      done
      # la medida corta, para las cambiadas que pasan del tope (7-nov-2026, arriba)
      for r in $URLS_CAMBIADAS_CORTA; do
        for m in "structure-gate.js 1298 720 c" "measure-screens.js 390 844 -" "mobile-gate.js 390 844 c"; do
          n=$((n+1)); printf '%s %s %s\n' "$n" "$r" "$m" >> "$NAVC_DIR/lista"
        done
      done
      NAVC_TOTAL=$n   # el `while read -r n` de abajo deja n vacio al acabar
      NAV_ENV="GATE_CANDIDATO='$NAVC_R/arbol' GATE_SITIO='${SITIO%/}' "
      nav_corre "$NAVC_DIR" "$NAVC_DIR/lista"
      NAV_ENV=""
      : > "$NAVC_DIR/rojas"   # las FALLA, una por linea, para medirlas sobre produccion (D-057)
      while read -r n r g w h c; do
        nav_lee "$NAVC_DIR/$n.out" "$g" "$r" "$w"
        case "$NAV_R" in
          PASA)  NAVC_MIRADAS=$((NAVC_MIRADAS+1)) ;;
          AVISO) NAVC_MIRADAS=$((NAVC_MIRADAS+1)); NAVC_MARCA_AVISOS=$((NAVC_MARCA_AVISOS+1)) ;;
          FALLA) NAVC_MIRADAS=$((NAVC_MIRADAS+1)); NAVC_FALLOS=$((NAVC_FALLOS+1))
                 printf '%s %s %s %s %s %s\n' "$n" "$r" "$g" "$w" "$h" "$c" >> "$NAVC_DIR/rojas"
                 case " $NAVC_ROJOS " in *" ${g%.js} "*) ;; *) NAVC_ROJOS="${NAVC_ROJOS:+$NAVC_ROJOS }${g%.js}" ;; esac ;;
          *)     NAVC_HUECOS="${NAVC_HUECOS:+$NAVC_HUECOS, }${g%.js} $r ${w}px" ;;
        esac
        if [ "$g" = mobile-menu-gate.js ]; then
          NAVC_MENU_TOTAL=$((NAVC_MENU_TOTAL+1)); [ "$NAV_R" = PASA ] && NAVC_MENU_PASA=$((NAVC_MENU_PASA+1))
        fi
      done < "$NAVC_DIR/lista"
      # 6-nov-2026 · LOS BOTONES ENTRE PAGINAS: cada pagina sola puede ser coherente y el
      #    sitio no. botones-sitio.js junta las salidas de botones-gate (por ancho) y les
      #    pasa la MISMA comparacion; solo cuenta lo que sale al juntarlas. Corre aqui, en
      #    node local: sin node, NO MEDIDO (y hueco solo si la web ya pide BOTONES_GATE=para).
      NAVC_BOT_OUT="$(awk '$3 == "botones-gate.js" { print $1 }' "$NAVC_DIR/lista" | while read -r k; do printf '%s ' "$NAVC_DIR/$k.out"; done)"
      if [ -n "$NAVC_BOT_OUT" ]; then
        echo
        if ! command -v node >/dev/null 2>&1; then
          echo "    botones-sitio.js       entre paginas               NO MEDIDO (sin node en esta maquina)"
          [ "$BOTONES_GATE" = para ] && NAVC_HUECOS="${NAVC_HUECOS:+$NAVC_HUECOS, }botones-sitio (sin node)"
        else
          # shellcheck disable=SC2086
          BOT_SAL="$(node "$REF/botones-sitio.js" $NAVC_BOT_OUT 2>&1)"; BOT_RC=$?
          printf '%s\n' "$BOT_SAL" | grep -v '^VEREDICTO' | sed 's/^/  /' | head -12
          if [ "$BOT_RC" = 1 ]; then
            if [ "$BOTONES_GATE" = para ]; then
              echo "    botones-sitio.js       entre paginas               FALLA"
              NAVC_FALLOS=$((NAVC_FALLOS+1)); NAVC_ROJOS="${NAVC_ROJOS:+$NAVC_ROJOS }botones-sitio"
            else
              echo "    botones-sitio.js       entre paginas               AVISO (solo avisa hasta BOTONES_GATE=para)"
              NAVC_MARCA_AVISOS=$((NAVC_MARCA_AVISOS+1))
            fi
          fi
        fi
      fi
      # 6-nov-2026 · EL AVISO DE COOKIES, SOBRE EL CANDIDATO. banner-probe.js no es un gate de
      #    run-gate.js: es una sonda con su Chrome, que rechaza el aviso, recarga y lo reabre.
      #    Se le pasa el mismo arbol (GATE_CANDIDATO) y dice cuanto sirvio del disco; con 0,
      #    NO VALE. La portada, a 1298 y a 390. FALLA = AVISO hasta BANNER_GATE=para; NO
      #    MEDIDO, hueco solo con BANNER_GATE=para. Tope de 300 s: sus tres cargas esperan
      #    60 s cada una, y el banco del 6-nov estuvo 15 min sin dar una linea con el host
      #    cargado (a la segunda, 2 min 19 s); colgada, sale NO MEDIDO (rc 124).
      if [ -f "$REF/banner-probe.js" ]; then
        echo
        for bwh in 1298:900 390:844; do
          bw="${bwh%%:*}"; bh="${bwh##*:}"; NAVC_TOTAL=$((NAVC_TOTAL+1))
          ssh -n -o BatchMode=yes "$NAV_HOST" \
              "cd ~/webtools && GATE_CANDIDATO='$NAVC_R/arbol' GATE_SITIO='${SITIO%/}' timeout 300 node banner-probe.js '${SITIO%/}/' $bw $bh" \
              > "$NAVC_DIR/banner-$bw.out" 2>&1
          BAN_RC=$?
          BAN_V="$(grep -m1 '^VEREDICTO:' "$NAVC_DIR/banner-$bw.out" | sed 's/^VEREDICTO: //')"
          if [ "$BAN_RC" = 0 ]; then
            printf '    %-22s %-26s %4spx  PASA%s\n' banner-probe.js / "$bw" "$( [ "$BAN_V" = PASA ] || echo " ($BAN_V)" )"
            NAVC_MIRADAS=$((NAVC_MIRADAS+1))
          elif [ "$BAN_RC" = 1 ]; then
            NAVC_MIRADAS=$((NAVC_MIRADAS+1))
            if [ "$BANNER_GATE" = para ]; then
              printf '    %-22s %-26s %4spx  FALLA\n' banner-probe.js / "$bw"
              NAVC_FALLOS=$((NAVC_FALLOS+1))
              case " $NAVC_ROJOS " in *" banner-probe "*) ;; *) NAVC_ROJOS="${NAVC_ROJOS:+$NAVC_ROJOS }banner-probe" ;; esac
            else
              printf '    %-22s %-26s %4spx  AVISO (solo avisa hasta BANNER_GATE=para)\n' banner-probe.js / "$bw"
              NAVC_MARCA_AVISOS=$((NAVC_MARCA_AVISOS+1))
            fi
            grep -E '^FALLA +B[0-9]' "$NAVC_DIR/banner-$bw.out" | head -6 | sed 's/^/        /'
          else
            printf '    %-22s %-26s %4spx  NO MEDIDO (%s)\n' banner-probe.js / "$bw" \
                   "${BAN_V:-$(grep -m1 'RUNNER-ERROR' "$NAVC_DIR/banner-$bw.out" | cut -c1-60)}"
            [ "$BANNER_GATE" = para ] && NAVC_HUECOS="${NAVC_HUECOS:+$NAVC_HUECOS, }banner-probe / ${bw}px"
          fi
        done
      fi
      # 6-nov-2026 · D-057 EN EL 1-QUATER. Cada FALLA de arriba se mide otra vez sobre
      #    PRODUCCION con el mismo gate, ruta, ancho, alto y configuracion (NAV_ENV vacio:
      #    lo publicado), y d057.pl --navegador hace la pregunta del paso 1-D057: ¿igual en
      #    produccion, y con fila abierta con fecha y dueño que nombre el gate y la pagina?
      #    nav_d057_aplica saca de NAVC_ROJOS el gate cuyas FALLA lo son todas. El aviso
      #    de cookies (banner-probe) y botones-sitio no entran: no son de run-gate.js, y
      #    el consentimiento es una lente que D-057 no cubre.
      if [ -s "$NAVC_DIR/rojas" ] && [ -f "$REF/d057.pl" ]; then
        echo
        echo "  D-057 · $(grep -c . "$NAVC_DIR/rojas") FALLA, medidas otra vez sobre PRODUCCION (mismo gate, ruta y tamano)"
        mkdir -p "$NAVC_DIR/prod"
        nav_corre "$NAVC_DIR/prod" "$NAVC_DIR/rojas"
        awk -v d="$NAVC_DIR" '{ printf "%s %s %s %s %s/%s.out %s/prod/%s.out\n", $3, $2, $4, $5, d, $1, d, $1 }' \
            "$NAVC_DIR/rojas" > "$NAVC_DIR/d057-lista"
        perl "$REF/d057.pl" --repo "$REPO" --navegador "$NAVC_DIR/d057-lista" > "$NAVC_DIR/d057-nav.txt" 2>&1
        grep -v '^D057-NAV: \|^  D-057 · lo viejo' "$NAVC_DIR/d057-nav.txt" | grep . | sed 's/^/  /'
        nav_d057_aplica "$NAVC_DIR/rojas" "$NAVC_DIR/d057-nav.txt"
      fi
      echo
      echo "  $NAVC_MIRADAS medidas · $NAVC_FALLOS FALLA · $(( NAVC_TOTAL - NAVC_MIRADAS )) sin medir$( [ "$NAVC_D057_N" -gt 0 ] && echo " · $NAVC_D057_N FALLA viejas por D-057 (no paran)" )${NAVC_MARCA_AVISOS:+$( [ "$NAVC_MARCA_AVISOS" -gt 0 ] && echo " · $NAVC_MARCA_AVISOS AVISO de marca, botones o aviso de cookies (no paran)" )}"
    fi
    navc_limpia; trap - INT TERM HUP
    if [ "$SUBIR" = 1 ]; then trap en_curso_fin EXIT; else trap - EXIT; fi
  fi
fi
if [ "${SIN_NAVEGADOR:-0}" != 1 ] && [ "$REDIR" != 1 ]; then
  echo
  nav_decide || exit 1
  if [ "$SUBIR" = 1 ]; then
    perl "$REF/receipt.pl" --anotar "NAVEGADOR-CANDIDATO $NAVC_MIRADAS medidas · $NAVC_FALLOS FALLA$( [ "$NAVC_D057_N" -gt 0 ] && echo " · $NAVC_D057_N viejas por D-057")${NAVC_HUECOS:+ · sin medir: $NAVC_HUECOS}${URLS_CAMBIADAS:+ · cambiadas: $URLS_CAMBIADAS}${URLS_CAMBIADAS_CORTA:+ · con la medida corta: $URLS_CAMBIADAS_CORTA}" \
         --repo "$REPO" >/dev/null 2>&1
    [ -n "$NAVC_D057" ] && perl "$REF/receipt.pl" --anotar "NAVEGADOR D-057 [$NAVC_D057] igual en produccion y con fila (gates/d057.pl --navegador)" \
         --repo "$REPO" >/dev/null 2>&1
    [ "$CAMBIADAS_FUERA" -gt 0 ] && perl "$REF/receipt.pl" --anotar "CAMBIADAS sin medir por los dos topes: $CAMBIADAS_FUERA (URLS_CAMBIADAS_MAX=$URLS_CAMBIADAS_MAX, URLS_CAMBIADAS_CORTA_MAX=$URLS_CAMBIADAS_CORTA_MAX)" \
         --repo "$REPO" >/dev/null 2>&1
    [ -n "$NAVC_NOTA" ] && perl "$REF/receipt.pl" --anotar "$NAVC_NOTA" --repo "$REPO" >/dev/null 2>&1 \
      && echo "  (anotado en el historial)"
  fi
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
# D-057 · un sin mirar viejo (igual en produccion, con fila con fecha) no es un hueco
# de esta subida, y MED-13 en una web sin GA4 ni Ads por decision no aplica. Los dos
# los dice d057.pl (corrido aqui si el paso 1 no lo corrio); se restan y se nombran.
D057_NV=""; D057_NA=""
if [ "$NV_REALES" != 0 ] && [ "$MEDIDO" = CANDIDATO ] && [ -f "$REF/d057.pl" ]; then
  [ -n "$D057_RC" ] || { echo; d057_corre; }
  D057_NV="$(d057_lista NV)"; D057_NA="$(d057_lista NO-APLICA)"
  NV_D057="$(printf '%s %s\n' "$D057_NV" "$D057_NA" | wc -w | tr -dc '0-9')"
  NV_REALES=$(( NV_REALES - ${NV_D057:-0} ))
  [ "$NV_REALES" -lt 0 ] && NV_REALES=0
fi
if [ "$NV" != 0 ]; then
  linea; echo "  2 · lo que nadie ha mirado"; linea
  echo "  $NV comprobaciones quedaron SIN VERIFICAR:"
  grep -m1 '^SIN-MIRAR:' "$REPO/.qa-recibo" | sed 's/^/    /'
  # 1-nov-2026 · A11Y-13 (teclado real y lector) tiene UNA parte que ya se mide: el
  #    menu movil, que mobile-menu-gate abre y cierra en el 1-quater. Se dice cual, y
  #    NO se resta del hueco: el orden de Tab de la pagina entera, el foco visible y
  #    el lector de pantalla siguen sin mirar, y el propio A11Y-13 dice que eso no lo
  #    sustituye ningun script. Restarlo seria un gate afirmando lo que no mide.
  if grep -m1 '^SIN-MIRAR:' "$REPO/.qa-recibo" | grep -qw 'A11Y-13' && [ "$NAVC_MENU_TOTAL" -gt 0 ]; then
    if [ "$NAVC_MENU_PASA" = "$NAVC_MENU_TOTAL" ]; then
      echo "  A11Y-13 · la parte del menu movil SI esta medida: mobile-menu-gate PASA en"
      echo "            $NAVC_MENU_PASA de $NAVC_MENU_TOTAL paginas a 390. Sigue sin mirar el resto: el orden de"
      echo "            Tab de la pagina entera, el foco visible y un lector de pantalla."
    else
      echo "  A11Y-13 · la parte del menu movil esta medida y es un NO: mobile-menu-gate"
      echo "            FALLA en $((NAVC_MENU_TOTAL - NAVC_MENU_PASA)) de $NAVC_MENU_TOTAL paginas (ver el 1-quater)."
    fi
  fi
  if [ "$NVC" != 0 ]; then
    echo
    echo "  De esas, $NVC NO son huecos: son las preguntas que solo produccion"
    echo "  contesta, y las contesta G11 en el paso 4."
    echo "    $NVC_LISTA"
    echo "  Quedan $NV_REALES sin mirar de verdad."
  fi
  if [ -n "$D057_NV$D057_NA" ]; then
    echo
    [ -n "$D057_NV" ] && echo "  D-057: $D057_NV ya estan igual sin mirar en produccion y tienen fila con fecha."
    [ -n "$D057_NA" ] && echo "  NO APLICA: $D057_NA (SIN_GA4_NI_ADS: $SIN_GA4_NI_ADS)."
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
      case " $NVC_LISTA $D057_NV $D057_NA " in *" $x "*) continue ;; esac
      # el historial guarda tambien la mitad medida de A11Y-13 (ver arriba)
      if [ "$x" = A11Y-13 ] && [ "$NAVC_MENU_TOTAL" -gt 0 ]; then
        x="A11Y-13(menu:$( [ "$NAVC_MENU_PASA" = "$NAVC_MENU_TOTAL" ] && echo PASA || echo FALLA)$NAVC_MENU_PASA/$NAVC_MENU_TOTAL)"
      fi
      HUECOS="$HUECOS $x"
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
# D-057 · lo que paso por viejo queda nombrado uno a uno en el historial, firmado
# «D-057» (no por el chat), y en _deploy/.d057-ultima.txt para la fila de 14 dias.
D057_NOTA=""
if [ -n "$D057_RC" ]; then
  D057_F="$(d057_lista FALLO)"
  [ -n "$D057_F" ]  && D057_NOTA="FALLO viejo: $D057_F"
  [ -n "$D057_NV" ] && D057_NOTA="${D057_NOTA:+$D057_NOTA; }sin mirar viejo: $D057_NV"
  [ -n "$D057_NA" ] && D057_NOTA="${D057_NOTA:+$D057_NOTA; }NO APLICA: $D057_NA"
  D057_Q="$(d057_lista QUITA)"
  [ -n "$D057_NOTA" ] && [ -n "$D057_Q" ] && D057_NOTA="$D057_NOTA; quita $D057_Q FALLO de produccion"
  if [ -n "$D057_NOTA" ] && [ "$SUBIR" = 1 ]; then
    perl "$REF/receipt.pl" --anotar "D-057 [$D057_NOTA] igual en produccion y con fila (gates/d057.pl)" --repo "$REPO" >/dev/null 2>&1 \
      && echo "  anotado en el historial: D-057 [$D057_NOTA]" \
      || echo "  NO he podido anotar D-057 en el historial: esta firma NO consta."
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
  # 🔴 27-oct-2026 · el aviso decia «se arregla antes de subir» y la puerta SUBIA.
  #    Paso en un sitio real con un estado escrito a mano fuera del vocabulario
  #    («cerrado 2026-10-22»). Un hueco abierto sigue sin bloquear; el fichero
  #    roto si, porque lo que no se puede leer no avisa a nadie.
  if [ "$HU_RC" = 1 ]; then
    echo
    echo "  🔴 El fichero de huecos esta mal formado. Se arregla antes de subir:"
    echo "     un hueco mal declarado no avisa a nadie y ensucia el recibo."
    if [ "$SUBIR" = 1 ]; then
      echo "  🔴 NO SUBO: el fichero de huecos esta mal formado. No se ha subido nada."
      exit 1
    fi
    echo "     (ensayo: con --subir NO se subiria hasta arreglarlo)"
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
#  El modo lo declara el repo (`MODO_SPEC=migracion|greenfield` en deploy.conf,
#  o `=ninguna` si el sitio no tiene spec a proposito). Sin declaracion no se
#  adivina: se dice que no se ha medido y por que.
#
#  🔴 28-sep-2026 · UN «NO HE PODIDO MEDIR» SALIA COMO «NO CUADRAN».
#  audit-vs-spec.pl sale con 0 (PASA), 1 (FALLA: comparo y no cuadra) o 2 (NO
#  MEDIDO: sin `_spec/`, sin repo, un modo que no conoce, o ni una comprobacion).
#  Este paso trataba cualquier distinto de 0 como descuadre, y su filtro se comia
#  el motivo: desplegando un sitio sin `_spec/` con MODO_SPEC=greenfield, la
#  puerta dijo «La spec y el arbol NO cuadran» sin una sola linea de detalle, y
#  no se habia comparado nada. El recibo lo anotaba bien («SPEC sin veredicto
#  (exit 2)»); lo que mentia era la consola. Ahora cada codigo dice lo suyo, el 2
#  con la primera linea del motivo tal cual, y el sitio que no tiene spec a
#  proposito lo declara (`MODO_SPEC=ninguna`) en vez de pedir cada vez una
#  comparacion que no se puede hacer. Sigue sin bloquear.
if [ ! -f "$REF/audit-vs-spec.pl" ]; then
  echo
  echo "  2-bis · spec contra arbol: no encuentro audit-vs-spec.pl. NO MEDIDO."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "SPEC no medida: falta el programa" --repo "$REPO" >/dev/null 2>&1
elif [ -z "${MODO_SPEC:-}" ]; then
  echo
  echo "  2-bis · spec contra arbol: $CONF no declara MODO_SPEC. NO MEDIDO."
  echo "          ponle MODO_SPEC=migracion (venia de una web), =greenfield (no la habia)"
  echo "          o =ninguna (este sitio no tiene spec, a proposito)."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "SPEC no medida: sin MODO_SPEC en deploy.conf" --repo "$REPO" >/dev/null 2>&1
elif [ "$MODO_SPEC" = ninguna ] || [ "$MODO_SPEC" = none ]; then
  echo
  echo "  2-bis · spec contra arbol: $CONF declara MODO_SPEC=$MODO_SPEC. NO MEDIDO, y a proposito:"
  echo "          el repo dice que este sitio no tiene spec contra la que comparar."
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "SPEC no medida: el repo declara que no tiene spec (MODO_SPEC=$MODO_SPEC)" --repo "$REPO" >/dev/null 2>&1
else
  linea; echo "  2-bis · la spec contra el arbol (modo $MODO_SPEC)"; linea
  SPEC_SALIDA="$(perl "$REF/audit-vs-spec.pl" --modo "$MODO_SPEC" --repo "$REPO" -q 2>&1)"
  SPEC_RC=$?
  if [ "$SPEC_RC" = 0 ] || [ "$SPEC_RC" = 1 ]; then
    printf '%s\n' "$SPEC_SALIDA" | grep -E 'FALLO|AVISO|NO VERIF|VEREDICTO|PASA [0-9]' | sed 's/^/  /'
  fi
  SPEC_VER="$(printf '%s\n' "$SPEC_SALIDA" | grep -m1 'VEREDICTO' | sed 's/.*VEREDICTO:[[:space:]]*//')"
  [ "$SUBIR" = 1 ] && perl "$REF/receipt.pl" --anotar "SPEC ${SPEC_VER:-sin veredicto} (exit $SPEC_RC)" --repo "$REPO" >/dev/null 2>&1
  case "$SPEC_RC" in
    0) ;;
    1)
      echo
      echo "  La spec y el arbol NO cuadran. Queda anotado y NO bloquea todavia"
      echo "  (ver el motivo con fecha arriba, en el comentario de este bloque)."
      echo "  Si lo de arriba es un falso positivo, se arregla EL GATE con su caso"
      echo "  rojo, no se calla: audit-vs-spec-tests/tests.pl."
      ;;
    2)
      # El motivo: si la corrida entera no midio nada, su linea «NADA MEDIDO»;
      # si no, la primera linea con texto (en los cortes tempranos va primero).
      SPEC_MOTIVO="$(printf '%s\n' "$SPEC_SALIDA" | grep -m1 'NADA MEDIDO')"
      [ -n "$SPEC_MOTIVO" ] || SPEC_MOTIVO="$(printf '%s\n' "$SPEC_SALIDA" | grep -m1 -v -E '^[[:space:]]*$|^[[:space:]]*(──|---)')"
      echo "  spec contra arbol: NO MEDIDO. audit-vs-spec no ha podido comparar (exit 2):"
      echo "  no es un aprobado y tampoco un descuadre. Lo que dice:"
      echo "    $(printf '%s' "$SPEC_MOTIVO" | sed 's/^[[:space:]]*//')"
      echo "  Si este sitio no tiene spec a proposito, declaralo en $CONF"
      echo "  con MODO_SPEC=ninguna: el hueco sigue constando, pero como decidido."
      ;;
    *)
      echo "  spec contra arbol: audit-vs-spec ha salido con $SPEC_RC, que no es PASA (0),"
      echo "  FALLA (1) ni NO MEDIDO (2). No se da por medido. Lo primero que dice:"
      printf '%s\n' "$SPEC_SALIDA" | grep -v '^[[:space:]]*$' | head -3 | sed 's/^/    /'
      ;;
  esac
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
#    NO BLOQUEABA, y por el mismo motivo que 2-bis: quitar una seccion a
#    proposito tambien sale como «perdida», y un gate que impide desplegar el
#    primer dia que da un falso positivo ensena a saltarse la puerta. Se ve, se
#    anota, se mira unas corridas, y entonces se sube el liston.
#
# 🔴 28-sep-2026 · SE SUBE EL LISTON, y lo decidieron las corridas. El
#    historial tenia 205 pasos 2-ter anotados desde el 26-ago: 58 con perdida
#    (28 %), 146 sin ella. Ese dia, en un sitio que suben varias sesiones, una
#    subida hecha desde una rama sacada ANTES de que otra sesion fusionara y
#    subiera lo suyo devolvio a su version anterior cuatro paginas de esa otra
#    sesion, su sitemap y su llms.txt. Este paso lo dijo («5 con perdida» donde
#    el cambio tocaba una pagina) y la puerta subio igual; G11 dio verde, porque
#    compara lo servido con el recibo, no con lo que habia antes.
#    Lo que sigue vigente del motivo de arriba: quitar texto a proposito es
#    legitimo, y en una de cada cuatro subidas pasa. Por eso NO es un muro: una
#    perdida PARA la subida (exit 1, sin subir nada) salvo que se declare con
#    --pierde-texto "motivo", como --aun-asi, y el historial se lleva las
#    paginas, cuantas palabras y el motivo. En ensayo sigue sin descargarse nada
#    y no para: la parada de --subir ocurre antes de la linea que sube, asi que
#    hace de ensayo de este paso.
if [ "$REDIR" = 1 ]; then
  # Retirar el dominio ES quitar todo su texto: a donde va cada pagina lo
  # mide redirects-gate.pl (cada ruta del mapa a su pagina, que contesta 200).
  no_aplica "2-ter · texto del cliente"
elif [ "$SUBIR" != 1 ]; then
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
    rm -rf "$ANT"
    printf '%s\n' "$TXT_SALIDA" | grep -E '^\s*MAL|conservan todas' | head -12 | sed 's/^/  /'
    echo "  ($BAJADAS paginas comparadas, $NUEVAS nuevas que no existian antes)"
    TXT_RES="$(printf '%s\n' "$TXT_SALIDA" | grep -o '[0-9]* con perdida' | tail -1)"
    # Las paginas que pierden y cuantas palabras, de TODAS las lineas MAL (la
    # vista de arriba se corta en 12): «es/index.html -26, learn/index.html -8».
    TXT_PAGS="$(printf '%s\n' "$TXT_SALIDA" \
      | sed -nE 's/^[[:space:]]*MAL[[:space:]]+([^[:space:]]+)[[:space:]]+FALTAN ([0-9]+).*/\1 -\2/p' \
      | paste -sd',' - | sed 's/,/, /g')"
    case "$TXT_RC" in
      0)
        perl "$REF/receipt.pl" \
             --anotar "TEXTO $BAJADAS comparadas · ${TXT_RES:-sin recuento} (exit $TXT_RC)" \
             --repo "$REPO" >/dev/null 2>&1
        ;;
      1)
        if [ -z "$PIERDE_TEXTO" ]; then
          echo
          echo "  🔴 NO SUBO: hay paginas que pierden palabras frente a lo que sirve"
          echo "     produccion, y nadie lo ha declarado. No se ha subido nada."
          echo "     Pierden: ${TXT_PAGS:-(no he podido leer cuales)}"
          echo
          echo "     · Si lo has quitado tu, a proposito: repite con"
          echo "           --pierde-texto \"el motivo\""
          echo "       y queda en el historial con las paginas y el motivo al lado."
          echo "     · Si pierde palabras una pagina que tu cambio NO toca, casi siempre"
          echo "       es otra sesion que subio DESPUES de tu base, y esta subida se la"
          echo "       devolveria a la version de antes. Antes de nada: git fetch, y el"
          echo "       ultimo SERVIDO del historial contra el hash de tu base:"
          echo "           perl \"$REF/receipt.pl\" --historial --sitio ${SITIO:-<url>}"
          echo "           perl \"$REF/receipt.pl\" --arbol --repo <arbol de tu base>"
          echo "       Si no coinciden, rehaz el cambio sobre lo nuevo y vuelve a medir."
          exit 1
        fi
        echo
        echo "  se sube igualmente, declarado. Motivo: $PIERDE_TEXTO"
        perl "$REF/receipt.pl" \
             --anotar "TEXTO $BAJADAS comparadas · ${TXT_RES:-sin recuento} (exit $TXT_RC)" \
             --repo "$REPO" >/dev/null 2>&1
        if perl "$REF/receipt.pl" --anotar "PIERDE-TEXTO [${TXT_PAGS:-sin detalle}] $PIERDE_TEXTO" \
                --repo "$REPO" >/dev/null 2>&1; then
          echo "  anotado en el historial: ${TXT_RES:-la perdida}, con las paginas y el motivo."
        else
          echo "  NO he podido anotarlo en el historial. Esta declaracion NO consta."
        fi
        ;;
      *)
        # Un comparador que revienta no ha medido nada: ni aprueba ni acusa.
        echo "  same-text.pl ha salido con $TXT_RC: no ha podido comparar. NO MEDIDO, y no para."
        printf '%s\n' "$TXT_SALIDA" | grep -v '^[[:space:]]*$' | head -3 | sed 's/^/    /'
        perl "$REF/receipt.pl" --anotar "TEXTO no medido: same-text.pl salio con $TXT_RC" \
             --repo "$REPO" >/dev/null 2>&1
        ;;
    esac
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
if [ "$REDIR" = 1 ]; then
  no_aplica "2-quater · auditor de sitio"
elif [ ! -f "$REF/audit.sh" ]; then
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
if [ "$REDIR" = 1 ]; then
  no_aplica "2-quinquies · citabilidad"
elif [ ! -f "$REF/citable.pl" ]; then
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
trap 'rm -f "$LISTA_HOY" "$RETIRADAS"; declare -F en_curso_fin >/dev/null && en_curso_fin' EXIT
perl "$REF/receipt.pl" --arbol --listar --repo "$REPO" 2>/dev/null \
  | sed -nE 's/^[0-9a-f]+[[:space:]]+[0-9]+[[:space:]]+//p' \
  | LC_ALL=C sort > "$LISTA_HOY"
: > "$RETIRADAS"
if [ -s "$LISTA_ANT" ] && [ -s "$LISTA_HOY" ]; then
  LC_ALL=C sort "$LISTA_ANT" > "$LISTA_ANT.orden.tmp"
  LC_ALL=C comm -23 "$LISTA_ANT.orden.tmp" "$LISTA_HOY" > "$RETIRADAS"
  rm -f "$LISTA_ANT.orden.tmp"
fi

# >>> cerrojo-de-subida (marca del banco deploy-tests: no la muevas sin moverlo)
# ── 3-ter-0 · ¿LO HA SUBIDO OTRA SESION HACE NADA? (5-nov-2026) ──────────────
#    Dos sesiones con permiso para la misma subida la hicieron dos veces: una web
#    subio dos veces con 11 s de diferencia (19-oct). Nada lo paraba: cada una
#    tenia su recibo valido. Ahora, al llegar aqui, se mira la ultima subida de
#    este SITIO en esta maquina. Si fue hace menos de 15 min y desde OTRA sesion,
#    no se sube sin `--otra-vez "motivo"`, que queda anotado. La misma sesion si
#    puede repetir (arreglar algo y volver a subir es lo normal).
#    La sesion es CLAUDE_CODE_SESSION_ID; sin ella (una persona en su terminal),
#    usuario@maquina. El cerrojo se escribe ANTES de subir: quien llegue detras ya
#    lo ve. ⚠️ LIMITE, declarado: solo ve las subidas de esta maquina (el
#    directorio central, ~/.qa-receipts/subidas/, o QA_RECIBOS_DIR).
CERROJO_DIR="${QA_RECIBOS_DIR:-${HOME:-${USERPROFILE:-.}}/.qa-receipts}/subidas"
CERROJO_MIN="${CERROJO_MIN:-15}"
cerrojo_sesion() { printf '%s\n' "${CLAUDE_CODE_SESSION_ID:-${USER:-${USERNAME:-alguien}}@$(hostname 2>/dev/null || echo maquina)}"; }
cerrojo_fichero() { printf '%s/%s\n' "$CERROJO_DIR" "$(printf '%s' "$SITIO" | sed -E 's#^[a-z]+://##; s#[/:]+$##; s#[^A-Za-z0-9._-]#_#g')"; }
cerrojo_decide() {  # $1 = ahora (epoch) · usa SITIO, REPO, OTRA_VEZ · 1 = no se sube · deja CERROJO_NOTA
  local f ant ses rep edad min yo
  CERROJO_NOTA=""
  f="$(cerrojo_fichero)"; yo="$(cerrojo_sesion)"
  [ -s "$f" ] || return 0
  IFS="$(printf '\t')" read -r ant ses rep < "$f"
  case "$ant" in ''|*[!0-9]*) return 0 ;; esac
  edad=$(( $1 - ant )); min=$(( (edad + 59) / 60 ))
  [ "$edad" -lt $((CERROJO_MIN * 60)) ] || return 0
  [ "$ses" = "$yo" ] && { echo "  (esta misma sesion subio $SITIO hace $min min: se repite)"; return 0; }
  if [ -n "${OTRA_VEZ:-}" ]; then
    echo "  ⚠ $SITIO se subio hace $min min desde otra sesion (${ses:0:13}…, $rep)."
    echo "    Se vuelve a subir a sabiendas: $OTRA_VEZ"
    CERROJO_NOTA="SUBIDA REPETIDA a los $min min de otra sesion: $OTRA_VEZ"
    return 0
  fi
  echo "  🔴 $SITIO SE SUBIO HACE $min MIN DESDE OTRA SESION: no se sube otra vez."
  echo "     Esa subida: sesion ${ses:0:13}…, repo $rep."
  echo "     Dos sesiones con la misma subida la hacen dos veces (19-oct, 11 s de diferencia)."
  echo "     Si es a proposito -la otra se paro, o hace falta repetir-:"
  echo "         --otra-vez \"el motivo\""
  return 1
}
cerrojo_escribe() {  # $1 = ahora (epoch)
  mkdir -p "$CERROJO_DIR" 2>/dev/null
  printf '%s\t%s\t%s\n' "$1" "$(cerrojo_sesion)" "$REPO" > "$(cerrojo_fichero)" 2>/dev/null
}
# <<< cerrojo-de-subida
AHORA_SUBE="$(date +%s)"
if ! cerrojo_decide "$AHORA_SUBE"; then
  perl "$REF/receipt.pl" --anotar "subida parada: $SITIO subido hace menos de $CERROJO_MIN min desde otra sesion" --repo "$REPO" >/dev/null 2>&1
  exit 1
fi
[ -n "$CERROJO_NOTA" ] && perl "$REF/receipt.pl" --anotar "$CERROJO_NOTA" --repo "$REPO" >/dev/null 2>&1

# >>> sello-antes-de-subir (marca del banco deploy-tests: no la muevas sin moverlo)
# ── 3-ter · ¿ES ESTE EL ARBOL DEL RECIBO? (1-nov-2026) ───────────────────────
#    El recibo se comprueba en el paso 1 y el subidor empaqueta el arbol de AHORA,
#    minutos despues (tras el auditor y el navegador). Medido el 31-oct en una web:
#    se regenero el CSS en medio, subio un arbol que ningun recibo habia sellado, y
#    G11 lo cazo con 27 ficheros DISTINTO... ya servidos. Se vuelve a comparar el
#    arbol y los receptores con el sello justo antes de subir; si no cuadra, no sube.
#    ⚠️ LIMITE, declarado: el subidor es de cada repo y empaqueta el disco. Entre
#    esta comprobacion y su `tar` quedan segundos, no minutos: durante una subida,
#    el repo no se toca.
# 🔴 5-nov-2026 · Y EL RECIBO ENTERO, NO SOLO EL ARBOL. Medido esa noche en una web:
#    la puerta leyo a las 22:08 un recibo verde; a las 22:17, a media puerta, un
#    qa-master sobre OTRO commit reescribio el recibo, en FALLA; aqui solo se
#    comparo el arbol con ese recibo nuevo (cuadraba: era su arbol) y subio un arbol
#    en rojo que el revisor habia devuelto. Ahora, antes de subir: (1) el recibo
#    tiene que ser el MISMO que dejo pasar el paso 1 (su SELLO), y (2) se vuelve a
#    verificar entero, como en el paso 1: veredicto, edad, arbol y sello.
RECIBO_SELLO_AHORA="$(grep -m1 '^SELLO:' "$REPO/.qa-recibo" 2>/dev/null | tr -d '\r')"
if [ -n "${RECIBO_SELLO_1:-}" ] && [ "$RECIBO_SELLO_AHORA" != "$RECIBO_SELLO_1" ]; then
  echo "  🔴 EL RECIBO YA NO ES EL QUE DEJO PASAR EL PASO 1: alguien volvio a medir durante"
  echo "     la puerta y lo reescribio. NO se sube: el veredicto que vale es el de un recibo"
  echo "     que esta puerta no ha leido."
  echo "     $(grep -m1 '^VEREDICTO:' "$REPO/.qa-recibo" 2>/dev/null | tr -d '\r') · $(grep -m1 '^FECHA:' "$REPO/.qa-recibo" 2>/dev/null | tr -d '\r')"
  echo "     Una puerta y un qa-master a la vez sobre el mismo repo no: que acabe uno, y se repite."
  perl "$REF/receipt.pl" --anotar "subida parada: el recibo cambio a media puerta" --repo "$REPO" >/dev/null 2>&1
  exit 1
fi
#    Con D-057 (paso 1-D057) el veredicto ya lo decidio d057.pl: todo lo demas, igual.
if ! SELLO_SAL="$(perl "$REF/receipt.pl" --verificar --repo "$REPO" --para-desplegar --horas "${HORAS:-12}" ${RECIBO_SALVO:-} 2>&1)"; then
  echo "  🔴 el recibo, vuelto a verificar justo antes de subir, ya no deja subir: NO se sube."
  printf '%s\n' "$SELLO_SAL" | grep -E 'CAMBIADO|recibo:|NUEVO|RETIRADO|SELLO|DISTINTO|ahora|VEREDICTO|FALLA|CADUC|caduc' | head -8 | sed 's/^ */     /'
  echo "     O algo toco el repo durante la puerta, o el recibo ya no vale. Vuelve a medir"
  echo "     el candidato y repite, sin tocar el repo mientras sube."
  perl "$REF/receipt.pl" --anotar "subida parada: el recibo ya no deja subir al volver a verificarlo" --repo "$REPO" >/dev/null 2>&1
  exit 1
fi
echo "  el recibo sigue siendo el del paso 1 y el arbol el suyo (comprobado justo antes de subir)"
# ¿se la ha mandado parar, o la orden que la lanzo ya no existe? (0-ter). SUBIENDO
# se escribe ANTES de mirar: asi un --parar que llegue a la vez ve uno u otro.
declare -F en_curso_escribe >/dev/null && en_curso_escribe SUBIENDO
if declare -F puerta_sigue >/dev/null && ! puerta_sigue; then
  en_curso_escribe "PARADA antes de subir"
  perl "$REF/receipt.pl" --anotar "subida parada: $PUERTA_PARADA" --repo "$REPO" >/dev/null 2>&1
  exit 1
fi
echo "  $CMD"
# el cerrojo, justo antes del subidor (y no antes del sello: un sello que para no ha subido nada)
declare -F cerrojo_escribe >/dev/null && cerrojo_escribe "${AHORA_SUBE:-$(date +%s)}"
eval "$CMD"
RC=$?
declare -F en_curso_escribe >/dev/null && en_curso_escribe "SUBIDO rc=$RC"
# <<< sello-antes-de-subir
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
G11_NOHAY="${TEMP:-/tmp}/g11-nohay-$$.tsv"; rm -f "$G11_NOHAY"
G11_NO_HALLADOS="$G11_NOHAY" perl "$REF/receipt.pl" --servido --repo "$REPO" --sitio "$SITIO" | tee "$G11_LOG"
G11=${PIPESTATUS[0]}
if [ "$G11" != 0 ]; then
  echo
  echo "  🔴 HAS SUBIDO Y PRODUCCION NO SIRVE ESO."
  echo "     Causas ya vistas: cache (Cache-Control 86400 en css/js sin versionar),"
  echo "     ruta remota equivocada, o SUBIDA que solo sube parte del arbol."
  echo "     Y si lo que falla es la 404 del host (EST-03), el arbol esta bien subido:"
  echo "     lo que no sirve el 404.html es la configuracion del host (su .htaccess)."
  echo "     No lo des por hecho hasta que esto salga en verde."
  rm -f "$G11_LOG" "$G11_NOHAY"
  exit 1
fi
# >>> altas-servidas (marca del banco deploy-tests: no la muevas sin moverlo)
# ── 4-0 · LAS PAGINAS QUE ESTA SUBIDA DA DE ALTA O CAMBIA, ¿SE SIRVEN? ───────
#    5-nov-2026 · Una subida cerro «El despliegue esta hecho y G11 lo ha
#    verificado» con G11 diciendo «no hallados 2 (ausentes 2), 404 x2»: eran justo
#    sus dos paginas NUEVAS. G11 sale 0 con no hallados (INCOMPLETO: puede ser su
#    mapeo ruta->URL), y en una web entera eso es prudente. En una pagina que ESTA
#    subida da de alta o cambia no lo es: es lo que se venia a publicar.
#    Se cruza la lista entera de G11 (G11_NO_HALLADOS) con CAMBIADAS_TODAS (todas,
#    sin el tope del navegador). Un 404 o un 410, o cualquier codigo que no sea de
#    «me lo han negado», en una de ellas: FALLA, y no se guarda la lista de esta
#    subida (la proxima la vuelve a mirar como alta). Negado (0, 401, 403, 407, 408,
#    429, 5xx) o pasado el tope de G11 («-»): NO MEDIDO, y el cierre lo dice. Sin
#    la lista de G11: NO MEDIDO.
altas_juzga() {  # $1 = fichero de G11 · usa CAMBIADAS_TODAS · deja ALTAS_FALLA y ALTAS_NM · 1 = FALLA
  local rel cod c
  ALTAS_FALLA=""; ALTAS_NM=""
  [ -n "${CAMBIADAS_TODAS:-}" ] || return 0
  if [ ! -f "$1" ]; then ALTAS_NM="G11 no dio su lista de no hallados"; return 0; fi
  while IFS="$(printf '\t')" read -r rel cod; do
    [ -n "$rel" ] || continue
    for c in $CAMBIADAS_TODAS; do
      [ "$c" = "$rel" ] || continue
      case "$cod" in
        -) ALTAS_NM="${ALTAS_NM:+$ALTAS_NM, }$rel (pasado el tope de G11)" ;;
        0|000|401|403|407|408|429|5[0-9][0-9]) ALTAS_NM="${ALTAS_NM:+$ALTAS_NM, }$rel ($cod)" ;;
        *) ALTAS_FALLA="${ALTAS_FALLA:+$ALTAS_FALLA, }$rel ($cod)" ;;
      esac
    done
  done < "$1"
  [ -z "$ALTAS_FALLA" ]
}
# <<< altas-servidas
if ! altas_juzga "$G11_NOHAY"; then
  echo
  echo "  🔴 FALLA · SUBIDO, PERO PRODUCCION NO SIRVE LO QUE ESTA SUBIDA PUBLICA."
  echo "     Paginas que da de alta o cambia y G11 no encuentra: $ALTAS_FALLA"
  echo "     Causas ya vistas: la ruta publica de la pagina no esta en el mapa del"
  echo "     subidor (una lista escrita a mano), o el host la reescribe a otra parte."
  echo "     No se guarda la lista de esta subida: la proxima las vuelve a medir."
  perl "$REF/receipt.pl" --anotar "CIERRE FALLA: paginas de la subida no servidas: $ALTAS_FALLA" --repo "$REPO" >/dev/null 2>&1
  rm -f "$G11_LOG" "$G11_NOHAY"
  exit 1
fi
rm -f "$G11_NOHAY"
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
  # Y sus huellas: con ellas, la proxima subida sabe que paginas cambia (1-nov-2026).
  { echo "$HUELLAS_VERSION"; arbol_huellas; } > "$HUELLAS_ANT.tmp" 2>/dev/null && [ "$(grep -c . "$HUELLAS_ANT.tmp")" -gt 1 ] \
    && mv -f "$HUELLAS_ANT.tmp" "$HUELLAS_ANT" || rm -f "$HUELLAS_ANT.tmp"
fi

echo
# 5-nov-2026 · aqui ponia «PASA · desplegado y verificado contra el recibo», y lo
#   decia tambien con paginas de la subida en 404. Es lo que dice G11, y se dice
#   asi; el veredicto de la subida es el CIERRE, al final, tras enlazado y navegador.
echo "  G11 · PASA: lo del recibo se sirve${CAMBIADAS_TODAS:+, y tambien cada pagina que esta subida da de alta o cambia}."
echo "  (el veredicto de la subida es el CIERRE, al final)"
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

# ── 4-ter · ARBOL DE REDIRECCIONES: ¿EL DOMINIO REDIRIGE LO QUE DICE? ────────
#    G11 compara lo servido con el recibo, y aqui el recibo es un robots.txt: lo
#    que importa —que /wp-login.php y cada ruta del mapa contesten 301 al sitio
#    que dice el .htaccess— solo lo contesta pedirlo al dominio. Bloquea igual
#    que G11: subido y redirigiendo mal no esta hecho.
if [ "$REDIR" = 1 ]; then
  linea; echo "  4-ter · las redirecciones, pedidas al dominio"; linea
  perl "$REF/redirects-gate.pl" --repo "$REPO" --sitio "$SITIO" --servido
  RED_RC=$?
  perl "$REF/receipt.pl" --anotar "REDIRECCIONES servidas (exit $RED_RC)" --repo "$REPO" >/dev/null 2>&1
  if [ "$RED_RC" != 0 ]; then
    echo
    echo "  🔴 HAS SUBIDO Y EL DOMINIO NO REDIRIGE COMO DICE EL .htaccess."
    echo "     Si una ruta de WordPress contesta 200, el servidor no esta leyendo"
    echo "     ese .htaccess (otro docroot, cache del host) o algo lo pisa."
    echo "     No lo des por hecho hasta que esto salga en verde."
    exit 1
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
if [ "$REDIR" = 1 ]; then
  no_aplica "5 · enlazado"
elif [ "${SIN_ENLAZADO:-0}" = 1 ]; then
  echo
  echo "  5 · enlazado: $CONF declara SIN_ENLAZADO=1, no se mide."
  ENL_NM="enlazado (SIN_ENLAZADO=1)"
  perl "$REF/receipt.pl" --anotar "ENLAZADO no medido: SIN_ENLAZADO=1 en deploy.conf" \
       --repo "$REPO" >/dev/null 2>&1
elif [ ! -f "$REF/crawl-links.pl" ] || [ ! -f "$REF/linking-gate.pl" ]; then
  echo
  echo "  5 · enlazado: no encuentro crawl-links.pl o linking-gate.pl. NO MEDIDO."
  ENL_NM="enlazado (falta el programa)"
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
      echo "  Subido, y G11 da servidos los ficheros del recibo."
      echo "  Lo que falla es el ENLAZADO de lo servido, y queda anotado. No se"
      echo "  deshace nada por esto, pero tampoco se puede decir que salio limpio."
    fi
  else
    echo "  no he podido rastrear $SITIO. El enlazado queda NO MEDIDO."
    ENL_NM="enlazado (el rastreo fallo)"
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
# 🔴 1-nov-2026 · LO QUE BLOQUEA ESTA EN EL 1-quater. Este paso era el UNICO sitio
#    donde corrian estos gates, y por eso un rojo de navegador nunca paro una
#    subida: una web nueva subio con 10 FALLA. Ahora los mismos gates miden el
#    CANDIDATO antes de subir, y para. Este paso se queda para lo que el arbol no
#    puede contestar: lo que sirve el host de verdad (CDN, cache, cabeceras, el
#    formulario contra su backend). Las claves y las funciones de medir son las
#    del 1-quater (nav_empuja, nav_mide, nav_lee, nav_corre): una sola copia.
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
#    (1-nov-2026: la lectura de las claves y del host se subio al 1-quater.)
if [ "$REDIR" = 1 ]; then
  no_aplica "6 · navegador"
elif [ "${SIN_NAVEGADOR:-0}" != 1 ] && [ -z "${NAV_HOST:-}" ]; then
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
  linea; echo "  6 · maqueta, densidad, movil y formularios de lo servido"; linea
  nav_empuja || echo "  (no he podido empujar todos los gates a $NAV_HOST: lo que falle saldra NO MEDIDO)"

  # Que URLs. Por defecto la portada; el repo puede declarar mas. Las de
  # formulario van aparte porque ahi el paso 10 se EXIGE: si esa pagina se queda
  # sin formulario es un FALLO, no un «no aplica».
  URLS_NAV="$(urls_navegador)"   # las declaradas y las que cambio esta subida (calculadas antes de subir)
  URLS_FORM="${URLS_FORMULARIO:-}"
  NAV_FALLOS=0; NAV_MIRADAS=0; NAV_BASURA=0; NAV_NM_CAMB=""
  NAV_DIR="$(mktemp -d -t navserv-XXXXXXXX)"; : > "$NAV_DIR/lista"; n=0
  for r in $URLS_NAV; do
    # 🔴 20-ago-2026 · EL GATE DE MOVIL. Se cableo aqui el mismo dia que se
    # escribio, y no despues: un gate fuera de la cadena no guarda nada. Lo que
    # caza no lo ve ningun otro: si el visitante puede ACTUAR desde el telefono
    # (accion sobre el pliegue, y sin nada encima). Mismo ancho que la densidad,
    # a proposito: los dos hablan del mismo movil y se leen juntos.
    # ⚠️ Mide la PRIMERA VISITA. El escenario "ya acepto cookies" exige pulsar
    # el banner, y esta puerta no toma decisiones de consentimiento por nadie;
    # el informe del gate lo declara en cada corrida.
    for m in "structure-gate.js 1298 720 c" "measure-screens.js 1298 720 -" \
             "measure-screens.js 390 844 -" "mobile-gate.js 390 844 c"; do
      n=$((n+1)); printf '%s %s %s\n' "$n" "$r" "$m" >> "$NAV_DIR/lista"
    done
  done
  nav_corre "$NAV_DIR" "$NAV_DIR/lista"
  NAV_N=$n   # el while de abajo deja n vacio: los formularios siguen la cuenta desde aqui
  NAV_CORRIO=1
  while read -r n r g w h c; do
    nav_lee "$NAV_DIR/$n.out" "$g" "$r" "$w"
    case "$NAV_R" in
      PASA)  NAV_MIRADAS=$((NAV_MIRADAS+1)) ;;
      FALLA) NAV_MIRADAS=$((NAV_MIRADAS+1)); NAV_FALLOS=$((NAV_FALLOS+1)) ;;
      *)     NAV_BASURA=$((NAV_BASURA+1))
             # una pagina de ESTA subida sin medir la nombra el cierre (5-nov-2026)
             case " $URLS_CAMBIADAS " in *" $r "*) case " $NAV_NM_CAMB " in *" $r "*) ;; *) NAV_NM_CAMB="${NAV_NM_CAMB:+$NAV_NM_CAMB }$r" ;; esac ;; esac ;;
    esac
  done < "$NAV_DIR/lista"
  # Los formularios, en serie y con su propia configuracion: forms-gate exige el
  # formulario en estas paginas, que es otra pregunta que «que cuenta como convertir».
  for r in $URLS_FORM; do
    for w in "1298 720" "390 844"; do
      NAV_N=$((NAV_N+1))
      nav_mide "$NAV_DIR/$NAV_N.out" "${SITIO%/}$r" forms-gate.js ${w% *} ${w#* } '{"exigeFormulario":true}'
      nav_lee "$NAV_DIR/$NAV_N.out" forms-gate.js "$r" "${w% *}"
      case "$NAV_R" in
        PASA)  NAV_MIRADAS=$((NAV_MIRADAS+1)) ;;
        FALLA) NAV_MIRADAS=$((NAV_MIRADAS+1)); NAV_FALLOS=$((NAV_FALLOS+1)) ;;
        *)     NAV_BASURA=$((NAV_BASURA+1)) ;;
      esac
    done
  done
  rm -rf "$NAV_DIR"

  # Un formulario no medido NO es un formulario correcto. Si el repo no declara
  # donde estan, se dice -- callarlo dejaria el paso 10 en el mismo sitio del
  # que viene: una promesa.
  if [ -z "$URLS_FORM" ]; then
    echo "    (el repo no declara URLS_FORMULARIO: el paso 10 NO se ha medido)"
    perl "$REF/receipt.pl" --anotar "PASO 10 no medido: deploy.conf no declara URLS_FORMULARIO" \
         --repo "$REPO" >/dev/null 2>&1
  fi
  perl "$REF/receipt.pl" \
       --anotar "NAVEGADOR $NAV_MIRADAS medidas · $NAV_FALLOS FALLA · $NAV_BASURA sin medir" \
       --repo "$REPO" >/dev/null 2>&1
  if [ "$NAV_FALLOS" != 0 ]; then
    echo
    echo "  Subido, y G11 da servidos los ficheros del recibo."
    echo "  Lo que falla es lo que solo se ve con un navegador EN LO SERVIDO, y queda"
    echo "  anotado. Si el 1-quater dio verde sobre el candidato, la diferencia la pone"
    echo "  el host (cache, CDN, cabeceras) o un formulario: se mira alli, no en el arbol."
  fi
fi

# ── 6-bis · LO QUE EL SERVIDOR CONTESTA A LOS BOTS DE IA (6-nov-2026) ─────────
#    2-sexies mira el robots.txt del ARBOL. No ve el CDN: ese dia daba 429 sin
#    Retry-After a la firma de GPTBot en 7 de 10 webs con robots.txt abierto, y
#    2-sexies salia PASA en las 7. ai-crawlers.pl --probe pide robots.txt y la
#    portada de lo servido con la firma de cada bot. Solo AVISA y se anota: es la
#    firma desde esta IP, no la del bot, y lo subido, subido esta.
if [ "${REDIR:-0}" != 1 ] && [ -f "$REF/ai-crawlers.pl" ] && command -v curl >/dev/null 2>&1; then
  SONDA_IA="$(perl "$REF/ai-crawlers.pl" --url "${SITIO%/}/" --probe --quiet 2>&1 | grep '^SONDA: ' | head -1)"
  echo
  echo "  6-bis · bots de IA en lo servido (ai-crawlers.pl --probe)"
  echo "    ${SONDA_IA:-SONDA: NO MEDIDO - ai-crawlers.pl no dio su linea}"
  perl "$REF/receipt.pl" --anotar "${SONDA_IA:-SONDA: NO MEDIDO}" --repo "$REPO" >/dev/null 2>&1
fi

# ── 6-ter · LO QUE LA WEB PIDE MEDIR TRAS SUBIR (TRAS_SUBIR, 6-nov-2026) ──────
#    Hay medidas que solo valen sobre lo servido y que esta puerta no puede traer
#    sola. La que lo pidio: las URLs con impresiones en Search Console que se
#    quedan sin 301. Antes de subir no se puede saber: produccion aun da 200 a
#    todas, y una URL que el candidato deja caer sin 301 se ve igual que una que
#    lleva el suyo. La web la declara en deploy.conf, `TRAS_SUBIR="<orden>"`
#    (`AFTER_UPLOAD` en ingles), y la puerta la corre aqui, desde el repo, despues
#    de G11 y del navegador. Solo AVISA, como el 6-bis: lo subido, subido esta.
#    exit 0 es PASA; 1, AVISO con sus lineas; cualquier otro (o 10 min sin
#    acabar), NO MEDIDO. Va al cierre y al historial.
TRAS_SUBIR="${TRAS_SUBIR:-${AFTER_UPLOAD:-}}"
TRAS_NOTA=""
if [ -n "$TRAS_SUBIR" ] && [ "${REDIR:-0}" != 1 ]; then
  echo
  echo "  6-ter · lo que $CONF pide medir tras subir: $TRAS_SUBIR"
  TRAS_OUT="$( cd "$REPO" && timeout 600 bash -c "$TRAS_SUBIR" 2>&1 )"; TRAS_RC=$?
  TRAS_CAB="$(printf '%s\n' "$TRAS_OUT" | grep -m1 . | cut -c1-200)"
  TRAS_MAL="$(printf '%s\n' "$TRAS_OUT" | grep -E '(^|[[:space:]])(FALLA|FALLO|FAIL|AVISO|WARN|NO MEDIDO|NOT MEASURED)([[:space:]]|$|:)')"
  N_TRAS_MAL="$(printf '%s' "$TRAS_MAL" | grep -c .)"
  case "$TRAS_RC" in
    0)
      echo "    PASA · ${TRAS_CAB:-(sin salida)}"
      perl "$REF/receipt.pl" --anotar "TRAS_SUBIR PASA: $TRAS_SUBIR" --repo "$REPO" >/dev/null 2>&1
      ;;
    1)
      echo "    ⚠ AVISO · ${TRAS_CAB:-(sin salida)}"
      printf '%s\n' "$TRAS_MAL" | head -10 | cut -c1-200 | sed 's/^[[:space:]]*/      /'
      [ "${N_TRAS_MAL:-0}" -gt 10 ] && echo "      … y $((N_TRAS_MAL - 10)) mas"
      echo "    Lo subido, subido esta: esto no para nada. Se arregla en la siguiente subida."
      TRAS_NOTA="tras subir, $TRAS_SUBIR avisa (${N_TRAS_MAL:-0} linea(s))"
      perl "$REF/receipt.pl" --anotar "TRAS_SUBIR AVISO: $TRAS_SUBIR · $(printf '%s\n' "$TRAS_MAL" | grep -m1 . | sed 's/^[[:space:]]*//' | cut -c1-160)" \
           --repo "$REPO" >/dev/null 2>&1
      ;;
    *)
      echo "    NO MEDIDO · la orden salio con $TRAS_RC$([ "$TRAS_RC" = 124 ] && echo ' (10 min sin acabar)') · ${TRAS_CAB:-(sin salida)}"
      #  Una ruta de Windows con \ llega rota: bash -c se come las barras (lo vio el
      #  banco el 6-nov: C:\Users\... se quedo en C:Users...). Se dice el porque.
      case "$TRAS_SUBIR" in *\\*)
        echo "    La orden lleva barras invertidas (\\) y bash se las come al correrla: las rutas, con / (C:/Users/...)." ;;
      esac
      TRAS_NOTA="tras subir, $TRAS_SUBIR sin medir (exit $TRAS_RC)"
      perl "$REF/receipt.pl" --anotar "TRAS_SUBIR NO MEDIDO (exit $TRAS_RC): $TRAS_SUBIR" --repo "$REPO" >/dev/null 2>&1
      ;;
  esac
fi

# >>> cierre-de-la-subida (marca del banco deploy-tests: no la muevas sin moverlo)
# ── EL CIERRE · una linea, y dice lo que se midio (5-nov-2026) ───────────────
#    Antes se cerraba con «El despliegue esta hecho y G11 lo ha verificado» aunque
#    el navegador hubiera dejado en NO MEDIDO las paginas nuevas («no parece la
#    pagina»). Ahora el cierre es UNO, al final, y sale de lo que paso:
#      FALLA      el enlazado o el navegador de lo servido en rojo
#      NO MEDIDO  el navegador no midio lo servido, o dejo sin medir una pagina
#                 que esta subida da de alta o cambia, o G11 no pudo mirarla
#      PASA       todo lo de arriba medido y en verde
#    No cambia el codigo de salida (lo subido, subido esta: 0); lo que cambia es
#    que nada que no se haya medido sale escrito como verificado.
cierre_dice() {  # usa ENL_RC, ENL_NM, NAV_FALLOS, NAV_CORRIO, NAV_BASURA, NAV_NM_CAMB, URLS_FORM, ALTAS_NM, REDIR, SIN_NAVEGADOR, CAMBIADAS_FUERA · deja CIERRE
  local fallos="" nm=""
  [ -n "${ENL_RC:-}" ] && [ "$ENL_RC" != 0 ] && fallos="el enlazado de lo servido"
  [ "${NAV_FALLOS:-0}" != 0 ] && fallos="${fallos:+$fallos y }$NAV_FALLOS medida(s) de navegador sobre lo servido"
  if [ "${REDIR:-0}" != 1 ]; then
    [ -n "${ENL_NM:-}" ] && nm="$ENL_NM"
    if [ "${SIN_NAVEGADOR:-0}" = 1 ]; then nm="${nm:+$nm; }navegador sobre lo servido (SIN_NAVEGADOR=1)"
    elif [ "${NAV_CORRIO:-0}" != 1 ]; then nm="${nm:+$nm; }navegador sobre lo servido (no corrio)"
    elif [ "${NAV_BASURA:-0}" != 0 ]; then
      nm="${nm:+$nm; }$NAV_BASURA medida(s) de navegador sin respuesta${NAV_NM_CAMB:+, entre ellas paginas de esta subida: $NAV_NM_CAMB}"
    fi
    [ "${CAMBIADAS_FUERA:-0}" -gt 0 ] 2>/dev/null && nm="${nm:+$nm; }$CAMBIADAS_FUERA pagina(s) cambiada(s) fuera del tope del navegador"
  fi
  [ -n "${ALTAS_NM:-}" ] && nm="${nm:+$nm; }G11 no pudo mirar: $ALTAS_NM"
  if [ -n "$fallos" ]; then CIERRE="FALLA · subido, pero en rojo: $fallos${nm:+ · y sin medir: $nm}"
  elif [ -n "$nm" ]; then CIERRE="NO MEDIDO · subido y servido segun G11, pero sin medir: $nm"
  elif [ "${REDIR:-0}" = 1 ]; then CIERRE="PASA · subido y servido segun G11 (arbol de redirecciones: enlazado y navegador no aplican)"
  else
    # una web sin URLS_FORMULARIO puede no tener formulario: no se juzga, pero se dice
    CIERRE="PASA · subido, servido segun G11 y medido en lo servido"
    [ -z "${URLS_FORM:-}" ] && CIERRE="$CIERRE (formularios: el repo no declara ninguno)"
  fi
}
# <<< cierre-de-la-subida
cierre_dice
# D-057: lo que subio por viejo va en el cierre, para que la fila de 14 dias lo diga
[ -n "${D057_NOTA:-}" ] && CIERRE="$CIERRE · D-057: $D057_NOTA"
# y lo del navegador que subio por viejo: el paso 6 lo vuelve a ver en rojo en lo servido
[ -n "${NAVC_D057:-}" ] && CIERRE="$CIERRE · D-057 en el navegador (viejas, con fila): $NAVC_D057"
# y lo que la web pidio medir tras subir, si no paso (6-ter): no cambia el veredicto, se lee al lado
[ -n "${TRAS_NOTA:-}" ] && CIERRE="$CIERRE · $TRAS_NOTA"
echo
linea; echo "  CIERRE · $CIERRE"; linea
perl "$REF/receipt.pl" --anotar "CIERRE $CIERRE" --repo "$REPO" >/dev/null 2>&1
exit 0
