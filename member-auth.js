// 조합원 초대 계정의 인증 상태와 활성 조합원 권한을 확인하는 공통 모듈
(function () {
  const SUPABASE_URL = 'https://jboceiacgczkqkhqcmqu.supabase.co';
  const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impib2NlaWFjZ2N6a3FraHFjbXF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1OTg1MTYsImV4cCI6MjA5ODE3NDUxNn0.9jHLNB8PVDrWlSc5CDGz5j6ZF9yaKwrnzICvvvsFbvA';
  const client = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

  async function getActiveMember() {
    const { data: { session }, error: sessionError } = await client.auth.getSession();
    if (sessionError || !session || !session.user.email_confirmed_at) return null;

    const { data: member, error: memberError } = await client
      .from('member_accounts')
      .select('user_id,email,display_name,is_active')
      .eq('user_id', session.user.id)
      .eq('is_active', true)
      .maybeSingle();

    if (memberError || !member) return null;
    return { session, member };
  }

  // 관리자 권한은 조합원 권한과 별도 계층이며 site_admins 활성 행으로만 판정한다.
  async function getActiveAdmin() {
    const { data: { session }, error: sessionError } = await client.auth.getSession();
    if (sessionError || !session || !session.user.email_confirmed_at) return null;

    const { data: admin, error: adminError } = await client
      .from('site_admins')
      .select('user_id,is_active')
      .eq('user_id', session.user.id)
      .eq('is_active', true)
      .maybeSingle();

    if (adminError || !admin) return null;
    return { session, admin };
  }

  async function requireActiveMember(redirectPath) {
    const auth = await getActiveMember();
    if (!auth) {
      window.location.replace(redirectPath);
      return null;
    }
    return auth;
  }

  function restHeaders(accessToken, extra) {
    return Object.assign({
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    }, extra || {});
  }

  function extractStoragePath(value, bucket) {
    if (!value) return null;
    if (value.startsWith(`${bucket}:`)) return value.slice(bucket.length + 1);
    const marker = `/storage/v1/object/public/${bucket}/`;
    const index = value.indexOf(marker);
    return index >= 0 ? value.slice(index + marker.length).split('?')[0] : null;
  }

  async function signedStorageUrl(value, bucket, expiresIn) {
    const path = extractStoragePath(value, bucket);
    if (!path) return value;
    const { data, error } = await client.storage
      .from(bucket)
      .createSignedUrl(decodeURIComponent(path), expiresIn || 600);
    return error ? null : data.signedUrl;
  }

  window.AMMemberAuth = {
    SUPABASE_URL,
    SUPABASE_KEY,
    client,
    getActiveMember,
    getActiveAdmin,
    requireActiveMember,
    restHeaders,
    signedStorageUrl
  };
})();
