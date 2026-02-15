$ErrorActionPreference = "Stop"

$repo = "Project-Korlang/Korlang-Site"
$apiUrl = "https://api.github.com/repos/" + $repo + "/releases"

# Add TLS/SSL support and user agent
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Korlang Installer v1.5"
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
      "User-Agent" = "Korlang-Installer/1.5"
      "Accept" = "application/vnd.github.v3+json"
    }
    $releases = Invoke-RestMethod -Uri ($apiUrl + "?per_page=100") -Headers $headers -TimeoutSec 30
    
    if ($releases -and $releases.Count -gt 0) {
        # Sort releases to prefer v* tags over rolling tags if possible
        $sortedReleases = $releases | Sort-Object { $_.created_at } -Descending
        foreach ($r in $sortedReleases) {
          $tag = $r.tag_name
          
          if ($channel -eq "alpha") {
            if ($tag -notmatch "alpha") { continue }
          } else {
            if ($tag -match "alpha") { continue }
          }

          $winAssets = $r.assets | Where-Object { $_.name -like "*windows*" -and $_.name -like "*.zip" }
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

if (-not $url) {
  if (-not $latest) { $latest = "v0.0.1-alpha" }
  $channel = "alpha"
  $zip = "korlang-" + $latest + "-windows-x86_64.zip"
  $url = "https://github.com/" + $repo + "/releases/download/" + $latest + "/" + $zip
  Write-Host "Auto-detection found no matching assets. Using default: $latest"
}

Write-Host "Selected: $latest ($channel)"
Write-Host "Asset: $zip"

$dest = Join-Path $HOME ".korlang\bin"
if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}

$temp = $null
try {
  $tempDir = [System.IO.Path]::GetTempPath()
  $temp = Join-Path $tempDir ([Guid]::NewGuid().ToString() + ".zip")
  
  Write-Host "Downloading..."
  $dlHeaders = @{ "User-Agent" = "Korlang-Installer/1.5" }
  Invoke-WebRequest -Uri $url -OutFile $temp -Headers $dlHeaders -TimeoutSec 60
  
  Write-Host "Extracting..."
  $extractTemp = Join-Path $dest "extract_temp"
  if (Test-Path $extractTemp) { Remove-Item $extractTemp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
  
  Expand-Archive -Path $temp -DestinationPath $extractTemp -Force
  
  # Robust Installation: Find korlang.exe wherever it is in the zip
  $exeFile = Get-ChildItem -Path $extractTemp -Recurse -Filter "korlang.exe" | Select-Object -First 1
  
  if ($exeFile) {
      $srcDir = $exeFile.Directory.FullName
      Write-Host "Detected structure: korlang.exe found in $($exeFile.Directory.Name). Moving files..."
      Get-ChildItem -Path $srcDir | Move-Item -Destination $dest -Force
  } else {
      Write-Host "Warning: korlang.exe not found in archive. Moving all files flat..."
      Get-ChildItem -Path $extractTemp -Recurse | Where-Object { -not $_.PSIsContainer } | Move-Item -Destination $dest -Force
  }
  
  if (Test-Path $extractTemp) { Remove-Item $extractTemp -Recurse -Force }
  if (Test-Path $temp) { Remove-Item $temp }
} catch {
  Write-Host "Error: $($_.Exception.Message)"
  if ($temp -and (Test-Path $temp)) { Remove-Item $temp }
  Write-Host ""
  Write-Host "Manual Installation:"
  Write-Host ("1. Visit: https://github.com/" + $repo + "/releases")
  Write-Host "2. Download: $zip"
  Write-Host "3. Extract to: $dest"
  exit 1
}

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
  Write-Host "----------------------------------------"
  Write-Host "ERROR: Verification failed. korlang.exe not found at $dest"
  Write-Host "Contents of $dest :"
  Get-ChildItem -Path $dest | Select-Object Name
  Write-Host "----------------------------------------"
  exit 1
}
