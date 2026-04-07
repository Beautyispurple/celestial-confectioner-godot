$root = Join-Path (Split-Path -Parent $PSScriptRoot) ""
Get-ChildItem -Path (Join-Path $root "ui") -Filter "*.gd" -Recurse -File | ForEach-Object {
    $p = $_.FullName
    $t = [IO.File]::ReadAllText($p)
    if ($t.IndexOf([char]13) -ge 0) {
        $t2 = $t -replace "`r`n", "`n" -replace "`r", "`n"
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [IO.File]::WriteAllText($p, $t2, $utf8)
        Write-Host "LF: $p"
    }
}
