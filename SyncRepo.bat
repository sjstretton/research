@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  SyncRepo.bat  -  fiscal-climate-ai-tools
REM
REM  Lives in the ROOT of the repo it syncs. Reads RepoDirectory.csv
REM  from the same folder, pulls the latest main, then stages, commits
REM  and pushes local changes back to main.
REM
REM  CSV columns: FolderName,RepoName,Pull,Add-Commit-Push
REM
REM  FolderName is "." because this script sits inside the repo rather
REM  than beside a set of repo folders. Do NOT leave it truly empty:
REM  cmd's "for /f" collapses leading delimiters, so an empty first
REM  field shifts every column and the URL lands in FolderName.
REM  "." , "" and a real folder name are all handled.
REM
REM  Usage:
REM    SyncAllRepos.bat                    prompt for the commit message
REM    SyncAllRepos.bat "fixed the join"   use that message, no prompt
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "CSV_FILE=%SCRIPT_DIR%RepoDirectory.csv"
set "ARG_MSG=%~1"

if not exist "%CSV_FILE%" (
    echo ERROR: Could not find RepoDirectory.csv next to this script.
    echo Expected at: %CSV_FILE%
    pause
    exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo ERROR: git is not on PATH.
    pause
    exit /b 1
)

echo ============================================================
echo  Repo Sync - Pull / Add / Commit / Push
echo ============================================================
if defined ARG_MSG (
    echo  Commit message: "%ARG_MSG%"
) else (
    echo  You will be prompted for a commit message if there is
    echo  anything to commit.
)
echo ============================================================
echo.

for /f "usebackq skip=1 tokens=1-4 delims=," %%A in ("%CSV_FILE%") do (
    call :ProcessRepo "%%A" "%%B" "%%C" "%%D"
)

echo.
echo ============================================================
echo  Done.
echo ============================================================
pause
exit /b 0

REM ------------------------------------------------------------
:ProcessRepo
set "FOLDER=%~1"
set "REPO_URL=%~2"
set "PULL_FLAG=%~3"
set "PUSH_FLAG=%~4"

REM "." or "" both mean "the folder this script is in"
if "%FOLDER%"=="." set "FOLDER="
if "%FOLDER%"==""  (
    set "REPO_PATH=%SCRIPT_DIR:~0,-1%"
    set "LABEL=this repo"
) else (
    set "REPO_PATH=%SCRIPT_DIR%%FOLDER%"
    set "LABEL=%FOLDER%"
)

echo ------------------------------------------------------------
echo Repo: !LABEL!  (%REPO_URL%)

if not exist "!REPO_PATH!" (
    echo   [SKIP] Folder not found: !REPO_PATH!
    goto :eof
)
if not exist "!REPO_PATH!\.git" (
    echo   [SKIP] Not a git repository: !REPO_PATH!
    goto :eof
)

pushd "!REPO_PATH!"

for /f "delims=" %%G in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "BRANCH=%%G"
echo   Current branch: !BRANCH!

git rev-parse --verify main >nul 2>&1
if !errorlevel! equ 0 (
    if /i not "!BRANCH!"=="main" (
        echo   Switching to main...
        git checkout main
        if !errorlevel! neq 0 (
            echo   [ERROR] Could not switch to main - commit or stash your changes first.
            popd
            goto :eof
        )
    )
) else (
    echo   [WARN] No local "main" branch found, staying on !BRANCH!.
)

if /i "%PULL_FLAG%"=="Y" (
    echo   Pulling latest changes...
    git pull
    if !errorlevel! neq 0 (
        echo   [ERROR] git pull failed. Skipping commit/push.
        popd
        goto :eof
    )
)

if /i "%PUSH_FLAG%"=="Y" (
    echo   Staging all changes...
    git add -A

    git diff --cached --quiet
    if !errorlevel! equ 0 (
        echo   No changes to commit.
    ) else (
        echo.
        echo   Changes to be committed:
        git --no-pager diff --cached --stat
        echo.

        set "COMMIT_MSG=%ARG_MSG%"
        if not defined COMMIT_MSG set /p COMMIT_MSG="  Commit message: "
        if "!COMMIT_MSG!"=="" (
            echo   [SKIP] No commit message entered - nothing committed.
            popd
            goto :eof
        )

        echo   Committing...
        git commit -m "!COMMIT_MSG!"
        if !errorlevel! neq 0 (
            echo   [ERROR] git commit failed.
            popd
            goto :eof
        )

        echo   Pushing to main...
        git push origin HEAD:main
        if !errorlevel! neq 0 (
            echo   [ERROR] git push failed.
            popd
            goto :eof
        )
        echo   Pushed.
    )
)

popd
goto :eof
