# Get-SystemInventory.ps1 - Partie 2 : inventaire du parc
$base          = "C:\PatchManagement"
$computersFile = "$base\computers.txt"
$csvOutput     = "$base\inventory.csv"

if (-not (Test-Path $computersFile)) {
    Write-Error "Fichier $computersFile introuvable !"
    exit
}

$cred    = $null
$results = @()
$sessOpt = New-PSSessionOption -OpenTimeout 10000 -OperationTimeout 60000

# Bloc execute sur chaque poste (en local ou a distance), sans variable externe
$collect = {
    $os   = Get-CimInstance Win32_OperatingSystem
    $cs   = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $wu   = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue

    $all   = @(Get-HotFix -ErrorAction SilentlyContinue)
    $dated = @($all | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending)
    if ($dated.Count -gt 0) { $lastDate = $dated[0].InstalledOn.ToString('dd/MM/yyyy') } else { $lastDate = 'Aucune' }

    [PSCustomObject]@{
        Poste            = $env:COMPUTERNAME
        Modele           = $cs.Model
        VersionBIOS      = $bios.SMBIOSBIOSVersion
        Windows          = $os.Caption
        VersionWindows   = $os.Version
        Architecture     = $os.OSArchitecture
        DernierDemarrage = $os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm')
        RAM_GB           = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        DisqueLibre_GB   = [math]::Round($disk.FreeSpace / 1GB, 2)
        NombreMAJ        = $all.Count
        DerniereMAJ      = $lastDate
        ServiceWU        = [string]$wu.Status
    }
}

function New-Row {
    param($Poste, $Ip, $Data, $Etat, $Erreur)
    $na = "-"
    [PSCustomObject]@{
        Poste            = $Poste
        AdresseIP        = $Ip
        Modele           = if ($Data) { $Data.Modele } else { $na }
        VersionBIOS      = if ($Data) { $Data.VersionBIOS } else { $na }
        Windows          = if ($Data) { $Data.Windows } else { $na }
        VersionWindows   = if ($Data) { $Data.VersionWindows } else { $na }
        Architecture     = if ($Data) { $Data.Architecture } else { $na }
        DernierDemarrage = if ($Data) { $Data.DernierDemarrage } else { $na }
        RAM_GB           = if ($Data) { $Data.RAM_GB } else { $na }
        DisqueLibre_GB   = if ($Data) { $Data.DisqueLibre_GB } else { $na }
        NombreMAJ        = if ($Data) { $Data.NombreMAJ } else { $na }
        DerniereMAJ      = if ($Data) { $Data.DerniereMAJ } else { $na }
        ServiceWU        = if ($Data) { $Data.ServiceWU } else { $na }
        Etat             = $Etat
        Erreur           = $Erreur
    }
}

foreach ($line in (Get-Content $computersFile)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts    = $line -split ";"
    $hostname = $parts[0].Trim()
    $ip       = $parts[1].Trim()

    Write-Host "Collecte des donnees pour $hostname ($ip)..." -ForegroundColor Cyan

    try {
        if ($hostname -eq $env:COMPUTERNAME) {
            $d = & $collect
        }
        else {
            if (-not $cred) { $cred = Get-Credential -Message "Compte administrateur des postes distants" }
            $session = New-PSSession -ComputerName $ip -Credential $cred -SessionOption $sessOpt -ErrorAction Stop
            try {
                $d = Invoke-Command -Session $session -ScriptBlock $collect -ErrorAction Stop
            }
            finally {
                Remove-PSSession $session
            }
        }
        $results += New-Row -Poste $d.Poste -Ip $ip -Data $d -Etat "Accessible" -Erreur "Aucune"
    }
    catch {
        Write-Warning "Echec pour $hostname ($ip) : $($_.Exception.Message)"
        $results += New-Row -Poste $hostname -Ip $ip -Data $null -Etat "Inaccessible" -Erreur $_.Exception.Message
    }
}

$results | Export-Csv -Path $csvOutput -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "=== INVENTAIRE DU PARC ===" -ForegroundColor Green
$results | Format-Table Poste, AdresseIP, Windows, Architecture, DernierDemarrage, ServiceWU, Etat -AutoSize
Write-Host "Fichier genere : $csvOutput" -ForegroundColor Cyan
