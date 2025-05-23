# MIT License

# Copyright (c) 2022 Alan Li

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from __future__ import annotations

import atexit
import os
import re
import shutil
import site
import sys
import tempfile
import threading
import traceback
import typing as T
from glob import glob
from shutil import which
from string import ascii_letters
from subprocess import PIPE
from subprocess import Popen
from types import ModuleType

import gdb

directory, file = os.path.split(__file__)
directory = os.path.expanduser(directory)
directory = os.path.abspath(directory)
venv_path = os.path.join(directory, ".venv")
if os.path.exists(venv_path):
    sys.path.append(directory)
    site_pkgs_path = glob(os.path.join(venv_path, "lib/*/site-packages"))[0]
    site.addsitedir(site_pkgs_path)
else:
    try:
        """
        > curl -LjO https://files.pythonhosted.org/packages/5d/0f/2a8cf0881833cae8a2b50f0ce63ba4662c44473640c1feeb054f19d33459/prompt_toolkit-3.0.46.tar.gz
        > tar zxvf prompt_toolkit-3.0.46.tar.gz
        > cd prompt_toolkit-3.0.46
        > sudo ./setup.py install
        """
        import prompt_toolkit

        del prompt_toolkit
    except ImportError:
        print("Failed to find prompt_toolkit and venv is not found")
        sys.exit(1)

from prompt_toolkit import PromptSession
from prompt_toolkit import print_formatted_text
from prompt_toolkit.application import run_in_terminal
from prompt_toolkit.auto_suggest import AutoSuggestFromHistory
from prompt_toolkit.completion import CompleteEvent
from prompt_toolkit.completion import Completer
from prompt_toolkit.completion import Completion
from prompt_toolkit.document import Document
from prompt_toolkit.formatted_text import ANSI
from prompt_toolkit.formatted_text import FormattedText
from prompt_toolkit.history import FileHistory
from prompt_toolkit.history import History
from prompt_toolkit.history import InMemoryHistory
from prompt_toolkit.key_binding import KeyPressEvent
from prompt_toolkit.output import create_output
from prompt_toolkit.shortcuts import CompleteStyle

# global variables
HAS_FZF = which("fzf") is not None
HISTORY_FILENAME = ".gdb_history"
MULTI_LINE_COMMANDS = {"commands", "if", "while", "py", "python", "define", "document"}
# This sucks, but there's not a GDB API for checking dont-repeat now.
# I just collect some common used commands which should not be repeated.
# If you have some user-define function, add your command into the list manually.
# If you found a command should/shouldn't in this list, please let me know on the issue page, thanks!
DONT_REPEAT: set[str] = {
    # original GDB
    "attach",
    "run",
    "r",
    "detach",
    "help",
    "complete",
    "quit",
    "q",
    # for GEF
    "theme",
    "canary",
    "functions",
    "gef",
    "tmux-setup",
} | MULTI_LINE_COMMANDS

FZF_RUN_CMD = (
    "fzf",
    "--bind=tab:down",
    "--bind=btab:up",
    "--cycle",
    "--select-1",
    "--exit-0",
    "--tiebreak=index",
    "--no-multi",
    "--height=40%",
    "--layout=reverse",
)

FZF_PRVIEW_WINDOW_ARGS = (
    "--preview-window",
    "right:55%:wrap",
)

REAL_GDB_MODULE = gdb

try:
    from geprc import BINDINGS
    from geprc import DONT_REPEAT as USER_DONT_REPEAT

    DONT_REPEAT = DONT_REPEAT.union(USER_DONT_REPEAT)
except ImportError:
    from prompt_toolkit.key_binding import KeyBindings

    BINDINGS = KeyBindings()


# function for logging
def print_info(s: str) -> None:
    print_formatted_text(FormattedText([("#00FFFF", s)]), file=sys.__stdout__)


def print_warning(s: str) -> None:
    print_formatted_text(FormattedText([("#FFCC00", s)]), file=sys.__stdout__)


def common_prefix(m: list[str]) -> str:
    """
    Given a list of strings, returns the longest common leading component
    """
    if not m:
        return ""
    s1 = min(m)
    s2 = max(m)
    for i, c in enumerate(s1):
        if c != s2[i]:
            return s1[:i]
    return s1


