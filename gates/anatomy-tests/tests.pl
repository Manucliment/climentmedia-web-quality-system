#!/usr/bin/perl
# =============================================================================
#  Banco de anatomy.pl — la tabla de anatomias tiene UNA fuente
# =============================================================================
#  No comprueba que el gate pase: comprueba QUE SE PONE ROJO, que es la unica
#  pregunta que importa. Cada caso MUTA una copia en un directorio temporal y
#  AFIRMA que el fichero cambio antes de correr el gate: una sustitucion que no
#  casa no da error y no cambia nada, y entonces el «no salio ningun FALLO» es
#  del control, no del gate (07-trampas §mutacion-muda).
# =============================================================================
use strict; use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path remove_tree);
use File::Basename qw(dirname);
use File::Spec;

my $REF = File::Spec->rel2abs(dirname($0) . '/..');
# The human table lives one level up, in blueprint/. The temp tree mirrors the
# repo layout (gates/ next to blueprint/) so the gate's relative path resolves.
my $ROOT = File::Spec->rel2abs(dirname($0) . '/.tmp-anatomy');
my $TMP  = "$ROOT/gates";
my $BP   = "$ROOT/blueprint";
my $MD   = '09-page-types.md';
my @FICH = qw(anatomy.pl anatomy.tsv qa-master.pl audit-vs-spec.pl structure-gate.js);
my ($OK, $MAL) = (0, 0);

sub fresco {
    remove_tree($ROOT) if -d $ROOT;
    make_path($TMP); make_path($BP);
    for my $f (@FICH) {
        copy("$REF/$f", "$TMP/$f") or die "no puedo copiar $f: $!\n";
    }
    copy("$REF/../blueprint/$MD", "$BP/$MD") or die "no puedo copiar $MD: $!\n";
}
sub leer { my $f = shift; open my $h, '<', $f or return undef; local $/; my $x = <$h>; close $h; $x }
sub escribir { my ($f, $x) = @_; open my $h, '>', $f or die $!; print $h $x; close $h }
sub correr { my $o = `perl "$TMP/anatomy.pl" --gate 2>&1`; return ($? >> 8, $o) }

sub caso {
    my ($titulo, $espera, $mutar) = @_;    # $espera: 'verde' o un trozo del motivo
    fresco();
    if ($mutar) {
        my $cambio = $mutar->();
        if (!$cambio) {
            printf "  MAL   %-46s la mutacion NO cambio el fichero: el control no vale\n", $titulo;
            $MAL++; return;
        }
    }
    my ($rc, $out) = correr();
    my $bien = $espera eq 'verde' ? ($rc == 0 && $out =~ /ANATOMIA OK/)
                                  : ($rc != 0 && $out =~ /\Q$espera\E/);
    if ($bien) { printf "  ok    %-46s %s\n", $titulo, ($espera eq 'verde' ? 'verde' : "rojo por «$espera»"); $OK++ }
    else {
        printf "  MAL   %-46s esperaba %s · rc=%s\n", $titulo, $espera, $rc;
        print "        ", (split /\n/, $out)[0] // '(sin salida)', "\n";
        $MAL++;
    }
}

# --- sustitucion que AFIRMA cuantas hizo -------------------------------------
sub sust {
    my ($f, $de, $a, $esperadas) = @_;
    my $s = leer("$TMP/$f") // return 0;
    my $n = 0; $n++ while $s =~ /\Q$de\E/g;
    return 0 unless $n == $esperadas;
    my $h = ($s =~ s/\Q$de\E/$a/g);   # /g: sin el solo cambia la PRIMERA
    return 0 unless $h == $esperadas;
    escribir("$TMP/$f", $s);
    return 1;
}

print "BANCO · anatomy.pl (una sola tabla de anatomias)\n\n";

caso('el arbol tal cual', 'verde', undef);

caso('A · 09 §2 pierde una fila REQ', 'marcas OBL', sub {
    sust("../blueprint/$MD", '| 4 | `closing` | REQ | — |',
                             '| 4 | `closing` | OPT | — |', 1);
});

caso('B · un .pl vuelve a escribir su tabla', 'su propia %ANATOMIA', sub {
    my $s = leer("$TMP/qa-master.pl") // return 0;
    escribir("$TMP/qa-master.pl", $s . "\nmy %ANATOMIA = (\n  home => [qw(hero)],\n);\n");
    return 1;
});

caso('B · un .pl deja de leer la tabla', 'no llama a anatomia_cargar', sub {
    sust('audit-vs-spec.pl', 'anatomia_cargar', 'anatomia_NO_cargar', 2);
});

caso('C · el bloque del .js se edita a mano', 'no coincide con anatomy.tsv', sub {
    sust('structure-gate.js', "  hub:          ['hero', 'catalogo', 'calificacion', 'cierre'],",
                               "  hub:          ['hero', 'catalogo', 'cierre'],", 1);
});

caso('C · se borra el bloque marcado del .js', 'no tiene el bloque marcado', sub {
    my $s = leer("$TMP/structure-gate.js") // return 0;
    my $abre = '/* >' . '>> ANATOMIA-GENERADA';
    my $cier = '/* >' . '>> FIN-ANATOMIA-GENERADA <' . '<< */';
    my $re = qr/\Q$abre\E.*?\Q$cier\E/s;
    my $n = 0; $n++ while $s =~ /$re/g;
    return 0 unless $n == 1;
    return 0 unless ($s =~ s/$re/const ANATOMIA = {};\nconst ANATOMIA_ALIAS = {};/);
    escribir("$TMP/structure-gate.js", $s);
    return 1;
});

caso('D · la tabla se queda sin tipos', 'tipos', sub {
    my $s = leer("$TMP/anatomy.tsv") // return 0;
    my $solo = join "\n", grep { /^\s*#/ } split /\n/, $s;
    return 0 if $solo eq $s;
    escribir("$TMP/anatomy.tsv", $solo . "\n");
    return 1;
});

caso('D · la tabla desaparece', 'anatomy.tsv', sub {
    unlink "$TMP/anatomy.tsv" or return 0;
    return !-e "$TMP/anatomy.tsv";
});

remove_tree($TMP) if -d $TMP;
printf "\n  OK %d · MAL %d\n", $OK, $MAL;
exit($MAL ? 1 : 0);
