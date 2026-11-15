# DEBLOAT

A small, good-looking terminal app to remove the bloatware that comes preinstalled with Windows 10/11.

It scans your PC for known junk apps (Bing News, Clipchamp, Solitaire, Candy Crush, TikTok, Xbox extras, …), and you pick what to remove from an interactive list. No installs or dependencies are needed: it's a single PowerShell script.

```
  ██████╗ ███████╗██████╗ ██╗      ██████╗  █████╗ ████████╗
  ██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗██╔══██╗╚══██╔══╝
  ██║  ██║█████╗  ██████╔╝██║     ██║   ██║███████║   ██║
  ██║  ██║██╔══╝  ██╔══██╗██║     ██║   ██║██╔══██║   ██║
  ██████╔╝███████╗██████╔╝███████╗╚██████╔╝██║  ██║   ██║
  ╚═════╝ ╚══════╝╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
  ╭─ Gefundene Apps (26) ──────────────────────── 0 ausgewaehlt ─╮
  │ ▸ ○  Bing Suche                 Microsoft    • empfohlen     │
  │   ○  Clipchamp                  Microsoft    • empfohlen     │
  │   ○  Microsoft 365 (Office)     Microsoft    • empfohlen     │
  │   ○  Medienwiedergabe           Microsoft    • optional      │
  │   ○  Xbox Identity Provider     Gaming       • Vorsicht      │
  ╰──────────────────────────────────────────── 1-13 von 26 ─────╯
```

> The interface is in German.

## Features

- Full-screen terminal UI with true-color gradients, keyboard navigation and scrolling
- Shows **only the bloatware that is actually installed** on your PC
- Every app is rated:
  - 🟢 **empfohlen** (recommended): safe to remove
  - 🟡 **optional**: some people use it (e.g. Media Player, Teams, Phone Link)
  - 🔴 **Vorsicht** (careful): may break something (e.g. Xbox login for Game Pass games)
- A short description for each app
- Confirmation dialog before anything is removed
- **System-wide mode** (as admin): removes the app for all users and stops it from coming back for new accounts
- **Test mode** (`-DryRun`): try everything without deleting anything
- One key to restart as administrator

## Usage

1. Download or clone this repository
2. Double-click **`Debloat.cmd`**

Or from a terminal:

```powershell
powershell -ExecutionPolicy Bypass -File .\debloat.ps1           # normal
powershell -ExecutionPolicy Bypass -File .\debloat.ps1 -DryRun   # test mode, nothing is removed
powershell -ExecutionPolicy Bypass -File .\debloat.ps1 -ListOnly # just print what was found
```

### Keys

| Key | Action |
|---|---|
| `↑` `↓` / `j` `k` | Move |
| `Space` | Select / deselect |
| `A` | Select all recommended |
| `O` / `N` | Select all / none |
| `Enter` | Uninstall selected (asks first) |
| `S` | Toggle system-wide mode (admin only) |
| `E` | Restart as administrator |
| `R` | Rescan |
| `Q` / `Esc` | Quit |

## Notes

- Only Microsoft Store (Appx) apps are handled. Classic programs like OneDrive or Edge are not touched.
- Core system apps that Windows marks as non-removable are never listed.
- Anything you remove can be reinstalled from the Microsoft Store at any time.
- Use at your own risk, and read the 🟡 / 🔴 entries before removing them.

## Requirements

Windows 10 or 11 with Windows PowerShell 5.1, which is built in. Windows Terminal is recommended for the best look.

## License

MIT
