@echo off
setlocal
cd /d "%~dp0..\.."
cls
echo.
echo   ============================================================
echo     A Writing  -  full maintenance run
echo   ============================================================
echo.
echo     1  Rename-Folders      number.CamelCase folder names
echo     2  Reorganize-Papers   files into slots, rebuild the index
echo     3  Rename-Files        filename convention, media folders
echo     4  Repair-Encoding     undo double-encoded characters
echo     5  Sync-Masters        retire stale derivatives
echo     6  Convert-Documents   a .qmd and a .docx for every paper
echo     7  Run-Website         PDFs, publish, render, link check
echo     8  Tidy-Scripts        spring clean of 9.Scripts
echo.
echo   Step 7 drives Word once per document with a 3 minute limit each,
echo   so a document Word cannot open is skipped, not waited on.
echo.
echo   Step 8 sends anything outside the five-folder layout to the
echo   Recycle Bin. Nothing is lost that is not recoverable there.
echo.
echo   The log lands in 9.Scripts\Reports\.
echo.
set /p go=Type Y then Enter to run, anything else to cancel: 
if /i not "%go%"=="Y" goto cancel
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\Run-All.ps1" -Apply <NUL
echo.
pause
goto done
:cancel
echo.
echo Cancelled. Nothing was changed.
pause
:done
endlocal
