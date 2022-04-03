@echo off
if exist deps\ (
    echo Dependencies found
) else (
    echo Dependencies not found
    echo Installing dependencies...
    timeout /t 1 /nobreak > NUL
    call install_discordia.bat
)
.\exes\luvit .\src\main.lua