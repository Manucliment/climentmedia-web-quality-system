#!/usr/bin/env bash
# =============================================================================
#  audit-vs-source.sh - INVENTARIO CONTRA INVENTARIO
# =============================================================================
#  Uso:  bash _migrate/audit-vs-source.sh [_migrate/origen]
#
#  ⚠️ POR QUE ESTE GATE Y NO UNA LISTA DE COMPROBACION
#  Los checklists comprueban lo que uno ya sabe mirar. En Site A a Domicile eso
#  dejo pasar, uno detras de otro:
#    · 13 imagenes de 19, incluido el logotipo
#    · las 5 fichas del equipo
#    · og:image en las 18 paginas
#    · GTM, GA4 y Google Ads enteros -> conversion midiendo cero
#    · 9 de sus 11 eventos, entre ellos phone_click
#    · un formulario entero (el de candidatura)
#  Ninguno lo detecto un gate. Los dos ultimos los encontro Manuel preguntando.
#
#  La diferencia: un checklist responde "¿esta lo que espero?". Esto responde
#  "¿que tenian ellos que nosotros no?". Enumera desde SU LADO, asi que detecta
#  categorias enteras que a mi ni se me habian ocurrido.
#
#  ⚠️ Se compara contra SU CODIGO, no contra su web publicada. Su web deja de
#  ser accesible en cuanto se mueve el DNS; su codigo es permanente y ademas
#  dice cosas que el render esconde.
#
#  Salida: lineas OK / FALTA / REVISAR y un codigo de salida != 0 si falta algo.
# =============================================================================
set -u
# 17-ago-2026 · `AUDIT_ROOT` existe para que este programa se pueda PROBAR.
# El repo se deducia de donde vive el script (`$0/..`), asi que la unica forma
# de correrlo sobre un fixture era copiar el script dentro del fixture -- y dos
# copias divergen el primer dia. Con la variable, el banco apunta a un arbol de
# mentira y el fichero sigue siendo uno. En uso normal no se toca.
ROOT="${AUDIT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SRC="${1:-$ROOT/_migrate/origen}"
cd "$ROOT"
[ -d "$SRC/src" ] || { echo "  Falta su codigo en $SRC/src"; exit 2; }

fail=0
ok()    { printf "  OK      %-30s %s\n" "$1" "${2:-}"; }
miss()  { printf "  🔴 FALTA %-29s %s\n" "$1" "${2:-}"; fail=$((fail+1)); }
warn()  { printf "  ⚠️ REVISAR %-27s %s\n" "$1" "${2:-}"; }

