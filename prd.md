# tex-to-markdown conversion TODOs

In this repo we are scripting the conversion of tex files to markdown and then
rendering with astro to html

This file contains tasks

Please update the PRD document when finished with tasks

## High priority

- [ ] **Footnotes embedded inside table cells**: Pandoc inlines `\footnote{}`
      from TeX tabular cells into `<td>` elements instead of collecting them at
      document end. Also produces duplicate `id="fn1"` across multiple
      footnotes. Affects BEDv1.md (5 instances), SAMv1.md (6 instances).

- [ ] **`\bytebox`/`\tagfield` diagrams lost**: SAMv1.tex uses custom
      picture-drawing macros (`\firstbytebox`, `\bytebox`, `\byteboxvector`,
      `\tagfield`) for byte-layout diagrams. These are silently dropped, leaving
      empty shell tables. The Lua filter has partial handlers for
      `\firstbytebox` and `\bytebox` but the compound `\tagfield` command isn't
      handled. (~4 diagram blocks in SAMv1.tex around lines 1146-1197)

## Medium priority

- [ ] **`\sf` font switch in math (SAMv1)**: Old LaTeX 2.09 `\sf` command used
      inside `$...$` is not supported by KaTeX. Appears at SAMv1.md lines ~1603,
      1610, 1655, 1661.

- [ ] **`\textsf{\textit{...}}` inside math (BEDv1)**: `\textsf` is not
      supported in KaTeX math mode. Appears at BEDv1.md lines ~316, 343, 517,
      519, 521.

- [ ] **Empty-body header-only tables**: Single-row TeX tabulars (no `\hline`
      separator) get their only row promoted to `<thead>`, leaving `<tbody>`
      empty. Affects SAMv1.md, CRAMv2.1.md, CRAMv3.md, and VCFv4.1-4.5.md (~6
      each for BCF encoding example tables).

## Low priority

- [ ] **`smallcaps` + math split expressions**: e.g. CRAMcodecs.md:38 has
      `$\textit{instance}$.<span class="smallcaps">Function</span>` where the
      dot-notation is split across math and HTML span.

- [ ] **Failed TikZ figures silently dropped**: If `pdflatex`/`dvisvgm` fail to
      compile a TikZ figure, it is skipped with a warning but no placeholder is
      inserted in the markdown.
