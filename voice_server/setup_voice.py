"""학습이 끝난 뒤 '내 목소리' 서버 설정을 자동으로 채운다.

- 학습한 모델 파일(GPT_weights*/<이름>*.ckpt, SoVITS_weights*/<이름>*.pth) 중 가장 최근 것
- 교정한 받아쓰기(output/asr_opt/slicer_opt.list)에서 3~10초 조각을 골라 감정별 참고 녹음으로
  (음높이·크기로 보통/차분/기쁨/신남/아쉬움 후보를 나눔 — 들어보고 바꿔도 됨)
- voice_server/refs/*.wav 와 voice.json 작성

GPT-SoVITS 폴더에서:
  runtime\\python.exe setup_voice.py [모델이름=her] [voice_server 폴더=C:\\MyPlannerVoice\\voice_server] [받아쓰기 파일=output\\asr_opt\\slicer_opt.list]
"""

import glob
import json
import os
import shutil
import sys


def newest(pattern_list):
    files = [f for p in pattern_list for f in glob.glob(p)]
    return max(files, key=os.path.getmtime) if files else None


def read_list(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("|")
            if len(parts) >= 4 and parts[3].strip():
                rows.append((parts[0], parts[3].strip()))
    return rows


def features(path):
    import librosa
    import numpy as np

    y, sr = librosa.load(path, sr=16000)
    dur = len(y) / sr
    f0 = librosa.yin(y, fmin=70, fmax=600, sr=sr, frame_length=1024)
    rms = librosa.feature.rms(y=y)[0]
    loud = rms > (rms.max() * 0.1)
    n = min(len(f0), len(loud))
    voiced = f0[:n][loud[:n]]
    pitch = float(np.median(voiced)) if len(voiced) else 0.0
    energy = float(20 * np.log10(np.mean(rms[loud]) + 1e-9)) if loud.any() else -99.0
    return dur, pitch, energy


def pick_emotions(clips):
    """clips: [(path, text, dur, pitch, energy)] → {emotion: clip}"""
    import numpy as np

    if not clips:
        return {}
    pitches = np.array([c[3] for c in clips])
    energies = np.array([c[4] for c in clips])
    med_p, med_e = float(np.median(pitches)), float(np.median(energies))
    sp = float(pitches.std() or 1.0)
    se = float(energies.std() or 1.0)
    z = {c[0]: ((c[3] - med_p) / sp, (c[4] - med_e) / se) for c in clips}
    used, out = set(), {}

    def take(name, score):
        cands = [c for c in clips if c[0] not in used]
        if not cands:
            return
        best = min(cands, key=score)
        used.add(best[0])
        out[name] = best

    # 보통: 음높이·크기가 가장 평균에 가깝고, 길이가 넉넉한 것
    take("neutral", lambda c: abs(z[c[0]][0]) + abs(z[c[0]][1]) - min(c[2], 8) * 0.05)
    take("excited", lambda c: -(z[c[0]][0] + z[c[0]][1]))  # 높고 큼
    take("happy", lambda c: -z[c[0]][0] + abs(z[c[0]][1]) * 0.3)  # 높음
    take("calm", lambda c: z[c[0]][0] + z[c[0]][1])  # 낮고 작음
    take("sad", lambda c: z[c[0]][1] * 1.5 + abs(z[c[0]][0]) * 0.3)  # 작음
    return out


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "her"
    vs = sys.argv[2] if len(sys.argv) > 2 else r"C:\MyPlannerVoice\voice_server"
    gsv = os.getcwd()

    gpt = newest([os.path.join(gsv, "GPT_weights*", f"{name}*.ckpt")])
    sovits = newest([os.path.join(gsv, "SoVITS_weights*", f"{name}*.pth")])
    print(f"[1/3] 학습한 모델\n      GPT    : {gpt}\n      SoVITS : {sovits}")
    if not gpt or not sovits:
        raise SystemExit(f"'{name}' 이름의 학습 결과를 못 찾았어요. 1B 미세 조정 훈련(SoVITS·GPT)이 끝났는지 확인해 주세요.")

    lst = sys.argv[3] if len(sys.argv) > 3 else os.path.join(gsv, "output", "asr_opt", "slicer_opt.list")
    if not os.path.isabs(lst):
        lst = os.path.join(gsv, lst)
    rows = read_list(lst)
    print(f"[2/3] 참고 녹음 고르기 (받아쓰기 {len(rows)}개 중 3~10초)")
    clips = []
    for path, text in rows:
        if not os.path.isabs(path):
            path = os.path.join(gsv, path)
        if not os.path.exists(path) or len(text) < 4:
            continue
        dur, pitch, energy = features(path)
        if 3.0 <= dur <= 9.8 and pitch > 0:
            clips.append((path, text, dur, pitch, energy))
    chosen = pick_emotions(clips)
    if "neutral" not in chosen:
        raise SystemExit("3~10초짜리 조각이 없어요. 학습 화면 0b 음성 분할에서 min_length 를 늘려 다시 자르거나, 직접 골라 주세요.")

    refs = os.path.join(vs, "refs")
    os.makedirs(refs, exist_ok=True)
    labels = {"neutral": "보통", "happy": "기쁨", "calm": "차분", "sad": "아쉬움", "excited": "신남"}
    emotions = {}
    for emo, (path, text, dur, pitch, energy) in chosen.items():
        dst = os.path.join(refs, f"{emo}.wav")
        shutil.copyfile(path, dst)
        emotions[emo] = {"audio": f"refs/{emo}.wav", "text": text}
        print(f"      {labels[emo]:4s} {dur:4.1f}초 {pitch:5.0f}Hz  \"{text}\"")

    cfg_path = os.path.join(vs, "voice.json")
    cfg = {}
    if os.path.exists(cfg_path):
        with open(cfg_path, encoding="utf-8") as f:
            cfg = json.load(f)
    cfg.update({"engine": "gptsovits", "port": cfg.get("port", 9800), "format": cfg.get("format", "mp3"),
                "language": "ko", "emotions": emotions})
    g = cfg.get("gptsovits") or {}
    g.update({"url": g.get("url", "http://127.0.0.1:9880"), "gpt_weights": gpt, "sovits_weights": sovits,
              "speed": g.get("speed", 1.0)})
    cfg["gptsovits"] = g
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    with open(os.path.join(vs, "gptsovits_path.txt"), "w", encoding="ascii") as f:
        f.write(gsv)
    print(f"[3/3] 저장: {cfg_path}")
    print("완료! 바탕화면 '내 목소리 서버'를 실행하고, 마이플래너 설정 → 내 목소리 → 켜기 → 샘플 듣기")


if __name__ == "__main__":
    main()
