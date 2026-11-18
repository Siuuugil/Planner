# 집 PC에서 할 일 (암호: "집 pc가 허브메모리백업")

사용자가 **"집 pc가 허브메모리백업"** 이라고 하면, 회사·클라우드에서 미뤄 둔 집 PC 작업과 테스트를 이 순서대로 같이 진행한다.
밖에서 기능을 더 만들면 아래 **3. 테스트 목록**에 한 줄씩 추가한다. 끝낸 항목은 `[x]`로 바꾸고, 다 끝나면 정리한다.

## 1. PC 마을(`llm-wiki`) 결재함 파일 올리기 — 집 PC에서만 가능

배경: `llm-wiki`의 `.gitignore`에 있던 `inbox/`(앞에 `/` 없음)가 루트 작업 문서 폴더뿐 아니라 `app/inbox/`(결재함 화면)까지 git에서 빼고 있었다.
그래서 결재함 화면은 집 PC에만 있고 GitHub에 올라간 적이 없다. 노트북 서버는 이 파일이 없어서 마을 지도 🔔 결재 → `/inbox`가 404.
`.gitignore`는 이미 `/inbox/`로 고쳐서 올라가 있다.

- [ ] 집 PC `llm-wiki` 폴더에서 `git pull` (고친 `.gitignore` 받기)
- [ ] `git status --short`로 새로 보이는 inbox 관련 파일 확인 — `app/inbox/` 말고도 `app/api/inbox/`, `lib/inbox/` 등 같은 이유로 빠진 폴더가 있으면 같이
- [ ] 커밋 후 푸시
- [ ] 노트북 서버: `git pull` → `npm install` → `npm run build` → 서버 재시작
- [ ] 노트북에서 🔔 결재 → `/inbox`가 404 없이 열리는지

## 2. 밀린 수집 처리 확인

- 2026-11-18 15:08(한국) 회사 노트북 웹에서 넣은 수집 1건이 처리 안 된 채 남아 있음 (`kind='inbox'`, `source='planner'`, `deleted=false`).
- [ ] PC 마을을 최신으로 켠 뒤 이 건의 디스코드 DM이 오는지 (안 오면: PC 마을이 켤 때 밀린 `inbox` 행을 다시 훑는지 확인)

남은 수집 행 확인 (Supabase SQL, 읽기 전용):

```sql
select id, data->>'source' as source, left(data->>'text', 40) as text, deleted, updated_at
from public.items where kind = 'inbox' order by updated_at desc limit 10;
```

## 3. 테스트 목록 (밖에서 만든 기능)

### 📥 수집함 (빌드 #36)
- [ ] 폰: Releases에서 새 APK 설치, 설정 맨 아래 빌드 번호 ≥ 36
- [ ] 폰: 다른 앱에서 공유 → 마이플래너 → "📥 수집함에 넣었어요" → 디스코드 DM 도착
- [ ] 폰·웹·PC 앱: 홈 📥 아이콘(또는 + → 📥 수집)으로 입력 → DM 도착
- [ ] DM 버튼 "할 일로" → 마이플래너 할 일 목록에 생기는지 (PC 마을이 `task` 행을 만드는지)
- [ ] DM 버튼 "버리기"/"마을 서재로" → 해당 `inbox` 행이 `deleted=true`
