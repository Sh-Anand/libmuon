#include <rad_defs.h>

// only touches ra, sp, gp, tp, t0-t2, a0-a7: registers are never freed, so every
// register written here counts against each warp for the whole kernel

.global _start
.type _start, @function
_start:
    csrr t2, CSR_BP
    lw a0, KERNEL_HEADER_MEM_GRID_X(t2)
    lw a1, KERNEL_HEADER_MEM_GRID_Y(t2)
    lw a2, KERNEL_HEADER_MEM_GRID_Z(t2)
    lw a3, KERNEL_HEADER_MEM_BLOCK_X(t2)
    lw a4, KERNEL_HEADER_MEM_BLOCK_Y(t2)
    lw a5, KERNEL_HEADER_MEM_BLOCK_Z(t2)

    csrr a6, CSR_THREAD_IDX_Z
    mul a6, a6, a4 // threadIdx.z * blockDim.y
    csrr a7, CSR_THREAD_IDX_Y
    add a6, a6, a7 // + threadIdx.y
    mul a6, a6, a3 // * blockDim.x
    csrr a7, CSR_THREAD_IDX_X
    add a6, a6, a7 // + threadIdx.x (intra-block index)

    csrr a7, CSR_BLOCK_IDX_Z
    mul a7, a7, a1 // blockIdx.z * gridDim.y
    csrr t0, CSR_BLOCK_IDX_Y
    add a7, a7, t0 // + blockIdx.y
    mul a7, a7, a0 // * gridDim.x
    csrr t0, CSR_BLOCK_IDX_X
    add a7, a7, t0 // + blockIdx.x (flat block index)

    mul a5, a5, a4
    mul a5, a5, a3 // total threads per block
    mul a7, a7, a5 // convert block index to thread offset
    add a6, a6, a7 // flat thread index across grid
    mul a5, a5, a2
    mul a5, a5, a1
    mul a5, a5, a0 // total threads in kernel (grid * block)

// setup tls
    lw t0, KERNEL_HEADER_MEM_TLS_BASE_ADDR(t2)
    li t1, KERNEL_TLS_SIZE
    div t1, t1, a5 // tls size per thread
    andi t1, t1, -16 // align per-thread tls to 16 bytes
    mul t1, t1, a6 // tls offset for this thread
    add tp, t0, t1 // tls pointer

// setup stacks: the stack region's upper half holds a data stack per thread (gp), its lower half
// the interleaved stacks (sp).  Frames are interleaved across a warp's lanes
// (-riscv-stack-word-stride), so its lanes share one region with stack pointers 4 bytes apart;
// gp holds what cannot be interleaved.
    lw t0, KERNEL_HEADER_MEM_STACK_BASE_ADDR(t2)
    li t1, KERNEL_STACK_SIZE / 2
    div a0, t1, a5 // size per thread, of each stack
    andi a0, a0, -16
    mul a1, a0, a6
    sub gp, t0, a1
    andi gp, gp, -16 // data stack pointer
    csrr a2, CSR_LANE_ID
    sub a1, a6, a2 // the warp's first thread
    mul a1, a0, a1
    sub t0, t0, t1
    sub a1, t0, a1
    // top of the warp's region: 16 stack bytes are 4 words, so frames keep their alignment and
    // va_arg can read a word's parity off its address
    andi a1, a1, -(16 * STACK_WORD_STRIDE)
    slli a2, a2, 2
    add sp, a1, a2 // stack pointer

// setup params: words past the first 8 go on the stack, then the first 8 into a0-a7
    lw t0, KERNEL_HEADER_MEM_PARAMS_SZ(t2)
    addi t1, t2, KERNEL_HEADER_MEM_END // params start
    add t0, t1, t0 // params end
    addi a0, t1, 32 // first stack param
    mv a1, sp

setup_params_stack:
    bgeu a0, t0, setup_params_regs
    lw a2, 0(a0)
    sw a2, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4 * STACK_WORD_STRIDE
    j setup_params_stack

setup_params_regs:
    lw t2, KERNEL_HEADER_MEM_KERNEL_PC(t2)
    beq t1, t0, launch_kernel
    lw a0, 0(t1)
    addi t1, t1, 4
    beq t1, t0, launch_kernel
    lw a1, 0(t1)
    addi t1, t1, 4
    beq t1, t0, launch_kernel
    lw a2, 0(t1)
    addi t1, t1, 4
    beq t1, t0, launch_kernel
    lw a3, 0(t1)
    addi t1, t1, 4
    beq t1, t0, launch_kernel
    lw a4, 0(t1)
    addi t1, t1, 4
    beq t1, t0, launch_kernel
    lw a5, 0(t1)
    addi t1, t1, 4
    beq t1, t0, launch_kernel
    lw a6, 0(t1)
    addi t1, t1, 4
    beq t1, t0, launch_kernel
    lw a7, 0(t1)

launch_kernel:
    mv ra, zero
    jalr x0, t2, 0
