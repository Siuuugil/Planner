// Supabase 접속 정보. publishable 키는 공개용 키라 앱에 넣어도 되며,
// 데이터 접근은 DB의 RLS 정책(본인 데이터만)으로 보호된다.
const supabaseUrl = 'https://edykgbaqmlmmmgwwgqtb.supabase.co';
const supabasePublishableKey = 'sb_publishable_S6pR80hHvWnppfE4nIO88A_t1SdiOfv';

/// 웹 앱 주소: 가입 확인·비밀번호 재설정 메일의 링크가 여기로 열린다.
/// (Supabase Authentication → URL Configuration 의 Site URL / Redirect URLs 에 등록 필요)
const webAppUrl = 'https://siuuugil.github.io/Planner/';

/// 빌드 번호·커밋 (GitHub Actions 가 --dart-define 으로 넣음, 직접 빌드하면 'dev')
const buildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');
const buildSha = String.fromEnvironment('BUILD_SHA', defaultValue: '');
String get buildLabel => buildSha.isEmpty ? '개발 빌드' : '빌드 #$buildId · ${buildSha.substring(0, 7)}';