if hasattr(gdb, "execute_mi"):  # This feature is only available in GDB 14.1 or later

    def get_gdb_completes(query: str) -> list[str]:
        return gdb.execute_mi("-complete", query)["matches"]  # type: ignore[attr-defined]
else:

    def get_gdb_completes(query: str) -> list[str]:
        completions_limit = T.cast(int, gdb.parameter("max-completions"))
        if completions_limit == -1:
            completions_limit = 0xFFFFFFFF
        if completions_limit == 0:
            return []
        if query.strip() and query[-1].isspace():
            # fuzzing all possible commands if the text before cursor endswith space
            all_completions = []
            for c in ascii_letters + "_-":
                if completions_limit <= 0:
                    break
                completions = gdb.execute(f"complete {query + c}", to_string=True).splitlines()[
                    :completions_limit
                ]
                all_completions.extend(completions)
                completions_limit -= len(completions)
        else:
            all_completions = gdb.execute(f"complete {query}", to_string=True).splitlines()[
                :completions_limit
            ]

        return all_completions


def safe_get_help_docs(command: str) -> str | None:
    """
    A wrapper for gdb.execute('help <command>', to_string=True), but return None if gdb raise an exception.
    """
    try:
        return gdb.execute(f"help {command}", to_string=True).strip()
    except gdb.error:
        return None


def should_get_help_docs(completion: str) -> bool:
    """
    Check if we need to get help docs for another completion that generated by same command.
    """
    if " " not in completion.strip():
        return True
    parent_command, _ = completion.rsplit(maxsplit=1)
    return safe_get_help_docs(parent_command) != safe_get_help_docs(completion)


def get_gdb_completion_and_status(query: str) -> tuple[list[str], bool]:
    """
    Return all possible completions and whether we need to get help docs for all completions.
    """
    all_completions = get_gdb_completes(query)
    # peek the first completion
    should_get_all_help_docs = False
    if all_completions:
        should_get_all_help_docs = should_get_help_docs(all_completions[0])
    return all_completions, should_get_all_help_docs


def create_fzf_process(query: str, preview: str = "") -> Popen:
    """
    Create a fzf process with given query and preview command.
    """
    if not HAS_FZF:
        raise ValueError("fzf is not installed")
    if query.startswith("!"):
        # ! in the beginning of query means we want to run the command directly for fzf
        query = "^" + query
    cmd: tuple[str, ...] = FZF_RUN_CMD + ("--query", query)
    if preview:
        cmd += FZF_PRVIEW_WINDOW_ARGS
        cmd += ("--preview", preview)
    return Popen(cmd, stdin=PIPE, stdout=PIPE, text=True)


def create_preview_fifos() -> tuple[str, str]:
    """
    Create a temporary directory and two FIFOs in it, return the paths of these FIFOs.

    This is modified from:
    https://github.com/infokiller/config-public/blob/652b4638a0a0ffed9743fa9e0ad2a8d4e4e90572/.config/ipython/profile_default/startup/ext/fzf_history.py#L128
    """
    fifo_dir = tempfile.mkdtemp(prefix="gep_tab_fzf_")
    fifo_input_path = os.path.join(fifo_dir, "input")
    fifo_output_path = os.path.join(fifo_dir, "output")
    os.mkfifo(fifo_input_path)
    os.mkfifo(fifo_output_path)
    atexit.register(shutil.rmtree, fifo_dir)
    return fifo_input_path, fifo_output_path


def fzf_reverse_search(event: KeyPressEvent) -> None:
    """Reverse search history with fzf."""

    def _fzf_reverse_search() -> None:
        # run_in_terminal will hide the prompt, we show the prompt while running fzf
        # so user can see the original prompt while selecting completions, which is more user-friendly
        event.app.renderer.render(event.app, event.app.layout, is_done=True)

        if not os.path.exists(HISTORY_FILENAME):
            # just create an empty file
            with open(HISTORY_FILENAME, "w"):
                pass
        p = create_fzf_process(event.app.current_buffer.document.text_before_cursor)
        with open(HISTORY_FILENAME) as f:
            visited = set()
            # Reverse the history, and only keep the youngest and unique one
            for line in f.read().strip().split("\n")[::-1]:
                if line and line not in visited:
                    visited.add(line)
                    p.stdin.write(line + "\n")
        stdout, _ = p.communicate()
        if stdout:
            event.app.current_buffer.document = Document()  # clear buffer
            event.app.current_buffer.insert_text(stdout.strip())

        # remove the prompt we showed after running fzf
        event.app.output.cursor_up(T.cast(str, gdb.parameter("prompt")).count("\n") + 1)
        event.app.renderer.erase()

    run_in_terminal(_fzf_reverse_search)


