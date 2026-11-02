# DJI Osmo Pocket 3 → HDMI 1080i50 sur Orange Pi 5 Plus

Ce dépôt contient les sources et la procédure d'une chaîne vidéo **Pocket 3 H.264
4K50 → décodage Rockchip MPP → HDMI-A-2 1080i50**, avec le micro de la caméra
envoyé sur HDMI.

**Téléchargement public : aucune image prête à installer n'est actuellement
disponible.** Le candidat microSD v4 est dans une release GitHub en brouillon,
accessible seulement aux personnes autorisées sur le dépôt. Le R2 décrit dans
ces pages est une sauvegarde personnelle privée ; les visiteurs du dépôt ne
peuvent pas la télécharger. Les sources et procédures ci-dessous sont publiques.

## État vérifié — 2 novembre 2026

| Point | État |
| --- | --- |
| Matériel testé | Une Orange Pi 5 Plus dans une BELABOX, système installé sur son eMMC. |
| Image et son | Sur l'eMMC, l'utilisateur a confirmé le 2 novembre une image fluide et le son du micro **sans gain**. La racine était `/dev/mmcblk0p1`, la sortie `1920x1080i50` et le plan NV12 actif. Après la capture MaskROM, il a coupé puis rétabli l'alimentation sans microSD et confirmé que tout fonctionnait. Ce dernier démarrage a été confirmé visuellement et auditivement par lui, sans nouveau relevé SSH. |
| Démarrage de la Pocket 3 | Après un redémarrage logiciel le 2 novembre, la caméra est revenue d'abord en mode transfert `2ca3:0020`. Si cela se reproduit, débrancher puis rebrancher son câble USB et choisir « webcam » `2ca3:0023`. Ensuite, un cache SPS/PPS H.264 corrompu a laissé seulement les barres de couleur ; restaurer les [39 octets validés](image/known-good-belabox-2026-11-02/) a rendu l'image et le son. Le cache actif est protégé ; le démarrage à froid suivant a donné image et son selon le propriétaire. |
| Fluidité réelle | Le seul mode 1080i50 ne suffisait pas : `kmssink sync=true` ne renouvelait le plan qu'environ 19 fois/s malgré 50 images/s en entrée et après décodage. Avec `sync=false`, le plan a changé 49,82 fois/s sur 5 s et l'utilisateur a vu la différence. Cela ne certifie pas une conversion entrelacée conforme sur tout écran. |
| Démarrage vidéo | Le premier lancement peut encore subir un SIGSEGV. L'option --no-fault permet à systemd de relancer le service ; ce rétablissement automatique a été observé au dernier démarrage à froid. **La cause interne du plantage reste à résoudre.** |
| Image installatrice | Le [candidat v4](image/README.md) a été reconstruit depuis `main` avec `sync=false` et le cache SPS/PPS corrigé. Le fichier local est gravable, mais **son installation eMMC et son démarrage sur matériel ne sont pas encore validés** ; aucune image corrigée n'est publiée comme version finale. Un cliché de l'eMMC fonctionnelle a été sauvegardé localement le 2 novembre et une copie de secours réparée a passé les contrôles hors ligne. **La restauration de cette copie n'a pas été testée physiquement.** Ces images personnelles restent hors GitHub. Les anciennes images v1.0/v2.0 ont été retirées. |
| Autre Orange Pi, écran ou installation NVMe | Parcours complet non validé avec ces corrections. Les identifiants DRM, le mode EDID et le démarrage doivent être contrôlés sur le matériel concerné. |

Le [compte rendu matériel](image/BELABOX_VALIDATION_2026-10-26.md) sépare les
mesures techniques de la confirmation physique. La [procédure BELABOX
eMMC](image/BELABOX_EMMC_RUNBOOK_FR.md) explique les erreurs rencontrées et la
restauration. Les anciennes images ne sont **pas** une sauvegarde de
l'installation actuelle.
Les [scripts exacts relevés sur la BELABOX fonctionnelle](image/known-good-belabox-2026-11-02/)
sont conservés séparément de la source générale destinée à plusieurs cartes.
Les archives personnelles de l'eMMC sont conservées dans **R2 privé**, avec
une [procédure de récupération](image/SAUVEGARDE_R2_FR.md). Les blocs des deux
archives ont été téléchargés et vérifiés par SHA-256 avant le retrait des
grosses copies locales.

## Par où commencer

| Besoin | Document |
| --- | --- |
| Installer une autre Orange Pi 5 Plus et contrôler le résultat | [Installation rapide et diagnostic](image/INSTALLATION_RAPIDE_FR.md) |
| Comprendre pourquoi l'installation a échoué puis fonctionné | [Procédure et diagnostic BELABOX](image/BELABOX_EMMC_RUNBOOK_FR.md) |
| Voir exactement ce qui a été testé sur eMMC | [Compte rendu du 26 octobre et du 2 novembre 2026](image/BELABOX_VALIDATION_2026-10-26.md) |
| Reconstruire les composants logiciels | [Versions figées](image/source-lock.txt) et [provisionnement ARM64 Noble](image/provision-rootfs.sh) |
| Suivre la future installation autonome eMMC | [Installateur microSD → eMMC](image/README.md) et [script de construction](image/build-public-installer.sh) |
| Comprendre les anciennes images retirées | [Historique v2.0](image/DUAL_IMAGES.md) |

La reconstruction part de la base Armbian Ubuntu Noble et des révisions
précisées dans le fichier image/source-lock.txt. Le script
image/build-public-installer.sh construit un candidat sur Linux ARM64, et
image/provision-rootfs.sh compile la pile et ses correctifs. **L'installateur
public n'est pas encore validé matériellement.** Le flash eMMC décrit dans la
procédure BELABOX utilise une image personnelle vérifiée localement ; il efface
l'eMMC de la machine visée.

## Configuration testée

- Orange Pi 5 Plus RK3588, Armbian Ubuntu Noble, noyau fournisseur
  6.1.115-vendor-rk35xx, GStreamer 1.24.
- DJI Pocket 3 en mode **webcam** (USB 2ca3:0023). La liaison constatée à
  480 Mb/s a permis le flux H.264 4K50 ; cette vitesse seule ne prouve pas un
  câble défectueux.
- Source H.264 : fork BELABOX de libuvc avec le
  [correctif de négociation 4K50](image/patches/belabox-uvc-stale-payload.patch).
- Décodage mppvideodec, affichage kmssink avec `sync=false` sur le plan NV12
  **114** de cette BELABOX. Le connecteur HDMI-A-2 et le mode 1080i50 sont
  recherchés à chaque démarrage ; **ne pas figer un numéro EDID** tel que #13.
  La source générale cherche aussi un plan NV12 automatiquement, mais cette
  variante n'a pas subi l'essai physique du 2 novembre.
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
  [installateur NVMe distinct](image/NVME_INSTALLER_LEGACY.md).

Ils restent accessibles comme archives techniques, **pas comme procédure
actuelle prête à exécuter**.

Une [vidéo de démonstration historique](demo/OSM0_ORANGEPI_TO_HDMI1080i50.mp4)
est conservée dans le dépôt ; elle n'est pas une preuve du démarrage de
l'installation eMMC actuelle.

## Licence et crédits

Licence MIT. Base système [Armbian](https://www.armbian.com/), source H.264
[BELABOX](https://github.com/BELABOX/gstlibuvch264src), décodeur Rockchip MPP
et [GStreamer](https://gstreamer.freedesktop.org/).
