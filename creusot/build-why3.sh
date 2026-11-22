#!/usr/bin/env bash
# Build the Why3 framework bundle that this repository ships alongside Creusot.
#
#   Usage: build-why3.sh <creusot-version> [output-dir]
#   e.g.   build-why3.sh 0.15.0 ./out
#
# Creusot cannot prove anything without Why3 and why3find, and they have no
# binary releases either -- upstream installs them by building an opam switch
# from `creusot-deps.opam`, which compiles OCaml and Why3 from source and is by
# far the slowest part of installing Creusot. This bundles the result.
#
# The versions come from the tag's own `creusot-deps.opam`, so the bundle always
# matches the Creusot release it sits next to.
#
# IMPORTANT -- why3 compiles its data directory in, and honours neither WHY3DATA
# nor relocation: `why3 --print-datadir` always reports the prefix it was built
# with. So the bundle is built at the fixed $PREFIX below and must be unpacked
# there (install.sh does that). Building it under $HOME would bake in a path that
# only exists for the user who built it.
set -euo pipefail

VERSION=${1:?usage: build-why3.sh <creusot-version> [outdir]}
OUTDIR=$(realpath -m "${2:-./out}")
PREFIX=${WHY3_BUNDLE_PREFIX:-/opt/creusot-why3}
BUILD_ROOT=${BUILD_ROOT:-/var/tmp/creusot-build}
REPO=https://github.com/creusot-rs/creusot

command -v opam >/dev/null || { echo "build-why3.sh: opam not found" >&2; exit 1; }

SRC=$BUILD_ROOT/v$VERSION/src
if [ ! -f "$SRC/creusot-deps.opam" ]; then
  rm -rf "$SRC"; mkdir -p "$(dirname "$SRC")"
  git clone --depth 1 --branch "v$VERSION" "$REPO" "$SRC"
fi
SOURCE_DATE_EPOCH=$(git -C "$SRC" log -1 --format=%ct)
export SOURCE_DATE_EPOCH

opam switch list >/dev/null 2>&1 || opam init --bare -y

# `in-creusot-ci` excludes why3-ide, Why3's GTK front end: a bundle for headless
# machines has no use for it and its lablgtk3 dependencies need system GTK
# packages. Set on this switch rather than globally.
if [ -x "$PREFIX/_opam/bin/why3" ] && cmp -s "$SRC/creusot-deps.opam" "$PREFIX/creusot-deps.opam"; then
  echo "build-why3.sh: reusing the switch at $PREFIX; its creusot-deps.opam already matches"
else
  rm -rf "$PREFIX"
  mkdir -p "$PREFIX"
  cp "$SRC/creusot-deps.opam" "$PREFIX/creusot-deps.opam"
  opam switch create -y --empty "$PREFIX"
  opam var in-creusot-ci=true --switch "$PREFIX" >/dev/null
  opam install -y --switch "$PREFIX" "$PREFIX"
fi

# Keep everything under lib/why3 except what is only needed to *compile* against
# Why3: the `.cmx`/`.cmi`/`.cmt`/`.cmti` interfaces, `.ml`/`.mli` sources and
# `.a`/`.o`/`.cma` archives. That is 131 MB down to 20 MB. Excluding by extension
# rather than selecting `*.cmxs` matters: lib/why3 also holds the `why3server`
# executable, which why3 spawns to run the provers. Without it every prover call
# hangs for ever, with no error.
#
# `META` and `dune-package` are dropped too. They are ocamlfind and dune metadata
# for compiling against Why3, and nothing here does -- a proof runs fine without
# them. They also happen to be the only part of this bundle that is not
# reproducible: dune writes a git-describe version into META when the package's
# source tree has git metadata, which depends on whether opam had the pin cached
# as a clone. Excluding them makes two from-scratch builds byte-identical.
P=$PREFIX/_opam
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR/bin" "$OUTDIR/share" "$OUTDIR/lib"
install -m 755 "$P/bin/why3" "$P/bin/why3find" "$OUTDIR/bin/"
strip "$OUTDIR/bin/why3" "$OUTDIR/bin/why3find"
cp -r "$P/share/why3" "$OUTDIR/share/"
(cd "$P" && find lib/why3 -type f \
    ! -name '*.cmx' ! -name '*.cmi' ! -name '*.cmt' ! -name '*.cmti' \
    ! -name '*.ml' ! -name '*.mli' ! -name '*.a' ! -name '*.o' ! -name '*.cma' \
    ! -name 'META' ! -name 'dune-package' \
    -print0 | tar --null -cf - -T -) | tar -xf - -C "$OUTDIR"
# Why3 ships its licence in share/why3/LICENSE; add why3find's where opam kept it.
for f in "$P"/doc/why3find/LICENSE* "$P"/.opam-switch/sources/why3find/LICENSE*; do
  [ -f "$f" ] && cp "$f" "$OUTDIR/LICENSE.why3find" && break
done

find "$OUTDIR" -exec touch -d "@$SOURCE_DATE_EPOCH" {} +
tar --sort=name --format=gnu --owner=0 --group=0 --numeric-owner \
    --mtime="@$SOURCE_DATE_EPOCH" -C "$OUTDIR" -cf - . \
  | gzip -9n > "$OUTDIR.tar.gz"
touch -d "@$SOURCE_DATE_EPOCH" "$OUTDIR.tar.gz"

"$OUTDIR/bin/why3" --version
echo "built the why3 framework for creusot $VERSION into $OUTDIR and $OUTDIR.tar.gz"
echo "it is baked for $PREFIX/_opam and must be unpacked there"
