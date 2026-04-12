# Prefix / substring match voice lines in .dtl (longest key wins; duplicate WAV keys collapsed).
# Run: powershell -NoProfile -File tools/sync_dialogic_voice.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$voiceDir = Join-Path $root "voice"

function Normalize-Key([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return "" }
    $lower = $s.ToLower()
    return [regex]::Replace($lower, "[^a-z0-9]", "")
}

function Get-StemKey([string]$fileBase) {
    if ($fileBase -match "^\d+(.+)$") {
        return Normalize-Key $matches[1]
    }
    return Normalize-Key $fileBase
}

function Leading-Num([string]$name) {
    if ($name -match "^(\d+)") { return [int]$matches[1] }
    return 999999
}

# key -> single best filename (lowest leading number wins)
$wavFiles = Get-ChildItem -Path $voiceDir -Filter "*.wav" -File
$keyToFile = @{}
foreach ($f in ($wavFiles | Sort-Object { Leading-Num $_.BaseName }, Name)) {
    $base = $f.BaseName
    $k = Get-StemKey $base
    if ([string]::IsNullOrEmpty($k) -or $k.Length -lt 4) { continue }
    if (-not $keyToFile.ContainsKey($k)) {
        $keyToFile[$k] = $f.Name
    }
}

$blockedKeys = @{
    "days" = $true; "week" = $true; "weeks" = $true; "months" = $true; "month" = $true
}

function Match-Wav([string]$textKey) {
    if ([string]::IsNullOrEmpty($textKey)) { return $null }
    $best = $null
    $bestLen = 0
    $bestIdx = [int]::MaxValue
    foreach ($k in $keyToFile.Keys) {
        if ($blockedKeys.ContainsKey($k)) { continue }
        if ($k.Length -lt 4) { continue }
        $idx = $textKey.IndexOf($k)
        if ($idx -lt 0) { continue }
        if ($k.Length -gt $bestLen) {
            $bestLen = $k.Length
            $bestIdx = $idx
            $best = $k
        }
        elseif ($k.Length -eq $bestLen -and $idx -lt $bestIdx) {
            $bestIdx = $idx
            $best = $k
        }
    }
    if ($null -eq $best) { return $null }
    # Short keys only at line start, and not for long lines (avoid "marzi" in the middle winning wrongly)
    if ($best.Length -le 5 -and $textKey.Length -gt $best.Length + 12 -and $bestIdx -gt 0) {
        return $null
    }
    return @{ File = $keyToFile[$best]; Key = $best; Index = $bestIdx }
}

$reserved = @{
    "if" = $true; "elif" = $true; "else" = $true; "jump" = $true; "label" = $true
    "join" = $true; "leave" = $true; "do" = $true; "set" = $true; "wait" = $true
    "return" = $true
}

function Get-DialogueLineInfo([string]$line) {
    if ($line -match "^(\t*)([^\s]+)\s+\(([^)]+)\):\s*(.*)$") {
        return @{
            Indent = $matches[1]
            Speech = $matches[4]
            ParenOnly = $false
        }
    }
    if ($line -match "^(\t*)([\w-]+):\s*(.+)$") {
        $tok = $matches[2]
        if ($reserved.ContainsKey($tok)) { return $null }
        return @{
            Indent = $matches[1]
            Speech = $matches[3]
            ParenOnly = $false
        }
    }
    if ($line -match "^(\t*)\((.+)\)\s*$") {
        return @{
            Indent = $matches[1]
            Speech = $matches[2]
            ParenOnly = $true
        }
    }
    $trim = $line.TrimEnd()
    if ($trim -match "^[A-Z0-9!,'\s\.\?\`"-:]+$" -and $trim.Length -ge 6) {
        if ($trim -match "[a-z]") { return $null }
        if ($line -match "^(\t*)(.+)$") {
            return @{
                Indent = $matches[1]
                Speech = $matches[2].TrimEnd()
                ParenOnly = $false
            }
        }
    }
    return $null
}

function Get-VoicePathFromLine([string]$line) {
    if ($line -match 'path="(res://voice/[^"]+)"') { return $matches[1] }
    return $null
}

function Expected-VoiceLine([string]$indent, [string]$fileName) {
    return "${indent}[voice path=`"res://voice/$fileName`" volume=`"0.0`" bus=`"Voice`"]"
}

function Process-Dtl([string]$path, [ref]$unmatched) {
    $lines = [System.IO.File]::ReadAllLines($path)
    $out = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $info = Get-DialogueLineInfo $line
        if ($null -eq $info) {
            $out.Add($line) | Out-Null
            $i++
            continue
        }

        $speechKey = Normalize-Key $info.Speech
        $match = Match-Wav $speechKey

        $prevNonEmpty = $i - 1
        while ($prevNonEmpty -ge 0 -and [string]::IsNullOrWhiteSpace($lines[$prevNonEmpty])) {
            $prevNonEmpty--
        }
        $hasVoice = ($prevNonEmpty -ge 0) -and ($lines[$prevNonEmpty] -match "\[voice\s")

        if ($info.ParenOnly -and -not $hasVoice) {
            $out.Add($line) | Out-Null
            $i++
            continue
        }

        if ($null -eq $match) {
            if ($hasVoice) {
                $unmatched.Value += "$path :$($i+1): (voice present, no match) $($line.Trim().Substring(0, [Math]::Min(80, $line.Trim().Length)))"
            }
            $out.Add($line) | Out-Null
            $i++
            continue
        }

        $want = Expected-VoiceLine $info.Indent $match.File
        if ($hasVoice) {
            $curPath = Get-VoicePathFromLine $lines[$prevNonEmpty]
            $expectedPath = "res://voice/$($match.File)"
            if ($curPath -eq $expectedPath) {
                $out.Add($line) | Out-Null
                $i++
                continue
            }
            while ($out.Count -gt 0 -and [string]::IsNullOrWhiteSpace($out[$out.Count - 1])) {
                $out.RemoveAt($out.Count - 1)
            }
            if ($out.Count -gt 0 -and ($out[$out.Count - 1] -match "\[voice\s")) {
                $out.RemoveAt($out.Count - 1)
            }
            $out.Add($want) | Out-Null
            $out.Add($line) | Out-Null
            $i++
            continue
        }

        $out.Add($want) | Out-Null
        $out.Add($line) | Out-Null
        $i++
    }

    # LF-only: CRLF breaks Dialogic shortcodes (line must end with ], not ]\r)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, [string]::Join("`n", $out), $utf8NoBom)
}

$unm = New-Object System.Collections.Generic.List[string]

Process-Dtl (Join-Path $root "intro_sequence.dtl") ([ref]$unm)
Process-Dtl (Join-Path $root "day_0.dtl") ([ref]$unm)

Write-Host "Unmatched (with existing voice): $($unm.Count)"
$unm | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
if ($unm.Count -gt 40) { Write-Host "... ($($unm.Count) total)" }
