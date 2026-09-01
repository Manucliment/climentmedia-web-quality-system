#!/usr/bin/perl
# =============================================================================
#  roles.pl — el vocabulario de roles, y las plantillas por TIPO de pagina
# =============================================================================
#  DOS MODOS
#    --gate         comprueba que roles.tsv, anatomy.tsv, los moldes y 09 §1
#                   dicen lo mismo. Sale 1 si no.
#    --plantillas   regenera blueprint/moulds/types/<tipo>.html, una hoja de
#                   montaje por cada tipo de anatomy.tsv.
#
#  🔴 POR QUE LA PLANTILLA NO LLEVA EL MARKUP DEL MOLDE DENTRO
#  Porque seria una SEGUNDA COPIA de cada molde, y este repositorio ya borro una
#  tabla por eso mismo: 10 §6 tenia una composicion por tipo escrita a mano que
#  discrepaba de las anatomias en cuatro filas, y «una pregunta con dos
#  respuestas es peor que una sin respuesta». Copiar el markup aqui seria el
#  mismo error con otra ropa — y peor, porque el dia que se arregle un molde la
#  plantilla seguiria ensenando el defecto.
#  La plantilla ENSAMBLA y APUNTA: el orden de los roles sale de anatomy.tsv, el
#  molde de cada rol sale de roles.tsv, y el «cuando / cuando no» se extrae del
#  molde EN CADA REGENERACION. Cero copias, y no puede divergir.
#
#  🔑 Y por eso se puede dar la plantilla por tipo que 10 §6 nego: lo que aquel
#  documento prohibio fue una segunda tabla ESCRITA A MANO. Una DERIVADA de las
#  dos fuentes que ya existen no es una segunda respuesta a la pregunta: es la
#  misma respuesta, montada.
use strict; use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);

my $DIR = dirname($0);
my $TSV_R = "$DIR/roles.tsv";
my $TSV_A = "$DIR/anatomy.tsv";
my $MOLDES = "$DIR/../blueprint/moulds";
my $DEST   = "$MOLDES/types";
my $MD     = "$DIR/../blueprint/09-page-types.md";
my $MD10   = "$DIR/../blueprint/10-layout-vocabulary.md";

my @MAL;
sub mal { push @MAL, $_[0] }
sub slurp { my $f = shift; open my $h, '<:raw', $f or return undef;
            local $/; my $t = <$h>; close $h; return $t }

# --- carga -------------------------------------------------------------------
sub filas {
    my ($f, $campos) = @_;
    my $t = slurp($f); die "no puedo leer $f\n" unless defined $t;
    my @r;
    for my $l (split /\n/, $t) {
        next if $l =~ /^\s*#/ || $l !~ /\S/;
        my @c = split /\|/, $l, $campos;
        push @r, \@c;
    }
    die "$f: 0 filas. Un gate sobre una tabla vacia aprueba cualquier cosa.\n" unless @r;
    return @r;
}

my @ROLES = filas($TSV_R, 6);
my @TIPOS = filas($TSV_A, 6);

