# >>> ai-ml-dev-bootstrap:macos-developer >>>
# Managed by ai-ml-dev-bootstrap. Keep this block after other interactive zsh
# integrations so syntax highlighting can register last.

export PATH="$HOME/.local/bin:$PATH"
export STARSHIP_CONFIG="$HOME/.config/starship/current.toml"

# Fast directory jumping, fuzzy history/file search, and the Starship prompt.
# The guards make adoption safe when an existing unmarked .zshrc already loads
# one or more of the same tools.
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
# <<< ai-ml-dev-bootstrap:macos-developer <<<
