#!/usr/bin/perl
# Convierte los JSON de `measure-layout.sh` en las tres tablas que se leen:
# anchos de `.sec__in` por seccion, contraste (peor elemento) y CPL.
#   uso: perl layout-summary.pl anchos   out/med-X.json ...
#        perl layout-summary.pl contraste out/med-X.json ...
use strict; use warnings; use JSON::PP;

my $modo = shift or die "uso: layout-summary.pl <anchos|contraste|cpl> <json...>\n";
my @f = @ARGV or die "sin ficheros\n";

sub carga { my ($p)=@_; open my $h,'<:raw',$p or die "$p: $!";
            my $s=do{local $/;<$h>}; close $h; return decode_json($s); }
sub id { my $p=shift; $p =~ s{.*[\\/]med-}{}; $p =~ s/\.json$//; return $p; }

if ($modo eq 'anchos') {
  printf "%-18s %-4s %-13s %-26s %8s %8s  %s\n",
         'pagina','iw','data-sec','clase del contenedor','sec px','in px','veredicto';
  print '-' x 104, "\n";
  for my $p (@f) {
    my $d = carga($p); my $id = id($p);
    unless (defined $d->{innerWidth}) { print "$id  SIN MEDIDA\n"; next; }
    for my $s (@{ $d->{secciones} }) {
      next unless defined $s->{anchoIn};
      my $esp = 1120;
      my $cl  = $s->{claseIn} // '';
      $esp = 544  if $cl =~ /sec__in--texto/;
      $esp = 768  if $cl =~ /sec__in--flujo/;
      $esp = 928  if $cl =~ /sec__in--spec/;
      $esp = 1280 if $cl =~ /sec__in--ancho/;
      my $ok = (abs($s->{anchoIn} - $esp) <= 1) ? 'OK' : "REVISAR (esp $esp)";
      printf "%-18s %-4s %-13s %-26s %8s %8s  %s\n",
             $id, $d->{innerWidth}, $s->{dataSec}, ($cl || '(sin clase)'),
             $s->{anchoSeccion}, $s->{anchoIn}, $ok;
    }
    printf "%-18s %-4s %-13s %-26s %8s %8s  %s\n", $id, $d->{innerWidth},
           '', '(desborde horizontal)', '', scalar @{$d->{desborde}},
           (@{$d->{desborde}} ? 'REVISAR' : 'OK');
    print "\n";
  }
}
elsif ($modo eq 'contraste') {
  printf "%-24s %5s %6s %8s  %-30s %-9s %-9s %5s %s\n",
         'fichero','medi','fallan','peor','peor elemento','color','fondo','px','minimo';
  print '-' x 118, "\n";
  my ($tot,$mal,$peor) = (0,0,99);
  for my $p (@f) {
    my $d = carga($p); my $id = id($p);
    my $c = $d->{contraste} or next;
    my $w = $c->{peor}[0];
    $tot += $c->{medidos}; $mal += $c->{fallan};
    $peor = $w->{ratio} if $w && $w->{ratio} < $peor;
    printf "%-24s %5s %6s %8s  %-30s %-9s %-9s %5s %s%s\n",
      $id, $c->{medidos}, $c->{fallan},
      ($w ? $w->{ratio} : '-'),
      ($w ? substr($w->{sel},0,30) : '-'),
      ($w ? $w->{color} : '-'), ($w ? $w->{fondo} : '-'),
      ($w ? $w->{px} : '-'), ($w ? $w->{minimo} : '-'),
      ($c->{fallan} ? '  <-- FALLA' : '');
  }
  print '-' x 118, "\n";
  printf "TOTAL: %d elementos con texto medidos, %d por debajo de su minimo, peor ratio %s\n",
         $tot, $mal, $peor;
}
elsif ($modo eq 'cpl') {
  printf "%-24s %5s %9s %9s  %s\n", 'fichero','bloq','max real','max caja','el peor';
  print '-' x 86, "\n";
  for my $p (@f) {
    my $d = carga($p); my $id = id($p); my $c = $d->{cpl} or next;
    my $w = $c->{peores}[0];
    printf "%-24s %5s %9s %9s  %s\n", $id, $c->{medidos}, $c->{maxReal}, $c->{maxCaja},
           ($w ? "$w->{sel} ($w->{px}px)" : '-');
  }
}
else { die "modo desconocido: $modo\n" }
