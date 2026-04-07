# Builds data/breath_temper_words.json from curated one-word-per-line pool files in tools/.
# Do not use general English frequency lists; pools are hand-written for breathing / grounding tone.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$toolDir = $PSScriptRoot

function Read-UniqueWords([string]$fileName) {
    $path = Join-Path $toolDir $fileName
    if (-not (Test-Path $path)) {
        Write-Error "Missing $path"
    }
    $seen = @{}
    $out = [System.Collections.ArrayList]@()
    Get-Content $path | ForEach-Object {
        $w = $_.Trim().ToLower()
        if ($w -eq "" -or $seen.ContainsKey($w)) { return }
        $seen[$w] = $true
        [void]$out.Add($w)
    }
    return ,$out.ToArray()
}

$inh = Read-UniqueWords "pools_inhale.txt"
$hold = Read-UniqueWords "pools_hold_still.txt"
$exh = Read-UniqueWords "pools_exhale.txt"
$h2 = Read-UniqueWords "pools_hold_accomplish.txt"

$obj = [ordered]@{
    inhale_calm = $inh
    hold_still = $hold
    exhale_release = $exh
    hold_accomplish = $h2
}
$json = $obj | ConvertTo-Json -Depth 5
$outPath = Join-Path $root "data\breath_temper_words.json"
$dataDir = Split-Path $outPath
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outPath, $json, $utf8)
Write-Host "Wrote $outPath"
Write-Host ("inhale {0} hold {1} exhale {2} hold2 {3}" -f $inh.Count, $hold.Count, $exh.Count, $h2.Count)
