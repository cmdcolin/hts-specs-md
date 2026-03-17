---
title: "BCF2 Quick Reference (r198)"
commit: 405fa48
date: 24 Jun 2019
---

In BCF2, each key in the FILTER, INFO and FORMAT fields is required to
be defined in the VCF header. For each record, a key is stored as an
integer which is the index of its first appearance in the header.
'` PASS`' is always indexed at 0, which is special cased as VCF does not
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

<table>
<thead>
<tr>
<th>Bit 0–3</th>
<th>C type</th>
<th>Missing value</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td><code>int8_t</code></td>
<td><code>0x80</code></td>
<td>signed 8-bit integer</td>
</tr>
<tr>
<td>2</td>
<td><code>int16_t</code></td>
<td><code>0x8000</code></td>
<td>signed 16-bit integer</td>
</tr>
<tr>
<td>3</td>
<td><code>int32_t</code></td>
<td><code>0x80000000</code></td>
<td>signed 32-bit integer</td>
</tr>
<tr>
<td>5</td>
<td><code>float</code></td>
<td><code>0x7F800001</code></td>
<td>IEEE 32-bit floating pointer number</td>
</tr>
<tr>
<td>7</td>
<td><code>char</code></td>
<td>'<code> 0</code>'</td>
<td>character</td>
</tr>
</tbody>
</table>

</div>

A genotype (GT) is encoded as an integer vector with each integer
describing an allele and its phase w.r.t. the previous allele. The first
allele does not carry the phase information. In the vector, each integer
is organized as '` allele+1 1 phased`' where `allele` is set to -1 if
the allele in GT is a dot '.' (thus the higher bits are all 0). The
vector is padded with missing values if the GT having fewer ploidy.

A BCF2 file is BGZF compressed and all multi-byte value are little
endian.

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
<td>BCF2 magic string</td>
<td><code>char[5]</code></td>
<td><code>BCF 2 1</code></td>
</tr>
<tr>
<td>l_text</td>
<td>Length of the header text, including any <span>NULL</span> padding</td>
<td><code>uint32_t</code></td>
<td></td>
</tr>
<tr>
<td>text</td>
<td><span>NULL</span>-terminated plain VCF header text</td>
<td><code>char[l_text]</code></td>
<td></td>
</tr>
<tr>
<td colspan="4"><span style="color: gray"><em>List of VCF records (until the end of the
BGZF section)</em></span></td>
</tr>
<tr>
<td>l_shared</td>
<td>Data length from <span>CHROM</span> to the end of <span>INFO</span></td>
<td><code>uint32_t</code></td>
<td></td>
</tr>
<tr>
<td>l_indiv</td>
<td>Data length of <span>FORMAT</span> and individual genotype fields</td>
<td><code>uint32_t</code></td>
<td></td>
</tr>
<tr>
<td>CHROM</td>
<td>Reference sequence ID</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td>POS</td>
<td>0-based leftmost coordinate</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td>rlen</td>
<td>Length of reference sequence</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td>QUAL</td>
<td>Variant quality; <code>0x7F800001</code> for a missing value</td>
<td><code>float</code></td>
<td></td>
</tr>
<tr>
<td>n_allele_info</td>
<td><code>n_allele 16 n_info</code></td>
<td><code>uint32_t</code></td>
<td></td>
</tr>
<tr>
<td>n_fmt_sample</td>
<td><code>n_fmt 24 n_sample</code></td>
<td><code>uint32_t</code></td>
<td></td>
</tr>
<tr>
<td>ID</td>
<td>Variant identifier</td>
<td><code>typed str</code></td>
<td></td>
</tr>
<tr>
<td colspan="4"><span style="color: gray"><em>List of alleles in the REF and ALT fields
(n=n_allele)</em></span></td>
</tr>
<tr>
<td><span>allele</span></td>
<td>A reference or alternate allele</td>
<td><code>typed str</code></td>
<td></td>
</tr>
<tr>
<td>FILTER</td>
<td>List of filters; filters are defined in the dictionary</td>
<td><code>typed vec</code></td>
<td></td>
</tr>
<tr>
<td colspan="4"><span style="color: gray"><em>List of key-value pairs in the INFO field
(n=n_info)</em></span></td>
</tr>
<tr>
<td><span>info_key</span></td>
<td>Info key, defined in the dictionary</td>
<td><code>typed int</code></td>
<td></td>
</tr>
<tr>
<td><span>info_value</span></td>
<td>Value</td>
<td><code>typed val</code></td>
<td></td>
</tr>
<tr>
<td colspan="4"><span style="color: gray"><em>List of FORMATs and sample information
(n=n_fmt)</em></span></td>
</tr>
<tr>
<td><span>fmt_key</span></td>
<td>Format key, defined in the dictionary</td>
<td><code>typed int</code></td>
<td></td>
</tr>
<tr>
<td><span>fmt_type</span></td>
<td>Typing byte of each individual value, possibly followed by a typed int
for the vector length</td>
<td><code>uint8_t+</code></td>
<td></td>
</tr>
<tr>
<td><span>fmt_value</span></td>
<td>Array of values. The information of each individual is concatenated in
the vector. Every value is of the same <span>fmt_type</span>.
Variable-length vectors are padded with missing values; a string is
stored as a vector of <code>char</code>.</td>
<td>(by <span>fmt_type</span>)</td>
<td></td>
</tr>
</tbody>
</table>