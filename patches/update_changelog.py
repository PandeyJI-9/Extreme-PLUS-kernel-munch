#!/usr/bin/env python3
import os, re, json, datetime, urllib.request, ssl, subprocess

CHANGELOG_FILE = 'EXTREME_Changelog.txt'
REPO = os.environ.get('GITHUB_REPOSITORY', 'PandeyJI-9/Extreme-PLUS-kernel-munch')
TOKEN = os.environ.get('GITHUB_TOKEN', '')
ctx = ssl._create_unverified_context()

# If token not in env, attempt extraction from git remote url
if not TOKEN:
    try:
        remote_url = subprocess.run(['git', 'remote', 'get-url', 'origin'], capture_output=True, text=True).stdout
        m_tok = re.search(r'://[^:]+:([^@]+)@', remote_url)
        if m_tok:
            TOKEN = m_tok.group(1)
    except Exception:
        pass

headers = {'User-Agent': 'Changelog-Action'}
if TOKEN:
    headers['Authorization'] = f'token {TOKEN}'

# 1. Fetch latest build info (Checks Telegram/Actions build runs + GitHub Releases)
latest_tag = ''
build_num = ''
build_source = 'Auto-Detect'
run_url = ''
artifact_name = ''

# Priority 0: Explicit input via environment (e.g. from workflow_dispatch input)
env_build = os.environ.get('BUILD_NUMBER', '').strip()
if env_build:
    m = re.search(r'(\d+)', env_build)
    if m:
        build_num = m.group(1)
        latest_tag = f'Build #{build_num}'
        build_source = 'Manual Input'

# Priority 1: Check GitHub Actions runs for build.yml (the exact build sent to Telegram DM & Chat)
act_run_num = ''
if not build_num:
    try:
        actions_url = f'https://api.github.com/repos/{REPO}/actions/workflows/build.yml/runs?status=success&per_page=1'
        req = urllib.request.Request(actions_url, headers=headers)
        with urllib.request.urlopen(req, context=ctx) as r:
            data = json.loads(r.read().decode())
            runs = data.get('workflow_runs', [])
            if runs:
                latest_run = runs[0]
                act_run_num = str(latest_run.get('run_number', ''))
                run_url = latest_run.get('html_url', '')
                run_id = latest_run.get('id', '')
                if run_id:
                    try:
                        art_req = urllib.request.Request(f'https://api.github.com/repos/{REPO}/actions/runs/{run_id}/artifacts', headers=headers)
                        with urllib.request.urlopen(art_req, context=ctx) as art_r:
                            art_data = json.loads(art_r.read().decode())
                            arts = art_data.get('artifacts', [])
                            if arts:
                                artifact_name = arts[0].get('name', '')
                    except Exception:
                        pass
    except Exception as e:
        print(f'Note on Actions API fetch: {e}')

# Fallback: check general runs if workflow endpoint failed
if not act_run_num and not build_num:
    try:
        runs_url = f'https://api.github.com/repos/{REPO}/actions/runs?status=success&per_page=5'
        req = urllib.request.Request(runs_url, headers=headers)
        with urllib.request.urlopen(req, context=ctx) as r:
            data = json.loads(r.read().decode())
            for r_item in data.get('workflow_runs', []):
                if 'build' in r_item.get('name', '').lower() or 'extreme' in r_item.get('name', '').lower():
                    act_run_num = str(r_item.get('run_number', ''))
                    run_url = r_item.get('html_url', '')
                    break
    except Exception as e:
        print(f'Note on general runs fetch: {e}')

# Priority 2: Check GitHub Releases
rel_run_num = ''
rel_tag = ''
try:
    rel_req = urllib.request.Request(f'https://api.github.com/repos/{REPO}/releases/latest', headers=headers)
    with urllib.request.urlopen(rel_req, context=ctx) as r:
        rel_data = json.loads(r.read().decode())
        rel_tag = rel_data.get('tag_name', '')
        m = re.search(r'\.(\d+)$', rel_tag)
        if m:
            rel_run_num = m.group(1)
except Exception as e:
    print(f'Note on release fetch: {e}')

# Decide latest build number between Actions (Telegram) and Releases
if not build_num:
    if act_run_num and rel_run_num:
        try:
            if int(act_run_num) >= int(rel_run_num):
                build_num = act_run_num
                latest_tag = f'Build #{build_num}'
                build_source = 'Telegram DM / Actions'
            else:
                build_num = rel_run_num
                latest_tag = rel_tag
                build_source = 'GitHub Release'
        except ValueError:
            build_num = act_run_num
            latest_tag = f'Build #{build_num}'
            build_source = 'Telegram DM / Actions'
    elif act_run_num:
        build_num = act_run_num
        latest_tag = f'Build #{build_num}'
        build_source = 'Telegram DM / Actions'
    elif rel_run_num:
        build_num = rel_run_num
        latest_tag = rel_tag
        build_source = 'GitHub Release'

# Fallback: check git tags if still empty
if not build_num:
    try:
        tag_res = subprocess.run(['git', 'tag', '--sort=-creatordate'], capture_output=True, text=True)
        tags = [t.strip() for t in tag_res.stdout.splitlines() if t.strip()]
        for t in tags:
            m = re.search(r'\.(\d+)$', t)
            if m:
                build_num = m.group(1)
                latest_tag = t
                build_source = 'Git Tag'
                break
    except Exception:
        pass

print(f'Target build detected: #{build_num} (Source: {build_source}, Tag: {latest_tag})')

current_date = datetime.datetime.now().strftime('%d/%m/%Y')
date_header = f'=========={current_date}' + (f' (Build #{build_num})' if build_num else '') + '=========='

# 2. Read existing changelog if present
existing_content = ''
if os.path.exists(CHANGELOG_FILE):
    with open(CHANGELOG_FILE, 'r', encoding='utf-8') as f:
        existing_content = f.read()

# 3. Check git commits (filter out noise, bots, and CI commits)
cmd = ['git', 'log', '-n', '35', '--no-merges', '--pretty=format:%s']
res = subprocess.run(cmd, capture_output=True, text=True)
all_commits = res.stdout.strip().splitlines()

filtered_commits = []
ignore_patterns = [
    'changelog.yml', 'auto-updated', 'send_rksu', 'build.yml',
    'update changelog', 'create changelog', 'create send_rksu',
    'chore(changelog)', 'docs: auto-updated', 'ci: remove github releases'
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
    new_lines = [f'* {c}' for c in filtered_commits[:10]]
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
    print(f'Added new changelog block for Build #{build_num}!')
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

with open('tg_source.txt', 'w', encoding='utf-8') as f:
    f.write(build_source)

if run_url:
    with open('tg_run_url.txt', 'w', encoding='utf-8') as f:
        f.write(run_url)

print('Changelog update and parsing finished successfully!')
