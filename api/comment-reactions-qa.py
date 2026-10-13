import os, subprocess, secrets, time
from pathlib import Path
root = Path(__file__).parent
name = 'bojian-comment-reactions-qa-20261008'
password = secrets.token_hex(16)
def run(args, **kw):
    return subprocess.run(args, check=True, **kw)
run(['docker','run','-d','--rm','--name',name,'-e','POSTGRES_USER=review_test','-e',f'POSTGRES_PASSWORD={password}','-e','POSTGRES_DB=review_test','-p','127.0.0.1:55439:5432','postgres:16-alpine'], stdout=subprocess.DEVNULL)
try:
    for _ in range(40):
        if subprocess.run(['docker','exec',name,'pg_isready','-h','127.0.0.1','-U','review_test'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            break
        time.sleep(.5)
    else:
        raise RuntimeError('isolated database not ready')
    env = dict(os.environ, HOME_FEED_TEST_DATABASE_URL=f'postgres://review_test:{password}@127.0.0.1:55439/review_test?sslmode=disable')
    test_dir = root / 'internal/httpapi'
    test_dir.mkdir(parents=True, exist_ok=True)
    migration_dir = root / 'internal/database/migrations'
    migration_dir.mkdir(parents=True, exist_ok=True)
    (migration_dir / '034_comment_replies_likes.sql').write_bytes((root / '034_comment_replies_likes.sql').read_bytes())
    (migration_dir / '035_comment_dislikes.sql').write_bytes((root / '035_comment_dislikes.sql').read_bytes())
    binary = root / 'bojian-comment-reactions.test'
    binary.chmod(0o755)
    run([str(binary), '-test.run', '^TestArticleCommentsIntegration$', '-test.v'], env=env, cwd=test_dir)
finally:
    run(['docker','stop',name],stdout=subprocess.DEVNULL)
