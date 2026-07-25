# macOS terminal experience

This repository treats the terminal as two layers:

```text
minimal/core -> reliable Ghostty + zsh baseline

developer    -> minimal + polished prompt, navigation, fuzzy search,
                typing assistance, and repository CLI tools
```

The default visual pairing is intentionally opinionated but easy to override:

```text
Ghostty  : TokyoNight Moon in dark mode, TokyoNight Day in light mode
Starship : Jetpack preset
```

It is designed for a personal Apple Silicon Mac used as a local development
host and as a control plane for remote Linux/GPU servers.

## Minimal/core behaviour

`./scripts/bootstrap-macos.sh --profile minimal` installs the core Brewfile and
then safely applies:

- `~/.config/ghostty/config.ghostty`;
- `~/.config/ghostty/appearance.ghostty` when it does not already exist;
- one marked Homebrew/history/completion block in `~/.zshrc`;
- `~/.zsh_history` with user-only permissions.

The managed Ghostty baseline provides:

- explicit `/bin/zsh -l` startup, so directory-managed accounts that still
  advertise `/bin/bash` work without changing the account-wide login shell;
- Ghostty zsh integration and opt-in SSH environment/terminfo handling;
- working-directory inheritance for windows, tabs, and splits;
- 64 MiB lazy scrollback per surface for build and agent logs;
- conservative clipboard read and paste protection;
- left Option as terminal Alt while right Option retains macOS character input;
- stable-channel update notifications (`check`, not silent installation);
- optional `appearance.ghostty` and `local.ghostty` includes, so an accidentally
  removed override does not stop the baseline from loading.

The minimal zsh block restores Homebrew's standard shell environment when it
is not already present, persists and shares history across active shells, and
enables native zsh completion. It does not install a prompt framework or
aliases.

## Developer behaviour

`./scripts/bootstrap-macos.sh --profile developer` layers these packages on top
of minimal:

```text
starship
zoxide
zsh-autosuggestions
zsh-syntax-highlighting
fzf
ripgrep / fd / jq / yq / bat / shellcheck / just
```

It also adds a second marked block at the end of `~/.zshrc` in this order:

```text
zoxide
fzf shell integration
Starship
zsh-autosuggestions
zsh-syntax-highlighting
```

Runtime guards prevent a pre-existing unmarked `.zshrc` from initializing the
same tool twice. Syntax highlighting is deliberately the final interactive
integration because it hooks into zsh's line editor after the other widgets
have been registered.

On a fresh machine the configurator generates Jetpack and selects it at
Starship's official default active path:

```text
~/.config/starship/presets/jetpack.toml
~/.config/starship.toml -> ~/.config/starship/presets/jetpack.toml
```

If `~/.config/starship.toml` already exists, it is preserved. This is important
for an established `.zshrc` that already runs `starship init zsh`: both the
existing line and the managed line now resolve the same active file. Re-running
the bootstrap does not reset the active preset.

## Coordinated theme switching

The developer profile installs `~/.local/bin/devtheme`. It is optional; the
normal default remains TokyoNight + Jetpack.

```bash
devtheme list
devtheme current

devtheme tokyo        # TokyoNight Moon/Day + Jetpack
devtheme tokyo-night  # TokyoNight Moon/Day + Tokyo Night preset
devtheme catppuccin   # Mocha/Latte + Catppuccin Powerline
devtheme gruvbox      # Gruvbox Dark/Light Hard + Gruvbox Rainbow
```

Generate a preset again from a newer Starship installation:

```bash
devtheme --refresh tokyo
```

The command changes:

```text
~/.config/ghostty/appearance.ghostty
~/.config/starship.toml
```

If the active Starship config is a custom file or an external symlink,
`devtheme` first copies it to:

```text
~/.config/ai-ml-dev-bootstrap/backups/starship.toml.<timestamp>
```

After changing a theme, press `Cmd+Shift+,` in Ghostty to reload the terminal
configuration. A new prompt invocation uses the selected Starship config.

## Local overrides

