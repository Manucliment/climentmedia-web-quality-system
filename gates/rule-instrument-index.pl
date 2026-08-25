#!/usr/bin/perl
# =============================================================================
#  rule-instrument-index.pl · EL INDICE, DERIVADO DE LOS DOS LADOS
# =============================================================================
#  19-ago-2026. Hasta hoy nadie podia contestar «¿que regla mide que
#  instrumento?» sin leerse 7.760 lineas de documentacion, y por eso nadie sabia
#  que el 57% del estandar no lo mira nada.
#
#  LO QUE ESTO NO ES: una tabla escrita a mano. Una tabla a mano caduca el dia
#  que se escribe -es literalmente el fallo de las tres tablas de anatomia, del
#  `_kit/audit.sh` que se quedo 51 lineas atras, y del auditor con la regla de
#  resolucion escrita cuatro veces-. Este indice se DERIVA de dos fuentes que ya
#  existen y que nadie mantiene para el:
#
#     lado A · lo que la regla DICE que la mide
#              -> `compliance.pl` ya lo parsea (`gates_de`) y desde hoy lo deja
#                 escrito en su snapshot. Aqui se LEE, no se vuelve a parsear:
#                 dos gramaticas para lo mismo divergirian.
#     lado B · lo que el instrumento EMITE de verdad
#              -> se extrae del CODIGO de qa-master.pl, audit.sh y
#                 linking-gate.pl. No de su documentacion.
#
#  Y lo que vale del cruce no es la lista: son los TRES DESAJUSTES.
#
#    A · ENGANCHE ROTO ... la regla nombra un check que el instrumento NO emite.
#        Es el peor de los tres: la regla PARECE cubierta y no lo esta. Cuenta
#        como cobertura en la matriz y nadie la mide. EXIT 1.
#    B · CHECK HUERFANO .. el instrumento lo emite y ninguna regla lo reclama.
#        O sobra el check, o falta la regla. Las dos cosas hay que decirlas.
#    C · SIN GATE ........ la regla es comprobable por maquina y no hay
#        instrumento. Es LA LISTA DE TRABAJO, y es la unica que se puede bajar
#        construyendo cosas.
#
#    perl rule-instrument-index.pl              usa el snapshot mas reciente
#    perl rule-instrument-index.pl --snap F     uno concreto
#
#  EXIT 0 = ningun enganche roto · 1 = hay enganches rotos · 2 = no pudo trabajar
# =============================================================================
use strict; use warnings;
use File::Basename qw(basename dirname);

my $DIR = dirname(__FILE__);
my %opt = (snap => '');
while (@ARGV) { my $a = shift @ARGV;
  if ($a eq '--snap') { $opt{snap} = shift @ARGV }
  else { die "argumento desconocido: $a\n" } }

# ---------- el snapshot mas reciente ----------------------------------------
if ($opt{snap} eq '') {
  my @s = sort { -M $a <=> -M $b } glob("$DIR/historial/conformidad-*.json");
  @s or do { print "no hay ningun snapshot en $DIR/historial/.\n"
           . "corre antes:  perl compliance.pl\n"; exit 2 };
  $opt{snap} = $s[0];
}

use JSON::PP ();
open my $fh, '<:raw', $opt{snap} or do { print "no puedo leer $opt{snap}\n"; exit 2 };
my $snap = JSON::PP->new->decode(do { local $/; <$fh> }); close $fh;
ref($snap->{reglas}) eq 'ARRAY' or do { print "el snapshot no trae reglas\n"; exit 2 };
$snap->{reglas}[0]{gates} or do {
  print "El snapshot es ANTERIOR al 19-ago y no trae los enganches parseados.\n"
      . "Vuelve a correr:  perl compliance.pl\n"; exit 2 };

# ---------- lado B · lo que cada instrumento EMITE, leido de su CODIGO -------
# Se lee el codigo y no la documentacion a proposito: la documentacion es
# justamente lo que deriva.
sub leer { my $f = shift; open my $h,'<:raw',$f or return ''; local $/; my $x=<$h>; close $h; $x }

# NORMALIZAR IGUAL EN LOS DOS LADOS, o el cruce inventa desajustes.
#   `uc "SEO-03b"` da "SEO-03B", y `gates_de` (en compliance.pl) guarda
#   "SEO-03b" con el sufijo en minuscula. Comparando eso salian 3 enganches
#   rotos que no lo estaban -SEO-03b, MED-07b, EST-06b, todos emitidos-.
#   La comparacion es lo ultimo que hay que dar por bueno: es donde dos
#   representaciones distintas del mismo hecho se leen como un hallazgo.
sub norm { my $x = shift // ''; $x =~ s/^\s+|\s+$//g;
           $x =~ /^([A-Za-z0-9]+)-(\d+)([A-Za-z]?)$/ ? uc($1).'-'.$2.lc($3) : uc($x) }

