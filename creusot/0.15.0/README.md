# Creusot 0.15.0

[Creusot](https://github.com/creusot-rs/creusot) is a deductive verifier for Rust.
It provides the `cargo creusot` subcommand.

Nothing here has a binary release upstream, so both tarballs are built from source
by [`../build.sh`](../build.sh) and [`../build-why3.sh`](../build-why3.sh). The
Creusot source is tag `v0.15.0`, commit `fd4d85b2c237ef93147e99f6a0c04acfc89a6a17`;
the Why3 and why3find versions come from that tag's own `creusot-deps.opam`.

| tarball                                               | holds                                   |
|-------------------------------------------------------|-----------------------------------------|
| `creusot-0.15.0-x86_64-unknown-linux-gnu.tar.gz`      | the Creusot binaries                    |
| `creusot-why3-0.15.0-x86_64-unknown-linux-gnu.tar.gz` | Why3 and why3find, which do the proving |

Both build scripts are deterministic: a second run of either reproduces its
checksum in [`SHA256SUMS`](SHA256SUMS) byte for byte.

## Use

```bash
creusot/install.sh      # --help for the options
```

See the [Creusot guide](https://guide.creusot.rs/installation.html) for everything
about using Creusot itself.

## What it needs to work

`install.sh` arranges all of this; the list is for installing by hand, or for
working out why an install misbehaves.

|                                           |                                                                  |
|-------------------------------------------|------------------------------------------------------------------|
| glibc                                     | 2.34 or newer for the Creusot binaries, 2.38 for the Why3 bundle |
| rustup toolchain                          | `nightly-2026-08-03`, `--profile minimal` is enough              |
| `/opt/creusot-why3/_opam`                 | where the Why3 bundle must be unpacked, and nowhere else         |
| `$CARGO_HOME/bin`                         | holds `cargo-creusot`, and must be on `PATH`                     |
| `$DATA/toolchains/nightly-2026-08-03/bin` | holds `creusot-rustc`                                            |
| `$DATA/bin`                               | holds `why3`, `why3find` and the four provers                    |
| `$DATA/share/why3find/packages`           | the Creusot Why3 prelude                                         |
| `$DATA/creusot_why3.conf`                 | prover configuration                                             |
| `$DATA/why3find.json`                     | seeds a new project's own copy                                   |

`$DATA` is `$CREUSOT_DATA_HOME`, else `$XDG_DATA_HOME/creusot`, else
`~/.local/share/creusot`.

**No environment variables are required.** `cargo-creusot` finds `creusot-rustc`
under `$DATA/toolchains/`, prepends `$DATA/bin` to `PATH` for why3find, and sets
`RUSTUP_TOOLCHAIN`, `WHY3CONFIG` and `DUNE_DIR_LOCATIONS` itself. Setting
`CREUSOT_DATA_HOME` moves `$DATA`; `CREUSOT_RUSTC` and `CREUSOT_PATH` override the
first two rows and are not otherwise needed.

The Why3 bundle's absolute path is not negotiable: `why3` compiles its data
directory in and ignores both `WHY3DATA` and being moved. `why3 --print-datadir`
reports the path it will use.
