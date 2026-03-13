---
title: "BCFv1_qref.tex"
commit: 39feb09
date: 20 Nov 2019
---

# BCFv1_qref.tex
{:.no_toc}

This printing is version 39feb09 from the [hts-specs](https://github.com/samtools/hts-specs) repository, last modified on 20 Nov 2019.

* Do not remove this line (it will not be displayed)
{:toc}

<div class="center">

<table>
<thead>
<tr>
<th colspan="2" style="text-align: center;"><strong>Field</strong></th>
<th style="text-align: center;"><strong>Description</strong></th>
<th style="text-align: center;"><strong>Type</strong></th>
<th style="text-align: center;"><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td colspan="2" style="text-align: left;">magic</td>
<td style="text-align: left;">Magic string</td>
<td style="text-align: left;"><span><code>char[4]</code></span></td>
<td style="text-align: left;"><span><code>BCF 4</code></span></td>
</tr>
<tr>
<td colspan="2" style="text-align: left;">l_seqnm</td>
<td style="text-align: left;">Length of concatenated sequence names</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="2" style="text-align: left;">seqnm</td>
<td style="text-align: left;">Concatenated names,
<span><code>NULL</code></span> padded</td>
<td
style="text-align: left;"><span><code>char[</code><span><code>l_seqnm</code></span><code>]</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="2" style="text-align: left;">l_smpl</td>
<td style="text-align: left;">Length of concatenated sample names</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="2" style="text-align: left;">smpl</td>
<td style="text-align: left;">Concatenated sample names</td>
<td
style="text-align: left;"><span><code>char[</code><span><code>l_smpl</code></span><code>]</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="2" style="text-align: left;">l_meta</td>
<td style="text-align: left;">Length of the meta text (double-hash
lines)</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="2" style="text-align: left;">meta</td>
<td style="text-align: left;">Meta text, <span><code>NULL</code></span>
terminated</td>
<td
style="text-align: left;"><span><code>char[</code><span><code>l_meta</code></span><code>]</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="5" style="text-align: center;"><em></em></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-5</span></td>
<td style="text-align: left;"><span>seq_id</span></td>
<td style="text-align: left;">Reference sequence ID</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-5</span></td>
<td style="text-align: left;"><span>pos</span></td>
<td style="text-align: left;">Position</td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-5</span></td>
<td style="text-align: left;"><span>qual</span></td>
<td style="text-align: left;">Variant quality</td>
<td style="text-align: left;"><span><code>float</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-5</span></td>
<td style="text-align: left;"><span>l_str</span></td>
<td style="text-align: left;">Length of <span>str</span></td>
<td style="text-align: left;"><span><code>int32_t</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-5</span></td>
<td style="text-align: left;"><span>str</span></td>
<td
style="text-align: left;"><span><code>ID+REF+ALT+FILTER+INFO+FORMAT</code></span>,
<span><code>NULL</code></span> padded</td>
<td
style="text-align: left;"><span><code>char[</code><span><code>l_str</code></span><code>]</code></span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"><span>2-5</span></td>
<td colspan="4" style="text-align: center;">Blocks of data; #blocks and
formats defined by <span><code>FORMAT</code></span> (table below)</td>
</tr>
</tbody>
</table>

</div>

<div class="center">

| **Field** | **Type** | **Description** |
|:--:|:---|:---|
| `DP` | `uint16_t[n]` | Read depth |
| `GL` | `float[n*G]` | Log10 likelihood of data; $`G=\frac{A(A+1)}{2}`$, $`A=\#\{alleles\}`$ |
| `GT` | `uint8_t[n]` | `missing 7 | phased 6 | allele1 3 | allele2` |
| `_GT` | `uint8_t+uint8_t[n*P]` | Generic GT; the first int equals the max ploidy $`P`$. If the highest bit is set, the allele is not present (e.g. due to different ploidy between samples). |
| `GQ` | `uint8_t[n]` | Genotype quality |
| `HQ` | `uint8_t[n*2]` | Haplotype quality |
| `_HQ` | `uint8_t+uint8_t[n*P]` | Generic HQ |
| `IBD` | `uint32_t[n*2]` | IBD |
| `_IBD` | `uint8_t+uint32_t[n*P]` | Generic IBD |
| `PL` | `uint8_t[n*G]` | Phred-scaled likelihood of data |
| `PS` | `uint32_t[n]` | Phase set |
| *Integer* | `int32_t[n*X]` | Fix-sized custom Integer; $`X`$ defined in the header |
| *Numeric* | `double[n*X]` | Fix-sized custom Numeric |
| *String* | `uint32_t+char*` | `NULL` padded concat. strings (int equals to the length) |

</div>

- A BCF file is in the `BGZF` format.

- All multi-byte numbers are little-endian.

- In a string, a missing value ‘.’ is an empty C string “` 0`” (not
  “`. 0`”)

- For `GL` and `PL`, likelihoods of genotypes appear in the order of
  alleles in `REF` and then `ALT`. For example, if ` REF=C`, `ALT=T,A`,
  likelihoods appear in the order of ` CC,CT,TT,CA,TA,AA` (NB: the
  ordering is different from the one in the original BCF proposal).

- Predefined `FORMAT` fields can be missing from VCF headers, but custom
  `FORMAT` fields are required to be explicitly defined in the headers.

- A `FORMAT` field with its name starting with ‘`_`’ is specific to BCF
  only. It gives an alternative binary representation of the
  corresponding VCF field, in case the default representation is unable
  to keep the genotype information, for example, when the ploidy is not
  2 or there are more than 8 alleles.