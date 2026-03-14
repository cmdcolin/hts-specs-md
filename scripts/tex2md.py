#!/usr/bin/env python3
import subprocess
import sys
import os
import re
import shutil
import tempfile

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

def extract_tikz_preamble(content):
    """Extract tikz-relevant commands for use in standalone documents.
    Scans the entire file (preamble and document body) but stops before the
    first tikzpicture, collecting:
    - tikz usepackage and usetikzlibrary declarations
    - single-line newcommand definitions (multi-line ones are skipped since
      they may depend on other preamble state not available in standalone)
    Skips renewcommand since it renews commands from packages not loaded in standalone."""
    first_tikz = content.find(r'\begin{tikzpicture}')
    search_text = content[:first_tikz] if first_tikz != -1 else content
    lines = []
    for line in search_text.split('\n'):
        stripped = line.strip()
        if re.match(r'\\usepackage(\[.*?\])?\{tikz', stripped):
            lines.append(line)
        elif re.match(r'\\usetikzlibrary', stripped):
            lines.append(line)
        elif re.match(r'\\tikzset', stripped):
            lines.append(line)
        elif re.match(r'\\newcommand\b', stripped):
            # Only include single-line definitions: braces must balance AND
            # the line must end with } after stripping inline comments
            # (to exclude multi-line defs where the body is on the next line).
            line_no_comment = re.sub(r'%.*$', '', line).rstrip()
            if line_no_comment.endswith('}') and line.count('{') == line.count('}'):
                lines.append(line)
    return '\n'.join(lines)


def find_tikzpictures(text):
    """Find all tikzpicture environments, returning list of (start, end, code) tuples."""
    results = []
    pattern = re.compile(r'\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}', re.DOTALL)
    for match in pattern.finditer(text):
        results.append((match.start(), match.end(), match.group()))
    return results


def compile_tikz_to_svg(tikz_code, preamble, output_svg_path):
    """Compile a tikzpicture environment to SVG using pdflatex + dvisvgm.
    Returns True on success, False on failure."""
    standalone_tex = (
        r'\documentclass{standalone}' + '\n'
        + preamble + '\n'
        + r'\begin{document}' + '\n'
        + tikz_code + '\n'
        + r'\end{document}' + '\n'
    )
    with tempfile.TemporaryDirectory() as tmpdir:
        tex_path = os.path.join(tmpdir, 'fig.tex')
        pdf_path = os.path.join(tmpdir, 'fig.pdf')
        svg_path = os.path.join(tmpdir, 'fig.svg')
        with open(tex_path, 'w') as f:
            f.write(standalone_tex)
        result = subprocess.run(
            ['pdflatex', '-interaction=nonstopmode', '-output-directory', tmpdir, tex_path],
            capture_output=True, text=True
        )
        if result.returncode != 0 or not os.path.exists(pdf_path):
            print(f"  pdflatex failed:\n{result.stdout[-800:]}")
            return False
        result = subprocess.run(
            ['dvisvgm', '--pdf', '--font-format=woff2', pdf_path, '-o', svg_path],
            capture_output=True, text=True
        )
        if result.returncode != 0 or not os.path.exists(svg_path):
            print(f"  dvisvgm failed:\n{result.stderr[-400:]}")
            return False
        os.makedirs(os.path.dirname(output_svg_path), exist_ok=True)
        shutil.copy(svg_path, output_svg_path)
        return True


