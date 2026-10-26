# Validation de l'installateur public microSD → eMMC

## Construction vérifiée

- Source du projet au moment de la construction : `3b289c4`.
- Base : Armbian 25.8.1 Noble vendor 6.1.115, archive SHA-256
  `8fc641e84f10d2a64ec0539da82c93c64059cdb672c2e06dacbd7e9527920478`.
- Architecture de construction : Linux ARM64 isolé ; image brute de 6 Gio.
- SHA-256 du brut : `443d2c0077a754c232e66e5298f1326f2abe971c1ea7c7468dc2fd79008d043a`.
- Archive `.img.gz` : 1 525 088 694 octets ; SHA-256
  `4d2a50b7ccc1e3b086dae303c6206643798c417458489eed353579fa3814b062`.
- Contrôles terminés : base vérifiée, sources externes aux révisions fixées,
  GStreamer et modules compilés, audit des comptes/SSH/identifiants, manifeste
  des fichiers critiques, `e2fsck` final sans erreur, intégrité Gzip, SHA-256
  identique après transfert sur le Mac.

## Essai matériel

| Étape | Résultat |
| --- | --- |
| microSD physique | Lecteur USB du Mac, `/dev/disk6`, 31,3 Go. Effacement explicitement confirmé par le propriétaire. |
| Écriture et vérification de la microSD | Raspberry Pi Imager 1.9.6 a annoncé « Écriture réussie », puis éjecté la carte. Les anciens réglages de personnalisation n'ont pas été appliqués. |
| Démarrage réel sur microSD | À vérifier. |
| Installation eMMC, comparaison et agrandissement | À vérifier. |
| Démarrage à froid sans microSD | À vérifier. |
| Image mobile 1080i50 et son Pocket 3 | À confirmer physiquement. |

Le propriétaire a explicitement renoncé à une sauvegarde complète de l'eMMC
actuellement fonctionnelle avant cet essai. La seule image de secours locale
existante précède des corrections finales ; elle ne constitue pas une copie
exacte de cette eMMC. La nouvelle image ne sera publiée qu'après les contrôles
matériels ci-dessus.
