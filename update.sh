#!/bin/bash
set -e

# Définition de la commande Git pour le dépôt bare
DOTFILES_GIT="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"

echo "=== 1. Mise à jour du système (Dépôts + AUR + Flatpak) ==="
yay -Syu
if command -v flatpak &> /dev/null; then
    flatpak update -y
    flatpak uninstall --unused -y
fi

echo -e "\n=== 2. Exportation des configurations actuelles (Portables / Sans matériel spécifique) ==="
# Exporte les paquets des dépôts officiels en excluant les pilotes/microcodes spécifiques au matériel
pacman -Qqen | grep -v -E '^(intel-ucode|amd-ucode|intel-media-driver|libva-mesa-driver|libva-nvidia-driver|vulkan-intel|lib32-vulkan-intel|vulkan-radeon|lib32-vulkan-radeon|nvidia|nvidia-utils|lib32-nvidia-utils|sof-firmware)$' > ~/pkglist-repo.txt

# Exporte les paquets AUR en excluant les outils spécifiques ThinkPad (throttled) et les paquets -debug
pacman -Qqem | grep -v -E '^(throttled|.*-debug)$' > ~/pkglist-aur.txt

# Exporte les applications Flatpak
if command -v flatpak &> /dev/null; then
    flatpak list --app --columns=application > ~/pkglist-flatpak.txt
fi

# Exporte les extensions VS Code
if command -v code &> /dev/null; then
    code --list-extensions > ~/vscode-extensions.txt 2>/dev/null || true
elif [ -d "$HOME/.vscode/extensions" ]; then
    ls "$HOME/.vscode/extensions/" | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+(-linux-x64)?$//' | grep -v '^extensions\.json$' > ~/vscode-extensions.txt
fi

# Exporte les services, timers et sockets activés (hors services matériels comme throttled)
if systemctl list-unit-files --state=enabled --no-pager &> /dev/null; then
    systemctl list-unit-files --state=enabled --no-pager \
        | awk '$1 ~ /\.(service|timer|socket)$/ {print $1}' \
        | grep -v -E '^(throttled\.service|NetworkManager-wait-online\.service|getty@\.service|systemd-.*|dbus-.*)$' \
        | sort -u > ~/services-list.txt
fi

# Synchronise le profil user.js de Firefox vers un emplacement générique portable
FF_PROFILE_USERJS=$(find "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox" -maxdepth 2 -name "user.js" 2>/dev/null | head -n 1 || true)
if [ -n "$FF_PROFILE_USERJS" ] && [ -f "$FF_PROFILE_USERJS" ]; then
    cp "$FF_PROFILE_USERJS" "$HOME/.config/firefox-user.js"
fi

# Copie des configurations système UNIVERSELLES dans le dossier de sauvegarde
rm -rf ~/.dotfiles-system/etc
mkdir -p ~/.dotfiles-system/etc

