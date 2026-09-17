@echo off
cd /d "%~dp0..\.."
cls
echo.
echo   Two folders at the root where there should be one - "0. Overview"
echo   beside "0.Overview", say. It checks every file in the one with the
echo   space against the other, and only sends it to the Recycle Bin if
echo   nothing in it is unique.
echo.
echo   A no-op when there are no twins.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Remove-TwinFolders.ps1" <NUL
echo.
set /p go=Type Y then Enter to apply, anything else to stop:
if /i not "%go%"=="Y" goto stop
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Remove-TwinFolders.ps1" -Apply <NUL
echo.
pause
goto :eof
:stop
echo.
echo Nothing changed.
pause
