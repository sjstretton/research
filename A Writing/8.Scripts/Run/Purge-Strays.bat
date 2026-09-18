@echo off
setlocal
cd /d "%~dp0..\.."
cls
echo.
echo   ============================================================
echo     A Writing  -  purge strays
echo   ============================================================
echo.
echo   Where there are two of something, one is kept and the rest go.
echo   This is deliberately aggressive.
echo.
echo     1  scripts and logs that ended up inside the papers
echo     2  files in 2.Source that belong to some other document
echo     3  the same file byte-for-byte in two places in one paper
echo     4  two names for one document - the losing set goes whole
echo     5  loose files at a paper root, moved into their slot
echo     6  folders left empty afterwards
echo.
echo   Everything removed goes to the Recycle Bin and stays there
echo   until you empty it. Nothing is overwritten.
echo.
echo   Close Word first - an open file cannot be moved.
echo.
pause
echo.
echo   ---------------- PREVIEW: nothing is changed ----------------
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Purge-Strays.ps1" <NUL
echo.
echo   The same list is in the scripts folder's Reports\_PurgeReport-preview.txt
echo.
set /p go=Type PURGE then Enter to do it, anything else to stop: 
if /i not "%go%"=="PURGE" goto stop
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Purge-Strays.ps1" -Apply <NUL
echo.
pause
goto done
:stop
echo.
echo Nothing changed.
pause
:done
endlocal
