# Timora

> A lightweight PowerShell tool that tails RFID timing files and syncs new records to the Racepatro API in real time.

---

## Requirements

- Windows with PowerShell 5.1+ (or PowerShell 7+)
- Network access to your Racepatro instance
- A valid device bearer token

---

## Installation

```powershell
# 1. Clone the repository
git clone https://github.com/your-org/timora.git
cd timora

# 2. Run the setup wizard
.\timora.ps1 -setup
```

The setup wizard will prompt you for:

| Field | Description | Example |
|---|---|---|
| **RaceDir** | Path to the timing files folder, relative to your home directory | `Documents/timingfiles` |
| **Interval** | How often (seconds) to check for new data | `5` |
| **Prefix** | Device IP prefix used in the filename | `192.168.1.01` |
| **Token** | Your Racepatro bearer token (input is masked) | `abc123...` |

Config is saved to `config.json`. The token is stored in plain text — **do not commit `config.json` to version control** (it is already in `.gitignore`).

---

## Commands

| Command | Description |
|---|---|
| `.\timora.ps1 -setup` | Run the interactive setup wizard |
| `.\timora.ps1 -connect` | Authenticate and start the RFID sync loop |
| `.\timora.ps1 -status` | Show current config, race file status, and log sizes |
| `.\timora.ps1 -clearlog` | Clear the log and error log files |

---

## Usage

### First time

```powershell
.\timora.ps1 -setup
```

### Start syncing

```powershell
.\timora.ps1 -connect
```

Timora will:
1. Authenticate with the Racepatro API
2. Locate today's timing file (`<RaceDir>/<Prefix>_<yyyyMMdd>.txt`)
3. Tail the file, sending any new lines to the API at the configured interval
4. Track progress in `info/state.txt` so a restart picks up where it left off

### Check status

```powershell
.\timora.ps1 -status
```

### Clear logs

```powershell
.\timora.ps1 -clearlog
```

---

## File Structure

```
timora/
├── timora.ps1          # Main entry point
├── setup.ps1           # Setup wizard
├── login.ps1           # API authentication
├── connection.ps1      # RFID sync loop
├── messages.ps1        # Centralized message constants
├── config.json         # Your local config (gitignored)
├── config-example.json # Example config for reference
└── info/
    ├── state.txt       # Byte offset of last successful sync
    ├── log.txt         # Successful send log
    └── error.txt       # Error log
```

---

## How the Sync Works

The timing software writes RFID reads as lines to a `.txt` file. Timora reads only **new bytes** since the last run (tracked via `info/state.txt`), sends them to the API, then advances the offset. This means:

- No duplicate sends on restart
- No data loss — partial lines at the end of a read are held until the next loop
- The timing file is opened in read-share mode so the timing software is never blocked

---

## Running as a Scheduled Task (optional)

To start Timora automatically on login, open Task Scheduler and create a task with:

- **Program:** `powershell.exe`
- **Arguments:** `-NoProfile -ExecutionPolicy Bypass -File "C:\path\to\timora\timora.ps1" -connect`
- **Trigger:** At log on

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Config not found` | Run `.\timora.ps1 -setup` |
| `Race file NOT FOUND` | Check that the timing software has created today's file and `RaceDir`/`Prefix` match |
| `Unauthorized (401)` | Token is invalid or expired — run `.\timora.ps1 -setup` and re-enter the token |
| Sync not advancing | Run `.\timora.ps1 -status` to check the offset; if stuck, delete `info/state.txt` and reconnect |

---

## Contributing

Pull requests welcome. Please keep `config.json` out of commits.
