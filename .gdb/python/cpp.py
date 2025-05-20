"""
Enhanced libstdc++ Pretty Printers Loader for GDB
"""

import sys
import os
import glob
import gdb
from pathlib import Path
from typing import Optional, Tuple

class StdCppPrinterLoader:
    """Main loader class for libstdc++ pretty printers"""

    # Path templates with version-aware patterns
    SEARCH_TEMPLATES = [
        # GCC version-specific paths (modern installations)
        '/usr/share/gcc-*/python',
        '/usr/lib/gcc/*/*/*/python',  # Multi-arch support

        # Legacy paths (traditional distributions)
        '/usr/share/gcc/python',
        '/usr/local/share/gcc/python',
        '/usr/lib/../share/gcc/python',  # Fedora/RHEL

        # User-local installations
        str(Path.home() / '.local/share/gcc/python'),
    ]

    @classmethod
    def _expand_glob_paths(cls) -> list[str]:
        """
        Expand all potential search paths using glob patterns

        Returns:
            List of concrete paths sorted by version (newest first)
        """
        expanded_paths = []
        for template in cls.SEARCH_TEMPLATES:
            try:
                matches = glob.glob(template)
                # Sort matches to prioritize newer versions
                expanded_paths.extend(sorted(matches, reverse=True))
            except Exception as e:
                continue
        return expanded_paths

    @classmethod
    def _validate_printer_path(cls, base_path: str) -> Optional[Tuple[str, str]]:
        """
        Validate if a path contains actual pretty printers

        Args:
            base_path: Candidate path to check

        Returns:
            Tuple of (python_path, printer_path) if valid, None otherwise
        """
        python_path = os.path.dirname(base_path)  # Parent directory for Python imports
        printer_module = os.path.join(base_path, 'libstdcxx', 'v6', 'printers.py')

        if os.path.exists(printer_module):
            return (python_path, base_path)
        return None

    @classmethod
    def find_best_printer_path(cls) -> Optional[Tuple[str, str]]:
        """
        Locate the most appropriate printer path

        Returns:
            Optimal (python_path, printer_path) tuple or None if not found
        """
        for path in cls._expand_glob_paths():
            validated = cls._validate_printer_path(path)
            if validated:
                return validated
        return None

    @classmethod
    def register_printers(cls, verbose: bool = True) -> bool:
        """
        Register libstdc++ pretty printers with GDB

        Args:
            verbose: Whether to output status messages

        Returns:
            True if successful, False otherwise
        """
        try:
            # Locate the printer installation
            path_result = cls.find_best_printer_path()
            if not path_result:
                if verbose:
                    cls._print_search_failure()
                return False

            python_path, printer_path = path_result

            # Ensure single registration
            if python_path not in sys.path:
                sys.path.insert(0, python_path)

            # Dynamic module loading
            import importlib.util
            spec = importlib.util.spec_from_file_location(
                "libstdcxx_printers",
                os.path.join(printer_path, 'libstdcxx', 'v6', 'printers.py')
            )
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            # Registration with current GDB context
            objfile = gdb.current_objfile() or gdb
            module.register_libstdcxx_printers(objfile)

            if verbose:
                gdb.write(f"Loaded libstdc++ printers from: {printer_path}\n")
            return True

        except Exception as e:
            if verbose:
                gdb.write(f"Printer registration failed: {str(e)}\n")
            return False

    @classmethod
    def _print_search_failure(cls):
        """Output detailed debug information when printers aren't found"""
        gdb.write("libstdc++ printers not found. Search paths attempted:\n")
        for template in cls.SEARCH_TEMPLATES:
            gdb.write(f"  • {template}\n")
        gdb.write("\nSuggested solution:\n")
        gdb.write("1. Install development package: 'gcc-gdb-plugin' or 'libstdc++-dev'\n")
        gdb.write("2. Verify GCC version matches Python support files\n")

def main() -> None:
        # Automatic registration handling
    if hasattr(gdb, 'current_objfile'):
        # Immediate registration if possible
        StdCppPrinterLoader.register_printers()
    else:
        # Deferred registration for early initialization
        gdb.write("Note: libstdc++ printers will auto-load with first object file\n")
        gdb.events.new_objfile.connect(
            lambda event: StdCppPrinterLoader.register_printers()
        )

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        traceback.print_tb(e.__traceback__)
        print_warning(
            "Something went wrong when running cpp.py!"
        )
