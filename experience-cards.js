// 체험 카드 목록 · 2-3
// 대문과 상담의 방과 배움의 방이 이 코드 한 벌을 나눠 씁니다.
// 콘텐츠를 코드가 아니라 데이터로 — 관리자 페이지에서 등록하면 여기에 그대로 나타납니다.
(function () {
  const SUPABASE_URL = 'https://jboceiacgczkqkhqcmqu.supabase.co';
  const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impib2NlaWFjZ2N6a3FraHFjbXF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1OTg1MTYsImV4cCI6MjA5ODE3NDUxNn0.9jHLNB8PVDrWlSc5CDGz5j6ZF9yaKwrnzICvvvsFbvA';

  const CSS = `
.exp-strip { margin: 0; }
.exp-strip-scroll {
  display: flex; gap: 16px; overflow-x: auto; padding: 4px 0 18px;
  scroll-snap-type: x proximity; -webkit-overflow-scrolling: touch;
}
.exp-card {
  flex: 0 0 262px; scroll-snap-align: start;
  display: flex; flex-direction: column; text-align: left;
  background: #fff; border: 0.5px solid #e8e4e0;
  color: #6B6B6B; text-decoration: none;
  transition: border-color .15s, transform .15s;
  overflow: hidden;
}
.exp-card:hover { border-color: #8FBFB8; transform: translateY(-2px); }
/* 섬네일. 16:9 자리를 늘 차지하므로 그림이 늦게 떠도 카드가 덜컹이지 않습니다. */
.exp-card-thumb {
  display: block; width: 100%; aspect-ratio: 16 / 9;
  object-fit: cover; background: #f4f2ef;
}
.exp-card-body { padding: 20px 20px 22px; display: flex; flex-direction: column; flex: 1; }
.exp-card-label {
  font-family: 'Raleway', sans-serif; font-size: 9.5px; font-weight: 300;
  letter-spacing: .22em; color: #9a9490; text-transform: uppercase;
}
.exp-card-title {
  font-family: 'Noto Serif KR', serif; font-size: 16px; font-weight: 300;
  color: #6B6B6B; margin: 10px 0 0; line-height: 1.6;
}
.exp-card-summary { font-size: 12.5px; line-height: 1.9; color: #9a9490; margin: 8px 0 0; }
.exp-card-go {
  font-size: 11.5px; color: #8FBFB8; margin: 16px 0 0; letter-spacing: .04em;
}
/* 그림이 없는 카드는 위가 허전하지 않게 여백을 조금 더 줍니다. */
.exp-card-plain .exp-card-body { padding-top: 26px; }
.exp-empty { font-size: 12.5px; line-height: 2; color: #9a9490; }
/* 대문 히어로용. 섬네일 한 장만 보여줍니다.
   섬네일에 프로그램 내용이 유튜브처럼 적혀 오므로 글자를 겹쳐 적지 않습니다.
   섬네일이 아직 없는 카드(exp-card-plain)는 빈 칸이 되지 않도록 글자를 그대로 둡니다. */
.exp-compact .exp-card { flex: 0 0 281px; }
.exp-compact .exp-card:not(.exp-card-plain) .exp-card-body { display: none; }
.exp-compact .exp-card-plain .exp-card-body { padding: 20px 18px; }
.exp-compact .exp-card-plain .exp-card-title { font-size: 15px; margin-top: 8px; }
.exp-compact .exp-card-plain .exp-card-summary { font-size: 12px; margin-top: 6px; }
.exp-compact .exp-card-plain .exp-card-go { margin-top: 12px; }
@media (max-width: 600px) {
  .exp-card { flex-basis: 232px; }
  .exp-compact .exp-card { flex-basis: 262px; }
}
`;

  const ROOM_LABEL = { counseling: 'COUNSELING', education: 'EDUCATION' };
  const THUMB_BUCKET = 'experience-thumbs';

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, ch =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  }

  function injectStyle() {
    if (document.getElementById('exp-cards-style')) return;
    const style = document.createElement('style');
    style.id = 'exp-cards-style';
    style.textContent = CSS;
    document.head.appendChild(style);
  }

  function cardHtml(item) {
    // 바깥 링크는 그쪽으로 바로 나가고, 붙여넣은 HTML 은 체험 화면에서 실행합니다.
    const isLink = item.content_type === 'link';
    const href = isLink ? item.link_url : `experience.html?key=${encodeURIComponent(item.experience_key)}`;
    const target = isLink ? ' target="_blank" rel="noopener noreferrer"' : '';

    // 섬네일 버킷은 공개라 주소로 바로 열립니다. 서명 URL 을 받지 않으므로
    // 대문 첫 화면에서 그림마다 요청이 붙지 않고 브라우저 캐시가 그대로 듣습니다.
    const thumb = item.thumb_path
      ? `<img class="exp-card-thumb" src="${SUPABASE_URL}/storage/v1/object/public/${THUMB_BUCKET}/${item.thumb_path}"
             alt="" loading="lazy">`
      : '';

    // 대문에서는 글자를 감추므로 링크에 읽어줄 이름을 따로 답니다.
    // 화면에는 나타나지 않고 화면낭독기와 마우스 올렸을 때만 쓰입니다.
    return `
      <a class="exp-card${thumb ? '' : ' exp-card-plain'}" href="${escapeHtml(href)}"${target}
         aria-label="${escapeHtml(item.title)}" title="${escapeHtml(item.title)}">
        ${thumb}
        <span class="exp-card-body">
          <span class="exp-card-label">${ROOM_LABEL[item.placement] || 'EXPERIENCE'}</span>
          <span class="exp-card-title">${escapeHtml(item.title)}</span>
          ${item.summary ? `<span class="exp-card-summary">${escapeHtml(item.summary)}</span>` : ''}
          <span class="exp-card-go">${isLink ? '바로 가기 &rarr;' : '해보기 &rarr;'}</span>
        </span>
      </a>`;
  }

  // options.into      : 카드를 그릴 요소의 id
  // options.placement : 'counseling' · 'education' 이면 그 방 것만, 없으면 걸려 있는 것 전부(대문)
  // options.onEmpty   : 등록된 체험이 없을 때 부릅니다. 없으면 그 자리를 비워 둡니다.
  async function render(options) {
    const host = document.getElementById(options.into);
    if (!host) return;

    let query = `${SUPABASE_URL}/rest/v1/experiences` +
      `?select=experience_key,title,summary,placement,content_type,link_url,thumb_path,sort_order` +
      `&order=sort_order.asc&order=created_at.asc`;
    query += options.placement
      ? `&placement=eq.${options.placement}`
      : '&placement=neq.hidden';

    let items = [];
    try {
      const response = await fetch(query, { headers: { apikey: SUPABASE_KEY } });
      if (response.ok) items = await response.json();
    } catch (error) {
      items = [];
    }

    // 아직 등록된 체험이 없으면 페이지의 원래 안내를 그대로 둡니다.
    if (!items.length) {
      if (options.onEmpty) options.onEmpty();
      return;
    }

    injectStyle();
    host.innerHTML = `<div class="exp-strip${options.compact ? ' exp-compact' : ''}">` +
      `<div class="exp-strip-scroll">${items.map(cardHtml).join('')}</div></div>`;
    if (options.onReady) options.onReady(items.length);
  }

  window.AMExperienceCards = { render, SUPABASE_URL, SUPABASE_KEY };
})();
