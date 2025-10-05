#include <rad_defs.h>

.global _start
.type _start, @function
_start:
    lw t0, %lo(KERNEL_HEADER_MEM_PARAMS_SZ)(zero)
    beqz t0, launch_kernel

launch_kernel:
    lw t3, %lo(KERNEL_HEADER_MEM_KERNEL_PC)(zero)
    jalr x0, t3, 0
