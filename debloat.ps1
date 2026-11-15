<#
    DEBLOAT  -  vorinstallierte Windows-Bloatware im Terminal entfernen

    Start:     Doppelklick auf Debloat.cmd
               oder: powershell -ExecutionPolicy Bypass -File debloat.ps1

    Optionen:  -DryRun     Nur simulieren, es wird nichts deinstalliert
               -ListOnly   Gefundene Bloat-Apps nur auflisten (ohne Oberflaeche)

    Tasten:    Pfeile / j k   bewegen         Leertaste   an-/abwaehlen
               A  empfohlene waehlen          O  alle waehlen     N  keine
               S  systemweit (Admin)          R  neu scannen      E  als Admin starten
               Enter  deinstallieren          Q / Esc  beenden
#>
[CmdletBinding()]
param([switch]$DryRun, [switch]$ListOnly)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

# PowerShell 7: Appx-Modul ueber die Windows-PowerShell-Kompatibilitaet laden
if ($PSVersionTable.PSEdition -eq 'Core') {
    try { Import-Module Appx -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue } catch { }
}

# ANSI/VT-Farben in der Konsole aktivieren (auch im klassischen conhost)
if (-not ('DebloatVT' -as [type])) {
    try {
        Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DebloatVT {
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    public static void Enable() {
        IntPtr h = GetStdHandle(-11); uint m;
        if (GetConsoleMode(h, out m)) SetConsoleMode(h, m | 0x0004);
    }
}
'@
    } catch { }
}
try { [DebloatVT]::Enable() } catch { }

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# ───────────────────────────── Theme ─────────────────────────────
$E   = [char]27
$RST = "$E[0m"
$BLD = "$E[1m"
function Fg([int]$r, [int]$g, [int]$b) { "$E[38;2;$r;$g;${b}m" }
function Bg([int]$r, [int]$g, [int]$b) { "$E[48;2;$r;$g;${b}m" }

$T = @{
    Text   = Fg 225 228 240
    Mute   = Fg 120 125 155
    Dim    = Fg 75 78 105
    Border = Fg 95 85 170
    Accent = Fg 0 215 255
    Pink   = Fg 255 85 200
    Green  = Fg 80 250 160
    Yellow = Fg 255 205 90
    Red    = Fg 255 95 115
    Blue   = Fg 110 165 255
    Orange = Fg 255 155 80
    White  = Fg 255 255 255
    SelBg  = Bg 42 38 82
    ModBg  = Bg 24 22 44
}
$CatColor  = @{ 'Microsoft' = $T.Blue; 'Gaming' = $T.Green; 'Drittanbieter' = $T.Orange }
$SafeLabel = @{ 1 = 'empfohlen'; 2 = 'optional'; 3 = 'Vorsicht' }
$SafeColor = @{ 1 = $T.Green; 2 = $T.Yellow; 3 = $T.Red }

$Banner = @(
    '██████╗ ███████╗██████╗ ██╗      ██████╗  █████╗ ████████╗'
    '██╔══██╗██╔════╝██╔══██╗██║     ██╔═══██╗██╔══██╗╚══██╔══╝'
    '██║  ██║█████╗  ██████╔╝██║     ██║   ██║███████║   ██║   '
    '██║  ██║██╔══╝  ██╔══██╗██║     ██║   ██║██╔══██║   ██║   '
    '██████╔╝███████╗██████╔╝███████╗╚██████╔╝██║  ██║   ██║   '
    '╚═════╝ ╚══════╝╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   '
)

