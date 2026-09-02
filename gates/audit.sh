#!/usr/bin/env bash
# =============================================================================
# _audit.sh - AUDITOR DE SITIO (no de pagina).
#
# Por que existe: teniamos un estandar de PAGINA (skill web-page-standard, 265
# lineas) y un gate de integridad de 5 comprobaciones (_check.sh). Entre los dos
# no habia nada que validara el sitio COMO SISTEMA. Todos los fallos que se nos
# colaron el 31-jul y el 1-ago eran de sistema, no de pagina:
#
#   - llms.txt publicaba 11 URLs a 404 y no listaba ninguna pieza de /learn/
#   - AGENTS.md afirmaba un posicionamiento retirado hacia meses
#   - el sitio no enviaba ni una cabecera Cache-Control
#   - una pagina indexable sin enlaces entrantes ni noindex
#
# Ninguna pagina estaba mal por separado. Por eso este fichero es EJECUTABLE:
# un documento hay que acordarse de leerlo, un script falla solo.
#
# USO
#   bash _audit.sh              # auditoria local (ficheros en disco)
#   bash _audit.sh --live       # + entrega real en produccion (necesita red)
#   bash _audit.sh --root DIR --url https://ejemplo.com
#
# PORTABLE: sin jq, sin node, sin python. Solo bash, grep, sed, find y curl.
# Para otro proyecto: copia el fichero y ajusta _audit.conf (ver abajo).
#
# SALIDA: [ ok ] pasa · [FAIL] rompe el build · [warn] mirar, no bloquea ·
#         [skip] no se pudo comprobar Y POR QUE (nunca se salta en silencio).
# =============================================================================
set -u

# ---------- configuracion ----------
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SELF_DIR"
BASE_URL=""
LIVE=0
# Defecto GENERICO a proposito: este script lo comparten todas las webs, y el
# defecto de antes arrastraba carpetas de climentmedia (ds-bundle, _cowork,
# .design-sync) dentro de un script compartido. Las 6 webs declaran el suyo en
# su .conf, asi que este defecto solo lo ve una web NUEVA -- y a una web nueva
# no se le pueden excluir carpetas que no tiene.
EXCLUDE_DIRS=".git node_modules dist build vendor"
DEAD_PREFIXES=""
BRAND=""

while [ $# -gt 0 ]; do
  case "$1" in
    --live) LIVE=1; shift ;;
    --root) ROOT="$2"; shift 2 ;;
    --url)  BASE_URL="$2"; shift 2 ;;
    *) echo "argumento desconocido: $1"; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
#  GUARDA: este script vive en la SKILL, no dentro de cada web.
# ---------------------------------------------------------------------------
#  19-ago-2026. Antes vivia COPIADO en cada repo -4 copias, 3 versiones-, y por
#  eso `ROOT` cae por defecto en la carpeta del propio script: ahi eso era
#  correcto. Ahora ya no: sin --root mediria la skill y diria cosas de ella,
#  en silencio y con aspecto de informe. Un instrumento que mide el arbol
#  equivocado sin quejarse es peor que uno que no corre.
if [ "$ROOT" = "$SELF_DIR" ]; then
  echo "audit.sh: falta --root." >&2
  echo "  Este script vive en la skill y NO mide la carpeta en la que esta." >&2
  echo "  Uso:  bash \"$0\" --root /ruta/al/repo" >&2
  exit 2
fi

# El .conf permite reusar este script en cualquier proyecto sin editarlo.
# Se aceptan los DOS nombres: el kit publicado usa `audit.conf` y los repos
# nuestros `_audit.conf`. Antes solo valia el segundo, y el kit de fuera no
# encontraba su propia configuracion.
for c in "$ROOT/audit.conf" "$ROOT/_audit.conf"; do [ -f "$c" ] && . "$c" && break; done
[ -n "$BASE_URL" ] || BASE_URL="${CONF_BASE_URL:-}"

FAIL=0; WARN=0; NCHECK=0
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
warn() { echo "  [warn] $1"; WARN=$((WARN+1)); }
ok()   { echo "  [ ok ] $1"; }
skip() { echo "  [skip] $1"; }
sec()  { echo; echo "-- $1"; }

# Lista de paginas HTML desplegables (excluye las carpetas de trabajo).
# OJO: la primera version usaba `eval find ... -not -path "..."` y devolvia CERO
# paginas en Git Bash. Consecuencia: S2, S3, S4.2 y S5.1 iteraban sobre nada y
# reportaban [ ok ] sin haber comprobado ni un fichero. Es EXACTAMENTE el fallo
# que este auditor existe para impedir -- una comprobacion que pasa porque no
# comprobo nada -- y por eso abajo hay un guardia que revienta si salen 0.
#  🔴 26-ago-2026 · LAS CARPETAS QUE EMPIEZAN POR GUION BAJO NO SE DESPLIEGAN,
#     Y ESTE LISTADO LAS AUDITABA IGUAL.
#     `EXCLUDE_DIRS` traia `.git node_modules dist build vendor` y ninguna de
#     las carpetas de trabajo. Consecuencia medida ese dia sobre una web de
#     cliente VIVA: **78 FALLOS, los 78 falsos**, todos de sus 7 plantillas de
#     imagen social en `_og/` -sin <title>, fuera del sitemap, sin canonical-.
#     Son plantillas, no paginas: `_og` esta en el `--exclude` del deploy y sus
#     ficheros dan **404 en produccion**, comprobado.
#     Un auditor que saca 78 rojos sobre un sitio sano se deja de mirar, y
#     entonces se pierde tambien lo que si cazaba.
#     Y costaba mas que ruido: al auditar de mas, dos repos **se pasaban de los
#     5 minutos y se cortaban sin dar veredicto** -uno tiene 220 HTML en
#     carpetas de trabajo y otro 151-.
#     Verificado antes de tocar: de las 13 carpetas `_*` con HTML que hay en
#     los 6 repos, **ninguna se despliega**. La convencion se sostiene.
page_list() {
  find "$ROOT" -name '*.html' -type f 2>/dev/null | sed "s|^$ROOT/||" | while read -r p; do
    keep=1
    case "$p" in _*/*) keep=0 ;; esac
    for d in $EXCLUDE_DIRS; do
      case "$p" in "$d"/*) keep=0; break ;; esac
    done
    [ "$keep" = 1 ] && echo "$p"
  done | sort
}

# ---------------------------------------------------------------------------
#  resolver_ruta · LAS DOS CONVENCIONES DE URL, EN UN SOLO SITIO
# ---------------------------------------------------------------------------
#  19-ago-2026. Nuestras webs sirven las URLs de dos formas distintas, y hasta
#  hoy el auditor solo conocia una:
#
#     dir-barra       /contacto  ->  contacto/index.html   (3 de las 6 del parque)
#     plano-sin-ext   /contacto  ->  contacto.html         (las otras 2)
#
#  `conformidad.conf` ya nombraba las dos por web (`modo = ...`) y el auditor no
#  se habia enterado: la primera vez que se le corrio a kine marco 363 FALLOS en
#  un sitio correcto -310 de ellos "enlace roto"-. Es la tercera vez que este
#  fichero paga el mismo error: un supuesto de convencion que nadie declaro.
#  *Si el barrido dice que todo esta roto a la vez, el roto es el barrido.*
#
#  NO se pregunta cual es la convencion: se acepta la que EXISTA. Asi no hay que
#  declararla en dos sitios y no pueden discrepar. Si no existe ninguna, se
#  devuelve la PRIMERA para que el mensaje de error diga que se esperaba.
#
#  Recibe y devuelve rutas ABSOLUTAS. La usan url_to_file (sitemap, ficheros
#  para maquinas) y el grafo de enlaces: un solo sitio, una sola regla.
#  🔴 26-ago-2026 · DEJA EL RESULTADO EN `RUTA_RESUELTA` ADEMAS DE IMPRIMIRLO.
#     La funcion es shell puro y no cuesta nada; lo caro era llamarla con
#     `$(...)`, que forkea una subshell por llamada. En un sitio de 61 paginas
#     hay ~1700 enlaces internos, o sea ~1700 forks, y en Git Bash un fork
#     cuesta decenas de milisegundos. El auditor no terminaba, y se cortaba
#     siempre dentro de S3. Los bucles calientes la llaman ahora SIN `$( )` y
#     leen la variable; el resto sigue con `$( )` y no hace falta tocarlo. La
#     regla de resolucion sigue escrita UNA sola vez, que es lo que importa.
resolver_ruta() {
  local c="$1" ultimo cand1 cand2
  case "$c" in
    */) cand1="${c}index.html"; cand2="${c%/}.html" ;;
    *)  ultimo="${c##*/}"
        case "$ultimo" in
          *.*) RUTA_RESUELTA="$c"; echo "$c"; return ;;
        esac
        cand1="$c/index.html"; cand2="$c.html" ;;
  esac
  [ -f "$cand1" ] && { RUTA_RESUELTA="$cand1"; echo "$cand1"; return; }
  [ -f "$cand2" ] && { RUTA_RESUELTA="$cand2"; echo "$cand2"; return; }
  RUTA_RESUELTA="$cand1"; echo "$cand1"
}

