# User-defined Commands

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