my (%ROL, @ORDEN_ROL);
for my $r (@ROLES) {
    my ($k, $en, $prim, $moldes, $trabajo, $nota) = @$r;
    $ROL{$k} = { en => $en, prim => $prim, trabajo => $trabajo, nota => ($nota // ""),
                 moldes => [ grep { length } split /\s+/, ($moldes // '') ] };
    push @ORDEN_ROL, $k;
}

# --- el «cuando» de cada molde, leido del molde ------------------------------
#  No se copia a mano en ningun sitio: se extrae aqui, en cada regeneracion.
#  🔴 El texto del molde VIENE ENVUELTO a ~76 columnas, asi que un patron que
#     para en el salto de linea corta la frase por la mitad. La primera version
#     de esta funcion escribio en las plantillas cosas como «la pastilla era»
#     y ahi se acababa: media regla, con pinta de regla entera. Se lee hasta la
#     linea en blanco o hasta la siguiente ETIQUETA EN MAYUSCULAS, que es como
#     estan estructuradas las cabeceras.
sub trozo {
    my ($t, $etiq) = @_;
    return undef unless $t =~ /^[ \t]*\Q$etiq\E:?[ \t]*(.*)$/m;
    my $desde = $-[0];
    my $resto = substr($t, $desde);
    $resto =~ s/^[^\n]*\Q$etiq\E:?[ \t]*//;
    # corta en la linea en blanco, en la siguiente etiqueta, o al cerrar el comentario
    my ($corte) = $resto =~ /\A(.*?)(?:\n[ \t]*\n|\n[ \t]*[A-Z\x{00C0}-\x{00DD}][A-Z\x{00C0}-\x{00DD} ]{3,}:|\n[ \t]*(?:⚠|🔑|⛔|🔴)|-->)/ms;
    $corte = $resto unless defined $corte;
    $corte =~ s/\s+/ /g; $corte =~ s/^\s+|\s+$//g;
    return undef unless length $corte;
    # Una plantilla es una hoja de referencia, no el molde: si la regla no cabe
    # en dos lineas se manda a leer el molde, que es donde vive entera.
    if (length($corte) > 240) { $corte = substr($corte, 0, 237) . '...'; }
    return $corte;
}
sub cuando_de {
    my ($molde) = @_;
    my $t = slurp("$MOLDES/$molde");
    return (undef, undef) unless defined $t;
    return (trozo($t, 'CUANDO'), trozo($t, 'CUANDO NO'));
}

# --- GATE --------------------------------------------------------------------
sub gate {
    # A · todo rol usado por una anatomia tiene que existir en el vocabulario.
    #     Es la arista que no existia: `anatomy.pl` reconcilia CONTANDO marcas,
    #     asi que un rol renombrado en un lado seguia cuadrando en el otro.
    my %usado;
    for my $t (@TIPOS) {
        my ($tipo, $obl, $cond) = @$t;
        for my $r (split(/\s+/, $obl // ''), split(/\s+/, $cond // '')) {
            next unless length $r;
            $usado{$r}++;
            mal("A · el tipo `$tipo` usa el rol `$r` y roles.tsv no lo tiene")
                unless $ROL{$r};
        }
    }
    # B · y al reves: un rol que no usa NINGUNA anatomia es vocabulario que
    #     nadie puede alcanzar. No se borra ni se ignora: se DECLARA con
    #     `SOLO-VOCABULARIO` y su motivo, igual que los tres roles sin molde.
    #     Un hueco declarado se cuenta; uno callado se olvida.
    #     🔴 Lo encontro este gate el dia que se escribio: `evidencia` y
    #     `contexto` llevaban en 09 §1 sin que ningun tipo los pidiera, asi que
    #     eran dos entradas del vocabulario que no aparecen en ninguna pagina.
    #     Meterlos en una anatomia cambia lo que TODOS los sitios estan
    #     obligados a llevar: es una decision de 09 §2, no de un gate.
    for my $k (@ORDEN_ROL) {
        next if $usado{$k};
        mal("B · el rol `$k` no lo usa ninguna anatomia y no esta declarado "
            . "`SOLO-VOCABULARIO` en roles.tsv: o entra en un tipo, o se declara")
            unless ($ROL{$k}{nota} // '') =~ /SOLO-VOCABULARIO/;
    }
    # C · el molde que se promete tiene que existir en el cajon.
    for my $k (@ORDEN_ROL) {
        for my $m (@{ $ROL{$k}{moldes} }) {
            mal("C · el rol `$k` apunta a `$m` y ese molde no esta en blueprint/moulds/")
                unless -f "$MOLDES/$m";
        }
    }
    # D · la fila del markdown y la de aqui tienen que decir lo mismo. Se compara
    #     el NOMBRE y la PRIMITIVA, que es justo lo que contar marcas no ve.
    my $md = slurp($MD);
    if (!defined $md) { mal("D · no encuentro $MD") }
    else {
        for my $k (@ORDEN_ROL) {
            my $en = $ROL{$k}{en};
            my ($fila) = $md =~ /^\|\s*`\Q$en\E`\s*\|([^\n]*)$/m;
            if (!defined $fila) { mal("D · 09 §1 no tiene fila para el rol `$en` (clave `$k`)"); next }
            my @c = split /\|/, $fila;
            my $prim_md = $c[1] // ''; $prim_md =~ s/\*//g; $prim_md =~ s/\s+/ /g;
            $prim_md =~ s/^\s+|\s+$//g;
            my $prim_ts = $ROL{$k}{prim};
            my $a = lc $prim_md; my $b = lc $prim_ts;
            $a =~ s/[^a-z ]//g; $b =~ s/[^a-z ]//g;
            $a =~ s/\bno mould yet\b/sin molde/; $b =~ s/\bsin molde\b/sin molde/;
            # El documento esta en ingles y la tabla de datos en castellano, asi
            # que «feature grid OR alternating pair» y «... O ...» son la misma
            # fila. Se normaliza la conjuncion; lo demas se compara literal.
            $a =~ s/ or / o /g; $b =~ s/ or / o /g;
            mal("D · el rol `$en`: 09 §1 dice primitiva «$prim_md» y roles.tsv dice «$prim_ts»")
                unless $a eq $b;
        }
    }
    # E · la cifra «11 de 14» se DERIVA. Estaba escrita a mano en DOS documentos.
    my $con = grep { @{ $ROL{$_}{moldes} } } @ORDEN_ROL;
    my $tot = scalar @ORDEN_ROL;
    for my $par (["09 §1", $md], ["10 §6", slurp($MD10)]) {
        my ($donde, $txt) = @$par;
        next unless defined $txt;
        while ($txt =~ /(\w+|\d+)\s+of\s+the\s+(\w+|\d+)\s+have a mould/gi) {
            my ($d, $t) = (num($1), num($2));
            mal("E · $donde dice «$1 of the $2 have a mould» y los datos dan $con de $tot")
                unless defined $d && defined $t && $d == $con && $t == $tot;
        }
        while ($txt =~ /Of the \*\*(\w+|\d+) roles\*\*, \*\*(\w+|\d+) have a mould/gi) {
            my ($t, $d) = (num($1), num($2));
            mal("E · $donde dice «$2 de $1 con molde» y los datos dan $con de $tot")
                unless defined $d && defined $t && $d == $con && $t == $tot;
        }
    }
    # G · TODO molde del cajon declara CUANDO y CUANDO NO.
    #     10 §4 promete que «cada molde lleva EN SU PROPIA CABECERA su cuando, su
    #     cuando no y su comportamiento a 390 px», y hasta hoy esa promesa no la
    #     comprobaba nadie: un molde nuevo podia entrar sin una linea de
    #     documentacion y la unica senal habria sido un hueco en la hoja de
    #     referencia, que nadie mira hasta que la necesita.
    #     Y este si es el sitio: la plantilla EXTRAE ese texto del molde, asi que
    #     un molde mudo produce una hoja peor sin que nada se ponga rojo.
    #     Documentar un asset para poder usarlo es el trabajo; que exista sin
    #     documentar es como se acaba reescribiendo desde cero en el proyecto
    #     siguiente, que es literalmente lo que dice la primera linea del indice
    #     de componentes.
    if (opendir(my $dh, $MOLDES)) {
        my @m = sort grep { /\.html$/ } readdir $dh;
        closedir $dh;
        mal("G · no hay ni un molde en $MOLDES: un barrido sobre un cajon vacio aprueba cualquier cosa")
            unless @m;
        for my $m (@m) {
            my $t = slurp("$MOLDES/$m") // '';
            mal("G · el molde `$m` no declara CUANDO: 10 §4 promete que todos lo llevan")
                unless $t =~ /^[ \t]*CUANDO:/m;
            mal("G · el molde `$m` no declara CUANDO NO: sin el, nadie sabe cuando NO usarlo")
                unless $t =~ /^[ \t]*CUANDO NO/m;
        }
    } else { mal("G · no puedo abrir $MOLDES") }

    # F · las plantillas del disco tienen que ser las que saldrian hoy.
    for my $t (@TIPOS) {
        my $tipo = $t->[0];
        my $f = "$DEST/$tipo.html";
        my $hay = slurp($f);
        if (!defined $hay) { mal("F · falta la plantilla de `$tipo`: corre --plantillas"); next }
        mal("F · la plantilla de `$tipo` no es la que saldria hoy: corre --plantillas")
            if $hay ne plantilla($t);
    }
    if (@MAL) {
        print "ROLES MAL\n";
        print "  · $_\n" for @MAL;
        print "\n  ", scalar(@MAL), " problema(s).\n";
        return 1;
    }
    printf "ROLES OK · %d roles (%d con molde, %d a mano) · %d tipos con plantilla\n",
           $tot, $con, $tot - $con, scalar(@TIPOS);
    return 0;
}
sub num {
    my ($x) = @_;
    return $x if $x =~ /^\d+$/;
    my %n = (one=>1,two=>2,three=>3,four=>4,five=>5,six=>6,seven=>7,eight=>8,
             nine=>9,ten=>10,eleven=>11,twelve=>12,thirteen=>13,fourteen=>14);
    return $n{lc $x};
}

# --- PLANTILLAS --------------------------------------------------------------
sub esc { my $s = shift // ''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; return $s }

sub plantilla {
    my ($t) = @_;
    my ($tipo, $obl, $cond, $sec, $nobl, $nota) = @$t;
    my @obl  = grep { length } split /\s+/, ($obl  // '');
    my @cond = grep { length } split /\s+/, ($cond // '');

    my $h = '';
    $h .= "<!DOCTYPE html>\n<html lang=\"es\">\n<head>\n<meta charset=\"UTF-8\">\n";
    $h .= "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n";
    $h .= "<title>PLANTILLA — $tipo</title>\n";
    $h .= "<!--\n";
    $h .= "  GENERADO POR gates/roles.pl --plantillas. NO SE EDITA A MANO.\n";
    $h .= "  Lo que se edita es la FUENTE: el orden de los roles esta en\n";
    $h .= "  gates/anatomy.tsv y el molde de cada rol en gates/roles.tsv.\n";
    $h .= "  `roles.pl --gate` se pone rojo si este fichero deja de ser el que\n";
    $h .= "  saldria hoy, asi que editarlo a mano no dura una bateria.\n\n";
    $h .= "  NO LLEVA EL MARKUP DE LOS MOLDES DENTRO, a proposito: seria una\n";
    $h .= "  segunda copia de cada uno, y el dia que se arregle un molde esta\n";
    $h .= "  hoja seguiria ensenando el defecto. Apunta, no copia.\n";
    $h .= "-->\n";
    # 🔴 SIN PALETA PROPIA ESTA HOJA SE ABRE NEGRO SOBRE NEGRO. Medido el
    #    1-sep-2026 con getComputedStyle, no leido de una captura: `background:
    #    rgba(0,0,0,0)` y `color: rgb(0,0,0)`. La primera version solo enlazaba
    #    ../_tokens.css y ../_base.css y no declaraba nada suya, asi que en
    #    cuanto esos dos no cargan —o el visor es oscuro— el texto desaparece.
    #    Una hoja de REFERENCIA se abre con doble clic desde el disco: tiene que
    #    valerse sola. Los enlaces se quedan como mejora, no como requisito.
    $h .= "<link rel=\"stylesheet\" href=\"../_tokens.css\">\n";
    $h .= "<link rel=\"stylesheet\" href=\"../_base.css\">\n";
    $h .= "<style>\n";
    $h .= "  :root{--pl-bg:#fff;--pl-fg:#16181d;--pl-dim:#5a6472;--pl-line:#c9d0d8;--pl-link:#0b5fff}\n";
    $h .= "  \@media (prefers-color-scheme:dark){:root{--pl-bg:#14161a;--pl-fg:#e8ebef;--pl-dim:#a4adba;--pl-line:#3a424e;--pl-link:#7fb0ff}}\n";
    $h .= "  html{background:var(--pl-bg)}\n";
    $h .= "  body{background:var(--pl-bg);color:var(--pl-fg);\n";
    $h .= "       font:16px/1.55 system-ui,-apple-system,\"Segoe UI\",sans-serif;\n";
    $h .= "       max-width:70ch;margin:0 auto;padding:2rem 1rem}\n";
    $h .= "  a{color:var(--pl-link)}\n";
    $h .= "  .slot{border:1px solid var(--pl-line);border-radius:.4rem;padding:.9rem 1rem;margin:.9rem 0}\n";
    $h .= "  .slot--cond{border-style:dashed}\n";
    $h .= "  .slot--mano{border-style:dotted}\n";
    $h .= "  .n{font-variant-numeric:tabular-nums;color:var(--pl-dim)}\n";
    $h .= "  .rol{font-weight:700}\n";
    $h .= "  .job{margin:.2rem 0 .5rem}\n";
    # El color se declara, no se baja la opacidad: `opacity` sobre texto es como
    # se cuela un contraste por debajo de AA sin que se note al escribirlo.
    $h .= "  .meta{font-size:.9em;color:var(--pl-dim);margin:.15rem 0}\n";
    $h .= "  ol{list-style:none;padding:0}\n";
    $h .= "  code{font-size:.95em}\n";
    $h .= "</style>\n</head>\n<body>\n";
    $h .= "<h1>Plantilla de referencia — <code>$tipo</code></h1>\n";
    $h .= "<p>Anatomia <strong>09 §$sec</strong>. "
        . scalar(@obl) . " rol(es) obligatorio(s)"
        . (@cond ? ", " . scalar(@cond) . " condicional(es)" : "") . ".</p>\n";
    $h .= "<p class=\"meta\">" . esc($nota) . "</p>\n" if defined $nota && $nota =~ /\S/;

    if (!@obl && !@cond) {
        $h .= "<p><strong>Este tipo no tiene anatomia a proposito.</strong> Ver 09 §$sec.</p>\n";
        $h .= "</body>\n</html>\n";
        return $h;
    }

    $h .= "<ol>\n";
    my $i = 0;
    for my $par ([\@obl, 'obligatorio', ''], [\@cond, 'condicional', ' slot--cond']) {
        my ($lista, $etiq, $cls) = @$par;
        for my $r (@$lista) {
            $i++;
            my $d = $ROL{$r} || { en => '?', trabajo => 'rol desconocido', moldes => [], prim => '?' };
            my @m = @{ $d->{moldes} };
            my $extra = @m ? $cls : "$cls slot--mano";
            $h .= "<li class=\"slot$extra\">\n";
            $h .= "  <div><span class=\"n\">" . sprintf('%02d', $i) . "</span> "
                . "<span class=\"rol\">$r</span> <span class=\"meta\">($d->{en} · $etiq)</span></div>\n";
            $h .= "  <p class=\"job\">" . esc($d->{trabajo}) . "</p>\n";
            if (@m) {
                for my $m (@m) {
                    my ($si, $no) = cuando_de($m);
                    $h .= "  <p class=\"meta\">Molde: <a href=\"../$m\"><code>$m</code></a></p>\n";
                    $h .= "  <p class=\"meta\">CUANDO: " . esc($si) . "</p>\n" if defined $si;
                    $h .= "  <p class=\"meta\">CUANDO NO: " . esc($no) . "</p>\n" if defined $no;
                }
                $h .= "  <p class=\"meta\">Dos moldes: el rol acepta cualquiera de los dos. "
                    . "Se elige por el CUANDO, no por costumbre.</p>\n" if @m > 1;
            } else {
                $h .= "  <p class=\"meta\"><strong>SIN MOLDE.</strong> Se maqueta a mano; "
                    . "no se salta. Deuda declarada en 10 §6.</p>\n";
            }
            $h .= "</li>\n";
        }
    }
    $h .= "</ol>\n";
    $h .= "<h2>Las dos constantes, y la regla de variedad</h2>\n";
    $h .= "<p>Toda pagina empieza por <code>01-hero.html</code> y termina por "
        . "<code>11-closing-cta.html</code>: eso es lo que garantiza las dos llamadas a la "
        . "accion que exige el gate de densidad. Y <strong>minimo 4 primitivas distintas por "
        . "pagina, maximo una rejilla de tarjetas</strong> (10 §2, regla 3).</p>\n";
    $h .= "<p class=\"meta\">Los roles que no salen aqui no se anaden porque quepan: "
        . "se anaden cambiando la anatomia en 09 §2 y gates/anatomy.tsv, que es donde vive "
        . "esa decision.</p>\n";
    $h .= "</body>\n</html>\n";
    return $h;
}

sub generar {
    make_path($DEST) unless -d $DEST;
    my $n = 0;
    for my $t (@TIPOS) {
        my $tipo = $t->[0];
        open my $o, '>:raw', "$DEST/$tipo.html" or die "no puedo escribir $tipo: $!\n";
        print $o plantilla($t); close $o; $n++;
    }
    print "escritas $n plantillas en blueprint/moulds/types/\n";
    return 0;
}

my $modo = $ARGV[0] // '--gate';
exit( $modo eq '--plantillas' ? generar() : gate() );
