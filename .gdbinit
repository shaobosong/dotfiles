# Source files -----------------------------------------------------------------

# GDB Enhanced Prompt
source ~/.gdb/python/gep.py

# GDB Dashboard
source ~/.gdb/python/dashboard.py

# GDB C++
source ~/.gdb/python/cpp.py

# Better GDB defaults ----------------------------------------------------------

set confirm off

# Download missing debug info and source files.
# set debuginfod enabled on

# c++
set demangle-style gnu-v3

set history filename ~/.gdb_history
set history remove-duplicates 100
set history save on

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

# Miscellaneous ----------------------------------------------------------------

# qemu-monitor
define qmon
    call monitor_init_hmp(qemu_chr_new("compat_monitor0", "stdio", 0), 1, 0)
    call handle_hmp_command(qemu_chr_find("compat_monitor0").be.opaque, $arg0)
end

document qmon
qmon STR -- emit a directive to HMP monitor when debug qemu.
end

define tstepi
    if $schedule_multiple
        set schedule-multiple off
        stepi
        set schedule-multiple on
    else
        si
    end
end

document tstepi
Step one instruction with thread locking, but proceed through subroutine calls.
Temporarily disable other threads during stepping.
end

alias tsi = tstepi

define tnexti
    if $schedule_multiple
        set schedule-multiple off
        nexti
        set schedule-multiple on
    else
        si
    end
end

document tnexti
Step one instruction with thread locking.
Temporarily disable other threads during stepping.
end

alias tni = tnexti

define tstep
    if $schedule_multiple
        set schedule-multiple off
        step
        set schedule-multiple on
    else
        si
    end
end

document tstep
Step program with thread locking until it reaches a different source line.
Temporarily disable other threads during stepping.
end

alias ts = tstep

define tnext
    if $schedule_multiple
        set schedule-multiple off
        next
        set schedule-multiple on
    else
        si
    end
end

document tnext
Step program with thread locking, and step over the subroutine calls.
Temporarily disable other threads during stepping.
end

alias tn = tnext

dashboard registers -style list "rax rbx rcx rdx rsi rdi rbp rsp r8 r9 r10 r11 r12 r13 r14 r15 rip eflags cs ss ds es fs gs"
# fctrl fstat ftag fiseg fioff foseg fooff fop fs_base gs_base k_gs_base cr0 cr2 cr3 cr4 cr8 efer"
