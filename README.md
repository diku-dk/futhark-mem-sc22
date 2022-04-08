# sc22-futhark-memory-artifact

## Manifest

## Manifest

This section describes every top-level directory and its purpose.

* `bin/`: precompiled binaries and scripts used in the artifact.

* `futhark/`: a Git submodule containing the Futhark compiler extended
  with memory optimisations.  This is the compiler used for the
  artifact, and can be used to (re)produce the `bin/futhark`
  executable with `make bin/futhark -B`.
