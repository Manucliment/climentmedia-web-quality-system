#!/usr/bin/env bash
# =============================================================================
#  run-all.sh · TODOS los bancos, UNA orden, UN numero
# =============================================================================
#    & "C:\Program Files\Git\bin\bash.exe" "/path/to/web-quality-system/gates/run-all.sh"
#
#  🔴 POR QUE EXISTE (13-ago-2026). Habia 10 bancos de prueba repartidos en 5
#     carpetas y NINGUN sitio desde donde correrlos todos. Cada uno se lanzaba a
#     mano, cuando alguien se acordaba de que existia. Es la misma enfermedad
#     que 07-trampas §25 -- «lo que depende de que alguien se acuerde, falla el
#     dia que no se acuerda»-- aplicada a las propias pruebas: la red de
#     seguridad estaba escrita y descolgada.
#
#     Sintoma medido ese mismo dia: al tocar `deploy.sh` corri el banco de la
#     puerta y ninguno de los otros nueve. Si el cambio hubiera roto el de
#     enlazado, me habria enterado dias despues y en otra web.
#
#  QUE NO HACE: no toca ninguna web viva, no despliega, no escribe en el
#  historial de verdad (cada banco exporta su propio QA_RECIBOS_DIR).
#  Los bancos lentos se saltan con `--rapido`.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
REF="$(pwd)"
RAPIDO=0
# `--fast` is the English alias. Both spellings work.
case "${1:-}" in --rapido|--fast) RAPIDO=1 ;; esac

# banco | orden | lento(1/0) | que cubre
BANCOS="
doc-gate|perl doc-gate-tests/tests.pl|0|el gate de documentacion
mismo-texto|perl same-text-tests/tests.pl|0|el texto del cliente no se pierde al rehacer la maqueta
crawl-enlaces|perl crawl-links-tests/tests.pl|0|migas, cache compartida, R5 y R10
qa-maestro|bash qa-master-tests/tests.sh|1|las 5 lentes y sus controles
recibo-base|bash receipt-tests/tests.sh|0|el recibo: arbol desplegable, sello, alcance
recibo-puerta|bash receipt-tests/tests-door.sh|1|G11 y la puerta de despliegue
recibo-cobertura|bash receipt-tests/tests-coverage.sh|0|el alcance del recibo
recibo-sitemap|bash receipt-tests/tests-sitemap.sh|0|el arbol desplegable
recibo-hook|bash receipt-tests/tests-hook.sh|0|el hook que bloquea subir sin recibo
recibo-cdn|perl receipt-tests/cdn-controls.pl|0|G11 detras de un CDN que reescribe imagenes
recibo-sello|bash receipt-tests/tests-sealing.sh|0|el asset sellado con ?v= y el cache de la URL desnuda
audit-vs-spec|perl audit-vs-spec-tests/tests.pl|0|la spec contra el arbol
audit-vs-origen|bash audit-vs-source-tests/tests.sh|0|el gate de migracion (medios)
gate-formularios|bash forms-gate-tests/tests.sh|1|el formulario en el DOM (paso 10)
anatomia|perl anatomy-tests/tests.pl|0|una sola tabla de anatomias (09 §2)
medir-pantallas|bash measure-screens-tests/tests.sh|1|densidad: la UNIDAD y los 19 moldes
gate-estructura|bash structure-gate-tests/battery.sh|1|maqueta: prosa vs maquetada, 3 REVISAR congelados
moldes-maqueta|bash structure-gate-tests/battery-layout.sh|1|los moldes: colisiones, contraste AA, anchos
gate-movil|bash mobile-gate-tests/battery.sh|1|movil: accion sobre el pliegue y CTA tapado (mide en el SERVIDOR)
conformidad|perl compliance-selftest.pl|1|la matriz y su alcance (sonda home-only)
historial|perl history-gate.pl|0|el registro nombra al check que acusa
form-handler|bash form-handler-tests/tests.sh|1|la plantilla del formulario: php -l y ejecucion
audit|bash audit-tests/tests.sh|1|el auditor de sitio: las 2 convenciones de URL
indice-gates|node gate-index.js|0|el indice REGLA -> INSTRUMENTO no tiene referencias muertas
huecos|bash holes-tests/tests.sh|0|lo que falta y no es nuestro, declarado
bots-ia|perl ai-crawlers-tests/tests.pl|0|los rastreadores de IA: si pueden entrar o no
canibalizacion|perl cannibalization-tests/tests.pl|0|dos paginas peleando por el mismo termino
citable|perl citable-tests/tests.pl|0|el parrafo sobrevive a que lo saquen de la pagina
"

