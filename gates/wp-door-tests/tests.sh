#!/usr/bin/env bash
# Banco de wp-door.sh (la puerta de escritura en WordPress, 6-nov-2026).
#   bash gates/wp-door-tests/tests.sh
# Sin red y sin WordPress: un HOST FALSO en una carpeta (WP_SSH y WP_SCP lo sirven en local) y una tanda inventada que
# escribe un fichero «estado» en vez de una base de datos. Cada caso mira el CIERRE, el código de salida y lo que pasó
# en el host (qué modos se llamaron, en qué estado quedó), no solo lo que la puerta dice.
set -u
AQUI=$(cd "$(dirname "$0")" && pwd)
PUERTA="${WP_DOOR:-$AQUI/../wp-door.sh}"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; mal=0
caso() { if [ "$2" = 1 ]; then ok=$((ok+1)); echo "  OK   $1"; else mal=$((mal+1)); echo "  MAL  $1 ${3:-}"; fi; }
si() { "$@" >/dev/null 2>&1 && echo 1 || echo 0; }

# ── el host falso ────────────────────────────────────────────────────────────
mkdir -p "$T/bin"
cat > "$T/bin/ssh" <<'EOF'
#!/usr/bin/env bash
while [ "${1:-}" = -n ] || [ "${1:-}" = -q ]; do shift; done
shift   # el host
HOME="$FAKE_HOME" exec bash -c "$1"
EOF
cat > "$T/bin/scp" <<'EOF'
#!/usr/bin/env bash
while [[ "${1:-}" == -* ]]; do shift; done
cp "$1" "${2#*:}"
EOF
cat > "$T/bin/lint" <<'EOF'
#!/usr/bin/env bash
if grep -q ERROR_DE_SINTAXIS "$1"; then echo "PHP Parse error: syntax error in $1"; exit 255; fi
echo "No syntax errors detected in $1"
EOF
chmod +x "$T/bin/"*
export WP_SSH="$T/bin/ssh" WP_SCP="$T/bin/scp" WP_PHP_LINT="$T/bin/lint"

# La tanda inventada. Lo que hace mal, a petición, con un fichero de la tanda (commiteado, como todo lo aprobado):
#   rojo-nuevo     tras aplicar, un rojo que antes no estaba        no-arregla  aplicar no quita el rojo de antes
#   rompe-volver   --volver deja otro estado                        aplicar-falla  aplicar sale con 3 (tras escribir)
#   medir-vacio    --medir no da ni una línea OK/🔴                 hora        --medir escribe la hora en una línea
cat > "$T/tanda.sh" <<'EOF'
#!/bin/bash
D="${TANDA_DIR:?}"; S="$HOME/sitio"; mkdir -p "$S" "$HOME/backups"
[ -f "$S/estado" ] || echo viejo > "$S/estado"
echo "${1:-aplicar}" >> "$HOME/llamadas"
case "${1:-aplicar}" in
  --medir)
    if [ -f "$D/medir-vacio" ]; then echo "nada que decir"; exit 0; fi
    e=$(cat "$S/estado")
    [ -f "$D/hora" ] && echo "   OK medido a las $(date +%H:%M:%S) del $(date +%Y-%m-%d)"
    echo "   OK la portada da 200"
    if [ "$e" = viejo ] || [ -f "$D/no-arregla" ]; then echo "   🔴 la etiqueta sin noindex"; else echo "   OK la etiqueta con noindex"; fi
    [ "$e" = nuevo ] && [ -f "$D/rojo-nuevo" ] && echo "   🔴 el carrito da 500"
    [ "$e" = roto ] && echo "   🔴 quedó a medias"
    echo "   $(grep -c . /dev/null) en rojo" ;;
  --volver)
    if [ -f "$D/rompe-volver" ]; then echo roto > "$S/estado"; exit 0; fi
    cp "$HOME/backups/estado" "$S/estado" ;;
  *)
    cp "$S/estado" "$HOME/backups/estado"; echo nuevo > "$S/estado"
    # solo el PRIMER aplicar: así el segundo no tapa a la puerta que no mire el primero
    if [ -f "$D/aplicar-falla" ] && [ ! -f "$HOME/ya-fallo" ]; then touch "$HOME/ya-fallo"; exit 3; fi
    exit 0 ;;
