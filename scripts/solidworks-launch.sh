# Starts SLDWORKS.exe from an already installed SOLIDWORKS in the Wine prefix (default ~/.wine-solidworks).
#   SOLIDWORKS_PREFIX  prefix directory
#   SW_VDESKTOP=1      run inside one Wine virtual desktop (SW_DESKTOP_SIZE=WxH, default 1920x1046)
#   SW_SOFTWARE_GL=1   CPU OpenGL (llvmpipe) instead of the GPU
#
# Default: every Wine window is its own compositor-managed window. Known issue in this mode: with the macro editor
# (VBA) open, Wine hit-tests the editor over the whole maximized main window, so clicks on the 3D view are routed
# to the editor. SW_VDESKTOP=1 avoids that (one compositor window; no Alt+Tab inside).
export WINEARCH=win64
export WINEDEBUG="${WINEDEBUG:-err+all,fixme-all}"
# msxml3: <X></X> for empty elements (activation checksum). comctl32: HDM_LAYOUT NULL guard (startup crash).
# wininet: response-body fix. The patched DLLs are placed in the prefix by solidworks-setup-prefix.
export WINEDLLOVERRIDES='mshtml=;wininet=n,b;msxml3=n,b;comctl32=n,b'
export WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS='--disable-gpu-sandbox'
if [ "${SW_SOFTWARE_GL:-0}" = 1 ]; then export LIBGL_ALWAYS_SOFTWARE=1; fi

sw_dir="$WINEPREFIX/drive_c/Program Files/SOLIDWORKS Corp/SOLIDWORKS"
if [ ! -f "$sw_dir/SLDWORKS.exe" ]; then
  echo "SOLIDWORKS is not installed in $WINEPREFIX (no $sw_dir/SLDWORKS.exe)." >&2
  exit 1
fi
cd "$sw_dir" || exit 1

if [ "${SW_VDESKTOP:-0}" = 1 ]; then
  exec "$SW_WINE/bin/wine" explorer "/desktop=SOLIDWORKS,${SW_DESKTOP_SIZE:-1920x1046}" SLDWORKS.exe
fi
exec "$SW_WINE/bin/wine" SLDWORKS.exe
