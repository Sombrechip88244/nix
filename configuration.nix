{ config, lib, pkgs, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Required for user-level options (homebrew, system.defaults)
  system.primaryUser = "oliverfildes";

  # Don't verify Nix version (required for Determinate Nix)
  system.checks.verifyNixPath = false;

  # Don't manage nix.conf (Determinate Nix handles it)
  nix.enable = false;

  # System packages
  environment.systemPackages = with pkgs; [
    git
    docker
    docker-compose
    ffmpeg
    neovim
    ripgrep
    jq
    htop
    curl
    wget
    unzip
    zip
    pi-coding-agent
    zsh
    btop

    # Also in home-manager, but needed early in PATH for shell init
    starship
    zoxide
    eza
    zellij
  ];

  # Shell config
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  # macOS defaults
  system.defaults = {
    # Dock
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      orientation = "left";
      mineffect = "scale";
      minimize-to-application = true;
      show-recents = false;
      tilesize = 36;
      mru-spaces = false;
      persistent-apps = [
        "/Applications/Ghostty.app"
        "/Applications/Arc.app"
        "/Applications/Obsidian.app"
      ];
    };

    # Finder
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      ShowStatusBar = true;
      ShowPathbar = true;
      FXPreferredViewStyle = "clmv";
      FXRemoveOldTrashItems = true;
      FXEnableExtensionChangeWarning = false;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      QuitMenuItem = true;
    };

    # Trackpad
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    # Global
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticWindowAnimationsEnabled = false;
      AppleShowScrollBars = "Always";
      NSTableViewDefaultSizeMode = 1;
      _HIHideMenuBar = false;
    };

    # Screenshots
    screencapture = {
      location = "~/Desktop";
      type = "png";
      disable-shadow = true;
      show-thumbnail = false;
    };

    # Security
    loginwindow = {
      GuestEnabled = false;
    };

    screensaver = {
      askForPasswordDelay = 0;
    };
  };

  # Homebrew
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    taps = [];
    brews = [];
    casks = [
      "ghostty"
      "obsidian"
      "arc"
      "discord"
      "iina"
      "maccy"
      "hiddenbar"
      "jellyfin-media-player"
      "alfred"
      "tailscale-app"
    ];
  };

  # Auto GC (manual launchd because nix.enable = false for Determinate Nix)
  launchd.user.agents.nix-gc = {
    command = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 30d";
    serviceConfig = {
      StartCalendarInterval = [{ Weekday = 0; Hour = 12; Minute = 0; }];
      RunAtLoad = false;
    };
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.sauce-code-pro
  ];

  system.stateVersion = 4;
}