# ─────────────────────────── Katalog ────────────────────────────
# S: 1 = empfohlen (sicher weg), 2 = optional (manche nutzen es), 3 = Vorsicht
$Catalog = @(
    # Microsoft
    @{ N = 'Cortana';                P = @('Microsoft.549981C3F5F10');              C = 'Microsoft'; S = 1; D = 'Alter Sprachassistent, in Windows 11 eingestellt.' }
    @{ N = 'Copilot';                P = @('Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider'); C = 'Microsoft'; S = 1; D = 'KI-Assistent von Microsoft (laesst sich jederzeit im Store neu holen).' }
    @{ N = 'Microsoft Nachrichten';  P = @('Microsoft.BingNews');                   C = 'Microsoft'; S = 1; D = 'News-App mit Bing-Inhalten und Werbung.' }
    @{ N = 'Microsoft Wetter';       P = @('Microsoft.BingWeather');                C = 'Microsoft'; S = 1; D = 'Wetter-App (MSN).' }
    @{ N = 'Bing Suche';             P = @('Microsoft.BingSearch');                 C = 'Microsoft'; S = 1; D = 'Bing-Websuche-Integration.' }
    @{ N = 'Bing Finanzen / Sport';  P = @('Microsoft.BingFinance', 'Microsoft.BingSports'); C = 'Microsoft'; S = 1; D = 'Alte MSN-Apps aus Windows 10.' }
    @{ N = 'Hilfe anfordern';        P = @('Microsoft.GetHelp');                    C = 'Microsoft'; S = 1; D = 'Support-Chat-App von Microsoft.' }
    @{ N = 'Tipps';                  P = @('Microsoft.Getstarted');                 C = 'Microsoft'; S = 1; D = 'Windows-Tipps und Einfuehrungs-App.' }
    @{ N = 'Microsoft 365 (Office)'; P = @('Microsoft.MicrosoftOfficeHub');         C = 'Microsoft'; S = 1; D = 'Werbe-Hub fuer Office/Microsoft 365. Installiertes Office bleibt erhalten.' }
    @{ N = 'Solitaire Collection';   P = @('Microsoft.MicrosoftSolitaireCollection'); C = 'Microsoft'; S = 1; D = 'Kartenspiele mit Werbung.' }
    @{ N = 'Kontakte (People)';      P = @('Microsoft.People');                     C = 'Microsoft'; S = 1; D = 'Alte Kontakte-App.' }
    @{ N = 'Power Automate';         P = @('Microsoft.PowerAutomateDesktop');       C = 'Microsoft'; S = 1; D = 'Automatisierungs-Tool, braucht kaum jemand privat.' }
    @{ N = 'Microsoft To Do';        P = @('Microsoft.Todos');                      C = 'Microsoft'; S = 2; D = 'Aufgabenliste von Microsoft.' }
    @{ N = 'Feedback-Hub';           P = @('Microsoft.WindowsFeedbackHub');         C = 'Microsoft'; S = 1; D = 'Feedback an Microsoft senden.' }
    @{ N = 'Karten';                 P = @('Microsoft.WindowsMaps');                C = 'Microsoft'; S = 1; D = 'Offline-Karten-App.' }
    @{ N = 'Filme & TV';             P = @('Microsoft.ZuneVideo');                  C = 'Microsoft'; S = 1; D = 'Alter Video-Player / Film-Shop.' }
    @{ N = 'Medienwiedergabe';       P = @('Microsoft.ZuneMusic');                  C = 'Microsoft'; S = 2; D = 'Standard-Musik- und Videoplayer. Nur entfernen, wenn du z. B. VLC nutzt.' }
    @{ N = 'Clipchamp';              P = @('Clipchamp.Clipchamp');                  C = 'Microsoft'; S = 1; D = 'Online-Videoeditor.' }
    @{ N = 'Dev Home';               P = @('Microsoft.Windows.DevHome');            C = 'Microsoft'; S = 1; D = 'Entwickler-Dashboard (von Microsoft eingestellt).' }
    @{ N = 'Microsoft Teams';        P = @('MicrosoftTeams', 'MSTeams');            C = 'Microsoft'; S = 2; D = 'Teams (privat/neu). Behalten, wenn du es fuer Schule/Arbeit brauchst.' }
    @{ N = 'Outlook (neu)';          P = @('Microsoft.OutlookForWindows');          C = 'Microsoft'; S = 2; D = 'Neues Outlook fuer Windows.' }
    @{ N = 'Mail & Kalender';        P = @('microsoft.windowscommunicationsapps');  C = 'Microsoft'; S = 2; D = 'Alte Mail- und Kalender-App.' }
    @{ N = 'Smartphone-Link';        P = @('Microsoft.YourPhone');                  C = 'Microsoft'; S = 2; D = 'Handy mit dem PC verbinden (SMS, Fotos, Anrufe).' }
    @{ N = 'Kurznotizen';            P = @('Microsoft.MicrosoftStickyNotes');       C = 'Microsoft'; S = 2; D = 'Sticky Notes auf dem Desktop.' }
    @{ N = 'Uhr / Wecker';           P = @('Microsoft.WindowsAlarms');              C = 'Microsoft'; S = 2; D = 'Wecker, Timer, Stoppuhr, Fokus-Sitzungen.' }
    @{ N = 'Audiorekorder';          P = @('Microsoft.WindowsSoundRecorder');       C = 'Microsoft'; S = 2; D = 'Sprachaufnahme-App.' }
    @{ N = 'Remotehilfe';            P = @('MicrosoftCorporationII.QuickAssist');   C = 'Microsoft'; S = 2; D = 'Fernwartung (Quick Assist). Wird oft von Betruegern missbraucht.' }
    @{ N = 'Microsoft Family';       P = @('MicrosoftCorporationII.MicrosoftFamily'); C = 'Microsoft'; S = 1; D = 'Jugendschutz-App.' }
    @{ N = 'Microsoft Journal';      P = @('Microsoft.MicrosoftJournal');           C = 'Microsoft'; S = 1; D = 'Handschrift-Notizen fuer Stift-Geraete.' }
    @{ N = 'Whiteboard';             P = @('Microsoft.Whiteboard');                 C = 'Microsoft'; S = 1; D = 'Digitales Whiteboard.' }
    @{ N = 'OneNote (App)';          P = @('Microsoft.Office.OneNote');             C = 'Microsoft'; S = 2; D = 'Alte OneNote-Store-App.' }
    @{ N = 'Skype';                  P = @('Microsoft.SkypeApp');                   C = 'Microsoft'; S = 1; D = 'Skype wurde von Microsoft eingestellt.' }
    @{ N = 'Paint 3D / 3D-Viewer';   P = @('Microsoft.MSPaint', 'Microsoft.Microsoft3DViewer', 'Microsoft.Print3D'); C = 'Microsoft'; S = 1; D = 'Alte 3D-Apps. Das normale Paint bleibt erhalten.' }
    @{ N = 'Mixed Reality-Portal';   P = @('Microsoft.MixedReality.Portal');        C = 'Microsoft'; S = 1; D = 'Fuer Windows-Mixed-Reality-Brillen (eingestellt).' }
    @{ N = 'Alte MS-Extras';         P = @('Microsoft.Wallet', 'Microsoft.Messaging', 'Microsoft.OneConnect'); C = 'Microsoft'; S = 1; D = 'Wallet, Messaging, Mobile Plans - aus Windows 10 uebrig.' }
    # Gaming
    @{ N = 'Xbox App';               P = @('Microsoft.GamingApp', 'Microsoft.XboxApp'); C = 'Gaming'; S = 2; D = 'Xbox / Game Pass. Behalten, wenn du Game Pass auf dem PC nutzt.' }
    @{ N = 'Xbox Game Bar';          P = @('Microsoft.XboxGamingOverlay', 'Microsoft.XboxGameOverlay'); C = 'Gaming'; S = 2; D = 'Win+G Overlay, Aufnahmen, FPS-Anzeige.' }
    @{ N = 'Xbox Sprache-zu-Text';   P = @('Microsoft.XboxSpeechToTextOverlay');    C = 'Gaming'; S = 1; D = 'Sprach-Overlay fuer Xbox-Party-Chat.' }
    @{ N = 'Xbox TCUI';              P = @('Microsoft.Xbox.TCUI');                  C = 'Gaming'; S = 3; D = 'Wird von manchen Spielen fuer Xbox-Freunde/Einladungen gebraucht.' }
    @{ N = 'Xbox Identity Provider'; P = @('Microsoft.XboxIdentityProvider');       C = 'Gaming'; S = 3; D = 'Xbox-Login. Ohne das starten Game-Pass- und Store-Spiele evtl. nicht!' }
    # Drittanbieter
    @{ N = 'Candy Crush & King';     P = @('king.com.*', '*CandyCrush*', '*BubbleWitch*'); C = 'Drittanbieter'; S = 1; D = 'Vorinstallierte Werbe-Spiele.' }
    @{ N = 'Spotify';                P = @('SpotifyAB.SpotifyMusic');               C = 'Drittanbieter'; S = 2; D = 'Musik-Streaming.' }
    @{ N = 'Disney+';                P = @('Disney.37853FC22B2CE');                 C = 'Drittanbieter'; S = 1; D = 'Streaming-Werbeverknuepfung.' }
    @{ N = 'Prime Video';            P = @('AmazonVideo.PrimeVideo');               C = 'Drittanbieter'; S = 1; D = 'Streaming-Werbeverknuepfung.' }
    @{ N = 'Netflix';                P = @('*Netflix*');                            C = 'Drittanbieter'; S = 1; D = 'Streaming-Werbeverknuepfung.' }
    @{ N = 'TikTok';                 P = @('*TikTok*');                             C = 'Drittanbieter'; S = 1; D = 'Vorinstallierte Social-Media-Verknuepfung.' }
    @{ N = 'Facebook / Instagram';   P = @('Facebook.*', '*Instagram*');            C = 'Drittanbieter'; S = 1; D = 'Vorinstallierte Social-Media-Apps.' }
    @{ N = 'LinkedIn';               P = @('*LinkedIn*');                           C = 'Drittanbieter'; S = 1; D = 'Vorinstallierte Social-Media-App.' }
    @{ N = 'Twitter / X';            P = @('*Twitter*');                            C = 'Drittanbieter'; S = 1; D = 'Vorinstallierte Social-Media-App.' }
    @{ N = 'WhatsApp';               P = @('5319275A.WhatsAppDesktop');             C = 'Drittanbieter'; S = 2; D = 'Messenger. Behalten, wenn du ihn nutzt.' }
    @{ N = 'McAfee';                 P = @('*McAfee*');                             C = 'Drittanbieter'; S = 1; D = 'Testversion-Werbung. Windows Defender schuetzt bereits.' }
    @{ N = 'Weitere Werbe-Apps';     P = @('*Duolingo*', '*PandoraMedia*', '*Flipboard*', '*Shazam*', '*HiddenCity*', '*MarchofEmpires*', '*Royal*Revolt*', '*Asphalt*', '*Hulu*', '*PhototasticCollage*', '*PicsArt*', '*AdobePhotoshopExpress*', '*EclipseManager*', '*ActiproSoftware*'); C = 'Drittanbieter'; S = 1; D = 'Diverse vorinstallierte Werbe-Apps und Spiele.' }
)

