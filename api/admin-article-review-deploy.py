import hashlib
import json
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parent
project = Path('/home/ubuntu/bojian-backend')
config = project / 'deploy/compose.admin.yaml'
image = 'bojian-admin-api:article-review-20261008-r1'

def run(args, **kw):
    return subprocess.run(args, check=True, **kw)

def info():
    return json.loads(subprocess.check_output(['docker','inspect','bojian-admin-api-1']))[0]

old_image = info()['Config']['Image']
original = config.read_bytes()
(root / 'compose.admin.before.yaml').write_bytes(original)
(root / 'previous-image.txt').write_text(old_image + '\n')
needle = 'image: bojian-admin-api:${RELEASE_TAG:?RELEASE_TAG is required}'
text = original.decode()
if text.count(needle) != 1:
    raise RuntimeError('unexpected admin image configuration; no changes made')
(root/'bojian-admin-review-api').chmod(0o755)
(root/'Dockerfile').write_text(f'FROM {old_image}\nCOPY bojian-admin-review-api /usr/local/bin/admin-api\n')
run(['docker','build','--pull=false','-t',image,str(root)])
compose = ['docker','compose','--env-file','.env.production','--env-file','deploy/release.env','-f','compose.production.yaml','-f','deploy/compose.admin.yaml','up','-d','--no-deps','admin-api']
try:
    config.write_text(text.replace(needle, f'image: {image}'))
    run(compose,cwd=project)
    for _ in range(40):
        current=info()
        if current['State'].get('Health',{}).get('Status') == 'healthy':
            break
        if not current['State']['Running']:
            raise RuntimeError('admin service stopped')
        time.sleep(1)
    else:
        raise RuntimeError('admin service health check failed')
    output=root/'installed-admin-api'
    run(['docker','cp','bojian-admin-api-1:/usr/local/bin/admin-api',str(output)])
    if hashlib.sha256(output.read_bytes()).digest() != hashlib.sha256((root/'bojian-admin-review-api').read_bytes()).digest():
        raise RuntimeError('installed binary mismatch')
    print('Deployed admin review fix; healthy; binary verified.',flush=True)
except Exception:
    config.write_bytes(original)
    run(compose,cwd=project)
    print('Rolled back to previous admin service image.',flush=True)
    raise