echo "==============================================================================="
echo "  TODOS LOS BANCOS DE LA SKILL"
[ "$RAPIDO" = 1 ] && echo "  (--rapido: me salto los lentos)"
echo "==============================================================================="

# Bancos cuyo recuento depende de lo que esta maquina haya hecho ya, no del
# codigo. Se suman al total igual, pero tambien aparte, para que la
# documentacion pueda prometer un numero que se cumpla en una instalacion nueva.
DEPENDE_DEL_ESTADO="historial"
TOT_ESTADO=0
TOT_OK=0; TOT_MAL=0; ROTOS=""; NO_MEDIDOS=""
# Cuantos bancos DEBERIAN correr. Se cuenta ANTES para poder comparar despues:
# un banco que desaparece no falla, y sin este numero su ausencia se lee como
# «no habia nada que contar» (07-trampas §40).
ESPERADOS="$(printf '%s\n' "$BANCOS" | grep -c '|')"
CORRIDOS=0

#  🔴 PREFLIGHT: every bank must name a file that exists. Two of them did not,
#     and nobody noticed, because both are marked slow — `--fast` never reaches
#     them, and the one number anybody reads comes from a fast run. A bank whose
#     path is wrong does not fail: it is simply never attempted, and the summary
#     that follows says "all green" over it.
#     This is checked BEFORE anything runs, so the answer is not buried in the
#     output of twenty-two other banks.
FALTANTES=""
while IFS='|' read -r n cmd lento cubre; do
  [ -z "$n" ] && continue
  f=$(printf '%s' "$cmd" | awk '{print $2}')
  [ -f "$REF/$f" ] || FALTANTES="$FALTANTES $n:$f"
done <<FINPRE
$BANCOS
FINPRE
if [ -n "$FALTANTES" ]; then
  echo
  printf "  🔴 BANKS WHOSE COMMAND NAMES A FILE THAT DOES NOT EXIST:%s\n" "$FALTANTES"
  echo "     They will never run, and a run that never happens reads as a pass."
  echo "     Fix the path or remove the bank. Nothing else runs until this is clean."
  exit 1
fi