# ─────────────────────────── Helfer ─────────────────────────────
function Fit([string]$s, [int]$n) {
    if ($n -le 0) { return '' }
    if ($s.Length -gt $n) {
        if ($n -le 1) { return $s.Substring(0, $n) }
        return $s.Substring(0, $n - 1) + '…'
    }
    return $s.PadRight($n)
}

function Rep([string]$c, [int]$n) { if ($n -le 0) { return '' } ; return $c * $n }

function Grad([string]$s, [int[]]$a, [int[]]$b) {
    $n  = [Math]::Max(1, $s.Length - 1)
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $s.Length; $i++) {
        $ch = $s[$i]
        if ($ch -ne ' ') {
            $t = $i / $n
            $r = [int]($a[0] + ($b[0] - $a[0]) * $t)
            $g = [int]($a[1] + ($b[1] - $a[1]) * $t)
            $bl = [int]($a[2] + ($b[2] - $a[2]) * $t)
            [void]$sb.Append("$E[38;2;$r;$g;${bl}m")
        }
        [void]$sb.Append($ch)
    }
    return $sb.ToString() + $RST
}

function Get-Bloat {
    $installed = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
        -not $_.IsFramework -and $_.NonRemovable -ne $true -and "$($_.SignatureKind)" -ne 'System'
    })
    $claimed = @{}
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($c in $Catalog) {
        $hits = @()
        foreach ($p in $c.P) {
            $hits += @($installed | Where-Object { $_.Name -like $p -and -not $claimed.ContainsKey($_.PackageFullName) })
        }
        if ($hits.Count -eq 0) { continue }
        foreach ($h in $hits) { $claimed[$h.PackageFullName] = $true }
        $out.Add([pscustomobject]@{
            Name     = $c.N
            Cat      = $c.C
            Safety   = [int]$c.S
            Desc     = $c.D
            Patterns = $c.P
            Full     = @($hits | ForEach-Object { $_.PackageFullName } | Select-Object -Unique)
            Ids      = @($hits | ForEach-Object { $_.Name } | Select-Object -Unique)
            Selected = $false
        })
    }
    $order = @{ 'Microsoft' = 0; 'Gaming' = 1; 'Drittanbieter' = 2 }
    return , @($out | Sort-Object @{ Expression = { $order[$_.Cat] } }, Safety, Name)
}

