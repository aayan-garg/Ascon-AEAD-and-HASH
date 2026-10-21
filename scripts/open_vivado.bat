@echo off
setlocal
set VIVADO_BIN=C:\Xilinx\2025.1\Vivado\bin\vivado.bat
cd /d "%~dp0\.."
set XPR_FILE=%CD%\vivado_proj\ascon_soc.xpr
echo Opening %XPR_FILE% in Vivado...
start "" cmd /c "%VIVADO_BIN% %XPR_FILE%"
