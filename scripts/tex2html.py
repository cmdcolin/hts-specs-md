#!/usr/bin/env python3
"""Convert TeX files to HTML using htlatex (tex4ht), then post-process to add
anchor links on section headings, a table of contents, and light styling."""

import subprocess
import sys
import os
import re
import tempfile
import shutil


def preprocess_tex_for_htlatex(tex_path):
    """Patch a TeX file to work around tex4ht incompatibilities."""
    with open(tex_path) as f:
        content = f.read()

    # Remove pdftex option from documentclass (causes backend mismatch with tex4ht)
    content = re.sub(r'\\documentclass\[([^]]*),?pdftex,?([^]]*)\]',
                     r'\\documentclass[\1\2]', content)
    content = re.sub(r'\\documentclass\[,+\]', r'\\documentclass[]', content)

    # Replace \ttfamily inside math mode (tex4ht can't handle it)
    content = re.sub(r'\{\\ttfamily\s+([^}]*)\}', r'\\mathrm{\1}', content)
    content = re.sub(r'\\ttfamily\b', r'\\mathrm', content)

    # Replace old-style \choose with \binom (tex4ht handles \binom better)
    # {a \choose b} → \binom{a}{b}
    def fix_choose(m):
        inner = m.group(1)
        parts = inner.split(r'\choose', 1)
        if len(parts) == 2:
            return r'\binom{' + parts[0].strip() + '}{' + parts[1].strip() + '}'
        return m.group(0)
    content = re.sub(r'\{([^{}]*\\choose[^{}]*)\}', fix_choose, content)

    # Fix tex4ht \hline:color bug — define it via AtBeginDocument so it's
    # available when tex4ht processes tables
    preamble_fix = r"""
\makeatletter
\AtBeginDocument{\expandafter\gdef\csname hline:color\endcsname{black}}
\makeatother
"""
    # Custom macro definitions - inject after \begin{document}
    body_defs = r"""
\makeatletter
\@ifundefined{cclass}{\newcommand*\cclass[1]{{\rmfamily\sffamily :#1:}}}{}
\@ifundefined{caret}{\newcommand*\caret{\textsuperscript{\ensuremath{\wedge}}}}{}
\@ifundefined{cigarops}{\newcommand*\cigarops[1]{#1}}{}
\@ifundefined{memlimited}{\newcommand*\memlimited{\textit{limited}}}{}
\makeatother
"""
    doc_start = content.find(r'\begin{document}')
    if doc_start >= 0:
        content = content[:doc_start] + preamble_fix + content[doc_start:]
        # Re-find after insertion
        doc_start = content.find(r'\begin{document}')
        insert_pos = doc_start + len(r'\begin{document}')
        content = content[:insert_pos] + '\n' + body_defs + content[insert_pos:]

    with open(tex_path, 'w') as f:
        f.write(content)