# ─────────────────────────── Zeichnen ───────────────────────────
function Row($it, [bool]$isCur, [int]$iw) {
    $bg    = ''; if ($isCur) { $bg = $T.SelBg }
    $ptr   = '  '; if ($isCur) { $ptr = '▸ ' }
    $box   = '○'; $boxC = $T.Dim
    if ($it.Selected) { $box = '●'; $boxC = $T.Pink }
    $nameC = $T.Text; if ($isCur -or $it.Selected) { $nameC = $T.White + $BLD }
    $nameW = [Math]::Max(8, $iw - 33)
    return $T.Border + '│' + $bg + ' ' + $T.Accent + $ptr + $boxC + $box + '  ' +
        $nameC + (Fit $it.Name $nameW) + $RST + $bg + ' ' +
        $CatColor[$it.Cat] + (Fit $it.Cat 13) +
        $SafeColor[$it.Safety] + (Fit ('• ' + $SafeLabel[$it.Safety]) 12) + ' ' +
        $RST + $T.Border + '│'
}

function KeyHints($pairs) {
    $s = ''
    foreach ($p in $pairs) { $s += $T.Accent + $BLD + $p[0] + $RST + ' ' + $T.Mute + $p[1] + '   ' }
    return $s
}

function Render {
    $w = [Console]::WindowWidth; $h = [Console]::WindowHeight
    if ($w -ne $script:LastW -or $h -ne $script:LastH) {
        [Console]::Write("$E[2J"); $script:LastW = $w; $script:LastH = $h
    }
    $items = $script:Items
    $L = New-Object System.Collections.Generic.List[string]
    $pad = '  '

    # Kopf
    if ($h -ge 30 -and $w -ge 66) {
        $L.Add('')
        foreach ($b in $Banner) { $L.Add($pad + (Grad $b @(0, 215, 255) @(255, 85, 200))) }
    } else {
        $L.Add('')
        $L.Add($pad + $BLD + (Grad 'D E B L O A T' @(0, 215, 255) @(255, 85, 200)))
    }
    $selCount = @($items | Where-Object { $_.Selected }).Count
    $chips = $pad + $T.Mute + 'Windows-Bloatware entfernen  ' + $T.Dim + '│  '
    if ($IsAdmin) { $chips += $T.Green + '● Admin' } else { $chips += $T.Yellow + '● Kein Admin' }
    $chips += $T.Dim + '  │  '
    if ($script:SystemWide) { $chips += $T.Pink + '● Systemweit' } else { $chips += $T.Mute + '○ Nur dein Benutzer' }
    if ($DryRun) { $chips += $T.Dim + '  │  ' + $T.Yellow + $BLD + 'TESTMODUS' }
    $L.Add($chips)
    $L.Add('')

    # Liste
    $iw    = [Math]::Max(40, $w - 6)
    $title = 'Gefundene Apps (' + $items.Count + ')'
    $selT  = ' ' + $selCount + ' ausgewaehlt '
    $L.Add($pad + $T.Border + '╭─ ' + $T.Accent + $BLD + $title + $RST + ' ' + $T.Border +
        (Rep '─' ($iw - 5 - $title.Length - $selT.Length)) + $T.Pink + $selT + $T.Border + '─╮')

    $footer = 7
    $listH  = [Math]::Max(3, $h - $L.Count - $footer)
    if ($items.Count -gt 0) {
        if ($script:Cur -ge $items.Count) { $script:Cur = $items.Count - 1 }
        if ($script:Cur -lt 0) { $script:Cur = 0 }
    }
    if ($script:Cur -lt $script:Top) { $script:Top = $script:Cur }
    if ($script:Cur -ge $script:Top + $listH) { $script:Top = $script:Cur - $listH + 1 }
    if ($script:Top -gt [Math]::Max(0, $items.Count - $listH)) { $script:Top = [Math]::Max(0, $items.Count - $listH) }

    for ($r = 0; $r -lt $listH; $r++) {
        $i = $script:Top + $r
        if ($items.Count -eq 0 -and $r -eq 1) {
            $msg = '  ✨ Keine bekannte Bloatware gefunden - dein System ist sauber!'
            $L.Add($pad + $T.Border + '│' + $T.Green + (Fit $msg $iw) + $T.Border + '│')
        } elseif ($i -lt $items.Count) {
            $L.Add($pad + (Row $items[$i] ($i -eq $script:Cur) $iw))
        } else {
            $L.Add($pad + $T.Border + '│' + (Rep ' ' $iw) + '│')
        }
    }
    $info = ''
    if ($items.Count -gt $listH) {
        $info = ' ' + ($script:Top + 1) + '-' + [Math]::Min($items.Count, $script:Top + $listH) + ' von ' + $items.Count + ' '
    }
    $L.Add($pad + $T.Border + '╰' + (Rep '─' ($iw - $info.Length - 1)) + $T.Mute + $info + $T.Border + '─╯')

    # Fuss
    if ($items.Count -gt 0) {
        $it = $items[$script:Cur]
        $dc = $T.Text; if ($it.Safety -eq 3) { $dc = $T.Red }
        $L.Add($pad + ' ' + $SafeColor[$it.Safety] + '▍ ' + $dc + (Fit $it.Desc ($w - 6)))
        $L.Add($pad + ' ' + $T.Dim + '  ' + (Fit ('Paket: ' + ($it.Ids -join ', ')) ($w - 7)))
    } else { $L.Add(''); $L.Add('') }
    $L.Add('')
    $L.Add($pad + (KeyHints @(@('↑↓', 'Bewegen'), @('Leertaste', 'Auswaehlen'), @('A', 'Empfohlene'), @('O', 'Alle'), @('N', 'Keine'))))
    $k2 = @(@('Enter', 'Deinstallieren'), @('R', 'Neu scannen'))
    if ($IsAdmin) { $k2 += , @('S', 'Systemweit an/aus') } else { $k2 += , @('E', 'Als Admin starten') }
    $k2 += , @('Q', 'Beenden')
    $L.Add($pad + (KeyHints $k2))
    $L.Add($pad + $script:Msg)

    while ($L.Count -gt $h) { $L.RemoveAt($L.Count - 1) }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("$E[H")
    for ($i = 0; $i -lt $L.Count; $i++) {
        [void]$sb.Append($L[$i]).Append($RST).Append("$E[K")
        if ($i -lt $L.Count - 1) { [void]$sb.Append("`n") }
    }
    [void]$sb.Append("$E[J")
    [Console]::Write($sb.ToString())
}

