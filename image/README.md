# Carte SD d'installation automatique vers NVMe — Orange Pi 5 Plus

Cette image démarre sur une Orange Pi 5 Plus, installe Armbian Ubuntu Noble et la chaîne DJI Pocket 3 → HDMI sur l'unique NVMe, programme U-Boot dans la mémoire SPI, puis éteint la carte. Après extinction, retirer la SD et rallumer l'Orange Pi pour démarrer depuis le NVMe.

## Contenu

- Armbian Noble minimal, noyau vendor RK3588, paquets mis à jour le 22 octobre 2026.
- GStreamer 1.24 et modules `mppvideodec` et `libuvch264src` compilés depuis les sources listées dans `source-lock.txt`.
- Service vidéo et règles udev du dépôt DJI.
- Installateur de premier démarrage `dji-install-to-nvme.service`.

## Utilisation

1. Décompresser ou sélectionner directement le fichier `.img.gz` dans Raspberry Pi Imager ou balenaEtcher, puis l'écrire sur une SD d'au moins 8 Go. Vérifier soigneusement le disque choisi : son contenu sera effacé.
2. Orange Pi éteinte, insérer la SD et brancher la Pocket 3 à son entrée USB et l'écran à la sortie HDMI.
3. Mettre sous tension. Ne pas couper l'alimentation pendant l'installation du NVMe et du SPI. L'installation peut prendre plusieurs minutes. La carte s'éteint automatiquement lorsqu'elle a terminé.
4. Après extinction, retirer la SD, puis rallumer. Le système et le service vidéo démarrent depuis le NVMe.

**Le premier démarrage efface entièrement l'unique NVMe détecté.** L'installateur refuse de démarrer si le modèle de carte est différent, si le système ne tourne pas sur SD, si le nombre de NVMe n'est pas exactement un, si ce NVMe est utilisé, ou si la mémoire SPI est absente. Une tentative échouée n'est pas répétée automatiquement ; consulter la console série/HDMI et `journalctl -u dji-install-to-nvme.service` avant toute reprise.

Pour un contrôle du fichier téléchargé : `shasum -a 256 nom-du-fichier.img.gz`, puis comparer à la valeur du fichier `.sha256` fourni.

Le fonctionnement vidéo final et le démarrage sans SD doivent être confirmés sur le matériel réel. La sortie HDMI est configurée en 1080i50 conformément au projet ; le flux caméra H.264 peut être en 4K50.
