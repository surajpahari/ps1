param(
  [switch]$setup,
  [switch]$connect,
  [switch]$fresh,
  [switch]$check,
  [switch]$clearlog,

  # Legacy flags kept for backward compatibility
  [switch]$upload,
  [switch]$upload_fresh
)

# Force TLS 1.2 (required when running from .bat / NoProfile)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# timora.ps1 - Main entry point for the Timora RFID sync tool
# =============================================================================

# Print a small elegant header on invocation
Write-Host "Timora RFID Sync" -ForegroundColor Cyan

. (Join-Path $PSScriptRoot "messages.ps1")
$MSG = Get-TinoraMessages

$ScriptPath    = Split-Path -Parent $MyInvocation.MyCommand.Path
$SetupScript   = Join-Path $ScriptPath "setup.ps1"
$LoginScript   = Join-Path $ScriptPath "login.ps1"
$SyncScript    = Join-Path $ScriptPath "connection.ps1"
$ConfigFile    = Join-Path $ScriptPath "config.json"
$LogFile       = Join-Path $ScriptPath "info/log.txt"
$ErrorLogFile  = Join-Path $ScriptPath "info/error.txt"
$StateFile     = Join-Path $ScriptPath "info/state.txt"

# ---------------------------------------------------------------------------
# -setup
# ---------------------------------------------------------------------------
if ($setup)
{
  & $SetupScript
  exit
}

# ---------------------------------------------------------------------------
# -check (Authenticates device, prints configuration/state info, but doesn't start sync)
# ---------------------------------------------------------------------------
if ($check)
{
  # 1. Run the device connection and authentication check
  Write-Host ""
  Write-Host "--- Device Status & Authentication Check ---" -ForegroundColor Gray
  & $LoginScript
  # $loginSuccess = ($LASTEXITCODE -eq 0)

  # 2. Display local config and sync offset status
  Write-Host ""
  Write-Host "--- Local Config & Sync Status Check ---" -ForegroundColor Gray
    
  # Config
  if (Test-Path $ConfigFile)
  {
    try
    {
      $cfg = Get-Content -Raw $ConfigFile | ConvertFrom-Json
      Write-Host "  RaceDir:      $($cfg.RaceDir)"         -ForegroundColor White
      Write-Host "  Prefix:       $($cfg.Prefix)"          -ForegroundColor White
      Write-Host "  Interval:     $($cfg.IntervalSeconds)s" -ForegroundColor White
      Write-Host "  API:          $($cfg.ApiUrl)"           -ForegroundColor White

      # Race file check
      $raceDir = $cfg.RaceDir
      if ($raceDir -like "~*")
      {
        $raceDir = $raceDir -replace "^~", [Environment]::GetFolderPath("UserProfile")
      } elseif (-not [System.IO.Path]::IsPathRooted($raceDir))
      {
        $raceDir = Join-Path $HOME $raceDir
      }

      $racePath = Join-Path $raceDir ("$($cfg.Prefix)_$(Get-Date -Format 'yyyyMMdd').txt")

      if (-not (Test-Path $raceDir))
      {
        Write-Host "  Timing Folder: NOT FOUND ($raceDir)" -ForegroundColor Red
      } elseif (Test-Path $racePath)
      {
        Write-Host ("  " + ($MSG.STATUS_RACEFILE_OK   -f $racePath)) -ForegroundColor Green
      } else
      {
        Write-Host ("  " + ($MSG.STATUS_RACEFILE_MISS -f $racePath)) -ForegroundColor Yellow
      }
    } catch
    {
      Write-Host "  Config is present but could not be parsed." -ForegroundColor Yellow
    }
  } else
  {
    Write-Host ("  " + $MSG.STATUS_CONFIG_MISS) -ForegroundColor Red
  }

  Write-Host ""

  # State offset
  if (Test-Path $StateFile)
  {
    $offset = (Get-Content -Raw $StateFile).Trim()
    Write-Host ("  " + ($MSG.STATUS_STATE -f $offset)) -ForegroundColor White
  } else
  {
    Write-Host "  Sync offset:  not initialized" -ForegroundColor DarkGray
  }

  # Log sizes
  if (Test-Path $LogFile)
  {
    $logLines = (Get-Content $LogFile | Measure-Object -Line).Lines
    Write-Host ("  " + ($MSG.STATUS_LOGSIZE -f $logLines)) -ForegroundColor White
  } else
  {
    Write-Host "  Log size:     no log yet" -ForegroundColor DarkGray
  }

  if (Test-Path $ErrorLogFile)
  {
    $errLines = (Get-Content $ErrorLogFile | Measure-Object -Line).Lines
    Write-Host ("  " + ($MSG.STATUS_ERRSIZE -f $errLines)) -ForegroundColor $(if ($errLines -gt 0)
      { "Red" 
      } else
      { "White" 
      })
  } else
  {
    Write-Host "  Error log:    no errors yet" -ForegroundColor DarkGray
  }

  Write-Host ""
  exit
}

