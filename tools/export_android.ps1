param(
    [string]$GodotPath = 'C:/Users/ding5/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe',
    [string]$OutputPath = 'builds/android/FireflyRoad-0.1.20261019.6-arm64-debug.apk'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot executable not found. Pass -GodotPath.' }
    if (-not (Test-Path -LiteralPath 'source/export_templates/4.6.3/android_debug.apk')) {
        throw 'The verified Godot 4.6.3 Android debug template is missing. See docs/android_apk.md.'
    }
    $apkTarget = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
    New-Item -ItemType Directory -Path (Split-Path -Parent $apkTarget) -Force | Out-Null
    & $GodotPath --headless --editor --path $projectRoot --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed.' }
    & $GodotPath --headless --path $projectRoot --export-debug Android $apkTarget
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed.' }
    Get-Item -LiteralPath $apkTarget | Select-Object FullName, Length, LastWriteTime
    Get-FileHash -LiteralPath $apkTarget -Algorithm SHA256
} finally {
    Pop-Location
}
