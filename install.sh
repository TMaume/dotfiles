#!/bin/bash
set -e

echo "=========================================================="
echo " Installation et Clonage Complet de la Configuration Arch"
echo "=========================================================="

echo -e "\n=== 1. Récupération des dotfiles (Dépôt GitHub) ==="
DOTFILES_SSH="git@github.com:TMaume/dotfiles.git"
DOTFILES_HTTPS="https://github.com/TMaume/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

sudo pacman -Syu --needed --noconfirm git base-devel

if [ ! -d "$DOTFILES_DIR" ]; then
    # Tente le clonage en SSH, sinon bascule automatiquement en HTTPS (pratique sur un nouveau PC sans clé SSH)
    git clone --bare "$DOTFILES_SSH" "$DOTFILES_DIR" 2>/dev/null || git clone --bare "$DOTFILES_HTTPS" "$DOTFILES_DIR"
    
    DOTFILES_GIT="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
    
    # Sauvegarde des fichiers existants conflictuels
    mkdir -p ~/.dotfiles-backup
    $DOTFILES_GIT checkout 2>&1 | grep -E "\s+\." | awk '{print $1}' | while read -r file; do
        mkdir -p "$(dirname "$HOME/.dotfiles-backup/$file")"
        mv "$HOME/$file" "$HOME/.dotfiles-backup/$file" 2>/dev/null || true
    done
    
    $DOTFILES_GIT checkout
    $DOTFILES_GIT config --local status.showUntrackedFiles no
fi

# Restaure immédiatement pacman.conf et makepkg.conf pour accélérer toute la suite (ParallelDownloads + compilation multi-cœurs native)
if [ -f "$HOME/.dotfiles-system/etc/pacman.conf" ]; then
    sudo cp "$HOME/.dotfiles-system/etc/pacman.conf" /etc/pacman.conf
fi
if [ -f "$HOME/.dotfiles-system/etc/makepkg.conf" ]; then
    sudo cp "$HOME/.dotfiles-system/etc/makepkg.conf" /etc/makepkg.conf
fi

