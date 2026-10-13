"""Deploy reviewed public-source welfare release with verified baselines and rollback."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import time

os.umask(0o077)
root = Path('/home/ubuntu/bojian-backend')
release = Path('/home/ubuntu/bojian-company-benefits-public-sources-20261012-r1')
compose = root / 'compose.production.yaml'
overlay = root / 'deploy/compose.admin.yaml'
old = {s: f'bojian-{s}:company-benefits-20261010-r1' for s in ['api', 'admin-api', 'admin-web']}
new = {s: f'bojian-{s}:company-benefits-public-sources-20261012-r1' for s in old}
old_sha = {'api': '49a26c00e2492e4ed50284a24a84c702fccde1f71330533517214e233b939f93',
           'admin-api': 'e2724ae525f6bd9054215033d954aa9dfb3b308fb499786f0499406a78de1e63',
           'admin-web': 'cf52be47f6a7fc69269d832265cbc6f5f20f5e1a563f2b32a2f15d903c4532b0'}
expected = {'api': 'ed274f0bac2842b64370bed5fa2e8447aa218549c556dc8281bea6fc3269316b',
            'admin-api': 'a938613d69d84a780e5282d0fdf721ff882d81b3594b90fc7f29b5e3cd72bee9',
            'admin-web': 'aedb160aea4cf55ffc5b46e2e12a58534976abad4b184996f7ac17a6d73c820f'}
artifact = {'api': ('main/bojian-api', '/usr/local/bin/bojian-api'),
            'admin-api': ('admin/admin-api', '/usr/local/bin/admin-api'),
            'admin-web': ('web/dist/index.html', '/usr/share/nginx/html/admin/index.html')}
compose_sha = {compose: 'b87b71d6c34112d7eafb9e364c342aaeb338409bf652d26936fa14a73de6275e',
               overlay: 'f68e17257e7f8b4aaff0f6e410dd9274eff02f0bcf6cf672dab96dbd15d3d938'}
args = ['docker', 'compose', '--env-file', '.env.production', '--env-file', 'deploy/release.env',
        '-f', 'compose.production.yaml', '-f', 'deploy/compose.admin.yaml']

def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)

def output(command):
    return subprocess.check_output(command, text=True).strip()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inspect(service):
    return json.loads(output(['docker', 'inspect', 'bojian-' + service + '-1']))[0]

def current_sha(service):
    return output(['docker', 'exec', 'bojian-' + service + '-1', 'sha256sum', artifact[service][1]]).split()[0]

def assert_baseline():
    for service in old:
        info = inspect(service)
        if info['Config']['Image'] != old[service] or current_sha(service) != old_sha[service]:
            raise RuntimeError('Running baseline changed: ' + service)
        tag_id = output(['docker', 'image', 'inspect', old[service], '--format', '{{.Id}}'])
        if tag_id != info['Image']:
            raise RuntimeError('Base image tag changed: ' + service)
        if info['State'].get('Health', {}).get('Status') != 'healthy':
            raise RuntimeError('Baseline not healthy: ' + service)
    for path, expected_sha in compose_sha.items():
        if sha(path) != expected_sha:
            raise RuntimeError('Compose baseline changed: ' + path.name)

def db(sql):
    command = ['docker', 'exec', '-i', 'bojian-postgres-1', 'sh', '-c',
               'exec psql -X -At -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"']
    result = subprocess.run(command, input=sql, text=True, capture_output=True, check=True)
    return result.stdout.strip()

def healthy(service):
    for _ in range(60):
        state = inspect(service)['State']
        if state.get('Health', {}).get('Status') == 'healthy':
            print(service + ' healthy', flush=True)
            return
        if state['Status'] in ['exited', 'dead']:
            break
        time.sleep(1)
    raise RuntimeError('Updated service not healthy: ' + service)

if not (release / 'qa.passed').exists():
    raise RuntimeError('PostgreSQL16 release QA has not passed')
assert_baseline()
for service, (source, _) in artifact.items():
    if sha(release / source) != expected[service]:
        raise RuntimeError('Release artifact checksum mismatch: ' + service)
static = json.loads((release / 'web/static-manifest.json').read_text())
# Validate all static files by the independently generated checksum list.
run(['sha256sum', '-c', str(release / 'web/SHA256SUMS')], cwd=release / 'web', stdout=subprocess.DEVNULL)
if db("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version='042_company_benefit_public_sources.sql');") != 'f':
    raise RuntimeError('Migration 042 already exists; inspect release state')
original, original_overlay = compose.read_text(), overlay.read_text()
if original.count('image: ' + old['api']) != 1 or any(original_overlay.count('image: ' + old[s]) != 1 for s in old):
    raise RuntimeError('Unexpected compose service image layout')
backup = release / 'backup'
backup.mkdir(mode=0o700, exist_ok=False)
(backup / 'compose.production.yaml').write_text(original)
(backup / 'compose.admin.yaml').write_text(original_overlay)
with (backup / 'database.before.dump').open('wb') as handle:
    run(['docker', 'exec', 'bojian-postgres-1', 'sh', '-c',
         'exec pg_dump -Fc -U "$POSTGRES_USER" -d "$POSTGRES_DB"'], stdout=handle)
if not (backup / 'database.before.dump').stat().st_size:
    raise RuntimeError('Database backup is empty')
(backup / 'services.json').write_text(json.dumps({s: {'image': old[s], 'image_id': inspect(s)['Image'], 'sha256': old_sha[s]} for s in old}, indent=2))
print('Baseline verified and database/configuration backups saved', flush=True)
for service, directory in [('api', 'main'), ('admin-api', 'admin')]:
    binary = release / artifact[service][0]
    binary.chmod(0o755)
    (release / directory / 'Dockerfile').write_text('FROM ' + old[service] + '\nCOPY ' + binary.name + ' ' + artifact[service][1] + '\n')
    run(['docker', 'build', '--pull=false', '-t', new[service], str(release / directory)])
(release / 'web/Dockerfile').write_text('FROM ' + old['admin-web'] + '\nCOPY dist/ /usr/share/nginx/html/admin/\n')
run(['docker', 'build', '--pull=false', '-t', new['admin-web'], str(release / 'web')])
assert_baseline()
try:
    compose.write_text(original.replace('image: ' + old['api'], 'image: ' + new['api']))
    updated_overlay = original_overlay
    for service in old:
        updated_overlay = updated_overlay.replace('image: ' + old[service], 'image: ' + new[service])
    overlay.write_text(updated_overlay)
    run(args + ['config', '--quiet'], cwd=root)
    run(args + ['up', '-d', '--no-deps', '--no-build', 'api'], cwd=root)
    healthy('api')
    if db("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version='042_company_benefit_public_sources.sql');") != 't':
        raise RuntimeError('Migration 042 did not apply')
    if db("SELECT count(*) FROM company_benefits WHERE status='PUBLISHED' AND (source_reviewed_at IS NULL OR source_reviewed_by IS NULL OR official_note<>'' OR NOT company_benefit_public_sources_complete(benefits_jsonb,sources_jsonb));") != '0':
        raise RuntimeError('An unreviewed benefit is publicly published')
    run(args + ['up', '-d', '--no-deps', '--no-build', 'admin-api'], cwd=root)
    healthy('admin-api')
    run(args + ['up', '-d', '--no-deps', '--no-build', 'admin-web'], cwd=root)
    healthy('admin-web')
    for service in new:
        if inspect(service)['Config']['Image'] != new[service] or current_sha(service) != expected[service]:
            raise RuntimeError('Deployed artifact mismatch: ' + service)
    for path, status in [('/api/v1/health', 'ok'), ('/api/v1/ready', 'ready')]:
        result = json.loads(output(['curl', '--resolve', 'bojian.kelance.cn:443:127.0.0.1', '-fsS', 'https://bojian.kelance.cn' + path]))
        if result.get('data', {}).get('status') != status:
            raise RuntimeError('Public HTTPS health/readiness check failed')
    code = output(['curl', '--resolve', 'bojian.kelance.cn:443:127.0.0.1', '-sS', '-o', '/dev/null', '-w', '%{http_code}', 'https://bojian.kelance.cn/admin/'])
    if code != '200':
        raise RuntimeError('Public admin page check failed')
    for path in ['/api/v1/company-benefits', '/api/admin/v1/company-benefits']:
        code = output(['curl', '--resolve', 'bojian.kelance.cn:443:127.0.0.1', '-sS', '-o', '/dev/null', '-w', '%{http_code}', 'https://bojian.kelance.cn' + path])
        if code != '401':
            raise RuntimeError('Unauthenticated welfare route not protected: ' + path)
    result = {'status': 'DEPLOYED_AND_HEALTHY', 'migration': '042_company_benefit_public_sources.sql',
              'services': {s: {'image': new[s], 'sha256': expected[s], 'health': 'healthy'} for s in new},
              'backup_directory': str(backup), 'database_backup_sha256': sha(backup / 'database.before.dump'),
              'checks': ['PostgreSQL16 isolated release suites', 'artifact and static file checksums',
                         'migration and no unreviewed publication', 'origin HTTPS health/readiness',
                         'admin page and API authentication'], 'completed_at_epoch': int(time.time())}
    (release / 'deployed.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PUBLIC_SOURCE_BENEFITS_DEPLOYED_ALL_SERVICES_HEALTHY', flush=True)
except Exception:
    compose.write_text(original)
    overlay.write_text(original_overlay)
    run(args + ['up', '-d', '--no-deps', '--no-build', 'api', 'admin-api', 'admin-web'], cwd=root)
    print('Service images rolled back; migration retained and legacy publication remains blocked.', flush=True)
    raise
