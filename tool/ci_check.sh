#!/usr/bin/env bash
# Preserve the command's exit status; expose bounded diagnostics via annotations
# for environments that cannot reach GitHub's external log-storage host.
set -uo pipefail
log=$(mktemp)
"$@" 2>&1 | tee "$log" | python3 -u -c '
import sys,re
previous=[]
for line in sys.stdin:
 print(line,end="",flush=True)
 if "All tests passed" in line:
  print("::notice title=Test summary::"+line.strip(),flush=True)
 previous.append(line.rstrip())
 previous=previous[-8:]
 if re.search(r"\[E\]|TimeoutException|EXCEPTION CAUGHT|Expected:|Actual:",line):
  text="\n".join(previous).replace("%","%25").replace("\r","%0D").replace("\n","%0A")
  print("::notice title=Live test diagnostics::"+text,flush=True)
' 
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  python3 - "$log" <<'PY'
import pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text(errors='replace')
text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
lines = text.splitlines()
indices = set(range(max(0,len(lines)-35),len(lines)))
for i,line in enumerate(lines):
    if re.search(r'error|exception|failed|Expected:|Actual:|Error:|warning|offset|hit test',line,re.I):
        indices.update(range(max(0,i-2),min(len(lines),i+8)))
selected='\n'.join(lines[i] for i in sorted(indices))[-14000:]
for start in range(0,len(selected),3500):
    chunk=selected[start:start+3500].replace('%','%25').replace('\r','%0D').replace('\n','%0A')
    print('::error title=Verification failure::'+chunk)
PY
fi
rm "$log"
exit "$status"
