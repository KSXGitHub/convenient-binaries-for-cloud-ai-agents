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

`../build.sh` is deterministic: a second run reproduces the checksum in
[`SHA256SUMS`](SHA256SUMS) byte for byte.

The Creusot binaries need glibc 2.34 or newer, the Why3 bundle 2.38. Only glibc is
built, because `creusot-rustc` runs only against the Rust toolchain it was compiled
against. The Why3 bundle must be unpacked at the prefix it was built for, which
`why3 --print-datadir` reports.

## Use

```bash
creusot/install.sh      # --help for the options
```

Afterwards `cargo creusot` needs no environment variables, only `~/.cargo/bin` on
`PATH`.

See the [Creusot guide](https://guide.creusot.rs/installation.html) for everything
about using Creusot itself.
