#!/usr/bin/perl
# =============================================================================
#  anatomy.pl — el guardia de la tabla de anatomias
# =============================================================================
#  La tabla vive en anatomy.tsv y la leen TRES programas. Dos la leen del
#  fichero (qa-master.pl, audit-vs-spec.pl). El tercero NO PUEDE:
#  structure-gate.js se evalua dentro del navegador, donde no hay disco. Ese
#  lleva una copia INCRUSTADA entre marcas, generada por este script.
#
#  Una copia solo es segura si hay algo que se pone rojo cuando deriva. Eso es
#  este fichero:
#    --gate          los cuatro controles de abajo. Sale 1 si alguno falla.
#    --regenerar-js  reescribe el bloque incrustado de structure-gate.js
#    --tabla         imprime la tabla como la ven los programas
#
#  QUE TENDRIA QUE OCURRIR PARA QUE ESTO SE PUSIERA ROJO
#    A · que 09 §2 gane o pierda una fila OBL y nadie toque anatomy.tsv
#        -> se cuentan los marcadores OBL de cada seccion del markdown, que no
#           dependen de este fichero: es el ancla independiente
#    B · que alguien vuelva a escribir una tabla a mano en los .pl
#    C · que el bloque incrustado del .js deje de coincidir con anatomy.tsv
#    D · que anatomy.tsv se quede sin fichero o sin tipos
#  Probado en rojo en los cuatro, no solo en verde.
# =============================================================================
use strict; use warnings;
use File::Basename qw(dirname); use File::Spec;
my $DIR  = dirname(File::Spec->rel2abs($0));
my $ABRE = '/* >' . '>> ANATOMIA-GENERADA';
my $CIER = '/* >' . '>> FIN-ANATOMIA-GENERADA <' . '<< */';
my $RE   = qr/\Q$ABRE\E.*?\Q$CIER\E/s;

# --- la tabla ---------------------------------------------------------------
sub cargar {
    my $f = shift // "$DIR/anatomy.tsv";
    open my $fh, '<', $f or die "anatomy.tsv: no se puede leer ($f): $!\n";
    my (@orden, %t);
    while (<$fh>) {
        chomp; s/\r$//;
        next if /^\s*#/ || !/\S/;
        my ($tipo, $roles, $cond, $sec, $obl, $nota) = split /\|/, $_, 6;
        $tipo = defined $tipo ? $tipo : ''; $tipo =~ s/^\s+|\s+$//g;
        die "anatomy.tsv: linea sin tipo: $_\n" unless $tipo =~ /^[a-z0-9]+$/;
        push @orden, $tipo;
        $t{$tipo} = { roles => [ grep { /\S/ } split ' ', (defined $roles ? $roles : '') ],
                      cond  => [ grep { /\S/ } split ' ', (defined $cond  ? $cond  : '') ],
                      sec   => (defined $sec ? $sec : ''),
                      obl   => (defined $obl ? $obl : ''),
                      nota  => (defined $nota ? $nota : '') };
    }
    close $fh;
    die "anatomy.tsv: 0 tipos. Un gate sobre una tabla vacia aprueba cualquier cosa.\n" unless @orden;
    return (\@orden, \%t);
}
my ($ORDEN, $T) = cargar();

# --- el bloque que se incrusta en el .js ------------------------------------
#  Se genera aqui para que solo exista UNA forma de escribirlo: si se generase
#  en dos sitios, volveriamos al problema que este fichero viene a cerrar.
sub bloque_js {
    my $s = "$ABRE · sale de anatomy.tsv · no editar a mano\n"
          . " * Regenerar:  perl anatomy.pl --regenerar-js\n"
          . " * Comprobar:  perl anatomy.pl --gate   (lo corre run-all.sh)\n"
          . " * La tabla humana es 09-tipos-de-pagina.md §2 */\n"
          . "const ANATOMIA = {\n";
    my $w = 0; for (@$ORDEN) { $w = length($_) if length($_) > $w }
    for my $tipo (@$ORDEN) {
        my @r = @{ $T->{$tipo}{roles} };
        next unless @r;
        $s .= sprintf("  %-*s [%s],\n", $w + 2, "$tipo:", join(', ', map { "'$_'" } @r));
    }
    $s .= "};\n";
    my @sin = grep { !@{ $T->{$_}{roles} } } @$ORDEN;
    # Los tipos SIN anatomia se emiten como lista, no como comentario: el gate
    # necesita distinguir «tipo valido que no lleva roles» de «tipo inventado».
    $s .= "/* Sin anatomia, a proposito: 09 §2.11 */\n"
        . "const ANATOMIA_SIN = [" . join(', ', map { "'$_'" } @sin) . "];\n" if @sin;
    # 🔴 1-sep-2026 · EL ALIAS ESTABA ESCRITO A MANO AQUI Y OTRA VEZ EN LA NOTA
    #    DEL TSV. Dos sitios para el mismo dato: `ficha` decia «alias aceptado:
    #    producto» en su nota y este generador emitia `producto: 'ficha'` sin
    #    leerla. Mientras hubo uno solo no se noto; al llegar el segundo
    #    (`quiz` -> `landing`) el que se edito a mano fue el fichero GENERADO, y
    #    el gate lo caza al instante — que es lo unico que impidio que
    #    divergieran de verdad.
    #    Ahora sale de la nota: «Alias aceptado: X» (o «alias aceptado: X»).
    my @alias;
    for my $tipo (@$ORDEN) {
        my $nota = $T->{$tipo}{nota} // '';
        push @alias, "$1: '$tipo'" if $nota =~ /alias\s+aceptado:\s*([a-z0-9_-]+)/i;
    }
    $s .= "const ANATOMIA_ALIAS = { " . join(', ', @alias) . " };\n" . $CIER;
    return $s;
}

