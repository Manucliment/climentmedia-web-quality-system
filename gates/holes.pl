#!/usr/bin/perl
# =============================================================================
#  holes.pl · LO QUE FALTA Y NO ES NUESTRO, DECLARADO Y LEIDO POR LA PUERTA
# =============================================================================
#  19-ago-2026. El mecanismo existia -`_spec/site.json -> huecos[]`- y solo lo
#  usaba la web de PRUEBA: las cuatro webs de cliente declaraban CERO. Y aun en
#  la de prueba era inerte, porque NINGUN gate lo leia. Documentacion que nadie
#  comprueba es una nota, no un mecanismo.
#
#  QUE RESUELVE. Hoy «falta el NIF de site-d» o «hay que tocar 4 disparadores
#  en el GTM de site-a» viven en fichas de Notion y en la cabeza de quien estuvo
#  ese dia. Eso significa que un despliegue puede salir sin que nadie vea lo que
#  sigue faltando, y que el dia que el cliente conteste nadie se entera.
#
#  Es lo mismo que `aceptado.conf` hizo con las decisiones: convertir algo que
#  se recordaba en algo que se DECLARA, se firma y se lee.
#
#  EL FICHERO: `_huecos.tsv` en la RAIZ del repo -no en `_spec/`, porque dos de
#  los seis repos no tienen `_spec/` y un mecanismo con dos casas diverge-.
#
#    id  quien  que  medido  bloquea  desde  estado
#
#  `quien`  cliente | Manuel | nosotros    quien tiene que resolverlo
#  `medido` LA PRUEBA de que falta. Un hueco sin medida es una suposicion, y
#           una suposicion en esta lista bloquea trabajo por nada.
#  `estado` abierto | cerrado
#
#    perl holes.pl --repo DIR          informe
#    perl holes.pl --repo DIR -q       solo el resumen
#  EXIT 0 = el fichero esta bien formado (haya huecos o no)
#       1 = el fichero esta MAL FORMADO, o un hueco no dice que lo prueba
#       2 = no se puede trabajar (falta el repo)
# =============================================================================
use strict; use warnings;
my ($REPO, $Q) = ('', 0);
while (@ARGV) { my $a = shift @ARGV;
  if ($a eq '--repo') { $REPO = shift @ARGV // '' }
  elsif ($a eq '-q')  { $Q = 1 }
}
$REPO ne '' && -d $REPO or do { print "holes.pl: falta --repo DIR\n"; exit 2 };
my $F = "$REPO/_huecos.tsv";

my @VALIDO_QUIEN  = qw(cliente Manuel nosotros);
my @VALIDO_ESTADO = qw(abierto cerrado);

if (!-f $F) {
  print "  HUECOS: este repo no declara `_huecos.tsv`.\n";
  print "  No es lo mismo que no tener huecos: es que nadie ha dicho cuales son.\n";
  print "  Cabecera:  id\tquien\tque\tmedido\tbloquea\tdesde\testado\n";
  exit 0;
}

# Crudo a la entrada y crudo a la salida: NADA de capas de codificacion.
# Leyendo con :encoding y escribiendo sin ella, los caracteres anchos salen
# rotos por pantalla; y al reves -mezclar capas- doble-codifica el fichero.
# Los bytes del TSV ya son UTF-8: pasan enteros si no se toca nada.
open my $h, '<:raw', $F or do { print "  HUECOS: no puedo leer $F\n"; exit 2 };
my (@filas, @mal); my $n = 0;
while (my $l = <$h>) {
  chomp $l; $n++;
  next if $l =~ /^\s*#/ || $l =~ /^\s*$/;
  my @c = split /\t/, $l, -1;
  next if lc($c[0] // '') eq 'id';                      # cabecera
  if (@c != 7) { push @mal, "linea $n: " . scalar(@c) . " columnas, hacen falta 7"; next }
  my %r; @r{qw(id quien que medido bloquea desde estado)} = @c;
  $r{_l} = $n;
  push @mal, "linea $n: id '$r{id}' no tiene la forma HUECO-NN"     unless $r{id}     =~ /^HUECO-\d+$/;
  push @mal, "linea $n: quien '$r{quien}' no esta en el vocabulario" unless grep { $_ eq $r{quien} } @VALIDO_QUIEN;
  push @mal, "linea $n: estado '$r{estado}' no esta en el vocabulario" unless grep { $_ eq $r{estado} } @VALIDO_ESTADO;
  push @mal, "linea $n: fecha '$r{desde}' no es AAAA-MM-DD"         unless $r{desde}  =~ /^\d{4}-\d{2}-\d{2}$/;
  push @mal, "linea $n ($r{id}): sin MEDIDO. Un hueco sin la prueba de que falta es una suposicion, y una suposicion aqui bloquea trabajo por nada" if ($r{medido} // '') =~ /^\s*$/;
  push @mal, "linea $n ($r{id}): sin BLOQUEA. Si no bloquea nada, no es un hueco: es una idea" if ($r{bloquea} // '') =~ /^\s*$/;
  push @filas, \%r;
}
close $h;

my @abiertos = grep { $_->{estado} eq 'abierto' } @filas;
my %por;  push @{ $por{$_->{quien}} }, $_ for @abiertos;

if (!$Q) {
  print "------------------------------------------------------------------------------\n";
  print "  HUECOS DECLARADOS  ·  ", scalar(@filas), " en total, ", scalar(@abiertos), " abiertos\n";
  print "------------------------------------------------------------------------------\n";
  for my $q (@VALIDO_QUIEN) {
    next unless $por{$q};
    print "\n  LO QUE DEBE: $q  (", scalar(@{$por{$q}}), ")\n";
    for my $r (@{ $por{$q} }) {
      printf("    %-10s %s\n", $r->{id}, $r->{que});
      print  "               medido:  $r->{medido}\n";
      print  "               bloquea: $r->{bloquea}   (abierto desde $r->{desde})\n";
    }
  }
  my @cerrados = grep { $_->{estado} eq 'cerrado' } @filas;
  printf("\n  cerrados: %d\n", scalar(@cerrados)) if @cerrados;
}

if (@mal) {
  print "\n  🔴 EL FICHERO ESTA MAL FORMADO:\n";
  print "     $_\n" for @mal;
  print "  Un hueco mal declarado no bloquea a nadie y ademas ensucia el recibo.\n";
  exit 1;
}
printf("  HUECOS: %d abiertos · %d cerrados · el fichero esta bien formado\n",
       scalar(@abiertos), scalar(@filas) - scalar(@abiertos));
exit 0;
