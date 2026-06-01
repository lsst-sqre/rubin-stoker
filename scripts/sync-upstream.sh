#!/usr/bin/env bash
# Fetch the upstream stoker base bodies for the four Rubin-customized skills
# into .upstream-cache/skills/ — and the onboard prompt into
# .upstream-cache/onboard/ — so they can be diffed against profile/skills/* and
# profile/onboard/* during a re-port. No files under profile/ are ever written.
#
# Since stoker#192 introduced per-file fallback to the builtin default profile,
# this profile only ships the files it customizes — there are no verbatim
# tracked files to overwrite anymore. The four Rubin-owned skills below are
# ported from the upstream default skill bodies with Rubin specifics layered
# on; when bumping the pin in UPSTREAM_STOKER_REF, use this script to stage
# the upstream bodies for `diff -ru` and re-port the Rubin layer by hand.
#
# Usage:
#   make sync-upstream                          # re-fetch the pinned ref
#   make sync-upstream STOKER_REF=<ref>         # bump the pin to <ref>
#   STOKER_REF=<ref> scripts/sync-upstream.sh
#
# Override the source repo (e.g. a local clone, for offline seeding) with:
#   STOKER_REPO=/path/to/stoker STOKER_REF=<ref> scripts/sync-upstream.sh
set -euo pipefail

STOKER_REPO="${STOKER_REPO:-https://github.com/jsickcodes/stoker.git}"
STOKER_REF="${STOKER_REF:-}"

if [ -z "${STOKER_REF}" ]; then
    echo "error: STOKER_REF is required (a tag, branch, or commit SHA of jsickcodes/stoker)" >&2
    echo "usage: make sync-upstream STOKER_REF=<ref>" >&2
    exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${REPO_ROOT}/.upstream-cache"
DEFAULT_SUBDIR="src/stoker/builtin/profiles/default"

# The four Rubin-customized skills. Each one is ported from the upstream
# default body, so we stage the upstream copy here for `diff -ru` during a
# re-port. Anything else in the upstream default profile is inherited at
# install time via stoker's per-file fallback and does not need staging.
PORTED_SKILLS=(
    stoker-prd
    stoker-prd-to-issues
    stoker-prd-followup
    stoker-create-pr
)

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

echo "Cloning ${STOKER_REPO} ..."
git clone --quiet --depth 1 --no-checkout "${STOKER_REPO}" "${tmpdir}/stoker"
git -C "${tmpdir}/stoker" fetch --quiet --depth 1 origin "${STOKER_REF}"
git -C "${tmpdir}/stoker" checkout --quiet FETCH_HEAD
RESOLVED_SHA="$(git -C "${tmpdir}/stoker" rev-parse HEAD)"

SRC="${tmpdir}/stoker/${DEFAULT_SUBDIR}"
if [ ! -d "${SRC}" ]; then
    echo "error: upstream default profile not found at ${DEFAULT_SUBDIR} (ref ${STOKER_REF})" >&2
    exit 1
fi

# Stage the upstream base bodies for the four ported skills.
rm -rf "${CACHE_DIR}/skills"
mkdir -p "${CACHE_DIR}/skills"
for s in "${PORTED_SKILLS[@]}"; do
    if [ ! -d "${SRC}/skills/${s}" ]; then
        echo "error: upstream default skill ${s} not found at ${DEFAULT_SUBDIR}/skills/${s} (ref ${STOKER_REF})" >&2
        exit 1
    fi
    cp -R "${SRC}/skills/${s}" "${CACHE_DIR}/skills/${s}"
done

# Stage the upstream onboard/devcontainer.md too. The Rubin onboard prompt
# (profile/onboard/devcontainer.md) is ported from this upstream body with the
# Rubin two-devcontainer / DinD / signing layer added, so it needs the same
# `diff -ru` re-port path as the four skills above.
rm -rf "${CACHE_DIR}/onboard"
mkdir -p "${CACHE_DIR}/onboard"
if [ ! -f "${SRC}/onboard/devcontainer.md" ]; then
    echo "error: upstream onboard prompt not found at ${DEFAULT_SUBDIR}/onboard/devcontainer.md (ref ${STOKER_REF})" >&2
    exit 1
fi
cp "${SRC}/onboard/devcontainer.md" "${CACHE_DIR}/onboard/devcontainer.md"

# Update the pin so the next `make sync-upstream` re-fetches the same ref.
cat > "${REPO_ROOT}/UPSTREAM_STOKER_REF" <<EOF
# Pinned jsickcodes/stoker ref that the four Rubin-customized skills were
# last re-ported against. Bump deliberately: re-run \`make sync-upstream
# STOKER_REF=<ref>\`, then \`diff -ru .upstream-cache/skills/<skill>
# profile/skills/<skill>\` to re-port any upstream changes by hand.
ref = ${STOKER_REF}
sha = ${RESOLVED_SHA}
EOF

echo "Staged upstream base skills + onboard prompt from ${STOKER_REF} (${RESOLVED_SHA}) into .upstream-cache/."
echo "Re-port hints:"
for s in "${PORTED_SKILLS[@]}"; do
    echo "  diff -ru .upstream-cache/skills/${s} profile/skills/${s}"
done
echo "  diff -u .upstream-cache/onboard/devcontainer.md profile/onboard/devcontainer.md"
