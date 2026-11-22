/* Linker Script for Full-2,114 NIST KAT Bare-Metal Runner (128 KB BRAM) */
/* Memory Map inside 128 KB BRAM (0x00000000 - 0x0001FFFF):
 *   0x0000_0000 - 0x0000_0FFF (4 KB)  : Startup vector & low ROM code
 *   0x0000_1000 - 0x0000_1FFF (4 KB)  : DMA scratch buffer (< 16 KB for dma_master)
 *   0x0000_2000 - 0x0001_FFFF (120 KB): Main .text, .rodata (76 KB KAT vectors), .data, .bss, stack
 */

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
    LOW_ROM  (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMA_BUF  (rw)  : ORIGIN = 0x00001000, LENGTH = 4K
    MAIN_RAM (rwx) : ORIGIN = 0x00002000, LENGTH = 120K
}

SECTIONS
{
    .text.init : {
        . = ALIGN(4);
        *(.text.init)
        . = ALIGN(4);
    } > LOW_ROM

    .dma_buf (NOLOAD) : {
        . = ALIGN(8);
        _dma_buf_start = .;
        *(.dma_buf)
        . = ALIGN(8);
    } > DMA_BUF

    .text : {
        . = ALIGN(4);
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > MAIN_RAM

    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > MAIN_RAM

    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > MAIN_RAM

    . = ALIGN(16);
    _stack_top = 0x0001FFF0;
}