Use this file for display-size or machine-specific Ghostty changes:

```text
~/.config/ghostty/local.ghostty
```

For example:

```ini
font-size = 15
```

Because Ghostty processes included config files after the baseline,
`local.ghostty` wins without creating merge conflicts with future bootstrap
updates.

Ghostty also reads a macOS-specific path after the XDG path:

```text
~/Library/Application Support/com.mitchellh.ghostty/config.ghostty
```

If that file exists, the configurator warns because it can override the managed
XDG config. Prefer one location unless the later override is intentional.

## Safe repeatability

The bootstrap is designed to be rerun:

- `brew bundle check` skips a Brewfile that is already satisfied;
- the default uses `--no-upgrade`; upgrades require `--upgrade`;
- a managed Ghostty main config is backed up before being refreshed;
- an unmanaged or symlinked Ghostty config is preserved and a
  `.ai-ml-dev-bootstrap-new` candidate is written for review;
- `appearance.ghostty` is installed only when absent, so `devtheme` and manual
  choices survive reruns;
- only marked blocks in `.zshrc` are replaced; unmarked personal content is
  retained;
- an existing Starship active config is preserved by bootstrap;
- an explicit `devtheme` switch backs up a custom Starship config first;
- backups are stored under
  `~/.config/ai-ml-dev-bootstrap/backups/`.

Useful controls:

```bash
# Show intended package and config actions.
./scripts/bootstrap-macos.sh --profile developer --dry-run

# Packages only; leave Ghostty and zsh files untouched.
./scripts/bootstrap-macos.sh --profile developer --skip-config

# Back up and replace an existing unmanaged Ghostty main config.
./scripts/bootstrap-macos.sh --profile developer --force-config

# Reapply only configuration, without Homebrew operations.
./scripts/configure-macos-shell.sh --profile developer
```

## Why no Oh My Zsh

The developer profile uses small tools with one clear responsibility instead
of a shell framework:

```text
Starship                prompt
zoxide                  directory ranking and `z`/`zi`
fzf                     fuzzy selection
zsh-autosuggestions     history-based inline suggestions
zsh-syntax-highlighting command-line highlighting
```

This keeps startup behaviour understandable and makes it easier to reproduce
only the parts that are useful on remote servers. Oh My Zsh remains a valid
personal dotfiles choice, but it is not required for this profile.

## Is Yazi included?

No. Yazi is useful for keyboard-driven terminal file browsing, especially in
SSH/tmux sessions, but VS Code Remote SSH and Finder already cover the common
workflow. Install it when that specific need appears:

```bash
brew install yazi
```

It remains outside minimal and developer so it does not bring an additional
file-management interaction model into every new machine.

## Troubleshooting

Verify that Ghostty is now running zsh rather than the older account shell:

```zsh
echo "$ZSH_VERSION"
ps -p $$ -o command=
echo "$HISTFILE"
```

Expected values include a zsh version, `/bin/zsh`, and
`~/.zsh_history`. `$SHELL` may still report `/bin/bash` for a directory-managed
account; Ghostty's explicit command is what controls the terminal process.

Inspect the active configurations:

```bash
ghostty +show-config | grep -E '^(theme|command|shell-integration|auto-update)'
devtheme current
ls -l ~/.config/starship.toml
```

Starship controls the prompt; zsh controls command history; Ghostty scrollback
controls text already displayed on screen. They are intentionally separate.

## Upstream references

- Ghostty configuration: <https://ghostty.org/docs/config>
- Ghostty shell integration: <https://ghostty.org/docs/features/shell-integration>
- Ghostty SSH integration: <https://ghostty.org/docs/features/ssh>
- Ghostty themes: <https://ghostty.org/docs/features/theme>
- Starship configuration: <https://starship.rs/config/>
- Starship presets: <https://starship.rs/presets/>
- zoxide: <https://github.com/ajeetdsouza/zoxide>
- Homebrew Bundle: <https://docs.brew.sh/Brew-Bundle-and-Brewfile>
