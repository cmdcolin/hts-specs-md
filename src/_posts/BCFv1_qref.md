---
title: "BCFv1_qref.tex"
commit: 39feb09
date: 20 Nov 2019
---

<div class="center">

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
<td><code>BCF 4</code></td>
</tr>
<tr>
<td>l_seqnm</td>
<td>Length of concatenated sequence names</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td>seqnm</td>
<td>Concatenated names, <code>NULL</code> padded</td>
<td><code>char[l_seqnm]</code></td>
<td></td>
</tr>
<tr>
<td>l_smpl</td>
<td>Length of concatenated sample names</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td>smpl</td>
<td>Concatenated sample names</td>
<td><code>char[l_smpl]</code></td>
<td></td>
</tr>
<tr>
<td>l_meta</td>
<td>Length of the meta text (double-hash lines)</td>
<td><code>int32_t</code></td>
<td></td>
</tr>
<tr>
<td>meta</td>
<td>Meta text, <code>NULL</code> terminated</td>
<td><code>char[l_meta]</code></td>
<td></td>
</tr>
<tr>
<td><em></em></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td><span>2-5</span></td>
<td><span>seq_id</span></td>
<td>Reference sequence ID</td>
<td><code>int32_t</code></td>
</tr>
<tr>
<td><span>2-5</span></td>
<td><span>pos</span></td>
<td>Position</td>
<td><code>int32_t</code></td>
</tr>
<tr>
<td><span>2-5</span></td>
<td><span>qual</span></td>
<td>Variant quality</td>
<td><code>float</code></td>
</tr>
<tr>
<td><span>2-5</span></td>
<td><span>l_str</span></td>
<td>Length of <span>str</span></td>
<td><code>int32_t</code></td>
</tr>
<tr>
<td><span>2-5</span></td>
<td><span>str</span></td>
<td><code>ID+REF+ALT+FILTER+INFO+FORMAT</code>, <code>NULL</code> padded</td>
<td><code>char[l_str]</code></td>
</tr>
<tr>
<td><span>2-5</span></td>
<td>Blocks of data; #blocks and formats defined by <code>FORMAT</code>
(table below)</td>
<td></td>
<td></td>
</tr>
</tbody>
</table>

</div>

<div class="center">

<table>
<thead>
<tr>
<th><strong>Field</strong></th>
<th><strong>Type</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td><code>DP</code></td>
<td><code>uint16_t[n]</code></td>
<td>Read depth</td>
</tr>
<tr>
<td><code>GL</code></td>
<td><code>float[n*G]</code></td>
<td>Log10 likelihood of data;
<math display="inline" xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mrow><mi>G</mi><mo>=</mo><mfrac><mrow><mi>A</mi><mo stretchy="false" form="prefix">(</mo><mi>A</mi><mo>+</mo><mn>1</mn><mo stretchy="false" form="postfix">)</mo></mrow><mn>2</mn></mfrac></mrow><annotation encoding="application/x-tex">G=\frac{A(A+1)}{2}</annotation></semantics></math>,
<math display="inline" xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mrow><mi>A</mi><mo>=</mo><mi>#</mi><mo stretchy="false" form="prefix">{</mo><mi>a</mi><mi>l</mi><mi>l</mi><mi>e</mi><mi>l</mi><mi>e</mi><mi>s</mi><mo stretchy="false" form="postfix">}</mo></mrow><annotation encoding="application/x-tex">A=\#\{alleles\}</annotation></semantics></math></td>
</tr>
<tr>
<td><code>GT</code></td>
<td><code>uint8_t[n]</code></td>
<td><code>missing 7 | phased 6 | allele1 3 | allele2</code></td>
</tr>
<tr>
<td><code>_GT</code></td>
<td><code>uint8_t+uint8_t[n*P]</code></td>
<td><span>Generic GT; the first int equals the max ploidy
<math display="inline" xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mi>P</mi><annotation encoding="application/x-tex">P</annotation></semantics></math>.
If the highest bit is set, the allele is not present (e.g. due to
different ploidy between samples).</span></td>
</tr>
<tr>
<td><code>GQ</code></td>
<td><code>uint8_t[n]</code></td>
<td><span>Genotype quality</span></td>
</tr>
<tr>
<td><code>HQ</code></td>
<td><code>uint8_t[n*2]</code></td>
<td><span>Haplotype quality</span></td>
</tr>
<tr>
<td><code>_HQ</code></td>
<td><code>uint8_t+uint8_t[n*P]</code></td>
<td><span>Generic HQ</span></td>
</tr>
<tr>
<td><code>IBD</code></td>
<td><code>uint32_t[n*2]</code></td>
<td><span>IBD</span></td>
</tr>
<tr>
<td><code>_IBD</code></td>
<td><code>uint8_t+uint32_t[n*P]</code></td>
<td><span>Generic IBD</span></td>
</tr>
<tr>
<td><code>PL</code></td>
<td><code>uint8_t[n*G]</code></td>
<td><span>Phred-scaled likelihood of data</span></td>
</tr>
<tr>
<td><code>PS</code></td>
<td><code>uint32_t[n]</code></td>
<td><span>Phase set</span></td>
</tr>
<tr>
<td><em>Integer</em></td>
<td><code>int32_t[n*X]</code></td>
<td><span>Fix-sized custom Integer;
<math display="inline" xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mi>X</mi><annotation encoding="application/x-tex">X</annotation></semantics></math>
defined in the header</span></td>
</tr>
<tr>
<td><em>Numeric</em></td>
<td><code>double[n*X]</code></td>
<td><span>Fix-sized custom Numeric</span></td>
</tr>
<tr>
<td><em>String</em></td>
<td><code>uint32_t+char*</code></td>
<td><code>NULL</code> padded concat. strings (int equals to the length)</td>
</tr>
</tbody>
</table>

</div>

- A BCF file is in the `BGZF` format.

- All multi-byte numbers are little-endian.

- In a string, a missing value '.' is an empty C string "` 0`" (not
  "`. 0`")

- For `GL` and `PL`, likelihoods of genotypes appear in the order of
  alleles in `REF` and then `ALT`. For example, if ` REF=C`, `ALT=T,A`,
  likelihoods appear in the order of ` CC,CT,TT,CA,TA,AA` (NB: the
  ordering is different from the one in the original BCF proposal).

- Predefined `FORMAT` fields can be missing from VCF headers, but custom
  `FORMAT` fields are required to be explicitly defined in the headers.

- A `FORMAT` field with its name starting with '`_`' is specific to BCF
  only. It gives an alternative binary representation of the
  corresponding VCF field, in case the default representation is unable
  to keep the genotype information, for example, when the ploidy is not
  2 or there are more than 8 alleles.