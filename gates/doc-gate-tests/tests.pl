#!/usr/bin/perl
# =============================================================================
#  Prueba de doc-gate.pl · rojos Y verdes, y sobre todo LOS FALSOS POSITIVOS
# =============================================================================
#    perl "/path/to/web-quality-system/gates/doc-gate-tests/tests.pl"
#
#  🔴 POR QUE LA MITAD DE ESTOS CASOS SON NEGATIVOS. La primera version de D1
#     sacó 32 fallos sobre esta misma skill y 29 eran FALSOS: acusaba a
#     `index.html`, `SKILL.md`, `gtag.js`, `scratchpad/...` y a rutas de otros
#     repos. Un gate de documentacion que acusa 9 de cada 10 veces en falso se
#     apaga el primer dia -- y entonces no protege nada, que es peor que no
#     tenerlo, porque ademas nadie se acuerda de que existio.
#
#     Por eso aqui hay tantos casos de «esto NO se puede acusar» como de «esto
#     SI». Los negativos son el contrato: dicen hasta donde llega el gate.
#
#  ⚠️ Hermetico: fabrica su propia carpeta con documentos y programas de
#     mentira. No lee la skill de verdad ni toca la red.
# =============================================================================
use strict; use warnings;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

my $DIR = $0; $DIR =~ s{[/\\][^/\\]+$}{};
my $GATE = "$DIR/../doc-gate.pl";
die "no encuentro $GATE\n" unless -f $GATE;

my ($ok, $ko) = (0, 0);

# Monta una carpeta con los ficheros dados y corre una comprobacion del gate.
#   $espera: 'PASA', 'FALLO', 'AVISO' o 'NO MEDIDO' para esa comprobacion
#   $opc (opcional): { rc => el codigo de salida que tiene que dar el gate,
#                      dice => qr/.../ que la linea del veredicto tiene que casar }
#   🔴 27-sep-2026 · `dice` existe porque un FALLO no dice POR QUE. Un caso que
#      espera el rojo de una cifra caducada pasaria igual si el gate cayera por
#      OTRA cifra del mismo documento -- un rojo por el motivo equivocado es un
#      verde disfrazado. Y `rc`, porque NO MEDIDO solo vale si sale 3: con un 0
#      se lee como un aprobado en `run-all.sh`, que solo mira el codigo.
sub caso {
    my ($eti, $lista, $ficheros, $espera, $desde, $opc) = @_;
    $opc ||= {};
    my $t = tempdir(CLEANUP => 1);
    for my $f (sort keys %$ficheros) {
        my $ruta = "$t/$f";
        (my $carpeta = $ruta) =~ s{[/\\][^/\\]+$}{};
        make_path($carpeta) unless -d $carpeta;
        open my $h, '>:raw', $ruta or die "no puedo escribir $ruta: $!\n";
        print $h $ficheros->{$f};
        close $h;
    }
    # `$desde` mide el gate desde una SUBCARPETA, que es como corre de verdad:
    # los CAMINO-*.md viven en la raiz de la skill y el gate se lanza desde
    # `references/`. Sin esta opcion, el banco no podia reproducir el caso real.
    my $raiz = defined $desde ? "$t/$desde" : $t;
    my $salida = `perl "$GATE" --dir "$raiz" --lista $lista 2>&1`;
    my $rc = $? >> 8;
    # «NO MEDIDO» son DOS palabras: se captura el estado entero, no la primera.
    my ($linea) = $salida =~ /^((?:PASA|FALLO|AVISO|NO MEDIDO)\s+\Q$lista\E\b.*)$/m;
    my ($real)  = defined $linea ? $linea =~ /^(PASA|FALLO|AVISO|NO MEDIDO)/ : ();
    $real //= 'SIN LINEA';
    my @mal;
    push @mal, "esperaba $espera y salio $real" if $real ne $espera;
    push @mal, "esperaba salir $opc->{rc} y salio $rc" if defined $opc->{rc} && $rc != $opc->{rc};
    push @mal, "la linea no casa $opc->{dice}" if $opc->{dice} && !(defined $linea && $linea =~ $opc->{dice});
    if (!@mal) { printf "  OK    %-56s %s=%s\n", $eti, $lista, $real; $ok++ }
    else { printf "  MAL   %-56s %s\n", $eti, join(' · ', @mal); $ko++;
           print "        $_\n" for grep { /^(PASA|FALLO|AVISO|NO MEDIDO)/ } split /\n/, $salida }
}

my $PROG = "#!/usr/bin/perl\n# de mentira\nif (\$x eq '--real') { }\nif (\$x eq '--otra') { }\n";
my $TRAMPA_OK = "# Trampas\n\n## 1 · algo\n\n**Lo caza:** `algo-pruebas/tests.pl`\n\ntexto\n";

print "\n== D1 · RUTAS: solo se acusa lo que se puede PROBAR\n";
caso('cita references/ que NO existe', 'D1',
     { 'doc.md' => "Se corre con `references/no-existe.pl`.\n", 'real.pl' => $PROG }, 'FALLO');
caso('cita references/ que SI existe', 'D1',
     { 'doc.md' => "Se corre con `references/real.pl`.\n", 'real.pl' => $PROG }, 'PASA');

# 🔴 26-sep-2026 · LAS CARPETAS DE HOY. `references/` desaparecio el 26-ago y D1
#    solo buscaba ese prefijo: un mes saliendo PASA sin comprobar ni una ruta
#    actual. Los dos primeros casos son los que el gate anterior daba en VERDE.
#    El tercero fija que se resuelve contra la raiz de la SKILL: un CLAUDE.md de
#    cliente cita `gates/...` de la skill, y en su repo esa ruta no esta.
caso('cita gates/ que NO existe (ni aqui ni en la skill)', 'D1',
     { 'doc.md' => "Se corre con `gates/no-existe-en-ningun-sitio.pl`.\n", 'real.pl' => $PROG }, 'FALLO');
caso('cita blueprint/ que NO existe', 'D1',
     { 'doc.md' => "El metodo esta en `blueprint/99-no-existe.md`.\n", 'real.pl' => $PROG }, 'FALLO');
caso('cita gates/ que existe en la SKILL aunque se mida otro arbol', 'D1',
     { 'doc.md' => "La documentacion la mide `gates/doc-gate.pl`.\n", 'real.pl' => $PROG }, 'PASA');
