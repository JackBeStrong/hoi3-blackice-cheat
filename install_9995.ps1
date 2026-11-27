# Installs cheat event 9995 (naval build time modifiers) into the BlackICE mod.
# - appends ship_build_50/70/85 to common/event_modifiers.txt (if missing)
# - inserts event 9995 into events/PoliticalEvents.txt just before the event 9996 block (gen_event.ps1 rewrites from there down)
# - refreshes the repo copy mod/events/PoliticalEvents_cheats.txt
# Safe to run again: it replaces an existing 9995 block instead of adding a second one.
$ErrorActionPreference = 'Stop'
$mod = 'C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1'
$enc = [Text.Encoding]::GetEncoding(1252)

# --- modifiers
$mf = Join-Path $mod 'common\event_modifiers.txt'
$m = [IO.File]::ReadAllText($mf, $enc)
if ($m -notmatch '(?m)^ship_build_50\s*=') {
    $add = "`r`nship_build_50 = {`r`n`tnaval_build_speed = -0.5`r`n}`r`nship_build_70 = {`r`n`tnaval_build_speed = -0.7`r`n}`r`nship_build_85 = {`r`n`tnaval_build_speed = -0.85`r`n}`r`n"
    [IO.File]::WriteAllText($mf, $m.TrimEnd() + "`r`n" + $add, $enc)
    'modifiers: added'
} else { 'modifiers: already present' }

# --- event
$ev = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'mod\events\event_9995.txt'), $enc).Trim() -replace '(?<!\r)\n', "`r`n"
$pf = Join-Path $mod 'events\PoliticalEvents.txt'
$t = [IO.File]::ReadAllText($pf, $enc)
$start95 = $t.IndexOf('# Cheat: faster ship building')
$start96 = $t.IndexOf('# Cheat: grant all technology')
if ($start96 -lt 0) { throw 'event 9996 header not found' }
if ($start95 -ge 0) {
    $t = $t.Substring(0, $start95).TrimEnd() + "`r`n`r`n" + $ev + "`r`n`r`n" + $t.Substring($start96)
    'event 9995: replaced'
} else {
    $t = $t.Substring(0, $start96).TrimEnd() + "`r`n`r`n" + $ev + "`r`n`r`n" + $t.Substring($start96)
    'event 9995: inserted'
}
[IO.File]::WriteAllText($pf, $t, $enc)

'braces open/close: ' + ([regex]::Matches($t, '\{').Count) + '/' + ([regex]::Matches($t, '\}').Count)
'id = 9995 count: ' + ([regex]::Matches($t, 'id = 9995\b').Count)

# --- repo copy of the cheat events (from event 9999 to end of file)
$c = $t.IndexOf("`tid = 9999")
$c = $t.LastIndexOf('country_event', $c)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'mod\events\PoliticalEvents_cheats.txt'), $t.Substring($c), $enc)
'repo copy updated'
