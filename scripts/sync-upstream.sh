#!/usr/bin/env bash
# Sync the verbatim-from-upstream parts of the Rubin stoker profile from a
# pinned jsickcodes/stoker ref.
#
# This profile ships the COMPLETE set of stoker skills and prompts (stoker
# has no builtin package-prompt fallback, and `install` is replace-not-merge
# with no inheritance — see AGENTS.md). The files that the Rubin profile does
# not customize are tracked verbatim and mechanically synced here so upstream
# drift surfaces as a reviewable git diff instead of silent skew.
#
# Overwrites ONLY the verbatim files. Never touches the four Rubin-owned
# skills (stoker-prd, stoker-prd-to-issues, stoker-prd-followup,
# stoker-create-pr), settings.toml, the issue templates, or the Rubin-owned
# devcontainer files (Dockerfile, devcontainer.json, firewall-allowlist.txt).
#
# Usage:
#   make sync-upstream STOKER_REF=<tag|branch|sha>
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
PROFILE_DIR="${REPO_ROOT}/profile"
DEFAULT_SUBDIR="src/stoker/builtin/profiles/default"

# Verbatim sets — keep in lockstep with the ownership table in AGENTS.md.
VERBATIM_SKILLS=(
    stoker-work
    stoker-implement
    stoker-review
    stoker-fixup
    stoker-rebase
)
VERBATIM_PROMPTS=(
    select.md
    implement.md
    review.md
    fixup.md
    rebase.md
)

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

echo "Cloning ${STOKER_REPO} ..."
git clone --quiet "${STOKER_REPO}" "${tmpdir}/stoker"
git -C "${tmpdir}/stoker" checkout --quiet "${STOKER_REF}"
RESOLVED_SHA="$(git -C "${tmpdir}/stoker" rev-parse HEAD)"

SRC="${tmpdir}/stoker/${DEFAULT_SUBDIR}"
if [ ! -d "${SRC}" ]; then
    echo "error: upstream default profile not found at ${DEFAULT_SUBDIR} (ref ${STOKER_REF})" >&2
    exit 1
fi

# Prompts (all five, verbatim).
mkdir -p "${PROFILE_DIR}/prompts"
for p in "${VERBATIM_PROMPTS[@]}"; do
    cp "${SRC}/prompts/${p}" "${PROFILE_DIR}/prompts/${p}"
done

# Verbatim skills (replace each directory wholesale; the four Rubin-owned
# skill directories are never named here, so they are left untouched).
mkdir -p "${PROFILE_DIR}/skills"
for s in "${VERBATIM_SKILLS[@]}"; do
    rm -rf "${PROFILE_DIR:?}/skills/${s}"
    cp -R "${SRC}/skills/${s}" "${PROFILE_DIR}/skills/${s}"
done

# Onboard interview prompt (verbatim — generic, in lockstep with upstream).
mkdir -p "${PROFILE_DIR}/onboard"
cp "${SRC}/onboard/project-mechanics.md" "${PROFILE_DIR}/onboard/project-mechanics.md"

# Codex harness config (verbatim).
mkdir -p "${PROFILE_DIR}/devcontainer"
cp "${SRC}/devcontainer/codex-config.toml" "${PROFILE_DIR}/devcontainer/codex-config.toml"

# Record the pinned ref + resolved SHA so the sync is reproducible and the
# Makefile can default to it on a no-argument re-sync.
cat > "${REPO_ROOT}/UPSTREAM_STOKER_REF" <<EOF
# Pinned jsickcodes/stoker ref that the verbatim profile files were synced
# from. Bump deliberately: re-run \`make sync-upstream STOKER_REF=<ref>\` and
# review the resulting diff before committing.
ref = ${STOKER_REF}
sha = ${RESOLVED_SHA}
EOF

echo "Synced verbatim profile files from ${STOKER_REF} (${RESOLVED_SHA})."
echo "Review the result with: git status && git diff"
