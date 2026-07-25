# >>> ai-ml-dev-bootstrap:macos-minimal >>>
# Managed by ai-ml-dev-bootstrap. Personal shell configuration may live above
# or below this block; rerunning the bootstrap updates only managed blocks.

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

# Native zsh completion. Developer integrations are loaded after this block.
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
# <<< ai-ml-dev-bootstrap:macos-minimal <<<
