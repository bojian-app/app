"""Guarded deployment of company benefits APIs and official moderation UI."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import time

project = Path('/home/ubuntu/bojian-backend')
release = Path('/home/ubuntu/bojian-company-benefits-20261010-r1')
compose = project / 'compose.production.yaml'
overlay = project / 'deploy/compose.admin.yaml'
old = {'api':'bojian-api:guidance-save-20261010-r1','admin-api':'bojian-admin-api:article-review-20261008-r1','admin-web':'bojian-admin-web:20260910-01'}
new = {'api':'bojian-api:company-benefits-20261010-r1','admin-api':'bojian-admin-api:company-benefits-20261010-r1','admin-web':'bojian-admin-web:company-benefits-20261010-r1'}
expected = {'api':'49a26c00e2492e4ed50284a24a84c702fccde1f71330533517214e233b939f93','admin-api':'e2724ae525f6bd9054215033d954aa9dfb3b308fb499786f0499406a78de1e63'}
baseline = {'api':'138b4ee4bf4be00cc7d0b38a914b547ba66923efcb9c7dd37a93e5a2ad324ec7','admin-api':'cb07a8154acd1e493a597bfd0f8e45256be11410612e8d951f73e5d955736c73'}
paths = {'api':'/usr/local/bin/bojian-api','admin-api':'/usr/local/bin/admin-api'}

def run(args,**kwargs):return subprocess.run(args,check=True,**kwargs)
def output(args):return subprocess.check_output(args).decode().strip()
def current(service):return output(['docker','inspect','bojian-'+service+'-1','--format','{{.Config.Image}}'])
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

for service in old:
 if current(service)!=old[service]:raise RuntimeError('Running image baseline changed: '+service)
for service in paths:
 if output(['docker','exec','bojian-'+service+'-1','sha256sum',paths[service]]).split()[0]!=baseline[service]:raise RuntimeError('Running binary baseline changed: '+service)
for service,folder,binary in [('api','main','bojian-api'),('admin-api','admin','admin-api')]:
 if sha(release/folder/binary)!=expected[service]:raise RuntimeError('Release checksum mismatch: '+service)
original=compose.read_text();original_overlay=overlay.read_text()
web_needle='image: bojian-admin-web:${RELEASE_TAG:?RELEASE_TAG is required}'
if original.count('image: '+old['api'])!=1 or original_overlay.count('image: '+old['api'])!=1 or original_overlay.count('image: '+old['admin-api'])!=1 or original_overlay.count(web_needle)!=1:raise RuntimeError('Unexpected service configuration')
for path,before in [(release/'compose.production.before.yaml',original),(release/'compose.admin.before.yaml',original_overlay)]:
 if path.exists() and path.read_text()!=before:raise RuntimeError('Deployment backup already exists with different contents')
 path.write_text(before)
for service,folder,binary in [('api','main','bojian-api'),('admin-api','admin','admin-api')]:
 (release/folder/binary).chmod(0o755)
 (release/folder/'Dockerfile').write_text('FROM '+old[service]+'\nCOPY '+binary+' '+paths[service]+'\n')
 run(['docker','build','--pull=false','-t',new[service],str(release/folder)])
(release/'web/Dockerfile').write_text('FROM '+old['admin-web']+'\nCOPY dist/ /usr/share/nginx/html/admin/\n')
run(['docker','build','--pull=false','-t',new['admin-web'],str(release/'web')])
args=['docker','compose','--env-file','.env.production','--env-file','deploy/release.env','-f','compose.production.yaml','-f','deploy/compose.admin.yaml']
def healthy(service):
 for _ in range(45):
  state=output(['docker','inspect','bojian-'+service+'-1','--format','{{.State.Health.Status}}'])
  if state=='healthy':return
  time.sleep(1)
 raise RuntimeError('Service did not become healthy: '+service)
try:
 compose.write_text(original.replace('image: '+old['api'],'image: '+new['api']))
 overlay.write_text(original_overlay.replace('image: '+old['api'],'image: '+new['api']).replace('image: '+old['admin-api'],'image: '+new['admin-api']).replace(web_needle,'image: '+new['admin-web']))
 run(args+['config','--quiet'],cwd=project)
 # The primary service owns migration 041; administrators start only afterwards.
 run(args+['up','-d','--no-deps','--no-build','api'],cwd=project);healthy('api')
 run(args+['up','-d','--no-deps','--no-build','admin-api','admin-web'],cwd=project)
 healthy('admin-api');healthy('admin-web')
 for service in new:
  if current(service)!=new[service]:raise RuntimeError('Updated image mismatch: '+service)
 for service in paths:
  if output(['docker','exec','bojian-'+service+'-1','sha256sum',paths[service]]).split()[0]!=expected[service]:raise RuntimeError('Updated binary checksum mismatch')
 if output(['docker','exec','bojian-admin-web-1','sha256sum','/usr/share/nginx/html/admin/index.html']).split()[0]!=sha(release/'web/dist/index.html'):raise RuntimeError('Admin website mismatch')
 print('COMPANY_BENEFITS_DEPLOYED_ALL_SERVICES_HEALTHY',flush=True)
except Exception:
 compose.write_text(original);overlay.write_text(original_overlay)
 run(args+['up','-d','--no-deps','--no-build','api','admin-api','admin-web'],cwd=project)
 print('Rolled back service images; additive welfare schema retained.',flush=True)
 raise