printf "\n"
while IFS='|' read -r nombre orden lento cubre; do
  [ -z "$nombre" ] && continue
  # Se cuenta AQUI, antes de cualquier `continue`: lo que se vigila no es que
  # todos pasen, es que de ninguno se pierda el rastro. Un banco saltado o que
  # no existe SI esta contado -- imprime su linea. El que desaparece no.
  CORRIDOS=$((CORRIDOS+1))
  if [ "$RAPIDO" = 1 ] && [ "$lento" = 1 ]; then
    printf "  SALTADO  %-18s %s\n" "$nombre" "(lento)"
    continue
  fi
  # El primer token de la orden es el interprete; el segundo, el fichero.
  fichero="$(printf '%s' "$orden" | awk '{print $2}')"
  if [ ! -f "$REF/$fichero" ]; then
    printf "  NO ESTA  %-18s %s\n" "$nombre" "$fichero"
    ROTOS="$ROTOS $nombre(no-esta)"
    TOT_MAL=$((TOT_MAL+1))
    continue
  fi
  # 🔴 `</dev/null` NO es cosmetico. La lista de bancos se lee con un heredoc, y
  #    el cuerpo del bucle HEREDA ese stdin. Cualquier programa dentro de un
  #    banco que lea de la entrada estandar -y `ssh` lo hace por defecto- se
  #    COME las lineas que quedan, y los bancos siguientes no se ejecutan.
  #    Y lo peor no es que no corran: es que el runner los daba por buenos.
  #    MEDIDO el 17-ago al cablear el paso 6 (que llama a `ssh`): de 8 bancos
  #    corrieron 3, el total bajo de 413 a 273, y la ultima linea seguia
  #    diciendo «Todos los bancos en verde».
  salida="$( cd "$REF" && eval "$orden" </dev/null 2>&1 )"
  rc=$?
  # exit 3 = «no lo he podido medir», distinto de 1 = «lo he medido y esta mal».
  # Es la misma distincion que hace la puerta entre NO CORRIDA y NO VERIFICADA,
  # y existe por el mismo motivo: mandar a alguien a buscar un defecto que no
  # existe cuesta una tarde. NO se cuenta como fallo, pero SE LISTA al final:
  # un hueco declarado sigue siendo un hueco, y callarlo seria un aprobado.
  # 🔴 1-sep-2026 · AQUI HABIA UNA INVERSION: un banco que sale 3 se contaba como
  #    CERO verdes, pero el mismo banco fallando sale 1, cae al bloque de abajo y
  #    SI se cuentan. Medido el mismo dia sobre `qa-maestro`, que desde hoy mide
  #    15 casos sin necesitar el sitio congelado:
  #        todo en verde  -> NO MEDIDO -> aporta  0   (total 736)
  #        un caso en rojo -> FALLA    -> aporta 14   (total 750)
  #    O sea que **arreglar el fallo hacia BAJAR el total en 15**. Un recuento
  #    que premia el rojo no es un recuento: es un incentivo al reves.
  #    Un banco parcial aporta lo que MIDIO y ademas se sigue listando como no
  #    medido, que son dos hechos distintos y los dos ciertos.
  if [ "$rc" = 3 ]; then
    n3_ok="$(printf '%s\n' "$salida"  | grep -oE 'OK +[0-9]+|[0-9]+ +OK|[0-9]+ +PASA' | grep -oE '[0-9]+' | tail -1)"
    TOT_OK=$((TOT_OK + ${n3_ok:-0}))
    if [ -n "${n3_ok:-}" ] && [ "${n3_ok:-0}" != 0 ]; then
      printf "  NO MEDIDO %-17s %s   (%s casos suyos SI medidos)\n" "$nombre" "$cubre" "$n3_ok"
    else
      printf "  NO MEDIDO %-17s %s\n" "$nombre" "$cubre"
    fi
    NO_MEDIDOS="$NO_MEDIDOS $nombre"
    continue
  fi
  # Cada banco imprime su recuento con su propio formato. Se leen los dos que
  # existen hoy -- «OK n · MAL n» y «n PASA · n FALLA»-- y si no casa ninguno se
  # dice, en vez de dar un cero que parece un aprobado.
  # Tres formatos vivos hoy: «OK 18 · MAL 0», «34 PASA · 0 FALLA» y «23 OK · 0 MAL».
  # El tercero faltaba y el banco del hook -24 casos- no contaba para el total:
  # salia «no he sabido leer su recuento», que es un cero con cara de aprobado.
  n_ok="$(printf '%s\n' "$salida"  | grep -oE 'OK +[0-9]+|[0-9]+ +OK|[0-9]+ +PASA' | grep -oE '[0-9]+' | tail -1)"
  n_mal="$(printf '%s\n' "$salida" | grep -oE 'MAL +[0-9]+|[0-9]+ +MAL|[0-9]+ +FALLA' | grep -oE '[0-9]+' | tail -1)"
  if [ -z "${n_ok:-}" ] && [ -z "${n_mal:-}" ]; then
    printf "  %-8s %-18s (no he sabido leer su recuento; exit %s)\n" \
           "$([ "$rc" = 0 ] && echo 'PASA' || echo 'FALLA')" "$nombre" "$rc"
    [ "$rc" = 0 ] || ROTOS="$ROTOS $nombre"
    [ "$rc" = 0 ] || TOT_MAL=$((TOT_MAL+1))
    continue
  fi
  n_ok="${n_ok:-0}"; n_mal="${n_mal:-0}"
  TOT_OK=$((TOT_OK + n_ok)); TOT_MAL=$((TOT_MAL + n_mal))
  # 26-ago-2026 - LOS BANCOS QUE DEPENDEN DEL ESTADO DE ESTA MAQUINA, APARTE.
  #   `historial` sale NO MEDIDO en una instalacion nueva -no hay despliegues
  #   que leer- y PASA en cuanto la maquina ha desplegado una vez. El total,
  #   entonces, no es el mismo numero para todo el mundo.
  #   Eso rompia D6 de la peor manera: el README promete el recuento de una
  #   INSTALACION LIMPIA -lo dice en su propia frase- y D6 lo comparaba con
  #   ESTA corrida. Hoy, tras desplegar dos webs, la bateria paso de 617 a 619
  #   y doc-gate se puso rojo sin que nadie hubiera roto nada.
  #   Y subir el numero a 619 habria sido PEOR: dejaria doc-gate en rojo para
  #   cualquiera que clone el repo y no haya desplegado nunca.
  case " $DEPENDE_DEL_ESTADO " in *" $nombre "*) TOT_ESTADO=$((TOT_ESTADO + n_ok)) ;; esac
  if [ "$rc" = 0 ] && [ "$n_mal" = 0 ]; then
    printf "  PASA     %-18s %3d casos   %s\n" "$nombre" "$n_ok" "$cubre"
  else
    printf "  FALLA    %-18s %3d ok / %d mal   %s\n" "$nombre" "$n_ok" "$n_mal" "$cubre"
    ROTOS="$ROTOS $nombre"
    printf '%s\n' "$salida" | grep -E '^\s*(MAL|FALLA)' | head -6 | sed 's/^/             /'
  fi
