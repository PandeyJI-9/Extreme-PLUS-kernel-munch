import glob

for path in glob.glob(".github/workflows/*.yml"):
    with open(path, 'r') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        if line.strip().startswith("if: ${{"):
            # Replace 'if: ${{ ... }}' with 'if: "${{ ... }}"'
            # First, check if it's already quoted
            if not line.strip().startswith("if: \"${{"):
                # find the index of "if: "
                idx = line.find("if: ${{")
                new_line = line[:idx] + "if: \"" + line[idx+4:].strip() + "\"\n"
                lines[i] = new_line
        
        elif line.strip().startswith("if: steps.clang"):
             # It's fine, leave it
             pass

    with open(path, 'w') as f:
        f.writelines(lines)
