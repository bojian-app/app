"""Run release welfare tests against a disposable PostgreSQL 16, never production DB."""
from pathlib import Path
import os
import secrets
import socket
import subprocess
import time

release = Path('/home/ubuntu/bojian-article-feedback-20261013-r1')
container = 'bojian-article-feedback-qa'
port = 55444
password = secrets.token_hex(24)
with socket.socket() as probe:
    probe.bind(('127.0.0.1', port))

def run(args, **kwargs):
    result = subprocess.run(args, **kwargs)
    if result.returncode:
        raise RuntimeError('QA command failed: ' + args[0])
    return result

started = False
try:
    run(['docker', 'run', '-d', '--rm', '--name', container,
         '-e', 'POSTGRES_USER=review_test', '-e', 'POSTGRES_DB=review_test',
         '-e', 'POSTGRES_PASSWORD=' + password, '-p', f'127.0.0.1:{port}:5432',
         '--tmpfs', '/var/lib/postgresql/data:rw,mode=0700', 'postgres:16-alpine'],
        stdout=subprocess.DEVNULL)
    started = True
    for _ in range(50):
        if subprocess.run(['docker', 'exec', container, 'pg_isready', '-h', '127.0.0.1', '-U', 'review_test'],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            break
        time.sleep(.5)
    else:
        raise RuntimeError('Isolated PostgreSQL did not become ready')
    env = dict(os.environ, TEMPLATE_TEST_DATABASE_URL=f'postgres://review_test:{password}@127.0.0.1:{port}/review_test?sslmode=disable')
    for key in ('ARTICLE_FEEDBACK_TEST_DATABASE_URL', 'HOME_FEED_TEST_DATABASE_URL', 'LIKE_NOTIFICATION_TEST_DATABASE_URL'):
        env[key] = env['TEMPLATE_TEST_DATABASE_URL']
    binary = release / 'feedback.test'
    binary.chmod(0o755)
    run([str(binary), '-test.run', '^(TestArticleFeedbackIntegration|TestArticleCommentsIntegration|TestArticleLikeNotificationsIntegration|TestHomeFeedIntegration|TestGuidanceNotificationSummariesIntegration|TestGuidanceAnnotationsIntegration|TestGuidanceSharing|TestGuidanceFields|TestListNotification.*|TestNotificationDeliveryReceipt.*)$', '-test.v'], env=env, cwd=release / 'source/internal/httpapi')
    (release / 'qa.passed').write_text('PostgreSQL16 release welfare suites passed\n')
    print('ISOLATED_POSTGRESQL16_RELEASE_QA_PASSED', flush=True)
finally:
    if started:
        run(['docker', 'stop', container], stdout=subprocess.DEVNULL)