done <<EOF
$BANCOS
EOF

echo
echo "  cuantas comprobaciones tienen caso (regla 5 de la formula):"
perl "$REF/coverage.pl" 2>/dev/null | grep -E '^  (qa-maestro|enlazado-gate|audit-vs-spec|doc-gate|TOTAL)' | sed 's/^/  /'

# 19-ago-2026 · EL NUMERO SE ESCRIBE, PARA QUE LA DOCUMENTACION NO PUEDA MENTIR.
# SKILL.md publicaba «365 casos en verde» y «59 de 121 con caso» cuando eran 817
# y 117 de 132, y en el mismo documento citaba el desglose correcto: se
# contradecia a si mismo. Ese parrafo dice «si baja, se ha roto algo», y un
# umbral escrito a mano que lleva meses sin tocarse NO puede detectar una bajada.
# Ahora el dato lo deja aqui quien lo mide, y doc-gate.pl compara.
#
# 🔴 22-ago-2026 · ESTO ESTABA 30 LINEAS MAS ABAJO, Y ASI D6 NO MEDIA ESTA
#    CORRIDA SINO LA ANTERIOR. `doc-gate.pl` se llamaba en la linea 132 y este
#    fichero se escribia en la 167: cuando el recuento cambiaba, D6 comparaba el
#    numero nuevo de SKILL.md contra el `.ultima-bateria` VIEJO y salia FALLA;
#    a la corrida siguiente pasaba solo, sin que nadie arreglara nada.
#    Medido hoy: la bateria dio «874 en verde · 0 en rojo» Y «bancos en rojo:
#    doc-gate(skill)» a la vez, y `perl doc-gate.pl` en solitario PASABA los 6.
#    Un rojo que se cura solo es peor que un rojo estable: ensena a ignorar el
#    gate. Se escribe ANTES de que doc-gate lo lea, que era la intencion desde
#    el principio -«el dato lo deja aqui quien lo mide, y doc-gate compara»-.
#    Los tres valores ya son definitivos aqui: el bucle de bancos ha terminado.
#    ⚠️ Y no cambia lo que se escribe: `rojo` cuenta CASOS de banco, no `ROTOS`,
#    asi que doc-gate no se cuenta a si mismo ni antes ni ahora.
# 🔴 28-ago-2026 · SE CONSERVAN LAS CIFRAS DEL OTRO MODO, o el documento no
#    puede publicar las dos. `--fast` da 630 y la completa 728: las dos son
#    ciertas, de corridas distintas, y las dos estan escritas en el README. Si
#    el fichero solo guardara la ultima, D6 tendria que llamar caducada a la
#    otra -- que es exactamente el falso rojo que esto viene a cerrar.
#    Mismo principio que `verde` / `verde-instalacion-limpia`: se guardan las
#    dos y se aceptan las dos; una cifra de verdad equivocada no casa con
#    ninguna, asi que el gate NO pierde el poder de ponerse rojo.
MODO="$([ "$RAPIDO" = 1 ] && echo rapido || echo completo)"
OTRO_MODO=""; OTRO_MEDIDO=""; OTRO_VERDE=""; OTRO_LIMPIA=""
if [ -f "$REF/.ultima-bateria" ]; then
  prev_modo="$(grep -m1 '^modo:' "$REF/.ultima-bateria" 2>/dev/null | sed 's/^modo:[[:space:]]*//')"
  if [ -n "$prev_modo" ] && [ "$prev_modo" != "$MODO" ]; then
    # La corrida anterior era del OTRO modo: sus cifras pasan a la seccion otro-modo.
    OTRO_MODO="$prev_modo"
    OTRO_MEDIDO="$(grep -m1 '^medido:' "$REF/.ultima-bateria" | sed 's/^medido:[[:space:]]*//')"
    OTRO_VERDE="$(grep -m1 '^verde:' "$REF/.ultima-bateria" | sed 's/^verde:[[:space:]]*//')"
    OTRO_LIMPIA="$(grep -m1 '^verde-instalacion-limpia:' "$REF/.ultima-bateria" | sed 's/^verde-instalacion-limpia:[[:space:]]*//')"
  else
    # Mismo modo: se arrastra lo que ya hubiera del otro, para no perderlo.
    OTRO_MODO="$(grep -m1 '^otro-modo:' "$REF/.ultima-bateria" | sed 's/^otro-modo:[[:space:]]*//')"
    OTRO_MEDIDO="$(grep -m1 '^otro-modo-medido:' "$REF/.ultima-bateria" | sed 's/^otro-modo-medido:[[:space:]]*//')"
    OTRO_VERDE="$(grep -m1 '^otro-modo-verde:' "$REF/.ultima-bateria" | sed 's/^otro-modo-verde:[[:space:]]*//')"
    OTRO_LIMPIA="$(grep -m1 '^otro-modo-verde-instalacion-limpia:' "$REF/.ultima-bateria" | sed 's/^otro-modo-verde-instalacion-limpia:[[:space:]]*//')"
  fi
