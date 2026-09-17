@echo off
setlocal
cd /d "%~dp0..\.."
cls
echo.
echo   ============================================================
echo     A Writing  -  end of day
echo   ============================================================
echo.
echo     1  Run-All        folder names, stale derivatives, a .qmd and
echo                       a .docx for every paper, publish, render,
echo                       link check, tidy
echo     2  git            commit what changed, pull --rebase, push
echo     3  FTP            upload 7.Website\_site to the web server
echo.
echo   The order matters: the site is rebuilt before it is committed,
echo   and committed before it goes live.
echo.
echo   A git conflict stops the push and tells you what to do. Nothing
echo   is ever force-pushed.
echo.
echo   Close Word first.
echo.
set /p go=Type Y then Enter to run, anything else to cancel: 
if /i not "%go%"=="Y" goto cancel
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\End-Day.ps1" -NoPause <NUL
echo.
pause
goto done
:cancel
echo.
echo Cancelled. Nothing was changed.
pause
:done
endlocal
