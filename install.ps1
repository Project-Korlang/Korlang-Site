$ErrorActionPreference = "Stop"

$repo = "Project-Korlang/Korlang-Site"
$api = "https://api.github.com/repos/$repo/releases"

Write-Host "Select release channel:"
Write-Host "1) stable"
Write-Host "2) alpha"
$choice = Read-Host ">"

$channel = "stable"
if ($choice -eq "2") { $channel = "alpha" }

$releases = Invoke-RestMethod -Uri $api
$latest = $null
foreach ($r in $releases) {
  $tag = $r.tag_name
  if ($channel -eq "alpha") {
    if ($tag -match "alpha") { $latest = $tag; break }
  } else {
    if ($tag -notmatch "alpha") { $latest = $tag; break }
  }
}

if (-not $latest) {
  Write-Error "Failed to detect latest $channel version"
}

$os = "windows"
$arch = "x86_64"
$zip = "korlang-$latest-$os-$arch.zip"
$url = "https://github.com/$repo/releases/download/$latest/$zip"

$dest = "$HOME\.korlang\bin"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$temp = New-TemporaryFile
Invoke-WebRequest -Uri $url -OutFile $temp
Expand-Archive -Path $temp -DestinationPath $dest -Force

$path = [Environment]::GetEnvironmentVariable("Path", "User")
if ($path -notlike "*\.korlang\bin*") {
  [Environment]::SetEnvironmentVariable("Path", "$path;$dest", "User")
}

Write-Host "Korlang installed from $latest ($channel). Restart your shell."
