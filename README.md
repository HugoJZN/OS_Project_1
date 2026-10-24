# Gestion des mises a jour - Patch Management (PowerShell)

Projet PowerShell : inventaire, controle de conformite et notification pour un petit parc Windows, administre a distance via PowerShell Remoting (WinRM).

**Auteurs :** Enzo JUZYNA, Hugo JUZYNA - Promo 2028 - annee 2026/2027
**Enseignant :** Salim Benayoune
**Vidéo :** https://drive.google.com/file/d/1zwJYuH_oA5gq6zI8J3T3ySyl5_QaIl2P/view?usp=sharing

## Environnement de test

- 2 machines virtuelles Windows 11 Pro (VMware, reseau NAT 192.168.176.0/24)
- PC-ADMIN (192.168.176.128) : poste d'administration, execute les scripts
- PC01 (192.168.176.129) : poste distant administre
- Windows PowerShell 5.1, WinRM sur HTTP (port 5985)

## Scripts

| Script | Partie | Role | Fichiers produits |
|---|---|---|---|
| Get-SystemInventory.ps1 | 2 | Inventaire systeme de chaque poste | inventory.csv |
| Get-PatchInventory.ps1 | 3 | Liste des correctifs installes (Get-HotFix) | PatchesInventory.csv |
| Get-ComplianceReport.ps1 | 4 | Compare les correctifs installes aux KB requis | ComplianceReport.csv |
| Generate-SecurityReport.ps1 | 5 | Rapport HTML de securite et journal | SecurityReport.html, PatchManager.log |
| Send-Notification.ps1 | 6 | Mail seulement si un poste est NON CONFORME ou INACCESSIBLE | PatchManager.log |

## Fichiers d'entree (dans C:\PatchManagement)

- computers.txt : un poste par ligne, au format NOM;ADRESSE_IP
- required-patches.txt : un identifiant KB par ligne

## Utilisation

Dans une console PowerShell administrateur, depuis C:\PatchManagement :

    Set-ExecutionPolicy -Scope Process Bypass
    .\Get-SystemInventory.ps1
    .\Get-PatchInventory.ps1
    .\Get-ComplianceReport.ps1
    .\Generate-SecurityReport.ps1
    .\Send-Notification.ps1

Les identifiants du poste distant sont demandes a chaque execution (Get-Credential), jamais ecrits dans les scripts. Pour tester l'envoi de mail : smtp4dev sur localhost:25 (valeur par defaut).

## Securite

- TrustedHosts limite a l'adresse de PC01
- Pare-feu WinRM de PC01 limite a l'adresse de PC-ADMIN
- Droits NTFS de C:\PatchManagement restreints (administrateurs et SYSTEM)
- Authentification Basic/Digest desactivee cote client
- Compte de service svc-patch a moindres privileges
- Aucun mot de passe en clair dans les scripts
