# =============================================================================
# connection.ps1 - RFID sync loop: tails the timing file and POSTs new lines
# Requires: config.json to be configured (run .\timora.ps1 -setup first)
# =============================================================================

param(
    [switch]$fresh   # Reset state offset before starting
)

# Force TLS 1.2 (required when running from .bat / NoProfile)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. (Join-Path $PSScriptRoot "messages.ps1")
$MSG = Get-TinoraMessages

# ---------------------------------------------------------------------------
# File paths
# ---------------------------------------------------------------------------
$ErrorLogFile = Join-Path $PSScriptRoot "info/error.txt"
$LogFile      = Join-Path $PSScriptRoot "info/log.txt"
$StateFile    = Join-Path $PSScriptRoot "info/state.txt"

# Ensure info/ directory exists
$infoDir = Join-Path $PSScriptRoot "info"
if (-not (Test-Path $infoDir)) {
    New-Item -ItemType Directory -Path $infoDir | Out-Null
}

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
$ConfigFile = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $ConfigFile)) {
    Write-Host "Config not found. Run: .\timora.ps1 -setup" -ForegroundColor Red
    exit 1
}

$config = Get-Content -Raw $ConfigFile | ConvertFrom-Json

$RaceDir         = $config.RaceDir
$ApiUrl          = $config.ApiUrl
$IntervalSeconds = [int]$config.IntervalSeconds
$Prefix          = $config.Prefix
$Token           = $config.token

# ---------------------------------------------------------------------------
# Validate required fields
# ---------------------------------------------------------------------------
$missing = @()
if ([string]::IsNullOrWhiteSpace($RaceDir))  { $missing += "RaceDir" }
if ([string]::IsNullOrWhiteSpace($ApiUrl))   { $missing += "ApiUrl" }
if ([string]::IsNullOrWhiteSpace($Token))    { $missing += "token" }
if ([string]::IsNullOrWhiteSpace($Prefix))   { $missing += "Prefix" }
if ($IntervalSeconds -lt 1)                  { $IntervalSeconds = 5 }

