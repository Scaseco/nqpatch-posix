# RDFPatch NQ Posix

Command-line tools for efficiently patching large sorted N-Quads files.

## Overview

This project provides three shell scripts for working with RDF patch files:

- **rdfpatch-nq-create.sh**: Generate a patch from two sorted N-Quads files
- **rdfpatch-nq-apply.sh**: Apply one or more patches to a base N-Quads file  
- **rdfpatch-nq-merge.sh**: Merge multiple patches into a single patch

## Design

The tools rely on `zcat` for transparent decompression of compressed files. By default, system `zcat` only supports gzip, but installing [`zutils`](https://linux.die.net/man/1/zutils) replaces it with a configurable decompression infrastructure that handles BZip2, XZ, LZ4, and other formats.

All tools work with byte-sorted N-Quads (e.g., `LC_ALL=C sort -u`).

## Quick Start

```bash
# Create a patch from two files
./rdfpatch-nq-create.sh old.nq new.nq > patch.rdfp

# Apply a patch
./rdfpatch-nq-apply.sh old.nq patch.rdfp > new.nq

# Merge multiple patches
./rdfpatch-nq-merge.sh patch1.rdfp patch2.rdfp > merged.rdfp
```

**Note**: The scripts work with both plain and compressed files. For compressed files, they use `zcat` (or `zutils` if installed for multi-format support).

## Installation

No installation required. Clone and make scripts executable:

```bash
git clone <repo>
cd rdfpatch-nq-posix
chmod +x *.sh
```

## Usage

### Creating Patches

```bash
./rdfpatch-nq-create.sh old.sorted.nq new.sorted.nq > patch.rdfp
```

Patches use the [RDF-Delta](https://afs.github.io/rdf-delta/rdf-patch.html) format with `A` (add) and `D` (delete) prefixes.

### Applying Patches

```bash
# Plain or compressed files (via zcat/zutils)
./rdfpatch-nq-apply.sh base.nq[.bz2|.xz] patch.rdfp[.bz2|.xz]

# Multiple patches (applied sequentially)
./rdfpatch-nq-apply.sh base.nq patch1.rdfp patch2.rdfp
```

### Merging Patches

```bash
./rdfpatch-nq-merge.sh patch1.rdfp patch2.rdfp > merged.rdfp
```

## Factory Expressions

Arguments starting with `@` are interpreted as factory expressions (commands to be evaluated):

```bash
./rdfpatch-nq-apply.sh \
  '@lbzcat wikidata.nt.bz2' \
  '@lbzcat patch.rdfp.bz2' \
  | lbzcat > result.nt.bz2
```

**Note**: Process substitution `<(...)` won't work because files must be readable twice.

## Performance

Tested on AMD Ryzen AI Max+ 395 with Wikidata-scale data:

- 969GiB patch application in **41 minutes 47 seconds**
- Output verified with md5sum checksums

## Examples

See `test/` directory for toy examples:

```bash
# Apply merged patch to snapshot1
./rdfpatch-nq-apply.sh test/snapshot1.nq test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp

# Or merge first, then apply
./rdfpatch-nq-apply.sh test/snapshot1.nq \
  =(./rdfpatch-nq-merge.sh test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp)
```

## Limitations

- ⚠️ Byte-level diff requires identical whitespace, encoding, and line endings
- ⚠️ Experimental - functional but not battle-tested
- ⚠️ Patches must be applied to the same base file they were created from

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.

