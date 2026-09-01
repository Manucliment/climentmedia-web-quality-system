#!/usr/bin/perl
# =============================================================================
#  Banco de `roles.pl` — el vocabulario de roles y las plantillas por tipo
# =============================================================================
#  Cada caso INYECTA un defecto y exige el rojo POR SU MOTIVO, no un rojo
#  cualquiera: un rojo por la razon equivocada es un verde disfrazado.
#  Y toda mutacion afirma que cambio el fichero antes de correr nada — una
#  sustitucion que no casa no da error y no cambia nada, y entonces el control
#  mide el arbol limpio y sale verde por no haber probado.
use strict; use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy);
use File::Spec;

my $REF  = File::Spec->rel2abs(dirname($0) . '/..');
my $ROOT = File::Spec->rel2abs(dirname($0) . '/.tmp-roles');
my $G    = "$ROOT/gates";
my $BP   = "$ROOT/blueprint";
my $MO   = "$BP/moulds";
my ($OK, $MAL) = (0, 0);

sub fresco {
    remove_tree($ROOT) if -d $ROOT;
    make_path($G); make_path($MO);
    copy("$REF/$_", "$G/$_") or die "no puedo copiar $_: $!\n"
        for qw(roles.pl roles.tsv anatomy.tsv);
    for my $md (qw(09-page-types.md 10-layout-vocabulary.md)) {
        copy("$REF/../blueprint/$md", "$BP/$md") or die "no puedo copiar $md: $!\n";
    }
    opendir(my $d, "$REF/../blueprint/moulds") or die "no hay moldes: $!\n";
    for my $f (grep { -f "$REF/../blueprint/moulds/$_" } readdir $d) {
        copy("$REF/../blueprint/moulds/$f", "$MO/$f") or die "no puedo copiar $f: $!\n";
    }
    closedir $d;
    # El arbol nace CON sus plantillas: el caso verde tiene que existir, o el
    # unico rojo que sabria producir este banco es «faltan las plantillas».
    # En silencio: un banco que imprime 13 lineas de ruido por caso esconde su
    # propia senal, y la senal de un banco es la unica razon por la que existe.
    generar_callando() or die "no pude generar las plantillas\n";
}

sub generar_callando {
    my $nul = File::Spec->devnull();
    return system(qq{"$^X" "$G/roles.pl" --plantillas > $nul 2>&1}) == 0;
}

sub leer  { my $f = shift; open my $h, '<:raw', $f or return undef;
            local $/; my $x = <$h>; close $h; $x }
sub escribir { my ($f, $x) = @_; open my $h, '>:raw', $f or die $!; print $h $x; close $h }

# Sustitucion que AFIRMA cuantas hizo. Devuelve 0 si no toco nada, y entonces
# el caso se declara invalido en vez de pasar.
sub cambiar {
    my ($f, $de, $a) = @_;
    my $t = leer($f); return 0 unless defined $t;
    my $n = ($t =~ s/\Q$de\E/$a/g);
    return 0 unless $n;
    escribir($f, $t);
    return $n;
}

sub correr { my $o = `"$^X" "$G/roles.pl" --gate 2>&1`; return ($? >> 8, $o) }

