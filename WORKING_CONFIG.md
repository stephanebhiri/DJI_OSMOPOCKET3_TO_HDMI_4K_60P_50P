# Configuration Fonctionnelle DJI Osmo Pocket 3 → HDMI

**Date**: 2026-01-07
**Statut**: ✅ PARFAIT - NE PAS MODIFIER

## Résumé
- Sortie HDMI: 1080i50 (ou 1080p50)
- Vidéo source: 4K 50fps (3840x2160) depuis DJI Osmo Pocket 3
- Décodage matériel: Rockchip MPP
- CPU: ~25% d'utilisation
- Latence: Très faible
- Fluidité: Parfaite

---

## Configuration Système

### 1. Kernel Version (CRITIQUE - NE PAS METTRE À JOUR)
```
Version: 6.1.84-vendor-rk35xx
Package: linux-image-vendor-rk35xx 24.11.3
Statut: FIGÉ (apt-mark hold)
```

**⚠️ IMPORTANT**: Le kernel 6.1.115 (version 25.8.1+) cause des crashes USB avec la caméra DJI.
**NE JAMAIS** upgrader le kernel!

Pour vérifier que le kernel est bien figé:
```bash
ssh orangepiosmo "apt-mark showhold"
```

### 2. Paramètres Boot (/boot/armbianEnv.txt)
```
verbosity=1
bootlogo=false
console=both
extraargs=cma=256M video=HDMI-A-1:1920x1080@50 usbcore.quirks=2ca3:0023:i
overlay_prefix=rockchip-rk3588
fdtfile=rockchip/rk3588-orangepi-5-plus.dtb
rootdev=UUID=4fc6d775-65ad-4b7c-9f42-aa1d93926b68
rootfstype=ext4
usbstoragequirks=0x2537:0x1066:u,0x2537:0x1068:u
```

**Paramètres clés**:
- `video=HDMI-A-1:1920x1080@50` - Force sortie HDMI 1080p50
- `usbcore.quirks=2ca3:0023:i` - Quirk USB pour DJI (tenté mais non efficace, peut être retiré)
- `cma=256M` - Mémoire continue pour MPP

### 3. Pipeline GStreamer (/usr/local/bin/dji-stream.sh)
```bash
#!/bin/bash

# DJI Osmo Pocket 3 streaming wrapper script
# Exits cleanly on errors so systemd can restart

exec /usr/bin/gst-launch-1.0 \
    libuvch264src index=0 ! video/x-h264,width=3840,height=2160,framerate=50/1 ! \
    h264parse ! mppvideodec ! \
    kmssink plane-id=72 connector-id=215 sync=false \
    alsasrc device=hw:4,0 ! audioconvert ! audioresample ! alsasink device=hw:1,0
```

**Paramètres critiques**:
- `plane-id=72` - Plan DRM overlay supportant NV12 (vérifié avec modetest)
- `connector-id=215` - Connecteur HDMI-A-1 (vérifié avec modetest)
- `width=3840,height=2160,framerate=50/1` - Résolution native de la caméra
- `hw:4,0` - Audio capture DJI
- `hw:1,0` - Audio HDMI output

### 4. Service Systemd (/etc/systemd/system/dji-h264-stream.service)
```ini
[Unit]
Description=DJI Osmo Pocket 3 H264 4K 50fps Stream to HDMI with Audio
After=network.target sound.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dji-stream.sh
Restart=always
RestartSec=3
Nice=-10
IOSchedulingClass=realtime

[Install]
WantedBy=multi-user.target
```

**Configuration**:
- Auto-start au boot: ✅ enabled
- Redémarrage automatique: ✅ après 3 secondes
- Priorité temps réel: ✅ Nice=-10

### 5. Règles udev

#### /etc/udev/rules.d/99-dji-camera.rules
```
# Restart DJI streaming service when camera is reconnected
ACTION=="add", SUBSYSTEM=="video4linux", ATTRS{idVendor}=="2ca3", ATTRS{idProduct}=="0023", RUN+="/bin/systemctl restart dji-h264-stream.service"
```

