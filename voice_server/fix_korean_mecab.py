"""GPT-SoVITS 한국어 학습 오류 고치기: "No module named 'eunjeon'"

한국어 발음 변환(g2pk2)은 Windows 에서 'eunjeon' 형태소 분석기를 찾는데,
eunjeon 은 Python 3.6 용 설치 파일만 있어서 새 Python 에선 Visual Studio 로 직접 빌드해야 한다.
대신 Windows 설치 파일이 있는 'python-mecab-ko' 를 설치하고, eunjeon 이름으로 연결해 준다.

GPT-SoVITS 폴더에서:  runtime\\python.exe fix_korean_mecab.py
"""

import importlib
import os
import subprocess
import sys
import sysconfig

SHIM = '''"""eunjeon 대체: python-mecab-ko 로 같은 기능 (마이플래너 fix_korean_mecab.py 가 만듦)"""
from mecab import MeCab as _MeCab


class Mecab:
    def __init__(self, dicpath=None, *args, **kwargs):
        self._m = _MeCab()

    def pos(self, phrase, *args, **kwargs):
        return [(str(s), str(t)) for s, t in self._m.pos(phrase)]

    def morphs(self, phrase, *args, **kwargs):
        return [s for s, _ in self.pos(phrase)]

    def nouns(self, phrase, *args, **kwargs):
        return [s for s, t in self.pos(phrase) if t.startswith("N")]
'''


def main():
    print("[1/3] python-mecab-ko 설치")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "python-mecab-ko"])
    importlib.invalidate_caches()

    print("[2/3] eunjeon 연결 파일 만들기")
    site = sysconfig.get_paths()["purelib"]
    target = os.path.join(site, "eunjeon")
    if os.path.exists(os.path.join(target, "__init__.py")) and "마이플래너" not in open(
        os.path.join(target, "__init__.py"), encoding="utf-8", errors="ignore"
    ).read():
        print("      진짜 eunjeon 이 이미 있어서 그대로 둬요")
    else:
        os.makedirs(target, exist_ok=True)
        with open(os.path.join(target, "__init__.py"), "w", encoding="utf-8") as f:
            f.write(SHIM)
        print(f"      {target}")

    print("[3/3] 확인")
    importlib.invalidate_caches()
    from eunjeon import Mecab

    print("     ", Mecab().pos("이번 주 보스를 다 잡았어요"))
    print("완료! 학습 화면에서 '훈련 데이터셋 포맷팅 원클릭 실행'을 다시 누르세요.")


if __name__ == "__main__":
    main()
