#!/usr/bin/perl
# =============================================================================
#  cannibalization-tests/tests.pl · EL BANCO DE `cannibalization.pl`
# =============================================================================
#  26-ago-2026. Escrito en la misma tanda que el gate.
#
#  El caso que mas importa de todo este banco es el de las PALABRAS VACIAS
#  («what is a good roas» contra «what is a good cpa»): si el gate no las
#  quitase, esas dos coincidirian en 4 de 5 palabras y saldria un CANIBALIZA
#  falso. Un gate que acusa de mas se acaba desactivando, y entonces se pierde
#  tambien lo que si cazaba. Ese caso es la razon de que exista la lista.
#
#    perl cannibalization-tests/tests.pl
# =============================================================================
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(make_path);
use File::Basename qw(dirname);

my $root = tempdir(CLEANUP => 1);
my $here = File::Spec->rel2abs(dirname(__FILE__));
my $GATE = File::Spec->catfile($here, '..', 'cannibalization.pl');
die "no encuentro el gate en $GATE\n" unless -f $GATE;

my ($ok, $bad) = (0, 0);

# Escribe una pagina en el arbol $tree
sub page {
  my ($tree, $path, $title, $h1, $noindex) = @_;
  my $f = "$root/$tree/$path";
  make_path(dirname($f));
  my $robots = $noindex ? qq{<meta name="robots" content="noindex, follow">} : '';
  open my $fh, '>', $f or die $!;
  print $fh qq{<!doctype html><html><head><title>$title</title>$robots</head>}
          . qq{<body><h1>$h1</h1><p>cuerpo</p></body></html>};
  close $fh;
}

sub run {
  my ($tree, @args) = @_;
  my $cmd = qq{"$^X" "$GATE" --repo "$root/$tree"};
  $cmd .= qq{ "$_"} for @args;
  my $out = `$cmd`;
  return ($? >> 8, $out);
}

sub check {
  my ($label, $rc, $out, $want_rc, $want_re) = @_;
  if ($rc == $want_rc && (!$want_re || $out =~ $want_re)) { $ok++; printf "  OK   %s\n", $label }
  else {
    $bad++;
    printf "  MAL  %s\n", $label;
    printf "       esperaba rc=%s%s, salio rc=%s\n", $want_rc, ($want_re ? " y /$want_re/" : ''), $rc;
    printf "       %s\n", $_ for grep { /VEREDICTO|NO MEDIDO/ } split /\n/, $out;
  }
}

print "\n  BANCO DE cannibalization.pl\n";
print "  " . '=' x 62 . "\n\n";

# --- MODO AUDITORIA ----------------------------------------------------------
page('a', 'index.html',            'Climent Ads Assistant - reporting', 'Climent Ads Assistant');
page('a', 'ads-assistant/index.html', 'Ad reporting you host yourself', 'Climent Ads Assistant');
{
  my ($rc, $out) = run('a', '--audit');
  check('AUD1 · dos H1 identicos -> FALLA', $rc, $out, 1, qr/H1 IDENTICO/);
}
{
  my ($rc, $out) = run('a', '--audit');
  check('AUD2 · ...y NOMBRA las dos rutas', $rc, $out, 1, qr{/ads-assistant/}s);
}

page('b', 'uno/index.html', 'El mismo title exacto', 'H1 distinto uno');
page('b', 'dos/index.html', 'El mismo title exacto', 'H1 distinto dos');
{
  my ($rc, $out) = run('b', '--audit');
  check('AUD3 · dos title identicos -> FALLA', $rc, $out, 1, qr/TITLE IDENTICO/);
}

