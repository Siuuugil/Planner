"""가짜 엔진으로 서버 동작 확인: python -m unittest test_server.py"""
import json
import math
import struct
import threading
import unittest
import urllib.request

import server


class FakeEngine:
    name = "fake"

    def __init__(self):
        self.calls = []

    def synth(self, text, emotion):
        self.calls.append((text, emotion))
        pcm = b"".join(struct.pack("<h", int(8000 * math.sin(i / 10))) for i in range(1600))
        return pcm, 16000, 1


class ServerTest(unittest.TestCase):
    def setUp(self):
        self.engine = FakeEngine()
        cfg = {"port": 0, "format": "wav", "emotions": {"neutral": {}, "happy": {}}}
        self.httpd = server.serve(self.engine, cfg)
        self.base = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()

    def test_health(self):
        with urllib.request.urlopen(self.base + "/health") as r:
            body = json.loads(r.read())
        self.assertEqual(body["engine"], "fake")
        self.assertEqual(body["emotions"], ["happy", "neutral"])

    def test_speak_cleans_text_and_returns_wav(self):
        req = urllib.request.Request(self.base + "/speak", data=json.dumps(
            {"text": "✨ **좋아요** → 시작!", "emotion": "happy"}).encode())
        with urllib.request.urlopen(req) as r:
            self.assertEqual(r.headers["Content-Type"], "audio/wav")
            audio = r.read()
        self.assertTrue(audio.startswith(b"RIFF"))
        self.assertEqual(self.engine.calls, [("좋아요 시작!", "happy")])

    def test_empty_text_is_400(self):
        req = urllib.request.Request(self.base + "/speak", data=b'{"text":"  "}')
        with self.assertRaises(urllib.error.HTTPError) as cm:
            urllib.request.urlopen(req)
        self.assertEqual(cm.exception.code, 400)

    def test_mp3_falls_back_to_wav_without_lameenc(self):
        audio, mime = server.encode(b"\0\0" * 100, 16000, 1, "mp3")
        self.assertIn(mime, ("audio/mpeg", "audio/wav"))


class GptSovitsAdapterTest(unittest.TestCase):
    """GPT-SoVITS api_v2 흉내: 무게 교체 + /tts 요청 내용 확인"""

    def test_request_shape(self):
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

        seen = {}

        class Fake(BaseHTTPRequestHandler):
            def do_GET(self):
                seen.setdefault("get", []).append(self.path)
                self.send_response(200); self.end_headers(); self.wfile.write(b"ok")

            def do_POST(self):
                seen["tts"] = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                wav = server.pcm_to_wav(b"\x01\x00" * 50, 32000)
                self.send_response(200); self.send_header("Content-Length", str(len(wav))); self.end_headers()
                self.wfile.write(wav)

            def log_message(self, *a):
                pass

        fake = ThreadingHTTPServer(("127.0.0.1", 0), Fake)
        threading.Thread(target=fake.serve_forever, daemon=True).start()
        try:
            cfg = {"language": "ko", "emotions": {
                "neutral": {"audio": "/r/n.wav", "text": "기본"}, "happy": {"audio": "/r/h.wav", "text": "기쁨"}},
                "gptsovits": {"url": f"http://127.0.0.1:{fake.server_address[1]}", "gpt_weights": "g.ckpt",
                              "sovits_weights": "s.pth"}}
            eng = server.GptSovitsEngine(cfg)
            pcm, rate, ch = eng.synth("안녕", "happy")
            self.assertEqual((len(pcm), rate, ch), (100, 32000, 1))
            self.assertEqual(seen["get"], ["/set_gpt_weights?weights_path=g.ckpt",
                                           "/set_sovits_weights?weights_path=s.pth"])
            t = seen["tts"]
            self.assertEqual((t["text"], t["text_lang"], t["ref_audio_path"], t["prompt_text"]),
                             ("안녕", "ko", "/r/h.wav", "기쁨"))
            eng.synth("모르는 감정", "angry")
            self.assertEqual(seen["tts"]["ref_audio_path"], "/r/n.wav")
        finally:
            fake.shutdown(); fake.server_close()


if __name__ == "__main__":
    unittest.main()
