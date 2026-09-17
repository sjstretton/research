@echo off
cd /d "%~dp0..\.."
cls
echo.
echo Spring clean of 9.Scripts. It lists what it would remove and asks
echo before doing anything. Removed items go to the Recycle Bin.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\Tidy-Scripts.ps1"
