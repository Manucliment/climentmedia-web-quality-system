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
  [ 'GPTBot',         'requerido', 'OpenAI, rastreo general' ],
  [ 'OAI-SearchBot',  'requerido', 'OpenAI, el que alimenta la busqueda de ChatGPT' ],
  [ 'ChatGPT-User',   'requerido', 'OpenAI, la peticion en vivo cuando un usuario pregunta' ],
  [ 'ClaudeBot',      'requerido', 'Anthropic, rastreo' ],
  [ 'Claude-User',    'requerido', 'Anthropic, peticion en vivo' ],
  [ 'PerplexityBot',  'requerido', 'Perplexity, rastreo' ],
  [ 'Perplexity-User','requerido', 'Perplexity, peticion en vivo' ],
  [ 'Bingbot',        'requerido', 'alimenta Copilot' ],
  [ 'GoogleOther',    'requerido', 'Google, usos distintos de la busqueda' ],
  [ 'anthropic-ai',   'aviso',     'nombre antiguo de Anthropic; si esta bloqueado y ClaudeBot no, es un resto' ],
  [ 'Google-Extended','aviso',     'NO rastrea: solo controla el uso en Gemini. Bloquearlo no quita de la busqueda' ],
  [ 'Applebot-Extended','aviso',   'idem para Apple Intelligence' ],
);

# --- argumentos ---------------------------------------------------------------
my ($url, $file, $repo, $quiet) = ('', '', '', 0);
my $path = '/';
while (@ARGV) {
  my $a = shift @ARGV;
  if    ($a eq '--url')   { $url  = shift @ARGV // '' }
  elsif ($a eq '--file')  { $file = shift @ARGV // '' }
  elsif ($a eq '--repo')  { $repo = shift @ARGV // '' }
  elsif ($a eq '--path')  { $path = shift @ARGV // '/' }
  elsif ($a eq '--quiet' or $a eq '-q') { $quiet = 1 }
  else { die "argumento desconocido: $a\n" }
}
die "hace falta --url, --file o --repo\n" unless $url or $file or $repo;

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
  print "VEREDICTO: NO MEDIDO (rc=3). Esto NO es un aprobado.\n";
  exit 3;
}
