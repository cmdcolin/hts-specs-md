---
title: "CSIv1.tex"
commit: 85c048d
date: 19 Jul 2020
---

<table>
<thead>
<tr>
<th><strong>Field</strong></th>
<th><strong>Description</strong></th>
<th><strong>Type</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>magic</td>
<td>Magic string</td>
<td><code>char[4]</code></td>
<td><code>CSI 1</code></td>
</tr>
<tr>
<td>min_shift</td>
<td># bits for the minimal interval</td>
<td><code>int32_t</code></td>
<td>[14]</td>
</tr>
<tr>
<td>depth</td>
<td>Depth of the binning index</td>
<td><code>int32_t</code></td>
<td>[5]</td>
</tr>
<tr>
<td>l_aux</td>
<td>Length of auxiliary data</td>
<td><code>int32_t</code></td>
<td>[0]</td>
</tr>
<tr>
<td>aux</td>
<td>Auxiliary data</td>
<td><code>uint8_t[l_aux]</code></td>
<td></td>
</tr>
<tr>
<td>n_ref</td>
<td># reference sequences</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td colspan="4"><span style="color: gray"><em>List of indices (n=n_ref)</em></span></td>
</tr>
<tr>
<td>n_bin</td>
<td># distinct bins</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td colspan="4"><span style="color: gray"><em>List of distinct bins
(n=n_bin)</em></span></td>
</tr>
<tr>
<td>bin</td>
<td>Distinct bin</td>
<td><code>uint32_t</code></td>
<td></td>
</tr>
<tr>
<td>loffset</td>
<td>(Virtual) file offset of the first overlapping record</td>
<td><code>uint64_t</code></td>
<td></td>
</tr>
<tr>
<td>n_chunk</td>
<td># chunks</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td colspan="4"><span style="color: gray"><em>List of chunks (n=n_chunk)</em></span></td>
</tr>
<tr>
<td><span>chunk_beg</span></td>
<td>(Virtual) file offset of the start of the chunk</td>
<td><code>uint64_t</code></td>
<td></td>
</tr>
<tr>
<td><span>chunk_end</span></td>
<td>(Virtual) file offset of the end of the chunk</td>
<td><code>uint64_t</code></td>
<td></td>
</tr>
<tr>
<td><span>n_no_coor</span> (optional)</td>
<td># unmapped unplaced reads (<span>RNAME</span> *)</td>
<td><code>uint64_t</code></td>
<td></td>
</tr>
</tbody>
</table>

The following functions generalise those given in the SAM specification
for a BAI-style binning scheme. Note that in CSI *depth* refers to the
scheme's maximal depth, i.e., the level number of the scheme's smallest
bins, and the single-bin level spanning the entire coordinate range is
level 0. Hence the BAI-style binning scheme, with six levels in total,
is represented by
$\sf \textit{min\_shift} = 14, \sf \textit{depth} = 5$.

CSI index files may contain metadata pseudo-bins for each reference
sequence, with the same contents as BAI pseudo-bins. In CSI, the
pseudo-bins have bin number
$\sf \textit{bin\_limit}(\sf \textit{min\_shift}, \sf \textit{depth}) + 1$.

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