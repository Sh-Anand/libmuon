#include <rad_defs.h>

.global _start
.type _start, @function
_start:
    li t0, KERNEL_HEADER_MEM_PARAMS_SZ
    beqz t0, launch_kernel
    li t1, KERNEL_MEM_PARAMS_START
    mv t2, zero
    
    lw a0, 0(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

    lw a1, 4(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

    lw a2, 8(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

    lw a3, 12(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

    lw a4, 16(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

    lw a5, 20(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

    lw a6, 24(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

    lw a7, 28(t1)
    addi t2, t2, 4
    beq t2, t0, launch_kernel

launch_kernel:
    lw t3, %lo(KERNEL_HEADER_MEM_KERNEL_PC)(zero)
    jalr x0, t3, 0
