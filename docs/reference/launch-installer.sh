#!/usr/bin/env bash
set -euo pipefail
# REFERENCE ONLY: the installer launcher used once on the author's machine. Paths are hard-coded; not part of the flake.
# Installer-only WinINet override: fixes response loss on a no-op HTTP seek.
# Desktop WebView2 presentation is still broken; loopback CDP exposes the real UI.
# Prefix MSXML6 default is builtin; sldIM.exe has a native,builtin app override.
# The native 64-bit DLL fails initialization; native 32-bit MSXML remains for IM.
export WINEPREFIX="$HOME/.wine-solidworks"
export WINEARCH=win64
export WINEDEBUG=err+all,fixme-all
export WINEDLLOVERRIDES='mshtml=;wininet=n,b'
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS='--disable-gpu-sandbox --remote-debugging-address=127.0.0.1 --remote-debugging-port=19227'
cd "$WINEPREFIX/drive_c/swdist/SOLIDWORKS_2026_sp04.1/sldim"
exec nix-shell -I nixpkgs=https://releases.nixos.org/nixpkgs/nixpkgs-26.11pre1088030.8edc0c72e3a3/nixexprs.tar.zst -p wineWow64Packages.unstable --run 'wine sldIM.exe'
