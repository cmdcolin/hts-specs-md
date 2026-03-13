---
title: "CRAM codec specification (version 3.1)"
commit: 563e8ab
date: 7 Apr 2025
---

# CRAM codec specification (version 3.1)
{:.no_toc}

This printing is version 563e8ab from the [hts-specs](https://github.com/samtools/hts-specs) repository, last modified on 7 Apr 2025.

* Do not remove this line (it will not be displayed)
{:toc}


This document covers the compression and decompression algorithms
(codecs) specific to the CRAM format. All bar the first of these were
introduced in CRAM v3.1.

It does not cover the CRAM format itself. For that see
<http://samtools.github.io/hts-specs/>.

## Pseudocode introduction

Various parts of this specification are written in a simplistic
pseudocode. This intentionally does not make explicit use of data types
and has minimal error checking. The number of operators is kept to a
minimum, but some are necessary and may be language specific. Due to the
lack of explicit data types, we also have different division operators
to symbolise floating point and integer divisions.

The pseudocode doesn't prescribe any particular programming paradigm -
functional, procedural or object oriented - but it does have a few
implicit assumptions. Variables are considered to be passed between
functions via unspecified means. For example the Range Coder sets
$`range`$ and $`code`$ during creation and these are used during the
decoding steps, but are not explicitly passed in as variables. We make
the implicit assumption that they are simply local variables of the
particular usage of this range coder. Other than ephemeral loop
counters, we do not reuse variable names so the intention should be
clear.

The exception to the above is occasionally we need to have multiple
instances of a particular data type, such as Order-1 decoding will have
many models. Here we use an object oriented way of describing the
problem with $`instance`$.<span class="smallcaps">Function</span>
notation.

Note some functions may return multiple items, such as `return (`*value,
length*`)`, but the calling code may assign a single variable to this
result. In this case the first value *value* will be used and *length*
will be discarded.

## Mathematical operators

| **Operator** | **Description** |
|---:|:---|
| $`a + b`$ | Addition |
| $`a - b`$ | Subtraction |
| $`a \times b`$ | Multiplication |
| $`a\ /\ b`$ | Floating point division $`a/b`$ |
| $`a %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
b`$ | Integer division $`a/b`$, equivalent to $`\lfloor{a/b}\rfloor`$ |
| $`a \bmod b`$ | Integer modulo (remainder) $`a - b\times(a %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
b)`$ |
| $`a = b`$ | Compares $`a`$ and $`b`$ variables, yielding true if they match, false otherwise |
| $`a \gets b`$ | Assigns value of $`b`$ to variable $`a`$ |
| $`a \mathbin{<\mkern-3mu<\,}b`$ | Bit-wise left shift $`a`$ by $`b`$ bits, shifting in zeros |
| $`a \mathbin{>\mkern-3mu>\,}b`$ | Bit-wise right shift $`a`$ by $`b`$ bits, shifting in zeros |
| $`a %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
b`$ | Bit-wise AND operator, joining values $`a`$, $`b`$ |
| $`a %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font OR}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
b`$ | Bit-wise OR operator, joining values $`a`$, $`b`$ |
| $`a % keyword rather than mathematical operator
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font \textbf{or}}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
b`$ | Logical OR operator, joining expressions $`a`$, $`b`$ |
| $`a % keyword rather than mathematical operator
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font \textbf{and}}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
b`$ | Logical AND operator, joining expressions $`a`$, $`b`$ |
| $`a \mathbin{+\mkern-10mu+\,}b`$ | String concatenation of $`a`$ and $`b`$: $`ab`$ |
| $`V_i`$ | Element $`i`$ of vector $`V`$ |
|  | The entire vector $`V`$ may be passed into a function |
| $`W_{i,j}`$ | Element $`i,j`$ of two-dimensional vector $`W`$. |
|  | The entire vector $`W`$ or a one dimensional slice $`W_i`$ (of size $`j`$) may be passed into a function. |

Note that string concatenation with the $`\mathbin{+\mkern-10mu+\,}`$
operator assumes the left and right values are converted to string form.
For example "level" $`\mathbin{+\mkern-10mu+\,}42`$ will convert the
integer 42 to "42" and produce the string "level42".

## Implicit functions

| **Operator** | **Description** |
|---:|:---|
| <span class="smallcaps">Min</span>$`(a,\ b)`$ | Smaller of $`a`$ and $`b`$ |
| <span class="smallcaps">Max</span>$`(a,\ b)`$ | Larger of $`a`$ and $`b`$ |
| <span class="smallcaps">ReadUint8</span> | Read an 8-bit unsigned integer (1 byte) from unspecified input source |
| <span class="smallcaps">ReadUint32</span> | Read a 32-bit unsigned little-endian integer from unspecified input source |
| <span class="smallcaps">ReadUint8</span>$`(src)`$ | Read an 8-bit unsigned integer (1 byte) from input $`src`$ |
| <span class="smallcaps">ReadUint32</span>$`(src)`$ | Read a 32-bit unsigned little-endian integer from input $`src`$ |
| <span class="smallcaps">ReadData</span>$`(len)`$ | Read $`len`$ bytes (8-bit unsigned) from an unspecified input source |
| <span class="smallcaps">ReadData</span>$`(len, src)`$ | Read $`len`$ bytes (8-bit unsigned) from input $`src`$ |
| <span class="smallcaps">ReadChar</span>$`(src)`$ | Read a single character from input $`src`$ |
| <span class="smallcaps">ReadString</span>$`(src)`$ | Read a nul-terminated string from input $`src`$ |
| <span class="smallcaps">EOF</span> | Returns true if the input source is exhausted. |
| <span class="smallcaps">Char</span>$`(a)`$ | Converts integer $`a`$ to a single character of appropriate ASCII value |
| <span class="smallcaps">Length</span>$`(a)`$ | Returns length of string $`a`$ excluding any nul-termination bytes |
| <span class="smallcaps">Swap</span>$`(a,\ b)`$ | Swaps the contents of $`a`$ and $`b`$ variables |

Many of the input functions here and below are defined to read either
from an unspecified input source (such as the input file descriptor, or
a global buffer that has not been explicitly stated in the pseudocode),
but also have forms that may decode from specified inputs / buffers.
They both consume their input sources in the same manner, using an
implicit offset of how many bytes so far have been read.

## Other basic functions

7-bit integer encoding stores values 7-bits at a time with the top bit
set if further bytes are required.

<div class="algorithmic">

(Read a variable sized unsigned integer 7-bits at a time. Returns the
value.) $`value \gets 0`$ $`length \gets 0`$ $`c \gets`$
$`value \gets (value \mathbin{<\mkern-3mu<\,}7) + (c %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
127)`$ $`length \gets length + 1`$ $`value`$

</div>

ITF8 integer encoding stores the additional number of bytes needed in
the count of the top bits set in the initial byte (ending with a zero
bit), followed by any subsequent whole bytes. See the main CRAM
specification for more details.

<div class="algorithmic">

(Read a variable sized unsigned integer with ITF8 encoding. Returns the
value.) $`v \gets`$ $`v \gets (v\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
\mathtt{0x0f}) \mathbin{<\mkern-3mu<\,}28`$ $`v \gets v + (`$
$`\mathbin{<\mkern-3mu<\,}20)`$ $`v \gets v + (`$
$`\mathbin{<\mkern-3mu<\,}12)`$ $`v \gets v + (`$
$`\mathbin{<\mkern-3mu<\,}4)`$ $`v \gets v + (`$
$`\mathbin{>\mkern-3mu>\,}4)`$ $`v \gets (v\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
\mathtt{0x0f}) \mathbin{<\mkern-3mu<\,}24`$ $`v \gets v + (`$
$`\mathbin{<\mkern-3mu<\,}16)`$ $`v \gets v + (`$
$`\mathbin{<\mkern-3mu<\,}8)`$ $`v \gets v +`$ $`v \gets (v\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
\mathtt{0x1f}) \mathbin{<\mkern-3mu<\,}16`$ $`v \gets v + (`$
$`\mathbin{<\mkern-3mu<\,}8)`$ $`v \gets v +`$ $`v \gets (v\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
\mathtt{0x3f}) \mathbin{<\mkern-3mu<\,}8`$ $`v \gets v +`$ $`v`$

</div>

# rANS 4x8 - Asymmetric Numeral Systems

This is the rANS format first defined in CRAM v3.0.

rANS is the range-coder variant of the Asymmetric Numerical Systems[^1].

The structure of the external rANS codec consists of several components:
meta-data consisting of compression-order, and compressed and
uncompressed sizes; normalised frequencies of the alphabet systems to be
encoded, either in Order-0 or Order-1 context; and the rANS encoded byte
stream itself.

Here "Order" refers to the number of bytes of context used in computing
the frequencies. It will be 0 or 1. Ignoring punctuation and space, an
Order-0 analysis of English text may observe that 'e' is the most common
letter (12-13%), and that 'u' occurs only around 2.5% of the time. If
instead we consider the frequency of a letter in the context of one
previous letter (Order-1) then these statistics change considerably; we
know that if the previous letter was 'q' then 'e' becomes a rare letter
while 'u' is the most likely.

These observed frequencies are inversely related to the amount of
storage required to encode a symbol (e.g. an alphabet letter)[^2].

### **rANS 4x8 compressed data structure**

A compressed data block consists of the following logical parts:

| **Value data type** | **Name** | **Description** |  |
|:---|:---|:---|:---|
| byte | order | the order of the codec, either 0 or 1 |  |
| uint32 | compressed size | the size in bytes of frequency table and compressed blob |  |
| uint32 | data size | raw or uncompressed data size in bytes |  |
| byte\[\] | frequency table | byte frequencies of input data written using RLE |  |
| byte\[\] | compressed blob | compressed data |  |

## **Frequency table**

The alphabet used here has a maximum of 256 possible symbols (all byte
values), but alphabets where fewer symbols are permitted too.

The symbol frequency table indicates which symbols are present and what
their relative frequencies are. The total sum of symbol frequencies are
normalised to add up to 4095[^3]. Given rounding differences when
renormalising to a fixed sum, it is up to the encoder to decide how to
distribute any remainder or remove excess frequencies. The normalised
frequency tables below are examples and not prescriptive of a specific
normalisation strategy.

Formally, this is an ordered alphabet $`\mathbb{A}`$ containing symbols
$`s`$ where $`s_{i}`$ with the $`i`$-th symbol in $`\mathbb{A}`$,
occurring with the frequency $`freq_{i}`$.

### Order-0 encoding

The normalised symbol frequencies are then written out as {symbol,
frequency} pairs in ascending order of symbol (0 to 255 inclusive). If a
symbol has a frequency of 0 then it is omitted.

To avoid storing long consecutive runs of symbols if all are present (eg
a-z in a long piece of English text) we use run-length-encoding on the
alphabet symbols. If two consecutive symbols have non-zero frequencies
then a counter of how many other non-zero frequency consecutive symbols
is output directly after the second consecutive symbol, with that many
symbols being subsequently omitted.

For example for non-zero frequency symbols 'a', 'b', 'c', 'd' and 'e' we
would write out symbol 'a', 'b' and the value 3 (to indicate 'c', 'd'
and 'e' are also present).

The frequency is output after every symbol (whether explicit or
implicit) using ITF8 encoding. This means that frequencies 0-127 are
encoded in 1 byte while frequencies 128-4095 are encoded in 2 bytes.

Finally the symbol 0 is written out to indicate the end of the
symbol-frequency table.

As an example, take the string `abracadabra`.

<div class="minipage">

Symbol frequency:\

| Symbol | Frequency |
|-------:|----------:|
|      a |         5 |
|      b |         2 |
|      c |         1 |
|      d |         1 |
|      r |         2 |

</div>

<div class="minipage">

Normalised to sum to 4095:\

| Symbol | Frequency |
|-------:|----------:|
|      a |      1863 |
|      b |       744 |
|      c |       372 |
|      d |       372 |
|      r |       744 |

</div>

Encoded as:

    0x61      0x87 0x47      # `a'           <1863>
    0x62 0x02 0x82 0xe8      # `b' <+2: c,d>  <744>
              0x81 0x74      # `c' (implicit) <372>
              0x81 0x74      # `d' (implicit) <372>
    0x72      0x82 0xe8      # `r'            <744>
    0x00                     # <0>

### Order-1 encoding

To encode Order-1 statistics typically requires a larger table as for an
$`N`$ sized alphabet we need to potentially store an $`N`$x$`N`$ matrix.
We store these as a series of Order-0 tables.

We start with the outer context byte, emitting the symbol if it is
non-zero frequency. We perform the same run-length-encoding as we use
for the Order-0 table and end the contexts with a nul byte. After each
context byte we emit the Order-0 table relating to that context.

One last caveat is that we have no context for the first byte in the
data stream (in fact for 4 equally spaced starting points, see
"interleaving" below). We use the ASCII value ('\0') as the starting
context for each interleaved rANS state and so need to consider this in
our frequency table.

Consider `abracadabraabracadabraabracadabraabracadabrad` as example
input. Note for the additional trailing "d" giving us 45 characters
instead of 44. This can be broken into 4 approximate equal portions
`abracadabra abracadabra abracadabra abracadabrad`. We operate one
independent rANS stream per portion, providing us the opportunity to
exploit CPU data parallelism.

<div class="minipage">

Naively observed Order-1 frequencies:\

| Context | Symbol | Frequency |
|--------:|-------:|----------:|
|      \0 |      a |         4 |
|       a |      a |         3 |
|         |      b |         8 |
|         |      c |         4 |
|         |      d |         5 |
|       b |      r |         8 |
|       c |      a |         4 |
|       d |      a |         4 |
|       r |      a |         8 |

</div>

<div class="minipage">

Normalised (per Order-0 statistics):\

| Context | Symbol | Frequency |
|--------:|-------:|----------:|
|      \0 |      a |      4095 |
|       a |      a |       614 |
|         |      b |      1639 |
|         |      c |       819 |
|         |      d |      1023 |
|       b |      r |      4095 |
|       c |      a |      4095 |
|       d |      a |      4095 |
|       r |      a |      4095 |

</div>

Note that the above table has redundant entries. While our complete
string had three cases of two consecutive "a" characters
("...cadabr**aa**braca..."), these spanned the junction of our split
streams and each rANS state is operating independently, starting with
the same last character of nul (0). Hence during decode we will not need
to access the table for the frequency of "a" in the context of a
previous "a". A similar issue occurs for the very last byte used for
each rANS state, which will not be used as a context. In extreme cases
this may even be the only time that symbols occurs anywhere. While these
scenarios represent unnecessary data to store, and these frequency
entries can be safely omitted, their presence does not invalidate the
data format and it may be simpler to use a more naive algorithm when
producing the frequency tables.

The above tables are encoded as:

    0x00                 # `\0' context
    0x61      0x8f 0xff  # a  <4095>
    0x00                 # end of Order-0 table

    0x61                 # `a' context
    0x61      0x82 0x66  # a             <614>
    0x62 0x02 0x86 0x67  # b <+2: c,d>  <1639>
              0x83 0x33  # c (implicit)  <819>
              0x83 0xff  # d (implicit) <1023>
    0x00                 # end of Order-0 table

    0x62 0x02            # `b' context, <+2: c, d>
    0x72      0x8f 0xff  # r <4095>
    0x00                 # end of Order-0 table

                         # `c' context (implicit)
    0x61      0x8f 0xff  # a <4095>
    0x00                 # end of Order-0 table

                         # `d' context (implicit)
    0x61      0x8f 0xff  # a <4095>
    0x00                 # end of Order-0 table

    0x72                 # `r' context
    0x61      0x8f 0xff  # a <4095>
    0x00                 # end of Order-0 table

    0x00                 # end of contexts

## rANS entropy encoding

The encoder takes a symbol $`s`$ and a current state $`x`$ (initially
$`L`$ below) to produce a new state $`x'`$ with function $`C`$.

$`x' = C(s,x)`$

The decoding function $`D`$ is the inverse of $`C`$ such that
$`C(D(x)) = x`$.

$`D(x') = (s,x)`$

The entire encoded message can be viewed as a series of nested $`C`$
operations, with decoding yielding the symbols in reverse order, much
like popping items off a stack. This is where the asymmetric part of ANS
comes from.

As we encode into $`x`$ the value will grow, so for efficiency we ensure
that it always fits within known bounds. This is governed by

$`L \leq x < bL-1`$

where $`b`$ is the base and $`L`$ is the lower-bound.

We ensure this property is true before every use of $`C`$ and after
every use of $`D`$. Finally to end the stream we flush any remaining
data out by storing the end state of $`x`$.

**Implementation specifics**

We use an unsigned 32-bit integer to hold $`x`$. In encoding it is
initialised to $`L`$. For decoding it is read little-endian from the
input stream.

Recall $`freq_{i}`$ is the frequency of the $`i`$-th symbol $`s_{i}`$ in
alphabet $`\mathbb{A}`$. We define $`cfreq_i`$ to be cumulative
frequency of all symbols up to but not including $`s_{i}`$:

$`cfreq_{i} = \left\{
\begin{array}{l l}
0 & \quad \textrm{if $i < 1$} \\
cfreq_{i-1} + freq_{i-1} & \quad \textrm{if $i \geq 1$}
\end{array}
\right.`$

We have a reverse lookup table $`cfreq\_to\_sym_c`$ from 0 to 4095
(0xfff) that maps a cumulative frequency $`c`$ to a symbol $`s`$.

$`cfreq\_to\_sym_c = s_{i} \quad where \quad c: \enskip cfreq_i \leq c <
cfreq_i + freq_i`$

The $`x' = C(s,x)`$ function used for the $`i`$-th symbol $`s`$ is:

$`x' = (x/freq_i) \times \mathtt{0x1000} + cfreq_i + (x \bmod freq_i)`$

The $`D(x') = (s,x)`$ function used to produce the $`i`$-th symbol $`s`$
and a new state $`x`$ is:

$`c = x' %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
\mathtt{0xfff}`$\
\* $`s_{i} = cfreq\_to\_sym_{c}`$\
\* $`x = freq_{i} (x' / \mathtt{0x1000}) + c - cfreq_{i}`$

Most of these operations can be implemented as bit-shifts and bit-AND,
with the encoder modulus being implemented as a multiplication by the
reciprocal, computed once only per alphabet symbol.

We use $`L = \mathtt{0x800000}`$ and $`b = 256`$, permitting us to flush
out one byte at a time (encoded and decoded in reverse order).

Before every encode $`C(s,x)`$ we renormalise $`x`$, shifting out the
bottom 8 bits of $`x`$ until $`x < \mathtt{0x80000} \times freq_i`$.
After finishing all encoding we flush 4 more bytes (lowest 8-bits first)
from $`x`$.

After every decoded $`D(x')`$ we renormalise $`x'`$, shifting in the
bottom 8 bits until $`x \geq \mathtt{0x800000}`$.

### Interleaving

For efficiency, we interleave 4 separate rANS codecs at the same
time[^4]. For the Order-0 codecs these simply encode or decode the 4
neighbouring bytes in cyclic fashion using interleaved codec 0, 1, 2,
and 3, sharing the same output buffer (so the output bytes get
interleaved).

For the Order-1 codec we cannot do this as we need to know the previous
byte value as the context for the next byte. We therefore split the
input data into 4 approximately equal sized fragments[^5] starting at
$`0`$, $`\lfloor{}len/4\rfloor{}`$, $`\lfloor{}len/4\rfloor{}\times2`$
and $`\lfloor{}len/4\rfloor{}\times 3`$. Each Order-1 codec operates in
a cyclic fashion as with Order-0, all starting with 0 as their state and
sharing the same compressed output buffer. Any remainder, when the input
buffer is not divisible by 4, is processed at the end by the 4th rANS
state.

We do not permit Order-1 encoding of data streams smaller than 4 bytes.

## rANS decode pseudocode

A naïve implementation of a rANS decoder follows. This pseudocode is for
clarity only and is not expected to be performant and we would normally
rewrite this to use lookup tables for maximum efficiency. The function
<span class="smallcaps">ReadUint8</span> fetches the next single
unsigned byte from an unspecified input source. Similarly for
<span class="smallcaps">ReadITF8</span> (variable size integer) and
<span class="smallcaps">ReadUint32</span> (32-bit unsigned integer in
little endian format).

<div class="algorithmic">

$`{}\gets`$ $`{}\gets`$ $`{}\gets`$

</div>

### rANS order-0

The Order-0 code is the simplest variant. Here we also define some of
the functions for manipulating the rANS state, which are shared between
Order-0 and Order-1 decoders.

<div class="algorithmic">

(Reads a table of Order-0 symbol frequencies $`F_i`$) (and sets the
cumulative frequency table $`C_{i+1} = C_i+F_i`$) $`s \gets`$
$`last\_sym \gets s`$ $`rle \gets 0`$ $`{}\gets`$ $`{}\gets`$ $`rle-1`$
$`{}\gets`$ $`s+1`$ $`s \gets`$ $`rle \gets`$ $`last\_sym \gets s`$
 (Compute cumulative frequencies $`C_i`$ from $`F_i`$) $`C_0 \gets 0`$
$`C_{s+1} \gets C_s + F_s`$

(Bottom 12 bits of our rANS state $`R`$ are our frequency) $`R\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip`$ 0xfff (Convert frequency to a symbol.
Find $`s`$ such that $`C_s \le f < C_{s+1}`$) (We would normally
implement this via a lookup table) $`s \gets 0`$ $`s \gets s+1`$ $`s`$
(Compute the next rANS state $`R`$ given frequency $`f`$ and cumulative
freq $`c`$) $`f \times (R \mathbin{>\mkern-3mu>\,}12) + (R\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip`$ 0xfff$`) - c`$ (If too small, feed in
more bytes to the rANS state $`R`$)
$`R \gets (R \mathbin{<\mkern-3mu<\,}8) +`$  $`R`$ $`R_j \gets`$
$`j \gets i \bmod 4`$ $`f \gets`$ $`s \gets`$ $`output_i \gets s`$
$`R_j \gets`$  $`R_j \gets`$ 

</div>

### rANS order-1

As described above, the decode logic is very similar to rANS Order-0
except we have a two dimensional array of frequencies to read and the
decode uses the last character as the context for decoding the next one.
In the pseudocode we illustrate this by using two dimensional vectors
$`C_{i,j}`$ and $`F_{i,j}`$. For simplicity, we reuse the Order-0 code
by referring to $`C_i`$ and $`F_i`$ of the 2D vectors to get a single
dimensional vector that operates in the same manner as the Order-0 code.
This is not necessarily the most efficient implementation.

Note the code for dealing with the remaining bytes when an output buffer
is not an exact multiple of 4 is less elegant in the Order-1 code. This
is correct, but it is unfortunately a design oversight.

<div class="algorithmic">

(Reads a table of Order-1 symbol frequencies $`F_{i,j}`$) (and sets the
cumulative frequency table $`C_{i,j+1} = C_{i,j}+F_{i,j}`$)
$`sym \gets`$ $`last\_sym \gets sym`$ $`rle \gets 0`$ $`{}\gets`$
$`rle-1`$ $`{}\gets`$ $`sym+1`$ $`sym \gets`$ $`rle \gets`$
$`last\_sym \gets sym`$

$`R_j \gets`$ $`L_j \gets 0`$ $`i \gets 0`$ $`f \gets`$ $`s \gets`$
$`output_{i + j \times \lfloor nbytes/4 \rfloor} \gets s`$
$`R_j \gets`$  $`R_j \gets`$  $`L_j \gets s`$ $`i \gets i+1`$     (Now
deal with the remainder if buffer size is not a multiple of 4,)
    (using rANS state 3 exclusively.) $`f \gets`$ $`s \gets`$
$`output_i \gets s`$ $`R_3 \gets`$  $`R_3 \gets`$  $`L_3 \gets s`$

</div>

# rANS Nx16

CRAM version 3.1 defines an additional rANS entropy encoder, using
16-bit renormalisation instead of the 8-bit used in CRAM 3.0 and with
inbuilt bit-packing and run-length encoding. The lower-bound and initial
encoder state $`L`$ is also changed to 0x8000. The Order-1 rANS Nx16
encoder has also been modified to permit a maximum frequency of 1024
instead of 4096. This offers better cache performance for the large
Order-1 tables and usually has minimal impact on compression ratio.

Additionally it permits adjustment of the number of interleaved rANS
states from the fixed 4 used in rANS 4x8 to either 4 or 32 states. The
benefit of the 32-way interleaving is in enabling efficient use of SIMD
instructions for faster encoding and decoding speeds. However it has a
small cost in size and initialisation times so it is not recommended on
smaller blocks of data.

Frequencies are now stored using uint7 format instead of ITF8. The
tables are also stored differently, separating the list of symbols
present in the alphabet (those with frequency greater than zero) from
the frequencies themselves.

Finally transformations may be applied to the data prior to compression
(or after decompression). These consist of stripe, for structured data
where every Nth byte is sent to one of N separate compression streams,
Run Length Encoding replacing repeated strings of symbols with a symbol
and count, and bit-packing where reduced alphabets can combine multiple
symbols into a byte prior to entropy encoding.

The initial "Order" byte is expanded with additional bits to list the
transformations to be applied. The specifics of each sub-format are
listed below, in the order they are applied.

- **<span class="smallcaps">Stripe</span>**: rANS Nx16 with multi-way
  interleaving (see
  Section <a href="#sec:ransstripe" data-reference-type="ref"
  data-reference="sec:ransstripe">3.6</a>).

- **<span class="smallcaps">NoSize</span>**: Do not store the size of
  the uncompressed data stream. This information is not required when
  the data stream is one of the four sub-streams in the
  <span class="smallcaps">Stripe</span> format.

- **<span class="smallcaps">Cat</span>**: If present, the order bit flag
  is ignored.

  The uncompressed data stream is the same as the compressed stream.
  This is useful for very short data where the overheads of compressing
  are too high.

- **<span class="smallcaps">N32</span>**: Flag indicating whether to
  interleave 4 or 32 rANS states.

- **<span class="smallcaps">Order</span>**: Bit field defining order-0
  (unset) or order-1 (set) entropy encoding, as described above by the
  <span class="smallcaps">RansDecodeNx16_0</span> and
  <span class="smallcaps">RansDecodeNx16_1</span> functions.

- **<span class="smallcaps">RLE</span>**: Bit field defining whether Run
  Length Encoding has been applied to the data. If set, the reverse
  transorm will be applied using
  <span class="smallcaps">DecodeRLE</span> after Order-0 or Order-1
  uncompression (see
  Section <a href="#sec:ransRLE" data-reference-type="ref"
  data-reference="sec:ransRLE">3.4</a>).

- **<span class="smallcaps">Pack</span>**: Bit field indicating the data
  was packed prior to compression (see
  Section <a href="#sec:ranspack" data-reference-type="ref"
  data-reference="sec:ranspack">3.5</a>). If set, unpack the bits after
  any RLE decoding has been applied (if required) using the
  <span class="smallcaps">DecodePack</span> function.

## Frequency tables

Frequency tables in rANS Nx16 separate the list of symbols from their
frequencies. The symbol list must be stored in ascending ASCII order,
with their frequency values in the same ordering as their corresponding
symbols. For the Order-1 frequency table this list of symbols is those
used in any context, thus we only have one alphabet recorded for all
contexts. This means in some contexts some (potentially many) symbols
will have zero frequency. To reduce the Order-1 table size an additional
zero run-length encoding step is used. Finally the Order-1 frequencies
may optionally be compressed using the Order-0 rANS Nx16 codec.

Frequencies must always add up to a power of 2, but do not necessarily
have to match the final power of two used in the Order-0 (4096) and
Order-1 (1024, 4096) entropy decoder algorithm. A normalisation step is
applied after reading the frequencies to scale them appropriately. This
is required as the Order-1 frequencies may be scaled differently for
each context.

<div class="algorithmic">

(Reads a set of symbols $`A`$ used in our alphabet) $`s \gets`$
$`last\_sym \gets s`$ $`rle \gets 0`$ $`A \gets (A,s)`$ $`{}\gets`$
$`rle-1`$ $`{}\gets`$ $`s+1`$ $`s \gets`$ $`rle \gets`$
$`last\_sym \gets s`$ $`A`$

</div>

<div class="algorithmic">

(Reads a table of Order-0 symbol frequencies $`F_i`$) (and sets the
cumulative frequency table $`C_{i+1} = C_i+F_i`$) $`F \gets (0,\ ...)`$
(Set to zero for all $`i \in \{0, 1,
  ..., 255\}`$) $`A \gets`$ $`F_i \gets`$ $`C_0 \gets 0`$
$`C_{s+1} \gets C_s + F_s`$

</div>

<div class="algorithmic">

(Normalises a table of frequencies $`F_i`$ to sum to a specified power
of 2.) $`tot \gets 0`$ $`tot \gets tot + F_i`$ $`shift \gets 0`$
$`tot \gets tot*2`$ $`shift \gets shift+1`$
$`F_i \gets F_i \mathbin{<\mkern-3mu<\,}shift`$

</div>

The Order-1 frequencies also store the complete alphabet of observed
symbols (ignoring context) followed by a table of frequencies for each
symbol in the alphabet. Given many frequencies will be zero where a
symbol is present in one context but not in others, all zero frequencies
are followed by a run length to omit adjacent zeros.

The order-1 frequency table itself may still be quite large, so is
optionally compressed using the order-0 rANS Nx16 codec with a fixed
4-way interleaving. This is specified in the bottom bit of the first
byte. If this is 1, it is followed by 7-bit encoded uncompressed and
compressed lengths and then the compressed frequency data. The
pseudocode here differs slightly to elsewhere as it indicates the input
sources, which are either the uncompressed frequency buffer or the
default (unspecified) source. The top 4 bits of the first byte indicate
the number of bits used for the frequency tables. Permitted values are
10 and 12.

<div class="algorithmic">

(Reads a table of Order-1 symbol frequencies $`F_{i,j}`$) (and sets the
cumulative frequency table $`C_{i,j+1} = C_{i,j}+F_{i,j}`$)
$`comp \gets`$ $`bits \gets comp \mathbin{>\mkern-3mu>\,}4`$
$`u\_size \gets`$ $`c\_size \gets`$ $`c\_data \gets`$ $`source \gets`$
(define $`source`$ to be the default input stream)
$`F \gets ((0,\ ...),\ ...)`$ (Set to zero for all $`i`$ and
$`j  \in \{0, 1, ..., 255\}`$) $`A \gets`$ $`run \gets 0`$
$`run \gets run-1`$ $`F_{i,j} \gets`$ $`run \gets`$ $`C_{i,0} \gets 0`$
$`C_{i,j+1} \gets C_{i,j} + F_{i,j}`$

</div>

## rANS Nx16 Order-0

To decode an Order-0 encoded byte stream we first decode the symbol
frequencies as described above and then decode the N interleaved rANS
states. This is similar to the old (4x8) rANS decoder, but the
<span class="smallcaps">RansRenorm</span> function is replaced by a
single 16-bit renormalisation instead of a loop using 8-bit values and
can interleave to different amounts.

<div class="algorithmic">

$`R\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
((1 \mathbin{<\mkern-3mu<\,}bits) -1)`$
$`f \times (R \mathbin{>\mkern-3mu>\,}bits) + (R\ %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
((1 \mathbin{<\mkern-3mu<\,}bits) -1) - c`$
$`R \gets (R \mathbin{<\mkern-3mu<\,}16) +`$  $`R`$ $`R_j \gets`$
$`j \gets i \bmod N`$ $`f \gets`$ $`s \gets`$ $`out_i \gets s`$
$`R_j \gets`$  $`R_j \gets`$  $`out`$

</div>

## rANS Nx16 Order-1

The Order-1 code is comparable to Order-0 but with an extra dimension
(the previous value) to the $`F`$ and $`C`$ matrices and a more complex
system for storing the frequencies. The frequencies may also add up to
either 1024 or 4096 (10 or 12 bits).

The N rANS states don't operate on interleaved data either, but in
distinct regions so they can utilise their previous symbols without
inter-dependency between the decoded output of the rANS states. This
makes the handling of data that isn't a multiple of N is a little more
complex too.

<div class="algorithmic">

$`R_j \gets`$ $`L_j \gets 0`$ (The primary unrollable loop) $`f \gets`$
$`s \gets`$ $`out_{i + j \times \lfloor len/N \rfloor} \gets s`$
$`R_j \gets`$  $`R_j \gets`$  $`L_j \gets s`$ (The remainder for data
not a multiple of N in size, using $`R_{N-1}`$ throughout.) $`f \gets`$
$`s \gets`$ $`out_i \gets s`$ $`R_{N-1} \gets`$  $`R_{N-1} \gets`$ 
$`L_{N-1} \gets s`$ $`out`$

</div>

## rANS Nx16 Run Length Encoding

For symbols that occur many times in succession, we can replace them
with a single symbol and a count. In this specification, run lengths are
always provided for certain symbols (even if the run length is 1) and
never for the other symbols (even if many are consecutive).

The data stream is split into two parts: the meta-data holding
run-lengths and the run-removed data itself.

| **Bytes** | **Type** | **Name** | **Description** |
|:---|:---|:---|:---|
| ? | uint7 | $`rle\_meta\_len`$ | RLE meta-data-size times 2. The bottom bit is a flag to indicate whether $`rle\_meta`$ is uncompressed (1) or compressed (0). |
| ? | uint7 | $`rle\_len`$ | Size of uncompressed data before <span class="smallcaps">DecodeRLE</span> is applied |
| ? | uint7 | $`(comp\_meta\_len)`$ | Only stored if bottom bit of $`rle\_meta\_len`$ is unset. Size of compressed RLE meta data. |
| ? | uint8\[\] | $`rle\_meta`$ | RLE meta-data. Decompress with <span class="smallcaps">RansDecodeNx16_0</span> if bottom bit of $`rle\_meta\_len`$ is unset. |

The meta-data format starts with the count of symbols which have runs
associated with them (zero being interpreted as all of them) and the
list of these symbol values. This is followed by the run lengths encoded
as variable sized integers in the *uint7* format.

<div class="algorithmic">

(Reads and optionally uncompresses the blob of run-lengths and the array
$`L`$) (indicating which symbols have associates run-lengths.)
$`L \gets (0,\ ...)`$ (Set to zero for all $`i \in \{0, 1,
  ..., 255\}`$) $`rle\_meta\_len \gets`$ $`len \gets`$
$`rle\_meta \gets`$ $`comp\_meta\_len \gets`$ $`rle\_meta \gets`$
$`rle\_meta \gets`$

$`n \gets`$ $`n \gets 256`$ $`s \gets`$ $`L_s \gets 1`$ ($`L`$,
$`rle\_meta`$, $`len`$)

</div>

The use of the run length meta-data occurs when expanding the
uncompressed data, after Order-0 or Order-1 data decompression.

<div class="algorithmic">

(Expands data ($`in`$) using run-length metadata) $`j \gets 0`$
$`sym \gets`$ $`run \gets`$ $`out_{j+k} \gets s`$
$`j \gets j + run + 1`$ $`out_j \gets s`$ $`j \gets j + 1`$ $`out`$

</div>

## rANS Nx16 Bit Packing

If the alphabet of used symbols in the uncompressed data stream is
small - no more than 16 - then we can pack multiple symbols together to
form bytes prior to compression. This permits 2, 4, 8 and infinite (all
symbols are the same) numbers per byte. The distinct symbol values do
not need to be adjacent as a mapping table $`P`$ converts mapped value
$`x`$ to original symbol $`P_x`$.

The packed format is split into uncompressed meta-data (below) and the
compressed packed data.

| **Bytes** | **Type** | **Name** | **Description**            |
|:----------|:---------|:---------|:---------------------------|
| 1         | byte     | $`nsym`$ | Number of distinct symbols |
| $`nsym`$  | byte\[\] | $`P`$    | Symbol map                 |
| ?         | uint7    | $`len`$  | Length of packed data      |

The first meta-data byte holds $`nsym`$, the number of distinct values,
followed by $`nsym`$ bytes to construct the $`P`$ map. If $`nsym = 1`$
then the byte stream is a stream of constant values and no bit-packing
is done (we know every value already). If $`nsym = 2`$ then each symbol
is 1 bit (8 per byte), if $`2 < nsym \le 4`$ symbols are 2 bits each (4
per byte) and if $`4 < nsym \le 16`$ symbols are 4 bits each (2 per
byte). It is not permitted to have $`nsym > 16`$ or $`nsym = 0`$ as bit
packing is not possible. Bits are unpacked from low to high.

Decoding this meta-data is implemented by the
<span class="smallcaps">DecodePackMeta</span> function below.

<div class="algorithmic">

$`nsym \gets`$ $`P_i \gets`$ $`len \gets`$ $`(P,\ nsym, \ len)`$

</div>

After uncompressing the main data stream, it should be unpacked using
<span class="smallcaps">DecodePack</span> below. The format of this data
stream is packed data as described above.

<div class="algorithmic">

$`j \gets 0`$ $`out_i \gets P_0`$ $`v \gets data_j`$ $`j \gets j+1`$
$`out_i \gets P_{(v %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
1)}`$ $`v = v \mathbin{>\mkern-3mu>\,}1`$ $`v \gets data_j`$
$`j \gets j+1`$ $`out_i \gets P_{(v %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
3)}`$ $`v = v \mathbin{>\mkern-3mu>\,}2`$ $`v \gets data_j`$
$`j \gets j+1`$ $`out_i \gets P_{(v %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
15)}`$ $`v = v \mathbin{>\mkern-3mu>\,}4`$ out

</div>

## Striped rANS Nx16

If we have a series of 32-bit values, we can often get better
compression by treating it as a series of 4 8-bit values representing
the first to last bytes in each 32-bit word, than we can by simply
processing it as a stream of 8-bit values. Each $`4{th}`$ byte is sent
to its own stream producing 4 interleaved streams, so the $`1^{st}`$
stream will hold data from byte 0, 4, 8, etc while the $`2^{nd}`$ stream
will hold data from byte 1, 5, 9, etc. Each of those four streams is
then itself compressed using this compression format.

For example an input block of small unsigned 32-bit little-endian
numbers may use RLE for the first three streams as they are mostly zero,
and a non-RLE Order-0 entropy encoder for the last stream.

In the general case we describe this as $`N`$-way interleaved streams.
We can consider this interleaving process to be equivalent to a table
transpose of $`M`$ rows by $`N`$ columns to $`N`$ rows by $`M`$ columns,
followed by compressing each $`N`$ row independently.

The byte stream consists of a 7-bit encoded uncompressed combined
length, a byte holding the value of $`N`$, followed by $`N`$ compressed
lengths also 7-bit encoded. Finally the data sub-streams themselves,
each a valid $`cdata`$ stream, follow.

Normally our $`cdata`$ format will include the decoded size, but with
<span class="smallcaps">Stripe</span> we can omit this from the internal
compressed sub-streams (using the <span class="smallcaps">NoSize</span>
flag) as given the total length we know how to compute the sub-lengths.

Reproducing the original uncompressed data involves decoding the $`N`$
sub-streams and interleaving them together again (reversing the table
transpose). The uncompressed data length may not necessary be an exact
multiple of $`N`$, in which case the latter uncompressed sub-streams may
be 1 byte shorter.

As an example starting with input data $`D`$ we define the transposed
data $`T`$ as:

$`D = aA\underline{A}bB\underline{B}cC\underline{C}dD\underline{D}e`$

$`T = [\ abcde,\ ABCD,\ \underline{A}\underline{B}\underline{C}\underline{D}\ ]`$

Note our example data is not a multiple of $`N`$ long, missing
$`E\underline{E}`$, which gives $`T`$ fragments of length \[5, 4, 4\].

If $`D_i`$ is the $`i^{th}`$ character in $`D`$ and $`T_{j,i}`$ is the
$`i^{th}`$ character of the $`j^{th}`$ substring in $`T`$,
transformations between $`D`$ and $`T`$ are defined as:

$`T_{j,i} = D_{i N +j}`$

$`D_i = T_{(i \bmod N),\ (i %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
N)}`$

<div class="algorithmic">

$`N \gets`$ $`clen_j \gets`$ $`ulen_j \gets (len %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
N) + ((len \bmod N) > j)`$ $`T_j \gets`$
$`out_{i \times N + j} \gets T_{j,i}`$ $`out`$

</div>

## Combined rANS Nx16 Format

We combine the Order-0 and Order-1 rANS Nx16 encoder with optional
run-length encoding, bit-packing and four-way interleaving into a single
data stream.

<table>
<thead>
<tr>
<th colspan="2" style="text-align: right;"><strong>Bits</strong></th>
<th style="text-align: right;"><strong>Type</strong></th>
<th style="text-align: right;"><strong>Name</strong></th>
<th colspan="2"
style="text-align: left;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td colspan="2" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">flag</span></td>
<td colspan="2" style="text-align: left;">Data format bit field</td>
</tr>
<tr>
<td style="text-align: right;"><span>1-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>Unless <span
class="smallcaps">NoSize</span> flag is set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint7</td>
<td style="text-align: right;">ulen</td>
<td style="text-align: left;">Uncompressed length</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If <span
class="smallcaps">Stripe</span> flag is set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;">N</td>
<td style="text-align: left;">Number of sub-streams</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint7[]</td>
<td style="text-align: right;">clen[]</td>
<td style="text-align: left;">N copies of compressed sub-block
length</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">cdata[]</td>
<td style="text-align: left;">N copies of Compressed data sub-block
(recurse)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If <span
class="smallcaps">Cat</span> flag is set (and <span
class="smallcaps">Stripe</span> flag is unset):</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">udata</td>
<td style="text-align: left;">Uncompressed data stream</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If <span
class="smallcaps">Pack</span> flag is set (and neither <span
class="smallcaps">Stripe</span> or <span class="smallcaps">Cat</span>
flags are set):</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">pack_meta</td>
<td style="text-align: left;">Pack lookup table</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If <span
class="smallcaps">RLE</span> flag is set (and neither <span
class="smallcaps">Stripe</span> or <span class="smallcaps">Cat</span>
flags are set):</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">rle_meta</td>
<td style="text-align: left;">RLE meta-data</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If neither <span
class="smallcaps">Stripe</span> or <span class="smallcaps">Cat</span>
flags are set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">cdata</td>
<td style="text-align: left;">Entropy encoded data stream (see <span
class="smallcaps">Order</span> flag)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

The first byte of our generalised data stream is a bit-flag detailing
the type of transformations and entropy encoders to be combined,
followed by optional meta-data, followed by the actual compressed data
stream. The bit-flags are defined below, but note not all combinations
are permitted.

<div class="threeparttable">

| **Bit AND value** | **Code** | **Description** |  |
|:---|:---|:---|:---|
| 1 | <span class="smallcaps">Order</span> | Order-0 or Order-1 entropy coding |  |
| 2 | reserved | Reserved (for possible order-2/3) |  |
| 4 | <span class="smallcaps">N32</span> | Interleave $`N=32`$ rANS states (else $`N=4`$) |  |
| 8 | <span class="smallcaps">Stripe</span> | multi-way interleaving of byte streams |  |
| 16 | <span class="smallcaps">NoSize</span> | original size is not recorded (for use by <span class="smallcaps">Stripe</span>) |  |
| 32 | <span class="smallcaps">Cat</span> | Data is uncompressed |  |
| 64 | <span class="smallcaps">RLE</span> | Run length encoding, with runs and literals encoded separately |  |
| 128 | <span class="smallcaps">Pack</span> | Pack 2, 4, 8 or infinite symbols per byte |  |

<div class="tablenotes">

($`*`$) Not to be used in conjunction with other bit-field values except
<span class="smallcaps">NoSize</span>.

</div>

</div>

Bit-packing and run length encoding transforms have their own meta-data,
which is decoded prior to the main compressed data stream. After
decoding, these transforms are applied in order of RLE followed by
unpack as required and in that order.

For example a $`flag`$ data-format value of 197 indicates a byte stream
should decode the pack meta-data, the RLE meta-data and the Order-1
compressed data itself, all using 32 rANS states, and then apply the RLE
followed by Unpack transforms to yield the original uncompressed data.

<span class="smallcaps">RansDecodeNx16</span> describes the decoding of
the generalised RANS Nx16 decoder.

<div class="algorithmic">

$`flags \gets`$ $`len \gets`$ $`data \gets`$ $`data`$ $`N \gets 32`$
$`N \gets 4`$ $`pack\_len \gets len`$ $`(P,\ nsym,\ len) \gets`$
$`rle\_len \gets len`$ $`(L,\ rle\_meta,\ len) \gets`$ $`data \gets`$
$`data \gets`$ $`data \gets`$ $`data \gets`$ $`data \gets`$ $`data`$

</div>

# Range coding

The range coder is a byte-wise arithmetic coder that operates by
repeatedly reducing a probability range (for example 0.0 to 1.0) one
symbol (byte) at a time, with the complete compressed data being
represented by any value within the final range.

This is easiest demonstrated with a worked example, so let us imagine we
have an alphabet of 4 symbols, 't', 'c', 'g', and 'a' with probabilities
0.2, 0.3, 0.3 and 0.2 respectively. We can construct a cumulative
distribution table and apply probability ranges to each of the symbols:

| **Symbol** | **Probability** | **Range low** | **Range high** |
|-----------:|----------------:|--------------:|---------------:|
|          t |             0.2 |           0.0 |            0.2 |
|          c |             0.3 |           0.2 |            0.5 |
|          g |             0.3 |           0.5 |            0.8 |
|          a |             0.2 |           0.8 |            1.0 |

As a *conceptual example* (note: this is not how it is implemented in
practice, see below) using arbitrary precision floating point
mathematics this could operate as follows.

If we wish to encode a message, such as "cat" then we will encode one
symbol at a time ('c', 'a', 't') successively reducing the initial range
of 0.0 to 1.0 by the cumulative distribution for that symbol. At each
point the new range is adjusted to be the proportion of the previous
range covered by the cumulative symbol range. See the table footnotes
below for the worked mathematics.

<div class="threeparttable">

| **Range low** | **/ high** | **Symbol** | **Sym. low** | **/ high** | **New range low** | **New range high** |
|---:|---:|---:|---:|---:|---:|---:|
| 0.000 | 1.000 | c | 0.2 | 0.5 | $`0+(1-0)\times.2`$ | $`0+(1-0)\times.5`$ |
| 0.200 | 0.500 | a | 0.8 | 1.0 | $`.2+(.5-.2)\times.8`$ | $`.2+(.5-.2)\times 1`$ |
| 0.440 | 0.500 | t | 0.0 | 0.2 | $`.44+(.5-.44)\times 0`$ | $`.44+(.5-.44)\times .2`$ |
| 0.440 | 0.452 | \<end\> |  |  |  |  |

</div>

Our final range is 0.44 to 0.452 with any value in that range
representing "cat", thus 0.45 would suffice. A pictorial example of this
process is below.

<figure data-latex-placement="h">
<img src="img/range_code.png" style="height:250pt" />
<figcaption>A pictorial demonstration of range reduction.</figcaption>
</figure>

Decoding is simply the reverse of this. In the above picture we can see
that 0.45 would read off 'c', 'a' and 't' by repeatedly comparing the
symbol ranges to the current range and using those to identify the
symbol and produce a new range.

<div class="threeparttable">

| **Range low** | **Range high** | **Fraction into range** | **Symbol** |
|--------------:|---------------:|------------------------:|-----------:|
|         0.000 |          1.000 |                   0.450 |          c |
|         0.200 |          0.500 |                   0.833 |          a |
|         0.440 |          0.500 |                   0.167 |          t |

<div class="tablenotes">

**a.** 0.45 into range 0.2 to 0.5: $`(0.45-0.2)/(0.5-0.2) = 0.833`$.
This falls within the 0.8 to 1.0 symbol range for 'a'.

**b.** 'a' symbol range 0.8 to 1.0 applied to range 0.2 to 0.5:
$`0.2+0.8\times(0.5-0.2) = 0.44`$ and $`0.2+1.0\times(0.5-0.2) = 0.5`$.

</div>

</div>

Note: The above example is not how the actual implementation works[^6].
For efficiency, we use integer values having a starting range of 0 to
$`2^{32}-1`$. We write out the top 8-bits of the range when low and high
become the same value. Special care needs to be taken to handle small
values that are numerically close but stradding a top byte value, such
as 0x37ffba20 to 0x38000034. The decoder does not need to do anything
special here, but the encoder must track the number of 0xff or 0x00
values to emit in order to avoid needing arbitrary precision integers.

Pseudocode for the range codec decoding follows. This implementation
uses code (next few bytes in the current bit-stream) and range instead
of low and high, both 32-bit unsigned integers. This specification
focuses on decoding, but given the additional complexity of the
precision overflows in encoder we describe this implementation too.

<span class="smallcaps">RangeDecodeCreate</span> initialises the range
coder, reading the first bytes of the compressed data stream.

<div class="algorithmic">

$`{}\gets`$ $`2^{32}-1`$ $`{}\gets`$ $`0`$
$`code \gets (code \mathbin{<\mkern-3mu<\,}8) +`$ $`code \gets code %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
2^{32}-1`$ this range coder ($`range`$, $`code`$)

</div>

Decoding each symbol is in two parts; getting the current frequency and
updating the range.

<div class="algorithmic">

$`range \gets range %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
tot\_freq`$ $`code %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
range`$

</div>

<div class="algorithmic">

$`{}\gets`$ $`code - sym\_low \times range`$ $`{}\gets`$
$`range \times sym\_freq`$

$`{}\gets`$ $`range \mathbin{<\mkern-3mu<\,}8`$ $`{}\gets`$
$`(code\mathbin{<\mkern-3mu<\,}8) +`$

</div>

As mentioned above, the encoder is more complex as it cannot shift out
the top byte until it has determined the value. This can take a
considerable while if our current low / high (low + range) are very
close but span a byte boundary, such as 0x37ffba20 to 0x38000034, where
ultimately we will later emit either 0x37 or 0x38. To handle this case,
when the range gets too small but the top bytes still differ, the
encoder caches the top byte of low (0x37) and keeps track of how many
0xff or 0x00 values will need to be written out once we finally observe
which value the range has shrunk to.

The <span class="smallcaps">RangeEncode</span> function is a straight
forward reversal of the <span class="smallcaps">RangeDecode</span>, with
the exception of the special code for shifting the top byte out of the
$`low`$ variable.

<div class="algorithmic">

$`{}\gets`$ $`low`$ $`{}\gets`$ $`range %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
tot\_freq`$ $`{}\gets`$ $`low + sym\_low \times range`$ $`{}\gets`$
$`range \times sym\_freq`$

$`carry \gets 1`$ $`{}\gets`$ $`range \mathbin{<\mkern-3mu<\,}8`$

</div>

<span class="smallcaps">RangeShiftLow</span> is the main heart of the
encoder renormalisation. It tracks the total number of extra bytes to
emit and $`carry`$ indicates whether they are a string of 0xFF or 0x00
values.

<div class="algorithmic">

$`FFnum \gets FFnum - 1`$ $`FFnum \gets FFnum - 1`$
$`cache \gets low \mathbin{>\mkern-3mu>\,}24`$ $`carry \gets 0`$
$`FFnum \gets FFnum + 1`$ $`low \gets low \mathbin{<\mkern-3mu<\,}8`$

</div>

For completeness, the Encoder initialisation and finish functions are
below.

<div class="algorithmic">

$`{}\gets`$ $`0`$ $`{}\gets`$ $`2^{32}-1`$ $`{}\gets`$ $`0`$ $`{}\gets`$
$`0`$ $`{}\gets`$ $`0`$

</div>

<div class="algorithmic">

</div>

## Adaptive Modelling

The probabilities passed to the range coder may be fixed for all
scenarios (as we had in the "cat" example), or they may be adaptive and
context aware. For example the letter 'u' occurs around 3% of time in
English text, but if the previous letter was 'q' it is close to 100% and
if the previous letter was 'u' it is close to 0%. Using the previous
letter is known as an Order-1 entropy encoder, but the context can be
anything. We can also adaptively adjust our probabilities as we encode
or decode, learning the likelihoods and thus avoiding needing to store
frequency tables in the data stream covering all possible contexts.

To do this we use a statistical model, containing an array of symbols
$`S`$ and their frequencies $`F`$. The sum of these frequences must be
less than $`2^{16}-16`$ so after adjusting the frequencies it never go
above the maximum unsigned 16-bit integer. When they get too high, they
are renormalised by approximately halving the frequencies (ensuring none
drop to zero).

Typically an array of models are used where the array index represents
the current context.

To encode any symbol the entropy encoder needs to know the frequency of
the symbol to encode, the cumulative frequencies of all symbols prior to
this symbol, and the total of all frequencies. For decoding a cumulative
frequency is obtained given the frequency total and the appropriate
symbol is found matching this frequency. Symbol frequencies are updated
after each encode or decode call and the symbols are kept in order of
most-frequent symbol first in order to reduce the overhead of scanning
through the cumulative frequencies.

<span class="smallcaps">ModelCreate</span> initialises a model by
setting every symbol to have a frequency of 1. (At no point do we permit
any symbol to have zero frequency.)

<div class="algorithmic">

$`total\_freq \gets num\_sym`$ $`max\_sym \gets num\_sym-1`$
$`S_i \gets i`$ $`F_i \gets 1`$ this model ($`total\_freq`$,
$`max\_sym`$, $`S`$, $`F`$)

</div>

<span class="smallcaps">ModelDecode</span> is called once for each
decoded symbol. It returns the next symbol and updates the model
frequencies automatically.

<div class="algorithmic">

$`freq \gets`$ $`rc.`$ $`x \gets 0`$ $`acc \gets 0`$
$`acc \gets acc + F_x`$ $`x \gets x+1`$ $`rc.`$ $`F_x \gets F_x + 16`$
$`total\_freq \gets total\_freq + 16`$ $`sym \gets S_x`$ $`sym`$

</div>

<span class="smallcaps">ModelRenormalise</span> is called whenever the
total frequencies get too high. The frequencies are halved, taking sure
to avoid any zero frequencies being created.

<div class="algorithmic">

$`total\_freq \gets 0`$ $`F_i \gets F_i - (F_i %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
2)`$ $`total\_freq \gets total\_freq + F_i`$

</div>

## Order-0 and Order-1 Encoding

We can combine the model defined above and the range coder to provide a
simple function to perform Order-0 entropy decoder.

<div class="algorithmic">

$`max\_sym \gets`$ $`max\_sym \gets 256`$ $`model\_lit \gets`$
$`rc \gets`$ $`out_i \gets model\_lit.`$ $`out`$

</div>

The Order-1 variant simply uses an array of models and selects the
appropriate model based on the previous value encoded or decoded. This
array index is our "context".

<div class="algorithmic">

$`max\_sym \gets`$ $`max\_sym \gets 256`$ $`model\_lit_i \gets`$
$`rc \gets`$ $`last \gets 0`$ $`out_i \gets model\_lit_{last}.`$
$`last \gets out_i`$ $`out`$

</div>

## RLE with Order-0 and Order-1 Encoding

The <span class="smallcaps">DecodeOrder0</span> and
<span class="smallcaps">DecodeOrder1</span> codecs can be expanded to
include a count of how many runs of each symbol should be decoded. Both
order 0 and order 1 variants are possible.

After the symbol is decoded, the run length must be decoded to indicate
how many *extra* copies of this symbol occur. Long runs are broken into
a series of lengths of no more than 3. If length 3 is decoded it
indicates we must decode an additional length and add to the current
one. The context used for the run length model is the symbol itself for
the initial run, 256 for the first continuation run (if $`\ge 4`$) and
257 for any further continuation runs. Thus encoding 10 'A' characters
would first store symbol 'A' followed by run length 3 (with context
'A'), length 3 (context 256), length 3 (context 257), and length 1
(context 257).

For example, if we have the string "ABBCCCCDDDDD" we will record
"A"\<0\> "B"\<1\> "C"\<3,0\> and "D"\<3,1\>.

<div class="algorithmic">

$`max\_sym \gets`$ $`max\_sym \gets 256`$ $`model\_lit \gets`$

$`model\_run_i \gets`$ $`rc \gets`$ $`i \gets 0`$
$`out_i \gets model\_lit.`$ $`part \gets model\_run_{out_i}.`$
$`run \gets part`$ $`rctx \gets 256`$ $`part \gets model\_run_{rctx}.`$
$`rctx \gets 257`$ $`run \gets run + part`$ $`out_{i+j} \gets out_i`$
$`i \gets run+1`$ $`out`$

</div>

The order-1 run length variant is identical to order-0 except the
previous symbol is used as the context for the next literal. The context
for the run length does not change.

<div class="algorithmic">

$`max\_sym \gets`$ $`max\_sym \gets 256`$ $`model\_lit_i \gets`$
$`model\_run_i \gets`$ $`rc \gets`$ $`last \gets 0`$ $`i \gets 0`$
$`out_i \gets model\_lit_{last}.`$ $`last \gets out_i`$
$`part \gets model\_run_{last}.`$ $`run \gets part`$ $`rctx \gets 256`$
$`part \gets model\_run_{rctx}.`$ $`rctx \gets 257`$
$`run \gets run + part`$ $`out_{i+j} \gets last`$ $`i \gets run+1`$
$`out`$

</div>

We wrap up the Order-0 and 1 entropy encoder, both with and without run
length encoding, into a data stream that specifies the type of encoded
data and also permits a number of additional transformations to be
applied. These transformations support bit packing (for example a data
block with only 4 distinct values can be packed with 4 values per byte),
no-op for tiny data blocks where entropy encoding would grow the data
and N-way interleaving of the 8-bit components of a 32-bit value.

<table>
<thead>
<tr>
<th colspan="2" style="text-align: right;"><strong>Bits</strong></th>
<th style="text-align: right;"><strong>Type</strong></th>
<th style="text-align: right;"><strong>Name</strong></th>
<th colspan="2"
style="text-align: left;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td colspan="2" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">flag</span></td>
<td colspan="2" style="text-align: left;">Data format bit field</td>
</tr>
<tr>
<td style="text-align: right;"><span>1-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>Unless <span
class="smallcaps">NoSize</span> flag is set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint7</td>
<td style="text-align: right;">ulen</td>
<td style="text-align: left;">Uncompressed length</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If <span
class="smallcaps">Stripe</span> flag is set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;">N</td>
<td style="text-align: left;">Number of sub-streams</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint7[]</td>
<td style="text-align: right;">clen[]</td>
<td style="text-align: left;">N copies of compressed sub-block
length</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">cdata[]</td>
<td style="text-align: left;">N copies of Compressed data sub-block
(recurse)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If <span
class="smallcaps">Cat</span> flag is set (and <span
class="smallcaps">Stripe</span> flag is unset):</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">udata</td>
<td style="text-align: left;">Uncompressed data stream</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If <span
class="smallcaps">Pack</span> flag is set (and neither <span
class="smallcaps">Stripe</span> or <span class="smallcaps">Cat</span>
flags are set):</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">pack_meta</td>
<td style="text-align: left;">Pack lookup table</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>If neither <span
class="smallcaps">Stripe</span> or <span class="smallcaps">Cat</span>
flags are set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;">?</td>
<td style="text-align: right;">uint8[]</td>
<td style="text-align: right;">cdata</td>
<td style="text-align: left;">Entropy encoded data stream (see <span
class="smallcaps">Order</span> / <span class="smallcaps">RLE</span> /
<span class="smallcaps">Ext</span> flags)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-5</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

The first byte of our generalised data stream is a bit-flag detailing
the type of transformations and entropy encoders to be combined,
followed by optional meta-data, followed by the actual compressed data
stream. The bit-flags are defined below, but note not all combinations
are permitted.

<div class="threeparttable">

| **Bit AND value** | **Code** | **Description** |  |
|:---|:---|:---|:---|
| 1 | <span class="smallcaps">Order</span> | Order-0 or Order-1 entropy coding |  |
| 2 | reserved | Reserved (for possible order-2/3) |  |
| 4 | <span class="smallcaps">Ext</span> | "External" compression via bzip2 |  |
| 8 | <span class="smallcaps">Stripe</span> | N-way interleaving of byte streams |  |
| 16 | <span class="smallcaps">NoSize</span> | Original size is not recorded (used by <span class="smallcaps">Stripe</span>) |  |
| 32 | <span class="smallcaps">Cat</span> | Data is uncompressed |  |
| 64 | <span class="smallcaps">RLE</span> | Run length encoding, with runs and literals encoded separately |  |
| 128 | <span class="smallcaps">Pack</span> | Pack 2, 4, 8 or infinite symbols per byte |  |

<div class="tablenotes">

($`*`$) Has no effect when <span class="smallcaps">Ext</span> flag is
set.

() Not to be used in conjunction with other flags except
<span class="smallcaps">Pack</span> and
<span class="smallcaps">NoSize</span>.

</div>

</div>

Of these <span class="smallcaps">Stripe</span> is the most complex. As
with the rANS Nx16 encoder, the data is rearranged such that every
$`N^{th}`$ byte is adjacent in a single block producing N distinct
sub-blocks. Each of the N streams is then itself compressed using this
compression format.

For example an input block of small unsigned 32-bit little-endian
numbers may use RLE for the first three streams as they are mostly zero,
and a non-RLE Order-0 entropy encoder of the last stream. Normally our
data format will include the decoded size, but with
<span class="smallcaps">Stripe</span> we can omit this from the internal
compressed streams as we know their size will be a computable fraction
of the combined data.

The data layout differs for each of these bit types, as described below
in the <span class="smallcaps">ArithDecode</span> function. Some of
these can be used in combination, so the order needs to be observed. The
Pack format has additional meta data. This is decoded first, before
entropy decoding and finally expanding the specified pack transformation
after decompression. For example value 193 is indicates a byte stream
should be decoded with an RLE aware order-1 entropy encoder and then
unpacked.

<div class="algorithmic">

$`flags \gets`$ $`len \gets`$ $`data \gets`$ $`data`$
$`pack\_len \gets len`$ $`(P,\ nsym,\ len) \gets`$ $`data \gets`$
$`data \gets`$ $`data \gets`$ $`data \gets`$ $`data \gets`$
$`data \gets`$ $`data \gets`$ $`data`$

</div>

The specifics of each sub-format are described below, in the order
(minus meta-data specific shuffling) they are applied.

- **<span class="smallcaps">Stripe</span>**: The byte stream consists of
  a 7-bit encoded uncompressed length and a byte holding the number of
  substreams $`N`$, and their 7-bit encoded compressed data streams
  lengths. This is then followed by the substreams themselves, each of
  which is a valid $`cdata`$ stream as defined above, hence this offers
  a recursive mechanism as each substream has its own format byte.

  The total uncompressed byte stream is then an interleaving of one byte
  in turn from each of the N substreams (in order of 1st to Nth). Thus
  an array of 32-bit unsigned integers could be unpacked using
  <span class="smallcaps">Stripe</span> to compress each of the 4 8-bit
  components together with their own algorithm.

  <div class="algorithmic">

  $`N \gets`$ $`clen_j \gets`$ $`ulen_j \gets (len %
    \nonscript\mskip-\medmuskip\mkern 5mu%
    \mathbin{\operator@font div}\penalty 900\mkern 5mu%
    \nonscript\mskip-\medmuskip
  N) + ((len \bmod N) > j)`$ $`T_j \gets`$
  $`out_{i \times N + j} \gets T_{j,i}`$ $`out`$

  </div>

- **<span class="smallcaps">NoSize</span>**: Do not store the size of
  the uncompressed data stream. This information is not required when
  the data stream is one of the four sub-streams in the
  <span class="smallcaps">Stripe</span> format.

- **<span class="smallcaps">Cat</span>**: If present, all other bit
  flags should be zero, with the possible exception of
  <span class="smallcaps">NoSize</span> or
  <span class="smallcaps">Pack</span>.

  The uncompressed data stream is the same as the compressed stream.
  This is useful for very short data where the overheads of compressing
  are too high.

- **<span class="smallcaps">Order</span>**: Bit field defining order-0
  (unset) or order-1 (set) entropy encoding, as described above by the
  <span class="smallcaps">DecodeOrder0</span> and
  <span class="smallcaps">DecodeOrder1</span> functions.

- **<span class="smallcaps">RLE</span>**: Bit field defining whether the
  Order-0 and Order-1 encoding should also use a run-length. When set,
  the <span class="smallcaps">DecodeRLE0</span> and
  <span class="smallcaps">DecodeRLE1</span> functions will be used
  instead of <span class="smallcaps">DecodeOrder0</span> and
  <span class="smallcaps">DecodeOrder1</span>.

- **<span class="smallcaps">Ext</span>**: Instead of using the adaptive
  arithmetic coder for decompression (with or without RLE), this uses an
  compression codec defined in an "external" library. Currently the only
  supported such codec is Bzip2. In future more may be added, so the
  "magic number" (the file signature, typically in first few bytes of
  data) *must* be validated to check the external codec being used.

  Given bzip2 is already supported elsewhere in CRAM, the purpose of
  adding it here is to permit bzip2 compression after
  <span class="smallcaps">Pack</span> and
  <span class="smallcaps">Stripe</span> transformations. This may be
  tidied up in later CRAM releases to clarify the separation between
  compression codecs and data transforms, but that requires more major
  restructuring so for compatibility with v3.0 these have been placed
  into this single codec.

  <div class="algorithmic">

  Error

  </div>

- **<span class="smallcaps">Pack</span>**: Data containing only 1, 2, 4
  or 16 distinct values can have multiple values packed into a single
  byte (infinite, 8, 4 or 2). The distinct symbol values do not need to
  be adjacent as a mapping table $`P`$ converts mapped value $`x`$ to
  original symbol $`P_x`$.

  The packed format is split into uncompressed meta-data (below) and the
  compressed packed data as described in the rANS Nx16 bit-packing
  section. The same <span class="smallcaps">DecodePackMeta</span> and
  <span class="smallcaps">DecodePack</span> functions are used.

# Name tokenisation codec

Sequence names (identifiers) typically follow a structured pattern and
compression based on columns within those structures usually leads to
smaller sizes. The sequence name (identifier) tokenisation relies
heavily on the rANS Nx16 and Adaptive arithmetic coders described above.

As an example, take a series of names:

    I17_08765:2:123:61541:01763#9
    I17_08765:2:123:1636:08611#9
    I17_08765:2:124:45613:16161#9

We may wish to tokenise each of these into 7 tokens, e.g.
"I17_08765:2:", "123", ":", "61541", ":", "01763"and "\#9". Some of
these are multi-byte strings, some single characters, and some numeric,
possibily with a leading zero. We also observe some regularly have
values that match the previous line (the initial prefix string, colons,
"\#9") while others are numerically very close to the value in the
previous line (124 vs 123).

The name tokeniser compares each name against a previous name (which is
not necessarily the one immediately prior) and encodes this name either
as a series of differences to the previous name or marking it as an
exact duplicate. A maximum of 128 tokens are permitted within any single
read name.

Token IDs (types) are listed below.

| **ID** | **Type** | **Value** | **Description** |
|:---|:---|:---|:---|
| 0 | TYPE | Type | Used to determine the type of token at a given position |
| 5 | DUP | Integer (distance) | The entire name is a duplicate of an earlier one. Used in position 0 only |
| 6 | DIFF | Integer (distance) | The entire name differs to earlier ones. Used in position 0 only |
| 1 | STRING | String | A nul-terminated string of characters |
| 2 | CHAR | Byte | A single character |
| 7 | DIGITS | $`0 \le`$ Int $`< 2^{32}`$ | A numerical value, not containing a leadng zero |
| 3 | DIGITS0 | $`0 \le`$ Int $`< 2^{32}`$ | A numerical value possibly starting in leading zeros |
| 4 | DZLEN | Int length | Length of associated DIGITS0 token |
| 8 | DELTA | $`0 \le`$ Int $`< 256`$ | A numeric value being stored as the difference to the numeric value of this token on the previous name |
| 9 | DELTA0 | $`0 \le`$ Int $`< 256`$ | As DELTA, but for numeric values starting with leading zeros |
| 10 | MATCH | (none) | This token is identical type and value to the same position in the previous name (NB: not permitted for DELTA/DELTA0) |
| 11 | NOP | (none) | Does nothing |
| 12 | END | (none) | Marks end of name |

The tokens and values are stored in a 2D array of byte streams,
$`B_{pos,type}`$, where pos 0 is reserved for name meta-data (whether it
is a duplicate name) and pos 1 onwards is for the first, second and
later tokens. $`Type`$ is one of the token types listed above,
corresponding to the type of data being stored. Some token types may
also have associated values. $`B_{pos,\texttt{TYPE}}`$ ($`type`$) holds
the token type itself and that is then used to retrieve any associated
value(s) if appropriate from $`B_{pos,type}`$. Thus multiple types at
the same token position will have their values encoded in distinct data
streams, e.g. if position 5 is of type either DIGITS or DELTA then data
streams will exist for $`B_{5,\texttt{TYPE}}`$,
$`B_{5,\texttt{DIGITS}}`$ and $`B_{5, \texttt{DELTA}}`$. Decoding per
name continues until a token of type END is observed.

More detail on the token types is given below.

- **TYPE**: This is the first token fetched at each token position. It
  holds the type of the token at this position, which in turn may then
  require retrieval from type-specific data streams at this position.

  For position 0, the TYPE field indicates whether this record is an
  exact duplicate of a prior read name or has been encoded as a delta to
  an earlier one.

- **DUP**, **DIFF**: These types are fetched for position 0, at the
  start of each new identifier. The value is an integer value describing
  how many reads before this (with 1 being the immediately previous
  name) we are comparing against. When we subsequently refer to
  "previous name" below, we always mean the one indicated by the DIFF
  field and not the one immediately prior to the current name.

  The first record will have a DIFF of zero and no delta or match
  operations are permitted.

- **STRING**: We fetch one byte at a time from the value byte stream,
  appending to the name buffer until the byte retrieved is zero. The
  zero byte is not stored in the name buffer. For purposes of token type
  MATCH, a match is defined as entirely matching the string including
  its length.

- **CHAR**: Fetch one single byte from the value byte stream and append
  to the name buffer.

- **DIGITS**: Fetch 4 bytes from the value byte stream and intrepret
  these as a little endian unsigned integer. This is appended to the
  name buffer as string of base-10 digits, most significant digit first.
  Larger values may be represented, but will require multiple DIGITS
  tokens. Negative values may be encoded by treating the minus sign as a
  CHAR or STRING and storing the absolute value.

- **DIGITS0**, **DZLEN**: This fetches the 4 byte value from
  $`B_{pos,DIGITS0}`$ and a 1 byte length from $`B_{pos,DZLEN}`$. As per
  DIGITS, the value is intrepreted as a little endian unsigned integer.
  The length indicates the total size of the numeric value when
  displayed in base 10 which must be greater than $`\log_{10}(value)`$
  with any remaining length indicating the number of leading zeros. For
  example if DIGITS0 value is 123 and DZLEN length is 5 the string
  "00123" must be appended to the name.

  For purposes of the MATCH type, both value and length must match.

- **DELTA**: Fetch a 1 byte value and add this to the DIGITS value from
  the previous name. The token in the prior name must be of type DIGITS
  or DELTA.

  MATCH is not supported for this type.

- **DELTA0**: As per DELTA, but the 1 byte value retrieved is added to
  the DIGITS0 value in the previous name. No DZLEN value is retrieved,
  with the length from the previous name being used instead. The token
  in the prior name must be of type DIGITS0 or DELTA0.

  MATCH is not supported for this type.

- **MATCH**: This token matches the token at the same position in the
  previous name. (The previous name is permitted to also have a MATCH
  token at this position, in which case it recurses to its previous
  name.)

  MATCH is only valid when the token being matched against is CHAR,
  STRING, DIGITS, DIGITS0 or MATCH. (I.e. matching a numeric delta will
  not repeat the delta increment.)

  No value is needed for MATCH tokens.

- **NOP**: This token type does nothing. The purpose of this is simply
  to permit skipping tokens in order to keep token numbers in sync, such
  as when processing "10" vs "-10" with the latter needing an additional
  "-" token.

- **END**: Marks the end of the name. A nul byte is added to the name
  output buffer. No value is needed for END tokens.

Decoding needs some simple functions to read successive bytes from our
token byte streams, as 8-bit characters or unsigned integers, as 32-bit
unsigned integers and nul-terminated strings. We reuse the
<span class="smallcaps">ReadUint32</span> and related functions with the
byte array specified as input.

<div class="algorithmic">

*(Convert an integer to a string form in base-10 digits, at least
$`len`$ bytes long with leading zeros)* $`str \gets val`$ $`str \gets`$
'$`0`$' $`\mathbin{+\mkern-10mu+\,}str`$ $`str`$

</div>

For the main name decoding loop, we use a single dimensional array of
names decoded so far, $`N`$, and a two dimensional array of their tokens
$`T`$ (indexed by name number $`n`$ and token position $`t`$ within that
name). We define a function to decode the $`n^{th}`$ name ($`N_n`$)
using a previous $`m^{th}`$ name ($`N_m`$). The tokens $`T`$ are used in
`MATCH` and `DELTA` token types to copy data from when constructing the
name.

Now we have the basic primitives for pulling from the $`B`$ byte
streams, decoding the $`n^{th}`$ individual name is as follows[^7]:

<div class="algorithmic">

*(Decodes the $`n^{th}`$ name, returning $`N_n`$ and updating globals
$`N_n`$ and $`T_n`$)* $`type \gets`$ $`dist \gets`$ $`m \gets n-dist`$
$`N_n \gets N_m`$ $`T_n \gets T_m`$ $`N_n`$ $`t \gets 1`$ $`type \gets`$
$`T_{n,t} \gets`$ $`T_{n,t} \gets`$ $`T_{n,t} \gets`$ $`d \gets`$
$`l \gets`$ $`T_{n,t} \gets`$ $`T_{n,t} \gets T_{m,t} +`$
$`d \gets T_{m,t} +`$ $`l \gets`$ $`T_{n,t} \gets`$
$`T_{n,t} \gets T_{m,t}`$ $`T_{n,t} \gets`$ ''
$`N_n \gets N_n \mathbin{+\mkern-10mu+\,}T_{n,t}`$ $`t \gets t+1`$
$`N_n`$

</div>

Given a complex name with both position and type specific values, this
can lead to many separate data streams. The name tokeniser codec is a
format within a format, as the multiple byte streams $`B_{pos,type}`$
are serialised into a single byte stream.

The serialised data stream starts with two unsigned little endian 32-bit
integers holding the total size of uncompressed name buffer and the
number of read names, and a flag byte indicating whether data is
compressed with arithmetic coding or rANS Nx16. Note the uncompressed
size is calculated as the sum of all name lengths including a
termination byte per name (e.g. the nul char). This is irrespective of
whether the implementation produces data in this form or whether it
returns separate name and name-length arrays.

This is then followed by serialised data and meta-data for each token
stream. Token types, $`ttype`$ holds one of the token ID values listed
above in the list above, plus special values to indicate certain
additional flags. Bit 6 (64) set indicates that this entire token data
stream is a duplicate of one earlier. Bit 7 (128) set indicates the
token is the first token at a new position. This way we only need to
store token types and not token positions.

The total size of the serialised stream needs to be already known, in
order to determine when the token types finish.

<table>
<thead>
<tr>
<th colspan="3" style="text-align: right;"><strong>Bytes</strong></th>
<th style="text-align: left;"><strong>Type</strong></th>
<th style="text-align: left;"><strong>Name</strong></th>
<th style="text-align: left;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td colspan="3" style="text-align: right;">4</td>
<td style="text-align: left;">uint32</td>
<td style="text-align: left;"><span
class="math inline">uncomp\_length</span></td>
<td style="text-align: left;">Length of uncompressed name buffer</td>
</tr>
<tr>
<td colspan="3" style="text-align: right;">4</td>
<td style="text-align: left;">uint32</td>
<td style="text-align: left;"><span
class="math inline">num\_reads</span></td>
<td style="text-align: left;">Number of read names</td>
</tr>
<tr>
<td colspan="3" style="text-align: right;">1</td>
<td style="text-align: left;">uint8</td>
<td style="text-align: left;"><span
class="math inline">use\_arith</span></td>
<td style="text-align: left;">Whether compression is arithmetic (1) or
rANS Nx16 (0)</td>
</tr>
<tr>
<td colspan="6" style="text-align: left;"><em>For each token data
stream</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-6</span></td>
<td colspan="2" style="text-align: right;">1</td>
<td style="text-align: left;">uint8</td>
<td style="text-align: left;"><span
class="math inline">ttype</span></td>
<td style="text-align: left;">Token type code plus flags (64=duplicate,
128=next token position).</td>
</tr>
<tr>
<td style="text-align: right;"><span>2-6</span></td>
<td colspan="5" style="text-align: left;"><em>If ttype AND 64
(duplicate)</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;">1</td>
<td style="text-align: left;">uint8</td>
<td style="text-align: left;"><span
class="math inline">dup\_pos</span></td>
<td style="text-align: left;">Duplicate from this token position</td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;">1</td>
<td style="text-align: left;">uint8</td>
<td style="text-align: left;"><span
class="math inline">dup\_type</span></td>
<td style="text-align: left;">Duplicate from this token type ID</td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td colspan="5" style="text-align: left;"><em>else if not
duplicate</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;">?</td>
<td style="text-align: left;">uint7</td>
<td style="text-align: left;"><span class="math inline">clen</span></td>
<td style="text-align: left;">compressed length</td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"><span
class="math inline">clen</span></td>
<td style="text-align: left;">uint8[]</td>
<td style="text-align: left;"><span
class="math inline">cdata</span></td>
<td style="text-align: left;">compressed data stream</td>
</tr>
</tbody>
</table>

A few tricks are used to remove some byte streams. In addition to the
explicit marking of duplicate bytes streams, if a byte stream of token
types is entirely MATCH apart from the very first value it is discarded.
It is possible to regenerate this during decode by observing the other
byte streams. For example if we have a byte stream $`B_{5,DIGITS}`$ but
no $`B_{5,TYPE}`$ then we assume the contents of $`B_{5,TYPE}`$ consist
of one DIGITS type followed by as many MATCH types as are needed.

The $`cdata`$ stream itself is as described in the relevant entropy
encoder section above (rANS or arithmetic coding).

<div class="algorithmic">

*(Decodes and uncompresses the serialised token byte streams)*
$`sz \gets 0`$ $`t \gets -1`$ $`ttype \gets`$ $`tok\_new \gets ttype %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
128`$ $`tok\_dup \gets ttype %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
64`$ $`type \gets ttype %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
63`$ $`t \gets t+1`$
$`B_{t,\texttt{TYPE}} \gets (type, \texttt{TOK\_MATCH}, \texttt{TOK\_MATCH}, ...)`$
$`dup\_pos \gets`$ $`dup\_type \gets`$
$`B_{t,type} \gets B_{dup\_pos,dup\_type}`$ $`clen \gets`$
$`data \gets`$ $`B_{t,type} \gets`$ $`B_{t,type} \gets`$ $`B`$

</div>

<div class="algorithmic">

*(Decodes all names, returning $`N`$)* $`ulen \gets`$ $`nnames \gets`$
$`use\_arith \gets`$ $`B \gets`$

$`N_n \gets`$ $`N`$

</div>

# FQZComp quality codec

The FQZComp quality codec uses an adaptive statistical model to predict
the next quality value in a given context (comprised of previous quality
values, position along this sequence, whether the sequence is the second
in a pair, and a running total of number of times the quality has
changed in this sequence).

For each position along the sequence, the models produce probabilities
for all possible next quality values, which are passed into an
arithmetic entropy encoder to encode or decode the actual next quality
value. The models are then updated based on the actual next quality in
order to learn the statistical properties of the quality data stream.
This step wise update process is identical for both encoding and
decoding.

The algorithm is a generalisation on the original fqzcomp program,
described in *Compression of FASTQ and SAM Format Sequencing Data* by
Bonfield JK, Mahoney MV (2013). PLoS ONE 8(3): e59190.
<https://doi.org/10.1371/journal.pone.0059190>

## FQZComp Models

The FQZComp process utilises knowledge of the read lengths, complement
(qualities reversed) status, and a generic parameter selector, but in
order to maintain a strict separation between CRAM data series this
knowledge is stored (duplicated) within the quality data stream itself.
Note the complement model is only needed in CRAM 3.1 as CRAM 4 natively
stores the quality in the original orientation already. Both reversed
and duplication models have no context and are boolean values.

The parameter selector model also has no context associated with it and
encodes $`max\_sel`$ distinct values. The selector value may be
quantised further using $`stab`$ (Selector Table) to reduce the selector
to fewer sets of parameters. This is useful if we wish to use the
selector bits directly in the context using the same parameters. The
selector is arbitrary and may be used for distinguishing READ1 from
READ2, as a precalculated "delta" instead of the running total,
distinguishing perfect alignments from imperfect ones, or any other
factor that is shown to improve quality predictability and increase
compression ratio (average quality, number of mismatches, tile, swathe,
proximity to tile edge, etc).

The quality model has a 16-bit context used to address an array of
$`2^{16}`$ models, each model permitting $`max\_sym`$ distinct quality
values. The context used is defined by the FQZcomp parameters, of which
there may be multiple sets, selected using the selector model. There are
4 read length models each having $`max\_sym`$ of 256. Each model is used
for the 4 successive bytes in a 32-bit length value.

The entropy encoder used is shared between all models, so the bit
streams are multiplexed together.

The 16-bit quality value context is constructed by adding sub-contexts
together consisting of previous quality values, position along the
current record, a running count (per record) of how many times the
quality value has differed to the previous one (delta), and an arbitrary
stored selector value, each shifted to a defined location within the
combined context value ($`qloc`$, $`ploc`$, $`dloc`$ and $`sloc`$
respectively). The qual, pos and delta sub-contexts are computed from
the previous data while the selector, if used, is read directly from the
compressed data stream. The selector may be used to switch parameter
sets, or simply to group quality strings into arbitrary user-defined
sub-sets. The numeric values for each of these components can be passed
through lookup tables ($`qtab`$ for quality, $`ptab`$ for positions,
$`dtab`$ for running delta and $`stab`$ for turning the selector $`s`$
into a parameter index $`x`$). These all convert the monotonically
increasing range 0$`\rightarrow`$M to a (usually smaller) monotonically
increasing 0$`\rightarrow`$N. For example if we wish to use the
approximate position along a 100 byte string, we may uniformly map
0$`\rightarrow`$<!-- -->127 to 0$`\rightarrow`$<!-- -->15 to utilise 4
bits of our 16-bit combined context.

<figure data-latex-placement="h">

<figcaption>An example FQZComp configuration.</figcaption>
</figure>

As some sequencing instruments produce binned qualities, e.g. 0, 10, 25,
35, these values are squashed to incremental values from 0 to
$`max\_sym-1`$ where $`max\_sym`$ is the maximum number of distinct
quality values observed. If this transform is required, the flag
$`have\_qmap`$ will be set and a mapping table ($`qmap`$) will hold the
original quality values. The encoded qualities will be the smaller
mapped range.

The quality sub-context is constructed by shifting left the previous
quality sub-context by $`qshift`$ bits and adding the current quality
after passing through the $`qmap`$ transform and if defined through the
$`qtab`$ lookup table. The quality context is limited to $`qbits`$ long
and is added to the combined context starting at bit $`qloc`$. The
quality sub-context is reset to zero at the start of each new record.
[^8]

The position context is simply the number of remaining quality values in
this record, so is a value starting at record length (minus 1) and
decrementing. As with the quality context it may be passed through a
lookup table $`ptab`$ before shifting left by $`ploc`$ bits and adding
to the combined context.

Delta is a count of the number of times the quality value has changed
from one value to a different one. Thus a run of identical values will
not increase delta. It gets reset to zero at the start of every record.
It may be adjusted by the $`dtab`$ lookup table and is shifted by
$`dloc`$ before adding to the combined context.

The selector value may also be used as a sub-context, if the $`do\_sel`$
paramter is set. The initial context value (reset per record) is defined
within each parameter set, providing a more general purpose alternative
to adding the selector value at a defined location ($`sloc`$) into the
context.

Thus the full context can be updated after each decoded quality with the
following pseudocode. Note for brevity this is assuming the $`pos`$,
$`delta`$, $`prevq`$, $`qctx`$ and $`sel`$ parameters referred are
global and updateable.

<div class="algorithmic">

(Add quality $`q`$ to produce and return a new context $`ctx`$)
$`ctx \gets params.context`$
$`qctx \gets (qctx \mathbin{<\mkern-3mu<\,}params.qshift) + qtab_q`$
$`ctx   \gets ctx + ((qctx %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
(2^{params.qbits}-1)) \mathbin{<\mkern-3mu<\,}params.qloc)`$ $`p \gets`$
$`ctx \gets ctx + (ptab_p \mathbin{<\mkern-3mu<\,}params.ploc)`$
$`d \gets`$
$`ctx \gets ctx + (dtab_d \mathbin{<\mkern-3mu<\,}params.dloc)`$
$`delta \gets delta+1`$ $`prevq \gets q`$
$`ctx \gets ctx + (sel \mathbin{<\mkern-3mu<\,}params.sloc)`$ $`ctx%
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font AND}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
(2^{16}-1)`$

</div>

In summary context is produced using the following models:

| Model | Max symbol | Context size | Description |
|:---|---:|:---|:---|
| $`model\_qual`$ | $`max\_sym`$ | $`2^{16}`$ | Primary model for quality values |
| $`model\_len`$ | 256 | 4 | Read length models with the context 0-3 being successive byte numbers (little endian order) |
| $`model\_rev`$ | 2 | none | Used if $`pflags.do\_rev`$ is defined. Indicating which strings to reverse. |
| $`model\_dup`$ | 2 | none | Used if $`pflags.do\_dup`$ is defined. Indicates if this whole string is a duplicate of the last one |
| $`model\_sel`$ | $`max\_sel`$ | none | Used if $`gflags.multi\_param`$ or $`pflags.do\_sel`$ are defined. |

## FQZComp Data Stream

The start of an FQZComp data stream consists of the parameters used by
the decoder. The data layout is as follows.

<table>
<thead>
<tr>
<th colspan="3" style="text-align: right;"><strong>Bits</strong></th>
<th style="text-align: right;"><strong>Type</strong></th>
<th style="text-align: right;"><strong>Name</strong></th>
<th colspan="3"
style="text-align: left;"><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td colspan="3" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">version</span></td>
<td colspan="3" style="text-align: left;">FQZComp format version: must
be 5</td>
</tr>
<tr>
<td colspan="3" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">gflags</span></td>
<td colspan="3" style="text-align: left;">Global FQZcomp bit-flags. From
lowest bit to highest:</td>
</tr>
<tr>
<td colspan="3" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="3" style="text-align: left;">1: <span
class="math inline">multi\_param</span>: indicates more than one
parameter block is present. Otherwise set <span
class="math inline">nparam = 1</span></td>
</tr>
<tr>
<td colspan="3" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="3" style="text-align: left;">2: <span
class="math inline">have\_stab</span>: indicates the parameter selector
is mapped through <span class="math inline">stab</span>. Otherwise set
<span class="math inline">stab_i = i</span></td>
</tr>
<tr>
<td colspan="3" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="3" style="text-align: left;">4: <span
class="math inline">do\_rev</span>: <span
class="math inline">model\_revcomp</span> will be used (CRAM v3.1)</td>
</tr>
<tr>
<td colspan="8" style="text-align: left;"></td>
</tr>
<tr>
<td colspan="8" style="text-align: left;"><em>If <span
class="math inline">multi\_param</span> gflag is set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td colspan="2" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">nparam</span></td>
<td colspan="2" style="text-align: left;">Number of parameter blocks
(defaults to 1)</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="8" style="text-align: left;"><em>If <span
class="math inline">have\_stab</span> gflag is set:</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td colspan="2" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">max\_sel</span></td>
<td colspan="2" style="text-align: left;">Maximum parameter selector
value</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;">variable</td>
<td style="text-align: right;">array</td>
<td style="text-align: right;"><span
class="math inline">stab</span></td>
<td colspan="2" style="text-align: left;">Parameter selector table</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td colspan="8" style="text-align: left;"></td>
</tr>
<tr>
<td colspan="8" style="text-align: left;"><em>Parameter block: repeated
<span class="math inline">nparam</span> times: (selected via <span
class="math inline">model\_sel</span> and <span
class="math inline">stab</span>)</em></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td colspan="2" style="text-align: right;">16</td>
<td style="text-align: right;">uint16</td>
<td style="text-align: right;"><span
class="math inline">context</span></td>
<td colspan="2" style="text-align: left;">Starting context value</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td colspan="2" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">pflags</span></td>
<td colspan="2" style="text-align: left;">Per-parameter block bit-flags.
From lowest bit to highest:</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">1: Reserved</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">2: <span
class="math inline">do\_dedup</span>: model_dup will be used</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">4: <span
class="math inline">do\_len</span>: model_len will be used for every
record</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">8: <span
class="math inline">do\_sel</span>: model_sel will be used</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">16: <span
class="math inline">have\_qmap</span>: indicates quality map is
present</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">32: <span
class="math inline">have\_ptab</span>: Load <span
class="math inline">ptab</span>, otherwise position contexts are
unused</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">64: <span
class="math inline">have\_dtab</span>: Load <span
class="math inline">dtab</span>, otherwise delta contexts are
unused</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: left;">128: <span
class="math inline">have\_qtab</span>: Load <span
class="math inline">qtab</span>, otherwise set <span
class="math inline">qtab_i = i</span></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td colspan="2" style="text-align: right;">8</td>
<td style="text-align: right;">uint8</td>
<td style="text-align: right;"><span
class="math inline">max\_sym</span></td>
<td colspan="2" style="text-align: left;">Total number of distinct
quality values</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td colspan="2" style="text-align: right;">4</td>
<td style="text-align: right;">uint4 (high)</td>
<td style="text-align: right;"><span
class="math inline">qbits</span></td>
<td colspan="2" style="text-align: left;">Total number of bits for
quality context</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;">4</td>
<td style="text-align: right;">uint4 (low)</td>
<td style="text-align: right;"><span
class="math inline">qshift</span></td>
<td colspan="2" style="text-align: left;">Left bit shift per successive
quality in quality context</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;">4</td>
<td style="text-align: right;">uint4 (high)</td>
<td style="text-align: right;"><span
class="math inline">qloc</span></td>
<td colspan="2" style="text-align: left;">Bit position of quality
context</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;">4</td>
<td style="text-align: right;">uint4 (low)</td>
<td style="text-align: right;"><span
class="math inline">sloc</span></td>
<td colspan="2" style="text-align: left;">Bit position of selector
context</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;">4</td>
<td style="text-align: right;">uint4 (high)</td>
<td style="text-align: right;"><span
class="math inline">ploc</span></td>
<td colspan="2" style="text-align: left;">Bit position of position
context</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"></td>
<td colspan="2" style="text-align: right;">4</td>
<td style="text-align: right;">uint4 (low)</td>
<td style="text-align: right;"><span
class="math inline">dloc</span></td>
<td colspan="2" style="text-align: left;">Bit position of delta
context</td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td colspan="6" style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td colspan="6" style="text-align: left;"><em>If <span
class="math inline">have\_qmap</span> pflag is set:</em></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;">variable</td>
<td style="text-align: right;">uint8[<span
class="math inline">max\_sym</span>]</td>
<td style="text-align: right;"><span
class="math inline">qmap</span></td>
<td style="text-align: left;">Map for unbinning quality values.</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td colspan="6" style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td colspan="6" style="text-align: left;"><em>If <span
class="math inline">have\_qtab</span> pflag is set:</em></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;">variable</td>
<td style="text-align: right;">array</td>
<td style="text-align: right;"><span
class="math inline">qtab</span></td>
<td style="text-align: left;">Quality context lookup table</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td colspan="6" style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td colspan="6" style="text-align: left;"><em>If <span
class="math inline">have\_tab</span> pflag is set:</em></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;">variable</td>
<td style="text-align: right;">array</td>
<td style="text-align: right;"><span
class="math inline">ptab</span></td>
<td style="text-align: left;">Position context lookup table</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td colspan="6" style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: left;"></td>
<td colspan="6" style="text-align: left;"><em>If <span
class="math inline">have\_tab</span> pflag is set:</em></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;">variable</td>
<td style="text-align: right;">array</td>
<td style="text-align: right;"><span
class="math inline">dtab</span></td>
<td style="text-align: left;">Delta context lookup table</td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>3-6</span></td>
<td colspan="6" style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
<tr>
<td style="text-align: right;"><span>2-7</span></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: right;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
<td style="text-align: left;"></td>
</tr>
</tbody>
</table>

<span class="smallcaps">FQZDecodeParams</span> below describes the
pseudocode for reading the parameter block.

<div class="algorithmic">

$`vers \gets`$ ERROR $`gflags \gets`$ $`nparam \gets`$
$`max\_sel \gets nparam`$ $`nparam \gets 1`$ $`max\_sel \gets 0`$
$`max\_sel \gets`$ $`stab \gets`$ $`max\_sym \gets 0`$ $`param_p \gets`$
$`max\_sym \gets param_p.max\_sym`$

</div>

<div class="algorithmic">

$`{}\gets`$ $`{}\gets`$ $`{}\gets`$ $`{}\gets`$ $`1`$

$`{}\gets`$ $`{}\gets`$ $`x %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
16`$ $`{}\gets`$ $`x \bmod 16`$ $`{}\gets`$ $`{}\gets`$ $`x %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
16`$ $`{}\gets`$ $`x \bmod 16`$ $`{}\gets`$ $`{}\gets`$ $`x %
  \nonscript\mskip-\medmuskip\mkern 5mu%
  \mathbin{\operator@font div}\penalty 900\mkern 5mu%
  \nonscript\mskip-\medmuskip
16`$ $`{}\gets`$ $`x \bmod 16`$

$`p.qmap_i \gets`$

$`p.qtab \gets`$ $`p.qtab_i \gets i`$

$`p.ptab \gets`$

$`p.dtab \gets`$

$`p`$

</div>

<span class="smallcaps">FQZCreateModels</span> creates the decoder
models based on the above parameters and the shared range coder.

<div class="program">

<div class="algorithmic">

$`rc \gets`$ $`model\_len_i \gets`$ $`model\_qual_i \gets`$
$`model\_dup \gets`$ $`model\_rev \gets`$ $`model\_sel \gets`$

</div>

</div>

<span class="smallcaps">ReadArray</span> reads an array $`A`$ of size
$`n`$ which maps values 0 to $`n-1`$ to a smaller range (0 to $`m-1`$),
both monotonically increasing. For efficiency this is done using a
two-level run length encoding.

Assuming $`m < n`$ there will be runs of the same value. We measure run
lengths for all values (even if they are zero). For example an array
$`A = \{0,1,3,4,5,6,7,7,7,7\}`$ may be converted to run lengths $`R =
\{1,1,0,1,1,1,1,4\}`$. To keep values in this array fitting within one
byte, long runs are broken down in a successive series of 255 values, so
a run of length 600 becomes 255 255 90.

This array $`R`$ is no longer monotonically increasing but may still
have repeated values, so is run-length encoded by storing the number of
additional values whenever the last two lengths match. This converts
$`R`$ to $`R2 = \{1, 1, +0, 0, 1, 1, +2, 4\}`$ where the '+' symbol is
shown purely to indicate the values representing the additional
run-length copy numbers. (This also now turns the example run of 600
above into 255 255 0 90.)

The final array $`R2`$ is the stored data stream. The decoder process is
the reverse of the above, starting by converting $`R2`$ to $`R`$ and
then $`A`$. The following pseudocode demonstrates this process.

<div class="algorithmic">

$`i,j,z \gets 0`$ $`last \gets -1`$ $`run \gets`$ $`R_j \gets run`$
$`j \gets j+1`$ $`z \gets z + run`$ $`copy \gets`$ $`R_j \gets run`$
$`j \gets j+1`$ $`z \gets z + run \times copy`$ $`last \gets run`$
$`i,j,z \gets 0`$ $`run\_len \gets 0`$ $`part \gets R_j`$
$`j \gets j + 1`$ $`run\_len \gets run\_len + part`$ $`A_z \gets i`$
$`z \gets z+1`$ $`i \gets i+1`$ $`A`$

</div>

The FQZComp main loop decodes data in the following order per read: read
length (if not fixed), the flag for whether this is read 2 (if needed),
a bit flag to indicate if the quality is duplicated (if needed),
followed by record length number of quality values using various data
gathered since the start of this read as context.

The output of this function is an array of quality values in the
variable $`output`$, indexed with the $`i^{th}`$ value via $`output_i`$.
The output buffer is a concatenation of all quality values for each
record. The record lengths are recorded, but note this is the number of
qualities encoded in CRAM for this sequence record and this does not
necessarily have to match the number of base calls (for example where
qualities are explicitly specified for SNP bases but not elsewhere).

<div class="algorithmic">

$`sel \gets 0`$ $`x \gets 0`$ $`sel \gets model\_sel.`$
$`x \gets stab_{sel}`$ $`param \gets params_x`$

$`rec\_len \gets`$ $`param.last\_len \gets rec\_len`$
$`param.first\_len = 0`$ $`rec\_len \gets param.last\_len`$
$`pos \gets rec\_len`$

$`rev_{rec} \gets model\_rev.`$ $`len_{rec} \gets rec\_len`$
$`rec \gets rec+1`$

$`is\_dup \gets 0`$ $`is\_dup \gets 1`$ $`qctx \gets 0`$
$`delta \gets 0`$ $`prevq \gets 0`$ $`x`$

</div>

<div class="algorithmic">

$`buf\_len \gets`$ $`i \gets 0`$ $`pos \gets 0`$ `next_record:`
$`x \gets`$ $`output_{i+j} \gets output_{i+j-rec\_len}`$
$`i \gets i+rec\_len`$ $`pos \gets 0`$

$`param \gets params_x`$ $`ctx \gets param.context`$
$`q \gets model\_qual_{ctx}.`$ $`output_i \gets qmap_q`$
$`output_i \gets q`$ $`ctx \gets`$ $`i \gets i + 1`$
$`pos \gets pos - 1`$

</div>

Read lengths are encoded as 4 8-bit bytes, each having its own model.

<div class="algorithmic">

$`rec\_len \gets model\_len_0.`$
$`rec\_len \gets rec\_len + (model\_len_1.`$$`\mathbin{<\mkern-3mu<\,}8)`$
$`rec\_len \gets rec\_len + (model\_len_2.`$$`\mathbin{<\mkern-3mu<\,}16)`$
$`rec\_len \gets rec\_len + (model\_len_3.`$$`\mathbin{<\mkern-3mu<\,}24)`$
$`rec\_len`$

</div>

For CRAM v4.0 quality values are stored in their original FASTQ
orientation. For CRAM v3.1 they are stored in their alignment
orientation and it may be beneficial for compression purposes to reverse
them first. If so $`do\_rev`$ will be set and the
<span class="smallcaps">ReverseQualities</span> procedure called below
after decoding.

<div class="algorithmic">

$`rec \gets 0`$ $`i \gets 0`$ $`j \gets 0`$ $`k \gets len_{rec}-1`$
$`j \gets j+1`$ $`k \gets k-1`$ $`i \gets i + len_{rec}`$
$`rec \gets rec+1`$

</div>

[^1]: J. Duda, *Asymmetric numeral systems: entropy coding combining
    speed of Huffman coding with compression rate of arithmetic coding*,
    <http://arxiv.org/abs/1311.2540>

[^2]: C.E. Shannon, *A Mathematical Theory of Communication*, Bell
    System Technical Journal, vol. 27, pp. 379-423, 623-656, July,
    October, 1948

[^3]: While the maths work fine up to 4096, for historical reasons this
    has always been documented as having a limit of 4095.
    Implementations may wish to validate decoding on $`<= 4096`$, but we
    recommend they use a limit of 4095 in their encoding output.

[^4]: F. Giesen, *Interleaved entropy coders*,
    <http://arxiv.org/abs/1402.3392>

[^5]: This was why the '\0' $`\to`$ 'a' context in the example above had
    a frequency of 4 instead of 1.

[^6]: This implementation was designed by Eugene Shelwein, based on
    Michael Schindler's earlier work.

[^7]: For simplicity of algorithm description, we take a flexible
    approach as to whether we read/write $`T`$ in numeric or string
    form. For example a `DELTA` token will fetch the previous token as a
    string, interpret it as a numeric value, add to it, and then write
    it back as a string. Practical implementations may wish to separate
    out T into distinct integer and string arrays.

[^8]: For example if we have 4 quality values in use – 0, 10, 25 and 35
    – we will be encoding quality values 0, 1, 2 and 3. We may wish to
    define $`qbits`$ to be 6 and $`qshift`$ to be 2 such that the
    previous 3 quality values can be used as context, for the prediction
    of the next quality value. There will likely be little reason to use
    $`qtab`$ in this scenario, but an encoder could define $`qtab`$ to
    convert {0, 1, 2, 3} to {0, 0, 0, 1} and use $`qshift`$ of 1
    instead, giving us knowledge of which of the previous 6 values were
    maximum quality.