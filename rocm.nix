{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/2e8743b8e53638d8af54c74c023e0bb317557afb.tar.gz") {} }:
let
  futhark0 = import ./futhark/default.nix {};
  futhark = futhark0.overrideAttrs (old: {
    installPhase = ''
                  mkdir -p $out/bin
                  tar xf futhark-nightly.tar.xz
                  cp futhark-nightly/bin/futhark $out/bin
                '';
  });
  rocm = pkgs.dockerTools.pullImage {
    imageName = "rocm/rocm-terminal";
    imageDigest = "sha256:eed044dc3843c76034cbddbb4f648b98eff138217781ecea6bfa8fd9aa97e4a4";
    sha256 = "1vn1hrrw780sj6qzipf2zqqk3hdb0x7hrm1nj5s6yd65w9xrvqrv";
    finalImageName = "rocm/rocm-terminal";
    finalImageTag = "5.1";
  } ;
  benchmarks = pkgs.copyPathToStore ./benchmarks;
  python-packages = python-packages: with python-packages; [
    numpy
  ];
in
pkgs.dockerTools.buildLayeredImage {
  name = "futhark-mem-sc22";
  tag = "rocm";
  fromImage = rocm;

  contents = [futhark
              benchmarks
              pkgs.python2
              (pkgs.python3.withPackages python-packages)
              pkgs.moreutils
              pkgs.jq
             ];

  config = {
    Env = ["CPATH=/opt/rocm/include:/opt/rocm/opencl/include"
           "C_INCLUDE_PATH=/opt/rocm/include:/opt/rocm/opencl/include"
           "LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/opencl/lib"
           "LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/opencl/lib"
           "CPLUS_INCLUDE_PATH=/opt/rocm/include:/opt/rocm/opencl/lib"
          ];
    Cmd = [ "${pkgs.gnumake}/bin/make" "tables"];
    WorkingDir = "${benchmarks}";
  };
}
