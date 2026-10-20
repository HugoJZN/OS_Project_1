# Generate-SecurityReport.ps1 - Partie 5 : rapport de securite (HTML) + journal
$base       = "C:\PatchManagement"
$sysCsv     = "$base\inventory.csv"
$compCsv    = "$base\ComplianceReport.csv"
$htmlOutput = "$base\SecurityReport.html"
$logFile    = "$base\PatchManager.log"

# Journal : format "date ; machine ; evenement"
function Write-Log {
    param([string]$Machine, [string]$Event)
    $stamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    Add-Content -Path $logFile -Value "$stamp ; $Machine ; $Event" -Encoding UTF8
}

function Enc {
    param($Value)
    if ($null -eq $Value -or "$Value" -eq "") { return "-" }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

Write-Log "PC-ADMIN" "Debut de la generation du rapport de securite"

foreach ($f in @($sysCsv, $compCsv)) {
    if (-not (Test-Path $f)) {
        Write-Log "PC-ADMIN" "ERREUR : fichier $f introuvable"
        Write-Error "Fichier $f introuvable : lancez d'abord Get-SystemInventory.ps1 puis Get-ComplianceReport.ps1"
        exit
    }
}

$sysData  = @(Import-Csv -Path $sysCsv)
$compData = @(Import-Csv -Path $compCsv)
$reportDate = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$sysByName = @{}
foreach ($s in $sysData) { $sysByName[$s.Poste] = $s }

$total        = $compData.Count
$inaccessible = @($compData | Where-Object { $_.Etat -eq "INACCESSIBLE" }).Count
$conformes    = @($compData | Where-Object { $_.Etat -eq "CONFORME" }).Count
$nonConformes = @($compData | Where-Object { $_.Etat -eq "NON CONFORME" }).Count
$accessibles  = $total - $inaccessible

$totalMissing = 0
foreach ($r in $compData) {
    $n = 0
    if ([int]::TryParse([string]$r.KB_Manquantes, [ref]$n)) { $totalMissing += $n }
}

if (($conformes + $nonConformes) -gt 0) {
    $rate = [math]::Round(100 * $conformes / ($conformes + $nonConformes), 1)
}
else {
    $rate = 0
}

$rows = New-Object System.Collections.Generic.List[string]
foreach ($r in $compData) {
    $s = $sysByName[$r.Poste]
    $winVer = "-"; $boot = "-"; $wu = "-"
    if ($s) {
        $winVer = "$($s.Windows) $($s.VersionWindows)".Trim()
        $boot   = $s.DernierDemarrage
        if ($s.ServiceWU) { $wu = $s.ServiceWU } else { $wu = $s.WindowsUpdateService }
    }

    if ($r.Etat -eq "INACCESSIBLE") { $access = "Non" } else { $access = "Oui" }

    if ($r.Etat -eq "CONFORME") { $cls = "ok" }
    elseif ($r.Etat -eq "NON CONFORME") { $cls = "ko" }
    else { $cls = "na" }

    $rows.Add("<tr><td>$(Enc $r.Poste)</td><td>$(Enc $r.AdresseIP)</td><td>$access</td><td>$(Enc $winVer)</td><td>$(Enc $boot)</td><td>$(Enc $wu)</td><td>$(Enc $r.KB_Requises)</td><td>$(Enc $r.KB_Manquantes)</td><td>$(Enc $r.Liste_Manques)</td><td class=""$cls"">$(Enc $r.Etat)</td><td>$(Enc $r.DateControle)</td></tr>")

    Write-Log $r.Poste "Etat de conformite : $($r.Etat) (KB manquants : $($r.KB_Manquantes))"
}

# ---- Postes necessitant une intervention ----
$todo = New-Object System.Collections.Generic.List[string]
foreach ($r in $compData) {
    if ($r.Etat -eq "NON CONFORME") {
        $todo.Add("<tr><td>$(Enc $r.Poste)</td><td>$(Enc $r.AdresseIP)</td><td class=""ko"">NON CONFORME</td><td>Installer les correctifs manquants : $(Enc $r.Liste_Manques)</td></tr>")
    }
    elseif ($r.Etat -eq "INACCESSIBLE") {
        $todo.Add("<tr><td>$(Enc $r.Poste)</td><td>$(Enc $r.AdresseIP)</td><td class=""na"">INACCESSIBLE</td><td>Verifier que le poste est allume, joignable sur le reseau et que WinRM est actif</td></tr>")
    }
}

# ---- Construction du HTML ----
$css = @'
body { font-family: Arial, sans-serif; margin: 20px; background: #f4f6f9; color: #333; }
.container { background: #fff; padding: 25px; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
h1, h2 { color: #0056b3; border-bottom: 2px solid #0056b3; padding-bottom: 5px; }
table { width: 100%; border-collapse: collapse; margin: 15px 0 30px 0; font-size: 0.9em; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background: #0056b3; color: #fff; }
tr:nth-child(even) { background: #f9f9f9; }
.cards { display: flex; flex-wrap: wrap; gap: 12px; margin: 15px 0 30px 0; }
.card { flex: 1 1 140px; border: 1px solid #ddd; border-radius: 6px; padding: 12px; text-align: center; }
.card b { display: block; font-size: 1.8em; color: #0056b3; }
td.ok { background: #d4edda; color: #155724; font-weight: bold; }
td.ko { background: #f8d7da; color: #721c24; font-weight: bold; }
td.na { background: #fff3cd; color: #856404; font-weight: bold; }
.footer { margin-top: 30px; font-size: 0.85em; color: #666; text-align: center; border-top: 1px solid #ddd; padding-top: 10px; }
'@

$h = New-Object System.Collections.Generic.List[string]
$h.Add('<!DOCTYPE html>')
$h.Add('<html lang="fr"><head><meta charset="utf-8">')
$h.Add('<title>Rapport de s&eacute;curit&eacute; - Patch Management</title>')
$h.Add("<style>$css</style></head><body><div class=""container"">")
$h.Add('<h1>Rapport de s&eacute;curit&eacute; et de conformit&eacute; du parc</h1>')
$h.Add("<p><strong>Date de g&eacute;n&eacute;ration :</strong> $reportDate</p>")

$h.Add('<h2>1. Synth&egrave;se globale</h2>')
$h.Add('<div class="cards">')
$h.Add("<div class=""card""><b>$total</b>Postes</div>")
$h.Add("<div class=""card""><b>$accessibles</b>Accessibles</div>")
$h.Add("<div class=""card""><b>$inaccessible</b>Inaccessibles</div>")
$h.Add("<div class=""card""><b>$conformes</b>Conformes</div>")
$h.Add("<div class=""card""><b>$nonConformes</b>Non conformes</div>")
$h.Add("<div class=""card""><b>$totalMissing</b>KB manquants</div>")
$h.Add("<div class=""card""><b>$rate %</b>Taux de conformit&eacute;</div>")
$h.Add('</div>')

$h.Add('<h2>2. D&eacute;tail par poste</h2>')
$h.Add('<table><tr><th>Poste</th><th>IP</th><th>Accessible</th><th>Version Windows</th><th>Dernier d&eacute;marrage</th><th>Service Windows Update</th><th>KB requis</th><th>KB manquants</th><th>Liste des KB manquants</th><th>&Eacute;tat</th><th>Date du contr&ocirc;le</th></tr>')
foreach ($line in $rows) { $h.Add($line) }
$h.Add('</table>')

$h.Add('<h2>3. Postes n&eacute;cessitant une intervention</h2>')
if ($todo.Count -gt 0) {
    $h.Add('<table><tr><th>Poste</th><th>IP</th><th>&Eacute;tat</th><th>Action recommand&eacute;e</th></tr>')
    foreach ($line in $todo) { $h.Add($line) }
    $h.Add('</table>')
}
else {
    $h.Add('<p>Aucune intervention n&eacute;cessaire : tous les postes sont conformes.</p>')
}

$h.Add('<div class="footer">Projet Patch Management PowerShell - rapport g&eacute;n&eacute;r&eacute; automatiquement</div>')
$h.Add('</div></body></html>')

($h -join "`n") | Out-File -FilePath $htmlOutput -Encoding utf8

Write-Log "PC-ADMIN" "Rapport HTML genere : $htmlOutput (total=$total, conformes=$conformes, non conformes=$nonConformes, inaccessibles=$inaccessible, taux=$rate %)"

Write-Host "Rapport HTML genere : $htmlOutput" -ForegroundColor Green
Write-Host "Journal             : $logFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Synthese : $total postes | $accessibles accessibles | $conformes conformes | $nonConformes non conformes | $inaccessible inaccessibles | taux $rate %" -ForegroundColor Yellow

Start-Process $htmlOutput
