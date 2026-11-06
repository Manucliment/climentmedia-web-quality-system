#!/usr/bin/perl
# =============================================================================
#  ai-crawlers-tests/tests.pl · EL BANCO DE `ai-crawlers.pl`
# =============================================================================
#  26-ago-2026. Escrito EN LA MISMA TANDA que el gate, no despues.
#
#  Cada caso existe porque un `grep` se equivocaria en el. Los cuatro primeros
#  son las cuatro trampas del parseo de robots.txt que la cabecera del gate
#  enumera; los demas son los controles de arriba y de abajo.
#
#  La pregunta que este banco tiene que contestar no es "pasa?", es:
#  QUE TENDRIA QUE OCURRIR PARA QUE ESTO SE PUSIERA ROJO. Si un caso no puede
#  fallar, no es un caso.
#
#    perl ai-crawlers-tests/tests.pl
#
#  Los fixtures se ESCRIBEN aqui, no se leen de ningun sitio: un banco que
#  depende del arbol vivo mide el arbol, no el gate.
# =============================================================================
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec;
use File::Basename qw(dirname);

my $dir  = tempdir(CLEANUP => 1);
my $here = File::Spec->rel2abs(dirname(__FILE__));
my $GATE = File::Spec->catfile($here, '..', 'ai-crawlers.pl');
die "no encuentro el gate en $GATE\n" unless -f $GATE;

my ($ok, $bad) = (0, 0);

# corre el gate sobre un robots.txt escrito al vuelo
sub run {
  my ($name, $body, $path) = @_;
  my $f = File::Spec->catfile($dir, "$name.txt");
  open my $fh, '>', $f or die $!;
  print $fh $body;
  close $fh;
  my $cmd = qq{"$^X" "$GATE" --file "$f"};
  $cmd .= qq{ --path "$path"} if $path;
  my $out = `$cmd`;
  my $rc = $? >> 8;
  return ($rc, $out);
}

