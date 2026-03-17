# Completed tex-to-markdown conversion tasks

- [x] **`\bytebox`/`\tagfield` diagrams lost**: Fixed — `tex2md.py` now
      pre-processes bytebox macros (`\tagfield`, `\arraytagfield`,
      `\byteboxvector`, `\firstbytebox`, `\bytebox`) into HTML tables before
      Pandoc runs. All 4 diagram blocks in SAMv1.tex are now rendered.

- [x] **Empty-body header-only tables**: Fixed — the Lua filter now strips empty
      `<tbody></tbody>` from the HTML output. Zero empty tbody elements remain
      across all files.

- [x] **`\textsf{\textit{...}}` in table cells**: Fixed — the Lua filter now
      converts math expressions containing `\textsf` to inline HTML elements
      (`<span class="sans-serif">`) instead of broken MathML. Affects BEDv1.md
      and CRAMcodecs.md.

- [x] **`smallcaps` + math split expressions**: Not a bug — the rendering is
      correct. `$\textit{instance}$.<span class="smallcaps">Function</span>`
      renders as expected with math italic + dot + small caps.

- [x] **Failed TikZ figures silently dropped**: Not a bug — all 10
      tikzpictures across 4 files compile to SVG successfully.
