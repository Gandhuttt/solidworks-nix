# solidworks-wine

Nix packaging for running a licensed SOLIDWORKS 2026 SP4.1 under Wine 11.18 on NixOS. It packages the
**fixes and tooling**, not SOLIDWORKS: the installer, the installed program and the activation are yours and stay
outside the Nix store.

## Status

Barely usable, in the author's own assessment. Installing, activating, launching, GPU rendering, saving and STEP export
worked on one NixOS/AMD machine, and this repository fixes the startup crash, the assembly-save crash and a viewport
redraw glitch. Still rough: left clicks on some PropertyManager buttons are ignored (cause not found), long operations
can look like hangs while the `sldProcMon.exe` helper crashes, and "Enhanced graphics performance" is unavailable. Only
one machine and one GPU were ever tested. Licence: none has been chosen for this repository; the patches are against
Wine (LGPL-2.1-or-later) and are derived from it.

## What it builds

| Output | Contents |
|---|---|
| `packages.dlls` | Patched Wine pieces built from source (only the needed targets): `wininet`, `msxml3`, `comctl32_v6` (standalone PE DLLs) and `win32u.so` |
| `packages.wine` | A real copy of the stock nixpkgs Wine tree with only `win32u.so` replaced (a symlink farm does not work: Wine resolves symlinks and loads the stock file) |
| `packages.solidworks` (default) | Commands `solidworks`, `solidworks-launch`, `solidworks-reset`, `solidworks-restore-minimized`, `solidworks-setup-prefix`, `solidworks-extract-part`, plus the desktop entry |

Patches (`patches/`), each fixing one observed failure:

| Patch | Fixes |
|---|---|
| `solidworks-wininet-zero-seek` | installer download: an unchanged `InternetSetFilePointer` discarded unread data |
| `solidworks-wininet-standalone` | build option: no builtin marker, so a native override can load the DLL from the prefix |
| `solidworks-msxml3-explicit-empty` | activation: the wizard checksums text that needs `<CheckSum></CheckSum>`, Wine wrote `<CheckSum/>` |
| `solidworks-comctl32-hdm-layout-null` | startup crash: `HDM_LAYOUT` with a NULL `lParam` |
| `win32u-mesa-vendor-exchange-swap` | AMD GPUs only: black 3D viewport with vendor "ATI Technologies Inc." and a partial-redraw glitch with swap method "undefined"; both changes are gated on PCI vendor `0x1002` |

`solidworks-setup-prefix` also applies, to an existing prefix: the SOLIDWORKS XML schema namespace fix (assembly save
crash), `OpenGL Enable Scissor=0`, `ShowSystray=0` and crash capture to a file.

## Usage

```sh
nix run .#setup-prefix        # once, with SOLIDWORKS installed in ~/.wine-solidworks and not running
nix run .                     # start SOLIDWORKS
nix profile install .         # or install the commands and the desktop entry
```

Environment: `SOLIDWORKS_PREFIX` (default `~/.wine-solidworks`), `SW_VDESKTOP=1` (one Wine virtual desktop, works
around mis-routed clicks when the macro editor is open), `SW_SOFTWARE_GL=1` (CPU OpenGL).

## What was verified

- All outputs build; the shell scripts pass shellcheck (via `writeShellApplication`).
- Built DLLs are the same size as the working prefix copies (hashes differ: Wine builds are not bit-reproducible).
- `win32u.so` built from source, run in a throwaway prefix: on the AMD GPU the GL vendor reports `Mesa` and the swap
  method is `0x2028`; under software rendering (not AMD) the swap method stays Wine's stock `0x202a`, so the swap
  override really is gated. (The gate first read `egl->vendor_id`, which is still empty when pixel formats are
  described, and silently never fired on the AMD GPU; the test caught it.) The file mapped by the process is the one
  inside `packages.wine`.
- `solidworks-setup-prefix` on a synthetic prefix: installs the DLLs (identical to the build outputs), patches the
  schemas, sets the registry values, and a second run changes nothing.
- `solidworks` / `-reset` / `-setup-prefix` refuse or defer correctly while a process of *that* prefix is running and
  ignore other prefixes; the start lock stops a second click during startup, is released when startup ends (tested with a 2-minute
  stand-in: script returns after ~22 s, lock acquirable while the app is open), and a later click then reports
  "already running".
- Real session on the current build (`solidworks` command, `packages.wine`, gated swap override): the window comes up, the process maps the
  `win32u.so` from this package, the viewport renders (119,953 model-like pixels, same as the hand-made setup), a part's
  volume reads back correctly, and `BodyGroup.SLDASM` (the assembly that used to hang) saves a copy, closes, and the
  copy reopens with the same 27 components and no load errors or warnings. The project folder was unchanged.
  The `BodyGroup.SLDASM` copy test was run on the previous build (identical on this GPU); the launch, mapped
  `win32u.so`, viewport render, volume read-back, empty log (0 schema errors, 0 crashes) were repeated on the current one.
