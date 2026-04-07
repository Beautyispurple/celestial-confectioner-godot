param([string[]]$Paths)
if ($Paths.Count -eq 0) {
    $Paths = $args
}
foreach ($p in $Paths) {
    if (-not (Test-Path $p)) { Write-Host "missing $p"; continue }
    $t = [IO.File]::ReadAllText($p)
    if ($t.IndexOf([char]13) -ge 0) {
        $t2 = $t -replace "`r`n", "`n" -replace "`r", "`n"
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [IO.File]::WriteAllText($p, $t2, $utf8)
        Write-Host "normalized LF: $p"
    } else {
        Write-Host "already LF: $p"
    }
}
