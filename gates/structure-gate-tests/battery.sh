#!/usr/bin/env bash
set -u
D="$(cd "$(dirname "$0")" && pwd)"

# =============================================================================
#  🔴 18-ago-2026 · RECUENTO. Este banco existia SIN CABLEAR y sin numero:
#  imprimia catorce lineas y salia 0 pasara lo que pasara, asi que ningun runner
#  podia saber si habia ido bien. Un banco escrito y descolgado parece cobertura
#  y no lo es.
#
#  P2, P3 y F3 dan REVISAR desde el 10-ago-2026 y NO es por el gate: miden
#  paginas VIVAS que se bajan con curl, o sea reglas viejas sobre HTML nuevo
#  (verificado entonces reconstruyendo el gate sin los cambios de ese dia: ya
#  fallaban los tres). Se congelan por nombre. Lo que este recuento vigila no es
#  que sean cero, es que **no aparezca uno nuevo** -- y que no desaparezca
#  ninguno, porque un REVISAR que se cura solo suele significar que el gate ha
#  dejado de mirar.
CONOCIDOS=" P2-site-d-page P3-site-d-home F3-privaci "
OK=0; MAL=0; NM=0; VISTOS=""; NM_IDS=""

res(){
  local id="$1" f="$2" b="$3" c="$4" esp="$5"
  #  🔴 A CASE WHOSE FIXTURE IS NOT HERE IS NOT A PASS AND NOT A FAILURE.
  #     Eight of the fixtures this battery was written against are frozen copies
  #     of real client pages, and they are deliberately not published. Counting
  #     them as failures would send somebody hunting a defect that does not
  #     exist; counting them as passes would let a hole read as coverage — which
  #     is the single failure mode this whole repository is about.
  #     They are counted separately and the battery exits 3 (NOT MEASURED) if any
  #     of them was skipped and nothing else failed. Regenerate one against a
  #     site you own with `../qa-master-tests/freeze-fixture.pl`, or point this
  #     case at a page of your own.
  if [ ! -f "$D/$f" ]; then
    NM=$((NM+1)); NM_IDS="$NM_IDS $id"
    printf "%-16s | esp %-5s | NOT MEASURED — fixture %s is not published\n" "$id" "$esp" "$f"
    return
  fi
  local j; j=$("$D/run-gate.sh" "$id" "$D/$f" "$b" "$c" 2>/dev/null)
  local v iw tipo prosa
  v=$(echo "$j"     | grep '"VEREDICTO"' | grep -o 'PASA\|FALLA' | head -1)
  iw=$(echo "$j"    | grep '"innerWidth"' | grep -o '[0-9]\+' | head -1)
  tipo=$(echo "$j"  | grep '"tipo"' | head -1 | sed 's/.*: "//; s/",*$//')
  prosa=$(echo "$j" | grep '"esPaginaProsa"' | grep -o 'true\|false')
  local estado
  if [ "${v:-x}" = "$esp" ]; then estado=OK; else estado=REVISAR; fi
  # 🔴 innerWidth SIEMPRE: Chrome clampa el ancho y una medida que no coincide
  # con lo pedido no es un resultado, es basura. No cuenta como OK.
  if [ "$estado" = OK ] && [ -n "$iw" ]; then
    OK=$((OK+1))
  elif [ "$estado" = REVISAR ]; then
    case "$CONOCIDOS" in
      *" $id "*) OK=$((OK+1)); VISTOS="$VISTOS $id" ;;   # REVISAR congelado y esperado
      *)         MAL=$((MAL+1)) ;;
    esac
  else
    MAL=$((MAL+1))
  fi
  printf "%-16s | esp %-5s | obt %-5s | %-7s | prosa=%-5s | iw=%s | %s\n" \
         "$id" "$esp" "${v:-ERROR}" "$estado" "$prosa" "$iw" "$tipo"
}

