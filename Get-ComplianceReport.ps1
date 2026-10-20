# Get-ComplianceReport.ps1 - Partie 4 : controle de conformite des correctifs requis
$base          = "C:\PatchManagement"
$computersFile = "$base\computers.txt"
$requiredFile  = "$base\required-patches.txt"
$csvOutput     = "$base\ComplianceReport.csv"

$patchesFile = @("$base\PatchesInventory.csv", "$base\Patches Inventory.csv") |
    Where-Object { Test-Path $_ } | Select-Object -First 1

foreach ($f in @($computersFile, $requiredFile)) {
    if (-not (Test-Path $f)) { Write-Error "Fichier $f introuvable !"; exit }
}
if (-not $patchesFile) {
    Write-Error "PatchesInventory.csv introuvable : lancez d'abord Get-PatchInventory.ps1"
    exit
}

$requiredPatches = Get-Content $requiredFile |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim().ToUpper() } |
    Select-Object -Unique

$inventory     = Import-Csv -Path $patchesFile
$checkDateTime = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
$computers     = Get-Content $computersFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$reports         = @()
$accessibleCount = 0
$compliantCount  = 0

foreach ($line in $computers) {
    $parts    = $line -split ";"
    $hostname = $parts[0].Trim()
    $ip       = $parts[1].Trim()

    # Test d'accessibilite WinRM
    $reachable = $true
    try {
        Test-WSMan -ComputerName $ip -ErrorAction Stop | Out-Null
    }
    catch {
        $reachable = $false
    }

    if ($reachable) {
        $accessibleCount++

        $installedPatches = @($inventory |
            Where-Object { ($_.Poste -eq $hostname) -or ($_.HostName -eq $hostname) } |
            ForEach-Object { if ($_.KB) { $_.KB } else { $_.HotFixID } } |
            Where-Object { $_ } |
            ForEach-Object { $_.Trim().ToUpper() })

        if ($installedPatches.Count -eq 0) {
            Write-Warning "$hostname est joignable mais absent de PatchesInventory.csv : relancez Get-PatchInventory.ps1, sinon tous les KB seront comptes manquants."
        }

        $missingKB = @($requiredPatches | Where-Object { $_ -notin $installedPatches })

        if ($missingKB.Count -eq 0) {
            $status     = "CONFORME"
            $missingStr = "Aucun"
            $compliantCount++
        }
        else {
            $status     = "NON CONFORME"
            $missingStr = $missingKB -join "; "
        }

        $reports += [PSCustomObject]@{
            Poste         = $hostname
            AdresseIP     = $ip
            KB_Requises   = $requiredPatches.Count
            KB_Manquantes = $missingKB.Count
            Liste_Manques = $missingStr
            Etat          = $status
            DateControle  = $checkDateTime
        }
    }
    else {
        $reports += [PSCustomObject]@{
            Poste         = $hostname
            AdresseIP     = $ip
            KB_Requises   = $requiredPatches.Count
            KB_Manquantes = "-"
            Liste_Manques = "-"
            Etat          = "INACCESSIBLE"
            DateControle  = $checkDateTime
        }
    }
}

$reports | Export-Csv -Path $csvOutput -NoTypeInformation -Encoding utf8

if ($accessibleCount -gt 0) {
    $complianceRate = [math]::Round(($compliantCount / $accessibleCount) * 100, 2)
}
else {
    $complianceRate = 0
}

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Yellow
Write-Host "         RAPPORT DE CONFORMITE DU PARC" -ForegroundColor Yellow
Write-Host "=======================================================" -ForegroundColor Yellow
Write-Host "Date et heure du controle : $checkDateTime"
Write-Host "Postes accessibles        : $accessibleCount / $($computers.Count)"
Write-Host "Taux global de conformite : $complianceRate %" -ForegroundColor Cyan
Write-Host ""

$reports | Format-Table Poste, AdresseIP, KB_Requises, KB_Manquantes, Etat, Liste_Manques, DateControle -AutoSize
