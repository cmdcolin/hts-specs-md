---
title: "CSIv1.tex"
commit: 85c048d
date: 19 Jul 2020
---

# CSIv1.tex
{:.no_toc}

This printing is version 85c048d from the [hts-specs](https://github.com/samtools/hts-specs) repository, last modified on 19 Jul 2020.

* Do not remove this line (it will not be displayed)
{:toc}

<table>
<thead>
<tr>
<th style="text-align: left;"><span>1-7</span></th>
<th style="text-align: center;"><strong>Description</strong></th>
<th style="text-align: center;"><strong>Type</strong></th>
<th style="text-align: center;"><strong>Value</strong></th>
<th style="text-align: left;"></th>
<th style="text-align: left;"></th>
<th style="text-align: right;"></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;">Magic string</td>
<td style="text-align: left;"><span><code>char[4]</code></span></td>
<td style="text-align: left;"><span><code>CSI 1</code></span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;"># bits for the minimal interval</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;">[14]</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;">Depth of the binning index</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;">[5]</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;">Length of auxiliary data</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;">[0]</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;">Auxiliary data</td>
<td
style="text-align: left;"><span><code>uint8_t[l_aux]</code></span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;"># reference sequences</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-7</span></td>
<td colspan="3" style="text-align: left;">n_bin</td>
<td style="text-align: left;"># distinct bins</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-7</span></td>
<td colspan="6" style="text-align: center;"><span
style="color: gray"><em>List of distinct bins (n=n_bin)</em></span></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-7</span></td>
<td style="text-align: left;"></td>
<td colspan="2" style="text-align: left;">bin</td>
<td style="text-align: left;">Distinct bin</td>
<td style="text-align: left;"><span><code>uint32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-7</span></td>
<td style="text-align: left;"></td>
<td colspan="2" style="text-align: left;">loffset</td>
<td style="text-align: left;">(Virtual) file offset of the first
overlapping record</td>
<td style="text-align: left;"><span><code>uint64_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-7</span></td>
<td style="text-align: left;"></td>
<td colspan="2" style="text-align: left;">n_chunk</td>
<td style="text-align: left;"># chunks</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-7</span></td>
<td style="text-align: left;"></td>
<td colspan="5" style="text-align: center;"><span
style="color: gray"><em>List of chunks (n=n_chunk)</em></span></td>
</tr>
<tr>
<td style="text-align: left;"><span>4-7</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>chunk_beg</span></td>
<td style="text-align: left;">(Virtual) file offset of the start of the
chunk</td>
<td style="text-align: left;"><span><code>uint64_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>4-7</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>chunk_end</span></td>
<td style="text-align: left;">(Virtual) file offset of the end of the
chunk</td>
<td style="text-align: left;"><span><code>uint64_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;"># unmapped unplaced reads
(<span>RNAME</span> *)</td>
<td style="text-align: left;"><span><code>uint64_t</code></span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-7</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
</tbody>
</table>

The following functions generalise those given in the SAM specification
for a BAI-style binning scheme. Note that in CSI *depth* refers to the
scheme’s maximal depth, i.e., the level number of the scheme’s smallest
bins, and the single-bin level spanning the entire coordinate range is
level 0. Hence the BAI-style binning scheme, with six levels in total,
is represented by $`\mbox{\sf min\_shift} = 14, \mbox{\sf depth} = 5`$.

CSI index files may contain metadata pseudo-bins for each reference
sequence, with the same contents as BAI pseudo-bins. In CSI, the
pseudo-bins have bin number
$`\mbox{\sf bin\_limit}(\mbox{\sf min\_shift}, \mbox{\sf depth}) + 1`$.

    /* calculate bin given an alignment covering [beg,end) (zero-based, half-close-half-open) */
    int reg2bin(int64_t beg, int64_t end, int min_shift, int depth)
    {
        int l, s = min_shift, t = ((1<<depth*3) - 1) / 7;
        for (--end, l = depth; l > 0; --l, s += 3, t -= 1<<l*3)
            if (beg>>s == end>>s) return t + (beg>>s);
        return 0;
    }

    /* calculate the list of bins that may overlap with region [beg,end) (zero-based) */
    int reg2bins(int64_t beg, int64_t end, int min_shift, int depth, int *bins)
    {
        int l, t, n, s = min_shift + depth*3;
        for (--end, l = n = t = 0; l <= depth; s -= 3, t += 1<<l*3, ++l) {
            int b = t + (beg>>s), e = t + (end>>s), i;
            for (i = b; i <= e; ++i) bins[n++] = i;
        }
        return n;
    }

    /* calculate maximum bin number -- valid bin numbers range within [0,bin_limit) */
    int bin_limit(int min_shift, int depth)
    {
        return ((1 << (depth+1)*3) - 1) / 7;
    }