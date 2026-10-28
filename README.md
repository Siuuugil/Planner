# 게임 플래너 (game_planner)

내 일정과 게임 스펙업을 함께 관리하는 Flutter 앱. Android, Windows(PC), 웹에서 동작합니다.

## 기능

- **오늘**: 오늘 일정, 아직 안 한 게임 숙제, 진행 중인 스펙업 목표를 한 화면에
- **일정**: 월/2주/주 캘린더, 일정 추가·수정·완료 체크, 게임과 연결 가능
- **게임**
  - 게임별 **일일/주간 숙제**: 게임마다 초기화 시각(기본 오전 6시)과 주간 초기화 요일(기본 수요일)을 설정하면 시간이 지나면 자동으로 다시 미완료가 됨
  - **스펙업 목표**: 시작값 → 현재값 → 목표값, 진행률 바, 마감일 D-day
  - 게임에 연결된 다가오는 일정
- **폰 ↔ PC 동기화** (Supabase): 이메일로 로그인하면 자동으로 맞춰짐
  - 오프라인에서도 그대로 사용 가능, 인터넷이 연결되면 밀린 변경을 올림
  - 다른 기기에서 바꾼 내용은 실시간으로 반영 (같은 항목을 양쪽에서 고치면 나중에 고친 쪽이 남음)
  - 로그인 안 해도 기기 안에서는 그대로 동작

## 설치 (Flutter 필요 없음)

코드를 올리면 GitHub Actions가 자동으로 빌드해서 레포의 **Releases → 최신 빌드** 에 올려 둡니다.

- **PC (Windows)**: `GamePlanner-windows.zip` 받아서 압축 풀고 `game_planner.exe` 실행
  (바탕화면 바로가기 만들어 두면 끝. 새 버전은 같은 폴더에 덮어쓰기)
- **Android**: `GamePlanner.apk` 받아서 설치 (처음 한 번 "출처를 알 수 없는 앱" 허용)
- **웹**: https://siuuugil.github.io/-/ (레포 이름을 바꾸면 주소의 `-` 부분도 바뀜)
  크롬 주소창의 "앱 설치" 아이콘으로 PC에 프로그램처럼 설치 가능

## 개발용 실행

[Flutter SDK](https://docs.flutter.dev/get-started/install) 설치 후:

```bash
flutter pub get
flutter run -d windows   # PC (Windows)
flutter run -d chrome    # 웹
flutter run              # 연결된 안드로이드 기기/에뮬레이터
```

빌드:

```bash
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
flutter build windows         # build/windows/x64/runner/Release/
flutter build web
```

## 동기화 설정

- Supabase 프로젝트: `game-planner` (서울 리전), 접속 정보는 `lib/config.dart`
- DB 스키마: `supabase/schema.sql` (`items` 테이블 + 본인 데이터만 접근하는 RLS)
- 가입 시 확인 메일의 링크를 한 번 눌러야 로그인됨. 번거로우면 Supabase 대시보드 →
  Authentication → Sign In / Providers → Email 에서 *Confirm email* 을 끄면 됨

## 구조

```
lib/
  main.dart                 앱 진입점, 테마, 한국어 로케일
  models/                   Schedule, Game, Goal, Chore (+ 초기화 계산)
  data/                     AppStore(상태 + 저장 + 변경 추적), SyncService(Supabase 동기화)
  screens/                  오늘 / 일정 / 게임 / 게임 상세
  widgets/                  타일과 추가·수정 다이얼로그
test/                       초기화 계산·진행률·화면 테스트
```

## 다음에 해볼 것

- 숙제·일정 알림 (로컬 푸시)
- 반복 일정
- 스펙업 기록 그래프
