// 상담의 방·배움의 방 분야 화면 · 2026-07-28
//
// 카드 목록과 분야 상세를 한 파일에서 그립니다. 분야가 늘어도 HTML 파일은 늘지 않습니다.
// 체험 실행을 experience.html 한 곳에 모은 것과 같은 이유입니다 —
// 분야마다 페이지를 만들면 nav 하나 고칠 때 그만큼 다 고쳐야 합니다.
//
// 쓰는 쪽:
//   AMRoom.render({
//     listInto, detailInto,   // 목록·상세를 그릴 자리
//     fields,                 // counseling-fields.js 등이 담아 둔 배열
//     roomName: '상담의 방',
//     page: 'counseling.html',
//     onDetail: (field) => {} // 상세로 들어가고 나올 때 부르는 손잡이 (체험 카드 감추기 등)
//   })
//
// 주소는 counseling.html?field=media 처럼 붙습니다.
// 분야마다 주소가 달라야 링크를 보낼 수 있고 뒤로가기가 동작합니다.

(function () {
  const STYLE = `
.amr-room { max-width: 1000px; margin: 0 auto; }
.amr-cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 16px; }
.amr-card { display: block; background: #fff; border: 0.5px solid #e8e4e0;
            padding: 26px 24px; text-decoration: none; color: #4A4A4A;
            transition: border-color 0.15s, transform 0.15s; }
.amr-card:hover { border-color: #8FBFB8; transform: translateY(-2px); }
.amr-card-name { font-family: 'Noto Serif KR', serif; font-size: 17px; font-weight: 400; }
.amr-card-sub { font-size: 13px; color: #6E6763; margin-top: 4px; }
.amr-card-lead { font-size: 13.5px; line-height: 1.9; color: #6E6763; margin-top: 12px; }
.amr-card-more { font-size: 13px; color: #8FBFB8; margin-top: 16px; }

.amr-detail-head { border-bottom: 0.5px solid #e8e4e0; padding-bottom: 22px; margin-bottom: 30px; }
.amr-detail-name { font-family: 'Noto Serif KR', serif; font-size: 26px; font-weight: 400; }
.amr-detail-sub { font-size: 13.5px; color: #6E6763; margin-top: 6px; }
.amr-detail-lead { font-size: 15px; line-height: 2; color: #4A4A4A; margin-top: 16px; }
.amr-body p { font-size: 14px; line-height: 2.1; color: #4A4A4A; margin-bottom: 20px; }

.amr-steps-t, .amr-foryou-t, .amr-extra-t {
  font-family: 'Raleway', sans-serif; font-size: 13px; font-weight: 400;
  letter-spacing: 0.2em; color: #6E6763; text-transform: uppercase;
  margin: 40px 0 18px; }
.amr-step { display: flex; gap: 18px; padding: 18px 0; border-top: 0.5px solid #e8e4e0; }
.amr-step-no { flex: 0 0 62px; font-family: 'Raleway', sans-serif; font-size: 13px;
               letter-spacing: 0.1em; color: #8FBFB8; padding-top: 3px; }
.amr-step-t { font-size: 14px; margin-bottom: 6px; }
.amr-step-x { font-size: 13.5px; line-height: 1.95; color: #6E6763; }

.amr-foryou { list-style: none; margin: 0; padding: 0; }
.amr-foryou li { font-size: 13.5px; line-height: 1.9; color: #4A4A4A; padding: 7px 0 7px 16px; position: relative; }
.amr-foryou li::before { content: '·'; position: absolute; left: 0; color: #8FBFB8; }

.amr-extra { background: #FAFAF8; border-left: 2px solid #8FBFB8; padding: 18px 20px; margin-top: 16px; }
.amr-extra p { font-size: 13.5px; line-height: 1.95; color: #4A4A4A; margin: 0; }
.amr-note { border: 0.5px solid #e8e4e0; background: #fff; padding: 20px 22px; margin-top: 36px; }
.amr-note-t { font-size: 14px; margin-bottom: 8px; }
.amr-note p { font-size: 13.5px; line-height: 1.95; color: #6E6763; margin: 0; }
.amr-note a { color: #8FBFB8; font-size: 13.5px; display: inline-block; margin-top: 10px; }

.amr-online { font-size: 13.5px; line-height: 1.9; color: #6E6763; margin-top: 36px;
              padding-top: 20px; border-top: 0.5px solid #e8e4e0; }
.amr-foot { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; margin-top: 24px; }
.amr-ask { display: inline-block; background: #8FBFB8; color: #fff; text-decoration: none;
           padding: 12px 24px; font-size: 14px; transition: background 0.15s; }
.amr-ask:hover { background: #6fa8a0; }
.amr-back { font-size: 13.5px; color: #6E6763; text-decoration: none; }
.amr-back:hover { color: #8FBFB8; }

@media (max-width: 640px) {
  .amr-cards { grid-template-columns: 1fr; }
  .amr-detail-name { font-size: 22px; }
  .amr-step { flex-direction: column; gap: 6px; }
  .amr-step-no { flex: none; }
}
`;

  function styleOnce() {
    if (document.getElementById('amr-room-style')) return;
    const style = document.createElement('style');
    style.id = 'amr-room-style';
    style.textContent = STYLE;
    document.head.appendChild(style);
  }

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function render(options) {
    const list = typeof options.listInto === 'string'
      ? document.getElementById(options.listInto) : options.listInto;
    const detail = typeof options.detailInto === 'string'
      ? document.getElementById(options.detailInto) : options.detailInto;
    const fields = options.fields || [];
    if (!list || !detail || fields.length === 0) return;

    styleOnce();
    const page = options.page || location.pathname.split('/').pop();
    const onDetail = options.onDetail || function () {};

    function drawList() {
      list.textContent = '';
      const box = element('div', 'amr-room');
      const grid = element('div', 'amr-cards');
      fields.forEach(field => {
        const card = element('a', 'amr-card');
        card.href = page + '?field=' + encodeURIComponent(field.key);
        card.appendChild(element('div', 'amr-card-name', field.name));
        if (field.sub) card.appendChild(element('div', 'amr-card-sub', field.sub));
        card.appendChild(element('p', 'amr-card-lead', field.lead));
        card.appendChild(element('div', 'amr-card-more', '자세히 보기 →'));
        card.addEventListener('click', event => {
          // 새 탭으로 여는 것은 막지 않습니다.
          if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
          event.preventDefault();
          go(field.key, true);
        });
        grid.appendChild(card);
      });
      box.appendChild(grid);
      list.appendChild(box);
    }

    function drawDetail(field) {
      detail.textContent = '';
      const box = element('div', 'amr-room');

      const head = element('div', 'amr-detail-head');
      head.appendChild(element('h1', 'amr-detail-name', field.name));
      if (field.sub) head.appendChild(element('div', 'amr-detail-sub', field.sub));
      head.appendChild(element('p', 'amr-detail-lead', field.lead));
      box.appendChild(head);

      const body = element('div', 'amr-body');
      (field.body || []).forEach(text => body.appendChild(element('p', null, text)));
      box.appendChild(body);

      if (field.steps && field.steps.length) {
        box.appendChild(element('div', 'amr-steps-t', field.stepsTitle || '함께 걷는 길'));
        field.steps.forEach(step => {
          const row = element('div', 'amr-step');
          row.appendChild(element('div', 'amr-step-no', step.no));
          const right = element('div');
          right.appendChild(element('div', 'amr-step-t', step.title));
          right.appendChild(element('div', 'amr-step-x', step.text));
          row.appendChild(right);
          box.appendChild(row);
        });
      }

      if (field.extra) {
        box.appendChild(element('div', 'amr-extra-t', field.extra.title));
        const extra = element('div', 'amr-extra');
        extra.appendChild(element('p', null, field.extra.text));
        box.appendChild(extra);
      }

      if (field.forYou && field.forYou.length) {
        box.appendChild(element('div', 'amr-foryou-t', 'For You · 이런 분들과 만나고 싶습니다'));
        const ul = element('ul', 'amr-foryou');
        field.forYou.forEach(item => ul.appendChild(element('li', null, item)));
        box.appendChild(ul);
      }

      if (field.note) {
        const note = element('div', 'amr-note');
        note.appendChild(element('div', 'amr-note-t', field.note.title));
        note.appendChild(element('p', null, field.note.text));
        if (field.note.link) {
          const link = element('a', null, field.note.link.label + ' →');
          link.href = field.note.link.href;
          note.appendChild(link);
        }
        box.appendChild(note);
      }

      box.appendChild(element('p', 'amr-online',
        '온라인으로도 만납니다. Zoom 화상상담으로 진행할 수 있으며, ' +
        '문의하실 때 온라인을 원하시는지 함께 알려주시면 됩니다.'));

      const foot = element('div', 'amr-foot');
      const ask = element('a', 'amr-ask', '이 상담 문의하기 →');
      // 어느 자리에서 눌렀는지만 넘깁니다. 문의 유형은 문의 화면에서 방문자가 직접 고릅니다.
      ask.href = 'contact.html?from=' + encodeURIComponent(field.name);
      foot.appendChild(ask);
      const back = element('a', 'amr-back', '← ' + (options.roomName || '목록') + '으로');
      back.href = page;
      back.addEventListener('click', event => {
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) return;
        event.preventDefault();
        go(null, true);
      });
      foot.appendChild(back);
      box.appendChild(foot);

      detail.appendChild(box);
    }

    function show(key) {
      const field = fields.filter(item => item.key === key)[0] || null;
      if (field) {
        drawDetail(field);
        detail.classList.remove('hidden');
        list.classList.add('hidden');
      } else {
        drawList();
        list.classList.remove('hidden');
        detail.classList.add('hidden');
      }
      onDetail(field);
      window.scrollTo({ top: 0, behavior: 'auto' });
    }

    function go(key, push) {
      if (push) {
        const url = key ? page + '?field=' + encodeURIComponent(key) : page;
        history.pushState({ field: key || null }, '', url);
      }
      show(key);
    }

    // 뒤로가기·앞으로가기를 따라갑니다.
    window.addEventListener('popstate', () => {
      show(new URLSearchParams(location.search).get('field'));
    });

    show(new URLSearchParams(location.search).get('field'));
  }

  window.AMRoom = { render: render };
})();
