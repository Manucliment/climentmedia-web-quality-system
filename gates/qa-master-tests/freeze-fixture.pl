#!/usr/bin/perl
# Selecciona de una cache de qa-maestro las entradas de UN host y las copia a
# un directorio de fixture. Copia el trio completo: .meta, .body y .hdr.
#   perl selecciona-fixture.pl <cache-origen> <destino> <substring-del-host> [--listar]
use strict; use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path);

my ($SRC, $DST, $NEEDLE, $MODO) = @ARGV;
die "uso: selecciona-fixture.pl <cache> <destino> <host> [--listar]\n"
    unless $SRC && $DST && $NEEDLE;
my $LISTAR = (($MODO // '') eq '--listar');
make_path($DST) unless -d $DST || $LISTAR;

opendir(my $dh, $SRC) or die "no puedo abrir $SRC: $!\n";
my @metas = grep { /\.meta$/ } readdir($dh);
closedir $dh;

my ($n, $bytes) = (0, 0);
my @urls;
for my $m (sort @metas) {
    open my $fh, '<', "$SRC/$m" or next;
    my $line = <$fh> // ''; close $fh;
    # formato de qa-maestro: code \t wire \t ctype \t url_efectiva \t tiempo
    next unless $line =~ /^\d{3}\t/;
    my @f = split /\t/, $line;
    my $url = $f[3] // '';
    next unless index($url, $NEEDLE) >= 0;
    (my $key = $m) =~ s/\.meta$//;
    push @urls, sprintf('%6d B  %s', ($f[1] // 0), $url);
    $n++;
    for my $ext (qw(meta body hdr)) {
        my $f = "$SRC/$key.$ext";
        next unless -e $f;
        $bytes += -s $f;
        copy($f, "$DST/$key.$ext") or die "copiando $f: $!\n" unless $LISTAR;
    }
}
print "$_\n" for sort @urls;
printf "\n%s: %d entradas · %.1f MB\n", ($LISTAR ? 'HABRIA COPIADO' : 'COPIADO'), $n, $bytes/1024/1024;
