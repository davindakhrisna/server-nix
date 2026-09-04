{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "vmd" "ahci" "nvme" "uas" "usbhid" "sd_mod"];
      kernelModules = [];
    };
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/29540d14-8554-4252-9dcc-9b661691617f";
    fsType = "btrfs";
    options = ["noatime" "compress=zstd" "discard=async" "space_cache=v2"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/05AB-EA3B";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/6454d227-991a-488a-b649-e951d5d65f1f";}
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
