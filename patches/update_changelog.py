#!/usr/bin/env python3
import os, re, json, datetime, urllib.request, ssl, subprocess

CHANGELOG_FILE = 'EXTREME_Changelog.txt'
REPO = os.environ.get('GITHUB_REPOSITORY', 'PandeyJI-9/Extreme-PLUS-kernel-munch')
TOKEN = os.environ.get('GITHUB_TOKEN', '')
ctx = ssl._create_unverified_context()

# 1. Fetch latest release info
latest_tag = ''
build_num = ''
try:
    headers = {'User-Agent': 'Changelog-Action'}
    if TOKEN:
        headers['Authorization'] = f'token {TOKEN}'
    req = urllib.request.Request(f'https://api.github.com/repos/{REPO}/releases/latest', headers=headers)
    with urllib.request.urlopen(req, context=ctx) as r:
        rel_data = json.loads(r.read().decode())
        latest_tag = rel_data.get('tag_name', '')
        m = re.search(r'\.(\d+)$', latest_tag)
        if m:
            build_num = m.group(1)
except Exception as e:
    print(f'Note on release fetch: {e}')

current_date = datetime.datetime.now().strftime('%d/%m/%Y')
date_header = f'=========={current_date}' + (f' (Build #{build_num})' if build_num else '') + '=========='

# 2. Read existing changelog if present
existing_content = ''
if os.path.exists(CHANGELOG_FILE):
    with open(CHANGELOG_FILE, 'r', encoding='utf-8') as f:
        existing_content = f.read()

# 3. Check git commits (filter out noise, bots, and CI commits)
cmd = ['git', 'log', '-n', '30', '--no-merges', '--pretty=format:%s']
res = subprocess.run(cmd, capture_output=True, text=True)
all_commits = res.stdout.strip().splitlines()

filtered_commits = []
ignore_patterns = [
    'changelog.yml', 'auto-updated', 'send_rksu', 'build.yml',
    'update changelog', 'create changelog', 'create send_rksu',
    'chore(changelog)', 'docs: auto-updated'
]

for c in all_commits:
    c_clean = c.strip()
    if not c_clean:
        continue
    if any(p in c_clean.lower() for p in ignore_patterns):
        continue
    if c_clean not in filtered_commits:
        filtered_commits.append(c_clean)

# Check if existing changelog already has this build tag
need_new_block = True
if build_num and f'Build #{build_num}' in existing_content:
    need_new_block = False
    print(f'Build #{build_num} already present in {CHANGELOG_FILE}')

if need_new_block and filtered_commits:
    new_lines = [f'* {c}' for c in filtered_commits[:8]]
    new_block = date_header + '\n' + '\n'.join(new_lines) + '\n\n'

    header = (
        'Kernel Specific Changes:\n'
        'Build type: EXTREME++ Stable / Hardcore Gaming\n'
        'Device name: POCO F4\n'
        'Device codename: munch\n'
        'Target ROM: Xiaomi HyperOS\n'
        'Kernel maintainer: @pandey_ji_8\n\n'
    )

    body = existing_content
    match = re.search(r'==========\d{2}/\d{2}/\d{4}', body)
    if match:
        body = body[match.start():]

    final_changelog = header + new_block + body.strip() + '\n'
    with open(CHANGELOG_FILE, 'w', encoding='utf-8') as f:
        f.write(final_changelog)
    print('Added new changelog block!')
else:
    print('Existing changelog structure kept intact.')

# 4. Extract latest block for Telegram broadcast
with open(CHANGELOG_FILE, 'r', encoding='utf-8') as f:
    active_content = f.read()

blocks = re.findall(r'(==========.*?==========\n(?:(?!\n==========)[\s\S])*)', active_content)
latest_block_text = ''
if blocks:
    latest_block_text = blocks[0].strip()

items = []
for line in latest_block_text.splitlines():
    line_s = line.strip()
    if line_s.startswith('=========='):
        continue
    if line_s.startswith('*') or line_s.startswith('•') or line_s.startswith('-'):
        items.append(line_s.lstrip('*•- '))
    elif line_s:
        items.append(line_s)

telegram_changes = '\n'.join([f'• {item}' for item in items[:10]])
if not telegram_changes:
    telegram_changes = '• General kernel stability and performance optimizations.'

with open('tg_changes.txt', 'w', encoding='utf-8') as f:
    f.write(telegram_changes)

with open('tg_tag.txt', 'w', encoding='utf-8') as f:
    f.write(latest_tag if latest_tag else 'Latest')

with open('tg_build.txt', 'w', encoding='utf-8') as f:
    f.write(f'Build #{build_num}' if build_num else '')

print('Changelog update and parsing finished successfully!')
