# Shared by every command (prepended by flake.nix).
: "${SOLIDWORKS_PREFIX:=$HOME/.wine-solidworks}"
export SOLIDWORKS_PREFIX
export WINEPREFIX="$SOLIDWORKS_PREFIX"

# sw_running: true when an SLDWORKS.exe that belongs to $WINEPREFIX is running (so another prefix, or a test
# prefix, is not mistaken for this one). Reads WINEPREFIX from the process environment, which the launcher exports.
sw_running() {
  local pid
  for pid in $(pgrep -x SLDWORKS.exe || true); do
    if tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -qxF "WINEPREFIX=$WINEPREFIX"; then
      return 0
    fi
  done
  return 1
}

# sw_count: number of SLDWORKS.exe processes on the machine (pgrep exits 1 on no match; keep pipefail quiet).
sw_count() { { pgrep -x SLDWORKS.exe || true; } | wc -l; }

