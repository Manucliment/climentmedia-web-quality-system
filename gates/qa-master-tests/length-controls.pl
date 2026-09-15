#!/usr/bin/env perl
# =============================================================================
#  Controles de largo_visible() · SEO-01 (title 15-65) y SEO-03b (desc 50-165)
# =============================================================================
#  Extrae la sub REAL de qa-master.pl y la evalua: mide el codigo que se
#  despliega, no una copia. Mismo patron que p3-controls.pl.
#
#  POR QUE EXISTE (20-ago-2026). Esta funcion ya se habia arreglado una vez
#  -las entidades contaban CINCO caracteres donde se ve UNO- y seguia contando
#  BYTES: una vocal acentuada valia 2 y un guion largo 3. O sea que el umbral
#  castigaba exactamente al frances y al castellano, que es el idioma de las
#  cinco webs. Medido ese dia en site-a.example/le-centre: title 70 contra 64
#  reales, meta description 175 contra 167. Los dos avisos, INVENTADOS.
#
#  Y lo que hace que duela: un fallo de frontera solo se ve CUANDO IMPORTA.
#  Con un title de 40 caracteres nadie se entera; solo aparece rozando el
#  umbral, que es justo el caso en el que uno se cree el numero.
#
#  Los casos van en BYTES, que es como el gate los lee del HTML.
# =============================================================================
use strict; use warnings; use utf8; use Encode ();
use File::Basename qw(dirname);
binmode(STDOUT, ':encoding(UTF-8)');

#  Derived from this file's own location, never from the caller's directory:
#  a default written as an absolute path works on exactly one machine, and a
#  default written relative to the repository root breaks the moment somebody
#  runs it from anywhere else (trap §7).
my $SRC = shift(@ARGV) // (dirname(__FILE__) . '/../qa-master.pl');
my $src = do { open my $f,'<:encoding(UTF-8)',$SRC or die "$SRC: $!"; local $/; <$f> };
my ($sub) = $src =~ /^(sub largo_visible\s+\{.*?^\})/ms
    or die "no encuentro sub largo_visible\n";
eval $sub; die $@ if $@;

#  etiqueta                                        texto                    largo
my @C = (
 # Los dos primeros son el title y la meta description REALES de una web del parque,
 # anonimizados el 15-sep-2026: marca, ciudad, calle y telefono eran de un cliente y
 # esto es un repo PUBLICO. Se conservan la ACENTUACION, el guion largo y el LARGO
 # EXACTO (64 y 167), que es lo unico que el control mide: un fallo de frontera solo
 # se ve rozando el umbral.
 ['title real de una web del parque (20-ago, anonimizado)',
  'Bel-Air — Centre de kinésithérapie à Varenne | Site A à Domicile', 64],
 ['meta description real de la misma (anonimizada)',
  'Le Verger, centre de kinésithérapie à Varennes (Rue des Tilleuls 120). Rééducation, thérapie manuelle et suivi post-opératoire en cabinet. Rendez-vous au 02 000 00 00.', 167],
 # CONTROLES NEGATIVOS: el arreglo no puede apagar la comprobacion.
 ['CONTROL · 80 sin acentos sigue siendo 80',      ('a' x 80), 80],
 ['CONTROL · 80 CON acentos tambien es 80',        ('é' x 80), 80],
 ['CONTROL · guion largo cuenta UNO, no tres',     ('—' x 30), 30],
 # La otra mitad de la funcion, que ya estaba arreglada y no puede romperse.
 ['CONTROL · entidad &amp; cuenta UNO, no cinco',  'a&amp;b', 3],
 ['CONTROL · entidad numerica &#8212; cuenta UNO', 'a&#8212;b', 3],
 ['CONTROL · texto vacio',                         '', 0],
);

my ($ok, $ko) = (0, 0);
for my $c (@C) {
    my ($eti, $txt, $esp) = @$c;
    my $real = largo_visible(Encode::encode('UTF-8', $txt));
    if ($real == $esp) { printf "  OK    %-46s esperaba %d y salio %d\n", $eti, $esp, $real; $ok++ }
    else               { printf "  MAL   %-46s esperaba %d y salio %d\n", $eti, $esp, $real; $ko++ }
}
printf "\n  %d OK  ·  %d MAL\n", $ok, $ko;
exit($ko ? 1 : 0);
