# Gestion des mises a jour - Patch Management (PowerShell)

Projet PowerShell : inventaire, controle de conformite et notification pour un petit parc Windows, administre a distance via PowerShell Remoting (WinRM).

**Auteurs :** Enzo JUZYNA, Hugo JUZYNA - Promo 2028 - annee 2026/2027
**Enseignant :** Salim Benayoune

## Environnement de test

- 2 machines virtuelles Windows 11 Pro (VMware, reseau NAT 192.168.176.0/24)
- PC-ADMIN (192.168.176.128) : poste d'administration, execute les scripts
- PC01 (192.168.176.129) : poste distant administre
- Windows PowerShell 5.1, WinRM sur HTTP (port 5985)

## Scripts

| Script | Partie | Role | Fichiers produits |
|---|---|---|---|
| `Get-SystemInventory.ps1` | 2 | Inventaire systeme de chaque poste (OS, BIOS, RAM, disque, service Windows Update) | `inventory.csv` |
| `Get-PatchInventory.ps1` | 3 | Liste des correctifs installes (`Get-HotFix`) | `PatchesInventory.csv` |
| `Get-ComplianceReport.ps1` | 4 | Compare les correctifs installes aux KB requis | `ComplianceReport.csv` |
| `Generate-SecurityReport.ps1` | 5 | Rapport HTML de securite et journal | `SecurityReport.html`, `PatchManager.log` |
| `Send-Notification.ps1` | 6 | Envoie un mail seulement si un poste est NON CONFORME ou INACCESSIBLE | `PatchManager.log` |

Les postes inaccessibles sont signales sans interrompre l'execution.

## Fichiers d'entree (a creer dans `C:\PatchManagement`)

- `computers.txt` : un poste par ligne, au format `NOM;ADRESSE_IP`
  ```
  PC-ADMIN;192.168.176.128
  PC01;192.168.176.129
  ```
- `required-patches.txt` : un identifiant KB par ligne (correctifs obligatoires)

## Utilisation

Dans une console PowerShell **administrateur**, depuis `C:\PatchManagement` :

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Get-SystemInventory.ps1
.\Get-PatchInventory.ps1
.\Get-ComplianceReport.ps1
.\Generate-SecurityReport.ps1
.\Send-Notification.ps1
```

Les identifiants du poste distant sont demandes une fois par execution (`Get-Credential`) et ne sont jamais ecrits dans les scripts.

Pour tester l'envoi de mail sans vrai serveur, utiliser smtp4dev sur `localhost:25` (valeur par defaut du script). Pour un autre serveur :

```powershell
.\Send-Notification.ps1 -SmtpServer smtp.exemple.com -Port 587 -UseSsl -From a@exemple.com -To b@exemple.com
```

## Securite

- `TrustedHosts` limite a l'adresse de PC01
- Regle de pare-feu WinRM de PC01 limitee a l'adresse de PC-ADMIN
- Droits NTFS du dossier `C:\PatchManagement` restreints (administrateurs et SYSTEM)
- Authentification Basic/Digest desactivee cote client
- Compte de service `svc-patch` a moindres privileges (membre de `Remote Management Users`)
- Aucun mot de passe en clair dans les scripts

## Notes

- Les scripts sont ecrits en ASCII pour eviter les problemes d'encodage de Windows PowerShell 5.1.
- Le journal `PatchManager.log` suit le format `date ; machine ; evenement`.
- Les fichiers generes (CSV, HTML, journal) et les fichiers d'identifiants ne sont pas versionnes.
