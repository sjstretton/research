@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  SyncRepo.bat
REM
REM  Generic: drop an identical copy of this file into the ROOT of
REM  every repo. It works out which repo it is in by asking git for
REM  the "origin" remote URL (git remote get-url origin), so nothing
REM  in the file needs editing per repo.
REM
REM  Double-click it to switch to main, pull the latest changes, then
REM  stage, commit and push your local changes back to main.
REM
REM  Usage:
REM    SyncRepo.bat                    prompt for the commit message
REM    SyncRepo.bat "fixed the join"   use that message, no prompt
REM
REM  To sync ALL your repos in one go, use SyncAllRepos.bat, which
REM  sits one level up in your Repos folder (C:\Users\<username>\Repos)
REM  and reads the list of repos from RepoDirectory.csv next to it.
REM ============================================================

set "REPO_PATH=%~dp0"
set "REPO_PATH=%REPO_PATH:~0,-1%"
set "ARG_MSG=%~1"

where git >nul 2>&1
if errorlevel 1 (
    echo ERROR: git is not on PATH.
    pause
    exit /b 1
)

if not exist "%REPO_PATH%\.git" (
    echo ERROR: Not a git repository: %REPO_PATH%
    echo This script must sit in the root folder of the repo it syncs.
    pause
    exit /b 1
)

REM Detect the GitHub address of this repo from its "origin" remote
set "REPO_URL="
for /f "delims=" %%U in ('git -C "%REPO_PATH%" remote get-url origin 2^>nul') do set "REPO_URL=%%U"
if not defined REPO_URL (
    echo ERROR: This repo has no "origin" remote, so there is nothing to pull from or push to.
    echo Clone it from GitHub, or add a remote with:  git remote add origin ^<url^>
    pause
    exit /b 1
)
if /i "%REPO_URL:~-4%"==".git" set "REPO_URL=%REPO_URL:~0,-4%"

echo ============================================================
echo  Repo Sync - Pull / Add / Commit / Push
echo ============================================================
echo  Repo:   %REPO_URL%
echo  Folder: %REPO_PATH%
if defined ARG_MSG (
    echo  Commit message: "%ARG_MSG%"
) else (
    echo  You will be prompted for a commit message if there is
    echo  anything to commit.
)
echo ============================================================
echo.

pushd "%REPO_PATH%"

for /f "delims=" %%G in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "BRANCH=%%G"
echo   Current branch: !BRANCH!

git rev-parse --verify main >nul 2>&1
if !errorlevel! equ 0 (
    if /i not "!BRANCH!"=="main" (
        echo   Switching to main...
        git checkout main
        if !errorlevel! neq 0 (
            echo   [ERROR] Could not switch to main - commit or stash your changes first.
            goto :done
        )
    )
) else (
    echo   [WARN] No local "main" branch found, staying on !BRANCH!.
)

echo   Pulling latest changes...
git pull
if !errorlevel! neq 0 (
    echo   [ERROR] git pull failed. Skipping commit/push.
    goto :done
)

echo   Staging all changes...
git add -A

git diff --cached --quiet
if !errorlevel! equ 0 (
    echo   No changes to commit.
    goto :done
)

echo.
echo   Changes to be committed:
git --no-pager diff --cached --stat
echo.

set "COMMIT_MSG=%ARG_MSG%"
if not defined COMMIT_MSG set /p COMMIT_MSG="  Commit message: "
if "!COMMIT_MSG!"=="" (
    echo   [SKIP] No commit message entered - nothing committed.
    goto :done
)

echo   Committing...
git commit -m "!COMMIT_MSG!"
if !errorlevel! neq 0 (
    echo   [ERROR] git commit failed.
    goto :done
)

echo   Pushing to main...
git push origin HEAD:main
if !errorlevel! neq 0 (
    echo   [ERROR] git push failed.
    goto :done
)
echo   Pushed.

:done
popd
echo.
echo ============================================================
echo  Done.
echo ============================================================
pause
exit /b 0
