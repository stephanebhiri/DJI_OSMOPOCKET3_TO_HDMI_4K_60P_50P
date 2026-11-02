# Retrouver la sauvegarde privée de la BELABOX

La capture de l'eMMC fonctionnelle du 2 novembre 2026 et sa copie de secours
réparée sont archivées dans le compte Cloudflare de Stéphane : bucket privé
`osmo2hdmi-backups`, préfixe `belabox/2026-11-02/`. Ce bucket doit rester privé,
car les images contiennent les clés SSH de la machine.

## Récupération sur un Mac disposant de Wrangler et Python 3

Se connecter au compte Cloudflare propriétaire, puis récupérer les petits
fichiers décrivant la sauvegarde dans un dossier vide :

```sh
wrangler login
mkdir -p osmo-rescue
cd osmo-rescue
wrangler r2 object get osmo2hdmi-backups/belabox/2026-11-02/manifest.json --remote --file manifest.json
wrangler r2 object get osmo2hdmi-backups/belabox/2026-11-02/restore.py --remote --file restore.py
python3 restore.py --output .
```

Cette commande télécharge les blocs de la **copie de secours réparée**, les
assemble dans l'ordre et vérifie chaque bloc ainsi que le SHA-256 final. Il
faut environ 1,9 Go libres. Ajouter `--exact` pour récupérer la capture brute
originale compressée à la place. Le script ne flashe aucun disque.

Sur le Mac d'origine, les petits fichiers sont aussi conservés dans
`/Users/stephane/OSMO2HDMI/cloud-backup/` ; exécuter directement son
`restore.py` avec `--output` suivi du dossier de destination.

## Archives attendues

| Archive | SHA-256 du gzip |
| --- | --- |
| `OSMO2HDMI-BELABOX-working-2026-11-02.img.gz` | `1404eecda874f7e71c7dff04d01d6463d8993c6309ca011b3b43d185ec93447f` |
| `OSMO2HDMI-BELABOX-working-2026-11-02-rescue.img.gz` | `5faaa6ba4de4c4e332f1c3e7818cde8a1acaf50619b5293390d2` |

Les archives sont stockées en blocs de 256 Mio maximum pour utiliser l'accès
R2 déjà disponible par Wrangler. `manifest.json` contient l'ordre, la taille
et l'empreinte de chaque bloc. Le fichier gzip téléchargé reste à décompresser
avant un flash MaskROM selon le [guide eMMC](BELABOX_EMMC_RUNBOOK_FR.md).

La copie de secours a passé les contrôles ext4, GPT et d'identité des scripts
hors ligne. **Son flash et son démarrage physique n'ont pas encore été testés.**
Le démarrage de l'eMMC originale après capture a été confirmé avec image et
son. L'installateur public microSD v4 reste un candidat distinct, qui nécessite
sa propre validation matérielle.

## Contrôle des identifiants inclus

L'archive de secours a été récupérée de R2 et vérifiée par SHA-256 pour un
contrôle hors ligne le 2 novembre. `/root/.ssh` contient une seule clé
**publique** dans `authorized_keys`, correspondant à `id_ed25519.pub` du Mac.
La clé privée du Mac n'y figure pas. Les clés privées détectées dans `/root`,
`/etc` et `/usr/local` sont les trois clés d'identité SSH du serveur de cette
Orange Pi (`ssh_host_*_key`). Le mot de passe root est verrouillé ; `/home`,
`/opt`, `/var/lib/private` et `/var/lib/git` sont vides. Aucune configuration
Wi-Fi avec mot de passe, clé privée de connexion à une autre machine, ni
identifiant cloud n'a été détecté dans les configurations et scripts examinés.
Ce contrôle porte sur les fichiers actifs de ces emplacements, pas sur une
recherche forensique dans les blocs supprimés du système de fichiers.

La clé publique de maintenance peut aussi être autorisée sur d'autres
machines : sa présence ne permet pas de s'y connecter sans la clé privée
conservée sur le Mac. Pour distribuer une image à d'autres personnes, utiliser
la finalisation publique du dépôt, qui retire les autorisations personnelles
et les clés d'identité SSH héritées. Une copie personnelle restaurée sur
plusieurs appareils conserverait autrement la même identité SSH.