caso('cita gates/ que existe en el arbol mirado', 'D1',
     { 'doc.md' => "Se corre con `gates/propio.pl`.\n", 'real.pl' => $PROG, 'gates/propio.pl' => $PROG }, 'PASA');
caso('un nombre anterior entre parentesis, tambien con carpeta de hoy', 'D1',
     { 'doc.md' => "Corre `gates/doc-gate.pl` *(entonces `gates/nombre-viejo.pl`)*.\n", 'real.pl' => $PROG }, 'PASA');
# La copia por maquina de una plantilla: gitignored, asi que un clon limpio no la
# tiene. Con su `.example` al lado es una instruccion, no una ruta muerta; sin el,
# sigue cayendo (el control que impide que la exencion se coma lo bueno).
caso('una copia por maquina con su .example al lado', 'D1',
     { 'doc.md' => "Lee el host de `gates/config/host.local.conf` (copia el .example).\n",
       'real.pl' => $PROG, 'gates/config/host.local.conf.example' => "HOST=x\n" }, 'PASA');
caso('...y sin .example al lado sigue cayendo', 'D1',
     { 'doc.md' => "Lee el host de `gates/config/host.local.conf`.\n", 'real.pl' => $PROG }, 'FALLO');

# 🔴 26-sep-2026 · EL COMANDO QUE SE COPIA. En un CLAUDE.md de web los programas
#    de la skill se citan con su ruta ENTERA y dentro de un bloque de codigo, y
#    D1 solo leia rutas sueltas entre acentos: 14 comandos vivos apuntaban a
#    programas renombrados el 26-ago y el gate decia PASA en los cinco repos.
caso('un comando con la ruta de la skill a un programa que ya no existe', 'D1',
     { 'doc.md' => "```bash\nperl ~/.claude/skills/client-site/references/no-existe.pl https://x --repo .\n```\n",
       'real.pl' => $PROG }, 'FALLO');
caso('...y a un programa que si existe en la skill', 'D1',
     { 'doc.md' => "```bash\nperl ~/.claude/skills/client-site/gates/doc-gate.pl --dir .\n```\n",
       'real.pl' => $PROG }, 'PASA');
caso('...y en un RUN_LOG es historia', 'D1',
     { 'RUN_LOG.md' => "- `bash ~/.claude/skills/client-site/references/no-existe.sh` -> EXIT 0\n",
       'real.pl' => $PROG }, 'PASA');

print "\n   -- y los que NO se pueden acusar (aqui murieron 29 falsos positivos)\n";
caso('`index.html` es prosa sobre la web del cliente', 'D1',
     { 'doc.md' => "El generador escribe `index.html` en cada carpeta.\n", 'real.pl' => $PROG }, 'PASA');
caso('`CLAUDE.md` y `SKILL.md` viven fuera de references/', 'D1',
     { 'doc.md' => "Ver `CLAUDE.md` del proyecto y `SKILL.md`.\n", 'real.pl' => $PROG }, 'PASA');
caso('`gtag.js` es de un tercero', 'D1',
     { 'doc.md' => "Carga `gtag.js` y `fbevents.js`.\n", 'real.pl' => $PROG }, 'PASA');
caso('`scratchpad/x.pl` es de una sesion', 'D1',
     { 'doc.md' => "Datos en `scratchpad/lente.json` y `scratchpad/x.pl`.\n", 'real.pl' => $PROG }, 'PASA');
caso('`otro-repo/styles.css` es de otro arbol', 'D1',
     { 'doc.md' => "Comparar con `site-d-web/styles.css`.\n", 'real.pl' => $PROG }, 'PASA');
caso('una ruta con hueco `<repo>/x.pl` es un ejemplo', 'D1',
     { 'doc.md' => "Se llama `<repo>/_deploy/subir.sh`.\n", 'real.pl' => $PROG }, 'PASA');

# 🔴 UNA RUTA DE REPO (`_deploy/`, `_spec/`...) NO SE MIRA, y esto lo fija.
#    El 13-ago probe a incluirlas y lo medi sobre los 5 repos y la skill: 12
#    acusaciones, 12 falsas. La razon de fondo la da el caso de abajo: esta
#    documentacion habla de OTROS arboles, asi que sus rutas internas son
#    correctas alli y no existen aqui. Un programa no distingue «mi ruta» de
#    «la ruta de la que hablo». Este caso existe para que no se vuelva a anadir.
caso('una ruta interna de repo NO se mira: habla de otro arbol', 'D1',
     { 'doc.md' => "La spec vive en `_spec/site.json` y se sube con `_deploy/subir.sh`.\n",
       'real.pl' => $PROG }, 'PASA');

# 🔴 LOS DOS CASOS REALES QUE ME ACUSARON EN FALSO sobre los repos de cliente.
#    Salieron de correr esto de verdad, no de imaginar que podria pasar.
caso('una TAREA PENDIENTE puede nombrar lo que aun no existe', 'D1',
     { 'doc.md' => "- [ ] Mover la sonda a `references/aun-no.pl`.\n", 'real.pl' => $PROG }, 'PASA');
caso('una CITA de lo que decia otro documento no es una afirmacion', 'D1',
     { 'doc.md' => "Los SKILL.md mandan leerlos (\"lee `references/muerto.md` para el mecanismo ACTUAL\").\n",
       'real.pl' => $PROG }, 'PASA');
# ...y el control que impide que esas dos exclusiones se coman lo bueno: una
# tarea YA HECHA y una linea normal con comillas siguen acusando.
caso('una tarea HECHA si afirma que existe', 'D1',
     { 'doc.md' => "- [x] El programa vive en `references/no-esta.pl`.\n", 'real.pl' => $PROG }, 'FALLO');
caso('una linea con comillas pero sin ruta dentro de ellas', 'D1',
     { 'doc.md' => "Dice \"esto es asi\" y el programa es `references/no-esta.pl`.\n", 'real.pl' => $PROG }, 'FALLO');

# 🔴 28-ago-2026 · UN REGISTRO DE CORRIDAS HABLA DEL PASADO.
#    Un RUN_LOG apunta lo que se corrio y cuando. Que la ruta ya no exista NO
#    contradice el apunte: existia ese dia. Reescribirlo para callar al gate
#    falsifica el registro, que es lo unico que un registro no puede permitirse.
#    Caso real: el RUN_LOG de un sitio citaba dos veces una ruta bajo
#    `references/`, renombrada a `gates/` el 25-ago, en dos frases en PASADO.
#    El segundo caso es el que prueba que la exclusion NO se come lo bueno.
caso('un RUN_LOG cita una ruta muerta: es historia, no una afirmacion', 'D1',
     { 'RUN_LOG.md' => "- `bash references/audit.sh --root .` -> **EXIT 0**\n", 'real.pl' => $PROG }, 'PASA');
