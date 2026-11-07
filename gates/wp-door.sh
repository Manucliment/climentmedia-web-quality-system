#!/usr/bin/env bash
# =============================================================================
#  wp-door.sh · la puerta de ESCRITURA en un WordPress vivo
# =============================================================================
#  La puerta de las subidas (deploy.sh) cubre los ficheros estáticos. Lo que se escribe DENTRO de un WordPress
#  (opciones, redirecciones, mu-plugins, entradas) iba a mano, con su copia y su vuelta atrás escritas cada vez.
#  Esta puerta no sabe de WordPress: hace cumplir el contrato de una TANDA, como deploy.sh hace cumplir el de UPLOAD.
#
#  USO
#    bash wp-door.sh <repo> <tanda>                     ensayo: sube la tanda, mide el antes y para
#    bash wp-door.sh <repo> <tanda> --escribir          aplica, prueba la vuelta, aplica otra vez y mide
#    bash wp-door.sh <repo> <tanda> --escribir --sin-probar-volver "<motivo>"
#    bash wp-door.sh <repo> <tanda> --volver            deshace la última vez de esa tanda (sin aprobado: deshacer
#                                                       no espera a nadie)
#
#  LA TANDA: <repo>/_deploy/wp/<tanda>/, commiteada, con
#    tanda.sh   tres modos: --medir (solo lee; líneas «OK …» y «🔴 …»), sin nada (copia en ~/backups, escribe,
#               purga) y --volver (desde su última copia). Corre en el host, en una carpeta de $WP_TMP que le llega
#               en TANDA_DIR: sus ficheros se leen de ahí, no de una ruta fija.
#    TANDA.md   qué escribe, qué NO y por qué, y ROJOS_DESPUES=<n> (lo que --medir puede dar después; por defecto 0)
#    lo que necesite (php para `wp eval-file`, mu-plugins…)
#  y FUERA de la carpeta, <repo>/_deploy/wp/<tanda>.aprobado, commiteado también:
#    APROBADO: <quién> · <fecha> · <árbol>
#  <árbol> = `git rev-parse HEAD:_deploy/wp/<tanda>`. Lo firma el Pod Manager (D-058): si se toca un fichero de la
#  tanda, el árbol cambia y hace falta otro aprobado. Va fuera porque dentro se nombraría a sí mismo.
#  <repo>/_deploy/deploy.conf: WP_HOST=<alias ssh> y, si no es /tmp, WP_TMP=<carpeta>. Solo se leen esas dos líneas.
#
#  PASOS
#    1. La carpeta y su .aprobado, limpios y commiteados; el aprobado nombra el árbol de hoy.
#    2. Empaqueta aquí el árbol APROBADO (git archive de HEAD, no la carpeta de trabajo, y sin convertir finales de
#       línea) y comprueba que cada fichero del paquete da su blob del árbol: si no, NO MEDIDO y no sube nada.
#       `bash -n` del tanda.sh del paquete, que es el que va a correr.
#    3. Cerrojo en el host: una tanda a la vez por web; uno de más de 15 min se da por muerto (y se dice).
#    4. Sube ese paquete a $WP_TMP/wp-<tanda>-<ts>/: no es un docroot. `php -l` de cada .php, allí.
#    5. --medir → antes.  Sin --escribir, CIERRE ENSAYO.
#    6. Con --escribir:
#       a. aplicar → --medir (después-1);
#       b. la vuelta, PROBADA: --volver → --medir (vuelta) tiene que dar lo de antes, línea a línea, sin horas.
#          Si no, para sin volver a aplicar: CIERRE FALLA «la vuelta no deja lo de antes»;
#       c. aplicar otra vez → --medir (después): rojos <= ROJOS_DESPUES y ni un rojo que no estuviera antes;
#       d. si c sale mal (o un aplicar falla): --volver → --medir. Igual a antes: CIERRE FALLA «VUELTO». Distinto:
#          CIERRE FALLA «VUELTA-INCOMPLETA», con las líneas que no volvieron.
#    7. Las medidas, en <repo>/_deploy/wp/_puerta/<tanda>-<ts>/; una fila en <repo>/_deploy/wp/historial.tsv.
#  Sale con 0 (PASA o ENSAYO), 1 (FALLA), 2 (NO MEDIDO) o 64 (uso).
#
#  PARA LAS PRUEBAS: WP_SSH y WP_SCP cambian ssh y scp (gates/wp-door-tests/ usa un host falso en una carpeta), y
#  WP_PHP_LINT cambia «php -l».
#  🔴 _deploy/wp/ no viaja con la subida estática: deploy.conf la tiene que excluir (_deploy entero, normalmente).
# =============================================================================
set -uo pipefail

