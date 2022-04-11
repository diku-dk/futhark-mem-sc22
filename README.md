# futhark-mem-sc22

## Instructions for running CUDA container

```
nix-build cuda.nix -o cuda.tar.gz
docker load < cuda.tar.gz
docker run --rm --security-opt=label=disable --hooks-dir=/usr/share/containers/oci/hooks.d/ localhost/futhark-mem-sc22:cuda
```


## Instructions for running ROCM container

```
nix-build rocm.nix -o rocm.tar.gz
docker load < rocm.tar.gz
docker run -t --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video localhost/futhark-mem-sc22:rocm
```

## Manifest

This section describes every top-level directory and its purpose.

* `bin/`: precompiled binaries and scripts used in the artifact.

* `futhark/`: a Git submodule containing the Futhark compiler extended
  with memory optimisations.  This is the compiler used for the
  artifact, and can be used to (re)produce the `bin/futhark`
  executable with `make bin/futhark -B`.
