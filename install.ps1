<#
Installs the transcribe-audio skill.
  Antigravity, all projects:  .\install.ps1
  Antigravity, one project:   .\install.ps1 -ProjectPath "D:\My Project"
  Claude Code, all projects:  .\install.ps1 -Agent Claude
  Both agents:                .\install.ps1 -Agent All
  Custom skills folder:       .\install.ps1 -TargetDir "C:\path\to\skills"
  Remove:                     add -Uninstall to any of the above
  Skip ffmpeg setup:          .\install.ps1 -SkipTools
#>
param(
    [ValidateSet('Antigravity', 'Claude', 'All')]
    [string]$Agent = 'Antigravity',
    [string]$ProjectPath,
    [string]$TargetDir,
    [switch]$Uninstall,
    [switch]$SkipTools,
    [string]$Repo = 'YOURNAME/transcribe-audio-skill',
    [string]$Branch = 'main'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$skillName = 'transcribe-audio'
$required = @('SKILL.md', 'scripts\lib.ps1', 'scripts\ensure-tools.ps1',
              'scripts\analyze-audio.ps1', 'scripts\split-audio.ps1', 'scripts\check-coverage.ps1')

if ($env:OS -ne 'Windows_NT') { Write-Host "This installer is for Windows."; exit 2 }

# 1. Where to install (one or more skills folders)
$dests = @()
if ($TargetDir) {
    $dests += $TargetDir
} else {
    if ($Agent -in @('Antigravity', 'All')) {
        if ($ProjectPath) { $dests += (Join-Path $ProjectPath '.agents\skills') }
        else              { $dests += (Join-Path $env:USERPROFILE '.gemini\config\skills') }
    }
    if ($Agent -in @('Claude', 'All')) {
        if ($ProjectPath) { $dests += (Join-Path $ProjectPath '.claude\skills') }
        else              { $dests += (Join-Path $env:USERPROFILE '.claude\skills') }
    }
}

if ($Uninstall) {
    foreach ($d in $dests) {
        $final = Join-Path $d $skillName
        if (Test-Path -LiteralPath $final) { Remove-Item -LiteralPath $final -Recurse -Force; Write-Host "Removed $final" }
        else { Write-Host "Not installed at $final" }
    }
    exit 0
}

# 2. Find the skill files (next to this script, or download from GitHub)
$src = $null; $tmp = $null
if ($PSScriptRoot) {
    foreach ($cand in @((Join-Path $PSScriptRoot "skills\$skillName"), (Join-Path $PSScriptRoot $skillName))) {
        if (Test-Path -LiteralPath (Join-Path $cand 'SKILL.md')) { $src = $cand; break }
    }
}
if (-not $src) {
    if ($Repo -like 'YOURNAME/*') {
        Write-Host "ERROR: skill files not found next to install.ps1. Extract the whole zip first, then run install.ps1 from inside it."
        exit 1
    }
    $tmp = Join-Path $env:TEMP ("transcribe-skill-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'repo.zip'
    $url = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"
    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $src = Get-ChildItem -Path $tmp -Directory -Recurse |
        Where-Object { $_.Name -eq $skillName -and (Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')) } |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $src) { Write-Host "ERROR: skill folder not found in the download."; exit 1 }
}

# 3. Copy (replaces an older version) and verify
$installed = @()
foreach ($d in $dests) {
    $final = Join-Path $d $skillName
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    if (Test-Path -LiteralPath $final) { Remove-Item -LiteralPath $final -Recurse -Force }
    Copy-Item -LiteralPath $src -Destination $final -Recurse
    Get-ChildItem -LiteralPath $final -Recurse -File | Unblock-File
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $final $_)) })
    if ($missing.Count) { Write-Host "ERROR: missing files in ${final}: $($missing -join ', ')"; exit 1 }
    Write-Host "Installed to $final"
    $installed += $final
}
if ($tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

# 4. Set up ffmpeg now so the first transcription is fast
if (-not $SkipTools) {
    Write-Host "Checking ffmpeg..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installed[0] 'scripts\ensure-tools.ps1')
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Skill installed, but ffmpeg setup failed. The skill will retry on first use,"
        Write-Host "or run: winget install Gyan.FFmpeg"
    }
}

Write-Host ""
Write-Host "Done. Start a NEW agent session (the skill is only detected at session start), then say:"
Write-Host "  Use the transcribe-audio skill on ""<your audio file>"""
if ($Agent -in @('Claude', 'All')) {
    Write-Host ""
    Write-Host "NOTE: this skill needs a model that can hear audio. Claude cannot listen to audio files,"
    Write-Host "so in Claude Code the skill will stop and say so. It works fully in Antigravity (Gemini)."
}
exit 0