# body: Liste von @(farbe, text)
function Show-Modal([string]$title, $body, [string]$accent) {
    $w  = [Console]::WindowWidth; $h = [Console]::WindowHeight
    $mw = [Math]::Min(66, $w - 4); $iw = $mw - 2
    $mh = $body.Count + 2
    $x  = [Math]::Max(1, [int][Math]::Floor(($w - $mw) / 2) + 1)
    $y  = [Math]::Max(1, [int][Math]::Floor(($h - $mh) / 2) + 1)
    $bg = $T.ModBg
    $tl = ' ' + $title + ' '
    $s  = "$E[$y;${x}H" + $bg + $accent + '╭─' + $BLD + $tl + $RST + $bg + $accent + (Rep '─' ($iw - 1 - $tl.Length)) + '╮' + $RST
    $row = $y
    foreach ($ln in $body) {
        $row++
        $s += "$E[$row;${x}H" + $bg + $accent + '│' + $ln[0] + ' ' + (Fit $ln[1] ($iw - 2)) + ' ' + $accent + '│' + $RST
    }
    $row++
    $s += "$E[$row;${x}H" + $bg + $accent + '╰' + (Rep '─' $iw) + '╯' + $RST
    [Console]::Write($s)
}

function Confirm-Removal($sel) {
    $body = New-Object System.Collections.Generic.List[object]
    $body.Add(@('', ''))
    $body.Add(@($T.White + $BLD, "$($sel.Count) App(s) werden deinstalliert:"))
    $max = 8
    for ($i = 0; $i -lt [Math]::Min($max, $sel.Count); $i++) {
        $body.Add(@($SafeColor[$sel[$i].Safety], '  • ' + $sel[$i].Name))
    }
    if ($sel.Count -gt $max) { $body.Add(@($T.Mute, "  … und $($sel.Count - $max) weitere")) }
    $body.Add(@('', ''))
    if ($script:SystemWide) { $body.Add(@($T.Pink, 'Modus: systemweit (alle Benutzer + neue Konten)')) }
    else { $body.Add(@($T.Mute, 'Modus: nur fuer deinen Benutzer')) }
    if (@($sel | Where-Object { $_.Safety -eq 3 }).Count -gt 0) {
        $body.Add(@($T.Red, '⚠ Enthaelt Apps mit Vorsicht-Markierung!'))
    }
    if ($DryRun) { $body.Add(@($T.Yellow, 'Testmodus: es wird nichts wirklich geloescht.')) }
    $body.Add(@('', ''))
    $body.Add(@($T.Accent + $BLD, '[J] Ja, entfernen        [N] Abbrechen'))
    $body.Add(@('', ''))
    Show-Modal 'Deinstallation bestaetigen' $body $T.Pink
    while ($true) {
        $k = [Console]::ReadKey($true)
        $c = [char]::ToLowerInvariant($k.KeyChar)
        if ($c -eq 'j' -or $c -eq 'y') { return $true }
        if ($c -eq 'n' -or $k.Key -eq 'Escape' -or $c -eq 'q') { return $false }
    }
}

