#!/usr/bin/perl
# =============================================================================
#  Prueba de audit-vs-spec.pl · el gate que tenia 24 comprobaciones y CERO casos
# =============================================================================
#    perl "/path/to/web-quality-system/gates/audit-vs-spec-tests/tests.pl"
#
#  🔴 POR QUE NACE ESTE BANCO, y por que el primer caso es el que es.
#     `coverage.pl` saco el 13-ago-2026 que este programa —775 lineas,
#     24 comprobaciones— tenia **0 de 24 con caso**. Era el peor numero de la
#     tabla. Al ir a mirarlo, la primera corrida contra un repo real:
#
#         $ perl audit-vs-spec.pl --modo migracion     # en site-e-web
#         Not an ARRAY reference at audit-vs-spec.pl line 181.
#
#     El gate **se moria**. Y morir asi es el peor final: sin veredicto, sin ID
#     y sin linea en el recibo. No dice «esta mal»: no dice NADA, y quien lo
#     lanza se queda sin saber si su sitio pasa.
#
#     Causa: `@{ $site->{legal} }` daba por hecho que `legal` es una lista de
#     paginas. Lo es en site-d y en site-a; en site-c es un HASH de ajustes. La
#     misma clave, dos significados, y ninguna spec estaba mal — nadie habia
#     escrito nunca que forma tenia que tener.
#
#  ⚠️ Hermetico: fabrica sus propios repos de mentira en un temporal. No lee
#     ninguna spec de verdad y no toca la red.
# =============================================================================
use strict; use warnings;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

use Cwd qw(abs_path);
# 🔴 ABSOLUTA, y no es cosmetico: cada caso hace `cd` a un temporal antes de
#    lanzar el gate. Con la ruta relativa (`$0/../audit-vs-spec.pl`) el banco
#    PASABA lanzado con ruta absoluta y FALLABA -4 OK, 5 MAL- lanzado como
#    `perl audit-vs-spec-tests/tests.pl` desde references/, que es como lo
#    llama `run-all.sh`. Una prueba cuyo resultado depende de desde donde
#    la lances no prueba nada. Es la trampa §7 de 07-trampas.md, en mi propio
#    banco y el mismo dia.
my $DIR = $0; $DIR =~ s{[/\\][^/\\]+$}{}; $DIR = '.' if $DIR eq $0;
my $GATE = abs_path("$DIR/../audit-vs-spec.pl") // "$DIR/../audit-vs-spec.pl";
die "no encuentro $GATE\n" unless -f $GATE;

my ($ok, $ko) = (0, 0);

