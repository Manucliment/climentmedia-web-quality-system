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
#   $espera: 'PASA' o 'FALLO' para esa comprobacion
sub caso {
    my ($eti, $lista, $ficheros, $espera, $desde) = @_;
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
    my ($linea) = $salida =~ /^(PASA|FALLO|AVISO)\s+\Q$lista\E\b.*$/m;
    my $real = $linea // 'SIN LINEA';
    $real =~ s/\s.*//;
    if ($real eq $espera) { printf "  OK    %-56s %s=%s\n", $eti, $lista, $real; $ok++ }
    else { printf "  MAL   %-56s esperaba %s y salio %s\n", $eti, $espera, $real; $ko++;
           print "        $_\n" for grep { /^(PASA|FALLO|AVISO)/ } split /\n/, $salida }
}

my $PROG = "#!/usr/bin/perl\n# de mentira\nif (\$x eq '--real') { }\nif (\$x eq '--otra') { }\n";
my $TRAMPA_OK = "# Trampas\n\n## 1 · algo\n\n**Lo caza:** `algo-pruebas/tests.pl`\n\ntexto\n";

print "\n== D1 · RUTAS: solo se acusa lo que se puede PROBAR\n";
caso('cita references/ que NO existe', 'D1',
     { 'doc.md' => "Se corre con `references/no-existe.pl`.\n", 'real.pl' => $PROG }, 'FALLO');
caso('cita references/ que SI existe', 'D1',
     { 'doc.md' => "Se corre con `references/real.pl`.\n", 'real.pl' => $PROG }, 'PASA');

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


printf "\n-----------------------------------------------------------------\n";
printf "  OK %-3d  ·  MAL %d\n", $ok, $ko;
print $ko ? "  🔴 HAY FALLOS: el gate de documentacion no es de fiar.\n"
          : "  Acusa lo que puede probar, y calla en lo que no.\n";
exit($ko ? 1 : 0);
