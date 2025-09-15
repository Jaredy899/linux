# Bootstrap installer for Windows PowerShell

$DOTFILES = "$env:USERPROFILE\dotfiles"
$PROFILEPATH = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
$CONFIGDIR = "$env:USERPROFILE\.config\fastfetch"
$MISEDIR = "$env:USERPROFILE\.config\mise"

# Ensure dirs
New-Item -ItemType Directory -Force -Path (Split-Path $PROFILEPATH) | Out-Null
New-Item -ItemType Directory -Force -Path $CONFIGDIR | Out-Null
New-Item -ItemType Directory -Force -Path $MISEDIR | Out-Null

Write-Host "📂 Linking configs..."
Copy-Item -Force "$DOTFILES\powershell\Microsoft.PowerShell_profile.ps1" $PROFILEPATH
Copy-Item -Force "$DOTFILES\config\starship.toml" "$env:USERPROFILE\.config\starship.toml"
Copy-Item -Force "$DOTFILES\config\mise\config.toml" "$MISEDIR\config.toml"
Copy-Item -Force "$DOTFILES\config\fastfetch\windows.jsonc" "$CONFIGDIR\config.jsonc"

Write-Host "⚙️ Installing tools..."
# requires winget available
if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
  winget install -e --id Starship.Starship
}
if (-not (Get-Command fastfetch -ErrorAction SilentlyContinue)) {
  winget install -e --id fastfetch-cli
}
if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
  winget install -e --id ajeetdsouza.zoxide
}
if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
  winget install -e --id jdx.mise
}
if (-not (Get-Module -ListAvailable Terminal-Icons)) {
  Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}

Write-Host "✅ Windows dotfiles installed. Restart PowerShell."