def generate_tikz_svgs(content, tex_basename, img_dir):
    """Find all tikzpictures in content, compile each to SVG, and return
    the content with tikzpictures replaced by \\includegraphics references."""
    preamble = extract_tikz_preamble(content)
    doc_start_match = re.search(r'\\begin\{document\}', content)
    if not doc_start_match:
        return content
    body_start = doc_start_match.start()
    body = content[body_start:]
    figures = find_tikzpictures(body)
    if not figures:
        return content

    tikz_img_dir = os.path.join(img_dir, 'tikz')
    replacements = []
    for i, (start, end, tikz_code) in enumerate(figures):
        svg_filename = f"{tex_basename}_{i+1}.svg"
        svg_path = os.path.join(tikz_img_dir, svg_filename)
        img_ref = f"img/tikz/{svg_filename}"
        print(f"  Generating TikZ figure {i+1}/{len(figures)}: {svg_filename}")
        if compile_tikz_to_svg(tikz_code, preamble, svg_path):
            replacements.append((start, end, f"\\includegraphics{{{img_ref}}}"))
        else:
            print(f"  Warning: skipping TikZ figure {i+1} (compilation failed)")

    # Apply replacements in reverse order to preserve offsets
    new_body = body
    for start, end, replacement in reversed(replacements):
        new_body = new_body[:start] + replacement + new_body[end:]
    return content[:body_start] + new_body


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

    # Convert embedded TikZ diagrams to SVG before pandoc processing.
    # Requires pdflatex and dvisvgm; skipped silently if either is missing.
    tex_basename = os.path.splitext(os.path.basename(input_tex))[0]
    img_dir = os.path.join(os.path.dirname(input_tex) or '.', 'img')
    has_tikz_tools = (shutil.which('pdflatex') is not None and
                      shutil.which('dvisvgm') is not None)
    if re.search(r'\\begin\{tikzpicture\}', content) and has_tikz_tools:
        print(f"  Converting TikZ figures in {input_tex}...")
        content = generate_tikz_svgs(content, tex_basename, img_dir)

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
        # Convert \Call{Name}{args} to \textsc{Name}(args) since pandoc drops \Call
        body = re.sub(r'\\Call{(\w+)}{([^}]*)}', r'\\textsc{\1}(\2)', body)
        with open(temp_tex, 'w') as f:
            f.write(body)
    else:
        temp_tex = input_tex

    # Generate the Markdown
    cmd = [
        "pandoc",
        temp_tex,
        "-t", "gfm-tex_math_gfm+tex_math_dollars",
        "--lua-filter", lua_filter,
        "--markdown-headings=atx",
        "--mathjax",  # preserves $...$ delimiters for remark-math to process
        "-M", f"commit={commit}",
        "-M", f"date={date}",
    ]
    
    try:
        md_content = run_command(cmd)
    finally:
        if temp_tex != input_tex and os.path.exists(temp_tex):
            os.remove(temp_tex)

    # Add YAML front matter for Astro
    front_matter = f"""---
title: "{title}"
commit: {commit}
date: {date}
---

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
    
    # Fix image paths for Astro (they are now in public/img)
    final_content = final_content.replace('src="img/', 'src="/hts-specs-md/img/')
    final_content = final_content.replace('](img/', '](/hts-specs-md/img/')

    # Remove PDF longtable artifacts ("Continued on next page", duplicate headers)
    final_content = re.sub(r'<tr>\s*<td[^>]*><em>…?Continued from previous.*?</td>\s*</tr>', '', final_content, flags=re.DOTALL | re.IGNORECASE)
    final_content = re.sub(r'<tr>\s*<td[^>]*><em>Continued on next.*?</td>\s*</tr>', '', final_content, flags=re.DOTALL | re.IGNORECASE)
    final_content = re.sub(r'<em>…?Continued from previous.*?</em>', '', final_content, flags=re.IGNORECASE)
    final_content = re.sub(r'<em>Continued on next.*?</em>', '', final_content, flags=re.IGNORECASE)
    final_content = re.sub(r'<tr>\s*<td[^>]*>(?:Key|Field)</td>\s*<td[^>]*>Number</td>\s*<td[^>]*>Type</td>\s*<td[^>]*>Description</td>\s*</tr>', '', final_content, flags=re.DOTALL | re.IGNORECASE)

    # Fix nested $ in \text{}/\textrm{} inside math - remark-math splits on inner $
    # e.g. \textrm{if $i < 1$} -> \textrm{if } i < 1
    final_content = re.sub(
        r'\\(text(?:rm)?)\{([^$}]*)\$([^$]*)\$([^}]*)\}',
        r'\\\1{\2} \3 \\\1{\4}',
        final_content
    )
    # Clean up empty \text{} / \textrm{} left by the above
    final_content = re.sub(r'\\text(?:rm)?\{\}', '', final_content)

    # KaTeX requires {aligned} instead of {align*} inside $$ display math
    final_content = final_content.replace(r'\begin{align*}', r'\begin{aligned}')
    final_content = final_content.replace(r'\end{align*}', r'\end{aligned}')

    with open(output_md, 'w') as f:
        f.write(final_content)
    
    print(f"Converted {input_tex} to {output_md}")

if __name__ == "__main__":
    main()
