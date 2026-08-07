# Force TLS 1.2 (required when running from .bat / NoProfile)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# login.ps1 - Authenticate device against the Timora API
# Exit codes: 0 = success, 1 = failure
# =============================================================================

. (Join-Path $PSScriptRoot "messages.ps1")
$MSG = Get-TinoraMessages

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
$ConfigFile = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $ConfigFile)) {
    Write-Host "Config not found. Run: .\timora.ps1 -setup" -ForegroundColor Red
    exit 1
}

$config = Get-Content -Raw $ConfigFile | ConvertFrom-Json

$Token    = $config.token
$LoginUrl = $config.LoginUrl

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "Token is empty. Run: .\timora.ps1 -setup" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($LoginUrl)) {
    Write-Host "LoginUrl is missing from config.json" -ForegroundColor Red
    exit 1
}

$headers = @{ "Authorization" = "Bearer $Token" }

# ---------------------------------------------------------------------------
# Authenticate
# ---------------------------------------------------------------------------
Write-Host $MSG.CONNECTING -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $LoginUrl -Method POST -Headers $headers -ErrorAction Stop

    if ($response -and $response.PSObject.Properties.Name -contains "device") {
        $raceEvent  = $response.event
        $checkpoint = $response.checkpoint
        $device     = $response.device

        # Print status labels with high-contrast highlighted values
        Write-Host "  Device:     " -NoNewline -ForegroundColor Gray
        Write-Host "$($device.name)" -NoNewline -ForegroundColor White
        Write-Host " ($($device.status))" -ForegroundColor Cyan

        Write-Host "  Event:      " -NoNewline -ForegroundColor Gray
        Write-Host "$($raceEvent.title)" -ForegroundColor Green

        Write-Host "  Checkpoint: " -NoNewline -ForegroundColor Gray
        Write-Host "$($checkpoint.name)" -NoNewline -ForegroundColor Yellow
        Write-Host " at " -NoNewline -ForegroundColor Gray
        Write-Host "$($checkpoint.location)" -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host $MSG.INVALID_RESPONSE -ForegroundColor Red
        exit 1
    }
} catch [System.Net.WebException] {
    $statusCode = $null
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }

    if ($statusCode -eq 401) {
        Write-Host $MSG.ERR_LOGIN_401 -ForegroundColor Red
    } elseif ($statusCode) {
        Write-Host ($MSG.ERR_LOGIN_HTTP -f $statusCode) -ForegroundColor Red
    } else {
        Write-Host ($MSG.LOGIN_FAILED -f $_.Exception.Message) -ForegroundColor Red
    }
    exit 1
} catch {
    Write-Host ($MSG.LOGIN_FAILED -f $_) -ForegroundColor Red
    exit 1
}