# ¿existe el programa que la regla nombra? Se busca por TODO el arbol de la
# skill y probando extension: `audit-vs-origen` es `audit-vs-source.sh` y
# `battery-layout.sh` vive en structure-gate-tests/. Buscar solo en $DIR y
# solo por nombre exacto acusaba a 6 programas que existen.
my %EXISTE;
sub existe {
  my $n = shift; return $EXISTE{$n} if exists $EXISTE{$n};
  my $hay = 0;
  for my $cand ($n, "$n.sh", "$n.pl", "$n.js") {
    $hay = 1, last if grep { -e $_ } glob("$DIR/$cand"), glob("$DIR/*/$cand");
  }
  $EXISTE{$n} = $hay;
}

my %EMITE;   # instrumento -> { check => 1 }
{
  my $qm = leer("$DIR/qa-master.pl");
  $EMITE{QAM}{norm($1)} = 1 while $qm =~ /\bid\s*=>\s*'([A-Za-z0-9]+-\d+[a-z]?)'/g;

  my $en = leer("$DIR/linking-gate.pl");
  $EMITE{ENL}{norm($1)} = 1 while $en =~ /\b(R\d+)\b/g;

  my $au = leer("$DIR/audit.sh");
  $EMITE{AUD}{$1} = 1 while $au =~ /\b(?:ok|bad|warn|skip)\s+"(S\d+\.\d+)/g;
}
for my $i (sort keys %EMITE) {
  printf("  %-4s emite %3d comprobaciones\n", $i, scalar keys %{$EMITE{$i}});
}
my $total_emitidos = 0; $total_emitidos += scalar keys %{$EMITE{$_}} for keys %EMITE;

