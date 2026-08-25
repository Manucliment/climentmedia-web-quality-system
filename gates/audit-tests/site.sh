#!/usr/bin/env bash
# Construye un sitio MINIMO que el auditor da por bueno, en la convencion que se
# le pida. Lo usan todos los casos: cada uno parte de aqui y rompe UNA cosa.
#
#   sitio_base <dir> <dir-barra|plano>
#
# Que sea minimo y VERDE es media prueba: si el sitio base saliera rojo, ningun
# caso podria distinguir su propio fallo del ruido de fondo.
pagina() {  # pagina <fichero> <ruta-canonica> <titulo>
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<HTML
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>$3 | Marca</title>
<meta name="description" content="Una descripcion de prueba con longitud suficiente para no disparar el aviso de descripcion corta del auditor de sitio.">
<link rel="stylesheet" href="/e.css">
<link rel="canonical" href="https://ejemplo.test$2">
<meta property="og:title" content="$3">
<meta property="og:description" content="d">
<meta property="og:url" content="https://ejemplo.test$2">
<meta property="og:image" content="https://ejemplo.test/og.png">
</head>
<body>
<main><h1>$3</h1><p>Texto.</p></main>
</body>
</html>
HTML
}

sitio_base() {
  local d="$1" modo="$2"
  rm -rf "$d"; mkdir -p "$d"
  : > "$d/og.png"
  printf "body{color:#111}
" > "$d/e.css"
  cat > "$d/_audit.conf" <<CONF
CONF_BASE_URL="https://ejemplo.test"
BRAND="Marca"
EXCLUDE_DIRS=".git node_modules"
DEAD_PREFIXES=""
CONF
  pagina "$d/index.html" "/" "Portada de prueba"
  if [ "$modo" = "plano" ]; then
    pagina "$d/contacto.html" "/contacto" "Contacto de prueba"
  else
    pagina "$d/contacto/index.html" "/contacto" "Contacto de prueba"
  fi
  # el enlace entre las dos: sin el, contacto es huerfana (S3.2)
  perl -pi -e 's{</main>}{<a href="/contacto">Contacto</a></main>} if $. > 0' "$d/index.html"
  perl -pi -e 's{</main>}{<a href="/">Inicio</a></main>} if $. > 0' \
    "$([ "$modo" = plano ] && echo "$d/contacto.html" || echo "$d/contacto/index.html")"
  cat > "$d/sitemap.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<url><loc>https://ejemplo.test/</loc></url>
<url><loc>https://ejemplo.test/contacto</loc></url>
</urlset>
XML
  printf 'User-agent: *\nAllow: /\nSitemap: https://ejemplo.test/sitemap.xml\n' > "$d/robots.txt"
}
