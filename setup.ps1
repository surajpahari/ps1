# Force TLS 1.2 (required when running from .bat / NoProfile)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# setup.ps1 - Interactive setup wizard for Timora
# Writes values to config.json
# =============================================================================

. (Join-Path $PSScriptRoot "messages.ps1")
$MSG = Get-TinoraMessages

$ConfigFile = Join-Path $PSScriptRoot "config.json"

# Load existing config if present so we can show defaults
$existing = $null
if (Test-Path $ConfigFile) {
    try {
        $existing = Get-Content -Raw $ConfigFile | ConvertFrom-Json
    } catch {
        # Corrupt config - start fresh
        $existing = $null
    }
}

function Read-Default {
    param(
        [string]$Label,
        [string]$Default = ""
    )
    if ($Default -ne "") {
        $hint = " [${Default}]"
    } else {
        $hint = ""
    }
    $raw = Read-Host "${Label}${hint}"
    if ([string]::IsNullOrWhiteSpace($raw) -and $Default -ne "") {
        return $Default
    }
    return $raw.Trim()
}

Clear-Host
Write-Host ""
Write-Host "  ===========================================" -ForegroundColor DarkCyan
Write-Host "   TIMORA - Setup Wizard" -ForegroundColor Cyan
Write-Host "  ===========================================" -ForegroundColor DarkCyan
Write-Host ""

# RaceDir
$defaultRaceDir = if ($existing) {
    $existing.RaceDir 
} else {
    "" 
}
$RaceDir = Read-Default -Label "Race directory (relative to HOME, e.g. Documents/timingfiles)" -Default $defaultRaceDir
while ([string]::IsNullOrWhiteSpace($RaceDir)) {
    Write-Host "  RaceDir cannot be empty." -ForegroundColor Yellow
    $RaceDir = Read-Default -Label "Race directory" -Default $defaultRaceDir
}

# IntervalSeconds
$defaultInterval = if ($existing -and $existing.IntervalSeconds) {
    [string]$existing.IntervalSeconds 
} else {
    "5" 
}
$intervalRaw = Read-Default -Label "Sync interval in seconds" -Default $defaultInterval
$IntervalSeconds = 5
if (-not [int]::TryParse($intervalRaw, [ref]$IntervalSeconds) -or $IntervalSeconds -lt 1) {
    Write-Host ("  " + ($MSG.SETUP_INVALID_INT -f $defaultInterval)) -ForegroundColor Yellow
    $IntervalSeconds = [int]$defaultInterval
}

# Prefix
$defaultPrefix = if ($existing) {
    $existing.Prefix 
} else {
    "" 
}
$Prefix = Read-Default -Label "Device prefix (e.g. 192.168.1.01)" -Default $defaultPrefix
while ([string]::IsNullOrWhiteSpace($Prefix)) {
    Write-Host "  Prefix cannot be empty." -ForegroundColor Yellow
    $Prefix = Read-Default -Label "Device prefix" -Default $defaultPrefix
}

# Token (mask input)
$defaultTokenHint = if ($existing -and $existing.token -ne "") {
    "<existing token - press Enter to keep>" 
} else {
    "" 
}

$tokenLabel = if ($defaultTokenHint -ne "") {
    "  Bearer token ($defaultTokenHint):" 
} else {
    "  Bearer token:" 
}
Write-Host ""
Write-Host $tokenLabel -ForegroundColor White
Write-Host ""
$secureToken = Read-Host -AsSecureString "  Token"
$Token = (New-Object System.Management.Automation.PSCredential("token", $secureToken)).GetNetworkCredential().Password
if ([string]::IsNullOrWhiteSpace($Token) -and $existing -and $existing.token -ne "") {
    $Token = $existing.token
    Write-Host "  Keeping existing token." -ForegroundColor DarkGray
}
while ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "  Token cannot be empty." -ForegroundColor Yellow
    $secureToken = Read-Host -AsSecureString "  Token"
    $Token = (New-Object System.Management.Automation.PSCredential("token", $secureToken)).GetNetworkCredential().Password
}

# API URLs - keep existing or use defaults
$ApiUrl = if ($existing -and $existing.ApiUrl) {
    $existing.ApiUrl 
} else {
    "https://admin.racepatro.com/api/v1/devices" 
}
$LoginUrl = if ($existing -and $existing.LoginUrl) {
    $existing.LoginUrl 
} else {
    "https://admin.racepatro.com/api/v1/device-auth" 
}

# Build config object and write
$config = [ordered]@{
    RaceDir         = $RaceDir
    ApiUrl          = $ApiUrl
    LoginUrl        = $LoginUrl
    IntervalSeconds = $IntervalSeconds
    Prefix          = $Prefix
    token           = $Token
}

$config | ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8 $ConfigFile

Write-Host ""
Write-Host ("  " + $MSG.SETUP_DONE) -ForegroundColor Green
Write-Host ""
Write-Host ""
