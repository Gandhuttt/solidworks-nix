# Installing SOLIDWORKS 2026 SP4.1 under Wine: what was done once

**This is a record, not a procedure.** It describes what got one install working on one machine (NixOS, AMD GPU,
Wine 11.18). Nothing here is automated, and nobody has repeated it from scratch. SOLIDWORKS itself, its installer, and
any licence are yours and are not part of this repository. A valid licence is required; the notes only cover making the
software run, not obtaining or bypassing a licence.

Every statement below is labelled by what backs it:

- **[checked]**: compared against a file on that machine (the edited MSI against the saved original, the installer log,
  a registry backup, the patch itself).
- **[script]**: stated in `docs/reference/launch-installer.sh`, not independently re-run.
- **[memory]**: done by hand during the original session and not re-checked afterwards.

Prefix: a 64-bit Wine prefix (`WINEARCH=win64`) at `~/.wine-solidworks`, using the Wine from `packages.wine`.

## Installer (`SolidWorksSetup.exe`, then `sldIM.exe`)

- **[script]** The installer UI is WebView2 and is started with `--disable-gpu-sandbox`. The launcher also opens a
  loopback remote-debugging port, because "desktop WebView2 presentation is still broken; loopback CDP exposes the real
  UI".
- **[script]** A patched `wininet` is loaded through an installer-local native override
  (`WINEDLLOVERRIDES='mshtml=;wininet=n,b'`) to fix "response loss on a no-op HTTP seek". The patch
  (`solidworks-wininet-zero-seek`) skips resetting the read state when a seek does not move the file position
  **[checked]**.
- **[script]** The prefix's default MSXML6 is builtin; the native 64-bit DLL failed to initialise, and a native 32-bit
  MSXML stays for the installation manager. **[memory]** That native 32-bit MSXML6 came from winetricks.
- **[memory]** A Windows-version warning dialog was invisible and was dismissed over the debugging port.

## Finishing the install (the MSI)

The first install run failed. **[checked]** `SummaryIMLog_…_00017.txt` ends `** Install FAILED with code 1603`, directly
after `WIDll_InstallSpatialIOP` logged `Unzip failed` (inside `UnzipWithProgress`). **Not established:** why the unzip
failed. A missing Shell zip-folder handler in Wine was a theory and was never confirmed.

The install then completed using a **copy** of `swwi/data/solidworks.msi` with these changes. **[checked]** by dumping
every table of the original and the edited MSI with `msitools` and diffing them: exactly three tables differ.

1. `CustomAction` / `InstallExecuteSequence`: nine added type-51 actions, `sw_wine_addlocal_01` to `_09`, each setting
   `ADDLOCAL`, scheduled at sequence 771 to 779 with the condition `SLDIM=1 And Not REMOVE~="ALL"`. Together they name
   **133** distinct features, out of 222 defined in the MSI's `Feature` table (an earlier draft of these notes said
   140; that was wrong).
2. `InstallSpatialIOP`: its condition changed from `NOT REMOVE~="ALL"` to `0`, so it no longer runs.
3. `Feature`: nine features changed from attribute 10 to 8, which clears the `FollowParent` bit: Motion, PCB, ScanTo3D,
   SolidWorksCosting, SolidWorksDesignChecker, SolidWorksRoutedsystems, Simulation, SolidWorksToolbox, TolAnalyst.

**Not verified:** whether each of these three edits is individually required, or whether the install would have worked
with fewer.

- **[memory]** With `InstallSpatialIOP` skipped, `spatialiop.zip` was extracted by hand into
  `C:\Program Files\SOLIDWORKS Corp\SOLIDWORKS\spiop\files`. **[checked]** That folder is populated in the prefix
  (about 2 GB).
- **[checked]** Cleanup of stale registry keys: a backup taken beforehand (`system.reg.before-cleanup`) held 7,631
  `Installer\UserData\S-1-5-18\Components` keys, of which **5,593** had no values at all; the live registry has none
  with no values now. **Not established:** that this cleanup was needed for anything to work.

## Activation

- **[checked]** The patched `msxml3` (`solidworks-msxml3-explicit-empty`) makes Wine serialise an element with no
  children as `<X></X>` instead of `<X/>`. It is placed beside the activation wizard (`swactwiz.exe`) with a native
  override.
- **[memory]** The reason: the wizard checksums the request text and requires the literal `<CheckSum></CheckSum>`,
  which Wine's msxml3 wrote as `<CheckSum/>`. That came from reading the wizard's code during the original session and
  was not re-checked for these notes.
- **[memory]** Activation counted against the licence's activation limit.

## After installing

Run `solidworks-setup-prefix` (see the README) to place the patched DLLs, apply the schema fix and set the registry
values, then start it with `solidworks`.
