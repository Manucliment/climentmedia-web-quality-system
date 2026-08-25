#!/usr/bin/env perl
# =============================================================================
#  receipt.pl  ·  EL RECIBO DE QA — la pieza que hace que el paso no se salte
# =============================================================================
#  Perl 5 puro (viene con Git Bash). Dependencias: curl (solo para --servido).
#  NO usa jq, node ni python: en esta maquina no hay jq ni python, y node NO
#  esta en el PATH de Git Bash (comprobado 10-ago-2026).
#
#  POR QUE EXISTE
#  --------------
#  «En rojo no se despliega» esta escrito en UN sitio: site-d-web/CLAUDE.md.
#  Y aunque estuviera en los cinco, es una frase: nada la obliga. El 10-ago el
#  arreglo de contraste de site-d llevaba horas en el repo y produccion seguia
#  sirviendo el CSS viejo, con todos los gates en verde. Los dos agujeros son el
#  mismo agujero: **«he corrido el QA» y «esta desplegado» son AFIRMACIONES, y
#  nadie las comprueba.**
#
#  Un recibo convierte las dos en HECHOS COMPROBABLES:
#    · lo firma la maquina que midio, no quien dice haber medido;
#    · va atado por md5 al ARBOL EXACTO que se midio, asi que no vale para otro;
#    · caduca, asi que no vale para siempre;
#    · dice a que version del estandar se midio, asi que la deriva se ve.
#
#  LAS CINCO PREGUNTAS QUE CONTESTA, Y NINGUNA MAS
#  -----------------------------------------------
#    1 · ¿se corrio el QA sobre ESTO?      ARBOL-HASH == hash del arbol de ahora
#    2 · ¿salio verde?                     VEREDICTO / LENTE-*
#    3 · ¿SOBRE CUANTO se midio?           ALCANCE-* (seccion 3-bis y 3-ter)
#    4 · ¿CONTRA QUE se midio?             MEDIDO-CONTRA (seccion 3-quater)
#    5 · ¿lo que se sirve es ESTO?         --servido (el gate G11)
#  La 3 se añadio el 11-ago-2026 y es la que faltaba: 1 y 2 juntas dejaban pasar
#  «PASA sobre el arbol de 192 ficheros» habiendo mirado una pagina.
#  La 4 se añadio el mismo dia, por el mismo motivo y con mas sangre: 1 y 2
#  juntas dejaban pasar un recibo que SELLA EL ARBOL DEL REPO con un veredicto
#  sacado de medir PRODUCCION. Dos artefactos distintos con una sola cara.
#
#  🔴 EL FLUJO, Y SON DOS MOMENTOS
#  -------------------------------
#    1 · MEDIR EL CANDIDATO   perl qa-master.pl <URL> --repo DIR --candidato
#        → recibo con MEDIDO-CONTRA: CANDIDATO. Dice si lo que se VA a subir
#          esta bien. Es el unico que puede decirlo.
#    2 · SUBIR                bash deploy.sh DIR --subir
#    3 · G11                  bash deploy.sh DIR --servido
#        → dice si lo servido es lo medido. Es el unico que puede decirlo.
#  Ni el 1 sustituye al 3 ni el 3 al 1. Medir produccion ANTES de subir es lo
#  que producia el bucle de site-d: el gate se negaba a subir el arreglo
#  porque produccion estaba mal, y produccion estaba mal porque no se habia
#  subido el arreglo.
#  No contesta «¿esta bien hecha la web?». Eso lo contesta qa-master.pl, y este
#  fichero solo transporta su respuesta sin que se pueda perder por el camino.
#
#  LO QUE **NO** ES
#  ----------------
#  No es seguridad. El SELLO detecta un recibo truncado o retocado a mano de
#  pasada; no detiene a quien quiera mentir a proposito, y no lo pretende. El
#  modo de fallo real no es la mala fe: es yo, dentro de tres semanas, con
#  prisa, dando por corrido un QA que no corri.
#
#  USO
#  ---
#    perl receipt.pl --escribir  --repo DIR --sitio URL --json QA.json [--salida F]
#    perl receipt.pl --verificar --repo DIR [--horas N] [--para-desplegar]
#    perl receipt.pl --servido   --repo DIR [--max N] [--cache DIR]
#    perl receipt.pl --arbol     --repo DIR [--listar]
#    perl receipt.pl --historial [--sitio URL]
#
#    --escribir        escribe <repo>/.qa-recibo a partir del JSON de qa-maestro
#    --verificar       valida el recibo contra el arbol de AHORA. exit 0/1
#    --para-desplegar  ademas exige VEREDICTO PASA, frescura, las cinco lentes
#                      corridas y un ALCANCE que no sea irrisorio (el gate)
#    --servido         G11: descarga cada fichero del manifiesto y compara md5
#    --arbol           imprime el hash del arbol desplegable (y con --listar, el
#                      manifiesto). Sirve para ver QUE se considera desplegable
#    --horas N         ventana de frescura (por defecto 12)
#    --anotar TEXTO    apunta una linea en el historial (lo usa deploy.sh)
#
#  EXIT
#  ----
#    0  OK          1  NO (con el motivo por STDOUT)      2  no se pudo correr
#  🔴 2 NO ES 0. Un recibo que no se pudo leer no es un recibo verde.
# =============================================================================

use strict;
use warnings;
use utf8;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path);
use File::Basename qw(dirname basename);

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

our $VERSION_RECIBO = 1;

# Directorio del propio script: de aqui sale el hash del ESTANDAR.
our $MIDIR = dirname(__FILE__);
$MIDIR = '.' if !defined $MIDIR || $MIDIR eq '';

# Carpeta central: NO guarda copias del recibo (dos copias derivan siempre).
# Guarda UNA cosa que el recibo no puede guardar: la historia entre webs.
#  QA_RECIBOS_DIR lo usan las pruebas para no ensuciar el historial de verdad:
#  un historial con 20 lineas de «https://ejemplo.test» deja de servir para lo
#  unico que sirve, que es mirar de un vistazo como van las cinco webs.
our $CENTRAL = $ENV{QA_RECIBOS_DIR}
            || (($ENV{HOME} || $ENV{USERPROFILE} || '.') . '/.qa-receipts');

# =============================================================================
#  1 · QUE ES «EL ARBOL DESPLEGABLE»
# =============================================================================
#  🔴 Esta lista es la definicion, y vive en UN solo sitio a proposito. Si el
#     hash cubre ficheros que no se suben, el gate da falsos rojos y se aprende
#     a saltarlo; si deja fuera ficheros que SI se suben, el gate no ve el fallo
#     que existe para ver —y el caso real de site-d estaba en styles.css.
#
#  Hasta hoy esta definicion solo existia en PROSA, y solo en un sitio:
#  site-b-web/CLAUDE.md («El deploy necesita lista blanca: nada de *.md,
#  *.bak*, .claude/, _seo/, api/lead.js, vercel.json»). Las otras cuatro webs no
#  la tienen escrita en ninguna parte.
#
#  Regla: se excluye por DEFECTO todo lo que es andamiaje, y cada repo puede
#  AÑADIR exclusiones en <repo>/.qa-arbol. Nunca quitar: si un repo pudiera
#  relajar la regla, el primer rojo incomodo se arreglaria relajandola.
# =============================================================================

our @EXCLUIR_DIR = qw(
    .git .github .claude .vscode node_modules scratch
);
# Todo directorio de primer nivel que empiece por «_» es andamiaje nuestro:
# _deploy _spec _seo _migrate _design _kit _cowork _post-images _secrets...
our $EXCLUIR_DIR_GUION_BAJO = 1;

our @EXCLUIR_FICHERO = (
    qr/\.md$/i,          # CLAUDE.md, README.md, MIGRACION.md, QA.md...
    qr/\.bak/i,          # styles.css.bak, _gen.ps1.bak-urls
    qr/\.ps1$/i,         # generadores
    qr/\.sh$/i,          # scripts
    qr/\.py$/i,
    qr/\.pl$/i,
    qr/\.conf$/i,        # _audit.conf
    qr/\.log$/i,
    qr/^\.qa-recibo$/,   # el propio recibo NO se despliega ni se auto-hashea
    qr/^\.qa-arbol$/,
    qr/^\.gitignore$/,
    qr/^\.DS_Store$/i,
    qr/^Thumbs\.db$/i,
);

sub norm_ruta {
    my ($p) = @_;
    $p =~ s{\\}{/}g;
    $p =~ s{/+$}{};
    return $p;
}

sub lee_qa_arbol {
    my ($repo) = @_;
    my @extra;
    my $f = "$repo/.qa-arbol";
    return @extra unless -f $f;
    open my $fh, '<:raw', $f or return @extra;
    while (my $l = <$fh>) {
        $l =~ s/\r?\n$//;
        next if $l =~ /^\s*#/ || $l !~ /\S/;
        if ($l =~ /^\s*EXCLUIR:\s*(.+?)\s*$/) {
            my $g = $1;
            # glob muy pequeño: * dentro de un segmento, ** cruza segmentos
            my $re = quotemeta($g);
            $re =~ s/\\\*\\\*/\x01/g;
            $re =~ s/\\\*/[^\/]*/g;
            $re =~ s/\x01/.*/g;
            push @extra, qr/^$re$/;
        }
    }
    close $fh;
    return @extra;
}

# Devuelve ([ [ruta_relativa, md5, bytes], ... ], hash_del_arbol)
# 🔴 EL RECIBO SELLA LO QUE SE SUBE, NO LO QUE HAY (11-ago-2026)
#    G11 pedia a produccion 195 ficheros y solo encontraba 152: los otros 43
#    —`_*_spec.json`, `ds-bundle/`— estan en `EXCLUIR` del deploy.conf y NO se
#    suben nunca. Salian como «NO HALLADO, y eso NO es un aprobado» en CADA
#    despliegue. Un aviso que sale siempre y siempre se ignora deja de ser un
#    aviso, y de paso tapa el dia que falte un fichero de verdad.
#    Se lee el EXCLUIR del propio `deploy.conf` en vez de copiarlo a `.qa-arbol`:
#    dos listas de lo mismo divergen, y entonces el recibo vuelve a sellar algo
#    distinto de lo que se sube.
#    ⚠️ SOLO SUMA. Nunca quita una exclusion de las de arriba: si un repo pudiera
#       relajar la regla, el primer rojo incomodo se arreglaria relajandola.
#    ⚠️ Y se DECLARA en el recibo (`ARBOL-EXCLUIDO-POR-DEPLOY`), porque esto
#       decide que NO se mide: un patron demasiado ancho aqui deja paginas fuera
#       del sello sin que nadie lo vea. Escrito, se ve.
our @EXCLUIDO_POR_DEPLOY;      # los patrones que se aplicaron, para el recibo
sub lee_excluir_deploy {
    my ($repo) = @_;
    @EXCLUIDO_POR_DEPLOY = ();
    my $f = "$repo/_deploy/deploy.conf";
    return () unless -f $f;
    open my $fh, '<:raw', $f or return ();
    local $/; my $txt = <$fh> // ''; close $fh;
    my ($linea) = $txt =~ /^\s*EXCLUIR\s*=\s*"?(.*?)"?\s*$/m;
    return () unless defined $linea;
    my @re;
    for my $g ($linea =~ /--exclude=([^\s"]+)/g) {
        push @EXCLUIDO_POR_DEPLOY, $g;
        # Mismo glob pequeno que `.qa-arbol`, y ademas casa por SEGMENTO: en tar,
        # `--exclude=ds-bundle` excluye ese directorio este donde este.
        my $re = quotemeta($g);
        $re =~ s/\\\*\\\*/\x01/g;
        $re =~ s/\\\*/[^\/]*/g;
        $re =~ s/\x01/.*/g;
        push @re, qr{^$re$}, qr{^$re/}, qr{(?:^|/)$re$};
    }
    return @re;
}

sub arbol {
    my ($repo, %o) = @_;
    $repo = norm_ruta($repo);
    my @extra = (lee_qa_arbol($repo), lee_excluir_deploy($repo));
    my @out;

    my $recorre;
    $recorre = sub {
        my ($dir, $rel) = @_;
        opendir(my $dh, $dir) or return;
        my @e = sort grep { $_ ne '.' && $_ ne '..' } readdir($dh);
        closedir $dh;
        for my $e (@e) {
            my $full = "$dir/$e";
            my $r    = $rel eq '' ? $e : "$rel/$e";
            if (-d $full) {
                next if grep { $_ eq $e } @EXCLUIR_DIR;
                # el guion bajo solo marca andamiaje en el PRIMER nivel:
                # dentro de assets/ puede haber cualquier cosa
                next if $EXCLUIR_DIR_GUION_BAJO && $rel eq '' && $e =~ /^_/;
                next if $e =~ /^\./ && $rel eq '';
                $recorre->($full, $r);
                next;
            }
            next unless -f $full;
            my $base = $e;
            next if grep { $base =~ $_ } @EXCLUIR_FICHERO;
            next if grep { $r    =~ $_ } @extra;
            open my $fh, '<:raw', $full or next;
            local $/;
            my $b = <$fh>;
            close $fh;
            $b = '' unless defined $b;
            push @out, [ $r, md5_hex($b), length($b) ];
        }
    };
    $recorre->($repo, '');

    @out = sort { $a->[0] cmp $b->[0] } @out;
    # El hash del arbol es el md5 de las lineas «md5<TAB>ruta». Depende del
    # contenido Y del nombre: mover un fichero cambia el hash, como debe ser.
    my $acc = join('', map { "$_->[1]\t$_->[0]\n" } @out);
    return (\@out, md5_hex($acc));
}

# =============================================================================
#  1-bis · LOS RECEPTORES — lo que vive en produccion y NO esta en el arbol
# =============================================================================
#  QUE SON: `_deploy/contact.php`, `smtp.php`, `check-smtp.php` y el `.htaccess`.
#  No estan en el arbol desplegable —`_deploy/` se excluye, y bien— pero SI
#  estan en produccion, y son LA CAPTACION de cuatro webs. Hasta el 11-ago-2026
#  el gate no los veia de ninguna manera: ni el ARBOL-HASH los cubria, ni G11
#  los pedia, ni subir.sh los subia.
#
#  🔴 LA DECISION: HASH PROPIO, DECLARADO, **NO** DENTRO DE ARBOL-HASH.
#  ---------------------------------------------------------------------------
#  Meterlos en el manifiesto era la opcion "coherente" a primera vista —tocar
#  uno invalidaria el recibo, que es justo lo que se quiere— y esta MAL por tres
#  motivos, en orden de gravedad:
#
#    1 · EL MANIFIESTO ES LA LISTA DE LA COMPRA DE G11. `--servido` recorre cada
#        entrada, la PIDE POR HTTP y compara md5. Un receptor PHP no se puede
#        pedir: el servidor lo EJECUTA y devuelve su salida, no su codigo. Si lo
#        devolviera seria una fuga de fuente, no una comprobacion. Meterlo en el
#        manifiesto garantiza un G11 en rojo para siempre, y un gate que no se
#        puede satisfacer es un gate que alguien apaga (lo dice la propia skill
#        sobre `aceptado.conf`).
#
#    2 · EL MANIFIESTO NO SABE DE RENOMBRADOS. En site-d el repo tiene
#        `contact.php` y produccion sirve `contacto.php`. El manifiesto indexa
#        por ruta del repo y no tiene donde poner el destino; anadirle una
#        columna cambia el significado del hash del arbol para las cinco webs.
#
#    3 · `_deploy/` SE EXCLUYE POR ALGO MAS. Dentro tambien viven `deploy.conf`,
#        `aceptado.conf`, los `.bak-*` y `_test-lead.php`. Levantar la exclusion
#        del directorio para pescar tres ficheros se traga el `aceptado.conf`
#        —y entonces editar una aceptacion invalidaria el recibo que la lee—.
#        Circular.
#
#  LO QUE SE CONSERVA, que es lo que de verdad pedia la coherencia: los
#  receptores VAN en el recibo (`RECEPTOR-NNN` + `RECEPTORES-HASH`), van BAJO EL
#  SELLO, y `--verificar` los compara igual que compara el arbol. Tocar un
#  contact.php SIGUE invalidando el recibo. Solo cambia por donde: por un
#  segundo hash declarado en vez de contaminando el manifiesto que alimenta G11.
#
#  Y NO ES UN PATRON NUEVO EN ESTE FICHERO: `ACEPTADOS-CONF-MD5` ya hace
#  exactamente esto con `_deploy/aceptado.conf`, y por el mismo motivo escrito
#  en su comentario —«ARBOL-HASH no los cubre y sin esta linea no habria forma
#  de saber que version del fichero produjo este veredicto»—.
#
#  LA LISTA VIVE EN `_deploy/deploy.conf` (`PHP_EN_PRODUCCION`), que es donde ya
#  vive `EXCLUIR`. Se lee con un regex y no sourceando: este fichero es perl, y
#  ejecutar un .conf de shell para leer una variable es abrir una via de
#  ejecucion en el gate a cambio de nada.
# =============================================================================
sub receptores {
    my ($repo) = @_;
    $repo = norm_ruta($repo);
    my $conf = "$repo/_deploy/deploy.conf";
    return () unless -f $conf;
    open my $fh, '<:raw', $conf or return ();
    local $/;
    my $t = <$fh>;
    close $fh;
    $t = '' unless defined $t;
    $t =~ s/\r\n/\n/g;
    my ($lista) = $t =~ /^PHP_EN_PRODUCCION="([^"]*)"/m;
    return () unless defined $lista && $lista =~ /\S/;
    my @out;
    for my $par (split /\s+/, $lista) {
        next unless $par =~ /\S/;
        my ($l, $n) = split /:/, $par, 2;
        next unless defined $l && defined $n && $l ne '' && $n ne '';
        # AUSENTE es un valor, no un fallo silencioso: un receptor declarado que
        # no esta en el repo tiene que mover el hash igual que uno que cambia.
        my ($md5, $bytes) = ('AUSENTE', 0);
        if (open my $g, '<:raw', "$repo/$l") {
            local $/;
            my $b = <$g>;
            close $g;
            $b = '' unless defined $b;
            $md5 = md5_hex($b);
            $bytes = length($b);
        }
        push @out, { repo => $l, prod => $n, md5 => $md5, bytes => $bytes };
    }
    # Orden estable por destino: el hash no puede depender del orden en que
    # alguien escribio los pares en el conf.
    @out = sort { $a->{prod} cmp $b->{prod} } @out;
    return @out;
}

