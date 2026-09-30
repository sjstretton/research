@echo off
cd /d "%~dp0..\.."
cls
echo.
echo Full workflow, PREVIEW only. Nothing is changed.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\Run-All.ps1" <NUL
echo.
pause