sub caso {
    my ($titulo, $espera, $mutar) = @_;   # $espera: 'verde' o un trozo del motivo
    fresco();
    if ($mutar) {
        my $cambio = $mutar->();
        if (!$cambio) {
            printf "  MAL   %-52s la mutacion NO cambio nada: el control no vale\n", $titulo;
            $MAL++; return;
        }
    }
    my ($rc, $out) = correr();
    my $bien = $espera eq 'verde' ? ($rc == 0 && $out =~ /ROLES OK/)
                                  : ($rc != 0 && $out =~ /\Q$espera\E/);
    if ($bien) { printf "  ok    %-52s %s\n", $titulo, ($espera eq 'verde' ? 'verde' : "rojo por «$espera»"); $OK++ }
    else {
        printf "  MAL   %-52s esperaba %s · rc=%s\n", $titulo, $espera, $rc;
        print "        ", ((split /\n/, $out)[0] // '(sin salida)'), "\n";
        print "        ", ((split /\n/, $out)[1] // ''), "\n";
        $MAL++;
    }
}

print "== BANCO DE roles.pl · el vocabulario y las plantillas por tipo\n";

caso('el arbol tal cual', 'verde', undef);

# A · la arista que no existia antes de este fichero: anatomy.pl reconcilia
#     CONTANDO marcas REQ, asi que un rol renombrado en un lado seguia
#     cuadrando en el otro. Aqui se compara por NOMBRE.
caso('A · un tipo usa un rol que el vocabulario no tiene',
     'usa el rol `cierre` y roles.tsv no lo tiene',
     sub { cambiar("$G/roles.tsv", "\ncierre|closing|", "\ncierreX|closing|") });

# B · vocabulario que no alcanza ninguna anatomia. No se borra ni se ignora:
#     se declara. Quitar la declaracion tiene que doler.
caso('B · rol sin anatomia y SIN declarar',
     'no lo usa ninguna anatomia',
     sub { cambiar("$G/roles.tsv", '|SOLO-VOCABULARIO: ninguna anatomia', '|ninguna anatomia') });

# C · un molde prometido que no esta en el cajon.
caso('C · el rol apunta a un molde que no existe',
     'ese molde no esta en blueprint/moulds/',
     sub { cambiar("$G/roles.tsv", '07-checklist.html', '07-checklist-QUE-NO-EXISTE.html') });

# D · el documento y la tabla dicen primitivas distintas. Es lo que un recuento
#     de marcas no puede ver, y por eso este caso importa mas de lo que parece.
caso('D · 09 §1 y roles.tsv discrepan en la primitiva',
     'dice primitiva',
     sub { cambiar("$G/roles.tsv", '|checklist|07-checklist.html', '|feature grid|07-checklist.html') });

caso('D · 09 §1 no tiene fila para ese rol',
     'no tiene fila para el rol',
     sub { cambiar("$G/roles.tsv", '|qualification|', '|qualificationX|') });

# E · la cifra «11 de 14» estaba escrita a mano en DOS documentos. Ahora se
#     deriva, y el gate se pone rojo si alguno se queda atras.
caso('E · el documento publica un recuento de moldes falso',
     'have a mould',
     sub { cambiar("$BP/09-page-types.md", 'Twelve of the fifteen have a mould',
                                           'Thirteen of the fifteen have a mould') });

# G · 10 §4 promete que todo molde lleva su CUANDO y su CUANDO NO en la cabecera.
#     Hasta el 1-sep-2026 esa promesa no la comprobaba nadie, y la hoja de
#     referencia EXTRAE ese texto: un molde mudo daba una hoja peor en silencio.
caso('G · un molde sin CUANDO',
     'no declara CUANDO',
     sub { cambiar("$MO/07-checklist.html", 'CUANDO:', 'CUANDX:') });

caso('G · un molde sin CUANDO NO',
     'no declara CUANDO NO',
     sub { cambiar("$MO/05-numbered-steps.html", 'CUANDO NO', 'CUANDX NO') });

# 🔑 Y el caso que impide que G apruebe la nada: si el cajon esta vacio, un
#    barrido «todos los moldes cumplen» es cierto y no significa nada.
caso('G · el cajon de moldes vacio no es un aprobado',
     'no hay ni un molde',
     sub {
         my $n = 0;
         opendir(my $d, $MO) or return 0;
         for my $f (grep { /\.html$/ } readdir $d) { unlink "$MO/$f" and $n++ }
         closedir $d;
         return $n;
     });

# F · las plantillas son GENERADAS. Editarlas a mano no puede durar una bateria,
#     o vuelven a ser una segunda fuente, que es justo lo que 10 §6 borro.
caso('F · alguien edita una plantilla a mano',
     'no es la que saldria hoy',
     sub { cambiar("$MO/types/servicio.html", '<h1>Plantilla de referencia',
                                              '<h1>EDITADO A MANO Plantilla de referencia') });

caso('F · falta la plantilla de un tipo',
     'falta la plantilla de `landing`',
     sub { unlink "$MO/types/landing.html" });

# H · Y AL REVES QUE F: una plantilla que ya no corresponde a ningun tipo.
#     Lo encontro un rename real (`quiz` -> `landing`): quedaron 14 plantillas
#     para 13 tipos y el gate paso, porque F solo mira que a cada tipo NO le
#     falte la suya. Una huerfana ensena una anatomia retirada con la
#     credibilidad de un fichero generado.
caso('H · una plantilla de un tipo que ya no existe',
     'sobra la plantilla',
     sub {
         my $t = leer("$MO/types/home.html") or return 0;
         escribir("$MO/types/tipo-retirado.html", $t);
         return 1;
     });

caso('H · y regenerar la BORRA', 'verde',
     sub {
         my $t = leer("$MO/types/home.html") or return 0;
         escribir("$MO/types/tipo-retirado.html", $t);
         generar_callando() or return 0;
         return -e "$MO/types/tipo-retirado.html" ? 0 : 1;
     });

# 🔑 EL CONTROL DE IDA Y VUELTA: si tras romperla se regenera, tiene que volver
#    al verde. Sin este caso, «F se pone rojo» podria significar que el gate
#    esta roto en un sentido y no que sabe distinguir las dos situaciones.
caso('F · y regenerar la devuelve al verde', 'verde',
     sub {
         my $n = cambiar("$MO/types/home.html", '<h1>Plantilla', '<h1>ROTA Plantilla');
         return 0 unless $n;
         generar_callando() or return 0;
         return 1;
     });

# La anatomia manda sobre la plantilla, no al reves: cambiar el orden de los
# roles de un tipo tiene que dejar obsoletas sus plantillas.
caso('F · cambiar la anatomia deja la plantilla obsoleta',
     'no es la que saldria hoy',
     sub { cambiar("$G/anatomy.tsv", 'home|hero prueba oferta proceso cierre',
                                     'home|hero oferta prueba proceso cierre') });

remove_tree($ROOT) if -d $ROOT;
print "\n  OK $OK · MAL $MAL\n";
exit($MAL ? 1 : 0);
