{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/k8s-vps.nix
    ./network.nix
  ];

  networking.hostName = "oci-vps-2";

  kubernetesNode.nodeIP = "100.83.7.89";

  # OCI boots UEFI with Ubuntu's stock layout: a 106MB ESP (sda15) that is
  # far too small for NixOS kernels+initrds, plus a 913MB ext4 /boot
  # (sda16). Unlike sakura/vultr's BIOS grub on /dev/vda, install GRUB as
  # the removable EFI loader (OCI NVRAM entries don't survive instance
  # lifecycle events) and keep kernels on the ext4 /boot.
  boot.loader.grub = {
    device = lib.mkForce "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # OCI's serial console (console history + interactive console connection)
  # reads ttyS0; without this the whole boot is invisible when SSH is down.
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];
}
