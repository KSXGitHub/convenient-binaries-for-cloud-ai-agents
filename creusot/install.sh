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

# This script only unpacks prebuilt binaries. It never builds Creusot, and when
# it cannot do its job it says so and stops -- it does not quietly turn into a
# rustc-dev download and a workspace compile, and it does not advise one either.
die() { echo "install.sh: $1" >&2; exit 1; }

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
[ -n "$VERSION" ] || die "no version directory found in $HERE"

# Only x86_64 glibc Linux is built here; see this version's README.md for why.
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] && [ -e /lib64/ld-linux-x86-64.so.2 ] || {
  die "x86_64 Linux (glibc) binaries only; this is $(uname -s)/$(uname -m)"
}
command -v rustup >/dev/null || die "rustup not found"

TARBALL=$HERE/$VERSION/creusot-$VERSION-x86_64-unknown-linux-gnu.tar.gz
[ -f "$TARBALL" ] || die "no tarball at $TARBALL"
if [ -f "$HERE/$VERSION/SHA256SUMS" ]; then
  (cd "$HERE/$VERSION" && sha256sum --check --quiet --ignore-missing SHA256SUMS) ||
    die "$TARBALL does not match SHA256SUMS"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
tar -xf "$TARBALL" -C "$TMP"

# The binary knows which nightly it was built against, so nothing is hardcoded.
CHANNEL=$("$TMP/bin/cargo-creusot" creusot version 2>/dev/null | sed -n 's/^Rust toolchain //p' | head -1 || true)
[ -n "$CHANNEL" ] || die "could not read the toolchain channel from the shipped cargo-creusot"

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
  command -v opam >/dev/null || die "opam not found"
  # This is the one step no prebuilt binary helps with: it compiles OCaml and
  # Why3 from source, and takes far longer than everything above put together.
  if ! opam switch list >/dev/null 2>&1; then
    echo "install.sh: opam is not initialised yet; running 'opam init --bare -y'"
    opam init --bare -y || die "'opam init' failed"
  fi
  cp "$TMP/creusot-deps.opam" "$DATA/creusot-deps.opam"
  why3_failed() { die "opam could not build the switch"; }
  # creusot-deps.opam also asks for why3-ide, Why3's GTK front end, unless the
  # variable `in-creusot-ci` is defined -- and its lablgtk3 dependencies then want
  # system GTK development packages, which a headless machine has no reason to
  # carry. So create the switch empty, define the variable on it, and install the
  # dependencies after. Upstream's CI defines the same variable globally; keeping
  # it on this switch leaves the rest of opam alone. The cost is that
  # `cargo creusot why3`, which opens that GUI, will not work.
  if [ ! -d "$DATA/_opam" ]; then
    opam switch create -y --empty "$DATA" || why3_failed
    opam var in-creusot-ci=true --switch "$DATA" >/dev/null || why3_failed
  fi
  opam install -y --switch "$DATA" "$DATA" || why3_failed
  ln -sf "$DATA/_opam/bin/why3" "$DATA/bin/why3"
  ln -sf "$DATA/_opam/bin/why3find" "$DATA/bin/why3find"
fi

echo
echo "installed creusot $VERSION"
echo "  $BIN must be on PATH; then 'cargo creusot --help'"
[ "$PROVERS" = 1 ] || echo "  solvers: run 'creusot-install provers'"
[ "$WHY3" = 1 ] || cat <<'EOF'
  Why3 and why3find are not installed: 'cargo creusot --only coma' works,
  proving does not. Re-run with --why3 for them.
EOF
