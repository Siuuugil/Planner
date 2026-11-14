# 내 목소리 서버 (voice_server)

마이플래너 AI 비서의 답을 **내 목소리**로 읽어주는 PC용 서버입니다.

```
폰/웹/PC 에서 질문 ─▶ PC 앱 (Claude가 답 + 감정 선택: 기쁨·차분·아쉬움·신남·보통)
                         │
                         ▼
               voice_server (이 폴더, 127.0.0.1:9800)
                 ├─ GPT-SoVITS  : 내 녹음으로 '학습'한 모델
                 └─ Qwen3-TTS   : 짧은 녹음으로 바로 복제
                         │  mp3
                         ▼
               Supabase Storage (내 계정 폴더) ─▶ 폰·웹·PC 에서 재생
```

- 서버는 이 PC 안(127.0.0.1)에서만 열립니다. 밖에서는 접속할 수 없어요.
- 음성 파일은 내 계정 폴더에만 올라가고, 대화를 지우면 같이 지워집니다.
- 서버가 꺼져 있으면 앱은 원래처럼 기본 음성으로 읽어요.

> 본인 목소리만 쓰세요. 다른 사람 목소리는 본인 동의 없이 복제하면 안 됩니다.

---

## 1. 녹음하기 (두 엔진 공통, 가장 중요)

품질의 80%는 녹음에서 결정됩니다.

**공통 요령**
- 조용한 방, 마이크와 입 사이 한 뼘. 에어컨·키보드 소리 X
- WAV(44.1k 또는 48kHz)로 저장. 폰 녹음도 되지만 PC 마이크/헤드셋 마이크가 더 좋아요
- 숨소리는 지우지 마세요. 학습 녹음에 자연스러운 숨이 있으면 결과에도 숨이 들어갑니다

**① 감정별 참고 녹음 (필수, 5개)** → `voice_server/refs/`

| 파일 | 감정 | 예시 대본 (그 감정으로 실제로 말하기) |
|---|---|---|
| `neutral.wav` | 보통 | 오늘 일정은 오후 세 시 회의 하나 있어요. |
| `happy.wav` | 기쁨 | 와, 이번 주 보스 다 잡았네요! 진짜 잘했어요. |
| `calm.wav` | 차분 | 괜찮아요, 천천히 하나씩 하면 돼요. |
| `sad.wav` | 아쉬움 | 아, 마감이 내일인데 아직 못 끝냈네요. |
| `excited.wav` | 신남 | 좋아요! 지금 바로 시작해 볼까요? |

- 길이 **3~10초** (GPT-SoVITS는 3~10초만 받음)
- 대본을 `voice.json`에 **글자 그대로** 적어야 합니다 (틀리면 발음이 꼬여요)
- AI는 답마다 이 중 하나를 고르고, 서버는 그 녹음의 말투·높낮이·속도를 따라 합니다
- 없는 감정은 `neutral`로 읽어요 (neutral만 있어도 동작)

**② 학습용 녹음 (GPT-SoVITS만, 5~10분 권장)**
- 1분만 있어도 학습은 되지만 5~10분이면 훨씬 자연스럽습니다
- 책·기사·평소 말투 대사를 다양한 감정으로 섞어서. 한 파일로 길게 녹음해도 WebUI가 잘라줍니다

---

## 2-A. GPT-SoVITS (학습형, 닮은 정도 최고)

RTX 3080 12GB 기준으로 학습 10~20분, 문장당 생성 1~3초 정도입니다.

### 설치
1. [GPT-SoVITS 릴리스](https://github.com/RVC-Boss/GPT-SoVITS/releases)에서 **Windows 통합 패키지**(7z) 받아 압축 풀기
   (경로에 한글·공백 없는 곳, 예: `C:\GPT-SoVITS`)
2. `go-webui.bat` 실행 → 브라우저에 WebUI가 열림
3. 모델 버전은 **v2Pro**(또는 v2 이상)를 고르세요. v2 부터 한국어를 지원합니다

### 학습 (WebUI 순서대로)
1. **0-전처리**
   - (잡음이 있으면) UVR5로 목소리만 분리
   - 음성 자르기: 학습용 녹음 폴더 지정 → 자르기
   - 음성 인식(ASR): **Faster Whisper**, 언어 **ko** → 자른 조각마다 글이 자동으로 붙음
   - 라벨 교정: 틀린 글자 고치기 (꼭! 정확할수록 발음이 좋아짐)
2. **1-학습**
   - 실험 이름: 예) `내목소리`
   - 1A 학습 데이터 포맷 → 한 번에 실행
   - 1B 미세조정: **SoVITS** 학습 (epoch 8~10) → **GPT** 학습 (epoch 10~15)
