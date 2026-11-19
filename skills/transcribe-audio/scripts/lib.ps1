# lib.ps1 - shared helpers (dot-source this file)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Refresh-Path {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$m;$u"
}

function Find-Tool([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $roots = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "$env:USERPROFILE\ffmpeg-tools",
        "$env:ProgramData\chocolatey\bin",
        "$env:USERPROFILE\scoop\shims",
        "C:\ffmpeg"
    )
    foreach ($r in $roots) {
        if (Test-Path $r) {
            $hit = Get-ChildItem -Path $r -Filter "$name.exe" -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    return $null
}

function Run-Native([string]$exe, [string[]]$arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = ($arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $out; Err = $errTask.Result }
}

function To-Double([string]$s) {
    [double]::Parse($s.Trim(), [Globalization.CultureInfo]::InvariantCulture)
}

function Inv([double]$x) {
    $x.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture)
}

function Fmt-Time([double]$s) {
    $t = [int][math]::Floor($s)
    '{0:D2}:{1:D2}:{2:D2}' -f [int][math]::Floor($t / 3600), [int][math]::Floor(($t % 3600) / 60), ($t % 60)
}

function Get-Duration([string]$ffprobe, [string]$file) {
    $r = Run-Native $ffprobe @('-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', $file)
    try { $d = To-Double $r.Out } catch { return 0.0 }
    return $d
}

function Get-Volume([string]$ffmpeg, [string]$file, [double]$start, [double]$end) {
    $a = @('-hide_banner', '-nostats', '-ss', (Inv $start), '-t', (Inv ($end - $start)),
           '-i', $file, '-af', 'volumedetect', '-f', 'null', '-')
    $r = Run-Native $ffmpeg $a
    $max = $null; $mean = $null
    if ($r.Err -match 'max_volume:\s*(-?[\d.]+|-inf)\s*dB') {
        $max = if ($Matches[1] -eq '-inf') { -120.0 } else { To-Double $Matches[1] }
    }
    if ($r.Err -match 'mean_volume:\s*(-?[\d.]+|-inf)\s*dB') {
        $mean = if ($Matches[1] -eq '-inf') { -120.0 } else { To-Double $Matches[1] }
    }
    return [pscustomobject]@{ Max = $max; Mean = $mean }
}
