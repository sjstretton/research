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
echo     2  Sync-Masters        retire stale derivatives
echo     3  Convert-Documents   a .qmd and a .docx for every paper
echo     4  Run-Website         publish, render, link check
echo     5  Tidy-Scripts        spring clean of the scripts folder
echo.
echo   Reorganize-Papers, Rename-Files and Repair-Encoding are no
echo   longer in the daily run. Use Organise.bat when you have just
echo   imported a batch of new material.
echo.
echo   Step 5 sends anything outside the five-folder layout to the
echo   Recycle Bin. Nothing is lost that is not recoverable there.
echo.
echo   The log lands in the scripts folder's Reports\.
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
