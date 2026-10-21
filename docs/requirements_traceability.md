# Requirements Traceability Matrix

> Tracks every requirement from `Project_PS.md` to its implementation phase, artifact, test, and acceptance criterion.
> Update with links to actual commits/files as implementation progresses.

| # | Requirement | Phase | Artifact | Test | Acceptance Criterion | Status |
|---|---|---|---|---|---|---|
| R1 | Ascon-AEAD128 enc/dec with tag check (SP 800-232) | 5 | `rtl/ascon/aead_ctrl.sv` | Official AEAD KATs | 100% KAT pass | `⬜ NOT STARTED` |
| R2 | Ascon-Hash256 (SP 800-232) | 5 | `rtl/ascon/hash_ctrl.sv` | Official Hash KATs | 100% KAT pass | `⬜ NOT STARTED` |
| R3 | 320-bit state, 5×64-bit words | 4 | `rtl/ascon/state_reg.sv` | Code review + simulation | Matches SP 800-232 §3 | `⬜ NOT STARTED` |
| R4 | Round-based datapath, 1 round/cycle baseline | 4 | `rtl/ascon/permutation_1r.sv` | Differential vs golden model | 0 mismatches | `⬜ NOT STARTED` |
| R5 | Plaintext not released before tag verification | 5 | `rtl/ascon/plaintext_gate.sv` | Security-gate tests (§12.2) | No PT before `tag_ok=1` | `⬜ NOT STARTED` |
| R6 | 100 MHz target | 10/11 | Vivado timing report | Post-implementation STA | WNS ≥ 0 at 100 MHz | `⬜ NOT STARTED` |
| R7 | AXI4-Lite + DMA integration | 6/7 | `rtl/bus/axil_regs.sv`, `rtl/dma/*` | Bus R/W + DMA tests | Verified from firmware | `⬜ NOT STARTED` |
| R8 | Boot-ROM integration with RV32 core | 8 | `firmware/bootrom/*`, `rtl/soc/*` | Boot sequence sim + board | Boot ROM reaches jump decision | `⬜ NOT STARTED` |
| R9 | Golden software model matching KATs | 3 | `reference/` | Official KATs | 100% pass before RTL oracle use | `⬜ NOT STARTED` |
| R10 | Permutation: ½, 1, 2 rounds/cycle | 4/10 | `rtl/ascon/permutation_{half,1r,2r}.sv` | Differential + synthesis | All 3 correct; synthesis recorded | `⬜ NOT STARTED` |
| R11 | Bit-sliced S-box + linear diffusion | 4 | `rtl/ascon/sbox5.sv`, `diffusion.sv` | Exhaustive truth-table | 0 mismatches | `⬜ NOT STARTED` |
| R12 | Mode controller FSM | 5 | `rtl/ascon/mode_ctrl.sv` | State-transition coverage | All states/transitions covered | `⬜ NOT STARTED` |
| R13 | 5×5 S-box via ESPRESSO/kernel/BDD | 4 | `tools/sbox_opt/*`, comparison report | Exhaustive equivalence + synthesis | Functionally identical; cost measured | `⬜ NOT STARTED` |
| R14 | Secure-boot flow | 8 | `firmware/bootrom/secure_boot.c`, `rtl/soc/boot_ctrl.sv` | Valid/invalid image matrix | Valid jumps; invalid refuses | `⬜ NOT STARTED` |
| R15 | Research paper technique | 12 | `docs/research_review.md` + implementation | Functional + synthesis evidence | Comparison table vs baseline | `⬜ NOT STARTED` |
| R16 | Area/throughput table for all design points | 10 | `results/performance/*` | Vivado reports | Reproducible, no fabricated numbers | `⬜ NOT STARTED` |
| R17 | CTL proof: `AG(jump → hash_ok)` | 9 | `formal/ctl/boot_safety.smv` | nuXmv proof + counterexample | Pass on correct, fail on broken | `⬜ NOT STARTED` |
| R18 | Boot-time cycle measurement | 11 | Cycle counter | Board/simulation count | Reported with image size | `⬜ NOT STARTED` |
| R19 | Physical demo: LED pass/fail | 11 | Board bitstream + demo | Live demonstration | Two distinct LED outcomes | `⬜ NOT STARTED` |

---

*Update status to `🟡 IN PROGRESS` or `✅ DONE` as work proceeds. Link to evidence files when available.*
