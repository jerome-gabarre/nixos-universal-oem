# /etc/nixos/flake.nix
{
  description = "NixOS Master Universel OEM - GitOps, Agnostique & 100% Natif Rust/Go";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    # Découplage matériel : charge le fichier hardware local s'il existe, sinon utilise un profil générique par labels
    localHardwareModule =
      if builtins.pathExists /etc/nixos/hardware-configuration.nix then
        /etc/nixos/hardware-configuration.nix
      else if builtins.pathExists ./hardware-configuration.nix then
        ./hardware-configuration.nix
      else
        ({ lib, ... }: {
          fileSystems."/" = lib.mkDefault {
            device = "/dev/disk/by-label/NIXOS_ROOT";
            fsType = "ext4";
          };
          fileSystems."/boot" = lib.mkDefault {
            device = "/dev/disk/by-label/NIXOS_BOOT";
            fsType = "vfat";
          };
        });

    mkDynamicSystem = system: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        localHardwareModule
        ./configuration.nix
        ./universal-rome-suite.nix
      ];
    };
  in {
    nixosConfigurations = {
      universal = mkDynamicSystem "x86_64-linux";
      universal-arm64 = mkDynamicSystem "aarch64-linux";
    };
  };
}
