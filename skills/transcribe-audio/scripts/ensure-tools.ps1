. "$PSScriptRoot\lib.ps1"

if ($env:OS -ne 'Windows_NT') {
    Write-Host "NOT_WINDOWS: install ffmpeg with your package manager (brew install ffmpeg / apt install ffmpeg)."
    exit 2
}

function Resolve-Both {
    $ff = Find-Tool 'ffmpeg'
    $fp = Find-Tool 'ffprobe'
    if ($ff -and $fp) { return @($ff, $fp) }
    return $null
}

$found = Resolve-Both
if (-not $found) { Refresh-Path; $found = Resolve-Both }

# Attempt 1: winget (one try, 10 minute timeout)
if (-not $found) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing FFmpeg with winget (one attempt, 10 min timeout)..."
        try {
            $p = Start-Process winget -ArgumentList @(
                'install', '--id', 'Gyan.FFmpeg', '-e', '--silent',
                '--accept-source-agreements', '--accept-package-agreements'
            ) -PassThru -WindowStyle Hidden
            if (-not $p.WaitForExit(600000)) {
                try { $p.Kill() } catch {}
                Write-Host "winget timed out."
            }
        } catch { Write-Host "winget failed: $($_.Exception.Message)" }
        Refresh-Path
        $found = Resolve-Both
    } else {
        Write-Host "winget not available."
    }
}

# Attempt 2: portable download
if (-not $found) {
    $dest = Join-Path $env:USERPROFILE 'ffmpeg-tools'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $urls = @(
        'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
        'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip'
    )
    foreach ($u in $urls) {
        try {
            $zip = Join-Path $env:TEMP 'ffmpeg-download.zip'
            Write-Host "Downloading $u"
            Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing
            Expand-Archive -Path $zip -DestinationPath $dest -Force
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
            $found = Resolve-Both
            if ($found) { break }
        } catch { Write-Host "Download failed: $($_.Exception.Message)" }
    }
}

if (-not $found) {
    Write-Host "ERROR: could not install ffmpeg automatically."
    Write-Host "Ask the user to run: winget install Gyan.FFmpeg   (or install from https://ffmpeg.org/download.html)"
    exit 1
}

$v = Run-Native $found[0] @('-version')
if ($v.Code -ne 0) { Write-Host "ERROR: ffmpeg found but will not run: $($found[0])"; exit 1 }
Write-Host "FFMPEG=$($found[0])"
Write-Host "FFPROBE=$($found[1])"
Write-Host ("VERSION=" + (($v.Out -split "`n")[0]).Trim())
exit 0
