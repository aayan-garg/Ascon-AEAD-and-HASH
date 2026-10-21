@echo off
setlocal
echo ================================================================================
echo OPENING ASCON SOC PROJECT IN VIVADO GUI
echo ================================================================================

set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin\vivado.bat

cd /d "%~dp0\.."

set XPR_FILE=%CD%\vivado_proj\ascon_soc.xpr

if not exist "%XPR_FILE%" (
    echo Generating Vivado Project from sources...
    call "%VIVADO_BIN%" -mode batch -nojournal -nolog -source scripts\create_vivado_project.tcl
)

echo Launching Vivado GUI with %XPR_FILE%...
start "" "%VIVADO_BIN%" -mode gui "%XPR_FILE%"
