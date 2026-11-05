// Un campo de correo creado desde el JS, sin <form>: recoge datos igual.
const i = document.createElement('input'); i.type = 'email'; i.name = 'email';
document.querySelector('main').appendChild(i);
document.querySelector('main').addEventListener('change', () => fetch('/alta.php', { method: 'POST', body: i.value }));
