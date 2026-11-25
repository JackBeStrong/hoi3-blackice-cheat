# Finds mod events/decisions whose trigger/allow checks a tech granted by event 9996 -> reports/tech_events.csv
$m = 'C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1'
$enc = [Text.Encoding]::GetEncoding(28591)

$techs = @{}
Import-Csv (Join-Path $PSScriptRoot 'data\techs.csv') | ForEach-Object { $techs[$_.Name] = $_.Folder }

function Get-Block([string]$body, [string]$key) {
    $mm = [regex]::Match($body, '(?m)^\s*' + $key + '\s*=\s*\{')
    if (-not $mm.Success) { return '' }
    $i = $mm.Index + $mm.Length; $d = 1; $s = $i
    while ($d -gt 0 -and $i -lt $body.Length) {
        if ($body[$i] -eq '{') { $d++ } elseif ($body[$i] -eq '}') { $d-- }
        $i++
    }
    return $body.Substring($s, $i - $s - 1)
}

$rows = New-Object System.Collections.Generic.List[object]
$files = @(Get-ChildItem (Join-Path $m 'events') -Filter *.txt) + @(Get-ChildItem (Join-Path $m 'decisions') -Filter *.txt)
foreach ($f in $files) {
    $text = [IO.File]::ReadAllText($f.FullName, $enc) -replace '#[^\r\n]*', ''
    $isDecision = $f.DirectoryName -like '*decisions'
    # split into top-level blocks (events) or second-level blocks (decisions)
    $depth = 0; $start = -1; $blocks = New-Object System.Collections.Generic.List[string]
    $target = if ($isDecision) { 1 } else { 0 }
    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($c -eq '{') {
            if ($depth -eq $target) {
                $ls = $text.LastIndexOfAny([char[]]"`n", [Math]::Max(0, $i - 1)); $start = $ls + 1
            }
            $depth++
        } elseif ($c -eq '}') {
            $depth--
            if ($depth -eq $target -and $start -ge 0) { $blocks.Add($text.Substring($start, $i - $start + 1)); $start = -1 }
        }
    }
    foreach ($b in $blocks) {
        $name = ([regex]::Match($b, '^\s*(\w+)\s*=')).Groups[1].Value
        $id = ([regex]::Match($b, '(?m)^\s*id\s*=\s*(\d+)')).Groups[1].Value
        $title = ([regex]::Match($b, '(?m)^\s*title\s*=\s*"?([^"\r\n]*)')).Groups[1].Value
        $triggeredOnly = $b -match 'is_triggered_only\s*=\s*yes'
        $cond = if ($isDecision) { (Get-Block $b 'potential') + ' ' + (Get-Block $b 'allow') } else { Get-Block $b 'trigger' }
        if (-not $cond) { continue }
        $hit = [regex]::Matches($cond, '\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(\d+)\b') |
            Where-Object { $techs.ContainsKey($_.Groups[1].Value) } |
            ForEach-Object { $_.Groups[1].Value + '=' + $_.Groups[2].Value } | Select-Object -Unique
        if (-not $hit) { continue }
        $tagOmg = $cond -match 'tag\s*=\s*OMG'
        $kind = if ($isDecision) { 'decision' } elseif ($triggeredOnly) { 'triggered-only' } else { 'mtth' }
        $rows.Add([pscustomobject]@{
            File = $f.Name; Kind = $kind; Id = $(if ($id) { $id } else { $name }); Title = $title; OMG = $tagOmg
            Techs = ($hit -join ' ')
            Effects = (([regex]::Matches($b, '\b(load_oob|add_country_modifier|set_country_flag|country_event|activate_unit_type|build_core|money|supplies|add_building)\b') | ForEach-Object { $_.Value } | Select-Object -Unique) -join ' ')
        })
    }
}
$rows | Export-Csv (Join-Path $PSScriptRoot 'reports\tech_events.csv') -NoTypeInformation
"total: $($rows.Count)"
$rows | Group-Object File | Sort-Object Count -Descending | ForEach-Object { '{0,-40} {1}' -f $_.Name, $_.Count }