3. **1C 추론**에서 방금 만든 모델 골라 몇 문장 들어보기. 마음에 드는 epoch 파일을 고르세요

학습이 끝나면 이런 파일이 생깁니다 (이름은 실험 이름·epoch 따라 다름):
```
C:\GPT-SoVITS\GPT_weights_v2Pro\내목소리-e15.ckpt
C:\GPT-SoVITS\SoVITS_weights_v2Pro\내목소리_e8_s200.pth
```

### API 켜기
```bat
cd C:\GPT-SoVITS
runtime\python.exe api_v2.py -a 127.0.0.1 -p 9880 -c GPT_SoVITS/configs/tts_infer.yaml
```
`voice.json`의 `gptsovits.gpt_weights` / `sovits_weights`에 위 파일 경로를 적으면, 서버가 켜질 때 내 모델로 바꿔 끼웁니다.

---

## 2-B. Qwen3-TTS (학습 없이 바로 복제)

녹음 몇 초로 바로 쓸 수 있고, 학습형보다는 닮은 정도가 조금 덜할 수 있어요. 1.7B 모델은 12GB VRAM에 들어갑니다.

```bat
cd voice_server
py -3.12 -m venv venv
venv\Scripts\activate
pip install torch --index-url https://download.pytorch.org/whl/cu128
pip install -U qwen-tts lameenc
```
- 처음 실행할 때 모델(`Qwen/Qwen3-TTS-12Hz-1.7B-Base`, 수 GB)을 자동으로 받습니다
- 감정은 GPT-SoVITS와 똑같이 **감정별 참고 녹음**으로 표현해요 (복제 모델은 말로 하는 감정 지시를 받지 않음)
- VRAM이 부족하면 `voice.json`의 모델을 `Qwen/Qwen3-TTS-12Hz-0.6B-Base`로

---

## 3. 서버 설정 · 실행

1. `voice.example.json`을 복사해 `voice.json`으로 이름 바꾸기
2. `engine`을 `"gptsovits"` 또는 `"qwen"`으로
3. `emotions`의 대본을 내 녹음과 똑같이, 파일 경로 확인
4. (선택) mp3로 보내기: `pip install lameenc` (없으면 wav. mp3가 10배쯤 작아요)
5. `start_voice_server.bat` 더블클릭
   - GPT-SoVITS 엔진이면 위의 `api_v2.py`를 먼저 켜 두기
   - GPT-SoVITS 쪽 파이썬으로 돌려도 됩니다: `C:\GPT-SoVITS\runtime\python.exe server.py voice.json`
6. 확인: 브라우저에서 http://127.0.0.1:9800/health

**두 엔진 비교:** `voice.json`의 `engine`만 바꾸고 서버를 다시 켜면 됩니다. 앱 설정에서 같은 문장으로 샘플을 들어보고 정하세요.

---

## 4. 앱에서 켜기 (PC 앱)

설정 → **내 목소리 (음성 복제)**
1. "AI 답을 내 목소리로" 켜기
2. 연결 확인 → `gptsovits 엔진 · 감정: ...` 이 나오면 OK
3. 감정 고르고 **샘플 듣기**

이제 대화의 답이 내 목소리로 나옵니다 (말풍선 옆 🗣 아이콘). 폰에서 보낸 질문도 PC가 내 목소리 음성을 붙여서 돌려줘요.
- PC 앱이 같은 계정으로 로그인돼 있어야 폰에서도 들립니다
- 답이 오기까지: Claude 답 + 음성 생성(몇 초)

## 5. 품질 올리는 팁

- 발음이 뭉개짐 → 참고 녹음 대본 오타 확인, 학습 라벨 교정 다시
- 기계 같음 → 학습 녹음을 늘리기(10분+), 감정 섞어서
- 감정이 약함 → 참고 녹음을 더 과장해서 다시 녹음 (참고 녹음의 감정을 그대로 따라 함)
- 숨소리 → 학습·참고 녹음에 자연스러운 들숨을 남기기
- 속도 → `gptsovits.speed` (1.0 = 보통, 1.1 = 조금 빠르게)

## 테스트

```bash
python -m unittest test_server.py   # 가짜 엔진으로 서버·GPT-SoVITS 연동 확인
```
