// 로그인한 본인이 자기 계정을 지우는 Supabase Edge Function입니다.
// 지울 대상은 요청 본문이 아니라 로그인 증명서(JWT)에서만 읽습니다. 남의 계정 번호를 보내와도 무시됩니다.
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
    'Access-Control-Allow-Headers': 'apikey, authorization, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
    'Content-Type': 'application/json',
  }
}

function response(origin: string, status: number, message: string) {
  return new Response(JSON.stringify({ message }), { status, headers: corsHeaders(origin) })
}

Deno.serve(async request => {
  const origin = request.headers.get('origin') || ''
  if (!allowedOrigins.has(origin)) return response('https://adlermind.co.kr', 403, '허용되지 않은 요청입니다.')
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(origin) })
  if (request.method !== 'POST') return response(origin, 405, '지원하지 않는 요청입니다.')

  const authorization = request.headers.get('authorization') || ''
  if (!authorization.toLowerCase().startsWith('bearer ')) return response(origin, 401, '로그인 후 다시 시도해 주세요.')

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !anonKey || !serviceRoleKey) return response(origin, 500, '서버 설정을 확인해 주세요.')

  // 보내온 로그인 증명서가 실제로 유효한지 Supabase에 되물어 확인합니다.
  const caller = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authorization } },
  })
  const { data: { user }, error: userError } = await caller.auth.getUser()
  if (userError || !user) return response(origin, 401, '로그인 정보를 확인하지 못했습니다. 다시 로그인한 뒤 시도해 주세요.')

  // 계정 삭제는 관리자 권한이 있어야 하므로 여기서만 service_role 열쇠를 씁니다.
  // auth.users 가 지워지면 별칭·회원정보·체험기록·공개후기는 외래키 연쇄삭제로 함께 지워지고,
  // 조합원 명부(member_accounts)는 on delete set null 이라 명부는 남고 계정 연결만 끊깁니다.
  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } })
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)
  if (deleteError) {
    console.error('delete user failed', user.id, deleteError.message)
    return response(origin, 500, '계정을 지우지 못했습니다. 잠시 후 다시 시도해 주세요.')
  }

  return response(origin, 200, '계정을 삭제했습니다.')
})
