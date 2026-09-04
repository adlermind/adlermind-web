/* 후원회원 안내 팝업 · 2026-09-02 작성 / 2026-09-04 이미지판으로 교체
 *
 * 쓰는 법 — 팝업을 띄우고 싶은 페이지의 </body> 앞에 한 줄만 넣습니다.
 *   <script src="supporter-popup.js"></script>
 *
 * 그림 · image/supporter_popup.webp (990×1240 · 원본은 paper/07_contents/popup/)
 *   그림 안에 이미 "후원회원 가입하기" 단추가 그려져 있어서
 *   그림 전체를 신청 페이지로 가는 링크로 감쌌습니다.
 *   그림을 바꾸실 때는 같은 이름으로 덮어쓰시면 됩니다. 비율은 4:5 를 지켜주세요.
 *
 * 원칙 (트리님 확정) — 팝업은 권유이지 관문이 아닙니다.
 *   · 닫기 단추를 크게 둡니다
 *   · 배경을 눌러도 닫힙니다
 *   · Esc 로도 닫힙니다
 *   · "오늘은 그만 보기" 는 그 기기의 브라우저에만 기억됩니다 (localStorage)
 *   · 후원회원 페이지에서는 뜨지 않습니다
 */
(function () {
  'use strict';

  var LINK  = 'supporter.html';
  var IMG   = 'image/supporter_popup.webp';
  var ALT   = '후원회원이 되어 함께 행복을 나누어요. '
            + '딱 한번 3만원, 협동조합의 후원회원이 되시면 조합의 모든 프로그램에 참여하실 때 '
            + '참가비를 10% 감액해 드립니다. '
            + '매달 뉴스레터로 조합의 소식과 아들러심리학의 이야기를 보내드립니다.';
  var KEY   = 'am_supporter_popup_hidden_until';
  var DELAY = 1200;   // 화면을 먼저 보시고 난 뒤에 뜹니다

  // 후원회원 페이지에서는 띄우지 않습니다. 이미 오신 분께 또 권할 이유가 없습니다.
  if (location.pathname.indexOf('supporter') !== -1) return;

  // 오늘은 그만 보기를 누르셨는지 확인합니다.
  // 시크릿 창이나 저장을 막은 브라우저에서는 읽기 자체가 막힐 수 있어 try 로 감쌉니다.
  try {
    var until = localStorage.getItem(KEY);
    if (until && Date.now() < Number(until)) return;
  } catch (e) {}

  var CSS = ''
    + '.am-sp-back{position:fixed;inset:0;background:rgba(74,74,74,.5);'
    +   'display:flex;align-items:center;justify-content:center;padding:20px;'
    +   'z-index:9000;opacity:0;transition:opacity .25s;overflow-y:auto;}'
    + '.am-sp-back.on{opacity:1;}'
    + '.am-sp-card{position:relative;width:100%;max-width:420px;margin:auto;'
    +   'background:#FBEADF;box-shadow:0 8px 40px rgba(0,0,0,.2);'
    +   'transform:translateY(10px);transition:transform .25s;}'
    + '.am-sp-back.on .am-sp-card{transform:translateY(0);}'
    /* 그림 전체가 신청 페이지로 가는 단추입니다.
       그림을 끌면 브라우저가 검은 테두리와 그림자를 그려서 그것을 막습니다 (2026-09-04).
       키보드로 오신 분께는 테두리가 보여야 하므로 :focus-visible 만 남깁니다. */
    + '.am-sp-link{display:block;line-height:0;outline:none;-webkit-tap-highlight-color:transparent;}'
    /* 테두리는 채도 낮은 꽃분홍 (브랜드 Mauve Pink · 2026-09-04 트리님 지시).
       초록은 그림의 살구빛과 부딪혀 눈에 거슬립니다. */
    + '.am-sp-link:focus-visible{outline:2px solid #C48DA0;outline-offset:-2px;}'
    + '.am-sp-link img{width:100%;height:auto;display:block;'
    +   'user-select:none;-webkit-user-select:none;-webkit-user-drag:none;pointer-events:none;}'
    /* 닫기 — 그림 위에 얹되 손가락으로 누르기 넉넉한 크기로 둡니다 */
    + '.am-sp-x{position:absolute;top:8px;right:8px;width:40px;height:40px;'
    +   'border:none;border-radius:50%;background:rgba(255,255,255,.85);'
    +   'font-size:24px;line-height:40px;color:#4A4A4A;cursor:pointer;'
    +   'padding:0;text-align:center;transition:background .15s;}'
    + '.am-sp-x:hover{background:#fff;}'
    + '.am-sp-later{display:block;width:100%;padding:14px;border:none;'
    +   'background:rgba(255,255,255,.6);color:#4A4A4A;font-size:14px;cursor:pointer;'
    +   'font-family:"Noto Sans KR",sans-serif;letter-spacing:.02em;'
    +   'border-top:0.5px solid rgba(74,74,74,.12);transition:background .15s;}'
    + '.am-sp-later:hover{background:rgba(255,255,255,.9);}'
    + '@media(max-width:520px){.am-sp-back{padding:12px;}'
    +   '.am-sp-card{max-width:100%;}}';

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

    var link = document.createElement('a');
    link.className = 'am-sp-link';
    link.href = LINK;

    var img = document.createElement('img');
    img.src = IMG;
    img.alt = ALT;
    img.draggable = false;   // 끌어서 옮기기를 막습니다
    link.appendChild(img);

    var x = document.createElement('button');
    x.className = 'am-sp-x';
    x.setAttribute('aria-label', '닫기');
    x.innerHTML = '&times;';

    var later = document.createElement('button');
    later.className = 'am-sp-later';
    later.textContent = '오늘은 그만 보기';

    card.appendChild(link);
    card.appendChild(later);
    card.appendChild(x);
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
    link.focus();
  }

  function start() { setTimeout(build, DELAY); }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
