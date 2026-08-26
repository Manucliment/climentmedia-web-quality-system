#!/usr/bin/perl
# =============================================================================
#  same-text-tests/tests.pl · EL BANCO DE `same-text.pl`
# =============================================================================
#  26-ago-2026. Escrito DESPUES que el gate, y esa es la historia que importa.
#
#  🔴 `same-text.pl` llevaba meses corriendo en CADA despliegue -- lo llama la
#     puerta en el paso 2-ter -- y NO TENIA NI UN CASO. Nadie habia escrito
#     nunca que debia acusar y que no. La regla 5 de la formula lo prohibe, y
#     aqui estaba prohibido y hecho.
#
#     Lo que costo: tokenizaba con la puntuacion PEGADA, asi que `energias:` y
#     `energias,` eran dos palabras distintas. Al desplegar nora acuso a 5
#     paginas de «perder palabras del cliente» y no faltaba ninguna: mover una
#     coma disparaba el aviso.
#
#     ⚠️ Y el daño no es el ruido. Este aviso existe para cazar algo caro
#     -entregar menos texto del cliente del que habia- y un guardia que se
#     equivoca a menudo no estorba: se apaga solo, en la cabeza de quien lo lee.
#
#  EL CASO QUE SOSTIENE EL BANCO es `PERDIDA1`: un parrafo entero borrado tiene
#  que salir MAL. Sin el, afinar la tokenizacion y desactivar el check son
#  indistinguibles desde fuera.
#
#    perl same-text-tests/tests.pl
# =============================================================================
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use File::Basename qw(dirname);

my $dir  = tempdir(CLEANUP => 1);
my $here = File::Spec->rel2abs(dirname(__FILE__));
my $GATE = File::Spec->catfile($here, '..', 'same-text.pl');
die "no encuentro el gate en $GATE\n" unless -f $GATE;

my ($ok, $bad) = (0, 0);
my $n = 0;

# Escribe un par de arboles (antes/despues) y devuelve sus dos rutas.
sub par {
  my ($cuerpo_antes, $cuerpo_despues) = @_;
  $n++;
  my ($a, $b) = ("$dir/a$n", "$dir/b$n");
  for my $par ([$a, $cuerpo_antes], [$b, $cuerpo_despues]) {
    my ($d, $c) = @$par;
    mkdir $d or die "no puedo crear $d: $!";
    open my $fh, '>:encoding(UTF-8)', "$d/index.html" or die $!;
    print $fh qq{<!doctype html><html lang="es"><body><main>$c</main></body></html>};
    close $fh;
  }
  return ($a, $b);
}

sub run {
  my ($a, $b) = @_;
  my $out = `"$^X" "$GATE" "$a" "$b" 2>&1`;
  return ($? >> 8, $out);
}

sub check {
  my ($label, $rc, $out, $want_rc, $want_re) = @_;
  if ($rc == $want_rc && (!$want_re || $out =~ $want_re)) { $ok++; printf "  OK   %s\n", $label }
  else {
    $bad++;
    printf "  MAL  %s\n", $label;
    printf "       esperaba rc=%s%s, salio rc=%s\n", $want_rc, ($want_re ? " y /$want_re/" : ''), $rc;
    printf "       %s\n", $_ for grep { /OK |MAL |conservan/ } split /\n/, $out;
  }
}

print "\n  BANCO DE same-text.pl\n";
print "  " . '=' x 62 . "\n\n";

# --- EL CASO QUE SOSTIENE EL BANCO -------------------------------------------
{
  my ($a, $b) = par(
    "<p>El primer parrafo dice una cosa concreta con su dato dentro.</p><p>El segundo parrafo dice otra cosa distinta y tambien importa.</p>",
    "<p>El primer parrafo dice una cosa concreta con su dato dentro.</p>");
  my ($rc, $out) = run($a, $b);
  check('PERDIDA1 · un parrafo ENTERO borrado -> MAL (el caso que lo pone rojo)',
        $rc, $out, 1, qr/MAL.*FALTAN/s);
}
{
  # Una sola palabra que desaparece tambien cuenta: la perdida no tiene umbral.
  my ($a, $b) = par(
    "<p>La ventana del historial se cierra a los treinta dias exactos.</p>",
    "<p>La ventana del historial se cierra a los dias exactos.</p>");
  my ($rc, $out) = run($a, $b);
  check('PERDIDA2 · UNA palabra que desaparece tambien -> MAL', $rc, $out, 1, qr/FALTAN.*treinta/s);
}