function Bar([int]$done, [int]$total, [int]$width) {
    $f = 0; if ($total -gt 0) { $f = [int][Math]::Round($width * $done / $total) }
    $fill = Rep '█' $f
    $s = ''
    if ($f -gt 0) { $s = (Grad $fill @(0, 215, 255) @(255, 85, 200)) }
    return $s + $T.Dim + (Rep '░' ($width - $f)) + $RST + ' ' + $T.Text + "$done/$total" + $RST
}

function Invoke-Removal($sel) {
    [Console]::Write("$E[2J$E[H")
    $w = [Console]::WindowWidth
    [Console]::WriteLine('')
    [Console]::WriteLine('  ' + $BLD + (Grad 'D E B L O A T' @(0, 215, 255) @(255, 85, 200)) + $T.Mute + '   ·   Deinstallation laeuft …' + $RST)
    [Console]::WriteLine('')

    $prov = @()
    if ($script:SystemWide -and $IsAdmin -and -not $DryRun) {
        [Console]::Write('  ' + $T.Mute + 'Lese bereitgestellte Pakete …' + $RST)
        $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
        [Console]::Write("`r$E[K")
    }

    $ok = 0; $fail = 0; $n = 0
    $errs = New-Object System.Collections.Generic.List[string]
    $nameW = [Math]::Max(10, [Math]::Min(32, $w - 30))
    foreach ($it in $sel) {
        $n++
        [Console]::Write("`r$E[K  " + $T.Yellow + '◌ ' + $T.Text + (Fit $it.Name $nameW) + $T.Mute + ' wird entfernt …' + $RST)
        $err = $null
        try {
            if ($DryRun) {
                Start-Sleep -Milliseconds 350
            } else {
                foreach ($f in $it.Full) {
                    if ($script:SystemWide -and $IsAdmin) { Remove-AppxPackage -Package $f -AllUsers -ErrorAction Stop }
                    else { Remove-AppxPackage -Package $f -ErrorAction Stop }
                }
                if ($script:SystemWide -and $IsAdmin) {
                    foreach ($pp in $prov) {
                        foreach ($p in $it.Patterns) {
                            if ($pp.DisplayName -like $p) {
                                Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction SilentlyContinue | Out-Null
                            }
                        }
                    }
                }
            }
        } catch { $err = $_.Exception.Message }

        if ($err) {
            $fail++
            $errs.Add($it.Name + ': ' + ($err -replace '\s+', ' '))
            [Console]::Write("`r$E[K  " + $T.Red + '✖ ' + $T.Text + (Fit $it.Name $nameW) + $T.Red + ' fehlgeschlagen' + $RST + "`n")
        } else {
            $ok++
            [Console]::Write("`r$E[K  " + $T.Green + '✔ ' + $T.Text + (Fit $it.Name $nameW) + $T.Green + ' entfernt' + $RST + "`n")
        }
        [Console]::Write('  ' + (Bar $n $sel.Count ([Math]::Min(40, $w - 14))))
    }
    [Console]::Write("`n`n")
    $sum = '  ' + $T.Green + $BLD + "$ok entfernt" + $RST
    if ($fail -gt 0) { $sum += $T.Mute + '  ·  ' + $T.Red + $BLD + "$fail fehlgeschlagen" + $RST }
    if ($DryRun) { $sum += $T.Mute + '  ·  ' + $T.Yellow + 'Testmodus (nichts geloescht)' + $RST }
    [Console]::WriteLine($sum)
    foreach ($e in $errs) { [Console]::WriteLine('  ' + $T.Red + '  ' + (Fit $e ($w - 6)).TrimEnd() + $RST) }
    if ($fail -gt 0 -and -not $IsAdmin) {
        [Console]::WriteLine('  ' + $T.Yellow + 'Tipp: Mit E als Admin neu starten und es erneut versuchen.' + $RST)
    }
    [Console]::WriteLine('')
    [Console]::WriteLine('  ' + $T.Mute + 'Entfernte Apps lassen sich jederzeit ueber den Microsoft Store neu installieren.' + $RST)
    [Console]::WriteLine('  ' + $T.Accent + $BLD + 'Beliebige Taste' + $RST + $T.Mute + ' zum Zurueckkehren …' + $RST)
    [void][Console]::ReadKey($true)
    [Console]::Write("$E[2J")
    return @($ok, $fail)
}

