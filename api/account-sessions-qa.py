import os, subprocess, secrets, time
from pathlib import Path
root = Path(__file__).parent
name = 'bojian-account-sessions-qa-20261009'
password = secrets.token_hex(16)
def run(args, **kw):
    return subprocess.run(args, check=True, **kw)
run(['docker','run','-d','--rm','--name',name,'-e','POSTGRES_USER=review_test','-e',f'POSTGRES_PASSWORD={password}','-e','POSTGRES_DB=review_test','-p','127.0.0.1:55440:5432','postgres:16-alpine'], stdout=subprocess.DEVNULL)
try:
    for _ in range(40):
        if subprocess.run(['docker','exec',name,'pg_isready','-h','127.0.0.1','-U','review_test'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            break
        time.sleep(.5)
    else:
        raise RuntimeError('isolated database not ready')
    env = dict(os.environ, ACCOUNT_SESSION_TEST_DATABASE_URL=f'postgres://review_test:{password}@127.0.0.1:55440/review_test?sslmode=disable')
    binary = root / 'bojian-account-sessions.test'
    binary.chmod(0o755)
    run([str(binary), '-test.run', '^TestAccountSessionIsolation$', '-test.v'], env=env, cwd=root)
finally:
    run(['docker','stop',name],stdout=subprocess.DEVNULL)
