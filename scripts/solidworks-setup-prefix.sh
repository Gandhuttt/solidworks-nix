# Idempotently applies everything this package needs inside an existing SOLIDWORKS Wine prefix:
#   - patched comctl32 (startup crash), wininet and msxml3 DLLs copied into the places the native overrides read them
#   - SOLIDWORKS XML schema fix (assembly save crash)
#   - registry: scissor off (viewport partial-redraw glitch), Wine systray window off, crash capture to a file
#   - icon extracted from SLDWORKS.exe for the desktop entry
# It does NOT install SOLIDWORKS (the installer is proprietary and the install needs manual steps), and it refuses to
# run while SLDWORKS.exe is running because it replaces DLLs that are mapped by the running process.
#   solidworks-setup-prefix [--revert-schemas]
export WINEDEBUG=-all
state="${XDG_STATE_HOME:-$HOME/.local/state}/solidworks-wine"
c="$WINEPREFIX/drive_c"
sw="$c/Program Files/SOLIDWORKS Corp/SOLIDWORKS"

if [ ! -f "$sw/SLDWORKS.exe" ]; then
  echo "SOLIDWORKS is not installed in $WINEPREFIX (no $sw/SLDWORKS.exe)." >&2
  exit 1
fi
if sw_running; then
  echo "SLDWORKS.exe is running: close it first (this replaces DLLs it has loaded)." >&2
  exit 1
fi

# install SRC DEST: copy only when different; keep the original once as DEST.orig when DEST already exists.
install_dll() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && cmp -s "$src" "$dest"; then echo "up to date: ${dest#"$c"/}"; return; fi
  if [ -e "$dest" ] && [ ! -e "$dest.orig" ]; then cp -p "$dest" "$dest.orig"; fi
  cp --no-preserve=mode "$src" "$dest"
  chmod u+w "$dest"
  echo "installed:  ${dest#"$c"/}"
}

sxs="$c/windows/winsxs/amd64_microsoft.windows.common-controls_6595b64144ccf1df_6.0.2600.2982_none_deadbeef"
if [ -d "$sxs" ]; then
  install_dll "$SW_DLLS/x86_64-windows/comctl32_v6.dll" "$sxs/comctl32.dll"
else
  echo "warning: $sxs missing; wineboot has not created the common-controls assembly yet" >&2
fi
install_dll "$SW_DLLS/x86_64-windows/wininet.dll" "$sw/wininet.dll"
# Used only by the activation wizard, which sits in setup/i386.
if [ -d "$sw/setup/i386" ]; then
  install_dll "$SW_DLLS/x86_64-windows/msxml3.dll" "$sw/setup/i386/msxml3.dll"
  install_dll "$SW_DLLS/x86_64-windows/wininet.dll" "$sw/setup/i386/wininet.dll"
fi

# SOLIDWORKS validates its own XML against data/xmlschema/sw*.xsd registered under this namespace. Those files have
# no targetNamespace: Microsoft's MSXML accepts that, Wine's rejects it, and Wine's NULL error text is then passed to
# strlen() by SOLIDWORKS (sldmoasmu.dll), crashing every assembly save.
python3 - "$sw/data/xmlschema" "${1:-apply}" <<'PY'
import os, shutil, sys
d, mode = sys.argv[1:3]
ns = "http://www.solidworks.com/sw2003/schema"
old = b'<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">'
new = ('<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="%s" targetNamespace="%s" elementFormDefault="qualified">' % (ns, ns)).encode()
for n in ("sw2003schema.xsd", "sw2004schema.xsd", "sw2005plusschema.xsd"):
    p, o = os.path.join(d, n), os.path.join(d, n + ".orig")
    if not os.path.exists(p):
        print("missing:   ", n); continue
    if mode == "--revert-schemas":
        if os.path.exists(o): shutil.copy2(o, p); print("restored:  ", n)
        continue
    b = open(p, "rb").read()
    if new in b: print("up to date:", n); continue
    assert b.count(old) == 1, (n, b.count(old))
    if not os.path.exists(o): shutil.copy2(p, o)
    open(p, "wb").write(b.replace(old, new)); print("patched:   ", n)
PY

wine="$SW_WINE/bin/wine"
reg() { "$wine" reg add "$@" /f >/dev/null 2>&1 && echo "registry:   $1 $2 $3"; }
reg 'HKCU\Software\SolidWorks\SOLIDWORKS 2026\Performance' /v 'OpenGL Enable Scissor' /t REG_DWORD /d 0
reg 'HKCU\Software\Wine\Explorer' /v ShowSystray /t REG_DWORD /d 0
mkdir -p "$state/crash"
"$wine" reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' /v Debugger /t REG_SZ \
  /d "cmd /c winedbg --auto %ld %ld > Z:${state//\//\\}\\crash\\last-crash.txt 2>&1" /f >/dev/null 2>&1 \
  && echo "registry:   AeDebug -> $state/crash/last-crash.txt"
reg 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' /v Auto /t REG_SZ /d 1
reg 'HKCU\Software\Wine\WineDbg' /v ShowCrashDialog /t REG_DWORD /d 0

icon="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps/solidworks.png"
if [ ! -e "$icon" ]; then
  tmp="$(mktemp -d)"
  if wrestool -x -t14 -n 11 "$sw/SLDWORKS.exe" -o "$tmp/sw.ico" 2>/dev/null && icotool -x -o "$tmp" "$tmp/sw.ico" 2>/dev/null; then
    for big in "$tmp"/*256x256x32.png; do
      if [ -e "$big" ]; then mkdir -p "$(dirname "$icon")"; cp "$big" "$icon"; echo "icon:       $icon"; fi
      break
    done
  fi
  rm -rf "$tmp"
fi
