#!/usr/bin/perl
# =============================================================================
#  chk-collisions.pl — el gate que impide que los moldes vuelvan a pisarse
# =============================================================================
#  POR QUE EXISTE (10-ago-2026)
#  ---------------------------
#  Los 19 moldes traian cada uno su `<style>` entero. Quince definian `.sec__in`
#  con CINCO anchos distintos, y al pegar dos en la misma pagina ganaba el ultimo:
#  la composicion de home dio **4 de 7 secciones a 568px en vez de 1120**, con una
#  rejilla en columnas de 188,7px contra un suelo de ~260. Nadie lo vio hasta que
#  se midio, porque el resultado no es un error: es una pagina mas estrecha.
#
#  Un documento que dice "no redeclares el chasis" no impide redeclararlo. Esto si.
#
#  USO
#    perl chk-collisions.pl <fichero.html|dir> ...
#    perl chk-collisions.pl ../../blueprint/moulds            # los 19
#  Sale 0 si todo bien, 1 si hay algun hallazgo. Imprime FICHERO:SELECTOR:MOTIVO.
#
#  LAS SEIS COMPROBACIONES
#    C1  un molde redeclara un selector del chasis (.sec, .sec__in, .btn, ...)
#    C2  un molde declara :root / body / *  (se escapa a toda la pagina)
#    C3  un selector de ELEMENTO suelto (`h2{}`) sin ninguna clase
#    C4  una clase que no es `mNN-` del propio molde ni del chasis
#    C5  dos moldes declaran el MISMO selector con declaraciones DISTINTAS
#    C6  dos moldes declaran el MISMO selector con las MISMAS declaraciones
#        (no rompe la pagina, pero significa que esa regla es del chasis)
# =============================================================================
use strict; use warnings;

# El chasis. Si se anade algo a _base.css, se anade aqui.
my @CHASIS = qw(
  sec sec--caja sec--tinta sec--ancla
  sec__in sec__in--texto sec__in--flujo sec__in--spec sec__in--ancho
  sec__h sec__sub btn btn--1 btn--2 nota enlace
);
my %CHASIS = map { $_ => 1 } @CHASIS;

# ── entrada ────────────────────────────────────────────────────────────────
my @files;
for my $arg (@ARGV) {
  if (-d $arg) { push @files, sort glob("$arg/*.html") }
  elsif (-f $arg) { push @files, $arg }
  else { die "no existe: $arg\n" }
}
die "uso: chk-collisions.pl <fichero.html|dir> ...\n" unless @files;

