# Get-PatchInventory.ps1 - Partie 3 : inventaire des correctifs
$base          = "C:\PatchManagement"
$computersFile = "$base\computers.txt"
$csvOutput     = "$base\PatchesInventory.csv"

if (-not (Test-Path $computersFile)) {
    Write-Error "Fichier $computersFile introuvable !"
    exit
}

$cred        = $null
$all         = New-Object System.Collections.Generic.List[object]
$unreachable = @()
$sessOpt     = New-PSSessionOption -OpenTimeout 10000 -OperationTimeout 60000

$collect = {
    Get-HotFix | Select-Object HotFixID, Description, InstalledOn, InstalledBy
}

foreach ($line in (Get-Content $computersFile)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts    = $line -split ";"
    $hostname = $parts[0].Trim()
    $ip       = $parts[1].Trim()

    Write-Host "Recuperation des correctifs sur $hostname ($ip)..." -ForegroundColor Cyan

    try {
        if ($hostname -eq $env:COMPUTERNAME) {
            $hotfixes = @(& $collect)
        }
        else {
            if (-not $cred) { $cred = Get-Credential -Message "Compte administrateur des postes distants" }
            $session = New-PSSession -ComputerName $ip -Credential $cred -SessionOption $sessOpt -ErrorAction Stop
            try {
                $hotfixes = @(Invoke-Command -Session $session -ScriptBlock $collect -ErrorAction Stop)
            }
            finally {
                Remove-PSSession $session
            }
        }

        foreach ($h in $hotfixes) {
            if ($h.InstalledBy) { $by = [string]$h.InstalledBy } else { $by = "N/A" }
            $all.Add([PSCustomObject]@{
                Poste       = $hostname
                AdresseIP   = $ip
                KB          = $h.HotFixID
                Description = $h.Description
                InstalledOn = $h.InstalledOn
                InstalledBy = $by
            })
        }
    }
    catch {
        Write-Warning "Poste $hostname ($ip) ignore : $($_.Exception.Message)"
        $unreachable += "$hostname ($ip)"
    }
}

if ($all.Count -eq 0) {
    Write-Warning "Aucun correctif collecte : PatchesInventory.csv non genere."
    exit
}

# Tri : poste (A-Z) puis date d'installation decroissante
$sorted = $all | Sort-Object @{Expression = 'Poste'; Descending = $false}, @{Expression = 'InstalledOn'; Descending = $true}

$sorted | Select-Object Poste, AdresseIP, KB, Description,
    @{N = 'DateInstallation'; E = { if ($_.InstalledOn) { $_.InstalledOn.ToString('dd/MM/yyyy') } else { 'N/A' } }},
    InstalledBy |
    Export-Csv -Path $csvOutput -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Green
Write-Host "     SYNTHESE DE L'INVENTAIRE DES CORRECTIFS" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green

foreach ($g in ($sorted | Group-Object Poste)) {
    $latest = $g.Group | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
    Write-Host ""
    Write-Host "Poste : $($g.Name)" -ForegroundColor Yellow
    Write-Host "  - Nombre total de correctifs recenses : $($g.Count)"
    if ($latest) {
        Write-Host "  - Date du correctif le plus recent    : $($latest.InstalledOn.ToString('dd/MM/yyyy'))"
        Write-Host "  - KB du dernier correctif installe    : $($latest.KB)"
    }
}

if ($unreachable.Count -gt 0) {
    Write-Host ""
    Write-Host "Postes ignores (inaccessibles) : $($unreachable -join ', ')" -ForegroundColor Red
}

Write-Host ""
Write-Host "Fichier genere : $csvOutput" -ForegroundColor Cyan
