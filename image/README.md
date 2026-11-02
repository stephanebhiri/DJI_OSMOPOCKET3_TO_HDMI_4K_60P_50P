# Installateur public microSD → eMMC (Orange Pi 5 Plus)

**État : candidat v4 local gravable, aucune version finale publiée.**
Le fichier `OSMO2HDMI-OrangePi5Plus-public-SD-eMMC-v4-2026-11-02.img.gz`
vient du commit `aedf3d2` de `main`. Il contient `kmssink sync=false` et le
cache H.264 SPS/PPS corrigé et protégé. Son SHA-256 est
`1ffc82479cdd5a69841717704f0ebe8b1137b553fe49c15281fc8b264f9867a8`.
L'archive, son système de fichiers et sa configuration ont passé les contrôles
statiques. **Elle n'a pas encore été gravée ni démarrée sur microSD réelle** :
l'installation eMMC et l'image/son après démarrage restent à vérifier avant
une publication comme version finale. La procédure ci-dessous décrit cet
installateur. Le fichier et son SHA-256 sont conservés dans une
[release GitHub en brouillon](https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P/releases/tag/untagged-8e4aa93b30b15998f1cf),
tag `v4-sd-emmc-candidate-2026-11-02` ; elle n'est pas accessible comme une
release publique finale. Ne pas utiliser
les anciennes images des releases v1/v2 ni l'image personnelle BELABOX comme
substitut : elles ne correspondent pas à cet installateur.

## Choisir le chemin d'installation

| Situation | Fichier et procédure disponibles | Limite actuelle |
| --- | --- | --- |
| MicroSD utilisable | Le candidat v4 ci-dessus, à écrire sur microSD puis à démarrer sur l'Orange Pi 5 Plus. | Le premier démarrage et la copie eMMC de v4 restent à confirmer sur matériel. |
| Aucune microSD | Le [guide MaskROM](BELABOX_EMMC_RUNBOOK_FR.md) explique le port USB-C de données, la sélection de l'eMMC et la vérification après écriture. | Le seul brut mentionné dans ce guide est une ancienne image **personnelle**, antérieure aux corrections du 2 novembre. Le candidat v4 est un installateur conçu pour démarrer sur microSD : le flasher directement sur eMMC ne constitue pas une installation validée. Aucune image publique directe eMMC à jour n'est encore produite. |

Les sources, scripts exacts de la BELABOX fonctionnelle, cache SPS/PPS et
diagnostics sont dans ce dépôt. Ils suffisent à **reconstruire et diagnostiquer**
la configuration actuelle ; ils ne remplacent pas les essais matériels des
deux chemins ci-dessus.

## Ce que fait la carte

La carte microSD contient Armbian Ubuntu Noble, les bibliothèques Rockchip MPP,
le module BELABOX corrigé pour la Pocket 3, GStreamer et les services vidéo et
audio. Au premier démarrage, le service vérifie le modèle Orange Pi 5 Plus, le
démarrage effectif sur microSD, la présence d'une seule eMMC non montée d'au
moins 8 Gio, l'intégrité des fichiers essentiels et le mode 1920×1080i50 sur
la sortie HDMI-A-2. **Après ces contrôles, il efface entièrement l'eMMC**,
copie les 6 Gio de l'image, compare les octets copiés, agrandit la partition
ext4 et active les services vidéo et audio sur l'eMMC. Il s'éteint ensuite.

La carte refuse d'écrire si elle a démarré sur l'eMMC, si la cible est absente
ou ambiguë, si l'écran n'annonce pas le mode demandé, ou si les fichiers
essentiels ne correspondent pas au manifeste. Une tentative échouée n'est pas
relancée automatiquement avec la même microSD ; lire le message affiché sur
la console et le journal du service.

## Utilisation après publication de l'image validée

1. Vérifier le SHA-256 du fichier `.img.gz` publié. Avec Raspberry Pi Imager,
   écrire cette image sur une **microSD saine d'au moins 8 Gio**. Sélectionner
   soigneusement la carte : le flash efface son contenu.
2. Éteindre l'Orange Pi 5 Plus. Insérer la microSD et connecter un écran qui
   accepte 1080i50 à **HDMI-A-2**, la sortie près de l'Ethernet sur la machine
   testée. Sauvegarder les données eMMC à conserver avant le démarrage de
   l'installateur. Laisser l'alimentation stable durant l'installation.
3. Démarrer. Si le microprogramme choisit une eMMC déjà amorçable plutôt que
   la microSD, l'installateur ne s'exécute pas ; il faut obtenir un démarrage
   réel sur microSD. Le contrôle de la racine microSD est obligatoire avant
   toute écriture eMMC.
4. Attendre l'extinction automatique annoncée par l'installateur. Ne pas
   retirer la carte durant la copie ni pendant la vérification.
5. Retirer la microSD, brancher la Pocket 3 sur un port USB de données,
   sélectionner **webcam** sur son écran, puis rallumer. La vidéo et le son
   doivent démarrer sans assistant de configuration. Si la caméra revient en
   mode transfert de fichiers après un redémarrage, débrancher puis rebrancher
   son câble USB et sélectionner à nouveau « webcam ». Vérifier une image
   mobile et le son sur l'écran ; le redémarrage autonome de la caméra n'a pas
   encore été démontré.

Il n'y a **aucun mot de passe ou clé SSH fournis**. SSH est désactivé par défaut.
Cette édition est dédiée à un appareil de sortie vidéo autonome ; l'accès de
maintenance nécessite une configuration locale explicite par le propriétaire.

## Reconstruction et contrôles

Le script [`build-public-installer.sh`](build-public-installer.sh) fonctionne
sur un hôte Linux ARM64 avec périphériques loop et au moins 10 Gio libres.
Il vérifie la base Armbian et les révisions de [`source-lock.txt`](source-lock.txt),
compile les composants dans l'image, supprime les identifiants et journaux,
installe le manifeste de hachages et génère un candidat compressé avec ses
SHA-256. Le script ne flashe aucun périphérique physique.

La validation requise avant publication est détaillée dans le
[plan d'installation](../docs/superpowers/plans/2026-10-26-public-sd-emmc-installer.md) :
décision de sauvegarde consignée, flash d'une nouvelle microSD,
installation réelle, démarrage à froid sans microSD, image mobile 1080i50 et
son du micro. Le [compte rendu de la BELABOX personnelle](BELABOX_VALIDATION_2026-10-26.md)
ne vaut pas validation de l'image publique.

L'[ancien installateur NVMe](NVME_INSTALLER_LEGACY.md) est conservé comme
archive technique séparée.
