#include <windows.h>
#include <stdio.h>
static int restore;
static BOOL CALLBACK cb(HWND h, LPARAM l) {
    WCHAR t[128] = L"", c[64] = L"";
    GetWindowTextW(h, t, 128); GetClassNameW(h, c, 64);
    BOOL vis = IsWindowVisible(h), icon = IsIconic(h), zoom = IsZoomed(h);
    if (!t[0] && !icon) return TRUE;
    RECT r; GetWindowRect(h, &r);
    printf("hwnd=%p vis=%d iconic=%d zoomed=%d rect=(%ld,%ld)-(%ld,%ld) class=%.28ls title=%.50ls\n", h, vis, icon, zoom, r.left, r.top, r.right, r.bottom, c, t);
    if (restore && icon && (wcsstr(t, L"SOLIDWORKS") || wcsstr(t, L"Visual Basic"))) {
        ShowWindow(h, SW_RESTORE);
        printf("   -> SW_RESTORE sent; iconic now=%d\n", IsIconic(h));
    }
    return TRUE;
}
int main(int argc, char **argv) {
    restore = argc > 1 && !strcmp(argv[1], "restore");
    HDESK d = OpenDesktopA("SOLIDWORKS", 0, FALSE, GENERIC_ALL);
    if (!d) { printf("OpenDesktop(SOLIDWORKS) failed %lu\n", GetLastError()); return 1; }
    printf("desktop opened; enumerating top-level windows\n");
    EnumDesktopWindows(d, cb, 0);
    return 0;
}
