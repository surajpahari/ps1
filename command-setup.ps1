# setup-command.ps1

$Folder = Split-Path -Parent $MyInvocation.MyCommand.Path

# Get current user PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Add folder if it isn't already there
if ($UserPath -notlike "*$Folder*")
{
  if ([string]::IsNullOrWhiteSpace($UserPath))
  {
    $NewPath = $Folder
  } else
  {
    $NewPath = "$UserPath;$Folder"
  }

  [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")

  Write-Host ""
  Write-Host "[OK] Timora has been added to your PATH." -ForegroundColor Green
  Write-Host "Folder: $Folder"
  Write-Host ""
  Write-Host "Close and reopen PowerShell, then run:"
  Write-Host "    timora"
} else
{
  Write-Host "[OK] Timora is already in your PATH." -ForegroundColor Yellow
}