sub receptores_hash {
    my (@r) = @_;
    return '' unless @r;
    return substr(md5_hex(join('', map { "$_->{md5}\t$_->{repo}\t$_->{prod}\n" } @r)), 0, 12);
}

# Los receptores TAL COMO LOS SELLO EL RECIBO. G11 tiene que preguntar por lo
# que se midio, no por lo que hay en el disco ahora: si alguien renombra un
# destino despues del QA, eso es justo lo que hay que ver, no lo que hay que
# seguir.
sub receptores_del_recibo {
    my ($R) = @_;
    my @out;
    for my $k (sort grep { /^RECEPTOR-\d+$/ } keys %$R) {
        next unless $R->{$k} =~ /^(\S+)\s+(\d+)\s+(.+?)\s+->\s+(.+?)\s*$/;
        push @out, { md5 => $1, bytes => $2, repo => $3, prod => $4 };
    }
    return @out;
}

# =============================================================================
#  2 · LA VERSION DEL ESTANDAR
# =============================================================================
#  Un recibo sin esto miente por omision: dice «paso el QA» sin decir CUAL. Si
#  manana 09-tipos-de-pagina exige algo nuevo, un recibo de ayer sigue siendo
#  verdad sobre AYER —y eso es exactamente lo que hay que poder ver.
#
#  Decision: cambiar el estandar NO invalida los recibos. Solo los marca. Si
#  cada edicion de un .md invalidara todo, se aprenderia a no editar los .md, o
#  a saltarse el gate; y de las dos cosas la segunda mata el sistema entero.
# =============================================================================
sub hash_estandar {
    my @f;
    for my $g ("$MIDIR/../SKILL.md", "$MIDIR/../CAMINO-*.md",
               "$MIDIR/*.md", "$MIDIR/qa-master.pl", "$MIDIR/receipt.pl",
               "$MIDIR/structure-gate.js", "$MIDIR/linking-gate.pl",
               "$MIDIR/measure-screens.js") {
        push @f, glob($g);
    }
    @f = sort grep { -f $_ } @f;
    return ('sin-estandar', 0) unless @f;
    my $acc = '';
    for my $f (@f) {
        open my $fh, '<:raw', $f or next;
        local $/;
        my $b = <$fh>;
        close $fh;
        $acc .= md5_hex(defined $b ? $b : '') . "\t" . basename($f) . "\n";
    }
    return (substr(md5_hex($acc), 0, 12), scalar @f);
}

# =============================================================================
#  3 · ESCRIBIR EL RECIBO
# =============================================================================
#  Formato: texto plano, LF, una CLAVE: valor por linea, cabecera corta y
#  manifiesto detras de un marcador. A proposito NO es JSON: el recibo tiene que
#  poder leerse con grep desde un hook sin dependencias, y tiene que poder
#  leerse con los ojos cuando algo no cuadre.
# =============================================================================
#  ⚠️ TODO valor de cabecera se escribe en ASCII puro. No es remilgo: el SELLO
#     es un md5 sobre bytes, y en esta maquina un literal con «·» ya salio
#     doble-codificado en el primer recibo real. Un recibo cuyo md5 depende de
#     como se decodifico una tilde es un recibo que un dia se rechaza solo.
#     El MANIFIESTO no se filtra: ahi las rutas tienen que ir tal cual salen del
#     disco o el mapeo ruta->URL de --servido deja de casar.
sub solo_ascii {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/[^\x20-\x7E]/-/g;
    return $s;
}

# =============================================================================
#  3-bis · EL ALCANCE — lo que el recibo callaba
# =============================================================================
#  🔴 Un recibo de climentmedia sella un ARBOL DE 192 FICHEROS habiendo medido
#     UNA pagina. No dice ni una cosa ni la otra: dice «VEREDICTO: PASA» y pone
#     debajo 192 lineas de manifiesto. Quien lo lea —yo, dentro de tres semanas,
#     con prisa— concluye que el arbol paso el QA. No es que el recibo se
#     equivoque: es que MIENTE POR OMISION, que es como mienten los informes.
#
#  El manifiesto contesta «¿sobre que arbol se firmo?». Faltaba la otra mitad:
#  «¿sobre que se MIDIO?». Son numeros distintos y la distancia entre los dos es
#  justo la parte del arbol que nadie ha mirado.
#
#  Cuando el que llama no lo declara, el recibo lo dice —ALCANCE: NO DECLARADO—
#  en vez de callarse. Callarse es lo que se lee como cobertura total.
#
#  ─────────────────────────────────────────────────────────────────────────────
#  🔴 QUE SE ESTAMPA (11-ago-2026) · «N URLs» NO ERA UNA RESPUESTA
#  ─────────────────────────────────────────────────────────────────────────────
#  Hasta hoy el recibo decia «ALCANCE-SEO: 25 URLs» y ahi paraba. Faltaban las
#  dos mitades que convierten eso en informacion:
#      · DE CUANTAS. «25» no se puede leer sin denominador: son el 71% de
#        climentmedia y el 37% de site-b, y el numero es el mismo.
#      · CUALES POR LENTE. La lista era la UNION de todas las lentes, asi que
#        «RENDIMIENTO 3 URLs» no decia CUALES 3. Un recibo de site-d llego a
#        listar 25 URLs con SEO en «NO CORRIDA»: quien lo lea cuenta 25.
#  Ahora cada lente lleva su cuenta, su denominador y los INDICES de sus URLs
#  dentro de la lista unica (`URLS 1-25`, `URLS 1,9,17`). Indices y no URLs
#  repetidas: el recibo de site-b pasaria de 25 lineas a 100 sin decir nada
#  nuevo, y un recibo que no se puede leer entero tampoco se lee.
#
#  🔴 DOS DENOMINADORES, Y LOS DOS HACEN FALTA
#      ALCANCE-SITIO             cuantas URLs tiene el SITIO (sitemap). Lo dice
#                                quien midio; si no lo dice, «NO SE SABE».
#      ALCANCE-PAGINAS-SELLADAS  cuantas paginas HTML sella ESTE recibo. Lo
#                                cuenta este fichero, del manifiesto, y por eso
#                                es el que manda en el gate: un denominador que
#                                aporta el mismo que aporta el numerador no
#                                comprueba nada.
#  No miden lo mismo y ninguno sobra: climentmedia sella 56 paginas HTML y su
#  sitemap declara 35 (hay 21 ficheros .html en el arbol que el sitio no
#  anuncia, 12 de ellos demos de `ds-bundle/` que el deploy.conf ni siquiera
#  sube). Esa distancia es informacion, no ruido.
# =============================================================================

# Paginas HTML del manifiesto: es lo que el recibo firma y lo que se puede
# medir. Los .css, .png y .js no se «miran» por pagina, asi que meterlos en el
# denominador solo sirve para inflar el desfase y volverlo ruido.
sub paginas_selladas {
    my ($man) = @_;
    return grep { /\.html?$/i } map { $_->[0] } @$man;
}