sub check {
  my ($label, $rc, $out, $want_rc, $want_re) = @_;
  my $pass = ($rc == $want_rc) && (!$want_re || $out =~ $want_re);
  if ($pass) { $ok++;  printf "  OK   %s\n", $label }
  else {
    $bad++;
    printf "  MAL  %s\n", $label;
    printf "       esperaba rc=%s%s, salio rc=%s\n", $want_rc,
      ($want_re ? " y /$want_re/" : ''), $rc;
    my @l = grep { /VEREDICTO|BLOQUEADO|NO MEDIDO/ } split /\n/, $out;
    printf "       %s\n", $_ for @l[0..($#l > 3 ? 3 : $#l)];
  }
}

print "\n  BANCO DE ai-crawlers.pl\n";
print "  " . '=' x 60 . "\n\n";

# --- CONTROLES DE ARRIBA Y DE ABAJO ------------------------------------------
{
  my ($rc, $out) = run('permite-todo', "User-agent: *\nDisallow:\n");
  check('permitir todo -> PASA', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  my ($rc, $out) = run('bloquea-todo', "User-agent: *\nDisallow: /\n");
  check('bloquear todo -> FALLA (control negativo)', $rc, $out, 1, qr/VEREDICTO: FALLA/);
}
{
  # El control que mas importa: que nombre AL bot bloqueado, no solo que falle.
  my ($rc, $out) = run('nombra', "User-agent: GPTBot\nDisallow: /\n");
  check('bloquear SOLO GPTBot -> FALLA y lo NOMBRA', $rc, $out, 1, qr/FALLA.*GPTBot/);
}
{
  my ($rc, $out) = run('nombra2', "User-agent: GPTBot\nDisallow: /\n");
  check('...y NO acusa a los demas', $rc, $out, 1, qr/PerplexityBot\s+requerido\s+PUEDE/);
}

# --- TRAMPA 1 · el grupo propio no hereda del `*` ----------------------------
{
  # `*` bloquea todo, pero GPTBot tiene grupo propio que permite.
  my ($rc, $out) = run('grupo-propio-salva',
    "User-agent: *\nDisallow: /\n\nUser-agent: GPTBot\nAllow: /\n");
  check('T1a · grupo propio SALVA a GPTBot del Disallow del *', $rc, $out, 1,
        qr/GPTBot\s+requerido\s+PUEDE/);
}
{
  # La sutil: GPTBot tiene grupo propio SIN reglas Allow/Disallow. No hereda
  # el `Disallow: /` del `*`, asi que puede entrar. Un grep diria lo contrario.
  my ($rc, $out) = run('grupo-propio-vacio',
    "User-agent: *\nDisallow: /\n\nUser-agent: GPTBot\nCrawl-delay: 10\n");
  check('T1b · grupo propio SIN reglas = permitido (no hereda el *)', $rc, $out, 1,
        qr/GPTBot\s+requerido\s+PUEDE/);
}
{
  # Y el sentido contrario del mismo caso: el `*` permitia, pero el grupo
  # propio bloquea. Aqui el grep que busca "Allow: /" tambien se equivoca.
  my ($rc, $out) = run('grupo-propio-bloquea',
    "User-agent: *\nAllow: /\n\nUser-agent: ClaudeBot\nDisallow: /\n");
  check('T1c · grupo propio BLOQUEA aunque el * permita', $rc, $out, 1,
        qr/FALLA.*ClaudeBot/);
}
{
  # Varios User-agent seguidos comparten el mismo grupo.
  my ($rc, $out) = run('agentes-compartidos',
    "User-agent: GPTBot\nUser-agent: ClaudeBot\nDisallow: /\n");
  check('T1d · dos User-agent seguidos comparten grupo', $rc, $out, 1,
        qr/FALLA.*(GPTBot.*ClaudeBot|ClaudeBot.*GPTBot)/);
}
{
  # 26-sep-2026 · Claude-SearchBot no estaba en la lista: bloquear la BUSQUEDA de
  # Claude salia en verde. Es el caso que el gate anterior aprobaba.
  my ($rc, $out) = run('claude-searchbot-bloqueado',
    "User-agent: *\nAllow: /\n\nUser-agent: Claude-SearchBot\nDisallow: /\n");
  check('T1e · bloquear Claude-SearchBot (la busqueda de Claude) FALLA', $rc, $out, 1,
        qr/FALLA.*Claude-SearchBot/);
}

# --- TRAMPA 2 · gana la ruta MAS LARGA ---------------------------------------
{
  my $body = "User-agent: *\nDisallow: /\nAllow: /learn/\n";
  my ($rc, $out) = run('mas-larga-permite', $body, '/learn/algo/');
  check('T2a · Disallow:/ + Allow:/learn/ -> /learn/algo PERMITIDO', $rc, $out, 0,
        qr/VEREDICTO: PASA/);
}
{
  my $body = "User-agent: *\nDisallow: /\nAllow: /learn/\n";
  my ($rc, $out) = run('mas-larga-bloquea', $body, '/');
  check('T2b · ...y la raiz sigue BLOQUEADA', $rc, $out, 1, qr/VEREDICTO: FALLA/);
}
{
  # Al reves: permitir todo pero bloquear una rama concreta.
  my $body = "User-agent: *\nAllow: /\nDisallow: /privado/\n";
  my ($rc, $out) = run('rama-bloqueada', $body, '/privado/x');
  check('T2c · Allow:/ + Disallow:/privado/ -> /privado/x BLOQUEADO', $rc, $out, 1,
        qr/VEREDICTO: FALLA/);
}

# --- TRAMPA 3 · `Disallow:` vacio permite ------------------------------------
{
  my ($rc, $out) = run('disallow-vacio', "User-agent: *\nDisallow:\nDisallow: /x\n");
  check('T3 · Disallow vacio NO bloquea', $rc, $out, 0, qr/VEREDICTO: PASA/);
}

# --- TRAMPA 4 · mayusculas ---------------------------------------------------
{
  my ($rc, $out) = run('minusculas', "user-agent: gptbot\ndisallow: /\n");
  check('T4 · el agente en minusculas casa igual', $rc, $out, 1, qr/FALLA.*GPTBot/);
}

# --- HIGIENE DEL PARSEO ------------------------------------------------------
{
  my ($rc, $out) = run('comentarios',
    "# esto es un comentario\nUser-agent: *   # y esto tambien\nDisallow: /  # bloquea\n");
  check('los comentarios se ignoran', $rc, $out, 1, qr/VEREDICTO: FALLA/);
}
{
  my ($rc, $out) = run('crlf', "User-agent: *\r\nDisallow: /\r\n");
  check('acepta finales de linea CRLF', $rc, $out, 1, qr/VEREDICTO: FALLA/);
}
{
  my ($rc, $out) = run('vacio', "\n\n");
  check('robots.txt vacio = permitir todo', $rc, $out, 0, qr/VEREDICTO: PASA/);
}
{
  # Los de nivel AVISO no pueden tumbar el gate: bloquear Google-Extended es
  # una decision legitima -no quita de la busqueda-, y confundirla con un
  # fallo es como un gate empieza a estorbar y acaba desactivado.
  my ($rc, $out) = run('aviso-no-falla',
    "User-agent: Google-Extended\nDisallow: /\n");
  check('un bot de AVISO bloqueado NO tumba el gate', $rc, $out, 0,
        qr/VEREDICTO: PASA.*aviso/s);
}

# --- FICHERO QUE NO EXISTE ---------------------------------------------------
{
  my $out = `"$^X" "$GATE" --file "$dir/no-existe-jamas.txt"`;
  my $rc = $? >> 8;
  check('sin robots.txt -> PASA, y lo dice', $rc, $out, 0, qr/NO EXISTE/);
}

# --- NO MEDIDO ---------------------------------------------------------------
{
  # Un host que no resuelve NO puede dar un veredicto. Tiene que salir 3.
  my $out = `"$^X" "$GATE" --url "https://no-existe-jamas.invalid/"`;
  my $rc = $? >> 8;
  check('host que no resuelve -> NO MEDIDO (rc=3), no un aprobado', $rc, $out, 3,
        qr/NO MEDIDO/);
}

# --- LA SONDA (--probe, 6-nov-2026) -------------------------------------------
# robots.txt deja entrar y el CDN no: 429 sin Retry-After a la firma de GPTBot en 7
# de 10 webs, con este gate en PASA en las 7. Un servidor propio en 127.0.0.1 (el de
# receipt-tests, con su `_ua.txt`: «trozo codigo [Retry-After]») hace de ese CDN.
# Con centinela: un puerto ocupado por otra sesion mediria OTRA cosa. Todos los
# casos, en ROJO contra el gate de antes (no conocia --probe).
{
  my $root = File::Spec->catdir($dir, 'sitio');
  mkdir $root;
  my $esc = sub { my ($n, $t) = @_; open my $f, '>', File::Spec->catfile($root, $n) or die $!; print $f $t; close $f };
  $esc->('robots.txt', "User-agent: *\nAllow: /\n");
  $esc->('index.html', "<h1>hola</h1>\n");
  my $cent = "centinela-$$-" . time;
  $esc->('_sentinel.txt', "$cent\n");
  # 🔴 10000-14999, y no 8600-8899: ese es el del servidor del 404 de qa-master-tests
  #    (y cae dentro del de los bancos del recibo). La primera version copio su formula,
  #    y las dos corridas a la vez se quitaron el puerto: 3 MAL en qa-master el 6-nov.
  #    Y si esta ocupado, el siguiente: el servidor muere sin ReuseAddr, y el centinela lo ve.
  my $srvpl = File::Spec->catfile($here, '..', 'receipt-tests', 'test-server.pl');
  my ($port, $pid, $srv, $vivo);
  for my $i (0 .. 4) {
    $port = 10000 + (($$ + $i * 977) % 5000);
    $pid = open($srv, '-|', $^X, $srvpl, $root, $port);
    my $listo = $pid ? <$srv> : undef;
    $vivo = defined $listo && `curl -s -m 5 "http://127.0.0.1:$port/_sentinel.txt" 2>/dev/null` =~ /\Q$cent\E/;
    last if $vivo;
    if ($pid) { kill 'TERM', $pid; close $srv; $pid = 0 }
  }
  if (!$vivo) {
    $bad++;
    print "  MAL  SONDA: no arranco mi servidor en el puerto $port (o contesta otro): nada de la sonda se ha medido\n";
  } else {
    my $sonda = sub {   # (etiqueta, _ua.txt o '', rc esperado, lo que TIENE que salir, lo que NO puede salir)
      my ($label, $ua, $want_rc, $si, $no) = @_;
      my $uf = File::Spec->catfile($root, '_ua.txt');
      if (length $ua) { $esc->('_ua.txt', $ua) } else { unlink $uf }
      my $out = `"$^X" "$GATE" --url "http://127.0.0.1:$port/" --probe 2>&1`;
      my $rc = $? >> 8;
      check($label, $rc, $out, $want_rc, $si);
      if ($no && $out =~ $no) { $ok--; $bad++; printf "  MAL  %s (y sale lo que no debe: /%s/)\n", $label, $no }
    };
    # 🔴 EL CASO DEL 6-NOV: robots.txt abierto, el CDN da 429 a GPTBot y robots.txt PASA.
    $sonda->('SONDA · GPTBot 429 sin Retry-After: AVISO, y robots.txt sigue en PASA', "GPTBot 429\n", 0,
             qr/SONDA: AVISO - 1 bot.*GPTBot \(entrena\): 429 en robots\.txt, sin Retry-After \(Server: cdn-de-prueba\); 429 en la pagina.*\nVEREDICTO: PASA/s);
    $sonda->('SONDA · con Retry-After lo dice', "GPTBot 429 120\n", 0, qr/GPTBot \(entrena\): 429 en robots\.txt, Retry-After 120/, qr/sin Retry-After/);
    $sonda->('SONDA · un bot que BUSCA cortado: AVISO y lo llama «busca»', "OAI-SearchBot 403\n", 0, qr/SONDA: AVISO.*OAI-SearchBot \(busca\): 403/);
    $sonda->('SONDA · la peticion del usuario cortada: AVISO', "Claude-User 503\n", 0, qr/SONDA: AVISO.*Claude-User \(usuario\): 503 en robots\.txt, sin Retry-After/);
    # NEGATIVOS: lo que NO es un aviso
    $sonda->('SONDA · todos como Chrome: PASA', '', 0, qr/SONDA: PASA - los 10 bots/, qr/SONDA: AVISO/);
    $sonda->('SONDA · Googlebot y bingbot 403 con firma falsa: esperado, PASA', "Googlebot 403\nbingbot 403\n", 0,
             qr/SONDA: PASA - los 8 bots.*Googlebot y bingbot reciben 403 con firma falsa: lo esperado/, qr/SONDA: AVISO/);
    $sonda->('SONDA · Googlebot con 429 no es «esperado»: AVISO', "Googlebot 429\n", 0, qr/SONDA: AVISO.*Googlebot: 429/);
    $sonda->('SONDA · Chrome tampoco entra: NO MEDIDO, no un aviso por bot', "Mozilla 503\n", 0, qr/SONDA: NO MEDIDO - Chrome recibe 503/, qr/SONDA: (AVISO|PASA)/);
  }
  kill 'TERM', $pid if $pid;
  close $srv if $pid;
  my $out = `"$^X" "$GATE" --file "$dir/x.txt" --probe 2>&1`;
  my $rc = $? >> 8;
  check('SONDA · sin --url no se finge: error que lo dice', ($rc ? 1 : 0), $out, 1, qr/la sonda \(--probe\) necesita --url/);
}

# --- REDIRECCION (necesita red Y un sitio que redirija) ----------------------
# Este caso existe porque la PRIMERA CORRIDA REAL lo encontro: con el banco en
# verde -19 casos, todos verdes- uno de los seis sitios medidos devolvia 301 de
# apex a www y salia NO MEDIDO. El banco sabia probar el gate y no sabia leer
# el mundo.
#
# 🔴 EL SITIO NO VA ESCRITO AQUI, y no es pudor: este repositorio es publico y
#    un banco que nombra un dominio ajeno lo expone y ademas le manda trafico
#    cada vez que alguien corre las pruebas. Se declara con una variable:
#
#      AI_CRAWLERS_REDIRECT_URL=https://tu-sitio.ejemplo/ perl tests.pl
#
#    Sin ella el caso sale NO MEDIDO, que es la respuesta honesta: no se ha
#    comprobado. Es la misma decision que `freeze-fixture.pl` para las capturas.
#
# Depende de un tercero, asi que NO puede ponerse rojo por que el tercero este
# caido: si no hay red, se declara NO MEDIDO y se dice. Un caso que falla por
# causas ajenas se acaba ignorando, y entonces deja de proteger.
my $no_medidos = 0;
{
  my $url = $ENV{AI_CRAWLERS_REDIRECT_URL} || '';
  if (!length $url) {
    $no_medidos++;
    print "  ---  RED · redireccion: NO MEDIDO (define AI_CRAWLERS_REDIRECT_URL"
        . " con un sitio tuyo que redirija apex->www)\n";
  } else {
    my $base = $url; $base =~ s{/+$}{};
    my $probe = `curl -sI --max-redirs 0 -o /dev/null -w "%{http_code}" -m 15 "$base/robots.txt" 2>/dev/null`;
    if (defined $probe and $probe =~ /^30[128]$/) {
      my $out = `"$^X" "$GATE" --url "$base/"`;
      my $rc = $? >> 8;
      check('RED · sigue la redireccion y NOMBRA la URL final',
            $rc, $out, 0, qr{robots\.txt:\s+\S+robots\.txt.*redireccion}s);
    } else {
      $no_medidos++;
      print "  ---  RED · redireccion: NO MEDIDO (el sitio no devolvio un 30x; salio '"
          . (defined $probe ? $probe : 'sin respuesta') . "')\n";
    }
  }
}

print "\n  " . '=' x 60 . "\n";
printf "  %d casos en verde  ·  %d en rojo%s\n", $ok, $bad,
  ($no_medidos ? "  ·  $no_medidos NO MEDIDO" : '');
# Recuento para el runner. `run-all.sh` lo lee con `OK +N` / `MAL +N` y, si no
# lo encuentra, imprime «no he sabido leer su recuento» y suma CERO al total,
# que es el unico numero que alguien lee. Su propio comentario lo llama «un
# cero con cara de aprobado».
#
# 🔴 VAN EN DOS LINEAS, Y NO ES ESTETICA. En una sola -«OK 20  MAL 0»- la
# alternancia del runner incluye `[0-9]+ +MAL`, que casa con «20  MAL» y le
# hace leer n_mal=20: este banco, con sus 20 casos EN VERDE, se contaba como
# 20 EN ROJO. Medido antes de dejarlo. En dos lineas ningun patron cruza.
printf "  OK %d\n",  $ok;
printf "  MAL %d\n\n", $bad;
exit($bad ? 1 : 0);
