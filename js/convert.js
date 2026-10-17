/* Страница конвертера. Файл никуда не отправляется: всё происходит в браузере. */
(function () {
  'use strict';
  var M = window.Morphio;
  var $ = function (s) { return document.querySelector(s); };

  var GUEST_LIMIT_BYTES = 20 * 1024 * 1024 * 1024; // 20 ГБ

  var GROUPS = {
    doc:   { name: 'Документы',    icon: 'file-text',    list: 'pdf docx doc odt rtf txt html md epub' },
    sheet: { name: 'Таблицы',      icon: 'table',        list: 'xlsx xls csv ods json pdf' },
    pres:  { name: 'Презентации',  icon: 'presentation', list: 'pptx ppt odp pdf' },
    img:   { name: 'Изображения',  icon: 'image',        list: 'png jpg webp avif gif bmp tiff svg ico heic pdf' },
    audio: { name: 'Аудио',        icon: 'music',        list: 'mp3 wav flac aac ogg m4a opus' },
    video: { name: 'Видео',        icon: 'video',        list: 'mp4 mov webm mkv avi gif mp3' },
    arch:  { name: 'Архивы',       icon: 'archive',      list: 'zip 7z rar tar gz' },
    ebook: { name: 'Книги',        icon: 'book',         list: 'epub mobi azw3 fb2 pdf' }
  };
  Object.keys(GROUPS).forEach(function (k) { GROUPS[k].list = GROUPS[k].list.split(' '); });

  var EXT_GROUP = {};
  function reg(group, exts) { exts.split(' ').forEach(function (e) { EXT_GROUP[e] = group; }); }
  reg('doc', 'pdf docx doc odt rtf txt html htm md');
  reg('sheet', 'xlsx xls csv ods json');
  reg('pres', 'pptx ppt odp');
  reg('img', 'png jpg jpeg webp avif gif bmp tiff tif svg ico heic heif');
  reg('audio', 'mp3 wav flac aac ogg m4a opus wma');
  reg('video', 'mp4 mov webm mkv avi wmv flv m4v');
  reg('arch', 'zip 7z rar tar gz tgz');
  reg('ebook', 'epub mobi azw3 fb2');

  var state = { file: null, ext: '', group: 'doc', target: null, busy: false };

  var els = {
    upload: $('#stepUpload'), settings: $('#stepSettings'), drop: $('#drop'), input: $('#fileInput'),
    fExt: $('#fExt'), fName: $('#fName'), fMeta: $('#fMeta'), fRemove: $('#fRemove'),
    tabs: $('#tabs'), fmts: $('#fmts'), go: $('#goBtn'), q: $('#quality'), qVal: $('#qVal'), ocr: $('#ocr'),
    queue: $('#queue'), overload: $('#overload'), retry: $('#retryBtn'), qPos: $('#qPos')
  };

  /* ---- Загрузка ---- */
  ['dragenter', 'dragover'].forEach(function (ev) {
    els.drop.addEventListener(ev, function (e) { e.preventDefault(); els.drop.classList.add('over'); });
  });
  ['dragleave', 'drop'].forEach(function (ev) {
    els.drop.addEventListener(ev, function (e) { e.preventDefault(); els.drop.classList.remove('over'); });
  });
  els.drop.addEventListener('drop', function (e) {
    if (e.dataTransfer.files && e.dataTransfer.files[0]) setFile(e.dataTransfer.files[0]);
  });
  els.input.addEventListener('change', function () { if (els.input.files[0]) setFile(els.input.files[0]); });
  els.drop.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); els.input.click(); } });
  document.addEventListener('paste', function (e) {
    var f = e.clipboardData && e.clipboardData.files && e.clipboardData.files[0];
    if (f && !state.file) setFile(f);
  });
  els.fRemove.addEventListener('click', reset);

  function setFile(file) {
    if (file.size > GUEST_LIMIT_BYTES) {
      window.toast('Файл больше суточного лимита гостя (20 ГБ). Зарегистрируйтесь, чтобы получить 50 ГБ.', 'err');
      return;
    }
    var m = /\.([a-z0-9]+)$/i.exec(file.name);
    state.file = file;
    state.ext = m ? m[1].toLowerCase() : '';
    state.group = EXT_GROUP[state.ext] || 'doc';
    state.target = null;

    els.fExt.textContent = (state.ext || 'file').slice(0, 5);
    els.fName.textContent = file.name;
    els.fMeta.textContent = M.fmtSize(file.size) + (EXT_GROUP[state.ext] ? ' · ' + GROUPS[state.group].name : ' · формат не распознан');
    els.upload.hidden = true;
    els.settings.hidden = false;
    els.queue.hidden = true;
    els.overload.hidden = true;
    renderTabs();
    renderFormats();
    updateGo();
    if (!EXT_GROUP[state.ext]) window.toast('Формат не распознан автоматически — выберите категорию вручную', 'info');
  }

  function reset() {
    state.file = null; state.target = null; state.busy = false;
    els.input.value = '';
    els.settings.hidden = true;
    els.upload.hidden = false;
  }

  /* ---- Форматы ---- */
  function renderTabs() {
    els.tabs.innerHTML = '';
    Object.keys(GROUPS).forEach(function (k) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'tab' + (k === state.group ? ' on' : '');
      b.setAttribute('role', 'tab');
      b.innerHTML = M.icon(GROUPS[k].icon) + GROUPS[k].name;
      b.addEventListener('click', function () { state.group = k; state.target = null; renderTabs(); renderFormats(); updateGo(); });
      els.tabs.appendChild(b);
    });
  }
  function renderFormats() {
    els.fmts.innerHTML = '';
    GROUPS[state.group].list.filter(function (f) { return f !== state.ext; }).forEach(function (f) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'fmt' + (state.target === f ? ' on' : '');
      b.textContent = f;
      b.addEventListener('click', function () { state.target = f; renderFormats(); updateGo(); });
      els.fmts.appendChild(b);
    });
  }
  function updateGo() {
    els.go.disabled = !state.target || state.busy;
    els.go.querySelector('span:last-child').textContent = state.target
      ? 'Конвертировать ' + (state.ext || 'файл').toUpperCase() + ' → ' + state.target.toUpperCase()
      : 'Выбери формат';
  }

  els.q.addEventListener('input', function () { els.qVal.textContent = els.q.value + '%'; });

  /* ---- Конвертация (сервис перегружен) ---- */
  var stepsEls = Array.prototype.slice.call(document.querySelectorAll('.q-step'));
  function setStep(i, cls) {
    stepsEls[i].classList.remove('active', 'done', 'fail');
    if (cls) stepsEls[i].classList.add(cls);
    var st = stepsEls[i].querySelector('.st');
    st.innerHTML = cls === 'done' ? M.icon('check') : cls === 'fail' ? M.icon('x') : '';
  }

  var timer = null;
  async function convert() {
    if (state.busy || !state.target) return;
    state.busy = true;
    updateGo();
    clearInterval(timer);

    els.queue.hidden = false;
    els.overload.hidden = true;
    stepsEls.forEach(function (_, i) { setStep(i, null); });
    els.queue.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

    setStep(0, 'active'); await M.wait(700 + Math.random() * 500);
    setStep(0, 'done');   setStep(1, 'active'); await M.wait(1000 + Math.random() * 700);
    setStep(1, 'done');   setStep(2, 'active'); await M.wait(1400 + Math.random() * 900);
    setStep(2, 'done');   setStep(3, 'active'); await M.wait(1500 + Math.random() * 800);
    setStep(3, 'fail');

    var pos = 3000 + Math.floor(Math.random() * 4000);
    els.qPos.textContent = 'Очередь: ' + pos.toLocaleString('ru-RU');
    els.overload.hidden = false;
    window.toast('Сервис перегружен, попробуйте позже', 'err');
    countdown(20);
    state.busy = false;
    updateGo();
  }

  function countdown(sec) {
    var label = els.retry.querySelector('span:last-child');
    els.retry.disabled = true;
    label.textContent = 'Повторить через ' + sec + ' с';
    timer = setInterval(function () {
      sec--;
      if (sec <= 0) {
        clearInterval(timer);
        els.retry.disabled = false;
        label.textContent = 'Повторить попытку';
      } else label.textContent = 'Повторить через ' + sec + ' с';
    }, 1000);
  }

  els.go.addEventListener('click', convert);
  els.retry.addEventListener('click', convert);
})();
