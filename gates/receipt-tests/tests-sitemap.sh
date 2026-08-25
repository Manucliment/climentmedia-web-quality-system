#!/usr/bin/env bash
# =============================================================================
#  tests-sitemap.sh · la excepcion del <lastmod>, y sus limites
# =============================================================================
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/receipt-tests/tests-sitemap.sh"
#
#  POR QUE EXISTE
#  --------------
#  En la primera corrida real de G11, en site-a.example, salio esto:
#      G11 · identicos 49 · distintos 1
#        DISTINTO  sitemap.xml -> 200 pero md5 distinto (repo d79944e5 / servido 0f4fbc42)
#  La UNICA diferencia eran los <lastmod>: _gen.ps1:1490 estampa la fecha de HOY
#  al generar, asi que el sitemap se pone en rojo SOLO, todos los dias, sin que
#  nadie haya roto nada y sin que nadie pueda arreglarlo. site-d tiene el
#  mismo patron (_gen.ps1:814). Un rojo que salta siempre enseña a ignorar el
#  gate, y un gate ignorado no protege nada.
#
#  🔴 PERO LA EXCEPCION TIENE QUE SER LA MAS PEQUEÑA QUE RESUELVE EL CASO.
#     Excluir el sitemap entero, o reducirlo a su lista de <loc>, tambien mata
#     el rojo —y de paso deja pasar que se caiga una URL, que cambie un
#     <priority> o que se rompa el XML—. Por eso aqui hay UN positivo y CINCO
#     negativos: cada negativo es una forma concreta de romper el sitemap que la
#     excepcion NO puede tapar.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
REF="$(cd .. && pwd)"
T="${TEMP:-/tmp}/sitemap-pruebas-$$"
PUERTO=$(( 8400 + ($$ % 900) ))
export QA_RECIBOS_DIR="$T/historial-de-pruebas"
OK=0; MAL=0

r() { local nombre="$1" esp="$2"; shift 2
  local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" = "$esp" ]; then OK=$((OK+1)); printf '  PASA  %-52s (exit %s)\n' "$nombre" "$rc"
  else MAL=$((MAL+1)); printf '  FALLA %-52s (exit %s, esperaba %s)\n' "$nombre" "$rc" "$esp"
       printf '%s\n' "$out" | sed 's/^/          /'; fi
  ULTIMA="$out"; }
contiene() { if printf '%s' "$ULTIMA" | grep -qF "$2"; then OK=$((OK+1)); printf '  PASA  %-52s\n' "$1"
  else MAL=$((MAL+1)); printf '  FALLA %-52s (no dice: %s)\n' "$1" "$2"
       printf '%s\n' "$ULTIMA" | sed 's/^/          /'; fi; }
no_contiene() { if printf '%s' "$ULTIMA" | grep -qF "$2"; then MAL=$((MAL+1)); printf '  FALLA %-52s (NO deberia decir: %s)\n' "$1" "$2"
       printf '%s\n' "$ULTIMA" | sed 's/^/          /'
  else OK=$((OK+1)); printf '  PASA  %-52s\n' "$1"; fi; }

# ── el fixture: un sitemap de 3 URLs, como los que genera _gen.ps1 ───────────
#  sitemap_repo <fecha> <marca-priority>   → sitemap con esa fecha en TODAS
sitemap_repo() {
cat <<XML
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>http://127.0.0.1/</loc><lastmod>$1</lastmod><changefreq>weekly</changefreq><priority>$2</priority></url>
  <url><loc>http://127.0.0.1/servicios</loc><lastmod>$1</lastmod><changefreq>monthly</changefreq><priority>0.8</priority></url>
  <url><loc>http://127.0.0.1/contacto</loc><lastmod>$1</lastmod><changefreq>monthly</changefreq><priority>0.5</priority></url>
</urlset>
XML
}
# sin la tercera URL: el caso que la excepcion NO puede tapar
sitemap_sin_contacto() {
cat <<XML
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>http://127.0.0.1/</loc><lastmod>$1</lastmod><changefreq>weekly</changefreq><priority>$2</priority></url>
  <url><loc>http://127.0.0.1/servicios</loc><lastmod>$1</lastmod><changefreq>monthly</changefreq><priority>0.8</priority></url>
</urlset>
XML
}

rm -rf "$T"; mkdir -p "$T/repo" "$T/servido"
printf 'portada\n' > "$T/repo/index.html"
cp "$T/repo/index.html" "$T/servido/index.html"

cat > "$T/qa-verde.json" <<'JSON'
{"sitio":"http://127.0.0.1:0","veredicto":"PASA",
 "resumen":{"fallo":0,"aviso":0,"no_verificado":0,"pasa":50},
 "instrumento":{"perl":"5.042002","dom":"qa.json"},
 "comprobaciones":[
  {"lente":"SEO","id":"SEO-01","estado":"PASA","titulo":"t"},
  {"lente":"RENDIMIENTO","id":"REN-01","estado":"PASA","titulo":"t"},
  {"lente":"ACCESIBILIDAD","id":"A11-01","estado":"PASA","titulo":"t"},
  {"lente":"MEDICION","id":"MED-01","estado":"PASA","titulo":"t"},
  {"lente":"ESTRUCTURA","id":"EST-01","estado":"PASA","titulo":"t"}]}
JSON

CENTINELA="centinela-$$-$(date +%s)"
printf '%s\n' "$CENTINELA" > "$T/servido/_centinela.txt"
perl "$REF/receipt-tests/test-server.pl" "$T/servido" "$PUERTO" >"$T/srv.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
sleep 1
RESP="$(curl -sS --max-time 5 "http://127.0.0.1:$PUERTO/_centinela.txt" 2>/dev/null)"
if [ "$RESP" != "$CENTINELA" ]; then
  echo "  NO ARRANCO MI SERVIDOR DE PRUEBAS en el puerto $PUERTO."
  echo "  Pedi el centinela y me contestaron: '${RESP:0:60}'"
  echo "  🔴 Sin esto las pruebas medirian otra web y algunas PASARIAN igual."
  exit 2