sub slurp {
    my $f = shift;
    open my $h, '<', $f or return undef;
    local $/;
    my $x = <$h>;
    close $h;
    return $x;
}
my @MAL;
sub mal { push @MAL, $_[0] }

# --- los cuatro controles ---------------------------------------------------
sub gate {
    # A · el markdown, contado. Ancla INDEPENDIENTE de anatomy.tsv.
    # The human table is blueprint/09-page-types.md §2, one directory up.
    # It marks a required role `REQ` (it was `OBL` in the Spanish original);
    # both spellings are counted so the anchor survives either edition.
    my $MD = "$DIR/../blueprint/09-page-types.md";
    my $md = slurp($MD);
    if (!defined $md) { mal("A · no se encuentra $MD: sin el, el ancla no existe") }
    else {
        my (%cuenta, $sec);
        for my $l (split /\n/, $md) {
            if    ($l =~ /^###\s*(2\.\d+)/) { $sec = $1 }
            elsif ($l =~ /^##\s+3\s/)       { $sec = undef }
            $cuenta{$sec}++ if defined $sec && $l =~ /\b(?:OBL|REQ)\b/;
        }
        my %visto;
        for my $tipo (@$ORDEN) {
            my $sec = $T->{$tipo}{sec}; next unless $sec =~ /\S/;
            next if $visto{$sec}++;
            my $dice = $T->{$tipo}{obl};
            my $hay  = defined $cuenta{$sec} ? $cuenta{$sec} : 0;
            mal("A · 09 §$sec tiene $hay marcas OBL y anatomy.tsv declara $dice. "
              . "O cambio el documento y no la tabla, o al reves")
                if "$hay" ne "$dice";
        }
    }
    # B · ningun .pl puede volver a llevar su propia tabla
    for my $f (qw(qa-master.pl audit-vs-spec.pl)) {
        my $src = slurp("$DIR/$f");
        if (!defined $src) { mal("B · no se encuentra $f"); next }
        mal("B · $f vuelve a declarar su propia %ANATOMIA a mano. Se lee de anatomy.tsv")
            if $src =~ /^\s*my\s+%ANATOMIA\s*=\s*\(/m;
        mal("B · $f no llama a anatomia_cargar(): no esta leyendo la tabla")
            unless $src =~ /anatomia_cargar/;
    }
    # C · el bloque incrustado del .js, caracter a caracter
    my $js = slurp("$DIR/structure-gate.js");
    if (!defined $js) { mal("C · no se encuentra structure-gate.js") }
    elsif ($js !~ /($RE)/) {
        mal("C · structure-gate.js no tiene el bloque marcado: o se borro, o se edito a mano");
    } else {
        my $hay = $1; my $debe = bloque_js();
        if ($hay ne $debe) {
            my @a = split /\n/, $hay; my @b = split /\n/, $debe;
            my $i = 0; $i++ while $i < @a && $i < @b && $a[$i] eq $b[$i];
            mal("C · el bloque de structure-gate.js no coincide con anatomy.tsv (linea "
              . ($i + 1) . "):\n      js  : " . (defined $a[$i] ? $a[$i] : '(no hay mas)')
              . "\n      tsv : " . (defined $b[$i] ? $b[$i] : '(no hay mas)'));
        }
    }
    # D · la tabla tiene sustancia
    my $con = grep { @{ $T->{$_}{roles} } } @$ORDEN;
    mal("D · solo $con tipos con roles. Se esperaban 10 (legal y 404 no llevan)") if $con < 10;
    return @MAL ? 0 : 1;
}

# --- linea de ordenes -------------------------------------------------------
my $orden = @ARGV ? shift(@ARGV) : '--gate';
if ($orden eq '--tabla') {
    for my $tipo (@$ORDEN) {
        printf "%-12s %-58s %s\n", $tipo,
               (join(' ', @{ $T->{$tipo}{roles} }) || '(sin anatomia)'),
               (@{ $T->{$tipo}{cond} } ? 'condicionales: ' . join(' ', @{ $T->{$tipo}{cond} }) : '');
    }
    exit 0;
}
if ($orden eq '--bloque-js') { print bloque_js(), "\n"; exit 0 }
if ($orden eq '--regenerar-js') {
    my $f  = "$DIR/structure-gate.js";
    my $js = slurp($f) or die "no se puede leer $f\n";
    my $nuevo = bloque_js();
    my $n = 0; $n++ while $js =~ /$RE/g;
    die "structure-gate.js: encontradas $n marcas ANATOMIA-GENERADA, se esperaba 1. No se toca nada.\n"
        unless $n == 1;
    my $hechas = ($js =~ s/$RE/$nuevo/);
    die "structure-gate.js: 0 sustituciones pese a 1 encontrada. No se escribe.\n" unless $hechas == 1;
    open my $h, '>', $f or die $!; print $h $js; close $h;
    print "structure-gate.js: bloque regenerado ($hechas sustitucion de 1 esperada)\n";
    exit 0;
}
if ($orden eq '--gate') {
    if (gate()) {
        printf "ANATOMIA OK · %d tipos · una sola tabla (anatomy.tsv), 3 consumidores cuadrados\n",
               scalar @$ORDEN;
        exit 0;
    }
    print "ANATOMIA FALLA\n";
    print "  · $_\n" for @MAL;
    exit 1;
}
die "uso: anatomy.pl [--gate|--tabla|--bloque-js|--regenerar-js]\n";
