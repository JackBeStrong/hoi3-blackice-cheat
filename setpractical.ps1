# Sets naval practicals for one country in a BlackICE save. Backs up the save first.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File setpractical.ps1 [-Tag CHI] [-Value 20] [-Save <file name>]
# Default save: the most recent non-autosave. Load the save again in game after running.
param(
    [string]$Tag = 'CHI',
    [double]$Value = 20,   # MAX_TECH_ABILITY in common/defines.lua is 20
    [string]$Save = '',
    [string[]]$Names = @('carrier_practical', 'capitalship_practical', 'cruiser_practical', 'destroyer_practical',
                         'submarine_practical', 'naval_engineering', 'naval_doctrine_practical')
)
$dir = 'C:\Users\jack\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 15.1\save games'
$file = if ($Save) { Join-Path $dir $Save } else {
    (Get-ChildItem $dir -Filter *.hoi3 | Where-Object { $_.Name -notmatch 'autosave' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
Write-Output "save: $file"

$enc = [Text.Encoding]::GetEncoding(1252)
$t = [IO.File]::ReadAllText($file, $enc)
$i = $t.IndexOf("`n$Tag=")
if ($i -lt 0) { throw "country $Tag not found" }
$j = $t.IndexOf("`n}", $i + 5)
$block = $t.Substring($i, $j - $i)

$val = $Value.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
foreach ($n in $Names) {
    $re = "(?m)^(\t$n=)([\d\.]+)"
    $m = [regex]::Match($block, $re)
    if (-not $m.Success) { Write-Output "  $n not found"; continue }
    Write-Output ("  {0,-26} {1} -> {2}" -f $n, $m.Groups[2].Value, $val)
    $block = [regex]::Replace($block, $re, "`${1}$val", 1)
}

$backup = "$file.bak"
if (-not (Test-Path $backup)) { Copy-Item $file $backup }
Write-Output "backup: $backup"
[IO.File]::WriteAllText($file, $t.Substring(0, $i) + $block + $t.Substring($j), $enc)
Write-Output 'done - reload the save in game'
