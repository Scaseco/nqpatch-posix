# RDFPatch NQ Posix

Patches large RDF files like Wikidata in less than 1 hour on consumer hardware.
All involved files must be based on byte sorted N-Quads such as produced by `LC_ALL=C sort -u`.

Project Status: Experimental - Functional but not battletested.

* Arguments that start with a `@` are interpreted as "factory expressions".
  The reason is, that scanning for added and removed quads must happen independently. The file is thus opened twice − once for each scan.
  Do not use process substitution as in `./rdfpatch-nq-apply.sh <(lbzcat file.rdfp.bz2)` - it won't work because the pipe-file cannot be read twice.

Omitting the `@` will try to decode files using `zcat`. On many systems, default `zcat` only supports gzip, but
installing `sudo apt install zutils` overrides this with a general customizable decoding system.

Measurements on an *AMD Ryzen AI Max+ 395*:

```bash
./rdfpatch-nq-apply.sh \
  '@lbzcat wikidata-20250723-truthy-BETA.sorted.nt.bz2' \
  '@lbzcat wikidata-20250723-to-20250918-truthy-BETA.sorted.rdfp.bz2' \
  | pv | lbzip2 -cz > patched-20250918.nt.bz2

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

## Merging Patchfile

```
./rdfpatch-nq-merge.sh test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp # patch-1-to-3.rdfp
```

## Apply a merged patch


```
# =(command) materializes the process output into a temporary file
./rdfpatch-nq-apply.sh test/snapshot1.nq =(./rdfpatch-nq-merge.sh test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp)

# Avoid, because it will start the merge process twice, which can be sub-par for many files.
./rdfpatch-nq-apply.sh test/snapshot1.nq '@./rdfpatch-nq-merge.sh test/patch-1-to-2.rdfp test/patch-2-to-3.rdfp'
```

## Toy example:

```
➜  cat test/old.nq 
b
c
d

➜  cat test/new.nq 
a
c
e

➜  ./rdfpatch-nq-create.sh test/old.nq test/new.nq > test/patch.rdfp
➜  cat test/patch.rdfp 
A a
D b
D d
A e

➜  ./rdfpatch-nq-apply.sh test/old.nq test/patch.rdfp
a
c
e
```

