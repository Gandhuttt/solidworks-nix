# Desktop-entry entry point. Non-destructive: never kills anything.
#  - SOLIDWORKS already running, or another start in progress -> do nothing (--new-session skips the running check).
#  - Leftover SOLIDWORKS helper processes without SLDWORKS.exe (a dead earlier session) make the new instance hang
#    with no window; we only warn and point at solidworks-reset.
state="${XDG_STATE_HOME:-$HOME/.local/state}/solidworks-wine"
mkdir -p "$state"

say() { notify-send "SOLIDWORKS" "$1" 2>/dev/null || true; echo "$1" >&2; }

exec 9>"$state/start.lock"
flock -n 9 || { say "A start is already in progress."; exit 0; }

new=0
[ "${1:-}" = "--new-session" ] && new=1

if [ "$new" = 0 ] && sw_running; then
  say "SOLIDWORKS is already running. Use --new-session for a second, separate session."
  exit 0
fi
if [ "$new" = 0 ] && ! sw_running && pgrep -f 'sldProcMon.exe|sldexitapp.exe' >/dev/null; then
  say "Leftover SOLIDWORKS processes from an earlier session were found; starting anyway. If no window appears, run solidworks-reset."
fi

# Keep the previous session's launch log so a crash can still be investigated after a relaunch.
[ -f "$state/last-launch.log" ] && mv -f "$state/last-launch.log" "$state/previous-launch.log"
before=$(sw_count)
# Detached child (setsid -f) with fd 9 closed: this script ends after the startup phase and releases the lock, so a
# later launch is not blocked while SOLIDWORKS stays open. Duplicate starts are then stopped by sw_running instead.
setsid -f solidworks-launch >"$state/last-launch.log" 2>&1 9>&-
for _ in $(seq 1 120); do
  [ "$(sw_count)" -gt "$before" ] && break
  sleep 0.5
done
sleep 20
