#!/usr/bin/env python3
"""
Explicit Model Checker for Boot Safety FSM (Kripke Structure & CTL Evaluator)
Requirement: [SPEC] R17, docs/research_plan.md R-7

Constructs the finite Kripke structure (S, S0, R, L) for the boot safety FSM
and evaluates the CTL fixed-point operators:
  - AX, EX
  - AG (greatest fixed point: nu Z . phi & AX(Z))
  - AF (least fixed point: mu Z . phi | AX(Z))
  - EF (least fixed point: mu Z . phi | EX(Z))
"""

from typing import Set, Tuple, Dict, List
import itertools

STATES = [
    "STATE_RESET",
    "STATE_READ_HEADER",
    "STATE_DMA_STREAM",
    "STATE_WAIT_HASH",
    "STATE_CHECK_TAG",
    "STATE_DECIDE",
    "STATE_JUMP",
    "STATE_HALT_REFUSE"
]

def next_fsm_state(current: str, hash_valid: bool, tamper_latched: bool, start: bool, dma_done: bool, hash_done: bool) -> str:
    """FSM transition function matching boot_ctrl.sv."""
    if tamper_latched:
        return "STATE_HALT_REFUSE"
    
    if current == "STATE_RESET":
        return "STATE_READ_HEADER" if start else "STATE_RESET"
    elif current == "STATE_READ_HEADER":
        return "STATE_DMA_STREAM"
    elif current == "STATE_DMA_STREAM":
        return "STATE_WAIT_HASH" if dma_done else "STATE_DMA_STREAM"
    elif current == "STATE_WAIT_HASH":
        return "STATE_CHECK_TAG" if hash_done else "STATE_WAIT_HASH"
    elif current == "STATE_CHECK_TAG":
        return "STATE_DECIDE"
    elif current == "STATE_DECIDE":
        return "STATE_JUMP" if (hash_valid and not tamper_latched) else "STATE_HALT_REFUSE"
    elif current == "STATE_JUMP":
        return "STATE_JUMP"
    elif current == "STATE_HALT_REFUSE":
        return "STATE_HALT_REFUSE"
    return current

class KripkeStructure:
    def __init__(self):
        self.states: Set[Tuple] = set()
        self.initial_states: Set[Tuple] = set()
        self.transitions: Dict[Tuple, Set[Tuple]] = {}
        self.labels: Dict[Tuple, Set[str]] = {}
        self.build()

    def build(self):
        # State tuple: (fsm_state, hash_valid, tamper_latched, start, dma_done, hash_done, hash_match, tamper_det)
        env_inputs = list(itertools.product([False, True], repeat=5)) # start, dma_done, hash_done, hash_match, tamper_det
        
        # Build all states
        for fsm in STATES:
            for hv in [False, True]:
                for tl in [False, True]:
                    for start, dma_done, hash_done, hash_match, tamper_det in env_inputs:
                        s = (fsm, hv, tl, start, dma_done, hash_done, hash_match, tamper_det)
                        self.states.add(s)
                        self.transitions[s] = set()
                        
                        # Labels
                        lbl = set()
                        lbl.add(fsm)
                        if fsm == "STATE_JUMP":
                            lbl.add("jump")
                        if fsm == "STATE_HALT_REFUSE":
                            lbl.add("refuse")
                        if hv:
                            lbl.add("hash_ok")
                        if tl:
                            lbl.add("tamper")
                        if tamper_det:
                            lbl.add("tamper_det")
                        if start:
                            lbl.add("start")
                        self.labels[s] = lbl
                        
                        # System boots from reset with clean security registers
                        if fsm == "STATE_RESET" and not hv and not tl:
                            self.initial_states.add(s)

        # Transitions
        for s in self.states:
            fsm, hv, tl, start, dma_done, hash_done, hash_match, tamper_det = s
            
            # Next hardware register values:
            # Sticky tamper latch
            nxt_tl = tl or tamper_det
            # Hash verification register latches match during CHECK_TAG state
            nxt_hv = (hv or (fsm == "STATE_CHECK_TAG" and hash_match)) and not nxt_tl
            
            nxt_fsm = next_fsm_state(fsm, nxt_hv, nxt_tl, start, dma_done, hash_done)
            
            # Non-deterministic environmental inputs for next cycle
            for nxt_in in env_inputs:
                nxt_s = (nxt_fsm, nxt_hv, nxt_tl) + nxt_in
                self.transitions[s].add(nxt_s)

    def reachable_states(self) -> Set[Tuple]:
        visited = set(self.initial_states)
        queue = list(self.initial_states)
        while queue:
            curr = queue.pop(0)
            for nxt in self.transitions[curr]:
                if nxt not in visited:
                    visited.add(nxt)
                    queue.append(nxt)
        return visited

    # --- CTL Operators ---
    def EX(self, phi: Set[Tuple]) -> Set[Tuple]:
        return {s for s, succs in self.transitions.items() if any(nxt in phi for nxt in succs)}

    def AX(self, phi: Set[Tuple]) -> Set[Tuple]:
        return {s for s, succs in self.transitions.items() if all(nxt in phi for nxt in succs)}

    def EF(self, phi: Set[Tuple]) -> Set[Tuple]:
        """Least fixed point: mu Z . (phi | EX(Z))"""
        z = set(phi)
        while True:
            nxt_z = z | self.EX(z)
            if nxt_z == z:
                break
            z = nxt_z
        return z

    def AF(self, phi: Set[Tuple]) -> Set[Tuple]:
        """Least fixed point: mu Z . (phi | AX(Z))"""
        z = set(phi)
        while True:
            nxt_z = z | self.AX(z)
            if nxt_z == z:
                break
            z = nxt_z
        return z

    def AG(self, phi: Set[Tuple]) -> Set[Tuple]:
        """Greatest fixed point: nu Z . (phi & AX(Z))"""
        z = set(self.states)
        while True:
            nxt_z = phi & self.AX(z)
            if nxt_z == z:
                break
            z = nxt_z
        return z

