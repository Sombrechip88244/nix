{ config, pkgs, secretsPath, ... }:

{
  home.packages = with pkgs; [
    fd
    fzf
    bat
    lazygit
    yazi
    btop
    dust
    duf
    procs
    bottom
    httpie
    gh
    fastfetch
    cmatrix
    tldr
    helix
    zsh-completions
    opencode
    delta
    direnv
    nix-direnv

    # Dev tooling
    awscli2
    kubectl
    nodejs
    go
    rustup
  ];

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      character.success_symbol = "[➜](bold green)";
      character.error_symbol = "[➜](bold red)";
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat = {
    enable = true;
    config.theme = "Gruvbox";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "always";
    git = true;
    extraOptions = [ "--group-directories-first" ];
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Sombrechip88244";
        email = "166306750+Sombrechip88244@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
      merge.conflictStyle = "zdiff3";
      url."git@github.com:".insteadOf = "gh:";
    };
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
    extraConfig = ''
      Include ~/.orbstack/ssh/config
    '';
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    history = {
      size = 100000;
      save = 100000;
      path = "~/.config/zsh/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
    };

    loginExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :
    '';

    initContent = ''
      if [ -f "$HOME/.api-keys" ]; then
        source "$HOME/.api-keys"
      fi

      eval "$(zellij setup --generate-auto-start zsh)"
    '';

    shellAliases = {
      rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix#MacBookAir";
      tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
      ls = "eza --icons=always --git-repos-no-status";
      lsa = "eza --icons=always --all";
      obsai = "(cd ~/notes/obsidian-notes/ && pi)";
      cd = "z";
      zi = "z -i";
      za = "z -a";
      zq = "z -q";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "aws"
        "kubectl"
        "kubectx"
        "rust"
      ];
    };
  };

  xdg.configFile = {
    "tmux/tmux.conf".source = ./dotfiles/tmux/tmux.conf;
    "tmux/tmux.reset.conf".source = ./dotfiles/tmux/tmux.reset.conf;
    "tmux/scripts/cal.sh" = {
      source = ./dotfiles/tmux/scripts/cal.sh;
      executable = true;
    };
    "zed/settings.json".source = ./dotfiles/zed/settings.json;
    "zellij/config.kdl".source = ./dotfiles/zellij/config.kdl;
    "btop/btop.conf".source = ./dotfiles/btop/btop.conf;
    "cmux/settings.json".source = ./dotfiles/cmux/settings.json;
    "opencode/config.jsonc".source = ./dotfiles/opencode/config.jsonc;
    "opencode/config.local.json".source = "${secretsPath}/opencode/config.local.json";
    "ghostty/config".source = ./dotfiles/ghostty/config;
  };

  home.file = {
    ".api-keys".source = "${secretsPath}/api-keys";
    ".hushlogin".text = "";
    ".pi/agent/settings.json".source = ./dotfiles/pi/settings.json;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BROWSER = "open";
    PAGER = "bat";
  };
}