caso('...y CUALQUIER OTRO documento que cite esa misma ruta sigue cayendo', 'D1',
     { 'doc.md' => "Se corre con `references/audit.sh`.\n", 'real.pl' => $PROG }, 'FALLO');

# 🔴 15-sep-2026 · UN NOMBRE ANTERIOR, DECLARADO COMO ANTERIOR.
#    Salio de arreglar una ficha de verdad: se reescribio para nombrar la ruta de
#    HOY y dejar la vieja entre parentesis como historia, y D1 siguio acusando. El
#    gate premiaba BORRAR la historia, que es lo contrario de lo que pide el repo.
#    Los tres casos van juntos a proposito: sin los dos negativos, esta exclusion
#    se vuelve la forma de callar cualquier ruta muerta escribiendo «antes».
caso('un nombre anterior entre parentesis es historia, no una afirmacion', 'D1',
     { 'doc.md' => "Corre `real.pl` *(entonces `references/muerto.js`)* y no llamaba a setUserAgent.\n",
       'real.pl' => $PROG }, 'PASA');
caso('...pero «antes» suelto, sin parentesis abierto, NO exime', 'D1',
     { 'doc.md' => "Antes lo mirabamos a mano; hoy se corre con `references/muerto.js`.\n",
       'real.pl' => $PROG }, 'FALLO');
caso('...ni un parentesis YA CERRADO antes de la ruta', 'D1',
     { 'doc.md' => "Se renombro (antes era otra cosa) y hoy es `references/muerto.js`.\n",
       'real.pl' => $PROG }, 'FALLO');

print "\n== D2 · BANDERAS\n";
caso('bandera que el programa NO acepta', 'D2',
     { 'doc.md' => "Correr `real.pl --inventada`.\n", 'real.pl' => $PROG }, 'FALLO');
caso('bandera que SI acepta', 'D2',
     { 'doc.md' => "Correr `real.pl --real`.\n", 'real.pl' => $PROG }, 'PASA');
# 🔴 EL FALSO POSITIVO QUE ME PILLO A MI: una linea que nombra un programa y
#    una bandera de OTRO. El gate no puede saber de cual es: calla.
caso('dos programas en la linea: no se puede atribuir', 'D2',
     { 'doc.md' => "Ver `otro.pl --inventada` junto a `real.pl --real`.\n",
       'real.pl' => $PROG, 'otro.pl' => $PROG }, 'PASA');
# 🔴 14-ago-2026 · LA BANDERA DECLARADA EN UNA ALTERNATIVA.
#    `qa-master.pl` declara SEIS asi -- `/^--(snippet|sin-red|sin-recibo|...)$/`
#    -- y el escaner solo veia `--foo` escrito entero: tras el `--` viene un
#    `(`, que no es `[a-z]`. D2 acusaba a `--sin-recibo` de «bandera que el
#    programa no acepta» **siendo una que el programa acepta**, en cuanto un
#    documento la citaba sola. Lo destapo escribir la regla 13 de 00-formula.md.
my $PROG_ALT = "#!/usr/bin/perl\n# de mentira\n"
             . "if (\$x =~ /^--(alfa|beta-larga|gamma)\$/) { }\n";
caso('bandera declarada en una alternativa', 'D2',
     { 'doc.md' => "Correr `alt.pl --beta-larga`.\n", 'alt.pl' => $PROG_ALT }, 'PASA');
# Y no se afloja: una inventada al lado de las tres de la alternativa sigue cayendo.
caso('...y una inventada SIGUE cayendo', 'D2',
     { 'doc.md' => "Correr `alt.pl --delta`.\n", 'alt.pl' => $PROG_ALT }, 'FALLO');

print "\n== D3 · IDs DE COMPROBACION\n";
my $EMITE = "#!/usr/bin/perl\nnv(id=>'SEO-01', titulo=>'x');\nbad(id=>'EST-06', titulo=>'y');\n";
caso('ID de una familia conocida que nadie emite', 'D3',
     { 'doc.md' => "Arregla SEO-99 antes de subir.\n", 'g.pl' => $EMITE }, 'FALLO');
caso('ID que si se emite', 'D3',
     { 'doc.md' => "Arregla SEO-01 antes de subir.\n", 'g.pl' => $EMITE }, 'PASA');
caso('familia desconocida: no es cosa nuestra', 'D3',
     { 'doc.md' => "El formulario devuelve ABC-12 y GDPR-01.\n", 'g.pl' => $EMITE }, 'PASA');

#  🔴 28-ago-2026 · UNA FAMILIA SIN NI UN EMISOR EN EL ARBOL NO SE PUEDE JUZGAR.
#     Al conectar por fin los repos de sitio (`config/site-repos.conf`),
#     un repo de sitio salio con 5 FALLO citando MED-09, MED-01, EST-03,
#     EST-04 y MED-13. Los cinco EXISTEN en `qa-master.pl` -- pero ese programa
#     vive en la skill, no en el repo del sitio, asi que ahi no se lee.
#     Y el guardia de "¿tengo con que juzgar?" era `keys %emitidos`, que en ese
#     arbol NO estaba vacio: un `R10 l` suelto dentro de un `.js` casaba con el
#     patron de las reglas de enlazado. UN acierto accidental basto para creerse
#     en posesion del catalogo entero. Hermano del "un cero de grep no es una
#     ausencia": **un UNO tampoco es una presencia.**
#     El tercer caso es el que prueba que esto NO apaga el check.
my $SOLO_R = "#!/usr/bin/perl\n# la regla R10 limita el menu\n";
caso('familia sin emisor en el arbol: se avisa, no se acusa', 'D3',
     { 'doc.md' => "Mira MED-09 y EST-03 en el recibo.\n", 'g.pl' => $SOLO_R }, 'AVISO');
caso('...y la familia que SI se emite se sigue juzgando', 'D3',
     { 'doc.md' => "Arregla SEO-01 y mira MED-09.\n", 'g.pl' => $EMITE }, 'AVISO');
caso('...pero un ID inexistente de una familia QUE SI SE EMITE sigue en rojo', 'D3',
     { 'doc.md' => "Arregla SEO-99 y mira MED-09.\n", 'g.pl' => $EMITE }, 'FALLO');