esac
EOF

N=0
# nuevo <nombre> [ROJOS_DESPUES] [modos…] → repo con la tanda t1 commiteada y aprobada; deja R, H (host) y TM (tmp)
nuevo() {
  N=$((N+1)); R="$T/r$N/sitio-$1"; H="$T/r$N/home"; TM="$T/r$N/tmp"
  mkdir -p "$R/_deploy/wp/t1" "$H" "$TM"
  git -C "$R" init -q; git -C "$R" config user.email banco@example.invalid; git -C "$R" config user.name banco
  git -C "$R" config core.autocrlf false
  printf 'SITIO=https://example.invalid/\nWP_HOST=host-falso\nWP_TMP=%s\n' "$TM" > "$R/_deploy/deploy.conf"
  cp "$T/tanda.sh" "$R/_deploy/wp/t1/tanda.sh"
  printf '# Tanda de prueba\nQué escribe: el estado. Qué no: nada más.\nROJOS_DESPUES=%s\n' "${2:-0}" > "$R/_deploy/wp/t1/TANDA.md"
  local m; for m in "${@:3}"; do echo "$m" > "$R/_deploy/wp/t1/$m"; done
  git -C "$R" add -- _deploy; git -C "$R" commit -q -m tanda
  aprobar
  export FAKE_HOME="$H"
}
aprobar() {
  echo "APROBADO: Pod Manager · 2026-11-06 · $(git -C "$R" rev-parse HEAD:_deploy/wp/t1)" > "$R/_deploy/wp/t1.aprobado"
  git -C "$R" add -- _deploy/wp/t1.aprobado; git -C "$R" commit -q -m aprobado
}
puerta() { SAL=$(bash "$PUERTA" "$R" t1 "$@" 2>&1); EX=$?; }
llamadas() { [ -f "$H/llamadas" ] && tr '\n' ' ' < "$H/llamadas" | sed 's/ $//' || echo "(ninguna)"; }
estado() { cat "$H/sitio/estado" 2>/dev/null || echo "(sin tocar)"; }
dice() { grep -qF -- "$1" <<<"$SAL"; }
fila() { tail -1 "$R/_deploy/wp/historial.tsv" 2>/dev/null; }

echo "wp-door: la puerta de escritura en WordPress"

nuevo bueno; puerta --escribir
caso "camino bueno: PASA, exit 0" "$( [ $EX = 0 ] && dice 'CIERRE: PASA' && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"
caso "camino bueno: medir, aplicar, medir, VOLVER, medir, aplicar, medir (la vuelta se prueba)" "$( [ "$(llamadas)" = '--medir aplicar --medir --volver --medir aplicar --medir' ] && echo 1 || echo 0)" "$(llamadas)"
caso "camino bueno: el host queda escrito" "$( [ "$(estado)" = nuevo ] && echo 1 || echo 0)" "$(estado)"
caso "camino bueno: historial con árbol, 1 → 0 en rojo, vuelta probada" "$(fila | grep -qE "	$(git -C "$R" rev-parse HEAD:_deploy/wp/t1)	escribir	1	0	sí	PASA" && echo 1 || echo 0)" "$(fila)"
caso "camino bueno: suelta el cerrojo" "$( [ ! -d "$TM/wp-door-sitio-bueno.cerrojo" ] && echo 1 || echo 0)"
caso "camino bueno: guarda las medidas fuera de la tanda (la tanda sigue limpia)" "$( ls "$R/_deploy/wp/_puerta/"t1-*/antes.txt >/dev/null 2>&1 && [ -z "$(git -C "$R" status --porcelain -- _deploy/wp/t1)" ] && echo 1 || echo 0)"
puerta --volver
caso "--volver solo: deshace la última y lo mide (PASA, VUELTO a mano)" "$( [ $EX = 0 ] && dice 'VUELTO a mano' && [ "$(estado)" = viejo ] && echo 1 || echo 0)" "exit $EX · $(estado) · $(tail -1 <<<"$SAL")"
caso "historial: una fila por pasada (cabecera + 2)" "$( [ "$(wc -l < "$R/_deploy/wp/historial.tsv")" = 3 ] && echo 1 || echo 0)" "$(wc -l < "$R/_deploy/wp/historial.tsv")"

