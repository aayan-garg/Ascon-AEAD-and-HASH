# Directory Structure — Ascon AEAD and Hash Engine

> **Canonical layout. All agents and contributors must place files according to this structure.**
> If a new directory is needed, update this file first and document the reason.

```
Ascon-AEAD-and-HASH/
├── AGENTS.md                          # Agent operating instructions (read first every session)
├── README.md                          # Project overview and quick-start
├── .gitignore                         # Excludes Vivado projects, sim dumps, __pycache__
│
├── docs/                              # All documentation
│   ├── final_report.md                # Comprehensive technical evaluation report (TA writeup)
│   ├── requirements_traceability.md   # Single source of truth for R1–R19
│   ├── AUDIT_RESPONSE.md              # Single source of truth for audit remediations
│   ├── CHANGELOG.md                   # Project changelog & consolidation record
│   ├── status.md                      # Live project status
│   ├── directory_structure.md         # THIS FILE — canonical layout reference
│   ├── architecture.md                # Detailed FSMs, data flows, round definitions
│   ├── research_review.md             # Paper summaries, verified citations, comparisons
│   ├── threat_model.md                # Secure-boot trust assumptions and defense-in-depth
│   ├── register_map.md                # AXI4-Lite register map with field definitions
│   └── decisions/                     # One file per resolved ambiguity/design decision
│       ├── tooling.md                 # Pinned tool versions
│       ├── algorithm_version.md       # SP 800-232 vs. v1.2 confirmation
│       ├── riscv_core.md              # RISC-V core selection rationale
│       └── sbox_optimization.md       # S-box optimization approach & variants
│
├── rtl/                               # All synthesizable RTL (SystemVerilog)
│   ├── ascon/                         # Ascon accelerator core
│   │   ├── sbox5.sv                   # Standard Boolean-equation S-box
│   │   ├── sbox5_espresso.sv          # ESPRESSO/BDD-optimized S-box variant
│   │   ├── diffusion.sv              # Linear diffusion layer
│   │   ├── round_core.sv             # One full combinational round
│   │   ├── state_reg.sv              # 320-bit state register (5×64-bit)
│   │   ├── permutation_1r.sv         # 1 round/cycle (baseline)
│   │   ├── permutation_half.sv       # ½ round/cycle (2 micro-steps)
│   │   ├── permutation_2r.sv         # 2 rounds/cycle (chained)
│   │   ├── mode_ctrl.sv              # Mode controller FSM
│   │   ├── aead_ctrl.sv              # AEAD mode wrapper
│   │   ├── hash_ctrl.sv              # Hash mode wrapper
│   │   └── plaintext_gate.sv         # Plaintext-release security gate
│   │
│   ├── bus/                           # Bus infrastructure
│   │   └── axil_regs.sv              # AXI4-Lite register file + address decode
│   │
│   ├── dma/                           # DMA engine
│   │   └── dma_master.sv             # Custom DMA master (valid/ready streaming)
│   │
│   ├── soc/                           # SoC integration
│   │   ├── top_bringup.sv            # Phase 2 minimal bring-up top
│   │   └── boot_ctrl.sv              # Secure-boot control logic
│   │
│   └── top/                           # Board-level top
│       └── zybo_top.sv               # Final board top-level with clocking, IO
│
├── firmware/                          # All software running on the RISC-V core
│   ├── bootrom/                       # Secure boot ROM
│   │   └── secure_boot.c             # Main boot ROM: hash, verify, jump/refuse
│   ├── linker/                        # Linker scripts
│   │   └── bootrom.ld                # Memory map for boot ROM
│   ├── startup/                       # Startup code
│   │   └── crt0.S                    # C runtime startup, vector table
│   └── tests/                         # Test firmware programs
│       ├── gpio_toggle.c             # Phase 2 bring-up test
│       └── accel_hash_test.c         # Phase 6 accelerator test
│
├── reference/                         # Golden software model (NOT original code — vendored)
│   ├── pyascon/                       # Vendored pyascon or ascon-c wrapper
│   ├── run_kats.py                    # KAT runner: produces pass/fail log
│   ├── kat_checksums.txt              # SHA-256 hashes of KAT vector files
│   └── vectors/                       # Official KAT vector files
│
├── tb/                                # All testbenches (simulation only, not synthesized)
│   ├── unit/                          # Per-module unit tests
│   │   ├── tb_sbox5.sv
│   │   ├── tb_round_core.sv
│   │   ├── tb_permutation.sv
│   │   ├── tb_mode_ctrl.sv
│   │   ├── tb_aead.sv
│   │   ├── tb_hash.sv
│   │   └── tb_security_gate.sv
│   ├── integration/                   # Multi-module integration tests
│   │   ├── tb_axil_regs.sv
│   │   └── tb_dma.sv
│   └── system/                        # Full-system boot-flow simulation
│       └── tb_secure_boot.sv
│
├── formal/                            # Formal verification
│   ├── ctl/                           # CTL model checking (nuXmv)
│   │   ├── boot_safety.smv           # Correct model
│   │   ├── boot_safety_broken.smv    # Deliberately broken model
│   │   └── run_nuxmv.sh              # Script to run proofs
│   └── sva/                           # SVA assertions (SymbiYosys)
│       └── ascon_assertions.sv
│
├── board/                             # FPGA board files
│   ├── zybo_z7_10.xdc                # Pin constraints for Zybo Z7-10
│   └── build.tcl                      # Vivado non-project-mode build script
│
├── scripts/                           # Automation scripts
│   ├── run_regression.sh              # Run all tests, report pass/fail
│   ├── provision_image.py             # Generate firmware image with embedded digest
│   └── convert_kat_vectors.py         # Convert KAT files to testbench-loadable format
│
├── tools/                             # Development tools
│   └── sbox_opt/                      # S-box optimization
│       ├── espresso_run.sh            # ESPRESSO minimization script
│       ├── bdd_analysis.py            # BDD-based optimization
│       └── compare_variants.py        # Compare S-box implementations
│
├── tests/                             # Top-level test entrypoints
│   └── run_all.sh                     # CI-friendly test runner
│
├── results/                           # Extracted, human-readable results (committed)
│   ├── kat/                           # KAT pass/fail logs
│   ├── performance/                   # Throughput/area comparison tables
│   ├── synthesis/                     # Vivado utilization summaries
│   ├── timing/                        # Timing analysis summaries
│   ├── formal/                        # CTL proof/counterexample logs
│   └── board/                         # Board test evidence
│       ├── boot_matrix/               # Per-case boot test logs
│       └── demo_evidence/             # Demo photos/videos
│
├── references/                        # Cached citation metadata (not full PDFs)
│   └── bibliography.md               # All verified citations with URLs
│
└── .agents/                           # Agent configuration
    ├── rules/                         # Antigravity behavioral rules
    │   └── rtl-project.md            # RTL-specific rules
    └── skills/                        # Custom skills
        └── rtl-design/               # RTL design skill
            └── SKILL.md
```

---

## Rules

1. **One module per file** in `rtl/`. Filename = module name.
2. **Testbenches prefixed with `tb_`** in `tb/`.
3. **No raw tool output** in `results/` — only small text/CSV/Markdown summaries.
4. **No generated/binary files** committed (`.bit`, `.ltx`, `.dcp`, `.runs/`, `__pycache__/`).
5. **New directories** require updating this file first with justification.

---

*Last updated: 2026-10-21*
