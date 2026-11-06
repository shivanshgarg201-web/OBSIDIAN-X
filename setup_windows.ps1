$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobile = Join-Path $root 'flutter_app'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Install Flutter and add it to PATH first.' }
Push-Location $mobile
try {
  flutter create --platforms=android --project-name obsidian_x --org com.obsidianx .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create failed.' }
  $manifest = Join-Path $mobile 'android/app/src/main/AndroidManifest.xml'
  $xml = Get-Content $manifest -Raw
  if ($xml -notmatch 'android.permission.ACCESS_FINE_LOCATION') {
    $permissions = '<uses-permission android:name="android.permission.INTERNET" />' + "`n    " +
      '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />' + "`n    " +
      '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />'
    $xml = $xml.Replace('<application', $permissions + "`n    " + '<application')
  }
  Set-Content $manifest $xml -Encoding UTF8
  $debugManifest = Join-Path $mobile 'android/app/src/debug/AndroidManifest.xml'
  @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:usesCleartextTraffic="true" />
</manifest>
'@ | Set-Content $debugManifest -Encoding UTF8
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
  Write-Host 'Flutter Android project ready. Start backend using npm install and npm start, then flutter run.'
} finally { Pop-Location }
