#!/usr/bin/env bash
# Calibra `chk-collisions.pl`: UN caso positivo (los 19 moldes de verdad) y SEIS
# negativos, uno por regla. Un gate que solo se ha visto en verde no prueba nada.
#   uso:  bash test-collisions.sh
set -u
D="$(cd "$(dirname "$0")" && pwd)"
CHK="perl $D/chk-collisions.pl"
F="$D/fixtures-collision"
fallos=0

caso(){ # id · exit esperado · codigo esperado (o -) · ficheros...
  local id="$1" esp="$2" cod="$3"; shift 3
  local out rc
  out=$($CHK "$@" 2>&1); rc=$?
  local ok="OK"
  [ "$rc" = "$esp" ] || ok="REVISAR(exit $rc)"
  if [ "$cod" != "-" ] && ! echo "$out" | grep -q "\[$cod\]"; then ok="REVISAR(sin $cod)"; fi
  [ "$ok" = "OK" ] || fallos=$((fallos+1))
  printf "%-26s | esp exit %s %-4s | %s\n" "$id" "$esp" "$cod" "$ok"
}

echo "===== POSITIVO · el repertorio real tiene que PASAR ====="
caso "P1-los-19-moldes"   0 -   "$D/../moldes"

echo
echo "===== NEGATIVOS · cada uno tiene que FALLAR por su motivo ====="
caso "N1-pisa-chasis"     1 C1  "$F/91-pisa-chasis.html"
caso "N2-global-body"     1 C2  "$F/92-global.html"
caso "N3-elemento-suelto" 1 C3  "$F/92-global.html"
caso "N4-sin-prefijo"     1 C4  "$F/93-sin-prefijo.html"
caso "N5-mismo-sel-difer" 1 C5  "$F/94-colision-uno.html" "$F/94-colision-dos.html"
caso "N6-mismo-sel-igual" 1 C6  "$F/95-dup-uno.html" "$F/95-dup-dos.html"

echo
echo "===== CONTROL · un negativo suelto NO puede contaminar al positivo ====="
caso "C1-19-mas-un-roto"  1 C1  "$D/../moldes" "$F/91-pisa-chasis.html"

echo
if [ "$fallos" = 0 ]; then echo "TODO OK — 8 casos, el gate distingue"; else echo "$fallos caso(s) a revisar"; fi
exit $fallos
