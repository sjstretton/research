@echo off
cd /d "%~dp0..\.."
cls
echo.
echo   Replace each .0 overview folder with the single Word document
echo   that now sits at the top of its section. The tree is searched,
echo   so renaming or renumbering a section changes nothing.
echo.
echo   A folder is only removed once its replacement file is in place.
echo   Removed folders go to the Recycle Bin. Addresses do not change.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Flatten-Overviews.ps1" <NUL
echo.
set /p go=Type Y then Enter to apply, anything else to stop: 
if /i not "%go%"=="Y" goto stop
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Flatten-Overviews.ps1" -Apply <NUL
echo.
pause
goto :eof
:stop
echo.
echo Nothing changed.
pause
