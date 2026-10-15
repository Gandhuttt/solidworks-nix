# Copies the PART you currently have selected in SOLIDWORKS out as a standalone .SLDPRT file.
#
#   solidworks-extract-part [NAME]
#
# Select a part (or a face / body of it) in the assembly, then run this. NAME is the new file name (".SLDPRT" is added
# if missing); the default is the part's own cache name. The file is written next to the open document and is never
# overwritten. Why it works: SOLIDWORKS keeps the internal components of an imported STEP assembly as ordinary files
# in a temp cache (...\Temp\swx*\IC~~\), and a part file is self-contained. A selected sub-assembly is refused: its
# file references other cached files, so a single copy would not stand alone.
#
# It only reads the selection (no document is opened, saved or changed) and attaches to a SOLIDWORKS that is already
# running: attaching to a stopped one would make Wine start it without the launcher's DLL overrides and crash.
name_arg="${1:-}"

if ! sw_running; then
  echo "SOLIDWORKS is not running in $WINEPREFIX. Start it with: solidworks" >&2
  exit 1
fi

vbs="$(mktemp --suffix=.vbs)"
trap 'rm -f "$vbs"' EXIT
cat >"$vbs" <<'VBS'
Option Explicit
Dim swApp, doc, sm, c, md
On Error Resume Next
Set swApp = CreateObject("SldWorks.Application")
If swApp Is Nothing Then WScript.Echo "ERROR=cannot attach to SOLIDWORKS": WScript.Quit 2
Set doc = swApp.ActiveDoc
If doc Is Nothing Then WScript.Echo "ERROR=no document is open": WScript.Quit 3
Set sm = doc.SelectionManager
If sm.GetSelectedObjectCount2(-1) < 1 Then WScript.Echo "ERROR=nothing is selected": WScript.Quit 4
Set c = Nothing
Set c = sm.GetSelectedObjectsComponent4(1, -1)
If c Is Nothing Then WScript.Echo "ERROR=the selection does not belong to a component": WScript.Quit 5
Err.Clear
Set md = Nothing
Set md = c.GetModelDoc2
If md Is Nothing Then WScript.Echo "ERROR=the component's document is not loaded": WScript.Quit 6
WScript.Echo "COMPONENT=" & c.Name2
WScript.Echo "KIND=" & md.GetType
WScript.Echo "FILE=" & md.GetPathName
WScript.Echo "ACTIVE=" & doc.GetPathName
VBS

# Same overrides as solidworks-launch, so attaching behaves like the running session.
out="$(WINEDEBUG=-all WINEDLLOVERRIDES='mshtml=;wininet=n,b;msxml3=n,b;comctl32=n,b' \
  timeout 120 "$SW_WINE/bin/wine" cscript //nologo "Z:${vbs//\//\\}" 2>&1 | tr -d '\r' | grep -E '^(ERROR|COMPONENT|KIND|FILE|ACTIVE)=' || true)"

field() { printf '%s\n' "$out" | sed -n "s/^$1=//p" | head -n1; }

if [ -z "$out" ]; then
  echo "Could not read the selection from SOLIDWORKS (no answer)." >&2
  exit 1
fi
if err="$(field ERROR)" && [ -n "$err" ]; then
  echo "Cannot extract: $err." >&2
  exit 1
fi

component="$(field COMPONENT)"
kind="$(field KIND)"
winfile="$(field FILE)"
winactive="$(field ACTIVE)"

if [ "$kind" != 1 ]; then
  echo "'$component' is a sub-assembly, not a part. Expand it and select the part inside (or click a face of it)," >&2
  echo "then run this again." >&2
  exit 1
fi

# Windows path -> Linux path inside this prefix.
towin() {
  local p="$1" rest
  case "$p" in
    [Cc]:\\*) rest="${p:3}"; printf '%s/drive_c/%s\n' "$WINEPREFIX" "${rest//\\//}" ;;
    [Zz]:\\*) rest="${p:3}"; printf '/%s\n' "${rest//\\//}" ;;
    *) return 1 ;;
  esac
}

if ! src="$(towin "$winfile")" || [ ! -f "$src" ]; then
  echo "The part's file is not where I can read it: $winfile" >&2
  exit 1
fi

if destdir="$(towin "$winactive" 2>/dev/null)"; then
  destdir="$(dirname "$destdir")"
else
  destdir="$PWD"
fi

if [ -n "$name_arg" ]; then
  base="${name_arg%.[Ss][Ll][Dd][Pp][Rr][Tt]}.SLDPRT"
else
  base="$(basename "$src")"
  base="${base%.step.SLDPRT}.SLDPRT"
fi
dest="$destdir/$base"

if [ -e "$dest" ]; then
  echo "Refusing to overwrite $dest" >&2
  exit 1
fi
cp -n "$src" "$dest"
cmp -s "$src" "$dest" || { echo "Copy does not match the source; removing it." >&2; rm -f "$dest"; exit 1; }
echo "Extracted '$component'"
echo "  from: $winfile"
echo "  to:   $dest ($(stat -c %s "$dest") bytes)"
