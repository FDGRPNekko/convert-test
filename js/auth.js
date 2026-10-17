/* Вход / регистрация / восстановление. Данные никуда не отправляются. */
(function () {
  'use strict';
  var M = window.Morphio;
  var $ = function (s) { return document.querySelector(s); };

  function setLoading(btn, on, text) {
    if (on) {
      btn.dataset.html = btn.innerHTML;
      btn.disabled = true;
      btn.innerHTML = '<span class="spin"></span><span>' + text + '</span>';
    } else {
      btn.disabled = false;
      btn.innerHTML = btn.dataset.html || btn.innerHTML;
    }
  }
  function showAlert(box, msg) {
    box.querySelector('span:last-child').textContent = msg;
    box.classList.remove('show');
    void box.offsetWidth; // перезапуск анимации
    box.classList.add('show');
  }
  function hideAlert(box) { box.classList.remove('show'); }
  function fieldErr(input, errEl, bad) {
    if (input) input.classList.toggle('bad', bad);
    if (errEl) errEl.classList.toggle('show', bad);
  }
  function shake(el) { el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake'); }

  function bindEye() {
    var eye = $('#eyeBtn'), pw = $('#password');
    if (!eye || !pw) return;
    eye.addEventListener('click', function () {
      var show = pw.type === 'password';
      pw.type = show ? 'text' : 'password';
      eye.innerHTML = M.icon(show ? 'eye-off' : 'eye');
      eye.setAttribute('aria-label', show ? 'Скрыть пароль' : 'Показать пароль');
    });
  }

  /* ---------------- ВХОД ---------------- */
  function initLogin() {
    var form = $('#loginForm'), email = $('#email'), pass = $('#password'), alertBox = $('#alert'), btn = $('#submit');
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      hideAlert(alertBox);
      var okE = M.isEmail(email.value.trim()), okP = pass.value.length > 0;
      fieldErr(email, $('#emailErr'), !okE);
      fieldErr(pass, $('#passErr'), !okP);
      if (!okE || !okP) { shake(form); return; }

      setLoading(btn, true, 'Проверяем данные…');
      await M.wait(1200 + Math.random() * 700);
      setLoading(btn, false);
      showAlert(alertBox, 'Ошибка: неправильная почта или пароль');
      shake(form);
      pass.value = '';
      pass.focus();
    });
    [email, pass].forEach(function (i) { i.addEventListener('input', function () { i.classList.remove('bad'); hideAlert(alertBox); }); });
  }

  /* ---------------- РЕГИСТРАЦИЯ ---------------- */
  function initRegister() {
    var step1 = $('#step1'), step2 = $('#step2');
    var form = $('#regForm'), email = $('#email'), pass = $('#password'), terms = $('#terms'), btn = $('#regSubmit');
    var alert1 = $('#alert1'), alert2 = $('#alert2');
    var strength = $('#strength'), hint = $('#strengthHint');

    pass.addEventListener('input', function () {
      var v = pass.value, s = 0;
      if (v.length >= 8) s++;
      if (/[a-zа-я]/.test(v) && /[A-ZА-Я]/.test(v)) s++;
      if (/\d/.test(v)) s++;
      if (/[^\w\s]/.test(v) || v.length >= 14) s++;
      if (!v) s = 0;
      strength.dataset.s = s;
      hint.textContent = ['Используйте буквы разного регистра, цифры и символы', 'Слабый пароль', 'Можно надёжнее', 'Хороший пароль', 'Отличный пароль'][s];
      pass.classList.remove('bad'); $('#passErr').classList.remove('show');
    });
    email.addEventListener('input', function () { email.classList.remove('bad'); $('#emailErr').classList.remove('show'); });
    terms.addEventListener('change', function () { $('#termsErr').classList.remove('show'); });

    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      hideAlert(alert1);
      var okE = M.isEmail(email.value.trim()), okP = pass.value.length >= 8, okT = terms.checked;
      fieldErr(email, $('#emailErr'), !okE);
      fieldErr(pass, $('#passErr'), !okP);
      $('#termsErr').classList.toggle('show', !okT);
      if (!okE || !okP || !okT) { shake(form); return; }

      setLoading(btn, true, 'Отправляем код…');
      await M.wait(1300 + Math.random() * 600);
      setLoading(btn, false);

      $('#sentTo').textContent = email.value.trim();
      step1.hidden = true;
      step2.hidden = false;
      step2.style.animation = 'pop .5s';
      window.toast('Код отправлен на ' + email.value.trim(), 'ok');
      startOtp();
    });

    /* ---- Шаг 2: код ---- */
    var otpBox = $('#otp'), otpForm = $('#otpForm'), otpBtn = $('#otpSubmit');
    var resend = $('#resend');
    var inputs = [], attempts = 0, MAX = 3, tick = null, locked = false;

    for (var i = 0; i < 6; i++) {
      var inp = document.createElement('input');
      inp.type = 'text'; inp.inputMode = 'numeric'; inp.maxLength = 1; inp.autocomplete = i === 0 ? 'one-time-code' : 'off';
      inp.setAttribute('aria-label', 'Цифра ' + (i + 1));
      otpBox.appendChild(inp); inputs.push(inp);
    }
    inputs.forEach(function (inp, idx) {
      inp.addEventListener('input', function () {
        inp.value = inp.value.replace(/\D/g, '').slice(-1);
        inp.classList.toggle('filled', !!inp.value);
        otpBox.classList.remove('bad'); hideAlert(alert2);
        if (inp.value && idx < 5) inputs[idx + 1].focus();
        if (code().length === 6) otpForm.requestSubmit ? otpForm.requestSubmit() : otpForm.dispatchEvent(new Event('submit', { cancelable: true }));
      });
      inp.addEventListener('keydown', function (e) {
        if (e.key === 'Backspace' && !inp.value && idx > 0) { inputs[idx - 1].focus(); inputs[idx - 1].value = ''; inputs[idx - 1].classList.remove('filled'); }
        if (e.key === 'ArrowLeft' && idx > 0) inputs[idx - 1].focus();
        if (e.key === 'ArrowRight' && idx < 5) inputs[idx + 1].focus();
      });
      inp.addEventListener('paste', function (e) {
        var t = (e.clipboardData || window.clipboardData).getData('text').replace(/\D/g, '').slice(0, 6);
        if (!t) return;
        e.preventDefault();
        t.split('').forEach(function (ch, k) { inputs[k].value = ch; inputs[k].classList.add('filled'); });
        inputs[Math.min(t.length, 5)].focus();
        if (t.length === 6) otpForm.requestSubmit ? otpForm.requestSubmit() : null;
      });
    });
    function code() { return inputs.map(function (i) { return i.value; }).join(''); }
    function clearCode() { inputs.forEach(function (i) { i.value = ''; i.classList.remove('filled'); }); inputs[0].focus(); }
    function lock(on) { locked = on; inputs.forEach(function (i) { i.disabled = on; }); otpBtn.disabled = on; }

    function startOtp() {
      attempts = 0; lock(false); clearCode(); hideAlert(alert2);
      var sec = 60;
      clearInterval(tick);
      resend.disabled = true;
      resend.innerHTML = 'Отправить повторно через <span id="resendTimer">' + sec + '</span> с';
      tick = setInterval(function () {
        sec--;
        if (sec <= 0) { clearInterval(tick); resend.disabled = false; resend.textContent = 'Отправить код повторно'; }
        else resend.querySelector('#resendTimer').textContent = sec;
      }, 1000);
    }

    otpForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      if (locked) return;
      if (code().length < 6) { otpBox.classList.add('bad'); shake(otpBox); showAlert(alert2, 'Введите все 6 цифр кода'); return; }
      lock(true);
      setLoading(otpBtn, true, 'Проверяем код…');
      otpBtn.disabled = true;
      await M.wait(1200 + Math.random() * 600);
      setLoading(otpBtn, false);
      attempts++;
      otpBox.classList.add('bad');
      shake(otpBox);
      if (attempts >= MAX) {
        showAlert(alert2, 'Слишком много неверных попыток. Запросите новый код.');
        lock(true);
        inputs.forEach(function (i) { i.disabled = true; });
        otpBtn.disabled = true;
      } else {
        showAlert(alert2, 'Неверный код. Осталось попыток: ' + (MAX - attempts));
        lock(false);
        clearCode();
      }
    });

    resend.addEventListener('click', function () {
      window.toast('Новый код отправлен на ' + $('#sentTo').textContent, 'ok');
      startOtp();
    });
    $('#changeEmail').addEventListener('click', function () {
      clearInterval(tick);
      step2.hidden = true; step1.hidden = false; email.focus();
    });
  }

  /* ---------------- ВОССТАНОВЛЕНИЕ ---------------- */
  function initForgot() {
    var form = $('#forgotForm'), email = $('#email'), btn = $('#submit'), box = $('#alert');
    email.addEventListener('input', function () { fieldErr(email, $('#emailErr'), false); });
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      hideAlert(box);
      var ok = M.isEmail(email.value.trim());
      fieldErr(email, $('#emailErr'), !ok);
      if (!ok) { shake(form); return; }
      setLoading(btn, true, 'Отправляем…');
      await M.wait(1300);
      setLoading(btn, false);
      showAlert(box, 'Если аккаунт с такой почтой существует, мы отправили на неё письмо с инструкцией.');
    });
  }

  bindEye();
  if ($('#loginForm')) initLogin();
  if ($('#regForm')) initRegister();
  if ($('#forgotForm')) initForgot();
})();
