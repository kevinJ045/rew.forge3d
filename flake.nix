{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    # nixpkgs.url = "github:nixos/nixpkgs";
  };
  outputs = { self, nixpkgs, utils }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = (import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowInsecure = true;
          permittedInsecurePackages = [
            "freeimage-unstable-2021-11-01"
          ];
        };
      });
      libraries = with pkgs; [
        mesa
        libGL
        libGLU
        glew
        xwayland
        glfw
        freeglut
        # glew110
        pkg-config
        xorg.libX11
        freeimage
      ];
    in
    {
      devShell = pkgs.mkShell {
        buildInputs = libraries;
        
        shellHook = ''
          echo $LD_LIBRARY_PATH
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libraries}:$LD_LIBRARY_PATH
        '';
      };
    }
  );
}