nuevo ensayo; puerta
caso "ensayo: sube y mide el antes, no escribe" "$( [ $EX = 0 ] && dice 'CIERRE: ENSAYO' && [ "$(llamadas)" = '--medir' ] && [ "$(estado)" = viejo ] && echo 1 || echo 0)" "exit $EX · $(llamadas)"
caso "ensayo: dice cuántos en rojo hay antes" "$(dice 'antes 1 en rojo' && echo 1 || echo 0)"

nuevo sin-aprobado; git -C "$R" rm -q -- _deploy/wp/t1.aprobado; git -C "$R" commit -q -m quita; puerta --escribir
caso "sin aprobado: para, y el host ni se toca" "$( [ $EX = 1 ] && dice 'sin aprobado' && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX · $(llamadas) · $(tail -1 <<<"$SAL")"
puerta
caso "sin aprobado: tampoco ensaya" "$( [ $EX = 1 ] && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)"

nuevo otro-arbol; echo "# cambio" >> "$R/_deploy/wp/t1/tanda.sh"; git -C "$R" add -- _deploy; git -C "$R" commit -q -m cambio; puerta --escribir
caso "aprobado de otro árbol: para (la tanda cambió después de aprobarla)" "$( [ $EX = 1 ] && dice 'otro árbol' && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"
puerta --volver
caso "aprobado de otro árbol: --volver sí corre (deshacer no espera a nadie)" "$( [ "$(llamadas)" = '--volver --medir' ] && echo 1 || echo 0)" "$(llamadas)"

nuevo sucio; echo "# sin commitear" >> "$R/_deploy/wp/t1/tanda.sh"; puerta --escribir
caso "carpeta con cambios sin commitear: para" "$( [ $EX = 1 ] && dice 'sin commitear' && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"
nuevo suelto; echo x > "$R/_deploy/wp/t1/suelto.php"; puerta --escribir
caso "un fichero nuevo sin commitear en la tanda: para" "$( [ $EX = 1 ] && dice 'sin commitear' && echo 1 || echo 0)" "exit $EX"

nuevo vuelta-rota 0 rompe-volver; puerta --escribir
caso "la vuelta no deja lo de antes: FALLA y NO vuelve a aplicar" "$( [ $EX = 1 ] && dice 'la vuelta no deja lo de antes' && [ "$(llamadas)" = '--medir aplicar --medir --volver --medir' ] && echo 1 || echo 0)" "exit $EX · $(llamadas) · $(tail -1 <<<"$SAL")"
caso "la vuelta no deja lo de antes: dice qué línea cambió" "$(dice 'quedó a medias' && echo 1 || echo 0)"
caso "la vuelta no deja lo de antes: historial «falla»" "$(fila | grep -q '	falla	FALLA' && echo 1 || echo 0)" "$(fila)"

nuevo rojo-nuevo 0 rojo-nuevo; puerta --escribir
caso "rojo nuevo tras aplicar: deshace y dice VUELTO" "$( [ $EX = 1 ] && dice 'rojo nuevo' && dice 'VUELTO: lo de antes' && [ "$(estado)" = viejo ] && echo 1 || echo 0)" "exit $EX · $(estado) · $(tail -1 <<<"$SAL")"
caso "rojo nuevo: nombra el rojo" "$(dice 'el carrito da 500' && echo 1 || echo 0)"

