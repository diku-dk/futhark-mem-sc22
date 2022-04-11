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

## Troubleshooting

### Podman fails with "Error: payload does not match any of the supported image formats (oci, oci-archive, dir, docker-archive)"

This symptom can have multiple causes:

* Insufficient space on `/tmp`, which us used for storing the
  container.  Set the `TMPDIR` environment variable to point at a
  directory where you have write access and there is plenty of free
  space.

* You may need to run the `docker` commands as root.

## Manifest

This section describes every top-level directory and its purpose.

* `bin/`: precompiled binaries and scripts used in the artifact.

* `futhark/`: a Git submodule containing the Futhark compiler extended
  with memory optimisations.  This is the compiler used for the
  artifact, and can be used to (re)produce the `bin/futhark`
  executable with `make bin/futhark -B`.
