@echo off
chcp 65001 >nul
cd /d %~dp0
rem GPT-SoVITS 엔진이면 GPT-SoVITS 폴더에서 api_v2.py 를 먼저 켜 두세요 (README 참고)
if exist venv\Scripts\python.exe (
  venv\Scripts\python.exe server.py voice.json
) else (
  python server.py voice.json
)
pause