# ---------- el cruce --------------------------------------------------------
my (@rotos, @fantasmas, %reclamado, @sin_gate);
for my $r (@{ $snap->{reglas} }) {
  my $g = $r->{gates} || {};
  my @qam = @{ $g->{qam} || [] };
  my @enl = @{ $g->{enl} || [] };
  my @otr = @{ $g->{otros} || [] };

  for my $c (@qam) {
    $EMITE{QAM}{norm($c)} ? ($reclamado{"QAM:$c"} = 1)
                    : push @rotos, { regla => $r->{id}, apunta => "qa-maestro $c",
                                     ref => $r->{ref}, texto => $r->{texto} };
  }
  for my $c (@enl) {
    next if $c eq '*';
    $EMITE{ENL}{norm($c)} ? ($reclamado{"ENL:$c"} = 1)
                    : push @rotos, { regla => $r->{id}, apunta => "enlazado-gate $c",
                                     ref => $r->{ref}, texto => $r->{texto} };
  }
  # los "otros" son herramientas nombradas: el enganche esta roto si el fichero
  # no existe. Un gate que nombra un programa inexistente es una regla que nadie
  # mide y que ademas parece medida.
  # UNA REGLA SOLO ESTA ROTA SI NO LA MIDE NADIE. MD-01 nombra «gate de CPL»
  # -que no es un programa- Y TAMBIEN `structure-gate.js`, que si existe y si
  # mide el ancho: acusarla de rota era decir que nadie la mide, y es falso.
  # El nombre fantasma sigue siendo un defecto, pero es OTRO: se cuenta aparte.
  my (@viven, @fantasma);
  for my $o (@otr) {
    my $n = $o; $n =~ s/^OTRO://;
    next if $n eq '';
    existe($n) ? push(@viven, $n) : push(@fantasma, $n);
  }
  my $mide_alguien = @qam || @enl || @viven;
  if (!$mide_alguien && @fantasma) {
    push @rotos, { regla => $r->{id}, apunta => join(" / ", @fantasma) . " (no existe)",
                   ref => $r->{ref}, texto => $r->{texto} };
  } elsif (@fantasma) {
    push @fantasmas, { regla => $r->{id}, apunta => join(" / ", @fantasma),
                       vive => join(" ", @viven, @qam, @enl), ref => $r->{ref} };
  }
  push @sin_gate, $r if !@qam && !@enl && !@otr
                     && lc($r->{comprobable_maquina} // '') eq 'si';
}

# cuantas reglas reclaman una comprobacion del auditor. Escrito a mano decia
# "ni una", y dejo de ser cierto el mismo dia que se ato la primera.
my $reclama_aud = 0;
for my $r (@{ $snap->{reglas} }) {
  my @o = @{ ($r->{gates}||{})->{otros} || [] };
  $reclama_aud++ if grep { /audit.sh/ } @o;
}

# ---------- huerfanos: el instrumento lo emite y nadie lo reclama ------------
my @huerfanos;
for my $i (sort keys %EMITE) {
  next if $i eq 'AUD';   # el catalogo no referencia los S-checks del auditor
                         # todavia: eso es el hallazgo, no el ruido. Se dice
                         # aparte, abajo, para no ahogar la lista.
  for my $c (sort keys %{$EMITE{$i}}) {
    push @huerfanos, "$i:$c" unless $reclamado{"$i:$c"};
  }
}

# ---------- informe ---------------------------------------------------------
my $L = '-' x 78;
print "\n$L\n  INDICE REGLA -> INSTRUMENTO   ·   derivado de dos lados, no escrito\n$L\n";
printf("  estandar   %d reglas   (%s)\n", scalar @{$snap->{reglas}}, basename($opt{snap}));
printf("  emiten     %d comprobaciones entre los 3 instrumentos leidos\n\n", $total_emitidos);

print "$L\n  A · ENGANCHES ROTOS  ·  la regla nombra un check que NO se emite\n$L\n";
if (@rotos) {
  for my $x (@rotos) {
    printf("  %-10s -> %-28s %s\n", $x->{regla}, $x->{apunta}, substr($x->{texto}//'',0,34));
    printf("  %-10s    %s\n", '', $x->{ref}//'');
  }
  printf("\n  %d enganche(s) roto(s). La regla PARECE cubierta y no lo esta:\n", scalar @rotos);
  print  "  cuenta como cobertura en la matriz y nadie la mide.\n";
} else { print "  ninguno.\n" }

print "\n$L\n  A-bis · NOMBRES FANTASMA  ·  la regla nombra algo que no existe, pero\n";
print   "          TAMBIEN algo que si la mide. El nombre sobra o esta mal escrito.\n$L\n";
if (@fantasmas) {
  for my $x (@fantasmas) {
    printf("  %-10s nombra '%s'  ·  la mide de verdad: %s\n", $x->{regla}, $x->{apunta}, $x->{vive});
  }
  printf("\n  %d. No dejan la regla sin medir, pero mandan buscar un programa que no hay.\n", scalar @fantasmas);
} else { print "  ninguno.\n" }

print "\n$L\n  B · CHECKS HUERFANOS  ·  se emiten y ninguna regla los reclama\n$L\n";
if (@huerfanos) {
  my $n = 0;
  while (@huerfanos) { my @l = splice(@huerfanos, 0, 8); print '  ', join(' ', @l), "\n"; $n += @l }
  print "\n  $n. O sobra el check, o falta la regla en el catalogo. Las dos hay que decirlas.\n";
} else { print "  ninguno.\n" }

print "\n$L\n  C · SIN GATE  ·  comprobable por maquina y sin instrumento  (LA LISTA)\n$L\n";
if (@sin_gate) {
  my %por_doc;
  push @{ $por_doc{ $_->{doc} // '?' } }, $_ for @sin_gate;
  for my $d (sort { @{$por_doc{$b}} <=> @{$por_doc{$a}} } keys %por_doc) {
    printf("  %3d  %s\n", scalar @{$por_doc{$d}}, $d);
  }
  # EL PORQUE, DERIVADO DEL CATALOGO, NO ESCRITO A MANO. El campo `tipo` ya
  # existe en cada regla; agruparlo aqui convierte «329 celdas sin gate» -un
  # numero que no dice que hacer- en tres montones con destinos distintos.
  my %tipo;
  $tipo{ $_->{tipo} // '(sin tipo)' }++ for @sin_gate;
  print "\n  y POR QUE no lo tienen (tipo declarado en el catalogo):\n";
  my %destino = (
    binaria      => 'si/no: se puede instrumentar. ES la lista de trabajo',
    umbral       => 'un numero contra un limite: se puede instrumentar',
    procedimiento=> 'un GESTO, no un sintoma. El gate solo puede probar el sintoma',
  );
  for my $t (sort { $tipo{$b} <=> $tipo{$a} } keys %tipo) {
    printf("    %3d  %-14s %s\n", $tipo{$t}, $t, $destino{$t} // '');
  }
  printf("\n  %d reglas. Es la unica de las tres listas que se baja CONSTRUYENDO.\n", scalar @sin_gate);
} else { print "  ninguna.\n" }

print "\n$L\n";
printf("  El auditor de sitio emite %d comprobaciones (S1.1-S6.6) y el catalogo del\n", scalar keys %{$EMITE{AUD}});
printf("  estandar referencia %d. El resto de su cobertura NO cuenta en la matriz:\n", $reclama_aud);
print  "  no porque no mida, sino porque nadie ato lo que mide a ninguna regla.\n";
print  "$L\n";
exit(@rotos ? 1 : 0);
