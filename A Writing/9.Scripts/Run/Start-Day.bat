@echo off
cd /d "%~dp0..\.."
cls
echo.
echo   ============================================================
echo     A Writing  -  start of day
echo   ============================================================
echo.
echo   Brings this copy up to date with GitHub before you touch
echo   anything, so today's work is not written over yesterday's
echo   from another machine.
echo.
echo     fetch, then pull with --rebase and --autostash
echo.
echo   Nothing is committed or pushed here. That is End-Day.bat.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\Start-Day.ps1" -NoPause <NUL
echo.
pause