uso() { echo "uso: wp-door.sh <repo> <tanda> [--escribir [--sin-probar-volver \"<motivo>\"] | --volver]" >&2; exit 64; }
[ $# -ge 2 ] || uso
REPO="${1%/}"; TANDA="$2"; shift 2
ESCRIBIR=0; VOLVER=0; SIN_PROBAR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --escribir) ESCRIBIR=1 ;;
    --volver) VOLVER=1 ;;
    --sin-probar-volver) shift; SIN_PROBAR="${1:-}"; [ -n "${SIN_PROBAR// /}" ] || { echo "--sin-probar-volver pide su motivo" >&2; exit 64; } ;;
    *) uso ;;
  esac
  shift
done
[ "$ESCRIBIR" = 1 ] && [ "$VOLVER" = 1 ] && uso
[ -n "$SIN_PROBAR" ] && [ "$ESCRIBIR" = 0 ] && { echo "--sin-probar-volver va con --escribir" >&2; exit 64; }
[[ "$TANDA" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "nombre de tanda no válido: $TANDA (letras, números, . _ -)" >&2; exit 64; }

SSH="${WP_SSH:-ssh}"; SCP="${WP_SCP:-scp}"; LINT="${WP_PHP_LINT:-php -l}"
REL="_deploy/wp/$TANDA"; DIR="$REPO/$REL"; APR="$REPO/_deploy/wp/$TANDA.aprobado"
TS=$(date +%Y%m%d-%H%M%S)
OUT="$REPO/_deploy/wp/_puerta/$TANDA-$TS"
HIST="$REPO/_deploy/wp/historial.tsv"
NOMBRE=$(basename "$REPO")

ARBOL="-"; ANTES_N="-"; DESPUES_N="-"; VUELTA="no"
cierre() { # estado motivo [exit]
  local est="$1" mot="$2" ex="${3:-}"
  if [ -d "$OUT" ] || mkdir -p "$OUT" 2>/dev/null; then :; fi
  [ -f "$HIST" ] || printf 'fecha\ttanda\tarbol\tmodo\trojos_antes\trojos_despues\tvuelta_probada\tcierre\n' > "$HIST"
  local modo=ensayo; [ "$ESCRIBIR" = 1 ] && modo=escribir; [ "$VOLVER" = 1 ] && modo=volver
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$TANDA" "$ARBOL" "$modo" "$ANTES_N" "$DESPUES_N" "$VUELTA" "$est - $mot" >> "$HIST"
  echo "CIERRE: $est - $mot"
  if [ -z "$ex" ]; then case "$est" in PASA|ENSAYO) ex=0 ;; FALLA) ex=1 ;; *) ex=2 ;; esac; fi
  exit "$ex"
}

# ── 1. el contrato, aquí ─────────────────────────────────────────────────────
[ -d "$REPO/.git" ] || [ -f "$REPO/.git" ] || { echo "no es un repo git: $REPO" >&2; exit 64; }
[ -d "$DIR" ] || { echo "no existe la tanda: $DIR" >&2; exit 64; }
CONF="$REPO/_deploy/deploy.conf"
leer_conf() { [ -f "$CONF" ] && sed -n "s/^[[:space:]]*$1=[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\}[[:space:]]*$/\1/p" "$CONF" | tail -1; }
WP_HOST=$(leer_conf WP_HOST); WP_TMP=$(leer_conf WP_TMP); WP_TMP="${WP_TMP:-/tmp}"
[ -n "$WP_HOST" ] || cierre "NO MEDIDO" "falta WP_HOST en _deploy/deploy.conf" 2
[[ "$WP_HOST" =~ ^[A-Za-z0-9._@-]+$ ]] || cierre "NO MEDIDO" "WP_HOST no válido: $WP_HOST" 2
[[ "$WP_TMP" =~ ^/[A-Za-z0-9._/-]*$ ]] || cierre "NO MEDIDO" "WP_TMP no válido: $WP_TMP" 2
[ -f "$DIR/tanda.sh" ] || cierre "FALLA" "la tanda no tiene tanda.sh"

