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
      availableKernelModules = [
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "uas"
        "sd_mod"
        "sdhci_pci"
        "vmd"
        "virtio_pci"
        "virtio_scsi"
        "virtio_blk"
        "usbhid"
      ];
      kernelModules = [];
    };
    kernelModules = [];
    extraModulePackages = [];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
