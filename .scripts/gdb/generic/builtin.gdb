# Better GDB defaults ----------------------------------------------------------

set confirm off

# Download missing debug info and source files.
# set debuginfod enabled on

set max-completions unlimited

# c++
set demangle-style gnu-v3

set history filename ~/.gdb_history
# set history remove-duplicates 100
set history save on

set pagination off

set print array off
set print array-indexes on
set print elements 0
set print pretty on

# c++
set print asm-demangle on
set print demangle on
set print object on
set print static-members on
set print vtbl on

# Set mode for Python stack dump on error.
set python print-stack full

set remotetimeout 99999

set verbose off

set debuginfod enabled off

# dashboard registers -style list "rax rbx rcx rdx rsi rdi rbp rsp r8 r9 r10 r11 r12 r13 r14 r15 rip eflags cs ss ds es fs gs"
# fctrl fstat ftag fiseg fioff foseg fooff fop fs_base gs_base k_gs_base cr0 cr2 cr3 cr4 cr8 efer"
