# >>> ai-ml-dev-bootstrap:macos-core >>>
# Managed by ai-ml-dev-bootstrap. Personal shell configuration may live above
# or below this block; rerunning the bootstrap updates only this marked block.

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

# Persist and share command history across Ghostty windows, tabs, and panes.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Native zsh completion. Avoid reinitializing it when existing dotfiles already
# loaded compinit before this managed block.
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi
zstyle ':completion:*' menu select

# Prompt, navigation, and fuzzy search. Guards make adoption safe when existing
# unmarked dotfiles already initialize one of these tools.
if (( $+commands[zoxide] && ! $+functions[__zoxide_z] )); then
  eval "$(zoxide init zsh)"
fi

if (( $+commands[fzf] && ! $+widgets[fzf-history-widget] )); then
  source <(fzf --zsh)
fi

if (( $+commands[starship] )) && [[ "${STARSHIP_SHELL:-}" != "zsh" ]]; then
  eval "$(starship init zsh)"
fi

# Homebrew-installed typing helpers. Syntax highlighting intentionally loads
# after the other ZLE integrations.
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
# <<< ai-ml-dev-bootstrap:macos-core <<<
