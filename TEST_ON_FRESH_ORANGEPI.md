# Test sur Orange Pi Neuf - Procédure Complète

Ce document décrit la procédure exacte pour tester l'installation sur un Orange Pi 5 Plus tout neuf.

## Prérequis

- Orange Pi 5 Plus (RK3588)
- Carte SD ou eMMC (minimum 8GB)
- Câble USB-C pour alimentation
- Câble HDMI
- DJI Osmo Pocket 3
- Moniteur HDMI

## Étape 1: Préparer la Carte SD

### Télécharger Armbian

1. Aller sur: https://www.armbian.com/orangepi-5-plus/
2. Télécharger: **Armbian Bookworm CLI** (dernière version stable)
3. Utiliser balenaEtcher ou dd pour flasher sur carte SD

### Flasher la Carte SD

**macOS/Linux (avec balenaEtcher):**
```bash
# Télécharger balenaEtcher: https://www.balena.io/etcher/
# 1. Sélectionner l'image Armbian
# 2. Sélectionner la carte SD
# 3. Cliquer "Flash!"
```

**macOS/Linux (avec dd):**
```bash
# Trouver le disque
diskutil list  # macOS
lsblk         # Linux

# Démonter
sudo diskutil unmountDisk /dev/diskX  # macOS
sudo umount /dev/sdX                  # Linux

# Flasher (remplacer /dev/diskX par le bon disque!)
sudo dd if=Armbian*.img of=/dev/diskX bs=1M status=progress

# Éjecter
sudo diskutil eject /dev/diskX  # macOS
sudo eject /dev/sdX            # Linux
```

## Étape 2: Premier Boot

1. Insérer la carte SD dans l'Orange Pi 5 Plus
2. Connecter le moniteur HDMI
3. Connecter l'alimentation USB-C
4. Attendre le boot (1-2 minutes)

### Configuration Initiale

Lors du premier boot, Armbian demande:

```
Login: root
Password: 1234

# Armbian demande de changer le mot de passe root
New root password: [votre_mot_de_passe]
Repeat: [votre_mot_de_passe]

# Créer un utilisateur (optionnel, appuyer Enter pour skip)
Create user: [Enter pour skip ou nom d'utilisateur]

# Configuration locale (optionnel)
Locales: [Enter pour garder par défaut]
```

### Connecter au Réseau

