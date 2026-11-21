#!/usr/bin/env bash
# Build the Creusot artefacts that are shipped in this repository.
#
#   Usage: build.sh <version> [target-triple] [output-dir]
#   e.g.   build.sh 0.15.0 x86_64-unknown-linux-gnu ./out
#
# Creusot publishes no binary releases, so these are built from source. Every
# input that upstream pins is pinned here too:
#   * the source tree is the release tag `v<version>`,
#   * the Rust toolchain is the channel in that tree's `rust-toolchain` file,
#   * the dependencies come from that tree's `Cargo.lock` (`--locked`).
# The build also runs in a fixed directory ($BUILD_ROOT) with source paths
# remapped and SOURCE_DATE_EPOCH pinned to the tag's commit date, so repeating it
# produces a byte-identical tarball. Changing BUILD_ROOT changes the hashes:
# `cargo-creusot` bakes in its own CARGO_MANIFEST_DIR as the fallback it uses when
# CREUSOT_PATH is unset.
set -euo pipefail

VERSION=${1:?usage: build.sh <version> [target] [outdir]}
TARGET=${2:-x86_64-unknown-linux-gnu}
OUTDIR=$(realpath -m "${3:-./out}")
BUILD_ROOT=${BUILD_ROOT:-/var/tmp/creusot-build}
REPO=https://github.com/creusot-rs/creusot

SRC=$BUILD_ROOT/v$VERSION/src
rm -rf "$SRC"
mkdir -p "$(dirname "$SRC")"
git clone --depth 1 --branch "v$VERSION" "$REPO" "$SRC"
cd "$SRC"

CHANNEL=$(sed -n 's/^channel *= *"\(.*\)"/\1/p' rust-toolchain)
COMPONENTS=$(sed -n 's/^components *= *\[\(.*\)\]/\1/p' rust-toolchain | tr -d '" ' | tr ',' ' ')
# shellcheck disable=SC2046
rustup toolchain install "$CHANNEL" --profile minimal --no-self-update $(printf -- '-c %s ' $COMPONENTS)
rustup target add --toolchain "$CHANNEL" "$TARGET"

# `creusot-rustc` is a rustc driver: it is compiled against `rustc-dev` and loads
# `librustc_driver-<hash>.so` out of the toolchain at run time. rustup ships
# `rustc-dev` for the host triple only, so `creusot-rustc` can be built for the
# host's own triple and for no other. `creusot-dev-config` is a helper for hacking
# on Creusot itself and is deliberately not shipped.
PACKAGES=(-p cargo-creusot -p creusot-install -p prelude-generator)
if [ "$TARGET" = "$(rustc -vV | sed -n 's/^host: //p')" ]; then
  PACKAGES+=(-p creusot-rustc)
fi

SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"
export SOURCE_DATE_EPOCH
export CARGO_INCREMENTAL=0
export CARGO_TARGET_DIR="$BUILD_ROOT/v$VERSION/target"
export RUSTFLAGS="--remap-path-prefix=$SRC=/build/creusot --remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}=/build/cargo"

cargo "+$CHANNEL" build --release --locked --target "$TARGET" "${PACKAGES[@]}"

BIN=$CARGO_TARGET_DIR/$TARGET/release
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR/bin" "$OUTDIR/share"
for b in cargo-creusot creusot-install prelude-generator creusot-rustc; do
  [ -f "$BIN/$b" ] || continue
  install -m 755 "$BIN/$b" "$OUTDIR/bin/$b"
  strip "$OUTDIR/bin/$b"
done

# Sources of the Creusot standard library, which `cargo creusot` compiles the
# crate under verification against; it looks for them under CREUSOT_PATH. Mirrors
# the `postInstall` of nix/creusot/creusot.nix.
cp Cargo.toml Cargo.lock "$OUTDIR/share/"
cp -r creusot-std creusot-std-proc pearlite-syn "$OUTDIR/share/"

# The Why3 prelude: Coma sources that `prelude-generator` expands from the
# templates in prelude-generator/. Shipping it saves the user a second build, and
# puts it where why3find looks (CREUSOT_DATA_HOME/share/why3find). Mirrors
# nix/creusot/prelude.nix.
CARGO_MANIFEST_DIR="$SRC/prelude-generator" "$OUTDIR/bin/prelude-generator"
mkdir -p "$OUTDIR/share/why3find"
cp -r "$SRC/target/creusot/packages" "$OUTDIR/share/why3find/"

# Read from CREUSOT_DATA_HOME at run time (why3find.json is also what
# `cargo creusot new` seeds a new project with), and from the working directory by
# `creusot-install why3 why3-conf`.
cp why3find.json creusot-install/creusot_why3.conf creusot-deps.opam LICENSE "$OUTDIR/"

find "$OUTDIR" -exec touch -d "@$SOURCE_DATE_EPOCH" {} +
tar --sort=name --format=gnu --owner=0 --group=0 --numeric-owner \
    --mtime="@$SOURCE_DATE_EPOCH" -C "$OUTDIR" -cf - . \
  | gzip -9n > "$OUTDIR.tar.gz"
touch -d "@$SOURCE_DATE_EPOCH" "$OUTDIR.tar.gz"

echo "built creusot $VERSION for $TARGET into $OUTDIR and $OUTDIR.tar.gz"
