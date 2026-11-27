# Counts "upgrades" for a unit: the summed levels of every tech that has an effect block for that unit,
# for one country in a given save. HoI3 wiki: "Each upgrade seems to result in a 1% increase in unit IC cost and build time."
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File upgrades.ps1 -SaveName "<file>.hoi3" -Tag USA [-Unit carrier]
param([string]$SaveName, [string]$Tag = 'USA', [string]$Unit = 'carrier', [switch]$List)
$mod  = 'C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1'
$sdir = 'C:\Users\jack\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 15.1\save games'
$enc  = [Text.Encoding]::GetEncoding(1252)
$path = Join-Path $sdir $SaveName
if (-not (Test-Path -LiteralPath $path)) { throw "save not found: $path" }
$t = [IO.File]::ReadAllText($path, $enc)
$i = $t.IndexOf("`n$Tag="); $j = $t.IndexOf("`n}", $i + 5); $b = $t.Substring($i, $j - $i)
$lv = @{}
foreach ($m in [regex]::Matches($b, '(?m)^\t\t(\w+)=\{(\d+) [\d\.]+ [\d\.]+\}')) {
    if (-not $lv.ContainsKey($m.Groups[1].Value)) { $lv[$m.Groups[1].Value] = [int]$m.Groups[2].Value }
}
# techs with a <Unit> block, and whether that block has a build_cost_ic / build_time line
$techs = @{}
Get-ChildItem "$mod\technologies" -Filter *.txt | ForEach-Object {
    $txt = [regex]::Replace([IO.File]::ReadAllText($_.FullName, $enc), '#[^\r\n]*', '')
    $stack = New-Object System.Collections.Generic.List[string]; $pending = ''
    foreach ($tok in [regex]::Matches($txt, '\{|\}|[\w\.\-]+')) {
        $v = $tok.Value
        if ($v -eq '{') { $stack.Add($pending); if ($stack.Count -eq 2 -and $pending -eq $Unit -and -not $techs.ContainsKey($stack[0])) { $techs[$stack[0]] = '' }; $pending = ''; continue }
        if ($v -eq '}') { if ($stack.Count) { $stack.RemoveAt($stack.Count - 1) }; $pending = ''; continue }
        if ($v -match '^-?[\d\.]+$' -and $pending) {
            if ($stack.Count -eq 2 -and $stack[1] -eq $Unit -and $pending -match '^build_') { $techs[$stack[0]] = 'has build line' }
            $pending = ''; continue
        }
        if ($v -match '^[A-Za-z_]') { $pending = $v }
    }
}
$rows = foreach ($k in $techs.Keys) { [pscustomobject]@{ tech = $k; level = $(if ($lv.ContainsKey($k)) { $lv[$k] } else { 0 }); note = $techs[$k] } }
$date = if ($t -match 'date="([^"]+)"') { $matches[1] } else { '?' }
$all = ($rows | Measure-Object level -Sum).Sum
$plain = ($rows | Where-Object { $_.note -eq '' } | Measure-Object level -Sum).Sum
Write-Output ("{0,-40} {1,-14} {2} {3}: upgrades={4}  (without techs that have their own build line: {5})" -f $SaveName, $date, $Tag, $Unit, $all, $plain)
if ($List) { $rows | Where-Object { $_.level -gt 0 } | Sort-Object tech | Format-Table -AutoSize | Out-String -Width 200 }