- Confirmed by the user on the current build, on their own assembly: hovering no longer makes parts vanish, and a
  normal Save works.
- **Not verified:** other GPUs, other Wine versions, and installing SOLIDWORKS from scratch with this package.

Scripting note: a script that calls `CreateObject("SldWorks.Application")` while SOLIDWORKS is not running makes Wine
start it itself, without the launcher's DLL overrides, and it crashes on a missing `comctl32` ordinal. Attach only to a
SOLIDWORKS started with `solidworks`.

## Extracting one part from an imported STEP assembly

`Save As > .sldprt` on an assembly turns the **whole** assembly into one part (a selection is not a filter), and on a
large imported assembly that takes minutes. SOLIDWORKS keeps the internal components of an imported STEP assembly as
ordinary files in `...\Temp\swx*\IC~~\`, and a part file is self-contained. `solidworks-extract-part [NAME]` reads
your current selection through the API (nothing is opened or changed), finds that part's cached file and copies it next
to the open document without overwriting anything. A selected sub-assembly is refused (its file references other
cached files). The refusals (SOLIDWORKS not running, nothing selected) are tested; extracting an actual selected part
with the command is not, only the same steps by hand (the copy loaded cleanly as a part).

## Known issue: PropertyManager buttons ignore left clicks (cause not found)

Seen once (assembly mate PropertyManager): left clicks on OK, Tangent and the alignment buttons did nothing, while
right-click > OK and Esc worked. Findings, from a passive low-level mouse logger (records button events only):

- Clicks are real (`injected=0`), reach Wine, and hit-test to the correct enabled `Button` controls; SOLIDWORKS was idle
  with no mouse capture or menu mode stuck.
- On a press the SOLIDWORKS button takes capture and focus; after the release it often still holds capture and stays in
  the pressed state (`BM_GETSTATE` 0xc where a normal Wine button reads 0x8), so the click never completes.
- Control: a throwaway window with a normal and an owner-drawn button, clicked with the same mouse in the same session,
  behaved correctly (release delivered, capture released, `BN_CLICKED` sent). So Wine's input path is healthy and the
  fault is on the SOLIDWORKS side of the button handling. Not yet explained why, and not reproduced on demand.

Logs are in `~/.local/state/solidworks-wine/investigations/`. The next step would be Wine message tracing
(`WINEDEBUG=+message`) from a fresh start, which cannot be turned on in a running session.

## Known issue: switching Wine trees on an existing prefix

Wine re-runs its prefix update when the `wine.inf` timestamp of the tree in use differs from the prefix's
`.update-timestamp`. Observed once, on the prefix this was developed with, going from a hand-made Wine copy to
`packages.wine`: the update stopped on a blocking "This application could not be started" dialog (the log shows
`wmadmod.dll` importing the missing `winegstreamer.dll`), and it had already rewritten 38 `Wow6432Node` COM registrations
to the 64-bit paths. The cause of the dialog was not found, and it did not appear when creating a fresh prefix.

What worked: stop the session, restore `system.reg`/`user.reg` from a backup taken before the first start, and leave
`.update-timestamp` equal to the new tree's `wine.inf` mtime (`1`, as in every Nix store tree) so no update runs. Wine
re-registers its own fonts by itself at each start, so nothing else needed fixing. Back up the two `.reg` files before
the first launch on a new tree. A Wine version bump needs a real update and is untested.

## Not covered

- **Installing SOLIDWORKS.** The installer needs manual steps this repository does not automate (WebView2 flags,
  a dismissed hidden dialog, edits to the MSI). What was done once is recorded in
  [docs/install-notes.md](docs/install-notes.md); the patched `wininet`/`msxml3` DLLs for it are in `packages.dlls`.
- **Activation** is bound to the machine (one activation used). It does not move with the package.
- **GPU coverage.** Both `win32u` changes come from tests on one AMD GPU (radeonsi, Mesa 26.2.4) and are limited to
  AMD devices (PCI vendor `0x1002`): the vendor-name change (`Mesa` instead of `ATI Technologies Inc.`) and the
  swap-method change (`WGL_SWAP_EXCHANGE_ARB` instead of `UNDEFINED`). Every other device, including software
  rendering, keeps Wine's stock values. Other AMD GPUs and drivers are untested. "Enhanced graphics performance" stays
  unavailable: making SOLIDWORKS treat the card as certified turned the viewport black in a test.
- **Other Wine versions.** The patches are against 11.18; a bump needs them rebased.
