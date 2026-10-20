#!/bin/bash
set -e

echo "=== Mise à jour du système ==="
sudo pacman -Syu --noconfirm

echo "=== Détection et installation des pilotes graphiques (Wayland/Niri) ==="
GPU=$(lspci | grep -i -E 'vga|3d|display')

if echo "$GPU" | grep -iq nvidia; then
    echo "NVIDIA détecté."
    sudo pacman -S --needed --noconfirm nvidia nvidia-utils
elif echo "$GPU" | grep -iq amd; then
    echo "AMD détecté."
    sudo pacman -S --needed --noconfirm mesa vulkan-radeon libva-mesa-driver
elif echo "$GPU" | grep -iq intel; then
    echo "Intel détecté."
    sudo pacman -S --needed --noconfirm mesa vulkan-intel intel-media-driver
else
    echo "GPU non reconnu spécifiquement, utilisation des pilotes Mesa génériques."
    sudo pacman -S --needed --noconfirm mesa
fi

echo "=== Installation de yay (AUR helper) ==="
if ! command -v yay &> /dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd ~
fi

echo "=== Installation de Dank Material Shell (DMS) ==="
if ! command -v dms &> /dev/null; then
    curl -fsSL https://install.danklinux.com | sh
fi

echo "=== Configuration de Flatpak et restauration des applications ==="
if [ -f "pkglist-flatpak.txt" ]; then
    # Installer flatpak si ce n'est pas déjà fait
    sudo pacman -S --needed --noconfirm flatpak
    
    # Ajouter le dépôt Flathub
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    # Installer les applications
    while read app; do
        [ -z "$app" ] && continue
        flatpak install -y flathub "$app"
    done < pkglist-flatpak.txt
fi

echo "=== Restauration des logiciels ==="
if [ -f "pkglist-repo.txt" ]; then
    sudo pacman -S --needed --noconfirm - < pkglist-repo.txt
fi

if [ -f "pkglist-aur.txt" ]; then
    yay -S --needed --noconfirm - < pkglist-aur.txt
fi

echo "=== Initialisation de la base de données (MariaDB/MySQL) ==="
if grep -q "^mariadb$" pkglist-repo.txt 2>/dev/null || pacman -Qs mariadb > /dev/null; then
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        echo "Initialisation du répertoire de données MariaDB..."
        sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    fi
fi

echo "=== Activation des services système ==="
if [ -f "services-list.txt" ]; then
    while read service; do
        # Ignore les lignes vides
        [ -z "$service" ] && continue 
        sudo systemctl enable "$service"
    done < services-list.txt
fi

echo "=== Récupération des dotfiles (Configuration Niri, Zsh, etc.) ==="
DOTFILES_REPO="git@github.com:TMaume/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
    
    # Configuration de l'alias temporaire pour le checkout
    alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
    
    # Backup des fichiers existants conflictuels au cas où (ex: .bashrc)
    mkdir -p ~/.dotfiles-backup
    config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} ~/.dotfiles-backup/{} || true
    
    config checkout
    config config --local status.showUntrackedFiles no
fi

echo "=== Restauration des configurations système (/etc) ==="
if [ -d "$HOME/.dotfiles-system/etc" ]; then
    echo "Copie des fichiers vers /etc..."
    sudo cp -r $HOME/.dotfiles-system/etc/* /etc/
fi

echo "=== Installation terminée ! ==="
echo "Redémarrez votre PC."