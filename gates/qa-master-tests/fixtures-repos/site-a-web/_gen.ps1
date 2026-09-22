# _gen.ps1 - generador de las paginas de site-a.example
# Fixture SINTETICO de gates/qa-master-tests: el banco no lo ejecuta, lo LEE.
# Esta aqui por MED-05: el barrido de data-* recorre tambien los generadores, y
# este tiene dos ramas (Rejilla y Seccion) que hoy no usa ninguna pagina. Lo que
# escriben -data-col y data-sec- no llega a ningun HTML: es NO APLICA, no FALLO.
# Las fichas de _spec/ que consume no forman parte del fixture: las paginas
# generadas ya estan en la raiz, tal y como se despliegan.
param([string]$Salida = $PSScriptRoot)

$Nav = @(
    @{ Href = '/services';    Texto = 'Nos soins' },
    @{ Href = '/le-centre';   Texto = 'Le centre' },
    @{ Href = '/reeducation'; Texto = 'Rééducation' },
    @{ Href = '/tarifs';      Texto = 'Tarifs' },
    @{ Href = '/contact';     Texto = 'Contact' }
)

function Rejilla([int]$Cols, [string[]]$Items) {
    $celdas = ($Items | ForEach-Object { "<div class='card'>$_</div>" }) -join ''
    return "<div class='cards' data-col='$Cols'>$celdas</div>"
}

function Seccion([string]$Id, [string]$Html) {
    return "<section data-sec='$Id'>$Html</section>"
}

function Ventana() {
    return @"
<div class="pop" id="pop-rdv" role="dialog" aria-labelledby="pop-titre" hidden>
  <button type="button" class="pop__close" data-pop-act='close' aria-label="Fermer">&times;</button>
  <h2 id="pop-titre">Prendre rendez-vous</h2>
  <p>Laissez vos coordonnées : nous vous rappelons en semaine pour fixer la séance.</p>
  <p><a class="btn" href="/contact">Remplir le formulaire</a></p>
</div>
"@
}

function Pagina($P) {
    $main = $P.Cuerpo
    if ($P.Rejilla) { $main += Rejilla -Cols $P.Rejilla.Cols -Items $P.Rejilla.Items }
    if ($P.Secciones) { foreach ($s in $P.Secciones) { $main += Seccion -Id $s.Id -Html $s.Html } }
    $attrMain = if ($P.Gracias) { " data-thanks='lead'" } else { '' }
    $nav = ($Nav | ForEach-Object { "      <li><a href=`"$($_.Href)`">$($_.Texto)</a></li>" }) -join "`n"
    $html = (Get-Content -Raw (Join-Path $PSScriptRoot '_spec/plantilla.html')) `
        -replace '\{\{TITULO\}\}', $P.Titulo `
        -replace '\{\{NAV\}\}', $nav `
        -replace '\{\{ATTR_MAIN\}\}', $attrMain `
        -replace '\{\{MAIN\}\}', $main `
        -replace '\{\{VENTANA\}\}', (Ventana)
    Set-Content -Encoding utf8NoBOM -Path (Join-Path $Salida $P.Fichero) -Value $html
}

foreach ($f in Get-ChildItem (Join-Path $PSScriptRoot '_spec') -Filter '*.psd1') {
    Pagina (Import-PowerShellDataFile $f.FullName)
}
