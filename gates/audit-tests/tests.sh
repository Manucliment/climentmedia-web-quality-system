#!/usr/bin/env bash
# =============================================================================
#  BANCO DE PRUEBAS DE audit.sh
# =============================================================================
#  19-ago-2026. `audit.sh` era el UNICO instrumento de la skill sin banco -y el
#  unico que vivia copiado dentro de cada repo, con 3 versiones distintas-. El
#  dia que subio a la skill se le escribio esto.
#
#  LO QUE MIDE ESTE BANCO, Y POR QUE ASI: cada caso parte de un sitio MINIMO Y
#  VERDE, rompe UNA cosa, y afirma que el auditor la caza. Los casos que
#  esperan VERDE son igual de importantes: son los que impiden volver a marcar
#  363 fallos en un sitio correcto, que es lo que paso la primera vez que se le
#  corrio a site-a.
#
#  Toda mutacion AFIRMA que el fichero cambio antes de correr el auditor. Un
#  control positivo que no cambia nada no prueba nada: pasa, y el gate no se ha
#  puesto a prueba.
#
#    bash tests.sh          EXIT 0 = banco verde
# =============================================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
AUD="$(cd "$DIR/.." && pwd)/audit.sh"
T="${TMPDIR:-/tmp}/audit-tests-$$"
export T
OK=0; KO=0
. "$DIR/site.sh"

[ -f "$AUD" ] || { echo "no encuentro $AUD"; exit 2; }

# correr <dir> -> imprime la salida; deja el rc en $RC
correr() { SALIDA="$(bash "$AUD" --root "$1" 2>&1)"; RC=$?; printf '%s' "$SALIDA"; }

# caso <nombre> <espera:VERDE|ROJO> <check-esperado o -> <dir>
caso() {
  local n="$1" esp="$2" chk="$3" d="$4"
  correr "$d" > /dev/null
  local veredicto; [ "$RC" -eq 0 ] && veredicto=VERDE || veredicto=ROJO
  local bien=1
  [ "$veredicto" = "$esp" ] || bien=0
  if [ "$esp" = ROJO ] && [ "$chk" != "-" ]; then
    printf '%s' "$SALIDA" | grep -q "\[FAIL\] $chk" || bien=0
  fi
  if [ "$bien" = 1 ]; then OK=$((OK+1)); printf '  ok   %-46s %s\n' "$n" "$veredicto"
  else KO=$((KO+1)); printf '  FALLA %-46s esperaba %s/%s y dio %s\n' "$n" "$esp" "$chk" "$veredicto"
       printf '%s' "$SALIDA" | grep '\[FAIL\]' | head -3 | sed 's/^/         /'
  fi
}

# muta <fichero> <perl-expr> · ABORTA si el fichero no cambia
muta() {
  local f="$1"; shift
  local a; a="$(md5sum "$f" | cut -d' ' -f1)"
  perl -0777 -pi -e "$1" "$f"
  local b; b="$(md5sum "$f" | cut -d' ' -f1)"
  [ "$a" != "$b" ] || { echo "  🔴 LA MUTACION NO CAMBIO NADA: $f"; KO=$((KO+1)); return 1; }
}

echo "== base: un sitio minimo tiene que salir VERDE en LAS DOS convenciones =="
echo "   (si esto fallara, ningun caso de abajo distinguiria su fallo del ruido)"
sitio_base "$T/base-dir"   dir-barra ; caso "base · carpeta/index.html"        VERDE - "$T/base-dir"
sitio_base "$T/base-plano" plano     ; caso "base · fichero plano sin ext"     VERDE - "$T/base-plano"

echo
echo "== los que tienen que salir ROJOS (si alguno sale verde, el gate esta ciego) =="

sitio_base "$T/c1" dir-barra
muta "$T/c1/index.html" 's{</main>}{<a href="/no-existe-de-verdad">x</a></main>}' \
  && caso "enlace roto de verdad (convencion carpeta)"  ROJO S3.1 "$T/c1"

sitio_base "$T/c2" plano
muta "$T/c2/index.html" 's{</main>}{<a href="/no-existe-de-verdad">x</a></main>}' \
  && caso "enlace roto de verdad (convencion plana)"    ROJO S3.1 "$T/c2"

sitio_base "$T/c3" dir-barra
muta "$T/c3/sitemap.xml" 's{</urlset>}{<url><loc>https://ejemplo.test/fantasma</loc></url></urlset>}' \
  && caso "sitemap apunta a una pagina que no existe"   ROJO S1.2 "$T/c3"

sitio_base "$T/c4" plano
muta "$T/c4/sitemap.xml" 's{<url><loc>https://ejemplo.test/contacto</loc></url>}{}' \
  && caso "pagina indexable fuera del sitemap"          ROJO S1.3 "$T/c4"

sitio_base "$T/c5" dir-barra
muta "$T/c5/index.html" 's{<title>[^<]*</title>}{}' \
  && caso "pagina sin <title>"                          ROJO S2.1 "$T/c5"

sitio_base "$T/c6" dir-barra
muta "$T/c6/index.html" 's{<title>[^<]*</title>}{<title>Marca</title>}' \
  && caso "<title> que es SOLO la marca"                ROJO S2.1 "$T/c6"

sitio_base "$T/c7" dir-barra
muta "$T/c7/contacto/index.html" 's{<title>[^<]*</title>}{<title>Portada de prueba | Marca</title>}' \
  && caso "dos paginas con el MISMO <title>"            ROJO S2.8 "$T/c7"

