{ config, lib, pkgs, modulesPath, ... }:

# PLACEHOLDER — regenerate this file for real once the VPS has been
# partitioned. Boot the installer ISO, run `vultr-install` (which
# partitions /dev/vda: a small BIOS-boot partition plus a single ext4
# root), then run:
#
#   nixos-generate-config --root /mnt
#
# and copy the resulting hardware-configuration.nix over this file before
# the final `nixos-install` (vultr-install does the install directly from
# the flake, so in practice: install once, regenerate, commit, rebuild).

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