# ---------------------------------------------------------------------------
# -clearlog
# ---------------------------------------------------------------------------
if ($clearlog)
{
  $cleared = $false
  foreach ($f in @($LogFile, $ErrorLogFile))
  {
    if (Test-Path $f)
    {
      Clear-Content -Path $f
      Write-Host "  Cleared: $f" -ForegroundColor DarkGray
      $cleared = $true
    }
  }
  if ($cleared)
  {
    Write-Host ("  " + $MSG.CLEARLOG_DONE) -ForegroundColor Green
  } else
  {
    Write-Host ("  " + $MSG.CLEARLOG_NOTHING) -ForegroundColor Yellow
  }
  exit
}

# ---------------------------------------------------------------------------
# -connect - Authenticate and start the sync loop
# ---------------------------------------------------------------------------
if ($connect)
{
  Write-Host $MSG.RUNNING_CONNECT -ForegroundColor Cyan
  & $LoginScript
  if ($LASTEXITCODE -eq 0)
  {
    & $SyncScript
  } else
  {
    Write-Host $MSG.SKIP_UPLOAD -ForegroundColor Red
  }
  exit
}

# ---------------------------------------------------------------------------
# -fresh - Clear state/log/error, then authenticate and start the sync loop
# ---------------------------------------------------------------------------
if ($fresh)
{
  Write-Host $MSG.RUNNING_FRESH -ForegroundColor Cyan

  foreach ($f in @($StateFile, $LogFile, $ErrorLogFile))
  {
    if (Test-Path $f)
    {
      Clear-Content -Path $f
      Write-Host "  Cleared: $f" -ForegroundColor DarkGray
    }
  }
  # Reset state to 0
  Set-Content -Path $StateFile -Value "0"
  Write-Host ("  " + $MSG.STATE_CLEARED) -ForegroundColor Green

  & $LoginScript
  if ($LASTEXITCODE -eq 0)
  {
    & $SyncScript
  } else
  {
    Write-Host $MSG.SKIP_UPLOAD -ForegroundColor Red
  }
  exit
}

# ---------------------------------------------------------------------------
# Legacy: -upload (Renamed to fit original connection sync loop, kept for backwards compatibility)
# ---------------------------------------------------------------------------
if ($upload)
{
  Write-Host $MSG.RUNNING_UPLOAD -ForegroundColor Cyan
  & $LoginScript
  if ($LASTEXITCODE -eq 0)
  {
    & $SyncScript -fresh
  } else
  {
    Write-Host $MSG.SKIP_UPLOAD -ForegroundColor Red
  }
  exit
}

# ---------------------------------------------------------------------------
# Legacy: -upload_fresh
# ---------------------------------------------------------------------------
if ($upload_continue)
{
  Write-Host $MSG.RUNNING_UPLOAD_FRESH -ForegroundColor Cyan
  & $LoginScript
  if ($LASTEXITCODE -eq 0)
  {
    & $SyncScript -fresh
  } else
  {
    Write-Host $MSG.SKIP_UPLOAD -ForegroundColor Red
  }
  exit
}

# ---------------------------------------------------------------------------
# No flag provided - show help
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  Usage:" -ForegroundColor White
Write-Host "    timora --setup      Run the setup wizard"                        -ForegroundColor DarkGray
Write-Host "    timora --connect    Authenticate & start the RFID sync loop"     -ForegroundColor DarkGray
Write-Host "    timora --fresh      Clear state/logs, then connect and sync"     -ForegroundColor DarkGray
Write-Host "    timora --check      Authenticate & display log/status info"      -ForegroundColor DarkGray
Write-Host "    timora --clearlog   Clear log files"                             -ForegroundColor DarkGray
Write-Host ""