sitio_base "$T/c8" dir-barra
muta "$T/c8/index.html" 's{<link rel="canonical"[^>]*>}{}' \
  && caso "pagina sin canonical"                        ROJO S2.3 "$T/c8"

sitio_base "$T/c9" dir-barra
muta "$T/c9/index.html" 's{<h1>}{<h1>a</h1><h1>}' \
  && caso "pagina con dos <h1>"                         ROJO S2.5 "$T/c9"

sitio_base "$T/c10" dir-barra
muta "$T/c10/index.html" 's{<html lang="es">}{<html>}' \
  && caso "<html> sin lang"                             ROJO S2.6 "$T/c10"

sitio_base "$T/c11" dir-barra
muta "$T/c11/index.html" 's{<p>Texto.</p>}{<p>Cl\xc3\x83\xc2\xadnica</p>}' \
  && caso "mojibake en una pagina"                      ROJO S4.1 "$T/c11"

sitio_base "$T/c12" dir-barra
muta "$T/c12/index.html" 's{<a href="/contacto">Contacto</a>}{}' \
  && caso "pagina huerfana (0 entrantes)"               ROJO S3.2 "$T/c12"

sitio_base "$T/c13" dir-barra
muta "$T/c13/index.html" 's{<link rel="stylesheet"[^>]*>}{}' \
  && caso "pagina sin hoja de estilos"                  ROJO S5.1 "$T/c13"

echo
echo "== los que tienen que salir VERDES (los que impiden acusar a un sitio correcto) =="

sitio_base "$T/v1" plano
caso "sitemap sin extension + ficheros .html"           VERDE - "$T/v1"

sitio_base "$T/v2" dir-barra
muta "$T/v2/index.html" 's{<title>[^<]*</title>}{<title>Contacto | Marca</title>}' \
  && muta "$T/v2/contacto/index.html" 's{<title>[^<]*</title>}{<title>Quienes somos | Marca</title>}' \
  && caso "titulo CORTO pero real (no es solo la marca)" VERDE - "$T/v2"

sitio_base "$T/v3" dir-barra
mv "$T/v3/_audit.conf" "$T/v3/audit.conf"
caso "acepta audit.conf ademas de _audit.conf"          VERDE - "$T/v3"

sitio_base "$T/v4" dir-barra
muta "$T/v4/index.html" 's{<p>Texto.</p>}{<p>IRM\xc3\x83OS e \xc3\x93RG\xc3\x83OS</p>}' \
  && caso "portugues legitimo (IRMAOS) NO es mojibake"  VERDE - "$T/v4"

echo
echo "== las 3 reglas del estandar que hasta hoy no medía nadie =="

sitio_base "$T/n1" dir-barra
muta "$T/n1/index.html" 's{<meta charset="utf-8">}{<meta charset="utf-8"><meta name="viewport" content="width=device-width, user-scalable=no">}' \
  && caso "zoom bloqueado (user-scalable=no)"           ROJO S2.10 "$T/n1"

sitio_base "$T/n2" dir-barra
muta "$T/n2/index.html" 's{<p>Texto.</p>}{<p>Llamanos al +34 917 737 078</p>}' \
  && caso "telefono VISIBLE sin enlace tel:"            ROJO S2.11 "$T/n2"

sitio_base "$T/n3" dir-barra
# OJO: el reemplazo de s{}{} en perl es de comillas DOBLES, asi que `@type` se
# interpolaba como un array vacio y el fixture quedaba con {"":"Article"}: el
# caso salia VERDE y parecia que el check estaba ciego. Se construye con printf.
printf '%s' '<script type="application/ld+json">{"@type":"Article"}</script><script type="application/ld+json">{"@type":"TechArticle"}</script>' > "$T/n3.frag"
muta "$T/n3/index.html" 's{</head>}{XFRAGX</head>}' \
  && perl -0777 -pi -e 'BEGIN{open my $g,"<","$ENV{T}/n3.frag"; local $/; $F=<$g>} s{XFRAGX}{$F}' "$T/n3/index.html" \
  && caso "declara Article Y TechArticle"               ROJO S2.12 "$T/n3"

sitio_base "$T/n4" dir-barra
muta "$T/n4/index.html" 's{</head>}{<script type="application/ld+json">{"telephone":"+34917737078"}</script></head>}' \
  && caso "telefono SOLO en el JSON-LD: NO es fallo"    VERDE - "$T/n4"

echo
echo "== la guarda: sin --root NO mide la carpeta del script =="
bash "$AUD" >/dev/null 2>&1
if [ $? -eq 2 ]; then OK=$((OK+1)); printf '  ok   %-46s rc=2\n' "sin --root aborta"
else KO=$((KO+1)); printf '  FALLA %-46s tenia que abortar con rc=2\n' "sin --root aborta"; fi

rm -rf "$T"
echo
echo "-------------------------------------------------------------"
# El formato lo manda run-all.sh: busca `OK <n>` y `MAL <n>`. Con
# "24 ok" en minusculas leia CERO y pintaba «0 casos» con un PASA al lado --
# «un cero con cara de aprobado», que es literalmente lo que su propio
# comentario avisa que ya paso una vez con el banco del hook.
printf "  BANCO audit.sh:  OK %d  ·  MAL %d\n" "$OK" "$KO"
echo "-------------------------------------------------------------"
[ "$KO" -eq 0 ] || exit 1
