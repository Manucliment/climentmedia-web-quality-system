#!/usr/bin/env bash
# =============================================================================
#  battery-layout.sh — todo lo que hay que volver a correr al tocar un molde
# =============================================================================
#  1. chk-collisions  · ningun molde pisa a otro ni al chasis  (+ sus 6 negativos)
#  2. measure-contrast · TODOS los moldes contra el minimo AA   (+ su negativo)
#     No lleva numero a proposito: `measure-contrast.sh` los enumera con un glob
#     sobre `blueprint/moulds/[0-9]*.html`, asi que un molde nuevo entra solo.
#     Aqui ponia «los 19» y el dia que entro el 20 se quedo desfasado sin que
#     nada fallara — un recuento escrito al lado de un glob no puede estar bien
#     mas que por casualidad.
#  3. anchos          · las 7 composiciones a 1280 y a 390 REALES
#  4. run-gate        · la home compuesta, control positivo de structure-gate.js
#
#  Tarda unos minutos: son ~50 arranques de Chrome. No hay atajo — el DOM no se
#  puede deducir del CSS.
#     uso: bash battery-layout.sh
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
cd "$D"
fallos=0

echo "############ 1 · COLISIONES ############"
bash test-collisions.sh || fallos=$((fallos+1))

echo
echo "############ 2 · CONTRASTE ############"
bash measure-contrast.sh >/dev/null 2>&1 || fallos=$((fallos+1))
bash measure-contrast.sh 2>&1 | tail -3
echo "-- control negativo (un color de marca malo tiene que FALLAR) --"
if bash measure-contrast.sh fixtures-contrast/tenue-de-cliente.html >/dev/null 2>&1; then
  echo "REVISAR: el negativo de contraste ha PASADO. El gate no mide."; fallos=$((fallos+1))
else
  echo "OK: el negativo de contraste falla, como debe."
fi

echo
echo "############ 3 · LAS 7 COMPOSICIONES ############"
# Los ordenes salen de `09-tipos-de-pagina.md` seccion 2. `NN:rol` fuerza el
# data-sec cuando el molde hace un papel distinto del que trae de fabrica.
compon(){ bash mk-mould.sh "$1" "${@:2}" >/dev/null; }
compon mould-home.html            01 06 03 05 02:evidencia 04:alternativas 11
compon work/c-servicio.html       01 03 07 05 09:evidencia 04:alternativas 08 02:hermanos 11
compon work/c-guia.html           01 02 02 02 06:prueba 04 08 12:hermanos 11
compon work/c-comparativa.html    01 04 07 02:evidencia 08 11
compon work/c-producto.html       01 14 03 15 10 08 11
compon work/c-casos.html          01 16 18 09 11
compon work/c-roadmap.html        01 17 12 11
JS=(); JS390=()
bash measure-layout.sh     comp-home mould-home.html 1280 >/dev/null 2>&1
bash measure-layout-390.sh comp-home mould-home.html      >/dev/null 2>&1
JS+=("out/med-comp-home.json"); JS390+=("out/med390-comp-home.json")
for p in servicio guia comparativa producto casos roadmap; do
  bash measure-layout.sh     "comp-$p" "work/c-$p.html" 1280 >/dev/null 2>&1
  bash measure-layout-390.sh "comp-$p" "work/c-$p.html"      >/dev/null 2>&1
  JS+=("out/med-comp-$p.json"); JS390+=("out/med390-comp-$p.json")
done
perl layout-summary.pl anchos "${JS[@]}"
echo "--- a 390px REALES (iframe; si iw no pone 390, la medida se tira) ---"
perl -MJSON::PP -e '
for my $f (@ARGV){ open my $h,"<:raw",$f or next; my $d=eval{decode_json(do{local $/;<$h>})} or next;
  my $id=$f; $id=~s{.*med390-}{}; $id=~s/\.json//;
  printf "%-16s iw=%-4s desborde=%-2d contraste_fallan=%-2d peor=%-5s cplReal=%s\n",
    $id,$d->{innerWidth},scalar @{$d->{desborde}},$d->{contraste}{fallan},
    $d->{contraste}{peor}[0]{ratio}//"-",$d->{cpl}{maxReal}; }' "${JS390[@]}"

echo
echo "############ 4 · LA HOME COMPUESTA CONTRA structure-gate.js ############"
V=$(bash run-gate.sh P1-molde mould-home.html - '{"tipo":"home","ruta":"/"}' 2>/dev/null \
    | grep '"VEREDICTO"' | grep -o 'PASA\|FALLA')
echo "P1-molde (control POSITIVO, debe PASAR): ${V:-ERROR}"
[ "${V:-x}" = "PASA" ] || fallos=$((fallos+1))

echo
[ "$fallos" = 0 ] && echo "BATERIA OK" || echo "BATERIA: $fallos bloque(s) a revisar"
exit $fallos
