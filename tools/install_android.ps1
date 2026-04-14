#Requires -Version 5.1
<#
  Export Android APK with Godot 4.x (headless) and install via adb.

  Prerequisites:
  - Project > Export: create an Android preset (note its exact name, default here is "Android").
  - export_presets.cfg must exist (Godot creates it when you add a preset).
  - Android SDK platform-tools on PATH, or set ADB path.
  - USB debugging on device; run: adb devices

  Usage (from project root):
    powershell -ExecutionPolicy Bypass -File tools\install_android.ps1
    powershell -ExecutionPolicy Bypass -File tools\install_android.ps1 -GodotExe "C:\Godot\Godot_v4.4-stable_win64_console.exe"

  Env vars (optional):
    GODOT_BIN  - path to Godot executable (console build recommended for logs)
    ADB        - path to adb.exe

  Flags:
    -SkipExport   Only adb install -r (use existing APK at -OutputApk)
    -Preset       Export preset name (must match export_presets.cfg)
    -Debug        Use --export-debug instead of --export-release
#>
param(
    [string] $GodotExe = $env:GODOT_BIN,
    [string] $Preset = "Android",
    [string] $OutputApk = "",
    [string] $AdbExe = $env:ADB,
    [switch] $SkipExport,
    [switch] $Debug
)

$ErrorActionPreference = "Stop"
# Script lives in <project>/tools/ — project root is parent of tools/
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $ProjectRoot "project.godot"))) {
    Write-Error "Could not find project.godot (expected repo root containing project.godot)."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($OutputApk)) {
    $buildDir = Join-Path $ProjectRoot "build"
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
    $OutputApk = Join-Path $buildDir "CreativeCraft_debug.apk"
}
$OutputApk = [System.IO.Path]::GetFullPath($OutputApk)

$exportCfg = Join-Path $ProjectRoot "export_presets.cfg"
if (-not (Test-Path $exportCfg)) {
    Write-Host "Missing export_presets.cfg. In Godot: Project > Export... > Add... > Android, save, then run again." -ForegroundColor Yellow
    exit 1
}

if (-not $SkipExport) {
    if ([string]::IsNullOrWhiteSpace($GodotExe)) {
        Write-Host "Set GODOT_BIN to your Godot 4.x executable, or pass -GodotExe." -ForegroundColor Yellow
        Write-Host 'Example: $env:GODOT_BIN = "C:\Godot\Godot_v4.4-stable_win64_console.exe"' -ForegroundColor Gray
        exit 1
    }
    if (-not (Test-Path $GodotExe)) {
        Write-Error "Godot not found: $GodotExe"
        exit 1
    }

    $exportFlag = if ($Debug) { "--export-debug" } else { "--export-release" }
    Write-Host "Exporting ($exportFlag) preset '$Preset' -> $OutputApk" -ForegroundColor Cyan
    $godotArgs = @(
        "--path", $ProjectRoot,
        "--headless",
        $exportFlag, $Preset,
        $OutputApk
    )
    $p = Start-Process -FilePath $GodotExe -ArgumentList $godotArgs -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Write-Error "Godot export failed (exit $($p.ExitCode)). Check preset name matches '$Preset' and Android export is configured."
        exit $p.ExitCode
    }
    if (-not (Test-Path $OutputApk)) {
        Write-Error "Export finished but APK missing: $OutputApk"
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($AdbExe)) {
    $AdbExe = "adb"
}

Write-Host "Checking device..." -ForegroundColor Cyan
& $AdbExe devices
if ($LASTEXITCODE -ne 0) {
    Write-Error "adb failed. Install Android platform-tools and add to PATH, or set ADB to adb.exe full path."
    exit 1
}

Write-Host "Installing (replace existing)..." -ForegroundColor Cyan
& $AdbExe install -r $OutputApk
if ($LASTEXITCODE -ne 0) {
    Write-Error "adb install failed. Is a device authorized in 'adb devices'?"
    exit 1
}

Write-Host "Done. Launch the app on the device." -ForegroundColor Green
