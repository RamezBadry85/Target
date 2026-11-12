"""Transport isolated CI fixtures only; 4 KiB/annotation, 10 annotations/step."""
from pathlib import Path
import sys
encoded = Path(sys.argv[1]).read_text()
part = int(sys.argv[2])
for start in range(part * 40000, min((part + 1) * 40000, len(encoded)), 4000):
    print(f'::notice title=Actual sample files {start//4000}::{encoded[start:start+4000]}')
