/* Linker Script for PicoRV32 Bringup Firmware */
/* Memory Map: 16 KB BRAM at 0x00000000 */

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > RAM

    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* Stack begins at end of Boot ROM area (0x0FE0) and grows downward.
       Must remain below CANDIDATE_HDR_ADDR (0x1000) so fetch_guard does not gate stack reads. */
    . = ALIGN(16);
    _stack_top = 0x00000FE0;
}
