@echo off
REM ==============================================================================
REM Open Vivado Graphical Waveform Viewer for PicoRV32 Bring-Up Simulation
REM ==============================================================================

set "SIM_BUILD=%~dp0..\sim_build"
cd /d "%SIM_BUILD%"

echo Launching Vivado Simulator Graphical Waveform Viewer...
call "C:\Xilinx\2025.1\Vivado\bin\xsim.bat" tb_picorv32_bringup_sim -gui
