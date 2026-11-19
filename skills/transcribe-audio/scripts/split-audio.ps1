param(
    [Parameter(Mandatory = $true)][string]$Audio,
    [double]$From = 0,
    [double]$To = 0,
    [double]$ChunkSeconds = 600,
    [double]$Overlap = 3,
    [string]$OutDir
)
. "$PSScriptRoot\lib.ps1"

if (-not (Test-Path -LiteralPath $Audio)) { Write-Host "ERROR: file not found: $Audio"; exit 1 }
$ff = Find-Tool 'ffmpeg'; $fp = Find-Tool 'ffprobe'
if (-not $ff -or -not $fp) { Write-Host "ERROR: ffmpeg/ffprobe missing. Run ensure-tools.ps1 first."; exit 1 }

$audioFull = (Resolve-Path -LiteralPath $Audio).Path
$name = [IO.Path]::GetFileNameWithoutExtension($audioFull) -replace '[^\w\-]+', '_'
$duration = Get-Duration $fp $audioFull
if ($duration -le 0) { Write-Host "ERROR: could not read duration."; exit 1 }
if ($To -le 0 -or $To -gt $duration) { $To = $duration }
if (-not $OutDir) { $OutDir = Join-Path $env:TEMP "transcribe-audio\$name\chunks" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$pos = $From
while ($pos -lt ($To - 0.5)) {
    $len = [math]::Min($ChunkSeconds + $Overlap, $To - $pos)
    $file = Join-Path $OutDir ("chunk_{0}s.m4a" -f [int][math]::Floor($pos))
    $r = Run-Native $ff @('-hide_banner', '-y', '-ss', (Inv $pos), '-t', (Inv $len),
        '-i', $audioFull, '-vn', '-ac', '1', '-c:a', 'aac', '-b:a', '64k', $file)
    if ($r.Code -ne 0 -or -not (Test-Path -LiteralPath $file)) {
        Write-Host "ERROR: failed to create piece at $(Fmt-Time $pos)"; exit 1
    }
    Write-Host "CHUNK=$file START=$(Fmt-Time $pos) START_SECONDS=$(Inv $pos) LENGTH=$(Inv $len)"
    $pos += $ChunkSeconds
}
exit 0