nuevo incompleta 0 rojo-nuevo rompe-volver; puerta --escribir --sin-probar-volver "prueba del banco"
caso "rojo nuevo y la vuelta rota: VUELTA-INCOMPLETA, con lo que no volvió" "$( [ $EX = 1 ] && dice 'VUELTA-INCOMPLETA' && dice 'quedó a medias' && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"

nuevo no-arregla 0 no-arregla; puerta --escribir
caso "después 1 en rojo y TANDA.md admite 0: deshace" "$( [ $EX = 1 ] && dice 'admite 0' && dice 'VUELTO' && [ "$(estado)" = viejo ] && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"
nuevo admite-1 1 no-arregla; puerta --escribir
caso "ROJOS_DESPUES=1 y queda el rojo de antes: PASA" "$( [ $EX = 0 ] && dice 'admite 1' && [ "$(estado)" = nuevo ] && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"
nuevo admite-1-nuevo 1 rojo-nuevo no-arregla; puerta --escribir
caso "ROJOS_DESPUES=1 no deja pasar un rojo NUEVO" "$( [ $EX = 1 ] && dice 'rojo nuevo' && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"

nuevo aplicar-falla 0 aplicar-falla; puerta --escribir
caso "aplicar sale con error: deshace y lo mide, sin seguir" "$( [ $EX = 1 ] && dice 'CIERRE: FALLA - aplicar salió con 3' && dice 'VUELTO' && [ "$(estado)" = viejo ] && [ "$(llamadas)" = '--medir aplicar --volver --medir' ] && echo 1 || echo 0)" "exit $EX · $(llamadas) · $(tail -1 <<<"$SAL")"

nuevo hora 0 hora; puerta --escribir
caso "la hora en una línea de --medir no hace distinta la vuelta" "$( [ $EX = 0 ] && dice 'CIERRE: PASA' && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"

nuevo vacio 0 medir-vacio; puerta --escribir
caso "--medir sin líneas OK/🔴: NO MEDIDO (2) y no escribe" "$( [ $EX = 2 ] && dice 'NO MEDIDO' && [ "$(llamadas)" = '--medir' ] && [ "$(estado)" = viejo ] && echo 1 || echo 0)" "exit $EX · $(llamadas)"

nuevo sin-probar; puerta --escribir --sin-probar-volver
caso "--sin-probar-volver sin motivo: uso (64)" "$( [ $EX = 64 ] && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX"
puerta --escribir --sin-probar-volver "WordPress sin copia posible de esa tabla"
caso "--sin-probar-volver con motivo: PASA sin llamar a --volver, y el motivo en el historial" "$( [ $EX = 0 ] && [ "$(llamadas)" = '--medir aplicar --medir' ] && fila | grep -q 'saltada: WordPress sin copia posible' && echo 1 || echo 0)" "exit $EX · $(llamadas) · $(fila)"

nuevo cerrojo; mkdir "$TM/wp-door-sitio-cerrojo.cerrojo"; puerta --escribir
caso "otra tanda corriendo (cerrojo fresco): para y no lo quita" "$( [ $EX = 1 ] && dice 'otra tanda' && [ -d "$TM/wp-door-sitio-cerrojo.cerrojo" ] && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"
touch -d '20 minutes ago' "$TM/wp-door-sitio-cerrojo.cerrojo"; puerta --escribir
caso "cerrojo de más de 15 min: se da por muerto, se dice, y pasa" "$( [ $EX = 0 ] && dice 'se da por muerto' && [ ! -d "$TM/wp-door-sitio-cerrojo.cerrojo" ] && echo 1 || echo 0)" "exit $EX · $(tail -1 <<<"$SAL")"

nuevo bash-n; printf 'if then\n' >> "$R/_deploy/wp/t1/tanda.sh"; git -C "$R" add -- _deploy; git -C "$R" commit -q -m roto; aprobar; puerta --escribir
caso "bash -n de tanda.sh falla: para antes de subir" "$( [ $EX = 1 ] && dice 'bash -n' && [ "$(llamadas)" = '(ninguna)' ] && [ -z "$(ls "$TM")" ] && echo 1 || echo 0)" "exit $EX · $(ls "$TM" | tr '\n' ' ') · $(tail -1 <<<"$SAL")"

