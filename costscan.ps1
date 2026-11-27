# Lists every positive build_cost_ic / build_time effect in the mod's tech files, whatever block it is in,
# together with the tech's level for two countries in the latest save. Used to find what raises unit cost.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File costscan.ps1 [-A CHI] [-B JAP] [-Target regex]
param([string]$A = 'CHI', [string]$B = 'JAP', [string]$Target = '.')
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
            if ($pending -match '^(build_cost_ic|build_time)$' -and [double]$v -gt 0 -and $stack.Count -ge 2) {
                $tech = $stack[0]; $path = ($stack | Select-Object -Skip 1) -join '.'
                if ($path -match $Target) {
                    $rows += [pscustomobject]@{ file = $file; tech = $tech; target = $path; key = $pending; per = [double]$v
                        lvlA = $(if ($la.ContainsKey($tech)) { $la[$tech] } else { 0 }); lvlB = $(if ($lb.ContainsKey($tech)) { $lb[$tech] } else { 0 }) }
                }
            }
            $pending = ''; continue
        }
        if ($v -match '^[A-Za-z_]') { $pending = $v }
    }
}
Write-Output "save: $($save.Name)   positive cost/time effects matching '$Target': $($rows.Count)"
$rows | Where-Object { $_.lvlA -gt 0 -or $_.lvlB -gt 0 } | Sort-Object target, tech |
    Format-Table file, tech, target, key, per, lvlA, lvlB -AutoSize | Out-String -Width 300
'targets: ' + (($rows | Select-Object -ExpandProperty target -Unique | Sort-Object) -join ', ')
