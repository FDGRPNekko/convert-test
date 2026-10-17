/* Документация: поиск по меню и подсветка текущего раздела */
(function () {
  'use strict';
  var links = Array.prototype.slice.call(document.querySelectorAll('#docsNav a'));
  var headings = Array.prototype.slice.call(document.querySelectorAll('#docsNav h5'));
  var sections = links.map(function (a) { return document.querySelector(a.getAttribute('href')); });
  var search = document.getElementById('docsSearch');
  var none = document.getElementById('noResults');

  // Подсветка раздела при прокрутке
  var current = null;
  function spy() {
    var active = 0;
    sections.forEach(function (s, i) { if (s && s.getBoundingClientRect().top <= 150) active = i; });
    if (current !== active) {
      current = active;
      links.forEach(function (a, i) { a.classList.toggle('on', i === active); });
    }
  }
  window.addEventListener('scroll', spy, { passive: true });
  window.addEventListener('resize', spy);
  spy();

  // Поиск: по названию раздела и по его тексту
  var texts = sections.map(function (s) { return s ? s.textContent.toLowerCase() : ''; });
  search.addEventListener('input', function () {
    var q = search.value.trim().toLowerCase(), shown = 0;
    links.forEach(function (a, i) {
      var match = !q || a.textContent.toLowerCase().indexOf(q) > -1 || texts[i].indexOf(q) > -1;
      a.classList.toggle('hide', !match);
      if (match) shown++;
    });
    headings.forEach(function (h) {
      var n = h.nextElementSibling, any = false;
      while (n && n.tagName === 'A') { if (!n.classList.contains('hide')) any = true; n = n.nextElementSibling; }
      h.style.display = any ? '' : 'none';
    });
    none.style.display = shown ? 'none' : 'block';
  });
})();
