"""Deploy foreground realtime outbox and replay with guarded rollback."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import time

root = Path('/home/ubuntu/bojian-backend')
release = Path('/home/ubuntu/bojian-realtime-20261009-r2')
old_image = 'bojian-api:realtime-20261009-r1'
new_image = 'bojian-api:realtime-20261009-r2'
compose = root / 'compose.production.yaml'
backup = release / 'compose.production.before.yaml'
overlay = root / 'deploy/compose.admin.yaml'
overlay_backup = release / 'compose.admin.before.yaml'
# Built from backend commit d21916b838593ce64bd9800d274fe303808267a2.

def run(args):
    subprocess.run(args, cwd=root, check=True)

current = subprocess.check_output(['docker', 'inspect', 'bojian-api-1', '--format', '{{.Config.Image}}']).decode().strip()
if current != old_image or (backup.exists() and backup.read_bytes() != compose.read_bytes()):
    raise SystemExit('Baseline changed; inspect before deploying')
if hashlib.sha256((release / 'bojian-api-realtime').read_bytes()).hexdigest() != '10c1265e21a28d29c7bf5c2b4d1fffbbec0aebb065c899eb9898c3302214a11a':
    raise SystemExit('Binary checksum mismatch')
running_hash = subprocess.check_output(['docker', 'exec', 'bojian-api-1', 'sha256sum', '/usr/local/bin/bojian-api']).decode().split()[0]
if running_hash != '56239d3189dcb4efe977b78d909e0a2f68ce28d5d91e924f3e3254d9f1f59760':
    raise SystemExit('Running binary baseline changed')
text = compose.read_text()
overlay_text = overlay.read_text()
if text.count('image: ' + old_image) != 1:
    raise SystemExit('Unexpected compose image configuration')
if overlay_text.count('image: ' + old_image) != 1:
    raise SystemExit('Unexpected compose overlay image configuration')
if overlay_backup.exists() and overlay_backup.read_bytes() != overlay.read_bytes():
    raise SystemExit('Compose overlay baseline changed')
if not backup.exists():
    shutil.copy2(compose, backup)
if not overlay_backup.exists():
    shutil.copy2(overlay, overlay_backup)
(release / 'bojian-api-realtime').chmod(0o755)
(release / 'Dockerfile').write_text('FROM ' + old_image + '\nCOPY bojian-api-realtime /usr/local/bin/bojian-api\n')
run(['docker', 'build', '-t', new_image, str(release)])
compose_args = ['docker', 'compose', '--env-file', '.env.production', '--env-file', 'deploy/release.env', '-f', 'compose.production.yaml', '-f', 'deploy/compose.admin.yaml']
try:
    compose.write_text(text.replace('image: ' + old_image, 'image: ' + new_image))
    overlay.write_text(overlay_text.replace('image: ' + old_image, 'image: ' + new_image))
    run(compose_args + ['config', '--quiet'])
    run(compose_args + ['up', '-d', '--no-deps', '--no-build', 'api'])
    for attempt in range(20):
        ready = subprocess.run(['docker', 'exec', 'bojian-api-1', 'curl', '-fsS', 'http://127.0.0.1:8080/api/v1/ready'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if ready.returncode == 0:
            break
        time.sleep(2)
    else:
        raise RuntimeError('Readiness did not recover')
    running_image = subprocess.check_output(['docker', 'inspect', 'bojian-api-1', '--format', '{{.Config.Image}}']).decode().strip()
    if running_image != new_image:
        raise RuntimeError('API image was not updated')
    deployed_hash = subprocess.check_output(['docker', 'exec', 'bojian-api-1', 'sha256sum', '/usr/local/bin/bojian-api']).decode().split()[0]
    if deployed_hash != '10c1265e21a28d29c7bf5c2b4d1fffbbec0aebb065c899eb9898c3302214a11a':
        raise RuntimeError('Deployed binary checksum mismatch')
    print('DEPLOYED_REALTIME_READY')
except Exception:
    shutil.copy2(backup, compose)
    shutil.copy2(overlay_backup, overlay)
    run(compose_args + ['up', '-d', '--no-deps', '--no-build', 'api'])
    raise
