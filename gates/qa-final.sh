#!/usr/bin/env bash
# =============================================================================
#  qa-final.sh - QA FINAL sobre el sitio PUBLICADO
# =============================================================================
#  Uso:  bash qa-final.sh https://dominio.tld [/ruta-de-contacto]
#
#  ⚠️ NO SUSTITUYE A LOS OTROS GATES, LOS CIERRA.
#    audit-vs-source.sh  -> inventario contra SU CODIGO   (¿falta una categoria?)
#    _audit.sh           -> estructura del HTML generado  (¿esta bien el build?)
#    fidelidad           -> texto suyo en el nuestro      (¿se perdio contenido?)
#    qa-final.sh         -> EL SITIO PUBLICADO, como lo vive un visitante
#
#  Los tres primeros miran el BUILD o la FUENTE. Ninguno mira lo publicado ni
#  cruza dimensiones, y por eso se escaparon og:image, la medicion entera y 9
#  de 11 eventos: no estaban en ninguna lista, y nadie recorria el sitio vivo.
#
#  ⚠️ ESTE SCRIPT SOLO VE LO QUE SE LE HA ESCRITO. La parte que de verdad
#  encuentra lo inesperado es el BLOQUE B (mirar) y el C (preguntas), que estan
#  en `08-qa-final.md` y NO se pueden automatizar. Si solo se corre el script,
#  el QA esta a medias.
#
#  Salida: PASA / FALLO / MIRAR por linea. Exit != 0 si hay algun FALLO.
# =============================================================================
set -u
B="${1:?uso: qa-final.sh https://dominio.tld [/contacto]}"; B="${B%/}"
CONTACT="${2:-}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; look=0
pass(){ printf "  PASA   %-34s %s\n" "$1" "${2:-}"; }
bad(){  printf "  FALLO  %-34s %s\n" "$1" "${2:-}"; fail=$((fail+1)); }
mira(){ printf "  MIRAR  %-34s %s\n" "$1" "${2:-}"; look=$((look+1)); }

G(){ curl -s --compressed --max-time 25 "$1" 2>/dev/null | tr -d '\000'; }
C(){ curl -s -o /dev/null -w '%{http_code}' --max-time 25 "$1" 2>/dev/null; }
# ⚠️ perl multilinea: un `sed` por lineas NO quita los <script>, y entonces el
#    Consent Mode se cuela como "texto" del sitio.
TXT(){ perl -0777 -pe 's{<script.*?</script>}{}gs; s{<style.*?</style>}{}gs'; }

HOST="${B#https://}"; HOST="${HOST#http://}"
echo "########## QA FINAL · $B ##########"

# ── 1. ENTREGA ───────────────────────────────────────────────────────────────
echo "-- 1. Entrega"
exp=$(echo | openssl s_client -connect "$HOST:443" -servername "$HOST" 2>/dev/null \
      | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
e=$(date -u -d "$exp" +%s 2>/dev/null || echo 0); now=$(date -u +%s)
d=$(( (e-now)/86400 ))
if   [ "$e" -le "$now" ]; then bad "certificado" "CADUCADO ($exp)"
elif [ "$d" -lt 15 ];      then mira "certificado" "caduca en $d dias"
else pass "certificado" "$d dias"; fi

san=$(echo | openssl s_client -connect "$HOST:443" -servername "$HOST" 2>/dev/null \
      | openssl x509 -noout -ext subjectAltName 2>/dev/null | tail -1)
wip=$(nslookup -type=A "www.$HOST" 8.8.8.8 2>/dev/null | grep -A2 'Name:' | grep Address | tail -1 | awk '{print $2}')
if [ -z "$wip" ]; then mira "www" "no resuelve: quien lo teclee no llega"
else
  wc=$(curl -s -o /dev/null -w '%{http_code}|%{ssl_verify_result}' --max-time 20 "https://www.$HOST/" 2>/dev/null)
  case "$wc" in *"|0") pass "www" "$wc";; *) bad "www" "resuelve pero responde $wc";; esac
fi

# ⚠️ SIN -k. Con -k esto no significa nada: es la bandera que oculta un
#    certificado caducado, que es lo unico que rompe la web el dia del cambio.
G "$B/sitemap.xml" | grep -oP '(?<=<loc>)[^<]+' > "$T/urls.txt" || true
N=$(grep -c . "$T/urls.txt" 2>/dev/null || echo 0)
if [ "$N" = "0" ]; then bad "sitemap.xml" "no existe o esta vacio"; echo "$B/" > "$T/urls.txt"; N=1
else pass "sitemap.xml" "$N URLs"; fi
b200=0
while read -r u; do [ -z "$u" ] && continue
  c=$(C "$u"); [ "$c" != "200" ] && { bad "URL indexada" "$c $u"; b200=$((b200+1)); }
done < "$T/urls.txt"
[ "$b200" = "0" ] && pass "URLs del sitemap" "$N/$N en 200"
for f in robots.txt llms.txt; do
  [ "$(C "$B/$f")" = "200" ] && pass "$f" || bad "$f" "no responde 200"
