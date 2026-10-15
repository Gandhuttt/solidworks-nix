# Restores minimized SOLIDWORKS / VBA windows inside the "SOLIDWORKS" Wine virtual desktop (SW_VDESKTOP=1); they park
# as a small icon at the desktop's bottom-left. Argument "list" only lists top-level windows. Useless outside the
# virtual desktop.
export WINEDEBUG=-all
"$SW_WINE/bin/wine" "$SW_VDRESTORE" "${1:-restore}" 2>&1 | grep -v libodbc || true
