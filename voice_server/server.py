"""마이플래너 '내 목소리' 서버 (PC 전용, 127.0.0.1 에서만 열림)

앱이 보내는 글을 내 목소리로 읽어 오디오로 돌려준다.
  GET  /health  -> {"ok": true, "engine": "...", "emotions": [...], "format": "mp3"}
  POST /speak   {"text": "...", "emotion": "happy"} -> audio/mpeg 또는 audio/wav

엔진 (voice.json 의 "engine"):
  gptsovits : 따로 켜 둔 GPT-SoVITS api_v2 서버(기본 9880)에 내 학습 모델로 요청
  qwen      : Qwen3-TTS Base 모델을 이 프로세스에 올려서 참고 녹음으로 목소리 복제

감정은 두 엔진 모두 '감정별 참고 녹음'(내 목소리로 그 감정으로 말한 3~10초)을 바꿔 끼워서 표현한다.
실행: python server.py [voice.json 경로]
"""

from __future__ import annotations

import io
import json
import re
import sys
import threading
import urllib.parse
import urllib.request
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

EMOTIONS = ["neutral", "happy", "calm", "sad", "excited"]
HERE = Path(__file__).resolve().parent


# ---------- 설정 ----------

def load_config(path: Path) -> dict:
    cfg = json.loads(path.read_text(encoding="utf-8"))
    cfg.setdefault("port", 9800)
    cfg.setdefault("format", "mp3")
    base = path.parent
    emotions = {}
    for name, ref in (cfg.get("emotions") or {}).items():
        audio = Path(ref["audio"])
        if not audio.is_absolute():
            audio = (base / audio).resolve()
        emotions[name] = {"audio": str(audio), "text": ref.get("text", "")}
    if "neutral" not in emotions:
        raise SystemExit("voice.json 의 emotions 에 'neutral'(기본) 참고 녹음이 꼭 있어야 해요.")
    cfg["emotions"] = emotions
    return cfg


def clean_text(text: str) -> str:
    """이모지·마크다운 기호를 빼고 읽기 좋게"""
    text = re.sub(r"[\U0001F300-\U0001FAFF☀-➿]", "", text)
    text = re.sub(r"[*#`>·→]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


# ---------- 오디오 변환 ----------

def wav_to_pcm(data: bytes) -> tuple[bytes, int, int]:
    with wave.open(io.BytesIO(data)) as w:
        if w.getsampwidth() != 2:
            raise ValueError("16bit wav 만 지원해요")
        return w.readframes(w.getnframes()), w.getframerate(), w.getnchannels()


def pcm_to_wav(pcm: bytes, rate: int, channels: int = 1) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)
    return buf.getvalue()


def encode(pcm: bytes, rate: int, channels: int, fmt: str) -> tuple[bytes, str]:
    """mp3 (lameenc 가 있으면) 아니면 wav. mp3 가 10배쯤 작아서 폰으로 보내기 좋다."""
    if fmt == "mp3":
        try:
            import lameenc  # pip install lameenc

            enc = lameenc.Encoder()
            enc.set_bit_rate(64)
            enc.set_in_sample_rate(rate)
            enc.set_channels(channels)
            enc.set_quality(2)
            return enc.encode(pcm) + enc.flush(), "audio/mpeg"
        except ImportError:
            pass
    return pcm_to_wav(pcm, rate, channels), "audio/wav"


# ---------- 엔진 ----------

class GptSovitsEngine:
    name = "gptsovits"

    def __init__(self, cfg: dict):
        g = cfg.get("gptsovits") or {}
        self.url = g.get("url", "http://127.0.0.1:9880").rstrip("/")
        self.lang = cfg.get("language", "ko")
        self.speed = float(g.get("speed", 1.0))
        self.emotions = cfg["emotions"]
        # 내가 학습한 모델로 바꿔 둔다 (비워 두면 GPT-SoVITS 쪽 설정 그대로)
        for key, endpoint in (("gpt_weights", "set_gpt_weights"), ("sovits_weights", "set_sovits_weights")):
            if g.get(key):
                q = urllib.parse.urlencode({"weights_path": g[key]})
                with urllib.request.urlopen(f"{self.url}/{endpoint}?{q}", timeout=300) as r:
                    r.read()

    def synth(self, text: str, emotion: str) -> tuple[bytes, int, int]:
        ref = self.emotions.get(emotion) or self.emotions["neutral"]
        body = json.dumps({
            "text": text,
            "text_lang": self.lang,
            "ref_audio_path": ref["audio"],
            "prompt_text": ref["text"],
            "prompt_lang": self.lang,
            "text_split_method": "cut5",
            "batch_size": 1,
            "media_type": "wav",
            "streaming_mode": False,
            "speed_factor": self.speed,
        }).encode()
        req = urllib.request.Request(f"{self.url}/tts", data=body, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=180) as r:
            return wav_to_pcm(r.read())


