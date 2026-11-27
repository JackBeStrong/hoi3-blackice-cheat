# Lists tech-level (country-wide) modifiers in the mod's tech files, i.e. keys directly inside a tech block
# (not inside a unit block), weighted by tech level for two countries in the latest save.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File modscan.ps1 [-A CHI] [-B JAP] [-Key regex]
param([string]$A = 'CHI', [string]$B = 'JAP', [string]$Key = 'build|recruit|cost|production|speed|time')
$mod  = 'C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1'
$save = Get-ChildItem 'C:\Users\jack\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 15.1\save games' -Filter *.hoi3 |
        Where-Object { $_.Name -notmatch '^TEST ' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$t = [IO.File]::ReadAllText($save.FullName, [Text.Encoding]::GetEncoding(1252))
function Get-Levels([string]$tag) {
    $i = $t.IndexOf("`n$tag="); $j = $t.IndexOf("`n}", $i + 5); $blk = $t.Substring($i, $j - $i); $h = @{}
    foreach ($m in [regex]::Matches($blk, '(?m)^\s*(\w+)=\{(\d+)(?: [\d\.]+){1,2}\}')) {
        $n = $m.Groups[1].Value; $v = [int]$m.Groups[2].Value
        if (-not $h.ContainsKey($n) -or $h[$n] -lt $v) { $h[$n] = $v }
    }
    $h
}
$la = Get-Levels $A; $lb = Get-Levels $B
$skip = '^(difficulty|start_year|first_offset|additional_offset|max_level|cost|time)$'
$rows = @()
Get-ChildItem "$mod\technologies" -Filter *.txt | ForEach-Object {
    $file = $_.Name
    $txt = [regex]::Replace([IO.File]::ReadAllText($_.FullName, [Text.Encoding]::GetEncoding(1252)), '#[^\r\n]*', '')
    $stack = New-Object System.Collections.Generic.List[string]; $pending = ''
    foreach ($tok in [regex]::Matches($txt, '\{|\}|[\w\.\-]+')) {
        $v = $tok.Value
        if ($v -eq '{') { $stack.Add($pending); $pending = ''; continue }
        if ($v -eq '}') { if ($stack.Count) { $stack.RemoveAt($stack.Count - 1) }; $pending = ''; continue }
        if ($v -match '^-?[\d\.]+$' -and $pending) {
            if ($stack.Count -eq 1 -and $pending -match $Key -and $pending -notmatch $skip) {
                $tech = $stack[0]
                $rows += [pscustomobject]@{ file = $file; tech = $tech; key = $pending; per = [double]$v
                    lvlA = $(if ($la.ContainsKey($tech)) { $la[$tech] } else { 0 }); lvlB = $(if ($lb.ContainsKey($tech)) { $lb[$tech] } else { 0 }) }
            }
            $pending = ''; continue
        }
        if ($v -match '^[A-Za-z_]') { $pending = $v }
    }
}
Write-Output "save: $($save.Name)"
$rows | Where-Object { $_.lvlA -gt 0 -or $_.lvlB -gt 0 } | Sort-Object key, tech |
    Format-Table file, tech, key, per, lvlA, lvlB -AutoSize | Out-String -Width 300
Write-Output '== totals (per * level)'
$rows | Group-Object key | ForEach-Object {
    [pscustomobject]@{ key = $_.Name
        A = [math]::Round(($_.Group | ForEach-Object { $_.per * $_.lvlA } | Measure-Object -Sum).Sum, 3)
        B = [math]::Round(($_.Group | ForEach-Object { $_.per * $_.lvlB } | Measure-Object -Sum).Sum, 3) }
} | Format-Table -AutoSize | Out-String -Width 200
