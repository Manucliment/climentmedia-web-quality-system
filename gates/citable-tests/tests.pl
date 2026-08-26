#!/usr/bin/perl
# =============================================================================
#  citable-tests/tests.pl · EL BANCO DE `citable.pl`
# =============================================================================
#  26-ago-2026. Escrito en la misma tanda que el gate.
#
#  El caso que sostiene todo el banco es `LANG3`: una pagina en FRANCES tiene
#  que salir NO MEDIDO, no PASA. Dos de nuestras seis webs son `fr` y `pt`, y
#  los patrones son de ingles y espanol. Un gate que barre una pagina que no
#  entiende y dice «0 hallazgos» es la peor version de si mismo: parece
#  cobertura y es un hueco.
#
#    perl citable-tests/tests.pl
# =============================================================================
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use File::Basename qw(dirname);

my $dir  = tempdir(CLEANUP => 1);
my $here = File::Spec->rel2abs(dirname(__FILE__));
my $GATE = File::Spec->catfile($here, '..', 'citable.pl');
die "no encuentro el gate en $GATE\n" unless -f $GATE;

my ($ok, $bad) = (0, 0);
my $n = 0;

# Un parrafo limpio y largo, para que las paginas tengan un control positivo
# dentro y los hallazgos no salgan por ser la unica frase del fichero.
my $LIMPIO = 'Google Ads guarda el historial de cambios durante 30 dias exactos y no '
  . 'admite backfill, asi que un experimento de seis semanas pierde la memoria de sus '
  . 'primeros doce dias. La cifra sale de restar treinta a cuarenta y dos.';

sub pageof {
  my ($lang, $body) = @_;
  $n++;
  my $f = "$dir/p$n.html";
  open my $fh, '>', $f or die $!;
  print $fh qq{<!doctype html><html lang="$lang"><head><title>t</title></head><body>$body</body></html>};
  close $fh;
  return $f;
}

sub run {
  my ($f, @args) = @_;
  my $cmd = qq{"$^X" "$GATE" --file "$f"};
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
    printf "       %s\n", $_ for grep { /VEREDICTO|NO MEDIDO|BLOQUEA|DEBILITA/ } split /\n/, $out;
  }
}

print "\n  BANCO DE citable.pl\n";
print "  " . '=' x 62 . "\n\n";

# --- IDIOMA · el caso que justifica el gate entero ---------------------------
{
  my ($rc, $out) = run(pageof('fr', "<p>Vous cherchez un kinesitherapeute a domicile dans votre commune et vous ne savez pas par ou commencer aujourd hui.</p>"));
  check('LANG3 · pagina en FRANCES -> NO MEDIDO, nunca PASA', $rc, $out, 3, qr/NO MEDIDO/);
}
{
  my ($rc, $out) = run(pageof('pt', "<p>O espelho sob medida e fabricado com vidro temperado e entregue em toda a regiao no prazo combinado.</p>"));
  check('LANG4 · pagina en PORTUGUES -> NO MEDIDO', $rc, $out, 3, qr/NO MEDIDO/);
}
{
  $n++;
  my $f = "$dir/sinlang.html";
  open my $fh, '>', $f or die $!;
  print $fh qq{<!doctype html><html><head><title>t</title></head><body><p>$LIMPIO</p></body></html>};
  close $fh;
  my ($rc, $out) = run($f);
  check('LANG5 · sin <html lang> -> NO MEDIDO', $rc, $out, 3, qr/NO MEDIDO/);
}

# --- CONTROL POSITIVO --------------------------------------------------------
{
  my ($rc, $out) = run(pageof('es', "<p>$LIMPIO</p>"));
  check('POS1 · parrafo limpio en espanol -> PASA sin hallazgos', $rc, $out, 0, qr/0 bloqueos, 0 debilitan/);
}

