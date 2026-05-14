# Edge-pulse overlay: thin colored band pulses along the top of the
# primary monitor for ~2s, then closes itself.
#
# Usage: edge-pulse.ps1 -Color <wpf-color-name-or-hex>
# Examples: -Color Gold, -Color DodgerBlue, -Color "#FF3399"
#
# Why this exists: FlashWindowEx (the normal "blink taskbar" Win32 API)
# is unreliable on Windows 11 + Electron-based windows (VSCode, Windows
# Terminal). We render our own WPF window so we control the visual
# 100%. It's click-through (WS_EX_TRANSPARENT) so it never steals
# focus or blocks input.

param(
    [Parameter()][string]$Color = 'Gold',
    [Parameter()][int]$Thickness = 20,
    # 0 = pulse forever until VSCode gets focus (capped at MaxDurationMs).
    # >0 = fixed total duration regardless of focus.
    [Parameter()][int]$DurationMs = 0,
    # Hard cap so we never pulse forever if user is away from desk.
    [Parameter()][int]$MaxDurationMs = 60000,
    # Process PID to walk up from to locate our VSCode window (so we know
    # when to stop). Optional — falls back to any Code.exe with window.
    [Parameter()][int]$SeedPid = 0,
    # Enable Gold → Orange → Red escalation as elapsed time grows.
    # Each stage swap speaks an escalation TTS phrase.
    [Parameter()][switch]$Escalate,
    [Parameter()][string]$EscalateText = 'Claude still needs you'
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Find the VSCode window we'll stop pulsing for (the Code.exe ancestor
# of $SeedPid with a MainWindowHandle).
function Find-VSCodeHwnd([int]$startPid) {
    if ($startPid -le 0) { return [IntPtr]::Zero }
    $cur = $startPid
    $hops = 0
    while ($cur -gt 0 -and $hops -lt 20) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$cur" -ErrorAction SilentlyContinue
        if (-not $p) { break }
        if ($p.Name -ieq 'Code.exe') {
            try {
                $proc = Get-Process -Id $cur -ErrorAction Stop
                if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
                    return $proc.MainWindowHandle
                }
            } catch {}
        }
        $cur = [int]$p.ParentProcessId
        $hops++
    }
    # Fallback: any visible Code.exe — better than nothing on multi-window
    # setups where ancestry walk drops us into an extension host with no
    # window.
    $fallback = Get-Process Code -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
                Select-Object -First 1
    if ($fallback) { return $fallback.MainWindowHandle }
    return [IntPtr]::Zero
}

$targetHwnd = Find-VSCodeHwnd -startPid $SeedPid

# Pin to primary monitor's working area (so it doesn't overlap the
# taskbar if it's on top).
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$bounds = $screen.Bounds

# Resolve color name → WPF Brush.
try {
    $brush = New-Object System.Windows.Media.SolidColorBrush(
        [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
    )
} catch {
    $brush = [System.Windows.Media.Brushes]::Gold
}

$win = New-Object System.Windows.Window
$win.WindowStyle = [System.Windows.WindowStyle]::None
$win.AllowsTransparency = $true
$win.Background = [System.Windows.Media.Brushes]::Transparent
$win.Topmost = $true
$win.ShowInTaskbar = $false
$win.ResizeMode = [System.Windows.ResizeMode]::NoResize
$win.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
$win.Left = $bounds.Left
$win.Top = $bounds.Top
$win.Width = $bounds.Width
$win.Height = $bounds.Height
$win.Focusable = $false
$win.IsHitTestVisible = $false

# Frame the entire monitor with a 4-edge border. A Canvas lets us place
# 4 rectangles at absolute positions (top/bottom/left/right) so the
# interior of the screen stays untouched — only the edges glow.
$canvas = New-Object System.Windows.Controls.Canvas
$canvas.Width = $bounds.Width
$canvas.Height = $bounds.Height
$canvas.IsHitTestVisible = $false

function New-EdgeRect([double]$w, [double]$h, [double]$x, [double]$y, $fill) {
    $r = New-Object System.Windows.Shapes.Rectangle
    $r.Width = $w
    $r.Height = $h
    $r.Fill = $fill
    $r.IsHitTestVisible = $false
    [System.Windows.Controls.Canvas]::SetLeft($r, $x)
    [System.Windows.Controls.Canvas]::SetTop($r, $y)
    return $r
}

$top    = New-EdgeRect $bounds.Width $Thickness 0 0 $brush
$bottom = New-EdgeRect $bounds.Width $Thickness 0 ($bounds.Height - $Thickness) $brush
$left   = New-EdgeRect $Thickness ($bounds.Height - 2 * $Thickness) 0 $Thickness $brush
$right  = New-EdgeRect $Thickness ($bounds.Height - 2 * $Thickness) ($bounds.Width - $Thickness) $Thickness $brush

$canvas.Children.Add($top)    | Out-Null
$canvas.Children.Add($bottom) | Out-Null
$canvas.Children.Add($left)   | Out-Null
$canvas.Children.Add($right)  | Out-Null

$win.Content = $canvas

# Make click-through at the Win32 level + expose GetForegroundWindow so
# we can stop pulsing once user focuses the right VSCode.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinHelpers {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x20;
    public const int WS_EX_LAYERED = 0x80000;
    public const int WS_EX_NOACTIVATE = 0x8000000;
    public const int WS_EX_TOOLWINDOW = 0x80;
}
'@