if ! ARBOL=$(git -C "$REPO" rev-parse --verify -q "HEAD:$REL" 2>/dev/null); then ARBOL="-"; cierre "FALLA" "la tanda no está commiteada ($REL)"; fi
SUCIO=$(git -C "$REPO" status --porcelain -- "$REL" "_deploy/wp/$TANDA.aprobado" 2>/dev/null)
[ -z "$SUCIO" ] || cierre "FALLA" "la tanda o su aprobado tienen cambios sin commitear: $(echo "$SUCIO" | head -3 | tr '\n' ' ')"

ROJOS_DESPUES=0
if [ -f "$DIR/TANDA.md" ]; then
  r=$(sed -n 's/^[^A-Za-z]*ROJOS_DESPUES=\([0-9][0-9]*\).*/\1/p' "$DIR/TANDA.md" | tail -1); [ -n "$r" ] && ROJOS_DESPUES="$r"
elif [ "$VOLVER" = 0 ]; then cierre "FALLA" "la tanda no tiene TANDA.md (qué escribe, qué no y ROJOS_DESPUES)"; fi

if [ "$VOLVER" = 0 ]; then
  [ -f "$APR" ] || cierre "FALLA" "sin aprobado: falta _deploy/wp/$TANDA.aprobado (lo firma el Pod Manager, D-058)"
  L=$(grep -E '^[[:space:]]*APROBADO:' "$APR" | tail -1)
  [ -n "$L" ] || cierre "FALLA" "el aprobado no tiene la línea «APROBADO: <quién> · <fecha> · <árbol>»"
  A=$(grep -oE '[0-9a-f]{40}' <<<"$L" | tail -1)
  [ -n "$A" ] || cierre "FALLA" "el aprobado no nombra un árbol (40 hex: git rev-parse HEAD:$REL)"
  [ "$A" = "$ARBOL" ] || cierre "FALLA" "el aprobado es de otro árbol (${A:0:12}; hoy ${ARBOL:0:12}): la tanda cambió después de aprobarla"
fi

# ── 2. el paquete, aquí: los bytes del árbol aprobado, y bash -n ─────────────
# 7-nov-2026: `git archive` de un SUBÁRBOL no lee la .gitattributes de la raíz, y con core.autocrlf=true (el de Git
# for Windows) convierte LF en CRLF: una tanda aprobada subió con su tanda.sh en CRLF y en el host `set -o pipefail`
# no valía y cada línea arrastraba un $'\r' (dos NO MEDIDO). Sin conversión, y con testigo: cada fichero del
# paquete tiene que dar el blob del árbol aprobado; si no, lo que subiría no es lo aprobado.
mkdir -p "$OUT" || { echo "no se pudo crear $OUT" >&2; exit 64; }
git -C "$REPO" -c core.autocrlf=false archive --format=tar -o "$OUT/tanda.tar" "HEAD:$REL" || cierre "NO MEDIDO" "git archive de $REL" 2
PAQ="$OUT/paquete"
{ mkdir -p "$PAQ" && tar -xf "$OUT/tanda.tar" -C "$PAQ"; } || cierre "NO MEDIDO" "no se pudo abrir aquí el paquete para comprobarlo" 2
DISTINTOS=""
while IFS= read -r -d '' linea; do
  read -r modo tipo blob <<<"${linea%%$'\t'*}"; f="${linea#*$'\t'}"
  [ "$tipo" = blob ] && [ "$modo" != 120000 ] || continue
  [ "$(git -C "$REPO" hash-object --no-filters -- "$PAQ/$f" 2>/dev/null)" = "$blob" ] || DISTINTOS="$DISTINTOS $f"
