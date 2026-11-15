"""GPT-SoVITS 받아쓰기(ASR) 대체: 한국어 전용, ctranslate2 없이 Whisper(PyTorch)로.

GPT-SoVITS 의 Faster Whisper 가 'ctranslate2.dll' 오류로 안 될 때 쓴다.
결과는 GPT-SoVITS 와 같은 형식(output/asr_opt/slicer_opt.list)이라 바로 교정·학습으로 넘어가면 된다.

GPT-SoVITS 폴더에서:
  runtime\\python.exe -m pip install --no-deps openai-whisper
  runtime\\python.exe -m pip install tiktoken more-itertools
  runtime\\python.exe asr_korean.py output\\slicer_opt output\\asr_opt
"""

import os
import sys


def main():
    inp = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "output/slicer_opt")
    out = sys.argv[2] if len(sys.argv) > 2 else "output/asr_opt"
    model_name = sys.argv[3] if len(sys.argv) > 3 else "turbo"  # large-v3-turbo

    import librosa  # GPT-SoVITS 에 이미 있음 (ffmpeg 없이 wav 읽기)
    import torch
    import whisper

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"[asr] Whisper {model_name} 불러오는 중 ({device}) — 처음엔 모델을 내려받아요")
    model = whisper.load_model(model_name, device=device)

    files = sorted(f for f in os.listdir(inp) if f.lower().endswith((".wav", ".mp3", ".flac")))
    folder = os.path.basename(inp)
    lines = []
    for i, name in enumerate(files, 1):
        path = os.path.join(inp, name)
        audio = librosa.load(path, sr=16000)[0]
        text = model.transcribe(audio, language="ko", fp16=(device == "cuda"))["text"].strip()
        print(f"[asr] {i}/{len(files)} {name}: {text}")
        if text:
            lines.append(f"{path}|{folder}|KO|{text}")

    os.makedirs(out, exist_ok=True)
    list_path = os.path.abspath(os.path.join(out, f"{folder}.list"))
    with open(list_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"[asr] 완료: {len(lines)}개 → {list_path}")


if __name__ == "__main__":
    main()
