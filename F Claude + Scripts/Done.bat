@echo off
:: Personal folder
:: cd /d "C:\Users\sjstr\Documents\OneDrive\Documents\A Research"

:: Work folder
:: cd /d "C:\Users\wb547395\OneDrive\Documents\A Research"

git add -A
git diff --cached --quiet
if errorlevel 1 (
    set /p msg=Commit message ^(Enter for default^): 
    call :commit
) else (
    echo No new changes to commit.
)
echo.
echo Pushing...
git push
if errorlevel 1 (
    echo.
    echo Push failed. Your work is committed locally. Run done.bat again when online.
) else (
    echo.
    echo Done. Everything is on GitHub.
)
pause
exit /b

:commit
if "%msg%"=="" set msg=Work session %date% %time:~0,5%
git commit -m "%msg%"
exit /b