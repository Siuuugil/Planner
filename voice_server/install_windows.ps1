# 마이플래너 '내 목소리' 설치 (Windows, GPT-SoVITS)
# 사용법: PowerShell 에 아래 한 줄 붙여넣기
#   irm https://raw.githubusercontent.com/Siuuugil/Planner/HEAD/voice_server/install_windows.ps1 | iex
# 하는 일: 폴더 만들기 → 음성 서버 파일 받기 → GPT-SoVITS 통합 패키지(최신) 받기·압축 풀기
#         → 설정 파일·바로가기 만들기 → 학습 화면(WebUI) 열기

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$Root = 'C:\MyPlannerVoice'          # 한글·공백 없는 경로 (GPT-SoVITS 요구사항)
$Raw  = 'https://raw.githubusercontent.com/Siuuugil/Planner/HEAD/voice_server'
$Hf   = 'https://huggingface.co/lj1995/GPT-SoVITS-windows-package'

function Step($n, $msg) { Write-Host ""; Write-Host "[$n/7] $msg" -ForegroundColor Cyan }
function Info($msg) { Write-Host "      $msg" }
function Warn($msg) { Write-Host "      ! $msg" -ForegroundColor Yellow }

Write-Host "마이플래너 '내 목소리' 설치를 시작해요. 설치 위치: $Root" -ForegroundColor Green

# 1. 확인
Step 1 '컴퓨터 확인'
$gpu = $null
try { $gpu = (& nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null) } catch {}
if ($gpu) { Info "그래픽카드: $gpu" } else { Warn 'NVIDIA 그래픽카드를 못 찾았어요. 설치는 되지만 학습·생성이 매우 느릴 수 있어요.' }
$drive = Get-PSDrive -Name ($Root.Substring(0,1))
$freeGb = [math]::Round($drive.Free / 1GB)
Info "C 드라이브 여유 공간: ${freeGb}GB"
if ($freeGb -lt 30) { Warn '여유 공간이 30GB 보다 적어요. 패키지(압축 + 풀린 파일)에 20~30GB 쯤 필요해요.' }

# 2. 음성 서버 파일
Step 2 '음성 서버 파일 받기'
$vs = Join-Path $Root 'voice_server'
New-Item -ItemType Directory -Force -Path $vs, (Join-Path $vs 'refs') | Out-Null
foreach ($f in 'server.py', 'start_voice_server.bat', 'voice.example.json', 'README.md') {
  Invoke-WebRequest -UseBasicParsing -Uri "$Raw/$f" -OutFile (Join-Path $vs $f)
}
Info "완료: $vs"

