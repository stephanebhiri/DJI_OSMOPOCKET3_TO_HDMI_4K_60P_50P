# GPIO Buttons - HDMI Mode Selection (1080i50 / 1080p50)

## 🎯 Deux Options Disponibles

### Option 1: Dual Button (RECOMMANDÉE) ✅

Deux boutons physiques pour sélectionner directement le mode:
- **Bouton 1 (Pin 7)**: Force **1080i50** (entrelacé) + reboot
- **Bouton 2 (Pin 11)**: Force **1080p50** (progressif) + reboot
- Pas d'ambiguïté - vous savez exactement quel mode vous obtenez

### Option 2: Single Button Toggle

Un seul bouton qui bascule entre les modes:
- **1080i50** (entrelacé) ↔ **1080p50** (progressif)
- Appui sur bouton → Change le mode → Redémarre automatiquement

**Ce guide couvre les deux options.**

---

## 🔌 Option 1: Dual Button Setup (Recommandée)

### Câblage Matériel

```
Orange Pi 5 Plus (40-pin header)
┌─────────────────┐
│  1  3.3V        │
│  3  ...         │
│  5  ...         │
│  7  GPIO3_A4 ●──┼─── Button 1 (1080i50) ───┐
│  9  GND      ●──┼────────────────────────────┼── GND
│ 11  GPIO3_A5 ●──┼─── Button 2 (1080p50) ───┘
│ 13  ...         │
└─────────────────┘
```

**Configuration:**
- **Button 1**: Pin 7 (GPIO3_A4 / GPIO 100) → 1080i50 (interlacé)
- **Button 2**: Pin 11 (GPIO3_A5 / GPIO 101) → 1080p50 (progressif)
- **GND commun**: Pin 9 ou Pin 14

### Installation

```bash
# Sur l'Orange Pi
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P
chmod +x install-hdmi-buttons.sh
./install-hdmi-buttons.sh
```

### Utilisation

1. **Appuyer sur Button 1 (Pin 7)** → Passe en 1080i50 + reboot
2. **Appuyer sur Button 2 (Pin 11)** → Passe en 1080p50 + reboot

**Simple et sans ambiguïté!**

---

## 🔌 Option 2: Single Button Toggle

### Câblage Matériel

---

## 🔌 Câblage Matériel

### Orange Pi 5 Plus - GPIO Pinout

```
Pin physique 7 (GPIO3_A4 / GPIO 100)
     |
   Button ────┐
              │
              GND (Pin 9 ou autre GND)
```

**Configuration:**
- **GPIO Pin**: 100 (GPIO3_A4, pin physique 7 sur le header 40 pins)
- **Résistance pull-up**: Activée en interne (pas besoin de résistance externe)
- **Logique**: LOW (0V) quand bouton pressé, HIGH (3.3V) quand relâché

### Schéma de Connexion

```
Orange Pi 5 Plus (40-pin header)
┌─────────────────┐
│  1  3.3V        │
│  3  ...         │
│  5  ...         │
│  7  GPIO3_A4 ●──┼─── Bouton ─── GND
│  9  GND      ●──┘
│ 11  ...         │
│ ...             │
└─────────────────┘
```

**Bouton recommandé:**
- Bouton poussoir momentané (normalement ouvert)
- Type: tactile switch, arcade button, etc.
- Aucune résistance externe nécessaire

---

## 📦 Installation

### 1. Copier les Fichiers

```bash
# Sur l'Orange Pi
cd /tmp
git clone https://github.com/stephanebhiri/DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P.git
cd DJI_OSMOPOCKET3_TO_HDMI_4K_60P_50P

# Installer les fichiers
sudo cp hdmi-mode-toggle.sh /usr/local/bin/
sudo cp gpio-button-daemon.py /usr/local/bin/
sudo chmod +x /usr/local/bin/hdmi-mode-toggle.sh
sudo chmod +x /usr/local/bin/gpio-button-daemon.py

# Installer le service systemd
sudo cp hdmi-button.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable hdmi-button.service
sudo systemctl start hdmi-button.service
```

### 2. Vérifier le Service

```bash
# Status du service
sudo systemctl status hdmi-button.service

# Logs en temps réel
sudo journalctl -u hdmi-button.service -f
```

Vous devriez voir:
```
✅ GPIO 100 configured successfully
✅ Ready! Press the button to toggle HDMI mode
```

---

## 🔧 Utilisation

### Avec le Bouton (Auto)

1. Appuyer sur le bouton
2. Le système détecte l'appui
3. Bascule le mode HDMI dans `/boot/armbianEnv.txt`
4. Redémarre automatiquement après 3 secondes
5. Après reboot, le nouveau mode HDMI est actif

### Manuellement (Sans Bouton)

```bash
# Basculer le mode manuellement
sudo /usr/local/bin/hdmi-mode-toggle.sh

# Puis rebooter
sudo reboot
```

---

## 🔍 Vérification

### Vérifier le Mode Actuel

