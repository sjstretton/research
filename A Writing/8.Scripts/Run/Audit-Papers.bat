@echo off
cd /d "%~dp0..\.."
cls
echo.
echo   Audit of the paper folders. It reads and reports; it changes nothing.
echo.
echo     A  the same file in more than one place
echo     B  two of a thing in one paper folder
echo     C  files at a paper root that are not the master
echo     D  scripts and logs that ended up inside the papers
echo.
echo   The list goes to 9.Scripts\Reports\_AuditReport.txt and .csv
echo.
pause
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Steps\Audit-Papers.ps1" <NUL
echo.
pause
