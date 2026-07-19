$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Khong tim thay lenh '$Name'. Hay cai Flutter SDK va them vao PATH."
    }
}

function Add-LineAfter([string]$Path, [string]$Needle, [string]$Line) {
    $content = Get-Content $Path -Raw
    if ($content.Contains($Line)) { return }
    if (-not $content.Contains($Needle)) {
        throw "Khong tim thay doan can patch trong ${Path}: $Needle"
    }
    $content = $content.Replace($Needle, "$Needle`r`n    $Line")
    Set-Content -Path $Path -Value $content -Encoding UTF8
}

Require-Command flutter

Write-Host "[1/6] Kiem tra Flutter..." -ForegroundColor Cyan
flutter doctor

if (-not (Test-Path (Join-Path $ProjectRoot "android"))) {
    Write-Host "[2/6] Tao Android shell..." -ForegroundColor Cyan
    $TempShell = Join-Path ([System.IO.Path]::GetTempPath()) ("fintrack_shell_" + [guid]::NewGuid())
    flutter create --platforms=android --org com.ct220h --project-name fintrack $TempShell
    Copy-Item (Join-Path $TempShell "android") (Join-Path $ProjectRoot "android") -Recurse
    $GeneratedMetadata = Join-Path $TempShell ".metadata"
    if (Test-Path $GeneratedMetadata) {
        Copy-Item $GeneratedMetadata (Join-Path $ProjectRoot ".metadata") -Force
    }
    Remove-Item $TempShell -Recurse -Force
} else {
    Write-Host "[2/6] Thu muc android da ton tai, giu nguyen." -ForegroundColor DarkGray
}

Write-Host "[3/6] Patch Gradle va Android Manifest..." -ForegroundColor Cyan

$AppKts = Join-Path $ProjectRoot "android/app/build.gradle.kts"
$SettingsKts = Join-Path $ProjectRoot "android/settings.gradle.kts"
$AppGroovy = Join-Path $ProjectRoot "android/app/build.gradle"
$SettingsGroovy = Join-Path $ProjectRoot "android/settings.gradle"

if (Test-Path $AppKts) {
    Add-LineAfter $AppKts 'id("com.android.application")' 'id("com.google.gms.google-services")'
    $content = Get-Content $AppKts -Raw
    $content = [regex]::Replace($content, 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23')
    Set-Content $AppKts $content -Encoding UTF8
} elseif (Test-Path $AppGroovy) {
    Add-LineAfter $AppGroovy "id 'com.android.application'" "id 'com.google.gms.google-services'"
    $content = Get-Content $AppGroovy -Raw
    $content = [regex]::Replace($content, 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23')
    Set-Content $AppGroovy $content -Encoding UTF8
} else {
    throw "Khong tim thay android/app/build.gradle(.kts)."
}

if (Test-Path $SettingsKts) {
    $content = Get-Content $SettingsKts -Raw
    $pluginLine = '    id("com.google.gms.google-services") version "4.4.4" apply false'
    if (-not $content.Contains('com.google.gms.google-services')) {
        $content = $content.Replace(
            '    id("dev.flutter.flutter-plugin-loader") version "1.0.0"',
            "    id(`"dev.flutter.flutter-plugin-loader`") version `"1.0.0`"`r`n$pluginLine"
        )
        Set-Content $SettingsKts $content -Encoding UTF8
    }
} elseif (Test-Path $SettingsGroovy) {
    $content = Get-Content $SettingsGroovy -Raw
    $pluginLine = "    id 'com.google.gms.google-services' version '4.4.4' apply false"
    if (-not $content.Contains('com.google.gms.google-services')) {
        $content = $content.Replace(
            "    id 'dev.flutter.flutter-plugin-loader' version '1.0.0'",
            "    id 'dev.flutter.flutter-plugin-loader' version '1.0.0'`r`n$pluginLine"
        )
        Set-Content $SettingsGroovy $content -Encoding UTF8
    }
}

$Manifest = Join-Path $ProjectRoot "android/app/src/main/AndroidManifest.xml"
$manifestContent = Get-Content $Manifest -Raw
$manifestContent = $manifestContent.Replace('android:label="fintrack"', 'android:label="FinTrack"')
if (-not $manifestContent.Contains('android.permission.INTERNET')) {
    $manifestContent = $manifestContent.Replace('<application', '<uses-permission android:name="android.permission.INTERNET" />' + "`r`n    <application")
}
if (-not $manifestContent.Contains('android:usesCleartextTraffic')) {
    $manifestContent = $manifestContent.Replace('<application', '<application android:usesCleartextTraffic="true"')
}
Set-Content $Manifest $manifestContent -Encoding UTF8

Write-Host "[4/6] Tai dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "[5/6] Tao launcher icon..." -ForegroundColor Cyan
dart run flutter_launcher_icons

Write-Host "[6/6] Kiem tra Firebase config..." -ForegroundColor Cyan
$GoogleServices = Join-Path $ProjectRoot "android/app/google-services.json"
if (-not (Test-Path $GoogleServices)) {
    Write-Warning "Chua co android/app/google-services.json. Hay tai tu Firebase app com.ct220h.fintrack va dat vao dung vi tri."
} else {
    Write-Host "Da tim thay google-services.json." -ForegroundColor Green
}

Write-Host "`nHoan tat. Chay: flutter run" -ForegroundColor Green
Write-Host "Backend emulator mac dinh: http://10.0.2.2:8000"