def run_htlatex(tex_file, output_dir):
    """Run htlatex on a TeX file, producing XHTML+MathML output."""
    basename = os.path.splitext(os.path.basename(tex_file))[0]

    # Work in a temp directory to avoid polluting the source tree
    with tempfile.TemporaryDirectory() as tmpdir:
        # Copy TeX file and generate version file
        shutil.copy(tex_file, tmpdir)
        tex_dir = os.path.dirname(os.path.abspath(tex_file))

        # Preprocess to fix tex4ht incompatibilities
        preprocess_tex_for_htlatex(os.path.join(tmpdir, f"{basename}.tex"))

        # Copy any .ver file or generate one
        ver_file = os.path.join(tex_dir, f"{basename}.ver")
        if not os.path.exists(ver_file):
            genversion = os.path.join(tex_dir, "scripts", "genversion.sh")
            if os.path.exists(genversion):
                result = subprocess.run(
                    [genversion, tex_file],
                    capture_output=True, text=True, cwd=tex_dir
                )
                with open(os.path.join(tmpdir, f"{basename}.ver"), 'w') as f:
                    f.write(result.stdout)
        else:
            shutil.copy(ver_file, tmpdir)

        # Copy image files that might be referenced
        img_dir = os.path.join(tex_dir, "img")
        if os.path.isdir(img_dir):
            shutil.copytree(img_dir, os.path.join(tmpdir, "img"))

        # Try htlatex first (runs full pipeline)
        # "xhtml,mathml,0" — 0 prevents page splitting into multiple files
        subprocess.run(
            ["htlatex", f"{basename}.tex", "xhtml,mathml,0", " -cmathml", "",
             "--interaction=nonstopmode"],
            capture_output=True, text=True, cwd=tmpdir
        )

        html_file = os.path.join(tmpdir, f"{basename}.html")
        if not os.path.exists(html_file):
            # htlatex may have aborted before tex4ht/t4ht due to errors,
            # but the DVI is usually still usable. Run tex4ht + t4ht manually.
            dvi_file = os.path.join(tmpdir, f"{basename}.dvi")
            if os.path.exists(dvi_file):
                subprocess.run(
                    ["tex4ht", "-f", basename],
                    capture_output=True, text=True, cwd=tmpdir
                )
                subprocess.run(
                    ["t4ht", "-f", basename],
                    capture_output=True, text=True, cwd=tmpdir
                )

        if not os.path.exists(html_file):
            print(f"Error: htlatex failed for {tex_file}", file=sys.stderr)
            return None

        # Merge split HTML pages into a single file if htlatex split the output
        split_pages = sorted([
            f for f in os.listdir(tmpdir)
            if f.startswith(basename) and f.endswith('.html') and f != f"{basename}.html"
        ])
        if split_pages:
            with open(html_file, encoding='iso-8859-1') as f:
                main_html = f.read()
            for page in split_pages:
                page_path = os.path.join(tmpdir, page)
                with open(page_path, encoding='iso-8859-1') as f:
                    page_html = f.read()
                # Extract body content from split page
                body_match = re.search(r'<body[^>]*>(.*)</body>', page_html, re.DOTALL)
                if body_match:
                    body_content = body_match.group(1)
                    # Insert before </body> of main file
                    main_html = main_html.replace('</body>', body_content + '\n</body>')
                os.remove(page_path)
            with open(html_file, 'w', encoding='iso-8859-1') as f:
                f.write(main_html)

        # Copy output files to destination
        os.makedirs(output_dir, exist_ok=True)
        for f in os.listdir(tmpdir):
            if f.endswith(('.html', '.css', '.svg', '.png')) and not re.match(rf'{re.escape(basename)}\d+\.html$', f):
                shutil.copy(os.path.join(tmpdir, f), output_dir)

        return os.path.join(output_dir, f"{basename}.html")


