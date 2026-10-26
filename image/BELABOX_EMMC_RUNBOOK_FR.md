# BELABOX Orange Pi 5 Plus → OSMO2HDMI sur eMMC

Procédure et diagnostic du matériel validé le 26 octobre 2026. À lire avec
[`BELABOX_VALIDATION_2026-10-26.md`](BELABOX_VALIDATION_2026-10-26.md), qui
contient les mesures et les résultats datés. La première Orange Pi fonctionnelle
n'avait pas été clonée : ce document et les sources corrigées sont conservés
pour éviter de reconstruire ces corrections de mémoire.

## Configuration réellement utilisée

- Orange Pi 5 Plus RK3588 dans une BELABOX, eMMC Samsung 61 865 984 000 octets.
- Armbian Ubuntu Noble, noyau `6.1.115-vendor-rk35xx`, GStreamer 1.24.
- DJI Pocket 3 en mode **webcam**, identifiant USB `2ca3:0023`, sur le port USB
  qui a fonctionné lors du test matériel. Une liaison USB 2 à 480 Mb/s a fourni
  le H.264 4K50 ; la seule vitesse négociée ne prouve pas un câble défectueux.
- HDMI-A-2 : sortie 1920×1080i à 50 Hz, son du micro de la Pocket 3 sur HDMI.
  Le connecteur et le numéro de mode EDID sont découverts à chaque démarrage.
- Vidéo : `libuvch264src` → `h264parse` → `mppvideodec` → `kmssink` sur le plan
  KMS 114, compatible NV12. Le 3840×2160 H.264 à 50 images/s est décodé puis
  mis à l'échelle pour la sortie entrelacée.

Les versions et révisions des composants sont figées dans
[`source-lock.txt`](source-lock.txt). Les images de téléchargement d'octobre 2026
ont été retirées : elles précèdent les corrections. Ne pas les utiliser comme
sauvegarde de cette installation. L'image personnelle locale contient une clé
SSH de maintenance et ne doit pas être publiée.

## Pourquoi les essais précédents ont échoué

| Symptôme | Cause constatée | Correction conservée |
| --- | --- | --- |
| 4K50 refusé après un essai 1080p30, parfois image figée | Le fork BELABOX de libuvc comparait aussi `dwMaxPayloadTransferSize`. La Pocket 3 renvoyait un `GET_MAX` périmé de `622080` avant de négocier `2488320`. | [`belabox-uvc-stale-payload.patch`](patches/belabox-uvc-stale-payload.patch) compare format, image et intervalle ; reconstruire libuvc. Test 1080p30→4K50 réussi. |
| Flux décodé mais pas d'image HDMI | Le plan KMS choisi automatiquement ne convenait pas au NV12 4K. | `plane-id=114` dans [`dji-stream.sh`](../dji-stream.sh). Vérifier que le plan actif reçoit un framebuffer NV12. |
| Service vidéo arrêté après reconnexions | La règle udev relançait le service pour chaque nœud `video4linux` ; la limite systemd était atteinte. | [`99-dji-camera.rules`](../99-dji-camera.rules) relance une seule fois à l'ajout du périphérique USB ; [`dji-h264-stream.service`](../dji-h264-stream.service) autorise les nouvelles tentatives. |
| 1080i50 sélectionné puis retour en 1080p60 | La console framebuffer reprenait le CRTC après `modetest -d` et restaurait son mode préféré. | [`osmo-hdmi50.sh`](osmo-hdmi50.sh) détache la console framebuffer avant de régler le mode. Le plan vidéo est ensuite utilisable par GStreamer. |
| Après un démarrage à froid, le service vidéo semblait actif mais aucun plan vidéo n'était affiché | `gst-launch-1.0` avait reçu SIGSEGV au premier lancement, puis son gestionnaire de défaut attendait un débogueur : systemd voyait encore un processus actif et ne redémarrait pas. Un redémarrage du service a immédiatement rétabli le flux. | `gst-launch-1.0 --no-fault` laisse le processus mourir en cas de nouveau défaut ; `Restart=always` le relance. Cette protection ne supprime pas la cause interne du SIGSEGV. Revérifier le démarrage automatique après coupure complète. |
| Reflash microSD suivi de corruption ext4 et binaire libuvc altéré | La microSD d'essai était instable. Un contrôle `e2fsck` hors montage et une comparaison SHA-256 ont révélé la corruption. | Ne pas la cloner. L'image eMMC provient d'une **autre** carte USB, contrôlée avec `e2fsck` et SHA-256, puis relue intégralement après flash. |
| Après extinction, ancien système BELABOX au lieu du nouveau | Le démarrage repartait de l'eMMC BELABOX tant que la nouvelle image n'y était pas installée. | Écrire directement l'image corrigée sur l'eMMC en MaskROM et vérifier `findmnt /`. |

## Construire à nouveau les sources

Partir de la base Noble indiquée dans `source-lock.txt` et appliquer
[`provision-rootfs.sh`](provision-rootfs.sh) dans l'environnement ARM64 prévu.
Le script applique le correctif H.265 de compatibilité, puis le correctif UVC
si l'ancienne comparaison de charge utile est encore présente. Il installe
ensuite les services, les scripts HDMI et audio et les règles udev. Ne pas
remplacer le noyau fournisseur 6.1.115/GStreamer 1.24 sans refaire tous les
tests matériels. Le script de finalisation de l'image personnelle est
[`finalize-runtime-image.sh`](finalize-runtime-image.sh).

Avant de fabriquer une nouvelle image, vérifier au minimum :