fi

{
  echo "medido: $(date +%Y-%m-%d)"
  # 🔴 28-ago-2026 · EL MODO, y faltaba. `--fast` se salta los 10 bancos lentos,
  #    asi que una corrida rapida y una completa escriben numeros MUY distintos
  #    -630 y 728- EN LA MISMA CASILLA, y nada decia cual era cual. Efecto: D6
  #    comparaba el numero que el README publica -que es el de `--fast`, y lo
  #    dice en su propia frase- contra la ultima corrida FUERA CUAL FUERA. Con
  #    la rapida salia verde y con la completa rojo, sin que nadie tocara nada.
  #    Es la misma enfermedad que este fichero persigue: dos cosas distintas en
  #    un solo hueco y ninguna etiqueta que las separe.
  echo "modo: $MODO"
  echo "bancos: $CORRIDOS"
  echo "verde: $TOT_OK"
  echo "rojo: $TOT_MAL"
  echo "verde-instalacion-limpia: $((TOT_OK - TOT_ESTADO))"
  echo "depende-del-estado: $TOT_ESTADO"
  if [ -n "$OTRO_MODO" ] && [ -n "$OTRO_VERDE" ]; then
    echo "otro-modo: $OTRO_MODO"
    echo "otro-modo-medido: $OTRO_MEDIDO"
    echo "otro-modo-verde: $OTRO_VERDE"
    echo "otro-modo-verde-instalacion-limpia: ${OTRO_LIMPIA:-$OTRO_VERDE}"
  fi
} > "$REF/.ultima-bateria"