done < <(git -C "$REPO" ls-tree -r -z "HEAD:$REL")
if [ -n "$DISTINTOS" ]; then
  rm -rf "$PAQ"
  cierre "NO MEDIDO" "el paquete no lleva los bytes del árbol aprobado en:$DISTINTOS (una conversión de git: eol o filter en una .gitattributes de la tanda)" 2
fi
bash -n "$PAQ/tanda.sh" 2>"$OUT/bash-n.txt" || { rm -rf "$PAQ"; cierre "FALLA" "bash -n de tanda.sh: $(head -1 "$OUT/bash-n.txt")"; }
rm -rf "$PAQ"

# ── 3. el cerrojo, en el host ────────────────────────────────────────────────
CERR="$WP_TMP/wp-door-$NOMBRE.cerrojo"
rem() { "$SSH" -n "$WP_HOST" "$1"; }
if ! rem "mkdir '$CERR'" 2>/dev/null; then
  if [ -n "$(rem "find '$WP_TMP' -maxdepth 1 -name 'wp-door-$NOMBRE.cerrojo' -mmin +15" 2>/dev/null)" ]; then
    echo "   cerrojo de más de 15 min: se da por muerto y se coge ($CERR)"
    rem "rmdir '$CERR' && mkdir '$CERR'" 2>/dev/null || cierre "NO MEDIDO" "no se pudo coger el cerrojo viejo $CERR" 2
  else
    cierre "FALLA" "otra tanda de $NOMBRE está corriendo (cerrojo $CERR, de menos de 15 min): se espera a que acabe"
  fi
fi
trap 'rem "rmdir '"'$CERR'"'" >/dev/null 2>&1' EXIT

# ── 4. subir el paquete del paso 2 ───────────────────────────────────────────
R="$WP_TMP/wp-$TANDA-$TS"
rem "mkdir -p '$R'" || cierre "NO MEDIDO" "no se pudo crear $R en $WP_HOST" 2
"$SCP" -q "$OUT/tanda.tar" "$WP_HOST:$R.tar" || cierre "NO MEDIDO" "scp a $WP_HOST:$R.tar" 2
rem "tar -xf '$R.tar' -C '$R' && rm -f '$R.tar'" || cierre "NO MEDIDO" "no se pudo abrir la tanda en $R" 2
rm -f "$OUT/tanda.tar"
for f in $(git -C "$REPO" ls-tree -r --name-only "HEAD:$REL" | grep -E '\.php$'); do
  rem "$LINT '$R/$f'" > "$OUT/php-l.txt" 2>&1 || cierre "FALLA" "php -l de $f: $(grep -v '^$' "$OUT/php-l.txt" | head -1)"
done

corre() { rem "cd '$R' && TANDA_DIR='$R' bash tanda.sh $1"; }
# Lo medido: solo las líneas OK y 🔴, sin horas ni fechas (la vuelta se compara con el antes línea a línea).
norma() { grep -E '^[[:space:]]*(OK|🔴)' "$1" | sed -E 's/^[[:space:]]+//; s/[0-9]{4}-[0-9]{2}-[0-9]{2}([ T][0-9]{2}:[0-9]{2}(:[0-9]{2})?)?/<fecha>/g; s/\b[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?\b/<hora>/g'; }
rojos() { norma "$1" | grep -c '^🔴'; }
medir() { # etiqueta → OUT/<etiqueta>.txt; NO MEDIDO si no dio ni una línea
  corre --medir > "$OUT/$1.txt" 2>&1
  [ -n "$(norma "$OUT/$1.txt")" ] || return 1
  return 0
}
rojos_nuevos() { comm -13 <(norma "$OUT/antes.txt" | grep '^🔴' | sort -u) <(norma "$1" | grep '^🔴' | sort -u); }

if [ "$VOLVER" = 1 ]; then
  corre --volver > "$OUT/volver.txt" 2>&1; ev=$?
  medir vuelta || cierre "NO MEDIDO" "--volver salió con $ev y --medir no dio ni una línea" 2
  DESPUES_N=$(rojos "$OUT/vuelta.txt"); VUELTA="a mano"
  [ "$ev" = 0 ] && cierre "PASA" "VUELTO a mano; --medir da $DESPUES_N en rojo (medidas en ${OUT#$REPO/})"
  cierre "FALLA" "--volver salió con $ev; --medir da $DESPUES_N en rojo (medidas en ${OUT#$REPO/})"