#  Normaliza una URL a la PAGINA que pide, para poder casarla con un fichero:
#    · el #fragmento no llega al servidor;
#    · el ?query lo sirve el MISMO fichero (loja.html?cat=redondos = loja.html);
#    · /servicios y /servicios/ son la misma pagina (climentmedia sirve con
#      barra, site-a y site-d sin ella);
#    · el host no distingue mayusculas, la ruta si.
sub clave_url {
    my ($u) = @_;
    return '' unless defined $u;
    $u =~ s/^\s+|\s+$//g;
    $u =~ s/#.*$//;
    $u =~ s/\?.*$//;
    $u =~ s{/+$}{};
    $u =~ s{^(https?://[^/]+)}{lc($1)}e;
    return $u;
}

#  Casa las URLs medidas con las paginas selladas, en las dos direcciones:
#    sin_medir  paginas que el recibo FIRMA y nadie ha mirado  <- el agujero
#    huerfanas  URLs medidas que no son ningun fichero del arbol <- el mapeo
#  Reutiliza urls_candidatas(), que es la misma funcion con la que G11 pide los
#  ficheros: si el mapeo ruta->URL de una web esta mal, esta mal en los dos
#  sitios y se ve en los dos, en vez de tener dos ideas distintas de lo mismo.
sub mapa_alcance {
    my ($sitio, $man, $urls) = @_;
    my @sell = paginas_selladas($man);
    my %medida = map { (clave_url($_) => 1) } grep { defined $_ && /\S/ } @$urls;
    delete $medida{''};
    my (%cubierta, @sin, %reclamada);
    if (defined $sitio && $sitio ne '') {
        for my $rel (@sell) {
            my $hit = 0;
            for my $c (urls_candidatas($sitio, $rel)) {
                my $k = clave_url($c);
                $reclamada{$k} = 1;
                $hit = 1 if $medida{$k};
            }
            $hit ? $cubierta{$rel}++ : push @sin, $rel;
        }
    }
    return {
        selladas  => scalar(@sell),
        medidas   => scalar(keys %cubierta),
        urls      => scalar(keys %medida),
        sin_medir => \@sin,
        huerfanas => [ sort grep { !$reclamada{$_} } keys %medida ],
    };
}

# =============================================================================
#  3-ter · EL ALCANCE CUENTA PARA LA VALIDEZ
# =============================================================================
#  🔴 EL CRITERIO, Y POR QUE ESTE
#
#  Un recibo verde afirma «este arbol se puede subir». Medida una pagina de
#  cuarenta, esa afirmacion no la sostiene nada. Pero un gate que exija
#  cobertura total no lo pasa NADIE —ni una sola de las cinco webs, ni hoy ni
#  nunca— y un gate que nadie pasa se apaga en una semana. Asi que el gate no
#  pide cobertura: **rechaza lo irrisorio**, que es un listón mucho mas bajo y
#  el unico que se puede defender.
#
#  REGLA (dos formas de cumplirla; basta UNA):
#      a) medir al menos 1 de cada 3 paginas HTML que el recibo sella, o
#      b) medir al menos 25 paginas — el tope por defecto de qa-maestro
#         (`--max-urls 25`), es decir, LO QUE DA UNA CORRIDA COMPLETA NORMAL.
#
#  El (b) existe para que la regla no sea imposible por crecer: un sitio de 200
#  paginas nunca llegaria al tercio con el tope por defecto, y la unica salida
#  seria `--max-urls 200` en cada despliegue (lento) o saltarse el gate (peor).
#  Con (b), **ninguna corrida completa por defecto puede fallar este gate**: lo
#  unico que lo dispara es haber medido a proposito menos de lo normal
#  (`--una-sola`, `--max-urls 5`) —que es exactamente el caso que hay que parar—.
#
#  MEDIDO EN LAS CINCO WEBS EL 11-ago-2026, corrida por defecto:
#      climentmedia  25 de 56 paginas selladas  45%   <- la mas ajustada
#      site-a 12 de 18                   67%
#      site-b       11 de 13                   85%
#      site-c 25 de 31                 81%
#      site-d 25 de 41                 61%
#  El liston es 33%: la mas ajustada le saca 12 puntos, y ademas cumple (b).
#  No es un numero elegido para que pasen: es el numero por debajo del cual la
#  frase «el arbol paso el QA» deja de tener contenido.
#
#  🔴 NO HAY VALVULA, Y ES A PROPOSITO. `--aun-asi` existe para lo NO VERIFICADO
#     porque ahi no hay alternativa (sin navegador no hay DOM y punto). Aqui SI
#     la hay, y son dos, las dos baratas: medir mas (`--max-urls N`) o dejar de
#     sellar lo que no se sube (`<repo>/.qa-arbol`). Una puerta trasera que no
#     hace falta se acaba usando por costumbre.
#
#  ⚠️ LO QUE ESTE GATE **NO** DICE: que el 45% sea suficiente. No lo es. El
#     recibo imprime en voz alta las paginas selladas que nadie miro, y esa
#     lista es el trabajo pendiente. El gate solo se niega a llamar verde a un
#     recibo vacio.
# =============================================================================
our $ALCANCE_MINIMO_PARTE   = 3;    # 1 de cada 3 paginas selladas
our $ALCANCE_MINIMO_PAGINAS = 25;   # o lo que da una corrida completa por defecto

#  Devuelve (\@motivos_de_rechazo, \%datos). Vacio = el alcance no impide nada.
#  UNA sola funcion para el gate y para el informe: si el que imprime y el que
#  bloquea calculan por su cuenta, un dia dicen cosas distintas.
sub juzga_alcance {
    my ($R) = @_;
    my @mal;
    my %d = (declarado => 0);

    if (!defined $R->{'ALCANCE-URLS'}) {
        $d{motivo} = 'NO DECLARADO';
        push @mal, "el recibo NO DECLARA SU ALCANCE: sella "
                 . ($R->{'ARBOL-FICHEROS'} // '?')
                 . " ficheros y no dice sobre cuantas paginas se midio";
        push @mal, "   un recibo sin alcance se lee como si cubriera el arbol entero, y";
        push @mal, "   casi nunca lo cubre. Lo escribio una version vieja de qa-maestro";
        push @mal, "   o se escribio a mano. Vuelve a medir y el recibo lo declarara solo:";
        push @mal, "       perl qa-master.pl " . ($R->{SITIO} // '<URL>')
                 . " --repo " . ($R->{REPO} // '<REPO>');
        return (\@mal, \%d);
    }

    $d{declarado} = 1;
    my $m = mapa_alcance($R->{SITIO}, $R->{_manifiesto} || [], [ urls_del_alcance($R) ]);
    %d = (%d, %$m);

    # ── el caso raro: hay URLs medidas y no casa NI UNA con el arbol ─────────
    #  Eso no es «cobertura cero»: es que el mapeo ruta->URL de esta web no es
    #  el que supongo (una web servida bajo subcarpeta, otro dominio, un CMS).
    #  Bloquear ahi seria acusar a la web de un fallo MIO. Se cae al numero que
    #  no depende de ninguna hipotesis —cuantas URLs se midieron— y se dice.
    my $base = $m->{medidas};
    if ($m->{medidas} == 0 && $m->{urls} > 0 && $m->{selladas} > 0) {
        $base = $m->{urls};
        $d{mapeo_roto} = 1;
    }
    $d{base} = $base;

    my $ok = ($base * $ALCANCE_MINIMO_PARTE >= $m->{selladas})
          || ($base >= $ALCANCE_MINIMO_PAGINAS);
    return (\@mal, \%d) if $ok;

    push @mal, sprintf("ALCANCE IRRISORIO: %d pagina%s medida%s de las %d paginas HTML que este recibo SELLA (%d%%)",
                       $base, ($base == 1 ? '' : 's'), ($base == 1 ? '' : 's'),
                       $m->{selladas},
                       ($m->{selladas} ? int(100 * $base / $m->{selladas} + 0.5) : 0));
    push @mal, "   El recibo dice PASA sobre lo que midio, no sobre lo que firma. Con este";
    push @mal, "   alcance, «el arbol paso el QA» no lo sostiene nada.";
    push @mal, sprintf("   El minimo para desplegar es 1 de cada %d paginas selladas (%d aqui), o %d paginas.",
                       $ALCANCE_MINIMO_PARTE,
                       int(($m->{selladas} + $ALCANCE_MINIMO_PARTE - 1) / $ALCANCE_MINIMO_PARTE),
                       $ALCANCE_MINIMO_PAGINAS);
    push @mal, "   Dos formas de arreglarlo, las dos baratas:";
    push @mal, "     1 · medir mas:  perl qa-master.pl " . ($R->{SITIO} // '<URL>')
             . " --repo " . ($R->{REPO} // '<REPO>') . " --max-urls " . $m->{selladas};
    push @mal, "     2 · o dejar de sellar lo que no se sube, en <repo>/.qa-arbol:";
    push @mal, "           EXCLUIR: ruta/que/no/se/despliega/**";
    if (@{ $m->{sin_medir} }) {
        my @s = @{ $m->{sin_medir} };
        push @mal, "   sin medir: " . join(', ', @s[0 .. ($#s > 3 ? 3 : $#s)])
                 . (@s > 4 ? sprintf(' ... y %d mas', @s - 4) : '');
    }
    push @mal, "   ⚠ el mapeo ruta->URL no ha casado NI UNA pagina: el numero de arriba son"
        if $d{mapeo_roto};
    push @mal, "     URLs medidas, no paginas del arbol. Mirar urls_candidatas() para esta web."
        if $d{mapeo_roto};
    return (\@mal, \%d);
}

sub urls_del_alcance {
    my ($R) = @_;
    return map { $R->{$_} } sort grep { /^ALCANCE-URL-\d+$/ } keys %$R;
}

#  «1,2,3,4,9,11,12» -> «1-4,9,11-12». Sin esto, site-b pone 100 lineas de URL
#  repetida en el recibo para no decir nada que no estuviera ya.
sub rangos {
    my @n = sort { $a <=> $b } grep { defined } @_;
    return '' unless @n;
    my @out;
    my ($ini, $ant) = ($n[0], $n[0]);
    for my $i (@n[1 .. $#n]) {
        if ($i == $ant + 1) { $ant = $i; next }
        push @out, ($ini == $ant ? $ini : ($ant == $ini + 1 ? "$ini,$ant" : "$ini-$ant"));
        $ini = $ant = $i;
    }
    push @out, ($ini == $ant ? $ini : ($ant == $ini + 1 ? "$ini,$ant" : "$ini-$ant"));
    return join(',', @out);
}

sub alcance_lineas {
    my (%a) = @_;
    my $al  = $a{alcance};
    my $man = $a{manifiesto} || [];
    my $nficheros = $a{ficheros} // scalar(@$man);
    my @L;
    my @LENTES = qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA);
    my @sell = paginas_selladas($man);

    my $hay = ($al && ref $al eq 'HASH' && grep { defined $al->{$_} } @LENTES) ? 1 : 0;
    if (!$hay) {
        push @L, "ALCANCE: NO DECLARADO";
        push @L, "ALCANCE-FICHEROS-SELLADOS: $nficheros";
        push @L, "ALCANCE-PAGINAS-SELLADAS: " . scalar(@sell);
        return @L;
    }

    my (%todas, %porlente);
    for my $l (@LENTES) {
        my $v = $al->{$l};
        next unless defined $v;
        my @u = ref $v eq 'ARRAY' ? @$v : ref $v eq 'HASH' ? (sort keys %$v) : ($v);
        @u = grep { defined $_ && $_ ne '' } @u;
        $porlente{$l} = \@u;
        $todas{$_} = 1 for @u;
    }
    my @todas = sort keys %todas;
    my %idx; my $i = 0;
    $idx{$_} = ++$i for @todas;

    my $sitio_urls = $a{sitio_urls};
    $sitio_urls = undef unless defined $sitio_urls && $sitio_urls =~ /^\d+$/ && $sitio_urls > 0;
    my $mapa = mapa_alcance($a{sitio}, $man, \@todas);

    # ⚠️ TODO en ASCII: estas lineas van bajo el SELLO, que es un md5 sobre
    #    bytes. Un «·» aqui hace que el recibo dependa de como se decodifico.
    push @L, "ALCANCE-URLS: " . scalar(@todas);
    push @L, "ALCANCE-SITIO: " . (defined $sitio_urls ? $sitio_urls : 'NO SE SABE');
    push @L, "ALCANCE-LISTA: "      . ($a{lista_urls}  // scalar(@todas));
    push @L, "ALCANCE-DOCUMENTOS: " . ($a{documentos}  // scalar(@todas));
    push @L, "ALCANCE-FICHEROS-SELLADOS: $nficheros";
    push @L, "ALCANCE-PAGINAS-SELLADAS: " . $mapa->{selladas};
    push @L, "ALCANCE-PAGINAS-MEDIDAS: "  . $mapa->{medidas};
    for my $l (@LENTES) {
        if (!exists $porlente{$l}) { push @L, "ALCANCE-$l: NO CORRIDA"; next }
        my @u = @{ $porlente{$l} };
        my $de = defined $sitio_urls ? "$sitio_urls del sitio" : "? del sitio (NO SE SABE)";
        push @L, sprintf("ALCANCE-%s: %d de %s - URLS %s",
                         $l, scalar(@u), $de, rangos(map { $idx{$_} } @u));
    }
    push @L, "ALCANCE-DOM: " . solo_ascii($a{dom}) if defined $a{dom} && $a{dom} ne '';
    $i = 0;
    for my $u (@todas) {
        $i++;
        push @L, sprintf("ALCANCE-URL-%03d: %s", $i, solo_ascii($u));
    }
    return @L;
}

#  Imprime el alcance en lenguaje humano. Se usa en --verificar: es ahi donde
#  alguien decide si se fia del recibo, y es ahi donde tiene que ver el desfase.
sub imprime_alcance {
    my ($R) = @_;
    my $nf = $R->{'ALCANCE-FICHEROS-SELLADOS'} // $R->{'ARBOL-FICHEROS'} // '?';
    my (undef, $d) = juzga_alcance($R);
    if (!$d->{declarado}) {
        print "  ⚠ ALCANCE NO DECLARADO: el recibo sella $nf ficheros y no dice sobre\n";
        print "    cuantas URLs se midio. Un recibo que no declara su alcance se lee\n";
        print "    como si cubriera el arbol entero, y casi nunca lo cubre.\n";
        return;
    }
    my $n = $R->{'ALCANCE-URLS'} + 0;
    if ($d->{selladas}) {
        printf "  alcance: %d de %d paginas HTML selladas (%d%%) · %d URL%s medida%s · %s ficheros sellados\n",
               $d->{medidas}, $d->{selladas},
               int(100 * $d->{medidas} / $d->{selladas} + 0.5),
               $n, ($n == 1 ? '' : 's'), ($n == 1 ? '' : 's'), $nf;
    } else {
        # No es «cobertura 0»: es que no hay nada de esto que medir. Decirlo
        # como «0 de 0 (0%)» seria una alarma inventada, y las alarmas
        # inventadas son las que ensenan a no leer el bloque.
        printf "  alcance: %d URL%s medida%s · %s ficheros sellados · el arbol NO sella ninguna\n",
               $n, ($n == 1 ? '' : 's'), ($n == 1 ? '' : 's'), $nf;
        print  "    pagina HTML, asi que no hay porcion del arbol que calcular\n";
    }
    if (defined $R->{'ALCANCE-SITIO'}) {
        if ($R->{'ALCANCE-SITIO'} =~ /^\d+$/) {
            printf "    el sitio declara %s URL%s en su sitemap\n",
                   $R->{'ALCANCE-SITIO'}, ($R->{'ALCANCE-SITIO'} == 1 ? '' : 's');
        } else {
            # sin sitemap no hay total del SITIO. Se dice, en vez de dejar el
            # denominador de las paginas selladas haciendose pasar por el.
            print "    NO consta cuantas URLs tiene el sitio (sin sitemap): el porcentaje\n";
            print "    de arriba es sobre el ARBOL, no sobre el sitio\n";
        }
    }
    my @det = map { "$_ " . ($R->{"ALCANCE-$_"} // '?') }
              grep { defined $R->{"ALCANCE-$_"} }
              qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA);
    print  "    por lente:\n" if @det;
    print  "      $_\n" for @det;
    print  "    DOM: " . $R->{'ALCANCE-DOM'} . "\n" if defined $R->{'ALCANCE-DOM'};
    my @u = urls_del_alcance($R);
    print  "    " . $_ . "\n" for @u[0 .. ($#u > 2 ? 2 : $#u)];
    print  "    ... y " . (@u - 3) . " URLs mas (todas en el recibo, ALCANCE-URL-NNN)\n" if @u > 3;
    # 🔴 lo que el recibo FIRMA y nadie ha mirado. Es la mitad que faltaba: sin
    #    esta lista, «PASA» se lee sobre el arbol entero.
    if (@{ $d->{sin_medir} || [] }) {
        my @s = @{ $d->{sin_medir} };
        printf "  ⚠ %d pagina%s HTML van FIRMADAS y NO MEDIDAS. Este recibo no dice nada de:\n",
               scalar(@s), (@s == 1 ? '' : 's');
        print  "      $_\n" for @s[0 .. ($#s > 4 ? 4 : $#s)];
        printf "      ... y %d mas\n", @s - 5 if @s > 5;
    }
    if (@{ $d->{huerfanas} || [] }) {
        my @h = @{ $d->{huerfanas} };
        printf "  ⚠ %d URL%s medida%s no casa%s con ningun fichero del arbol (mapeo ruta->URL):\n",
               scalar(@h), (@h == 1 ? '' : 's'), (@h == 1 ? '' : 's'), (@h == 1 ? '' : 'n');
        print  "      $_\n" for @h[0 .. ($#h > 2 ? 2 : $#h)];
    }
}

# =============================================================================
#  3-quater · CONTRA QUE SE MIDIO — la cara del recibo
# =============================================================================
#  Se imprime en `--verificar` porque es ahi donde alguien decide si se fia. Las
#  dos frases que hay que poder decir en voz alta al leerlo:
#    CANDIDATO  → «este veredicto habla del arbol que voy a subir; de produccion
#                  no dice nada, y por eso G11 sigue siendo obligatorio»
#    PRODUCCION → «este veredicto habla de la web que ya esta subida; de los
#                  cambios que tengo en el repo no dice nada»
#  Los recibos anteriores al 11-ago-2026 no llevan la linea: se leen como
#  PRODUCCION, que es lo que eran todos, y se dice que se esta suponiendo.
sub medido_contra {
    my ($R) = @_;
    my $v = uc($R->{'MEDIDO-CONTRA'} // '');
    return $v eq 'CANDIDATO' ? 'CANDIDATO' : $v eq 'PRODUCCION' ? 'PRODUCCION' : 'PRODUCCION (supuesto: recibo sin la linea)';
}
sub nv_por_candidato {
    my ($R) = @_;
    my @x = split /\s+/, ($R->{'NV-POR-CANDIDATO'} // '');
    return grep { $_ ne '' } @x;
}
sub imprime_medido_contra {
    my ($R) = @_;
    my $m = medido_contra($R);
    printf "  medido contra: %s%s\n", $m,
           (defined $R->{'MEDIDO-EN'} && $R->{'MEDIDO-EN'} ne '' ? " ($R->{'MEDIDO-EN'})" : '');
    if ($m eq 'CANDIDATO') {
        print "    el veredicto es del ARBOL QUE ESTE RECIBO SELLA. Es el gate de ANTES\n";
        print "    de subir, y es el unico que puede decir algo de lo que se va a subir.\n";
        print "    NO dice nada de produccion: eso lo contesta G11 DESPUES (--servido).\n";
        my @nv = nv_por_candidato($R);
        if (@nv) {
            printf "    %d comprobaciones quedaron sin medir por ser el candidato: %s\n",
                   scalar(@nv), join(' ', @nv);
            print  "    No son huecos de nadie: son configuracion del host, y las contesta G11.\n";
        }
    } else {
        print "    ⚠ el veredicto es de la WEB YA SUBIDA, no del arbol que este recibo sella.\n";
        print "    Si el repo trae cambios sin subir, este recibo no dice nada de ellos:\n";
        print "    ni de un arreglo que aun no esta arriba, ni de un defecto nuevo.\n";
        print "    Para medir lo que se va a subir: qa-master.pl <URL> --repo DIR --candidato\n";
    }
}

# =============================================================================
#  3-quinquies · LOS ACEPTADOS — lo que se decidio no arreglar, dicho en alto
# =============================================================================
#  Se imprime en `--verificar` por el mismo motivo que `medido contra`: es ahi
#  donde alguien decide si se fia. La frase que hay que poder decir en voz alta
#  al leerlo es «esta web pasa el gate CON estos cinco defectos conocidos, los
#  firmo fulano tal dia, y caducan tal otro».
sub imprime_aceptados {
    my ($R) = @_;
    my $n = $R->{ACEPTADO} // 0;
    if ($R->{'ACEPTADOS-RECHAZADOS'}) {
        printf "  ⚠ %s entrada(s) de aceptado.conf fueron RECHAZADAS al medir: no valian,\n",
               $R->{'ACEPTADOS-RECHAZADOS'};
        print  "    y esos fallos siguieron contando. Mirar el informe del QA.\n";
    }
    return unless $n;
    printf "  ACEPTADOS: %d · decisiones ya tomadas, no defectos sin arreglar\n", $n;
    for my $i (1 .. $n) {
        my $l = $R->{sprintf('ACEPTADO-%03d', $i)} // next;
        my $h = $R->{sprintf('ACEPTADO-%03d-HUELLA', $i)} // '';
        my $p = $R->{sprintf('ACEPTADO-%03d-PARCIAL', $i)} // '';
        my $c = $R->{sprintf('ACEPTADO-%03d-CUBRE',   $i)} // '';
        print "    $l\n";
        print "        huella: $h\n" if $h ne '';
        print "        cubre:  $c hallazgo(s)\n" if $c ne '';
        # Se dice AQUI, pegado a la aceptacion, y no en una nota al pie: el que
        # lee esto esta decidiendo si despliega, y necesita saber que esta
        # aceptacion no habla de todo el sitio.
        if ($p ne '') {
            print "        🔴 ACEPTACION PARCIAL — no cubre todo el sitio:\n";
            print "           $p\n";
        }
    }
    if (my $p = $R->{'ACEPTADOS-CADUCAN-PRONTO'}) {
        print "  🔴 CADUCAN PRONTO: $p\n";
        print "     Cuando caduquen vuelven a ser FALLO y la puerta se cierra. Decidirlo antes.\n";
    }
    print "  Ninguno de estos se dejo de medir: se midieron, dieron mal, y alguien firmo\n";
    print "  que era una decision y no un defecto. Si el hallazgo cambia, vuelve a contar.\n";
}

sub escribe_recibo {
    my (%a) = @_;
    my $repo = norm_ruta($a{repo});
    my ($man, $hash) = arbol($repo);
    my ($est, $nest) = hash_estandar();
    my $ahora = time;
    my $horas = defined $a{horas} ? $a{horas} : 12;

    my @cuerpo;
    push @cuerpo, "RECIBO-VERSION: $VERSION_RECIBO";
    push @cuerpo, "SITIO: " . solo_ascii($a{sitio} // '');
    push @cuerpo, "REPO: " . solo_ascii($repo);
    push @cuerpo, "FECHA: " . strftime('%Y-%m-%dT%H:%M:%S', localtime($ahora));
    push @cuerpo, "FECHA-EPOCH: $ahora";
    push @cuerpo, "CADUCA-EPOCH: " . ($ahora + $horas * 3600);
    push @cuerpo, "CADUCA: " . strftime('%Y-%m-%dT%H:%M:%S', localtime($ahora + $horas * 3600));
    push @cuerpo, "ESTANDAR: $est ($nest ficheros)";
    push @cuerpo, "INSTRUMENTO: " . solo_ascii($a{instrumento} // "perl $]");
    # ── 🔴 CONTRA QUE SE MIDIO (11-ago-2026) ────────────────────────────────
    #  EL FALLO que trae esta linea: el recibo sellaba EL ARBOL DEL REPO (118
    #  ficheros, su md5) con un veredicto sacado de medir PRODUCCION. Dos
    #  artefactos distintos con una sola cara, y de ahi el bucle de site-d: la
    #  puerta se negaba a subir el arreglo porque produccion estaba mal, y
    #  produccion estaba mal porque no se habia subido el arreglo. Al reves era
    #  peor: un arbol con un defecto NUEVO sacaba recibo verde si la web que ya
    #  estaba subida estaba bien.
    #      CANDIDATO  · el veredicto es del arbol que este recibo firma. Es el
    #                   gate de ANTES de subir. No dice nada de produccion.
    #      PRODUCCION · el veredicto es de la web viva. Es el gate de DESPUES.
    #  Un recibo sin esta linea es de antes del arreglo: se lee como PRODUCCION,
    #  que es lo que eran todos.
    push @cuerpo, "MEDIDO-CONTRA: " . solo_ascii($a{medido_contra} // 'PRODUCCION');
    push @cuerpo, "MEDIDO-EN: "     . solo_ascii($a{medido_en} // ($a{sitio} // ''));
    push @cuerpo, "ARBOL-HASH: $hash";
    push @cuerpo, "ARBOL-FICHEROS: " . scalar(@$man);
    # Lo que el deploy.conf saca del arbol: decide QUE NO SE MIDE, asi que va
    # escrito y bajo el SELLO. Sin esta linea, un patron demasiado ancho dejaria
    # paginas fuera del recibo sin dejar rastro.
    push @cuerpo, "ARBOL-EXCLUIDO-POR-DEPLOY: " . join(' ', @EXCLUIDO_POR_DEPLOY)
        if @EXCLUIDO_POR_DEPLOY;
    push @cuerpo, "ARBOL-BYTES: " . eval { my $s = 0; $s += $_->[2] for @$man; $s };
    # ── 🔴 LOS RECEPTORES, SELLADOS APARTE (11-ago-2026) ────────────────────
    #  Por que aparte y no dentro de ARBOL-HASH: seccion 1-bis, con los tres
    #  motivos. Resumen: el manifiesto es la lista que G11 pide POR HTTP, y un
    #  .php no se puede pedir por HTTP sin que sea una fuga de fuente.
    #  Van bajo el SELLO igual que todo lo demas, asi que estirar uno a mano
    #  rompe el recibo entero.
    my @rec = receptores($repo);
    if (@rec) {
        push @cuerpo, "RECEPTORES: " . scalar(@rec);
        push @cuerpo, "RECEPTORES-HASH: " . receptores_hash(@rec);
        my $ri = 0;
        for my $r (@rec) {
            $ri++;
            push @cuerpo, sprintf('RECEPTOR-%03d: %s %d %s -> %s',
                                  $ri, $r->{md5}, $r->{bytes},
                                  solo_ascii($r->{repo}), solo_ascii($r->{prod}));
        }
    }
    for my $l (qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA)) {
        push @cuerpo, "LENTE-$l: " . (($a{lentes} && $a{lentes}{$l}) ? $a{lentes}{$l} : 'NO CORRIDA');
    }
    push @cuerpo, "FALLO: "         . ($a{fallo} // 0);
    push @cuerpo, "AVISO: "         . ($a{aviso} // 0);
    push @cuerpo, "NO-VERIFICADO: " . ($a{nv}    // 0);
    push @cuerpo, "PASA: "          . ($a{pasa}  // 0);
    push @cuerpo, "ACEPTADO: "      . scalar(@{ $a{aceptados} || [] });
    push @cuerpo, "VEREDICTO: "     . solo_ascii($a{veredicto} // 'DESCONOCIDO');
    # ── 🔴 LOS ACEPTADOS, ID POR ID, EN LA CARA DEL RECIBO ──────────────────
    #  Un fallo ACEPTADO es una decision de negocio ya tomada, no un defecto sin
    #  arreglar: por eso no cuenta para el veredicto. Pero un silenciador que no
    #  se ve es un defecto enterrado con papeleo, asi que sale AQUI, con su
    #  motivo, quien lo firma y hasta cuando. El que despliega no puede decir que
    #  no lo sabia: lo tiene delante, bajo el SELLO, y si alguien edita una de
    #  estas lineas para estirar una fecha el sello deja de cuadrar.
    if ($a{aceptados} && @{$a{aceptados}}) {
        my $aviso_d = defined $a{aceptados_aviso_dias} ? $a{aceptados_aviso_dias} : 14;
        my $i = 0;
        my @pronto;
        for my $x (@{ $a{aceptados} }) {
            $i++;
            push @pronto, $x->{id} if defined $x->{dias} && $x->{dias} <= $aviso_d;
            push @cuerpo, sprintf('ACEPTADO-%03d: %s | hasta %s | quedan %s d | %s | %s',
                                  $i, solo_ascii($x->{id}), solo_ascii($x->{hasta} // '?'),
                                  (defined $x->{dias} ? $x->{dias} : '?'),
                                  solo_ascii($x->{acepta} // '?'), solo_ascii($x->{motivo} // ''));
            # La huella aparte: es larga, y es lo unico que ata la aceptacion a
            # ESTE hallazgo y no al check entero. Si cambia, la aceptacion muere.
            push @cuerpo, sprintf('ACEPTADO-%03d-HUELLA: %s', $i, solo_ascii($x->{huella} // ''));
            # 🔴 UNA ACEPTACION QUE NO PUEDE GARANTIZAR SU ALCANCE NO PUEDE
            #    PRESENTARSE COMO SI LO HICIERA. Hay checks que miden una
            #    MUESTRA (RENDIMIENTO mira 3 paginas de 25) o cuya evidencia
            #    depende de cuantas paginas bajaron. Aceptar su hallazgo NO es
            #    aceptar que el resto del sitio este limpio, y sin esta linea
            #    el recibo lo dejaria creer. Va BAJO EL SELLO como todo lo
            #    demas: borrarla para que parezca completa rompe el sello.
            push @cuerpo, sprintf('ACEPTADO-%03d-PARCIAL: %s', $i, solo_ascii($x->{parcial}))
                if defined $x->{parcial} && $x->{parcial} ne '';
            push @cuerpo, sprintf('ACEPTADO-%03d-CUBRE: %s', $i, $x->{cubre})
                if defined $x->{cubre} && $x->{cubre};
        }
        push @cuerpo, "ACEPTADOS-CADUCAN-PRONTO: " . solo_ascii(join(' ', @pronto)) if @pronto;
        # El md5 del conf que los firmo. `_deploy/` y los `.conf` estan fuera del
        # arbol desplegable —correctamente: no se suben—, asi que ARBOL-HASH no
        # los cubre y sin esta linea no habria forma de saber que version del
        # fichero produjo este veredicto.
        push @cuerpo, "ACEPTADOS-CONF-MD5: " . solo_ascii($a{aceptados_conf})
            if defined $a{aceptados_conf} && $a{aceptados_conf} ne '';
    }
    # Entradas del conf que el gate RECHAZO. Cero no se escribe; cualquier otra
    # cosa si, porque significa que alguien creyo tener una decision firmada y
    # no la tiene —y el fallo siguio contando—.
    push @cuerpo, "ACEPTADOS-RECHAZADOS: " . $a{aceptados_rechazados}
        if $a{aceptados_rechazados};
    # 🔴 La linea que hace honesto el recibo: que NO se ha mirado.
    if ($a{nv_ids} && @{$a{nv_ids}}) {
        push @cuerpo, "SIN-MIRAR: " . solo_ascii(join(' ', @{$a{nv_ids}}));
    }
    if ($a{fallo_ids} && @{$a{fallo_ids}}) {
        push @cuerpo, "FALLAN: " . solo_ascii(join(' ', @{$a{fallo_ids}}));
    }
    # De los SIN-MIRAR, los que quedaron asi *por medir el candidato*. No son
    # huecos de nadie: son las preguntas que solo produccion contesta, y las
    # contesta G11 al subir. Se separan para que `deploy.sh` no pida
    # `--aun-asi` por ellas: un `--aun-asi` que hace falta en cada despliegue
    # deja de significar nada, y entonces tampoco protege a los huecos de verdad.
    if ($a{nv_candidato} && @{$a{nv_candidato}}) {
        push @cuerpo, "NV-POR-CANDIDATO: " . solo_ascii(join(' ', @{$a{nv_candidato}}));
    }
    push @cuerpo, alcance_lineas(alcance    => $a{alcance},
                                 dom        => $a{alcance_dom},
                                 manifiesto => $man,
                                 ficheros   => scalar(@$man),
                                 sitio      => ($a{sitio} // ''),
                                 sitio_urls => $a{alcance_sitio},
                                 lista_urls => $a{alcance_lista},
                                 documentos => $a{alcance_documentos});
    push @cuerpo, "---MANIFIESTO---";
    push @cuerpo, "$_->[1]\t$_->[2]\t$_->[0]" for @$man;

    my $cuerpo = join("\n", @cuerpo) . "\n";
    my $sello  = md5_hex($cuerpo);

    my $salida = $a{salida} // "$repo/.qa-recibo";
    open my $fh, '>:raw', $salida or die "no puedo escribir $salida: $!\n";
    print $fh "# RECIBO DE QA - lo escribe qa-master.pl - NO editar a mano.\n";
    print $fh "# El SELLO cubre todo lo que va debajo. Editar una linea lo rompe.\n";
    print $fh "SELLO: $sello\n";
    print $fh $cuerpo;
    close $fh;

    historial(sitio => ($a{sitio} // ''), accion => 'QA',
              veredicto => ($a{veredicto} // '?'), hash => $hash,
              nv => ($a{nv} // 0), nota => "estandar=$est",
              ids => solo_ascii(join(' ', @{ $a{fallo_ids} || [] })));

    return { salida => $salida, hash => $hash, ficheros => scalar(@$man), estandar => $est };
}

# =============================================================================
#  4 · LEER Y VALIDAR
# =============================================================================
sub lee_recibo {
    my ($ruta) = @_;
    return (undef, "no hay recibo en $ruta") unless -f $ruta;
    open my $fh, '<:raw', $ruta or return (undef, "no puedo leer $ruta: $!");
    local $/;
    my $todo = <$fh>;
    close $fh;
    $todo = '' unless defined $todo;
    $todo =~ s/\r\n/\n/g;   # por si git o un editor lo paso a CRLF

    my ($sello) = $todo =~ /^SELLO:\s*([0-9a-f]{32})\s*$/m;
    return (undef, "el recibo no tiene SELLO: no lo ha escrito qa-maestro")
        unless $sello;

    # ⚠️ NO usar /^SELLO:/ sin /m: el recibo empieza por dos lineas de comentario,
    #    asi que ^ (anclado al inicio de la cadena) no casa y TODO recibo parecia
    #    «truncado». Lo cazaron las pruebas; en produccion habria sido un gate que
    #    rechaza siempre, y un gate que rechaza siempre se desactiva a la semana.
    my ($cuerpo) = $todo =~ /\bSELLO:\s*[0-9a-f]{32}\n(.*)\z/s;
    return (undef, "recibo truncado") unless defined $cuerpo;

    my %R;
    my @man;
    my $en_man = 0;
    for my $l (split /\n/, $cuerpo) {
        if ($l eq '---MANIFIESTO---') { $en_man = 1; next; }
        if ($en_man) {
            my ($m, $b, $r) = split /\t/, $l, 3;
            push @man, [ $r, $m, $b ] if defined $r;
            next;
        }
        $R{$1} = $2 if $l =~ /^([A-Z0-9-]+):\s*(.*)$/;
    }
    $R{_manifiesto} = \@man;
    $R{_sello_ok}   = (md5_hex($cuerpo) eq $sello) ? 1 : 0;
    $R{_ruta}       = $ruta;
    return (\%R, undef);
}

#  Devuelve (ok, \@motivos, \%recibo). `para_desplegar` añade las exigencias
#  que solo tienen sentido antes de subir: verde y fresco.
sub verifica {
    my (%o) = @_;
    my $repo = norm_ruta($o{repo});
    my $ruta = $o{recibo} // "$repo/.qa-recibo";
    my @mal;

    my ($R, $err) = lee_recibo($ruta);
    if ($err) {
        return (0, [ $err,
                     "NADIE HA CORRIDO EL QA SOBRE ESTE ARBOL, o el recibo se borro.",
                     "Correlo:  perl qa-master.pl <URL> --repo $repo" ], undef);
    }
    push @mal, "el SELLO no cuadra: el recibo se ha editado o esta corrupto"
        unless $R->{_sello_ok};

    # ── 1 · ¿el QA se corrio sobre ESTE arbol? ───────────────────────────────
    my (undef, $hash_ahora) = arbol($repo);
    if (($R->{'ARBOL-HASH'} // '') ne $hash_ahora) {
        push @mal, "el arbol ha CAMBIADO desde el QA";
        push @mal, "   recibo: " . ($R->{'ARBOL-HASH'} // '?') . "  ·  ahora: $hash_ahora";
        # decir QUE cambio, o el mensaje no sirve para nada
        my @dif = diferencias($repo, $R->{_manifiesto});
        push @mal, "   " . $_ for @dif[0 .. ($#dif > 5 ? 5 : $#dif)];
        push @mal, "   ... y " . (@dif - 6) . " mas" if @dif > 6;
    }

    # ── 1-bis · ¿y los RECEPTORES? ──────────────────────────────────────────
    #  Misma pregunta que el arbol, sobre lo otro que se despliega. Se trata
    #  igual de duro: si el contact.php ha cambiado desde que se midio, este
    #  recibo no habla de lo que se va a subir.
    #  Un recibo SIN la linea teniendo el repo receptores es anterior al sellado
    #  (11-ago-2026): tampoco vale, y decirlo es mas barato que un rojo raro.
    #  Los recibos caducan a las 12 h, asi que esto no jubila ninguno vivo.
    {
        my @rec_ahora  = receptores($repo);
        my $rh_ahora   = receptores_hash(@rec_ahora);
        my $rh_recibo  = $R->{'RECEPTORES-HASH'} // '';
        if ($rh_recibo eq '' && $rh_ahora ne '') {
            push @mal, "el recibo NO sella los receptores y este repo tiene " . scalar(@rec_ahora);
            push @mal, "   es un recibo anterior al 11-ago-2026: vuelve a medir";
        } elsif ($rh_recibo ne $rh_ahora) {
            push @mal, "los RECEPTORES han CAMBIADO desde el QA";
            push @mal, "   recibo: " . ($rh_recibo || '(ninguno)') . "  ·  ahora: " . ($rh_ahora || '(ninguno)');
            my %v = map { $_->{prod} => $_->{md5} } receptores_del_recibo($R);
            my %n = map { $_->{prod} => $_->{md5} } @rec_ahora;
            for my $k (sort keys %n) {
                push @mal, "   NUEVO     $k"                          unless exists $v{$k};
                push @mal, "   CAMBIADO  $k" if exists $v{$k} && $v{$k} ne $n{$k};
            }
            push @mal, "   RETIRADO  $_" for sort grep { !exists $n{$_} } keys %v;
        }
    }

    # ── 2 · frescura y color: solo cuando se va a desplegar ──────────────────
    if ($o{para_desplegar}) {
        my $horas = defined $o{horas} ? $o{horas} : 12;
        my $cad = $R->{'CADUCA-EPOCH'} // 0;
        my $lim = ($R->{'FECHA-EPOCH'} // 0) + $horas * 3600;
        $cad = $lim if $lim < $cad;   # --horas puede apretar, nunca aflojar
        # >= y no >: «--horas 0» tiene que caducar SIEMPRE (es la forma de
        # forzar que se vuelva a medir), y en una ventana de 12 h que caduque
        # un segundo antes no le importa a nadie.
        if (time >= $cad) {
            my $h = int((time - ($R->{'FECHA-EPOCH'} // 0)) / 3600);
            push @mal, "el recibo esta CADUCADO: se midio hace ${h} h (ventana ${horas} h)";
            push @mal, "   la web viva y sus terceros cambian sin tocar el repo";
        }
        # ⚠️ /^PASA\b/ y no `eq 'PASA'`: desde el estado ACEPTADO el veredicto se
        #    escribe «PASA (con N aceptados)» a proposito —«PASA» a secas seria
        #    mentir por omision a quien solo lee esta linea—. `\b` es lo que
        #    impide que un futuro «PASAJERO» o «PASA-A-MEDIAS» cuele por parecido.
        if (($R->{VEREDICTO} // '') !~ /^PASA\b/) {
            push @mal, "VEREDICTO: " . ($R->{VEREDICTO} // '?') . " - EN ROJO NO SE DESPLIEGA";
            for my $l (qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA)) {
                my $v = $R->{"LENTE-$l"} // '?';
                push @mal, "   lente $l: $v" if $v =~ /FALLA/;
            }
        }

        # ── 🔴 LA PUERTA DE ATRAS MAS FACIL ─────────────────────────────────
        # `qa-master.pl --solo seo` sale PASA en 20 segundos y escribia un
        # recibo verde con CUATRO lentes sin correr. Lo encontre en la primera
        # corrida real contra site-a: recibo VALIDO, veredicto PASA,
        # LENTE-RENDIMIENTO / ACCESIBILIDAD / MEDICION / ESTRUCTURA en «NO
        # CORRIDA». Es exactamente el fallo que este encargo viene a matar —el
        # gate existe, y hay una forma comoda de no pasar por el— y habria
        # aparecido la primera semana, no como trampa sino como atajo razonable.
        # Una lente que no se corrio no es un aprobado ni un aviso: es un hueco.
        # 🔴 13-ago-2026 · DOS HUECOS DISTINTOS, DOS MENSAJES (trampa §18).
        #    Antes salian juntos como «SIN CORRER», y no es lo mismo:
        #      · NO CORRIDA    -> la lente ni se lanzo (recibo hecho con --solo)
        #      · NO VERIFICADA -> la lente SI corrio y no midio NADA: todas sus
        #        comprobaciones en NO VERIFICADO. Medido apuntando el gate a un
        #        puerto muerto: `PASA 0` y el recibo sellaba «LENTE-SEO: PASA».
        #    Decirle «no la has corrido» a alguien que si la corrio le manda a
        #    arreglar lo que no es -- que es como se pierde una tarde.
        my @sin_correr = grep { ($R->{"LENTE-$_"} // 'NO CORRIDA') eq 'NO CORRIDA' }
                         qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA);
        my @sin_medir  = grep { ($R->{"LENTE-$_"} // '') eq 'NO VERIFICADA' }
                         qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA);
        my @otras      = grep { my $v = $R->{"LENTE-$_"} // 'NO CORRIDA';
                                $v !~ /^(PASA|FALLA|NO CORRIDA|NO VERIFICADA)$/ }
                         qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA);
        if (@sin_correr) {
            push @mal, "hay lentes SIN CORRER: " . join(', ', @sin_correr);
            push @mal, "   el recibo se escribio con --solo, y media medida no es una medida";
            push @mal, "   correr qa-master.pl SIN --solo antes de desplegar";
        }
        if (@sin_medir) {
            push @mal, "hay lentes que CORRIERON y no midieron NADA: " . join(', ', @sin_medir);
            push @mal, "   todas sus comprobaciones salieron NO VERIFICADO: cero medido, cero aprobado";
            push @mal, "   mirar por que no pudo medir (la web no contesta, falta el --dom, falta un dato)";
        }
        if (@otras) {
            push @mal, "lentes con un estado que no se leer: " . join(', ', @otras);
        }

        # ── 🔴 EL ALCANCE (11-ago-2026) ─────────────────────────────────────
        #  Hermana de la de arriba. Esa caza «he corrido 1 de 5 LENTES»; esta
        #  caza «he mirado 1 de 40 PAGINAS». Las dos son la misma mentira —un
        #  verde sacado de una muestra que no da para el veredicto— y hasta hoy
        #  solo estaba tapada la primera. El criterio y su justificacion, en la
        #  cabecera de la seccion 3-ter: aqui solo se aplica.
        #  ⚠️ Va en `para_desplegar` a proposito: `--verificar` a secas contesta
        #     «¿se corrio el QA sobre este arbol?», y a esa pregunta el alcance
        #     no la cambia. Lo que el alcance decide es si vale como VERDE.
        my ($mal_alc) = juzga_alcance($R);
        push @mal, @$mal_alc;
    }

    return (@mal ? 0 : 1, \@mal, $R);
}

sub diferencias {
    my ($repo, $man_viejo) = @_;
    my ($man_nuevo) = arbol($repo);
    my %v = map { $_->[0] => $_->[1] } @$man_viejo;
    my %n = map { $_->[0] => $_->[1] } @$man_nuevo;
    my @d;
    for my $k (sort keys %n) {
        if (!exists $v{$k})          { push @d, "NUEVO     $k" }
        elsif ($v{$k} ne $n{$k})     { push @d, "CAMBIADO  $k" }
    }
    push @d, "BORRADO   $_" for sort grep { !exists $n{$_} } keys %v;
    return @d;
}

# =============================================================================
#  5 · G11 · ¿LO QUE SE SIRVE ES LO DEL RECIBO?
# =============================================================================
#  Este es el gate que hoy NO existe y que habria cazado site-d. Los demas
#  gates miden el repo o miden la web; ninguno comprueba que sean lo mismo
#  DESPUES de subir, que es justo el momento en que se dejan de mirar.
#
#  ⚠️ curl SIEMPRE con -L: sin el se mide el cuerpo de un 301.
#
#  🔴 Y SIEMPRE con un «Accept» explicito. Aqui ponia que el 403 de
#     shop.site-b.example se evitaba con el UA de navegador. ERA FALSO, y costo
#     caro: G11 devolvia «95 de 95 NO HALLADO» en site-b y salia con EXIT 0
#     —no comparaba nada y lo daba por bueno—.
#
#     QUE PASA DE VERDAD (medido a mano el 10-ago-2026, 15 peticiones a
#     https://shop.site-b.example/, leyendo las cabeceras del cable con -v):
#         --compressed + UA                       -> 403   <- lo que hacia este fichero
#         --compressed SIN UA                     -> 403   <- el UA NO era la causa
#         UA SIN --compressed                     -> 200   <- ni el UA la cura
#         --compressed + UA + -H "Accept: */*"    -> 200   <- ¡el MISMO valor que ya mandaba!
#         --compressed + UA + -H "X-Nada: 1"      -> 200   <- una cabecera cualquiera basta
#         --compressed + UA + Referer             -> 200   <- por esto qa-master.pl no lo sufre
#         --compressed + UA + Accept de navegador -> 200   <- en HTML y en PNG
#
#     No es «le falta Accept»: curl manda «Accept: */*» SIEMPRE. Lo que se
#     rechaza es la HUELLA de curl. En el cable, la peticion que da 403 acaba
#     exactamente asi, y esas dos son las dos ultimas cabeceras:
#         Accept: */*
#         Accept-Encoding: deflate, gzip, br, zstd
#     Al pasar -H "Accept: ...", curl quita la suya y la manda DESPUES de
#     Accept-Encoding: cambia el orden, la huella deja de casar, y contesta 200.
#     Por eso «-H X-Nada: 1» tambien lo arregla, con el mismo Accept de antes.
#
#     ⚠️ Lo que NO se: la regla exacta del WAF de Hostinger. Lo de arriba son 15
#        observaciones reproducibles, no la regla. Y por eso el comentario de
#        crawl-links.pl:85 —«403 si llega Accept-Encoding SIN Accept»— acierta
#        el ARREGLO y falla el motivo: nunca llega sin Accept.
#     ⚠️ Esto se probo quitando el arreglo y viendo la prueba en ROJO. La primera
#        version de esa prueba (un servidor que exigia Accept) la pasaba el
#        codigo roto —claro: curl siempre manda Accept—. Una prueba que no se ha
#        visto fallar no prueba nada. Ver receipt-tests/tests-coverage.sh §1.
# =============================================================================
our $UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        . '(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
our $ACCEPT = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';

sub urls_candidatas {
    my ($base, $rel) = @_;
    $base =~ s{/+$}{};
    return ("$base/") if $rel eq 'index.html';
    if ($rel =~ m{^(.*)/index\.html$}) {
        # las URLs de site-d y site-a van SIN barra final; las de climentmedia
        # con ella. Se prueban las dos: es una peticion mas, no una hipotesis.
        return ("$base/$1", "$base/$1/");
    }
    if ($rel =~ m{^(.*)\.html$}) {
        return ("$base/$1", "$base/$rel");
    }
    return ("$base/$rel");
}

# =============================================================================
#  5-ter · UN CDN QUE TRANSFORMA IMAGENES, Y POR QUE NO ES UN «DISTINTO»
# =============================================================================
#  Medido el 20-ago-2026 en site-a.example, la primera vez que G11 corrio
#  detras del CDN de Hostinger (`Server: hcdn`): 49 ficheros identicos y 12
#  DISTINTO. Los 12 eran imagenes, y ninguna estaba mal subida.
#
#  QUE HACE EL CDN, medido fichero a fichero:
#    · PNG  -> lo RECOMPRIME: mismo IHDR (1200x630), le mete un chunk pHYs y
#              reescribe el IDAT. 26.099 bytes en el repo, 27.280 servidos.
#    · JPEG -> lo REDIMENSIONA: el SOF pasa de 1726x911 a 1600x844.
#    · y si la peticion acepta webp, devuelve otra cosa entera: 13.768 bytes.
#
#  🔴 LO QUE SE INTENTO ANTES DE RENDIRSE, porque «no se puede» hay que
#  probarlo: `Cache-Control: no-transform`, `Accept: */*`, sin User-Agent, UA de
#  curl y un cache-buster. Las cinco devuelven la version transformada. **A
#  traves de este CDN los bytes originales son inalcanzables**, y ademas borra
#  `Last-Modified` y `ETag` de las imagenes (el CSS si los lleva), asi que
#  tampoco queda una señal de frescura con la que decir «esta es la nueva».
#
#  POR QUE NO SE MARCAN COMO OK, QUE SERIA LO COMODO
#  Porque no se han comprobado. Van a su propio saco y salen como NO
#  VERIFICADO, con lo que se pierde dicho en voz alta: **una imagen que no se
#  haya subido y cuya version vieja siga sirviendose NO se distingue aqui.**
#  Eso lo contesta el md5 contra el disco por SSH, que es lo que ya hace
#  subir.sh con los receptores.
#
#  POR QUE NO SE EXCLUYEN LAS IMAGENES Y YA
#  Misma razon que con el <lastmod> del sitemap: seria tirar cobertura. Si no
#  hay CDN delante, un md5 de imagen que no casa SIGUE SIENDO FALLO — y ahi es
#  un fallo de verdad. La excepcion solo se aplica cuando hay algo que
#  demostrablemente transforma, y cuando lo servido sigue siendo una imagen.
sub lee_cabeceras {
    my $f = shift;
    return '' unless defined $f && -f $f;
    open my $fh, '<:raw', $f or return '';
    local $/; my $h = <$fh>; close $fh;
    return $h // '';
}

# Devuelve una nota si —y solo si— lo servido es una imagen valida que ha
# pasado por un CDN. undef en cualquier otro caso: entonces es un DISTINTO.
sub cdn_transforma {
    my ($rel, $b, $hdr) = @_;
    return undef unless defined $b && length $b;
    return undef unless $rel =~ /\.(png|jpe?g|gif|webp|avif|ico)$/i;
    # 1 · ¿hay algo delante que transforme? Si no, esto es un defecto nuestro.
    my ($cdn) = ($hdr // '') =~ /^(?:server:\s*(hcdn\S*)|x-hcdn-\S+:|cf-ray:|x-served-by:|x-cache:|x-cdn:|via:)/mi;
    my $marca = $cdn ? "Server: $cdn" : undef;
    unless (defined $marca) {
        my ($linea) = ($hdr // '') =~ /^((?:x-hcdn-\S+|cf-ray|x-served-by|x-cache|x-cdn|via):[^\r\n]*)/mi;
        $marca = $linea if $linea;
    }
    return undef unless defined $marca;
    # 2 · ¿lo servido SIGUE siendo una imagen? Si el CDN devuelve HTML, un reto
    #     antibot o basura, eso no es una transformacion: es un fallo.
    my $fmt = substr($b,0,8) eq "\x89PNG\r\n\x1a\n"      ? 'PNG'
            : substr($b,0,2) eq "\xFF\xD8"                ? 'JPEG'
            : substr($b,0,6) =~ /^GIF8[79]a$/             ? 'GIF'
            : (substr($b,0,4) eq 'RIFF' && substr($b,8,4) eq 'WEBP') ? 'WEBP'
            : substr($b,4,8) eq 'ftypavif'                ? 'AVIF'
            : substr($b,0,4) eq "\x00\x00\x01\x00"        ? 'ICO'
            : undef;
    return undef unless defined $fmt;
    my $dim = medidas_imagen($b);
    return sprintf('%s · %s%s · %d bytes servidos · md5 NO comprobable', $marca, $fmt,
                   ($dim ? " $dim" : ''), length $b);
}

# Ancho x alto de PNG y JPEG sin decodificar la imagen. Solo para el informe:
# el CDN redimensiona, asi que NO se usa como criterio de igualdad.
sub medidas_imagen {
    my $b = shift;
    if (substr($b,0,8) eq "\x89PNG\r\n\x1a\n" && length($b) > 24) {
        my ($w,$h) = unpack('NN', substr($b,16,8));
        return "${w}x${h}" if $w && $h;
    }
    if (substr($b,0,2) eq "\xFF\xD8") {
        my $p = 2;
        while ($p + 4 <= length $b) {
            last unless substr($b,$p,1) eq "\xFF";
            my $m = ord(substr($b,$p+1,1));
            last if $m == 0xDA;
            my $len = unpack('n', substr($b,$p+2,2));
            if ($m >= 0xC0 && $m <= 0xCF && $m != 0xC4 && $m != 0xC8 && $m != 0xCC) {
                my ($h,$w) = unpack('nn', substr($b,$p+5,4));
                return "${w}x${h}" if $w && $h;
            }
            $p += 2 + $len;
        }
    }
    return undef;
}

sub baja {
    my ($url, $cache) = @_;
    my $tmp;
    if ($cache) {
        make_path($cache) unless -d $cache;
        $tmp = "$cache/" . md5_hex($url) . '.bin';
        if (-f $tmp) {
            open my $fh, '<:raw', $tmp or return (undef, 0);
            local $/; my $b = <$fh>; close $fh;
            return ($b, 200, lee_cabeceras("$tmp.hdr"));
        }
    }
    $tmp //= ($ENV{TEMP} || '/tmp') . '/recibo-' . md5_hex($url) . '.bin';
    # 🔴 20-ago-2026 · SE GUARDAN LAS CABECERAS. Sin ellas no hay forma de
    # distinguir «un CDN ha transformado esta imagen» de «alguien ha subido
    # otro fichero», y las dos cosas se ven igual: un md5 que no casa.
    my $code = `curl -sS -L --compressed -A "$UA" -H "Accept: $ACCEPT" -D "$tmp.hdr" -o "$tmp" -w "%{http_code}" "$url" 2>/dev/null`;
    $code =~ s/\D//g;
    $code = $code || 0;
    # 🔴 La cache guarda SOLO los 200. curl escribe el cuerpo del error en el
    #    mismo fichero, y la cache devuelve «200» de oficio: un 403 cacheado
    #    volvia en la corrida siguiente como una pagina servida con md5 distinto
    #    —un DISTINTO inventado, que es la peor salida posible de un gate—.
    #    Sin --cache no se notaba porque el fichero se borraba cada vez.
    my $hdr = lee_cabeceras("$tmp.hdr");
    if ($code != 200) { unlink $tmp if -f $tmp; unlink "$tmp.hdr" if -f "$tmp.hdr"; return (undef, $code, $hdr) }
    return (undef, $code, $hdr) unless -f $tmp;
    open my $fh, '<:raw', $tmp or return (undef, $code, $hdr);
    local $/; my $b = <$fh>; close $fh;
    unless ($cache) { unlink $tmp; unlink "$tmp.hdr" if -f "$tmp.hdr" }
    return ($b, $code, $hdr);
}

# =============================================================================
#  5-bis · EL SITEMAP Y LA FECHA QUE CAMBIA SOLA
# =============================================================================
#  Encontrado en la primera corrida real de G11, en site-a.example:
#      DISTINTO  sitemap.xml -> 200 pero md5 distinto (repo d79944e5 / servido 0f4fbc42)
#  La UNICA diferencia eran los <lastmod>: 2026-08-07 servido, 2026-08-10 en el
#  repo, en las 12 URLs. La causa es _gen.ps1:1490, que estampa la fecha de HOY
#  al generar; site-d hace lo mismo (_gen.ps1:814) y hoy coincide solo porque
#  no se ha regenerado. Es decir: **el sitemap se pone en rojo solo, todos los
#  dias, sin que nadie haya roto nada y sin que nadie pueda arreglarlo.**
#  Un rojo asi no protege: enseña a ignorar el gate, que es peor que no tenerlo.
#
#  🔴 QUE SE COMPARA, Y POR QUE ASI
#  Se neutraliza SOLO el contenido de <lastmod> y se comparan los bytes
#  restantes. La alternativa —comparar la lista de <loc>— tambien mataba el
#  rojo, pero de paso dejaba ciego al gate para <priority>, <changefreq>, los
#  <xhtml:link hreflang>, el orden y la estructura del XML: cualquiera de esas
#  cosas puede romperse en un deploy y ninguna se veria. Normalizar una etiqueta
#  es la exclusion mas pequeña que resuelve el caso; excluir el fichero entero,
#  o reducirlo a su lista de URLs, es tirar cobertura que hoy si tenemos.
#  Y quitar una URL del sitemap SIGUE saltando: los bytes de esa <url> ya no
#  estan (probado en las dos direcciones, tests-sitemap.sh).
# =============================================================================
sub es_sitemap {
    my ($rel) = @_;
    return ($rel =~ m{(^|/)sitemap[^/]*\.xml$}i) ? 1 : 0;
}

sub sin_lastmod {
    my ($x) = @_;
    return '' unless defined $x;
    $x =~ s{<lastmod\b[^>]*>.*?</lastmod>}{<lastmod>=</lastmod>}gsi;
    return $x;
}

sub fechas_lastmod {
    my ($x) = @_;
    return '(ninguna)' unless defined $x;
    my %v;
    while ($x =~ m{<lastmod\b[^>]*>\s*([^<]*?)\s*</lastmod>}gsi) { $v{$1} = 1 }
    return '(ninguna)' unless %v;
    my @k = sort keys %v;
    return join(',', @k[0 .. ($#k > 2 ? 2 : $#k)]) . (@k > 3 ? " +" . (@k - 3) : '');
}

#  Devuelve un texto explicativo si la UNICA diferencia son los <lastmod>, y
#  undef en cualquier otro caso. Lee el fichero del repo y exige que su md5 sea
#  el del MANIFIESTO: si el arbol ha derivado desde el QA, no se concede ninguna
#  excepcion sobre bytes que nadie ha medido.
sub igual_salvo_lastmod {
    my ($repo, $rel, $md5_manifiesto, $servido) = @_;
    return undef unless defined $servido;
    my $local = "$repo/$rel";
    return undef unless -f $local;
    open my $fh, '<:raw', $local or return undef;
    local $/;
    my $b = <$fh>;
    close $fh;
    return undef unless defined $b;
    return undef unless md5_hex($b) eq $md5_manifiesto;   # arbol derivado: no hay excepcion
    return undef unless sin_lastmod($b) eq sin_lastmod($servido);
    return sprintf('identico salvo <lastmod> (repo %s / servido %s)',
                   fechas_lastmod($b), fechas_lastmod($servido));
}

# =============================================================================
#  5-quater · UN ASSET SELLADO CON ?v= Y EL CACHE DEL CDN EN LA URL DESNUDA
# =============================================================================
#  Medido el 25-ago-2026 en site-a.example. G11 daba DISTINTO en styles.css
#  (repo 86dcf007 / servido 7f5b0a00) y el sitio estaba PERFECTO:
#    · el HTML del arbol enlaza  /styles.css?v=86dcf007  (el sello de 12.17.2)
#    · esa URL sirve 86dcf007 en 5 de 5 peticiones
#    · la URL DESNUDA /styles.css sirve una copia vieja del CDN, y NINGUNA
#      pagina la enlaza
#  G11 pedia la URL desnuda, que es exactamente la que el sello existe para no
#  usar. Un gate que se pone rojo en cada despliegue por algo que ningun
#  visitante puede ver es un gate que alguien acaba apagando.
#
#  🔴 LO QUE **NO** SE HACE: inventarse la URL sellada. El sello se LEE del HTML
#  del propio arbol. Si ninguna pagina sella ese fichero, no hay excepcion y el
#  DISTINTO se queda tal cual. Fabricar la URL seria medir mi hipotesis en vez
#  del hecho, que es la trampa de siempre.
#
#  Y si dos paginas lo sellan con valores DISTINTOS, tampoco hay excepcion: eso
#  no es un cache viejo, es un arbol incoherente, y taparlo seria peor.
sub sello_en_html {
    my ($repo, $rel, $manifiesto) = @_;
    return undef if $rel =~ /[.]html?$/i;      # el sello es para ASSETS, no para paginas
    my $q = quotemeta $rel;
    my %sellos;
    for my $f (@$manifiesto) {
        my $h = $f->[0];
        next unless $h =~ /[.]html$/i;
        open my $fh, '<:raw', "$repo/$h" or next;
        local $/;
        my $t = <$fh>;
        close $fh;
        next unless defined $t;
        while ($t =~ m{["'](?:[.]?/)?$q[?](v=[A-Za-z0-9._-]{1,64})["']}g) { $sellos{$1} = 1 }
    }
    my @s = sort keys %sellos;
    return undef unless @s == 1;
    return $s[0];
}

sub servido {
    my (%o) = @_;
    my $repo = norm_ruta($o{repo});
    my ($R, $err) = lee_recibo($o{recibo} // "$repo/.qa-recibo");
    return (2, [ $err ]) if $err;
    my $base = $o{sitio} || $R->{SITIO} || '';
    return (2, [ 'no se de que URL bajar: falta SITIO en el recibo' ]) unless $base;

    my $max = $o{max} || 400;
    my (@mal, @nohay, @ok, @solo_fecha, @transformadas, @sellados);
    my (%codigos, $bloqueados, $ausentes);
    $bloqueados = $ausentes = 0;
    my $n = 0;
    for my $f (@{ $R->{_manifiesto} }) {
        my ($rel, $md5) = @$f;
        last if $n >= $max;
        $n++;
        my $hallado = 0;
        my $ultimo  = '';
        my $ucode   = 0;
        for my $u (urls_candidatas($base, $rel)) {
            my ($b, $code, $hdr) = baja($u, $o{cache});
            $ultimo = "$u -> $code";
            $ucode  = $code;
            next unless defined $b && $code == 200;
            if (md5_hex($b) eq $md5) { push @ok, $rel; $hallado = 1; last; }
            # unica excepcion, y NO es silenciosa: se cuenta y se imprime
            my $nota = es_sitemap($rel) ? igual_salvo_lastmod($repo, $rel, $md5, $b) : undef;
            if (defined $nota) {
                push @ok, $rel;
                push @solo_fecha, "$rel  ·  $nota";
                $hallado = 1;
                last;
            }
            # 🔴 ¿es un CDN transformando una imagen, o es un fichero mal
            # subido? Se ven igual —un md5 que no casa— y no son lo mismo.
            # 🔴 ¿lo enlaza el HTML con un sello ?v=? Entonces la URL desnuda que
            # acabo de pedir no la usa ningun visitante: hay que pedir LA SELLADA,
            # que es la unica que existe para el navegador. Ver 5-quater.
            my $sello = sello_en_html($repo, $rel, $R->{_manifiesto});
            if (defined $sello) {
                my ($bs, $cs) = baja("$u?$sello", $o{cache});
                if (defined $bs && $cs == 200 && md5_hex($bs) eq $md5) {
                    push @ok, $rel;
                    push @sellados, sprintf('%s  ·  la URL sellada (?%s) sirve %s; la desnuda tiene cache viejo (%s) y no la enlaza nadie',
                                            $rel, $sello, substr($md5, 0, 8), substr(md5_hex($b), 0, 8));
                    $hallado = 1;
                    last;
                }
            }
            my $tr = cdn_transforma($rel, $b, $hdr);
            if (defined $tr) {
                push @transformadas, "$rel  ·  $tr";
                $hallado = 1;
                last;
            }
            $ultimo = sprintf('%s -> 200 pero md5 distinto (repo %s / servido %s)',
                              $u, substr($md5, 0, 8), substr(md5_hex($b), 0, 8));
            $ucode  = 200;
        }
        next if $hallado;
        if ($ultimo =~ /md5 distinto/) { push @mal,   "$rel  ·  $ultimo" }
        else {
            push @nohay, "$rel  ·  $ultimo";
            $codigos{$ucode}++;
            # 🔴 «No lo encuentro» y «me lo han negado» NO son lo mismo, y hasta
            #    hoy caian en el mismo saco. Un 404 puede significar que ese
            #    fichero no se sube; un 403/429/000 significa que el gate no ha
            #    podido MEDIR, y eso nunca es informacion sobre la web.
            if ($ucode == 0 || $ucode == 401 || $ucode == 403 || $ucode == 407
                || $ucode == 408 || $ucode == 429 || ($ucode >= 500 && $ucode <= 599)) {
                $bloqueados++;
            } else { $ausentes++ }
        }
    }

    # ═════════════════════════════════════════════════════════════════════════
    #  🔴 G11 TAMBIEN MIRA LOS RECEPTORES (11-ago-2026)
    # ═════════════════════════════════════════════════════════════════════════
    #  Hasta hoy G11 solo miraba el arbol, asi que la captacion de cuatro webs
    #  quedaba fuera de la unica pregunta que se hace DESPUES de subir.
    #
    #  🔴 LO QUE HTTP **NO** PUEDE CONTESTAR, DICHO ANTES DE EMPEZAR: el md5.
    #  Un `.php` en produccion se EJECUTA; lo que vuelve es su salida, no su
    #  codigo. Si volviera su codigo tendriamos una fuga de fuente, no una
    #  comprobacion. El md5 contra el disco lo hace `subir.sh` por SSH, que es
    #  el unico que puede, y lo hace fichero a fichero al subirlos.
    #
    #  LO QUE SI CONTESTA, y son tres averias reales, no un adorno:
    #    · 5xx  -> el receptor esta ROTO. Es el modo de fallo que mas duele y el
    #             mas invisible: el visitante ve un error y a nosotros no nos
    #             llega nada. Un lead perdido no deja rastro en ningun sitio.
    #    · `<?php` en el cuerpo -> el PHP NO SE ESTA EJECUTANDO y el servidor
    #             sirve el fuente. Ahi dentro va la ruta del SMTP y la del
    #             buzon. Es un incidente, no un aviso.
    #    · un no-PHP (.htaccess) que responde 200 con cuerpo -> se esta sirviendo
    #             la configuracion del sitio.
    #  Un 403, un 404 o un 405 NO son fallo: `check-smtp.php` da 404 a proposito
    #  y `GET /contact.php` da 405 (solo acepta POST). Se imprime el codigo y se
    #  deja que lo lea quien sepa que espera cada uno.
    my (@rec_mal, @rec_ok);
    for my $r (receptores_del_recibo($R)) {
        my $u = $base;
        $u =~ s{/+$}{};
        $u .= '/' . $r->{prod};
        my ($b, $code, undef) = baja($u, undef);   # sin cache: el receptor cambia al subir
        $b = '' unless defined $b;
        my $es_php = ($r->{prod} =~ /\.php$/i) ? 1 : 0;
        if ($code >= 500 && $code <= 599) {
            push @rec_mal, "$r->{prod}  ·  $code · el receptor esta ROTO (los leads se pierden en silencio)";
        } elsif ($code == 200 && $b =~ /<\?php/) {
            push @rec_mal, "$r->{prod}  ·  200 y el cuerpo lleva '<?php' · SIRVE EL CODIGO FUENTE";
        } elsif (!$es_php && $code == 200 && length($b)) {
            push @rec_mal, "$r->{prod}  ·  200 con cuerpo · esto NO se debe servir por web";
        } else {
            push @rec_ok, sprintf('%s  ·  %d%s', $r->{prod}, $code,
                                  ($es_php ? ' · md5 no comprobable por HTTP (lo hace subir.sh por SSH)' : ''));
        }
    }

    # Lo transformado por el CDN se ha bajado y se ha mirado, asi que cuenta
    # como intento; lo que NO hace es contar como verificado (no entra en @ok).
    my $comparados = scalar(@ok) + scalar(@mal) + scalar(@transformadas);
    # =====================================================================
    #  🔴 EL GATE SE MIDE A SI MISMO ANTES DE OPINAR DE LA WEB
    # =====================================================================
    #  Hasta hoy, «0 comparados y 95 no hallados» salia por pantalla con un
    #  aviso y **exit 0**: el gate no habia mirado nada y el que lo lanzo se
    #  llevaba un aprobado. Un gate que no ha comparado ni un fichero no esta
    #  diciendo que la web este bien ni que este mal: esta diciendo que EL no
    #  funciona, y eso no puede volver a salir como cualquier otra cosa.
    #  Ninguna de estas dos reglas apaga un fallo verdadero: un md5 distinto
    #  gana siempre (FALLA), y lo que antes era exit 0 aqui pasa a exit 2.
    #  El «== 0» cubre tambien el manifiesto vacio: un G11 que no tenia nada que
    #  pedir tampoco ha comprobado nada, y salir en verde de ahi es la misma
    #  mentira con menos ficheros.
    # Un receptor roto pesa lo mismo que un fichero del arbol distinto: las dos
    # cosas significan que produccion no esta sirviendo lo que se aprobo.
    #  🔴 Y si lo unico que se ha podido mirar son imagenes que el CDN
    #  transforma, NO hay verde: no se ha verificado ni un fichero. Es la misma
    #  regla del «0 comparados» de arriba, con otro disfraz.
    my $veredicto = (@mal || @rec_mal)                ? 'FALLA'
                  : ($comparados == 0)                ? 'GATE-ROTO'
                  : (!@ok && @transformadas)          ? 'COBERTURA'
                  : ($bloqueados > $comparados)       ? 'COBERTURA'
                  : @nohay                            ? 'INCOMPLETO'
                  :                                     'PASA';

    my %diag = (
        intentados => $n, comparados => $comparados,
        bloqueados => $bloqueados, ausentes => $ausentes,
        codigos => \%codigos, solo_fecha => \@solo_fecha, transformadas => \@transformadas,
        sellados => \@sellados,
        arbol => scalar @{ $R->{_manifiesto} }, veredicto => $veredicto,
        rec_mal => \@rec_mal, rec_ok => \@rec_ok,
    );
    return (((@mal || @rec_mal) ? 1 : 0), \@mal, \@nohay, \@ok, $R, \%diag);
}

# =============================================================================
#  6 · HISTORIAL — lo unico que un recibo suelto no puede ver
# =============================================================================
#  Un recibo sabe de su web. El historial sabe de las CINCO: que web hace meses
#  que no pasa por el gate, cual despliega siempre con cosas sin mirar, cual
#  arreglo algo que las otras cuatro siguen teniendo. Esa es la deriva que el
#  encargo pide hacer visible sin que nadie tenga que acordarse de mirar.
#  Append-only, TSV, sin dependencias.
# =============================================================================
sub historial {
    my (%a) = @_;
    make_path($CENTRAL) unless -d $CENTRAL;
    my $f = "$CENTRAL/history.tsv";
    my $nuevo = !-f $f;
    # 🔴 La cabecera solo se escribia al crear el fichero, asi que anadir una
    #  columna dejaba un TSV cuya PRIMERA LINEA MIENTE: 7 nombres para filas de
    #  8 campos. Un lector por indice no se entera y uno por nombre se equivoca
    #  callado. Se migra una vez, y solo si hace falta. Las filas viejas se
    #  quedan con 7 campos a proposito: no se inventa lo que no se guardo.
    if (!$nuevo) {
        open my $r, '<:raw', $f or return;
        my $cab = <$r>;
        if (defined $cab && $cab !~ /ids_fallo/) {
            local $/; my $resto = <$r>; close $r;
            $cab =~ s/\r?\n\z//;
            open my $w, '>:raw', $f or return;
            print $w "$cab\tids_fallo\n", (defined $resto ? $resto : '');
            close $w;
        } else { close $r }
    }
    open my $fh, '>>:raw', $f or return;
    # 🔴 18-ago-2026 · `ids_fallo` se anade AL FINAL a proposito: es un TSV
    #  append-only y las 1.257 lineas viejas tienen 7 campos. Asi las viejas se
    #  siguen leyendo y las nuevas dicen QUE fallo, que es lo que faltaba: 727
    #  lineas con veredicto FALLA y ni una que nombre al check que acuso.
    print $fh "fecha\tsitio\taccion\tveredicto\tarbol_hash\tno_verificado\tnota\tids_fallo\n" if $nuevo;
    printf $fh "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        strftime('%Y-%m-%dT%H:%M:%S', localtime),
        ($a{sitio} // ''), ($a{accion} // ''), ($a{veredicto} // ''),
        ($a{hash} // ''), (defined $a{nv} ? $a{nv} : ''), ($a{nota} // ''),
        ($a{ids} // '');
    close $fh;
}

# =============================================================================
#  7 · CLI  (modulino: si alguien hace `require`, no se ejecuta nada)
# =============================================================================
sub main {
    my %opt = (horas => 12, max => 400);
    my $modo = '';
    my @a = @ARGV;

    # English aliases. Additive: the internal option keys stay as they are,
    # because they double as mode names ($modo = $1). Both spellings work.
    my %ALIAS = (
        '--write' => '--escribir', '--verify'  => '--verificar',
        '--served'=> '--servido',  '--tree'    => '--arbol',
        '--history'=>'--historial','--record'  => '--anotar',
        '--for-deploy' => '--para-desplegar',
        '--list'  => '--listar',   '--site'    => '--sitio',
        '--out'   => '--salida',   '--receipt' => '--recibo',
        '--hours' => '--horas',    '--instrument' => '--instrumento',
    );
    @a = map { $ALIAS{$_} // $_ } @a;

    while (@a) {
        my $x = shift @a;
        if    ($x =~ /^--(escribir|verificar|servido|arbol|historial)$/) { $modo = $1 }
        elsif ($x eq '--anotar') { $modo = 'anotar'; $opt{anotar} = shift @a }
        elsif ($x eq '--para-desplegar') { $opt{para_desplegar} = 1 }
        elsif ($x eq '--listar')         { $opt{listar} = 1 }
        elsif ($x =~ /^--(repo|sitio|json|salida|recibo|cache|horas|max|anotar|instrumento)$/) {
            $opt{$1} = shift @a;
        }
        elsif ($x eq '-h' || $x eq '--help') { $modo = 'ayuda' }
        else { print "opcion no reconocida: $x\n"; return 2 }
    }

    if (!$modo || $modo eq 'ayuda') {
        open my $fh, '<:encoding(UTF-8)', __FILE__ or return 2;
        while (my $l = <$fh>) { last if $l !~ /^#/ && $l !~ /^\s*$/; print $l if $l =~ /^#/ }
        close $fh;
        return 2;
    }

    if ($modo eq 'historial') {
        my $f = "$CENTRAL/history.tsv";
        unless (-f $f) { print "todavia no hay historial en $f\n"; return 0 }
        open my $fh, '<:encoding(UTF-8)', $f or return 2;
        while (my $l = <$fh>) {
            next if $opt{sitio} && $l !~ /\Q$opt{sitio}\E/ && $l !~ /^fecha\t/;
            print $l;
        }
        close $fh;
        return 0;
    }

    unless ($opt{repo} && -d $opt{repo}) {
        print "FALTA --repo (o no es un directorio): " . ($opt{repo} // '(nada)') . "\n";
        return 2;
    }

    # Deja constancia de algo que no es ni un QA ni una comprobacion de lo
    # servido: sobre todo, de una subida que FALLO. Sin esta linea, en el
    # historial una subida rota y una subida que nunca se intento se ven igual.
    if ($modo eq 'anotar') {
        my ($R) = lee_recibo("$opt{repo}/.qa-recibo");
        historial(sitio => ($R ? ($R->{SITIO} // '') : ''), accion => 'NOTA',
                  veredicto => '', hash => ($R ? ($R->{'ARBOL-HASH'} // '') : ''),
                  nv => '', nota => solo_ascii($opt{anotar} // ''));
        print "anotado en $CENTRAL/history.tsv\n";
        return 0;
    }

    if ($modo eq 'arbol') {
        my ($man, $hash) = arbol($opt{repo});
        my $bytes = 0; $bytes += $_->[2] for @$man;
        printf "ARBOL-HASH   %s\n", $hash;
        printf "FICHEROS     %d\n", scalar @$man;
        printf "BYTES        %d\n", $bytes;
        if ($opt{listar}) {
            printf "%s  %9d  %s\n", substr($_->[1], 0, 8), $_->[2], $_->[0] for @$man;
        } else {
            printf "\n(--listar para ver los %d ficheros que se consideran desplegables)\n",
                   scalar @$man;
        }
        # ── LO QUE NADIE HABIA MIRADO NUNCA ─────────────────────────────────
        # Que es «el arbol desplegable» de cada web no estaba escrito en ningun
        # sitio salvo en PROSA y en un solo repo (site-b-web/CLAUDE.md). La
        # primera vez que se corre esto sale a la cara: climentmedia daba 192
        # ficheros y 138 MB, con prototipos de imagenes de LinkedIn dentro.
        # No lo adivino: lo enseño y que lo decida quien sepa.
        my @gordos = sort { $b->[2] <=> $a->[2] } grep { $_->[2] > 1_000_000 } @$man;
        if (@gordos) {
            printf "\n  ⚠ %d ficheros pesan mas de 1 MB (%.1f MB en total del arbol).\n",
                   scalar @gordos, $bytes / 1048576;
            printf "    %8.1f MB  %s\n", $_->[2] / 1048576, $_->[0]
                for @gordos[0 .. ($#gordos > 4 ? 4 : $#gordos)];
            print  "    Si algo de esto NO se sube, declararlo en <repo>/.qa-arbol:\n";
            print  "        EXCLUIR: downloads/posts/**\n";
            print  "    Mientras no se declare, el hash cubre cosas que no se despliegan\n";
            print  "    y el gate dara rojos que no son rojos —que es como muere un gate.\n";
        }
        return 0;
    }

    if ($modo eq 'escribir') {
        my %d;
        if ($opt{json} && -f $opt{json}) {
            %d = %{ lee_json_qa($opt{json}) };
        } else {
            print "FALTA --json con la salida de qa-master.pl --json\n";
            print "🔴 Sin el, el recibo diria «verde» sin que nadie haya medido nada.\n";
            return 2;
        }
        # ⚠️ %d PRIMERO y las opciones DESPUES. Al reves, %d lleva su propio
        #    `sitio` y pisaba silenciosamente al `--sitio` de la linea de
        #    ordenes: el recibo salia apuntando a otra URL sin decir nada.
        my $r = escribe_recibo(%d,
                               repo   => $opt{repo},
                               sitio  => ($opt{sitio} // $d{sitio}),
                               salida => $opt{salida}, horas => $opt{horas},
                               instrumento => ($opt{instrumento} // $d{instrumento}));
        printf "RECIBO escrito: %s\n", $r->{salida};
        printf "  arbol %s · %d ficheros · estandar %s · veredicto %s\n",
               $r->{hash}, $r->{ficheros}, $r->{estandar}, ($d{veredicto} // '?');
        return 0;
    }

    if ($modo eq 'verificar') {
        my ($ok, $mal, $R) = verifica(repo => $opt{repo}, recibo => $opt{recibo},
                                      horas => $opt{horas},
                                      para_desplegar => $opt{para_desplegar});
        if ($ok) {
            printf "RECIBO VALIDO · %s · %s · arbol %s\n",
                   ($R->{SITIO} // '?'), ($R->{FECHA} // '?'), ($R->{'ARBOL-HASH'} // '?');
            printf "  veredicto %s · sin mirar %s\n",
                   ($R->{VEREDICTO} // '?'), ($R->{'NO-VERIFICADO'} // '?');
            imprime_alcance($R);
            imprime_medido_contra($R);
            imprime_aceptados($R);
            # ⚠️ Los NV que lo son POR MEDIR EL CANDIDATO ya se han explicado
            #    arriba, y repetirlos aqui como «no las ha mirado nadie» es
            #    contradecirse en dos lineas. Un informe que se contradice se
            #    cree por la linea mas comoda, que aqui seria la de ignorarlo.
            if (($R->{'NO-VERIFICADO'} // 0) > 0) {
                my %cand = map { $_ => 1 } nv_por_candidato($R);
                my @reales = grep { !$cand{$_} } split /\s+/, ($R->{'SIN-MIRAR'} // '');
                @reales = grep { $_ ne '' } @reales;
                if (@reales) {
                    printf "  ⚠ NO VERIFICADO NO ES UN APROBADO. %d comprobacion%s no las ha mirado nadie:\n",
                           scalar(@reales), (@reales == 1 ? '' : 'es');
                    print "    " . join(' ', @reales) . "\n";
                } elsif (!%cand) {
                    print "  ⚠ NO VERIFICADO NO ES UN APROBADO. " . $R->{'NO-VERIFICADO'}
                        . " comprobaciones no las ha mirado nadie:\n";
                    print "    " . ($R->{'SIN-MIRAR'} // '(el recibo no las lista)') . "\n";
                }
            }
            return 0;
        }
        print "RECIBO NO VALIDO\n";
        print "  · $_\n" for @$mal;
        return 1;
    }

    if ($modo eq 'servido') {
        my ($rc, $mal, $nohay, $ok, $R, $D) = servido(repo => $opt{repo}, sitio => $opt{sitio},
                                                  recibo => $opt{recibo}, cache => $opt{cache},
                                                  max => $opt{max});
        if ($rc == 2 || !$D) { print "no se pudo correr: $_\n" for @$mal; return 2 }
        my $cods = join(' · ', map { "$_ x$D->{codigos}{$_}" }
                               sort { $D->{codigos}{$b} <=> $D->{codigos}{$a} || $a <=> $b }
                               keys %{ $D->{codigos} });
        printf "G11 · lo servido frente al recibo · %s\n", ($R->{SITIO} // '?');
        printf "  pedidos %d de los %d ficheros del arbol · COMPARADOS %d\n",
               $D->{intentados}, $D->{arbol}, $D->{comparados};
        printf "  transformados por un CDN, NO verificados: %d\n", scalar @{ $D->{transformadas} }
               if @{ $D->{transformadas} || [] };
        printf "  identicos %d · distintos %d · no hallados %d (negados %d · ausentes %d)\n",
               scalar @$ok, scalar @$mal, scalar @$nohay, $D->{bloqueados}, $D->{ausentes};
        printf "  codigos de lo no hallado: %s\n", $cods if $cods ne '';
        print "  DISTINTO  $_\n" for @$mal;
        print "  IGUAL-SALVO-FECHA  $_\n" for @{ $D->{solo_fecha} };
        # SI estan verificados: se ha comparado el md5 de la URL que el HTML
        # enlaza de verdad. Se imprime igual porque taparlo escondería el dia en
        # que el sello deje de emitirse y todo el mundo vuelva a la URL desnuda.
        print "  SELLADO-OK  $_\n" for @{ $D->{sellados} || [] };
        # 🔴 Su propio bloque, y con el hueco dicho. No son OK: son imagenes que
        #    un CDN reescribe, asi que su md5 NO se ha comprobado ni se puede.
        if (@{ $D->{transformadas} || [] }) {
            print "  CDN-NO-VERIFICADO  $_\n" for @{ $D->{transformadas} };
            print "  ⚠ Esas NO estan verificadas: el CDN las reescribe -recomprime los PNG y\n";
            print "    redimensiona los JPEG- y borra su Last-Modified, asi que por HTTP no hay\n";
            print "    forma de saber si son las nuevas.\n";
            print "    LO QUE NO SE VE AQUI: una imagen que no se haya subido y cuya version\n";
            print "    vieja siga sirviendose. Eso lo contesta el md5 contra el disco por SSH.\n";
            print "    Y si algun dia salen como DISTINTO en vez de aqui, es que ya no hay CDN\n";
            print "    delante: entonces SI es un defecto.\n";
        }
        # ── los receptores, en su propio bloque ────────────────────────────
        if (@{ $D->{rec_ok} } || @{ $D->{rec_mal} }) {
            printf "  receptores: %d bien · %d mal\n",
                   scalar @{ $D->{rec_ok} }, scalar @{ $D->{rec_mal} };
            print "  RECEPTOR-MAL  $_\n" for @{ $D->{rec_mal} };
            print "  receptor      $_\n" for @{ $D->{rec_ok} };
        }
        print "  NO HALLADO $_\n" for @$nohay[0 .. ($#$nohay > 9 ? 9 : $#$nohay)];
        print "  ... y " . (@$nohay - 10) . " no hallados mas\n" if @$nohay > 10;
        historial(sitio => ($R->{SITIO} // ''), accion => 'SERVIDO',
                  veredicto => $D->{veredicto},
                  hash => ($R->{'ARBOL-HASH'} // ''), nv => '',
                  # ASCII puro: historial() escribe en :raw, y un «·» sale como
                  # mojibake en el TSV. Ya paso en la primera linea que escribi.
                  nota => sprintf('%d comparados de %d - %d ok / %d distintos / %d no hallados (%d negados)',
                                  $D->{comparados}, $D->{intentados}, scalar @$ok,
                                  scalar @$mal, scalar @$nohay, $D->{bloqueados}));
        if (@{ $D->{solo_fecha} }) {
            printf "\n  (%d sitemap identico salvo <lastmod>: lo estampa _gen.ps1 al generar.\n",
                   scalar @{ $D->{solo_fecha} };
            print  "   Se compara TODO lo demas byte a byte —quitar una URL sigue saltando.)\n";
        }
        if (@{ $D->{rec_mal} }) {
            print "\n🔴 UN RECEPTOR DE LEADS NO ESTA BIEN EN PRODUCCION.\n";
            print "   Esto no se nota mirando la web: las paginas se ven perfectas y el\n";
            print "   formulario se traga los envios. Mirarlo AHORA, no manana.\n";
            print "   Vuelta atras de un paso, sin tocar las paginas:\n";
            print "     ssh <host> \"cp -p ~/backups/<dominio>-<sello>.receptores/* <docroot>/\"\n";
            print "   (la copia la deja subir.sh en su paso 4-bis, con el sello del despliegue)\n";
            return 1 unless @$mal;   # si ademas falla el arbol, se dice lo de abajo tambien
        }
        if (@$mal) {
            print "\n🔴 PRODUCCION NO SIRVE LO QUE SE MIDIO. Todos los gates verdes de\n";
            print "   arriba hablan de un arbol que el visitante no esta viendo.\n";
            if ($D->{comparados} < $D->{intentados} / 2) {
                printf "   ⚠ Y ademas solo he podido comparar %d de %d: hay mas fallos posibles sin mirar.\n",
                       $D->{comparados}, $D->{intentados};
            }
            return 1;
        }
        # ── 🔴 el gate se declara roto ANTES de dejar pasar nada ────────────
        if ($D->{veredicto} eq 'GATE-ROTO') {
            printf "\n🔴 G11 NO HA COMPARADO NI UN FICHERO (0 de %d). ESTO ES UN FALLO DEL GATE.\n",
                   $D->{intentados};
            print  "   No dice que la web este bien ni que este mal: dice que no se ha medido.\n";
            print  "   «N de N no hallado» NUNCA es un aprobado —hasta hoy salia con exit 0—.\n";
            printf "   Codigos: %s\n", ($cods ne '' ? $cods : '(ninguno)');
            print  "   Donde mirar, por orden:\n";
            print  "     1 · las cabeceras de baja() — el WAF de site-b da 403 a la huella\n";
            print  "         de curl (Accept: */* + Accept-Encoding al final). Se manda Accept.\n";
            print  "     2 · el mapeo ruta->URL de urls_candidatas() para esta web\n";
            printf "     3 · SITIO: %s  ¿es la URL que sirve el arbol?\n", ($R->{SITIO} // '?');
            return 2;
        }
        if ($D->{veredicto} eq 'COBERTURA') {
            printf "\n🔴 COBERTURA NO FIABLE: me han NEGADO %d peticiones y solo he comparado %d.\n",
                   $D->{bloqueados}, $D->{comparados};
            print  "   Mas rechazos que medidas = el problema es el gate, no la web.\n";
            printf "   Codigos: %s\n", ($cods ne '' ? $cods : '(ninguno)');
            print  "   NO VERIFICADO no es un aprobado: esto sale en 2, no en 0.\n";
            return 2;
        }
        if (@$nohay) {
            print "\n⚠ Hay ficheros del arbol servidos que NO he encontrado, y eso NO es un aprobado.\n";
            print "   O no estan subidos, o el mapeo ruta->URL de esta web no es el que supongo.\n";
            print "   Mirarlo antes de darlo por bueno.\n";
        }
        return 0;
    }
    return 2;
}

# Lector minimo del JSON de qa-maestro. Usa JSON::PP si esta (viene con perl).
sub lee_json_qa {
    my ($f) = @_;
    require JSON::PP;
    open my $fh, '<:raw', $f or die "no puedo leer $f: $!\n";
    local $/; my $t = <$fh>; close $fh;
    my $j = JSON::PP->new->utf8->decode($t);
    my %lentes;
    my %nfallo;
    my @nv;
    my @fallo;
    # 🔴 13-ago-2026 · TRES estados por lente, no dos (trampa §18). Aqui se
    #    arrancaba en 'PASA' y solo se bajaba a 'FALLA': una lente cuyas
    #    comprobaciones fueran TODAS NO VERIFICADO quedaba sellada «PASA», y
    #    `--para-desplegar` acepta cualquier lente que diga PASA o FALLA.
    #    Se lleva la cuenta de cuantas midieron ALGO: si ninguna, no es PASA.
    my %midio;
    for my $c (@{ $j->{comprobaciones} || [] }) {
        my $l = $c->{lente} // 'OTRA';
        $lentes{$l} //= 'PASA';
        $midio{$l}++ if ($c->{estado} // '') ne 'NV';
        # 🔴 18-ago-2026 · AQUI SE TIRABA EL NOMBRE DEL QUE ACUSA.
        #  Del FALLO se guardaba un CONTADOR y del NV el ID. Efecto medido:
        #  727 lineas del historial con veredicto FALLA y CERO que digan QUE
        #  check fallo. Por eso nadie pudo notar nunca que la mayoria de las
        #  acusaciones eran falsas: el registro no guarda al acusador. Sin esto
        #  no se puede medir la precision de un gate, y sin medir la precision
        #  el instrumento solo puede crecer.
        if (($c->{estado} // '') eq 'FALLO') { $lentes{$l} = 'FALLA'; $nfallo{$l}++; push @fallo, ($c->{id} // '?') }
        if (($c->{estado} // '') eq 'NV') { push @nv, ($c->{id} // '?') }
    }
    for my $l (keys %lentes) {
        $lentes{$l} = 'NO VERIFICADA' if $lentes{$l} eq 'PASA' && !$midio{$l};
    }
    # ── 🔴 EL ALCANCE, EN LA FORMA EN QUE LO ESCRIBE EL JSON ────────────────
    #  Aqui ponia `alcance => $j->{alcance}`, y eran DOS FORMAS DISTINTAS de la
    #  misma clave: qa-maestro le pasa a escribe_recibo() un { LENTE => [urls] },
    #  pero en el JSON escribe { sitio_urls, lista_urls, documentos, por_lente }.
    #  Resultado, comprobado el 11-ago con site-a.json: un recibo escrito por la
    #  via `receipt.pl --escribir --json` salia con **ALCANCE-URLS: 0** y las
    #  cinco lentes en «NO CORRIDA» teniendo el JSON las 12 URLs delante.
    #  No fallaba: rellenaba el hueco con ceros, que es la unica forma de error
    #  que no se ve. Y con el gate de alcance, ese cero ahora ademas bloquearia
    #  un despliegue legitimo —un falso rojo nacido de un desajuste interno—.
    #  Se aceptan las dos formas: la nueva (por_lente) y la plana, por si un
    #  JSON viejo o de otra herramienta llega con { LENTE => [urls] }.
    my $ja = $j->{alcance};
    my ($alc, $sitio_urls, $lista_urls, $documentos);
    if (ref $ja eq 'HASH') {
        if (ref $ja->{por_lente} eq 'HASH') {
            $alc = { map { $_ => ($ja->{por_lente}{$_}{urls} || []) }
                     grep { ref $ja->{por_lente}{$_} eq 'HASH' }
                     keys %{ $ja->{por_lente} } };
            $sitio_urls = $ja->{sitio_urls};
            $lista_urls = $ja->{lista_urls};
            $documentos = $ja->{documentos};
        } else {
            $alc = $ja;
        }
    }

    return {
        sitio     => $j->{sitio},
        veredicto => $j->{veredicto},
        # contra que se midio. Si el JSON es viejo y no lo trae, escribe_recibo
        # pone PRODUCCION, que es lo que eran todos antes del 11-ago-2026.
        medido_contra => $j->{medido_contra},
        medido_en     => $j->{medido_en},
        nv_candidato  => $j->{nv_por_candidato},
        # si el JSON lo trae, el recibo lo estampa; si no, dira NO DECLARADO
        alcance     => $alc,
        alcance_sitio      => $sitio_urls,
        alcance_lista      => $lista_urls,
        alcance_documentos => $documentos,
        # el JSON guarda el DOM bajo `instrumento`, no en una clave propia: se
        # reconstruye igual que lo manda qa-maestro en la via directa, para que
        # las dos vias escriban EL MISMO recibo (el SELLO cubre esta linea).
        alcance_dom => ($j->{alcance_dom}
                        // ($j->{instrumento}{dom}
                            ? $j->{instrumento}{dom} . ' (innerWidth='
                              . ($j->{instrumento}{innerWidth} // '?') . ')'
                            : undef)),
        lentes    => \%lentes,
        fallo     => $j->{resumen}{fallo},
        aviso     => $j->{resumen}{aviso},
        nv        => $j->{resumen}{no_verificado},
        pasa      => $j->{resumen}{pasa},
        nv_ids    => \@nv,
        fallo_ids => \@fallo,
        # Las dos vias —qa-maestro directo y `receipt.pl --escribir --json`—
        # tienen que escribir EL MISMO recibo: el SELLO cubre estas lineas, y un
        # recibo que segun por donde se escriba lleva o no lleva los aceptados
        # es el desajuste interno que ya nos costo un ALCANCE-URLS: 0.
        aceptados            => ($j->{aceptados} || []),
        aceptados_rechazados => scalar(@{ $j->{aceptados_rechazados} || [] }),
        aceptados_aviso_dias => 14,
        instrumento => 'perl ' . ($j->{instrumento}{perl} // $])
                     . ($j->{instrumento}{dom} ? ' · DOM ' . $j->{instrumento}{dom} : ' · sin DOM'),
    };
}

exit(main()) unless caller;
1;
