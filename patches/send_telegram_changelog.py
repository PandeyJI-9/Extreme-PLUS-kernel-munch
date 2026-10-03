#!/usr/bin/env python3
import os, html, urllib.request, json, ssl, datetime

ctx = ssl._create_unverified_context()
repo = os.environ.get('GITHUB_REPOSITORY', 'PandeyJI-9/Extreme-PLUS-kernel-munch')
bot_token = os.environ.get('TELEGRAM_TOKEN', '')
chat_id = os.environ.get('TELEGRAM_CHAT_ID', '')

if not bot_token or not chat_id:
    print('Telegram token or chat ID missing, skipping Telegram broadcast.')
    exit(0)

raw_link = f'https://raw.githubusercontent.com/{repo}/main/EXTREME_Changelog.txt'
blob_link = f'https://github.com/{repo}/blob/main/EXTREME_Changelog.txt'
release_link = f'https://github.com/{repo}/releases/latest'

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

# HTML escape commits text so <, >, & do not break Telegram HTML parser
safe_changes = html.escape(raw_changes)
current_date = datetime.datetime.now().strftime('%d/%m/%Y')

build_badge = f' ({build_str})' if build_str else ''

caption = f"""🔥 <b>EXTREME++ Kernel | Update Changelog</b>

📱 <b>Device:</b> POCO F4 (<code>munch</code>)
⚡ <b>Target ROM:</b> Xiaomi HyperOS
👤 <b>Maintainer:</b> @pandey_ji_8
🏷 <b>Version:</b> <code>{tag_name}</code>{build_badge}
🗓 <b>Date:</b> {current_date}

━━━━━━━━━━━━━━━━━━━━
🛠 <b>Latest Changes:</b>
{safe_changes}

━━━━━━━━━━━━━━━━━━━━
🌐 <b>Raw Changelog Link (Full):</b>
<code>{raw_link}</code>

🔗 <b>Quick Links:</b>
• <a href="{raw_link}">📄 Direct Raw File</a>
• <a href="{blob_link}">👁️ View on GitHub</a>
• <a href="{release_link}">📦 Download Latest Kernel</a>"""

payload = json.dumps({
    'chat_id': chat_id,
    'text': caption,
    'parse_mode': 'HTML',
    'disable_web_page_preview': True
}).encode('utf-8')

req = urllib.request.Request(f'https://api.telegram.org/bot{bot_token}/sendMessage', data=payload, headers={
    'Content-Type': 'application/json'
})

try:
    with urllib.request.urlopen(req, context=ctx) as resp:
        print('Telegram message sent successfully! Status:', resp.status)
except Exception as e:
    print('Telegram broadcast failed:', e)
