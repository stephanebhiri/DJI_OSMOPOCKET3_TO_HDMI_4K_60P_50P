# Configuration active sur la BELABOX le 2 novembre 2026

Ce dossier conserve **les deux scripts réellement lus sur l'eMMC** après la
confirmation physique d'une image fluide et du son de la Pocket 3. Ils sont
propres à cette Orange Pi 5 Plus et à son plan KMS 114. Ils ne sont pas une
image complète de l'eMMC ni une preuve du fonctionnement sur un autre écran.

| Fichier installé | SHA-256 constaté sur la machine |
| --- | --- |
| `/usr/local/bin/dji-stream.sh` | `3bada12307f7e1a85045aa9816bf93d55d1039dac9add732e3ea9dfac3f9b8cb` |
| `/usr/local/bin/osmo-hdmi50.sh` | `992d986c3424bb1136a3cd29a18f620ad2d336195e1f91d1629074e88405e44f` |
| `/usr/local/bin/dji-hdmi-audio.sh` | `5c5c41948b1ada69a0a7a57c5192329431163ba6fe005ee727b295e49b804a60` |
| `/root/.spspps/0` | `116eaddd34020344a16a378759b0a1f41fd07d9ca3e8aaf7ed0f7611ad66169e` |

Le fichier [`pocket3-4k50.spspps`](pocket3-4k50.spspps) est la copie exacte
des 39 octets SPS/PPS H.264 retrouvés dans l'image eMMC du 26 octobre. Le
2 novembre, le cache présent après redémarrage mesurait 1 022 octets et
contenait des en-têtes SPS/PPS invalides (`07`/`08`) ; le décodeur ne
produisait plus d'image. Effacer ce cache pour employer les constantes par
défaut du plugin n'a pas rétabli l'image. Réinstaller ces 39 octets puis
relancer **le service vidéo seul** a rétabli un framebuffer NV12 actif ; le
propriétaire a confirmé l'image mobile et le son. Le fichier actif a ensuite
été protégé avec `chattr +i` (`----i---------e-------`). Aucune nouvelle
extinction complète n'a été faite après cette protection.

Pour cette même installation, si ce cache doit être remis : arrêter
`dji-h264-stream.service`, enlever au besoin l'attribut immuable avec
`chattr -i /root/.spspps/0`, copier ce fichier vers `/root/.spspps/0` en
mode 644, remettre `chattr +i`, puis démarrer le service vidéo. Vérifier
son SHA-256 et **l'image mobile à l'écran**. Ne pas appliquer aveuglément
ce cache à une autre caméra ou un autre profil vidéo.

Le script audio installé est exactement [`../dji-hdmi-audio.sh`](../dji-hdmi-audio.sh),
sans gain ni limiteur. Les trois services et les trois règles udev installés
correspondaient aussi aux fichiers du dépôt par SHA-256 :
`dji-h264-stream.service`, `osmo-hdmi50.service`, `dji-hdmi-audio.service`,
`99-dji-camera.rules`, `50-dji-usb.rules`, `99-dma-heap.rules`.

Le script vidéo actif emploie `plane-id=114` et `sync=false`. Le script vidéo
général à la racine du dépôt cherche le plan KMS automatiquement ; ce chemin
général n'a pas été testé physiquement avec la correction de fluidité sur cette
machine. Le script HDMI actif choisit le mode 1080i50 dans l'EDID à chaque
démarrage, sans numéro de mode figé. Lors de cette session le connecteur était
236 et l'index EDID 13 : **ces nombres ne sont pas des constantes à copier**.

État système relevé : `/dev/mmcblk0p1 ext4`, noyau
`6.1.115-vendor-rk35xx`, GStreamer `1.24.2`, USB Pocket 3 `2ca3:0023`,
HDMI-A-2 `1920x1080i50`, framebuffer NV12 3840×2160 sur le plan 114.
`/boot/armbianEnv.txt` contenait `cma=256M`,
`usbcore.quirks=2ca3:0023:i` et aussi un ancien argument
`video=HDMI-A-1:1920x1080i@50`. Ce dernier n'a pas été nécessaire pour
sélectionner HDMI-A-2 et ne doit pas être repris aveuglément. Le `rootdev=UUID`
de cette BELABOX est propre à son eMMC.

Pour réinstaller ces deux scripts **sur cette même BELABOX seulement**, après
avoir vérifié que le noyau, les dépendances, la Pocket 3 et HDMI-A-2 sont
présents, copier les fichiers dans `/usr/local/bin/`, leur donner le mode 755,
puis redémarrer `osmo-hdmi50.service` et `dji-h264-stream.service` dans cet
ordre. Le son utilise le script audio du dossier parent et
`dji-hdmi-audio.service`. Contrôler ensuite physiquement l'image mobile et
le son. Voir [le compte rendu](../BELABOX_VALIDATION_2026-10-26.md) pour les
mesures et les limites.
