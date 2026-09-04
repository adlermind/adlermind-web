/* 후원회원 안내 팝업 · 2026-09-02
 *
 * 쓰는 법 — 팝업을 띄우고 싶은 페이지의 </body> 앞에 한 줄만 넣습니다.
 *   <script src="supporter-popup.js"></script>
 *
 * 원칙 (트리님 확정) — 팝업은 권유이지 관문이 아닙니다.
 *   · 닫기 버튼을 크게 둡니다
 *   · 배경을 눌러도 닫힙니다
 *   · Esc 로도 닫힙니다
 *   · "오늘은 그만 보기" 는 그 기기의 브라우저에만 기억됩니다 (localStorage)
 *   · 후원회원 페이지에서는 뜨지 않습니다
 *
 * 문구는 트리님이 직접 쓰신 확정 문장입니다. 낱말과 순서를 임의로 고치지 않습니다.
 */
(function () {
  'use strict';

  var LINK   = 'supporter.html';
  var KEY    = 'am_supporter_popup_hidden_until';
  var DELAY  = 1200;   // 화면을 먼저 보시고 난 뒤에 뜹니다

  // 후원회원 페이지에서는 띄우지 않습니다. 이미 오신 분께 또 권할 이유가 없습니다.
  if (location.pathname.indexOf('supporter') !== -1) return;

  // 오늘은 그만 보기를 누르셨는지 확인합니다.
  // 시크릿 창이나 저장을 막은 브라우저에서는 읽기 자체가 막힐 수 있어 try 로 감쌉니다.
  try {
    var until = localStorage.getItem(KEY);
    if (until && Date.now() < Number(until)) return;
  } catch (e) {}

  var CSS = ''
    + '.am-sp-back{position:fixed;inset:0;background:rgba(74,74,74,.45);'
    +   'display:flex;align-items:center;justify-content:center;padding:20px;'
    +   'z-index:9000;opacity:0;transition:opacity .25s;}'
    + '.am-sp-back.on{opacity:1;}'
    + '.am-sp-card{background:#fff;max-width:440px;width:100%;padding:32px 30px 26px;'
    +   'position:relative;box-shadow:0 8px 40px rgba(0,0,0,.18);'
    +   'transform:translateY(10px);transition:transform .25s;'
    +   'max-height:88vh;overflow-y:auto;}'
    + '.am-sp-back.on .am-sp-card{transform:translateY(0);}'
    + '.am-sp-x{position:absolute;top:10px;right:12px;border:none;background:none;'
    +   'font-size:26px;line-height:1;color:#6E6763;cursor:pointer;'
    +   'width:40px;height:40px;}'
    + '.am-sp-x:hover{color:#4A4A4A;}'
    + '.am-sp-label{font-family:Raleway,sans-serif;font-size:13px;letter-spacing:.22em;'
    +   'color:#E8929A;margin-bottom:10px;}'
    + '.am-sp-title{font-family:"Noto Serif KR",serif;font-size:22px;font-weight:400;'
    +   'color:#4A4A4A;margin:0 0 16px;}'
    + '.am-sp-text{font-size:14px;line-height:2;color:#4A4A4A;margin:0 0 18px;}'
    + '.am-sp-fee{border-left:2px solid #8FBFB8;padding:10px 16px;margin-bottom:20px;'
    +   'font-size:14px;line-height:1.9;color:#4A4A4A;}'
    + '.am-sp-fee strong{font-weight:500;}'
    + '.am-sp-go{display:block;width:100%;padding:14px;background:#8FBFB8;color:#fff;'
    +   'text-align:center;text-decoration:none;font-size:14px;letter-spacing:.04em;'
    +   'transition:background .15s;}'
    + '.am-sp-go:hover{background:#6fa8a0;}'
    + '.am-sp-later{display:block;width:100%;padding:12px;margin-top:8px;'
    +   'border:none;background:none;color:#6E6763;font-size:13px;cursor:pointer;'
    +   'font-family:"Noto Sans KR",sans-serif;}'
    + '.am-sp-later:hover{color:#4A4A4A;text-decoration:underline;}'
    + '@media(max-width:520px){.am-sp-card{padding:28px 22px 22px;}'
    +   '.am-sp-title{font-size:20px;}}';

  function build() {
    var style = document.createElement('style');
    style.textContent = CSS;
    document.head.appendChild(style);

    var back = document.createElement('div');
    back.className = 'am-sp-back';
    back.setAttribute('role', 'dialog');
    back.setAttribute('aria-modal', 'true');
    back.setAttribute('aria-label', '후원회원 안내');

    var card = document.createElement('div');
    card.className = 'am-sp-card';

    var x = document.createElement('button');
    x.className = 'am-sp-x';
    x.setAttribute('aria-label', '닫기');
    x.innerHTML = '&times;';

    var label = document.createElement('div');
    label.className = 'am-sp-label';
    label.textContent = 'SUPPORTER';

    var title = document.createElement('h2');
    title.className = 'am-sp-title';
    title.textContent = '후원회원을 모십니다';

    // 트리님 확정 문장. 낱말과 순서를 고치지 않습니다.
    var text = document.createElement('p');
    text.className = 'am-sp-text';
    text.innerHTML = '후원회원은 협동조합의 성장을 후원해 주시는 회원입니다.<br>'
      + '하여 총회 의결이나 배당에는 참여하지 않으며, 프로그램 참여 시 10% 감액과 함께 '
      + '매달 뉴스레터로 아들러마인드와 동행하실 수 있습니다.';

    var fee = document.createElement('div');
    fee.className = 'am-sp-fee';
    fee.innerHTML = '후원회비 · <strong>30,000원</strong> (한 번만 납부하시면 됩니다)';

    var go = document.createElement('a');
    go.className = 'am-sp-go';
    go.href = LINK;
    go.textContent = '후원회원 안내 보기';

    var later = document.createElement('button');
    later.className = 'am-sp-later';
    later.textContent = '오늘은 그만 보기';

    card.appendChild(x);
    card.appendChild(label);
    card.appendChild(title);
    card.appendChild(text);
    card.appendChild(fee);
    card.appendChild(go);
    card.appendChild(later);
    back.appendChild(card);
    document.body.appendChild(back);

    function close() {
      back.classList.remove('on');
      document.removeEventListener('keydown', onKey);
      setTimeout(function () {
        if (back.parentNode) back.parentNode.removeChild(back);
      }, 250);
    }
    function hideToday() {
      try {
        // 오늘 자정까지 담아둡니다.
        var end = new Date();
        end.setHours(23, 59, 59, 999);
        localStorage.setItem(KEY, String(end.getTime()));
      } catch (e) {}
      close();
    }
    function onKey(e) { if (e.key === 'Escape') close(); }

    x.addEventListener('click', close);
    later.addEventListener('click', hideToday);
    back.addEventListener('click', function (e) { if (e.target === back) close(); });
    document.addEventListener('keydown', onKey);

    requestAnimationFrame(function () { back.classList.add('on'); });
    go.focus();
  }

  function start() { setTimeout(build, DELAY); }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
