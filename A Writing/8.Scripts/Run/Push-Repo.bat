@echo off
cd /d "%~dp0..\.."
cls
echo.
echo   Commit, pull, push - the GitHub part on its own.
echo.
echo     1  commit everything that has changed here
echo     2  pull with --rebase, so your commits sit on top of
echo        anything that came from another machine
echo     3  push
echo.
echo   Nothing is ever force-pushed. If the pull hits a conflict it
echo   stops there and tells you what to type.
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Push-Repo.ps1" <NUL
echo.
pause
