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

## Verifying

Run this, against the mirrored file itself:

```bash
gh attestation verify \
  dylint/6.4.0/cargo-dylint-x86_64-unknown-linux-gnu-v6.4.0.tar.gz \
  --repo trailofbits/dylint
```

It is the only check worth the name, because it is the only one that
reaches past this repository. It asks GitHub what workflow built those
bytes, and no edit made here can change the answer.

Nothing computed purely from this directory can stand in for it. The
`.sha256` and the `.sig` are mirrored because the release publishes
them, but both are checked against data this same directory supplies, so
anyone who can rewrite a tarball can rewrite its digest, re-sign it with
a key of their own, and overwrite `minisign.pub` with the matching
public half. Every such check then passes. A script that ran them and
reported success would be measuring this repository against itself.

The `minisign.pub` files are still worth having, for the one workflow
that does break that circle: compare a key against
`package.metadata.binstall.signing.pubkey` in that version's
`Cargo.toml` on crates.io, which is where `cargo-binstall` reads it
from. That comparison, like the attestation, is a question put to a
server rather than to these files, which is what gives it force. Each
release signs with its own unrelated key, which is why a key sits in
every version directory rather than once at the top of this one, and
why there is none to pin across releases.

Even checked that way the signature establishes less than it sounds
like. crates.io hosts source, not binaries, so a key published there is
a claim about which key signs the binaries, made by whoever can publish
the crate. A verified signature therefore says a key designated from the
source signed these bytes. It says nothing about them having been built
from that source, because no part of the scheme records how they were
produced. Only the attestation does, which is why it is the one command
above.

So a prebuilt binary asks for strictly more trust than a source install
does. `cargo install cargo-dylint` trusts crates.io and your own
compiler; taking the binary trusts the Dylint release pipeline to have
built it honestly from that source, on top. Where that is too much, the
fallback is to build from the same crates.io source and ignore this
directory.

What the mirror itself adds is immutability. A GitHub release asset can
be deleted and re-uploaded under the same name; these bytes are frozen
under a git commit, at digests recorded when they were reviewed.

## Architecture and glibc floor

These are `x86_64` only, and built against glibc. The releases carry
other targets that are not mirrored here, so check the releases page
before concluding a platform is unserved.

Each binary refuses to start below the glibc its release was built
against, and that floor is high enough to exclude container images still
in common use. Rather than write the number down, where moving an
upstream build runner would leave it stale, read it off the binary and
compare it against `ldd --version`:

```bash
objdump -T path/to/cargo-dylint \
  | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -uV | tail -1
```

No musl build is mirrored, because the releases do not carry one.
Building the two commands for `x86_64-unknown-linux-musl` does work, and
yields a pair of static binaries with no glibc floor at all, but those
would be the only artifacts in this repository with no upstream signature
behind them. To build a pair:

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
