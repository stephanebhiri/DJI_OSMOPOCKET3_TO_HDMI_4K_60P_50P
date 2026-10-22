# Images prêtes à flasher — Orange Pi 5 Plus

Version `v2.0-orangepi5plus`, construite le 22 octobre 2026 avec les révisions de [`source-lock.txt`](source-lock.txt).

| Fichier | Usage | Résultat |
| --- | --- | --- |
| `OSMO2HDMI-OrangePi5Plus-microSD-boot-2026-10-22.img.gz` | Utilisation sur microSD | Démarre et lance automatiquement la Pocket 3 vers HDMI-A-2 en 1080i50. |
| `OSMO2HDMI-OrangePi5Plus-microSD-emmc-installer-2026-10-22.img.gz` | Installation sur eMMC | **Efface toute l'eMMC**, copie le système, vérifie les données, agrandit la partition et éteint la carte. Retirer la microSD et rallumer pour utiliser le système installé. |

Télécharger **un seul** fichier `.img.gz`, vérifier son SHA-256 avec le fichier `SHA256SUMS`, puis le flasher sur une microSD d'au moins 8 Go avec Etcher ou Raspberry Pi Imager. Une fois la carte insérée, brancher l'écran sur la sortie HDMI-A-2 et la Pocket 3 sur un port USB de données, puis mettre sous tension. L'image installateur peut prendre plusieurs minutes ; ne pas couper le courant avant l'extinction automatique.

Les images sont conçues comme des appareils autonomes : aucun compte Linux à créer et aucun mot de passe préinstallé. Le compte root est verrouillé et SSH désactivé. En cas de besoin de maintenance, préparer une nouvelle image ou modifier celle-ci hors ligne.

**Priorité de démarrage :** sur une Orange Pi 5 Plus déjà équipée d'un chargeur de démarrage eMMC, l'insertion de la microSD peut ne pas suffire : la carte peut continuer à démarrer sur l'eMMC. Il faut alors démarrer la microSD en priorité (par exemple en désactivant temporairement le chargeur eMMC via MaskROM). La version installateur ne peut rien faire tant que la carte n'a pas effectivement démarré sur microSD. Elle refuse l'installation si la machine, le disque source ou l'eMMC ne correspondent pas aux vérifications prévues.

**HDMI :** les paramètres 1080i50, `connector-id=236`, `plane-id=114` et le mode EDID `#13` ont été validés sur l'écran et la prise HDMI-A-2 de l'installation d'origine. Selon l'écran ou la prise HDMI, ces identifiants peuvent changer et demander une adaptation.

Le décodage du flux DJI 4K50 et sa sortie 1080i50 ont été vérifiés sur l'eMMC de l'installation d'origine. Le démarrage autonome de ces deux variantes de microSD et le parcours complet de l'installateur eMMC restent à valider sur le matériel final avant de considérer ces images comme testées de bout en bout.

Le code des deux services et de l'installateur se trouve dans ce dossier. L'ancien installateur NVMe reste disponible dans `dji-install-to-nvme.*`, mais ne correspond pas à ces deux images.