if [ -d /etc/greetd ]; then
    mkdir -p ~/.dotfiles-system/etc/greetd
    cp -r /etc/greetd/* ~/.dotfiles-system/etc/greetd/ 2>/dev/null || true
    # Supprime les fichiers de backup auto-générés pour garder le dépôt propre
    find ~/.dotfiles-system/etc/greetd/ -name "*.backup*" -delete
fi

[ -f /etc/pacman.conf ] && cp /etc/pacman.conf ~/.dotfiles-system/etc/
[ -f /etc/makepkg.conf ] && cp /etc/makepkg.conf ~/.dotfiles-system/etc/
[ -f /etc/my.cnf ] && cp /etc/my.cnf ~/.dotfiles-system/etc/

# Configurations d'optimisation universelles (zRAM dynamique, sysctl, BBR, DNS cache, journald, udev EPP)
if [ -f /etc/systemd/zram-generator.conf ]; then
    mkdir -p ~/.dotfiles-system/etc/systemd
    cp /etc/systemd/zram-generator.conf ~/.dotfiles-system/etc/systemd/
fi

if [ -d /etc/systemd/journald.conf.d ]; then
    mkdir -p ~/.dotfiles-system/etc/systemd/journald.conf.d
    cp -r /etc/systemd/journald.conf.d/* ~/.dotfiles-system/etc/systemd/journald.conf.d/ 2>/dev/null || true
fi

mkdir -p ~/.dotfiles-system/etc/sysctl.d
if [ -f /etc/sysctl.d/99-system-optimizations.conf ]; then
    cp /etc/sysctl.d/99-system-optimizations.conf ~/.dotfiles-system/etc/sysctl.d/99-system-optimizations.conf
elif [ -f /etc/sysctl.d/99-thinkpad-optimizations.conf ]; then
    cp /etc/sysctl.d/99-thinkpad-optimizations.conf ~/.dotfiles-system/etc/sysctl.d/99-system-optimizations.conf
fi

if [ -f /etc/modules-load.d/bbr.conf ]; then
    mkdir -p ~/.dotfiles-system/etc/modules-load.d
    cp /etc/modules-load.d/bbr.conf ~/.dotfiles-system/etc/modules-load.d/
fi

if [ -d /etc/NetworkManager/conf.d ]; then
    mkdir -p ~/.dotfiles-system/etc/NetworkManager/conf.d
    cp -r /etc/NetworkManager/conf.d/* ~/.dotfiles-system/etc/NetworkManager/conf.d/ 2>/dev/null || true
fi

if [ -d /etc/NetworkManager/dnsmasq.d ]; then
    mkdir -p ~/.dotfiles-system/etc/NetworkManager/dnsmasq.d
    cp -r /etc/NetworkManager/dnsmasq.d/* ~/.dotfiles-system/etc/NetworkManager/dnsmasq.d/ 2>/dev/null || true
fi

if [ -f /etc/udev/rules.d/85-power-epp.rules ]; then
    mkdir -p ~/.dotfiles-system/etc/udev/rules.d
    cp /etc/udev/rules.d/85-power-epp.rules ~/.dotfiles-system/etc/udev/rules.d/
fi

echo "✅ Listes et configurations système universelles générées."

# Exportation automatique de la base de données si le service tourne
if systemctl is-active --quiet mariadb 2>/dev/null; then
    echo -e "\n=== Exportation des bases de données ==="
    echo "🔐 Sauvegarde via mariadb-dump (Mot de passe sudo peut être requis)..."
    sudo mariadb-dump -u root --all-databases > ~/bases_de_donnees_backup.sql
    sudo chown "$USER:$USER" ~/bases_de_donnees_backup.sql
    echo "✅ Base de données exportée dans ~/bases_de_donnees_backup.sql."
fi

echo -e "\n=== 3. Sauvegarde sur GitHub ==="
# Ajoute les listes, les configurations système universelles et les fichiers de configuration utilisateur
$DOTFILES_GIT add \
    ~/pkglist-repo.txt \
    ~/pkglist-aur.txt \
    ~/pkglist-flatpak.txt \
    ~/vscode-extensions.txt \
    ~/services-list.txt \
    ~/.dotfiles-system/ \
    ~/bases_de_donnees_backup.sql \
    ~/install.sh \
    ~/update.sh \
    ~/.config/code-flags.conf \
    ~/.config/electron-flags.conf \
    ~/.config/mimeapps.list \
    ~/.config/firefox-user.js \
    ~/.config/Code/User/settings.json \
    ~/.config/dms/settings.json \
    ~/.config/dms/plugin_settings.json \
    ~/.config/dms/plugins.lock.json \
    ~/.config/dms/firefox.css \
    ~/.config/dms/plugins/ \
    ~/.config/dms/themes/ \
    ~/.config/niri/config.kdl \
    ~/.config/niri/dms/alttab.kdl \
    ~/.config/niri/dms/binds.kdl \
    ~/.config/niri/dms/colors.kdl \
    ~/.config/niri/dms/cursor.kdl \
    ~/.config/niri/dms/input.kdl \
    ~/.config/niri/dms/layout.kdl \
    ~/.config/niri/dms/outputs.kdl \
    ~/.config/niri/dms/windowrules.kdl \
    ~/.config/niri/dms/wpblur.kdl \
    ~/.config/fish/config.fish \
    ~/.config/vesktop/settings.json \
    ~/.config/vesktop/settings/ \
    ~/Pictures/frame-1.png 2>/dev/null || true

# Ajoute toutes les modifications et suppressions des fichiers déjà suivis
$DOTFILES_GIT add -u

# Vérifie s'il y a des changements à envoyer
if [ -n "$($DOTFILES_GIT status --porcelain)" ]; then
    echo "Fichiers modifiés :"
    $DOTFILES_GIT status -s
    
    echo ""
    read -p "Entrez un message de commit (Laissez vide pour utiliser la date du jour) : " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="Mise à jour système, optimisations et dotfiles - $(date +'%d/%m/%Y %H:%M')"
    fi
    
    $DOTFILES_GIT commit -m "$commit_msg"
    $DOTFILES_GIT push
    echo "✅ Dépôt GitHub mis à jour avec succès."
else
    echo "✅ Aucune modification de configuration à envoyer sur GitHub."
fi
