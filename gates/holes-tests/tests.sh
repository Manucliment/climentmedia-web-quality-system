#!/usr/bin/env bash
# =============================================================================
#  BANCO DE holes.pl
# =============================================================================
#  Cada caso escribe un `_huecos.tsv` y afirma que el gate lo acepta o lo
#  rechaza. Los rojos son la mitad que importa: un gate que acepta cualquier
#  cosa no declara nada, solo da la sensacion de que si.
#
#  El caso que mas vale es «sin MEDIDO»: un hueco sin la prueba de que falta es
#  una suposicion, y una suposicion en esa lista bloquea trabajo por nada.
# =============================================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
G="$(cd "$DIR/.." && pwd)/holes.pl"
T="${TMPDIR:-/tmp}/holes-tests-$$"; mkdir -p "$T"
OK=0; KO=0
CAB=$(printf 'id\tquien\tque\tmedido\tbloquea\tdesde\testado')
BUENA=$(printf 'HUECO-01\tcliente\tel NIF\tno consta en la spec\taviso legal\t2026-08-19\tabierto')

caso() {  # caso <nombre> <esperado:0|1> <contenido>
  local n="$1" esp="$2" c="$3"
  printf '%s\n' "$c" > "$T/_huecos.tsv"
  [ -s "$T/_huecos.tsv" ] || { echo "  🔴 el fixture salio vacio: $n"; KO=$((KO+1)); return; }
  perl "$G" --repo "$T" -q >/dev/null 2>&1; local rc=$?
  if [ "$rc" = "$esp" ]; then OK=$((OK+1)); printf '  ok    %-46s rc=%s\n' "$n" "$rc"
  else KO=$((KO+1)); printf '  FALLA %-46s esperaba rc=%s y dio %s\n' "$n" "$esp" "$rc"; fi
}

echo "== el que tiene que salir VERDE =="
caso "fichero bien formado" 0 "$CAB
$BUENA"

echo
echo "== los que tienen que salir ROJOS =="
caso "6 columnas en vez de 7"        1 "$CAB
$(printf 'HUECO-02\tcliente\tx\tmedido\tbloquea\t2026-08-19')"
caso "id que no es HUECO-NN"         1 "$CAB
$(printf 'FALTA-1\tcliente\tx\tmedido\tbloquea\t2026-08-19\tabierto')"
caso "quien fuera del vocabulario"   1 "$CAB
$(printf 'HUECO-03\tel_becario\tx\tmedido\tbloquea\t2026-08-19\tabierto')"
caso "estado fuera del vocabulario"  1 "$CAB
$(printf 'HUECO-04\tcliente\tx\tmedido\tbloquea\t2026-08-19\tmas_o_menos')"
caso "fecha que no es AAAA-MM-DD"    1 "$CAB
$(printf 'HUECO-05\tcliente\tx\tmedido\tbloquea\t19-ago-2026\tabierto')"
caso "hueco SIN la prueba de que falta" 1 "$CAB
$(printf 'HUECO-06\tcliente\tx\t\tbloquea\t2026-08-19\tabierto')"
caso "hueco que no bloquea nada"     1 "$CAB
$(printf 'HUECO-07\tcliente\tx\tmedido\t\t2026-08-19\tabierto')"

echo
echo "== sin fichero: NO es un fallo, es un aviso =="
rm -f "$T/_huecos.tsv"
perl "$G" --repo "$T" -q >/dev/null 2>&1
if [ $? -eq 0 ]; then OK=$((OK+1)); printf '  ok    %-46s rc=0\n' "repo sin _huecos.tsv"
else KO=$((KO+1)); printf '  FALLA %-46s tenia que dar rc=0\n' "repo sin _huecos.tsv"; fi

rm -rf "$T"
echo
echo "-------------------------------------------------------------"
printf "  BANCO holes.pl:  OK %d  ·  MAL %d\n" "$OK" "$KO"
echo "-------------------------------------------------------------"
[ "$KO" -eq 0 ] || exit 1
