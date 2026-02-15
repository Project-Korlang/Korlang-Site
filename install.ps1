$ErrorActionPreference = "Stop"

# The releases are actually in the Site repo based on current setup
$repo = "Project-Korlang/Korlang-Site"
$apiUrl = "https://api.github.com/repos/" + $repo + "/releases"

# Add TLS/SSL support and user agent
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Korlang Installer v1.3"
Write-Host "========================"

$channel = $env:KORLANG_CHANNEL
if (-not $channel) {
  Write-Host "Select release channel:"
  Write-Host "1) stable"
  Write-Host "2) alpha"
  $choice = Read-Host ">"
  $channel = "stable"
  if ($choice -eq "2") { $channel = "alpha" }
}

$latest = $null
$zip = $null
$url = $null

if ($env:KORLANG_VERSION) {
  $latest = $env:KORLANG_VERSION
  Write-Host "Using specified version: $latest"
} else {
  Write-Host "Fetching latest $channel release from GitHub..."
  try {
    $headers = @{
      "User-Agent" = "Korlang-Installer/1.3"
      "Accept" = "application/vnd.github.v3+json"
    }
    $releases = Invoke-RestMethod -Uri ($apiUrl + "?per_page=100") -Headers $headers -TimeoutSec 30
    
    if ($releases -and $releases.Count -gt 0) {
        foreach ($r in $releases) {
          $tag = $r.tag_name
          
          # Filter by channel
          if ($channel -eq "alpha") {
            if ($tag -notmatch "alpha") { continue }
          } else {
            if ($tag -match "alpha") { continue }
          }

          # Look for windows assets
          $winAssets = $r.assets | Where-Object { $_.name -like "*windows*" }
          if ($winAssets) {
              $targetAsset = $winAssets | Where-Object { $_.name -like "*x86_64*" } | Select-Object -First 1
              if (-not $targetAsset) { $targetAsset = $winAssets | Select-Object -First 1 }
              
              if ($targetAsset) {
                  $latest = $tag
                  $zip = $targetAsset.name
                  $url = $targetAsset.browser_download_url
                  break
              }
          }
        }
    }
  } catch {
    Write-Host "Note: Could not reach GitHub API ($($_.Exception.Message))"
  }
}

# Corrected fallback to 0.0.1
if (-not $url) {
  if (-not $latest) { $latest = "v0.0.1-alpha" }
  $channel = "alpha"
  $zip = "korlang-" + $latest + "-windows-x86_64.zip"
  $url = "https://github.com/" + $repo + "/releases/download/" + $latest + "/" + $zip
  Write-Host "Auto-detection found no matching assets in releases. Falling back to: $latest"
}

Write-Host "Selected: $latest ($channel)"
Write-Host "Asset: $zip"

$dest = Join-Path $HOME ".korlang\bin"
if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}

try {
  $temp = [System.IO.Path]::GetTempFileName()
  Write-Host "Downloading..."
  $dlHeaders = @{ "User-Agent" = "Korlang-Installer/1.3" }
  Invoke-WebRequest -Uri $url -OutFile $temp -Headers $dlHeaders -TimeoutSec 60
  
  Write-Host "Extracting to $dest"
  $extractTemp = Join-Path $dest "extract_temp"
  if (Test-Path $extractTemp) { Remove-Item $extractTemp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
  
  Expand-Archive -Path $temp -DestinationPath $extractTemp -Force
  
  $extracted = Get-ChildItem -Path $extractTemp
  if ($extracted.Count -eq 1 -and $extracted[0].PSIsContainer) {
      Write-Host "Stripping top-level directory..."
      Get-ChildItem -Path $extracted[0].FullName | Move-Item -Destination $dest -Force
  } else {
      $extracted | Move-Item -Destination $dest -Force
  }
  
  Remove-Item $extractTemp -Recurse -Force
  if (Test-Path $temp) { Remove-Item $temp }
} catch {
  Write-Host "Download failed: $($_.Exception.Message)"
  Write-Host ""
  Write-Host "Manual Installation:"
  Write-Host ("1. Visit: https://github.com/" + $repo + "/releases")
  Write-Host "2. Download: $zip"
  Write-Host "3. Extract to: $dest"
  exit 1
}

# Verify installation
$korlangExe = Join-Path $dest "korlang.exe"
if (Test-Path $korlangExe) {
  Write-Host "✓ Korlang installed successfully!"
  
  $path = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($path -notlike "*\.korlang\bin*") {
    Write-Host "Adding to PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$path;$dest", "User")
    Write-Host "✓ Added to user PATH. Restart your shell to use."
  }
  
  Write-Host "Run: korlang --version"
} else {
  Write-Error "Verification failed. korlang.exe not found."
  exit 1
}
