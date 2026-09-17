@echo off
setlocal
cd /d "%~dp0..\.."
cls
echo.
echo   ============================================================
echo     A Writing  -  the long run
echo   ============================================================
echo.
echo   Master-All.bat with the three structural steps put back:
echo.
echo     Reorganize-Papers   files into the standard slots
echo     Rename-Files        filename convention, media folders
echo     Repair-Encoding     undo double-encoded characters
echo.
echo   Worth doing after importing a batch of new material, and not
echo   otherwise - on a settled tree these walk every file to do
echo   nothing.
echo.
set /p go=Type Y then Enter to run, anything else to cancel: 
if /i not "%go%"=="Y" goto cancel
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\Run-All.ps1" -Apply -Full <NUL
echo.
pause
goto done
:cancel
echo.
echo Cancelled. Nothing was changed.
pause
:done
endlocal