echo
echo "  the documentation gate, on this repository AND on every site you configure:"
# 🔴 Los repos tambien, y no de adorno: su CLAUDE.md es la documentacion que
#    mas deriva -- nadie la relee y no la miraba ningun programa. La primera
#    corrida sobre ellos saco 3 hallazgos... y los 3 eran falsos positivos MIOS,
#    que es lo que llevo a acotar D1. Ver 07-trampas.md §27.
#    Si un repo no esta en esta maquina, se dice y se sigue: no se inventa un OK.
if perl "$REF/doc-gate.pl" >/dev/null 2>&1; then
  printf "    %-24s PASA\n" "this repository"
else
  printf "    %-24s FALLA · perl doc-gate.pl\n" "this repository"
  ROTOS="$ROTOS doc-gate(skill)"
fi
#  The list of site repositories is CONFIGURATION, not something baked in here.
#  One absolute path per line in `config/site-repos.conf`, `#` comments ignored.
#  With no config file this prints one line saying so — which is the honest
#  answer. Printing nothing would read as "checked, all fine".
SITEREPOS="${SITE_REPOS_CONF:-$REF/config/site-repos.conf}"
if [ ! -f "$SITEREPOS" ]; then
  printf "    %-24s no sites configured (see config/site-repos.conf.example)\n" "your sites"
fi
for ruta in $( [ -f "$SITEREPOS" ] && grep -v '^[[:space:]]*#' "$SITEREPOS" | grep -v '^[[:space:]]*$' ); do
  repo="$(basename "$ruta")"
  if [ ! -d "$ruta" ]; then
    printf "    %-24s NOT ON THIS MACHINE (configured, not found)\n" "$repo"
    continue
  fi
  if perl "$REF/doc-gate.pl" --dir "$ruta" >/dev/null 2>&1; then
    printf "    %-24s PASA\n" "$repo"
  else
    printf "    %-24s FALLA · perl doc-gate.pl --dir %s\n" "$repo" "$ruta"
    ROTOS="$ROTOS doc-gate($repo)"
  fi
done