# --- LO QUE NO PUEDE ACUSAR · el motivo por el que existe este banco ---------
{
  # 🔴 EL DEFECTO REAL DE NORA. Mover la puntuacion no es perder texto.
  my ($a, $b) = par(
    "<p>Esto es lo que representa a nivel de energias:</p>",
    "<p>A nivel de energias, la luna nueva representa:</p>");
  my ($rc, $out) = run($a, $b);
  # Aqui SI desaparecen palabras (`Esto`, `es`, `lo`, `que`) y el gate acierta
  # al decirlo. Lo que se afirma es lo otro: que `energias` y `representa`, que
  # solo cambiaron de puntuacion, NO figuran entre las que faltan. Antes del
  # arreglo figuraban las dos, y esa era la mitad falsa del aviso.
  check('RUIDO1 · `energias:` -> `energias,` no figura entre las que faltan',
        $rc, $out, 1, qr/FALTAN(?!.*energias)(?!.*representa)/s);
}
{
  # Reescribir el sujeto SI quita palabras -- y debe acusarlas, pero solo esas.
  my ($a, $b) = par(
    "<p>Este es un ritual sencillo y profundo para atraer calma.</p>",
    "<p>Este ritual es sencillo y profundo, y sirve para atraer calma.</p>");
  my ($rc, $out) = run($a, $b);
  # 🔑 ESTE CASO SE ESCRIBIO MAL LA PRIMERA VEZ, y el gate tenia razon: al
  #    reordenar, el articulo `un` desaparece DE VERDAD. Lo correcto es exigir
  #    que se acuse `un` y SOLO `un` -- `profundo`, que solo gano una coma, no
  #    puede estar en la lista. Prueba las dos mitades a la vez: que no acusa de
  #    mas y que sigue acusando lo que falta.
  check('RUIDO2 · al reordenar, solo falta el `un` que si desaparecio',
        $rc, $out, 1, qr/FALTAN 1: un x1/);
}
{
  my ($a, $b) = par(
    "<p>La ventana se cierra a los treinta dias y no admite backfill.</p>",
    "<p>La ventana se cierra a los treinta dias, y no admite backfill.</p>");
  my ($rc, $out) = run($a, $b);
  check('RUIDO3 · anadir UNA coma no es perder texto', $rc, $out, 0, qr/conservan todas/);
}
{
  my ($a, $b) = par(
    "<p>Esto es el error mas caro que comete un anunciante al medir.</p>",
    "<p>esto es el error mas caro que comete un anunciante al medir.</p>");
  my ($rc, $out) = run($a, $b);
  check('RUIDO4 · solo cambia una mayuscula: no es perdida', $rc, $out, 0, qr/conservan todas/);
}

# --- HIGIENE -----------------------------------------------------------------
{
  # Anadir texto no es perder texto, y se dice aparte.
  my ($a, $b) = par(
    "<p>La ventana del historial se cierra a los treinta dias exactos.</p>",
    "<p>La ventana del historial se cierra a los treinta dias exactos.</p><p>Y ademas no admite ningun backfill posterior.</p>");
  my ($rc, $out) = run($a, $b);
  check('HIG1 · anadir un parrafo -> OK, y se cuenta como nuevo', $rc, $out, 0, qr/nuevas/);
}
{
  # Solo se mira lo que hay dentro de <main>: el cromo no es contenido nuestro.
  $n++;
  my ($a, $b) = ("$dir/na$n", "$dir/nb$n");
  for my $d ($a, $b) { mkdir $d or die $! }
  open my $f1, '>:encoding(UTF-8)', "$a/index.html" or die $!;
  print $f1 '<!doctype html><html lang="es"><body><p>fuera de main</p></body></html>';
  close $f1;
  open my $f2, '>:encoding(UTF-8)', "$b/index.html" or die $!;
  print $f2 '<!doctype html><html lang="es"><body><p>fuera de main</p></body></html>';
  close $f2;
  my ($rc, $out) = run($a, $b);
  check('HIG2 · sin <main> se DICE, no se aprueba por defecto', $rc, $out, 0, qr/sin <main>/);
}

print "\n  " . '=' x 62 . "\n";
printf "  %d casos en verde  ·  %d en rojo\n", $ok, $bad;
# En DOS lineas a proposito: ver la nota del banco de bots-ia.
printf "  OK %d\n",  $ok;
printf "  MAL %d\n\n", $bad;
exit($bad ? 1 : 0);
