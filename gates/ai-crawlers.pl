#!/usr/bin/perl
# =============================================================================
#  ai-crawlers.pl · PUEDEN ENTRAR LOS BOTS DE IA, O TODO LO DEMAS DA IGUAL
# =============================================================================
#  26-ago-2026. Barrido sobre los 34 gates, el blueprint y los docs de este
#  sistema buscando los nombres de los rastreadores de IA:
#
#      GPTBot 0 · PerplexityBot 0 · ClaudeBot 0 · "AI Overview" 0
#
#  Cero. El estandar de pagina tiene 256 reglas y NINGUNA mira si un motor de
#  respuestas puede alcanzar la pagina. Generamos `llms.txt` y lo cerramos con
#  un gate; nadie habia comprobado nunca si el bot que deberia leerlo tiene
#  permiso para entrar.
#
#  La regla viene de la skill `seo-intel` (gtm-skills, MIT), y es la primera de
#  su lista por un motivo: si los bots no pueden rastrear, ninguna optimizacion
#  de contenido importa. Es barato y cubre las 6 webs de una pasada.
#
#  POR QUE NO ES UN `grep`. Un `grep -c GPTBot robots.txt` mide mi hipotesis,
#  no el hecho, y falla en los cuatro casos que de verdad ocurren:
#
#   1. Un bot con grupo PROPIO deja de heredar el grupo `*` POR COMPLETO. Un
#      `User-agent: GPTBot` seguido solo de `Crawl-delay: 10` NO hereda el
#      `Allow: /` del `*`: se queda sin reglas, que es permitir todo. Pero si
#      el `*` tenia `Disallow: /`, el bot con grupo propio SE SALVA. Los dos
#      sentidos importan y un grep no ve ninguno.
#   2. Gana la ruta MAS LARGA, no la primera ni la ultima. `Disallow: /` con
#      `Allow: /blog/` permite `/blog/x`. Al reves tambien.
#   3. `Disallow:` vacio significa PERMITIR TODO. Un grep de "Disallow" lo
#      cuenta como bloqueo.
#   4. Los nombres de agente son insensibles a mayusculas: `gptbot` es GPTBot.
#
#  QUE DEVUELVE
#    0  medido, y todos los bots requeridos pueden entrar
#    1  medido, y al menos uno esta bloqueado
#    3  NO MEDIDO -no se pudo leer robots.txt-. No es un aprobado.
#
#  Un `robots.txt` que da 404 es PERMITIR TODO por el estandar, y eso se
#  reporta como 0 diciendolo. Un timeout o un 500 es 3: no se sabe.
#
#  USO
#    perl ai-crawlers.pl --url https://example.com/
#    perl ai-crawlers.pl --file ruta/robots.txt
#    perl ai-crawlers.pl --repo DIR            (busca DIR/robots.txt)
#    perl ai-crawlers.pl --url URL --path /learn/algo/   (ruta a comprobar)
#    perl ai-crawlers.pl ... --quiet           (solo el veredicto)
#    perl ai-crawlers.pl --url URL --probe     (y la SONDA: ver abajo; --sonda)
#
#  LA SONDA (--probe, 6-nov-2026). robots.txt dice si un bot PUEDE entrar; no dice
#  si el servidor le DEJA. Un benchmark de GEO de otra agencia encontro un servidor
#  que daba 503 sin Retry-After a los rastreos en bloque con robots.txt abierto, y
#  ese mismo dia, medido desde este sistema: el CDN de un hosting compartido daba
#  429, sin cuerpo y sin Retry-After, a la firma de GPTBot en 7 de 10 webs, tambien
#  en robots.txt, con robots.txt dejandole entrar. Este gate daba PASA en las 7.
#  Con --probe pide robots.txt y la pagina (--path) con la firma (User-Agent) de cada
#  bot y con la de Chrome, y dice el codigo, Retry-After y Server cuando no es el de
#  Chrome. Separa los que BUSCAN y citan (y la peticion del usuario) de los que
#  ENTRENAN. Googlebot y bingbot con firma falsa reciben 403 de un CDN que comprueba
#  su IP: es lo esperado y no avisa. LIMITE, dicho: es la firma desde ESTA IP, no la
#  IP del bot; uno con su IP verificada puede recibir otra cosa. Por eso avisa y no
#  falla: la linea SONDA no cambia el codigo de salida.
#      SONDA: PASA | AVISO | NO MEDIDO - ...
#
#  Cada linea de salida dice QUE REGLA decidio, para que se pueda verificar sin
#  volver a abrir el fichero. Un veredicto sin su evidencia no es medible.
# =============================================================================
use strict;
use warnings;

