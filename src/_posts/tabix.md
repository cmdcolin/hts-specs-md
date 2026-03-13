---
title: "The Tabix index file format"
commit: 38f353f
date: 6 Jun 2018
---

This printing is version 38f353f from the [hts-specs](https://github.com/samtools/hts-specs) repository, last modified on 6 Jun 2018.

<div class="center">

<table>
<thead>
<tr>
<th><strong>Field</strong></th>
<th><strong>Description</strong></th>
<th><strong>Type</strong></th>
<th><strong>Value</strong></th>
<th></th>
<th></th>
</tr>
</thead>
<tbody>
<tr>
<td><code>magic</code></td>
<td>Magic string</td>
<td><span><code>char[4]</code></span></td>
<td>TBI<span class="math inline">∖</span>1</td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>n_ref</code></td>
<td># sequences</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>format</code></td>
<td>Format (0: generic; 1: SAM; 2: VCF)</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>col_seq</code></td>
<td>Column for the sequence name</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>col_beg</code></td>
<td>Column for the start of a region</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>col_end</code></td>
<td>Column for the end of a region</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>meta</code></td>
<td>Leading character for comment lines</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>skip</code></td>
<td># lines to skip at the beginning</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>l_nm</code></td>
<td>Length of concatenated sequence names</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><code>names</code></td>
<td>Concatenated names, each zero terminated</td>
<td><span><code>char[l_nm]</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span style="color: gray"><em>List of indices (n=n_ref)</em></span></td>
<td></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>2-7</span></td>
<td><code>n_bin</code></td>
<td># distinct bins (for the binning index)</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>2-7</span></td>
<td><span style="color: gray"><em>List of distinct bins
(n=n_bin)</em></span></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>3-7</span></td>
<td></td>
<td><code>bin</code></td>
<td>Distinct bin number</td>
<td><span><code>uint32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>3-7</span></td>
<td></td>
<td><code>n_chunk</code></td>
<td># chunks</td>
<td><span><code>int32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>3-7</span></td>
<td></td>
<td><span style="color: gray"><em>List of chunks (n=n_chunk)</em></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>4-7</span></td>
<td></td>
<td></td>
<td><span><code>cnk_beg</code></span></td>
<td>Virtual file offset of the start of the chunk</td>
<td><span><code>uint64_t</code></span></td>
</tr>
<tr>
<td><span>4-7</span></td>
<td></td>
<td></td>
<td><span><code>cnk_end</code></span></td>
<td>Virtual file offset of the end of the chunk</td>
<td><span><code>uint64_t</code></span></td>
</tr>
<tr>
<td><span>2-7</span></td>
<td><code>n_intv</code></td>
<td># 16kb intervals (for the linear index)</td>
<td><span><code>int32_t</code></span></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>2-7</span></td>
<td><span style="color: gray"><em>List of distinct intervals
(n=n_intv)</em></span></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>3-7</span></td>
<td></td>
<td><code>ioff</code></td>
<td>File offset of the first record in the interval</td>
<td><span><code>uint64_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span><code>n_no_coor</code></span> (optional)</td>
<td># unmapped reads without coordinates set</td>
<td><span><code>uint64_t</code></span></td>
<td></td>
<td></td>
<td></td>
</tr>
</tbody>
</table>

</div>

**Notes:**

- The index file is BGZF compressed.

- All integers are little-endian.

- When `(format&0x10000)` is true, the coordinate follows the `BED` rule
  (i.e. half-closed-half-open and zero based); otherwise, the coordinate
  follows the `GFF` rule (closed and one based).

- For the SAM format, the end of a region equals `POS` plus the
  reference length in the alignment, inferred from `CIGAR`. For the VCF
  format, the end of a region equals `POS` plus the size of the
  deletion.

- Field `col_beg` may equal `col_end`, and in this case, the end of a
  region is `end`=`beg+1`.

- Example. For `GFF`, `format`=0, `col_seq`=1, ` col_beg`=4,
  `col_end`=5, `meta`='`#`' and ` skip`=0. For `BED`, `format`=0x10000,
  `col_seq`=1, ` col_beg`=2, `col_end`=3, `meta`='`#`' and ` skip`=0.

- Given a zero-based, half-closed and half-open region ` [beg, end)`,
  the `bin` number is calculated with the following C function:

      int reg2bin(int beg, int end) {
        --end;
        if (beg>>14 == end>>14) return ((1<<15)-1)/7 + (beg>>14);
        if (beg>>17 == end>>17) return ((1<<12)-1)/7 + (beg>>17);
        if (beg>>20 == end>>20) return  ((1<<9)-1)/7 + (beg>>20);
        if (beg>>23 == end>>23) return  ((1<<6)-1)/7 + (beg>>23);
        if (beg>>26 == end>>26) return  ((1<<3)-1)/7 + (beg>>26);
        return 0;
      }

- The list of bins that may overlap a region `[beg, end)` can be
  obtained with the following C function.

      #define MAX_BIN (((1<<18)-1)/7)
      int reg2bins(int rbeg, int rend, uint16_t list[MAX_BIN])
      {
        int i = 0, k;
        --rend;
        list[i++] = 0;
        for (k =    1 + (rbeg>>26); k <=    1 + (rend>>26); ++k) list[i++] = k;
        for (k =    9 + (rbeg>>23); k <=    9 + (rend>>23); ++k) list[i++] = k;
        for (k =   73 + (rbeg>>20); k <=   73 + (rend>>20); ++k) list[i++] = k;
        for (k =  585 + (rbeg>>17); k <=  585 + (rend>>17); ++k) list[i++] = k;
        for (k = 4681 + (rbeg>>14); k <= 4681 + (rend>>14); ++k) list[i++] = k;
        return i; // #elements in list[]
      }