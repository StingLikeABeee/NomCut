# NomCut one-click installer for Windows (PowerShell 5.1+, no admin needed).
# What it does: checks your PC, installs what is missing (Python, FFmpeg), downloads NomCut, builds a private
# Python environment, makes a desktop shortcut, starts the app and opens it in your browser.
# Everything lands in one folder (default: %LOCALAPPDATA%\NomCut). Delete that folder to uninstall.
# Plain text on purpose: you can read every line before you run it.
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'NomCut'),
    [string]$ZipUrl = 'https://github.com/StingLikeABeee/NomCut/archive/refs/heads/main.zip',
    [string]$SourceDir = '',          # developers: copy the app from a local folder instead of downloading
    [switch]$NoStart,                 # install only, do not start the app
    [switch]$Yes,                     # answer "yes" to the optional questions (GPU libraries, Ollama)
    [switch]$SkipOptional,            # answer "no" to the optional questions
    [switch]$NoShortcut               # do not create the Desktop shortcut (testing)
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'      # much faster downloads in Windows PowerShell
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Say($m)  { Write-Host "  $m" }
function Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  OK  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  !!  $m" -ForegroundColor Yellow }
function Ask($q) {
    if ($Yes) { return $true }
    if ($SkipOptional) { return $false }
    $a = Read-Host "  $q (y/n)"
    return ($a -match '^(y|Y|h|H)')
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Real-Python {
    # a working python 3.10+ that is NOT the Microsoft Store stub
    $cands = @()
    foreach ($n in @('python', 'python3')) {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        if ($c -and $c.Source -notmatch 'WindowsApps') { $cands += $c.Source }
    }
    $cands += @(Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object FullName)
    $cands += @(Get-ChildItem "$env:ProgramFiles\Python3*\python.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object FullName)
    foreach ($p in $cands) {
        try {
            $v = & $p -c "import sys;print('%d.%d' % sys.version_info[:2])" 2>$null
            if ($LASTEXITCODE -eq 0 -and [version]$v -ge [version]'3.10') { return $p }
        } catch {}
    }
    return $null
}
function Download($url, $out) {
    Say "downloading $([IO.Path]::GetFileName($out)) ..."
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$log = Join-Path $InstallDir 'install.log'
try { Start-Transcript -Path $log -Append | Out-Null } catch {}

Write-Host ""
Write-Host "  NOMCUT STUDIO SETUP" -ForegroundColor Green
Write-Host "  Drop a link, get captioned 9:16 shorts in minutes. Free, local, open-source. By Nouman Arif"
Write-Host "  Install folder: $InstallDir"

try {
    # ---- 0. check the PC
    Step "Step 1/6 - Checking your system"
    if (-not [Environment]::Is64BitOperatingSystem) { throw "NomCut requires 64-bit Windows." }
    $drive = (Get-Item $InstallDir).PSDrive
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    Say ("Windows: " + [Environment]::OSVersion.VersionString + " | free disk on " + $drive.Name + ": " + $freeGB + " GB")
    if ($freeGB -lt 6) { throw "At least 6 GB free disk space is required (currently $freeGB GB). Free up space and run again." }
    $hasGpu = $false
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        $g = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
        if ($LASTEXITCODE -eq 0 -and $g) { $hasGpu = $true; Say "NVIDIA GPU: $g" }
    }
    if (-not $hasGpu) { Say "No NVIDIA GPU detected: NomCut will run on CPU (slightly slower, still works)." }

    # ---- 1. python
    Step "Step 2/6 - Python runtime"
    $py = Real-Python
    if ($py) { Ok "Python found: $py" }
    else {
        Say "Python not found, installing Python 3.12 (~3 minutes)..."
        $done = $false
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                & winget install -e --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements | Out-Null
                Refresh-Path; $py = Real-Python; if ($py) { $done = $true }
            } catch {}
        }
        if (-not $done) {
            $installer = Join-Path $env:TEMP 'python-3.12-installer.exe'
            Download 'https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe' $installer
            Start-Process -FilePath $installer -ArgumentList '/quiet', 'InstallAllUsers=0', 'PrependPath=1', 'Include_test=0', 'Include_launcher=0' -Wait
            Refresh-Path; $py = Real-Python
        }
        if (-not $py) { throw "Python installation failed. Please install Python 3.12 from python.org and re-run this installer." }
        Ok "Python installed: $py"
    }

    # ---- 2. ffmpeg (portable copy inside the install folder, no PATH changes)
    Step "Step 3/6 - FFmpeg video engine"
    $ffbin = ''
    $ffOnPath = (Get-Command ffmpeg -ErrorAction SilentlyContinue) -and (Get-Command ffprobe -ErrorAction SilentlyContinue)
    $ownFf = Join-Path $InstallDir 'ffmpeg\bin'
    if (Test-Path (Join-Path $ownFf 'ffmpeg.exe')) { $ffbin = $ownFf; Ok "FFmpeg already present in install folder." }
    elseif ($ffOnPath) { Ok "FFmpeg already installed on system PATH." }
    else {
        $zip = Join-Path $env:TEMP 'ffmpeg-essentials.zip'
        Download 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' $zip
        $tmp = Join-Path $env:TEMP 'ffmpeg-unpack'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $root = Get-ChildItem $tmp -Directory | Select-Object -First 1
        New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'ffmpeg') | Out-Null
        Copy-Item (Join-Path $root.FullName 'bin') (Join-Path $InstallDir 'ffmpeg') -Recurse -Force
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
        $ffbin = $ownFf; Ok "FFmpeg installed."
    }

    # ---- 3. the app
    Step "Step 4/6 - Fetching NomCut Studio"
    $app = Join-Path $InstallDir 'app'
    New-Item -ItemType Directory -Force -Path $app | Out-Null
    if ($SourceDir) {
        Get-ChildItem $SourceDir -Force | Where-Object { $_.Name -notin @('.venv', 'data', '__pycache__', '.git') } | ForEach-Object { Copy-Item $_.FullName $app -Recurse -Force }
    } else {
        $zip = Join-Path $env:TEMP 'nomcut-main.zip'
        Download $ZipUrl $zip
        $tmp = Join-Path $env:TEMP 'nomcut-unpack'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $root = Get-ChildItem $tmp -Directory | Select-Object -First 1
        Get-ChildItem $root.FullName -Force | ForEach-Object { Copy-Item $_.FullName $app -Recurse -Force }
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path (Join-Path $app 'app.py'))) { throw "Application files missing (app.py not found). Check your internet connection." }
    Ok "App files: $app"

    # ---- 4. private python environment
    Step "Step 5/6 - Installing dependencies (3-6 minutes)"
    $venvPy = Join-Path $app '.venv\Scripts\python.exe'
    if (-not (Test-Path $venvPy)) { & $py -m venv (Join-Path $app '.venv'); if ($LASTEXITCODE -ne 0) { throw "Could not create virtual environment." } }
    & $venvPy -m pip install --upgrade pip --quiet 2>$null
    & $venvPy -m pip install -r (Join-Path $app 'requirements.txt') --quiet
    if ($LASTEXITCODE -ne 0) { throw "Package installation failed. Check internet and re-run (this installer resumes safely)." }
    & $venvPy -c "import fastapi, uvicorn, yt_dlp, numpy, cv2, faster_whisper, PIL; print('imports ok')"
    if ($LASTEXITCODE -ne 0) { throw "Core packages failed verification." }
    Ok "Packages ready."

    # ---- optional extras
    Step "Optional acceleration & AI models"
    if ($hasGpu -and (Ask "Install NVIDIA CUDA libraries (~1.2 GB) for faster local speech transcription on uncaptioned videos?")) {
        & $venvPy -m pip install nvidia-cublas-cu12 "nvidia-cudnn-cu12==9.*" --quiet
        if ($LASTEXITCODE -eq 0) { Ok "GPU libraries installed." } else { Warn "GPU libraries could not be installed (CPU fallback will be used)." }
    }
    $hasOllama = [bool](Get-Command ollama -ErrorAction SilentlyContinue)
    $wantModel = $false
    if (-not $hasOllama) {
        if (Ask "Install Ollama + llama3.2:3b (~2.5 GB) for AI-generated titles, hooks, and smarter moment ranking?") {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                & winget install -e --id Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements | Out-Null
                Refresh-Path
            } else { Warn "winget not available: install Ollama from ollama.com, then run: ollama pull llama3.2:3b" }
            $hasOllama = [bool](Get-Command ollama -ErrorAction SilentlyContinue)
            $wantModel = $true
        } else { Say "Skipped Ollama: NomCut will still work using audio and motion activity scores." }
    } else {
        $have = (& ollama list 2>$null) -join "`n"
        if ($have -match 'llama3\.2:3b') { Ok "Ollama and llama3.2:3b model already installed." }
        elseif (Ask "Ollama detected. Download AI model llama3.2:3b (~2 GB)?") { $wantModel = $true }
    }
    if ($wantModel -and $hasOllama) {
        try { & ollama pull llama3.2:3b; Ok "AI model ready." } catch { Warn "Model download incomplete. You can run later: ollama pull llama3.2:3b" }
    }

    # ---- start script + desktop shortcut
    Step "Step 6/6 - Creating shortcuts & launching"
    $startBat = Join-Path $InstallDir 'Start-NomCut.bat'
    $pathLine = if ($ffbin) { "set `"PATH=$ffbin;%PATH%`"" } else { 'rem FFmpeg already on PATH' }
    $bat = @(
        '@echo off',
        'title NomCut Studio (close this window to stop the server)',
        'if not defined NOMCUT_PORT set NOMCUT_PORT=8770',
        $pathLine,
        'powershell -NoProfile -Command "try{Invoke-WebRequest -UseBasicParsing http://127.0.0.1:%NOMCUT_PORT%/healthz -TimeoutSec 2 | Out-Null; exit 0}catch{exit 1}"',
        'if %errorlevel%==0 (',
        '  start "" http://127.0.0.1:%NOMCUT_PORT%',
        '  exit /b 0',
        ')',
        "cd /d `"$app`"",
        'start "" /min powershell -NoProfile -WindowStyle Hidden -Command "for($i=0;$i -lt 90;$i++){try{Invoke-WebRequest -UseBasicParsing http://127.0.0.1:$env:NOMCUT_PORT/healthz -TimeoutSec 2 | Out-Null; Start-Process http://127.0.0.1:$env:NOMCUT_PORT; break}catch{Start-Sleep 1}}"',
        "`"$venvPy`" app.py"
    )
    Set-Content -Path $startBat -Value $bat -Encoding ASCII
    # same start script with the phone remote switched on (listens on the home network, PIN required; see README)
    $phoneBat = Join-Path $InstallDir 'Start-NomCut-Phone.bat'
    Set-Content -Path $phoneBat -Value (@($bat[0], $bat[1], 'set NOMCUT_LAN=1') + $bat[2..($bat.Count - 1)]) -Encoding ASCII
    if (-not $NoShortcut) { try {
        $desk = [Environment]::GetFolderPath('Desktop')
        $sh = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desk 'NomCut.lnk'))
        $sh.TargetPath = $startBat; $sh.WorkingDirectory = $InstallDir; $sh.Description = 'NomCut Studio - AI 9:16 vertical clip maker'; $sh.Save()
        $sh2 = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desk 'NomCut (phone access).lnk'))
        $sh2.TargetPath = $phoneBat; $sh2.WorkingDirectory = $InstallDir; $sh2.Description = 'NomCut Studio with phone remote (same Wi-Fi, PIN)'; $sh2.Save()
        Ok "Created 'NomCut' shortcut on your Desktop."
        Ok "Created 'NomCut (phone access)' shortcut on your Desktop for mobile live control."
    } catch { Warn "Could not create Desktop shortcut. Launch file: $startBat" } }

    Stop-Transcript | Out-Null
    Write-Host ""
    Write-Host "  SETUP COMPLETE" -ForegroundColor Green
    if ($NoShortcut) { Write-Host "  Next time: double-click $startBat to open NomCut in your browser (http://127.0.0.1:8770)." }
    else { Write-Host "  Next time: double-click 'NomCut' on your Desktop to open NomCut in your browser (http://127.0.0.1:8770)." }
    Write-Host "  Workflow: 1) paste a video link  2) click 'Auto-cut clips'  3) preview & click 'Download MP4'."
    Write-Host $(if ($NoShortcut) { "  Uninstall: delete the $InstallDir folder." } else { "  Uninstall: delete the $InstallDir folder and Desktop shortcuts." })
    if (-not $NoStart) {
        Say "Starting NomCut Studio..."
        $env:Path = $(if ($ffbin) { "$ffbin;" } else { '' }) + $env:Path
        Start-Process -FilePath $startBat -WindowStyle Minimized
        Write-Host "  Your browser will open in a few seconds. If not, visit: http://127.0.0.1:8770"
    }
} catch {
    try { Stop-Transcript | Out-Null } catch {}
    Write-Host ""
    Write-Host "  SETUP FAILED" -ForegroundColor Red
    Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Log file: $log"
    Write-Host "  Help: share this log with an AI coding assistant, or open an issue at: github.com/StingLikeABeee/NomCut"
    exit 1
}
