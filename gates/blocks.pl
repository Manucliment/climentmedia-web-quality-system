#!/usr/bin/perl
# Vuelca los bloques[] de una pagina de pages.jsonl con su INDICE, que es lo
# que `maqueta` usa para cortar. Con JSON::PP, no con regex: el contenido lleva
# comillas escapadas y acentos, y un barrido a mano ya rompio cuatro veces en
# esta migracion (CLAUDE.md de site-e-web).
use strict; use warnings; use JSON::PP;
my ($fichero, $slug, $ancho) = (@ARGV);
$ancho //= 120;
# OJO: `decode_json` quiere BYTES. Con una capa `:encoding(UTF-8)` en el open,
# la linea llega ya decodificada y decode_json muere -- y como el `eval` se lo
# tragaba, el programa decia "no encuentro el slug" teniendolo delante.
open my $fh, '<:raw', $fichero or die "no puedo leer $fichero: $!\n";
binmode STDOUT, ':encoding(UTF-8)';
while (my $l = <$fh>) {
    next unless $l =~ /\S/;
    my $p = eval { decode_json($l) };
    die "linea ilegible: $@" if $@;
    next unless $p;
    next unless ($p->{slug} // '') eq $slug;
    printf "== %s · %s bloques · h1: %s\n", $slug, scalar @{$p->{bloques} || []}, ($p->{h1} // '-');
    my $i = 0;
    for my $b (@{ $p->{bloques} || [] }) {
        my $x = $b->{x} // '';
        $x =~ s/\s+/ /g;
        $x = substr($x, 0, $ancho) . (length($b->{x} // '') > $ancho ? ' [...]' : '');
        printf "%3d %-5s %s\n", $i++, ($b->{t} // '?'), $x;
    }
    exit 0;
}
die "no encuentro el slug '$slug' en $fichero\n";
