#!/usr/bin/env bash
# Install the prebuilt Creusot from this repository.
#
#   Usage: install.sh [version] [--no-provers] [--why3]
#     version       which directory here to install from; the newest by default
#     --no-provers  skip downloading the SMT solvers
#     --why3        also build the opam switch for Why3 and why3find (slow)
#
# This does what Creusot's own ./INSTALL does, without the part that compiles the
# workspace: `cargo install --path cargo-creusot` and `--path creusot-rustc` want
# the pinned nightly *with* rustc-dev, which is a ~500 MB component and a full
# build. The binaries here are already compiled against that nightly, so all
# that is needed at run time is the same nightly with `--profile minimal`.
#
# Everything lands where cargo-creusot looks by default, so afterwards plain
# `cargo creusot` works with no environment variables set:
#
#   ~/.cargo/bin/cargo-creusot                              the entry point
#   ~/.cargo/bin/creusot-install                             for `provers` later
#   $DATA/toolchains/<channel>/bin/creusot-rustc             the rustc driver
#   $DATA/share/why3find/packages/                           the Why3 prelude
#   $DATA/{why3find.json,creusot_why3.conf}                  configuration
#   $DATA/bin/                                               provers, why3
#
# where $DATA is $CREUSOT_DATA_HOME, else $XDG_DATA_HOME/creusot, else
# ~/.local/share/creusot. cargo-creusot puts $DATA/bin on PATH for why3find
# itself, so only ~/.cargo/bin has to be on yours.
set -euo pipefail

usage() { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

VERSION=
PROVERS=1
WHY3=0
for arg in "$@"; do
  case $arg in
    --no-provers) PROVERS=0 ;;
    --why3) WHY3=1 ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "install.sh: unknown option '$arg'" >&2; usage >&2; exit 2 ;;
    *) VERSION=$arg ;;
  esac
done

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [ -z "$VERSION" ]; then
  VERSION=$(cd "$HERE" && ls -d [0-9]*/ 2>/dev/null | tr -d / | sort -V | tail -1)
fi
[ -n "$VERSION" ] || { echo "install.sh: no version directory found in $HERE" >&2; exit 1; }

# Only x86_64 glibc Linux is built here; see this version's README.md for why.
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] && [ -e /lib64/ld-linux-x86-64.so.2 ] || {
  echo "install.sh: these binaries are x86_64 Linux (glibc) only; this is $(uname -s)/$(uname -m)" >&2
  exit 1
}
command -v rustup >/dev/null || { echo "install.sh: rustup is required; see https://rustup.rs" >&2; exit 1; }

TARBALL=$HERE/$VERSION/creusot-$VERSION-x86_64-unknown-linux-gnu.tar.gz
[ -f "$TARBALL" ] || { echo "install.sh: no tarball at $TARBALL" >&2; exit 1; }
if [ -f "$HERE/$VERSION/SHA256SUMS" ]; then
  (cd "$HERE/$VERSION" && sha256sum --check --quiet --ignore-missing SHA256SUMS)
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
tar -xf "$TARBALL" -C "$TMP"

# The binary knows which nightly it was built against, so nothing is hardcoded.
CHANNEL=$("$TMP/bin/cargo-creusot" creusot version 2>/dev/null | sed -n 's/^Rust toolchain //p' | head -1 || true)
[ -n "$CHANNEL" ] || { echo "install.sh: could not read the toolchain from cargo-creusot" >&2; exit 1; }

DATA=${CREUSOT_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/creusot}
BIN=${CARGO_HOME:-$HOME/.cargo}/bin

echo "install.sh: creusot $VERSION, toolchain $CHANNEL, data directory $DATA"
rustup toolchain install "$CHANNEL" --profile minimal --no-self-update

install -d "$BIN" "$DATA/bin" "$DATA/toolchains/$CHANNEL/bin" "$DATA/share/why3find"
install -m 755 "$TMP/bin/cargo-creusot" "$TMP/bin/creusot-install" "$BIN/"
install -m 755 "$TMP/bin/creusot-rustc" "$DATA/toolchains/$CHANNEL/bin/"
cp -rT "$TMP/share/why3find/packages" "$DATA/share/why3find/packages"
install -m 644 "$TMP/why3find.json" "$TMP/creusot_why3.conf" "$DATA/"
# share/creusot-std and friends are not installed: a released creusot-std comes
# from crates.io, and those sources are only consulted through CREUSOT_PATH when
# running against a development build of Creusot.

# Writes ~/.config/creusot/why3.conf, which `cargo creusot why3` uses. Run from
# the unpacked copy, where the relative paths creusot-install expects resolve --
# run inside $DATA it would try to copy those files onto themselves.
mkdir -p "$TMP/creusot-install"
cp "$TMP/creusot_why3.conf" "$TMP/creusot-install/creusot_why3.conf"
(cd "$TMP" && CREUSOT_DATA_HOME="$DATA" "$BIN/creusot-install" why3-conf) ||
  echo "install.sh: warning: could not write why3.conf; 'cargo creusot' still works" >&2

if [ "$PROVERS" = 1 ]; then
  CREUSOT_DATA_HOME="$DATA" "$BIN/creusot-install" provers
fi

if [ "$WHY3" = 1 ]; then
  command -v opam >/dev/null || { echo "install.sh: --why3 needs opam; see https://opam.ocaml.org" >&2; exit 1; }
  # This is the one step no prebuilt binary helps with: it compiles OCaml and
  # Why3 from source, and takes far longer than everything above put together.
  cp "$TMP/creusot-deps.opam" "$DATA/creusot-deps.opam"
  if ! opam switch create -y "$DATA"; then
    cat >&2 <<'EOF'
install.sh: opam could not create the switch. It usually means system packages
are missing -- opam prints the command for them above, and declines to run your
package manager on its own. On Debian or Ubuntu they are typically:

    apt-get install libgmp-dev zlib1g-dev pkg-config

Install those, then re-run this script with --why3.
EOF
    exit 1
  fi
  ln -sf "$DATA/_opam/bin/why3" "$DATA/bin/why3"
  ln -sf "$DATA/_opam/bin/why3find" "$DATA/bin/why3find"
fi

echo
echo "installed creusot $VERSION"
echo "  $BIN must be on PATH; then 'cargo creusot --help'"
[ "$PROVERS" = 1 ] || echo "  solvers: run 'creusot-install provers'"
[ "$WHY3" = 1 ] || cat <<EOF
  Why3 and why3find are not installed; 'cargo creusot --only coma' works without
  them, proving does not. Re-run with --why3 (needs opam), or see
  https://guide.creusot.rs/installation.html
EOF
