$utf8 = New-Object System.Text.UTF8Encoding $false
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
foreach ($name in @('intro_sequence.dtl', 'day_0.dtl')) {
    $p = Join-Path $root $name
    $t = [IO.File]::ReadAllText($p)
    $t = $t.Replace("`r`n", "`n").Replace("`r", "`n")
    [IO.File]::WriteAllText($p, $t, $utf8)
}
