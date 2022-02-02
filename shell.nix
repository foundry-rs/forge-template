let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "5bca0569dc1b0a4ade46fbe53d0ba4b3c0ac4ca7";
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
