# Creusot 0.15.0

[Creusot](https://github.com/creusot-rs/creusot) is a deductive verifier for Rust.
It provides the `cargo creusot` subcommand.

Upstream publishes no binary releases, so these tarballs are built from source by
[`../build.sh`](../build.sh) — which is both how they were made and how to remake
them: it is deterministic down to the [`SHA256SUMS`](SHA256SUMS) beside them. The
source is tag `v0.15.0`, commit `fd4d85b2c237ef93147e99f6a0c04acfc89a6a17`.

The binaries need glibc 2.34 or newer. Only glibc is built: `creusot-rustc` is a
rustc driver and runs only against the Rust toolchain it was compiled against, so
a musl build would have to be made on a musl host and paired with a musl
toolchain.

## Use

```bash
mkdir -p /opt/creusot
tar xf creusot-0.15.0-x86_64-unknown-linux-gnu.tar.gz -C /opt/creusot
export PATH=/opt/creusot/bin:$PATH
export CREUSOT_DATA_HOME=/opt/creusot
export CREUSOT_PATH=/opt/creusot/share
export CREUSOT_RUSTC=/opt/creusot/bin/creusot-rustc
```

`creusot-rustc` loads `librustc_driver` out of the toolchain it was built with, so
that toolchain has to be installed and on the library path:

```bash
rustup toolchain install nightly-2026-08-03 --profile minimal -c rustfmt -c rustc-dev -c llvm-tools
rustup run nightly-2026-08-03 cargo creusot --only coma
```

`creusot-install provers` downloads the SMT solvers into `$CREUSOT_DATA_HOME/bin`.
Why3 is not in the tarball; see the
[Creusot guide](https://guide.creusot.rs/installation.html) for it and for
everything about using Creusot itself.
