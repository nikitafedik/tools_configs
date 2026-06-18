param(
    [Parameter(Mandatory = $true)]
    [string]$StateDir,

    [string]$Title = "Codex plot preview"
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$createdNew = $false
$mutexName = "Local\CodexPlotPreview-$env:USERNAME"
$mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$createdNew)

if (-not $createdNew) {
    return
}

$imagePathFile = Join-Path $StateDir "current_image.txt"
$titleFile = Join-Path $StateDir "current_title.txt"

function Read-FirstLine([string]$Path) {
    if (-not [System.IO.File]::Exists($Path)) {
        return $null
    }

    try {
        return ([System.IO.File]::ReadLines($Path) | Select-Object -First 1)
    } catch {
        return $null
    }
}

function Load-Bitmap([string]$Path) {
    if (-not [System.IO.File]::Exists($Path)) {
        return $null
    }

    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.StreamSource = $stream
        $bitmap.EndInit()
        $bitmap.Freeze()
        return $bitmap
    } finally {
        if ($stream -ne $null) {
            $stream.Dispose()
        }
    }
}

$window = New-Object System.Windows.Window
$window.Title = $Title
$window.Width = 1100
$window.Height = 760
$window.MinWidth = 520
$window.MinHeight = 360
$window.WindowStartupLocation = "CenterScreen"

$dock = New-Object System.Windows.Controls.DockPanel
$dock.LastChildFill = $true

$status = New-Object System.Windows.Controls.TextBlock
$status.Margin = "10,6,10,8"
$status.FontFamily = "Consolas"
$status.FontSize = 12
$status.TextWrapping = "NoWrap"
$status.TextTrimming = "CharacterEllipsis"
$status.Foreground = [System.Windows.Media.Brushes]::DimGray
[System.Windows.Controls.DockPanel]::SetDock($status, [System.Windows.Controls.Dock]::Bottom)

$viewer = New-Object System.Windows.Controls.Border
$viewer.Background = [System.Windows.Media.Brushes]::Black
$viewer.Padding = "8"

$image = New-Object System.Windows.Controls.Image
$image.Stretch = [System.Windows.Media.Stretch]::Uniform
$image.HorizontalAlignment = "Center"
$image.VerticalAlignment = "Center"
$viewer.Child = $image

$dock.Children.Add($status) | Out-Null
$dock.Children.Add($viewer) | Out-Null
$window.Content = $dock

$script:lastPath = $null
$script:lastWrite = $null

function Update-Plot {
    $path = Read-FirstLine $imagePathFile
    if ([string]::IsNullOrWhiteSpace($path)) {
        $status.Text = "Waiting for a Codex plot..."
        return
    }

    $plotTitle = Read-FirstLine $titleFile
    if ([string]::IsNullOrWhiteSpace($plotTitle)) {
        $plotTitle = [System.IO.Path]::GetFileName($path)
    }

    if (-not [System.IO.File]::Exists($path)) {
        $status.Text = "Missing: $path"
        return
    }

    $writeTime = [System.IO.File]::GetLastWriteTimeUtc($path)
    if ($path -eq $script:lastPath -and $writeTime -eq $script:lastWrite) {
        return
    }

    $bitmap = Load-Bitmap $path
    if ($bitmap -eq $null) {
        $status.Text = "Could not load: $path"
        return
    }

    $image.Source = $bitmap
    $window.Title = "Codex plot - $plotTitle"
    $status.Text = "$plotTitle    $path"
    $script:lastPath = $path
    $script:lastWrite = $writeTime
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({ Update-Plot })

$window.Add_Loaded({
    Update-Plot
    $timer.Start()
})

$window.Add_Closed({
    $timer.Stop()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
})

$app = New-Object System.Windows.Application
$app.Run($window) | Out-Null
