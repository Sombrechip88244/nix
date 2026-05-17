{
  description = "M1 MacBook Air Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    secrets = {
      url = "git+ssh://git@github.com/Sombrechip88244/secrets.git";
      flake = false;
    };

    pi-skills = {
      url = "github:badlogic/pi-skills";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, darwin, home-manager, nix-homebrew, secrets, pi-skills, ... }: {
    darwinConfigurations."MacBookAir" = darwin.lib.darwinSystem {
      system = "aarch64-darwin";

      modules = [
        ./configuration.nix

        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "oliverfildes";
            autoMigrate = true;
          };
        }

        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.oliverfildes = { lib, ... }: {
            _module.args.secretsPath = builtins.toString secrets;
            _module.args.piSkillsSrc = pi-skills;
            home = {
              username = "oliverfildes";
              homeDirectory = lib.mkForce "/Users/oliverfildes";
              stateVersion = "24.11";
            };

            imports = [ ./home.nix ];
          };
        }
      ];
    };
  };
}
