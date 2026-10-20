# ==========================================
# 0. Gestion de l'historique
# ==========================================
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Options de sauvegarde et synchronisation
setopt INC_APPEND_HISTORY        # Écrit dans l'historique dès que la commande est exécutée
setopt SHARE_HISTORY             # Partage l'historique entre toutes les sessions/onglets ouverts
setopt HIST_IGNORE_DUPS          # Ignore les commandes dupliquées consécutives
setopt HIST_IGNORE_SPACE         # N'enregistre pas les commandes débutant par un espace

# ==========================================
# 1. Système de complétion intelligente
# ==========================================
autoload -Uz compinit
compinit

# Menu interactif de navigation pour la touche Tab
zstyle ':completion:*' menu select

# ==========================================
# 2. Configuration des suggestions (Grisé)
# ==========================================
# Stratégie : chercher d'abord dans l'historique, puis dans les dossiers/commandes
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Chargement de l'autocomplétion
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ==========================================
# 3. Raccourcis Clavier (Kitty)
# ==========================================
# Flèche de droite : Avancer le curseur vers la droite (accepte la suggestion en fin de ligne)
bindkey "^[[C" forward-char

# Ctrl + Flèche de droite : Accepter la suggestion mot par mot (ou dossier par dossier)
bindkey "^[[1;5C" forward-word

# Flèche de gauche : Déplacer le curseur vers la gauche
bindkey "^[[D" backward-char

# Touche Suppr (Delete) : Supprimer le caractère sous le curseur
bindkey "^[[3~" delete-char

# ==========================================
# 4. Apparence (Prompt)
# ==========================================
# Chargement du thème visuel Starship
eval "$(starship init zsh)"

# Environnement Swiftly
[ -f "$HOME/.local/share/swiftly/env.sh" ] && source "$HOME/.local/share/swiftly/env.sh"

# OpenClaw Completion
[ -f '/home/dtl21/.openclaw/completions/openclaw.zsh' ] && source '/home/dtl21/.openclaw/completions/openclaw.zsh'

# Added by Antigravity CLI installer
export PATH="/home/dtl21/.local/bin:$PATH"
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# ==========================================
# 5. Coloration syntaxique
# ==========================================
# ATTENTION : Ce plugin doit TOUJOURS rester la dernière ligne du fichier
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh