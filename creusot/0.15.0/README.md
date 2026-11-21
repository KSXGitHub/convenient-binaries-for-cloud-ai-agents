# Creusot 0.15.0

[Creusot](https://github.com/creusot-rs/creusot) is a deductive verifier for Rust.
It provides the `cargo creusot` subcommand.

Upstream publishes no binary releases, so this tarball is built from source by
[`../build.sh`](../build.sh) — which is both how it was made and how to remake it:
it is deterministic down to the [`SHA256SUMS`](SHA256SUMS) beside it. The source
is tag `v0.15.0`, commit `fd4d85b2c237ef93147e99f6a0c04acfc89a6a17`.

The binaries need glibc 2.34 or newer. Only glibc is built: `creusot-rustc` is a
rustc driver and runs only against the Rust toolchain it was compiled against, so
a musl build would have to be made on a musl host and paired with a musl
toolchain.

## Use

```bash
creusot/install.sh
```

[`install.sh`](../install.sh) is Creusot's own `./INSTALL` without the part that
compiles the workspace. It installs the pinned nightly with `--profile minimal`,
unpacks the binaries and the Why3 prelude where `cargo creusot` looks for them by
default, and downloads the SMT solvers — so afterwards `cargo creusot` needs no
environment variables, only `~/.cargo/bin` on `PATH`.

Proving also needs Why3 and why3find, which are built from source by opam and are
the slow part of any Creusot install. Pass `--why3` to do that too;
`cargo creusot --only coma` works without them.

To place the files by hand instead: `cargo-creusot` on `PATH`, `creusot-rustc` in
`$CREUSOT_DATA_HOME/toolchains/nightly-2026-08-03/bin/`, and the tarball's
`share/why3find/packages`, `why3find.json` and `creusot_why3.conf` under
`$CREUSOT_DATA_HOME`. The `share/creusot-std` sources are only consulted through
`CREUSOT_PATH` against a development build of Creusot, so a released version does
not need them.

See the [Creusot guide](https://guide.creusot.rs/installation.html) for everything
about using Creusot itself.
