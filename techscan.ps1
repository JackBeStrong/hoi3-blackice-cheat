# Scans every BlackICE tech definition and classifies it (OK / GATED / NEVER / EXCL?) -> data/techs.csv
$d = 'C:\Users\jack\games\Hearts of Iron 3\tfh\mod\BlackICE 15.1\technologies'
$enc = [Text.Encoding]::GetEncoding(28591)
$rows = New-Object System.Collections.Generic.List[object]

foreach ($file in Get-ChildItem $d -Filter *.txt) {
    $lines = [IO.File]::ReadAllLines($file.FullName, $enc)
    $depth = 0; $name = $null; $buf = $null
    foreach ($raw in $lines) {
        $x = ($raw -replace '#.*$', '')
        if ($depth -eq 0 -and $x -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{') {
            $name = $matches[1]; $buf = New-Object System.Text.StringBuilder
        }
        if ($null -ne $name) { [void]$buf.AppendLine($x) }
        $depth += ([regex]::Matches($x, '\{').Count - [regex]::Matches($x, '\}').Count)
        if ($depth -eq 0 -and $null -ne $name) {
            $body = $buf.ToString()
            $allow = ''
            $m = [regex]::Match($body, 'allow\s*=\s*\{')
            if ($m.Success) {
                $i = $m.Index + $m.Length; $dd = 1; $s = $i
                while ($dd -gt 0 -and $i -lt $body.Length) {
                    if ($body[$i] -eq '{') { $dd++ } elseif ($body[$i] -eq '}') { $dd-- }
                    $i++
                }
                $allow = ($body.Substring($s, $i - $s - 1) -replace '\s+', ' ').Trim()
            }
            $max = ([regex]::Match($body, 'max_level\s*=\s*(\d+)')).Groups[1].Value
            $folder = ([regex]::Match($body, 'folder\s*=\s*(\w+)')).Groups[1].Value
            $year = ([regex]::Match($body, 'start_year\s*=\s*(\d+)')).Groups[1].Value
            $isTech = $body -match 'folder\s*='
            if ($isTech) {
                $cat = 'OK'
                if ($allow -match 'impossible|always\s*=\s*no') { $cat = 'NEVER' }
                elseif ($allow -match 'has_country_flag|has_global_flag|\btag\s*=|has_country_modifier|government|ideology') { $cat = 'GATED' }
                elseif ($allow -match 'NOT\s*=\s*\{\s*\w+\s*=\s*1\s*\}' -and $allow -notmatch 'NOT\s*=\s*\{\s*' + $name + '\s*=') { $cat = 'EXCL?' }
                if ($name -match '_hidden$') { $cat = 'HIDDEN' }
                $rows.Add([pscustomobject]@{ Cat = $cat; Name = $name; Max = $max; Year = $year; Folder = $folder; File = $file.Name; Allow = $allow })
            }
            $name = $null
        }
    }
}

$rows | Export-Csv (Join-Path $PSScriptRoot 'data\techs.csv') -NoTypeInformation
$rows | Group-Object Cat | % { '{0}: {1}' -f $_.Name, $_.Count }
'--- folders ---'
$rows | Group-Object Folder | % { '{0}: {1}' -f $_.Name, $_.Count }
'--- NEVER / GATED / EXCL? / HIDDEN ---'
$rows | ? { $_.Cat -ne 'OK' } | Sort-Object Cat, Name | % {
    $a = $_.Allow; if ($a.Length -gt 140) { $a = $a.Substring(0, 140) + '...' }
    '{0,-7} {1,-45} [{2}] {3}' -f $_.Cat, $_.Name, $_.Folder, $a
}
