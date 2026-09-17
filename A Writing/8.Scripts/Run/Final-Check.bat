@echo off
cd /d "%~dp0..\.."
cls
echo.
echo   ============================================================
echo     A Writing  -  final check
echo   ============================================================
echo.
echo   Reads the tree, the site, the scripts folder, the tools and
echo   the repository, and says whether anything will break. It
echo   changes nothing.
echo.
echo     OK       fine
echo     NOTE     worth knowing
echo     PROBLEM  End-Day.bat will not get through this
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Verify-Setup.ps1" <NUL
echo.
echo   The same list is in 9.Scripts\Reports\_VerifyReport.txt
echo.
pause
