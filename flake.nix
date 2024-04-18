{
  description = "Hyprspace";

  inputs.hyprland.url = "github:hyprwm/Hyprland";

  outputs = {
    self,
    hyprland,
  }: let
    inherit (hyprland.inputs) nixpkgs;
    inherit (nixpkgs) lib;

    # System types to support.
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    perSystem = attrs:
      lib.genAttrs supportedSystems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        attrs system pkgs);

    # Generate version
    inherit (builtins) elemAt head readFile split substring;
    mkDate = longDate: (lib.concatStringsSep "-" [
      (substring 0 4 longDate)
      (substring 4 2 longDate)
      (substring 6 2 longDate)
    ]);
    version =
      (head (split "'"
        (elemAt
          (split " version: '" (readFile ./meson.build))
          2)))
      + "+date=${mkDate (self.lastModifiedDate or "19700101")}_${self.shortRev or "dirty"}";
  in {
    # Provide some binary packages for selected system types
    packages = perSystem (system: pkgs: {
      Hyprspace = let
        hyprlandPkg = hyprland.packages.${system}.hyprland;
      in
        pkgs.gcc13Stdenv.mkDerivation {
          pname = "Hyprspace";
          inherit version;
          src = ./.;

          inherit (hyprlandPkg) nativeBuildInputs;
          buildInputs = [hyprlandPkg] ++ hyprlandPkg.buildInputs;

          meta = with lib; {
            homepage = "https://github.com/KZDKM/Hyprspace";
            description = "Workspace overview plugin for Hyprland";
            license = licenses.gpl2Only;
            platforms = platforms.linux;
          };
        };
      default = self.packages.${system}.Hyprspace;
    });

    # The default environment for 'nix develop'
    devShells = perSystem (system: pkgs: {
      default = pkgs.mkShell {
        shellHook = ''
          meson setup build --reconfigure
          sed -e 's/c++23/c++2b/g' ./build/compile_commands.json > ./compile_commands.json
        '';
        name = "Hyprspace-shell";
        nativeBuildInputs = with pkgs; [gcc13];
        buildInputs = [hyprland.packages.${system}.hyprland];
        inputsFrom = [
          hyprland.packages.${system}.hyprland
          self.packages.${system}.Hyprspace
        ];
      };
    });

    formatter = perSystem (_: pkgs: pkgs.alejandra);
  };
}
