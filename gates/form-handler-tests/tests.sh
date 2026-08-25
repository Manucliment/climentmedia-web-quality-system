#!/bin/sh
# =============================================================================
#  Banco de form-handler.php — el receptor de formularios de las webs de cliente
# =============================================================================
#  🔴 POR QUE EXISTE (18-ago-2026)
#  Este fichero se COPIA a `_deploy/contact.php` de cada web de cliente, y hasta
#  hoy **no lo validaba ninguna herramienta**: no habia `php` ni en la maquina de
#  Manuel ni en el servidor. Se leia a mano. Un error de sintaxis ahi es un 500
#  en el formulario de un cliente vivo, y el fichero existe precisamente porque
#  en Site A a Domicile el formulario contestaba 200 sin que llegara nada.
#
#  Manuel autorizo instalar `php-cli` en example-host ese dia. SOLO la CLI:
#  ni `php-fpm` ni modulo de servidor web, asi que nada quedo accesible desde
#  fuera. Verificado: 0 servicios php, 0 paquetes fpm.
#
#  ⚠️ `php -l` dice que PARSEA, no que funcione. Por eso los casos 2 y 3 lo
#  EJECUTAN, y el 4 y el 5 son los controles de que este banco sabe ponerse rojo.
# =============================================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
REF="$(dirname "$DIR")"
HOST="${NAV_HOST:-example-host}"
FH="$REF/form-handler.php"
OK=0; MAL=0

echo "BANCO · form-handler.php (php -l y ejecucion) · en $HOST"
echo

if [ ! -f "$FH" ]; then
  echo "  MAL   no encuentro $FH"; echo; echo "  OK 0 · MAL 1"; exit 1
fi
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOST" 'command -v php >/dev/null' </dev/null 2>/dev/null; then
  echo "  NO VERIFICADO · no se llega a $HOST o no tiene php"
  echo "  Esto NO es un aprobado: sin interprete la plantilla no la valida nadie,"
  echo "  que es exactamente el estado del que viene este banco."
  echo; echo "  OK 0 · MAL 1"; exit 1
fi

REM="$(ssh "$HOST" 'echo $HOME' </dev/null 2>/dev/null)/.fh-pruebas"
ssh "$HOST" "rm -rf $REM && mkdir -p $REM" </dev/null >/dev/null 2>&1
scp -q "$FH" "$HOST:$REM/base.php" </dev/null

comp () {                    # comp <titulo> <orden remota> <patron que DEBE salir>
  t="$1"; orden="$2"; pat="$3"
  out="$(ssh "$HOST" "cd $REM && $orden" </dev/null 2>&1)"
  case "$out" in
    *"$pat"*) printf "  ok    %-52s\n" "$t"; OK=$((OK+1)) ;;
    *)        printf "  MAL   %-52s esperaba «%s»\n" "$t" "$pat"
              printf "        salio: %s\n" "$(printf '%s' "$out" | head -1)"; MAL=$((MAL+1)) ;;
  esac
}
nocomp () {                  # nocomp <titulo> <orden remota> <patron que NO debe salir>
  t="$1"; orden="$2"; pat="$3"
  out="$(ssh "$HOST" "cd $REM && $orden" </dev/null 2>&1)"
  case "$out" in
    *"$pat"*) printf "  MAL   %-52s NO deberia decir «%s»\n" "$t" "$pat"; MAL=$((MAL+1)) ;;
    *)        printf "  ok    %-52s\n" "$t"; OK=$((OK+1)) ;;
  esac
}

echo "== LA PLANTILLA TAL CUAL SALE DE AQUI"
comp   "parsea sin errores de sintaxis"        "php -l base.php" "No syntax errors"
comp   "sin configurar, SE NIEGA a funcionar"  "php base.php"    "sin configurar"

echo
echo "== CONFIGURADA CON VALORES REALES"
ssh "$HOST" "cd $REM && sed 's/RELLENAR@ejemplo.tld/info@ejemplo-real.be/g; s/RELLENAR nombre del cliente/Cliente Real/' base.php > ok.php" </dev/null 2>/dev/null
nocomp "ya no se queja de estar sin configurar"     "php ok.php" "sin configurar"
nocomp "y no suelta avisos de PHP por el camino"    "php ok.php" "PHP Warning"

echo
echo "== CONTROLES DE QUE ESTE BANCO SABE PONERSE ROJO"
# 4 · si el linter no estuviera corriendo de verdad, esto pasaria
ssh "$HOST" "cd $REM && printf '<?php\nfunction rota( {\n' > rota.php" </dev/null 2>/dev/null
comp   "un fichero roto SI lo caza php -l"          "php -l rota.php" "syntax error"
# 5 · y si el guardia no existiera, el caso 2 estaria midiendo otra cosa
ssh "$HOST" "cd $REM && grep -v 'sin configurar' base.php > singuardia.php" </dev/null 2>/dev/null
nocomp "sin el guardia, la plantilla YA no avisa"   "php singuardia.php" "sin configurar"

ssh "$HOST" "rm -rf $REM" </dev/null >/dev/null 2>&1
echo
printf "  OK %d · MAL %d\n" "$OK" "$MAL"
[ "$MAL" -eq 0 ] || exit 1
