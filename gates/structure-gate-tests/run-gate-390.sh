#!/usr/bin/env bash
# Igual que run-gate.sh pero midiendo a 390px REALES. Chrome headless en Windows
# CLAMPA --window-size a ~500px: pedir 390 daria una PNG de 390 sobre una pagina
# compuesta a 504, o sea un RECORTE disfrazado de movil. Dentro de un
# <iframe width=390> el innerWidth del documento medido SI es 390 y las media
# queries se evaluan contra el. Requiere --allow-file-access-from-files: sin el,
# un iframe file:// es origen opaco y leer su documento lanza SecurityError.
set -u
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
# Self-locating, for the reason in trap §7.
GATE="$(cd "$(dirname "$0")/.." && pwd -W)/structure-gate.js"
D="$(cd "$(dirname "$0")" && pwd -W)"
ID="$1"; SRC="$2"; BASE="${3:--}"; CONF="${4:-{\}}"
mkdir -p "$D/work" "$D/out"
IN="$D/work/${ID}_390_inner.html"; HOST="$D/work/${ID}_390.html"

if [ "$BASE" != "-" ]; then
  awk -v b="$BASE" 'BEGIN{d=0}{ if(!d && tolower($0) ~ /<head[ >]/){ sub(/<[hH][eE][aA][dD][^>]*>/, "&\n<base href=\""b"\">"); d=1 } print }' "$SRC" > "$IN"
else cp "$SRC" "$IN"; fi
{
  echo "<script>window.__GATE__ = $CONF;</script>"
  echo '<script>try{ var __R ='; cat "$GATE"
  echo ';}catch(e){ __R = JSON.stringify({ERROR:String(e && e.stack || e)}); }'
  echo 'var d=document.createElement("pre"); d.id="__G";'
  echo 'd.textContent="@@"+btoa(unescape(encodeURIComponent(__R)))+"@@";'
  echo 'document.body.appendChild(d);</script>'
} >> "$IN"

cat > "$HOST" <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>t</title>
<style>html,body{margin:0}iframe{width:390px;height:844px;border:0;display:block}</style></head>
<body><iframe id="f" src="${ID}_390_inner.html"></iframe>
<script>window.addEventListener('load',function(){
  var w=document.getElementById('f').contentDocument;
  var p=w.getElementById('__G');
  var o=document.createElement('pre'); o.textContent = p ? p.textContent : '@@VACIO@@';
  document.body.appendChild(o);
});</script></body></html>
HTML

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-sandbox \
  --allow-file-access-from-files --window-size=1440,900 --dump-dom "file:///$HOST" 2>/dev/null \
  | grep -o '@@[A-Za-z0-9+/=]\{40,\}@@' | head -1 | tr -d '@' | base64 -d | tee "$D/out/${ID}-390.json"
