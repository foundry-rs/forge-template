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

### Install DAppTools

```sh
curl https://dapp.tools/install | sh
```
