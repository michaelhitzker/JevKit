#!/usr/bin/env python3
"""Validate committed release metadata without modifying the checkout."""
import re
import sys
from pathlib import Path


def validate(version, root):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Use a stable major.minor.patch version without a v prefix.")
    if (root / "VERSION").read_text().strip() != version:
        raise ValueError("The requested version must match the committed VERSION file.")



if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("Usage: validate-release.py MAJOR.MINOR.PATCH")
        validate(sys.argv[1], Path(__file__).resolve().parent.parent)
    except ValueError as error:
        sys.exit(str(error))
    print("Release metadata is valid.")
