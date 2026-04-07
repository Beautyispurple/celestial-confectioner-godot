# DO NOT use general English word lists (e.g. Google 10k) for this file.
# That produced random/offensive words unrelated to breathing. Curated JSON lives in
# data/breath_temper_words.json and is edited by hand. This script only validates JSON shape.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "data\breath_temper_words.json"
if (-not (Test-Path $path)) {
    Write-Error "Missing $path"
}
$json = Get-Content $path -Raw | ConvertFrom-Json
$keys = @("inhale_calm", "hold_still", "exhale_release", "hold_accomplish")
foreach ($k in $keys) {
    if (-not $json.PSObject.Properties.Name -contains $k) { Write-Error "Missing key $k" }
    $arr = $json.$k
    if ($arr.Count -lt 1) { Write-Error "Empty array $k" }
}
Write-Host "OK: breath_temper_words.json structure valid ($path)"
