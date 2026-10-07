#!/usr/bin/env python3
import os, html, urllib.request, json, ssl, datetime

ctx = ssl._create_unverified_context()
repo = os.environ.get('GITHUB_REPOSITORY', 'PandeyJI-9/Extreme-PLUS-kernel-munch')
bot_token = os.environ.get('TELEGRAM_TOKEN', '')

targets = []
chat_id = os.environ.get('TELEGRAM_CHAT_ID', '').strip()
dm_id = os.environ.get('TELEGRAM_DM_ID', '').strip()

if chat_id:
    targets.append(chat_id)
if dm_id and dm_id not in targets:
    targets.append(dm_id)

if not bot_token or not targets:
    print('Telegram token or target chat IDs missing, skipping Telegram broadcast.')
    exit(0)

raw_link = f'https://raw.githubusercontent.com/{repo}/main/EXTREME_Changelog.txt'
blob_link = f'https://github.com/{repo}/blob/main/EXTREME_Changelog.txt'
releases_link = f'https://github.com/{repo}/releases'

raw_changes = '• General performance and stability optimizations.'
if os.path.exists('tg_changes.txt'):
    with open('tg_changes.txt', 'r', encoding='utf-8') as f:
        raw_changes = f.read().strip()

tag_name = 'Latest'
if os.path.exists('tg_tag.txt'):
    with open('tg_tag.txt', 'r', encoding='utf-8') as f:
        tag_name = f.read().strip()

build_str = ''
if os.path.exists('tg_build.txt'):
    with open('tg_build.txt', 'r', encoding='utf-8') as f:
        build_str = f.read().strip()

run_url = ''
if os.path.exists('tg_run_url.txt'):
    with open('tg_run_url.txt', 'r', encoding='utf-8') as f:
        run_url = f.read().strip()

build_source = 'Telegram Broadcast'
if os.path.exists('tg_source.txt'):
    with open('tg_source.txt', 'r', encoding='utf-8') as f:
        build_source = f.read().strip()

# HTML escape commits text so <, >, & do not break Telegram HTML parser
safe_changes = html.escape(raw_changes)
current_date = datetime.datetime.now().strftime('%d/%m/%Y')

build_badge = f' ({build_str})' if build_str else ''

quick_links = [
    f'• <a href="{raw_link}">📄 Direct Raw Changelog</a>',
    f'• <a href="{blob_link}">👁️ View on GitHub</a>',
]
if run_url:
    quick_links.append(f'• <a href="{run_url}">⚡ GitHub Run & Artifacts ({build_str})</a>')
quick_links.append(f'• <a href="{releases_link}">📦 Releases Archive</a>')
quick_links_str = '\n'.join(quick_links)

caption = f"""🔥 <b>EXTREME++ Kernel | Update Changelog</b>

📱 <b>Device:</b> POCO F4 (<code>munch</code>)
⚡ <b>Target ROM:</b> Xiaomi HyperOS
👤 <b>Maintainer:</b> @pandey_ji_8
🏷 <b>Version:</b> <code>{tag_name}</code>{build_badge}
📡 <b>Build Source:</b> <code>{build_source}</code>
🗓 <b>Date:</b> {current_date}

━━━━━━━━━━━━━━━━━━━━
🛠 <b>Latest Changes:</b>
{safe_changes}

━━━━━━━━━━━━━━━━━━━━
🌐 <b>Raw Changelog Link (Full):</b>
<code>{raw_link}</code>

🔗 <b>Quick Links:</b>
{quick_links_str}"""

for target in targets:
    payload = json.dumps({
        'chat_id': target,
        'text': caption,
        'parse_mode': 'HTML',
        'disable_web_page_preview': True
    }).encode('utf-8')

    req = urllib.request.Request(f'https://api.telegram.org/bot{bot_token}/sendMessage', data=payload, headers={
        'Content-Type': 'application/json'
    })

    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            print(f'Telegram message sent successfully to {target}! Status: {resp.status}')
    except Exception as e:
        print(f'Telegram broadcast to {target} failed:', e)