nuevo php; printf '<?php\nERROR_DE_SINTAXIS\n' > "$R/_deploy/wp/t1/aplicar.php"; git -C "$R" add -- _deploy; git -C "$R" commit -q -m php; aprobar; puerta --escribir
caso "php -l de un .php de la tanda falla: para antes de medir" "$( [ $EX = 1 ] && dice 'php -l de aplicar.php' && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX · $(llamadas) · $(tail -1 <<<"$SAL")"

nuevo sube-head; puerta
caso "lo que sube es el árbol de HEAD, con sus ficheros" "$(ls -d "$TM"/wp-t1-*/ >/dev/null 2>&1 && [ -f "$(ls -d "$TM"/wp-t1-*/ | head -1)/TANDA.md" ] && echo 1 || echo 0)"

# 7-nov: con core.autocrlf=true (el de Git for Windows), `git archive` de un subárbol subía tanda.sh en CRLF. Los
# repos de este banco ponían autocrlf=false, y por eso no se veía.
nuevo crlf; git -C "$R" config core.autocrlf true; puerta
SUB=$(ls -d "$TM"/wp-t1-*/ 2>/dev/null | head -1)
caso "core.autocrlf=true: sube los bytes del árbol (sin un CR) y ensaya" "$( [ $EX = 0 ] && dice 'CIERRE: ENSAYO' && [ -n "$SUB" ] && [ "$(tr -cd '\r' < "$SUB/tanda.sh" | wc -c)" = 0 ] && [ "$(wc -c < "$SUB/tanda.sh")" = "$(git -C "$R" cat-file -s HEAD:_deploy/wp/t1/tanda.sh)" ] && echo 1 || echo 0)" "exit $EX · ${SUB:-(no subió)} · $(tail -1 <<<"$SAL")"
nuevo eol-crlf; printf 'tanda.sh text eol=crlf\n' > "$R/_deploy/wp/t1/.gitattributes"; git -C "$R" add -- _deploy 2>/dev/null; git -C "$R" commit -q -m eol; aprobar; puerta
caso "una .gitattributes de la tanda que convierte: NO MEDIDO (2), nombra el fichero y no sube nada" "$( [ $EX = 2 ] && dice 'bytes del árbol aprobado en: tanda.sh' && [ -z "$(ls "$TM")" ] && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX · $(ls "$TM" | tr '\n' ' ') · $(tail -1 <<<"$SAL")"

nuevo sin-host; sed -i '/^WP_HOST=/d' "$R/_deploy/deploy.conf"; puerta --escribir
caso "sin WP_HOST en deploy.conf: NO MEDIDO (2)" "$( [ $EX = 2 ] && dice 'falta WP_HOST' && echo 1 || echo 0)" "exit $EX"
nuevo host-raro; sed -i 's/^WP_HOST=.*/WP_HOST=host;rm/' "$R/_deploy/deploy.conf"; puerta --escribir
caso "WP_HOST con caracteres raros: NO MEDIDO, no se pasa al ssh" "$( [ $EX = 2 ] && dice 'WP_HOST no válido' && [ "$(llamadas)" = '(ninguna)' ] && echo 1 || echo 0)" "exit $EX"
SAL=$(bash "$PUERTA" "$R" "../t1" --escribir 2>&1); EX=$?
caso "nombre de tanda con «..»: uso (64)" "$( [ $EX = 64 ] && echo 1 || echo 0)" "exit $EX"
SAL=$(bash "$PUERTA" "$R" t1 --escribir --volver 2>&1); EX=$?
caso "--escribir y --volver a la vez: uso (64)" "$( [ $EX = 64 ] && echo 1 || echo 0)" "exit $EX"

echo "OK $ok · MAL $mal"
[ "$mal" = 0 ]
