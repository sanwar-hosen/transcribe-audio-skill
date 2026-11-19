param(
    [Parameter(Mandatory = $true)][string]$Transcript,
    [Parameter(Mandatory = $true)][string]$Regions,
    [double]$Tolerance = 5,
    [double]$MaxGap = 45
)
. "$PSScriptRoot\lib.ps1"

$stamps = @()
foreach ($line in (Get-Content -LiteralPath $Transcript -Encoding UTF8)) {
    if ($line -match '^\[(\d{2}):(\d{2}):(\d{2})\]') {
        $stamps += ([int]$Matches[1] * 3600 + [int]$Matches[2] * 60 + [int]$Matches[3])
    }
}
if ($stamps.Count -eq 0) { Write-Host "COVERAGE_FAIL: no [HH:MM:SS] entries found"; exit 3 }
$stamps = @($stamps | Sort-Object)

$problems = @()
foreach ($r in (Import-Csv -LiteralPath $Regions)) {
    $rs = To-Double $r.start; $re = To-Double $r.end
    if (($re - $rs) -lt 2) { continue }
    $near = @($stamps | Where-Object { $_ -ge ($rs - $Tolerance) -and $_ -le ($re + $Tolerance) })
    if ($near.Count -eq 0) {
        $problems += "NO transcript entries for speech $(Fmt-Time $rs) - $(Fmt-Time $re)"
        continue
    }
    $inside = @($stamps | Where-Object { $_ -ge $rs -and $_ -le $re })
    $pts = @($rs) + $inside + @($re)
    $pts = @($pts | Sort-Object)
    for ($i = 1; $i -lt $pts.Count; $i++) {
        if (($pts[$i] - $pts[$i - 1]) -gt $MaxGap) {
            $problems += "Possible skipped speech between $(Fmt-Time $pts[$i - 1]) and $(Fmt-Time $pts[$i])"
        }
    }
}

if ($problems.Count -eq 0) {
    Write-Host "COVERAGE_OK ($($stamps.Count) entries, last at $(Fmt-Time $stamps[-1]))"
    exit 0
}
Write-Host "COVERAGE_PROBLEMS:"
$problems | ForEach-Object { Write-Host "  $_" }
exit 3
