# https://github.com/plusls/gdb-fzf/blob/main/gdb-fzf.py

import base64
import ctypes
from typing import List, Tuple
import subprocess
import gdb
import os
import asyncio
import threading

HELP = True


class HIST_ENTRY(ctypes.Structure):
    _fields_ = [
        ('line', ctypes.c_char_p),
        ('timestamp', ctypes.c_char_p),
        ('data', ctypes.c_void_p),
    ]


def get_libreadline() -> ctypes.CDLL:
    libreadline = ctypes.CDLL('libreadline.so.8')
    # HIST_ENTRY** history_list()
    libreadline.history_list.restype = ctypes.POINTER(
        ctypes.POINTER(HIST_ENTRY))

    # int rl_generic_bind (const char *keyseq, rl_command_func_t *function)
    libreadline.rl_bind_keyseq.argtypes = (
        ctypes.c_char_p, ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int, ctypes.c_int))
    libreadline.rl_bind_keyseq.restype = ctypes.c_int

    # void rl_add_undo (enum undo_code, int, int, char * text);
    # enum undo_code { UNDO_DELETE, UNDO_INSERT, UNDO_BEGIN, UNDO_END };
    libreadline.rl_add_undo.argtypes = (
        ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_char_p)

    # int rl_delete_text (int from, int to)
    libreadline.rl_delete_text.argtypes = (ctypes.c_int, ctypes.c_int)
    libreadline.rl_delete_text.restype = ctypes.c_int

    # int rl_insert_text (const char *string)
    libreadline.rl_insert_text.argtypes = (ctypes.c_char_p, )
    libreadline.rl_insert_text.restype = ctypes.c_int

    # int rl_forced_update_display
    libreadline.rl_forced_update_display.restype = ctypes.c_int

    # int rl_crlf
    # libreadline.rl_crlf.restype = ctypes.c_int

    return libreadline


@ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int, ctypes.c_int)
def fzf_search_history(sign: int, key: int) -> int:
    libreadline = get_libreadline()
    history_list = get_history_list(libreadline)
    # libreadline.rl_crlf()
    rl_line_buffer_ptr = ctypes.c_char_p.in_dll(libreadline, "rl_line_buffer")
    query = ctypes.string_at(rl_line_buffer_ptr)
    make_readline_line(libreadline, get_fzf_result(query, history_list))
    libreadline.rl_forced_update_display()
    return 0


def run_gdb_command(command: str) -> bytes:
    memfd = os.memfd_create("gdb-output", 0)
    pid = os.getpid()
    # 如果直接用 gdb.execute（‘complete xxx'), 若是 xxx 以空格结尾则会存在截断
    gdb.execute(f"pipe {command}| cat >/proc/{pid}/fd/{memfd}", to_string=True)
    with os.fdopen(memfd, 'rb') as f:
        return f.read()


do_generate_help_file_stop = False


def do_generate_help_file(items: List[bytes], memfd: int):
    for i in items:

        i = i.strip()
        i = i.split(b'\n')[0].split(b'|')[0]

        if not i:
            continue
        try:
            s = base64.b64encode(gdb.execute(
                f'help {i.decode()}', to_string=True).encode())
            s += b',' + i + b'\n'
            os.write(memfd, s)
        except:
            pass

        if do_generate_help_file_stop:
            break


def generate_help_file(items: List[bytes]) -> Tuple[int, threading.Thread]:
    memfd = os.memfd_create("gdb-help-file", 0)
    t = threading.Thread(target=do_generate_help_file,
                         args=(items, memfd))
    t.start()
    return memfd, t


@ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int, ctypes.c_int)
def fzf_auto_complete(sign: int, key: int) -> int:
    libreadline = get_libreadline()
    # libreadline.rl_crlf()
    rl_line_buffer_ptr = ctypes.c_char_p.in_dll(libreadline, "rl_line_buffer")
    query = ctypes.string_at(rl_line_buffer_ptr)
    query_str = query.decode()

    query_complete_str_list = get_history_list(libreadline)

    if query_str.endswith(' '):
        query_complete_str_list += run_gdb_command(
            f'complete {query_str}').split(b'\n')
    else:
        query_complete_str_list += run_gdb_command(
            f'complete {query_str} ').split(b'\n')
        idx = query_str.rfind(" ")
        if idx == -1:
            s = ''
        else:
            s = query_str[:idx]
        query_complete_str_list += run_gdb_command(
            f'complete {s} ').split(b'\n')
    make_readline_line(libreadline, get_fzf_result(
        query, query_complete_str_list))
    libreadline.rl_forced_update_display()

    return 0


def make_readline_line(libreadline: ctypes.CDLL, s: bytes):
    rl_line_buffer_ptr = ctypes.c_char_p.in_dll(libreadline, "rl_line_buffer")
    rl_line_buffer = ctypes.string_at(rl_line_buffer_ptr)
    rl_point_ptr = ctypes.c_int.in_dll(libreadline, "rl_point")
    rl_end_ptr = ctypes.c_int.in_dll(libreadline, "rl_end")
    rl_mark_ptr = ctypes.c_int.in_dll(libreadline, "rl_mark")

    if s != rl_line_buffer:
        libreadline.rl_add_undo(2, 0, 0, None)
        libreadline.rl_delete_text(0, rl_point_ptr.value)
        rl_point_ptr.value = 0
        rl_end_ptr.value = 0
        rl_mark_ptr.value = 0
        libreadline.rl_insert_text(s)
        libreadline.rl_add_undo(3, 0, 0, None)


def get_history_list(libreadline: ctypes.CDLL) -> List[bytes]:
    hlist = libreadline.history_list()
    ret: List[bytes] = []
    if not hlist:
        return ret
    i = 0
    while True:
        history = hlist[i]
        if not history:
            break
        ret.append(history[0].line)
        i += 1

    return ret


def get_fzf_result(query: bytes, items: List[bytes]) -> bytes:

    global do_generate_help_file_stop
    do_generate_help_file_stop = False

    if not items:
        return query

    # drop duplicates
    seen = set()
    items = [
        s for s in (i.strip() for i in reversed(items))
        if not (s in seen or seen.add(s))
    ]

    if HELP:
        help_fd, t = generate_help_file(items)

    echo_str = "{..}$"
    pid = os.getpid()
    args = [
        "fzf",
        '--print0',
        '--read0',
        "--bind=tab:down",
        "--bind=btab:up",
        # "--cycle",
        # "--select-1",
        "--exit-0",
        "--tiebreak=index",
        "--no-multi",
        "--height=40%",
        # '--layout=reverse',
        '--print-query',
        # '--tac',
        '--query', query.decode(),
    ]

    if HELP:
        args += [
            '--preview',
            f'cat /proc/{pid}/fd/{help_fd}|grep {echo_str}|awk -F, \'{{print $1}}\'|base64 -d',
        ]

    p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    assert (p.stdin)
    assert (p.stdout)
    out = b'\x00'.join([i for i in items if i])
    p.stdin.write(out)
    p.stdin.close()
    p.wait()
    res_array = p.stdout.read().split(b'\x00')[:-1]

    if HELP:
        do_generate_help_file_stop = True
        t.join()
        os.close(help_fd)

    if not res_array:
        res = query
    else:
        res = res_array[-1]

    return res


def gdb_fzf():
    libreadline = get_libreadline()
    assert (libreadline.rl_bind_keyseq(b"\\C-r", fzf_search_history) == 0)
    # assert (libreadline.rl_bind_keyseq(b"\\t", fzf_auto_complete) == 0)


def main():
    gdb_fzf()


main()
