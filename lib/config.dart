// Supabase 접속 정보. publishable 키는 공개용 키라 앱에 넣어도 되며,
// 데이터 접근은 DB의 RLS 정책(본인 데이터만)으로 보호된다.
const supabaseUrl = 'https://edykgbaqmlmmmgwwgqtb.supabase.co';
const supabasePublishableKey = 'sb_publishable_S6pR80hHvWnppfE4nIO88A_t1SdiOfv';

/// 웹 앱 주소: 가입 확인·비밀번호 재설정 메일의 링크가 여기로 열린다.
/// (Supabase Authentication → URL Configuration 의 Site URL / Redirect URLs 에 등록 필요)
const webAppUrl = 'https://siuuugil.github.io/Planner/';
