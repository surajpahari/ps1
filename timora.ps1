param (
    [switch]$connect,
    [switch]$upload
)

$AppConnectionScript = "$HOME/rfid-test/data/login.ps1"
$RaceUploadScript = "$HOME/rfid-test/data/timora-connection.ps1"


if ($connect) {
    Write-Host "Running connect..."
    & $AppConnectionScript
}

if ($upload) {
    Write-Host "Running upload..."
    & $AppConnectionScript
    if ($LASTEXITCODE -eq 0) {
        & $RaceUploadScript
    } else {
        Write-Host "Skipping race upload because login failed." -ForegroundColor Red
    }
}

