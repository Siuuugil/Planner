@echo off
chcp 65001 >nul
cd /d %~dp0
if not exist voice.json (
  echo voice.json 이 없어요. voice.example.json 을 복사해서 만들고 대본을 고쳐 주세요.
  pause
  exit /b 1
)

rem 설치 스크립트가 적어 둔 GPT-SoVITS 위치
set GSV=
if exist gptsovits_path.txt set /p GSV=<gptsovits_path.txt

findstr /c:"\"engine\": \"gptsovits\"" voice.json >nul
if %errorlevel%==0 if defined GSV (
  echo GPT-SoVITS API 를 새 창에서 켜요...
  start "GPT-SoVITS API" /d "%GSV%" "%GSV%\runtime\python.exe" api_v2.py -a 127.0.0.1 -p 9880 -c GPT_SoVITS/configs/tts_infer.yaml
)

if exist venv\Scripts\python.exe (
  venv\Scripts\python.exe server.py voice.json
) else if defined GSV (
  "%GSV%\runtime\python.exe" server.py voice.json
) else (
  python server.py voice.json
)
pause
