#!/bin/bash
# Banco de banner-probe.js: copia la sonda y run.js al host de medida y lo corre alli
# (Chrome vive en el servidor; en Windows recorta el ancho). Sin host, NO MEDIDO, no verde.
REF="$(cd "$(dirname "$0")/.." && pwd)"
. "$REF/nav-host.sh"
H="$(nav_host "$REF")"
[ -n "$H" ] || { echo "  N/M   banner-probe: NOT MEASURED, NAV_HOST sin configurar"; exit 0; }
ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$H" 'mkdir -p ~/webtools/banner-probe-tests' 2>/dev/null \
  || { echo "  N/M   banner-probe: NOT MEASURED, no llego a $H"; exit 0; }
scp -q "$REF/banner-probe.js" "$H:webtools/banner-probe.js" </dev/null && \
scp -q "$REF/banner-probe-tests/run.js" "$H:webtools/banner-probe-tests/run.js" </dev/null || { echo "  N/M   banner-probe: no se pudo copiar"; exit 0; }
echo "== banner-probe · el aviso de cookies como lo ve un visitante · en $H"
ssh -n -o BatchMode=yes "$H" 'cd ~/webtools && node banner-probe-tests/run.js'
