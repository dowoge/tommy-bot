@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

set "DEPS_DIR=%CD%\deps"
set "LIT_EXE=%CD%\exes\lit.exe"

echo tommy-bot dependency installer

if not exist "%DEPS_DIR%" (
    echo Creating deps directory...
    mkdir "%DEPS_DIR%"
    if errorlevel 1 (
        echo Failed to create deps directory.
        exit /b 1
    )
)

if not exist "%LIT_EXE%" (
    echo Missing lit executable: "%LIT_EXE%"
    exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo Missing git in PATH.
    echo Install Git for Windows and make sure the git command is available in Command Prompt.
    exit /b 1
)

echo Installing/updating discordia with lit...
"%LIT_EXE%" install SinisterRectus/discordia
if errorlevel 1 (
    echo Failed to install discordia.
    exit /b 1
)

call :ensure_git_repo "https://github.com/dowoge/discordia-slash.git" "%DEPS_DIR%\discordia-slash"
if errorlevel 1 exit /b 1

call :ensure_git_repo "https://github.com/dowoge/discordia-interactions.git" "%DEPS_DIR%\discordia-interactions"
if errorlevel 1 exit /b 1

echo Dependencies are ready.
exit /b 0

:ensure_git_repo
set "REPO_URL=%~1"
set "TARGET_DIR=%~2"

if exist "%TARGET_DIR%\.git" (
    echo Updating %TARGET_DIR%...
    git -C "%TARGET_DIR%" pull --ff-only
    if errorlevel 1 (
        echo Failed to update %TARGET_DIR%.
        exit /b 1
    )
    exit /b 0
)

if exist "%TARGET_DIR%" (
    echo Removing invalid existing directory: %TARGET_DIR%
    rmdir /s /q "%TARGET_DIR%"
    if exist "%TARGET_DIR%" (
        echo Failed to remove %TARGET_DIR%.
        exit /b 1
    )
)

echo Cloning %REPO_URL% into %TARGET_DIR%...
git clone "%REPO_URL%" "%TARGET_DIR%"
if errorlevel 1 (
    echo Failed to clone %REPO_URL%.
    exit /b 1
)

exit /b 0