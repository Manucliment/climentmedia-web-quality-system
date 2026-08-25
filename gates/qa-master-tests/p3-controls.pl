#!/usr/bin/env perl
# Controles del enlace de salto (P3). Extrae las subs REALES de qa-master.pl
# y las evalua: mide el codigo que se despliega, no una copia.
use strict; use warnings; use utf8;
use File::Basename qw(dirname);
binmode(STDOUT, ':encoding(UTF-8)');
#  Self-locating, for the reason in trap §7.
my $SRC = shift(@ARGV) // (dirname(__FILE__) . '/../qa-master.pl');
my $src = do { open my $f,'<:encoding(UTF-8)',$SRC or die "$SRC: $!"; local $/; <$f> };
my $code = '';
for my $n (qw(strip_code tag_text attr tiene_skip_link)) {
    my ($s) = $src =~ /^(sub \Q$n\E\s+\{.*\})[ \t]*$/m;         # sub de una linea
    ($s)    = $src =~ /^(sub \Q$n\E\s+\{.*?^\})/ms unless $s;   # sub multilinea
    die "no encuentro sub $n\n" unless $s;
    $code .= "$s\n";
}
eval $code; die $@ if $@;

my $NAV = '<nav><a href="/">Inicio</a><a href="/servicios">Servicios</a></nav>';
my @C = (
 # etiqueta                                          esperado  html
 ['site-c   · class=saltar href=#principal (1.er <a>)',   1,
  qq{<body><a class="saltar" href="#principal">Ir al contenido</a><header>$NAV</header><main id="principal"><h1>x</h1></main></body>}],
 ['site-a   · class=skip href=#main "Aller au contenu"',  1,
  qq{<body><div class="topbar"><a class="skip" href="#main">Aller au contenu</a></div><header>$NAV</header><main id="main"><h1>x</h1></main></body>}],
 ['bc     · class=skip href=#main "Saltar al contenido"',1,
  qq{<body><a class="skip" href="#main">Saltar al contenido</a><header>$NAV</header><main id="main"><h1>x</h1></main></body>}],
 ['solo DESTINO pero es el 1.er enlace y fuera de nav', 1,
  qq{<body><a href="#main">Conteudo</a><header>$NAV</header><main id="main"><h1>x</h1></main></body>}],
 ['MENU   · <a href="#inicio">Inicio</a> dentro de nav', 0,
  qq{<body><header><nav><a href="#inicio">Inicio</a><a href="#servicios">Servicios</a><a href="#contacto">Contacto</a></nav></header><main><h1>x</h1></main></body>}],
 ['INDICE · <a href="#contenido">Contenido del curso</a>',0,
  qq{<body><header>$NAV</header><main><h1>Curso</h1><p><a href="/a">a</a><a href="/b">b</a><a href="/c">c</a><a href="/d">d</a></p>}
  .qq{<ul class="indice"><li><a href="#contenido">Contenido del curso</a></li><li><a href="#precio">Precio</a></li></ul></main></body>}],
);
my ($ok,$ko)=(0,0);
for my $c (@C) {
    my ($eti,$esp,$html) = @$c;
    my $real = tiene_skip_link($html) ? 1 : 0;
    if ($real == $esp) { printf "  OK    %-52s esperaba %s y salio %s\n", $eti, $esp?'SI':'NO', $real?'SI':'NO'; $ok++ }
    else               { printf "  MAL   %-52s esperaba %s y salio %s\n", $eti, $esp?'SI':'NO', $real?'SI':'NO'; $ko++ }
}
printf "\n  %d OK  ·  %d MAL\n", $ok, $ko;
exit($ko ? 1 : 0);
