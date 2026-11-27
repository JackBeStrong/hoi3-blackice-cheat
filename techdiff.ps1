# Compares two countries in the latest save: for every tech that has an effect block for -Unit,
# sums each effect key (build_cost_ic, build_time, sea_attack, ...) weighted by each country's tech level.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File techdiff.ps1 [-Unit carrier] [-A CHI] [-B JAP] [-Detail build_cost_ic]
# note: PowerShell variable names are case-insensitive, so the file object must not be called $save (that is the [string] -Save parameter)
param([string]$Unit = 'carrier', [string]$A = 'CHI', [string]$B = 'JAP', [string]$Detail = '', [string]$SaveName = '')
$mod  = 'C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1'
$sdir = 'C:\Users\jack\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 15.1\save games'
if ($SaveName) { $saveFile = Get-Item -LiteralPath (Join-Path $sdir $SaveName) }
else { $saveFile = Get-ChildItem $sdir -Filter *.hoi3 | Where-Object { $_.Name -notmatch '^TEST ' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
Write-Output "save: $($saveFile.Name)"
$t = [IO.File]::ReadAllText($saveFile.FullName, [Text.Encoding]::GetEncoding(1252))

function Get-Levels([string]$tag) {
    $i = $t.IndexOf("`n$tag=")
    $j = $t.IndexOf("`n}", $i + 5)
    $b = $t.Substring($i, $j - $i)
    $h = @{}
    foreach ($m in [regex]::Matches($b, '(?m)^\s*(\w+)=\{(\d+)(?: [\d\.]+){1,2}\}')) {
        $n = $m.Groups[1].Value; $v = [int]$m.Groups[2].Value
        if (-not $h.ContainsKey($n) -or $h[$n] -lt $v) { $h[$n] = $v }
    }
    return $h
}
$la = Get-Levels $A
$lb = Get-Levels $B

# collect every key inside "<Unit> = { ... }" for every tech, tolerating "{" on the next line
$effects = @()   # tech, key, per
Get-ChildItem "$mod\technologies" -Filter *.txt | ForEach-Object {
    $txt = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::GetEncoding(1252))
    $txt = [regex]::Replace($txt, '#[^\r\n]*', '')
    $depth = 0; $tech = ''; $pending = ''; $inUnit = -1
    foreach ($tok in [regex]::Matches($txt, '\{|\}|[\w\.\-]+')) {
        $v = $tok.Value
        if ($v -eq '{') {
            if ($depth -eq 0) { $tech = $pending }
            if ($depth -eq 1 -and $pending -eq $Unit) { $inUnit = 2 }
            $depth++; $pending = ''; continue
        }
        if ($v -eq '}') { $depth--; if ($depth -lt 2) { $inUnit = -1 }; $pending = ''; continue }
        if ($v -match '^-?[\d\.]+$' -and $pending -ne '') {
            if ($inUnit -eq 2 -and $depth -eq 2) { $effects += [pscustomobject]@{ tech = $tech; key = $pending; per = [double]$v } }
            $pending = ''; continue
        }
        if ($v -match '^[A-Za-z_]') { $pending = $v }
    }
}

# note: PowerShell variables are case-insensitive, so don't reuse $a/$b here (they would overwrite $A/$B)
$rows = foreach ($e in $effects) {
    $levelA = if ($la.ContainsKey($e.tech)) { $la[$e.tech] } else { 0 }
    $levelB = if ($lb.ContainsKey($e.tech)) { $lb[$e.tech] } else { 0 }
    [pscustomobject]@{ tech = $e.tech; key = $e.key; per = $e.per; lvlA = $levelA; lvlB = $levelB; totA = $e.per * $levelA; totB = $e.per * $levelB }
}

Write-Output "`n== $Unit : summed effects (A=$A vs B=$B)"
$rows | Group-Object key | ForEach-Object {
    [pscustomobject]@{ key = $_.Name; A = [math]::Round(($_.Group | Measure-Object totA -Sum).Sum, 3); B = [math]::Round(($_.Group | Measure-Object totB -Sum).Sum, 3) }
} | Sort-Object key | Format-Table -AutoSize | Out-String -Width 200

# "upgrades": sum of levels of every tech that has an effect block for this unit (HoI3 wiki: each upgrade ~ +1% IC and time)
$techs = $effects | Select-Object -ExpandProperty tech -Unique
$upA = ($techs | ForEach-Object { if ($la.ContainsKey($_)) { $la[$_] } else { 0 } } | Measure-Object -Sum).Sum
$upB = ($techs | ForEach-Object { if ($lb.ContainsKey($_)) { $lb[$_] } else { 0 } } | Measure-Object -Sum).Sum
Write-Output "== upgrades (sum of levels of techs with a $Unit block): A=$A $upA   B=$B $upB   (techs with a block: $(@($techs).Count))"

if ($Detail) {
    Write-Output "== detail for $Detail"
    $rows | Where-Object { $_.key -eq $Detail -and ($_.lvlA -gt 0 -or $_.lvlB -gt 0) } | Sort-Object totA |
        Format-Table tech, per, lvlA, totA, lvlB, totB -AutoSize | Out-String -Width 200
}