def fzf_tab_autocomplete(event: KeyPressEvent) -> None:
    """
    Tab autocomplete with fzf.
    """

    def _fzf_tab_autocomplete() -> None:
        target_text = (
            event.app.current_buffer.document.text_before_cursor.lstrip()
        )  # Ignore leading whitespaces
        all_completions, should_get_all_help_docs = get_gdb_completion_and_status(target_text)
        if not all_completions:
            return

        # run_in_terminal will hide the prompt, we show the prompt while running fzf
        # so user can see the original prompt while selecting completions, which is more user-friendly
        event.app.renderer.render(event.app, event.app.layout, is_done=True)

        prefix = common_prefix([common_prefix(all_completions), target_text])
        # TODO/FIXME: qeury might not be the expected one, e.g.
        # (gdb) complete b fun
        # b foo::B::func()
        # b funlockfile
        # The query should be "fun", but using the longest common prefix and split by non-word characters
        # We get "f" as the query
        # TODO/FIXME: For debugging C++/Rust code, we need more complex regex to get the more accurate query
        # Note: The behaviour might be different from different gdb versions
        query = re.split(r"\W+", prefix)[-1]
        if prefix:
            completion_idx = len(prefix) - len(query)
        else:
            completion_idx = 0
        p = create_fzf_process(query, FZF_PRVIEW_CMD if should_get_all_help_docs else None)
        completion_help_docs = {}
        for i, completion in enumerate(all_completions):
            if prefix.endswith("'" + query) and not completion.endswith("'"):
                # This is a heuristic to fix the weird behavior of gdb's `complete` command:
                # (gdb) complete p 'm
                # ...
                # p 'main
                p.stdin.write(completion[completion_idx:] + "'" + "\n")
            else:
                p.stdin.write(completion[completion_idx:] + "\n")
            if should_get_all_help_docs:
                completion_help_docs[i] = safe_get_help_docs(completion)
        t = FzfTabCompletePreviewThread(FIFO_INPUT_PATH, FIFO_OUTPUT_PATH, completion_help_docs)
        t.start()
        stdout, _ = p.communicate()
        t.stop()
        if stdout:
            # We might need to delete some characters before cursor if prefix + query != target_text
            event.app.current_buffer.delete_before_cursor(len(target_text) - len(prefix))
            stdout = stdout.rstrip()
            if (
                target_text.startswith(prefix + "'")
                and not stdout.startswith("'")
                and stdout.endswith("'")
            ):
                # This is a heuristic to fix the weird behavior of gdb's `complete` command:
                # (gdb) complete b 'm
                # ...
                # b main'
                # Note: The behaviour might be different from different gdb versions
                stdout = "'" + stdout
            event.app.current_buffer.insert_text(stdout[len(query) :].rstrip())

        # remove the prompt we showed after running fzf
        event.app.output.cursor_up(T.cast(str, gdb.parameter("prompt")).count("\n") + 1)
        event.app.renderer.erase()

    run_in_terminal(_fzf_tab_autocomplete)


class FzfTabCompletePreviewThread(threading.Thread):
    """
    A thread for previewing help docs of selected completion with fzf.

    This is modified from:
    https://github.com/infokiller/config-public/blob/master/.config/ipython/profile_default/startup/ext/fzf_history.py#L72
    """

    def __init__(
        self, fifo_input_path: str, fifo_output_path: str, completion_help_docs: dict, **kwargs
    ) -> None:
        super().__init__(**kwargs)
        self.fifo_input_path = fifo_input_path
        self.fifo_output_path = fifo_output_path
        self.completion_help_docs = completion_help_docs
        self.is_done = threading.Event()

    def run(self) -> None:
        while not self.is_done.is_set():
            with open(self.fifo_input_path, encoding="utf-8") as fifo_input:
                while not self.is_done.is_set():
                    data = fifo_input.read()
                    if len(data) == 0:
                        break
                    with open(self.fifo_output_path, "w", encoding="utf-8") as fifo_output:
                        try:
                            idx = int(data)
                        except ValueError:
                            continue
                        help_doc = self.completion_help_docs.get(idx)
                        if help_doc is not None:
                            fifo_output.write(help_doc)

    def stop(self) -> None:
        self.is_done.set()
        with open(self.fifo_input_path, "w", encoding="utf-8") as f:
            f.close()
        self.join()


