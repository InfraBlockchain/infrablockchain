# YOSEMITE - Proof-of-Transaction(PoT) Consensus based Public Blockchain

<!-- [![Build status](https://badge.buildkite.com/370fe5c79410f7d695e4e34c500b4e86e3ac021c6b1f739e20.svg?branch=master)](https://buildkite.com/EOSIO/eosio) -->

Using a volatile native crypto-currency causes a great hindrance in running a business. YOSEMITE resolves that problem by using tokens that have their values pegged to government-approved fiat money. Those fiat-pegged stable coins (e.g. USD-pegged dUSD token) are issued by trust entities (Depositories) as the underlying token of the blockchain. We call it native token.

YOSEMITE's unique Proof-of-Transaction(PoT) consensus algorithm, which allows only the direct contributors to the blockchain to create blocks and get rewarded, can address the fundamental problems in PoW, PoS consensus algorithms and sustain a fair and reasonable operation.

Finally, governments and companies globally have a capable underlying system to utilize the advantages of blockchain and conduct sustainable policies and businesses.

YOSEMITE is powered by [EOSIO software](https://github.com/EOSIO/eos) to get low latency block confirmation and BFT finality. Other than EOSIO features, some of the novel features of YOSEMITE include:

1. Uses real money (e.g. USD, EUR, CNY) as the native token for transaction fee : [README](contracts/yx.ntoken/README.md)
1. KYC/AML Compliant Blockchain
1. Proof-of-Transaction & Transaction-as-a-Vote (will be provided)
1. Embedded Decentralized Exchange (will be provided)
1. Smart contract platform powered by Web Assembly (will be provided)

YOSEMITE is released under the open source MIT license and is offered “AS IS” without warranty of any kind, express or implied. Any security provided by the YOSEMITE software depends in part on how it is used, configured, and deployed. YOSEMITE is built upon many third-party libraries such as Binaryen (Apache License) and WAVM (BSD 3-clause) which are also provided “AS IS” without warranty of any kind. Without limiting the generality of the foregoing, Yosemite X Inc. makes no representation or guarantee that YOSEMITE or any third-party libraries will perform as intended or will be free of errors, bugs or faulty code. Both may fail in large or small ways that could completely or partially limit functionality or compromise computer systems. If you use or implement YOSEMITE, you do so at your own risk. In no event will Yosemite X Inc. be liable to any party for any damages whatsoever, even if it had been advised of the possibility of damage.  

**If you have previously installed EOSIO, please run the `eosio_uninstall` script (it is in the directory where you cloned EOSIO) before downloading and using the binary releases.**

#### Mac OS X Brew Install
```sh
$ brew tap eosio/eosio
$ brew install eosio
```
#### Mac OS X Brew Uninstall
```sh
$ brew remove eosio
```
#### Ubuntu 18.04 Debian Package Install
```sh
$ wget https://github.com/eosio/eos/releases/download/v1.6.0/eosio_1.6.0-1-ubuntu-18.04_amd64.deb
$ sudo apt install ./eosio_1.6.0-1-ubuntu-18.04_amd64.deb
```
#### Ubuntu 16.04 Debian Package Install
```sh
$ wget https://github.com/eosio/eos/releases/download/v1.6.0/eosio_1.6.0-1-ubuntu-16.04_amd64.deb
$ sudo apt install ./eosio_1.6.0-1-ubuntu-16.04_amd64.deb
```
#### Debian Package Uninstall
```sh
$ sudo apt remove eosio
```
#### Centos RPM Package Install
```sh
$ wget https://github.com/eosio/eos/releases/download/v1.6.0/eosio-1.6.0-1.el7.x86_64.rpm
$ sudo yum install ./eosio-1.6.0-1.el7.x86_64.rpm
```
#### Centos RPM Package Uninstall
```sh
$ sudo yum remove eosio.cdt
```
#### Fedora RPM Package Install
```sh
$ wget https://github.com/eosio/eos/releases/download/v1.6.0/eosio-1.6.0-1.fc27.x86_64.rpm
$ sudo yum install ./eosio-1.6.0-1.fc27.x86_64.rpm
```
#### Fedora RPM Package Uninstall
```sh
$ sudo yum remove eosio.cdt
```

## Supported Operating Systems
1. Centos 7
2. Ubuntu 18.04
3. MacOS Darwin 10.12 and higher (MacOS 10.13.x recommended)

## Integrated Services
1. [Native Token](contracts/yx.ntoken/README.md)
1. [Non-native or User Tokens](contracts/yx.token/README.md)
1. [Account Management and KYC](contracts/yx.identity/README.md)
1. [Digital Contract Signing Service](contracts/yx.dcontract/README.md)

## Resources
1. [Website](https://yosemitex.com)
1. [White Paper](https://yosemitex.com/documents/YOSEMITE_Blockchain_Technical_White_Paper_201802a.pdf)
1. [Java SDK](https://github.com/YosemiteLabs/yosemite-j)
1. [Roadmap](roadmap.md)

<a name="gettingstarted"></a>
## Getting Started
YOSEMITE is based on [EOSIO software](https://github.com/EOSIO/eos). So instructions detailing the process of getting the software, building it, running a simple test network that produces blocks, account creation to the blockchain can be helped by [Getting Started](https://developers.eos.io/eosio-nodeos/docs/overview-1) on the [EOSIO Developer Portal](https://developers.eos.io).
But the names of programs and scripts are changed.
```
nodeos -> yosemite
cleos  -> clyos ('cl'ient + 'yos'emite)
keosd  -> keyos (key + 'yos'emite)
```
### Client Tool
clyos : https://developers.eos.io/eosio-nodeos/docs/cleos-overview

### Key Store Daemon
keyos : https://developers.eos.io/eosio-nodeos/docs/keosd-overview

## Build and Install
To build YOSEMITE, use `yosemite_build.sh`. To install and unsintall, use `yosemite_install.sh` and `yosemite_uninstall.sh`.

## Local Single-node Testnet
For local test environment, [EOSIO Local Single-node Testnet](https://developers.eos.io/eosio-nodeos/docs/local-single-node-testnet) would help.

For the first execution of YOSEMITE signle-node blockchain, you should do like below:
```shell
cd build/programs/yosemite
./yosemite -e -p yosemite --plugin eosio::chain_api_plugin --plugin eosio::history_api_plugin \
           --config-dir $HOME/yosemite/config \
           --data-dir $HOME/yosemite/data
```
Then you can adjust `config.ini` under `config-dir` to just execute `./yosemite`.
```ini
enable-stale-production = true
 
producer-name = yosemite
 
plugin = eosio::producer_plugin
plugin = eosio::chain_api_plugin
plugin = eosio::http_plugin

contracts-console = true
verbose-http-errors = true
```
