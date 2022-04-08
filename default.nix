{ pkgs ? import <nixpkgs> {} }:
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
    imageDigest = "sha256:01d41694d0b0be8b7d1ea8146c7d318474a0f4a90bfea17d3ac1af0328a0830b";
    sha256 = "0jf6w0vgwdi7g24hmd05c4yrac1lkpn3id811kgy17apgy89p9sq";
    finalImageName = "nvidia/cuda";
    finalImageTag = "latest";
  };
in
pkgs.dockerTools.buildLayeredImage {
  name = "futhark-mem-sc22";
  tag = "latest";
  fromImage = nixFromDockerHub;

  contents = [futhark pkgs.python2 pkgs.python3 pkgs.moreutils pkgs.jq];

  config = {
    Cmd = [ "/futhark" ];
  };
}
