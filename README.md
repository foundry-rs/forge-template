# <h1 align="center"> DappTools Template </h1>

**Template repository for getting started quickly with DappTools**

![Github Actions](https://github.com/gakonst/dapptools-template/workflows/Tests/badge.svg)

## Building and testing

```sh
git clone https://github.com/gakonst/dapptools-template
cd dapptools-template
make
make test
```
## Installing the toolkit

If you do not have DappTools already installed, you'll need to run the below
commands

### Install Nix

```sh
# User must be in sudoers
curl -L https://nixos.org/nix/install | sh

# Run this or login again to use Nix
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

### Install DappTools

```sh
curl https://dapp.tools/install | sh
```

## DappTools Resources

* [dapp.tools](https://dapp.tools/)
    * [HEVM Docs](https://github.com/dapphub/dapptools/blob/master/src/hevm/README.md)
    * [DappTools Docs](https://github.com/dapphub/dapptools/tree/master/src/dapp#readme)
    * [Seth Docs](https://github.com/dapphub/dapptools/tree/master/src/seth#readme) & [Introduction to Seth](https://docs.makerdao.com/clis/seth)
* [Symbolic Execution with ds-test](https://fv.ethereum.org/2020/12/11/symbolic-execution-with-ds-test/)
* [HEVM and Seth Cheatsheet](https://kndrck.co/posts/hevm_seth_cheatsheet/)
* [Solmate](https://github.com/Rari-Capital/solmate/)
* [Multi Collateral DAI](https://github.com/makerdao/dss)
* [Smart Contract Development with dapp.tools](https://youtu.be/lPinWgaNceM) at EthDenver
