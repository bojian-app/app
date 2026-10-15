"""Exercise the configured provider with synthetic content; never print credentials."""
import json
import subprocess
import urllib.request
import urllib.error

container = json.loads(subprocess.check_output(['docker', 'inspect', 'bojian-api-1']))[0]
env = dict(row.split('=', 1) for row in container['Config']['Env'] if '=' in row)
required = ['AI_POLISH_BASE_URL', 'AI_POLISH_API_KEY', 'AI_POLISH_MODEL']
if not all(env.get(key) for key in required):
    raise SystemExit('AI_CONFIG_INCOMPLETE')
content = {
    'personal_info': {'full_name': '虚构测试用户'},
    'job_expectation': {'position': '产品经理', 'preference': '我做过需求分析，也做过功能设计，希望把产品做好。'},
    'work_experiences': [{'company': '虚构测试公司', 'position': '产品经理', 'start_date': '2024-01', 'end_date': '2025-01', 'description': '我主要就是和业务方聊需求，把需求整理出来，然后做产品功能设计，和研发一起把功能上线。'}],
    'projects': [], 'educations': [], 'skills': [], 'certifications': [], 'app_layout': 'standard',
}
system = '你是专业简历编辑。仅对原文进行保守润色，不得编造、推断、增加或删除事实，不得修改数字、日期、公司、职位、学校、项目名称和技能事实。保持原文语言和输入 JSON 的完整结构。只返回 JSON 对象，格式必须为 {"content": 完整润色后简历对象}，不要返回 Markdown 或解释。'
body = {
    'model': env['AI_POLISH_MODEL'],
    'messages': [{'role': 'system', 'content': system}, {'role': 'user', 'content': json.dumps({'content': content, 'instructions': '仅优化已有的 preference 和 description，精简口语化表述，不增加事实，保持其他字段与数组顺序不变。'}, ensure_ascii=False)}],
    'temperature': .3, 'max_tokens': 2048, 'response_format': {'type': 'json_object'},
    'thinking': {'type': 'disabled'}, 'reasoning_effort': 'low',
}
req = urllib.request.Request(env['AI_POLISH_BASE_URL'].rstrip('/') + '/chat/completions', data=json.dumps(body).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + env['AI_POLISH_API_KEY']})
try:
    with urllib.request.urlopen(req, timeout=60) as response:
        result = json.load(response)
except urllib.error.HTTPError as error:
    raise SystemExit('PROVIDER_HTTP_' + str(error.code))
except Exception as error:
    raise SystemExit('PROVIDER_TRANSPORT_' + type(error).__name__)
text = result['choices'][0]['message']['content'].strip()
if text.startswith('```'):
    text = text.split('\n', 1)[1].rsplit('```', 1)[0]
output = json.loads(text)['content']
assert output['personal_info'] == content['personal_info']
assert len(output['work_experiences']) == 1
for key in ['company', 'position', 'start_date', 'end_date']:
    assert output['work_experiences'][0][key] == content['work_experiences'][0][key]
changed = output['work_experiences'][0]['description'] != content['work_experiences'][0]['description']
assert changed and output['work_experiences'][0]['description'].strip()
print(json.dumps({'status': 'PASS', 'synthetic_input': True, 'structured_output': True, 'identity_and_dates_preserved': True, 'narrative_changed': changed, 'description': output['work_experiences'][0]['description']}, ensure_ascii=False))
