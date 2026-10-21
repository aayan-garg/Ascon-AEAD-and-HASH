# Ascon AEAD and Hash Engine for IoT Secure Boot

[![Zybo Z7-10](https://img.shields.io/badge/Target-Zybo%20Z7--10-blue)]()
[![NIST SP 800-232](https://img.shields.io/badge/Standard-SP%20800--232-green)]()
[![License](https://img.shields.io/badge/License-TBD-lightgrey)]()

## Overview

A hardware implementation of **Ascon-AEAD128** and **Ascon-Hash256** (per NIST SP 800-232) integrated with an **RV32 RISC-V SoC** on the **Digilent Zybo Z7-10** FPGA for secure boot of IoT firmware.

## Key Features

- Ascon-AEAD128 authenticated encryption/decryption with tag verification
- Ascon-Hash256 cryptographic hashing
- Three permutation design points: ½, 1, and 2 rounds per cycle
- 5×5 S-box optimization via ESPRESSO/kernel-extraction/BDD
- AXI4-Lite control + custom DMA bulk transfer
- Secure boot: firmware integrity verification before execution
- Formal CTL proof: `AG(jump → hash_ok)`
- Physical demo: LED-indicated boot pass/fail with switch-based byte tampering

## Project Structure

See [`docs/directory_structure.md`](docs/directory_structure.md) for the complete layout.

## Getting Started

*Documentation and setup instructions will be added as implementation progresses.*

## Status

See [`docs/status.md`](docs/status.md) for current project state.

## Documentation

| Document | Purpose |
|---|---|
| [`docs/implementation_plan.md`](docs/implementation_plan.md) | Phase-by-phase execution plan |
| [`docs/research_plan.md`](docs/research_plan.md) | Research tasks and sources |
| [`docs/requirements_traceability.md`](docs/requirements_traceability.md) | Requirements → artifacts mapping |
| [`AGENTS.md`](AGENTS.md) | Agent operating instructions |

## References

- [NIST SP 800-232](https://csrc.nist.gov/pubs/sp/800/232/final) — Ascon standard
- [ascon/ascon-c](https://github.com/ascon/ascon-c) — Official reference code and KAT vectors
- [YosysHQ/picorv32](https://github.com/YosysHQ/picorv32) — RISC-V core
- [Zybo Z7 Reference Manual](https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual) — Board documentation
