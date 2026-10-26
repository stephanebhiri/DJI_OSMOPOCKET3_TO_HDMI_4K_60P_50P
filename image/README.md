# Installateur public microSD → eMMC (Orange Pi 5 Plus)

**État : image candidate en construction, aucun téléchargement public validé à ce jour.**
La procédure ci-dessous décrit l'installateur en cours de test. Ne pas utiliser
les anciennes images des releases v1/v2 ni l'image personnelle BELABOX comme
substitut : elles ne correspondent pas à cet installateur.

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
   testée. Laisser l'alimentation stable durant l'installation.
3. Démarrer. Si le microprogramme choisit une eMMC déjà amorçable plutôt que
   la microSD, l'installateur ne s'exécute pas ; il faut obtenir un démarrage
   réel sur microSD. Le contrôle de la racine microSD est obligatoire avant
   toute écriture eMMC.
4. Attendre l'extinction automatique annoncée par l'installateur. Ne pas
   retirer la carte durant la copie ni pendant la vérification.
5. Retirer la microSD, brancher la Pocket 3 sur un port USB de données,
   sélectionner **webcam** sur son écran, puis rallumer. La vidéo et le son
   doivent démarrer sans assistant de configuration.

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
sauvegarde hors ligne de l'eMMC fonctionnelle, flash d'une nouvelle microSD,
installation réelle, démarrage à froid sans microSD, image mobile 1080i50 et
son du micro. Le [compte rendu de la BELABOX personnelle](BELABOX_VALIDATION_2026-10-26.md)
ne vaut pas validation de l'image publique.

L'[ancien installateur NVMe](NVME_INSTALLER_LEGACY.md) est conservé comme
archive technique séparée.
