@echo off
setlocal
echo ================================================================================
echo ZYBO Z7-10 JTAG PROGRAMMING LAUNCHER
echo ================================================================================

set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin\vivado.bat

if not exist "%VIVADO_BIN%" (
    echo [ERROR] Vivado not found at %VIVADO_BIN%
    pause
    exit /b 1
)

cd /d "%~dp0\.."

echo Running Vivado Hardware Manager to flash build\top_bringup.bit...
call "%VIVADO_BIN%" -mode batch -nojournal -nolog -source scripts\program_board.tcl

if %ERRORLEVEL% equ 0 (
    echo.
    echo [SUCCESS] Programming finished! Check your board for walking LEDs.
) else (
    echo.
    echo [NOTE] If programming failed:
    echo   1. Check power switch SW4 is slid to ON.
    echo   2. Check jumper JP6 power source is set to USB.
    echo   3. Check jumper JP5 boot mode is set to JTAG.
)

pause
