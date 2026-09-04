{self, ...}: {
  flake.homeModules = {
    shell = {...}: {
      imports = with self.homeModules; [
        utils-zsh
        utils-cli
      ];
    };

    # Aliases for backwards and multi-module compatibility
    utils = self.homeModules.shell;
    shell-zsh = self.homeModules.utils-zsh;
    shell-cli = self.homeModules.utils-cli;
  };
}