def postprocess_html(html_path, base_url="/hts-specs-md"):
    """Post-process htlatex HTML to add anchor links, TOC, and styling."""
    with open(html_path, encoding='iso-8859-1') as f:
        html = f.read()

    # Remove empty "array-hline" rows that tex4ht generates for \hline
    html = re.sub(r'<tr\s*\n?class="array-hline">(?:<td></td>)+</tr>', '', html)

    # Remove empty/whitespace-only table rows (tex4ht spacer rows from \hline, \cline)
    html = re.sub(
        r'<tr\s[^>]*>(?:\s*<td\s[^>]*>\s*</td>\s*)+</tr>',
        '', html
    )

    # Remove cline spacer rows (they add visual noise in HTML)
    html = re.sub(
        r'<tr\s*\n?\s*class="cline">.*?</tr>',
        '', html, flags=re.DOTALL
    )

    # Fix invalid CSS color "#black" generated by tex4ht (should be "black")
    html = html.replace('#black', 'black')

    # Fix tex4ht multicolumn: it emits <td></td> <div class="multicolumn">content</div>
    # instead of a proper <td colspan="N">. Convert the broken pattern into valid HTML.
    def fix_multicolumn(m):
        tr_attrs = m.group(1)
        content = m.group(2)
        empty_tds = re.findall(r'<td\s[^>]*>\s*</td>', content)
        mc_match = re.search(
            r'<div\s+class="multicolumn"\s*(?:style="([^"]*)")?\s*>(.*?)</div>',
            content, re.DOTALL
        )
        if mc_match:
            mc_style = mc_match.group(1) or ''
            mc_content = mc_match.group(2)
            colspan = len(empty_tds) + 1
            after_div = content[mc_match.end():]
            style_attr = f' style="{mc_style}"' if mc_style else ''
            return (f'<tr {tr_attrs}>'
                    f'<td colspan="{colspan}"{style_attr}>{mc_content}</td>'
                    f'{after_div}</tr>')
        return m.group(0)

    html = re.sub(
        r'<tr\s*\n?\s*((?:style|id|class)="[^"]*"(?:\s+(?:style|id|class)="[^"]*")*)\s*>'
        r'(.*?)</tr>',
        fix_multicolumn, html, flags=re.DOTALL
    )

    # Split longtables that have colspan section headers into separate tables.
    # htlatex renders \multicolumn rows poorly in nested tables (all section
    # headers get grouped at the top). Splitting into per-section tables fixes this.
    def split_longtable(table_match):
        full = table_match.group(0)
        # Only split tables that have colspan rows acting as section headers
        colspan_rows = list(re.finditer(r'<tr\s[^>]*><td\s+colspan="\d+"[^>]*>.*?</tr>', full, re.DOTALL))
        if len(colspan_rows) < 2:
            return full
        # Check if the first colspan row is a header row (bold text = column headers)
        first_content = colspan_rows[0].group(0)
        if 'cmbx' not in first_content:
            return full

        # Extract the colgroup/column definitions
        colgroup_match = re.search(r'(<colgroup.*?</colgroup>(?:\s*<colgroup.*?</colgroup>)*)', full, re.DOTALL)
        colgroups = colgroup_match.group(1) if colgroup_match else ''

        # The header row (Tag / Description) is the first colspan row
        header_row = colspan_rows[0].group(0)
        # Find the description cell that follows in the same row or next cell
        # Actually the header row has: <td colspan="2">Tag</td> <td>Description</td>
        # We need the full <tr> including all cells

        # Split into rows
        rows = list(re.finditer(r'<tr\s[^>]*>.*?</tr>', full, re.DOTALL))
        if not rows:
            return full

        # Find indices of section-header rows (colspan rows after the first header)
        section_starts = []
        for i, row in enumerate(rows):
            row_text = row.group(0)
            if '<td colspan=' in row_text or 'colspan=' in row_text:
                # Skip the very first row (column headers like "Tag" / "Description")
                if i == 0:
                    continue
                section_starts.append(i)

        if not section_starts:
            return full

        # Build separate tables
        result_parts = []
        # Get text before the table
        table_start = re.search(r'<table\s', full)
        wrapper_before = full[:table_match.start(1)] if table_match.lastindex else ''

        for sec_idx, start_row_idx in enumerate(section_starts):
            end_row_idx = section_starts[sec_idx + 1] if sec_idx + 1 < len(section_starts) else len(rows)
            section_row = rows[start_row_idx].group(0)

            # Extract section title from the colspan cell
            title_match = re.search(r'<td\s+colspan="\d+"[^>]*>(.*?)</td>', section_row, re.DOTALL)
            title_text = re.sub(r'<[^>]+>', '', title_match.group(1)).strip() if title_match else ''
            # Extract description from the next <td> in the same row
            desc_match = re.search(r'</td>\s*<td[^>]*>(.*?)</td>\s*</tr>', section_row, re.DOTALL)
            desc_html = desc_match.group(1).strip() if desc_match else ''

            # Build section heading
            result_parts.append(
                f'<h4 class="nested-table-section">'
                f'<code>{title_text}</code>'
                f'</h4>\n'
            )
            if desc_html:
                result_parts.append(f'<p>{desc_html}</p>\n')

            # Build sub-table with field rows, removing the empty first <td> from each
            sub_rows = [rows[j].group(0) for j in range(start_row_idx + 1, end_row_idx)]
            if sub_rows:
                result_parts.append('<table class="longtable">\n')
                result_parts.append('<tr><th>Tag</th><th>Description</th></tr>\n')
                for sr in sub_rows:
                    # Remove the empty first <td>...</td> that was the tag-group column
                    sr = re.sub(r'<td\s[^>]*>\s*</td>', '', sr, count=1)
                    result_parts.append(sr + '\n')
                result_parts.append('</table>\n')

        # Replace the original table+wrapper with the split tables
        return '\n'.join(result_parts)

    html = re.sub(
        r'<div class="longtable">\s*<table\s+id="[^"]*"\s+class="longtable"[^>]*>(.*?)</table>\s*</div>',
        split_longtable, html, flags=re.DOTALL
    )

    # Parse headings and build TOC
    heading_pattern = re.compile(
        r'<(h[2-5])\s+class="(\w+Head)">'
        r'(?:<span class="titlemark">([\d.]+)\s*</span>\s*)?'
        r'<a\s+\n?\s*id="([^"]*)">'
        r'</a>'
        r'(.*?)'
        r'</(h[2-5])>',
        re.DOTALL
    )

    toc_entries = []
    def replace_heading(m):
        tag = m.group(1)
        cls = m.group(2)
        section_num = (m.group(3) or '').strip()
        old_id = m.group(4)
        title_html = m.group(5).strip()
        # Clean title text for TOC
        title_text = re.sub(r'<[^>]+>', '', title_html).strip()

        # Create readable ID from section number
        anchor_id = section_num if section_num else old_id
        anchor_id = anchor_id.rstrip('.')

        depth = int(tag[1])
        toc_entries.append((depth, anchor_id, f"{section_num} {title_text}".strip()))

        return (
            f'<{tag} class="{cls}" id="{anchor_id}">'
            f'<span class="titlemark">{section_num} </span>'
            f'{title_html}'
            f' <a href="#{anchor_id}" class="header-anchor">#</a>'
            f'</{tag}>'
        )

    html = heading_pattern.sub(replace_heading, html)

    # Build TOC HTML using section number depth (count dots) instead of heading level
    if toc_entries:
        toc_html = '<details class="toc" open>\n<summary>Table of Contents</summary>\n<ul>\n'
        for _, anchor_id, text in toc_entries:
            sec_depth = anchor_id.count('.') + 1 if anchor_id and anchor_id[0].isdigit() else 1
            indent_class = f' class="depth-{sec_depth + 1}"' if sec_depth > 1 else ''
            toc_html += f'<li{indent_class}><a href="#{anchor_id}">{text}</a></li>\n'
        toc_html += '</ul>\n</details>\n'
    else:
        toc_html = ''

    # Inject TOC after the title block
    # Look for the end of the maketitle div
    maketitle_end = html.find('</div>', html.find('class="maketitle"'))
    if maketitle_end > 0:
        insert_pos = maketitle_end + len('</div>')
        html = html[:insert_pos] + '\n' + toc_html + html[insert_pos:]

    # Inject custom styles before </head>
    custom_css = """
<style>
  body {
    font-family: "Charter", "Bitstream Charter", "Georgia", serif;
    font-size: 0.95rem;
    line-height: 1.6;
    max-width: 900px;
    margin: 0 auto;
    padding: 2rem;
  }
  .header-anchor {
    text-decoration: none;
    font-size: 0.8em;
    opacity: 0.3;
  }
  .header-anchor:hover { opacity: 1; }
  h2, h3, h4, h5 {
    border-bottom: 1px solid #eaecef;
    padding-bottom: 0.3em;
    margin-top: 1.5rem;
  }
  :target { scroll-margin-top: 2rem; }
  .toc {
    background: #f6f8fa;
    padding: 0.5rem 0.75rem;
    border-radius: 6px;
    border: 1px solid #d1d5da;
    margin-bottom: 1.5rem;
    font-size: 0.8rem;
  }
  .toc summary { cursor: pointer; font-weight: 600; font-size: 0.85rem; }
  .toc ul { list-style: none; padding-left: 0; margin: 0.25rem 0 0; columns: 2; column-gap: 1.5rem; }
  .toc li { margin: 0.1rem 0; line-height: 1.25; break-inside: avoid; }
  .toc .depth-3 { padding-left: 0.75rem; }
  .toc .depth-4 { padding-left: 1.5rem; }
  .toc .depth-5 { padding-left: 2.25rem; }
  .toc a:hover { text-decoration: underline; }
  table { border-collapse: collapse; margin-bottom: 1rem; }
  td, th { border: 1px solid #ddd; padding: 2px 8px; }
  th { background-color: #f8f9fa; }
  .nested-table-section {
    border-bottom: none;
    margin-bottom: 0.25rem;
    margin-top: 1.5rem;
  }
  .nested-table-section + p { margin-top: 0; margin-bottom: 0.5rem; }
  .banner {
    background: #fff8e1;
    border: 1px solid #ffe082;
    border-radius: 6px;
    padding: 0.5rem 0.75rem;
    font-size: 0.85rem;
    margin-bottom: 1rem;
  }
  a, a span { color: revert; font-family: inherit; font-size: inherit; }
  nav { display: flex; gap: 1rem; margin-bottom: 2rem; align-items: center; }
  @media (max-width: 768px) {
    body { padding: 0.5rem; font-size: 0.9rem; }
    .toc ul { columns: 1; }
  }
</style>
"""
    html = html.replace('</head>', custom_css + '</head>')

    # Add navigation bar after <body>
    nav_html = f"""
<nav>
  <a href="{base_url}">hts-specs-md</a>
  <a href="{base_url}/about">About</a>
</nav>
"""
    html = re.sub(r'(<body[^>]*>)', r'\1\n' + nav_html, html)

    # Write back as UTF-8
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html)

    return html_path


def main():
    if len(sys.argv) < 3:
        print("Usage: tex2html.py <input.tex> <output_dir>")
        sys.exit(1)

    tex_file = sys.argv[1]
    output_dir = sys.argv[2]
    base_url = sys.argv[3] if len(sys.argv) > 3 else "/hts-specs-md"

    print(f"Converting {tex_file} with htlatex...")
    html_path = run_htlatex(tex_file, output_dir)
    if html_path:
        print(f"Post-processing {html_path}...")
        postprocess_html(html_path, base_url)
        print(f"Done: {html_path}")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
