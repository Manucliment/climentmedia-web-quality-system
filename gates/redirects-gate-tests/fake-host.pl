#!/usr/bin/env perl
# Un host que contesta lo que le digan, ruta a ruta, para probar
# `redirects-gate.pl --servido` sin tocar ningun dominio de verdad.
#   perl fake-host.pl <respuestas.tsv> <puerto>
# Cada linea:  ruta<TAB>codigo<TAB>location     (ruta sin la barra inicial; '' es /)
# La linea con ruta '*' contesta a todo lo que no este en la lista.
# /_sentinel contesta 200 con el contenido de <respuestas.tsv>.sentinel, para que
# el banco sepa que habla con ESTE servidor y no con otro que ya tuviera el puerto.
# Sin ReuseAddr, por el motivo escrito en receipt-tests/test-server.pl.
use strict; use warnings;
use IO::Socket::INET;
my ($tsv, $puerto) = @ARGV;
die "uso: fake-host.pl <respuestas.tsv> <puerto>\n" unless $tsv && $puerto;
$| = 1;
my $s = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $puerto,
                              Proto => 'tcp', Listen => 16)
        or die "no puedo escuchar en $puerto: $!\n";
sub lee {
    my ($f) = @_;
    open my $fh, '<:raw', $f or return '';
    local $/; my $x = <$fh>; close $fh;
    return defined $x ? $x : '';
}
while (my $c = $s->accept) {
    my $l = <$c>;
    unless (defined $l) { close $c; next }
    my ($ruta) = $l =~ m{^GET\s+(\S+)};
    while (defined($l = <$c>) && $l !~ /^\r?$/) { }
    $ruta = '/' unless defined $ruta;
    $ruta =~ s/\?.*$//;
    $ruta =~ s{^/}{};
    if ($ruta eq '_sentinel') {
        my $b = lee("$tsv.sentinel");
        print $c "HTTP/1.0 200 OK\r\nContent-Length: " . length($b) . "\r\n\r\n$b";
        close $c; next;
    }
    my (%r, $def);
    for my $x (split /\n/, lee($tsv)) {
        $x =~ s/\r$//;
        my ($p, $cod, $loc) = split /\t/, $x, 3;
        next unless defined $cod;
        if ($p eq '*') { $def = [$cod, $loc] } else { $r{$p} = [$cod, $loc] }
    }
    my $a = $r{$ruta} // $def // ['404', ''];
    my ($cod, $loc) = @$a;
    my $h = "HTTP/1.0 $cod X\r\nContent-Length: 0\r\n";
    $h .= "Location: $loc\r\n" if defined $loc && $loc ne '';
    print $c "$h\r\n";
    close $c;
}
