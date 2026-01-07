# DJI Osmo Pocket 3 → HDMI 4K Streaming

![Status](https://img.shields.io/badge/status-tested%20%26%20working-brightgreen)
![Kernel](https://img.shields.io/badge/kernel-6.1.84--vendor--rk35xx-blue)
![Platform](https://img.shields.io/badge/platform-OrangePi%205%20Plus%20%7C%20RK3588-orange)

Hardware-accelerated H264 streaming from DJI Osmo Pocket 3 to HDMI with Rockchip MPP decoder.

**🎯 Tested Configuration (2026-01-07)**
- ✅ OrangePi 5 Plus (RK3588)
- ✅ Armbian Debian 12 (Bookworm)
- ✅ Kernel 6.1.84-vendor-rk35xx
- ✅ 4K 50fps → Hardware decode → HDMI 1080p50
- ✅ CPU: ~25%, Latence: <100ms, Fluidité: Parfaite

---

## 🚀 Installation Rapide (Recommandée)

**Une seule commande pour tout installer:**

```bash
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
chmod +x install-working-config.sh
./install-working-config.sh
```

Le script installe:
- Kernel 6.1.84 (figé pour éviter les upgrades)
- Rockchip MPP (décodage hardware)
- GStreamer + plugins (mppvideodec, libuvch264src)
- Configuration HDMI 1080p50
- Service systemd auto-start
- IDs pré-configurés (plane-id=72, connector-id=215)

**Installation: ~15-20 minutes**

Après reboot, brancher la caméra DJI = ça marche! 🎥

---

## 🎛️ Bouton GPIO - Toggle HDMI Mode (Optionnel)

Basculer entre **1080i50** (entrelacé) et **1080p50** (progressif) avec un bouton physique:

```bash
chmod +x install-gpio-button.sh
./install-gpio-button.sh
```

Connexion: **Pin 7 (GPIO3_A4) ──── Bouton ──── GND**

📘 Guide complet: **[GPIO_BUTTON_GUIDE.md](GPIO_BUTTON_GUIDE.md)**

---

## 📖 Documentation

- **[INSTALL_GUIDE.md](INSTALL_GUIDE.md)** - Guide d'installation détaillé
- **[WORKING_CONFIG.md](WORKING_CONFIG.md)** - Configuration technique complète
- **[GPIO_BUTTON_GUIDE.md](GPIO_BUTTON_GUIDE.md)** - Toggle HDMI mode avec bouton
- **[README_DETAILED.md](README_DETAILED.md)** - Documentation projet originale

---

## ✅ Vérification Rapide

```bash
./QUICK_CHECK.sh
```

---

## 🔧 Troubleshooting

### Service ne démarre pas
```bash
sudo systemctl status dji-h264-stream.service
sudo journalctl -u dji-h264-stream.service -n 50
```

### Pas d'image
1. Vérifier moniteur HDMI connecté avant boot
2. Débrancher/rebrancher caméra DJI

### Caméra non détectée
```bash
lsusb | grep 2ca3  # Devrait afficher ID 2ca3:0023
```

Plus d'infos → **[WORKING_CONFIG.md](WORKING_CONFIG.md)**

---

## 📊 Performance

| Métrique | Valeur |
|----------|--------|
| Résolution source | 4K 50fps (3840x2160) |
| Sortie HDMI | 1080p50 |
| CPU Usage | ~25-30% |
| Latence | < 100ms |
| Décodage | 100% hardware (MPP) |

---

## ⚠️ Important

**NE JAMAIS upgrader le kernel!**

Le kernel 6.1.115+ cause des crashes USB avec la DJI Osmo Pocket 3.
Le script fige automatiquement le kernel sur 6.1.84.

Vérifier: `apt-mark showhold` → doit afficher `linux-image-vendor-rk35xx`

---

## 🤝 Contribuer

Issues et PRs bienvenues sur GitHub!

---

## 📝 Licence

MIT License
