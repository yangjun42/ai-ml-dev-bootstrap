# >>> ai-ml-dev-bootstrap:macos-developer >>>
# Managed by ai-ml-dev-bootstrap. Keep this block after other interactive zsh
# integrations so syntax highlighting can register last.

export PATH="$HOME/.local/bin:$PATH"
export STARSHIP_CONFIG="$HOME/.config/starship/current.toml"

# Fast directory jumping, fuzzy history/file search, and the Starship prompt.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[fzf] )) && source <(fzf --zsh)
(( $+commands[starship] )) && eval "$(starship init zsh)"

# Homebrew-installed typing helpers. Syntax highlighting intentionally loads
# after the other ZLE integrations.
if (( $+commands[brew] )); then
  AI_ML_BREW_PREFIX="$(brew --prefix)"

  if [[ -r "$AI_ML_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$AI_ML_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  if [[ -r "$AI_ML_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$AI_ML_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi

  unset AI_ML_BREW_PREFIX
fi
# <<< ai-ml-dev-bootstrap:macos-developer <<<
