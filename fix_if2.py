import glob

for path in glob.glob(".github/workflows/*.yml"):
    with open(path, 'r') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        if "if: \"${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}\"" in line:
            lines[i] = line.replace(
                'if: "${{ github.event.workflow_run.conclusion == \'success\' || github.event_name == \'workflow_dispatch\' }}"',
                'if: "${{ github.event_name == \'workflow_dispatch\' || (github.event_name == \'workflow_run\' && github.event.workflow_run.conclusion == \'success\') }}"'
            )

    with open(path, 'w') as f:
        f.writelines(lines)