HTML=$(ls *.html zones/*.html 2>/dev/null)

echo "=== 1. Paginas ==="
for f in "$SRC"/src/routes/*.tsx; do
  b=$(basename "$f" .tsx)
  case "$b" in __root) continue;; zones.\$city) continue;; index) t="index.html";; *) t="$b.html";; esac
  [ -f "$t" ] && ok "$b" || miss "$b" "no existe $t"
done
n=$(ls zones/*.html 2>/dev/null | wc -l)
c=$(grep -c . _spec/cities.jsonl 2>/dev/null || echo 0)
[ "$n" = "$c" ] && ok "paginas de ciudad" "$n" || miss "paginas de ciudad" "$n frente a $c ciudades"

echo "=== 2. Eventos de medicion ==="
for e in $(grep -rhoP 'track\("[a-z_]+"|data-event="[a-z_]+"|event:\s*"[a-z_]+"' "$SRC/src" --include='*.tsx' --include='*.ts' \
           | sed 's/track("//; s/data-event="//; s/event: *"//; s/"//' | sort -u); do
  if grep -qE "data-event=\"$e\"|data-thanks=\"$e\"" $HTML 2>/dev/null || grep -qE "'$e'" script.js 2>/dev/null
  then ok "evento $e"; else miss "evento $e" "su web lo dispara y la nuestra no"; fi
done

echo "=== 3. Terceros y contenedores ==="
# ⚠️ Fuera los marcadores de posicion. Su site.ts lleva `// e.g. "GTM-XXXXXXX"`
# en un comentario, y sin este filtro el gate reclama un contenedor inventado.
# Un gate que da falsas alarmas se acaba ignorando, que es peor que no tenerlo.
for id in $(grep -rhoE 'GTM-[A-Z0-9]+|AW-[0-9]+|G-[A-Z0-9]{8,}' "$SRC/src" 2>/dev/null \
            | grep -vE 'X{4,}|0{6,}' | sort -u); do
  grep -q "$id" $HTML 2>/dev/null && ok "id $id" || miss "id $id" "declarado en su codigo"
done
gtm=$(grep -rhoE 'GTM-[A-Z0-9]+' "$SRC/src" 2>/dev/null | head -1)
if [ -n "$gtm" ]; then
  # Los AW-/G- casi nunca estan en su repo: viven DENTRO del contenedor.
  for id in $(curl -s --max-time 25 "https://www.googletagmanager.com/gtm.js?id=$gtm" \
              | grep -oE 'AW-[0-9]+|G-[A-Z0-9]{8,}' | sort -u); do
    grep -q "$id" $HTML 2>/dev/null && ok "en contenedor $id" \
      || warn "en contenedor $id" "vive dentro de GTM; basta con que GTM cargue"
  done
fi

echo "=== 4. Formularios ==="
sf=$(grep -rl '<form' "$SRC/src" --include='*.tsx' 2>/dev/null | wc -l)
mf=$(grep -l '<form' $HTML 2>/dev/null | wc -l)
[ "$mf" -ge "$sf" ] && ok "formularios" "$mf paginas (suyos: $sf componentes)" \
  || miss "formularios" "$mf frente a $sf"
grep -rq 'mailto:' "$SRC/src" --include='*.tsx' 2>/dev/null && \
  warn "mailto en su codigo" "sus formularios enviaban por mailto: comprobar que el nuestro NO"

echo "=== 5. Imagenes ==="
# ⚠️ Solo extensiones de imagen reales. Lovable deja ficheros `*.asset.json`
# junto a cada imagen, y sin este filtro el gate pide "entree.jpg.asset.json".
si=$(grep -rhoP '(?<=from ")@/assets/[^"]+\.(jpg|jpeg|png|webp|svg)(?=")' "$SRC/src" 2>/dev/null | sed 's|.*/||' | sort -u)
for img in $si; do
  b="${img%.*}"
  ls assets/ 2>/dev/null | grep -qE "^${b}(-[A-Za-z0-9_-]+)?\.[a-z]+$" && ok "img $img" || miss "img $img"
done

echo "=== 5-bis. Medios que NO son imagenes ==="
# 🔴 17-ago-2026 · ESTE BLOQUE NACE DE UN VIDEO PERDIDO Y DE UN GATE QUE DIJO
#    QUE NO FALTABA NADA.
#
#    La portada de site-c.example tenia un VIDEO DE FONDO en el hero
#    (`tora-video-home-02.mp4`, 2,9 MB, autoplay/muted/loop). Se migro la web,
#    el gate de migracion cerro con «2 huecos, y los dos son los contenedores
#    de GTM», y el video NO ESTABA. Nadie lo noto hasta que Manuel pregunto por
#    el, ocho dias despues de publicar.
#
#    La causa: el bloque 5 enumera IMAGENES. Video, audio y los <iframe> -mapas,
#    reproductores, widgets de resenas- no los contaba NADIE. Comprobado el
#    mismo dia en los tres sitios donde podia estar: este generico, el de site-c y
#    el de site-a. Cero menciones a video en los tres.
#
# ⚠️ Y LA PARTE QUE HAY QUE LLEVARSE: **el medio que una pagina muestra no
#    siempre esta en una etiqueta de medio.** El video de site-c NO estaba en un
#    `<video src>`: vivia dentro de los ajustes de Elementor, como
#    `background_video_link&quot;:&quot;https://.../tora-video-home-02.mp4`.
#    Un barrido de `<video>` habria salido limpio y habriamos cerrado igual de
#    tranquilos. Por eso aqui se buscan las EXTENSIONES en cualquier sitio del
#    origen -atributos, JSON incrustado, CSS- y no las etiquetas.
# ⚠️ DOS DETALLES QUE PARECEN DE ESTILO Y DECIDEN SI EL CHECK VALE. Los dos
#    salieron al probarlo contra site-c, y sin ellos el bloque es decorativo:
#
#    1 · EL NOMBRE VA PRECEDIDO DE `/`. Sin exigirlo, la expresion casa dentro
#        de JavaScript minificado: `t.touchEvents.mov`, `a.mov`, `i.mov`,
#        `r.mov`. Cuatro medios inventados en la primera corrida. Un medio de
#        verdad SIEMPRE vive en una ruta.
#    2 · NUESTRO ARBOL SE MIRA SIN `_migrate/`. Ahi vive la copia de SU web, asi
#        que buscando en el repo entero **todo medio suyo se encuentra siempre**
#        y el gate sale verde por definicion. En mi primera corrida
#        `tora-video-home-02.mp4` -el que FALTABA- salio «ok» por esto.
#    Y `--binary-files=without-match`, o grep imprime «Binary file … matches» y
#    esa palabra acaba en la lista como si fuera un fichero.
MEDIOS_RE='/[A-Za-z0-9_.-]+\.(mp4|webm|mov|m4v|ogv|mp3|wav|m4a)'
sus_med=$(grep -rhoE --binary-files=without-match "$MEDIOS_RE" "$SRC" 2>/dev/null \
          | sed 's|.*/||' | sort -u)
if [ -z "$sus_med" ]; then
  ok "medios: su origen no trae ni video ni audio"
else
  for m in $sus_med; do
    b="${m%.*}"
    if grep -rqE --binary-files=without-match --exclude-dir=_migrate "${b}\.[a-z0-9]+" \
         . --include='*.html' --include='*.css' --include='*.js' 2>/dev/null \
       || ls assets/ assets/media/ assets/video/ 2>/dev/null | grep -qE "^${b}\."; then
      ok "medio $m"
    else
      miss "medio $m"
    fi
  done
fi
# Los <iframe> son la otra mitad del mismo punto ciego: un mapa incrustado o un
# reproductor se pierden igual de callados que un video. Se compara el DOMINIO,
# no la URL entera: el identificador del mapa cambia y el proveedor no.
sus_ifr=$(grep -rhoE '<iframe[^>]+src="[^"]+"' "$SRC" 2>/dev/null \
          | grep -oE 'src="[^"]+"' | sed 's/src="//;s/"//' | sed 's|https\?://||' \
          | cut -d/ -f1 | sort -u)
for h in $sus_ifr; do
  grep -rq "$h" . --include='*.html' 2>/dev/null && ok "iframe de $h" || miss "iframe de $h"
done

echo "=== 6. Componentes con contenido propio ==="
for c in TrustBand StatsBand FAQ CookieBanner ConversionPopup FloatingWhatsApp; do
  used=$(grep -rl "<$c" "$SRC/src" --include='*.tsx' 2>/dev/null | grep -v "/$c.tsx" | wc -l)
  if [ "$used" = "0" ]; then ok "$c" "su web NO lo usa: no hay que replicarlo"; continue; fi
  # ⚠️ Se detecta por SU TEXTO VISIBLE, no por una clase CSS mia.
  # La primera version buscaba `trust|shield` y daba TrustBand por perdido
  # estando puesto: mis clases no tienen por que llamarse como su componente.
  # Buscar el texto que el usuario ve funciona sea cual sea el marcado.
  case "$c" in
    TrustBand)        p='rapeutes qualifi';;   # ⚠ ASCII: con `.` los acentos fallan (2 bytes)
    StatsBand)        p='data-count';;
    FAQ)              p='faq__box';;
    CookieBanner)     p='cookie-consent';;
    ConversionPopup)  p='conv-popup';;
    FloatingWhatsApp) p='class="fab"';;
  esac
  grep -qE "$p" $HTML 2>/dev/null && ok "$c" || miss "$c" "lo usan en $used sitio(s)"
done

echo "=== 7. Ficheros de sitio ==="
for f in robots.txt sitemap.xml llms.txt favicon.png; do
  [ -f "$f" ] && ok "$f" || miss "$f"
done
grep -q 'og:image' index.html 2>/dev/null && ok "og:image" || miss "og:image"
for f in $HTML; do grep -q 'og:image' "$f" || { miss "og:image en $f"; break; }; done

echo "=== 8. Paginas legales con texto ==="
for l in mentions-legales politique-confidentialite politique-cookies conditions-generales; do
  if [ -f "$l.html" ] && ! grep -q 'Texte en attente' "$l.html"; then ok "$l"
  else miss "$l" "sin el texto del cliente"; fi
done

echo "----------------------------------------------------------"
if [ "$fail" -eq 0 ]; then echo "  SIN HUECOS frente a su codigo."; else echo "  $fail HUECO(S). No se despliega asi."; fi
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
