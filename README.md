# RDFPatch NQ Posix

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

