# CLAUDE.md

마이플래너(MyPlanner): 일정·할 일·게임(메이플) 관리 Flutter 앱. Android · Windows · 웹.
사용자에게는 **한국어로** 답한다. 기능 설명은 `README.md`, 폴더 구조는 README의 "구조" 섹션.

## 세 앱이 한 테이블로 연결됨 (공유 채널)

Supabase 프로젝트 `game-planner`(서울)의 `public.items` 테이블 하나를 세 앱이 같이 쓴다.

- **MyPlanner** (이 레포): 일정·할 일 등을 쓰고 읽음
- **할 일 앱** (앞으로 만들 예정)
- **PC 마을** (별도 Next.js 프로젝트 `llm-wiki`): 일정·할 일을 읽고, 아래 `event`·`inbox` 행을 처리함

`items` 행: `{ user_id, id, kind, data(jsonb), deleted, updated_at }`, 기본키 `(user_id, id)`, RLS로 본인 행만.

`kind` 값 (DB 제약 `items_kind_check`, `supabase/schema.sql`에 기록):

| kind | 누가 씀 | 내용 |
|---|---|---|
| `schedule` `game` `task` `maple` `mark` `ai` | MyPlanner | 앱 데이터 (모델별 `toJson()`) |
| `inbox` | MyPlanner가 **쓰기만** | 📥 수집: `data = { text, source: 'planner', at: <ISO> }`. PC 마을이 디스코드 DM(할 일로 / 마을 서재로 / 버리기)으로 처리한 뒤 `deleted: true` + 새 `updated_at` |
| `event` | PC 마을 쪽 | 폰 푸시 + 디스코드 DM 알림. **앱에서는 아직 쓰지 않는다** (앱은 자체 로컬 알림 사용) |

규칙:
- `data`는 일반 JSON만.
- 병합은 `updated_at`이 더 최신인 쪽이 이김 (DB 트리거 `items_keep_newer`가 오래된 업데이트를 버림).
- 앱이 모르는 `kind`는 `AppStore.applyRemote`에서 **무시**한다 (지우거나 덮어쓰지 말 것).
- 새 `kind`를 추가하려면 실제 DB 제약도 바꿔야 함 — 라이브 DB는 사용자 확인 없이 건드리지 않는다. `schema.sql`은 기록용.

### 그 밖의 공유 자원

- **Supabase Storage `voice` 버킷** (비공개, 최대 5MB, mp3/wav): AI 답을 '내 목소리'로 만든 음성. 경로 `<user_id>/<노트 id>.mp3`, RLS로 본인 폴더만. 재생은 서명 URL(10분). 대화를 지우면 파일도 지움 (`AiService.deleteChats`).
- **`ai` 행의 대화 상태** (`AiNote.status`): 폰·웹은 질문을 `{type:'chat', status:'pending'}`로 쓰고, PC 앱이 `'working'`으로 잡은 뒤 답을 채우며 `status`를 지운다 (`null` = 답 완료, `'error'` = 실패). 여러 PC가 켜져 있으면 `by`(기기 id)로 한 대만 답한다. 다른 앱이 `ai` 행을 읽을 때 이 값을 참고.

## AI · 음성 구조

- AI는 **PC 앱에서만** 사용자 PC의 Claude Code CLI로 실행 (`lib/ai/claude_cli*.dart`, API 키 없음). 폰·웹은 위 `pending` 중계로 PC에게 묻는다.
- 음성: 폰·웹 음성 인식(`speech_to_text`) + 읽기(`flutter_tts`), PC의 '내 목소리'는 `voice_server/`.
- **`voice_server/`**: 앱과 따로 도는 PC용 Python 서버 (`127.0.0.1:9800`, GPT-SoVITS api_v2 또는 Qwen3-TTS). CI는 빌드하지 않음. 테스트는 `cd voice_server && python -m unittest test_server.py`. 설치·학습 보조 스크립트(`install_windows.ps1`, `setup_voice.py`, `asr_korean.py`, `fix_korean_mecab.py`)도 여기.

## 동기화 구조 (`lib/data/`)

- `AppStore`: 로컬 상태(SharedPreferences JSON). `commit()` → `_diff()`가 바뀐 레코드를 `pending`에 쌓음.
- `SyncService`: 로그인·앱 복귀·로컬 변경 시 전체 받아 `applyRemote` → `pending` 업로드(upsert). Realtime으로 즉시 반영.
- `AppStore.addCapture(text)`: `inbox` 행을 `pending`에만 넣음 (`_known`에 안 넣어서 `_diff`가 삭제로 오해하지 않음). 앱에 목록은 없음.
- Android 공유(`text/plain`) → `MainActivity.kt` → MethodChannel `myplanner/share` → `lib/data/capture.dart`의 `ShareIntake`.

## 작업 규칙

여러 세션(Claude)이 이 레포를 같이 쓴다. 서로 덮어쓰지 않게:

- **작업 시작 전 기본 브랜치를 최신으로 받는다.** `git fetch` 후 뒤처져 있으면 `git pull`, 이미 최신이면 받지 말고 그대로 작업.
- **기능을 추가하거나 구조를 바꾸면 이 파일(CLAUDE.md)도 갱신한다.** 새 `kind`·공유 자원·폴더·규칙이 생기면 해당 섹션에 적는다.

- **공개 레포**: 비밀값(API 키, 토큰, 비밀번호) 커밋 금지. `lib/config.dart`의 Supabase publishable key는 공개용이라 괜찮음.
- **녹음·음성 파일 커밋 금지**: 실제 사람 목소리(`voice_server/refs/`, `voice.json`, `*.wav`, `*.mp3`)는 레포에 올리지 않는다 (`voice_server/.gitignore`로 막혀 있음).
- **웹 빌드**: `dart:io`를 직접 import하지 말 것. PC 전용 코드는 `claude_cli.dart`·`desktop/desktop_shell.dart`처럼 `_io.dart`/`_stub.dart` 조건부 export로 나눈다.
- 변경 후 `flutter analyze` 깨끗하게, `flutter test` 통과 유지. 동기화 로직을 바꾸면 `test/sync_test.dart`에 테스트 추가.
- CI(`.github/workflows/build.yml`): 푸시마다 검사·테스트 + Android/Windows/웹 빌드. **기본 브랜치**면 "latest" 릴리스(APK·Windows zip) 갱신 + GitHub Pages 웹 배포. `*.md`, `supabase/**`만 바뀌면 빌드 안 함.
- Android APK는 고정 키로 서명해야 폰에서 업데이트 설치가 됨 (CI가 서명 SHA-256 확인).
- Flutter 버전은 CI의 `FLUTTER_VERSION`과 맞춘다.
- 기능을 추가하면 `README.md`의 "기능" 섹션도 업데이트.
