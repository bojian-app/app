#!/usr/bin/env python3
"""Print public WeChat registration fields from a HarmonyOS signed Profile.

Reads only; it does not validate the signing certificate's trust chain and must
not be used as a release-signature verifier. Private keys are never required.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def registration_fields(profile, expected_bundle):
    info = profile.get('bundle-info', {})
    bundle = info.get('bundle-name')
    identifier = info.get('app-identifier')
    if bundle != expected_bundle:
        raise ValueError(f'Profile 包名为 {bundle!r}，与预期 {expected_bundle!r} 不一致')
    if not isinstance(identifier, str) or not identifier.strip():
        raise ValueError('Profile 没有 app-identifier，不能据此填写微信 Identifier')
    return {'Bundle ID': bundle, 'Identifier': identifier}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', type=Path, help='华为签发的 .p7b Profile（无需私钥）')
    parser.add_argument('--bundle', default='cn.kelance.bojian')
    args = parser.parse_args()
    if not args.profile.is_file():
        parser.error('Profile 文件不存在')
    result = subprocess.run(
        ['openssl', 'cms', '-verify', '-noverify', '-inform', 'DER',
         '-in', str(args.profile)], capture_output=True,
    )
    if result.returncode:
        print('无法解析 CMS Profile；请使用华为下载的原始 .p7b 文件。', file=sys.stderr)
        return 1
    try:
        fields = registration_fields(json.loads(result.stdout), args.bundle)
    except (ValueError, TypeError, AttributeError) as error:
        print(str(error), file=sys.stderr)
        return 1
    print(json.dumps(fields, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
