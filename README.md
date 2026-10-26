# DJI Osmo Pocket 3 → HDMI 1080i50 sur Orange Pi 5 Plus

Ce dépôt contient les sources et la procédure d'une chaîne vidéo **Pocket 3 H.264
4K50 → décodage Rockchip MPP → HDMI-A-2 1080i50**, avec le micro de la caméra
envoyé sur HDMI.

## État vérifié — 26 octobre 2026

| Point | État |
| --- | --- |
| Matériel testé | Une Orange Pi 5 Plus dans une BELABOX, système installé sur son eMMC. |
| Image et son | Après coupure complète, l'utilisateur a confirmé l'image mobile et le son du micro sur l'écran HDMI. La racine était /dev/mmcblk0p1, la sortie 1920×1080i50 et le plan vidéo NV12 actif. |
| Démarrage vidéo | Le premier lancement peut encore subir un SIGSEGV. L'option --no-fault permet à systemd de relancer le service ; ce rétablissement automatique a été observé au dernier démarrage à froid. **La cause interne du plantage reste à résoudre.** |
| Image à télécharger | **Aucune image corrigée publique prête à flasher.** Les anciennes images v1.0/v2.0 ont été retirées. L'image personnelle de la BELABOX contient une clé SSH de maintenance et n'est pas distribuée. |
| Autre Orange Pi, écran ou installation NVMe | Parcours complet non validé avec ces corrections. Les identifiants DRM, le mode EDID et le démarrage doivent être contrôlés sur le matériel concerné. |

Le [compte rendu matériel](image/BELABOX_VALIDATION_2026-10-26.md) sépare les
mesures techniques de la confirmation physique. La [procédure BELABOX
eMMC](image/BELABOX_EMMC_RUNBOOK_FR.md) explique les erreurs rencontrées et la
restauration. Les anciennes images ne sont **pas** une sauvegarde de
l'installation actuelle.

## Par où commencer

| Besoin | Document |
| --- | --- |
| Comprendre pourquoi l'installation a échoué puis fonctionné | [Procédure et diagnostic BELABOX](image/BELABOX_EMMC_RUNBOOK_FR.md) |
| Voir exactement ce qui a été testé sur eMMC | [Compte rendu du 26 octobre 2026](image/BELABOX_VALIDATION_2026-10-26.md) |
| Reconstruire les composants logiciels | [Versions figées](image/source-lock.txt) et [provisionnement ARM64 Noble](image/provision-rootfs.sh) |
| Comprendre les anciennes images retirées | [Historique v2.0](image/DUAL_IMAGES.md) |

La reconstruction part de la base Armbian Ubuntu Noble et des révisions
précisées dans le fichier image/source-lock.txt. Le script
image/provision-rootfs.sh compile la pile sur ARM64 et installe les services et
les correctifs. **Ce dépôt ne propose pas une commande unique validée pour
convertir toute BELABOX ou toute Orange Pi.** Le flash eMMC décrit dans la
procédure utilise une image personnelle vérifiée localement ; il efface l'eMMC
de la machine visée.

## Configuration testée

- Orange Pi 5 Plus RK3588, Armbian Ubuntu Noble, noyau fournisseur
  6.1.115-vendor-rk35xx, GStreamer 1.24.
- DJI Pocket 3 en mode **webcam** (USB 2ca3:0023). La liaison constatée à
  480 Mb/s a permis le flux H.264 4K50 ; cette vitesse seule ne prouve pas un
  câble défectueux.
- Source H.264 : fork BELABOX de libuvc avec le
  [correctif de négociation 4K50](image/patches/belabox-uvc-stale-payload.patch).
- Décodage mppvideodec, affichage kmssink sur le plan NV12 **114** de cette
  carte. Le connecteur HDMI-A-2 et le mode 1080i50 sont recherchés à chaque
  démarrage ; **ne pas figer un numéro EDID** tel que #13.
- Son : capture ALSA nommée DJIPocket3, sortie ALSA HDMI nommée
  rockchiphdmi1. Les services vidéo et audio sont indépendants.

Les identifiants de plan et les noms de carte audio ci-dessus sont ceux du
matériel testé. Les scripts concernés sont [la vidéo](dji-stream.sh),
[le mode HDMI](image/osmo-hdmi50.sh) et [l'audio](image/dji-hdmi-audio.sh).

## Vérifier une machine installée

Sur l'Orange Pi :

~~~sh
findmnt -n -o SOURCE,FSTYPE /
lsusb | grep '2ca3:0023'
systemctl is-active osmo-hdmi50 dji-h264-stream dji-hdmi-audio
grep 'Display mode:' /sys/kernel/debug/dri/0/summary
grep -A7 'plane\[114\]' /sys/kernel/debug/dri/0/state
journalctl -b -u dji-h264-stream.service --no-pager | tail -30
~~~

Sur la BELABOX validée, on attend /dev/mmcblk0p1 ext4, 1920×1080i50 et un
framebuffer NV12 sur le plan 114. Un service marqué « active » ne prouve pas
que la vidéo bouge : regarder l'écran en déplaçant la Pocket 3 et écouter son
micro. Les erreurs USB au début du démarrage peuvent disparaître quand la
caméra finit de s'énumérer ; consulter l'état final et les journaux.

## Documents historiques

Les guides suivants décrivent des étapes antérieures et peuvent contenir des
versions de noyau, des identifiants DRM ou des images qui ne correspondent pas
à l'installation eMMC vérifiée le 26 octobre :

- [Image v1.0](IMAGE_README.md), [installation de janvier](INSTALL_GUIDE.md),
  [configuration Noble initiale](WORKING_CONFIG_NOBLE.md),
  [configuration Bookworm](WORKING_CONFIG.md).
- [Ancien guide détaillé](README_DETAILED.md),
  [essais sur une Orange Pi neuve](TEST_ON_FRESH_ORANGEPI.md),
  [création d'image](CREATE_IMAGE.md),
  [installateur NVMe distinct](image/README.md).

Ils restent accessibles comme archives techniques, **pas comme procédure
actuelle prête à exécuter**.

Une [vidéo de démonstration historique](demo/OSM0_ORANGEPI_TO_HDMI1080i50.mp4)
est conservée dans le dépôt ; elle n'est pas une preuve du démarrage de
l'installation eMMC actuelle.

## Licence et crédits

Licence MIT. Base système [Armbian](https://www.armbian.com/), source H.264
[BELABOX](https://github.com/BELABOX/gstlibuvch264src), décodeur Rockchip MPP
et [GStreamer](https://gstreamer.freedesktop.org/).
