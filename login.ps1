param (
    [string]$TokenFile = "$HOME/rfid-test/data/token.txt",
    [string]$LoginUrl = "http://racepatro.test/api/v1/device-auth"
)

# Read token
if (!(Test-Path $TokenFile)) {
    Write-Host "Token file not found: $TokenFile" -ForegroundColor Red
    exit 1
}

$Token = (Get-Content $TokenFile -Raw).Trim()
$headers = @{ "Authorization" = "Bearer $Token" }

try {
    Write-Host "Connecting to race app..."
    $response = Invoke-RestMethod -Uri $LoginUrl -Method POST -Headers $headers

    if ($response -is [System.Management.Automation.PSObject]) {
        $event = $response.event
        $checkpoint = $response.checkpoint
        $device = $response.device

        Write-Host "Connected device '$($device.name)' (status: $($device.status))" -ForegroundColor Cyan
        Write-Host "Event: $($event.title)" -ForegroundColor Green 
        Write-Host "Checkpoint: $($checkpoint.name) at $($checkpoint.location)" -ForegroundColor Blue 

        exit 0   # Success
    } else {
        Write-Host "Connection error: Invalid response" -ForegroundColor Red
        exit 1   # Failure
    }

} catch [System.Net.WebException] {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    if ($statusCode -eq 401) {
        Write-Host "Unauthorized (401). Token may be invalid or expired." -ForegroundColor Red
    } else {
        Write-Host "HTTP error $statusCode during login." -ForegroundColor Red
    }
    exit 1   # Failure
} catch {
    Write-Host "Login failed: $_" -ForegroundColor Red
    exit 1   # Failure
}