#  $espera: 'MUERE' | ID que tiene que salir | '!ID' que NO puede salir
sub caso {
    my ($eti, $site_json, $espera, $modo, $extra) = @_;
    $modo ||= 'migracion';
    my $t = tempdir(CLEANUP => 1);
    make_path("$t/_spec");
    open my $h, '>:raw', "$t/_spec/site.json" or die $!;
    print $h $site_json; close $h;
    # una pagina en disco, para que el gate tenga algo que mirar
    open my $p, '>:raw', "$t/index.html" or die $!;
    print $p "<!DOCTYPE html><html><head><title>t</title></head><body><main><h1>t</h1></main></body></html>";
    close $p;
    # Ficheros extra del caso, con ruta relativa al repo de mentira. Hacen falta
    # para lo que NO se contesta solo con site.json: paginas en disco, el
    # generador y el runtime.
    for my $rel (sort keys %{ $extra || {} }) {
        my $abs = "$t/$rel";
        (my $dir = $abs) =~ s{[/\\][^/\\]+$}{};
        make_path($dir) if $dir ne $abs && !-d $dir;
        open my $f, '>:raw', $abs or die "no puedo escribir $abs: $!\n";
        print $f $extra->{$rel}; close $f;
    }

    my $salida = `cd "$t" && perl "$GATE" --modo $modo 2>&1`;
    my $murio  = ($salida =~ /Not an ARRAY|Can't use|at .*\.pl line \d+\.$/m) ? 1 : 0;

    if ($espera eq 'MUERE') {
        if ($murio) { printf "  OK    %-54s murio, como se esperaba\n", $eti; $ok++ }
        else { printf "  MAL   %-54s NO murio (y el caso espera que muera)\n", $eti; $ko++ }
        return;
    }
    if ($murio) {
        printf "  MAL   %-54s SE HA MUERTO\n", $eti; $ko++;
        print "        ", (grep { /line \d+/ } split /\n/, $salida)[0] // '', "\n";
        return;
    }
    my ($no, $id) = $espera =~ /^(!?)(.+)$/;
    # 🔴 «FALLO:ID» busca el ID **en un renglon de ese estado**, no en cualquier
    #    parte de la salida. Hacia falta desde el 14-ago: los checks que tambien
    #    imprimen `ok  LEG-01  ...` cuando pasan hacian que un `!LEG-01` no
    #    pudiera cumplirse NUNCA -- el ID sale igual, con otro estado delante.
    #    Un caso que no puede pasar no es un caso: es ruido rojo permanente.
    my $sale;
    if ($id =~ /^(FALLO|AVISO|ok|NO VERIF):(.+)$/) {
        my ($est, $cid) = ($1, $2);
        $sale = ($salida =~ /^\s*\S*\s*\Q$est\E\s+\Q$cid\E\b/m) ? 1 : 0;
    } else {
        $sale = ($salida =~ /\b\Q$id\E\b/) ? 1 : 0;
    }
    if (($no eq '!' && !$sale) || ($no eq '' && $sale)) {
        printf "  OK    %-54s %s%s\n", $eti, ($no ? 'no sale ' : 'sale '), $id; $ok++;
    } else {
        printf "  MAL   %-54s esperaba %s%s\n", $eti, ($no ? 'NO ' : ''), $id; $ko++;
        print "        ", join("\n        ", (split /\n/, $salida)[0..3]), "\n";
    }
}

my $BASE = '"sitio":"https://ejemplo.test","nombre":"Ejemplo"';

print "\n== NO MORIRSE · la forma de una coleccion no la adivina nadie\n";
# El caso EXACTO de site-c, que es el que tumbaba el gate.
caso('`legal` como HASH de ajustes (el caso de site-c)',
     "{$BASE,\"legal\":{\"aviso_legal\":\"si\",\"titular_necesario\":[\"nif\"]}}", 'ESQ-03');
caso('...y no revienta',
     "{$BASE,\"legal\":{\"aviso_legal\":\"si\",\"titular_necesario\":[\"nif\"]}}", '!Not an ARRAY');
# La forma normal sigue funcionando: el arreglo no puede haberla roto.
caso('`legal` como LISTA de paginas (site-d, site-a)',
     "{$BASE,\"legal\":[{\"slug\":\"aviso-legal\"}]}", '!ESQ-03');
# Un hash cuyas claves son slugs SI se puede leer: es la misma coleccion escrita
# de otra forma, y acusarla seria un falso positivo.
caso('`legal` como hash slug => registro SI se lee',
     "{$BASE,\"legal\":{\"aviso-legal\":{\"slug\":\"aviso-legal\"}}}", '!ESQ-03');
# Medio y medio no se sabe leer, y entonces se dice.
caso('un hash a medias se declara, no se adivina',
     "{$BASE,\"legal\":{\"aviso-legal\":{\"slug\":\"aviso-legal\"},\"nota\":\"texto\"}}", 'ESQ-03');
caso('un escalar donde se esperaba una lista',
     "{$BASE,\"cities\":\"madrid\"}", 'ESQ-03');
caso('sin la clave no se dice nada (no es un hueco)',
     "{$BASE}", '!ESQ-03');

print "\n== Y LAS OTRAS COLECCIONES, por el mismo camino\n";
caso('`categories` como hash de ajustes',
     "{$BASE,\"categories\":{\"orden\":\"alfabetico\"}}", 'ESQ-03');
caso('`cities` como hash de ajustes',
     "{$BASE,\"cities\":{\"radio_km\":30}}", 'ESQ-03');

print "\n== PAG-01 · lo que la spec RETIRA a proposito no es una pagina que falte\n";
# 🔴 EL DEFECTO (14-ago-2026): en site-c.example este check acusaba a
#    /tienda, /carrito, /finalizar-compra y /mi-cuenta -- el WooCommerce VACIO
#    que el cliente decidio retirar, declarado en `urls.se_retiran` CON su
#    motivo -- y a la PORTADA, porque su registro viene de WordPress con
#    slug "home" y el gate buscaba `home/index.html`. Cinco de seis acusaciones
#    eran decisiones ya tomadas y escritas.
caso('una pagina declarada y ausente SIGUE fallando',
     "{$BASE,\"cities\":[{\"slug\":\"tienda\"}]}", 'FALLO:PAG-01');
caso('...pero si la spec la RETIRA, no',
     "{$BASE,\"cities\":[{\"slug\":\"tienda\"}],\"urls\":{\"se_retiran\":{\"/tienda\":\"WooCommerce vacio\"}}}", '!FALLO:PAG-01');
# Y se DICE que se salto: un hueco declarado sigue siendo un hueco con dueno.
caso('...y se anota cuantas se saltaron',
     "{$BASE,\"cities\":[{\"slug\":\"tienda\"}],\"urls\":{\"se_retiran\":{\"/tienda\":\"WooCommerce vacio\"}}}", 'AVISO:PAG-01b');
# La barra inicial no puede decidir nada: "/tienda" y "tienda" son la misma.
caso('la barra de delante da igual',
     "{$BASE,\"cities\":[{\"slug\":\"tienda\"}],\"urls\":{\"se_retiran\":[\"tienda\"]}}", '!FALLO:PAG-01');
# La portada: su registro dice tipo "page" y slug "home", y vive en index.html.
caso('la portada con slug «home» vive en index.html',
     "{$BASE,\"cities\":[{\"slug\":\"home\",\"tipo\":\"page\"}]}", '!FALLO:PAG-01');

print "\n== MED-01 · un comentario NO es codigo, y el gate tambien es un lector\n";
# 🔴 EL DEFECTO: acusaba a `data-conversion` de no tener lector. No lo tiene
#    porque SE QUITO, y lo unico que queda en el generador es el comentario que
#    explica por que. El gate acusaba a la documentacion del arreglo.
caso('un data-* de verdad sin lector SIGUE fallando',
     "{$BASE}", 'FALLO:MED-01', 'migracion',
     { '_gen.ps1' => "\$h += '<main data-conversion=\"lead\">'\n",
       'script.js' => "console.log('nada');\n" });
# 🔴 18-ago-2026 · Y EL CSS TAMBIEN ES UN LECTOR. El molde 15 emite `data-col`
#    y su mecanismo movil es `content: attr(data-col)`: el atributo tiene lector,
#    y es el que hace la tabla usable en un movil. El check solo miraba script.js.
caso('un data-* que lee el CSS con attr() NO es mudo',
     "{$BASE}", '!FALLO:MED-01', 'migracion',
     { '_gen.ps1'   => "\$h += '<td data-col=\"Frecuencia\">'\n",
       'script.js'  => "console.log('nada');\n",
       'styles.css' => "td::before{content:attr(data-col)}\n" });
caso('y con un selector [data-x] tampoco',
     "{$BASE}", '!FALLO:MED-01', 'migracion',
     { '_gen.ps1'   => "\$h += '<div data-estado=\"abierto\">'\n",
       'script.js'  => "console.log('nada');\n",
       'styles.css' => "[data-estado]{display:block}\n" });
caso('pero uno que no lee NI el CSS NI el JS sigue cayendo',
     "{$BASE}", 'FALLO:MED-01', 'migracion',
     { '_gen.ps1'   => "\$h += '<div data-inventado=\"1\">'\n",
       'script.js'  => "console.log('nada');\n",
       'styles.css' => "body{margin:0}\n" });
caso('...pero si solo esta en un COMENTARIO, no',
     "{$BASE}", '!FALLO:MED-01', 'migracion',
     { '_gen.ps1' => "# AQUI habia un data-conversion=\"lead\" y se quito el 12-ago\n\$h += '<main>'\n",
       'script.js' => "console.log('nada');\n" });
# 🔴 Y el caso que hacia falta para poder cablear data-sec a una web: estos dos
#    atributos los lee el GATE (qa-maestro EST-02), no el navegador. Sin esta
#    excepcion, arreglar la anatomia de una web la ponia en rojo.
caso('data-tipo y data-sec: su lector es el gate, no el runtime',
     "{$BASE}", '!FALLO:MED-01', 'migracion',
     { '_gen.ps1' => "\$h += '<main data-tipo=\"servicio\"><section data-sec=\"hero\">'\n",
       'script.js' => "console.log('nada');\n" });

print "\n== LEG-01 · la pagina puede declarar que es legal de tres formas\n";
# 🔴 EL DEFECTO: «la spec no declara ninguna pagina legal» sobre una web con
#    TRES publicadas. El gate solo miraba la coleccion `legal` de site.json, y
#    esa web la usa para otra cosa (los datos del titular que faltan).
my $LEGALON = '<!DOCTYPE html><html><head><title>Aviso legal</title></head><body>'
            . '<main data-tipo="legal"><h1>Aviso legal</h1><p>'
            . ('texto legal de verdad del cliente, con su longitud. ' x 30)
            . '</p></main></body></html>';
caso('sin ninguna declaracion, SIGUE fallando',
     "{$BASE}", 'FALLO:LEG-01');
caso('declarada en tipos.por_slug',
     "{$BASE,\"cities\":[{\"slug\":\"aviso-legal\"}],\"tipos\":{\"por_slug\":{\"aviso-legal\":\"legal\"}}}",
     '!FALLO:LEG-01', 'migracion', { 'aviso-legal/index.html' => $LEGALON });
# La mas fuerte de las tres: lo que se SIRVE. Es lo que lee qa-maestro y lo que
# ve Google, y manda sobre cualquier cosa que diga la spec.
caso('declarada con data-tipo="legal" en el propio HTML',
     "{$BASE,\"cities\":[{\"slug\":\"aviso-legal\"}]}",
     '!FALLO:LEG-01', 'migracion', { 'aviso-legal/index.html' => $LEGALON });
# Y no se afloja el listón: una legal con marcador de pendiente sigue en rojo.
caso('una legal con «pendiente de revision» SIGUE fallando',
     "{$BASE,\"cities\":[{\"slug\":\"aviso-legal\"}]}",
     'FALLO:LEG-01', 'migracion',
     { 'aviso-legal/index.html' => '<!DOCTYPE html><html><head><title>x</title></head><body>'
       . '<main data-tipo="legal"><h1>Aviso legal</h1><p>Pendiente de revision juridica. '
       . ('relleno para pasar de los 800 caracteres y que falle por el marcador. ' x 20)
       . '</p></main></body></html>' });

# =============================================================================
#  17-ago-2026 · LOS GATES QUE SOSTIENEN LA FASE DE **CREACION**
# =============================================================================
#  🔴 POR QUE ESTA TANDA. `CAMINO-1-web-nueva.md` tiene 14 pasos y **los 14
#     declaran su gate**: sobre el papel, el proceso esta entero de la A a la Z.
#     Medido el 17-ago, la verdad era otra: **7 de esos 14 pasos se apoyan en
#     `audit-vs-spec.pl`, que era el programa MENOS probado del instrumento**
#     -5 de 25 comprobaciones con caso-. Y los 20 sin caso no eran los raros:
#     eran justo los del camino de CREAR una web.
#
#       INT-01/02/03 -> paso 1  · Intake
#       ESQ-01/02    -> paso 1b · Greenfield, y son el umbral que el propio
#                                 documento nombra: nunca se habian visto fallar
#       ANA-01/02    -> paso 4  · Anatomia
#       ENL-01       -> paso 3  · Arquitectura y enlazado
#
#     Un proceso escrito entero cuyos gates no se han visto en ROJO no es un
#     proceso: es un indice.
# =============================================================================

print "\n== PASO 1b · GREENFIELD: el umbral que decide si se clona el esqueleto\n";
# 🔴 ESQ-01 · site-d es el UNICO de los 5 repos SIN 404.html, y es justo el
#    repo del que se clona el esqueleto. Produccion devuelve el 404 de Apache:
#    796 bytes y CERO enlaces, en una web de 40 paginas que paga clics. Sin este
#    check, ese agujero viaja en cada copia.
caso('ESQ-01 · sin 404, el esqueleto no se clona',
     "{$BASE}", 'FALLO:ESQ-01', 'greenfield');
caso('ESQ-01 · con 404.html, pasa',
     "{$BASE}", 'ok:ESQ-01', 'greenfield',
     { '404.html' => '<!DOCTYPE html><html><head><title>404</title></head><body><main><h1>No existe</h1><p><a href="/">Inicio</a></p></main></body></html>' });
# La otra forma valida: carpeta. Si el check solo mirase el fichero suelto,
# acusaria a media docena de webs bien montadas.
caso('ESQ-01 · y 404/index.html tambien vale',
     "{$BASE}", 'ok:ESQ-01', 'greenfield',
     { '404/index.html' => '<!DOCTYPE html><html><head><title>404</title></head><body><main><h1>No existe</h1></main></body></html>' });

# 🔴 ESQ-02 · el favicon de site-a eran **320.221 bytes servidos en 13 paginas**.
#    Un icono de 32 px pesando mas que la hoja de estilos entera.
caso('ESQ-02 · un favicon de 300 KB FALLA',
     "{$BASE}", 'FALLO:ESQ-02', 'greenfield',
     { '404.html' => '<html><body><main><h1>x</h1></main></body></html>',
       'favicon.png' => ('B' x 300_000) });
caso('ESQ-02 · uno de 3 KB pasa',
     "{$BASE}", 'ok:ESQ-02', 'greenfield',
     { '404.html' => '<html><body><main><h1>x</h1></main></body></html>',
       'favicon.png' => ('B' x 3_000) });
# Y el control que evita el falso positivo mas tonto: sin favicon no se puede
# acusar de que pese demasiado. Son dos hallazgos distintos.
caso('ESQ-02 · sin favicon NO se acusa de peso',
     "{$BASE}", '!FALLO:ESQ-02', 'greenfield',
     { '404.html' => '<html><body><main><h1>x</h1></main></body></html>' });

print "\n== PASO 1 · INTAKE: lo que bloquea empezar\n";
# 🔴 INT-01 · un intake incompleto no se nota hasta el final, cuando ya no hay
#    a quien preguntarle sin quedar mal. Son 7 datos y el gate los nombra.
caso('INT-01 · una spec sin NAP FALLA',
     "{$BASE}", 'FALLO:INT-01', "greenfield");
caso('INT-01 · con los 7 datos, pasa',
     "{$BASE," .
     '"brand":{"name":"Ejemplo","legalName":"Ejemplo SL"},' .
     '"nap":{"telephone":"+34600000000","email":"hola@ejemplo.test",' .
     '"hoursDisplay":"L-V 9-18","streetAddress":"Calle 1","areaServed":["Madrid"]}}',
     'ok:INT-01', "greenfield");
# «No publicamos la direccion» es una DECISION valida y hay que poder declararla:
# si el gate exigiera calle siempre, una web sin oficina no podria pasar nunca y
# el check se acabaria ignorando.
# ⚠️ Y OJO CON LA FORMA: `"noAddress": true` **NO cuenta**. El gate exige un
#    valor con texto (un booleano de JSON es una referencia y lo descarta), asi
#    que hay que escribir el MOTIVO. No es una pega: una spec que dice «no
#    publicamos direccion porque se atiende a domicilio» se entiende dentro de
#    seis meses; un `true` no. Este caso lo fija para que nadie lo relaje.
caso('INT-01 · «no publicamos direccion» es declarable',
     "{$BASE," .
     '"brand":{"name":"Ejemplo","legalName":"Ejemplo SL"},' .
     '"nap":{"telephone":"+34600000000","email":"hola@ejemplo.test",' .
     '"hoursDisplay":"L-V 9-18","noAddress":"no se publica: se atiende a domicilio",' .
     '"areaServed":["Madrid"]}}',
     'ok:INT-01', "greenfield");
caso('INT-01 · ...pero un `true` pelado NO vale, y es a proposito',
     "{$BASE," .
     '"brand":{"name":"Ejemplo","legalName":"Ejemplo SL"},' .
     '"nap":{"telephone":"+34600000000","email":"hola@ejemplo.test",' .
     '"hoursDisplay":"L-V 9-18","noAddress":true,"areaServed":["Madrid"]}}',
     'FALLO:INT-01', "greenfield");

# 🔴 INT-02 · «a donde llegan los leads» es EL dato que mas caro sale olvidar:
#    en site-a el formulario mostraba EXITO con el CRM de destino dado de baja.
caso('INT-02 · sin destino de los leads, FALLA',
     "{$BASE}", 'FALLO:INT-02', "greenfield");
# Las claves que el gate acepta son `form.to`, `contact.to` y `nap.leadsTo`.
# Se fijan aqui porque son la clase de dato que uno escribe donde le parece.
caso('INT-02 · declarado en form.to, pasa',
     "{$BASE,\"form\":{\"to\":\"leads\@site-a.be\"}}", 'ok:INT-02', 'greenfield');
# 🔴 18-ago-2026 · Y UN PLACEHOLDER NO CUENTA COMO BUZON. Estos dos casos usaban
#    `leads@ejemplo.test` para demostrar que el check PASA: el banco fijaba justo
#    el agujero. references/form-handler.php se copia a _deploy/contact.php y
#    traia escrito `contact@ejemplo.tld`, asi que copiar la plantilla y no tocarla
#    aprobaba el check que existe por el CRM muerto de site-a.
caso('INT-02 · con la direccion de la PLANTILLA, FALLA',
     "{$BASE}", 'FALLO:INT-02', 'greenfield',
     { '_deploy/contact.php' => '<?php $to = "contact@ejemplo.tld"; ?>' });
# 🔴 18-ago-2026 (misma tarde) · Y UN COMENTARIO NO ES CONFIGURACION. Este
#    programa no quitaba comentarios en NINGUNA de sus 15 lecturas -- qa-maestro lo
#    hace en 20 sitios--, asi que un `// TODO: poner info@cliente.be` ponia INT-02
#    en verde mientras la constante seguia en el valor de la plantilla. Es la
#    trampa §43 otra vez, en el mismo fichero y el mismo dia en que se escribio.
caso('INT-02 · un buzon que solo vive en un COMENTARIO no cuenta',
     "{$BASE}", 'FALLO:INT-02', 'greenfield',
     { '_deploy/contact.php' => "<?php\n// TODO: poner info\@site-a.be cuando conteste\nconst MAIL_TO = \"RELLENAR\@ejemplo.tld\";\n" });
caso('INT-02 · y una URL https:// no la parte el quita-comentarios',
     "{$BASE}", 'ok:INT-02', 'greenfield',
     { '_deploy/contact.php' => "<?php\nconst SITE = \"https://site-a.be\";\nconst MAIL_TO = \"info\@site-a.be\";\n" });
caso('INT-02 · un buzon de ejemplo en la spec tampoco cuela',
     "{$BASE,\"form\":{\"to\":\"leads\@ejemplo.test\"}}", 'FALLO:INT-02', 'greenfield');
# Y la otra via: sin declararlo en la spec pero con un receptor real en disco.
# Es como estan hoy site-a y site-d, y contarlo como hueco seria falso.
caso('INT-02 · o con un contact.php que tiene buzon',
     "{$BASE}", 'ok:INT-02', 'greenfield',
     { '_deploy/contact.php' => '<?php $to = "leads@site-a.be"; ?>' });

# INT-03 es AVISO y no fallo a proposito: no saber quien aprueba no impide
# construir, impide ENTREGAR. Se dice y se sigue.
caso('INT-03 · sin aprobador, AVISA (no bloquea)',
     "{$BASE}", 'AVISO:INT-03', "greenfield");
caso('INT-03 · con nombre, pasa',
     "{$BASE,\"approver\":\"Manuel Climent\"}", 'ok:INT-03', "greenfield");

print "\n== PASO 10 · INVENTARIO: lo que se publica y nadie declaro\n";
# INV-01 es AVISO y no fallo: una pagina en disco que la spec no declara suele
# ser un resto de una tanda anterior, no un defecto. Pero no puede callarse: es
# contenido que el visitante puede alcanzar y que nadie mantiene.
caso('INV-01 · una pagina que la spec no declara, AVISA',
     "{$BASE,\"cities\":[{\"slug\":\"madrid\"}]}", 'AVISO:INV-01', 'greenfield',
     { 'madrid/index.html' => '<html><body><main><h1>Madrid</h1></main></body></html>',
       'sobrante/index.html' => '<html><body><main><h1>De otra tanda</h1></main></body></html>' });

# 🔴 INV-02 · texto de relleno EN VIVO. Es el hermano del `MED-08` de site-d
#    (una politica publicada diciendo «pendiente de revision juridica»): el
#    dano cae en el visitante, que lee un sitio a medio hacer.
caso('INV-02 · lorem ipsum servido, FALLA',
     "{$BASE}", 'FALLO:INV-02', 'greenfield',
     { 'index.html' => '<html><body><main><h1>Hola</h1><p>Lorem ipsum dolor sit amet.</p></main></body></html>' });
caso('INV-02 · y un [pendiente] tambien',
     "{$BASE}", 'FALLO:INV-02', 'greenfield',
     { 'index.html' => '<html><body><main><h1>Hola</h1><p>Telefono: [pendiente]</p></main></body></html>' });
# 🔴 EL CONTROL QUE HACE QUE ESTE CHECK SE PUEDA ENCENDER EN WEBS EN ESPANOL:
#    «TODO» se busca SIN /i a proposito, porque «todo» es una palabra
#    castellana normal. Sin esta distincion, el gate acusaria a cualquier web
#    en espanol en su primera frase -- y un gate que acusa a todo el mundo se
#    apaga el primer dia.
caso('INV-02 · pero «todo» en castellano NO es relleno',
     "{$BASE}", '!FALLO:INV-02', 'greenfield',
     { 'index.html' => '<html><body><main><h1>Hola</h1><p>Todo el equipo trabaja a domicilio, todo el ano.</p></main></body></html>' });

# 🔴 INV-03 · el defecto REAL de la web de site-d antes de migrarla: emitia
#    `SearchAction` -que le dice a Google «tengo buscador, ofrecelo en los
#    resultados»- sin tener ni un campo de busqueda. Es schema que afirma algo
#    que el sitio no tiene, y Google lo penaliza cuando lo comprueba.
caso('INV-03 · SearchAction sin buscador, FALLA',
     "{$BASE}", 'FALLO:INV-03', 'greenfield',
     { 'index.html' => '<html><head><script type="application/ld+json">{"@type":"WebSite","potentialAction":{"@type":"SearchAction"}}</script></head><body><main><h1>x</h1></main></body></html>' });
caso('INV-03 · con buscador de verdad, pasa',
     "{$BASE}", 'ok:INV-03', 'greenfield',
     { 'index.html' => '<html><head><script type="application/ld+json">{"@type":"WebSite","potentialAction":{"@type":"SearchAction"}}</script></head><body><main><h1>x</h1><input type="search" name="q"></main></body></html>' });

# 🔴 UN AGUJERO QUE HA SALIDO AL ESCRIBIR ESTOS CASOS, y se fija aqui para que
#    cambiarlo sea una DECISION y no un descuido.
#
#    El bloque `inventado` -INV-01, INV-02, INV-03- **solo corre en greenfield**.
#    El motivo escrito en el gate es razonable: en una migracion, el inventario
#    contra su codigo lo hace `audit-vs-source.sh` y no se repite aqui.
#
#    Pero INV-02 y INV-03 no son inventario: son **defectos de lo publicado**, y
#    ocurren igual migrando. La prueba es de casa: el `SearchAction` sin
#    buscador era un defecto de la web de **site-d, que es una MIGRACION** --
#    esta escrito en su CLAUDE.md como uno de los cuatro que desaparecieron al
#    migrar. O sea: **el check que lo habria cazado esta apagado justo en el
#    modo en el que ocurrio**, y lo tapo que la migracion lo arreglo de rebote.
#
#    No se cambia desde aqui: mover que bloques corren por modo toca los 5 repos
#    y las dos ramas del CAMINO-1. Este caso deja constancia del comportamiento
#    de HOY, para que quien lo cambie lo vea en rojo y sepa que lo esta cambiando.
caso('INV-03 · HOY no se mira en migracion (agujero, no diseno)',
     "{$BASE}", '!FALLO:INV-03', 'migracion',
     { 'index.html' => '<html><head><script type="application/ld+json">{"@type":"WebSite","potentialAction":{"@type":"SearchAction"}}</script></head><body><main><h1>x</h1></main></body></html>' });

print "\n== PASOS 7 y 8 · MEDICION Y FORMULARIOS\n";
# 🔴 FOR-01 · `mailto:` es el defecto que tenian las webs originales de
#    site-d Y de site-a. Abre el cliente de correo del visitante y no envia
#    NADA si no tiene uno configurado -- que en un movil es lo normal.
caso('FOR-01 · un formulario con action mailto:, FALLA',
     "{$BASE}", 'FALLO:FOR-01', 'migracion',
     { 'index.html' => '<html><body><main><h1>x</h1><form action="mailto:hola@ejemplo.test"><input name="n"></form></main></body></html>' });
caso('FOR-01 · con un receptor de verdad, pasa',
     "{$BASE}", 'ok:FOR-01', 'migracion',
     { 'index.html' => '<html><body><main><h1>x</h1><form action="/contacto.php"><input name="n"></form></main></body></html>' });

# 🔴 FOR-02 · «guarda en disco ANTES de enviar» no es una florituras: en site-a se
#    borro el buzon de envio y el formulario siguio devolviendo 302 **sin enviar
#    correo y sin ninguna senal visible**. Los leads de esos dias existen porque
#    estaban en disco.
caso('FOR-02 · un receptor que no guarda copia, se marca',
     "{$BASE}", '!ok:FOR-02', 'migracion',
     { 'index.html' => '<html><body><main><h1>x</h1><form action="/contacto.php"></form></main></body></html>',
       '_deploy/contact.php' => '<?php mail("a@b.test","asunto","cuerpo"); header("Location: /gracias/"); ?>' });
caso('FOR-02 · uno que guarda antes de enviar, pasa',
     "{$BASE}", 'ok:FOR-02', 'migracion',
     { 'index.html' => '<html><body><main><h1>x</h1><form action="/contacto.php"></form></main></body></html>',
       '_deploy/contact.php' => '<?php file_put_contents("_leads/l.jsonl", $j); mail("a@b.test","s","c"); ?>' });

# MED-03 · el contenedor que la spec declara tiene que estar EN LAS PAGINAS. Una
# web con GTM en la spec y sin GTM en el HTML no mide nada, y el sintoma -cero
# conversiones- se confunde con «no convierte».
caso('MED-03 · GTM declarado y ausente del HTML, FALLA',
     "{$BASE,\"tracking\":{\"gtm\":\"GTM-ABC1234\"}}", 'FALLO:MED-03', 'migracion',
     { 'index.html' => '<html><body><main><h1>x</h1></main></body></html>' });
caso('MED-03 · y presente, pasa',
     "{$BASE,\"tracking\":{\"gtm\":\"GTM-ABC1234\"}}", 'ok:MED-03', 'migracion',
     { 'index.html' => '<html><head><script>(function(){})(GTM-ABC1234)</script></head><body><main><h1>x</h1></main></body></html>' });

print "\n== PASOS 3, 4 y 6 · ANATOMIA, ENLAZADO Y FICHEROS PARA MAQUINAS\n";
# 🔴 ANA-02 · la anatomia por ROL. Es el check que estuvo en NO VERIFICADO sobre
#    las 121 paginas del parque hasta que site-c empezo a declarar `data-sec`.
#    Un `hub` sin catalogo es un indice que no indexa nada.
caso('ANA-02 · un hub sin `catalogo` FALLA',
     "{$BASE,\"pages\":[{\"slug\":\"servicios\",\"tipo\":\"hub\"}]}", 'FALLO:ANA-02', 'greenfield',
     { 'servicios/index.html' => '<html><body><main data-tipo="hub">'
       . '<section data-sec="hero"><h1>Servicios</h1></section>'
       . '<section data-sec="cierre"><h2>Fin</h2></section></main></body></html>' });
# 🔴 18-ago-2026 · SON CUATRO, NO TRES. 09 §2.5 pide tambien `calificacion`
#    («como elegir entre ellos»), que es lo que distingue un hub de un menu. La
#    tabla de este gate llevaba tres desde que se escribio y este caso fijaba el
#    error. Ahora la tabla es una sola y vive en anatomy.tsv.
caso('ANA-02 · con los cuatro roles de `hub`, pasa',
     "{$BASE,\"pages\":[{\"slug\":\"servicios\",\"tipo\":\"hub\"}]}", 'ok:ANA-02', 'greenfield',
     { 'servicios/index.html' => '<html><body><main data-tipo="hub">'
       . '<section data-sec="hero"><h1>Servicios</h1></section>'
       . '<section data-sec="catalogo"><h2>Lo que hacemos</h2></section>'
       . '<section data-sec="calificacion"><h2>Cual te conviene</h2></section>'
       . '<section data-sec="cierre"><h2>Fin</h2></section></main></body></html>' });

# ENL-02 · un hub con menos de 4 hijos no es un hub: es una pagina con enlaces.
# Importa porque la arquitectura se decide ANTES de escribir (paso 3), y un hub
# flaco descubierto al final obliga a rehacer las URLs -- que es lo unico que no
# se puede rehacer barato cuando la web ya esta indexada.
caso('ENL-02 · un hub con 2 hijos se marca',
     "{$BASE,\"cities\":[{\"slug\":\"servicios\",\"tipo\":\"hub\"}," .
     '{"slug":"servicios/uno","padre":"servicios"},{"slug":"servicios/dos","padre":"servicios"}]}',
     'ENL-02', 'greenfield');

# PAG-02 · los tres ficheros para maquinas. Se rompen SIN AVISAR porque no son
# HTML: un `grep` de `href` no los cubre, y por eso sobrevivieron enteros a una
# reestructuracion en climentmedia publicando 11 URLs a 404.
caso('PAG-02 · sin robots.txt, FALLA',
     "{$BASE}", 'FALLO:PAG-02', 'migracion');
caso('PAG-02 · con los tres, pasa',
     "{$BASE}", 'ok:PAG-02', 'migracion',
     { 'robots.txt' => "User-agent: *\nAllow: /\n",
       'sitemap.xml' => '<?xml version="1.0"?><urlset><url><loc>https://ejemplo.test/</loc></url></urlset>',
       'llms.txt' => "# Ejemplo\n" });

# PAG-03 · el sitemap que promete paginas que no existen. Es la forma en que un
# sitio se queda enviando a Google a 404 sin que nadie lo note: el fichero es
# valido, las URLs parecen bien, y solo se ve resolviendolas contra el disco.
caso('PAG-03 · el sitemap lista una pagina que no existe',
     "{$BASE}", 'FALLO:PAG-03', 'migracion',
     { 'robots.txt' => "User-agent: *\n", 'llms.txt' => "# x\n",
       'sitemap.xml' => '<?xml version="1.0"?><urlset><url><loc>https://ejemplo.test/no-existe/</loc></url></urlset>' });
caso('PAG-03 · y si existe, pasa',
     "{$BASE}", 'ok:PAG-03', 'migracion',
     { 'robots.txt' => "User-agent: *\n", 'llms.txt' => "# x\n",
       'sitemap.xml' => '<?xml version="1.0"?><urlset><url><loc>https://ejemplo.test/si-existe/</loc></url></urlset>',
       'si-existe/index.html' => '<html><body><main><h1>Existe</h1></main></body></html>' });

# 🔴 MED-02 · la pagina de gracias con `noindex` Y con marca de conversion. Las
#    dos cosas, y por razones distintas: sin `noindex` Google la indexa y
#    aparece en resultados como si fuera contenido; sin marca, la conversion no
#    se cuenta y el canal parece que no funciona.
caso('MED-02 · gracias sin noindex ni marca, FALLA',
     "{$BASE,\"cities\":[{\"slug\":\"gracias\"}]}", 'FALLO:MED-02', 'migracion',
     { 'gracias/index.html' => '<html><body><main><h1>Gracias</h1></main></body></html>' });
caso('MED-02 · con noindex y marca de conversion, pasa',
     "{$BASE,\"cities\":[{\"slug\":\"gracias\"}]}", 'ok:MED-02', 'migracion',
     { 'gracias/index.html' => '<html><head><meta name="robots" content="noindex"></head>'
       . '<body data-thanks="pageview"><main><h1>Gracias</h1></main></body></html>' });

print "\n== BLOQUE 8 · IMAGENES: existen, y tienen alt\n";
# 🔴 IMG-01 · una imagen declarada y ausente no rompe nada visible en el HTML:
#    sale un hueco. Y si la ausente es la `og:image`, lo que sale es un
#    RECTANGULO GRIS en WhatsApp -- que en un negocio local es el canal real de
#    recomendacion. En site-c, 23 de 30 paginas se compartian sin imagen porque su
#    Yoast apuntaba a /wp-content/, que en nuestro arbol no existe.
caso('IMG-01 · una imagen declarada y ausente, FALLA',
     "{$BASE,\"pages\":[{\"slug\":\"servicio\",\"image\":\"assets/no-esta.jpg\",\"imageAlt\":\"x\"}]}",
     'FALLO:IMG-01', 'migracion',
     { 'servicio/index.html' => '<html><body><main><h1>x</h1></main></body></html>' });
caso('IMG-01 · y si esta en disco, pasa',
     "{$BASE,\"pages\":[{\"slug\":\"servicio\",\"image\":\"assets/si-esta.jpg\",\"imageAlt\":\"x\"}]}",
     'ok:IMG-01', 'migracion',
     { 'servicio/index.html' => '<html><body><main><h1>x</h1></main></body></html>',
       'assets/si-esta.jpg' => 'JPEGdementira' });
# Una imagen externa no se puede comprobar en disco, y acusarla seria inventarse
# un hueco: se deja pasar a proposito.
caso('IMG-01 · una imagen externa no se acusa',
     "{$BASE,\"pages\":[{\"slug\":\"servicio\",\"image\":\"https://cdn.ejemplo.test/x.jpg\",\"imageAlt\":\"x\"}]}",
     'ok:IMG-01', 'migracion',
     { 'servicio/index.html' => '<html><body><main><h1>x</h1></main></body></html>' });

# 🔴 IMG-02 · el `alt` es CAMPO DE LA SPEC y no algo que se escriba a mano al
#    maquetar. La razon esta medida: `og:image:alt` es obligatorio desde el
#    5-ago y estaba al **0 %** en 4 de las 5 webs, incluida aquella donde vive
#    el estandar. Lo que no es un campo, se olvida.
caso('IMG-02 · una imagen sin imageAlt, FALLA',
     "{$BASE,\"pages\":[{\"slug\":\"servicio\",\"image\":\"assets/x.jpg\"}]}",
     'FALLO:IMG-02', 'migracion',
     { 'servicio/index.html' => '<html><body><main><h1>x</h1></main></body></html>',
       'assets/x.jpg' => 'JPEGdementira' });
caso('IMG-02 · con alt, pasa',
     "{$BASE,\"pages\":[{\"slug\":\"servicio\",\"image\":\"assets/x.jpg\",\"imageAlt\":\"Sala de tratamiento\"}]}",
     'ok:IMG-02', 'migracion',
     { 'servicio/index.html' => '<html><body><main><h1>x</h1></main></body></html>',
       'assets/x.jpg' => 'JPEGdementira' });

printf "\n-----------------------------------------------------------------\n";
printf "  OK %-3d  ·  MAL %d\n", $ok, $ko;
print $ko ? "  🔴 HAY FALLOS.\n"
          : "  El gate no se muere, y dice lo que no puede leer en vez de suponerlo.\n";
exit($ko ? 1 : 0);