# ── parseo ─────────────────────────────────────────────────────────────────
# Devuelve lista de [contexto, selector, declaraciones-normalizadas]
sub parse_css {
  my ($css) = @_;
  $css =~ s{/\*.*?\*/}{}gs;            # fuera comentarios ANTES de nada: un
                                       # comentario pegado delante de una regla
                                       # se cuela dentro del selector y la regla
                                       # se vuelve invisible (ya me paso).
  my @out;
  my $walk; $walk = sub {
    my ($src, $ctx) = @_;
    my $i = 0; my $n = length $src;
    while ($i < $n) {
      my $b = index($src, '{', $i);
      last if $b < 0;
      my $sel = substr($src, $i, $b - $i);
      my ($d, $j) = (0, $b);
      while ($j < $n) {
        my $c = substr($src, $j, 1);
        $d++ if $c eq '{'; $d-- if $c eq '}';
        last if $d == 0;
        $j++;
      }
      my $body = substr($src, $b + 1, $j - $b - 1);
      $sel =~ s/^\s+|\s+$//g; $sel =~ s/\s+/ /g;
      if ($sel =~ /^\@(media|supports)\b/i) {
        $walk->($body, ($ctx ? "$ctx " : '') . $sel);
      } elsif ($sel =~ /^\@/) {
        # keyframes, font-face...: no declaran selectores de pagina
      } else {
        my $decl = join ';', sort grep { /\S/ } map { s/^\s+|\s+$//gr }
                             split /;/, ($body =~ s/\s+/ /gr);
        push @out, [$ctx, $_, $decl] for map { s/^\s+|\s+$//gr } split /,/, $sel;
      }
      $i = $j + 1;
    }
  };
  $walk->($css, '');
  return @out;
}

# ── recoger ────────────────────────────────────────────────────────────────
my (@bad, %porselector);
for my $f (@files) {
  my $base = $f; $base =~ s{.*[\\/]}{};
  next if $base =~ /^_/;                       # _tokens.css / _base.css no son moldes
  my ($num) = $base =~ /^(\d{2})-/;
  open my $fh, '<:raw', $f or die "$f: $!";
  my $src = do { local $/; <$fh> }; close $fh;
  my $css = join "\n", ($src =~ /<style[^>]*>(.*?)<\/style>/gs);
  next unless $css =~ /\S/;

  for my $r (parse_css($css)) {
    my ($ctx, $sel, $decl) = @$r;
    my $key = ($ctx ? "$ctx | " : '') . $sel;

    # C2 · globales
    if ($sel =~ /^(?::root|body|html|\*)$/) {
      push @bad, [$base, $key, 'C2', "declara un selector GLOBAL: se escapa a toda la pagina en cuanto este molde se pega con otro"];
      next;
    }
    # C3 · elemento suelto sin ninguna clase en el selector
    unless ($sel =~ /\./) {
      push @bad, [$base, $key, 'C3', "selector de ELEMENTO sin clase: pinta ese elemento en toda la pagina"];
      next;
    }
    # C1 y C4 · clases del selector
    my @cls = $sel =~ /\.([A-Za-z][\w-]*)/g;
    my ($subject) = $sel =~ /([^\s>+~]+)$/;      # ultimo compuesto = el sujeto
    my @subcls = $subject ? ($subject =~ /\.([A-Za-z][\w-]*)/g) : ();
    if (grep { $CHASIS{$_} } @subcls) {
      push @bad, [$base, $key, 'C1', "redeclara el chasis: eso vive UNA vez en _base.css"];
    }
    for my $c (@cls) {
      next if $CHASIS{$c};
      next if defined($num) && $c =~ /^m\Q$num\E-/;
      push @bad, [$base, $key, 'C4',
        defined($num) ? "clase `$c` sin el prefijo `m$num-` del molde"
                      : "clase `$c` fuera del chasis en un fichero sin numero de molde"];
    }
    push @{ $porselector{$key} }, [$base, $decl];
  }
}

# ── C5 / C6 · el mismo selector en dos moldes ──────────────────────────────
for my $key (sort keys %porselector) {
  my @e = @{ $porselector{$key} };
  my %files; push @{ $files{$_->[0]} }, $_->[1] for @e;
  next if keys(%files) < 2;
  my %decl; $decl{$_->[1]} = 1 for @e;
  my $quien = join ', ', sort keys %files;
  if (keys(%decl) > 1) {
    push @bad, ['(varios)', $key, 'C5', "declarado en $quien con cuerpos DISTINTOS: al componer gana el ultimo pegado"];
  } else {
    push @bad, ['(varios)', $key, 'C6', "declarado identico en $quien: si lo necesitan dos moldes, es de _base.css"];
  }
}

# ── salida ─────────────────────────────────────────────────────────────────
if (@bad) {
  print "FALLA  chk-collisions: ", scalar(@bad), " hallazgo(s)\n\n";
  for my $b (sort { $a->[2] cmp $b->[2] or $a->[0] cmp $b->[0] } @bad) {
    printf "  [%s] %-32s %s\n         -> %s\n", @$b[2,0,1], $b->[3];
  }
  print "\n";
  exit 1;
}
printf "PASA   chk-collisions: %d fichero(s), 0 colisiones, 0 selectores de chasis redeclarados\n",
       scalar(grep { !m{[\\/]_} } @files);
exit 0;
