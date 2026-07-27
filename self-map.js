// 자기탐색 지도 · 1-I
//
// 구역 이름·좌표·계절 판정·그림 경로를 한 곳에서 관리합니다.
// 심지 simji-web/src/lib/self-map.ts 를 그대로 옮긴 것입니다.
// 구역 정의가 두 홈페이지에서 갈라지지 않게 이 파일 하나만 고칩니다.
//
// 쓰는 쪽: AMSelfMap.render({ into, rows })
//   rows — experience_records 줄 (map_regions · experience_title · id 를 씁니다)

(function () {
  const SEASONS = ['spring', 'summer', 'autumn', 'winter'];

  const SEASON_LABEL = {
    spring: '봄', summer: '여름', autumn: '가을', winter: '겨울'
  };

  const REGIONS = [
    {
      key: 'bitteul',
      name: '빛뜰',
      academic: '창조적 자아 · Creative Self',
      factors: '사고 · 정서 · 통제감 · 긍정적 유머 · 일',
      description: '내면의 생각과 정서, 나를 통제하는 힘, 긍정적 유머와 업무적 강점을 찾아가는 자리입니다.',
      anchor: { x: 22, y: 26 }
    },
    {
      key: 'ppurisaem',
      name: '뿌리샘',
      academic: '본질적 자아 · Essential Self',
      factors: '영성 · 삶의 의미 · 성 정체성 · 문화 정체성 · 자기돌봄',
      description: '영성과 삶의 의미, 나의 성·문화 정체성을 이해하고 스스로를 돌보는 방법을 찾아가는 자리입니다.',
      anchor: { x: 18, y: 70 }
    },
    {
      key: 'baramgogae',
      name: '바람고개',
      academic: '대처적 자아 · Coping Self',
      factors: '쉼 · 스트레스 대처 · 자기가치 · 현실적 신념',
      description: '충분히 쉬고 스트레스를 다루는 방법, 나의 가치와 현실적인 생각을 찾아가는 자리입니다.',
      anchor: { x: 80, y: 22 }
    },
    {
      key: 'eoulsup',
      name: '어울숲',
      academic: '사회적 자아 · Social Self',
      factors: '우정 · 사랑 · 공헌 · 기여',
      description: '다른 사람과 관계를 맺고 공동체에 공헌하고 기여하는 나만의 방법을 찾아가는 자리입니다.',
      anchor: { x: 84, y: 81 }
    },
    {
      key: 'sumgyeolgil',
      name: '숨결길',
      academic: '신체적 자아 · Physical Self',
      factors: '운동 · 영양 · 알아차림',
      description: '운동과 영양 상태를 살피고 몸과 마음의 변화를 알아차리며 건강하게 돌보는 방법을 찾아가는 자리입니다.',
      anchor: { x: 64, y: 72 }
    },
    {
      key: 'maeumjari',
      name: '마음자리',
      academic: '통합적 자아 · Indivisible Self',
      factors: '불완전할 용기 · 생활양식 · 구체적 실천 · 성장',
      description: '불완전한 나를 받아들이고 생활양식을 이해하며 구체적으로 실천하고 성장해 가는 자리입니다.',
      anchor: { x: 50, y: 47 }
    }
  ];

  const KEYS = REGIONS.map(region => region.key);

  function currentSeason(date) {
    const month = Number(new Intl.DateTimeFormat('en-US', {
      month: 'numeric', timeZone: 'Asia/Seoul'
    }).format(date || new Date()));

    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'autumn';
    return 'winter';
  }

  function fullPath(season, small) {
    return 'self-map/full/adlermind-map-' + season + '-full' + (small ? '-768' : '') + '.webp';
  }

  function cardPath(season, region, small) {
    return 'self-map/cards/' + season + '/adlermind-map-' + season + '-' + region +
      (small ? '-512' : '') + '.webp';
  }

  // 모르는 이름이 섞여 와도 화면이 깨지지 않게 아는 구역만 남기고 중복을 없앱니다.
  function toRegions(value) {
    if (!Array.isArray(value)) return [];
    const out = [];
    value.forEach(item => {
      if (typeof item !== 'string') return;
      if (KEYS.indexOf(item) === -1) return;
      if (out.indexOf(item) !== -1) return;
      out.push(item);
    });
    return out;
  }

  const STYLE = `
.ams-area { margin-bottom: 56px; }
.ams-map { position: relative; width: 100%; aspect-ratio: 3 / 2; overflow: hidden;
           border: 0.5px solid #e8e4e0; background: #FAFAF8; }
.ams-map-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.ams-paths { position: absolute; inset: 0; z-index: 1; width: 100%; height: 100%; pointer-events: none; }
.ams-paths line { stroke: rgba(255,255,255,0.95); stroke-width: 0.55; stroke-dasharray: 1.1 1.3;
                  vector-effect: non-scaling-stroke; filter: drop-shadow(0 0 2px rgba(232,146,154,0.7)); }
.ams-marker { position: absolute; z-index: 2; display: grid;
              grid-template-areas: 'light count' 'label label';
              justify-items: center; color: #4A4A4A; text-decoration: none;
              transform: translate(-50%, -50%); }
.ams-light { grid-area: light; width: 11px; height: 11px; border: 1px solid rgba(255,255,255,0.95);
             border-radius: 50%; background: rgba(255,255,255,0.88);
             box-shadow: 0 0 0 4px rgba(255,255,255,0.25); }
.ams-marker-on .ams-light { background: #E8929A;
             box-shadow: 0 0 0 4px rgba(232,146,154,0.34), 0 0 16px 8px rgba(232,146,154,0.6); }
.ams-label { grid-area: label; margin-top: 5px; padding: 2px 7px; border-radius: 999px;
             background: rgba(255,255,255,0.9); font-family: 'Noto Serif KR', serif;
             font-size: 13px; white-space: nowrap; box-shadow: 0 1px 4px rgba(0,0,0,0.1); }
.ams-count { grid-area: count; min-width: 16px; height: 16px; margin: -4px 0 0 -2px; padding: 0 4px;
             border-radius: 999px; background: rgba(107,107,107,0.88);
             font-size: 13px; line-height: 16px; color: #fff; text-align: center; }
.ams-mobile-intro, .ams-mobile-cards { display: none; }
.ams-index { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; margin-top: 14px; }
.ams-index-card { min-width: 0; padding: 14px 15px 16px; border: 0.5px solid #e8e4e0;
                  background: #fff; scroll-margin-top: 90px; }
.ams-index-card h3 { margin: 0; font-family: 'Noto Serif KR', serif; font-size: 16px;
                     font-weight: 400; color: #4A4A4A; }
.ams-index-card p { min-height: 38px; margin: 5px 0 8px; font-size: 13px; line-height: 1.7; color: #6E6763; }
.ams-index-card ul, .ams-names { margin: 0; padding: 0; list-style: none; }
.ams-index-card li, .ams-names li { font-size: 13px; line-height: 1.7; color: #4A4A4A; }
.ams-index-card li::before, .ams-names li::before { content: '·'; margin-right: 5px; color: #6E6763; }
.ams-soft { border: 0.5px solid #e8e4e0; background: #fff; color: #4A4A4A;
            font-family: 'Noto Sans KR', sans-serif; font-weight: 400; font-size: 13.5px;
            padding: 5px 12px; cursor: pointer; transition: all 0.15s; }
.ams-soft:hover { border-color: #8FBFB8; color: #8FBFB8; }

@media (max-width: 760px) {
  .ams-map, .ams-index { display: none; }
  .ams-mobile-intro { display: block; margin-bottom: 14px; text-align: center; }
  .ams-mobile-scroll { width: 100%; margin-top: 10px; overflow-x: auto;
                       border: 0.5px solid #e8e4e0; background: #FAFAF8; }
  .ams-mobile-scroll img { display: block; width: 768px; max-width: none; height: auto; }
  .ams-mobile-cards { display: grid; gap: 14px; }
  .ams-mobile-card { overflow: hidden; border: 0.5px solid #e8e4e0; background: #fff; }
  .ams-mobile-card > img { display: block; width: 100%; height: auto; }
  .ams-card-body { padding: 18px 18px 20px; }
  .ams-card-body h3 { margin: 0; font-family: 'Noto Serif KR', serif; font-size: 21px;
                      font-weight: 400; color: #4A4A4A; }
  .ams-academic { margin: 3px 0 0; font-size: 13px; color: #6E6763; }
  .ams-factors { margin: 13px 0 0; font-size: 13px; line-height: 1.7; color: #6E6763; }
  .ams-desc { margin: 5px 0 0; font-size: 14px; line-height: 1.75; color: #4A4A4A; }
  .ams-names { margin-top: 12px; padding-top: 10px; border-top: 0.5px solid #e8e4e0; }
}
`;

  function styleOnce() {
    if (document.getElementById('ams-style')) return;
    const style = document.createElement('style');
    style.id = 'ams-style';
    style.textContent = STYLE;
    document.head.appendChild(style);
  }

  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    // 체험 이름은 자료 쪽에서 온 글이라 textContent 로만 넣습니다.
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function nameList(records) {
    const list = element('ul', 'ams-names');
    records.forEach(row => list.appendChild(element('li', null, row.experience_title)));
    return list;
  }

  function render(options) {
    const into = options.into;
    const rows = options.rows || [];
    if (!into) return;

    styleOnce();
    const season = options.season || currentSeason();
    const seasonName = SEASON_LABEL[season];

    // 줄마다 구역 목록을 한 번만 읽어 둡니다.
    const marked = rows.map(row => ({ row: row, regions: toRegions(row.map_regions) }));
    const byRegion = {};
    REGIONS.forEach(region => {
      byRegion[region.key] = marked
        .filter(item => item.regions.indexOf(region.key) !== -1)
        .map(item => item.row);
    });

    into.textContent = '';
    const area = element('section', 'ams-area');
    area.setAttribute('aria-label', '자기탐색 지도');

    // ── 컴퓨터 화면: 지도 한 장 위에 구역 표시 ──
    const map = element('div', 'ams-map');

    const image = element('img', 'ams-map-img');
    image.src = fullPath(season);
    image.alt = seasonName + '의 자기탐색 지도';
    map.appendChild(image);

    // 한 기록이 여러 구역에 걸리면 그 구역들을 선으로 잇습니다.
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('class', 'ams-paths');
    svg.setAttribute('viewBox', '0 0 100 100');
    svg.setAttribute('preserveAspectRatio', 'none');
    svg.setAttribute('aria-hidden', 'true');
    marked.forEach(item => {
      const first = REGIONS.filter(region => region.key === item.regions[0])[0];
      if (!first) return;
      item.regions.slice(1).forEach(key => {
        const to = REGIONS.filter(region => region.key === key)[0];
        if (!to) return;
        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', first.anchor.x);
        line.setAttribute('y1', first.anchor.y);
        line.setAttribute('x2', to.anchor.x);
        line.setAttribute('y2', to.anchor.y);
        svg.appendChild(line);
      });
    });
    map.appendChild(svg);

    REGIONS.forEach(region => {
      const records = byRegion[region.key];
      const marker = element('a', 'ams-marker' + (records.length > 0 ? ' ams-marker-on' : ''));
      marker.href = '#ams-region-' + region.key;
      marker.style.left = region.anchor.x + '%';
      marker.style.top = region.anchor.y + '%';
      marker.setAttribute('aria-label', region.name + '. 저장한 체험 ' + records.length + '건');
      marker.appendChild(element('span', 'ams-light'));
      marker.appendChild(element('span', 'ams-label', region.name));
      if (records.length > 0) marker.appendChild(element('span', 'ams-count', String(records.length)));
      map.appendChild(marker);
    });
    area.appendChild(map);

    // ── 휴대폰 화면: 전체 지도 열기 + 구역 카드 ──
    const intro = element('div', 'ams-mobile-intro');
    const toggle = element('button', 'ams-soft', '전체 지도 크게 보기');
    toggle.type = 'button';
    const scroll = element('div', 'ams-mobile-scroll');
    scroll.hidden = true;
    const fullImage = element('img');
    fullImage.src = fullPath(season, true);
    fullImage.alt = seasonName + ' 자기탐색 지도 전체 보기';
    scroll.appendChild(fullImage);
    toggle.addEventListener('click', () => {
      scroll.hidden = !scroll.hidden;
      toggle.textContent = scroll.hidden ? '전체 지도 크게 보기' : '전체 지도 닫기';
    });
    intro.appendChild(toggle);
    intro.appendChild(scroll);
    area.appendChild(intro);

    const cards = element('div', 'ams-mobile-cards');
    REGIONS.forEach(region => {
      const records = byRegion[region.key];
      const card = element('article', 'ams-mobile-card');
      const picture = element('img');
      picture.src = cardPath(season, region.key, true);
      picture.alt = region.name + '의 ' + seasonName + ' 풍경';
      picture.loading = 'lazy';
      card.appendChild(picture);

      const body = element('div', 'ams-card-body');
      body.appendChild(element('h3', null, region.name));
      body.appendChild(element('p', 'ams-academic', region.academic));
      body.appendChild(element('p', 'ams-factors', region.factors));
      body.appendChild(element('p', 'ams-desc', region.description));
      if (records.length > 0) body.appendChild(nameList(records));
      card.appendChild(body);
      cards.appendChild(card);
    });
    area.appendChild(cards);

    // ── 구역별 목록 (지도에서 누르면 오는 자리) ──
    const index = element('div', 'ams-index');
    index.setAttribute('aria-label', '지도 구역별 저장한 체험 목록');
    REGIONS.forEach(region => {
      const records = byRegion[region.key];
      const box = element('section', 'ams-index-card');
      box.id = 'ams-region-' + region.key;
      box.appendChild(element('h3', null, region.name));
      box.appendChild(element('p', null, region.description));
      if (records.length > 0) box.appendChild(nameList(records));
      index.appendChild(box);
    });
    area.appendChild(index);

    into.appendChild(area);
  }

  window.AMSelfMap = {
    SEASONS: SEASONS,
    REGIONS: REGIONS,
    KEYS: KEYS,
    seasonLabel: SEASON_LABEL,
    currentSeason: currentSeason,
    fullPath: fullPath,
    cardPath: cardPath,
    toRegions: toRegions,
    render: render
  };
})();