class UserParameter(gdb.Parameter):
    gep_loaded = False

    def __init__(
        self,
        name: str,
        default_value: T.Any,
        set_show_doc: str,
        parameter_class: int,
        help_doc: str = "",
        enum_sequence: T.Sequence | None = None,
    ) -> None:
        self.set_show_doc = set_show_doc
        self.set_doc = f"Set {self.set_show_doc}."
        self.show_doc = f"Show {self.set_show_doc}."
        self.__doc__ = help_doc.strip() or None
        if enum_sequence:
            super().__init__(name, gdb.COMMAND_NONE, parameter_class, enum_sequence)
        else:
            super().__init__(name, gdb.COMMAND_NONE, parameter_class)
        self.value = default_value

    def get_set_string(self) -> str:
        if not self.gep_loaded:
            return ""
        svalue = self.value
        # TODO: Support other type when needed
        if isinstance(svalue, bool):
            svalue = "on" if svalue else "off"
        return f"Set {self.set_show_doc} to {svalue!r}."

    def get_show_string(self, svalue: T.Any) -> str:
        if not self.gep_loaded:
            return ""
        return f"{self.set_show_doc.capitalize()} is {svalue!r}."


single_column_tab_complete = UserParameter(
    "single-column-tab-complete",
    True,
    "whether to use single column for tab completion",
    gdb.PARAM_BOOLEAN,
)

if HAS_FZF:
    # key binding for fzf history search
    BINDINGS.add("c-r")(fzf_reverse_search)
    # key binding for fzf tab completion
    FIFO_INPUT_PATH, FIFO_OUTPUT_PATH = create_preview_fifos()
    FZF_PRVIEW_CMD = f"echo {{n}} > {FIFO_INPUT_PATH}\ncat {FIFO_OUTPUT_PATH}"
    BINDINGS.add("c-i")(fzf_tab_autocomplete)
else:
    print_warning("Install fzf for better experience with GEP")


class GDBHistory(FileHistory):
    """
    Manage your GDB History
    """

    def __init__(self, filename: str, ignore_duplicates: bool = False) -> None:
        self.ignore_duplicates = ignore_duplicates
        super().__init__(filename=filename)

    def load_history_strings(self) -> list[str]:
        strings = []
        if os.path.exists(self.filename):
            with open(self.filename) as f:
                for string in reversed(f.read().splitlines()):
                    if self.ignore_duplicates and string in strings:
                        continue
                    if string:
                        strings.append(string)
        return strings

    def store_string(self, string: str) -> None:
        with open(self.filename, "a") as f:
            f.write(string.strip() + "\n")


class GDBCompleter(Completer):
    """
    Completer of GDB
    """

    def __init__(self) -> None:
        super().__init__()

    def get_completions(
        self, document: Document, complete_event: CompleteEvent
    ) -> T.Iterator[Completion]:
        target_text = document.text_before_cursor.lstrip()  # Ignore leading whitespaces

        cursor_idx_in_completion = len(target_text)
        all_completions, should_get_all_help_docs = get_gdb_completion_and_status(target_text)
        if not all_completions:
            return

        for completion in all_completions:
            if not completion.startswith(target_text):
                # TODO/FIXME: This might cause some missing of completion for something like:
                # (gdb) complete b fun
                # b foo::B::func()
                # b funlockfile
                # b foo::B::func() will be ignored
                continue
            display_meta = (
                None if not should_get_all_help_docs else safe_get_help_docs(completion) or None
            )
            # remove some prefix of raw completion
            completion = completion[cursor_idx_in_completion:]
            # display readable completion based on the text before cursor
            display = re.split(r"\W+", target_text)[-1] + completion
            yield Completion(completion, display=display, display_meta=display_meta)


