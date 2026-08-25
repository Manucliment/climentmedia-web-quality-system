#!/usr/bin/env bash
# Compone UNA pagina a partir de los moldes del repertorio.
#   uso: mk-mould.sh <salida.html> 01 06 03 02 09 08 11
# Los ordenes canonicos salen de `09-tipos-de-pagina.md` seccion 2 (las once
# anatomias, por ROL). La tabla que habia en `10-vocabulario` seccion 6 discrepaba
# de esa y se borro: una pregunta con dos respuestas es peor que una sin respuesta.
# Es el CONTROL POSITIVO de `gate-estructura.js`: si el repertorio bien usado no
# pasa el gate, el gate esta mal calibrado.
#
# 🔴 LO PRIMERO QUE HACE ES CORRER `chk-collisions.pl`, Y SI FALLA NO COMPONE.
#    Antes, cada molde traia su `<style>` entero con su propio `.sec__in`, y al
#    pegarlos ganaba el ultimo: la home salia con 4 de 7 secciones a 568px en vez
#    de 1120. La pagina no daba ningun error — solo era mas estrecha. Por eso el
#    aviso que habia aqui ("gana el ultimo, es cosmetico") era falso y ahora es
#    un gate.
set -u
D="$(cd "$(dirname "$0")" && pwd)"
M="$D/../moldes"
OUT="$1"; shift
ORDEN="$*"

if ! perl "$D/chk-collisions.pl" "$M"; then
  echo "ABORTA: los moldes se pisan entre si. No se compone nada." >&2
  exit 1
fi

{
  echo '<!DOCTYPE html><html lang="es"><head><meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width,initial-scale=1">'
  echo '<title>Pagina compuesta con el repertorio de moldes</title>'
  # EL CHASIS, UNA SOLA VEZ Y EL PRIMERO. Es lo que hace que componer sea sumar.
  echo '<style>/* --- _tokens.css --- */'; cat "$M/_tokens.css"; echo '</style>'
  echo '<style>/* --- _base.css --- */';   cat "$M/_base.css";   echo '</style>'
  for t in $ORDEN; do
    n=${t%%:*}
    f=$(ls "$M"/${n}-*.html)
    echo "<style>/* --- molde $n --- */"
    awk '/<style/{f=1;next} /<\/style>/{f=0} f' "$f"
    echo '</style>'
  done
  echo '<style>main{display:block}</style>'
  echo '</head><body>'
  echo '<nav><a href="/">Inicio</a> <a href="/servicios/">Servicios</a> <a href="/contacto/">Contacto</a></nav>'
  echo '<main>'
  # `NN:rol` cambia el data-sec del molde. El que trae de fabrica es un POR
  # DEFECTO: el mismo `par-alterno` es `oferta` en una pagina y `evidencia` en
  # otra, y quien lo decide es la ANATOMIA de la pagina (09-tipos seccion 2), no
  # el molde. Ej.: `mk-mould.sh out.html 01 06 03 05 02:evidencia 04 11`
  for t in $ORDEN; do
    n=${t%%:*}; rol=""; case "$t" in *:*) rol=${t#*:};; esac
    f=$(ls "$M"/${n}-*.html)
    awk '/<body/{f=1;next} /<\/body>/{f=0} f' "$f" \
      | perl -pe "BEGIN{\$r=q{$rol};\$done=0} if(\$r ne '' && !\$done && s/data-sec=\"[^\"]*\"/data-sec=\"\$r\"/){\$done=1}"
  done
  echo '</main>'
  echo '<footer><a href="/legal/">Aviso legal</a></footer>'
  # El <script> de 18 y 19 ya viaja dentro de <body> y sale en el bucle de arriba.
  echo '</body></html>'
# `fill-hrefs.awk` cambia los href="#" de plantilla por destinos reales. Va sobre
# el DOCUMENTO ENTERO, no molde a molde: el script solo actua entre <main> y
# </main>, asi que darle un fragmento suelto no sustituye nada y la pagina sale
# con cero enlaces internos de cuerpo. (Estaba escrito desde el principio y
# `mk-mould.sh` no lo llamaba; cuando lo llame mal, tampoco hizo nada.)
} | awk -f "$D/fill-hrefs.awk" > "$OUT"
echo "escrito $OUT  $(wc -c < "$OUT") bytes"
