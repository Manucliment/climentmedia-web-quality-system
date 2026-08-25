#!/usr/bin/env bash
# =============================================================================
#  Banco de `audit-vs-source.sh` — el gate de MIGRACION.
#
#  🔴 POR QUE EXISTE, y por que llega tarde.
#  Este programa contesta «¿que tenian ellos que nosotros no?», y cerro la
#  migracion de site-c.example diciendo **«2 huecos, y los dos son los
#  contenedores de GTM»** con el VIDEO DEL HERO perdido. Enumeraba imagenes y
#  llamaba a eso medios. El 17-ago se le anadio el bloque `5-bis` (video, audio
#  e <iframe>) **y no tenia ni un caso de prueba** -- o sea, el arreglo del
#  agujero venia con el mismo agujero dentro.
#
#  Los fixtures se arman aqui, en un temporal, y el programa se apunta a ellos
#  con `AUDIT_ROOT`. Nada de copiar el script dentro del fixture: dos copias
#  divergen el primer dia.
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
REF="$(cd "$D/.." && pwd)"
GATE="$REF/audit-vs-source.sh"
ok=0; ko=0
T="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/avo-$$")"
trap 'rm -rf "$T"' EXIT

[ -f "$GATE" ] || { echo "  no encuentro audit-vs-source.sh"; exit 2; }

# arma <nombre>  -> crea $T/<nombre> con el minimo que el gate exige
arma() {
  local n="$1"; rm -rf "$T/$n"
  mkdir -p "$T/$n/_migrate/origen/src/routes" "$T/$n/assets" "$T/$n/zones"
  : > "$T/$n/index.html"
  # rutas: el bloque 1 pide un .tsx por pagina. Con una basta.
  echo 'export default function Index(){return null}' > "$T/$n/_migrate/origen/src/routes/index.tsx"
  # cities.jsonl vacio + 0 zonas: el bloque 1 compara los dos y cuadra en 0.
  mkdir -p "$T/$n/_spec"; : > "$T/$n/_spec/cities.jsonl"
}

corre() { OUT="$(AUDIT_ROOT="$T/$1" bash "$GATE" "$T/$1/_migrate/origen" 2>&1)"; RC=$?; }

# dice <etiqueta> <SI|NO> <literal> <fixture>
dice() {
  local eti="$1" quiero="$2" lit="$3"; corre "$4"
  local hay=NO; printf '%s' "$OUT" | grep -qF -- "$lit" && hay=SI
  if [ "$hay" = "$quiero" ]; then
    printf '  OK    %-54s %s "%s"\n' "$eti" "$quiero" "$lit"; ok=$((ok+1))
  else
    printf '  MAL   %-54s esperaba %s y salio %s\n' "$eti" "$quiero" "$hay"; ko=$((ko+1))
    printf '%s\n' "$OUT" | grep -i "medio\|iframe" | head -4 | sed 's/^/          /'
  fi
}

echo "==============================================================================="
echo "  GATE DE MIGRACION · el bloque 5-bis (medios que no son imagenes) · 17-ago-2026"
echo "==============================================================================="
echo
echo "== EL CASO ROJO: el video que se perdio de verdad"
# Reproduce site-c.example: su Elementor guardaba el video en un blob de
# ajustes, NO en un <video src>. Un barrido de `<video>` habria salido limpio.
arma perdido
mkdir -p "$T/perdido/_migrate/origen/media"
: > "$T/perdido/_migrate/origen/media/tora-video-home-02.mp4"
cat > "$T/perdido/_migrate/origen/paginas-home.html" <<'H'
<div data-settings='{"background_video_link":"https:\/\/ejemplo.test\/wp-content\/uploads\/2025\/03\/tora-video-home-02.mp4"}'></div>
H
dice "caza el video que falta"                SI "FALTA medio"          perdido
dice "y lo nombra"                            SI "tora-video-home-02"   perdido

echo
echo "== EL CASO VERDE: el mismo, ya repuesto"
# No es otro fixture: es el rojo con el video puesto en NUESTRO arbol.
cp -r "$T/perdido" "$T/repuesto"
mkdir -p "$T/repuesto/assets/media"
: > "$T/repuesto/assets/media/tora-video-home-02.mp4"
dice "deja de reclamarlo"                     NO "FALTA medio"          repuesto
dice "y lo da por bueno"                      SI "OK      medio"        repuesto

echo
echo "== LOS DOS CONTROLES QUE DECIDEN SI EL CHECK VALE"
# 🔴 CONTROL 1 · JS minificado. En mi primera corrida contra site-c, la expresion
#    casaba `t.touchEvents.mov`, `a.mov`, `i.mov`, `r.mov`: CUATRO medios
#    inventados. Un gate que reclama ficheros que no existen se desactiva.
arma jsmin
cat > "$T/jsmin/_migrate/origen/src/bundle.js" <<'J'
var t={};t.touchEvents.mov=1;var a={};a.mov=2;i.mov=3;r.mov=4;e.wav=5;
J
dice "no inventa medios desde JS minificado"  NO "FALTA medio"          jsmin
dice "y dice que su origen no traia ninguno"  SI "no trae ni video"     jsmin

# 🔴 CONTROL 2 · el mas peligroso, y me mordio. `_migrate/` contiene la copia de
#    SU web, asi que buscando en el repo entero **todo medio suyo se encuentra
#    siempre** y el gate sale verde por definicion. En mi primera version
#    `tora-video-home-02.mp4` -el que FALTABA- salio «ok» por esto.
#    Este fixture es exactamente ese caso: el fichero SOLO existe en _migrate/.
dice "el fichero en _migrate NO cuenta como nuestro" SI "FALTA medio"   perdido

echo
echo "== IFRAMES: la otra mitad del punto ciego"
# Un mapa incrustado o un reproductor se pierden igual de callados que un video.
arma mapa
cat > "$T/mapa/_migrate/origen/src/contacto.tsx" <<'H'
<iframe src="https://www.google.com/maps/embed?pb=!1m18" loading="lazy"></iframe>
H
dice "caza el mapa incrustado que falta"      SI "FALTA iframe"         mapa
cp -r "$T/mapa" "$T/mapa-ok"
echo '<iframe src="https://www.google.com/maps/embed?pb=!1m18"></iframe>' > "$T/mapa-ok/index.html"
dice "y calla cuando esta"                    NO "FALTA iframe"         mapa-ok

echo
echo "-----------------------------------------------------------------"
printf "  OK %d   ·   MAL %d\n" "$ok" "$ko"
[ "$ko" -eq 0 ] && echo "  El gate de migracion ya no es ciego a los medios." \
                || echo "  🔴 Hay casos MAL: no se migra nada con esto asi."
exit "$ko"
