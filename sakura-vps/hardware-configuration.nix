{ config, lib, pkgs, modulesPath, ... }:

# PLACEHOLDER — regenerate this file for real once the VPS has been
# partitioned. Boot the installer ISO, partition /dev/vda (a single ext4
# root partition plus a small BIOS-boot partition is enough for GRUB in
# legacy/BIOS mode), mount it at /mnt, then run:
#
#   nixos-generate-config --root /mnt
#
# and copy the resulting hardware-configuration.nix over this file before
# running `nixos-install`.

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
