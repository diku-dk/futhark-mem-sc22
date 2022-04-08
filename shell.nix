{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/2e8743b8e53638d8af54c74c023e0bb317557afb.tar.gz") {} }:

# Use host C compiler to avoid breaking OpenCL.
pkgs.stdenvNoCC.mkDerivation {
  name = "futhark-mem-sc22";
  nativeBuildInputs = [
     pkgs.python2
     pkgs.python3
  ];
}
