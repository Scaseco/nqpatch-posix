# RDFPatch NQ Posix

Command-line tools for efficiently patching large sorted N-Quads files.
Implemented as bash scripts backed by the POSIX tooling comm, awk, sort, and sed.

## Project Status

- Functional and tested

## Overview

This project provides three shell scripts for working with RDF patch files:

- **rdfpatch-nq-create.sh**: Generate a patch from two sorted N-Quads files
- **rdfpatch-nq-apply.sh**: Apply one or more patches to a base N-Quads file  
- **rdfpatch-nq-merge.sh**: Merge multiple patches into a single patch

## Design

The tools rely on `zcat` for transparent decompression of compressed files. By default, system `zcat` only supports gzip, but installing [`zutils`](https://linux.die.net/man/1/zutils) replaces it with a configurable decompression infrastructure that handles bzip2, gzip, lzip, xz, and zstd.

All tools work on the basis of byte-sorted N-Quads (e.g., `LC_ALL=C sort -u`). The `.rdfp` RDF patch files are sorted N-Quads prefixed with `A ` or `D ` for additions or deletions, respectively.

⚠️ For maximum performance, zutils should be configured to leverage the fastest (de-)compression tools!
  As an example, in order to use `lbzip2` instead of `bzip2`, add the following entry to `.config/zutils.conf`.
```bash
bz2 = lbzip2
```
Details can be found at: [https://www.nongnu.org/zutils/manual/zutils_manual.html#Configuration](https://www.nongnu.org/zutils/manual/zutils_manual.html#Configuration) \
Alternatively, `rdfpach-nq` supports [Factory Expressions](#factory-expressions).

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

### Local Installation

No installation required. Clone and make scripts executable:

```bash
git clone https://github.com/Scaseco/rdfpatch-nq-posix.git
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
  | lbzcat -z > result.nt.bz2
```

**Note**:
* (Plain) Process substitution `<(...)` won't work because files must be readable twice.
* Process Substitution using a temporary file `=(...)` will work, but this materializes the argument as a plain text file, which may use up a lot of disk space.


### Docker

Build the Docker image:

```bash
docker build -t rdfpatch .
```

Or pull from a registry:

```bash
docker pull aksw/rdfpatch-nq-posix
```

#### Usage

Run with the wrapper script using `create`, `apply`, or `merge` commands:

```bash
# Create a patch from two files
docker run --rm -u "$(id -u):$(id -g)" -v $(pwd):/data rdfpatch create old.nq new.nq > patch.rdfp

# Apply a patch
docker run --rm -u "$(id -u):$(id -g)" -v $(pwd):/data rdfpatch apply old.nq patch.rdfp > new.nq

# Merge multiple patches
docker run --rm -u "$(id -u):$(id -g)" -v $(pwd):/data rdfpatch merge patch1.rdfp patch2.rdfp > merged.rdfp
```

## Performance

Tested on AMD Ryzen AI Max+ 395 with Wikidata-scale data:

- 969GiB patch application in **41 minutes 47 seconds**
- Output verified with md5sum checksums

<details>
<summary>Detailed Experiment Output</summary>

```bash
./rdfpatch-nq-apply.sh \
  '@lbzcat wikidata-20250723-truthy-BETA.sorted.nt.bz2' \
  '@lbzcat wikidata-20250723-to-20250918-truthy-BETA.sorted.rdfp.bz2' \
  | pv | lbzip2 -z > patched-20250918.nt.bz2

# 969GiB 0:41:47 [ 395MiB/s]
# 41:47.11 total
```

```bash
md5sum patched-20250918.nt.bz2
# 3aee2213ab4d4367f5ea6ba75b6eaf68
# 45.883 total
```

```Bash
md5sum wikidata-20250918-truthy-BETA.sorted.nt.bz2 
# 3aee2213ab4d4367f5ea6ba75b6eaf68
# 46.904 total
```

</details>

## Examples

See `test/` directory for toy examples:

```bash
# Apply merged patch to snapshot1
./rdfpatch-nq-apply.sh test/snapshot1.nq test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp

# Or merge first, then apply
./rdfpatch-nq-apply.sh test/snapshot1.nq \
  =(./rdfpatch-nq-merge.sh test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp)
```

## Testing

Run the test suite using Bats:

```bash
cd bats-tests
./run-tests.sh
```

See `bats-tests/TESTING.md` for details on the test infrastructure.

## Limitations

- ⚠️ Byte-level diff requires identical whitespace, encoding, and line endings
- ⚠️ Patches must be applied to the same base file they were created from

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.