1. `bash -n dji-stream.sh image/osmo-hdmi50.sh image/provision-rootfs.sh`
   et `git diff --check` sur les sources.
2. Dans Noble, tester 1080p30 puis 4K50 avec la Pocket 3 réellement branchée.
3. Vérifier `modetest -M rockchip -c` : HDMI-A-2 doit offrir **1920×1080i 50** ;
   ne jamais figer le numéro de mode `#5` ou `#13` dans l'image.
4. Démarrer le flux et vérifier `plane[114]` actif en NV12, le mode de CRTC
   `1920x1080i50`, l'image **mobile** et le son sur un écran réel.

## Installer une image personnelle vérifiée sur l'eMMC

Cette section décrit le chemin utilisé sur le matériel, pas une image publique
prête à télécharger. Il faut un fichier brut dont le hash et la taille ont été
vérifiés. L'image préparée localement le 26 octobre mesurait exactement
`6442450944` octets (6 Gio) et avait pour SHA-256
`eef110804488b3168894ebf585e59a4cab982b05fd3d2fa1f2d7d8b904b4819f`.
Les retouches ultérieures de `osmo-hdmi50.sh` et `dji-stream.sh` sont décrites
ci-dessus : **ce fichier brut précède ces deux retouches**. Après restauration
de ce fichier, réinstaller les deux scripts depuis les sources actuelles.

1. Éteindre l'Orange Pi ; retirer microSD et lecteur USB. Brancher l'alimentation
   5 V sur le Type-C proche de l'Ethernet et le Mac sur **l'autre** Type-C de
   données, avec un câble de données. Maintenir MaskROM au rebranchement de
   l'alimentation, puis relâcher le bouton. Le port d'alimentation ne transporte
   pas les données de flash.
2. Sur le Mac, `rkdeveloptool ld` doit afficher `Vid=0x2207,Pid=0x350b` et
   `Maskrom`. Charger le programme RK3588 approprié avec `rkdeveloptool db
   <loader-rk3588.bin>` puis faire `rkdeveloptool cs 1` (**1 = eMMC**).
3. **Avant toute écriture**, `rkdeveloptool rfi` doit annoncer `120832000
   Sectors`, soit 61 865 984 000 octets pour cette eMMC. Lire les premiers
   secteurs (`rkdeveloptool rl 0 2048 <fichier-de-contrôle>`) et contrôler la
   table GPT. Si la capacité ou le type ne correspondent pas, s'arrêter.
4. Écrire le brut avec `rkdeveloptool wl 0 <image-brute>`. Le contenu précédent
   de l'eMMC est effacé. Relire les 6 Gio par blocs avec `rkdeveloptool rl` et
   comparer SHA-256 de chaque bloc à la même plage de l'image source. Les douze
   blocs de 512 Mio ont tous correspondu lors de cette installation.
5. `rkdeveloptool rd`, débrancher le câble de données du Mac, puis redémarrer
   sans microSD ni lecteur USB. La machine peut obtenir **une nouvelle IP DHCP**.
   Confirmer son identité par son adresse MAC connue, pas seulement par l'IP.

## Contrôle après chaque démarrage à froid

Exécuter sur l'Orange Pi :

```sh
findmnt -n -o SOURCE,FSTYPE /
uname -r
lsusb | grep '2ca3:0023'
systemctl is-active osmo-hdmi50 dji-h264-stream dji-hdmi-audio
grep 'Display mode:' /sys/kernel/debug/dri/0/summary
grep -A7 'plane\[114\]' /sys/kernel/debug/dri/0/state
journalctl -b -u dji-h264-stream.service --no-pager | tail -30
dmesg | grep -Ei 'EXT4-fs error|I/O error|mmc.*error'
```

Attendus : `/dev/mmcblk0p1 ext4` pour `/`, noyau 6.1.115 fournisseur,
Pocket 3 présente, trois services actifs, HDMI-A-2 en `1920x1080i50`, plan 114
avec `crtc=video_port1`, framebuffer NV12 3840×2160 et aucun défaut ext4.
**`systemctl active` seul ne prouve pas la vidéo** : contrôler le plan et
déplacer la Pocket 3 devant l'écran ; écouter aussi son micro sur HDMI.

Si le plan reste nul mais que le service est actif, chercher `Caught SIGSEGV`
dans le journal. Vérifier que `dji-stream.sh` utilise `--no-fault`, puis
redémarrer le service. Si la sortie repasse en 1080p60, vérifier que la console
framebuffer est détachée (`/sys/class/vtconsole/vtcon*/bind`) et relancer
`osmo-hdmi50.service` **après avoir arrêté** `dji-h264-stream.service` qui
occupe le périphérique DRM. Si le périphérique USB manque, rebrancher la
Pocket 3 et confirmer le choix « webcam » sur son écran.

## Capacité eMMC et conservation

L'image brute a une partition racine de 6 Gio sur une eMMC de 64 Go ; elle
fonctionne avec environ 3,3 Gio libres. La copie de l'image avait laissé le
GPT de secours à 6 Gio : il a été déplacé à la fin du disque. L'extension de
la partition racine montée a été refusée par `parted` ; ne pas considérer le
reste comme utilisable avant extension et contrôle du système de fichiers.

Conserver ensemble, hors du dépôt public : l'image personnelle comprimée, son
hash, les deux scripts retouchés et ce compte rendu. Un hash prouve la copie
de l'image ; le fonctionnement du matériel exige en plus un démarrage à froid
et une vérification physique de l'image et du son.
