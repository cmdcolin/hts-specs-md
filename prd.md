# tex-to-markdown conversion TODOs

In this repo we are scripting the conversion of tex files to markdown and then
rendering with astro to html

This file contains tasks

Please move completed items of the PRD to COMPLETED.md

## Low priority

- [ ] **Footnotes embedded inside table cells**: Pandoc inlines `\footnote{}`
      from TeX tabular cells into `<td>` elements instead of collecting them at
      document end. Also produces duplicate `id="fn1"` across multiple
      footnotes. Affects BEDv1.md (5 instances), SAMv1.md (6 instances).
