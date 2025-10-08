#include <rad_print.h>
#include <rad_defs.h>
#include "tinyprintf.h"

void rad_printf(const char* format, ...) {
    va_list args;
    va_start(args, format);
    
    char buffer[256];
    int len = tiny_vsnprintf(buffer, 256, format, args);
    
    volatile char* io_cout_addr = (volatile char*)IO_COUT;
    for (int i = 0; i < len && i < 256 - 1; i++) {
        *io_cout_addr = buffer[i];
    }
    
    va_end(args);
}