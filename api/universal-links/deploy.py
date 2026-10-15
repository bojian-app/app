import datetime, hashlib, json, pathlib, subprocess
config = pathlib.Path('/home/ubuntu/bojian-backend/deploy/Caddyfile')
EXPECTED = '5e9a2a8abda9843e0f19ff951d2c17da247028c8b4a02dbd2e8f818488cfdfe6'
PROPOSED = '{$DOMAIN} {\n    encode zstd gzip\n\n    route {\n    # Apple Universal Links association for Bojian iOS.\n    @bojian_aasa path /.well-known/apple-app-site-association /apple-app-site-association\n    handle @bojian_aasa {\n        header Content-Type application/json\n        header Cache-Control "public, max-age=3600"\n        respond `{\n  "applinks": {\n    "apps": [],\n    "details": [\n      {\n        "appID": "C6Z4939YD6.cn.kelance.bojian",\n        "paths": [\n          "/wechat/*"\n        ]\n      }\n    ]\n  }\n}` 200\n    }\n\n    redir /admin /admin/ 308\n    @admin_api path /api/auth/* /api/user/* /api/admin/v1 /api/admin/v1/*\n    handle @admin_api {\n        uri strip_prefix /api\n        reverse_proxy admin-api:8081\n    }\n\n    # This endpoint validates a live admin session, role and matching audit ID.\n    handle /internal/admin/templates/uploads {\n        reverse_proxy api:8080\n    }\n\n    @backend path /api/* /webhooks/* /admin/v1 /admin/v1/*\n    handle @backend {\n        reverse_proxy api:8080\n    }\n\n    handle /admin/* {\n        reverse_proxy admin-web:8080\n    }\n\n    handle {\n        reverse_proxy website:3000\n    }\n    }\n\n    header {\n        X-Content-Type-Options nosniff\n        Referrer-Policy strict-origin-when-cross-origin\n        -Server\n    }\n    log\n}\n'
AASA = '{\n  "applinks": {\n    "apps": [],\n    "details": [\n      {\n        "appID": "C6Z4939YD6.cn.kelance.bojian",\n        "paths": [\n          "/wechat/*"\n        ]\n      }\n    ]\n  }\n}\n'
before = config.read_bytes()
if hashlib.sha256(before).hexdigest() != EXPECTED:
    raise SystemExit('Caddy baseline changed; deployment aborted')
release = pathlib.Path('/home/ubuntu/bojian-universal-links-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
release.mkdir(exist_ok=False)
(release / 'Caddyfile.before').write_bytes(before)
(release / 'Caddyfile.after').write_text(PROPOSED)
(release / 'apple-app-site-association').write_text(AASA)
subprocess.run(['docker','exec','-i','bojian-caddy-1','caddy','validate','--config','/dev/stdin','--adapter','caddyfile'], input=PROPOSED.encode(), check=True)
try:
    if config.read_bytes() != before:
        raise RuntimeError('Configuration changed before write')
    # Keep the inode: Caddy bind-mounts this file rather than its directory.
    config.write_text(PROPOSED)
    subprocess.run(['docker','exec','bojian-caddy-1','caddy','reload','--config','/etc/caddy/Caddyfile','--adapter','caddyfile'],check=True)
except Exception:
    config.write_bytes(before)
    subprocess.run(['docker','exec','bojian-caddy-1','caddy','reload','--config','/etc/caddy/Caddyfile','--adapter','caddyfile'],check=True)
    raise
print(json.dumps({'backup_directory':str(release),'caddy_sha256':hashlib.sha256(config.read_bytes()).hexdigest(),'aasa':json.loads(AASA)}))
