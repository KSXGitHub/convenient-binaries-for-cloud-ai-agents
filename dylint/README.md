# Dylint

Prebuilt `cargo-dylint` and `dylint-link` for `x86_64-unknown-linux-gnu`,
mirrored byte-for-byte from the
[Dylint releases](https://github.com/trailofbits/dylint/releases).

These two commands are what a Dylint lint library needs in order to be
built and run. Each tarball holds one binary under a top-level
directory, so `--strip-components=1` extracts it straight onto `PATH`.

## Why mirror them

Building both from source costs minutes of CPU and leaves hundreds of
megabytes under the target directory, which a container with a fixed disk
allowance pays for every time it starts. Extracting these tarballs takes
about a second.

A source build also needs a toolchain new enough for Dylint's own MSRV,
which is not always the one a container ships with. Where it is not,
`cargo install` refuses to start and the toolchain has to be provisioned
first.

Running `cargo dylint` still builds the Dylint driver and the lint
library itself, and those two are the larger part of a cold run. What the
mirror removes is only the cost of the two commands.

## Picking a version

Take whichever version your project pins, and keep `cargo-dylint` and
`dylint-link` on the same one. They are released together under one tag.

Matching the pin is a convenience rather than a requirement. The only
compatibility gate is in the Dylint driver, which reads the
`dylint_version` symbol out of the lint library and compares it against
its own `DYLINT_VERSION`. That constant tracks the symbol's ABI rather
than the crate version, so where two releases agree on it, a newer
`cargo-dylint` drives a library built by an older `dylint_linting`. Both
spellings of the constant are in the published sources, so a pairing can
be checked before it is relied on.

## What the toolchain has to be

Nothing here pins the toolchain your project builds under. `cargo dylint`
builds the lint library, and the driver to load it with, under the
toolchain the *library* asks for. A project on a stable toolchain can
therefore find a driver being built under a nightly, because that is what
the library it lints with pins.

So `rustup` has to be present and free to install that toolchain, with
whatever components the library names. A library built on `clippy_utils`
needs `rustc-dev` at least, and often `rust-src` and
`llvm-tools-preview` besides, which is a sizeable download on a cold
container, and another cost the mirror does not remove.

`cargo dylint` also wants `git`, and a C linker reachable as `cc`, which
`dylint-link` execs.

## What trusting these costs

Upstream signs its release assets with minisign. Neither those
signatures nor their keys are kept here, because a copy of both sitting
in one directory answers only to itself: anyone able to rewrite a
tarball can re-sign it with a key of their own and replace the public
half beside it, after which the check passes. Verified properly, a
signature is a question put to crates.io, where the key that release
designated is published, and that question can be asked there without a
copy kept in this repository.

A signature settles less than it sounds like anyway. crates.io hosts
source, not binaries, so a key published there is a claim about which
key signs the binaries, made by whoever can publish the crate. The most
a verified signature says is that a key designated from the source
signed these bytes, and nothing about them having been built from that
source, because no part of that scheme records how they were produced.
The attestation GitHub attaches to a release does record it, and is the
only thing here that would.

So a prebuilt binary asks for strictly more trust than a source install
does. `cargo install cargo-dylint` trusts crates.io and your own
compiler; taking the binary trusts the Dylint release pipeline to have
built it honestly from that source, on top. Where that is too much, the
fallback is to build from the same crates.io source and ignore this
directory.

What the mirror itself adds is immutability. A GitHub release asset can
be deleted and re-uploaded under the same name; these bytes are frozen
under a git commit, so whatever was established about them when they
were added stays established.

## Architecture and glibc floor

These are `x86_64` only, and built against glibc. The releases carry
other targets that are not mirrored here, so check the releases page
before concluding a platform is unserved.

Every binary mirrored here needs **glibc 2.39 or newer**, measured off
the committed files, which cannot drift because those files do not. That
floor is recent enough to exclude container images still in common use,
so it is worth comparing against `ldd --version` before assuming a
container can run these. A later release may raise it again.

No musl build is mirrored, because the releases do not carry one.
Building the two commands for `x86_64-unknown-linux-musl` does work, and
yields a pair of static binaries with no glibc floor at all, but those
would be the only files here that upstream never published, built rather
than mirrored, and so outside everything said above. To build a pair:

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
