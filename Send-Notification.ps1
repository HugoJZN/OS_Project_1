# Send-Notification.ps1 - Partie 6 : notification de l'administrateur (mail uniquement si anomalie)
param(
    [string]$SmtpServer     = "localhost",
    [int]$Port              = 25,
    [string]$From           = "patchmanager@lab.local",
    [string]$To             = "admin@entreprise.local",
    [switch]$UseSsl,
    [string]$CredentialFile = "C:\PatchManagement\smtp-cred.xml"
)

$base       = "C:\PatchManagement"
$compCsv    = "$base\ComplianceReport.csv"
$htmlReport = "$base\SecurityReport.html"
$logFile    = "$base\PatchManager.log"

$e = [string][char]0xE9
$o = [string][char]0xF4

function Write-Log {
    param([string]$Machine, [string]$Event)
    $stamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    Add-Content -Path $logFile -Value "$stamp ; $Machine ; $Event" -Encoding UTF8
}

if (-not (Test-Path $compCsv)) {
    Write-Log "PC-ADMIN" "ERREUR ; ComplianceReport.csv introuvable, notification impossible"
    Write-Error "Fichier $compCsv introuvable : lancez d'abord Get-ComplianceReport.ps1"
    exit 1
}

$data         = @(Import-Csv -Path $compCsv)
$nonConformes = @($data | Where-Object { $_.Etat -eq "NON CONFORME" })
$inaccessible = @($data | Where-Object { $_.Etat -eq "INACCESSIBLE" })

if (($nonConformes.Count + $inaccessible.Count) -eq 0) {
    Write-Log "PC-ADMIN" "Aucune anomalie detectee : aucune notification envoyee"
    Write-Host "Aucune anomalie : pas de notification envoyee." -ForegroundColor Green
    exit 0
}

# ---- Construction du message ----
$controlDate = ($data[0].DateControle -split " ")[0]
$subject     = "[PATCH MANAGEMENT] Anomalies d${e}tect${e}es"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Date du contr${o}le : $controlDate")
$lines.Add("")
$lines.Add(("Postes contr${o}l${e}s      : {0}" -f $data.Count))
$lines.Add(("Postes non conformes  : {0}" -f $nonConformes.Count))
$lines.Add(("Postes inaccessibles  : {0}" -f $inaccessible.Count))
$lines.Add("")

foreach ($r in $data) {
    if ($r.Etat -eq "NON CONFORME") {
        $lines.Add("$($r.Poste) : NON CONFORME")
        foreach ($kb in ($r.Liste_Manques -split ";")) {
            if ($kb.Trim()) { $lines.Add("        $($kb.Trim()) manquante") }
        }
        $lines.Add("")
    }
    elseif ($r.Etat -eq "INACCESSIBLE") {
        $lines.Add("$($r.Poste) : INACCESSIBLE")
        $lines.Add("")
    }
}
$lines.Add("Rapport complet en pi${e}ce jointe.")
$body = $lines -join "`r`n"

$mail = @{
    SmtpServer  = $SmtpServer
    Port        = $Port
    From        = $From
    To          = $To
    Subject     = $subject
    Body        = $body
    Encoding    = [System.Text.Encoding]::UTF8
    ErrorAction = "Stop"
}
if ($UseSsl) { $mail["UseSsl"] = $true }
if (Test-Path $htmlReport) { $mail["Attachments"] = $htmlReport }
if (Test-Path $CredentialFile) { $mail["Credential"] = Import-Clixml -Path $CredentialFile }

# ---- Envoi + trace dans le journal ----
try {
    Send-MailMessage @mail -WarningAction SilentlyContinue
    Write-Log "PC-ADMIN" "Notification envoyee a $To"
    Write-Host "Notification envoyee a $To" -ForegroundColor Green
}
catch {
    Write-Log "PC-ADMIN" "ERREUR ; Notification non envoyee ($($_.Exception.Message))"
    Write-Warning "Notification non envoyee : $($_.Exception.Message)"
    exit 1
}
