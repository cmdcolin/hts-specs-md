---
title: "BCF2 Quick Reference (r198)"
commit: 405fa48
date: 24 Jun 2019
---

# BCF2 Quick Reference (r198)
{:.no_toc}

This printing is version 405fa48 from the [hts-specs](https://github.com/samtools/hts-specs) repository, last modified on 24 Jun 2019.

* Do not remove this line (it will not be displayed)
{:toc}

In BCF2, each key in the FILTER, INFO and FORMAT fields is required to
be defined in the VCF header. For each record, a key is stored as an
integer which is the index of its first appearance in the header.
‘` PASS`’ is always indexed at 0, which is special cased as VCF does not
require the presence of this word.

In BCF2, a typed value consists of a typing byte and the actual value
with type mandated by the typing byte. In the typing byte, the lowest
four bits give the atomic type. If the number represented by the higher
4 bits is smaller than 15, it is the size of the following vector; if
the number equals 15, the following typed integer is the array size. The
highest 4 bits of a Flag type equals 0 and in this case, no assumptions
can be made about the lower 4 bits. The table below gives the atomic
types and their missing values:

<div class="center">

| Bit 0–3 | C type    | Missing value | Description                         |
|--------:|:----------|--------------:|:------------------------------------|
|       1 | `int8_t`  |        `0x80` | signed 8-bit integer                |
|       2 | `int16_t` |      `0x8000` | signed 16-bit integer               |
|       3 | `int32_t` |  `0x80000000` | signed 32-bit integer               |
|       5 | `float`   |  `0x7F800001` | IEEE 32-bit floating pointer number |
|       7 | `char`    |        ‘` 0`’ | character                           |

</div>

A genotype (GT) is encoded as an integer vector with each integer
describing an allele and its phase w.r.t. the previous allele. The first
allele does not carry the phase information. In the vector, each integer
is organized as ‘` allele+1 1 phased`’ where `allele` is set to -1 if
the allele in GT is a dot ‘.’ (thus the higher bits are all 0). The
vector is padded with missing values if the GT having fewer ploidy.

A BCF2 file is BGZF compressed and all multi-byte value are little
endian.

<table>
<thead>
<tr>
<th style="text-align: left;"><span>1-6</span></th>
<th style="text-align: center;"><strong>Description</strong></th>
<th style="text-align: center;"><strong>Type</strong></th>
<th style="text-align: center;"><strong>Value</strong></th>
<th style="text-align: left;"></th>
<th style="text-align: right;"></th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;"><span>1-6</span></td>
<td style="text-align: left;">BCF2 magic string</td>
<td style="text-align: left;"><span><code>char[5]</code></span></td>
<td style="text-align: left;"><span><code>BCF 2 1</code></span></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-6</span></td>
<td style="text-align: left;">Length of the header text, including any
<span>NULL</span> padding</td>
<td style="text-align: left;"><span><code>uint32_t</code></span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-6</span></td>
<td style="text-align: left;"><span>NULL</span>-terminated plain VCF
header text</td>
<td
style="text-align: left;"><span><code>char[</code><span><code>l_text</code></span><code>]</code></span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">l_shared</td>
<td style="text-align: left;">Data length from <span>CHROM</span> to the
end of <span>INFO</span></td>
<td style="text-align: left;"><span><code>uint32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">l_indiv</td>
<td style="text-align: left;">Data length of <span>FORMAT</span> and
individual genotype fields</td>
<td style="text-align: left;"><span><code>uint32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">CHROM</td>
<td style="text-align: left;">Reference sequence ID</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">POS</td>
<td style="text-align: left;">0-based leftmost coordinate</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">rlen</td>
<td style="text-align: left;">Length of reference sequence</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">QUAL</td>
<td style="text-align: left;">Variant quality;
<span><code>0x7F800001</code></span> for a missing value</td>
<td style="text-align: left;"><span><code>float</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">n_allele_info</td>
<td
style="text-align: left;"><span><code>n_allele 16 n_info</code></span></td>
<td style="text-align: left;"><span><code>uint32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">n_fmt_sample</td>
<td
style="text-align: left;"><span><code>n_fmt 24 n_sample</code></span></td>
<td style="text-align: left;"><span><code>uint32_t</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">ID</td>
<td style="text-align: left;">Variant identifier</td>
<td style="text-align: left;"><span><code>typed str</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="5" style="text-align: center;"><span
style="color: gray"><em>List of alleles in the REF and ALT fields
(n=n_allele)</em></span></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>allele</span></td>
<td style="text-align: left;">A reference or alternate allele</td>
<td style="text-align: left;"><span><code>typed str</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="2" style="text-align: left;">FILTER</td>
<td style="text-align: left;">List of filters; filters are defined in
the dictionary</td>
<td style="text-align: left;"><span><code>typed vec</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="5" style="text-align: center;"><span
style="color: gray"><em>List of key-value pairs in the INFO field
(n=n_info)</em></span></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>info_key</span></td>
<td style="text-align: left;">Info key, defined in the dictionary</td>
<td style="text-align: left;"><span><code>typed int</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>info_value</span></td>
<td style="text-align: left;">Value</td>
<td style="text-align: left;"><span><code>typed val</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-6</span></td>
<td colspan="5" style="text-align: center;"><span
style="color: gray"><em>List of FORMATs and sample information
(n=n_fmt)</em></span></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>fmt_key</span></td>
<td style="text-align: left;">Format key, defined in the dictionary</td>
<td style="text-align: left;"><span><code>typed int</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>fmt_type</span></td>
<td style="text-align: left;">Typing byte of each individual value,
possibly followed by a typed int for the vector length</td>
<td style="text-align: left;"><span><code>uint8_t+</code></span></td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>3-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"><span>fmt_value</span></td>
<td style="text-align: left;">Array of values. The information of each
individual is concatenated in the vector. Every value is of the same
<span>fmt_type</span>. Variable-length vectors are padded with missing
values; a string is stored as a vector of
<span><code>char</code></span>.</td>
<td style="text-align: left;">(by <span>fmt_type</span>)</td>
<td style="text-align: right;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>1-6</span></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: right;"></td>
</tr>
</tbody>
</table>