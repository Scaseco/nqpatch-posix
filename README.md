# RDFPatch NQ Posix

Patches large RDF files like Wikidata in less than 1 hour on consumer hardware.

```bash
./rdfpatch-nq-apply.sh \
  '@lbzcat wikidata-20250723-truthy-BETA.sorted.nt.bz2' \
  '@lbzcat wikidata-20250723-to-20250918-truthy-BETA.sorted.rdfp.bz2' \
  | pv | lbzip2 -cz > patched-20250918.nt.bz2

# 969GiB 0:41:47 [ 395MiB/s]
# 41:47.11 total
```

md5sum patched-20250918.nt.bz2
# 3aee2213ab4d4367f5ea6ba75b6eaf68
# 45.883 total

md5sum wikidata-20250918-truthy-BETA.sorted.nt.bz2 
# 3aee2213ab4d4367f5ea6ba75b6eaf68
# 46.904 total
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