# --- los bots, y por que esta cada uno ---------------------------------------
# Es una lista con fecha, no un dogma. Se revisa cuando cambie el mercado.
my @BOTS = (
  [ 'Googlebot',      'requerido', 'el billete de entrada: las citas de AI Overviews salen casi siempre del top-5 organico' ],
  [ 'GPTBot',         'requerido', 'OpenAI, entrenamiento de modelos. Bloquearlo NO quita de la busqueda de ChatGPT: eso es OAI-SearchBot' ],
  [ 'OAI-SearchBot',  'requerido', 'OpenAI, el que alimenta la busqueda de ChatGPT' ],
  [ 'ChatGPT-User',   'requerido', 'OpenAI, la peticion en vivo cuando un usuario pregunta' ],
  [ 'ClaudeBot',      'requerido', 'Anthropic, entrenamiento de modelos' ],
  # 26-sep-2026 · faltaba. La pagina de rastreadores de Anthropic (abr-2026) separa tres:
  # ClaudeBot (entrenamiento), Claude-SearchBot (el indice de busqueda) y Claude-User (la
  # peticion del usuario, que SI respeta robots.txt). Sin este, un robots.txt que bloqueara
  # la busqueda de Claude salia en verde.
  [ 'Claude-SearchBot','requerido', 'Anthropic, el indice de la busqueda de Claude' ],
  [ 'Claude-User',    'requerido', 'Anthropic, peticion en vivo (respeta robots.txt)' ],
  [ 'PerplexityBot',  'requerido', 'Perplexity, rastreo' ],
  [ 'Perplexity-User','requerido', 'Perplexity, peticion en vivo' ],
  [ 'Bingbot',        'requerido', 'alimenta Copilot' ],
  [ 'GoogleOther',    'requerido', 'Google, usos distintos de la busqueda' ],
  [ 'anthropic-ai',   'aviso',     'nombre antiguo de Anthropic; si esta bloqueado y ClaudeBot no, es un resto' ],
  [ 'Google-Extended','aviso',     'NO rastrea: solo controla el uso en Gemini. Bloquearlo no quita de la busqueda' ],
  [ 'Applebot-Extended','aviso',   'idem para Apple Intelligence' ],
);

