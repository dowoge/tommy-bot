@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "ROOT_DIR=%CD%"
set "DEPS_DIR=%ROOT_DIR%\deps"
set "LUVIT_EXE=%ROOT_DIR%\exes\luvit.exe"
set "MAIN_FILE=%ROOT_DIR%\src\main.lua"
set "INSTALL_SCRIPT=%ROOT_DIR%\install_discordia.bat"

echo Starting from "%ROOT_DIR%"

if not exist "%LUVIT_EXE%" (
    echo ERROR: Missing Luvit executable at "%LUVIT_EXE%"
    exit /b 1
)

if not exist "%MAIN_FILE%" (
    echo ERROR: Missing entrypoint at "%MAIN_FILE%"
    exit /b 1
)

set "NEEDS_INSTALL="
if not exist "%DEPS_DIR%\discordia\" set "NEEDS_INSTALL=1"
if not exist "%DEPS_DIR%\discordia-slash\" set "NEEDS_INSTALL=1"
if not exist "%DEPS_DIR%\discordia-interactions\" set "NEEDS_INSTALL=1"

if defined NEEDS_INSTALL (
    echo Dependencies missing. Running installer...

    where git >nul 2>nul
    if errorlevel 1 (
        echo ERROR: git is not installed or not available on PATH
        exit /b 1
    )

    if not exist "%INSTALL_SCRIPT%" (
        echo ERROR: Missing installer script at "%INSTALL_SCRIPT%"
        exit /b 1
    )

    call "%INSTALL_SCRIPT%"
    if errorlevel 1 (
        echo ERROR: Dependency installation failed
        exit /b 1
    )
) else (
    echo Dependencies found
)

echo Launching bot...
"%LUVIT_EXE%" "%MAIN_FILE%"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo Bot exited with code %EXIT_CODE%
)

exit /b %EXIT_CODE%