# Configuration Validée - Ubuntu Noble 24.04

✅ **Testé et fonctionnel le 8 janvier 2026**

## ⚠️ Important: Noble vs Trixie

**✅ UTILISER: Ubuntu Noble 24.04 (ou Armbian Bookworm)**
- GStreamer 1.24.2
- Compatible avec libuvch264src (BELABOX fork)

**❌ NE PAS UTILISER: Debian Trixie**
- GStreamer 1.26
- **INCOMPATIBLE** avec libuvch264src (BELABOX fork)
- Erreur: "Unable to get stream control: Invalid mode"

## Système Validé

- **OS**: Armbian 25.11.1 Noble (Ubuntu 24.04)
- **Kernel**: 6.1.115-vendor-rk35xx
- **GStreamer**: 1.24.2
- **Hardware**: Orange Pi 5 Plus (RK3588)

## Configuration DJI

Le DJI Osmo Pocket 3 s'adapte automatiquement à la demande du receiver.

**Configuration validée:**
- **Résolution**: 4K (3840x2160)
- **Framerate**: 50 fps
- **Format**: H.264

## Configuration HDMI

**Boot parameters** (`/boot/armbianEnv.txt`):
```
extraargs=usbcore.quirks=2ca3:0023:i video=HDMI-A-1:1920x1080i@50 cma=256M
```

**KMS sink parameters:**
- `plane-id=73` (supporte NV12 pour MPP)
- `connector-id=215` (HDMI-A-1)

⚠️ **Note**: `plane-id=72` ne marche PAS (erreur "Invalid argument")

## Pipeline GStreamer Validé

```bash
gst-launch-1.0 \
    libuvch264src index=0 ! video/x-h264,width=3840,height=2160,framerate=50/1 ! \
    h264parse ! mppvideodec ! \
    kmssink plane-id=73 connector-id=215 sync=false
```

## Performances

- **CPU**: ~43% (décodage hardware MPP)
- **RAM**: ~92 MB (stable)
- **Latence**: Faible (~50-100ms)

## Fichiers Modifiés

### 1. `/etc/udev/rules.d/50-dji-usb.rules` (NOUVEAU)

```
SUBSYSTEM=="usb", ATTRS{idVendor}=="2ca3", ATTRS{idProduct}=="0023", MODE="0666", GROUP="video"
```

**Sans ce fichier**: Erreur "Access denied" au démarrage

### 2. `dji-stream.sh`

**Changements critiques:**
- `plane-id=72` → `plane-id=73` ✅
- Audio temporairement désactivé (pour stabilité)

### 3. `/boot/armbianEnv.txt`

**Ajout USB quirk:**
```
usbcore.quirks=2ca3:0023:i
```

## Installation sur Fresh Noble

1. **Flasher Ubuntu Noble 24.04 Minimal/IOT** (kernel 6.1 vendor)

2. **Configurer SSH avant boot** (optionnel):
```bash
# Monter la partition root
mkdir -p /tmp/armbi_root
mount /dev/sdX1 /tmp/armbi_root

# Ajouter clé SSH
mkdir -p /tmp/armbi_root/root/.ssh
cat ~/.ssh/id_rsa.pub > /tmp/armbi_root/root/.ssh/authorized_keys
chmod 700 /tmp/armbi_root/root/.ssh
chmod 600 /tmp/armbi_root/root/.ssh/authorized_keys

# Activer SSH
touch /tmp/armbi_root/boot/ssh

# Démonter
umount /tmp/armbi_root
```

3. **Booter et se connecter**:
```bash
# Login par défaut: orangepi / orangepi
ssh orangepi@<IP>
```

4. **Cloner le repo**:
```bash
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
```

5. **Installer**:
```bash
sudo ./install.sh
```

6. **Installer les permissions USB**:
```bash
sudo cp 50-dji-usb.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

7. **Configurer HDMI et USB quirk**:
```bash
sudo sed -i 's|extraargs=cma=256M|extraargs=usbcore.quirks=2ca3:0023:i video=HDMI-A-1:1920x1080i@50 cma=256M|' /boot/armbianEnv.txt
```

8. **Installer le script corrigé**:
```bash
sudo cp dji-stream.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dji-stream.sh
```

9. **Activer le service**:
```bash
sudo cp dji-h264-stream.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dji-h264-stream.service
```

10. **Rebooter**:
```bash
sudo reboot
```

11. **Brancher le DJI et vérifier**:
```bash
sudo systemctl status dji-h264-stream.service
```

## Dépannage

### Erreur "Access denied"
```bash
# Vérifier permissions USB
ls -la /dev/bus/usb/001/*

# Recharger udev
sudo udevadm control --reload-rules
sudo udevadm trigger

# Rebrancher le DJI
```

### Erreur "Invalid argument" (kmssink)
```bash
# Vérifier plane-id dans dji-stream.sh
cat /usr/local/bin/dji-stream.sh | grep plane-id

# Doit être: plane-id=73 (pas 72!)
```

### Pas de vidéo
```bash
# Vérifier que le service tourne
sudo systemctl status dji-h264-stream.service

# Voir les logs
sudo journalctl -u dji-h264-stream.service -f

# Tester manuellement
sudo systemctl stop dji-h264-stream.service
gst-launch-1.0 videotestsrc ! kmssink plane-id=73 connector-id=215
```

### OOM killer (mémoire)
Si le service est tué après quelques minutes, c'est normal - le service redémarre automatiquement (comportement observé mais stable après redémarrage).

## Commandes Utiles

```bash
# Statut du service
sudo systemctl status dji-h264-stream.service

# Redémarrer
sudo systemctl restart dji-h264-stream.service

# Arrêter/Démarrer
sudo systemctl stop dji-h264-stream.service
sudo systemctl start dji-h264-stream.service

# Logs en direct
sudo journalctl -u dji-h264-stream.service -f

# Vérifier DJI connecté
lsusb | grep -i dji

# Vérifier décodage
dmesg | grep -i "uvc\|dji"
```

## Différences avec Bookworm

Cette configuration est identique à Bookworm car Noble et Bookworm partagent **GStreamer 1.24**.

**Pourquoi ça marche:**
- BELABOX fork (jan 2025) développé pour GStreamer 1.24
- Noble = GStreamer 1.24 ✅
- Trixie = GStreamer 1.26 ❌ (changements d'API incompatibles)
