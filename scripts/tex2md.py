#!/usr/bin/env python3
import subprocess
import sys
import os
import re

def run_command(cmd, shell=False):
    result = subprocess.run(cmd, shell=shell, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error running command: {cmd}")
        print(result.stderr)
        sys.exit(1)
    return result.stdout

def get_version_info(tex_file):
    output = run_command(["scripts/genversion.sh", tex_file])
    # output looks like:
    # \newcommand*\commitdesc{b5341fb}
    # \newcommand*\headdate{12 Aug 2025}
    commit_match = re.search(r'\\newcommand\*\\commitdesc\{([^}]+)\}', output)
    date_match = re.search(r'\\newcommand\*\\headdate\{([^}]+)\}', output)
    
    commit = commit_match.group(1) if commit_match else "unknown"
    date = date_match.group(1) if date_match else "unknown"
    return commit, date

def main():
    if len(sys.argv) < 2:
        print("Usage: tex2md.py <input.tex> [output.md]")
        sys.exit(1)

    input_tex = sys.argv[1]
    if len(sys.argv) > 2:
        output_md = sys.argv[2]
    else:
        output_md = input_tex.replace(".tex", ".md")

    commit, date = get_version_info(input_tex)
    
    # Ensure .ver file exists for pandoc to include if it's referenced in the TeX file
    ver_file = input_tex.replace(".tex", ".ver")
    if not os.path.exists(ver_file):
        with open(ver_file, 'w') as f:
            f.write(f"\\newcommand*\\commitdesc{{{commit}}}\n")
            f.write(f"\\newcommand*\\headdate{{{date}}}\n")

    # Extract title from TeX file
    with open(input_tex, 'r') as f:
        content = f.read()
    
    title_raw = input_tex
    title_start = content.find(r'\title{')
    if title_start != -1:
        start_pos = title_start + 7
        brace_count = 1
        for i in range(start_pos, len(content)):
            if content[i] == '{':
                brace_count += 1
            elif content[i] == '}':
                brace_count -= 1
            if brace_count == 0:
                title_raw = content[start_pos:i]
                break
    
    # Use pandoc to clean up the title
    title_proc = subprocess.run(["pandoc", "-f", "latex", "-t", "plain"], input=title_raw, capture_output=True, text=True)
    title = title_proc.stdout.strip()
    title = title.replace('\n', ' ').strip()
    # Normalize spaces
    title = re.sub(r'\s+', ' ', title)
    # Remove any stray { or } that might have been left over if pandoc failed to clean them
    title = title.replace('{', '').replace('}', '').strip()

    # We'll use a lua filter to handle some custom commands
    lua_filter = "scripts/pandoc-filter.lua"
    
    # Create a temporary TeX file without the preamble to avoid complex macro errors
    temp_tex = input_tex + ".tmp.tex"
    doc_start_match = re.search(r'\\begin\{document\}', content)
    if doc_start_match:
        body = content[doc_start_match.start():]
        # Strip problematic macros that confuse pandoc but aren't needed for MD
        body = re.sub(r'\\algblockdefx\[Foreach\].*?\n', '', body)
        body = re.sub(r'\\algnewcommand.*?\n', '', body)
        with open(temp_tex, 'w') as f:
            f.write(body)
    else:
        temp_tex = input_tex

    # Generate the Markdown
    cmd = [
        "pandoc",
        temp_tex,
        "-t", "gfm+gfm_auto_identifiers-tex_math_dollars-smart",
        "--lua-filter", lua_filter,
        "--markdown-headings=atx",
        "--katex",
        "-M", f"commit={commit}",
        "-M", f"date={date}",
    ]
    
    try:
        md_content = run_command(cmd)
    finally:
        if temp_tex != input_tex and os.path.exists(temp_tex):
            os.remove(temp_tex)

    # Add Jekyll front matter
    front_matter = f"""---
title: "{title}"
commit: {commit}
date: {date}
---

# {title}
{{:.no_toc}}

This printing is version {commit} from the [hts-specs](https://github.com/samtools/hts-specs) repository, last modified on {date}.

* Do not remove this line (it will not be displayed)
{{:toc}}

"""
    
    # Clean up some common pandoc artifacts
    # Remove everything up to and including the first # Title if it exists
    # or just start from the first # Section
    lines = md_content.splitlines()
    start_idx = 0
    found_title = False
    for i, line in enumerate(lines[:30]):
        if line.startswith("# "):
            start_idx = i + 1
            found_title = True
            break
            
    if not found_title:
        # If no # Title found, look for first ## Section
        for i, line in enumerate(lines[:30]):
            if line.startswith("## "):
                start_idx = i
                break

    final_content = front_matter + "\n".join(lines[start_idx:])
    
    # Replace curly quotes with straight quotes for a cleaner look
    final_content = final_content.replace('‘', "'").replace('’', "'")
    final_content = final_content.replace('“', '"').replace('”', '"')
    
    # Remove PDF artifacts like "Continued on next page"
    final_content = re.sub(r'<tr>\s*<td[^>]*><em>…Continued from previous.*?</td>\s*</tr>', '', final_content, flags=re.DOTALL | re.IGNORECASE)
    final_content = re.sub(r'<tr>\s*<td[^>]*><em>Continued on next.*?</td>\s*</tr>', '', final_content, flags=re.DOTALL | re.IGNORECASE)
    # Also catch them if they are not in <tr> (pandoc table artifacts)
    final_content = re.sub(r'<td[^>]*><em>…Continued from previous.*?</td>', '', final_content, flags=re.IGNORECASE)
    final_content = re.sub(r'<td[^>]*><em>Continued on next.*?</td>', '', final_content, flags=re.IGNORECASE)

    with open(output_md, 'w') as f:
        f.write(final_content)
    
    print(f"Converted {input_tex} to {output_md}")

if __name__ == "__main__":
    main()