$win.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper $win
    $hwnd = $helper.Handle
    $ex = [WinHelpers]::GetWindowLong($hwnd, [WinHelpers]::GWL_EXSTYLE)
    $ex = $ex -bor [WinHelpers]::WS_EX_TRANSPARENT `
              -bor [WinHelpers]::WS_EX_LAYERED `
              -bor [WinHelpers]::WS_EX_NOACTIVATE `
              -bor [WinHelpers]::WS_EX_TOOLWINDOW
    [WinHelpers]::SetWindowLong($hwnd, [WinHelpers]::GWL_EXSTYLE, $ex) | Out-Null
})

# Animation: pulse 0 → 0.95 → 0 every 800ms. RepeatBehavior depends on
# mode — fixed duration vs loop-until-focus.
$anim = New-Object System.Windows.Media.Animation.DoubleAnimation
$anim.From = 0.0
$anim.To = 0.95
$anim.AutoReverse = $true
$anim.Duration = New-Object System.Windows.Duration(
    [System.TimeSpan]::FromMilliseconds(400)
)

if ($DurationMs -gt 0) {
    # Fixed-duration mode: pulse N times then stop.
    $pulses = [Math]::Max(1, [int]($DurationMs / 800))
    $anim.RepeatBehavior = New-Object System.Windows.Media.Animation.RepeatBehavior($pulses)
} else {
    # Loop-until-focus mode.
    $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
}

# TTS-only audio: speak an escalation phrase on each stage. Eager
# Add-Type so the first Speak() doesn't stall the dispatcher.
Add-Type -AssemblyName System.Speech | Out-Null

function Invoke-EscalationTTS([string]$text) {
    # Prefer pre-baked Supertonic WAV for the canonical escalation phrase.
    # Async via SoundPlayer.Play() (not PlaySync) so the pulse animation
    # keeps running while audio plays.
    $wavPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'audio\claude-still-needs.wav'
    if ((-not $env:CLAUDE_NOTIFY_WAV_DISABLED) -and (Test-Path $wavPath)) {
        try {
            $player = New-Object System.Media.SoundPlayer $wavPath
            $player.Play()
            return
        } catch { }
    }
    # SAPI fallback — live synthesis for unbaked or disabled-WAV cases.
    try {
        $tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $prompt = $tts.SpeakAsync($text)
        $tts.add_SpeakCompleted({ param($s, $e) $s.Dispose() })
    } catch { }
}

$win.Add_Loaded({
    $canvas.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
    # Initial TTS is handled by the parallel toast PowerShell (see
    # notification-alert.js / stop-notify.js) — edge-pulse only speaks
    # at escalation stages.
})

$startTime = [DateTime]::UtcNow

# Escalation stages — color + replay-sound at each threshold (ms from start).
# Only used when -Escalate is set.
$escalationStages = @(
    @{ AtMs = 20000; Color = 'DarkOrange' },
    @{ AtMs = 40000; Color = 'Red' }
)
$nextStageIndex = 0

# Helper to swap brush color on all 4 edge rectangles simultaneously.
function Set-EdgeColor($newColor) {
    try {
        $newBrush = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString($newColor)
        )
        $top.Fill = $newBrush
        $bottom.Fill = $newBrush
        $left.Fill = $newBrush
        $right.Fill = $newBrush
    } catch { }
}

# Stop condition: focused on target VSCode, OR fixed duration elapsed,
# OR hard max-duration cap reached. Poll every 250ms.
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [System.TimeSpan]::FromMilliseconds(250)
$timer.Add_Tick({
    $elapsed = ([DateTime]::UtcNow - $startTime).TotalMilliseconds

    # Max-duration hard cap.
    if ($elapsed -ge $MaxDurationMs) {
        $timer.Stop()
        $win.Close()
        return
    }

    # Fixed-duration mode handles its own stop via animation length.
    if ($DurationMs -gt 0 -and $elapsed -ge $DurationMs) {
        $timer.Stop()
        $win.Close()
        return
    }

    # Escalation: advance color stage when its threshold is crossed,
    # and speak escalation phrase to demand attention.
    if ($Escalate -and $nextStageIndex -lt $escalationStages.Count) {
        $next = $escalationStages[$nextStageIndex]
        if ($elapsed -ge $next.AtMs) {
            Set-EdgeColor $next.Color
            Invoke-EscalationTTS $EscalateText
            $script:nextStageIndex = $nextStageIndex + 1
        }
    }

    # Loop-until-focus mode: stop when user clicks into the right VSCode.
    if ($DurationMs -eq 0 -and $targetHwnd -ne [IntPtr]::Zero) {
        $fg = [WinHelpers]::GetForegroundWindow()
        if ($fg -eq $targetHwnd) {
            $timer.Stop()
            $win.Close()
            return
        }
    }
})
$win.Add_Loaded({ $timer.Start() })

$win.ShowDialog() | Out-Null
