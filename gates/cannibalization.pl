#!/usr/bin/perl
# =============================================================================
#  cannibalization.pl · DOS PAGINAS PELEANDO POR EL MISMO TERMINO
# =============================================================================
#  26-ago-2026. Sale de la puerta 5 de `seo-business-fit-filter` (gtm-skills,
#  MIT): toda pieza se declara NEW / UPDATE / CANNIBALIZES antes de escribirse.
#
#  POR QUE, Y NO ES TEORICO. `_seo/content-backlog.md` abre con un banner rojo:
#  tres piezas del Batch 1 YA estaban publicadas con otra URL, y avisa «no
#  volver a escribirlas o se crea una segunda pagina atacando la misma
#  keyword». Eso es una canibalizacion cazada A MANO, en un aviso, dentro de un
#  fichero que el radar del 22-ago dice que «vuelve a ir desfasado».
#
#  Y ya habia mordido antes: al poner «Climent Ads Assistant» de H1 en la
#  portada quedo DUPLICADO EXACTO con el H1 del hub del producto. Dos paginas
#  compitiendo por el mismo termino no se reparten el trafico: el buscador
#  elige una, y no elige la que tu quieres.
#
#  DOS MODOS, Y HACEN COSAS DISTINTAS
#
#    --audit          barre el arbol y busca colisiones que YA existen.
#                     Es exacto: H1 o title identicos entre paginas indexables.
#                     Sin heuristica, sin umbral, sin opinion.
#
#    --keyword "..."  ANTES de escribir: contra que choca esta pieza.
#                     Aqui si hay heuristica, y por eso el veredicto SIEMPRE
#                     viene con la evidencia -que pagina, con que H1, que
#                     palabras coinciden- para que decida un humano.
#
#  LOS VEREDICTOS
#    NUEVO       nada del arbol ataca ese termino
#    ACTUALIZA   ya existe la pagina de esa URL -no es una pieza nueva-
#    CANIBALIZA  OTRA pagina ya ataca el termino. Esto para el trabajo.
#    REVISAR     coincidencia parcial. NO tumba el gate a proposito: un gate
#                que bloquea en la zona gris se acaba desactivando entero, y
#                entonces se pierde tambien lo que si valia.
#
#  QUE DEVUELVE
#    0  medido, y no hay canibalizacion (puede haber REVISAR, se dice)
#    1  medido, y hay colision
#    3  NO MEDIDO. No es un aprobado.
#
#  LO QUE ESTE GATE NO SABE, Y HAY QUE DECIRLO: no lee rankings. Dos paginas
#  pueden competir sin parecerse en el H1, y eso solo lo ve Search Console.
#  Esto caza la colision DECLARADA -la que se ve en el arbol-, que es la que
#  se puede evitar antes de escribir.
#
#  USO
#    perl cannibalization.pl --repo DIR --audit
#    perl cannibalization.pl --repo DIR --keyword "incrementality testing"
#    perl cannibalization.pl --repo DIR --keyword "..." --url /learn/algo/
# =============================================================================
use strict;
use warnings;