class QwenEngine:
    name = "qwen"

    def __init__(self, cfg: dict):
        import numpy as np  # noqa: F401  (qwen-tts 와 함께 설치됨)
        import torch
        from qwen_tts import Qwen3TTSModel

        q = cfg.get("qwen") or {}
        self.lang = q.get("language", "Korean")
        self.model = Qwen3TTSModel.from_pretrained(
            q.get("model", "Qwen/Qwen3-TTS-12Hz-1.7B-Base"),
            device_map=q.get("device", "cuda:0"),
            dtype=torch.bfloat16,
        )
        # 감정별 참고 녹음은 미리 한 번만 계산해 둔다
        self.prompts = {
            name: self.model.create_voice_clone_prompt(ref_audio=ref["audio"], ref_text=ref["text"])
            for name, ref in cfg["emotions"].items()
        }
        self.lock = threading.Lock()

    def synth(self, text: str, emotion: str) -> tuple[bytes, int, int]:
        import numpy as np

        prompt = self.prompts.get(emotion) or self.prompts["neutral"]
        with self.lock:  # GPU 하나라 한 번에 하나씩
            wavs, sr = self.model.generate_voice_clone(text=text, language=self.lang, voice_clone_prompt=prompt)
        pcm = (np.clip(wavs[0], -1, 1) * 32767).astype("<i2").tobytes()
        return pcm, sr, 1


def make_engine(cfg: dict):
    engine = cfg.get("engine", "gptsovits")
    if engine == "gptsovits":
        return GptSovitsEngine(cfg)
    if engine == "qwen":
        return QwenEngine(cfg)
    raise SystemExit(f"모르는 엔진: {engine} (gptsovits 또는 qwen)")


# ---------- HTTP ----------

def make_handler(engine, cfg: dict):
    class Handler(BaseHTTPRequestHandler):
        def _json(self, code: int, obj: dict):
            data = json.dumps(obj, ensure_ascii=False).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path == "/health":
                self._json(200, {"ok": True, "engine": engine.name, "emotions": sorted(cfg["emotions"]),
                                 "format": cfg["format"]})
            else:
                self._json(404, {"error": "not found"})

        def do_POST(self):
            if self.path != "/speak":
                return self._json(404, {"error": "not found"})
            try:
                req = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
                text = clean_text(str(req.get("text", "")))[:1000]
                if not text:
                    return self._json(400, {"error": "text 가 비어 있어요"})
                emotion = str(req.get("emotion") or "neutral")
                pcm, rate, ch = engine.synth(text, emotion)
                audio, mime = encode(pcm, rate, ch, cfg["format"])
            except Exception as e:  # 앱에는 이유를 알려준다
                return self._json(500, {"error": f"{type(e).__name__}: {e}"})
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(len(audio)))
            self.end_headers()
            self.wfile.write(audio)

        def log_message(self, fmt, *args):
            sys.stderr.write("[voice] " + fmt % args + "\n")

    return Handler


def serve(engine, cfg: dict) -> ThreadingHTTPServer:
    return ThreadingHTTPServer(("127.0.0.1", int(cfg["port"])), make_handler(engine, cfg))


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "voice.json"
    if not path.exists():
        raise SystemExit(f"{path} 가 없어요. voice.example.json 을 복사해서 voice.json 으로 만들어 주세요.")
    cfg = load_config(path)
    print(f"[voice] {cfg['engine']} 엔진 준비 중… (처음엔 모델 로딩에 시간이 걸려요)")
    engine = make_engine(cfg)
    httpd = serve(engine, cfg)
    print(f"[voice] 준비 완료: http://127.0.0.1:{cfg['port']}  감정: {', '.join(sorted(cfg['emotions']))}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