print "\n== D4 · CADA TRAMPA DECLARA QUE LA CAZA\n";
caso('una trampa sin declararlo', 'D4',
     { '07-trampas.md' => "# T\n\n## 1 · algo\n\ntexto\n" }, 'FALLO');
caso('una trampa que lo declara', 'D4', { '07-trampas.md' => $TRAMPA_OK }, 'PASA');
# «nadie» es una respuesta VALIDA: hay trampas que no se pueden automatizar.
# Si «nadie» fallara, la salida facil seria inventarse un mecanismo, y entonces
# el numero de cobertura -- el unico que dice si esto mejora -- seria mentira.
caso('«nadie» es una respuesta valida y no falla', 'D4',
     { '07-trampas.md' => "# T\n\n## 1 · algo\n\n**Lo caza:** nadie · es una regla de escritura\n\ntexto\n" }, 'PASA');
#  19-ago-2026 - EL FICHERO REAL USA DOS CONVENCIONES: `## N .` en las 59
#  primeras y con signo de seccion delante del numero en las ultimas seis. D4 solo aceptaba la primera, asi
#  que las seis ultimas eran INVISIBLES: cinco trampas se escribieron sin declarar quien
#  las caza y el gate no dijo nada. Estos dos casos son los que lo impiden.
my $SEC = chr(0xC2).chr(0xA7); my $PTO = chr(0xC2).chr(0xB7);
caso('un encabezado con seccion-signo tambien se MIRA (y acusa)', 'D4',
     { '07-trampas.md' => "# Trampas\n\n## ${SEC}60 ${PTO} algo\n\nsin declararlo\n" }, 'FALLO');
caso('...y con seccion-signo y declarado, PASA', 'D4',
     { '07-trampas.md' => "# Trampas\n\n## ${SEC}60 ${PTO} algo\n\n**Lo caza:** `algo-pruebas/tests.pl`\n" }, 'PASA');
caso('con varias, basta que a UNA le falte', 'D4',
     { '07-trampas.md' => "# T\n\n## 1 · a\n\n**Lo caza:** nadie\n\nx\n\n## 2 · b\n\nsin declarar\n" }, 'FALLO');

print "\n== D5 · LOS CAMINOS LLEVAN EL MISMO BLOQUE DE LA PUERTA\n";
# 🔴 EL DEFECTO QUE LO TRAJO: los 4 CAMINO-*.md -los documentos que alguien
#    SIGUE- no nombraban ni una vez `deploy.sh`, la unica puerta obligatoria.
#    Se arreglo poniendo el mismo bloque en los cuatro; esto comprueba que sigue
#    siendo el mismo, porque «acordarse de copiarlo» es la clase de regla que ya
#    fallo antes (menu duplicado a mano en 21 paginas, §24).
my $PUERTA = "## 🔴 LA PUERTA — el unico paso\n\nbash references/deploy.sh DIR --subir\n";
caso('dos caminos con el MISMO bloque', 'D5',
     { 'CAMINO-1-x.md' => "# uno\n\n$PUERTA", 'CAMINO-2-y.md' => "# dos\n\n$PUERTA" }, 'PASA');
caso('un camino SIN el bloque', 'D5',
     { 'CAMINO-1-x.md' => "# uno\n\n$PUERTA", 'CAMINO-2-y.md' => "# dos\n\nsin puerta\n" }, 'FALLO');
caso('dos caminos con bloques DISTINTOS', 'D5',
     { 'CAMINO-1-x.md' => "# uno\n\n$PUERTA",
       'CAMINO-2-y.md' => "# dos\n\n## 🔴 LA PUERTA — el unico paso\n\notra cosa\n" }, 'FALLO');
# Un salto de linea de mas no es una divergencia: acusar por eso seria ruido.
caso('espacios y saltos de mas NO son divergencia', 'D5',
     { 'CAMINO-1-x.md' => "# uno\n\n$PUERTA",
       'CAMINO-2-y.md' => "# dos\n\n## 🔴 LA PUERTA — el unico paso\n\n\nbash references/deploy.sh DIR --subir\n\n" }, 'PASA');
caso('con un solo camino no aplica', 'D5',
     { 'CAMINO-1-x.md' => "# uno\n\nsin puerta\n" }, 'PASA');

