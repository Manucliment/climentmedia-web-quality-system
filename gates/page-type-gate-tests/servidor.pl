#!/usr/bin/perl
# A tiny HTTP server for the PT-08 cases: it plays four sites at once.
#   /f/<name>          a fixture file from the folder given, with PUERTO replaced by the port
#   /buscar?q=X        a results page that shows X and carries noindex      (the good one)
#   /indexable?q=X     a results page that shows X and can be indexed
#   /sin-buscador?s=X  no search behind it: 302 to the home
#   /cualquiera?q=X    answers 200 but ignores the term (a page that is not a results page)
#   /limite            429, a host that rate-limits the probe
#   anything else      404
use strict; use warnings;
use IO::Socket::INET;
my $port = shift or die "uso: servidor.pl <puerto> <carpeta>\n";
my $dir  = shift or die "uso: servidor.pl <puerto> <carpeta>\n";
my $s = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $port, Listen => 10, ReuseAddr => 1)
    or die "no puedo escuchar en $port: $!\n";
sub dec { my $x = shift // ''; $x =~ tr/+/ /; $x =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge; $x }
sub resp { my ($c, $st, $cab, $b) = @_; $b //= '';
    print $c "HTTP/1.0 $st\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: " . length($b) . "\r\n$cab\r\n$b" }
while (my $c = $s->accept) {
    my $l = <$c> // ''; my ($ruta) = $l =~ m{^GET\s+(\S+)};
    while (my $h = <$c>) { last if $h =~ /^\r?\n$/ }
    $ruta //= '/';
    my ($p, $q) = split /\?/, $ruta, 2; $q //= '';
    my %q = map { my ($k, $v) = split /=/, $_, 2; ($k => dec($v)) } split /&/, $q;
    if ($p eq '/') { resp($c, '200 OK', '', '<html><head><title>Portada</title></head><body><h1>Portada</h1></body></html>') }
    elsif ($p =~ m{^/f/([\w.-]+)$} && open my $fh, '<:raw', "$dir/$1") {
        local $/; my $b = <$fh>; close $fh; $b =~ s/PUERTO/$port/g; resp($c, '200 OK', '', $b);
    }
    elsif ($p eq '/buscar')      { resp($c, '200 OK', '', qq{<html><head><meta name="robots" content="noindex,follow"></head><body><h1>Resultados para «$q{q}»</h1></body></html>}) }
    elsif ($p eq '/indexable')   { resp($c, '200 OK', '', qq{<html><head></head><body><h1>Resultados para «$q{q}»</h1></body></html>}) }
    elsif ($p eq '/sin-buscador'){ resp($c, '302 Found', "Location: http://127.0.0.1:$port/\r\n", '') }
    elsif ($p eq '/cualquiera')  { resp($c, '200 OK', '', '<html><body><h1>Bienvenido</h1></body></html>') }
    elsif ($p eq '/limite')      { resp($c, '429 Too Many Requests', '', 'slow down') }
    else                         { resp($c, '404 Not Found', '', 'no') }
    close $c;
}