# --- se regenera el control positivo antes de medirlo -----------------------
# El orden cubre la anatomia de `home` de 09 §2 (hero·prueba·oferta·proceso·
# cierre) y mete 16-galeria para que la pagina tenga medios, como los tiene una
# home de verdad. `fill-hrefs.awk` da destinos reales a los href="#".
"$D/mk-mould.sh" "$D/work/mh-arr-raw.html" 01 06 03 02 16 09 05 08 11 >/dev/null || exit 1
awk -f "$D/fill-hrefs.awk" "$D/work/mh-arr-raw.html" > "$D/mould-home-fixed.html"

echo "=========== CONTROLES POSITIVOS (deben PASAR) ==========="
res P1-molde     mould-home-fixed.html -                                                        '{"tipo":"home","ruta":"/"}' PASA
# ⚠️ P2 y P3 dan REVISAR desde el 10-ago-2026, y NO es por el gate.
# Las paginas reales no estan versionadas aqui (se bajan con curl y cambian).
# Comprobado con el gate RECONSTRUIDO SIN los cambios de ese dia (ANCHO-MIN,
# CONTRASTE, aviso de cplMediana, heroe sobre el pliegue, bloque de preambulo):
#   P2 ya FALLABA por  ANCHO · 1 parrafo a 86 cpl
#   P3 ya FALLABA por  VARIEDAD · 3 primitivas [hero, rejilla, par-alterno]
#   F3 ya FALLABA por  ANCHO · 20 parrafos a 86 cpl
# Es decir: los tres fallan por reglas VIEJAS sobre HTML NUEVO. La expectativa
# «PASA» se fijo contra una copia que ya no es la que sirve el sitio.
# Se deja en PASA a proposito: es lo que esas paginas DEBEN hacer, y ponerlas en
# FALLA seria dar por bueno el defecto. Lo que hay que arreglar es la pagina.
# 🔴 Ademas, con CONTRASTE ya medido, P2 y P3 tienen un defecto REAL que nadie
#    habia medido nunca: el boton primario `a.btn` de site-d.example esta a
#    4,02:1 (AA exige 4,5:1) — texto oklch(0.99 0.005 210) sobre fondo
#    oklch(0.58 0.09 210). Se arregla bajando la L del fondo, no el gate.
res P2-site-d-page   site-d-implantes.html    https://site-d.example/odontologia/implantes-dentales    '{}'                         PASA
res P3-site-d-home    site-d-home.html         https://site-d.example/                                  '{}'                         PASA
echo
echo "=========== CONTROLES NEGATIVOS (deben FALLAR) =========="
res N1-cm-learn   cm-learn.html        https://climentmedia.com/learn/what-is-a-good-roas/           '{}'                         FALLA
res N2-site-a      site-a-services.html   https://site-a.example/services.html                        '{}'                         FALLA
res N3-site-c      site-c-home.html       https://site-c.example/                                   '{}'                         FALLA
res N4-fabric    prose-fabricated.html https://climentmedia.com/learn/guia-roas/                     '{}'                         FALLA
echo
echo "=========== ANCHO-MIN · la home rota que APROBABA EN VACIO ======"
# `mould-home-broken.html` es la home compuesta ANTES de que los moldes pasaran a
# `_base.css`: 4 de 7 secciones a 568px y celdas de 173-189px. El gate la daba
# por buena con `fallos: []` y `cplMediana: null`. Es un fixture CONGELADO: no
# se regenera, existe para que ese fallo no pueda volver sin que salte.
res A1-mh-roto   mould-home-broken.html -                                                             '{"tipo":"home","ruta":"/"}' FALLA
echo
echo "=========== CONTRASTE · control positivo Y negativo en la misma pagina ==="
# 4 casos que DEBEN fallar (uno en oklch, uno con alfa) y 4 que DEBEN pasar
# (uno en oklch oscuro, uno por texto grande). Una regla que solo se ha visto en
# verde no prueba nada.
res C1-contraste contrast-control.html https://climentmedia.com/control-contraste/                 '{"tipo":"guia"}'            FALLA
echo
echo "=========== FRONTERA (textual legitima: NO acusar) ======"
res F1-legal     site-d-legal.html        https://site-d.example/aviso-legal                       '{}'                         PASA
res F1b-forzad   site-d-legal.html        https://site-d.example/aviso-legal                       '{"tipo":"servicio"}'        FALLA
res F2-guialar   guide-laid-out.html  https://climentmedia.com/learn/guia-roas-maquetada/           '{}'                         PASA
# 🔴 20-ago-2026 · El MISMO fichero de arriba con las primeras palabras de cada
# parrafo envueltas en <strong>: mismo texto visible, mismo ancho, misma
# maqueta. Salia FALLA con `cplMediana: 17` porque `cplReal` media desde el
# primer nodo de texto SUELTO, que en un parrafo que empieza con un elemento en
# linea arranca a mitad de linea. En la portada de climentmedia un parrafo de
# 544px con ~73 cpl reales devolvia **2**. El falso positivo solo hunde la
# mediana, nunca la sube: siempre acusa de "linea demasiado corta".
res F4-strong    cpl-leading-strong.html https://climentmedia.com/learn/guia-roas-maquetada/        '{}'                         PASA
echo
echo "=========== FRONTERA 2 · politica de privacidad REAL y larga ============"
res F3-privaci   site-c-privacidad.html https://site-c.example/politica-privacidad/               '{}'                         PASA
res F3b-forzad   site-c-privacidad.html https://site-c.example/politica-privacidad/               '{"tipo":"guia"}'            FALLA

