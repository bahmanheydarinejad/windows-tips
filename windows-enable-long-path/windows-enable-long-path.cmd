@echo off
:: Check for admin rights
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Apply registry change
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" ^
/v LongPathsEnabled /t REG_DWORD /d 1 /f

echo.
echo Long Path has been enabled successfully.
echo.

:: Restart prompt
set /p restart=Do you want to restart now? (Y/N): 

if /I "%restart%"=="Y" shutdown /r /t 0

echo Restart skipped.
pause
