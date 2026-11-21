# Dylint

Prebuilt `cargo-dylint` and `dylint-link` for `x86_64-unknown-linux-gnu`,
mirrored byte-for-byte from the
[Dylint releases](https://github.com/trailofbits/dylint/releases).

These two commands are what a Dylint lint library needs in order to be
built and run. [perfectionist](https://github.com/KSXGitHub/perfectionist)
is such a library, and the projects that lint with it
(`parallel-disk-usage`, `my-translated-lyrics`, `pnpm`) need the same two
commands.

## Why mirror them

`cargo install --locked cargo-dylint dylint-link` takes roughly two
minutes of wall time on four cores and leaves about 700 MB under the
target directory, which a container with a fixed disk allowance has to
pay for every time. Extracting these tarballs takes about a second and
costs 14 MB.

The source build also needs a toolchain new enough for Dylint's own MSRV,
which is not always the one a container ships with. `cargo install` of
version 6.4.0 fails outright on rustc 1.97.0, for example.

Running `cargo dylint` still builds the Dylint driver and the lint
library itself, and those two are the larger part of a cold run. What the
mirror removes is only the cost of the two commands.

## Picking a version

Take the version the consuming project already pins:

| Version | Pinned by |
| ------- | --------- |
| 6.3.0 | `pnpm`, in the `dylint` job of `.github/workflows/pacquet-ci.yml` |
| 6.3.2 | `parallel-disk-usage` and `my-translated-lyrics`, in `dylint-version` |
| 6.4.0 | `perfectionist`, as the `dylint_linting` dependency in `Cargo.toml` |

Keep `cargo-dylint` and `dylint-link` on the same version. They are
released together under one tag.

Matching the pin is a convenience rather than a requirement. The only
compatibility gate is in the Dylint driver, which reads the
`dylint_version` symbol out of the lint library and compares it against
its own `DYLINT_VERSION`. That constant is the string `0.1.0` in
`dylint_linting` 6.0.1 and in 6.4.0 alike, so it does not track the crate
version, and a newer `cargo-dylint` drives an older library. The 6.4.0
binary here ran a `perfectionist` built against `dylint_linting` 6.0.1
without complaint.

## What the toolchain has to be

Nothing here pins the consuming project's toolchain. `cargo dylint`
builds the lint library, and the driver to load it with, under the
toolchain the *library* asks for, not the one the project lints under:
linting `parallel-disk-usage`, which is on 1.100.0, built a driver under
`nightly-2026-05-28` because that is what the pinned `perfectionist`
revision requires.

So `rustup` has to be present and free to install that toolchain, with
whatever components the library names. `perfectionist` asks for
`rustc-dev`, `rust-src` and `llvm-tools-preview`, which is a download of
some hundreds of megabytes on a cold container, and another cost the
mirror does not remove.

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
base=https://raw.githubusercontent.com/KSXGitHub/convenient-binaries-for-cloud-ai-agents/master
mkdir -p "$dest"
for bin in cargo-dylint dylint-link; do
  curl -sSL "$base/dylint/$version/$bin-x86_64-unknown-linux-gnu-v$version.tar.gz" \
    | tar -xz -C "$dest" --strip-components=1
done
```

`cargo dylint` also needs `git` and a C linker reachable as `cc`, the
same as a source install does.

## Verifying

Every tarball comes with the `.sha256` and `.sig` files the release
publishes. The signature is [minisign](https://jedisct1.github.io/minisign/);
each Dylint release signs with its own key, published as
`package.metadata.binstall.signing.pubkey` in that version's `Cargo.toml`
on crates.io:

| Version | Public key |
| ------- | ---------- |
| 6.3.0 | `RWSXVkGJeTMuN3x0cx2IJ1Y9H9NIApDmWgH602XAL8NCnSczrmPtAUIY` |
| 6.3.2 | `RWRdbyRNO+/QGkBEsymvSLVXe9ifZ871+evIixu0rPcejKR2BynubvL5` |
| 6.4.0 | `RWTli65d9uuuE9wjVkK8JxFzblxCXVPyFx1cyisJOXwxmpepKoGk43+Q` |

The `.sha256` files are written in two different formats, because the
6.3.x and 6.4.0 releases were cut by different runners: 6.3.0 and 6.3.2
use the `coreutils` layout, and 6.4.0 the BSD `SHA2-256(file)= hash`
layout. Both are mirrored as published.

## Architecture and glibc floor

These are `x86_64` only. Dylint also publishes
`aarch64-unknown-linux-gnu`, which is not mirrored here, so an arm64
container still has to install from source.

Every binary here needs **glibc 2.39 or newer**, the version on the
Ubuntu 24.04 runner that builds them. They run on Ubuntu 24.04, Debian 13
and anything later, and fail to start on Ubuntu 22.04, Debian 12 or
Amazon Linux 2023.

Dylint publishes no musl target, so there is nothing to mirror for an
older container. Building the two commands for
`x86_64-unknown-linux-musl` does work: the result is a pair of static
binaries with no glibc floor at all, and 6.4.0 built that way ran a
project's lints end to end, driver build included. They are not mirrored
here because they would be the only artifacts in this repository with no
upstream signature behind them. To build a pair:

```bash
apt-get install -y musl-tools
rustup target add x86_64-unknown-linux-musl
CC_x86_64_unknown_linux_musl=musl-gcc \
CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc \
  cargo install --locked --version 6.4.0 \
    --target x86_64-unknown-linux-musl \
    cargo-dylint dylint-link
```

## Licence

Dylint is MIT OR Apache-2.0. Both texts sit beside this file, taken from
the `v6.4.0` tag.
