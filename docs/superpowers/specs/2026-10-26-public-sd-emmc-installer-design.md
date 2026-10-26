# Image microSD publique installant OSMO2HDMI sur eMMC

Date : 26 octobre 2026. Statut : proposition à approuver avant l'implémentation.

## Intention

Un propriétaire d'Orange Pi 5 Plus doit pouvoir télécharger une image publique,
la graver sur une microSD saine, démarrer la carte, puis obtenir sur l'eMMC un
appareil Pocket 3 vers HDMI 1080i50 avec son. Il ne doit pas avoir à reconstruire
à la main les correctifs audio, UVC, HDMI ou le démarrage de la BELABOX testée.
L'image doit être construite à partir des sources du dépôt, sans clone de
l'installation personnelle.

## Parcours utilisateur retenu

1. Télécharger l'image compressée de l'installateur et son SHA-256 depuis une
   publication GitHub. Vérifier le hash et graver une microSD saine d'au moins
   16 Go avec un outil qui vérifie l'écriture.
2. Orange Pi 5 Plus éteinte : insérer la microSD, relier l'écran à HDMI-A-2
   avec un EDID offrant 1080i50 et, pour le test final, la Pocket 3 en mode webcam.
   Mettre sous tension. L'installation n'a lieu que si le noyau démarre
   effectivement depuis la microSD.
3. L'installateur identifie le modèle, la microSD source et l'unique eMMC cible,
   vérifie son contenu et sa taille, puis affiche clairement la cible qu'il va
   effacer. Il copie le système complet sur l'eMMC, relit et compare tous les
   octets copiés, vérifie le système de fichiers hors montage et agrandit la
   partition eMMC. Il désactive sa propre exécution sur la cible et active
   HDMI, vidéo et audio. Il écrit un résultat durable et éteint la carte.
4. Retirer la microSD et rallumer. Le système démarre depuis l'eMMC ; le mode
   1080i50, l'image mobile et le son du micro sont contrôlés physiquement.

La carte installatrice est autonome après son démarrage. Elle ne peut pas
forcer un firmware qui a choisi l'eMMC ou le SPI à démarrer sur microSD. Si
c'est le cas, la documentation décrit la sélection ou la récupération du
support de démarrage ; elle ne prétend pas que l'installation a eu lieu.

## Périmètre

- Cible : Orange Pi 5 Plus RK3588 avec une seule eMMC libre d'au moins 8 Go.
  Le nom /dev/mmcblkN n'est jamais figé. Aucun NVMe ou disque USB n'est effacé.
- Base : Armbian 25.8.1 Ubuntu Noble minimal, noyau fournisseur 6.1.115,
  image de base vérifiée par SHA-256. GStreamer 1.24, Rockchip MPP et
  gstlibuvch264src aux révisions indiquées dans image/source-lock.txt.
- Correctifs inclus : négociation UVC 1080p30→4K50, découverte dynamique
  d'un plan KMS NV12 compatible avec le CRTC de HDMI-A-2 (le plan 114 n'est
  qu'une mesure sur la BELABOX testée), découverte dynamique du mode EDID
  1080i50, son HDMI nommé et redémarrage vidéo après une erreur initiale.
  L'ancien argument de démarrage qui vise HDMI-A-1 doit être supprimé ou
  corrigé pour éviter une contradiction avec la sortie HDMI-A-2 supportée.
- Aucune clé SSH, aucun mot de passe commun, aucune identité machine ou donnée
  réseau personnelle dans l'image publique. SSH est désactivé par défaut ;
  l'appareil vidéo doit fonctionner sans compte de maintenance préinstallé.
  Une image personnalisée avec une clé publique peut être produite localement
  sans être publiée. Les erreurs d'installation sont visibles sur HDMI/UART
  et dans l'état conservé sur la carte ; la récupération avancée peut se faire
  en démarrant une microSD Armbian de maintenance et en montant l'eMMC. Ce
  choix privilégie le démarrage vidéo immédiat plutôt qu'un assistant de
  création de compte qui bloquerait la sortie HDMI.
- Les anciens installateurs NVMe et images retirées restent historiques ; ils
  ne sont pas la base de cette nouvelle publication.

