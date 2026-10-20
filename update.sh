#!/bin/bash
set -e

# Définition de la commande Git pour le dépôt bare
DOTFILES_GIT="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"

echo "=== 1. Mise à jour du système (Dépôts + AUR) ==="
yay -Syu

echo -e "\n=== 2. Exportation des configurations actuelles ==="
# Met à jour les listes locales
pacman -Qqen > ~/pkglist-repo.txt
pacman -Qqem > ~/pkglist-aur.txt
flatpak list --app --columns=application > ~/pkglist-flatpak.txt
systemctl list-unit-files --state=enabled --type=service --no-pager | grep \.service | awk '{print $1}' > ~/services-list.txt

# Copie des configurations système dans le dossier de sauvegarde
mkdir -p ~/.dotfiles-system/etc
[ -d /etc/greetd ] && cp -r /etc/greetd ~/.dotfiles-system/etc/
[ -f /etc/pacman.conf ] && cp /etc/pacman.conf ~/.dotfiles-system/etc/
[ -f /etc/makepkg.conf ] && cp /etc/makepkg.conf ~/.dotfiles-system/etc/
[ -f /etc/my.cnf ] && cp /etc/my.cnf ~/.dotfiles-system/etc/  # <-- Ajout MySQL

echo "✅ Listes et configurations système générées."

# Exportation automatique de la base de données si le service tourne
if systemctl is-active --quiet mariadb; then
    echo -e "\n=== Exportation des bases de données ==="
    echo "🔐 Sauvegarde via mariadb-dump (Mot de passe sudo peut être requis)..."
    # Utilisation de sudo et du nouveau nom de commande, sans le paramètre -p
    sudo mariadb-dump -u root --all-databases > ~/bases_de_donnees_backup.sql
    
    # On redonne les droits de ton utilisateur normal au fichier généré (au cas où sudo l'aurait bloqué)
    sudo chown $USER:$USER ~/bases_de_donnees_backup.sql
    echo "✅ Base de données exportée dans ~/bases_de_donnees_backup.sql."
fi

echo -e "\n=== 3. Sauvegarde sur GitHub ==="
# Ajoute les fichiers générés, le dossier système et le dump SQL
$DOTFILES_GIT add ~/pkglist-repo.txt ~/pkglist-aur.txt ~/pkglist-flatpak.txt ~/services-list.txt ~/.dotfiles-system/ ~/bases_de_donnees_backup.sql

# Ajoute toutes les modifications des fichiers de configuration DÉJÀ SUIVIS (Niri, DMS, Zsh, etc.)
$DOTFILES_GIT add -u

# Vérifie s'il y a des changements à envoyer
if [ -n "$($DOTFILES_GIT status --porcelain)" ]; then
    echo "Fichiers modifiés :"
    $DOTFILES_GIT status -s
    
    echo ""
    read -p "Entrez un message de commit (Laissez vide pour utiliser la date du jour) : " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="Mise à jour système, paquets et DB - $(date +'%d/%m/%Y %H:%M')"
    fi
    
    $DOTFILES_GIT commit -m "$commit_msg"
    $DOTFILES_GIT push
    echo "✅ Dépôt GitHub mis à jour avec succès."
else
    echo "✅ Aucune modification de configuration à envoyer sur GitHub."
fi