echo
echo "==============================================================================="
printf "  %d casos en verde · %d en rojo\n" "$TOT_OK" "$TOT_MAL"
# `.ultima-bateria` ya se ha escrito ARRIBA, antes de llamar a doc-gate.pl.
# Estaba aqui hasta el 22-ago-2026 y por eso D6 medía la corrida anterior; el
# porque completo esta en el comentario del bloque, en su sitio nuevo.
# 🔴 18-ago-2026 · Y EL CONTROL INVERSO: un banco ESCRITO Y DESCOLGADO.
# El de abajo caza el banco que se esfuma de la corrida. Este caza el que nunca
# entro: escribir un banco y cablearlo son DOS gestos, y solo el primero deja
# rastro visible -- un directorio con pruebas dentro parece trabajo hecho.
# Medido hoy: `structure-gate-tests/` (898 ficheros) y `compliance-selftest.pl`
# llevaban existiendo sin que los corriera nadie. Cero senal, cero sospecha.
#  🔴 THIS CHECK WENT MUTE ONCE, AND IT WENT MUTE BY BEING RENAMED. The globs
#     used to read `*-pruebas` and `*autoprueba*.pl`. When the batteries were
#     renamed to `*-tests` and `*selftest*.pl`, both globs stopped matching
#     anything — measured: 0 and 0, against 13 and 1 that exist. The guard kept
#     printing nothing, which reads exactly like "nothing is unwired".
#     It is the defect this check was written to catch, committed against the
#     check itself. Hence the census below: a sweep that finds NOTHING TO LOOK AT
#     must say so, because zero findings and zero subjects print identically.
#  🔴 AND IT COUNTS ENTRY SCRIPTS, NOT DIRECTORIES. Checking directories was the
#     second half of the same blind spot: `grep` for the directory name matches as
#     soon as ANY ONE of its scripts is wired, so a whole battery living inside an
#     already-wired directory is invisible. Two were, and the day they were finally
#     run one of them came out **62 pass · 6 fail** — six red cases nobody had ever
#     seen, on a fixture that had quietly stopped matching the code it tests.
#     The unit that has to be accounted for is the thing you can run.
DESCOLGADOS=""; VISTOS=0
for f in "$REF"/*-tests/tests*.sh "$REF"/*-tests/tests*.pl \
         "$REF"/*-tests/battery*.sh "$REF"/*-tests/battery*.pl; do
  [ -f "$f" ] || continue
  VISTOS=$((VISTOS+1))
  n="$(basename "$(dirname "$f")")/$(basename "$f")"
  printf '%s\n' "$BANCOS" | grep -qF "$n" || DESCOLGADOS="$DESCOLGADOS $n"
done
for a in "$REF"/*selftest*.pl; do
  [ -f "$a" ] || continue
  VISTOS=$((VISTOS+1))
  n="$(basename "$a")"
  printf '%s\n' "$BANCOS" | grep -q "$n" || DESCOLGADOS="$DESCOLGADOS $n"
done
if [ "$VISTOS" -eq 0 ]; then
  echo
  echo "  🔴 THE UNWIRED-BANK CHECK FOUND NOTHING TO LOOK AT."
  echo "     Not one directory matched \`*-tests\` and not one file matched"
  echo "     \`*selftest*.pl\`. That is not a pass: the check is blind. Somebody"
  echo "     renamed the batteries and did not move these globs."
  ROTOS="$ROTOS censo-descolgados"
elif [ -n "$DESCOLGADOS" ]; then
  echo
  printf "  🔴 BATTERIES WRITTEN AND NEVER WIRED IN:%s\n" "$DESCOLGADOS"
  echo "     They exist, nobody runs them, and their absence is invisible."
  echo "     Either they go into the BANCOS list above, or they get deleted."
  echo "     What is not allowed is sitting there looking like coverage."
  ROTOS="$ROTOS descolgados"
fi

# 🔴 El control de que no ha desaparecido ninguno. Sin esto, un banco que se
# esfuma -por `ssh` comiendose el stdin, o por lo que venga manana- baja el
# total en silencio y la linea siguiente sigue diciendo «todos en verde».
# Ya paso: 8 esperados, 3 corridos, 413 -> 273, y el runner lo dio por bueno.
if [ "$CORRIDOS" != "$ESPERADOS" ]; then
  echo
  printf "  🔴 SE ESPERABAN %d BANCOS Y SOLO SE HA VISTO %d.\n" "$ESPERADOS" "$CORRIDOS"
  echo "  Los que faltan no han fallado: NO HAN CORRIDO, y eso no es un aprobado."
  echo "  Sospechoso habitual: algo dentro de un banco leyendo de stdin y"
  echo "  comiendose la lista (07-trampas §40)."
  exit 1
fi
if [ -n "$NO_MEDIDOS" ]; then
  # Se dice SIEMPRE, pase o falle lo demas. Un banco que no ha podido medir no
  # es un aprobado, y callarlo aqui convertiria «todos en verde» en una mentira
  # por omision -- que es el fallo de 07-trampas §40 con otra ropa.
  echo "  NO MEDIDOS:$NO_MEDIDOS"
fi
if [ -n "$ROTOS" ]; then
  echo "  🔴 bancos en rojo:$ROTOS"
  echo "  No se toca ninguna web con esto asi: el instrumento es lo que dice si"
  echo "  un defecto de la web es un defecto o es suyo."
  exit 1
fi
if [ -n "$NO_MEDIDOS" ]; then
  echo "  Los demas bancos en verde. Los de arriba NO se han medido."
else
  echo "  Todos los bancos en verde."
fi
echo "==============================================================================="
