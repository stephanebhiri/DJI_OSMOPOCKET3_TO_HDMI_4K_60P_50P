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
