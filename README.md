# 게임 플래너 (game_planner)

내 일정과 게임 스펙업을 함께 관리하는 Flutter 앱. Android, Windows(PC), 웹에서 동작합니다.

## 기능

- **오늘**: 오늘 일정, 아직 안 한 게임 숙제, 진행 중인 스펙업 목표를 한 화면에
- **일정**: 월/2주/주 캘린더, 일정 추가·수정·완료 체크, 게임과 연결 가능
- **게임**
  - 게임별 **일일/주간 숙제**: 게임마다 초기화 시각(기본 오전 6시)과 주간 초기화 요일(기본 수요일)을 설정하면 시간이 지나면 자동으로 다시 미완료가 됨
  - **스펙업 목표**: 시작값 → 현재값 → 목표값, 진행률 바, 마감일 D-day
  - 게임에 연결된 다가오는 일정
- 데이터는 기기 안(SharedPreferences)에 저장 (기기 간 동기화는 아직 없음)

## 실행

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

## 구조

```
lib/
  main.dart                 앱 진입점, 테마, 한국어 로케일
  models/                   Schedule, Game, Goal, Chore (+ 초기화 계산)
  data/                     AppStore(상태 + 저장), StoreScope
  screens/                  오늘 / 일정 / 게임 / 게임 상세
  widgets/                  타일과 추가·수정 다이얼로그
test/                       초기화 계산·진행률·화면 테스트
```

## 다음에 해볼 것

- 기기 간 동기화 (폰 ↔ PC): Firebase 또는 Supabase
- 숙제·일정 알림 (로컬 푸시)
- 반복 일정
- 스펙업 기록 그래프
