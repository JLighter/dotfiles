# ── Performance optimizations ──
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"
skip_global_compinit=1

# ── Oh My Zsh ──
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="spaceship"

# ── Spaceship (async + minimal sections) ──
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_CHAR_SYMBOL="⚡"
SPACESHIP_PROMPT_ORDER=(time user dir git line_sep char)

# ── Plugins (syntax highlighting must be last) ──
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# ── Autosuggest ──
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
ZSH_AUTOSUGGEST_USE_ASYNC=1

# ── Compinit: once per day, single call ──
autoload -Uz compinit
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
    compinit
else
    compinit -C
fi

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

# ── SSH agent: run once at startup, not in precmd ──
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/id_github_sign_and_auth 2>/dev/null
fi

export PATH

[ -f ~/.zsh_aliases ] && source ~/.zsh_aliases
source ~/.zshrc.custom

# ── Fzf (deduplicated) ──
if [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
    FZF_DEFAULT_OPTS="--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all"
fi

# ── Zoxide ──
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ── Envman ──
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

precmd () { print -Pn "\e]0;zsh\a" }

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
export PATH="$PATH:/Users/julien/.lmstudio/bin"

export PNPM_HOME="/Users/julien/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

export PATH="/Users/julien/.antigravity/antigravity/bin:$PATH"

export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

# ── Herdr ──
export OPENCODE_PORT=4096
eval "$(herdr completion zsh)"
