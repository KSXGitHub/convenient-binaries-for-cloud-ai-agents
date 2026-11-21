#!/bin/bash
# Check the mirrored Dylint binaries. Run it from anywhere:
#
#   dylint/verify.sh              # every mirrored version
#   dylint/verify.sh 6.4.0        # one version
#
# Three checks, in increasing order of what they establish. Each says why
# it was skipped rather than passing quietly, and the script fails if any
# check that did run failed.
set -uo pipefail

cd "$(dirname "$0")" || exit 1

TARGET=x86_64-unknown-linux-gnu
BINARIES=(cargo-dylint dylint-link)
BASE_URL=https://github.com/trailofbits/dylint/releases/download

if [ $# -gt 0 ]; then
  versions=("$@")
else
  mapfile -t versions < <(find . -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V)
fi

failed=0
skipped=()

note_skip() {
  case " ${skipped[*]} " in
    *" $1 "*) ;;
    *) skipped+=("$1") ;;
  esac
}

report() {
  if [ "$1" -eq 0 ]; then
    printf '  ok      %s\n' "$2"
  else
    printf '  FAILED  %s\n' "$2"
    failed=1
  fi
}

for version in "${versions[@]}"; do
  if [ ! -d "$version" ]; then
    printf '%s: no such version in this mirror\n' "$version"
    failed=1
    continue
  fi
  printf '\n%s\n' "$version"

  for binary in "${BINARIES[@]}"; do
    archive="$binary-$TARGET-v$version.tar.gz"
    path="$version/$archive"

    # 1. The digest the release published. Catches a damaged file, nothing
    #    more. The two release runners wrote it in different layouts, so
    #    pull the hex out rather than feeding it to `sha256sum --check`.
    expected=$(grep -oE '[0-9a-f]{64}' "$path.sha256" | head -1)
    actual=$(sha256sum "$path" | cut -d' ' -f1)
    [ "$expected" = "$actual" ]
    report $? "sha256         $archive"

    # 2. The minisign signature, against the key this directory carries.
    #    `-x` because the release names it `.sig`, not `.minisig`. This
    #    proves a key designated from the crate's source signed these
    #    bytes. It carries no build provenance: see README.md.
    if command -v minisign >/dev/null 2>&1; then
      minisign -V -p "$version/minisign.pub" -m "$path" -x "$path.sig" >/dev/null 2>&1
      report $? "minisign       $archive"
    else
      note_skip 'minisign is not installed'
    fi

    # 3. The release asset as GitHub serves it now. Proves this mirror
    #    holds upstream's bytes and not someone else's.
    if [ "${SKIP_NETWORK:-}" != "true" ]; then
      fresh=$(mktemp)
      if curl -sSfL -m 180 -o "$fresh" "$BASE_URL/v$version/$archive"; then
        cmp -s "$fresh" "$path"
        report $? "matches release $archive"
      else
        note_skip 'the release download was unreachable'
      fi
      rm -f "$fresh"
    else
      note_skip 'SKIP_NETWORK=true'
    fi
  done

  # 4. The glibc floor, read off the binaries rather than written down,
  #    against the glibc of the machine running this. Not a failure when
  #    it is too high: cross-checking a mirror from another machine is
  #    legitimate. It is reported so nobody has to trust a number in a
  #    README that upstream can move under them.
  if command -v objdump >/dev/null 2>&1; then
    unpacked=$(mktemp -d)
    floor=$(
      for binary in "${BINARIES[@]}"; do
        tar -xzf "$version/$binary-$TARGET-v$version.tar.gz" \
          -C "$unpacked" --strip-components=1 2>/dev/null \
          && objdump -T "$unpacked/$binary" 2>/dev/null \
          | grep -oE 'GLIBC_[0-9]+\.[0-9]+'
      done | sort -uV | tail -1
    )
    rm -rf "$unpacked"
    here=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')
    printf '  note    needs %s, this machine has glibc %s\n' \
      "${floor:-an unknown glibc}" "${here:-of unknown version}"
  else
    note_skip 'objdump is not installed, so the glibc floor was not read'
  fi

  # 5. The build provenance, which is the one that says where the binary
  #    came from rather than who vouched for it. It needs the GitHub API,
  #    so it is the check a sandboxed agent usually cannot run and a
  #    person usually can.
  if command -v gh >/dev/null 2>&1; then
    for binary in "${BINARIES[@]}"; do
      archive="$binary-$TARGET-v$version.tar.gz"
      output=$(gh attestation verify "$version/$archive" --repo trailofbits/dylint 2>&1)
      status=$?
      if [ $status -ne 0 ] && printf '%s' "$output" | grep -q 'HTTP 403'; then
        note_skip 'the GitHub API refused the attestation lookup'
      else
        report $status "attestation    $archive"
      fi
    done
  else
    note_skip 'the gh CLI is not installed'
  fi
done

for reason in ${skipped+"${skipped[@]}"}; do
  printf '\nskipped: %s\n' "$reason"
done

if [ "$failed" -eq 0 ]; then
  printf '\nEvery check that ran passed.\n'
else
  printf '\nSomething failed above.\n'
fi
exit "$failed"
