#!/usr/bin/env python3
"""Dispatch shim — real logic lives in the project-type adapter (ADR-0011).

single_project's implementation: .agent/project_types/single_project/sync.py
"""

import os
import sys

ADAPTER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "adapter")

if __name__ == "__main__":
    os.execv(ADAPTER, [ADAPTER, "sync"] + sys.argv[1:])
