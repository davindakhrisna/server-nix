{
  flake.nixosModules.hardware = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.var;
  in {
    options.var = {
      cpu = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["intel" "amd"]);
        default = null;
        description = "CPU type: intel or amd";
      };

      gpu = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["nvidia" "amd" "intel"]);
        default = null;
        description = "GPU type: nvidia, amd, or intel";
      };

      nvidia = {
        mode = lib.mkOption {
          type = lib.types.enum ["desktop" "offload" "sync"];
          default = "desktop";
          description = "Nvidia mode: desktop (dedicated GPU) or offload/sync (hybrid laptop PRIME)";
        };
        intelBusId = lib.mkOption {
          type = lib.types.str;
          default = "PCI:0:2:0";
          description = "Intel iGPU PCI Bus ID for PRIME";
        };
        nvidiaBusId = lib.mkOption {
          type = lib.types.str;
          default = "PCI:1:0:0";
          description = "Nvidia GPU PCI Bus ID for PRIME";
        };
      };
    };

    config = lib.mkMerge [
      # CPU: Intel
      (lib.mkIf (cfg.cpu == "intel") {
        hardware.cpu.intel.updateMicrocode = true;
        services.thermald.enable = true;
      })

      # CPU: AMD
      (lib.mkIf (cfg.cpu == "amd") {
        hardware.cpu.amd.updateMicrocode = true;
      })

      # GPU: Nvidia
      (lib.mkIf (cfg.gpu == "nvidia") {
        services.xserver.videoDrivers = ["nvidia"];
        hardware.graphics = {
          enable = true;
          extraPackages = with pkgs; [
            nvidia-vaapi-driver
          ];
        };
        hardware.nvidia = {
          open = false;
          modesetting.enable = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          powerManagement.enable = true;
          powerManagement.finegrained = cfg.nvidia.mode == "offload";

          prime = lib.mkIf (cfg.nvidia.mode != "desktop") {
            offload = {
              enable = cfg.nvidia.mode == "offload";
              enableOffloadCmd = cfg.nvidia.mode == "offload";
            };
            sync.enable = cfg.nvidia.mode == "sync";
            inherit (cfg.nvidia) intelBusId nvidiaBusId;
          };
        };
      })

      # GPU: AMD
      (lib.mkIf (cfg.gpu == "amd") {
        services.xserver.videoDrivers = ["amdgpu"];
        hardware.graphics = {
          enable = true;
          extraPackages = with pkgs; [
            vaapiVdpau
            libvdpau-va-gl
          ];
        };
      })
    ];
  };
}
