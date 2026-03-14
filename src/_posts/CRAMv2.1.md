---
title: "CRAM format specification (version 2.1)"
commit: 703ef9b
date: 2 Feb 2023
---

This printing is version 703ef9b from the [hts-specs](https://github.com/samtools/hts-specs) repository, last modified on 2 Feb 2023.


This specification describes the CRAM 2.1 format.

CRAM has the following major objectives:

1.  Significantly better lossless compression than BAM

2.  Full compatibility with BAM

3.  Effortless transition to CRAM from using BAM files

4.  Support for controlled loss of BAM data

The first three objectives allow users to take immediate advantage of
the CRAM format while offering a smooth transition path from using BAM
files. The fourth objective supports the exploration of different lossy
compression strategies and provides a framework in which to effect these
choices. Please note that the CRAM format does not impose any rules
about what data should or should not be preserved. Instead, CRAM
supports a wide range of lossless and lossy data preservation strategies
enabling users to choose which data should be preserved.

Data in CRAM is stored either as CRAM records or using one of the
general purpose compressors (gzip, bzip2). CRAM records are compressed
using a number of different encoding strategies. For example, bases are
reference compressed by encoding base differences rather than storing
the bases themselves.[^1]

# 2 **Data types** <a href="#data-types" class="header-anchor">#</a>

CRAM specification uses logical data types and storage data types;
logical data types are written as words (e.g. int) while physical data
types are written using single letters (e.g. i). The difference between
the two is that storage data types define how logical data types are
stored in CRAM. Data in CRAM is stored either as as bits or as bytes.
Writing values as bits and bytes is described in detail below.

## 2.1 **Logical data types** <a href="#logical-data-types" class="header-anchor">#</a>

Byte  
 \
Signed byte (8 bits).

Integer  
 \
Signed 32-bit integer.

Long  
 \
Signed 64-bit integer.

Array  
 \
An array of any logical data type: `<`type`>`\[ \]

## 2.2 **Writing bits to a bit stream** <a href="#writing-bits-to-a-bit-stream" class="header-anchor">#</a>

A bit stream consists of a sequence of 1s and 0s. The bits are written
most significant bit first where new bits are stacked to the right and
full bytes on the left are written out. In a bit stream the last byte
will be incomplete if less than 8 bits have been written to it. In this
case the bits in the last byte are shifted to the left.

### 2.2.1 Example of writing to bit stream <a href="#example-of-writing-to-bit-stream" class="header-anchor">#</a>

Let's consider the following example. The table below shows a sequence
of write operations:

<table>
<thead>
<tr>
<th><strong>Operation order</strong></th>
<th><strong>Buffer state before</strong></th>
<th><strong>Written bits</strong></th>
<th><strong>Buffer state after</strong></th>
<th><strong>Issued bytes</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>0x0</td>
<td>1</td>
<td>0x1</td>
<td>-</td>
</tr>
<tr>
<td>2</td>
<td>0x1</td>
<td>0</td>
<td>0x2</td>
<td>-</td>
</tr>
<tr>
<td>3</td>
<td>0x2</td>
<td>11</td>
<td>0xB</td>
<td>-</td>
</tr>
<tr>
<td>4</td>
<td>0xB</td>
<td>0000 0111</td>
<td>0x7</td>
<td>0xB0</td>
</tr>
</tbody>
</table>

After flushing the above bit stream the following bytes are written:
0xB0 0x70. Please note that the last byte was 0x7 before shifting to the
left and became 0x70 after that:

`> echo "obase=16; ibase=2; 00000111" bc`\
`7`\
\
`> echo "obase=16; ibase=2; 01110000" bc`\
`70`

And the whole bit sequence:

`> echo "obase=2; ibase=16; B070" bc`\
`1011000001110000`

When reading the bits from the bit sequence it must be known that only
12 bits are meaningful and the bit stream should not be read after that.

### 2.2.2 Note on writing to bit stream <a href="#note-on-writing-to-bit-stream" class="header-anchor">#</a>

When writing to a bit stream both the value and the number of bits in
the value must be known. This is because programming languages normally
operate with bytes (8 bits) and to specify which bits are to be written
requires a bit-holder, for example an integer, and the number of bits in
it. Equally, when reading a value from a bit stream the number of bits
must be known in advance. In case of prefix codes (e.g. Huffman) all
possible bit combinations are either known in advance or it is possible
to calculate how many bits will follow based on the first few bits.
Alternatively, two codes can be combined, where the first contains the
number of bits to read.

## 2.3 **Writing bytes to a byte stream** <a href="#writing-bytes-to-a-byte-stream" class="header-anchor">#</a>

The interpretation of byte stream is straightforward. CRAM uses *little
endianness* for bytes when applicable and defines the following storage
data types:

Boolean (bool)  
 \
Boolean is written as 1-byte with 0x0 being 'false' and 0x1 being
'true'.

Integer (int32)  
 \
Signed 32-bit integer, written as 4 bytes in little-endian byte order.

Long (int64)  
 \
Signed 64-bit integer, written as 8 bytes in little-endian byte order.

ITF-8 integer (itf8)  
 \
This is an alternative way to write an integer value. The idea is
similar to UTF-8 encoding and therefore this encoding is called ITF-8
(Integer Transformation Format - 8 bit).

The most significant bits of the first byte have special meaning and are
called 'prefix'. These are 0 to 4 true bits followed by a 0. The number
of 1's denote the number of bytes the follow. To accommodate 32 bits
such representation requires 5 bytes with only 4 lower bits used in the
last byte 5.

LTF-8 long or (ltf8)  
 \
See ITF-8 for more details. The only difference between ITF-8 and LTF-8
is the number of bytes used to encode a single value. To do so 64 bits
are required and this can be done with 9 byte at most with the first
byte consisting of just 1s or 0xFF value.

Array (\[ \])  
 \
Array length is written first as integer (itf8), followed by the
elements of the array.

### 2.3.1 Encoding <a href="#encoding" class="header-anchor">#</a>

Encoding is a data type that specifies how data series have been
compressed. Encodings are defined as encoding`<`type`>` where the type
is a logical data type as opposed to a storage data type.

An encoding is written as follows. The first integer (itf8) denotes the
codec id and the second integer (itf8) the number of bytes in the
following encoding-specific values.

Subexponential encoding example:

<table>
<thead>
<tr>
<th><strong>Value</strong></th>
<th><strong>Type</strong></th>
<th><strong>Name</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>0x7</td>
<td>itf8</td>
<td>codec id</td>
</tr>
<tr>
<td>0x2</td>
<td>itf8</td>
<td>number of bytes to follow</td>
</tr>
<tr>
<td>0x0</td>
<td>itf8</td>
<td>offset</td>
</tr>
<tr>
<td>0x1</td>
<td>itf8</td>
<td>K parameter</td>
</tr>
</tbody>
</table>

The first byte "0x7" is the codec id.

The second 4 bytes "0x0 0x0 0x0 0xD" denote the length of the bytes to
follow (13).

The subexponential encoding has 3 parameters: integer (itf8) K, int
(itf8) offset and boolean (bool) unary bit:

K = 0x1 = 1

offset = 0x0 = 0

### 2.3.2 Map <a href="#map" class="header-anchor">#</a>

A map is a collection of keys and associated values. A map with N keys
is written as follows:

<table>
<thead>
<tr>
<th>size in bytes</th>
<th>N</th>
<th>key 1</th>
<th>value 1</th>
<th>key ...</th>
<th>value ...</th>
<th>key N</th>
<th>value N</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Both the size in bytes and the number of keys are written as integer
(itf8). Keys and values are written according to their data types and
are specific to each map.

## 2.4 **Strings** <a href="#strings" class="header-anchor">#</a>

Strings are represented as byte arrays using UTF-8 format. Read names,
reference sequence names and tag values with type 'Z' are stored as
UTF-8.

# 3 **Encodings**  <a href="#encodings" class="header-anchor">#</a>

Encoding is a data structure that captures information about compression
details of a data series that are required to uncompress it. This could
be a set of constants required to initialize a specific decompression
algorithm or statistical properties of a data series or, in case of data
series being stored in an external block, the block content id.

Encoding notation is defined as the keyword 'encoding' followed by its
data type in angular brackets, for example 'encoding`<`byte`>`' stands
for an encoding that operates on a data series of data type 'byte'.

Encodings may have parameters of different data types, for example the
external encoding has only one parameter, integer id of the external
block. The following encodings are defined:

<table>
<thead>
<tr>
<th><strong>Codec</strong></th>
<th><strong>ID</strong></th>
<th><strong>Parameters</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>NULL</td>
<td>0</td>
<td>none</td>
<td>series not preserved</td>
</tr>
<tr>
<td>EXTERNAL</td>
<td>1</td>
<td>int block content id</td>
<td>the block content identifier used to associate external data blocks with
data series</td>
</tr>
<tr>
<td>GOLOMB</td>
<td>2</td>
<td>int offset, int M</td>
<td>Golomb coding</td>
</tr>
<tr>
<td>HUFFMAN_INT</td>
<td>3</td>
<td>int array, int array</td>
<td>coding with int values</td>
</tr>
<tr>
<td>BYTE_ARRAY_LEN</td>
<td>4</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code> array length,
encoding<code>&lt;</code>byte<code>&gt;</code> bytes</td>
<td>coding of byte arrays with array length</td>
</tr>
<tr>
<td>BYTE_ARRAY_STOP</td>
<td>5</td>
<td>byte stop, int external block content id</td>
<td>coding of byte arrays with a stop value</td>
</tr>
<tr>
<td>BETA</td>
<td>6</td>
<td>int offset, int number of bits</td>
<td>binary coding</td>
</tr>
<tr>
<td>SUBEXP</td>
<td>7</td>
<td>int offset, int K</td>
<td>subexponential coding</td>
</tr>
<tr>
<td>GOLOMB_RICE</td>
<td>8</td>
<td>int offset, int log2m</td>
<td>Golomb-Rice coding</td>
</tr>
<tr>
<td>GAMMA</td>
<td>9</td>
<td>int offset</td>
<td>Elias gamma coding</td>
</tr>
</tbody>
</table>

See the later **Encodings** sections for more detailed descriptions of
all the above coding algorithms and their parameters.

# 4 **File structure** <a href="#file-structure" class="header-anchor">#</a>

The overall CRAM file structure is described in this section. Please
refer to other sections of this document for more detailed information.

A CRAM file starts with a fixed length file definition followed by one
or more containers. The BAM header is stored in the first container.

<img src="/hts-specs-md/img/CRAMFileFormat2-1-fig001.png"
style="width:356pt;height:31pt" alt="image" />

Pic.1 CRAM file starts with a file definition followed by the BAM header
and other containers.

Containers consist of one or more blocks. By convention, the BAM header
is stored in the first container within a single block. This is known as
the BAM header block.

<img src="/hts-specs-md/img/CRAMFileFormat2-1-fig002.png"
style="width:354pt;height:103pt" alt="image" />

Pic.2 The BAM header is stored in the first container.

Each container starts with a container header followed by one or more
blocks. Each block starts with a block header. All data in CRAM is
stored within blocks after the block header.

<img src="/hts-specs-md/img/CRAMFileFormat2-1-fig003.png"
style="width:356pt;height:154pt" alt="image" />

Pic.3 Container and block structure. All data in CRAM files is stored in
blocks.

The first block in each container is the compression header block:

<img src="/hts-specs-md/img/CRAMFileFormat2-1-fig004.png"
style="width:354pt;height:103pt" alt="image" />

Pic.4 Compression header is the first block in the container.

The blocks after the compression header are organised logically into
slices. One slice may contain, for example, a contiguous region of
alignment data. Slices begin with a slice header block and are followed
by one or more data blocks:

<img src="/hts-specs-md/img/CRAMFileFormat2-1-fig005.png"
style="width:374pt;height:137pt" alt="image" />

Pic.5 Containers are logically organised into slices.

Data blocks are divided into core and external data blocks. Each slice
must have at least one core data block immediately after the slice
header block. The core data block may be followed by one or more
external data blocks.

<img src="/hts-specs-md/img/CRAMFileFormat2-1-fig006.png"
style="width:392pt;height:149pt" alt="image" />

Pic.5 Data blocks are divided into core and external data blocks.

# 5 **File definition** <a href="#file-definition" class="header-anchor">#</a>

Each CRAM file starts with a fixed length (26 bytes) definition with the
following fields:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>byte[4]</td>
<td>format magic number</td>
<td>CRAM (0x43 0x52 0x41 0x4d)</td>
</tr>
<tr>
<td>unsigned byte</td>
<td>major format number</td>
<td>2 (0x2)</td>
</tr>
<tr>
<td>unsigned byte</td>
<td>minor format number</td>
<td>1 (0x1)</td>
</tr>
<tr>
<td>byte[20]</td>
<td>file id</td>
<td>CRAM file identifier (e.g. file name or SHA1 checksum)</td>
</tr>
</tbody>
</table>

Valid CRAM *major*.*minor* version numbers are as follows:

- The original public CRAM release.

- The first CRAM release implemented in both Java and C; tidied up
  implementation vs specification differences in *1.0*.

- Gained end of file markers; compatible with *2.0*.

- Additional compression methods; header and data checksums;
  improvements for unsorted data.

# 6 **Container structure** <a href="#container-structure" class="header-anchor">#</a>

The file definition is followed by one or more containers with the
following header structure where the container content is stored in the
'blocks' field:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>int32</td>
<td>length</td>
<td>byte size of the container data (blocks)</td>
</tr>
<tr>
<td>itf8</td>
<td>reference sequence id</td>
<td>reference sequence identifier or -1 for unmapped reads -2 for multiple
reference sequences</td>
</tr>
<tr>
<td>itf8</td>
<td>starting position on the reference</td>
<td>the alignment start position or 0 for unmapped reads</td>
</tr>
<tr>
<td>itf8</td>
<td>alignment span</td>
<td>the length of the alignment or 0 for unmapped reads</td>
</tr>
<tr>
<td>itf8</td>
<td>number of records</td>
<td>number of records in the container</td>
</tr>
<tr>
<td>itf8</td>
<td>record counter</td>
<td>1-based sequential index of records in the file/stream.</td>
</tr>
<tr>
<td>ltf8</td>
<td>bases</td>
<td>number of read bases</td>
</tr>
<tr>
<td>itf8</td>
<td>number of blocks</td>
<td>the number of blocks</td>
</tr>
<tr>
<td>itf8[ ]</td>
<td>landmarks</td>
<td>Each integer value of this array is a byte offset into the blocks byte
array. Landmarks are used for random access indexing.</td>
</tr>
<tr>
<td>byte[ ]</td>
<td>blocks</td>
<td>The blocks contained within the container.</td>
</tr>
</tbody>
</table>

## 6.1 **CRAM header in the first container** <a href="#cram-header-in-the-first-container"
class="header-anchor">#</a>

The first container in the CRAM file contains the BAM header in an
uncompressed block. BAM header is terminated with \0 byte and any extra
bytes in the block can be used to expand the BAM header. For example
when updating @SQ records additional space may be required for the BAM
header. It is recommended to reserve 50% more space in the CRAM header
block than it is required by the BAM header.

# 7 **Block structure** <a href="#block-structure" class="header-anchor">#</a>

Containers consist of one or more blocks. Block compression is applied
independently and in addition to any encodings used to compress data
within the block. The block have the following header structure with the
data stored in the 'block data' field:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>byte</td>
<td>method</td>
<td>the block compression method: 0: raw (none)* 1: gzip 2: bzip2</td>
</tr>
<tr>
<td>byte</td>
<td>block content type id</td>
<td>the block content type identifier</td>
</tr>
<tr>
<td>itf8</td>
<td>block content id</td>
<td>the block content identifier used to associate external data blocks with
data series</td>
</tr>
<tr>
<td>itf8</td>
<td>size in bytes*</td>
<td>size of the block data after applying block compression</td>
</tr>
<tr>
<td>itf8</td>
<td>raw size in bytes*</td>
<td>size of the block data before applying block compression</td>
</tr>
<tr>
<td>byte[ ]</td>
<td>block data</td>
<td>the data stored in the block:
<math display="inline" xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mi>•</mi><annotation encoding="application/x-tex">\bullet</annotation></semantics></math>
bit stream of CRAM records (core data block)
<math display="inline" xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mi>•</mi><annotation encoding="application/x-tex">\bullet</annotation></semantics></math>
byte stream (external data block)
<math display="inline" xmlns="http://www.w3.org/1998/Math/MathML"><semantics><mi>•</mi><annotation encoding="application/x-tex">\bullet</annotation></semantics></math>
additional fields ( header blocks)</td>
</tr>
</tbody>
</table>

\* Note on raw method: both compressed and raw sizes must be set to the
same value.

## 7.1 **Block content types** <a href="#block-content-types" class="header-anchor">#</a>

CRAM has the following block content types:

<table>
<thead>
<tr>
<th><strong>Block content type</strong></th>
<th><strong>Block content type id</strong></th>
<th><strong>Name</strong></th>
<th><strong>Contents</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>FILE_HEADER</td>
<td>0</td>
<td>BAM header block</td>
<td>BAM header</td>
</tr>
<tr>
<td>COMPRESSION_HEADER</td>
<td>1</td>
<td>Compression header block</td>
<td>See specific section</td>
</tr>
<tr>
<td>MAPPED_SLICE_HEADER</td>
<td>2</td>
<td>Slice header block</td>
<td>See specific section</td>
</tr>
<tr>
<td></td>
<td>3</td>
<td></td>
<td>reserved</td>
</tr>
<tr>
<td>EXTERNAL_DATA</td>
<td>4</td>
<td>external data block</td>
<td>data produced by external encodings</td>
</tr>
<tr>
<td>CORE_DATA</td>
<td>5</td>
<td>core data block</td>
<td>bit stream of all encodings except for external</td>
</tr>
</tbody>
</table>

## 7.2 **Block content id** <a href="#block-content-id" class="header-anchor">#</a>

Block content id is used to distinguish between external blocks in the
same slice. Each external encoding has an id parameter which must be one
of the external block content ids. For external blocks the content id is
a positive integer. For all other blocks content id should be 0.
Consequently, all external encodings must not use content id less than
1.

### 7.2.1 Data blocks <a href="#data-blocks" class="header-anchor">#</a>

Data is stored in data blocks. There are two types of data blocks: core
data blocks and external data blocks.The difference between core and
external data blocks is that core data blocks consist of data series
that are compressed using bit encodings while the external data blocks
are byte compressed. One core data block and any number of external data
blocks are associated with each slice.

Writing to and reading from core and external data blocks is organised
through CRAM records. Each data series is associated with an encoding.
In case of external encoding the block content id is used to identify
the block where the data series is stored. Please note that external
blocks can have multiple data series associated with them; in this case
the values from these data series will be interleaved.

## 7.3 **BAM header block** <a href="#bam-header-block" class="header-anchor">#</a>

The BAM header is stored in a single block within the first container.

The following constraints apply to the BAM header:

- The SQ:MD5 checksum is required unless the reference sequence has been
  embedded into the file.

- At least one RG record is required.

- The HD:SO sort order is always POS.

## 7.4 **Compression header block** <a href="#compression-header-block" class="header-anchor">#</a>

The compression header block consists of 3 parts: preservation map, data
series encoding map and tag encoding map.

### 7.4.1 Preservation map <a href="#preservation-map" class="header-anchor">#</a>

The preservation map contains information about which data was preserved
in the CRAM file. It is stored as a map with byte\[2\] keys:

<table>
<thead>
<tr>
<th><strong>Key</strong></th>
<th><strong>Value data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>RN</td>
<td>bool</td>
<td>read names included</td>
<td>true if read names are preserved for all reads</td>
</tr>
<tr>
<td>AP</td>
<td>bool</td>
<td>AP data series delta</td>
<td>true if AP data series is delta, false otherwise</td>
</tr>
<tr>
<td>RR</td>
<td>bool</td>
<td>reference required</td>
<td>true if reference sequence is required to restore the data completely</td>
</tr>
<tr>
<td>SM</td>
<td>byte[5]</td>
<td>substitution matrix</td>
<td>substitution matrix</td>
</tr>
<tr>
<td>TD</td>
<td>byte[ ]</td>
<td>tag ids dictionary</td>
<td>a list of lists of tag ids, see tag encoding section</td>
</tr>
</tbody>
</table>

### 7.4.2 Data series encodings <a href="#data-series-encodings" class="header-anchor">#</a>

Each data series has an encoding. These encoding are stored in a map
with byte\[2\] keys:

<table>
<thead>
<tr>
<th><strong>Key</strong></th>
<th><strong>Value data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>BF</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>bit flags</td>
<td>see separate section</td>
</tr>
<tr>
<td>AP</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>in-seq positions</td>
<td>0-based alignment start delta from previous record *</td>
</tr>
<tr>
<td>FP</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>in-read positions</td>
<td>positions of the read features</td>
</tr>
<tr>
<td>RL</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>read lengths</td>
<td>read lengths</td>
</tr>
<tr>
<td>DL</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>deletion lengths</td>
<td>base-pair deletion lengths</td>
</tr>
<tr>
<td>NF</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>distance to next fragment</td>
<td>number of records to the next fragment*</td>
</tr>
<tr>
<td>BA</td>
<td>encoding<code>&lt;</code>byte<code>&gt;</code></td>
<td>bases</td>
<td>bases</td>
</tr>
<tr>
<td>QS</td>
<td>encoding<code>&lt;</code>byte<code>&gt;</code></td>
<td>quality scores</td>
<td>quality scores</td>
</tr>
<tr>
<td>FC</td>
<td>encoding<code>&lt;</code>byte<code>&gt;</code></td>
<td>read features codes</td>
<td>see separate section</td>
</tr>
<tr>
<td>FN</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>number of read features</td>
<td>number of read features in each record</td>
</tr>
<tr>
<td>BS</td>
<td>encoding<code>&lt;</code>byte<code>&gt;</code></td>
<td>base substitution codes</td>
<td>base substitution codes</td>
</tr>
<tr>
<td>IN</td>
<td>encoding<code>&lt;</code>byte[ ]<code>&gt;</code></td>
<td>insertion</td>
<td>inserted bases</td>
</tr>
<tr>
<td>RG</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>read groups</td>
<td>read groups. Special value '-1' stands for no group.</td>
</tr>
<tr>
<td>MQ</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>mapping qualities</td>
<td>mapping quality scores</td>
</tr>
<tr>
<td>TL</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>tag ids</td>
<td>list of tag ids, see tag encoding section</td>
</tr>
<tr>
<td>RN</td>
<td>encoding<code>&lt;</code>byte[ ]<code>&gt;</code></td>
<td>read names</td>
<td>read names</td>
</tr>
<tr>
<td>NS</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>next fragment reference sequence id</td>
<td>reference sequence ids for the next fragment</td>
</tr>
<tr>
<td>NP</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>next mate alignment start</td>
<td>alignment positions for the next fragment</td>
</tr>
<tr>
<td>TS</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>template size</td>
<td>template sizes</td>
</tr>
<tr>
<td>MF</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>next mate bit flags</td>
<td>see specific section</td>
</tr>
<tr>
<td>CF</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>compression bit flags</td>
<td>see specific section</td>
</tr>
<tr>
<td>TM</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>test mark</td>
<td>a prefix expected before every record, for debugging purposes.</td>
</tr>
<tr>
<td>RI</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>reference id</td>
<td>record reference id from the BAM file header</td>
</tr>
<tr>
<td>RS</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>reference skip length</td>
<td>number of skipped bases for the 'N' read feature</td>
</tr>
<tr>
<td>PD</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>padding</td>
<td>number of padded bases</td>
</tr>
<tr>
<td>HC</td>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>hard clip</td>
<td>number of hard clipped bases</td>
</tr>
<tr>
<td>SC</td>
<td>encoding<code>&lt;</code>byte[ ]<code>&gt;</code></td>
<td>soft clip</td>
<td>soft clipped bases</td>
</tr>
</tbody>
</table>

\* The data series is reset for each slice.

### 7.4.3 Encoding tags <a href="#encoding-tags" class="header-anchor">#</a>

The TL (tag list) data series represents combined information about the
number of tags in a record and their ids.

Let $L_{i}=\{T_{i0}, T_{i1}, \ldots, T_{ix}\}$ be sorted list of all tag
ids for a record $R_{i}$, where $i$ is the sequential record index and
$T_{ij}$ denotes $j$-th tag id in the record. We recommend alphabetical
sort order. The list of unique $L_{i}$ is assigned sequential integer
numbers starting with 0. These integer numbers represent the TL data
series. The sorted list of unique $L_{i}$ is stored as the TD value in
the preservation map. Using TD, an integer from the TL data series can
be mapped back into a list of tag ids.

The TD is written as byte array consisting of $L_{i}$ values separated
with \0. Each $L_{i}$ value is written as a sequence of 3 bytes: tag id
followed by tag value type. For example AMiOQZ\0OQZ\0, where the TD
consists of just two values: integer 0 for tags {AM:i,OQ:Z} and 1 for
tag {OQ:Z}.

### 7.4.4 Encoding tag values <a href="#encoding-tag-values" class="header-anchor">#</a>

The encodings used for different tags are stored in a map. The map has
integer keys composed of the two letter tag abbreviation followed by the
tag type as defined in the SAM specification, for example 'OQZ' for
'OQ:Z'. The three bytes form a big endian integer and are written as
ITF8. For example, 3-byte representation of OQ:Z is {0x4F, 0x51, 0x5A}
and these bytes are interpreted as the integer 0x004F515A. The integer
is finally written as ITF8.

<table>
<thead>
<tr>
<th><strong>Key</strong></th>
<th><strong>Value data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>TAG NAME 1:TAG TYPE 1</td>
<td>encoding<code>&lt;</code>byte[ ]<code>&gt;</code></td>
<td>read tag 1</td>
<td>tag values (names and types are available in the data series code)</td>
</tr>
<tr>
<td>...</td>
<td></td>
<td>...</td>
<td>...</td>
</tr>
<tr>
<td>TAG NAME N:TAG TYPE N</td>
<td>encoding<code>&lt;</code>byte[ ]<code>&gt;</code></td>
<td>read tag N</td>
<td>...</td>
</tr>
</tbody>
</table>

Note that tag values are encoded as array of bytes. The routines to
convert tag values into byte array and back are the same as in BAM with
the exception of value type being captured in the tag key rather in the
value.

## 7.5 **Slice header block** <a href="#slice-header-block" class="header-anchor">#</a>

The slice header block is never compressed (block method=raw). For
reference mapped reads the slice header also defines the reference
sequence context of the data blocks associated with the slice. Mapped
and unmapped reads can be stored within the same slice similarly to BAM
file. Slices with unsorted reads must not contain any other types of
reads.

The slice header block contains the following fields.

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>itf8</td>
<td>reference sequence id</td>
<td>reference sequence identifier or -1 for unmapped or unsorted reads</td>
</tr>
<tr>
<td>itf8</td>
<td>alignment start</td>
<td>the alignment start position or -1 for unmapped or unsorted reads</td>
</tr>
<tr>
<td>itf8</td>
<td>alignment span</td>
<td>the length of the alignment or 0 for unmapped or unsorted reads</td>
</tr>
<tr>
<td>itf8</td>
<td>number of records</td>
<td>the number of records in the slice</td>
</tr>
<tr>
<td>ltf8</td>
<td>record counter</td>
<td>1-based sequential index of records in the file/stream</td>
</tr>
<tr>
<td>itf8</td>
<td>number of blocks</td>
<td>the number of blocks in the slice</td>
</tr>
<tr>
<td>itf8[ ]</td>
<td>block content ids</td>
<td>block content ids of the blocks in the slice</td>
</tr>
<tr>
<td>itf8</td>
<td>embedded reference bases block content id</td>
<td>block content id for the embedded reference sequence bases or -1 for
none</td>
</tr>
<tr>
<td>byte[16]</td>
<td>reference md5</td>
<td>MD5 checksum of the reference bases within the slice boundaries or 16 \0
bytes for unmapped or unsorted reads</td>
</tr>
</tbody>
</table>

## 7.6 **Core data block** <a href="#core-data-block" class="header-anchor">#</a>

A core data block is a bit stream (most significant bit first)
consisting of one or more CRAM records. Please note that one byte could
hold more then one CRAM record as a minimal CRAM record could be just a
few bits long. The core data block has the following fields:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Value</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>bit[ ]</td>
<td>CRAM record 1</td>
<td>The first CRAM record</td>
</tr>
<tr>
<td>...</td>
<td>...</td>
<td>...</td>
</tr>
<tr>
<td>bit[ ]</td>
<td>CRAM record N</td>
<td>The Nth CRAM record</td>
</tr>
</tbody>
</table>

## 7.7 **External data block** <a href="#external-data-block" class="header-anchor">#</a>

Relationship between core data block and external data blocks is shown
in the following picture:

<img src="/hts-specs-md/img/CRAMFileFormat2-1-fig007.png"
style="width:451pt;height:350pt" alt="image" />

Pic.3 Relationship between core data block and external data blocks.

The picture shows how a CRAM record (on the left) is partially written
to core data block while the other fields are stored in two external
data blocks. The specific encodings are presented only for demonstration
purposes, the main point here is to distinguish between bit encodings
whose output is always stored in core data block and the external
encoding which simply stored the bytes into external data blocks.

# 8 **End of file marker** <a href="#end-of-file-marker" class="header-anchor">#</a>

A special container is used to mark the end of a file or stream. It is
optional in version preceding 2.1 but required in later versions. The
idea is to provide an easy and a quick way to detect that a CRAM file or
stream is complete. The marker is basically an empty container with ref
seq id set to -1 (unaligned) and alignment start set to 4542278.

Here is a complete content of the EOF container explained in detail:

<table>
<thead>
<tr>
<th><strong>hex bytes</strong></th>
<th><strong>data type</strong></th>
<th><strong>decimal value</strong></th>
<th><strong>field name</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td><em>Container header</em></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>0b 00 00 00</td>
<td>integer</td>
<td>11</td>
<td>size of blocks data</td>
</tr>
<tr>
<td>ff ff ff ff ff</td>
<td>itf8</td>
<td>-1</td>
<td>ref seq id</td>
</tr>
<tr>
<td>e0 45 4f 46</td>
<td>itf8</td>
<td>4542278</td>
<td>alignment start</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>alignment span</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>nof records</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>global record counter</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>bases</td>
</tr>
<tr>
<td>01</td>
<td>itf8</td>
<td>1</td>
<td>block count</td>
</tr>
<tr>
<td>00</td>
<td>array</td>
<td>0</td>
<td>landmarks</td>
</tr>
<tr>
<td><em>Compression header block</em></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>00</td>
<td>byte</td>
<td>0 (RAW)</td>
<td>compression method</td>
</tr>
<tr>
<td>01</td>
<td>byte</td>
<td>1 (COMPRESSION_HEADER)</td>
<td>block content type</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>block content id</td>
</tr>
<tr>
<td>06</td>
<td>itf8</td>
<td>6</td>
<td>compressed size</td>
</tr>
<tr>
<td>06</td>
<td>itf8</td>
<td>6</td>
<td>uncompressed size</td>
</tr>
<tr>
<td><em>Compression header</em></td>
<td></td>
<td></td>
<td></td>
</tr>
<tr>
<td>01</td>
<td>itf8</td>
<td>1</td>
<td>preservation map byte size</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>preservation map size</td>
</tr>
<tr>
<td>01</td>
<td>itf8</td>
<td>1</td>
<td>encoding map byte size</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>encoding map size</td>
</tr>
<tr>
<td>01</td>
<td>itf8</td>
<td>1</td>
<td>tag encoding byte size</td>
</tr>
<tr>
<td>00</td>
<td>itf8</td>
<td>0</td>
<td>tag encoding map size</td>
</tr>
</tbody>
</table>

When compiled together the EOF marker is exactly 30 bytes long and in
hex representation is:

0b 00 00 00 ff ff ff ff ff e0 45 4f 46 00 00 00 00 01 00 00 01 00 06 06
01 00 01 00 01 00

# 9 **Record structure** <a href="#record-structure" class="header-anchor">#</a>

CRAM record is based on the SAM record but has additional features
allowing for more efficient data storage. In contrast to BAM record CRAM
record uses bits as well as bytes for data storage. This way, for
example, various coding techniques which output variable length binary
codes can be used directly in CRAM. On the other hand, data series that
do not require binary coding can be stored separately in external blocks
with some other compression applied to them independently.

## 9.1 **CRAM record** <a href="#cram-record" class="header-anchor">#</a>

Both mapped and unmapped reads start with the following fields. Please
note that the data series type refers to the logical data type and the
data series name corresponds to the data series encoding map.

<table>
<thead>
<tr>
<th></th>
<th><strong>Data series type</strong></th>
<th><strong>Data series name</strong></th>
<th><strong>Field</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>int</td>
<td>BF</td>
<td>CRAM bit flags</td>
<td>see CRAM record bit flags</td>
</tr>
<tr>
<td>2</td>
<td>int</td>
<td>CF</td>
<td>compression bit flags</td>
<td>see compression bit flags</td>
</tr>
<tr>
<td>3</td>
<td>int</td>
<td>RI</td>
<td>ref id</td>
<td>reference sequence id, not used for single reference slices, reserved
for future multiref slices.</td>
</tr>
<tr>
<td>4</td>
<td>int</td>
<td>RL</td>
<td>read length</td>
<td>the length of the read</td>
</tr>
<tr>
<td>5</td>
<td>int</td>
<td>AP</td>
<td>alignment start</td>
<td>the alignment start position *1</td>
</tr>
<tr>
<td>6</td>
<td>int</td>
<td>RG</td>
<td>read group</td>
<td>the read group identifier</td>
</tr>
<tr>
<td>7</td>
<td>byte</td>
<td>QS</td>
<td>quality scores</td>
<td>quality scores are stored depending on the value of the 'mapped QS
included' field</td>
</tr>
<tr>
<td>8</td>
<td>byte[ ]</td>
<td>RN</td>
<td>read name</td>
<td>the read names (if preserved)</td>
</tr>
<tr>
<td>9</td>
<td>*2</td>
<td>*2</td>
<td>mate record</td>
<td>*2 (if not the last record)</td>
</tr>
<tr>
<td>10</td>
<td>int</td>
<td>TL</td>
<td>tag ids</td>
<td>tag ids *3</td>
</tr>
<tr>
<td>11</td>
<td>byte[ ]</td>
<td>-</td>
<td>tag values</td>
<td>tag values *3</td>
</tr>
</tbody>
</table>

\*1 The AP data series is delta encoded for reads mapped to a single
reference slice and normal integer value in all other cases.

\*2 See **mate record** section.

\*3 See **tag encoding** section.

The CRAM record structure for mapped reads has the following additional
fields:

<table>
<thead>
<tr>
<th></th>
<th><strong>Data series type</strong></th>
<th><strong>Data series name</strong></th>
<th><strong>Field</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>*1</td>
<td>*1</td>
<td>read feature records</td>
<td>*1</td>
</tr>
<tr>
<td>2</td>
<td>byte</td>
<td>MQ</td>
<td>mapping quality</td>
<td>read mapping quality</td>
</tr>
</tbody>
</table>

\*1 See read feature record specification below.

The CRAM record structure for unmapped reads has the following
additional fields:

<table>
<thead>
<tr>
<th></th>
<th><strong>Data series type</strong></th>
<th><strong>Data series name</strong></th>
<th><strong>Field</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>byte[read length]</td>
<td>BA</td>
<td>bases</td>
<td>the read bases</td>
</tr>
</tbody>
</table>

## 9.2 **Read bases** <a href="#read-bases" class="header-anchor">#</a>

CRAM format supports ACGTN bases only. All non-ACGTN read bases must be
replaced with N (unknown) base. In case of mismatching non-ACGTN read
base and non-ACGTN reference base a ReadBase read feature should be used
to capture the fact that the read base should be restored as N base.

## 9.3 **CRAM record bit flags (BF data series)** <a href="#cram-record-bit-flags-bf-data-series"
class="header-anchor">#</a>

The following flags are defined for each CRAM read record:

<table>
<thead>
<tr>
<th><strong>Bit flag</strong></th>
<th><strong>Comment</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>0x1</td>
<td>! 0x40 &amp;&amp; ! 0x80</td>
<td>template having multiple segments in sequencing</td>
</tr>
<tr>
<td>0x2</td>
<td></td>
<td>each segment properly aligned according to the aligner</td>
</tr>
<tr>
<td>0x4</td>
<td></td>
<td>segment unmapped</td>
</tr>
<tr>
<td>0x8</td>
<td>calculated* or stored in the mate's info</td>
<td>next segment in the template unmapped</td>
</tr>
<tr>
<td>0x10</td>
<td></td>
<td>SEQ being reverse complemented</td>
</tr>
<tr>
<td>0x20</td>
<td>calculated* or stored in the mate's info</td>
<td>SEQ of the next segment in the template being reverse complemented</td>
</tr>
<tr>
<td>0x40</td>
<td></td>
<td>the first segment in the template</td>
</tr>
<tr>
<td>0x80</td>
<td></td>
<td>the last segment in the template</td>
</tr>
<tr>
<td>0x100</td>
<td></td>
<td>secondary alignment</td>
</tr>
<tr>
<td>0x200</td>
<td></td>
<td>not passing quality controls</td>
</tr>
<tr>
<td>0x400</td>
<td></td>
<td>PCR or optical duplicate</td>
</tr>
</tbody>
</table>

\* For segments within the same slice.

## 9.4 **Read feature records** <a href="#read-feature-records" class="header-anchor">#</a>

Read features are used to store read details that are expressed using
read coordinates (e.g. base differences respective to the reference
sequence). The read feature records start with the number of read
features followed by the read features themselves:

<table>
<thead>
<tr>
<th></th>
<th><strong>Data series type</strong></th>
<th><strong>Data series name</strong></th>
<th><strong>Field</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>int</td>
<td>FN</td>
<td>number of read features</td>
<td>the number of read features</td>
</tr>
<tr>
<td>2 *1</td>
<td>int</td>
<td>FP</td>
<td>in-read-position</td>
<td>position of the read feature</td>
</tr>
<tr>
<td>3 *1</td>
<td>byte</td>
<td>FC</td>
<td>read feature code</td>
<td>*2</td>
</tr>
<tr>
<td>4 *1</td>
<td>*2</td>
<td>*2</td>
<td>read feature data</td>
<td>*2</td>
</tr>
</tbody>
</table>

\*1 Repeated for each read feature.

\*2 See **read feature codes** below.

### 9.4.1 Read feature codes <a href="#read-feature-codes" class="header-anchor">#</a>

The following codes are used to distinguish variations in read
coordinates:

<table>
<thead>
<tr>
<th><strong>Feature code</strong></th>
<th><strong>Id</strong></th>
<th><strong>Data series type</strong></th>
<th><strong>Data series name</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>Read base</td>
<td>B (0x42)</td>
<td>byte,byte</td>
<td>BA,QS</td>
<td>A base and associated quality score</td>
</tr>
<tr>
<td>Substitution</td>
<td>X (0x58)</td>
<td>byte</td>
<td>BS</td>
<td>base substitution codes, SAM operators X, M and =</td>
</tr>
<tr>
<td>Insertion</td>
<td>I (0x49)</td>
<td>byte[ ]</td>
<td>IN</td>
<td>inserted bases, SAM operator I</td>
</tr>
<tr>
<td>Deletion</td>
<td>D (0x44)</td>
<td>int</td>
<td>DL</td>
<td>number of deleted bases, SAM operator D</td>
</tr>
<tr>
<td>Insert base</td>
<td>i (0x69)</td>
<td>byte</td>
<td>BA</td>
<td>single inserted base, SAM operator I</td>
</tr>
<tr>
<td>Quality score</td>
<td>Q (0x51)</td>
<td>byte</td>
<td>QS</td>
<td>single quality score</td>
</tr>
<tr>
<td>Reference skip</td>
<td>N (0x4E)</td>
<td>int</td>
<td>RS</td>
<td>number of skipped bases, SAM operator N</td>
</tr>
<tr>
<td>Soft clip</td>
<td>S</td>
<td>byte[ ]</td>
<td>SC</td>
<td>soft clipped bases, SAM operator S</td>
</tr>
<tr>
<td>Padding</td>
<td>P</td>
<td>int</td>
<td>PD</td>
<td>number of padded bases, SAM operator P</td>
</tr>
<tr>
<td>Hard clip</td>
<td>H</td>
<td>int</td>
<td>HC</td>
<td>number of hard clipped bases, SAM operator H</td>
</tr>
</tbody>
</table>

### 9.4.2 Base substitution codes (BS data series) <a href="#base-substitution-codes-bs-data-series"
class="header-anchor">#</a>

A base substitution is defined as a change from one nucleotide base
(reference base) to another (read base) including N as an unknown or
missing base. There are 5 possible bases ACGTN, 4 possible substitutions
for each base and 20 substitutions in total. Substitutions for the same
reference base are assigned integer codes from 0 to 3 inclusive. To
restore a base one would need to know its substitution code and the
reference base.

A base substitution matrix assigns integer codes to all possible
substitutions.

Substitution matrix is written as follows. Substitutions for a given
reference base are sorted by their frequencies in descending order then
assigned numbers from 0 to 3. Same-frequency ties are broken using
alphabetical order. For example, let us assume the following
substitution frequencies for base A:

AC: 15%

AG: 25%

AT: 55%

AN: 5%

Then the substitution codes are:

AC: 2

AG: 1

AT: 0

AN: 3

and they are written as a single byte, 10 01 00 11 = 147 decimal or 0x93
in this case. The whole substitution matrix is written as 5 bytes, one
for each reference base in the alphabetical order: A, C, G, T and N.

Note: the last two bits of each substitution code are redundant but
still required to simplify the reading.

## 9.5 **Mate record** <a href="#mate-record" class="header-anchor">#</a>

There are two ways in which mate information can be preserved in CRAM:
number of records downstream (distance) to the next fragment in the
template and a special mate record if the next fragment is not in the
current slice. Combination of the two approaches allows to fully restore
BAM level mate information and efficiently store it in the CRAM file.

For mates within the slice only the distance is captured:

<table>
<thead>
<tr>
<th></th>
<th><strong>Data series type</strong></th>
<th><strong>Data series name</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>int</td>
<td>NF</td>
<td>the number of records to the next fragment</td>
</tr>
</tbody>
</table>

If the next fragment is not found within the horizon then the following
structure is included into the CRAM record:

<table>
<thead>
<tr>
<th></th>
<th><strong>Data series type</strong></th>
<th><strong>Data series name</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>byte</td>
<td>MF</td>
<td>next mate bit flags, see table below</td>
</tr>
<tr>
<td>2</td>
<td>byte[ ]</td>
<td>RN</td>
<td>the read name</td>
</tr>
<tr>
<td>3</td>
<td>int</td>
<td>NS</td>
<td>mate reference sequence identifier</td>
</tr>
<tr>
<td>4</td>
<td>int</td>
<td>NP</td>
<td>mate alignment start position</td>
</tr>
<tr>
<td>5</td>
<td>int</td>
<td>TS</td>
<td>the size of the template (insert size)</td>
</tr>
</tbody>
</table>

### 9.5.1  <a href="#section" class="header-anchor">#</a>

### 9.5.2 Next mate bit flags (MF data series) <a href="#next-mate-bit-flags-mf-data-series"
class="header-anchor">#</a>

The next mate bit flags expressed as an integer represent the MF data
series. The following bit flags are defined:

<table>
<thead>
<tr>
<th><strong>Bit flag</strong></th>
<th><strong>Name</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>0x1</td>
<td>mate negative strand bit</td>
<td>the bit is set if the mate is on the negative strand</td>
</tr>
<tr>
<td>0x2</td>
<td>mate unmapped bit</td>
<td>the bit is set if the mate is unmapped</td>
</tr>
</tbody>
</table>

### 9.5.3 Read names (RN data series) <a href="#read-names-rn-data-series" class="header-anchor">#</a>

Read names can be preserved in the CRAM format. However, it is
anticipated that in the majority of cases original read names will not
be preserved and sequential integer numbers will be used as read names.
Read names may also be used to associate fragments into templates when
the fragments are too far apart to be referenced by the number of CRAM
records. In this case the read names are not required to be the same as
the original ones. Their only two requirements are:

$\bullet$ read name must be the same for all fragments of the same
template

$\bullet$ read name of a template must be unique within a file

## 9.6 **Compression bit flags (CF data series)** <a href="#compression-bit-flags-cf-data-series"
class="header-anchor">#</a>

The compression bit flags expressed as an integer represent the CF data
series. The following compression flags are defined for each CRAM read
record:

<table>
<thead>
<tr>
<th><strong>Bit flag</strong></th>
<th><strong>Name</strong></th>
<th><strong>Description</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>0x1</td>
<td>quality scores stored as array</td>
<td>quality scores can be stored as read features or as an array similar to
read bases.</td>
</tr>
<tr>
<td>0x2</td>
<td>detached</td>
<td>the next segment is out of horizon</td>
</tr>
<tr>
<td>0x4</td>
<td>has mate downstream</td>
<td>tells if the next segment should be expected further in the stream</td>
</tr>
</tbody>
</table>

# 10 **Reference sequences** <a href="#reference-sequences" class="header-anchor">#</a>

CRAM format is natively based upon usage of reference sequences even
though in some cases they are not required. In contrast to BAM format
CRAM format has strict rules about reference sequences.

1.  M5 (sequence MD5 checksum) field of @SQ sequence record in the BAM
    header is required and UR (URI for the sequence fasta optionally
    gzipped file) field is strongly advised. The rule for calculating
    MD5 is to remove any non-base symbols (like \n, sequence name or
    length and spaces) and upper case the rest. Here are some examples:

    `> samtools faidx human_g1k_v37.fasta 1 grep -v '^>' tr -d '\n' tr a-z A-Z md5sum -`\
    `1b22b98cdeb4a9304cb5d48026a85128 -`

    `> samtools faidx human_g1k_v37.fasta 1:10-20 grep -v '^``>``' tr -d '\n' tr a-z A-Z md5sum -`\
    `0f2a4865e3952676ffad2c3671f14057 -`

    Please note that the latter calculates the checksum for 11 bases
    from position 10 (inclusive) to 20 (inclusive) and the bases are
    counted 1-based, so the first base position is 1.

2.  All CRAM reader implementations are expected to check for reference
    MD5 checksums and report any missing or mismatching entries.
    Consequently, all writer implementations are expected to ensure that
    all checksums are injected or checked during compression time.

3.  In some cases reads may be mapped beyond the reference sequence. All
    out of range reference bases are all assumed to be 'N'.

4.  MD5 checksum bytes in slice header should be ignored for unmapped or
    multiref slices.

# 11 **Indexing** <a href="#indexing" class="header-anchor">#</a>

### 11.0.1 General notes <a href="#general-notes" class="header-anchor">#</a>

Please note that CRAM indexing is external to the file format itself and
may change independently of the file format specification in the future.
For example, a new type of index files may appear.

Individual records are not indexed in CRAM files, slices should be used
instead as a unit of random access. Another important difference between
CRAM and BAM indexing is that CRAM container header and compression
header block (first block in container) must always be read before
decoding a slice. Therefore two read operations are required for random
access in CRAM.

Indexing a CRAM file is deemed to be a lightweight operation because it
does not require any CRAM records to be read. All indexing information
can be obtained from container headers, namely sequence id, alignment
start and span, container start byte offset and slice byte offset inside
the container.

### 11.0.2 CRAM index <a href="#cram-index" class="header-anchor">#</a>

A CRAM index is a gzipped tab delimited file containing the following
columns:

1.  Sequence id

2.  Alignment start

3.  Alignment span

4.  Container start byte offset in the file

5.  Slice start byte offset in the container data ('blocks')

6.  Slice bytes

Each line represents a slice in the CRAM file. Please note that all
slices must be listed in index file.

### 11.0.3 BAM index <a href="#bam-index" class="header-anchor">#</a>

BAM indexes are supported by using 4-byte integer pointers called
landmarks that are stored in container header. BAM index pointer is a
64-bit value with 48 bits reserved for the BAM block start position and
16 bits reserved for the in-block offset. When used to index CRAM files,
the first 48 bits are used to store the CRAM container start position
and the last 16 bits are used to store the index of the landmark in the
landmark array stored in container header. The landmark index can be
used to access the appropriate slice.

The above indexing scheme treats CRAM slices as individual records in
BAM file. This allows to apply BAM indexing to CRAM files, however it
introduces some overhead in seeking specific alignment start because all
preceding records in the slice must be read and discarded.

# 12 **Appendix** <a href="#appendix" class="header-anchor">#</a>

## 12.1 **External encoding** <a href="#external-encoding" class="header-anchor">#</a>

External encoding operates on bytes only. Therefore any data series must
be translated into bytes before sending data into an external block. The
following agreements are defined.

Integer values are written as ITF8, which then can be translated into an
array of bytes.

Strings, like read name, are translated into bytes according to UTF8
rules. In most cases these should coincide with ASCII, making the
translation trivial.

## 12.2 **Codings** <a href="#codings" class="header-anchor">#</a>

### 12.2.1 Introduction <a href="#introduction" class="header-anchor">#</a>

The basic idea for codings is to efficiently represent some values in
binary format. This can be achieved in a number of ways that most
frequently involve some knowledge about the nature of the values being
encoded, for example, distribution statistics. The methods for choosing
the best encoding and determining its parameters are very diverse and
are not part of the CRAM format specification, which only describes how
the information needed to decode the values should be stored.

### 12.2.2 Offset <a href="#offset" class="header-anchor">#</a>

Most of the codings listed below encode positive integer numbers. An
integer offset value is used to allow any integer numbers and not just
positive ones to be encoded. It can also be used for monotonically
decreasing distributions with the maximum not equal to zero. For
example, given offset is 10 and the value to be encoded is 1, the
actually encoded value would be offset+value=11. Then when decoding, the
offset would be subtracted from the decoded value.

### 12.2.3 Beta coding <a href="#beta-coding" class="header-anchor">#</a>

### 12.2.4 Definition <a href="#definition" class="header-anchor">#</a>

Beta coding is a most common way to represent numbers in *binary
notation*.

### 12.2.5 Examples <a href="#examples" class="header-anchor">#</a>

<table>
<thead>
<tr>
<th><strong>Number</strong></th>
<th><strong>Codeword</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>1</td>
<td>1</td>
</tr>
<tr>
<td>2</td>
<td>10</td>
</tr>
<tr>
<td>4</td>
<td>100</td>
</tr>
</tbody>
</table>

### 12.2.6 Parameters <a href="#parameters" class="header-anchor">#</a>

CRAM format defines the following parameters of beta coding:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>itf8</td>
<td>offset</td>
<td>offset is added to each value</td>
</tr>
<tr>
<td>itf8</td>
<td>length</td>
<td>the number of bits used</td>
</tr>
</tbody>
</table>

### 12.2.7 Gamma coding <a href="#gamma-coding" class="header-anchor">#</a>

### 12.2.8 Definition <a href="#definition-1" class="header-anchor">#</a>

*Elias gamma code* is a prefix encoding of positive integers. This is a
combination of unary coding and beta coding. The first is used to
capture the number of bits required for beta coding to capture the
value.

### 12.2.9 Encoding <a href="#encoding-1" class="header-anchor">#</a>

1.  Write it in binary.

2.  Subtract 1 from the number of bits written in step 1 and prepend
    that many zeros.

3.  An equivalent way to express the same process:

4.  Separate the integer into the highest power of 2 it contains ($2N$)
    and the remaining $N$ binary digits of the integer.

5.  Encode $N$ in unary; that is, as $N$ zeroes followed by a one.

6.  Append the remaining $N$ binary digits to this representation of
    $N$.

### 12.2.10 Decoding <a href="#decoding" class="header-anchor">#</a>

1.  Read and count 0s from the stream until you reach the first 1. Call
    this count of zeroes $N$.

2.  Considering the one that was reached to be the first digit of the
    integer, with a value of $2N$, read the remaining $N$ digits of the
    integer.

### 12.2.11 Examples <a href="#examples-1" class="header-anchor">#</a>

<table>
<thead>
<tr>
<th><strong>Value</strong></th>
<th><strong>Codeword</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td>1</td>
</tr>
<tr>
<td>2</td>
<td>010</td>
</tr>
<tr>
<td>3</td>
<td>011</td>
</tr>
<tr>
<td>4</td>
<td>00100</td>
</tr>
</tbody>
</table>

### 12.2.12 Parameters <a href="#parameters-1" class="header-anchor">#</a>

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>itf8</td>
<td>offset</td>
<td>offset is added to each value</td>
</tr>
</tbody>
</table>

### 12.2.13 Golomb coding <a href="#golomb-coding" class="header-anchor">#</a>

### 12.2.14 Definition <a href="#definition-2" class="header-anchor">#</a>

*Golomb encoding* is a prefix encoding optimal for representation of
random positive numbers following geometric distribution.

1.  Fix the parameter $M$ to an integer value.

2.  For $N$, the number to be encoded, find

    1.  quotient $q = \lfloor N/M \rfloor$

    2.  remainder $r = N \bmod M$

3.  Generate Codeword

    1.  The Code format : `<`Quotient Code`>``<`Remainder Code`>`, where

    2.  Quotient Code (in unary coding)

        1.  Write a $q$-length string of 1 bits

        2.  Write a 0 bit

    3.  Remainder Code (in truncated binary encoding)

        1.  If $M$ is power of 2, code remainder as binary format. So
            $log_{2}(M)$ bits are needed. (Rice code)

        2.  If $M$ is not a power of 2, set $b=\lceil log_{2}(M) \rceil$

            1.  If $r < 2^{b}-M$ code $r$ as plain binary using $b-1$
                bits.

            2.  If $r \ge 2^{b}$ code the number $r+2^{b}$ in plain
                binary representation using $b$ bits.

### 12.2.15 Examples <a href="#examples-2" class="header-anchor">#</a>

<table>
<thead>
<tr>
<th><strong>Number</strong></th>
<th><strong>Codeword, M=10</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>0</td>
<td>0000</td>
</tr>
<tr>
<td>4</td>
<td>0100</td>
</tr>
<tr>
<td>10</td>
<td>10000</td>
</tr>
<tr>
<td>42</td>
<td>11110010</td>
</tr>
</tbody>
</table>

### 12.2.16 Parameters <a href="#parameters-2" class="header-anchor">#</a>

Golomb coding takes the following parameters:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>itf8</td>
<td>offset</td>
<td>offset is added to each value</td>
</tr>
<tr>
<td>itf8</td>
<td>M</td>
<td>the golomb parameter (number of bins)</td>
</tr>
</tbody>
</table>

### 12.2.17 Golomb-Rice coding <a href="#golomb-rice-coding" class="header-anchor">#</a>

Golomb-Rice coding is a special case of Golomb coding when the M
parameter is a power of 2. The reason for this coding is that the
division operations in Golomb coding can be replaced with bit shift
operators.

### 12.2.18 Subexponential coding <a href="#subexponential-coding" class="header-anchor">#</a>

### 12.2.19 Definition <a href="#definition-3" class="header-anchor">#</a>

Subexponential coding is parametrized by a non-nengative integer $k$.
The main feature of the subexponential code is its length. For integers
$n < 2k+1$ the code length increases linearly with $n$, but for larger
$n$ it increases logarithmically.

### 12.2.20 Encoding <a href="#encoding-2" class="header-anchor">#</a>

1.  Determine the group index i using the following rules:

    1.  if $n < 2^{k}$, then $i = 0$.

    2.  if $n \ge 2^{k}$ , then determine $i$ such that
        $2^{i+k-1} \le n < 2^{i+k}$

2.  Form the prefix of $i$ 1s.

3.  Insert the separator 0.

4.  Form the tail: express the value of $(n - 2^{i+k-1})$ as a
    $(i + k - 1)$-bit binary number if $i > 0$ and $n$ as a $k$-bit
    binary number otherwise.

### 12.2.21 Decoding <a href="#decoding-1" class="header-anchor">#</a>

1.  Let $i$ be the number of leading 1s (prefix) in the codeword.

2.  Form a run of 0s of length

    1.  0, if $i = 0$

    2.  $2^{i+k-1}$, otherwise

3.  Skip the next 0 (separator).

4.  Compute the length of the tail, $c_{tail}$ as

    1.  $k$, if $i = 0$

    2.  $k + i - 1$, if $i \ge 1$

5.  The next $c_{tail}$ bits are the tail. Form a run of 0s of length
    represented by the tail.

6.  Append 1 to the run of 0s.

7.  Go to step 1 to process the next codeword.

### 12.2.22 Examples <a href="#examples-3" class="header-anchor">#</a>

<table>
<thead>
<tr>
<th><strong>Number</strong></th>
<th><strong>Codeword, k=0</strong></th>
<th><strong>Codeword, k=1</strong></th>
<th><strong>Codeword, k=2</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>0</td>
<td>0</td>
<td>00</td>
<td>000</td>
</tr>
<tr>
<td>1</td>
<td>10</td>
<td>01</td>
<td>001</td>
</tr>
<tr>
<td>2</td>
<td>1100</td>
<td>100</td>
<td>010</td>
</tr>
<tr>
<td>3</td>
<td>1101</td>
<td>101</td>
<td>011</td>
</tr>
<tr>
<td>4</td>
<td>111000</td>
<td>11000</td>
<td>1000</td>
</tr>
<tr>
<td>5</td>
<td>111001</td>
<td>11001</td>
<td>1001</td>
</tr>
<tr>
<td>6</td>
<td>111010</td>
<td>11010</td>
<td>1010</td>
</tr>
<tr>
<td>7</td>
<td>111011</td>
<td>11011</td>
<td>1011</td>
</tr>
<tr>
<td>8</td>
<td>11110000</td>
<td>1110000</td>
<td>110000</td>
</tr>
<tr>
<td>9</td>
<td>11110001</td>
<td>1110001</td>
<td>110001</td>
</tr>
<tr>
<td>10</td>
<td>11110010</td>
<td>1110010</td>
<td>110010</td>
</tr>
</tbody>
</table>

### 12.2.23 Parameters <a href="#parameters-3" class="header-anchor">#</a>

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>itf8</td>
<td>offset</td>
<td>offset is added to each value</td>
</tr>
<tr>
<td>itf8</td>
<td>k</td>
<td>the order of the subexponential coding</td>
</tr>
</tbody>
</table>

### 12.2.24 Huffman coding <a href="#huffman-coding" class="header-anchor">#</a>

CRAM uses canonical *huffman coding*, which requires only bit-lengths of
codewords to restore data. The canonical huffman code follows two
additional rules: the alphabet has a natural sort order and codewords
are sorted by their numerical values. Given these rules and a codebook
containing bit-lengths for each value in the alphabet the codewords can
be easily restored.

**Important note: for alphabets with only one value there is no output
bits at all.**

### 12.2.25 Code computation <a href="#code-computation" class="header-anchor">#</a>

$\bullet$ Sort the alphabet ascending using bit-lengths and then using
numerical order of the values.

$\bullet$ The first symbol in the list gets assigned a codeword which is
the same length as the symbol's original codeword but all zeros. This
will often be a single zero ('0').

$\bullet$ Each subsequent symbol is assigned the next binary number in
sequence, ensuring that following codes are always higher in value.

$\bullet$ When you reach a longer codeword, then after incrementing,
append zeros until the length of the new codeword is equal to the length
of the old codeword.

### 12.2.26 Parameters <a href="#parameters-4" class="header-anchor">#</a>

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>itf8[ ]</td>
<td>alphabet</td>
<td>list of all encoded values</td>
</tr>
<tr>
<td>itf8[ ]</td>
<td>bit-lengths</td>
<td>array of bit-lengths for each symbol in the alphabet</td>
</tr>
</tbody>
</table>

### 12.2.27 Byte array coding <a href="#byte-array-coding" class="header-anchor">#</a>

Often there is a need to encode an array of bytes. This can be optimized
if the length of the encoded arrays is known. For such cases
BYTE_ARRAY_LEN and BYTE_ARRAY_STOP codings can be used.

### 12.2.28 BYTE_ARRAY_LEN  <a href="#byte_array_len" class="header-anchor">#</a>

Byte arrays are captured length-first, meaning that the length of every
array is written using an additional encoding. For example this could be
a golomb encoding. The parameter for BYTE_ARRAY_LEN are listed below:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>encoding<code>&lt;</code>int<code>&gt;</code></td>
<td>lengths encoding</td>
<td>an encoding describing how the arrays lengths are captured</td>
</tr>
<tr>
<td>encoding<code>&lt;</code>byte<code>&gt;</code></td>
<td>values encoding</td>
<td>an encoding describing how the values are captured</td>
</tr>
</tbody>
</table>

### 12.2.29 BYTE_ARRAY_STOP  <a href="#byte_array_stop" class="header-anchor">#</a>

Byte arrays are captured as a sequence of bytes terminated by a special
stop byteFor example this could be a golomb encoding. The parameter for
BYTE_ARRAY_STOP are listed below:

<table>
<thead>
<tr>
<th><strong>Data type</strong></th>
<th><strong>Name</strong></th>
<th><strong>Comment</strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>byte</td>
<td>stop byte</td>
<td>a special byte treated as a delimiter</td>
</tr>
<tr>
<td>itf8</td>
<td>external id</td>
<td>id of an external block containing the byte stream</td>
</tr>
</tbody>
</table>

## 12.3 **Choosing the container size** <a href="#choosing-the-container-size" class="header-anchor">#</a>

CRAM format does not constrain the size of the containers. However, the
following should be considered when deciding the container size:

$\bullet$ Data can be compressed better by using larger containers

$\bullet$ Random access performance is better for smaller containers

$\bullet$ Streaming is more convenient for small containers

$\bullet$ Applications typically buffer containers into memory

We recommend 1MB containers. They are small enough to provide good
random access and streaming performance while being large enough to
provide good compression. 1MB containers are also small enough to fit
into the L2 cache of most modern CPUs.

Some simplified examples are provided below to fit data into 1MB
containers.

**Unmapped short reads with bases, read names, recalibrated and original
quality scores**

We have 10,000 unmapped short reads (100bp) with read names,
recalibrated and original quality scores. We estimate 0.4 bits/base
(read names) + 0.4 bits/base (bases) + 3 bits/base (recalibrated quality
scores) + 3 bits/base (original quality scores) =~ 7 bits/base. Space
estimate is (10,000 \* 100 \* 7) / 8 / 1024 / 1024 =~ 0.9 MB. Data could
be stored in a single container.

**Unmapped long reads with bases, read names and quality scores**

We have 10,000 unmapped long reads (10kb) with read names and quality
scores. We estimate: 0.4 bits/base (bases) + 3 bits/base (original
quality scores) =~ 3.5 bits/base. Space estimate is (10,000 \* 10,000 \*
3.5) / 8 / 1024 / 1024 =~ 42 MB. Data could be stored in 42 x 1MB
containers.

**Mapped short reads with bases, pairing and mapping information**

We have 250,000 mapped short reads (100bp) with bases, pairing and
mapping information. We estimate the compression to be 0.2 bits/base.
Space estimate is (250,000 \* 100 \* 0.2) / 8 / 1024 / 1024 =~ 0.6 MB.
Data could be stored in a single container.

**Embedded reference sequences**

We have a reference sequence (10Mb). We estimate the compression to be 2
bits/base. Space estimate is (10000000 \* 2 / 8 / 1024 / 1024) =~ 2.4MB.
Data could be written into three containers: 1MB + 1MB + 0.4MB.

[^1]: Markus Hsi-Yang Fritz, Rasko Leinonen, Guy Cochrane, and Ewan
    Birney, **Efficient storage of high throughput DNA sequencing data
    using reference-based compression**, *Genome Res.* 2011 21: 734–740;
    [doi:10.1101/gr.114819.110](http://dx.doi.org/doi:10.1101/gr.114819.110);
    pmid:21245279.