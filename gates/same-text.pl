#!/usr/bin/perl
# Compara el TEXTO VISIBLE de dos arboles HTML, pagina a pagina.
# Existe para comprobar la regla de la casa: "se conserva el CONTENIDO, se
# rehace la MAQUETA". Una maqueta nueva que se come un parrafo no da error en
# ningun sitio -- la pagina sigue siendo HTML valido y el gate sigue verde.
#
# Se compara por PALABRAS, no por lineas: la maqueta cambia el orden de las
# etiquetas y la sangria a proposito, y eso no es una diferencia de contenido.
use strict; use warnings;
my ($antes, $despues) = @ARGV;
$antes && $despues or die "uso: same-text.pl <dir-antes> <dir-despues>\n";
binmode STDOUT, ':encoding(UTF-8)';

my @rel;
sub recorrer {
    my ($base, $dir) = @_;
    opendir my $d, $dir or return;
    for my $e (sort grep { !/^\./ } readdir $d) {
        my $p = "$dir/$e";
        if (-d $p) { recorrer($base, $p) }
        elsif ($e =~ /\.html$/) { my $r = $p; $r =~ s/^\Q$base\E\/?//; push @rel, $r }
    }
    closedir $d;
}
recorrer($antes, $antes);

sub palabras {
    my $f = shift;
    open my $fh, '<:encoding(UTF-8)', $f or return undef;
    local $/; my $h = <$fh>; close $fh;
    ($h) = $h =~ m{<main\b[^>]*>(.*)</main>}s or return undef;
    $h =~ s/<(script|style)\b.*?<\/\1>//gsi;
    # Los comentarios NO son texto visible. Sin esta linea, reescribir un
    # comentario del generador salia como "perdida de contenido" -- un falso
    # positivo, y de los que hacen que se deje de mirar la herramienta.
    $h =~ s/<!--.*?-->//gs;
    $h =~ s/<[^>]+>/ /g;
    $h =~ s/&nbsp;/ /g; $h =~ s/&amp;/&/g; $h =~ s/&quot;/"/g;
    $h =~ s/&([a-z]+|#\d+);/ /gi;          # el resto de entidades, a espacio
    # 🔴 26-ago-2026 · LA PUNTUACION IBA PEGADA AL TOKEN, y eso convertia
    #    cualquier reescritura en «perdida de texto del cliente».
    #    Medido ese dia al desplegar nora: el gate acuso a 5 paginas de perder
    #    palabras y decia «FALTAN 9: ... energias: ... profundo ...». Contadas
    #    a mano en el fichero: `profundo` 2->2, `representa` 3->3, `energias`
    #    3->3. No faltaba NINGUNA. Lo unico que habia cambiado era la
    #    puntuacion adherida: antes `energias:` y despues `energias,`.
    #
    #    ⚠️ Y el daño no es el ruido, es lo que el ruido se lleva por delante.
    #    Este aviso existe para cazar algo caro -entregar menos texto del
    #    cliente del que habia- y si salta con cada coma deja de leerse. El dia
    #    que se pierda un parrafo entero, el aviso estara ahi, identico, y
    #    nadie lo mirara. Un guardia que se equivoca a menudo no estorba: se
    #    apaga solo, en la cabeza de quien lo lee.
    #
    #    Se compara por PALABRA: sin signos en los bordes y sin distinguir
    #    mayusculas. Perder «Esto» y ganar «esto» tampoco es perder contenido.
    #    Lo que NO se toca es el recuento: si una palabra desaparece de verdad,
    #    sigue faltando. Ver el caso «un parrafo entero borrado» del banco.
    my @w = grep { length }
            map  { my $x = lc $_; $x =~ s/^[^\w]+//; $x =~ s/[^\w]+$//; $x }
            grep { length } split /\s+/, $h;
    return \@w;
}

my ($ok, $mal) = (0, 0);
for my $r (@rel) {
    my $a = palabras("$antes/$r");
    my $b = palabras("$despues/$r");
    unless (defined $a && defined $b) { printf "  ?? %-55s (sin <main> en uno de los dos)\n", $r; next }
    my %ca; $ca{$_}++ for @$a;
    my %cb; $cb{$_}++ for @$b;
    my (@faltan, @sobran);
    for my $w (sort keys %ca) {
        my $d = $ca{$w} - ($cb{$w} // 0);
        push @faltan, "$w x$d" if $d > 0;
    }
    for my $w (sort keys %cb) {
        my $d = $cb{$w} - ($ca{$w} // 0);
        push @sobran, "$w x$d" if $d > 0;
    }
    if (!@faltan) {
        $ok++;
        printf "  OK  %-55s %d palabras%s\n", $r, scalar @$b,
            (@sobran ? sprintf(' (+%d nuevas)', scalar @sobran) : '');
    } else {
        $mal++;
        printf "  MAL %-55s FALTAN %d: %s\n", $r, scalar @faltan,
            join(' · ', @faltan[0 .. ($#faltan > 7 ? 7 : $#faltan)]);
    }
}
print "\n  $ok paginas conservan todas sus palabras · $mal con perdida\n";
exit($mal ? 1 : 0);
