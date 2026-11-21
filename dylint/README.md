# Dylint

Prebuilt `cargo-dylint` and `dylint-link` for `x86_64-unknown-linux-gnu`,
copied byte-for-byte from the
[Dylint releases](https://github.com/trailofbits/dylint/releases). Each
tarball holds one binary under a top-level directory, so
`--strip-components=1` extracts it straight onto `PATH`.

Take the version your project pins and keep both commands on it; they
are released together under one tag. A newer `cargo-dylint` also drives
a library built by an older `dylint_linting`, because the driver's
compatibility check is on an ABI constant rather than on the crate
version.

## What has to be present

- `x86_64` Linux with **glibc 2.39 or newer**, measured off the
  committed binaries.
- `rustup`, free to install the toolchain the *lint library* pins, with
  the components it names. That is what `cargo dylint` builds under, not
  your project's toolchain, so a project on stable can find a driver
  being built under a nightly. A library built on `clippy_utils` needs
  `rustc-dev` at least, often `rust-src` and `llvm-tools-preview` too.
- `git`, and a C linker reachable as `cc`, which `dylint-link` execs.

The mirror saves only the two `cargo install` runs. A cold `cargo dylint`
still builds the driver and the lint library, and still fetches that
toolchain.

## Provenance

These are upstream's release assets, not built here, and their build
provenance is not verified in this repository. Where the GitHub API is
reachable, `gh attestation verify <tarball> --repo trailofbits/dylint`
checks it. To avoid trusting a prebuilt binary at all, run
`cargo install --locked cargo-dylint dylint-link` instead and pay the
build.

## No musl or arm64 build

The releases carry an `aarch64-unknown-linux-gnu` target that is not
mirrored here, and no musl target at all. Building the pair against musl
works, and removes the glibc floor:

```bash
version=6.4.0
apt-get install -y musl-tools
rustup target add x86_64-unknown-linux-musl
CC_x86_64_unknown_linux_musl=musl-gcc \
CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc \
  cargo install --locked --version "$version" \
    --target x86_64-unknown-linux-musl \
    cargo-dylint dylint-link
```

## Licence

Dylint is MIT OR Apache-2.0, and both texts sit beside this file.