my ($repo, $kw, $url, $audit, $quiet) = ('', '', '', 0, 0);
while (@ARGV) {
  my $a = shift @ARGV;
  if    ($a eq '--repo')    { $repo  = shift @ARGV // '' }
  elsif ($a eq '--keyword') { $kw    = shift @ARGV // '' }
  elsif ($a eq '--url')     { $url   = shift @ARGV // '' }
  elsif ($a eq '--audit')   { $audit = 1 }
  elsif ($a eq '--quiet' or $a eq '-q') { $quiet = 1 }
  else { die "argumento desconocido: $a\n" }
}
no_medido("hace falta --repo") unless $repo;
no_medido("no existe el directorio $repo") unless -d $repo;
no_medido("hace falta --audit o --keyword") unless $audit or length $kw;

# --- normalizacion ------------------------------------------------------------
# Se trabaja en BYTES y se traducen los acentos a mano. Meter una capa de
# codificacion aqui es como se dobla-codifica un fichero entero sin que nada
# de error: la trampa esta documentada y no se repite.
my %ACC = (
  "\xc3\xa1"=>'a', "\xc3\xa9"=>'e', "\xc3\xad"=>'i', "\xc3\xb3"=>'o', "\xc3\xba"=>'u',
  "\xc3\x81"=>'a', "\xc3\x89"=>'e', "\xc3\x8d"=>'i', "\xc3\x93"=>'o', "\xc3\x9a"=>'u',
  "\xc3\xa0"=>'a', "\xc3\xa8"=>'e', "\xc3\xac"=>'i', "\xc3\xb2"=>'o', "\xc3\xb9"=>'u',
  "\xc3\xa2"=>'a', "\xc3\xaa"=>'e', "\xc3\xae"=>'i', "\xc3\xb4"=>'o', "\xc3\xbb"=>'u',
  "\xc3\xa3"=>'a', "\xc3\xb5"=>'o', "\xc3\xa7"=>'c',
  "\xc3\xb1"=>'n', "\xc3\x91"=>'n', "\xc3\xbc"=>'u', "\xc3\xa4"=>'a', "\xc3\xb6"=>'o',
);
sub norm {
  my ($s) = @_;
  return '' unless defined $s;
  for my $k (keys %ACC) { my $v = $ACC{$k}; $s =~ s/\Q$k\E/$v/g }
  $s = lc $s;
  $s =~ s/&[a-z]+;/ /g;         # entidades HTML
  $s =~ s/&#x?[0-9a-f]+;/ /gi;
  $s =~ s/[^a-z0-9]+/ /g;
  $s =~ s/^\s+|\s+$//g;
  return $s;
}

# Palabras que no distinguen un tema de otro. Sin ellas, «what is a good roas»
# y «what is a good cpa» coincidirian en 4 de 5 palabras y saldria un falso
# CANIBALIZA. Esto NO es cosmetica: es lo que separa la senal del ruido.
my %STOP = map { $_ => 1 } qw(
  a al algo ante como con contra de del desde donde dos e el en entre es esta este esto
  hasta la las le lo los mas me mi mucho muy no nos o os para pero por que se si sin
  sobre su sus te tu tus un una uno unos y ya
  the a an and or of for to in on at by with from is are was were be been being
  what how why when where which who whose your you our we us it its this that these those
  can could should would may might will do does did not
);
sub content_words {
  my @w = grep { length($_) > 2 and !$STOP{$_} } split /\s+/, norm($_[0]);
  my %seen; return grep { !$seen{$_}++ } @w;
}

# --- leer el arbol ------------------------------------------------------------
my @files;
{
  my @stack = ($repo);
  while (@stack) {
    my $d = pop @stack;
    opendir(my $dh, $d) or next;
    for my $e (readdir $dh) {
      next if $e eq '.' or $e eq '..';
      # Carpetas que NO se publican: contarlas produce colisiones fantasma.
      next if $e =~ /^(\.git|node_modules|_deploy|_spec|_seo|_qa|_kit|_migrate|_post-images|ds-bundle|\.design-sync|_cowork)$/;
      my $p = "$d/$e";
      if (-d $p) { push @stack, $p }
      elsif ($e =~ /\.html?$/i) { push @files, $p }
    }
    closedir $dh;
  }
}
no_medido("no hay ni un .html bajo $repo") unless @files;

my @pages;
for my $f (@files) {
  open my $fh, '<', $f or next;
  local $/; my $html = <$fh>; close $fh;

  my ($title) = $html =~ m{<title[^>]*>(.*?)</title>}is;
  my ($h1)    = $html =~ m{<h1[^>]*>(.*?)</h1>}is;
  for ($title, $h1) { next unless defined $_; s/<[^>]*>//g; s/\s+/ /g; s/^\s+|\s+$//g }

  # Una pagina noindex no puede canibalizar: no compite por nada.
  my $noindex = ($html =~ m{<meta[^>]+name=["']robots["'][^>]*content=["'][^"']*noindex}i) ? 1 : 0;

  my $rel = $f; $rel =~ s{^\Q$repo\E/?}{};
  my $slug = $rel; $slug =~ s{(^|/)index\.html?$}{$1}i; $slug =~ s{\.html?$}{}i;
  $slug = '/' . $slug; $slug =~ s{//+}{/}g;

  push @pages, { file => $rel, slug => $slug, title => ($title // ''),
                 h1 => ($h1 // ''), noindex => $noindex };
}

my @live = grep { !$_->{noindex} } @pages;

# =============================================================================
#  MODO AUDITORIA · colisiones exactas que YA existen
# =============================================================================
if ($audit) {
  my (%by_h1, %by_title, @hits);
  for my $p (@live) {
    push @{ $by_h1{ norm($p->{h1}) } },       $p if length norm($p->{h1});
    push @{ $by_title{ norm($p->{title}) } }, $p if length norm($p->{title});
  }
  for my $k (sort keys %by_h1) {
    next unless @{ $by_h1{$k} } > 1;
    push @hits, [ 'H1 IDENTICO', $by_h1{$k}[0]{h1}, [ map { $_->{slug} } @{ $by_h1{$k} } ] ];
  }
  for my $k (sort keys %by_title) {
    next unless @{ $by_title{$k} } > 1;
    push @hits, [ 'TITLE IDENTICO', $by_title{$k}[0]{title}, [ map { $_->{slug} } @{ $by_title{$k} } ] ];
  }

  unless ($quiet) {
    printf "arbol: %s\n%d paginas HTML  ·  %d indexables  ·  %d noindex (no compiten)\n\n",
      $repo, scalar @pages, scalar @live, scalar(@pages) - scalar(@live);
  }
  if (@hits) {
    unless ($quiet) {
      for my $h (@hits) {
        printf "  %s: \"%s\"\n", $h->[0], $h->[1];
        printf "      %s\n", $_ for @{ $h->[2] };
        print  "\n";
      }
      print "Dos paginas con el mismo H1 o el mismo title no se reparten el trafico:\n";
      print "el buscador elige UNA, y no elige la que tu quieres. Se separan por intencion.\n\n";
    }
    printf "VEREDICTO: FALLA - %d colision(es) exacta(s)\n", scalar @hits;
    exit 1;
  }
  printf "VEREDICTO: PASA - %d paginas indexables, 0 colisiones exactas de H1 o title\n", scalar @live;
  exit 0;
}

# =============================================================================
#  MODO CANDIDATO · contra que choca esta pieza ANTES de escribirla
# =============================================================================
my @kwords = content_words($kw);
no_medido("la keyword \"$kw\" no deja ni una palabra con contenido tras quitar vacias")
  unless @kwords;

# ACTUALIZA: la URL propuesta ya existe. No es una pieza nueva.
if (length $url) {
  my $u = $url; $u =~ s{/+$}{/}; $u = "/$u" unless $u =~ m{^/};
  for my $p (@live) {
    my $s = $p->{slug}; $s =~ s{/+$}{/};
    if (lc $s eq lc $u or lc "$s/" eq lc $u or lc $s eq lc "$u/") {
      print "La URL $url YA EXISTE: $p->{file}\n" unless $quiet;
      print "  H1 actual: \"$p->{h1}\"\n" unless $quiet;
      print "VEREDICTO: ACTUALIZA - no es una pieza nueva, es una revision de esa pagina\n";
      exit 0;
    }
  }
}

my (@fuerte, @parcial);
for my $p (@live) {
  my $hay = norm(join ' ', $p->{title}, $p->{h1}, $p->{slug});
  next unless length $hay;
  my $hit = 0;
  $hit++ for grep { $hay =~ /(?:^| )\Q$_\E(?: |$)/ } @kwords;
  next unless $hit;
  my $frac = $hit / scalar @kwords;
  my $row = { p => $p, hit => $hit, frac => $frac };
  # TODAS las palabras con contenido presentes = ataca el mismo termino.
  #
  # El umbral de REVISAR es LA MITAD, no dos tercios, y se bajo el 26-ago tras
  # verlo fallar en el banco: con una keyword de DOS palabras con contenido
  # -que es lo normal- dos tercios es inalcanzable, asi que 1 de 2 caia en
  # NUEVO y la zona gris no existia. Un aviso de mas aqui es barato: REVISAR
  # no tumba el gate, solo informa.
  if ($frac >= 0.999) { push @fuerte,  $row }
  elsif ($frac >= 0.5) { push @parcial, $row }
}

unless ($quiet) {
  printf "keyword:  \"%s\"\n", $kw;
  printf "palabras con contenido: %s\n", join(', ', @kwords);
  printf "arbol: %d paginas indexables en %s\n\n", scalar @live, $repo;
}

if (@fuerte) {
  unless ($quiet) {
    print "CANIBALIZA. Estas paginas ya atacan ese termino:\n\n";
    for my $r (sort { $b->{frac} <=> $a->{frac} } @fuerte) {
      printf "  %s\n", $r->{p}{slug};
      printf "      H1:    \"%s\"\n", $r->{p}{h1};
      printf "      title: \"%s\"\n", $r->{p}{title};
      printf "      fichero: %s   (%d de %d palabras)\n\n", $r->{p}{file}, $r->{hit}, scalar @kwords;
    }
    print "Antes de escribir: o es un ACTUALIZA de una de estas, o hay que\n";
    print "separar la intencion -H1 y capsula distintos, y enlazarlas entre si-.\n\n";
  }
  printf "VEREDICTO: FALLA - CANIBALIZA con %d pagina(s): %s\n",
    scalar @fuerte, join(', ', map { $_->{p}{slug} } @fuerte);
  exit 1;
}

if (@parcial) {
  unless ($quiet) {
    print "REVISAR. Coincidencia parcial - puede ser legitimo, lo decide un humano:\n\n";
    for my $r (sort { $b->{frac} <=> $a->{frac} } @parcial) {
      printf "  %s  (%d de %d palabras)\n", $r->{p}{slug}, $r->{hit}, scalar @kwords;
      printf "      H1: \"%s\"\n", $r->{p}{h1};
    }
    print "\n";
  }
  printf "VEREDICTO: PASA - NUEVO, con %d para REVISAR: %s\n",
    scalar @parcial, join(', ', map { $_->{p}{slug} } @parcial);
  exit 0;
}

print "Ninguna pagina indexable del arbol ataca ese termino.\n" unless $quiet;
print "VEREDICTO: PASA - NUEVO\n";
exit 0;

sub no_medido {
  my ($why) = @_;
  print "NO MEDIDO: $why\n";
  print "VEREDICTO: NO MEDIDO (rc=3). Esto NO es un aprobado.\n";
  exit 3;
}
