# Installer OSMO2HDMI sur une autre Orange Pi 5 Plus

Cette page sert de point de départ. La [procédure détaillée](BELABOX_EMMC_RUNBOOK_FR.md)
explique les pannes rencontrées ; le [relevé matériel](BELABOX_VALIDATION_2026-10-26.md)
distingue mesures et confirmation sur l'écran. Les scripts et le cache de la
BELABOX fonctionnelle sont dans [known-good-belabox-2026-11-02/](known-good-belabox-2026-11-02/).

## Avant de commencer

- Carte **Orange Pi 5 Plus** avec eMMC ; Pocket 3 en mode **webcam** (`2ca3:0023`).
- Écran acceptant **1920×1080i50** sur **HDMI-A-2**, la sortie près des prises
  Ethernet sur la BELABOX testée. Un écran informatique 1080p seulement ne
  constitue pas un essai valable du 1080i50.
- Les sources visent Armbian Noble, noyau fournisseur `6.1.115-vendor-rk35xx`,
  GStreamer 1.24, entrée H.264 3840×2160/50, sortie HDMI 1080i50 et audio
  Pocket 3 → HDMI **sans gain**.
- Une installation sur eMMC efface son ancien contenu. Confirmer que la bonne
  carte est visée avant le premier flash.

## Avec microSD : candidat public v4

1. Vérifier le SHA-256 de
   `OSMO2HDMI-OrangePi5Plus-public-SD-eMMC-v4-2026-11-02.img.gz` :
   `1ffc82479cdd5a69841717704f0ebe8b1137b553fe49c15281fc8b264f9867a8`.
   Le fichier est dans la [release en brouillon](https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P/releases/tag/untagged-8e4aa93b30b15998f1cf).
2. Graver sur une **microSD saine d'au moins 8 Gio**, l'insérer dans le slot
   microSD, brancher HDMI-A-2, puis démarrer. Le système doit réellement
   démarrer sur microSD ; sinon l'installateur refuse d'écrire l'eMMC.
3. Lire l'écran d'installation. Après vérification de la cible et copie de
   l'image, la carte s'éteint. Retirer la microSD avant le prochain démarrage.
4. Brancher la Pocket 3 ; choisir **webcam** sur son écran. Si elle revient en
   mode transfert après un redémarrage, débrancher puis rebrancher son câble
   USB et choisir de nouveau webcam.

**État de preuve :** ce fichier v4 a passé les contrôles de construction,
d'intégrité et d'identité. Il **n'a pas encore effectué une installation réelle
sur une autre Orange Pi**. La première réussite physique reste à consigner.

## Sans microSD : MaskROM

Le [guide MaskROM](BELABOX_EMMC_RUNBOOK_FR.md) décrit le port USB-C de données,
le chargeur RK3588, la sélection de l'eMMC et la comparaison après écriture.
**Il manque encore un cliché hors ligne de l'eMMC actuellement fonctionnelle.**
Le seul brut local de 6 Gio date d'avant les corrections finales du 2 novembre ;
il exige de réinstaller les scripts et le cache du dossier `known-good`.
Le candidat microSD v4 ne doit pas être écrit tel quel sur l'eMMC : il contient
le service d'installation prévu pour un démarrage depuis microSD et refuserait
de se lancer depuis l'eMMC.

Pour constituer **une fois** un secours exact de la BELABOX actuellement
fonctionnelle, le script en lecture seule
[`backup-belabox-emmc-maskrom.sh`](backup-belabox-emmc-maskrom.sh) est prêt.
Il exige un arrêt de la carte et un branchement MaskROM au Mac ; il refuse
les autres capacités eMMC et lit les 6 Gio contenant la partition racine.
Il ne lance aucune commande d'écriture sur l'eMMC. L'archive et son SHA-256
restent privés et locaux. **Cette capture n'a pas encore été effectuée** ;
les seuls scripts copiés ne remplacent pas cette sauvegarde exacte.
Sur ce Mac, une fois la carte passée en MaskROM, lancer depuis la racine du
dépôt `image/backup-belabox-emmc-maskrom.sh` sans argument : le script trouve
le programme et le chargeur déjà présents dans le dossier parent et place
l'archive datée à cet endroit. Sur un autre Mac, lui passer explicitement le
programme, le chargeur et le préfixe de sortie (voir son message d'usage).
La copie couvre les 6 Gio amorçables et toute la partition racine actuelle,
pas l'en-tête GPT secondaire situé à la fin de l'eMMC de 64 Go. Après une
éventuelle restauration, replacer cet en-tête comme dans la
[procédure détaillée](BELABOX_EMMC_RUNBOOK_FR.md).

## Contrôle après installation

Si l'accès SSH a été configuré sur la machine personnelle, lancer le contrôle
en lecture seule du dépôt :

```sh
ssh root@ADRESSE_DU_PI 'bash -s' < image/verify-runtime.sh
```

Il vérifie eMMC, noyau, mode webcam, trois services, HDMI 1080i50, plan NV12,
cadence du framebuffer, cache SPS/PPS et capture/lecture ALSA. Un résultat
`OK` prouve **ces états logiciels**, pas que l'écran montre l'image de la
caméra ni que son haut-parleur est audible. Confirmer une fois en bougeant la
Pocket 3 devant l'écran et en parlant près de son micro. La version publique
est livrée sans SSH ; ce contrôle à distance ne s'y applique pas avant une
configuration locale explicite.

## Si l'image ou le son manque

| Symptôme | Première vérification ; ne changer qu'un élément à la fois |
| --- | --- |
| Écran noir ou `login:` | Vérifier le câble sur HDMI-A-2 et un écran compatible 1080i50. |
| Barres de couleur, son présent | Vérifier `2ca3:0023`, le SHA-256 du cache `/root/.spspps/0` et le plan NV12 ; suivre [la récupération du cache](known-good-belabox-2026-11-02/README.md). Ne pas toucher au gain audio. |
| Image saccadée | Vérifier `sync=false` et mesurer les changements du plan avec `verify-runtime.sh` ; l'étiquette 1080i50 seule ne prouve pas la fluidité. |
| Pas de son | Vérifier les cartes ALSA nommées `DJIPocket3` et `rockchiphdmi1`, puis la capture et la lecture `RUNNING`. Le script audio vérifié n'ajoute aucun gain. |

Les identifiants de connecteur et d'index EDID (`236` et `13` lors du dernier
relevé) ne sont **pas** des constantes à recopier. Le script source les
redécouvre ; son choix de plan a été testé sur la sortie de `modetest` de la
BELABOX fonctionnelle et a sélectionné le plan `114`.
