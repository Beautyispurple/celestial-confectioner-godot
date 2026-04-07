$root = Split-Path -Parent $PSScriptRoot
Get-ChildItem -Path $root -Filter "*.gd" -Recurse -File | Where-Object { $_.FullName -notmatch "\\addons\\" } | ForEach-Object {
    $p = $_.FullName
    $t = [IO.File]::ReadAllText($p)
    if ($t.IndexOf([char]13) -ge 0) {
        $t2 = $t -replace "`r`n", "`n" -replace "`r", "`n"
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [IO.File]::WriteAllText($p, $t2, $utf8)
        Write-Host "LF: $p"
    }
}
