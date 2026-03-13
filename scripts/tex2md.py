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
    
    # Extract title from TeX file
    with open(input_tex, 'r') as f:
        content = f.read()
    
    title_match = re.search(r'\\title\{(.*?)\}', content, re.DOTALL)
    title_raw = title_match.group(1) if title_match else input_tex
    
    # Use pandoc to clean up the title
    title_proc = subprocess.run(["pandoc", "-f", "latex", "-t", "plain"], input=title_raw, capture_output=True, text=True)
    title = title_proc.stdout.strip()
    title = title.replace('\n', ' ').strip()
    # Normalize spaces
    title = re.sub(r'\s+', ' ', title)

    # We'll use a lua filter to handle some custom commands
    lua_filter = "scripts/pandoc-filter.lua"
    
    # Generate the Markdown
    cmd = [
        "pandoc",
        input_tex,
        "-t", "gfm+gfm_auto_identifiers-tex_math_dollars-smart",
        "--lua-filter", lua_filter,
        "--markdown-headings=atx",
        "-M", f"commit={commit}",
        "-M", f"date={date}",
    ]
    
    md_content = run_command(cmd)

    # Add Jekyll front matter
    front_matter = f"""---
layout: default
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

    with open(output_md, 'w') as f:
        f.write(final_content)
    
    print(f"Converted {input_tex} to {output_md}")

if __name__ == "__main__":
    main()
