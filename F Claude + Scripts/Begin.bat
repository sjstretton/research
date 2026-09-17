@echo off
:: Personal folder
:: cd /d "C:\Users\sjstr\Documents\OneDrive\Documents\A Research"

:: Work folder
:: cd /d "C:\Users\wb547395\OneDrive\Documents\A Research"

echo Pulling latest from github.com/sjstretton/research...
git pull --rebase --autostash
if errorlevel 1 (
    echo.
    echo Pull failed. You may be offline or have a conflict.
) else (
    echo.
    echo Up to date.
)
pause