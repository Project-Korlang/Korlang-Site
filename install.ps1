$ErrorActionPreference = "Stop"

$repo = "project-korlang/korlang"
$api = "https://api.github.com/repos/$repo/releases/latest"
$release = Invoke-RestMethod -Uri $api
$version = $release.tag_name

$os = "windows"
$arch = "x86_64"
$zip = "korlang-$version-$os-$arch.zip"
$url = "https://github.com/$repo/releases/download/$version/$zip"

$dest = "$HOME\.korlang\bin"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$temp = New-TemporaryFile
Invoke-WebRequest -Uri $url -OutFile $temp
Expand-Archive -Path $temp -DestinationPath $dest -Force

$path = [Environment]::GetEnvironmentVariable("Path", "User")
if ($path -notlike "*\.korlang\bin*") {
  [Environment]::SetEnvironmentVariable("Path", "$path;$dest", "User")
}

Write-Host "Korlang installed. Restart your shell."
