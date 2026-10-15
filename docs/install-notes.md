# Installing SOLIDWORKS 2026 SP4.1 under Wine: what was done once

**This is a record, not a procedure.** It describes what got one install working on one machine (NixOS, AMD GPU,
Wine 11.18). Nothing here is automated, and nobody has repeated it from scratch. SOLIDWORKS itself, its installer, and
any licence are yours and are not part of this repository. A valid licence is required; the notes only cover making the
software run, not obtaining or bypassing a licence.

Prefix: a 64-bit Wine prefix (`WINEARCH=win64`) at `~/.wine-solidworks`, using the Wine from `packages.wine`.

## Installer (`SolidWorksSetup.exe`, then `sldIM.exe`)

- The installer UI is WebView2. It needs `--disable-gpu-sandbox`; `docs/reference/launch-installer.sh` also opens a
  loopback remote-debugging port so the real UI can be driven, because the desktop presentation stayed broken.
- A Windows-version warning dialog was invisible; it was dismissed over that debugging port.
- The installer's HTTP downloads lost data on a seek that did not move the file pointer; the patched `wininet`
  (`solidworks-wininet-zero-seek`) fixes that. It is used through an installer-local native override
  (`WINEDLLOVERRIDES='mshtml=;wininet=n,b'`).
- A native 32-bit MSXML6 (from winetricks) was needed for the installation manager; the 64-bit builtin was kept for
  `msiexec`.

## Finishing the install (the MSI)

The MSI run failed until three things were changed in a **copy** of `swwi/data/solidworks.msi` (keep the original):

1. The `InstallSpatialIOP` custom action failed under Wine (the Shell zip folder it relies on is missing, error 1603),
   so its condition was set to `0` and `spatialiop.zip` was extracted by hand into
   `C:\Program Files\SOLIDWORKS Corp\SOLIDWORKS\spiop\files`.
2. `ADDLOCAL` was set explicitly (an install of 140 features) by adding type-51 property actions.
3. The `FollowParent` bit was cleared on nine optional add-in features (Toolbox, Simulation, Routing, Motion, Costing,
   ScanTo3D, TolAnalyst, DesignChecker, PCB).

About 5,600 empty stale `Installer` component keys were also removed from `system.reg` (a backup was taken first).
Not verified: whether each of these edits is individually required.

## Activation

The activation wizard (`swactwiz.exe`) checksums the request text and requires the literal `<CheckSum></CheckSum>`;
Wine's msxml3 wrote `<CheckSum/>`. The patched `msxml3` (`solidworks-msxml3-explicit-empty`), placed beside the wizard
with a native override, fixes that serialisation difference. Activation counts against the licence's activation limit.

## After installing

Run `solidworks-setup-prefix` (see the README) to place the patched DLLs, apply the schema fix and set the registry
values, then start it with `solidworks`.
