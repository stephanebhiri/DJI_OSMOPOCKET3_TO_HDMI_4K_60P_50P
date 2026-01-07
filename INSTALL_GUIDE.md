# Installation Guide - DJI Osmo Pocket 3 → HDMI 4K 50fps

**Configuration Testée et Validée - 2026-01-07**

## ⚠️ IMPORTANT: Deux Options d'Installation

### Option 1: Configuration Validée (RECOMMANDÉE) ✅

Cette option installe **exactement** la configuration qui fonctionne parfaitement:
- Kernel 6.1.84-vendor-rk35xx (figé)
- HDMI 1080p50
- IDs pré-configurés (plane-id=72, connector-id=215)
- Audio pré-configuré (hw:4,0 → hw:1,0)

```bash
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
chmod +x install-working-config.sh
./install-working-config.sh
```

Le système redémarrera automatiquement avec le bon kernel et la bonne config.

### Option 2: Installation Manuelle (AVANCÉE)

Si vous voulez configurer manuellement ou si vos IDs DRM sont différents:

```bash
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
chmod +x install.sh
./install.sh
```

Vous devrez ensuite configurer manuellement les IDs DRM et audio (voir README.md).

---

## Matériel Requis

- **SBC**: OrangePi 5 Plus (ou tout SBC avec Rockchip RK3588)
- **OS**: Armbian Debian 12 (Bookworm)
- **Caméra**: DJI Osmo Pocket 3
- **Connexion**: USB pour caméra, HDMI pour sortie

---

## Installation Rapide (Configuration Validée)

### 1. Préparer l'Orange Pi

Installer Armbian sur l'Orange Pi 5 Plus:
- Télécharger: [Armbian Bookworm pour Orange Pi 5 Plus](https://www.armbian.com/orangepi-5-plus/)
- Flasher sur carte SD/eMMC
- Démarrer et configurer (utilisateur, réseau, etc.)

### 2. Cloner et Installer

```bash
# Se connecter à l'Orange Pi en SSH
ssh root@<IP_ORANGE_PI>

# Installer git si nécessaire
apt-get update && apt-get install -y git

# Cloner le repo
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P

# Lancer l'installation
chmod +x install-working-config.sh
./install-working-config.sh
```

L'installation prend environ **15-20 minutes**.

### 3. Rebooter

Le script proposera de redémarrer automatiquement. Acceptez.

### 4. Connecter la Caméra

Après le reboot:
1. Brancher la DJI Osmo Pocket 3 en USB
2. La caméra va switcher du mode RNDIS (réseau) vers UVC (caméra)
3. Le service démarre automatiquement
4. La vidéo s'affiche sur HDMI

### 5. Vérifier

```bash
# Vérifier le service
sudo systemctl status dji-h264-stream.service

# Vérifier le kernel
uname -r
# Devrait afficher: 6.1.84-vendor-rk35xx

# Vérifier la caméra
lsusb | grep 2ca3
# Devrait afficher: ID 2ca3:0023 DJI Technology Co., Ltd. DJIPocket3
```

---

## Troubleshooting

### Le service ne démarre pas

```bash
# Voir les logs
sudo journalctl -u dji-h264-stream.service -n 50

# Redémarrer le service
sudo systemctl restart dji-h264-stream.service
```

### Pas d'image sur HDMI

1. Vérifier que le moniteur est connecté **avant** le démarrage
2. Vérifier les paramètres boot:
   ```bash
   cat /boot/armbianEnv.txt | grep extraargs
   ```
   Devrait contenir: `video=HDMI-A-1:1920x1080@50`

3. Tester manuellement:
   ```bash
   sudo systemctl stop dji-h264-stream.service
   sudo /usr/local/bin/dji-stream.sh
   ```

### La caméra ne se connecte pas

1. Débrancher/rebrancher la caméra
2. Vérifier qu'elle passe en mode UVC (0x0023):
   ```bash
   lsusb | grep 2ca3
   ```
3. Si elle reste en mode RNDIS (0x0020), attendre quelques secondes

### CPU élevé

- CPU normal: 25-30% pour 4K 50fps
- Si > 50%: vérifier que MPP fonctionne:
  ```bash
  sudo journalctl -u dji-h264-stream.service | grep "mpp"
  ```

---

## Configuration Détaillée

Pour comprendre la configuration complète, voir:
- `WORKING_CONFIG.md` - Configuration technique détaillée
- `README.md` - Documentation complète du projet

---

## Maintenance

### Ne JAMAIS faire

❌ **Upgrader le kernel** (figé sur 6.1.84)
❌ Exécuter `apt-get upgrade` sans vérifier
❌ Modifier `/boot/armbianEnv.txt` sans backup

### Vous pouvez faire

✅ Redémarrer l'Orange Pi (tout redémarre auto)
✅ Débrancher/rebrancher la caméra (auto-restart)
✅ Redémarrer le service manuellement

---

## Vérification Rapide

Script de vérification rapide:

```bash
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
./QUICK_CHECK.sh
```

---

## Support

Pour les problèmes:
1. Vérifier `WORKING_CONFIG.md`
2. Exécuter `QUICK_CHECK.sh`
3. Ouvrir une issue sur GitHub avec les logs

---

## Performances

Configuration validée:
- **Résolution source**: 4K 50fps (3840x2160)
- **Sortie HDMI**: 1080p50
- **CPU**: ~25-30%
- **Latence**: < 100ms
- **Fluidité**: Parfaite, sans saccades
- **Décodage**: 100% matériel (Rockchip MPP)

---

## Licence

MIT License
