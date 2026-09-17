@echo off
cd /d "%~dp0..\.."
cls
echo.
echo PDFs and website, PREVIEW only. Nothing is changed.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\Run-Website.ps1" <NUL
echo.
pause
