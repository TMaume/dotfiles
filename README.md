# Dotfiles Arch Linux — Niri & Dank Material Shell

Configuration complète et portable pour **Arch Linux**, gérée via un dépôt Git *bare* (`~/.dotfiles`) avec un répertoire de travail directement dans `$HOME`.

## Aperçu de l'environnement

- **Compositeur Wayland** : [Niri](https://github.com/YaLTeR/niri)
- **Shell & Greeter** : [Dank Material Shell (DMS)](https://danklinux.com/) + `greetd` (`dms-greeter`) + `dfiles` / `dsearch` / `dcal`
- **Thématisation dynamique** : Matugen (Starship, Sidra, thèmes DMS, fonds d'écran Opium)
- **Terminal & Shell** : Kitty, Zsh (`zsh-autosuggestions`, `zsh-syntax-highlighting`, Starship), Fish, Fastfetch
- **Applications & Outils** : VS Code (extensions & settings), Firefox (`user.js` optimisé + Pywalfox), Vesktop, MariaDB, Docker

---

## Installation sur une nouvelle machine

Sur une installation fraîche d'Arch Linux (avec un utilisateur disposant de `sudo` et d'une connexion internet) :

```bash
curl -fsSLO https://raw.githubusercontent.com/TMaume/dotfiles/main/install.sh
chmod +x install.sh
./install.sh
```

> **Note** : Le script tente d'abord de cloner le dépôt en SSH (`git@github.com:TMaume/dotfiles.git`) et bascule automatiquement en HTTPS si aucune clé SSH n'est configurée.

### Ce que fait `install.sh`

1. **Clonage des dotfiles** : initialise le dépôt *bare* dans `~/.dotfiles`, sauvegarde les éventuels fichiers conflictuels dans `~/.dotfiles-backup`, puis applique `pacman.conf` et `makepkg.conf`.
2. **Détection matérielle automatique** :
   - **CPU** : installe `intel-ucode` (et `hwp_dynamic_boost`) ou `amd-ucode`.
   - **GPU** : installe les pilotes et l'accélération matérielle adaptés (`nvidia`, `amd` ou `intel`) et génère `~/.config/environment.d/95-hardware-accel.conf`.
   - **Lenovo ThinkPad Intel** : installe et active `throttled` uniquement sur ce matériel.
3. **Outils de base** : installe `yay` (AUR helper) et Dank Material Shell (`dms`).
4. **Restauration des logiciels** :
   - Paquets officiels (`~/pkglist-repo.txt`)
   - Paquets AUR (`~/pkglist-aur.txt`)
   - Applications Flatpak (`~/pkglist-flatpak.txt`)
   - Pywalfox via `pipx`
5. **Configuration système & optimisations (`/etc`)** :
   - Copie les configurations universelles depuis `~/.dotfiles-system/etc/` (`greetd`, `sysctl.d`, `zram-generator.conf`, `journald.conf.d`, `logind.conf.d`, `NetworkManager`, `udev`, `tmpfiles.d`, `reflector`, `my.cnf`).
   - Passe les montages `relatime` en `noatime` dans `/etc/fstab`.
   - Ajoute l'utilisateur aux groupes `gamemode`, `input`, `greeter` et `docker`.
6. **Personnalisation utilisateur** :
   - Initialise `~/.local/state/dms/session.json` depuis `session.seed.json` et recrée les liens symboliques pour `dms-greeter` (`/var/cache/dms-greeter`).
   - Adapte automatiquement les chemins `/home/dtl21` et l'utilisateur `greetd` si le nom d'utilisateur diffère sur la nouvelle machine.
   - Configure `zsh` comme shell par défaut.
   - Applique `~/.config/firefox-user.js` au profil Firefox et restaure les extensions VS Code (`~/vscode-extensions.txt`).
7. **Services systemd** : active les services système (`~/services-list.txt`, `cups.socket`, timers `paccache`/`fstrim`/`reflector`) et les services utilisateur (`dms`, `dfiles`, `dsearch`, `dcal`, `dcal-annual-events.timer`, `fix-webcam`, `appimagelauncherd`).
8. **Base de données (MariaDB)** : initialise le répertoire de données et propose de restaurer `~/bases_de_donnees_backup.sql` s'il est présent.

---

## Mise à jour & sauvegarde (`update.sh`)

Pour mettre à jour le système et pousser l'état actuel de la configuration sur GitHub :

```bash
~/update.sh
```

Le script exécute les étapes suivantes :
1. Met à jour les paquets (`yay -Syu`) et Flatpak (`flatpak update`).
2. Régénère les listes portables en excluant les pilotes spécifiques au matériel :
   - `~/pkglist-repo.txt`
   - `~/pkglist-aur.txt`
   - `~/pkglist-flatpak.txt`
   - `~/vscode-extensions.txt`
   - `~/services-list.txt`
3. Synchronise `~/.config/firefox-user.js`, `~/.config/dms/session.seed.json` et les configurations système universelles dans `~/.dotfiles-system/etc/`.
4. Exporte les bases MariaDB dans `~/bases_de_donnees_backup.sql` si `mariadb` est actif.
5. Indexe les fichiers suivis, demande un message de commit (ou utilise la date du jour par défaut) et pousse vers `origin/main`.

---

## Utilisation quotidienne du dépôt

Un alias `config` est défini dans `~/.zshrc` :

```bash
config status
config add ~/.config/mon-fichier
config commit -m "Message"
config push
```

## Structure principale

```text
~/
├── install.sh                 # Script d'installation complète sur un nouveau PC
├── update.sh                  # Script de mise à jour système et sauvegarde GitHub
├── README.md                  # Documentation du dépôt
├── pkglist-repo.txt           # Paquets des dépôts officiels Arch
├── pkglist-aur.txt            # Paquets AUR
├── pkglist-flatpak.txt        # Applications Flatpak
├── vscode-extensions.txt      # Extensions VS Code
├── services-list.txt          # Unités systemd activées
├── .zshrc / .zprofile         # Configuration Zsh & environnement
├── .gitconfig                 # Configuration Git & helper GitHub CLI
├── .dotfiles-system/etc/      # Configurations système universelles (/etc)
├── .local/bin/                # Scripts utilisateur (dcal, webcam, wallpaper)
└── .config/                   # Configurations des applications (niri, dms, kitty, etc.)
```
