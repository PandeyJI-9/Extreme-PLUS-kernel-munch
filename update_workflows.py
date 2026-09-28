import os
import re

def update_file(filename, trigger_workflow, success_only=True):
    with open(filename, 'r') as f:
        content = f.read()

    # Remove existing workflow_run if any to prevent duplicates
    content = re.sub(r'\s*workflow_run:[\s\S]*?(?=\n\s*[a-zA-Z_]+:)', '', content)

    # Insert workflow_run under 'on:'
    run_block = f"""
  workflow_run:
    workflows: ["{trigger_workflow}"]
    types: [completed]
"""
    content = content.replace('\non:\n  workflow_dispatch:', '\non:\n  workflow_dispatch:' + run_block)

    # If it needs success check, inject it into jobs
    if success_only:
        content = re.sub(
            r'(jobs:\n\s+[a-zA-Z0-9_-]+:\n)',
            r'\1    if: ${{ github.event.workflow_run.conclusion == \'success\' || github.event_name == \'workflow_dispatch\' }}\n',
            content,
            count=1
        )

    with open(filename, 'w') as f:
        f.write(content)

os.chdir('.github/workflows')
update_file('verifier.yml', '🧪 Fast CI Test (defconfig + DTB)')
update_file('builder.yml', '☣️ GOD-LEVEL Diagnostics & Audit')
update_file('releaser_and_sync.yml', '🔨 Build EXTREME++GAMING Kernel')