**Ethernet (recommandé pour l'installation):**
- Brancher câble Ethernet = connexion automatique

**WiFi:**
```bash
nmtui  # Interface graphique
# ou
nmcli device wifi list
nmcli device wifi connect "SSID" password "PASSWORD"
```

### Trouver l'IP

```bash
ip addr show
# ou
hostname -I
```

## Étape 3: Se Connecter en SSH

Depuis votre Mac:
```bash
ssh root@<IP_ORANGE_PI>
# Entrer le mot de passe root
```

## Étape 4: Mise à Jour Initiale (IMPORTANTE!)

```bash
# Mettre à jour la liste des paquets
apt-get update

# NE PAS faire apt-get upgrade maintenant!
# Le script install-working-config.sh va installer le bon kernel
```

## Étape 5: Installation DJI Configuration

```bash
# Installer git si nécessaire
apt-get install -y git

# Cloner le repo
cd /root
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P

# Vérifier les fichiers
ls -la
# Devrait voir: install-working-config.sh, INSTALL_GUIDE.md, etc.

# Lancer l'installation
chmod +x install-working-config.sh
./install-working-config.sh
```

### Pendant l'Installation

L'installation prend environ **15-20 minutes** et affiche:

```
[1/9] Installing kernel 6.1.84-vendor-rk35xx...
[2/9] Holding kernel package...
[3/9] Configuring boot parameters...
[4/9] Installing prerequisites...
[5/9] Installing Rockchip MPP...
[6/9] Installing gstreamer-rockchip...
[7/9] Installing libuvch264src...
[8/9] Installing udev rules and scripts...
[9/9] Installing systemd service...
```

À la fin, le script propose de redémarrer:
```
⚠️  REBOOT REQUIRED
Reboot now? (y/n)
```

**Répondre: y**

## Étape 6: Après Reboot

### Vérifier le Kernel

```bash
ssh root@<IP_ORANGE_PI>

# Vérifier kernel
uname -r
# Devrait afficher: 6.1.84-vendor-rk35xx

# Vérifier que le kernel est figé
apt-mark showhold
# Devrait afficher: linux-image-vendor-rk35xx
```

### Connecter la Caméra DJI

1. Brancher la DJI Osmo Pocket 3 en USB
2. Attendre 5-10 secondes (la caméra switch du mode RNDIS vers UVC)
3. Le service démarre automatiquement

### Vérifier le Service

```bash
# Status du service
sudo systemctl status dji-h264-stream.service
# Devrait afficher: Active: active (running)

# Vérifier la caméra
lsusb | grep 2ca3
# Devrait afficher: ID 2ca3:0023 DJI Technology Co., Ltd. DJIPocket3

# Vérifier CPU
ps aux | grep gst-launch
# CPU devrait être ~25-30%
```

### Vérifier l'Image HDMI

Sur le moniteur HDMI, vous devriez voir:
- Image fluide de la caméra DJI
- Pas de saccades
- Latence très faible (<100ms)

## Étape 7: Tests de Validation

### Test 1: Débrancher/Rebrancher Caméra

```bash
# Débrancher la caméra
# Attendre 3 secondes
# Rebrancher la caméra
# Attendre 5-10 secondes

# Vérifier que le service a redémarré
sudo systemctl status dji-h264-stream.service
```

**Résultat attendu:** Image réapparaît automatiquement

### Test 2: Reboot Complet

```bash
sudo reboot

# Après reboot, reconnecter en SSH
ssh root@<IP_ORANGE_PI>

# Brancher la caméra DJI
# Attendre 5-10 secondes

# Vérifier
sudo systemctl status dji-h264-stream.service
```

**Résultat attendu:** Service démarre automatiquement au boot

### Test 3: Vérification Complète

```bash
cd /root/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
./QUICK_CHECK.sh
```

**Résultat attendu:** Tous les checks sont OK

## Problèmes Courants

### Problème 1: Kernel Pas Changé

**Symptôme:** `uname -r` affiche toujours l'ancien kernel après reboot

**Solution:**
```bash
# Vérifier les kernels installés
dpkg -l | grep linux-image

# Vérifier le boot
cat /boot/armbianEnv.txt

# Réinstaller le bon kernel
sudo apt-get install --reinstall linux-image-vendor-rk35xx=24.11.3
sudo reboot
```

### Problème 2: Service Ne Démarre Pas

**Symptôme:** `systemctl status dji-h264-stream.service` montre "failed"

**Solution:**
```bash
# Voir les logs
sudo journalctl -u dji-h264-stream.service -n 50

# Vérifier que la caméra est bien en mode UVC (0x0023)
lsusb | grep 2ca3

# Tester manuellement
sudo systemctl stop dji-h264-stream.service
sudo /usr/local/bin/dji-stream.sh
```

### Problème 3: Pas d'Image HDMI

**Solutions à essayer:**
1. Vérifier que le moniteur était connecté **avant** le boot
2. Vérifier les paramètres boot:
   ```bash
   cat /boot/armbianEnv.txt | grep extraargs
   # Devrait contenir: video=HDMI-A-1:1920x1080@50
   ```
3. Redémarrer avec moniteur connecté

### Problème 4: CPU Trop Élevé (>50%)

**Diagnostic:**
```bash
# Vérifier que MPP fonctionne
sudo journalctl -u dji-h264-stream.service | grep "mpp"

# Devrait voir: mpp[XXXX]: hal_h264d_vdpu34x
```

**Si MPP ne fonctionne pas:**
```bash
# Vérifier permissions DMA heap
ls -la /dev/dma_heap/
# Devrait être: crw-rw-rw-

# Corriger si nécessaire
sudo chmod 666 /dev/dma_heap/*
sudo chmod 666 /dev/mpp_service

# Redémarrer service
sudo systemctl restart dji-h264-stream.service
```

## Checklist de Validation Finale

- [ ] Kernel = 6.1.84-vendor-rk35xx
- [ ] Kernel figé (apt-mark showhold)
- [ ] Service active (systemctl status)
- [ ] Caméra détectée (lsusb | grep 2ca3:0023)
- [ ] CPU ~25-30%
- [ ] Image fluide sur HDMI
- [ ] Latence < 100ms
- [ ] Débrancher/rebrancher = auto-restart OK
- [ ] Reboot = auto-start OK

Si tous les checks sont OK: **✅ Installation Réussie!**

## Sauvegarde Configuration

Une fois validé, créer un backup:

```bash
cd /root
sudo tar czf dji-working-backup-$(date +%Y%m%d).tar.gz \
  /boot/armbianEnv.txt \
  /usr/local/bin/dji-stream.sh \
  /etc/systemd/system/dji-h264-stream.service \
  /etc/udev/rules.d/99-*.rules \
  DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P/

# Copier sur votre Mac
scp root@<IP_ORANGE_PI>:~/dji-working-backup-*.tar.gz ~/Desktop/
```

## Temps Total Estimé

- Préparation carte SD: **10 minutes**
- Premier boot + config: **5 minutes**
- Installation complète: **20 minutes**
- Tests de validation: **10 minutes**

**Total: ~45 minutes** pour une installation complète sur Orange Pi neuf

## Support

En cas de problème:
1. Consulter `WORKING_CONFIG.md`
2. Exécuter `QUICK_CHECK.sh`
3. Vérifier les logs: `sudo journalctl -u dji-h264-stream.service -n 100`
4. Ouvrir une issue sur GitHub avec les logs