# --- 1 · PRONOMBRE HUERFANO (BLOQUEA) ----------------------------------------
{
  my ($rc, $out) = run(pageof('en', "<p>This is the single most expensive mistake an advertiser can make when running an incrementality test on a live account.</p>"));
  check('C1a · EN abre con "This" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  my ($rc, $out) = run(pageof('es', "<p>Esto es el error mas caro que puede cometer un anunciante al lanzar un test de incrementalidad.</p>"));
  check('C1b · ES abre con "Esto" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  # Control negativo del mismo check: nombrar el sujeto lo apaga.
  my ($rc, $out) = run(pageof('es', "<p>El error mas caro que puede cometer un anunciante al lanzar un test de incrementalidad es terminarlo antes de tiempo.</p>"));
  check('C1c · ...y nombrando el sujeto NO salta (control negativo)', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
# --- LOS FALSOS POSITIVOS QUE ENCONTRO LA PRIMERA CORRIDA REAL ---------------
# De 76 hallazgos sobre climentmedia, ~37 eran DETERMINANTE + sustantivo, no
# pronombre huerfano. Estos casos existen para que no vuelvan.
{
  my ($rc, $out) = run(pageof('en', "<p>This page explains how the change history window works and why it closes at exactly thirty days.</p>"));
  check('FP1 · "This page explains" es determinante, NO pronombre huerfano', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run(pageof('en', "<p>These terms describe the two different ways an advertiser can lose visibility without a single rejected ad.</p>"));
  check('FP2 · "These terms describe" tampoco', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run(pageof('es', "<p>Esta pagina explica como funciona la ventana del historial y por que se cierra a los treinta dias.</p>"));
  check('FP3 · ES "Esta pagina explica" tampoco', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  # Y el control negativo del arreglo: con un VERBO detras si tiene que saltar.
  my ($rc, $out) = run(pageof('en', "<p>This is the single most expensive mistake an advertiser makes when running an incrementality test.</p>"));
  check('FP4 · ...pero "This is" SI salta (el arreglo no apago el check)', $rc, $out, 1, qr/BLOQUEA/);
}
{
  my ($rc, $out) = run(pageof('es', "<p>Esta es la decision mas cara que toma un anunciante al lanzar un test de incrementalidad.</p>"));
  check('FP5 · ...y ES "Esta es" tambien salta', $rc, $out, 1, qr/BLOQUEA/);
}

# --- 2 · REFERENCIA HACIA ATRAS (BLOQUEA) ------------------------------------
{
  my ($rc, $out) = run(pageof('en', "<p>As mentioned above, the change history window closes at thirty days and there is no way to recover what fell outside it.</p>"));
  check('C2a · EN "as mentioned above" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*anterior/s);
}
{
  my ($rc, $out) = run(pageof('es', "<p>Como se vio arriba, la ventana del historial se cierra a los treinta dias y no hay forma de recuperar lo anterior.</p>"));
  check('C2b · ES "como se vio arriba" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*anterior/s);
}

# --- 3 · SUJETO SIN NOMBRAR (DEBILITA, solo con --brand) ---------------------
my $LARGO_GENERICO = 'Our platform reads the account data every night and produces the weekly '
  . 'report without ever writing a single change back to the campaigns, because the connection '
  . 'is read only by design and the scopes granted at sign in do not include any write '
  . 'permission at all. The operator keeps the decision and we keep the evidence, which is the '
  . 'whole point of the arrangement and the reason the audit trail survives a procurement '
  . 'review without anyone having to take our word for anything at any point in the process.';
{
  my ($rc, $out) = run(pageof('en', "<p>$LARGO_GENERICO</p>"), '--brand', 'Climent Media');
  check('C3a · parrafo LARGO con "our platform" y sin marca -> DEBILITA', $rc, $out, 0, qr/DEBILITA.*marca/s);
}
{
  # El umbral de 60 palabras, que puso la primera corrida real: sin el, este
  # check acusaba al 19% de los parrafos del sitio.
  my ($rc, $out) = run(pageof('en', "<p>Our platform reads the account data and produces the weekly report without writing anything back.</p>"), '--brand', 'Climent Media');
  check('C3d · un parrafo CORTO con "our platform" NO se acusa (no es citable)', $rc, $out, 0,
        qr/0 bloqueos, 0 debilitan/);
}
{
  my ($rc, $out) = run(pageof('en', "<p>Climent Media reads the account data and produces the weekly report without ever writing a single change back to the campaigns.</p>"), '--brand', 'Climent Media');
  check('C3b · ...nombrando la marca NO salta (control negativo)', $rc, $out, 0, qr/0 bloqueos, 0 debilitan/);
}
{
  # Sin --brand el check NO se hace. La skill lo manda: «saltate un check antes
  # que forzar un hallazgo».
  my ($rc, $out) = run(pageof('en', "<p>Our platform reads the account data and produces the weekly report without ever writing a single change back to the campaigns.</p>"));
  check('C3c · sin --brand el check se SALTA, no se inventa', $rc, $out, 0, qr/0 bloqueos, 0 debilitan/);
}

# --- 4 · HEDGING (DEBILITA con 2 o mas) --------------------------------------
{
  my ($rc, $out) = run(pageof('en', "<p>The result may possibly indicate that the campaign could potentially be somewhat underperforming relative to its target.</p>"));
  check('C4a · varios atenuantes -> DEBILITA', $rc, $out, 0, qr/DEBILITA.*atenuantes/s);
}
{
  # UNO solo no basta: un gate que salta con cada «puede» acusa a todo.
  my ($rc, $out) = run(pageof('en', "<p>The change history window may close before the experiment ends, and the gap is exactly twelve days on a six week test.</p>"));
  check('C4b · UN solo atenuante no basta (evita acusar a todo)', $rc, $out, 0, qr/0 bloqueos, 0 debilitan/);
}

# --- 5 · FECHA RELATIVA (DEBILITA) -------------------------------------------
{
  my ($rc, $out) = run(pageof('en', "<p>Google recently changed how budget limited campaigns behave under target CPA bidding across search and shopping.</p>"));
  check('C5a · EN "recently" -> DEBILITA', $rc, $out, 0, qr/DEBILITA.*fecha relativa/s);
}
{
  my ($rc, $out) = run(pageof('es', "<p>Google cambio recientemente el comportamiento de las campanas limitadas por presupuesto con puja por CPA objetivo.</p>"));
  check('C5b · ES "recientemente" -> DEBILITA', $rc, $out, 0, qr/DEBILITA.*fecha relativa/s);
}

# --- 6 · PARRAFO LARGO (PULIDO) ----------------------------------------------
{
  my $largo = join ' ', map { "Frase numero $_ del parrafo con su dato dentro." } 1..7;
  my ($rc, $out) = run(pageof('es', "<p>$largo</p>"));
  check('C6 · siete frases en un parrafo -> PULIDO, no falla', $rc, $out, 0, qr/PULIDO.*frases/s);
}

# --- BANDA DE CITA -----------------------------------------------------------
{
  my ($rc, $out) = run(pageof('es', "<p>$LIMPIO</p>"));
  check('BAN1 · sin pasaje de 134-167 palabras -> AVISA y NO falla', $rc, $out, 0, qr/ni un pasaje entre 134 y 167/);
}
{
  my $banda = join ' ', map { "palabra$_" } 1..150;
  my ($rc, $out) = run(pageof('es', "<p>$banda</p>"));
  check('BAN2 · con un pasaje en banda -> lo cuenta y no avisa', $rc, $out, 0,
        qr/banda de cita \(134-167 palabras\): 1/);
}

# --- HIGIENE: EL CROMO NO SE MIDE --------------------------------------------
{
  # El mismo defecto DENTRO de un <nav> no es de nadie: es el menu.
  my ($rc, $out) = run(pageof('en', "<nav><p>This is the navigation blurb that would otherwise trip the orphan pronoun check on every single page.</p></nav><p>$LIMPIO</p>"));
  check('HIG1 · lo que hay en <nav> no se mide', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run(pageof('en', "<footer><p>This footer line repeats on all pages and must not generate a finding per page.</p></footer><p>$LIMPIO</p>"));
  check('HIG2 · lo que hay en <footer> no se mide', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  # Textos cortos -pies de foto, etiquetas- no son pasajes.
  my ($rc, $out) = run(pageof('en', "<p>This one is short.</p><p>$LIMPIO</p>"));
  check('HIG3 · un texto de menos de 40 caracteres no es un pasaje', $rc, $out, 0, qr/VEREDICTO: PASA/);
}

# --- NO MEDIDO ---------------------------------------------------------------
{
  my $out = `"$^X" "$GATE" --file "$dir/no-existe.html"`;
  check('NM1 · fichero inexistente -> NO MEDIDO', $? >> 8, $out, 3, qr/NO MEDIDO/);
}
{
  my $out = `"$^X" "$GATE"`;
  check('NM2 · sin argumentos -> NO MEDIDO', $? >> 8, $out, 3, qr/NO MEDIDO/);
}

print "\n  " . '=' x 62 . "\n";
printf "  %d casos en verde  ·  %d en rojo\n", $ok, $bad;
# En DOS lineas a proposito: ver la nota del banco de bots-ia.
printf "  OK %d\n",  $ok;
printf "  MAL %d\n\n", $bad;
exit($bad ? 1 : 0);
