// 별칭 기반 체험계정을 내부 이메일 노출 없이 생성하는 Supabase Edge Function입니다.
import { createClient } from 'npm:@supabase/supabase-js@2.95.0'

const allowedOrigins = new Set([
  'https://adlermind.co.kr',
  'https://www.adlermind.co.kr',
  'http://localhost:8766',
  'http://127.0.0.1:8766',
])

function corsHeaders(origin: string) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
    'Content-Type': 'application/json',
  }
}

function response(origin: string, status: number, message: string) {
  return new Response(JSON.stringify({ message }), { status, headers: corsHeaders(origin) })
}

async function nicknameToEmail(nickname: string) {
  const normalized = nickname.normalize('NFKC').trim().toLowerCase()
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(normalized))
  const hex = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('')
  return `u${hex.slice(0, 40)}@adlermind.co.kr`
}

Deno.serve(async request => {
  const origin = request.headers.get('origin') || ''
  if (!allowedOrigins.has(origin)) return response('https://adlermind.co.kr', 403, '허용되지 않은 요청입니다.')
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(origin) })
  if (request.method !== 'POST') return response(origin, 405, '지원하지 않는 요청입니다.')
  if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) return response(origin, 415, 'JSON 요청만 허용합니다.')

  let body: { nickname?: unknown; password?: unknown }
  try { body = await request.json() } catch { return response(origin, 400, '요청 형식을 확인해 주세요.') }
  const nickname = typeof body.nickname === 'string' ? body.nickname.normalize('NFKC').trim() : ''
  const password = typeof body.password === 'string' ? body.password : ''
  if (nickname.length < 2 || nickname.length > 20) return response(origin, 400, '별칭은 2자 이상 20자 이하로 입력해 주세요.')
  if (/[\u0000-\u001f\u007f]/u.test(nickname)) return response(origin, 400, '별칭에 사용할 수 없는 문자가 있습니다.')
  if (password.length < 6 || password.length > 72) return response(origin, 400, '비밀번호는 6자 이상 72자 이하로 입력해 주세요.')

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) return response(origin, 500, '서버 설정을 확인해 주세요.')
  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } })
  const email = await nicknameToEmail(nickname)
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { account_type: 'experience' },
  })
  if (error || !data.user) return response(origin, error?.message?.includes('already') ? 409 : 400, error?.message?.includes('already') ? '이미 사용 중인 별칭입니다.' : '체험계정을 만들지 못했습니다.')

  const { error: profileError } = await admin.from('site_users').insert({ user_id: data.user.id, nickname })
  if (profileError) {
    await admin.auth.admin.deleteUser(data.user.id)
    return response(origin, profileError.code === '23505' ? 409 : 500, profileError.code === '23505' ? '이미 사용 중인 별칭입니다.' : '체험계정을 완성하지 못했습니다.')
  }
  return response(origin, 201, '체험계정이 생성되었습니다.')
})