#  🔴 26-ago-2026 · SUSTITUYE A `realpath -m --relative-to`, QUE ERA EL CUELLO
#     DE BOTELLA DE VERDAD. `realpath` es un BINARIO EXTERNO y estaba dentro
#     del bucle de ~1700 enlaces, dentro de un `$( )`: ~1700 procesos.
#     Esto es shell puro, no forkea, y de paso quita una dependencia --
#     `realpath` no existe en todas las instalaciones y el fichero declara ser
#     portable con solo bash, grep, sed, find y curl.
#     ⚠️ **Probado equivalente, no supuesto**: comparado contra `realpath`
#     sobre los 1075 destinos distintos de un sitio real -> 1075 iguales, 0
#     distintos. La primera version fallaba 45 de 1075, todos por el mismo
#     caso: cuando el destino ES la raiz, `realpath` dice "." y esta devolvia
#     cadena vacia. Por eso se prueba antes de cablear.
rel_a_root() {                 # deja el resultado en RUTA_REL
  local p="$1" seg out="" old="$IFS"
  case "$p" in "$ROOT"/*) p="${p#"$ROOT"/}" ;; "$ROOT") p="" ;; esac
  IFS='/'
  for seg in $p; do
    case "$seg" in
      ''|.) ;;
      ..)  case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac ;;
      *)   if [ -z "$out" ]; then out="$seg"; else out="$out/$seg"; fi ;;
    esac
  done
  IFS="$old"
  [ -z "$out" ] && out="."
  RUTA_REL="$out"
}

# La INVERSA de resolver_ruta: de un fichero en disco a las URLs con las que se
# puede estar publicando. Existe por el mismo motivo y en la misma pareja: S1.3
# mapeaba fichero -> URL conociendo UNA sola convencion, y por eso acusaba a
# kine de tener 15 paginas «fuera del sitemap» que estan perfectamente dentro
# (contacto.html se publica como /contacto). Las dos funciones son las dos
# direcciones de la MISMA regla, y por eso viven juntas.
urls_de_fichero() {
  local p="$1" base sinbarra
  base="$(echo "$p" | sed 's|index\.html$||')"
  echo "$BASE_URL/$base"                       # /carpeta/   o  /pagina.html
  sinbarra="${base%/}"
  echo "$BASE_URL/$sinbarra"                   # /carpeta    o  /pagina.html
  case "$base" in
    *.html) echo "$BASE_URL/${base%.html}" ;;  # /pagina      (convencion plana)
  esac
}

# URL absoluta -> ruta de fichero en disco, RELATIVA a ROOT.
# La convencion (carpeta/index.html o fichero plano) la decide `resolver_ruta`,
# que es el UNICO sitio donde esa regla esta escrita.
url_to_file() {
  local u="${1#$BASE_URL}"; u="${u%%\#*}"; u="${u%%\?*}"
  u="${u#/}"
  [ -z "$u" ] && { echo "index.html"; return; }
  local abs; abs="$(resolver_ruta "$ROOT/$u")"
  echo "${abs#$ROOT/}"
}

# Texto de <title> sin el sufijo de marca.
title_of() {
  sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$1" | head -1
}

# El contenido de un <pre> es TEXTO, no marcado: un href dentro de un ejemplo
# de codigo no es un enlace. Sin esto, una pagina que inlinea documentacion
# (las de /copy/) reporta como rotos los href de sus propios ejemplos, y hasta
# fragmentos de regex sueltos. Es el mismo error que el chequeo de mojibake:
# tratar codigo fuente inlineado como si fuera markup.
# awk y no `sed '/<pre/,/<\/pre>/d'`: sed no cierra el rango en la misma linea,
# asi que un <pre> de una linea se comeria el resto del documento.
strip_pre() {
  awk '{
    line=$0
    while (match(line, /<pre[^>]*>/)) {
      pre=substr(line,1,RSTART-1); rest=substr(line,RSTART+RLENGTH)
      if (match(rest, /<\/pre>/)) { line = pre substr(rest,RSTART+RLENGTH); continue }
      else { print pre; inpre=1; line=""; break }
    }
    if (inpre) { if (match(line, /<\/pre>/)) { inpre=0; line=substr(line,RSTART+RLENGTH) } else next }
    print line
  }' "$1"
}

echo "==========================================================="
echo " AUDITORIA DE SITIO: $ROOT"
[ -n "$BASE_URL" ] && echo " URL base: $BASE_URL"
[ "$LIVE" -eq 1 ] && echo " modo: LOCAL + PRODUCCION" || echo " modo: LOCAL (usa --live para comprobar la entrega)"
echo "==========================================================="

PAGES="$(page_list)"
NPAGES=$(echo "$PAGES" | grep -c . )
echo "  paginas desplegables encontradas: $NPAGES"
# GUARDIA ANTI-VACIO. Sin esto, un fallo en page_list convierte media auditoria
# en [ ok ] falsos: iterar sobre una lista vacia no falla, "pasa". Ya ocurrio.
if [ "$NPAGES" -lt 1 ]; then
  echo "  [FAIL] S0 el barrido de paginas devolvio CERO ficheros."
  echo "         No es que el sitio este limpio: es que no se ha mirado nada."
  echo "         Revisa ROOT y EXCLUDE_DIRS en _audit.conf antes de creerte nada."
  exit 1
fi

# =============================================================================
sec "S1 · FICHEROS PARA MAQUINAS (sitemap · llms.txt · AGENTS.md · robots.txt)"
# Se rompen sin avisar porque NO son HTML: un grep de href= no los cubre.
# =============================================================================

SM="$ROOT/sitemap.xml"
if [ ! -f "$SM" ]; then
  bad "S1.1 no hay sitemap.xml"
  SM_URLS=""
else
  head -1 "$SM" | grep -q '<?xml' && grep -q '<urlset' "$SM" \
    && ok "S1.1 sitemap.xml bien formado" || bad "S1.1 sitemap.xml malformado"
  SM_URLS=$(grep -oE '<loc>[^<]+' "$SM" | sed 's/<loc>//')
  NSM=$(echo "$SM_URLS" | grep -c .)
  MISS=0
  for u in $SM_URLS; do
    f="$(url_to_file "$u")"
    [ -f "$ROOT/$f" ] || { bad "S1.2 sitemap apunta a algo que no existe en disco: $u  (esperaba $f)"; MISS=1; }
  done
  [ "$MISS" -eq 0 ] && ok "S1.2 las $NSM URLs del sitemap existen en disco"

  # S1.3 toda pagina indexable tiene que estar EN el sitemap.
  # Es la mitad que casi nadie comprueba: se vigila que el sitemap no mienta,
  # no que este completo. Una pagina real fuera del sitemap es una pagina que
  # Google puede tardar meses en encontrar.
  # ⚠️ ESTE CHEQUEO TRAIA UN SUPUESTO SIN DECLARAR: que `carpeta/index.html` se
  #    indexa como `/carpeta/` CON barra. Al pasar el sitio a URLs sin barra
  #    -que es la forma que este cliente ya tiene indexada- marco 78 fallos en un
  #    sitio correcto. Es la misma clase de fallo que la trampa 2 de CLAUDE.md,
  #    con los enlaces relativos. Ahora se comparan las dos formas.
  #    *Si el barrido dice que todo esta roto a la vez, el roto es el barrido.*
  FALTAN=0
  for p in $PAGES; do
    grep -q 'name="robots"[^>]*noindex' "$ROOT/$p" && continue
    ENCONTRADA=0
    for u in $(urls_de_fichero "$p"); do
      echo "$SM_URLS" | grep -qxF "$u" && { ENCONTRADA=1; break; }
    done
    if [ "$ENCONTRADA" -eq 0 ]; then
      bad "S1.3 indexable pero FUERA del sitemap: $p  (o la anades, o le pones noindex)"
      FALTAN=1
    fi
  done
  [ "$FALTAN" -eq 0 ] && ok "S1.3 toda pagina indexable esta en el sitemap"

  # S1.4 y ninguna del sitemap puede ser noindex (se contradicen).
  CONTRA=0
  for u in $SM_URLS; do
    f="$ROOT/$(url_to_file "$u")"
    [ -f "$f" ] || continue
    grep -q 'name="robots"[^>]*noindex' "$f" && { bad "S1.4 en el sitemap Y con noindex (se contradicen): $u"; CONTRA=1; }
  done
  [ "$CONTRA" -eq 0 ] && ok "S1.4 ninguna URL del sitemap lleva noindex"
fi

for MF in llms.txt AGENTS.md; do
  if [ ! -f "$ROOT/$MF" ]; then
    skip "S1.5 no hay $MF en el repo (si el sitio lo sirve, esta descuadrado)"
    continue
  fi
  # El backtick y el asterisco se excluyen: son sintaxis de markdown, no de la URL.
  URLS=$(grep -oE 'https?://[^ )"<>*`]+' "$ROOT/$MF" | sed 's/[.,:]$//' | sort -u)
  MISSM=0; NEXT=0
  for u in $URLS; do
    case "$u" in
      "$BASE_URL"*)
        f="$(url_to_file "$u")"
        [ -f "$ROOT/$f" ] || { bad "S1.5 $MF apunta a algo que no existe: $u  (esperaba $f)"; MISSM=1; } ;;
      *) NEXT=$((NEXT+1)) ;;
    esac
  done
  NIN=$(echo "$URLS" | grep -c "^$BASE_URL")
  [ "$MISSM" -eq 0 ] && ok "S1.5 las $NIN URLs propias de $MF existen ($NEXT externas, no comprobadas en local)"
  # S1.6 son texto plano: una entidad HTML se lee literal.
  if grep -qE '&(amp|mdash|ndash|middot|rarr|larr|quot|iquest|aacute|eacute|iacute|oacute|uacute|ntilde);' "$ROOT/$MF"; then
    bad "S1.6 $MF tiene entidades HTML sin decodificar (es texto plano: se leen literales)"
  else
    ok "S1.6 $MF sin entidades HTML crudas"
  fi

  # S1.6b · CADA URL PROPIA LLEVA DESCRIPCION (2-sep-2026)
  # 03-contenido-y-seo seccion 5 pide "las paginas CON SUS DESCRIPCIONES" desde
  # siempre, y no lo comprobaba nadie. Medido ese dia: 14 de 48 en nuestra
  # propia web, o sea 34 URLs desnudas. Una URL sin descripcion le dice al
  # modelo que la pagina EXISTE; no le dice cual abrir, que es justo para lo
  # que sirve este fichero.
  # Solo grep y comparacion numerica a proposito: este script tiene documentado
  # que un check con construcciones raras aqui dentro da VERDE por no llegar a
  # ejecutarse.
  CON_URL=$(grep -cE "^- \[[^]]*\]\($BASE_URL[^)]*\)" "$ROOT/$MF")
  DESNUDAS=$(grep -cE "^- \[[^]]*\]\($BASE_URL[^)]*\)[[:space:]]*$" "$ROOT/$MF")
  if [ "$CON_URL" -eq 0 ]; then
    skip "S1.6b $MF no lista URLs propias con el formato - [Titulo](url): no se puede medir"
  elif [ "$DESNUDAS" -eq 0 ]; then
    ok "S1.6b las $CON_URL URLs propias de $MF llevan descripcion"
  else
    bad "S1.6b $MF: $DESNUDAS de $CON_URL URLs propias SIN descripcion (una URL desnuda dice que la pagina existe, no cual abrir)"
  fi
done

if [ -f "$ROOT/robots.txt" ]; then
  grep -qi "^Sitemap: https\?://" "$ROOT/robots.txt" \
    && ok "S1.7 robots.txt declara el sitemap con URL absoluta" \
    || bad "S1.7 robots.txt no declara Sitemap: con URL absoluta"
else
  bad "S1.7 no hay robots.txt"
fi

# S1.8 ninguna superficie puede citar una ruta que ya solo existe como 301.
if [ -n "$DEAD_PREFIXES" ]; then
  DP=0
  for pre in $DEAD_PREFIXES; do
    for MF in sitemap.xml llms.txt AGENTS.md; do
      [ -f "$ROOT/$MF" ] || continue
      n=$(grep -c "$BASE_URL$pre" "$ROOT/$MF" 2>/dev/null)
      [ "$n" -gt 0 ] && { bad "S1.8 $MF cita $n vez/veces la ruta muerta $pre"; DP=1; }
    done
  done
  [ "$DP" -eq 0 ] && ok "S1.8 ningun fichero para maquinas cita rutas muertas"
else
  skip "S1.8 sin DEAD_PREFIXES configurado en _audit.conf (no se puede comprobar)"
fi

# =============================================================================
sec "S2 · META POR PAGINA"
# =============================================================================
T_MISS=0; T_BRAND=0; D_MISS=0; D_LONG=0; D_SHORT=0; C_MISS=0; OG_MISS=0; H1_BAD=0; LANG_BAD=0; LD_ENT=0
TITLES_FILE="$(mktemp 2>/dev/null || echo "$ROOT/.audit-titles.tmp")"
: > "$TITLES_FILE"

for p in $PAGES; do
  f="$ROOT/$p"
  # Una pagina noindex no compite en buscadores ni se comparte: exigirle
  # canonical, Open Graph o un title con termino es ruido, y un auditor
  # ruidoso se acaba ignorando. Se le sigue exigiendo lo estructural.
  INDEXABLE=1
  grep -q 'name="robots"[^>]*noindex' "$f" && INDEXABLE=0
  # --- title
  t="$(title_of "$f")"
  if [ -z "$t" ]; then bad "S2.1 sin <title>: $p"; T_MISS=1
  else
    echo "$t" >> "$TITLES_FILE"
    # title que es solo la marca = 0 clics con impresiones (ya medido en mkt.)
    if [ -n "$BRAND" ]; then
        core="$(echo "$t" | sed "s/[[:space:]]*[-|&][a-z]*;*[[:space:]]*$BRAND[[:space:]]*$//I" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        # 19-ago-2026 · ANTES ERA `-lt 12`, UN SUELO ARBITRARIO QUE ACUSABA A
        # TITULOS PERFECTAMENTE BUENOS: «Contacto» son 8 y «A propos» 8, y los
        # dos son terminos reales, no marca. Lo que el check quiere decir es
        # otra cosa, y ahora lo dice: el titulo no puede ser SOLO la marca.
        # Se compara con la marca en vez de medir longitud, que era medir un
        # sintoma parecido en vez del hecho.
        core_min="$(echo "$core" | tr '[:upper:]' '[:lower:]')"
        brand_min="$(echo "$BRAND" | tr '[:upper:]' '[:lower:]')"
        if [ "$INDEXABLE" -eq 1 ] && { [ "${#core}" -lt 3 ] || [ "$core_min" = "$brand_min" ]; }; then
          bad "S2.1 <title> sin termino, solo marca ('$t'): $p"; T_BRAND=1
        fi
    fi
  fi
  # --- description
  d="$(sed -n 's/.*<meta name="description" content="\([^"]*\)".*/\1/p' "$f" | head -1)"
  if [ -z "$d" ]; then bad "S2.2 sin meta description: $p"; D_MISS=1
  else
    # Se mide el texto DECODIFICADO: Google ve "&" y "—", no "&amp;" ni
    # "&mdash;". Contando el crudo se recortarian frases que caben.
    # CUALQUIER entidad cuenta como UN caracter: &amp; se ve como "&" y &euro;
    # como "EUR". Una lista escrita a mano siempre se queda corta -- esta no
    # tenia &euro; y acusaba de larga una description que cabia (20-ago-2026).
    dd="$(echo "$d" | sed -e 's/&#\?[a-zA-Z0-9]{1,7};/X/g')"
    n=${#dd}
    if [ "$n" -gt 165 ]; then bad "S2.2 description de $n caracteres (Google corta ~155-160, se pierde el gancho): $p"; D_LONG=1
    elif [ "$n" -lt 110 ]; then warn "S2.2 description corta ($n car., desaprovecha espacio): $p"; D_SHORT=1; fi
  fi
  # --- canonical
  [ "$INDEXABLE" -eq 1 ] && { grep -q 'rel="canonical"' "$f" || { bad "S2.3 sin canonical: $p"; C_MISS=1; }; }
  # --- Open Graph (solo indexables: una noindex no se comparte)
  if [ "$INDEXABLE" -eq 1 ]; then
    for og in 'og:title' 'og:description' 'og:url' 'og:image'; do
      grep -q "property=\"$og\"" "$f" || { bad "S2.4 falta $og: $p"; OG_MISS=1; }
    done
    # Y que la imagen EXISTA, no solo que la etiqueta este. Comprobar la
    # etiqueta y no el fichero es como se publica una pagina que al compartirse
    # sale como un rectangulo gris: el HTML es correcto y el 404 es del asset.
    ogimg="$(grep -o 'property="og:image" content="[^"]*"' "$f" | sed 's/.*content="//;s/"//' | head -1)"
    if [ -n "$ogimg" ]; then
      ogp="${ogimg#$BASE_URL/}"
      case "$ogimg" in
        "$BASE_URL"*) [ -f "$ROOT/$ogp" ] || { bad "S2.9 og:image declarada pero el fichero NO existe ($ogp): $p"; OG_MISS=1; } ;;
      esac
    fi
  fi
  # --- S2.10 · el zoom no se bloquea  (regla AC-A15 del estandar) ------------
  # `user-scalable=no` y `maximum-scale=1` impiden ampliar la pagina. Para quien
  # no ve bien, eso no es una molestia: es no poder usar la web. Se medible en
  # disco y hasta hoy no lo miraba NADIE -- una de las 45 reglas huerfanas.
  grep -qE '<meta[^>]+name="viewport"[^>]+(user-scalable=no|maximum-scale=1(\.0)?[",])' "$f" \
    && { bad "S2.10 el zoom esta bloqueado (user-scalable=no o maximum-scale=1): $p"; ZOOM_BAD=1; }

  # --- S2.11 · el telefono es un enlace tel:  (regla TP-15) ------------------
  # Un telefono escrito en texto y no enlazado obliga a copiarlo a mano en un
  # movil, que es donde se llama. Solo se exige si la pagina lo ENSENA.
  #
  # 🔴 LA PRIMERA VERSION MIRABA EL FICHERO ENTERO Y ACUSO A 29 PAGINAS DE NORA.
  #    El numero estaba dentro del JSON-LD ("telephone":"+34..."), donde tiene
  #    que ser texto plano: un tel: ahi seria incorrecto. Se mira solo lo que el
  #    visitante VE -- fuera <script> y fuera <head>-, que es el mismo error de
  #    "tratar texto inlineado como si fuera marcado" que ya costo falsos
  #    positivos en S3.1, en el JSON-LD y en el mojibake.
  VISIBLE="$(sed -e '/<script/,/<\/script>/d' -e '/<head/,/<\/head>/d' "$f" 2>/dev/null)"
  if printf '%s' "$VISIBLE" | grep -qE '(\+34|\+32|\+351)[0-9 ]{6,}' && ! grep -q 'href="tel:' "$f"; then
    bad "S2.11 ensena un telefono y no hay ningun href=\"tel:\": $p"; TEL_BAD=1
  fi

  # --- S2.12 · Article XOR TechArticle  (regla WPS-25) -----------------------
  # Declarar los dos @type en la misma pagina es decirle a Google dos cosas
  # distintas sobre que es. Se elige uno.
  if grep -q '"@type"[^}]*"Article"' "$f" && grep -q '"@type"[^}]*"TechArticle"' "$f"; then
    bad "S2.12 declara Article Y TechArticle a la vez (elige uno): $p"; TIPO_BAD=1
  fi
  # --- un solo H1
  nh1=$(grep -oE '<h1[ >]' "$f" | wc -l | tr -d ' ')
  [ "$nh1" -eq 1 ] || { bad "S2.5 tiene $nh1 <h1> (debe ser exactamente 1): $p"; H1_BAD=1; }
  # --- lang
  grep -qE '<html[^>]+lang="' "$f" || { bad "S2.6 <html> sin lang: $p"; LANG_BAD=1; }
  # --- entidades crudas dentro del JSON-LD: Google lee "&iquest;Sois" literal
  if grep -q 'application/ld+json' "$f"; then
    # OJO con `sed -n '/A/,/B/p'`: NO busca el cierre en la misma linea que la
    # apertura, asi que un JSON-LD de una sola linea hacia que el rango se
    # comiera el resto del documento. Daba 14 falsos positivos: las entidades
    # estaban en <p> del cuerpo, donde son CORRECTAS. Con awk se recorta el
    # bloque de verdad, valga en una linea o en varias.
    # Y pasa antes por strip_pre, como S3.1: una pagina que inlinea
    # documentacion cita ejemplos de JSON-LD dentro de un <pre>, y el awk los
    # tomaba por bloques reales. Mismo error que con los href y con el mojibake:
    # tratar texto inlineado como si fuera marcado.
    if strip_pre "$f" | awk '/application\/ld\+json/ { inld=1 }
            inld {
              l=$0
              if (match(l, /application\/ld\+json"?>/)) l=substr(l, RSTART+RLENGTH)
              if (match(l, /<\/script>/)) { print substr(l,1,RSTART-1); inld=0 } else print l
            }' | grep -qE '&(amp|mdash|ndash|middot|rarr|larr|rsquo|lsquo|iquest|aacute|eacute|iacute|oacute|uacute|ntilde);'; then
      bad "S2.7 entidades HTML dentro del JSON-LD (Google las lee literales): $p"; LD_ENT=1
    fi
  fi
done
[ "$T_MISS" -eq 0 ] && [ "$T_BRAND" -eq 0 ] && ok "S2.1 todas con <title> y con termino, no solo marca"
[ "${ZOOM_BAD:-0}" -eq 0 ] && ok "S2.10 ninguna bloquea el zoom"
[ "${TEL_BAD:-0}" -eq 0 ] && ok "S2.11 todo telefono visible es un enlace tel:"
[ "${TIPO_BAD:-0}" -eq 0 ] && ok "S2.12 ninguna declara Article y TechArticle a la vez"
[ "$D_MISS" -eq 0 ] && [ "$D_LONG" -eq 0 ] && ok "S2.2 todas con description dentro de limite"
[ "$C_MISS" -eq 0 ] && ok "S2.3 todas con canonical"
[ "$OG_MISS" -eq 0 ] && ok "S2.4 todas con Open Graph completo"
[ "$H1_BAD" -eq 0 ] && ok "S2.5 todas con exactamente un <h1>"
[ "$LANG_BAD" -eq 0 ] && ok "S2.6 todas con lang"
[ "$LD_ENT" -eq 0 ] && ok "S2.7 JSON-LD sin entidades crudas"

DUP="$(sort "$TITLES_FILE" | uniq -d)"
if [ -n "$DUP" ]; then
  echo "$DUP" | while read -r x; do echo "  [FAIL] S2.8 <title> duplicado: $x"; done
  FAIL=$((FAIL+1))
else
  ok "S2.8 ningun <title> duplicado"
fi
rm -f "$TITLES_FILE"

# =============================================================================
sec "S3 · GRAFO DE ENLACES"
# =============================================================================

BROKEN=0
for p in $PAGES; do
  d="$(dirname "$ROOT/$p")"
  # while-read y no `for`: un href puede contener espacios (el favicon es un
  # data: URI con SVG dentro) y el for lo partia en trozos, generando 17 falsos
  # positivos por pagina. data:, javascript: y las absolutas se descartan antes.
  # ⚠️ `cmd | while read` corre el bucle en una SUBSHELL: los `bad` de dentro
  # imprimian pero NO incrementaban el contador del padre, y BROKEN volvia a 0
  # al salir. Resultado: 21 fallos impresos, "FAIL: 2" en el resumen y un
  # "[ ok ] cero enlaces rotos" JUSTO DEBAJO de los 21. Un resumen que
  # contradice lo que acaba de imprimir es peor que no tener resumen.
  # Con `done < <(...)` el bucle corre en el shell padre y las cuentas valen.
  while IFS= read -r h; do
    tgt="${h%%#*}"; tgt="${tgt%%\?*}"
    [ -z "$tgt" ] && continue
    # Tercer sitio donde vivia la regla de resolucion, y el unico que quedaba:
    # probaba "$d/$tgt" y, si fallaba, "$ROOT$tgt", ninguno de los dos con la
    # convencion de fichero plano. Por eso kine daba 310 "enlaces rotos" hacia
    # paginas que existen (/a-propos -> a-propos.html). Ahora despacha por si la
    # ruta es absoluta o relativa y deja la CONVENCION a resolver_ruta, que es
    # el unico sitio donde esa regla esta escrita.
    # Sin `$( )`: son ~1700 llamadas. Ver la cabecera de `resolver_ruta`.
    case "$tgt" in
      /*) resolver_ruta "$ROOT$tgt" >/dev/null ;;
      *)  resolver_ruta "$d/$tgt"   >/dev/null ;;
    esac
    cand="$RUTA_RESUELTA"
    [ -e "$cand" ] || { bad "S3.1 enlace roto en $p -> $h"; BROKEN=1; }
  done < <(strip_pre "$ROOT/$p" | grep -oE 'href="[^"#?][^"]*"' | sed 's/href="//;s/"$//' \
           | grep -vE '^(https?:|mailto:|tel:|data:|javascript:|//|#)' | sort -u)
done
[ "$BROKEN" -eq 0 ] && ok "S3.1 cero enlaces internos rotos"

# S3.2 huerfanas: indexables sin ni un enlace entrante desde el cuerpo de otra pagina.
# Una pagina que solo cuelga del nav no tiene senal interna; y una sin NADA es
# invisible salvo por el sitemap.
# Se RESUELVE cada enlace relativo a su pagina de origen antes de comparar.
# ⚠️ La primera version comparaba la ruta completa ("agents/x/") contra el href
# tal cual, asi que solo veia los enlaces escritos desde la raiz. Un enlace
# vecino (href="x/") o hacia arriba (href="../x/") no contaba, y daba huerfana
# una pagina con dos enlaces entrantes reales. Peor todavia: en sentido
# contrario CALLABA, porque bastaba un enlace desde la home para dar por buena
# cualquier pagina. Un check de huerfanas que no resuelve rutas no sirve.
LINKMAP="$(mktemp 2>/dev/null || echo "$ROOT/.audit-links.tmp")"
: > "$LINKMAP"
for p in $PAGES; do
  d="$(dirname "$ROOT/$p")"
  strip_pre "$ROOT/$p" | grep -ohE 'href="[^"#?][^"]*"' | sed 's/href="//;s/"$//' \
    | grep -vE '^(https?:|mailto:|tel:|data:|javascript:|//|#)' \
    | while IFS= read -r h; do
        tgt="${h%%#*}"; tgt="${tgt%%\?*}"
        [ -z "$tgt" ] && continue
        case "$tgt" in
          /*) cand="$ROOT$tgt" ;;
          *)  cand="$d/$tgt" ;;
        esac
          # ⚠ Aqui solo se resolvia "algo/" -> "algo/index.html". Con URLs SIN
          #    barra final -la forma que este cliente ya tiene indexada- "/contacto"
          #    quedaba como directorio y nadie contaba su enlace entrante: 40
          #    huerfanas en un sitio bien enlazado. Se aceptan LAS DOS.
          # La misma regla que el sitemap, y por eso la misma funcion: aqui vivia
          # duplicada -solo la mitad, la de la barra final- y por eso el grafo de
          # enlaces de kine daba 310 rotos que no lo estaban.
          resolver_ruta "$cand" >/dev/null; cand="$RUTA_RESUELTA"
        rel_a_root "$cand"; r="$RUTA_REL"
        [ -n "$r" ] && echo "$r|$p"
      done >> "$LINKMAP"
done
ORPH=0
for p in $PAGES; do
  grep -q 'name="robots"[^>]*noindex' "$ROOT/$p" && continue
  [ "$p" = "index.html" ] && continue
  n=$(grep -c "^$p|" "$LINKMAP" 2>/dev/null)
  self=$(grep -c "^$p|$p$" "$LINKMAP" 2>/dev/null)
  n=$((n - self))
  if [ "$n" -lt 1 ]; then bad "S3.2 huerfana (0 enlaces entrantes, indexable): $p"; ORPH=1
  elif [ "$n" -lt 2 ]; then warn "S3.2 solo $n enlace entrante (el PASO 0 pide 2): $p"; fi
done
rm -f "$LINKMAP"
[ "$ORPH" -eq 0 ] && ok "S3.2 ninguna pagina indexable esta huerfana"

# =============================================================================
sec "S4 · INTEGRIDAD Y CODIFICACION"
# =============================================================================
# Se escanea SOLO lo que se despliega. Los documentos del repo (CLAUDE.md y
# companyia) quedan fuera a proposito: uno de ellos DOCUMENTA el patron de
# mojibake, y se marcaba a si mismo como corrupto. Un auditor que da falsos
# positivos se acaba ignorando, que es peor que no tenerlo.
DEPLOYED="$PAGES"
for f in styles.css components.css script.js llms.txt robots.txt sitemap.xml AGENTS.md; do
  [ -f "$ROOT/$f" ] && DEPLOYED="$DEPLOYED
$f"
done
# Las paginas /copy/ quedan fuera: inlinean codigo fuente verbatim y pueden
# contener el propio patron de mojibake (audit.sh lo lleva dentro para
# detectarlo). Un fichero que DOCUMENTA el patron se marca a si mismo.
MOJI=""
for f in $DEPLOYED; do
  case "$f" in */copy/index.html) continue ;; esac
    # 19-ago-2026 · LA LISTA ERA DE 8 SECUENCIAS Y SE DEJABA FUERA LA MITAD DE
    # LAS VOCALES. Tenia `Ã©` (e) y `Ã±` (n) pero NO `Ã­` (i) ni `Ã¡` `Ã³` `Ãº`,
    # asi que el mojibake de «clinica» y «politica» -las dos palabras mas
    # frecuentes de nuestras webs de cliente- pasaba en VERDE. Lo encontro el
    # banco de pruebas el dia que se escribio, no una web rota.
    # NO se usa un patron ancho tipo `Ã.`: en portugues `Ã` mayuscula es LEGITIMA
    # (IRMAOS, ORGAOS) y marcaria una tienda entera en portugues. La lista explicita
    # cubre es/fr/pt y no tiene falsos positivos; hay un caso verde que lo prueba.
    grep -qE 'Ã¡|Ã©|Ã­|Ã³|Ãº|Ã±|Ã§|Ã£|Ãµ|Ã¢|Ãª|Ã´|Ã |Ã¨|Ã‚|â€|â‚¬|Â»|Â«|ï¿½' "$ROOT/$f" 2>/dev/null && MOJI="$MOJI $f"
done
[ -n "$MOJI" ] && bad "S4.1 mojibake en:$MOJI" || ok "S4.1 sin mojibake en lo desplegable"

# 🔴 18-ago-2026 · SE CONTABAN LAS ETIQUETAS DENTRO DE LOS COMENTARIOS.
#    Un comentario HTML que EXPLICA la regla hacia fallar a la pagina que la
#    cumplia: 3 abren, 2 cierran, y la tercera estaba en prosa dentro de un
#    comentario. Es la trampa §43 en este fichero: cuanto mejor documentas un
#    check, mas facil es que se acuse a si mismo. Se quitan los comentarios
#    antes de contar, igual que hacen qa-maestro.pl y audit-vs-spec.pl.
UNB=0
for p in $PAGES; do
  sincom=$(perl -0777 -pe 's/<!--.*?-->//gs' "$ROOT/$p")
  o=$(printf '%s' "$sincom" | grep -oE '<section' | wc -l | tr -d ' ')
  c=$(printf '%s' "$sincom" | grep -oE '</section>' | wc -l | tr -d ' ')
  [ "$o" = "$c" ] || { bad "S4.2 <section> descuadrado en $p ($o abren, $c cierran)"; UNB=1; }
done
[ "$UNB" -eq 0 ] && ok "S4.2 <section> equilibrado en todas"

# =============================================================================
sec "S5 · CSS Y RENDIMIENTO"
# =============================================================================
CSSMISS=0
for p in $PAGES; do
  grep -q 'rel="stylesheet"' "$ROOT/$p" || { bad "S5.1 sin hoja de estilos (saldria SIN ESTILO): $p"; CSSMISS=1; continue; }
  for href in $(grep -oE '<link rel="stylesheet" href="[^"]+"' "$ROOT/$p" | sed 's/.*href="//;s/"//'); do
    case "$href" in http*|//*) continue ;; esac
    # Dos convenciones VALIDAS, no una:
    #   ../styles.css  -> relativa a la pagina  (nuestro sitio)
    #   /styles.css    -> relativa a la RAIZ    (sitios servidos desde su dominio)
    # La primera version solo entendia la relativa y marcaba 81 fallos en un
    # sitio correcto. El auditor traia un supuesto que nunca declaro.
    # TERCERA convencion, y la que faltaba: el SELLO DE CACHE. 07-trampas.md §15
    # obliga a servir el CSS y el JS con `?v=...` —si no, el navegador sirve la
    # hoja vieja y un getComputedStyle miente—. Este auditor resolvia el href
    # entero contra el disco, asi que `styles.css?v=7` no existia como fichero y
    # marcaba FAIL. En el sitio de prueba del 18-ago-2026 salieron 12 FAIL, los
    # 12 falsos: la skill exigia el sello y su propio auditor lo castigaba.
    # No se habia visto nunca porque ninguno de los 5 repos sellaba su CSS.
    href="${href%%[?]*}"
    href="${href%%[#]*}"
    case "$href" in
      /*) t="$ROOT$href" ;;
      *)  t="$(dirname "$ROOT/$p")/$href" ;;
    esac
    [ -f "$t" ] || { bad "S5.1 hoja de estilos con prefijo mal (no resuelve): $p -> $href"; CSSMISS=1; }
  done
done
[ "$CSSMISS" -eq 0 ] && ok "S5.1 todas cargan sus hojas de estilo y resuelven"

# S5.2 solo transform y opacity se componen en GPU. Animar box-shadow, width,
# height, top/left o colores repinta en el hilo principal sin parar.
NOCOMP=0
for css in $(find "$ROOT" -maxdepth 2 -name '*.css' 2>/dev/null | grep -vE "/($(echo $EXCLUDE_DIRS | tr ' ' '|'))/"); do
  # La propiedad puede ir tras "0% {" en la misma linea, no solo al principio.
  # Anclado a ^ se escapaba `0% { box-shadow: ... }` -- que es justo como se
  # escriben los keyframes cortos, y como estaba el fallo real de components.css.
  #
  #  🔴 26-ago-2026 · EL RANGO `/@keyframes/,/^}/` NO CIERRA EN UN KEYFRAMES DE
  #     UNA SOLA LINEA, Y SE TRAGA EL RESTO DEL FICHERO.
  #     Medido sobre una web de cliente VIVA cuyo unico @keyframes es correcto
  #     -solo opacity y transform, en una linea-: como no hay ningun `}` a
  #     principio de linea, el rango siguio hasta el siguiente que encontro y
  #     capturo **36 lineas** en vez de 1. Dentro venia una regla de menu movil
  #     con `margin` y `padding`, y el auditor acuso a la animacion de animar
  #     margenes. El sitio estaba bien.
  #     Y el numero que daba despistaba ademas: `grep -n` numera las lineas del
  #     EXTRACTO, no las del CSS, asi que el fallo señalaba la linea 30 de un
  #     fichero donde el @keyframes esta en la 403.
  #     Ahora se cuentan las llaves y el bloque termina cuando la profundidad
  #     vuelve a cero. Sin escapes: `cnt()` compara caracteres, porque una llave
  #     dentro de una expresion regular de awk es ambigua.
  hits=$(awk '
    function cnt(s, ch,   n, i) { n = 0
      for (i = 1; i <= length(s); i++) if (substr(s, i, 1) == ch) n++
      return n }
    /@keyframes/ { dentro = 1; prof = 0 }
    dentro { print
      prof += cnt($0, "{") - cnt($0, "}")
      if (prof <= 0) dentro = 0 }
  ' "$css" | grep -nE '(^|[{;[:space:]])(box-shadow|width|height|top|left|right|bottom|margin|padding|background-color|filter)[[:space:]]*:' | head -5)
  [ -n "$hits" ] && { bad "S5.2 @keyframes anima propiedades no compuestas en $(basename $css): $(echo "$hits" | tr '\n' ' ' | cut -c1-120)"; NOCOMP=1; }
done
[ "$NOCOMP" -eq 0 ] && ok "S5.2 las animaciones solo tocan transform/opacity"

# S5.3 toda animacion necesita su salida de reduced-motion.
RM=0
for css in $(find "$ROOT" -maxdepth 2 -name '*.css' 2>/dev/null | grep -vE "/($(echo $EXCLUDE_DIRS | tr ' ' '|'))/"); do
  nk=$(grep -c '@keyframes' "$css")
  [ "$nk" -eq 0 ] && continue
  if grep -q 'prefers-reduced-motion' "$css"; then
    ok "S5.3 $(basename $css) tiene salida de prefers-reduced-motion ($nk animaciones)"
  else
    bad "S5.3 $(basename $css) define $nk @keyframes y NO tiene bloque prefers-reduced-motion"; RM=1
  fi
done
[ "$RM" -eq 0 ] || true

# S5.4 CSS muerto: clases definidas y usadas en CERO paginas.
# Anadido el 2-ago tras encontrar 20 reglas huerfanas de un directorio borrado
# semanas antes. CSS muerto no falla nunca: solo pesa, y sobre todo confunde a
# quien lo lea despues -- describe una estructura que ya no existe.
# Es `warn` y no `bad`: hay clases legitimas que solo aparecen desde JS.
# Se construye UNA sola vez el inventario de clases usadas, en lugar de hacer
# un grep por clase y pagina (eran ~7.800 greps y tardaba minutos).
USEDCLS="$(for p in $PAGES; do grep -ohE 'class="[^"]*"' "$ROOT/$p"; done \
  | sed 's/class="//;s/"$//' | tr ' ' '\n' | sort -u)"
QQ="\"'"
JSCLS="$(cat "$ROOT"/*.js 2>/dev/null | grep -ohE "[$QQ][a-zA-Z][a-zA-Z0-9_-]*[$QQ]" | tr -d "$QQ" | sort -u)"
DEADCSS=""; NDEAD=0
for cls in $(find "$ROOT" -maxdepth 1 -name '*.css' -exec grep -ohE '^\.[a-zA-Z][a-zA-Z0-9_-]*' {} \; | sed 's/^\.//' | sort -u); do
  echo "$USEDCLS" | grep -qx "$cls" && continue
  echo "$JSCLS"   | grep -qx "$cls" && continue   # la anade el JS en runtime
  # Y puede estar DORMIDA, no muerta: el generador la emite solo para ciertos
  # specs (p.ej. un aviso que sale unicamente si el item tiene ese campo).
  # Sin esta linea el check pide borrar CSS que hace falta -- el mismo error de
  # barrido que ya ha costado tres diagnosticos falsos en este proyecto.
  grep -qs "\b$cls\b" "$ROOT"/*.ps1 "$ROOT"/*.py "$ROOT"/*.sh 2>/dev/null && continue
  NDEAD=$((NDEAD+1)); DEADCSS="$DEADCSS .$cls"
done
if [ "$NDEAD" -gt 0 ]; then
  warn "S5.4 $NDEAD clase(s) definidas y sin uso en ninguna pagina:$(echo $DEADCSS | cut -c1-160)"
else
  ok "S5.4 sin CSS muerto"
fi

# =============================================================================
if [ "$LIVE" -eq 1 ]; then
sec "S6 · ENTREGA EN PRODUCCION"
  if [ -z "$BASE_URL" ]; then
    skip "S6 sin --url ni CONF_BASE_URL: no se puede comprobar produccion"
  else
    # S6.0 · Disco vs produccion. Se separa A PROPOSITO de S6.1.
    # ⚠️ Antes S6.1 recorria el sitemap de DISCO contra produccion, asi que una
    # pagina legitimamente en staging ponia --live en ROJO. Un gate que se pone
    # rojo por trabajo pendiente de desplegar ensena a ignorarlo, que es el peor
    # resultado posible para un gate. Ahora:
    #   S6.0 = que hay en disco y aun no en produccion  -> aviso, no fallo
    #   S6.1 = que sirve produccion de verdad           -> fallo si algo rompe
    SM_LIVE="$(curl -s "$BASE_URL/sitemap.xml" | grep -oE '<loc>[^<]+' | sed 's/<loc>//')"
    PEND=""
    for u in $SM_URLS; do echo "$SM_LIVE" | grep -qx "$u" || PEND="$PEND $u"; done
    if [ -n "$PEND" ]; then
      warn "S6.0 en disco y aun NO en produccion (pendiente de desplegar):$PEND"
    else
      ok "S6.0 disco y produccion coinciden: nada pendiente de desplegar"
    fi

    L200=0; NL=0
    for u in $SM_LIVE; do
      NL=$((NL+1))
      c=$(curl -s -o /dev/null -w "%{http_code}" "$u")
      [ "$c" = "200" ] || { bad "S6.1 $c en $u"; L200=1; }
    done
    [ "$L200" -eq 0 ] && ok "S6.1 las $NL URLs del sitemap EN VIVO responden 200"

    # Hay que PEDIR la compresion o el servidor no la manda, y el aviso saldria
    # siempre aunque este bien configurada.
    H="$(curl -s -D - -o /dev/null -H 'Accept-Encoding: gzip, br' "$BASE_URL/")"
    echo "$H" | grep -qi '^cache-control:' && ok "S6.2 el HTML envia Cache-Control" || bad "S6.2 el HTML NO envia Cache-Control (cada visita recurrente revalida todo)"
    echo "$H" | grep -qi '^content-encoding:' && ok "S6.3 compresion activa" || warn "S6.3 sin Content-Encoding (comprueba que el server comprime)"
    for hh in x-content-type-options referrer-policy; do
      echo "$H" | grep -qi "^$hh:" && ok "S6.4 cabecera $hh presente" || warn "S6.4 falta la cabecera $hh"
    done

    CSSU="$(grep -oE '<link rel="stylesheet" href="[^"]+"' "$ROOT/index.html" | head -1 | sed 's/.*href="//;s/"//')"
    if [ -n "$CSSU" ]; then
      HC="$(curl -s -D - -o /dev/null "$BASE_URL/$CSSU")"
      echo "$HC" | grep -qi '^cache-control:' && ok "S6.5 los assets envian Cache-Control" || bad "S6.5 los assets NO envian Cache-Control"
    fi

    for MF in llms.txt AGENTS.md; do
      curl -s -f -o /dev/null "$BASE_URL/$MF" 2>/dev/null || { warn "S6.6 $BASE_URL/$MF no responde (¿sin desplegar?)"; continue; }
      LM=0
      for u in $(curl -s "$BASE_URL/$MF" | grep -oE "$BASE_URL[^ )\"<>*\`]+" | sed 's/[.,:]$//' | sort -u); do
        c=$(curl -s -o /dev/null -w "%{http_code}" "$u")
        [ "$c" = "200" ] || { bad "S6.6 $MF EN VIVO apunta a $c: $u"; LM=1; }
      done
      [ "$LM" -eq 0 ] && ok "S6.6 todas las URLs de $MF en vivo responden 200"
    done
  fi
else
  sec "S6 · ENTREGA EN PRODUCCION"
  skip "S6 no ejecutado (pasa --live para comprobar cache, cabeceras y URLs en vivo)"
fi

# =============================================================================
echo
echo "==========================================================="
echo " FAIL: $FAIL   ·   warn: $WARN"
if [ "$FAIL" -eq 0 ]; then
  echo " == VERDE: el sitio pasa la auditoria =="
  echo "==========================================================="
  exit 0
else
  echo " == ROJO: $FAIL fallo(s). No desplegar sin arreglarlos. =="
  echo "==========================================================="
  exit 1
fi
