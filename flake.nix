{
  description = "hakyll-nix-template";

  nixConfig = {
    allow-import-from-derivation = "true";
    bash-prompt = "[hakyll-nix]λ ";
  };

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        hakyll-site = pkgs.haskell.lib.justStaticExecutables (pkgs.haskellPackages.callPackage ./ssg {});
        website = pkgs.stdenv.mkDerivation {
          name = "website";
          src = ./.;
          # This hack is needed apparently https://github.com/jaspervdj/hakyll/pull/1017
          LANG = "en_US.UTF-8";
          buildPhase = ''
            ${hakyll-site}/bin/hakyll-site build --verbose
          '';
          installPhase = ''
            mkdir -p "$out/dist"
            cp -a dist/. "$out/dist"
          '';
        } // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
        };

      in
      {
        apps = {
          default = flake-utils.lib.mkApp {
            drv = hakyll-site;
            exePath = "/bin/hakyll-site";
          };
        };

        packages = {
          inherit hakyll-site website;
          default = website;
        };
      }
    );
}
