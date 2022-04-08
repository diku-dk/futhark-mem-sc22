{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/2e8743b8e53638d8af54c74c023e0bb317557afb.tar.gz") {} }:
let
  futhark0 = import ./futhark/default.nix {};
  futhark = futhark0.overrideAttrs (old: {
                installPhase = ''
                  mkdir -p $out
                  tar xf futhark-nightly.tar.xz
                  cp futhark-nightly/bin/futhark $out
                '';
            });
  nixFromDockerHub = pkgs.dockerTools.pullImage {
  imageName = "nvidia/cuda";
  imageDigest = "sha256:833fe2344bbe88181e79758fbcc744721f79ff2f6f7669a92020200bbd7445f2";
  sha256 = "0mv3nhfjjv49h9yd30fn3x14087dwpdc4n4aci29ak8difqf41jf";
  finalImageName = "nvidia/cuda";
  finalImageTag = "11.6.1-devel-ubuntu18.04";
}
;
  benchmarks = pkgs.copyPathToStore ./benchmarks;
in
pkgs.dockerTools.buildLayeredImage {
  name = "futhark-mem-sc22";
  tag = "latest";
  fromImage = nixFromDockerHub;

  contents = [futhark
              benchmarks
              pkgs.python2
              pkgs.python3
              pkgs.moreutils
              pkgs.jq
             ];

  config = {
    Env = ["C_INCLUDE_PATH=/usr/local/cuda/include"
           "LIBRARY_PATH=/usr/local/cuda/lib64"
           "LD_LIBRARY_PATH=/usr/local/cuda/lib64"
           "CPLUS_INCLUDE_PATH=/usr/local/cuda/include"
          ];
    Cmd = [ "${pkgs.gnumake}/bin/make" "FUTHARK=/futhark"];
    WorkingDir = "${benchmarks}";
  };
}