# noindex no compite: es el caso que separa «colision» de «duplicado».
page('c', 'vivo/index.html',  'Titulo unico c1', 'El mismo H1');
page('c', 'copia/index.html', 'Titulo unico c2', 'El mismo H1', 1);
{
  my ($rc, $out) = run('c', '--audit');
  check('AUD4 · H1 repetido pero la otra es NOINDEX -> PASA', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run('c', '--audit');
  check('AUD5 · ...y cuenta la noindex aparte', $rc, $out, 0, qr/1 noindex/);
}

page('d', 'x/index.html', 'Titulo unico d1', 'H1 unico d1');
page('d', 'y/index.html', 'Titulo unico d2', 'H1 unico d2');
{
  my ($rc, $out) = run('d', '--audit');
  check('AUD6 · arbol limpio -> PASA (control positivo)', $rc, $out, 0, qr/0 colisiones/);
}

# --- MODO CANDIDATO ----------------------------------------------------------
page('e', 'learn/incrementality-testing/index.html',
     'Incrementality testing for ad accounts', 'Incrementality testing');
page('e', 'learn/marketing-attribution/index.html',
     'Marketing attribution', 'Marketing attribution');

{
  my ($rc, $out) = run('e', '--keyword', 'incrementality testing');
  check('CAN1 · el termino ya lo ataca una pagina -> CANIBALIZA', $rc, $out, 1, qr/CANIBALIZA/);
}
{
  my ($rc, $out) = run('e', '--keyword', 'incrementality testing');
  check('CAN2 · ...y NOMBRA la pagina y su H1', $rc, $out, 1,
        qr{/learn/incrementality-testing/.*H1:\s+"Incrementality testing"}s);
}
{
  my ($rc, $out) = run('e', '--keyword', 'google ads change history');
  check('CAN3 · termino sin relacion -> NUEVO', $rc, $out, 0, qr/VEREDICTO: PASA - NUEVO\s*$/m);
}
{
  my ($rc, $out) = run('e', '--keyword', 'incrementality testing budget', '--url', '/learn/incrementality-testing/');
  check('CAN4 · la URL ya existe -> ACTUALIZA, no canibaliza', $rc, $out, 0, qr/ACTUALIZA/);
}
{
  # 1 de 2 -> zona gris. NO puede tumbar el gate.
  # Este caso encontro un defecto de diseno el 26-ago: con el umbral en dos
  # tercios, una keyword de DOS palabras nunca podia caer en gris -1 de 2 es
  # 0,5-, asi que la zona gris no existia para el caso mas comun. Se bajo a la
  # mitad. El caso se queda como la prueba de que existe.
  my ($rc, $out) = run('e', '--keyword', 'attribution windows');
  check('CAN5 · 1 de 2 palabras -> PASA con REVISAR (la zona gris existe)', $rc, $out, 0, qr/REVISAR/);
}
{
  # 2 de 3, el otro lado de la misma banda.
  my ($rc, $out) = run('e', '--keyword', 'marketing attribution windows');
  check('CAN6 · 2 de 3 palabras -> PASA con REVISAR', $rc, $out, 0, qr/REVISAR/);
}
{
  # Y el limite de abajo: 1 de 3 no llega ni a gris.
  my ($rc, $out) = run('e', '--keyword', 'attribution pixel deduplication');
  check('CAN7 · 1 de 3 no llega ni a REVISAR -> NUEVO limpio', $rc, $out, 0,
        qr/VEREDICTO: PASA - NUEVO\s*$/m);
}

# --- EL CASO QUE JUSTIFICA LAS PALABRAS VACIAS -------------------------------
page('f', 'learn/what-is-a-good-roas/index.html', 'What is a good ROAS', 'What is a good ROAS');
{
  my ($rc, $out) = run('f', '--keyword', 'what is a good cpa');
  check('STOP1 · «good cpa» NO canibaliza a «good roas» (4 de 5 palabras son vacias)',
        $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run('f', '--keyword', 'what is a good roas');
  check('STOP2 · ...pero el mismo termino SI canibaliza (control negativo)',
        $rc, $out, 1, qr/CANIBALIZA/);
}

# --- ACENTOS -----------------------------------------------------------------
page('g', 'es/medicion/index.html', 'Medicion de campanas', "Medici\xc3\xb3n de campa\xc3\xb1as");
{
  my ($rc, $out) = run('g', '--keyword', "medici\xc3\xb3n campa\xc3\xb1as");
  check('ACC1 · el acento del H1 no impide el match', $rc, $out, 1, qr/CANIBALIZA/);
}
{
  my ($rc, $out) = run('g', '--keyword', 'medicion campanas');
  check('ACC2 · ...y sin acentos tambien casa', $rc, $out, 1, qr/CANIBALIZA/);
}

# --- NOINDEX EN MODO CANDIDATO -----------------------------------------------
page('h', 'borrador/index.html', 'Incrementality testing', 'Incrementality testing', 1);
{
  my ($rc, $out) = run('h', '--keyword', 'incrementality testing');
  check('NOI1 · una pagina noindex NO canibaliza', $rc, $out, 0, qr/VEREDICTO: PASA/);
}

# --- CARPETAS QUE NO SE PUBLICAN ---------------------------------------------
page('i', 'ok/index.html', 'Titulo i', 'H1 i');
page('i', '_seo/borrador.html', 'Incrementality testing', 'Incrementality testing');
{
  my ($rc, $out) = run('i', '--keyword', 'incrementality testing');
  check('EXC1 · lo que hay en _seo/ no cuenta (no se publica)', $rc, $out, 0, qr/VEREDICTO: PASA/);
}

# --- NO MEDIDO ---------------------------------------------------------------
{
  my $out = `"$^X" "$GATE" --repo "$root/no-existe" --audit`;
  check('NM1 · repo inexistente -> NO MEDIDO', $? >> 8, $out, 3, qr/NO MEDIDO/);
}
{
  my $empty = "$root/vacio"; make_path($empty);
  my $out = `"$^X" "$GATE" --repo "$empty" --audit`;
  check('NM2 · arbol sin HTML -> NO MEDIDO, no un aprobado', $? >> 8, $out, 3, qr/NO MEDIDO/);
}
{
  my ($rc, $out) = run('e', '--keyword', 'what is the a of');
  check('NM3 · keyword que es toda palabras vacias -> NO MEDIDO', $rc, $out, 3, qr/NO MEDIDO/);
}
{
  my $out = `"$^X" "$GATE" --repo "$root/e"`;
  check('NM4 · sin --audit ni --keyword -> NO MEDIDO', $? >> 8, $out, 3, qr/NO MEDIDO/);
}

print "\n  " . '=' x 62 . "\n";
printf "  %d casos en verde  ·  %d en rojo\n", $ok, $bad;
# En DOS lineas: en una sola, `[0-9]+ +MAL` del runner casa con «N  MAL» y lee
# los verdes como rojos. Medido el 26-ago con el banco de bots-ia.
printf "  OK %d\n",  $ok;
printf "  MAL %d\n\n", $bad;
exit($bad ? 1 : 0);
