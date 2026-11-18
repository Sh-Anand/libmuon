#include <rad_defs.h>

// only touches ra, sp, gp, tp, t0-t2, a0-a7: registers are never freed, so every
// register written here counts against each warp for the whole kernel

.global _start
.type _start, @function
_start:
    csrr t2, CSR_BP

// setup stacks and tls from this thread's hardware slot, in the region every kernel shares.  Frames
// are interleaved across a warp's lanes (-riscv-stack-word-stride), so the lanes share the warp
// slot's stack with stack pointers 4 bytes apart; gp is a data stack for what cannot be interleaved.
    csrr a0, CSR_CLUSTER_ID
    csrr a1, CSR_NUM_CORES
    mul a0, a0, a1
    csrr a1, CSR_CORE_ID
    add a0, a0, a1
    csrr a1, CSR_NUM_WARPS
    mul a0, a0, a1
    csrr a1, CSR_WARP_ID
    add a0, a0, a1 // warp slot
    csrr a2, CSR_LANE_ID
    slli a1, a0, STACK_WORD_STRIDE_SHIFT
    add a1, a1, a2 // thread slot
    lla t0, rad_stack_region
    lw t0, 0(t0)

    addi a0, a0, 1
    slli a0, a0, WARP_STACK_SHIFT
    add a0, t0, a0 // top of the warp slot's stack
    slli a2, a2, 2
    add sp, a0, a2 // stack pointer

    li a0, WARP_STACKS_SIZE
    add t0, t0, a0
    addi a0, a1, 1
    slli a0, a0, THREAD_STACK_SHIFT
    add gp, t0, a0 // data stack pointer

    li a0, THREAD_STACKS_SIZE
    add t0, t0, a0
    slli a0, a1, THREAD_TLS_SHIFT
    add tp, t0, a0 // tls pointer

// setup params: words past the first 8 go on the stack, then the first 8 into a0-a7
    lw t0, PARAMS_SIZE(t2)
    addi t1, t2, PARAMS_START // params start
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
    csrr t2, CSR_KERNEL_PC
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

// base of the stack region, set in the image by the host before it is copied to the device
.data
.balign 4
.global rad_stack_region
rad_stack_region:
    .word 0
// the params ring: its base, set by the host as above, and the tail device launches add to
.global rad_params_ring
rad_params_ring:
    .word 0
.global rad_params_tail
rad_params_tail:
    .word 0
