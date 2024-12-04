# Bitcoin, Lightning & Nostr dev environment

[![license](https://img.shields.io/badge/license-MIT-red.svg?style=flat)](https://raw.githubusercontent.com/z017/btc-lightning-nostr-devenv/main/LICENSE)

## Features
- Services:
  - Bitcoin Node
  - Lightning Nodes
  - Thunderhub
  - Nostr Relay
- Clients:
  - bitcoin-cli
  - lncli
  - nak
- Private key derivation from mnemonic and path
- Public key generation from private key

## Requirements
- [docker](https://www.docker.com)
- [jq](https://jqlang.github.io/jq)

## Installation
Clone repository:

```sh
$ git clone git://github.com/z017/btc-lightning-nostr-devenv.git
```

Afterwards, run the script to test it is working:

```sh
$ cd btc-lightning-nostr-devenv
$ ./devenv

Usage:
  devenv [options] [command] [args]

Available Commands:
  start                             Start dev environment.
  stop                              Stop dev environment.
  sh <service_name>                 Open a shell inside a running container.
  private_key <mnemonic> <path>     Generate private key from mnemonic and
                                    derivation path.     
  public_key <private_key>          Generate public key from private key.
  bitcoin_cli [args]                Bitcoind client.
  dev_lncli [args]                  Dev lnd client.
  alice_lncli [args]                Alice lnd client.
  bob_lncli [args]                  Bob lnd client.
  nak [args]                        Nostr relay client.
  clean                             Clean dev environment.
  help                              Display detailed help.
  version                           Print version information.

Options:
  --help, -h              Alias help command.
  --version, -v           Alias version command.
  --log-level <level>     Set the log level severity. Lower level will be
                          ignored. Must be an integer or a level name:
                          trace debug info warn error fatal.
  --                      Denotes the end of the options.  Arguments after this
                          will be handled as parameters even if they start with
                          a '-'.
```

If you get an error like this one:

```sh
-bash: ./devenv: Permission denied
```

Remember to make the script executable:

```sh
$ chmod +x devenv
```

## Getting Started

Start the development environment:
```sh
$ ./devenv start
```

Docker published ports:
- bitcoind
  - 18443 -> RPC
  - 29000 -> ZMQ TX
  - 29001 -> ZMQ BLOCK
  - 29002 -> ZMQ HASH BLOCK
- lnd
  - 10009 -> RPC
  - 8080  -> REST
- nostr_relay
  - 8081  -> WS
- thunderhub
  - 3000  -> HTTP

Access Thunderhub as a logged in user from:
- `http://localhost:3000/sso?token=1`

## Inspiration

- [Stacker News devenv](https://github.com/stackernews/stacker.news)
- [Cashu RegTest](https://github.com/ifuensan/cashu-regtest)

# License

Bitcoin, Lightning & Nostr dev environment is licensed under the MIT License (MIT). Please see [License File](https://raw.githubusercontent.com/z017/btc-lightning-nostr-devenv/main/LICENSE) for more information.