# --- argumentos ---------------------------------------------------------------
my ($url, $file, $repo, $quiet, $probe) = ('', '', '', 0, 0);
my $path = '/';
while (@ARGV) {
  my $a = shift @ARGV;
  if    ($a eq '--url')   { $url  = shift @ARGV // '' }
  elsif ($a eq '--file')  { $file = shift @ARGV // '' }
  elsif ($a eq '--repo')  { $repo = shift @ARGV // '' }
  elsif ($a eq '--path')  { $path = shift @ARGV // '/' }
  elsif ($a eq '--quiet' or $a eq '-q') { $quiet = 1 }
  elsif ($a eq '--probe' or $a eq '--sonda') { $probe = 1 }
  else { die "argumento desconocido: $a\n" }
}
die "hace falta --url, --file o --repo\n" unless $url or $file or $repo;
die "la sonda (--probe) necesita --url: mide lo que contesta el servidor, no un fichero\n" if $probe and not $url;

# --- la sonda: lo que contesta el servidor a la firma de cada bot -------------
# Las firmas, como las publican sus duenos (6-nov-2026). La de Claude-SearchBot se
# escribe como las otras dos de Anthropic: un CDN casa por el nombre, no por la cadena.
my @SONDA = (
  [ 'Chrome',           'referencia', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36' ],
  [ 'OAI-SearchBot',    'busca',      'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; OAI-SearchBot/1.0; +https://openai.com/searchbot' ],
  [ 'ChatGPT-User',     'usuario',    'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; ChatGPT-User/1.0; +https://openai.com/bot' ],
  [ 'Claude-SearchBot', 'busca',      'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Claude-SearchBot/1.0; +Claude-SearchBot@anthropic.com)' ],
  [ 'Claude-User',      'usuario',    'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Claude-User/1.0; +Claude-User@anthropic.com)' ],
  [ 'PerplexityBot',    'busca',      'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; PerplexityBot/1.0; +https://perplexity.ai/perplexitybot)' ],
  [ 'Perplexity-User',  'usuario',    'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Perplexity-User/1.0; +https://perplexity.ai/perplexity-user)' ],
  [ 'GPTBot',           'entrena',    'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)' ],
  [ 'ClaudeBot',        'entrena',    'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ClaudeBot/1.0; +claudebot@anthropic.com)' ],
  [ 'Googlebot',        'verificado', 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' ],
  [ 'bingbot',          'verificado', 'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)' ],
);
# (codigo, Retry-After, Server) de la ULTIMA respuesta: con -L, -D trae las de cada salto.
sub pide {
  my ($u, $ua) = @_;
  return ('0', '', '') if $u =~ /'/ or $ua =~ /'/;
  my $h = `curl -sL --max-redirs 5 -o /dev/null -D - -m 20 -A '$ua' '$u' 2>/dev/null`;
  my @r = grep { /^HTTP\// } split /\r?\n\r?\n/, ($h // '');
  return ('0', '', '') unless @r;
  my ($code) = $r[-1] =~ m{^HTTP/\S+\s+(\d{3})};
  my ($ra)   = $r[-1] =~ /^Retry-After:\s*(\S+)/mi;
  my ($sv)   = $r[-1] =~ /^Server:\s*(\S+)/mi;
  return ($code // '0', $ra // '', $sv // '');
}
my $SONDA_HECHA = 0;
sub sonda {
  return unless $probe and $url and not $SONDA_HECHA++;
  (my $base = $url) =~ s{^(https?://[^/]+).*$}{$1};
  my $pag = $base . ($path =~ m{^/} ? $path : "/$path");
  my %r;
  for my $s (@SONDA) { $r{$s->[0]} = [ [ pide("$base/robots.txt", $s->[2]) ], [ pide($pag, $s->[2]) ] ] }
  my ($cr, $cp) = ($r{Chrome}[0][0], $r{Chrome}[1][0]);
  unless ($quiet) {
    print "\nSONDA: la firma de cada bot desde esta IP (robots.txt y $pag)\n";
    printf "  %-17s %-10s %-24s %s\n", 'BOT', 'QUE HACE', 'robots.txt', 'pagina';
    for my $s (@SONDA) {
      my @c = map { my ($k, $ra, $sv) = @$_; $k . ($k =~ /^(?:429|503)$/ ? ($ra ne '' ? " Retry-After $ra" : ' sin Retry-After') : '') } @{ $r{$s->[0]} };
      printf "  %-17s %-10s %-24s %s\n", $s->[0], $s->[1], @c;
    }
  }
  if ($cp !~ /^2/) {
    print "SONDA: NO MEDIDO - Chrome recibe $cp en $pag: sin una referencia que entre, no se puede decir que un bot recibe otra cosa\n";
    return;
  }
  my (@aviso, @esperado);
  for my $s (@SONDA[1 .. $#SONDA]) {
    my ($n, $rol) = @$s;
    my @mal;
    for my $i (0, 1) {
      my ($k, $ra, $sv) = @{ $r{$n}[$i] };
      my $ref = $i ? $cp : $cr;
      next if $k eq $ref or $k =~ /^[23]/;
      push @mal, sprintf('%s en %s%s%s', $k, ($i ? 'la pagina' : 'robots.txt'),
                         ($k =~ /^(?:429|503)$/ ? ($ra ne '' ? ", Retry-After $ra" : ', sin Retry-After') : ''),
                         ($sv ne '' ? " (Server: $sv)" : ''));
    }
    next unless @mal;
    if ($rol eq 'verificado' and not grep { !/^403 / } @mal) { push @esperado, $n; next }
    push @aviso, "$n" . ($rol eq 'entrena' ? ' (entrena)' : $rol eq 'verificado' ? '' : " ($rol)") . ': ' . join('; ', @mal);
  }
  my $esp = @esperado ? ' · ' . join(' y ', @esperado) . ' reciben 403 con firma falsa: lo esperado, el CDN comprueba su IP' : '';
  if (@aviso) {
    print "SONDA: AVISO - " . scalar(@aviso) . " bot(s) reciben con su firma otra cosa que Chrome ($cp): " . join(' · ', @aviso) . "$esp\n";
    print "  robots.txt les deja entrar o no (tabla de arriba); esto es lo que el SERVIDOR les contesta. Los que entrenan\n"
        . "  no quitan de las respuestas con busqueda; los que buscan y la peticion del usuario, si. Medido con la firma\n"
        . "  desde esta IP: con su IP verificada, un bot puede recibir otra cosa (lo dice el ajuste del CDN o sus logs).\n"
      unless $quiet;
  } else {
    print "SONDA: PASA - los " . (scalar(@SONDA) - 1 - @esperado) . " bots que buscan, citan o entrenan reciben lo mismo que Chrome ($cp)$esp\n";
  }
}

# --- conseguir el robots.txt --------------------------------------------------
my ($text, $origin, $status);

if ($repo) { $file = "$repo/robots.txt" unless $file }

if ($file) {
  $origin = $file;
  if (-f $file) {
    open my $fh, '<', $file or do { no_medido("no se pudo abrir $file: $!") };
    local $/; $text = <$fh>; close $fh;
    $status = 'fichero local';
  } else {
    # En un repo, que no exista robots.txt es un HECHO medido, no un fallo de
    # medicion: el estandar dice que sin robots.txt se permite todo. Pero para
    # un sitio que se va a publicar es casi siempre un descuido, asi que se
    # dice en voz alta.
    print "robots.txt NO EXISTE en $file\n" unless $quiet;
    print "Por el estandar eso PERMITE TODO, asi que ningun bot esta bloqueado.\n" unless $quiet;
    print "VEREDICTO: PASA (sin robots.txt)\n";
    exit 0;
  }
} else {
  my $base = $url; $base =~ s{/+$}{};
  $base =~ s{^(https?://[^/]+).*$}{$1};
  $origin = "$base/robots.txt";
  # -L y hasta 5 saltos A PROPOSITO: un `robots.txt` detras de una redireccion
  # apex -> www es lo normal, y los buscadores la siguen. La primera version no
  # lo hacia, y en la primera corrida contra sitios reales uno de los seis -301
  # de apex a www, un salto, 200- salio NO MEDIDO. El banco estaba en verde: 19
  # casos, todos verdes, y no sabia leer el mundo.
  # Se reporta la URL FINAL, no la pedida, para que se vea que hubo salto.
  my $probe = `curl -sL --max-redirs 5 -o /dev/null -w "%{http_code} %{num_redirects} %{url_effective}" -m 20 -A "ai-crawlers.pl/1.0" "$origin" 2>/dev/null`;
  my ($code, $hops, $eff) = split /\s+/, ($probe // ''), 3;
  $code = '0' unless defined $code and $code =~ /^\d+$/;
  $hops = 0   unless defined $hops and $hops =~ /^\d+$/;
  $eff  = $origin unless defined $eff and length $eff;
  $origin = $eff;
  if ($code eq '404' or $code eq '410') {
    print "robots.txt devuelve $code en $origin\n" unless $quiet;
    print "Por el estandar eso PERMITE TODO.\n" unless $quiet;
    sonda();
    print "VEREDICTO: PASA (robots.txt $code)\n";
    exit 0;
  }
  no_medido("robots.txt devolvio HTTP $code en $origin") unless $code eq '200';
  $text = `curl -sL --max-redirs 5 -m 20 -A "ai-crawlers.pl/1.0" "$origin" 2>/dev/null`;
  no_medido("robots.txt vino vacio con HTTP 200 en $origin") unless defined $text and length $text;
  $status = $hops ? "HTTP 200 tras $hops redireccion(es)" : "HTTP 200";
}

# --- parseo de robots.txt -----------------------------------------------------
# Devuelve: { agente_en_minusculas => [ [ 'allow'|'disallow', ruta ], ... ] }
# Varias lineas User-agent seguidas comparten el mismo grupo de reglas.
sub parse_robots {
  my ($t) = @_;
  my %g;
  my @current;        # agentes que comparten el grupo que se esta leyendo
  my $seen_rule = 0;  # si ya vimos una regla, un User-agent nuevo abre grupo
  for my $line (split /\r?\n/, $t) {
    $line =~ s/#.*$//;            # comentarios
    $line =~ s/^\s+|\s+$//g;
    next unless length $line;
    my ($field, $value) = $line =~ /^([A-Za-z-]+)\s*:\s*(.*)$/ or next;
    $field = lc $field;
    if ($field eq 'user-agent') {
      if ($seen_rule) { @current = (); $seen_rule = 0 }
      push @current, lc $value;
      $g{lc $value} ||= [];
      next;
    }
    next unless @current;
    if ($field eq 'allow' or $field eq 'disallow') {
      $seen_rule = 1;
      push @{ $g{$_} }, [ $field, $value ] for @current;
    }
  }
  return \%g;
}

# Decide si $agent puede pedir $p. Devuelve (1|0, "la regla que decidio").
sub allows {
  my ($g, $agent, $p) = @_;
  my $key = lc $agent;
  my $group;
  if (exists $g->{$key})     { $group = $g->{$key};  }
  elsif (exists $g->{'*'})   { $group = $g->{'*'}; $key = '*' }
  else { return (1, 'no hay grupo aplicable -> permitido') }

  # Gana la ruta MAS LARGA. A igual longitud, gana Allow.
  my ($best_len, $best_type, $best_raw) = (-1, '', '');
  for my $r (@$group) {
    my ($type, $pat) = @$r;
    # `Disallow:` vacio = no bloquea nada. `Allow:` vacio se ignora igual.
    next unless length $pat;
    next unless match_path($pat, $p);
    my $len = length $pat;
    if ($len > $best_len or ($len == $best_len and $type eq 'allow')) {
      ($best_len, $best_type, $best_raw) = ($len, $type, "$type: $pat");
    }
  }
  if ($best_len < 0) {
    my $why = @$group ? "ninguna regla del grupo [$key] casa con $p" : "el grupo [$key] no tiene reglas";
    return (1, "$why -> permitido");
  }
  return ($best_type eq 'allow' ? 1 : 0, "[$key] $best_raw");
}

# Comodines del estandar: * cualquier cosa, $ fin de cadena.
sub match_path {
  my ($pat, $p) = @_;
  my $rx = '';
  for my $ch (split //, $pat) {
    if    ($ch eq '*') { $rx .= '.*' }
    elsif ($ch eq '$') { $rx .= '\z' }
    else               { $rx .= quotemeta $ch }
  }
  return $p =~ /^$rx/;
}

# --- correr -------------------------------------------------------------------
my $groups = parse_robots($text);

my (@blocked, @warned, @ok);
my @rows;
for my $b (@BOTS) {
  my ($name, $level, $why) = @$b;
  my ($can, $rule) = allows($groups, $name, $path);
  push @rows, [ $name, $level, ($can ? 'PUEDE' : 'BLOQUEADO'), $rule, $why ];
  if ($can)                     { push @ok,      $name }
  elsif ($level eq 'requerido') { push @blocked, $name }
  else                          { push @warned,  $name }
}

unless ($quiet) {
  print "robots.txt: $origin ($status)\n";
  print "ruta comprobada: $path\n\n";
  printf "  %-20s %-10s %-10s %s\n", 'BOT', 'NIVEL', 'VEREDICTO', 'REGLA QUE DECIDIO';
  printf "  %-20s %-10s %-10s %s\n", '-' x 20, '-' x 10, '-' x 10, '-' x 30;
  for my $r (@rows) { printf "  %-20s %-10s %-10s %s\n", @$r[0..3] }
  print "\n";
  if (@blocked) {
    print "BLOQUEADOS y son requeridos:\n";
    for my $r (@rows) { print "  - $r->[0]: $r->[4]\n" if $r->[2] eq 'BLOQUEADO' and $r->[1] eq 'requerido' }
    print "\n";
  }
  if (@warned) {
    print "Bloqueados pero solo AVISO (puede ser deliberado):\n";
    for my $r (@rows) { print "  - $r->[0]: $r->[4]\n" if $r->[2] eq 'BLOQUEADO' and $r->[1] eq 'aviso' }
    print "\n";
  }
}

sonda();
if (@blocked) {
  printf "VEREDICTO: FALLA - %d requerido(s) bloqueado(s): %s\n", scalar @blocked, join(', ', @blocked);
  exit 1;
}
printf "VEREDICTO: PASA - %d de %d pueden entrar%s\n",
  scalar @ok, scalar @BOTS,
  (@warned ? sprintf(' (%d aviso: %s)', scalar @warned, join(', ', @warned)) : '');
exit 0;

sub no_medido {
  my ($why) = @_;
  print "NO MEDIDO: $why\n";
  sonda();   # un robots.txt que no contesta puede ser el mismo CDN: la sonda lo dice
  print "VEREDICTO: NO MEDIDO (rc=3). Esto NO es un aprobado.\n";
  exit 3;
}
