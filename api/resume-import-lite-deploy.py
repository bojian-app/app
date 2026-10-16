"""Deploy Lite AI resume recognition and composition with guarded rollback."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import time

root = Path('/home/ubuntu/bojian-backend')
release = Path('/home/ubuntu/bojian-docx-lite-20261015-r1')
old_image = 'bojian-api:article-feedback-20261013-r1'
new_image = 'bojian-api:resume-import-lite-20261015-r1'
compose = root / 'compose.production.yaml'
backup = release / 'compose.production.before.yaml'
overlay = root / 'deploy/compose.admin.yaml'
overlay_backup = release / 'compose.admin.before.yaml'
# Built from the verified running article-feedback release plus the AI resume-import patch.

def run(args):
    subprocess.run(args, cwd=root, check=True)

if not (release / 'qa.passed').exists():
    raise SystemExit('Real DOCX AI import QA required')
current = subprocess.check_output(['docker', 'inspect', 'bojian-api-1', '--format', '{{.Config.Image}}']).decode().strip()
if current != old_image or (backup.exists() and backup.read_bytes() != compose.read_bytes()):
    raise SystemExit('Baseline changed; inspect before deploying')
if hashlib.sha256((release / 'bojian-api').read_bytes()).hexdigest() != '08061b02a404ac7abe845ab0621a458e5abaef6a9fec204e69ea12a9c1cea87b':
    raise SystemExit('Binary checksum mismatch')
running_hash = subprocess.check_output(['docker', 'exec', 'bojian-api-1', 'sha256sum', '/usr/local/bin/bojian-api']).decode().split()[0]
if running_hash != '73874a0682a9e85201b04ef1ac9ebb9d8e5fc349b801ba9f84bc987e10895c55':
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
with (release / 'database.before.dump').open('wb') as handle:
    subprocess.run(['docker', 'exec', 'bojian-postgres-1', 'sh', '-c', 'exec pg_dump -Fc -U "$POSTGRES_USER" -d "$POSTGRES_DB"'], stdout=handle, check=True)
(release / 'bojian-api').chmod(0o755)
(release / 'Dockerfile').write_text('FROM ' + old_image + '\nCOPY bojian-api /usr/local/bin/bojian-api\n')
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
    if deployed_hash != '08061b02a404ac7abe845ab0621a458e5abaef6a9fec204e69ea12a9c1cea87b':
        raise RuntimeError('Deployed binary checksum mismatch')
    print('DEPLOYED_RESUME_IMPORT_LITE_READY')
except Exception:
    shutil.copy2(backup, compose)
    shutil.copy2(overlay_backup, overlay)
    run(compose_args + ['up', '-d', '--no-deps', '--no-build', 'api'])
    raise
