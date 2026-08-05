# ── Performance optimizations ──
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"
skip_global_compinit=1

# Titre de terminal figé : mécanisme OMZ, au lieu d'un precmd() maison qui
# entrait en conflit avec omz_termsupport_precmd.
DISABLE_AUTO_TITLE="true"

# ── Oh My Zsh ──
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="spaceship"

# ── Spaceship (async + minimal sections) ──
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_CHAR_SYMBOL="⚡"
SPACESHIP_PROMPT_ORDER=(time user dir git line_sep char)

# ── Plugins (syntax highlighting must be last) ──
plugins=(git zsh-completions zsh-autosuggestions zsh-syntax-highlighting)

# oh-my-zsh.sh appelle déjà compinit avec son propre cache journalier
# ($ZSH_COMPDUMP) — ne pas le rappeler ici, ça doublerait compinit + compaudit.
source $ZSH/oh-my-zsh.sh

# ── Autosuggest ──
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
ZSH_AUTOSUGGEST_USE_ASYNC=1

# ── Historique (HISTSIZE/SAVEHIST d'OMZ sont à 50000/10000) ──
HISTSIZE=200000
SAVEHIST=200000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS

# ── Éditeur ──
export EDITOR="nvim"
export VISUAL="$EDITOR"

# ── Alias expansion ──
globalias() {
   if [[ $LBUFFER =~ '[a-zA-Z0-9]+$' ]]; then
       zle _expand_alias
       zle expand-word
   fi
   zle self-insert
}
zle -N globalias
bindkey " " globalias
bindkey "^[[Z" magic-space
bindkey -M isearch " " magic-space

# L'agent SSH est fourni par launchd sur macOS (SSH_AUTH_SOCK toujours défini) :
# pas de ssh-agent à lancer ici. Cf. AddKeysToAgent/UseKeychain dans ~/.ssh/config.

source ~/.zshrc.custom

# ── Fzf ──
if [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
    export FZF_DEFAULT_OPTS="--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all"
fi

# ── Zoxide ──
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ── Envman ──
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# ── Conda: lazy-loaded ──
conda() {
    unfunction conda
    local __conda_setup
    __conda_setup="$("$HOME/.miniconda/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "$HOME/.miniconda/etc/profile.d/conda.sh" ]; then
            . "$HOME/.miniconda/etc/profile.d/conda.sh"
        else
            export PATH="$PATH:/Users/julien/.miniforge3/bin"
            export PATH="$HOME/.miniconda/bin:$PATH"
        fi
    fi
    unset __conda_setup
    conda "$@"
}

# ── Bun ──
if [ -d "$HOME/.bun" ]; then
    export BUN_INSTALL="$HOME/.bun"
    [ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
    export PATH="$PATH:$BUN_INSTALL/bin"
fi

command -v bat &>/dev/null && export BAT_THEME="kanagawa"

# ── PATH additions ──
export PATH="$PATH:$HOME/.lmstudio/bin"

export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# ── Herdr ──
export OPENCODE_PORT=4096
eval "$(herdr completion zsh)"
