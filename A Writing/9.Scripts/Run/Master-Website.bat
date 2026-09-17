@echo off
setlocal
cd /d "%~dp0..\.."
cls
echo.
echo   ============================================================
echo     A Writing  -  PDFs and website
echo   ============================================================
echo.
echo     1  Build-Pdfs      a PDF for every paper with a master .docx
echo     2  Publish-Site    copy into 7.Website\papers, write
echo                        0.Overview\ResearchOverview.docx, quarto render,
echo                        then check every link
echo.
echo   Each document is converted in its own process with a 3 minute
echo   limit. One that Word cannot open is killed, logged and skipped -
echo   the run does not stop. Word already open is left alone.
echo.
echo   A PDF newer than its .docx is not rebuilt, so re-running is quick
echo   and an interrupted run picks up where it left off.
echo.
echo   Reports: 9.Scripts\Reports\_PdfReport.txt and _SiteReport.txt
echo.
set /p go=Type Y then Enter to run, anything else to cancel: 
if /i not "%go%"=="Y" goto cancel
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\Engine\Run-Website.ps1" -Apply <NUL
echo.
pause
goto done
:cancel
echo.
echo Cancelled. Nothing was changed.
pause
:done
endlocal