def emulate_prompt_hook(current_prompt: str) -> str:
    """
    Emulate the gdb.prompt_hook behavior
    """
    try:
        # emulate the original prompt
        current_prompt = gdb.prompt_hook(current_prompt) if gdb.prompt_hook else None
        if current_prompt:
            # If prompt_string is generated by gdb.prompt_hook, we update the prompt like native GDB
            safe_prompt_string = "".join(
                f"\\{ord(c):o}" if ord(c) < 0x100 else c for c in current_prompt
            )
            gdb.execute(f"set prompt {safe_prompt_string}", from_tty=False, to_string=True)
    except Exception as e:
        print(f"Python Exception {type(e)}: {e}")
    finally:
        if current_prompt is None:
            current_prompt = gdb.parameter("prompt")
    return current_prompt


def get_repeat_command(gdb_history: History) -> str:
    """
    Get the command to repeat
    """
    cmd_list = gdb_history.get_strings()
    if cmd_list:
        full_cmd = cmd_list[-1].strip()
        main_cmd = re.split(r"\W+", full_cmd)[0]
        if main_cmd.partition("/")[0] == "x":
            # Handle special case for `x/FMT` command
            # https://sourceware.org/gdb/current/onlinedocs/gdb.html/Memory.html
            # > If you use RET to repeat the x command, the repeat count n is used again; the other arguments default as for successive uses of x.
            return main_cmd
        elif main_cmd in ("list", "l") and not full_cmd.endswith("-"):
            # Handle special case for `list` command
            # https://sourceware.org/gdb/current/onlinedocs/gdb.html/List.html
            # > Repeating a list command with RET discards the argument, so it is equivalent to typing just list.
            # > An exception is made for an argument of ‘-’; that argument is preserved in repetition so that each repetition moves up in the source file.
            return main_cmd
        elif main_cmd not in DONT_REPEAT:
            return full_cmd
    return ""


def emulate_prompt(session: PromptSession, current_prompt: str, gdb_history: History) -> None:
    """
    Emulate the prompt after executing gdb.prompt_hook
    """
    # remove SOH (\001) and STX (\002) for prompt_toolkit
    full_cmd = session.prompt(ANSI(current_prompt.replace("\001", "").replace("\002", "")))
    main_cmd = re.split(r"\W+", full_cmd.strip())[0]
    quit_input_in_multiline_mode = False

    if not full_cmd.strip():
        full_cmd = get_repeat_command(gdb_history)
    elif main_cmd in MULTI_LINE_COMMANDS:

        def single_line_py(main_cmd: str, full_cmd: str) -> bool:
            # If full_cmd is something like: `py print(1)`, we don't need to handle multi-line input
            return main_cmd in ("py", "python") and full_cmd.strip() not in ("py", "python")

        first_cmd_is_py = main_cmd in ("py", "python")

        if not single_line_py(main_cmd, full_cmd):
            # TODO: Should we show more info when using `commands` or `define`?
            # e.g. In native GDB:
            # (gdb) commands
            # Type commands for breakpoint(s) 1, one per line.
            # End with a line saying just "end"
            # > (input goes here)
            stack_size = 1
            while stack_size > 0:
                full_cmd += "\n"
                try:
                    new_line = session.prompt(">".rjust(stack_size))
                except EOFError:
                    full_cmd += "end"
                    stack_size -= 1
                    continue
                except KeyboardInterrupt:
                    quit_input_in_multiline_mode = True
                    break
                main_cmd = re.split(r"\W+", new_line.strip())[0]
                if (
                    not first_cmd_is_py
                    and main_cmd in MULTI_LINE_COMMANDS
                    and not single_line_py(main_cmd, new_line)
                ):
                    stack_size += 1
                elif main_cmd == "end":
                    stack_size -= 1
                full_cmd += new_line

    if not quit_input_in_multiline_mode:
        # This is a hack to fix the issue when debugging the kernel with qemu-system-*
        # Without this hack, somehow pressing ctrl-c in GDB will not interrupt the kernel
        # See #23 for more details
        # TODO: Is there a better way to fix this issue?
        gdb.execute(
            f"""python
try: gdb.execute({full_cmd!r}, from_tty=True)
except gdb.error as e: print(e)
"""
        )


