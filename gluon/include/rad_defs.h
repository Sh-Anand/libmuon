#define GPU_MEM_START_ADDR       0x100

#define GPU_DRAM_SIZE (1ULL << 32) // 4GB

// A kernel's params block, which CSR_BP points a thread at: the params' size in bytes, then the params.
#define PARAMS_SIZE 0
#define PARAMS_START 4

// stack words of a warp's lanes are interleaved: word i of lane l is at 4 * (STACK_WORD_STRIDE * i + l).
// Kernels and everything linked into them are compiled with -mllvm -riscv-stack-word-stride of this.
#define STACK_WORD_STRIDE_SHIFT 5
#define STACK_WORD_STRIDE (1 << STACK_WORD_STRIDE_SHIFT)

// One stack region serves every kernel: only as many threads as the hardware has slots run at once,
// so _start carves it by slot.  A warp slot is an (SM, core, warp), a thread slot one of its lanes.
// The region holds the warp slots' interleaved stacks, then the thread slots' data stacks, then
// their TLS.
#define MAX_WARP_SLOTS 64     // SMs * cores * warps the region is sized for
#define WARP_STACK_SHIFT 15   // interleaved stack per warp slot: 32 KB, 256 words per thread
#define THREAD_STACK_SHIFT 10 // data stack per thread slot: 1 KB
#define THREAD_TLS_SHIFT 4    // TLS per thread slot: 16 bytes
#define WARP_STACKS_SIZE (MAX_WARP_SLOTS << WARP_STACK_SHIFT)
#define THREAD_STACKS_SIZE ((MAX_WARP_SLOTS << STACK_WORD_STRIDE_SHIFT) << THREAD_STACK_SHIFT)
#define THREAD_TLS_SIZE ((MAX_WARP_SLOTS << STACK_WORD_STRIDE_SHIFT) << THREAD_TLS_SHIFT)
#define STACK_REGION_SIZE (WARP_STACKS_SIZE + THREAD_STACKS_SIZE + THREAD_TLS_SIZE)
// 16 stack bytes are 4 words: frames keep their alignment, and va_arg reads a word's parity off its address
#define STACK_REGION_ALIGN (16 * STACK_WORD_STRIDE)

#define CSR_LANE_ID 0xcc0
#define CSR_WARP_ID 0xcc1
#define CSR_CORE_ID 0xcc2
#define CSR_CLUSTER_ID 0xcd0
#define CSR_NUM_WARPS 0xfc1 // per core
#define CSR_NUM_CORES 0xfc2 // per SM
#define CSR_BLOCK_IDX_X 0xfc3
#define CSR_BLOCK_IDX_Y 0xfc4
#define CSR_BLOCK_IDX_Z 0xfc5
#define CSR_THREAD_IDX_X 0xfc6
#define CSR_THREAD_IDX_Y 0xfc7
#define CSR_THREAD_IDX_Z 0xfc8
#define CSR_BP 0xfc9 // this kernel's params block
#define CSR_CMD_ID_LO 0xfcb // unique id of the launching command: stream id << 56 | per-stream command id
#define CSR_CMD_ID_HI 0xfcc
#define CSR_KERNEL_PC 0xfcd // the kernel _start jumps to

#define HW_STREAM_COUNT 4

#define IO_COUT 0xFF080000

// device C only: glibc's pthread rwlock has a field named __shared, and rad_start.S includes this
#if defined(__riscv) && !defined(__ASSEMBLER__)
#define __shared __attribute__((address_space(1))) // lowers loads/stores to .shared

// marks a kernel, a function that can be launched.  Kernels go in their own section, which is how
// the ELF loader tells them from ordinary functions.
#define __kernel__ __attribute__((section("rad_kernels")))

// Launch a grid of `kernel` from this thread: (gx, gy, gz) CTAs of (bx, by, bz) threads, each with
// `smem` bytes of shared memory.  `params` is its params block, which must stay in place until the
// launched threads have started.  The launching thread does not wait.  The kernel's id is filled in
// when the ELF is loaded, from the pair this leaves in .rad.launches: {the instruction, the kernel}.
#define rad_launch(kernel, gx, gy, gz, bx, by, bz, smem, params)                                    \
    do {                                                                                             \
        unsigned _w0 = (unsigned)(params), _w1 = (gx) | (gy) << 16, _w2 = (gz) | ((bz) - 1) << 24, \
                 _w3 = ((bx) - 1) | ((by) - 1) << 10 | ((smem) + 15) / 16 << 20;                    \
        asm volatile("1: vx_launch 0, %0, %1, %2, %3\n"                                             \
                     ".pushsection .rad.launches,\"\",@progbits\n"                                  \
                     ".word 1b, " #kernel "\n"                                                      \
                     ".popsection"                                                                   \
                     : : "r"(_w0), "r"(_w1), "r"(_w2), "r"(_w3) : "memory");                         \
    } while (0)

// vx_bar across the whole CTA
__attribute__((convergent)) static inline void __syncthreads() {
    asm volatile(".insn r 0x0b, 4, 0, x0, x0, x0" ::: "memory");
}

// this thread's index within its block, and its block's index within the grid
#define RAD_IDX(name, csr) \
    static inline unsigned name(void) { unsigned v; asm volatile("csrr %0, %1" : "=r"(v) : "i"(csr)); return v; }
RAD_IDX(rad_thread_idx_x, CSR_THREAD_IDX_X)
RAD_IDX(rad_thread_idx_y, CSR_THREAD_IDX_Y)
RAD_IDX(rad_thread_idx_z, CSR_THREAD_IDX_Z)
RAD_IDX(rad_block_idx_x, CSR_BLOCK_IDX_X)
RAD_IDX(rad_block_idx_y, CSR_BLOCK_IDX_Y)
RAD_IDX(rad_block_idx_z, CSR_BLOCK_IDX_Z)
#undef RAD_IDX
#endif