fi
rm -f "$T/servido/_centinela.txt"

sella() {   # reescribe el recibo para el arbol de AHORA
  perl "$REF/receipt.pl" --escribir --repo "$T/repo" --json "$T/qa-verde.json" \
       --sitio "http://127.0.0.1:$PUERTO" >/dev/null
}

echo "==============================================================================="
echo "  EL SITEMAP Y LA FECHA QUE CAMBIA SOLA (127.0.0.1, ninguna web viva)"
echo "==============================================================================="

echo
echo "-- 0 · CONTROL: identicos de verdad -------------------------------------------"
sitemap_repo '2026-08-10' '1.0' > "$T/repo/sitemap.xml"
cp "$T/repo/sitemap.xml" "$T/servido/sitemap.xml"
sella
r "sitemap identico: G11 en verde"          0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "y lo cuenta como identico"          "identicos 2"
no_contiene "sin excepcion que aplicar"       "IGUAL-SALVO-FECHA"

echo
echo "-- 1 · POSITIVO: SOLO cambia <lastmod> (el caso de site-a) ----------------------"
#  repo regenerado hoy, produccion con el sitemap de hace tres dias
sitemap_repo '2026-08-10' '1.0' > "$T/repo/sitemap.xml"
sitemap_repo '2026-08-07' '1.0' > "$T/servido/sitemap.xml"
sella
r "cambiar SOLO la fecha: PASA"             0 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "no lo llama DISTINTO"               "distintos 0"
contiene "pero lo DICE, no lo esconde"        "IGUAL-SALVO-FECHA"
contiene "y enseña las dos fechas"            "repo 2026-08-10 / servido 2026-08-07"

echo
echo "-- 2 · NEGATIVO: falta una URL del sitemap ------------------------------------"
#  mismas fechas: lo unico que cambia es que se ha caido /contacto
sitemap_repo        '2026-08-10' '1.0' > "$T/repo/sitemap.xml"
sitemap_sin_contacto '2026-08-10' '1.0' > "$T/servido/sitemap.xml"
sella
r "quitar una URL: FALLA"                   1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "nombra el fichero"                  "sitemap.xml"
contiene "dice que el md5 no cuadra"          "md5 distinto"
contiene "y lo dice sin rodeos"               "PRODUCCION NO SIRVE LO QUE SE MIDIO"

echo
echo "-- 3 · NEGATIVO: falta una URL **y ademas** cambia la fecha -------------------
     (el que de verdad prueba la excepcion: normalizar la fecha no puede tapar
      la URL que falta, que es como se colaria de verdad)"
sitemap_repo        '2026-08-10' '1.0' > "$T/repo/sitemap.xml"
sitemap_sin_contacto '2026-08-07' '1.0' > "$T/servido/sitemap.xml"
sella
r "URL caida bajo una fecha distinta: FALLA" 1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "sigue siendo DISTINTO"              "DISTINTO  sitemap.xml"
no_contiene "y NO se cuela por la excepcion"  "IGUAL-SALVO-FECHA"

echo
echo "-- 4 · NEGATIVO: cambia <priority>, no la lista de URLs -----------------------
     (por esto NO se compara «la lista de <loc>»: eso lo daria por bueno)"
sitemap_repo '2026-08-10' '1.0' > "$T/repo/sitemap.xml"
sitemap_repo '2026-08-07' '0.1' > "$T/servido/sitemap.xml"
sella
r "priority cambiado: FALLA"                1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "lo marca DISTINTO"                  "DISTINTO  sitemap.xml"

echo
echo "-- 5 · NEGATIVO: la excepcion es SOLO para el sitemap -------------------------
     (un .html con la misma pinta de «solo ha cambiado una fecha» sigue en rojo)"
sitemap_repo '2026-08-10' '1.0' > "$T/repo/sitemap.xml"
cp "$T/repo/sitemap.xml" "$T/servido/sitemap.xml"
printf '<p>actualizado <lastmod>2026-08-10</lastmod></p>\n' > "$T/repo/index.html"
printf '<p>actualizado <lastmod>2026-08-07</lastmod></p>\n' > "$T/servido/index.html"
sella
r "el mismo cambio en un .html: FALLA"      1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "nombra el html"                     "DISTINTO  index.html"
printf 'portada\n' > "$T/repo/index.html"; cp "$T/repo/index.html" "$T/servido/index.html"

echo
echo "-- 6 · NEGATIVO: el arbol ha derivado desde el QA -----------------------------
     (si el sitemap del repo ya no es el que se midio, no hay excepcion que dar:
      la excepcion se concede sobre bytes MEDIDOS, no sobre los de ahora)"
sitemap_repo '2026-08-10' '1.0' > "$T/repo/sitemap.xml"
sitemap_repo '2026-08-07' '1.0' > "$T/servido/sitemap.xml"
sella
sitemap_sin_contacto '2026-08-10' '1.0' > "$T/repo/sitemap.xml"   # editado DESPUES del recibo
r "sin excepcion sobre bytes no medidos"    1 perl "$REF/receipt.pl" --servido --repo "$T/repo"
contiene "lo marca DISTINTO"                  "DISTINTO  sitemap.xml"
no_contiene "y no aplica la excepcion"        "IGUAL-SALVO-FECHA"

echo
echo "==============================================================================="
printf "  %d PASA · %d FALLA\n" "$OK" "$MAL"
echo "==============================================================================="
[ "$MAL" = 0 ] || exit 1
