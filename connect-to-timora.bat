@echo off
REM Batch file to run timora.ps1 -upload_fresh

REM Get the folder of this batch file
set SCRIPT_DIR=%~dp0

REM Run PowerShell in the same window
powershell -NoExit -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%timora.ps1" -upload_fresh