def gep_prompt(current_prompt: str) -> None:
    print_info("GEP is running now!")
    UserParameter.gep_loaded = True
    history_on = gdb.parameter("history save")
    if history_on:
        global HISTORY_FILENAME
        HISTORY_FILENAME = gdb.parameter("history filename")
        is_ignore_duplicates = -1 == gdb.parameter("history remove-duplicates")
        gdb_history = GDBHistory(HISTORY_FILENAME, ignore_duplicates=is_ignore_duplicates)
    else:
        print_warning("`set history save on` for better experience with GEP")
        gdb_history = InMemoryHistory()
    session: PromptSession = PromptSession(
        history=gdb_history,
        enable_history_search=True,
        auto_suggest=AutoSuggestFromHistory(),
        completer=GDBCompleter() if not HAS_FZF else None,
        complete_style=CompleteStyle.COLUMN
        if single_column_tab_complete.value
        else CompleteStyle.MULTI_COLUMN,
        complete_while_typing=False,
        key_bindings=BINDINGS,
        output=create_output(stdout=sys.__stdout__),
    )
    while True:
        current_prompt = emulate_prompt_hook(current_prompt)
        try:
            emulate_prompt(session, current_prompt, gdb_history)
        except KeyboardInterrupt:
            pass
        except EOFError:
            gdb.execute("quit")
        except Exception as e:
            print(e)
            traceback.print_tb(e.__traceback__)


def hijack_prompt(original_prompt: T.Callable | None) -> None:
    """
    Hijack the original prompt and use GEP prompt
    """

    def hijacked_prompt(current_prompt: str) -> None:
        global REAL_GDB_MODULE
        global gdb
        # If gdb.prompt_hook is called by user before first prompt, f_back will not be None
        # So, we need to call the original prompt_hook instead of gep_prompt
        if sys._getframe().f_back is not None:
            result = original_prompt(current_prompt)
            if (
                REAL_GDB_MODULE.prompt_hook.__name__ != hijacked_prompt.__name__
                and REAL_GDB_MODULE.prompt_hook != hijack_prompt
            ):
                # prompt_hook is been overridden in user-defined prompt_hook, we need to re-hijack the prompt
                # We need to compare the name here because the prompt_hook might be re-hijacked by us if the __setattr__ of GdbModuleWrapper is called
                hijack_prompt(REAL_GDB_MODULE.prompt_hook)
            return result
        REAL_GDB_MODULE.prompt_hook = original_prompt  # retrieve old prompt hook
        sys.modules["gdb"] = gdb = REAL_GDB_MODULE  # we don't need to re-hijack the prompt anymore
        gep_prompt(current_prompt)  # pass the current_prompt to gep_prompt

    REAL_GDB_MODULE.prompt_hook = hijacked_prompt


def hijack_gdb() -> None:
    """
    Hijack the original gdb module and replace it with our own to hijack the prompt
    """
    global REAL_GDB_MODULE
    global gdb

    hijack_prompt(REAL_GDB_MODULE.prompt_hook)

    class GdbModuleWrapper(ModuleType):
        """
        A wrapper for `gdb` module to make sure we can import GEP at any time
        """

        def __getattr__(self, name: str) -> T.Any:
            return getattr(REAL_GDB_MODULE, name)

        def __setattr__(self, name: str, value: T.Any) -> None:
            if name == "prompt_hook" and gdb != REAL_GDB_MODULE:
                # Before first prompt_hook, re-hijack the prompt
                hijack_prompt(value)
                return
            setattr(REAL_GDB_MODULE, name, value)

    sys.modules["gdb"] = gdb = GdbModuleWrapper("gdb", getattr(gdb, "__doc__", ""))


def main() -> None:
    # source the gdbinit-gep config in the same directory
    # gep_path = os.path.dirname(os.path.realpath(__file__))
    # gdb.execute(f"source {os.path.join(gep_path, 'gdbinit-gep')}")

    # Hijack the gdb module to use our own prompt
    hijack_gdb()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        traceback.print_tb(e.__traceback__)
        print_warning(
            "Something went wrong when running GEP, please report an issue on https://github.com/lebr0nli/GEP/issues with the traceback above, thanks!"
        )
