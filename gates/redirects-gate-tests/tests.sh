#!/usr/bin/env bash
# =============================================================================
#  BANCO · redirects-gate.pl (el arbol que solo redirige) y su recibo
# =============================================================================
#  Cada caso cambia UNA cosa de un arbol bueno y exige el rojo POR SU MOTIVO: el
#  id de la comprobacion que tiene que caer va en el caso, y un rojo por otra cosa
#  es un MAL. Un rojo por el motivo equivocado es un verde disfrazado.
#
#  Dos servidores propios en 127.0.0.1, con centinela: uno sirve los destinos
#  (receipt-tests/test-server.pl), otro hace de dominio viejo ya subido
#  (fake-host.pl). Cero webs de cliente: este repositorio es publico.
#  Los destinos son http:// del banco, asi que el candidato corre con
#  --permitir-http; el caso 2 comprueba que la puerta rechaza ese recibo.
#
#  uso:  bash tests.sh
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
GATE="../redirects-gate.pl"
ok=0; ko=0

W="$(mktemp -d -t redir-banco-XXXXXXXX)"
export QA_RECIBOS_DIR="$W/central"
CENT="centinela-$$-$(date +%s)"

# ── los destinos ─────────────────────────────────────────────────────────────
mkdir -p "$W/destinos"
printf '%s\n' "$CENT" > "$W/destinos/_sentinel.txt"
for p in index aviso clinica; do printf '<h1>%s</h1>\n' "$p" > "$W/destinos/$p.html"; done
P1=$(( 9300 + ($$ % 200) ))
perl ../receipt-tests/test-server.pl "$W/destinos" "$P1" >/dev/null 2>&1 &
S1=$!
# ── el dominio viejo, ya subido ──────────────────────────────────────────────
P2=$(( P1 + 211 ))
: > "$W/host.tsv"
printf '%s' "$CENT" > "$W/host.tsv.sentinel"
perl fake-host.pl "$W/host.tsv" "$P2" >/dev/null 2>&1 &
S2=$!
trap 'kill $S1 $S2 2>/dev/null; rm -rf "$W"' EXIT
sleep 1
if [ "$(curl -sS --max-time 5 "http://127.0.0.1:$P1/_sentinel.txt" 2>/dev/null)" != "$CENT" ] ||
   [ "$(curl -sS --max-time 5 "http://127.0.0.1:$P2/_sentinel" 2>/dev/null)" != "$CENT" ]; then
  echo "  MAL   no arrancaron mis servidores ($P1, $P2): nada de lo de abajo mide nada"
  exit 1
fi
T="http://127.0.0.1:$P1"
SITIO="http://viejo.example.test"

# ── un arbol: robots.txt + _deploy/.htaccess con las lineas que se le pasen ──
arbol() {
  local d="$W/$1"; shift
  rm -rf "$d"; mkdir -p "$d/_deploy"
  printf 'User-agent: *\nAllow: /\n' > "$d/robots.txt"
  {
    echo "SITIO=$SITIO"
    echo 'ARBOL=redirecciones'
    echo 'EXCLUIR="--exclude=_deploy --exclude=.qa-recibo"'
    echo 'PHP_EN_PRODUCCION="_deploy/.htaccess:.htaccess"'
  } > "$d/_deploy/deploy.conf"
  printf '%s\n' "$@" > "$d/_deploy/.htaccess"
  printf '%s' "$d"
}
BASE_ANTES=(
  'Options -Indexes'
  'RewriteEngine On'
  'RewriteRule ^\.well-known/acme-challenge/ - [L]'
  'RewriteRule ^robots\.txt$ - [L]'
)
MAPA=(
  "RewriteRule ^aviso-legal/?$ $T/aviso [R=301,L]"
  "RewriteRule ^nosotros/?$ $T/clinica [R=301,L]"
  "RewriteRule ^servicios/limpieza/?$ $T/clinica [R=301,L]"
)
COMODIN="RewriteRule ^ $T/ [R=301,L]"

OUT="$W/salida.txt"
# caso · rc esperado · texto que TIENE que salir · arbol · opciones del gate
espera() {
  local n="$1" rc="$2" si="$3" d="$4"; shift 4
  perl "$GATE" --repo "$d" --sitio "$SITIO" "$@" > "$OUT" 2>&1
  local r=$?
  if [ "$r" = "$rc" ] && grep -qF -- "$si" "$OUT"; then
    ok=$((ok+1)); printf '  PASA  %s\n' "$n"
  else
    ko=$((ko+1)); printf '  MAL   %s  (rc %s, esperaba %s y «%s»)\n' "$n" "$r" "$rc" "$si"
    sed 's/^/        /' "$OUT"
  fi
}

echo "=== el candidato ==="
D=$(arbol bueno "${BASE_ANTES[@]}" "${MAPA[@]}" "$COMODIN")
espera "1 · arbol bueno: PASA y escribe el recibo"           0 "VEREDICTO: PASA" "$D" --candidato --permitir-http
if grep -q '^REDIRECCIONES-PRUEBA: SI' "$D/.qa-recibo" 2>/dev/null && grep -q '^TIPO: REDIRECCIONES' "$D/.qa-recibo"; then
  ok=$((ok+1)); echo "  PASA  1b · el recibo lleva TIPO y la marca de PRUEBA bajo el sello"
else ko=$((ko+1)); echo "  MAL   1b · el recibo no lleva TIPO: REDIRECCIONES o la marca de PRUEBA"; fi

perl ../receipt.pl --verificar --repo "$D" --para-desplegar > "$OUT" 2>&1; r=$?
if [ "$r" = 1 ] && grep -q 'recibo de PRUEBA' "$OUT"; then
  ok=$((ok+1)); echo "  PASA  2 · la puerta rechaza un recibo hecho con --permitir-http"
else ko=$((ko+1)); echo "  MAL   2 · la puerta acepta un recibo de PRUEBA (rc $r)"; sed 's/^/        /' "$OUT"; fi

perl ../receipt.pl --verificar --repo "$D" > "$OUT" 2>&1; r=$?
if [ "$r" = 0 ] && grep -q 'alcance: REDIRECCIONES' "$OUT"; then
  ok=$((ok+1)); echo "  PASA  2b · sin --para-desplegar el recibo vale y dice su alcance"
else ko=$((ko+1)); echo "  MAL   2b · el recibo no se lee (rc $r)"; sed 's/^/        /' "$OUT"; fi

espera "3 · destinos http sin --permitir-http"     1 "RED-04  linea 5: destino sin https" "$D" --candidato

D=$(arbol pagina "${BASE_ANTES[@]}" "${MAPA[@]}" "$COMODIN"); printf '<?php\n' > "$D/index.php"
espera "4 · una pagina en el arbol"                1 "RED-02  el arbol lleva una pagina o algo que se ejecuta: index.php" "$D" --candidato --permitir-http

D=$(arbol condicion "${BASE_ANTES[@]}" "${MAPA[@]}" 'RewriteCond %{REQUEST_FILENAME} !-f' "$COMODIN")
espera "5 · comodin condicional (RewriteCond)"     1 "RED-01  linea 8: RewriteCond" "$D" --candidato --permitir-http

D=$(arbol sincomodin "${BASE_ANTES[@]}" "${MAPA[@]}")
espera "6 · sin comodin"                           1 "RED-06  /wp-login.php no lo coge ninguna regla" "$D" --candidato --permitir-http

D=$(arbol temporal "${BASE_ANTES[@]}" "RewriteRule ^aviso-legal/?$ $T/aviso [R=302,L]" "${MAPA[@]:1}" "$COMODIN")
espera "7 · una redireccion temporal (302)"        1 "RED-04  linea 5: redirige con 302" "$D" --candidato --permitir-http

D=$(arbol sinL "${BASE_ANTES[@]}" "RewriteRule ^aviso-legal/?$ $T/aviso [R=301]" "${MAPA[@]:1}" "$COMODIN")
espera "8 · una redireccion sin L"                 1 "RED-04  linea 5: redireccion sin L" "$D" --candidato --permitir-http

D=$(arbol tapada "${BASE_ANTES[@]}" "RewriteRule ^servicios/ $T/ [R=301,L]" "${MAPA[@]}" "$COMODIN")
espera "9 · una regla del mapa tapada por otra"    1 "RED-05  linea 8: /servicios/limpieza no llega a su regla; la tapa la linea 5" "$D" --candidato --permitir-http

D=$(arbol wplogin "${BASE_ANTES[@]}" 'RewriteRule ^wp-login\.php$ - [L]' "${MAPA[@]}" "$COMODIN")
espera "10 · deja servir /wp-login.php"            1 "RED-06  /wp-login.php lo deja servir la linea 5" "$D" --candidato --permitir-http
espera "10b · ...y RED-07 dice que no esta en el arbol" 1 "RED-07  linea 5: deja servir /wp-login.php, que no esta en el arbol" "$D" --candidato --permitir-http

D=$(arbol sinrobots 'RewriteEngine On' "${MAPA[@]}" "$COMODIN")
espera "11 · robots.txt en el arbol y redirigido"  1 "RED-08  /robots.txt esta en el arbol y no se serviria" "$D" --candidato --permitir-http

D=$(arbol roto "${BASE_ANTES[@]}" "RewriteRule ^aviso-legal/?$ $T/no-existe [R=301,L]" "${MAPA[@]:1}" "$COMODIN")
espera "12 · un destino que da 404"                1 "RED-09  destino roto: $T/no-existe contesta 404" "$D" --candidato --permitir-http

D=$(arbol propio "${BASE_ANTES[@]}" "RewriteRule ^aviso-legal/?$ $SITIO/aviso [R=301,L]" "${MAPA[@]:1}" "$COMODIN")
espera "13 · redirige a su propio dominio"         1 "RED-04  linea 5: redirige a este mismo dominio" "$D" --candidato --permitir-http

D=$(arbol alias "${BASE_ANTES[@]}" "Redirect 301 /aviso-legal $T/aviso" "${MAPA[@]:1}" "$COMODIN")
espera "14 · Redirect de mod_alias"                1 "RED-01  linea 5: Redirect es de mod_alias" "$D" --candidato --permitir-http

D=$(arbol interna "${BASE_ANTES[@]}" 'RewriteRule ^blog/?$ /index.php [L]' "${MAPA[@]}" "$COMODIN")
espera "15 · una reescritura interna"              1 "RED-01  linea 5: reescritura interna" "$D" --candidato --permitir-http

M="http://127.0.0.1:$(( P1 + 97 ))"
D=$(arbol muerto "${BASE_ANTES[@]}" "RewriteRule ^aviso-legal/?$ $M/aviso [R=301,L]" "${MAPA[@]:1}" "$COMODIN")
espera "16 · un destino que no contesta: NO MEDIDO, no aprobado" 3 "RED-09  NO MEDIDO" "$D" --candidato --permitir-http
grep -q '^LENTE-REDIRECCIONES: NO VERIFICADA' "$D/.qa-recibo" 2>/dev/null \
  && { ok=$((ok+1)); echo "  PASA  16b · el recibo la sella NO VERIFICADA"; } \
  || { ko=$((ko+1)); echo "  MAL   16b · el recibo no sella NO VERIFICADA"; }

echo "=== lo servido ==="
D=$(arbol servido "${BASE_ANTES[@]}" "${MAPA[@]}" "$COMODIN")
SITIO="http://127.0.0.1:$P2"
sirve_bien() {
  {
    printf 'robots.txt\t200\t\n'
    printf 'aviso-legal\t301\t%s\n' "$T/aviso"
    printf 'nosotros\t301\t%s\n' "$T/clinica"
    printf 'servicios/limpieza\t301\t%s\n' "$T/clinica"
    printf '*\t301\t%s\n' "$T/"
  } > "$W/host.tsv"
}
sirve_bien
espera "17 · el dominio redirige lo que dice el .htaccess" 0 "VEREDICTO: PASA" "$D" --servido --permitir-http
printf 'wp-login.php\t200\t\n' >> "$W/host.tsv"
espera "18 · /wp-login.php contesta 200 en el dominio"      1 "RED-10  /wp-login.php tenia que dar 301" "$D" --servido --permitir-http
sirve_bien; printf 'robots.txt\t301\t%s\n' "$T/" >> "$W/host.tsv"
espera "19 · robots.txt redirigido en el dominio"          1 "RED-10  /robots.txt tenia que servirse (200) y contesta 301" "$D" --servido --permitir-http
sirve_bien; printf 'nosotros\t302\t%s\n' "$T/clinica" >> "$W/host.tsv"
espera "20 · una ruta del mapa con 302 en el dominio"      1 "RED-10  /nosotros tenia que dar 301" "$D" --servido --permitir-http
sirve_bien; printf 'aviso-legal\t301\t%s\n' "$T/" >> "$W/host.tsv"
espera "21 · una ruta del mapa a otro destino"             1 "RED-10  /aviso-legal tenia que dar 301 -> $T/aviso" "$D" --servido --permitir-http

echo "=== la puerta ==="
SITIO="http://viejo.example.test"
D=$(arbol raro "${BASE_ANTES[@]}" "${MAPA[@]}" "$COMODIN")
sed -i 's/^ARBOL=redirecciones$/ARBOL=otra-cosa/' "$D/_deploy/deploy.conf"
bash ../deploy.sh "$D" > "$OUT" 2>&1; r=$?
if [ "$r" = 2 ] && grep -q 'ARBOL=otra-cosa no lo se leer' "$OUT"; then
  ok=$((ok+1)); echo "  PASA  22 · un ARBOL= que no se lee para la puerta (exit 2)"
else ko=$((ko+1)); echo "  MAL   22 · ARBOL=otra-cosa (rc $r)"; sed 's/^/        /' "$OUT"; fi
D=$(arbol rojo "${BASE_ANTES[@]}" "${MAPA[@]}")
perl "$GATE" --repo "$D" --sitio "$SITIO" --candidato --permitir-http >/dev/null 2>&1
bash ../deploy.sh "$D" > "$OUT" 2>&1; r=$?
if [ "$r" = 1 ] && grep -q 'redirects-gate.pl' "$OUT" && grep -q 'NO SE DESPLIEGA' "$OUT"; then
  ok=$((ok+1)); echo "  PASA  23 · recibo en rojo: no se despliega y manda a medir con redirects-gate.pl"
else ko=$((ko+1)); echo "  MAL   23 · recibo en rojo (rc $r)"; sed 's/^/        /' "$OUT"; fi

echo
echo "  RESULTADO: OK $ok · MAL $ko"
[ "$ko" = 0 ]
