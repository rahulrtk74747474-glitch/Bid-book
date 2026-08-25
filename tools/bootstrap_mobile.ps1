$ErrorActionPreference = 'Stop'

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $Root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not installed or not available on PATH.'
}

if (-not (Test-Path 'android') -or -not (Test-Path 'ios')) {
    flutter create . --platforms=android,ios --org com.bidbook --project-name bid_book
}

if (Get-Command python -ErrorAction SilentlyContinue) {
    python tools/configure_mobile_native.py
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    py -3 tools/configure_mobile_native.py
} else {
    throw 'Python 3 is required to patch the generated Android/iOS wrappers.'
}

flutter pub get
flutter analyze
flutter test

Write-Host 'Bid&Book mobile wrappers are ready.'
Write-Host 'Android package / iOS bundle ID: com.bidbook.app'
Write-Host 'Run: flutter run --dart-define=BIDBOOK_API_BASE_URL=http://<your-lan-ip>:8000'
