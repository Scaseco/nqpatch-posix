# NQPatch

Command-line tools for efficiently patching large sorted N-Quads RDF files.
Implemented as bash scripts backed by the POSIX tooling awk, sort, comm, and sed.

As a demo, check out the sorted Wikidata truthy dumps and diffs that can be processed with the tooling of this repo: [hf.co/datasets/Aklakan/wikidata-sorted-nquads-and-diffs](https://huggingface.co/datasets/Aklakan/wikidata-sorted-nquads-and-diffs).

## Tracking Layer

NQPatch includes a *tracking layer* to manage patch relationships using SHA1 checksums.
The metadata for a file `x` is stored in a file `x.meta.json`.

- **nqpatch track sort input output**: Creates `output` by sorting `input`
  - Creates or extends `input.meta.json` with the sha1 hash of the input file
  - Creates or extends `output.meta.json` with the `sha1` and `sha1-original` keys with the hashes of the output file and the input file, respectively.
- **nqpatch track create**: `nqpatch track create old_dump new_dump patch.rdfp`: Creates `patch.rdfp` as the diff between `old` and `new`
  - Creates or extends `old_dump.meta.json` with the sha1 hash of the `old_dump` file
  - Creates or extends `new_dump.meta.json` with the sha1 hash of the `new_dump` file
  - Creates or extends `patch.rdfp.meta.json` with the `sha1-from` and `sha1-to` keys set to the hashes of the old/new dumps
  - Patch filename must be explicitly provided (not auto-generated)
  - Supports compressed patch output (.gz, .bz2, .xz, .zst)

## Project Status

- v2.x: Functional and tested with `.meta.json` metadata storage
- v1.x: See `v1.0.0` tag for legacy `.sha1` file-based tracking

## Overview

This project provides command-line tools for working with RDF patches, accessible via the `nqpatch` wrapper script:

- **nqpatch create**: Generate a patch from two sorted N-Quads files
- **nqpatch apply**: Apply one or more patches to a base N-Quads file
- **nqpatch merge**: Merge multiple patches into a single patch
- **nqpatch track sort**: Sort an N-Quads file and create tracking metadata
- **nqpatch track create**: Create a patch and tracking metadata (patch filename must be explicitly provided)

The entrypoint **nqpatch** features the sub-commands `create`, `apply` and `merge` that delegate to the scripts listed above.

## Design

The tools rely on `zcat` for transparent decompression of compressed files. By default, system `zcat` only supports gzip, but installing [`zutils`](https://linux.die.net/man/1/zutils) replaces it with a configurable decompression infrastructure that handles bzip2, gzip, lzip, xz, and zstd.

All tools work on the basis of byte-sorted N-Quads (e.g., `LC_ALL=C sort -u`). The `.rdfp` RDF patch files are sorted N-Quads prefixed with `A ` or `D ` for additions or deletions, respectively.

⚠️ For maximum performance, zutils should be configured to leverage the fastest (de-)compression tools. Also, for processing multiple files simultaneously, you want
   to limit the resources for each tool. The following zutils configuration uses parallel versions of the compression codec tools and restricts them to 4 cores. The file can be placed under `.config/zutils.conf`:
```
bz2 = lbzip2 -n4
gz = pigz -p4
xz = pixz -p4
zst = zstd -T4
lz = lz4
```

The corresponding packages on Ubuntu are:
```bash
sudo apt-get install lbzip2 pigz pixz zstd lz4
```

Details can be found at: [https://www.nongnu.org/zutils/manual/zutils_manual.html#Configuration](https://www.nongnu.org/zutils/manual/zutils_manual.html#Configuration)


## Quick Start

```bash
# Create a patch from two files
nqpatch create old.nq new.nq > patch.rdfp

# Apply a patch
nqpatch apply old.nq patch.rdfp > new.nq

# Merge multiple patches
nqpatch merge patch1.rdfp patch2.rdfp > merged.rdfp

# Create tracking metadata
nqpatch track create old.nq new.nq patch.rdfp

# Sort with tracking metadata
nqpatch track sort input.nq output.nq
```

**Note**: The scripts work with both plain and compressed files. For compressed files, they use `zcat` (or `zutils` if installed for multi-format support).

## Installation

### Local Installation

No installation required. Clone and make scripts executable:

```bash
git clone https://github.com/Scaseco/nqpatch-posix.git
cd nqpatch-posix
chmod +x nqpatch *.sh
```



## Usage

### Creating Patches

```bash
nqpatch create old.sorted.nq new.sorted.nq > patch.rdfp
```

Patches use the [RDF-Delta](https://afs.github.io/rdf-delta/rdf-patch.html) format with `A` (add) and `D` (delete) prefixes.

### Applying Patches

```bash
# Plain or compressed files (zcat handles decompression automatically)
nqpatch apply base.nq patch.rdfp

# Multiple patches (applied sequentially)
nqpatch apply base.nq patch1.rdfp patch2.rdfp

# Using process substitution for remote patches
nqpatch apply local-data.nq <(curl https://example.org/patch.rdfp)
```

### Merging Patches

```bash
nqpatch merge patch1.rdfp patch2.rdfp > merged.rdfp
```

### Tracking Patches

```bash
# Create tracking metadata
nqpatch track create old.nq new.nq patch.rdfp
```

The tracking layer creates `.meta.json` files containing:
- `sha1` - SHA1 hash of the file
- `sha1-original` (for sorted files) - SHA1 hash of the original unsorted file
- `sha1-from` (for patches) - SHA1 hash of the source snapshot
- `sha1-to` (for patches) - SHA1 hash of the target snapshot


### Tracking Layer Design

The tracking layer uses SHA1 hashes to establish relationships between snapshots and patches, stored in `.meta.json` files:

- **JSON metadata files** (`.meta.json`): Store SHA1 hashes and relationships in a structured format
- **sha1**: Hash of the file itself
- **sha1-original**: For sorted files, hash of the original unsorted file
- **sha1-from/sha1-to**: For patches, hashes of source and target snapshots
- **No centralized registry**: Each repository maintains its own `.meta.json` files
- **Move-resistant**: Files can be relocated; hash relationships persist as long as metadata files move with them

Future tools can use these files to:
- Find patches for a given snapshot
- Verify patch integrity
- Optimize patch chains vs full snapshot downloads

### Docker

Build the Docker image:

```bash
docker build -t aksw/nqpatch .
```

Or pull from a registry:

```bash
docker pull aksw/nqpatch
```

#### Usage

⚠️ Make sure to specify `--log-driver=none` \
Otherwise, all data from stdout will also be written to the docker logs.
When processing large amounts of data, this extra logging is a severe
performance hit and can easily consume up all remaining disk space.

Run with the wrapper script using `create`, `apply`, or `merge` commands:

```bash
# Create a patch from two files
docker run --rm --log-driver=none -i -v "$(pwd):/data" aksw/nqpatch \
  create old.nq new.nq > patch.rdfp

# Apply a patch
docker run --rm --log-driver=none -i -v "$(pwd):/data" aksw/nqpatch \
  apply old.nq patch.rdfp > new.nq

# Merge multiple patches
docker run --rm --log-driver=none -i -v "$(pwd):/data" aksw/nqpatch \
  merge patch1.rdfp patch2.rdfp > merged.rdfp
```

In case you write to files inside the `/data` volume, set the user:group in order for those files get the right ownership. For the current user this is typically done with:
`docker run -u "$(id -u):$(id -g) [...]"`

## Performance

Tested on AMD Ryzen AI Max+ 395 with Wikidata-scale data:

- 969GiB patch application in **41 minutes 47 seconds**
- Output verified with md5sum checksums

<details>
<summary>Detailed Experiment Output</summary>

```bash
nqpatch apply \
  wikidata-20250723-truthy-BETA.sorted.nt.bz2 \
  wikidata-20250723-to-20250918-truthy-BETA.sorted.rdfp.bz2 \
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

See `test/` directory for toy examples. For version 1.x implementation with separate `.sha1` files, see the `v1.0.0` tag.

```bash
# Apply merged patch to snapshot1
nqpatch apply test/snapshot1.nq test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp

# Or merge first, then apply
nqpatch apply test/snapshot1.nq \
  =(nqpatch merge test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp)
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

## Star History

<a href="https://www.star-history.com/?repos=Scaseco%2Fnqpatch-posix&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=Scaseco/nqpatch-posix&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=Scaseco/nqpatch-posix&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=Scaseco/nqpatch-posix&type=date&legend=top-left" />
 </picture>
</a>

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.