function Find-Gsv { Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue |
  Where-Object { Test-Path (Join-Path $_.FullName 'go-webui.bat') } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
$existing = Find-Gsv
if ($existing) {
  Step 3 "GPT-SoVITS 가 이미 있어요 ($($existing.FullName)) → 받기·압축 풀기는 건너뛰어요"
  $gsv = $existing.FullName
} else {
# 3. 최신 통합 패키지 찾기
Step 3 'GPT-SoVITS 최신 통합 패키지 찾기'
$pkg = $null
try {
  $files = Invoke-RestMethod -Uri 'https://huggingface.co/api/models/lj1995/GPT-SoVITS-windows-package/tree/main'
  # 이름 끝의 날짜(YYYYMMDD)가 가장 늦은 .7z
  $pkg = $files | Where-Object { $_.path -match '\.7z$' } |
    Sort-Object { if ($_.path -match '(\d{8})') { $matches[1] } else { '0' } } -Descending |
    Select-Object -First 1
} catch { Warn "목록을 못 읽었어요: $($_.Exception.Message)" }
if ($pkg) {
  $name = $pkg.path
  $sizeGb = [math]::Round($pkg.size / 1GB, 1)
} else {
  # 목록이 안 되면 공식 README 의 링크 사용
  $readme = (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/RVC-Boss/GPT-SoVITS/main/README.md').Content
  if ($readme -match 'GPT-SoVITS-windows-package/resolve/main/([^)?\s]+\.7z)') { $name = $matches[1]; $sizeGb = '?' }
  else { throw '패키지 주소를 찾지 못했어요. 인터넷 연결을 확인하거나 README 의 수동 설치를 따라 주세요.' }
}
Info "패키지: $name (${sizeGb}GB)"

# 4. 받기 (중간에 끊겨도 다시 실행하면 이어 받음)
Step 4 '패키지 받기 (용량이 커서 오래 걸려요. 창을 닫지 마세요)'
$archive = Join-Path $Root $name
$url = "$Hf/resolve/main/$name`?download=true"
& curl.exe -L --fail --retry 5 -C - -o $archive $url
if ($LASTEXITCODE -ne 0) { throw "다운로드 실패 (curl 코드 $LASTEXITCODE). 다시 실행하면 이어서 받아요." }
Info '다운로드 완료'

# 5. 압축 풀기 (7-Zip)
Step 5 '압축 풀기'
$sevenZip = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sevenZip -and (Get-Command winget -ErrorAction SilentlyContinue)) {
  Info '7-Zip 설치 중 (winget)…'
  & winget install --id 7zip.7zip -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
  $sevenZip = @("$env:ProgramFiles\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ($sevenZip) {
  & $sevenZip x $archive "-o$Root" -y | Out-Null
} else {
  Info '7-Zip 이 없어서 Windows 기본 tar 로 시도해요…'
  & tar.exe -xf $archive -C $Root
}
if ($LASTEXITCODE -ne 0) { throw '압축 풀기 실패. 7-Zip(https://www.7-zip.org)을 설치하고 다시 실행해 주세요.' }
$gsv = Find-Gsv
if (-not $gsv) { throw "압축은 풀렸는데 go-webui.bat 을 못 찾았어요 ($Root 확인)." }
$gsv = $gsv.FullName
Info "GPT-SoVITS 위치: $gsv"
$ans = Read-Host '      다 풀렸어요. 압축 파일을 지워 공간을 확보할까요? (Y/n)'
if ($ans -ne 'n') { Remove-Item $archive -Force; Info '압축 파일 삭제' }
}

# 6. 설정
Step 6 '설정 파일 만들기'
Set-Content -Path (Join-Path $vs 'gptsovits_path.txt') -Value $gsv -Encoding ASCII
$cfg = Join-Path $vs 'voice.json'
if (-not (Test-Path $cfg)) { Copy-Item (Join-Path $vs 'voice.example.json') $cfg; Info 'voice.json 생성 (녹음 후 대본·모델 경로를 고쳐 주세요)' }
$py = Join-Path $gsv 'runtime\python.exe'
if (Test-Path $py) {
  try { & $py -m pip install -q lameenc 2>$null | Out-Null; Info 'mp3 변환(lameenc) 설치' } catch { Warn 'lameenc 설치 실패 (wav 로 보내요, 동작엔 문제 없음)' }
}

# 기본 go-webui.bat 은 중국어(zh_CN)로 켜져서 한국어판 실행 파일을 따로 만든다
$webuiKo = Join-Path $gsv 'go-webui-ko.bat'
$orig = Get-Content (Join-Path $gsv 'go-webui.bat') -Raw
Set-Content -Path $webuiKo -Value ($orig -replace 'webui\.py\s+\w+', 'webui.py ko_KR') -Encoding ASCII
Info '한국어 학습 화면 실행 파일: go-webui-ko.bat'

# 7. 바로가기
Step 7 '바탕화면 바로가기'
$desk = [Environment]::GetFolderPath('Desktop')
$sh = New-Object -ComObject WScript.Shell
foreach ($s in @(
  @{ Name = 'GPT-SoVITS 학습'; Target = $webuiKo; Dir = $gsv },
  @{ Name = '내 목소리 서버'; Target = (Join-Path $vs 'start_voice_server.bat'); Dir = $vs },
  @{ Name = '내 목소리 녹음 폴더'; Target = (Join-Path $vs 'refs'); Dir = $vs }
)) {
  $lnk = $sh.CreateShortcut((Join-Path $desk "$($s.Name).lnk"))
  $lnk.TargetPath = $s.Target
  $lnk.WorkingDirectory = $s.Dir
  $lnk.Save()
}
Info "바탕화면: 'GPT-SoVITS 학습', '내 목소리 서버', '내 목소리 녹음 폴더'"

Write-Host ""
Write-Host '설치 완료!' -ForegroundColor Green
Write-Host '다음 순서:'
Write-Host "  1) 녹음: 감정별 3~10초 5개를 '내 목소리 녹음 폴더'에 (neutral/happy/calm/sad/excited.wav) + 학습용 5~10분"
Write-Host "  2) 'GPT-SoVITS 학습' 으로 학습 (README 2-A)"
Write-Host "  3) $cfg 에 대본·모델 경로 적기"
Write-Host "  4) '내 목소리 서버' 실행 → 마이플래너 설정 → 내 목소리 → 켜기"
$open = Read-Host '지금 학습 화면(WebUI)을 열까요? (Y/n)'
if ($open -ne 'n') { Start-Process -FilePath $webuiKo -WorkingDirectory $gsv }
