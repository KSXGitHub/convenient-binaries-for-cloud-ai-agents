# Creusot

[Creusot](https://github.com/creusot-rs/creusot) is a deductive verifier for Rust.
It provides the `cargo creusot` subcommand.

Upstream publishes no binary releases, so unlike the other tools in this
repository these tarballs are built from source by [`build.sh`](build.sh).

## 0.15.0

| | |
|---|---|
| Source | `https://github.com/creusot-rs/creusot` tag `v0.15.0` |
| Commit | `fd4d85b2c237ef93147e99f6a0c04acfc89a6a17` |
| Rust toolchain | `nightly-2026-08-03` (`rustfmt`, `rustc-dev`, `llvm-tools`) |
| Built with | `./build.sh 0.15.0 <target>` |

The build is reproducible: run `build.sh` again with the same `BUILD_ROOT` and it
produces tarballs with the checksums in [`0.15.0/SHA256SUMS`](0.15.0/SHA256SUMS),
byte for byte.

### Contents

```
bin/cargo-creusot       the `cargo creusot` subcommand
bin/creusot-rustc       the rustc driver that does the translation to Coma
bin/creusot-install     installs the provers and the Why3 toolchain
bin/prelude-generator   regenerates share/why3find/packages (already generated here)
share/                  creusot-std sources, for CREUSOT_PATH
share/why3find/         the Why3 prelude, for CREUSOT_DATA_HOME
why3find.json           seed config, copied into new projects by `cargo creusot new`
creusot_why3.conf       Why3 configuration
creusot-deps.opam       opam dependencies, for `creusot-install why3`
```

`creusot-dev-config` is a helper for hacking on Creusot itself, so it is not shipped.

The **musl tarball has no `creusot-rustc`**. `creusot-rustc` is a rustc driver: it
is compiled against `rustc-dev` and loads `librustc_driver-<hash>.so` out of the
Rust toolchain at run time, and rustup ships `rustc-dev` for the host triple only.
A `creusot-rustc` is therefore only usable with the toolchain it was built
against, which on a glibc host is the glibc one. The musl tarball holds the three
statically linked binaries that have no such constraint.

The glibc binaries need glibc 2.34 or newer (Ubuntu 22.04, Debian 12, RHEL 9).

### Use

```bash
mkdir -p /opt/creusot
tar xf creusot-0.15.0-x86_64-unknown-linux-gnu.tar.gz -C /opt/creusot
export PATH=/opt/creusot/bin:$PATH
export CREUSOT_DATA_HOME=/opt/creusot
export CREUSOT_PATH=/opt/creusot/share
export CREUSOT_RUSTC=/opt/creusot/bin/creusot-rustc
```

`creusot-rustc` links against the toolchain it was built with, so that toolchain
has to be installed and on the library path:

```bash
rustup toolchain install nightly-2026-08-03 --profile minimal -c rustfmt -c rustc-dev -c llvm-tools
```

Running `cargo creusot` under `rustup run nightly-2026-08-03` is the simplest way
to get `LD_LIBRARY_PATH` set; otherwise point it at that toolchain's `lib`
directory yourself.

Translating Rust to Coma (`cargo creusot --only coma`) works with that alone.
Discharging the proof obligations additionally needs the provers and Why3:

```bash
creusot-install provers   # downloads alt-ergo, z3, cvc4, cvc5 into $CREUSOT_DATA_HOME/bin
creusot-install why3      # needs opam, and must run next to creusot-deps.opam
```

See the [Creusot guide](https://guide.creusot.rs/installation.html) for the rest.

### License

Creusot is LGPL-2.1-or-later; [`LICENSE`](LICENSE) is its license text, copied
from the source tree. `build.sh` records how these binaries were produced from
the tagged sources.
