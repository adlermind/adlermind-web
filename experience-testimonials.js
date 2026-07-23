// 체험후기 · 2-5
// 관리자가 등록한 후기를 첫화면에 가로스크롤로 표시합니다.
// 3개까지 안정적으로 보이고, 4개 이상이면 좌우 스크롤이 생깁니다.
(function () {
  const SUPABASE_URL = 'https://jboceiacgczkqkhqcmqu.supabase.co';
  const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impib2NlaWFjZ2N6a3FraHFjbXF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1OTg1MTYsImV4cCI6MjA5ODE3NDUxNn0.9jHLNB8PVDrWlSc5CDGz5j6ZF9yaKwrnzICvvvsFbvA';

  const CSS = `
.test-strip { margin: 0; }
.test-strip-scroll {
  display: flex; gap: 16px; overflow-x: auto; padding: 4px 0 18px;
  scroll-snap-type: x proximity; -webkit-overflow-scrolling: touch;
}
.test-card {
  flex: 0 0 285px; scroll-snap-align: start;
  display: flex; flex-direction: row; align-items: flex-start; gap: 12px;
  background: #fff; border: 0.5px solid #e8e4e0;
  padding: 14px 16px;
  color: #6B6B6B; text-decoration: none;
  transition: border-color .15s, background .15s;
  cursor: default;
}
.test-card:hover { border-color: #8FBFB8; }
/* 사진 영역: 100×70, 동적 팝업 용 */
.test-photo {
  flex: 0 0 100px; width: 100px; height: 70px;
  object-fit: cover; background: #f4f2ef;
  border: 0.5px solid #eeeae6;
  cursor: pointer;
  display: block;
}
.test-photo:hover { opacity: 0.9; }
.test-content { flex: 1; display: flex; flex-direction: column; }
.test-header { display: flex; gap: 8px; align-items: baseline; margin-bottom: 6px; }
.test-alias {
  font-family: 'Noto Serif KR', serif; font-size: 13px; font-weight: 400;
  color: #5e7773;
}
.test-program {
  font-size: 11px; color: #98928d; letter-spacing: .04em;
}
.test-body {
  font-size: 12px; line-height: 1.6; color: #6B6B6B;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
  overflow: hidden; word-break: break-word;
  margin-bottom: 6px;
}
.test-more {
  font-size: 11px; color: #8FBFB8; cursor: pointer;
  text-decoration: underline; letter-spacing: .04em;
}
.test-empty { font-size: 12.5px; line-height: 2; color: #9a9490; text-align: center; padding: 20px; }

/* 팝업 모달 */
.test-modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%;
  background: rgba(0,0,0,0.5); z-index: 1000; align-items: center; justify-content: center; }
.test-modal.open { display: flex; }
.test-modal-content {
  background: #fff; max-width: 90vw; max-height: 90vh;
  display: flex; flex-direction: column; overflow: hidden;
}
.test-modal-img { max-width: 100%; max-height: 70vh; object-fit: contain; }
.test-modal-close {
  align-self: flex-end; padding: 8px 12px;
  background: none; border: none; font-size: 20px; color: #6B6B6B;
  cursor: pointer; line-height: 1;
}

/* 스크롤 없이 3개가 안정 표시 */
@media (max-width: 960px) {
  .test-card { flex-basis: 260px; }
}
@media (max-width: 600px) {
  .test-card { flex-basis: 240px; }
  .test-photo { width: 80px; height: 56px; }
  .test-alias { font-size: 12px; }
  .test-program { font-size: 10px; }
}
`;

  const THUMB_BUCKET = 'experience-thumbs';

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, ch =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  }

  function injectStyle() {
    if (document.getElementById('test-style')) return;
    const style = document.createElement('style');
    style.id = 'test-style';
    style.textContent = CSS;
    document.head.appendChild(style);
  }

  function cardHtml(item) {
    const photo = item.photo_path
      ? `<img class="test-photo" src="${SUPABASE_URL}/storage/v1/object/public/${THUMB_BUCKET}/${item.photo_path}"
             alt="${escapeHtml(item.alias)}" loading="lazy" data-full-path="${item.photo_path}">`
      : '';

    const bodyShort = item.body.substring(0, 100);
    const hasMore = item.body.length > 100;

    return `
      <div class="test-card">
        ${photo}
        <div class="test-content">
          <div class="test-header">
            <span class="test-alias">${escapeHtml(item.alias)}</span>
            <span class="test-program">· ${escapeHtml(item.program_label)}</span>
          </div>
          <div class="test-body">${escapeHtml(bodyShort)}${hasMore ? '...' : ''}</div>
          ${hasMore ? `<span class="test-more">더보기</span>` : ''}
        </div>
      </div>`;
  }

  async function fetchTestimonials() {
    try {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/experience_testimonials?is_visible=eq.true&order=sort_order.asc`,
        {
          headers: {
            'Authorization': `Bearer ${SUPABASE_KEY}`,
            'apikey': SUPABASE_KEY,
          },
        }
      );
      if (!res.ok) return [];
      return await res.json();
    } catch (e) {
      console.error('Failed to fetch testimonials:', e);
      return [];
    }
  }

  function createModal() {
    const modal = document.createElement('div');
    modal.className = 'test-modal';
    modal.id = 'test-modal';
    modal.innerHTML = `
      <div class="test-modal-content">
        <button class="test-modal-close" type="button" aria-label="닫기">×</button>
        <img class="test-modal-img" alt="">
      </div>`;
    modal.querySelector('.test-modal-close').addEventListener('click', () => modal.classList.remove('open'));
    modal.addEventListener('click', (e) => {
      if (e.target === modal) modal.classList.remove('open');
    });
    document.body.appendChild(modal);
    return modal;
  }

  function renderTestimonials(into, items) {
    const container = document.getElementById(into);
    if (!container) return;

    injectStyle();

    if (!items.length) {
      container.innerHTML = '<div class="test-empty">아직 등록된 후기가 없습니다.</div>';
      return;
    }

    let modal = document.getElementById('test-modal');
    if (!modal) modal = createModal();

    const html = `
      <div class="test-strip">
        <div class="test-strip-scroll">
          ${items.map(item => cardHtml(item)).join('')}
        </div>
      </div>`;

    container.innerHTML = html;

    // 이벤트 위임: 사진 클릭 → 팝업
    container.addEventListener('click', (e) => {
      if (e.target.classList.contains('test-photo')) {
        const fullPath = e.target.getAttribute('data-full-path');
        const img = modal.querySelector('img');
        img.src = `${SUPABASE_URL}/storage/v1/object/public/${THUMB_BUCKET}/${fullPath}`;
        modal.classList.add('open');
      }

      // 더보기 → 글 펼쳐짐
      if (e.target.classList.contains('test-more')) {
        const card = e.target.closest('.test-card');
        const bodyDiv = card.querySelector('.test-body');
        const item = items.find(i => i.alias === card.querySelector('.test-alias').textContent);
        if (item) {
          bodyDiv.textContent = item.body;
          bodyDiv.style.WebkitLineClamp = 'unset';
          bodyDiv.style.overflow = 'visible';
          e.target.remove();
        }
      }
    });
  }

  // 전역 함수로 노출
  window.AMTestimonials = {
    async render(opts) {
      const items = await fetchTestimonials();
      renderTestimonials(opts.into || 'amReviews', items);
      if (opts.onReady) opts.onReady();
    }
  };
})();