## Construction et contrôles

- Ajouter un script de construction qui refuse une base ou des révisions
  inattendues, prépare un système ARM64 sur une machine Linux, applique
  image/provision-rootfs.sh, installe et active uniquement le service
  d'installation sur l'image microSD, et produit image brute, compression,
  SHA-256 et manifeste des versions.
- Prévoir au moins 20 Go d'espace de travail temporaire pour la base, l'image,
  les montages et la compression. Le Mac n'a actuellement qu'environ 12 Go
  libres ; utiliser un stockage de travail adapté ou archiver les anciens
  artefacts après vérification, sans supprimer la sauvegarde personnelle.
- Ajouter une finalisation publique distincte de
  image/finalize-runtime-image.sh, qui contient une clé personnelle. Vérifier
  hors ligne l'absence de clés, mots de passe connus, journaux et identifiants
  propres à la BELABOX. Ne pas utiliser le clone personnel comme image source.
- Faire fonctionner l'installateur avant les services vidéo, avec la source
  microSD figée en lecture seule durant la copie. En cas d'erreur, ne pas
  annoncer la réussite ni éteindre comme si l'installation était terminée.
  L'écriture sur eMMC ne commence qu'après les vérifications de modèle,
  support de démarrage, cible unique, capacité et contenu source.
- Tester les refus sûrs avec des périphériques simulés, puis le parcours de
  copie et de comparaison sur des fichiers disques de test. Vérifier la
  syntaxe, le contenu de l'image, la taille, les hashes et le démarrage des
  services installés.
- Sur le matériel réel, utiliser la nouvelle microSD saine. Avant de tester
  l'effacement de l'eMMC fonctionnelle, conserver hors ligne en MaskROM une
  sauvegarde vérifiée des 6 Gio initiaux qui contiennent l'unique partition
  système et le chargeur, ainsi que l'en-tête GPT de fin de disque. Il n'est
  pas nécessaire de copier les 61,9 Go, dont la majeure partie est hors
  partition ; documenter la réparation du GPT lors d'une restauration.
  Le test final exige démarrage de
  la microSD, installation, retrait de la carte, démarrage à froid sur eMMC,
  mode 1080i50, image mobile, son et absence d'erreur ext4.
- Publier l'image et son hash seulement après ce test de bout en bout. Le
  README doit dire exactement quel matériel a été testé et mentionner que
  le premier lancement vidéo peut encore subir un SIGSEGV dont la cause
  interne n'est pas résolue, même si systemd le récupère.
- Le fichier compressé doit rester sous la [limite GitHub de 2 Gio par
  fichier de release](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
  Si ce seuil est dépassé, suspendre la publication et choisir un hébergement
  adapté avec l'utilisateur, sans remettre un gros binaire dans Git.

## Choix et limites à garder visibles

- Le format est une image microSD autonome qui installe l'eMMC. C'est le
  choix exprimé par l'utilisateur ; le chemin Mac MaskROM reste une voie
  de récupération, pas le parcours ordinaire.
- L'image est publique pour d'autres Orange Pi 5 Plus. La base propre et la
  séparation des clés personnelles en découlent.
- L'utilisateur a choisi le démarrage immédiat de la vidéo et du son, avec
  SSH désactivé par défaut, sans écran de création de compte préalable.
- La nouvelle microSD saine annoncée par l'utilisateur sert au test matériel.
  L'ancienne microSD qui a corrompu ext4 est exclue.
- L'installation peut effacer l'eMMC uniquement lorsque la microSD installatrice
  est réellement le support de démarrage et que tous les contrôles passent.
  Les cas de firmware qui démarre ailleurs sont signalés comme non couverts
  automatiquement.
- L'écran doit exposer 1080i50 sur HDMI-A-2 pour que le résultat annoncé soit
  vérifiable. Si ce mode manque, l'installateur s'arrête avant effacement ou
  exige un parcours explicitement non validé ; il ne sélectionne pas 1080p60
  silencieusement.
- La cause interne du SIGSEGV du premier lancement vidéo n'est pas connue.
  Le projet ne doit pas revendiquer une stabilité absolue tant qu'elle n'a
  pas été diagnostiquée et corrigée.
