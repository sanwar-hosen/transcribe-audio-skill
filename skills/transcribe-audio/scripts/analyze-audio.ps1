param(
    [Parameter(Mandatory = $true)][string]$Audio,
    [double]$NoiseDb = -35,
    [double]$MinSilence = 2,
    [double]$GapCheckSeconds = 20,
    [double]$ChunkAboveMinutes = 30
)
. "$PSScriptRoot\lib.ps1"

if (-not (Test-Path -LiteralPath $Audio)) { Write-Host "ERROR: file not found: $Audio"; exit 1 }
$ff = Find-Tool 'ffmpeg'; $fp = Find-Tool 'ffprobe'
if (-not $ff -or -not $fp) { Write-Host "ERROR: ffmpeg/ffprobe missing. Run ensure-tools.ps1 first."; exit 1 }

$audioFull = (Resolve-Path -LiteralPath $Audio).Path
$name = [IO.Path]::GetFileNameWithoutExtension($audioFull) -replace '[^\w\-]+', '_'
$work = Join-Path $env:TEMP "transcribe-audio\$name"
New-Item -ItemType Directory -Force -Path $work | Out-Null

$duration = Get-Duration $fp $audioFull
if ($duration -le 0) { Write-Host "ERROR: could not read duration."; exit 1 }

# silence map
$r = Run-Native $ff @('-hide_banner', '-nostats', '-i', $audioFull,
    '-af', "silencedetect=noise=$($NoiseDb)dB:d=$MinSilence", '-f', 'null', '-')
$silences = @()
$curStart = $null
foreach ($line in ($r.Err -split "`r?`n")) {
    if ($line -match 'silence_start:\s*(-?[\d.]+)') {
        $curStart = [math]::Max(0.0, (To-Double $Matches[1]))
    } elseif ($line -match 'silence_end:\s*(-?[\d.]+)') {
        if ($null -ne $curStart) {
            $silences += [pscustomobject]@{ Start = $curStart; End = (To-Double $Matches[1]) }
            $curStart = $null
        }
    }
}
if ($null -ne $curStart) { $silences += [pscustomobject]@{ Start = $curStart; End = $duration } }

# speech = everything that is not silence
$speech = @(); $pos = 0.0
foreach ($s in ($silences | Sort-Object Start)) {
    if (($s.Start - $pos) -ge 0.3) { $speech += [pscustomobject]@{ Start = $pos; End = $s.Start } }
    $pos = [math]::Max($pos, $s.End)
}
if (($duration - $pos) -ge 0.3) { $speech += [pscustomobject]@{ Start = $pos; End = $duration } }

$speechTotal = 0.0
foreach ($s in $speech) { $speechTotal += ($s.End - $s.Start) }

$whole = Get-Volume $ff $audioFull 0 $duration
$sizeMB = (Get-Item -LiteralPath $audioFull).Length / 1MB
# Only very long recordings are cut. Everything shorter is heard as ONE file.
$mode = if ($speech.Count -eq 0) { 'NONE' }
        elseif ($duration -ge ($ChunkAboveMinutes * 60)) { 'CHUNK' }
        else { 'WHOLE_FILE' }
$next = switch ($mode) {
    'NONE'       { 'NEXT: tell the user no speech was detected. Do not write a transcript.' }
    'WHOLE_FILE' { 'NEXT: open the ORIGINAL file once and transcribe it. Do NOT cut, split, trim or extract any part of it.' }
    'CHUNK'      { 'NEXT: run split-audio.ps1 for each speech region. Do NOT cut audio any other way.' }
}

$lines = @()
$lines += "FILE=$audioFull"
$lines += "WORKDIR=$work"
$lines += "DURATION=$(Fmt-Time $duration) ($([math]::Round($duration, 1)) s)"
$lines += "SIZE_MB=$([math]::Round($sizeMB, 1))"
$lines += "OVERALL_MEAN_DB=$($whole.Mean) OVERALL_PEAK_DB=$($whole.Max)"
$lines += "SPEECH_TOTAL=$(Fmt-Time $speechTotal) ($([math]::Round($speechTotal)) s)"
$lines += "SPEECH_REGIONS=$($speech.Count)"
$i = 1
foreach ($s in $speech) {
    $lines += ("  region {0}: {1} - {2} ({3} s)" -f $i, (Fmt-Time $s.Start), (Fmt-Time $s.End), [math]::Round($s.End - $s.Start))
    $i++
}
$lines += "SILENT_GAPS_OVER_$($GapCheckSeconds)S:"
$anyGap = $false
foreach ($s in $silences) {
    $len = $s.End - $s.Start
    if ($len -ge $GapCheckSeconds) {
        $anyGap = $true
        $v = Get-Volume $ff $audioFull $s.Start $s.End
        $verdict = if ($null -eq $v.Max) { 'unknown (check manually)' }
                   elseif ($v.Max -gt -50) { 'QUIET SOUND PRESENT - listen to this part' }
                   else { 'silent' }
        $lines += ("  {0} - {1} ({2} s) peak={3} dB -> {4}" -f (Fmt-Time $s.Start), (Fmt-Time $s.End), [math]::Round($len), $v.Max, $verdict)
    }
}
if (-not $anyGap) { $lines += "  none" }
$lines += "MODE=$mode"
$lines += $next

$csv = @('start,end')
foreach ($s in $speech) { $csv += "$(Inv $s.Start),$(Inv $s.End)" }
Set-Content -LiteralPath (Join-Path $work 'speech_regions.csv') -Value $csv -Encoding UTF8
Set-Content -LiteralPath (Join-Path $work 'analysis.txt') -Value $lines -Encoding UTF8
$lines | ForEach-Object { Write-Host $_ }
exit 0