done
ent=$(G "$B/llms.txt" | grep -o '&[a-zA-Z]\+;\|&#x\?[0-9a-fA-F]\+;' | wc -l)
[ "$ent" -eq 0 ] && pass "llms.txt sin entidades" || bad "llms.txt" "$ent entidades HTML en texto plano"

# ── 2. CONTENIDO ─────────────────────────────────────────────────────────────
echo "-- 2. Contenido"
: > "$T/t.txt"; noog=0; badcan=0; noalt=0; nodesc=0
while read -r u; do [ -z "$u" ] && continue
  h=$(G "$u")
  printf '%s\n' "$h" | grep -oP '(?<=<title>)[^<]*' | head -1 >> "$T/t.txt"
  printf '%s\n' "$h" | grep -q 'og:image' || { noog=$((noog+1)); [ "$noog" -le 2 ] && bad "og:image" "$u"; }
  printf '%s\n' "$h" | grep -q 'name="description"' || nodesc=$((nodesc+1))
  can=$(printf '%s\n' "$h" | grep -oP '(?<=rel="canonical" href=")[^"]+' | head -1)
  [ -n "$can" ] && [ "${can%/}" != "${u%/}" ] && { badcan=$((badcan+1)); bad "canonical != self" "$u -> $can"; }
  # ⚠️ `grep -o ... | wc -l` cuenta OCURRENCIAS. `grep -c` contaria lineas.
  na=$(printf '%s\n' "$h" | grep -o '<img[^>]*>' | grep -v 'alt=' | wc -l)
  [ "$na" -gt 0 ] && noalt=$((noalt+1))
done < "$T/urls.txt"
[ "$noog"   = "0" ] && pass "og:image en todas"
[ "$badcan" = "0" ] && pass "canonical apunta a si misma"
[ "$nodesc" = "0" ] && pass "meta description" || bad "meta description" "$nodesc sin ella"
[ "$noalt"  = "0" ] && pass "alt en imagenes" || bad "alt" "$noalt paginas con <img> sin alt"
# ⚠️ wc -l, NO `grep -c . || echo 0`: grep -c YA imprime 0 y sale con 1, asi que
# el fallback anade un segundo 0 y la comparacion numerica revienta. Detectado
# validando este mismo script contra un sitio que sabiamos bueno.
dup=$(sort "$T/t.txt" | uniq -d | wc -l)
if [ "$dup" -eq 0 ]; then pass "titles unicos"; else
  bad "titles duplicados" "$dup"; sort "$T/t.txt" | uniq -d | head -3 | sed 's/^/            /'; fi

# ── 3. MEDICION ──────────────────────────────────────────────────────────────
echo "-- 3. Medicion"
h=$(G "$B/")
gtm=$(printf '%s\n' "$h" | grep -oE 'GTM-[A-Z0-9]+' | head -1)
if [ -z "$gtm" ]; then
  mira "sin contenedor" "correcto si el cliente no mide; FALLO si hace publicidad"
else
  pass "contenedor" "$gtm"
  # ⚠️ Patron tolerante a espacios: `consent', 'default'` no casa con
  #    `consent'*,*'*default`. Ese error dio un falso FALLO en la auditoria.
  cp=$(printf '%s\n' "$h" | grep -bo "consent'\?,\? *'\?default" | head -1 | cut -d: -f1)
  gp=$(printf '%s\n' "$h" | grep -bo 'googletagmanager.com/gtm.js' | head -1 | cut -d: -f1)
  if   [ -z "$cp" ];                 then bad  "consent default" "NO EXISTE: cookies antes de aceptar"
  elif [ "$cp" -lt "${gp:-999999}" ]; then pass "consent default" "antes de GTM"
  else bad "consent default" "DESPUES de GTM: las cookies ya estan puestas"; fi
  printf '%s\n' "$h" | grep -qiE 'cookie|consent' && pass "banner" || bad "banner" "GTM sin banner"
  for id in $(G "https://www.googletagmanager.com/gtm.js?id=$gtm" | grep -oE 'AW-[0-9]+|G-[A-Z0-9]{8,}' | sort -u); do
    pass "dentro del contenedor" "$id"
  done
  # ⚠️ Los eventos pueden venir de DOS formas y hay que mirar las dos:
  #    · atributos `data-event` en el marcado
  #    · un listener DELEGADO en el JS, que no deja ni rastro en el HTML
  #    Contando solo lo primero, un sitio con la medicion correcta sale con
  #    "0 tipos" -pasó con Clinica BC- y ese aviso se acaba ignorando.
  #    Ninguna de las dos comprobaciones prueba que DISPAREN: eso es el bloque B.
  ev=$(printf '%s\n' "$h" | grep -o 'data-event="[a-z_]*"' | sort -u | wc -l)
  js=$(printf '%s\n' "$h" | grep -oP '(?<=src=")/[a-z0-9./_-]+\.js' | head -3)
  dele=0
  for j in $js; do
    G "$B$j" | grep -q "phone_click\|data-event\|dataLayer.push" && dele=1
  done
  if   [ "$ev" -ge 2 ];  then pass "eventos" "$ev tipos en el marcado"
  elif [ "$dele" -eq 1 ]; then mira "eventos" "por listener delegado en el JS: comprobar EN EL NAVEGADOR que disparan (bloque B)"
  else bad "eventos" "no se emite ninguno: sus conversiones miden cero"; fi
