# Dylint

Prebuilt `cargo-dylint` and `dylint-link` for `x86_64-unknown-linux-gnu`,
mirrored byte-for-byte from the
[Dylint releases](https://github.com/trailofbits/dylint/releases).

These two commands are what a Dylint lint library needs in order to be
built and run.

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

## Using them

Each tarball holds a single binary under a top-level directory, so
`--strip-components=1` drops it straight into a directory on `PATH`:

```bash
version=6.4.0
dest=~/.local/bin
mkdir -p "$dest"
for bin in cargo-dylint dylint-link; do
  tar -xzf "dylint/$version/$bin-x86_64-unknown-linux-gnu-v$version.tar.gz" \
    -C "$dest" --strip-components=1
done
```

Without a checkout of this repository, pipe them in instead:

```bash
version=6.4.0
dest=~/.local/bin
base=https://raw.githubusercontent.com/KSXGitHub/convenient-binaries-for-cloud-ai-agents/HEAD
mkdir -p "$dest"
for bin in cargo-dylint dylint-link; do
  curl -sSL "$base/dylint/$version/$bin-x86_64-unknown-linux-gnu-v$version.tar.gz" \
    | tar -xz -C "$dest" --strip-components=1
done
```

`cargo dylint` also needs `git` and a C linker reachable as `cc`, the
same as a source install does.

## Verifying

`verify.sh` runs every check this mirror can offer, over one version or
all of them:

```bash
dylint/verify.sh          # every mirrored version
dylint/verify.sh 6.4.0    # one of them
```

It names any check it had to skip rather than passing quietly, and fails
if a check that did run failed. The checks, weakest first:

- **The published digest**, from the `.sha256` beside each tarball.
  Catches a damaged file.
- **The minisign signature**, from the `.sig`, against the
  `minisign.pub` in that version's directory. Needs
  [minisign](https://jedisct1.github.io/minisign/).
- **The bytes GitHub serves now**, re-downloaded and compared, which
  shows this mirror holds upstream's release and not someone else's.
  Set `SKIP_NETWORK=true` to leave it out.
- **The build provenance**, via `gh attestation verify`. This is the
  only check that says where a binary came from rather than who vouched
  for it, and it needs GitHub API access that a sandboxed agent often
  does not have.

### What the signature does and does not establish

It is worth being exact, because "signature verified" sounds like more
than this is.

Each version mirrored here carries its own signing key, unrelated to the
rest, which is why the key sits in the version directory rather than at
the top of this one. So there is no long-lived key to pin and no way to
recognise a signer across releases. Each key also came from
`package.metadata.binstall.signing.pubkey` in that version's
`Cargo.toml` on crates.io, which is where `cargo-binstall` reads it from,
rather than from a channel independent of the release itself.

Note what crates.io is carrying there. It hosts source, not binaries, so
that key is a claim about which key signs the binaries, made by whoever
can publish the crate. The check therefore says a key designated from
the source signed this binary. It says nothing about the binary having
been built from that source, because no part of the scheme records how
the binary was produced.

That is the property a mirror of binaries most wants, and only the
attestation supplies it. What a verified signature catches is a
corrupted download, and a release asset tampered with after publication
by someone who could not also republish the crate. It is not proof of
anyone's identity, and it would not survive a compromised release
pipeline.

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
in common use. `verify.sh` reads it off the binaries and prints it beside
the glibc of the machine running it, so there is no number here to go
stale against an upstream that moves its build runner.

No musl build is mirrored, because the releases do not carry one.
Building the two commands for `x86_64-unknown-linux-musl` does work, and
yields a pair of static binaries with no glibc floor at all, but those
would be the only artifacts in this repository with no upstream signature
behind them. To build a pair:

```bash
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
