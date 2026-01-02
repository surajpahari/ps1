REM Description: Batch file to run the PowerShell script to connect to Timora
REM Replace the file name with your actual PowerShell script file name if different
@echo off
start powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\RTS Timer 70\Desktop\ps1-main\ps1-main\timora.ps1" --connect
