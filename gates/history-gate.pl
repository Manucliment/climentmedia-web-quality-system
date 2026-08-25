#!/usr/bin/perl
# =============================================================================
#  history-gate.pl — el registro tiene que decir QUIEN acuso
# =============================================================================
#  🔴 POR QUE EXISTE (18-ago-2026)
#  `receipt.pl` guardaba el ID de lo NO VERIFICADO y del FALLO solo un contador.
#  Medido: 727 lineas del historial con veredicto FALLA sobre webs reales y
#  CERO que digan que check fallo. Por eso nadie pudo notar nunca que la mayoria
#  de las acusaciones eran falsas -- el registro no guarda al acusador. Y sin
#  nombre no se puede medir la precision de un gate, asi que el instrumento solo
#  podia crecer.
#
#  Arreglado ese dia. Este programa es lo que impide que se desarregle: si
#  alguien revierte el cambio, la PRIMERA corrida real vuelve a escribir una
#  FALLA sin nombre y esto se pone rojo.
#
#  ANCLA: no se compara contra una fecha escrita a mano -- se cuentan CAMPOS.
#  Las lineas de antes de la migracion tienen 7; las de despues, 8. La propia
#  linea dice de que epoca es, asi que el gate no depende de que yo recuerde
#  cuando fue.
# =============================================================================
use strict; use warnings;
my $F = $ENV{QA_RECIBOS_DIR}
     || (($ENV{HOME} || $ENV{USERPROFILE} || '.') . '/.qa-receipts');
$F .= '/history.tsv';
my ($OK, $MAL) = (0, 0);
print "BANCO · historial-gate (el registro nombra al que acusa)\n\n";

if (!-f $F) {
    # NOT MEASURED, which is not the same as broken. On a fresh install nothing
    # has been deployed yet, so there is no record to validate. Exit 3 is this
    # system's code for "I did not measure it" (see the trap log §35): a 1 sends
    # somebody looking for a defect that does not exist, and a gate that is red
    # from day one is a gate somebody switches off.
    print "  NOT MEASURED · there is no history at $F\n";
    print "  This is NOT a pass. It is also not an instrument failure: nothing\n";
    print "  has been deployed yet, so there is no record to check. Run it again\n";
    print "  after the first deploy.\n\n  OK 0 · MAL 0\n";
    exit 3;
}
open my $h, '<:raw', $F or die "no puedo leer $F: $!\n";
my $cab = <$h>;
$cab = '' unless defined $cab;
chomp $cab; $cab =~ s/\r$//;
my @cols = split /\t/, $cab;
if (grep { $_ eq 'ids_fallo' } @cols) {
    printf "  ok    %-52s cabecera con %d columnas\n", 'la cabecera declara ids_fallo', scalar @cols; $OK++;
} else {
    printf "  MAL   %-52s cabecera: %s\n", 'la cabecera NO declara ids_fallo', join('|', @cols); $MAL++;
}

my ($nuevas, $sin_nombre, @ejemplos) = (0, 0);
while (my $l = <$h>) {
    chomp $l; $l =~ s/\r$//; next unless $l =~ /\S/;
    my @f = split /\t/, $l, -1;
    next unless @f >= 8;                       # linea de antes de la migracion
    next unless ($f[2] // '') eq 'QA';         # SERVIDO y NOTA no traen veredicto de lentes
    next unless ($f[3] // '') =~ /FALLA/;
    $nuevas++;
    next if ($f[7] // '') =~ /\S/;
    $sin_nombre++;
    push @ejemplos, "$f[0] $f[1]" if @ejemplos < 3;
}
close $h;

if ($sin_nombre) {
    printf "  MAL   %-52s %d de %d\n", 'lineas FALLA sin decir que check fallo', $sin_nombre, $nuevas;
    print  "        $_\n" for @ejemplos;
    print  "        Alguien ha revertido el guardado de ids en receipt.pl o en qa-master.pl.\n";
    $MAL++;
} else {
    printf "  ok    %-52s %d lineas FALLA, todas con nombre\n",
           'toda FALLA posterior a la migracion dice quien acuso', $nuevas; $OK++;
}

my $viejas = 0;
{
    open my $g, '<:raw', $F or last;
    <$g>;
    while (my $l = <$g>) { my @f = split /\t/, $l, -1; $viejas++ if @f == 7 }
    close $g;
}
printf "\n  (%d lineas anteriores a la migracion, con 7 campos: no se les inventa nada)\n", $viejas;
printf "\n  OK %d · MAL %d\n", $OK, $MAL;
exit($MAL ? 1 : 0);