fi

# ── 4. CONTACTO ──────────────────────────────────────────────────────────────
echo "-- 4. Contacto"
CU="$B$CONTACT"
[ -z "$CONTACT" ] && CU=$(grep -iE '/contact|/contacto|/kontakt' "$T/urls.txt" | head -1)
if [ -z "$CU" ]; then mira "pagina de contacto" "no encontrada en el sitemap"
else
  cb=$(G "$CU")
  nf=$(printf '%s\n' "$cb" | grep -o '<form' | wc -l)
  if [ "$nf" -eq 0 ]; then
    mira "formulario" "0 en el HTML de $CU (¿se pinta en cliente?)"
  else
    act=$(printf '%s\n' "$cb" | grep -oP '<form[^>]*action="\K[^"]+' | head -1)
    if [ -z "$act" ]; then
      # 🔴 El fallo de Site A y el de BC: sin action y con mailto en la pagina.
      if printf '%s\n' "$cb" | grep -q 'mailto:'; then
        bad "formulario" "SIN action y con mailto: no envia si no hay cliente de correo, y no queda copia"
      else
        bad "formulario" "SIN action: comprobar a donde envia de verdad"
      fi
    else
      pass "formulario" "action=$act"
      [ "$(C "$B$act")" = "404" ] && bad "receptor" "$act devuelve 404"
    fi
  fi
  printf '%s\n' "$cb" | grep -q 'leadconnector\|gohighlevel\|hubspot\|typeform' \
    && mira "CRM de terceros" "verificar que la cuenta sigue viva"
fi

# ── 5. PRIVACIDAD Y HONESTIDAD ───────────────────────────────────────────────
echo "-- 5. Privacidad y honestidad"
# ⚠️ NO basta con mirar src= y href=: GTM se inyecta desde un script INLINE, y
#    con el patron de etiquetas salia "0 terceros" en un sitio que carga GTM.
#    Se buscan tambien los dominios citados dentro de <script>. Sigue sin ver lo
#    que un tercero cargue a su vez: para eso, el bloque B (panel de red).
third=$( { printf '%s\n' "$h" | grep -oP '<(script|link)[^>]*(src|href)="https?://\K[a-z0-9.-]+'
           printf '%s\n' "$h" | grep -oP "<script[^>]*>.*?</script>" \
             | grep -oP "['\"]https?://\K[a-z0-9.-]+" ; } \
         | sort -u | grep -v "$HOST" | grep -vE '^(schema\.org|www\.w3\.org)$')
nt=$(printf '%s' "$third" | grep -c . )
if [ "$nt" -eq 0 ]; then pass "terceros" "ninguno"
else printf "  MIRAR  %-34s %s\n" "terceros que CARGAN" "$(printf '%s' "$third" | paste -sd' ' -)"; look=$((look+1)); fi
printf '%s' "$third" | grep -q 'fonts.googleapis' \
  && bad "Google Fonts enlazado" "tercero + IP del visitante a Google (RGPD). Autoalojar"
if printf '%s\n' "$h" | grep -q 'SearchAction'; then
  printf '%s\n' "$h" | TXT | grep -qE 'type="search"|role="search"' \
    && pass "SearchAction" "hay buscador" \
    || bad "SearchAction" "declarado y NO hay buscador: senal negativa"
fi
if [ -n "$gtm" ]; then
  # ⚠️ NO se busca en el sitemap: las paginas legales suelen estar EXCLUIDAS a
  #    proposito, y eso daba un FALLO falso en un sitio que si la tiene.
  #    Se prueban las rutas habituales por HTTP, que es lo que ve un visitante.
  pc=""
  for r in /politique-cookies /politica-cookies /politica-de-cookies /cookies /cookie-policy; do
    [ "$(C "$B$r")" = "200" ] && { pc="$r"; break; }
  done
  [ -z "$pc" ] && printf '%s\n' "$h" | grep -qoP 'href="\K[^"]*cookie[^"]*' \
    && pc=$(printf '%s\n' "$h" | grep -oP 'href="\K[^"]*cookie[^"]*' | head -1)
  [ -n "$pc" ] && pass "politica de cookies" "$pc" || bad "politica de cookies" "hay GTM y no hay pagina"
fi
for p in /_leads/ /_secrets/ /check-smtp.php /check-bounces.php; do
  c=$(C "$B$p"); [ "$c" = "200" ] && bad "expuesto por web" "$p responde 200"
done

echo "----------------------------------------------------------"
echo "  FALLOS: $fail   ·   A MIRAR: $look"
[ "$fail" -eq 0 ] && echo "  Bloque A en verde. FALTAN LOS BLOQUES B y C de 08-qa-final.md." \
                  || echo "  No se cierra el proyecto con FALLOS abiertos."
exit "$fail"