# 🔴 14-ago-2026 · LOS CAMINOS VIVEN EN EL PADRE, Y POR ESO D5 NO CORRIA NUNCA.
#    En la skill de verdad los CAMINO-*.md estan en la RAIZ y el gate se lanza
#    desde `references/`. D5 ya miraba el directorio padre... derivandolo con
#    `$DIR =~ m{^(.*)[/\\][^/\\]+$}`, que **con `$DIR` = "." no casa**: el padre
#    acababa siendo "." otra vez y D5 respondia «menos de 2 caminos: no aplica».
#    Y "." es exactamente lo que vale `$DIR` cuando lo llama `run-all.sh`.
#    O sea que el check que comprueba que los cuatro documentos que alguien
#    SIGUE nombran la puerta de despliegue llevaba desde que se escribio saliendo
#    en verde sin mirar nada. Estos dos casos lo fijan desde el hijo: uno que
#    tiene que pasar y otro que tiene que acusar.
caso('los caminos se ven desde el directorio HIJO', 'D5',
     { 'CAMINO-1-x.md' => "# uno\n\n$PUERTA",
       'CAMINO-2-y.md' => "# dos\n\n$PUERTA",
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');
caso('...y desde el hijo tambien ACUSA', 'D5',
     { 'CAMINO-1-x.md' => "# uno\n\n$PUERTA",
       'CAMINO-2-y.md' => "# dos\n\nsin puerta\n",
       'references/relleno.md' => "# relleno\n" }, 'FALLO', 'references');

# 🔴 26-ago-2026 · EL PATRON NUMERICO RECOGIA LOS `references/` NUMERADOS.
#    `^[1-9][0-9]?-.*\.md$` existe para `paths/1-new-site.md`, y estaba aplicado
#    a los CUATRO directorios que D5 mira, incluido `$DIR`. En el repo `$DIR` es
#    `gates/` -sin `.md` numerados- y pasaba; en la skill es `references/`, que
#    tiene `10-` a `18-`, y los trataba como caminos exigiendoles el bloque de
#    la puerta. Mismo codigo, veredictos opuestos: repo PASA, skill «9 de 13».
#    Los nueve acusados eran documentos de referencia. El falso positivo vivio
#    porque NINGUN caso ponia un `.md` numerado al lado de los caminos.
#    Estos dos lo fijan: el numerado en `references/` no cuenta, y el de
#    `paths/` sigue contando -- si solo estuviera el primero, apagar el patron
#    entero tambien pasaria el banco.
caso('un references/ NUMERADO no es un camino', 'D5',
     { 'CAMINO-1-x.md'                  => "# uno\n\n$PUERTA",
       'CAMINO-2-y.md'                  => "# dos\n\n$PUERTA",
       'references/10-vocabulario.md'   => "# vocabulario\n\nsin puerta, y no le hace falta\n",
       'references/18-estandar.md'      => "# estandar\n\nsin puerta, y no le hace falta\n" },
     'PASA', 'references');
caso('...pero un paths/<n>-*.md SI lo es, y acusa', 'D5',
     { 'paths/1-nueva.md'               => "# uno\n\n$PUERTA",
       'paths/2-mejorar.md'             => "# dos\n\nsin puerta\n",
       'references/10-vocabulario.md'   => "# vocabulario\n\nsin puerta\n" },
     'FALLO', 'references');

print "\n== D6 . SKILL.md no puede mentir sobre su propia bateria\n";
#  D6 se anadio el 19-ago SIN caso, que es justo lo que la regla 5 prohibe. El
#  caso que importa es el segundo: si nadie puede ponerlo ROJO, no esta probado.
my $BAT  = "medido: 2026-08-19\nbancos: 19\nverde: 826\nrojo: 0\n";
my $BIEN = "# skill\n\n| Casos en verde | **826 . 0 en rojo** |\n";
my $VIEJO= "# skill\n\n| Casos en verde | **365 . 0 en rojo** |\n";
caso('el recuento coincide con la ultima bateria', 'D6',
     { 'SKILL.md' => $BIEN,
       'references/.ultima-bateria' => $BAT,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');
caso('...y CADUCADO se acusa (el caso que lo pone rojo)', 'D6',
     { 'SKILL.md' => $VIEJO,
       'references/.ultima-bateria' => $BAT,
       'references/relleno.md' => "# relleno\n" }, 'FALLO', 'references');
caso('sin bateria corrida se DICE, no se aprueba por defecto', 'D6',
     { 'SKILL.md' => $BIEN,
       'references/relleno.md' => "# relleno\n" }, 'AVISO', 'references');
caso('SKILL.md que no publica recuento: nada que caducar', 'D6',
     { 'SKILL.md' => "# skill\n\nprosa sin recuento de bateria\n",
       'references/.ultima-bateria' => $BAT,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');

#  🔴 26-ago-2026 · EL RECUENTO NO ES UNO, SON DOS, Y ESO ROMPIA D6.
#     `historial` sale NO MEDIDO en una instalacion nueva y PASA en cuanto la
#     maquina ha desplegado una vez. Ese dia, tras desplegar dos webs, la
#     bateria paso de 617 a 619 y D6 se puso rojo sin que nadie hubiera roto
#     nada. El arreglo obvio -subir el numero del README a 619- era el MALO:
#     habria dejado D6 en rojo para cualquiera que clone el repo y no haya
#     desplegado nunca. Un gate no puede exigir que la documentacion mienta a
#     los demas para callarse en tu maquina.
#     Ahora `run-all.sh` escribe tambien `verde-instalacion-limpia` y D6 acepta
#     los dos. Los tres casos de abajo son las tres situaciones, y el tercero
#     es el que prueba que aceptar dos numeros NO ha apagado el check.
my $BAT2 = "medido: 2026-08-26\nbancos: 20\nverde: 828\nrojo: 0\n"
         . "verde-instalacion-limpia: 826\ndepende-del-estado: 2\n";
caso('la maquina YA ha desplegado: vale el numero de instalacion limpia', 'D6',
     { 'SKILL.md' => $BIEN,
       'references/.ultima-bateria' => $BAT2,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');
caso('...y tambien vale el total de ESA maquina', 'D6',
     { 'SKILL.md' => "# skill\n\n| Casos en verde | **828 . 0 en rojo** |\n",
       'references/.ultima-bateria' => $BAT2,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');
caso('...pero un numero que no es NINGUNO de los dos sigue en rojo', 'D6',
     { 'SKILL.md' => $VIEJO,
       'references/.ultima-bateria' => $BAT2,
       'references/relleno.md' => "# relleno\n" }, 'FALLO', 'references');

#  🔴 28-ago-2026 · Y NO SON DOS, SON CUATRO: HAY DOS MODOS DE CORRIDA.
#     `--fast` se salta los 10 bancos lentos y da un total MUY distinto al de
#     la corrida completa (630 contra 728 el dia que se vio). Los dos numeros
#     son ciertos y los dos estan publicados en el README -que ademas dice de
#     cual habla-. Hasta ese dia `.ultima-bateria` guardaba solo la ultima
#     corrida SIN DECIR DE QUE MODO ERA, asi que D6 comparaba el numero del
#     README contra la corrida que hubiera pasado por ultima vez: VERDE tras
#     una rapida y ROJO tras una completa, sin que nadie tocara una linea.
#     Es la misma enfermedad que este gate persigue -dos cosas distintas en un
#     solo hueco, sin etiqueta- cometida dentro del propio instrumento.
#     Ahora el fichero lleva `modo:` y conserva las cifras del otro modo.
#     El tercer caso es el que prueba que aceptar cuatro numeros NO lo apaga.
my $BAT3 = "medido: 2026-08-28\nmodo: completo\nbancos: 28\nverde: 828\nrojo: 0\n"
         . "verde-instalacion-limpia: 826\ndepende-del-estado: 2\n"
         . "otro-modo: rapido\notro-modo-medido: 2026-08-28\n"
         . "otro-modo-verde: 730\notro-modo-verde-instalacion-limpia: 728\n";
caso('vale el numero del OTRO modo (el README publica los dos)', 'D6',
     { 'SKILL.md' => "# skill\n\n| Casos en verde | **730 . 0 en rojo** |\n",
       'references/.ultima-bateria' => $BAT3,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');
caso('...y el del modo de ESTA corrida sigue valiendo', 'D6',
     { 'SKILL.md' => "# skill\n\n| Casos en verde | **828 . 0 en rojo** |\n",
       'references/.ultima-bateria' => $BAT3,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');
caso('...pero un numero que no es NINGUNO de los CUATRO sigue en rojo', 'D6',
     { 'SKILL.md' => $VIEJO,
       'references/.ultima-bateria' => $BAT3,
       'references/relleno.md' => "# relleno\n" }, 'FALLO', 'references');

#  🔴 26-ago-2026 · EL NUMERO DE BATERIAS ERA OTRO DATO A MANO SIN VIGILAR.
#     Ese dia el README raiz decia «37 programs and 27 test batteries» cuando
#     ya eran 28, y estaba asi EN UN COMMIT YA EMPUJADO al repo publico. El
#     dato para compararlo ya existia -- `run-all.sh` escribe `bancos:` -- y
#     solo faltaba que alguien lo leyera. Un numero a mano en un documento
#     publico no caduca despacio: caduca callado.
my $BIEN_B = "# skill\n\n| Casos en verde | **826 . 0 en rojo** |\n\n20 test batteries.\n";
my $MAL_B  = "# skill\n\n| Casos en verde | **826 . 0 en rojo** |\n\n99 test batteries.\n";
caso('el numero de BATERIAS tambien coincide', 'D6',
     { 'SKILL.md' => $BIEN_B,
       'references/.ultima-bateria' => $BAT2,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');
caso('...y un numero de baterias caducado se acusa', 'D6',
     { 'SKILL.md' => $MAL_B,
       'references/.ultima-bateria' => $BAT2,
       'references/relleno.md' => "# relleno\n" }, 'FALLO', 'references');

#  🔴 16-sep-2026 · D6 LEIA «0 en rojo» Y «cases green», PERO NO «0 red».
#     Los documentos de este repo estan en ingles, y el README raiz publicaba su
#     recuento en la tercera forma: «**593 . 0 red** on --fast». Ninguno de los
#     tres patrones la veia, asi que ese numero envejecio 85 casos por debajo de
#     la bateria -- 593 contra 678 medidos ese dia- con D6 en VERDE y diciendo
#     que casaba «en 3 documentos». Un gate que dice cubrir tres ficheros y solo
#     entiende el idioma de dos es peor que uno que solo declarara dos: el
#     tercero se lee como vigilado.
#     Los dos casos son los dos signos, como manda la casa: si solo estuviera el
#     rojo, un patron que acusara a cualquier «0 red» pasaria igual.
my $ING_MAL  = "# skill\n\n| Test cases green | **365 . 0 red** on `--fast` |\n";
my $ING_BIEN = "# skill\n\n| Test cases green | **826 . 0 red** on `--fast` |\n";
caso('la forma INGLESA caducada tambien se acusa', 'D6',
     { 'SKILL.md' => $ING_MAL,
       'references/.ultima-bateria' => $BAT,
       'references/relleno.md' => "# relleno\n" }, 'FALLO', 'references');
caso('...y la forma inglesa CORRECTA no se acusa', 'D6',
     { 'SKILL.md' => $ING_BIEN,
       'references/.ultima-bateria' => $BAT,
       'references/relleno.md' => "# relleno\n" }, 'PASA', 'references');

#  🔴 28-sep-2026 · EN UN CLON RECIEN HECHO, D6 SALIA ROJO DESDE LA PRIMERA CORRIDA.
#     Tras la primera `--fast` el registro no tiene la otra corrida, y el README
#     publica las dos: la cifra de la completa no casaba con nada y se acusaba
#     como CADUCADA, cuando lo unico cierto es que esta maquina no la ha medido.
#     El mantenedor no lo veia porque su registro ya tiene las dos. Con un solo
#     modo medido, una cifra que no casa es NO MEDIDO; con los dos, FALLO, como
#     siempre. Un registro sin `modo:` (de antes del 28-ago) sigue como estaba.
my $BAT_1MODO = "medido: 2026-09-28\nmodo: rapido\nbancos: 20\nverde: 828\nrojo: 0\n"
              . "verde-instalacion-limpia: 826\ndepende-del-estado: 2\n";
caso('un solo modo medido y la cifra de la OTRA corrida -> NO MEDIDO, sale 3', 'D6',
     { 'SKILL.md' => "# skill\n\n| Casos en verde | **826 . 0 en rojo** en --fast, **1300 . 0 en rojo** en la completa |\n",
       'references/.ultima-bateria' => $BAT_1MODO,
       'references/relleno.md' => "# relleno\n" }, 'NO MEDIDO', 'references', { rc => 3, dice => qr/1300/ });
caso('...pero el numero de BATERIAS no depende del modo: sigue en rojo', 'D6',
     { 'SKILL.md' => "# skill\n\n| Casos en verde | **826 . 0 en rojo** |\n\n99 test batteries.\n",
       'references/.ultima-bateria' => $BAT_1MODO,
       'references/relleno.md' => "# relleno\n" }, 'FALLO', 'references', { rc => 1, dice => qr/99 baterias/ });

print "\n== D8 . la cobertura publicada tiene que ser la medida\n";
#  🔴 27-sep-2026 · D6 compara los CASOS de la bateria y nadie comparaba la
#     COBERTURA. Medido ese dia: de ocho cifras de coverage.pl publicadas en tres
#     documentos, CINCO estaban caducadas -- el total («123 of 138» con 126 de
#     140 medidos), el alcance de gates/README.md («88% ... 4 programs of 28»),
#     la fila de un programa («25 of 25» con 26) y el numero de programas en tres
#     sitios («38», que nacio mal: ese dia habia 37 ficheros y 36 programas).
#     Los textos de abajo son los de verdad, con su salto de linea y su cita.
#  Cada rojo nombra SU cifra (`dice`): un rojo por otra cifra del mismo
#  documento no prueba nada. Y NO MEDIDO tiene que salir 3 (`rc`).
my $BAT8 = "medido: 2026-09-27\nmodo: rapido\nbancos: 32\nverde: 787\nrojo: 0\n"
         . "cobertura-con-caso: 126\ncobertura-comprobaciones: 140\ncobertura-pct: 90\n"
         . "cobertura-programas-medidos: 4\ncobertura-programas: 36\n"
         . "cobertura-por-programa: qa-master.pl=84/96 linking-gate.pl=10/11 audit-vs-spec.pl=26/26 doc-gate.pl=6/7\n";
my $BAT8_VIEJA = "medido: 2026-09-20\nmodo: rapido\nbancos: 32\nverde: 780\nrojo: 0\n";
my $RAIZ8 = "# repo\n\n```\ngates/            The executable half. 36 programs and 32 test batteries.\n```\n\n"
          . "| Number | Today | What it means |\n|---|---|---|\n"
          . "| Checks **with a fixture** | **126 of 140 (90%)** | No check ships without a test |\n\n"
          . "> **And the second number states its own scope, which is the honest half of it.** That 90% is\n"
          . "> measured over **4 programs out of 36**. The coverage tool prints the 32 it does not measure,\n"
          . "> by name, on every run.\n";
my $GATES8 = "# gates\n\n36 programs and 32 test batteries. This file is the index.\n\n"
           . "| Program | What it does |\n|---|---|\n"
           . "| `coverage.pl` | How many checks have a test case. Today: **126 of 140 (90%)**. |\n"
           . "| `audit-vs-spec.pl` | The spec against the tree. **26 of 26 checks have a case.** |\n\n"
           . "The coverage figure has a scope you should know: **90% is measured over 4 programs of 36**,\n"
           . "not over everything.\n";
my $SKILL8 = "# skill\n\n| `gates/` | 36 programas y sus bancos |\n";
sub arbol8 {   # el arbol de verdad, con los cambios que pida el caso
    my (%cambia) = @_;
    my %f = ( 'README.md' => $RAIZ8, 'SKILL.md' => $SKILL8, 'references/README.md' => $GATES8,
              'references/.ultima-bateria' => $BAT8 );
    for my $k (keys %cambia) { if (defined $cambia{$k}) { $f{$k} = $cambia{$k} } else { delete $f{$k} } }
    return \%f;
}
# Cambia un trozo del texto de verdad, y AFIRMA que lo ha cambiado: un fixture
# que no llega a mutar deja pasar el caso sin haber probado nada.
sub con8 { my ($texto, $de, $por) = @_; my $n = ($texto =~ s/\Q$de\E/$por/g); die "arbol8: «$de» no esta\n" unless $n; $texto }

caso('todas las cifras casan con la bateria -> PASA (y sale 0)', 'D8',
     arbol8(), 'PASA', 'references', { rc => 0 });
caso('el total CADUCADO, el caso real (123 of 138) -> FALLO', 'D8',
     arbol8('README.md' => con8($RAIZ8, '**126 of 140 (90%)**', '**123 of 138 (89%)**')),
     'FALLO', 'references', { rc => 1, dice => qr/README\.md dice 123 \(con caso\)/ });
caso('sin bateria corrida -> NO MEDIDO, que sale 3 y no es un aprobado', 'D8',
     arbol8('references/.ultima-bateria' => undef), 'NO MEDIDO', 'references', { rc => 3 });
caso('con una bateria de ANTES de D8 (sin cobertura) -> NO MEDIDO', 'D8',
     arbol8('references/.ultima-bateria' => $BAT8_VIEJA), 'NO MEDIDO', 'references', { rc => 3 });
caso('documentos que no publican cobertura: nada que caducar, ni sin bateria', 'D8',
     { 'README.md' => "# repo\n\nprosa sin cifras\n", 'references/relleno.md' => "# relleno\n" },
     'PASA', 'references', { rc => 0 });
caso('el % del alcance, CADUCADO al otro lado del salto de linea -> FALLO', 'D8',
     arbol8('README.md' => con8($RAIZ8, 'That 90% is', 'That 89% is')),
     'FALLO', 'references', { dice => qr/README\.md dice 89 \(% del alcance\)/ });
caso('el alcance «4 programs of 28» de gates/README.md -> FALLO', 'D8',
     arbol8('references/README.md' => con8($GATES8, '**90% is measured over 4 programs of 36**',
                                                    '**88% is measured over 4 programs of 28**')),
     'FALLO', 'references', { dice => qr/dice 28 \(programas del alcance\)/ });
caso('«prints the 33 it does not measure» cuando son 36 - 4 -> FALLO', 'D8',
     arbol8('README.md' => con8($RAIZ8, 'prints the 32 it', 'prints the 33 it')),
     'FALLO', 'references', { dice => qr/dice 33 \(programas sin medir\)/ });
caso('la fila de un programa, CADUCADA (25 of 25) -> FALLO', 'D8',
     arbol8('references/README.md' => con8($GATES8, '**26 of 26 checks', '**25 of 25 checks')),
     'FALLO', 'references', { dice => qr/dice 25 \(audit-vs-spec\.pl con caso\)/ });
caso('la cobertura de un programa que la bateria NO mide -> FALLO', 'D8',
     arbol8('references/README.md' => $GATES8 . "| `citable.pl` | Citability. **10 of 10 checks have a case.** |\n"),
     'FALLO', 'references', { dice => qr/citable\.pl.*la bateria no mide eso/ });
caso('«38 programs» cuando son 36 -> FALLO', 'D8',
     arbol8('references/README.md' => con8($GATES8, '36 programs and 32', '38 programs and 32')),
     'FALLO', 'references', { dice => qr/gates\/README\.md dice 38 \(programas\)/ });
caso('...y en castellano, «38 programas» -> FALLO', 'D8',
     arbol8('SKILL.md' => con8($SKILL8, '36 programas', '38 programas')),
     'FALLO', 'references', { dice => qr/SKILL\.md dice 38 \(programas\)/ });
caso('la forma castellana del total, CADUCADA -> FALLO', 'D8',
     arbol8('SKILL.md' => $SKILL8 . "\nTOTAL: 123 de 138 comprobaciones tienen caso (89%)\n"),
     'FALLO', 'references', { dice => qr/SKILL\.md dice 123 \(con caso\)/ });

print "\n== D9 . lo que publica UN instrumento tiene que ser lo medido\n";
#  🔴 28-sep-2026 · D6 vigila el TOTAL de la bateria y D8 la cobertura, pero
#     gates/README.md publica ademas lo que imprime UN instrumento: el indice
#     REGLA -> INSTRUMENTO («257 rules, 159 with an instrument (62%)», y su
#     salida pegada: «checks emitted ... 157», «with no rule claiming it .. 89»)
#     y los casos de UN banco («159 cases», «371 cases»). Medido ese dia: dos de
#     esas cifras llevaban caducadas desde que se escribieron (158 y 90), y una
#     tercera en la prosa repetia el 89.
#  El banco de cada «N cases» sale de la lista BANCOS de run-all.sh -- el mismo
#  fichero que los ejecuta --, asi que el fixture trae la suya.
my $RUNALL9 = "#!/usr/bin/env bash\nBANCOS=\"\n"
            . "qa-maestro|bash qa-master-tests/tests.sh|1|las 5 lentes\n"
            . "gate-estructura|bash structure-gate-tests/battery.sh|1|maqueta\n"
            . "indice-gates|node gate-index.js|0|el indice\n\"\n";
my $BAT9 = "medido: 2026-09-28\nmodo: completo\nbancos: 2\nverde: 530\nrojo: 0\n"
         . "casos-por-banco: qa-maestro=371 indice-gates=159\n"
         . "indice-reglas: 257\nindice-con-instrumento: 159\nindice-con-instrumento-pct: 62\n"
         . "indice-sin-instrumento: 98\nindice-medibles: 42\nindice-parciales: 16\nindice-juicio: 40\n"
         . "indice-techo: 217\nindice-techo-pct: 84\n"
         . "indice-emitidos: 158\nindice-sin-regla: 90\nindice-sin-regla-pct: 57\n";
my $GATES9 = "# gates\n\n| Program | What it does |\n|---|---|\n"
           . "| `gate-index.js` | The RULE -> INSTRUMENT index. **159 cases.** See below. |\n"
           . "| `coverage.pl` | How many checks have a test case. |\n\n"
           . "`gate-index.js` has always answered one question -- 257 rules,\n"
           . "**159 with an instrument (62%)**, the other 98 listed with `--huecos`.\n\n"
           . "```\n  checks emitted .......... 158\n  with no rule claiming it .. 90   (57%)\n```\n\n"
           . "- **`qa-master-tests/tests.sh` no longer needs its capture.** Every case runs against\n"
           . "  a synthetic site. On a clean clone the bank runs\n  **371 cases** and exits **0**.\n"
           # La viñeta HERMANA, sin linea en blanco por medio, como en el README real:
           # el primer D9 cortaba por lineas en blanco, veia DOS bancos en el mismo
           # bloque y no atribuia el 371 a nadie -- y este fixture, sin ella, no lo veia.
           . "- `structure-gate-tests/battery.sh` marks the eight affected cases `NOT MEASURED`\n"
           . "  individually, and exits **3** if any were skipped.\n";
sub arbol9 {
    my (%cambia) = @_;
    my %f = ( 'references/README.md' => $GATES9, 'references/run-all.sh' => $RUNALL9,
              'references/.ultima-bateria' => $BAT9 );
    for my $k (keys %cambia) { if (defined $cambia{$k}) { $f{$k} = $cambia{$k} } else { delete $f{$k} } }
    return \%f;
}
sub con9 { my ($texto, $de, $por) = @_; my $n = ($texto =~ s/\Q$de\E/$por/g); die "arbol9: «$de» no esta\n" unless $n; $texto }

caso('todas las cifras del instrumento casan -> PASA (y sale 0)', 'D9',
     arbol9(), 'PASA', 'references', { rc => 0 });
caso('«checks emitted 157» cuando son 158 (el caso real) -> FALLO', 'D9',
     arbol9('references/README.md' => con9($GATES9, 'checks emitted .......... 158', 'checks emitted .......... 157')),
     'FALLO', 'references', { rc => 1, dice => qr/dice 157 \(checks emitidos\)/ });
caso('«with no rule claiming it 89» cuando son 90 (el caso real) -> FALLO', 'D9',
     arbol9('references/README.md' => con9($GATES9, 'claiming it .. 90', 'claiming it .. 89')),
     'FALLO', 'references', { dice => qr/dice 89 \(sin regla\)/ });
caso('«159 with an instrument» CADUCADO en la frase -> FALLO', 'D9',
     arbol9('references/README.md' => con9($GATES9, '**159 with an instrument (62%)**', '**158 with an instrument (61%)**')),
     'FALLO', 'references', { dice => qr/dice 158 \(con instrumento\)/ });
caso('los casos de UN banco, CADUCADOS en su fila (159 cases) -> FALLO', 'D9',
     arbol9('references/README.md' => con9($GATES9, '**159 cases.**', '**150 cases.**')),
     'FALLO', 'references', { dice => qr/dice 150 \(casos de indice-gates\)/ });
caso('...y en una viñeta con OTRA al lado, cada una con su banco (371) -> FALLO', 'D9',
     arbol9('references/README.md' => con9($GATES9, '**371 cases**', '**131 cases**')),
     'FALLO', 'references', { dice => qr/dice 131 \(casos de qa-maestro\)/ });
caso('sin bateria corrida -> NO MEDIDO, que sale 3', 'D9',
     arbol9('references/.ultima-bateria' => undef), 'NO MEDIDO', 'references', { rc => 3 });
caso('con una bateria de ANTES de D9 (sin indice ni casos) -> NO MEDIDO', 'D9',
     arbol9('references/.ultima-bateria' => $BAT8_VIEJA), 'NO MEDIDO', 'references', { rc => 3 });
caso('un banco que ninguna corrida ha medido -> NO MEDIDO, y lo nombra', 'D9',
     arbol9('references/.ultima-bateria' => con9($BAT9, 'qa-maestro=371 ', '')),
     'NO MEDIDO', 'references', { rc => 3, dice => qr/qa-maestro/ });
caso('documentos que no publican nada de un instrumento: PASA sin bateria', 'D9',
     { 'README.md' => "# repo\n\nprosa sin cifras\n", 'references/relleno.md' => "# relleno\n" },
     'PASA', 'references', { rc => 0 });
caso('«**N cases**» sin el fichero de ningun banco al lado no se atribuye', 'D9',
     arbol9('references/README.md' => $GATES9 . "\nThe old run stopped at **85 cases.** before the rename.\n"),
     'PASA', 'references', { rc => 0 });
caso('la salida castellana pegada, CADUCADA -> FALLO', 'D9',
     arbol9('references/README.md' => $GATES9 . "\n```\n    con instrumento .........  158   (61%)\n```\n"),
     'FALLO', 'references', { dice => qr/dice 158 \(con instrumento\)/ });


printf "\n-----------------------------------------------------------------\n";
printf "  OK %-3d  ·  MAL %d\n", $ok, $ko;
print $ko ? "  🔴 HAY FALLOS: el gate de documentacion no es de fiar.\n"
          : "  Acusa lo que puede probar, y calla en lo que no.\n";
exit($ko ? 1 : 0);
