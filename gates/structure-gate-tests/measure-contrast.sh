#!/usr/bin/env bash
# =============================================================================
#  measure-contrast.sh — el gate de contraste de los moldes
# =============================================================================
#  Mide TODOS los elementos con texto de los 19 moldes y FALLA si alguno cae por
#  debajo de su minimo WCAG 2.1 AA (4,5:1, o 3:1 si el texto es grande).
#
#  POR QUE ES UN SCRIPT Y NO UNA FRASE EN UN COMENTARIO
#  ----------------------------------------------------
#  `_tokens.css` dice que los colores de marca "son lo unico que se toca por
#  cliente". Antes eso era una invitacion a romperlo sin enterarse: el peor
#  elemento de los moldes 05, 10 y 12 daba **4,51:1** contra un minimo de 4,5.
#  Margen: 0,01. Y habia SEIS elementos ya por debajo que nadie habia visto,
#  porque el contraste no se ve mirando (`opacity:.4` sobre --tinta = 3,82:1).
#
#  ⚠️ NO se leen colores de una captura. Se calcula con `getComputedStyle`, la
#     opacidad heredada aplicada, el primer fondo opaco de los ancestros, y la
#     formula de luminancia relativa de WCAG. Ver `measure-layout.js`.
#
#  USO
#    bash measure-contrast.sh            # los 19 moldes
#    bash measure-contrast.sh fich.html  # uno suelto o una pagina compuesta
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
if [ "$#" -gt 0 ]; then FILES=("$@"); else FILES=("$D"/../../blueprint/moulds/[0-9]*.html); fi

JSONS=()
for f in "${FILES[@]}"; do
  n="c-$(basename "$f" .html)"
  bash "$D/measure-layout.sh" "$n" "$f" 1280 >/dev/null 2>&1
  [ -f "$D/out/med-$n.json" ] && JSONS+=("$D/out/med-$n.json")
done
[ "${#JSONS[@]}" -gt 0 ] || { echo "sin medidas — no hay nada que juzgar"; exit 1; }

perl "$D/layout-summary.pl" contraste "${JSONS[@]}"
MAL=$(perl "$D/layout-summary.pl" contraste "${JSONS[@]}" | grep -c '<-- FALLA' || true)
echo
if [ "$MAL" -gt 0 ]; then
  echo "FALLA  measure-contrast: $MAL fichero(s) con algun elemento por debajo de su minimo AA."
  echo "       Si acabas de cambiar un color de marca en _tokens.css, es esto."
  exit 1
fi
echo "PASA   measure-contrast: ${#JSONS[@]} fichero(s), 0 elementos por debajo del minimo AA"
exit 0
