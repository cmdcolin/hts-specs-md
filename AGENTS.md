# Agent Instructions

## Build Artifacts

The markdown files in `src/_posts/` are **generated build artifacts** — do not
edit them directly. They are produced by converting the canonical `.tex` source
files using the conversion pipeline:

```
scripts/tex2md.py <input.tex> src/_posts/<output.md>
```

To fix issues with the rendered markdown, edit the pipeline instead:

- `scripts/tex2md.py` — Python preprocessor that transforms LaTeX before pandoc
- `scripts/pandoc-filter.lua` — Pandoc Lua filter for custom AST transformations
- `src/layouts/Layout.astro` — Site layout and CSS

After modifying the pipeline, regenerate the affected markdown files:

```sh
# Regenerate a single file
python3 scripts/tex2md.py CRAMv3.tex src/_posts/CRAMv3.md

# Regenerate all files
for tex in BCFv1_qref BCFv2_qref BEDv1 CRAMcodecs CRAMv2.1 CRAMv3 CSIv1 SAMtags SAMv1 \
           VCFv4.1 VCFv4.2 VCFv4.3 VCFv4.4 VCFv4.5 crypt4gh tabix; do
  python3 scripts/tex2md.py "${tex}.tex" "src/_posts/${tex}.md"
done
```
