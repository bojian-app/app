"""Read-only release verification; print only transport metadata."""
import json
import subprocess
from collections import Counter

raw = subprocess.check_output(['docker','logs','--since','5m','bojian-api-1'], stderr=subprocess.STDOUT).decode()
paths = {'/api/v1/realtime', '/api/v1/realtime/token', '/api/v1/realtime/events'}
counts = Counter()
longest = 0
for line in raw.splitlines():
    try:
        row = json.loads(line)
    except ValueError:
        continue
    if row.get('path') in paths:
        counts[(row['path'], row.get('status'))] += 1
        if row['path'] in {'/api/v1/realtime', '/api/v1/realtime/events'}:
            longest = max(longest, row.get('duration_ms', 0))
for (path,status),count in sorted(counts.items(), key=lambda entry: str(entry[0])):
    print(f'{path}: status={status}, requests={count}')
print(f'Longest completed realtime connection: {longest} ms')
raw = subprocess.check_output(['docker','logs','--since','5m','bojian-caddy-1'], stderr=subprocess.STDOUT).decode()
counts = Counter()
for line in raw.splitlines():
    try:
        row = json.loads(line)
    except ValueError:
        continue
    path = row.get('request',{}).get('uri','').split('?',1)[0]
    if path in paths:
        counts[(path,row.get('status'))] += 1
for (path,status),count in sorted(counts.items(), key=lambda entry: str(entry[0])):
    print(f'Proxy {path}: status={status}, requests={count}')
