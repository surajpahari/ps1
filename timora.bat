@echo off
:: =============================================================================
:: timora.bat — Thin Windows Command Line wrapper for Timora script
:: Usage:
::   timora --check
::   timora --setup
::   timora --clearlog
:: =============================================================================

SET "SCRIPT_DIR=%~dp0"
SET "TIMORA=%SCRIPT_DIR%timora.ps1"

IF NOT EXIST "%TIMORA%" (
    echo [ERROR] timora.ps1 not found in %SCRIPT_DIR%
    exit /b 1
)

IF "%~1"=="" GOTO HELP
IF "%~1"=="--check" GOTO CHECK
IF "%~1"=="--setup" GOTO SETUP
IF "%~1"=="--clearlog" GOTO CLEARLOG
IF "%~1"=="--connect" GOTO CONNECT
IF "%~1"=="--fresh" GOTO FRESH

:HELP
powershell -NoProfile -ExecutionPolicy Bypass -File "%TIMORA%"
exit /b 0

:CHECK
powershell -NoProfile -ExecutionPolicy Bypass -File "%TIMORA%" -check
exit /b %ERRORLEVEL%

:SETUP
powershell -NoProfile -ExecutionPolicy Bypass -File "%TIMORA%" -setup
exit /b %ERRORLEVEL%

:CLEARLOG
powershell -NoProfile -ExecutionPolicy Bypass -File "%TIMORA%" -clearlog
exit /b %ERRORLEVEL%

:CONNECT
powershell -NoProfile -ExecutionPolicy Bypass -File "%TIMORA%" -connect
exit /b %ERRORLEVEL%

:FRESH
powershell -NoProfile -ExecutionPolicy Bypass -File "%TIMORA%" -fresh
exit /b %ERRORLEVEL%
