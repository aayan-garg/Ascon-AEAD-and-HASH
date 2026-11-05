# Research Review: Ascon Hardware Architectures

- **Objective:** Survey relevant Ascon hardware literature and record which
  sources were directly checked.
- **Date:** November 5, 2026
- **Measurement tables:** [`results/performance/comparison_table.md`](../results/performance/comparison_table.md)
  and [`results/performance/engine_comparison_table.md`](../results/performance/engine_comparison_table.md)

## Citation verification

| Paper | Confirmed fields | Source page opened | Status |
|---|---|---|---|
| Malal, *High-Performance FPGA Implementations of Lightweight ASCON-128 and ASCON-128a with Enhanced Throughput-to-Area Efficiency* | Author, title, ePrint 2025/825, year 2025, DOI, abstract | [IACR ePrint 2025/825](https://eprint.iacr.org/2025/825) | CONFIRMED |
| Groß et al., *Suit up! Made-to-Measure Hardware Implementations of Ascon* | Authors, title, ePrint 2015/034, year 2015, abstract | [IACR ePrint 2015/034](https://eprint.iacr.org/2015/034) | CONFIRMED |
| Groß et al., *Generic Low-Latency Masking in Hardware* | Generic masking topic and DOI | [TCHES DOI](https://doi.org/10.13154/tches.v2018.i2.1-21) | CONFIRMED |
| Mohamed et al., *An Efficient Serialized Hardware Implementation of the ASCON Algorithm* | URL was not accessible from this environment | [Nature URL](https://www.nature.com/articles/s41598-024-65672-0) | UNCONFIRMED |
| Konstantopoulou et al., *Review and Analysis of FPGA and ASIC Implementations of NIST Lightweight Cryptography Finalists* | DOI page was not accessible from this environment | [ACM DOI](https://doi.org/10.1145/3721122) | UNCONFIRMED |

The 2024 conference date and 2025 ePrint date for Malal are intentionally
separate: the paper is dated 2024 at ISCTürkiye and posted as ePrint 2025/825.
The ePrint page confirms DOI `10.1109/ISCTrkiye64784.2024.10779273`.

## Primary literature

### Groß et al. (DSD 2015)

The ePrint abstract confirms a hardware design-space study covering low-area,
high-performance, and protected Ascon implementations. The source page does
not establish the exact 32-bit-slice claim used by this project. Therefore
`permutation_serial32` is our own 32-bit-slice serialisation, motivated by the
serialised designs surveyed in the verified literature; it is not claimed to
be a reimplementation of a specific published design.

### Malal (ISCTürkiye 2024 / ePrint 2025)

The opened ePrint page describes 6-round and 4-round FPGA implementations and
reports throughput-to-area improvements in its abstract. It is background
only; its figures are not used as measurements of this repository.

### Generic masking

The Groß, Iusupov, Bloem paper is a generic hardware masking paper. It is not
described here as an Ascon-specific investigation. Masking is not implemented
in this repository and is **NOT DONE**.

The two entries marked **UNCONFIRMED** are not used to support design claims
or numerical comparisons.

## S-box variants in this repository

- **ESPRESSO:** `rtl/ascon/sbox5_espresso.sv` contains equations that were
  minimized externally with ESPRESSO; this repository only verifies them
  against NIST SP 800-232 Table 6. The checked-in PLA is only a conversion of
  those RTL equations, not ESPRESSO output.
- **Kernel:** `rtl/ascon/sbox5_kernel.sv` is an ANF restatement of the standard
  equations; no kernel extraction was performed.
- **BDD:** `rtl/ascon/sbox5_bdd.sv` is a 32-entry lookup table; no BDD
  decomposition was performed.

All three variants are functionally checked by
[`tb/unit/tb_sbox_equiv.sv`](../tb/unit/tb_sbox_equiv.sv). The available
engine measurements are reported as same-session synthesis results, but the
small 3,052/3,055 versus 3,191 LUT difference is not attributed to the
unperformed techniques. It may reflect synthesis variation or a baseline run
from a different `round_core.sv` revision.
