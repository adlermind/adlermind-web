// 저장한 체험 기록을 그리는 자리 · 1-H
//
// 표시 계약 3칸(summary · keywords · action)만 읽습니다. result_data 를 뜯어보지 않으므로
// 체험이 늘어도 이 파일은 바뀌지 않습니다 (결정 6).
//
// 쓰는 쪽: AMRecords.render({ into, client, userId })
// 조회에 반드시 user_id 조건을 둡니다. RLS 가 활성 관리자에게 전체 조회를 허용하므로,
// 관리자 계정의 개인 페이지가 다른 사람의 기록까지 합치지 않게 하는 별도 경계입니다.

(function () {
  const STYLE = `
.amr-head { margin-bottom: 18px; }
.amr-title { font-family: 'Noto Serif KR', serif; font-size: 16px; color: #6B6B6B; margin-bottom: 6px; }
.amr-desc { font-size: 12.5px; color: #9a9490; line-height: 1.9; }
.amr-msg { font-size: 12.5px; color: #9a9490; line-height: 1.9; padding: 18px 0; }
.amr-list { list-style: none; display: grid; gap: 14px; margin: 0 0 40px; padding: 0; }
.amr-card { background: #fff; border: 0.5px solid #e8e4e0; padding: 22px 22px 18px; }
.amr-meta { display: flex; flex-wrap: wrap; gap: 10px; align-items: baseline; font-size: 12px; color: #9a9490; }
.amr-meta strong { font-weight: 400; color: #6B6B6B; font-size: 13px; }
.amr-summary { font-size: 13.5px; line-height: 1.9; color: #6B6B6B; margin-top: 12px; }
.amr-block { margin-top: 14px; }
.amr-label { font-size: 11px; letter-spacing: 0.06em; color: #9a9490; margin-bottom: 7px; }
.amr-chips { display: flex; flex-wrap: wrap; gap: 6px; }
.amr-chip { font-size: 12px; color: #6B6B6B; border: 0.5px solid #e8e4e0; background: #FAFAF8; padding: 4px 11px; }
.amr-action { font-size: 13px; line-height: 1.9; color: #6B6B6B; }
.amr-foot { margin-top: 16px; display: flex; justify-content: flex-end; }
.amr-del { border: 0.5px solid #e8e4e0; background: none; color: #9a9490; font-family: 'Noto Sans KR', sans-serif;
           font-weight: 300; font-size: 11.5px; padding: 5px 12px; cursor: pointer; transition: all 0.15s; }
.amr-del:hover { border-color: #E8929A; color: #E8929A; }
.amr-del:disabled { opacity: 0.5; cursor: default; }
.amr-sum-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; }
.amr-sum-card { background: #fff; border: 0.5px solid #e8e4e0; padding: 24px 22px; }
.amr-sum-title { font-family: 'Noto Serif KR', serif; font-size: 14px; color: #6B6B6B; margin-bottom: 4px; }
.amr-sum-desc { font-size: 12px; color: #9a9490; line-height: 1.8; margin-bottom: 14px; }
.amr-steps { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; }
.amr-steps li { font-size: 12.5px; line-height: 1.8; color: #6B6B6B; }
.amr-steps small { display: block; font-size: 11px; color: #9a9490; }
.amr-empty { font-size: 12px; color: #9a9490; }
`;

  function styleOnce() {
    if (document.getElementById('amr-style')) return;
    const style = document.createElement('style');
    style.id = 'amr-style';
    style.textContent = STYLE;
    document.head.appendChild(style);
  }

  function toText(value) {
    return typeof value === 'string' ? value.trim() : '';
  }

  function toKeywords(value) {
    if (Array.isArray(value)) return value.map(toText).filter(Boolean);
    const one = toText(value);
    return one ? [one] : [];
  }

  // 표시 계약 3칸만 꺼냅니다. 나머지(detail)는 읽지 않습니다.
  function readContract(row) {
    const result = row.result_data;
    const box = result && typeof result === 'object' && !Array.isArray(result) ? result : {};
    return {
      summary: toText(box.summary),
      keywords: toKeywords(box.keywords),
      action: toText(box.action)
    };
  }

  const dateFormat = new Intl.DateTimeFormat('ko-KR', {
    year: 'numeric', month: 'long', day: 'numeric', timeZone: 'Asia/Seoul'
  });

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    // 체험 자료가 보낸 글은 반드시 textContent 로 넣습니다. innerHTML 로 넣으면
    // 자료 쪽 글이 이 페이지의 화면을 건드릴 수 있습니다.
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function render(options) {
    const into = options.into;
    const client = options.client;
    const userId = options.userId;
    if (!into || !client || !userId) return;

    styleOnce();
    let rows = [];

    function drawMessage(message) {
      into.textContent = '';
      into.appendChild(element('p', 'amr-msg', message));
    }

    function drawCard(row) {
      const contract = readContract(row);
      const card = element('li', 'amr-card');

      const meta = element('div', 'amr-meta');
      meta.appendChild(element('strong', null, row.experience_title));
      const time = element('time', null, dateFormat.format(new Date(row.created_at)));
      time.dateTime = row.created_at;
      meta.appendChild(time);
      card.appendChild(meta);

      card.appendChild(element('p', 'amr-summary',
        contract.summary || '아직 한 줄로 정리되지 않은 체험입니다.'));

      if (contract.keywords.length > 0) {
        const block = element('div', 'amr-block');
        block.appendChild(element('div', 'amr-label', '나를 설명하는 말'));
        const chips = element('div', 'amr-chips');
        contract.keywords.forEach(keyword => chips.appendChild(element('span', 'amr-chip', keyword)));
        block.appendChild(chips);
        card.appendChild(block);
      }

      if (contract.action) {
        const block = element('div', 'amr-block');
        block.appendChild(element('div', 'amr-label', '이번 주 작은 실천'));
        block.appendChild(element('p', 'amr-action', contract.action));
        card.appendChild(block);
      }

      const foot = element('div', 'amr-foot');
      const button = element('button', 'amr-del', '이 기록 삭제');
      button.type = 'button';
      button.addEventListener('click', () => remove(row, button));
      foot.appendChild(button);
      card.appendChild(foot);

      return card;
    }

    function drawCollection(title, description, emptyText, fill) {
      const card = element('div', 'amr-sum-card');
      card.appendChild(element('div', 'amr-sum-title', title));
      card.appendChild(element('div', 'amr-sum-desc', description));
      const list = element('ul', 'amr-steps');
      fill(list);
      if (list.childElementCount === 0) card.appendChild(element('p', 'amr-empty', emptyText));
      else card.appendChild(list);
      return card;
    }

    function draw() {
      into.textContent = '';

      const head = element('div', 'amr-head');
      head.appendChild(element('div', 'amr-title', '지난 체험'));
      head.appendChild(element('p', 'amr-desc', '저장한 날짜의 최신순으로 모았습니다.'));
      into.appendChild(head);

      if (rows.length === 0) {
        into.appendChild(element('p', 'amr-msg', '아직 저장한 체험 기록이 없습니다.'));
        return;
      }

      const list = element('ol', 'amr-list');
      rows.forEach(row => list.appendChild(drawCard(row)));
      into.appendChild(list);

      const grid = element('div', 'amr-sum-grid');

      grid.appendChild(drawCollection(
        '나를 설명하는 말',
        '체험에서 고른 말을 한자리에 모았습니다.',
        '아직 모인 말이 없습니다.',
        list2 => {
          const seen = [];
          rows.forEach(row => readContract(row).keywords.forEach(keyword => {
            if (seen.indexOf(keyword) !== -1) return;
            seen.push(keyword);
            list2.appendChild(element('li', null, keyword));
          }));
        }
      ));

      grid.appendChild(drawCollection(
        '이번 주 작은 실천',
        '체험에서 해보기로 정한 행동입니다.',
        '아직 정해둔 작은 실천이 없습니다.',
        list2 => {
          rows.forEach(row => {
            const action = readContract(row).action;
            if (!action) return;
            const item = element('li', null, action);
            item.appendChild(element('small', null, row.experience_title));
            list2.appendChild(item);
          });
        }
      ));

      into.appendChild(grid);
    }

    async function remove(row, button) {
      const asked = window.confirm(
        `'${row.experience_title}' 기록 한 건을 삭제할까요?\n삭제한 기록은 되돌릴 수 없습니다.`
      );
      if (!asked) return;

      button.disabled = true;
      const { error } = await client
        .from('experience_records')
        .delete()
        .eq('id', row.id)
        .eq('user_id', userId);

      if (error) {
        button.disabled = false;
        window.alert('기록을 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.');
        return;
      }
      rows = rows.filter(item => item.id !== row.id);
      draw();
    }

    (async () => {
      drawMessage('저장한 기록을 불러오고 있습니다.');
      const { data, error } = await client
        .from('experience_records')
        .select('id, experience_key, experience_title, result_data, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) {
        drawMessage('기록을 불러오지 못했습니다. 잠시 후 다시 열어 주세요.');
        return;
      }
      rows = data || [];
      draw();
    })();
  }

  window.AMRecords = { render: render };
})();
