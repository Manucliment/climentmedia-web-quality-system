#!/bin/bash
# Banco de banner-probe.js: copia la sonda y run.js al host de medida y lo corre alli
# (Chrome vive en el servidor; en Windows recorta el ancho). Sin host, NO MEDIDO, no verde.
REF="$(cd "$(dirname "$0")/.." && pwd)"
. "$REF/nav-host.sh"
H="$(nav_host "$REF")"
[ -n "$H" ] || { echo "  N/M   banner-probe: NOT MEASURED, NAV_HOST sin configurar"; exit 0; }
# 6-nov-2026 · en su propia carpeta (banco-banner), con el run-gate.js de ESTE arbol: la sonda saca
# de el como servir un arbol, y ~/webtools/run-gate.js lo reescriben la puerta y los otros bancos.
ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$H" 'mkdir -p ~/webtools/banco-banner/banner-probe-tests' 2>/dev/null \
  || { echo "  N/M   banner-probe: NOT MEASURED, no llego a $H"; exit 0; }
scp -q "$REF/banner-probe.js" "$REF/run-gate.js" "$H:webtools/banco-banner/" </dev/null && \
scp -q "$REF/banner-probe-tests/run.js" "$H:webtools/banco-banner/banner-probe-tests/run.js" </dev/null || { echo "  N/M   banner-probe: no se pudo copiar"; exit 0; }
echo "== banner-probe · el aviso de cookies como lo ve un visitante · en $H"
ssh -n -o BatchMode=yes "$H" 'cd ~/webtools/banco-banner && node banner-probe-tests/run.js'
