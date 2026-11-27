# Lists the techs whose level differs for one country between two saves, plus each one's effect on a unit.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File savediff.ps1 -Old <save> -New <save> [-Tag USA] [-Unit carrier]
param([Parameter(Mandatory)] [string]$Old, [Parameter(Mandatory)] [string]$New, [string]$Tag = 'USA', [string]$Unit = 'carrier')
$dir = 'C:\Users\jack\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 15.1\save games'
$mod = 'C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1'
$enc = [Text.Encoding]::GetEncoding(1252)

function Get-Levels([string]$file) {
    $t = [IO.File]::ReadAllText((Join-Path $dir $file), $enc)
    $date = if ($t -match 'date="([^"]+)"') { $matches[1] } else { '?' }
    $i = $t.IndexOf("`n$Tag="); $j = $t.IndexOf("`n}", $i + 5); $b = $t.Substring($i, $j - $i); $h = @{}
    foreach ($m in [regex]::Matches($b, '(?m)^\t\t(\w+)=\{(\d+) [\d\.]+ [\d\.]+\}')) {
        if (-not $h.ContainsKey($m.Groups[1].Value)) { $h[$m.Groups[1].Value] = [int]$m.Groups[2].Value }
    }
    return @{ date = $date; lv = $h }
}
$o = Get-Levels $Old; $n = Get-Levels $New
Write-Output "$Tag  $Old ($($o.date))  ->  $New ($($n.date))"

# per-tech effects on the unit (one line per tech: key=value ...)
$eff = @{}
Get-ChildItem "$mod\technologies" -Filter *.txt | ForEach-Object {
    $txt = [regex]::Replace([IO.File]::ReadAllText($_.FullName, $enc), '#[^\r\n]*', '')
    $stack = New-Object System.Collections.Generic.List[string]; $pending = ''
    foreach ($tok in [regex]::Matches($txt, '\{|\}|[\w\.\-]+')) {
        $v = $tok.Value
        if ($v -eq '{') { $stack.Add($pending); $pending = ''; continue }
        if ($v -eq '}') { if ($stack.Count) { $stack.RemoveAt($stack.Count - 1) }; $pending = ''; continue }
        if ($v -match '^-?[\d\.]+$' -and $pending) {
            if ($stack.Count -eq 2 -and $stack[1] -eq $Unit) { $eff[$stack[0]] = (@($eff[$stack[0]]) + "$pending=$v") -join ' ' }
            $pending = ''; continue
        }
        if ($v -match '^[A-Za-z_]') { $pending = $v }
    }
}

$keys = @($o.lv.Keys + $n.lv.Keys | Sort-Object -Unique)
$rows = foreach ($k in $keys) {
    $a = if ($o.lv.ContainsKey($k)) { $o.lv[$k] } else { 0 }
    $b = if ($n.lv.ContainsKey($k)) { $n.lv[$k] } else { 0 }
    if ($a -ne $b) { [pscustomobject]@{ tech = $k; old = $a; new = $b; "effect_on_$Unit" = $(if ($eff.ContainsKey($k)) { $eff[$k].Trim() } else { '' }) } }
}
Write-Output "techs changed: $(@($rows).Count)"
$rows | Sort-Object { $_."effect_on_$Unit" -eq '' }, tech | Format-Table -AutoSize -Wrap | Out-String -Width 300
