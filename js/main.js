/* ==========================================================================
   DOC — общий скрипт: шапка/подвал, фон, анимации, утилиты
   ========================================================================== */
(function () {
  'use strict';
  document.documentElement.classList.add('js');

  var SUPPORT_EMAIL = 'clotc13@gmail.com';
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var page = document.body.dataset.page || '';

  /* ---------- Иконки ---------- */
  var ICONS = {
    zap: '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
    shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
    file: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/>',
    'file-text': '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/>',
    image: '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/>',
    music: '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
    video: '<path d="m22 8-6 4 6 4V8z"/><rect x="2" y="6" width="14" height="12" rx="2"/>',
    archive: '<rect x="2" y="3" width="20" height="5" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8M10 12h4"/>',
    book: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15z"/><path d="M20 17v5H6.5a2.5 2.5 0 0 1 0-5"/>',
    table: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18"/>',
    presentation: '<path d="M2 3h20M21 3v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V3M12 16v5M8 21h8"/>',
    lock: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    mail: '<rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 6L2 7"/>',
    key: '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6M15.5 7.5l3 3L22 7l-3-3"/>',
    code: '<path d="m16 18 6-6-6-6M8 6l-6 6 6 6"/>',
    layers: '<path d="m12 2 10 5-10 5L2 7l10-5z"/><path d="m2 17 10 5 10-5M2 12l10 5 10-5"/>',
    globe: '<circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20 15 15 0 0 1 0-20z"/>',
    'arrow-right': '<path d="M5 12h14M12 5l7 7-7 7"/>',
    copy: '<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    'eye-off': '<path d="M17.9 17.9A10.1 10.1 0 0 1 12 19c-6.5 0-10-7-10-7a18 18 0 0 1 5.1-5.9M9.9 4.2A9 9 0 0 1 12 5c6.5 0 10 7 10 7a18 18 0 0 1-2.2 3.2M1 1l22 22"/>',
    alert: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0zM12 9v4M12 17h.01"/>',
    server: '<rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><path d="M6 6h.01M6 18h.01"/>',
    user: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    sparkles: '<path d="m12 3 1.9 5.8L20 11l-6.1 2.2L12 19l-1.9-5.8L4 11l6.1-2.2L12 3z"/><path d="M19 3v4M17 5h4M5 17v4M3 19h4"/>',
    menu: '<path d="M3 6h18M3 12h18M3 18h18"/>',
    refresh: '<path d="M21 12a9 9 0 0 0-15-6.7L3 8M3 3v5h5M3 12a9 9 0 0 0 15 6.7L21 16M21 21v-5h-5"/>',
    activity: '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>',
    headset: '<path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1v-6h3zM3 19a2 2 0 0 0 2 2h1v-6H3z"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
    star: '<path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8-6.2-3.3-6.2 3.3L7 14.2 2 9.3l6.9-1z"/>',
    minimize: '<path d="M8 3v3a2 2 0 0 1-2 2H3m18 0h-3a2 2 0 0 1-2-2V3m0 18v-3a2 2 0 0 1 2-2h3M3 16h3a2 2 0 0 1 2 2v3"/>',
    scan: '<path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 12h10"/>',
    home: '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/>',
    gauge: '<path d="m12 14 4-4"/><path d="M3.3 19a10 10 0 1 1 17.4 0"/>',
    rocket: '<path d="M4.5 16.5c-1.5 1.3-2 5-2 5s3.7-.5 5-2c.7-.8.7-2.1-.1-2.9a2.2 2.2 0 0 0-2.9-.1zM12 15l-3-3a22 22 0 0 1 2-4 12.9 12.9 0 0 1 11-6c0 2.7-.8 7.5-6 11a22 22 0 0 1-4 2z"/><path d="M9 12H4s.6-3 2-4c1.6-1.1 5 0 5 0M12 15v5s3-.6 4-2c1.1-1.6 0-5 0-5"/>'
  };
  function icon(name, cls) {
    return '<span class="ico ' + (cls || '') + '" aria-hidden="true"><svg viewBox="0 0 24 24">' + (ICONS[name] || '') + '</svg></span>';
  }
  function hydrate(root) {
    (root || document).querySelectorAll('i[data-i]').forEach(function (el) {
      el.outerHTML = icon(el.dataset.i, el.className);
    });
  }
  window.MorphioIcon = icon;
  window.MorphioHydrate = hydrate;

  /* ---------- Фон ---------- */
  function buildBackground() {
    var bg = document.createElement('div');
    bg.className = 'bg';
    bg.setAttribute('aria-hidden', 'true');
    bg.innerHTML =
      '<div class="orb o1"></div><div class="orb o2"></div><div class="orb o3"></div>' +
      '<div class="bg-grid"></div><div class="bg-grid glow"></div>' +
      '<canvas></canvas><div class="bg-noise"></div><div class="bg-vignette"></div>';
    document.body.prepend(bg);
    if (reduce) return;
    initPulses(bg.querySelector('canvas'));

    var mx = window.innerWidth / 2, my = window.innerHeight * 0.4, ticking = false;
    window.addEventListener('pointermove', function (e) {
      mx = e.clientX; my = e.clientY;
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(function () {
          document.documentElement.style.setProperty('--mx', mx + 'px');
          document.documentElement.style.setProperty('--my', my + 'px');
          ticking = false;
        });
      }
    }, { passive: true });
  }

  // Световые импульсы, бегущие по линиям сетки
  function initPulses(canvas) {
    var ctx = canvas.getContext('2d');
    var G = 56, dpr = Math.min(window.devicePixelRatio || 1, 2), W, H, pulses = [];
    var colors = ['139,92,246', '34,211,238', '244,114,182'];

    function resize() {
      W = window.innerWidth; H = window.innerHeight;
      canvas.width = W * dpr; canvas.height = H * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    function spawn() {
      var horiz = Math.random() < 0.5;
      var cols = Math.ceil(W / G), rows = Math.ceil(H / G);
      var dir = Math.random() < 0.5 ? 1 : -1;
      var p = {
        horiz: horiz, dir: dir,
        line: (horiz ? Math.floor(Math.random() * rows) : Math.floor(Math.random() * cols)) * G + 0.5,
        pos: horiz ? (dir > 0 ? -40 : W + 40) : (dir > 0 ? -40 : H + 40),
        speed: 1.4 + Math.random() * 2.4,
        len: 80 + Math.random() * 140,
        color: colors[Math.floor(Math.random() * colors.length)]
      };
      pulses.push(p);
    }
    function frame() {
      ctx.clearRect(0, 0, W, H);
      if (pulses.length < 9 && Math.random() < 0.04) spawn();
      for (var i = pulses.length - 1; i >= 0; i--) {
        var p = pulses[i];
        p.pos += p.speed * p.dir;
        var max = p.horiz ? W : H;
        if ((p.dir > 0 && p.pos - p.len > max) || (p.dir < 0 && p.pos + p.len < 0)) { pulses.splice(i, 1); continue; }
        var x0, y0, x1, y1;
        if (p.horiz) { x0 = p.pos; x1 = p.pos - p.len * p.dir; y0 = y1 = p.line; }
        else { y0 = p.pos; y1 = p.pos - p.len * p.dir; x0 = x1 = p.line; }
        var g = ctx.createLinearGradient(x0, y0, x1, y1);
        g.addColorStop(0, 'rgba(' + p.color + ',.95)');
        g.addColorStop(1, 'rgba(' + p.color + ',0)');
        ctx.strokeStyle = g; ctx.lineWidth = 1.6;
        ctx.shadowColor = 'rgba(' + p.color + ',.9)'; ctx.shadowBlur = 10;
        ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
        ctx.shadowBlur = 0;
        ctx.fillStyle = '#fff';
        ctx.beginPath(); ctx.arc(x0, y0, 1.7, 0, 6.283); ctx.fill();
      }
      requestAnimationFrame(frame);
    }
    resize();
    window.addEventListener('resize', resize);
    for (var i = 0; i < 4; i++) { spawn(); pulses[i].pos = Math.random() * (pulses[i].horiz ? W : H); }
    document.addEventListener('visibilitychange', function () { /* rAF сам останавливается в фоне */ });
    requestAnimationFrame(frame);
  }

  /* ---------- Шапка и подвал ---------- */
  var LOGO =
    '<a href="index.html" class="logo" aria-label="DOC — на главную"><span class="logo-mark">' +
    '<svg viewBox="0 0 24 24" fill="none" stroke="url(#lg)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
    '<defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#a78bfa"/><stop offset=".6" stop-color="#22d3ee"/><stop offset="1" stop-color="#f472b6"/></linearGradient></defs>' +
    '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M8 13h8M8 17h5"/></svg></span>DOC</a>';

  var NAV = [
    ['index.html', 'Главная', 'home'],
    ['convert.html', 'Конвертер', 'convert'],
    ['docs.html', 'Документация', 'docs'],
    ['pricing.html', 'Лимиты', 'pricing'],
    ['status.html', 'Статус', 'status'],
    ['contact.html', 'Поддержка', 'contact']
  ];

  function buildHeader() {
    var host = document.getElementById('site-header');
    if (!host) return;
    var links = NAV.map(function (n) {
      return '<a href="' + n[0] + '"' + (page === n[2] ? ' class="active"' : '') + '>' + n[1] + '</a>';
    }).join('');
    var mlinks = NAV.map(function (n) {
      return '<a class="m-link' + (page === n[2] ? ' active' : '') + '" href="' + n[0] + '">' + n[1] + '</a>';
    }).join('');
    host.innerHTML =
      '<div class="scroll-bar"></div>' +
      '<header class="header" id="header"><div class="container nav">' + LOGO +
      '<nav class="nav-links" aria-label="Основная навигация">' + links + '</nav>' +
      '<div class="nav-cta"><a class="btn ghost sm" href="login.html">Войти</a>' +
      '<a class="btn primary sm" href="register.html">Регистрация</a></div>' +
      '<button class="burger" id="burger" aria-label="Открыть меню">' + icon('menu') + '</button>' +
      '</div></header>' +
      '<div class="mobile-menu" id="mmenu">' + mlinks +
      '<div class="m-cta"><a class="btn lg block" href="login.html">Войти</a><a class="btn primary lg block" href="register.html">Создать аккаунт</a></div></div>';

    var header = document.getElementById('header');
    var bar = host.querySelector('.scroll-bar');
    function onScroll() {
      header.classList.toggle('scrolled', window.scrollY > 12);
      var h = document.documentElement;
      var max = h.scrollHeight - h.clientHeight;
      bar.style.width = (max > 0 ? (window.scrollY / max) * 100 : 0) + '%';
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    var burger = document.getElementById('burger'), menu = document.getElementById('mmenu');
    burger.addEventListener('click', function () {
      var open = menu.classList.toggle('open');
      burger.innerHTML = icon(open ? 'x' : 'menu');
      document.body.style.overflow = open ? 'hidden' : '';
    });
  }

  function buildFooter() {
    var host = document.getElementById('site-footer');
    if (!host) return;
    host.innerHTML =
      '<footer class="footer"><div class="container">' +
      '<div class="footer-grid">' +
      '<div>' + LOGO + '<p class="about">Конвертируем документы, изображения, аудио и видео. Быстро, аккуратно и без лишних кнопок.</p>' +
      '<a class="mail-pill" href="mailto:' + SUPPORT_EMAIL + '">' + icon('mail') + SUPPORT_EMAIL + '</a></div>' +
      '<div><h4>Продукт</h4><ul><li><a href="convert.html">Конвертер</a></li><li><a href="pricing.html">Лимиты и тарифы</a></li><li><a href="status.html">Статус сервиса</a></li><li><a href="register.html">Регистрация</a></li></ul></div>' +
      '<div><h4>Ресурсы</h4><ul><li><a href="docs.html">Документация</a></li><li><a href="docs.html#formats">Форматы</a></li><li><a href="docs.html#errors">Коды ошибок</a></li></ul></div>' +
      '<div><h4>Компания</h4><ul><li><a href="contact.html">Поддержка</a></li><li><a href="legal.html#terms">Условия использования</a></li><li><a href="legal.html#privacy">Конфиденциальность</a></li><li><a href="login.html">Войти</a></li></ul></div>' +
      '</div>' +
      '<div class="footer-bottom"><span>© 2026 DOC. Все права защищены.</span>' +
      '<span class="sys"><span class="badge amber" style="padding:5px 12px 5px 10px;font-size:12.5px"><span class="dot"></span>Повышенная нагрузка</span></span></div>' +
      '</div></footer><div class="toasts" id="toasts"></div>';
  }

  /* ---------- Toast ---------- */
  window.toast = function (msg, type) {
    var box = document.getElementById('toasts');
    if (!box) return;
    type = type || 'info';
    var ic = { ok: 'check', err: 'alert', info: 'info' }[type] || 'info';
    var t = document.createElement('div');
    t.className = 'toast ' + type;
    t.setAttribute('role', 'status');
    t.innerHTML = icon(ic) + '<span></span>';
    t.lastChild.textContent = msg;
    box.appendChild(t);
    setTimeout(function () {
      t.classList.add('out');
      setTimeout(function () { t.remove(); }, 300);
    }, 3800);
  };

  /* ---------- Эффекты ---------- */
  function reveal() {
    var els = document.querySelectorAll('.reveal');
    if (!('IntersectionObserver' in window)) { els.forEach(function (e) { e.classList.add('in'); }); return; }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    els.forEach(function (e) { io.observe(e); });
  }

  function counters() {
    var els = document.querySelectorAll('[data-count]');
    if (!els.length) return;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        io.unobserve(en.target);
        var el = en.target, end = parseFloat(el.dataset.count), dec = (el.dataset.dec | 0), suffix = el.dataset.suffix || '';
        var t0 = performance.now(), dur = 1800;
        (function tick(t) {
          var p = Math.min((t - t0) / dur, 1), e = 1 - Math.pow(1 - p, 4);
          var v = end * e;
          el.textContent = v.toLocaleString('ru-RU', { minimumFractionDigits: dec, maximumFractionDigits: dec }) + suffix;
          if (p < 1) requestAnimationFrame(tick);
        })(t0);
      });
    }, { threshold: 0.4 });
    els.forEach(function (e) { io.observe(e); });
  }

  function spotlight() {
    document.addEventListener('pointermove', function (e) {
      var card = e.target.closest && e.target.closest('.card');
      if (!card) return;
      var r = card.getBoundingClientRect();
      card.style.setProperty('--x', (e.clientX - r.left) + 'px');
      card.style.setProperty('--y', (e.clientY - r.top) + 'px');
    }, { passive: true });
  }

  function tilt() {
    if (reduce) return;
    document.querySelectorAll('[data-tilt]').forEach(function (el) {
      el.addEventListener('pointermove', function (e) {
        var r = el.getBoundingClientRect();
        var x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5;
        el.style.transform = 'rotateY(' + (x * 9) + 'deg) rotateX(' + (-y * 9) + 'deg)';
      });
      el.addEventListener('pointerleave', function () { el.style.transform = ''; });
    });
  }

  function copyButtons() {
    document.addEventListener('click', function (e) {
      var b = e.target.closest('[data-copy], .copy-btn[data-target]');
      if (!b) return;
      var text = b.dataset.copy;
      if (!text && b.dataset.target) {
        var t = document.querySelector(b.dataset.target);
        text = t ? t.innerText : '';
      }
      if (!text) return;
      var done = function () {
        var old = b.innerHTML;
        b.innerHTML = icon('check') + 'Скопировано';
        window.toast('Скопировано в буфер обмена', 'ok');
        setTimeout(function () { b.innerHTML = old; }, 1800);
      };
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text); done(); });
      } else { fallbackCopy(text); done(); }
    });
  }
  function fallbackCopy(text) {
    var ta = document.createElement('textarea');
    ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); } catch (e) { /* noop */ }
    ta.remove();
  }

  function typed() {
    var el = document.querySelector('[data-typed]');
    if (!el) return;
    var words = el.dataset.typed.split('|'), wi = 0, ci = 0, del = false;
    if (reduce) { el.textContent = words[0]; return; }
    (function step() {
      var w = words[wi];
      if (!del) { ci++; if (ci === w.length) { del = true; el.textContent = w; return setTimeout(step, 1700); } }
      else { ci--; if (ci === 0) { del = false; wi = (wi + 1) % words.length; } }
      el.textContent = w.slice(0, ci);
      setTimeout(step, del ? 45 : 95);
    })();
  }

  // Анимация макета в hero
  function mockLoop() {
    var bar = document.querySelector('[data-mock-bar]'), pct = document.querySelector('[data-mock-pct]');
    if (!bar) return;
    var p = 0, hold = 0;
    setInterval(function () {
      if (hold > 0) {
        hold--;
        if (hold === 0) { p = 0; bar.style.width = '0%'; pct.textContent = '0%'; }
        return;
      }
      p += 1 + Math.random() * 2.6;
      if (p >= 100) { p = 100; hold = 28; }
      bar.style.width = p + '%';
      pct.textContent = Math.floor(p) + '%';
    }, 60);
  }

  /* ---------- Общие утилиты для страниц ---------- */
  window.Morphio = {
    email: SUPPORT_EMAIL,
    icon: icon,
    hydrate: hydrate,
    wait: function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); },
    isEmail: function (v) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v); },
    fmtSize: function (b) {
      var u = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'], i = 0;
      while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
      return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)).toString().replace('.', ',') + ' ' + u[i];
    }
  };

  /* ---------- Старт ---------- */
  buildBackground();
  buildHeader();
  buildFooter();
  hydrate();
  reveal();
  counters();
  spotlight();
  tilt();
  copyButtons();
  typed();
  mockLoop();
})();
