#!/usr/bin/python3 -I
"""Launch the bundled observer from this installed plugin only."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dock_doctor.service import main

if __name__ == "__main__":
    main()
