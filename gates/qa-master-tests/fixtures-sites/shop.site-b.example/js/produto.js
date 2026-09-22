// SITIO SINTETICO shop.site-b.example · pinta la ficha en el navegador a partir del ?sku=.
// Sin JS, produto.html es el mismo esqueleto para todos los SKU: mismo title, sin h1.
export function initProduct(raiz, sku) {
  if (!raiz) return;
  const h1 = document.createElement('h1');
  h1.textContent = 'Modelo ' + (sku || 'desconhecido');
  document.title = h1.textContent + ' | Site B Loja';
  raiz.replaceChildren(h1);
}
