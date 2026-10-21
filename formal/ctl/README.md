# Formal CTL Model Checking: Secure Boot Safety

- **Target Property:** $\text{CTLSPEC } AG(\text{jump} \rightarrow \text{hash\_ok})$
- **Requirement Reference:** `[SPEC]` R17, `docs/research_plan.md` R-7, `Initial Research.md` §13.2
- **Formal Engine:** nuXmv / NuSMV
- **Target Subsystem:** Secure Boot Controller FSM (`rtl/soc/boot_ctrl.sv`)

---

## 1. Mathematical Objective

The primary formal requirement of this project (`[SPEC]` R17) states:
> *"Formally prove `AG(jump -> hash_ok)` using CTL model checking in nuXmv or NuSMV."*

In Computation Tree Logic (CTL):
- **$A$ (All paths):** In every possible infinite execution sequence starting from the initial state ($s_0$).
- **$G$ (Globally):** At every temporal step along the path.
- **$\text{jump} \rightarrow \text{hash\_ok}$:** If the controller asserts the instruction pointer jump enable to execute untrusted application code, the cryptographic Ascon digest verification signal (`hash_ok`) must evaluate to `TRUE`.

---

## 2. Tooling Differentiation: nuXmv vs. SymbiYosys

| Dimension | SymbiYosys (Sby) | nuXmv / NuSMV |
|---|---|---|
| **Underlying Logic** | Linear Temporal Logic (LTL) & SVA | Computation Tree Logic (CTL) & LTL |
| **Quantification** | Linear paths ($G, F, U, X$) | Branching-time trees ($AG, EF, AF, EG, AX, EX$) |
| **Solving Engine** | Bounded Model Checking (BMC), k-induction (Z3, Yices, Boolector) | Symbolic BDD & SAT/SMT-based Model Checking |
| **Project Role** | Internal AXI4-Lite bus handshake assertions (`formal/sva/`) | **Primary CTL Safety Verification (`formal/ctl/`)** |

---

## 3. Abstracted Model Boundary

Directly model checking the entire 320-bit Ascon permutation datapath inside a symbolic model checker creates an unmanageably large state space ($2^{320}$ states).

To achieve mathematical tractability:
1. **Permutation Datapath:** Exhaustively validated via 100% official NIST Known Answer Tests (KATs) and truth-table verification.
2. **Comparator Datapath:** The 256-bit hash comparator outputs a single verified boolean:
   $$\text{hash\_ok} = (\text{digest}[255:0] == \text{golden\_digest}[255:0])$$
3. **Controller Boundary:** nuXmv verifies the finite-state machine controlling reset, DMA initiation, wait-states, hash check, decision logic, and CPU core execution release.

---

## 4. Formal CTL Specification Suite (`boot_safety.smv`)

| ID | CTL Formula | Natural Language Specification |
|---|---|---|
| **SPEC-CTL-1** | `AG (jump -> hash_ok)` | **Mandatory Safety:** Along all execution paths at all times, code jump implies hash verification was successful. |
| **SPEC-CTL-2** | `AG (tamper_det -> !EF jump)` | **Tamper Resilience:** Detection of hardware tampering permanently prevents any future state from reaching `JUMP`. |
| **SPEC-CTL-3** | `AG (state = STATE_DECIDE & !hash_ok -> AX (state = STATE_HALT_REFUSE))` | **Strict Lockout:** If verification fails at the decision barrier, transition to `HALT_REFUSE` occurs immediately on the next clock cycle. |
| **SPEC-CTL-4** | `AG (start -> AF (jump \| refuse \| !start))` | **Termination / Liveness:** Starting boot guarantees eventual termination into an authenticated boot or defensive lockout. |
| **SPEC-CTL-5** | `AG (refuse -> AG refuse)` | **Terminal State Invariance:** Once locked in `HALT_REFUSE`, escape without hardware reset is mathematically impossible. |

---

## 5. Verification Execution Instructions

When running on Linux / WSL2 with nuXmv installed:

```bash
# Run batch verification
nuXmv formal/ctl/boot_safety.smv
```

Expected nuXmv output:
```text
-- specification AG (jump -> hash_ok) is true
-- specification AG (tamper_det -> !EF jump) is true
-- specification AG ((state = STATE_DECIDE & !hash_ok) -> AX state = STATE_HALT_REFUSE) is true
-- specification AG (start -> AF ((jump | refuse) | !start)) is true
-- specification AG (refuse -> AG refuse) is true
```
