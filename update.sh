#!/bin/bash
set -e

# Définition de la commande Git pour le dépôt bare (car l'alias ~/.zshrc ne marche pas dans un script bash)
DOTFILES_GIT="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"

echo "=== 1. Mise à jour du système (Dépôts + AUR) ==="
yay -Syu

echo -e "\n=== 2. Exportation des logiciels et services actuels ==="
# Met à jour les listes locales avec ce qui est actuellement sur la machine
pacman -Qqen > ~/pkglist-repo.txt
pacman -Qqem > ~/pkglist-aur.txt
systemctl list-unit-files --state=enabled --type=service --no-pager | grep \.service | awk '{print $1}' > ~/services-list.txt
echo "✅ Listes générées."

echo -e "\n=== 3. Sauvegarde sur GitHub ==="
# Ajoute spécifiquement les 3 fichiers textes générés
$DOTFILES_GIT add ~/pkglist-repo.txt ~/pkglist-aur.txt ~/services-list.txt

# Ajoute toutes les modifications des fichiers de configuration DÉJÀ SUIVIS (ex: ~/.zshrc s'il a été modifié)
$DOTFILES_GIT add -u

# Vérifie s'il y a des changements à envoyer
if [ -n "$($DOTFILES_GIT status --porcelain)" ]; then
    echo "Fichiers modifiés :"
    $DOTFILES_GIT status -s
    
    echo ""
    read -p "Entrez un message de commit (Laissez vide pour utiliser la date du jour) : " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="Mise à jour système et paquets - $(date +'%d/%m/%Y %H:%M')"
    fi
    
    $DOTFILES_GIT commit -m "$commit_msg"
    $DOTFILES_GIT push
    echo "✅ Dépôt GitHub mis à jour avec succès."
else
    echo "✅ Aucune modification de configuration à envoyer sur GitHub."
fi
