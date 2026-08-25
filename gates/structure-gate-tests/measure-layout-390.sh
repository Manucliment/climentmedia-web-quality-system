#!/usr/bin/env bash
# Igual que measure-layout.sh pero a 390px REALES.
#   uso: measure-layout-390.sh <id> <fichero.html>
# Chrome headless en Windows CLAMPA --window-size a ~500px: pedir 390 daria una
# pagina compuesta a ~504 y una imagen recortada — un movil de mentira. Dentro de
# un <iframe width=390> el innerWidth del documento medido SI es 390 y las media
# queries se evaluan contra el. Requiere --allow-file-access-from-files: sin el,
# un iframe file:// es origen opaco y leerlo lanza SecurityError (me dio 19
# medidas en blanco antes de verlo).
# La sonda imprime `innerWidth`: si no pone 390, la medicion se tira.
set -u
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
DW="$(cd "$(dirname "$0")" && pwd -W)"
D="$(cd "$(dirname "$0")" && pwd)"
ID="$1"; SRC="$2"
mkdir -p "$D/work" "$D/out"
IN="$D/work/m390-$ID-inner.html"; HOST="$D/work/m390-$ID.html"
cp "$SRC" "$IN"
cp "$D/../moldes/_tokens.css" "$D/../moldes/_base.css" "$D/work/" 2>/dev/null || true
{
  echo '<script>try{ var __R ='; cat "$D/measure-layout.js"
  echo ';}catch(e){ __R = JSON.stringify({ERROR:String(e && e.stack || e)}); }'
  echo 'var d=document.createElement("pre"); d.id="__M";'
  echo 'd.textContent="##"+btoa(unescape(encodeURIComponent(__R)))+"##";'
  echo 'document.body.appendChild(d);</script>'
} >> "$IN"

cat > "$HOST" <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>t</title>
<style>html,body{margin:0}iframe{width:390px;height:900px;border:0;display:block}</style></head>
<body><iframe id="f" src="m390-$ID-inner.html"></iframe>
<script>window.addEventListener('load',function(){
  var w=document.getElementById('f').contentDocument;
  var p=w.getElementById('__M');
  var o=document.createElement('pre'); o.textContent = p ? p.textContent : '##VACIO##';
  document.body.appendChild(o);
});</script></body></html>
HTML

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-sandbox \
  --allow-file-access-from-files --force-device-scale-factor=1 \
  --window-size=1440,1000 --dump-dom "file:///$DW/work/m390-$ID.html" 2>/dev/null \
  | grep -o '##[A-Za-z0-9+/=]\{40,\}##' | head -1 | tr -d '#' | base64 -d | tee "$D/out/med390-$ID.json"
echo
