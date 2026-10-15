{
  description = "SOLIDWORKS under Wine: patched Wine pieces, launcher and prefix tooling (SOLIDWORKS itself is not included)";

  # Same nixpkgs release the setup was developed against (Wine 11.18).
  inputs.nixpkgs.url = "https://releases.nixos.org/nixpkgs/nixpkgs-26.11pre1088030.8edc0c72e3a3/nixexprs.tar.zst";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      stockWine = pkgs.wineWow64Packages.unstable;

      patchDir = ./patches;

      # One build that produces every patched Wine piece we need. Only the listed targets are built, not all of Wine.
      #  - wininet, msxml3, comctl32_v6: standalone PE DLLs (no builtin marker, see wininet-standalone.patch) that the
      #    prefix loads through native overrides.
      #  - win32u.so: unix half of win32u, used inside the patched Wine tree below.
      dlls = stockWine.overrideAttrs (old: {
        pname = "wine-solidworks-dlls";
        patches = (old.patches or [ ]) ++ [
          "${patchDir}/solidworks-wininet-standalone.patch"
          "${patchDir}/solidworks-wininet-zero-seek.patch"
          "${patchDir}/solidworks-msxml3-explicit-empty.patch"
          "${patchDir}/solidworks-comctl32-hdm-layout-null.patch"
          "${patchDir}/win32u-mesa-vendor-exchange-swap.patch"
        ];
        buildPhase = ''
          runHook preBuild
          make -j$NIX_BUILD_CORES \
            dlls/wininet/i386-windows/wininet.dll dlls/wininet/x86_64-windows/wininet.dll \
            dlls/msxml3/i386-windows/msxml3.dll dlls/msxml3/x86_64-windows/msxml3.dll \
            dlls/comctl32_v6/x86_64-windows/comctl32_v6.dll \
            dlls/win32u/win32u.so
          runHook postBuild
        '';
        installPhase = ''
          mkdir -p $out/i386-windows $out/x86_64-windows $out/x86_64-unix
          cp dlls/wininet/i386-windows/wininet.dll dlls/msxml3/i386-windows/msxml3.dll $out/i386-windows/
          cp dlls/wininet/x86_64-windows/wininet.dll dlls/msxml3/x86_64-windows/msxml3.dll \
             dlls/comctl32_v6/x86_64-windows/comctl32_v6.dll $out/x86_64-windows/
          cp dlls/win32u/win32u.so $out/x86_64-unix/
        '';
        postInstall = "";
        postFixup = "";
        outputs = [ "out" ];
      });

      # The stock Wine tree (a real copy) with only win32u.so replaced. It must be a copy, not a symlink farm: Wine
      # resolves symlinks when locating lib/wine, so a farm silently loads the stock win32u.so (checked).
      wine = pkgs.runCommand "wine-solidworks-${stockWine.version}" { nativeBuildInputs = [ pkgs.binutils ]; } ''
        cp -r --preserve=mode ${stockWine} $out
        chmod -R u+w $out
        install -m 0755 ${dlls}/x86_64-unix/win32u.so $out/lib/wine/x86_64-unix/win32u.so
        # Installed outside the dirs Nix strips, so strip it here like the stock tree.
        strip --strip-unneeded $out/lib/wine/x86_64-unix/win32u.so
      '';

      vdrestore = pkgs.runCommand "vdrestore.exe" { nativeBuildInputs = [ pkgs.pkgsCross.mingwW64.stdenv.cc ]; } ''
        x86_64-w64-mingw32-gcc ${./tools/vdrestore.c} -o $out -luser32
      '';

      mkScript = name: runtimeInputs: extraEnv: pkgs.writeShellApplication {
        inherit name runtimeInputs;
        runtimeEnv = { SW_WINE = "${wine}"; SW_DLLS = "${dlls}"; } // extraEnv;
        text = builtins.readFile ./scripts/lib.sh + builtins.readFile ./scripts/${name}.sh;
      };

      launch = mkScript "solidworks-launch" [ ] { };
      reset = mkScript "solidworks-reset" [ pkgs.procps pkgs.coreutils pkgs.gnugrep pkgs.libnotify ] { };
      restoreMinimized = mkScript "solidworks-restore-minimized" [ ] { SW_VDRESTORE = "${vdrestore}"; };
      setupPrefix = mkScript "solidworks-setup-prefix" [ pkgs.python3 pkgs.icoutils pkgs.procps pkgs.coreutils pkgs.gnugrep ] { };
      extractPart = mkScript "solidworks-extract-part" [ pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.procps ] { };
      start = mkScript "solidworks" [ launch pkgs.procps pkgs.coreutils pkgs.gnugrep pkgs.util-linux pkgs.libnotify ] { };

      desktopItem = pkgs.makeDesktopItem {
        name = "solidworks";
        desktopName = "SOLIDWORKS 2026";
        comment = "SOLIDWORKS under Wine";
        exec = "${start}/bin/solidworks";
        icon = "solidworks";
        categories = [ "Graphics" "Engineering" ];
        startupWMClass = "sldworks.exe";
        actions.Reset = {
          name = "Reset SOLIDWORKS session (stops leftover processes)";
          exec = "${reset}/bin/solidworks-reset";
        };
      };

      solidworks = pkgs.symlinkJoin {
        name = "solidworks-wine";
        paths = [ start launch reset restoreMinimized setupPrefix extractPart desktopItem ];
      };
    in
    {
      packages.${system} = {
        inherit dlls wine solidworks;
        default = solidworks;
      };

      apps.${system} = {
        default = { type = "app"; program = "${start}/bin/solidworks"; meta.description = "Start SOLIDWORKS from the Wine prefix"; };
        setup-prefix = { type = "app"; program = "${setupPrefix}/bin/solidworks-setup-prefix"; meta.description = "Apply the patched DLLs, schema fix and registry settings to an existing prefix"; };
      };
    };
}
