#!/usr/bin/env bash
# =============================================================================
#  Banco de `forms-gate.js` — el gate del PASO 10.
#
#  Corre con Chrome LOCAL a traves del arnes de `structure-gate-tests/
#  run-gate.sh` (5o argumento = el gate a evaluar). No usa el servidor a
#  proposito: un banco que necesita red se salta el dia que la red falla.
#
#  ⚠️ Los fixtures son AUTOCONTENIDOS -CSS en la propia pagina- porque el
#  defecto que este gate caza ES la ausencia de CSS. Un fixture que dependiera
#  de una hoja externa saldria «roto» tambien cuando la hoja no cargue, y no
#  sabriamos cual de las dos cosas se esta midiendo.
# =============================================================================
set -u
D="$(cd "$(dirname "$0")" && pwd)"
REF="$(cd "$D/.." && pwd)"
RUN="$REF/structure-gate-tests/run-gate.sh"
GATE="$REF/forms-gate.js"   # derived, not hard-coded to one machine
ok=0; ko=0

[ -f "$RUN" ] || { echo "  no encuentro run-gate.sh"; exit 2; }

# corre <id> <fixture> <json __GATE__> -> deja el JSON en $OUT
corre() {
  OUT="$("$RUN" "$1" "$D/fixtures/$2" - "$3" "$GATE" 2>/dev/null)"
}

# veredicto <etiqueta> <PASA|FALLA> <fixture> <json>
veredicto() {
  local eti="$1" esp="$2"; corre "f-$(echo "$eti" | tr -c 'a-zA-Z0-9' '-')" "$3" "$4"
  local v; v="$(printf '%s' "$OUT" | grep '"VEREDICTO"' | grep -o 'PASA\|FALLA' | head -1)"
  if [ "${v:-AUSENTE}" = "$esp" ]; then
    printf '  OK    %-52s -> %s\n' "$eti" "$v"; ok=$((ok+1))
  else
    printf '  MAL   %-52s esperaba %s y salio %s\n' "$eti" "$esp" "${v:-AUSENTE}"; ko=$((ko+1))
    printf '%s\n' "$OUT" | head -3 | sed 's/^/          /'
  fi
}

# contiene <etiqueta> <SI|NO> <literal> <fixture> <json>
contiene() {
  local eti="$1" quiero="$2" lit="$3"; corre "c-$(echo "$eti" | tr -c 'a-zA-Z0-9' '-')" "$4" "$5"
  local hay=NO; printf '%s' "$OUT" | grep -qF -- "$lit" && hay=SI
  if [ "$hay" = "$quiero" ]; then
    printf '  OK    %-52s %s "%s"\n' "$eti" "$quiero" "$lit"; ok=$((ok+1))
  else
    printf '  MAL   %-52s esperaba %s y salio %s\n' "$eti" "$quiero" "$hay"; ko=$((ko+1))
  fi
}

echo "==============================================================================="
echo "  GATE DE FORMULARIOS (paso 10) · 17-ago-2026"
echo "==============================================================================="
echo
echo "== EL CASO ROJO: los defectos que han estado EN PRODUCCION"
# 🔴 F3 es el que justifica el gate entero. En site-d el <form> llevaba
#    class="lead" -la ENTRADILLA de esa hoja, un parrafo-, asi que `.lead`
#    devolvia una regla y el formulario parecia estilado. Sin CSS propio, el
#    campo cepo se pintaba en pantalla poniendo «No rellenar»: un humano lo
#    rellena y su solicitud se DESCARTA EN SILENCIO. Medido hoy en vivo sobre
#    https://site-d.example/contacto -- sigue asi.
veredicto "el formulario roto FALLA"                    FALLA roto.html '{}'
contiene  "F3 · dice que el CEPO se ve"                 SI "el campo CEPO"      roto.html '{}'
contiene  "F3 · y lo nombra"                            SI "website"           roto.html '{}'
# F4: su web original enviaba por mailto:, que abre el cliente de correo del
# visitante y no manda nada si no tiene uno configurado.
contiene  "F4 · caza el envio por mailto:"              SI "envia por mailto"   roto.html '{}'
# F2: el placeholder no es una etiqueta -- desaparece al escribir.
contiene  "F2 · caza el campo sin etiqueta"             SI "sin etiqueta"       roto.html '{}'
# F6: pedir correo y telefono sin casilla de consentimiento es RGPD sin cumplir.
contiene  "F6 · caza la falta de consentimiento"        SI "consentimiento"     roto.html '{}'
# F5: con un <div> por boton, quien navega con teclado no puede enviar.
contiene  "F5 · caza que el boton no es un boton"       SI "boton de envio real" roto.html '{}'

