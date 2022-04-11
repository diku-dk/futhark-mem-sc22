# futhark-mem-sc22

Welcome to `futhark-mem-sc22`. The purpose of this repository is to help
reproduce the results of the "Memory Optimizations in an Array Language" paper
submitted to SC22.

## Initial setup

Immediately after cloning this repository, you should initialize and update the
submodules:

```
git clone https://github.com/diku-dk/futhark-mem-sc22
cd futhark-mem-sc22
git submodule init
git submodule update
```

## Instructions for running experiments

We support two different methods of running the experiments from the paper:
Directly on your host-machine or inside one of the provided containers.

### Running benchmarks on your host-machine

If you have installed and configured an OpenCL capable GPU (we use NVIDIAs A100
and AMDs MI100 in our article), you should be able to run the experiments using:

```
make all
```

This will compile and run both reference- and Futhark-implementations of all
benchmarks using the Futhark binary in `bin` and show the resulting performance
tables in ASCII. To use another version of Futhark, use `make FUTHARK=my-futhark
all`.

Alternatively, you can reproduce the experiment for each table individually by
running e.g. `make table1` in the `benchmarks` directory:

```
cd benchmarks
make table1
```

Benchmark results are cached, so running `make table1` a second time will be
instantaneous. To cleanup cached results, use `make clean`.

### Running benchmarks in a container

For even greater reproducability, we supply Docker-containers which can be used
to replicate the results from our article, as described below.

For NVIDIA devices, additional steps are needed to ensure that Docker containers
have access to the hosts GPU devices. Follow the instructions to
[here](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#docker)
to set up and install the NVIDIA Container Toolkit.

We supply two containers: `futhark-mem-sc22:cuda` and `futhark-mem-sc22:rocm`,
targeted at CUDA devices (such as NVIDIAs A100) and ROCM devices (such as AMDs
MI100) respectively.

The containers have been uploaded to the Github container
registry, and can be executed as follows

```
# cuda
docker run --rm -t --security-opt=label=disable --hooks-dir=/usr/share/containers/oci/hooks.d/ ghcr.io/diku-dk/futhark-mem-sc22:cuda

# rocm
docker run --rm -t --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video ghcr.io/diku-dk/futhark-mem-sc22:rocm
```

Running the commands above will pull and execute the container in question,
running all benchmarks and showing the resulting tables, equivalent to running
`make tables` in the `benchmarks` directory.

If anything fails, or if you only want to run particular benchmarks one at a
time, you can also get a command prompt inside the container by appending `-i
bash` to the commands above. Run `make help` inside the container to get
started.

## Rebuilding containers and binaries

To re-build or verify the container builds or the `futhark` binary, we use
[Nix](https://nixos.org/). To install Nix, follow the [installation instructions
on the website](https://nixos.org/download.html).

To build the `futhark` binary, simply execute the following command after
installing Nix:

```
make bin/futhark
```

Each container can be rebuilt using the following commands:

```
# cuda
make cuda.tar.gz

# rocm
make rocm.tar.gz
```

After building each container, you can load it into your local Docker registry
using:

```
# cuda
docker load < cuda.tar.gz

# rocm
docker load < rocm.tar.gz
```

Finally, you can run your locally built container using the commands from above,
replacing the ghcr.io link with e.g. `localhost/futhark-mem-sc22:cuda`.

## Troubleshooting

### Podman fails with "Error: payload does not match any of the supported image formats (oci, oci-archive, dir, docker-archive)"

Podman is a docker-equivalent, which mostly works as a 1:1 substitute, but which
has some bad error messages. The symptom described above can have multiple causes:

* Insufficient space on `/tmp`, which us used for storing the
  container.  Set the `TMPDIR` environment variable to point at a
  directory where you have write access and there is plenty of free
  space.

* You may need to run the `podman` commands as root.

## Manifest

This section describes every top-level directory and its purpose.

* `bin/`: precompiled binaries used in the artifact.

* `futhark/`: a Git submodule containing the Futhark compiler extended
  with memory optimisations.  This is the compiler used for the
  artifact, and can be used to (re)produce the `bin/futhark`
  executable with `make bin/futhark -B`.

* `benchmarks/`: Futhark and reference implementations of the different
  benchmarks used in the article. Contains a `Makefile` that allows you to run
  each benchmark and `result-table.py` which is used to show the tables in
  ASCII-form.

* `nvidia-icd/`: Additional files needed to build the `cuda.tar.gz`
  container. In particular, the `nvidia/cuda` Docker image supplied by NVIDIA
  does not by default support OpenCL execution, so we have to patch in some
  configuration-files.

## Makefile targets in root directory

```
futhark-mem-sc22 artifact
-------------------------

Targets:
  `make tables`      - Compile and run all benchmarks to reproduce tables from paper
                       For more info, use `make help` inside the `benchmarks` directory.
  `make bin/futhark` - Rebuild the futhark binary.
  `make cuda.tar.gz` - Build the docker container for CUDA (A100) execution.
  `make rocm.tar.gz` - Build the docker container for ROCM (MI100) execution.

  `make clean`       - Cleanup cached results.
  `make help`        - Show help information.

```

## Makefile info in benchmarks directory

```
futhark-mem-sc22 benchmarks
---------------------------

Targets:
  `make tables` - Compile and run all benchmarks to reproduce tables from the paper.
  `make table1` - Compile and run NW benchmarks
  `make table2` - Compile and run LUD benchmarks
  `make table3` - Compile and run Hotspot benchmarks
  `make table4` - Compile and run LBM benchmarks
  `make table5` - Compile and run OptionPricing benchmarks
  `make table6` - Compile and run LocVolCalib benchmarks

  `make clean`  - Cleanup all cached results
  `make help`   - Show help information.

For all targets, you can specify a different version of `futhark` by setting `FUTHARK=my-futhark`.
Similarly, you can specify how many executions of each benchmark you want to use with e.g. `RUNS=10`.

Inside the CUDA and ROCM containers, you have to specify e.g. `make FUTHARK=/futhark table1`.
```

