# Validation de l'installateur public microSD → eMMC

## Premier candidat rejeté après essai matériel

- Source du projet au moment de la construction : `3b289c4`.
- Base : Armbian 25.8.1 Noble vendor 6.1.115, archive SHA-256
  `8fc641e84f10d2a64ec0539da82c93c64059cdb672c2e06dacbd7e9527920478`.
- Architecture de construction : Linux ARM64 isolé ; image brute de 6 Gio.
- SHA-256 du brut : `443d2c0077a754c232e66e5298f1326f2abe971c1ea7c7468dc2fd79008d043a`.
- Archive `.img.gz` : 1 525 088 694 octets ; SHA-256
  `4d2a50b7ccc1e3b086dae303c6206643798c417458489eed353579fa3814b062`.
- Contrôles statiques terminés : base vérifiée, sources externes aux révisions fixées,
  GStreamer et modules compilés, audit des comptes/SSH/identifiants, manifeste
  des fichiers critiques, `e2fsck` final sans erreur, intégrité Gzip, SHA-256
  identique après transfert sur le Mac. **Ces contrôles n'ont pas suffi.**

La microSD du premier candidat a bien démarré : l'ancien SSH de l'eMMC ne
répondait plus et l'écran a demandé « Create root password ». Cette demande
contredit l'objectif de démarrage autonome. L'image ne doit pas être publiée.
Après retrait de la microSD, l'ancien système eMMC a redémarré sur l'adresse
DHCP `192.168.75.64` ; sa racine était `/dev/mmcblk0p1`. L'eMMC était donc
intacte. L'écran montrait alors `osmo2hdmi login:` parce qu'il était branché
sur HDMI-A-1, tandis que le service de cette installation attend HDMI-A-2.
La connexion sur HDMI-A-2, près des ports Ethernet, a rendu l'image Pocket 3.
Le propriétaire a aussi évoqué un moniteur informatique pendant l'essai : une
incompatibilité de ce moniteur avec 1080i50 reste possible, mais non établie.
La cause a été retracée dans Armbian : `/root/.not_logged_in_yet` active
`/etc/profile.d/armbian-check-first-login.sh`, tandis que deux surcharges
`getty` connectent automatiquement root sur la console. La désactivation du
service `armbian-firstrun` ne supprimait ni le marqueur ni l'autologin.
Le test de finalisation reproduit maintenant cette configuration et refuse
l'image tant qu'elle subsiste. Correction source : `e3c54f2`.

Après l'arrêt, la carte revenue au Mac montrait une partition Linux de
30,9 Go au lieu de 6 Gio. La base Armbian active
`armbian-resize-filesystem.service` depuis `basic.target.wants`, avant notre
service eMMC. La première finalisation ne supprimait que la liaison dans
`multi-user.target.wants`. La vérification de taille de l'installateur refuse
alors cette carte avant toute écriture eMMC. Le test de finalisation reproduit
désormais cette liaison réelle et impose son masquage. Correction source :
`93a575a`.

## Candidat corrigé à reconstruire

La deuxième construction a été interrompue dès la découverte du
redimensionnement Armbian ; aucun artefact de cette tentative n'a été utilisé.
La prochaine image doit intégrer les deux corrections. SHA-256 et nouvel essai
matériel seront ajoutés après production du fichier.

## Essai matériel

| Étape | Résultat |
| --- | --- |
| microSD physique | Lecteur USB du Mac, `/dev/disk6`, 31,3 Go. Effacement explicitement confirmé par le propriétaire. |
| Écriture et vérification de la première microSD | Raspberry Pi Imager 1.9.6 a annoncé « Écriture réussie », puis éjecté la carte. Les anciens réglages de personnalisation n'ont pas été appliqués. |
| Démarrage réel sur microSD | Confirmé pour le premier candidat par l'absence de l'ancien SSH et la console Armbian. La version corrigée reste à tester. |
| Installation eMMC, comparaison et agrandissement | À vérifier. |
| Démarrage à froid sans microSD | À vérifier. |
| Image mobile 1080i50 et son Pocket 3 | À confirmer physiquement. |

Le propriétaire a explicitement renoncé à une sauvegarde complète de l'eMMC
actuellement fonctionnelle avant cet essai. La seule image de secours locale
existante précède des corrections finales ; elle ne constitue pas une copie
exacte de cette eMMC. La nouvelle image ne sera publiée qu'après les contrôles
matériels ci-dessus.
