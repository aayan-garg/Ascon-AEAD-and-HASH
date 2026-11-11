# Repository Directory Structure

*Last updated: 2026-11-11*

All file and directory changes should preserve this documented layout. Keep `AGENTS.md` and [status.md](status.md) updated whenever significant verification or structural changes occur.

```text
Ascon-AEAD-and-HASH/
├── .gitattributes
├── .gitignore
├── .agents/                                   # Agent workspace rules and skills
├── AGENTS.md                                  # Engineering contract, status summary, and repository rules
├── README.md                                  # Top-level overview, quickstart, and verification status
│
├── board/                                     # Target FPGA constraints (Digilent Zybo Z7-10)
│   ├── zybo_z7_10.xdc                         # Physical pin constraints, 100/125 MHz clocks, LEDs/switches
│   └── timing_ooc.xdc                         # Out-of-context synthesis timing constraint (100 MHz)
│
├── docs/                                      # Design architecture, verification & evaluation docs
│   ├── decisions/                             # Architecture Decision Records (ADRs)
│   │   ├── algorithm_version.md               # NIST SP 800-232 vs submission selection
│   │   ├── paper_design_technique.md          # Literature technique mapping & synthesis tradeoffs
│   │   ├── riscv_core.md                      # PicoRV32 core selection rationale
│   │   ├── sbox_optimization.md               # ESPRESSO vs BDD vs kernel S-box optimization
│   │   └── tooling.md                         # Simulation, synthesis, and formal tool selection
│   ├── AUDIT_RESPONSE.md                      # Consolidated technical audit responses
│   ├── CHANGELOG.md                           # Chronological change and consolidation record
│   ├── architecture.md                        # System architecture, FSMs, and interfaces
│   ├── directory_structure.md                 # This file
│   ├── final_report.md                        # Comprehensive technical evaluation report
│   ├── hand_hls_derivation.md                 # Analytical timing/area/throughput derivations
│   ├── hardware_test_plan.md                  # Zybo Z7-10 bring-up & ILA hardware test plan
│   ├── register_map.md                        # AXI4-Lite SoC MMIO register map
│   ├── requirements_traceability.md           # Requirements R1-R19 traceability matrix
│   ├── research_review.md                     # Literature survey and design space analysis
│   ├── status.md                              # Current verification and hardware readiness status
│   └── threat_model.md                        # Security threat model & attack surfaces
│
├── firmware/                                  # RISC-V bare-metal boot ROM & test images
│   ├── build_firmware.py                      # Hex image builder / validator
│   ├── bootrom/
│   │   ├── secure_boot.c                      # Boot verification C reference source
│   │   ├── secure_boot.hex                    # Compiled boot image
│   │   └── trusted_manifest.h                 # Signed firmware manifest structure
│   ├── linker/
│   │   ├── app.ld                             # Application linker script
│   │   └── bringup.ld                         # Bring-up SoC linker script
│   ├── startup/
│   │   └── crt0.S                             # RISC-V startup assembly
│   └── tests/
│       ├── boot_matrix/                       # Pre-built BRAM hex images for boot cases & benchmarks
│       │   ├── bram_case1_valid.hex           # Case 1: valid signed payload image
│       │   ├── bram_case2_flipped.hex         # Case 2: corrupted payload byte
│       │   ├── bram_case3_wrong_digest.hex    # Case 3: digest mismatch
│       │   ├── bram_case4_invalid_len.hex     # Case 4: invalid payload length
│       │   ├── bram_case5_bad_magic.hex       # Case 5: invalid manifest magic
│       │   ├── bram_payload_64b.hex           # Scaling benchmark image (64 B)
│       │   ├── bram_payload_1024b.hex         # Scaling benchmark image (1024 B)
│       │   └── bram_payload_4096b.hex         # Scaling benchmark image (4096 B)
│       ├── accel_dma_test.{c,hex}
│       ├── accel_hash_test.{c,hex}
│       ├── app_payload.c
│       ├── forced_jump.{c,hex}
│       ├── gpio_toggle.{c,hex}
│       └── gpio_toggle_board.{c,hex}
│
├── formal/                                    # Formal verification artifacts
│   ├── ctl/
│   │   ├── README.md                          # NuSMV reproduction guide
│   │   ├── boot_safety_broken.smv             # Faulty model exhibiting AG(jump->hash_ok) counterexample
│   │   ├── boot_safety_corrected.smv          # Hardened model proving CTL safety & liveness
│   │   └── verify_smv.py                      # NuSMV automated runner & logger
│   └── sva/
│       └── boot_ctrl_sva.sv                   # SystemVerilog Assertions for boot_ctrl & fetch_guard
│
├── reference/                                 # Golden cryptographic reference models & NIST KATs
│   ├── ascon-c/                               # Upstream Ascon C reference suite & KAT files
│   ├── kat/                                   # NIST SP 800-232 / LWC official KAT text vectors
│   │   ├── LWC_AEAD_KAT_128_128.txt
│   │   └── LWC_HASH_KAT_128_256.txt
│   ├── pyascon/                               # Python Ascon reference implementation
│   └── run_kats.py                            # Python golden model KAT checker (2,120 vectors)
│
├── results/                                   # Committed verification, synthesis, and board logs
│   ├── regression.log                         # Master 39/39 regression suite log (KATs + CTL + XSim)
│   ├── differential_perm_serial32.log         # Serial-32 vs 1-round permutation differential test log
│   ├── board/                                 # SoC integration logs, bitstream summaries, ILA & runbook
│   │   ├── HARDWARE_RUNBOOK.md                # Zybo Z7-10 bring-up step-by-step runbook
│   │   ├── axil_integration.log               # AXI4-Lite SoC XSim log
│   │   ├── bitstream_build.log                # Vivado bitstream utilization & timing summary
│   │   ├── bitstream_build_raw.log            # Raw Vivado batch build log (top_bringup)
│   │   ├── boot_matrix/                       # Simulated boot cases (case_1..9), scaling, forced-jump logs
│   │   ├── dma_boundary.log                   # DMA boundary condition simulation log
│   │   ├── ila_traces/                        # Captured hardware ILA probe CSV files
│   │   │   ├── ila_capture_fault_injection.csv# Steady-state -trigger_now capture (SW0 fault refusal)
│   │   │   └── ila_capture_normal_boot.csv    # Steady-state -trigger_now capture (valid boot)
│   │   ├── ila_verification_report.md         # Hardware ILA bring-up report & probe map
│   │   ├── phase2_bringup.md                  # PicoRV32 bring-up summary
│   │   ├── phase6_axil_summary.md             # AXI4-Lite SoC integration summary
│   │   └── phase7_dma_summary.md              # DMA engine integration summary
│   ├── formal/                                # NuSMV CTL proofs, counterexamples & SVA status log
│   │   ├── counterexample_broken.log
│   │   ├── nuxmv/                             # Raw NuSMV 2.6.0 execution transcripts
│   │   ├── phase9_formal_summary.md
│   │   ├── proof_correct.log
│   │   └── sva/sva_boot_ctrl.log
│   ├── kat/                                   # Unit/full KAT simulation logs across S-box & round variants
│   ├── performance/                           # Parsed Vivado comparison tables
│   │   ├── comparison_table.md                # Permutation architecture variants comparison
│   │   └── engine_comparison_table.md         # Full AEAD+Hash engine variants comparison
│   ├── synthesis/                             # Vivado utilization reports & ESPRESSO raw PLA/log
│   └── timing/                                # Vivado post-synth / post-route timing reports
│
├── rtl/                                       # Synthesizable SystemVerilog / Verilog RTL
│   ├── ascon/                                 # Ascon cryptographic core, permutations, S-boxes & controllers
│   ├── bus/
│   │   └── axil_regs.sv                       # AXI4-Lite slave control/status/FIFO register file
│   ├── dma/
│   │   └── dma_master.sv                      # DMA streaming read/write controller
│   ├── soc/                                   # Secure-boot SoC subsystem & Zybo Z7-10 top wrappers
│   │   ├── boot_ctrl.sv                       # Hardware root-of-trust FSM
│   │   ├── fetch_guard.sv                     # Instruction fetch firewall
│   │   ├── picorv32.v                         # PicoRV32 RV32IMC soft CPU core
│   │   ├── top_bringup.sv                     # Core SoC top module
│   │   └── top_bringup_board.sv               # Zybo Z7-10 physical wrapper (LEDs, RGB, switches, clock)
│   └── top/                                   # Reserved top-level placeholder (.gitkeep)
│
├── scripts/                                   # Build, simulation, programming, and checker scripts
│   ├── ascon_sbox.pla                         # Reference copy of Ascon 5-bit S-box PLA truth table
│   ├── build_bitstream.tcl                    # Vivado batch script: build/top_bringup.bit
│   ├── build_bitstream_ila.tcl                # Vivado batch script: build/top_bringup_ila.bit + .ltx
│   ├── capture_ila.tcl                        # Vivado Hardware Manager ILA CSV capture script
│   ├── check_doc_links.py                     # Validates internal Markdown links across docs & results
│   ├── check_doc_numbers.py                   # Validates doc metrics match Vivado/tool logs & reports
│   ├── diagnose_jtag.tcl                      # Vivado Hardware Manager JTAG/ILA probe inspection helper
│   ├── gen_perm_vectors.py                    # Generates random permutation vectors from Python oracle
│   ├── generate_engine_table.py               # Parses engine .rpt files -> engine_comparison_table.md
│   ├── kat_to_vectors.py                      # Converts NIST KAT files -> $readmemh .mem files
│   ├── parse_synth_reports.py                 # Parses permutation .rpt files -> comparison_table.md
│   ├── program_board.bat                      # Windows launcher for program_board.tcl
│   ├── program_board.tcl                      # Programs Zybo Z7-10 xc7z010 via JTAG
│   ├── provision_image.py                     # Generates signed/corrupted BRAM hex boot images
│   ├── run_regression.{py,ps1,sh}             # Master regression suite drivers
│   ├── synth_engine_variants.tcl              # Vivado OOC synthesis for AEAD+Hash engine variants
│   └── synth_variants.tcl                     # Vivado OOC synthesis for permutation variants
│
├── tb/                                        # SystemVerilog testbenches and KAT memory vectors
│   ├── unit/                                  # Permutation, S-box, controller, gate, and full KAT TBs
│   ├── integration/                           # AXI, DMA, forced-jump, boot-matrix, payload-scaling TBs
│   ├── system/                                # Reserved system TB placeholder (.gitkeep)
│   └── vectors/                               # $readmemh binary vectors (aead_kat.mem, hash_kat.mem, perm_random_vectors.svh)
│
└── tools/
    └── sbox_opt/                              # S-box optimization toolkit (ESPRESSO, BDD, kernel)
        ├── README.md                          # ESPRESSO build & reproducibility instructions
        ├── ascon_sbox.pla                     # Ascon 5-bit S-box PLA truth table
        ├── bdd_synthesizer.py                 # Quine-McCluskey / BDD synthesizer
        ├── count_pla_literals.py              # Reproducible PLA literal counter
        ├── espresso_runner.py                 # Invokes local tools/sbox_opt/bin/espresso binary
        ├── generate_sbox_pla.py               # Generates Ascon S-box PLA from specification
        ├── kernel_extractor.py                # Algebraic kernel extraction & factor report
        └── run_sbox_opt.py                    # End-to-end S-box optimization runner
```

> **Note:** Build artifacts (`build/`), Vivado project/cache directories (`.Xil/`, `xsim.dir/`), and locally compiled binaries (`tools/sbox_opt/bin/`) are gitignored and generated locally on demand.
