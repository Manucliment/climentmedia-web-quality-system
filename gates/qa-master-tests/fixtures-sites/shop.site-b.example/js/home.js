// SITIO SINTETICO shop.site-b.example · enriquece las dos rejillas de la home.
// La home ya viene servida con su h1 y su texto: esto solo pinta tarjetas.
const CATEGORIAS = ['redondos', 'retangulares', 'organicos', 'led', 'camarim', 'banheiro', 'moveis'];

function tarjeta(texto, href) {
  const a = document.createElement('a');
  a.className = 'tarjeta';
  a.href = href;
  a.textContent = texto;
  return a;
}

const cat = document.getElementById('catGrid');
if (cat) cat.replaceChildren(...CATEGORIAS.map(c => tarjeta(c, '/loja.html?cat=' + c)));

const feat = document.getElementById('featGrid');
if (feat) feat.replaceChildren(...[1, 2, 3, 4].map(n => {
  const sku = 'MOB-' + String(n).padStart(3, '0');
  return tarjeta(sku, '/produto.html?sku=' + sku);
}));
