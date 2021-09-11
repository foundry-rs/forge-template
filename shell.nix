let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "adcc076b1441b3a928a8f0b42b2a63f05d9bcf0d";
  }) {};

in
  pkgs.mkShell {
    src = null;
    name = "dapptools-template";
    buildInputs = with pkgs; [
      pkgs.dapp
      pkgs.seth
      pkgs.go-ethereum-unlimited
      pkgs.hevm
    ];
  }
