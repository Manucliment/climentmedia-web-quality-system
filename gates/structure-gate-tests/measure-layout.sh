#!/usr/bin/env bash
# Corre `measure-layout.js` sobre un fichero local con Chrome headless.
#   uso: measure-layout.sh <id> <fichero.html> [ancho-css]
# Ancho por defecto 1280 CSS. Chrome descuenta la barra de scroll aunque se pase
# `--hide-scrollbars` en `--headless=new`, asi que se pide ancho+18 y la sonda
# imprime el `innerWidth` de verdad: si no coincide, la medicion se tira.
set -u
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
D="$(cd "$(dirname "$0")" && pwd -W)"          # -W: ruta WINDOWS, o Chrome da ERR_FILE_NOT_FOUND
SONDA="$(cd "$(dirname "$0")" && pwd)/measure-layout.js"
ID="$1"; SRC="$2"; ANCHO="${3:-1280}"
PIDE=$((ANCHO + 18))
mkdir -p "$D/work" "$D/out"
W="$D/work/med-$ID.html"
cp "$SRC" "$W"
# Un molde suelto engancha el chasis con <link href="_tokens.css"> RELATIVO. Al
# copiarlo a work/ ese enlace se rompe y la pagina se mide SIN CSS: sale plana y
# parece rota. Por eso el chasis viaja con la copia.
WD="$(cd "$(dirname "$0")" && pwd)"
cp "$WD/../../blueprint/moulds/_tokens.css" "$WD/../../blueprint/moulds/_base.css" "$WD/work/" 2>/dev/null || true
{
  echo '<script>try{ var __R ='
  cat "$SONDA"
  echo ';}catch(e){ __R = JSON.stringify({ERROR:String(e && e.stack || e)}); }'
  echo 'var d=document.createElement("pre"); d.id="__M";'
  echo 'd.textContent="##"+btoa(unescape(encodeURIComponent(__R)))+"##";'
  echo 'document.body.appendChild(d);</script>'
} >> "$W"

"$CHROME" --headless=new --disable-gpu --hide-scrollbars --no-sandbox \
  --allow-file-access-from-files --force-device-scale-factor=1 \
  --window-size=$PIDE,1000 --dump-dom "file:///$W" > "$D/work/med-$ID.dom" 2>"$D/work/med-$ID.err"

B64=$(grep -o '##[A-Za-z0-9+/=]\{40,\}##' "$D/work/med-$ID.dom" | head -1 | tr -d '#')
if [ -z "$B64" ]; then echo "{\"ERROR\":\"sin payload — $(tail -2 "$D/work/med-$ID.err" | tr '\n' ' ')\"}"; exit 1; fi
echo "$B64" | base64 -d | tee "$D/out/med-$ID.json"
echo