function Restart-AsAdmin {
    $exe = (Get-Process -Id $PID).Path
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($DryRun) { $a += ' -DryRun' }
    try {
        Start-Process -FilePath $exe -Verb RunAs -ArgumentList $a -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Scan {
    [Console]::Write("$E[2J$E[H`n  " + $BLD + (Grad 'D E B L O A T' @(0, 215, 255) @(255, 85, 200)) + $T.Mute + '   ·   Scanne installierte Apps …' + $RST)
    $script:Items = Get-Bloat
    [Console]::Write("$E[2J")
}

# ──────────────────────────── Start ─────────────────────────────
if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
    Write-Host 'Get-AppxPackage ist nicht verfuegbar. Bitte mit Windows PowerShell (powershell.exe) starten.' -ForegroundColor Red
    exit 1
}

if ($ListOnly) {
    $items = Get-Bloat
    [Console]::WriteLine('')
    [Console]::WriteLine('  ' + $BLD + (Grad 'D E B L O A T' @(0, 215, 255) @(255, 85, 200)) + $T.Mute + "   ·   $($items.Count) Bloat-Apps gefunden" + $RST)
    [Console]::WriteLine('')
    foreach ($it in $items) {
        [Console]::WriteLine('  ' + $T.Text + (Fit $it.Name 26) + ' ' + $CatColor[$it.Cat] + (Fit $it.Cat 14) +
            $SafeColor[$it.Safety] + (Fit ('• ' + $SafeLabel[$it.Safety]) 12) + $T.Dim + ($it.Ids -join ', ') + $RST)
    }
    [Console]::WriteLine('')
    return
}

if ([Console]::IsInputRedirected) {
    Write-Host 'Bitte in einem echten Terminal starten (oder -ListOnly verwenden).' -ForegroundColor Yellow
    exit 1
}

$script:Items = @(); $script:Cur = 0; $script:Top = 0
$script:SystemWide = $false; $script:Msg = ''
$script:LastW = 0; $script:LastH = 0
$oldCtrlC = [Console]::TreatControlCAsInput
$oldTitle = $Host.UI.RawUI.WindowTitle

try {
    [Console]::TreatControlCAsInput = $true
    $Host.UI.RawUI.WindowTitle = 'DEBLOAT'
    [Console]::Write("$E[?1049h$E[?25l")
    Scan

    while ($true) {
        Render
        $k = [Console]::ReadKey($true)
        $key = "$($k.Key)"
        $c = [char]::ToLowerInvariant($k.KeyChar)
        $items = $script:Items
        $script:Msg = ''

        if (($k.Modifiers -band [ConsoleModifiers]::Control) -and $key -eq 'C') { break }
        elseif ($key -eq 'UpArrow' -or $c -eq 'k') { if ($script:Cur -gt 0) { $script:Cur-- } }
        elseif ($key -eq 'DownArrow' -or $c -eq 'j') { if ($script:Cur -lt $items.Count - 1) { $script:Cur++ } }
        elseif ($key -eq 'PageUp') { $script:Cur = [Math]::Max(0, $script:Cur - 10) }
        elseif ($key -eq 'PageDown') { $script:Cur = [Math]::Max(0, [Math]::Min($items.Count - 1, $script:Cur + 10)) }
        elseif ($key -eq 'Home') { $script:Cur = 0 }
        elseif ($key -eq 'End') { $script:Cur = [Math]::Max(0, $items.Count - 1) }
        elseif ($key -eq 'Spacebar') {
            if ($items.Count -gt 0) {
                $items[$script:Cur].Selected = -not $items[$script:Cur].Selected
                if ($script:Cur -lt $items.Count - 1) { $script:Cur++ }
            }
        }
        elseif ($c -eq 'a') {
            foreach ($it in $items) { $it.Selected = ($it.Safety -eq 1) }
            $script:Msg = $T.Green + '✔ Alle empfohlenen Apps ausgewaehlt'
        }
        elseif ($c -eq 'o') {
            foreach ($it in $items) { $it.Selected = $true }
            $script:Msg = $T.Yellow + '● Alles ausgewaehlt - pruefe gelbe und rote Eintraege!'
        }
        elseif ($c -eq 'n') { foreach ($it in $items) { $it.Selected = $false } }
        elseif ($c -eq 'r') { Scan; $script:Msg = $T.Accent + '↻ Neu gescannt' }
        elseif ($c -eq 's') {
            if ($IsAdmin) { $script:SystemWide = -not $script:SystemWide }
            else { $script:Msg = $T.Yellow + 'Systemweit geht nur als Admin - druecke E.' }
        }
        elseif ($c -eq 'e' -and -not $IsAdmin) {
            if (Restart-AsAdmin) { break }
            $script:Msg = $T.Red + 'Admin-Start abgebrochen.'
        }
        elseif ($key -eq 'Enter') {
            $sel = @($items | Where-Object { $_.Selected })
            if ($sel.Count -eq 0) {
                $script:Msg = $T.Yellow + 'Nichts ausgewaehlt - Leertaste zum Auswaehlen, A fuer Empfohlene.'
            } elseif (Confirm-Removal $sel) {
                $res = Invoke-Removal $sel
                Scan
                $script:Msg = $T.Green + "✔ $($res[0]) entfernt" + $(if ($res[1] -gt 0) { $T.Red + "   ✖ $($res[1]) fehlgeschlagen" } else { '' })
            } else {
                $script:LastW = 0
            }
        }
        elseif ($key -eq 'Escape' -or $c -eq 'q') { break }
    }
}
finally {
    [Console]::Write("$E[0m$E[?25h$E[?1049l")
    [Console]::TreatControlCAsInput = $oldCtrlC
    try { $Host.UI.RawUI.WindowTitle = $oldTitle } catch { }
}
