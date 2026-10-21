/* Linker Script for Relocated Application Payload */
OUTPUT_ARCH( "riscv" )
ENTRY(_app_start)

MEMORY
{
    APP_RAM (rwx) : ORIGIN = 0x00001040, LENGTH = 4K
}

SECTIONS
{
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > APP_RAM

    .data : {
        . = ALIGN(4);
        *(.data .data.*)
        . = ALIGN(4);
    } > APP_RAM

    .bss : {
        . = ALIGN(4);
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
    } > APP_RAM
}
