#!/usr/bin/perl
# =============================================================================
#  citable-tests/tests.pl · EL BANCO DE `citable.pl`
# =============================================================================
#  26-ago-2026. Escrito en la misma tanda que el gate.
#
#  El caso que sostiene todo el banco es `LANG3`: una pagina en un idioma SIN
#  patrones tiene que salir NO MEDIDO, no PASA. Un gate que barre una pagina que
#  no entiende y dice 0 hallazgos es la peor version de si mismo: parece
#  cobertura y es un hueco.
#
#  26-ago, tarde: `fr` y `pt` YA se miden, asi que las seis webs del parque
#  estan cubiertas y LANG3/LANG4 pasaron a ALEMAN y NEERLANDES. La regla que
#  prueban no ha cambiado; cambio que idioma la ejemplifica. Si algun dia se
#  anaden esos dos, hay que mover estos casos otra vez: el banco no puede
#  quedarse sin ningun idioma descubierto o deja de probar la regla.
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
  my ($rc, $out) = run(pageof('de', "<p>Der Physiotherapeut kommt zu Ihnen nach Hause und die Sitzung dauert etwa dreissig Minuten pro Termin.</p>"));
  check('LANG3 · pagina en ALEMAN -> NO MEDIDO, nunca PASA', $rc, $out, 3, qr/NO MEDIDO/);
}
{
  my ($rc, $out) = run(pageof('nl', "<p>De kinesitherapeut komt bij u thuis langs en een sessie duurt ongeveer dertig minuten per afspraak.</p>"));
  check('LANG4 · pagina en NEERLANDES -> NO MEDIDO', $rc, $out, 3, qr/NO MEDIDO/);
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

# --- FRANCES · anadido el 26-ago-2026 -----------------------------------------
#  Los seis primeros hallazgos reales -3 en cada uno de los dos sitios en frances- se
#  revisaron A MANO uno por uno y los seis eran genuinos. Estos casos los
#  congelan, y los FP de abajo congelan lo que NO puede volver a saltar.
{
  my ($rc, $out) = run(pageof('fr', "<p>C'est la seule part qui reste a votre charge apres le remboursement de la mutuelle et elle varie selon le statut.</p>"));
  check("FR1 · abre con \"C'est\" -> BLOQUEA", $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  my ($rc, $out) = run(pageof('fr', "<p>Cela depend du type de soins prescrits par le medecin et du nombre de seances prevues dans l ordonnance.</p>"));
  check('FR2 · abre con "Cela" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  my ($rc, $out) = run(pageof('fr', "<p>Ce sont les deux seules situations dans lesquelles la mutuelle refuse le remboursement des seances a domicile.</p>"));
  check('FR3 · abre con "Ce sont" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  my ($rc, $out) = run(pageof('fr', "<p>Comme explique plus haut, la seance dure environ trente minutes et le kinesitherapeute se deplace chez vous.</p>"));
  check('FR4 · "comme explique plus haut" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*anterior/s);
}
{
  # El hallazgo real de ti-care.html: el formulario NO esta arriba para un motor.
  my ($rc, $out) = run(pageof('fr', "<p>Pour prendre rendez vous, remplissez le formulaire ci-dessus et vous serez rappele dans les vingt quatre heures.</p>"));
  check('FR5 · "ci-dessus" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*anterior/s);
}
{
  # 🔴 EL CONTROL QUE JUSTIFICA DEJAR `il`/`elle` FUERA DEL PATRON. En frances
  #    son impersonales la mitad de las veces -il faut, il y a, il s'agit-, y
  #    meterlos reproduciria el 50% de falsos positivos que ya costo el ingles.
  my ($rc, $out) = run(pageof('fr', "<p>Il faut une prescription du medecin traitant pour que la mutuelle rembourse les seances de kinesitherapie.</p>"));
  check('FR6 · "Il faut" es impersonal y NO salta (por eso il/elle estan fuera)', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run(pageof('fr', "<p>Ce cabinet propose des seances de kinesitherapie a domicile pour les patients qui ne peuvent pas se deplacer.</p>"));
  check('FR7 · "Ce cabinet propose" es determinante, NO pronombre huerfano', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run(pageof('fr', "<p>Le remboursement est peut-etre partiel et depend probablement du statut du patient ainsi que de la prescription.</p>"));
  check('FR8 · dos atenuantes franceses -> DEBILITA', $rc, $out, 0, qr/DEBILITA.*atenuantes/s);
}
{
  # 🔑 EL UNICO CASO DEL BANCO QUE PRUEBA %ACC DE VERDAD: el acento esta DENTRO
  #    de la palabra que dispara. `e` con acento ya lo traia el espanol, asi que
  #    no discrimina; `e` con acento GRAVE -dernierement- lo anadio esta tanda.
  #    Los bytes se fabrican aqui, no se teclean: escribirlos a mano en un
  #    fichero que viaja por varias capas es como se doble-codifica sin error.
  my $E_GRAVE = chr(0xC3) . chr(0xA8);   # e con acento grave, en bytes UTF-8
  my ($rc, $out) = run(pageof('fr', "<p>Derni${E_GRAVE}rement, la mutuelle a modifie le montant du ticket moderateur pour les seances a domicile.</p>"));
  check('FR9 · "dernierement" ACENTUADO -> DEBILITA (prueba el desacentuado)', $rc, $out, 0, qr/DEBILITA.*fecha relativa/s);
}

# --- PORTUGUES · anadido el 26-ago-2026 ---------------------------------------
#  Cierra el sexto sitio, que ademas es el UNICO del parque con citas de IA.
{
  my ($rc, $out) = run(pageof('pt', "<p>Isto e o erro mais caro que um cliente comete ao escolher a espessura do vidro do espelho sob medida.</p>"));
  check('PT1 · abre con "Isto" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  my ($rc, $out) = run(pageof('pt', "<p>Este e o modelo mais vendido e sai em qualquer medida ate dois metros de altura sem custo extra.</p>"));
  check('PT2 · abre con "Este e" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  my ($rc, $out) = run(pageof('pt', "<p>Como visto acima, o prazo de entrega e de quinze dias uteis a contar da confirmacao da encomenda.</p>"));
  check('PT3 · "como visto acima" -> BLOQUEA', $rc, $out, 1, qr/BLOQUEA.*anterior/s);
}
{
  my ($rc, $out) = run(pageof('pt', "<p>Este espelho sob medida leva vidro temperado de seis milimetros e chega montado em toda a regiao norte.</p>"));
  check('PT4 · "Este espelho leva" es determinante, NO pronombre huerfano', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  # 🔴 EL CONTROL QUE JUSTIFICA DEJAR `e` ACENTUADO FUERA. Sin acentos se vuelve
  #    la conjuncion «y», que abre una de cada dos frases en portugues. Meterlo
  #    en el patron acusaria a medio sitio.
  my $E_AGUDA = chr(0xC3) . chr(0xA9);
  my ($rc, $out) = run(pageof('pt', "<p>${E_AGUDA} possivel encomendar o espelho com iluminacao integrada e com moldura em qualquer cor do catalogo.</p>"));
  check('PT5 · abre con "E" acentuado y NO salta (por eso esta fuera)', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run(pageof('pt', "<p>A loja mudou recentemente o prazo de producao dos espelhos sob medida para quinze dias uteis.</p>"));
  check('PT6 · "recentemente" -> DEBILITA', $rc, $out, 0, qr/DEBILITA.*fecha relativa/s);
}
{
  # Acentos portugueses por todo el parrafo: no pueden FABRICAR hallazgos.
  # ⚠️ Ningun disparador portugues lleva acento dentro, asi que las altas de
  #    %ACC para `pt` solo se prueban por este lado -- que no rompan-, no por el
  #    de que hagan saltar algo. Dicho aqui para que nadie lea mas cobertura de
  #    la que hay.
  my $A_TILDE = chr(0xC3) . chr(0xA3);   # a con tilde
  my $C_CED   = chr(0xC3) . chr(0xA7);   # c con cedilla
  my $O_TILDE = chr(0xC3) . chr(0xB5);   # o con tilde
  my $body = "A produ${C_CED}${A_TILDE}o do espelho come${C_CED}a apos a confirma${C_CED}${A_TILDE}o e as dimens${O_TILDE}es sao verificadas antes do corte.";
  my ($rc, $out) = run(pageof('pt', "<p>$body</p>"));
  check('PT7 · acentos portugueses NO fabrican hallazgos', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
my $PT_LARGO = 'Nos espelhos sob medida a espessura do vidro decide o preco final, e nos '
  . 'modelos com iluminacao integrada o custo sobe cerca de vinte por cento, porque a fita '
  . 'de led e a fonte de alimentacao entram no orcamento. A entrega chega a toda a regiao '
  . 'norte no prazo combinado, com montagem incluida, e o cliente escolhe a moldura do '
  . 'catalogo sem qualquer custo adicional.';
{
  # 🔴 EL OTRO CONTROL DE COLISION: `nos` sin acento es tambien la contraccion
  #    «en los», y abre parrafos enteros. Fuera del patron generico por eso.
  my ($rc, $out) = run(pageof('pt', "<p>$PT_LARGO</p>"), '--brand', 'Acme');
  check('PT8 · "nos" como contraccion NO se lee como sujeto sin nombrar', $rc, $out, 0, qr/0 bloqueos, 0 debilitan/);
}
{
  # ...y el positivo que prueba que el check no esta muerto para portugues.
  my $con_nossa = $PT_LARGO;
  $con_nossa =~ s/A entrega chega/A nossa equipa entrega/ or die "el fixture de PT9 no caso\n";
  my ($rc, $out) = run(pageof('pt', "<p>$con_nossa</p>"), '--brand', 'Acme');
  check('PT9 · ...pero "nossa equipa" SI (el arreglo no apago el check)', $rc, $out, 0, qr/DEBILITA.*marca/s);
}

# --- EL `it` IMPERSONAL Y LAS CONTRACCIONES · 26-ago-2026, tarde -------------
#  Los seis salen de UN solo hallazgo real en climentmedia (1 de 58), que
#  resulto ser tres defectos apilados: la normalizacion partia `It&rsquo;s` en
#  `It s`, el `it` era impersonal, y ademas el parrafo era una cita textual.
{
  my ($rc, $out) = run(pageof('en', "<p>It is recommended that you run the experiment for at least six weeks before reading it.</p>"));
  check('EXP1 · "It is recommended that" es impersonal -> NO salta', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run(pageof('en', "<p>It&rsquo;s worth noting that the change history window closes at exactly thirty days for everyone.</p>"));
  check('EXP2 · "It\'s worth noting" tampoco (y con la entidad de apostrofo)', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  # ...y el control de que el arreglo no apago el check: un `it` que SI senala.
  my ($rc, $out) = run(pageof('en', "<p>It works out what it would change and shows you first, and nothing moves until you approve.</p>"));
  check('EXP3 · un "it" que SI senala sigue saltando', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  # 🔴 EL CASO QUE OBLIGO A HACER LOS DOS CAMBIOS A LA VEZ. Arreglar solo la
  #    normalizacion habria dejado de ver este, que es un huerfano de verdad.
  my ($rc, $out) = run(pageof('en', "<p>That&rsquo;s the part that fails, and the maths has nothing to do with any of it.</p>"));
  check('CON1 · "That\'s" con entidad SIGUE saltando (contraccion leida)', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  my ($rc, $out) = run(pageof('en', "<p>It&rsquo;s the range we see across accounts, and not a prediction about yours in particular.</p>"));
  check('CON2 · "It\'s" con entidad tambien salta', $rc, $out, 1, qr/BLOQUEA.*pronombre/s);
}
{
  # Una cita no se puede reescribir sin falsearla: se sabe, pero no BLOQUEA.
  my ($rc, $out) = run(pageof('en', "<p>&ldquo;This is the number nobody publishes,&rdquo; the platform documentation says, and it is right.</p>"));
  check('CITA1 · un pronombre DENTRO de una cita -> PULIDO, no BLOQUEA', $rc, $out, 0, qr/PULIDO.*cita textual/s);
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
