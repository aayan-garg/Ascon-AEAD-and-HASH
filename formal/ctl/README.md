# Formal CTL Model Checking: Secure Boot Safety

- **Target Property:** $\text{CTLSPEC } AG(\text{jump} \rightarrow \text{hash\_ok})$
- **Requirement Reference:** `[SPEC]` R17, `docs/requirements_traceability.md` R17
- **Formal Tool:** NuSMV 2.6.0
- **Target Subsystem:** Hardware Secure Boot Controller FSM (`rtl/soc/boot_ctrl.sv`)
- **Evidence Log:** [`results/formal/nuxmv/proof_corrected_nusmv.log`](../../results/formal/nuxmv/proof_corrected_nusmv.log)

---

## 1. Mathematical Objective

The primary formal requirement of this project (`[SPEC]` R17) states:
> *"Formally prove `AG(jump -> hash_ok)` using CTL model checking in nuXmv or NuSMV."*

In Computation Tree Logic (CTL):
- **$A$ (All paths):** In every possible infinite execution sequence branching from the initial state ($s_0$).
- **$G$ (Globally):** At every temporal step along the path.
- **$\text{jump} \rightarrow \text{hash\_ok}$:** Whenever the controller asserts `jump_enable` to release execution to candidate application code, the cryptographic Ascon digest verification signal (`hash_ok`) must evaluate to `TRUE`.

---

## 2. Model Structure and Files

1. **`formal/ctl/boot_safety_corrected.smv` (Authoritative Proof Model):**
   Encodes the exact state transitions, latched registers, and guard conditions of `rtl/soc/boot_ctrl.sv`:
   - Enforces latched register evaluation `hash_verified_q`.
   - Clears `verified_before_jump_q` upon physical tamper assertion.
   - Proves all 5 safety properties TRUE under NuSMV 2.6.0.
2. **`formal/ctl/boot_safety_broken.smv` (Counterexample Demonstration Model):**
   Demonstrates counterexample trace generation when the cryptographic verification check is bypassed in `STATE_DECIDE`.

---

## 3. Abstracted Model Boundary

Directly model checking the entire 320-bit Ascon permutation datapath inside a symbolic model checker creates an unmanageably large state space ($2^{320}$ states).

To achieve formal mathematical tractability:
1. **Permutation Datapath:** Exhaustively validated via 100% official NIST Known Answer Tests (KATs) across 1,089 AEAD and 1,025 Hash vectors.
2. **Comparator Datapath:** The 256-bit hash comparator outputs a single verified boolean:
   $$\text{hash\_ok} = (\text{digest}[255:0] == \text{golden\_digest}[255:0])$$
3. **Controller Boundary:** NuSMV verifies the finite-state machine controlling reset, DMA initiation, wait-states, hash check, decision logic, and CPU core execution release.

---

## 4. Formal CTL Specification Suite (`boot_safety_corrected.smv`)

| ID | CTL Formula | Natural Language Specification | NuSMV Result |
|---|---|---|:---:|
| **SPEC-CTL-1** | `AG (jump -> hash_ok)` | **Mandatory Safety:** Along all execution paths at all times, code jump implies hash verification was successful. | **TRUE** |
| **SPEC-CTL-2** | `AG (jump -> verified_before_jump)` | **Monitor Invariant:** In `STATE_JUMP`, `verified_before_jump` monitor register is TRUE, proving verification strictly preceded jump. | **TRUE** |
| **SPEC-CTL-3** | `AG (tamper_latched -> !EF jump)` | **Tamper Resilience:** Once tamper is latched, it is globally impossible on any future branch to reach `JUMP`. | **TRUE** |
| **SPEC-CTL-4** | `AG (state = STATE_DECIDE & !hash_verified -> AX (state = STATE_HALT_REFUSE))` | **Strict Lockout:** If verification fails at the decision barrier, transition to `HALT_REFUSE` occurs immediately on next cycle. | **TRUE** |
| **SPEC-CTL-5** | `AG (refuse -> AG refuse)` | **Terminal State Invariance:** Once locked in `HALT_REFUSE`, escape without hardware reset is mathematically impossible. | **TRUE** |

---

## 5. Verification Execution Instructions

Run with NuSMV 2.6.0:

```bash
# Verify corrected model (All 5 properties PROVED TRUE)
NuSMV formal/ctl/boot_safety_corrected.smv

# Demonstrate counterexample generation on broken model
NuSMV formal/ctl/boot_safety_broken.smv
```

Exact NuSMV 2.6.0 output transcript recorded in [`results/formal/nuxmv/proof_corrected_nusmv.log`](../../results/formal/nuxmv/proof_corrected_nusmv.log):
```text
-- specification AG (jump -> hash_ok)  is true
-- specification AG (tamper_latched -> !(EF jump))  is true
-- specification AG ((state = STATE_DECIDE & !hash_verified) -> AX state = STATE_HALT_REFUSE)  is true
-- specification AG (refuse -> AG refuse)  is true
-- specification AG (jump -> verified_before_jump)  is true
```