fi

# ── 5. el antes ──────────────────────────────────────────────────────────────
medir antes || cierre "NO MEDIDO" "--medir no dio ni una línea OK/🔴 (${OUT#$REPO/}/antes.txt)" 2
ANTES_N=$(rojos "$OUT/antes.txt")
echo "   antes: $ANTES_N en rojo"
[ "$ESCRIBIR" = 1 ] || cierre "ENSAYO" "subida y medida, sin escribir: antes $ANTES_N en rojo; con --escribir aplicaría $TANDA (árbol ${ARBOL:0:12})"

# ── 6. escribir ──────────────────────────────────────────────────────────────
deshacer() { # motivo
  corre --volver > "$OUT/volver-final.txt" 2>&1
  if ! medir vuelta-final; then cierre "FALLA" "$1; deshecho, pero --medir no midió después: VUELTA-INCOMPLETA sin medir"; fi
  DESPUES_N=$(rojos "$OUT/vuelta-final.txt")
  if diff -q <(norma "$OUT/antes.txt") <(norma "$OUT/vuelta-final.txt") >/dev/null; then
    cierre "FALLA" "$1; VUELTO: lo de antes, otra vez"
  fi
  local d; d=$(diff <(norma "$OUT/antes.txt") <(norma "$OUT/vuelta-final.txt") | grep -E '^[<>]' | head -3 | tr '\n' ' ')
  cierre "FALLA" "$1; VUELTA-INCOMPLETA: $d"
}

corre "" > "$OUT/aplicar-1.txt" 2>&1; e1=$?
[ "$e1" = 0 ] || deshacer "aplicar salió con $e1"
medir despues-1 || deshacer "--medir no midió tras aplicar"

if [ -n "$SIN_PROBAR" ]; then
  VUELTA="saltada: $SIN_PROBAR"
  echo "   vuelta SIN probar: $SIN_PROBAR"
  cp "$OUT/despues-1.txt" "$OUT/despues.txt"
else
  corre --volver > "$OUT/volver-prueba.txt" 2>&1; ev=$?
  if ! medir vuelta || [ "$ev" != 0 ] || ! diff -q <(norma "$OUT/antes.txt") <(norma "$OUT/vuelta.txt") >/dev/null; then
    VUELTA="falla"
    d=$(diff <(norma "$OUT/antes.txt") <(norma "$OUT/vuelta.txt" 2>/dev/null) 2>/dev/null | grep -E '^[<>]' | head -3 | tr '\n' ' ')
    DESPUES_N=$( [ -s "$OUT/vuelta.txt" ] && rojos "$OUT/vuelta.txt" || echo -)
    cierre "FALLA" "la vuelta no deja lo de antes (--volver salió con $ev): no se vuelve a aplicar. VUELTA-INCOMPLETA: ${d:-sin medida}"
  fi
  VUELTA="sí"
  corre "" > "$OUT/aplicar-2.txt" 2>&1; e2=$?
  [ "$e2" = 0 ] || deshacer "el segundo aplicar salió con $e2"
  medir despues || deshacer "--medir no midió tras el segundo aplicar"
fi

DESPUES_N=$(rojos "$OUT/despues.txt")
NUEVOS=$(rojos_nuevos "$OUT/despues.txt")
[ -z "$NUEVOS" ] || deshacer "rojo nuevo tras aplicar: $(head -2 <<<"$NUEVOS" | tr '\n' ' ')"
[ "$DESPUES_N" -le "$ROJOS_DESPUES" ] || deshacer "después $DESPUES_N en rojo y TANDA.md admite $ROJOS_DESPUES"
cierre "PASA" "$TANDA escrita: antes $ANTES_N en rojo, después $DESPUES_N (admite $ROJOS_DESPUES); vuelta $VUELTA; medidas en ${OUT#$REPO/}"
