# Scans the latest BlackICE save for one country: shipyard techs, shipyard counter variables,
# naval practicals, naval ministers in office and capital shipyards in owned provinces.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File savescan.ps1 [-Tag CHI]
param([string]$Tag = 'CHI')
$dir  = 'C:\Users\jack\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 15.1\save games'
$save = Get-ChildItem $dir -Filter *.hoi3 | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Output "save: $($save.Name)  ($($save.LastWriteTime))"
$t = [IO.File]::ReadAllText($save.FullName, [Text.Encoding]::GetEncoding(1252))
if ($t -match 'date="([^"]+)"') { Write-Output "game date: $($matches[1])" }

# --- country block
$i = $t.IndexOf("`n$Tag=")
$j = $t.IndexOf("`n}", $i + 5)
$c = $t.Substring($i, $j - $i)

Write-Output "`n== techs"
foreach ($n in 'Capital_Ship_Building_Technologies', 'Capital_Ship_Building_Technologies_REVERSE',
               'Medium_Ship_Building_Technologies', 'Medium_Ship_Building_Technologies_REVERSE',
               'Small_Ship_Building_Technologies', 'Small_Ship_Building_Technologies_REVERSE') {
    $m = [regex]::Match($c, "(?m)^\s*$n=\{([^}]*)\}")
    Write-Output ("{0,-45} {1}" -f $n, $m.Groups[1].Value)
}

Write-Output "`n== variables"
foreach ($m in [regex]::Matches($c, '"?(capital_ship_shipyard[\w]*|national_focus|\w*_minister_\d+)"?\s*=\s*([\-\d\.]+)')) {
    if ($m.Groups[1].Value -match 'capital|national_focus|old_admiral|battle_fleet|decisive') { Write-Output ("{0,-55} {1}" -f $m.Groups[1].Value, $m.Groups[2].Value) }
}

Write-Output "`n== practicals"
foreach ($m in [regex]::Matches($c, '(?m)^\s*(carrier_practical|capitalship_practical|naval_engineering)=([\d\.]+)')) { Write-Output ("{0,-25} {1}" -f $m.Groups[1].Value, $m.Groups[2].Value) }

Write-Output "`n== ministers in office"
foreach ($p in 'head_of_state', 'head_of_government', 'armament_minister', 'chief_of_navy') {
    $m = [regex]::Match($c, "(?m)^\s*$p=\s*\{\s*id=\s*\{\s*id=(\d+)")
    if (-not $m.Success) { $m = [regex]::Match($c, "(?m)^\s*$p=(\d+)") }
    Write-Output ("{0,-20} {1}" -f $p, $m.Groups[1].Value)
}

Write-Output "`n== provinces with capital shipyards (owner $Tag)"
# province blocks start with "<id>=" on its own line; the building is stored as "capital_ship_shipyard= { <max> <current> }"
$heads = [regex]::Matches($t, '(?m)^(\d+)=\s*$')
$total = 0
for ($k = 0; $k -lt $heads.Count; $k++) {
    $s = $heads[$k].Index
    $e = if ($k + 1 -lt $heads.Count) { $heads[$k + 1].Index } else { $t.Length }
    $chunk = $t.Substring($s, [Math]::Min($e - $s, 20000))
    $hdr = ($chunk -split 'history=')[0]
    if ($hdr -notmatch 'owner="' + $Tag + '"') { continue }
    $cm = [regex]::Match($hdr, 'capital_ship_shipyard=\s*\{\s*([\d\.]+)\s+([\d\.]+)\s*\}')
    if (-not $cm.Success) { continue }
    $ctrl = ''; if ($hdr -match 'controller="(\w+)"') { $ctrl = $matches[1] }
    $core = if ($hdr -match 'core="' + $Tag + '"') { 'core' } else { 'NOT core' }
    Write-Output ("{0,-6} max={1} current={2} controller={3} {4}" -f $heads[$k].Groups[1].Value, $cm.Groups[1].Value, $cm.Groups[2].Value, $ctrl, $core)
    $total += [double]$cm.Groups[1].Value
}
Write-Output "total capital shipyard levels: $total"
