param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [string]$Title = "Codex plot preview",

    [int]$HoldSeconds = 0,

    [int]$MaxWidth = 0,

    [int]$MaxHeight = 0
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Write-Raw([string]$Text) {
    [Console]::Out.Write($Text)
}

function Add-SixelRun(
    [System.Text.StringBuilder]$Builder,
    [int]$Count,
    [char]$Character
) {
    if ($Count -le 0) {
        return
    }

    if ($Count -ge 4) {
        [void]$Builder.Append("!")
        [void]$Builder.Append($Count)
        [void]$Builder.Append($Character)
        return
    }

    for ($i = 0; $i -lt $Count; $i++) {
        [void]$Builder.Append($Character)
    }
}

if (-not [System.IO.File]::Exists($ImagePath)) {
    Write-Host "Missing image: $ImagePath"
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}

$esc = [char]27
$bel = [char]7
Write-Raw ($esc + "]0;" + $Title + $bel)
Write-Host "Codex plot preview: $Title"
Write-Host $ImagePath
Write-Host ""

$source = $null
$bitmap = $null
$graphics = $null

try {
    $source = [System.Drawing.Bitmap]::FromFile($ImagePath)

    $consoleWidth = 120
    $consoleHeight = 40
    try {
        $consoleWidth = [Math]::Max(80, [Console]::WindowWidth)
        $consoleHeight = [Math]::Max(24, [Console]::WindowHeight)
    } catch {
    }

    if ($MaxWidth -le 0) {
        $MaxWidth = [Math]::Min(1600, [Math]::Max(640, $consoleWidth * 8))
    }

    if ($MaxHeight -le 0) {
        $MaxHeight = [Math]::Min(1000, [Math]::Max(360, ($consoleHeight - 6) * 16))
    }

    $scale = [Math]::Min($MaxWidth / [double]$source.Width, $MaxHeight / [double]$source.Height)
    if ($scale -gt 1.0) {
        $scale = 1.0
    }

    $width = [Math]::Max(1, [int][Math]::Round($source.Width * $scale))
    $height = [Math]::Max(1, [int][Math]::Round($source.Height * $scale))

    $bitmap = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($source, 0, 0, $width, $height)

    $levels = @(0, 85, 170, 255)
    $palette = New-Object System.Collections.Generic.List[object]
    for ($r = 0; $r -lt 4; $r++) {
        for ($g = 0; $g -lt 4; $g++) {
            for ($b = 0; $b -lt 4; $b++) {
                $palette.Add(@($levels[$r], $levels[$g], $levels[$b])) | Out-Null
            }
        }
    }

    Write-Raw ($esc + "Pq")
    Write-Raw ('"1;1;{0};{1}' -f $width, $height)

    for ($i = 0; $i -lt $palette.Count; $i++) {
        $color = $palette[$i]
        $rp = [int][Math]::Round($color[0] * 100 / 255)
        $gp = [int][Math]::Round($color[1] * 100 / 255)
        $bp = [int][Math]::Round($color[2] * 100 / 255)
        Write-Raw ('#{0};2;{1};{2};{3}' -f $i, $rp, $gp, $bp)
    }

    for ($y = 0; $y -lt $height; $y += 6) {
        $masks = @()
        $used = New-Object bool[] 64
        for ($i = 0; $i -lt 64; $i++) {
            $masks += ,(New-Object byte[] $width)
        }

        for ($dy = 0; $dy -lt 6; $dy++) {
            $py = $y + $dy
            if ($py -ge $height) {
                break
            }

            $bit = [byte](1 -shl $dy)
            for ($x = 0; $x -lt $width; $x++) {
                $pixel = $bitmap.GetPixel($x, $py)
                $ri = [Math]::Min(3, [Math]::Max(0, [int][Math]::Round($pixel.R / 85.0)))
                $gi = [Math]::Min(3, [Math]::Max(0, [int][Math]::Round($pixel.G / 85.0)))
                $bi = [Math]::Min(3, [Math]::Max(0, [int][Math]::Round($pixel.B / 85.0)))
                $index = ($ri * 16) + ($gi * 4) + $bi
                $masks[$index][$x] = [byte]($masks[$index][$x] -bor $bit)
                $used[$index] = $true
            }
        }

        for ($index = 0; $index -lt 64; $index++) {
            if (-not $used[$index]) {
                continue
            }

            Write-Raw ("#$index")
            $builder = New-Object System.Text.StringBuilder
            $lastChar = [char]0
            $runLength = 0

            for ($x = 0; $x -lt $width; $x++) {
                $char = [char](63 + $masks[$index][$x])
                if ($runLength -eq 0) {
                    $lastChar = $char
                    $runLength = 1
                    continue
                }

                if ($char -eq $lastChar) {
                    $runLength++
                    continue
                }

                Add-SixelRun $builder $runLength $lastChar
                $lastChar = $char
                $runLength = 1
            }

            Add-SixelRun $builder $runLength $lastChar
            Write-Raw $builder.ToString()
            Write-Raw '$'
        }

        Write-Raw '-'
    }

    Write-Raw ($esc + "\")
    Write-Host ""
    Write-Host ("Rendered {0}x{1} from {2}x{3}" -f $width, $height, $source.Width, $source.Height)
} finally {
    if ($graphics -ne $null) {
        $graphics.Dispose()
    }
    if ($bitmap -ne $null) {
        $bitmap.Dispose()
    }
    if ($source -ne $null) {
        $source.Dispose()
    }
}

if ($HoldSeconds -gt 0) {
    Write-Host ("Closing in {0} seconds..." -f $HoldSeconds)
    Start-Sleep -Seconds $HoldSeconds
} else {
    Read-Host "Press Enter to close" | Out-Null
}