echo
echo "=========== FRONTERA 3 - ANCHO-MIN: rejilla SI, fila de botones NO ======="
# 24-ago-2026. Los dos fixtures tienen una seccion cuyo contenedor mide 510px,
# por debajo del suelo de 840. La UNICA diferencia es que hay dentro:
#   fila-de-botones   -> dos <a class="btn">     NO es una rejilla. No debe acusar.
#   rejilla-estrujada -> tres tarjetas de texto  SI lo es.         Debe acusar.
#
# `res` no sirve aqui: los dos dan FALLA por otras reglas (anatomia, variedad),
# asi que comparar el VEREDICTO no distingue. Se mira la regla concreta, que es
# lo unico que prueba lo que dice probar.
#
# 🔴 EL ROJO ES EL QUE VALE. El primer intento de arreglar el falso positivo
# excluia tambien los hijos que CONTIENEN una accion, y eso se llevaba por
# delante las tarjetas de verdad -una tarjeta cuyo titulo es un enlace lo
# cumple-: `celdasDe` devolvia vacio y ANCHO-MIN dejaba de mirar del todo. La
# bateria de 879 casos paso en verde con esa version dentro. Lo caza este par.
ancho_min(){
  local id="$1" f="$2" esp="$3"
  local n; n=$("$D/run-gate.sh" "$id" "$D/$f" - '{"tipo":"servicio","ruta":"/x/"}' 2>/dev/null | grep -c "ANCHO-MIN")
  local hay=no; [ "${n:-0}" -gt 0 ] && hay=si
  if [ "$hay" = "$esp" ]; then OK=$((OK+1)); printf "  OK      %-14s ANCHO-MIN=%s (esperado %s)\n" "$id" "$hay" "$esp";
  else MAL=$((MAL+1)); printf "  REVISAR %-14s ANCHO-MIN=%s y se esperaba %s\n" "$id" "$hay" "$esp"; fi
}
ancho_min G1-btnfila  button-row.html    no
ancho_min G2-rejmala  grid-squeezed.html  si

echo
echo "=========== FRONTERA 4 - cpl no se le exige a quien no es prosa =========="
# Una pagina de contacto legitima no tiene parrafos de 200+ caracteres, y no
# debe tenerlos. Antes del 24-ago el aviso de cpl saltaba igual y, con el de
# «bloques sin imagen», ya sumaba los DOS que bastan para fallar: NINGUNA
# pagina de contacto podia aprobar este gate. El forzado a `guia` es el rojo:
# una guia sin un solo parrafo de lectura SI es un defecto, y si alguien pone
# `lectura:false` en todos los perfiles «para que deje de molestar», salta.
res G3-contacto  contact-real.html   -   '{"tipo":"contacto","ruta":"/contacto/"}'  PASA
res G3b-forzad   contact-real.html   -   '{"tipo":"guia","ruta":"/contacto/"}'      FALLA

