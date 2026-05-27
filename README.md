# Stoker profile for SQuaRE/Rubin Observatory

Rubin Observatory workflow settings for the [Stoker agentic engineering harness](https://github.com/jsickcodes/stoker).
*This workflow is experimental.* Contact @jonathansick for details.

This repository is a **stoker profile**: a directory of policy
(`settings.toml`, prompts, skills, issue templates, onboarding interview, and
a devcontainer sandbox) that `stoker install` vendors into a consuming
repository. The profile content lives under [`profile/`](profile/); the
profile name is `rubin`.

## Installing the profile

In the repository you want to drive with stoker:

```sh
stoker install --profile github.com/lsst-sqre/rubin-stoker//profile@<ref>
```

Use a commit SHA or tag for `<ref>` so the install is reproducible. After
install, run the onboarding interview to teach stoker how *this* repo builds,
tests, and lints:

```sh
stoker onboard project-mechanics
```

This writes `.claude/skills/project-mechanics/SKILL.md` — the source of truth
the validation phases (`stoker-work`, `stoker-fixup`, `stoker-rebase`) read at
runtime. For a repo that runs testcontainers (e.g. docverse), the
`complete_test` command captured here is where the testcontainers env vars
live, for example:

```
TC_HOST=localhost TESTCONTAINERS_RYUK_DISABLED=true uv run --only-group=nox nox -s test
```

### Secrets

The Rubin profile declares these in `profile/settings.toml`:

| Secret | Required | Notes |
|--------|----------|-------|
| `gh_token` | **yes** | Pushes branches, posts reviews, files issues from the sandbox. |
| `signing_key_private` | **yes** | SSH private key — SQuaRE signs every commit. |
| `signing_key_public` | **yes** | Matching public key (allowed_signers). |
| `anthropic_key` | no | Only when running against the API rather than Claude Code subscription auth. |

The signing keys are **required** (unlike the upstream default profile, where
they are optional): the sandbox cannot produce a valid signed commit without
both halves. There is intentionally **no Jira token** — the sandbox AFK loop
never talks to Jira (see below).

### Atlassian (Jira) MCP — interactive only

The Jira-aware skills (`stoker-prd`, `stoker-prd-to-issues`,
`stoker-prd-followup`) read and comment on Jira through the
[Atlassian MCP server](https://rubinobs.atlassian.net/jira/), which you
configure in your interactive Claude Code environment. These skills run **on
the host**, never in the sandbox.

If the MCP server is not configured, the skills **degrade gracefully**: they
ask you to paste the ticket contents and print the Jira comment text for you
to paste back. The sandbox AFK loop is **GitHub-only** — it reads the Jira
key/URL from the GitHub issue metadata and has no Jira credentials, MCP, or
firewall egress to Jira.

## How the profile is organized

```
profile/
├── settings.toml                 # name="rubin", phase models, required secrets
├── prompts/                      # 5 phase prompts (synced verbatim from upstream)
├── skills/
│   ├── stoker-prd/               # Rubin-owned: Jira seed + comment
│   ├── stoker-prd-to-issues/     # Rubin-owned: Rubin branch naming + Jira metadata + comment
│   ├── stoker-prd-followup/      # Rubin-owned: Jira metadata + comment
│   ├── stoker-create-pr/         # Rubin-owned: DM-XXXXX title + Jira reference
│   └── stoker-{work,implement,review,fixup,rebase}/   # synced verbatim
├── issue_templates/              # Rubin-owned: default + optional Jira Key/URL
├── onboard/project-mechanics.md  # synced verbatim
└── devcontainer/
    ├── Dockerfile                # Rubin-owned: Python + uv + signing + tooling
    ├── devcontainer.json         # Rubin-owned: + Docker-in-Docker
    ├── firewall-allowlist.txt    # Rubin-owned: + Docker Hub CDN / RFC1918 CIDRs
    └── codex-config.toml         # synced verbatim
```

stoker's `install` is **replace-not-merge with no inheritance**, and this
stoker version ships no builtin package-prompt fallback, so the profile must
ship the **complete** set of skills and prompts — even the ones it does not
customize. The un-customized files are tracked verbatim and synced
mechanically (see below) so upstream drift surfaces as a reviewable diff.

## Maintaining the verbatim-synced files

The files this profile does not customize are pulled from a pinned
`jsickcodes/stoker` ref recorded in [`UPSTREAM_STOKER_REF`](UPSTREAM_STOKER_REF):

```sh
# Re-sync the pinned ref (no drift expected if nothing changed upstream):
make sync-upstream

# Bump to a newer upstream ref and review the diff:
make sync-upstream STOKER_REF=<tag|branch|sha>
git diff
```

The sync overwrites only the verbatim files (the 5 phase prompts, the 5
verbatim skills, `onboard/project-mechanics.md`, and
`devcontainer/codex-config.toml`). It never touches the four Rubin-owned
skills, `settings.toml`, the issue templates, or the Rubin-owned devcontainer
files. The full ownership table is in [`AGENTS.md`](AGENTS.md).

`make lint` runs the pre-commit hygiene hooks (also enforced in CI).

## Known limitation: Docker-in-Docker vs the egress firewall

The sandbox enables Docker-in-Docker so testcontainers can run inside the AFK
loop, and the firewall allowlist adds the Docker Hub CDN (Cloudflare) ranges
plus the RFC1918 private ranges that container/testcontainer traffic uses
after port DNAT. The sandbox's `init-firewall.sh` is owned by the stoker
*package* (not this profile) and flushes/reinstalls the `OUTPUT` chain on
every run and every 15 minutes via cron. dockerd's own rules live on the
`FORWARD`/`nat` chains, so the two should not collide — but this combination
has not yet been validated end-to-end in a live sandbox. If image pulls or
testcontainer connections fail, check `journalctl -k | grep STOKER-EGRESS-DROP`
for the blocked destination and widen the allowlist, or re-apply docker's
iptables rules after the firewall init.
