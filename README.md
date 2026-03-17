# hts-specs-md

This is a fork of https://github.com/samtools/hts-specs/ that converts the tex
based hts-specs documents into markdown and then converts markdown to html for
the web

## Conversion notes

The conversion uses pandoc and an extensive lua conversion script (it is not a
uber-lightweight conversion). The result is optimized for HTML readability, so
is not a basic default pandoc usage

The conversion script was largely generated with Claude Code

I also tested htlatex

It is better in some ways and worse in others. It is actually a tossup and I am
not really sure about this project anymore