echo
echo "=========== FRONTERA 5 - cpl: la rejilla NO es columna de lectura ========"
# 24-ago-2026. Los dos fixtures tienen parrafos de 200+ caracteres a ~285px.
# La UNICA diferencia es donde viven:
#   cpl-testimonios-rejilla -> en celdas de una rejilla de 3 columnas. NO avisa.
#   cpl-prosa-estrecha      -> prosa corrida en una columna de 285px. SI avisa.
#
# El filtro era `len >= 200`, una PROXY que da por hecho que una celda lleva
# texto corto. Un TESTIMONIO no: 10 de los 12 "parrafos de lectura" de
# /hipnosis-para-recuperar-a-tu-pareja-en-san-diego/ eran testimonios en
# tarjetas de 286px, y hundian la mediana a 34. Seis paginas de esa web salian
# acusadas de "linea demasiado corta" sin tenerla, cinco de ellas destino de
# los anuncios que paga la clienta.
#
# 🔴 EL ROJO ES EL QUE VALE, y aqui hizo falta de verdad: la primera version
# excluia CUALQUIER celda sin mirar cuantas columnas habia. Un par-alterno es
# una celda, asi que se llevo tambien la prosa buena y los parrafos de lectura
# de esa pagina pasaron de 12 a CERO. El aviso desaparecio porque el gate dejo
# de mirar, no porque la pagina mejorase. Con >=3 columnas quedo bien.
#
# `res` no sirve: los dos dan FALLA por otras reglas. Se mira la regla concreta.
aviso_cpl(){
  local id="$1" f="$2" esp="$3"
  local n; n=$("$D/run-gate.sh" "$id" "$D/$f" - '{"tipo":"servicio","ruta":"/x/"}' 2>/dev/null | grep -c "longitud de linea mediana")
  local hay=no; [ "${n:-0}" -gt 0 ] && hay=si
  if [ "$hay" = "$esp" ]; then OK=$((OK+1)); printf "  OK      %-16s aviso-cpl=%s (esperado %s)\n" "$id" "$hay" "$esp";
  else MAL=$((MAL+1)); printf "  REVISAR %-16s aviso-cpl=%s y se esperaba %s\n" "$id" "$hay" "$esp"; fi
}
aviso_cpl H1-testis   cpl-testimonial-grid.html  no
aviso_cpl H2-estrecha cpl-narrow-prose.html       si

# --- el numero, que es lo que faltaba ---------------------------------------
echo
for c in $CONOCIDOS; do
  #  A frozen REVISAR whose fixture was never measured cannot have "stopped
  #  giving REVISAR" — nobody asked it. Without this it would be reported as a
  #  gate that went quiet, which is a real and serious finding, and inventing one
  #  is how a battery teaches people to ignore it.
  case "$NM_IDS" in *" $c"*) continue ;; esac
  case "$VISTOS" in
    *" $c"*) : ;;
    *) echo "  🔴 $c ya NO da REVISAR. Puede ser bueno -- o puede ser que el gate"
       echo "     haya dejado de mirar. Se comprueba a mano y se saca de CONOCIDOS."
       MAL=$((MAL+1)) ;;
  esac
done
printf "  OK %d · MAL %d · NO MEDIDOS %d   (%d REVISAR congelados:%s)\n" \
       "$OK" "$MAL" "$NM" "$(echo $CONOCIDOS | wc -w)" "$CONOCIDOS"
if [ "$NM" -gt 0 ]; then
  echo
  echo "  🔎 NOT MEASURED:$NM_IDS"
  echo "     Their fixtures are frozen copies of real client pages and are not"
  echo "     published. This battery therefore did NOT cover those cases. Freeze"
  echo "     equivalents from a site you own to close the gap:"
  echo "         perl ../qa-master-tests/freeze-fixture.pl <URL> <name>.html"
fi
[ "$MAL" -eq 0 ] || exit 1
[ "$NM" -eq 0 ] || exit 3
