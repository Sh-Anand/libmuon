#include <rad_defs.h>

.global _start
.type _start, @function
_start:
    csrr t0, CSR_BLOCK_IDX_X
    csrr t1, CSR_BLOCK_IDX_Y
    csrr t2, CSR_BLOCK_IDX_Z
    csrr t3, CSR_THREAD_IDX_X
    csrr t4, CSR_THREAD_IDX_Y
    csrr t5, CSR_THREAD_IDX_Z
    
    li t6, KERNEL_HEADER_MEM_GRID_X
    lw t7, 0(t6) // kernel grid x
    lw t8, 4(t6) // kernel grid y
    lw t9, 8(t6) // kernel grid z
    lw t10, 12(t6) // kernel block x
    lw t11, 16(t6) // kernel block y   
    lw t12, 20(t6) // kernel block z

    mul a0, t12, t11 // threads per block in yz plane
    mul a0, a0, t10 // total threads per block
    mul t13, a0, t9
    mul t13, t13, t8
    mul t13, t13, t7 // total threads in kernel (grid * block)

    mul a1, t5, t11 // threadIdx.z * blockDim.y
    add a1, a1, t4 // + threadIdx.y
    mul a1, a1, t10 // * blockDim.x
    add a1, a1, t3 // + threadIdx.x (intra-block index)
    mul a2, t2, t8 // blockIdx.z contribution scaled by gridDim.y
    add a2, a2, t1 // combine with blockIdx.y
    mul a2, a2, t7 // scale by gridDim.x
    add a2, a2, t0 // add blockIdx.x
    mul a2, a2, a0 // convert block coordinates to thread offset
    add a0, a1, a2 // flat thread index across grid

// setup tls
    li t0, KERNEL_HEADER_MEM_TLS_BASE_ADDR
    lw t0, 0(t0)
    li t1, KERNEL_TLS_SIZE
    div t1, t1, t13 // tls size per thread
    mul t1, t1, a0 // tls offset for this thread
    add tp, t0, t1 // tls pointer

// setup stack
    li t0, KERNEL_HEADER_MEM_STACK_BASE_ADDR
    lw t0, 0(t0)
    li t1, KERNEL_STACK_SIZE
    div t1, t1, t13 // stack size per thread
    mul t1, t1, a0 // stack offset for this thread
    sub sp, t0, t1 // stack pointer

// setup params
    li t0, KERNEL_HEADER_MEM_PARAMS_SZ
    lw t0, 0(t0)
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

    mv t3, zero

setup_params_stack:
    add t4, t1, t2
    add t6, sp, t3
    lw t5, 0(t4)
    sw t5, 0(t6)
    addi t3, t3, 4
    addi t2, t2, 4
    blt t2, t0, setup_params_stack

launch_kernel:
    li t4, KERNEL_HEADER_MEM_KERNEL_PC
    lw t3, 0(t4)
    jalr x0, t3, 0