if ($missing.Count -gt 0) {
    Write-Host "Missing config fields: $($missing -join ', '). Run: .\timora.ps1 -setup" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Expand tilde and build race file path
# ---------------------------------------------------------------------------
if ($RaceDir -like "~*") {
    $RaceDir = $RaceDir -replace "^~", [Environment]::GetFolderPath("UserProfile")
} elseif (-not [System.IO.Path]::IsPathRooted($RaceDir)) {
    $RaceDir = Join-Path $HOME $RaceDir
}

$CurrentDate = Get-Date -Format "yyyyMMdd"
$RacePath    = Join-Path $RaceDir ("${Prefix}_${CurrentDate}.txt")

Write-Host "Race file:  $RacePath"          -ForegroundColor DarkGray
Write-Host "API:        $ApiUrl"            -ForegroundColor DarkGray
Write-Host "Interval:   ${IntervalSeconds}s" -ForegroundColor DarkGray
Write-Host ""

# Ensure parent folder exists
if (-not (Test-Path $RaceDir)) {
    Write-Host "[ERROR] Timing directory '$RaceDir' does not exist. Create the folder first or run: .\timora.ps1 -setup" -ForegroundColor Red
    exit 1
}

# Loop until the file exists
while (-not (Test-Path $RacePath)) {
    Write-Host "Waiting for timing file to be created at: $RacePath (Is this the correct path?)" -ForegroundColor Yellow
    Start-Sleep -Seconds $IntervalSeconds
}

$FilePath = $RacePath
$headers  = @{ "Authorization" = "Bearer $Token" }

# ---------------------------------------------------------------------------
# State file - tracks byte offset of last successful send
# ---------------------------------------------------------------------------
if ($fresh -or -not (Test-Path $StateFile)) {
    Set-Content -Path $StateFile -Value "0" -Encoding UTF8
    Write-Host $MSG.STATE_INITIALIZED -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Sync loop
# ---------------------------------------------------------------------------
$partialLine = ""

Write-Host $MSG.STARTING_SYNC -ForegroundColor Cyan
Write-Host ""

while ($true) {
    try {
        $lastPosition = [int64](Get-Content -Path $StateFile -Raw).Trim()
        $fileSize     = (Get-Item $FilePath).Length

        Write-Host ($MSG.LAST_POSITION -f $lastPosition, $fileSize) -ForegroundColor DarkGray

        if ($fileSize -gt $lastPosition) {
            Write-Host $MSG.NEW_DATA_FOUND -ForegroundColor Yellow

            # Open without exclusive lock - timing software may still be writing
            $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open,
                                          [System.IO.FileAccess]::Read,
                                          [System.IO.FileShare]::ReadWrite)
            $fs.Seek($lastPosition, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader     = New-Object System.IO.StreamReader($fs)
            $newContent = $reader.ReadToEnd()
            $reader.Close()
            $fs.Close()

            if (-not [string]::IsNullOrWhiteSpace($newContent)) {
                # Stitch together any leftover partial line from last loop
                if ($partialLine.Length -gt 0) {
                    $newContent  = $partialLine + $newContent
                    $partialLine = ""
                }

                $lines = $newContent -split "`r?`n"
                Write-Host ($MSG.TOTAL_LINES -f $lines.Count) -ForegroundColor DarkGray

                # If the last line has no trailing newline it's incomplete - hold it back
                if (-not $newContent.EndsWith("`n")) {
                    $partialLine = $lines[-1]
                    $lines       = $lines[0..($lines.Length - 2)]
                    Write-Host ($MSG.PARTIAL_LINE -f $partialLine) -ForegroundColor DarkGray
                }

                # Filter out blank lines
                $lines = $lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

                if ($lines.Count -gt 0) {
                    $payload   = $lines -join "`n"
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

                    Write-Host ($MSG.SENDING_LINES -f $lines.Count) -ForegroundColor Yellow
                    Write-Host $payload -ForegroundColor DarkYellow

                    try {
                        Invoke-RestMethod `
                            -Uri         $ApiUrl `
                            -Method      POST `
                            -Body        $payload `
                            -ContentType "text/plain" `
                            -Headers     $headers `
                            -ErrorAction Stop | Out-Null

                        $logEntry = $MSG.SENT_RECORDS -f $timestamp, $lines.Count
                        Write-Host $logEntry -ForegroundColor Green
                        Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8

                    } catch [System.Net.WebException] {
                        $statusCode = $null
                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                        }

                        if ($statusCode -eq 401) {
                            $err = $MSG.ERR_UNAUTHORIZED -f $timestamp, $lines.Count
                        } elseif ($statusCode) {
                            $err = $MSG.ERR_HTTP -f $timestamp, $lines.Count, $statusCode
                        } else {
                            $err = $MSG.ERR_SEND -f $timestamp, $lines.Count, $_.Exception.Message
                        }

                        Write-Host $err -ForegroundColor Red
                        Add-Content -Path $ErrorLogFile -Value $err -Encoding UTF8

                    } catch {
                        $err = $MSG.ERR_SEND -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $lines.Count, $_
                        Write-Host $err -ForegroundColor Red
                        Add-Content -Path $ErrorLogFile -Value $err -Encoding UTF8
                    }

                    # Advance state offset by bytes actually sent (include newline per line)
                    $sentBytes = [Text.Encoding]::UTF8.GetByteCount(($lines -join "`n") + "`n")
                    $newOffset = $lastPosition + $sentBytes
                    Set-Content -Path $StateFile -Value $newOffset -Encoding UTF8
                    Write-Host ($MSG.STATE_UPDATED -f $newOffset) -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host $MSG.NO_NEW_DATA -ForegroundColor DarkGray
        }

    } catch {
        $errMsg = $MSG.ERR_UNEXPECTED -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $_
        Write-Host $errMsg -ForegroundColor Red
        Add-Content -Path $ErrorLogFile -Value $errMsg -Encoding UTF8
    }

    Write-Host ""
    Start-Sleep -Seconds $IntervalSeconds
}