def run_verification():
    print("=" * 70)
    print("ASCON SECURE BOOT CONTROLLER CTL MODEL CHECKER")
    print("Model Checking Target: AG (jump -> hash_ok) and Safety Properties")
    print("=" * 70)
    
    kripke = KripkeStructure()
    reachable = kripke.reachable_states()
    print(f"Total State Configurations: {len(kripke.states)}")
    print(f"Total Reachable States:    {len(reachable)}")
    print(f"Total Transitions Built:   {sum(len(v) for v in kripke.transitions.values())}")
    print("-" * 70)

    # Propositions
    jump_states = {s for s in kripke.states if "jump" in kripke.labels[s]}
    hash_ok_states = {s for s in kripke.states if "hash_ok" in kripke.labels[s]}
    tamper_states = {s for s in kripke.states if "tamper" in kripke.labels[s]}
    refuse_states = {s for s in kripke.states if "refuse" in kripke.labels[s]}
    decide_states = {s for s in kripke.states if "STATE_DECIDE" in kripke.labels[s]}

    # Check 1: AG (jump -> hash_ok)
    p1_phi = (kripke.states - jump_states) | hash_ok_states
    ag_p1 = kripke.AG(p1_phi)
    p1_pass = reachable.issubset(ag_p1)
    print(f"Property 1: AG (jump -> hash_ok)")
    print(f"  Result: {'[PROVED TRUE]' if p1_pass else '[FAILED]'}")

    # Check 2: AG (tamper -> !EF jump)
    ef_jump = kripke.EF(jump_states)
    not_ef_jump = kripke.states - ef_jump
    p2_phi = (kripke.states - tamper_states) | not_ef_jump
    ag_p2 = kripke.AG(p2_phi)
    p2_pass = reachable.issubset(ag_p2)
    print(f"Property 2: AG (tamper_latched -> !EF jump)")
    print(f"  Result: {'[PROVED TRUE]' if p2_pass else '[FAILED]'}")

    # Check 3: AG (STATE_DECIDE & !hash_ok -> AX STATE_HALT_REFUSE)
    decide_and_bad_hash = decide_states - hash_ok_states
    ax_refuse = kripke.AX(refuse_states)
    p3_phi = (kripke.states - decide_and_bad_hash) | ax_refuse
    ag_p3 = kripke.AG(p3_phi)
    p3_pass = reachable.issubset(ag_p3)
    print(f"Property 3: AG (STATE_DECIDE & !hash_ok -> AX STATE_HALT_REFUSE)")
    print(f"  Result: {'[PROVED TRUE]' if p3_pass else '[FAILED]'}")

    # Check 4: AG (refuse -> AG refuse)
    ag_refuse = kripke.AG(refuse_states)
    p4_phi = (kripke.states - refuse_states) | ag_refuse
    ag_p4 = kripke.AG(p4_phi)
    p4_pass = reachable.issubset(ag_p4)
    print(f"Property 4: AG (refuse -> AG refuse)")
    print(f"  Result: {'[PROVED TRUE]' if p4_pass else '[FAILED]'}")

    print("=" * 70)
    all_passed = p1_pass and p2_pass and p3_pass and p4_pass
    if all_passed:
        print("ALL FORMAL CTL PROPERTIES MATHEMATICALLY PROVED TRUE!")
    else:
        print("FORMAL VERIFICATION FAILED.")
    print("=" * 70)
    return 0 if all_passed else 1

if __name__ == "__main__":
    import sys
    sys.exit(run_verification())
