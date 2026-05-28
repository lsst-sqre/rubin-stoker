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

Everything not shown here is inherited from the upstream `default` profile
via stoker's per-file fallback ([jsickcodes/stoker#192](https://github.com/jsickcodes/stoker/pull/192)):

```
profile/
├── settings.toml                 # name="rubin", phase models, required secrets
├── skills/
│   ├── stoker-prd/               # Jira seed + comment
│   ├── stoker-prd-to-issues/     # Rubin branch naming + Jira metadata + comment
│   ├── stoker-prd-followup/      # Jira metadata + comment
│   └── stoker-create-pr/         # DM-XXXXX title + Jira reference
├── issue_templates/              # default + optional Jira Key/URL
│   ├── prd.yml
│   └── prd-task.yml
└── devcontainer/
    ├── Dockerfile                # Python + uv + signing + tooling
    ├── devcontainer.json         # + Docker-in-Docker
    └── firewall-allowlist.txt    # + Docker Hub CDN / RFC1918 CIDRs
```

## Maintaining the profile

`stoker install` resolves each profile-relative path against this profile
first and falls back to the builtin `default` profile per file, so the only
files that need to live here are the ones Rubin actually customizes (the ten
listed above). The phase prompts, the un-customized skills
(`stoker-{work,implement,review,fixup,rebase}`), `onboard/project-mechanics.md`,
and `devcontainer/codex-config.toml` are all supplied by the builtin default at
install time.

The four customized skills above are **ported from the upstream default skill
bodies** with Rubin specifics layered on. Bump
[`UPSTREAM_STOKER_REF`](UPSTREAM_STOKER_REF) when you want to re-port against
a newer stoker; otherwise leave it alone — there is no longer any verbatim
sync to keep current.

```sh
# Pull the upstream base skills into .upstream-cache/skills/ for diffing:
make sync-upstream
diff -ru .upstream-cache/skills/stoker-prd profile/skills/stoker-prd

# Bump to a newer upstream ref before re-porting:
make sync-upstream STOKER_REF=<tag|branch|sha>
```

`make sync-upstream` never writes anything under `profile/` — the re-port is
fully manual. `make lint` runs the pre-commit hygiene hooks (also enforced in
CI).

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
