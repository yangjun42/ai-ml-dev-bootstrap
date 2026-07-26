# Managed by ai-ml-dev-bootstrap.
# Put personal or machine-specific additions in:
#   ~/.config/zsh/local.zsh
# That optional file is loaded before the final interactive typing helpers.

# Make a fresh Homebrew installation available in new zsh sessions.
if (( ! $+commands[brew] )); then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Keep per-user commands first without accumulating duplicate PATH entries.
typeset -U path PATH
path=("$HOME/.local/bin" $path)

# Persist and share command history across terminal windows, tabs, and panes.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Native zsh completion.
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi
zstyle ':completion:*' menu select

# Prompt, navigation, and fuzzy search.
if (( $+commands[zoxide] && ! $+functions[__zoxide_z] )); then
  eval "$(zoxide init zsh)"
fi

if (( $+commands[fzf] && ! $+widgets[fzf-history-widget] )); then
  source <(fzf --zsh)
fi

if (( $+commands[starship] )) && [[ "${STARSHIP_SHELL:-}" != "zsh" ]]; then
  eval "$(starship init zsh)"
fi

# Personal additions load before the final ZLE integrations so syntax
# highlighting can remain last.
AI_ML_ZSH_LOCAL="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/local.zsh"
[[ -r "$AI_ML_ZSH_LOCAL" ]] && source "$AI_ML_ZSH_LOCAL"
unset AI_ML_ZSH_LOCAL

# Homebrew-installed typing helpers. Syntax highlighting intentionally loads
# after all other line-editor integrations.
if (( $+commands[brew] )); then
  AI_ML_BREW_PREFIX="$(brew --prefix)"

  if (( ! $+functions[_zsh_autosuggest_start] )) && \
      [[ -r "$AI_ML_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$AI_ML_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  if (( ! $+functions[_zsh_highlight] )) && \
      [[ -r "$AI_ML_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$AI_ML_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi

  unset AI_ML_BREW_PREFIX
fi