echo
echo "== EL CASO VERDE: el mismo formulario, arreglado"
# No es otro fichero: es el rojo con el cepo fuera de pantalla, action real,
# campos etiquetados, consentimiento que ENLAZA la politica y boton de verdad.
veredicto "el formulario correcto PASA"                 PASA  bueno.html '{}'
# 🔴 El cepo se esconde FUERA DE PANTALLA, no con display:none: hay bots que
#    ignoran los campos ocultos con display, y entonces el cepo deja de cazar.
#    El gate lo avisa, y aqui se comprueba que NO avisa cuando esta bien hecho.
contiene  "y no protesta por el cepo bien escondido"    NO   "display:none"     bueno.html '{}'
contiene  "el consentimiento enlaza la politica"        NO   "no ENLAZA"        bueno.html '{}'

echo
echo "== LOS CONTROLES QUE DECIDEN SI EL GATE SE PUEDE ENCENDER"
# 🔴 SIN ESTE, el gate acusaria al 90 % del parque: la mayoria de las paginas
#    NO tienen formulario y con toda la razon (una guia, un hub, un legal). Un
#    gate que da falsos positivos en masa se desactiva, que es peor que no
#    tenerlo.
veredicto "una guia sin formulario NO se acusa"         PASA  sin-formulario.html '{}'
# Y la otra mitad: la pagina de contacto que se ha quedado SIN formulario si
# hay que cazarla. Es el mismo fichero con la configuracion del que lo exige,
# asi que el control prueba la CONFIGURACION, no dos ficheros distintos.
veredicto "pero si se exige, la falta SI falla"         FALLA sin-formulario.html '{"exigeFormulario":true}'

echo
echo "== LO QUE EL GATE NO PUEDE SABER, Y LO DICE"
# 🔴 El defecto que ya nos costo un cliente: en site-a el formulario mostraba
#    EXITO con el CRM de destino dado de baja. Nada en el DOM lo delata. Si el
#    gate callara, un PASA se leeria como «el formulario funciona».
contiene  "F10 · declara que no sabe si el correo llega" SI "QUE EL CORREO LLEGUE" bueno.html '{}'
# 🔴 F9 NO se puede probar sobre `roto.html`: alli el "boton" es un <div>, F5 ya
#    falla, y F9 no llega a evaluarse -- que es lo correcto, porque sin boton de
#    envio hablar de doble envio es ruido. Mi primer intento lo probaba ahi y
#    salio MAL: el caso estaba mal elegido, no el gate.
#    `sin-guarda.html` es `bueno.html` MENOS la declaracion, y prueba las dos
#    mitades: sigue saliendo PASA **y** el gate dice que no lo ha verificado.
contiene  "F9 · y la guarda de doble envio, si no consta" SI "DOBLE ENVIO"      sin-guarda.html '{}'
veredicto "un formulario perfecto sin declararla, PASA"  PASA sin-guarda.html '{}'
contiene  "y en el que SI la declara, calla"             NO  "DOBLE ENVIO"      bueno.html '{}'

echo
echo "-----------------------------------------------------------------"
printf "  OK %d   ·   MAL %d\n" "$ok" "$ko"
[ "$ko" -eq 0 ] && echo "  Caza los defectos reales, deja pasar lo bueno y dice lo que no sabe." \
                || echo "  🔴 Hay casos MAL: el gate NO se usa hasta arreglarlos."
exit "$ko"
