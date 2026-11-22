# Creusot 0.15.0

[Creusot](https://github.com/creusot-rs/creusot) is a deductive verifier for Rust.
It provides the `cargo creusot` subcommand.

Nothing here has a binary release upstream, so both tarballs are built from source
by [`../build.sh`](../build.sh) and [`../build-why3.sh`](../build-why3.sh). The
Creusot source is tag `v0.15.0`, commit `fd4d85b2c237ef93147e99f6a0c04acfc89a6a17`;
the Why3 and why3find versions come from that tag's own `creusot-deps.opam`.

| | |
|---|---|
| `creusot-0.15.0-x86_64-unknown-linux-gnu.tar.gz` | `cargo-creusot`, `creusot-rustc`, `creusot-install`, the Creusot Why3 prelude |
| `creusot-why3-0.15.0-x86_64-unknown-linux-gnu.tar.gz` | Why3 1.8.2+git and why3find 1.3.0+dev — Creusot proves nothing without them |

The Creusot binaries need glibc 2.34 or newer; the Why3 bundle needs 2.38. Only
glibc is built: `creusot-rustc` is a rustc driver and runs only against the Rust
toolchain it was compiled against, so a musl build would have to be made on a musl
host and paired with a musl toolchain.

## Use

```bash
creusot/install.sh
```

[`install.sh`](../install.sh) is Creusot's own `./INSTALL` without the parts that
compile — neither the workspace against `rustc-dev`, nor the opam switch that
builds OCaml and Why3 from source and took 405 s here. It installs the pinned
nightly with `--profile minimal`, unpacks both tarballs where `cargo creusot`
looks for them, and downloads the SMT solvers. Afterwards `cargo creusot` needs no
environment variables, only `~/.cargo/bin` on `PATH`.

Why3 is installed by default; `--no-why3` leaves it out, and `cargo creusot --only
coma` still translates without it. `--why3` falls back to building the opam switch
when the bundle is missing.

The Why3 bundle is unpacked into `/opt/creusot-why3/_opam` and has to live exactly
there: `why3` compiles its data directory in and honours neither `WHY3DATA` nor
being moved, so `install.sh` asks the bundled binary where it will look rather
than trusting any path of its own.

See the [Creusot guide](https://guide.creusot.rs/installation.html) for everything
about using Creusot itself.
