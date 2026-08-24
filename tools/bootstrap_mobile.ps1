$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not installed or not available on PATH.'
}

if (-not (Test-Path 'android') -or -not (Test-Path 'ios')) {
    flutter create . --platforms=android,ios --org com.bidbook --project-name bid_book
}

flutter pub get
flutter test

Write-Host 'Bid&Book is ready. Run: flutter run'
