@echo off
setlocal

set "ROOT=%~dp0.."
set "SIM_BUILD=%ROOT%\sim_build"
set "XSIM=C:\Xilinx\2025.1\Vivado\bin\xsim.bat"

if not "%~1"=="" goto :HAS_ARG

echo ==============================================================================
echo Ascon Vivado Waveform Viewer Launcher
echo ==============================================================================
echo Usage: open_wave.bat ^<simulation_name^>
echo.
echo Available simulations:
echo   1. tb_sbox_equiv       - Exhaustive 32-vector S-Box Equivalence [Milestone 1]
echo   2. tb_round_core       - Single Combinational Round Datapath [Milestone 1]
echo   3. tb_permutation_1r   - Baseline 1-Round/Cycle Permutation [Milestone 1]
echo   4. tb_permutation_2r   - Unrolled 2-Rounds/Cycle Permutation [Milestone 1]
echo   5. tb_permutation_half - Pipelined 1/2-Round/Cycle Permutation [Milestone 1]
echo   6. tb_aead             - Ascon-AEAD128 Encrypt ^& Decrypt KATs [Milestone 2]
echo   7. tb_hash             - Ascon-Hash256 Official NIST KATs [Milestone 2]
echo   8. tb_security_gate    - Plaintext Shadow Buffer Isolation [Milestone 2]
echo   9. tb_axil_regs        - AXI4-Lite Register File BFM [Milestone 3]
echo  10. tb_dma              - Streaming DMA Boundary Tests [Milestone 3]
echo  11. tb_soc_ascon        - PicoRV32 Bare-Metal Hash Firmware [Milestone 3]
echo  12. tb_soc_dma          - Full SoC DMA Bulk Hash Execution [Milestone 3]
echo  13. tb_secure_boot      - Complete 9-Case Secure Boot Matrix [Milestone 4]
echo ==============================================================================
echo Example: open_wave.bat tb_sbox_equiv
exit /b 0

:HAS_ARG
set "SIM_NAME=%~1"
REM Strip _sim suffix if provided
if "%SIM_NAME:~-4%"=="_sim" (
    set "SNAPSHOT=%SIM_NAME%"
) else (
    set "SNAPSHOT=%SIM_NAME%_sim"
)

cd /d "%SIM_BUILD%"
if not exist "%SNAPSHOT%.wdb" (
    echo [ERROR] Simulation database "%SNAPSHOT%.wdb" not found in sim_build.
    exit /b 1
)

echo [LAUNCHING] Vivado Simulator GUI for %SNAPSHOT%...
start "" "%XSIM%" %SNAPSHOT% -gui
