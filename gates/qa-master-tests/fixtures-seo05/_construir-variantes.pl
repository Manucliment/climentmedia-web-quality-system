#!/usr/bin/perl
# Construye las cuatro variantes de fixture a partir de `alineado/`.
#
# 🔑 NO se guarda como fuente: las fixtures VIVEN como ficheros estaticos y son
#    lo que la bateria lee. Esto se corre UNA vez y queda aqui solo para que se
#    vea de que se derivo cada variante. Si se vuelve a correr, tiene que dar
#    exactamente el mismo arbol.
#
# Cada variante difiere de la base en UN fichero y en UNA linea. La bateria lo
# comprueba con `diff -rq`, que es el control barato de que un rojo viene del
# defecto inyectado y no de otra cosa que se colo en la copia.
use strict; use warnings;

my $BASE = 'alineado';
die "hay que correrlo desde fixtures-seo05/\n" unless -d $BASE;

# [ carpeta, fichero, texto viejo, texto nuevo ]
my @V = (
  [ 'h1-hero',        'index.html',
    '<h1>Tarot del amor</h1>', '<h1>hero</h1>' ],
  [ 'solo-marca',     'contacto/index.html',
    '<h1>Contacto</h1>', '<h1>Fixture Nora te escucha</h1>' ],
  [ 'desc-ajena',     'precios/index.html',
    'Precios de cada sesion, sin permanencia y con primera consulta breve.',
    'Envio gratis a partir de treinta euros en toda la peninsula.' ],
);

# La description duplicada se COPIA de index.html en vez de escribirse: asi es
# byte a byte la misma, que es justo lo que SEO-02b tiene que ver, y de paso
# arrastra el acento de «sesión» — que es lo que fija el arreglo de doble
# codificacion.
my $idx = leer("$BASE/index.html");
my ($desc_base) = $idx =~ /<meta name="description" content="([^"]*)">/
  or die "no encuentro la description de la base\n";
#
# 🔴 Y va sobre `hipnosis/`, NO sobre `blog/`, por un motivo que costo una
#    pasada: puesta en `blog/` la description duplicada tambien era AJENA a su
#    titulo, asi que la variante encendia SEO-02b **y** SEO-05b a la vez y un
#    rojo ya no decia cual de los dos. Un control que enrojece por dos motivos
#    a la vez no aisla nada. La pagina `hipnosis/` existe justo para esto: la
#    description que se le copia habla de hipnosis, asi que sigue alineada con
#    su propio titulo y el UNICO check que salta es el de duplicados.
push @V, [ 'desc-duplicada', 'hipnosis/index.html',
           'Sesiones de hipnosis sentimental, una a una, con seguimiento cercano.',
           $desc_base ];

for my $v (@V) {
    my ($dir, $rel, $de, $a) = @$v;
    system('rm', '-rf', $dir) == 0 or die "no pude limpiar $dir\n";
    system('cp', '-r', $BASE, $dir) == 0 or die "no pude copiar a $dir\n";

    my $f = "$dir/$rel";
    my $t = leer($f);
    my $n = ($t =~ s/\Q$de\E/$a/g);          # cuenta las que HACE, no las que ve
    die "$dir: esperaba 1 sustitucion en $rel, hice $n\n" unless $n == 1;
    escribir($f, $t);

    # Releer del disco: que la sustitucion diga «1 de 1» no prueba que quedara
    # escrito lo que yo creo.
    my $rel_t = leer($f);
    die "$dir: el texto viejo sigue ahi\n"  if index($rel_t, $de) >= 0;
    die "$dir: el texto nuevo no esta\n"    if index($rel_t, $a)  < 0;
    print "OK  $dir  ($rel)\n";
}
print "listo: ", scalar(@V), " variantes\n";

sub leer     { my ($f) = @_; open my $h, '<:raw', $f or die "$f: $!\n";
               local $/; my $t = <$h>; close $h; return $t }
sub escribir { my ($f, $t) = @_; open my $h, '>:raw', $f or die "$f: $!\n";
               print $h $t; close $h }
