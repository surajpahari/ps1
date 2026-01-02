param (
  [switch]$connect,
  [switch]$upload,
  [switch]$upload_fresh
)

$AppConnectionScript = "$HOME/rfid-test/data/login.ps1"
$RaceUploadScript = "$HOME/rfid-test/data/connection.ps1"


if ($connect)
{
  Write-Host "Running connect..."
  & $AppConnectionScript
}

if ($upload)
{
  Write-Host "Running upload..."
  & $AppConnectionScript
  if ($LASTEXITCODE -eq 0)
  {
    & $RaceUploadScript
  } else
  {
    Write-Host "Skipping race upload because login failed." -ForegroundColor Red
  }
}

if ($upload_fresh)
{
  $StateFile = Join-Path $PSScriptRoot "info/state.txt"
  Write-Host "Running upload fresh..."

  # Clear/reset the state file
  Set-Content -Path $StateFile -Value "0"
  Write-Host "State file cleared to 0"

  # Run connection/login script
  & $AppConnectionScript
  if ($LASTEXITCODE -eq 0)
  {
    & $RaceUploadScript -fresh
  } else
  {
    Write-Host "Skipping race upload because login failed." -ForegroundColor Red
  }
}

