{ modulesPath, ... }:

# Ubuntu's stock OCI partition layout, kept as-is by nixos-infect:
# sda1 root, sda15 the (tiny) ESP, sda16 the ext4 /boot that holds
# kernels and grub.cfg.
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/7b6acfda-4881-4b46-93d8-7f282f6c5548";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/69ff1a96-45f5-4d0e-adf5-cfa2b537ab41";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/683A-3428";
    fsType = "vfat";
  };
}
