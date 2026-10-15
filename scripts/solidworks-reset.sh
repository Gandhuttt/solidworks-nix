# Explicit recovery: stops EVERYTHING running in the SOLIDWORKS Wine prefix (wineserver -k). Unsaved work is lost.
# Refuses while SLDWORKS.exe is running.
if sw_running; then
  echo "SLDWORKS.exe is running. Close it normally first; refusing to kill it (unsaved work)." >&2
  notify-send "SOLIDWORKS" "Still running: close it normally first." 2>/dev/null || true
  exit 1
fi
"$SW_WINE/bin/wineserver" -k 2>/dev/null || true
"$SW_WINE/bin/wineserver" -w 2>/dev/null || true
notify-send "SOLIDWORKS" "Wine session reset." 2>/dev/null || true
echo "Wine session for $WINEPREFIX reset."
