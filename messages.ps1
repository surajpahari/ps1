# =============================================================================
# messages.ps1 - Centralized message constants for Timora
# Usage: . (Join-Path $PSScriptRoot "messages.ps1")
#        Then call: $MSG = Get-TinoraMessages
# =============================================================================

function Get-TinoraMessages {
    return @{
        # General
        CONNECTING           = "Connecting to race app..."
        STARTING_SYNC        = "Starting RFID sync loop..."

        # Connection / Login
        CONNECTED_DEVICE     = "Connected device '{0}' (status: {1})"
        EVENT                = "Event: {0}"
        CHECKPOINT           = "Checkpoint: {0} at {1}"
        INVALID_RESPONSE     = "Connection error: Unexpected response format from server."
        LOGIN_FAILED         = "Login failed: {0}"

        # Upload / Sync flow
        RUNNING_CONNECT      = "Running connect..."
        RUNNING_FRESH        = "Running fresh connect - clearing state and logs..."
        RUNNING_UPLOAD       = "Running upload..."
        RUNNING_UPLOAD_FRESH = "Running upload fresh..."
        SKIP_UPLOAD          = "Skipping upload - login failed."

        # State file
        STATE_CLEARED        = "State file cleared to 0."
        STATE_INITIALIZED    = "State file initialized at 0."
        STATE_UPDATED        = "State file updated to {0}."

        # Data reading
        NEW_DATA_FOUND       = "New data found, reading..."
        NO_NEW_DATA          = "No new data."
        TOTAL_LINES          = "Total lines read: {0}"
        PARTIAL_LINE         = "Partial line saved for next loop: {0}"
        SENDING_LINES        = "Sending {0} line(s) to backend..."
        SENT_RECORDS         = "{0} | Sent {1} record(s)"
        LAST_POSITION        = "Last position: {0} | File size: {1}"

        # File / Path
        RACE_PATH_MISSING    = "Race file '{0}' does not exist. Has the timing device written a file yet?"

        # Errors - HTTP
        ERR_UNAUTHORIZED     = "{0} | {1} line(s) | ERROR: Unauthorized (401) - token may be invalid or expired."
        ERR_HTTP             = "{0} | {1} line(s) | ERROR: HTTP {2}"
        ERR_LOGIN_401        = "Unauthorized (401). Token may be invalid or expired."
        ERR_LOGIN_HTTP       = "HTTP {0} error during login."

        # Errors - General
        ERR_UNEXPECTED       = "{0} | Unexpected error: {1}"
        ERR_SEND             = "{0} | {1} line(s) | ERROR: {2}"

        # Setup
        SETUP_WELCOME        = "=== Timora Setup Wizard ==="
        SETUP_DONE           = "Config saved successfully to config.json"
        SETUP_RACEDIR        = "Enter RaceDir (relative to HOME, e.g. Documents/timingfiles): "
        SETUP_INTERVAL       = "Enter sync interval in seconds (default 5): "
        SETUP_PREFIX         = "Enter device prefix (e.g. 192.168.1.01): "
        SETUP_TOKEN          = "Enter your bearer token: "
        SETUP_INVALID_INT    = "Invalid number, using default: {0}s"

        # Status
        STATUS_CONFIG_OK     = "Config:       OK"
        STATUS_CONFIG_MISS   = "Config:       MISSING - run: .\timora.ps1 -setup"
        STATUS_STATE         = "Sync offset:  {0} bytes"
        STATUS_LOGSIZE       = "Log size:     {0} lines"
        STATUS_ERRSIZE       = "Error log:    {0} lines"
        STATUS_RACEFILE_OK   = "Race file:    {0}"
        STATUS_RACEFILE_MISS = "Race file:    NOT FOUND ({0})"

        # Clear log
        CLEARLOG_DONE        = "Logs cleared."
        CLEARLOG_NOTHING     = "No log files found to clear."
    }
}
