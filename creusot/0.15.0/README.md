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

## Prerequisites

`install.sh` arranges everything else. These are what it needs from you, or cannot
do on your behalf.

| prerequisite                                                    | why                                                                                                                                |
|-----------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| glibc 2.34 or newer; 2.38 for the Why3 bundle                   | the binaries are dynamically linked                                                                                                |
| `rustup`                                                        | `install.sh` installs the pinned toolchain through it                                                                              |
| network for `static.rust-lang.org` and GitHub release downloads | the toolchain and the four provers are fetched, not bundled                                                                        |
| a writable `/opt/creusot-why3`                                  | where the Why3 bundle has to live, and stay: `why3` compiles that path in and ignores `WHY3DATA`, so it cannot be moved afterwards |
| `$CARGO_HOME/bin` on `PATH`                                     | `install.sh` puts `cargo-creusot` there but cannot edit your `PATH`                                                                |
| `opam`, for `--why3` only                                       | the fallback that builds Why3 from source when the bundle is absent                                                                |