echo -e "\n=== 2. Détection dynamique du CPU et des pilotes graphiques ==="
CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}' || true)
if [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    echo "CPU Intel détecté -> Installation de intel-ucode..."
    sudo pacman -S --needed --noconfirm intel-ucode
    if [ -f /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost ]; then
        echo "w /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost - - - - 1" | sudo tee /etc/tmpfiles.d/intel-hwp-boost.conf >/dev/null
        sudo systemd-tmpfiles --create /etc/tmpfiles.d/intel-hwp-boost.conf || true
    fi
elif [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    echo "CPU AMD détecté -> Installation de amd-ucode..."
    sudo pacman -S --needed --noconfirm amd-ucode
fi

GPU=$(lspci | grep -i -E 'vga|3d|display')
mkdir -p "$HOME/.config/environment.d"

if echo "$GPU" | grep -iq nvidia; then
    echo "GPU NVIDIA détecté."
    sudo pacman -S --needed --noconfirm nvidia nvidia-utils lib32-nvidia-utils libva-nvidia-driver libva-utils
    cat << 'EOF' > "$HOME/.config/environment.d/95-hardware-accel.conf"
LIBVA_DRIVER_NAME=nvidia
MOZ_ENABLE_WAYLAND=1
MESA_SHADER_CACHE_MAX_SIZE=4G
EOF
elif echo "$GPU" | grep -iq amd; then
    echo "GPU AMD détecté."
    sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils
    cat << 'EOF' > "$HOME/.config/environment.d/95-hardware-accel.conf"
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
RADV_PERFTEST=video_decode
MOZ_ENABLE_WAYLAND=1
MESA_SHADER_CACHE_MAX_SIZE=4G
EOF
elif echo "$GPU" | grep -iq intel; then
    echo "GPU Intel détecté."
    sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver libva-utils sof-firmware
    cat << 'EOF' > "$HOME/.config/environment.d/95-hardware-accel.conf"
LIBVA_DRIVER_NAME=iHD
VDPAU_DRIVER=va_gl
ANV_VIDEO_DECODE=1
MOZ_ENABLE_WAYLAND=1
MESA_SHADER_CACHE_MAX_SIZE=4G
EOF
    echo "options i915 enable_fbc=1 fastboot=1" | sudo tee /etc/modprobe.d/i915.conf >/dev/null
    echo "options snd_hda_intel power_save=0" | sudo tee /etc/modprobe.d/audio-powersave.conf >/dev/null
    if grep -q "^MODULES=()" /etc/mkinitcpio.conf 2>/dev/null; then
        sudo sed -i 's/^MODULES=()/MODULES=(i915)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P || true
    fi
else
    echo "GPU générique détecté -> Installation de Mesa."
    sudo pacman -S --needed --noconfirm mesa lib32-mesa libva-utils
fi

echo -e "\n=== 3. Installation de yay (AUR helper) ==="
if ! command -v yay &> /dev/null; then
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd ~
fi

echo -e "\n=== 4. Installation de Dank Material Shell (DMS) ==="
if ! command -v dms &> /dev/null; then
    curl -fsSL https://install.danklinux.com | sh
fi

echo -e "\n=== 5. Restauration des logiciels (Dépôts Officiels + AUR + Flatpak) ==="
if [ -f "$HOME/pkglist-repo.txt" ]; then
    sudo pacman -S --needed --noconfirm - < "$HOME/pkglist-repo.txt"
fi

if [ -f "$HOME/pkglist-aur.txt" ]; then
    yay -S --needed --noconfirm - < "$HOME/pkglist-aur.txt"
fi

# Détection automatique Lenovo ThinkPad Intel -> Installation de throttled uniquement si pertinent
SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
if [ "$SYS_VENDOR" = "LENOVO" ] && [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    echo "Lenovo ThinkPad Intel détecté -> Installation et activation de throttled..."
    yay -S --needed --noconfirm throttled
    sudo systemctl enable --now throttled.service || true
fi

if [ -f "$HOME/pkglist-flatpak.txt" ]; then
    sudo pacman -S --needed --noconfirm flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    while read -r app; do
        [ -z "$app" ] && continue
        flatpak install -y flathub "$app"
    done < "$HOME/pkglist-flatpak.txt"
fi

echo -e "\n=== 6. Restauration des configurations système (/etc) et optimisations ==="
if [ -d "$HOME/.dotfiles-system/etc" ]; then
    echo "Copie des fichiers universels vers /etc..."
    sudo cp -r "$HOME/.dotfiles-system/etc/"* /etc/
fi

# Optimise le montage SSD avec noatime dans /etc/fstab sur le nouveau PC
if grep -q "relatime" /etc/fstab 2>/dev/null; then
    sudo cp -a /etc/fstab "/etc/fstab.bak.$(date +%s)"
    sudo sed -i 's/\([[:space:]]\)relatime\([[:space:]]\)/\1noatime\2/g' /etc/fstab
    sudo sed -i 's/rw,relatime/rw,noatime/g' /etc/fstab
    sudo mount -o remount,noatime / || true
fi

sudo modprobe tcp_bbr 2>/dev/null || true
sudo sysctl --system >/dev/null || true
sudo udevadm control --reload-rules || true

# Ajoute l'utilisateur au groupe gamemode
if getent group gamemode >/dev/null 2>&1; then
    sudo usermod -aG gamemode "$USER" || true
fi

# Adapte le chemin du fond d'écran dans Niri si le nom d'utilisateur diffère sur le nouveau PC
if [ -f "$HOME/.config/niri/config.kdl" ] && [ "$HOME" != "/home/dtl21" ]; then
    sed -i "s|/home/dtl21|$HOME|g" "$HOME/.config/niri/config.kdl"
fi

# Applique le profil d'optimisation Firefox (RAM cache + VA-API)
if [ -f "$HOME/.config/firefox-user.js" ]; then
    for prof in "$HOME/.config/mozilla/firefox/"*.default* "$HOME/.mozilla/firefox/"*.default*; do
        if [ -d "$prof" ]; then
            cp "$HOME/.config/firefox-user.js" "$prof/user.js"
        fi
    done
fi

# Restaure les extensions VS Code
if [ -f "$HOME/vscode-extensions.txt" ] && command -v code &> /dev/null; then
    echo "Restauration des extensions VS Code..."
    while read -r ext; do
        [ -z "$ext" ] && continue
        code --install-extension "$ext" --force 2>/dev/null || true
    done < "$HOME/vscode-extensions.txt"
fi

echo -e "\n=== 7. Activation des services, timers et sockets système ==="
if [ -f "$HOME/services-list.txt" ]; then
    while read -r unit; do
        [ -z "$unit" ] && continue
        sudo systemctl enable "$unit" 2>/dev/null || true
    done < "$HOME/services-list.txt"
fi
# S'assure que CUPS reste en activation par socket et MariaDB en démarrage manuel
sudo systemctl disable cups.service mariadb.service 2>/dev/null || true
sudo systemctl enable cups.socket paccache.timer fstrim.timer 2>/dev/null || true

echo -e "\n=== 8. Configuration de la base de données (MariaDB) ==="
if command -v mariadb &> /dev/null; then
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        echo "Initialisation du répertoire de données MariaDB..."
        sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    fi

    if [ -f "$HOME/bases_de_donnees_backup.sql" ]; then
        echo ""
        read -p "❓ Un fichier de sauvegarde SQL a été trouvé. Voulez-vous restaurer vos bases de données ? (o/N) " restore_db
        if [[ "$restore_db" =~ ^[OoYy]$ ]]; then
            echo "Démarrage temporaire du service MariaDB pour la restauration..."
            sudo systemctl start mariadb
            sleep 2
            echo "Restauration en cours..."
            sudo mariadb -u root < "$HOME/bases_de_donnees_backup.sql"
            sudo systemctl stop mariadb
            echo "✅ Bases de données restaurées avec succès (MariaDB arrêté, prêt à la demande) !"
        else
            echo "⏩ Restauration ignorée. MariaDB est installé et prêt à l'emploi."
        fi
    fi
fi

echo -e "\n=== Installation terminée ! ==="
echo "Redémarrez votre PC pour profiter de votre environnement complet."