```bash
# Voir le paramètre boot
cat /boot/armbianEnv.txt | grep extraargs

# Mode progressif (1080p50):
# extraargs=... video=HDMI-A-1:1920x1080@50 ...

# Mode entrelacé (1080i50):
# extraargs=... video=HDMI-A-1:1920x1080M@50eD ...
```

### Vérifier dans les Logs Système

```bash
# Après boot, vérifier le mode appliqué
dmesg | grep -i "1920x1080"

# Mode progressif affiche:
# Update mode to 1920x1080p50

# Mode entrelacé affiche:
# Update mode to 1920x1080i50
```

---

## ⚙️ Configuration Avancée

### Changer le GPIO Pin

Si vous voulez utiliser un autre GPIO:

```bash
# Éditer le service
sudo nano /etc/systemd/system/hdmi-button.service

# Changer la ligne ExecStart:
ExecStart=/usr/bin/python3 /usr/local/bin/gpio-button-daemon.py XXX
# Remplacer XXX par le numéro GPIO

# Redémarrer le service
sudo systemctl daemon-reload
sudo systemctl restart hdmi-button.service
```

### GPIO Disponibles sur Orange Pi 5 Plus

Quelques GPIO utilisables (vérifier la doc Orange Pi):
- **GPIO 100** (GPIO3_A4) - Pin 7 - **RECOMMANDÉ**
- GPIO 101 (GPIO3_A5) - Pin 11
- GPIO 102 (GPIO3_A6) - Pin 13
- GPIO 103 (GPIO3_A7) - Pin 15

**Attention:** Ne pas utiliser les GPIO déjà utilisés par d'autres fonctions (I2C, SPI, UART, etc.)

---

## 🐛 Troubleshooting

### Le bouton ne répond pas

```bash
# Vérifier le service
sudo systemctl status hdmi-button.service

# Vérifier les logs
sudo journalctl -u hdmi-button.service -n 50

# Tester manuellement
sudo python3 /usr/local/bin/gpio-button-daemon.py 100
# Puis appuyer sur le bouton
```

### "Permission denied" sur GPIO

```bash
# Le daemon doit tourner en root
sudo systemctl restart hdmi-button.service
```

### Le mode ne change pas après reboot

```bash
# Vérifier que /boot/armbianEnv.txt a été modifié
cat /boot/armbianEnv.txt | grep extraargs

# Vérifier qu'il y a bien un backup
ls -la /boot/armbianEnv.txt.backup
```

### Tester le GPIO manuellement

```bash
# Exporter le GPIO
echo 100 > /sys/class/gpio/export

# Configurer en input
echo in > /sys/class/gpio/gpio100/direction

# Lire la valeur (devrait être 1 au repos, 0 quand bouton pressé)
cat /sys/class/gpio/gpio100/value

# Nettoyer
echo 100 > /sys/class/gpio/unexport
```

---

## 📊 Comparaison Modes HDMI

| Mode | Résolution | Scan | Avantages | Inconvénients |
|------|-----------|------|-----------|---------------|
| **1080p50** | 1920x1080 | Progressif | Image plus nette, moins de flicker | Bande passante plus élevée |
| **1080i50** | 1920x1080 | Entrelacé | Bande passante réduite | Peut avoir du flicker sur écrans modernes |

**Recommandation:**
- Écrans modernes (LCD/LED/OLED): **1080p50** (progressif)
- Anciens CRT ou compatibilité: **1080i50** (entrelacé)

---

## 🎨 Personnalisation

### Ajouter une LED de Status

Vous pouvez ajouter une LED pour indiquer le mode actuel:

```python
# Dans gpio-button-daemon.py, ajouter après toggle_hdmi_mode():

LED_GPIO = 101  # Choisir un autre GPIO pour LED
led = GPIOButton(LED_GPIO)
led.setup()

# Allumer/Éteindre LED selon mode
if mode == "progressive":
    # LED ON
    with open(f"/sys/class/gpio/gpio{LED_GPIO}/value", "w") as f:
        f.write("1")
else:
    # LED OFF
    with open(f"/sys/class/gpio/gpio{LED_GPIO}/value", "w") as f:
        f.write("0")
```

### Changer le Temps de Debounce

Dans `gpio-button-daemon.py`:

```python
DEBOUNCE_TIME = 1.0  # Changer à 0.5 pour réponse plus rapide
                     # ou 2.0 pour éviter les doubles appuis
```

---

## 📝 Fichiers Installés

```
/usr/local/bin/hdmi-mode-toggle.sh     - Script de bascule
/usr/local/bin/gpio-button-daemon.py   - Daemon GPIO
/etc/systemd/system/hdmi-button.service - Service systemd
/boot/armbianEnv.txt                   - Config boot (modifiée)
/tmp/hdmi_current_mode                 - Mode actuel (cache)
```

---

## 🔒 Sécurité

Le daemon tourne en **root** car:
- Accès GPIO nécessite root
- Modification de `/boot/armbianEnv.txt` nécessite root
- Commande `reboot` nécessite root

**Recommandation:** Ne pas exposer le bouton si accès non autorisé possible.

---

## 📖 Licence

MIT License - Même licence que le projet principal
