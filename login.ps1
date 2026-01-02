param (
  [string]$LoginUrl = "https://rpatro.zeronetechnology.com.np/api/v1/device-auth"
)

$TokenFile = Join-Path $PSScriptRoot "token.txt"

# Default TokenFile if not provided
if (-not $TokenFile)
{
  $TokenFile = Join-Path $PSScriptRoot "token.txt"
}

# Read token
if (!(Test-Path $TokenFile))
{
  Write-Host "Token file not found: $TokenFile" -ForegroundColor Red
  exit 1
}

$Token = (Get-Content $TokenFile -Raw).Trim()
$headers = @{
  Authorization = "Bearer $Token"
}

try
{
  Write-Host "Connecting to race app..."

  $response = Invoke-RestMethod `
    -Uri $LoginUrl `
    -Method POST `
    -Headers $headers `
    -ErrorAction Stop

  if ($null -eq $response)
  {
    Write-Host "Connection error: Empty response" -ForegroundColor Red
    exit 1
  }

  $event = $response.event
  $checkpoint = $response.checkpoint
  $device = $response.device

  Write-Host "Connected device '$($device.name)' (status: $($device.status))" -ForegroundColor Cyan
  Write-Host "Event: $($event.title)" -ForegroundColor Green
  Write-Host "Checkpoint: $($checkpoint.name) at $($checkpoint.location)" -ForegroundColor Blue

  exit 0   # Success

} catch [System.Net.WebException]
{
  if ($_.Exception.Response)
  {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    if ($statusCode -eq 401)
    {
      Write-Host "Unauthorized (401). Token may be invalid or expired." -ForegroundColor Red
    } else
    {
      Write-Host "HTTP error $statusCode during login." -ForegroundColor Red
    }
  } else
  {
    Write-Host "Network error during login." -ForegroundColor Red
  }
  exit 1
} catch
{
  Write-Host "Login failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}


