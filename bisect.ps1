# Binary search for the tech(s) that inflate unit cost.
# Builds test copies of a save in which a chosen set of techs for country A is set to country B's levels.
#
#   1) list the techs where A is ahead of B:
#        powershell -NoProfile -ExecutionPolicy Bypass -File bisect.ps1 -Init
#      writes data\bisect\all.txt (one tech per line: name<TAB>levelA<TAB>levelB<TAB>folder)
#   2) split a list in two and build one test save per half:
#        powershell -NoProfile -ExecutionPolicy Bypass -File bisect.ps1 -Split all
#      writes data\bisect\all_1.txt, all_2.txt and saves "TEST all_1.hoi3", "TEST all_2.hoi3"
#   3) load each TEST save in game, read the carrier IC cost, then split whichever half dropped the cost:
#        powershell -NoProfile -ExecutionPolicy Bypass -File bisect.ps1 -Split all_1
#   Optional: -Make <list> builds a single test save from a list without splitting.
#
# The source save is never modified.
#   -Exact       builds "TEST exact": every tech of A set to B's level (also techs where B is ahead)
#   -Only a,b,c  builds "TEST only <first>": just the listed techs of A set to B's level
param(
    [string]$Save = 'Republic_of China1937_11_08_13.hoi3',
    [string]$A = 'CHI',
    [string]$B = 'JAP',
    [switch]$Init,
    [string]$Split = '',
    [string]$Make = '',
    [switch]$Exact,
    [string[]]$Only = @(),
    [string]$Name = '',
    [int]$SetTo = -1   # with -Only: set the techs to this level instead of country B's level
)
# with -File, "-Only a,b,c" arrives as one string; split it here
$Only = @($Only | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
$ErrorActionPreference = 'Stop'
$dir  = 'C:\Users\jack\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 15.1\save games'
$work = Join-Path $PSScriptRoot 'data\bisect'
New-Item -ItemType Directory -Force $work | Out-Null
$enc  = [Text.Encoding]::GetEncoding(1252)
$src  = Join-Path $dir $Save
$t    = [IO.File]::ReadAllText($src, $enc)

function Get-Block([string]$tag) {
    $i = $t.IndexOf("`n$tag=")
    if ($i -lt 0) { throw "country $tag not found in $Save" }
    $j = $t.IndexOf("`n}", $i + 5)
    return @{ start = $i; end = $j; text = $t.Substring($i, $j - $i) }
}
function Get-Levels([string]$text) {
    $h = @{}
    foreach ($m in [regex]::Matches($text, '(?m)^\t\t(\w+)=\{(\d+) [\d\.]+ [\d\.]+\}')) {
        if (-not $h.ContainsKey($m.Groups[1].Value)) { $h[$m.Groups[1].Value] = [int]$m.Groups[2].Value }
    }
    return $h
}

function Build-Test([string]$name, [string[]]$techs) {
    $ba = Get-Block $A
    $lb = Get-Levels (Get-Block $B).text
    $text = $ba.text
    $n = 0
    foreach ($tech in $techs) {
        $target = if ($SetTo -ge 0) { $SetTo } elseif ($lb.ContainsKey($tech)) { $lb[$tech] } else { 0 }
        $re = "(?m)^(\t\t$tech=\{)\d+( [\d\.]+ [\d\.]+\})"
        if ([regex]::IsMatch($text, $re)) {
            $text = [regex]::Replace($text, $re, "`${1}$target`${2}", 1); $n++
        }
    }
    $out = Join-Path $dir "TEST $name.hoi3"
    [IO.File]::WriteAllText($out, $t.Substring(0, $ba.start) + $text + $t.Substring($ba.end), $enc)
    $what = if ($SetTo -ge 0) { "level $SetTo" } else { "$B levels" }
    Write-Output ("  TEST {0}.hoi3  ({1} techs set to {2})" -f $name, $n, $what)
}

function Read-List([string]$name) {
    $p = Join-Path $work "$name.txt"
    if (-not (Test-Path $p)) { throw "list $p not found" }
    return @(Get-Content $p | Where-Object { $_ -and -not $_.StartsWith('#') })
}

if ($Init) {
    $la = Get-Levels (Get-Block $A).text
    $lb = Get-Levels (Get-Block $B).text
    $folder = @{}
    $csv = Join-Path $PSScriptRoot 'data\techs.csv'
    if (Test-Path $csv) {
        Import-Csv $csv -Header status, name, max, year, folder, file, allow | ForEach-Object { $folder[$_.name] = $_.folder }
    }
    $rows = foreach ($k in $la.Keys) {
        $vb = if ($lb.ContainsKey($k)) { $lb[$k] } else { 0 }
        if ($la[$k] -gt $vb) {
            $f = if ($folder.ContainsKey($k)) { $folder[$k] } else { 'zz_unknown' }
            [pscustomobject]@{ name = $k; a = $la[$k]; b = $vb; folder = $f }
        }
    }
    # sort by folder so each half keeps related techs together
    $rows = $rows | Sort-Object folder, name
    $rows | ForEach-Object { "{0}`t{1}`t{2}`t{3}" -f $_.name, $_.a, $_.b, $_.folder } | Set-Content (Join-Path $work 'all.txt')
    Write-Output "techs where $A is ahead of ${B}: $($rows.Count)  -> data\bisect\all.txt"
    $rows | Group-Object folder | Sort-Object Name | ForEach-Object { "  {0,-28} {1}" -f $_.Name, $_.Count }
    Write-Output 'building control save (every one of these techs set to JAP level):'
    Build-Test 'all' ($rows | ForEach-Object { $_.name })
}

if ($Split) {
    $lines = Read-List $Split
    $half = [math]::Ceiling($lines.Count / 2)
    $p1 = $lines[0..($half - 1)]
    $p2 = if ($lines.Count -gt $half) { $lines[$half..($lines.Count - 1)] } else { @() }
    $p1 | Set-Content (Join-Path $work "${Split}_1.txt")
    $p2 | Set-Content (Join-Path $work "${Split}_2.txt")
    Write-Output "split $Split ($($lines.Count)) -> ${Split}_1 ($($p1.Count)), ${Split}_2 ($($p2.Count))"
    foreach ($part in @(@("${Split}_1", $p1), @("${Split}_2", $p2))) {
        $folders = ($part[1] | ForEach-Object { ($_ -split "`t")[3] } | Sort-Object -Unique) -join ', '
        Write-Output "  $($part[0]) folders: $folders"
        Build-Test $part[0] ($part[1] | ForEach-Object { ($_ -split "`t")[0] })
    }
}

if ($Make) {
    $lines = Read-List $Make
    Build-Test $Make ($lines | ForEach-Object { ($_ -split "`t")[0] })
}

if ($Exact) {
    $la = Get-Levels (Get-Block $A).text
    $lb = Get-Levels (Get-Block $B).text
    $diff = @($la.Keys | Where-Object { $la[$_] -ne $(if ($lb.ContainsKey($_)) { $lb[$_] } else { 0 }) })
    $behind = @($diff | Where-Object { $la[$_] -lt $lb[$_] })
    Write-Output "techs that differ: $($diff.Count) (A ahead: $($diff.Count - $behind.Count), A behind: $($behind.Count))"
    Build-Test 'exact' $diff
}

if ($Only.Count) {
    $la = Get-Levels (Get-Block $A).text
    $lb = Get-Levels (Get-Block $B).text
    foreach ($o in $Only) { Write-Output ("  {0,-40} {1} {2} -> {3}" -f $o, $A, $la[$o], $(if ($lb.ContainsKey($o)) { $lb[$o] } else { 0 })) }
    $label = if ($Name) { $Name } else { "only $($Only[0])" }
    Build-Test $label $Only
}
