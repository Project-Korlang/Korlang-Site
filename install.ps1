$ErrorActionPreference = "Stop"

$repo = "Project-Korlang/Korlang-Compiler"
$apiUrl = "https://api.github.com/repos/" + $repo + "/releases"

# Add TLS/SSL support and user agent
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Korlang Installer v1.1"
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
if ($env:KORLANG_VERSION) {
  $latest = $env:KORLANG_VERSION
  Write-Host "Using specified version: $latest"
} else {
  Write-Host "Fetching latest $channel release from GitHub..."
  try {
    $headers = @{
      "User-Agent" = "Korlang-Installer/1.1"
      "Accept" = "application/vnd.github.v3+json"
    }
    $releases = Invoke-RestMethod -Uri ($apiUrl + "?per_page=100") -Headers $headers -TimeoutSec 30
    
    if ($releases -and $releases.Count -gt 0) {
        foreach ($r in $releases) {
          $tag = $r.tag_name
          if ($channel -eq "alpha") {
            if ($tag -match "alpha") { $latest = $tag; break }
          } else {
            if ($tag -notmatch "alpha") { $latest = $tag; break }
          }
        }
    }
  } catch {
    Write-Host "Note: Could not reach GitHub API ($($_.Exception.Message))"
  }
}

# Fallback if no releases found or API failed
if (-not $latest) {
  $latest = "v0.1.0-alpha"
  Write-Host "No releases found on GitHub yet. Falling back to default: $latest"
  $channel = "alpha"
}

Write-Host "Selected version: $latest ($channel)"

$os = "windows"
$arch = "x86_64"
$zip = "korlang-" + $latest + "-" + $os + "-" + $arch + ".zip"
$url = "https://github.com/" + $repo + "/releases/download/" + $latest + "/" + $zip

Write-Host "Downloading: $zip"
Write-Host "From: $url"

$dest = Join-Path $HOME ".korlang\bin"
if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}

try {
  $temp = [System.IO.Path]::GetTempFileName()
  Write-Host "Downloading to temporary file..."
  # We still use $headers here, but note they might be empty if we skipped the try block
  $dlHeaders = @{ "User-Agent" = "Korlang-Installer/1.1" }
  Invoke-WebRequest -Uri $url -OutFile $temp -Headers $dlHeaders -TimeoutSec 60
  
  Write-Host "Extracting to $dest"
  $extractTemp = Join-Path $dest "extract_temp"
  if (Test-Path $extractTemp) { Remove-Item $extractTemp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
  
  Expand-Archive -Path $temp -DestinationPath $extractTemp -Force
  
  $extracted = Get-ChildItem -Path $extractTemp
  if ($extracted.Count -eq 1 -and $extracted[0].PSIsContainer) {
      Write-Host "Detected top-level directory in zip, stripping..."
      Get-ChildItem -Path $extracted[0].FullName | Move-Item -Destination $dest -Force
  } else {
      $extracted | Move-Item -Destination $dest -Force
  }
  
  Remove-Item $extractTemp -Recurse -Force
  if (Test-Path $temp) { Remove-Item $temp }
} catch {
  Write-Host "Download failed: $($_.Exception.Message)"
  Write-Host ""
  Write-Host "Manual Installation Instructions:"
  Write-Host ("1. Visit: https://github.com/" + $repo + "/releases")
  Write-Host "2. Download: $zip"
  Write-Host "3. Extract to: $dest"
  Write-Host "4. Add to PATH: $dest"
  exit 1
}

# Verify installation
$korlangExe = Join-Path $dest "korlang.exe"
if (Test-Path $korlangExe) {
  Write-Host "✓ Korlang installed successfully!"
  Write-Host "Location: $korlangExe"
  
  # Add to PATH if not already present
  $path = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($path -notlike "*\.korlang\bin*") {
    Write-Host "Adding to PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$path;$dest", "User")
    Write-Host "✓ Added to user PATH. Restart your shell to use."
  } else {
    Write-Host "✓ Already in PATH."
  }
  
  Write-Host ""
  Write-Host "Installation complete! Restart your shell and run:"
  Write-Host "korlang --version"
} else {
  Write-Error "Installation verification failed. korlang.exe not found."
  exit 1
}
