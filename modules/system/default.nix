{
  flake.nixosModules.system = {self, ...}: {
    imports = with self.nixosModules; [
      base
      hardware
      utils
      services
    ];
  };
}
