# 마이플래너 (MyPlanner)

일정, 업무, 기타 할 일, 게임 스펙업을 한곳에서 관리하는 Flutter 앱. Android, Windows(PC), 웹에서 동작합니다.

## 기능

4개 탭: **홈 · 캘린더 · 할 일 · 메이플**

- **홈**: 오늘 일정·마감 할 일·게임 숙제를 시간순 한 목록으로, 진행률, 결정석·캐릭터 위젯
- **캘린더**: 월/2주/주 캘린더에 일정과 마감일 있는 할 일 함께 표시
- **할 일**: 업무·개인 할 일 [전체 | 업무 | 개인] 필터, 빠른 추가, 마감일·D-day, 완료 접기
- **메이플**: 캐릭터 카드 + [숙제 | 결정석 | 성장 | 목표], 다른 게임도 숙제 탭에서 관리
  - 게임별 **일일/주간 숙제**: 게임마다 초기화 시각(기본 오전 6시)과 주간 초기화 요일(기본 수요일)을 설정하면 시간이 지나면 자동으로 다시 미완료가 됨
  - **스펙업 목표**: 시작값 → 현재값 → 목표값, 진행률 바, 마감일 D-day
  - 게임에 연결된 다가오는 일정
- **메이플스토리 캐릭터 연동** (넥슨 Open API, 설정에서 API 키 입력)
  - 닉네임 검색 → 캐릭터 이미지·레벨·경험치·직업·월드·길드·전투력
  - 레벨·전투력 목표를 만들면 현재값이 캐릭터 갱신 때 자동으로 채워짐
  - 성장 기록 그래프 (레벨/전투력), 지난 14일 기록 불러오기
  - 주요 스탯, 장착 장비(스타포스·잠재능력)
  - API 키는 기기에만 저장, 캐릭터·기록은 계정에 동기화
- **💎 결정석 수익** (게임 탭)
  - 매주 잡는 보스를 캐릭터별로 등록 (파티 인원만큼 나눠서 계산), 주간 퀘스트처럼 체크
  - 이번 주 수익/예상 수익, 캐릭터당 주간 판매 제한(14개) 경고, 주간 수익 기록 그래프·평균·누적
  - 메소 목표: 결정석 수익이 자동으로 쌓이고 "지금 속도면 N주 뒤" 예상
  - 가격표 기본값: [보스 결정 가격 정리](https://matsu1207.tistory.com/757) (2026.10.22 기준), 앱에서 수정 가능
  - 주간 초기화 알림에 남은 결정석 금액 표시
- **알림** (설정 ⚙️): 일정 시작 N분 전, 마감일·종일 일정 당일 아침, 게임 숙제 초기화 N시간 전에 남은 숙제
  - Android·Windows는 앱이 꺼져 있어도 울림, 웹은 페이지가 열려 있을 때만
- **폰 ↔ PC 동기화** (Supabase): 이메일로 로그인하면 자동으로 맞춰짐
  - 오프라인에서도 그대로 사용 가능, 인터넷이 연결되면 밀린 변경을 올림
  - 다른 기기에서 바꾼 내용은 실시간으로 반영 (같은 항목을 양쪽에서 고치면 나중에 고친 쪽이 남음)
  - 로그인 안 해도 기기 안에서는 그대로 동작

## 설치 (Flutter 필요 없음)

코드를 올리면 GitHub Actions가 자동으로 빌드해서 레포의 **Releases → 최신 빌드** 에 올려 둡니다.

- **PC (Windows)**: `MyPlanner-windows.zip` 받아서 압축 풀고 `my_planner.exe` 실행
  (바탕화면 바로가기 만들어 두면 끝. 새 버전은 같은 폴더에 덮어쓰기)
- **Android**: `MyPlanner.apk` 받아서 설치 (처음 한 번 "출처를 알 수 없는 앱" 허용)
- **웹**: https://siuuugil.github.io/Planner/
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
  models/                   Schedule, Task, Game, Goal, Chore (+ 초기화 계산)
  data/                     AppStore(상태 + 저장 + 변경 추적), SyncService(Supabase 동기화)
  notify/                   알림 계획(reminders.dart)·예약(notify_service.dart)
  maple/                    넥슨 Open API 클라이언트·캐릭터 갱신
  ui/kit.dart               테마와 공통 디자인 요소 (섹션 카드, 진행 막대, 체크 등)
  screens/                  홈 / 캘린더 / 할 일 / 메이플 (+ 캐릭터·결정석·게임 상세, 계정, 설정)
  widgets/                  타일과 추가·수정 다이얼로그
test/                       초기화 계산·진행률·동기화 병합·알림 계획·화면 테스트
```

## 다음에 해볼 것

- 반복 일정
