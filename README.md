# nix config

Nix-darwin + home-manager configuration for macOS (Apple Silicon).

## Bootstrap on a factory-reset Mac

### 1. Install Determinate Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 2. Generate an SSH key and add to GitHub

```bash
ssh-keygen -t ed25519 -C "your@email.com"
cat ~/.ssh/id_ed25519.pub
```

Copy the output, add at [github.com/settings/keys](https://github.com/settings/keys).

### 3. Clone repos

```bash
git clone git@github.com:Sombrechip88244/nix.git ~/.config/nix
git clone git@github.com:Sombrechip88244/secrets.git ~/Developer/secrets
```

### 4. Update hostname

```bash
scutil --get LocalHostName
```

Edit `~/.config/nix/flake.nix` and set `darwinConfigurations."YourHostName"`.

### 5. Make SSH key active

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

### 6. Build
```bash
sudo darwin-rebuild switch --flake ~/.config/nix#MacBookAir
```

Open a new terminal. From now on, just run `rebuild`.

---

## Updating

```bash
nix flake update    # refresh all inputs
rebuild             # apply
```

## Layout

```
~/.config/nix/
├── flake.nix              # entry point, inputs, outputs
├── flake.lock             # pinned input versions
├── configuration.nix      # system-level (packages, defaults, homebrew)
├── home.nix               # user-level (packages, programs, dotfiles)
├── dotfiles/              # managed config files
│   ├── tmux/
│   ├── zellij/
│   ├── zed/
│   ├── btop/
│   ├── cmux/
│   ├── opencode/
│   └── ghostty/
└── nix.conf               # local nix settings
```

## What's managed

| Layer | Managed by | What |
|-------|------------|------|
| **System** | `configuration.nix` | Packages, Homebrew casks, macOS defaults, fonts, auto-GC, launchd agents |
| **User** | `home.nix` | Packages, git/ssh/gh/direnv config, zsh + OMZ plugins, starship, bat, fzf, eza |
| **Dotfiles** | `home.nix` → `dotfiles/` | tmux, zellij, zed, btop, cmux, opencode, ghostty |
| **Secrets** | Private repo → home-manager symlink | API keys, env vars (never in this repo) |
