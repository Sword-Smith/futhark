# This default.nix builds a tarball containing a statically linked
# Futhark binary and some manpages.  Likely to only work on linux.
#
# Just run 'nix-build' and fish the tarball out of 'result/'.

{ nixpkgs ? import <nixpkgs> {},
  compiler ? "ghc883",
  suffix ? "nightly" }:
let
  pkgs = nixpkgs;

  futhark =
    pkgs.haskell.lib.overrideCabal
      (pkgs.haskell.lib.addBuildTools
        (pkgs.haskell.packages.${compiler}.callCabal2nix "futhark"
          ( pkgs.lib.cleanSourceWith { filter = name: type:
                                         baseNameOf (toString name) != "default.nix";
                                       src = pkgs.lib.cleanSource ./.;
                                     })
          { })
        [ pkgs.python37Packages.sphinx ])
    ( _drv: {
      isLibrary = false;
      isExecutable = true;
      enableSharedExecutables = false;
      enableSharedLibraries = false;
      enableLibraryProfiling = false;
      configureFlags = [
        "--ghc-option=-optl=-static"
        "--ghc-option=-split-sections"
        "--extra-lib-dirs=${pkgs.ncurses.override { enableStatic = true; }}/lib"
        "--extra-lib-dirs=${pkgs.glibc.static}/lib"
        "--extra-lib-dirs=${pkgs.gmp6.override { withStatic = true; }}/lib"
        "--extra-lib-dirs=${pkgs.zlib.static}/lib"
        "--extra-lib-dirs=${pkgs.libffi.overrideAttrs (old: { dontDisableStatic = true; })}/lib"
        ];

      postBuild = (_drv.postBuild or "") + ''
        make -C docs man
        '';

      postInstall = (_drv.postInstall or "") + ''
        mkdir -p $out/share/man/man1
        mv docs/_build/man/*.1 $out/share/man/man1/
        '';
      }
    );
in pkgs.stdenv.mkDerivation rec {
  name = "futhark-" + suffix;
  version = futhark.version;
  src = tools/release;

  buildInputs = [ futhark ];

  buildPhase = ''
    mv skeleton futhark-${suffix}/
    cp -r ${futhark}/bin futhark-${suffix}/bin
    cp -r ${futhark}/share futhark-${suffix}/share
    chmod +w -R futhark-${suffix}
    tar -Jcf futhark-${suffix}.tar.xz futhark-${suffix}
  '';

  installPhase = ''
    mkdir -p $out
    cp futhark-${suffix}.tar.xz $out/futhark-${suffix}.tar.xz
  '';
}
