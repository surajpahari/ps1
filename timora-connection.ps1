$FilePath = "$HOME/rfid-test/data/race.txt"
$StateFile = "$HOME/rfid-test/data/state.txt"
$ApiUrl = "http://racepatro.test/api/v1/devices"
$TokenFile = "$HOME/rfid-test/data/token.txt"
$IntervalSeconds = 5
$LogFile = "$HOME/rfid-test/data/log.txt"
$ErrorLogFile = "$HOME/rfid-test/data/error.txt"

# Read Bearer token from file
if (!(Test-Path $TokenFile))
{
  Write-Host "Token file not found: $TokenFile" -ForegroundColor Red
  exit
}
$Token = (Get-Content $TokenFile -Raw).Trim()
$headers = @{ "Authorization" = "Bearer $Token" }

# Initialize state file if missing
if (!(Test-Path $StateFile))
{
  Set-Content $StateFile "0"
  Write-Host "State file initialized at 0"
}

# Keep leftover partial line between loops
$partialLine = ""

Write-Host "Starting RFID sync loop..."
while ($true)
{
  try
  {
    $lastPosition = [int64](Get-Content $StateFile)
    $fileSize = (Get-Item $FilePath).Length
    Write-Host "Last position: $lastPosition, File size: $fileSize"

    if ($fileSize -gt $lastPosition)
    {
      Write-Host "New data found, reading..."
      # Open file for reading without locking
      $fs = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'ReadWrite')
      $fs.Seek($lastPosition, 'Begin') | Out-Null
      $reader = New-Object System.IO.StreamReader($fs)
      $newContent = $reader.ReadToEnd()
      $reader.Close()
      $fs.Close()

      if ($newContent.Trim().Length -gt 0)
      {
        # Prepend leftover partial line from previous loop
        if ($partialLine.Length -gt 0)
        {
          $newContent = $partialLine + $newContent
          $partialLine = ""
        }

        # Split by lines
        $lines = $newContent -split "`r?`n"
        Write-Host "Total lines read: $($lines.Count)"

        # Check if last line is complete
        if (-not $newContent.EndsWith("`n"))
        {
          $partialLine = $lines[-1]
          $lines = $lines[0..($lines.Length - 2)]
          Write-Host "Partial line detected, saved for next loop: $partialLine"
        }

        if ($lines.Count -gt 0)
        {
          $payload = $lines -join "`n"
          Write-Host "Sending $($lines.Count) lines to backend..."

          try
          {
            $response = Invoke-RestMethod `
              -Uri $ApiUrl `
              -Method POST `
              -Body $payload `
              -ContentType "text/plain" `
              -Headers $headers


            $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Sent $($lines.Count) lines | Response: $(ConvertTo-Json $response -Depth 5)"
            Write-Host $logEntry -ForegroundColor Green
            Add-Content $LogFile $logEntry

          } catch [System.Net.WebException]
          {
            # Extract the HTTP status code
            $statusCode = $_.Exception.Response.StatusCode.Value__
            if ($statusCode -eq 401)
            {
              $err = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Sent $($lines.Count) lines | ERROR: Unauthorized (401). Token may be invalid or expired."
              Write-Host $err -ForegroundColor Red
              Add-Content $ErrorLogFile $err
            } else
            {
              $err = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Sent $($lines.Count) lines | ERROR: HTTP $statusCode"
              Write-Host $err -ForegroundColor Red
              Add-Content $ErrorLogFile $err
            }
          } catch
          {
            # Any other unexpected errors
            $err = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Sent $($lines.Count) lines | ERROR: $_"
            Write-Host $err -ForegroundColor Red
            Add-Content $ErrorLogFile $err
          }
          # Update state file offset
          $sentBytes = [Text.Encoding]::UTF8.GetByteCount(($lines -join "`n") + "`n")
          Set-Content $StateFile ($lastPosition + $sentBytes)
          Write-Host "State file updated to $($lastPosition + $sentBytes)"
        }
      }
    } else
    {
      Write-Host "No new data found."
    }
  } catch
  {
    $errMsg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Unexpected ERROR: $_"
    Add-Content $ErrorLogFile $errMsg
    Write-Host $errMsg -ForegroundColor Red
  }

  Start-Sleep -Seconds $IntervalSeconds
}

