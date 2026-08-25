#!/usr/bin/env bash
# Corre gate-estructura.js sobre una copia local de una pagina, con <base> para
# que resuelvan CSS e imagenes, y devuelve el JSON del gate.
#   uso: run-gate.sh <id> <fichero.html> <base-href|-> '<json de __GATE__>' [gate.js]
# El <base> tambien es lo que hace que el gate vea el ORIGEN y la RUTA reales.
#
# 17-ago-2026 · El 5o argumento (opcional) corre OTRO gate de navegador con este
# mismo arnes -hoy `gate-formularios.js`-. Por defecto sigue siendo
# `gate-estructura.js`, asi que la bateria de maqueta no se entera. Se anade en
# vez de copiar el fichero porque dos copias divergen el primer dia: el `<base>`,
# el `--allow-file-access-from-files` y el envoltorio de base64 son exactamente
# los mismos problemas para cualquier gate que se pegue en la pagina.
set -u
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
ID="$1"; SRC="$2"; BASE="${3:--}"; CONF="${4:-{\}}"
# Derived from this script's own directory, never an absolute path: a default
# that names one machine works on exactly one machine (trap §7).
GATE="${5:-$(cd "$(dirname "$0")/.." && pwd -W)/structure-gate.js}"
[ -f "$GATE" ] || { echo "{\"ERROR\":\"no encuentro el gate: $GATE\"}"; exit 2; }
D="$(cd "$(dirname "$0")" && pwd -W)"   # -W: ruta WINDOWS. Con pwd normal, Git Bash devuelve /tmp/... y Chrome abre ERR_FILE_NOT_FOUND
mkdir -p "$D/work" "$D/out"
W="$D/work/$ID.html"

# <base> justo detras de <head>, con awk: nada de sed sobre HTML con entidades.
if [ "$BASE" != "-" ]; then
  awk -v b="$BASE" 'BEGIN{d=0}{ if(!d && tolower($0) ~ /<head[ >]/){ sub(/<[hH][eE][aA][dD][^>]*>/, "&\n<base href=\""b"\">"); d=1 } print }' "$SRC" > "$W"
else
  cp "$SRC" "$W"
fi

{
  echo "<script>window.__GATE__ = $CONF;</script>"
  echo '<script>try{ var __R ='
  cat "$GATE"
  echo ';}catch(e){ __R = JSON.stringify({ERROR:String(e && e.stack || e)}); }'
  echo 'var d=document.createElement("pre"); d.id="__G";'
  echo 'd.textContent="@@"+btoa(unescape(encodeURIComponent(__R)))+"@@";'
  echo 'document.body.appendChild(d);</script>'
} >> "$W"

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-sandbox \
  --allow-file-access-from-files --force-device-scale-factor=1 \
  --window-size=1440,900 --dump-dom "file:///$W" > "$D/work/$ID.dom" 2>"$D/work/$ID.err"

B64=$(grep -o '@@[A-Za-z0-9+/=]\{40,\}@@' "$D/work/$ID.dom" | head -1 | tr -d '@')
if [ -z "$B64" ]; then echo "{\"ERROR\":\"sin payload — $(tail -2 "$D/work/$ID.err" | tr '\n' ' ')\"}"; exit 1; fi
echo "$B64" | base64 -d | tee "$D/out/$ID.json"
