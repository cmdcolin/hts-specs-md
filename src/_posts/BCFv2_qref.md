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
<td><span><code>int8_t</code></span></td>
<td><span><code>0x80</code></span></td>
<td>signed 8-bit integer</td>
</tr>
<tr>
<td>2</td>
<td><span><code>int16_t</code></span></td>
<td><span><code>0x8000</code></span></td>
<td>signed 16-bit integer</td>
</tr>
<tr>
<td>3</td>
<td><span><code>int32_t</code></span></td>
<td><span><code>0x80000000</code></span></td>
<td>signed 32-bit integer</td>
</tr>
<tr>
<td>5</td>
<td><span><code>float</code></span></td>
<td><span><code>0x7F800001</code></span></td>
<td>IEEE 32-bit floating pointer number</td>
</tr>
<tr>
<td>7</td>
<td><span><code>char</code></span></td>
<td>'<span><code> 0</code></span>'</td>
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
<th><span>1-6</span></th>
<th><strong>Description</strong></th>
<th><strong>Type</strong></th>
<th><strong>Value</strong></th>
<th></th>
</tr>
</thead>
<tbody>
<tr>
<td><span>1-6</span></td>
<td>BCF2 magic string</td>
<td><span><code>char[5]</code></span></td>
<td><span><code>BCF 2 1</code></span></td>
<td></td>
</tr>
<tr>
<td><span>1-6</span></td>
<td>Length of the header text, including any <span>NULL</span> padding</td>
<td><span><code>uint32_t</code></span></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>1-6</span></td>
<td><span>NULL</span>-terminated plain VCF header text</td>
<td><span><code>char[</code><span><code>l_text</code></span><code>]</code></span></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>1-6</span></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>l_shared</td>
<td>Data length from <span>CHROM</span> to the end of <span>INFO</span></td>
<td><span><code>uint32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>l_indiv</td>
<td>Data length of <span>FORMAT</span> and individual genotype fields</td>
<td><span><code>uint32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>CHROM</td>
<td>Reference sequence ID</td>
<td><span><code>int32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>POS</td>
<td>0-based leftmost coordinate</td>
<td><span><code>int32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>rlen</td>
<td>Length of reference sequence</td>
<td><span><code>int32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>QUAL</td>
<td>Variant quality; <span><code>0x7F800001</code></span> for a missing
value</td>
<td><span><code>float</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>n_allele_info</td>
<td><span><code>n_allele 16 n_info</code></span></td>
<td><span><code>uint32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>n_fmt_sample</td>
<td><span><code>n_fmt 24 n_sample</code></span></td>
<td><span><code>uint32_t</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>ID</td>
<td>Variant identifier</td>
<td><span><code>typed str</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td><span style="color: gray"><em>List of alleles in the REF and ALT fields
(n=n_allele)</em></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>3-6</span></td>
<td></td>
<td><span>allele</span></td>
<td>A reference or alternate allele</td>
<td><span><code>typed str</code></span></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td>FILTER</td>
<td>List of filters; filters are defined in the dictionary</td>
<td><span><code>typed vec</code></span></td>
<td></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td><span style="color: gray"><em>List of key-value pairs in the INFO field
(n=n_info)</em></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>3-6</span></td>
<td></td>
<td><span>info_key</span></td>
<td>Info key, defined in the dictionary</td>
<td><span><code>typed int</code></span></td>
</tr>
<tr>
<td><span>3-6</span></td>
<td></td>
<td><span>info_value</span></td>
<td>Value</td>
<td><span><code>typed val</code></span></td>
</tr>
<tr>
<td><span>2-6</span></td>
<td><span style="color: gray"><em>List of FORMATs and sample information
(n=n_fmt)</em></span></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>3-6</span></td>
<td></td>
<td><span>fmt_key</span></td>
<td>Format key, defined in the dictionary</td>
<td><span><code>typed int</code></span></td>
</tr>
<tr>
<td><span>3-6</span></td>
<td></td>
<td><span>fmt_type</span></td>
<td>Typing byte of each individual value, possibly followed by a typed int
for the vector length</td>
<td><span><code>uint8_t+</code></span></td>
</tr>
<tr>
<td><span>3-6</span></td>
<td></td>
<td><span>fmt_value</span></td>
<td>Array of values. The information of each individual is concatenated in
the vector. Every value is of the same <span>fmt_type</span>.
Variable-length vectors are padded with missing values; a string is
stored as a vector of <span><code>char</code></span>.</td>
<td>(by <span>fmt_type</span>)</td>
</tr>
<tr>
<td><span>1-6</span></td>
<td></td>
<td></td>
<td></td>
<td></td>
</tr>
</tbody>
</table>