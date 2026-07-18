// 공개 페이지에서 체험계정과 이메일 회원의 로그인 표시를 통합합니다.
(async () => {
  if (!window.supabase || typeof SB_URL === 'undefined' || typeof SB_KEY === 'undefined') return;

  const client = window._sbNav || window.sb || window.supabase.createClient(SB_URL, SB_KEY);
  const { data: { session } } = await client.auth.getSession();
  if (!session) return;

  let nickname = '';
  let accountPage = 'mypage.html';

  const { data: experienceProfile } = await client
    .from('site_users')
    .select('nickname')
    .eq('user_id', session.user.id)
    .maybeSingle();

  if (experienceProfile) {
    nickname = experienceProfile.nickname;
  } else {
    const { data: formalProfile } = await client
      .from('site_profiles')
      .select('nickname, display_name')
      .eq('user_id', session.user.id)
      .maybeSingle();
    if (!formalProfile) return;
    nickname = formalProfile.nickname || formalProfile.display_name;
    accountPage = 'account-home.html';
  }

  ['navLoginLink', 'navLoginMobile'].forEach(id => {
    const element = document.getElementById(id);
    if (!element) return;
    element.textContent = `${nickname}님의 Life Style`;
    element.href = accountPage;
  });
})();
