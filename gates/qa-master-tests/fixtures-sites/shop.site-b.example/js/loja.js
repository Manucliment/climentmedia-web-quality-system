// SITIO SINTETICO shop.site-b.example · pinta el catalogo ENTERO en el navegador.
// Sin JS, loja.html es un esqueleto vacio: ese es el defecto que SEO-14 caza.
export function initShop(raiz, cat) {
  if (!raiz) return;
  const h1 = document.createElement('h1');
  h1.textContent = cat ? 'Loja · ' + cat : 'Loja · todos os modelos';
  raiz.replaceChildren(h1);
}