#### /etc/udev/rules.d/99-dma-heap.rules
```
# Udev rules for DMA heap access (Rockchip MPP hardware decode)
KERNEL=="dma_heap", MODE="0666"
SUBSYSTEM=="dma_heap", KERNEL=="system", MODE="0666"
SUBSYSTEM=="dma_heap", KERNEL=="system-uncached", MODE="0666"
SUBSYSTEM=="dma_heap", KERNEL=="reserved", MODE="0666"

# MPP service device
KERNEL=="mpp_service", MODE="0666"
```

---

## Périphériques Audio

```
Capture:
- carte 4 : DJIPocket3 [DJIPocket3], périphérique 0 : USB Audio [USB Audio]
  → hw:4,0

Playback:
- carte 1 : rockchip-hdmi0 [rockchip-hdmi0], périphérique 0
  → hw:1,0
```

---

## Performance

- **CPU Usage**: ~25% (gst-launch-1.0 process)
- **Memory**: ~90 MB
- **Load Average**: 1.0-1.3 (normal pour 4K 50fps)
- **Décodage**: 100% matériel via Rockchip MPP VPU
- **Format interne**: NV12 (zero-copy vers overlay plane)

---

## Dépannage

### La caméra ne se connecte pas en mode UVC
- Débrancher/rebrancher la caméra
- Elle commence en mode RNDIS (0x0020) puis bascule en UVC (0x0023)
- Vérifier: `lsusb | grep 2ca3`

### Le service ne démarre pas
```bash
sudo systemctl status dji-h264-stream.service
sudo journalctl -u dji-h264-stream.service -n 50
```

### Vérifier les IDs DRM (si changement de moniteur)
```bash
sudo modetest -M rockchip | grep -E "connector.*HDMI.*connected"
sudo modetest -M rockchip -p | grep -B 1 "NV12" | grep -E '^[0-9]+'
```

### Tester manuellement
```bash
sudo systemctl stop dji-h264-stream.service
sudo /usr/local/bin/dji-stream.sh
```

---

## Commandes de Vérification

### Vérifier que tout fonctionne
```bash
# Kernel version
ssh orangepiosmo "uname -r"
# Devrait afficher: 6.1.84-vendor-rk35xx

# Service actif
ssh orangepiosmo "sudo systemctl is-active dji-h264-stream.service"
# Devrait afficher: active

# CPU usage
ssh orangepiosmo "ps aux | grep '[g]st-launch'"
# Devrait montrer ~25-30% CPU

# Caméra connectée
ssh orangepiosmo "lsusb | grep 2ca3"
# Devrait afficher: Bus 001 Device XXX: ID 2ca3:0023 DJI Technology Co., Ltd. DJIPocket3
```

---

## NE PAS FAIRE

❌ **Ne PAS upgrader le kernel** (figé sur 6.1.84)
❌ **Ne PAS modifier** `/boot/armbianEnv.txt` sans backup
❌ **Ne PAS changer** plane-id ou connector-id sans vérifier avec modetest
❌ **Ne PAS exécuter** `apt-get upgrade` sans exclure le kernel

---

## Backup Configuration

Pour sauvegarder la configuration actuelle:
```bash
ssh orangepiosmo "tar czf /tmp/dji-config-backup.tar.gz \
  /boot/armbianEnv.txt \
  /usr/local/bin/dji-stream.sh \
  /etc/systemd/system/dji-h264-stream.service \
  /etc/udev/rules.d/99-dji-camera.rules \
  /etc/udev/rules.d/99-dma-heap.rules"

scp orangepiosmo:/tmp/dji-config-backup.tar.gz ~/Desktop/
```

---

## Historique des Modifications

### 2026-01-07
- ✅ Downgrade kernel: 6.1.115 → 6.1.84
- ✅ Correction plane-id: 73 → 72
- ✅ Correction connector-id: 217 → 215
- ✅ Ajout 99-dma-heap.rules
- ✅ Configuration HDMI: 1920x1080@50
- ✅ Kernel figé (apt-mark hold)
- ✅ **Statut: PARFAIT - Fluidité excellente, latence très faible**
